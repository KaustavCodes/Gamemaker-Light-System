varying vec2 pos;
uniform vec2  u_pos;
uniform vec3  u_color;
uniform float u_radius;
uniform float u_intensity;
uniform float u_light_type;    // 0.0 = point (360 deg), 1.0 = spotlight cone
uniform vec2  u_direction;     // Normalized direction vector for spotlight
uniform float u_cone_angle;    // Spotlight half-angle in degrees
uniform float u_cone_softness; // 0 = hard edge, 1 = fully gradual falloff

void main() {
    vec2  dis  = pos - u_pos;
    float dist = length(dis);
    float ndc  = dist / u_radius;
    float falloff = max(0.0, 1.0 - ndc);
    float str = pow(falloff, 2.0) * u_intensity;  // Quadratic: smooth fade

    // Spotlight cone attenuation (only when u_light_type == 1).
    if (u_light_type > 0.5) {
        const float EPSILON = 0.001;  // Prevent division by zero at the light source centre
        vec2  to_pixel  = dis / max(dist, EPSILON);  // Normalized direction light→pixel
        float dot_val   = dot(to_pixel, normalize(u_direction));
        float cone_cos  = cos(radians(u_cone_angle));
        // Inner edge of the soft zone; softness=0 → same as outer (hard cut).
        float inner_cos = cos(radians(u_cone_angle * (1.0 - u_cone_softness)));
        float cone_factor = smoothstep(cone_cos, inner_cos, dot_val);
        str *= cone_factor;
    }

    gl_FragColor = vec4(u_color * str, 1.0);
}