extends RefCounted
## Drawing-only transition state. Source actions, HitVO, animation frames,
## resource cost, freeze, position, velocity and permission windows are inputs.
## A new action interrupts a visual recovery immediately; no added hard lock.
const ROOT := "res://assets/fighters/v022/"
static var _specs: Dictionary = {}
static var _actors: Dictionary = {}
const PROTECTED := ["hurt", "guard_stun", "launch", "juggle", "slam", "down", "getup", "ko", "throw_hold", "burst", "escape"]
const NEUTRAL := ["idle", "walk", "run"]

static func reset() -> void:
	_specs.clear()
	_actors.clear()

static func _spec(id: String) -> Dictionary:
	if _specs.has(id): return _specs[id]
	var path: String = ("res://assets/fighters/v034/" if id in ["notify", "wojak"] else ROOT) + id + ".manifest.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	_specs[id] = parsed.get("transition_sequences_v028", {}) if parsed is Dictionary else {}
	if parsed is Dictionary:
		_specs[id]["neutral_poses"]=parsed.get("base_sequences",{}).get("idle",[])
	return _specs[id]

static func _frame_at(sequence: Array, progress: float) -> String:
	if sequence.is_empty(): return ""
	return str(sequence[mini(sequence.size() - 1, int(clampf(progress, 0.0, .999999) * sequence.size()))])

## Pure API for replay/QA. Previous visual memory is returned separately from
## the immutable input context, so callers can test interrupted transitions.
static func resolve(id: String, context: Dictionary, memory: Dictionary = {}) -> Dictionary:
	var out := context.duplicate()
	var next := memory.duplicate(true)
	var spec := _spec(id)
	if spec.is_empty(): return {"context": out, "memory": next}
	if bool(context.get("transition_resolved_v028", false)): return {"context": out, "memory": next}
	var clock := float(context.get("visual_clock", 0.0))
	var state := str(context.get("state", "idle"))
	var label := str(context.get("current_label", context.get("source_label", "站立")))
	var grounded := bool(context.get("grounded", true))
	var facing := int(context.get("facing", 1))
	var protected := state in PROTECTED or state in ["guard", "attack", "dash"]
	var explicit := not str(context.get("pose_override", context.get("pose_id", ""))).is_empty()
	var initialized := bool(memory.get("initialized", false)) and clock >= float(memory.get("last_clock", clock))
	var old_state := str(memory.get("state", state))
	var old_grounded := bool(memory.get("grounded", grounded))
	var old_facing := int(memory.get("facing", facing))
	var mode := str(memory.get("mode", "")) if initialized else ""
	var started := float(memory.get("started", clock))
	var previous_label := str(memory.get("label", label))
	if initialized and not explicit:
		if protected:
			mode = ""  # The live source move/hurt/guard always wins immediately.
		elif grounded and not old_grounded and state in NEUTRAL + ["jump"]:
			mode = "land"; started = clock
		elif not grounded and old_grounded and state == "jump":
			mode = "takeoff"; started = clock
		elif not grounded and old_state == "attack" and state == "jump":
			mode = "air_convert"; started = clock
		elif grounded and state in NEUTRAL and old_state == "attack":
			var previous_pose: String=str(memory.get("source_pose",""))
			var settled: Array=spec.get("neutral_poses",[])+spec.get("land",[])+spec.get("recover",[]).slice(4)
			# Landing is an action-container state. An authored tail may already
			# reach neutral; replaying the mid-recovery drawing would crouch twice.
			mode = "" if previous_label=="落地" or previous_pose in settled else "recover"
			started = clock
		elif facing != old_facing and state in NEUTRAL + ["jump"]:
			mode = "turn"; started = clock
			next["turn_from"] = old_facing
			next["turn_to"] = facing
		elif mode == "turn" and not state in NEUTRAL + ["jump"]:
			mode = ""
		elif mode in ["land", "recover"] and (not grounded or not state in NEUTRAL + ["jump"]):
			mode = ""
		elif mode in ["takeoff", "air_convert"] and (grounded or state != "jump"):
			mode = ""
	# A standalone preview can request one registered transition explicitly;
	# normal battle contexts use the state crossings above.
	var duration := .18
	var sequence: Array = []
	if mode == "turn":
		sequence = spec.get("turn", []).duplicate()
		if int(next.get("turn_from", old_facing)) < 0: sequence.reverse()
	elif mode == "recover":
		duration = float(spec.get("durations_seconds", {}).get("recover", .16))
		# Source-label recoveries already show the early follow-through. Continue
		# from the mid-return drawing instead of replaying an attack windup.
		sequence = spec.get("recover", []).slice(2)
	elif mode == "land": sequence = spec.get("land", [])
	elif mode == "takeoff":
		duration = .14; sequence = spec.get("takeoff", []).slice(0, 4)
	elif mode == "air_convert":
		duration = float(spec.get("durations_seconds", {}).get("air_convert", .12))
		sequence = spec.get("takeoff", []).slice(4)
	var elapsed := maxf(0.0, clock - started)
	if not explicit and not protected and not sequence.is_empty() and elapsed < duration:
		out["pose_override"] = _frame_at(sequence, elapsed / duration)
		out["transition_phase"] = mode
		out["transition_progress"] = elapsed / duration
		# Turn cels already traverse right -> front -> left; they must be drawn
		# with one positive canvas facing through the whole authored turn.
		out["visual_facing"] = 1 if mode == "turn" else facing
		out["transition_root_compensation"] = Vector2.ZERO
		out["transition_source_clock_unchanged"] = true
	else:
		mode = ""
	# Labels mapped through real manifest base sequences remain observable even
	# before this helper has a previous state (e.g. captured first land frame).
	if not out.has("transition_phase"):
		# BVN executes its real landing source label inside attack state. This is
		# an observation tag only: protection and the source pose stay untouched.
		if label == "落地": out["transition_phase"] = "land_source"
		elif str(context.get("source_visual_phase_v028",""))=="recover" and state=="attack": out["transition_phase"]="recover_source"
		elif label == "起跳" and not protected: out["transition_phase"] = "takeoff_source"
		elif not grounded and label in ["跳", "跳中", "落"] and not protected: out["transition_phase"] = "air_source"
	out["transition_resolved_v028"] = true
	next.merge({"initialized": true, "last_clock": clock, "state": state, "label": label, "grounded": grounded, "facing": facing, "mode": mode, "started": started, "previous_label": previous_label,"source_pose":context.get("source_visual_pose_id_v028","")}, true)
	return {"context": out, "memory": next}

## Real actor API. Multiple draw/FX-anchor queries in one source clock sample
## reuse the same resolved pose; they never advance animation independently.
static func resolve_actor(actor: Variant, context: Dictionary) -> Dictionary:
	if not str(context.get("pose_override", context.get("pose_id", ""))).is_empty(): return context
	if bool(context.get("transition_resolved_v028", false)): return context
	var key := str(actor.get_instance_id())
	for retained: String in _actors.keys():
		if (_actors[retained]["actor"] as WeakRef).get_ref() == null: _actors.erase(retained)
	var entry: Dictionary = _actors.get(key, {"actor": weakref(actor), "memory": {}, "sample_key": "", "visual": {}})
	var sample_key := str(context.get("visual_clock", 0.0)) + ":" + str(context.get("state", "")) + ":" + str(context.get("grounded", true)) + ":" + str(context.get("facing", 1)) + ":" + str(context.get("current_label", ""))
	if entry["sample_key"] == sample_key:
		var reused := context.duplicate()
		reused.merge(entry["visual"], true)
		return reused
	var resolved := resolve(str(actor.fighter_id), context, entry["memory"])
	var out: Dictionary = resolved["context"]
	var visual: Dictionary = {}
	for field: String in ["pose_override", "transition_phase", "transition_progress", "visual_facing", "transition_root_compensation", "transition_source_clock_unchanged", "transition_resolved_v028"]:
		if out.has(field): visual[field] = out[field]
	entry["memory"] = resolved["memory"]; entry["sample_key"] = sample_key; entry["visual"] = visual
	_actors[key] = entry
	return out
