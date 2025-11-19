varying vec2 pos;                    // Pixel world pos
uniform vec2 u_pos;                  // Light center
uniform vec3 u_color;                // RGB (0-1)
uniform float u_radius;              // Spread amount
uniform float u_intensity;           // Brightness multiplier

void main() {
    vec2 dis = pos - u_pos;
    float dist_sq = dot(dis, dis);
    float str = u_intensity / (sqrt(dist_sq + u_radius * u_radius) - u_radius + 0.001);
    str = max(0.0, str);  // Clamp negative
    gl_FragColor = vec4(u_color * str, 1.0);
}