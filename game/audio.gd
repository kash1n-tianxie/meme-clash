extends Node

var music: AudioStreamPlayer
var channels: Array[AudioStreamPlayer] = []
var track_name: String = ""
var channel_index: int = 0
var _duck_tween: Tween
const MUSIC_LEVEL := -9.0
const MIX_BUS := "MemeClashMix"
const MIX_CEILING_DB := -1.0
const SUPER_LEVEL := 0.0 # Existing -7 dB channel -> +7 dB; immutable WAV.
var last_duck_ms := -120
var sound_cache: Dictionary = {}
var _sound_rng := RandomNumberGenerator.new()
var _duck_priority := 0
var _duck_until_ms := 0
var _owns_mix_bus := false
## New material Foley has a separate bounded priority pool. Legacy J/UI voices
## and their immutable cache/channel sequence retain the existing contract.
const SKILL_VOICE_COUNT := 10
const SKILL_LOOP_COUNT := 2
var skill_sound_cache: Dictionary = {}
var skill_channels: Array[AudioStreamPlayer] = []
var _skill_voice_state: Array[Dictionary] = []
var _skill_layers: Dictionary = {}
var _skill_contact_gate: Dictionary = {}
var _skill_paused := false
var _skill_frozen := false
var _skill_pause_started_ms := -1
var _skill_epoch := 0
## stop() clears a player's local handles before the mixer and AudioServer's
## SafeList cleanup release their references. Remember every actual playback,
## including replaced tracks/voices, without keeping any playback alive.
var _playback_refs: Dictionary = {}
var _shutdown_started := false
var _shutdown_started_usec := 0
var _shutdown_blocked_requests := 0
var _playbacks_started := 0

func _ready() -> void:
	_sound_rng.randomize()
	_ensure_mix_bus()
	music = AudioStreamPlayer.new()
	music.bus = MIX_BUS
	music.volume_db = MUSIC_LEVEL
	add_child(music)
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.bus = MIX_BUS
		player.volume_db = -8.0
		add_child(player)
		channels.append(player)

## Only this game's mix is limited. Master still owns the user's volume/mute.
## The limiter catches overlapping voices; it does not change source clocks.
func _ensure_mix_bus() -> void:
	if AudioServer.get_bus_index(MIX_BUS) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, MIX_BUS)
	AudioServer.set_bus_send(index, "Master")
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = MIX_CEILING_DB
	limiter.pre_gain_db = 0.0
	limiter.release = 0.10
	AudioServer.add_bus_effect(index, limiter)
	_owns_mix_bus = true

func set_volume(value: float) -> void:
	AudioServer.set_bus_mute(0, value <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.0001)))

func play_music(track: String) -> void:
	if _reject_shutdown_request(): return
	if DisplayServer.get_name() == "headless":
		return
	if track_name == track and music.playing:
		return
	track_name = track
	_reset_duck()
	music.volume_db = MUSIC_LEVEL
	var path := "res://assets/audio/" + track + ".wav"
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStreamWAV = load(path)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	music.stream = stream
	music.play()
	_track_playback(music)

func play_sfx(kind: String) -> void:
	if _reject_shutdown_request(): return
	if DisplayServer.get_name() == "headless":
		return
	if channels.is_empty():
		return
	var path: String = sfx_path(kind)
	if not ResourceLoader.exists(path):
		return
	var player: AudioStreamPlayer = channels[channel_index]
	channel_index = (channel_index + 1) % channels.size()
	if not sound_cache.has(kind):
		sound_cache[kind] = load(path)
	player.stream = sound_cache[kind]
	player.volume_db = sfx_level_db(kind)
	player.pitch_scale = _pitch_scale(kind)
	player.play()
	_track_playback(player)
	if music.playing:
		var plan := _plan_music_duck(kind, player.stream.get_length(), Time.get_ticks_msec())
		if plan.is_empty():
			return
		if _duck_tween and _duck_tween.is_valid():
			_duck_tween.kill()
		music.volume_db = float(plan.level_db)
		_duck_tween = create_tween()
		_duck_tween.tween_interval(float(plan.hold_seconds))
		_duck_tween.tween_property(music, "volume_db", MUSIC_LEVEL, float(plan.release_seconds)).set_trans(Tween.TRANS_SINE)

static func sfx_level_db(kind: String) -> float:
	if kind == "super":
		return SUPER_LEVEL
	return -7.0 if kind in ["heavy", "land", "launch"] else -9.0

static func sfx_path(kind: String) -> String:
	return "res://assets/audio/v034/"+kind+".wav" if kind.begins_with("v034_") else "res://assets/audio/"+kind+".wav"

func _pitch_scale(kind: String) -> float:
	# Do not advance @GlobalScope's RNG used by source CPU/other battle code.
	return _sound_rng.randf_range(0.97, 1.03) if kind in ["hit", "blade", "paw", "shoe", "ball", "case"] else 1.0

## A small deterministic envelope also used by the headless audio regression.
## Repeated ordinary impacts cannot truncate a still-playing super explosion.
func _plan_music_duck(kind: String, duration: float, now_ms: int) -> Dictionary:
	if kind not in ["heavy", "super", "launch", "land", "counter"]:
		return {}
	var priority := 2 if kind == "super" else 1
	if now_ms < _duck_until_ms and priority < _duck_priority:
		return {}
	if priority == 1 and now_ms - last_duck_ms < 120:
		return {}
	var total_seconds := clampf(duration, 0.25, 0.8) if priority == 2 else 0.145
	var release_seconds := 0.16 if priority == 2 else 0.10
	last_duck_ms = now_ms
	_duck_priority = priority
	_duck_until_ms = now_ms + ceili(total_seconds * 1000.0)
	return {"level_db": MUSIC_LEVEL - (5.0 if priority == 2 else 3.0),
		"hold_seconds": total_seconds - release_seconds, "release_seconds": release_seconds,
		"total_seconds": total_seconds, "until_ms": _duck_until_ms, "priority": priority}

func _reset_duck() -> void:
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_priority = 0
	_duck_until_ms = 0
	last_duck_ms = -120

## Cache immutable streams before the match countdown, without selecting a
## channel, starting playback, changing levels or sampling random pitch.
func prewarm_sfx(kinds: Array) -> void:
	for kind: String in kinds:
		if sound_cache.has(kind):
			continue
		var path: String = sfx_path(kind)
		if ResourceLoader.exists(path):
			sound_cache[kind] = load(path)

## Skill prewarm is silent: never allocates a player, samples random pitch,
## consumes a combat clock or changes the original sixteen-SFX cache.
func prewarm_skill_sfx(kinds: Array) -> void:
	for value: Variant in kinds:
		var key: String=str(value)
		if skill_sound_cache.has(key): continue
		var catalog_script: Script=load("res://game/bvn_skill_audio_v029.gd")
		var path: String=str(catalog_script.catalog().get("assets",{}).get(key,{}).get("path","res://assets/audio/v029/"+key+".wav"))
		if ResourceLoader.exists(path): skill_sound_cache[key]=load(path)

## Reserve the existing bounded pool silently before an actual source match.
## No stream assignment/playback, music duck, channel rotation or RNG sample.
func prewarm_skill_voice_pool() -> void:
	_ensure_skill_channels()

func _ensure_skill_channels() -> void:
	if not skill_channels.is_empty(): return
	for index in range(SKILL_VOICE_COUNT):
		var player:=AudioStreamPlayer.new()
		player.bus=MIX_BUS
		add_child(player)
		skill_channels.append(player)
		_skill_voice_state.append({"until_ms":0,"priority":-1,"loop_key":"","epoch":0})

## A high-priority real finale can replace a quieter preparation/release. A
## preparation cannot truncate a confirmed impact or an existing finale.
static func choose_skill_voice(states: Array, now_ms: int, priority: int) -> int:
	for index in range(states.size()):
		if str(states[index].get("loop_key",""))=="" and int(states[index].get("until_ms",0))<=now_ms: return index
	var slot: int=-1
	var lowest: int=priority
	var oldest: int=2147483647
	for index in range(states.size()):
		var state: Dictionary=states[index]
		if not str(state.get("loop_key","")).is_empty(): continue
		var candidate_priority: int=int(state.get("priority",-1))
		var candidate_until: int=int(state.get("until_ms",0))
		if candidate_priority<lowest or (candidate_priority==lowest and candidate_until<oldest):
			slot=index; lowest=candidate_priority; oldest=candidate_until
	return slot

## Native stream_paused halts audio playback position, while Time's wall clock
## still moves. Preserve the remaining tail/priority of voices active at pause.
## This is a pure audio deadline transform, never a battle/source clock change.
static func resume_skill_voice_deadlines(states: Array, pause_started_ms: int, now_ms: int) -> Array:
	var result: Array=states.duplicate(true)
	var elapsed: int=maxi(0,now_ms-pause_started_ms)
	if pause_started_ms<0 or elapsed<=0: return result
	for state: Dictionary in result:
		if not str(state.get("loop_key","")).is_empty(): continue
		var deadline: int=int(state.get("until_ms",0))
		if deadline>pause_started_ms: state["until_ms"]=deadline+elapsed
	return result

func _skill_stream(key: String) -> AudioStreamWAV:
	if not skill_sound_cache.has(key): prewarm_skill_sfx([key])
	return skill_sound_cache.get(key)

func play_skill_cue(cue: Dictionary) -> bool:
	if _reject_shutdown_request(): return false
	if DisplayServer.get_name()=="headless" or _skill_paused: return false
	var key: String=str(cue.get("key",""))
	var stream:=_skill_stream(key)
	if stream==null: return false
	var now: int=Time.get_ticks_msec()
	var phase: String=str(cue.get("phase",""))
	# Source contacts remain observable. At most one audible ordinary material
	# impact per owner per 65 ms prevents dense paper/claw chains from drowning
	# their motion; a confirmed finale is never suppressed by this small gate.
	if phase in ["impact","guard"]:
		var gate: String=str(cue.get("owner_index",0))+":"+phase
		if now-int(_skill_contact_gate.get(gate,-9999))<65: return false
		_skill_contact_gate[gate]=now
	_ensure_skill_channels()
	var priority: int=int(cue.get("priority",1))
	var slot: int=choose_skill_voice(_skill_voice_state,now,priority)
	if slot<0: return false
	var player: AudioStreamPlayer=skill_channels[slot]
	player.stop()
	player.stream=stream
	player.volume_db=clampf(float(cue.get("gain_db",-9.0)),-24.0,0.0)
	player.pitch_scale=clampf(float(cue.get("pitch",1.0)),.8,1.2)
	player.stream_paused=false
	player.play()
	_track_playback(player)
	_skill_epoch+=1
	_skill_voice_state[slot]={"until_ms":now+ceili(stream.get_length()/player.pitch_scale*1000.0),"priority":priority,"loop_key":"","epoch":_skill_epoch}
	var duck: String=str(cue.get("music_duck",""))
	if music.playing and not duck.is_empty():
		var plan:=_plan_music_duck(duck,stream.get_length(),now)
		if not plan.is_empty():
			if _duck_tween and _duck_tween.is_valid(): _duck_tween.kill()
			music.volume_db=float(plan.level_db)
			_duck_tween=create_tween()
			_duck_tween.tween_interval(float(plan.hold_seconds))
			_duck_tween.tween_property(music,"volume_db",MUSIC_LEVEL,float(plan.release_seconds)).set_trans(Tween.TRANS_SINE)
	return true

func set_skill_layer(layer_key: String,cue: Dictionary,active: bool) -> void:
	if _reject_shutdown_request(): return
	if DisplayServer.get_name()=="headless": return
	if not active:
		_fade_skill_layer(layer_key)
		return
	if _skill_layers.has(layer_key): return
	# Two simultaneous sustained layers at most; prefer each owner's own active
	# actor/object rather than creating a layer for every paper/ball fragment.
	var owner: int=int(cue.get("owner_index",0))
	for existing: String in _skill_layers:
		if int(_skill_layers[existing].get("owner",-1))==owner: return
	if _skill_layers.size()>=SKILL_LOOP_COUNT: return
	var original:=_skill_stream(str(cue.get("key","")))
	if original==null: return
	_ensure_skill_channels()
	var now: int=Time.get_ticks_msec()
	var slot: int=choose_skill_voice(_skill_voice_state,now,1)
	if slot<0: return
	var stream: AudioStreamWAV=original.duplicate()
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin=0
	stream.loop_end=ceili(stream.get_length()*stream.mix_rate)
	var player: AudioStreamPlayer=skill_channels[slot]
	player.stop(); player.stream=stream; player.pitch_scale=1.0; player.volume_db=-45.0
	player.stream_paused=false; player.play()
	_track_playback(player)
	_skill_epoch+=1
	_skill_voice_state[slot]={"until_ms":2147483647,"priority":1,"loop_key":layer_key,"epoch":_skill_epoch}
	var fade:=create_tween()
	fade.tween_property(player,"volume_db",clampf(float(cue.get("gain_db",-10.0)),-24.0,-6.0),.065)
	_skill_layers[layer_key]={"slot":slot,"owner":owner,"tween":fade,"epoch":_skill_epoch}
	player.stream_paused=_skill_paused or _skill_frozen

func _fade_skill_layer(layer_key: String) -> void:
	if not _skill_layers.has(layer_key): return
	var layer: Dictionary=_skill_layers[layer_key]
	var slot: int=int(layer.slot)
	var player: AudioStreamPlayer=skill_channels[slot]
	var previous: Variant=layer.get("tween")
	if previous!=null and previous.is_valid(): previous.kill()
	var epoch: int=int(layer.epoch)
	_skill_layers.erase(layer_key)
	# Unpause a retired layer so its 90 ms fade completes during hit freeze.
	player.stream_paused=false
	var fade:=create_tween()
	fade.tween_property(player,"volume_db",-50.0,.09)
	fade.tween_callback(func() -> void:
		if not is_instance_valid(player) or int(_skill_voice_state[slot].epoch)!=epoch: return
		player.stop(); player.stream=null
		_skill_voice_state[slot]={"until_ms":0,"priority":-1,"loop_key":"","epoch":epoch}
	)

## Pause stops all skill voices. Hit freeze pauses only continuous layers, so
## the newly confirmed impact transient can sound once during the freeze.
func set_skill_suspended(paused: bool,frozen: bool=false) -> void:
	if paused and not _skill_paused:
		_skill_pause_started_ms=Time.get_ticks_msec()
	elif not paused and _skill_paused:
		var resumed: Array=resume_skill_voice_deadlines(_skill_voice_state,_skill_pause_started_ms,Time.get_ticks_msec())
		for index in range(resumed.size()): _skill_voice_state[index]=resumed[index]
		_skill_pause_started_ms=-1
	_skill_paused=paused; _skill_frozen=frozen
	for index in range(skill_channels.size()):
		var loop: bool=not str(_skill_voice_state[index].get("loop_key","")).is_empty()
		skill_channels[index].stream_paused=paused or (frozen and loop)

func stop_skill_sfx() -> void:
	for key: String in _skill_layers:
		var tween: Variant=_skill_layers[key].get("tween")
		if tween!=null and tween.is_valid(): tween.kill()
	_skill_layers.clear(); _skill_contact_gate.clear()
	_skill_paused=false; _skill_frozen=false; _skill_pause_started_ms=-1
	for index in range(skill_channels.size()):
		skill_channels[index].stop(); skill_channels[index].stream=null; skill_channels[index].stream_paused=false
		_skill_epoch+=1
		_skill_voice_state[index]={"until_ms":0,"priority":-1,"loop_key":"","epoch":_skill_epoch}

func _exit_tree() -> void:
	stop_all()
	if _owns_mix_bus:
		var index := AudioServer.get_bus_index(MIX_BUS)
		if index >= 0:
			AudioServer.remove_bus(index)
		_owns_mix_bus = false

func stop_all() -> void:
	_reset_duck()
	stop_skill_sfx()
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	for player in channels:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func _reject_shutdown_request() -> bool:
	if not _shutdown_started: return false
	_shutdown_blocked_requests += 1
	return true

func _track_playback(player: AudioStreamPlayer) -> void:
	_prune_playbacks()
	if not player.has_stream_playback(): return
	var playback: AudioStreamPlayback = player.get_stream_playback()
	var identity: int = playback.get_instance_id()
	if _playback_refs.has(identity): return
	_playback_refs[identity] = weakref(playback)
	_playbacks_started += 1

func _prune_playbacks() -> int:
	for identity: int in _playback_refs.keys():
		if _playback_refs[identity].get_ref() == null:
			_playback_refs.erase(identity)
	return _playback_refs.size()

## Terminal only: normal menu/match stop_all() retains its reusable semantics.
## Gate late signals/callbacks before requesting all current playbacks to stop.
func begin_shutdown() -> void:
	if _shutdown_started: return
	_shutdown_started = true
	_shutdown_started_usec = Time.get_ticks_usec()
	if is_instance_valid(music): _track_playback(music)
	for player: AudioStreamPlayer in channels:
		if is_instance_valid(player): _track_playback(player)
	for player: AudioStreamPlayer in skill_channels:
		if is_instance_valid(player): _track_playback(player)
	stop_all()

func shutdown_status() -> Dictionary:
	var pending: int = _prune_playbacks()
	return {"started": _shutdown_started, "drained": _shutdown_started and pending == 0,
		"pending": pending, "pending_ids": _playback_refs.keys(),
		"started_playbacks": _playbacks_started, "blocked_requests": _shutdown_blocked_requests,
		"elapsed_usec": Time.get_ticks_usec() - _shutdown_started_usec if _shutdown_started else 0}

## Let the real mixer erase retired nodes and the normal main-loop AudioServer
## update reclaim them. Never infer disposal from playing=false or a mix clock.
## The bound is a failure deadline, not a cleanup sleep or success criterion.
func drain_shutdown(timeout_seconds: float = 1.0) -> Dictionary:
	begin_shutdown()
	var deadline_usec: int = Time.get_ticks_usec() + ceili(clampf(timeout_seconds, 0.0, 5.0) * 1000000.0)
	while _prune_playbacks() > 0 and Time.get_ticks_usec() < deadline_usec:
		if not is_inside_tree(): break
		await get_tree().process_frame
	var result: Dictionary = shutdown_status()
	result["timed_out"] = not bool(result.drained)
	if not bool(result.drained):
		push_error("Audio shutdown timed out with actual playbacks still alive: " + str(result.pending_ids))
	return result
