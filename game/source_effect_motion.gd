extends RefCounted
## Presentation only. The caller supplies actual source HitVO areas and the
## actor-relative or independent-object source clock. No combat timer, hit area,
## resource, action permission or random number is created or changed here.
const Pixel = preload("res://game/pixel_fighter.gd")
const PaintedMotion = preload("res://game/skill_effect_motion.gd")
const CACHE_LIMIT := 128
static var _prepared: Dictionary = {}
static var _prepared_builds := 0

## Consecutive rectangles of the same registered HitVO form one visual release.
## A real inactive gap remains a separate interval; different HitVOs never merge.
static func derive_intervals(areas: Array, hit_id: String, frame_space: String = "relative", area_kind: String = "hit") -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if frame_space not in ["relative", "absolute"] or hit_id.is_empty(): return candidates
	for value: Variant in areas:
		if not value is Dictionary: continue
		var area: Dictionary = value
		if str(area.get("kind", "")) != area_kind or bool(area.get("unregistered_hit", false)): continue
		# Bullet.setHitVO supplies its id independently of the child main collider.
		# This exception requires the caller's explicit bullet_main kind.
		if area_kind != "bullet_main" and _hit_id(area) != hit_id: continue
		var start_key := "relative_start" if frame_space == "relative" else "source_start"
		var end_key := "relative_end" if frame_space == "relative" else "source_end"
		if not area.has(start_key) or not area.has(end_key): continue
		var start: float = float(area[start_key])
		var end: float = float(area[end_key])
		if not is_finite(start) or not is_finite(end) or end <= start: continue
		candidates.append({"start":start, "end":end, "hit_id":hit_id, "segments":1})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["start"] < b["start"] if a["start"] != b["start"] else a["end"] < b["end"])
	var merged: Array[Dictionary] = []
	for interval: Dictionary in candidates:
		if not merged.is_empty() and float(interval["start"]) <= float(merged[-1]["end"]):
			merged[-1]["end"] = maxf(float(merged[-1]["end"]), float(interval["end"]))
			merged[-1]["segments"] = int(merged[-1]["segments"]) + 1
		else: merged.append(interval.duplicate())
	return merged

static func _hit_id(area: Dictionary) -> String:
	return str(area.get("source_name", area.get("hit_id", area.get("id", ""))))

static func _clip(clip: String) -> String:
	return str(Pixel.EFFECT_ALIASES.get(clip, {"air_super":"super", "launcher":"skill2", "sweep":"skill3", "air_skill":"skill3", "air_slam":"skill3"}.get(clip, Pixel.ALIASES.get(clip,clip))))

static func _not_ready(reason: String) -> Dictionary:
	return {"ready":false, "reason":reason, "source_kind":"source_clock_painted_effect"}

## Prepare once per source label/HitVO, then pass the returned descriptor as
## context.prepared. It contains no moving rectangle, clock, action RNG or Node.
## The bounded fallback cache also reuses the original UV topology/texture.
static func prepare(context: Dictionary) -> Dictionary:
	var id: String = str(context.get("id", ""))
	var clip: String = _clip(str(context.get("clip", "")))
	var hit_id: String = str(context.get("hit_id", ""))
	var space: String = str(context.get("frame_space", "relative"))
	var area_kind: String = str(context.get("area_kind", "hit"))
	var areas: Variant = context.get("areas", [])
	if not areas is Array or areas.is_empty(): return _not_ready("missing source intervals")
	var key: String = id+"|"+clip+"|"+hit_id+"|"+space+"|"+area_kind
	# Optional immutable definition identity supplied by the caller (actor entry
	# label, or child source_symbol). It must never include serial/frame/area.
	# This lookup avoids even the interval scan on subsequent production draws.
	var definition_key: String = str(context.get("definition_key", ""))
	if not definition_key.is_empty():
		key += "|definition:"+definition_key
		if _prepared.has(key): return _prepared[key]
	var intervals := derive_intervals(areas, hit_id, space, area_kind)
	if intervals.is_empty(): return _not_ready("missing source intervals")
	if definition_key.is_empty():
		for interval: Dictionary in intervals:
			key += "|%s:%s:%s" % [interval["start"],interval["end"],interval["segments"]]
	if _prepared.has(key): return _prepared[key]
	var painted: Dictionary = Pixel.get_effect_state(id, clip, 0.4)
	if not bool(painted.get("ready", false)) or bool(painted.get("contains_character", true)):
		return _not_ready("missing character-free painted clip")
	var texture_path: String = str(painted.get("texture", ""))
	var texture: Texture2D = Pixel._texture(texture_path)
	if texture == null: return _not_ready("missing painted texture")
	var source: Variant = painted.get("source_rect", null)
	if not source is Array or source.size() != 4: return _not_ready("missing painted source region")
	var region := Rect2(float(source[0]), float(source[1]), float(source[2]), float(source[3]))
	if not region.has_area() or not region.position.is_finite() or not region.size.is_finite() or region.position.x < 0 or region.position.y < 0 or region.end.x > texture.get_width() or region.end.y > texture.get_height():
		return _not_ready("invalid painted source region")
	var direction: String = str(painted.get("direction", ""))
	if direction.is_empty(): return _not_ready("missing painted direction")
	# Reuse the existing painted release's exact original UV grid and identities.
	# This immutable prototype is created once, never once per draw.
	var prototype: Dictionary = PaintedMotion.sample(painted)
	var grid: Array[Rect2] = []
	for piece: Dictionary in prototype["pieces"]: grid.append(piece["uv_rect"])
	if grid.is_empty(): return _not_ready("missing painted topology")
	for interval: Dictionary in intervals: interval.make_read_only()
	intervals.make_read_only()
	grid.make_read_only()
	var result := {"ready":true, "id":id, "clip":painted["clip"], "hit_id":hit_id, "frame_space":space, "area_kind":area_kind, "intervals":intervals, "texture":texture, "texture_path":texture_path, "source_rect":region, "direction":direction, "grid":grid, "spark_count":prototype["sparks"].size(), "spark_style":str(prototype["sparks"][0]["style"]) if not prototype["sparks"].is_empty() else "blade", "color":prototype["color"], "major":prototype["major"], "contains_character":false}
	result.make_read_only()
	if _prepared.size() >= CACHE_LIMIT: _prepared.erase(_prepared.keys()[0])
	_prepared[key] = result
	_prepared_builds += 1
	return result

static func cache_stats() -> Dictionary:
	return {"prepared":_prepared.size(), "limit":CACHE_LIMIT, "builds":_prepared_builds}

## Offline asset refresh/test teardown; does not touch Pixel's texture cache.
static func clear_cache() -> void:
	_prepared.clear()
	_prepared_builds = 0

## Required context:
## id, clip, hit_id, source_frame (float), areas, area (actual world Rect2).
## frame_space: relative for an actor action definition; absolute for child data.
## Optional: facing (+/-1), area_kind (hit or explicit bullet_main), hit_active.
## source_frame may contain source_clock*30. A frozen source clock freezes both
## life phase and the continuous flow field, independently of render frame rate.
static func sample(context: Dictionary) -> Dictionary:
	if not bool(context.get("hit_active", true)) or bool(context.get("removed", false)):
		return _not_ready("inactive source hit")
	var id: String = str(context.get("id", ""))
	var clip: String = _clip(str(context.get("clip", "")))
	var hit_id: String = str(context.get("hit_id", ""))
	var clock: Variant = context.get("source_frame", null)
	var raw_area: Variant = context.get("area", null)
	if not (clock is int or clock is float) or not is_finite(float(clock)):
		return _not_ready("missing or nonfinite source clock")
	if not raw_area is Rect2: return _not_ready("missing source world area")
	var box: Rect2 = raw_area
	if not box.has_area() or not box.position.is_finite() or not box.size.is_finite():
		return _not_ready("invalid source world area")
	var facing: int = int(context.get("facing", 1))
	if facing not in [-1, 1]: return _not_ready("invalid facing")
	var prepared: Dictionary = context.get("prepared", {})
	if prepared.is_empty(): prepared = prepare(context)
	if not bool(prepared.get("ready", false)): return _not_ready(str(prepared.get("reason", "missing prepared paint")))
	if prepared["id"] != id or prepared["clip"] != clip or prepared["hit_id"] != hit_id or prepared["frame_space"] != str(context.get("frame_space", "relative")) or prepared["area_kind"] != str(context.get("area_kind", "hit")):
		return _not_ready("prepared descriptor identity mismatch")
	var intervals: Array = prepared["intervals"]
	var interval: Dictionary = {}
	var frame: float = float(clock)
	for candidate: Dictionary in intervals:
		if frame >= float(candidate["start"]) and frame < float(candidate["end"]):
			interval = candidate
			break
	if interval.is_empty(): return _not_ready("outside source hit interval")
	var direction: String = prepared["direction"]
	var elapsed: float = frame - float(interval["start"])
	var phase: float = elapsed / (float(interval["end"]) - float(interval["start"]))
	# Start after the legacy reveal: the very first active frame is fully readable.
	# Tail erosion leaves a 55% core across the full original alpha silhouette.
	# No part of an effective source interval becomes wholly invisible.
	var paint_phase := lerpf(0.27, 0.82, phase)
	var vertical := direction in ["rising", "sky_fan"]
	# Same erosion field as PaintedMotion, sampled directly over its cached UV
	# grid. A bright core is added; no second dynamic mesh/deep-copy is needed.
	var erosion_front := smoothstep(0.61, 1.0, paint_phase)*1.50-0.30
	var settle := smoothstep(0.72, 1.0, phase)
	var amplitude := minf(4.0, minf(box.size.x, box.size.y)*0.06)*(1.0-settle*0.60)
	var pieces: Array[Dictionary] = []
	for uv_rect: Rect2 in prepared["grid"]:
		var points := PackedVector2Array()
		var alphas := PackedFloat32Array()
		for index in range(4):
			var corner: Vector2 = [Vector2.ZERO, Vector2(1,0), Vector2.ONE, Vector2(0,1)][index]
			var uv: Vector2 = uv_rect.position + corner*uv_rect.size
			var at: Vector2 = uv*box.size
			var along: float = 1.0-uv.y if vertical else uv.x
			# Source-time flow never resets the overall expansion/erosion phase.
			var wave: float = sin(along*TAU*1.5-elapsed*0.32)*sin(uv.x*PI)*sin(uv.y*PI)*amplitude
			if vertical: at.x += wave
			else: at.y += wave
			at = at.clamp(Vector2.ZERO, box.size)
			points.append(at)
			var across: float = uv.x if vertical else uv.y
			var erosion: float = 1.0-smoothstep(along-0.14+across*0.04, along+0.14+across*0.04, erosion_front)
			alphas.append(0.55+0.45*erosion)
		pieces.append({"points":points, "uv_rect":uv_rect, "alphas":alphas, "opacity":_max_alpha(alphas)})
	var sparks: Array[Dictionary] = []
	for index in range(int(prepared["spark_count"])):
		var travel := fposmod(elapsed*0.045+float(index)*0.173, 1.0)
		var across := 0.20+float(index%3)*0.27
		var position := Vector2(across*box.size.x, (1.0-travel)*box.size.y) if vertical else Vector2(travel*box.size.x, across*box.size.y)
		var tail := Vector2(0, -minf(12,box.size.y*0.08)) if vertical else Vector2(minf(14,box.size.x*0.08),0)
		sparks.append({"position":position, "tail":tail, "opacity":sin(travel*PI)*0.6*(1.0-settle*0.85), "style":prepared["spark_style"]})
	return {"ready":true, "id":id, "clip":prepared["clip"], "hit_id":hit_id, "source_frame":frame, "frame_space":context.get("frame_space", "relative"), "interval":interval.duplicate(), "phase":phase, "paint_phase":paint_phase, "flow_clock":elapsed, "area":box, "origin":box.position, "world_size":box.size, "anchor":Vector2.ZERO, "facing":facing, "texture":prepared["texture"], "texture_path":prepared["texture_path"], "source_rect":prepared["source_rect"], "pieces":pieces, "sparks":sparks, "color":prepared["color"], "major":prepared["major"], "alpha_floor":0.55, "source_kind":"source_clock_painted_effect", "contains_character":false}

static func _max_alpha(values: PackedFloat32Array) -> float:
	var result := 0.0
	for value in values: result = maxf(result, value)
	return result

## Draws world-space points; leaves the caller's draw transform unchanged.
## The original texture/source-alpha and actual source box stay authoritative.
static func draw(canvas: CanvasItem, state: Dictionary, tint: Color = Color.WHITE) -> void:
	if not bool(state.get("ready", false)): return
	var texture: Texture2D = state["texture"]
	var region: Rect2 = state["source_rect"]
	for piece: Dictionary in state["pieces"]:
		var points := PackedVector2Array()
		for point: Vector2 in piece["points"]: points.append(_world_point(state, point))
		var uvs := PackedVector2Array()
		var uv_rect: Rect2 = piece["uv_rect"]
		for corner: Vector2 in [Vector2.ZERO, Vector2(1,0), Vector2.ONE, Vector2(0,1)]:
			uvs.append((region.position+(uv_rect.position+corner*uv_rect.size)*region.size)/texture.get_size())
		var colors := PackedColorArray()
		for alpha: float in piece["alphas"]:
			var color := tint
			color.a *= alpha
			colors.append(color)
		canvas.draw_polygon(points, colors, uvs, texture)
	for spark: Dictionary in state["sparks"]:
		var color: Color = state["color"]*tint
		color.a *= float(spark["opacity"])
		var head: Vector2 = spark["position"]
		var tail: Vector2 = (head-spark["tail"]).clamp(Vector2.ZERO, state["world_size"])
		canvas.draw_line(_world_point(state, tail), _world_point(state, head), color, 2, false)

static func _world_point(state: Dictionary, local: Vector2) -> Vector2:
	if int(state["facing"]) < 0: local.x = float(state["world_size"].x)-local.x
	return state["origin"]+local
