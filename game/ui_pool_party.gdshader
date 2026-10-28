shader_type canvas_item;
render_mode unshaded;
// Only small hand-annotated parts of the one coherent painting articulate.
// UVs outside the masks, the poster, shoes and all contact shadows remain unchanged.
uniform int zone_count = 0;
uniform vec4 zones[24];
uniform vec4 zone_parameters[24];
uniform vec4 zone_pivots[24];
uniform vec4 zone_exclude_a[24];
uniform vec4 zone_exclude_b[24];
uniform vec2 water_polygon[12];
uniform vec4 water_exclusions[8];
uniform vec4 speakers[2];
uniform float beat_time = 0.0;
uniform float motion_clock = 0.0;
uniform float motion_amount = 1.0;
uniform float menu_response = 0.0;
uniform bool menu_confirm = false;
varying vec4 painting_tint;

void vertex() { painting_tint = COLOR; }

float rect_mask(vec2 uv, vec4 rect) {
    if (rect.z <= 0.0 || rect.w <= 0.0) { return 0.0; }
    return step(rect.x, uv.x) * step(rect.y, uv.y) * step(uv.x, rect.x + rect.z) * step(uv.y, rect.y + rect.w);
}

float ellipse_mask(vec2 uv, vec4 ellipse) {
    vec2 q = (uv - ellipse.xy) / max(ellipse.zw, vec2(0.00001));
    return 1.0 - smoothstep(0.62, 1.0, length(q));
}

bool inside_pool(vec2 uv) {
    bool inside = false;
    for (int i = 0; i < 12; i++) {
        vec2 a = water_polygon[i];
        vec2 b = water_polygon[(i + 11) % 12];
        if ((a.y > uv.y) != (b.y > uv.y)) {
            float crossing = (b.x - a.x) * (uv.y - a.y) / (b.y - a.y) + a.x;
            if (uv.x < crossing) { inside = !inside; }
        }
    }
    return inside;
}

void fragment() {
    vec2 uv = UV;
    vec2 pixel = uv * vec2(1280.0, 720.0);
    vec2 displacement = vec2(0.0);
    if (uv.x > 0.38 && uv.y < 0.871 && motion_amount > 0.0) {
        for (int i = 0; i < 24; i++) {
            if (i >= zone_count) { break; }
            vec4 zone = zones[i];
            if (abs(uv.x - zone.x) > zone.z || abs(uv.y - zone.y) > zone.w) { continue; }
            vec4 rule = zone_parameters[i];
            vec4 pivot = zone_pivots[i];
            float weight = ellipse_mask(uv, zone) * (1.0 - smoothstep(pivot.z - 0.022, pivot.z, uv.y));
            weight *= 1.0 - max(rect_mask(uv, zone_exclude_a[i]), rect_mask(uv, zone_exclude_b[i]));
            float wave = sin(beat_time * 6.28318530718 / max(rule.z, 1.0) + rule.x);
            float radius = max(zone.z * 1280.0, zone.w * 720.0);
            vec2 from_joint = pixel - pivot.xy * vec2(1280.0, 720.0);
            float angle = wave * rule.y / max(radius * 1.35, 1.0);
            // Rio's existing painted free-arm region acknowledges a focus change without scaling her body.
            if (pivot.w < 0.5 && i == 1) {
                angle += menu_response * 0.012;
            }
            vec2 local;
            if (rule.w > 1.5) {
                local = from_joint * wave * 0.013;
            } else if (rule.w > 0.5) {
                local = vec2(wave * rule.y, sin(beat_time * 6.28318530718 / 8.0 + rule.x) * rule.y * 0.22);
            } else {
                float c = cos(angle);
                float s = sin(angle);
                local = vec2(c * from_joint.x - s * from_joint.y, s * from_joint.x + c * from_joint.y) - from_joint;
            }
            displacement += local * weight;
        }
        // Never exceed the art review's 1.5 logical pixel limit, even where masks overlap.
        float length_px = length(displacement);
        displacement *= min(1.0, 1.5 / max(length_px, 0.0001)) * motion_amount;
    }
    vec2 articulated_uv = uv + displacement / vec2(1280.0, 720.0);
    vec4 source = texture(TEXTURE, articulated_uv);
    float water = 0.0;
    if (uv.x > 0.38 && uv.y > 0.397 && uv.y < 0.665 && motion_amount > 0.0) {
        water = inside_pool(uv) ? 1.0 : 0.0;
        for (int i = 0; i < 8; i++) {
            water *= 1.0 - rect_mask(uv, water_exclusions[i]);
        }
        // Color shimmer only: the water polygon, stone coping, ladder and background never stretch.
        water *= smoothstep(0.14, 0.27, source.b - source.r) * smoothstep(0.12, 0.25, source.g - source.r);
        float ripple = sin(pixel.x * 0.10 + pixel.y * 0.07 + motion_clock * 1.0) * sin(pixel.y * 0.19 - motion_clock * 0.65);
        source.rgb += vec3(0.008, 0.016, 0.018) * ripple * water * motion_amount;
    }
    if (motion_amount > 0.0) {
        float pulse = pow(1.0 - fract(beat_time), 3.0);
        for (int i = 0; i < 2; i++) {
            float cone = ellipse_mask(uv, speakers[i]);
            source.rgb += vec3(0.010, 0.023, 0.025) * cone * pulse * motion_amount;
        }
    }
    COLOR = vec4(source.rgb * painting_tint.rgb, source.a * painting_tint.a);
}
