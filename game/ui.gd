extends Control
## Japanese, mouse / keyboard friendly front end. All coordinates use a 1280 x 720 canvas.

signal start_requested(p1_id: String, p2_id: String, mode: String, difficulty: String)
signal quit_requested
signal settings_changed(values: Dictionary)
signal training_recipe_requested(recipe: String)
signal vs_start_requested
signal vs_cancelled
signal battle_page_closed

const Data = preload("res://game/data.gd")
const BVNSelectFlow = preload("res://game/bvn_select_flow.gd")
const HDPortrait = preload("res://game/hd_portrait.gd")
const RosterPortraitV034 = preload("res://game/bvn_roster_portrait_v034.gd")
const HDStageShader = preload("res://game/hd_home_stage.gdshader")
const Summer = preload("res://game/summer_theme.gd")
const INK := Summer.NAVY
const PAPER := Summer.CREAM
const RED := Summer.CORAL
const YELLOW := Summer.SUN
const BLUE := Summer.SEA
const MUTED := Summer.MUTED
const AQUA := Summer.AQUA
var _ids: Array[String] = ["shark", "cat", "worker", "chicken", "rio"]

var _roster: Dictionary = {}
var _art: Dictionary = {}
var _face_art: Dictionary = {}
var _face_parts: Dictionary = {}
var _portrait_data: Dictionary = {}
var _visual_target_ids: Array[String] = []
var _modern_art := false
var _hd_motion: Dictionary = {}
var _hd_rig: Script
var _hd_performers: Array[Control] = []
var _animations: Dictionary = {}
var _core_animations: Dictionary = {}
var _animation_metrics: Dictionary = {}
var _home_performer: PartyHDCanvas
var _home_buttons: Array[Button] = []
var _confirm_busy := false
var _pending_tween: Tween
var _stick_axis := Vector2.ZERO
var _stick_repeat := 0.0
var _last_home_focus := -1
var _home_idle_seconds := 0.0
var _home_easter_index := 0
const HOME_EASTER_IDLE_SECONDS := 33.0
const HOME_EASTER_DURATION := 1.5
const HOME_EASTER_CAST := ["rio", "cat", "worker", "chicken", "shark"]
var _rio_reactions: Dictionary = {}
var _rio_clip_units: Dictionary = {}
var _ui_time := 0.0
var _beat_time := 0.0
var _entry_time := 0.0
var _home_logo: Control
const MENU_BPM := 160.0
var _screen: Control
var _page := "home"
var _mode := "cpu"
var _difficulty := "normal"
var _p1 := "shark"
var _p2 := "chicken"
var _p1_locked := false
var _p2_locked := false
var _active_index := 0
var _select_flow = BVNSelectFlow.new()
var _card_buttons: Array[Button] = []
var _random_button: Button
var _selection_aux: Array[Button] = []
var _start_button: Button
var _last_match: Dictionary = {}
var _settings: Dictionary = {"volume": 0.55, "shake": true, "flash": true, "reduced_motion": false, "bindings_p1": Data.DEFAULT_P1.duplicate(), "bindings_p2": Data.DEFAULT_P2.duplicate()}
var _training_recipe := "normal_chain"
var _training_recipes: Array[String] = ["normal_chain", "air_chain", "full_normal", "hit_confirm", "sparring"]
var authored_skills_enabled := false
var source_bindings_enabled := true
var _training_routes: Script
var _guide_return := "home"
var _guide_tab := 0
var _guide_character_id := "rio"
var _binding_player := -1
var _binding_action := -1
var _binding_message := "変更するボタンを選び、新しいキーを押してください。"
var _binding_buttons: Array[Button] = []
var _binding_status: Label
var _volume_label: Label
var _ready_done := false
var _vs_active: bool = false
var _vs_elapsed: float = 0.0
const VS_SECONDS: float = 1.8
var _battle_page_active: bool = false

# Selection advice describes the existing source kit, not a balance ranking.
const CHARACTER_ADVICE: Dictionary = {
 "shark": {"type":"前進・間合い", "difficulty":"扱い：ふつう"},
 "cat": {"type":"接近・空中派生", "difficulty":"扱い：むずかしい"},
 "worker": {"type":"反撃・設置", "difficulty":"扱い：ふつう"},
 "chicken": {"type":"ボール・牽制", "difficulty":"扱い：ふつう"},
 "rio": {"type":"大剣・一撃", "difficulty":"扱い：むずかしい"},
 "notify": {"type":"連続通知・バッグ", "difficulty":"扱い：ふつう"},
 "wojak": {"type":"連撃・広い記号", "difficulty":"扱い：むずかしい"},
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_roster()
	_load_settings()
	_ready_done = true
	show_home()


func _load_roster() -> void:
	# Runtime loading lets the front end start even while the character art is being prepared.
	_art.clear()
	_face_art.clear()
	_face_parts.clear()
	_visual_target_ids.clear()
	_roster = {
		"shark": {"name": "トララレロ・トラララ", "subtitle": "三足のスニーカーシャーク", "description": "長いリーチと突進で押し切る。空振りには注意！", "moves": ["三足ダッシュ", "三脚スピン", "ビーチダイブ"], "super": "三足ワールドツアー", "color": BLUE, "difficulty": 1},
		"cat": {"name": "ハッピーキャット", "subtitle": "表情で戦うミーム猫", "description": "ジャンプと「Huh?」で相手を翻弄。技ごとに顔が変わる！", "moves": ["ハッピージャンプ", "Huh? カウンター", "涙ころころ"], "super": "猫ミームグループチャット", "color": YELLOW, "difficulty": 2},
		"worker": {"name": "定時退社くん", "subtitle": "帰りたい、ただそれだけ", "description": "文字と道具で距離を作る。今日の仕事は、もう終わり。", "moves": ["お気をつけて", "定時ダッシュ", "勉強したくない"], "super": "本日はここまで", "color": Color("54c5aa"), "difficulty": 2},
		"rio": {"name": "蒼刃リオ", "subtitle": "蒼月の大剣使い・22歳", "description": "蒼い髪、大きな刃、一瞬の勝負。", "moves": ["蒼波斬", "昇月斬", "一刀・轟刃"], "super": "蒼月・断界", "color": Color("5b96ff"), "difficulty": 2},
		"chicken": {"name": "クン・チキン", "subtitle": "コートの練習生", "description": "バスケとステップでペースを握る。近づいたら肩で勝負！", "moves": ["バスケパス", "練習生ステップ", "ショルダータックル"], "super": "ベスト・プラクティスター", "color": Color("ffa55c"), "difficulty": 1},
	}
	if ResourceLoader.exists("res://game/data.gd"):
		var data_script: Script = load("res://game/data.gd")
		if data_script:
			var constants: Dictionary = data_script.get_script_constant_map()
			if constants.get("ROSTER") is Dictionary:
				_roster = constants["ROSTER"]
			if constants.get("ORDER") is Array:
				_ids.assign(Data.playable_ids())
	var portrait_path := "res://assets/art/portraits.json"
	if FileAccess.file_exists(portrait_path):
		var portraits: Variant = JSON.parse_string(FileAccess.get_file_as_string(portrait_path))
		if portraits is Dictionary and int(portraits.get("version", 0)) == 1 and portraits.get("portraits") is Dictionary:
			_portrait_data = portraits["portraits"]
	var target_portraits: Dictionary = {}
	var target_path := "res://assets/art/visual_v18/metadata.json"
	if FileAccess.file_exists(target_path):
		var target: Variant = JSON.parse_string(FileAccess.get_file_as_string(target_path))
		if target is Dictionary and int(target.get("version", 0)) == 1:
			target_portraits = target.get("portraits", {})
	var motion_path := "res://assets/art/ui_motion.json"
	if FileAccess.file_exists(motion_path):
		var motion: Variant = JSON.parse_string(FileAccess.get_file_as_string(motion_path))
		if motion is Dictionary and int(motion.get("version",0)) == 1:
			_hd_motion = motion
	var crop_regions := {
		"shark": Rect2(65, 89, 1551, 781),
		"cat": Rect2(27, 16, 1046, 1415),
		"worker": Rect2(266, 99, 658, 1143),
		"chicken": Rect2(204, 41, 1021, 1056),
		"rio": Rect2(18, 10, 1003, 1515),
	}
	for id: String in _ids:
		var art_path := "res://assets/art/%s.png" % id
		var entry: Dictionary = _portrait_data.get(id, {})
		if target_portraits.get(id) is Dictionary:
			var preferred: Dictionary = target_portraits[id]
			var preferred_path := "res://" + str(preferred.get("source", "assets/art/visual_v18/%s.png" % id)).trim_prefix("res://")
			if ResourceLoader.exists(preferred_path):
				art_path = preferred_path
				entry = preferred
				_visual_target_ids.append(id)
		if ResourceLoader.exists(art_path):
			var atlas := AtlasTexture.new()
			atlas.atlas = load(art_path)
			var canvas_rect := Rect2(Vector2.ZERO, atlas.atlas.get_size())
			atlas.region = (crop_regions.get(id, canvas_rect) as Rect2).intersection(canvas_rect)
			var canvas: Array = entry.get("canvas", [])
			if canvas.size() == 2 and atlas.atlas.get_size() == Vector2(float(canvas[0]), float(canvas[1])):
				var body: Array = entry.get("full_body_rect", [])
				var head: Array = entry.get("source_rect", [])
				if body.size() == 4 and head.size() == 4:
					var body_rect := Rect2(float(body[0]), float(body[1]), float(body[2]), float(body[3]))
					var face_rect := Rect2(float(head[0]), float(head[1]), float(head[2]), float(head[3]))
					if not body_rect.has_area() or not face_rect.has_area() or not canvas_rect.encloses(body_rect) or not canvas_rect.encloses(face_rect):
						continue
					atlas.region = body_rect
					var face := AtlasTexture.new()
					face.atlas = atlas.atlas
					face.region = face_rect
					_face_art[id] = face
					var parts: Array[Rect2] = []
					for raw: Variant in entry.get("source_parts", []):
						if raw is Array and raw.size() == 4:
							var part := Rect2(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))
							if part.has_area() and face.region.encloses(part):
								parts.append(part)
					_face_parts[id] = parts
			_art[id] = atlas
	_modern_art = true
	for legacy_id: String in Data.ORDER:
		if not _face_art.has(legacy_id): _modern_art = false
	if ResourceLoader.exists("res://game/hd_character_rig.gd"):
		_hd_rig = load("res://game/hd_character_rig.gd")


func _load_animation_resources() -> void:
	if _modern_art:
		# HD articulated menu actors and the separate playable pixel previews share
		# identity, while obsolete whole-body sheets do not replace the new masters.
		return
	for id: String in _ids:
		var dance_path := "res://assets/animation/%s_dance.png" % id
		var core_path := "res://assets/animation/%s_core.png" % id
		var idle_path := "res://assets/animation/%s_idle.png" % id
		if ResourceLoader.exists(idle_path):
			_core_animations[id] = _animation_data(idle_path, 4, 1, 4, "idle")
		elif ResourceLoader.exists(core_path):
			_core_animations[id] = _animation_data(core_path, 4, 8, 4, "idle")
		else:
			_core_animations.erase(id)
		if ResourceLoader.exists(dance_path):
			_animations[id] = _animation_data(dance_path, 4, 2, 8, "dance")
		elif _core_animations.has(id):
			_animations[id] = _core_animations[id]

	if _rio_clip_units.is_empty():
		# Reuse the art-approved, clip-wide body units used by the fighter renderer.
		var calibration_path := "res://assets/animation/rio-clip-calibration.json"
		if FileAccess.file_exists(calibration_path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(calibration_path))
			if parsed is Dictionary and parsed.get("clips") is Dictionary:
				_rio_clip_units = parsed["clips"]
		if _rio_clip_units.is_empty():
			_rio_clip_units = {
				"idle": {"body_height":448.0,"foot_line":731.0,"center_x":270.0},
				"heavy": {"body_height":296.0,"foot_line":733.0,"center_x":234.0},
				"light": {"body_height":200.0,"foot_line":620.0,"center_x":232.0},
				"block": {"body_height":252.0,"foot_line":654.0,"center_x":205.0},
			}
	for kind: String in ["idle", "heavy", "light", "block"]:
		var path := "res://assets/animation/rio_%s.png" % kind
		if ResourceLoader.exists(path) and not _rio_reactions.has(kind):
			_rio_reactions[kind] = _animation_data(path, 4, 1, 4, "reaction")
			_rio_reactions[kind]["body_calibration"] = _rio_clip_units.get(kind, {})


func _animation_data(path: String, columns: int, rows: int, frames: int, kind: String) -> Dictionary:
	var sprite: Texture2D = load(path)
	if sprite == null:
		return {}
	var metadata_path := path.trim_suffix(".png") + ".frames.json"
	var metadata_stamp := FileAccess.get_modified_time(metadata_path) if FileAccess.file_exists(metadata_path) else 0
	var cache_key := "%s:%d:%d:%d:%d" % [path, columns, rows, sprite.get_instance_id(), metadata_stamp]
	if not _animation_metrics.has(cache_key):
		var metrics := _curated_idle_metrics(sprite, metadata_path, columns, rows) if path.ends_with("_core.png") else {}
		if metrics.is_empty():
			metrics = _measure_first_row(sprite, columns, rows)
		_animation_metrics[cache_key] = metrics
	var metrics: Dictionary = _animation_metrics[cache_key]
	return {
		"texture": sprite, "columns": columns, "rows": rows, "frames": frames, "kind": kind,
		"bounds": metrics["bounds"], "common_foot": metrics["common_foot"], "cell": metrics["cell"],
		"frame_regions": metrics.get("frame_regions", []), "frame_parts": metrics.get("frame_parts", []),
		"body_height_unit": metrics.get("body_height_unit", 0.0),
		"center_x": metrics.get("center_x", 0.0), "body_scale": metrics.get("body_scale", 1.0),
	}


func _curated_idle_metrics(sprite: Texture2D, path: String, columns: int, rows: int) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("Invalid UI animation frame metadata: " + path)
		return {}
	var metadata: Dictionary = parsed
	if not metadata.get("canvas") is Array or not metadata.get("frames") is Array or not metadata.get("row_calibration") is Array:
		push_warning("Incomplete UI animation frame metadata: " + path)
		return {}
	var canvas: Array = metadata["canvas"]
	var entries: Array = metadata["frames"]
	var rows_calibration: Array = metadata["row_calibration"]
	if int(metadata.get("version", 0)) != 1 or canvas.size() != 2 or int(metadata.get("columns", 0)) != columns or int(metadata.get("rows", 0)) != rows or entries.size() != columns * rows:
		push_warning("UI animation metadata layout does not match: " + path)
		return {}
	var atlas_size := sprite.get_size()
	if Vector2(float(canvas[0]), float(canvas[1])) != atlas_size:
		push_warning("UI animation metadata canvas does not match: " + path)
		return {}
	var calibration: Dictionary = {}
	for row_data: Variant in rows_calibration:
		if row_data is Dictionary and int(row_data.get("row", -1)) == 0:
			calibration = row_data
			break
	var body_height := float(calibration.get("body_height_unit", 0.0))
	if body_height <= 0.0:
		push_warning("UI animation metadata needs a fixed idle body height: " + path)
		return {}
	var cell := atlas_size / Vector2(columns, rows)
	var regions: Array[Rect2] = []
	regions.resize(columns)
	var parts_by_frame: Array = []
	parts_by_frame.resize(columns)
	var found_columns: Dictionary = {}
	var joint_bounds := Rect2()
	for entry: Variant in entries:
		if not entry is Dictionary or int(entry.get("row", -1)) != 0:
			continue
		var column := int(entry.get("col", -1))
		var values: Variant = entry.get("actual_rect")
		if column < 0 or column >= columns or found_columns.has(column) or not values is Array or values.size() != 4:
			push_warning("UI animation metadata has invalid idle source rectangles: " + path)
			return {}
		var region := Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
		if not region.has_area() or region.position.x < 0.0 or region.position.y < 0.0 or region.end.x > atlas_size.x or region.end.y > atlas_size.y:
			push_warning("UI animation metadata source rectangle exceeds its canvas: " + path)
			return {}
		regions[column] = region
		var parts: Array[Rect2] = []
		var raw_parts: Variant = entry.get("source_parts", [])
		if not raw_parts is Array:
			push_warning("UI animation metadata source_parts must be an array: " + path)
			return {}
		for raw_part: Variant in raw_parts:
			if not raw_part is Array or raw_part.size() != 4:
				push_warning("UI animation metadata has invalid source parts: " + path)
				return {}
			var part := Rect2(float(raw_part[0]), float(raw_part[1]), float(raw_part[2]), float(raw_part[3]))
			if not part.has_area() or part.position.x < 0.0 or part.position.y < 0.0 or part.end.x > atlas_size.x or part.end.y > atlas_size.y:
				push_warning("UI animation metadata source part exceeds its canvas: " + path)
				return {}
			parts.append(part)
		parts_by_frame[column] = parts
		found_columns[column] = true
		var logical_region := Rect2(region.position - Vector2(column, 0) * cell, region.size)
		joint_bounds = logical_region if not joint_bounds.has_area() else joint_bounds.merge(logical_region)
	if found_columns.size() != columns:
		push_warning("UI animation metadata is missing idle frames: " + path)
		return {}
	return {
		"bounds": joint_bounds, "common_foot": float(calibration.get("foot_line", joint_bounds.end.y)),
		"cell": cell, "frame_regions": regions, "frame_parts": parts_by_frame, "body_height_unit": body_height,
		"center_x": float(calibration.get("center_x", joint_bounds.get_center().x)),
		"body_scale": maxf(float(calibration.get("body_scale", 1.0)), 0.01),
	}


func _measure_first_row(sprite: Texture2D, columns: int, rows: int) -> Dictionary:
	# Every frame keeps its full source cell. Only a shared first-row reference is measured once.
	var cell := sprite.get_size() / Vector2(columns, rows)
	var bounds := Rect2(Vector2.ZERO, cell)
	var image := sprite.get_image()
	if image == null or image.is_empty():
		return {"bounds": bounds, "common_foot": cell.y, "cell": cell}
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var pixels := image.get_data()
	var width := image.get_width()
	var first_row_height := mini(ceili(cell.y), image.get_height())
	var minimum := cell
	var maximum := Vector2.ZERO
	var found := false
	for y: int in range(first_row_height):
		var alpha_start := y * width * 4 + 3
		for x: int in range(width):
			if pixels[alpha_start + x * 4] <= 38:
				continue
			var column := mini(floori(float(x) / cell.x), columns - 1)
			var local_x := float(x) - float(column) * cell.x
			minimum.x = minf(minimum.x, local_x)
			minimum.y = minf(minimum.y, float(y))
			maximum.x = maxf(maximum.x, minf(cell.x, local_x + 1.0))
			maximum.y = maxf(maximum.y, minf(cell.y, float(y) + 1.0))
			found = true
	if found:
		bounds = Rect2(minimum, maximum - minimum)
	return {"bounds": bounds, "common_foot": bounds.end.y, "cell": cell}


func _process(delta: float) -> void:
	if _vs_active and _page == "vs" and is_visible_in_tree():
		_vs_elapsed += delta
		if _vs_elapsed >= VS_SECONDS:
			_finish_vs()
	_ui_time += delta
	_entry_time += delta
	_beat_time = _music_time()
	if is_instance_valid(_screen):
		_screen.modulate.a = 1.0 if _reduced_motion() else clampf(_entry_time / Summer.PAGE_SECONDS, 0.0, 1.0)
	if is_instance_valid(_home_performer):
		_home_performer.clock = _beat_time
		_home_performer.reduced_motion = _reduced_motion()
		# A four-beat character gag belongs to actual idle time, not a timer that
		# keeps interrupting someone who is choosing a mode or changing settings.
		if _page == "home" and is_visible_in_tree() and not _confirm_busy and not _reduced_motion():
			_home_idle_seconds += delta
			if _home_idle_seconds >= HOME_EASTER_IDLE_SECONDS and _home_performer.performance_state == "loop":
				var cast: Array = HOME_EASTER_CAST.duplicate()
				for staged_id: String in Data.STAGED_V034_IDS:
					if staged_id in _ids: cast.append(staged_id)
				_home_performer.react("easter", HOME_EASTER_DURATION, cast[_home_easter_index%cast.size()])
				_home_easter_index = (_home_easter_index + 1) % cast.size()
				_home_idle_seconds = 0.0
	for actor: Control in _hd_performers:
		if is_instance_valid(actor):
			actor.clock_override = _beat_time
			actor.reduced_motion = _reduced_motion()
	if _stick_axis.length() > 0.55:
		_stick_repeat -= delta
		if _stick_repeat <= 0.0:
			_navigate(Vector2i(signi(_stick_axis.x), 0) if absf(_stick_axis.x) > absf(_stick_axis.y) else Vector2i(0, signi(_stick_axis.y)))
			_stick_repeat = 0.18


func _reduced_motion() -> bool:
	return bool(_settings.get("reduced_motion", false))


func _music_time() -> float:
	var audio := get_node_or_null("/root/GameAudio")
	if audio != null:
		var music: Variant = audio.get("music")
		if music is AudioStreamPlayer and music.playing:
			return maxf(0.0, music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())
	return _ui_time


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _page == "home":
		var intent: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventMouseMotion and event.relative.length_squared() >= 4.0) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.55)
		if intent: _home_interaction()
	if _binding_player >= 0:
		if event is InputEventKey and event.pressed and not event.echo:
			var code := int(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
			if code == KEY_ESCAPE:
				_binding_player = -1
				_binding_action = -1
				_binding_message = "変更を取り消しました。"
				show_controls()
			else:
				_commit_binding(_binding_player, _binding_action, code)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		if event.axis == JOY_AXIS_LEFT_X:
			_stick_axis.x = event.axis_value
		else:
			_stick_axis.y = event.axis_value
		if _stick_axis.length() > 0.55 and _stick_repeat <= 0.0:
			_navigate(Vector2i(signi(_stick_axis.x), 0) if absf(_stick_axis.x) > absf(_stick_axis.y) else Vector2i(0, signi(_stick_axis.y)))
			_stick_repeat = 0.32
		elif _stick_axis.length() < 0.35:
			_stick_repeat = 0.0
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey or event is InputEventJoypadButton) or not event.is_pressed():
		return
	if _confirm_busy:
		get_viewport().set_input_as_handled()
		return
	if _page == "vs":
		if event.is_echo(): return
		var vs_button: int = event.button_index if event is InputEventJoypadButton else -1
		if event.is_action_pressed("ui_cancel") or vs_button == JOY_BUTTON_B:
			_cancel_vs()
		elif event.is_action_pressed("ui_accept") or vs_button == JOY_BUTTON_A:
			_finish_vs()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_F1 and not event.echo:
		show_guide()
		get_viewport().set_input_as_handled()
		return
	var joy_button: int = event.button_index if event is InputEventJoypadButton else -1
	if event.is_action_pressed("ui_cancel") or joy_button == JOY_BUTTON_B:
		if _page == "select" and (_p1_locked or _p2_locked):
			_reselect_p1()
		elif _page == "guide":
			_guide_back()
		elif _page == "controls":
			show_settings()
		elif _page == "settings":
			_settings_back()
		elif _page != "home":
			show_home()
		get_viewport().set_input_as_handled()
		return
	if _page == "select" and _mode == "local" and event is InputEventKey and not event.echo and _local_selection_key(event):
		get_viewport().set_input_as_handled()
		return
	var direction := Vector2i.ZERO
	if event.is_action_pressed("ui_left") or joy_button == JOY_BUTTON_DPAD_LEFT:
		direction.x = -1
	elif event.is_action_pressed("ui_right") or joy_button == JOY_BUTTON_DPAD_RIGHT:
		direction.x = 1
	elif event.is_action_pressed("ui_up") or joy_button == JOY_BUTTON_DPAD_UP:
		direction.y = -1
	elif event.is_action_pressed("ui_down") or joy_button == JOY_BUTTON_DPAD_DOWN:
		direction.y = 1
	if direction != Vector2i.ZERO:
		_navigate(direction)
		get_viewport().set_input_as_handled()
		return
	if (event.is_action_pressed("ui_accept") or joy_button == JOY_BUTTON_A) and not event.is_echo():
		var focus := get_viewport().gui_get_focus_owner()
		if focus is Button and not focus.disabled:
			if _page == "select" and _card_buttons.has(focus) and _p1_locked and _p2_locked:
				_confirm_action(focus, _start_match)
			else:
				if focus.toggle_mode:
					focus.button_pressed = not focus.button_pressed
				focus.pressed.emit()
		get_viewport().set_input_as_handled()


func _navigate(direction: Vector2i, player: int = -1) -> void:
	if _confirm_busy:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if _page == "select" and (player >= 0 or focus == null or _card_buttons.has(focus)):
		if player >= 0:
			_active_index = _ids.find(_p1 if player == 0 else _p2)
		elif _card_buttons.has(focus):
			_active_index = _card_buttons.find(focus)
		if direction == Vector2i.RIGHT and _active_index == _ids.size()-1 and is_instance_valid(_random_button):
			_random_button.grab_focus()
			return
		if direction == Vector2i.DOWN and _active_index >= _selection_columns() and not _selection_aux.is_empty():
			_selection_aux[0].grab_focus()
			return
		var next_index := _grid_neighbor(_active_index, direction)
		if _select_flow.preview(_ids[next_index], player if player >= 0 else (1 if _p1_locked else 0), true):
			_sync_select_flow()
			_active_index = next_index
			_build_select()
			_react_selection_actor(_ids[next_index], "invite", 0.32, player if player >= 0 else (1 if _p1_locked else 0))
		return
	if focus is HSlider and direction.x != 0:
		focus.value = clampf(focus.value + direction.x * focus.step, focus.min_value, focus.max_value)
		return
	if focus is Control:
		var side := SIDE_LEFT if direction.x < 0 else SIDE_RIGHT if direction.x > 0 else SIDE_TOP if direction.y < 0 else SIDE_BOTTOM
		var next := focus.find_valid_focus_neighbor(side)
		if next != null:
			if _page == "select" and _card_buttons.has(next):
				var next_index := _card_buttons.find(next)
				if _select_flow.preview(_ids[next_index], 1 if _p1_locked else 0, true):
					_sync_select_flow()
					_active_index = next_index
					_build_select()
					_react_selection_actor(_ids[next_index], "invite", 0.32, 1 if _p1_locked else 0)
			else:
				next.grab_focus()


func _grid_neighbor(index: int, direction: Vector2i) -> int:
	return BVNSelectFlow.grid_neighbor(index, direction, _ids.size(), _selection_columns())

func _selection_columns() -> int:
	return 4 if _ids.size()>5 else 3

func _selection_card_rect(index: int) -> Rect2:
	var width: float = 94.0 if _ids.size()>5 else 126.0
	var stride: float = 102.0 if _ids.size()>5 else 137.0
	var columns: int = _selection_columns()
	return Rect2(440+(index%columns)*stride,188+(index/columns)*156,width,144)


func _local_selection_key(event: InputEventKey) -> bool:
	var code := int(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	for player: int in range(2):
		var keys: Array = _settings["bindings_p1" if player == 0 else "bindings_p2"]
		if not bool(_select_flow.enabled[player]):
			continue
		var directions := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
		for index: int in range(4):
			if code == int(keys[index]):
				_navigate(directions[index], player)
				return true
		if code == int(keys[4]):
			_begin_character_confirmation(_p1 if player == 0 else _p2, null, player)
			return true
	return false


func _new_screen(page: String) -> void:
	var previous_page := _page
	if previous_page == "vs" and page != "vs" and _vs_active:
		_vs_active = false
		vs_cancelled.emit()
	if _page == "select" and page != "select":
		_select_flow.cancel_pending()
		_sync_select_flow()
	var page_changed := page != _page or not is_instance_valid(_screen)
	_page = page
	if page_changed:
		_entry_time = 0.0
	_load_animation_resources()
	_home_logo = null
	_home_performer = null
	_hd_performers.clear()
	_home_buttons.clear()
	_last_home_focus = -1
	_home_idle_seconds = 0.0
	_confirm_busy = false
	if page_changed:
		_stick_axis = Vector2.ZERO
		_stick_repeat = 0.0
	if _pending_tween != null and _pending_tween.is_valid():
		_pending_tween.kill()
	_pending_tween = null
	if is_instance_valid(_screen):
		remove_child(_screen)
		_screen.queue_free()
	_screen = Control.new()
	_screen.name = "JapaneseUI"
	_screen.modulate.a = 1.0 if _reduced_motion() else clampf(_entry_time / Summer.PAGE_SECONDS, 0.0, 1.0)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)
	_card_buttons.clear()
	_random_button = null
	_selection_aux.clear()
	_start_button = null
	material = null
	if page_changed and not _reduced_motion():
		var wipe := SummerWipe.new()
		wipe.name = "SummerPageWipe"
		wipe.size = Vector2(1280, 720)
		wipe.reverse = page == "home" and previous_page != "home"
		wipe.z_index = Summer.LAYER_TRANSITION
		wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_screen.add_child(wipe)
	queue_redraw()


func show_home() -> void:
	if _battle_page_active:
		_close_battle_page()
		return
	if not _ready_done:
		return
	_new_screen("home")
	_home_performer = PartyHDCanvas.new()
	_home_performer.name = "IllustratedPoolParty"
	_home_performer.master_art = _art
	_home_performer.motion_metadata = _hd_motion
	_home_performer.rig_script = _hd_rig
	_home_performer.size = Vector2(1280, 720)
	_home_performer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_performer.reduced_motion = _reduced_motion()
	_home_performer.clock = _music_time()
	_screen.add_child(_home_performer)
	_home_logo = Control.new()
	_home_logo.name = "SummerLogo"
	_home_logo.position = Vector2(30, 24)
	_home_logo.size = Vector2(442, 254)
	_home_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_home_logo)
	var logo_path := "res://assets/art/visual_v18/title_logo.png"
	if ResourceLoader.exists(logo_path):
		var title := TextureRect.new()
		title.name = "LogoTexture"
		title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title.texture = load(logo_path)
		title.size = Vector2(430, 215)
		title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_home_logo.add_child(title)
	else:
		_label("ミーム", Rect2(0, 0, 433, 92), 72, INK, HORIZONTAL_ALIGNMENT_LEFT, _home_logo)
		_label("大乱闘", Rect2(-3, 72, 437, 122), 94, INK, HORIZONTAL_ALIGNMENT_LEFT, _home_logo)
	_label("夏だ！ 海だ！ ミームで勝負。", Rect2(5, 226, 419, 28), 19, INK, HORIZONTAL_ALIGNMENT_LEFT, _home_logo)
	_label("サマー・ファイト・パーティー", Rect2(927, 22, 307, 30), 17, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var menu := ["対戦スタート", "ローカル対戦", "トレーニング", "設定", "終了"]
	var subtitles := ["CPU と腕試し", "ふたりで対戦", "技と間合いを練習", "音量・演出・キー設定", "また海で会おう"]
	var actions: Array[Callable] = [func(): show_select("cpu"), func(): show_select("local"), func(): show_select("training"), show_settings, func(): quit_requested.emit()]
	for index: int in range(menu.size()):
		var rect := Rect2(39 - index * 3, 295 + index * 72, 398 - index * 13, 66 if index == 0 else 59)
		var button := _button(menu[index], rect, actions[index], 29 if index == 0 else 25, YELLOW if index == 0 else PAPER) as SummerButton
		button.name = "HomeMenu_%d" % index
		button.visual.number = index + 1
		button.visual.subtitle = subtitles[index]
		button.visual.kind = ["start", "local", "training", "settings", "return"][index]
		button.visual.primary = index == 0
		button.visual.compact = false
		button.visual.font_size = 29 if index == 0 else 25
		button.visual.menu_mode = true
		button.mouse_entered.connect(_home_focus.bind(index))
		button.focus_entered.connect(_home_focus.bind(index))
		_home_buttons.append(button)
	_link_vertical_focus(_home_buttons)
	_home_buttons[0].grab_focus()
	_footer("↑ ↓ 選択   Enter / A 決定   F1 遊び方", "%d人のミーム、ひと夏の勝負。  v%s" % [_ids.size(), Data.VERSION])

func _home_focus(index: int) -> void:
	_home_interaction()
	if _last_home_focus == index or _confirm_busy:
		return
	_last_home_focus = index
	if is_instance_valid(_home_performer):
		_home_performer.react("invite" if index == 0 else "menu", 0.32 if not _reduced_motion() else 0.18)


func _home_interaction() -> void:
	_home_idle_seconds = 0.0
	if is_instance_valid(_home_performer):
		_home_performer.cancel_idle_gag()


func get_home_buttons() -> Array[Button]:
	return _home_buttons


func get_home_performer_state() -> Dictionary:
	if not is_instance_valid(_home_performer):
		return {}
	var performers := _home_performer.get_performer_states()
	var joints := 0
	var rig_count := 0
	for state: Dictionary in performers:
		joints += int(state.get("joint_count", 0))
		rig_count += int(bool(state.get("uses_hd_rig", false)))
	return {"state": _home_performer.performance_state, "frame": _home_performer.frame_index, "rhythmic": _home_performer.rhythmic, "reduced_motion": _reduced_motion(), "music_seconds": _music_time(), "representation": "hd_illustration_party", "motion_mode": "multi_joint_pose_animation" if rig_count == _ids.size() else "localized_illustration_animation", "joint_count": joints, "rig_count": rig_count, "motion_zone_count": _home_performer.motion_zone_count, "performers": performers}


func get_fullbody_performer_states() -> Array:
	var states: Array = []
	for actor: Control in _hd_performers:
		if is_instance_valid(actor) and actor.has_method("get_pose_state"):
			states.append(actor.call("get_pose_state"))
	return states


func debug_home_feedback(index: int, pressed: bool = false) -> void:
	if _page != "home" or index < 0 or index >= _home_buttons.size():
		return
	_home_buttons[index].grab_focus()
	if pressed:
		_home_buttons[index].pressed.emit()


func _confirm_action(button: Button, action: Callable) -> void:
	if _confirm_busy or button.disabled:
		return
	# VS has an automatic deadline: a return click must cancel immediately,
	# including during the last confirmation-animation interval.
	if _page == "vs":
		_click_sound()
		if button is SummerButton: button.confirm()
		if action.is_valid(): action.call()
		return
	if _page == "home": _home_interaction()
	if _page == "select" and button.has_meta("bvn_character") and action.get_method() != "_start_match":
		var id := str(button.get_meta("bvn_character"))
		_begin_character_confirmation(str(_ids.pick_random()) if id == "__random__" else id, button)
		return
	_click_sound()
	if button is SummerButton:
		button.confirm()
	if not action.is_valid():
		return
	_confirm_busy = true
	if _page == "home" and is_instance_valid(_home_performer):
		_home_performer.react("confirm", Summer.CONFIRM_SECONDS)
	_pending_tween = _screen.create_tween()
	_pending_tween.tween_interval(Summer.CONFIRM_SECONDS)
	_pending_tween.tween_callback(func():
		_confirm_busy = false
		if action.is_valid():
			action.call()
	)


func show_select(mode: String = "cpu") -> void:
	if _battle_page_active:
		_close_battle_page()
		return
	if not _ready_done:
		return
	_mode = mode
	_select_flow.reset(mode, _ids, _p1, _p2)
	_sync_select_flow()
	_active_index = _ids.find(_p1)
	_build_select()


func _build_select() -> void:
	_new_screen("select")
	var poster := SelectionTargetCanvas.new()
	poster.name = "CharacterSelectIllustration"
	poster.size = Vector2(1280, 720)
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(poster)
	var mode_label := {"cpu": "CPU 対戦", "local": "ローカル対戦", "training": "トレーニング"}
	_label("キャラクター選択", Rect2(269, 24, 742, 67), 47, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_label(str(mode_label.get(_mode, "CPU 対戦")), Rect2(955, 34, 285, 32), 19, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	var instruction := "P1 のキャラクターを選ぼう"
	if _p1_locked:
		instruction = "対戦相手を選ぼう" if _mode != "local" else "P2 のキャラクターを選ぼう"
	if _p1_locked and _p2_locked:
		instruction = "準備完了！ 対戦スタート"
	_label(instruction, Rect2(365, 126, 550, 35), 22, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_build_character_panel(_p1, true)
	_build_character_panel(_p2, false)
	for index: int in range(_ids.size()):
		var id: String = _ids[index]
		var info: Dictionary = _roster[id]
		var card_rect: Rect2 = _selection_card_rect(index)
		var card := _button("", card_rect, _choose_character.bind(id), 23, PAPER)
		card.set_meta("bvn_character", id)
		card.mouse_entered.connect(_hover_character.bind(id))
		card.tooltip_text = str(info.get("subtitle", "")) + "\n" + str(info.get("description", ""))
		card.set_meta("selected", index == _active_index)
		card.visual.kind = "character"
		card.visual.accent = RED if _select_flow.active_player == 0 else BLUE
		_portrait(id, Rect2(5,4,card_rect.size.x-10,106), card, false, false, true)
		_label(str(info.get("name", id)), Rect2(3,111,card_rect.size.x-6,29), 13 if _ids.size()>5 else 16, PAPER, HORIZONTAL_ALIGNMENT_CENTER, card)
		if _p1_locked and _p1 == id:
			_marker("P1", Rect2(3, 5, 35, 23), RED, card)
		if _p2_locked and _p2 == id:
			_marker("P2" if _mode == "local" else "CPU", Rect2(card_rect.size.x-44,5,41,23), BLUE, card)
		_card_buttons.append(card)
	var random_rect: Rect2 = _selection_card_rect(_ids.size())
	var random_button := _button("ランダム", random_rect, func(): _choose_character(str(_ids.pick_random())), 16 if _ids.size()>5 else 19, YELLOW)
	random_button.set_meta("bvn_character", "__random__")
	random_button.visual.kind = "random"
	random_button.name = "RandomCharacterButton"
	_random_button = random_button
	random_button.tooltip_text = "五人からおまかせで選びます。" if _ids.size()==5 else "%d人からおまかせで選びます。" % _ids.size()
	_label("？", Rect2(8,8,random_rect.size.x-16,59), 48, INK, HORIZONTAL_ALIGNMENT_CENTER, random_button)
	_label("おまかせ", Rect2(8,112,random_rect.size.x-16,23), 12 if _ids.size()>5 else 14, INK, HORIZONTAL_ALIGNMENT_CENTER, random_button)
	_card_buttons[_active_index].grab_focus()
	if _mode == "cpu":
		_label("CPU の強さ", Rect2(448, 494, 384, 23), 17, INK, HORIZONTAL_ALIGNMENT_CENTER)
		_add_difficulty_buttons(Vector2(440, 521), 126, 11, 16)
	elif _mode == "training":
		var recipe: Dictionary = Data.TRAINING_RECIPES.get(_training_recipe, Data.TRAINING_RECIPES["normal_chain"])
		var sparring := _training_recipe == "sparring"
		var recipe_caption := "実戦練習 ›" if sparring else "練習：" + str(recipe["name"]) + "  ›"
		var recipe_button := _button(recipe_caption, Rect2(440, 495, 110 if sparring else 400, 34), _cycle_training_recipe, 15 if sparring else 19, PAPER)
		recipe_button.name = "TrainingRecipeButton"
		recipe_button.tooltip_text = _recipe_input(_training_recipe) + "\n" + str(recipe["hint"])
		_selection_aux.append(recipe_button)
		if sparring:
			_add_difficulty_buttons(Vector2(556, 495), 90, 5, 15)
		var summary := "気と体力は実戦と同じ。\nRリセット／KOで再開。" if sparring else "3段の命中を練習。Tでガード切替。\n気・体力は満タン。"
		if _training_recipe == "air_chain":
			summary = "跳ぶ → 空中攻撃 → 空中技。\n命中・コンボの保証はありません。"
		elif _training_recipe == "full_normal":
			summary = "全%d段の命中を練習。Tでガード切替。\n開始時は気300。以後は実戦と同じ。" % int(_training_descriptor(_training_recipe).get("total", 3))
		elif _training_recipe == "hit_confirm":
			summary = "キャラ別の命中派生。Tでガード切替。\n開始時は気300。以後は実戦と同じ。"
		var training_summary := _label(summary, Rect2(443, 533, 394, 51), 14, INK, HORIZONTAL_ALIGNMENT_CENTER)
		training_summary.name = "TrainingSummary"
	else:
		_label("同じキャラクターでも対戦できます。", Rect2(442, 511, 395, 42), 18, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var start_button := _button("対戦開始", Rect2(440, 589, 400, 53), _start_match, 29, YELLOW)
	start_button.name = "BattleStartButton"
	start_button.disabled = not _select_flow.is_ready()
	_start_button = start_button
	_label("Enter / A：決定   Tab：項目移動", Rect2(443, 646, 394, 24), 14, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var guide_button := _button("操作・技ガイド", Rect2(475, 680, 237, 30), show_guide, 17, PAPER)
	guide_button.name = "SelectionGuideButton"
	var back_button := _button("ホームへ", Rect2(26, 679, 153, 31), show_home, 18, PAPER)
	if _selection_aux.is_empty():
		_selection_aux.append(start_button if not start_button.disabled else back_button)
	_selection_aux.append(back_button)
	_selection_aux.append(guide_button)
	if _p1_locked:
		_button("P1 を選び直す", Rect2(192, 679, 218, 31), _reselect_p1, 18, YELLOW)
	_wire_selection_focus(back_button)
	_label("← ↑ ↓ → 選択   Esc / B 戻る", Rect2(855, 680, 394, 27), 16, INK, HORIZONTAL_ALIGNMENT_RIGHT)

func _add_difficulty_buttons(origin: Vector2, width: float = 140.0, gap: float = 9.0, font_size: int = 17) -> void:
	var difficulty_ids := ["easy", "normal", "hard"]
	var difficulty_labels := ["かんたん", "ふつう", "むずかしい"]
	for index: int in range(difficulty_ids.size()):
		var value: String = difficulty_ids[index]
		var button := _button(difficulty_labels[index], Rect2(origin + Vector2(index * (width + gap), 0), Vector2(width, 36)), _select_difficulty.bind(value), font_size, YELLOW if _difficulty == value else PAPER)
		button.name = "Difficulty" + value.capitalize()
		button.set_meta("difficulty", value)
		button.set_meta("selected", _difficulty == value)
		button.visual.kind = "difficulty"
		_selection_aux.append(button)


func _select_difficulty(value: String) -> void:
	if value not in ["easy", "normal", "hard"]:
		return
	_difficulty = value
	_build_select()
	for button: Button in _selection_aux:
		if str(button.get_meta("difficulty", "")) == value:
			button.grab_focus()
			break


func _wire_selection_focus(back_button: Button) -> void:
	for index: int in range(_card_buttons.size()):
		var card := _card_buttons[index]
		card.focus_neighbor_left = card.get_path_to(_card_buttons[_grid_neighbor(index, Vector2i.LEFT)])
		card.focus_neighbor_right = card.get_path_to(_card_buttons[_grid_neighbor(index, Vector2i.RIGHT)])
		card.focus_neighbor_top = card.get_path_to(_card_buttons[_grid_neighbor(index, Vector2i.UP)])
		card.focus_neighbor_bottom = card.get_path_to(_card_buttons[_grid_neighbor(index, Vector2i.DOWN)])
	var last_index: int = _card_buttons.size()-1
	_card_buttons[last_index].focus_neighbor_right = _card_buttons[last_index].get_path_to(_random_button)
	_random_button.focus_neighbor_left = _random_button.get_path_to(_card_buttons[last_index])
	_random_button.focus_neighbor_top = _random_button.get_path_to(_card_buttons[_selection_columns()-1])
	_random_button.focus_neighbor_bottom = _random_button.get_path_to(_selection_aux[0])
	for index: int in range(_selection_aux.size()):
		var button := _selection_aux[index]
		button.focus_neighbor_top = button.get_path_to(_card_buttons[_selection_columns() if index==0 else last_index])
		button.focus_neighbor_left = button.get_path_to(_selection_aux[posmod(index - 1, _selection_aux.size())])
		button.focus_neighbor_right = button.get_path_to(_selection_aux[(index + 1) % _selection_aux.size()])
		button.focus_neighbor_bottom = button.get_path_to(_start_button if not _start_button.disabled and button != _start_button else back_button)
	_start_button.focus_neighbor_top = _start_button.get_path_to(_selection_aux[0])
	_start_button.focus_neighbor_bottom = _start_button.get_path_to(back_button)
	back_button.focus_neighbor_top = back_button.get_path_to(_start_button if not _start_button.disabled else _selection_aux[0])
	back_button.focus_neighbor_bottom = back_button.get_path_to(_card_buttons[0])


func _build_character_panel(id: String, left: bool) -> void:
	var info: Dictionary = _roster[id]
	var panel_x := 12.0 if left else 852.0
	var accent := RED if left else BLUE
	var side_name := "P1" if left else ("P2" if _mode == "local" else "CPU")
	_marker(side_name, Rect2(panel_x + (20 if left else 327), 116, 69, 36), accent)
	var portrait := _portrait(id, Rect2(panel_x, 105, 416, 443), null, id == "rio", true)
	portrait.set_meta("selection_side", "p1" if left else "p2")
	portrait.set_meta("portrait_slot", Rect2(panel_x, 105, 416, 443))
	_label(str(info.get("name", id)), Rect2(panel_x + 12, 547, 316, 39), 27, PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	var advice: Dictionary = CHARACTER_ADVICE.get(id, {})
	var kit: Label = _selection_info_line(str(advice.get("type", "")) + "  /  " + str(advice.get("difficulty", "")), Rect2(panel_x + 14, 588, 313, 27), 16)
	kit.name = "SelectionAdvice_" + ("p1" if left else "p2")
	var inputs: String = _training_input_caption("full_normal", id, 313, 15)
	var route: Label = _selection_info_line("基本連携：" + inputs, Rect2(panel_x + 14, 616, 313, 27), 15)
	route.name = "SelectionRoute_" + ("p1" if left else "p2")
	route.tooltip_text = "命中と連携許可を見て押し直す。距離・防御で結果は変わります。"
	_label("命中を見て押し直す", Rect2(panel_x + 14, 646, 313, 21), 13, INK, HORIZONTAL_ALIGNMENT_CENTER)
	# A small, explicitly separate playable pose keeps HD selection art distinct
	# from the in-match pixel actor without obscuring the full-body illustration.
	_pixel_preview(id, Rect2(panel_x + 343, 589, 66, 76))


func _selection_info_line(text: String, rect: Rect2, requested_size: int) -> Label:
	var fitted: int = requested_size
	while fitted > 13 and ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > rect.size.x:
		fitted -= 1
	var line: Label = _label(text, rect, fitted, PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.size = rect.size
	line.tooltip_text = text
	return line


func _sync_select_flow() -> void:
	if _select_flow.roster.is_empty():
		return
	var state: Dictionary = _select_flow.snapshot()
	_p1 = str(state.p1)
	_p2 = str(state.p2)
	_p1_locked = bool(state.p1_locked)
	_p2_locked = bool(state.p2_locked)
	if is_instance_valid(_start_button):
		_start_button.disabled = not bool(state.ready)


func get_select_flow_state() -> Dictionary:
	return _select_flow.snapshot()


func _hover_character(id: String) -> void:
	if _confirm_busy or _page != "select":
		return
	var player := _select_flow.pointer_player()
	if player < 0 or _select_flow.selected[player] == id:
		return
	if _select_flow.preview(id, player):
		_sync_select_flow()
		_active_index = _ids.find(id)
		_build_select()
		_react_selection_actor(id, "invite", 0.32, player)


func _react_selection_actor(id: String, kind: String, duration: float, player: int = -1) -> void:
	for portrait in _screen.find_children("*_HDPortrait", "", true, false):
		if str(portrait.get_meta("character_id", "")) != id or bool(portrait.get_meta("face_only", false)) or not portrait.has_method("react"):
			continue
		if player >= 0 and portrait.has_meta("selection_side") and str(portrait.get_meta("selection_side")) != ("p1" if player == 0 else "p2"):
			continue
		portrait.call("react", kind, duration)


func _reselect_p1() -> void:
	_select_flow.cancel_selection()
	_sync_select_flow()
	_active_index = _ids.find(_p1)
	_build_select()


func _begin_character_confirmation(id: String, button: Button = null, player: int = -1) -> void:
	if _confirm_busy:
		return
	if _select_flow.is_ready():
		_select_flow.preview(id, 1, true)
	var ticket: Dictionary = _select_flow.begin_confirmation(id, player)
	if ticket.is_empty():
		return
	_sync_select_flow()
	_confirm_busy = true
	_click_sound()
	if button is SummerButton:
		button.confirm()
	# This is the Godot counterpart to SelecterItemUI's 'select' MovieClip and
	# addFrameScript callback, not a claimed import of its Flash animation art.
	_react_selection_actor(id, "confirm", Summer.CONFIRM_SECONDS, int(ticket.player))
	_pending_tween = _screen.create_tween()
	_pending_tween.tween_interval(Summer.CONFIRM_SECONDS)
	_pending_tween.tween_callback(func():
		_confirm_busy = false
		if _select_flow.complete_confirmation(ticket):
			_sync_select_flow()
			_active_index = _ids.find(_select_flow.selected[_select_flow.active_player])
			_build_select()
	)


func _choose_character(id: String) -> void:
	# Existing preview/test callers complete synchronously. Real mouse/key/pad
	# confirmation uses _begin_character_confirmation and acknowledges its animation.
	if _select_flow.is_ready():
		_select_flow.preview(id, 1, true)
	var ticket: Dictionary = _select_flow.begin_confirmation(id)
	if ticket.is_empty() or not _select_flow.complete_confirmation(ticket):
		return
	_sync_select_flow()
	_active_index = _ids.find(_select_flow.selected[_select_flow.active_player])
	_build_select()


func _start_match() -> void:
	var selected: Dictionary = _select_flow.consume_start()
	if selected.is_empty():
		return
	_p1 = str(selected.p1)
	_p2 = str(selected.p2)
	_last_match = {"p1": _p1, "p2": _p2, "mode": _mode, "difficulty": _difficulty, "recipe": _training_recipe}
	if _mode == "training":
		training_recipe_requested.emit(_training_recipe)
	start_requested.emit(_p1, _p2, _mode, _difficulty)


func show_vs(p1_id: String, p2_id: String, mode: String, difficulty: String) -> void:
	if not _ready_done: return
	_new_screen("vs")
	_p1 = p1_id
	_p2 = p2_id
	_mode = mode
	_difficulty = difficulty
	_vs_active = true
	_vs_elapsed = 0.0
	_label("次の対戦", Rect2(57, 21, 610, 64), 44, PAPER)
	_label("VS", Rect2(500, 240, 280, 132), 108, INK, HORIZONTAL_ALIGNMENT_CENTER)
	for side: int in range(2):
		var id: String = p1_id if side == 0 else p2_id
		var x: float = 50.0 if side == 0 else 820.0
		_marker("1P" if side == 0 else ("2P" if mode == "local" else "CPU"), Rect2(x + 126, 117, 118, 34), RED if side == 0 else BLUE)
		_portrait(id, Rect2(x, 151, 410, 374), null, id == "rio", true)
		_label(str(_roster[id].get("name", id)), Rect2(x, 534, 410, 42), 30, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var mode_name: String = str({"cpu":"CPU 対戦", "local":"ローカル対戦", "training":"トレーニング"}.get(mode, mode))
	var level: String = str({"easy":"かんたん", "normal":"ふつう", "hard":"むずかしい"}.get(difficulty, difficulty))
	_label(mode_name + (" / " + level if mode == "cpu" else ""), Rect2(461, 392, 358, 37), 21, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_label("プールサイド", Rect2(461, 434, 358, 30), 18, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var start: Button = _button("今すぐ対戦", Rect2(434, 588, 412, 55), _finish_vs, 28, YELLOW)
	start.name = "VSSkipButton"
	var back: Button = _button("選択へ戻る", Rect2(65, 619, 277, 44), _cancel_vs, 23, PAPER)
	back.name = "VSCancelButton"
	start.focus_neighbor_left = start.get_path_to(back)
	back.focus_neighbor_right = back.get_path_to(start)
	start.grab_focus()
	_footer("Enter / A：スキップ    Esc / B：選択へ", "まもなく対戦開始")


func _finish_vs() -> void:
	if not _vs_active or _page != "vs": return
	_vs_active = false
	vs_start_requested.emit()


func _cancel_vs() -> void:
	if not _vs_active or _page != "vs": return
	_vs_active = false
	vs_cancelled.emit()
	show_select(_mode)


func show_battle_page(page: String, p1_id: String, p2_id: String) -> void:
	if page not in ["skills", "settings"] or not _ready_done: return
	_battle_page_active = true
	_p1 = p1_id
	_p2 = p2_id
	if page == "skills":
		show_guide(1)
	else:
		show_settings()


func _close_battle_page() -> void:
	if not _battle_page_active: return
	_battle_page_active = false
	_binding_player = -1
	_binding_action = -1
	_stick_axis = Vector2.ZERO
	_stick_repeat = 0.0
	battle_page_closed.emit()


func _settings_back() -> void:
	if _battle_page_active:
		_close_battle_page()
	else:
		show_home()


func clear_battle_page_context() -> void:
	_battle_page_active = false
	_binding_player = -1
	_binding_action = -1


func show_result(winner_name: String, summary: Dictionary = {}) -> void:
	if not _ready_done:
		return
	_new_screen("result")
	_label("対戦結果", Rect2(56, 30, 750, 69), 54, PAPER)
	var is_draw := winner_name.is_empty() or winner_name == "引き分け"
	_label("引き分け" if is_draw else "勝利！", Rect2(50, 115, 720, 114), 88, INK)
	if summary.is_empty():
		_label("引き分け" if is_draw else winner_name, Rect2(62, 240, 670, 100), 42, PAPER)
		_label("もう一戦？ 今日の主役はまだ決まっていない。", Rect2(66, 353, 630, 65), 24, PAPER)
	else:
		_label("引き分け" if is_draw else winner_name, Rect2(62, 235, 670, 47), 34, PAPER)
		_build_result_summary(summary)
	var winner_id := _p1
	for id: String in _ids:
		if str(_roster[id].get("name", "")) == winner_name:
			winner_id = id
	var winner_portrait := _portrait(winner_id, Rect2(769, 143, 396, 439))
	if RosterPortraitV034.supports(winner_id):
		winner_portrait.set_base_clip("win")
	if winner_portrait is HDRigPortrait:
		# The result has room for the blade outside its paper frame, clear of buttons.
		winner_portrait.clip_contents = false
		winner_portrait.set_base_clip("dance")
		winner_portrait.react("celebrate", 0.65)
	_pixel_preview(winner_id, Rect2(1116, 515, 124, 139), "dance")
	var buttons: Array[Button] = []
	buttons.append(_button("再戦", Rect2(67, 446, 432, 63), _rematch, 30, YELLOW))
	buttons.append(_button("キャラクター選択", Rect2(67, 525, 432, 61), func(): show_select(_mode), 26, PAPER))
	buttons.append(_button("ホームへ", Rect2(67, 602, 432, 55), show_home, 25, PAPER))
	_link_vertical_focus(buttons)
	buttons[0].disabled = _last_match.is_empty()
	buttons[0].grab_focus()
	_footer("↑ ↓ 選択    Enter 決定    Esc ホームへ", "次のミームに備えよう。")


func _build_result_summary(summary: Dictionary) -> void:
	var wins: Array = summary.get("wins", [])
	var score: String = "%d — %d" % [int(wins[0]), int(wins[1])] if wins.size() == 2 else "—"
	var duration: int = maxi(0, floori(float(summary.get("elapsed", 0.0))))
	var headline: Label = _label("%s    %dラウンド / %d:%02d" % [score, int(summary.get("rounds", 0)), duration / 60, duration % 60], Rect2(66, 284, 663, 32), 22, YELLOW)
	headline.name = "ResultMatchSummary"
	var players: Array = summary.get("players", [])
	for side: int in range(mini(2, players.size())):
		var player: Dictionary = players[side]
		var x: float = 67.0 + side * 335.0
		var id: String = str(player.get("id", ""))
		var name_text: String = str(_roster.get(id, {}).get("name", id))
		_label(("1P " if side == 0 else ("2P " if _last_match.get("mode", _mode) == "local" else "CPU ")) + name_text, Rect2(x, 321, 322, 27), 18, PAPER)
		for index: int in range(3):
			var values: Array[String] = ["与ダメ %d / 被ダメ %d" % [int(player.get("damage_dealt", 0)), int(player.get("damage_taken", 0))], "最大 %d連撃" % int(player.get("max_combo", 0)), "最大連撃ダメージ %d" % int(player.get("max_combo_damage", 0))]
			var entry: Label = _label(values[index], Rect2(x, 349 + index * 28, 322, 27), 17, PAPER)
			entry.name = "ResultStat_%d_%d" % [side, index]
	var finish: String = str(summary.get("finish_reason", summary.get("finish_kind", "")))
	var reason: Label = _label(str({"ko":"KO", "skill_ko":"必殺KO", "super_ko":"超必殺KO", "timeout":"時間切れ", "draw":"引き分け", "double_ko":"同時KO"}.get(finish, finish)), Rect2(508, 441, 215, 27), 17, PAPER, HORIZONTAL_ALIGNMENT_RIGHT)
	reason.name = "ResultFinishKind"


func _rematch() -> void:
	if _last_match.is_empty():
		return
	if _last_match.get("mode", "") == "training":
		training_recipe_requested.emit(str(_last_match.get("recipe", _training_recipe)))
	start_requested.emit(str(_last_match["p1"]), str(_last_match["p2"]), str(_last_match["mode"]), str(_last_match["difficulty"]))


func show_settings() -> void:
	if not _ready_done:
		return
	_new_screen("settings")
	_label("設定", Rect2(59, 32, 970, 64), 49, PAPER)
	_label("自分に合った遊び方で。", Rect2(67, 109, 610, 38), 25, MUTED)
	_label("変更は自動で保存されます。", Rect2(744, 117, 422, 28), 18, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_label("マスター音量", Rect2(123, 189, 391, 48), 28, INK)
	_volume_label = _label("%d %%" % roundi(float(_settings["volume"]) * 100.0), Rect2(1046, 194, 120, 40), 25, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	var slider := HSlider.new()
	slider.name = "VolumeSlider"
	slider.position = Vector2(588, 198)
	slider.size = Vector2(412, 34)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(_settings["volume"])
	slider.add_theme_stylebox_override("slider", _button_style(Summer.SEA, INK, 1))
	slider.add_theme_stylebox_override("grabber_area", _button_style(YELLOW, INK, 1))
	slider.add_theme_stylebox_override("grabber_area_highlight", _button_style(YELLOW, INK, 2))
	for icon_name: String in ["grabber", "grabber_highlight", "grabber_disabled"]:
		var thumb := GradientTexture2D.new()
		thumb.width = 18 if icon_name != "grabber_highlight" else 22
		thumb.height = 28
		thumb.gradient = Gradient.new()
		thumb.gradient.colors = PackedColorArray([MUTED if icon_name == "grabber_disabled" else INK, MUTED if icon_name == "grabber_disabled" else INK])
		slider.add_theme_icon_override(icon_name, thumb)
	var slider_focus := SliderFocusArt.new()
	slider_focus.name = "VolumeFocusRing"
	slider_focus.size = slider.size
	slider_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slider.add_child(slider_focus)
	slider.focus_entered.connect(slider_focus.queue_redraw)
	slider.focus_exited.connect(slider_focus.queue_redraw)
	slider.value_changed.connect(func(value: float): _volume_label.text = "%d %%" % roundi(value * 100.0); _set_setting("volume", value))
	_screen.add_child(slider)
	var rows := [
		["shake", "画面の振動", "強い攻撃のとき、画面を揺らします。"],
		["flash", "強い閃光", "大技のフラッシュ演出。オフでも技は使えます。"],
		["reduced_motion", "動きを抑える", "飾りと画面切り替えの動きを抑えます。"],
	]
	var controls: Array[Control] = [slider]
	for index: int in range(rows.size()):
		var y := 281.0 + index * 99.0
		_label(rows[index][1], Rect2(123, y, 660, 42), 28, INK)
		_label(rows[index][2], Rect2(126, y + 43, 710, 31), 17, MUTED)
		var toggle := _toggle(rows[index][0], Rect2(910, y + 2, 252, 55))
		toggle.name = "Setting_" + rows[index][0]
		controls.append(toggle)
	var back := _button("対戦へ戻る" if _battle_page_active else "ホームへ戻る", Rect2(122, 593, 349, 62), _settings_back, 26, YELLOW)
	back.name = "SettingsBackButton"
	controls.append(back)
	var key_settings := _button("キー設定", Rect2(495, 593, 307, 62), show_controls, 25, PAPER)
	key_settings.name = "KeySettingsButton"
	controls.append(key_settings)
	var guide := _button("操作・技ガイド", Rect2(826, 593, 337, 62), show_guide, 23, PAPER)
	guide.name = "SettingsGuideButton"
	controls.append(guide)
	for index: int in range(controls.size()):
		controls[index].focus_neighbor_top = controls[index].get_path_to(controls[posmod(index - 1, controls.size())])
		controls[index].focus_neighbor_bottom = controls[index].get_path_to(controls[(index + 1) % controls.size()])
	slider.grab_focus()
	_footer("↑ ↓ 項目   ← → 音量   Enter / A 切り替え   Esc / B 戻る", "音楽はそのまま、遊びやすく。")


func _toggle(setting_name: String, rect: Rect2) -> Button:
	var button := _button("オン" if bool(_settings[setting_name]) else "オフ", rect, Callable(), 28, PAPER)
	button.toggle_mode = true
	button.button_pressed = bool(_settings[setting_name])
	button.toggled.connect(func(enabled: bool): button.text = "オン" if enabled else "オフ"; _set_setting(setting_name, enabled))
	return button


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		for key: String in _settings:
			_settings[key] = config.get_value("settings", key, _settings[key])
	_settings["volume"] = clampf(float(_settings["volume"]), 0.0, 1.0)
	for key_name: String in ["bindings_p1", "bindings_p2"]:
		var defaults: Array = Data.DEFAULT_P1 if key_name == "bindings_p1" else Data.DEFAULT_P2
		if not _settings[key_name] is Array or _settings[key_name].size() != Data.CONTROL_ACTIONS.size():
			_settings[key_name] = defaults.duplicate()
	_apply_volume()
	settings_changed.emit(_settings.duplicate())


func _set_setting(key: String, value: Variant) -> void:
	_settings[key] = value
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	for setting_name: String in _settings:
		config.set_value("settings", setting_name, _settings[setting_name])
	config.save("user://settings.cfg")
	_apply_volume()
	for child in _screen.find_children("*", "", true, false) if is_instance_valid(_screen) else []:
		if child is SummerButton:
			child.reduced_motion = _reduced_motion()
		if child is AnimatedPortrait or child is PartyHDCanvas or child is HDPortrait or child is HDRigPortrait or child is PixelPreview or child is RosterPortraitV034:
			child.reduced_motion = _reduced_motion()
	settings_changed.emit(_settings.duplicate())


func _apply_volume() -> void:
	var volume := float(_settings["volume"])
	AudioServer.set_bus_mute(0, volume <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))


func get_settings() -> Dictionary:
	return _settings.duplicate()


func _content_parent(parent: Control) -> Control:
	return parent.visual if parent is SummerButton else parent


func _label(text: String, rect: Rect2, font_size: int = 24, color: Color = INK, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, parent: Control = null) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	(_content_parent(parent) if parent != null else _screen).add_child(label)
	return label


func _marker(text: String, rect: Rect2, color: Color, parent: Control = null) -> Control:
	var mark := PosterTag.new()
	mark.position = rect.position
	mark.size = rect.size
	mark.accent = color
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_content_parent(parent) if parent != null else _screen).add_child(mark)
	_label(text, Rect2(Vector2.ZERO, rect.size), 16, INK, HORIZONTAL_ALIGNMENT_CENTER, mark)
	return mark


func _keycap(text: String, rect: Rect2, font_size: int = 18, color: Color = YELLOW, parent: Control = null) -> Control:
	var cap := PosterTag.new()
	cap.position = rect.position
	cap.size = rect.size
	cap.accent = color
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_content_parent(parent) if parent != null else _screen).add_child(cap)
	_label(text, Rect2(3, 0, rect.size.x - 6, rect.size.y - 1), font_size, INK, HORIZONTAL_ALIGNMENT_CENTER, cap)
	return cap


func _button(text: String, rect: Rect2, action: Callable, font_size: int = 26, accent: Color = PAPER) -> Button:
	var button := SummerButton.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.reduced_motion = _reduced_motion()
	button.visual = SummerButtonArt.new()
	button.visual.size = rect.size
	button.visual.font_size = font_size
	button.visual.accent = accent
	button.visual.primary = accent == YELLOW
	button.visual.kind = "return" if "ホーム" in text or "戻る" in text else "generic"
	button.visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.visual.pivot_offset = rect.size * 0.5
	button.add_child(button.visual)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", font_size)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(key, Color.TRANSPARENT)
	for key: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(key, StyleBoxEmpty.new())
	button.pressed.connect(_confirm_action.bind(button, action))
	_screen.add_child(button)
	return button


func _click_sound() -> void:
	var audio := get_node_or_null("/root/GameAudio")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", "click")


func _button_style(background: Color, edge: Color, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_border_width_all(width)
	style.border_color = edge
	style.skew = Vector2(-0.06, 0)
	style.content_margin_left = 17.0
	style.content_margin_right = 17.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func _hd_rig_available(id: String) -> bool:
	if _hd_rig == null and ResourceLoader.exists("res://game/hd_character_rig.gd"):
		_hd_rig = load("res://game/hd_character_rig.gd")
	return _hd_rig != null and bool(_hd_rig.call("has_assets", id))


func _portrait(id: String, rect: Rect2, parent: Control = null, hero: bool = false, prefer_idle: bool = false, face_only: bool = false) -> Control:
	if RosterPortraitV034.supports(id):
		var registered: Control = RosterPortraitV034.new()
		registered.name = id+"_HDPortrait"
		registered.configure(id,"home" if _page=="home" else "selection",face_only)
		registered.position = rect.position
		registered.size = rect.size
		registered.reduced_motion = _reduced_motion()
		(_content_parent(parent) if parent!=null else _screen).add_child(registered)
		if not face_only: _hd_performers.append(registered)
		return registered
	if not face_only and _hd_rig_available(id):
		var actor := HDRigPortrait.new()
		actor.name = id + "_HDPortrait"
		actor.set_meta("character_id", id)
		actor.set_meta("face_only", false)
		actor.fighter_id = id
		actor.rig_script = _hd_rig
		actor.base_clip = "idle"
		actor.phase = float(_ids.find(id)) * 0.5 * 60.0 / MENU_BPM
		actor.clock_override = _music_time()
		actor.reduced_motion = _reduced_motion()
		actor.position = rect.position
		actor.size = rect.size
		actor.facing = 1
		actor.body_priority = hero and _page == "select"
		# Fit the complete pose union once. The heavy sword is part of Rio's
		# silhouette, including invitation and confirmation, not a cropped prop.
		(_content_parent(parent) if parent != null else _screen).add_child(actor)
		_hd_performers.append(actor)
		return actor
	if _modern_art:
		if not face_only:
			var master = HDPortrait.new()
			master.name = id + "_HDPortrait"
			master.set_meta("character_id",id)
			master.set_meta("face_only",false)
			var atlas: AtlasTexture = _art[id]
			var profile: Dictionary = _hd_motion.get("characters",{}).get(id,{}).duplicate(true)
			profile["amplitude_space"] = _hd_motion.get("amplitude_space","")
			master.configure(id,atlas.atlas,atlas.region,profile)
			master.position = rect.position
			master.size = rect.size
			master.phase = float(_ids.find(id)) * 0.375
			master.reduced_motion = _reduced_motion()
			(_content_parent(parent) if parent != null else _screen).add_child(master)
			_hd_performers.append(master)
			return master
		var master := FighterPortrait.new()
		master.name = id + "_HDPortrait"
		master.set_meta("character_id", id)
		master.set_meta("representation", "original_meme_master")
		master.set_meta("face_only", face_only)
		master.fighter_id = id
		master.texture = _face_art.get(id) if face_only else _art.get(id)
		if face_only:
			master.source_parts.assign(_face_parts.get(id, []))
		master.position = rect.position
		master.size = rect.size
		master.mouse_filter = Control.MOUSE_FILTER_IGNORE
		(_content_parent(parent) if parent != null else _screen).add_child(master)
		return master
	var portrait := AnimatedPortrait.new()
	portrait.name = id + "_AnimatedPortrait"
	portrait.set_meta("character_id", id)
	var visual_id := id
	if id == "rio" and not _art.has(id) and not _animations.has(id):
		visual_id = "cat"
	portrait.fighter_id = visual_id
	portrait.texture = _art.get(visual_id)
	portrait.phase = _ui_time + float(_ids.find(id)) * 0.17
	portrait.fps = MENU_BPM / 60.0 * 4.0
	portrait.beat_bounce = false
	portrait.reduced_motion = _reduced_motion()
	portrait.draw_scale = 1.0
	portrait.neon_mode = false
	var info: Dictionary = _core_animations.get(visual_id, {}) if prefer_idle else _animations.get(visual_id, {})
	if info.is_empty():
		info = _animations.get(visual_id, {})
	if not info.is_empty():
		portrait.sheet = info["texture"]
		portrait.columns = int(info["columns"])
		portrait.rows = int(info["rows"])
		portrait.frame_count = int(info["frames"])
		portrait.common_bounds = info["bounds"]
		portrait.common_foot = float(info["common_foot"])
		portrait.frame_regions.assign(info.get("frame_regions", []))
		portrait.frame_parts = info.get("frame_parts", [])
		portrait.body_height_unit = float(info.get("body_height_unit", 0.0))
		portrait.reference_center = float(info.get("center_x", 0.0))
		portrait.reference_body_scale = float(info.get("body_scale", 1.0))
		portrait.set_meta("uses_frame_metadata", not portrait.frame_regions.is_empty())
		portrait.set_meta("reference_bounds", info["bounds"])
		portrait.set_meta("reference_cell", info["cell"])
		portrait.set_meta("common_foot", info["common_foot"])
		portrait.set_meta("animation_kind", info["kind"])
		if info["kind"] == "idle":
			portrait.fps = 6.0
	portrait.rhythmic = _page == "home" and info.get("kind", "") == "dance"
	if portrait.rhythmic:
		# Offset each dancer by an exact half beat while keeping all five on the same audio clock.
		portrait.phase = float(_ids.find(id)) * 0.5 * 60.0 / MENU_BPM
	var shader_path := "res://game/ui_summer_character.gdshader"
	if ResourceLoader.exists(shader_path):
		var treatment := ShaderMaterial.new()
		treatment.shader = load(shader_path)
		treatment.set_shader_parameter("outline_pixels", 1.8 if hero else 1.2)
		portrait.material = treatment
	if hero:
		portrait.reaction_clips = _rio_reactions
	portrait.position = rect.position
	portrait.size = rect.size
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_content_parent(parent) if parent != null else _screen).add_child(portrait)
	return portrait


func _link_vertical_focus(buttons: Array[Button]) -> void:
	for index: int in range(buttons.size()):
		var button := buttons[index]
		button.focus_neighbor_top = button.get_path_to(buttons[(index + buttons.size() - 1) % buttons.size()])
		button.focus_neighbor_bottom = button.get_path_to(buttons[(index + 1) % buttons.size()])


func _footer(left_text: String, right_text: String) -> void:
	_label(left_text, Rect2(35, 682, 766, 28), 16, INK)
	_label(right_text, Rect2(817, 682, 427, 28), 14, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), PAPER)
	if _page in ["home", "select"]:
		return
	# Shared print system: a cut-paper masthead, a sea-colored margin, and distinct
	# game components. Text, selection and focus never move with these shapes.
	draw_colored_polygon(PackedVector2Array([Vector2(0, 96), Vector2(1280, 96), Vector2(1280, 720), Vector2(968, 720)]), BLUE)
	for x: int in range(992, 1280, 18):
		for y: int in range(118, 670, 18):
			draw_circle(Vector2(x, y), 1.35, Color(0.09, 0.23, 0.33, 0.13))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1262, 93), Vector2(0, 104)]), INK)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(19, 0), Vector2(1, 104), Vector2(0, 104)]), RED)
	draw_colored_polygon(PackedVector2Array([Vector2(796, 0), Vector2(818, 0), Vector2(795, 96), Vector2(772, 96)]), AQUA)
	draw_line(Vector2(22, 97), Vector2(760, 91), YELLOW, 5)
	if _page == "result":
		draw_colored_polygon(PackedVector2Array([Vector2(0, 96), Vector2(797, 96), Vector2(646, 675), Vector2(0, 675)]), INK)
		draw_circle(Vector2(1004, 338), 276, YELLOW)
		for i: int in range(20):
			var angle := float(i) / 20.0 * TAU
			var from := Vector2(1004, 338) + Vector2(cos(angle), sin(angle)) * 282
			var to := Vector2(1004, 338) + Vector2(cos(angle), sin(angle)) * 320
			draw_line(from, to, PAPER, 9.0)
		_print_panel(Rect2(34, 118, 731, 110), YELLOW, 23)
		draw_line(Vector2(51, 349), Vector2(653, 341), RED, 5)
	elif _page == "settings":
		for index: int in range(4):
			var y := 170.0 if index == 0 else 272.0 + (index - 1) * 99.0
			var h := 83.0 if index == 0 else 93.0
			_print_panel(Rect2(94 - index * 5, y, 1093 + index * 5, h), PAPER, 19)
			_print_panel(Rect2(90 - index * 5, y, 22, h), [BLUE, RED, YELLOW, BLUE][index], 9)
			draw_line(Vector2(124, y + h - 7), Vector2(886, y + h - 7), Color(0.09, 0.23, 0.33, 0.12), 1)
	elif _page == "controls":
		for side: int in range(2):
			var x := 65.0 + side * 577.0
			_print_panel(Rect2(x, 146, 518, 31), INK, 11)
			for index: int in range(10):
				var y := 182.0 + index * 43.0
				draw_line(Vector2(x + 7, y + 37), Vector2(x + 228, y + 37), Color(0.09, 0.23, 0.33, 0.15), 1)
	elif _page == "guide":
		if _guide_tab == 0:
			for side: int in range(2):
				var x := 72.0 + side * 594.0
				for index: int in range(10):
					var y := 187.0 + index * 36.0
					draw_line(Vector2(x + 207, y + 32), Vector2(x + 549, y + 32), Color(0.09, 0.23, 0.33, 0.11), 1)
		elif _guide_tab == 1:
			_print_panel(Rect2(69, 234, 479, 335), BLUE, 20)
			draw_circle(Vector2(260, 393), 151, PAPER)
		elif _guide_tab == 2:
			_print_panel(Rect2(547, 186, 671, 388), INK, 18)
			_print_panel(Rect2(559, 252, 647, 101), YELLOW, 12)
	draw_rect(Rect2(0, 675, 1280, 45), PAPER)
	draw_line(Vector2(23, 673), Vector2(1253, 673), INK, 1.5)


func _print_panel(rect: Rect2, color: Color, cut: float = 12.0) -> void:
	draw_colored_polygon(PackedVector2Array([rect.position + Vector2(cut, 0), Vector2(rect.end.x, rect.position.y), rect.end - Vector2(cut, 0), Vector2(rect.position.x, rect.end.y)]), color)


class FighterPortrait extends Control:
	var fighter_id := "shark"
	var texture: Texture2D
	var source_parts: Array[Rect2] = []

	func _draw() -> void:
		if texture != null:
			var texture_size := texture.get_size()
			if texture_size.x > 0 and texture_size.y > 0:
				var factor := minf(size.x / texture_size.x, size.y / texture_size.y)
				var target_size := texture_size * factor
				if texture is AtlasTexture and not source_parts.is_empty():
					var atlas := texture as AtlasTexture
					var origin := (size - target_size) / 2.0
					for part: Rect2 in source_parts:
						# Both head portions keep one common source-to-display transform.
						draw_texture_rect_region(atlas.atlas, Rect2(origin + (part.position - atlas.region.position) * factor, part.size * factor), part)
					return
				draw_texture_rect(texture, Rect2((size - target_size) / 2.0, target_size), false)
				return
		# Simple original placeholders are also usable if a resource is unavailable.
		draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(240, 300))
		_draw_oval(Rect2(33, 270, 174, 20), Color(0, 0, 0, 0.24))
		match fighter_id:
			"shark":
				_draw_shark()
			"cat":
				_draw_cat()
			"worker":
				_draw_worker()
			"chicken":
				_draw_chicken()


	func _draw_oval(rect: Rect2, color: Color) -> void:
		var points := PackedVector2Array()
		for index: int in range(40):
			var angle := float(index) / 40.0 * TAU
			points.append(rect.get_center() + Vector2(cos(angle), sin(angle)) * rect.size / 2.0)
		draw_colored_polygon(points, color)


	func _draw_shark() -> void:
		var outline := Color("171723")
		var body := Color("8fc8d4")
		draw_colored_polygon(PackedVector2Array([Vector2(44, 156), Vector2(7, 113), Vector2(13, 196), Vector2(59, 177)]), body)
		draw_colored_polygon(PackedVector2Array([Vector2(89, 124), Vector2(108, 38), Vector2(143, 114)]), body)
		_draw_oval(Rect2(38, 87, 185, 133), outline)
		_draw_oval(Rect2(43, 92, 175, 124), body)
		_draw_oval(Rect2(109, 154, 105, 53), Color("e8eeee"))
		for leg: Vector2 in [Vector2(66, 204), Vector2(123, 209), Vector2(178, 202)]:
			draw_line(leg, leg + Vector2(0, 48), outline, 15)
			draw_line(leg, leg + Vector2(0, 48), body, 9)
			draw_rect(Rect2(leg + Vector2(-20, 42), Vector2(49, 22)), outline)
			draw_rect(Rect2(leg + Vector2(-16, 42), Vector2(44, 15)), Color("3699ee"))
			draw_line(leg + Vector2(-10, 50), leg + Vector2(13, 49), Color.WHITE, 3)
		draw_circle(Vector2(182, 119), 7, outline)
		draw_arc(Vector2(178, 143), 26, 0.25, 1.75, 14, outline, 3)


	func _draw_cat() -> void:
		var fur := Color("c38f54")
		var ink := Color("171723")
		_draw_oval(Rect2(71, 129, 106, 115), fur)
		draw_line(Vector2(164, 217), Vector2(204, 169), fur, 19)
		draw_line(Vector2(76, 153), Vector2(36, 105), fur, 21)
		draw_line(Vector2(163, 152), Vector2(210, 100), fur, 21)
		draw_line(Vector2(93, 228), Vector2(70, 269), fur, 23)
		draw_line(Vector2(151, 228), Vector2(176, 269), fur, 23)
		draw_colored_polygon(PackedVector2Array([Vector2(69, 94), Vector2(62, 34), Vector2(107, 60), Vector2(158, 61), Vector2(193, 33), Vector2(186, 110)]), fur)
		_draw_oval(Rect2(63, 56, 129, 106), fur)
		_draw_oval(Rect2(87, 105, 86, 47), Color("edd6ab"))
		draw_arc(Vector2(104, 95), 12, PI + 0.2, TAU - 0.2, 12, ink, 4)
		draw_arc(Vector2(155, 95), 12, PI + 0.2, TAU - 0.2, 12, ink, 4)
		draw_circle(Vector2(130, 117), 5, ink)
		draw_arc(Vector2(130, 120), 17, 0.2, PI - 0.2, 12, ink, 4)
		for offset: int in [-1, 1]:
			draw_line(Vector2(130 + offset * 29, 124), Vector2(130 + offset * 58, 118), ink, 2)
			draw_line(Vector2(130 + offset * 29, 130), Vector2(130 + offset * 58, 140), ink, 2)


	func _draw_worker() -> void:
		var skin := Color("ffd0a3")
		var ink := Color("24212b")
		draw_line(Vector2(104, 216), Vector2(82, 273), ink, 23)
		draw_line(Vector2(149, 215), Vector2(173, 267), ink, 23)
		draw_rect(Rect2(74, 136, 94, 97), Color("35b4dc"))
		draw_line(Vector2(75, 147), Vector2(45, 199), Color("35b4dc"), 27)
		draw_line(Vector2(166, 151), Vector2(198, 177), Color("35b4dc"), 27)
		draw_circle(Vector2(45, 201), 12, skin)
		draw_circle(Vector2(201, 178), 12, skin)
		draw_rect(Rect2(173, 191, 61, 49), Color("715743"))
		draw_arc(Vector2(204, 195), 13, PI, TAU, 12, ink, 4)
		_draw_oval(Rect2(72, 39, 104, 111), skin)
		draw_colored_polygon(PackedVector2Array([Vector2(72, 91), Vector2(73, 53), Vector2(94, 28), Vector2(144, 29), Vector2(175, 51), Vector2(177, 87), Vector2(153, 59), Vector2(140, 77), Vector2(119, 58), Vector2(101, 80), Vector2(88, 60)]), ink)
		draw_arc(Vector2(103, 92), 9, 0.15, PI - 0.15, 12, ink, 3)
		draw_arc(Vector2(146, 92), 9, 0.15, PI - 0.15, 12, ink, 3)
		draw_arc(Vector2(126, 106), 15, 0.15, PI - 0.15, 12, ink, 3)


	func _draw_chicken() -> void:
		var ink := Color("24212b")
		var feather := Color("fff0ba")
		_draw_oval(Rect2(64, 123, 113, 118), feather)
		draw_rect(Rect2(82, 154, 77, 88), Color("777c93"))
		draw_line(Vector2(87, 145), Vector2(105, 232), ink, 10)
		draw_line(Vector2(154, 145), Vector2(136, 232), ink, 10)
		draw_line(Vector2(91, 233), Vector2(79, 270), Color("e6a32d"), 15)
		draw_line(Vector2(145, 233), Vector2(162, 270), Color("e6a32d"), 15)
		draw_line(Vector2(68, 153), Vector2(43, 209), feather, 24)
		draw_line(Vector2(169, 153), Vector2(191, 202), feather, 24)
		draw_circle(Vector2(203, 229), 34, Color("e27831"))
		draw_arc(Vector2(203, 229), 34, 0, TAU, 40, ink, 3)
		draw_line(Vector2(169, 228), Vector2(237, 230), ink, 3)
		draw_line(Vector2(202, 195), Vector2(204, 263), ink, 3)
		_draw_oval(Rect2(69, 40, 109, 112), feather)
		draw_colored_polygon(PackedVector2Array([Vector2(70, 82), Vector2(80, 38), Vector2(114, 21), Vector2(123, 48), Vector2(105, 67), Vector2(90, 60)]), ink)
		draw_colored_polygon(PackedVector2Array([Vector2(123, 48), Vector2(137, 22), Vector2(165, 40), Vector2(180, 83), Vector2(157, 61), Vector2(140, 66)]), ink)
		draw_circle(Vector2(103, 97), 5, ink)
		draw_circle(Vector2(150, 97), 5, ink)
		draw_colored_polygon(PackedVector2Array([Vector2(114, 115), Vector2(139, 115), Vector2(126, 130)]), Color("e6a32d"))


class AnimatedPortrait extends FighterPortrait:
	var sheet: Texture2D
	var columns := 4
	var rows := 2
	var frame_count := 8
	var frame_index := 0
	var fps := MENU_BPM / 60.0 * 4.0
	var phase := 0.0
	var rhythmic := false
	var beat_bounce := true
	var draw_scale := 1.0
	var neon_mode := false
	var common_bounds := Rect2()
	var common_foot := -1.0
	var frame_regions: Array[Rect2] = []
	var frame_parts: Array = []
	var body_height_unit := 0.0
	var reference_center := 0.0
	var reference_body_scale := 1.0
	var _elapsed := 0.0
	var _frame_progress := 0.0
	var _local_clock := 0.0
	var reduced_motion := false
	var performance_state := "dance"
	var reaction_clips: Dictionary = {}
	var _reaction_left := 0.0
	var _reaction_duration := 0.0
	var _reaction_sequence: Array[int] = []
	var _reaction_clip: Dictionary = {}
	var _base_info: Dictionary = {}
	var _reaction_reference_height := 0.0
	var _reaction_body_calibration := Vector3.ZERO


	func _ready() -> void:
		_elapsed = phase
		_frame_progress = phase * fps
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		set_process(sheet != null or material != null)

	func _process(delta: float) -> void:
		_local_clock += delta
		if rhythmic:
			_elapsed = _music_clock() + phase
			_frame_progress = _elapsed * (MENU_BPM / 60.0 * 4.0)
		else:
			_elapsed += delta
			_frame_progress += delta * fps
		var loop_frame := int(floor(_frame_progress)) % maxi(frame_count, 1)
		if reduced_motion:
			loop_frame = (int(floor(_frame_progress / 2.0)) * 2) % maxi(frame_count, 1)
		frame_index = loop_frame
		if _reaction_left > 0.0:
			_reaction_left = maxf(0.0, _reaction_left - delta)
			var progress := 1.0 - _reaction_left / maxf(_reaction_duration, 0.001)
			frame_index = _reaction_sequence[mini(int(progress * _reaction_sequence.size()), _reaction_sequence.size() - 1)]
			if _reaction_left <= 0.0:
				_restore_loop()
				frame_index = int(floor(_frame_progress)) % maxi(frame_count, 1)
		set_meta("atlas_frame", frame_index)
		set_meta("performance_state", performance_state)
		queue_redraw()

	func react(kind: String, duration: float = 0.32) -> void:
		if performance_state == "confirm" and _reaction_left > 0.0:
			return
		if _base_info.is_empty():
			_base_info = {"sheet": sheet, "columns": columns, "rows": rows, "frame_count": frame_count, "common_bounds": common_bounds, "common_foot": common_foot, "frame_regions": frame_regions.duplicate(), "frame_parts": frame_parts, "body_height_unit": body_height_unit, "reference_center": reference_center, "reference_body_scale": reference_body_scale}
		_restore_loop()
		performance_state = kind
		_reaction_duration = duration
		_reaction_left = duration
		var clip_name := "heavy" if kind == "confirm" else "light" if kind == "ball" else "block" if kind == "invite" else "idle"
		_reaction_clip = reaction_clips.get(clip_name, {})
		if not _reaction_clip.is_empty():
			# Dance has a 385 px standing head-to-boot unit in its 443.5 px square cell.
			# Every 887 px reaction clip has its own fixed art-approved standing-equivalent unit.
			_reaction_reference_height = 385.0
			var calibration: Dictionary = _reaction_clip.get("body_calibration", {})
			_reaction_body_calibration = Vector3(float(calibration.get("body_height", common_bounds.size.y)), float(calibration.get("foot_line", _reaction_clip["common_foot"])), float(calibration.get("center_x", _reaction_clip["bounds"].get_center().x)))
			sheet = _reaction_clip["texture"]
			columns = int(_reaction_clip["columns"])
			rows = int(_reaction_clip["rows"])
			frame_count = int(_reaction_clip["frames"])
			common_bounds = _reaction_clip["bounds"]
			common_foot = float(_reaction_clip["common_foot"])
			frame_regions.clear()
			frame_parts = []
			body_height_unit = 0.0
			_reaction_sequence.assign([2, 2, 2, 2] if kind == "confirm" else [0, 1, 2, 3])
		else:
			_reaction_sequence.assign([6, 6, 6] if kind == "confirm" else [4, 5, 6, 7] if kind == "ball" else [1, 2, 3])
		frame_index = _reaction_sequence[0]
		queue_redraw()

	func _restore_loop() -> void:
		if not _base_info.is_empty():
			for key: String in _base_info:
				set(key, _base_info[key])
		performance_state = "dance" if rhythmic else "idle"
		_reaction_left = 0.0
		_reaction_reference_height = 0.0
		_reaction_body_calibration = Vector3.ZERO
		_reaction_clip = {}

	func _music_clock() -> float:
		var audio := get_node_or_null("/root/GameAudio")
		if audio != null:
			var music: Variant = audio.get("music")
			if music is AudioStreamPlayer and music.playing:
				return maxf(0.0, music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())
		return _local_clock

	func _set_treatment(source: Rect2, atlas_size: Vector2) -> void:
		var treatment := material as ShaderMaterial
		if treatment == null:
			return
		treatment.set_shader_parameter("frame_region", Vector4(source.position.x / atlas_size.x, source.position.y / atlas_size.y, source.size.x / atlas_size.x, source.size.y / atlas_size.y))
		treatment.set_shader_parameter("motion_clock", _elapsed)
		treatment.set_shader_parameter("secondary_motion", 0.0 if reduced_motion else 0.35 if fighter_id == "rio" else 0.08)
		if neon_mode:
			var beat := pow(1.0 - fposmod(_elapsed * MENU_BPM / 60.0, 1.0), 3.0)
			treatment.set_shader_parameter("neon_strength", 0.8 + beat * 0.24)

	func _draw() -> void:
		if sheet == null:
			if texture is AtlasTexture:
				var atlas := texture as AtlasTexture
				_set_treatment(atlas.region, atlas.atlas.get_size())
			elif texture != null:
				_set_treatment(Rect2(Vector2.ZERO, texture.get_size()), texture.get_size())
			super._draw()
			return
		var cell := sheet.get_size() / Vector2(columns, rows)
		if cell.x <= 0.0 or cell.y <= 0.0:
			return
		var column := frame_index % columns
		var row := frame_index / columns
		var nominal_source := Rect2(Vector2(column, row) * cell, cell)
		var source := nominal_source
		var reference := common_bounds if common_bounds.has_area() else Rect2(Vector2.ZERO, cell)
		var foot := common_foot if common_foot >= 0.0 else reference.end.y
		var factor := minf(size.x / reference.size.x, size.y / reference.size.y) * draw_scale
		var logical_origin := Vector2(size.x * 0.5 - reference.get_center().x * factor, size.y - foot * factor)
		if body_height_unit > 0.0 and frame_index < frame_regions.size():
			# Curated irregular sheets use one row-wide source-pixel scale and a shared logical anchor.
			factor = minf(size.x / reference.size.x, size.y / body_height_unit) * reference_body_scale * draw_scale
			logical_origin = Vector2(size.x * 0.5 - reference_center * factor, size.y - foot * factor)
			source = frame_regions[frame_index]
		if _reaction_reference_height > 0.0:
			var base_bounds: Rect2 = _base_info.get("common_bounds", reference)
			var dance_pixel_scale := minf(size.x / base_bounds.size.x, size.y / base_bounds.size.y) * draw_scale
			factor = dance_pixel_scale * _reaction_reference_height / maxf(_reaction_body_calibration.x, 1.0)
			logical_origin = Vector2(size.x * 0.5 - _reaction_body_calibration.z * factor, size.y - _reaction_body_calibration.y * factor)
		var destination := Rect2(logical_origin + (source.position - nominal_source.position) * factor, source.size * factor)
		# A fixed row correction preserves drawn feet; no frame-dependent stretching or bounding-box crops.
		if frame_count == 8 and frame_index >= 4:
			var source_shift := float({"shark": 38.0, "cat": 40.0, "worker": 48.0, "chicken": 22.0, "rio": 23.0}.get(fighter_id, 0.0))
			destination.position.y += source_shift * factor
		if rhythmic and beat_bounce:
			destination.position.y -= absf(sin(_elapsed * TAU * MENU_BPM / 60.0)) * 2.0
		_set_treatment(source, sheet.get_size())
		if frame_index < frame_parts.size() and frame_parts[frame_index] is Array and not frame_parts[frame_index].is_empty():
			for part: Rect2 in frame_parts[frame_index]:
				var part_destination := Rect2(destination.position + (part.position - source.position) * factor, part.size * factor)
				draw_texture_rect_region(sheet, part_destination, part)
		else:
			draw_texture_rect_region(sheet, destination, source)


class SummerButton extends Button:
	var visual: SummerButtonArt
	var reduced_motion := false
	var _tween: Tween
	var _state := ""
	var _confirmed_left := 0.0
	var _last_reduced_motion := false

	func _ready() -> void:
		set_process(true)

	func confirm() -> void:
		_confirmed_left = Summer.CONFIRM_SECONDS
		_update_visual_state("confirmed")

	func _process(delta: float) -> void:
		_confirmed_left = maxf(0.0, _confirmed_left - delta)
		var next := "disabled" if disabled else "confirmed" if _confirmed_left > 0.0 else "pressed" if is_pressed() and not toggle_mode else "focus" if has_focus() or is_hovered() else "selected" if button_pressed or bool(get_meta("selected", false)) else "default"
		if next != _state or _last_reduced_motion != reduced_motion:
			_last_reduced_motion = reduced_motion
			_update_visual_state(next)
		visual.caption = text
		visual.selected = button_pressed or bool(get_meta("selected", false))
		visual.reduced_motion = reduced_motion
		visual.feedback = maxf(0.0, visual.feedback - delta / Summer.HOVER_SECONDS)
		visual.queue_redraw()

	func _update_visual_state(next: String) -> void:
		_state = next
		if visual == null:
			return
		visual.state = next
		visual.feedback = 1.0
		if _tween != null and _tween.is_valid():
			_tween.kill()
		var target := Vector2.ZERO
		var target_scale := Vector2.ONE
		if not reduced_motion:
			if next == "focus":
				target = Vector2(-4 if visual.kind == "return" else 5, -1)
				target_scale = Vector2(1.012, 1.012)
			elif next in ["pressed", "confirmed"]:
				target = Vector2(2, 3)
				target_scale = Vector2(0.985, 0.985)
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(visual, "position", target, 0.045 if next == "pressed" else Summer.HOVER_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(visual, "scale", target_scale, 0.045 if next == "pressed" else Summer.HOVER_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


class SummerButtonArt extends Control:
	var caption := ""
	var subtitle := ""
	var number := 0
	var font_size := 26
	var primary := false
	var compact := true
	var menu_mode := false
	var accent := PAPER
	var kind := "generic"
	var state := "default"
	var selected := false
	var reduced_motion := false
	var feedback := 0.0

	func _text(value: String, point: Vector2, font_size_value: int, color: Color = INK, width: float = -1.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
		draw_string(ThemeDB.fallback_font, point, value, align, width, font_size_value, color)

	func _draw() -> void:
		var active := state in ["focus", "pressed", "confirmed", "selected"] or selected
		if menu_mode:
			_draw_menu(active)
			return
		if kind == "character":
			_draw_character(active)
			return
		var background := YELLOW if primary or active else PAPER
		if state == "disabled":
			background = Color("e2e7df")
		var ink := MUTED if state == "disabled" else INK
		var points := PackedVector2Array([Vector2(10, 0), Vector2(size.x, 0), Vector2(size.x - 10, size.y), Vector2(0, size.y)])
		var shadow := PackedVector2Array()
		for point: Vector2 in points:
			shadow.append(point + Vector2(0, 5))
		draw_colored_polygon(shadow, INK)
		draw_colored_polygon(points, background)
		var outline := PackedVector2Array(points)
		outline.append(points[0])
		draw_line(Vector2(10, 0), Vector2(size.x, 0), ink, 2.0)
		draw_line(Vector2(size.x - 10, size.y), Vector2(0, size.y), ink, 2.0)
		if active and state != "disabled":
			draw_polyline(outline, ink, 2.5, true)
		if selected and kind == "difficulty":
			draw_polyline(PackedVector2Array([Vector2(9, 7), Vector2(13, 11), Vector2(20, 4)]), INK, 2.3, true)
		if selected and kind == "recipe":
			draw_polyline(PackedVector2Array([Vector2(size.x - 37, 18), Vector2(size.x - 31, 24), Vector2(size.x - 20, 12)]), INK, 3.0, true)
		if state == "confirmed" and kind != "difficulty":
			draw_polyline(PackedVector2Array([Vector2(size.x - 47, 23), Vector2(size.x - 38, 32), Vector2(size.x - 22, 14)]), INK, 4.0, true)
		elif active and state != "disabled" and kind != "difficulty":
			draw_colored_polygon(PackedVector2Array([Vector2(size.x - 31, size.y * 0.5 - 6), Vector2(size.x - 22, size.y * 0.5), Vector2(size.x - 31, size.y * 0.5 + 6)]), INK)
		if not compact:
			draw_colored_polygon(PackedVector2Array([Vector2(10, 0), Vector2(68, 0), Vector2(58, size.y), Vector2(0, size.y)]), RED)
			_text("%02d" % number, Vector2(14, size.y * 0.5 + 10), 25, INK)
			_text(caption, Vector2(79, 36 if primary else 29), font_size, ink, size.x - 120)
			_text(subtitle, Vector2(80, 62 if primary else 49), 16 if primary else 15, MUTED, size.x - 121)
		else:
			if not caption.is_empty():
				var baseline := size.y * 0.5 + font_size * 0.35
				if kind == "recipe":
					baseline = 31.0
				elif kind == "random":
					baseline = 89.0
				if kind == "difficulty":
					_text(caption, Vector2(7, baseline), font_size, ink, size.x - 14, HORIZONTAL_ALIGNMENT_CENTER)
				else:
					_text(caption, Vector2(13, baseline), font_size, ink, size.x - 26, HORIZONTAL_ALIGNMENT_CENTER)
		if state == "focus" and kind == "start":
			for i: int in range(3):
				var y := 18.0 + i * 16.0
				draw_line(Vector2(size.x + 4, y), Vector2(size.x + 12 + feedback * 8.0, y - 3), AQUA, 2.5, true)
		elif state == "focus" and kind == "settings":
			for i: int in range(3):
				draw_line(Vector2(size.x - 61 + i * 7, size.y - 9), Vector2(size.x - 61 + i * 7, size.y - 14 - (i + 1) * 3), INK, 2)
		elif state == "focus" and kind == "local":
			draw_circle(Vector2(size.x - 55, 15), 3.5, RED)
			draw_circle(Vector2(size.x - 45, 15), 3.5, AQUA)
		elif state == "focus" and kind == "training":
			draw_arc(Vector2(size.x - 52, 17), 6, 0, TAU, 20, INK, 1.5, true)
			draw_line(Vector2(size.x - 60, 17), Vector2(size.x - 44, 17), INK, 1.5)
		elif state == "focus" and kind == "return":
			draw_polyline(PackedVector2Array([Vector2(size.x - 44, 14), Vector2(size.x - 53, 19), Vector2(size.x - 44, 24)]), INK, 2, true)

	func _draw_menu(active: bool) -> void:
		var disabled := state == "disabled"
		var emphasized := active and not disabled
		var ink := MUTED if disabled else INK
		var fill := YELLOW if emphasized or primary else PAPER
		if disabled: fill = Color("e2e7df")
		var shape := PackedVector2Array([Vector2(9, 0), Vector2(size.x, 0), Vector2(size.x - 17, size.y), Vector2(-6, size.y)])
		var shadow := PackedVector2Array()
		for point: Vector2 in shape: shadow.append(point + Vector2(2, 4))
		draw_colored_polygon(shadow, INK)
		draw_colored_polygon(shape, fill)
		var outline := PackedVector2Array(shape)
		outline.append(shape[0])
		draw_polyline(outline, ink, 2.8 if emphasized else 1.8, true)
		draw_colored_polygon(PackedVector2Array([Vector2(9, 0), Vector2(48, 0), Vector2(34, size.y), Vector2(-6, size.y)]), RED if emphasized else Color("e8e1cc"))
		_text("%02d" % number, Vector2(4, 34), 19, ink)
		_text(caption, Vector2(55, 33), font_size, ink, size.x - 92)
		_text(subtitle, Vector2(57, 54), 13, MUTED, size.x - 91)
		if emphasized:
			if state == "confirmed":
				draw_polyline(PackedVector2Array([Vector2(size.x - 40, 23), Vector2(size.x - 32, 31), Vector2(size.x - 19, 16)]), INK, 3.5, true)
			else:
				draw_colored_polygon(PackedVector2Array([Vector2(size.x - 31, size.y * 0.5 - 7), Vector2(size.x - 20, size.y * 0.5), Vector2(size.x - 31, size.y * 0.5 + 7)]), INK)

	func _draw_character(active: bool) -> void:
		var edge := YELLOW if active else accent
		var face_height := size.y - 33.0
		draw_rect(Rect2(0, 0, size.x, size.y), INK)
		draw_rect(Rect2(4, 4, size.x - 8, face_height - 4), Color("d5f1ef"))
		for index: int in range(6):
			draw_line(Vector2(4, 15 + index * 21), Vector2(size.x - 4, -6 + index * 21), Color(1, 0.98, 0.91, 0.28), 2)
		draw_line(Vector2(3, face_height), Vector2(size.x - 3, face_height), edge, 3)
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), edge, false, 5 if active else 2.5)
		if active:
			draw_colored_polygon(PackedVector2Array([Vector2(size.x - 22, face_height - 21), Vector2(size.x - 7, face_height - 21), Vector2(size.x - 7, face_height - 6)]), YELLOW)


class SelectionTargetCanvas extends Control:
	var background: Texture2D
	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var path := "res://assets/art/visual_v18/pool_home.png"
		if not ResourceLoader.exists(path): path = "res://assets/art/home_pool_2d.png"
		if ResourceLoader.exists(path): background = load(path)
		queue_redraw()
	func _draw() -> void:
		if background != null:
			draw_texture_rect(background, Rect2(0, 0, 1280, 720), false)
		# Header is a broad, rough paper stroke, while the scene remains open.
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 78), Vector2(1112, 83), Vector2(994, 104), Vector2(843, 97), Vector2(640, 108), Vector2(425, 96), Vector2(242, 99), Vector2(0, 79)]), PAPER)
		draw_polyline(PackedVector2Array([Vector2(0, 81), Vector2(243, 101), Vector2(426, 98), Vector2(640, 110), Vector2(844, 99), Vector2(996, 106), Vector2(1113, 85), Vector2(1280, 80)]), INK, 3, true)
		draw_colored_polygon(PackedVector2Array([Vector2(381, 122), Vector2(909, 122), Vector2(895, 163), Vector2(367, 163)]), PAPER)
		# Small paper labels group mode controls; no opaque character panels.
		draw_colored_polygon(PackedVector2Array([Vector2(434, 494), Vector2(849, 494), Vector2(834, 581), Vector2(421, 581)]), Color(1, 0.973, 0.91, 0.94))
		for side: int in range(2):
			var x := 16.0 if side == 0 else 856.0
			var accent := RED if side == 0 else BLUE
			# The name and two advice lines share one dark strip. Their full
			# fixed text rows fit above the accent; the footnote stays on paper.
			var strip := PackedVector2Array([Vector2(x + 10, 548), Vector2(x + 333, 547), Vector2(x + 329, 644), Vector2(x, 644)])
			draw_colored_polygon(strip, INK)
			draw_line(Vector2(x + 8, 644), Vector2(x + 325, 644), accent, 3)
			draw_colored_polygon(PackedVector2Array([Vector2(x + 12, 647), Vector2(x + 329, 647), Vector2(x + 324, 670), Vector2(x + 5, 670)]), PAPER)
		draw_rect(Rect2(0, 674, 1280, 46), PAPER)
		draw_line(Vector2(23, 674), Vector2(1253, 674), INK, 1.5)


class PosterTag extends Control:
	var accent := YELLOW
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(5, 2), Vector2(size.x, 2), Vector2(size.x - 3, size.y + 2), Vector2(1, size.y + 2)]), INK)
		draw_colored_polygon(PackedVector2Array([Vector2(4, 0), Vector2(size.x - 1, 0), Vector2(size.x - 4, size.y - 1), Vector2(0, size.y - 1)]), accent)


class SummerWipe extends Control:
	var reverse := false
	var elapsed := 0.0
	func _process(delta: float) -> void:
		elapsed += delta
		if elapsed >= Summer.PAGE_SECONDS:
			queue_free()
		else:
			queue_redraw()
	func _draw() -> void:
		var progress := clampf(elapsed / Summer.PAGE_SECONDS, 0.0, 1.0)
		var x := lerpf(-190, 1580, progress if not reverse else 1.0 - progress)
		var points := PackedVector2Array([Vector2(x - 35, -24), Vector2(x + 92, -24), Vector2(x - 144, 744), Vector2(x - 264, 744)])
		draw_colored_polygon(points, BLUE)
		draw_polyline(PackedVector2Array([Vector2(x + 95, -24), Vector2(x - 141, 744)]), PAPER, 9, true)
		draw_polyline(PackedVector2Array([Vector2(x + 108, -24), Vector2(x - 128, 744)]), INK, 1.5, true)


class SliderFocusArt extends Control:
	func _draw() -> void:
		var slider := get_parent() as HSlider
		if slider != null and slider.has_focus():
			var bounds := Rect2(Vector2(-9, -9), size + Vector2(18, 18))
			draw_rect(bounds, INK, false, 2.5)
			draw_colored_polygon(PackedVector2Array([Vector2(-18, size.y * 0.5 - 5), Vector2(-11, size.y * 0.5), Vector2(-18, size.y * 0.5 + 5)]), INK)

func _binding_name(player: int, action_index: int) -> String:
	var keys: Array = _settings["bindings_p1" if player == 0 else "bindings_p2"]
	var code := int(keys[action_index])
	return {KEY_LEFT: "←", KEY_RIGHT: "→", KEY_UP: "↑", KEY_DOWN: "↓", KEY_SPACE: "Space", KEY_SHIFT: "Shift"}.get(code, OS.get_keycode_string(code))


func _training_descriptor(recipe_id: String, character_id: String = "") -> Dictionary:
	if authored_skills_enabled and recipe_id=="hit_confirm":
		return load("res://game/authored_training_routes.gd").descriptor(_p1 if character_id.is_empty() else character_id,recipe_id)
	if not _training_routes and ResourceLoader.exists("res://game/bvn_training_routes.gd"):
		_training_routes = load("res://game/bvn_training_routes.gd")
	if _training_routes:
		return _training_routes.descriptor(_p1 if character_id.is_empty() else character_id, recipe_id)
	return {}


func _training_step_key(step: Dictionary) -> String:
	var slot := int(step.get("key_slot", -1))
	if slot < 0:
		return "自動追撃"
	var parts: Array[String] = []
	for modifier: Variant in step.get("modifiers", []):
		parts.append(_binding_name(0, int(modifier)))
	parts.append(_binding_name(0, slot))
	var prefix := "空中 " if str(step.get("command", "")).begins_with("air_") else ""
	return prefix + "+".join(parts)


func _recipe_input(recipe_id: String, character_id: String = "") -> String:
	if recipe_id in ["full_normal", "hit_confirm"]:
		var route := _training_descriptor(recipe_id, character_id)
		var inputs: Array[String] = []
		for step: Dictionary in route.get("steps", []):
			inputs.append(_training_step_key(step))
		return " → ".join(inputs)
	var attack := _binding_name(0, 4)
	var up_attack := _binding_name(0, 2) + "+" + attack
	var jump := _binding_name(0, 5)
	var slam := "空中 " + _binding_name(0, 7)
	return {
		"normal_chain": "%s → %s → %s" % [attack, attack, attack],
		"launch_slam": "%s → %s → %s → %s" % [attack, up_attack, jump, slam],
		"air_chain": "%s → 空中 %s → %s" % [jump, attack, slam],
		"four_hit": "%s → %s → %s → %s → %s" % [attack, attack, up_attack, jump, slam],
		"sparring": "自由対戦・CPU",
	}.get(recipe_id, "")


func _training_input_caption(recipe_id: String, character_id: String, width: float, font_size: int) -> String:
	var caption := _recipe_input(recipe_id, character_id)
	if ThemeDB.fallback_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
		return caption
	# Long rebound key names must not grow a course card or collide with the
	# conditions. Compress only repeated identical presses, never a new input.
	var parts: Array[String] = []
	var previous := ""
	var repeated := 0
	for input: String in caption.split(" → "):
		if input == previous:
			repeated += 1
			continue
		if not previous.is_empty():
			parts.append(previous + (" ×%d" % repeated if repeated > 1 else ""))
		previous = input
		repeated = 1
	if not previous.is_empty():
		parts.append(previous + (" ×%d" % repeated if repeated > 1 else ""))
	return " → ".join(parts)


func _cycle_training_recipe() -> void:
	var index := _training_recipes.find(_training_recipe)
	_training_recipe = _training_recipes[(index + 1) % _training_recipes.size()]
	_build_select()
	if not _selection_aux.is_empty():
		_selection_aux[0].grab_focus()


func set_available_training_recipes(recipes: Array) -> void:
	_training_recipes.clear()
	for id: Variant in recipes:
		if Data.TRAINING_RECIPES.has(str(id)):
			_training_recipes.append(str(id))
	if _training_recipes.is_empty():
		_training_recipes.append("normal_chain")
	if not _training_recipes.has(_training_recipe):
		_training_recipe = _training_recipes[0]


func _pixel_preview(id: String, rect: Rect2, clip: String = "idle") -> Control:
	if RosterPortraitV034.supports(id):
		var registered: Control = RosterPortraitV034.new()
		registered.name = id+"_PixelPreview"
		registered.configure(id,"win" if clip=="dance" else "selection")
		registered.position = rect.position
		registered.size = rect.size
		registered.reduced_motion = _reduced_motion()
		registered.clip_contents = true
		_screen.add_child(registered)
		return registered
	var preview := PixelPreview.new()
	preview.name = id + "_PixelPreview"
	preview.fighter_id = id
	preview.clip = clip
	preview.position = rect.position
	preview.size = rect.size
	preview.reduced_motion = _reduced_motion()
	preview.phase = float(_ids.find(id)) * 0.13
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.clip_contents = true
	_screen.add_child(preview)
	return preview


func show_controls() -> void:
	if not _ready_done:
		return
	_binding_player = -1
	_binding_action = -1
	_new_screen("controls")
	_binding_buttons.clear()
	_label("キー設定", Rect2(57, 27, 640, 69), 45, PAPER)
	var devices := Input.get_connected_joypads()
	var pad_name := "ゲームパッド：未接続" if devices.is_empty() else "接続中：" + Input.get_joy_name(devices[0])
	_label(pad_name, Rect2(653, 43, 549, 42), 17, PAPER, HORIZONTAL_ALIGNMENT_RIGHT)
	_binding_status = _label(_binding_message, Rect2(75, 98, 1124, 40), 19, INK)
	_label("P1", Rect2(82, 144, 120, 35), 25, PAPER)
	_label("P2", Rect2(659, 144, 120, 35), 25, PAPER)
	for player: int in range(2):
		var x := 76.0 + player * 577.0
		for index: int in range(Data.CONTROL_ACTIONS.size()):
			var y := 182.0 + index * 43.0
			_label(Data.CONTROL_LABELS[index], Rect2(x, y, 225, 35), 20, INK)
			var button := _button(_binding_name(player, index), Rect2(x + 249, y, 258, 36), _begin_binding.bind(player, index), 20, PAPER)
			button.name = "Binding_%d_%s" % [player + 1, Data.CONTROL_ACTIONS[index]]
			_binding_buttons.append(button)
	var back := _button("設定へ戻る", Rect2(75, 638, 268, 43), show_settings, 22, YELLOW)
	var reset := _button("初期キーに戻す", Rect2(367, 638, 284, 43), _reset_bindings, 21, PAPER)
	_label("パッド：X 攻撃 / A ジャンプ / B 瞬歩 / Y 技 / RB 必殺 / LB ダメージ脱出", Rect2(681, 635, 528, 49), 16, MUTED)
	for player: int in range(2):
		for index: int in range(10):
			var button := _binding_buttons[player * 10 + index]
			button.focus_neighbor_top = button.get_path_to(_binding_buttons[player * 10 + posmod(index - 1, 10)])
			button.focus_neighbor_bottom = button.get_path_to(_binding_buttons[player * 10 + index + 1] if index < 9 else back)
			button.focus_neighbor_left = button.get_path_to(_binding_buttons[(1 - player) * 10 + index])
			button.focus_neighbor_right = button.focus_neighbor_left
	back.focus_neighbor_top = back.get_path_to(_binding_buttons[9])
	back.focus_neighbor_right = back.get_path_to(reset)
	back.focus_neighbor_bottom = back.get_path_to(_binding_buttons[0])
	reset.focus_neighbor_top = reset.get_path_to(_binding_buttons[19])
	reset.focus_neighbor_left = reset.get_path_to(back)
	reset.focus_neighbor_bottom = reset.get_path_to(_binding_buttons[10])
	_binding_buttons[0].grab_focus()
	_footer("Enter / A 変更   新しいキーを押す   Esc 取消・戻る", "矢印 / 数字 / テンキーにも対応")


func _begin_binding(player: int, action_index: int) -> void:
	_binding_player = player
	_binding_action = action_index
	_binding_buttons[player * 10 + action_index].text = "キーを押す…"
	_binding_status.text = "P%d・%s：新しいキーを押してください。Esc で取消。" % [player + 1, Data.CONTROL_LABELS[action_index]]


func _commit_binding(player: int, action_index: int, code: int) -> bool:
	var valid := code != 0 and code not in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB, KEY_F1, KEY_F3, KEY_F4, KEY_F11, KEY_R, KEY_T]
	if not valid:
		_binding_message = "このキーはメニュー・練習操作用です。別のキーを選んでください。"
	for other_player: int in range(2):
		var values: Array = _settings["bindings_p1" if other_player == 0 else "bindings_p2"]
		for index: int in range(values.size()):
			if int(values[index]) == code and not (other_player == player and index == action_index):
				valid = false
				_binding_message = "そのキーは P%d・%s で使用中です。別のキーを選んでください。" % [other_player + 1, Data.CONTROL_LABELS[index]]
	if valid:
		var key_name := "bindings_p1" if player == 0 else "bindings_p2"
		var keys: Array = _settings[key_name].duplicate()
		keys[action_index] = code
		_set_setting(key_name, keys)
		_binding_message = "P%d・%s を %s に変更しました。" % [player + 1, Data.CONTROL_LABELS[action_index], OS.get_keycode_string(code)]
	_binding_player = -1
	_binding_action = -1
	show_controls()
	_binding_buttons[player * 10 + action_index].grab_focus()
	return valid


func _reset_bindings() -> void:
	_set_setting("bindings_p1", Data.DEFAULT_P1.duplicate())
	_set_setting("bindings_p2", Data.DEFAULT_P2.duplicate())
	_binding_message = "P1 / P2 のキーを初期設定に戻しました。"
	show_controls()


func show_guide(tab: int = 0) -> void:
	if not _ready_done:
		return
	if _page != "guide":
		_guide_return = "battle" if _battle_page_active and _page not in ["settings", "controls"] else _page
		_guide_character_id = _p1
	_guide_tab = tab
	_new_screen("guide")
	_label("操作・技ガイド", Rect2(54, 23, 800, 64), 43, PAPER)
	_label("キャラクター共通の入力で、違う戦い方。", Rect2(59, 97, 967, 24), 17, MUTED)
	var tabs: Array[Button] = []
	for index: int in range(3):
		var button := _button(["基本操作", "キャラクター技", "連携・実戦練習"][index], Rect2(60 + index * 389, 126, 369, 45), show_guide.bind(index), 23, YELLOW if index == tab else PAPER)
		button.name = "GuideTab_%d" % index
		button.set_meta("selected", index == tab)
		tabs.append(button)
	if tab == 0:
		_guide_controls()
	elif tab == 1:
		_guide_character()
	else:
		_guide_training()
	var content_buttons: Array[Button] = []
	for child in _screen.get_children():
		if child is Button and not tabs.has(child):
			content_buttons.append(child)
	var back := _button("対戦へ戻る" if _battle_page_active and _guide_return == "battle" else "戻る", Rect2(60, 625, 274, 47), _guide_back, 23, PAPER)
	back.name = "GuideBackButton"
	var train := _button("対戦へ戻る" if _battle_page_active else "トレーニングへ", Rect2(358, 625, 362, 47), _close_battle_page if _battle_page_active else func(): show_select("training"), 25, YELLOW)
	train.name = "GuidePrimaryButton"
	back.focus_neighbor_right = back.get_path_to(train)
	train.focus_neighbor_left = train.get_path_to(back)
	for index: int in range(tabs.size()):
		tabs[index].focus_neighbor_left = tabs[index].get_path_to(tabs[posmod(index - 1, tabs.size())])
		tabs[index].focus_neighbor_right = tabs[index].get_path_to(tabs[(index + 1) % tabs.size()])
		tabs[index].focus_neighbor_bottom = tabs[index].get_path_to(content_buttons[0] if not content_buttons.is_empty() else back)
	for index: int in range(content_buttons.size()):
		var button := content_buttons[index]
		button.focus_neighbor_top = button.get_path_to(content_buttons[index - 1] if index > 0 else tabs[tab])
		button.focus_neighbor_bottom = button.get_path_to(content_buttons[index + 1] if index + 1 < content_buttons.size() else back)
		button.focus_neighbor_right = button.get_path_to(train)
	if tab == 2 and _screen.has_node("TrainingCharacterButton"):
		var choose: Button = _screen.get_node("TrainingCharacterButton")
		for recipe_id: String in _training_recipes:
			var course: Button = _screen.get_node("TrainingCourse_" + recipe_id)
			course.focus_neighbor_right = course.get_path_to(choose)
		choose.focus_neighbor_left = choose.get_path_to(_screen.get_node("TrainingCourse_" + _training_recipe))
		choose.focus_neighbor_bottom = choose.get_path_to(train)
	back.focus_neighbor_top = back.get_path_to(tabs[tab])
	train.focus_neighbor_top = train.get_path_to(tabs[tab])
	tabs[tab].grab_focus()
	_footer("F1 ガイド   ↑ ↓ ← → / Tab 項目   Enter / A 決定   Esc / B 戻る", "技は押し直す。長押しで連携にはなりません。")


func _guide_controls() -> void:
	var attack := _binding_name(0, 4)
	var up := _binding_name(0, 2)
	var down := _binding_name(0, 3)
	var skill := _binding_name(0, 7)
	var rows_left: Array = [
		[_binding_name(0, 0) + " / " + _binding_name(0, 1), "左右へ移動"],
		[down + "（長押し）", "削り5%・体力切れで崩れる。離すと後隙"],
		[up, "上方向（跳ばない）／防御中の左右は転身"],
		[attack + "（押し直す）", "許可中に連携。段数はキャラ別"],
		[down + "+" + attack, "下方向攻撃（地上防御中も可）"],
		[up + "+" + attack, "上方向攻撃。動作・派生はキャラ別"],
		[_binding_name(0, 5), "ジャンプ。空中でもう一度跳べる"],
		["倒れて弾んだ時 " + _binding_name(0, 6), "受け身：体力30。起き上がりを早める"],
		[_binding_name(0, 6), "瞬歩：地上は体力20、空中は30"],
		["横方向 + " + attack + ("/"+skill if source_bindings_enabled else ""), "地上で密着した相手を投げる"],
	]
	var rows_right: Array = [
		[skill, "メインスキル"],
		[up + "+" + skill, "上方向スキル"],
		[down + "+" + skill, "下方向スキル（地上防御中も可）"],
		["空中 " + attack + " / " + skill, "空中攻撃は1回。派生で追撃"],
		["空中 " + skill, "各キャラ専用の空中スキル"] if source_bindings_enabled else ["空中 " + down + "+" + skill, "空中スキル。方向派生はキャラ別"],
		[_binding_name(0, 8) + " / " + up + "+" + _binding_name(0, 8), "通常・上・空中必殺：気100" if source_bindings_enabled else "気100。上・空中必殺はキャラ別"],
		[down + "+" + _binding_name(0, 8), "大必殺：気300（地上防御中も可）"],
		[_binding_name(0, 9) + " / パッドLB", "被ダメ中の脱出：気100・体力50以上"],
		["Esc / Start", "一時停止"],
		["R / T（練習）", "位置リセット / 相手の防御切替"],
	]
	for side: int in range(2):
		var x := 76.0 + side * 594.0
		var rows: Array = rows_left if side == 0 else rows_right
		for index: int in range(rows.size()):
			_keycap(str(rows[index][0]), Rect2(x, 188 + index * 35, 179, 29), 16, YELLOW if index < 3 else BLUE)
			_label(str(rows[index][1]), Rect2(x + 190, 187 + index * 35, 371, 33), 17, INK)
	var p2_actions: Array[String] = []
	for action: int in range(4, 10):
		p2_actions.append(_binding_name(1, action) + " " + str(Data.CONTROL_LABELS[action]))
	_label("P2：" + _binding_name(1, 0) + " / " + _binding_name(1, 1) + " / " + _binding_name(1, 2) + " / " + _binding_name(1, 3) + " 方向   " + " / ".join(p2_actions), Rect2(77, 544, 1126, 24), 14, INK)
	_label("脱出は体力100を消費。50～99で使うと過負荷。必殺・ガード崩れからは脱出できない。", Rect2(77, 571, 1126, 24), 14, INK)
	_label("残像移動：" + down + "+" + _binding_name(0, 6) + " 横 / " + up + "+" + _binding_name(0, 6) + " 上 / 空中 " + down + "+" + _binding_name(0, 6) + " 下。気60・体力80、0.4秒無敵。", Rect2(77, 598, 1126, 24), 14, INK)


func _guide_character() -> void:
	var info: Dictionary = _roster[_guide_character_id]
	var choose := _button(str(info["name"]) + "  ›", Rect2(75, 186, 457, 45), func(): _guide_character_id = _ids[(_ids.find(_guide_character_id) + 1) % _ids.size()]; show_guide(1), 25, PAPER)
	choose.name = "GuideCharacterButton"
	_portrait(_guide_character_id, Rect2(83, 239, 288, 329), null, false, true)
	_pixel_preview(_guide_character_id, Rect2(366, 364, 172, 209))
	var timeline: Script = load("res://game/bvn_playable_timeline.gd")
	var stages := 0
	for index: int in range(1, 6):
		if not str(timeline.label_for_command(_guide_character_id, "attack%d" % index)).is_empty():
			stages = index
	_label("通常攻撃：最大%d段  /  許可中に押し直す" % stages, Rect2(559, 190, 642, 57), 23, INK)
	var actions := _guide_move_rows(_guide_character_id)
	for index: int in range(actions.size()):
		var row: Dictionary = actions[index]
		_keycap(row["input"], Rect2(565, 256 + index * 30, 153, 27), 15, RED if int(row["cost"]) > 0 else YELLOW)
		_label(row["name"], Rect2(743, 254 + index * 30, 301, 30), 18, MUTED)
		_label(row["use"], Rect2(1051, 254 + index * 30, 153, 30), 13, INK)
	_label(str(info.get("tactics", "空振りの隙に注意して、間合いを選ぼう。")), Rect2(80, 577, 1130, 31), 17, MUTED)


func _guide_move_rows(id: String) -> Array[Dictionary]:
	# UI describes only formal source labels available to this profile. No actor is
	# instantiated and no invented launcher/counter/projectile metadata is used.
	var timeline: Script = load("res://game/bvn_playable_timeline.gd")
	var info: Dictionary = _roster[id]
	var up := _binding_name(0, 2)
	var down := _binding_name(0, 3)
	var attack := _binding_name(0, 4)
	var skill := _binding_name(0, 7)
	var major := _binding_name(0, 8)
	var candidates: Array[Dictionary] = [
		{"id":"sweep", "input":down+"+"+attack, "name":str(info["sweep"]), "cost":0},
		{"id":"launcher", "input":up+"+"+attack, "name":str(info["launcher"]), "cost":0},
		{"id":"skill1", "input":skill, "name":str(info["moves"][0]), "cost":0},
		{"id":"skill2", "input":up+"+"+skill, "name":str(info["moves"][1]), "cost":0},
		{"id":"skill3", "input":down+"+"+skill, "name":str(info["moves"][2]), "cost":0},
		{"id":"air_skill", "input":"空中 "+skill, "name":"空中スキル", "cost":0},
		{"id":"super", "input":major, "name":str(info["super"]), "cost":100},
		{"id":"super_up", "input":up+"+"+major, "name":"空中争球！" if authored_skills_enabled and id=="chicken" else "上方向必殺", "cost":100},
		{"id":"super_down", "input":down+"+"+major, "name":str({"rio":"大剣、暴走します！","cat":"猫ミーム大炎上","worker":"残業、却下！","chicken":"ラストダンク","shark":"三足ワールドツアー"}.get(id,"大必殺")), "cost":300},
		{"id":"air_super", "input":"空中 "+major, "name":"空中必殺", "cost":100},
		{"id":"万解", "input":"未対応", "name":"変身", "cost":300},
	]
	var result: Array[Dictionary] = []
	for row in candidates:
		if source_bindings_enabled and str(row["id"])=="万解": continue
		var binding: Dictionary = load("res://game/bvn_skill_bindings.gd").binding_for(id,str(row["id"])) if source_bindings_enabled else {}
		var definition: Dictionary = timeline.definition(str(binding.get("donor_profile_id",id)),str(binding.get("entry_label",row["id"])))
		if definition.is_empty():
			continue
		row["use"] = _source_move_use(definition)
		if not binding.is_empty():
			row["name"] = str(binding["name_ja"])
			row["cost"] = int(binding["cost"])
			row["use"] = Data.SKILL_USES[id].get(str(row["id"]),row["use"])
		if authored_skills_enabled:
			var slot: int=["skill1","skill2","skill3"].find(str(row["id"]))
			if slot>=0: row["use"]=str(info["move_uses"][slot])
			elif row["id"] in ["super","super_down"]: row["use"]="反撃が成立すると追撃" if id=="worker" and row["id"]=="super" else "最初の命中で追撃"
			if id=="rio" and row["id"]=="super": row["use"]="重い剣を一度落とす"
		if int(row["cost"]) > 0:
			row["use"] = "気%d / %s" % [int(row["cost"]), row["use"]]
		result.append(row)
	return result


func _source_move_use(definition: Dictionary) -> String:
	var methods: Dictionary = {}
	for event in definition.get("events", []):
		for call in event.get("calls", []):
			if call.get("supported", false):
				methods[str(call.get("method", ""))] = true
	if methods.has("doWanKai"): return "変身（未対応）"
	if methods.has("setHurtAction"): return "被弾で派生"
	if methods.has("setHitTarget"): return "接触で派生"
	if methods.has("fire"): return "飛び道具"
	if methods.has("addAttacker"): return "独立攻撃"
	if methods.has("justHitToPlay"): return "命中で派生"
	if methods.has("setTouchFloor"): return "着地で派生"
	if methods.has("moveToTarget") or methods.has("moveOnce"): return "移動攻撃"
	if methods.has("setSteelBody"): return "一部で鋼体"
	return "前方を攻撃"


func _guide_training() -> void:
	for index: int in range(_training_recipes.size()):
		var recipe_id := _training_recipes[index]
		var info: Dictionary = Data.TRAINING_RECIPES[recipe_id]
		var button := _button(str(info["name"]), Rect2(76, 192 + index * 75, 454, 67), _select_training_guide_recipe.bind(recipe_id), 21, YELLOW if recipe_id == _training_recipe else PAPER)
		button.name = "TrainingCourse_" + recipe_id
		button.set_meta("training_recipe", recipe_id)
		button.visual.kind = "recipe"
		button.set_meta("selected", recipe_id == _training_recipe)
		_label(_training_input_caption(recipe_id, _guide_character_id, 416, 14), Rect2(17, 39, 416, 23), 14, MUTED, HORIZONTAL_ALIGNMENT_LEFT, button)
	var active: Dictionary = Data.TRAINING_RECIPES[_training_recipe]
	_label(str(active["name"]), Rect2(567, 192, 621, 42), 29, PAPER)
	var choose := _button(str(_roster[_guide_character_id]["name"]) + "  ›", Rect2(573, 239, 618, 43), _cycle_training_guide_character, 23, PAPER)
	choose.name = "TrainingCharacterButton"
	choose.tooltip_text = "キャラクターを切り替え、そのキャラクターの課題を確認します。"
	var input_caption := _training_input_caption(_training_recipe, _guide_character_id, 606, 27)
	var input_font := 27
	while input_font > 18 and ThemeDB.fallback_font.get_string_size(input_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, input_font).x > 606:
		input_font -= 1
	var input_label := _label(input_caption, Rect2(575, 292, 606, 53), input_font, INK)
	input_label.name = "TrainingInput"
	var route := _training_descriptor(_training_recipe, _guide_character_id)
	var hint := str(route.get("note", active["hint"])) if _training_recipe in ["full_normal", "hit_confirm"] else str(active["hint"])
	var hint_label := _label(hint, Rect2(575, 354, 606, 70), 19, PAPER)
	# _label assigns its initial rectangle before enabling autowrap. Restore
	# this local text width after its final font/wrap settings are in effect.
	hint_label.size = Vector2(606, 70)
	hint_label.name = "TrainingCondition"
	var steps := "① 十分に跳ぶ\n② 空中攻撃を入力\n③ 技の許可中に空中スキル"
	var note := "通常攻撃は命中、空中課題は合法な入力で進む。気・体力は満タン。命中・コンボは保証しません。"
	if _training_recipe == "normal_chain":
		steps = "① 間合いを合わせる\n② 許可中に押し直す\n③ 最初の三入力を試す"
	elif _training_recipe in ["full_normal", "hit_confirm"]:
		var lines: Array[String] = []
		for index: int in range(route.get("steps", []).size()):
			var step: Dictionary = route["steps"][index]
			var instruction := _training_step_key(step) + " を当てる"
			if str(step.get("kind", "")) == "branch" or int(step.get("key_slot", -1)) < 0:
				instruction = "命中時の自動追撃を確認（追加入力なし）"
			elif str(step.get("kind", "")) == "branch_hit":
				instruction += "（条件を満たした時）"
			lines.append("%d  %s" % [index + 1, instruction])
		steps = "\n".join(lines)
		note = "開始時は気300。以後は気・体力が実戦と同じ。Rリセット／Tガード切替。確定コンボの保証ではありません。"
	elif _training_recipe == "sparring":
		steps = "① CPUの動きを読む\n②「後隙 / 距離を確認」を読む\n③ 体力低下なら守り続けない"
		note = "後隙の表示は命中保証ではありません。Rでリセット／KOで再開。Tのガード固定は課題練習のみ。"
	var step_label := _label(steps, Rect2(578, 426, 598, 151), 20, PAPER)
	step_label.add_theme_constant_override("line_spacing", 0)
	step_label.name = "TrainingSteps"
	var note_label := _label(note, Rect2(77, 584, 1129, 31), 16, MUTED)
	note_label.name = "TrainingGuideNote"


func _cycle_training_guide_character() -> void:
	_guide_character_id = _ids[(_ids.find(_guide_character_id) + 1) % _ids.size()]
	show_guide(2)
	_screen.get_node("TrainingCharacterButton").grab_focus()


func _select_training_guide_recipe(recipe_id: String) -> void:
	_training_recipe = recipe_id
	show_guide(2)
	_screen.get_node("TrainingCourse_" + recipe_id).grab_focus()


func _guide_back() -> void:
	if _battle_page_active and _guide_return == "battle":
		_close_battle_page()
	elif _guide_return == "settings" or _guide_return == "controls":
		show_settings()
	elif _guide_return == "select":
		_build_select()
	else:
		show_home()


class PixelPreview extends Control:
	var fighter_id := "rio"
	var clip := "idle"
	var phase := 0.0
	var reduced_motion := false
	var _clock := 0.0
	var _pixel: Script

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if ResourceLoader.exists("res://game/pixel_fighter.gd"):
			_pixel = load("res://game/pixel_fighter.gd")
		set_process(true)

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(4, 0), Vector2(size.x, 0), Vector2(size.x - 4, size.y), Vector2(0, size.y)]), PAPER)
		draw_line(Vector2(6, size.y - 1), Vector2(size.x - 6, size.y - 1), AQUA, 2)
		if _pixel != null and _pixel.call("has_assets", fighter_id):
			var body_height := size.y * 0.73
			var origin_x := size.x * 0.5
			if fighter_id == "shark":
				body_height = minf(body_height, (size.x - 12.0) * 0.59)
			elif fighter_id == "rio":
				# The absurd blade extends far beyond the small adult fighter's body.
				body_height = minf(body_height, (size.x - 12.0) * 0.40)
				origin_x = size.x * 0.26
			draw_set_transform(Vector2(snappedf(origin_x, 2.0), snappedf(size.y - 23.0, 2.0)))
			_pixel.call("draw_fighter", self, fighter_id, clip, 0.0 if reduced_motion else _clock + phase, 1, Color.WHITE, body_height)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_rect(Rect2(size.x * 0.36, size.y * 0.2, size.x * 0.28, size.y * 0.52), BLUE)
		draw_string(ThemeDB.fallback_font, Vector2(7, size.y - 6), "バトル", HORIZONTAL_ALIGNMENT_LEFT, size.x - 12, 12, INK)


class HDRigPortrait extends Control:
	## The renderer owns layered artwork and its joint poses. This node owns only
	## menu timing, reaction state and a stationary foot origin; no master warp.
	var fighter_id := "rio"
	var rig_script: Script
	var base_clip := "idle"
	var performance_state := "loop"
	var clock_override := -1.0
	var phase := 0.0
	var reduced_motion := false
	var body_height := 0.0
	var facing := 1
	var foot_origin := Vector2.ZERO
	var fixed_layout := false
	var body_priority := false
	var _local_clock := 0.0
	var _reaction_left := 0.0
	var _reaction_duration := 0.24
	var _drawing: Node2D
	static var _union_cache: Dictionary = {}

	static func union_bounds(renderer: Script, id: String, direction: int) -> Rect2:
		var key := id + ":" + str(direction)
		if _union_cache.has(key):
			return _union_cache[key]
		var result := Rect2()
		if renderer != null and renderer.has_method("get_content_rect"):
			for clip: String in ["idle", "dance", "invite", "confirm", "easter"]:
				for frame: int in range(17):
					var bounds: Rect2 = renderer.call("get_content_rect", id, clip, float(frame) / 16.0, 100.0, direction)
					if bounds.has_area():
						result = result.merge(bounds) if result.has_area() else bounds
		if not result.has_area():
			result = Rect2(-40, -100, 80, 100)
		_union_cache[key] = result
		return result

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		clip_contents = not fixed_layout
		var bounds := union_bounds(rig_script, fighter_id, facing)
		if body_priority:
			body_height = minf(size.y - 28.0, (size.y - 16.0) * 100.0 / bounds.size.y)
			var scale := body_height / 100.0
			foot_origin = Vector2(size.x * 0.47, size.y - 8.0 - bounds.end.y * scale)
		elif not fixed_layout:
			var scale := minf((size.x - 14.0) / bounds.size.x, (size.y - 16.0) / bounds.size.y)
			body_height = scale * 100.0
			foot_origin = Vector2((size.x - bounds.size.x * scale) * 0.5 - bounds.position.x * scale, size.y - 8.0 - bounds.end.y * scale)
		else:
			# All home reactions share one fixed scale, calibrated once over the
			# full pose union; nothing follows an individual frame's changing bbox.
			var scale := body_height / 100.0
			if bounds.position.x < 0: scale = minf(scale, (foot_origin.x - 461.0) / -bounds.position.x)
			if bounds.end.x > 0: scale = minf(scale, (1268.0 - foot_origin.x) / bounds.end.x)
			if bounds.position.y < 0: scale = minf(scale, (foot_origin.y - 52.0) / -bounds.position.y)
			if bounds.end.y > 0: scale = minf(scale, (675.0 - foot_origin.y) / bounds.end.y)
			body_height = maxf(scale, 0.1) * 100.0
		set_meta("pose_union_at_height100", bounds)
		set_meta("representation", "hd_layered_illustration")
		set_meta("character_id", fighter_id)
		_drawing = HDRigDrawing.new()
		_drawing.name = "ArticulatedDrawing"
		_drawing.performer = self
		_drawing.position = foot_origin
		_drawing.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_drawing)
		set_process(true)

	func set_base_clip(value: String) -> void:
		base_clip = value
		queue_redraw()

	func react(kind: String, duration: float = 0.24) -> void:
		if performance_state == "confirm" and _reaction_left > 0.0:
			return
		performance_state = kind
		_reaction_duration = maxf(duration, 0.01)
		_reaction_left = _reaction_duration
		queue_redraw()

	func _process(delta: float) -> void:
		_local_clock += delta
		_reaction_left = maxf(_reaction_left - delta, 0.0)
		if _reaction_left <= 0.0:
			performance_state = "loop"
		if not is_visible_in_tree():
			return
		if is_instance_valid(_drawing):
			_drawing.queue_redraw()
		queue_redraw()

	func _pose_request() -> Dictionary:
		var clock := clock_override if clock_override >= 0.0 else _local_clock
		var clip := base_clip
		var progress := 0.0
		if performance_state in ["invite", "menu", "confirm", "easter"]:
			clip = "invite" if performance_state == "menu" else performance_state
			progress = 1.0 - _reaction_left / _reaction_duration
			# Reduced motion keeps an immediate, readable discrete feedback pose.
			if reduced_motion:
				progress = 0.85 if clip == "confirm" else 0.65
		elif performance_state == "celebrate":
			clip = "dance"
			progress = (clock + phase) / 0.75 if not reduced_motion else 0.0
		elif not reduced_motion:
			progress = (clock + phase) / (0.75 if clip == "dance" else 2.25)
		return {"clip": clip, "progress": progress}

	func ground_anchor() -> Vector2:
		return foot_origin

	func get_pose_state() -> Dictionary:
		var request := _pose_request()
		var pose: Dictionary = {}
		if rig_script != null and bool(rig_script.call("has_assets", fighter_id)):
			pose = rig_script.call("get_pose_state", fighter_id, request.clip, request.progress, body_height)
		var joints: Variant = pose.get("joints", pose.get("joint_positions", {}))
		pose["joint_count"] = int(pose.get("joint_count", joints.size() if joints is Dictionary or joints is Array else 0))
		pose["id"] = fighter_id
		pose["uses_hd_rig"] = true
		pose["state"] = performance_state
		pose["clip"] = request.clip
		pose["progress"] = request.progress
		pose["clock_seconds"] = clock_override if clock_override >= 0.0 else _local_clock
		pose["phase_seconds"] = phase
		pose["body_height"] = body_height
		pose["foot_origin"] = foot_origin
		pose["facing"] = facing
		var displayed_feet: Array[Vector2] = []
		for foot: Variant in pose.get("feet", []):
			if foot is Vector2:
				displayed_feet.append(global_position + foot_origin + Vector2(foot.x * facing, foot.y))
		pose["feet_canvas"] = displayed_feet
		var weapon_tip: Variant = pose.get("weapon_tip", Vector2.ZERO)
		if weapon_tip is Vector2:
			pose["weapon_tip_canvas"] = global_position + foot_origin + Vector2(weapon_tip.x * facing, weapon_tip.y)
		pose["reduced_motion"] = reduced_motion
		return pose

	func draw_rig(surface: CanvasItem) -> void:
		if rig_script == null or not bool(rig_script.call("has_assets", fighter_id)):
			return
		var request := _pose_request()
		rig_script.call("draw_character", surface, fighter_id, request.clip, request.progress, facing, Color.WHITE, body_height)


class HDRigDrawing extends Node2D:
	var performer: Control
	func _draw() -> void:
		if is_instance_valid(performer):
			performer.call("draw_rig", self)


class PartyHDCanvas extends Control:
	var master_art: Dictionary = {}
	var motion_metadata: Dictionary = {}
	var rig_script: Script
	var clock := 0.0
	var reduced_motion := false
	var performance_state := "loop"
	var rhythmic := true
	var frame_index := 0
	var motion_zone_count := 0
	var _actors: Array = []
	var _background_material: ShaderMaterial
	var _reaction_left := 0.0
	const ACTORS = [
		{"id":"worker", "foot":Vector2(601,471), "height":255.0, "facing":1, "rect":Rect2(522,214,152,259)},
		{"id":"shark", "foot":Vector2(710,445), "height":170.0, "facing":1, "rect":Rect2(483,274,264,172)},
		{"id":"cat", "foot":Vector2(595,651), "height":180.0, "facing":1, "rect":Rect2(515,459,135,194)},
		{"id":"chicken", "foot":Vector2(787,654), "height":190.0, "facing":1, "rect":Rect2(686,460,183,196)},
		{"id":"rio", "foot":Vector2(985,668), "height":560.0, "facing":1, "rect":Rect2(864,94,395,574)},
	]

	func _ready() -> void:
		var background := TextureRect.new()
		background.name = "HandPaintedPool"
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var path := "res://" + str(motion_metadata.get("background",{}).get("source","assets/art/home_pool_2d.png"))
		if ResourceLoader.exists("res://assets/art/visual_v18/pool_home.png"):
			path = "res://assets/art/visual_v18/pool_home.png"
		elif not ResourceLoader.exists(path):
			path = "res://assets/art/home_beach.png"
		if ResourceLoader.exists(path):
			background.texture = load(path)
		background.size = Vector2(1280,720)
		background.stretch_mode = TextureRect.STRETCH_SCALE
		background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.show_behind_parent = true
		if background.texture != null:
			_background_material = ShaderMaterial.new()
			_background_material.shader = HDStageShader
			_background_material.set_shader_parameter("canvas_size",background.texture.get_size())
			var backdrop: Dictionary = motion_metadata.get("background",{})
			var water: Array = backdrop.get("water_rect_source",[680,414,820,245])
			_background_material.set_shader_parameter("water_region",Vector4(float(water[0]),float(water[1]),float(water[2]),float(water[3])))
			var speaker_vectors := PackedVector4Array()
			for region: Array in backdrop.get("speaker_rects_source",[]):
				if region.size() == 4 and speaker_vectors.size() < 2:
					speaker_vectors.append(Vector4(float(region[0]),float(region[1]),float(region[2]),float(region[3])))
			while speaker_vectors.size() < 2:
				speaker_vectors.append(Vector4.ZERO)
			_background_material.set_shader_parameter("speaker_regions",speaker_vectors)
			background.material = _background_material
		add_child(background)
		var shadows := HDContactShadows.new()
		shadows.size = Vector2(1280,720)
		shadows.show_behind_parent = true
		shadows.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shadows)
		var party: Array = ACTORS.duplicate(true)
		for new_id: String in Data.STAGED_V034_IDS:
			if Data.is_selectable(new_id):
				var rect: Rect2 = Rect2(788,427,136,223) if new_id=="notify" else Rect2(915,345,135,228)
				party.append({"id":new_id,"height":rect.size.y,"rect":rect,"facing":1})
		for index: int in range(party.size()):
			var info: Dictionary = party[index]
			var id := str(info.id)
			var actor: Control
			if RosterPortraitV034.supports(id):
				var registered: Control = RosterPortraitV034.new()
				registered.configure(id,"home")
				registered.position = info.rect.position
				registered.size = info.rect.size
				actor = registered
			elif rig_script != null and bool(rig_script.call("has_assets", id)):
				var rig_actor := HDRigPortrait.new()
				rig_actor.fighter_id = id
				rig_actor.rig_script = rig_script
				rig_actor.fixed_layout = true
				rig_actor.body_height = float(info.height)
				rig_actor.foot_origin = info.foot
				rig_actor.facing = int(info.facing)
				rig_actor.base_clip = "dance"
				rig_actor.size = Vector2(1280,720)
				actor = rig_actor
			else:
				var atlas: AtlasTexture = master_art.get(id)
				if atlas == null:
					continue
				var fallback := HDPortrait.new()
				var profile: Dictionary = motion_metadata.get("characters",{}).get(id,{}).duplicate(true)
				profile["amplitude_space"] = motion_metadata.get("amplitude_space","")
				fallback.configure(id,atlas.atlas,atlas.region,profile)
				fallback.position = info.rect.position
				fallback.size = info.rect.size
				actor = fallback
			actor.name = id + "_HDPerformer"
			actor.phase = float(index)*0.5*60.0/MENU_BPM
			actor.clock_override = clock
			actor.reduced_motion = reduced_motion
			actor.show_behind_parent = true
			add_child(actor)
			_actors.append(actor)
			shadows.contacts.append({"point":actor.position + actor.ground_anchor(),"width":float(info.height) * (0.18 if id == "rio" else 0.27)})
		set_meta("representation","hd_illustration_party")
		set_meta("motion_mode","localized_illustration_animation")
		resized.connect(queue_redraw)
		theme_changed.connect(queue_redraw)
		queue_redraw()
		set_process(true)

	func react(kind: String, duration: float = 0.24, featured_id: String = "rio") -> void:
		if performance_state == "confirm" and _reaction_left > 0.0:
			return
		performance_state = kind
		_reaction_left = maxf(duration,0.01)
		for actor in _actors:
			if kind == "confirm" or actor.fighter_id == featured_id:
				actor.react(kind,duration)

	func cancel_idle_gag() -> void:
		if performance_state != "easter": return
		performance_state = "loop"
		_reaction_left = 0.0
		for actor in _actors:
			if actor.performance_state == "easter":
				actor.performance_state = "loop"
				actor.set("_reaction_left", 0.0)

	func _sync_performer_clock() -> void:
		for actor in _actors:
			actor.clock_override = clock
			actor.reduced_motion = reduced_motion

	func get_performer_states() -> Array:
		_sync_performer_clock()
		var result: Array = []
		motion_zone_count = 0
		for actor in _actors:
			var state: Dictionary = actor.get_pose_state()
			result.append(state)
			motion_zone_count += int(state.get("motion_zone_count",0))
		return result

	func _process(delta: float) -> void:
		_reaction_left = maxf(_reaction_left-delta,0.0)
		if _reaction_left == 0.0:
			performance_state = "loop"
		if not is_visible_in_tree():
			return
		if _background_material != null:
			_background_material.set_shader_parameter("music_seconds",clock)
			_background_material.set_shader_parameter("motion_strength",0.0 if reduced_motion else 1.0)
		_sync_performer_clock()
		frame_index = posmod(floori(clock / 0.75 * 8.0), 8)

	func _draw() -> void:
		# Independent printed paper, not a flattened concept screenshot. Every
		# button retains a fixed hit rectangle above this compositional layer.
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(512, 0), Vector2(460, 290), Vector2(416, 675), Vector2(0, 675)]), PAPER)
		var brush := PackedVector2Array([Vector2(509, 0), Vector2(520, 0), Vector2(485, 151), Vector2(489, 174), Vector2(476, 204), Vector2(480, 235), Vector2(467, 278), Vector2(466, 322), Vector2(453, 356), Vector2(451, 398), Vector2(441, 449), Vector2(444, 474), Vector2(430, 523), Vector2(432, 557), Vector2(416, 613), Vector2(418, 675), Vector2(400, 675), Vector2(442, 296)])
		draw_colored_polygon(brush, INK)
		for index: int in range(18):
			var y := float(index) * 38.0
			var x := 508.0 - y * 0.14
			draw_line(Vector2(x + 8, y), Vector2(x + 20, y - 14), INK, 1.3)
		for y: int in range(15, 673, 23):
			for x: int in range(8, 445 - y / 10, 23):
				draw_circle(Vector2(x, y), 0.7, Color(0.09, 0.23, 0.33, 0.065))
		draw_line(Vector2(35, 278), Vector2(419, 269), RED, 5)
		draw_colored_polygon(PackedVector2Array([Vector2(0, 257), Vector2(307, 193), Vector2(321, 211), Vector2(0, 285)]), Color(0.105, 0.69, 0.79, 0.25))
		draw_colored_polygon(PackedVector2Array([Vector2(467, 274), Vector2(480, 228), Vector2(489, 237), Vector2(474, 301)]), RED)
		draw_colored_polygon(PackedVector2Array([Vector2(438, 458), Vector2(451, 396), Vector2(462, 408), Vector2(447, 477)]), AQUA)
		draw_colored_polygon(PackedVector2Array([Vector2(922, 17), Vector2(1250, 17), Vector2(1239, 59), Vector2(911, 59)]), PAPER)
		draw_line(Vector2(923, 59), Vector2(1239, 59), INK, 2)
		draw_rect(Rect2(0, 675, 1280, 45), PAPER)
		draw_line(Vector2(23, 674), Vector2(1253, 674), INK, 1.5)


class HDContactShadows extends Control:
	var contacts: Array[Dictionary] = []
	func _draw() -> void:
		for contact: Dictionary in contacts:
			for ring: int in range(3):
				var points := PackedVector2Array()
				for vertex: int in range(24):
					var angle := float(vertex)/24.0*TAU
					points.append(contact.point+Vector2(cos(angle)*float(contact.width)*(0.45-float(ring)*0.075),sin(angle)*(5.0-float(ring))))
				draw_colored_polygon(points,Color(0.09,0.23,0.33,0.045))


class PixelPartyWorld extends Node2D:
	var clock := 0.0
	var reduced_motion := false
	var reaction := "loop"
	var reaction_progress := 0.0
	var _pixel: Script
	var _stage: Script
	const ACTORS = [
		{"id": "worker", "foot": Vector2(1088, 482), "height": 190.0, "facing": -1},
		{"id": "shark", "foot": Vector2(625, 480), "height": 129.0, "facing": 1},
		{"id": "rio", "foot": Vector2(859, 629), "height": 240.0, "facing": 1},
		{"id": "cat", "foot": Vector2(617, 651), "height": 166.0, "facing": 1},
		{"id": "chicken", "foot": Vector2(1137, 644), "height": 190.0, "facing": -1},
	]

	func _ready() -> void:
		if ResourceLoader.exists("res://game/pixel_fighter.gd"):
			_pixel = load("res://game/pixel_fighter.gd")
		if ResourceLoader.exists("res://game/pixel_stage.gd"):
			_stage = load("res://game/pixel_stage.gd")

	func _process(_delta: float) -> void:
		queue_redraw()

	func _pose(actor: Dictionary, index: int) -> Dictionary:
		var id := str(actor["id"])
		var clip := "dance"
		var progress := clock / 0.75 + float(index) * 0.25
		if reduced_motion:
			clip = "idle"
			progress = 0.0
		elif reaction == "confirm":
			clip = "confirm"
			progress = clampf(reaction_progress * 1.8, 0.0, 1.0)
		elif reaction in ["invite", "menu"] and id == "rio":
			clip = "invite"
			progress = reaction_progress
		return {"clip": clip, "progress": progress}

	func get_performer_states() -> Array:
		var result: Array = []
		if _pixel == null:
			return result
		for index: int in range(ACTORS.size()):
			var actor: Dictionary = ACTORS[index]
			var pose := _pose(actor, index)
			var state: Dictionary = _pixel.call("get_pose_state", str(actor["id"]), pose["clip"], pose["progress"])
			state["id"] = actor["id"]
			state["foot"] = actor["foot"]
			state["display_height"] = actor["height"]
			result.append(state)
		return result

	func _draw() -> void:
		if _stage != null:
			_stage.call("draw_stage", self, clock, reduced_motion)
		else:
			draw_rect(Rect2(0, 0, 1280, 720), BLUE)
		if _pixel == null:
			return
		for index: int in range(ACTORS.size()):
			var actor: Dictionary = ACTORS[index]
			var foot: Vector2 = actor["foot"]
			var height := float(actor["height"])
			draw_set_transform(foot)
			# Contact shadows are anchored in the same world as the moving knees and shoes.
			for line: int in range(4):
				draw_rect(Rect2(-height * 0.27 + line * 4, -4 + line * 4, height * 0.54 - line * 8, 4), Color(0.09, 0.23, 0.33, 0.11))
			var pose := _pose(actor, index)
			_pixel.call("draw_fighter", self, str(actor["id"]), pose["clip"], pose["progress"], int(actor["facing"]), Color.WHITE, height)
			draw_set_transform(Vector2.ZERO)
