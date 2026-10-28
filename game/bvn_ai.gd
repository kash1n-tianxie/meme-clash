extends RefCounted
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2021-2024, 5DPLAY Game Studio. Godot language port, 2026.
# Upstream: 5DPLAY-Game-Studio/BleachVsNaruto, commit
# 891f5776dbdf3cbf40919e27aa8d6e77a5f66c97.
# Direct behavioral port, source coordinates and source numeric action states.
# FighterAICtrl.as:83-100,102-219 (enabled predicates, 30Hz animation render).
# FighterAILogicBase.as:57-64,85-149,172-232 (ranges, random tables, combo order).
# FighterAILogic.as:75-137,149-161,176-679 (six levels and individual decisions).
# Actor labels and hit-range metadata are supplied by the adapter, never invented here.
# The source's sticky special/ghost flags, duplicate order entries, hit-down cache
# write and impossible ghost-down interval are intentionally preserved; see tests.

const SOURCE_COMMIT := "891f5776dbdf3cbf40919e27aa8d6e77a5f66c97"
const FPS_ANIMATE := 30.0
const FPS_GAME := 60
const NORMAL := 0
const FREEZE := 40
const ATTACK := 10
const SKILL := 11
const BISHA := 12
const BISHA_SUPER := 13
const JUMP := 14
const HURT_ACT := 16
const DEFENSE := 20
const HURT := 21
const HURT_FLYING := 22
const HURT_DOWN := 23
const PREDICATES := ["moveLeft", "moveRight", "jump", "jumpDown", "dash", "downJump", "defense", "attack", "attackAIR", "skillAIR", "bishaAIR", "skill1", "skill2", "zhao1", "zhao2", "zhao3", "catch1", "catch2", "bisha", "bishaUP", "bishaSUPER", "assist", "specialSkill", "ghostStep", "ghostJump", "ghostJumpDowm"]

# Values are compared against Math.random()*10, not percentages.
const RATES := {
	"R0": [0, 0, 0, 0, 0, 0],
	"R_DJ": [0, 0, 0.2, 1, 3, 5],
	"R_MV": [3, 5, 7, 8, 9, 10],
	"R_MV_ATK": [2, 4, 5, 3, 1, 0],
	"R_MV_SK": [2, 4, 3, 2, 0, 0],
	"R_MV_BS": [2, 1, 0, 0, 0, 0],
	"R_JP_C": [1, 2, 3, 2, 1, 0],
	"R_JP_CH": [0, 1, 2, 3, 3, 4],
	"R_JP_UP": [2, 3, 4, 5, 6, 6],
	"R_JP_LO": [0.01, 0, 0, 0, 0, 0],
	"R_JP_LB": [0.02, 0, 0, 0, 0, 0],
	"R_DSH1": [0, 0, 0.1, 0.5, 0, 0],
	"R_DSH2": [0, 0.05, 0.3, 1, 0, 0],
	"R_DSH3": [0, 0, 0.05, 0, 0, 0],
	"R_DSH4": [0.5, 1, 2, 5, 7, 9],
	"R_DSH5": [0, 0, 0.1, 3, 1, 0],
	"R_DSH6": [0, 0, 0.05, 1, 0, 0],
	"R_DSH7": [0, 0, 0.05, 0.1, 0, 0],
	"R_DEF_C": [10, 10, 10, 10, 10, 10],
	"R_DEF_F": [5, 4, 4, 3, 2, 1],
	"R_DEF_N": [2, 1, 1, 0, 0, 0],
	"R_DEF_N2": [0.5, 1, 3, 5, 7, 9],
	"R_DEF_F2": [0.5, 1, 3, 2, 1, 0],
	"R_DEF_SK": [1, 3, 5, 7, 9, 10],
	"R_DEF_BS": [2, 4, 6, 8, 10, 10],
	"R_ATK_C": [1, 2, 3, 6, 9, 10],
	"R_ATK_D": [0.5, 1, 4, 6, 8, 10],
	"R_ATK_DF": [0.5, 1, 3, 2, 2, 1],
	"R_ATK_HA": [0.5, 1, 1, 0.5, 0, 0],
	"R_ATK_A": [0.5, 1, 1, 0, 0, 0],
	"R_SK_B1": [0.1, 0.2, 0.5, 3, 6, 10],
	"R_SK_B2": [0, 0.2, 0.5, 2, 1, 0],
	"R_SK_B3": [0, 0.2, 0.7, 5, 7, 9],
	"R_SK_B4": [0.1, 0.2, 0.5, 1, 2, 2],
	"R_SK_N1": [0, 0, 0.1, 1, 5, 10],
	"R_SK_N2": [0.1, 0.5, 1, 3, 2, 0.2],
	"R_SK_N3": [0, 0, 1, 1, 0, 0],
	"R_SK_HA": [0.5, 1, 0.5, 0, 0, 0],
	"R_SK_AT": [0, 0, 0, 1, 1, 2],
	"R_BS_B1": [0, 0, 0.3, 2, 5, 10],
	"R_BS_B2": [0.1, 0.2, 0.5, 2, 2, 2],
	"R_BS_B3": [0, 0, 0.5, 3, 7, 9],
	"R_BS_B4": [0.1, 0.2, 1, 6, 8, 10],
	"R_BS_N1": [0, 0, 0.5, 4, 8, 10],
	"R_BS_N2": [0.2, 0.5, 1, 2, 2, 0],
	"R_BS_H": [0.2, 0.5, 1, 3, 5, 6],
	"R_BS_J": [0.2, 0.5, 1, 3, 4, 4],
	"R_BS_D1": [0.2, 0.5, 1, 3, 2, 1],
	"R_BS_D2": [0.2, 0.5, 1, 2, 1, 0],
	"R_BS_HA": [0.2, 0.5, 0, 0, 0, 0],
	"R_BS_AT": [0, 0.2, 0.5, 2, 1, 1],
	"R_BS_SK": [0, 0, 0.1, 0, 0, 0],
	"R_CA_N": [0, 0.5, 1, 3, 2, 1],
	"R_CA_D": [1, 2, 4, 5, 7, 10],
	"R_CA_NF": [0, 0.5, 1, 0, 0, 0],
	"R_CA_DF": [1, 2, 3, 4, 3, 2],
	"R_BRK": [0, 0, 0, 0, 0.1, 0.2],
	"R_BRK_S": [0, 0, 0, 0, 0.2, 0.4],
	"R_CALL": [0, 0.02, 0.05, 0.05, 0, 0],
	"R_CALL_D": [0, 0.02, 0.05, 0.1, 0.3, 0.5],
	"R_GS": [0, 0, 0, 0, 0.1, 0.2],
	"R_GS_J": [0, 0, 0.1, 0.1, 0.1, 0.1],
	"R_GS_D": [0, 0, 0, 0.1, 0.1, 0.1],
}

var ai_level := 3
var predicates: Dictionary = {}
var rendered_frames := 0
var _clock := 0.0
var _move_frame := 0
var _self: Dictionary = {}
var _target: Dictionary = {}
var _threats: Array = []
var _action_flags: Dictionary = {}
var _ranges: Dictionary = {}
var _hit_traits: Dictionary = {}
var _conting := false
var _cont_order: Array[Dictionary] = []
var _break_cache: Dictionary = {}
var _hit_down_cache: Dictionary = {}
var _random_source := Callable()

func _init() -> void:
	reset()

func configure(level: int = 3) -> void:
	ai_level = level
	reset()

func reset() -> void:
	predicates.clear()
	for key in PREDICATES:
		predicates[key] = false
	_clock = 0.0
	_move_frame = 0
	rendered_frames = 0
	_cont_order.clear()
	_break_cache.clear()
	_hit_down_cache.clear()

# Test/replay injection. An invalid Callable uses the normal uniform RNG.
func set_random_source(provider: Callable) -> void:
	_random_source = provider

# Call only while the source game is action-enabled; freeze/hitstop must freeze
# this clock too, as FighterAICtrl checks GameCtrl.actionEnable.
func tick(delta: float, self_state: Dictionary, target_state: Dictionary,
		threats: Array = [], action_flags: Dictionary = {},
		ranges: Dictionary = {}, hit_traits: Dictionary = {}) -> Dictionary:
	_self = self_state
	_target = target_state
	_threats = threats
	_action_flags = action_flags
	_ranges = ranges
	_hit_traits = hit_traits
	if _self.is_empty() or _target.is_empty():
		return predicates.duplicate()
	_clock += maxf(delta, 0.0)
	while _clock + 0.0000001 >= 1.0 / FPS_ANIMATE:
		_clock -= 1.0 / FPS_ANIMATE
		_render_frame()
	return predicates.duplicate()

func get_debug_state() -> Dictionary:
	return {"level": ai_level, "rendered_frames": rendered_frames,
		"move_frame": _move_frame, "pending_combo_order": _cont_order.duplicate(true),
		"predicates": predicates.duplicate(), "source_commit": SOURCE_COMMIT}

func _sample() -> float:
	return float(_random_source.call()) if _random_source.is_valid() else randf()

func _level_index() -> int:
	return 0 if ai_level in [0, 1] else ai_level - 1 if ai_level in [2, 3, 4, 5] else 5

func _prob(rate_name: String) -> bool:
	var level_index := _level_index()
	return _sample() * 10.0 < float(RATES[rate_name][level_index])

func _target_state() -> int:
	return int(_target.get("action_state", NORMAL)) if bool(_target.get("is_fighter", true)) else -1

func _by_state(default_rate: String, overrides: Dictionary = {}) -> bool:
	return _prob(str(overrides.get(_target_state(), default_rate)))

func _enabled(key: String) -> bool:
	return bool(_action_flags.get(key, false))

func _distance(target: Dictionary) -> Vector2:
	return Vector2(absf(float(target.get("x", 0.0)) - float(_self.get("x", 0.0))),
		absf(float(target.get("y", 0.0)) - float(_self.get("y", 0.0))))

func _target_in_range(key: String) -> bool:
	var area: Variant = _target.get("body_area")
	var hit_range: Variant = _ranges.get(key)
	return area is Rect2 and hit_range is Rect2 and area.intersects(hit_range)

func _can_hit() -> bool:
	if bool(_target.get("is_fighter", true)):
		return bool(_target.get("allow_be_hit", false))
	return _target.get("body_area") is Rect2

func _hit_entries(key: String) -> Array:
	var entries: Variant = _hit_traits.get(key, [])
	if entries is Dictionary:
		return [entries]
	return entries if entries is Array else []

func _is_break_act(key: String) -> bool:
	if _break_cache.has(key):
		return bool(_break_cache[key])
	for hit in _hit_entries(key):
		if bool(hit.get("is_break_def", hit.get("isBreakDef", false))):
			_break_cache[key] = true
			return true
	_break_cache[key] = false
	return false

func _is_hit_down_act(key: String) -> bool:
	if _hit_down_cache.has(key):
		return bool(_hit_down_cache[key])
	# Upstream Base.as:189-202 writes into _breakActCache, not _hitDownActCache.
	for hit in _hit_entries(key):
		if int(hit.get("hurt_type", hit.get("hurtType", 0))) == 1:
			_break_cache[key] = true
			return true
	_break_cache[key] = false
	return false

func _add_order(key: String, order: int) -> void:
	# Source indexOf(string) cannot find object entries, so duplicate IDs are kept.
	_cont_order.append({"id": key, "order": order})

func _update_order() -> void:
	if _cont_order.is_empty():
		return
	_cont_order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) > int(b["order"]))
	for index in range(1, _cont_order.size()):
		predicates[str(_cont_order[index]["id"])] = false
	_cont_order.clear()

func _render_frame() -> void:
	rendered_frames += 1
	_conting = int(_self.get("action_state", NORMAL)) in [ATTACK, SKILL, BISHA, BISHA_SUPER]
	# Base.render calls updateActionAI and priority resolution first. Jump's order
	# is added afterwards and intentionally survives until the next source frame.
	_update_dash()
	_update_attack()
	_update_skill()
	_update_bisha()
	_update_catch()
	_update_assist()
	_update_order()
	_update_move()
	_update_jump()
	_update_jump_down()
	predicates["downJump"] = _by_state("R_DJ", {SKILL: "R0", BISHA: "R0", BISHA_SUPER: "R0"})
	_update_defense()
	_update_special_skill()
	_update_ghost()

func _update_move() -> void:
	predicates["moveLeft"] = false
	predicates["moveRight"] = false
	var self_x := float(_self.get("x", 0.0))
	var target_x := float(_target.get("x", 0.0))
	if int(_self.get("action_state", NORMAL)) == DEFENSE:
		if _sample() * 10.0 < float([1, 2, 4, 5, 6, 8][_level_index()]):
			predicates["moveLeft"] = self_x > target_x + 20.0
			predicates["moveRight"] = self_x < target_x - 20.0
		return
	var moving := false
	if _move_frame < FPS_GAME:
		_move_frame += 1
		moving = true
	else:
		moving = _by_state("R_MV", {ATTACK: "R_MV_ATK", SKILL: "R_MV_SK", BISHA: "R_MV_BS", BISHA_SUPER: "R_MV_BS"})
		if moving:
			_move_frame = 0
	if moving:
		var catch_move: bool = (predicates["catch1"] or predicates["catch2"]) and _distance(_target).y < 2.0
		var keep := 15.0 if catch_move else 40.0
		predicates["moveLeft"] = self_x > target_x + keep
		predicates["moveRight"] = self_x < target_x - keep
	if not predicates["moveLeft"] and not predicates["moveRight"]:
		_move_frame = FPS_GAME

func _update_jump() -> void:
	if _conting:
		predicates["jump"] = _by_state("R_JP_C", {HURT: "R_JP_CH"})
	elif float(_self.get("y", 0.0)) > float(_target.get("y", 0.0)) + 50.0:
		predicates["jump"] = _by_state("R_JP_UP", {BISHA: "R_MV_BS", BISHA_SUPER: "R_MV_BS"})
	else:
		predicates["jump"] = _by_state("R_JP_LO", {BISHA: "R_JP_LB", BISHA_SUPER: "R_JP_LB"})
	if _conting and predicates["jump"]:
		_add_order("jump", 10)

func _update_jump_down() -> void:
	if float(_self.get("y", 0.0)) < float(_target.get("y", 0.0)) - 50.0:
		predicates["jumpDown"] = _by_state("R_JP_UP", {BISHA: "R_MV_BS", BISHA_SUPER: "R_MV_BS"})
	else:
		predicates["jumpDown"] = _by_state("R_JP_LO", {BISHA: "R_JP_LB", BISHA_SUPER: "R_JP_LB"})

func _update_dash() -> void:
	var far := _distance(_target).x > 200.0
	var direct := 1 if float(_target.get("x", 0.0)) > float(_self.get("x", 0.0)) else -1
	var attacking_zero := {ATTACK: "R0", SKILL: "R0", BISHA: "R0", BISHA_SUPER: "R0"}
	if float(_self.get("energy", 0.0)) < 40.0:
		if far and int(_self.get("direct", 1)) == direct:
			predicates["dash"] = _by_state("R_DSH1", {ATTACK: "R_DSH2", SKILL: "R_DSH2", BISHA: "R0", BISHA_SUPER: "R0"})
		else:
			predicates["dash"] = _by_state("R_DSH3", attacking_zero)
	elif far and int(_self.get("direct", 1)) != int(_target.get("direct", -1)):
		predicates["dash"] = _by_state("R_DSH4", {ATTACK: "R_DSH5", SKILL: "R_DSH6", BISHA: "R0", BISHA_SUPER: "R0"})
	else:
		predicates["dash"] = _by_state("R_DSH7", attacking_zero)

func _update_defense() -> void:
	if predicates["defense"]:
		predicates["defense"] = _by_state("R_DEF_C", {FREEZE: "R_DEF_F", NORMAL: "R_DEF_N", HURT: "R0", HURT_FLYING: "R0", HURT_DOWN: "R0"})
		if predicates["defense"]:
			return
	var distance := _distance(_target)
	predicates["defense"] = _by_state("R0", {ATTACK: "R_DEF_N2" if distance.x < 100.0 and distance.y < 100.0 else "R_DEF_F2", SKILL: "R_DEF_SK", BISHA: "R_DEF_BS", BISHA_SUPER: "R_DEF_BS"})
	if predicates["defense"]:
		return
	for threat in _threats:
		if not bool(threat.get("attacking", false)):
			continue
		var rates: Array = []
		match str(threat.get("kind", "")):
			"bullet":
				var dis := _distance(threat)
				rates = [2, 4, 5, 7, 9, 10] if dis.x < 200.0 and dis.y < 150.0 else [2, 4, 5, 5, 2, 1]
			"attacker": rates = [2, 4, 5, 7, 9, 10]
			"assister": rates = [2, 4, 6, 8, 10, 10]
		if not rates.is_empty():
			var index := _level_index()
			predicates["defense"] = _sample() * 10.0 < float(rates[index])
			if predicates["defense"]:
				return

func _update_attack() -> void:
	predicates["attack"] = false
	predicates["attackAIR"] = false
	if not (_enabled("attack") or _enabled("attackAIR")) or not _can_hit():
		return
	if not _by_state("R_ATK_C" if _conting else "R_ATK_D", {DEFENSE: "R_ATK_DF", HURT_ACT: "R_ATK_HA", ATTACK: "R_ATK_A", SKILL: "R0", BISHA: "R0", BISHA_SUPER: "R0"}):
		return
	var order := 10
	if _conting:
		predicates["attack"] = true
		predicates["attackAIR"] = float(_self.get("y", 0.0)) < float(_target.get("y", 0.0))
		if str(_self.get("cur_action", "")) == "砍1":
			order = 200
	else:
		predicates["attack"] = _target_in_range("kanmian")
		predicates["attackAIR"] = _target_in_range("tkanmian") and float(_self.get("y", 0.0)) < float(_target.get("y", 0.0))
		order = 300
	for key in ["attack", "attackAIR"]:
		if predicates[key]:
			_add_order(key, order)

func _update_skill() -> void:
	for spec in [["skill1", "kj1", "kj1mian"], ["skill2", "kj2", "kj2mian"], ["zhao1", "zh1", "zh1mian"], ["zhao2", "zh2", "zh2mian"], ["zhao3", "zh3", "zh3mian"], ["skillAIR", "tz", "tzmian"]]:
		predicates[spec[0]] = _enabled(spec[0]) and _skill_ai(spec[0], spec[1], spec[2])

func _skill_ai(key: String, hit_id: String, hit_range: String) -> bool:
	var rates := {HURT_ACT: "R_SK_HA", ATTACK: "R_SK_AT", SKILL: "R0", BISHA: "R0", BISHA_SUPER: "R0"}
	var default_rate: String
	if _is_break_act(hit_id):
		default_rate = "R_SK_B1" if _conting else "R_SK_B2"
		rates[DEFENSE] = "R_SK_B3" if _conting else "R_SK_B4"
	else:
		default_rate = "R_SK_N1" if _conting else "R_SK_N2"
		rates[DEFENSE] = "R_SK_N3"
	var result := _by_state(default_rate, rates) and _can_hit() and _target_in_range(hit_range)
	if result and _conting:
		_add_order(key, 10 if _is_hit_down_act(hit_id) else 110)
	return result

func _update_bisha() -> void:
	for spec in [["bisha", "bs", "bsmian", 100, 100], ["bishaUP", "sbs", "sbsmian", 100, 100], ["bishaSUPER", "cbs", "cbsmian", 300, 200], ["bishaAIR", "kbs", "kbsmian", 100, 210]]:
		predicates[spec[0]] = _enabled(spec[0]) and _bisha_ai(spec[0], spec[1], spec[2], spec[3], spec[4])

func _bisha_ai(key: String, hit_id: String, hit_range: String, qi: int, order: int) -> bool:
	var result := false
	if float(_self.get("qi", 0.0)) >= qi:
		var rates := {HURT_ACT: "R_BS_HA", ATTACK: "R_BS_AT", SKILL: "R_BS_SK", BISHA: "R_BS_SK", BISHA_SUPER: "R_BS_SK"}
		var default_rate: String
		if _is_break_act(hit_id):
			default_rate = "R_BS_B1" if _conting else "R_BS_B2"
			rates[DEFENSE] = "R_BS_B3" if _conting else "R_BS_B4"
		else:
			default_rate = "R_BS_N1" if _conting else "R_BS_N2"
			rates[HURT] = "R_BS_H"
			rates[JUMP] = "R_BS_J"
			rates[DEFENSE] = "R_BS_D1" if _conting else "R_BS_D2"
		result = _by_state(default_rate, rates) and _can_hit() and _target_in_range(hit_range)
	if result and _conting:
		_add_order(key, order)
	return result

func _update_catch() -> void:
	predicates["catch1"] = false
	predicates["catch2"] = false
	if _target_state() in [HURT, HURT_FLYING, HURT_DOWN]:
		return
	var near := _distance(_target).x < 50.0
	for spec in [["catch1", 150], ["catch2", 110]]:
		predicates[spec[0]] = _by_state("R_CA_N" if near else "R_CA_NF", {DEFENSE: "R_CA_D" if near else "R_CA_DF"}) and _can_hit()
		if predicates[spec[0]]:
			_add_order(spec[0], spec[1])

func _update_assist() -> void:
	predicates["assist"] = _by_state("R_CALL", {DEFENSE: "R_CALL_D", BISHA: "R0", BISHA_SUPER: "R0"})

func _update_special_skill() -> void:
	if int(_self.get("action_state", NORMAL)) != HURT:
		return
	if float(_self.get("hp", 0.0)) > float(_self.get("hp_max", 0.0)) * 0.6 or float(_self.get("qi", 0.0)) < 150.0:
		return
	predicates["specialSkill"] = _by_state("R_BRK", {SKILL: "R_BRK_S"})

func _update_ghost() -> void:
	var dis := _distance(_target)
	if dis.x > 80.0 or dis.y > 80.0 or float(_self.get("qi", 0.0)) < 200.0:
		return
	if int(_self.get("action_state", NORMAL)) not in [ATTACK, SKILL]:
		return
	predicates["ghostStep"] = _by_state("R0", {HURT: "R_GS"})
	var diff := float(_target.get("y", 0.0)) - float(_self.get("y", 0.0))
	predicates["ghostJump"] = _by_state("R0", {HURT: "R_GS_J"}) if diff < -80.0 and diff > -100.0 else false
	# Upstream <80 && >100 interval is intentionally impossible.
	predicates["ghostJumpDowm"] = _by_state("R0", {HURT: "R_GS_D"}) if diff < 80.0 and diff > 100.0 else false
