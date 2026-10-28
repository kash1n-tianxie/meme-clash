extends Control
## Native-resolution illustration with small source-local motion and fixed foot pixels.
## This is a single painted master, not a claimed full-body frame sequence.
const MotionShader = preload("res://game/hd_art_motion.gdshader")
var fighter_id := ""
var texture: Texture2D
var source_rect := Rect2()
var profile: Dictionary = {}
var phase := 0.0
var clock_override := -1.0
var reduced_motion := false
var performance_state := "loop"
var _local_clock := 0.0
var _held_clock := 0.0
var _reaction_left := 0.0
var _reaction_duration := 0.24
var _zones: Array[Dictionary] = []
var _treatment: ShaderMaterial

func configure(id: String, master: Texture2D, source: Rect2, motion_profile: Dictionary = {}) -> void:
	fighter_id = id
	texture = master
	source_rect = source
	profile = motion_profile.duplicate(true)
	_zones.clear()
	for value: Variant in profile.get("deform_zones", []):
		if value is Dictionary and _zones.size() < 8:
			_zones.append(value.duplicate(true))
	if _zones.is_empty():
		# Conservative fallback until the art-approved motion metadata is present.
		var head := Vector2(source.position.x + source.size.x * (0.19 if id == "rio" else 0.56), source.position.y + source.size.y * 0.2)
		_zones.append({"center_source": [head.x,head.y], "radius_source": [source.size.x * 0.13,source.size.y * 0.17],"kind":"head","amplitude_px":1.5,"phase":0.0})
		_zones.append({"center_source": [head.x,source.position.y + source.size.y * 0.44],"radius_source":[source.size.x * 0.15,source.size.y * 0.22],"kind":"torso","amplitude_px":1.2,"phase":1.4})

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_treatment = ShaderMaterial.new()
	_treatment.shader = MotionShader
	material = _treatment
	set_meta("representation", "hd_illustration_local_animation")
	_sync_shader()

func _clock() -> float:
	if reduced_motion:
		return 0.0
	if performance_state == "confirm":
		return _held_clock
	if clock_override >= 0.0:
		return clock_override + phase
	var audio := get_node_or_null("/root/GameAudio")
	if audio != null:
		var music: Variant = audio.get("music")
		if music is AudioStreamPlayer and music.playing:
			return maxf(0.0,music.get_playback_position()+AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency()) + phase
	return _local_clock + phase

func _process(delta: float) -> void:
	_local_clock += delta
	_reaction_left = maxf(_reaction_left - delta, 0.0)
	if _reaction_left <= 0.0:
		performance_state = "loop"
	_sync_shader()
	queue_redraw()

func react(kind: String, duration: float = 0.24) -> void:
	if performance_state == "confirm" and _reaction_left > 0.0:
		return
	_held_clock = _clock()
	performance_state = kind
	_reaction_duration = maxf(duration,0.01)
	_reaction_left = _reaction_duration
	_sync_shader()

func _pixel_scale() -> float:
	return minf(size.x / maxf(source_rect.size.x,1.0),size.y / maxf(source_rect.size.y,1.0))

func _destination() -> Rect2:
	var drawn_size := source_rect.size * _pixel_scale()
	return Rect2((size-drawn_size)*0.5,drawn_size)

func ground_anchor() -> Vector2:
	var foot: Array = profile.get("foot_source",[source_rect.get_center().x,source_rect.end.y])
	return _destination().position + (Vector2(float(foot[0]),float(foot[1]))-source_rect.position) * _pixel_scale()

func _normalized_zone(value: Dictionary) -> Dictionary:
	var center: Array = value.get("center_source",value.get("center_source_px",[0.0,0.0]))
	var radius: Array = value.get("radius_source",value.get("radius_source_px",[1.0,1.0]))
	var axis: Array = value.get("axis",[1.0,0.35] if str(value.get("kind","")) in ["hair","arm","hand"] else [0.12,1.0])
	var raw_amplitude := float(value.get("amplitude_px",1.5))
	var amplitude := raw_amplitude / maxf(_pixel_scale(),0.001) if profile.get("amplitude_space","") == "logical_display_pixels" else raw_amplitude
	amplitude = minf(amplitude,1.3/maxf(_pixel_scale(),0.001))
	return {"center":Vector2(float(center[0]),float(center[1])),"radius":Vector2(maxf(float(radius[0]),1.0),maxf(float(radius[1]),1.0)),"axis":Vector2(float(axis[0]),float(axis[1])),"amplitude":amplitude,"phase":float(value.get("phase",0.0)),"kind":str(value.get("kind","torso"))}

func _sync_shader() -> void:
	if _treatment == null or texture == null:
		return
	var canvas := texture.get_size()
	_treatment.set_shader_parameter("canvas_size",canvas)
	_treatment.set_shader_parameter("source_region",Vector4(source_rect.position.x/canvas.x,source_rect.position.y/canvas.y,source_rect.size.x/canvas.x,source_rect.size.y/canvas.y))
	var zone_vectors := PackedVector4Array()
	var motion_vectors := PackedVector4Array()
	for value: Dictionary in _zones:
		var zone := _normalized_zone(value)
		zone_vectors.append(Vector4(zone.center.x,zone.center.y,zone.radius.x,zone.radius.y))
		var amplitude: float = minf(zone.amplitude * (1.2 if performance_state in ["invite","menu"] and zone.kind in ["arm","hand"] else 1.0),1.3/maxf(_pixel_scale(),0.001))
		motion_vectors.append(Vector4(zone.axis.x,zone.axis.y,amplitude,zone.phase))
	while zone_vectors.size() < 8:
		zone_vectors.append(Vector4.ZERO)
		motion_vectors.append(Vector4.ZERO)
	_treatment.set_shader_parameter("zones",zone_vectors)
	_treatment.set_shader_parameter("zone_motion",motion_vectors)
	_treatment.set_shader_parameter("zone_count",_zones.size())
	_treatment.set_shader_parameter("motion_clock",_clock())
	_treatment.set_shader_parameter("motion_strength",0.0 if reduced_motion else 1.0)
	_treatment.set_shader_parameter("feet_fixed_y",float(profile.get("feet_fixed_source_y_min",source_rect.end.y-20.0)))
	_treatment.set_shader_parameter("max_displacement_source_px",1.4/maxf(_pixel_scale(),0.001))
	var fixed_vectors := PackedVector4Array()
	for value: Variant in profile.get("fixed_zones",[]):
		if value is Dictionary and value.get("rect_source") is Array and value.rect_source.size() == 4 and fixed_vectors.size() < 4:
			var region: Array = value.rect_source
			fixed_vectors.append(Vector4(float(region[0]),float(region[1]),float(region[2]),float(region[3])))
	var fixed_count := fixed_vectors.size()
	while fixed_vectors.size() < 4:
		fixed_vectors.append(Vector4.ZERO)
	_treatment.set_shader_parameter("fixed_regions",fixed_vectors)
	_treatment.set_shader_parameter("fixed_count",fixed_count)

func get_pose_state() -> Dictionary:
	var states: Array = []
	var clock := _clock()
	for value: Dictionary in _zones:
		var zone := _normalized_zone(value)
		var offset: Vector2 = Vector2.ZERO if reduced_motion else zone.axis * zone.amplitude * sin(clock*3.7+zone.phase)
		states.append({"kind":zone.kind,"offset_source_px":[offset.x,offset.y]})
	return {"id":fighter_id,"source_kind":"hd_illustration_local_animation","motion_zone_count":_zones.size(),"state":performance_state,"frame_count":1,"frame":0,"regions":states,"feet_fixed":true,"reduced_motion":reduced_motion}

func _draw() -> void:
	if texture != null and source_rect.has_area():
		draw_texture_rect_region(texture,_destination(),source_rect)
