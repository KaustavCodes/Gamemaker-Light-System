// Ambient darkness
draw_set_alpha(ambient_alpha);
draw_set_color(c_black);
var vx = camera_get_view_x(view_camera[0]);
var vy = camera_get_view_y(view_camera[0]);
var vw = camera_get_view_width(view_camera[0]);
var vh = camera_get_view_height(view_camera[0]);
draw_rectangle(vx, vy, vx + vw, vy + vh, false);
draw_set_alpha(1);
draw_set_color(c_white);

// Lighting pass
var _u_pos       = u_pos;
var _u_pos2      = u_pos2;
var _u_z         = u_z;
var _u_z2        = u_z2;
var _u_color     = u_color;
var _u_radius    = u_radius;
var _u_intensity = u_intensity;
var _vb          = vb;

// GPU states
gpu_set_ztestenable(true);
gpu_set_zwriteenable(true);
gpu_set_cullmode(cull_noculling);

var _z = 0;
var _cam_x = vx + vw * 0.5;
var _cam_y = vy + vh * 0.5;

with (obj_light) {
    // Cull distant lights
    if (point_distance(x, y, _cam_x, _cam_y) > radius * 1.5 + vw * 0.5) continue;
    
    // Shadows
    shader_set(shd_shadow);
    shader_set_uniform_f(_u_pos2, x, y);
    shader_set_uniform_f(_u_z2, _z);
    vertex_submit(_vb, pr_trianglelist, -1);
    
    // Additive light
    gpu_set_blendmode(bm_add);
    shader_set(shd_light);
    shader_set_uniform_f(_u_pos, x, y);
    shader_set_uniform_f(_u_z, _z);
    shader_set_uniform_f(_u_radius, radius);
    shader_set_uniform_f(_u_intensity, intensity);
    shader_set_uniform_f_array(_u_color, [
        color_get_red(my_color) / 255.0,
        color_get_green(my_color) / 255.0,
        color_get_blue(my_color) / 255.0
    ]);
    
    draw_rectangle(vx, vy, vx + vw, vy + vh, false);
    gpu_set_blendmode(bm_normal);
    
    _z--;
}

// Cleanup
shader_reset();
gpu_set_ztestenable(false);
gpu_set_zwriteenable(false);
gpu_set_cullmode(cull_noculling);