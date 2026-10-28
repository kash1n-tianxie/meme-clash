shader_type canvas_item;
render_mode unshaded;
uniform vec2 canvas_size = vec2(1672.0,941.0);
uniform vec4 water_region = vec4(680.0,414.0,820.0,245.0);
uniform vec4 speaker_regions[2];
uniform float music_seconds = 0.0;
uniform float motion_strength = 1.0;
varying vec4 paint_tint;
void vertex() { paint_tint = COLOR; }
void fragment() {
	vec2 p = UV * canvas_size;
	vec2 q = (p-water_region.xy)/max(water_region.zw,vec2(1.0));
	float water_mask = smoothstep(0.02,0.12,q.x) * (1.0-smoothstep(0.88,0.98,q.x)) * smoothstep(0.10,0.22,q.y) * (1.0-smoothstep(0.80,0.95,q.y));
	float wave = sin(p.x*0.025+music_seconds*1.6)*cos(p.y*0.025-music_seconds*0.9)*0.55;
	vec2 sample_uv = UV + vec2(0.0,wave*water_mask*motion_strength)/canvas_size;
	vec4 paint = texture(TEXTURE,sample_uv);
	float beat = pow(1.0-fract(music_seconds*160.0/60.0),3.0);
	for (int i = 0; i < 2; i++) {
		vec2 r = (p-speaker_regions[i].xy)/max(speaker_regions[i].zw,vec2(1.0));
		float mask = step(0.0,r.x)*step(r.x,1.0)*step(0.0,r.y)*step(r.y,1.0);
		paint.rgb += vec3(0.014,0.025,0.026)*mask*beat*motion_strength;
	}
	COLOR = paint*paint_tint;
}
