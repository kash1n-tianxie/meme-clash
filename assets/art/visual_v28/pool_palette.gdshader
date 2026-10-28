shader_type canvas_item;
render_mode unshaded;

uniform vec2 painted_pixel_size = vec2(0.0006906077, 0.0009208103);
uniform float unification_strength : hint_range(0.0, 1.0) = 1.0;
varying vec4 stage_tint;

void vertex() { stage_tint = COLOR; }

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    vec3 painted = source.rgb;
    float luminance = dot(painted, vec3(0.2126, 0.7152, 0.0722));
    // Only the authored pool plate receives depth grading. Its feather bands
    // keep their true atlas UV, while sky continuation shares the base grade.
    float plate = 1.0 - step(0.0000001,
        abs(TEXTURE_PIXEL_SIZE.x - painted_pixel_size.x) +
        abs(TEXTURE_PIXEL_SIZE.y - painted_pixel_size.y));
    float mid_height = smoothstep(0.12, 0.24, UV.y) *
        (1.0 - smoothstep(0.66, 0.77, UV.y));
    float center = smoothstep(0.0, 0.22, UV.x) *
        (1.0 - smoothstep(0.78, 1.0, UV.x));
    float depth = plate * mid_height * center;
    // The sea remains blue and the paving warm. Midground palms, bottles and
    // railings lose a little micro-contrast so bodies and skill colors read.
    vec3 ink = mix(vec3(luminance), painted, 0.95 - depth * 0.12);
    ink = mix(ink, (ink - vec3(0.47)) * 0.87 + vec3(0.47), depth * 0.70);
    ink *= vec3(0.982, 0.995, 1.003);
    ink = mix(ink, ink * vec3(0.96, 0.985, 1.025), depth * 0.48);
    COLOR = vec4(mix(painted, ink, unification_strength), source.a) * stage_tint;
}
