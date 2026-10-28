shader_type canvas_item;
render_mode unshaded;

varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }

float box_mask(vec2 uv, vec2 center, vec2 half_size) {
	vec2 soft = vec2(1.0) - smoothstep(half_size - vec2(0.014), half_size, abs(uv - center));
	return soft.x * soft.y;
}

void fragment() {
	vec2 uv = UV;
	vec4 base = texture(TEXTURE, uv);
	if (float(textureSize(TEXTURE, 0).x) > 100.0) {
		// Restrict flowing highlights to the waterfall regions of the illustrated arena.
		float falls = box_mask(uv, vec2(0.578, 0.520), vec2(0.027, 0.124));
		falls += box_mask(uv, vec2(0.288, 0.318), vec2(0.021, 0.090));
		falls += box_mask(uv, vec2(0.450, 0.423), vec2(0.020, 0.088));
		falls += box_mask(uv, vec2(0.887, 0.455), vec2(0.027, 0.105));
		uv.x += sin(uv.y * 140.0 - TIME * 3.0) * 0.0008 * min(1.0, falls);
		base = texture(TEXTURE, uv);
		float flowing = sin(uv.y * 170.0 - TIME * 6.0) * 0.014 * min(1.0, falls);
		base.rgb += vec3(0.60, 0.72, 1.0) * flowing;
		float lanterns = box_mask(uv, vec2(0.142, 0.501), vec2(0.136, 0.216));
		lanterns += box_mask(uv, vec2(0.851, 0.501), vec2(0.139, 0.216));
		float warmth = sin(TIME * 1.5) * 0.012 * min(1.0, lanterns);
		base.rgb += vec3(1.0, 0.50, 0.20) * warmth;
	}
	COLOR = base * vertex_tint;
}
