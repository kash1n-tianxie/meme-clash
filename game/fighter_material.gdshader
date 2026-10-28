shader_type canvas_item;
render_mode unshaded;

uniform vec3 warm_light : source_color = vec3(1.035, 0.970, 0.885);
uniform vec3 sky_light : source_color = vec3(0.13, 0.24, 0.43);
uniform float saturation : hint_range(0.0, 1.5) = 0.89;
uniform float brightness : hint_range(0.5, 1.5) = 0.94;
uniform float outline_pixels : hint_range(0.0, 3.0) = 1.3;
uniform vec4 frame_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float motion_clock = 0.0;
uniform float secondary_motion = 0.0;
uniform float hit_glow = 0.0;
varying vec4 draw_tint;

void vertex() {
	draw_tint = COLOR;
}

void fragment() {
	vec2 local_uv = (UV - frame_region.xy) / max(frame_region.zw, vec2(0.001));
	float torso = smoothstep(0.24, 0.42, local_uv.y) * (1.0 - smoothstep(0.65, 0.80, local_uv.y));
	float hair = (1.0 - smoothstep(0.25, 0.50, local_uv.y));
	vec2 source_uv = UV;
	source_uv.x += frame_region.z * secondary_motion * (sin(motion_clock * 2.4) * torso * 0.003 + sin(motion_clock * 2.0 + local_uv.y * 4.0) * hair * 0.002);
	source_uv.y += frame_region.w * secondary_motion * cos(motion_clock * 2.4) * torso * 0.0015;
	vec4 source = texture(TEXTURE, source_uv);
	vec2 step_uv = TEXTURE_PIXEL_SIZE * outline_pixels;
	float left = texture(TEXTURE, source_uv + vec2(-step_uv.x, 0.0)).a;
	float right = texture(TEXTURE, source_uv + vec2(step_uv.x, 0.0)).a;
	float top = texture(TEXTURE, source_uv + vec2(0.0, -step_uv.y)).a;
	float bottom = texture(TEXTURE, source_uv + vec2(0.0, step_uv.y)).a;
	float solid = smoothstep(0.13, 0.40, source.a);
	float adjacent = max(max(left, right), max(top, bottom));
	float near_edge = 1.0 - smoothstep(0.13, 0.45, min(min(left, right), min(top, bottom)));
	float luma = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 color = mix(vec3(luma), source.rgb, saturation) * brightness * warm_light;
	// Convert pale generated sticker fringes at the alpha boundary into a thin ink edge.
	float pale = smoothstep(0.86, 0.99, min(min(source.r, source.g), source.b));
	color = mix(color, vec3(0.065, 0.066, 0.083), pale * near_edge * 0.80);
	float cool_edge = clamp(source.a - left, 0.0, 1.0) * 0.20;
	color += sky_light * cool_edge;
	// A brief local chest light preserves the face, fur detail, and black ink edge.
	float chest = smoothstep(0.45, 0.55, local_uv.y) * (1.0 - smoothstep(0.72, 0.82, local_uv.y));
	float contact = exp(-pow((local_uv.x - 0.60) / 0.28, 2.0));
	color += vec3(0.16, 0.14, 0.105) * chest * contact * hit_glow * (1.0 - near_edge);
	float outline = (1.0 - solid) * smoothstep(0.24, 0.60, adjacent) * 0.65;
	float alpha = max(solid, outline);
	color = mix(vec3(0.035, 0.037, 0.055), color, solid);
	COLOR = vec4(color * draw_tint.rgb, alpha * draw_tint.a);
}
