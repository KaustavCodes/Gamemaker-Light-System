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

// P8 — Normal-map surface lighting (optional).
// Set u_normal_enabled = 1.0 and bind a normal-map surface to u_normal_map to activate.
// The normal map must be a surface that covers the current view (same resolution).
// Normals are packed as RGB in [0,1]; decoded to world-space XYZ in [-1,1].
// u_light_z is the height of the light above the 2-D XY plane (world units).
// u_view_origin / u_view_size describe the camera's world-space rectangle so the
// fragment can convert its world position into a UV for the normal-map surface lookup.
uniform sampler2D u_normal_map;
uniform float     u_normal_enabled;  // 0.0 = disabled (fast path), 1.0 = enabled
uniform float     u_light_z;         // Height of this light above the XY plane
uniform vec2      u_view_origin;     // World-space top-left of the current view
uniform vec2      u_view_size;       // World-space width/height of the current view

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

    // P8: Normal-map modulation.
    // When u_normal_enabled == 1.0, sample the scene normal map and compute a
    // Lambertian (diffuse) n·l term.  Surfaces facing away from the light get str = 0.
    if (u_normal_enabled > 0.5) {
        // Convert world-space pixel position to [0,1] UV on the normal-map surface.
        // Flip Y because GameMaker surfaces have Y=0 at the top.
        vec2 uv = (pos - u_view_origin) / u_view_size;
        uv.y = 1.0 - uv.y;

        // Sample and decode: RGB [0,1] → XYZ [-1,1].  Blue channel encodes +Z (facing up).
        vec4  n_sample    = texture2D(u_normal_map, clamp(uv, 0.0, 1.0));
        vec3  surf_normal = normalize(vec3(n_sample.xy * 2.0 - 1.0, max(n_sample.z, EPSILON)));

        // Build a 3-D light direction from the surface pixel to the light source.
        vec3  light_dir = normalize(vec3(u_pos - pos, u_light_z));
        float n_dot_l   = max(dot(surf_normal, light_dir), 0.0);
        str *= n_dot_l;
    }

    gl_FragColor = vec4(u_color * str, 1.0);
}