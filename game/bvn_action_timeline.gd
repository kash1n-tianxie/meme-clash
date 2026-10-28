extends RefCounted
## Copyright (C) 2021-2026 5DPLAY Game Studio; Godot adaptation (C) 2026.
## SPDX-License-Identifier: GPL-3.0-or-later
## Public FlashSrc commit 4d8174bb51009ca62a477bd7dd62f50a7f3ab049.
## ninja1/main_mc.xml + active LIBRARY/一护全动作.xml, not the unused AS2 backup.
## FighterMcCtrler.as:352-359 (setAttack),563-572 (endAct),166-217 (idle).
## FighterMC.as:460-535 and FighterHitModel.as:61-74 identify body/hit instances.
## Pure timeline data. The caller owns movement, input latches, collisions and rendering.
## See assets/logic/bvn-ninja1-normal.json and third_party/5DPLAY-BVN/ACTION_TIMELINE_PORT.txt.

const DATA_PATH := "res://assets/logic/bvn-ninja1-normal.json"
const SOURCE_FPS := 30.0
const SOURCE_COMMIT := "4d8174bb51009ca62a477bd7dd62f50a7f3ab049"
static var _data: Dictionary = {}

static func _load_source() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary: _data = parsed
	return _data

static func raw_data() -> Dictionary:
	return _load_source().duplicate(true)

## Converts wall-clock action time to a zero-based source animation frame.
## Prefer sample_normal_frame with your actual 30Hz tick for deterministic integration.
static func source_frame(elapsed_seconds: float) -> int:
	return maxi(0, int(floor(maxf(0.0, elapsed_seconds) * SOURCE_FPS + 0.000001)))

static func normal_definition(normal: int) -> Dictionary:
	var source := _load_source()
	var id := "normal%d" % normal
	if normal < 1 or normal > 3 or not source.get("normals", {}).has(id): return {}
	var result: Dictionary = source["normals"][id].duplicate(true)
	result["startup"] = float(result["startup_frames"]) / SOURCE_FPS
	result["active"] = float(result["active_frames"]) / SOURCE_FPS
	result["recovery"] = float(result["recovery_frames"]) / SOURCE_FPS
	result["total"] = float(result["total_frames_until_idle"]) / SOURCE_FPS
	result["damage"] = int(result["hit_vo_effective"]["power"])
	return result

static func sample_normal(normal: int, elapsed_seconds: float) -> Dictionary:
	return sample_normal_frame(normal, source_frame(elapsed_seconds))

## Permissions arise from entered setAttack events and disappear at endAct.
## The source window allows the next J even on whiff; no authored hit-confirm gate exists here.
static func sample_normal_frame(normal: int, frame: int) -> Dictionary:
	var definition := normal_definition(normal)
	if definition.is_empty(): return {"ready": false}
	frame = maxi(0, frame)
	var target_label := ""
	var next_normal := 0
	var ended := false
	var idle := frame >= int(definition["idle_frame"])
	for event: Dictionary in definition["events"]:
		if int(event["relative_frame"]) > frame: continue
		for call: Dictionary in event["calls"]:
			if call["controller"] != "mc_ctrler": continue
			match str(call["method"]):
				"setAttack":
					target_label = str(call["arguments"][0])
					next_normal = 2 if target_label == "砍2" else (3 if target_label == "砍3" else 0)
					ended = false
				"endAct":
					target_label = ""
					next_normal = 0
					ended = true
				"idle":
					target_label = ""
					next_normal = 0
					ended = false
	var active := false
	if not idle:
		for interval: Array in definition["active_intervals"]:
			if frame >= int(interval[0]) and frame < int(interval[1]): active = true
	var phase := "idle" if idle else ("active" if active else ("startup" if frame < int(definition["startup_frames"]) else "recovery"))
	return {
		"ready": true, "id": definition["id"], "source_label": definition["source_label"],
		"source_frame": frame, "source_absolute_index": int(definition["source_start_index"]) + frame,
		"phase": phase, "active": active, "idle": idle,
		"can_chain": not idle and next_normal > 0, "next_normal": next_normal,
		"target_label": target_label, "ended_permissions": ended,
		"action_slots": {"attack": target_label} if not target_label.is_empty() else {},
		"hit_vo": definition["hit_vo_effective"].duplicate(true),
		"body_rect_source": _rect(definition["body_rect_source"]),
		"hit_rect_source": _rect(definition["hit_rect_source"]),
		"events": events_between(normal, frame - 1, frame)
	}

static func normal_target(normal: int, elapsed_seconds: float) -> int:
	return int(sample_normal(normal, elapsed_seconds).get("next_normal", 0))

## Delivers each entered frame event once even when the caller skips several source frames.
## previous_frame=-1 includes the initial frame. Events past idle are never delivered.
static func events_between(normal: int, previous_frame: int, current_frame: int) -> Array[Dictionary]:
	var definition := normal_definition(normal)
	var result: Array[Dictionary] = []
	if definition.is_empty() or current_frame <= previous_frame: return result
	for event: Dictionary in definition["events"]:
		var frame := int(event["relative_frame"])
		if frame > previous_frame and frame <= current_frame and frame <= int(definition["idle_frame"]):
			result.append(event.duplicate(true))
	return result

static func _rect(values: Array) -> Rect2:
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))

## Godot meme-art adapter: preserve the original shape, uniformly normalize to body height,
## and register at foot centre. Target height is already in world px; do not multiply by1.6 again.
static func normalized_hit_rect(normal: int, body_height: float, facing: int = 1) -> Rect2:
	var definition := normal_definition(normal)
	if definition.is_empty() or body_height <= 0: return Rect2()
	var body := _rect(definition["body_rect_source"])
	var hit := _rect(definition["hit_rect_source"])
	var anchor := Vector2(body.get_center().x, body.end.y)
	var scale := body_height / body.size.y
	var start := (hit.position - anchor) * scale
	var size := hit.size * scale
	if facing < 0: start.x = -start.x - size.x
	return Rect2(start, size)

static func normalized_body_rect(normal: int, body_height: float) -> Rect2:
	var definition := normal_definition(normal)
	if definition.is_empty() or body_height <= 0: return Rect2()
	var body := _rect(definition["body_rect_source"])
	var scale := body_height / body.size.y
	return Rect2(-body.size.x * scale * .5, -body_height, body.size.x * scale, body_height)
