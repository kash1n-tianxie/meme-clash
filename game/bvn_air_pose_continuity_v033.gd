extends RefCounted
## Existing-cel display registration only. This does not create inverted art.
## One scalar per weak actor; no source bundle/vertex history or extra surface.
const RETURN_SECONDS: float = 0.10
const MAX_HEIGHT_FRACTION: float = 0.18
static var _actors: Dictionary = {}

static func clear() -> void:
	_actors.clear()

static func eligible(id: String, context: Dictionary, pose: Dictionary) -> bool:
	if id != "rio" or bool(context.get("grounded",true)): return false
	if str(context.get("state","")) not in ["hurt","launch","juggle","slam"]: return false
	if not bool(context.get("source_visible",context.get("visible",true))): return false
	var record: Dictionary = context.get("reaction_identity",{})
	if str(record.get("outcome","")) != "hit" or int(record.get("serial",-1)) < 1: return false
	# The source-owned Cat capture/throw paths have their own exact paw/chest
	# registration. Never mix a second display registration into those paths.
	if str(record.get("binding_id","")) in ["cat:super","cat:super_down"]: return false
	var pair: Dictionary = context.get("reaction_source_pair_v029",{})
	if bool(pair.get("active",false)): return false
	if bool(pose.get("reserved_contact_holder",false)): return false
	var key: String = str(pose.get("pose_id",""))
	if key == "v29rx_rio_15": return false
	if not (key.begins_with("v32air_rio_") or key in ["v29rx_rio_12","v29rx_rio_13","v29rx_rio_14","v29rx_rio_16","v29rx_rio_17"]): return false
	var raw: Variant = pose.get("anchors",{}).get("anatomy_hips",[])
	return raw is Array and raw.size() >= 2 and float(pose.get("body_reference_height",0.0)) > 0.0

static func _remaining(memory: Dictionary, clock: float) -> float:
	var t: float = clampf((clock-float(memory.get("started",clock)))/RETURN_SECONDS,0.0,1.0)
	return float(memory.get("from_offset",0.0))*(1.0-t*t*(3.0-2.0*t))

static func sample(id: String, context: Dictionary, pose: Dictionary, height: float, memory: Dictionary = {}) -> Dictionary:
	if height <= 0.0 or not eligible(id,context,pose): return {"offset":Vector2.ZERO,"next":{}}
	var clock: float = float(context.get("visual_clock",0.0))
	var serial: int = int(context.get("reaction_identity",{}).get("serial",-1))
	var key: String = str(pose.get("pose_id",""))
	var raw: Array = pose["anchors"]["anatomy_hips"]
	var hip: float = float(raw[1])*height/float(pose["body_reference_height"])
	if not is_finite(clock) or not is_finite(hip): return {"offset":Vector2.ZERO,"next":{}}
	var next: Dictionary = memory.duplicate()
	var fresh: bool = next.is_empty() or int(next.get("serial",-2)) != serial or clock < float(next.get("clock",clock)) or not is_equal_approx(float(next.get("height",height)),height)
	if fresh:
		next = {"serial":serial,"pose":key,"clock":clock,"height":height,"raw_hip":hip,"last_offset":0.0,"from_offset":0.0,"started":clock}
		return {"offset":Vector2.ZERO,"next":next}
	# Body, material and anchor queries of the same stopped source sample must
	# not consume this memory independently or decay by redraw wall time.
	if clock == float(next["clock"]) and key == str(next["pose"]):
		return {"offset":Vector2(0.0,float(next["last_offset"])),"next":next}
	var value: float = _remaining(next,clock)
	if key != str(next["pose"]):
		# Preserve the previously displayed pelvis only within the explicit
		# bound. Large orientation/anatomy changes stay visibly unresolved.
		value = clampf(float(next["raw_hip"])+float(next["last_offset"])-hip,-height*MAX_HEIGHT_FRACTION,height*MAX_HEIGHT_FRACTION)
		next["from_offset"] = value
		next["started"] = clock
	next.merge({"pose":key,"clock":clock,"raw_hip":hip,"last_offset":value},true)
	return {"offset":Vector2(0.0,value),"next":next}

static func offset_for_actor(actor: Variant, pose: Dictionary, context: Dictionary) -> Vector2:
	# This tiny ownership map is bounded by the two live fighters. Prune stale
	# weak owners before reusing instance IDs across matches.
	for old_key: int in _actors.keys():
		var reference: WeakRef = _actors[old_key]["actor"]
		if reference.get_ref() == null: _actors.erase(old_key)
	if actor == null: return Vector2.ZERO
	var key: int = int(actor.get_instance_id())
	var stored: Dictionary = _actors.get(key,{})
	var memory: Dictionary = stored.get("memory",{})
	var result: Dictionary = sample(str(actor.fighter_id),context,pose,float(actor.body_height),memory)
	if result["next"].is_empty():
		_actors.erase(key)
	else:
		var reference: WeakRef = stored.get("actor",null) as WeakRef
		if reference == null: reference = weakref(actor)
		_actors[key] = {"actor":reference,"memory":result["next"]}
	return result["offset"]
