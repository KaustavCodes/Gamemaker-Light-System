// Vertex format and buffer
vertex_format_begin();
vertex_format_add_position_3d();
vf = vertex_format_end();
vb = vertex_create_buffer();

// Shader uniforms
u_pos       = shader_get_uniform(shd_light, "u_pos");
u_pos2      = shader_get_uniform(shd_shadow, "u_pos");
u_z         = shader_get_uniform(shd_light, "u_z");
u_z2        = shader_get_uniform(shd_shadow, "u_z");
u_color     = shader_get_uniform(shd_light, "u_color");
u_radius    = shader_get_uniform(shd_light, "u_radius");
u_intensity = shader_get_uniform(shd_light, "u_intensity");

// Flags and settings
rebuild_vb      = true;
use_front_caps  = true;  // true = blocks cast shadows on themselves (darker)
ambient_alpha   = 0.3;   // 0.0-1.0: Global darkness level