shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D scene_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 flash_colors[8];
uniform int flash_dark[8];
uniform int flash_count = 0;
void fragment() {
	vec4 scene = texture(scene_texture, SCREEN_UV);
	for (int i = 0; i < 8; i++) {
		if (i >= flash_count) break;
		vec4 flash = flash_colors[i];
		if (flash_dark[i] == 1) {
			scene.rgb = mix(scene.rgb, min(scene.rgb, flash.rgb), flash.a);
		} else {
			scene.rgb = min(vec3(1.0), scene.rgb + flash.rgb * flash.a);
		}
	}
	COLOR = scene;
}
