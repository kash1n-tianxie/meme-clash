shader_type canvas_item;
render_mode unshaded;
uniform float sea_clock = 0.0;
uniform float sea_amount = 1.0;
void fragment() {
    vec2 uv = UV;
    float ocean = smoothstep(0.355, 0.405, uv.y) * (1.0 - smoothstep(0.505, 0.58, uv.y)) * smoothstep(0.39, 0.43, uv.x);
    uv.x += sin(uv.y * 42.0 + sea_clock * 0.55) * 0.00065 * ocean * sea_amount;
    uv.y += sin(uv.x * 35.0 + sea_clock * 0.4) * 0.0003 * ocean * sea_amount;
    COLOR = texture(TEXTURE, uv) * COLOR;
}
