shader_type canvas_item;
render_mode unshaded;

// The UV mesh owns motion. This pass only places its single body in pool light.
uniform vec4 frame_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float unification_strength : hint_range(0.0, 1.0) = 1.0;
varying vec4 body_tint;
void vertex() { body_tint = COLOR; }
void fragment() {
    vec4 texel = texture(TEXTURE, UV);
    vec2 step_uv = TEXTURE_PIXEL_SIZE;
    vec2 lo = frame_region.xy + step_uv * 0.5;
    vec2 hi = frame_region.xy + frame_region.zw - step_uv * 0.5;
    float neighbor = min(min(texture(TEXTURE, clamp(UV + vec2(step_uv.x, 0.0), lo, hi)).a,
                             texture(TEXTURE, clamp(UV - vec2(step_uv.x, 0.0), lo, hi)).a),
                         min(texture(TEXTURE, clamp(UV + vec2(0.0, step_uv.y), lo, hi)).a,
                             texture(TEXTURE, clamp(UV - vec2(0.0, step_uv.y), lo, hi)).a));
    float brightest = max(texel.r, max(texel.g, texel.b));
    float darkest = min(texel.r, min(texel.g, texel.b));
    // Soften only bright neutral alpha-border pixels, preserving skin/eyes.
    float pale_edge = smoothstep(0.84, 0.98, darkest) *
                      (1.0 - smoothstep(0.05, 0.19, brightest - darkest)) *
                      (1.0 - smoothstep(0.05, 0.55, neighbor));
    vec3 ink = mix(texel.rgb, texel.rgb * vec3(0.73, 0.78, 0.83), pale_edge * 0.55);
    // Share the stage's blue-black cel ink while preserving each meme's own
    // bright palette and the painted light/shadow planes.
    float dark_ink = 1.0 - smoothstep(0.075, 0.20, brightest);
    ink = mix(ink, vec3(0.07, 0.14, 0.22), dark_ink * 0.60);
    float local_height = 1.0 - clamp((UV.y - frame_region.y) / frame_region.w, 0.0, 1.0);
    vec3 pool_light = mix(vec3(0.94, 0.97, 1.02), vec3(1.035, 1.012, 0.975), local_height);
    vec3 baseline = ink * pool_light;
    // A common interior-edge ink integrates photographic fur, flat office
    // art and painted fighters without expanding any sprite's alpha contour.
    float inner_edge = (1.0 - smoothstep(0.12, 0.75, neighbor)) *
                       smoothstep(0.30, 0.95, texel.a);
    vec3 navy = vec3(0.055, 0.115, 0.19);
    vec3 unified = mix(ink, navy, pale_edge * 0.24);
    unified = mix(unified, unified * vec3(0.88, 0.94, 1.02), inner_edge * 0.30);
    float luminance = dot(unified, vec3(0.2126, 0.7152, 0.0722));
    unified = mix(vec3(luminance), unified, 0.94);
    // Warm high key light and cool reflected water belong to the body plane,
    // including all new turn/recovery/hit poses through frame_region.
    vec3 integrated_light = mix(vec3(0.922, 0.970, 1.044),
                                vec3(1.027, 1.012, 0.975), local_height);
    unified *= integrated_light;
    COLOR = vec4(mix(baseline, unified, unification_strength) * body_tint.rgb,
                 texel.a * body_tint.a);
}
