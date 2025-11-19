varying vec2 pos;
uniform vec2 u_pos;
uniform vec3 u_color;
uniform float u_radius;
uniform float u_intensity;

void main() {
    vec2 dis = pos - u_pos;
    float dist = length(dis);
    float ndc = dist / u_radius;  // Normalized distance (0=center, 1=edge)
    float falloff = max(0.0, 1.0 - ndc);
    float str = pow(falloff, 2.0) * u_intensity;  // Quadratic: even center, smooth fade
    gl_FragColor = vec4(u_color * str, 1.0);
}