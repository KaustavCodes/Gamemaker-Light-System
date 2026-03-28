var vx = camera_get_view_x(view_camera[0]);
var vy = camera_get_view_y(view_camera[0]);
var vw = camera_get_view_width(view_camera[0]);
var vh = camera_get_view_height(view_camera[0]);

// 1. Create/recreate surfaces if they were dropped from GPU memory or if the
//    view dimensions changed (window resize, fullscreen toggle, resolution switch).
if (!surface_exists(light_surface)
    || surface_get_width(light_surface)  != vw
    || surface_get_height(light_surface) != vh) {
    if (surface_exists(light_surface)) surface_free(light_surface);
    light_surface = surface_create(vw, vh);
}
if (enable_soft_shadows) {
    if (!surface_exists(blur_surface_h)
        || surface_get_width(blur_surface_h)  != vw
        || surface_get_height(blur_surface_h) != vh) {
        if (surface_exists(blur_surface_h)) surface_free(blur_surface_h);
        blur_surface_h = surface_create(vw, vh);
    }
    if (!surface_exists(blur_surface_v)
        || surface_get_width(blur_surface_v)  != vw
        || surface_get_height(blur_surface_v) != vh) {
        if (surface_exists(blur_surface_v)) surface_free(blur_surface_v);
        blur_surface_v = surface_create(vw, vh);
    }
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
var _u_pos           = u_pos;
var _u_pos2          = u_pos2;
var _u_z             = u_z;
var _u_z2            = u_z2;
var _u_color         = u_color;
var _u_radius        = u_radius;
var _u_intensity     = u_intensity;
var _u_attenuation   = u_attenuation;
var _u_light_type    = u_light_type;
var _u_direction     = u_direction;
var _u_cone_angle    = u_cone_angle;
var _u_cone_inner    = u_cone_inner_angle;
var _u_cone_soft     = u_cone_softness;

// P8: Cache normal-map uniform handles and resolve the normal-map texture once.
var _u_normal_enabled = u_normal_enabled;
var _u_light_z_uni    = u_light_z_uni;
var _u_view_origin    = u_view_origin_uni;
var _u_view_size_u    = u_view_size_uni;
var _u_normal_map     = u_normal_map;
var _nm_enabled       = surface_exists(normal_map_surface);
var _nm_tex           = _nm_enabled ? surface_get_texture(normal_map_surface) : -1;

gpu_set_ztestenable(true);
gpu_set_zwriteenable(true);
gpu_set_cullmode(cull_noculling);

// Reset the depth buffer each frame so that moved blockers don't leave phantom shadows.
// Write a "far" depth (object-space z = +1.0) everywhere, then shadows (z = -0.5) and
// light rects (z = 0) can both overwrite it correctly via LEQUAL.
gpu_set_blendmode_ext(bm_zero, bm_zero);  // no colour output — depth writes only
gpu_set_ztestenable(false);               // always write (ignore stored depth)
shader_set(shd_shadow);
shader_set_uniform_f(_u_pos2, 0, 0);  // no extrusion needed (verts have z=0)
shader_set_uniform_f(_u_z2, 1.5);     // object z = 1.5 - 0.5 = 1.0  (far reference)
vertex_submit(depth_clear_vb, pr_trianglelist, -1);
shader_reset();
gpu_set_blendmode(bm_normal);
gpu_set_ztestenable(true);

var _z = 0;

with (obj_light) {
    // Skip lights that have been manually disabled.
    if (!active) continue;

    // Exact viewport-AABB vs light-circle cull.
    // Find the nearest point on the view rectangle to the light position, then check
    // whether the distance from the light centre to that nearest point is within the
    // light's radius.  If it isn't, the light circle doesn't touch the view at all —
    // neither the illumination rect nor any shadow from it would be visible.
    // This replaces the previous approximate circle-vs-circle test and correctly
    // handles both wide and tall viewports with no arbitrary safety multiplier.
    var _nx = clamp(x, vx, vx + vw);
    var _ny = clamp(y, vy, vy + vh);
    var _dx = x - _nx;
    var _dy = y - _ny;
    if (_dx * _dx + _dy * _dy > radius * radius) continue;

    // --- P9: Draw Shadows — per-blocker, with light-distance culling ---
    // Instead of submitting one monolithic buffer for every light, iterate each
    // obj_light_block and skip those whose bounding box doesn't intersect this
    // light's circle.  Only nearby blockers contribute GPU work for this light.
    shader_set(shd_shadow);
    shader_set_uniform_f(_u_pos2, x, y);
    shader_set_uniform_f(_u_z2, _z);

    // Cache light properties into locals before entering the inner with() loop
    // (self changes to obj_light_block inside the nested with).
    var _lx = x;
    var _ly = y;
    var _lr = radius;

    with (obj_light_block) {
        if (!cast_shadow || shadow_vb == -1) continue;

        // P9: Skip this blocker if its bounding sphere does not overlap this light's circle.
        // _blocker_r is a conservative bounding radius: the largest scaled dimension of the
        // blocker (rect width/height, circle radius × scale) from its pivot point.
        // radius on obj_light_block is the circle radius; it is always initialised (defaults to
        // sprite_width/2) so it is safe to include here regardless of shape.
        var _bdx      = _lx - x;
        var _bdy      = _ly - y;
        var _blocker_r = max(width  * abs(image_xscale),
                             height * abs(image_yscale),
                             radius * max(abs(image_xscale), abs(image_yscale)));
        var _cull = _lr + _blocker_r + 32;  // 32 px margin for rounding and edge extrusions
        if (_bdx * _bdx + _bdy * _bdy > _cull * _cull) continue;

        vertex_submit(shadow_vb, pr_trianglelist, -1);
    }

    // Draw Additive Light (punching holes in the darkness layer).
    gpu_set_blendmode(bm_add);
    shader_set(shd_light);
    shader_set_uniform_f(_u_pos, x, y);
    shader_set_uniform_f(_u_z, _z);
    shader_set_uniform_f(_u_radius, radius);
    shader_set_uniform_f(_u_intensity, intensity);
    shader_set_uniform_f(_u_attenuation, attenuation_exponent);
    shader_set_uniform_f(_u_color, color_get_red(my_color) / 255.0,
                                    color_get_green(my_color) / 255.0,
                                    color_get_blue(my_color) / 255.0);
    // Per-instance spotlight uniforms.
    shader_set_uniform_f(_u_light_type, light_type == "spot" ? 1.0 : 0.0);
    shader_set_uniform_f(_u_direction, dcos(light_direction), -dsin(light_direction));
    shader_set_uniform_f(_u_cone_angle, cone_angle);
    shader_set_uniform_f(_u_cone_inner, cone_inner_angle);
    shader_set_uniform_f(_u_cone_soft, cone_softness);

    // P8: Normal-map uniforms.  Only active when the controller has a valid normal_map_surface.
    if (_nm_enabled) {
        shader_set_uniform_f(_u_normal_enabled, 1.0);
        shader_set_uniform_f(_u_light_z_uni, light_z);
        shader_set_uniform_f(_u_view_origin, vx, vy);
        shader_set_uniform_f(_u_view_size_u, vw, vh);
        texture_set_stage(_u_normal_map, _nm_tex);
    } else {
        shader_set_uniform_f(_u_normal_enabled, 0.0);
    }

    // P1 optimisation: clip the drawn rectangle to the light's bounding box.
    // This reduces fragment shader invocations from (W × H) to at most (2r × 2r)
    // per light, yielding 60%+ fewer fragments for typical radii.
    var _lx1 = max(vx,       x - radius);
    var _ly1 = max(vy,       y - radius);
    var _lx2 = min(vx + vw,  x + radius);
    var _ly2 = min(vy + vh,  y + radius);
    draw_rectangle(_lx1, _ly1, _lx2, _ly2, false);
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
    // P3: Recompute Gaussian kernel weights only when soft_shadow_radius changes.
    if (soft_shadow_radius != _cached_blur_radius) {
        _cached_blur_radius = soft_shadow_radius;
        var _sigma = max(soft_shadow_radius, 0.001);
        var _total = 0;
        for (var _i = 0; _i <= 4; _i++) {
            blur_weights[_i] = exp(-(_i * _i) / (2.0 * _sigma * _sigma));
            _total += (_i == 0) ? blur_weights[_i] : blur_weights[_i] * 2;
        }
        for (var _i = 0; _i <= 4; _i++) {
            blur_weights[_i] /= _total;
        }
    }

    // Pass 1: Horizontal blur  light_surface → blur_surface_h
    surface_set_target(blur_surface_h);
    draw_clear(c_black);
    shader_set(shd_blur);
    shader_set_uniform_f(u_blur_texel_size, 1.0 / vw, 1.0 / vh);
    shader_set_uniform_f(u_blur_horizontal, 1.0);
    shader_set_uniform_f_array(u_blur_weights, blur_weights);
    draw_surface(light_surface, vx, vy);
    shader_reset();
    surface_reset_target();

    // Pass 2: Vertical blur  blur_surface_h → blur_surface_v
    surface_set_target(blur_surface_v);
    draw_clear(c_black);
    shader_set(shd_blur);
    shader_set_uniform_f(u_blur_texel_size, 1.0 / vw, 1.0 / vh);
    shader_set_uniform_f(u_blur_horizontal, 0.0);
    shader_set_uniform_f_array(u_blur_weights, blur_weights);
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