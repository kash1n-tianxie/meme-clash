extends RefCounted
## SPDX-License-Identifier: GPL-3.0-or-later
## Godot adaptation of pinned OpenBleachVsNaruto FighterAttacker/Bullet.
## Logic objects retain their own source clock, source areas and controller.
const Timeline = preload("res://game/bvn_playable_timeline.gd")
const Events = preload("res://game/bvn_playable_events.gd")
signal source_event_requested(event: Dictionary)
var world: Variant
var owner: Variant
var fighter_id := ""
## Frozen donor namespace: owner may idle, react or cast another donor meanwhile.
var source_profile_id := ""
var source_binding_id := ""
var source_entry_command := ""
var source_entry_label := ""
var last_contact: Dictionary = {}
var owner_index := 0
var facing := 1
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var damping := Vector2.ZERO
## FighterAttacker is BaseGameSprite; Bullet never receives this secondary channel.
var bvn_reverse_velocity: float = 0.0
var bvn_reverse_damping: float = 0.0
var gravity := 4.0
var apply_g := true
var in_air := false
var removed := false
var playing := true
var attacking := false
var kind := "attacker"
var name := ""
var art_clip := "skill1"
var child: Dictionary = {}
var registration: Dictionary = {}
var linear := Transform2D.IDENTITY
var source_generation := 0
var source_label := ""
var source_frame := 0
var source_absolute_frame := 0
var action_serial := 0
## Practice-only provenance is captured at spawn. The source object may keep
## hitting after its owner starts another move; combat's existing move is intact.
var source_origin_action := ""
var source_origin_label := ""
var source_origin_serial := 0
var teaching_origin: Dictionary = {}
var source_condition_resolver: Callable
var unsupported: Array[Dictionary] = []
var sample: Dictionary = {}
var offset := Vector2.ZERO
var follow_x := false
var follow_y := false
var hit_target: Dictionary = {}
var touch_floor := ""
var floor_touched := false
var bullet_area := Rect2()
var bullet_vo: Dictionary = {}
var bullet_hit := false
var hit_able := true
var timeout := false
var hold_ticks := -1.0
var hits_left := -1
var hp := 100.0
var hp_max := 100.0
var acceleration := Vector2.ZERO
var max_speed := Vector2(999,999)
var min_speed := Vector2(-999,-999)
var hit_speed := Vector2(NAN,NAN)
var clock := 0.0

func source_note_unsupported(event: Dictionary, reason: String) -> void:
	unsupported.append({"reason":reason,"frame":source_frame,"event":event.duplicate(true)})
	world.note_unsupported(owner,event,reason)

func initialize(host: Variant, fighter: Variant, instance: Dictionary, definition: Dictionary, params: Dictionary, object_kind: String) -> void:
	world=host; owner=fighter; owner_index=fighter.player_index; fighter_id=fighter.fighter_id
	source_profile_id=fighter.source_active_profile_id(); source_binding_id=fighter.source_binding_id
	source_entry_command=fighter.source_entry_command; source_entry_label=fighter.source_entry_label
	facing=fighter.facing; action_serial=fighter.action_serial
	source_origin_action=fighter.action; source_origin_label=fighter.source_label; source_origin_serial=action_serial
	teaching_origin={"type":object_kind,"action":source_origin_action,"label":source_origin_label,"serial":source_origin_serial,"owner_index":owner_index,"source_frame":fighter.source_absolute_frame,"donor_profile_id":source_profile_id,"binding_id":source_binding_id}
	registration=instance.duplicate(true); child=definition.duplicate(true)
	name=str(instance.get("instance_name","")); kind=object_kind
	art_clip=fighter.action
	var m: Dictionary=instance.get("instance_matrix",{})
	linear=Transform2D(Vector2(float(m.get("a",1)),float(m.get("b",0))),Vector2(float(m.get("c",0)),float(m.get("d",1))),Vector2.ZERO)
	# FighterAttacker.findHitArea gets bounds INSIDE _mainMc, then translates
	# only in getCurrentRect. Bullet.setHitVO registers owner-space bounds.
	linear=Transform2D.IDENTITY
	var root: Dictionary=Timeline.profile(source_profile_id).get("actor_registration",{}).get("root_matrix",{})
	var anchor: Vector2=fighter.source_active_foot_anchor()
	offset=Vector2(float(m.get("tx",0))+float(root.get("tx",0)),float(m.get("ty",0))+float(root.get("ty",0)))-anchor
	apply_g=bool(params.get("applyG",true))
	for axis in ["x","y"]:
		var value: Variant=params.get(axis,null)
		var n: int=0 if axis=="x" else 1
		if kind=="bullet":
			var speed: float=5.0 if n==0 else 0.0
			if value is Dictionary:
				speed=float(value.get("start",speed)); acceleration[n]=float(value.get("add",0))*2
				max_speed[n]=float(value.get("max",999)); min_speed[n]=float(value.get("min",-999))
				if value.has("hit"): hit_speed[n]=float(value["hit"])
			elif value is int or value is float: speed=float(value)
			velocity[n]=speed
		elif value is Dictionary:
			offset[n]=float(value.get("offset",0))
			if n==0: follow_x=bool(value.get("followTarget",false))
			else: follow_y=bool(value.get("followTarget",false))
		elif value is int or value is float: offset[n]+=float(value)
	position=fighter.position+Vector2(offset.x*facing,offset.y)*1.6
	var target: Variant=world.target_for(fighter)
	if kind=="attacker" and target!=null:
		for axis in ["x","y"]:
			var value: Variant=params.get(axis,null)
			var n: int=0 if axis=="x" else 1
			if value is Dictionary and bool(value.get("moveToTarget",false)):
				position[n]=target.position[n]+offset[n]*1.6*(facing if n==0 else 1)
				attacking=true
				var limits: Variant=value.get("range",null)
				if limits is Array and limits.size()==2:
					var dis: float=(position[n]-fighter.position[n])/1.6*(facing if n==0 else 1)
					position[n]=fighter.position[n]+clampf(dis,float(limits[0]),float(limits[1]))*1.6*(facing if n==0 else 1)
	if kind=="bullet":
		velocity.x*=facing; acceleration.x*=facing
		if not is_nan(hit_speed.x): hit_speed.x*=facing
		if params.has("hold"): hold_ticks=float(params["hold"])*60.0 if float(params["hold"])!=-1 else -1
		hits_left=int(params.get("hits",-1)); hp=float(params.get("hp",100)); hp_max=hp
		bullet_area=world.rect_from(instance.get("bullet_registered_bounds",[]))
		bullet_vo=Timeline.hit_vo(source_profile_id,name.trim_suffix("atm"))
		bullet_vo=bullet_vo.get("effective",bullet_vo).duplicate(true)
		bullet_vo["id"]=name.trim_suffix("atm")
	source_condition_resolver=world.resolve_object_expression
	source_event_requested.connect(world.dispatch_object_event)
	refresh_sample(true)

func transformed_rect(rect: Rect2) -> Rect2:
	var corners: Array[Vector2]=[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	var result:=Rect2()
	for i in range(4):
		var point: Vector2=linear*corners[i]
		point=Vector2(point.x*facing,point.y)*1.6+position
		if i==0: result=Rect2(point,Vector2.ZERO)
		else: result=result.expand(point)
	return result

func refresh_sample(execute: bool) -> void:
	sample=Timeline.sample_attacker(source_profile_id,str(child.get("source_symbol",name)),source_frame)
	source_absolute_frame=source_frame
	if execute:
		var generation: int=source_generation
		for event: Dictionary in sample.get("events",[]):
			Events.execute_event(self,event)
			if removed or generation!=source_generation: break

func branch(label: String, play: bool=true) -> bool:
	var labels: Dictionary=child.get("labels",{})
	if not labels.has(label): return false
	source_frame=int(labels[label].get("frame",0)); source_generation+=1
	source_label=label; playing=play; refresh_sample(true)
	return true

func set_bvn_reverse_push(source_velocity: float,source_damping: float) -> void:
	if kind!="attacker" or removed: return
	bvn_reverse_velocity=source_velocity; bvn_reverse_damping=source_damping

func advance(delta: float, animate: bool) -> void:
	if removed: return
	var ticks: float=delta*60.0
	var floor_y: float=Vector2(0,world.battle.stage_map.player_bottom).y
	if kind=="bullet":
		if not bullet_hit:
			position+=velocity*.5*1.6*ticks
			velocity+=acceleration*.5*ticks
			velocity.x=clampf(velocity.x,min_speed.x,max_speed.x) if facing>0 else clampf(velocity.x,-max_speed.x,-min_speed.x)
			velocity.y=clampf(velocity.y,min_speed.y,max_speed.y)
			if hold_ticks!=-1 and not timeout:
				hold_ticks-=ticks
				if hold_ticks<=0:
					timeout=true
					if not branch("timeout",true): removed=true; return
			if position.y>floor_y:
				contact({})
			elif position.x<world.battle.stage_map.left-20*1.6 or position.x>world.battle.stage_map.right+20*1.6 or position.y>world.battle.stage_map.bottom+20*1.6:
				removed=true
	else:
		# GameLogic.isInAir precedes gravity/velocity, irrespective of applyG.
		in_air=velocity.y<0 or position.y<=floor_y-12*1.6
		if not in_air:
			position.y=floor_y; gravity=4
		elif not apply_g or velocity.y<0:
			gravity=0
		else:
			gravity=minf(12,gravity+.6*ticks)
			# BaseGameSprite.applayG moves directly; it never changes getVecY.
			position.y+=gravity*.5*1.6*ticks
		position+=velocity*.5*1.6*ticks
		position.x+=bvn_reverse_velocity*.5*1.6*ticks
		bvn_reverse_velocity=move_toward(bvn_reverse_velocity,0,bvn_reverse_damping*3.0*ticks)
		for n in range(2): velocity[n]=move_toward(velocity[n],0,damping[n]*ticks)
		if not hit_target.is_empty(): world.check_object_target(self)
		if in_air:
			floor_touched=false
		elif not floor_touched:
			floor_touched=true
			if not touch_floor.is_empty():
				var label: String=touch_floor; touch_floor=""; branch(label)
		var target: Variant=world.target_for(owner)
		if target!=null:
			if follow_x: position.x=target.position.x+offset.x*facing*1.6
			if follow_y: position.y=target.position.y+offset.y*1.6
	if not animate or not playing or removed: return
	source_frame=mini(source_frame+1,int(child.get("frame_count",1))-1)
	if kind=="bullet":
		var labels: Dictionary=child.get("labels",{})
		var current_label: String=""
		var label_frame: int=-1
		for key: String in labels:
			var start: int=int(labels[key].get("frame",0))
			if start<=source_frame and start>label_frame: current_label=key; label_frame=start
		if current_label=="loop":
			source_frame=int(labels.get("loop_start",{"frame":0})["frame"])
		elif current_label=="remove": removed=true
		elif current_label=="hit_over": hit_able=false
		elif source_frame==int(child.get("frame_count",1))-2: removed=true
		if removed: return
	refresh_sample(true)
	# Flash advances/executes/finds the penultimate frame before removeSelf.
	if kind=="attacker" and source_frame==int(child.get("frame_count",1))-2: removed=true

func hits() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if removed: return result
	if kind=="bullet":
		if hit_able and not bullet_vo.is_empty() and bullet_area.has_area():
			result.append(world.make_hit(owner,bullet_vo,transformed_rect(bullet_area),"bullet",action_serial,teaching_origin,self))
		return result
	for area: Dictionary in sample.get("hits",[]):
		var exact: Dictionary=area.get("hit_vo",{})
		exact=exact.get("effective",exact).duplicate(true)
		exact["id"]=str(area.get("hit_id",""))
		result.append(world.make_hit(owner,exact,transformed_rect(world.rect_from(area.get("source_rect",[]))),"attacker",action_serial,teaching_origin,self))
	return result

func source_visual_state() -> Dictionary:
	var regions: Array[Dictionary]=[]
	var hit_regions: Array[Rect2]=[]
	var bounds:=Rect2()
	for area: Dictionary in sample.get("areas",[]):
		var region: Dictionary=area.duplicate(true)
		region["area"]=transformed_rect(world.rect_from(area.get("source_rect",[])))
		regions.append(region)
		if str(area.get("kind",""))=="hit": hit_regions.append(region["area"])
		if region["area"].has_area(): bounds=region["area"] if not bounds.has_area() else bounds.merge(region["area"])
	if kind=="bullet":
		bounds=transformed_rect(bullet_area)
		if hit_able and not removed: hit_regions=[bounds]
	return {"ready":true,"fighter_id":fighter_id,"base_profile_id":owner.source_move_context().get("base_profile_id",fighter_id),"donor_profile_id":source_profile_id,"source_profile_id":source_profile_id,"binding_id":source_binding_id,"command":source_entry_command,"entry_label":source_entry_label,"source_symbol":str(child.get("source_symbol",name)),"current_label":source_label,"source_label":source_label,"source_frame":source_frame,"source_absolute_frame":source_absolute_frame,"source_frame_count":int(child.get("frame_count",1)),"source_playing":playing,"source_object_instance_id":get_instance_id(),"action_serial":action_serial,"name":name,"kind":kind,"position":position,"facing":facing,"removed":removed,"hit_able":hit_able,"bullet_hit":bullet_hit,"contact":last_contact.duplicate(true),"regions":regions,"hit_regions":hit_regions,"actual_bounds":bounds,"body_region":bounds,"touch_floor":floor_touched,"source_origin_action":source_origin_action,"source_origin_label":source_origin_label}

func source_notify_contact(hit: Dictionary,result: Dictionary,target_index: int=-1) -> void:
	last_contact={"result":result.duplicate(true),"target_index":target_index,"hit_id":str(hit.get("source_name","")),"source_frame":source_frame}

func contact(target_result: Dictionary) -> void:
	if not target_result.is_empty(): source_notify_contact({"source_name":str(bullet_vo.get("id",""))},target_result)
	if kind!="bullet": return
	if hits_left!=-1:
		hits_left-=1
		if hits_left<=0:
			bullet_hit=true; hit_able=false
			if not branch("hit",true): removed=true
	if not target_result.is_empty():
		for n in range(2):
			if not is_nan(hit_speed[n]): velocity[n]=hit_speed[n]

func be_hit(source: Dictionary, other: Variant=null) -> void:
	if kind!="bullet" or bullet_hit: return
	hp-=float(other.hp_max) if other!=null and other.kind=="bullet" else float(source.get("source_hit_vo",{}).get("power",source.get("damage",0)))
	if hp<=0:
		bullet_hit=true; hit_able=false
		if not branch("hit",true): removed=true

func hit_bullet() -> void:
	for n in range(2):
		if not is_nan(hit_speed[n]): velocity[n]=hit_speed[n]
