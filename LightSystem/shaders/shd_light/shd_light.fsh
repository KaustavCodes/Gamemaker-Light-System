varying vec2 pos;
uniform vec2  u_pos;
uniform vec3  u_color;
uniform float u_radius;
uniform float u_intensity;
uniform float u_light_type;     // 0.0 = point (360 deg), 1.0 = spotlight cone
uniform vec2  u_direction;      // Normalized direction vector for spotlight
uniform float u_cone_angle;     // Spotlight outer half-angle in degrees
uniform float u_cone_inner_angle; // Beam width: 0 = sharp tip, >0 = flat bright zone half-angle
uniform float u_cone_softness;  // Outer-edge softness: 0 = hard cut, >0 = soft fringe

void main() {
    vec2  dis  = pos - u_pos;
    float dist = length(dis);
    float ndc  = dist / u_radius;
    float falloff = max(0.0, 1.0 - ndc);
    float str = pow(falloff, 2.0) * u_intensity;  // Quadratic: smooth fade

    // Spotlight cone attenuation (only when u_light_type == 1).
    if (u_light_type > 0.5) {
        const float EPSILON = 0.001;  // Prevent division by zero at the light source center
        vec2  to_pixel  = dis / max(dist, EPSILON);
        float dot_val   = dot(to_pixel, normalize(u_direction));

        float outer_cos = cos(radians(u_cone_angle));

        // Determine the inner bright-zone edge:
        //   cone_inner_angle > 0  → user explicitly set a flat-top beam width; use it directly.
        //   cone_inner_angle == 0 → fall back to softness-derived inner edge (original behaviour).
        float inner_deg = (u_cone_inner_angle > 0.001)
            ? u_cone_inner_angle
            : u_cone_angle * (1.0 - clamp(u_cone_softness, 0.0, 0.999));
        float inner_cos = cos(radians(inner_deg));

        // Guard: inner must represent a strictly narrower angle than outer so
        // smoothstep doesn't invert (inner_cos must be > outer_cos).
        inner_cos = max(inner_cos, outer_cos + 0.0001);

        // Smooth from 0 at the outer edge to 1 inside the bright zone.
        float cone_factor = smoothstep(outer_cos, inner_cos, dot_val);
        str *= cone_factor;
    }

    gl_FragColor = vec4(u_color * str, 1.0);
}