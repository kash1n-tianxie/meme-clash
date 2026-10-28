extends RefCounted
## SPDX-License-Identifier: GPL-3.0-or-later
## Target-dependent controller port from OpenBleachVsNaruto@4d7bc991.
## Source IR is interpreted by whitelist; it is never evaluated as code.
const Timeline = preload("res://game/bvn_playable_timeline.gd")
const SourceObject = preload("res://game/bvn_playable_object.gd")
var battle: Variant
var objects: Array = []
var unsupported: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var attractions: Dictionary = {}
var source_clock := 0.0
var animation_tick := false
var modifiers: Dictionary = {}
var bisha_owner := -1
var slow_time := 0.0
var speed_rate := 1.0

func initialize(host: Variant) -> void:
	battle=host
	for actor in battle.fighters:
		actor.source_condition_resolver=resolve_expression
		actor.source_process_frame_callback=process_actor_frame
		actor.source_event_requested.connect(actor_event.bind(actor))

func reset() -> void:
	objects.clear(); attractions.clear(); unsupported.clear(); trace.clear(); modifiers.clear(); source_clock=0; animation_tick=false
	bisha_owner=-1; slow_time=0; speed_rate=1
	for actor in battle.fighters: actor.visible=true

func target_for(actor: Variant) -> Variant:
	if battle.fighters.size()!=2: return null
	return battle.fighters[1-int(actor.player_index)]

func note_unsupported(actor: Variant, event: Dictionary, reason: String) -> void:
	if unsupported.size()<200:
		unsupported.append({"fighter":actor.fighter_id,"label":actor.source_label,"frame":actor.source_frame,"reason":reason,"event":event.duplicate(true)})

static func rect_from(value: Variant) -> Rect2:
	if value is Rect2: return value
	if value is Array and value.size()==4: return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))
	return Rect2()

static func arg(args: Array, index: int, fallback: Variant=null) -> Variant:
	return args[index] if index<args.size() else fallback

func just_hit(actor: Variant, hit_id: String, include_defense: bool=false) -> bool:
	var target: Variant=target_for(actor)
	if target==null: return false
	var current: Dictionary=target.last_source_hurt_hit
	if not current.is_empty(): return str(current.get("id",""))==hit_id and (not actor.source_bindings_enabled or str(current.get("source_profile_id",actor.source_active_profile_id()))==actor.source_active_profile_id())
	var defended: Dictionary=target.last_source_defense_hit
	return include_defense and str(defended.get("id",""))==hit_id and (not actor.source_bindings_enabled or str(defended.get("source_profile_id",actor.source_active_profile_id()))==actor.source_active_profile_id())

func resolve_expression(value: Variant, actor: Variant) -> Variant:
	if value is Array:
		var result: Array=[]
		for item in value: result.append(resolve_expression(item,actor))
		return result
	if not value is Dictionary: return value
	match str(value.get("kind","")):
		"literal": return value.get("value",null)
		"expression": return resolve_expression(value.get("expression",{}),actor)
		"reference":
			var name: String=str(value.get("name",""))
			if name.ends_with(".target"): return target_for(actor)!=null
			if name.ends_with(".hp"): return actor.hp
			if name.ends_with(".direct"): return actor.facing
			if name=="true": return true
			if name=="false": return false
			if name=="null": return null
		"unary":
			var operand: Variant=resolve_expression(value.get("operand",{}),actor)
			if operand==null: return null
			match str(value.get("operator","")):
				"!": return not bool(operand)
				"-": return -float(operand)
				"+": return float(operand)
		"binary":
			var left: Variant=resolve_expression(value.get("left",{}),actor)
			var right: Variant=resolve_expression(value.get("right",{}),actor)
			if left==null or right==null: return null
			match str(value.get("operator","")):
				">": return left>right
				"<": return left<right
				">=": return left>=right
				"<=": return left<=right
				"==","===": return left==right
				"!=","!==": return left!=right
				"&&": return bool(left) and bool(right)
				"||": return bool(left) or bool(right)
				"+": return left+right
				"-": return left-right
		"call":
			var callee: Variant=value.get("callee",{})
			var name: String=str(callee.get("name","")) if callee is Dictionary else str(callee)
			var args: Array=resolve_expression(value.get("arguments",[]),actor)
			if name.ends_with(".justHit"): return just_hit(actor,str(arg(args,0,"")),bool(arg(args,1,false)))
			if name.ends_with(".targetInRange"): return target_in_range(actor,arg(args,0),arg(args,1))
	return null

func target_in_range(actor: Variant, rx: Variant, ry: Variant=null) -> bool:
	var target: Variant=target_for(actor)
	if target==null: return false
	var gap: Vector2=(target.position-actor.position)/1.6
	gap.x*=actor.facing
	return (not rx is Array or (gap.x>=float(rx[0]) and gap.x<=float(rx[1]))) and (not ry is Array or (gap.y>=float(ry[0]) and gap.y<=float(ry[1])))

func instance_at(actor: Variant, name: String) -> Dictionary:
	return Timeline.instance_at(actor.source_active_profile_id(),name,actor.source_absolute_frame)

func actor_event(event: Dictionary, actor: Variant) -> void:
	var method: String=str(event.get("method",""))
	var controller: String=str(event.get("controller",""))
	var args: Array=event.get("arguments",[])
	if trace.size()<3000: trace.append({"fighter":actor.fighter_id,"profile_id":actor.source_active_profile_id(),"binding_id":actor.source_binding_id,"label":actor.source_label,"frame":actor.source_frame,"controller":controller,"method":method,"arguments":args.duplicate(true)})
	if controller in ["effect","$effect_ctrler"]:
		effect_event(actor,method,args)
		return
	match method:
		"addAttacker","fire": spawn(actor,str(arg(args,0,"")),arg(args,1,{}) if arg(args,1,{}) is Dictionary else {},"bullet" if method=="fire" else "attacker")
		"justHitToPlay":
			if just_hit(actor,str(arg(args,0,"")),bool(arg(args,3,false))): actor.source_branch(str(arg(args,1,"")))
			elif bool(arg(args,2,false)): actor.source_idle()
		"moveToTarget":
			var target: Variant=target_for(actor)
			if target==null: return
			if arg(args,0)!=null:
				var x: float=float(args[0])*1.6
				actor.position.x=target.position.x+x*actor.facing
				if x>0:
					if target.position.x<x: actor.position.x=target.position.x+x
					elif target.position.x>battle.stage_map.right-x: actor.position.x=target.position.x-x
			if arg(args,1)!=null: actor.position.y=target.position.y+float(args[1])*1.6
			if bool(arg(args,2,true)): actor.facing=1 if actor.position.x<target.position.x else -1
		"setDirectToTarget":
			var target: Variant=target_for(actor)
			if target!=null: actor.facing=1 if actor.position.x<target.position.x else -1
		"moveTarget":
			if arg(args,0)==null:
				attractions.erase(actor.player_index)
				var target: Variant=target_for(actor)
				if target!=null: target.bvn_apply_gravity=true
			else: attractions[actor.player_index]=arg(args,0,{}).duplicate(true)
		"assign":
			var target: Variant=target_for(actor)
			if target!=null and str(arg(args,0,"")).ends_with("target.visible"): target.visible=bool(arg(args,1,true))
		"loseHp": actor.hp=maxi(0,actor.hp-int(float(arg(args,0,0))))
		"hurtFly":
			actor.source_hurt_fly(float(arg(args,0,0)),float(arg(args,1,0)))
		"addHpLosePercent": modifiers[actor.player_index]={"hp_lose_percent":float(arg(args,0,0))}
		"doWanKai": note_unsupported(actor,event,"source transformation roster not available for these five meme bodies")
		_: note_unsupported(actor,event,"unimplemented external controller method")

func process_actor_frame(actor: Variant, sample: Dictionary) -> void:
	if not actor.source_hit_target.is_empty():
		var checker: String=str(actor.source_hit_target.get("checker",""))
		var target: Variant=target_for(actor)
		for area: Dictionary in sample.get("areas",[]):
			if area.get("instance_name","")==checker and target!=null and actor._source_world_rect(rect_from(area.get("source_rect",[]))).intersects(target.body_box()):
				actor.source_branch(str(actor.source_hit_target.get("label","")),"",true)
				return

func spawn(actor: Variant, name: String, params: Dictionary, kind: String) -> void:
	var registration: Dictionary=instance_at(actor,name)
	var definition: Dictionary=Timeline.attacker_definition(actor.source_active_profile_id(),str(registration.get("library",name)))
	if registration.is_empty() or definition.is_empty():
		note_unsupported(actor,{"name":name,"params":params},"missing actual independent object instance")
		return
	if kind=="bullet" and not rect_from(registration.get("bullet_registered_bounds",[])).has_area():
		note_unsupported(actor,{"name":name},"missing source bullet first-frame bounds")
		return
	var object=SourceObject.new()
	objects.append(object)
	object.initialize(self,actor,registration,definition,params,kind)

func object_event(object: Variant, event: Dictionary) -> void:
	var method: String=str(event.get("method","")); var args: Array=event.get("arguments",[])
	if str(event.get("controller","")).contains("effect"):
		# A spawned object's immutable birth binding owns its sound. The owner
		# may have already returned to J/neutral or entered another technique.
		if method in ["playSoundHit1","playSoundHit2"]:
			if battle and battle.has_method("_source_skill_audio_manages_binding") and battle._source_skill_audio_manages_binding(str(object.source_binding_id)): return
			if battle: battle._sfx("swing" if method=="playSoundHit1" else "heavy")
			return
		effect_event(object.owner,method,args); return
	match method:
		"move": object.velocity=Vector2(float(arg(args,0,0))*object.facing,float(arg(args,1,0)))
		"damping": object.damping=Vector2(float(arg(args,0,0)),float(arg(args,1,0)))
		"stopMove": object.velocity=Vector2.ZERO
		"endAct": object.attacking=false
		"stop": object.playing=false
		"gotoAndPlay","gotoAndStop": object.branch(str(arg(args,0,"")),method=="gotoAndPlay")
		"setTouchFloor": object.touch_floor=str(arg(args,0,""))
		"setHitTarget": object.hit_target={"checker":str(arg(args,0,"")),"label":str(arg(args,1,""))}
		"stopFollowTarget": object.follow_x=false; object.follow_y=false
		"removeSelf": object.removed=true
		"crossMap": pass # Separate attackers already pass horizontal bounds.
		_: object.source_note_unsupported(event,"unimplemented independent object method")

func dispatch_object_event(event: Dictionary) -> void:
	var object: Variant=instance_from_id(int(event.get("source_object_instance_id",0)))
	if object!=null: object_event(object,event)

func resolve_object_expression(expression: Variant, object: Variant) -> Variant:
	return resolve_expression(expression,object.owner)

func check_object_target(object: Variant) -> void:
	var target: Variant=target_for(object.owner)
	if target==null: return
	for area: Dictionary in object.sample.get("areas",[]):
		if area.get("instance_name","")==object.hit_target.get("checker","") and object.transformed_rect(rect_from(area.get("source_rect",[]))).intersects(target.body_box()):
			object.branch(str(object.hit_target.get("label","")))
			return

func make_hit(owner: Variant, exact: Dictionary, area: Rect2, source_type: String, serial: int, teaching_origin: Dictionary={}, hit_entity: Variant=null) -> Dictionary:
	var bisha: bool=str(exact.get("id","")).contains("bs")
	# Open3.4 Bullet.setHitVO201–205 / FighterAttacker.findHitArea437–446:
	# cloned HitVO.owner is the independent entity; fighter credit stays owner.
	var entity: Variant=owner if hit_entity==null else hit_entity
	var donor_id: String=entity.source_profile_id if hit_entity!=null else owner.source_active_profile_id()
	var binding_id: String=entity.source_binding_id if hit_entity!=null else owner.source_binding_id
	var source_vo: Dictionary=exact.duplicate(true)
	source_vo["source_profile_id"]=donor_id
	var hit: Dictionary={"area":area,"source_profile_id":donor_id,"source_binding_id":binding_id,"source_object_instance_id":entity.get_instance_id() if hit_entity!=null else 0,"source_hit_vo":source_vo,"source_name":str(exact.get("id","")),"source_type":source_type,"serial":serial,"move":owner.action,"kind":"super" if bisha else "special","damage":int(float(exact.get("power",0))*float(exact.get("powerRate",1))),"knockback":float(exact.get("hitx",0))*48,"stun":float(exact.get("hurtTime",300))*.001,"owner_x":entity.position.x,"owner_facing":entity.facing,"hit_owner_facing":entity.facing,"feedback":"super" if bisha else "heavy","label":owner.display_name}
	if not teaching_origin.is_empty(): hit["teaching_origin"]=teaching_origin.duplicate()
	return hit

func advance(delta: float) -> void:
	source_clock+=delta; animation_tick=source_clock+0.0000001>=1.0/30.0
	if animation_tick: source_clock-=1.0/30.0
	for actor in battle.fighters:
		if actor.source_runtime_enabled and not actor.source_hit_target.is_empty(): process_actor_frame(actor,actor.source_snapshot)
	for index in attractions:
		var actor: Variant=battle.fighters[int(index)]
		var target: Variant=target_for(actor)
		var params: Dictionary=attractions[index]
		if target==null: continue
		var aim:=Vector2(float(params.get("x",0)),float(params.get("y",0)))*1.6
		if params.has("followmc"):
			var instance: Dictionary=instance_at(actor,str(params["followmc"]))
			if instance.is_empty(): continue
			var matrix: Dictionary=instance.get("instance_matrix",{})
			aim=actor.position+Vector2(float(matrix.get("tx",0))*actor.facing,float(matrix.get("ty",0)))*1.6
		if params.has("speed"):
			var speed_value: Variant=params["speed"]
			var step: Vector2=Vector2.ONE*float(speed_value)*.5*1.6 if speed_value is int or speed_value is float else Vector2(float(speed_value.get("x",0)),float(speed_value.get("y",0)))*.5*1.6
			if step.x>0:
				if target.position.x>aim.x+step.x: target.position.x-=step.x
				if target.position.x<aim.x-step.x: target.position.x+=step.x
				if target.position.y>aim.y+step.y: target.velocity.y=-step.y*48/1.6; target.bvn_damping.y=1
				if target.position.y<aim.y-step.y: target.velocity.y=step.y*48/1.6; target.bvn_damping.y=1
		else: target.position=aim
	for object in objects: object.advance(delta,animation_tick)
	objects=objects.filter(func(object: Variant) -> bool: return not object.removed)

func effect_event(actor: Variant, method: String, args: Array) -> void:
	var source_audio_handled: bool=battle.has_method("_source_audio_event") and battle._source_audio_event(actor,method,args)
	match method:
		"shine","shake","startShake","endShake","hitFloor":
			if battle.has_method("_source_presentation_event"):battle._source_presentation_event(actor,method,args)
		"playSoundHit1":
			if not battle.has_method("_source_skill_audio_manages") or not battle._source_skill_audio_manages(actor): battle._sfx("swing")
		"playSoundHit2":
			if not battle.has_method("_source_skill_audio_manages") or not battle._source_skill_audio_manages(actor): battle._sfx("heavy")
		"dash": battle._sfx("dash")
		"jump":
			if not source_audio_handled:battle._sfx("land")
		"bisha":
			bisha_owner=actor.player_index
			if battle.has_method("_source_bisha_started"): battle._source_bisha_started(actor,args)
			battle.cinema_owner=actor.player_index
			battle.cinema_name=str(actor.action_data.get("label",battle.SUPER_NAMES.get(actor.fighter_id,"超ミーム")))
			battle.cinema_time=10.0
			if not battle.has_method("_source_skill_audio_manages") or not battle._source_skill_audio_manages(actor): battle._sfx("super")
		"endBisha":
			if bisha_owner==actor.player_index: bisha_owner=-1; battle.cinema_time=0
		"slowDown":
			slow_time=float(arg(args,0,0)); speed_rate=1.5
		"walk","shadow","endShadow","startWanKai": pass
		_: note_unsupported(actor,{"method":method,"arguments":args},"unknown source effect")
