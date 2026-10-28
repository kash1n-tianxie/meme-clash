shader_type canvas_item;
render_mode unshaded;
uniform vec2 canvas_size = vec2(1024.0, 1536.0);
uniform vec4 source_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 zones[8]; // source-pixel centers and radii
uniform vec4 zone_motion[8]; // direction.xy, source-pixel amplitude, phase
uniform int zone_count = 0;
uniform float motion_clock = 0.0;
uniform float motion_strength = 1.0;
uniform float feet_fixed_y = 1500.0;
uniform vec4 fixed_regions[4];
uniform int fixed_count = 0;
uniform float max_displacement_source_px = 4.0;
varying vec4 paint_tint;

void vertex() {
	paint_tint = COLOR;
}

void fragment() {
	vec2 source_px = UV * canvas_size;
	vec2 displacement = vec2(0.0);
	for (int i = 0; i < 8; i++) {
		if (i >= zone_count) { break; }
		vec2 q = (source_px - zones[i].xy) / max(zones[i].zw, vec2(1.0));
		float mask = pow(max(0.0, 1.0 - dot(q, q)), 2.0);
		float pulse = sin(motion_clock * 3.7 + zone_motion[i].w);
		displacement += zone_motion[i].xy * zone_motion[i].z * pulse * mask;
	}
	// Source coordinates, atlas scale and the feet remain fixed. Only painted
	// head/hair/arm/torso neighborhoods move; no whole-cutout translation.
	float fixed_foot_mask = 1.0 - smoothstep(feet_fixed_y - 30.0, feet_fixed_y, source_px.y);
	float prop_mask = 1.0;
	for (int i = 0; i < 4; i++) {
		if (i >= fixed_count) { break; }
		vec2 low = fixed_regions[i].xy;
		vec2 high = low + fixed_regions[i].zw;
		float inside = step(low.x, source_px.x) * step(low.y, source_px.y) * step(source_px.x, high.x) * step(source_px.y, high.y);
		prop_mask *= 1.0 - inside;
	}
	displacement *= motion_strength * fixed_foot_mask * prop_mask;
	float total_shift = length(displacement);
	if (total_shift > max_displacement_source_px) {
		displacement *= max_displacement_source_px / max(total_shift, 0.001);
	}
	vec2 sample_uv = UV - displacement / canvas_size;
	vec2 half_texel = vec2(0.5) / canvas_size;
	sample_uv = clamp(sample_uv, source_region.xy + half_texel, source_region.xy + source_region.zw - half_texel);
	vec4 pigment = texture(TEXTURE, sample_uv);
	COLOR = pigment * paint_tint;
}
