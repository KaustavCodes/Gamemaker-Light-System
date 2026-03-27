// Two-pass separable Gaussian blur for soft shadow penumbra.
// Pass 1 (u_horizontal=1.0): horizontal smear of the light surface.
// Pass 2 (u_horizontal=0.0): vertical smear of the horizontal result.
varying vec2  v_vTexcoord;
uniform vec2  u_texel_size;   // (1/surface_width, 1/surface_height)
uniform float u_horizontal;   // 1.0 = horizontal pass, 0.0 = vertical pass
uniform float u_blur_radius;  // Gaussian sigma in pixels (controls softness)

void main() {
    vec4  color = vec4(0.0);
    float total = 0.0;
    vec2  dir   = u_horizontal > 0.5 ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    float sigma = max(u_blur_radius, 0.001);

    // 9-tap kernel: constant loop bounds required by GLSL ES.
    for (int i = -4; i <= 4; i++) {
        float fi     = float(i);
        float weight = exp(-(fi * fi) / (2.0 * sigma * sigma));
        vec2  uv     = v_vTexcoord + dir * fi * u_texel_size;
        color += texture2D(gm_BaseTexture, uv) * weight;
        total += weight;
    }

    gl_FragColor = color / total;
}
