extends RefCounted
## Logic-only, pinned XFL timeline adapter. 5DPLAY Game Studio and contributors.
## Source: OpenBleachVsNaruto@4d7bc9913ec6b609ba521ff86b6066bff134a736
## GPL-3.0-or-later. Original verified XML/AS3 is under source_reference/open-bvn-playable.
## No contact, movement, conditions, damage application or art is executed here.
const DATA_PATH := "res://assets/logic/bvn-playable-profiles.json"
const ROSTER_PATH_V034 := "res://assets/logic/bvn-playable-profiles-v034.json"
const SOURCE_FPS := 30.0
static var _data: Dictionary = {}
static var _definitions: Dictionary = {}

static func release_cache() -> void:
	_data.clear()
	_definitions.clear()

static func _load_data() -> Dictionary:
	if _data.is_empty():
		if not FileAccess.file_exists(DATA_PATH):
			push_error("Missing pinned playable logic data: " + DATA_PATH)
			return {}
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed
			# Independently parsed fixed source profiles. Existing profile data
			# remains immutable; overlays may add new IDs but never replace them.
			if FileAccess.file_exists(ROSTER_PATH_V034):
				var extra: Variant=JSON.parse_string(FileAccess.get_file_as_string(ROSTER_PATH_V034))
				if extra is Dictionary:
					_data.get("profiles",{}).merge(extra.get("profiles",{}),false)
					_data.get("aliases",{}).merge(extra.get("aliases",{}),false)
	return _data

static func profile_key(id: String) -> String:
	var data := _load_data()
	return str(data.get("aliases", {}).get(id, id))

static func _profile_ref(id: String) -> Dictionary:
	return _load_data().get("profiles", {}).get(profile_key(id), {})

static func profile(id: String) -> Dictionary:
	return _profile_ref(id).duplicate(true)

static func source_metadata() -> Dictionary:
	return _load_data().get("source", {}).duplicate(true)

static func label_for_command(id: String, command: String) -> String:
	var p := _profile_ref(id)
	if p.get("actor", {}).get("labels", {}).has(command):
		return command
	return str(p.get("command_labels", {}).get(command, ""))

static func labels(id: String) -> Array:
	return _profile_ref(id).get("actor", {}).get("labels", {}).keys()

static func hit_vo(id: String, key: String) -> Dictionary:
	return _profile_ref(id).get("hit_vos", {}).get(key, {}).duplicate(true)

static func _event_terminal(event: Dictionary) -> bool:
	# nextFrame crosses later labels. Only explicit, unconditional control redirects
	# delimit a definition; endAct closes permissions but continues visual frames.
	for c in event.get("calls", []):
		if not c.get("supported", false) or not c.get("conditions", []).is_empty():
			continue
		if c.get("method", "") in ["idle", "loop", "stop", "gotoAndPlay", "gotoAndStop"]:
			return true
	return false

static func _make_definition(id: String, actor: Dictionary, label: String, child: bool = false) -> Dictionary:
	var source_labels: Dictionary = actor.get("labels", {})
	if not source_labels.has(label):
		return {}
	var start := int(source_labels[label].get("frame", 0))
	var end := int(actor.get("frame_count", 0)) - 1
	var terminal: Dictionary = {}
	for event in actor.get("events", []):
		if int(event.get("frame", 0)) < start:
			continue
		if _event_terminal(event):
			end = int(event["frame"])
			terminal = event
			break
	var events: Array = []
	var areas: Array = []
	for event in actor.get("events", []):
		var absolute := int(event.get("frame", 0))
		if absolute >= start and absolute <= end:
			var out: Dictionary = event.duplicate(true)
			out["source_frame"] = absolute
			out["frame"] = absolute - start
			events.append(out)
	for area in actor.get("areas", []):
		if int(area.get("source_end", 0)) <= start or int(area.get("source_start", 0)) > end:
			continue
		var out: Dictionary = area.duplicate(true)
		out["relative_start"] = maxi(0, int(area["source_start"]) - start)
		out["relative_end"] = mini(end + 1, int(area["source_end"])) - start
		areas.append(out)
	return {
		"profile_id": profile_key(id), "label": label, "source_start_frame": start,
		"source_end_frame": end, "frame_count": maxi(1, end - start + 1),
		"authored_label_span": int(source_labels[label].get("authored_span", 1)),
		"fps": SOURCE_FPS, "source_file": actor.get("source_file", ""),
		"source_symbol": actor.get("source_symbol", ""), "events": events, "areas": areas,
		"entry_action_slots": {}, "terminal_event": terminal.duplicate(true),
		"child_attacker": child, "conditional_branches_require_resolver": true,
		"space": "document_root_source_px" if not child else "attacker_local_source_px"
	}

static func _definition_ref(id: String, command_or_label: String) -> Dictionary:
	var key := profile_key(id) + "::" + command_or_label
	if not _definitions.has(key):
		var p := _profile_ref(id)
		var label := label_for_command(id, command_or_label)
		_definitions[key] = _make_definition(id, p.get("actor", {}), label)
	return _definitions[key]

static func definition(id: String, command_or_label: String) -> Dictionary:
	return _definition_ref(id, command_or_label).duplicate(true)

## Read-only scalar queries avoid copying entire XML/IR profiles every draw.
static func foot_anchor(id: String) -> Vector2:
	var foot: Variant=_profile_ref(id).get("foot_anchor",[0,0])
	if foot is Array and foot.size()>=2: return Vector2(float(foot[0]),float(foot[1]))
	if foot is Dictionary: return Vector2(float(foot.get("x",0)),float(foot.get("y",0)))
	return Vector2.ZERO

static func has_definition(id: String,command_or_label: String) -> bool:
	return not _definition_ref(id,command_or_label).is_empty()

static func definition_metadata(id: String,command_or_label: String) -> Dictionary:
	var data: Dictionary=_definition_ref(id,command_or_label)
	if data.is_empty(): return {}
	return {"profile_id":data["profile_id"],"label":data["label"],"source_start_frame":data["source_start_frame"],"source_end_frame":data["source_end_frame"],"frame_count":data["frame_count"],"source_symbol":data["source_symbol"],"fps":SOURCE_FPS}

static func events_between(id: String, command_or_label: String, previous_frame: int, current_frame: int) -> Array:
	var result: Array = []
	var d := _definition_ref(id, command_or_label)
	if current_frame <= previous_frame:
		return result
	for event in d.get("events", []):
		var f := int(event.get("frame", 0))
		if f > previous_frame and f <= current_frame:
			result.append(event.duplicate(true))
	return result

static func _apply_slot(p: Dictionary, slots: Dictionary, method: String, arguments: Array) -> void:
	var setters: Dictionary = p.get("action_setters", {})
	if not setters.has(method):
		return
	var setter: Dictionary = setters[method]
	var label := str(arguments[0]) if not arguments.is_empty() and arguments[0] is String else str(setter.get("label", ""))
	if not p.get("actor", {}).get("labels", {}).has(label):
		return # upstream checkFrame gates absent actions.
	var cost: int = int(setter.get("cost", 0))
	if method.begins_with("setBisha") and arguments.size() > 1 and (arguments[1] is float or arguments[1] is int):
		cost = int(arguments[1])
	var break_act := bool(arguments[1]) if method == "setTouchFloor" and arguments.size() > 1 else method == "setTouchFloor"
	slots[str(setter.get("slot", ""))] = {"label": label, "cost": cost, "breakAct": break_act}

static func _sample_definition(id: String, d: Dictionary, relative_frame: int) -> Dictionary:
	if d.is_empty():
		return {}
	var p := _profile_ref(id)
	var last := maxi(0, int(d.get("frame_count", 1)) - 1)
	var f := clampi(relative_frame, 0, last)
	var absolute := int(d.get("source_start_frame", 0)) + f
	var areas: Array = []
	var bullet_main: Dictionary = {}
	var hits: Array = []
	var body: Dictionary = {}
	for area in d.get("areas", []):
		if absolute < int(area.get("source_start", 0)) or absolute >= int(area.get("source_end", 0)):
			continue
		var out: Dictionary = area.duplicate(true)
		areas.append(out)
		if out.get("kind", "") == "bullet_main":
			bullet_main = out
		elif out.get("kind", "") == "body":
			body = out
		elif out.get("kind", "") == "hit":
			out["hit_vo"] = hit_vo(id, str(out.get("hit_id", "")))
			hits.append(out)
	var slots: Dictionary = d.get("entry_action_slots", {}).duplicate(true)
	var current_events: Array = []
	var ended_permissions := false
	var idle := false
	var next_label := ""
	var unsupported: Array = []
	for event in d.get("events", []):
		var ef := int(event.get("frame", 0))
		if ef > f:
			break
		if ef == f:
			current_events.append(event.duplicate(true))
		for call in event.get("calls", []):
			if not call.get("supported", false):
				unsupported.append(call.duplicate(true))
				continue
			if not call.get("conditions", []).is_empty():
				continue # pure data never pretends conditional permission was granted.
			var method := str(call.get("method", ""))
			var arguments: Array = call.get("arguments", [])
			if method == "endAct":
				slots.clear()
				ended_permissions = true
			elif method == "setMove":
				_apply_slot(p, slots, "setMoveLeft", [])
				_apply_slot(p, slots, "setMoveRight", [])
			elif method in ["setAllAct", "setAirAllAct"]:
				for setter in p.get("action_setters", {}):
					var is_air := str(setter).ends_with("AIR")
					if (method == "setAirAllAct" and (is_air or setter == "setDash")) or (method == "setAllAct" and not is_air and setter != "setTouchFloor" and setter != "setJumpQuick"):
						_apply_slot(p, slots, str(setter), [])
			elif method == "idle":
				idle = true
				next_label = str(arguments[0]) if not arguments.is_empty() else "站立"
			elif method in ["loop", "gotoAndPlay", "gotoAndStop"]:
				next_label = str(arguments[0]) if not arguments.is_empty() else ""
			else:
				_apply_slot(p, slots, method, arguments)
	return {
		"profile_id": profile_key(id), "label": d.get("label", ""), "frame": f,
		"source_frame": absolute, "frame_count": d.get("frame_count", 0),
		"hits": hits, "body_area": body, "bullet_area": bullet_main, "areas": areas, "events": current_events,
		"current_frame_events": current_events, "action_slots": slots,
		"ended_permissions": ended_permissions, "ended": ended_permissions,
		"idle": idle, "next_label": next_label, "past_definition": relative_frame > last,
		"unsupported": unsupported, "requires_condition_resolver": true
	}

static func sample_frame(id: String, command_or_label: String, frame: int) -> Dictionary:
	return _sample_definition(id, _definition_ref(id, command_or_label), frame)

static func sample(id: String, command_or_label: String, time_seconds: float) -> Dictionary:
	return sample_frame(id, command_or_label, int(floor(maxf(0.0, time_seconds) * SOURCE_FPS)))

static func attacker_definition(id: String, symbol_or_instance: String) -> Dictionary:
	var children: Dictionary = _profile_ref(id).get("children", {})
	if children.has(symbol_or_instance):
		return children[symbol_or_instance].duplicate(true)
	for symbol in children:
		for instance in children[symbol].get("registrations", []):
			if instance.get("instance_name", "") == symbol_or_instance:
				return children[symbol].duplicate(true)
	return {}

static func sample_attacker(id: String, symbol_or_instance: String, frame: int) -> Dictionary:
	var child := attacker_definition(id, symbol_or_instance)
	if child.is_empty():
		return {}
	# Independent attacker frame 0 is a legal entry even without authored labels.
	var full := {
		"label": symbol_or_instance, "source_start_frame": 0,
		"frame_count": child.get("frame_count", 1), "events": child.get("events", []),
		"areas": child.get("areas", []), "entry_action_slots": {}
	}
	var result := _sample_definition(id, full, frame)
	result["child_attacker"] = true
	result["source_symbol"] = child.get("source_symbol", "")
	result["space"] = "attacker_local_source_px"
	return result

static func instance_at(id: String, name: String, absolute_frame: int) -> Dictionary:
	var actor: Dictionary = _profile_ref(id).get("actor", {})
	for item in actor.get("instances", []):
		if item.get("instance_name", "") != name:
			continue
		if absolute_frame < int(item.get("source_start", 0)) or absolute_frame >= int(item.get("source_end", 0)):
			continue
		var out: Dictionary = item.duplicate(true)
		out["start"] = out["source_start"]
		out["end"] = out["source_end"]
		out["matrix"] = out["instance_matrix"]
		out["child_symbol"] = out["source_symbol"]
		return out
	return {}

static func sample_absolute_frame(id: String, absolute_frame: int) -> Dictionary:
	var actor: Dictionary = _profile_ref(id).get("actor", {})
	if actor.is_empty():
		return {}
	return _sample_definition(id, {"label": "", "source_start_frame": 0,
		"frame_count": actor.get("frame_count", 1), "events": actor.get("events", []),
		"areas": actor.get("areas", []), "entry_action_slots": {}}, absolute_frame)

static func ai_ranges(id: String) -> Dictionary:
	return _profile_ref(id).get("ai_ranges", {}).duplicate(true)

static func hit_vos_like(id: String, substring: String) -> Array:
	# Original FighterHitModel.getHitVOLike uses contains, rather than starts_with.
	var result: Array = []
	for key in _profile_ref(id).get("hit_vos", {}):
		if str(key).contains(substring):
			var record: Dictionary = _profile_ref(id)["hit_vos"][key]
			var effective: Dictionary = record.get("effective", {}).duplicate(true)
			effective["id"] = key
			result.append(effective)
	return result
