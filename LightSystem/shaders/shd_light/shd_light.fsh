varying vec2 pos;
uniform vec2  u_pos;
uniform vec3  u_color;
uniform float u_radius;
uniform float u_intensity;
uniform float u_attenuation;         // Falloff exponent: 1.0=linear, 2.0=quadratic (default), 3.0=cubic
uniform float u_light_type;        // 0.0 = point (360°), 1.0 = spotlight cone
uniform vec2  u_direction;         // Normalised direction vector for spotlight
uniform float u_cone_angle;        // Spotlight outer half-angle in degrees
uniform float u_cone_inner_angle;  // Flat-top source width in pixels (0 = pointy tip)
uniform float u_cone_softness;     // Edge softness 0..1 (0 = full gradient, 1 = hard flat cut)

const float EPSILON = 0.001;  // Prevent division by zero at the light source centre

void main() {
    vec2  dis  = pos - u_pos;
    float dist = length(dis);

    // Spotlight cone attenuation (only when u_light_type == 1).
    float str;
    if (u_light_type > 0.5) {
        vec2  dir_norm = normalize(u_direction);
        vec2  perp_dir = vec2(-dir_norm.y, dir_norm.x);  // perpendicular to beam direction

        // ---- Flat-top source segment ----
        // The virtual source is a line segment of half-width (u_cone_inner_angle / 2) pixels,
        // centred at u_pos and oriented perpendicular to the beam.
        // u_cone_inner_angle == 0  →  single-point tip (classic pointy spotlight).
        // u_cone_inner_angle == 200 →  200 px wide flat origin (trapezoidal beam).
        float half_src_w = u_cone_inner_angle * 0.5;
        float across     = dot(dis, perp_dir);
        float clamped    = clamp(across, -half_src_w, half_src_w);

        // Displacement from the closest point on the source segment.
        vec2  eff_dis  = dis - clamped * perp_dir;
        float eff_dist = length(eff_dis);

        // Radial falloff measured from the effective (closest source) point so the
        // flat-top region is uniformly bright at any given depth along the beam.
        float eff_falloff = max(0.0, 1.0 - eff_dist / u_radius);
        str = pow(eff_falloff, u_attenuation) * u_intensity;

        // Angular attenuation relative to the effective source point.
        vec2  to_pixel = eff_dis / max(eff_dist, EPSILON);
        float dot_val  = dot(to_pixel, dir_norm);

        float outer_cos = cos(radians(u_cone_angle));
        // cone_softness 0.0 → inner = 0° → full angular gradient from axis (gradual)
        // cone_softness 0.7 → inner at 70% of cone_angle → large bright zone, soft edge
        // cone_softness 1.0 → inner = cone_angle → hard cut at outer edge
        float inner_cos = cos(radians(u_cone_angle * clamp(u_cone_softness, 0.0, 1.0)));
        inner_cos = max(inner_cos, outer_cos + 0.0001);

        float cone_factor = smoothstep(outer_cos, inner_cos, dot_val);
        str *= cone_factor;
    } else {
        // Point light: customisable radial falloff via u_attenuation exponent.
        float falloff = max(0.0, 1.0 - dist / u_radius);
        str = pow(falloff, u_attenuation) * u_intensity;
    }

    gl_FragColor = vec4(u_color * str, 1.0);
}