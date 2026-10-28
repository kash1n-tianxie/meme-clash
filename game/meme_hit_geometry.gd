extends RefCounted
## Meme-asset geometry adapter, NOT official BVN playable-character hitbox data.
## Retains the caller's upstream timing, HitVO, damage, guard, hitGap and resource rules.
## Upstream 891f5776dbdf3cbf40919e27aa8d6e77a5f66c97:
## FighterMC.as:496-535 finds current named hit display objects with getBounds;
## FighterCtrler.as:501-543 associates each area with its existing HitVO;
## FighterCtrler.as:577-603 mirrors and translates resource-local rectangles.
## This adapter substitutes OUR rendered articulated part silhouettes for those areas.
## It never changes frame eligibility and never turns cosmetic skill FX into an AOE.

const Pixel := preload("res://game/pixel_fighter.gd")
const Timeline := preload("res://game/bvn_action_timeline.gd")
const SOURCE_SCALE := 1.6
const ALPHA_THRESHOLD := 38.0 / 255.0
const RASTER_DENSITY := 2.0 # Half a native pixel; two world px at the current 4x rigs.
const ATTACK_CLIPS := ["attack1","attack2","attack3","sweep","launcher","air_light","air_skill","air_slam","skill1","skill2","skill3","super","super_up","super_down","air_super"]
## Authored pose registration from Fighter._normal_pose_progress, not new combat timing.
## Source active intervals [2,4)/[4,6)/[4,6) span these interpolated art phases.
const NORMAL_ACTIVE_PHASES := {"attack1":Vector2(.429,.714),"attack2":Vector2(.444,.667),"attack3":Vector2(.455,.636)}
static var _rig_cache: Dictionary = {}
static var _image_cache: Dictionary = {}
static var _outline_cache: Dictionary = {}
static var _move_bounds_cache: Dictionary = {}

## Pure state-free sample. origin/body_height are WORLD pixels, already scaled from BVN.
## active and no_box MUST come from the real action timeline; the defaults are for QA only.
## Result shapes contain convex/concave source-alpha polygons and a broad-phase area.
## Do NOT use bounds alone as the collision: call intersect_body to reject empty AABB corners.
static func sample(id: String, clip: String, progress: float, body_height: float = 0.0, facing: int = 1, origin: Vector2 = Vector2.ZERO, active: bool = true, no_box: bool = false) -> Dictionary:
	var meta := _rig(id)
	if meta.is_empty(): return {"ready":false,"shapes":[],"bounds":Rect2()}
	# Fighter.pixel_animation_state maps its air bisha to the authored super clip.
	var visual := Pixel.get_pose_state(id,"super" if clip == "air_super" else clip,progress)
	if not visual.get("ready",false): return {"ready":false,"shapes":[],"bounds":Rect2()}
	var p: Dictionary = visual["pose"]
	var actual_clip: String = p["clip"]
	var rig: Dictionary = meta["rig"]
	var height := body_height if body_height > 0 else float(rig["world_height"])
	var scale := height / float(rig["native_height"])
	var sign_x := -1 if facing < 0 else 1
	var parts := _attack_parts(meta,p)
	# Source-specific branches reuse the painted-part sampler. Only the caller's
	# real source gate opens damage eligibility; art metadata supplies no timing.
	var attack_art: bool=actual_clip in ATTACK_CLIPS or bool(meta["clips"].get(actual_clip,{}).get("attack_visual",false))
	var shapes: Array[Dictionary] = []
	var bounds := Rect2()
	var anchor := origin
	var anchor_key := "weapon_tip" if id in ["rio","worker"] else ("shoe_tip" if id == "shark" else "paw_tip")
	var local_anchor: Vector2 = visual[anchor_key] * (height / float(rig["world_height"]))
	anchor += Vector2(local_anchor.x * sign_x,local_anchor.y)
	# Projectile spawn/counter may use the same real anchor, but has no melee geometry.
	if active and not no_box and attack_art:
		for part: Dictionary in parts:
			for native_polygon: PackedVector2Array in _part_outlines(meta,part):
				var polygon := PackedVector2Array()
				for vertex: Vector2 in native_polygon:
					var point: Vector2 = (vertex - part["pivot"] * part["size"]).rotated(part["angle"]) + part["at"]
					polygon.append(origin + Vector2(point.x * sign_x,point.y) * scale)
				if polygon.size() < 3: continue
				var area := polygon_bounds(polygon)
				shapes.append({"part":part["name"],"variant":part["variant"],"polygon":polygon,"area":area})
				bounds = area if shapes.size() == 1 else bounds.merge(area)
	var npc_rect := Rect2()
	if actual_clip in ["attack1","attack2","attack3"]:
		var local := Timeline.normalized_hit_rect(int(actual_clip.trim_prefix("attack")),height,sign_x)
		npc_rect = Rect2(origin + local.position,local.size)
	return {"ready":true,"id":id,"clip":actual_clip,"progress":progress,"active":active and not no_box and attack_art,"no_box":no_box,"shapes":shapes,"bounds":bounds,"anchor":anchor,"body_height":height,"origin":origin,"facing":sign_x,"source_scale":SOURCE_SCALE,"source_npc_audit_rect":npc_rect,"source_kind":"meme_rendered_part_silhouette","geometry_resolution_world":scale / RASTER_DENSITY,"part_names":parts.map(func(part: Dictionary) -> String: return part["name"])}

## Narrow-phase actual silhouette/body intersection. One transaction per attacker/target,
## even if several pieces touch: retain source hitGap and source pair-snapshot ordering.
static func intersect_body(geometry: Dictionary, target: Rect2) -> Dictionary:
	if target.size.x <= 0 or target.size.y <= 0: return {"hit":false}
	var target_polygon := PackedVector2Array([target.position,Vector2(target.end.x,target.position.y),target.end,Vector2(target.position.x,target.end.y)])
	var best: Dictionary = {"hit":false}
	var best_distance := INF
	var anchor: Vector2 = geometry.get("anchor",target.get_center())
	for shape: Dictionary in geometry.get("shapes",[]):
		if not (shape["area"] as Rect2).intersects(target): continue
		var intersections := Geometry2D.intersect_polygons(shape["polygon"],target_polygon)
		for polygon: PackedVector2Array in intersections:
			if polygon.size() < 3: continue
			# A triangle centroid remains INSIDE the overlap, unlike a concave AABB centre.
			var indices := Geometry2D.triangulate_polygon(polygon)
			for i in range(0,indices.size(),3):
				var point := (polygon[indices[i]] + polygon[indices[i+1]] + polygon[indices[i+2]]) / 3.0
				var distance := point.distance_squared_to(anchor)
				if distance < best_distance:
					best_distance = distance
					best = {"hit":true,"part":shape["part"],"area":shape["area"],"rect":polygon_bounds(polygon),"contact":point,"intersection":polygon}
	return best

## Prediction envelope for source AI/checkers only, never a damaging AOE.
## NPC normals use their real source-frame-to-art map; other actions use rig registration.
## Cache stays local/right-facing: origin and facing never expand the cache.
static func move_bounds(id: String, clip: String, body_height: float = 0.0, facing: int = 1, origin: Vector2 = Vector2.ZERO, no_box: bool = false) -> Rect2:
	var key := "%s/%s/%.4f/%s" % [id,clip,body_height,no_box]
	if not _move_bounds_cache.has(key):
		var local := Rect2()
		var found := false
		var phases := contact_phase_range(id,clip)
		for i in range(25):
			var frame := sample(id,clip,lerpf(phases.x,phases.y-.00001,float(i)/24.0),body_height,1,Vector2.ZERO,true,no_box)
			if frame["shapes"].is_empty(): continue
			local = local.merge(frame["bounds"]) if found else frame["bounds"]
			found = true
		_move_bounds_cache[key] = local
	var result: Rect2 = _move_bounds_cache[key]
	if result.size == Vector2.ZERO: return Rect2()
	if facing < 0: result.position.x = -result.end.x
	result.position += origin
	return result

static func cache_stats() -> Dictionary:
	return {"rigs":_rig_cache.size(),"images":_image_cache.size(),"outlines":_outline_cache.size(),"move_envelopes":_move_bounds_cache.size()}

static func contact_phase_range(id: String, clip: String) -> Vector2:
	var name: String = "super" if clip == "air_super" else Pixel._clip_name(clip)
	return NORMAL_ACTIVE_PHASES.get(name,Pixel.contact_phases(id,name))

static func world_rect_to_source(rect: Rect2) -> Rect2:
	return Rect2(rect.position / SOURCE_SCALE,rect.size / SOURCE_SCALE)

static func polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty(): return Rect2()
	var result := Rect2(polygon[0],Vector2.ZERO)
	for point: Vector2 in polygon: result = result.expand(point)
	return result

static func clear_cache() -> void:
	_rig_cache.clear(); _image_cache.clear(); _outline_cache.clear(); _move_bounds_cache.clear()

static func _vec(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))

static func _rig(id: String) -> Dictionary:
	if _rig_cache.has(id): return _rig_cache[id]
	var path := "res://assets/pixel/%s.rig.json" % id
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary: _rig_cache[id] = parsed; return parsed
	return {}

static func _part(name: String, size: Vector2, pivot: Vector2, at: Vector2, angle: float, variant: bool = false, crop: Rect2 = Rect2(0,0,1,1)) -> Dictionary:
	return {"name":name,"size":size,"pivot":pivot,"at":at,"angle":angle,"variant":variant,"crop":crop}

## Same transforms as Pixel.draw_fighter, Pixel._arm/_variant_wrist/_draw_shark.
## Selection is the striking limb/prop, never the character's entire card/body rectangle.
static func _attack_parts(meta: Dictionary, p: Dictionary) -> Array[Dictionary]:
	var id: String = meta["id"]
	var rig: Dictionary = meta["rig"]
	var clip: String = p["clip"]
	var strikers: Array=meta["clips"].get(clip,{}).get("striking_parts",[])
	var result: Array[Dictionary] = []
	if id == "shark":
		result.append(_part("foot_front",Vector2(21,12),Vector2(.45,1),p["front_foot"]+Vector2(13,0),0))
		if clip in ["skill2","skill3","super","super_up","super_down"] or "middle_shoe" in strikers:
			result.append(_part("foot_middle",Vector2(21,12),Vector2(.45,1),p.get("middle_foot",Vector2.ZERO),0))
		if clip in ["skill2","skill3","super","super_up","super_down"] or "back_shoe" in strikers:
			result.append(_part("foot_back",Vector2(21,12),Vector2(.45,1),p["back_foot"]+Vector2(-14,0),0))
		return result
	var angle := deg_to_rad(float(p["torso"]))
	var hip: Vector2 = Vector2(0,-float(rig["thigh"])-float(rig["shin"])-float(rig["foot"][1])+2)+p["hip"]
	var waist: Vector2 = hip - Vector2(0,float(rig["pelvis"][1])*.35)
	var shoulder: Vector2 = waist + Vector2(float(rig["shoulder"]),-float(rig["torso"][1])+5).rotated(angle)
	var elbow: Vector2 = shoulder + Vector2(0,float(rig["upper"])).rotated(deg_to_rad(float(p["front_upper"]))+angle*.35)
	var wrist: Vector2 = elbow + Vector2(0,float(rig["lower"])).rotated(deg_to_rad(float(p["front_lower"]))+angle*.35)
	var variant := int(p["body_variant"])
	var integrated_arms := variant >= 0 and bool(meta.get("variants_include_arms",id in ["cat","worker","chicken"]))
	if integrated_arms: wrist = Pixel._variant_wrist(meta,p,waist,angle)
	if id == "rio":
		var grip := _vec(rig.get("weapon_grip_uv",[.12,.84]))
		# Exclude rear handle: damage follows the painted blade/guard, not empty hilt space.
		result.append(_part("weapon",_vec(rig["weapon"]),grip,wrist,Pixel._rio_weapon_angle(meta,p,wrist),false,Rect2(grip.x,0,1.0-grip.x,1)))
		return result
	if id == "worker":
		result.append(_part("weapon",_vec(rig["weapon"]),Vector2(.5,.03),wrist,deg_to_rad(float(p["weapon"])*.55)))
		return result
	if clip == "sweep":
		result.append(_part("foot_front",_vec(rig["foot"]),Vector2(.45,1),p["front_foot"],deg_to_rad(float(p.get("foot_front_angle",0)))))
	elif integrated_arms:
		var marks: Dictionary = {"cat":[Vector2(.86,.84),Vector2(.84,.43),Vector2(.66,.85),Vector2(.88,.47)],"chicken":[Vector2(.83,.69),Vector2(.89,.16),Vector2(.72,.78),Vector2(.90,.25)]}
		var mark: Vector2 = marks[id][mini(variant,3)]
		var crop := Rect2(mark-Vector2(.18,.22),Vector2(.36,.44)).intersection(Rect2(0,0,1,1))
		result.append(_part(["torso_low","torso_rise","torso_slam","torso_recoil"][mini(variant,3)],_vec(rig["torso"])*Vector2(1.4,1),Vector2(.5,1),waist,angle*.7,true,crop))
	else:
		var direction: Vector2 = wrist-elbow
		# Distal forearm/painted paw: the source lower limb includes the hand end-cap.
		result.append(_part("lower_front",Vector2(float(rig.get("arm_width",7))+1,direction.length()+2),Vector2(.5,.07),elbow,direction.angle()-PI/2,false,Rect2(0,.40,1,.60)))
	if id == "cat" and (clip in ["skill1","super","super_up"] or "back_paw" in strikers) and not integrated_arms:
		var back_shoulder: Vector2 = waist+Vector2(-float(rig["shoulder"]),-float(rig["torso"][1])+5).rotated(angle)
		var back_elbow: Vector2 = back_shoulder+Vector2(0,float(rig["upper"])).rotated(deg_to_rad(float(p["back_upper"]))+angle*.35)
		var back_wrist: Vector2 = back_elbow+Vector2(0,float(rig["lower"])).rotated(deg_to_rad(float(p["back_lower"]))+angle*.35)
		var back_direction: Vector2 = back_wrist-back_elbow
		result.append(_part("lower_back",Vector2(float(rig.get("arm_width",7))+1,back_direction.length()+2),Vector2(.5,.07),back_elbow,back_direction.angle()-PI/2,false,Rect2(0,.40,1,.60)))
	if id == "chicken":
		if clip == "skill3":
			# Shoulder tackle: use painted front half, not a square extending beyond the plush body.
			result.append(_part("torso",_vec(rig["torso"]),Vector2(.5,1),waist,angle,false,Rect2(.58,0,.42,.8)))
		elif not clip in ["skill1","super","super_up"] or float(p["phase"]) <= .44:
			result.append(_part("weapon",_vec(rig["weapon"]),Vector2(.5,.5),wrist+Vector2(2,0),0))
	return result

## Cache the visible source alpha contour at the part's rendered native dimensions.
## Source_parts exclusion is identical to the renderer; neighbour fragments never hit.
static func _part_outlines(meta: Dictionary, part: Dictionary) -> Array[PackedVector2Array]:
	# Bone length is mathematically fixed. Quantize only its cache key to eliminate
	# float roundoff per animation pose; the draw/hit transform itself stays exact.
	var stable_size: Vector2 = (part["size"] as Vector2).snapped(Vector2(.001,.001))
	var key := "%s/%s/%s/%s/%s" % [meta["id"],part["name"],part["variant"],stable_size,part["crop"]]
	if _outline_cache.has(key): return _outline_cache[key]
	var result: Array[PackedVector2Array] = []
	var group: Dictionary = meta["variants"] if part["variant"] else meta["parts"]
	if not group["parts"].has(part["name"]): return result
	var info: Dictionary = group["parts"][part["name"]]
	var source := _rect(info["rect"])
	var path: String = meta["variants_texture"] if part["variant"] else meta["parts_texture"]
	if not _image_cache.has(path):
		var texture := load(path) as Texture2D
		if not texture: return result
		_image_cache[path] = texture.get_image()
	var image: Image = _image_cache[path]
	var size: Vector2 = part["size"]
	var raster_size := Vector2i(maxi(1,int(ceil(size.x*RASTER_DENSITY))),maxi(1,int(ceil(size.y*RASTER_DENSITY))))
	var mask := BitMap.new()
	mask.create(raster_size)
	var source_parts: Array = info.get("source_parts",[])
	var crop: Rect2 = part["crop"]
	for y in range(raster_size.y):
		for x in range(raster_size.x):
			var uv := Vector2((x+.5)/raster_size.x,(y+.5)/raster_size.y)
			if not crop.has_point(uv): continue
			if bool(info.get("flip_y",false)): uv.y = 1.0-uv.y
			var source_point := source.position+uv*source.size
			var belongs := source_parts.is_empty()
			for values: Array in source_parts:
				if _rect(values).has_point(source_point): belongs = true; break
			if belongs and image.get_pixel(int(source_point.x),int(source_point.y)).a > ALPHA_THRESHOLD:
				mask.set_bit(x,y,true)
	for outline: PackedVector2Array in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,raster_size),.25):
		if outline.size() < 3: continue
		var polygon := PackedVector2Array()
		for vertex: Vector2 in outline: polygon.append(vertex*size/Vector2(raster_size))
		result.append(polygon)
	_outline_cache[key] = result
	return result

static func _rect(values: Array) -> Rect2:
	return Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3]))
