# Performance Analysis 27 March 2026 —  
## KaustavCodes / Gamemaker-Light-System · Dynamic 2D Lighting System

> **Analysis done by GitHub Copilot Agent**  
> Engine: GameMaker Studio 2 (IDE 2024.14.3.217)  
> Codebase snapshot: branch `copilot/build-2d-lighting-engine`, 27 March 2026  
> Scope: All GML objects, all GLSL shaders, all utility scripts, room configuration

---

## 1. System Architecture Overview

The system is composed of the following first-class components:

| Asset | Role |
|---|---|
| `obj_LightingController` | Singleton. Owns all GPU resources, drives both the shadow and light passes each Draw event, rebuilds blocker geometry each Step event. |
| `obj_light` | Per-light instance. Stores colour, radius, intensity, spotlight parameters, flicker/wobble state. No Draw event — rendering is centralised in the controller. |
| `obj_light_block` | Per-blocker instance. Declares shape (`rect` / `circle` / `polygon`), scale, and rotation. Contributes vertices to the shared shadow buffer. |
| `obj_mouse_light` | Thin demo wrapper — sets `x/y` to `mouse_x/y` each Step. |
| `shd_light` | Fragment-heavy. Computes additive radial / spotlight illumination per pixel. |
| `shd_shadow` | Vertex-heavy / invisible. Extrudes shadow quads to infinity for depth masking. |
| `shd_blur` | Two-pass 9-tap separable Gaussian blur for soft-shadow penumbra. |
| `Quad()` | GML helper — emits 6 vertices (2 triangles) for one shadow edge into the vertex buffer. |
| `scr_path_to_polygon()` | Converts a GameMaker Path asset into a `ds_list` of local-coordinate polygon points. |

### Render Pipeline per Frame

```
Step event (CPU)
└─ Rebuild blocker vertex buffer (unless static_world = true)

Draw event (GPU)
├─ surface_set_target(light_surface)
├─  camera_apply → draw_clear (ambient colour)
├─  Depth pre-clear: giant quad at z=1.0 (bm_zero blend, no colour output)
├─  For each obj_light:
│    ├─ shader_set(shd_shadow)  → depth-only shadow mask for THIS light
│    └─ shader_set(shd_light)   → additive full-viewport rectangle
├─ surface_reset_target()
├─ [Optional] 2-pass Gaussian blur (horizontal → vertical)
└─ gpu_set_blendmode_ext(bm_dest_color, bm_zero) → multiply light surface onto scene
```

---

## 2. Detailed Performance Analysis

### 2.1 Fragment Shader Cost — Critical Bottleneck ⚠️

**File:** `shd_light.fsh`

Every light draws a **full-viewport rectangle** via `draw_rectangle(vx, vy, vx+vw, vy+vh, false)`. This means the fragment shader runs on **every pixel of the screen for every light**.

For a typical 1366 × 768 display at 10 lights:

```
1,366 × 768 × 10 = 10,490,880 fragment shader invocations per frame
```

Each invocation computes:
- `length(vec2)` — a `sqrt()`, which is one of the most expensive GLSL operations
- `pow(falloff, 2.0)` — a floating-point exponent
- For spotlights additionally: `normalize()`, `dot()`, `cos(radians())`, `smoothstep()`, `clamp()`

**The fix** is to scissor or restrict the drawn area to the bounding rectangle of the light's radius before calling `draw_rectangle`. Using `gpu_set_scissor()` or, better, drawing a rectangle clipped to `[x-radius, y-radius, x+radius, y+radius]` in world space would reduce fragment work to at most `πr²` pixels per light rather than `W × H`:

```
10 lights × π × 350² ≈ 3,848,451 fragments   (63% reduction at r=350)
10 lights × π × 200² ≈ 1,256,637 fragments   (88% reduction at r=200)
```

> **Severity: HIGH.** This is the single most impactful bottleneck for games with many or large lights.

---

### 2.2 Vertex Buffer Rebuild — CPU Bottleneck ⚠️

**File:** `obj_LightingController/Step_0.gml`

When `static_world = false` (the default), the **entire blocker vertex buffer is rebuilt every Step**:

```gml
vertex_begin(_vb, vf);
with (obj_light_block) {
    // array_create(num_points) × 2  — heap allocation every frame
    // dcos() + dsin() per vertex    — trigonometry per frame
    // Quad() × num_edges            — 6 vertex writes per edge
}
vertex_end(_vb);
```

**Issues identified:**

1. **`array_create(num_points)` called twice per blocker per frame** — this causes garbage collection pressure in GML. For 20 blockers, that is 40 heap allocations per step (600+ per second at 60 fps).

2. **All blocker geometry is concatenated into one global buffer for all lights.** The shadow shader then runs this entire buffer once per light. There is no per-light culling — a blocker on the far left of the map still submits shadow vertices for a light on the far right.

3. **No dirty flag per blocker** — even if only one blocker moved, all are rebuilt. A `dirty` flag on `obj_light_block` that triggers a partial rebuild would be far cheaper.

4. **`vertex_begin` / `vertex_end` on every Step regardless of blocker count** — even when zero blockers are visible.

**The `static_world` mitigation** (`vertex_freeze`) is excellent and reduces this cost to zero for static scenes. For dynamic scenes it is the main CPU bottleneck.

> **Severity: MEDIUM–HIGH.** Manageable with 5–10 dynamic blockers; painful with 30+.

---

### 2.3 Shadow Geometry Has No Per-Light Culling ⚠️

**File:** `obj_LightingController/Draw_0.gml`, lines 73–76

```gml
shader_set(shd_shadow);
shader_set_uniform_f(_u_pos2, x, y);  // light position
vertex_submit(_vb, pr_trianglelist, -1);  // ALL blocker geometry
```

The same monolithic vertex buffer (containing every blocker on the map) is submitted for **every light's shadow pass**. A blocker that is 2000 pixels away from a light with radius 350 still contributes geometry.

For `N` lights × `V` total shadow vertices: `N × V` GPU vertex-shader invocations just for depth masking.

**Recommended fix:** Partition blockers into a spatial grid (e.g., 256×256 px cells). Per light, collect only cells within the radius circle, and build a per-light sub-buffer or use a persistent indexed buffer with indirect draw.

> **Severity: MEDIUM.** Noticeable once lights > 6 and blocker count > 40.

---

### 2.4 Depth Buffer State Toggling ⚠️

**File:** `obj_LightingController/Draw_0.gml`, lines 47–62, 104–106

```gml
gpu_set_ztestenable(true);
gpu_set_zwriteenable(true);
gpu_set_cullmode(cull_noculling);
// ... depth clear pass ...
// ... per-light passes ...
gpu_set_ztestenable(false);
gpu_set_zwriteenable(false);
gpu_set_cullmode(cull_noculling);
```

GPU pipeline state changes (z-test, z-write, cull mode, blend mode) are cheap individually but cumulative. For `N` lights this loop issues:
- 1 `gpu_set_blendmode_ext` (depth clear)
- 1 `gpu_set_blendmode(bm_normal)` per restore
- 1 `gpu_set_blendmode(bm_add)` per light
- 1 `gpu_set_blendmode(bm_normal)` per light
- 3 GPU state calls to reset after loop

That is `2N + 4` state-change calls per frame. At 10 lights = 24 calls. These are low-cost individually but add up on mobile GPUs.

> **Severity: LOW.** Acceptable at current scales.

---

### 2.5 Gaussian Blur — Kernel Weights Computed at Runtime ⚠️

**File:** `shd_blur.fsh`

```glsl
for (int i = -4; i <= 4; i++) {
    float fi     = float(i);
    float weight = exp(-(fi * fi) / (2.0 * sigma * sigma));  // exp() every tap
    ...
}
```

`exp()` is an expensive transcendental function. It is computed **9 times per pixel** even though `sigma` is a uniform that does not change between taps within a single pass. The weights should be computed once in GML and passed as a `uniform vec4` array (or two `vec4`s for the 9 values), removing all `exp()` calls from the fragment shader entirely:

```glsl
// Precomputed in GML, passed as: shader_set_uniform_f_array(u_weights, [w0,w1,...,w4])
uniform float u_weights[5];  // symmetric, only 5 unique values for a 9-tap kernel
```

> **Severity: MEDIUM.** Significant on low-end mobile GPUs. Cheap on desktop.

---

### 2.6 Per-Light GML Array Allocation in Draw Event ⚠️

**File:** `obj_LightingController/Draw_0.gml`, line 85–89

```gml
shader_set_uniform_f_array(_u_color, [
    color_get_red(my_color)   / 255.0,
    color_get_green(my_color) / 255.0,
    color_get_blue(my_color)  / 255.0
]);
```

This **allocates a new 3-element GML array on every light, every frame**. At 60 fps × 10 lights = 600 array allocations per second, each triggering GML's garbage collector.

**Fix:** Cache the colour array on `obj_light` and only update it when `my_color` changes:

```gml
// In obj_light Create_0.gml
color_array = [color_get_red(my_color)/255.0, color_get_green(my_color)/255.0, color_get_blue(my_color)/255.0];

// In Draw_0.gml — pass the cached array
shader_set_uniform_f_array(_u_color, color_array);
```

Alternatively, use three separate `shader_set_uniform_f` calls — no allocation at all.

> **Severity: LOW–MEDIUM.** GML GC is non-deterministic; this can cause micro-stutters.

---

### 2.7 Frustum Culling Is Conservative and Approximate ⚠️

**File:** `obj_LightingController/Step_0.gml`, line 31

```gml
if (x + _br < vx || x - _br > vx + vw || y + _br < vy || y - _br > vy + vh) continue;
```

And in `Draw_0.gml`, line 70:

```gml
if (point_distance(x, y, _cam_x, _cam_y) > radius * 1.5 + vw * 0.5) continue;
```

**Blocker culling** uses a bounding-radius check that scales by `image_xscale`/`image_yscale` and adds `64px` padding. This is correct but involves `abs()`, `max()`, and a comparison per blocker per frame — fine for small counts.

**Light culling** uses `point_distance()` (a `sqrt()`) every frame for every light. This can be replaced with a squared-distance comparison (no `sqrt` required):

```gml
var _dx = x - _cam_x;
var _dy = y - _cam_y;
var _thresh = radius * 1.5 + vw * 0.5;
if (_dx*_dx + _dy*_dy > _thresh*_thresh) continue;
```

> **Severity: LOW.** `point_distance()` is fast, but eliminating `sqrt()` in tight loops is good practice.

---

### 2.8 Circle Blocker Tessellation — Fixed Per Instance ⚠️

**File:** `obj_light_block/Create_0.gml`

```gml
circle_sides = 16;  // Per instance
```

Circle shadow quality is a fixed constant per blocker with no level-of-detail (LOD) based on screen size or distance from the camera. A large circle at the edge of view needs far fewer sides than one filling the screen.

Additionally, the 16 point arrays are recomputed every frame from `dcos`/`dsin` calls even when the circle hasn't moved or scaled:

```gml
for (var i = 0; i < sides; i++) {
    var a = i * ang_step;
    px[i] = x + rx * dcos(a);  // trig per vertex per frame
    py[i] = y - ry * dsin(a);
}
```

For a static circle, these values never change. `static_world` prevents the full rebuild, but for dynamic scenes this is wasted computation.

> **Severity: LOW–MEDIUM.** Impactful only when many circle blockers are present.

---

### 2.9 Surface Resize Not Handled ⚠️

**File:** `obj_LightingController/Draw_0.gml`, lines 7–13

```gml
if (!surface_exists(light_surface)) {
    light_surface = surface_create(vw, vh);
}
```

Surfaces are created at the current view size if they don't exist, but **there is no code to detect when the view dimensions change** (e.g., window resize, fullscreen toggle, resolution change). If `vw` / `vh` change between frames the surfaces will be the wrong size, causing stretching or cropping artefacts until the GPU discards them (which GameMaker does on context loss, not on resize).

**Fix:** Check view dimensions each frame and recreate surfaces when they mismatch:

```gml
if (!surface_exists(light_surface) || surface_get_width(light_surface) != vw || surface_get_height(light_surface) != vh) {
    if (surface_exists(light_surface)) surface_free(light_surface);
    light_surface = surface_create(vw, vh);
}
```

> **Severity: MEDIUM for desktop (resizable window), LOW for mobile (fixed resolution).**

---

### 2.10 No Per-Light Shadow Masking ⚠️

**Architecture observation**

The current depth buffer approach produces **one shared shadow mask for the whole frame, written additively by all lights sequentially**. Light B can be occluded by a blocker only relevant to Light A because the depth mask written by Light A's shadow pass is still in the buffer when Light B's light rectangle is drawn.

The `_z--` counter (depth z per light) partially separates them, but because all shadow geometry extrudes to the same depth (`u_z - 0.5`) and the depth clear uses `z = 1.0`, the system effectively treats all shadows as equal-depth regardless of which light they belong to.

**True per-light shadow masking** requires either:
1. A stencil buffer cleared between lights (not available in GML without extensions)
2. Separate surfaces per light (expensive but correct)
3. A screen-space shadow accumulation technique (more complex but scalable)

> **Severity: MEDIUM — visible artefact risk in dense multi-light scenes.**

---

### 2.11 Missing Modern Lighting Features

The following features are standard in production 2D lighting systems and are absent:

| Missing Feature | Impact |
|---|---|
| **Normal maps** | Cannot simulate surface bumps or directionality on flat textures |
| **Specular highlights** | Surfaces look matte regardless of material |
| **Light cookies / projected textures** | Cannot project patterns (e.g., window grilles, foliage shadows) |
| **Emissive objects** | Bright objects don't contribute to scene illumination |
| **Per-light shadow bias control** | Shadow acne is unavoidable on thin shapes |
| **Penumbra per blocker edge** (not just whole-surface blur) | Soft shadow blur applies equally everywhere rather than where geometry meets |
| **Point light `attenuation_exponent` control** | Only quadratic falloff (`pow 2.0`) is hardcoded |
| **Color temperature / kelvin input** | Lights use raw RGB only |
| **Light layers / groups** | Cannot isolate which lights affect which objects |

---

## 3. Pros

| # | Pro | Detail |
|---|---|---|
| 1 | **GPU-accelerated core** | Both shadow masking and light shading run entirely on the GPU. CPU is only involved in vertex buffer construction. |
| 2 | **Additive blending is physically correct** | Multiple overlapping lights automatically produce correct brightness addition. |
| 3 | **`static_world` mode eliminates CPU cost entirely** | `vertex_freeze()` drops the blocker rebuild to zero cost — ideal for mostly-static scenes. |
| 4 | **Three blocker shapes** | Rect, circle (with independent x/y scale for ellipses), and arbitrary polygon — covers the vast majority of 2D game needs. |
| 5 | **Frustum culling on both blockers and lights** | Off-screen elements are skipped in both the VB build and the draw loop. |
| 6 | **Clean singleton controller pattern** | Easy integration — one object manages everything, no global scripts scattered across the project. |
| 7 | **Proper GPU resource cleanup** | `CleanUp_0.gml` correctly frees all surfaces, vertex buffers, and vertex formats. No leaks. |
| 8 | **Spotlight with flat-top beam origin** | `cone_inner_angle` (pixel width) + `cone_softness` + `cone_angle` provide a flexible, physically-inspired trapezoidal beam. |
| 9 | **Flicker and wobble system** | Smooth lerp-based intensity and position jitter, with per-instance randomisation. Production-ready for candles, torches. |
| 10 | **Intensity and radius easing** | `target_intensity` + `intensity_ease_speed` allow smooth programmatic on/off transitions without external tweening. |
| 11 | **Two-pass Gaussian blur for soft shadows** | Optional penumbra effect with adjustable kernel radius — visually convincing for most use cases. |
| 12 | **`scr_path_to_polygon`** | Allows artists to define blocker shapes with GM's Path editor rather than hardcoding coordinates. |
| 13 | **Depth-buffer shadow technique** | Avoids the stencil shadow volume requirement — works on any hardware with a Z-buffer, including most mobile devices. |
| 14 | **No external dependencies** | Pure GML + GLSL ES, no extensions or marketplace assets required. |

---

## 4. Cons

| # | Con | Severity | Detail |
|---|---|---|---|
| 1 | **Full-viewport rect per light** | 🔴 HIGH | The fragment shader runs on every screen pixel for every light. No scissor, no light volume. |
| 2 | **Per-frame full VB rebuild for dynamic scenes** | 🔴 HIGH | All blocker geometry is rebuilt from scratch every Step when `static_world = false`. GC pressure from `array_create()`. |
| 3 | **No per-light shadow culling** | 🟠 MEDIUM | The entire blocker buffer is submitted for every light's depth pass. Distant blockers cost GPU time for every light. |
| 4 | **Shared shadow mask for all lights** | 🟠 MEDIUM | The depth buffer is not fully cleared between lights, leading to potential cross-light shadow bleed artefacts. |
| 5 | **`exp()` in blur shader per-tap** | 🟠 MEDIUM | Gaussian weights recalculated at runtime in the fragment shader. Should be precomputed on CPU and passed as uniforms. |
| 6 | **Surface resize not handled** | 🟠 MEDIUM | Surfaces are not recreated when the view dimensions change — artefacts on window resize or resolution switch. |
| 7 | **No normal maps or specular** | 🟠 MEDIUM | Surfaces look flat under all lighting conditions. Critical limitation for polished production visuals. |
| 8 | **Per-frame GML array allocation for colour** | 🟡 LOW–MED | `[r/255, g/255, b/255]` array created inside the draw loop for every light, every frame — GC pressure. |
| 9 | **`point_distance()` (sqrt) in light culling** | 🟡 LOW | Should use squared-distance comparison. Minor but avoidable. |
| 10 | **Fixed attenuation exponent (`pow 2.0`)** | 🟡 LOW | No way to set linear, cubic, or custom falloff curves per light. |
| 11 | **Circle tessellation fixed, no LOD** | 🟡 LOW | `circle_sides` is a static constant with no distance-based reduction. |
| 12 | **Polygon points are a `ds_list`** | 🟡 LOW | GML `ds_list` has more overhead and less cache locality than a native array. Should migrate to array. |
| 13 | **No shadow bias control** | 🟡 LOW | Thin or axis-aligned shapes can produce shadow acne with the depth-only technique. |
| 14 | **No light groups / layers** | 🟡 LOW | Cannot selectively exclude certain objects from certain lights (e.g., UI elements, skybox). |
| 15 | **`draw_clear()` always recomputes ambient** | 🟡 LOW | The 6-variable ambient computation runs every frame even when ambient settings are static. |

---

## 5. Specific Improvement Recommendations

Listed in priority order for production adoption:

### Priority 1 — Fragment Cost (Highest ROI)

**Replace full-viewport `draw_rectangle` with a light-radius-clipped rectangle:**

```gml
// In Draw_0.gml, inside the with(obj_light) block, replace:
draw_rectangle(vx, vy, vx + vw, vy + vh, false);

// With:
var _lx1 = max(vx,        x - radius);
var _ly1 = max(vy,        y - radius);
var _lx2 = min(vx + vw,  x + radius);
var _ly2 = min(vy + vh,   y + radius);
draw_rectangle(_lx1, _ly1, _lx2, _ly2, false);
```

Zero shader changes required. Instant win for typical light radii (< 400 px on a 1366-wide view).

---

### Priority 2 — VB Rebuild Dirty Tracking

Add a `_dirty` variable to `obj_light_block`. Set it `true` in any event that changes `x`, `y`, `image_angle`, `image_xscale`, `image_yscale`, `width`, `height`, or `radius`. In the controller Step, only rebuild when `any(obj_light_block, _dirty)`:

```gml
// obj_LightingController/Step_0.gml
var _any_dirty = false;
with (obj_light_block) {
    if (_dirty) { _any_dirty = true; break; }
}
if (_any_dirty || rebuild_vb) {
    // ... rebuild ...
    with (obj_light_block) { _dirty = false; }
}
```

---

### Priority 3 — Precomputed Blur Kernel

In `obj_LightingController` Step or Create, precompute weights when `soft_shadow_radius` changes:

```gml
// Compute 5 symmetric weights (9-tap kernel)
blur_weights = array_create(5);
var _sigma = max(soft_shadow_radius, 0.001);
var _total = 0;
for (var _i = 0; _i <= 4; _i++) {
    blur_weights[_i] = exp(-(_i * _i) / (2.0 * _sigma * _sigma));
    _total += (_i == 0) ? blur_weights[_i] : blur_weights[_i] * 2;
}
for (var _i = 0; _i <= 4; _i++) blur_weights[_i] /= _total;
// Pass as uniform: shader_set_uniform_f_array(u_weights, blur_weights);
```

Then simplify `shd_blur.fsh` to use `uniform float u_weights[5]` instead of computing `exp()`.

---

### Priority 4 — Eliminate Per-Frame Colour Array Allocation

```gml
// In obj_light Create_0.gml — add:
_color_arr = [color_get_red(my_color)/255.0, color_get_green(my_color)/255.0, color_get_blue(my_color)/255.0];

// Whenever my_color is changed anywhere:
_color_arr[0] = color_get_red(my_color)   / 255.0;
_color_arr[1] = color_get_green(my_color) / 255.0;
_color_arr[2] = color_get_blue(my_color)  / 255.0;

// In Draw_0.gml — replace the array literal:
shader_set_uniform_f_array(_u_color, _color_arr);
```

---

### Priority 5 — Surface Dimension Validation

```gml
// In Draw_0.gml, replace surface existence checks with:
if (!surface_exists(light_surface)
    || surface_get_width(light_surface)  != vw
    || surface_get_height(light_surface) != vh) {
    if (surface_exists(light_surface)) surface_free(light_surface);
    light_surface = surface_create(vw, vh);
}
// Same for blur_surface_h and blur_surface_v
```

---

### Priority 6 — Squared-Distance Light Culling

```gml
// In Draw_0.gml, replace:
if (point_distance(x, y, _cam_x, _cam_y) > radius * 1.5 + vw * 0.5) continue;

// With:
var _dx = x - _cam_x;
var _dy = y - _cam_y;
var _cull_r = radius * 1.5 + vw * 0.5;
if (_dx * _dx + _dy * _dy > _cull_r * _cull_r) continue;
```

---

### Priority 7 — Migrate Polygon Points from `ds_list` to Array

```gml
// Old: ds_list_add(points, [lx, ly], ...);
// New: points = [[lx1,ly1], [lx2,ly2], ...];
// Access: var pt = points[i];  var lx = pt[0];
```

Arrays have better cache locality and no separate memory allocation overhead in GML 2.3+.

---

### Priority 8 — Normal Map Support (Future Road-Map)

To modernise the visual quality:

1. Add `u_normal_map` sampler to `shd_light.fsh`
2. Sample the normal at `pos` in UV space
3. Decode to world-space normal: `normal.xy = normal_sample.xy * 2.0 - 1.0`
4. Replace the flat `dot_val` directional test with a proper diffuse term:  
   `float n_dot_l = max(dot(normal.xy, to_pixel), 0.0);`
5. Blend: `str *= n_dot_l;`

This single addition transforms the visual fidelity from "flat 2D lit" to "pseudo-3D shaded".

---

## 6. Platform-Specific Notes

| Platform | Notes |
|---|---|
| **Windows / Mac** | Fully supported. Z-buffer depth technique works as designed. Two-pass blur is fast on discrete GPU. |
| **Android / iOS** | Fragment-heavy full-viewport rects are the primary concern. Tile-based GPU architectures (PowerVR, Mali, Adreno) benefit most from Priority 1 fix. `exp()` in the blur shader is expensive on mobile fragment shaders. |
| **HTML5** | WebGL has a Z-buffer; the technique should work but `vertex_format_add_position_3d()` and depth state control have known bugs in some GMS2 HTML5 targets. Test carefully. The `enable_soft_shadows` blur will be noticeable on low-end browser hardware. |
| **Opera GX** | Same as HTML5 considerations. |
| **tvOS / iOS** | Very similar to iOS above. |

---

## 7. Scalability Estimates

Based on static analysis (no runtime profiling available):

| Lights | Dynamic Blockers | `static_world` | Estimated Performance |
|---|---|---|---|
| 1–3 | 0–10 | `false` | ✅ Excellent — 60 fps on any hardware |
| 4–8 | 0–10 | `false` | ✅ Good — 60 fps desktop, ~45 fps mid-range mobile |
| 4–8 | 0–10 | `true` | ✅ Excellent — `static_world` removes CPU cost |
| 8–15 | 10–30 | `false` | ⚠️ Moderate — 60 fps desktop (with Priority 1 fix), <30 fps without it on mid mobile |
| 15–30 | 30+ | `false` | ❌ Poor — fragment and VB rebuild cost dominates; requires Priority 1+2+3 fixes |
| Any | Any | `true` + Priority 1 | ✅ Very Good — GPU fragment cost alone remains |

---

## 8. Production Readiness Rating

### Rating: 6.5 / 10

| Category | Score | Justification |
|---|---|---|
| **Visual Quality** | 7/10 | Point lights, spotlights with flat-top beam, adjustable softness. Missing normal maps and specular limits ceiling. |
| **Performance (small scene)** | 9/10 | 1–5 lights, mostly static: excellent GPU utilisation, minimal CPU. |
| **Performance (large scene)** | 4/10 | Full-viewport rect per light (unfixed) is a hard scalability ceiling. |
| **Code Quality** | 7/10 | Well-structured, clean separation of concerns, good comments. Some GC-pressure patterns. |
| **Integration Ease** | 9/10 | Drop in one controller object. Clear, well-commented API variables. |
| **Robustness** | 6/10 | No surface resize handling, potential cross-light shadow artefacts, no error guards on missing controller. |
| **Feature Completeness** | 5/10 | Core lighting is solid; no normals, specular, cookies, emissives, or light groups. |
| **Mobile Readiness** | 5/10 | Works, but full-viewport rects and runtime `exp()` in blur are expensive on tile-based GPUs. |

### Summary Verdict

> This system is **production-ready for small-to-medium 2D games** (top-down RPGs, puzzle games, platformers) with **5–8 lights** and **mostly static or low-dynamic-blocker** scenes. It integrates cleanly, is well-structured, and delivers attractive results with minimal setup cost.  
>  
> For **large-scale or high-light-count productions** (action games, open maps, many simultaneous lights), the full-viewport fragment draw must be addressed (Priority 1 fix) before shipping. Without it, performance on mobile or lower-end hardware will be unacceptable above ~6 lights.  
>  
> The `static_world` flag is the single most impactful existing optimisation and should be used **by default** for any room with non-moving geometry, even if some lights flicker — blocker geometry being static and lights being animated is the common case in most 2D games.

---

## 9. Quick-Reference Priority Checklist

- [ ] 🔴 **P1** — Clip `draw_rectangle` to light bounding box (fragment cost, 60%+ gain)
- [ ] 🔴 **P2** — Dirty-flag VB rebuild (CPU/GC cost, critical for dynamic scenes)
- [ ] 🟠 **P3** — Precompute Gaussian blur weights on CPU, remove `exp()` from shader
- [ ] 🟠 **P4** — Cache `obj_light` colour array, no per-frame allocation
- [ ] 🟠 **P5** — Surface dimension validation on window resize
- [ ] 🟡 **P6** — Squared-distance light culling (remove `sqrt()`)
- [ ] 🟡 **P7** — Migrate polygon `ds_list` to native array
- [ ] 🟢 **P8** — Normal map support (road-map feature, major visual uplift)
- [ ] 🟢 **P9** — Per-light shadow sub-buffer / spatial partitioning (scalability beyond 15 lights)
- [ ] 🟢 **P10** — Adjustable attenuation curve (linear / quadratic / custom exponent per light)

---

*Analysis done by GitHub Copilot Agent — 27 March 2026*  
*Codebase: KaustavCodes/Gamemaker-Light-System, branch `copilot/build-2d-lighting-engine`*
