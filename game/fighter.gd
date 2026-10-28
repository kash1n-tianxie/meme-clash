extends Node2D
## Copyright (C) 2021-2026 5DPLAY Game Studio; Godot adaptation (C) 2026.
## SPDX-License-Identifier: GPL-3.0-or-later
## Official BVN source rules are connected via bvn_* modules. Authored meme
## clips, hit shapes and animation routes adapt the source to these characters.
## A deterministic, deliberately small fighting-game actor. Battle owns time and input.

signal action_started(move_id: String)
signal landed(speed: float)
## Presentation-only output of the already computed 30 Hz hurt-fly step.
signal source_floor_impact(event: Dictionary)
signal source_event_requested(event: Dictionary)

const BVNHurtBreak = preload("res://game/bvn_hurt_break.gd")
const BVNTimeline = preload("res://game/bvn_action_timeline.gd")
const BVNInput = preload("res://game/bvn_input.gd")
const BVNDefense = preload("res://game/bvn_defense_rules.gd")
const BVNAir = preload("res://game/bvn_air_rules.gd")
const BVNMotion = preload("res://game/bvn_motion.gd")
const BVNHit = preload("res://game/bvn_hit_rules.gd")
const SourceKOPresentation = preload("res://game/bvn_ko_presentation_v032.gd")
const HitGeometry = preload("res://game/meme_hit_geometry.gd")
const PlayableEvents = preload("res://game/bvn_playable_events.gd")
const SourceBindings = preload("res://game/bvn_skill_bindings.gd")
const AuthoredSkillRuntime = preload("res://game/authored_skill_runtime.gd")
## Explicit opt-in: pinned source fixtures continue to exercise source-only actors.
var authored_skills_enabled := false
var authored_skill_runtime: RefCounted
const FLOOR_Y := 830.0
var stage_floor_y := FLOOR_Y
const CORE_ROWS := {"idle":0,"walk":1,"jump":2,"light":3,"heavy":4,"hurt":5,"block":6,"ko":7}
const ANIMATION_LAYOUTS := {"core":Vector2i(4,8),"special":Vector2i(4,4),"dance":Vector2i(4,2),"extra":Vector2i(4,2)}
const INDEPENDENT_CLIPS := ["idle","walk","jump","light","heavy","hurt","block","ko","special1","special2","special3","super","crouch","throw"]
## Art-approved fixed body height and two foot baselines in the 443.5px extra cells.
const EXTRA_CALIBRATION := {"shark":Vector3(182,356,323),"cat":Vector3(224,386,348),"worker":Vector3(197,376,358),"chicken":Vector3(205,384,372),"rio":Vector3(214,373,329)}
## Body height, floor baseline, and foot midpoint of the independent idle source.
const INDEPENDENT_UNITS := {"rio":Vector3(448.0/887.0,731.0/887.0,270.0/443.5)}
const CAT_SUPER_SOURCE := Vector3(410.0/887.0,671.0/887.0,247.0/443.5)
const RIO_CLIP_CALIBRATION := {
	"idle":Vector3(1,731.0/887.0,270.0/443.5),
	"walk":Vector3(448.0/352.0,686.0/887.0,244.0/443.5),
	"jump":Vector3(448.0/350.0,747.0/887.0,242.0/443.5),
	"light":Vector3(448.0/200.0,620.0/887.0,232.0/443.5),
	"heavy":Vector3(448.0/296.0,733.0/887.0,234.0/443.5),
	"hurt":Vector3(448.0/246.0,618.0/887.0,281.0/443.5),
	"block":Vector3(448.0/252.0,654.0/887.0,205.0/443.5),
	"ko":Vector3(448.0/340.0,693.0/887.0,218.0/443.5),
	"special1":Vector3(448.0/205.0,623.0/887.0,215.0/443.5),
	"special2":Vector3(448.0/235.0,660.0/887.0,220.0/443.5),
	"special3":Vector3(448.0/242.0,713.0/887.0,230.0/443.5),
	"super":Vector3(448.0/242.0,745.0/887.0,239.0/443.5)
}
static var animation_cache: Dictionary = {}
const DEFINITIONS := {
	"shark": {"name": "トララレロ", "color": Color("39b5ed"), "speed": 268.0, "width": 112.0, "height": 184.0},
	"cat": {"name": "ミームねこ", "color": Color("f6cb57"), "speed": 296.0, "width": 76.0, "height": 228.0},
	"worker": {"name": "定時くん", "color": Color("7abbef"), "speed": 254.0, "width": 76.0, "height": 244.0},
	"chicken": {"name": "クン・チキン", "color": Color("fc8bab"), "speed": 263.0, "width": 88.0, "height": 244.0},
	"rio": {"name": "蒼刃リオ", "color": Color("75cbef"), "speed": 175.0, "width": 82.0, "height": 240.0},
	"notify": {"name": "通知ちゃん", "color": Color("ef707e"), "speed": 175.0, "width": 76.0, "height": 240.0},
	"wojak": {"name": "ウォジャック", "color": Color("dddde4"), "speed": 175.0, "width": 76.0, "height": 240.0}
}

var fighter_id := "shark"
var player_index := 0
var display_name := "トララレロ"
var accent := Color("39b5ed")
var hp := 1000.0
var energy := 100.0
var energy_overload := false
var energy_gap := 0
var energy_clock := 0.0
var hype := 0.0
var facing := 1
var velocity := Vector2.ZERO
var state := "idle"
var state_time := 0.0
var action := ""
var action_time := 0.0
var source_normal_frame := -1
var action_data: Dictionary = {}
var hit_targets: Dictionary = {}
var attack_hit := false
var spawned_prop := false
var armor_used := false
var retreat := false
var grounded := true
var crouching := false
var guarding := false
var bvn_defense: Dictionary=BVNDefense.fresh()
var bvn_defense_game_clock := 0.0
var bvn_defense_animation_clock := 0.0
var invulnerable := 0.0
var hurt_flash := 0.0
var guard_flash := 0.0
var combo_hits := 0
var combo_reset := 0.0
var burst_used := false
var ghost_source_state := 0
var speed := 265.0
var body_width := 80.0
var body_height := 165.0
var texture: Texture2D
var emotion_textures: Dictionary = {}
var render_size := Vector2(180.0, 210.0)
var emotion := "happy"
var trail: Array[Vector2] = []
var last_intent: Dictionary = {}
var walk_clock := 0.0
var air_time := 0.0
var air_hits_remaining := BVNAir.DEFAULT_AIR_HITS
var jumps_remaining := BVNAir.DEFAULT_JUMPS
var jump_start_delay := 0.0
var jump_from_ground := true
var jump_retrigger_delay := 0.0
var bvn_motion := BVNMotion.new()
var bvn_damping := Vector2(0,.5)
## Open BaseGameSprite.setVec2: additive source-unit impulse, independent of velocity.
var bvn_reverse_velocity: float = 0.0
var bvn_reverse_damping: float = 0.0
var bvn_apply_gravity := true
var hurt_fly: Dictionary={}
var hurt_fly_clock := 0.0
var hurt_fly_window := 0.0
var hurt_fly_recovery_frame: int = 0
var animation_sheets: Dictionary = {}
var animation_reference := Rect2(0.12,0.12,0.76,0.80)
var preview_animation := ""
var contact_shadow := 1.0
var body_canvas: Node2D
var source_body_material: ShaderMaterial
var crouch_time := 0.0
var crouch_release_time := 0.0
var clip_calibration: Dictionary={}
var action_serial := 0
var attack_contact := false
var contact_result := ""
var route_closed := false
var pending_command := ""
var buffer_life := 0.0
var reject_reason := ""
var dash_cooldown := 0.0
var dash_direction := 1
var air_dash_used := false
var air_light_used := false
var air_slam_used := false
var combo_launch_used := false
var combo_air_light_hit := false
var combo_damage := 0.0
var current_hurt_power := 0.0
var last_hurt_bisha := false
var hurt_chain_break := false
var hurt_break_state: Dictionary={}
var last_combo_hits := 0
var last_combo_damage := 0.0
var protection_min := 0.0
var landing_safety := 0.0
var pixel_script: Script
## Formal OpenBVN 3.4 MovieClip profile. The old NPC timeline remains available
## for isolated audit fixtures; production profiles never inherit its chain rules.
var source_timeline: Script
var source_profile: Dictionary={}
var source_runtime_enabled := false
## Opt-in mixed move data; initialization, normals and reactions keep the base body.
var source_bindings_enabled := false
var source_actor_renderer: Script
var source_renderer_handled := false
var source_move_profile_id := ""
var source_entry_command := ""
var source_entry_label := ""
var source_binding_id := ""
var source_speed := 0.0
var source_jump_power := 15.0
var source_heavy := 3.0
var source_hp_max := 1000.0
var source_foot_anchor := Vector2.ZERO
var source_idle_body := Rect2()
var source_label := ""
var source_frame := 0
var source_absolute_frame := 0
var source_generation := 0
var source_clock := 0.0
var source_playing := false
var source_runtime_state := 0
var source_permissions: Dictionary={}
var source_steel := false
var source_super_steel := false
var source_cross := false
var source_allow_be_hit := true
var source_just_hurt_resume := false
var source_hurt_action := ""
var source_hit_target: Dictionary={}
var source_hit_confirmations: Dictionary={}
var source_unsupported: Array[Dictionary]=[]
var source_condition_resolver: Callable
var source_process_frame_callback: Callable
var source_snapshot: Dictionary={}
var last_source_hurt_hit: Dictionary={}
var last_source_defense_hit: Dictionary={}
var source_doing_action := false
var source_frame_trace: Array[Dictionary]=[]
var source_auto_direct_clock := 0.0
var source_animation_clock := 0.0
var source_external_animation_clock := false
var source_animation_boundary := false
## Drawing/source floor feedback only; never substitutes for gameplay state=ko.
var source_ko_presentation := SourceKOPresentation.new()
var source_doing_air_action := false
var source_is_jumping := false
var source_jump_delay_frames := 0
var source_jump_frame_count := 0
var source_is_touch_floor := true
var source_move_target_active := false

func _authored_runtime() -> RefCounted:
	if authored_skill_runtime==null: authored_skill_runtime=AuthoredSkillRuntime.new(self)
	return authored_skill_runtime

func authored_is_active() -> bool:
	return authored_skills_enabled and authored_skill_runtime!=null and authored_skill_runtime.active

func authored_hits() -> Array[Dictionary]:
	return _authored_runtime().hits() if authored_skills_enabled else []

func authored_notify_contact(hit: Dictionary,result: Dictionary,target: Node2D) -> void:
	if authored_skills_enabled: _authored_runtime().notify_contact(hit,result,target)

func authored_receive_contact(source: Dictionary,attacker: Node2D) -> Dictionary:
	return _authored_runtime().receive_contact(source,attacker) if authored_skills_enabled else {"handled":false}

func authored_visual_state() -> Dictionary:
	return _authored_runtime().visual_state() if authored_skills_enabled else {"ready":false}

func authored_prop_state() -> Array[Dictionary]:
	return _authored_runtime().prop_state() if authored_skills_enabled else []

func authored_reset() -> void:
	if authored_skill_runtime!=null: authored_skill_runtime.reset()

func authored_world_step(delta: float,target: Node2D) -> void:
	if authored_skills_enabled: _authored_runtime().world_step(delta,target)

func authored_input(intent: Dictionary) -> void:
	if authored_skills_enabled: _authored_runtime().input(intent)

func configure(id: String, index: int) -> void:
	fighter_id = id if DEFINITIONS.has(id) else "shark"
	clip_calibration.clear()
	if fighter_id=="rio":
		for clip in RIO_CLIP_CALIBRATION:
			var calibration: Vector3=RIO_CLIP_CALIBRATION[clip]
			clip_calibration[clip]={"scale":calibration.x,"foot":calibration.y,"center":calibration.z}
	player_index = index
	var info: Dictionary = DEFINITIONS[fighter_id]
	display_name = str(info["name"])
	accent = info["color"]
	speed = float(info["speed"])
	body_width = float(info["width"])
	body_height = float(info["height"])
	_load_source_profile()
	if ResourceLoader.exists("res://game/pixel_fighter.gd"): pixel_script=load("res://game/pixel_fighter.gd")
	if not body_canvas:
		body_canvas=Node2D.new()
		body_canvas.draw.connect(_draw_body)
		add_child(body_canvas)
	if ResourceLoader.exists("res://game/fighter_material.gdshader"):
		var treatment := ShaderMaterial.new()
		treatment.shader=load("res://game/fighter_material.gdshader")
		body_canvas.material=treatment
	var path := "res://assets/art/%s.png" % fighter_id
	if ResourceLoader.exists(path):
		var source: Texture2D = load(path) as Texture2D
		if source:
			var img: Image = source.get_image()
			var used: Rect2i = img.get_used_rect() if img else Rect2i(Vector2i.ZERO, Vector2i(source.get_size()))
			var art_crops := {"shark":Rect2i(65,89,1551,781),"cat":Rect2i(27,16,1046,1415),"worker":Rect2i(266,99,658,1143),"chicken":Rect2i(204,41,1021,1056),"rio":Rect2i(18,10,1003,1515)}
			if art_crops.has(fighter_id) and img:
				var crop: Rect2i = art_crops[fighter_id]
				if crop.end.x <= img.get_width() and crop.end.y <= img.get_height():
					used = crop
			if used.size.x > 0 and used.size.y > 0:
				var atlas := AtlasTexture.new()
				atlas.atlas = source
				atlas.region = Rect2(used)
				texture = atlas
				var aspect := float(used.size.x) / float(used.size.y)
				var target_height := 200.0
				if fighter_id == "shark":
					render_size = Vector2(280.0, 280.0 / aspect)
				elif fighter_id == "chicken":
					target_height = 230.0
					render_size = Vector2(target_height * aspect, target_height)
				elif fighter_id == "worker":
					target_height = 210.0
					render_size = Vector2(target_height * aspect, target_height)
				elif fighter_id == "rio":
					target_height = 220.0
					render_size = Vector2(target_height * aspect, target_height)
				else:
					render_size = Vector2(target_height * aspect, target_height)
	if fighter_id == "cat":
		for face in ["huh", "cry", "shock"]:
			var face_path := "res://assets/art/cat_%s.png" % face
			if ResourceLoader.exists(face_path):
				var face_source: Texture2D = load(face_path) as Texture2D
				if face_source:
					var face_atlas := AtlasTexture.new()
					face_atlas.atlas = face_source
					face_atlas.region = Rect2(27,16,1046,1415)
					emotion_textures[face] = face_atlas
	_load_animation_sheets()
	if fighter_id=="cat" and animation_sheets.has("clip:super"):
		clip_calibration["super"]={"scale":animation_reference.size.y/CAT_SUPER_SOURCE.x,"foot":CAT_SUPER_SOURCE.y,"center":CAT_SUPER_SOURCE.z}
	reset_round(340.0 if index == 0 else 940.0)

func _load_animation_sheets() -> void:
	animation_sheets.clear()
	var requests: Array[Dictionary]=[]
	for sheet_name in ANIMATION_LAYOUTS:
		requests.append({"key":sheet_name,"file":sheet_name,"layout":ANIMATION_LAYOUTS[sheet_name]})
	for clip in INDEPENDENT_CLIPS:
		requests.append({"key":"clip:"+clip,"file":clip,"layout":Vector2i(4,1)})
	for request in requests:
		var sheet_name: String=request["key"]
		var path := "res://assets/animation/%s_%s.png" % [fighter_id,request["file"]]
		if not ResourceLoader.exists(path):
			continue
		if animation_cache.has(path):
			animation_sheets[sheet_name] = animation_cache[path]
			continue
		var sheet: Texture2D = load(path) as Texture2D
		if not sheet:
			continue
		var layout: Vector2i=request["layout"]
		var rows := layout.y
		var columns := layout.x
		var cell := sheet.get_size()/Vector2(layout)
		var image: Image = sheet.get_image()
		var pixels := PackedByteArray()
		if image:
			if image.is_compressed(): image.decompress()
			image.convert(Image.FORMAT_RGBA8)
			pixels=image.get_data()
		var idle_bounds := Rect2()
		var all_bounds := Rect2()
		var row_bounds: Array[Rect2]=[]
		for _row in range(rows): row_bounds.append(Rect2())
		var cells: Array[Rect2] = []
		for row in range(rows):
			for column in range(columns):
				var region := Rect2(Vector2(column,row)*cell,cell)
				cells.append(region)
				if image:
					var used := Rect2(image.get_region(Rect2i(region)).get_used_rect())
					if row==0 or sheet_name=="extra":
						var opaque := _opaque_region_bounds(image,pixels,Rect2i(region))
						if opaque.size.x>0 and opaque.size.y>0:
							used=Rect2(opaque)
					if used.size.x>0 and used.size.y>0:
						var normalized := Rect2(used.position/cell,used.size/cell)
						all_bounds = normalized if all_bounds.size==Vector2.ZERO else all_bounds.merge(normalized)
						row_bounds[row]=normalized if row_bounds[row].size==Vector2.ZERO else row_bounds[row].merge(normalized)
						if row==0:
							idle_bounds = normalized if idle_bounds.size==Vector2.ZERO else idle_bounds.merge(normalized)
		var descriptor := {"texture":sheet,"rows":rows,"columns":columns,"cell":cell,"regions":cells,"bounds":all_bounds,"idle_bounds":idle_bounds,"row_bounds":row_bounds,"path":path}
		_apply_frame_metadata(descriptor,path.trim_suffix(".png")+".frames.json")
		animation_cache[path] = descriptor
		animation_sheets[sheet_name] = descriptor
	if animation_sheets.has("core"):
		var bounds: Rect2 = animation_sheets["core"].get("idle_bounds",Rect2())
		if bounds.size.x>0.03 and bounds.size.y>0.03:
			animation_reference = bounds
	if animation_sheets.has("clip:idle"):
		var bounds: Rect2=animation_sheets["clip:idle"]["idle_bounds"]
		if bounds.size.x>0.03 and bounds.size.y>0.03:
			animation_reference=bounds

## Curated source rectangles preserve complete poses in irregular AI-generated sheets.
## Metadata is bundled as ordinary JSON; no pixels are altered or processed per draw.
func _apply_frame_metadata(descriptor: Dictionary,path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("Invalid animation frame metadata: "+path)
		return
	var metadata: Dictionary=parsed
	var canvas: Array=metadata.get("canvas",[])
	var source_size: Vector2=descriptor["texture"].get_size()
	var frames: Array=metadata.get("frames",[])
	var rows: int=descriptor["rows"]
	var columns: int=descriptor["columns"]
	if int(metadata.get("version",0))!=1 or canvas.size()!=2 or Vector2(float(canvas[0]),float(canvas[1]))!=source_size or int(metadata.get("columns",0))!=columns or int(metadata.get("rows",0))!=rows or frames.size()!=rows*columns:
		push_warning("Animation metadata layout does not match its source: "+path)
		return
	var calibration: Array=metadata.get("row_calibration",[])
	if calibration.size()!=rows:
		push_warning("Animation metadata lacks fixed row calibration: "+path)
		return
	var curated_regions: Array[Rect2]=[]
	var anchors: Array[Vector2]=[]
	var source_parts: Array=[]
	for index in range(frames.size()):
		var entry: Dictionary=frames[index]
		var values: Array=entry.get("actual_rect",[])
		var anchor: Array=entry.get("anchor_px",[])
		if int(entry.get("frame",-1))!=index or int(entry.get("row",-1))!=floori(float(index)/columns) or int(entry.get("col",-1))!=posmod(index,columns) or values.size()!=4 or anchor.size()!=2:
			push_warning("Animation metadata frame order is invalid: "+path)
			return
		var region:=Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3]))
		if region.size.x<=0 or region.size.y<=0 or region.position.x<0 or region.position.y<0 or region.end.x>source_size.x or region.end.y>source_size.y:
			push_warning("Animation metadata rectangle leaves its source: "+path)
			return
		curated_regions.append(region)
		anchors.append(Vector2(float(anchor[0]),float(anchor[1])))
		var frame_parts: Array[Rect2]=[]
		for part_values in entry.get("source_parts",[]):
			if not part_values is Array or part_values.size()!=4:
				push_warning("Animation metadata source part is invalid: "+path)
				return
			var part:=Rect2(float(part_values[0]),float(part_values[1]),float(part_values[2]),float(part_values[3]))
			if part.size.x<=0 or part.size.y<=0 or not region.encloses(part):
				push_warning("Animation metadata source part leaves its complete pose: "+path)
				return
			frame_parts.append(part)
		if frame_parts.is_empty(): frame_parts.append(region)
		source_parts.append(frame_parts)
	for row in range(rows):
		var row_data: Dictionary=calibration[row]
		if int(row_data.get("row",-1))!=row or float(row_data.get("body_height_unit",0))<=0 or not row_data.has("foot_line") or not row_data.has("center_x") or float(row_data.get("body_scale",1.0))<=0:
			push_warning("Animation metadata row calibration is invalid: "+path)
			return
	descriptor["regions"]=curated_regions
	descriptor["anchors"]=anchors
	descriptor["source_parts"]=source_parts
	descriptor["row_calibration"]=calibration
	descriptor["metadata_path"]=path
	descriptor["uses_metadata"]=true

## Optional art calibration is fixed for the entire clip, never recalculated per frame.
func set_clip_calibration(clip: String,scale_factor: float=1.0,foot_line: float=-1.0,center_x: float=-1.0) -> void:
	clip_calibration[clip]={"scale":clampf(scale_factor,0.5,4.0),"foot":foot_line,"center":center_x}
	queue_redraw()

func animation_source(frame: Dictionary) -> Dictionary:
	return animation_sheets.get(str(frame.get("source_key",frame.get("sheet","core"))),{})

func _resolve_animation_frame(sheet: String,clip: String,row: int,column: int,looping: bool,clock: float) -> Dictionary:
	var separate_clip := "crouch" if clip=="crouch_recover" else ("light" if clip=="air" else clip)
	var source_key := "clip:"+separate_clip
	var separate := animation_sheets.has(source_key)
	if not separate: source_key=sheet
	var available := animation_sheets.has(source_key)
	var region := Rect2()
	var source_texture: Texture2D
	var cell := Vector2.ZERO
	var nominal_region:=Rect2()
	var curated:=false
	var anchor:=Vector2.ZERO
	var source_parts: Array=[]
	if available:
		var descriptor: Dictionary=animation_sheets[source_key]
		var regions: Array=descriptor["regions"]
		var columns: int=descriptor["columns"]
		var source_row:=0 if separate else row
		var frame_index:=clampi(source_row*columns+column,0,regions.size()-1)
		region=regions[frame_index]
		source_texture=descriptor["texture"]
		cell=descriptor["cell"]
		nominal_region=Rect2(Vector2(column,source_row)*cell,cell)
		curated=bool(descriptor.get("uses_metadata",false))
		if curated:
			anchor=descriptor["anchors"][frame_index]
			source_parts=descriptor["source_parts"][frame_index]
	var result: Dictionary={"sheet":sheet,"clip":clip,"row":row,"column":column,"source_key":source_key,"texture":source_texture,"cell":cell,"region":region,"source_parts":source_parts,"nominal_region":nominal_region,"uses_metadata":curated,"anchor_px":anchor,"available":available,"looping":looping,"clock":clock}
	if available:
		result["source_pixel_scale"]=_animation_draw_rect(result).size.x/maxf(1.0,cell.x)
	return result

## Access the effective source without mutating gameplay, including cinematic/UI previews.
func animation_frame_for_clip(clip: String,column: int=0) -> Dictionary:
	var sheet := "core"
	var row := int(CORE_ROWS.get("light" if clip=="air" else clip,0))
	if clip.begins_with("special") or clip=="super":
		sheet="special"
		row=3 if clip=="super" else clampi(int(clip.trim_prefix("special"))-1,0,2)
	elif clip=="dance":
		sheet="dance"
		row=floori(float(column)/float(ANIMATION_LAYOUTS["dance"].x))
		column=posmod(column,int(ANIMATION_LAYOUTS["dance"].x))
	elif clip in ["throw","crouch","crouch_recover"]:
		sheet="extra"
		row=1 if clip=="throw" else 0
	return _resolve_animation_frame(sheet,clip,row,column,false,0.0)

func _opaque_region_bounds(image: Image,pixels: PackedByteArray,region: Rect2i) -> Rect2i:
	# Sample twice per four-pixel square, once at load; exclude faint generation noise.
	var left := region.size.x
	var top := region.size.y
	var right := -1
	var bottom := -1
	var image_width := image.get_width()
	for y in range(region.position.y,region.end.y,2):
		var row_left := region.size.x
		var row_right := -1
		var row_samples := 0
		for x in range(region.position.x,region.end.x,2):
			var offset := (y*image_width+x)*4+3
			if offset<pixels.size() and pixels[offset]>=38:
				var local_x := x-region.position.x
				row_samples+=1
				row_left=mini(row_left,local_x)
				row_right=maxi(row_right,local_x)
		# Thin cross-cell fins and sparse alpha noise must not move the shared foot anchor.
		if row_samples>=maxi(3,ceili(region.size.x*0.04)):
			var local_y := y-region.position.y
			left=mini(left,row_left)
			top=mini(top,local_y)
			right=maxi(right,row_right)
			bottom=maxi(bottom,local_y)
	if right<left or bottom<top:
		return Rect2i()
	return Rect2i(left,top,mini(region.size.x-left,right-left+2),mini(region.size.y-top,bottom-top+2))

## UI previews can reuse the same real frames without changing combat state.
func set_animation_preview(clip: String) -> void:
	preview_animation = clip
	queue_redraw()

func animation_frame_state() -> Dictionary:
	var sheet := "core"
	var clip := state
	var row := 0
	var column := 0
	var looping := false
	var clock := state_time
	var duration := 0.70
	var frame_count := int(ANIMATION_LAYOUTS["core"].x)
	var held_pose := false
	if not preview_animation.is_empty():
		clip = preview_animation
		clock = walk_clock
		looping = true
		row=int(CORE_ROWS.get(clip,0))
		column=posmod(floori(clock*(10.0 if clip=="walk" else 6.0)),frame_count)
		if clip=="dance":
			sheet="dance"
			row=0
			frame_count=int(ANIMATION_LAYOUTS["dance"].x*ANIMATION_LAYOUTS["dance"].y)
			column=posmod(floori(clock*12.0),frame_count)
	elif state=="attack":
		clip=action
		clock=action_time
		duration=float(action_data.get("startup",0.1))+float(action_data.get("active",0.1))+float(action_data.get("recovery",0.2))
		if action.begins_with("skill") or action.begins_with("special"):
			sheet="special"
			row=clampi(int(action.trim_prefix("special").trim_prefix("skill"))-1,0,2)
		elif action.begins_with("super"):
			sheet="special"
			row=3
		elif action=="throw":
			sheet="extra"
			row=1
		else:
			row=3 if action in ["light","air"] else 4
	elif state=="ko":
		row=7
		duration=0.65
	elif state=="hurt":
		row=5
		duration=maxf(0.20,float(action_data.get("hurt_length",0.3)))
	elif not grounded:
		clip="jump"
		row=2
		clock=air_time
		duration=0.85
	elif crouching:
		clip="crouch"
		sheet="extra"
		row=0
		clock=crouch_time
		column=mini(2,floori(crouch_time/0.10))
		held_pose=true
	elif crouch_release_time>0.0:
		clip="crouch_recover"
		sheet="extra"
		row=0
		column=3
		held_pose=true
	else:
		clip="block" if guarding else ("walk" if absf(velocity.x)>20.0 else "idle")
		row=int(CORE_ROWS.get(clip,0))
		clock=walk_clock
		looping=true
		column=posmod(floori(clock*(10.0 if clip=="walk" else 6.0)),frame_count)
	if sheet!="dance":
		frame_count=int(ANIMATION_LAYOUTS[sheet].x)
	if preview_animation=="dance":
		column=posmod(floori(clock*12.0),frame_count)
		row=floori(float(column)/float(ANIMATION_LAYOUTS["dance"].x))
		column=posmod(column,int(ANIMATION_LAYOUTS["dance"].x))
	elif not looping and not held_pose:
		if state=="attack":
			var startup := float(action_data.get("startup",0.1))
			var active := float(action_data.get("active",0.1))
			var startup_frames := maxi(1,floori(frame_count*0.5))
			var contact_frame := mini(frame_count-2,startup_frames)
			if clock<startup:
				column=clampi(floori(clock/maxf(0.01,startup)*startup_frames),0,startup_frames-1)
			elif clock<=startup+active:
				column=contact_frame
			else:
				var recover := maxf(0.01,duration-startup-active)
				column=clampi(contact_frame+1+floori((clock-startup-active)/recover*(frame_count-contact_frame-1)),contact_frame+1,frame_count-1)
		else:
			column=clampi(floori(clock/maxf(0.1,duration)*float(frame_count)),0,frame_count-1)
	return _resolve_animation_frame(sheet,clip,row,column,looping,clock)

func _animation_draw_rect(frame: Dictionary) -> Rect2:
	var descriptor: Dictionary=animation_source(frame)
	var cell: Vector2=descriptor["cell"]
	if bool(descriptor.get("uses_metadata",false)):
		var row:=int(frame["row"])
		var row_data: Dictionary=descriptor["row_calibration"][row]
		var pixel_scale:=_target_animation_height()/float(row_data["body_height_unit"])*float(row_data.get("body_scale",1.0))
		var foot_local:=float(row_data["foot_line"])-float(row)*cell.y
		var origin:=Vector2(-float(row_data["center_x"]),-foot_local)*pixel_scale
		return Rect2(origin,cell*pixel_scale)
	var reference := animation_reference
	if str(frame["sheet"]) in ["dance","extra"] or fighter_id=="shark" and str(frame["sheet"])=="special":
		var sheet_reference: Rect2=descriptor.get("idle_bounds",Rect2())
		if sheet_reference.size.x>0.2 and sheet_reference.size.y>0.2:
			reference=sheet_reference
	var target_height := 200.0
	if fighter_id=="worker": target_height=210.0
	if fighter_id=="chicken": target_height=230.0
	if fighter_id=="rio": target_height=220.0
	if fighter_id=="shark": target_height=165.0
	var target_width := target_height*cell.x/cell.y/maxf(0.2,reference.size.y)
	if fighter_id=="shark":
		target_width=280.0/maxf(0.2,reference.size.x)
	var size := Vector2(target_width,target_width*cell.y/cell.x)
	var foot := clampf(reference.end.y,0.55,1.0)
	if str(frame["sheet"])=="extra":
		var row_bounds: Array=descriptor.get("row_bounds",[])
		var row:=int(frame.get("row",0))
		if row<row_bounds.size() and row_bounds[row].size.y>0.2:
			foot=clampf(row_bounds[row].end.y,0.55,1.0)
	var center := reference.get_center().x
	if str(frame.get("source_key",frame["sheet"]))=="extra" and EXTRA_CALIBRATION.has(fighter_id):
		var calibration: Vector3=EXTRA_CALIBRATION[fighter_id]
		var canvas_height := target_height/(calibration.x/443.5)
		size=Vector2(canvas_height*cell.x/cell.y,canvas_height)
		foot=(calibration.z if int(frame.get("row",0))==1 else calibration.y)/443.5
		center=0.5
	if str(frame.get("source_key","")).begins_with("clip:"):
		var clip_reference: Rect2=descriptor["idle_bounds"]
		# Character units come from the idle reference; bending/jumping is never stretched.
		foot=clampf(clip_reference.end.y,0.25,1.0)
		center=0.5
		if INDEPENDENT_UNITS.has(fighter_id):
			var units: Vector3=INDEPENDENT_UNITS[fighter_id]
			var canvas_height := target_height/units.x
			size=Vector2(canvas_height*cell.x/cell.y,canvas_height)
			center=units.z
			if frame["source_key"]=="clip:idle": foot=units.y
		var calibration: Dictionary=clip_calibration.get(str(frame["source_key"]).trim_prefix("clip:"),{})
		size*=float(calibration.get("scale",1.0))
		if float(calibration.get("foot",-1.0))>0: foot=float(calibration["foot"])
		if float(calibration.get("center",-1.0))>=0: center=float(calibration["center"])
	return Rect2(Vector2(-center*size.x,-foot*size.y),size)

func _target_animation_height() -> float:
	return float({"shark":165.0,"cat":200.0,"worker":210.0,"chicken":230.0,"rio":220.0}.get(fighter_id,200.0))

## A changing crop never stretches a changing pose. Draw it with the fixed logical
## canvas' source-pixel scale and its offset from the nominal cell origin.
func _animation_source_draw_rect(frame: Dictionary,source_part: Rect2=Rect2()) -> Rect2:
	var logical:=_animation_draw_rect(frame)
	if not bool(frame.get("uses_metadata",false)):
		return logical
	var cell: Vector2=frame["cell"]
	var region: Rect2=source_part if source_part.size!=Vector2.ZERO else frame["region"]
	var nominal: Rect2=frame["nominal_region"]
	var pixel_scale:=logical.size.x/cell.x
	return Rect2(logical.position+(region.position-nominal.position)*pixel_scale,region.size*pixel_scale)

## Rectangular parts isolate nearby silhouettes and disconnected props while
## preserving their original pixel coordinates, pose, and common body scale.
func animation_draw_commands(frame: Dictionary) -> Array[Dictionary]:
	var commands: Array[Dictionary]=[]
	if not bool(frame.get("available",false)): return commands
	var parts: Array=frame.get("source_parts",[])
	if parts.is_empty(): parts=[frame["region"]]
	for part in parts:
		commands.append({"source_rect":part,"draw_rect":_animation_source_draw_rect(frame,part),"texture":frame["texture"]})
	return commands

func animation_render_metrics(frame: Dictionary) -> Dictionary:
	if not bool(frame.get("available",false)):
		return {}
	var logical:=_animation_draw_rect(frame)
	var actual:=_animation_source_draw_rect(frame)
	var cell: Vector2=frame["cell"]
	return {"logical_rect":logical,"actual_rect":actual,"source_pixel_scale":logical.size.x/cell.x,"metadata":bool(frame.get("uses_metadata",false))}

func _source_rect(value: Variant) -> Rect2:
	if value is Rect2: return value
	if value is Array and value.size()>=4: return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))
	if value is Dictionary: return _source_rect(value.get("source_rect",value.get("rect",[])))
	return Rect2()

func _load_source_profile() -> void:
	source_runtime_enabled=false; source_profile.clear()
	if not ResourceLoader.exists("res://game/bvn_playable_timeline.gd"): return
	source_timeline=load("res://game/bvn_playable_timeline.gd")
	source_profile=source_timeline.profile(fighter_id)
	if source_profile.is_empty(): return
	var config: Dictionary=source_profile.get("config",{})
	source_speed=float(config.get("speed",0))
	source_jump_power=float(config.get("jumpPower",config.get("jump_power",15)))
	source_heavy=float(config.get("heavy",3))
	source_hp_max=float(config.get("hp",1000))
	speed=source_speed*BVNMotion.VELOCITY_UNIT
	var foot: Variant=source_profile.get("foot_anchor",[0,0])
	if foot is Array and foot.size()>=2: source_foot_anchor=Vector2(float(foot[0]),float(foot[1]))
	elif foot is Dictionary: source_foot_anchor=Vector2(float(foot.get("x",0)),float(foot.get("y",0)))
	source_idle_body=_source_rect(source_profile.get("idle_body_area",[]))
	if source_idle_body.size.x<=0 or source_idle_body.size.y<=0 or source_speed<=0:
		push_error("Formal BVN profile missing source initialization: "+fighter_id)
		return
	body_width=source_idle_body.size.x*BVNAir.STAGE_UNIT_SCALE
	body_height=source_idle_body.size.y*BVNAir.STAGE_UNIT_SCALE
	source_runtime_enabled=true

func source_active_profile_id() -> String:
	return source_move_profile_id if source_bindings_enabled and not source_move_profile_id.is_empty() else SourceBindings.base_profile_id(fighter_id)

func _source_clear_move_context() -> void:
	source_move_profile_id=""; source_entry_command=""; source_entry_label=""; source_binding_id=""

func source_has_label(label: String,profile_id: String="") -> bool:
	return source_runtime_enabled and source_timeline.has_definition(source_active_profile_id() if profile_id.is_empty() else profile_id,label)

func source_input_candidates(flags: Dictionary,catch_allowed: bool=false,down: bool=false) -> Array[String]:
	return BVNInput.command_candidates(flags,grounded,catch_allowed,down,source_bindings_enabled,source_action_state() in [10,11,12,13])

## Read-only source clock and spatial state for the actor and FX renderers.
func source_move_context() -> Dictionary:
	var definition: Dictionary=source_timeline.definition_metadata(source_active_profile_id(),source_label) if source_runtime_enabled else {}
	var binding: Dictionary=SourceBindings.binding_for(fighter_id,source_entry_command) if source_bindings_enabled else {}
	return {"ready":source_runtime_enabled,"fighter_id":fighter_id,"base_profile_id":SourceBindings.base_profile_id(fighter_id),"donor_profile_id":source_active_profile_id(),"source_profile_id":source_active_profile_id(),"binding_id":source_binding_id,"command":source_entry_command if not source_entry_command.is_empty() else action,"entry_label":source_entry_label if not source_entry_label.is_empty() else source_label,"current_label":source_label,"source_label":source_label,"source_frame":source_frame,"source_absolute_frame":source_absolute_frame,"source_frame_count":int(definition.get("frame_count",1)),"source_start_frame":int(definition.get("source_start_frame",0)),"source_playing":source_playing,"action_serial":action_serial,"foot_anchor":source_active_foot_anchor(),"name_ja":str(binding.get("name_ja",display_name)),"source_doing_action":source_doing_action}

func source_active_foot_anchor() -> Vector2:
	if source_active_profile_id()==SourceBindings.base_profile_id(fighter_id): return source_foot_anchor
	return source_timeline.foot_anchor(source_active_profile_id())

func source_ko_visual_state() -> Dictionary:
	return source_ko_presentation.snapshot() if state=="ko" and hp<=0 and grounded and hurt_fly.is_empty() else {}

func source_visual_state() -> Dictionary:
	var context: Dictionary=source_move_context()
	context["ground_ko_presentation_v032"]=source_ko_visual_state()
	context.merge({"source_clock":source_clock,"hurt_flash":hurt_flash,"guard_flash":guard_flash,"last_hurt_bisha":last_hurt_bisha,"guard_held":bool(last_intent.get("guard",false)),"guard_resume_pending":bool(bvn_defense.get("resume_pending",false))},true)
	var regions: Array[Dictionary]=[]
	var hit_regions: Array[Rect2]=[]
	for area: Dictionary in source_snapshot.get("areas",[]):
		var region: Dictionary=area.duplicate(true)
		region["area"]=_source_world_rect(_source_rect(area))
		regions.append(region)
		if str(area.get("kind",""))=="hit": hit_regions.append(region["area"])
	var paired_target: Variant=null
	if source_process_frame_callback.is_valid():
		var world: Variant=source_process_frame_callback.get_object()
		if world!=null and world.has_method("target_for"): paired_target=world.target_for(self)
	var stage: String="HIT" if source_label.contains("HIT") else ("TF" if source_label.contains("TF") else ("CHK" if source_label.contains("CHK") else ("HA" if source_label.contains("HA") else "entry")))
	context.merge({"visual_clock":walk_clock,"state_time":state_time,"body_height":body_height,"floor_y":stage_floor_y,"crouching":crouching or (state=="guard" and bool(last_intent.get("guard",false))),"regions":regions,"hit_regions":hit_regions,"body_region":body_box(),"actor_position":position,"position":position,"facing":facing,"visible":visible,"source_visible":visible,"grounded":grounded,"touch_floor":source_is_touch_floor,"stage":stage,"branch":source_label,"contact":contact_result,"confirmed":attack_hit,"confirmations":source_hit_confirmations.duplicate(true),"hurt_action":source_hurt_action,"target_index":int(paired_target.player_index) if paired_target!=null else -1,"paired_target_index":int(paired_target.player_index) if paired_target!=null and (source_move_target_active or not paired_target.visible) else -1,"target_position":paired_target.position if paired_target!=null else Vector2.ZERO,"paired_target_position":paired_target.position if paired_target!=null else Vector2.ZERO,"paired_target_visible":paired_target.visible if paired_target!=null else true,"source_target_active":source_move_target_active,"progress":clampf(float(source_frame)/maxf(1,float(context["source_frame_count"])),0,1),"state":state,"action":action},true)
	return context

func source_note_unsupported(event: Dictionary,reason: String) -> void:
	var entry: Dictionary={"label":source_label,"frame":source_frame,"reason":reason,"event":event.duplicate(true)}
	# Diagnostics are bounded; an unsupported operation is observable rather than
	# silently executed as an unconditional call or growing forever during loops.
	if source_unsupported.size()<100: source_unsupported.append(entry)

func source_set_permission(key: String,label: String,extra: Variant=null) -> void:
	var profile_id: String=source_active_profile_id()
	var binding: Dictionary=SourceBindings.permission_binding(fighter_id,key,label) if source_bindings_enabled else {}
	if not binding.is_empty():
		profile_id=str(binding["donor_profile_id"]); label=str(binding["entry_label"])
	elif source_bindings_enabled and label in ["砍1","砍技1","砍技2","摔1","摔2","跳砍","跳","瞬步","落","落地"]:
		profile_id=SourceBindings.base_profile_id(fighter_id)
	if not source_has_label(label,profile_id): return
	var permission: Dictionary={"label":label,"profile_id":profile_id}
	if not binding.is_empty():
		permission["binding_id"]=binding["binding_id"]; permission["command"]=binding["command"]
	if extra is bool: permission["breakAct"]=extra
	elif extra!=null: permission["cost"]=float(extra)
	source_permissions[key]=permission

func _source_defaults(air: bool=false) -> void:
	source_permissions.clear()
	var setter: String="setAirAllAct" if air else "setAllAct"
	PlayableEvents.execute_event(self,{"calls":[{"controller":"$mc_ctrler","method":setter,"arguments":[]}]})

## This is endAct(), not idle(): late HitVO areas remain sampled after FREEZE.
func source_end_act() -> void:
	source_permissions.clear(); source_hit_target.clear(); source_hurt_action=""
	source_runtime_state=40; source_steel=false; source_super_steel=false
	if source_move_target_active:
		source_move_target_active=false
		source_event_requested.emit({"controller":"$mc_ctrler","method":"moveTarget","arguments":[null],"source_label":source_label,"source_frame":source_frame,"action_serial":action_serial})

func source_idle(label: String="站立",entering_source_state: int=-1) -> void:
	# Open3.4 idle130–153 / FighterActionState.isHurting:21,22,23,24.
	# Some Godot reaction branches change state before this call, so they pass
	# the actual source state they are leaving; endAct40 is never a hurt resume.
	if entering_source_state<0: entering_source_state=source_action_state()
	if entering_source_state in [21,22,23,24]: source_just_hurt_resume=true
	if source_move_target_active: source_end_act()
	_source_clear_move_context()
	source_generation+=1; source_clock=0; source_playing=false; source_doing_action=false; source_doing_air_action=false
	source_is_jumping=false; source_jump_delay_frames=0; source_jump_frame_count=0; jump_start_delay=0
	source_runtime_state=0; source_steel=false; source_super_steel=false; source_cross=false; source_allow_be_hit=not source_just_hurt_resume
	source_hurt_action=""; source_hit_target.clear(); source_hit_confirmations.clear()
	last_source_hurt_hit.clear(); last_source_defense_hit.clear()
	action=""; action_data.clear(); attack_hit=false; attack_contact=false; route_closed=false
	state="idle" if grounded else "jump"; state_time=0; emotion="happy"; source_auto_direct_clock=0
	bvn_apply_gravity=true; guarding=false; visible=true
	if grounded:
		source_is_touch_floor=true
		velocity=Vector2.ZERO
	else:
		source_is_touch_floor=false
		velocity.x=0
	source_label=label if grounded else "落"
	source_frame=0; source_snapshot=source_timeline.sample_frame(fighter_id,source_label,0)
	source_absolute_frame=int(source_snapshot.get("source_frame",0))
	_source_defaults(not grounded)
	if not grounded:
		source_set_permission("jump","跳")
		source_set_permission("touchFloor","落地",true)
	if label!="站立" and grounded and source_has_label(label):
		source_playing=true
		_source_execute_frame()

func _source_command_key(request: String) -> String:
	# These two approved content profiles use WU=招2 and SU=招3. Input
	# direction selects the semantic command; its permission is the actual
	# source setter for that label, including any quick cancel variant.
	if fighter_id in ["notify","wojak"] and request in ["skill2","skill3"]:
		return "zhao2" if request=="skill2" else "zhao3"
	var keys: Dictionary={"attack":"attack" if grounded else "attackAIR","attack1":"attack","attack2":"attack","attack3":"attack","attack4":"attack","attack5":"attack","sweep":"skill1","launcher":"skill2","skill1":"zhao1","skill2":"zhao3","skill3":"zhao2","air_light":"attackAIR","air_skill":"skillAIR","air_slam":"skillAIR","super":"bisha","super_up":"bishaUP","super_down":"bishaSUPER","air_super":"bishaAIR","throw":"catch1","throw1":"catch1","throw2":"catch2","jump":"jump" if source_permissions.has("jump") or not source_permissions.has("jumpQuick") else "jumpQuick","fastfall":"jumpDown","dash":"dash"}
	return str(keys.get(request,request))

func _source_label_command(label: String,fallback: String="") -> String:
	if fighter_id in ["notify","wojak"] and label.get_slice("_",0) in ["招2","招3"]:
		return "skill2" if label.get_slice("_",0)=="招2" else "skill3"
	var labels: Dictionary={"砍1":"attack1","砍2":"attack2","砍3":"attack3","砍4":"attack4","砍4_QK":"attack4","砍5":"attack5","砍技1":"sweep","砍技2":"launcher","招1":"skill1","招2":"skill3","招3":"skill2","跳砍":"air_light","跳招":"air_skill","跳招-上":"air_skill","跳招-下":"air_slam","必杀":"super","上必杀":"super_up","超必杀":"super_down","空中必杀":"air_super","摔1":"throw","摔2":"throw","瞬步":"dash"}
	return str(labels.get(label,fallback if not fallback.is_empty() else label))

## goFrame preserves controller state; doAction clears it and emits a new action.
## The current frame script executes synchronously before Battle samples hits.
func source_branch(label: String,hit_id: String="",restart_action: bool=false,air_action: bool=false) -> bool:
	if not source_has_label(label):
		source_note_unsupported({"label":label},"missing branch label")
		return false
	if restart_action:
		velocity=Vector2.ZERO; source_permissions.clear(); source_hit_target.clear(); source_hurt_action=""
		guarding=false; _clear_bvn_defense(); crouching=false; invulnerable=0
		source_allow_be_hit=true; source_cross=false; bvn_apply_gravity=true
		source_is_jumping=false; source_jump_delay_frames=0; source_jump_frame_count=0; jump_start_delay=0
		source_doing_action=true; source_doing_air_action=air_action; state="attack"; state_time=0; action_serial+=1
		action=_source_label_command(label,action); attack_hit=false; attack_contact=false; hit_targets.clear(); spawned_prop=false
	source_generation+=1; source_label=label; source_frame=0; source_clock=0; action_time=0; source_playing=true
	source_snapshot=source_timeline.sample_frame(source_active_profile_id(),label,0)
	source_absolute_frame=int(source_snapshot.get("source_frame",0))
	action_data=_source_move_definition(action,label)
	if not hit_id.is_empty(): source_hit_confirmations[hit_id]=true
	_source_execute_frame()
	if restart_action: action_started.emit(action)
	return true

func _source_execute_frame() -> void:
	var generation: int=source_generation
	source_snapshot=source_timeline.sample_frame(source_active_profile_id(),source_label,source_frame)
	source_absolute_frame=int(source_snapshot.get("source_frame",source_absolute_frame))
	if source_frame_trace.size()<300:
		source_frame_trace.append({"label":source_label,"frame":source_frame,"absolute":source_absolute_frame,"state":source_runtime_state,"profile_id":source_active_profile_id(),"binding_id":source_binding_id})
	# touchFloor passes setAttack as a one-animation-frame delayed callback.
	if source_label=="落地" and source_frame==1: source_set_permission("attack","砍1")
	for event: Dictionary in source_snapshot.get("events",source_snapshot.get("current_frame_events",[])):
		if source_generation!=generation: break
		PlayableEvents.execute_event(self,event)
	if source_generation==generation and source_process_frame_callback.is_valid(): source_process_frame_callback.call(self,source_snapshot)

func source_sync_animation_tick(tick: bool) -> void:
	source_external_animation_clock=true
	source_animation_boundary=tick

## Source EffectCtrler.bisha pauses GameCtrl, then justRenderAnimate(caster).
## Only frame scripts run: no velocity/gravity, resource regeneration or hurt
## timers advance, and no opponent/object is touched by this actor method.
func source_animate_only(delta: float,tick: bool) -> void:
	if authored_is_active():
		queue_redraw()
		if body_canvas: body_canvas.queue_redraw()
		return
	if not source_runtime_enabled: return
	source_sync_animation_tick(tick)
	_source_render_animation_prelude()
	_source_tick(delta)
	queue_redraw()
	if body_canvas: body_canvas.queue_redraw()

func _source_animation_step(delta: float) -> void:
	if source_external_animation_clock: return
	source_animation_clock+=delta
	source_animation_boundary=source_animation_clock+.0000001>=1.0/30.0
	if source_animation_boundary: source_animation_clock-=1.0/30.0

## Open3.4 renderAnimate833–835 / 3.7 HurtCtrl.renderAnimatePrelude172–176.
## Run BEFORE this tick's hurtResume/idle, never after _source_tick. A marker
## created during this advance therefore lasts until the next real30Hz prelude.
func _source_render_animation_prelude() -> void:
	if source_animation_boundary and source_just_hurt_resume:
		source_allow_be_hit=true
		source_just_hurt_resume=false

func _source_tick(delta: float) -> void:
	if not source_playing: return
	source_clock+=delta
	if source_animation_boundary:
		source_clock=0
		source_frame+=1
		action_time=float(source_frame)/30.0+source_clock
		var definition: Dictionary=source_timeline.definition_metadata(source_active_profile_id(),source_label)
		if source_frame>=int(definition.get("frame_count",1)):
			# No implicit idle at an arbitrary label boundary. Only true actor end
			# stops playback; extracted idle/redirect scripts usually precede it.
			source_playing=false
			return
		_source_execute_frame()
	action_time=float(source_frame)/30.0+source_clock

## Open FighterMcCtrler:1262–1362. Stopped jump poses still count global
## animation ticks; quick/ordinary air-jump rights are distinct source slots.
func _source_render_jump_animate() -> void:
	if state!="jump" or not source_is_jumping or source_doing_action or not source_animation_boundary: return
	if source_jump_delay_frames>0:
		source_jump_delay_frames-=1
		jump_start_delay=float(source_jump_delay_frames)/30.0
		if source_jump_delay_frames==0:
			jumps_remaining-=1
			velocity.y=-source_jump_power*BVNMotion.VELOCITY_UNIT
			bvn_damping=Vector2(0,.5); bvn_motion.reset(false)
			_source_reaction_snapshot("跳")
			source_jump_frame_count=0; _source_defaults(true); source_runtime_state=14
		return
	source_jump_frame_count+=1
	if source_jump_frame_count==2: source_set_permission("jumpQuick","跳")
	if source_label=="跳中":
		if source_jump_frame_count>=4: source_set_permission("jump","跳")
	elif velocity.y>-source_jump_power*.35*BVNMotion.VELOCITY_UNIT:
		_source_reaction_snapshot("跳中"); source_jump_frame_count=0
	if velocity.y>=0: source_is_jumping=false

func source_notify_contact(hit_id: String,result: Dictionary,target_index: int=-1) -> void:
	source_hit_confirmations[hit_id]={"result":result.duplicate(true),"target":target_index,"frame":source_absolute_frame}
	attack_contact=true; attack_hit=not bool(result.get("blocked",false)); contact_result="guard" if not attack_hit else "hit"

func _source_world_rect(rect: Rect2,profile_id: String="") -> Rect2:
	var anchor: Vector2=source_active_foot_anchor() if profile_id.is_empty() else source_timeline.foot_anchor(profile_id)
	var local: Rect2=Rect2((rect.position-anchor)*BVNAir.STAGE_UNIT_SCALE,rect.size*BVNAir.STAGE_UNIT_SCALE)
	if facing<0: local.position.x=-local.end.x
	local.position+=position
	return local

func source_rect_to_world(value: Variant,profile_id: String="") -> Rect2:
	return _source_world_rect(_source_rect(value),profile_id)

func source_frame_hits() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if not source_runtime_enabled or not source_doing_action or state not in ["attack","dash"]: return result
	for item: Dictionary in source_snapshot.get("hits",[]):
		var hit: Dictionary=item.duplicate(true)
		var wrapped: Dictionary=hit.get("hit_vo",hit.get("hitVO",hit.get("source_hit_vo",{})))
		var exact: Dictionary=wrapped.get("effective",wrapped).duplicate(true)
		var name: String=str(hit.get("hit_id",hit.get("name",hit.get("id",""))))
		if name.ends_with("atm"): name=name.trim_suffix("atm")
		exact["id"]=name
		exact["source_profile_id"]=source_active_profile_id()
		var audit: Rect2=_source_world_rect(_source_rect(hit))
		# Formal hit areas are authoritative; rebuilding the old painted-alpha
		# outline here is unused and caused a ~100ms first-strike physics stall.
		hit.merge({"source_profile_id":source_active_profile_id(),"source_binding_id":source_binding_id,"source_object_instance_id":0,"source_name":name,"source_hit_vo":exact,"source_audit_area":audit,"source_label":source_label,"source_frame":source_frame,"kind":"super" if source_runtime_state in [12,13] or name.contains("bs") else ("throw" if int(exact.get("hitType",1))==11 else ("normal" if source_runtime_state==10 else "special")),"damage":int(float(exact.get("power",0))*float(exact.get("powerRate",1))),"knockback":float(exact.get("hitx",0))*BVNMotion.VELOCITY_UNIT,"stun":float(exact.get("hurtTime",300))*.001,"area":audit,"owner_x":position.x,"owner_facing":facing},true)
		result.append(hit)
	return result

func _source_move_definition(move: String,label: String="") -> Dictionary:
	var profile_id: String=source_active_profile_id()
	var binding: Dictionary={}
	if label.is_empty():
		var key: String=_source_command_key(move)
		var permission: Dictionary=source_permissions.get(key,{})
		label=str(permission.get("label",""))
		profile_id=str(permission.get("profile_id",profile_id))
		if source_bindings_enabled: binding=SourceBindings.binding_for(fighter_id,move)
		if not binding.is_empty() and permission.is_empty(): profile_id=str(binding["donor_profile_id"])
	else:
		binding=SourceBindings.binding_for(fighter_id,source_entry_command) if source_bindings_enabled else {}
		if label.is_empty(): label=str({"attack1":"砍1","attack2":"砍2","attack3":"砍3","attack4":"砍4","attack5":"砍5","sweep":"砍技1","launcher":"砍技2","skill1":"招1","skill2":"招3","skill3":"招2","air_light":"跳砍","air_skill":"跳招","air_slam":"跳招-下","super":"必杀","super_up":"上必杀","super_down":"超必杀","air_super":"空中必杀","throw":"摔1","dash":"瞬步"}.get(move,move))
	var definition: Dictionary=source_timeline.definition(profile_id,label)
	if definition.is_empty(): return {"move":move,"source_timeline":label,"no_box":true,"startup":0.0,"active":0.0,"recovery":0.0,"damage":0,"kind":"special"}
	var first: int=int(definition.get("frame_count",1))
	var last: int=0
	var hits: Array=[]
	for area: Dictionary in definition.get("areas",[]):
		if area.get("kind","")!="hit": continue
		hits.append(area)
		first=mini(first,int(area.get("relative_start",0))); last=maxi(last,int(area.get("relative_end",0)))
	var exact: Dictionary={}
	if not hits.is_empty():
		var wrapped: Dictionary=source_timeline.hit_vo(profile_id,str(hits[0].get("hit_id","")))
		exact=wrapped.get("effective",{})
	else: first=0
	return {"move":move,"source_timeline":label,"formal_profile":true,"startup":float(first)/30,"active":float(maxi(0,last-first))/30,"recovery":float(maxi(0,int(definition.get("frame_count",1))-last))/30,"damage":int(float(exact.get("power",0))),"kind":"super" if move.begins_with("super") or move=="air_super" else ("normal" if move.begins_with("attack") or move=="air_light" else "special"),"feedback":"super" if move.begins_with("super") or move=="air_super" else "light","label":str(binding.get("name_ja",label)),"source_profile_id":profile_id,"source_binding_id":str(binding.get("binding_id",source_binding_id)),"source_definition":definition,"source_hit_vo":exact,"no_box":hits.is_empty()}

func _source_start_action(request: String,reverse_dash: bool=false) -> bool:
	var key: String=_source_command_key(request)
	var slot: Dictionary=source_permissions.get(key,{})
	if hp<=0 or slot.is_empty() or state in ["hurt","launch","juggle","slam","down","getup","escape","burst","guard_stun","throw_hold","ko"]:
		reject_reason="接続できない"; return false
	var label: String=str(slot.get("label",""))
	var profile_id: String=str(slot.get("profile_id",source_active_profile_id()))
	if not source_has_label(label,profile_id): reject_reason="未登録の動作"; return false
	if source_bindings_enabled:
		if key in ["attackAIR","skillAIR","bishaAIR"] and grounded and source_action_state() not in [10,11,12,13]: reject_reason="空中専用"; return false
		if key in ["attack","skill1","skill2","zhao1","zhao2","zhao3","bisha","bishaUP","bishaSUPER","catch1","catch2"] and not grounded and source_action_state() not in [10,11,12,13]: reject_reason="地上専用"; return false
	if request=="jump":
		if jumps_remaining<=0: return false
		source_permissions.clear(); source_generation+=1; source_playing=false; source_doing_action=false; source_doing_air_action=false
		state="jump"; source_runtime_state=14; action=""; action_data.clear(); state_time=0; guarding=false; _clear_bvn_defense()
		jump_from_ground=grounded; source_jump_delay_frames=2 if grounded else 1
		jump_start_delay=float(source_jump_delay_frames)/30.0; jump_retrigger_delay=0
		source_is_jumping=true; source_jump_frame_count=0
		if grounded: _source_reaction_snapshot("起跳")
		invulnerable=0; grounded=false; air_time=0; source_allow_be_hit=true; source_cross=false
		action_started.emit("jump"); return true
	if request=="fastfall":
		if grounded: return false
		source_permissions.clear(); source_generation+=1; source_playing=false; source_doing_action=false
		source_is_jumping=false; source_jump_delay_frames=0; source_jump_frame_count=0; jump_start_delay=0
		jumps_remaining=0; velocity.y=5*BVNMotion.VELOCITY_UNIT; bvn_damping=Vector2(0,1); position.y+=1.6
		source_label=label; source_set_permission("touchFloor","落地",true); guarding=false; _clear_bvn_defense(); state="jump"
		return true
	if key in ["attackAIR","skillAIR","bishaAIR"] and not source_doing_action and air_hits_remaining<=0:
		reject_reason="空中行動済み"; return false
	if key in ["bisha","bishaUP","bishaSUPER","bishaAIR"]:
		var cost: float=float(slot.get("cost",300 if key=="bishaSUPER" else 100))
		if hype<cost: reject_reason="気が足りない"; return false
		hype-=cost
	if request=="dash":
		if not grounded and jumps_remaining<1: return false
		if not use_bvn_energy(20 if grounded else 30): return false
		if not grounded: jumps_remaining=0
	if key in ["attackAIR","skillAIR","bishaAIR"]:
		if key=="attackAIR": bvn_damping.y+=3; air_hits_remaining-=1; jumps_remaining=0
		elif key=="skillAIR":
			air_hits_remaining=0; jumps_remaining=0
			if source_is_jumping and not source_bindings_enabled:
				if bool(last_intent.get("source_up",false)) and source_has_label("跳招-上"): label="跳招-上"
				if (request=="air_slam" or bool(last_intent.get("guard",false))) and source_has_label("跳招-下"): label="跳招-下"
		else: air_hits_remaining=0
	var source_state: int=13 if key=="bishaSUPER" else (12 if key.begins_with("bisha") else (15 if request=="dash" else (10 if key in ["attack","attackAIR"] else 11)))
	# Native QK/SP permissions retain their exact alternate entry and cost.
	# The skin identity is orthogonal: objects/audio still belong to the
	# approved command without replacing the original source permission.
	if source_bindings_enabled and fighter_id in ["notify","wojak"] and str(slot.get("binding_id","")).is_empty():
		var identity: Dictionary=SourceBindings.binding_for(fighter_id,request)
		if not identity.is_empty() and profile_id==str(identity.get("donor_profile_id","")):
			var entry: String=str(identity.get("entry_label",""))
			if label==entry or label.begins_with(entry+"_"):
				slot=slot.duplicate();slot["binding_id"]=identity["binding_id"];slot["command"]=request
	source_move_profile_id=profile_id if source_bindings_enabled else ""
	source_entry_command=str(slot.get("command",request)); source_entry_label=label; source_binding_id=str(slot.get("binding_id",""))
	action=_source_label_command(label,request); source_runtime_state=source_state
	retreat=reverse_dash; armor_used=false; route_closed=false; contact_result=""
	if not source_branch(label,"",true,key in ["attackAIR","skillAIR","bishaAIR"]): return false
	if request=="dash":
		state="dash"; source_allow_be_hit=false; bvn_apply_gravity=false
	return true

func reset_round(x: float) -> void:
	source_ko_presentation.reset()
	authored_reset()
	position = Vector2(x, stage_floor_y)
	velocity = Vector2.ZERO
	bvn_reverse_velocity=0.0; bvn_reverse_damping=0.0
	hurt_fly_recovery_frame=0
	hp = source_hp_max if source_runtime_enabled else 1000.0
	hurt_break_state.clear(); last_hurt_bisha=false; hurt_chain_break=false; current_hurt_power=0
	energy=100.0; energy_overload=false; energy_gap=0; energy_clock=0.0
	hype = 0.0
	facing = 1 if player_index == 0 else -1
	state = "idle"
	state_time = 0.0
	action = ""
	action_data.clear()
	hit_targets.clear()
	attack_hit = false
	spawned_prop = false
	armor_used = false
	grounded = true
	crouching = false
	guarding = false
	bvn_defense=BVNDefense.fresh(); bvn_defense_game_clock=0; bvn_defense_animation_clock=0
	invulnerable = 0.15
	hurt_flash = 0.0
	guard_flash = 0.0
	air_time = 0.0
	air_hits_remaining=BVNAir.DEFAULT_AIR_HITS; jumps_remaining=BVNAir.DEFAULT_JUMPS
	jump_start_delay=0.0; jump_retrigger_delay=0.0; bvn_motion.reset()
	bvn_damping=Vector2(0,.5); hurt_fly.clear(); hurt_fly_clock=0.0; hurt_fly_window=0.0
	bvn_apply_gravity=true
	crouch_time = 0.0
	crouch_release_time = 0.0
	combo_hits = 0
	combo_reset = 0.0
	burst_used = false
	ghost_source_state = 0
	emotion = "happy"
	preview_animation = ""
	trail.clear()
	attack_contact=false; contact_result=""; route_closed=false
	clear_buffer(); dash_cooldown=0; air_dash_used=false; air_light_used=false; air_slam_used=false
	combo_launch_used=false; combo_air_light_hit=false; combo_damage=0; last_combo_hits=0; last_combo_damage=0
	protection_min=0; landing_safety=0
	if source_runtime_enabled:
		source_unsupported.clear(); source_frame_trace.clear(); source_generation+=1
		source_animation_clock=0; source_external_animation_clock=false; source_animation_boundary=false; source_is_touch_floor=true
		source_just_hurt_resume=false
		source_idle()
	queue_redraw()

## Ported from FighterMcFloorHandler.allowCatch, preserving direction and strict <2px edge / <1px floor-height gaps.
## Logical stage units are 1.6x the original 800px Flash screen.
func bvn_resource_state() -> Dictionary:
	return {"energy":energy,"energy_max":100.0,"energy_overload":energy_overload,"energy_gap":energy_gap,"energy_clock":energy_clock,"action_state":source_action_state()}

func _apply_bvn_resource(next: Dictionary) -> void:
	energy=float(next.get("energy",energy))
	energy_overload=bool(next.get("energy_overload",energy_overload))
	energy_gap=int(next.get("energy_gap",energy_gap))
	energy_clock=float(next.get("energy_clock",energy_clock))

func use_bvn_energy(amount: float) -> bool:
	if not BVNHit.has_energy(energy,amount,energy_overload,true): return false
	_apply_bvn_resource(BVNHit.use_energy(bvn_resource_state(),amount))
	return true

func allow_bvn_catch(target: Node2D) -> bool:
	if target.state=="hurt": return false
	var self_body:=body_box()
	var target_body: Rect2=target.body_box()
	var dx: float
	if self_body.position.x<target_body.position.x:
		if facing<0: return false
		dx=target_body.position.x-self_body.end.x
	else:
		if facing>0: return false
		dx=self_body.position.x-target_body.end.x
	return dx<3.2 and absf(position.y-target.position.y)<1.6

func body_box() -> Rect2:
	if source_runtime_enabled:
		if source_bindings_enabled and source_active_profile_id()!=SourceBindings.base_profile_id(fighter_id):
			var base_local:=Rect2((source_idle_body.position-source_foot_anchor)*BVNAir.STAGE_UNIT_SCALE,source_idle_body.size*BVNAir.STAGE_UNIT_SCALE)
			if facing<0: base_local.position.x=-base_local.end.x
			base_local.position+=position
			return base_local
		var exact: Rect2=_source_rect(source_snapshot.get("body_area",source_idle_body))
		if exact.size.x<=0 or exact.size.y<=0: return Rect2()
		return _source_world_rect(exact)
	var crouch_ratio := 0.42 if fighter_id=="shark" and action=="skill1" else 0.53
	var h := body_height * (crouch_ratio if crouching else 1.0)
	return Rect2(position + Vector2(-body_width * 0.5, -h), Vector2(body_width, h))

func is_locked() -> bool:
	return state in ["hurt","launch","juggle","slam","down","getup","escape","burst","guard_stun","throw_hold","ko","attack","dash"]

func is_combo_locked() -> bool:
	return state in ["hurt","launch","juggle","slam","throw_hold"]

func is_protected() -> bool:
	return (source_runtime_enabled and not source_allow_be_hit) or state in ["escape","burst"] or invulnerable>0.0 or (not hurt_break_state.is_empty() and not bool(hurt_break_state.get("allow_be_hit",true)))

func is_attacking() -> bool:
	return state=="attack" and not action_data.is_empty()

## Source FighterMcCtrler.endAct clears actions AND reports FREEZE to the AI.
## Public normals use exact XML events. Meme resources use the same bounded
## endAct registration already used by their cancel flags; recovery still runs.
func end_act_reached() -> bool:
	if authored_is_active(): return authored_skill_runtime.stage=="recovery"
	if source_runtime_enabled: return source_doing_action and source_runtime_state==40
	if not is_attacking(): return false
	if action in ["attack1","attack2","attack3"]:
		return bool(BVNTimeline.sample_normal(int(action.trim_prefix("attack")),action_time).get("ended_permissions",false))
	return action_time>=float(action_data.get("startup",.1))+float(action_data.get("active",.1))+2.0/30.0

## The actual action flag is sampled for both human input and the source AI.
## NPC J-chain events are exact upstream data. Additional meme routes explicitly
## adapt that same frame permission slot; skill/air clips have their own short events.
func frame_action_flags() -> Dictionary:
	if authored_is_active():
		return {"bisha":authored_skill_runtime.can_cancel("super"),"bishaSUPER":authored_skill_runtime.can_cancel("super_down")}
	var flags: Dictionary={}
	for key in ["attack","attackAIR","skill1","skill2","zhao1","zhao2","zhao3","skillAIR","bisha","bishaUP","bishaSUPER","bishaAIR","jump","jumpDown","dash","defense","moveLEFT","moveRIGHT"]: flags[key]=false
	if source_runtime_enabled:
		if state in ["hurt","launch","juggle","slam","down","getup","escape","burst","guard_stun","throw_hold","ko"]: return flags
		for key: String in source_permissions:
			var value: Dictionary=source_permissions[key]
			flags[key]=bool(value.get("enabled",not str(value.get("label","")).is_empty()))
		if bool(flags.get("jumpQuick",false)): flags["jump"]=true
		return flags
	if state=="guard":
		flags.merge(BVNDefense.actions(),true)
		return flags
	if not is_locked():
		for key in flags: flags[key]=true
		return flags
	if not is_attacking(): return flags
	var confirmed:=attack_hit and not route_closed
	if action in ["attack1","attack2","attack3"]:
		var normal:=int(action.trim_prefix("attack"))
		var sample:=BVNTimeline.sample_normal(normal,action_time)
		flags["attack"]=bool(sample.get("can_chain",false))
		# Meme cast adapter: WJ/SJ are additional routes, absent from the public NPC.
		# They share setAttack's bounded slot; endAct clears ALL these extensions.
		if confirmed and flags["attack"]:
			for key in ["skill1","skill2","zhao1","zhao2","zhao3","bisha","bishaUP","bishaSUPER"]: flags[key]=true
		return flags
	var startup:=float(action_data.get("startup",.1))
	var active:=float(action_data.get("active",.1))
	# Godot meme-resource events: clearActions on start; early recovery endAct.
	# No permission extends through the whole recovery as it did previously.
	var chain_open:=confirmed and action_time>=startup+.015 and not end_act_reached()
	if chain_open:
		if action=="launcher": flags["jump"]=true
		if action in ["air_light","air_skill"]: flags["skillAIR"]=true
		if action in ["skill1","skill2"]:
			for key in ["bisha","bishaUP","bishaSUPER"]: flags[key]=true
	return flags

func command_enabled(command: String) -> bool:
	command=_normalize_command(command)
	if authored_skills_enabled and fighter_id=="chicken" and command in ["super","super_up","super_down","air_super"] and not _authored_runtime().ball_in_hand(): return false
	if authored_is_active(): return authored_skill_runtime.can_cancel(command)
	# renderHurtFlying reads dashJump independently of normal action slots.
	if command=="dash" and can_bvn_floor_recovery(): return true
	if source_runtime_enabled:
		var key: String=_source_command_key(command)
		return bool(frame_action_flags().get(key,false))
	var keys: Dictionary={"attack":"attack" if grounded else "attackAIR","attack1":"attack","attack2":"attack","attack3":"attack","sweep":"skill1","launcher":"skill2","skill1":"zhao1","skill2":"zhao3","skill3":"zhao2","air_light":"attackAIR","air_skill":"skillAIR","air_slam":"skillAIR","super":"bisha","super_up":"bishaUP","super_down":"bishaSUPER","air_super":"bishaAIR","jump":"jump","fastfall":"jumpDown","dash":"dash"}
	if keys.has(command): return BVNInput.enabled_action(frame_action_flags(),str(keys[command]))
	if command=="throw" and state=="guard": return false
	return not is_locked()

func source_action_label() -> String:
	if source_runtime_enabled: return source_label
	return "砍"+action.trim_prefix("attack") if action in ["attack1","attack2","attack3"] else action

func source_action_state() -> int:
	if authored_is_active(): return 13 if action=="super_down" else (12 if action in ["super","super_up"] else 11)
	if state=="ko": return 30
	# GhostHandler changes velocity/frames and protection, but preserves actionState.
	if state=="burst": return ghost_source_state
	if source_runtime_enabled and state in ["attack","dash","getup"] and (source_doing_action or source_playing): return source_runtime_state
	if is_attacking():
		if end_act_reached(): return 40
		if action_data.get("kind","")=="super": return 13 if action=="super_down" else 12
		if action in ["sweep","launcher","air_slam","throw"]: return 11
		return 11 if action_data.get("kind","")=="special" else 10
	if state in ["guard","guard_stun"]: return 20
	if not hurt_fly.is_empty():
		var fly_phase:=int(hurt_fly.get("phase",1))
		return 24 if fly_phase==3 else (23 if fly_phase==4 else 22)
	if state in ["down","getup","slam"]: return 23
	if is_combo_locked(): return 21
	if state=="dash": return 15
	if not grounded: return 14
	return 40 if is_locked() else 0

func attack_range(move: String) -> Rect2:
	var data: Dictionary=action_data if move==action and is_attacking() else move_definition(move)
	if source_runtime_enabled:
		var source_definition: Dictionary=data.get("source_definition",{})
		var source_bounds: Rect2=Rect2()
		var found: bool=false
		for area: Dictionary in source_definition.get("areas",[]):
			if area.get("kind","")!="hit": continue
			var rect: Rect2=source_rect_to_world(area,str(data.get("source_profile_id",source_active_profile_id())))
			source_bounds=source_bounds.merge(rect) if found else rect; found=true
		return source_bounds
	# FighterMC.currentArea is animation-resource geometry in the source engine.
	# Predict our actual striking part for AI, retaining every original timing rule.
	if _uses_pixel_body() and move!="throw" and not bool(data.get("no_box",false)):
		var clip: String="super" if move=="air_super" else move
		return HitGeometry.move_bounds(fighter_id,clip,body_height,facing,position)
	if move in ["attack1","attack2","attack3"]:
		var local:=BVNTimeline.normalized_hit_rect(int(move.trim_prefix("attack")),body_height,facing)
		return Rect2(position+local.position,local.size)
	var reach:=float(data.get("range",95))
	var offset:=body_width*.28
	return Rect2(position+Vector2(offset if facing>0 else -offset-reach,float(data.get("y",-145))),Vector2(reach,float(data.get("height",110))))

func _hit_frame_active() -> bool:
	if source_runtime_enabled: return source_doing_action and not source_snapshot.get("hits",[]).is_empty()
	if not is_attacking() or action_data.get("no_box",false): return false
	if action in ["attack1","attack2","attack3"]:
		return bool(BVNTimeline.sample_normal(int(action.trim_prefix("attack")),action_time).get("active",false))
	else:
		var start:=float(action_data.get("startup",.1))
		return action_time>=start and action_time<start+float(action_data.get("active",.1))

func active_hit_geometry() -> Dictionary:
	if source_runtime_enabled: return {"ready":false,"source_collision":true}
	if not _hit_frame_active() or action=="throw" or not _uses_pixel_body(): return {"ready":false}
	var visual:=pixel_animation_state()
	return HitGeometry.sample(fighter_id,visual["clip"],visual["progress"],body_height,facing,position,true,false)

func active_box() -> Rect2:
	if source_runtime_enabled:
		var areas: Array[Dictionary]=source_frame_hits()
		return areas[0]["area"] if not areas.is_empty() else Rect2()
	if not _hit_frame_active(): return Rect2()
	var geometry:=active_hit_geometry()
	return geometry["bounds"] if geometry.get("ready",false) else attack_range(action)

func _normal_frame_events() -> void:
	var normal:=int(action.trim_prefix("attack"))
	var current:=BVNTimeline.source_frame(action_time)
	for event in BVNTimeline.events_between(normal,source_normal_frame,current):
		for call in event["calls"]:
			var args: Array=call.get("arguments",[])
			match str(call["method"]):
				"movePercent": velocity=Vector2(float(args[0])*speed*facing,float(args[1])*speed)
				"dampingPercent": bvn_damping=Vector2(float(args[0]),float(args[1]))*(speed/BVNMotion.VELOCITY_UNIT)
	source_normal_frame=current

func contact_point(overlap: Rect2) -> Vector2:
	var point:=overlap.get_center()
	if pixel_script and pixel_script.has_method("get_pose_state"):
		var visual:=pixel_animation_state()
		var pose: Dictionary=pixel_script.get_pose_state(fighter_id,visual["clip"],visual["progress"])
		var key := "weapon_tip" if fighter_id in ["rio","worker"] else ("shoe_tip" if fighter_id=="shark" else "paw_tip")
		if pose.has(key):
			var local: Vector2=pose[key]
			point=position+Vector2(local.x*facing,local.y)
	return Vector2(clampf(point.x,overlap.position.x,overlap.end.x),clampf(point.y,overlap.position.y,overlap.end.y))

func can_counter(source: Dictionary) -> bool:
	if source_runtime_enabled: return false # Real setHurtAction is resolved by beHit.
	return fighter_id=="cat" and is_attacking() and action=="skill2" and action_time>=0.05 and action_time<=0.25 and source.get("kind","normal")=="normal" and not attack_hit

func clear_buffer() -> void:
	pending_command=""
	buffer_life=0.0

func buffer_action(command: String,lifetime: float=BVNInput.INPUT_DELAY) -> void:
	if command.is_empty(): return
	pending_command=command
	buffer_life=lifetime

func _end_combo() -> void:
	if combo_hits>0:
		last_combo_hits=combo_hits
		last_combo_damage=combo_damage
		combo_reset=0.85
	combo_hits=0
	current_hurt_power=0.0
	last_hurt_bisha=false; hurt_chain_break=false
	combo_damage=0
	combo_launch_used=false
	combo_air_light_hit=false

func _normalize_command(command: String) -> String:
	var aliases := {"light":"attack","heavy":"attack3","air":"air_light","special1":"skill1","special2":"skill2","special3":"skill3"}
	return str(aliases.get(command,command))

func start_action(request: String, reverse_dash := false) -> bool:
	request=_normalize_command(request)
	if source_bindings_enabled and request=="air_slam": request="air_skill"
	reject_reason=""
	if authored_skills_enabled and grounded and _authored_runtime().has_slot(request):
		return authored_skill_runtime.begin(request)
	if authored_skills_enabled and fighter_id=="chicken" and request in ["super_up","air_super"] and not _authored_runtime().ball_in_hand():
		reject_reason="ボール回収中"; authored_skill_runtime.hint=reject_reason; authored_skill_runtime.hint_time=1.1; return false
	if authored_is_active(): reject_reason="技の後隙です"; return false
	if source_runtime_enabled: return _source_start_action(request,reverse_dash)
	if hp<=0 or state in ["hurt","launch","juggle","slam","down","getup","escape","burst","guard_stun","throw_hold","ko"]:
		reject_reason="行動できない"
		return false
	if request=="jump":
		var jump_cancel := state=="attack" and action=="launcher" and command_enabled("jump")
		if not BVNAir.can_jump(jumps_remaining) or jump_retrigger_delay>0 or not command_enabled("jump") or (is_locked() and not jump_cancel):
			reject_reason="跳べない"
			return false
		state="jump"
		action=""
		action_data.clear()
		state_time=0.0
		jump_from_ground=grounded
		jump_start_delay=BVNAir.jump_delay(grounded)
		jump_retrigger_delay=4.0/BVNAir.ANIMATION_FPS
		invulnerable=0.0
		grounded=false
		guarding=false
		_clear_bvn_defense()
		air_time=0.0
		air_dash_used=false
		action_started.emit("jump")
		return true
	if request=="fastfall":
		if grounded or is_locked(): return false
		velocity.y=maxf(velocity.y,820.0)
		return true
	if request=="dash":
		if is_locked() or not command_enabled("dash") or dash_cooldown>0 or (not grounded and air_dash_used):
			reject_reason="ステップ待ち"
			return false
		if not use_bvn_energy(20.0 if grounded else 30.0):
			reject_reason="体力回復待ち"
			return false
		state="dash"
		state_time=0.0
		action="dash"
		action_time=0.0
		dash_direction=-facing if reverse_dash else facing
		dash_cooldown=0.0
		invulnerable=0.27
		if not grounded: air_dash_used=true
		guarding=false
		_clear_bvn_defense()
		clear_buffer()
		action_started.emit("dash")
		return true
	if request=="attack":
		if not grounded: request="air_light"
		elif is_attacking() and action in ["attack1","attack2"]: request="attack2" if action=="attack1" else "attack3"
		else: request="attack1"
	if not grounded and request in ["attack1","attack2","attack3"]: request="air_light"
	if not grounded and request not in ["air_light","air_skill","air_slam","air_super"]:
		reject_reason="地上専用"
		return false
	if grounded and request in ["air_light","air_skill","air_slam","air_super"]:
		reject_reason="空中専用"
		return false
	if request in ["air_light","air_skill","air_slam","air_super"] and not BVNAir.can_air_action(is_attacking(),air_hits_remaining):
		reject_reason="空中追撃済み"
		return false
	if not command_enabled(request):
		reject_reason="接続できない"
		return false

	if (request.begins_with("super") or request=="air_super") and hype<(300 if request=="super_down" else 100):
		reject_reason="熱量不足"
		return false
	if request=="throw" and not grounded: return false
	if not ["attack1","attack2","attack3","sweep","launcher","skill1","skill2","skill3","air_light","air_skill","air_slam","super","super_down","super_up","air_super","throw"].has(request): return false
	action=request
	action_serial+=1
	state="attack"
	state_time=0.0
	action_time=0.0
	source_normal_frame=-1
	invulnerable=0.0
	guarding=false
	_clear_bvn_defense()
	crouching=false
	attack_hit=false
	attack_contact=false
	contact_result=""
	route_closed=false
	spawned_prop=false
	armor_used=false
	retreat=reverse_dash
	hit_targets.clear()
	action_data=move_definition(request)
	## FighterMcCtrler.doAction resets BOTH impulse components and damping.
	velocity=Vector2.ZERO
	bvn_damping=Vector2.ZERO
	bvn_apply_gravity=true # FighterMcCtrler.doAction:889 restores isApplyG.
	if request in ["attack1","attack2","attack3"]: _normal_frame_events()
	if request.begins_with("super") or request=="air_super": hype-=300 if request=="super_down" else 100
	if request in ["air_light","air_skill","air_slam","air_super"]:
		var budget:=BVNAir.begin_air_bisha(jumps_remaining) if request=="air_super" else BVNAir.begin_air_action(air_hits_remaining,request!="air_light")
		air_hits_remaining=budget["air_hits"]; jumps_remaining=budget["jumps"]
	if request=="air_light": air_light_used=true
	if request=="air_slam": air_slam_used=true
	if fighter_id=="cat": emotion="huh" if request=="skill2" else ("cry" if request=="skill3" else "happy")
	action_started.emit(request)
	queue_redraw()
	return true

func move_definition(move: String) -> Dictionary:
	move=_normalize_command(move)
	if source_runtime_enabled: return _source_move_definition(move)
	var legacy := {"attack":"light","attack1":"light","attack2":"light","attack3":"heavy","air_light":"air","skill1":"special1","skill2":"special2","skill3":"special3","super_down":"super","super_up":"super","air_super":"super"}
	var base: Dictionary=_legacy_move_definition(str(legacy.get(move,move)))
	base["move"]=move
	base["reaction"]="hurt"
	base["feedback"]="light"
	if move in ["attack1","attack2","attack3"]: base["y"]=-body_height*0.72
	if move=="attack2": base.merge({"startup":0.115,"active":0.095,"recovery":0.22,"range":125.0 if fighter_id=="rio" else 110.0,"label":"二撃！"},true)
	elif move=="attack3": base.merge({"startup":0.19,"active":0.11,"recovery":0.35,"feedback":"heavy","label":"三撃！"},true)
	elif move=="launcher": base.merge({"startup":0.17,"active":0.12,"recovery":0.34,"damage":85,"source_hity":-5.0,"impulse_reference":"zako/ninja_earth1/main_mc.xml:zh1","range":135.0 if fighter_id=="rio" else 108.0,"height":190.0,"y":-185.0,"knockback":25.0,"stun":0.48,"reaction":"launch","feedback":"launch","label":"打ち上げ！"},true)
	elif move=="sweep": base.merge({"startup":0.22,"active":0.14,"recovery":0.43,"damage":100,"range":160.0 if fighter_id=="rio" else 125.0,"height":65.0,"y":-70.0,"knockback":90.0,"stun":0.43,"reaction":"down","feedback":"slam","label":"足払い！"},true)
	elif move=="air_light": base.merge({"startup":0.09,"active":0.16,"recovery":0.20,"damage":70,"range":125.0,"height":165.0,"y":-165.0,"knockback":15.0,"stun":0.43,"feedback":"light","label":"空中追撃！"},true)
	elif move=="air_skill": base.merge({"startup":0.15,"active":0.18,"recovery":0.27,"damage":90,"range":165.0,"height":170.0,"y":-170.0,"knockback":50.0,"stun":0.43,"kind":"special","feedback":"heavy","label":"空中ミーム！"},true)
	elif move=="air_slam": base.merge({"startup":0.12,"active":0.19,"recovery":0.32,"damage":110,"range":145.0,"height":210.0,"y":-170.0,"knockback":70.0,"stun":0.5,"reaction":"slam","feedback":"slam","label":"叩き落とし！"},true)
	elif move=="throw": base["reaction"]="down"; base["feedback"]="heavy"
	elif move.begins_with("super") or move=="air_super":
		base["feedback"]="super"
		if move=="super_down": base.merge({"startup":0.35,"active":0.20,"range":250.0,"height":105.0,"y":-105.0,"reaction":"down","label":"地上ミーム解放！"},true); base.erase("no_box"); base.erase("spawn")
		elif move=="super_up": base.merge({"startup":0.28,"active":0.22,"range":175.0,"height":325.0,"y":-330.0,"label":"天空ミーム解放！"},true); base.erase("no_box"); base.erase("spawn")
	elif move.begins_with("skill"):
		base["feedback"]="heavy" if int(base.get("damage",65))>=100 else "light"
	if move in ["attack1","attack2","attack3"]:
		var source:=BVNTimeline.normal_definition(int(move.trim_prefix("attack")))
		var hit: Dictionary=source["hit_vo_effective"]
		base.merge({"startup":source["startup"],"active":source["active"],"recovery":source["recovery"],"damage":source["damage"],"knockback":float(hit.get("hitx",0))*BVNMotion.VELOCITY_UNIT,"stun":float(hit.get("hurtTime",0))*.001,"reaction":"hurt","source_hit_vo":hit,"source_timeline":source["source_label"],"feedback":"heavy" if move=="attack3" else "light"},true)
	base["block_stun"]=0.16 if base["feedback"]=="light" else 0.23
	return base

func _legacy_move_definition(move: String) -> Dictionary:
	var base := {"startup": 0.10, "active": 0.10, "recovery": 0.20, "damage": 65, "range": 95.0, "height": 110.0, "y": -145.0, "knockback": 95.0, "stun": 0.33, "kind": "normal", "label": "パシッ"}
	if move == "heavy":
		base.merge({"startup": 0.24, "active": 0.13, "recovery": 0.32, "damage": 105, "range": 140.0, "knockback": 220.0, "stun": 0.40, "label": "ドン！"}, true)
	elif move == "air":
		base.merge({"startup": 0.12, "active": 0.18, "recovery": 0.21, "damage": 80, "range": 100.0, "height": 130.0, "y": -150.0, "knockback": 150.0, "label": "バシッ"}, true)
	elif move == "throw":
		base.merge({"startup": 0.08, "active": 0.12, "recovery": 0.36, "damage": 90, "range": 62.0, "height": 165.0, "y": -170.0, "knockback": 330.0, "stun": 0.46, "kind": "throw", "label": "ぽいっ！"}, true)
	elif move == "super":
		var reach := 210.0
		if fighter_id == "cat" or fighter_id == "worker":
			reach = 165.0
		base.merge({"startup": 0.27, "active": 0.17, "recovery": 0.58, "damage": 260, "range": reach, "height": 175.0, "y": -185.0, "knockback": 400.0, "stun": 0.8, "kind": "super", "label": "超ミーム！！"}, true)
		if fighter_id == "chicken":
			base.merge({"no_box": true, "spawn": "superball", "spawn_at": 0.27}, true)
	elif move.begins_with("special"):
		base.merge({"kind": "special", "startup": 0.20, "active": 0.16, "recovery": 0.35, "damage": 100, "label": "ミーム！"}, true)
		match fighter_id:
			"shark":
				if move == "special1":
					base.merge({"startup": 0.14, "active": 0.27, "recovery": 0.40, "damage": 100, "range": 110.0, "height": 80.0, "y": -75.0, "dash": 620.0, "label": "シューズ・ダッシュ"}, true)
				elif move == "special2":
					base.merge({"startup": 0.13, "active": 0.24, "recovery": 0.48, "damage": 110, "range": 85.0, "height": 245.0, "y": -255.0, "label": "三脚スピン"}, true)
				else:
					base.merge({"startup": 0.24, "active": 0.34, "recovery": 0.45, "damage": 120, "range": 115.0, "height": 170.0, "y": -130.0, "hop": -500.0, "hop_damping_y": .5, "dash": 350.0, "label": "ビーチ・プレス"}, true)
			"cat":
				if move == "special1":
					base.merge({"startup": 0.16, "active": 0.35, "recovery": 0.27, "damage": 85, "range": 95.0, "height": 145.0, "y": -135.0, "hop": -610.0, "hop_damping_y": .5, "dash": 280.0, "label": "ハッピー・ジャンプ"}, true)
				elif move == "special2":
					base.merge({"startup": 0.05, "active": 0.20, "recovery": 0.39, "damage": 75, "no_box": true, "label": "Huh？"}, true)
				else:
					base.merge({"startup": 0.26, "active": 0.10, "recovery": 0.36, "no_box": true, "spawn": "tear", "spawn_at": 0.26, "damage": 65, "label": "涙ころころ"}, true)
			"worker":
				if move == "special1":
					base.merge({"startup": 0.19, "active": 0.16, "recovery": 0.25, "damage": 70, "range": 130.0, "knockback": 410.0, "label": "お帰りください"}, true)
				elif move == "special2":
					base.merge({"startup": 0.12, "active": 0.30, "recovery": 0.31, "damage": 90, "range": 90.0, "dash": -440.0 if retreat else 520.0, "no_box": retreat, "label": "定時退社！"}, true)
				else:
					base.merge({"startup": 0.24, "active": 0.10, "recovery": 0.35, "no_box": true, "spawn": "book", "spawn_at": 0.24, "damage": 95, "label": "勉強したくない"}, true)
			"chicken":
				if move == "special1":
					base.merge({"startup": 0.29, "active": 0.10, "recovery": 0.35, "no_box": true, "spawn": "ball", "spawn_at": 0.29, "damage": 85, "label": "バスケ・パス"}, true)
				elif move == "special2":
					base.merge({"startup": 0.22, "active": 0.28, "recovery": 0.37, "damage": 105, "range": 110.0, "dash": 310.0, "label": "二年半ステップ"}, true)
				else:
					base.merge({"startup": 0.20, "active": 0.19, "recovery": 0.43, "damage": 110, "range": 100.0, "dash": 440.0, "armor": true, "label": "鉄山靠！"}, true)
			"rio":
				if move=="special1":
					base.merge({"startup":0.27,"active":0.10,"recovery":0.36,"no_box":true,"spawn":"blade_wave","spawn_at":0.27,"damage":85,"label":"蒼刃波"},true)
				elif move=="special2":
					base.merge({"startup":0.16,"active":0.24,"recovery":0.47,"damage":110,"range":105.0,"height":265.0,"y":-277.0,"label":"昇天斬"},true)
				else:
					base.merge({"startup":0.34,"active":0.20,"recovery":0.48,"damage":125,"range":165.0,"armor":true,"dash":80.0,"label":"蒼鋼・溜め斬り"},true)
	if fighter_id == "shark" and move == "heavy":
		base["range"] = 175.0
	if fighter_id=="rio":
		if move=="light":
			base.merge({"range":120.0,"label":"シュッ"},true)
		elif move=="heavy":
			base.merge({"range":180.0,"startup":0.27,"label":"斬！"},true)
		elif move=="super":
			base.merge({"range":240.0,"startup":0.32,"height":200.0,"y":-220.0,"label":"蒼月・断界！"},true)
	return base

func _clear_bvn_defense() -> void:
	bvn_defense=BVNDefense.clear(bvn_defense)
	guarding=false

func _enter_bvn_defense(turn_axis: float=0) -> void:
	state="guard"; state_time=0
	if absf(turn_axis)>.1: facing=1 if turn_axis>0 else -1
	bvn_defense=BVNDefense.enter(bvn_defense)
	guarding=bool(bvn_defense["guard"])
	# doDefense's dampingPercent(1,1) stops any incoming walk impulse;
	# raw direction keys inside defense are facing requests, never movement.
	bvn_damping=Vector2.ONE*(speed/BVNMotion.VELOCITY_UNIT)
	if source_runtime_enabled:
		_source_clear_move_context()
		source_generation+=1; source_playing=false; source_doing_action=false; source_label="防御"; source_frame=0
		source_runtime_state=20; _source_defense_slots()
		source_snapshot=source_timeline.sample_frame(fighter_id,source_label,0)

func _source_defense_slots() -> void:
	source_permissions.clear()
	for setter: String in ["setSkill1","setZhao2","setBishaSUPER","setJumpDown"]:
		PlayableEvents.execute_event(self,{"calls":[{"controller":"mc","method":setter,"arguments":[]}]})

func _source_reaction_snapshot(label: String) -> void:
	if not source_runtime_enabled: return
	_source_clear_move_context()
	source_label=label; source_frame=0; source_snapshot=source_timeline.sample_frame(fighter_id,label,0)
	source_absolute_frame=int(source_snapshot.get("source_frame",0))

func source_hurt_fly(x: float,y: float) -> void:
	source_generation+=1; source_playing=false; source_doing_action=false
	source_runtime_state=22; source_permissions.clear()
	var hit_x: float=x*facing
	velocity=Vector2(hit_x,y)*BVNMotion.VELOCITY_UNIT
	if hit_x!=0: facing=-1 if hit_x>0 else 1
	hurt_fly=BVNHit.start_hurt_fly(Vector2(hit_x,y),not grounded,position.y/BVNAir.STAGE_UNIT_SCALE)
	hurt_fly_clock=0; hurt_fly_window=0; hurt_fly_recovery_frame=0; state="launch"; state_time=0
	bvn_damping=Vector2(0,.5); bvn_apply_gravity=true
	_source_reaction_snapshot("击飞")

func _render_bvn_defense(delta: float,intent: Dictionary) -> void:
	bvn_defense_animation_clock+=delta
	while bvn_defense_animation_clock+.0000001>=1.0/BVNDefense.ANIMATION_FPS:
		bvn_defense_animation_clock-=1.0/BVNDefense.ANIMATION_FPS
		if state not in ["guard","guard_stun"]: continue
		var was_resume_pending: bool=bool(bvn_defense.get("resume_pending",false))
		var rendered:=BVNDefense.render_animate(bvn_defense,bool(intent.get("guard",false)),state=="guard_stun")
		bvn_defense=rendered["next"]
		guarding=bool(bvn_defense["guard"])
		# goFrame(DEFENSE_RESUME,{call:idle,delay:1}) exposes its visual
		# label for this animation tick; the existing next-tick idle below
		# still owns the release timing and permission restoration.
		if fighter_id in ["notify","wojak"] and source_runtime_enabled and not was_resume_pending and bool(bvn_defense.get("resume_pending",false)) and source_has_label("防御恢复"):
			_source_reaction_snapshot("防御恢复")
		if rendered["idle"]:
			state="idle" if grounded else "jump"; state_time=0
			velocity=Vector2.ZERO; bvn_damping=Vector2.ZERO; bvn_apply_gravity=true
			if source_runtime_enabled: source_idle()

func _source_enter_move() -> void:
	source_permissions.clear()
	for setter: String in ["setMove","setAttack","setZhao1","setZhao3","setSkill2","setJump","setDash","setBisha","setBishaUP","setDefense","setCatch1","setCatch2"]:
		PlayableEvents.execute_event(self,{"calls":[{"controller":"mc","method":setter,"arguments":[]}]})
	source_runtime_state=0; source_doing_action=false
	if source_has_label("走"): source_branch("走")

func set_bvn_reverse_push(source_velocity: float,source_damping: float) -> void:
	bvn_reverse_velocity=source_velocity; bvn_reverse_damping=source_damping

func advance(delta: float, intent: Dictionary, opponent_x: float) -> void:
	# FighterMcCtrler.renderHurtFlying is one callback per GAME tick, not
	# animation time: bounce resets1 then increments2; early down keeps counting.
	if hurt_fly.is_empty(): hurt_fly_recovery_frame=0
	elif int(hurt_fly.get("phase",0))==3: hurt_fly_recovery_frame=2
	elif hurt_fly_recovery_frame>0: hurt_fly_recovery_frame+=1
	var entered_state:=state
	last_intent=intent
	if authored_is_active():
		authored_input(intent)
		authored_skill_runtime.step(delta)
	if source_runtime_enabled and not authored_is_active():
		_source_animation_step(delta)
		_source_render_animation_prelude()
		# renderAirAction calls fall on the next game tick after ascent ends.
		if state=="jump" and not grounded and not source_doing_action and not source_is_jumping and source_jump_delay_frames==0 and source_label not in ["落","防御"]: source_idle()
	if source_runtime_enabled and state=="idle":
		source_auto_direct_clock+=delta
		if source_auto_direct_clock+.0000001>=6.0/30.0:
			source_auto_direct_clock=0; facing=1 if opponent_x>=position.x else -1
	if state!="burst":
		bvn_defense_game_clock+=delta
		while bvn_defense_game_clock+.0000001>=1.0/BVNDefense.GAME_FPS:
			bvn_defense_game_clock-=1.0/BVNDefense.GAME_FPS
			bvn_defense=BVNDefense.tick_game(bvn_defense)
	if state in ["guard","guard_stun"]:
		var turn_axis:=float(intent.get("axis",0))
		var turn:=1 if turn_axis>0 else -1
		if absf(turn_axis)>.1 and facing!=turn:
			facing=turn
			bvn_defense=BVNDefense.enter(bvn_defense,state=="guard_stun")
			guarding=bool(bvn_defense["guard"])
	state_time+=delta
	_apply_bvn_resource(BVNHit.tick_energy(bvn_resource_state(),delta))
	jump_retrigger_delay=maxf(0,jump_retrigger_delay-delta)
	walk_clock+=delta
	invulnerable=maxf(0,invulnerable-delta)
	hurt_flash=maxf(0,hurt_flash-delta)
	guard_flash=maxf(0,guard_flash-delta)
	dash_cooldown=maxf(0,dash_cooldown-delta)
	combo_reset=maxf(0,combo_reset-delta)
	if combo_reset<=0 and combo_hits==0: last_combo_hits=0
	if hp<=0: state="ko"
	_advance_hurt_break(delta)
	if not hurt_fly.is_empty():
		clear_buffer()
	elif state=="burst":
		clear_buffer()
		if state_time>=.4 or (action=="ghost_down" and grounded):
			state="idle" if grounded else "jump"; action=""; state_time=0; velocity.x=0
			invulnerable=0.0; _end_combo()
			if source_runtime_enabled: source_idle()
	elif state=="escape":
		clear_buffer()
		protection_min=maxf(0,protection_min-delta)
		landing_safety=maxf(0,landing_safety-delta) if grounded else 0.12
		invulnerable=maxf(invulnerable,0.03)
		velocity.x=move_toward(velocity.x,0,delta*700)
		if protection_min<=0 and grounded and landing_safety<=0:
			state="idle"; state_time=0; invulnerable=0.0; _end_combo()
	elif state in ["hurt","launch","juggle","slam","guard_stun","throw_hold"]:
		clear_buffer()
		if state_time>=float(action_data.get("hurt_length",0.33)) and (state!="guard_stun" or velocity.x==0):
			var entering_source_state: int=source_action_state()
			bvn_apply_gravity=true # Source idle() restores gravity before idle/fall.
			if grounded:
				state="guard" if state=="guard_stun" else "idle"
				state_time=0; _end_combo()
			else:
				state="jump"; state_time=0; _end_combo()
			if source_runtime_enabled:
				if state=="guard": _source_defense_slots()
				else: source_idle("站立",entering_source_state)
	elif state=="down":
		clear_buffer()
		velocity.x=move_toward(velocity.x,0,delta*900)
		if grounded and state_time>=0.42: state="getup"; state_time=0; invulnerable=0.22
	elif state=="getup":
		clear_buffer()
		if not source_runtime_enabled and state_time>=0.22: state="idle" if grounded else "jump"; state_time=0; invulnerable=0.0; _end_combo()
	elif state=="ko":
		authored_reset()
		velocity.x=move_toward(velocity.x,0,delta*1000)
	elif authored_is_active():
		# Fresh J/K/U are consumed by the stance before generic input parsing.
		# Only a real confirmed small-skill cancel may consume a super request.
		clear_buffer()
		var authored_command: String=str(intent.get("action",""))
		if authored_skill_runtime.can_cancel(authored_command): start_action(authored_command)
	else:
		if state not in ["attack","dash","guard"] and not source_runtime_enabled: facing=1 if opponent_x>=position.x else -1
		var axis := float(intent.get("axis",0))
		if state=="dash" and not source_runtime_enabled:
			action_time+=delta
			velocity.x=dash_direction*700.0 if state_time<0.14 else move_toward(velocity.x,0,delta*6500)
			if state_time>=0.27: state="idle"; action=""; state_time=0
		else:
			crouching=false
			if state not in ["attack","dash","guard"]:
				guarding=false
				bvn_damping.x=0.0
				if source_runtime_enabled:
					if grounded:
						var move_key: String="moveRIGHT" if axis>0 else "moveLEFT"
						var moves: bool=absf(axis)>.1 and bool(frame_action_flags().get(move_key,false)) and not bool(intent.get("guard",false))
						if moves:
							if state!="walk": _source_enter_move()
							facing=1 if axis>0 else -1; velocity.x=axis*speed; state="walk"
						elif state=="walk": source_idle()
					elif bool(source_permissions.get("airMove",{}).get("enabled",false)): velocity.x=axis*speed
				else:
					if not(grounded and intent.get("guard",false)): velocity.x=axis*speed
					state="walk" if absf(axis)>0.1 else ("idle" if grounded else "jump")
			if intent.get("jump",false): buffer_action("jump")
			if str(intent.get("action","")).length()>0: buffer_action(str(intent["action"]))
			if not pending_command.is_empty():
				if start_action(pending_command,bool(intent.get("retreat",false))): clear_buffer()
				else:
					buffer_life-=delta
					if buffer_life<=0: clear_buffer()
			# FloorHandler tries authorized attacks BEFORE doDefense. A fresh
			# S+J/S+U therefore selects its skill rather than being erased by guard.
			if state not in ["attack","dash","guard"] and grounded and intent.get("guard",false):
				_enter_bvn_defense(axis)
			if state=="attack" and not source_runtime_enabled:
				action_time+=delta
				var startup := float(action_data.get("startup",0.1))
				var active := float(action_data.get("active",0.1))
				if action in ["attack1","attack2","attack3"]:
					_normal_frame_events()
				elif action_time>=startup and action_time<startup+active:
					if action_data.has("dash"): velocity.x=float(action_data["dash"])*facing
					if action_data.has("hop") and grounded and not action_data.get("hopped",false):
						velocity.y=float(action_data["hop"]); grounded=false; action_data["hopped"]=true
						# FighterMain.jump applies source JUMP_DAMPING=.5 with an
						# upward impulse. Without this resource event vy never decays.
						bvn_damping.y=float(action_data.get("hop_damping_y",.5))
				elif action not in ["attack1","attack2","attack3"]: velocity.x=move_toward(velocity.x,0,delta*1200)
				if action_time>=startup+active+float(action_data.get("recovery",0.2)):
					state="idle" if grounded else "jump"; action=""; state_time=0; emotion="happy"
	var source_landing_redirected:=false
	var vertical_displacement:=0.0
	if jump_start_delay>0:
		# doAirJump keeps old impulse/gravity during its one animation-frame delay.
		if not jump_from_ground:
			var carried:=bvn_motion.step_vertical(velocity.y,delta,bvn_damping.y,bvn_apply_gravity)
			velocity.y=carried["velocity"]; vertical_displacement=carried["displacement"]
		if not source_runtime_enabled: jump_start_delay=maxf(0,jump_start_delay-delta)
		if not source_runtime_enabled and jump_start_delay<=0:
			jumps_remaining-=1
			velocity.y=-source_jump_power*BVNMotion.VELOCITY_UNIT if source_runtime_enabled else BVNAir.JUMP_VELOCITY
			bvn_damping=Vector2(0,.5)
			bvn_motion.reset(false)
	elif not grounded:
		var vertical:=bvn_motion.step_vertical(velocity.y,delta,bvn_damping.y,bvn_apply_gravity)
		velocity.y=vertical["velocity"]
		vertical_displacement=vertical["displacement"]
		air_time+=delta
	var horizontal:=bvn_motion.step_horizontal(velocity.x,delta,bvn_damping.x)
	velocity.x=horizontal["velocity"]
	position+=Vector2(horizontal["displacement"],vertical_displacement)
	if not is_zero_approx(bvn_reverse_velocity):
		# setVec2 scales damping by SPEED_PLUS_DEFAULT*6=.5*6, then
		# renderVelocity sums both channels. Reuse the existing source integrator.
		var reverse: Dictionary=bvn_motion.step_horizontal(bvn_reverse_velocity*BVNMotion.VELOCITY_UNIT,delta,bvn_reverse_damping*3.0)
		position.x+=float(reverse["displacement"])
		bvn_reverse_velocity=float(reverse["velocity"])/BVNMotion.VELOCITY_UNIT
	# Vector2 stores float32: source DanGai913.6 becomes913.5999756. Compare
	# against the same representable floor so idle does not repeatedly fall.
	if source_runtime_enabled and not grounded and jump_start_delay<=0 and state not in ["hurt","launch","juggle","slam","down","getup","ko"]: source_is_touch_floor=false
	if position.y>=Vector2(0,stage_floor_y).y and jump_start_delay<=0 and velocity.y>=0:
		var landing_now: bool=not grounded
		if not grounded:
			air_hits_remaining=BVNAir.DEFAULT_AIR_HITS; jumps_remaining=BVNAir.DEFAULT_JUMPS
			bvn_motion.reset()
			if velocity.y>180: landed.emit(velocity.y)
			if state=="slam" and hurt_fly.is_empty(): state="down"; state_time=0; _end_combo()
		position.y=stage_floor_y; velocity.y=0; grounded=true; air_time=0; air_dash_used=false
		if source_runtime_enabled and not source_is_touch_floor and entered_state not in ["hurt","launch","juggle","slam","down","getup","ko"] and not source_permissions.get("touchFloor",{}).is_empty() and (not source_doing_air_action or bool(source_permissions["touchFloor"].get("breakAct",true))):
			var landing: Dictionary=source_permissions.get("touchFloor",{})
			source_runtime_state=0; source_branch(str(landing.get("label","落地")),"",true)
			source_landing_redirected=true
			source_is_touch_floor=true; jumps_remaining=BVNAir.DEFAULT_JUMPS; air_hits_remaining=BVNAir.DEFAULT_AIR_HITS
	else: grounded=false
	if not hurt_fly.is_empty(): _advance_bvn_hurt_fly(delta)
	_advance_source_ko_presentation()
	# Open GameMainLogicCtrler advances gravity/velocity before MovieClip frames.
	# Parent Battle samples source collision only on this shared 30Hz boundary.
	if source_runtime_enabled and not authored_is_active():
		_source_render_jump_animate()
		# Original GameCtrler.checkRenderAnimate precedes logical touchFloor.
		# A newly executed goFrame(TF) therefore cannot nextFrame again here.
		if state in ["attack","dash","walk","getup"] and not source_landing_redirected: _source_tick(delta)
	if state=="idle" and entered_state!="idle":
		bvn_defense=BVNDefense.idle_enter(bvn_defense)
		guarding=false
	_render_bvn_defense(delta,intent)
	if absf(velocity.x)>350 or velocity.y<-180:
		trail.push_front(position)
		if trail.size()>5: trail.pop_back()
	elif not trail.is_empty(): trail.pop_back()
	queue_redraw()
	if body_canvas: body_canvas.queue_redraw()

## Pin counters to the actual actor animation callback, not redraw/state_time.
## Ground playHurtDown has a stopped bounce POSE, not an upward impulse.
func _advance_source_ko_presentation() -> void:
	var cue: Dictionary=source_ko_presentation.step(source_animation_boundary,grounded,source_runtime_enabled and hp<=0 and state=="ko" and hurt_fly.is_empty())
	if cue.is_empty():return
	cue.merge({"position":Vector2(position.x,stage_floor_y),"source_label":source_label,"source_generation":source_generation,"source_frame":source_frame,"source_absolute_frame":source_absolute_frame},true)
	source_floor_impact.emit(cue)

## Official FighterMC hurt-fly phases advance at the original animation rate.
func _advance_bvn_hurt_fly(delta: float) -> void:
	hurt_fly_clock+=delta
	while hurt_fly_clock+0.0000001>=1.0/BVNHit.FPS_ANIMATE and not hurt_fly.is_empty():
		hurt_fly_clock-=1.0/BVNHit.FPS_ANIMATE
		var step:=BVNHit.step_hurt_fly(hurt_fly,not grounded,position.y/BVNAir.STAGE_UNIT_SCALE,hp>0)
		hurt_fly=step["next"]
		if step.has("set_damping_x"): bvn_damping.x=step["set_damping_x"]
		if step.has("set_velocity_y"):
			velocity.y=float(step["set_velocity_y"])*BVNMotion.VELOCITY_UNIT
			grounded=false; bvn_motion.reset(false)
		match str(step["event"]):
			"fall":
				state="down"; state_time=0
				if source_runtime_enabled: _source_reaction_snapshot("击飞_落")
			"bounce":
				state="juggle"; state_time=0; hurt_fly_window=0.0
				if source_runtime_enabled: _source_reaction_snapshot("击飞_弹")
			"heavy_floor","normal_floor":
				state="down"; state_time=0
				if source_runtime_enabled: _source_reaction_snapshot("击飞_倒")
			"resume":
				hurt_fly.clear(); state="getup"; state_time=0; _end_combo()
				if source_runtime_enabled:
					source_runtime_state=23; source_branch("击飞_起")
			"dead": hurt_fly.clear(); state="ko"
		# FighterMC.renderHurtFly -> FighterEffectCtrl.hitFloor. Consume the
		# existing rule result after the real reaction label was applied. No
		# position, velocity, down timer or source-frame mutation is added.
		if step.has("floor_strength"):
			source_floor_impact.emit({"event":str(step["event"]),"strength":float(step["floor_strength"]),"type":0 if str(step["event"])=="bounce" else (2 if str(step["event"])=="heavy_floor" else 1),"position":Vector2(position.x,stage_floor_y),"source_label":source_label,"source_generation":source_generation,"source_frame":source_frame,"source_absolute_frame":source_absolute_frame})
		if source_runtime_enabled and int(hurt_fly.get("phase",0))==1 and state_time>=1.0/30.0 and source_label=="被打": _source_reaction_snapshot("击飞")
	if int(hurt_fly.get("phase",0))==3: hurt_fly_window+=delta

## Open3.4 renderHurtFlying648–665 reads L on each game callback. During
## bounce the counter resets every tick; it continues into early ordinary down.
func can_bvn_floor_recovery() -> bool:
	var phase: int=int(hurt_fly.get("phase",0))
	if hp<=0 or phase not in [3,4]: return false
	# Battle reads raw input before advance(), so include this callback's ++.
	if phase==4 and (hurt_fly_recovery_frame<=0 or hurt_fly_recovery_frame+1>=20): return false
	if not BVNHit.hurt_down_jump_allowed(energy,current_hurt_power): return false
	if source_runtime_enabled and not source_has_label("起身"): return false
	return true

func try_bvn_floor_recovery() -> bool:
	if not can_bvn_floor_recovery(): return false
	var original_velocity_x: float=velocity.x
	var original_source_state: int=source_action_state()
	_apply_bvn_resource(BVNHit.use_energy(bvn_resource_state(),30))
	if source_runtime_enabled:
		# Open FighterMcCtrler2072–2094: the real recovery MovieClip runs
		# its own idle script. A legacy getup timer cannot substitute for it.
		hurt_fly.clear(); source_branch("起身","",true)
		state="getup"; source_runtime_state=original_source_state; state_time=0
		source_allow_be_hit=false; invulnerable=0
		velocity=Vector2(original_velocity_x,0)
		bvn_damping=Vector2(original_velocity_x/BVNMotion.VELOCITY_UNIT*.1,0)
		_end_combo(); clear_buffer()
		return true
	hurt_fly.clear(); state="getup"; state_time=0; action=""; velocity.y=0.0
	bvn_damping=Vector2(absf(velocity.x/BVNMotion.VELOCITY_UNIT)*.1,0)
	invulnerable=.22; _end_combo(); clear_buffer()
	return true

## Uses the actual upstream hurt/guard/steel calculation, including fractional chip HP.
func receive_hit(raw_damage: int, knockback: float, stun: float, source_facing: int, kind := "normal", guarding_hit := false, source: Dictionary={}) -> Dictionary:
	if hp<=0 or is_protected(): return {"hit":false}
	var source_reaction:=str(source.get("reaction","hurt"))
	var source_y:=0.0
	if source_reaction=="launch": source_y=float(source.get("source_hity",-5.0))
	elif source_reaction=="slam": source_y=15.0
	elif source_reaction=="down": source_y=6.0
	var armor:=is_attacking() and bool(action_data.get("armor",false)) and action_time>=.05 and action_time<=float(action_data.get("startup",.2))+float(action_data.get("active",.15))
	var target:=bvn_resource_state()
	target.merge({"hp":hp,"allow_be_hit":source_allow_be_hit if source_runtime_enabled else true,"guard":(guarding_hit or guarding) and grounded,"steel":source_steel or armor or bool(hurt_break_state.get("steel",false)),"super_steel":source_super_steel or bool(hurt_break_state.get("super_steel",false)),"hurt_action":source_hurt_action if source_runtime_enabled else "","in_air":not grounded,"x":position.x/BVNAir.STAGE_UNIT_SCALE,"facing":facing},true)
	var hit: Dictionary={"power":raw_damage,"hitx":knockback/BVNMotion.VELOCITY_UNIT,"hity":source_y,"hurt_time_ms":stun*1000,"hurt_type":1 if source_reaction in ["launch","down","slam"] else 0,"hit_type":BVNHit.HIT_CATCH if kind=="throw" else 1,"is_break_def":kind=="throw" or source.get("is_break_def",false),"is_bisha":kind=="super","owner_facing":source_facing,"owner_x":float(source.get("owner_x",position.x-source_facing*100))/BVNAir.STAGE_UNIT_SCALE,"check_direct":true,"has_owner":source.get("has_owner",true),"target_apply_g":bool(source.get("target_apply_g",source.get("targetApplyG",true)))}
	if source.get("source_hit_vo") is Dictionary:
		var exact: Dictionary=source["source_hit_vo"]
		hit.merge({"power":exact.get("power",raw_damage),"power_rate":exact.get("powerRate",1),"hitx":exact.get("hitx",0),"hity":exact.get("hity",0),"hurt_time_ms":exact.get("hurtTime",300),"hurt_type":exact.get("hurtType",0),"hit_type":exact.get("hitType",1),"is_break_def":exact.get("isBreakDef",false),"is_real":exact.get("isReal",false),"check_direct":exact.get("checkDirect",true),"target_apply_g":exact.get("isApplyG",exact.get("targetApplyG",true))},true)
	var answer:=BVNHit.resolve_hit(target,hit)
	if not answer.get("hit",false): return answer
	if answer.get("reaction","")=="hurt_action":
		source_branch(str(answer.get("hurt_action","")),"",true)
		return {"hit":true,"blocked":false,"damage":0.0,"combo_count":combo_hits,"combo_damage":combo_damage,"armor":false,"guard_break":false,"terminal":false,"reaction":"hurt_action","source_gap":0.0}
	var next: Dictionary=answer["next"]
	bvn_damping=answer.get("damping",Vector2(.1,.5))
	_apply_bvn_resource(next)
	hp=float(next["hp"])
	hype=BVNHit.add_qi(hype,float(answer.get("qi_gain",0)))
	invulnerable=float(answer.get("gap_time",0))
	var damage: float=answer["damage"]
	var blocked: bool=answer["blocked"]
	var armored: bool=answer["armor"]
	if authored_skills_enabled and not armored: _authored_runtime().interrupt()
	if source_runtime_enabled:
		var observed: Dictionary=source.get("source_hit_vo",{}).duplicate(true)
		observed["id"]=str(source.get("source_name",observed.get("id","")))
		if blocked: last_source_defense_hit=observed
		else: last_source_hurt_hit=observed
		if not armored:
			source_generation+=1; source_playing=false; source_doing_action=false; source_permissions.clear(); source_hurt_action=""; source_hit_target.clear()
			source_is_jumping=false; source_jump_delay_frames=0; source_jump_frame_count=0
	if blocked:
		if source_runtime_enabled: _source_reaction_snapshot("防御")
		if not bool(bvn_defense.get("active",false)): bvn_defense=BVNDefense.enter(bvn_defense,true)
		bvn_defense["guard"]=true; guarding=true
		clear_buffer(); guard_flash=.08; attack_contact=false; attack_hit=false
		state="guard_stun"; state_time=0; action=""
		action_data={"hurt_length":answer["stun_time"]}
		velocity.x=answer["velocity"].x*BVNMotion.VELOCITY_UNIT
		_end_combo()
	else:
		if not armored:
			current_hurt_power+=raw_damage
			last_hurt_bisha=kind=="super"
			hurt_chain_break=hurt_chain_break or bool(hit.get("is_break_def",false))
		combo_hits+=1; combo_damage+=damage; combo_reset=1.05; hurt_flash=.05; emotion="shock"
		if not armored:
			_clear_bvn_defense()
			clear_buffer(); guarding=false; crouching=false; action=""; state_time=0; jump_start_delay=0.0
			# doHurtAnimate resets isApplyG; only alive hurtType0 may override it.
			bvn_apply_gravity=bool(answer.get("apply_gravity",true)) if hp>0 and int(hit["hurt_type"])==0 else true
			var hurt_length: float=float(answer["stun_time"])
			action_data={"hurt_length":hurt_length}
			velocity=answer["velocity"]*BVNMotion.VELOCITY_UNIT
			if velocity.y<0: grounded=false; bvn_motion.reset(false)
			if answer["reaction"]=="fly":
				hurt_fly=BVNHit.start_hurt_fly(answer["velocity"],not grounded,position.y/BVNAir.STAGE_UNIT_SCALE)
				hurt_fly_clock=0.0; hurt_fly_window=0.0; hurt_fly_recovery_frame=0
			else: hurt_fly.clear(); hurt_fly_recovery_frame=0
			if source_runtime_enabled: _source_reaction_snapshot("被打")
			state="hurt" if grounded else "juggle"
			if answer["guard_break"]: state="hurt"
			elif source_reaction=="launch":
				combo_launch_used=true; grounded=false; state="launch"; bvn_motion.reset(false)
			elif source_reaction in ["down","slam"]:
				state="slam" if not grounded else "down"
				if grounded: velocity.y=0.0
		else:
			armor_used=true
		if hp<=0:
			state="ko"
			authored_reset()
			# The already accepted ordinary settlement owns this integer hold.
			# Keep actual label/state/velocity/damping intact; air/fly KO is excluded.
			if source_runtime_enabled and not armored and not blocked and grounded and int(hit["hurt_type"])==0 and str(answer.get("reaction",""))=="hurt" and hurt_fly.is_empty():
				source_ko_presentation.begin(int(answer["stun_frames"]),int(hit["hit_type"]),source_generation)
	var terminal:=state in ["down","slam","ko"]
	return {"hit":true,"blocked":blocked,"damage":damage,"combo_count":combo_hits,"combo_damage":combo_damage,"armor":armored,"guard_break":answer["guard_break"],"auto_escape":false,"terminal":terminal,"reaction":source_reaction,"launched":state=="launch","source_gap":answer["gap_time"]}

## Ordinary hurt O follows FighterMcHurtCtrl.renderHurtBreak. S+L/W+L remain ghost.
func hurt_break_eligibility() -> Dictionary:
	var source:=bvn_resource_state()
	source.merge({"alive":hp>0,"hurting":state in ["hurt","juggle"] and hurt_fly.is_empty(),"special_pressed":true,"qi":hype,"last_bisha":last_hurt_bisha,"hurt_break_hit":hurt_chain_break,"current_hurt_damage":int(current_hurt_power)},true)
	return source

func can_hurt_break() -> bool:
	return BVNHurtBreak.can(hurt_break_eligibility())

func perform_hurt_break() -> bool:
	var begin:=BVNHurtBreak.begin(hurt_break_eligibility(),position,facing)
	if not bool(begin.get("allowed",false)): return false
	hurt_break_state=begin["state"]
	_apply_bvn_resource(hurt_break_state)
	hype=float(hurt_break_state["qi"])
	invulnerable=0.0; clear_buffer()
	return true

func _advance_hurt_break(delta: float) -> void:
	if hurt_break_state.is_empty(): return
	hurt_break_state=BVNHurtBreak.tick(hurt_break_state,delta)
	if bool(hurt_break_state.get("idle_event",false)):
		var entering_source_state: int=source_action_state()
		state="idle" if grounded else "jump"; action=""; action_data.clear(); state_time=0
		hurt_fly.clear(); bvn_apply_gravity=true
		if grounded:
			velocity=Vector2.ZERO; bvn_damping=Vector2.ZERO
			air_hits_remaining=BVNAir.DEFAULT_AIR_HITS; jumps_remaining=BVNAir.DEFAULT_JUMPS
		else:
			# First fall after ordinary hurt: keepY/damping, clearX (source fall()).
			velocity.x=0
		_end_combo(); clear_buffer()
		if source_runtime_enabled: source_idle("站立",entering_source_state)
	if int(hurt_break_state.get("steel_frames",0))<=0 and int(hurt_break_state.get("hit_frames",0))<=0: hurt_break_state.clear()

func hurt_break_hit() -> Dictionary:
	return BVNHurtBreak.current_hit(hurt_break_state)

## Official FighterMcGhostHandler.startGhostStep; physical S+L/W+L.
## No round cap, knockback, damage, or projectile deletion is added.
func perform_burst(variant: String="ghost") -> bool:
	var entering_source_state:=source_action_state()
	if hp<=0 or entering_source_state in [12,13,50]: return false
	if hype<60 or not BVNHit.has_energy(energy,80,energy_overload,true): return false
	hype-=60
	_apply_bvn_resource(BVNHit.use_energy(bvn_resource_state(),80))
	ghost_source_state=entering_source_state
	_clear_bvn_defense()
	burst_used=false; state="burst"; state_time=0; action=variant; action_data.clear()
	if source_runtime_enabled:
		source_generation+=1; source_playing=false; source_doing_action=false; source_doing_air_action=false
		source_is_jumping=false; source_jump_delay_frames=0; source_jump_frame_count=0
		source_permissions.clear(); source_hurt_action=""; source_hit_target.clear(); source_steel=false; source_super_steel=false
	bvn_apply_gravity=true
	clear_buffer(); hurt_fly.clear(); bvn_damping=Vector2(0,.1 if variant=="ghost_up" else 0); invulnerable=.4; protection_min=.4; landing_safety=0.0; _end_combo()
	jump_start_delay=0.0
	if variant=="ghost_up":
		velocity=Vector2(0,-12.0*BVNMotion.VELOCITY_UNIT); jumps_remaining=maxi(0,jumps_remaining-1)
		grounded=false; bvn_motion.reset(false)
	elif variant=="ghost_down": velocity=Vector2(0,15.0*BVNMotion.VELOCITY_UNIT)
	else: velocity=Vector2(facing*8.0*BVNMotion.VELOCITY_UNIT,0)
	return true

## Map source animation frames to the actual contact keys of each authored pose.
## Values describe art registration only; hit/permission source frames stay intact.
func _normal_pose_progress(normal: int) -> float:
	var maps: Dictionary={
		1:[[0,0.0],[1,.286],[2,.429],[3,.571],[4,.714],[6,.80],[11,.90],[20,1.0]],
		2:[[0,0.0],[2,.222],[4,.444],[5,.556],[6,.667],[9,.80],[15,.90],[27,1.0]],
		3:[[0,0.0],[3,.273],[4,.455],[5,.545],[6,.636],[11,.85],[25,1.0]]}
	var keys: Array=maps[normal]
	var frame:=action_time*30.0
	for index in range(keys.size()-1):
		var first: Array=keys[index]
		var second: Array=keys[index+1]
		if frame<=float(second[0]): return lerpf(float(first[1]),float(second[1]),clampf((frame-float(first[0]))/(float(second[0])-float(first[0])),0,1))
	return 1.0

func pixel_animation_state() -> Dictionary:
	if authored_is_active():
		var authored: Dictionary=authored_visual_state()
		var authored_clip: String=str(authored["semantic_move_id"])
		if not str(authored["branch"]).is_empty(): authored_clip+="__"+str(authored["branch"])
		authored_clip+="_"+str(authored["stage"])
		return {"clip":authored_clip,"progress":authored["phase"],"appearance":authored["appearance"],"authored":authored}
	var base: Dictionary=_pixel_animation_state_base()
	if authored_skills_enabled: base["appearance"]=_authored_runtime().visual_state().get("appearance",{})
	return base

func _pixel_animation_state_base() -> Dictionary:
	if source_runtime_enabled and state=="getup" and source_playing and pixel_script:
		var mapped: Dictionary=pixel_script.get_source_visual(fighter_id,source_label,float(source_frame)+source_clock*30.0)
		if bool(mapped.get("known",false)) and str(mapped.get("art_clip",""))=="getup":
			var alignment: Dictionary=mapped.get("source_alignment",{})
			var idle_frame: int=int(alignment.get("idle_frame",0))
			# Reach the standing pose during the last visible recovery frame.
			# The source idle event still owns permission and the actual exit.
			var progress:=clampf((float(source_frame)+source_clock*30.0)/maxf(1.0,float(idle_frame-1)),0.0,1.0) if idle_frame>0 else float(mapped.get("progress",0.0))
			return {"clip":"getup","progress":progress,"source_label":source_label,"source_absolute_frame":source_absolute_frame,"source_frame":source_frame,"source_alignment":alignment}
	if source_runtime_enabled and source_doing_action and state in ["attack","dash"]:
		var current_label: String=source_label
		var current_start: int=-1
		for label: String in source_profile.get("actor",{}).get("labels",{}):
			var start: int=int(source_profile["actor"]["labels"][label].get("frame",0))
			if start<=source_absolute_frame and start>current_start: current_label=label; current_start=start
		var relative: float=float(source_absolute_frame-current_start)+source_clock*30.0
		if pixel_script and pixel_script.has_method("get_source_visual"):
			var mapped: Dictionary=pixel_script.get_source_visual(fighter_id,current_label,relative)
			if bool(mapped.get("known",false)):
				return {"clip":mapped["art_clip"],"progress":mapped["progress"],"source_label":source_label,"current_frame_label":current_label,"source_absolute_frame":source_absolute_frame,"source_frame":source_frame,"source_alignment":mapped.get("source_alignment",{})}
		var art_clip: String=_source_label_command(current_label,action)
		if art_clip=="air_super": art_clip="super"
		var first: float=float(action_data.get("startup",0))*30.0
		var last: float=first+float(action_data.get("active",0))*30.0
		var end: float=float(action_data.get("source_definition",{}).get("frame_count",1)-1)
		var frame: float=float(source_frame)+source_clock*30.0
		var phases: Vector2=pixel_script.contact_phases(fighter_id,art_clip) if _uses_pixel_body() else Vector2(.45,.62)
		var progress: float=frame/maxf(1,end) if last<=first else (frame/maxf(1,first)*phases.x if frame<first else (lerpf(phases.x,phases.y,(frame-first)/maxf(1,last-first)) if frame<last else lerpf(phases.y,1,(frame-last)/maxf(1,end-last))))
		return {"clip":art_clip,"progress":clampf(progress,0,1),"source_label":source_label,"current_frame_label":current_label,"source_absolute_frame":source_absolute_frame,"source_frame":source_frame}
	var clip := ("super" if action=="air_super" else action) if state=="attack" else state
	if clip=="guard_stun": clip="guard"
	if clip in ["launch","juggle","slam"]: clip="air_hurt"
	if clip=="walk" or clip=="idle": return {"clip":clip,"progress":walk_clock}
	if state=="guard": return {"clip":"guard","progress":0.52+sin(walk_clock*6)*0.035}
	if state=="guard_stun": return {"clip":"guard","progress":clampf(0.45+state_time/maxf(.1,float(action_data.get("hurt_length",.18)))*0.35,0.45,0.80)}
	if state in ["hurt","launch","juggle","slam"]:
		return {"clip":clip,"progress":clampf(0.30+state_time/maxf(.1,float(action_data.get("hurt_length",.33)))*0.70,0.30,1.0)}
	if not preview_animation.is_empty(): return {"clip":preview_animation,"progress":walk_clock}
	var duration := 0.55
	if state=="attack":
		if action in ["attack1","attack2","attack3"]: return {"clip":clip,"progress":_normal_pose_progress(int(action.trim_prefix("attack")))}
		var startup := float(action_data.get("startup",0.1))
		var active := float(action_data.get("active",0.1))
		var recovery := float(action_data.get("recovery",0.2))
		var contact_phases: Vector2=pixel_script.contact_phases(fighter_id,clip) if _uses_pixel_body() else Vector2(.45,.62)
		var progress := 0.0
		if action_time<startup: progress=action_time/maxf(0.01,startup)*contact_phases.x
		elif action_time<startup+active: progress=contact_phases.x+(action_time-startup)/maxf(0.01,active)*(contact_phases.y-contact_phases.x)
		else: progress=contact_phases.y+(action_time-startup-active)/maxf(0.01,recovery)*(1.0-contact_phases.y)
		return {"clip":clip,"progress":clampf(progress,0,1)}
	elif state=="dash": duration=0.27
	elif state=="jump": duration=0.87
	elif state=="burst": return {"clip":"dash","progress":clampf(state_time/.4,0,1)}
	elif state=="getup": duration=0.22
	elif state=="down": duration=0.42
	return {"clip":clip,"progress":clampf((action_time if state in ["attack","dash"] else state_time)/duration,0,1)}

func _draw() -> void:
	draw_set_transform(Vector2(0.0, stage_floor_y - position.y))
	var altitude := maxf(0.0,stage_floor_y-position.y)
	var shadow_scale := clampf(1.0-altitude/620.0,0.46,1.0)
	for ring in range(5,0,-1):
		var radius := body_width*(0.39+ring*0.09)*shadow_scale
		draw_ellipse_shape(Vector2(0,3),Vector2(radius,2+ring*1.6),Color(0.045,0.037,0.071,(0.018+float(6-ring)*0.012)*shadow_scale))
	draw_ellipse_shape(Vector2(0,2),Vector2(body_width*0.37*shadow_scale,4.8*shadow_scale),Color(0.03,0.025,0.046,0.29*shadow_scale))
	draw_ellipse_shape(Vector2(-34,12),Vector2(body_width*0.95*shadow_scale,8.0*shadow_scale),Color(0.035,0.038,0.07,0.10*shadow_scale))
	draw_set_transform(Vector2.ZERO)
	source_renderer_handled=false
	if source_bindings_enabled and source_actor_renderer!=null and source_actor_renderer.has_method("draw_actor"):
		# Shadow stays on the parent; exactly one lit mesh body is drawn by the child.
		source_renderer_handled=source_actor_renderer.has_assets(fighter_id)
		if source_renderer_handled:
			if body_canvas: body_canvas.queue_redraw()
			return
	if _uses_pixel_body():
		_draw_pixel_speed_ghosts()
		draw_set_transform(Vector2.ZERO,0.0,Vector2(float(facing),1.0))
		_draw_action()
		draw_set_transform(Vector2.ZERO)
		if guarding:
			var guard_center:=Vector2(facing*body_width*.46,-body_height*.64)
			draw_arc(guard_center,body_height*.27,-1.5 if facing>0 else 1.6,1.5 if facing>0 else 4.7,16,Color(.36,.91,1,.68),4,false)
		if body_canvas: body_canvas.queue_redraw()
		return
	var motion := Vector2.ZERO
	var angle := 0.0
	var scale_y := 1.0
	var frame := animation_frame_state()
	var animated: bool = frame["available"]
	if animated and not pixel_script and altitude<170:
		var reflection: Dictionary=animation_source(frame)
		draw_set_transform(Vector2(-13,altitude+6),0.0,Vector2(float(facing),-0.14))
		for command in animation_draw_commands(frame):
			draw_texture_rect_region(reflection["texture"],command["draw_rect"],command["source_rect"],Color(0.78,0.64,0.50,0.075*(1.0-altitude/170.0)))
		draw_set_transform(Vector2.ZERO)
	if not animated and state == "walk":
		motion.y = -absf(sin(walk_clock * 15.0)) * 8.0
		angle = sin(walk_clock * 15.0) * 0.025
	elif not animated and state == "idle":
		motion.y = -sin(walk_clock * 3.0) * 2.0
	elif not animated and state == "hurt":
		angle = -facing * 0.12
	elif not animated and state == "ko":
		angle = facing * 1.2
		motion.y = -25.0
	elif not animated and state == "attack":
		var phase := clampf(action_time / maxf(0.1, float(action_data.get("startup", 0.1))), 0.0, 1.0)
		angle = facing * (0.11 * phase if action != "special2" else -0.09)
		motion.x = facing * sin(action_time * 16.0) * 5.0
	if crouching:
		scale_y = 1.0 if animated else 0.58
	for i in range(trail.size() if not pixel_script else 0):
		if animated:
			var ghost_descriptor: Dictionary = animation_source(frame)
			var ghost_position := trail[i]-position
			draw_set_transform(ghost_position,0.0,Vector2(float(facing),scale_y))
			for command in animation_draw_commands(frame):
				draw_texture_rect_region(ghost_descriptor["texture"],command["draw_rect"],command["source_rect"],Color(accent,0.18*(1.0-float(i)/5.0)))
		else:
			draw_ellipse_shape(trail[i] - position + Vector2(-facing * 35.0, -50.0), Vector2(28.0, 16.0), Color(accent, 0.13 * (1.0 - float(i) / 5.0)))
	draw_set_transform(motion, angle, Vector2(float(facing), scale_y))
	var tint := Color.WHITE
	if hurt_flash > 0.0:
		tint = Color(1.12,1.12,1.08)
	elif guard_flash > 0.0:
		tint = Color(0.65,1.30,1.60)
	if invulnerable > 0.0:
		tint.a = 0.65 + sin(walk_clock * 60.0) * 0.20
	if not animated and texture:
		var rect := Rect2(Vector2(-render_size.x * 0.5, -render_size.y), render_size)
		var current_texture: Texture2D = emotion_textures.get(emotion, texture)
		draw_texture_rect(current_texture, rect, false, tint)
	elif not animated:
		_draw_fallback()
	_draw_action()
	draw_set_transform(Vector2.ZERO)
	if fighter_id=="worker" and is_attacking() and action=="skill1":
		var startup := float(action_data.get("startup",0.19))
		if action_time>=startup and action_time<=startup+float(action_data.get("active",0.16)):
			draw_string(ThemeDB.fallback_font,Vector2(facing*120-76,-99),"お帰りください",HORIZONTAL_ALIGNMENT_CENTER,152,17,Color("171721"))
	if guarding:
		var center := Vector2(facing * 52.0, -95.0)
		draw_arc(center, 68.0, -1.5 if facing > 0 else 1.6, 1.5 if facing > 0 else 4.7, 20, Color("5be7ff"), 5.0, true)
	if fighter_id == "cat" and not pixel_script:
		_draw_cat_emotion()
	if body_canvas:
		var treatment: ShaderMaterial=body_canvas.material as ShaderMaterial
		if treatment and animated:
			var descriptor: Dictionary=animation_source(frame)
			var atlas_size: Vector2=descriptor["texture"].get_size()
			var region: Rect2=frame["region"]
			treatment.set_shader_parameter("frame_region",Vector4(region.position.x/atlas_size.x,region.position.y/atlas_size.y,region.size.x/atlas_size.x,region.size.y/atlas_size.y))
			treatment.set_shader_parameter("motion_clock",walk_clock)
			treatment.set_shader_parameter("secondary_motion",0.9 if fighter_id=="rio" and state in ["idle","walk","block"] else 0.0)
			treatment.set_shader_parameter("hit_glow",clampf(hurt_flash/0.05,0.0,1.0))
		body_canvas.queue_redraw()

func _uses_pixel_body() -> bool:
	return pixel_script!=null and pixel_script.has_method("draw_fighter") and pixel_script.has_method("has_assets") and pixel_script.has_assets(fighter_id)

func _pixel_ghost_count() -> int:
	# A dash intentionally leaves three ordered speed echoes. Attacks, jumping,
	# guard, and recovery never borrow a stale movement trail as a second body.
	if state!="dash" or absf(velocity.x)<400.0: return 0
	return mini(3,mini(trail.size(),maxi(0,floori(state_time*60.0))))

func visual_draw_plan() -> Dictionary:
	var pixels:=_uses_pixel_body()
	return {"renderer":"pixel" if pixels else "legacy","body_passes":1,"legacy_body_passes":0 if pixels else 1,"ghost_passes":_pixel_ghost_count() if pixels else 0,"ghost_reason":"dash" if pixels and _pixel_ghost_count()>0 else "","clip":pixel_animation_state()["clip"]}

func _draw_pixel_speed_ghosts() -> void:
	var count:=_pixel_ghost_count()
	if count==0: return
	var visual:=pixel_animation_state()
	var previous:=Vector2.INF
	var rendered:=0
	var sample_limit:=mini(trail.size(),maxi(0,floori(state_time*60.0)))
	for sample_index in range(sample_limit):
		var sample: Vector2=trail[sample_index]
		# Avoid three nearly coincident tinted copies. Each echo occupies a distinct
		# point behind the moving actor and fades away from the body.
		if absf(sample.x-position.x)<12.0 or (previous!=Vector2.INF and sample.distance_to(previous)<8.0): continue
		draw_set_transform(sample-position)
		var opacity:=0.10-float(rendered)*0.027
		if authored_skills_enabled:
			pixel_script.draw_fighter(self,fighter_id,visual["clip"],visual["progress"],facing,Color(accent,opacity),body_height if source_runtime_enabled else 0.0,visual.get("appearance",{}))
		else: pixel_script.draw_fighter(self,fighter_id,visual["clip"],visual["progress"],facing,Color(accent,opacity),body_height if source_runtime_enabled else 0.0)
		previous=sample; rendered+=1
		if rendered>=count: break
	draw_set_transform(Vector2.ZERO)

func _draw_body() -> void:
	if source_renderer_handled:
		if source_body_material==null:
			source_body_material=ShaderMaterial.new()
			source_body_material.shader=load("res://game/bvn_body_light.gdshader")
		body_canvas.material=source_body_material
		var context: Dictionary=source_actor_renderer._actor_context(self,source_visual_state())
		var pose: Dictionary=source_actor_renderer.get_pose_state(fighter_id,context)
		if pose.get("ready",false):
			var atlas: Texture2D=source_actor_renderer.texture_for_pose(pose)
			var size: Vector2=atlas.get_size()
			var region: Array=pose["rect"]
			source_body_material.set_shader_parameter("frame_region",Vector4(float(region[0])/size.x,float(region[1])/size.y,float(region[2])/size.x,float(region[3])/size.y))
		body_canvas.draw_set_transform(Vector2.ZERO)
		source_actor_renderer.draw_prepared_actor(body_canvas,self,context,pose)
		return
	if not pixel_script and ResourceLoader.exists("res://game/pixel_fighter.gd"): pixel_script=load("res://game/pixel_fighter.gd")
	if _uses_pixel_body():
		body_canvas.material=null
		var visual := pixel_animation_state()
		var tint := Color(1.0,0.98,0.94)
		if hurt_flash>0: tint=tint.lerp(Color(1.0,1.0,1.0),0.18)
		if guard_flash>0: tint=Color(0.72,0.96,1.0)
		if invulnerable>0 and (not authored_skills_enabled or state in ["burst","escape","dash"]): tint.a=0.70+sin(walk_clock*42)*0.15
		body_canvas.draw_set_transform(Vector2.ZERO)
		if authored_skills_enabled:
			pixel_script.draw_fighter(body_canvas,fighter_id,visual["clip"],visual["progress"],facing,tint,body_height if source_runtime_enabled else 0.0,visual.get("appearance",{}))
		else: pixel_script.draw_fighter(body_canvas,fighter_id,visual["clip"],visual["progress"],facing,tint,body_height if source_runtime_enabled else 0.0)
		return
	var frame := animation_frame_state()
	if not frame["available"]:
		return
	var tint := Color.WHITE
	if guard_flash>0: tint=Color(0.82,1.08,1.15)
	if invulnerable>0: tint.a=0.65+sin(walk_clock*60)*0.20
	var scale_y := 1.0
	body_canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2(float(facing),scale_y))
	var descriptor: Dictionary=animation_source(frame)
	for command in animation_draw_commands(frame):
		body_canvas.draw_texture_rect_region(descriptor["texture"],command["draw_rect"],command["source_rect"],tint)

func draw_ellipse_shape(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32):
		var t := float(i) * TAU / 32.0
		points.append(center + Vector2(cos(t) * radii.x, sin(t) * radii.y))
	draw_colored_polygon(points, color)

func _draw_fallback() -> void:
	var outline := Color("10131e")
	match fighter_id:
		"shark":
			draw_ellipse_shape(Vector2(0, -95), Vector2(107, 60), outline)
			draw_ellipse_shape(Vector2(0, -98), Vector2(100, 54), Color("56b9dc"))
			draw_colored_polygon(PackedVector2Array([Vector2(-27,-140),Vector2(-7,-193),Vector2(28,-132)]), Color("3493be"))
			draw_colored_polygon(PackedVector2Array([Vector2(-90,-101),Vector2(-139,-139),Vector2(-130,-70)]), Color("3493be"))
			for i in range(3):
				var x := -61.0 + i * 58.0
				draw_line(Vector2(x, -60),Vector2(x + 13, -17),outline,15)
				draw_style_box(_shoe_box(), Rect2(x-8,-23,52,23))
			draw_circle(Vector2(62,-114),8,outline)
			draw_line(Vector2(62,-81),Vector2(93,-85),outline,4)
			for i in range(4):
				draw_colored_polygon(PackedVector2Array([Vector2(64+i*7,-83),Vector2(67+i*7,-73),Vector2(71+i*7,-84)]),Color.WHITE)
		"cat":
			draw_ellipse_shape(Vector2(0,-83),Vector2(52,69),outline)
			draw_ellipse_shape(Vector2(0,-85),Vector2(47,64),Color("ddc49b"))
			draw_circle(Vector2(0,-157),47,outline)
			draw_circle(Vector2(0,-157),42,Color("e0c6a0"))
			for x in [-1,1]:
				draw_colored_polygon(PackedVector2Array([Vector2(x*35,-176),Vector2(x*36,-215),Vector2(x*10,-192)]),outline)
				draw_line(Vector2(x*36,-102),Vector2(x*74,-148),Color("e0c6a0"),17)
				draw_line(Vector2(x*22,-30),Vector2(x*39,-8),Color("e0c6a0"),18)
			draw_circle(Vector2(-15,-158),5,outline)
			draw_circle(Vector2(15,-158),5,outline)
			draw_arc(Vector2(0,-147),12,0,PI,12,outline,3)
		"worker":
			for x in [-1,1]:
				draw_line(Vector2(x*14,-50),Vector2(x*23,-6),Color("203c75"),19)
				draw_line(Vector2(x*31,-112),Vector2(x*47,-62),Color("7cbaef"),19)
			draw_style_box(_plain_box(Color("68b4eb")),Rect2(-35,-134,70,89))
			draw_circle(Vector2(0,-166),36,Color("151724"))
			draw_circle(Vector2(0,-159),31,Color("ffdbb7"))
			draw_colored_polygon(PackedVector2Array([Vector2(-32,-173),Vector2(-19,-192),Vector2(25,-187),Vector2(33,-170),Vector2(9,-178),Vector2(-3,-169)]),Color("151724"))
			draw_circle(Vector2(-11,-158),3,outline)
			draw_circle(Vector2(11,-158),3,outline)
			draw_arc(Vector2(0,-153),10,0,PI,12,outline,2)
			draw_style_box(_plain_box(Color("705436")),Rect2(37,-69,43,34))
		"chicken":
			for x in [-1,1]:
				draw_line(Vector2(x*25,-38),Vector2(x*39,-5),Color("ffc859"),14)
				draw_line(Vector2(x*42,-127),Vector2(x*75,-88),Color("fff0bb"),23)
			draw_ellipse_shape(Vector2(0,-94),Vector2(54,75),outline)
			draw_ellipse_shape(Vector2(0,-94),Vector2(48,69),Color("fff0bb"))
			draw_circle(Vector2(0,-171),43,outline)
			draw_circle(Vector2(0,-169),37,Color("fff0bb"))
			draw_colored_polygon(PackedVector2Array([Vector2(-41,-173),Vector2(-20,-216),Vector2(-2,-197),Vector2(20,-216),Vector2(41,-174),Vector2(10,-186),Vector2(0,-170),Vector2(-10,-186)]),outline)
			draw_circle(Vector2(-15,-170),4,outline)
			draw_circle(Vector2(15,-170),4,outline)
			draw_colored_polygon(PackedVector2Array([Vector2(-12,-155),Vector2(12,-155),Vector2(0,-144)]),Color("ed963f"))
			draw_line(Vector2(-24,-136),Vector2(-20,-45),outline,10)
			draw_line(Vector2(24,-136),Vector2(20,-45),outline,10)
			draw_circle(Vector2(68,-64),28,Color("f5963f"))
			draw_arc(Vector2(68,-64),27,0,TAU,24,outline,3)
			draw_line(Vector2(42,-64),Vector2(94,-64),outline,2)
			draw_line(Vector2(68,-91),Vector2(68,-37),outline,2)
		"rio":
			for x in [-1,1]:
				draw_line(Vector2(x*16,-74),Vector2(x*26,-7),Color("172235"),24)
				draw_line(Vector2(x*33,-147),Vector2(x*48,-92),Color("e9c3af"),15)
			draw_style_box(_plain_box(Color("172235")),Rect2(-34,-148,68,46))
			draw_style_box(_plain_box(Color("e9c3af")),Rect2(-24,-104,48,36))
			draw_circle(Vector2(0,-183),35,Color("274c7d"))
			draw_circle(Vector2(0,-179),27,Color("f5d3bd"))
			draw_colored_polygon(PackedVector2Array([Vector2(-31,-190),Vector2(-18,-220),Vector2(25,-214),Vector2(38,-177),Vector2(14,-195),Vector2(-8,-184)]),Color("438dd5"))
			draw_line(Vector2(-29,-194),Vector2(-39,-115),Color("438dd5"),15)
			draw_line(Vector2(29,-192),Vector2(39,-107),Color("356db0"),16)
			draw_circle(Vector2(-9,-180),3,Color("143451"))
			draw_circle(Vector2(10,-180),3,Color("143451"))
			draw_colored_polygon(PackedVector2Array([Vector2(39,-127),Vector2(72,-230),Vector2(101,-250),Vector2(77,-137)]),Color("c9deed"))
			draw_line(Vector2(45,-126),Vector2(28,-90),outline,9)

func _plain_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color("151724")
	box.set_border_width_all(3)
	box.set_corner_radius_all(6)
	return box

func _shoe_box() -> StyleBoxFlat:
	return _plain_box(Color("e9f2ff"))

func _draw_action() -> void:
	if not is_attacking(): return
	var startup := float(action_data.get("startup",0.1))
	var active := float(action_data.get("active",0.1))
	if active <= 0.0 or action_time<startup or action_time>startup+active: return
	var pulse := sin(clampf((action_time-startup)/active,0.0,1.0)*PI)
	var center := Vector2(body_width*0.45+42,-body_height*0.58)
	var tip:=center
	if pixel_script:
		var visual:=pixel_animation_state()
		var pose: Dictionary=pixel_script.get_pose_state(fighter_id,visual["clip"],visual["progress"])
		tip=pose.get("weapon_tip" if fighter_id in ["rio","worker"] else ("shoe_tip" if fighter_id=="shark" else "paw_tip"),center)
		center=tip.lerp(center,0.25)
	var ink:=Color("a5efff") if fighter_id=="rio" else (Color("baf4ff") if fighter_id=="shark" else Color("fff2b0"))
	if action in ["attack1","attack2","attack3","air_light","air_skill"]:
		var reverse:=action=="attack2"
		var radius:=27.0+pulse*(32 if action=="attack3" else 14)
		draw_arc(center,radius,-1.5 if not reverse else 0.2,0.8 if not reverse else 2.5,12,Color(ink,0.72),8 if action=="attack3" else 4,false)
		draw_line(tip+Vector2(-35,-9 if reverse else 9),tip,Color(ink,0.52),4,false)
	elif action=="launcher":
		draw_arc(Vector2(body_width*.40,-body_height*.44),body_height*.35,-2.15,-0.35,15,Color(ink,0.75),8,false)
		draw_line(tip+Vector2(-12,45),tip,Color(ink,0.55),4,false)
	elif action=="sweep":
		draw_arc(Vector2(body_width*.40,-24),72,-0.4,1.1,13,Color(ink,0.65),8,false)
	elif action=="air_slam":
		draw_line(tip+Vector2(-35,-115),tip+Vector2(12,24),Color(ink,0.62),12,false)
		draw_line(tip+Vector2(-20,-90),tip+Vector2(15,35),Color(1,1,1,.48),4,false)

func _draw_cat_emotion() -> void:
	if emotion == "happy" and not (state=="attack" and action=="skill2"):
		return
	var label := "Huh?"
	if emotion=="cry":
		label = "うえーん"
	elif emotion=="shock":
		label = "！？"
	var y := -render_size.y - 23.0 if texture else -233.0
	draw_style_box(_plain_box(Color("fff3c5")),Rect2(-54,y-30,108,42))
	draw_string(ThemeDB.fallback_font,Vector2(-44,y),label,HORIZONTAL_ALIGNMENT_CENTER,88,22,Color("191724"))
