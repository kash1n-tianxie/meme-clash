extends RefCounted
## Copyright (C) 2021-2024 5DPLAY Game Studio; Godot translation (C) 2026.
## SPDX-License-Identifier: GPL-3.0-or-later
## Official commit891f5776dbdf3cbf40919e27aa8d6e77a5f66c97.
## FighterMcHurtCtrl.as:118-124,158-163,360-446; FighterMcCtrler.as:717,797.
## Source game ticks update just-defense; source animation ticks update held
## defense/post-decrement delay. Physical reactions/resources remain HitRules.
const GAME_FPS := 60.0
const ANIMATION_FPS := 30.0
const DEFENSE_ACTIONS := ["skill1","zhao2","bishaSUPER","jumpDown"]

static func fresh() -> Dictionary:
	return {"active":false,"guard":false,"just_frames":6,"delay":0,"resume_pending":false}

static func idle_enter(state: Dictionary) -> Dictionary:
	var next:=clear(state)
	next["just_frames"]=int(.1*GAME_FPS)
	return next

static func clear(state: Dictionary) -> Dictionary:
	var next: Dictionary=state.duplicate()
	next["active"]=false; next["guard"]=false; next["resume_pending"]=false
	return next

static func enter(state: Dictionary,is_just_defense: bool=false) -> Dictionary:
	var next: Dictionary=state.duplicate()
	next["active"]=true
	next["guard"]=is_just_defense or int(next.get("just_frames",0))>0
	next["delay"]=1
	next["resume_pending"]=false
	return next

static func tick_game(state: Dictionary) -> Dictionary:
	var next: Dictionary=state.duplicate()
	next["just_frames"]=maxi(0,int(next.get("just_frames",0))-1)
	return next

static func render_animate(state: Dictionary,held: bool,defense_hitting: bool=false) -> Dictionary:
	var next: Dictionary=state.duplicate()
	var result: Dictionary={"next":next,"idle":false}
	if not bool(next.get("active",false)): return result
	# goFrame(DEFENSE_RESUME, ..., {call: idle, delay:1}) is one animation tick.
	if bool(next.get("resume_pending",false)):
		result["next"]=idle_enter(next); result["idle"]=true
		return result
	if defense_hitting: return result
	var previous:=int(next.get("delay",0))
	next["delay"]=previous-1
	if previous>0: return result
	if held:
		next["guard"]=true
	elif int(next["delay"])<=-5:
		next["resume_pending"]=true
	return result

static func actions() -> Dictionary:
	var result: Dictionary={}
	for key: String in DEFENSE_ACTIONS: result[key]=true
	return result
