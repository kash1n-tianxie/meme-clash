extends RefCounted
## Whole-body cels plus one locally deformable UV surface per fighter.
## Source cels still define the silhouette. Only presentation is interpolated;
## source clocks, HitVO, positions, freeze and damage are never advanced here.
const ROOT := "res://assets/fighters/v022/"
const STYLE_ROOT := "res://assets/fighters/v037/"
const IDS := ["rio","cat","worker","chicken","shark","notify","wojak"]
const ReactionIdentity = preload("res://game/bvn_reaction_identity_v028.gd")
const PoseTransitions = preload("res://game/bvn_pose_transitions_v028.gd")
const GPUWarmup = preload("res://game/bvn_gpu_warmup_v028.gd")
const SourceMotion = preload("res://game/bvn_motion.gd")
const AirPoseContinuity = preload("res://game/bvn_air_pose_continuity_v033.gd")
static var _manifests: Dictionary={}
static var _style_ready: Dictionary={}
static var _textures: Dictionary={}
static var _geometry_cache: Dictionary={}
static var _observer: Callable=Callable()
static var _mesh_cache: Dictionary={}
static var _stream_stats: Dictionary={"surface_builds":0,"vertex_updates":0,"attribute_updates":0,"frozen_vertex_skips":0,"unchanged_attribute_skips":0}
static var _gpu_warmup_ref: WeakRef
const GRID_X := 12
const GRID_Y := 18
const SPATIAL_WEIGHT_STRIDE: int = 7
static var _topology := PackedInt32Array()

static func _sample_frame(context: Dictionary) -> float:
	# The immutable source frame remains the integer collision frame. Sampling
	# its existing fractional clock avoids an extra 30 Hz visual quantization.
	return float(context.get("source_frame",0.0)) + (float(context.get("source_clock",0.0))*30.0 if bool(context.get("source_playing",true)) else 0.0)

static func _manifest(id: String) -> Dictionary:
	if _manifests.has(id):return _manifests[id]
	var path: String=("res://assets/fighters/v034/" if id in ["notify","wojak"] else ROOT)+id+".manifest.json"
	if not FileAccess.file_exists(path):return {}
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:return {}
	parsed=ReactionIdentity.merge_manifest(id,parsed)
	_style_ready[id]=false
	if id in ["cat","shark"]:
		var style_path: String=STYLE_ROOT+id+".style.json"
		var fragment: Variant=JSON.parse_string(FileAccess.get_file_as_string(style_path)) if FileAccess.file_exists(style_path) else null
		if fragment is Dictionary and _valid_style_overlay(id,parsed,fragment):
			# Replace only registered pixels/anchors and their shared UI metadata.
			# Source labels, bindings and every action/phase map remain untouched.
			for field: String in ["frames","sheets","ui"]:
				var merged: Dictionary=parsed.get(field,{}).duplicate()
				merged.merge(fragment[field],true)
				parsed[field]=merged
			_style_ready[id]=true
	_manifests[id]=parsed
	return parsed

## A partial fragment cannot switch only the body or only the menu to new art.
## This validates registration; native pixel/anatomy acceptance is separate.
static func _valid_style_overlay(id: String, meta: Dictionary, fragment: Dictionary) -> bool:
	if id not in ["cat","shark"] or str(fragment.get("fighter_id",""))!=id:return false
	if not fragment.get("ready",false) is bool or not fragment.get("ready",false):return false
	for field: String in ["frames","sheets","ui"]:
		if not fragment.get(field) is Dictionary or fragment[field].is_empty():return false
	var ui: Dictionary=fragment.ui
	if not ui.get("sequences") is Dictionary:return false
	var frames: Dictionary=meta.get("frames",{}).duplicate()
	frames.merge(fragment.frames,true)
	var sheets: Dictionary=meta.get("sheets",{}).duplicate()
	sheets.merge(fragment.sheets,true)
	var required: Array=[str(ui.get("portrait_pose",""))]
	required.append_array(fragment.frames.keys())
	for mode: String in ["selection","home","win","cutin"]:
		var sequence: Variant=ui.sequences.get(mode)
		if not sequence is Array or sequence.is_empty():return false
		required.append_array(sequence)
	for key: Variant in required:
		var frame: Variant=frames.get(str(key))
		if not frame is Dictionary or not bool(frame.get("ready",false)):return false
		if frame.get("rect",[]).size()!=4 or frame.get("pivot",[]).size()!=2 or float(frame.get("body_reference_height",0))<=0:return false
		var sheet: Dictionary=sheets.get(str(frame.get("sheet","")),{})
		var atlas: String=str(sheet.get("path",frame.get("atlas","")))
		if atlas.is_empty() or not (FileAccess.file_exists(atlas) or ResourceLoader.exists(atlas)):return false
	var portrait: Dictionary=frames[str(ui.portrait_pose)]
	var rect: Array=portrait.rect
	var region: Rect2=Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3]))
	var crop: Variant=ui.get("face_rect")
	if not crop is Array or crop.size()!=4:return false
	var face: Rect2=Rect2(float(crop[0]),float(crop[1]),float(crop[2]),float(crop[3]))
	if str(ui.get("face_rect_space","cel"))!="atlas":face.position+=region.position
	return region.has_area() and face.has_area() and region.encloses(face)

static func style_overlay_ready(id: String) -> bool:
	if id not in ["cat","shark"]:return false
	_manifest(id)
	return bool(_style_ready.get(id,false))

static func has_assets(id: String) -> bool:
	return not _manifest(id).get("frames",{}).is_empty()

static func clear_cache() -> void:
	_manifests.clear();_textures.clear();_geometry_cache.clear()
	_style_ready.clear()
	AirPoseContinuity.clear()
	# Canvas draw commands retain a mesh RID, not its RefCounted Resource. Live
	# canvases must keep their resources even while artwork metadata is reset.
	_prune_mesh_cache()
	ReactionIdentity.clear()
	PoseTransitions.reset()

static func _prune_mesh_cache() -> void:
	for key: String in _mesh_cache.keys():
		var entry: Dictionary=_mesh_cache[key]
		if (entry["canvas"] as WeakRef).get_ref()==null or (entry["actor"] as WeakRef).get_ref()==null:
			_mesh_cache.erase(key)

static func _retained_mesh(canvas: CanvasItem, actor: Variant, texture: Texture2D=null) -> ArrayMesh:
	_prune_mesh_cache()
	var key:=str(canvas.get_instance_id())+":"+str(actor.get_instance_id())
	if not _mesh_cache.has(key):
		_mesh_cache[key]={"canvas":weakref(canvas),"actor":weakref(actor),"mesh":ArrayMesh.new()}
	if texture!=null:_mesh_cache[key]["texture"]=texture
	return _mesh_cache[key]["mesh"] as ArrayMesh

static func set_draw_observer(observer: Callable=Callable()) -> void:
	_observer=observer

static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		var resource: Variant=load(path)
		if not resource is Texture2D:return null
		_textures[path]=resource
	return _textures[path]

static func texture_for_pose(pose: Dictionary) -> Texture2D:
	return _texture(str(pose.get("atlas",""))) if pose.get("ready",false) else null

static func render_stats(reset: bool=false) -> Dictionary:
	var result: Dictionary=_stream_stats.duplicate()
	result["retained_meshes"]=_mesh_cache.size()
	result["cached_cel_geometry"]=_geometry_cache.size()
	result["mode"]="retained_dynamic_vertex_attribute_regions"
	if reset:
		for key: String in _stream_stats:_stream_stats[key]=0
	return result

## Godot's native surface layout supplies the strides and offsets. Colors in
## ArrayMesh's ordinary COLOR channel are RGBA8; match its truncating packing
## exactly, including clamping HDR contact light to the original channel range.
static func _attribute_bytes(uv: PackedVector2Array,colors: PackedColorArray,format: int) -> PackedByteArray:
	var count:=uv.size()
	var stride:=RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
	var color_offset:=RenderingServer.mesh_surface_get_format_offset(format,count,Mesh.ARRAY_COLOR)
	var uv_offset:=RenderingServer.mesh_surface_get_format_offset(format,count,Mesh.ARRAY_TEX_UV)
	var bytes:=PackedByteArray();bytes.resize(stride*count)
	for index in range(count):
		var start:=index*stride
		var color: Color=colors[index]
		bytes[start+color_offset]=clampi(int(color.r*255.0),0,255)
		bytes[start+color_offset+1]=clampi(int(color.g*255.0),0,255)
		bytes[start+color_offset+2]=clampi(int(color.b*255.0),0,255)
		bytes[start+color_offset+3]=clampi(int(color.a*255.0),0,255)
		bytes.encode_float(start+uv_offset,uv[index].x)
		bytes.encode_float(start+uv_offset+4,uv[index].y)
	return bytes

## Retain the surface/index buffer for the canvas command's entire lifetime.
## Only its existing vertex/attribute regions change. No source clock or body
## sampling frequency changes, and an exactly frozen sample needs no upload.
static func update_retained_surface(mesh: ArrayMesh,descriptor: Dictionary,at: Vector2=Vector2.ZERO) -> void:
	var points: PackedVector2Array=descriptor["vertices"]
	var vertices:=PackedVector3Array();vertices.resize(points.size())
	var lower:=Vector2.INF;var upper: Vector2=-Vector2.INF
	for index in range(points.size()):
		var point: Vector2=points[index]+at
		vertices[index]=Vector3(point.x,point.y,0.0)
		lower=lower.min(point);upper=upper.max(point)
	var uv: PackedVector2Array=descriptor["uv"]
	var colors: PackedColorArray=descriptor["colors"]
	var stream: Dictionary=mesh.get_meta("v028_stream",{})
	if mesh.get_surface_count()==0:
		var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_TEX_UV]=uv
		arrays[Mesh.ARRAY_COLOR]=colors
		arrays[Mesh.ARRAY_INDEX]=descriptor["indices"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
		stream={"format":mesh.surface_get_format(0),"vertex_bytes":vertices.to_byte_array(),"uv":uv,"colors":colors}
		mesh.set_meta("v028_stream",stream)
		_stream_stats["surface_builds"]+=1
	else:
		var vertex_bytes:=vertices.to_byte_array()
		if stream.get("vertex_bytes",PackedByteArray())!=vertex_bytes:
			mesh.surface_update_vertex_region(0,0,vertex_bytes)
			stream["vertex_bytes"]=vertex_bytes
			_stream_stats["vertex_updates"]+=1
		else:_stream_stats["frozen_vertex_skips"]+=1
		if stream.get("uv",PackedVector2Array())!=uv or stream.get("colors",PackedColorArray())!=colors:
			mesh.surface_update_attribute_region(0,0,_attribute_bytes(uv,colors,int(stream["format"])))
			stream["uv"]=uv;stream["colors"]=colors
			_stream_stats["attribute_updates"]+=1
		else:_stream_stats["unchanged_attribute_skips"]+=1
	# Updating the buffer does not recompute ArrayMesh's original AABB. Supply
	# the actual current bounds so a turn, larger sword cel or caught pose can
	# never be culled using the first idle drawing's old rectangle.
	mesh.custom_aabb=AABB(Vector3(lower.x,lower.y,0.0),Vector3(upper.x-lower.x,upper.y-lower.y,.00001))

static func prewarm(id: String) -> void:
	var meta:=_manifest(id)
	var warmup: Node=_native_warmup()
	for sheet: String in meta.get("sheets",{}):
		var texture:=_texture(str(meta["sheets"][sheet]["path"]))
		if warmup!=null:warmup.add_texture(texture)
	var ocean_path: String="res://assets/fx/v037/shark/ocean-animation.png"
	if id=="shark" and ResourceLoader.exists(ocean_path) and warmup!=null:warmup.add_texture(_texture(ocean_path))

static func _native_warmup() -> Node:
	if DisplayServer.get_name()=="headless":return null
	var tree: SceneTree=Engine.get_main_loop() as SceneTree
	if tree==null:return null
	var warmup: Node=_gpu_warmup_ref.get_ref() if _gpu_warmup_ref!=null else null
	if warmup==null:
		warmup=GPUWarmup.new()
		_gpu_warmup_ref=weakref(warmup)
		tree.root.call_deferred("add_child",warmup)
	return warmup

static func _contact_selection(seq: Array, frame: float, duration: float, first: float, last: float, layout: Dictionary={}) -> Dictionary:
	if seq.size()<3 or first<0 or last<=first:return {"sequence":seq,"progress":clampf(frame/maxf(1,duration-1),0,1)}
	var prep:=clampi(int(layout.get("prepare",ceil(seq.size()*.25))),1,seq.size()-2)
	# Six new base cels reserve two real drawings for the recovery instead of
	# spending three on contact and holding only one through the whole tail.
	var active:=clampi(int(layout.get("active",2 if seq.size()==6 else ceil(seq.size()*.5))),1,seq.size()-prep-1)
	if frame<first:return {"sequence":seq.slice(0,prep),"progress":clampf(frame/maxf(1,first),0,1),"phase":"prepare"}
	if frame<last:return {"sequence":seq.slice(prep,prep+active),"progress":clampf((frame-first)/maxf(1,last-first),0,1),"phase":"contact"}
	return {"sequence":seq.slice(prep+active),"progress":clampf((frame-last)/maxf(1,duration-last-1),0,1),"phase":"recover"}

static func _exact_phase_selection(phases: Array, frame: float, actual_end: float=-1.0) -> Dictionary:
	var begin:=0.0
	for index in range(phases.size()):
		var phase: Dictionary=phases[index]
		var end:=float(phase["until"])
		var last_visible_recovery:=false
		# A source label can return before its archived authored span ends.
		# Finish only the last drawing-only recovery within that real runtime
		# count; anticipation, contact and cancel holds retain their exact frames.
		if index==phases.size()-1 and str(phase.get("phase",""))=="recover" and actual_end-1.0>begin:
			# The source's final label frame executes goto/idle immediately,
			# before drawing. Its final visible half-frame is count - 1.5.
			end=minf(end,actual_end-1.0)
			last_visible_recovery=true
		if frame<end:
			var span:=end-begin-(.5 if last_visible_recovery else 0.0)
			# Some real source returns leave only one visible half-frame of
			# final recovery. A one-frame minimum would hold its second-last
			# drawing until idle; keep the exact remaining recovery denominator.
			# Preparation and contact retain their previous one-frame behavior.
			var divisor:=maxf(.001,span) if last_visible_recovery else maxf(1.0,span)
			return {"sequence":phase["sequence"],"progress":clampf((frame-begin)/divisor,0.0,1.0),"phase":str(phase.get("phase","source_event"))}
		begin=end
	return {"sequence":phases.back()["sequence"],"progress":1.0,"phase":str(phases.back().get("phase","recover"))}

static func _skill_selection(spec: Dictionary, label: String, context: Dictionary) -> Dictionary:
	var seq: Array=spec.get("sequence",[]).duplicate()
	var label_info: Dictionary=spec.get("labels",{}).get(label,{})
	var duration:=maxf(1,float(context.get("source_frame_count",label_info.get("authored_span",1))))
	var frame:=_sample_frame(context)
	# Each real branch has its own clock. Long techniques can therefore pose
	# around their actual release/contact events rather than spreading drawings
	# uniformly across a miss, hit-confirm and finishing branch.
	var exact_phases: Array=spec.get("label_pose_phases",{}).get(label,[])
	if not exact_phases.is_empty():
		return _exact_phase_selection(exact_phases,frame,duration)
	var branch:=label!=str(spec.get("source_label",""))
	var branches: Dictionary=spec.get("branch_sequences",{})
	if not branches.is_empty():
		if not branch:seq=branches.get("entry",seq)
		else:
			for suffix: String in branches:
				if suffix!="entry" and label.ends_with(suffix):seq=branches[suffix];break
	elif branch:
		if label.ends_with("_HA") or label.ends_with("_CHK"):seq=seq.slice(maxi(0,int(seq.size()*.35)),maxi(1,int(seq.size()*.85)))
		elif label.ends_with("_TF"):seq=seq.slice(maxi(0,seq.size()-4))
		elif label.ends_with("_L"):seq=seq.slice(maxi(0,int(seq.size()*.4)),maxi(1,int(seq.size()*.75)))
		elif label.ends_with("_HIT"):seq=seq.slice(mini(3,maxi(0,seq.size()-3)))
	# Special contact/miss/landing sequences use only the actual branch clock.
	if branch:return {"sequence":seq,"progress":clampf(frame/maxf(1,duration-1),0,1),"phase":"source_branch"}
	var phases: Array=spec.get("pose_phases",[])
	if not phases.is_empty():
		var prior:=0.0
		for phase: Dictionary in phases:
			var until:=float(phase["until"])
			if frame<until:return {"sequence":phase["sequence"],"progress":clampf((frame-prior)/maxf(1,until-prior),0,1),"phase":str(phase.get("phase","source_event"))}
			prior=until
		return {"sequence":phases.back()["sequence"],"progress":1.0,"phase":"source_event"}
	var first:=INF;var last:=-INF
	for hit: Dictionary in spec.get("hit_regions",[]):
		var start:=float(hit.get("start",0));var end:=float(hit.get("end_exclusive",start))
		if start<duration and end>0:first=minf(first,maxf(0,start));last=maxf(last,minf(duration,end))
	for spawn: Dictionary in spec.get("spawn_events",[]):
		var event_frame:=float(spawn.get("frame",0))-float(spec.get("source_start_frame",0))
		if event_frame>=0 and event_frame<duration:first=minf(first,event_frame);last=maxf(last,minf(duration,event_frame+4))
	if first!=INF and last>first:return _contact_selection(seq,frame,duration,first,last,spec.get("phase_layout",{}))
	return {"sequence":seq,"progress":clampf(frame/maxf(1,duration-1),0,1),"phase":"source_hold"}

static func _sequence(meta: Dictionary, context: Dictionary) -> Dictionary:
	var victory: Dictionary=_victory_selection_v035(meta,context)
	if not victory.is_empty():return victory
	var override:=str(context.get("pose_override",context.get("pose_id","")))
	if not override.is_empty():
		if meta.get("frames",{}).has(override):return {"sequence":[override],"key":override,"progress":float(context.get("transition_progress",0.0)),"phase":str(context.get("transition_phase","visual"))}
		var explicit: Array=meta.get("base_sequences",{}).get(override,[])
		return {"sequence":explicit,"key":override,"progress":float(context.get("progress",0.0))}
	var ground_ko: Dictionary=_ground_ko_selection_v032(meta,context)
	if not ground_ko.is_empty():return ground_ko
	var roster_reaction: Dictionary=_roster_reaction_selection_v034(meta,context)
	if not roster_reaction.is_empty():return roster_reaction
	var reaction_pose: String=ReactionIdentity.pose_override_for(str(meta.get("fighter_id",context.get("fighter_id",""))),context)
	if not reaction_pose.is_empty() and meta.get("frames",{}).has(reaction_pose):
		return {"sequence":[reaction_pose],"key":"hurt:identity","progress":float(context.get("state_time",0.0)),"phase":"reaction"}
	var label:=str(context.get("current_label",context.get("source_label","站立")))
	var profile:=str(context.get("donor_profile_id",context.get("base_profile_id","")))
	var command:=str(context.get("command",""))
	var slot:=str(meta.get("command_slots",{}).get(command,""))
	if slot.is_empty():slot=str(meta.get("label_slots",{}).get(profile+":"+label,""))
	var progress:=clampf(float(context.get("progress",0.0)),0,1)
	var count:=float(context.get("source_frame_count",1.0))
	if count>1:progress=clampf(_sample_frame(context)/maxf(1.0,count-1),0,1)
	if not slot.is_empty() and meta.get("bindings",{}).has(slot):
		var spec: Dictionary=meta["bindings"][slot]
		var chosen:=_skill_selection(spec,label,context)
		chosen["key"]=slot+":"+label;chosen["slot"]=slot
		return chosen
	var key:=str(meta.get("label_base",{}).get(label,""))
	var state:=str(context.get("state",""))
	if state in ["juggle","launch","slam"]:key="air_hurt"
	elif state in ["down","getup","ko"]:key=state
	if key.is_empty():
		key=str(meta.get("label_base",{}).get(label.get_slice("_",0),""))
		if label.is_empty():key="idle"
	if key=="guard" and bool(context.get("crouching",false)):key="guard_low"
	var seq: Array=meta.get("base_sequences",{}).get(key,[])
	if key.is_empty():return {"sequence":[],"key":"unmapped:"+label,"progress":0.0}
	# BVN deliberately stops its jump MovieClip. The live source impulse and
	# its separate gravity still move the body: choose the new drawn air arc
	# from those inputs, rather than freezing an apex cel through the descent.
	# This never ticks a clock or changes the action/landing/air-cancel rules.
	if key in ["jump_rise","jump_apex","fall"] and state=="jump" and not bool(context.get("grounded",true)) and context.has("motion_vertical_speed_v031"):
		var airborne:=_airborne_selection_v031(meta,context)
		if not airborne.get("sequence",[]).is_empty():
			airborne["key"]=key+":"+label
			return airborne
	# These optional drawing ranges follow the existing source normal-attack
	# clock, including its real cancel window. They never change that window.
	var exact_base: Array=meta.get("base_label_pose_phases",{}).get(profile+":"+label,[])
	if not exact_base.is_empty() and not key in ["hurt","air_hurt","down","getup","ko","guard","guard_low"]:
		var chosen:=_exact_phase_selection(exact_base,_sample_frame(context),count)
		chosen["key"]=key+":"+label
		return chosen
	var hold: String=str(meta.get("base_hold_poses",{}).get(key,""))
	if key in ["guard","guard_low"] and not hold.is_empty():
		var hold_index:=seq.find(hold)
		if bool(context.get("guard_held",true)) or state=="guard_stun":
			var raised:=clampf(float(context.get("state_time",0.0))/.10,0.0,1.0)
			return {"sequence":seq.slice(0,maxi(1,hold_index+1)) if raised<1.0 else [hold],"key":key+":"+label,"progress":raised,"phase":"guard_hold"}
		if not bool(context.get("guard_resume_pending",false)):
			return {"sequence":[hold],"key":key+":"+label,"progress":0.0,"phase":"guard_hold"}
		var recover: Array=seq.slice(maxi(0,hold_index+1))
		return {"sequence":recover if not recover.is_empty() else [hold],"key":key+":"+label,"progress":.75 if bool(context.get("guard_resume_pending",false)) else .0,"phase":"guard_release"}
	if key=="idle":progress=fposmod(float(context.get("visual_clock",0))*.65,1.0)
	elif key in ["walk","run"]:progress=fposmod(float(context.get("visual_clock",0))*(3.5 if key=="walk" else 5.0),1.0)
	elif not bool(context.get("source_playing",true)) and key in ["hurt","air_hurt","getup","land","down","ko","guard","guard_low"]:
		var seconds: float=.16 if key in ["guard","guard_low"] else (.36 if key=="getup" else (.40 if key in ["down","ko"] else .22))
		progress=clampf(float(context.get("state_time",0))/seconds,0,1)
	var windows: Dictionary=meta.get("base_contact_windows",{}).get(profile+":"+label,{})
	if not windows.is_empty():
		var layouts: Dictionary=meta.get("base_phase_layouts",{})
		var layout: Dictionary=layouts.get(profile+":"+label,layouts.get(key,{}))
		var chosen:=_contact_selection(seq,_sample_frame(context),count,float(windows["first"]),float(windows["last"]),layout)
		chosen["key"]=key+":"+label;return chosen
	return {"sequence":seq,"key":key+":"+label,"progress":progress}

## Battle already owns the real winning preview. Consume only its dance flag
## on a living actor, using the manifest's explicit victory originals.
static func _victory_selection_v035(meta: Dictionary,context: Dictionary) -> Dictionary:
	var preview: Dictionary=context.get("presentation_victory_v035",{})
	if not bool(preview.get("ready",false)):return {}
	var sequence: Array=meta.get("base_sequences",{}).get("victory",[])
	if sequence.is_empty():sequence=meta.get("ui",{}).get("sequences",{}).get("win",[])
	if sequence.is_empty():return {}
	for pose: String in sequence:
		if not bool(meta.get("frames",{}).get(pose,{}).get("ready",false)):return {}
	var progress: float=fposmod(maxf(0,float(preview.get("clock",0)))*6.0/float(sequence.size()),1.0)
	return {"sequence":sequence,"key":"victory:accepted_preview","progress":progress,"phase":"victory"}

static func _roster_reaction_selection_v034(meta: Dictionary,context: Dictionary) -> Dictionary:
	var sequences: Dictionary=meta.get("reaction_sequences_v034",{})
	if sequences.is_empty():return {}
	var state: String=str(context.get("state",""))
	var label: String=str(context.get("current_label",context.get("source_label","")))
	var record: Dictionary=context.get("reaction_identity",{})
	var key: String=""
	# HitVO gives the initial direction, but the live flight phase and actual
	# vertical speed (including Source's separate gravity) give the current arc.
	# Held victims keep their authenticated capture pose and registration.
	var flight: Dictionary=_roster_flight_selection_v035(meta,context)
	if not flight.is_empty():return flight
	if label=="击飞_弹":key="rebound"
	elif state in ["launch","juggle","slam"]:
		var exact: Dictionary=record.get("hit",context.get("reaction_hit",{}))
		var hit_y: float=float(exact.get("hity",0.0))
		key="air_down" if hit_y>2.0 or state=="slam" else ("air_up" if hit_y< -3.0 or state=="launch" else "air_side")
	elif state=="hurt" and bool(context.get("grounded",true)) and not record.is_empty():
		var contact: Vector2=Vector2(record.get("contact_local",Vector2.ZERO))
		var height: float=maxf(1.0,float(context.get("body_height",90.0)))
		key="ground_upper" if contact.y< -height*.62 else ("ground_lower" if contact.y> -height*.33 else "ground_middle")
	if key.is_empty():return {}
	var sequence: Array=sequences.get(key,[])
	if sequence.is_empty():return {}
	var elapsed: float=float(context.get("state_time",0.0))
	var length: float=maxf(.08,float(context.get("reaction_hurt_length",.22)))
	return {"sequence":sequence,"key":"reaction:"+key,"progress":clampf(elapsed/length,0.0,1.0),"phase":"reaction"}

static func _roster_flight_selection_v035(meta: Dictionary,context: Dictionary) -> Dictionary:
	if str(meta.get("fighter_id","")) not in ["notify","wojak"]:return {}
	if not bool(context.get("reaction_fly",false)) or bool(context.get("grounded",true)):return {}
	if str(context.get("state","")) not in ["launch","juggle","slam"]:return {}
	if bool(context.get("reaction_source_pair_v029",{}).get("active",false)):return {}
	var hit: Dictionary=context.get("reaction_identity",{}).get("hit",context.get("reaction_hit",{}))
	if int(hit.get("hitType",0))==11:return {}
	var source_phase: int=int(context.get("reaction_fly_phase_v029",0))
	if source_phase not in [1,3] or not context.has("motion_vertical_speed_v031"):return {}
	var speed: float=float(context["motion_vertical_speed_v031"])
	if not is_finite(speed):return {}
	var reference: float=maxf(1.0,float(context.get("motion_jump_speed_v031",720.0)))
	var ratio: float=speed/reference
	var phase: String="rise" if ratio<-.16 else ("apex" if ratio<.16 else "fall")
	if source_phase==3:phase="rebound"
	var sequence: Array=meta.get("reaction_flight_sequences_v035",{}).get(phase,[])
	if sequence.is_empty():return {}
	# No elapsed hurt duration runs this arc; freeze preserves all inputs.
	return {"sequence":sequence,"key":"reaction:flight_"+phase,"progress":0.0,"phase":"reaction_flight_"+phase,"source_flight_phase":source_phase,"speed_source":"actual_source_motion_plus_gravity"}

## Only the authenticated grounded ordinary death record can mask generic KO.
## Existing complete originals are selected; no body copy/new cel/physical lift.
static func _ground_ko_selection_v032(meta: Dictionary, context: Dictionary) -> Dictionary:
	if str(context.get("state",""))!="ko" or not bool(context.get("grounded",true)):return {}
	var record: Dictionary=context.get("ground_ko_presentation_v032",{})
	if not bool(record.get("ready",false)):return {}
	var stage: String=str(record.get("stage",""))
	var cel: String=""
	if stage=="hold":
		var held: Array=meta.get("base_sequences",{}).get("hurt",[])
		if held.is_empty():return {}
		var frame: int=int(record.get("hurt_animation_frame",0))
		cel=str(held[mini(held.size()-1,int(float(frame)*float(held.size())/7.0))])
	elif stage=="bounce":
		var id: String=str(meta.get("fighter_id",context.get("fighter_id","")))
		cel=str(ReactionIdentity.AirContact.data().get("fighters",{}).get(id,{}).get("air",{}).get("rebound",""))
	elif stage in ["down","dead"]:
		var down: Array=meta.get("base_sequences",{}).get("down",[])
		if not down.is_empty():cel=str(down.back())
	if cel.is_empty() or not meta.get("frames",{}).has(cel):return {}
	return {"sequence":[cel],"key":"ko:source_"+stage,"progress":0.0,"phase":"ground_ko_"+stage}

static func _airborne_selection_v031(meta: Dictionary, context: Dictionary) -> Dictionary:
	var arcs: Dictionary=meta.get("airborne_sequences_v031",{})
	if arcs.is_empty():return {}
	var reference:=maxf(1.0,float(context.get("motion_jump_speed_v031",720.0)))
	var rate:=float(context.get("motion_vertical_speed_v031",0.0))/reference
	var altitude:=maxf(0.0,float(context.get("floor_y",0.0))-Vector2(context.get("actor_position",context.get("position",Vector2.ZERO))).y)
	var height:=maxf(1.0,float(context.get("body_height",90.0)))
	var phase: String="rising" if rate<-.35 else ("apex" if rate<.20 else "descent")
	var progress:=clampf((rate+1.0)/.65,0.0,1.0) if phase=="rising" else (clampf((rate+.35)/.55,0.0,1.0) if phase=="apex" else clampf((rate-.20)/.60,0.0,1.0))
	if rate>=0.0 and altitude<height*.35:
		phase="preland";progress=1.0
	return {"sequence":arcs.get(phase,[]),"progress":progress,"phase":"air_"+phase,"physical_root_unchanged":true}

static func get_pose_state(id: String, context: Dictionary={}) -> Dictionary:
	var meta:=_manifest(id)
	if meta.is_empty():return {"ready":false,"fighter_id":id}
	var selection:=_sequence(meta,context)
	var seq: Array=selection.get("sequence",[])
	if seq.is_empty():return {"ready":false,"fighter_id":id,"clip":selection.get("key","")}
	var p:=clampf(float(selection.get("progress",0)),0,1)
	var index:=mini(seq.size()-1,int(p*float(seq.size())))
	var pose_id:=str(seq[index]);var frame: Dictionary=meta["frames"].get(pose_id,{})
	if not bool(frame.get("ready",false)):return {"ready":false,"pose_id":pose_id}
	var out:=frame.duplicate(true)
	out["fighter_id"]=id;out["atlas"]=meta["sheets"][frame["sheet"]]["path"]
	out["clip"]=selection["key"];out["keyframe"]=index;out["keyframe_count"]=seq.size()
	out["keyframe_progress"]=clampf(p*float(seq.size())-float(index),0,1)
	out["phase"]=selection.get("phase","visual")
	out["progress"]=p;out["source_profile"]=context.get("donor_profile_id",context.get("base_profile_id",""))
	out["source_label"]=context.get("current_label",context.get("source_label",""))
	out["source_frame"]=context.get("source_frame",0.0)
	out["sample_frame"]=_sample_frame(context)
	out["source_absolute_frame"]=context.get("source_absolute_frame",0.0)
	out["source_fps"]=30;out["branch"]=context.get("actual_branch",context.get("branch",""))
	return out

static func _actor_context(actor: Variant, context: Dictionary) -> Dictionary:
	# Nested source bundles/HitVO/anchors are read-only here. Only presentation
	# fields are inserted at the top level, so copying the complete nested
	# source bundle on every body/FX-anchor query has no purpose.
	var out: Dictionary=context.duplicate()
	if out.is_empty() and actor.has_method("source_visual_state"):out=actor.source_visual_state()
	if actor.has_method("source_visual_state"):
		if actor.has_method("source_ko_visual_state"):out["ground_ko_presentation_v032"]=actor.source_ko_visual_state()
		out["presentation_victory_v035"]={"ready":float(actor.hp)>0.0 and str(actor.preview_animation)=="dance","clock":float(actor.walk_clock)}
		out["source_clock"]=float(actor.source_clock)
		out["hurt_flash"]=float(actor.hurt_flash)
		out["guard_flash"]=float(actor.guard_flash)
		out["last_hurt_bisha"]=bool(actor.last_hurt_bisha)
		out["reaction_hit"]=actor.last_source_hurt_hit
		out["reaction_velocity"]=actor.velocity
		# Native gravity is stored separately from velocity.y by BaseGameSprite.
		# Read the actual downward motion instead of treating vy==0 as an apex.
		out["motion_vertical_speed_v031"]=float(actor.velocity.y)+(float(actor.bvn_motion.gravity)*SourceMotion.VELOCITY_UNIT if actor.velocity.y>=0.0 and bool(actor.bvn_apply_gravity) else 0.0)
		out["motion_jump_speed_v031"]=float(actor.source_jump_power)*SourceMotion.VELOCITY_UNIT
		out=ReactionIdentity.enrich_context(actor,out)
		# Observe source recovery before adding a neutral transition. Do not
		# replay follow-through after the authored cel already reached idle.
		var source_pose: Dictionary=get_pose_state(str(actor.fighter_id),out)
		out["source_visual_pose_id_v028"]=source_pose.get("pose_id","")
		out["source_visual_phase_v028"]=source_pose.get("phase","")
		if not out["presentation_victory_v035"].ready:out=PoseTransitions.resolve_actor(actor,out)
	return out

static func _bell(value: float, center: float, width: float) -> float:
	var d: float=(value-center)/maxf(.001,width)
	return exp(-d*d*2.0)

static func _soft(value: float) -> float:
	var p:=clampf(value,0.0,1.0)
	return p*p*(3.0-2.0*p)

## Displacements are in body heights and are spatially weighted. The sole
## point at the fighter's real foot remains exact; upper body, head and outer
## hair/cloth lag at different rates instead of rotating the complete card.
static func deform_point(local: Vector2, body_height: float, id: String, pose: Dictionary, context: Dictionary) -> Vector2:
	var height:=maxf(1.0,body_height)
	var x:=local.x/height
	var y:=-local.y/height
	var foot_weight:=_soft(y/.18)
	var core:=exp(-pow(x/.53,2.0))
	var head:=_bell(y,.86,.21)
	var chest:=_bell(y,.60,.22)
	var hips:=_bell(y,.35,.20)
	var leg:=_bell(y,.13,.15)
	var outer:=_soft((absf(x)-.20)/.52)
	var cloth:=outer*_bell(y,.42,.42)
	var clip:=str(pose.get("clip","")).get_slice(":",0)
	var phase:=str(pose.get("phase","visual"))
	var p:=clampf(float(pose.get("progress",0.0)),0.0,1.0)
	var time:=float(context.get("visual_clock",0.0))
	var state:=str(context.get("state",""))
	var offset:=Vector2.ZERO
	var attack:=not str(context.get("command","")).is_empty() or clip.begins_with("attack") or clip in ["sweep","launcher","air_attack","throw1","throw2"]
	if clip in ["hurt","air_hurt","caught","throw_victim","guard","guard_low"] or state in ["hurt","guard","guard_stun","juggle","launch","down","getup","ko"]:attack=false
	if clip.begins_with("idle") or (state=="idle" and not attack):
		var breath:=sin(time*TAU*.85)
		offset.y-=.0085*breath*chest*core
		offset.x+=.0045*breath*head*core
		offset.x+=sin(time*TAU*.85-.70)*(.013 if id=="rio" else .008)*outer*(head+cloth*.50)
	elif clip in ["walk","run"] or state in ["walk","run","dash"]:
		var gait:=time*TAU*(5.0 if clip=="run" or state=="dash" else 3.5)
		offset.y-=.014*absf(sin(gait))*core*(chest+head*.40)
		offset.x+=sin(gait)*core*(hips*.014-head*.012)
		# Legs counter-swing around the hips; the center foot anchor stays put.
		offset.x+=sin(gait)*tanh(x*14.0)*leg*.026
		offset.y-=maxf(0.0,sin(gait)*tanh(x*14.0))*leg*.012
		offset.x+=sin(gait-.7)*outer*(head*.012+cloth*.020)
	elif attack:
		var drive:=0.0
		var tension:=0.0
		if phase=="prepare":
			drive=-.038*_soft(p)
			tension=.025*sin(p*PI*.75)
		elif phase=="contact":
			drive=lerpf(-.038,.064,_soft(p/.38)) if p<.38 else lerpf(.064,.017,_soft((p-.38)/.62))
			tension=-.015*sin(p*PI)
		elif phase=="recover":
			drive=.017*(1.0-_soft(p))
			tension=.006*sin(p*PI)
		else:
			# Source-event and actual branch sequences preserve their own clocks.
			# The curve enriches each cel, without creating a new action/branch.
			var cel_phase:=float(pose.get("keyframe_progress",0.0))
			drive=.026*sin(cel_phase*PI)
			tension=.010*sin(cel_phase*TAU)
		var heavy:=1.20 if id=="rio" else (1.08 if id=="shark" else .90)
		offset.x+=drive*heavy*core*(chest+.55*hips+.62*head)
		offset.y+=tension*core*(chest+.48*hips)
		# Hair, coat/skirt and weapon-side pixels follow later than the torso.
		var lag:=sin(p*PI)*(.014 if id=="rio" else .010)
		offset.x-=lag*outer*(head+.60*cloth)
		offset.y+=lag*cloth*signf(x)
		# An extended sword/wing/hand has local reach; the opposite side is not
		# stretched, and the actor's physical root never gains fake movement.
		offset.x+=maxf(0.0,x-.22)*drive*.30*_bell(y,.60,.42)
	elif clip in ["land","jump_prepare"]:
		var settle:=sin(p*PI)
		offset.y+=settle*.030*core*(hips+.65*chest)
		offset.x+=settle*x*.030*core

	return local+offset*height*foot_weight+ReactionIdentity.deform_point(local,body_height,id,pose,context)

## Grid points reuse only spatial Gaussian weights. Keep the public arbitrary-
## point path above intact for anchors and as the exact arithmetic reference.
static func _deform_cached_point(local: Vector2, body_height: float, id: String, pose: Dictionary, context: Dictionary, weights: PackedFloat64Array, first: int) -> Vector2:
	var height:=maxf(1.0,body_height)
	var x:=local.x/height
	var y:=-local.y/height
	var foot_weight:=_soft(y/.18)
	var core: float=weights[first]
	var head: float=weights[first+1]
	var chest: float=weights[first+2]
	var hips: float=weights[first+3]
	var leg: float=weights[first+4]
	var outer:=_soft((absf(x)-.20)/.52)
	var cloth: float=weights[first+5]
	var clip:=str(pose.get("clip","")).get_slice(":",0)
	var phase:=str(pose.get("phase","visual"))
	var p:=clampf(float(pose.get("progress",0.0)),0.0,1.0)
	var time:=float(context.get("visual_clock",0.0))
	var state:=str(context.get("state",""))
	var offset:=Vector2.ZERO
	var attack:=not str(context.get("command","")).is_empty() or clip.begins_with("attack") or clip in ["sweep","launcher","air_attack","throw1","throw2"]
	if clip in ["hurt","air_hurt","caught","throw_victim","guard","guard_low"] or state in ["hurt","guard","guard_stun","juggle","launch","down","getup","ko"]:attack=false
	if clip.begins_with("idle") or (state=="idle" and not attack):
		var breath:=sin(time*TAU*.85)
		offset.y-=.0085*breath*chest*core
		offset.x+=.0045*breath*head*core
		offset.x+=sin(time*TAU*.85-.70)*(.013 if id=="rio" else .008)*outer*(head+cloth*.50)
	elif clip in ["walk","run"] or state in ["walk","run","dash"]:
		var gait:=time*TAU*(5.0 if clip=="run" or state=="dash" else 3.5)
		offset.y-=.014*absf(sin(gait))*core*(chest+head*.40)
		offset.x+=sin(gait)*core*(hips*.014-head*.012)
		# Legs counter-swing around the hips; the center foot anchor stays put.
		offset.x+=sin(gait)*tanh(x*14.0)*leg*.026
		offset.y-=maxf(0.0,sin(gait)*tanh(x*14.0))*leg*.012
		offset.x+=sin(gait-.7)*outer*(head*.012+cloth*.020)
	elif attack:
		var drive:=0.0
		var tension:=0.0
		if phase=="prepare":
			drive=-.038*_soft(p)
			tension=.025*sin(p*PI*.75)
		elif phase=="contact":
			drive=lerpf(-.038,.064,_soft(p/.38)) if p<.38 else lerpf(.064,.017,_soft((p-.38)/.62))
			tension=-.015*sin(p*PI)
		elif phase=="recover":
			drive=.017*(1.0-_soft(p))
			tension=.006*sin(p*PI)
		else:
			# Source-event and actual branch sequences preserve their own clocks.
			# The curve enriches each cel, without creating a new action/branch.
			var cel_phase:=float(pose.get("keyframe_progress",0.0))
			drive=.026*sin(cel_phase*PI)
			tension=.010*sin(cel_phase*TAU)
		var heavy:=1.20 if id=="rio" else (1.08 if id=="shark" else .90)
		offset.x+=drive*heavy*core*(chest+.55*hips+.62*head)
		offset.y+=tension*core*(chest+.48*hips)
		# Hair, coat/skirt and weapon-side pixels follow later than the torso.
		var lag:=sin(p*PI)*(.014 if id=="rio" else .010)
		offset.x-=lag*outer*(head+.60*cloth)
		offset.y+=lag*cloth*signf(x)
		# An extended sword/wing/hand has local reach; the opposite side is not
		# stretched, and the actor's physical root never gains fake movement.
		offset.x+=maxf(0.0,x-.22)*drive*.30*weights[first+6]
	elif clip in ["land","jump_prepare"]:
		var settle:=sin(p*PI)
		offset.y+=settle*.030*core*(hips+.65*chest)
		offset.x+=settle*x*.030*core

	return local+offset*height*foot_weight+ReactionIdentity.deform_point(local,body_height,id,pose,context)

## Pure CPU descriptor used both by the real one-surface draw and QA. UVs do
## not move, so no second body, dissolve, stale trail or sprite-part cut exists.
static func _cel_geometry(id: String,pose: Dictionary,body_height: float) -> Dictionary:
	var cache_key:=id+":"+str(pose["pose_id"])+":"+str(body_height)
	if _geometry_cache.has(cache_key):return _geometry_cache[cache_key]
	var r: Array=pose["rect"]
	var size:=Vector2(float(r[2]),float(r[3]))
	var pivot:=Vector2(float(pose["pivot"][0]),float(pose["pivot"][1]))
	var unit:=body_height/maxf(1.0,float(pose["body_reference_height"]))
	var local_points:=PackedVector2Array()
	var uv:=PackedVector2Array()
	var colors:=PackedColorArray()
	var light_weights: Array=[]
	var sheet: Dictionary=_manifest(id)["sheets"][pose["sheet"]]
	var atlas_size:=Vector2(float(sheet["size"][0]),float(sheet["size"][1]))
	for row in range(GRID_Y+1):
		for column in range(GRID_X+1):
			var corner:=Vector2(float(column)/GRID_X,float(row)/GRID_Y)
			var local: Vector2=(corner*size-pivot)*unit
			local_points.append(local)
			uv.append((Vector2(float(r[0]),float(r[1]))+corner*size)/atlas_size)
			var altitude: float=-local.y/maxf(1.0,body_height)
			var shade:=lerpf(.84,1.0,_soft(altitude/.30))
			# Pool daylight: warm chest/key light, a cooler upper sky fill and
			# restrained ground shading. This stays local to the body surface.
			var warmth:=_bell(altitude,.52,.36)*.045
			var sky:=_soft((altitude-.58)/.45)*.025
			colors.append(Color(shade,shade-warmth*.35+sky*.20,shade-warmth+sky,1.0))
			light_weights.append([_bell(altitude,.58,.30),_bell(altitude,.64,.34)])
	if _topology.is_empty():
		for row in range(GRID_Y):
			for column in range(GRID_X):
				var start: int=row*(GRID_X+1)+column
				_topology.append_array(PackedInt32Array([start,start+1,start+GRID_X+2,start,start+GRID_X+2,start+GRID_X+1]))
	# Use the same packed grid points consumed by sample_mesh, with Float64
	# weights to avoid adding a new rounding step before Vector2 deformation.
	var spatial_weights: PackedFloat64Array=PackedFloat64Array()
	spatial_weights.resize(local_points.size()*SPATIAL_WEIGHT_STRIDE)
	var normalized_height: float=maxf(1.0,body_height)
	for index: int in range(local_points.size()):
		var point: Vector2=local_points[index]
		var x: float=point.x/normalized_height
		var y: float=-point.y/normalized_height
		var first: int=index*SPATIAL_WEIGHT_STRIDE
		spatial_weights[first]=exp(-pow(x/.53,2.0))
		spatial_weights[first+1]=_bell(y,.86,.21)
		spatial_weights[first+2]=_bell(y,.60,.22)
		spatial_weights[first+3]=_bell(y,.35,.20)
		spatial_weights[first+4]=_bell(y,.13,.15)
		spatial_weights[first+5]=_soft((absf(x)-.20)/.52)*_bell(y,.42,.42)
		spatial_weights[first+6]=_bell(y,.60,.42)
	var geometry: Dictionary={"locals":local_points,"uv":uv,"colors":colors,"light_weights":light_weights,"unit":unit,"spatial_weights":spatial_weights,"spatial_weight_height":normalized_height}
	_geometry_cache[cache_key]=geometry
	return geometry

static func sample_mesh(id: String, pose: Dictionary, context: Dictionary, body_height: float, facing: int=1) -> Dictionary:
	if not bool(pose.get("ready",false)):return {"ready":false}
	var geometry:=_cel_geometry(id,pose,body_height)
	var local_points: PackedVector2Array=geometry["locals"]
	var vertices:=PackedVector2Array();vertices.resize(local_points.size())
	var direction:=1.0 if facing>=0 else -1.0
	var spatial_weights: PackedFloat64Array=geometry.get("spatial_weights",PackedFloat64Array())
	# Keep the existing id/pose/string(height) cache key behavior. In particular,
	# a distinct exact height sharing that string must still use its own ratio.
	var cached_spatial: bool=spatial_weights.size()==local_points.size()*SPATIAL_WEIGHT_STRIDE and float(geometry.get("spatial_weight_height",-INF))==maxf(1.0,body_height)
	for index in range(local_points.size()):
		var point: Vector2=_deform_cached_point(local_points[index],body_height,id,pose,context,spatial_weights,index*SPATIAL_WEIGHT_STRIDE) if cached_spatial else deform_point(local_points[index],body_height,id,pose,context)
		vertices[index]=Vector2(point.x*direction,point.y)
	var colors: PackedColorArray=geometry["colors"]
	var light:=clampf(float(context.get("hurt_flash",0.0))/.05,0,1)
	var guard_light:=clampf(float(context.get("guard_flash",0.0))/.08,0,1)
	if light>0.0 or guard_light>0.0:
		colors=colors.duplicate()
		for index in range(colors.size()):
			var weights: Array=geometry["light_weights"][index]
			colors[index]=colors[index].lerp(Color(1.28,1.25,1.13,1.0),float(weights[0])*light*.75).lerp(Color(.72,1.07,1.12,1.0),guard_light*.38*float(weights[1]))
	return {"ready":true,"vertices":vertices,"uv":geometry["uv"],"colors":colors,"indices":_topology,"unit":geometry["unit"],"body_count":1,"surfaces":1,"body_mesh":true,"local_deformation":true}

static func _draw(canvas: CanvasItem, actor: Variant, pose: Dictionary, at: Vector2=Vector2.ZERO, context: Dictionary={}) -> bool:
	if not bool(pose.get("ready",false)):return false
	var texture:=_texture(str(pose["atlas"]))
	if texture==null:return false
	var descriptor:=sample_mesh(str(actor.fighter_id),pose,context,float(actor.body_height),int(context.get("visual_facing",actor.facing)))
	var points: PackedVector2Array=descriptor["vertices"]
	# A local ArrayMesh would be released before GLES consumes draw_mesh's RID.
	# Retain one mesh per canvas/actor and update its single surface in place.
	var mesh:=_retained_mesh(canvas,actor,texture)
	update_retained_surface(mesh,descriptor,at)
	canvas.draw_mesh(mesh,texture)
	if _observer.is_valid():
		var drawn_points:=points.duplicate()
		if at!=Vector2.ZERO:
			for index in range(drawn_points.size()):drawn_points[index]+=at
		_observer.call({"stage":"whole_body","actor_instance":actor.get_instance_id(),"draw_process_frame":Engine.get_process_frames(),"fighter_id":actor.fighter_id,"pose_id":pose["pose_id"],"canvas":canvas.get_instance_id(),"points":drawn_points,"source_frame":pose.get("source_frame",0),"sample_frame":pose.get("sample_frame",0),"unit":descriptor["unit"],"body_count":1,"surfaces":1,"body_mesh":true,"transition_phase":context.get("transition_phase",""),"visual_facing":context.get("visual_facing",actor.facing),"reaction_family":context.get("_reaction_descriptor_v028",{}).get("family",""),"reaction_serial":context.get("_reaction_descriptor_v028",{}).get("serial",-1)})
	return true

static func draw_actor(canvas: CanvasItem, actor: Variant, context: Dictionary={}) -> bool:
	var ctx:=_actor_context(actor,context)
	if not bool(ctx.get("source_visible",ctx.get("visible",true))):return true
	var pose:=get_pose_state(str(actor.fighter_id),ctx)
	return draw_prepared_actor(canvas,actor,ctx,pose)

## Fighter's shader needs the same selected atlas region. Reuse its resolved
## context and pose instead of resolving reactions/transitions a second time.
static func draw_prepared_actor(canvas: CanvasItem,actor: Variant,ctx: Dictionary,pose: Dictionary) -> bool:
	if not bool(ctx.get("source_visible",ctx.get("visible",true))):return true
	var display_offset: Vector2=display_registration_offset(actor,pose,ctx)
	if _draw(canvas,actor,pose,display_offset,ctx):return true
	# An unregistered state remains visible as an explicitly reported new-art
	# fallback; production must never show an old disassembled puppet again.
	var neutral:=ctx.duplicate();neutral["pose_override"]="idle"
	var fallback:=get_pose_state(str(actor.fighter_id),neutral)
	fallback["unmapped_source_state"]=pose.get("clip","")
	if _observer.is_valid():_observer.call({"stage":"unmapped_source_state","fighter_id":actor.fighter_id,"label":ctx.get("current_label","")})
	return _draw(canvas,actor,fallback,Vector2.ZERO,neutral)

static func draw_target_pose(canvas: CanvasItem, target_actor: Variant, pose_id: String="caught", context: Dictionary={}) -> bool:
	# This is the source-owned hidden-victim path only. The owner context
	# supplies a genuine paired capture; still draw the target exactly once.
	var paired_pose: String=ReactionIdentity.pair_victim_override(str(target_actor.fighter_id),context)
	var ctx:=_actor_context(target_actor,{});ctx["pose_override"]=paired_pose if not paired_pose.is_empty() else pose_id
	var pose:=get_pose_state(str(target_actor.fighter_id),ctx)
	var at: Vector2=(target_actor.position if canvas!=target_actor else Vector2.ZERO)+display_registration_offset(target_actor,pose,ctx)
	return _draw(canvas,target_actor,pose,at,ctx)

## Both the one body mesh and all world anchors use exactly this registration.
## The Rio aid is a bounded vertical translation of existing airborne art,
## not a body rotation, blend or a change to the actor's physical source root.
static func display_registration_offset(actor: Variant,pose: Dictionary,context: Dictionary) -> Vector2:
	var registration: Dictionary=pair_display_registration(actor,pose,context)
	return registration.get("offset",Vector2.ZERO)+AirPoseContinuity.offset_for_actor(actor,pose,context)

static func pair_display_registration(actor: Variant,pose: Dictionary,context: Dictionary) -> Dictionary:
	var inactive: Dictionary={"ready":false,"offset":Vector2.ZERO}
	# Only the accepted victim is registered to its actual holder. Attackers
	# and unrelated visible hurt cels never get repositioned by this drawing aid.
	var record: Dictionary=context.get("reaction_identity",{})
	var owner_ref: WeakRef=record.get("attacker",null) as WeakRef
	var owner: Variant=owner_ref.get_ref() if owner_ref!=null else null
	if owner==null or owner==actor or not owner.has_method("source_visual_state"):return inactive
	var owner_context: Dictionary=owner.source_visual_state()
	if str(owner.fighter_id)=="wojak":
		return _wojak_ordinary_capture_registration(actor,pose,context,record,owner,owner_context)
	if str(owner_context.get("binding_id","")) not in ["cat:super","cat:super_down"] or int(owner_context.get("paired_target_index",-1))!=int(actor.player_index):return inactive
	var anchors: Dictionary=world_anchors(owner,owner_context)
	var candidate:=pose.duplicate()
	var raw: Array=pose.get("anchors",{}).get("capture_chest",[])
	if raw.size()==2:
		var local:=Vector2(float(raw[0]),float(raw[1]))*float(actor.body_height)/maxf(1,float(pose.get("body_reference_height",1)))
		candidate["display_deformed_capture_chest_v029"]=deform_point(local,float(actor.body_height),str(actor.fighter_id),pose,context)
	return ReactionIdentity.AirContact.paired_display_offset(owner_context,anchors,candidate,float(actor.body_height),int(context.get("visual_facing",actor.facing)),actor.position)

static func _wojak_ordinary_capture_registration(actor: Variant,pose: Dictionary,context: Dictionary,record: Dictionary,owner: Variant,owner_context: Dictionary) -> Dictionary:
	var inactive: Dictionary={"ready":false,"offset":Vector2.ZERO}
	# Register only the body already caught by the original ordinary HitType11.
	# Release hits replace that record; a later action cannot reuse the hold.
	if not bool(pose.get("ready",false)) or str(record.get("outcome",""))!="hit" or int(record.get("hit",{}).get("hitType",-1))!=11:return inactive
	if str(owner_context.get("current_label","")) not in ["摔1","摔2"] or str(actor.state) not in ["hurt","throw_hold"]:return inactive
	if int(record.get("owner_action_serial_v034",-1))!=int(owner.action_serial) or int(owner_context.get("target_index",-1))!=int(actor.player_index):return inactive
	var capture_key: String="capture_chest" if pose.get("anchors",{}).has("capture_chest") else "anatomy_chest"
	var raw: Array=pose.get("anchors",{}).get(capture_key,[])
	if raw.size()!=2:return inactive
	var anchors: Dictionary=world_anchors(owner,owner_context)
	if not anchors.has("free_grab_hand"):return inactive
	var unit: float=float(actor.body_height)/maxf(1,float(pose.get("body_reference_height",1)))
	var local: Vector2=deform_point(Vector2(float(raw[0]),float(raw[1]))*unit,float(actor.body_height),str(actor.fighter_id),pose,context)
	var direction: float=1.0 if int(context.get("visual_facing",actor.facing))>=0 else -1.0
	var chest: Vector2=actor.position+Vector2(local.x*direction,local.y)
	var grip: Vector2=anchors.free_grab_hand
	return {"ready":true,"offset":grip-chest,"grip_world":grip,"target_chest_world":chest,"target_chest_display_world":grip,"capture_anchor_key_v034":capture_key,"binding_id":"wojak:ordinary_throw","target_index":int(actor.player_index),"changes_physics":false,"source_roots_unchanged":true,"body_count":1}

## Preserve the existing camera query's transition and registration observation
## when no aerial safe-frame fit needs full world-anchor geometry.
static func observe_actor_presentation(actor: Variant) -> void:
	var ctx: Dictionary=_actor_context(actor,{})
	var pose: Dictionary=get_pose_state(str(actor.fighter_id),ctx)
	if bool(pose.get("ready",false)):
		display_registration_offset(actor,pose,ctx)

static func world_anchors(actor: Variant, context: Dictionary={}) -> Dictionary:
	var ctx:=_actor_context(actor,context)
	var pose:=get_pose_state(str(actor.fighter_id),ctx)
	var result: Dictionary={}
	if not bool(pose.get("ready",false)):return result
	var unit:=float(actor.body_height)/maxf(1,float(pose["body_reference_height"]))
	var d:=1.0 if int(ctx.get("visual_facing",actor.facing))>=0 else -1.0
	var display_offset: Vector2=display_registration_offset(actor,pose,ctx)
	for key: String in pose.get("anchors",{}):
		var raw: Array=pose["anchors"][key];var point:=Vector2(float(raw[0]),float(raw[1]))*unit
		point=deform_point(point,float(actor.body_height),str(actor.fighter_id),pose,ctx)
		result[key]=actor.position+display_offset+Vector2(point.x*d,point.y)
	return result

static func coverage() -> Dictionary:
	var fighters: Dictionary={}
	for id: String in IDS:
		var m:=_manifest(id);fighters[id]={"ready_frames":m.get("ready_frame_count",0),"unique_rgba":m.get("unique_rgba_count",0),"generated_slots":m.get("generated_candidate_slots",0),"bindings":m.get("bindings",{}).size()}
	return {"method":"builtin_imagegen_whole_body_rgba","whole_body":true,"old_part_rotation":false,"local_uv_mesh":true,"mesh_vertices":(GRID_X+1)*(GRID_Y+1),"fractional_source_clock":true,"body_copies":0,"fighters":fighters}
