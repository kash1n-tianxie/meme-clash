extends Control
## Original v034 cel UI. One registered body, no old-character art fallback,
## shaders, whole-image wobble, or gameplay clock. Native atlas pixels retained.
const Data = preload("res://game/data.gd")
const Full = preload("res://game/bvn_full_pose_renderer.gd")
static var _metadata: Dictionary = {}
static var _textures: Dictionary = {}
var fighter_id: String = ""
var clip: String = "selection"
var face_only: bool = false
var phase: float = 0.0
var clock_override: float = -1.0
var reduced_motion: bool = false
var performance_state: String = "loop"
var _local_clock: float = 0.0
var _reaction_left: float = 0.0
var _held_clock: float = 0.0

static func manifest(id: String) -> Dictionary:
	if id in ["cat","shark"]:
		return Full._manifest(id) if Full.style_overlay_ready(id) else {}
	if id not in Data.STAGED_V034_IDS: return {}
	if _metadata.has(id): return _metadata[id]
	var path: String = str(Data.ROSTER[id].manifest)
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or str(parsed.get("fighter_id","")) != id: return {}
	_metadata[id] = parsed
	return parsed

static func supports(id: String) -> bool:
	return not manifest(id).is_empty()

static func clear_cache() -> void:
	_metadata.clear()
	_textures.clear()

static func sequence(id: String, mode: String) -> Array:
	var meta: Dictionary = manifest(id)
	var ui: Dictionary = meta.get("ui",{})
	var registered: Array = ui.get("sequences",{}).get(mode,[])
	return registered if not registered.is_empty() else [str(ui.get("portrait_pose",""))]

static func pose(id: String, mode: String, clock: float, only_face: bool = false) -> Dictionary:
	var meta: Dictionary = manifest(id)
	var ui: Dictionary = meta.get("ui",{})
	var frames: Array = sequence(id,mode)
	if meta.is_empty() or frames.is_empty(): return {}
	var index: int = 0 if only_face else posmod(floori(maxf(clock,0.0)*float(ui.get("fps",6.0))),frames.size())
	var key: String = str(ui.get("portrait_pose","")) if only_face else str(frames[index])
	var cel: Dictionary = meta.get("frames",{}).get(key,{})
	if not bool(cel.get("ready",false)): return {}
	var rect: Array = cel.get("rect",[])
	var pivot: Array = cel.get("pivot",[])
	if rect.size()!=4 or pivot.size()!=2 or float(cel.get("body_reference_height",0.0))<=0: return {}
	var region: Rect2 = Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3]))
	var source: Rect2 = region
	if only_face:
		var face: Array = ui.get("face_rect",[])
		if face.size()!=4: return {}
		source = Rect2(float(face[0]),float(face[1]),float(face[2]),float(face[3]))
		if str(ui.get("face_rect_space","cel")) != "atlas": source.position += region.position
		if not region.encloses(source) or not source.has_area(): return {}
	var atlas: String = str(meta.get("sheets",{}).get(str(cel.get("sheet","")),{}).get("path",cel.get("atlas","")))
	return {"ready":not atlas.is_empty(),"fighter_id":id,"pose_id":key,"atlas":atlas,"region":source,"full_region":region,"pivot":Vector2(float(pivot[0]),float(pivot[1])),"body_reference_height":float(cel.body_reference_height),"frame_index":index,"sequence_count":frames.size(),"only_face":only_face}

static func fit_bounds(id: String, mode: String) -> Rect2:
	var bounds: Rect2 = Rect2()
	var meta: Dictionary = manifest(id)
	for key: Variant in sequence(id,mode):
		var cel: Dictionary = meta.get("frames",{}).get(str(key),{})
		var rect: Array = cel.get("rect",[])
		var pivot: Array = cel.get("pivot",[])
		var height: float = float(cel.get("body_reference_height",0.0))
		if not bool(cel.get("ready",false)) or rect.size()!=4 or pivot.size()!=2 or height<=0: continue
		var local: Rect2 = Rect2(-Vector2(float(pivot[0]),float(pivot[1]))/height,Vector2(float(rect[2]),float(rect[3]))/height)
		bounds = bounds.merge(local) if bounds.has_area() else local
	return bounds

static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		if not ResourceLoader.exists(path): return null
		var resource: Variant = load(path)
		if not resource is Texture2D: return null
		_textures[path] = resource
	return _textures[path] as Texture2D

static func destination(id: String, mode: String, target: Rect2, frame: Dictionary) -> Rect2:
	var source: Rect2 = frame.region
	if bool(frame.only_face):
		var scale: float = minf(target.size.x/source.size.x,target.size.y/source.size.y)
		var extent: Vector2 = source.size*scale
		return Rect2(target.position+(target.size-extent)*.5,extent)
	var bounds: Rect2 = fit_bounds(id,mode)
	if not bounds.has_area(): return Rect2()
	var display_height: float = minf(target.size.x/bounds.size.x,target.size.y/bounds.size.y)
	var origin: Vector2 = target.position+(target.size-bounds.size*display_height)*.5-bounds.position*display_height
	var unit: float = display_height/float(frame.body_reference_height)
	return Rect2(origin-Vector2(frame.pivot)*unit,source.size*unit)

static func draw_portrait(canvas: CanvasItem, id: String, target: Rect2, mode: String = "cutin", clock: float = 0.0, only_face: bool = false, tint: Color = Color.WHITE) -> bool:
	var frame: Dictionary = pose(id,mode,clock,only_face)
	if not frame.get("ready",false): return false
	var image: Texture2D = texture(str(frame.atlas))
	if image==null: return false
	var drawn: Rect2 = destination(id,mode,target,frame)
	if not drawn.has_area(): return false
	canvas.draw_texture_rect_region(image,drawn,frame.region,tint)
	return true

func configure(id: String, mode: String = "selection", only_face: bool = false) -> void:
	fighter_id = id
	clip = mode
	face_only = only_face
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_meta("character_id",id)
	set_meta("face_only",only_face)
	set_meta("representation","original_registered_v034_cels")

func _clock() -> float:
	if performance_state=="confirm" and _reaction_left>0.0: return _held_clock
	return 0.0 if reduced_motion else maxf(0.0,clock_override if clock_override>=0.0 else _local_clock)+phase

func _process(delta: float) -> void:
	_local_clock += delta
	_reaction_left = maxf(0.0,_reaction_left-delta)
	if _reaction_left==0.0: performance_state="loop"
	queue_redraw()

func react(kind: String, seconds: float = .24) -> void:
	_held_clock = _clock()
	performance_state = kind
	_reaction_left = maxf(seconds,.01)

func set_base_clip(mode: String) -> void:
	clip = mode

func ground_anchor() -> Vector2:
	var frame: Dictionary = pose(fighter_id,clip,_clock(),false)
	if not frame.get("ready",false): return Vector2(size.x*.5,size.y)
	var rect: Rect2 = destination(fighter_id,clip,Rect2(Vector2.ZERO,size),frame)
	return rect.position+Vector2(frame.pivot)*rect.size.x/Vector2(frame.region.size).x

func get_pose_state() -> Dictionary:
	var frame: Dictionary = pose(fighter_id,clip,_clock(),face_only)
	return {"fighter_id":fighter_id,"ready":frame.get("ready",false),"pose_id":frame.get("pose_id",""),"clip":clip,"frame_index":frame.get("frame_index",0),"sequence_count":frame.get("sequence_count",0),"foot_anchor":ground_anchor(),"face_only":face_only,"representation":"original_registered_v034_cels","motion_zone_count":0,"body_count":1 if frame.get("ready",false) and not face_only else 0}

func _draw() -> void:
	draw_portrait(self,fighter_id,Rect2(Vector2.ZERO,size),clip,_clock(),face_only)
