extends RefCounted
## Copyright (C) 2021-2026 5DPLAY Game Studio; Godot adaptation (C) 2026.
## SPDX-License-Identifier: GPL-3.0-or-later
## Official core commit 891f5776dbdf3cbf40919e27aa8d6e77a5f66c97:
## FighterMcHurtCtrl.as:662-711; FighterMain.as:159-197,238-243,325-353,541-569,621-635.
## Idle/prelude order: FighterMcCtrler.as:166-217 and FighterMcHurtCtrl.as:116-125,172-179.
## The five original meme resources choose comicType!=1 energyExplode, not Naruto replacement.
## Pure state only; actor state/FX/input/geometry integration is the caller's responsibility.

const HitRules = preload("res://game/bvn_hit_rules.gd")
const SOURCE_COMMIT := "891f5776dbdf3cbf40919e27aa8d6e77a5f66c97"
const SOURCE_FPS := 30.0
const DEFAULT_STAGE_UNIT := 1.6
const REQUIRED_ENERGY := 50.0
const ENERGY_COST := 100.0
const QI_COST := 100.0
const MAX_RAW_HURT := 210
const SOURCE_RECT := Rect2(-100, -200, 200, 210)

## Same per-HitVO integer calculation as getDamage, BEFORE defender defense/armour modifiers.
static func raw_hurt_damage(hits: Array) -> int:
	var total := 0
	for hit: Dictionary in hits:
		var power := float(hit.get("power", hit.get("damage", 0)))
		var add := float(hit.get("powerAdd", hit.get("power_add", 0)))
		var rate := float(hit.get("powerRate", hit.get("power_rate", 1)))
		total += int((power + power * add / 100.0) * rate)
	return total

static func _bisha(hit: Dictionary) -> bool:
	# HitVO.isBisha checks the resource id, not hitType or the amount of damage.
	var id := str(hit.get("id", ""))
	return id.contains("bs") or id.contains("sbs") or id.contains("cbs") or id.contains("kbs")

static func eligibility(source: Dictionary) -> Dictionary:
	var hits: Array = source.get("hurt_hits", [])
	var last: Dictionary = source.get("last_hit", hits.back() if not hits.is_empty() else {})
	var last_bisha := bool(source.get("last_bisha", _bisha(last)))
	var break_def := bool(source.get("hurt_break_hit", false))
	for hit: Dictionary in hits:
		if bool(hit.get("isBreakDef", hit.get("is_break_def", false))): break_def = true
	var raw := int(source.get("current_hurt_damage", raw_hurt_damage(hits)))
	var hurting := bool(source.get("hurting", str(source.get("action_state", "")) in ["hurt", "21"]))
	var reason := ""
	if not bool(source.get("alive", true)): reason = "not_alive"
	elif not hurting: reason = "not_render_hurt_route"
	elif not bool(source.get("special_pressed", false)): reason = "no_special_input"
	# hasEnergy(50,false) NEVER relies on the overflow branch. At energy>=50 an
	# existing overload flag does not veto it; do not add a !energy_overload rule.
	elif float(source.get("energy", 0)) < REQUIRED_ENERGY: reason = "energy_below_50"
	elif float(source.get("qi", 0)) < QI_COST: reason = "qi_below_100"
	elif last_bisha: reason = "last_hurt_is_bisha"
	elif break_def: reason = "hurt_history_contains_break_def"
	elif raw > MAX_RAW_HURT: reason = "raw_hurt_above_210"
	return {"allowed":reason.is_empty(), "reason":reason, "raw_hurt_damage":raw,
		"last_bisha":last_bisha, "hurt_break_hit":break_def}

static func can(source: Dictionary) -> bool:
	return bool(eligibility(source)["allowed"])

## Exact new HitVO defaults plus FighterMain.energyExplode assignments.
## hitx is signed source px/frame, NOT world velocity; caller converts it once.
static func hit_vo(facing: int = 1) -> Dictionary:
	return {"id":null, "owner":null, "power":50.0, "powerAdd":0.0, "powerRate":1.0,
		"hitType":5, "isBreakDef":false, "hitx":15.0 * facing, "hity":0.0,
		"hurtTime":300.0, "hurtType":1, "slowDown":0.0, "checkDirect":true,
		"focusTarget":false, "targetApplyG":true, "source_rect":SOURCE_RECT}

## position is a Godot world coordinate. Unlike normal-body adaptation, this effect
## uses original stage-unit geometry (1.6x). The rectangle snapshots the CAST position.
static func begin(source: Dictionary, position: Vector2 = Vector2.ZERO, facing: int = 1, stage_unit: float = DEFAULT_STAGE_UNIT) -> Dictionary:
	var check := eligibility(source)
	if not check["allowed"]: return {"allowed":false, "reason":check["reason"], "state":source.duplicate(true)}
	if int(source.get("comic_type", 0)) == 1:
		# A separate source replaceSkill branch exists. It is deliberately not claimed
		# as this module's energy-explode behavior; our meme resource type is0.
		return {"allowed":false, "reason":"comic_type_1_requires_replace_skill", "state":source.duplicate(true)}
	var state: Dictionary = HitRules.use_energy(source.duplicate(true), ENERGY_COST)
	state["qi"] = float(source["qi"]) - QI_COST
	state["break_kind"] = "energy_explode"
	state["resource_selection"] = "original_memes_choose_non_naruto_comic_type"
	state["hit_frames"] = 10
	state["steel_frames"] = 60
	state["allow_be_hit"] = false
	state["steel"] = true
	state["super_steel"] = true
	state["hit_vo"] = hit_vo(facing)
	state["hit_area"] = Rect2(position + SOURCE_RECT.position * stage_unit, SOURCE_RECT.size * stage_unit)
	state["cast_position"] = position
	state["facing"] = facing
	state["source_clock"] = 0.0
	state["idle_event"] = false
	state["events"] = []
	state["hurting"] = bool(source.get("hurting", str(source.get("action_state", "")) in ["hurt", "21"]))
	state["just_hurt_resume"] = bool(state.get("just_hurt_resume", false))
	# Source energyExplode does not immediately reset the hurt motion or enter idle.
	return {"allowed":true, "reason":"", "state":state, "events":["energy_explode"],
		"training_command":"ASSIST", "dispatch_hurt_resume":true}

## Exactly one FighterMain.renderAnimate frame AFTER the controller's prelude.
## Returned idle_event requests the actual source idle() transition; apply final
## allow_be_hit/steel values after idle, since energyExplode overwrites its side effects.
static func render_frame(previous: Dictionary) -> Dictionary:
	var state := previous.duplicate(true)
	var events: Array[String] = []
	state["idle_event"] = false
	if bool(state.get("just_hurt_resume", false)):
		state["allow_be_hit"] = true
		state["just_hurt_resume"] = false
	var hit_frames := int(state.get("hit_frames", 0))
	if hit_frames > 0:
		hit_frames -= 1
		state["hit_frames"] = hit_frames
		if hit_frames == 8:
			state["idle_event"] = true
			events.append("idle")
			# onIdleEnter(wasHurting) sets a next-frame prelude flag. Subsequent
			# source code overwrites idle's allowBeHit value to false this frame.
			if bool(state.get("hurting", false)): state["just_hurt_resume"] = true
			state["hurting"] = false
			state["allow_be_hit"] = false
			state["clear_hurt_history"] = true
		if hit_frames <= 0:
			state["hit_vo"] = {}
			state["allow_be_hit"] = true
	var steel_frames := int(state.get("steel_frames", 0))
	if steel_frames > 0:
		steel_frames -= 1
		state["steel_frames"] = steel_frames
		state["steel"] = steel_frames > 0
		state["super_steel"] = steel_frames > 0
	state["events"] = events
	return state

## 60Hz/variable-rate adapter; timers only advance at the official30Hz animation rate.
## Resource regeneration remains in the existing resource module, avoiding double ticking.
static func tick(previous: Dictionary, delta: float) -> Dictionary:
	var state := previous.duplicate(true)
	var clock := float(state.get("source_clock", 0)) + maxf(0, delta)
	var events: Array[String] = []
	while clock + 0.0000001 >= 1.0 / SOURCE_FPS:
		state = render_frame(state)
		for event: String in state["events"]: events.append(event)
		clock -= 1.0 / SOURCE_FPS
	state["source_clock"] = maxf(0, clock)
	state["events"] = events
	state["idle_event"] = events.has("idle")
	return state

## Matches FighterMain.getCurrentHits: strict counter<8 and nonnull VO.
## These are seven active animation frames(counter7..1), not all ten timer frames.
static func current_hit(state: Dictionary) -> Dictionary:
	var remaining := int(state.get("hit_frames", 0))
	var vo: Dictionary = state.get("hit_vo", {})
	if vo.is_empty() or remaining >= 8 or remaining <= 0: return {}
	var result := vo.duplicate(true)
	result["currentArea"] = state["hit_area"]
	# Aliases for the already ported pure HitRules reader. owner=null is critical:
	# hitx was signed at cast time and MUST NOT be multiplied by facing again.
	result.merge({"power_add":result["powerAdd"], "power_rate":result["powerRate"],
		"hit_type":result["hitType"], "hurt_type":result["hurtType"],
		"hurt_time_ms":result["hurtTime"], "is_break_def":result["isBreakDef"],
		"is_bisha":false, "check_direct":result["checkDirect"], "has_owner":false,
		"target_apply_g":result["targetApplyG"], "area":state["hit_area"],
		"current_area":state["hit_area"]}, true)
	return result
