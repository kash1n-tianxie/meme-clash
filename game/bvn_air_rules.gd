extends RefCounted
## Copyright (C) 2021-2026, 5DPLAY Game Studio; Godot port (C) 2026.
## SPDX-License-Identifier: GPL-3.0-or-later
## BVN 891f577: FighterMcAirHandler.as:66-139,288-418; FighterMain.as:68,77-78,535-538.
## Clip names and the 1280/800 stage-unit conversion are our Godot adapters.

const ANIMATION_FPS := 30.0
const GROUND_JUMP_DELAY := 2.0/ANIMATION_FPS
const AIR_JUMP_DELAY := 1.0/ANIMATION_FPS
const DEFAULT_JUMPS := 2
const DEFAULT_AIR_HITS := 1
const JUMP_POWER := 15.0
const STAGE_UNIT_SCALE := 1.6
const JUMP_VELOCITY := -JUMP_POWER*ANIMATION_FPS*STAGE_UNIT_SCALE

static func can_jump(remaining: int) -> bool:
	return remaining>0

static func jump_delay(on_ground: bool) -> float:
	return GROUND_JUMP_DELAY if on_ground else AIR_JUMP_DELAY

## A frame-defined route may continue an air combo after the free air action is used.
## An unconnected new air move requires remaining airHitTimes, as the source does.
static func can_air_action(doing_action: bool,remaining_hits: int) -> bool:
	return doing_action or remaining_hits>0

static func begin_air_action(remaining_hits: int,skill: bool=false) -> Dictionary:
	return {"air_hits":0 if skill else remaining_hits-1,"jumps":0}

## FighterMcAirHandler.doAirBisha:405-418 clears airHitTimes only. Unlike
## doAirAttack/doAirSkill, it does not consume the remaining jumpTimes.
static func begin_air_bisha(remaining_jumps: int) -> Dictionary:
	return {"air_hits":0,"jumps":remaining_jumps}

static func landing_counts() -> Dictionary:
	return {"air_hits":DEFAULT_AIR_HITS,"jumps":DEFAULT_JUMPS}
