extends Node2D

const Data = preload("res://game/data.gd")
const MENU_CANVAS := Vector2i(1280, 720)
const BATTLE_CANVAS := Vector2i(800, 600)
const BATTLE_WINDOW := Vector2i(960, 720)
const BATTLE_PROJECTION := 0.625 # Battle's HD 1280 x 960 canvas -> canonical BVN 800 x 600.
var ui: Control
var battle: Node2D
var last_match: Dictionary = {"p1": "shark", "p2": "chicken", "mode": "cpu", "difficulty": "normal"}
var settings: Dictionary = {"volume": 0.55, "shake": true, "flash": true, "reduced_motion": false, "bindings_p1": Data.DEFAULT_P1.duplicate(), "bindings_p2": Data.DEFAULT_P2.duplicate()}
var training_recipe := "normal_chain"
var last_selection_flow: Dictionary = {}
var _capture_path: String = ""
var _quitting := false
var _demo := false
var _demo_clock := 0.0
var _demo_index := 0
var _session_clock := 0.0
var _record_seconds := 0.0
var _battle_presentation := false
var _menu_window_state: Dictionary = {}
var _vs_match: Dictionary = {}
var _paused_page_state: Dictionary = {}
var _menu_windowed_size := MENU_CANVAS
var _menu_windowed_position := Vector2i.ZERO
const DEMO_ACTIONS := [[0.8,"jump"],[2.0,"attack"],[3.2,"launcher"],[4.5,"skill1"],[5.9,"skill2"],[7.3,"skill3"],[8.8,"super"]]

func _ready() -> void:
	_remember_menu_windowed_geometry()
	TranslationServer.set_locale("ja")
	DisplayServer.window_set_title("%s v%s" % [Data.TITLE, Data.VERSION])
	get_tree().auto_accept_quit = false
	var theme_resource: Theme = load("res://assets/theme.tres")
	ThemeDB.fallback_font = theme_resource.default_font
	_load_settings()
	ui = load("res://game/ui.gd").new()
	ui.name = "Interface"
	ui.theme = theme_resource
	add_child(ui)
	ui.start_requested.connect(_begin_vs)
	ui.vs_start_requested.connect(_finish_vs)
	ui.vs_cancelled.connect(func(): _vs_match.clear())
	ui.battle_page_closed.connect(_close_pause_page)
	ui.quit_requested.connect(_quit_game)
	ui.settings_changed.connect(_apply_settings)
	ui.training_recipe_requested.connect(func(recipe: String): training_recipe = recipe)
	var battle_script: Script = load("res://game/battle.gd")
	var battle_constants := battle_script.get_script_constant_map()
	if battle_constants.get("TRAINING_AVAILABLE") is Array:
		ui.call("set_available_training_recipes", battle_constants["TRAINING_AVAILABLE"])
	ui.call("show_home")
	GameAudio.play_music("menu")
	call_deferred("_preview_arguments")

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		for key in settings:
			settings[key] = cfg.get_value("settings", key, settings[key])
	_apply_settings(settings)

func _apply_settings(values: Dictionary) -> void:
	settings.merge(values, true)
	GameAudio.set_volume(float(settings.get("volume", 0.55)))
	if is_instance_valid(battle):
		battle.call("set_feedback_options", bool(settings.get("shake", true)), bool(settings.get("flash", true)))
		battle.call("set_reduced_motion", bool(settings.get("reduced_motion", false)))
		_apply_bindings_to_battle()


func _apply_bindings_to_battle() -> void:
	if not is_instance_valid(battle) or not battle.has_method("set_key_bindings"):
		return
	var first: Variant = settings.get("bindings_p1", Data.DEFAULT_P1)
	var second: Variant = settings.get("bindings_p2", Data.DEFAULT_P2)
	if not first is Array or first.size() != Data.CONTROL_ACTIONS.size():
		first = Data.DEFAULT_P1.duplicate()
	if not second is Array or second.size() != Data.CONTROL_ACTIONS.size():
		second = Data.DEFAULT_P2.duplicate()
	battle.call("set_key_bindings", first, second)

func _begin_vs(p1_id: String, p2_id: String, mode: String, difficulty: String = "normal") -> void:
	if _quitting or is_instance_valid(battle) or not _vs_match.is_empty() or not _paused_page_state.is_empty(): return
	_vs_match = {"p1": p1_id, "p2": p2_id, "mode": mode, "difficulty": difficulty}
	ui.show_vs(p1_id, p2_id, mode, difficulty)


func _finish_vs() -> void:
	if _quitting or _vs_match.is_empty(): return
	var match_data: Dictionary = _vs_match.duplicate()
	_vs_match.clear()
	_start_match(str(match_data.p1), str(match_data.p2), str(match_data.mode), str(match_data.difficulty))


func _start_match(p1_id: String, p2_id: String, mode: String, difficulty: String = "normal") -> void:
	if is_instance_valid(ui) and ui.has_method("get_select_flow_state"):
		last_selection_flow = ui.call("get_select_flow_state")
	_vs_match.clear()
	ui.set("_vs_active", false)
	_remove_battle()
	last_match = {"p1": p1_id, "p2": p2_id, "mode": mode, "difficulty": difficulty}
	ui.hide()
	ui.process_mode = Node.PROCESS_MODE_DISABLED
	_enter_battle_presentation()
	battle = load("res://game/battle.gd").new()
	battle.authored_skills_enabled=ui.authored_skills_enabled
	battle.source_bindings_enabled=ui.source_bindings_enabled
	battle.name = "Battle"
	battle.scale = Vector2.ONE * BATTLE_PROJECTION
	add_child(battle)
	battle.match_finished.connect(_match_finished)
	battle.exit_requested.connect(_leave_match)
	if battle.has_signal("pause_page_requested"):
		battle.connect("pause_page_requested", _open_pause_page)
	battle.call("setup", p1_id, p2_id, mode, difficulty)
	battle.call("set_feedback_options", bool(settings.get("shake", true)), bool(settings.get("flash", true)))
	battle.call("set_reduced_motion", bool(settings.get("reduced_motion", false)))
	_apply_bindings_to_battle()
	if mode == "training" and battle.has_method("set_training_recipe"):
		battle.call("set_training_recipe", training_recipe)
	GameAudio.play_music("battle")

func _match_finished(winner_index: int) -> void:
	var summary: Dictionary = battle.call("get_match_summary") if is_instance_valid(battle) and battle.has_method("get_match_summary") else {}
	var winner_id: String = str(last_match["p1"] if winner_index == 0 else last_match["p2"])
	_remove_battle()
	_restore_menu_presentation()
	ui.show()
	ui.process_mode = Node.PROCESS_MODE_INHERIT
	ui.call("show_result", "引き分け" if winner_index < 0 else Data.ROSTER[winner_id]["name"], summary)
	GameAudio.play_music("menu")

func _leave_match() -> void:
	_remove_battle()
	_restore_menu_presentation()
	ui.show()
	ui.process_mode = Node.PROCESS_MODE_INHERIT
	ui.call("show_select", last_match["mode"])
	GameAudio.play_music("menu")

func _open_pause_page(page: String) -> void:
	if page not in ["skills", "settings"] or not is_instance_valid(battle) or not bool(battle.get("paused")) or not _paused_page_state.is_empty(): return
	_paused_page_state = {"instance": battle.get_instance_id(), "process_mode": battle.process_mode, "paused": bool(battle.get("paused")), "visible": battle.visible}
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	battle.hide()
	_restore_menu_presentation()
	ui.process_mode = Node.PROCESS_MODE_INHERIT
	ui.show()
	ui.show_battle_page(page, str(last_match.p1), str(last_match.p2))


func _close_pause_page() -> void:
	if _paused_page_state.is_empty(): return
	var original: Dictionary = _paused_page_state.duplicate()
	_paused_page_state.clear()
	ui.hide()
	ui.process_mode = Node.PROCESS_MODE_DISABLED
	if not is_instance_valid(battle) or battle.get_instance_id() != int(original.instance): return
	_enter_battle_presentation()
	_apply_settings(ui.get_settings())
	# Reapply bindings clears the existing raw-input latches, as regular pause
	# already clears queued commands; it never changes the actor's source clock.
	battle.set("paused", bool(original.paused))
	battle.visible = bool(original.visible)
	battle.process_mode = int(original.process_mode)
	battle.queue_redraw()


func _remove_battle() -> void:
	_paused_page_state.clear()
	if is_instance_valid(ui): ui.clear_battle_page_context()
	if is_instance_valid(battle):
		battle.hide()
		battle.process_mode = Node.PROCESS_MODE_DISABLED
		battle.queue_free()
		battle = null


static func _is_fullscreen_mode(mode: Window.Mode) -> bool:
	return mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]


func _remember_menu_windowed_geometry() -> void:
	var window := get_window()
	if not _battle_presentation and window.mode == Window.MODE_WINDOWED:
		_menu_windowed_size = window.size
		_menu_windowed_position = window.position


func _enter_battle_presentation() -> void:
	var window := get_window()
	if not _battle_presentation:
		_remember_menu_windowed_geometry()
		_menu_window_state = {
			"size": _menu_windowed_size,
			"position": _menu_windowed_position,
			"min_size": window.min_size,
			"content_scale_size": window.content_scale_size,
			"content_scale_mode": window.content_scale_mode,
			"content_scale_aspect": window.content_scale_aspect,
		}
	_battle_presentation = true
	window.content_scale_size = BATTLE_CANVAS
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	# The browser owns the physical canvas; changing its window size leaves
	# stale pixels outside the resized WebGL drawing area on WebKit.
	if not OS.has_feature("web"):
		window.min_size = BATTLE_CANVAS
	_apply_windowed_presentation_size()


func _restore_menu_presentation() -> void:
	if not _battle_presentation:
		return
	var window := get_window()
	_battle_presentation = false
	if not OS.has_feature("web"):
		window.min_size = _menu_window_state.get("min_size", Vector2i(800, 450))
	window.content_scale_size = _menu_window_state.get("content_scale_size", MENU_CANVAS)
	window.content_scale_mode = _menu_window_state.get("content_scale_mode", Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	window.content_scale_aspect = _menu_window_state.get("content_scale_aspect", Window.CONTENT_SCALE_ASPECT_KEEP)
	# Preserve fullscreen/maximized mode. Only restore a normal window's geometry.
	if not OS.has_feature("web") and window.mode == Window.MODE_WINDOWED:
		window.size = _menu_window_state.get("size", _menu_windowed_size)
		window.position = _menu_window_state.get("position", _menu_windowed_position)
	_menu_window_state.clear()


func _apply_windowed_presentation_size() -> void:
	if OS.has_feature("web"):
		return
	var window := get_window()
	if window.mode != Window.MODE_WINDOWED:
		return
	if _battle_presentation:
		var previous_center := window.position + window.size / 2
		window.size = BATTLE_WINDOW
		window.position = previous_center - window.size / 2
	else:
		window.size = _menu_windowed_size
		window.position = _menu_windowed_position


func get_presentation_state() -> Dictionary:
	var window := get_window()
	return {
		"scene": "battle" if _battle_presentation else "menu",
		"canvas_size": window.content_scale_size,
		"window_size": window.size,
		"min_size": window.min_size,
		"scale_mode": window.content_scale_mode,
		"scale_aspect": window.content_scale_aspect,
		"window_mode": window.mode,
		"fullscreen": _is_fullscreen_mode(window.mode),
		"battle_projection": battle.scale if is_instance_valid(battle) else Vector2.ONE,
		"saved_menu": _menu_window_state.duplicate(),
	}

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var window := get_window()
		var full := _is_fullscreen_mode(window.mode)
		if not full:
			_remember_menu_windowed_geometry()
		window.mode = Window.MODE_WINDOWED if full else Window.MODE_FULLSCREEN
		if full:
			_apply_windowed_presentation_size.call_deferred()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()

func _quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	_vs_match.clear()
	set_process(false)
	set_process_unhandled_input(false)
	if is_instance_valid(ui):
		ui.set("_vs_active", false)
		ui.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(battle): battle.process_mode = Node.PROCESS_MODE_DISABLED
	GameAudio.begin_shutdown()
	var audio_exit: Dictionary = await GameAudio.drain_shutdown()
	# A failed disposal deadline is observable; do not turn it into a clean exit.
	get_tree().quit(0 if bool(audio_exit.drained) else 1)

# Development previews use the actual production scenes and renderer.
func _preview_arguments() -> void:
	var screen := ""
	var first := "shark"
	var second := "chicken"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview="):
			screen = arg.trim_prefix("--preview=")
		if arg.begins_with("--capture="):
			_capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--p1="):
			first = arg.trim_prefix("--p1=")
		if arg.begins_with("--p2="):
			second = arg.trim_prefix("--p2=")
		if arg == "--demo":
			_demo = true
		if arg.begins_with("--record-seconds="):
			_record_seconds = maxf(0.0, float(arg.trim_prefix("--record-seconds=")))
	if screen in ["select", "select-ready"]:
		ui.set("_p1", first)
		ui.set("_p2", second)
		ui.call("show_select", "cpu")
		if screen == "select-ready":
			ui.call("_choose_character", first)
			ui.call("_choose_character", second)
	elif screen == "settings":
		ui.call("show_settings")
	elif screen == "guide":
		ui.call("show_guide")
	elif screen in ["controls", "keybindings"]:
		ui.call("show_controls")
	elif screen == "result":
		# Populate the same rematch context that a completed selection normally supplies.
		ui.set("_last_match", {"p1": first, "p2": second, "mode": "cpu", "difficulty": "normal"})
		ui.call("show_result", str(Data.ROSTER[first]["name"]))
	elif screen == "reduced":
		ui.get("_settings")["reduced_motion"] = true
		ui.call("show_home")
	elif screen == "hover":
		ui.call("debug_home_feedback", 1)
	elif screen in ["fight", "pause"]:
		_start_match(first, second, "training" if _demo else "local", "normal")
		if _demo:
			battle.phase = "active"
			for i in range(2):
				battle.fighters[i].reset_round(550.0 + 130.0*i)
				battle.fighters[i].hype = 100.0
		if screen == "pause":
			battle.phase = "active"
			battle.paused = true
	if not _capture_path.is_empty():
		await get_tree().create_timer(1.0 if screen != "fight" else 3.5).timeout
		if screen == "hover":
			ui.call("debug_home_feedback", 0)
			await get_tree().create_timer(0.12).timeout
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png(_capture_path)
		print("CAPTURE_SAVED ", _capture_path)
		if "--auto-quit" in OS.get_cmdline_user_args():
			_quit_game()

# Engine-rendered action showcases exercise the same attacks, collisions, audio and VFX.
func _process(delta: float) -> void:
	_session_clock += delta
	if _record_seconds > 0.0 and _session_clock >= _record_seconds and not _quitting:
		_quit_game()
	if not _demo or not is_instance_valid(battle) or _demo_index >= DEMO_ACTIONS.size():
		return
	_demo_clock += delta
	var cue: Array = DEMO_ACTIONS[_demo_index]
	if _demo_clock < float(cue[0]):
		return
	for i in range(2):
		battle.fighters[i].reset_round(550.0 + 130.0*i)
		battle.fighters[i].hype = 100.0
	battle.projectiles.clear()
	battle.training_reset_time = 0.0
	battle.debug_action(0, str(cue[1]))
	_demo_index += 1
