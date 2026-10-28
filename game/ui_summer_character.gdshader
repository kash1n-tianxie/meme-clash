shader_type canvas_item;
render_mode unshaded;
uniform vec4 frame_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float motion_clock = 0.0;
uniform float secondary_motion = 0.35;
uniform float outline_pixels = 1.5;
varying vec4 draw_tint;
void vertex() { draw_tint = COLOR; }
void fragment() {
    vec2 local_uv = (UV - frame_region.xy) / max(frame_region.zw, vec2(0.001));
    vec2 uv = UV;
    float hair = 1.0 - smoothstep(0.25, 0.49, local_uv.y);
    uv.x += frame_region.z * secondary_motion * sin(motion_clock * 2.0 + local_uv.y * 3.0) * hair * 0.002;
    vec2 edge = TEXTURE_PIXEL_SIZE * outline_pixels;
    vec4 src = texture(TEXTURE, uv);
    float neighbor = max(max(texture(TEXTURE, uv + vec2(edge.x, 0)).a, texture(TEXTURE, uv - vec2(edge.x, 0)).a), max(texture(TEXTURE, uv + vec2(0, edge.y)).a, texture(TEXTURE, uv - vec2(0, edge.y)).a));
    float alpha = smoothstep(0.08, 0.34, src.a);
    vec3 sunlit = clamp(src.rgb * vec3(1.035, 1.02, 0.97), 0.0, 1.0);
    vec3 ink = vec3(0.090, 0.231, 0.333);
    float border = (1.0 - alpha) * smoothstep(0.22, 0.60, neighbor);
    COLOR = vec4(mix(ink, sunlit, alpha) * draw_tint.rgb, max(alpha, border * 0.75) * draw_tint.a);
}
