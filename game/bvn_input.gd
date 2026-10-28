extends RefCounted
## Copyright (C) 2021-2024 5DPLAY Game Studio; Godot port (C) 2026.
## SPDX-License-Identifier: GPL-3.0-or-later
## Translated from official BVN commit 891f5776dbdf3cbf40919e27aa8d6e77a5f66c97:
## GameInputer.as:35,119-126,257-286; FighterKeyCtrl.as:60-201;
## FighterMcFloorHandler.as:100-157; FighterMcAirHandler.as:164-215.
## Godot/our character adapters: semantic slot names, one selected command per tick,
## the existing down-air skill clip, and burst/throw-tech handled by Battle.

const INPUT_DELAY := 0.1
const WATCHED_SLOTS := [4,5,6,7,8]
var delayed_keys: Dictionary = {}

func clear() -> void:
	delayed_keys.clear()

## A raw press remains visible for 100ms, just like JUST_DOWN_DELAY * game FPS.
## The caller supplies rising edges (keyboard events and gamepad), not key repeat.
func tick(delta: float, rising: Dictionary) -> Dictionary:
	for slot in delayed_keys.keys():
		delayed_keys[slot]=float(delayed_keys[slot])-delta
		if float(delayed_keys[slot])<=0.00001: delayed_keys.erase(slot)
	for slot in WATCHED_SLOTS:
		if rising.get(slot,false): delayed_keys[slot]=INPUT_DELAY
	var result:=rising.duplicate()
	for slot in WATCHED_SLOTS: result[slot]=delayed_keys.has(slot)
	return result

## Each boolean predicate corresponds to a FighterKeyCtrl public method.
static func predicates(axis: float,up: bool,down: bool,keys: Dictionary,attack_held: bool=false,jump_held: bool=false) -> Dictionary:
	var attack: bool=keys.get(4,false)
	var jump: bool=keys.get(5,false)
	var dash: bool=keys.get(6,false)
	var skill: bool=keys.get(7,false)
	var super_skill: bool=keys.get(8,false)
	return {
		"moveLEFT":axis<0,"moveRIGHT":axis>0,"defense":down,
		"attack":attack and not(up or down or jump_held),
		"jump":jump and not attack_held,"jumpQuick":jump and not attack_held,
		"jumpDown":down and jump,
		# AS3's comma operator in dash() evaluates the down operand. Keep it explicit.
		"dash":dash and not down,"dashJump":dash,
		"skill1":down and attack,"skill2":up and attack,
		"zhao1":skill and not up and not down,"zhao2":down and skill,"zhao3":up and skill,
		"catch1":attack and absf(axis)>0.1,"catch2":skill and absf(axis)>0.1,
		"bisha":super_skill and not(up or down),"bishaUP":super_skill and up,
		"bishaSUPER":super_skill and down,
		"attackAIR":attack,"skillAIR":skill,"bishaAIR":super_skill,
		"ghostStep":dash and down,"ghostJump":dash and up,"ghostJumpDown":dash and down
	}

## Ordered exactly as the relevant floor/air handler calls, with explicit clip map.
static func command_candidates(flags: Dictionary,grounded: bool,catch_allowed: bool=false,down: bool=false,faithful_bindings: bool=false,attacking: bool=false) -> Array[String]:
	var result: Array[String]=[]
	if grounded:
		if catch_allowed:
			if faithful_bindings:
				if flags["catch1"]: result.append("throw1")
				if flags["catch2"]: result.append("throw2")
			elif flags["catch1"] or flags["catch2"]: result.append("throw")
		for pair in [["bishaSUPER","super_down"],["bishaUP","super_up"],["bisha","super"],
			["skill2","launcher"],["skill1","sweep"],["zhao3","skill2"],
			["zhao2","skill3"],["attack","attack"],["zhao1","skill1"],
			["jump","jump"]]:
			if flags[pair[0]]: result.append(pair[1])
		if flags["ghostStep"]: result.append("ghost")
		elif flags["ghostJump"]: result.append("ghost_up")
		elif flags["dash"]: result.append("dash")
		# FloorHandler's original final block permits AIR slots during an
		# attack if a source frame explicitly registered them (e.g. landing J).
		if faithful_bindings and attacking:
			if flags["attackAIR"]: result.append("air_light")
			if flags["skillAIR"]: result.append("air_skill")
			if flags["bishaAIR"]: result.append("air_super")
	else:
		if flags["attackAIR"]: result.append("air_light")
		if flags["skillAIR"]: result.append("air_slam" if down and not faithful_bindings else "air_skill")
		if flags["bishaAIR"]: result.append("air_super")
		if flags["jump"]: result.append("fastfall" if down else "jump")
		# Original AirHandler's floor calls are only available during an action;
		# actual setter/checkFrame permissions are still checked by the actor.
		if faithful_bindings and attacking:
			for pair in [["bishaSUPER","super_down"],["bishaUP","super_up"],["bisha","super"],["skill2","launcher"],["skill1","sweep"],["zhao3","skill2"],["zhao2","skill3"],["attack","attack1"],["zhao1","skill1"]]:
				if flags[pair[0]]: result.append(pair[1])
		if flags["ghostJumpDown"]: result.append("ghost_down")
		elif flags["ghostJump"]: result.append("ghost_up")
		elif flags["dash"]: result.append("dash")
	return result

## FighterActionLogic uses an enabled controller AND the current frame's action flag.
## Frame flags come from this game's authored clip timelines, not upstream anime art.
static func enabled_action(frame_flags: Dictionary,action_name: String,controller_enabled: bool=true,musou_allowed: bool=true) -> bool:
	return controller_enabled and musou_allowed and bool(frame_flags.get(action_name,false))
