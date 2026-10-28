extends RefCounted
# SPDX-License-Identifier: GPL-3.0-or-later
# Godot port of 5DPLAY BVN core behavior, Copyright (C) 2021-2026 5DPLAY Game Studio.
# Source: work/reference-bvn/CORE_KernelLogic/src/net/play5d/game/bvn/
# GameMainLogicCtrl.as:383-440; FighterMain.as:258-300,541-576,703-725;
# FighterMcHurtCtrl.as:308-320,449-537,543-650,762-878; GameConfig.as:54-147.
# Pure state transformations. Actor movement, poses and effects are the caller's responsibility.
# Source velocity values are returned unchanged: the Godot adapter must convert source pixels/frame.

const FPS_GAME := 60.0
const FPS_ANIMATE := 30.0
const QI_MAX := 300.0
const ENERGY_MAX := 100.0
const USE_ENERGY_CD := .8
const ENERGY_ADD_NORMAL := 2.0
const ENERGY_ADD_DEFENSE := .8
const ENERGY_ADD_ATTACKING := 1.1
const ENERGY_ADD_OVER_LOAD_PERFRAME := .6
const ENERGY_ADD_OVER_LOAD_RESUME := 30.0
const ENERGY_LOSE_DEFENSE_BREAK_RATE := .9
const QI_ADD_HIT_RATE := .17
const QI_ADD_HIT_BISHA_RATE := 0.0
const QI_ADD_HIT_MAX := 15.0
const QI_ADD_HURT_RATE := .08
const QI_ADD_HURT_MAX := 20.0
const HURT_GAP_FRAME := 4
const HURT_FRAME_OFFSET := 3
const DEFENSE_GAP_FRAME := 4
const DEFENSE_GAP_FRAME_DOWN := 8
const DEFENSE_LOSE_HP_RATE := .05
const DEFENSE_HOLD_FRAME_MIN := 5
const DEFENSE_HOLD_FRAME_MAX := 10
const DEFENSE_HOLD_FRAME_DOWN := 10
const BREAK_DEF_GAP_FRAME := 4
const BREAK_DEF_DOWN_GAP_FRAME := 10
const BREAK_DEF_HOLD_FRAME := 42
const STEEL_HURT_GAP_FRAME := 4
const STEEL_HURT_DOWN_GAP_FRAME := 10
const STEEL_HURT_HP_PERCENT := .65
const STEEL_SUPER_HURT_HP_PERCENT := .3
const HIT_CATCH := 11
const HURT_JUMP_FRAME := 15
const HIT_DOWN_BY_HITY := 5.0
const HIT_DOWN_FRAME := 15
const HIT_DOWN_FRAME_HEAVY := 30

## Open3.4 FighterMcCtrler1477–1501. The real HitVO.owner must be a
## BaseGameSprite; Bullet implements IGameSprite and is deliberately excluded.
## Coordinates/velocity stay in source units; setVec2 is a separate impulse.
static func wall_reverse_push(touch_side: bool,base_owner: bool,target_x: float,owner_x: float,owner_direct: int,hit_x: float) -> Dictionary:
	if not touch_side or not base_owner or absf(target_x-owner_x)>=100.0: return {}
	var target_on_left: bool=target_x<owner_x
	var direction: int=1 if target_on_left else -1
	if (target_on_left and owner_direct==1) or (not target_on_left and owner_direct==-1): direction=0
	return {"velocity":clampf(hit_x*direction*1.4,-20.0,20.0),"damping":.3}

## Resource state uses energy, energy_max, energy_overload, energy_gap (30Hz frames),
## energy_clock (seconds carried to the next animation frame), and action_state.
static func has_energy(energy: float, amount: float, overload: bool=false, allow_overflow: bool=false) -> bool:
	return energy>=amount or (allow_overflow and not overload)

static func use_energy(state: Dictionary, amount: float) -> Dictionary:
	var next: Dictionary=state.duplicate()
	var energy: float=float(next.get("energy",ENERGY_MAX))-amount
	next["energy_gap"]=int(USE_ENERGY_CD*FPS_ANIMATE)
	if energy<0:
		energy=0
		next["energy_overload"]=true
	next["energy"]=energy
	return next

## Exactly one FighterMain.renderEnergy animation frame, including its early return on cooldown.
## Energy is deliberately not clamped here: source adds past energyMax, then caps in renderCheckValue.
static func render_energy(state: Dictionary) -> Dictionary:
	var next: Dictionary=state.duplicate()
	var gap: int=int(next.get("energy_gap",0))
	if gap>0:
		next["energy_gap"]=gap-1
		return next
	var energy: float=float(next.get("energy",ENERGY_MAX))
	if energy>=float(next.get("energy_max",ENERGY_MAX)): return next
	if bool(next.get("energy_overload",false)):
		energy+=ENERGY_ADD_OVER_LOAD_PERFRAME
		if energy>ENERGY_ADD_OVER_LOAD_RESUME: next["energy_overload"]=false
	else:
		var action: String=str(next.get("action_state","idle"))
		if action in ["20","guard"]: energy+=ENERGY_ADD_DEFENSE
		elif action in ["10","11","12","13","attack","skill","super"]: energy+=ENERGY_ADD_ATTACKING
		else: energy+=ENERGY_ADD_NORMAL
	next["energy"]=energy
	return next

## Physics-rate adapter: accumulator prevents 60Hz physics from regenerating twice as fast.
static func tick_energy(state: Dictionary, delta: float) -> Dictionary:
	var next: Dictionary=state.duplicate()
	var clock: float=float(next.get("energy_clock",0))+maxf(0,delta)
	while clock+0.0000001>=1.0/FPS_ANIMATE:
		next=render_energy(next)
		clock-=1.0/FPS_ANIMATE
	next["energy_clock"]=maxf(0,clock)
	next["energy"]=clampf(float(next.get("energy",ENERGY_MAX)),0,float(next.get("energy_max",ENERGY_MAX)))
	return next

static func use_qi(qi: float, amount: float) -> Dictionary:
	return {"allowed":qi>=amount,"qi":qi-amount if qi>=amount else qi}

static func add_qi(qi: float, amount: float, maximum: float=QI_MAX) -> float:
	return minf(qi+amount,maximum)

static func qi_on_hit(power: float, bisha: bool=false, target_is_fighter: bool=true) -> float:
	if not target_is_fighter: return 0.0
	return minf(power*(QI_ADD_HIT_BISHA_RATE if bisha else QI_ADD_HIT_RATE),QI_ADD_HIT_MAX)

static func qi_on_hurt(power: float) -> float:
	return minf(power*QI_ADD_HURT_RATE,QI_ADD_HURT_MAX)

static func damage_of(hit: Dictionary) -> int:
	var power: float=float(hit.get("power",hit.get("damage",0)))
	return int((power+power*float(hit.get("power_add",0))*.01)*float(hit.get("power_rate",1)))

## BaseGameSprite.loseHp:480-500, applied separately for each source deduction.
static func hp_loss(amount: float, target: Dictionary) -> float:
	if not bool(target.get("allow_lose_hp",true)): return 0.0
	return maxf(0,amount*clampf(2.0-float(target.get("defense_rate",1)),.1,1)-float(target.get("defense",0)))

## GameMainLogicCtrl.getHitObj returns only the first intersecting hit, never edge-only contact.
static func first_contact(hits: Array, body: Rect2, allow_be_hit: bool=true) -> Dictionary:
	if not allow_be_hit or body.size.x<=0 or body.size.y<=0: return {}
	for hit in hits:
		if not hit is Dictionary: continue
		var area: Variant=hit.get("area",hit.get("current_area",Rect2()))
		if not area is Rect2: continue
		var contact: Rect2=area.intersection(body)
		if contact.size.x>0 and contact.size.y>0:
			return {"hit":hit.duplicate(true),"rect":contact}
	return {}

## Snapshot BOTH contacts before applying either receive-hit, so simultaneous attacks can trade.
static func pair_contacts(hits_a: Array, body_a: Rect2, hits_b: Array, body_b: Rect2, allow_a: bool=true, allow_b: bool=true) -> Dictionary:
	return {"a_hits_b":first_contact(hits_a,body_b,allow_b),"b_hits_a":first_contact(hits_b,body_a,allow_a)}

static func wrong_defense_direction(defender_x: float, defender_facing: int, owner_x: float, owner_facing: int) -> bool:
	if defender_x<owner_x-5: return defender_facing<0 and owner_facing<0
	if defender_x>owner_x+5: return defender_facing>0 and owner_facing>0
	return false

## Hit: power/power_add/power_rate, hitx/hity, hurt_time_ms, hurt_type (0 hurt / 1 flying),
## hit_type, is_break_def, is_bisha, check_direct, has_owner, owner_x/owner_facing, target_apply_g.
## Target: hp, allow_be_hit, guard, steel, super_steel, in_air, x/facing, resource-state fields.
## Result: resource next-state plus damage/hp, reaction, velocity (SOURCE units), hit_gap_frames,
## stun_frames/time, interrupts, blocked/armor/guard_break, and qi_gain. No arbitrary combo limiter.
static func resolve_hit(target: Dictionary, hit: Dictionary) -> Dictionary:
	if not bool(target.get("allow_be_hit",true)): return {"hit":false}
	var next: Dictionary=target.duplicate()
	var damage: int=damage_of(hit)
	var power: float=float(hit.get("power",hit.get("damage",0)))
	var hurt_type: int=int(hit.get("hurt_type",0))
	var has_owner: bool=bool(hit.get("has_owner",true))
	var facing: int=int(hit.get("owner_facing",1)) if has_owner else 1
	var hitx: float=float(hit.get("hitx",0))
	var hity: float=float(hit.get("hity",0))
	var break_def: bool=bool(hit.get("is_break_def",false))
	var catch_hit: bool=int(hit.get("hit_type",1))==HIT_CATCH and break_def
	var bisha: bool=bool(hit.get("is_bisha",false))
	var steel: bool=bool(target.get("steel",false))
	var super_steel: bool=bool(target.get("super_steel",false))
	var hurt_ms: float=float(hit.get("hurt_time_ms",300))
	var hp_damage: float=hp_loss(damage,target)
	var result := {"hit":true,"blocked":false,"armor":false,"guard_break":false,"interrupts":true,"reaction":"fly" if hurt_type==1 else "hurt","velocity":Vector2(hitx*facing,hity),"damping":Vector2(0 if hurt_type==1 else .1,.5),"hit_gap_frames":HURT_GAP_FRAME,"stun_frames":maxi(HURT_GAP_FRAME,roundi(hurt_ms*.001*FPS_ANIMATE)+HURT_FRAME_OFFSET),"qi_gain":qi_on_hurt(power),"apply_gravity":hurt_type==1 or bool(hit.get("target_apply_g",true)),"raw_damage":damage}
	if not str(target.get("hurt_action","")).is_empty():
		result.merge({"reaction":"hurt_action","hurt_action":target["hurt_action"],"damage":0.0,"interrupts":false},true)
		result["next"]=next
		return result
	var bypass_steel: bool=not super_steel and (bool(target.get("energy_overload",false)) or bisha or catch_hit)
	if steel and not bypass_steel:
		hp_damage=hp_loss(damage*(STEEL_SUPER_HURT_HP_PERCENT if super_steel else STEEL_HURT_HP_PERCENT),target)
		if float(target.get("hp",1000))>hp_damage:
			result["armor"]=true; result["interrupts"]=false; result["reaction"]="armor"
			result["hit_gap_frames"]=STEEL_HURT_DOWN_GAP_FRAME if hurt_type==1 else STEEL_HURT_GAP_FRAME
			var cost: float=damage*(.2 if super_steel else (1.0 if break_def else .4))
			next=use_energy(next,cost)
			var multiplier: float=2.0 if break_def else 1.0
			result["velocity"]=Vector2.ZERO if super_steel else Vector2(hitx*facing,hity)*multiplier
			result["damping"]=Vector2.ZERO if super_steel else Vector2(absf(hitx*.1),absf(hity*.1))
			result["stun_frames"]=0
		else:
			# Source lethal steel applies its reduction, then calls normal doHurt as well.
			hp_damage+=hp_loss(damage,target)
	else:
		var wrong_direction: bool=bool(hit.get("check_direct",true)) and has_owner and wrong_defense_direction(float(target.get("x",0)),int(target.get("facing",1)),float(hit.get("owner_x",0)),facing)
		# Open3.4 FighterMcCtrler.as:1512-1531: isReal bypasses defense only.
		if not steel and bool(target.get("guard",false)) and not catch_hit and not bool(hit.get("is_real",false)) and not wrong_direction:
			hp_damage=hp_loss(damage*DEFENSE_LOSE_HP_RATE,target)
			if float(target.get("hp",1000))<=hp_damage:
				hp_damage+=hp_loss(damage,target)
			else:
				var cost: int=int(float(target.get("energy_max",ENERGY_MAX))*ENERGY_LOSE_DEFENSE_BREAK_RATE) if break_def else mini(int(damage*.2),50)
				var enough: bool=has_energy(float(target.get("energy",ENERGY_MAX)),cost,bool(target.get("energy_overload",false)))
				next=use_energy(next,cost)
				if enough:
					result["blocked"]=true; result["reaction"]="guard"
					result["hit_gap_frames"]=DEFENSE_GAP_FRAME_DOWN if hurt_type==1 else DEFENSE_GAP_FRAME
					result["stun_frames"]=DEFENSE_HOLD_FRAME_DOWN if hurt_type==1 else clampi(int(hurt_ms*.001*FPS_GAME*.2),DEFENSE_HOLD_FRAME_MIN,DEFENSE_HOLD_FRAME_MAX)
					result["velocity"]=Vector2(hitx*facing,0)
					result["damping"]=Vector2(1,0)
				else:
					hp_damage+=hp_loss(damage*.1,target)
					result["guard_break"]=true; result["reaction"]="guard_break"
					result["hit_gap_frames"]=BREAK_DEF_DOWN_GAP_FRAME if hurt_type==1 else BREAK_DEF_GAP_FRAME
					result["stun_frames"]=BREAK_DEF_HOLD_FRAME
					result["velocity"]=Vector2(clampf(hitx,5,10)*facing,0)
					result["damping"]=Vector2(.1,0)
					next["energy_overload"]=false
	if result["reaction"] in ["hurt","fly"]:
		if bool(target.get("in_air",false)) and hity<=0: hity-=3
		elif not bool(target.get("in_air",false)) and hity<0: hity-=6
		result["velocity"]=Vector2(hitx*facing,hity)
		if bool(hit.get("weak_hit",false)) and float(target.get("hp",1000))>hp_damage:
			result["interrupts"]=false
			result["reaction"]="weak"
			result["velocity"]=target.get("velocity",Vector2.ZERO)
			result["stun_frames"]=0
		if hurt_type==1: result["stun_frames"]=0
	next["hp"]=maxf(0,float(target.get("hp",1000))-hp_damage)
	next["allow_be_hit"]=false
	result["alive"]=float(next["hp"])>0
	# FighterMcHurtCtrl:562 only applies targetApplyG to alive ordinary hurt.
	if not result["alive"]: result["apply_gravity"]=true
	result["damage"]=hp_damage
	result["next"]=next
	result["gap_time"]=float(result["hit_gap_frames"])/FPS_ANIMATE
	# HurtHold uses post-decrement <=0; the counter needs N+1 animation ticks to resume.
	result["stun_time"]=(float(result["stun_frames"])+1.0)/FPS_ANIMATE if int(result["stun_frames"])>0 else 0.0
	return result

static func tick_hit_gap(frames: int) -> Dictionary:
	var next: int=maxi(0,frames-1)
	return {"frames":next,"allow_be_hit":next==0}

## FighterMC.playHurtFly:335-366, renderHurtFly:551-651.
## y and velocity stay in source units, and step is called at 30Hz after movement/floor detection.
## The caller consumes event / set_velocity_y / set_damping_x, then stores next.
static func start_hurt_fly(velocity: Vector2, in_air: bool, y: float) -> Dictionary:
	var heavy: bool=velocity.y>HIT_DOWN_BY_HITY
	return {"phase":1,"phase_frames":0,"fly_frames":0 if heavy or in_air else HURT_JUMP_FRAME,"down_frames":0,"heavy":heavy,"min_y":y,"hity":velocity.y}

static func step_hurt_fly(state: Dictionary, in_air: bool, y: float, alive: bool=true) -> Dictionary:
	var next: Dictionary=state.duplicate()
	var output := {"next":next,"event":""}
	var phase: int=int(next.get("phase",0))
	if phase==1:
		next["fly_frames"]=int(next.get("fly_frames",0))-1
		next["min_y"]=minf(float(next.get("min_y",y)),y)
		if int(next["fly_frames"])<=0 and not in_air:
			next["phase"]=2; next["phase_frames"]=1; output["event"]="fall"
	elif phase in [2,3]:
		var age: int=int(next.get("phase_frames",0))
		next["phase_frames"]=age+1
		if age<2: return output
		if phase==2:
			var height: float=y-float(next.get("min_y",y))
			if bool(next.get("heavy",false)):
				next["phase"]=4; next["down_frames"]=HIT_DOWN_FRAME_HEAVY
				output["event"]="heavy_floor"
				output["set_damping_x"]=4.0
				output["floor_strength"]=clampf(height*.04*(1.0+float(next.get("hity",0))*.1),2,5)
			else:
				var bounce: float=clampf(height*.04,3,8)
				next["phase"]=3; next["phase_frames"]=1
				output["event"]="bounce"
				output["set_velocity_y"]=-bounce
				output["floor_strength"]=clampf(bounce,.5,3)
		elif not in_air:
			next["phase"]=4; next["down_frames"]=HIT_DOWN_FRAME
			output["event"]="normal_floor"; output["set_damping_x"]=2.0
			output["floor_strength"]=1.0
	elif phase==4:
		if not alive:
			next["phase"]=0; output["event"]="dead"
		else:
			next["down_frames"]=int(next.get("down_frames",0))-1
			if int(next["down_frames"])<=0:
				next["phase"]=0; output["event"]="resume"
	return output

## FighterMcHurtCtrl.doHurtDownJump:903-928; action availability/window is supplied by caller.
static func hurt_down_jump_allowed(energy: float, current_hurt_damage: float, already_doing: bool=false) -> bool:
	return not already_doing and current_hurt_damage<=240 and has_energy(energy,30)

## FighterMcHurtCtrl.renderHurtBreak:672-701. Qi100, energy gate50 but SPEND100.
## Last bisha and any isBreakDef hit in the current hurt chain both prohibit the counter.
static func hurt_break_allowed(energy: float, qi: float, current_hurt_damage: float, last_bisha: bool=false, hurt_break_hit: bool=false) -> bool:
	return has_energy(energy,50) and qi>=100 and current_hurt_damage<=210 and not last_bisha and not hurt_break_hit
