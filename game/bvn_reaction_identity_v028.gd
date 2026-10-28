extends RefCounted
## Presentation-only, accepted-contact reaction identity. Never changes actor
## state, time, source HitVO, freeze, velocity, HP or permissions.
const DATA_PATH := "res://assets/fighters/v028/reactions/reaction-anatomy.json"
const IDS := ["rio", "cat", "worker", "chicken", "shark"]
const AirContact = preload("res://game/bvn_air_contact_v029.gd")
const COMMAND_SLOTS := {"skill1":"U", "skill2":"WU", "skill3":"SU", "super":"I", "super_up":"WI", "super_down":"SI", "air_skill":"AIR_U", "air_super":"AIR_I"}
static var _data: Dictionary = {}
static var _contacts: Dictionary = {}
static var _serial: int = 0

static func _load() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary: _data = parsed
	return _data

static func clear() -> void:
	_contacts.clear()
	_data.clear()
	_serial = 0
	AirContact.clear()

static func merge_manifest(id: String, meta: Dictionary) -> Dictionary:
	var fragment: Dictionary = _load().get("fighters", {}).get(id, {})
	if fragment.is_empty(): return meta
	var added: int = 0
	for key: String in fragment.get("frames", {}):
		if not meta["frames"].has(key): added += 1
	meta["frames"].merge(fragment.get("frames", {}), false)
	meta["sheets"].merge(fragment.get("sheets", {}), false)
	meta["ready_frame_count"] = int(meta.get("ready_frame_count", 0)) + added
	meta["unique_rgba_count"] = int(meta.get("unique_rgba_count", 0)) + added
	meta["reaction_identity_v028"] = true
	var complete: Dictionary = AirContact.data().get("fighters", {}).get(id, {})
	var added_complete: int = 0
	for key: String in complete.get("frames", {}):
		if not meta["frames"].has(key): added_complete += 1
	meta["frames"].merge(complete.get("frames", {}), false)
	meta["sheets"].merge(complete.get("sheets", {}), false)
	meta["ready_frame_count"] = int(meta.get("ready_frame_count", 0)) + added_complete
	meta["unique_rgba_count"] = int(meta.get("unique_rgba_count", 0)) + added_complete
	meta["reaction_stages_v029"] = true
	return meta

## Call once after a real receive_hit accepted this direct or child-object hit.
## Repeated hits with identical HitVO IDs remain different accepted contacts.
static func capture_contact(defender: Variant, attacker: Variant, source: Dictionary, result: Dictionary) -> void:
	if not bool(result.get("hit", false)) or defender == null: return
	_serial += 1
	var exact: Dictionary = source.get("source_hit_vo", {})
	var attack_id: String = str(attacker.fighter_id) if attacker != null else ""
	var binding: String = str(source.get("source_binding_id", ""))
	var command: String = binding.get_slice(":", 1)
	if command.is_empty() and attacker != null: command = str(attacker.source_entry_command)
	var slot: String = str(COMMAND_SLOTS.get(command, command))
	var hit: Dictionary = {}
	for key: String in ["hitType", "hurtType", "hitx", "hity", "hurtTime", "power", "isBreakDef", "isApplyG"]:
		hit[key] = exact.get(key, 0)
	hit["id"] = str(source.get("source_name", exact.get("id", "")))
	var outcome: String = "guard" if bool(result.get("blocked", false)) else ("armor" if bool(result.get("armor", false)) else "hit")
	var area: Rect2 = source.get("area", Rect2()) if source.get("area", Rect2()) is Rect2 else Rect2()
	var contact_world: Vector2 = defender.position
	if area.has_area() and defender.has_method("body_box"):
		var intersection: Rect2 = area.intersection(defender.body_box())
		if intersection.has_area(): contact_world = intersection.get_center()
	var local_contact: Vector2 = contact_world - defender.position
	local_contact.x *= float(defender.facing)
	_contacts[int(defender.get_instance_id())] = {
		"actor":weakref(defender), "attacker":weakref(attacker) if attacker != null else null, "serial":_serial, "attacker_id":attack_id,
		"slot":slot, "command":command, "binding_id":binding,
		"profile":str(source.get("source_profile_id", "")),
		"label":str(source.get("source_label", "")), "hit":hit,
		"source_type":str(source.get("source_type", "actor")),
		"source_frame":int(source.get("source_frame", -1)),
		"source_absolute_frame":int(source.get("source_absolute_frame", -1)),
		"outcome":outcome, "contact_local":local_contact,
		"owner_direction":int(source.get("hit_owner_facing", source.get("owner_facing", 1))),
		"velocity":defender.velocity, "actual_launch":bool(result.get("launched", false)),
		"actual_terminal":bool(result.get("terminal", false)),
		"kind":str(source.get("kind", "normal"))
	}
	if attack_id == "wojak":
		_contacts[int(defender.get_instance_id())]["owner_action_serial_v034"] = int(attacker.action_serial)
	# The identities are compact, weakly owned metadata. No per-vertex deepcopy.
	if _contacts.size() > 16:
		for key: int in _contacts.keys():
			if (_contacts[key]["actor"] as WeakRef).get_ref() == null: _contacts.erase(key)

static func enrich_context(actor: Variant, context: Dictionary) -> Dictionary:
	var out: Dictionary = context
	var record: Dictionary = _contacts.get(int(actor.get_instance_id()), {})
	var actual_hurt: Dictionary = actor.last_source_hurt_hit
	var actual_defense: Dictionary = actor.last_source_defense_hit
	# Real idle() clears HitVO records. A preceding super cannot leak into idle,
	# a new round, armor or a later unobserved hit from a different source.
	var relevant: Dictionary = actual_defense if str(record.get("outcome", "")) == "guard" else actual_hurt
	if not record.is_empty() and not relevant.is_empty() and str(relevant.get("id", "")) == str(record.get("hit", {}).get("id", "")):
		out["reaction_identity"] = record
	else:
		out["reaction_identity"] = {}
	out["reaction_hit"] = actual_hurt
	out["reaction_defense_hit"] = actual_defense
	out["reaction_velocity"] = actor.velocity
	out["reaction_hurt_length"] = float(actor.action_data.get("hurt_length", .3))
	out["reaction_fly"] = not actor.hurt_fly.is_empty()
	out["reaction_fly_phase_v029"] = int(actor.hurt_fly.get("phase", 0))
	out["reaction_source_pair_v029"] = {}
	var attacker_ref: WeakRef = record.get("attacker", null) as WeakRef
	var accepted_owner: Variant = attacker_ref.get_ref() if attacker_ref != null else null
	if not out.get("reaction_identity", {}).is_empty() and accepted_owner != null and accepted_owner.has_method("source_visual_state"):
		var pair_context: Dictionary = accepted_owner.source_visual_state()
		out["reaction_source_pair_v029"] = {"binding": str(pair_context.get("binding_id", "")), "label": str(pair_context.get("current_label", "")), "frame": int(pair_context.get("source_frame", 0)), "active": bool(pair_context.get("source_target_active", false)) and int(pair_context.get("paired_target_index", -1)) == int(actor.player_index)}
	out.erase("_reaction_descriptor_v028")
	return out

static func _family(record: Dictionary, hit: Dictionary, velocity: Vector2) -> String:
	var id: String = str(record.get("attacker_id", ""))
	var slot: String = str(record.get("slot", ""))
	var hit_type: int = int(hit.get("hitType", 1))
	var hit_y: float = float(hit.get("hity", 0.0))
	var name: String = str(hit.get("id", ""))
	if id == "rio":
		return "sword_drop" if hit_y > 2.0 or slot == "SI" else "sword_side"
	if id == "chicken":
		return "ball_head" if hit_y < -3.0 or slot in ["WU", "WI"] else "ball_belly"
	if id == "cat":
		return "cat_slam" if hit_y > 3.0 or slot == "AIR_I" else ("cat_squeeze" if hit_type == 11 or slot == "I" else "cat_claw")
	if id == "worker":
		return "stamp_crush" if slot in ["I", "SI"] or name == "bs" else "case_shoulder"
	if id == "shark":
		if velocity.y < -24.0 or hit_y < -3.0: return "wave_lift"
		return "shark_bite" if hit_type == 11 or slot in ["I", "SI"] else "wave_pressure"
	# Generic genuine source contacts still distinguish anatomy and direction.
	if hit_type == 11: return "cat_squeeze"
	if hit_y > 2.0: return "stamp_crush"
	if hit_y < -3.0: return "ball_head"
	return "sword_side" if hit_type in [1, 6] else "ball_belly"

static func _vector(raw: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if raw is Vector2: return raw
	if raw is Array and raw.size() >= 2: return Vector2(float(raw[0]), float(raw[1]))
	return fallback

static func _anatomy(id: String, pose: Dictionary, height: float) -> Dictionary:
	var anchors: Dictionary = pose.get("anchors", {})
	var saved: Dictionary = _load().get("anatomy", {}).get(id, {}).get(str(pose.get("pose_id", "")), {})
	var reference: float = maxf(1.0, float(pose.get("body_reference_height", height)))
	var result: Dictionary = {}
	for key: String in ["head", "chest", "hips"]:
		var anchor_name: String = "anatomy_" + key
		var point: Vector2 = _vector(anchors.get(anchor_name, saved.get(key, [])))
		var radius: Vector2 = _vector(anchors.get(anchor_name + "_radius", saved.get(key + "_radius", [])))
		if point == Vector2.ZERO and not anchors.has(anchor_name) and not saved.has(key): continue
		result[key] = point / reference
		result[key + "_radius"] = Vector2(maxf(6.0, radius.x), maxf(6.0, radius.y)) / reference
	# Actual hand/mouth/jaw/tail positions provide local accessory follow-through.
	for key: String in ["hand", "mouth", "jaw", "tail", "briefcase", "weapon_grip", "weapon_tip", "rear_foot", "front_foot", "third_foot"]:
		if anchors.has(key): result[key] = _vector(anchors[key]) / reference
	return result

static func describe(id: String, pose: Dictionary, context: Dictionary) -> Dictionary:
	var state: String = str(context.get("state", ""))
	var clip: String = str(pose.get("clip", "")).get_slice(":", 0)
	var record: Dictionary = context.get("reaction_identity", {})
	var guard: bool = state in ["guard", "guard_stun"] or (state.is_empty() and clip in ["guard", "guard_low"])
	var hurting: bool = state in ["hurt", "juggle", "launch", "slam", "throw_hold"] or (state.is_empty() and clip in ["hurt", "air_hurt", "caught", "throw_victim"])
	var landing: bool = state == "down" or (state.is_empty() and clip == "down")
	var getting_up: bool = state == "getup" or (state.is_empty() and clip == "getup")
	var armored: bool = not hurting and not guard and float(context.get("hurt_flash", 0.0)) > 0.0
	var hit: Dictionary = context.get("reaction_defense_hit", {}) if guard else context.get("reaction_hit", {})
	if not record.is_empty(): hit = record.get("hit", hit)
	var valid: bool = ((hurting or guard or armored) and not hit.is_empty()) or landing or getting_up
	if state == "ko" or clip == "ko": valid = false
	var velocity: Vector2 = context.get("reaction_velocity", Vector2.ZERO)
	var face: float = float(context.get("facing", 1))
	var push: float = signf(velocity.x) * face if absf(velocity.x) > 1.0 else float(record.get("owner_direction", -int(face))) * face
	var age: float = maxf(0.0, float(context.get("state_time", 0.0)))
	var length: float = maxf(.08, float(context.get("reaction_hurt_length", .30)))
	var contact_peak: float = exp(-age / .105)
	var head_lag: float = exp(-maxf(0.0, age - .024) / .145) * (.56 + .44 * sin(clampf(age / .16, 0, 1) * PI))
	var rebound: float = sin(clampf((age - .075) / maxf(.08, length - .075), 0, 1) * PI) * .32
	var severity: float = clampf(.74 + absf(float(hit.get("hitx", 0))) * .035 + float(hit.get("power", 0)) * .0021, .76, 1.30)
	if bool(context.get("last_hurt_bisha", false)): severity = minf(1.46, severity + .12)
	return {"ready":valid, "pose_id":str(pose.get("pose_id", "")), "family":_family(record, hit, velocity), "guard":guard, "armor":armored, "landing":landing, "getup":getting_up, "airborne":not bool(context.get("grounded", true)), "age":age, "length":length, "peak":contact_peak, "head_lag":head_lag, "rebound":rebound, "severity":severity, "push":push, "anatomy":_anatomy(id, pose, float(context.get("body_height", 100))), "contact_local":record.get("contact_local", Vector2.ZERO), "serial":int(record.get("serial", -1)), "uses_real_contact":not record.is_empty(), "body_count":1, "adds_hits":false}

static func pose_override_for(id: String, context: Dictionary) -> String:
	# The motion specialist owns authored I/SI attacker frames. Contact-holder
	# candidates are opt-in fallback only; never mask a newer complete skill.
	var holder: String = AirContact.holder_override(id, context) if bool(context.get("allow_contact_holder_fallback_v029", false)) else ""
	if not holder.is_empty(): return holder
	var real_record: Dictionary = context.get("reaction_identity", {})
	var complete_family: String = _family(real_record, real_record.get("hit", {}), context.get("reaction_velocity", Vector2.ZERO))
	var complete: String = AirContact.pose_for(id, context, complete_family)
	if not complete.is_empty(): return complete
	if str(context.get("state", "")) != "hurt" or not bool(context.get("grounded", true)): return ""
	var record: Dictionary = context.get("reaction_identity", {})
	if record.is_empty() or str(record.get("outcome", "")) != "hit": return ""
	var age: float = maxf(0.0, float(context.get("state_time", 0.0)))
	var length: float = maxf(.08, float(context.get("reaction_hurt_length", .30)))
	var peak_end: float = minf(.115, length * .55)
	var return_end: float = minf(.205, length * .84)
	if age < .020 or age >= return_end: return ""
	var index: int = 5 if age >= peak_end else 0
	if age < peak_end:
		var family: String = _family(record, record.get("hit", {}), context.get("reaction_velocity", Vector2.ZERO))
		index = {"sword_side":0, "ball_belly":1, "ball_head":2, "sword_drop":3, "cat_slam":3, "stamp_crush":3, "cat_claw":3, "cat_squeeze":1, "case_shoulder":0, "wave_pressure":0, "wave_lift":2, "shark_bite":1}.get(family, 0)
	var poses: Array = _load().get("fighters", {}).get(id, {}).get("reaction_poses", [])
	return str(poses[index]) if poses.size() > index else ""

static func pair_victim_override(id: String, owner_context: Dictionary) -> String:
	return AirContact.pair_victim_override(id, owner_context)

static func _weight(local: Vector2, center: Vector2, radius: Vector2) -> float:
	var delta: Vector2 = (local - center) / Vector2(maxf(.018, radius.x), maxf(.018, radius.y))
	return exp(-delta.length_squared() * 1.15)

## Return a local displacement, not an absolute point. The renderer adds this
## to its movement/attack continuity displacement on the one existing UV body.
static func deform_point(local: Vector2, body_height: float, id: String, pose: Dictionary, context: Dictionary) -> Vector2:
	var descriptor: Dictionary = context.get("_reaction_descriptor_v028", {})
	if str(descriptor.get("pose_id", "")) != str(pose.get("pose_id", "")) or descriptor.is_empty():
		descriptor = describe(id, pose, context)
		context["_reaction_descriptor_v028"] = descriptor
	if not bool(descriptor.get("ready", false)): return Vector2.ZERO
	var height: float = maxf(1.0, body_height)
	var p: Vector2 = local / height
	var anatomy: Dictionary = descriptor["anatomy"]
	if not anatomy.has("chest") or not anatomy.has("head") or not anatomy.has("hips"): return Vector2.ZERO
	var head: float = _weight(p, anatomy["head"], anatomy["head_radius"])
	var chest: float = _weight(p, anatomy["chest"], anatomy["chest_radius"])
	var hips: float = _weight(p, anatomy["hips"], anatomy["hips_radius"])
	var peak: float = float(descriptor["peak"])
	var lag: float = float(descriptor["head_lag"])
	var rebound: float = float(descriptor["rebound"])
	var push: float = float(descriptor["push"])
	var offset: Vector2 = Vector2.ZERO
	if bool(descriptor["guard"]):
		var hand: Vector2 = anatomy.get("hand", anatomy["chest"])
		var brace: float = _weight(p, hand, anatomy["chest_radius"] * .75)
		offset.x = push * peak * (.027 * brace + .012 * chest + .008 * head)
		offset.y = peak * .012 * chest
	elif bool(descriptor["armor"]):
		var contact: Vector2 = descriptor["contact_local"] / height
		var localized: float = _weight(p, contact if contact != Vector2.ZERO else anatomy["chest"], anatomy["chest_radius"] * .64)
		var shock: float = clampf(float(context.get("hurt_flash", 0.0)) / .05, 0, 1)
		offset = Vector2(push * .018, .008) * localized * shock
	elif bool(descriptor["landing"]):
		var settle: float = exp(-float(descriptor["age"]) / .16)
		offset = Vector2(.008 * push * head, .015 * chest + .008 * hips) * settle
	elif bool(descriptor["getup"]):
		var progress: float = clampf(float(pose.get("progress", 0)), 0, 1)
		offset = Vector2(-.012 * push * chest, -.016 * chest) * sin(progress * PI)
	else:
		match str(descriptor["family"]):
			"sword_side":
				offset.x = push * (.095 * chest * peak + .112 * head * lag - .027 * hips * peak - .046 * chest * rebound)
				offset.y = (.025 * chest - .017 * head) * peak
			"sword_drop", "cat_slam":
				offset.x = push * (.034 * chest * peak + .062 * head * lag)
				offset.y = (.13 * chest + .12 * head + .045 * hips) * peak - .026 * chest * rebound
			"ball_belly":
				offset.x = push * (.090 * hips * peak - .079 * chest * peak - .106 * head * lag)
				offset.y = (.067 * chest + .060 * head) * peak - .019 * hips * rebound
			"ball_head":
				offset.x = push * (.163 * head * lag + .043 * chest * peak)
				offset.y = (-.052 * head + .021 * chest) * peak
			"cat_claw":
				offset.x = push * (.052 * chest * peak - .025 * head * lag)
				offset.y = (.075 * head - .020 * chest + .018 * hips) * peak
			"cat_squeeze", "shark_bite":
				var pinch: Vector2 = p - anatomy["chest"]
				offset.x = -.17 * pinch.x * chest * peak + push * .032 * head * lag
				offset.y = -.13 * pinch.y * chest * peak + .073 * head * lag
			"case_shoulder":
				var shoulder_side: float = clampf((p.x - (anatomy["chest"] as Vector2).x) * -push * 5.0 + .6, .2, 1.0)
				offset.x = push * (.105 * chest * shoulder_side * peak + .060 * head * lag - .027 * hips * peak)
				offset.y = (-.025 * chest * shoulder_side + .035 * head) * peak
			"stamp_crush":
				offset.x = (p.x - (anatomy["chest"] as Vector2).x) * .20 * chest * peak
				offset.y = (.155 * head + .160 * chest + .043 * hips) * peak - .020 * chest * rebound
			"wave_pressure":
				offset.x = push * (.125 * chest * peak + .145 * head * lag + .046 * hips * peak)
				offset.y = -.018 * chest * peak + .026 * head * lag
			"wave_lift":
				offset.x = push * (.053 * chest * peak + .135 * head * lag - .046 * hips * peak)
				offset.y = -.070 * chest * peak + .040 * hips * peak
		# Feet remain registered to the source root. Airborne legs may curl, but
		# the origin itself and every ground-foot strip remain exactly invariant.
		if bool(descriptor["airborne"]):
			offset += Vector2(-push * .025, -.025) * hips * peak
	var pin: float = smoothstep(0.0, .095, maxf(0.0, -p.y))
	# The new drawings already contain full silhouette compression/rebound.
	# Keep a small delayed local follow-through instead of bending them twice.
	var authored_stage: float = .18 if bool(pose.get("reaction_stages_v029", false)) else 1.0
	return offset * height * pin * float(descriptor["severity"]) * authored_stage

static func coverage() -> Dictionary:
	return {"fighters":_load().get("fighters", {}).size(), "reaction_cels":30, "materials":12, "root_pinned":true, "changes_source":false, "accepted_contacts_only":true, "complete_stages_v029": AirContact.coverage()}
