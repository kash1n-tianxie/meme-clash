extends RefCounted
## Drawing-only reaction stages. Source positions, HitVO, state, freeze and
## frame clocks are read but are never set or advanced in this module.
const PATH := "res://assets/fighters/v029/reactions/reaction-sequences.json"
const AIR_OVERLAY_V032 := "res://assets/fighters/v032/air-reactions/air-reaction-overlay.json"
const ROSTER_AIR_V034 := "res://assets/fighters/v034/reaction-air-map.json"
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed
			if FileAccess.file_exists(AIR_OVERLAY_V032):
				var overlay: Variant = JSON.parse_string(FileAccess.get_file_as_string(AIR_OVERLAY_V032))
				if overlay is Dictionary:
					# Append original new art only; the old endpoints, captured/holder,
					# ground mappings and metadata remain byte-equivalent on disk.
					for id: String in overlay.get("fighters", {}):
						if not _data.get("fighters", {}).has(id): continue
						var actor: Dictionary = _data["fighters"][id]
						var extra: Dictionary = overlay["fighters"][id]
						actor["sheets"].merge(extra.get("sheets", {}), false)
						actor["frames"].merge(extra.get("frames", {}), false)
						actor["air_sequences_v032"] = extra.get("air_sequences_v032", {}).duplicate(true)
					_data["new_air_cels_v032"] = int(overlay.get("registered_cels", 0))
			if FileAccess.file_exists(ROSTER_AIR_V034):
				var roster: Variant=JSON.parse_string(FileAccess.get_file_as_string(ROSTER_AIR_V034))
				if roster is Dictionary:_data.get("fighters",{}).merge(roster.get("fighters",{}),false)
	return _data

static func clear() -> void:
	_data.clear()

static func ground_family(family: String) -> String:
	if family in ["ball_belly", "cat_squeeze", "shark_bite"]: return "belly"
	if family in ["ball_head", "wave_lift"]: return "lift"
	if family in ["sword_drop", "cat_slam", "stamp_crush"]: return "crush"
	return "side"

static func reaction_stage(context: Dictionary) -> String:
	var age: float = maxf(0.0, float(context.get("state_time", 0.0)))
	var length: float = maxf(.035, float(context.get("reaction_hurt_length", .30)))
	if age < minf(.025, length * .10): return "contact"
	if age < minf(.115, length * .46): return "peak"
	if age < minf(.220, length * .83): return "rebound"
	return "stable"

static func _cel(id: String, key: String) -> String:
	return str(data().get("fighters", {}).get(id, {}).get("air", {}).get(key, ""))

static func _air_join_v032(id: String, key: String, progress: float) -> String:
	var sequence: Array = data().get("fighters", {}).get(id, {}).get("air_sequences_v032", {}).get(key, [])
	if sequence.is_empty(): return _cel(id, key)
	# One-way progression ends on the real v029 endpoint. No wall clock,
	# counter, looping, random offset, source-frame mutation or actor write.
	var t: float = clampf(progress, 0.0, 1.0)
	return str(sequence[mini(sequence.size()-1, int(t*float(sequence.size())))])

static func pose_for(id: String, context: Dictionary, family: String) -> String:
	var state: String = str(context.get("state", ""))
	# A real source get-up/recovery may itself leave the floor. Its archived
	# animation must win in both grounded and airborne states.
	if state in ["ko", "guard", "guard_stun", "attack", "dash", "getup"]: return ""
	var record: Dictionary = context.get("reaction_identity", {})
	if record.is_empty() or str(record.get("outcome", "")) != "hit": return ""
	if not state in ["hurt", "launch", "juggle", "slam", "throw_hold", "down", "getup"]: return ""
	var pair: Dictionary = context.get("reaction_source_pair_v029", {})
	var held: bool = bool(pair.get("active", false)) and pair.get("binding", "") in ["cat:super", "cat:super_down"]
	if state == "throw_hold" or held: return _cel(id, "captured")
	var velocity: Vector2 = context.get("reaction_velocity", Vector2.ZERO)
	var fly_phase: int = int(context.get("reaction_fly_phase_v029", 0))
	if not bool(context.get("grounded", true)):
		# BVN stores falling G apart from public vy. The existing renderer
		# supplies their actual sum; synthetic legacy callers may still use vy.
		var vertical: float = float(context.get("motion_vertical_speed_v031", velocity.y))
		var age: float = maxf(0.0, float(context.get("state_time", 0.0)))
		if fly_phase == 3 or str(context.get("current_label", "")) == "击飞_弹": return _air_join_v032(id, "rebound", age/.16)
		if vertical > 85.0 or state == "slam" or fly_phase == 2:
			var descent: float = clampf((vertical-85.0)/600.0, 0.0, 1.0)
			if state == "slam": descent = maxf(descent, clampf(age/.18, 0.0, 1.0))
			return _air_join_v032(id, "falling", descent)
		if fly_phase == 1 and age > .14: return _air_join_v032(id, "flip", (age-.14)/.16)
		if vertical < -85.0 or family in ["ball_head", "wave_lift"]: return _air_join_v032(id, "lift", age/.14)
		return _cel(id, "side")
	# A real get-up keeps its archived source animation. Never replace it with
	# an upright captive or early standing cel while invulnerable/on the floor.
	if state == "getup": return ""
	var stage: String = reaction_stage(context)
	if state == "down":
		stage = "peak" if float(context.get("state_time", 0.0)) < .07 else "rebound"
		family = "stamp_crush"
	var spec: Dictionary = data().get("fighters", {}).get(id, {})
	return str(spec.get("ground", {}).get(ground_family(family), {}).get(stage, ""))

static func pair_victim_override(id: String, owner_context: Dictionary) -> String:
	# Used only in the existing source-owned hidden-victim draw. No second body
	# is added, and visible victims are handled by pose_for instead.
	if str(owner_context.get("binding_id", "")) != "cat:super": return ""
	if bool(owner_context.get("paired_target_visible", true)): return ""
	if int(owner_context.get("paired_target_index", -1)) < 0: return ""
	var label: String = str(owner_context.get("current_label", ""))
	if label == "必杀_TF": return _cel(id, "falling")
	return _cel(id, "captured")

static func holder_override(id: String, context: Dictionary) -> String:
	# Exact source MoveTarget ownership is required. Whiffs, guard, entry and
	# release tails retain the authored attack rather than looking like a grab.
	if id != "cat" or not bool(context.get("source_target_active", false)): return ""
	if int(context.get("paired_target_index", -1)) < 0: return ""
	var binding: String = str(context.get("binding_id", ""))
	var label: String = str(context.get("current_label", ""))
	var frame: float = float(context.get("source_frame", 0.0))
	var spec: Dictionary = data().get("fighters", {}).get("cat", {}).get("holder", {})
	if binding == "cat:super" and label in ["必杀_HIT", "必杀_L"]:
		return str(spec.get("raise" if label == "必杀_HIT" else "press", ""))
	if binding == "cat:super_down" and label == "超必杀" and frame >= 58 and frame < 128:
		var target_position: Vector2 = context.get("paired_target_position", Vector2.ZERO)
		var owner_position: Vector2 = context.get("actor_position", context.get("position", Vector2.ZERO))
		if target_position.y < owner_position.y - 18.0: return str(spec.get("raise", ""))
		if target_position.y > owner_position.y + 18.0: return str(spec.get("press", ""))
		return str(spec.get("hold", ""))
	return ""

static func _point(raw: Variant) -> Vector2:
	if raw is Vector2: return raw
	if raw is Array and raw.size() >= 2: return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.INF

static func _pair_has_accepted_hit(context: Dictionary, target_index: int) -> bool:
	# Source goFrame can also write a bare boolean confirmation. Only a real
	# receive_hit result or the current confirmed contact counts here.
	var confirmations: Variant = context.get("confirmations", {})
	if confirmations is Dictionary:
		for confirmation: Variant in confirmations.values():
			if not confirmation is Dictionary: continue
			if int(confirmation.get("target", -1)) != target_index: continue
			var result: Dictionary = confirmation.get("result", {})
			if bool(result.get("hit", false)) and not bool(result.get("blocked", false)) and not bool(result.get("armor", false)): return true
	return bool(context.get("confirmed", false)) and str(context.get("contact", "")) in ["hit", ""]

static func paired_display_offset(owner_context: Dictionary, owner_anchors: Dictionary, target_pose: Dictionary, target_height: float, target_facing: int, target_position: Vector2) -> Dictionary:
	# A displayed registration offset only. Never writes target.position,
	# velocity, source MoveTarget, collision boxes, freeze or the owner pose.
	# Call with the holder's already deformed WORLD paw anchors. The consumer
	# adds this same offset to the one victim body and all its display anchors.
	var inactive: Dictionary = {"ready":false, "offset":Vector2.ZERO}
	var binding: String = str(owner_context.get("binding_id", ""))
	var label: String = str(owner_context.get("current_label", ""))
	var target_index: int = int(owner_context.get("paired_target_index", -1))
	if target_index < 0 or not binding in ["cat:super", "cat:super_down"]: return inactive
	var hidden: bool = not bool(owner_context.get("paired_target_visible", true))
	var target_active: bool = bool(owner_context.get("source_target_active", false))
	if binding == "cat:super":
		if not label in ["必杀_HIT", "必杀_L"] or not (target_active or hidden): return inactive
	else:
		var frame: float = float(owner_context.get("source_frame", 0.0))
		if label != "超必杀" or not target_active or frame < 58.0 or frame >= 128.0: return inactive
	if str(owner_context.get("contact", "")) in ["guard", "armor", "miss"]: return inactive
	if not _pair_has_accepted_hit(owner_context, target_index): return inactive
	if not bool(target_pose.get("ready", false)) or target_height <= 0.0 or not target_position.is_finite(): return inactive
	var target_anchors: Dictionary = target_pose.get("anchors", {})
	var chest: Vector2 = _point(target_anchors.get("capture_chest", target_anchors.get("anatomy_chest", [])))
	var unit: float = target_height / maxf(1.0, float(target_pose.get("body_reference_height", 0.0)))
	if not chest.is_finite() or float(target_pose.get("body_reference_height", 0.0)) <= 0.0: return inactive
	chest *= unit
	# Optional rendered-local chest supplied by the renderer includes its small
	# UV follow-through exactly and avoids a 1-2 px contact mismatch.
	if target_pose.has("display_deformed_capture_chest_v029"):
		chest = _point(target_pose["display_deformed_capture_chest_v029"])
	var direction: float = 1.0 if target_facing >= 0 else -1.0
	var current_chest: Vector2 = target_position + Vector2(chest.x * direction, chest.y)
	var front_paw: Vector2 = _point(owner_anchors.get("paw_tip", owner_anchors.get("hand", [])))
	var rear_paw: Vector2 = _point(owner_anchors.get("rear_paw", owner_anchors.get("rear_hand", [])))
	if not front_paw.is_finite(): return inactive
	# Registered old I descent tails may have only a single hand anchor. A
	# missing second paw can use that genuine visible hand, never a guessed box.
	var grip: Vector2 = (front_paw + rear_paw) * .5 if rear_paw.is_finite() else front_paw
	var offset: Vector2 = grip - current_chest
	if not offset.is_finite(): return inactive
	return {"ready":true, "offset":offset, "grip_world":grip, "target_chest_world":current_chest, "target_chest_display_world":current_chest+offset, "binding_id":binding, "target_index":target_index, "source_roots_unchanged":true, "changes_physics":false, "body_count":1}

static func coverage() -> Dictionary:
	return {"fighters": data().get("fighters", {}).size(), "registered_new_cels": int(data().get("registered_cels", 0)), "new_air_cels_v032": int(data().get("new_air_cels_v032", 0)), "ground_families": 4, "ground_stages": 4, "air_silhouettes_per_fighter": 6, "cat_holder_cels": 3, "source_roots_unchanged": true, "paired_display_registration_only": true, "adds_bodies": false, "adds_hits": false}
