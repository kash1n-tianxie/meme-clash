extends RefCounted
## HD menu performers: legacy isolated components and V18 original-master skinning.
## V18 samples one unchanged painted image on one continuous joint-weighted mesh.
## All drawing preserves the caller's CanvasItem draw transform. Coordinates are foot-relative.

static var _characters: Dictionary = {}
static var _part_textures: Dictionary = {}
static var _source_textures: Dictionary = {}
static var _mesh_layouts: Dictionary = {}
static var _mesh_pose_cache: Dictionary = {}
static var _mesh_pose_order: Array[String] = []
static var _loaded := false
const MANIFEST := "res://assets/art/hd_rigs/manifest.json"
const EXTRA_MANIFEST := "res://assets/art/hd_rigs/four_memes.json"
const MASTER_MANIFEST := "res://assets/art/hd_rigs/visual_v18.json"
const MESH_POSE_CACHE_LIMIT := 32
const CLIPS := ["idle", "dance", "invite", "confirm", "easter"]

static func _v(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2: return value
	if value is Array and value.size() >= 2: return Vector2(float(value[0]), float(value[1]))
	return fallback

static func _load() -> void:
	if _loaded: return
	_loaded = true
	for path: String in [MANIFEST, EXTRA_MANIFEST, MASTER_MANIFEST]:
		if not FileAccess.file_exists(path): continue
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if value is Dictionary: _characters.merge(value.get("characters", {}), true)
	for id: String in _characters:
		if _characters[id].get("renderer", "") != "master_mesh":
			_characters[id]["parts"].sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.get("z",0)) < int(b.get("z",0)))

static func has_assets(id: String) -> bool:
	_load()
	if not _characters.has(id): return false
	var meta: Dictionary = _characters[id]
	if meta.get("renderer", "") == "master_mesh":
		return not meta.get("bones", []).is_empty() and _source_texture(str(meta.get("source_path", ""))) != null
	return not meta.get("parts", []).is_empty()

static func available_characters() -> Array:
	_load()
	return _characters.keys()

static func release_cache() -> void:
	_part_textures.clear(); _source_textures.clear(); _characters.clear(); _mesh_layouts.clear(); _mesh_pose_cache.clear(); _mesh_pose_order.clear(); _loaded = false

static func _source_texture(path: String) -> Texture2D:
	if _source_textures.has(path): return _source_textures[path]
	var texture: Texture2D
	if ResourceLoader.exists(path): texture = load(path) as Texture2D
	else:
		var raw := Image.new()
		if raw.load(path) == OK: texture = ImageTexture.create_from_image(raw)
	if texture: _source_textures[path] = texture
	return texture

static func _part_texture(meta: Dictionary, part: Dictionary) -> Texture2D:
	var key := str(meta["id"]) + "/" + str(part["name"])
	if _part_textures.has(key): return _part_textures[key]
	var path: String = str(meta["textures"].get(part.get("texture", "parts"), ""))
	var texture := _source_texture(path)
	if texture == null: return null
	var pixels: Image = texture.get_image()
	if pixels.is_compressed(): pixels.decompress()
	if pixels.get_format() != Image.FORMAT_RGBA8: pixels.convert(Image.FORMAT_RGBA8)
	var r: Array = part["source_rect"]
	var rect := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
	var isolated := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	isolated.fill(Color.TRANSPARENT)
	for chunk: Array in part.get("source_parts", [r]):
		var piece := Rect2i(int(chunk[0]), int(chunk[1]), int(chunk[2]), int(chunk[3]))
		isolated.blit_rect(pixels, piece, piece.position - rect.position)
	if bool(part.get("flip_y",false)): isolated.flip_y()
	if bool(part.get("flip_x",false)): isolated.flip_x()
	var ready := ImageTexture.create_from_image(isolated)
	_part_textures[key] = ready
	return ready

static func _ik(root: Vector2, target: Vector2, upper: float, lower: float, bend: float) -> Vector2:
	var offset := target - root
	var distance := clampf(offset.length(), .01, upper + lower - .01)
	var direction := offset.normalized()
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var side := sqrt(maxf(0.0, upper * upper - along * along))
	return root + direction * along + Vector2(-direction.y, direction.x) * side * bend

static func _grounded_weapon_angle(grip: Vector2, outline: Array) -> float:
	var low := -PI/2.0
	var high := 0.0
	for iteration in range(24):
		var angle := (low+high)*.5
		var bottom := -INF
		for point: Array in outline: bottom=maxf(bottom,_v(point).rotated(angle).y+grip.y)
		if bottom > 0: high=angle
		else: low=angle
	return (low+high)*.5

static func _dance_step(phase: float, slot: int, count: int, lift: float, stride: float, duty: float) -> Vector2:
	# Only one foot swings in its beat window. All other feet remain planted;
	# the actor origin and Rio's separate sword support never move with a step.
	var beat := phase * count
	if floori(beat) != slot: return Vector2.ZERO
	var local := (beat-float(slot)-(1.0-duty)*.5) / maxf(.01,duty)
	if local <= 0.0 or local >= 1.0: return Vector2.ZERO
	var arc := pow(sin(local*PI),2)
	return Vector2(stride*arc,-lift*arc)

static func _pose(meta: Dictionary, clip: String, progress: float) -> Dictionary:
	var name := clip if clip in CLIPS else "idle"
	var phase := fposmod(progress, 1.0) if name in ["idle", "dance"] else clampf(progress, 0.0, 1.0)
	var pose_phase := phase
	var confirm_strength := 0.0
	if name == "confirm":
		var enter := clampf(phase/.55,0.0,1.0)
		confirm_strength = enter*enter*(3.0-2.0*enter)
		# Freeze every secondary oscillator as well as the main body lean.
		pose_phase = confirm_strength*.5
	var wave := pose_phase * TAU
	var rig: Dictionary = meta.get("rig", {})
	var id: String = meta["id"]
	var dancing := name == "dance"
	var pulse := sin(wave * 2.0)
	var hip_y := float(rig.get("hip_y", -46.0))
	var bob := (4.0 * (.5 + .5 * cos(wave * 2.0))) if dancing else sin(wave) * .65
	var sway := sin(wave) * (5.0 if dancing else .6)
	var lean := sin(wave) * (7.0 if dancing else 1.0)
	var special := confirm_strength if name == "confirm" else sin(phase * PI)
	if name == "invite": sway = -special * 3.0; lean = special * -6.0; bob = special * 2.0
	if name == "confirm": sway = -special * 8.0; lean = -special * 13.0; bob = special * 5.0
	if name == "easter": sway = sin(wave * 2) * 9.0 * special; lean = sin(wave * 2) * 16.0 * special; bob = special * 12.0
	if id == "worker" and dancing: lean += 12.0 + 15.0 * (.5+.5*sin(wave))
	var torso_angle := deg_to_rad(lean)
	var hips := Vector2(sway, hip_y + bob)
	var torso_height := float(rig.get("torso_height", 34.0))
	var neck := hips + _v(rig.get("head_offset",[0,-torso_height])).rotated(torso_angle)
	var shoulder_span := float(rig.get("shoulder_span", 10.0))
	var shoulder_y := -torso_height + float(rig.get("shoulder_drop", 5.0))
	var front_shoulder := hips + Vector2(shoulder_span, shoulder_y).rotated(torso_angle)
	var back_shoulder := hips + Vector2(-shoulder_span, shoulder_y).rotated(torso_angle)
	var foot_gap := float(rig.get("foot_gap", 11.0))
	var front_foot := Vector2(foot_gap, 0)
	var back_foot := Vector2(-foot_gap, 0)
	var third_foot := Vector2.ZERO
	if dancing:
		var step: Dictionary = rig.get("dance_step",{})
		var lift := float(step.get("lift",0.0))
		var stride := float(step.get("stride",0.0))
		var duty := clampf(float(step.get("duty",.72)),.1,1.0)
		var count := 3 if id == "shark" else 2
		front_foot += _dance_step(phase,0,count,lift,stride,duty)
		back_foot += _dance_step(phase,1,count,lift,-stride,duty)
		if count == 3: third_foot += _dance_step(phase,2,count,lift,0.0,duty)
	var upper_leg := float(rig.get("leg_upper", 23.0))
	var lower_leg := float(rig.get("leg_lower", 23.0))
	var ankle_height := float(rig.get("ankle_height", 8.0))
	var front_hip := hips + Vector2(5, float(rig.get("leg_root_drop",0)))
	var back_hip := hips + Vector2(-5, float(rig.get("leg_root_drop",0)))
	var front_knee := _ik(front_hip, front_foot - Vector2(0, ankle_height), upper_leg, lower_leg, -1.0)
	var back_knee := _ik(back_hip, back_foot - Vector2(0, ankle_height), upper_leg, lower_leg, 1.0)
	if id == "rio":
		front_knee = front_hip.lerp(front_foot-Vector2(0,ankle_height),.5)+Vector2(pulse*2,0)
		back_knee = back_hip.lerp(back_foot-Vector2(0,ankle_height),.5)-Vector2(pulse*2,0)
	elif id == "worker":
		front_knee=front_hip.lerp(front_foot,.46)+Vector2(3+sin(wave)*3,0)
		back_knee=back_hip.lerp(back_foot,.46)-Vector2(3+sin(wave)*3,0)
	var upper_arm := float(rig.get("upper", 19.0))
	var lower_arm := float(rig.get("lower", 19.0))
	var front_wrist := front_shoulder + Vector2(10 + 8*sin(wave), 18 + 5*cos(wave))
	var back_wrist := back_shoulder + Vector2(-11 + 8*sin(wave+PI), 18 + 5*cos(wave+PI))
	var sword_length := float(rig.get("weapon_length", 126.0))
	var weapon_grip := hips + Vector2(17.0, -3.0)
	var weapon_angle := 0.0
	var weapon_tip := Vector2.ZERO
	var weapon_ground_contact := Vector2.ZERO
	if id == "rio":
		weapon_grip = Vector2(17 + (sway * .35), -49 + bob * .4)
		if name == "confirm": weapon_grip += Vector2(-special * 5, -special * 5)
		if name == "easter": weapon_grip += Vector2(-special * 4, special * 6)
		# A long heavy sword pivots on the ground, rather than orbiting the torso.
		var horizontal := sqrt(maxf(1.0, sword_length*sword_length-weapon_grip.y*weapon_grip.y))
		weapon_tip = Vector2(weapon_grip.x + horizontal, 0)
		weapon_angle = (weapon_tip - weapon_grip).angle() - PI / 2.0
		var outline: Array=rig.get("weapon_outline_native",[])
		if not outline.is_empty():
			weapon_angle=_grounded_weapon_angle(weapon_grip,outline)
			weapon_tip=weapon_grip+_v(rig.get("weapon_tip_native",[0,sword_length])).rotated(weapon_angle)
			for point: Array in outline:
				var candidate := weapon_grip+_v(point).rotated(weapon_angle)
				if candidate.y>=weapon_ground_contact.y-.0001: weapon_ground_contact=candidate
		var grip_axis := Vector2(0, 1).rotated(weapon_angle)
		front_wrist = weapon_grip - grip_axis * 3.5
		back_wrist = weapon_grip - grip_axis * 9.0
		if name == "invite": front_wrist = front_shoulder + Vector2(14 + special * 4, -20 * special + 4)
	elif id == "cat":
		front_wrist = front_shoulder + Vector2(13 + pulse*5, -15 - absf(sin(wave))*12)
		back_wrist = back_shoulder + Vector2(-13 - pulse*5, -15 - absf(cos(wave))*12)
	elif id == "worker":
		front_wrist = front_shoulder + Vector2(8, 28)
		back_wrist = back_shoulder + Vector2(-8 - pulse*6, 22)
	elif id == "chicken":
		front_wrist = front_shoulder + Vector2(16 + pulse*8, 6 - sin(wave)*14)
		back_wrist = back_shoulder + Vector2(-16 - pulse*8, 6 + sin(wave)*14)
	if id != "rio" and name == "invite": front_wrist=front_shoulder+Vector2(16+special*5,4-special*25)
	if id != "rio" and name == "confirm":
		front_wrist=front_shoulder+Vector2(12-special*6,12-special*12)
		back_wrist=back_shoulder+Vector2(-12+special*6,12-special*12)
	var front_elbow := _ik(front_shoulder, front_wrist, upper_arm, lower_arm, 1.0)
	var back_elbow := _ik(back_shoulder, back_wrist, upper_arm, lower_arm, -1.0)
	var head_angle := torso_angle * .6 + deg_to_rad(sin(wave - .45) * (5.0 if dancing else 1.3))
	var joints := {"hips":hips, "hip_front":front_hip, "hip_back":back_hip,"hip_third":hips+Vector2(0,float(rig.get("leg_root_drop",0))),
		"torso":hips, "neck":neck, "head":neck,
		"shoulder_front":front_shoulder, "elbow_front":front_elbow, "wrist_front":front_wrist,
		"shoulder_back":back_shoulder, "elbow_back":back_elbow, "wrist_back":back_wrist,
		"upper_front":front_shoulder, "lower_front":front_elbow, "upper_back":back_shoulder, "lower_back":back_elbow,
		"knee_front":front_knee, "knee_back":back_knee, "ankle_front":front_foot-Vector2(0,ankle_height), "ankle_back":back_foot-Vector2(0,ankle_height),
		"foot_front":front_foot, "foot_back":back_foot, "foot_third":third_foot, "ankle_third":third_foot-Vector2(0,ankle_height),
		"skirt_front":hips.lerp(front_foot,.48)+Vector2(4 + sin(wave-.6)*3,0),
		"skirt_back":hips.lerp(back_foot,.48)+Vector2(-4 + sin(wave-1.2)*3,0),
		"hair_left":neck+Vector2(-8,-16).rotated(head_angle), "hair_right":neck+Vector2(8,-16).rotated(head_angle),
		"tail":hips+_v(rig.get("tail_offset",[-16,-9])), "weapon":weapon_grip, "weapon_tip":weapon_tip,"weapon_ground_contact":weapon_ground_contact,
		"prop":front_wrist}
	var angles := {"head_angle":head_angle, "torso_angle":torso_angle,
		"hair_left_angle":head_angle+deg_to_rad(sin(wave-.7)*(15.0 if dancing else 3.5)),
		"hair_right_angle":head_angle+deg_to_rad(sin(wave-1.1)*(18.0 if dancing else 4.0)),
		"skirt_front_angle":deg_to_rad(sin(wave-.8)*(9.0 if dancing else 1.5)),
		"skirt_back_angle":deg_to_rad(sin(wave-1.3)*(7.0 if dancing else 1.2)),
		"weapon_angle":weapon_angle, "tail_angle":deg_to_rad(sin(wave-.7)*15), "zero":0.0}
	var face_variant := int(meta.get("face_variants",{}).get(name,1 if name in ["invite","easter"] else 0))
	return {"clip":name,"phase":phase,"pose_phase":pose_phase,"confirm_held":name=="confirm" and phase>=.55,"joints":joints,"angles":angles,"face_variant":face_variant,
		"joint_count":joints.size(),"keyframe_count":8 if dancing else 4,"source_kind":"ai_drawn_parts_articulated_skeletal_animation",
		"feet": [front_foot, back_foot, third_foot] if id=="shark" else [front_foot,back_foot],"root_anchor":Vector2.ZERO,"head_anchor":neck,"body_height_unit":float(meta.get("native_body_height",100))}

static func get_pose_state(id: String, clip: String, progress: float, body_height: float = 300.0) -> Dictionary:
	_load()
	if not _characters.has(id): return {"ready":false}
	var meta: Dictionary = _characters[id]
	if meta.get("renderer", "") == "master_mesh": return _master_state(meta, clip, progress, body_height)
	var result := _pose(meta, clip, progress)
	var scale := body_height / float(meta.get("native_body_height",100))
	var bounds := Rect2()
	var first_point := true
	for part: Dictionary in meta["parts"]:
		for command: Dictionary in _geometry(part,result):
			for point: Vector2 in command["points"]:
				if first_point: bounds=Rect2(point*scale,Vector2.ZERO); first_point=false
				else: bounds=bounds.expand(point*scale)
	result["bounds"] = bounds
	result["max_extent"]=Vector2(maxf(absf(bounds.position.x),absf(bounds.end.x)),maxf(absf(bounds.position.y),absf(bounds.end.y)))
	var scaled: Dictionary = {}
	for key: String in result["joints"]: scaled[key] = result["joints"][key] * scale
	result["joints_native"] = result["joints"]
	result["joints"] = scaled
	result["feet"] = [scaled["foot_front"],scaled["foot_back"],scaled["foot_third"]] if id=="shark" else [scaled["foot_front"],scaled["foot_back"]]
	result["weapon_tip"] = scaled["weapon_tip"]
	result["weapon_ground_contact"]=scaled["weapon_ground_contact"]
	result["head_anchor"] = scaled["head"]
	result["part_count"] = meta["parts"].size()
	var used: Dictionary = {}
	var active_parts := 0
	for part: Dictionary in meta["parts"]:
		if part.has("face_variant") and int(part["face_variant"]) != int(result["face_variant"]): continue
		active_parts+=1
		used[str(part.get("anchor","hips"))]=true
		for joint: String in part.get("bone",[]): used[joint]=true
	result["joint_count"]=used.size()
	result["active_part_count"]=active_parts
	result["body_height"] = body_height
	result["ready"] = true
	return result

static func _geometry(part: Dictionary, pose: Dictionary) -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	if part.has("face_variant") and int(part["face_variant"]) != int(pose["face_variant"]): return commands
	var joints: Dictionary = pose["joints"]
	var at: Vector2 = joints.get(str(part.get("anchor","hips")), Vector2.ZERO)
	var angle: float = float(pose["angles"].get(str(part.get("rotation","zero")),0))
	var rect: Array = part["source_rect"]
	var source_size := Vector2(float(rect[2]),float(rect[3]))
	var size := _v(part.get("size",[20,20]))
	var pivot := _v(part.get("pivot",[.5,.5])) * source_size
	if bool(part.get("flip_y",false)): pivot.y=source_size.y-pivot.y
	if bool(part.get("flip_x",false)): pivot.x=source_size.x-pivot.x
	var ratio := size / source_size
	if part.has("bone"):
		var bone: Array = part["bone"]
		var start: Vector2 = joints.get(str(bone[0]), at)
		var end: Vector2 = joints.get(str(bone[1]), start+Vector2(0,20))
		var direction := (end-start).normalized()
		start-=direction*float(part.get("bone_overlap_start",0))
		end+=direction*float(part.get("bone_overlap_end",0))
		var source_start := _v(part.get("source_joint_start",[source_size.x*.5,0]))
		var source_end := _v(part.get("source_joint_end",[source_size.x*.5,source_size.y]))
		if bool(part.get("flip_y",false)):
			source_start.y=source_size.y-source_start.y; source_end.y=source_size.y-source_end.y
		if bool(part.get("flip_x",false)):
			source_start.x=source_size.x-source_start.x; source_end.x=source_size.x-source_end.x
		var source_direction := source_end-source_start
		var bone_scale := (end-start).length()/maxf(1.0,source_direction.length())
		ratio = Vector2.ONE*bone_scale
		pivot = source_start
		at = start
		angle = (end-start).angle()-source_direction.angle()
	elif part.has("bind_pivot") and not joints.has(str(part.get("anchor",""))):
		at = joints.get(str(part.get("parent","hips")),Vector2.ZERO)+_v(part["bind_pivot"])
	var points := PackedVector2Array()
	var bands := 6 if bool(part.get("cloth_chain",false)) else 1
	for strip in range(bands):
		points.clear()
		var uv := PackedVector2Array()
		var lo := float(strip)/bands
		var hi := float(strip+1)/bands
		for corner: Vector2 in [Vector2(0,lo),Vector2(1,lo),Vector2(1,hi),Vector2(0,hi)]:
			var p := ((corner*source_size-pivot)*ratio).rotated(angle)+at
			if bands > 1:
				var original_hem := ((Vector2(.5,1)*source_size-pivot)*ratio).rotated(angle)+at
				p.y += (float(part.get("fixed_hem_y",-2.0))-original_hem.y)*pow(corner.y,2)
				p.x += sin(corner.y*PI)*float(joints["skirt_front"].x-joints["hips"].x)*.5
			points.append(p)
			uv.append(corner)
		commands.append({"points":points.duplicate(),"uv":uv})
	return commands

static func get_content_rect(id: String,clip: String,progress: float,body_height: float = 300.0,facing: int = 1) -> Rect2:
	var state := get_pose_state(id,clip,progress,body_height)
	var bounds: Rect2 = state.get("bounds",Rect2())
	if facing < 0: bounds.position.x=-bounds.end.x
	return bounds

static func _draw_part(canvas: CanvasItem, meta: Dictionary, part: Dictionary, pose: Dictionary, scale: float, facing: int, tint: Color) -> void:
	var geometry := _geometry(part,pose)
	if geometry.is_empty(): return
	var texture := _part_texture(meta,part)
	if texture==null: return
	for command: Dictionary in geometry:
		var points := PackedVector2Array()
		for point: Vector2 in command["points"]: points.append(Vector2(point.x*facing,point.y)*scale)
		canvas.draw_polygon(points,PackedColorArray([tint]),command["uv"],texture)

static func draw_character(canvas: CanvasItem, id: String, clip: String, progress: float, facing: int = 1, tint: Color = Color.WHITE, body_height: float = 300.0) -> void:
	_load()
	if not _characters.has(id): return
	var meta: Dictionary = _characters[id]
	if meta.get("renderer", "") == "master_mesh":
		_draw_master(canvas, meta, clip, progress, facing, tint, body_height)
		return
	var pose := _pose(meta,clip,progress)
	var scale := body_height/float(meta.get("native_body_height",100))
	for part: Dictionary in meta["parts"]: _draw_part(canvas,meta,part,pose,scale,facing,tint)


## V18 uses one continuous master-image surface. Each UV appears exactly once;
## neighboring triangles share their vertices, so a rotating shoulder cannot
## leave a cut-part gap or draw a second torso. Source PNG pixels are unchanged.
static func _master_phase(clip: String, progress: float) -> Dictionary:
	var name := clip if clip in CLIPS else "idle"
	var phase := fposmod(progress, 1.0) if name in ["idle", "dance"] else clampf(progress, 0.0, 1.0)
	var strength := smoothstep(0.0, .55, phase) if name == "confirm" else sin(phase * PI)
	return {"clip":name, "phase":phase, "strength":strength, "wave":(strength * .5 if name == "confirm" else phase) * TAU}

static func _master_pose(meta: Dictionary, clip: String, progress: float) -> Dictionary:
	var timing := _master_phase(clip, progress)
	var dance: bool = timing.clip == "dance"
	var wave: float = timing.wave
	var strength: float = timing.strength
	var height := float(meta["source_body_height"])
	var transforms: Dictionary = {}
	var joints: Dictionary = {}
	var angles: Dictionary = {}
	for bone: Dictionary in meta["bones"]:
		var name := str(bone["name"])
		var pivot := _v(bone["pivot"])
		var parent := str(bone.get("parent", ""))
		var motion := str(bone.get("motion", name))
		var target_pivot := _transform_source(pivot, transforms[parent]) if transforms.has(parent) else pivot
		var angle := float(transforms[parent].angle) if transforms.has(parent) else 0.0
		var relative_angle := 0.0
		var offset := Vector2.ZERO
		var side := float(bone.get("side", 1.0))
		var lag := float(bone.get("lag", .0))
		var follow := sin(wave - lag) + sin(lag)
		match motion:
			"torso":
				relative_angle = deg_to_rad(sin(wave) * (2.2 if dance else .65))
				offset = Vector2(sin(wave) * height * (.009 if dance else .001), sin(wave * 2.0) * height * (.009 if dance else .0015))
				if timing.clip == "invite": relative_angle = deg_to_rad(-4.0 * strength)
				if timing.clip == "confirm": relative_angle = deg_to_rad(-3.0 * strength)
				if timing.clip == "easter": relative_angle = deg_to_rad(sin(wave * 2.0) * 4.0 * strength)
				if str(meta.id) == "worker" and dance: relative_angle += deg_to_rad((1.0 - cos(wave)) * 4.0)
				if str(meta.id) == "rio":
					# Both arms are nearly extended in the painted rest pose. Her
					# weight rocks toward the supported blade, never away from it
					# far enough to require stretching or detach a painted hand.
					var load := (1.0 - cos(wave)) * .5
					relative_angle = deg_to_rad(pow(sin(wave), 2.0) * (2.2 if dance else .45))
					offset = Vector2(load * height * (.009 if dance else .001), (1.0 - cos(wave * 2.0)) * height * (.003 if dance else .0007))
					if timing.clip in ["invite", "confirm"]: relative_angle = deg_to_rad(3.0 * strength); offset.x = height * .004 * strength
					if timing.clip == "easter": relative_angle = deg_to_rad(pow(sin(wave * 2.0), 2.0) * 3.0 * strength)
			"head":
				relative_angle = deg_to_rad(follow * (3.0 if dance else .8))
				if timing.clip in ["invite", "confirm"]: relative_angle += deg_to_rad(side * strength * -3.0)
			"arm", "paw", "fin":
				relative_angle = deg_to_rad(side * follow * (6.0 if dance else 1.0))
				if timing.clip == "invite": relative_angle += deg_to_rad(side * strength * 9.0)
				if timing.clip == "confirm": relative_angle += deg_to_rad(side * strength * 5.0)
				if timing.clip == "easter": relative_angle += deg_to_rad(side * sin(wave * 2.0) * strength * 12.0)
			"forearm": relative_angle = deg_to_rad(side * follow * (3.0 if dance else .55))
			"tail": relative_angle = deg_to_rad(follow * (8.0 if dance else 2.0))
			"hair": relative_angle = deg_to_rad(side * follow * (4.0 if dance else 1.4))
			"skirt":
				relative_angle = deg_to_rad(side * follow * (2.0 if dance else .35))
				offset.x = side * follow * height * (.004 if dance else .0008)
			"prop": relative_angle = deg_to_rad(side * follow * (4.0 if dance else .4))
			"weapon":
				# Its pivot is the real blade/ground support, not the actor root.
				target_pivot = pivot
				angle = 0.0
				relative_angle = deg_to_rad(follow * (.65 if dance else .15))
			"fixed": target_pivot = pivot; angle = 0.0
		angle += relative_angle * float(bone.get("strength", 1.0))
		transforms[name] = {"pivot":pivot, "target":target_pivot + offset, "angle":angle}
		joints[name] = target_pivot + offset
		angles[name] = angle
	# Inverse kinematics keeps painted hands on the heavy grip and leg chains
	# connected to planted feet, even while the hips/shoulders follow the beat.
	for chain: Dictionary in meta.get("ik_chains", []):
		var source_root := _v(chain["root"])
		var source_middle := _v(chain["middle"])
		var source_end := _v(chain["end"])
		var root_parent := str(chain.get("root_parent", "torso"))
		var target_parent := str(chain.get("target_parent", ""))
		var target_root := _transform_source(source_root, transforms[root_parent]) if transforms.has(root_parent) else source_root
		var target_end := _transform_source(source_end, transforms[target_parent]) if transforms.has(target_parent) else source_end
		var target_middle := source_middle if target_root.distance_to(source_root) < .0001 and target_end.distance_to(source_end) < .0001 else _ik(target_root, target_end, source_root.distance_to(source_middle), source_middle.distance_to(source_end), float(chain.get("bend", 1.0)))
		var upper := str(chain["upper"])
		var lower := str(chain["lower"])
		var upper_angle := (target_middle - target_root).angle() - (source_middle - source_root).angle()
		var lower_angle := (target_end - target_middle).angle() - (source_end - source_middle).angle()
		transforms[upper] = {"pivot":source_root, "target":target_root, "angle":upper_angle}
		transforms[lower] = {"pivot":source_middle, "target":target_middle, "angle":lower_angle}
		joints[upper] = target_root; joints[lower] = target_middle
		joints[upper + "_end"] = target_middle; joints[lower + "_end"] = target_end
		angles[upper] = upper_angle; angles[lower] = lower_angle
	return {"clip":timing.clip, "phase":timing.phase, "confirm_held":timing.clip == "confirm" and timing.phase >= .55, "transforms":transforms, "joints_source":joints, "angles":angles}

static func _transform_source(point: Vector2, transform: Dictionary) -> Vector2:
	return (point - transform.pivot).rotated(float(transform.angle)) + transform.target

static func _source_polygon(value: Array) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for point: Variant in value: polygon.append(_v(point))
	return polygon

static func _master_weights(meta: Dictionary, point: Vector2) -> Array:
	var candidates: Array = []
	var sum := 0.0
	for bone: Dictionary in meta["bones"]:
		var pivot := _v(bone["pivot"])
		var end := _v(bone.get("end", bone["pivot"]))
		var radius := maxf(float(bone.get("radius", 1.0)), 1.0)
		var distance := point.distance_to(Geometry2D.get_closest_point_to_segment(point, pivot, end))
		var weight := pow(clampf(1.0 - distance / radius, 0.0, 1.0), 2.0)
		var polygon: Array = bone.get("polygon", [])
		if not polygon.is_empty():
			var source_polygon := _source_polygon(polygon)
			var inside := Geometry2D.is_point_in_polygon(point, source_polygon)
			var boundary_distance := INF
			for index: int in range(source_polygon.size()):
				boundary_distance = minf(boundary_distance, point.distance_to(Geometry2D.get_closest_point_to_segment(point, source_polygon[index], source_polygon[(index + 1) % source_polygon.size()])))
			var feather := float(bone.get("feather", 42.0))
			if inside and bool(bone.get("rigid", str(bone.get("motion", "")) in ["fixed", "weapon", "head"])) and boundary_distance >= feather:
				return [[str(bone["name"]), 1.0]]
			weight = float(bone.get("priority", 12.0)) * smoothstep(0.0, maxf(feather, .001), boundary_distance) if inside else weight * float(bone.get("outside_weight", .0))
		if weight > .00001: candidates.append([str(bone["name"]), weight]); sum += weight
	if sum <= .00001: return [[str(meta.get("fallback_bone", "torso")), 1.0]]
	# A small body contribution makes every boundary taper into the same surface.
	candidates.append([str(meta.get("fallback_bone", "torso")), 1.0]); sum += 1.0
	for entry: Array in candidates: entry[1] = float(entry[1]) / sum
	return candidates

static func _deform_source(point: Vector2, weights: Array, transforms: Dictionary) -> Vector2:
	var output := Vector2.ZERO
	for entry: Array in weights:
		var transform: Dictionary = transforms.get(str(entry[0]), {"pivot":Vector2.ZERO, "target":Vector2.ZERO, "angle":0.0})
		output += _transform_source(point, transform) * float(entry[1])
	return output

static func _master_layout(meta: Dictionary) -> Dictionary:
	var id := str(meta.id)
	if _mesh_layouts.has(id): return _mesh_layouts[id]
	var r: Array = meta["source_bounds"]
	var bounds := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var step := maxf(20.0, float(meta.get("mesh_step", 40.0)))
	var columns := maxi(1, ceili(bounds.size.x / step))
	var rows := maxi(1, ceili(bounds.size.y / step))
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	var weights: Array = []
	var canvas := _v(meta["canvas"])
	for row: int in range(rows + 1):
		for column: int in range(columns + 1):
			var point := bounds.position + bounds.size * Vector2(float(column) / columns, float(row) / rows)
			points.append(point)
			uv.append(point / canvas)
			weights.append(_master_weights(meta, point))
	var indices := PackedInt32Array()
	for row: int in range(rows):
		for column: int in range(columns):
			var first := row * (columns + 1) + column
			indices.append_array(PackedInt32Array([first, first + 1, first + columns + 2, first, first + columns + 2, first + columns + 1]))
	var layout := {"points":points, "uv":uv, "weights":weights, "indices":indices, "columns":columns, "rows":rows}
	_mesh_layouts[id] = layout
	return layout

static func _master_bounds(meta: Dictionary, pose: Dictionary, scale: float) -> Rect2:
	# Pose containment is a conservative source boundary, never a per-frame scale.
	var layout := _master_layout(meta)
	var foot := _v(meta["source_foot"])
	var bounds := Rect2()
	var first := true
	var columns: int = layout.columns
	var rows: int = layout.rows
	for row: int in range(rows + 1):
		for column: int in range(columns + 1):
			if row != 0 and row != rows and column != 0 and column != columns: continue
			var index := row * (columns + 1) + column
			var point := (_deform_source(layout.points[index], layout.weights[index], pose.transforms) - foot) * scale
			if first: bounds = Rect2(point, Vector2.ZERO); first = false
			else: bounds = bounds.expand(point)
	return bounds

static func _master_state(meta: Dictionary, clip: String, progress: float, body_height: float) -> Dictionary:
	var pose := _master_pose(meta, clip, progress)
	var foot := _v(meta["source_foot"])
	var scale := body_height / maxf(1.0, float(meta["source_body_height"]))
	var joints: Dictionary = {}
	var native_joints: Dictionary = {}
	for name: String in pose.joints_source:
		joints[name] = (pose.joints_source[name] - foot) * scale
		native_joints[name] = (pose.joints_source[name] - foot) * 100.0 / maxf(1.0, float(meta["source_body_height"]))
	var feet: Array[Vector2] = []
	for point: Variant in meta.get("feet", [meta["source_foot"]]): feet.append((_v(point) - foot) * scale)
	var bounds := _master_bounds(meta, pose, scale)
	var weapon_tip := _v(meta.get("weapon_tip", meta["source_foot"]))
	var weapon_transform: Dictionary = pose.transforms.get("weapon", {})
	if not weapon_transform.is_empty(): weapon_tip = _transform_source(weapon_tip, weapon_transform)
	return {"ready":true, "id":meta.id, "clip":pose.clip, "phase":pose.phase, "pose_phase":pose.phase, "confirm_held":pose.confirm_held,
		"source_kind":"single_original_master_continuous_weighted_mesh", "source_path":meta.source_path, "representation":"hd_mesh_illustration", "body_height":body_height,
		"body_height_unit":100.0, "source_body_height":meta.source_body_height, "source_foot":foot, "source_bounds":meta.source_bounds,
		"joints":joints, "joints_native":native_joints, "angles":pose.angles, "joint_count":joints.size(), "part_count":1, "active_part_count":1, "skin_bone_count":meta.bones.size(), "keyframe_count":0, "animation_type":"continuous_skinning",
		"bounds":bounds, "max_extent":Vector2(maxf(absf(bounds.position.x), absf(bounds.end.x)), maxf(absf(bounds.position.y), absf(bounds.end.y))),
		"feet":feet, "root_anchor":Vector2.ZERO, "head_anchor":joints.get("head", Vector2.ZERO), "weapon_tip":(weapon_tip - foot) * scale,
		"weapon_ground_contact":(_v(meta.get("weapon_ground", meta["source_foot"])) - foot) * scale, "face_variant":0,
		"mesh_vertex_count":_master_layout(meta).points.size(), "mesh_triangle_count":_master_layout(meta).indices.size() / 3, "surface_count":1, "character_copies":1}

static func _master_mesh(meta: Dictionary, clip: String, progress: float) -> ArrayMesh:
	var timing := _master_phase(clip, progress)
	var phase: float = .55 if timing.clip == "confirm" and timing.phase >= .55 else float(timing.phase)
	# Render at 120 phase samples per cycle (~160fps at the 160BPM two-beat dance).
	var quantized := roundf(phase * 120.0) / 120.0
	var key := str(meta.id) + "/" + str(timing.clip) + "/" + str(quantized)
	if _mesh_pose_cache.has(key): return _mesh_pose_cache[key]
	var layout := _master_layout(meta)
	var pose := _master_pose(meta, timing.clip, quantized)
	var foot := _v(meta["source_foot"])
	var unit_scale := 100.0 / maxf(1.0, float(meta["source_body_height"]))
	var vertices := PackedVector3Array()
	for index: int in range(layout.points.size()):
		var point := (_deform_source(layout.points[index], layout.weights[index], pose.transforms) - foot) * unit_scale
		vertices.append(Vector3(point.x, point.y, 0.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = layout.uv
	arrays[Mesh.ARRAY_INDEX] = layout.indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_pose_cache[key] = mesh
	_mesh_pose_order.append(key)
	while _mesh_pose_order.size() > MESH_POSE_CACHE_LIMIT:
		_mesh_pose_cache.erase(_mesh_pose_order.pop_front())
	return mesh

static func _draw_master(canvas: CanvasItem, meta: Dictionary, clip: String, progress: float, facing: int, tint: Color, body_height: float) -> void:
	var texture := _source_texture(str(meta.source_path))
	if texture == null: return
	var scale := body_height / 100.0
	var transform := Transform2D(Vector2(scale * facing, 0.0), Vector2(0.0, scale), Vector2.ZERO)
	canvas.draw_mesh(_master_mesh(meta, clip, progress), texture, transform, tint)

static func get_master_metadata(id: String) -> Dictionary:
	_load()
	return _characters.get(id, {}).duplicate(true)

static func get_cache_state() -> Dictionary:
	return {"master_layouts":_mesh_layouts.size(), "pose_meshes":_mesh_pose_cache.size(), "pose_mesh_limit":MESH_POSE_CACHE_LIMIT, "source_textures":_source_textures.size()}
