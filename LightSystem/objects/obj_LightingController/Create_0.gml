// Vertex format (position-only — used for per-blocker shadow volumes and the depth-clear quad)
vertex_format_begin();
vertex_format_add_position_3d();
vf = vertex_format_end();

// Shader uniforms — shd_light
u_pos         = shader_get_uniform(shd_light, "u_pos");
u_z           = shader_get_uniform(shd_light, "u_z");
u_color       = shader_get_uniform(shd_light, "u_color");
u_radius      = shader_get_uniform(shd_light, "u_radius");
u_intensity   = shader_get_uniform(shd_light, "u_intensity");
u_attenuation = shader_get_uniform(shd_light, "u_attenuation");
u_light_type  = shader_get_uniform(shd_light, "u_light_type");
u_direction   = shader_get_uniform(shd_light, "u_direction");
u_cone_angle    = shader_get_uniform(shd_light, "u_cone_angle");
u_cone_inner_angle = shader_get_uniform(shd_light, "u_cone_inner_angle");
u_cone_softness = shader_get_uniform(shd_light, "u_cone_softness");

// Shader uniforms — shd_light (P8 normal maps)
u_normal_map      = shader_get_sampler_index(shd_light, "u_normal_map");
u_normal_enabled  = shader_get_uniform(shd_light, "u_normal_enabled");
u_light_z_uni     = shader_get_uniform(shd_light, "u_light_z");
u_view_origin_uni = shader_get_uniform(shd_light, "u_view_origin");
u_view_size_uni   = shader_get_uniform(shd_light, "u_view_size");

// Shader uniforms — shd_shadow
u_pos2 = shader_get_uniform(shd_shadow, "u_pos");
u_z2   = shader_get_uniform(shd_shadow, "u_z");

// Shader uniforms — shd_blur
u_blur_texel_size = shader_get_uniform(shd_blur, "u_texel_size");
u_blur_horizontal = shader_get_uniform(shd_blur, "u_horizontal");
u_blur_weights    = shader_get_uniform(shd_blur, "u_weights");

// Flags and scene-level settings
rebuild_vb     = true;
use_front_caps = true;   // true = blockers cast shadows on themselves (darker)
static_world   = false;  // true = never rebuild per-blocker VBs after the initial build

// Atmosphere (scene-level settings)
ambient_color    = c_black;  // Tint of darkness; e.g., make_color_rgb(0,0,50) for night blue
ambient_alpha    = 1.0;      // 0.0 = no darkness effect, 1.0 = full darkness
min_illumination = 0.0;      // 0.0-1.0: minimum brightness so shadows are never fully black

// Normal map (P8 — optional scene-level normal map surface for surface-orientation lighting).
// Assign a surface that covers the current view with packed surface normals to enable
// per-pixel Lambertian (n·l) modulation on top of the standard radial/spotlight falloff.
// Each obj_light instance also exposes light_z (height above the 2-D plane).
normal_map_surface = -1;  // surface_id; -1 = disabled

// Soft shadows (scene-level settings)
enable_soft_shadows = false;  // Blur-based penumbra effect over the light surface
soft_shadow_radius  = 3.0;    // Blur kernel size in pixels

// Surfaces
light_surface  = -1;
blur_surface_h = -1;
blur_surface_v = -1;

// Depth-clear buffer: a frozen huge quad used to reset the depth buffer each frame so that
// blockers which move don't leave phantom shadows behind.  Vertices sit at z=0 (not extruded
// by the shadow shader), and we pass u_z = 1.5 → object-space z = 1.0 (a "far" value that
// any real shadow at z = -0.5 will overwrite via LEQUAL).
depth_clear_vb = vertex_create_buffer();
vertex_begin(depth_clear_vb, vf);
var _r = 200000;  // large enough to cover any possible camera position
vertex_position_3d(depth_clear_vb, -_r, -_r, 0);
vertex_position_3d(depth_clear_vb,  _r, -_r, 0);
vertex_position_3d(depth_clear_vb,  _r,  _r, 0);
vertex_position_3d(depth_clear_vb, -_r, -_r, 0);
vertex_position_3d(depth_clear_vb,  _r,  _r, 0);
vertex_position_3d(depth_clear_vb, -_r,  _r, 0);
vertex_end(depth_clear_vb);
vertex_freeze(depth_clear_vb);

// --- P3: Precomputed Gaussian blur kernel weights ---
// Computed once here and recalculated whenever soft_shadow_radius changes.
// Passed to the shader as a uniform, removing all exp() calls from the fragment shader.
_cached_blur_radius = -1;  // sentinel: forces first computation
blur_weights = array_create(5, 0.0);