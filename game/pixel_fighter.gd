extends RefCounted
## Painted articulated parts. Each clip uses skeletal keys, not a moving full-body card.
## All coordinates originate at the fighter feet. Draw polygons preserve the caller's draw transform.

static var _rigs: Dictionary = {}
static var _textures: Dictionary = {}
static var _isolated_parts: Dictionary = {}
static var _source_images: Dictionary = {}
static var _effects: Dictionary = {}
static var _draw_observer: Callable = Callable()
## Authored rolling pose rotates the component vertices, preserving any caller transform.
## Reset after each immediate draw; no second body or previous-frame actor is retained.
static var _authored_roll := 0.0
static var _authored_roll_pivot := Vector2(0,-31)
const SkillEffectMotion=preload("res://game/skill_effect_motion.gd")
const EFFECT_ALIASES={"U":"skill1","WU":"skill2","SU":"skill3","I":"super","SI":"super_down","WI":"super_up"}
const IDS = ["rio", "cat", "shark", "worker", "chicken"]
const ALIASES = {"light1":"attack1", "light2":"attack2", "light3":"attack3", "light":"attack1", "heavy":"attack3", "block":"guard", "special1":"skill1", "special2":"skill2", "special3":"skill3", "knockdown":"down", "ko":"down", "crouch":"sweep"}

static func _load_rig(id: String) -> Dictionary:
	if _rigs.has(id): return _rigs[id]
	var path = "res://assets/pixel/%s.rig.json" % id
	if not FileAccess.file_exists(path): return {}
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary: return {}
	_rigs[id] = value
	return value

static func has_assets(id: String) -> bool:
	return not _load_rig(id).is_empty()

## Disabled in production. Native/headless draw-path QA can observe the exact
## polygon submitted to CanvasItem; it never replaces or changes that drawing.
static func set_draw_observer(observer: Callable = Callable()) -> void:
	_draw_observer=observer

## Source labels stay in the actor. This is an explicit art lookup only;
## unknown labels never silently invent a damaging animation.
static func get_source_visual(id: String, source_label: String, source_relative_frame: float = 0.0) -> Dictionary:
	var meta:=_load_rig(id)
	var mapping: Dictionary=meta.get("source_visuals",{}).get(source_label,{})
	if mapping.is_empty():return {"known":false,"id":id,"source_label":source_label,"art_clip":"","progress":0.0}
	var clip: String=mapping["art_clip"]
	if not meta["clips"].has(clip):return {"known":false,"id":id,"source_label":source_label,"art_clip":clip,"progress":0.0}
	var alignment: Dictionary=mapping["source_alignment"]
	var landmarks: Array=alignment.get("pose_landmarks",[])
	var phase:=0.0
	if not landmarks.is_empty():
		phase=float(landmarks[-1][1])
		if source_relative_frame<=float(landmarks[0][0]):phase=float(landmarks[0][1])
		else:
			for i in range(landmarks.size()-1):
				var a: Array=landmarks[i];var b: Array=landmarks[i+1]
				if source_relative_frame<=float(b[0]):
					phase=lerpf(float(a[1]),float(b[1]),clampf((source_relative_frame-float(a[0]))/maxf(.00001,float(b[0])-float(a[0])),0,1))
					break
	return {"known":true,"id":id,"source_label":source_label,"art_clip":clip,"progress":clampf(phase,0,1),"source_alignment":alignment,"effect_clip":mapping.get("effect_clip",clip)}

static func has_clip(id: String, clip: String) -> bool:
	return _load_rig(id).get("clips",{}).has(_clip_name(clip))

## nextFrame can cross visual labels while FighterMC retains its entry label.
## Lookup the currently visible region without changing that source actor entry.
static func get_source_visual_absolute(id: String, entry_label: String, source_absolute_frame: float) -> Dictionary:
	var table: Dictionary=_load_rig(id).get("source_visuals",{})
	if not table.has(entry_label):return {"known":false,"id":id,"source_label":entry_label,"art_clip":"","progress":0.0}
	var selected: String=entry_label
	var index: float=-INF
	for label: String in table:
		var start: float=table[label]["source_alignment"]["source_start_index"]
		if start<=source_absolute_frame and start>index:
			selected=label;index=start
	if index==-INF:return {"known":false,"id":id,"source_label":entry_label,"art_clip":"","progress":0.0}
	if source_absolute_frame>=index+float(table[selected]["source_alignment"]["frame_count"]):return {"known":false,"id":id,"source_label":entry_label,"art_clip":"","progress":0.0}
	var result:=get_source_visual(id,selected,source_absolute_frame-index)
	result["entry_label"]=entry_label
	result["visual_label"]=selected
	result["source_absolute_frame"]=source_absolute_frame
	return result

## Art registration locates the visible strike inside an existing authored clip.
## It does not change the actor's startup, active, recovery or source hit frames.
static func contact_phases(id: String, clip: String) -> Vector2:
	var registration: Dictionary=_load_rig(id).get("contact_registration",{}).get(_clip_name(clip),{})
	return Vector2(float(registration.get("startup_end",.45)),float(registration.get("active_end",.62)))

static func _texture(path: String) -> Texture2D:
	if not _textures.has(path): _textures[path] = load(path)
	return _textures[path]

static func _isolated_texture(meta: Dictionary, group: Dictionary, name: String, texture: Texture2D, rect: Rect2, variant: bool) -> Texture2D:
	var key: String=meta["id"]+"/"+("variants/" if variant else "parts/")+name
	if _isolated_parts.has(key): return _isolated_parts[key]
	# Copy exact original source pixels into a transparent runtime cache. PNG assets are never changed.
	var source_key:=texture.get_instance_id()
	if not _source_images.has(source_key):
		var decoded: Image=texture.get_image()
		if decoded.is_compressed(): decoded.decompress()
		if decoded.get_format()!=Image.FORMAT_RGBA8: decoded.convert(Image.FORMAT_RGBA8)
		_source_images[source_key]=decoded
	var original: Image=_source_images[source_key]
	var isolated=Image.create(roundi(rect.size.x),roundi(rect.size.y),false,Image.FORMAT_RGBA8)
	isolated.fill(Color.TRANSPARENT)
	for piece: Array in group["parts"][name]["source_parts"]:
		var source_rect=Rect2i(int(piece[0]),int(piece[1]),int(piece[2]),int(piece[3]))
		var dest=source_rect.position-Vector2i(rect.position)
		isolated.blit_rect(original,source_rect,dest)
	var ready=ImageTexture.create_from_image(isolated)
	_isolated_parts[key]=ready
	return ready

## Fixed immutable actor/effect resources, loaded before the fight countdown.
## Crops preserve identical original pixels; no action/frame/damage logic is run.
static func prewarm_render_assets(id: String) -> void:
	var meta:=_load_rig(id)
	if meta.is_empty(): return
	for group_name: String in ["parts","variants"]:
		var group: Dictionary=meta[group_name]
		var texture:=_texture(meta["variants_texture" if group_name=="variants" else "parts_texture"])
		if not texture: continue
		for name: String in group["parts"]:
			var definition: Dictionary=group["parts"][name]
			if not definition.has("source_parts"): continue
			var r: Array=definition["rect"]
			_isolated_texture(meta,group,name,texture,Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3])),group_name=="variants")
	var effects:=_load_effects(id)
	if effects.has("texture"): _texture(effects["texture"])

static func _clip_name(clip: String) -> String:
	return ALIASES.get(clip, clip)

static func _sample(meta: Dictionary, clip: String, progress: float) -> Dictionary:
	var name = _clip_name(clip)
	var definition: Dictionary = meta["clips"].get(name, meta["clips"]["idle"])
	var frames: Array = definition["keyframes"]
	var count = frames.size()
	var loop: bool = definition["loop"]
	var phase = fposmod(progress, 1.0) if loop else clampf(progress, 0.0, 1.0)
	var time = phase * (count if loop else count - 1)
	var a = mini(int(time), count - 1)
	var b = (a + 1) % count if loop else mini(a + 1, count - 1)
	var amount = time - float(a)
	var markers: Array=definition.get("keyframe_phases",[])
	if markers.size()==count:
		a=count-1;b=a;amount=0.0
		for i in range(count-1):
			if phase<=float(markers[i+1]):
				a=i;b=i+1
				amount=clampf((phase-float(markers[i]))/maxf(.000001,float(markers[i+1])-float(markers[i])),0,1)
				break
	var result: Dictionary = {}
	for key in frames[a]:
		var value = frames[a][key]
		var other = frames[b].get(key,value)
		if value is Array:
			result[key] = Vector2(float(value[0]),float(value[1])).lerp(Vector2(float(other[0]),float(other[1])),amount)
		elif str(key).ends_with("variant"):
			result[key] = int(value if amount < 0.5 else other)
		else:
			result[key] = lerpf(float(value),float(other),amount)
	result["clip"] = name
	result["keyframe"] = a
	result["phase"] = phase
	result["keyframe_count"] = count
	if meta["id"]=="shark":
		# Shoe attacks remain articulated kicks: rear/middle shoes stay planted during the launcher.
		var contact = maxf(0.0,sin(clampf((phase-.20)/.60,0.0,1.0)*PI)) if not loop else 0.0
		if name in ["launcher","skill2","super_up"]:
			result["front_foot"].y -= contact*18.0
		elif name=="sweep":
			result["front_foot"].x += contact*12.0
		elif name in ["attack1","attack2","attack3"]:
			result["front_foot"].x += contact*10.0
			result["front_foot"].y -= contact*8.0
	return result

static func _vec(data: Array) -> Vector2:
	return Vector2(float(data[0]),float(data[1]))

static func _part(canvas: CanvasItem, meta: Dictionary, name: String, size: Vector2, pivot: Vector2, at: Vector2, angle: float, world_scale: float, facing: int, tint: Color, variant: bool = false) -> void:
	var group: Dictionary = meta["variants" if variant else "parts"]
	if not group["parts"].has(name): return
	var r: Array = group["parts"][name]["rect"]
	var rect = Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3]))
	var texture = _texture(meta["variants_texture" if variant else "parts_texture"])
	if not texture: return
	if group["parts"][name].has("source_parts"):
		texture=_isolated_texture(meta,group,name,texture,rect,variant)
		rect=Rect2(Vector2.ZERO,rect.size)
	var region_parts: Array = [[rect.position.x,rect.position.y,rect.size.x,rect.size.y]]
	var corners = [Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)]
	for source_part: Array in region_parts:
		var piece = Rect2(float(source_part[0]),float(source_part[1]),float(source_part[2]),float(source_part[3]))
		var points = PackedVector2Array()
		var uv = PackedVector2Array()
		for corner in corners:
			var source_pixel: Vector2 = piece.position + corner * piece.size
			var fraction: Vector2 = (source_pixel - rect.position) / rect.size
			var p: Vector2 = (fraction * size - pivot * size).rotated(angle) + at
			if not is_zero_approx(_authored_roll):
				p=(p-_authored_roll_pivot).rotated(_authored_roll)+_authored_roll_pivot
			points.append(Vector2(p.x * facing, p.y) * world_scale)
			if bool(group["parts"][name].get("flip_y",false)):
				source_pixel.y=rect.position.y+rect.size.y-(source_pixel.y-rect.position.y)
			uv.append(source_pixel / texture.get_size())
		if _draw_observer.is_valid():
			_draw_observer.call({"stage":"part","id":meta["id"],"name":name,"canvas":canvas.get_instance_id(),"points":points,"world_scale":world_scale,"facing":facing})
		canvas.draw_polygon(points,PackedColorArray([tint]),uv,texture)

static func _bone(canvas: CanvasItem, meta: Dictionary, name: String, a: Vector2, b: Vector2, width: float, world_scale: float, facing: int, tint: Color) -> void:
	var direction = b - a
	_part(canvas,meta,name,Vector2(width,direction.length()+2),Vector2(0.5,0.07),a,direction.angle()-PI/2,world_scale,facing,tint)

static func _knee(hip: Vector2, ankle: Vector2, upper: float, lower: float, bend: float = 1.0) -> Vector2:
	var delta = ankle - hip
	var dist = clampf(delta.length(),0.1,upper+lower-0.1)
	var forward = delta.normalized()
	var along = (upper*upper-lower*lower+dist*dist)/(2.0*dist)
	var out = sqrt(maxf(0.0,upper*upper-along*along))
	return hip + forward*along + Vector2(forward.y,-forward.x)*out*bend

static func _leg(canvas: CanvasItem, meta: Dictionary, p: Dictionary, suffix: String, hip: Vector2, foot: Vector2, world_scale: float, facing: int, tint: Color) -> void:
	var rig: Dictionary = meta["rig"]
	var foot_size = _vec(rig["foot"])
	var ankle = foot - Vector2(0,foot_size.y-1)
	if bool(rig.get("flowing_skirt",false)):
		# Four broad overlapping cloth panels cover both legs as one long wrap skirt.
		# Each upper/lower chain flexes independently; feet still take real separate steps.
		var root_hip=hip-Vector2(4 if suffix=="front" else -4,0)
		var cloth_root=root_hip+Vector2(1.0 if suffix=="front" else -1.0,0)
		var hem: Vector2=(p["front_foot"]+p["back_foot"])*.25-Vector2(0,foot_size.y-1)
		var movement=1.5 if p["clip"] in ["walk","dance","jump","air_light","air_skill","air_slam"] or bool(meta["clips"].get(p["clip"],{}).get("airborne_visual",false)) else .6
		var cloth_knee=cloth_root.lerp(hem,.50)+Vector2(sin(float(p["phase"])*TAU*2+(.8 if suffix=="front" else -.8))*movement,0)
		hem.x+=sin(float(p["phase"])*TAU*2-1.2)*movement*.6
		_bone(canvas,meta,"thigh_"+suffix,cloth_root,cloth_knee,24,world_scale,facing,tint)
		_bone(canvas,meta,"shin_"+suffix,cloth_knee,hem,28,world_scale,facing,tint)
		_part(canvas,meta,"foot_"+suffix,foot_size,Vector2(.45,1),foot,deg_to_rad(float(p.get("foot_"+suffix+"_angle",0))),world_scale,facing,tint)
		return
	var knee = _knee(hip,ankle,float(rig["thigh"]),float(rig["shin"]))
	var width = float(rig.get("leg_width",8.0 if meta["id"]=="rio" else 7.0))
	_bone(canvas,meta,"thigh_"+suffix,hip,knee,width,world_scale,facing,tint)
	_bone(canvas,meta,"shin_"+suffix,knee,ankle,float(rig.get("shin_width",width-1.5)),world_scale,facing,tint)
	_part(canvas,meta,"foot_"+suffix,foot_size,Vector2(0.45,1),foot,deg_to_rad(float(p.get("foot_"+suffix+"_angle",0))),world_scale,facing,tint)

static func _arm(canvas: CanvasItem, meta: Dictionary, p: Dictionary, suffix: String, shoulder: Vector2, torso_angle: float, world_scale: float, facing: int, tint: Color, draw_parts: bool = true) -> Vector2:
	var rig: Dictionary = meta["rig"]
	var upper_angle = deg_to_rad(float(p[suffix+"_upper"])) + torso_angle*0.35
	var lower_angle = deg_to_rad(float(p[suffix+"_lower"])) + torso_angle*0.35
	# Explicit reach keys belong only to new authored clips. They let the short
	# chicken wings clear its large meme face when lifting the single real ball.
	var reach: float=clampf(float(p.get(suffix+"_reach",1.0)),.75,1.8)
	var elbow = shoulder + Vector2(0,float(rig["upper"])*reach).rotated(upper_angle)
	var wrist = elbow + Vector2(0,float(rig["lower"])*reach).rotated(lower_angle)
	if draw_parts:
		var width = float(rig.get("arm_width",5.0 if meta["id"]=="rio" else 7.0))
		_bone(canvas,meta,"upper_"+suffix,shoulder,elbow,width,world_scale,facing,tint)
		_bone(canvas,meta,"lower_"+suffix,elbow,wrist,width+1,world_scale,facing,tint)
	return wrist

static func _arm_to(canvas: CanvasItem, meta: Dictionary, suffix: String, shoulder: Vector2, wrist: Vector2, world_scale: float, facing: int, tint: Color) -> void:
	var rig: Dictionary=meta["rig"]
	var elbow=_knee(shoulder,wrist,float(rig["upper"]),float(rig["lower"]),-1.0)
	var width=float(rig.get("arm_width",6.0))
	_bone(canvas,meta,"upper_"+suffix,shoulder,elbow,width,world_scale,facing,tint)
	_bone(canvas,meta,"lower_"+suffix,elbow,wrist,width+1,world_scale,facing,tint)

static func _variant_has_arms(meta: Dictionary) -> bool:
	return bool(meta.get("variants_include_arms",meta["id"] in ["cat","worker","chicken"]))

static func _rio_weapon_angle(meta: Dictionary, p: Dictionary, wrist: Vector2) -> float:
	if not bool(meta["rig"].get("heavy_sword",false)): return deg_to_rad(float(p["weapon"])+32)
	var size=_vec(meta["rig"]["weapon"])
	var delta=(_vec(meta["rig"].get("weapon_tip_uv",[.985,.5]))-_vec(meta["rig"].get("weapon_grip_uv",[.12,.5])))*size
	var floor_angle=asin(clampf(-wrist.y/delta.length(),-.95,.95))-delta.angle()
	if p["clip"] in ["idle","walk","invite"]:
		# The actual painted sword tip rests on the floor; body strains around the handle.
		return floor_angle
	var angle=deg_to_rad(float(p["weapon"]))
	var grounded=not p["clip"] in ["jump","air_light","air_skill","air_slam","air_hurt","down","getup"] and not bool(meta["clips"].get(p["clip"],{}).get("airborne_visual",false))
	if p["clip"]=="air_slam" and float(p["phase"])>.62: grounded=true
	if grounded and angle>=0.0 and angle<PI*.5:
		angle=minf(angle,floor_angle)
	return angle

static func _rio_back_grip(meta: Dictionary, p: Dictionary, wrist: Vector2) -> Vector2:
	var legacy=wrist+Vector2(-3,2)
	# Only the newly authored standing flinch and first two cuts use a hilt-
	# aligned second hand. Other source poses, including recovery and WJ, are
	# unchanged. Return to the old grip before the original chain handoff.
	var weight:=0.0
	if p["clip"] in ["attack1","attack2"]:
		weight=smoothstep(0.0,.20,float(p["phase"]))*(1.0-smoothstep(.67,.74,float(p["phase"])))
	elif p["clip"]=="hurt":
		weight=smoothstep(0.0,.15,float(p["phase"]))*(1.0-smoothstep(.78,1.0,float(p["phase"])))
	elif str(p["clip"]).begins_with("rio_"):
		weight=1.0
	return legacy.lerp(wrist+Vector2(-3,0).rotated(_rio_weapon_angle(meta,p,wrist)),weight)

static func _head_name(meta: Dictionary, p: Dictionary) -> String:
	var choice = int(p["head_variant"])
	if meta["id"]=="cat" and choice==4: return "head_huh"
	if meta["id"]=="cat" and choice==5: return "head_cry"
	if choice >= 0: return ["head_focus","head_attack","head_hurt","head_happy"][mini(choice,3)]
	return "head"

static func draw_fighter(canvas: CanvasItem, id: String, clip: String, progress: float, facing: int = 1, tint: Color = Color.WHITE, body_height: float = 0.0, appearance: Dictionary = {}) -> void:
	var meta = _load_rig(id)
	if meta.is_empty(): return
	var p = _sample(meta,clip,progress)
	_authored_roll=deg_to_rad(float(p.get("body_roll",0.0))) if str(clip).begins_with("cat_rolling_paw") else 0.0
	if id=="cat" and appearance.has("cat_face"):
		p["head_variant"]={"happy":3,"huh":4,"cry":5,"startled":2,"shock":2}.get(str(appearance["cat_face"]),p["head_variant"])
	var rig: Dictionary = meta["rig"]
	var world_scale = (body_height if body_height > 0 else float(rig["world_height"])) / float(rig["native_height"])
	if _draw_observer.is_valid():
		_draw_observer.call({"stage":"begin","id":id,"clip":p["clip"],"canvas":canvas.get_instance_id(),"requested_body_height":body_height,"effective_body_height":world_scale*float(rig["native_height"]),"world_scale":world_scale})
	if id == "shark":
		_draw_shark(canvas,meta,p,world_scale,facing,tint)
		_authored_roll=0.0
		return
	var torso_size = _vec(rig["torso"])
	# Less than half a native pixel of ribcage breathing; head/shoulders follow the same neck.
	if p["clip"]=="idle": torso_size.y += float(p.get("breath",0.0))
	var pelvis_size = _vec(rig["pelvis"])
	var head_size = _vec(rig["head"])
	var angle = deg_to_rad(float(p["torso"]))
	var hip = Vector2(0,-float(rig["thigh"])-float(rig["shin"])-float(rig["foot"][1])+2) + p["hip"]
	var waist = hip - Vector2(0,pelvis_size.y*0.35)
	var neck = waist + Vector2(0,-torso_size.y+1).rotated(angle)
	var shoulder_back = waist + Vector2(-float(rig["shoulder"]),-torso_size.y+5).rotated(angle)
	var shoulder_front = waist + Vector2(float(rig["shoulder"]),-torso_size.y+5).rotated(angle)
	var variant = int(p["body_variant"])
	var upper_has_arms = variant >= 0 and _variant_has_arms(meta)
	# The second normal strike is the actual rear paw, crossing in front of
	# the chest. Draw that chain once in front only during this cut, and return
	# it behind the body before the unchanged source chain handoff (.7225).
	var rear_paw_in_front=id=="cat" and ((p["clip"]=="attack2" and float(p["phase"])>=.38 and float(p["phase"])<.70) or (str(p["clip"]).begins_with("cat_") and float(p.get("rear_paw_front",0.0))>.5))
	var two_hand_ball=id=="chicken" and str(p["clip"]).begins_with("chicken_") and float(p.get("ball_two_hand",0.0))>.5 and bool(appearance.get("ball_in_hand",true))
	# Rear chains first, then connected core, then front chains; pivots overlap by two native pixels.
	if id=="rio":
		var hair_size=_vec(rig.get("hair_size",[13,22]))
		_part(canvas,meta,"hair",hair_size,Vector2(.5,.05),neck+Vector2(-head_size.x*.43,-head_size.y*.69),angle+deg_to_rad(float(p["hair"])-12),world_scale,facing,tint)
	if id=="cat":
		_part(canvas,meta,"tail",Vector2(10,22),Vector2(0.7,0.85),hip+Vector2(-5,1),deg_to_rad(float(p["tail"])-35),world_scale,facing,tint)
	_arm(canvas,meta,p,"back",shoulder_back,angle,world_scale,facing,tint,not upper_has_arms and not (id=="rio" and bool(rig.get("heavy_sword",false))) and not rear_paw_in_front and not two_hand_ball)
	_leg(canvas,meta,p,"back",hip+Vector2(-4,0),p["back_foot"],world_scale,facing,tint)
	_leg(canvas,meta,p,"front",hip+Vector2(4,0),p["front_foot"],world_scale,facing,tint)
	_part(canvas,meta,"pelvis",pelvis_size,Vector2(0.5,0.5),hip,angle*0.35,world_scale,facing,tint)
	if variant >= 0:
		var variant_size = torso_size
		if upper_has_arms: variant_size.x *= 1.40
		_part(canvas,meta,["torso_low","torso_rise","torso_slam","torso_recoil"][mini(variant,3)],variant_size,Vector2(0.5,1),waist,angle*.7,world_scale,facing,tint,true)
	else:
		_part(canvas,meta,"torso",torso_size,Vector2(0.5,1),waist,angle,world_scale,facing,tint)
	var heavy_sword=id=="rio" and bool(rig.get("heavy_sword",false))
	var wrist = _arm(canvas,meta,p,"front",shoulder_front,angle,world_scale,facing,tint,not upper_has_arms and not heavy_sword)
	if upper_has_arms: wrist = _variant_wrist(meta,p,waist,angle)
	if two_hand_ball:
		_arm_to(canvas,meta,"back",shoulder_back,wrist+Vector2(-3,2),world_scale,facing,tint)
	if rear_paw_in_front:
		_arm(canvas,meta,p,"back",shoulder_back,angle,world_scale,facing,tint)
	if id=="rio":
		var heavy=bool(rig.get("heavy_sword",false))
		var grip=_vec(rig.get("weapon_grip_uv",[.12,.5])) if heavy else Vector2(.12,.84)
		_part(canvas,meta,"weapon",_vec(rig["weapon"]),grip,wrist,_rio_weapon_angle(meta,p,wrist),world_scale,facing,tint)
		if heavy:
			# Both glove end-caps cover the handle rather than leaving a floating weapon.
			_arm_to(canvas,meta,"back",shoulder_back,_rio_back_grip(meta,p,wrist),world_scale,facing,tint)
			_arm(canvas,meta,p,"front",shoulder_front,angle,world_scale,facing,tint)
		if bool(rig.get("twin_tails",false)):
			var front_hair=_vec(rig.get("hair_size",[13,22]))
			_part(canvas,meta,"hair_front",front_hair,Vector2(.5,.05),neck+Vector2(head_size.x*.40,-head_size.y*.69),angle+deg_to_rad(float(p["hair"])*-.7+10),world_scale,facing,tint)
	elif id=="worker":
		_part(canvas,meta,"weapon",_vec(rig["weapon"]),Vector2(0.50,0.03),wrist,deg_to_rad(float(p["weapon"])*0.55),world_scale,facing,tint)
	elif id=="chicken" and bool(appearance.get("ball_in_hand",true)) and not p["clip"] in ["throw","hurt","air_hurt","down","getup","guard"]:
		# Ball releases at actual strike; battle owns the moving ball after this phase.
		if not (p["clip"] in ["skill1","super","super_up"] and p["phase"] > .44):
			_part(canvas,meta,"weapon",_vec(rig["weapon"]),Vector2(0.5,0.5),wrist+Vector2(2,0),0,world_scale,facing,tint)
	var head_name = _head_name(meta,p)
	if id=="cat" and p["clip"]=="skill2": head_name="head_huh"
	elif id=="cat" and p["clip"]=="skill3": head_name="head_cry"
	var use_variant = not head_name in ["head","head_huh","head_cry"]
	_part(canvas,meta,head_name,head_size,Vector2(0.5,0.93),neck,angle*.25+deg_to_rad(float(p["head"])),world_scale,facing,tint,use_variant)
	_authored_roll=0.0

static func _draw_shark(canvas: CanvasItem, meta: Dictionary, p: Dictionary, world_scale: float, facing: int, tint: Color) -> void:
	var hip: Vector2 = Vector2(0,-28)+p["hip"]*.65
	var body_angle = deg_to_rad(float(p["torso"])*.45)
	var variant = int(p["body_variant"])
	var torso_name = "torso" if variant < 0 else ["torso_low","torso_rise","torso_slam","torso_recoil"][mini(variant,3)]
	_part(canvas,meta,"tail",Vector2(25,23),Vector2(0.90,0.60),hip+Vector2(-11,-2).rotated(body_angle),body_angle+deg_to_rad(float(p["tail"])*.6),world_scale,facing,tint)
	# Exactly three independent articulated leg chains. No extra dorsal fin is drawn: torso already contains one.
	var feet = [p["back_foot"]+Vector2(-14,0),p.get("middle_foot",Vector2.ZERO),p["front_foot"]+Vector2(13,0)]
	var suffixes = ["back","middle","front"]
	for i in range(3):
		var start = hip+Vector2((i-1)*11,6).rotated(body_angle)
		var foot: Vector2 = feet[i]
		var ankle = foot-Vector2(0,10)
		var knee = _knee(start,ankle,7,7)
		_bone(canvas,meta,"thigh_"+suffixes[i],start,knee,7,world_scale,facing,tint)
		_bone(canvas,meta,"shin_"+suffixes[i],knee,ankle,6,world_scale,facing,tint)
		var shoe_angle:=deg_to_rad(float(p.get("foot_"+suffixes[i]+"_angle",0.0))) if str(p["clip"]).begins_with("shark_") else 0.0
		_part(canvas,meta,"foot_"+suffixes[i],Vector2(21,12),Vector2(.45,1),foot,shoe_angle,world_scale,facing,tint)
	_part(canvas,meta,torso_name,Vector2(35,23),Vector2(.5,.6),hip,body_angle,world_scale,facing,tint,variant>=0)
	_part(canvas,meta,"upper_back",Vector2(12,8),Vector2(.12,.25),hip+Vector2(-4,2),body_angle+deg_to_rad(float(p["back_upper"])),world_scale,facing,tint)
	_part(canvas,meta,"upper_front",Vector2(13,8),Vector2(.12,.25),hip+Vector2(4,3),body_angle+deg_to_rad(float(p["front_upper"])),world_scale,facing,tint)
	var head_name = _head_name(meta,p)
	_part(canvas,meta,head_name,Vector2(30,18),Vector2(.13,.58),hip+Vector2(10,-2).rotated(body_angle),body_angle*.55+deg_to_rad(float(p["head"])),world_scale,facing,tint,head_name!="head")

static func get_pose_state(id: String, clip: String, progress: float) -> Dictionary:
	var meta = _load_rig(id)
	if meta.is_empty(): return {"ready":false,"id":id}
	var p = _sample(meta,clip,progress)
	var joints = _joint_positions(meta,p)
	return {"ready":true,"id":id,"clip":p["clip"],"frame":p["keyframe"],"keyframe_count":p["keyframe_count"],"joint_count":18 if id=="shark" else 17,"source_kind":"layered_pixel_rig","motion_mode":"multi_joint_pose","pose":p,"native_height":meta["rig"]["native_height"],"body_variant":p["body_variant"],"head_variant":p["head_variant"],"parts_texture":meta["parts_texture"],"joint_positions":joints,"weapon_tip":joints["weapon_tip"],"paw_tip":joints["paw_tip"],"shoe_tip":joints["shoe_tip"],"source_alignment":meta["clips"].get(p["clip"],{}).get("source_alignment",{})}

static func _joint_positions(meta: Dictionary, p: Dictionary) -> Dictionary:
	var rig: Dictionary=meta["rig"]
	var scale=float(rig["world_height"])/float(rig["native_height"])
	var hip: Vector2
	var wrist: Vector2
	var shoulder: Vector2
	var head: Vector2
	var angle=deg_to_rad(float(p["torso"]))
	var shoe: Vector2=p["front_foot"]+Vector2(float(rig["foot"][0])*.5,-float(rig["foot"][1])*.45)
	if meta["id"]=="shark":
		hip=Vector2(0,-28)+p["hip"]*.65
		shoulder=hip+Vector2(4,3)
		wrist=shoulder+Vector2(13,0).rotated(deg_to_rad(float(p["front_upper"])))
		head=hip+Vector2(20,-4)
		shoe+=Vector2(13,0)
	else:
		hip=Vector2(0,-float(rig["thigh"])-float(rig["shin"])-float(rig["foot"][1])+2)+p["hip"]
		var waist=hip-Vector2(0,float(rig["pelvis"][1])*.35)
		shoulder=waist+Vector2(float(rig["shoulder"]),-float(rig["torso"][1])+5).rotated(angle)
		var reach: float=clampf(float(p.get("front_reach",1.0)),.75,1.8)
		var elbow=shoulder+Vector2(0,float(rig["upper"])*reach).rotated(deg_to_rad(float(p["front_upper"]))+angle*.35)
		wrist=elbow+Vector2(0,float(rig["lower"])*reach).rotated(deg_to_rad(float(p["front_lower"]))+angle*.35)
		if int(p["body_variant"])>=0 and _variant_has_arms(meta):
			wrist=_variant_wrist(meta,p,waist,angle)
		head=waist+Vector2(0,-float(rig["torso"][1])-float(rig["head"][1])*.45).rotated(angle)
	var weapon_tip=wrist
	if meta["id"]=="rio":
		var delta=Vector2(34,0)
		if bool(rig.get("heavy_sword",false)):
			delta=(_vec(rig.get("weapon_tip_uv",[.985,.5]))-_vec(rig.get("weapon_grip_uv",[.12,.5])))*_vec(rig["weapon"])
		weapon_tip+=delta.rotated(_rio_weapon_angle(meta,p,wrist))
	elif meta["id"]=="worker":weapon_tip+=Vector2(8,14).rotated(deg_to_rad(float(p["weapon"])*.55))
	elif meta["id"]=="chicken":weapon_tip+=Vector2(7,0)
	var positions: Dictionary={"hip":hip*scale,"head":head*scale,"shoulder":shoulder*scale,"wrist":wrist*scale,"weapon_tip":weapon_tip*scale,"paw_tip":wrist*scale,"shoe_tip":shoe*scale}
	if str(p["clip"]).begins_with(str(meta["id"])+"_"):
		positions["front_foot"]=p["front_foot"]*scale
		positions["back_foot"]=p["back_foot"]*scale
		positions["middle_foot"]=p.get("middle_foot",Vector2.ZERO)*scale
		if meta["id"]=="shark":
			positions["front_foot"]+=Vector2(13,0)*scale
			positions["back_foot"]+=Vector2(-14,0)*scale
		positions["weapon_grip"]=wrist*scale
		positions["weapon_angle"]=_rio_weapon_angle(meta,p,wrist) if meta["id"]=="rio" else deg_to_rad(float(p["weapon"])*.55)
		if meta["id"]!="shark":
			var waist: Vector2=hip-Vector2(0,float(rig["pelvis"][1])*.35)
			var shoulder_back: Vector2=waist+Vector2(-float(rig["shoulder"]),-float(rig["torso"][1])+5).rotated(angle)
			var reach_back: float=clampf(float(p.get("back_reach",1.0)),.75,1.8)
			var elbow_back: Vector2=shoulder_back+Vector2(0,float(rig["upper"])*reach_back).rotated(deg_to_rad(float(p["back_upper"]))+angle*.35)
			positions["wrist_back"]=(elbow_back+Vector2(0,float(rig["lower"])*reach_back).rotated(deg_to_rad(float(p["back_lower"]))+angle*.35))*scale
		if str(p["clip"]).begins_with("cat_rolling_paw"):
			var roll:=deg_to_rad(float(p.get("body_roll",0.0)))
			for key: String in positions:
				if positions[key] is Vector2:
					var local: Vector2=positions[key]/scale
					positions[key]=((local-_authored_roll_pivot).rotated(roll)+_authored_roll_pivot)*scale
	return positions

static func _variant_wrist(meta: Dictionary, p: Dictionary, waist: Vector2, angle: float) -> Vector2:
	var hand_marks = {"cat":[Vector2(.86,.84),Vector2(.84,.43),Vector2(.66,.85),Vector2(.88,.47)],"worker":[Vector2(.85,.85),Vector2(.86,.68),Vector2(.70,.84),Vector2(.88,.65)],"chicken":[Vector2(.83,.69),Vector2(.89,.16),Vector2(.72,.78),Vector2(.90,.25)]}
	var point: Vector2 = hand_marks[meta["id"]][mini(int(p["body_variant"]),3)]
	var size = _vec(meta["rig"]["torso"])*Vector2(1.4,1)
	return waist + ((point-Vector2(.5,1))*size).rotated(angle*.7)

static func _load_effects(id: String) -> Dictionary:
	if _effects.has(id): return _effects[id]
	var path="res://assets/pixel/effects/%s.effects.json"%id
	if not FileAccess.file_exists(path): return {}
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: return {}
	_effects[id]=data
	return data

static func has_skill_effects(id: String) -> bool:
	return not _load_effects(id).is_empty()

static func clear_runtime_cache() -> void:
	# Offline render/test teardown only: free draw canvases and await frame_post_draw before this call.
	_draw_observer=Callable()
	_isolated_parts.clear()
	_source_images.clear()
	_textures.clear()
	_effects.clear()
	_rigs.clear()

static func get_effect_state(id: String, clip: String, progress: float, body_height: float=0.0) -> Dictionary:
	var meta=_load_effects(id)
	var rig_meta=_load_rig(id)
	var name: String=EFFECT_ALIASES.get(clip,_clip_name(clip))
	if meta.is_empty() or rig_meta.is_empty() or not meta["effects"].has(name): return {"ready":false}
	var source: Dictionary=meta["effects"][name]
	var p=clampf(progress,0,1)
	var expansion=lerpf(.35,1.0,smoothstep(0.0,.16,p))
	var fade=1.0-smoothstep(.66,1.0,p)
	var scale=(body_height/float(rig_meta["rig"]["world_height"])) if body_height>0 else 1.0
	var full_size=_vec(source["world_size"])*scale
	var size=full_size*expansion
	var position=Vector2(38,-float(rig_meta["rig"]["world_height"])*.58)*scale
	if name in ["skill2","super_up"]: position=Vector2(45,0)*scale
	elif name in ["skill3","super_down"]: position=Vector2(32,0)*scale
	elif name=="super": position=Vector2(25,-12)*scale
	var direction: String=source["direction"]
	if direction in ["horizontal","arena","ground_arena"]:
		position.x+=smoothstep(.08,.72,p)*(52 if name=="skill1" else 100)*scale
	if p>.66: position.y-=smoothstep(.66,1,p)*(16 if name.begins_with("super") else 8)*scale
	var anchor=_vec(source["anchor"])
	var segment="expand" if p<.16 else ("release" if p<.66 else "dissipate")
	return {"ready":true,"id":id,"clip":name,"phase":p,"phase_segment":segment,"texture":meta["texture"],"source_rect":source["source_rect"],"world_size":size,"maximum_world_size":full_size,"native_extent":full_size/4,"position":position,"anchor":anchor,"opacity":fade,"direction":direction,"source_kind":"ai_effect_shape_plus_release_timeline_composite","contains_character":false}

static func draw_skill_effect(canvas: CanvasItem, id: String, clip: String, progress: float, facing: int=1, tint: Color=Color.WHITE, body_height: float=0.0) -> void:
	# Independent release timeline0..1. Caller owns startup, hit spark, hitstop and layering.
	var state=get_effect_state(id,clip,progress,body_height)
	if not state.get("ready",false) or state["opacity"]<=.001: return
	var texture=_texture(state["texture"])
	if not texture: return
	# The projectile caller supplies a fixed body_height to fit its actual hit
	# object. Only the release uses a flowing/dissolving mesh; the projectile
	# silhouette and apparent centre must stay stable during flight.
	if body_height<=0.0:
		SkillEffectMotion.draw(canvas,state,texture,facing,tint)
		return
	var source: Array=state["source_rect"]
	var rect=Rect2(float(source[0]),float(source[1]),float(source[2]),float(source[3]))
	var size: Vector2=state["world_size"]
	var position: Vector2=state["position"]
	var anchor: Vector2=state["anchor"]
	var points=PackedVector2Array()
	var uv=PackedVector2Array()
	for corner in [Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)]:
		var at: Vector2=(corner-anchor)*size+position
		points.append(Vector2(at.x*facing,at.y))
		uv.append((rect.position+corner*rect.size)/texture.get_size())
	var color=tint
	color.a*=float(state["opacity"])
	canvas.draw_polygon(points,PackedColorArray([color]),uv,texture)
