extends RefCounted
## Read-only material Foley, tied to accepted source frames / actual objects / contacts.
## No battle mutation, clock advancement, input, source RNG or HitVO synthesis.
const SkillFX = preload("res://game/bvn_skill_fx.gd")
const Data = preload("res://game/data.gd")
const CATALOG_PATH := "res://assets/audio/v032/catalog.json"
const ADDITIONAL_CATALOG_PATH := "res://assets/audio/v034/catalog.json"
const COMMANDS := ["skill1","skill2","skill3","air_skill","super","super_up","super_down","air_super"]
const PHASE_PRIORITY := {"prepare":1,"charge":2,"release":3,"sustain":1,"impact":4,"finale":6,"guard":4,"recover":1,"land":1,"jump":1}
const PHASE_GAIN_DB := {"prepare":-12.0,"charge":-9.0,"release":-7.0,"sustain":-12.0,"impact":-6.0,"finale":-3.0,"guard":-8.0,"recover":-14.0,"land":-11.0,"jump":-12.0}
static var _catalog: Dictionary = {}
var audio: Variant
var debug_events := false
var events: Array[Dictionary] = []
var dispatched := 0
var suppressed_duplicates := 0
var _actors: Dictionary = {}
var _objects: Dictionary = {}
var _contacts: Dictionary = {}
var _source_layers: Dictionary = {}
var _landing_seen: Dictionary = {}
var _floor_seen: Dictionary = {}
var _jump_seen: Dictionary = {}
var _seen_actors: Dictionary = {}
var _seen_objects: Dictionary = {}
var _paused := false
var _frozen := false

func _init(receiver: Variant = null) -> void:
	audio=receiver

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		if parsed is Dictionary: _catalog=parsed
		if FileAccess.file_exists(ADDITIONAL_CATALOG_PATH):
			var additional: Variant = JSON.parse_string(FileAccess.get_file_as_string(ADDITIONAL_CATALOG_PATH))
			if additional is Dictionary:
				for section: String in ["assets","bindings","floor_impacts"]:
					_catalog.get_or_add(section,{}).merge(additional.get(section,{}),false)
	return _catalog

static func binding(binding_id: String) -> Dictionary:
	return catalog().get("bindings",{}).get(binding_id,{})

func prewarm(fighter_ids: Array = []) -> void:
	if audio!=null and audio.has_method("prewarm_skill_sfx"):
		var keys: Array = []
		for key: String in catalog().get("assets",{}):
			var id: String = str(catalog()["assets"][key].get("character",""))
			if id in ["notify","wojak"] and id not in fighter_ids: continue
			keys.append(key)
		audio.prewarm_skill_sfx(keys)
	# Actual selected roster IDs opt into ready voices and their ordinary
	# material cues while the arena is loading. Default offline catalog warmup
	# preserves the legacy resource-only contract and never chooses a channel.
	if audio!=null and not fighter_ids.is_empty():
		if audio.has_method("prewarm_skill_voice_pool"):audio.prewarm_skill_voice_pool()
		if audio.has_method("prewarm_sfx"):
			var ordinary: Array[String]=[]
			for id: String in fighter_ids:
				var key: String=str(Data.ROSTER.get(id,{}).get("normal_sfx",""))
				if not key.is_empty() and key not in ordinary:ordinary.append(key)
			if not ordinary.is_empty():audio.prewarm_sfx(ordinary)

static func manages_actor(actor: Variant) -> bool:
	if actor==null or not bool(actor.source_runtime_enabled) or not bool(actor.source_bindings_enabled): return false
	var command: String=str(actor.source_entry_command)
	var binding_id: String=str(actor.source_binding_id)
	if command not in COMMANDS or binding(binding_id).is_empty(): return false
	var fx_binding: Dictionary=SkillFX._load().get("bindings",{}).get(binding_id,{})
	if fx_binding.is_empty(): return false
	return SkillFX._load().get("bundles",{}).get(fx_binding.get("bundle",""),{}).get("labels",{}).has(str(actor.source_label))

func set_suspended(paused: bool, frozen: bool=false) -> void:
	_paused=paused; _frozen=frozen
	if audio!=null and audio.has_method("set_skill_suspended"):
		audio.set_skill_suspended(paused,frozen)

## Begin/end only retire removed actors/objects. One-shot identities survive a freeze.
func begin_tick() -> void:
	_seen_actors.clear(); _seen_objects.clear()

func end_tick() -> void:
	for key: Variant in _actors.keys():
		if not _seen_actors.has(key):
			_stop_layer("actor:"+str(key))
			_stop_source_actor(str(key))
			_actors.erase(key)
	for key: Variant in _objects.keys():
		if not _seen_objects.has(key):
			_stop_layer("object:"+str(key))
			_objects.erase(key)

func update_actor(actor: Variant) -> bool:
	if actor==null: return false
	var key: String=str(actor.get_instance_id())
	_seen_actors[key]=true
	if not manages_actor(actor):
		_stop_source_actor(key)
		if _actors.has(key):
			var record: Dictionary=_actors[key]
			# A genuine neutral completion earns recovery; an interruption does not.
			if str(actor.state) in ["idle","walk","jump","fall","guard"] and bool(record.get("released",false)) and not bool(record.get("recovered",false)):
				_emit(str(record.binding_id),"recover",record.identity+":end",int(actor.player_index),{})
			_stop_layer("actor:"+key)
			_actors.erase(key)
		return false
	var context: Dictionary=actor.source_move_context()
	context.merge({"actor_key":key,"owner_index":int(actor.player_index),"source_clock":float(actor.source_clock),
		"has_live_region":not actor.source_frame_hits().is_empty(),"state":str(actor.state),
		"doing_action":bool(actor.source_doing_action)},true)
	return update_actor_state(context)

## Normalized packets enable offline dispatch QA without allocating combat objects.
func update_actor_state(packet: Dictionary) -> bool:
	var binding_id: String=str(packet.get("binding_id",""))
	var config: Dictionary=binding(binding_id)
	if config.is_empty() or not bool(packet.get("ready",true)): return false
	var key: String=str(packet.get("actor_key",packet.get("owner_index",0)))
	_seen_actors[key]=true
	var serial: int=int(packet.get("action_serial",0))
	var identity: String=key+":"+str(serial)+":"+binding_id
	var fx_binding: Dictionary=SkillFX._load().get("bindings",{}).get(binding_id,{})
	var bundle: Dictionary=SkillFX._load().get("bundles",{}).get(fx_binding.get("bundle",""),{})
	var label: String=str(packet.get("source_label",bundle.get("label","")))
	if not bundle.get("labels",{}).has(label): return false
	var frame: int=int(packet.get("source_absolute_frame",bundle.get("start",0)))-int(bundle.get("start",0))
	var owner: int=int(packet.get("owner_index",0))
	var record: Dictionary=_actors.get(key,{})
	if record.is_empty() or str(record.get("identity",""))!=identity:
		_stop_layer("actor:"+key)
		_stop_source_actor(key)
		record={"identity":identity,"binding_id":binding_id,"owner_index":owner,"action_serial":serial,
			"seen":{},"released":false,"recovered":false}
		_actors[key]=record
	if _paused: return true
	_once(record,"prepare",binding_id,"prepare",owner,{"source_frame":frame,"source_label":label,
		"source_absolute_frame":int(packet.get("source_absolute_frame",0)),"action_serial":serial})
	if not bool(packet.get("doing_action",true)): _stop_source_actor(key)
	var onset: Dictionary=_active_window(bundle,frame,bool(packet.get("has_live_region",false)))
	var detail: Dictionary={"source_frame":frame,"source_label":label,"source_absolute_frame":int(packet.get("source_absolute_frame",0)),"action_serial":serial}
	if not onset.is_empty():
		var cue_key: String="release:"+str(onset.start)+":"+str(onset.hit_id)
		_once(record,cue_key,binding_id,"release",owner,detail)
		record["released"]=true
		# Sustained pressure exists only in a real long active source window.
		var sustained: bool=int(onset.end)-int(onset.start)>=18
		_layer("actor:"+key,binding_id,owner,sustained,detail)
	else:
		_layer("actor:"+key,binding_id,owner,false,detail)
	var phase: Dictionary=SkillFX.cinema_phase(str(fx_binding.get("fighter_id","")),str(fx_binding.get("command","")),label,
		float(packet.get("source_absolute_frame",0))+float(packet.get("source_clock",0))*30.0)
	if phase.get("ready",false) and str(phase.get("stage",""))=="recover" and not bool(record.get("recovered",false)):
		_once(record,"recover",binding_id,"recover",owner,detail)
		record["recovered"]=true
	return true

static func _active_window(bundle: Dictionary, frame: int, has_live_region: bool) -> Dictionary:
	if not has_live_region: return {}
	var window: Dictionary={}
	for region: Dictionary in bundle.get("regions",[]):
		if frame>=int(region.start) and frame<int(region.end_exclusive):
			window={"start":int(region.start),"end":int(region.end_exclusive),"hit_id":str(region.hit_id)}
			break
	if window.is_empty(): return {}
	var changed:=true
	while changed:
		changed=false
		for region: Dictionary in bundle.get("regions",[]):
			if str(region.hit_id)!=str(window.hit_id): continue
			if int(region.end_exclusive)==int(window.start) and int(region.start)<int(window.start):
				window["start"]=int(region.start); changed=true
			if int(region.start)==int(window.end) and int(region.end_exclusive)>int(window.end):
				window["end"]=int(region.end_exclusive); changed=true
	return window

func update_object(object: Variant) -> bool:
	if object==null: return false
	return update_object_state({"object_key":str(object.get_instance_id()),"binding_id":str(object.source_binding_id),
		"owner_index":int(object.owner_index),"source_frame":int(object.source_frame),"source_absolute_frame":int(object.source_absolute_frame),
		"action_serial":int(object.action_serial),"removed":bool(object.removed),"active_hit":not object.hits().is_empty(),
		"source_spawn_absolute_frame":int(object.teaching_origin.get("source_frame",-1)),"source_type":str(object.kind),"name":str(object.name)})

func update_object_state(packet: Dictionary) -> bool:
	var binding_id: String=str(packet.get("binding_id",""))
	var config: Dictionary=binding(binding_id)
	if config.is_empty() or bool(packet.get("removed",false)): return false
	var key: String=str(packet.get("object_key",""))
	if key.is_empty(): return false
	_seen_objects[key]=true
	if _paused: return true
	var owner: int=int(packet.get("owner_index",0))
	if not _objects.has(key):
		_objects[key]={"binding_id":binding_id,"birth":int(packet.get("source_spawn_absolute_frame",-1))}
		# No predicted spawn frame: the actual independent object owns this cue.
		_emit(binding_id,"release","object:"+key+":birth",owner,packet)
		_mark_actor_object_release(packet)
	var id: String=binding_id.get_slice(":",0)
	var sustained: bool=bool(packet.get("active_hit",false)) and id in ["worker","shark","wojak"]
	_layer("object:"+key,binding_id,owner,sustained,packet)
	return true

func _mark_actor_object_release(packet: Dictionary) -> void:
	# A projectile-only normal also has a real release. Its owner earns a quiet
	# recovery only if this birth belongs to the exact currently accepted action.
	# A surviving older ball/paper cannot mark a newly accepted action released.
	for record: Dictionary in _actors.values():
		if int(record.get("owner_index",-1))!=int(packet.get("owner_index",-2)): continue
		if int(record.get("action_serial",-1))!=int(packet.get("action_serial",-2)): continue
		if str(record.get("binding_id",""))!=str(packet.get("binding_id","")): continue
		record["released"]=true

## Only authored source events enter this interface. Bisha supplies its actual
## isSuper / face arguments, and source-held pressure lasts to endShake or the
## real owner lifecycle ending. No artificial duration or damage is created.
func on_source_event(actor: Variant, method: String, args: Array) -> bool:
	if actor==null: return false
	var packet: Dictionary=actor.source_move_context()
	packet.merge({"actor_key":str(actor.get_instance_id()),"owner_index":int(actor.player_index),
		"source_clock":float(actor.source_clock),"source_absolute_frame":int(actor.source_absolute_frame),
		"action_serial":int(actor.action_serial),"source_generation":int(actor.source_generation),
		"doing_action":bool(actor.source_doing_action),"fighter_id":str(actor.fighter_id),
		"has_live_region":not actor.source_frame_hits().is_empty()},true)
	return on_source_event_state(packet,method,args)

func on_source_event_state(packet: Dictionary, method: String, args: Array) -> bool:
	var key: String=str(packet.get("actor_key",packet.get("owner_index",0)))
	if method=="endShake":
		_stop_source_actor(key)
		return true
	if method=="jump": return _on_jump_state(packet,args)
	var binding_id: String=str(packet.get("binding_id",""))
	var config: Dictionary=binding(binding_id)
	if config.is_empty() or method not in ["bisha","shine","startShake"]: return false
	if _paused: return true
	update_actor_state(packet)
	var record: Dictionary=_actors.get(key,{})
	if record.is_empty(): return false
	var detail: Dictionary=packet.duplicate(true)
	detail["source_effect"]=method; detail["source_args"]=args.duplicate(true)
	var owner: int=int(packet.get("owner_index",0))
	if method in ["bisha","shine"] and int(config.get("tier",1))>=2:
		# One charge accent per real accepted action, including a repeated white
		# flash during the same freeze. It cannot be classified as a hit/finale.
		_once(record,"source-charge",binding_id,"charge",owner,detail)
	elif method=="startShake":
		if not _source_layers.has(key):
			_source_layers[key]={"identity":record.identity,"binding_id":binding_id,"owner_index":owner}
		_layer("source:"+key,binding_id,owner,true,detail)
	return true

func _stop_source_actor(key: String) -> void:
	if not _source_layers.has(key): return
	_stop_layer("source:"+key)
	_source_layers.erase(key)

func _on_jump_state(packet: Dictionary,args: Array) -> bool:
	var binding_id: String=str(packet.get("binding_id",""))
	if binding(binding_id).is_empty(): binding_id=str(packet.get("fighter_id",""))+":skill1"
	if binding(binding_id).is_empty(): return false
	if _paused: return true
	# The accepted ordinary jump and a matching authored jump-effect opcode
	# can be delivered at different source label/frame positions. Both belong
	# to the same actual source generation, so the frame must not split them.
	var key: String="%s:%d" % [str(packet.get("actor_key","")),int(packet.get("source_generation",0))]
	if _jump_seen.has(key): suppressed_duplicates+=1; return true
	_jump_seen[key]=true
	if _jump_seen.size()>128: _jump_seen.erase(_jump_seen.keys()[0])
	var detail: Dictionary=packet.duplicate(true)
	detail["source_effect"]="jump";detail["source_args"]=args.duplicate(true)
	_emit(binding_id,"jump","source-jump:"+key,int(packet.get("owner_index",0)),detail)
	return true

## The actual landed signal owns this cue. A source jump opcode is never
## treated as a landing, and reading the same floor frame cannot replay it.
func on_landing(actor: Variant, speed: float) -> bool:
	if actor==null: return false
	return on_landing_state({"actor_key":str(actor.get_instance_id()),"fighter_id":str(actor.fighter_id),
		"binding_id":str(actor.source_binding_id),"owner_index":int(actor.player_index),
		"action_serial":int(actor.action_serial),"source_generation":int(actor.source_generation),
		"source_absolute_frame":int(actor.source_absolute_frame),
		"source_clock":float(actor.source_clock),"speed":speed,"source_enabled":bool(actor.source_runtime_enabled)})

func on_landing_state(packet: Dictionary) -> bool:
	if not bool(packet.get("source_enabled",true)) or float(packet.get("speed",0))<180: return false
	var binding_id: String=str(packet.get("binding_id",""))
	if binding(binding_id).is_empty(): binding_id=str(packet.get("fighter_id",""))+":air_super"
	if binding(binding_id).is_empty(): return false
	if _paused: return true
	var identity: String="%s:%d:%d:%d:%.6f" % [str(packet.get("actor_key","")),int(packet.get("action_serial",0)),
		int(packet.get("source_generation",0)),
		int(packet.get("source_absolute_frame",0)),float(packet.get("source_clock",0))]
	if _landing_seen.has(identity): suppressed_duplicates+=1; return true
	_landing_seen[identity]=true
	if _landing_seen.size()>128: _landing_seen.erase(_landing_seen.keys()[0])
	_emit(binding_id,"land","landing:"+identity,int(packet.get("owner_index",0)),packet)
	return true

## Only the actual hurt-fly rule output / executed hitFloor source opcode
## calls here. This cue is neither a predicted floor box nor jump landing.
func on_floor_impact(packet: Dictionary) -> bool:
	var id:=str(packet.get("fighter_id",""))
	var kind:=int(packet.get("type",-1))
	if kind<0 or kind>2 or not catalog().get("floor_impacts",{}).has(id):return false
	if _paused:return true
	var identity: String="%s:%d" % [str(packet.get("actor_key","")),int(packet.get("floor_event_serial",-1))]
	if _floor_seen.has(identity):suppressed_duplicates+=1;return true
	_floor_seen[identity]=true
	if _floor_seen.size()>128:_floor_seen.erase(_floor_seen.keys()[0])
	var key:=str(catalog()["floor_impacts"][id][str(kind)])
	var phase: String=["floor_bounce","floor_normal","floor_heavy"][kind]
	var cue: Dictionary={"key":key,"phase":phase,"binding_id":id+":hitFloor","owner_index":int(packet.get("owner_index",0)),"priority":5 if kind==2 else 3,"gain_db":-7.0 if kind==2 else (-9.0 if kind==0 else -12.0),"pitch":1.0,"event_key":"source-floor:"+identity,"tier":2 if kind==2 else 1,"detail":packet.duplicate(true),"music_duck":"heavy" if kind==2 else ""}
	dispatched+=1
	if debug_events:
		events.append(cue.duplicate(true))
		if events.size()>4096:events.pop_front()
	if audio!=null and audio.has_method("play_skill_cue"):audio.play_skill_cue(cue)
	return true

## This receives an accepted-contact presentation packet, never predicted boxes.
## Independent object binding/provenance is authoritative even after owner idles.
func on_contact(effect: Dictionary, owner_index: int, serial: int=-1, object_id: int=0, target_index: int=-1) -> bool:
	var binding_id: String=str(effect.get("binding_id",effect.get("source_binding_id","")))
	if binding(binding_id).is_empty() or not bool(effect.get("confirmed",false)): return false
	var outcome: String=str(effect.get("outcome",""))
	if outcome not in ["hit","guard","blocked","armor","steel","counter","guard_break","bullet_clash"]: return false
	var source_type: String=str(effect.get("source_type","actor"))
	var hit_id: String=str(effect.get("hit_id",effect.get("source_name","")))
	var frame: int=int(effect.get("source_absolute_frame",effect.get("source_frame",-1)))
	var key: String="%d:%d:%d:%d:%s:%s:%d:%s" % [owner_index,serial,object_id,target_index,source_type,hit_id,frame,outcome]
	if _contacts.has(key):
		suppressed_duplicates+=1
		return true
	_contacts[key]=true
	if _contacts.size()>1024: _contacts.erase(_contacts.keys()[0])
	if _paused: return true
	var final: bool=outcome=="hit" and int(binding(binding_id).get("tier",1))>=2 and bool(effect.get("finisher",false))
	var phase: String="finale" if final else ("impact" if outcome in ["hit","guard_break"] else "guard")
	_emit(binding_id,phase,"contact:"+key,owner_index,effect)
	return true

func _once(record: Dictionary, key: String, binding_id: String, phase: String, owner: int, detail: Dictionary) -> void:
	if record.seen.has(key):
		suppressed_duplicates+=1
		return
	record.seen[key]=true
	_emit(binding_id,phase,str(record.identity)+":"+key,owner,detail)

func _emit(binding_id: String, phase: String, event_key: String, owner: int, detail: Dictionary) -> void:
	var config: Dictionary=binding(binding_id)
	var cue: Dictionary={"key":str(config.get(phase,"")),"phase":phase,"binding_id":binding_id,"owner_index":owner,
		"priority":int(PHASE_PRIORITY.get(phase,1)),"gain_db":float(PHASE_GAIN_DB.get(phase,-9.0)),
		"pitch":1.0,"event_key":event_key,"tier":int(config.get("tier",1)),"detail":detail.duplicate(true),
		"music_duck":"super" if phase=="finale" else ("heavy" if phase=="impact" and int(config.get("tier",1))>=2 else "")}
	if phase == "release" and binding_id.begins_with("notify:"):
		var pitch_by_spawn: Dictionary = config.get("release_pitch_by_spawn",{})
		var pitch_by_object: Dictionary = config.get("release_pitch_by_object",{})
		cue["pitch"] = float(pitch_by_object.get(str(detail.get("name","")),pitch_by_spawn.get(str(detail.get("source_spawn_absolute_frame",-1)),1.0)))
	if cue.key.is_empty(): return
	dispatched+=1
	if debug_events:
		events.append(cue.duplicate(true))
		if events.size()>4096: events.pop_front()
	if audio!=null and audio.has_method("play_skill_cue"): audio.play_skill_cue(cue)

func _layer(key: String,binding_id: String,owner: int,active: bool,detail: Dictionary) -> void:
	if audio==null or not audio.has_method("set_skill_layer"): return
	var config: Dictionary=binding(binding_id)
	audio.set_skill_layer(key,{"key":str(config.get("sustain","")),"phase":"sustain","owner_index":owner,
		"binding_id":binding_id,"priority":1,"gain_db":PHASE_GAIN_DB.sustain,"pitch":1.0,"detail":detail},active)

func _stop_layer(key: String) -> void:
	if audio!=null and audio.has_method("set_skill_layer"): audio.set_skill_layer(key,{},false)

func reset() -> void:
	for key: Variant in _actors: _stop_layer("actor:"+str(key))
	for key: Variant in _objects: _stop_layer("object:"+str(key))
	for key: Variant in _source_layers: _stop_layer("source:"+str(key))
	_actors.clear(); _objects.clear(); _contacts.clear(); _source_layers.clear(); _landing_seen.clear(); _floor_seen.clear(); _jump_seen.clear(); _seen_actors.clear(); _seen_objects.clear()
	set_suspended(false,false)
	if audio!=null and audio.has_method("stop_skill_sfx"): audio.stop_skill_sfx()
