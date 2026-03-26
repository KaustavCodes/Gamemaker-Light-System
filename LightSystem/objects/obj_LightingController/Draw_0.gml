var vx = camera_get_view_x(view_camera[0]);
var vy = camera_get_view_y(view_camera[0]);
var vw = camera_get_view_width(view_camera[0]);
var vh = camera_get_view_height(view_camera[0]);

// 1. Create/recreate surfaces if they were dropped from GPU memory.
if (!surface_exists(light_surface)) {
    light_surface = surface_create(vw, vh);
}
if (enable_soft_shadows) {
    if (!surface_exists(blur_surface_h)) blur_surface_h = surface_create(vw, vh);
    if (!surface_exists(blur_surface_v)) blur_surface_v = surface_create(vw, vh);
}

// 2. Target the Light Surface and apply camera so world coords align.
surface_set_target(light_surface);
camera_apply(view_camera[0]);

// 3. Clear to the ambient "darkness" color.
//    ambient_alpha=0 → white (no effect); ambient_alpha=1 → full darkness tint.
//    min_illumination ensures dark areas never drop below a visible threshold.
var _min     = min_illumination;
var _dark_r  = max(color_get_red(ambient_color)   / 255, _min);
var _dark_g  = max(color_get_green(ambient_color) / 255, _min);
var _dark_b  = max(color_get_blue(ambient_color)  / 255, _min);
var _clear_r = lerp(1.0, _dark_r, ambient_alpha);
var _clear_g = lerp(1.0, _dark_g, ambient_alpha);
var _clear_b = lerp(1.0, _dark_b, ambient_alpha);
draw_clear(make_color_rgb(_clear_r * 255, _clear_g * 255, _clear_b * 255));

// --- LIGHTING PASS ---
// Cache uniform handles and controller refs as locals for use inside with() block.
var _u_pos          = u_pos;
var _u_pos2         = u_pos2;
var _u_z            = u_z;
var _u_z2           = u_z2;
var _u_color        = u_color;
var _u_radius       = u_radius;
var _u_intensity    = u_intensity;
var _u_light_type   = u_light_type;
var _u_direction    = u_direction;
var _u_cone_angle   = u_cone_angle;
var _u_cone_soft    = u_cone_softness;
var _vb             = vb;

gpu_set_ztestenable(true);
gpu_set_zwriteenable(true);
gpu_set_cullmode(cull_noculling);

var _z     = 0;
var _cam_x = vx + vw * 0.5;
var _cam_y = vy + vh * 0.5;

with (obj_light) {
    // Frustum culling: skip lights whose radius doesn't reach the view.
    if (point_distance(x, y, _cam_x, _cam_y) > radius * 1.5 + vw * 0.5) continue;

    // Draw Shadows (masking the light using depth).
    shader_set(shd_shadow);
    shader_set_uniform_f(_u_pos2, x, y);
    shader_set_uniform_f(_u_z2, _z);
    vertex_submit(_vb, pr_trianglelist, -1);

    // Draw Additive Light (punching holes in the darkness layer).
    gpu_set_blendmode(bm_add);
    shader_set(shd_light);
    shader_set_uniform_f(_u_pos, x, y);
    shader_set_uniform_f(_u_z, _z);
    shader_set_uniform_f(_u_radius, radius);
    shader_set_uniform_f(_u_intensity, intensity);
    shader_set_uniform_f_array(_u_color, [
        color_get_red(my_color)   / 255.0,
        color_get_green(my_color) / 255.0,
        color_get_blue(my_color)  / 255.0
    ]);
    // Per-instance spotlight uniforms.
    shader_set_uniform_f(_u_light_type, light_type == "spot" ? 1.0 : 0.0);
    shader_set_uniform_f(_u_direction, dcos(light_direction), -dsin(light_direction));
    shader_set_uniform_f(_u_cone_angle, cone_angle);
    shader_set_uniform_f(_u_cone_soft, cone_softness);

    draw_rectangle(vx, vy, vx + vw, vy + vh, false);
    gpu_set_blendmode(bm_normal);

    _z--;
}

shader_reset();
gpu_set_ztestenable(false);
gpu_set_zwriteenable(false);
gpu_set_cullmode(cull_noculling);

// 4. Reset render target back to the application surface.
surface_reset_target();

// 5. Soft Shadow Blur Passes (optional — enabled via enable_soft_shadows).
if (enable_soft_shadows && surface_exists(blur_surface_h) && surface_exists(blur_surface_v)) {
    // Pass 1: Horizontal blur  light_surface → blur_surface_h
    surface_set_target(blur_surface_h);
    draw_clear(c_black);
    shader_set(shd_blur);
    shader_set_uniform_f(u_blur_texel_size, 1.0 / vw, 1.0 / vh);
    shader_set_uniform_f(u_blur_horizontal, 1.0);
    shader_set_uniform_f(u_blur_radius_uni, soft_shadow_radius);
    draw_surface(light_surface, vx, vy);
    shader_reset();
    surface_reset_target();

    // Pass 2: Vertical blur  blur_surface_h → blur_surface_v
    surface_set_target(blur_surface_v);
    draw_clear(c_black);
    shader_set(shd_blur);
    shader_set_uniform_f(u_blur_texel_size, 1.0 / vw, 1.0 / vh);
    shader_set_uniform_f(u_blur_horizontal, 0.0);
    shader_set_uniform_f(u_blur_radius_uni, soft_shadow_radius);
    draw_surface(blur_surface_h, vx, vy);
    shader_reset();
    surface_reset_target();

    // Final: multiply the blurred light map onto the game surface.
    gpu_set_blendmode_ext(bm_dest_color, bm_zero);
    draw_surface(blur_surface_v, vx, vy);
    gpu_set_blendmode(bm_normal);
} else {
    // 6. Draw the Light Surface using MULTIPLY blending (no soft shadows).
    gpu_set_blendmode_ext(bm_dest_color, bm_zero);
    draw_surface(light_surface, vx, vy);
    gpu_set_blendmode(bm_normal);
}