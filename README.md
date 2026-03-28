Dynamic 2D Lighting System for GameMaker Studio 2
=================================================

A performant, GPU-based 2D dynamic lighting and shadow system for GameMaker Studio 2 (GMS2 v2.3+). Drop in a controller, place lights and shadow blockers, and get real-time coloured illumination with hard or soft shadows — with automatic camera-view culling so off-screen lights cost zero GPU.

---

Table of Contents
-----------------

1. [About the Project](#about-the-project)
2. [Features](#features)
3. [Prerequisites](#prerequisites)
4. [Installation](#installation)
5. [Quick-Start Setup](#quick-start-setup)
   - [Step 1 — Add the Controller](#step-1--add-the-controller)
   - [Step 2 — Add Shadow Blockers](#step-2--add-shadow-blockers)
   - [Step 3 — Add Lights](#step-3--add-lights)
   - [Step 4 — Run the Room](#step-4--run-the-room)
6. [Variable Reference](#variable-reference)
   - [obj_LightingController](#obj_lightingcontroller)
   - [obj_light](#obj_light)
   - [obj_light_block](#obj_light_block)
7. [Advanced Features](#advanced-features)
   - [Spotlight / Cone Light](#spotlight--cone-light)
   - [Flicker and Wobble](#flicker-and-wobble)
   - [Smooth Intensity and Radius Easing](#smooth-intensity-and-radius-easing)
   - [Soft Shadows](#soft-shadows)
   - [Normal Map Lighting](#normal-map-lighting)
   - [Polygon Shadow Blockers](#polygon-shadow-blockers)
   - [Static World Optimisation](#static-world-optimisation)
8. [Camera Culling — Automatic and Manual](#camera-culling--automatic-and-manual)
   - [How Automatic Culling Works](#how-automatic-culling-works)
   - [Manual Light Control with the `active` Flag](#manual-light-control-with-the-active-flag)
   - [Common Runtime Patterns](#common-runtime-patterns)
9. [Troubleshooting](#troubleshooting)

---

About the Project
-----------------

**Purpose** — Provide an easy-to-integrate lighting solution that enhances 2D game visuals without heavy performance costs.

**Key Components**

| Asset | Role |
|---|---|
| `obj_LightingController` | Master controller — builds shadow geometry each Step and composites the final light surface in Draw |
| `obj_light` | Individual light source — point or spotlight |
| `obj_light_block` | Shadow caster — rectangle, circle, or convex polygon |
| `shd_light` | Fragment shader — radial/spotlight falloff, attenuation, optional normal-map modulation |
| `shd_shadow` | Vertex shader — extrudes blocker edges into shadow volumes |
| `shd_blur` | Two-pass Gaussian blur for soft shadow edges |
| `Quad()` | Script — helper to emit a shadow-volume quad into a vertex buffer |
| `scr_path_to_polygon()` | Script — converts a Path asset into the array format used by polygon blockers |

**Limitations** — Best for convex blocker shapes. Concave shapes must be split into multiple convex pieces. Not recommended for HTML5 targets (no Z-buffer).

---

Features
--------

- Multiple simultaneous lights with fully independent per-instance settings.
- Three shadow-caster shapes: rectangle, circle, ellipse, or convex polygon.
- Global ambient darkness, colour tint, and minimum-illumination floor.
- **Exact AABB-circle viewport culling** — lights whose circle doesn't touch the camera rectangle are skipped entirely every frame. Works correctly for any viewport aspect ratio.
- **Per-light `active` flag** — instantly disable/re-enable any light without destroying it.
- Spotlights (directional cone) with inner angle, cone softness, and trapezoidal beam shape.
- Per-light adjustable attenuation curve (linear → quadratic → cubic, any positive exponent).
- Built-in flicker and positional wobble simulation.
- Smooth intensity and radius easing via `lerp` (fade in/out, pulsing).
- Soft shadow blur via a two-pass separable Gaussian kernel (kernel precomputed on CPU — no `exp()` in fragment shader).
- Automatic surface resize handling on window resize, fullscreen toggle, or resolution change.
- Dirty-flag per-blocker vertex buffer rebuild — shadow geometry is only recomputed for blockers that actually move.
- **Per-light shadow culling** — each blocker owns a frozen vertex buffer; the shadow pass submits only geometry for blockers within each light's radius.
- Optional per-pixel **normal map** support for Lambertian (n·l) surface shading.

---

Prerequisites
-------------

- GameMaker Studio 2 version 2.3 or later.
- Basic GML knowledge (events, instances, variables).
- Target platform must support a Z-buffer (Desktop, Mobile). HTML5 is not supported.

---

Installation
------------

1. Download or clone this repository.
2. Open GMS2 and either:
   - Open the included project file directly, **or**
   - Drag the `LightSystem` folder into your own project's Asset Browser.
3. Confirm these assets are present in your project:
   - Objects: `obj_LightingController`, `obj_light`, `obj_light_block`
   - Shaders: `shd_light`, `shd_shadow`, `shd_blur`
   - Scripts: `Quad`, `scr_path_to_polygon`

---

Quick-Start Setup
-----------------

### Step 1 — Add the Controller

Place **one** instance of `obj_LightingController` in your room, on a layer that draws *after* your game world (so the lighting is composited on top). A dedicated `"Lighting"` instance layer works well.

Optionally customise the atmosphere in the room's **Creation Code** for that instance, or in the object's own **Create event**:

```gml
// Creation Code on obj_LightingController instance
ambient_color = make_color_rgb(0, 0, 40);  // deep-blue night tint
ambient_alpha = 0.85;                       // 0 = no darkness, 1 = full darkness
min_illumination = 0.05;                    // shadows never go fully black
```

### Step 2 — Add Shadow Blockers

Place instances of `obj_light_block` wherever you want shadows (walls, pillars, barrels, etc.).

Set the **shape** and size in the instance's Creation Code:

```gml
// Rectangle wall (default) — auto-sized from sprite
shape = "rect";
// width and height default to sprite_width / sprite_height

// Override size manually (useful when the sprite is decorative, not physics-sized)
width  = 64;
height = 128;

// Disable shadow casting for a specific blocker
cast_shadow = false;
```

```gml
// Circular pillar
shape  = "circle";
radius = 32;            // leave as 0 to use sprite_width / 2
circle_sides = 16;      // tessellation quality: 8 blocky, 16 default, 32 smooth
```

For polygon shapes see the [Polygon Shadow Blockers](#polygon-shadow-blockers) section.

Blockers do **not** need a sprite to cast shadows, but assigning one lets you see them in the editor. Set `image_alpha = 0` on the instance if you only want the invisible shadow volume.

### Step 3 — Add Lights

Place instances of `obj_light`. No sprite is needed — the light is rendered entirely by the shader.

```gml
// Creation Code on an obj_light instance
my_color  = make_color_rgb(255, 200, 100);  // warm lantern colour
radius    = 300;                             // illumination radius in pixels
intensity = 1.0;                             // brightness multiplier
attenuation_exponent = 2.0;                  // 1 = linear, 2 = quadratic (default), 3 = cubic
```

### Step 4 — Run the Room

Hit Play. Lights illuminate the scene additively and cast hard shadows from every `obj_light_block`. Overlapping lights blend naturally.

**Important**: if you add, remove, or teleport a shadow blocker at runtime, notify the controller so it rebuilds the affected vertex buffers:

```gml
obj_LightingController.rebuild_vb = true;
```

You do **not** need to call this when a blocker simply moves — the dirty-detection system handles that automatically.

---

Variable Reference
------------------

### obj_LightingController

| Variable | Default | Description |
|---|---|---|
| `ambient_color` | `c_black` | Background darkness tint colour. |
| `ambient_alpha` | `1.0` | `0` = fully lit (no darkness), `1` = full darkness tint. |
| `min_illumination` | `0.0` | Minimum brightness in unlit areas (0–1). Prevents fully black shadows. |
| `use_front_caps` | `true` | When `true`, blockers shade their own top face (self-shadow). |
| `static_world` | `false` | Set to `true` for scenes where no blocker ever moves. Shadow VBs are built once and never rebuilt, saving CPU every step. |
| `rebuild_vb` | `true` | Set to `true` at runtime to force all blocker VBs to regenerate this frame (e.g., after adding/removing a blocker). Automatically resets to `false`. |
| `enable_soft_shadows` | `false` | Enables a two-pass Gaussian blur over the light surface for soft penumbra edges. |
| `soft_shadow_radius` | `3.0` | Blur kernel size in pixels. Larger values = softer/wider penumbra. |
| `normal_map_surface` | `-1` | Optional surface ID for per-pixel normal-map lighting. `-1` = disabled. See [Normal Map Lighting](#normal-map-lighting). |

### obj_light

| Variable | Default | Description |
|---|---|---|
| `active` | `true` | `false` = this light is skipped entirely (no shadow pass, no draw). Light state is preserved. |
| `my_color` | `c_white` | Light colour. Use `make_color_rgb()` for custom colours. |
| `radius` | *(room var)* | Illumination radius in pixels. Controls both the visual falloff and the culling bounds. |
| `intensity` | `0.9` | Brightness multiplier. `1.0` = full, `0.5` = dim, `>1` = overbright. |
| `attenuation_exponent` | `2.0` | Falloff curve. `1.0` linear (wide glow), `2.0` quadratic (natural), `3.0` cubic (concentrated). |
| `light_type` | `"point"` | `"point"` for 360° radial, `"spot"` for a directional cone. |
| `light_direction` | `0` | Spotlight aim in degrees. `0` = right, `90` = down (GM coordinate system). |
| `cone_angle` | `45` | Spotlight outer half-angle in degrees. Total cone arc = `cone_angle * 2`. |
| `cone_inner_angle` | `0` | Flat-top beam-origin width in **pixels**. `0` = pointy tip; e.g., `200` = 200 px wide origin. |
| `cone_softness` | `0.7` | Edge softness `0`–`1`. `0` = full angular gradient; `1` = hard cutoff at cone edge. |
| `light_z` | `200.0` | Height above the 2-D plane for normal-map calculations. Larger = shallower lighting angle. |
| `base_intensity` | `0.9` | Reference intensity used by flicker. |
| `flicker_min` | `-0.3` | Minimum random intensity offset from `base_intensity`. |
| `flicker_max` | `0.1` | Maximum random intensity offset from `base_intensity`. |
| `wobble_amp` | `5` | Max pixel offset for positional wobble (candle-like movement). |
| `target_intensity` | `base_intensity` | Ease `intensity` toward this value each step when `intensity_ease_speed > 0`. |
| `intensity_ease_speed` | `0` | Lerp speed for intensity easing. `0` = instant snap. |
| `target_radius` | `-1` | Ease `radius` toward this value. `-1` = disabled (use `radius` directly). |
| `radius_ease_speed` | `0` | Lerp speed for radius easing. `0` = instant. |

### obj_light_block

| Variable | Default | Description |
|---|---|---|
| `shape` | `"rect"` | Shadow shape: `"rect"`, `"circle"`, or `"polygon"`. |
| `cast_shadow` | `true` | Set to `false` to disable this blocker's shadow entirely. |
| `width` | `sprite_width` | Rectangle half-width source. Respects `image_xscale`. |
| `height` | `sprite_height` | Rectangle half-height source. Respects `image_yscale`. |
| `radius` | `sprite_width/2` | Circle radius. Respects `image_xscale`/`image_yscale` for ellipses. |
| `circle_sides` | `16` | Tessellation for circle shapes. `8` = blocky, `32` = smooth. |
| `points` | `-1` | Array of `[lx, ly]` local-coordinate pairs for polygon shapes. |

---

Advanced Features
-----------------

### Spotlight / Cone Light

Turn any `obj_light` instance into a spotlight by setting `light_type = "spot"` and configuring the cone parameters. All values can be changed at runtime.

```gml
// Creation Code or Step event on an obj_light instance
light_type      = "spot";
light_direction = 45;      // aim 45° (down-right)
cone_angle      = 30;      // 30° half-angle → 60° total beam
cone_inner_angle = 0;      // pointy tip (set >0 for a trapezoidal flashlight beam)
cone_softness   = 0.6;     // 60% of cone is uniformly bright, 40% fades at edges

// Rotate the spotlight with the player each step:
light_direction = point_direction(x, y, obj_player.x, obj_player.y);
```

Set `cone_inner_angle` to a pixel width (e.g., `150`) to create a flashlight beam with a flat origin — useful for wall-mounted lights or wide lanterns.

### Flicker and Wobble

The flicker system is built into `obj_light`'s Step event and activates when `flicker_enabled = true`.

```gml
// Enable flicker in Creation Code
flicker_enabled = true;

base_intensity = 1.0;   // stable centre brightness
flicker_min    = -0.4;  // darkest dip  (base - 0.4)
flicker_max    = 0.15;  // brightest spike (base + 0.15)
wobble_amp     = 4;     // max pixel wobble radius (0 = no wobble)
```

The intensity and position update automatically each step with smooth lerping for a natural candlelight feel. You do not need any extra code.

To disable flicker on an individual light without touching the other variables:

```gml
my_light.flicker_enabled = false;
my_light.intensity = my_light.base_intensity;  // snap back to stable value
```

### Smooth Intensity and Radius Easing

Use the built-in easing variables to fade lights in and out, or expand/contract their radius smoothly over time.

```gml
// Fade a light in over ~0.5 s
my_light.intensity_ease_speed = 4.0;   // lerp factor per second
my_light.target_intensity     = 1.0;   // ease toward full brightness

// Fade out (e.g., on a light-switch trigger)
my_light.target_intensity = 0.0;

// Pulsing radius (set every step for a continuous pulse)
my_light.radius_ease_speed = 3.0;
my_light.target_radius     = 200 + 30 * sin(current_time * 0.003);
```

`intensity_ease_speed` and `radius_ease_speed` are in units **per second** (the system multiplies by `delta_time`), so the speed is frame-rate independent.

### Soft Shadows

Enable soft (blurred) shadow edges on the controller. Two-pass separable Gaussian blur — one horizontal, one vertical — is applied to the light composite surface each frame.

```gml
// In obj_LightingController Creation Code (or instance Creation Code)
enable_soft_shadows = true;
soft_shadow_radius  = 4.0;   // blur kernel radius in pixels; larger = wider penumbra
```

The Gaussian kernel weights are precomputed on the CPU and sent to `shd_blur` as a uniform, so there is no `exp()` in the fragment shader at runtime. The kernel is recalculated automatically whenever `soft_shadow_radius` changes.

> **Performance note**: Soft shadows add two full-view surface render passes per frame. On mobile or low-end targets, keep `soft_shadow_radius` low (1–3) or disable the feature entirely.

### Normal Map Lighting

Assign a normal-map surface to the controller to enable per-pixel Lambertian (n·l) shading. This makes flat sprites appear to have bumpy or rounded surfaces based on the direction of each light.

**Step 1 — Create the normal-map surface** (each frame in a Draw event or Draw GUI Begin):

```gml
// Typically done in obj_LightingController's Draw Begin event, or a dedicated object.
// The surface must cover the current camera view.
var _vw = camera_get_view_width(view_camera[0]);
var _vh = camera_get_view_height(view_camera[0]);
if (!surface_exists(my_normal_surf)
    || surface_get_width(my_normal_surf)  != _vw
    || surface_get_height(my_normal_surf) != _vh) {
    if (surface_exists(my_normal_surf)) surface_free(my_normal_surf);
    my_normal_surf = surface_create(_vw, _vh);
}

// Draw normal sprites into the surface
surface_set_target(my_normal_surf);
draw_clear(make_color_rgb(128, 128, 255));  // flat surface default: RGB (0.5, 0.5, 1.0)
draw_sprite(spr_wall_normals, 0, wall_x - camera_x, wall_y - camera_y);
surface_reset_target();
```

Normal-map encoding convention:  
- **R** = X normal component (0 = left, 128 = flat, 255 = right)  
- **G** = Y normal component (0 = up, 128 = flat, 255 = down)  
- **B** = Z normal component (128–255; higher = more face-on)

**Step 2 — Assign the surface to the controller** (each frame, because the surface ID can change):

```gml
obj_LightingController.normal_map_surface = my_normal_surf;
```

**Step 3 — Tune light height** (once, on each `obj_light` instance):

```gml
light_z = 150;   // world units above the plane; smaller = steeper / more dramatic shading
                 // larger = shallower / more uniform shading. Default: 200
```

Normal-map shading is applied *in addition* to the standard radial/spotlight falloff — it modulates, rather than replaces, the light intensity per pixel.

### Polygon Shadow Blockers

For irregularly shaped walls or objects, use the `"polygon"` shape and provide an array of local-coordinate points.

**Option A — Manual array:**

```gml
// Creation Code on obj_light_block
shape  = "polygon";
// Points are [local_x, local_y] offsets from the instance origin.
// List them in winding order (clockwise or counter-clockwise).
points = [
    [-40, -10],
    [ 40, -10],
    [ 20,  30],
    [-20,  30]
];
```

**Option B — Convert a GameMaker Path asset:**

```gml
// Creation Code on obj_light_block
shape  = "polygon";
points = scr_path_to_polygon(pth_my_wall_shape);
```

Draw the path in the Path editor with points relative to `(0, 0)`. The system automatically rotates and translates the points using `image_angle` and `x`/`y` every time the blocker moves.

> **Important**: Polygon shapes must be **convex**. Concave shapes produce incorrect shadow geometry. Split concave shapes into multiple `obj_light_block` instances.

### Static World Optimisation

If your shadow-casting geometry never changes after room start (common for tile-based dungeons or fixed-layout levels), enable `static_world` on the controller:

```gml
// In obj_LightingController Creation Code
static_world = true;
```

In static-world mode, each blocker's vertex buffer is built once on the first frame it is processed and never rebuilt again, eliminating all per-blocker CPU work in the Step event. This is the single largest CPU optimisation available and can reduce Step time to near-zero for scenes with hundreds of blockers.

> **Caution**: After enabling `static_world`, moving, scaling, or rotating a blocker will **not** update its shadow. Only use this for geometry you are certain will never move.

---

Camera Culling — Automatic and Manual
--------------------------------------

With many lights in a large scene it is important that lights outside the camera view contribute zero GPU work. This system implements both an automatic culling pass (always active) and a manual disable mechanism.

### How Automatic Culling Works

Every frame, before any GPU work begins for a light, the controller performs an **exact AABB-circle intersection test**:

```
1. Find the nearest point on the camera view rectangle to the light's position.
2. Compute the squared distance from the light to that nearest point.
3. If that distance exceeds the light's radius, the light's circle doesn't
   touch the view at all — skip it completely (no shader setup, no shadow
   pass, no fragment draw).
```

The equivalent GML inside the controller's Draw event is:

```gml
var _nx = clamp(x, vx, vx + vw);   // nearest x on view rect
var _ny = clamp(y, vy, vy + vh);   // nearest y on view rect
var _dx = x - _nx;
var _dy = y - _ny;
if (_dx * _dx + _dy * _dy > radius * radius) continue;  // cull
```

**What this means in practice:**

- A torch at world position `(2000, 500)` with `radius = 200` is fully culled when the camera shows x `0`–`1366`. No draw calls are made for it.
- As the camera scrolls and the torch's circle starts overlapping the view edge, the light is automatically included again.
- Culling is correct for **any viewport aspect ratio** and any camera position. There is no arbitrary safety multiplier.

**This requires no configuration** — it is always active and cannot be disabled.

Blocker VB culling works in the same way: off-screen blockers do not have their vertex buffers built, and they are transparently rebuilt the moment the camera moves to include them.

### Manual Light Control with the `active` Flag

The `active` variable on every `obj_light` instance gives you direct, immediate control over whether a light is processed at all. Setting it to `false` is the cheapest possible way to disable a light:

- The shadow pass for that light is skipped.
- The fragment draw call for that light is skipped.
- All light state (color, radius, flicker timers, easing targets) is preserved while the light is off.
- Re-enabling is instant — no rebuild, no re-initialisation.

```gml
// Disable a light
my_light.active = false;

// Re-enable it
my_light.active = true;
```

Use `active` for anything that requires intentional control by game logic:

| Scenario | Approach |
|---|---|
| Light switch / lever | Toggle `active` on press |
| Power-out event (all lights off) | `with (obj_light) { active = false; }` |
| Emergency lighting (subset back on) | Loop and re-enable specific instances |
| Conditional light (only on at night) | `active = (game_hour >= 20 \|\| game_hour < 6)` |
| Cutscene blackout | `active = false` for duration, restore after |

### Common Runtime Patterns

**Light switch (toggle on/off):**

```gml
// obj_switch — Interact event
var _light = instance_nearest(x, y, obj_light);
if (instance_exists(_light)) {
    _light.active = !_light.active;
}
```

**Day/night cycle — all lights on at dusk:**

```gml
// Step event or Alarm
var _is_night = (game_hour >= 20 || game_hour < 6);
with (obj_light) {
    active = _is_night;
}
```

**Smooth fade-out before disabling (no visual pop):**

```gml
// Begin fade-out
my_light.target_intensity     = 0.0;
my_light.intensity_ease_speed = 3.0;   // fade over ~0.33 s

// In a later alarm or when intensity is near zero, fully disable:
if (my_light.intensity < 0.01) {
    my_light.active    = false;
    my_light.intensity = 0.0;   // reset so it snaps to full when re-enabled
}
```

**Spawn a light at runtime and attach it to a projectile:**

```gml
// In the projectile's Create event
my_fire_light = instance_create_layer(x, y, "Lighting", obj_light);
my_fire_light.my_color = make_color_rgb(255, 120, 30);
my_fire_light.radius   = 180;
my_fire_light.intensity = 1.2;
my_fire_light.attenuation_exponent = 2.5;
```

```gml
// In the projectile's Step event — follow the projectile
my_fire_light.x = x;
my_fire_light.y = y;
```

```gml
// In the projectile's Destroy event — clean up the light
instance_destroy(my_fire_light);
```

**Disable a light when it is far from the player (zone-based manual cull):**

This supplements the automatic viewport cull for very large lights (high `radius`) that technically overlap the view but whose source is far from the player and may not contribute meaningfully:

```gml
// Step event on each obj_light (or managed from a controller)
var _dist = point_distance(x, y, obj_player.x, obj_player.y);
active = (_dist < activation_range);   // activation_range set per-instance, e.g. 800
```

---

Troubleshooting
---------------

**No lights or shadows visible:**
- Confirm `obj_LightingController` is in the room on a layer that draws over the game world.
- Check that `ambient_alpha` is greater than `0` (if it is `0` the overlay is fully transparent, which looks identical to having no darkness — but lights still affect it additively).
- Ensure GMS2 is using a target that supports a Z-buffer (Desktop/Mobile; HTML5 is not supported).

**Shadows appear but lights have no colour / everything is dark:**
- Check `ambient_color` and `ambient_alpha`. If the surface clears to pure black and no lights are active, the room will appear black.
- Verify `intensity` > `0` and `radius` > `0` on each `obj_light`.

**Shadow artifacts (spikes, Z-fighting, flickering edges):**
- Ensure blocker shapes are convex. Concave shapes require splitting.
- Reduce `circle_sides` if circle-blocker edge artefacts appear.
- Increase `min_illumination` slightly (e.g., `0.02`) to hide sub-pixel depth precision issues at shadow edges.

**Performance issues (lag, stuttering):**
- Enable `static_world = true` on the controller if blockers don't move.
- Reduce `radius` on lights — the fragment clip rectangle and shadow cull radius both scale with it.
- Disable `enable_soft_shadows` or reduce `soft_shadow_radius` — the blur passes are the most expensive per-frame cost.
- Use `active = false` on lights that aren't currently relevant (see [Manual Light Control](#manual-light-control-with-the-active-flag)).
- For very large rooms, consider the zone-based manual cull pattern described above.

**A moved blocker still shows its old shadow:**
- Set `obj_LightingController.rebuild_vb = true;` after changing a blocker's shape or after `instance_create` / `instance_destroy` of any blocker. Normal movement and scaling are detected automatically and do not require this.

**Polygon shape looks wrong:**
- Verify points are in winding order and the shape is convex.
- Check that local coordinates in the `points` array are relative to the instance origin `(0, 0)`, not world coordinates.

---

For full implementation details, browse the source files in `LightSystem/objects/` and `LightSystem/shaders/`. Contributions welcome — fork and open a PR!