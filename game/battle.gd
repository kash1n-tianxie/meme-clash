extends Node2D
## Copyright (C) 2021-2026 5DPLAY Game Studio; Godot adaptation (C) 2026.
## SPDX-License-Identifier: GPL-3.0-or-later
## BVN source rules are connected through bvn_*; meme clips, CPU and effects are adapters.

signal match_finished(winner_index: int)
signal pause_page_requested(page: String)
signal exit_requested
signal training_feedback(message: String,success: bool)

const FinishPresentation = preload("res://game/battle_finish_v035.gd")
const FighterScript = preload("res://game/fighter.gd")
const PixelRenderer = preload("res://game/pixel_fighter.gd")
const BVNAI = preload("res://game/bvn_ai.gd")
const BVNInput = preload("res://game/bvn_input.gd")
const BVNMotion = preload("res://game/bvn_motion.gd")
const BVNMap = preload("res://game/bvn_map.gd")
const BVNHit = preload("res://game/bvn_hit_rules.gd")
const BVNPush = preload("res://game/bvn_push_rules.gd")
const SummerTheme = preload("res://game/summer_theme.gd")
const FightHUD = preload("res://game/battle_hud.gd")
const RosterPortrait = preload("res://game/bvn_roster_portrait_v034.gd")
const GameData = preload("res://game/data.gd")
const PlayableWorld = preload("res://game/bvn_playable_world.gd")
const TrainingRoutes = preload("res://game/bvn_training_routes.gd")
const SourceEffectMotion = preload("res://game/source_effect_motion.gd")
const BattleFeedback = preload("res://game/battle_feedback.gd")
const ReactionIdentity = preload("res://game/bvn_reaction_identity_v028.gd")
const BVNEffectFreeze = preload("res://game/bvn_effect_freeze.gd")
const SourceBindings = preload("res://game/bvn_skill_bindings.gd")
const SourceSkillFX = preload("res://game/bvn_skill_fx.gd")
const WojakPunctuationFX = preload("res://game/fx_wojak_v034.gd")
const SourceSkillAudio = preload("res://game/bvn_skill_audio_v029.gd")
const SourcePresentation = preload("res://game/bvn_source_presentation_v031.gd")
const FeedbackSmoothness = preload("res://game/bvn_feedback_smoothness_v038.gd")
const SourceFlashShader = preload("res://game/bvn_source_flash_v031.gdshader")
const StageReadability = preload("res://game/bvn_stage_readability_v029.gd")
const SkillCinema = preload("res://game/skill_cinema.gd")
const PoolFeedback = preload("res://game/pool_stage_feedback.gd")
const AuthoredSkillFX = preload("res://game/authored_skill_fx.gd")
const AuthoredTrainingRoutes = preload("res://game/authored_training_routes.gd")
const CUTIN_SECONDS := 0.55
const WIDTH := 1280.0
const HEIGHT := 960.0
const FLOOR_Y := 830.0
## Transparent controls overlay shares the stage; projection also maps HD feedback.
const ARENA_RECT := Rect2(0,0,1280,960)
const ARENA_SCALE := 1.0
const COMBAT_RENDER_SIZE := Vector2i(800,600)
const SUPER_NAMES := {"shark":"三足ワールドツアー", "cat":"ミーム猫グループチャット", "worker":"本日はここまで！", "chicken":"最優秀練習生", "rio":"大剣、暴走します！", "notify":"通知、全部オフ！", "wojak":"もう知らない"}
const TRAINING_AVAILABLE := ["normal_chain","air_chain","sparring","full_normal","hit_confirm"]
const BATTLE_SFX := ["hit","blade","paw","shoe","ball","case","heavy","guard","counter","launch","land","super","round","dash","charge","swing"]
const P1_KEYS := [KEY_A,KEY_D,KEY_W,KEY_S,KEY_J,KEY_K,KEY_L,KEY_U,KEY_I,KEY_O]
const P2_KEYS := [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6]

var fighters: Array = []
var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var popups: Array[Dictionary] = []
var wins := [0,0]
var round_number := 1
var round_timer := 60.0
var mode := "cpu"
var difficulty := "normal"
var p1_id := "shark"
var p2_id := "chicken"
var phase := "intro"
var phase_time := 0.0
var hitstop := 0.0
## Open3.4 EffectCtrler.freeze: authoritative60Hz frame count. Public hitstop
## mirrors remaining seconds so existing feedback readers keep a stable API.
var source_freeze_frames := 0
var source_freeze_enabled := true
## New character techniques reuse BVN movement/contact rules. Pinned-source
## fixtures explicitly disable this authored layer before setup().
var authored_skills_enabled := false
## Production enables the forty complete source move bundles before setup.
var source_bindings_enabled := false
## Headless source-mechanics fixtures may omit raster asset prewarming explicitly.
var full_pose_rendering_enabled := true
var full_pose_renderer: Script
var skill_audio: RefCounted
var authored_cpu_turn := 0
var authored_cutins: Array[Dictionary]=[]
var cinema_time := 0.0
var cinema_owner := 0
var cinema_name := ""
var cinema_seen: Dictionary={}
var cinema_source_start_frame := 0
var cinema_source_start_clock := 0.0
var cinema_source_binding := ""
var cinema_source_is_super := false
var cinema_source_face := ""
var source_presentation := SourcePresentation.new()
var stage_landings: Array[Dictionary]=[]
var source_floor_impacts: Array[Dictionary]=[]
var source_floor_impact_serial := 0
var stage_actor_history: Dictionary={}
var landing_audio_this_tick: Dictionary={}
var presentation_anchor_history: Dictionary={}
var round_winner := -1
var match_sent := false
var paused := false
var pause_index := 0
## Presentation-only latch. Its timer advances solely in the paused early return.
var pause_pressed_index := -1
var pause_pointer_index := -1
var pause_confirm_index := -1
var pause_confirm_left := 0.0
var pause_focus_clock := 0.0
var shake_enabled := true
var flash_enabled := true
var shake_time := 0.0
var flash_time := 0.0
var zoom_time := 0.0
var stage_map := BVNMap.new()
var camera_zoom := 1.0
var camera_offset := Vector2.ZERO
var camera_shake := Vector2.ZERO
var impact_strength := 1.0
var training_guard := false
var training_reset_time := 0.0
var debug_actions: Dictionary = {}
var previous_keys := [{},{}]
var previous_pad := [{},{}]
var input_latches := [BVNInput.new(),BVNInput.new()]
var cpu_ai := BVNAI.new()
var cpu_cooldown := 0.0
var cpu_intent: Dictionary = {}
var frame_counter := 0
var stage_texture: Texture2D
var impact_texture: Texture2D
var font: Font
var canvas: Node2D
var backdrop: Node2D
var debug_boxes := false
var ready_called := false
var hp_trail := [1000.0,1000.0]
var hp_trail_delay := [0.0,0.0]
var previous_hp := [1000,1000]
var show_controls := false
var controls_visibility: int = 0
var finish_presentation = FinishPresentation.new()
var last_ko_contact: Dictionary = {}
var match_players: Array[Dictionary] = []
var match_elapsed: float = 0.0
var match_combo_damage: Array[float] = [0.0,0.0]
var match_combo_count: Array[int] = [0,0]
var scenery_time := 0.0
var reduced_motion := false
var key_bindings := [P1_KEYS.duplicate(),P2_KEYS.duplicate()]
var pressed_events := [{},{}]
var world_viewport: SubViewport
var world_root: Node2D
var source_flash_layer: ColorRect
var source_flash_material: ShaderMaterial
var world_display: TextureRect
var world_effects: Node2D
var world_skill_back: Node2D
var skill_casts: Array[Dictionary] = []
var skill_releases: Array[Dictionary] = []
var skill_art: Script = preload("res://game/pixel_fighter.gd")
var pixel_stage_script: Script
var training_recipe := "normal_chain"
var training_message := "J → J → J"
var training_stage := 0
var training_moves: Array[String]=[]
var last_inputs := ["",""]
var cpu_route := ""
var training_watched_move := ""
var training_miss_reported := false
var training_completed_serial := -1
var training_last_counted_serial := -1
var training_last_body_contact_serial := -1
var playable_world: RefCounted
var source_map_metadata: Dictionary={}
var training_course: RefCounted
var source_ai_bundle_cache: Dictionary={}

## A borrowed technique brings its original AI marker and HitVO traits too.
## Decision probabilities and orders remain in the pinned BVN AI implementation.
func _source_ai_bundle(actor) -> Dictionary:
	var id: String=str(actor.fighter_id)
	if source_ai_bundle_cache.has(id): return source_ai_bundle_cache[id]
	var base: String=SourceBindings.base_profile_id(id)
	var markers: Dictionary=PlayableWorld.Timeline.ai_ranges(base)
	var marker_profiles: Dictionary={}
	for name in markers: marker_profiles[name]=base
	var slots: Dictionary={"zh1":["skill1","zh1mian"],"zh2":["skill3","zh2mian"],"zh3":["skill2","zh3mian"],"bs":["super","bsmian"],"sbs":["super_up","sbsmian"],"cbs":["super_down","cbsmian"],"tz":["air_skill","tzmian"],"kbs":["air_super","kbsmian"]}
	var traits: Dictionary={}
	var anchors: Dictionary={}
	for hit_key in ["kj1","kj2","zh1","zh2","zh3","tz","bs","sbs","cbs","kbs"]:
		var donor: String=base
		if slots.has(hit_key):
			var binding: Dictionary=SourceBindings.binding_for(id,str(slots[hit_key][0]))
			donor=str(binding.get("donor_profile_id",base))
			var marker_name: String=str(slots[hit_key][1])
			var donor_markers: Dictionary=PlayableWorld.Timeline.ai_ranges(donor)
			if donor_markers.has(marker_name):
				markers[marker_name]=donor_markers[marker_name]; marker_profiles[marker_name]=donor
		traits[hit_key]=PlayableWorld.Timeline.hit_vos_like(donor,hit_key)
	for profile_id in marker_profiles.values():
		if anchors.has(profile_id): continue
		var values: Array=PlayableWorld.Timeline.profile(str(profile_id)).get("foot_anchor",[0,0])
		anchors[profile_id]=Vector2(float(values[0]),float(values[1]))
	var result: Dictionary={"markers":markers,"marker_profiles":marker_profiles,"anchors":anchors,"traits":traits}
	source_ai_bundle_cache[id]=result
	return result

func _exit_tree() -> void:
	# Independent source objects reference their controller world. Break this
	# lifetime cycle when leaving an arena, including a KO with live objects.
	if playable_world: playable_world.reset()
	if skill_audio: skill_audio.reset()


func _ready() -> void:
	if ready_called: return
	font=ThemeDB.fallback_font
	world_viewport=SubViewport.new()
	world_viewport.size=COMBAT_RENDER_SIZE
	# Match the reference's native800x600 arena sampling. The canonical source
	# world/physics remain1280x960; only the illustrated actor raster changes.
	world_viewport.transparent_bg=true
	world_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	world_viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(world_viewport)
	world_root=Node2D.new()
	world_root.scale=Vector2(float(COMBAT_RENDER_SIZE.x)/WIDTH,float(COMBAT_RENDER_SIZE.y)/HEIGHT)
	world_viewport.add_child(world_root)
	backdrop=Node2D.new()
	backdrop.z_index=-30
	backdrop.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	backdrop.draw.connect(_draw_backdrop)
	add_child(backdrop)
	canvas=Node2D.new()
	canvas.z_index=-10
	world_root.add_child(canvas)
	world_skill_back=Node2D.new()
	world_skill_back.z_index=-1
	world_skill_back.draw.connect(_draw_skill_back)
	canvas.add_child(world_skill_back)
	world_effects=Node2D.new()
	world_effects.z_index=5
	world_effects.draw.connect(_draw_world_effects)
	canvas.add_child(world_effects)
	world_display=TextureRect.new()
	world_display.position=ARENA_RECT.position
	world_display.size=ARENA_RECT.size
	world_display.texture=world_viewport.get_texture()
	world_display.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	# A transparent viewport has already composited RGB by alpha. Normal MIX
	# would multiply those painted releases again and hide their faint edges.
	var composite_material:=CanvasItemMaterial.new()
	composite_material.blend_mode=CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	world_display.material=composite_material
	world_display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	world_display.z_index=-20
	add_child(world_display)
	source_flash_layer=ColorRect.new();source_flash_layer.position=ARENA_RECT.position;source_flash_layer.size=ARENA_RECT.size
	source_flash_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;source_flash_layer.z_index=-19
	source_flash_material=ShaderMaterial.new();source_flash_material.shader=SourceFlashShader
	source_flash_layer.material=source_flash_material;add_child(source_flash_layer)
	if ResourceLoader.exists("res://assets/art/stage.png"): stage_texture=load("res://assets/art/stage.png")
	if ResourceLoader.exists("res://assets/vfx/impact.png"): impact_texture=load("res://assets/vfx/impact.png")
	ready_called=true
	queue_redraw()

func set_key_bindings(first: Array, second: Array) -> void:
	if first.size()==10 and second.size()==10:
		key_bindings=[first.duplicate(),second.duplicate()]
		previous_keys=[{},{}]
		pressed_events=[{},{}]
		for latch in input_latches: latch.clear()
		for fighter in fighters: fighter.clear_buffer()
	_refresh_training_label()

func set_training_recipe(recipe: String="normal_chain") -> void:
	training_recipe=recipe if recipe in TRAINING_AVAILABLE else "normal_chain"
	training_stage=0
	training_moves.clear()
	training_watched_move=""
	training_miss_reported=false
	training_completed_serial=-1
	training_last_counted_serial=-1
	training_last_body_contact_serial=-1
	training_course=null
	if training_recipe in TrainingRoutes.COURSE_IDS:
		training_course=AuthoredTrainingRoutes.new() if authored_skills_enabled and training_recipe=="hit_confirm" else TrainingRoutes.new()
		training_course.configure(p1_id,training_recipe)
	if is_sparring_training():
		training_guard=false
		# Main applies the selected recipe after setup. Correct only the opening
		# resource fixture; active sparring never gets a refill from this setter.
		if phase=="intro":
			for fighter in fighters:
				fighter.hype=0.0; fighter.energy=100.0; fighter.energy_overload=false
				fighter.energy_gap=0; fighter.energy_clock=0.0
	_refresh_training_label()

## Practice adapter: reuse the exact live BVN CPU/resource rules without a timer.
func is_sparring_training() -> bool:
	return mode=="training" and training_recipe=="sparring"

func _key_label(slot: int) -> String:
	return OS.get_keycode_string(int(key_bindings[0][slot]))

func get_training_route() -> Dictionary:
	if authored_skills_enabled and training_recipe=="hit_confirm": return AuthoredTrainingRoutes.descriptor(p1_id,training_recipe)
	return TrainingRoutes.descriptor(p1_id,training_recipe)

func get_training_progress() -> Dictionary:
	if training_course:
		var result: Dictionary=training_course.progress()
		result["message"]=training_message
		return result
	return {"recipe":training_recipe,"stage":training_stage,"total":0 if is_sparring_training() else 3,"status":"complete" if training_stage>=3 else "ready","message":training_message,"steps":[],"completion":"","source_profile":""}

func _training_actor_state() -> Dictionary:
	var actor=fighters[0]
	return {"serial":actor.action_serial,"label":actor.source_label,"state":actor.state,"doing_action":actor.source_doing_action or actor.authored_is_active(),"grounded":actor.grounded}

func _apply_training_course(update: Dictionary) -> void:
	if update.is_empty() or not training_course: return
	var state: Dictionary=training_course.progress()
	training_stage=int(state["stage"]); training_moves.assign(state["moves"])
	training_completed_serial=int(state["completed_serial"])
	training_message=str(update.get("message",training_message))
	training_feedback.emit(training_message,bool(update.get("success",false)))

func _refresh_training_label() -> void:
	if training_course:
		var keys: Array[String]=[]
		for step: Dictionary in get_training_route().get("steps",[]):
			if int(step.get("key_slot",-1))<0:
				keys.append("命中時に自動追撃")
				continue
			var text: String=_key_label(int(step["key_slot"]))
			for modifier: int in step.get("modifiers",[]): text=_key_label(modifier)+"+"+text
			keys.append(text)
		training_message=" → ".join(keys)+"（実際の命中を確認・開始時のみ気300）"
		return
	if is_sparring_training():
		training_message="気と体力は実戦と同じ。KOで再開"
		return
	var attack := _key_label(4)
	var jump := _key_label(5)
	var skill := _key_label(7)
	training_message="%s → 空中%s → 空中%s（操作課題）" % [jump,attack,skill] if training_recipe=="air_chain" else "%s → %s → %s（最初の三入力）" % [attack,attack,attack]

func setup(first_id: String, second_id: String, requested_mode: String, requested_difficulty: String = "normal") -> void:
	source_freeze_frames=0
	hitstop=0.0
	p1_id = first_id
	p2_id = second_id
	mode = requested_mode
	difficulty = requested_difficulty
	if not ready_called:
		_ready()
	var audio=get_node_or_null("/root/GameAudio")
	if skill_audio: skill_audio.reset()
	skill_audio=SourceSkillAudio.new(audio)
	if source_bindings_enabled: skill_audio.prewarm([first_id,second_id])
	if audio and audio.has_method("prewarm_sfx"):
		audio.prewarm_sfx(BATTLE_SFX)
	for fighter in fighters:
		fighter.queue_free()
	fighters.clear()
	for i in range(2):
		var fighter = FighterScript.new()
		fighter.source_bindings_enabled=source_bindings_enabled
		if source_bindings_enabled and full_pose_rendering_enabled and ResourceLoader.exists("res://game/bvn_full_pose_renderer.gd"):
			full_pose_renderer=load("res://game/bvn_full_pose_renderer.gd")
			fighter.source_actor_renderer=full_pose_renderer
		canvas.add_child(fighter)
		fighter.configure(first_id if i==0 else second_id, i)
		fighter.authored_skills_enabled=authored_skills_enabled
		fighter.action_started.connect(_fighter_action_started.bind(i))
		fighter.landed.connect(_fighter_landed.bind(i))
		fighter.source_floor_impact.connect(_fighter_source_floor_impact.bind(i))
		fighters.append(fighter)
	playable_world=PlayableWorld.new()
	playable_world.initialize(self)
	if ResourceLoader.exists("res://game/data.gd"):
		var data_script = load("res://game/data.gd")
		if data_script:
			var roster = data_script.get("ROSTER")
			if roster is Dictionary:
				for fighter in fighters:
					var info: Dictionary = roster.get(fighter.fighter_id,{})
					fighter.display_name = str(info.get("name",fighter.display_name))
	restart_match()
	# Build immutable local silhouettes/envelopes while loading the arena. Avoid
	# a first-attack/first-AI-turn cache stall once the playable countdown finishes.
	for fighter in fighters:
		if source_bindings_enabled and full_pose_renderer:
			full_pose_renderer.prewarm(fighter.fighter_id)
			SourceSkillFX.prewarm_character(fighter.fighter_id)
		else:
			PixelRenderer.prewarm_render_assets(fighter.fighter_id)
		_source_ai_ranges(fighter)
	if source_bindings_enabled and full_pose_renderer and DisplayServer.get_name()!="headless":
		var cast_fonts: SubViewport=preload("res://game/bvn_cast_font_warmup_v039.gd").new()
		cast_fonts.prepare([first_id,second_id],font)
		add_child(cast_fonts)

func set_feedback_options(shake_option: bool, flash_option: bool) -> void:
	shake_enabled = shake_option
	flash_enabled = flash_option

## This changes visual amplitudes and history only; combat clocks remain intact.
func set_reduced_motion(enabled: bool) -> void:
	reduced_motion=enabled
	if reduced_motion:
		for fighter in fighters:
			if fighter.trail.size()>1: fighter.trail.resize(1)
	queue_redraw()

func restart_match() -> void:
	match_elapsed=0.0
	match_players.clear()
	for id: String in [p1_id,p2_id]:
		match_players.append({"id":id,"damage_dealt":0.0,"damage_taken":0.0,"max_combo":0,"max_combo_damage":0.0})
	wins = [0,0]
	round_number = 1
	paused = false
	pause_index = 0
	match_sent = false
	training_guard = false
	previous_keys = [{},{}]
	previous_pad = [{},{}]
	for latch in input_latches: latch.clear()
	_start_round()

func _start_round() -> void:
	finish_presentation.reset()
	if world_effects: world_effects.modulate=Color.WHITE
	if world_skill_back: world_skill_back.modulate=Color.WHITE
	last_ko_contact.clear()
	match_combo_damage=[0.0,0.0]
	match_combo_count=[0,0]
	source_presentation.reset()
	_sync_source_flash_layer()
	cinema_source_is_super=false;cinema_source_face=""
	if skill_audio: skill_audio.reset()
	stage_landings.clear();source_floor_impacts.clear();source_floor_impact_serial=0;stage_actor_history.clear();presentation_anchor_history.clear()
	if playable_world: playable_world.reset()
	if source_map_metadata.is_empty():
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/logic/bvn-playable-map.json"))
		if parsed is Dictionary: source_map_metadata=parsed
	var raw: Dictionary=source_map_metadata.get("raw_markers",{})
	var point1: Array=raw.get("p1",[377.1,366])
	var point2: Array=raw.get("p2",[615.1,366])
	stage_map.configure({"line_left":float(raw.get("left",0))*1.6,"line_right":float(raw.get("right",1000))*1.6,"line_bottom":float(raw.get("bottom",395))*1.6,"line_player_bottom":float(raw.get("player_bottom",366))*1.6,"p1":Vector2(float(point1[0]),float(point1[1]))*1.6,"p2":Vector2(float(point2[0]),float(point2[1]))*1.6,"layers":{"map":Vector2.ZERO},"floor":source_map_metadata.get("floors",[])},Vector2(WIDTH,HEIGHT),Vector2(float(source_map_metadata.get("map_layer_width",1000))*1.6,HEIGHT))
	# GameStage.as:492-499 uses 1.0..2.5; uniform 1.6x source coordinates.
	stage_map.auto_zoom_max=2.5
	stage_map.side_offset=16.0
	projectiles.clear()
	effects.clear()
	skill_casts.clear()
	skill_releases.clear()
	popups.clear()
	authored_cutins.clear()
	round_timer = 60.0
	phase = "intro"
	phase_time = 2.15
	round_winner = -1
	combo_clear()
	hitstop = 0.0
	source_freeze_frames = 0
	cinema_time = 0.0
	cinema_seen.clear()
	shake_time = 0.0
	flash_time = 0.0
	hp_trail=[1000.0,1000.0]
	hp_trail_delay=[0.0,0.0]
	previous_hp=[1000,1000]
	zoom_time = 0.0
	camera_zoom = 1.0
	cpu_cooldown = 0.0
	authored_cpu_turn=0
	cpu_ai.configure(1 if difficulty in ["easy","やさしい"] else (6 if difficulty in ["hard","むずかしい"] else 3))
	cpu_intent.clear()
	training_reset_time = 0.0
	if mode=="training": set_training_recipe(training_recipe)
	for i in range(fighters.size()):
		fighters[i].stage_floor_y=stage_map.player_bottom
		fighters[i].reset_round(stage_map.p1pos.x if i==0 else stage_map.p2pos.x)
		if mode=="training" and not is_sparring_training():
			fighters[i].hype = 300.0
	queue_redraw()

func combo_clear() -> void:
	debug_actions.clear()
	pressed_events=[{},{}]
	for fighter in fighters: fighter.clear_buffer()

func get_debug_state() -> Dictionary:
	var actor_states: Array[Dictionary] = []
	for fighter in fighters:
		actor_states.append({"id":fighter.fighter_id,"hp":fighter.hp,"hype":fighter.hype,"x":fighter.position.x,"y":fighter.position.y,"state":fighter.state,"action":fighter.action,"combo":fighter.combo_hits,"burst_used":fighter.burst_used,"animation":fighter.animation_frame_state(),"pixel_animation":fighter.pixel_animation_state(),"guard":fighter.guarding,"buffer":fighter.pending_command,"combo_damage":fighter.combo_damage,"protected":fighter.is_protected()})
	return {"fighters":actor_states,"authored_skills":authored_skills_enabled,"round":round_number,"timer":round_timer,"wins":wins.duplicate(),"phase":phase,"paused":paused,"projectiles":projectiles.size(),"cinema":cinema_time,"frame":frame_counter,"effects":effects.size(),"camera_zoom":camera_zoom,"bvn_camera":stage_map.get_camera_state(),"training_message":training_message,"training_stage":training_stage,"last_inputs":last_inputs.duplicate(),"world_size":world_viewport.size if world_viewport else Vector2i.ZERO}

func debug_action(player_index: int, action: String) -> void:
	if player_index>=0 and player_index<2:
		debug_actions[player_index] = action

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or fighters.size()!=2:
		return
	if event is InputEventKey and event.pressed and not event.echo and not paused and phase=="active":
		var physical: int= event.physical_keycode if event.physical_keycode!=0 else event.keycode
		for index in range(2):
			if index==1 and mode!="local": continue
			for slot in range(10):
				if physical==key_bindings[index][slot] or _keypad_alias(index,slot,physical):
					pressed_events[index][slot]=true
					if slot>=4:
						pressed_events[index]["up_snapshot"]=Input.is_physical_key_pressed(int(key_bindings[index][2])) or pressed_events[index].get(2,false)
						pressed_events[index]["down_snapshot"]=Input.is_physical_key_pressed(int(key_bindings[index][3])) or pressed_events[index].get(3,false)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			paused = not paused
			combo_clear()
			pause_index = 0
			_reset_pause_feedback()
			get_viewport().set_input_as_handled()
			queue_redraw()
			return
		if paused:
			if pause_confirm_index<0:
				if event.keycode in [KEY_W,KEY_UP]:
					_set_pause_focus(posmod(pause_index-1,5))
				elif event.keycode in [KEY_S,KEY_DOWN]:
					_set_pause_focus(posmod(pause_index+1,5))
				elif event.keycode in [KEY_ENTER,KEY_SPACE,KEY_J]:
					_confirm_pause()
			get_viewport().set_input_as_handled()
			queue_redraw()
			return
		if mode=="training" and event.keycode==KEY_R:
			_start_round()
			phase = "active"
		elif mode=="training" and not is_sparring_training() and event.keycode==KEY_T:
			training_guard = not training_guard
		elif event.keycode==KEY_F3:
			controls_visibility=(controls_visibility+1)%3
			show_controls=controls_visibility>0
		elif event.keycode==KEY_F4:
			debug_boxes = not debug_boxes
	if event is InputEventMouseMotion and paused:
		pause_pointer_index=_pause_index_at(get_global_transform_with_canvas().affine_inverse()*event.position)
		if pause_confirm_index<0 and pause_pointer_index>=0:
			_set_pause_focus(pause_pointer_index)
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_START:
			paused = not paused
			combo_clear()
			pause_index = 0
			_reset_pause_feedback()
		elif paused:
			if event.button_index==JOY_BUTTON_B:
				paused=false
				combo_clear()
				_reset_pause_feedback()
			elif pause_confirm_index<0:
				if event.button_index==JOY_BUTTON_DPAD_UP:
					_set_pause_focus(posmod(pause_index-1,5))
				elif event.button_index==JOY_BUTTON_DPAD_DOWN:
					_set_pause_focus(posmod(pause_index+1,5))
				elif event.button_index==JOY_BUTTON_A:
					_confirm_pause()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and paused:
		if pause_confirm_index<0:
			pause_pointer_index=_pause_index_at(get_global_transform_with_canvas().affine_inverse()*event.position)
			if event.pressed:
				pause_pressed_index=pause_pointer_index
				if pause_pointer_index>=0: _set_pause_focus(pause_pointer_index)
			else:
				var origin:=pause_pressed_index
				pause_pressed_index=-1
				if origin>=0 and pause_pointer_index==origin:
					_set_pause_focus(origin)
					_confirm_pause()
		get_viewport().set_input_as_handled()
	queue_redraw()

func _reset_pause_feedback() -> void:
	pause_pressed_index=-1
	pause_pointer_index=-1
	pause_confirm_index=-1
	pause_confirm_left=0.0
	pause_focus_clock=0.0

func _pause_index_at(point: Vector2) -> int:
	for index in range(5):
		if _pause_button_rect(index).has_point(point): return index
	return -1

func _set_pause_focus(index: int) -> void:
	if pause_index!=index:
		pause_index=index
		pause_focus_clock=0.0

func _confirm_pause() -> void:
	if not paused or pause_confirm_index>=0: return
	pause_pressed_index=-1
	pause_confirm_index=pause_index
	pause_confirm_left=SummerTheme.CONFIRM_SECONDS
	_sfx("click")
	queue_redraw()

func _advance_pause_feedback(delta: float) -> void:
	pause_focus_clock+=delta
	if pause_confirm_index<0: return
	pause_confirm_left=maxf(0.0,pause_confirm_left-delta)
	if pause_confirm_left<=0.0:
		pause_index=pause_confirm_index
		_activate_pause()

## Draw-only transforms never move the mouse target. No source pose is sampled.
func _pause_button_presentation(index: int) -> Dictionary:
	var state: String="confirmed" if pause_confirm_index==index else "disabled" if pause_confirm_index>=0 else "pressed" if pause_pressed_index==index and pause_pointer_index==index else "focus" if pause_index==index else "default"
	var hit_rect:=_pause_button_rect(index)
	var visual_rect:=hit_rect
	if not reduced_motion:
		if state=="focus":
			var amount:=clampf(pause_focus_clock/SummerTheme.HOVER_SECONDS,0.0,1.0)
			visual_rect.position+=Vector2(-4 if index in [0,2] else 5,-1)*amount
			visual_rect=visual_rect.grow_individual(2*amount,0,2*amount,0)
		elif state in ["pressed","confirmed"]:
			visual_rect.position+=Vector2(2,3)
			visual_rect=visual_rect.grow_individual(-3,-1,-3,-1)
	return {"state":state,"hit_rect":hit_rect,"visual_rect":visual_rect,"reduced_motion":reduced_motion}

func _activate_pause() -> void:
	_reset_pause_feedback()
	match pause_index:
		0: paused=false
		1: restart_match()
		2: exit_requested.emit()
		3: pause_page_requested.emit("skills")
		4: pause_page_requested.emit("settings")

func _physics_process(delta: float) -> void:
	var floor_observation: Array[Dictionary]=[]
	landing_audio_this_tick.clear()
	if skill_audio:skill_audio.set_suspended(paused,source_freeze_frames>0 or hitstop>0 or (playable_world!=null and playable_world.bisha_owner>=0))
	for actor in fighters:
		floor_observation.append({"grounded":actor.grounded,"y":actor.position.y,"key":actor.get_instance_id(),"speed":maxf(0.0,float(actor.velocity.y)+(float(actor.bvn_motion.gravity)*BVNMotion.VELOCITY_UNIT if actor.bvn_apply_gravity else 0.0))})
	var active_before: bool=phase=="active" and not paused
	if active_before: match_elapsed+=delta
	_step_source_battle(delta)
	# A normal BVN fall moves through its separate G even when vy==0. Observe
	# the actual floor edge after the source update; do not change Fighter's
	# original landing opcode, floor test, velocity reset or source branch.
	if active_before and phase=="active" and not paused and source_bindings_enabled and skill_audio:
		for index in range(mini(fighters.size(),floor_observation.size())):
			var actor: Variant=fighters[index];var old: Dictionary=floor_observation[index]
			if old.key==actor.get_instance_id() and not old.grounded and actor.grounded and actor.visible and actor.hurt_fly.is_empty() and not landing_audio_this_tick.has(old.key):
				var speed: float=maxf(float(old.speed),(actor.position.y-float(old.y))/maxf(delta,.00001))
				if speed>=180.0:skill_audio.on_landing(actor,speed)

	source_presentation.reconcile(fighters)
	_refresh_source_shake_projection()
	_sync_source_flash_layer()
	_update_skill_audio_presentation()

func _update_skill_audio_presentation() -> void:
	if not skill_audio or not source_bindings_enabled: return
	skill_audio.set_suspended(paused,source_freeze_frames>0 or hitstop>0 or (playable_world!=null and playable_world.bisha_owner>=0))
	skill_audio.begin_tick()
	for actor in fighters: skill_audio.update_actor(actor)
	if playable_world:
		for object in playable_world.objects: skill_audio.update_object(object)
	skill_audio.end_tick()

func _source_presentation_event(actor, method: String, args: Array) -> void:
	if method=="hitFloor":
		_fighter_source_floor_impact({"event":"source_opcode","type":int(SourcePresentation.argument(args,0,0)),"strength":0.0,"position":Vector2(actor.position.x,actor.stage_floor_y),"source_label":actor.source_label,"source_generation":actor.source_generation,"source_frame":actor.source_frame,"source_absolute_frame":actor.source_absolute_frame},int(actor.player_index))
		return
	source_presentation.event(int(actor.player_index),int(actor.action_serial),method,args)
	if method=="endShake":_refresh_source_shake_projection()

func _refresh_source_shake_projection() -> void:
	var strength:=.22 if reduced_motion else 1.0
	var contact: Vector2=source_presentation.contact_shake(impact_strength*FeedbackSmoothness.contact_gain(shake_time)) if shake_time>0 else Vector2.ZERO
	camera_shake=(source_presentation.sample_shake()+contact)*strength if shake_enabled else Vector2.ZERO
	if canvas:canvas.position=camera_offset+camera_shake
	if backdrop:backdrop.position.x=clampf(-40.0+camera_offset.x*.02+camera_shake.x*.45,-80.0,0.0)

func _sync_source_flash_layer() -> void:
	if source_flash_layer==null:return
	var colors:=PackedColorArray();var modes:=PackedInt32Array()
	for index in range(8):
		var tint:=Color(0,0,0,0);var dark:=0
		if index<source_presentation.flashes.size() and flash_enabled:
			var source: Dictionary=source_presentation.flashes[index]
			tint=source.color;tint.a=float(source.alpha)*(.22 if reduced_motion else 1.0)
			dark=1 if str(source.source_blend)=="darken" else 0
		colors.append(tint);modes.append(dark)
	source_flash_material.set_shader_parameter("flash_colors",colors)
	source_flash_material.set_shader_parameter("flash_dark",modes)
	source_flash_material.set_shader_parameter("flash_count",source_presentation.flashes.size() if flash_enabled else 0)
	# Two harmless zero-count intro draws prewarm the actual screen shader.
	source_flash_layer.visible=(flash_enabled and not source_presentation.flashes.is_empty()) or frame_counter<=2

func _source_audio_event(actor, method: String, args: Array) -> bool:
	if source_bindings_enabled and skill_audio and skill_audio.has_method("on_source_event"):
		return bool(skill_audio.on_source_event(actor,method,args))
	return false

func _source_skill_audio_manages(actor) -> bool:
	return source_bindings_enabled and skill_audio!=null and SourceSkillAudio.manages_actor(actor)

func _source_skill_audio_manages_binding(binding_id: String) -> bool:
	return source_bindings_enabled and skill_audio!=null and not SourceSkillAudio.binding(binding_id).is_empty()

func _step_source_battle(delta: float) -> void:
	if fighters.size()!=2: return
	frame_counter+=1
	var intents: Array[Dictionary]=[_read_player(0),{}]
	if mode=="local": intents[1]=_read_player(1)
	elif mode=="training": intents[1]={"guard":training_guard}
	if paused:
		for fighter in fighters: fighter.clear_buffer()
		_advance_pause_feedback(delta)
		queue_redraw()
		return
	_update_visuals(delta)
	# EffectCtrler142–146/762–775 advances its slow timer before the
	# gameplay-freeze/bisha early returns. Explicit user pause above stops both.
	if playable_world and playable_world.slow_time>0:
		playable_world.slow_time=maxf(0,playable_world.slow_time-delta)
		if playable_world.slow_time<.0000001:
			playable_world.slow_time=0.0; playable_world.speed_rate=1.0
	# EffectCtrler.renderFreeze212–224 runs before GameCtrler's game/bisha path:
	# decrement first; the tick that reaches0 resumes. Effects above still render.
	if source_freeze_frames>0:
		source_freeze_frames-=1
		hitstop=float(source_freeze_frames)/BVNEffectFreeze.FPS_GAME
		if source_freeze_frames>0:
			queue_redraw()
			return
	for index in range(2):
		# Human input lifetime is owned solely by the official 100ms raw-key latch.
		if index==0 or mode=="local": fighters[index].clear_buffer()
		if debug_actions.has(index):
			var command := str(debug_actions[index])
			intents[index]["action"]="" if command=="burst" else command
			intents[index]["burst"]=command=="burst"
		debug_actions.erase(index)
		var command := str(intents[index].get("action",""))
		if intents[index].get("burst",false):
			fighters[index].clear_buffer()
			fighters[index].buffer_action("burst")
		elif not command.is_empty(): fighters[index].buffer_action(command,float(intents[index].get("input_life",BVNInput.INPUT_DELAY)))
	if playable_world and playable_world.bisha_owner>=0:
		playable_world.source_clock+=delta
		var animation_boundary: bool=playable_world.source_clock+.0000001>=1.0/30
		if animation_boundary: playable_world.source_clock-=1.0/30
		var actor=fighters[playable_world.bisha_owner]
		actor.source_animate_only(delta,animation_boundary)
		for fighter in fighters: fighter.clear_buffer()
		world_skill_back.queue_redraw(); world_effects.queue_redraw(); queue_redraw()
		return
	if cinema_time>0:
		cinema_time=maxf(0,cinema_time-delta)
		hitstop=maxf(0,hitstop-delta)
		if cinema_time>0.13:
			for fighter in fighters: fighter.clear_buffer()
		queue_redraw()
		return
	if hitstop>0:
		hitstop=maxf(0,hitstop-delta)
		queue_redraw()
		return
	if playable_world and playable_world.speed_rate>1.0:
		delta/=playable_world.speed_rate
	if phase=="intro":
		phase_time-=delta
		for i in range(2): fighters[i].clear_buffer(); fighters[i].advance(delta,{},fighters[1-i].position.x)
		if phase_time<=0: phase="active"; _sfx("round")
		queue_redraw(); return
	if phase=="round_end":
		phase_time-=delta
		finish_presentation.advance(delta)
		if not finish_presentation.kind.is_empty():
			# Retire the actual lethal frame visually; never keep frozen child hitboxes
			# on screen through victory or advance the dead match for extra hits.
			var tail_alpha: float=clampf((.95-finish_presentation.age)/.70,0.0,1.0)
			world_effects.modulate.a=tail_alpha
			world_skill_back.modulate.a=tail_alpha
		if finish_presentation.contact_hold():
			for actor in fighters: actor.clear_buffer()
			queue_redraw(); return
		if round_winner>=0 and finish_presentation.victory_ready() and fighters[round_winner].preview_animation!="dance":
			fighters[round_winner].set_animation_preview("dance")
		# Continue the real shared30Hz residue after contacts have stopped.
		# Calling World.advance here would also change objects/attractions.
		var ko_animation_boundary: bool=false
		if playable_world:
			playable_world.source_clock+=delta
			ko_animation_boundary=playable_world.source_clock+.0000001>=1.0/30.0
			if ko_animation_boundary:playable_world.source_clock-=1.0/30.0
		for i in range(2):
			fighters[i].clear_buffer()
			# Narrow KO-only correction preserves the survivor's existing
			# finish-action physics/scripts and timer/input behavior this patch.
			if playable_world and not fighters[i].source_ko_visual_state().is_empty():fighters[i].source_sync_animation_tick(ko_animation_boundary)
			fighters[i].advance(delta,{},fighters[1-i].position.x)
		if phase_time<=0:
			if wins[0]>=2 or wins[1]>=2:
				phase="finished"
				if not match_sent: match_sent=true; match_finished.emit(0 if wins[0]>=2 else 1)
			else: round_number+=1; _start_round()
		queue_redraw(); return
	if phase!="active": return
	if mode=="cpu" or is_sparring_training():
		intents[1]=_cpu_input(delta)
		if intents[1].get("burst",false): fighters[1].clear_buffer(); fighters[1].buffer_action("burst")
		elif not str(intents[1].get("action","")).is_empty(): fighters[1].buffer_action(str(intents[1]["action"]))
	for i in range(2):
		var actor=fighters[i]
		if i==1 and mode=="training" and authored_skills_enabled and training_recipe=="hit_confirm" and p1_id=="worker" and not training_guard:
			var waiting: Dictionary=fighters[0].authored_visual_state()
			if str(waiting.get("semantic_move_id",""))=="worker_deadline_counter" and int(waiting.get("frame",0))==5:
				actor.buffer_action("attack1") # A real dummy J, with normal startup/contact.
		if actor.pending_command=="hurt_break" or actor.pending_command=="burst":
			_do_hurt_break(i); actor.clear_buffer(); intents[i]["action"]=""; intents[i]["jump"]=false
		elif actor.pending_command.begins_with("ghost"):
			_do_burst(i,actor.pending_command); actor.clear_buffer(); intents[i]["action"]=""; intents[i]["jump"]=false
		elif actor.pending_command=="throw_tech": _try_throw_tech(i); actor.clear_buffer()
		elif actor.pending_command=="dash" and not actor.hurt_fly.is_empty(): actor.try_bvn_floor_recovery(); actor.clear_buffer()
		if actor.grounded and not actor.is_locked() and fighters[1-i].combo_hits==0:
			actor.air_light_used=false; actor.air_slam_used=false
		var pending_before: String=actor.pending_command
		var serial_before: int=actor.action_serial
		var movement: Dictionary=intents[i].duplicate()
		movement["action"]=""; movement["jump"]=false
		if playable_world: actor.source_sync_animation_tick(playable_world.source_clock+delta+.0000001>=1.0/30.0)
		actor.advance(delta,movement,fighters[1-i].position.x)
		actor.position=stage_map.fix_sprite_position(actor.position,actor.velocity.x)["position"]
		_release_skill_if_ready(i)
		if mode=="training" and i==0 and not pending_before.is_empty() and pending_before not in ["burst","throw_tech"] and actor.pending_command.is_empty() and actor.action_serial==serial_before and not actor.reject_reason.is_empty():
			training_message="接続が早すぎる" if actor.is_attacking() and actor.action_time<float(actor.action_data.get("startup",0.1))+0.02 else ("熱量不足" if actor.reject_reason=="熱量不足" else "接続できない・入力を確認")
			training_feedback.emit(training_message,false)
		_spawn_action_prop(i)
	_resolve_pushboxes()
	for i in range(2):
		if fighters[i].authored_skills_enabled:
			fighters[i].authored_world_step(delta,fighters[1-i])
	if playable_world:
		playable_world.advance(delta)
		# Sample both accepted attacks before a mutual hit can change either
		# owner's reaction label. The outer pass is idempotent during freeze.
		_update_skill_audio_presentation()
		if playable_world.animation_tick: _resolve_playable_contacts()
		elif authored_skills_enabled: _resolve_source_and_authored_contacts(false)
	else: _resolve_melee_pair(intents)
	_update_projectiles(delta)
	if mode=="training": _training_update(delta)
	else:
		round_timer=maxf(0,round_timer-delta)
		if fighters[0].hp<=0 or fighters[1].hp<=0 or round_timer<=0: _finish_round()
	world_effects.queue_redraw(); queue_redraw(); backdrop.queue_redraw()

func _keypad_alias(index: int,slot: int,key: int) -> bool:
	if index!=1 or slot<4: return false
	var top := [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6]
	var keypad := [KEY_KP_1,KEY_KP_2,KEY_KP_3,KEY_KP_4,KEY_KP_5,KEY_KP_6]
	return int(key_bindings[index][slot])==int(top[slot-4]) and key==int(keypad[slot-4])

func _read_player(index: int) -> Dictionary:
	var held: Dictionary={}
	var fresh: Dictionary={}
	for slot in range(10):
		var key: int=int(key_bindings[index][slot])
		held[slot]=Input.is_physical_key_pressed(key)
		if index==1 and slot>=4:
			var keypad := [KEY_KP_1,KEY_KP_2,KEY_KP_3,KEY_KP_4,KEY_KP_5,KEY_KP_6]
			if _keypad_alias(index,slot,keypad[slot-4]): held[slot]=held[slot] or Input.is_physical_key_pressed(keypad[slot-4])
		fresh[slot]=(held[slot] and not previous_keys[index].get(slot,false)) or pressed_events[index].get(slot,false)
	previous_keys[index]=held.duplicate()
	var up_snapshot: bool=pressed_events[index].get("up_snapshot",false)
	var down_snapshot: bool=pressed_events[index].get("down_snapshot",false)
	pressed_events[index].clear()
	var axis := float(int(held[1])-int(held[0]))
	var up: bool=held[2] or up_snapshot
	var down: bool=held[3] or down_snapshot
	var pads := Input.get_connected_joypads()
	if index<pads.size():
		var device: int=pads[index]
		var analog := Input.get_joy_axis(device,JOY_AXIS_LEFT_X)
		if absf(analog)>0.22: axis=signf(analog)
		if Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_LEFT): axis=-1
		if Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_RIGHT): axis=1
		up=up or Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_UP) or Input.get_joy_axis(device,JOY_AXIS_LEFT_Y)<-0.45
		down=down or Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_DOWN) or Input.get_joy_axis(device,JOY_AXIS_LEFT_Y)>0.45
		var buttons := [JOY_BUTTON_X,JOY_BUTTON_A,JOY_BUTTON_B,JOY_BUTTON_Y,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_LEFT_SHOULDER]
		var pad_held: Dictionary={}
		for button_index in range(buttons.size()):
			var button: int=buttons[button_index]
			pad_held[button]=Input.is_joy_button_pressed(device,button)
			held[button_index+4]=held[button_index+4] or pad_held[button]
			fresh[button_index+4]=fresh[button_index+4] or pad_held[button] and not previous_pad[index].get(button,false)
		previous_pad[index]=pad_held
	var delayed: Dictionary=input_latches[index].tick(1.0/60.0,fresh)
	var result:=resolve_controls(index,axis,up,down,delayed,held.get(4,false),held.get(5,false),held.get(9,false))
	# Branches need a real new press, never the repeating 100ms source latch.
	result["fresh_J"]=bool(fresh.get(4,false))
	result["fresh_K"]=bool(fresh.get(5,false))
	result["fresh_U"]=bool(fresh.get(7,false))
	result["held_U"]=bool(held.get(7,false))
	var life:=0.0
	for value in input_latches[index].delayed_keys.values(): life=maxf(life,float(value))
	result["input_life"]=life
	return result

## Shared semantic resolver is used by keyboard/pad and input regression tests.
func resolve_controls(index: int,axis: float,up: bool,down: bool,fresh: Dictionary,attack_held: bool=false,jump_held: bool=false,special_held: bool=false) -> Dictionary:
	var actor=fighters[index]
	var target=fighters[1-index]
	var face := 1 if target.position.x>=actor.position.x else -1
	var flags:=BVNInput.predicates(axis,up,down,fresh,attack_held,jump_held)
	var result := {"axis":axis,"guard":flags["defense"],"retreat":axis*face<0,"action":"","burst":false,"source_up":up,"source_down":down,"fresh_J":bool(fresh.get(4,false)),"fresh_K":bool(fresh.get(5,false)),"fresh_U":bool(fresh.get(7,false))}
	var command := ""
	if (fresh.get(9,false) or special_held) and actor.can_hurt_break(): result["burst"]=true; command="hurt_break"
	elif actor.state=="throw_hold" and fresh.get(4,false): command="throw_tech"
	else:
		var can_throw: bool=not actor.is_locked() and target.grounded and not target.is_protected() and not target.is_combo_locked() and actor.allow_bvn_catch(target)
		var candidates: Array[String]=actor.source_input_candidates(flags,can_throw,down) if source_bindings_enabled else BVNInput.command_candidates(flags,actor.grounded,can_throw,down)
		for candidate in candidates:
			if candidate.begins_with("ghost") or actor.command_enabled(candidate):
				command=candidate
				break
	if command!="burst": result["action"]=command
	if not command.is_empty(): last_inputs[index]=command
	return result

## Source fixtures retain original30Hz AI decisions. Production uses this as the
## movement/defense base and adapts technique choices to the new real props.
func _source_ai_state(actor) -> Dictionary:
	var body: Rect2=actor.body_box()
	return {"x":actor.position.x/1.6,"y":actor.position.y/1.6,"direct":actor.facing,"action_state":actor.source_action_state(),"energy":actor.energy,"qi":actor.hype,"hp":actor.hp,"hp_max":1000,"cur_action":actor.source_action_label(),"is_fighter":true,"allow_be_hit":actor.hp>0 and not actor.is_protected(),"body_area":Rect2(body.position/1.6,body.size/1.6)}

func _source_ai_ranges(actor) -> Dictionary:
	var result: Dictionary={}
	# Authored AImain frame2 markers, exactly as FighterMC.initHitRange reads them.
	# These are source AI reach rectangles, not unioned J1..3 hitboxes or a
	# predicted trajectory from the obsolete meme-projectile adapter.
	var bundle: Dictionary=_source_ai_bundle(actor) if source_bindings_enabled else {}
	var markers: Dictionary=bundle["markers"] if source_bindings_enabled else PlayableWorld.Timeline.ai_ranges(actor.fighter_id)
	for name in markers:
		var values: Array=markers[name].get("source_rect",[])
		if values.size()!=4: continue
		var native:=Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3]))
		var area: Rect2
		if source_bindings_enabled:
			var anchor: Vector2=bundle["anchors"][bundle["marker_profiles"][name]]
			area=Rect2((native.position-anchor)*1.6,native.size*1.6)
			if actor.facing<0: area.position.x=-area.end.x
			area.position+=actor.position
		else: area=actor._source_world_rect(native)
		result[name]=Rect2(area.position/1.6,area.size/1.6)
	return result

func _source_ai_hit_traits(actor) -> Dictionary:
	if source_bindings_enabled: return _source_ai_bundle(actor)["traits"]
	var result: Dictionary={}
	# Original FighterHitModel.getHitVOLike searches the real registered VO IDs.
	for key in ["kj1","kj2","zh1","zh2","zh3","tz","bs","sbs","cbs","kbs"]:
		result[key]=PlayableWorld.Timeline.hit_vos_like(actor.fighter_id,key)
	return result

func _cpu_input(delta: float) -> Dictionary:
	var actor=fighters[1]
	var target=fighters[0]
	var threats: Array=[]
	if playable_world:
		for object in playable_world.objects:
			if object.owner_index==1 or object.removed: continue
			var active: bool=object.hit_able if object.kind=="bullet" else object.attacking
			threats.append({"kind":object.kind,"x":object.position.x/1.6,"y":object.position.y/1.6,"attacking":active})
	var flags: Dictionary=cpu_ai.tick(delta,_source_ai_state(actor),_source_ai_state(target),threats,actor.frame_action_flags(),_source_ai_ranges(actor),_source_ai_hit_traits(actor))
	flags["moveLEFT"]=flags.get("moveLeft",false)
	flags["moveRIGHT"]=flags.get("moveRight",false)
	flags["dashJump"]=flags.get("downJump",false)
	flags["ghostJumpDown"]=flags.get("ghostJumpDowm",false)
	var axis:=(-1.0 if flags["moveLEFT"] else 0.0)+(1.0 if flags["moveRIGHT"] else 0.0)
	var result: Dictionary={"axis":axis,"guard":bool(flags.get("defense",false)),"retreat":axis*actor.facing<0,"action":"","burst":false}
	var can_throw: bool=not actor.is_locked() and target.grounded and not target.is_protected() and not target.is_combo_locked() and actor.allow_bvn_catch(target)
	var candidates: Array[String]=actor.source_input_candidates(flags,can_throw,bool(flags.get("jumpDown",false))) if source_bindings_enabled else BVNInput.command_candidates(flags,actor.grounded,can_throw,bool(flags.get("jumpDown",false)))
	for candidate in candidates:
		if candidate.begins_with("ghost") or actor.command_enabled(candidate):
			result["action"]=candidate
			break
	if bool(flags.get("downJump",false)) and not actor.hurt_fly.is_empty(): result["action"]="dash"
	if bool(flags.get("specialSkill",false)) and actor.can_hurt_break(): result["action"]="hurt_break"
	if authored_skills_enabled: result=_authored_cpu_techniques(delta,result,actor,target)
	cpu_intent=result.duplicate()
	return result

## Upstream movement/defense remains the base. New skills require their actual
## props and branch windows rather than the old XML's projectile assumptions.
func _authored_cpu_techniques(delta: float,result: Dictionary,actor,target) -> Dictionary:
	cpu_cooldown=maxf(0,cpu_cooldown-delta)
	result.merge({"fresh_J":false,"fresh_K":false,"fresh_U":false,"held_U":false},true)
	var visual: Dictionary=actor.authored_visual_state()
	var semantic: String=str(visual.get("semantic_move_id",visual.get("move_id","")))
	var stage: String=str(visual.get("stage",""))
	var age: int=int(visual.get("frame",0))
	var distance: float=absf(actor.position.x-target.position.x)
	var has_ball: bool=bool(visual.get("ball_in_hand",true))
	var has_folder: bool=str(visual.get("trap_state","none"))!="none"
	if actor.authored_is_active():
		result["action"]=""; result["axis"]=0.0; result["guard"]=false
		if semantic=="rio_drag_charge": result["held_U"]=age<43
		if stage in ["stance","branch","window"] or semantic in ["cat_meme_sway","chicken_dribble_sway","shark_shoe_dash"]:
			if age>=11 and age<=16:
				# One new edge; the actor consumes it once. A far opponent earns a
				# brake/fake, an aerial opponent the hopping branch.
				var button: String="fresh_U" if distance>360 else ("fresh_K" if not target.grounded else "fresh_J")
				result[button]=age==12
		return result
	if actor.state in ["hurt","juggle","launch","slam","down","getup","ko","throw_hold"]: return result
	# Preserve ordinary attacks, jump, dash and the source defensive responses.
	# Replace only decisions whose source skill has changed its purpose.
	var chosen: String=str(result.get("action",""))
	if chosen in ["skill1","skill2","skill3","super","super_down"]: result["action"]=""
	if actor.fighter_id=="chicken" and chosen=="super_up": result["action"]=""
	if not actor.grounded or cpu_cooldown>0: return result
	if not str(result.get("action","")).is_empty(): return result
	var opponent_attacking: bool=target.is_attacking()
	var move: String=""
	if not target.grounded and distance<255: move="super_up" if actor.fighter_id=="chicken" and has_ball and actor.hype>=100 else "skill2"
	elif opponent_attacking and distance<245 and actor.fighter_id in ["worker","rio"]:
		move="super" if actor.fighter_id=="worker" and actor.hype>=100 and authored_cpu_turn%3==0 else "skill3"
	elif actor.hype>=300 and distance<210 and not target.guarding and (actor.fighter_id!="chicken" or has_ball): move="super_down"
	elif actor.hype>=100 and distance<220 and actor.fighter_id!="worker" and not target.guarding and (actor.fighter_id!="chicken" or has_ball): move="super"
	elif actor.fighter_id=="worker" and not has_folder and distance>240 and distance<480: move="skill1"
	elif actor.fighter_id=="chicken" and has_ball and distance>235 and distance<600: move="skill1"
	elif actor.fighter_id=="rio" and distance<280: move="skill1"
	elif actor.fighter_id in ["shark","cat","chicken"] and distance<430: move="skill1" if actor.fighter_id!="chicken" else "skill3"
	elif distance<245: move="skill2" if authored_cpu_turn%2==0 else "skill3"
	if not move.is_empty() and actor.command_enabled(move):
		result["action"]=move; result["guard"]=false
		result["held_U"]=actor.fighter_id=="rio" and move=="skill1"
		result["fresh_U"]=move.begins_with("skill")
		cpu_cooldown=.55 if difficulty=="hard" else (.9 if difficulty=="normal" else 1.25)
		authored_cpu_turn+=1
	return result

func _incoming_projectile(index: int) -> bool:
	if not playable_world: return false
	for object in playable_world.objects:
		if object.kind!="bullet" or object.owner_index==index or object.removed or not object.hit_able: continue
		# The same near-bullet threshold used by the source AI defense branch.
		var gap: Vector2=(object.position-fighters[index].position)/1.6
		if absf(gap.x)<200 and absf(gap.y)<150: return true
	return false

func _resolve_pushboxes() -> void:
	var states: Array[Dictionary]=[]
	for actor in fighters:
		var fixed:=stage_map.fix_sprite_position(actor.position,actor.velocity.x)
		var body: Rect2=actor.body_box()
		states.append({"x":actor.position.x/1.6,"body":Rect2(body.position/1.6,body.size/1.6),"velocity":actor.velocity.x/48.0,"heavy":actor.source_heavy if actor.source_runtime_enabled else 2.0,"cross":actor.source_cross if actor.source_runtime_enabled else actor.state=="burst","touch_side":fixed["touch_side"]})
	var push:=BVNPush.resolve(states[0],states[1])
	for i in range(2):
		fighters[i].position=stage_map.fix_sprite_position(fighters[i].position+Vector2(push[i]*1.6,0),fighters[i].velocity.x)["position"]

## Source GameMainLogicCtrler: render collisions only on 30Hz animation ticks.
## Snapshot every contact first. Independent objects survive the owner's action.
func _resolve_playable_contacts() -> void:
	_resolve_source_and_authored_contacts(true)

func _resolve_source_and_authored_contacts(source_tick: bool) -> void:
	var transactions: Array[Dictionary]=[]
	var fighter_hits: Array=[[],[]]
	for i in range(2):
		var actor=fighters[i]
		var hits: Array=actor.source_frame_hits() if source_tick else []
		if actor.authored_skills_enabled: hits.append_array(actor.authored_hits())
		var explosion: Dictionary=actor.hurt_break_hit()
		if not explosion.is_empty():
			hits.append({"area":explosion["currentArea"],"source_hit_vo":explosion,"has_owner":false,"damage":50,"knockback":float(explosion["hitx"])*48,"stun":.3,"kind":"special","move":"hurt_break","feedback":"heavy","source_type":"energy_explode","serial":actor.action_serial,"owner_x":actor.position.x,"hit_owner_facing":1})
		var snapshot: Dictionary=BVNHit.first_contact(hits,fighters[1-i].body_box(),not fighters[1-i].is_protected())
		fighter_hits[i]=hits
		if not snapshot.is_empty():
			snapshot.hit["_presentation_source_frame"]=actor.source_frame
			snapshot.hit["_presentation_source_absolute_frame"]=actor.source_absolute_frame
			transactions.append({"owner":i,"snapshot":snapshot})
	for object in playable_world.objects:
		if not source_tick: continue
		var i: int=object.owner_index
		var snapshot: Dictionary=BVNHit.first_contact(object.hits(),fighters[1-i].body_box(),not fighters[1-i].is_protected())
		if not snapshot.is_empty():
			snapshot.hit["_presentation_source_frame"]=object.source_frame
			snapshot.hit["_presentation_source_absolute_frame"]=object.source_absolute_frame
			transactions.append({"owner":i,"snapshot":snapshot,"object":object})
	var projectile_transactions: Array[Dictionary]=[]
	for target_object in playable_world.objects:
		if not source_tick: continue
		if target_object.kind!="bullet" or not target_object.hit_able: continue
		var target_box: Rect2=target_object.transformed_rect(target_object.bullet_area)
		var contact: Dictionary=BVNHit.first_contact(fighter_hits[1-target_object.owner_index],target_box)
		if not contact.is_empty(): projectile_transactions.append({"target":target_object,"hit":contact["hit"]})
		for object in playable_world.objects:
			if object.owner_index==target_object.owner_index: continue
			contact=BVNHit.first_contact(object.hits(),target_box)
			if not contact.is_empty(): projectile_transactions.append({"target":target_object,"hit":contact["hit"],"other":object})
	for transaction in projectile_transactions:
		transaction["target"].be_hit(transaction["hit"],transaction.get("other",null))
		if transaction.has("other") and transaction["other"].kind=="bullet": transaction["other"].hit_bullet()
	for transaction in transactions:
		var i: int=int(transaction["owner"])
		var source: Dictionary=transaction["snapshot"]["hit"].duplicate(true)
		if transaction.has("object"): source["independent"]=true
		var defender=fighters[1-i]
		source["contact"]=transaction["snapshot"]["rect"].get_center()
		source["serial"]=int(source.get("serial",fighters[i].action_serial))
		source["move"]=str(source.get("move",fighters[i].action))
		source["hit_owner_facing"]=int(source.get("owner_facing",fighters[i].facing))
		var kind: String=str(source.get("kind","special"))
		if _authored_counter_contact(i,defender,source): continue
		var target_touch_side: bool=bool(stage_map.fix_sprite_position(defender.position,defender.velocity.x).touch_side)
		var result: Dictionary=_receive_battle_hit(defender,int(source.get("damage",0)),float(source.get("knockback",0)),float(source.get("stun",0)),int(source["hit_owner_facing"]),kind,defender.guarding and defender.grounded,source)
		if not result.get("hit",false): continue
		if source_tick and not source.get("authored_hit",false) and source.get("has_owner",true) and result.get("reaction","")!="hurt_action":
			_apply_source_wall_reverse_push(defender,transaction.get("object",fighters[i]),source,target_touch_side)
		if source.get("authored_hit",false): fighters[i].authored_notify_contact(source,result,defender)
		else: fighters[i].source_notify_contact(str(source.get("source_name",source.get("source_hit_vo",{}).get("id",""))),result,1-i)
		_register_impact(i,defender,result,source)
		if transaction.has("object"): transaction["object"].contact(result)

## Open3.4 beHit1477–1501 targets HitVO.owner, never the credited fighter
## behind an independent object. Bullet is not BaseGameSprite; stale objects fail.
func _apply_source_wall_reverse_push(defender: Variant,entity: Variant,source: Dictionary,touch_side: bool) -> void:
	if not is_instance_valid(entity): return
	var base_owner: bool=fighters.has(entity)
	if not base_owner:
		if not playable_world.objects.has(entity) or entity.removed or entity.kind!="attacker": return
		base_owner=true
	var push: Dictionary=BVNHit.wall_reverse_push(touch_side,base_owner,defender.position.x/1.6,entity.position.x/1.6,int(entity.facing),float(source.get("source_hit_vo",{}).get("hitx",0)))
	if not push.is_empty(): entity.set_bvn_reverse_push(float(push.velocity),float(push.damping))

func _authored_counter_contact(index: int,defender,source: Dictionary) -> bool:
	if not defender.authored_skills_enabled: return false
	var response: Dictionary=defender.authored_receive_contact(source,fighters[index])
	if not response.get("handled",false): return false
	var counter: Dictionary=response.get("hit",{})
	if counter.is_empty(): return true
	var attacker=fighters[index]
	counter["contact"]=attacker.body_box().get_center()
	counter["owner_x"]=defender.position.x
	counter["hit_owner_facing"]=defender.facing
	var result: Dictionary=_receive_battle_hit(attacker,int(counter.get("damage",80)),float(counter.get("knockback",180)),float(counter.get("stun",.4)),defender.facing,str(counter.get("kind","special")),false,counter)
	if result.get("hit",false):
		defender.authored_notify_contact(counter,result,attacker)
		_register_impact(1-index,attacker,result,counter)
	return true

## Official GameMainLogicCtrl takes both hit snapshots before applying either.
func _resolve_melee_pair(intents: Array[Dictionary]) -> void:
	var hits: Array=[[],[]]
	for i in range(2):
		var actor=fighters[i]
		var explosion: Dictionary=actor.hurt_break_hit()
		if not explosion.is_empty():
			hits[i].append({"area":explosion["currentArea"],"source_hit_vo":explosion,"has_owner":false,"damage":50,"knockback":float(explosion["hitx"])*48,"stun":.3,"kind":"special","move":"hurt_break","reaction":"hurt","feedback":"heavy","label":"ダメージ脱出","source_type":"energy_explode","serial":actor.action_serial,"owner_x":actor.position.x,"hit_owner_facing":1})
			continue
		var geometry: Dictionary=actor.active_hit_geometry()
		var area: Rect2=geometry["bounds"] if geometry.get("ready",false) else actor.active_box()
		if area.size!=Vector2.ZERO and (actor.action_data.get("kind","")!="throw" or not actor.hit_targets.has(1-i)):
			var source: Dictionary=actor.action_data.duplicate()
			source["area"]=area; source["serial"]=actor.action_serial; source["owner_x"]=actor.position.x
			if geometry.get("ready",false): source["hit_geometry"]=geometry
			hits[i].append(source)
	var pair:=BVNHit.pair_contacts(hits[0],fighters[0].body_box(),hits[1],fighters[1].body_box(),not fighters[0].is_protected(),not fighters[1].is_protected())
	# Reject transparent/empty parts of each broad box BEFORE either transaction.
	# Several touching silhouette pieces still create just one source HitVO contact.
	for index in range(2):
		var key: String="a_hits_b" if index==0 else "b_hits_a"
		var snapshot: Dictionary=pair[key]
		if snapshot.is_empty() or not snapshot["hit"].has("hit_geometry"): continue
		var narrow: Dictionary=fighters[index].HitGeometry.intersect_body(snapshot["hit"]["hit_geometry"],fighters[1-index].body_box())
		if not narrow.get("hit",false): pair[key]={}
		else:
			snapshot["rect"]=narrow["rect"]
			snapshot["hit"]["geometry_contact"]=narrow["contact"]
			snapshot["hit"]["geometry_part"]=narrow["part"]
	for index in range(2):
		var key: String="a_hits_b" if index==0 else "b_hits_a"
		# Empty now also means a rejected transparent corner. Never retry the
		# damaging broad box. Only an already-held throw has a later release event.
		if not pair[key].is_empty() or (fighters[index].is_attacking() and fighters[index].action_data.get("kind","")=="throw" and fighters[index].action_data.get("grabbed",false)):
			_resolve_melee(index,intents[1-index],pair[key])

func _resolve_melee(index: int, _defender_intent: Dictionary, snapshot: Dictionary={}) -> void:
	var attacker=fighters[index]
	var defender=fighters[1-index]
	if not attacker.is_attacking() and snapshot.is_empty(): return
	var source: Dictionary=snapshot["hit"].duplicate() if not snapshot.is_empty() else attacker.action_data.duplicate()
	var kind := str(source.get("kind","normal"))
	if kind=="throw":
		if attacker.action_data.get("grabbed",false):
			if defender.state!="throw_hold": attacker.hit_targets[1-index]=true; return
			if attacker.action_time>=0.25 and not attacker.hit_targets.has(1-index):
				defender.state="idle"
				defender.invulnerable=0.0
				source["contact"]=defender.position+Vector2(-attacker.facing*20,-80)
				var answer: Dictionary=_receive_battle_hit(defender,int(source["damage"]),float(source["knockback"]),float(source["stun"]),attacker.facing,"throw",false,source)
				attacker.hit_targets[1-index]=true
				_register_impact(index,defender,answer,source)
			return
		var grab_box: Rect2=attacker.active_box()
		if grab_box.size==Vector2.ZERO or attacker.hit_targets.has(1-index): return
		var gap: float= absf(attacker.position.x-defender.position.x)-(attacker.body_width+defender.body_width)*0.5
		if not defender.grounded or defender.is_protected() or defender.is_combo_locked() or gap>20 or not grab_box.intersects(defender.body_box()): return
		attacker.action_data["grabbed"]=true
		defender.state="throw_hold"; defender.state_time=0.0; defender.action=""
		defender.velocity=Vector2.ZERO; defender.clear_buffer()
		defender.action_data={"hurt_length":0.35,"grab_owner":index,"grab_time":attacker.action_time}
		return
	var box: Rect2=source["area"] if not snapshot.is_empty() else attacker.active_box()
	if box.size==Vector2.ZERO or not box.intersects(defender.body_box()) or defender.hp<=0 or defender.is_protected(): return
	var overlap: Rect2=snapshot["rect"] if not snapshot.is_empty() else box.intersection(defender.body_box())
	source["contact"]=source.get("geometry_contact",attacker.contact_point(overlap))
	if defender.can_counter(source) and defender.facing==-attacker.facing:
		attacker.hit_targets[1-index]=true; attacker.route_closed=true; attacker.contact_result="counter"
		defender.attack_hit=true; defender.attack_contact=true
		var counter: Dictionary={"kind":"special","move":"counter","damage":75,"knockback":260,"stun":0.40,"feedback":"counter","reaction":"hurt","label":"Huh？ 反撃！","contact":defender.contact_point(attacker.body_box())}
		var answer: Dictionary=_receive_battle_hit(attacker,75,260,0.40,defender.facing,"special",false,counter)
		if answer.get("hit",false): _register_impact(1-index,attacker,answer,counter)
		return
	var guarded: bool=defender.guarding and defender.grounded
	var result: Dictionary=_receive_battle_hit(defender,int(source.get("damage",65)),float(source.get("knockback",100)),float(source.get("stun",0.33)),int(source.get("hit_owner_facing",attacker.facing)),kind,guarded,source)
	if result.get("hit",false):
		attacker.hit_targets[1-index]=true
		_register_impact(index,defender,result,source)

func _register_impact(index: int, defender, result: Dictionary, source: Dictionary) -> void:
	if not result.get("hit",false): return
	var attacker=fighters[index]
	_record_match_contact(index,defender,result,source)
	ReactionIdentity.capture_contact(defender,attacker,source,result)
	var blocked: bool=result.get("blocked",false)
	var armored: bool=result.get("armor",false)
	var kind := str(source.get("kind","normal"))
	var contact: Vector2=source.get("contact",defender.body_box().get_center())
	var profile := str(source.get("feedback","light"))
	if source.get("counter_confirmed",false): profile="counter"
	# Visual HitType selection is separate from the existing freeze/route/RNG
	# profile. Independent Bullet/Attacker direction belongs to the real entity.
	var feedback := BattleFeedback.describe(source,result,int(defender.source_profile.get("config",{}).get("defenseType",0)))
	feedback["floor_y"]=defender.stage_floor_y
	feedback["body_height"]=defender.body_height
	feedback["target_grounded"]=defender.grounded or is_equal_approx(defender.position.y,defender.stage_floor_y)
	var contact_metadata: Dictionary={}
	var managed_sound:=false
	if source_bindings_enabled and skill_audio and not str(source.get("source_binding_id",attacker.source_binding_id)).is_empty():
		contact_metadata=_source_contact_presentation(attacker,defender,result,source,profile)
		var sound_packet:=contact_metadata.duplicate(true)
		sound_packet["pos"]=contact_metadata.get("pos",contact);sound_packet["feedback"]=feedback
		var sound_display: Dictionary=SourceSkillFX.sample_contact(sound_packet)
		if sound_display.get("ready",false): sound_packet.merge(sound_display,true)
		# Contact sound follows the true actor/object release before the impact.
		# A surviving projectile keeps its own binding after its owner recovers.
		skill_audio.update_actor(attacker)
		var source_object_id: int=int(source.get("source_object_instance_id",0))
		if source_object_id!=0 and playable_world:
			for object in playable_world.objects:
				if object.get_instance_id()==source_object_id: skill_audio.update_object(object);break
		managed_sound=skill_audio.on_contact(sound_packet,index,int(source.get("serial",attacker.action_serial)),source_object_id,int(defender.player_index))
	var visual_direction: int=int(source.get("hit_owner_facing",source.get("owner_facing",attacker.facing)))
	var source_effect: Dictionary=BVNEffectFreeze.from_contact(source,result,int(defender.source_profile.get("config",{}).get("defenseType",0)),source_freeze_enabled)
	var formal_freeze: bool=attacker.source_runtime_enabled and bool(source_effect.get("ready",false))
	if formal_freeze and int(source_effect.get("frames",0))>0:
		# Each source effect replaces _freezeFrame; absent/NONE effect leaves it.
		source_freeze_frames=int(source_effect["frames"])
		hitstop=float(source_freeze_frames)/BVNEffectFreeze.FPS_GAME
	var current_source: bool=not source.has("serial") or (int(source["serial"])==attacker.action_serial and str(source.get("move",""))==attacker.action)
	if current_source:
		attacker.attack_contact=true
		attacker.attack_hit=not blocked and not armored
		attacker.contact_result="guard" if blocked else ("armor" if armored else "hit")
		attacker.route_closed=bool(result.get("terminal",false)) or armored or profile=="counter"
	var qi_gain: float=0.0 if kind=="super" else (float(source.get("damage",0))*(.1 if source.get("source_type","")=="bullet" else .15) if source.get("source_type","") in ["bullet","attacker"] else BVNHit.qi_on_hit(float(source.get("damage",0)),false))
	attacker.hype=BVNHit.add_qi(attacker.hype,qi_gain)
	if blocked:
		_impact(contact,SummerTheme.SEA,false,"guard",1,visual_direction,feedback)
		_popup("ガード",contact+Vector2(0,-75),SummerTheme.CREAM,0.35)
		if not managed_sound: _sfx("guard")
		if not formal_freeze: hitstop=maxf(hitstop,0.035)
	else:
		var strong := profile in ["heavy","launch","slam","super","counter"]
		var combo: int=int(result.get("combo_count",defender.combo_hits))
		_impact(contact,SummerTheme.SUN,strong,"hit",combo,visual_direction,feedback)
		if bool(result.get("guard_break",false)):
			_popup("ガード崩し！",contact+Vector2(0,-75),SummerTheme.SUN,.55)
		if profile=="counter": _popup("反撃！" if source.get("authored_hit",false) else "Huh？ 反撃！",contact+Vector2(0,-75),SummerTheme.CREAM)
		var materials := {"rio":"blade","cat":"paw","shark":"shoe","worker":"case","chicken":"ball","notify":"v034_notify_bag_hit","wojak":"v034_wojak_push"}
		if not managed_sound:
			_sfx("counter" if profile=="counter" else ("launch" if result.get("launched",false) else str(materials.get(attacker.fighter_id,"hit"))))
			if profile in ["heavy","slam"]: _sfx("heavy")
		var pauses := {"light":0.055,"heavy":0.085,"launch":0.075,"slam":0.090,"super":0.110,"counter":0.070}
		if not formal_freeze: hitstop=maxf(hitstop,float(pauses.get(profile,0.055)))
		shake_time=0.14 if strong else 0.055; impact_strength=1.0 if strong else 0.30; flash_time=0.05 if strong else 0.0
		if strong: zoom_time=0.14
		if source.get("authored_hit",false):
			var major: bool=kind=="super"
			shake_time=.23 if major else .16
			impact_strength=2.1 if major else 1.35
			flash_time=.065 if major else .040
			zoom_time=.14
		if armored:
			_popup("耐えた！",contact+Vector2(0,-110),SummerTheme.SUN)
			if not managed_sound: _sfx("guard")
		var cinema_key: String="%d:%d" % [index,int(source.get("serial",attacker.action_serial))]
		if kind=="super" and not attacker.source_runtime_enabled and not cinema_seen.has(cinema_key):
			cinema_seen[cinema_key]=true
			cinema_time=CUTIN_SECONDS; cinema_owner=index
			var suffix := "・地裂" if source.get("move","")=="super_down" else ("・天空" if source.get("move","")=="super_up" else "")
			cinema_name=str(SUPER_NAMES.get(attacker.fighter_id,"超ミーム"))+suffix
	if source_bindings_enabled and not effects.is_empty():
		var binding_id: String=str(source.get("source_binding_id",attacker.source_binding_id))
		if not binding_id.is_empty():
			var metadata: Dictionary=contact_metadata if not contact_metadata.is_empty() else _source_contact_presentation(attacker,defender,result,source,profile)
			effects[-1]["bvn_contact"]=metadata
			var contact_effect: Dictionary=effects[-1].duplicate()
			contact_effect.merge(metadata,true)
			var display: Dictionary=SourceSkillFX.sample_contact(contact_effect)
			if display.get("ready",false):
				# Only display lifetime/camera feedback changes; original freeze stays authoritative.
				effects[-1]["life"]=display["duration"]; effects[-1]["max"]=display["duration"]
				if not blocked and not armored:
					var tier: int=int(display["tier"])
					var finish: bool=bool(display["finisher"])
					impact_strength=.42 if tier==1 else (.80 if tier==2 else 1.18)
					if finish:
						impact_strength+=.28
					zoom_time=.10 if finish else (.065 if tier>=2 else 0.0)
					flash_time=.035 if finish and tier==3 else (.016 if finish else 0.0)
		elif str(attacker.fighter_id)=="wojak" and not _wojak_normal_contact_label(source).is_empty():
			var metadata: Dictionary=_source_contact_presentation(attacker,defender,result,source,profile)
			metadata.merge({"ready":true,"id":"wojak","normal_source":true,"source_profile":"sasuke_susanoo","label":_wojak_normal_contact_label(source),"height":float(defender.body_height),"frame":int(metadata.get("source_frame",0))},true)
			effects[-1]["wojak_punctuation_contact_v034"]=metadata
	if source.get("authored_hit",false) and not effects.is_empty():
		effects[-1]["authored_contact"]={"id":attacker.fighter_id,"semantic_id":str(source.get("semantic_move_id","")),"outcome":"guard" if blocked else ("armor" if armored else ("counter" if profile=="counter" else "hit"))}
	if mode=="training" and index==0: _training_contact(str(source.get("move","")),result,source)
	if defender.fighter_id=="worker" and not blocked: _remove_owner_traps(1-index)

func _source_contact_presentation(attacker,defender,result: Dictionary,source: Dictionary,profile: String) -> Dictionary:
	var entity: Variant=attacker
	var object_id: int=int(source.get("source_object_instance_id",0))
	if object_id!=0 and playable_world:
		for candidate in playable_world.objects:
			if is_instance_valid(candidate) and candidate.get_instance_id()==object_id and candidate.owner==attacker:
				entity=candidate; break
	var birth: Dictionary=source.get("teaching_origin",{})
	if entity!=attacker: birth=entity.teaching_origin
	var attacker_anchors: Dictionary={};var target_anchors: Dictionary={}
	if full_pose_renderer and full_pose_renderer.has_method("world_anchors"):
		attacker_anchors=full_pose_renderer.world_anchors(attacker)
		target_anchors=full_pose_renderer.world_anchors(defender)
	var axis: Vector2=Vector2(float(source.get("hit_owner_facing",attacker.facing)),0)
	if entity!=attacker and entity.velocity.length_squared()>1.0:axis=entity.velocity.normalized()
	elif attacker_anchors.has("weapon_tip") and attacker_anchors.has("weapon_grip"):
		axis=(attacker_anchors.weapon_tip-attacker_anchors.weapon_grip).normalized()
	var presentation_contact: Vector2=source.get("contact",defender.body_box().get_center())
	var paired_contact:=false
	if full_pose_renderer and not result.get("blocked",false) and not result.get("armor",false):
		var target_context: Dictionary=full_pose_renderer._actor_context(defender,defender.source_visual_state())
		var target_pose: Dictionary=full_pose_renderer.get_pose_state(str(defender.fighter_id),target_context)
		var pair: Dictionary=full_pose_renderer.pair_display_registration(defender,target_pose,target_context)
		if pair.get("ready",false):
			presentation_contact=pair.target_chest_display_world
			paired_contact=true
	# Only the displayed contact follows the registered captured body. Keep the
	# source contact separately; HP, collision and hit-freeze use the original.
	return {"fighter_id":attacker.fighter_id,"binding_id":str(source.get("source_binding_id",attacker.source_binding_id)),"outcome":"guard" if result.get("blocked",false) else ("armor" if result.get("armor",false) else ("counter" if profile=="counter" else "hit")),"confirmed":true,"body_height":defender.body_height,"floor_y":defender.stage_floor_y,"target_grounded":defender.grounded or is_equal_approx(defender.position.y,defender.stage_floor_y),"source_name":str(source.get("source_name",source.get("source_hit_vo",{}).get("id",""))),"hit_id":str(source.get("source_name",source.get("source_hit_vo",{}).get("id",""))),"source_type":str(source.get("source_type","actor")),"source_frame":int(source.get("_presentation_source_frame",entity.source_frame)),"source_absolute_frame":int(source.get("_presentation_source_absolute_frame",entity.source_absolute_frame)),"source_spawn_absolute_frame":int(birth.get("source_frame",-1)),"terminal":bool(result.get("terminal",false)),"launched":bool(result.get("launched",false)),"knocked_down":bool(result.get("knocked_down",false)),"attacker_anchors":attacker_anchors,"target_anchors":target_anchors,"attack_axis":axis,"source_area":source.get("area",Rect2()),"object_velocity":entity.velocity if entity!=attacker else Vector2.ZERO,"pos":presentation_contact,"position":presentation_contact,"source_contact":source.get("contact",presentation_contact),"paired_display_contact":paired_contact}

func _try_throw_tech(index: int) -> bool:
	var defender=fighters[index]
	if defender.state!="throw_hold" or defender.state_time>0.14: return false
	var owner: int=int(defender.action_data.get("grab_owner",1-index))
	var attacker=fighters[owner]
	attacker.hit_targets[index]=true; attacker.route_closed=true
	for actor in [attacker,defender]:
		actor.state="escape"; actor.state_time=0.0; actor.action=""; actor.action_data.clear()
		actor.protection_min=0.16; actor.landing_safety=0.12; actor.invulnerable=0.16; actor.clear_buffer(); actor._end_combo()
	attacker.velocity.x=-attacker.facing*230; defender.velocity.x=attacker.facing*230
	_popup("投げ抜け！",(attacker.position+defender.position)*0.5+Vector2(0,-180),SummerTheme.SEA)
	_sfx("guard")
	return true

func _training_contact(move: String,result: Dictionary,source: Dictionary={}) -> void:
	if training_course:
		_apply_training_course(training_course.observe_contact(source,result,_training_actor_state()))
		return
	if is_sparring_training():
		training_message="ガードされた・収める間は反撃に注意" if result.get("blocked",false) else ("耐えられた・反撃に注意" if result.get("armor",false) else "命中！ %d ダメージ" % int(result.get("damage",0)))
		training_feedback.emit(training_message,false)
		return
	if training_recipe=="air_chain":
		return # This recipe advances accepted airborne inputs, never contact counts.
	# Independent source objects retain their own HitVO/serial after their owner
	# changes action. They are valid combat hits, but never a Fighter J lesson.
	if source.get("source_type","") in ["attacker","bullet","energy_explode"] or not source.get("teaching_origin",{}).is_empty(): return
	var contact_serial: int=int(source.get("serial",fighters[0].action_serial))
	training_last_body_contact_serial=contact_serial
	if contact_serial==training_last_counted_serial: return
	if result.get("armor",false) or result.get("blocked",false):
		training_message="ガード・耐える相手には確定接続できません"; training_feedback.emit(training_message,false); return
	var routes := {"normal_chain":["attack1","attack2","attack3"]}
	var route: Array=routes[training_recipe]
	if training_stage>=route.size():
		if contact_serial==training_completed_serial or move!=route[0]: return
		training_stage=0; training_moves.clear(); training_completed_serial=-1; training_last_counted_serial=-1
	var count: int=int(result.get("combo_count",0))
	if count==1 and training_recipe!="normal_chain": training_stage=0; training_moves.clear()
	if training_stage<route.size() and move==route[training_stage]:
		training_moves.append(move); training_stage+=1
		training_last_counted_serial=contact_serial
		if training_stage==route.size():
			training_completed_serial=contact_serial
			training_message="最初の三入力成功！ 命中保証のない操作練習です"
			training_feedback.emit(training_message,true)
		else:
			training_message="%d/%d 接続成功・次の入力へ" % [training_stage,route.size()]
	else:
		training_message="ルートが異なります・Rでやり直し"; training_stage=0; training_feedback.emit(training_message,false)

func _do_hurt_break(index: int) -> bool:
	var actor=fighters[index]
	if not actor.perform_hurt_break(): return false
	_impact(actor.position+Vector2(0,-120),SummerTheme.AQUA,true,"burst")
	_popup("ダメージ脱出！",actor.position+Vector2(0,-260),SummerTheme.CREAM,.5)
	_sfx("guard")
	return true

func _do_burst(index: int,variant: String="ghost") -> void:
	var actor=fighters[index]
	if not actor.perform_burst("ghost" if variant=="burst" else variant): return
	_impact(actor.position+Vector2(0,-90),Color("9bdaff"),false,"burst")
	_popup("幽歩",actor.position+Vector2(0,-245),Color("8ae2ff"),.35)
	_sfx("dash")

func _spawn_action_prop(index: int) -> void:
	var actor=fighters[index]
	if actor.source_runtime_enabled: return
	if not actor.is_attacking() or actor.spawned_prop or not actor.action_data.has("spawn"):
		return
	if actor.action_time<float(actor.action_data.get("spawn_at",0.2)):
		return
	actor.spawned_prop=true
	var kind := str(actor.action_data["spawn"])
	actor.action_data["serial"]=actor.action_serial
	for prop in projectiles:
		if int(prop["owner"])==index and str(prop["kind"])==kind:
			_popup("ひとつずつ！",actor.position+Vector2(0,-200),Color("d4dcff"),0.4)
			return
	var y: float=actor.position.y-104.0
	var speed := 460.0
	var radius := 24.0
	var fuse := 0.0
	if kind=="tear":
		y=actor.position.y-25
		speed=225.0
		radius=22.0
	elif kind=="book":
		y=actor.position.y-18
		speed=0.0
		radius=35.0
		fuse=0.8
	elif kind=="superball":
		speed=600.0
		radius=37.0
	elif kind=="blade_wave":
		y=actor.position.y-112
		speed=510.0
		radius=33.0
	projectiles.append({"kind":kind,"owner":index,"x":actor.position.x+actor.facing*(actor.body_width*0.5+39),"y":y,"vx":speed*actor.facing,"radius":radius,"life":3.4,"fuse":fuse,"source":actor.action_data.duplicate(),"facing":actor.facing,"age":0.0})

func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		if i>=projectiles.size():
			continue
		var prop: Dictionary=projectiles[i]
		prop["age"]=float(prop["age"])+delta
		prop["life"]=float(prop["life"])-delta
		prop["x"]=float(prop["x"])+float(prop["vx"])*delta
		if prop["life"]<=0 or prop["x"]<-70 or prop["x"]>1350:
			projectiles.erase(prop)
			continue
		if str(prop["kind"])=="book" and float(prop["age"])<float(prop["fuse"]):
			continue
		var target=fighters[1-int(prop["owner"])]
		var radius := float(prop["radius"])
		var box := Rect2(float(prop["x"])-radius,float(prop["y"])-radius,radius*2,radius*2)
		if str(prop["kind"])=="book":
			box=Rect2(float(prop["x"])-48,FLOOR_Y-115,96,115)
		if box.intersects(target.body_box()) and not target.is_protected() and target.hp>0:
			var source: Dictionary=prop["source"].duplicate()
			source["contact"]=box.intersection(target.body_box()).get_center()
			source["owner_x"]=fighters[int(prop["owner"])].position.x
			source["source_type"]="bullet"
			var guarded: bool=target.guarding and target.grounded
			var result: Dictionary=_receive_battle_hit(target,int(source["damage"]),float(source.get("knockback",160)),float(source.get("stun",0.35)),int(prop["facing"]),str(source.get("kind","special")),guarded,source)
			if result.get("hit",false):
				_register_impact(int(prop["owner"]),target,result,source)
			elif result.get("escaped",false):
				_popup("コンボ脱出",target.position+Vector2(0,-205),Color("8ae2ff"))
			projectiles.erase(prop)

func _remove_owner_traps(index: int) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		if int(projectiles[i]["owner"])==index and str(projectiles[i]["kind"])=="book":
			projectiles.remove_at(i)

func _remove_near_props(center: Vector2, reach: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		var pos:=Vector2(float(projectiles[i]["x"]),float(projectiles[i]["y"]))
		if pos.distance_to(center+Vector2(0,-90))<reach:
			projectiles.remove_at(i)

func _training_update(delta: float) -> void:
	var actor=fighters[0]
	var target=fighters[1]
	if training_course:
		_apply_training_course(training_course.observe_frame(_training_actor_state()))
		# The source-compatible prerequisite fixture belongs to initialization,
		# R and KO only. Active lessons use actual Qi/energy and do not heal.
		if actor.hp<=0 or target.hp<=0:
			_start_round()
			training_message="KO・課題をリセット（開始時は気300）"
		return
	if is_sparring_training():
		# No constant Qi/stamina refill, forced stationary guard or timed heal.
		# Only KO/manual reset restarts the normal round and source AI state.
		if actor.hp<=0 or target.hp<=0:
			_start_round()
			training_message="KO・実戦練習を再開"
			return
		if not training_watched_move.is_empty() and not actor.is_attacking() and not actor.attack_contact and not training_miss_reported:
			training_message="空振り・収める間は反撃に注意"; training_miss_reported=true
			training_feedback.emit(training_message,false)
		return
	var lesson_contact: bool=actor.attack_contact
	if actor.source_runtime_enabled and training_watched_move in ["attack1","attack2","attack3"]:
		# source_notify_contact also observes an independent owner's hits. Keep
		# that source behavior; use an actual body contact for the J lesson only.
		lesson_contact=training_last_body_contact_serial==actor.action_serial
	if training_recipe!="air_chain" and not training_watched_move.is_empty() and not actor.is_attacking() and not lesson_contact and not training_miss_reported:
		training_message="届かない・間合いを近づけよう"; training_miss_reported=true
		training_feedback.emit(training_message,false)
	if training_recipe=="air_chain" and training_stage>0 and training_stage<3 and actor.grounded and not actor.is_attacking():
		training_message="着地しました・%sからもう一度" % _key_label(5)
		training_stage=0; training_moves.clear()
		training_feedback.emit(training_message,false)
	var hurt: bool=actor.hp<1000 or target.hp<1000
	if hurt:
		training_reset_time+=delta
		if fighters[0].is_combo_locked() or fighters[1].is_combo_locked() or fighters[1].state in ["down","getup","escape"]: training_reset_time=0.0
		if training_reset_time>2.0 or fighters[0].hp<=0 or fighters[1].hp<=0:
			for index in range(2): fighters[index].reset_round(stage_map.p1pos.x if index==0 else stage_map.p2pos.x)
			projectiles.clear(); training_reset_time=0.0
	for fighter in fighters:
		fighter.hype=300.0; fighter.energy=100.0; fighter.energy_overload=false; fighter.burst_used=false

func _receive_battle_hit(target, damage: int, knockback: float, stun: float, facing: int, kind: String, guarded: bool, source: Dictionary) -> Dictionary:
	var before: float=target.hp
	var result: Dictionary=target.receive_hit(damage,knockback,stun,facing,kind,guarded,source)
	result["actual_hp_loss"]=maxf(0.0,before-target.hp)
	return result

func _record_match_contact(index: int, defender, result: Dictionary, source: Dictionary) -> void:
	if phase!="active" or match_players.size()!=2: return
	var loss: float=float(result.get("actual_hp_loss",0.0))
	match_players[index].damage_dealt+=loss
	match_players[1-index].damage_taken+=loss
	if not result.get("blocked",false) and loss>0:
		var count: int=int(result.get("combo_count",0))
		if count<=match_combo_count[index]: match_combo_damage[index]=0.0
		match_combo_count[index]=count
		match_combo_damage[index]+=loss
		match_players[index].max_combo=maxi(int(match_players[index].max_combo),count)
		match_players[index].max_combo_damage=maxf(float(match_players[index].max_combo_damage),match_combo_damage[index])
	elif result.get("blocked",false):
		match_combo_damage[index]=0.0; match_combo_count[index]=0
	if defender.hp>0 or loss<=0: return
	var attacker=fighters[index]
	var packet: Dictionary=_source_contact_presentation(attacker,defender,result,source,str(source.get("feedback","light")))
	var display: Dictionary=SourceSkillFX.sample_contact(packet)
	var command: String=str(packet.get("binding_id","")).get_slice(":",1)
	var title: String=SourceSkillFX.formal_skill_title(attacker.fighter_id,command)
	packet.merge({"owner":index,"fatal":true,"tier":SourceSkillFX.tier_for(str(packet.get("binding_id",""))),"finisher":bool(display.get("finisher",false)),"title":title},true)
	last_ko_contact=packet

func get_match_summary() -> Dictionary:
	var reason: String=finish_presentation.kind
	if reason.is_empty() and phase in ["round_end","finished"]:
		reason=("double_ko" if fighters[0].hp<=0 and fighters[1].hp<=0 else "draw") if round_winner<0 else ("ko" if fighters[1-round_winner].hp<=0 else "timeout")
	return {"winner_index":round_winner,"rounds":round_number,"wins":wins.duplicate(),"elapsed":match_elapsed,"players":match_players.duplicate(true),"finish_kind":reason}

func _finish_round() -> void:
	if phase!="active": return
	phase="round_end"
	round_winner=-1
	if fighters[0].hp>fighters[1].hp: round_winner=0
	elif fighters[1].hp>fighters[0].hp: round_winner=1
	var special_finish: bool=false
	if round_winner>=0:
		wins[round_winner]+=1
		special_finish=finish_presentation.begin(last_ko_contact,round_winner,fighters[1-round_winner].hp)
		if not special_finish: fighters[round_winner].set_animation_preview("dance")
	phase_time=3.35 if special_finish else 2.3
	if not special_finish:
		source_presentation.reset()
		source_floor_impacts.clear()
		if skill_audio: skill_audio.reset()
	projectiles.clear()
	_sfx("round")

func _impact(pos: Vector2,color: Color,strong: bool,style: String="hit",combo: int=1,direction: int=1,feedback: Dictionary={}) -> void:
	var duration := 0.28 if strong else 0.18
	if style=="guard": duration=0.23
	var shards: Array[Dictionary] = []
	var count := 8 if strong else 5
	for i in range(count):
		var angle := randf_range(-PI,PI)
		shards.append({"velocity":Vector2(cos(angle),sin(angle))*randf_range(160.0,360.0),"rotation":randf_range(-PI,PI),"size":randf_range(3.0,7.0)})
	effects.append({"pos":pos,"color":color,"life":duration,"max":duration,"strong":strong,"style":style,"combo":combo,"facing":direction,"shards":shards,"feedback":feedback,"visual_age":0.0})
	if effects.size()>15:
		effects.pop_front()

func _popup(label: String,pos: Vector2,color: Color,duration:=0.65) -> void:
	popups.append({"text":label,"pos":pos,"color":color,"life":duration,"max":duration})
	if popups.size()>10:
		popups.pop_front()

func _sfx(name: String) -> void:
	var audio=get_node_or_null("/root/GameAudio")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(name)

func _action_has_source_sound(actor, methods: Array[String]) -> bool:
	if not actor.source_runtime_enabled: return false
	var definition: Dictionary=actor.action_data.get("source_definition",{})
	for event: Dictionary in definition.get("events",[]):
		for call: Dictionary in event.get("calls",[]):
			if bool(call.get("supported",false)) and str(call.get("controller","")) in ["effect","$effect_ctrler"] and str(call.get("method","")) in methods:
				return true
	return false

func _fighter_action_started(move_id: String,index: int) -> void:
	if move_id=="jump":_source_audio_event(fighters[index],"jump",[])
	if fighters[index].authored_is_active() and move_id in ["super","super_down","super_up"]:
		var duration: float=.43 if move_id=="super_down" else .30
		authored_cutins.append({"owner":index,"time":duration,"duration":duration,"name":str(fighters[index].action_data.get("label","必殺！")),"major":move_id=="super_down"})
		if authored_cutins.size()>2: authored_cutins.pop_front()
	if mode=="training" and index==0 and training_course:
		_apply_training_course(training_course.observe_action(move_id,fighters[0].source_label,fighters[0].action_serial))
	if mode=="training" and index==0 and training_recipe!="air_chain" and move_id not in ["jump","dash","fastfall","burst"]:
		training_watched_move=move_id; training_miss_reported=false
	var managed_skill:=_source_skill_audio_manages(fighters[index])
	if (move_id.begins_with("super") or move_id=="air_super") and not managed_skill: _sfx("charge")
	elif move_id=="dash":
		if not _action_has_source_sound(fighters[index],["dash"]): _sfx("dash")
	elif move_id in ["attack1","attack2","attack3","attack4","attack5","air_light","sweep","launcher","throw","skill1","skill2","skill3","air_skill","air_slam"]:
		# Actual source frame cues own the whoosh. A missing authored cue
		# receives one acceptance fallback; contact sounds remain independent.
		if not managed_skill and not _action_has_source_sound(fighters[index],["playSoundHit1","playSoundHit2"]): _sfx("swing")
	if move_id in ["skill1","skill2","skill3","air_skill","air_slam","air_super","super","super_down","super_up"]:
		var actor=fighters[index]
		if source_bindings_enabled:
			var binding: Dictionary=SourceBindings.binding_for(actor.fighter_id,move_id)
			if not binding.is_empty(): actor.action_data["label"]=str(binding["name_ja"])
		elif actor.authored_is_active():
			pass # The runtime supplies the accepted technique's Japanese name.
		elif move_id in ["skill1","skill2","skill3"]:
			var slot: int=["skill1","skill2","skill3"].find(move_id)
			actor.action_data["label"]=GameData.ROSTER[actor.fighter_id]["moves"][slot]
		elif move_id in ["air_skill","air_slam"]:
			actor.action_data["label"]="空中技"+("・下降" if move_id=="air_slam" else ("・上昇" if actor.source_label.ends_with("-上") else ""))
		# A cast is a time-line event, separate from a contact event. Whiffs have a release too.
		skill_casts.append({"owner":index,"serial":actor.action_serial,"move":move_id,"released":false})
		if skill_casts.size()>4: skill_casts.pop_front()
	if mode=="training" and index==0 and training_recipe=="air_chain":
		# This signal is emitted only after the source runtime accepts a command.
		# Raw button presses and rejected/unavailable actions never advance a step.
		var accepted := "air_skill" if move_id=="air_slam" else move_id
		var route: Array[String]=["jump","air_light","air_skill"]
		if accepted=="jump":
			training_stage=0; training_moves.clear(); training_completed_serial=-1
		if training_stage<route.size() and accepted==route[training_stage]:
			training_moves.append(accepted); training_stage+=1
			if training_stage==route.size():
				training_completed_serial=fighters[0].action_serial
				training_message="空中入力成功！ 命中・コンボの保証ではありません"
				training_feedback.emit(training_message,true)
			else:
				var key := _key_label(4) if training_stage==1 else _key_label(7)
				training_message="%d/3 入力を受付・次は空中%s（技の許可中）" % [training_stage,key]

func _fighter_landed(speed: float,index: int) -> void:
	if speed<180 or fighters.size()<=index: return
	var actor=fighters[index]
	# Hurt-fly impact belongs to its delayed 30 Hz hitFloor event, rather
	# than the earlier geometric floor edge that also serves ordinary jumps.
	if source_bindings_enabled and not actor.hurt_fly.is_empty():return
	var material_landing: bool=source_bindings_enabled and skill_audio!=null and skill_audio.has_method("on_landing") and skill_audio.on_landing(actor,speed)
	if material_landing:landing_audio_this_tick[actor.get_instance_id()]=true
	else:_sfx("land")
	effects.append({"pos":Vector2(actor.position.x,actor.stage_floor_y),"color":Color("e5c7a5"),"life":0.30,"max":0.30,"strong":false,"style":"dust","combo":1,"facing":1,"shards":[]})

func _fighter_source_floor_impact(event: Dictionary,index: int) -> void:
	if not source_bindings_enabled or index<0 or index>=fighters.size():return
	var actor: Variant=fighters[index]
	source_floor_impact_serial+=1
	var packet:=event.duplicate(true)
	packet.merge({"owner_index":index,"fighter_id":str(actor.fighter_id),"actor_key":str(actor.get_instance_id()),"action_serial":int(actor.action_serial),"floor_event_serial":source_floor_impact_serial,"age":0.0,"presentation_time":source_presentation.elapsed},true)
	source_floor_impacts.append(packet)
	while source_floor_impacts.size()>8:source_floor_impacts.pop_front()
	var strength:=float(packet.get("strength",0))
	# This is the same character wrapper used by original hitFloor, hence
	# its two-times pulse multiplier; do not add a second contact camera cue.
	if strength>0:source_presentation.event(index,int(actor.action_serial),"shake",[0,strength,0])
	if skill_audio:skill_audio.on_floor_impact(packet)

func _release_skill_if_ready(index: int) -> void:
	var actor=fighters[index]
	for cast in skill_casts:
		if int(cast["owner"])!=index or int(cast["serial"])!=actor.action_serial or cast["released"]: continue
		if actor.authored_is_active():
			var visual: Dictionary=actor.authored_visual_state()
			var authored_release: bool=str(visual.get("stage","")) in ["active","confirmed","counter","stance","follow","combo"]
			if str(visual.get("semantic_move_id","")) in ["worker_folder_set","chicken_bounce_pass"] and not actor.authored_prop_state().is_empty(): authored_release=true
			if not authored_release: continue
		elif actor.source_runtime_enabled:
			var has_release: bool=not actor.source_frame_hits().is_empty()
			for object in playable_world.objects:
				if object.owner_index==index and object.action_serial==actor.action_serial: has_release=true
			if not has_release: continue
		elif actor.action_time<float(actor.action_data.get("startup",.2)): continue
		cast["released"]=true
		var move: String=cast["move"]
		var major=move.begins_with("super") or move=="air_super"
		skill_releases.append({"owner":index,"serial":actor.action_serial,"id":actor.fighter_id,"move":move,"pos":actor.position,"facing":actor.facing,"height":0.0,"age":0.0,"duration":.72 if major else .36})
		if skill_releases.size()>8: skill_releases.pop_front()
		if source_bindings_enabled:
			# Accepted source HitVO/object event owns the release; no invented cast freeze.
			if not _source_skill_audio_manages(actor): _sfx("super" if major else str({"rio":"blade","cat":"paw","worker":"case","chicken":"ball","shark":"shoe"}.get(actor.fighter_id,"swing")))
			continue
		if major:
			_sfx("super")
			flash_time=maxf(flash_time,.035)
			shake_time=maxf(shake_time,.10); impact_strength=maxf(impact_strength,.55)
		elif actor.authored_is_active():
			var release_sounds: Dictionary={"rio":"blade","cat":"paw","worker":"case","chicken":"ball","shark":"shoe"}
			_sfx(str(release_sounds.get(actor.fighter_id,"swing")))
		elif actor.fighter_id=="rio": _sfx("blade")

func _draw_skill_back() -> void:
	if fighters.size()!=2: return
	_draw_stage_feedback()
	if source_bindings_enabled:
		_draw_source_skill_cinema(false)
		if playable_world and playable_world.bisha_owner>=0:
			var actor=fighters[playable_world.bisha_owner]
			var tier: int=SourceSkillFX.tier_for(actor.source_binding_id)
			var source_time: float=maxf(0.0,float(actor.source_absolute_frame-cinema_source_start_frame)/30.0+actor.source_clock-cinema_source_start_clock)
			var alpha: float=(.44 if tier>=3 else .26)*clampf(source_time/.09,0,1)
			world_skill_back.draw_rect(_source_visible_world_bounds(),Color(.01,.04,.09,alpha))
		_draw_skill_releases(true)
		_draw_playable_objects(true)
		_draw_paired_source_targets(world_skill_back)
		return
	var super_charge:=false
	for cast in skill_casts:
		if not cast["released"] and (str(cast["move"]).begins_with("super") or cast["move"]=="air_super"): super_charge=true
	if super_charge:
		world_skill_back.draw_rect(Rect2(-64,-64,WIDTH+128,HEIGHT+128),Color(.01,.04,.09,.50))
	for cast in skill_casts:
		if cast["released"]: continue
		var actor=fighters[int(cast["owner"])]
		if actor.authored_is_active(): continue
		var fraction=clampf(actor.action_time/maxf(.01,float(actor.action_data.get("startup",.2))),0,1)
		var major=str(cast["move"]).begins_with("super") or cast["move"]=="air_super"
		var tint: Color=actor.accent.lerp(SummerTheme.CREAM,.25)
		var floor_pos: Vector2=actor.position+Vector2(0,-4)
		var extent=125.0 if major else 62.0
		var ring=PackedVector2Array()
		for vertex in range(25):
			var angle=float(vertex)*TAU/24
			ring.append(floor_pos+Vector2(cos(angle)*(extent+fraction*35),sin(angle)*13))
		world_skill_back.draw_polyline(ring,Color(tint,.45+fraction*.5),4,false)
		if major:
			for n in range(8):
				var x=(n-3.5)*34
				var y=-fposmod(scenery_time*190+n*35,actor.body_height+85)
				world_skill_back.draw_line(floor_pos+Vector2(x,y),floor_pos+Vector2(x-8,y+28),Color(tint,.48),4,false)
		world_skill_back.draw_circle(actor.position+Vector2(actor.facing*22,-actor.body_height*.57),8+fraction*(20 if major else 10),Color(tint,.30+fraction*.35))
	_draw_skill_releases(true)
	_draw_playable_objects(true)

func _source_visible_world_bounds() -> Rect2:
	# Size display-only overlays through the existing camera, including high jumps.
	var origin:=(-canvas.position)/canvas.scale
	return Rect2(origin,Vector2(WIDTH,HEIGHT)/canvas.scale).grow(2.0)

func _draw_source_skill_cinema(caption: bool) -> void:
	if not source_bindings_enabled or phase!="active" or paused:return
	if caption:
		for row: Dictionary in source_skill_caption_layouts():
			SkillCinema.draw_caption(self,font,row.state,row.at,row.width)
		return
	# The background canvas inherits the existing source camera. Sampling its
	# inverse only sizes the backdrop decoration; gameplay projection is intact.
	var bounds:=_source_visible_world_bounds()
	for side in range(fighters.size()):
		var actor=fighters[side]
		if not SourceSkillFX.actor_presentation_possible(actor,2):continue
		var context: Dictionary=_sample_actor_presentation(actor)
		var state:=SourceSkillFX.sample_actor(actor,context)
		if not state.get("ready",false):continue
		SkillCinema.draw_background(world_skill_back,state,bounds,reduced_motion)

## Measure the actual wrapped title and phase line before placing the next
## live skill. Both players may be casting after the shared Bisha entrance.
## A single surviving cue keeps its original anchor; source samples are read-only.
func source_skill_caption_layouts() -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	if not source_bindings_enabled or phase!="active" or paused or cinema_time>0.0:return rows
	var next_top: float=-INF
	for side: int in range(fighters.size()):
		var actor=fighters[side]
		if not SourceSkillFX.actor_presentation_possible(actor,2):continue
		var state:=SourceSkillFX.sample_actor(actor,_sample_actor_presentation(actor))
		var display:=SkillCinema.sample(state)
		if not display.get("ready",false) or clampf(float(display.get("accent_alpha",0))*4.5,0.0,.95)<.01:continue
		var anchor: Dictionary=FightHUD.caption_anchor(side)
		var at: Vector2=anchor.at
		var width: float=anchor.width
		var layout:=SkillCinema.caption_layout(font,display,at,width)
		var title_ascent: float=font.get_ascent(int(layout.size))+3.0
		at.y=maxf(at.y,next_top+title_ascent)
		var last_baseline: float=at.y+maxi(0,layout.lines.size()-1)*float(layout.line_height)
		var bottom: float=last_baseline+font.get_descent(int(layout.size))+3.0
		if not str(layout.subtitle).is_empty():
			bottom=maxf(bottom,at.y+layout.lines.size()*float(layout.line_height)-4.0+font.get_descent(int(layout.subtitle_size))+2.0)
		var rect:=Rect2(Vector2(at.x,at.y-title_ascent),Vector2(width,bottom-at.y+title_ascent))
		rows.append({"side":side,"state":state,"at":at,"width":width,"rect":rect})
		next_top=bottom+14.0
	return rows

func _sample_actor_presentation(actor: Variant) -> Dictionary:
	var context: Dictionary=actor.source_visual_state()
	if not full_pose_renderer or not full_pose_renderer.has_method("world_anchors"):return context
	var anchors: Dictionary=full_pose_renderer.world_anchors(actor,context)
	var identity: String=str(actor.action_serial)+":"+str(actor.source_label)+":"+str(actor.facing)
	var sample: float=float(actor.source_absolute_frame)+float(actor.source_clock)*30.0
	var key: int=actor.get_instance_id()
	var previous: Dictionary={}
	var history: Dictionary=presentation_anchor_history.get(key,{})
	if not history.is_empty() and str(history["identity"])==identity:
		if is_equal_approx(sample,float(history["sample"])):
			# Both back/front draws and frozen source frames reuse the same pair.
			previous=history["previous"]
		elif sample>float(history["sample"]) and sample-float(history["sample"])<=2.01:
			previous=history["anchors"]
	context["anchors"]=anchors
	context["previous_anchors"]=previous
	context["anchor_sample"]={"identity":identity,"source_sample":sample,"actual_world_points":true}
	if history.is_empty() or history["identity"]!=identity or not is_equal_approx(sample,float(history["sample"])):
		presentation_anchor_history[key]={"identity":identity,"sample":sample,"anchors":anchors.duplicate(true),"previous":previous.duplicate(true)}
	return context

func _wojak_normal_contact_label(source: Dictionary) -> String:
	if str(source.get("source_profile_id",""))!="sasuke_susanoo":return ""
	var label: String=str(source.get("source_label",""))
	if int(source.get("source_object_instance_id",0))==0:
		return label if label in ["砍1","砍2","砍3","砍4","砍5","跳砍","摔1","摔2"] else ""
	if playable_world:
		for object: Variant in playable_world.objects:
			if object.get_instance_id()==int(source.get("source_object_instance_id",0)) and _is_wojak_normal_child(object):return "砍5"
	return ""

func _is_wojak_normal_child(object: Variant) -> bool:
	return str(object.fighter_id)=="wojak" and str(object.source_profile_id)=="sasuke_susanoo" and str(object.source_binding_id).is_empty() and str(object.name)=="k5mc" and str(object.child.get("source_symbol",""))=="元件/mc_076" and str(object.source_origin_label)=="砍5" and int(object.teaching_origin.get("source_frame",-1))==295

func _wojak_normal_object_packet(object: Variant) -> Dictionary:
	if not _is_wojak_normal_child(object) or object.removed:return {}
	var actual_hits: Array[Dictionary]=object.hits()
	if actual_hits.is_empty():return {}
	var context: Dictionary=object.source_visual_state()
	var box: Rect2=Rect2()
	for hit: Dictionary in actual_hits:
		var area: Rect2=hit.get("area",Rect2())
		if area.has_area():box=area if not box.has_area() else box.merge(area)
	if not box.has_area():return {}
	context.merge({"ready":true,"id":"wojak","normal_source":true,"normal_object":true,"normal_active":true,"source_profile":"sasuke_susanoo","label":"砍5","box":box,"height":float(object.owner.body_height),"frame":int(object.source_frame),"source_clock":float(object.clock),"source_playing":bool(object.playing),"birth_source_absolute_frame":295,"source_objects_drawn":1,"normal_hit_ids":actual_hits.map(func(hit: Dictionary) -> String:return str(hit.get("source_name","")))},true)
	return context

func _wojak_normal_punctuation_packet(actor: Variant,context: Dictionary) -> Dictionary:
	if not actor.source_runtime_enabled or actor.source_active_profile_id()!="sasuke_susanoo" or not bool(context.get("source_playing",false)):return {}
	var label: String=str(context.get("current_label",""))
	if label not in ["砍1","砍2","砍3","砍4","砍5","跳砍","摔1","摔2"]:return {}
	var actual_hits: Array[Dictionary]=actor.source_frame_hits()
	if actual_hits.is_empty():return {}
	var anchors: Dictionary=context.get("anchors",{})
	if not anchors.has("hand"):return {}
	var packet: Dictionary=context.duplicate()
	packet.merge({"ready":true,"id":"wojak","normal_source":true,"source_profile":"sasuke_susanoo","label":label,"hand":anchors.hand,"head":anchors.get("head",anchors.hand),"chest":anchors.get("chest",anchors.hand),"height":float(actor.body_height),"position":actor.position,"facing":int(actor.facing),"frame":int(actor.source_frame),"source_clock":float(actor.source_clock),"source_playing":true,"normal_active":true,"normal_hit_ids":actual_hits.map(func(hit: Dictionary) -> String:return str(hit.get("source_name","")))},true)
	return packet

func _draw_skill_releases(back_layer: bool=false) -> void:
	if source_bindings_enabled:
		var target: CanvasItem=world_skill_back if back_layer else world_effects
		for actor in fighters:
			var skill_possible: bool=SourceSkillFX.actor_presentation_possible(actor)
			var normal_possible: bool=str(actor.fighter_id)=="wojak" and str(actor.source_binding_id).is_empty() and actor.source_runtime_enabled and actor.source_active_profile_id()=="sasuke_susanoo" and actor.source_playing and str(actor.source_label) in ["砍1","砍2","砍3","砍4","砍5","跳砍","摔1","摔2"] and not actor.source_frame_hits().is_empty()
			if not skill_possible and not normal_possible:continue
			var context: Dictionary=_sample_actor_presentation(actor)
			if skill_possible:SourceSkillFX.draw_actor(target,actor,context,"back" if back_layer else "front")
			if normal_possible:
				var packet: Dictionary=_wojak_normal_punctuation_packet(actor,context)
				if not packet.is_empty():WojakPunctuationFX.draw_normal_actor(target,packet,"back" if back_layer else "front")
		return
	if authored_skills_enabled:
		var authored_canvas: Node2D=world_skill_back if back_layer else world_effects
		for actor in fighters:
			AuthoredSkillFX.draw(authored_canvas,actor,actor.authored_visual_state(),actor.authored_prop_state(),"back" if back_layer else "front")
	# Weapon-following skill trails sit behind both actors; actual projectiles and
	# contact sparks keep their separate foreground passes.
	if not back_layer: return
	if not skill_art.has_method("draw_skill_effect"): return
	var target: Node2D=world_skill_back
	if playable_world:
		for actor in fighters:
			if not actor.source_runtime_enabled or actor.authored_is_active(): continue
			for hit: Dictionary in actor.source_frame_hits():
				if hit.get("kind","")=="normal": continue
				_draw_source_effect(target,_actor_effect_context(actor,hit))
		return
	for release in skill_releases:
		var actor=fighters[int(release["owner"])]
		var anchor: Vector2=release["pos"]
		if actor.action_serial==int(release["serial"]) and actor.is_attacking(): anchor=actor.position
		var move: String=release["move"]
		if move=="air_super": move="super"
		if move=="air_skill": move="skill1"
		elif move=="air_slam": move="skill3"
		var progress=clampf(float(release["age"])/float(release["duration"]),0,1)
		target.draw_set_transform(anchor)
		skill_art.call("draw_skill_effect",target,str(release["id"]),move,progress,int(release["facing"]),Color.WHITE,float(release["height"]))
		target.draw_set_transform(Vector2.ZERO)

func _cast_label_layout(cast: Dictionary,occupied: Array[Rect2]=[]) -> Dictionary:
	var display_layout: Script=preload("res://game/bvn_cast_caption_layout_v030.gd")
	var index:=int(cast.get("owner",-1))
	if index<0 or index>=fighters.size():return {"ready":false,"visible":false,"reason":"missing_caster"}
	var actor=fighters[index]
	var major: bool=str(cast.get("move","")).begins_with("super") or str(cast.get("move",""))=="air_super"
	var label:=str(actor.action_data.get("label","ミーム！"))
	var actor_active: bool=actor.is_attacking() and actor.action_serial==int(cast.get("serial",actor.action_serial))
	if major and source_bindings_enabled and actor_active and phase=="active" and not paused and cinema_time<=0.0:
		# Read this actor's current accepted source branch, never a remaining
		# projectile's old binding. The phase caption uses exactly this sample.
		var source_state:=SourceSkillFX.sample_actor(actor,actor.source_visual_state())
		var caption_state:=SkillCinema.sample(source_state)
		var caption_visible:=bool(caption_state.get("ready",false)) and clampf(float(caption_state.get("accent_alpha",0))*4.5,0,.95)>=.01
		if caption_visible:
			return display_layout.layout({"label":label,"major":true,"source_owned":true,"source_actor_active":true,"source_caption_visible":true,"child_only":false})
	var visual_height: float=float(actor.body_height)
	if not actor.source_runtime_enabled or actor.authored_skills_enabled:
		var pose: Dictionary=actor.pixel_animation_state()
		visual_height=float(pose.get("native_height",actor.body_height/4))*4
	var point: Vector2=world_to_screen(actor.position+Vector2(0,-visual_height-25))
	if major and not actor.authored_is_active() and not source_bindings_enabled: label=str(SUPER_NAMES.get(actor.fighter_id,"超ミーム"))+("・地裂" if cast["move"]=="super_down" else ("・天空" if cast["move"]=="super_up" else ""))
	var size:=25 if major else 18
	var width:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x+6.0
	var rect:=Rect2(Vector2(point.x-width*.5,point.y-font.get_ascent(size)),Vector2(width,font.get_height(size)))
	var obstacles: Array[Rect2]=occupied.duplicate()
	# This is the measured transparent guide currently drawn by FightHUD; it
	# reserves only text placement, not any part of the combat stage.
	var controls: Rect2=FightHUD.control_visible_rect
	if controls.has_area():obstacles.append(controls)
	obstacles.append(Rect2(ARENA_RECT.position,Vector2(ARENA_RECT.size.x,232)))
	for other in fighters:
		var shown: bool=other.visible
		var display_offset:=Vector2.ZERO
		if full_pose_renderer and full_pose_renderer.has_method("pair_display_registration"):
			var body_context: Dictionary=full_pose_renderer._actor_context(other,{})
			var body_pose: Dictionary=full_pose_renderer.get_pose_state(str(other.fighter_id),body_context)
			var registration: Dictionary=full_pose_renderer.pair_display_registration(other,body_pose,body_context)
			if registration.get("ready",false):
				display_offset=registration.get("offset",Vector2.ZERO)
				# A hidden cat-I victim is drawn once by the paired back pass.
				# Use that same registered offset rather than its source root alone.
				if not shown:
					for holder in fighters:
						var holder_context: Dictionary=holder.source_visual_state()
						if str(holder_context.get("binding_id",""))=="cat:super" and int(holder_context.get("paired_target_index",-1))==int(other.player_index) and not bool(holder_context.get("paired_target_visible",true)):
							shown=true;break
		if not shown:continue
		var body: Rect2=FightHUD.control_actor_screen_rect(self,other)
		body.position+=display_offset*canvas.scale*ARENA_SCALE
		obstacles.append(body.grow(8))
	return display_layout.layout({"label":label,"major":major,"desired_rect":rect,"arena":ARENA_RECT,"size":size,"ascent":font.get_ascent(size),"minimum_y":238.0,"maximum_y":ARENA_RECT.end.y-35,"obstacles":obstacles,"source_actor_active":actor_active,"source_owned":false,"source_caption_visible":false,"child_only":not actor_active})

func _draw_cast_labels() -> void:
	if phase!="active": return
	var occupied: Array[Rect2]=[]
	for cast in skill_casts:
		var layout:=_cast_label_layout(cast,occupied)
		if not layout.get("ready",false) or not layout.get("visible",false):continue
		var rect: Rect2=layout.rect
		_text(layout.label,Vector2(rect.position.x,layout.baseline),layout.size,SummerTheme.SUN if layout.major else SummerTheme.CREAM,rect.size.x,HORIZONTAL_ALIGNMENT_CENTER)
		occupied.append(rect)

func _update_stage_feedback(delta: float) -> void:
	for i in range(source_floor_impacts.size()-1,-1,-1):
		source_floor_impacts[i]["age"]=float(source_floor_impacts[i]["age"])+delta
		if float(source_floor_impacts[i]["age"])>=PoolFeedback.floor_duration(source_floor_impacts[i]):source_floor_impacts.remove_at(i)
	for i in range(stage_landings.size()-1,-1,-1):
		stage_landings[i]["age"]=float(stage_landings[i]["age"])+delta
		if float(stage_landings[i]["age"])>=.36:stage_landings.remove_at(i)
	for actor in fighters:
		var key: int=actor.get_instance_id()
		var history: Dictionary=stage_actor_history.get(key,{})
		if not history.is_empty() and actor.grounded and actor.hurt_fly.is_empty() and not bool(history["grounded"]):
			# BVN's gravity integrator can move the body while public vy is zero.
			# Read actual floor travel; do not synthesize or write a source impulse.
			var travel_speed: float=(actor.position.y-float(history["position_y"]))/maxf(delta,.00001)
			var speed: float=maxf(float(history["velocity_y"]),travel_speed)
			if speed>35.0:stage_landings.append({"position":Vector2(actor.position.x,actor.stage_floor_y),"speed":speed,"age":0.0})
		stage_actor_history[key]={"grounded":actor.grounded,"velocity_y":actor.velocity.y,"position_y":actor.position.y}
	while stage_landings.size()>8:stage_landings.pop_front()

func _draw_stage_feedback() -> void:
	for impact: Dictionary in source_floor_impacts:PoolFeedback.draw_floor_impact(world_skill_back,impact)
	for landing: Dictionary in stage_landings:PoolFeedback.draw_landing(world_skill_back,landing)
	for actor in fighters:
		var anchors: Dictionary=full_pose_renderer.world_anchors(actor) if full_pose_renderer and full_pose_renderer.has_method("world_anchors") else {}
		PoolFeedback.draw_feet(world_skill_back,actor,anchors)
	for effect: Dictionary in effects:
		if effect.has("wojak_punctuation_contact_v034"):
			var punctuation: Dictionary=effect.duplicate();punctuation.merge(effect["wojak_punctuation_contact_v034"],true)
			WojakPunctuationFX.draw_normal_contact(world_skill_back,punctuation,"back")
			continue
		if not effect.has("bvn_contact"):continue
		var contact: Dictionary=effect.duplicate();contact.merge(effect["bvn_contact"],true)
		SourceSkillFX.draw_contact(world_skill_back,contact,"back")
		PoolFeedback.draw_contact(world_skill_back,contact,SourceSkillFX.sample_contact(contact))

func _update_visuals(delta: float) -> void:
	scenery_time+=delta
	_update_stage_feedback(delta)
	for cutin in authored_cutins: cutin["time"]=maxf(0,float(cutin["time"])-delta)
	for i in range(authored_cutins.size()-1,-1,-1):
		if float(authored_cutins[i]["time"])<=0: authored_cutins.remove_at(i)
	if reduced_motion:
		for fighter in fighters:
			# Fighter may append its newest position later in this physics tick.
			# At most two ghosts remain; the stored positions have no combat role.
			if fighter.trail.size()>1: fighter.trail.resize(1)
	# Hitstop pauses bodies, rather than stretching a 50ms contact light to 130ms.
	# During normal play Fighter.advance owns these same timers once per tick.
	if hitstop>0.0 or cinema_time>0.0:
		for fighter in fighters:
			fighter.hurt_flash=maxf(0.0,fighter.hurt_flash-delta)
			fighter.guard_flash=maxf(0.0,fighter.guard_flash-delta)
			fighter.queue_redraw()
	for i in range(fighters.size()):
		if source_bindings_enabled:
			# Give the actual performing face/hand priority over a nearby hurt
			# body, below real contact FX. Paired hidden victims keep their path.
			fighters[i].z_index=2 if fighters[i].source_doing_action and fighters[i].state in ["attack","dash"] else 0
		elif authored_skills_enabled:
			# The performing body stays readable in close grapples; contact FX
			# retain their separate higher layer. No extra actor is drawn.
			fighters[i].z_index=2 if fighters[i].authored_is_active() else 0
		var current_hp: int=fighters[i].hp
		if current_hp<previous_hp[i]:
			hp_trail_delay[i]=0.32
		elif current_hp>previous_hp[i]:
			hp_trail[i]=float(current_hp)
		previous_hp[i]=current_hp
		hp_trail_delay[i]=maxf(0.0,hp_trail_delay[i]-delta)
		if hp_trail_delay[i]<=0:
			hp_trail[i]=move_toward(float(hp_trail[i]),float(current_hp),delta*640)
	source_presentation.reconcile(fighters)
	source_presentation.advance(delta,paused)
	shake_time=maxf(0.0,shake_time-delta)
	flash_time=maxf(0.0,flash_time-delta)
	zoom_time=maxf(0.0,zoom_time-delta)
	var motion_strength:=0.22 if reduced_motion else 1.0
	var source_camera:=stage_map.step_camera([fighters[0].position,fighters[1].position])
	var source_transform: Transform2D=source_camera["transform"]
	var source_zoom: float=source_camera["render_zoom"]
	var impact_zoom:=1.0+sin(clampf(zoom_time/0.14,0.0,1.0)*PI)*0.035*motion_strength*(clampf(impact_strength,1.0,1.7) if authored_skills_enabled else 1.0) if shake_enabled else 1.0
	camera_zoom=source_zoom*impact_zoom
	camera_offset=source_transform.origin*impact_zoom+Vector2(WIDTH*.5,HEIGHT*.6)*(1.0-impact_zoom)
	if source_bindings_enabled and full_pose_renderer:
		if FeedbackSmoothness.needs_air_fit(fighters):
			var visible_points: Array[Dictionary]=[]
			for actor in fighters:
				var anchors: Dictionary=full_pose_renderer.world_anchors(actor)
				var high_reaction: bool=not actor.grounded and actor.state in ["hurt","juggle","launch","slam"] and not actor.last_source_hurt_hit.is_empty()
				visible_points.append({"visible":actor.visible,"head":anchors.get("head",actor.position-Vector2(0,actor.body_height)),"feet":anchors.get("feet",actor.position),"height":actor.body_height,"air_reaction":high_reaction})
			var display_frame: Dictionary=StageReadability.fit_air_reaction(camera_zoom,camera_offset,visible_points,Vector2(WIDTH,HEIGHT))
			camera_zoom=display_frame.zoom;camera_offset=display_frame.offset
		else:
			# A no-op safe frame still used to observe transition/registration
			# memory. Keep those effects without deforming every anchor.
			for actor in fighters:
				if full_pose_renderer.has_method("observe_actor_presentation"):
					full_pose_renderer.observe_actor_presentation(actor)
				else:
					full_pose_renderer.world_anchors(actor)
	_refresh_source_shake_projection()
	if canvas:
		canvas.scale=Vector2.ONE*camera_zoom
	if backdrop:
		# The HD scenic plate keeps its readable horizon as the source camera
		# zooms the actors. Its ground line still follows the projected live floor.
		backdrop.position=Vector2(clampf(-40.0+camera_offset.x*.02+camera_shake.x*.45,-80.0,0.0),0)
		backdrop.scale=Vector2.ONE
		backdrop.queue_redraw()
	var world_delta:=0.0 if hitstop>0 or cinema_time>0 else delta
	for i in range(effects.size()-1,-1,-1):
		# BVN renders contact effects while fighter freeze is active. Only this
		# decorative age advances; source release clocks/life and gameplay do not.
		if effects[i].get("feedback",{}).get("ready",false):
			effects[i]["visual_age"]=float(effects[i].get("visual_age",0.0))+delta
		effects[i]["life"]=float(effects[i]["life"])-world_delta
		if effects[i]["life"]<=0:
			effects.remove_at(i)
	for i in range(skill_releases.size()-1,-1,-1):
		skill_releases[i]["age"]=float(skill_releases[i]["age"])+world_delta
		if skill_releases[i]["age"]>=skill_releases[i]["duration"]: skill_releases.remove_at(i)
	for i in range(skill_casts.size()-1,-1,-1):
		var cast: Dictionary=skill_casts[i]
		var actor=fighters[int(cast["owner"])]
		if not actor.is_attacking() or actor.action_serial!=int(cast["serial"]): skill_casts.remove_at(i)
	for i in range(popups.size()-1,-1,-1):
		popups[i]["life"]=float(popups[i]["life"])-delta
		if popups[i]["life"]<=0:
			popups.remove_at(i)
	if world_effects: world_effects.queue_redraw()
	if world_skill_back: world_skill_back.queue_redraw()

func _draw_backdrop() -> void:
	if not backdrop:
		return
	if not pixel_stage_script and ResourceLoader.exists("res://game/pixel_stage.gd"): pixel_stage_script=load("res://game/pixel_stage.gd")
	if pixel_stage_script:
		var scenic_floor: float=stage_map.player_bottom*camera_zoom+camera_offset.y+camera_shake.y*.45
		pixel_stage_script.draw_stage(backdrop,scenery_time,reduced_motion,HEIGHT,WIDTH+80.0,scenic_floor)
		return
	if stage_texture:
		backdrop.draw_texture_rect(stage_texture,Rect2(0,0,WIDTH,HEIGHT),false)
		backdrop.draw_rect(Rect2(0,0,WIDTH,HEIGHT),Color(0.04,0.035,0.1,0.10))
	else:
		backdrop.draw_rect(Rect2(0,0,WIDTH,HEIGHT),Color("172134"))
		backdrop.draw_rect(Rect2(0,145,WIDTH,382),Color("24304a"))
		backdrop.draw_rect(Rect2(145,222,830,286),Color("ece4c9"))
		backdrop.draw_rect(Rect2(132,176,860,54),Color("c5274d"))
		backdrop.draw_string(font,Vector2(280,216),"夜ふかしマート",HORIZONTAL_ALIGNMENT_LEFT,-1,35,Color("fff4c2"))
		for i in range(4):
			backdrop.draw_rect(Rect2(175+i*183,266,161,178),Color("63718b"))
			backdrop.draw_rect(Rect2(184+i*183,277,144,70),Color("f4dea4"))
		backdrop.draw_rect(Rect2(1070,275,100,245),Color("bb2446"))
		backdrop.draw_rect(Rect2(1080,292,80,135),Color("e1e4da"))
		backdrop.draw_rect(Rect2(0,525,WIDTH,195),Color("323246"))
		backdrop.draw_line(Vector2(0,FLOOR_Y),Vector2(WIDTH,FLOOR_Y),Color("92898b"),3)
		for i in range(10):
			backdrop.draw_line(Vector2(i*150,HEIGHT),Vector2(500+i*35,525),Color("444458"),2)
	# Sparse petals stay behind the actors and below the HUD.
	for index in range(11):
		var phase := float(index)*2.17
		var petal_y := 148.0+fposmod(float(index)*47.0+scenery_time*(12.0+index%3*3.0),365.0)
		var petal_x := fposmod(float(index)*121.0+scenery_time*9.0+sin(scenery_time*0.8+phase)*21.0,WIDTH)
		var petal_size := 2.2+float(index%3)*0.6
		var shape := PackedVector2Array([Vector2(-petal_size,0),Vector2(0,-petal_size*0.48),Vector2(petal_size,0),Vector2(0,petal_size*0.65)])
		backdrop.draw_set_transform(Vector2(petal_x,petal_y),sin(scenery_time+phase)*0.8)
		backdrop.draw_colored_polygon(shape,Color(0.98,0.70,0.83,0.34))
	backdrop.draw_set_transform(Vector2.ZERO)
	backdrop.draw_rect(Rect2(0,0,WIDTH,137),SummerTheme.CREAM)
	backdrop.draw_rect(Rect2(0,640,WIDTH,80),SummerTheme.CREAM)

func _draw() -> void:
	if not font or fighters.size()!=2:
		return
	_draw_hud()
	_draw_popups()
	_draw_cast_labels()
	_draw_authored_prompts()
	_draw_authored_cutins()
	if debug_boxes:
		for fighter in fighters:
			draw_rect(world_rect_to_screen(fighter.body_box()),Color(0.3,1,0.5,0.25),true)
			if fighter.source_runtime_enabled:
				for hit: Dictionary in fighter.source_frame_hits():
					draw_rect(world_rect_to_screen(hit["area"]),Color(1,.15,.15,.38),true)
				continue
			var geometry: Dictionary=fighter.active_hit_geometry()
			if geometry.get("ready",false):
				for shape: Dictionary in geometry["shapes"]:
					var points:=PackedVector2Array()
					for point: Vector2 in shape["polygon"]: points.append(world_to_screen(point))
					draw_colored_polygon(points,Color(.15,.85,1,.32))
					points.append(points[0]); draw_polyline(points,Color(.15,.85,1,.85),1.5)
			else:
				var box:Rect2=fighter.active_box()
				if box.size!=Vector2.ZERO: draw_rect(world_rect_to_screen(box),Color(1,0.15,0.15,0.45),true)
		if playable_world:
			for object in playable_world.objects:
				for hit: Dictionary in object.hits(): draw_rect(world_rect_to_screen(hit["area"]),Color(.1,.8,1,.38),true)
	if phase=="intro":
		var text: String="ROUND %d" % round_number if phase_time>0.75 else "はじめ！"
		if mode=="training": text="トレーニング" if phase_time>0.75 else "練習開始！"
		_banner(text,Color("ffe063"))
	elif phase=="round_end":
		if not finish_presentation.kind.is_empty(): finish_presentation.draw_overlay(self)
		else:
			var title := "引き分け！" if round_winner<0 else ("K.O.！" if fighters[0].hp<=0 or fighters[1].hp<=0 else "時間切れ！")
			_banner(title,Color("ffdd66"))
			if round_winner>=0:
				_text(fighters[round_winner].display_name+" の勝ち！",Vector2(ARENA_RECT.position.x,431),29,Color.WHITE,ARENA_RECT.size.x,HORIZONTAL_ALIGNMENT_CENTER)
	if cinema_time>0.0:
		_draw_cinema()
	_draw_source_skill_cinema(true)
	if flash_time>0.0 and flash_enabled:
		draw_rect(ARENA_RECT,Color(1,1,0.96,flash_time*4.0*(0.22 if reduced_motion else 1.0)))
	if paused:
		_draw_pause()

func _text(value: String,pos: Vector2,size: int,color: Color,width: float=-1,alignment: int=HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if color.get_luminance()>0.45:
		draw_string_outline(font,pos,value,alignment,width,size,3,Color(0.05,0.04,0.09,0.95))
	draw_string(font,pos,value,alignment,width,size,color)

func _draw_authored_prompts() -> void:
	if not authored_skills_enabled or phase!="active": return
	var actor=fighters[0]
	var visual: Dictionary=actor.authored_visual_state()
	var text: String=str(visual.get("hint",""))
	var semantic: String=str(visual.get("semantic_move_id",""))
	if actor.authored_is_active() and str(visual.get("stage",""))=="stance":
		var actions: Dictionary={"cat_meme_sway":["飛びつき","小跳び","つかみ"],"shark_shoe_dash":["滑る","跳ぶ","止まる"],"chicken_dribble_sway":["肩","小跳び","フェイント"]}
		if actions.has(semantic):
			var words: Array=actions[semantic]
			text="%s %s / %s %s / %s %s" % [_key_label(4),words[0],_key_label(5),words[1],_key_label(7),words[2]]
	elif actor.authored_is_active() and semantic=="rio_drag_charge" and str(visual.get("stage",""))=="charge":
		text=_key_label(7)+" 長押し・離すと振る"+(" / 強！" if str(visual.get("charge_tier",""))=="strong" else "")
	elif actor.fighter_id=="chicken" and not bool(visual.get("ball_in_hand",true)):
		text="ボール回収中 / "+_key_label(7)+"で呼び戻す"
	if not text.is_empty(): _text(text,Vector2(282,201),21,SummerTheme.CREAM,715,HORIZONTAL_ALIGNMENT_CENTER)

## HUD text stays still and uses the shared navy ink on opaque cream paper.
func _hud_text(value: String,pos: Vector2,size: int,color: Color=SummerTheme.NAVY,width: float=-1,alignment: int=HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font,pos,value,alignment,width,size,color)

func _poster_outline(points: PackedVector2Array,color: Color,width: float=2.0) -> void:
	var closed:=points.duplicate()
	closed.append(points[0])
	draw_polyline(closed,color,width,true)

func _draw_hud() -> void:
	FightHUD.draw_hud(self)

func _draw_world_effects() -> void:
	if not font: return
	_draw_skill_releases(); _draw_props()
	_draw_playable_objects()
	_draw_effects()

func _draw_paired_source_targets(target_canvas: CanvasItem) -> void:
	if not source_bindings_enabled or not full_pose_renderer or not full_pose_renderer.has_method("draw_target_pose"): return
	for actor in fighters:
		var context: Dictionary=actor.source_visual_state()
		# Lee's confirmed cat grab owns this paired victim drawing. A different
		# source technique hiding its own body must keep that disappearance.
		if str(context.get("binding_id",""))!="cat:super": continue
		var index: int=int(context.get("paired_target_index",-1))
		if index<0 or index>=fighters.size() or bool(context.get("paired_target_visible",true)): continue
		var victim=fighters[index]
		# The one captured body sits behind the holder, so a large shark cannot
		# conceal the cat's face and both paws. Front contact FX remain above both.
		full_pose_renderer.draw_target_pose(target_canvas,victim,"caught",context)

func _draw_playable_objects(back_layer: bool=false) -> void:
	if not playable_world: return
	if source_bindings_enabled:
		for object in playable_world.objects:
			SourceSkillFX.draw_object(world_skill_back if back_layer else world_effects,object,{},"back" if back_layer else "front")
			var punctuation: Dictionary=_wojak_normal_object_packet(object)
			if not punctuation.is_empty():WojakPunctuationFX.draw_normal_object(world_skill_back if back_layer else world_effects,punctuation,"back" if back_layer else "front")
		return
	for object in playable_world.objects:
		# Preserve the source projectile, but expose the wing/target pose.
		var rear_ball: bool=object.kind=="bullet" and object.fighter_id=="chicken" and object.name=="zh1atm"
		if back_layer and not rear_ball: continue
		var target: CanvasItem=world_skill_back if back_layer else world_effects
		var hits: Array=object.hits()
		var tint: Color=fighters[object.owner_index].accent
		if object.kind=="bullet":
			var box: Rect2=object.transformed_rect(object.bullet_area)
			var pulse: float=sin(float(object.source_frame)*.8)*.12+.85
			if not back_layer: _playable_ellipse(box.grow(5),Color(tint,.18*pulse),target)
			if rear_ball and not back_layer: continue
			_playable_ellipse(box,Color("fca442"),target)
			target.draw_arc(box.get_center(),minf(box.size.x,box.size.y)*.45,0,TAU,16,Color("ffe270"),3,false)
			target.draw_line(box.get_center()+Vector2(-box.size.x*.4,0),box.get_center()+Vector2(box.size.x*.4,0),Color("693942"),2)
		else:
			for hit: Dictionary in hits:
				var box: Rect2=hit["area"]
				_draw_source_effect(world_effects,_object_effect_context(object,hit))
			if object.fighter_id=="chicken" and object.name in ["kj2mc","kj2mc2"]:
				world_effects.draw_set_transform(object.position)
				PixelRenderer.draw_fighter(world_effects,"chicken","launcher",fposmod(float(object.source_frame)/18.0,1.0),object.facing,Color.WHITE,fighters[object.owner_index].body_height)
				world_effects.draw_set_transform(Vector2.ZERO)

## Presentation samples only the current formal HitVO and its own source clock.
## Independent objects keep their child clock even when the owner changes move.
func _actor_effect_context(actor: Variant, hit: Dictionary) -> Dictionary:
	return {"id":actor.fighter_id,"clip":actor.action,"hit_id":str(hit.get("hit_id",hit.get("source_name",""))),"source_frame":float(actor.source_frame)+actor.source_clock*30.0,"frame_space":"relative","definition_key":actor.source_label,"areas":actor.action_data.get("source_definition",{}).get("areas",[]),"area":hit["area"],"facing":actor.facing,"floor_anchor":actor.stage_floor_y}

func _object_effect_context(object: Variant, hit: Dictionary) -> Dictionary:
	return {"id":object.fighter_id,"clip":object.art_clip,"hit_id":str(hit.get("source_name","")),"source_frame":float(object.source_frame)+object.clock*30.0,"frame_space":"absolute","definition_key":str(object.child.get("source_symbol","")),"areas":object.child.get("areas",[]),"area":hit["area"],"facing":object.facing,"removed":object.removed}

func _draw_source_effect(target: CanvasItem, context: Dictionary) -> void:
	var state:=SourceEffectMotion.sample(context)
	if not state.get("ready",false): return
	var display:=_source_effect_display_layout(context,state)
	# Arena-wide fields retain their full hazard silhouette, with less painted
	# density so the original stage and both foreground bodies stay readable.
	target.draw_set_transform(display["offset"],0.0,display["scale"])
	SourceEffectMotion.draw(target,state,Color(1,1,1,float(display["density"])))
	target.draw_set_transform(Vector2.ZERO)

## A ground-painted release uses the painter's height and the real stage floor.
## Only this draw transform changes: sample.area/source clock/HitVO remain exact.
## In particular Aizen's cbs collider extends below the floor; stretching the
## ground-arena picture over that whole collider buries its painted base.
func _source_effect_display_layout(context: Dictionary, state: Dictionary) -> Dictionary:
	var source_rect:=Rect2(state["origin"],state["world_size"])
	var display_rect:=source_rect
	var painted: Dictionary=skill_art.get_effect_state(str(state.get("id","")),str(state.get("clip","")),0.4)
	if painted.get("direction","")=="ground_arena" and context.has("floor_anchor"):
		var floor_y: float=float(context["floor_anchor"])
		var painted_size: Vector2=painted.get("maximum_world_size",Vector2.ZERO)
		if is_finite(floor_y) and painted_size.y>0.0:
			display_rect.size.y=minf(source_rect.size.y,painted_size.y)
			display_rect.position.y=floor_y-display_rect.size.y
	var display_scale:=display_rect.size/source_rect.size
	var direction: String=str(painted.get("direction",""))
	var coverage: float=display_rect.size.x*display_rect.size.y*camera_zoom*camera_zoom/(WIDTH*HEIGHT)
	var minimum_density:=0.70 if direction=="ground_arena" else 0.34
	var density: float=lerpf(1.0,minimum_density,smoothstep(0.70,1.80,coverage)) if state.get("major",false) else 1.0
	return {"rect":display_rect,"source_rect":source_rect,"scale":display_scale,"offset":display_rect.position-source_rect.position*display_scale,"floor_anchored":display_rect!=source_rect,"direction":direction,"coverage":coverage,"density":density}

func _playable_ellipse(box: Rect2, color: Color, target: CanvasItem) -> void:
	var points:=PackedVector2Array()
	for vertex in range(24):
		var angle: float=float(vertex)*TAU/24
		points.append(box.get_center()+Vector2(cos(angle),sin(angle))*box.size*.5)
	target.draw_colored_polygon(points,color)

func _world_text(value: String,pos: Vector2,size: int,color: Color,width: float=-1,alignment: int=HORIZONTAL_ALIGNMENT_LEFT) -> void:
	world_effects.draw_string_outline(font,pos,value,alignment,width,size,4,SummerTheme.NAVY)
	world_effects.draw_string(font,pos,value,alignment,width,size,color)

func _world_floor_wave(center: Vector2,rx: float,ry: float,color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(17):
		var angle := i*TAU/16.0
		points.append(center+Vector2(cos(angle)*rx,sin(angle)*ry))
	world_effects.draw_polyline(points,color,4,false)

func _draw_props() -> void:
	for prop in projectiles:
		var center := Vector2(float(prop["x"]),float(prop["y"]))
		var kind := str(prop["kind"])
		var radius := float(prop["radius"])
		if kind in ["ball","superball"]:
			world_effects.draw_circle(center+Vector2(3,3),radius+3,Color("16101b"))
			world_effects.draw_circle(center,radius,Color("fca442"))
			world_effects.draw_arc(center,radius,0,TAU,28,Color("5a2938"),3,true)
			world_effects.draw_line(center+Vector2(-radius,0),center+Vector2(radius,0),Color("5a2938"),2)
			world_effects.draw_line(center+Vector2(0,-radius),center+Vector2(0,radius),Color("5a2938"),2)
			if kind=="superball":
				world_effects.draw_arc(center,radius+9,0,TAU,32,Color("ffe270"),4,true)
		elif kind=="tear":
			world_effects.draw_colored_polygon(PackedVector2Array([center+Vector2(0,-34),center+Vector2(-20,6),center+Vector2(0,23),center+Vector2(20,6)]),Color("77ddff"))
			world_effects.draw_circle(center+Vector2(-6,-1),5,Color("d9fbff"))
		elif kind=="blade_wave":
			var direction := int(prop["facing"])
			var owner=fighters[int(prop["owner"])]
			var pose: Dictionary=owner.pixel_animation_state()
			var height=float(pose.get("native_height",72))*4*.45
			var fx: Dictionary=skill_art.get_effect_state(owner.fighter_id,"skill1",.35,height)
			if fx.get("ready",false):
				var offset: Vector2=fx["position"]+(Vector2(.5,.5)-fx["anchor"])*fx["world_size"]
				world_effects.draw_set_transform(center-Vector2(offset.x*direction,offset.y))
				skill_art.draw_skill_effect(world_effects,owner.fighter_id,"skill1",.35,direction,Color.WHITE,height)
				world_effects.draw_set_transform(Vector2.ZERO)
			for trail in range(3):
				var y=(trail-1)*13.0
				world_effects.draw_line(center+Vector2(-direction*130,y),center+Vector2(-direction*25,y),Color(.45,.82,1,.18+trail*.06),4,false)
		else:
			world_effects.draw_rect(Rect2(center-Vector2(32,12),Vector2(64,22)),Color("f5e4c6"))
			world_effects.draw_line(center-Vector2(0,12),center+Vector2(0,10),Color("827fa9"),2)
			if float(prop["age"])>=float(prop["fuse"]):
				world_effects.draw_rect(Rect2(center+Vector2(-48,-104),Vector2(96,87)),Color("f4ddb4"))
				_world_text("勉強",center+Vector2(-43,-70),20,Color("192032"),86,HORIZONTAL_ALIGNMENT_CENTER)
				_world_text("ムリ！",center+Vector2(-43,-39),21,Color("c51c48"),86,HORIZONTAL_ALIGNMENT_CENTER)
			else:
				world_effects.draw_arc(center+Vector2(0,-20),23,-PI/2,-PI/2+TAU*float(prop["age"])/float(prop["fuse"]),18,Color("ffdd65"),3,true)

func _draw_effects() -> void:
	for effect in effects:
		if source_bindings_enabled and effect.has("wojak_punctuation_contact_v034"):
			var punctuation: Dictionary=effect.duplicate();punctuation.merge(effect["wojak_punctuation_contact_v034"],true)
			WojakPunctuationFX.draw_normal_contact(world_effects,punctuation,"front")
			continue
		if source_bindings_enabled and effect.has("bvn_contact"):
			var contact: Dictionary=effect.duplicate()
			contact.merge(effect["bvn_contact"],true)
			SourceSkillFX.draw_contact(world_effects,contact,"front")
			continue
		if effect.has("authored_contact"):
			var info: Dictionary=effect["authored_contact"]
			AuthoredSkillFX.draw_contact(world_effects,effect["pos"],str(info["id"]),str(info["semantic_id"]),str(info["outcome"]),float(effect.get("visual_age",0)),int(effect.get("facing",1)))
			continue
		if not effect.get("feedback",{}).is_empty():
			BattleFeedback.draw(world_effects,BattleFeedback.sample(effect),impact_texture)
			continue
		var progress := 1.0-float(effect["life"])/float(effect["max"])
		var elapsed := progress*float(effect["max"])
		var pos: Vector2=effect["pos"]
		var color: Color=effect["color"]
		var style := str(effect.get("style","hit"))
		var strong: bool=effect["strong"]
		var facing: int=effect.get("facing",1)
		color.a=pow(1.0-progress,1.3)
		var size := 49.0 if strong else 29.0
		if style=="dust":
			for puff in range(4):
				var x := (puff-1.5)*(8+progress*35)
				var y := -sin(progress*PI)*(8+absf(puff-1.5)*7)
				var center := pos+Vector2(x,y)
				_world_floor_wave(center,7+progress*15,4+progress*8,Color(0.90,0.77,0.58,(1-progress)*0.16))
		elif style=="burst":
			world_effects.draw_arc(pos,50+progress*180,0,TAU,48,color,7*(1-progress)+1,true)
			world_effects.draw_arc(pos,35+progress*120,0,TAU,40,Color(1,1,1,color.a),2,true)
		elif style=="guard":
			world_effects.draw_arc(pos,22+progress*38,-1.8 if facing>0 else 1.3,1.8 if facing>0 else 4.8,24,color,4,true)
			world_effects.draw_line(pos+Vector2(-13,-25),pos+Vector2(13,25),Color(1,1,1,color.a),5)
			world_effects.draw_line(pos+Vector2(-13,25),pos+Vector2(13,-25),color,4)
		else:
			if impact_texture:
				var source := impact_frame_state(strong,clampf(elapsed/0.16,0,1))
				var extent := (220.0 if strong else 135.0)+sin(progress*PI)*(22.0 if strong else 20.0)
				world_effects.draw_texture_rect_region(impact_texture,Rect2(pos-Vector2.ONE*extent*0.5,Vector2.ONE*extent),source["region"],Color(1,1,1,1.0-progress*0.72))
			else:
				var points := PackedVector2Array()
				for j in range(16):
					var angle := j*TAU/16.0
					var radius := size*(0.85+progress*0.8)*(1.0 if j%2==0 else 0.30)
					points.append(pos+Vector2(cos(angle),sin(angle))*radius)
				world_effects.draw_colored_polygon(points,color)
				world_effects.draw_circle(pos,10*(1-progress),Color(1,1,1,color.a))
			world_effects.draw_arc(pos,size*(0.45+progress*2.2),0,TAU,32,Color(color,color.a*0.7),3,true)
			if strong:
				var floor_pos := Vector2(pos.x,stage_map.player_bottom-3)
				_world_floor_wave(floor_pos,25+progress*150,9+progress*22,Color(color,color.a*0.50))
				for streak in range(4):
					var y := -33.0+streak*22.0
					var tail := pos+Vector2((-45-progress*110)*facing,y)
					world_effects.draw_line(tail,tail+Vector2(60*facing,-4),Color(1,1,1,color.a*0.55),2,true)
				var combos: int=effect.get("combo",1)
				for extra in range(mini(3,combos-1)):
					var tiny := pos+Vector2((extra*27-32)*facing,-45-extra*9)
					world_effects.draw_line(tiny-Vector2(9,9),tiny+Vector2(9,9),Color(1,1,1,color.a),2)
					world_effects.draw_line(tiny-Vector2(9,-9),tiny+Vector2(9,-9),color,2)
		var shards: Array=effect.get("shards",[])
		for shard in shards:
			var vector: Vector2=shard["velocity"]
			if strong and style=="hit":
				var debris_origin := Vector2(pos.x,stage_map.player_bottom-5)
				var debris := debris_origin+Vector2(vector.x*elapsed*0.65,-absf(vector.y)*elapsed+450*elapsed*elapsed)
				var length := float(shard["size"])
				var angle := float(shard["rotation"])+elapsed*5.0
				var triangle := PackedVector2Array([debris+Vector2(-length,-length*0.5).rotated(angle),debris+Vector2(length,-length*0.5).rotated(angle),debris+Vector2(0,length).rotated(angle)])
				world_effects.draw_colored_polygon(triangle,Color(0.95,0.84,0.58,color.a))
			else:
				var spark := pos+vector*elapsed
				var tip := spark+vector.normalized()*(9+progress*8)
				world_effects.draw_line(spark,tip,Color(color,color.a),2,true)

## Pixel world and HD UI share this single projection, including camera feedback.
func world_to_screen(point: Vector2) -> Vector2:
	return ARENA_RECT.position+(canvas.position+point*canvas.scale)*ARENA_SCALE

func world_rect_to_screen(rect: Rect2) -> Rect2:
	return Rect2(world_to_screen(rect.position),rect.size*canvas.scale*ARENA_SCALE)

func _draw_popups() -> void:
	# Meaningful feedback is readable HD UI; contact sparks remain in the pixel world.
	for popup in popups:
		var progress := 1.0-float(popup["life"])/float(popup["max"])
		var source: Vector2=popup["pos"]+Vector2(0,-progress*27)
		var pos:=world_to_screen(source)
		pos.x=clampf(pos.x,ARENA_RECT.position.x+160,ARENA_RECT.end.x-160)
		pos.y=clampf(pos.y,165,ARENA_RECT.end.y-20)
		var color: Color=popup["color"]
		color.a=minf(1.0,float(popup["life"])*4)
		_text(str(popup["text"]),pos+Vector2(-160,0),22,color,320,HORIZONTAL_ALIGNMENT_CENTER)

func impact_frame_state(strong: bool,progress: float) -> Dictionary:
	var region := Rect2()
	var column := clampi(floori(progress*4),0,3)
	var row:=1 if strong else 0
	if impact_texture:
		var cell:=impact_texture.get_size()/Vector2(4,2)
		region=Rect2(Vector2(column,row)*cell,cell)
	return {"available":impact_texture!=null,"row":row,"column":column,"region":region}

func _draw_floor_wave(center: Vector2,rx: float,ry: float,color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(33):
		var angle := i*TAU/32.0
		points.append(center+Vector2(cos(angle)*rx,sin(angle)*ry))
	draw_polyline(points,color,3,true)

func _pause_button_rect(index: int) -> Rect2:
	return Rect2(415,235+index*63+(HEIGHT-720)*.5,450,54)

func _banner(title: String,color: Color) -> void:
	draw_set_transform(Vector2(0,(HEIGHT-720)*.5))
	draw_colored_polygon(PackedVector2Array([Vector2(0,294),Vector2(1280,260),Vector2(1280,382),Vector2(0,416)]),Color(0.05,0.03,0.09,0.85))
	_text(title,Vector2(ARENA_RECT.position.x,365),60,color,ARENA_RECT.size.x,HORIZONTAL_ALIGNMENT_CENTER)
	draw_set_transform(Vector2.ZERO)

func _source_bisha_started(actor, args: Array=[]) -> void:
	# Notification from the actual source effect event; this starts no gameplay timer.
	cinema_source_start_frame=int(actor.source_absolute_frame)
	cinema_source_start_clock=float(actor.source_clock)
	cinema_source_binding=str(actor.source_binding_id)
	cinema_source_is_super=bool(SourcePresentation.argument(args,0,false))
	cinema_source_face=str(SourcePresentation.argument(args,1,""))

func source_cinema_presentation() -> Dictionary:
	if not playable_world or playable_world.bisha_owner<0: return {"ready":false}
	var actor=fighters[playable_world.bisha_owner]
	var tier: int=maxi(SourceSkillFX.tier_for(cinema_source_binding),3 if cinema_source_is_super else 1)
	var duration: float=.56 if tier>=3 else .40
	var age: float=maxf(0.0,float(actor.source_absolute_frame-cinema_source_start_frame)/30.0+actor.source_clock-cinema_source_start_clock)
	return {"ready":age<duration,"tier":tier,"age":age,"duration":duration,"progress":clampf(age/duration,0,1),"binding_id":cinema_source_binding,"source_start_frame":cinema_source_start_frame,"source_is_super":cinema_source_is_super,"source_face":cinema_source_face,"mapped_face_id":str(actor.fighter_id)}

func _draw_cinema() -> void:
	# A short graded face slash follows real Bisha frames, without extending its freeze.
	var actor=fighters[cinema_owner]
	var progress=clampf(1.0-cinema_time/CUTIN_SECONDS,0.0,1.0)
	var tier: int=SourceSkillFX.tier_for(actor.source_binding_id) if source_bindings_enabled else 3
	var major: bool=tier>=3
	var duration: float=.56 if major else .40
	if playable_world and playable_world.bisha_owner>=0:
		var display: Dictionary=source_cinema_presentation()
		if not display.get("ready",false): return
		progress=float(display["progress"])
		tier=int(display["tier"]); major=tier>=3
	var entrance=minf(1.0,progress/.16)
	var exit=maxf(0.0,(progress-.76)/.24)
	var shift=(1.0-entrance)*(72 if major else 40)+exit*46
	var alpha: float=entrance*(1-exit)
	draw_set_transform(Vector2(ARENA_RECT.position.x+shift,16),0,Vector2.ONE*ARENA_SCALE)
	var side: Color=SummerTheme.CORAL if cinema_owner==0 else SummerTheme.SEA
	var left: float=350.0 # Reserve the transparent control guide throughout the entrance.
	var top: float=121 if major else 132
	var bottom: float=286 if major else 249
	draw_colored_polygon(PackedVector2Array([Vector2(left,top),Vector2(1220,top-10),Vector2(1280,bottom-24),Vector2(left+10,bottom)]),Color(SummerTheme.NAVY,.96*alpha))
	draw_line(Vector2(left,top+8),Vector2(1203,top),Color(SummerTheme.SUN,alpha),6 if major else 3,true)
	draw_line(Vector2(left+28,bottom-6),Vector2(1280,bottom-26),Color(side,alpha),4,true)
	for line in range(12 if major else 7):
		var x: float=450+line*78+progress*65
		draw_line(Vector2(x,top+19),Vector2(x-96,bottom-24),Color(side,.23*alpha),5 if major else 2,true)
	_draw_character_cinema_mark(str(actor.fighter_id),Vector2(1150,(top+bottom)*.5),progress,major,alpha)
	if alpha>.08:
		var portrait_rect: Rect2=Rect2(left+18,top+17,217 if major else 168,bottom-top-29)
		if RosterPortrait.supports(str(actor.fighter_id)):RosterPortrait.draw_portrait(self,actor.fighter_id,portrait_rect,"cutin",0.0,true,Color(1,1,1,alpha))
		else:FightHUD.draw_portrait(self,actor.fighter_id,portrait_rect)
	_hud_text("超必殺 / 3 気" if major else "必殺 / 1 気",Vector2(left+254,top+39),20 if major else 16,Color(SummerTheme.SUN,alpha))
	_hud_text(cinema_name,Vector2(left+250,top+98 if major else top+77),41 if major else 31,Color(SummerTheme.CREAM,alpha),1280-left-280)
	_hud_text(actor.display_name,Vector2(left+253,bottom-17),15,Color(side,alpha),1280-left-280)
	draw_set_transform(Vector2.ZERO)

func _draw_character_cinema_mark(id: String, at: Vector2, progress: float, major: bool, alpha: float) -> void:
	if id=="chicken":
		var radius:=58.0 if major else 38.0
		var spin:=progress*PI*.30
		draw_set_transform(Vector2(ARENA_RECT.position.x,16)+at*ARENA_SCALE,spin,Vector2.ONE*ARENA_SCALE)
		draw_circle(Vector2.ZERO,radius,Color(SummerTheme.CORAL,.36*alpha))
		draw_arc(Vector2.ZERO,radius,0,TAU,40,Color(SummerTheme.SUN,.86*alpha),3.0,true)
		draw_line(Vector2(-radius,0),Vector2(radius,0),Color(SummerTheme.NAVY,alpha),3.0,true)
		draw_line(Vector2(0,-radius),Vector2(0,radius),Color(SummerTheme.NAVY,alpha),3.0,true)
		for sign_x in [-1.0,1.0]:
			var curve:=PackedVector2Array()
			for i in range(17):
				var y: float=-radius+float(i)*radius/8.0
				curve.append(Vector2(sign_x*radius*.45*sin(float(i)*PI/16.0),y))
			draw_polyline(curve,Color(SummerTheme.NAVY,alpha),2.5,true)
	elif id=="rio":
		draw_set_transform(Vector2(ARENA_RECT.position.x,16),0,Vector2.ONE*ARENA_SCALE)
		var length:=90.0 if major else 59.0
		var axis:=Vector2(.72,-.69)
		var side:=Vector2(-axis.y,axis.x)
		var base:=at-axis*length*.55
		var tip:=at+axis*length
		var blade:=PackedVector2Array([base-side*12.0,tip,base+side*12.0])
		draw_colored_polygon(blade,Color(SummerTheme.SEA,.40*alpha))
		draw_line(base,tip,Color(SummerTheme.CREAM,.78*alpha),3.0,true)
		draw_line(base-side*22.0,base+side*22.0,Color(SummerTheme.SUN,.8*alpha),5.0,true)
		draw_line(base,base-axis*22.0,Color(SummerTheme.CORAL,.85*alpha),6.0,true)
	# Return to the parent's short face-cut projection; gameplay bodies and the
	# stable life/timer HUD never inherit this character-specific ornament.
	draw_set_transform(Vector2(ARENA_RECT.position.x+(1.0-minf(1.0,progress/.16))*(-72 if major else -40)+maxf(0.0,(progress-.76)/.24)*46,16),0,Vector2.ONE*ARENA_SCALE)

func _draw_authored_cutins() -> void:
	if authored_cutins.is_empty() or phase!="active" or paused: return
	var cutin: Dictionary=authored_cutins[-1]
	var actor=fighters[int(cutin["owner"])]
	var p: float=clampf(1-float(cutin["time"])/float(cutin["duration"]),0,1)
	var entrance: float=smoothstep(0,.22,p)
	var departure: float=smoothstep(.68,1,p)
	var shift: float=0.0 if reduced_motion else (1-entrance)*-120+departure*120
	var alpha: float=clampf(entrance*(1-departure),0,1)
	var tint: Color=actor.accent
	draw_set_transform(Vector2(shift,0))
	draw_colored_polygon(PackedVector2Array([Vector2(244,157),Vector2(1195,143),Vector2(1250,302),Vector2(267,338)]),Color(SummerTheme.NAVY,.95*alpha))
	for n in range(12):
		var x: float=300+n*83+fposmod(p*200,83)
		draw_line(Vector2(x,160),Vector2(x-135,302),Color(tint,.30*alpha),8,false)
	draw_line(Vector2(252,162),Vector2(1195,147),Color(SummerTheme.SUN,alpha),6,false)
	draw_line(Vector2(279,330),Vector2(1250,297),Color(tint,alpha),5,false)
	# Existing illustrated portrait, separate from the actual single combat body.
	if alpha>.06: FightHUD.draw_portrait(self,actor.fighter_id,Rect2(285,174,198,133))
	var cue: String="超必殺！" if bool(cutin["major"]) else "必殺！"
	_hud_text(cue,Vector2(512,191),22,Color(SummerTheme.SUN,alpha))
	var title: String=str(cutin["name"])
	var size: int=39
	while size>26 and font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>700: size-=1
	_hud_text(title,Vector2(507,249),size,Color(SummerTheme.CREAM,alpha),713)
	_hud_text(actor.display_name,Vector2(512,287),20,Color(tint,alpha))
	draw_set_transform(Vector2.ZERO)

func _draw_pause() -> void:
	draw_rect(Rect2(0,0,WIDTH,HEIGHT),Color(SummerTheme.CREAM,0.76))
	draw_set_transform(Vector2(0,(HEIGHT-720)*.5))
	var poster:=PackedVector2Array([Vector2(390,110),Vector2(909,88),Vector2(879,640),Vector2(365,665)])
	var shadow:=PackedVector2Array()
	for point in poster: shadow.append(point+Vector2(7,8))
	draw_colored_polygon(shadow,Color(SummerTheme.NAVY,0.14))
	draw_colored_polygon(poster,SummerTheme.CREAM)
	_poster_outline(poster,SummerTheme.NAVY,3)
	draw_colored_polygon(PackedVector2Array([Vector2(391,110),Vector2(415,109),Vector2(395,645),Vector2(366,665)]),SummerTheme.AQUA)
	draw_colored_polygon(PackedVector2Array([Vector2(802,95),Vector2(909,88),Vector2(906,123),Vector2(799,130)]),SummerTheme.SUN)
	_hud_text("ちょっと休憩",Vector2(415,178),42,SummerTheme.NAVY,450,HORIZONTAL_ALIGNMENT_CENTER)
	_hud_text("ひと息ついたら、もうひと勝負。",Vector2(415,207),16,SummerTheme.MUTED,450,HORIZONTAL_ALIGNMENT_CENTER)
	var options := ["対戦に戻る", "もう一度", "キャラクター選択へ", "この対戦の技表", "音・演出・キー設定"]
	for i in range(5):
		var presentation:=_pause_button_presentation(i)
		var state:=str(presentation.state)
		var rect: Rect2=presentation.visual_rect
		rect.position.y-=(HEIGHT-720)*.5
		var focused:=state in ["focus","pressed","confirmed"]
		var text_color:=SummerTheme.MUTED if state=="disabled" else SummerTheme.NAVY
		var button:=PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x-10,0),rect.position+Vector2(rect.size.x,10),rect.end,rect.position+Vector2(0,rect.size.y)])
		draw_colored_polygon(button,SummerTheme.CORAL if state=="pressed" else SummerTheme.SUN if focused else SummerTheme.CREAM)
		_poster_outline(button,SummerTheme.MUTED if state=="disabled" else SummerTheme.NAVY,3 if focused else 1.5)
		draw_line(rect.position+Vector2(7,rect.size.y-4),rect.position+Vector2(rect.size.x-7,rect.size.y-4),SummerTheme.CORAL if focused else SummerTheme.SEA,3,true)
		if focused:
			draw_colored_polygon(PackedVector2Array([rect.position+Vector2(10,19),rect.position+Vector2(20,27),rect.position+Vector2(10,35)]),SummerTheme.NAVY)
		_hud_text("%02d" % (i+1),rect.position+Vector2(28,35),16,SummerTheme.MUTED)
		_hud_text(options[i],rect.position+Vector2(67,37),26,text_color,366,HORIZONTAL_ALIGNMENT_CENTER)
		if state=="confirmed":
			draw_polyline(PackedVector2Array([rect.position+Vector2(417,21),rect.position+Vector2(424,29),rect.position+Vector2(437,15)]),SummerTheme.NAVY,3,true)
	_hud_text("↑↓ 選択 / Enter 決定 / ESC 戻る",Vector2(415,590),17,SummerTheme.MUTED,450,HORIZONTAL_ALIGNMENT_CENTER)
	_hud_text("マウス / A 決定 / B・START 戻る",Vector2(415,616),14,SummerTheme.MUTED,450,HORIZONTAL_ALIGNMENT_CENTER)
	draw_set_transform(Vector2.ZERO)
