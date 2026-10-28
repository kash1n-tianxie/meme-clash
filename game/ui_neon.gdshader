shader_type canvas_item;
render_mode unshaded;

uniform vec4 frame_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 neon_color : source_color = vec4(1.0, 0.11, 0.30, 1.0);
uniform float motion_clock = 0.0;
uniform float secondary_motion = 0.6;
uniform float neon_strength = 1.0;
varying vec4 draw_tint;

void vertex() { draw_tint = COLOR; }

void fragment() {
	vec2 local_uv = (UV - frame_region.xy) / max(frame_region.zw, vec2(0.001));
	vec2 uv = UV;
	float hair = 1.0 - smoothstep(0.26, 0.50, local_uv.y);
	float cloth = smoothstep(0.36, 0.52, local_uv.y) * (1.0 - smoothstep(0.72, 0.90, local_uv.y));
	uv.x += frame_region.z * secondary_motion * (sin(motion_clock * 2.4) * hair * 0.003 + sin(motion_clock * 2.1 + local_uv.y * 4.0) * cloth * 0.002);
	vec2 offset = TEXTURE_PIXEL_SIZE * 3.8;
	vec4 src = texture(TEXTURE, uv);
	vec4 left = texture(TEXTURE, uv - vec2(offset.x, 0.0));
	vec4 right = texture(TEXTURE, uv + vec2(offset.x, 0.0));
	vec4 top = texture(TEXTURE, uv - vec2(0.0, offset.y));
	vec4 bottom = texture(TEXTURE, uv + vec2(0.0, offset.y));
	float solid = smoothstep(0.10, 0.38, src.a);
	float adjacent = max(max(left.a, right.a), max(top.a, bottom.a));
	float border = max(0.0, src.a - min(min(left.a, right.a), min(top.a, bottom.a)));
	float glow = (1.0 - solid) * smoothstep(0.12, 0.60, adjacent);
	float detail = clamp(length(left.rgb - right.rgb) + length(top.rgb - bottom.rgb), 0.0, 1.0) * solid;
	float blue_hair = smoothstep(0.04, 0.22, src.b - src.r) * hair;
	float light = dot(src.rgb, vec3(0.2126, 0.7152, 0.0722));
	// Keep blue hair and facial color readable, with dark ink and colored stage lighting.
	vec3 base = src.rgb * mix(0.44, 0.93, blue_hair);
	base = mix(base, vec3(0.025, 0.022, 0.050), (1.0 - light) * 0.27);
	float pale_border = smoothstep(0.80, 0.97, min(min(src.r, src.g), src.b)) * smoothstep(0.04, 0.55, border);
	base = mix(base, neon_color.rgb, pale_border);
	base += neon_color.rgb * (border * 0.73 + detail * 0.20) * neon_strength;
	vec3 final_color = mix(neon_color.rgb * neon_strength, base, solid);
	COLOR = vec4(final_color * draw_tint.rgb, max(solid, glow * 0.62) * draw_tint.a);
}
