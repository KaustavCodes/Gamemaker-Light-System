// Two-pass separable Gaussian blur for soft shadow penumbra.
// Pass 1 (u_horizontal=1.0): horizontal smear of the light surface.
// Pass 2 (u_horizontal=0.0): vertical smear of the horizontal result.
// Weights are precomputed on CPU and passed as u_weights[5] (symmetric 9-tap kernel).
varying vec2  v_vTexcoord;
uniform vec2  u_texel_size;   // (1/surface_width, 1/surface_height)
uniform float u_horizontal;   // 1.0 = horizontal pass, 0.0 = vertical pass
uniform float u_weights[5];   // Precomputed Gaussian kernel weights (symmetric, 5 unique values)

void main() {
    vec2 dir = u_horizontal > 0.5 ? vec2(1.0, 0.0) : vec2(0.0, 1.0);

    // Centre tap (i=0)
    vec4 color = texture2D(gm_BaseTexture, v_vTexcoord) * u_weights[0];

    // Symmetric taps 1..4
    for (int i = 1; i <= 4; i++) {
        float fi = float(i);
        vec2  offset = dir * fi * u_texel_size;
        color += texture2D(gm_BaseTexture, v_vTexcoord + offset) * u_weights[i];
        color += texture2D(gm_BaseTexture, v_vTexcoord - offset) * u_weights[i];
    }

    gl_FragColor = color;
}
