extends RefCounted
const MaterialLayers = preload("res://game/bvn_material_layers_v029.gd")
## Source-clock-only presentation. Never calls contacts, advances a clock, or draws actors.
const SkillBindings=preload("res://game/bvn_skill_bindings.gd")
const SourceTimeline=preload("res://game/bvn_playable_timeline.gd")
const DATA_PATH := "res://assets/fx/v022/skill-fx-bundles.json"
const ROSTER_DATA_PATH := "res://assets/fx/v034/skill-fx-bundles-v034.json"
const NEW_FIGHTERS: Array[String]=["notify","wojak"]
const COLORS := {"rio":Color("52aee8"),"cat":Color("f35ba5"),"worker":Color("ea4a57"),"chicken":Color("ff782b"),"shark":Color("17b9c9"),"notify":Color("e94359"),"wojak":Color("13181e")}
const INK := Color("193c59")
## A presentation hierarchy over the forty pinned source bindings. No extra
## attacks, freeze, global RNG or secondary actor drawings are introduced.
const WHITE := Color("fff6d9")
const RIO_EDGE := Color("c0eeff")
const RIO_SHADOW := Color("174d87")
const BALL_SHADOW := Color("572b30")
const RANK_SCALE := [1.0,1.0,1.30,1.62]
const FINAL_CHILD_HITS := {"worker:super":"bs","chicken:super_up":"sbs2","chicken:super_down":"cbs"}
const NORMAL_LAUNCHER_SYMBOLS := {"kj2mc":"元件/mc_0035","kj2mc2":"元件/mc_0034"}
static var _data: Dictionary = {}
static var _properties: Dictionary = {}
static var _basketball_material: Texture2D
static var _final_child_windows: Dictionary={}
static var _character_fx_modules: Dictionary={}
static var _stopped_terminals: Dictionary={}
const CHARACTER_FX_PATHS := {"rio":"res://game/fx_rio_v028.gd","chicken":"res://game/fx_chicken_v028.gd","cat":"res://game/fx_cat_v027.gd","worker":"res://game/fx_worker_v027.gd","shark":"res://game/fx_shark_v027.gd","notify":"res://game/fx_notify_v034.gd","wojak":"res://game/fx_wojak_v034.gd"}

static func prewarm_character(id: String) -> void:
	_character_fx(id)

static func _character_fx(id: String) -> Variant:
	if _character_fx_modules.has(id):return _character_fx_modules[id]
	var path: String=str(CHARACTER_FX_PATHS.get(id,""))
	# Optional while each artist is authoring; production release requires all
	# registered helpers and verifies their callbacks before Desktop integration.
	if not path.is_empty() and ResourceLoader.exists(path):
		var module: Variant=load(path)
		if module!=null:_character_fx_modules[id]=module;return module
	return null

static func _meme_cinema_stages(id: String,slot: String) -> Array:
	match id+":"+slot:
		"cat:I":return [[37,"prepare","爪をためる","paw_charge"],[61,"entry","飛びつき狙い","paw_pounce"],[79,"grab_spin","抱え込み回転","paw_grab"],[90,"descent","猫団子・急降下","paw_drop"],[96,"impact","両爪・着地叩き","paw_slam"],[119,"recover","にゃっ…着地！","paw_settle"]]
		"cat:WI":return [[20,"prepare","上爪をためる","paw_charge"],[34,"rise","びっくり昇り爪","paw_rise"],[54,"recover","爪をひっこめる","paw_settle"]]
		"cat:SI":return [[59,"prepare","暴走スイッチ","paw_charge"],[86,"combo","右！左！連続爪！","paw_rush"],[124,"rage_combo","猫ミーム・暴走","paw_rage"],[140,"heavy","両爪を振りかぶる","paw_slam"],[143,"impact","猫パンチ・締め！","paw_slam"],[173,"recover","急にすん…","paw_settle"]]
		"cat:AIR_I":return [[22,"prepare","空中で丸まる","paw_charge"],[28,"descent","猫団子・落下","paw_drop"],[36,"impact","着地の両爪","paw_slam"],[83,"recover","ぷるぷる着地","paw_settle"]]
		"worker:I":return [[40,"prepare","書類を準備","paper_charge"],[89,"paper_field","稟議の紙吹雪","paper_stack"],[93,"impact","承認！重い一印","office_stamp"],[113,"recover","書類を片づける","paper_settle"]]
		"worker:WI":return [[44,"prepare","移動申請中…","paper_charge"],[69,"entry","定時の瞬間移動","office_step"],[189,"office_chain","残業書類・連続配達","paper_delivery"],[192,"heavy","最終承認！","office_stamp"],[249,"recover","かばんを持ち直す","paper_settle"]]
		"worker:SI":return [[50,"prepare","退勤申請をためる","paper_charge"],[179,"overtime_field","残業の書類地獄","overtime_paper"],[183,"impact","定時！退勤の一印","clockout_stamp"],[236,"recover","お疲れさまでした","paper_settle"]]
		"worker:AIR_I":return [[22,"prepare","空中でかばんを構える","briefcase_charge"],[25,"heavy","出張・かばん叩き","briefcase_slam"],[71,"recover","出張から帰る","paper_settle"]]
		"shark:I":return [[29,"prepare","三足で踏みしめる","shoe_charge"],[37,"bite_dash","噛みつき水圧ダッシュ","jaw_stream"],[65,"recover","靴で止まる","shoe_settle"]]
		"shark:WI":return [[28,"prepare","三足をたたむ","shoe_charge"],[74,"water_spin","三足・渦巻き回転","shoe_whirlpool"],[82,"open","水圧を絞り込む","shoe_charge"],[88,"heavy","渦の締め蹴り","shoe_final_kick"],[113,"recover","三足で着地","shoe_settle"]]
		"shark:SI":return [[60,"prepare","深海の水圧をためる","shoe_charge"],[67,"descent","三足・深海急降下","shoe_dive"],[73,"impact","噛みつき突入","jaw_pressure"],[106,"water_hold","水圧の噛み砕き","jaw_pressure"],[113,"heavy","深海・終撃","deep_pressure"],[136,"recover","びしょ濡れ三足","shoe_settle"]]
		"shark:AIR_I":return [[28,"prepare","空中で三足を縮める","shoe_charge"],[38,"descent","三足・水圧落下","shoe_dive"],[41,"impact","着地の水圧","deep_pressure"],[71,"recover","靴で水を払う","shoe_settle"]]
	return []

static func _load() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary: _data=parsed
		# A generated source-only overlay adds two IDs. Existing forty bundles
		# and bindings cannot be overwritten by roster data or runtime sampling.
		if FileAccess.file_exists(ROSTER_DATA_PATH):
			var overlay: Variant=JSON.parse_string(FileAccess.get_file_as_string(ROSTER_DATA_PATH))
			if overlay is Dictionary:
				for key: String in overlay.get("bindings",{}):
					var entry: Dictionary=overlay.bindings[key]
					if str(entry.get("fighter_id","")) not in NEW_FIGHTERS or _data.get("bindings",{}).has(key):continue
					var bundle_key: String=str(entry.get("bundle",""))
					if not overlay.get("bundles",{}).has(bundle_key) or _data.get("bundles",{}).has(bundle_key):continue
					_data["bindings"][key]=entry
					_data["bundles"][bundle_key]=overlay.bundles[bundle_key]
	return _data

static func profile_count() -> int:
	return _load().get("bindings",{}).size()

static func _read(value: Variant, key: String, fallback: Variant=null) -> Variant:
	if value is Dictionary: return value.get(key,fallback)
	if value is not Object or not is_instance_valid(value): return fallback
	var script: Variant=value.get_script()
	var cache_key: String=str(script)
	if not _properties.has(cache_key):
		var names: Dictionary={}
		for property: Dictionary in value.get_property_list(): names[str(property["name"])]=true
		_properties[cache_key]=names
	if not _properties[cache_key].has(key): return fallback
	var found: Variant=value.get(key)
	return fallback if found==null else found

static func _v(value: Variant, fallback: Vector2=Vector2.ZERO) -> Vector2:
	if value is Vector2: return value
	if value is Array and value.size()>=2: return Vector2(float(value[0]),float(value[1]))
	return fallback

static func _rect(value: Variant) -> Rect2:
	if value is Rect2: return value
	if value is Array and value.size()>=4: return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))
	if value is Dictionary:
		for key: String in ["area","world_rect","rect"]:
			if value.has(key): return _rect(value[key])
	return Rect2()

static func _world_regions(context: Dictionary) -> Array[Rect2]:
	var result: Array[Rect2]=[]
	for region: Variant in context.get("hit_regions",[]):
		var box: Rect2=_rect(region)
		if box.has_area(): result.append(box)
	return result

static func _binding(id: String, command: String) -> Dictionary:
	return _load().get("bindings",{}).get(id+":"+command,{})

static func tier_for(binding_id: String) -> int:
	var binding: Dictionary=_load().get("bindings",{}).get(binding_id,{})
	if binding.is_empty(): return 0
	var slot: String=str(binding.get("slot",""))
	return 3 if slot=="SI" else (2 if slot in ["I","WI","AIR_I"] else 1)

## Cheap preflight for Battle's standard source_visual_state path. This is a
## presentation query, never action permission or contact authentication. Do not
## cache it: labels, donors and snapshots can change within one rendered frame.
static func actor_presentation_possible(actor: Variant, minimum_tier: int=1) -> bool:
	if actor==null or not bool(actor.source_runtime_enabled):return false
	var id: String=str(actor.fighter_id)
	var command: String=str(actor.source_entry_command)
	if command.is_empty():command=str(actor.action)
	var binding: Dictionary=_binding(id,command)
	if binding.is_empty() or tier_for(id+":"+command)<minimum_tier:return false
	if str(actor.source_active_profile_id())!=str(binding["profile"]):return false
	var bundle: Dictionary=_load()["bundles"][binding["bundle"]]
	var label: String=str(actor.source_label)
	if not bundle["labels"].has(label):return false
	if id in NEW_FIGHTERS:
		var metadata: Dictionary=bundle["labels"][label]
		var absolute: int=int(actor.source_absolute_frame)
		if absolute<int(metadata.frame) or absolute>int(metadata.source_end_frame):return false
	return true

## A source-frame presentation vocabulary shared with the cinema layer. These
## milestones are the archived region / birth times, not a second move timer.
static func _terminal_holds(profile: String,label: String) -> bool:
	var key:=profile+":"+label
	if not _stopped_terminals.has(key):
		var holds:=false
		var terminal: Dictionary=SourceTimeline._definition_ref(profile,label).get("terminal_event",{})
		for call: Dictionary in terminal.get("calls",[]):
			if call.get("supported",false) and call.get("conditions",[]).is_empty() and call.get("method","")=="stop":holds=true
		_stopped_terminals[key]=holds
	return bool(_stopped_terminals[key])

static func cinema_phase(id: String,command: String,label: String,absolute_frame: float) -> Dictionary:
	var binding: Dictionary=_binding(id,command)
	if not COLORS.has(id) or binding.is_empty() or tier_for(id+":"+command)<2:return {"ready":false}
	var bundle: Dictionary=_load()["bundles"][binding["bundle"]]
	if not bundle["labels"].has(label):return {"ready":false}
	var label_start: float=float(bundle["labels"][label].frame)
	var label_end: float=label_start+float(bundle["labels"][label].authored_span)
	if id in NEW_FIGHTERS:return _with_formal_title(_roster_cinema_phase(id,command,label,absolute_frame,binding,bundle),command)
	if id in ["cat","worker","shark"]:
		# XFL nextFrame may cross a label boundary while keeping the accepted
		# branch name. The pinned executable terminal owns its real span.
		label_end=float(SourceTimeline.definition_metadata(str(binding["profile"]),label).get("source_end_frame",label_end))
	# The registered label is authoritative. A stale / impossible entry label
	# cannot use a later absolute number to invent the confirmed-HIT branch.
	var holds_last: bool=id in ["cat","worker","shark"] and _terminal_holds(str(binding["profile"]),label)
	if absolute_frame<label_start or absolute_frame>label_end or (absolute_frame>=label_end and not holds_last):return {"ready":false}
	var t: float=absolute_frame-float(bundle["start"])
	var slot: String=binding["slot"]
	var stages: Array=_meme_cinema_stages(id,slot)
	if not stages.is_empty():
		# Miss recovery is a different accepted source path, never the HIT chain.
		if id=="cat" and slot=="I" and label=="必杀":stages=[[37,"prepare","爪をためる","paw_charge"],[41,"entry","飛びつき狙い","paw_pounce"],[61,"recover","爪を引いて着地","paw_settle"]]
		elif id=="worker" and slot=="WI" and label=="上必杀":stages=[[44,"prepare","移動申請中…","paper_charge"],[47,"entry","定時の瞬間移動","office_step"],[69,"recover","かばんを持ち直す","paper_settle"]]
		var meta: Dictionary=SourceTimeline.definition_metadata(str(binding["profile"]),label)
		var actual_end: float=float(meta.get("source_end_frame",label_end))
		if absolute_frame>actual_end or (absolute_frame>=actual_end and not holds_last):return {"ready":false}
		var last_stage: Array=stages.back()
		var recovery_begin: float=float(stages[stages.size()-2][0])
		if last_stage[1]=="recover" and actual_end-float(bundle.start)>recovery_begin:
			last_stage[0]=minf(float(last_stage[0]),actual_end-float(bundle.start)+(.5 if holds_last else -.5))
	elif id=="rio" and slot=="SI":
		stages=[[50,"prepare","大剣を持ち上げる","blade_charge"],[75,"entry","重さで突進","blade_entry"],[157,"combo","切り返し連撃","blade_combo"],[226,"rotation","大剣・暴走回転","blade_rotation"],[234,"rise","空へ振り上げる","blade_rise"],[239,"descent","一刀・落下斬り","blade_drop"],[278,"recover","重すぎる…","blade_settle"]]
	elif id=="rio" and slot=="I":
		stages=[[26,"prepare","大剣を構える","blade_charge"],[32,"combo","踏み込み斬り","blade_entry"],[37,"heavy","重さを乗せた一刀","blade_heavy"],[61,"recover","剣を引き戻す","blade_settle"]]
	elif id=="chicken" and slot=="SI":
		stages=[[81,"prepare","ダンクを狙う","ball_charge"],[97,"air_combo","ドリブル突破","ball_dribble"],[123,"air_combo","空中キャッチ","ball_catch"],[136,"descent","ダンク急降下","dunk_rim"],[144,"impact","ネットを揺らす","dunk_rim"],[162,"recover","着地の余韻","rim_settle"]]
	elif id=="chicken" and slot=="I":
		stages=[[33,"prepare","三球を狙い撃ち","ball_charge"],[44,"combo","一球目","ball_shot"],[65,"combo","二球目","ball_shot"],[85,"heavy","三球目・全力投球","power_ball"],[131,"recover","投げ終わり","ball_settle"]]
	elif id=="rio" and slot=="WI":
		stages=[[28,"prepare","大剣をためる","blade_charge"],[74,"rise","大剣・昇り斬り","blade_rise"],[82,"open","重さを乗せ直す","blade_charge"],[88,"heavy","頂点で追い打ち","blade_heavy"],[113,"recover","剣を引き戻す","blade_settle"]]
	elif id=="rio" and slot=="AIR_I":
		stages=[[22,"prepare","空中で大剣を構える","blade_charge"],[25,"descent","空中落下一刀","blade_drop"],[71,"recover","空中で剣を引き戻す","blade_settle"]]
	elif id=="chicken" and slot=="WI":
		stages=[[74,"prepare","真上へ狙いを定める","ball_charge"],[78,"rise","高く放つ一球","alley_oop"],[124,"recover","投球の余韻","ball_settle"]]
	elif id=="chicken" and slot=="AIR_I":
		stages=[[22,"prepare","空中で球を構える","ball_charge"],[28,"descent","球を抱えて急降下","falling_ball"],[36,"impact","落下ダンク","dunk_rim"],[83,"recover","着地の余韻","rim_settle"]]
	else:
		var first: int=99999
		var last: int=0
		for region: Dictionary in bundle.get("regions",[]):first=mini(first,int(region.start));last=maxi(last,int(region.end_exclusive))
		for birth: Variant in bundle.get("spawn_frames",[]):first=mini(first,int(birth));last=maxi(last,int(birth)+4)
		var finish: float=float(bundle["labels"][label].frame)-float(bundle["start"])+float(bundle["labels"][label].authored_span)
		var release_motif: String="blade_rise" if id=="rio" else "alley_oop"
		if slot=="AIR_I":release_motif="blade_drop" if id=="rio" else "falling_ball"
		stages=[[first,"prepare","必殺を構える","blade_charge" if id=="rio" else "ball_charge"],[last,"descent" if slot=="AIR_I" else "rise","空から一撃" if slot=="AIR_I" else "上昇必殺",release_motif],[maxf(last+1,finish),"recover","振り抜きの余韻","blade_settle" if id=="rio" else "ball_settle"]]
	var begin: float=0.0
	for stage: Array in stages:
		var end: float=float(stage[0])
		if t<end:
			return {"ready":true,"id":id,"slot":slot,"binding_id":id+":"+command,"stage":stage[1],"title":stage[2],"motif":stage[3],"progress":clampf((t-begin)/maxf(1,end-begin),0,1),"source_label":label,"source_absolute_frame":absolute_frame,"timing_source":"archived_source_frame","contains_character":false,"source_clock_mutated":false}
		begin=end
	return {"ready":false}

## Formal bindings read new roster names from Data. Stage words remain secondary;
## no actor branch/label or source duration is changed to choose a caption.
static func formal_skill_title(id: String,command: String) -> String:
	return str(SkillBindings.binding_for(id,command).get("name_ja",""))

static func _with_formal_title(phase: Dictionary,command: String) -> Dictionary:
	if not phase.get("ready",false):return phase
	var official: String=formal_skill_title(str(phase.get("id","")),command)
	if official.is_empty():return phase
	phase["subtitle"]=str(phase.get("subtitle",phase.get("title","")))
	phase["title"]=official
	phase["cue"]=official
	return phase

static func cinematic_phase(state: Dictionary) -> Dictionary:
	if not state.get("ready",false) or int(state.get("tier",0))<2:return {"ready":false}
	# Use the already sampled actual ownership phase. Recomputing from the
	# archive alone would call the pre-capture uppercut a completed grab.
	var result: Dictionary=state.get("cinema_phase",{}).duplicate(true)
	if result.is_empty():result=cinema_phase(str(state.get("id","")),str(state.get("command","")),str(state.get("label","")),float(state.get("absolute_frame",0))+float(state.get("source_clock",0))*30.0)
	if not result.get("ready",false):return result
	result=_with_formal_title(result,str(state.get("command",str(result.get("binding_id","")).get_slice(":",1))))
	var stage: String=result["stage"]
	if stage=="entry":stage="open"
	if result["id"]=="rio" and result["slot"]=="SI" and stage in ["rise","descent"]:stage="heavy"
	result["stage"]=stage
	result["cue"]=result["title"]
	result["accent_strength"]=.26 if stage in ["prepare","recover"] else (.68 if stage in ["heavy","impact","rotation"] else .44)
	result["source_frame"]=state.get("source_frame",0)
	result["source_clock"]=state.get("source_clock",0.0)
	return result

## Only the actor's current formal source region, or a real source spawn window,
## can release art. The phase drives a short sweep instead of a frozen arc.
static func release_profile(bundle: Dictionary,frame: float,has_live_region: bool) -> Dictionary:
	var first: int=99999
	var last: int=-1
	var active_start: int=-1
	var active_end: int=0
	var recent_end: int=-1
	for region: Dictionary in bundle.get("regions",[]):
		var begin: int=int(region.get("start",0))
		var end: int=int(region.get("end_exclusive",begin+1))
		first=mini(first,begin); last=maxi(last,begin)
		if frame>=float(end):recent_end=maxi(recent_end,end)
		if has_live_region and frame>=begin and frame<float(end) and begin>=active_start:
			active_start=begin; active_end=end
	for spawn: Variant in bundle.get("spawn_frames",[]):
		var begin: int=int(spawn)
		first=mini(first,begin); last=maxi(last,begin)
		if frame>=float(begin+4):recent_end=maxi(recent_end,begin+4)
		if frame>=begin and frame<float(begin+4) and begin>=active_start:
			active_start=begin; active_end=begin+4
	var phase: float=clampf((frame-float(active_start))/maxf(1,float(active_end-active_start)),0,1) if active_start>=0 else 0.0
	var recovery: float=clampf((frame-float(recent_end))/6.0,0,1) if recent_end>=0 else 1.0
	return {"first":first,"last":last,"start":active_start,"phase":phase,"active":active_start>=0,"finishing_release":active_start>=0 and active_start==last,"prepare":clampf(frame/maxf(1,first),0,1) if frame<float(first) else 0.0,"recent_end":recent_end,"recovery_phase":recovery,"recovering":active_start<0 and recent_end>=0 and recovery<1.0}

static func sample_actor(actor: Variant, context: Dictionary) -> Dictionary:
	if not bool(context.get("ready",false)) or not bool(context.get("source_bindings_enabled",true)): return {"ready":false}
	var id: String=str(context.get("fighter_id",_read(actor,"fighter_id","")))
	var command: String=str(context.get("command",""))
	var binding: Dictionary=_binding(id,command)
	if binding.is_empty(): return {"ready":false}
	if str(context.get("donor_profile_id",binding["profile"]))!=str(binding["profile"]): return {"ready":false}
	var bundle: Dictionary=_load()["bundles"][binding["bundle"]]
	var label: String=str(context.get("source_label",bundle["label"]))
	if not bundle["labels"].has(label): return {"ready":false}
	var absolute: int=int(context.get("source_absolute_frame",int(bundle["start"])+int(context.get("source_frame",0))))
	if id in NEW_FIGHTERS:
		var label_meta: Dictionary=bundle["labels"][label]
		if absolute<int(label_meta.frame) or absolute>int(label_meta.source_end_frame):return {"ready":false}
	var frame: int=absolute-int(bundle["start"])
	var boxes: Array[Rect2]=_world_regions(context)
	var release: bool=not boxes.is_empty()
	for spawn: Variant in bundle.get("spawn_frames",[]):
		if frame>=int(spawn) and frame<int(spawn)+4: release=true
	var floor: float=float(context.get("floor_y",_read(actor,"stage_floor_y",0.0)))
	var source_clock: float=float(context.get("source_clock",_read(actor,"source_clock",0.0)))
	var source_playing: bool=bool(context.get("source_playing",_read(actor,"source_playing",true)))
	if id in NEW_FIGHTERS and not source_playing:source_clock=0.0
	var release_state: Dictionary=release_profile(bundle,float(frame)+clampf(source_clock*30.0,0,.999),not boxes.is_empty())
	var state: Dictionary={"ready":true,"id":id,"command":command,"slot":binding["slot"],"binding_id":id+":"+command,"tier":tier_for(id+":"+command),"release_state":release_state,"profile":binding["profile"],"label":label,"frame":frame,"absolute_frame":absolute,"position":_v(context.get("position",_read(actor,"position",Vector2.ZERO))),"height":maxf(32.0,float(context.get("body_height",_read(actor,"body_height",90.0)))),"facing":int(context.get("facing",_read(actor,"facing",1))),"floor":floor,"boxes":boxes,"release":release,"stage":str(context.get("stage","")),"contact":context.get("contact",""),"confirmed":bool(context.get("confirmed",false)),"anchors":context.get("anchors",{}),"previous_anchors":context.get("previous_anchors",{}),"anchor_sample":context.get("anchor_sample",{}),"grounded":bool(context.get("grounded",_read(actor,"grounded",false))),"bundle":bundle}
	state["ball_visible"]=bool(context.get("ball_visible",state["anchors"].has("ball")))
	state["source_frame"]=int(context.get("source_frame",absolute-int(bundle["labels"][label].frame)))
	state["source_clock"]=source_clock
	if id in NEW_FIGHTERS:state["source_playing"]=source_playing
	var attachment: Dictionary=anchor_attachment(state)
	state["anchor_ready"]=attachment["ready"]
	state["missing_anchors"]=attachment.get("missing",[])
	state["attachment"]=attachment
	if id in NEW_FIGHTERS:state["cinema_phase"]=cinema_phase(id,command,label,float(absolute)+source_clock*30.0)
	state["geometry"]=actor_geometry(state)
	if id not in NEW_FIGHTERS:state["cinema_phase"]=cinema_phase(id,command,label,float(absolute)+source_clock*30.0)
	if id=="cat" and str(binding["slot"])=="I" and label=="必杀_HIT" and context.has("source_target_active") and not context.get("source_target_active",false) and context.get("paired_target_visible",true) and state["cinema_phase"].get("ready",false):
		# The confirmed source uppercut first launches the victim; the cat then
		# chases before MoveTarget begins. Do not label that gap as a held grab.
		state["cinema_phase"]["stage"]="pursuit"
		state["cinema_phase"]["title"]="打ち上げて追いかける"
		state["cinema_phase"]["cue"]="打ち上げて追いかける"
		state["cinema_phase"]["motif"]="paw_pounce"
	return state

static func draw_actor(canvas: CanvasItem, actor: Variant, context: Dictionary, layer: String) -> Dictionary:
	var state: Dictionary=sample_actor(actor,context)
	if not state.get("ready",false): return state
	var p: Vector2=state["position"]
	var h: float=state["height"]
	var color: Color=COLORS[state["id"]]
	var f: float=float(state["facing"])
	var t: float=float(state["absolute_frame"])
	var character_fx: Variant=_character_fx(str(state["id"]))
	if character_fx!=null:
		if state["anchor_ready"]:
			if state["id"]!="wojak":MaterialLayers.draw(canvas,state,layer)
			character_fx.draw_actor(canvas,state,layer)
		return state
	if state["id"] in ["rio","chicken"]:
		# These two production fighters now require the very same sampled pose
		# anchors as the renderer. Missing registration cannot create floating FX.
		if not state["anchor_ready"]: return state
		_draw_attached_actor(canvas,state,layer)
		return state
	var center: Vector2=p+Vector2(f*h*.30,-h*.55)
	if not state["boxes"].is_empty(): center=state["boxes"][0].get_center()
	if layer=="front":
		# Only joint glints. Actual hit/guard bursts are drawn by draw_contact.
		if state["release"]:
			var anchor: Vector2=_anchor(state,"weapon_grip" if state["id"]=="rio" else ("front_foot" if state["id"]=="shark" else "paw_tip"),p+Vector2(f*h*.24,-h*.5))
			_spark(canvas,anchor,color,h*.045,.58, t)
		return state
	if not state["release"]:
		_draw_preparation(canvas,state)
		return state
	_draw_release_rank(canvas,state,center)
	match state["id"]:
		"rio": _actor_sword(canvas,state,center)
		"cat": _actor_claw(canvas,state,center)
		"worker": _actor_paper(canvas,state,center)
		"chicken": _actor_ball_wing(canvas,state,center)
		"shark": _actor_water(canvas,state,center)
	return state

static func draw(canvas: CanvasItem, actor: Variant, context: Dictionary, layer: String) -> Dictionary:
	return draw_actor(canvas,actor,context,layer)

static func _anchor(state: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return _v(state.get("anchors",{}).get(key,fallback),fallback)

static func anchor_attachment(state: Dictionary) -> Dictionary:
	var anchors: Dictionary=state.get("anchors",{})
	var id: String=str(state.get("id",""))
	var ball_visible: bool=bool(state.get("ball_visible",anchors.has("ball")))
	var required: Array=["weapon_grip","weapon_tip"] if id=="rio" else (["hand","ball"] if id=="chicken" and ball_visible else (["hand"] if id=="chicken" else []))
	if id=="cat":required=["paw_tip"]
	elif id=="worker":required=["hand","briefcase"]
	elif id=="shark":required=["front_foot","third_foot","jaw"]
	elif id=="notify":required=["hand","phone","bag_grip" if anchors.has("bag_grip") else "bag"]
	elif id=="wojak":required=["hand","anatomy_head","anatomy_chest"]
	var result: Dictionary={"ready":true,"missing":[],"world_anchors":{},"origin":state.get("position",Vector2.ZERO),"axis":Vector2(float(state.get("facing",1)),0)}
	for key: String in required:
		var actual: String="paw_tip" if key=="hand" and not anchors.has("hand") and anchors.has("paw_tip") else key
		var point: Vector2=_v(anchors.get(actual,Vector2(INF,INF)),Vector2(INF,INF))
		if not point.is_finite(): result["missing"].append(key);result["ready"]=false
		else: result["world_anchors"][key]=point
	if not result["ready"]: return result
	if id=="rio":
		var blade: Vector2=result["world_anchors"]["weapon_tip"]-result["world_anchors"]["weapon_grip"]
		if blade.length_squared()<1.0:result["ready"]=false;result["missing"].append("distinct_blade_endpoints");return result
		result["origin"]=result["world_anchors"]["weapon_tip"]
		result["axis"]=blade.normalized()
	elif id=="chicken":
		result["origin"]=result["world_anchors"]["ball"] if ball_visible else result["world_anchors"]["hand"]
		result["ball_visible"]=ball_visible
		if ball_visible and anchors.has("ball_rim"):
			var rim: Vector2=_v(anchors["ball_rim"],result["origin"])
			if rim.is_finite():result["ball_radius"]=rim.distance_to(result["origin"])
	elif id in NEW_FIGHTERS:
		result["origin"]=result["world_anchors"]["phone" if id=="notify" else "hand"]
	elif id in ["cat","worker","shark"]:
		var key: String="paw_tip" if id=="cat" else ("hand" if id=="worker" else "front_foot")
		result["origin"]=result["world_anchors"][key]
	return result

## Geometric descriptors expose attachment/footprints to meaningful QA without
## executing GPU commands. Every path starts at the renderer's measured anchor.
static func actor_geometry(state: Dictionary) -> Dictionary:
	var attachment: Dictionary=state.get("attachment",anchor_attachment(state))
	if not attachment.get("ready",false):return {"ready":false,"paths":[],"body_copies":0}
	if str(state.get("id","")) in NEW_FIGHTERS:
		var fx: Variant=_character_fx(str(state["id"]))
		return fx.actor_geometry(state) if fx!=null else {"ready":false,"body_copies":0}
	if str(state.get("id","")) in ["cat","worker","shark"]:
		var id: String=state["id"]
		var origin: Vector2=attachment["origin"]
		var active: bool=bool(state.get("release_state",{}).get("active",false))
		var axis: Vector2=Vector2(float(state.get("facing",1)),0)
		var end: Vector2=origin
		if active and not state.get("boxes",[]).is_empty():
			var box: Rect2=state["boxes"][0]
			end=Vector2(box.end.x if axis.x>0 else box.position.x,box.get_center().y)
		return {"ready":true,"motif":{"cat":"three_paw_claws","worker":"briefcase_paper_stamp","shark":"three_sneaker_water_pressure"}[id],"origin":origin,"axis":axis,"paths":[[origin,end]] if active else [],"release_active":active,"body_copies":0,"opaque_plate":false,"finishing_hit":false,"clock_mutated":false,"attachment_keys":attachment.world_anchors.keys()}
	if str(state.get("id","")) not in ["rio","chicken"]:return {"ready":false,"paths":[],"body_copies":0}
	var id: String=state["id"]
	var slot: String=state["slot"]
	var h: float=state["height"]
	var tier: int=state["tier"]
	var release: Dictionary=state["release_state"]
	var phase: float=release.get("phase",0.0)
	var origin: Vector2=attachment["origin"]
	var f: float=state["facing"]
	var direction: Vector2=Vector2(f,-.05).normalized()
	if slot in ["WU","WI"]:direction=Vector2(f*.20,-1).normalized()
	if slot in ["AIR_U","AIR_I"] or (slot=="SI" and int(state["frame"])>=int(release.get("last",9999))-8):direction=Vector2(f*.15,1).normalized()
	if slot=="SU":direction=Vector2(f,.17).normalized()
	var previous: Dictionary=state.get("previous_anchors",{})
	var previous_key: String="weapon_tip" if id=="rio" else "ball"
	var last: Vector2=_v(previous.get(previous_key,origin),origin)
	var has_travel: bool=last.is_finite() and origin.distance_squared_to(last)>h*h*.0004 and origin.distance_squared_to(last)<h*h*2.25
	if has_travel:direction=(origin-last).normalized()
	var side: Vector2=direction.orthogonal()
	var length: float=h*(.48 if tier==1 else (.63 if tier==2 else .78))
	var points: Array[Vector2]=[origin,origin-direction*length*.28+side*length*.07,origin-direction*length*.62+side*length*.14,origin-direction*length+side*length*.10]
	if has_travel:points=[origin,origin.lerp(last,.35)+side*h*.035,origin.lerp(last,.72)+side*h*.018,last]
	var width: float=h*(.080 if tier==1 else (.112 if tier==2 else .146))
	var theme: String="sword_cut" if id=="rio" else "basketball_swish"
	var visual_stage: String="release" if state["release"] else ("startup" if int(state["frame"])<int(release.get("first",9999)) else "recovery")
	return {"ready":true,"origin":origin,"axis":direction,"blade_axis":attachment["axis"],"paths":[points],"width":width,"edge_width":maxf(1.6,h*.021),"theme":theme,"slot":slot,"stage":visual_stage,"phase":phase,"tier":tier,"ball_radius":attachment.get("ball_radius",h*(.18 if tier==1 else .23)),"uses_previous_anchor":has_travel,"floor_origin":Vector2(origin.x,state["floor"]),"source_absolute_frame":state["absolute_frame"],"source_release_only":true,"finishing_hit":false,"body_copies":0,"render_silhouette":"round_rubber_arcs" if id=="chicken" else "blade_wake","tapered_cut_lane":id=="rio"}

static func _draw_attached_actor(canvas: CanvasItem,s: Dictionary,layer: String) -> void:
	var geometry: Dictionary=s["geometry"]
	var attachment: Dictionary=s["attachment"]
	var id: String=s["id"]
	var h: float=s["height"]
	var tier: int=s["tier"]
	var origin: Vector2=geometry["origin"]
	var release: Dictionary=s["release_state"]
	var color: Color=COLORS[id]
	var anchors: Dictionary=attachment["world_anchors"]
	if layer=="front":
		if s["release"]:
			# A tiny opaque leading-edge glint survives bright pool scenery. The
			# wide painted cutting plane remains behind the one rendered body.
			var axis: Vector2=geometry["axis"]
			if id=="rio":_solid_stroke(canvas,[origin-axis*h*.053,origin+axis*h*.041],maxf(2.0,h*.032),WHITE,color,.95)
			else:_round_band(canvas,origin,Vector2(h*.068,h*.047),-.72,.60,axis.angle(),h*.026,Color("ffe2a0"),BALL_SHADOW,.88)
		return
	if not s["release"]:
		if int(s["frame"])<int(release["first"]):
			var prepare: float=float(release["prepare"])
			if id=="rio":
				var grip: Vector2=anchors["weapon_grip"]
				var tip: Vector2=anchors["weapon_tip"]
				var charge: Vector2=grip.lerp(tip,.54+.30*prepare)
				_solid_stroke(canvas,[grip.lerp(tip,.42),charge,tip],h*(.028 if tier==1 else .041),RIO_EDGE,RIO_SHADOW,.44+prepare*.34)
				if tier>=2:
					for n in range(2 if tier==2 else 3):
						var dir: Vector2=Vector2(float(s["facing"]),-.70+float(n)*.45).normalized()
						_solid_stroke(canvas,[charge-dir*h*(.35+prepare*.19),charge-dir*h*.14],h*.034,Color("ffd483") if tier==3 else RIO_EDGE,RIO_SHADOW,(.38+prepare*.32)/(1+float(n)*.25))
			elif attachment.get("ball_visible",false):
				# This outlines the real held ball, never paints another sphere.
				var radius: float=float(geometry["ball_radius"])*(.80+prepare*.14)
				_round_band(canvas,origin,Vector2(radius,radius*.91),-.90,.50,.1,h*(.030 if tier==1 else .043),Color("ffc768"),BALL_SHADOW,.57+prepare*.33)
				if tier>=2:
					_round_band(canvas,origin,Vector2(radius*1.27,radius*1.08),2.39,3.47,.1,h*.033,Color("ffd66e"),BALL_SHADOW,.38+prepare*.21)
		elif release.get("recovering",false):
			var fade: float=pow(1.0-float(release["recovery_phase"]),1.5)*.36
			if id=="rio":_solid_stroke(canvas,geometry["paths"][0],float(geometry["width"])*.42,color,RIO_SHADOW,fade)
			else:_round_band(canvas,origin,Vector2(h*.16,h*.13),.24,1.64,float(s["facing"])*.3,h*.041,Color("ffc76b"),BALL_SHADOW,fade)
		return
	var paths: Array=geometry["paths"]
	var width: float=geometry["width"]
	var phase: float=release["phase"]
	if id=="rio":
		var cinema: Dictionary=s.get("cinema_phase",{})
		var rotating: bool=cinema.get("stage","")=="rotation"
		if rotating:
			# The long source cbs4 spin has one curved blade wake, not an X on
			# every active frame. The same actual sword anchors define its center.
			var spin_center: Vector2=anchors["weapon_grip"].lerp(anchors["weapon_tip"],.46)
			var spin_radius: float=anchors["weapon_grip"].distance_to(anchors["weapon_tip"])*.51
			var turn: float=float(s["absolute_frame"])*.25
			_round_band(canvas,spin_center,Vector2(spin_radius,spin_radius*.49),turn,turn+1.44,0,h*.078,Color("b0eaff"),RIO_SHADOW,.73)
		else:_solid_stroke(canvas,paths[0],width,COLORS["rio"],RIO_SHADOW,.98)
		var grip: Vector2=anchors["weapon_grip"]
		var tip: Vector2=anchors["weapon_tip"]
		_solid_stroke(canvas,[grip.lerp(tip,.48),grip.lerp(tip,.76),tip],h*(.026 if tier==1 else .040),RIO_EDGE,RIO_SHADOW,.88)
		if tier>=2 and not rotating:
			var offset: Vector2=Vector2(geometry["axis"]).orthogonal()*h*(.062 if tier==2 else .095)
			var extra: Array[Vector2]=[]
			for point: Vector2 in paths[0]:extra.append(point+offset)
			_solid_stroke(canvas,extra,width*.37,Color("ffd686") if tier==3 else RIO_EDGE,RIO_SHADOW,.74)
		# The cast sweep is valid even on a miss, but it never creates a contact
		# finishing burst, screen flash or ground explosion on its own.
	else:
		var dir: Vector2=geometry["axis"]
		var radius: float=clampf(float(geometry["ball_radius"]),h*.085,h*.24)
		# A compact rubber curl follows the held ball / released hand. Real
		# airborne spheres belong exclusively to the already existing child.
		_round_band(canvas,origin,Vector2(radius*1.40,radius*1.07),2.18,4.00,dir.angle()+phase*.15,h*(.045 if tier==1 else .067),Color("ffbc50"),BALL_SHADOW,.89)
		if tier>=2:_round_band(canvas,origin,Vector2(radius*1.67,radius*1.29),-.55,.52,dir.angle(),h*.042,Color("ffe8a2"),BALL_SHADOW,.75)

## Constant-width round-ended arcs: basketball rubber never inherits the
## narrowing sword ribbon silhouette. Each quad is finite and convex.
static func _round_band(canvas: CanvasItem,center: Vector2,radius: Vector2,begin: float,end: float,rotation: float,width: float,color: Color,shadow: Color,alpha: float) -> void:
	if alpha<=.001 or width<=0:return
	var points: Array[Vector2]=_ellipse_points(center,radius,begin,end,rotation)
	for n in range(points.size()-1):
		canvas.draw_line(points[n],points[n+1],Color(shadow,alpha*.94),width+maxf(1.8,width*.20),true)
		canvas.draw_line(points[n],points[n+1],Color(color,alpha),width,true)
	for point: Vector2 in [points[0],points.back()]:
		canvas.draw_circle(point,width*.5+maxf(.9,width*.10),Color(shadow,alpha*.94))
		canvas.draw_circle(point,width*.5,Color(color,alpha))

static func _rubber_fan(canvas: CanvasItem,center: Vector2,radius: Vector2,begin: float,end: float,rotation: float,alpha: float) -> void:
	var points: PackedVector2Array=PackedVector2Array([center])
	var colors: PackedColorArray=PackedColorArray([Color("fbb24d",alpha)])
	for n in range(15):
		var t: float=float(n)/14.0
		var angle: float=lerpf(begin,end,t)
		points.append(center+Vector2(cos(angle)*radius.x,sin(angle)*radius.y).rotated(rotation))
		colors.append(Color(Color("ffd071").lerp(Color("df792d"),t),alpha))
	canvas.draw_polygon(points,colors)
	var edge: PackedVector2Array=points.duplicate();edge.append(points[0])
	canvas.draw_polyline(edge,Color(BALL_SHADOW,alpha*.92),1.8,true)
	var middle: float=(begin+end)*.5
	var seam_end: Vector2=center+Vector2(cos(middle)*radius.x,sin(middle)*radius.y).rotated(rotation)
	canvas.draw_line(center,seam_end,Color(BALL_SHADOW,alpha*.86),maxf(1.1,radius.y*.038),true)

static func _ellipse_points(center: Vector2,radius: Vector2,begin: float,end: float,rotation: float=0.0) -> Array[Vector2]:
	var points: Array[Vector2]=[]
	for n in range(13):
		var angle: float=lerpf(begin,end,float(n)/12.0)
		points.append(center+Vector2(cos(angle)*radius.x,sin(angle)*radius.y).rotated(rotation))
	return points

## Finite, convex per-segment paint strips. Strong dark edges stay legible in
## daylight; shaded filled surfaces replace subpixel wireframe-looking trails.
static func ribbon_quads(points: Array,width: float) -> Array[PackedVector2Array]:
	var quads: Array[PackedVector2Array]=[]
	if points.size()<2 or not is_finite(width) or width<=0:return quads
	for n in range(points.size()-1):
		var p: Vector2=points[n]
		var q: Vector2=points[n+1]
		if not p.is_finite() or not q.is_finite() or p.distance_squared_to(q)<.04:continue
		var side: Vector2=(q-p).normalized().orthogonal()
		var a: float=float(n)/float(points.size()-1)
		var b: float=float(n+1)/float(points.size()-1)
		var wa: float=maxf(.40,width*.5*(.16+.84*pow(sin(PI*a),.7)))
		var wb: float=maxf(.40,width*.5*(.16+.84*pow(sin(PI*b),.7)))
		quads.append(PackedVector2Array([p-side*wa,q-side*wb,q+side*wb,p+side*wa]))
	return quads

static func _solid_stroke(canvas: CanvasItem,points: Array,width: float,color: Color,shadow: Color,alpha: float) -> void:
	if alpha<=.001:return
	var edges: Array[PackedVector2Array]=ribbon_quads(points,width+maxf(2.4,width*.24))
	var paint: Array[PackedVector2Array]=ribbon_quads(points,width)
	for quad: PackedVector2Array in edges:canvas.draw_colored_polygon(quad,Color(shadow,alpha*.94))
	var shades: PackedColorArray=PackedColorArray([Color(color.darkened(.18),alpha),Color(color.darkened(.18),alpha),Color(color.lightened(.32),alpha),Color(color.lightened(.32),alpha)])
	for quad: PackedVector2Array in paint:canvas.draw_polygon(quad,shades)
	# A restrained rim, rather than a central full-white blade sheet.
	for n in range(points.size()-1):
		var p: Vector2=points[n]
		var q: Vector2=points[n+1]
		if p.distance_squared_to(q)>.04:canvas.draw_line(p,q,Color(WHITE,alpha*.52),maxf(.8,width*.12),true)

static func _draw_preparation(canvas: CanvasItem, s: Dictionary) -> void:
	var frame: int=s["frame"]
	var bundle: Dictionary=s["bundle"]
	var first: int=99999
	for r: Dictionary in bundle["regions"]: first=mini(first,int(r["start"]))
	for sf: Variant in bundle["spawn_frames"]: first=mini(first,int(sf))
	if frame<0 or frame>=first: return
	var h: float=s["height"]
	var p: Vector2=s["position"]
	var f: float=s["facing"]
	var pulse: float=.44+.16*sin(float(s["absolute_frame"])*.7)
	var point: Vector2=p+Vector2(f*h*.22,-h*.53)
	var tier: int=int(s.get("tier",1))
	var anticipation: float=float(s.get("release_state",{}).get("prepare",0.0))
	if tier>=2:
		# Two slim converging streaks telegraph the Qi action in the world. Their
		# growth comes from the real wind-up frame and never fills the actor body.
		var size: float=h*(.16+.17*anticipation)*(1.18 if tier==3 else 1.0)
		for n in range(tier):
			var axis: Vector2=Vector2(f,-.35+float(n)*.31).normalized()
			_trace(canvas,[point-axis*size*(1.2+float(n)*.15),point-axis*size*.36],h*.017,COLORS[s["id"]],(.28+.34*anticipation)/float(n+1))
	match s["id"]:
		"rio":
			point=_anchor(s,"weapon_grip",point)
			_trace(canvas,[point+Vector2(-f*h*.15,h*.05),point,point+Vector2(f*h*.18,-h*.07)],h*.023,COLORS["rio"],pulse)
		"cat":
			point=_anchor(s,"paw_tip",point)
			for n in range(3): _spark(canvas,point+Vector2(f*n*h*.045,-n*h*.018),COLORS["cat"],h*.026,pulse,float(frame+n))
		"worker":
			for n in range(2): _paper(canvas,point+Vector2(f*n*h*.12,-n*h*.06),h*.055,float(frame)*.12+n,.60)
		"chicken":
			point=_anchor(s,"ball",point)
			_curve(canvas,point,Vector2(h*.14,h*.12),.3,2.3,h*.023,COLORS["chicken"],pulse,float(frame)*.13)
		"shark":
			for key: String in ["front_foot","middle_foot","back_foot"]:
				var foot: Vector2=_anchor(s,key,p+Vector2(f*h*.1,0))
				_drop(canvas,foot+Vector2(0,-h*.04),Vector2(0,-h*.08),COLORS["shark"],pulse,h*.017)

static func _draw_release_rank(canvas: CanvasItem,s: Dictionary,center: Vector2) -> void:
	var tier: int=int(s.get("tier",1))
	if tier<2: return
	var release: Dictionary=s.get("release_state",{})
	var phase: float=float(release.get("phase",0.0))
	var h: float=s["height"]
	var f: float=s["facing"]
	var p: Vector2=s["position"]
	var anchor: Vector2=_anchor(s,"weapon_tip" if s["id"]=="rio" else ("front_foot" if s["id"]=="shark" else "paw_tip"),center)
	var final: bool=bool(release.get("finishing_release",false))
	var reach: float=h*(.33 if tier==2 else .48)*(1.17 if final else 1.0)
	var intensity: float=(.8 if final else .55)*(.35+.65*sin(PI*clampf(.13+phase*.72,0,1)))
	var color: Color=COLORS[s["id"]]
	# A few directed, tapered speed strokes give each release a clear ordinal
	# weight. No concentric aura or flat full-screen effect sheet is involved.
	for n in range(2 if tier==2 else 4):
		var across: float=(float(n)-float(tier-1)*.5)*h*.085
		var head: Vector2=anchor+Vector2(f*reach*(.45+phase*.3),across)
		var tail: Vector2=head+Vector2(-f*reach*(.75+float(n)*.09),h*.03*sin(float(n)+phase*PI))
		_trace(canvas,[tail,tail.lerp(head,.63),head],h*(.020 if tier==2 else .028),color,intensity/(1.0+float(n)*.28))
	if tier==3 and final and s["grounded"]:
		_floor_ripple(canvas,Vector2(p.x,s["floor"]),h*(.80+phase*.40),color,float(s["absolute_frame"]),.42*(1.0-phase*.5))

static func _actor_sword(canvas: CanvasItem,s: Dictionary,c: Vector2) -> void:
	var h: float=s["height"]
	var f: float=s["facing"]
	var frame: float=s["absolute_frame"]
	var slot: String=s["slot"]
	var box: Rect2=s["boxes"][0] if not s["boxes"].is_empty() else Rect2(c-Vector2.ONE*h*.3,Vector2.ONE*h*.6)
	var grip: Vector2=_anchor(s,"weapon_grip",s["position"]+Vector2(f*h*.25,-h*.50))
	var tip: Vector2=_anchor(s,"weapon_tip",c)
	var radius: Vector2=Vector2(clampf(box.size.x*.34,h*.23,h*1.35),clampf(box.size.y*.31,h*.20,h*.95))
	var rot: float=-.35*f
	if slot in ["WU","WI"]: rot=-1.1*f
	if slot=="AIR_U": rot=1.3*f
	if slot=="AIR_I": rot=.65*f
	var origin: Vector2=tip.lerp(c,.32)
	var blade: Vector2=tip-grip
	var anchor_data: Dictionary=s.get("anchors",{})
	var actual_blade: bool=anchor_data.has("weapon_grip") and anchor_data.has("weapon_tip") and blade.length_squared()>.25
	var direction: Vector2=Vector2(f,0)
	if actual_blade:
		# Whole-body frame measurements are already registered/mirrored to world.
		# Never blend the tip toward a large or remote collision-box center.
		direction=blade.normalized()
		rot=direction.angle()
		origin=tip
	var tier: int=int(s.get("tier",1))
	var sweep: float=float(s.get("release_state",{}).get("phase",0.0))
	var count: int=3 if tier>=2 else 2
	for n in range(count):
		var offset: Vector2=Vector2(-f*n*h*.035,n*h*.018)
		if actual_blade: offset=(-direction*h*.035+direction.orthogonal()*h*.018)*float(n)
		_curve(canvas,origin+offset,radius*(1.0-float(n)*.11),-1.22+sweep*.42,.38+sweep*.76,h*(.043 if n==0 else .021)*sqrt(float(RANK_SCALE[tier])),COLORS["rio"],(.94 if tier==3 else .88) if n==0 else .42,rot+.045*sin(frame*.4))
	_trace(canvas,[grip,grip.lerp(tip,.72),tip],h*.018,COLORS["rio"],.38)
	_fragments(canvas,tip,COLORS["rio"],h*.16,frame,5)
	if s["grounded"] and (str(s["label"]).contains("_TF") or (slot=="SI" and s["frame"]>=226)):
		_floor_ripple(canvas,Vector2(tip.x,s["floor"]),h*.65,COLORS["rio"],frame,.68)

static func _actor_claw(canvas: CanvasItem,s: Dictionary,c: Vector2) -> void:
	var h: float=s["height"]
	var f: float=s["facing"]
	var slot: String=s["slot"]
	var frame: float=s["absolute_frame"]
	var paw: Vector2=_anchor(s,"paw_tip",c)
	var direction: Vector2=Vector2(f,-.45).normalized()
	if slot=="WU": direction=Vector2(f,0)
	if slot=="WI": direction=Vector2(f*.2,-1).normalized()
	if slot in ["SU","AIR_I"] or str(s["label"]).contains("_TF"): direction=Vector2(f*.15,1).normalized()
	if slot=="AIR_U": direction=Vector2(-f,-.25).normalized()
	if slot=="SI": direction=Vector2(f, -.6 if int(frame)%16<8 else .3).normalized()
	var normal: Vector2=direction.orthogonal()
	var rank: float=float(RANK_SCALE[int(s.get("tier",1))])
	var sweep: float=float(s.get("release_state",{}).get("phase",0.0))
	for n in range(3):
		var base: Vector2=paw+normal*(float(n)-1.0)*h*.075
		_trace(canvas,[base-direction*h*(.37-sweep*.10)*sqrt(rank),base-direction*h*.09+normal*h*.04,base+direction*h*(.15+sweep*.12)*sqrt(rank)],h*.038*sqrt(rank),COLORS["cat"],.89-float(n)*.09)
	_fragments(canvas,paw,COLORS["cat"],h*.10,frame,4)
	if slot=="SU":
		for n in range(3): _drop(canvas,paw+Vector2(f*n*h*.12,-h*.09),Vector2(-f*h*.08,h*.10),Color("5ec8eb"),.65,h*.022)
	if s["grounded"] and str(s["label"]).contains("_TF"):
		_floor_ripple(canvas,Vector2(s["position"].x,s["floor"]),h*.47,COLORS["cat"],frame,.70)

static func _actor_paper(canvas: CanvasItem,s: Dictionary,c: Vector2) -> void:
	var h: float=s["height"]
	var slot: String=s["slot"]
	var frame: float=s["absolute_frame"]
	var f: float=s["facing"]
	var box: Rect2=s["boxes"][0] if not s["boxes"].is_empty() else Rect2(c-Vector2.ONE*h*.16,Vector2.ONE*h*.32)
	if slot=="SI":
		# The enormous original field is unchanged. Keep its readable paper vortex
		# around the actual caster, bounded inside the live source region.
		var p: Vector2=s["position"]
		var local: Rect2=Rect2(p+Vector2(-h*2.0,-h*1.72),Vector2(h*4.0,h*1.80)).intersection(box)
		if not local.has_area(): return
		var origin: Vector2=local.get_center()
		for n in range(24):
			var angle: float=float(n)*2.399+frame*.075*f
			var orbit: float=.30+.64*fposmod(float(n)*.381+frame*.008,1.0)
			var pos: Vector2=origin+Vector2(cos(angle)*local.size.x*.46,sin(angle)*local.size.y*.45)*orbit
			var tangent: Vector2=Vector2(-sin(angle),cos(angle)*.48)*f
			_paper(canvas,pos,h*(.095+.032*sin(float(n)+frame*.13)),frame*.13+n,.84,true)
			_trace(canvas,[pos-tangent*h*.17,pos],h*.018,Color("629fbc"),.63)
		return
	var length: float=clampf(box.size.x,h*.30,h*3.4)
	var begin: Vector2=c-Vector2(f*length*.42,0)
	for n in range(6):
		var u: float=fposmod(float(n)/6.0+frame*.023,1.0)
		var pos: Vector2=begin+Vector2(f*length*u,sin(u*TAU+frame*.2)*h*.10)
		_paper(canvas,pos,h*(.06+.025*sin(n+frame*.3)),frame*.18+n,.82)
		_trace(canvas,[pos-Vector2(f*h*.13,h*.015),pos],h*.014,Color("629fbc"),.52)
	if slot in ["SU","WI","AIR_I"]: _stamp(canvas,c,h*.15,COLORS["worker"],.64,frame)

static func _actor_ball_wing(canvas: CanvasItem,s: Dictionary,c: Vector2) -> void:
	var h: float=s["height"]
	var f: float=s["facing"]
	var slot: String=s["slot"]
	var frame: float=s["absolute_frame"]
	var point: Vector2=_anchor(s,"ball",c)
	var rank: float=float(RANK_SCALE[int(s.get("tier",1))])
	if slot in ["U","SU","I","WI"]:
		# Real ball entities are drawn by draw_object. This is only the release-hand seam.
		point=_anchor(s,"paw_tip",s["position"]+Vector2(f*h*.30,-h*.50))
		_curve(canvas,point,Vector2(h*.19,h*.13)*sqrt(rank),-1.2,1.2,h*.037*sqrt(rank),COLORS["chicken"],.86,-.2*f)
	else:
		var dir: Vector2=Vector2(f,-.75).normalized() if slot=="WU" else Vector2(f*.25,1).normalized()
		_trace(canvas,[point-dir*h*.47*sqrt(rank),point-dir*h*.17+Vector2(-f*h*.04,0),point],h*.055*sqrt(rank),COLORS["chicken"],.92)
		_curve(canvas,point,Vector2(h*.20,h*.16),-.5,1.5,h*.024,Color("49bbdf"),.72,frame*.08)
	if s["grounded"] and str(s["label"]).contains("_TF"):
		_floor_ripple(canvas,Vector2(s["position"].x,s["floor"]),h*.58,COLORS["chicken"],frame,.77)

static func _actor_water(canvas: CanvasItem,s: Dictionary,c: Vector2) -> void:
	var h: float=s["height"]
	var f: float=s["facing"]
	var slot: String=s["slot"]
	var frame: float=s["absolute_frame"]
	var fallback_foot: Vector2=c
	if slot=="SI":
		# A tall dive HitVO center is hundreds of pixels above the actor.
		# Without authored shoe anchors, use the real actor foot registration.
		var p: Vector2=s["position"]
		fallback_foot=Vector2(p.x+f*h*.18,s["floor"] if s["grounded"] else p.y-h*.06)
	var foot: Vector2=_anchor(s,"front_foot",fallback_foot)
	if slot in ["U","I"]:
		var box: Rect2=s["boxes"][0] if not s["boxes"].is_empty() else Rect2(c-Vector2(h*.3,h*.1),Vector2(h*.6,h*.2))
		var end: Vector2=Vector2(box.end.x if f>0 else box.position.x,box.get_center().y)
		_trace(canvas,[foot,foot.lerp(end,.35)+Vector2(0,-h*.06),foot.lerp(end,.7)+Vector2(0,h*.045),end],h*(.055 if slot=="I" else .036),COLORS["shark"],.88)
		for n in range(3):
			var pos: Vector2=foot.lerp(end,float(n+1)/4.0)
			_curve(canvas,pos,Vector2(h*.11,h*.075),-.9,1.7,h*.019,COLORS["shark"],.56,frame*.12+n)
	else:
		var keys: Array[String]=["front_foot","middle_foot","back_foot"]
		for n in range(3):
			var pos: Vector2=_anchor(s,keys[n],foot+Vector2(-f*n*h*.13,n*h*.06))
			var rad: float=h*(.23 if slot in ["WI","SI","SU"] else .18)
			_curve(canvas,pos,Vector2(rad,rad*.5),-.5,1.5,h*.035,COLORS["shark"],.84-float(n)*.1,frame*.08+n*.65)
			_drop(canvas,pos+Vector2(f*h*.07,-h*.05),Vector2(f*h*.10,-h*.08),COLORS["shark"],.78,h*.025)
	if s["grounded"] and str(s["label"]).contains("_TF"):
		_floor_ripple(canvas,Vector2(s["position"].x,s["floor"]),h*.61,COLORS["shark"],frame,.79)

static func sample_object(object: Variant,context: Dictionary={}) -> Dictionary:
	if context.is_empty() and object is Object and object.has_method("source_visual_state"):
		context=object.source_visual_state()
	if bool(context.get("removed",_read(object,"removed",true))): return {"ready":false}
	var id: String=str(context.get("fighter_id",_read(object,"fighter_id","")))
	var binding_id: String=str(context.get("binding_id",context.get("source_binding_id",_read(object,"source_binding_id",""))))
	var binding: Dictionary=_load().get("bindings",{}).get(binding_id,{})
	var profile: String=str(context.get("source_profile_id",_read(object,"source_profile_id",binding.get("profile",""))))
	var name: String=str(context.get("name",_read(object,"name","")))
	var symbol: String=str(context.get("source_symbol",_read(object,"child",{}).get("source_symbol","")))
	var origin_action: String=str(context.get("source_origin_action",_read(object,"source_origin_action","")))
	var origin_label: String=str(context.get("source_origin_label",_read(object,"source_origin_label","")))
	var normal_launcher: bool=id=="chicken" and binding_id.is_empty() and profile=="naruto" and NORMAL_LAUNCHER_SYMBOLS.has(name) and symbol==str(NORMAL_LAUNCHER_SYMBOLS.get(name,"")) and origin_action=="launcher" and origin_label=="砍技2"
	if binding.is_empty():
		if not normal_launcher: return {"ready":false}
		binding={"profile":"naruto","slot":"NORMAL_WJ"}
	if profile!=str(binding["profile"]): return {"ready":false}
	if id in NEW_FIGHTERS and str(binding.get("fighter_id",""))!=id:return {"ready":false}
	var box: Rect2=_rect(context.get("area",context.get("actual_bounds",Rect2())))
	if not box.has_area():
		var raw: Rect2=_rect(_read(object,"bullet_area",Rect2()))
		if not raw.has_area():
			var sample: Dictionary=_read(object,"sample",{})
			var candidates: Array=sample.get("hits",[])
			if candidates.is_empty(): candidates=_read(object,"child",{}).get("areas",[])
			for area: Dictionary in candidates:
				if area.get("kind","hit")=="hit": raw=_rect(area.get("source_rect",[])); break
		if raw.has_area() and object is Object and object.has_method("transformed_rect"): box=object.transformed_rect(raw)
	if not box.has_area(): box=Rect2(_v(context.get("position",_read(object,"position",Vector2.ZERO)))-Vector2(12,12),Vector2(24,24))
	var state: Dictionary={"ready":true,"id":id,"slot":binding["slot"],"binding_id":binding_id,"profile":profile,"normal_launcher":normal_launcher,"name":name,"height":float(context.get("body_height",_read(_read(object,"owner",null),"body_height",90.0))),"frame_count":int(context.get("source_frame_count",_read(object,"child",{}).get("frame_count",1))),"active_regions":not _world_regions(context).is_empty(),"position":_v(context.get("position",_read(object,"position",Vector2.ZERO))),"box":box,"frame":int(context.get("source_frame",_read(object,"source_frame",0))),"kind":str(context.get("kind",_read(object,"kind","attacker"))),"bullet_hit":bool(context.get("bullet_hit",_read(object,"bullet_hit",false))),"hit_able":bool(context.get("hit_able",_read(object,"hit_able",true))),"facing":int(context.get("facing",_read(object,"facing",1))),"velocity":_v(context.get("velocity",_read(object,"velocity",Vector2.ZERO))),"symbol":str(context.get("source_symbol",_read(object,"child",{}).get("source_symbol",""))),"floor":float(context.get("floor_y",_read(_read(object,"owner",null),"stage_floor_y",_v(context.get("position",_read(object,"position",Vector2.ZERO))).y))),"mirror_y":float(_read(object,"registration",{}).get("instance_matrix",{}).get("d",1))<0.0}
	state["birth_source_absolute_frame"]=int(_read(object,"teaching_origin",{}).get("source_frame",context.get("source_spawn_absolute_frame",-1)))
	state["source_clock"]=float(context.get("source_clock",_read(object,"clock",0.0)))
	if id in NEW_FIGHTERS:
		var catalog: Dictionary=_roster_object_catalog(binding,state)
		# Rendering never supplies a missing source projectile. Its immutable
		# birth, symbol and name must identify an actual archived spawned child.
		if catalog.is_empty():return {"ready":false}
		state["source_playing"]=bool(context.get("source_playing",_read(object,"playing",true)))
		if not state["source_playing"]:state["source_clock"]=0.0
		state["hold_ticks"]=float(context.get("hold_ticks",_read(object,"hold_ticks",-1.0)))
		state["hits_left"]=int(context.get("hits_left",_read(object,"hits_left",-1)))
		state["timeout"]=bool(context.get("timeout",_read(object,"timeout",false)))
		state["removed"]=false
		state["label"]=str(context.get("source_label",_read(object,"source_label","")))
		state["contact"]=context.get("contact",_read(object,"last_contact",{}))
		state["checker_only"]=_roster_checker_only(catalog,int(state["frame"]))
		state["source_release_rank"]=int(catalog.get("release_rank",0))
	state["geometry"]=object_geometry(state)
	return state

static func draw_object(canvas: CanvasItem,object: Variant,context: Dictionary={},layer: String="back") -> Dictionary:
	var s: Dictionary=sample_object(object,context)
	if not s.get("ready",false) or layer!="back": return s
	var character_fx: Variant=_character_fx(str(s["id"]))
	if character_fx!=null:
		character_fx.draw_object(canvas,s,layer)
		return s
	var box: Rect2=s["box"]
	var c: Vector2=box.get_center()
	var frame: float=s["frame"]
	if s.get("normal_launcher",false):
		_draw_normal_launcher(canvas,s)
		return s
	if s["id"]=="chicken":
		if s["slot"]=="SI":
			_draw_source_dunk_field(canvas,s)
		else:
			_draw_ball(canvas,c,box,s)
	elif s["id"]=="worker":
		if s["slot"]=="WU":
			# Child mc015 is empty before its real F3 region. Never relocate its origin.
			s["material_visible"]=bool(s["active_regions"]) and int(s["frame"])>=3
			if s["material_visible"]: _draw_paper_tower(canvas,s)
			return s
		var count: int=8 if s["slot"]=="I" else 6
		for n in range(count):
			var u: float=fposmod(float(n)/float(count)+frame*.037,1.0)
			var pos: Vector2=c+Vector2(sin(u*TAU)*box.size.x*.35,(u-.5)*minf(box.size.y,180.0))
			_paper(canvas,pos,clampf(box.size.x*.07,4,11),frame*.23+n,.80)
			_trace(canvas,[pos+Vector2(-12,4),pos],2.0,Color("74b5d0"),.5)
		if s["slot"]=="I":
			var final: bool=int(s["frame"])>=49
			_stamp(canvas,c,minf(28.0 if final else 22.0,box.size.x*.26),COLORS["worker"],.92 if final else .72,frame)
			if final: _fragments(canvas,c,COLORS["worker"],minf(48.0,box.size.x*.42),frame,8)
	return s

static func object_geometry(s: Dictionary) -> Dictionary:
	if s.get("ready",false) and str(s.get("id","")) in NEW_FIGHTERS:
		var fx: Variant=_character_fx(str(s["id"]))
		return fx.object_geometry(s) if fx!=null else {"ready":false,"body_copies":0}
	if not s.get("ready",false) or s.get("id","")!="chicken":return {"ready":false,"body_copies":0}
	var box: Rect2=s["box"]
	var h: float=maxf(32,s["height"])
	var final_ball: bool=s.get("binding_id","")=="chicken:super" and int(s.get("birth_source_absolute_frame",-1))==550
	var tier: int=tier_for(str(s.get("binding_id","")))
	var radius: float=clampf(minf(box.size.x,box.size.y)*(.43 if final_ball else .33),6,minf(43,h*(.33 if final_ball else (.245 if tier>=2 else .185))))
	var axis: Vector2=Vector2(s["velocity"])
	if not axis.is_finite() or axis.length_squared()<.01:axis=Vector2(float(s["facing"]),0)
	axis=axis.normalized()
	var reach: float=radius*(4.8 if final_ball else (3.6 if tier>=2 else 2.6))
	var center: Vector2=box.get_center()
	var side: Vector2=axis.orthogonal()
	var paths: Array=[ [center-axis*radius*.82,center-axis*reach*.52+side*radius*.17,center-axis*reach] ]
	return {"ready":true,"center":center,"radius":radius,"axis":axis,"paths":paths,"width":maxf(3.8,radius*(.52 if final_ball else .39)),"tier":tier,"strong_projectile":final_ball,"release_stage":"impact_material" if s["bullet_hit"] else "travel","source_frame":s["frame"],"birth_source_absolute_frame":s.get("birth_source_absolute_frame",-1),"actual_box":box,"body_copies":0,"confirmed_finishing_hit":false,"render_silhouette":"dunk_rim" if s.get("slot","")=="SI" else "sphere_and_round_rubber","tapered_cut_lane":false}

static func _draw_source_dunk_field(canvas: CanvasItem,s: Dictionary) -> void:
	var box: Rect2=s["box"]
	var h: float=maxf(32,s["height"])
	var frame: float=float(s["frame"])+s["source_clock"]*30.0
	var p: Vector2=Vector2(box.get_center().x,minf(box.end.y,s["floor"]))
	var span: float=clampf(box.size.x*.36,24,h*1.03)
	var phase: float=clampf(frame/maxf(1,float(s["frame_count"])-1),0,1)
	var alpha: float=.84 if s["active_regions"] else .38*(1.0-phase)
	# A real source attack field is an open basket with rubber court ripples,
	# not two angled sword swipes. It cannot invent a confirmed impact core.
	var center: Vector2=p+Vector2(0,-h*.22)
	_draw_dunk_rim(canvas,center,Vector2(span*.58,h*.16),h*.045,alpha*.82,phase)
	for n in range(2):
		var pulse: float=fposmod(frame*.065+float(n)*.5,1.0)
		var r: float=span*(.44+pulse*.49)
		_round_band(canvas,p,Vector2(r,r*.23),.13,PI-.13,0,h*.048,Color("ffbb5b"),BALL_SHADOW,alpha*(1.0-pulse)*.62)

static func _draw_paper_tower(canvas: CanvasItem,s: Dictionary) -> void:
	# The actual registered source box is tall and narrow; its child-local
	# positive Y compensates the off-screen parent origin. Use this world box.
	var box: Rect2=s["box"]
	var bottom: float=minf(box.end.y,float(s["floor"]))
	var top: float=box.position.y
	if bottom<=top: return
	var frame: float=s["frame"]
	var h: float=maxf(32,float(s["height"]))
	var center_x: float=box.get_center().x
	var width: float=box.size.x
	var extent: float=bottom-top
	var line: Array[Vector2]=[]
	for n in range(7):
		var u: float=float(n)/6.0
		line.append(Vector2(center_x+sin(frame*.15+u*TAU)*width*.055,lerpf(bottom-2,top+2,u)))
	_trace(canvas,line,maxf(1.3,width*.055),Color("7ab8d4"),.63)
	var count: int=clampi(int(extent/(h*.48)),12,32)
	var size: float=clampf(width*.17,3.2,h*.11)
	for n in range(count):
		var u: float=fposmod(float(n)/float(count)+frame*.019,1.0)
		var p: Vector2=Vector2(center_x+sin(frame*.22+float(n)*2.399)*width*.20,lerpf(top+size*1.75,bottom-size*1.75,u))
		var rot: float=sin(frame*.19+float(n)*1.71)*.72
		_paper(canvas,p,size,rot,.85,true)
		_trace(canvas,[p+Vector2(0,minf(size*2.2,bottom-p.y-1.0)),p],maxf(1.0,size*.14),Color("76b9d4"),.54)

static func _draw_normal_launcher(canvas: CanvasItem,s: Dictionary) -> void:
	# These are the two real Naruto W+J attacker children, not new skill bindings.
	# A feather-shaped material replaces the original clone artwork; no extra bird or ball.
	var box: Rect2=s["box"]
	var c: Vector2=box.get_center()
	var frame: float=s["frame"]
	var f: float=s["facing"]
	var progress: float=clampf(frame/maxf(1.0,float(s["frame_count"])-1),0,1)
	var active: bool=s["active_regions"]
	var a: float=.89 if active else .48*(1.0-progress*.72)
	var length: float=clampf(maxf(box.size.x,box.size.y)*.60,15,54)
	var dir: Vector2=Vector2(f*(.48 if s["name"]=="kj2mc" else -.36),-1).normalized()
	var side: Vector2=dir.orthogonal()
	for n in range(3):
		var offset: Vector2=side*(float(n)-1.0)*length*.16
		_trace(canvas,[c-dir*length*.64+offset,c+side*sin(frame*.22+n)*length*.075+offset,c+dir*length*.48+offset],maxf(1.8,length*(.095 if n==1 else .060)),COLORS["chicken"],a*(1.0-float(abs(n-1))*.24))
	if active: _fragments(canvas,c,COLORS["chicken"],length*.38,frame,3)

static func _ball_material() -> Texture2D:
	if _basketball_material!=null: return _basketball_material
	# A tiny original rubber material. Three palette tones light an actual sphere.
	# Its alpha is circular; this is a prop material, never a full-screen panel.
	var size: int=64
	var pixels: Image=Image.create(size,size,false,Image.FORMAT_RGBA8)
	var light: Vector3=Vector3(-.46,-.63,.68).normalized()
	var shadow: Color=Color("993c24")
	var rubber: Color=Color("ff7629")
	var lit: Color=Color("ffce76")
	for y in range(size):
		for x in range(size):
			var nx: float=(float(x)+.5-float(size)*.5)/(float(size)*.5)
			var ny: float=(float(y)+.5-float(size)*.5)/(float(size)*.5)
			var radial: float=nx*nx+ny*ny
			if radial>=1: continue
			var nz: float=sqrt(1.0-radial)
			var diffuse: float=clampf(Vector3(nx,ny,nz).dot(light),0,1)
			var shade: Color=shadow.lerp(rubber,diffuse/.58) if diffuse<.58 else rubber.lerp(lit,(diffuse-.58)/.42)
			# Fine, fixed rubber grain; it does not shimmer with the source clock.
			var grain: float=.025*sin(float(x*19+y*31))
			shade=shade.lightened(grain) if grain>0 else shade.darkened(-grain)
			shade.a=clampf((1.0-sqrt(radial))*float(size)*.58,0,1)
			pixels.set_pixel(x,y,shade)
	_basketball_material=ImageTexture.create_from_image(pixels)
	return _basketball_material

static func _draw_ball(canvas: CanvasItem,c: Vector2,box: Rect2,s: Dictionary) -> void:
	var tier: int=tier_for(str(s.get("binding_id","")))
	var h: float=maxf(32,s.get("height",90.0))
	var geometry: Dictionary=s["geometry"]
	var radius: float=geometry["radius"]
	var frame: float=float(s["frame"])*(-1.0 if s.get("mirror_y",false) else 1.0)
	if s["bullet_hit"]:
		_round_band(canvas,c,Vector2(radius,radius*.78),.2,2.4,frame*.13,maxf(3.5,radius*.26),COLORS["chicken"],BALL_SHADOW,.75)
		return
	var polygon: PackedVector2Array=PackedVector2Array()
	for n in range(40):polygon.append(c+Vector2.RIGHT.rotated(float(n)*TAU/40.0)*(radius+1.6))
	canvas.draw_colored_polygon(polygon,BALL_SHADOW)
	canvas.draw_texture_rect(_ball_material(),Rect2(c-Vector2.ONE*radius,Vector2.ONE*radius*2),false)
	canvas.draw_arc(c,radius*.985,0,TAU,40,Color("792b28"),maxf(1.15,radius*.027),true)
	for n in range(2):
		_curve(canvas,c,Vector2(radius*.94,radius*.57),0,TAU,maxf(.85,radius*.028),Color("612725"),.98,frame*.13+n*1.57,false)
	canvas.draw_arc(c+Vector2(-radius*.12,-radius*.13),radius*.68,3.56,4.49,14,Color("ffe4a5"),maxf(.8,radius*.025),true)
	var direction: Vector2=geometry["axis"]
	# Broad, round-ended rubber fans live beside the actual sphere. There is
	# no long tapered lane or tall invisible hit-box arc resembling a blade.
	var tail_center: Vector2=c-direction*radius*.27
	_round_band(canvas,tail_center,Vector2(radius*1.42,radius*.97),2.56,3.72,direction.angle(),maxf(2.7,radius*.15),Color("ff8b32"),BALL_SHADOW,.97)
	if tier>=2:_round_band(canvas,tail_center,Vector2(radius*1.78,radius*1.16),2.78,3.51,direction.angle(),maxf(1.6,radius*.077),Color("ffedbf"),BALL_SHADOW,.91)
	if geometry["strong_projectile"]:
		_round_band(canvas,c,Vector2(radius*1.25,radius*1.06),-.44,.44,direction.angle(),maxf(2.4,radius*.12),Color("ffe7ac"),BALL_SHADOW,.91)

## Derive the final blow from pinned actor regions or the child's own HitVO.
## A third basketball keeps its birth provenance when its owner is already idle.
static func _finishing_contact(effect: Dictionary,binding_id: String,binding: Dictionary,bundle: Dictionary,outcome: String) -> bool:
	if outcome!="hit" or tier_for(binding_id)<2: return false
	if effect.has("finisher") and str(binding.get("fighter_id","")) not in NEW_FIGHTERS: return bool(effect["finisher"])
	var hit_id: String=str(effect.get("hit_id",effect.get("source_name",effect.get("feedback",{}).get("hit_id",""))))
	var source_type: String=str(effect.get("source_type",effect.get("feedback",{}).get("source_type","actor")))
	if binding_id in ["worker:super","chicken:super_up","chicken:super_down"]:
		# These moves continue in an independent child after the last actor
		# region. Its actual final local HitVO window owns the ending beat.
		if source_type!="attacker":return false
		if hit_id!=str(FINAL_CHILD_HITS[binding_id]):return false
		var local: int=int(effect.get("source_frame",effect.get("source_absolute_frame",-1)))
		var window: Dictionary=_final_child_window(binding,bundle,hit_id)
		var birth: int=int(effect.get("source_spawn_absolute_frame",-1))
		return not window.is_empty() and (birth<0 or birth==int(window.birth)) and local>=int(window.start) and local<int(window.end)
	if source_type in ["bullet","attacker"]:
		if str(binding.get("fighter_id","")) in NEW_FIGHTERS:
			var local: int=int(effect.get("source_frame",-1))
			var birth: int=int(effect.get("source_spawn_absolute_frame",-1))
			var last_start: int=-1
			var last_end: int=-1
			var last_id: String=""
			for window: Dictionary in bundle.get("child_hits",[]):
				if int(window.birth)==birth and int(window.start)>=last_start:
					last_start=int(window.start);last_end=int(window.end_exclusive);last_id=str(window.hit_id)
			return last_start>=0 and hit_id==last_id and local>=last_start and local<last_end
		if FINAL_CHILD_HITS.has(binding_id): return hit_id==str(FINAL_CHILD_HITS[binding_id])
		if binding_id=="chicken:super":
			return int(effect.get("source_spawn_absolute_frame",-1))==int(bundle["start"])+65
		# Single-shot upper basketball has a separate real child final HitVO.
		return false
	var last: int=-1
	var last_end: int=-1
	var last_id: String=""
	for region: Dictionary in bundle.get("regions",[]):
		if int(region["start"])>=last: last=int(region["start"]);last_end=int(region["end_exclusive"]);last_id=str(region["hit_id"])
	if last<0 or hit_id!=last_id: return false
	# One final HitVO may expand through adjacent shape rectangles. The first
	# real contact of that uninterrupted window owns the ending beat. Walk
	# backwards only across matching contiguous regions: an earlier separate
	# strike with the same ID cannot be mistaken for a finisher.
	var extended:=true
	while extended:
		extended=false
		for region: Dictionary in bundle.get("regions",[]):
			if str(region["hit_id"])==last_id and int(region["end_exclusive"])==last and int(region["start"])<last:
				last=int(region["start"]);extended=true
	var absolute: int=int(effect.get("source_absolute_frame",-1))
	if absolute>=0: return absolute>=int(bundle["start"])+last and absolute<int(bundle["start"])+last_end
	if str(binding.get("fighter_id","")) in NEW_FIGHTERS:return false
	# Unique final IDs remain conclusive even without frame metadata. Repeated
	# IDs cannot prove a finisher and are intentionally treated as ordinary hits.
	var occurrences: int=0
	for region: Dictionary in bundle.get("regions",[]):
		if str(region["hit_id"])==last_id: occurrences+=1
	return occurrences==1

static func _final_child_window(binding: Dictionary,bundle: Dictionary,hit_id: String) -> Dictionary:
	var key: String=str(binding.get("profile",""))+":"+str(binding.get("slot",""))+":"+hit_id
	if _final_child_windows.has(key):return _final_child_windows[key]
	# Gameplay has already loaded this pinned timeline. Borrow its immutable
	# metadata instead of parsing a second 2.4MB JSON during the first finisher.
	var profile: Dictionary=SourceTimeline._profile_ref(str(binding.get("profile","")))
	for spawn: Dictionary in profile.get("spawn_events",[]):
		var birth_matches: bool=false
		for relative: Variant in bundle.spawn_frames:
			if int(relative)==int(spawn.frame)-int(bundle.start):birth_matches=true;break
		if not birth_matches:continue
		for instance: Dictionary in spawn.get("instances",[]):
			var child: Dictionary=profile.get("children",{}).get(str(instance.get("source_symbol","")),{})
			for region: Dictionary in child.get("areas",[]):
				if region.get("kind","")=="hit" and str(region.get("hit_id",""))==hit_id:
					var window: Dictionary={"start":int(region.source_start),"end":int(region.source_end),"source_symbol":instance.source_symbol,"birth":spawn.frame}
					_final_child_windows[key]=window
					return window
	_final_child_windows[key]={}
	return {}

static func _contact_motif(effect: Dictionary,binding: Dictionary,bundle: Dictionary,final: bool) -> String:
	var id: String=str(binding.get("fighter_id",""))
	var slot: String=str(binding.get("slot",""))
	var hit: String=str(effect.get("hit_id",effect.get("source_name","")))
	if id in NEW_FIGHTERS:
		return ("notification_mute" if final and slot=="SI" else ("notification_check" if slot=="WU" else "notification_contact")) if id=="notify" else ("cold_final_ink" if final else "cold_contact_brackets")
	if id=="chicken":
		if final:return "dunk_rim" if slot in ["SI","AIR_I"] else ("alley_oop" if slot=="WI" else "power_ball")
		return "rubber_compress" if str(effect.get("source_type","actor")) in ["bullet","attacker"] else ("ball_catch" if slot in ["WU","WI","AIR_I"] else "ball_bounce")
	if id=="cat":return "paw_slam" if final else ("paw_rage" if slot=="SI" else ("paw_grab" if slot=="I" else "paw_claw"))
	if id=="worker":return "clockout_stamp" if final and slot=="SI" else ("office_stamp" if final else ("paper_stack" if str(effect.get("source_type","actor"))=="attacker" else "briefcase_hit"))
	if id=="shark":return "deep_pressure" if final and slot in ["SI","AIR_I"] else ("jaw_pressure" if slot in ["I","SI"] else "shoe_water")
	if id!="rio":return "source_material"
	if slot=="SI":
		if final:return "blade_drop"
		if hit=="cbs4":return "blade_rotation"
		if hit in ["cbs3","cbs5"]:return "blade_rise"
		if hit=="cbs2":
			var order: int=0
			var relative: int=int(effect.get("source_absolute_frame",-1))-int(bundle.start)
			for region: Dictionary in bundle.regions:
				if str(region.hit_id)==hit and int(region.start)<=relative:order+=1
			return "blade_return" if order%2==0 else "blade_entry"
		return "blade_entry"
	if final:return "blade_drop" if slot=="AIR_I" else "blade_heavy"
	return "blade_return" if hit=="bs" else ("blade_rise" if slot in ["WU","WI"] else "blade_entry")

## Exposed contour contract, used by both rendering and source-backed tests.
## Ball contacts use bounded round rubber surfaces; they have no cut lanes.
static func contact_geometry(state: Dictionary) -> Dictionary:
	if not state.get("ready",false):return {"ready":false}
	if str(state.get("id","")) in NEW_FIGHTERS:
		var fx: Variant=_character_fx(str(state["id"]))
		return fx.contact_geometry(state) if fx!=null else {"ready":false,"body_copies":0}
	var h: float=state["height"]
	var final: bool=state["finisher"]
	var tier: int=state["tier"]
	var center: Vector2=state["pos"]
	var phase: float=state["phase"]
	if state["id"]=="chicken":
		var radius: float=h*(.57 if tier>=3 else .44) if final else h*(.19 if tier==1 else .28)
		var rubber_radius: Vector2=Vector2(radius*.72,radius*.54)*(1.0+phase*.22)
		var basket: bool=state["contact_motif"] in ["dunk_rim","alley_oop"]
		var rim_radius: Vector2=Vector2(radius,radius*(.27 if basket else .74))*(1.0+phase*.30)
		return {"ready":true,"motif":state["contact_motif"],"center":center,"rubber_radius":rubber_radius,"ring_radius":rim_radius,"width":h*(.071 if final else .043),"seamed_rubber":true,"rounded_caps":true,"cut_lanes":[],"body_copies":0,"source_confirmed":true}
	if state["id"] in ["cat","worker","shark"]:
		return {"ready":true,"motif":state["contact_motif"],"center":center,"tier":tier,"finisher":final,"material":{"cat":"paw_claw","worker":"paper_stamp","shark":"water_pressure"}[state["id"]],"body_copies":0,"opaque_plate":false,"source_confirmed":true,"floor_contact":state["floor_contact"]}
	return {"ready":true,"motif":state["contact_motif"],"center":center,"blade_axis":state["attack_axis"],"cut_width":state["strike_width"],"body_copies":0,"source_confirmed":true}

static func sample_contact(effect: Dictionary,layer: String="front") -> Dictionary:
	var id: String=str(effect.get("fighter_id",effect.get("id","")))
	var binding_id: String=str(effect.get("binding_id",effect.get("source_binding_id","")))
	var binding: Dictionary=_load().get("bindings",{}).get(binding_id,{})
	if layer!="front" or not COLORS.has(id) or binding.is_empty() or not bool(effect.get("confirmed",true)): return {"ready":false}
	if id in NEW_FIGHTERS and str(binding.get("fighter_id",""))!=id:return {"ready":false}
	var feedback: Dictionary=effect.get("feedback",{})
	if int(feedback.get("hit_type",2))==0: return {"ready":false}
	var outcome: String=str(effect.get("outcome",effect.get("contact","hit")))
	if outcome not in ["hit","guard","counter","blocked","armor","steel","guard_break","bullet_clash"]: return {"ready":false}
	var bundle: Dictionary=_load()["bundles"][binding["bundle"]]
	var tier: int=tier_for(binding_id)
	var final: bool=_finishing_contact(effect,binding_id,binding,bundle,outcome)
	var duration: float=.22 if tier==1 else (.28 if tier==2 else .32)
	if final: duration+=.035
	if outcome in ["guard","blocked","armor","steel","counter","bullet_clash"]: duration=.22
	var age: float=float(effect.get("visual_age",effect.get("age",0.0)))
	if not is_finite(age) or age<0 or age>=duration: return {"ready":false}
	var p: Vector2=_v(effect.get("position",effect.get("pos",Vector2.ZERO)))
	if not p.is_finite(): return {"ready":false}
	var h: float=clampf(float(effect.get("body_height",90.0)),32,180)
	var phase: float=clampf(age/duration,0,1)
	var radius: float=h*(.27 if tier==1 else (.37 if tier==2 else .47))*(1.18 if final else 1.0)
	var core: float=h*(.10 if tier==1 else (.13 if tier==2 else .16))*(1.15 if final else 1.0)
	if outcome in ["guard","blocked","armor","steel","counter","bullet_clash"]: radius=h*.20;core=h*.058
	var floor: float=float(effect.get("floor_y",feedback.get("floor_y",p.y+200)))
	var grounded: bool=bool(effect.get("target_grounded",feedback.get("target_grounded",false)))
	var floor_contact: bool=grounded and absf(floor-p.y)<=maxf(24.0,h*.40)
	var direction: int=int(effect.get("facing",effect.get("direction",feedback.get("direction",1))))
	var axis: Vector2=_v(effect.get("attack_axis",Vector2.ZERO))
	var attacker_anchors: Dictionary=effect.get("attacker_anchors",{})
	if axis.length_squared()<.01 and id=="rio" and attacker_anchors.has("weapon_tip") and attacker_anchors.has("weapon_grip"):
		axis=_v(attacker_anchors["weapon_tip"])-_v(attacker_anchors["weapon_grip"])
	if axis.length_squared()<.01 and id=="chicken":axis=_v(effect.get("object_velocity",Vector2.ZERO))
	if not axis.is_finite() or axis.length_squared()<.01:axis=Vector2(1 if direction>=0 else -1,-.36)
	axis=axis.normalized()
	var visual_stage: String="contact" if age<.045 else ("follow_through" if age<duration*.62 else "settle")
	if final and age<.11:visual_stage="finale"
	var strike_width: float=h*(.056 if tier==1 else (.078 if tier==2 else .104))*(1.13 if final else 1.0)
	var debris_budget: int=4 if tier==1 else (7 if tier==2 else 10)
	if outcome!="hit":debris_budget=3;strike_width=h*.032
	# A proven last HitVO earns a much wider material face than its previous
	# multihits. This changes only paint geometry, never the actual source area.
	var finale_reach: float=h*(.84 if tier==2 else 1.22) if final else 0.0
	var finale_width: float=h*(.17 if tier==2 else .23) if final else 0.0
	var state: Dictionary={"ready":true,"id":id,"binding_id":binding_id,"tier":tier,"finisher":final,"outcome":outcome,"family":str(feedback.get("family","strike")),"hit_type":int(feedback.get("hit_type",2)),"pos":p,"height":h,"radius":radius,"core_radius":core,"duration":duration,"age":age,"phase":phase,"alpha":pow(1.0-phase,1.45),"core_alpha":pow(clampf(1.0-age/.045,0,1),1.8),"direction":1 if direction>=0 else -1,"attack_axis":axis,"strike_width":strike_width,"debris_budget":debris_budget,"finale_reach":finale_reach,"finale_width":finale_width,"visual_stage":visual_stage,"ground_splash":final and floor_contact and outcome=="hit","floor_y":floor,"floor_contact":floor_contact,"contains_character":false,"source_clock_mutated":false}
	state["slot"]=binding["slot"]
	for key: String in ["hit_id","source_frame","source_absolute_frame","source_spawn_absolute_frame","source_type","attacker_anchors","target_anchors"]:
		state[key]=effect.get(key,{} if key.ends_with("anchors") else ("" if key in ["hit_id","source_type"] else -1))
	state["birth_source_absolute_frame"]=effect.get("source_spawn_absolute_frame",-1)
	state["child"]=str(effect.get("source_type","actor")) in ["attacker","bullet"]
	if id in NEW_FIGHTERS:
		state["confirmed"]=true
		# Checkers have no HitVO and cannot reach the accepted contact painter.
		if str(effect.get("hit_id","")) in ["zh10","zh10atm","mianchecker","bs_chkm","cbs_chkm"]:return {"ready":false}
		state["checker_only"]=false
	state["contact_motif"]=_contact_motif(effect,binding,bundle,final)
	state["geometry"]=contact_geometry(state)
	return state

static func draw_contact(canvas: CanvasItem,effect: Dictionary,layer: String="front") -> Dictionary:
	var state: Dictionary=sample_contact(effect,"front")
	if not state.get("ready",false): return state
	var character_fx: Variant=_character_fx(str(state["id"]))
	if character_fx!=null:
		if state["id"]!="wojak":MaterialLayers.draw(canvas,state,layer,true)
		character_fx.draw_contact(canvas,state,layer)
		return state
	if layer=="back":
		if state["finisher"] and state["id"] in ["rio","chicken"]:_draw_finale_back(canvas,state)
		return state
	if layer!="front":return {"ready":false}
	var id: String=state["id"]
	var outcome: String=state["outcome"]
	var p: Vector2=state["pos"]
	var h: float=state["height"]
	var r: float=state["radius"]
	var age: float=state["age"]
	var phase: float=state["phase"]
	var a: float=state["alpha"]
	var f: float=float(state["direction"])
	var color: Color=COLORS[id]
	if id in ["rio","chicken"]:
		_draw_painted_contact(canvas,state)
		return state
	if outcome in ["armor","steel"]:
		# Body armor gives an angular hard ping. It never becomes a shield arc.
		_trace(canvas,[p+Vector2(-h*.12,h*.035),p+Vector2(h*.13,-h*.035)],h*.023,WHITE,a)
		_trace(canvas,[p+Vector2(h*.01,-h*.10),p+Vector2(-h*.01,h*.10)],h*.018,color,a*.70)
		_fragments(canvas,p,Color("ffdf85"),h*.18,age*30,3)
		return state
	if outcome in ["guard","blocked"]:
		var rotation: float=0.0 if f>=0 else PI
		_curve(canvas,p-Vector2(f*h*.015,0),Vector2(h*.13,h*.22),-.85,.85,h*.026,Color("65c8e4"),a,rotation)
		_trace(canvas,[p-Vector2(f*h*.07,0),p+Vector2(f*h*.09,-h*.05)],h*.016,WHITE,a)
		_fragments(canvas,p,Color("abecff"),h*.14,age*30,3)
		return state
	if outcome in ["counter","bullet_clash"]:
		_trace(canvas,[p-Vector2(r*.7,r*.7),p+Vector2(r*.7,r*.7)],h*.032,color,a)
		_trace(canvas,[p-Vector2(r*.7,-r*.7),p+Vector2(r*.7,-r*.7)],h*.023,WHITE,a)
		_fragments(canvas,p,color,r,age*30,4)
		return state
	# The white contact nucleus lasts 45 ms, while thin fragments survive the
	# heavy hitstop. This exposes the reaction body immediately after contact.
	if state["core_alpha"]>0:
		_contact_core(canvas,p,float(state["core_radius"]),color,float(state["core_alpha"]),id,f)
	var expansion: float=.52+phase*1.22
	var axis: Vector2=Vector2(f,-.36).normalized()
	var side: Vector2=axis.orthogonal()
	match id:
		"rio":
			_trace(canvas,[p-axis*r*expansion,p-axis*r*.10,p+axis*r*expansion],h*(.036 if state["finisher"] else .025),color,a)
			if state["tier"]>=2: _trace(canvas,[p-side*r*.68,p,p+side*r*.72],h*.020,WHITE,a*.72)
		"cat":
			for n in range(3):
				var base: Vector2=p+side*(float(n)-1.0)*h*.064
				_trace(canvas,[base-axis*r*.58,base+axis*r*(.38+phase*.58)],h*.021,color,a*(1.0-float(n)*.13))
			if state["finisher"]: _curve(canvas,p,Vector2(r*expansion,r*expansion*.52),-.65,.75,h*.019,color,a*.72,axis.angle())
		"worker":
			# A stamping angle and tumbling sheets read as office pressure.
			_stamp(canvas,p,h*(.15 if state["tier"]==1 else .22),color,a*(1.0-phase*.4),age*30)
			for n in range(3 if state["tier"]==1 else 6):
				var angle: float=float(n)*2.399+.25
				var dir: Vector2=Vector2.RIGHT.rotated(angle)
				_paper(canvas,p+dir*r*(.36+phase*1.34),h*.037,angle+age*4,a*.76,true)
		"chicken":
			# Open seam arcs and short lane streaks carry basketball material.
			_curve(canvas,p,Vector2(r*expansion,r*.56*expansion),.12,1.42,h*.026,color,a,age*2)
			_curve(canvas,p,Vector2(r*.86*expansion,r*.43*expansion),3.12,4.24,h*.019,WHITE,a*.73,-age*2)
			for n in range(2 if state["tier"]==1 else 4):
				var base: Vector2=p+Vector2(-f*r*.6,(float(n)-1.5)*h*.058)
				_trace(canvas,[base,base+Vector2(f*r*(1.1+phase*.5),0)],h*.017,color,a*.6)
		"shark":
			for n in range(4 if state["tier"]==1 else 6):
				var angle: float=-PI*.88+float(n)*PI*.19
				var dir: Vector2=Vector2(cos(angle)*f,sin(angle))
				_drop(canvas,p+dir*r*(.33+phase*.65),dir*r*(.45+phase*.33),color,a,h*.022)
			if state["finisher"]: _curve(canvas,p+Vector2(0,h*.08),Vector2(r*expansion,r*.23),PI*.1,PI*.85,h*.026,color,a*.74)
	_fragments(canvas,p,color,r*(.60+phase*.55),age*30,5 if state["tier"]==1 else (7 if state["tier"]==2 else 10))
	if state["finisher"]:
		# The finishing beat is wider and more directional than prior combo hits.
		for n in range(3):
			var dir: Vector2=Vector2(f,-.46+float(n)*.40).normalized()
			var reach: float=r*(.95+phase*.65)
			_trace(canvas,[p+dir*reach*.58,p+dir*reach],h*.020,color,a*.79)
		if state["floor_contact"]: _draw_ground_finish(canvas,state,color)
	if outcome=="guard_break":
		for n in range(3): _trace(canvas,[p+side*(float(n)-1.0)*r*.35,p+axis*r*.82+side*(float(n)-1.0)*r*.51],h*.022,Color("9eeeff"),a)
	return state

static func _draw_painted_contact(canvas: CanvasItem,s: Dictionary) -> void:
	var id: String=s["id"]
	var p: Vector2=s["pos"]
	var h: float=s["height"]
	var radius: float=s["radius"]
	var phase: float=s["phase"]
	var alpha: float=s["alpha"]
	var axis: Vector2=s["attack_axis"]
	var side: Vector2=axis.orthogonal()
	var color: Color=COLORS[id]
	var shadow: Color=RIO_SHADOW if id=="rio" else BALL_SHADOW
	var outcome: String=s["outcome"]
	if outcome in ["guard","blocked"]:
		var facing: float=float(s["direction"])
		_solid_stroke(canvas,_ellipse_points(p-Vector2(facing*h*.026,0),Vector2(h*.14,h*.23),-.82,.82,0 if facing>0 else PI),h*.047,Color("8adef0"),INK,alpha)
		_solid_stroke(canvas,[p-axis*h*.067,p+axis*h*.055],h*.039,WHITE,INK,alpha)
		_draw_material_chips(canvas,p,Color("a7e4fa"),INK,h*.020,h*.13,phase,alpha,3)
		return
	if outcome in ["armor","steel","counter","bullet_clash"]:
		var across: Vector2=axis.orthogonal()
		_solid_stroke(canvas,[p-axis*h*.13,p+axis*h*.13],h*.047,WHITE,shadow,alpha)
		_solid_stroke(canvas,[p-across*h*.088,p+across*h*.088],h*.034,Color("ffe0a0") if outcome in ["armor","steel"] else color,shadow,alpha)
		_draw_material_chips(canvas,p,color,shadow,h*.024,h*.20,phase,alpha,3)
		return
	# Dense center remains brief. The recognizable material is a shaded painted
	# cut face or broken ball panel, never a generic full-screen geometric card.
	if s["core_alpha"]>.001:
		_contact_core(canvas,p,s["core_radius"],color,s["core_alpha"],id,float(s["direction"]))
	if id=="rio":
		var reach: float=s["finale_reach"]*(.88+phase*.46) if s["finisher"] else radius*(.74+phase*.76)
		var motif: String=s["contact_motif"]
		if motif=="blade_rotation":
			# One broad rotating wake follows the real cbs4 multi-hit. No second
			# cross-shaped cut is stamped onto every frame of the spin.
			var angle: float=axis.angle()+phase*.60
			_round_band(canvas,p,Vector2(radius*(.84+phase*.61),radius*.60),-.12,1.62,angle,h*.083,Color("98e0ff"),RIO_SHADOW,alpha*.86)
			_round_band(canvas,p,Vector2(radius*.80,radius*.47),2.93,3.79,angle,h*.032,Color("e5f7ff"),RIO_SHADOW,alpha*.66)
		elif motif=="blade_drop":
			# A single silver-blue falling blade with a gold leading edge gives
			# SI its own final silhouette. Energy expands behind the body.
			var down: Vector2=Vector2(float(s["direction"])*.23,1).normalized()
			var flank: Vector2=down.orthogonal()
			var path: Array[Vector2]=[p-down*reach*.91,p-down*reach*.30+flank*h*.030,p+down*reach*.17,p+down*reach*.69]
			_solid_stroke(canvas,path,h*(.105 if s["tier"]>=3 else .073),Color("b1eaff"),RIO_SHADOW,alpha*.82)
			var edge: Array[Vector2]=[]
			for point: Vector2 in path:edge.append(point+flank*h*.026)
			_solid_stroke(canvas,edge,h*.029,Color("ffe09b"),RIO_SHADOW,alpha*.84)
		else:
			var lift: float=-.19 if motif=="blade_return" else .14
			if motif=="blade_rise":lift=-.34
			var path: Array[Vector2]=[p-axis*reach,p-axis*reach*.29+side*radius*lift,p+axis*reach*.34-side*radius*lift*.6,p+axis*reach*1.01]
			_solid_stroke(canvas,path,s["finale_width"]*.62 if s["finisher"] else s["strike_width"],Color("d1f1ff") if motif=="blade_return" else Color("79d8ff"),RIO_SHADOW,alpha*.90)
			if s["finisher"]:_solid_stroke(canvas,path,h*.039,Color("fff0b3"),RIO_SHADOW,alpha*.83)
		# Material fragments remain local; the defender's recoil is visible
		# after the same 45ms white nucleus as before.
		_draw_material_chips(canvas,p,Color("bddfff"),RIO_SHADOW,h*.041 if s["finisher"] else h*.023,reach*.76 if s["finisher"] else radius*1.05,phase,alpha,6 if s["finisher"] else 3)
	else:
		_draw_basketball_contact(canvas,s)
	# Pool water/deck debris is owned by the stage feedback layer. Returning
	# ground_splash provides one clear true-contact trigger instead of duplicates.

static func _draw_finale_back(canvas: CanvasItem,s: Dictionary) -> void:
	var p: Vector2=s["pos"]
	var h: float=s["height"]
	var reach: float=s["finale_reach"]
	var phase: float=s["phase"]
	var alpha: float=s["alpha"]*.24
	var angle: float=Vector2(s["attack_axis"]).angle()
	var color: Color=Color("91dfff") if s["id"]=="rio" else Color("ffc770")
	var shadow: Color=RIO_SHADOW if s["id"]=="rio" else BALL_SHADOW
	if s["id"]=="chicken":
		var geometry: Dictionary=s["geometry"]
		var rim_radius: Vector2=geometry["ring_radius"]
		if s["contact_motif"] in ["dunk_rim","alley_oop"]:
			_draw_dunk_rim(canvas,p-Vector2(0,h*.041),rim_radius,h*.038,s["alpha"]*.92,phase)
		else:
			_round_band(canvas,p,rim_radius,-.25,.86,angle,h*.042,Color("ff8d35"),BALL_SHADOW,s["alpha"]*.67)
			_round_band(canvas,p,rim_radius*.83,2.65,3.62,angle,h*.027,Color("ffe3a4"),BALL_SHADOW,s["alpha"]*.56)
		return
	if s["contact_motif"]=="blade_drop":
		var down: Vector2=Vector2(float(s["direction"])*.23,1).normalized()
		for n in [-1,1]:
			var center: Vector2=p+down.orthogonal()*float(n)*h*.11
			_solid_stroke(canvas,[center-down*reach*.72,center-down*reach*.18,center+down*reach*.71],h*.073,Color("c7efff"),RIO_SHADOW,s["alpha"]*.29)
		_round_band(canvas,p,Vector2(h*.64,h*.45),.30,2.73,down.angle(),h*.063,Color("ffd38a"),RIO_SHADOW,s["alpha"]*.31)
		return
	# Contact-centered open crescents behind the body remain valid in the air.
	# No ellipse is relocated to the pool floor; water stays ground_splash-only.
	for n in range(3):
		var r: float=reach*(.64+phase*.97+float(n)*.15)
		var begin: float=float(n)*2.08+.17
		_solid_stroke(canvas,_ellipse_points(p,Vector2(r,r*.57),begin,begin+1.40,angle),h*(.054 if n==0 else .039),color,shadow,alpha/(1.0+float(n)*.28))

static func _draw_basketball_contact(canvas: CanvasItem,s: Dictionary) -> void:
	var geometry: Dictionary=s["geometry"]
	var p: Vector2=s["pos"]
	var h: float=s["height"]
	var phase: float=s["phase"]
	var alpha: float=s["alpha"]
	var axis: Vector2=s["attack_axis"]
	var rotation: float=axis.angle()
	var rubber: Vector2=geometry["rubber_radius"]
	var width: float=geometry["width"]
	# Rubber compresses normal to the real arrival direction. Its opaque skin
	# is brief; open rings and curved ball fragments reveal the victim below.
	if float(s["age"])<.085:
		var compression: float=clampf(1.0-float(s["age"])/.085,0,1)
		var squash: Vector2=Vector2(rubber.x*.47,rubber.y*.74)
		_rubber_fan(canvas,p,squash,-PI*.82,PI*.82,rotation,alpha*compression*.68)
		_round_band(canvas,p,squash,-.78,.78,rotation,maxf(1.4,h*.018),Color("ffdc8b"),BALL_SHADOW,alpha*compression*.90)
	# Short orange half-rings have equal-width round caps. A ball hit can no
	# longer accidentally display the shared silver sword lane / blue scythe.
	var basket: bool=s["contact_motif"] in ["dunk_rim","alley_oop"] and s["finisher"]
	if not basket:
		_round_band(canvas,p,rubber,.12,1.35,rotation,width*.63,Color("ff8e34"),BALL_SHADOW,alpha*.96)
		_round_band(canvas,p,rubber*.68,2.88,3.55,rotation,width*.28,Color("fff0c5"),BALL_SHADOW,alpha*.69)
	var count: int=4 if s["finisher"] else 2
	for n in range(count):
		var angle: float=float(n)*TAU/float(count)+.39
		var dir: Vector2=Vector2.RIGHT.rotated(angle)
		var center: Vector2=p+dir*h*(.12+phase*(.31 if s["finisher"] else .21))
		var size: float=h*(.116 if s["finisher"] else .069)*(1.0-float(n%2)*.16)
		_rubber_fan(canvas,center,Vector2(size,size*.86),-.59,.66,angle+phase*.74,alpha*.92)
	if s["finisher"] and not basket:
		var ring: Vector2=geometry["ring_radius"]
		_round_band(canvas,p,ring,-.21,.44,rotation,width*.35,Color("ffe3a4"),BALL_SHADOW,alpha*.58)

static func _draw_dunk_rim(canvas: CanvasItem,center: Vector2,radius: Vector2,width: float,alpha: float,phase: float) -> void:
	# A recognizable oval hoop + a short white woven net. Entirely visual and
	# contact-centered; aerial dunks never paint a false floor impact.
	_round_band(canvas,center,radius,0,PI,0,width,Color("ff702a"),BALL_SHADOW,alpha*.94)
	var net_height: float=radius.y*(.74+sin(phase*PI)*.25)
	for n in range(5):
		var u: float=float(n)/4.0
		var x: float=lerpf(-radius.x*.83,radius.x*.83,u)
		var top: Vector2=center+Vector2(x,radius.y*.32)
		var bottom: Vector2=center+Vector2(x*.65,radius.y*.48+net_height)
		canvas.draw_line(top,bottom,Color("3f7da0",alpha*.91),maxf(2.6,width*.56),true)
		canvas.draw_line(top,bottom,Color("f3ffff",alpha*.98),maxf(1.4,width*.31),true)
		if n<4:
			var next_x: float=lerpf(-radius.x*.83,radius.x*.83,float(n+1)/4.0)
			canvas.draw_line(top.lerp(bottom,.36),center+Vector2(next_x*.73,radius.y*.48+net_height*.78),Color("e5fbff",alpha*.96),maxf(1.2,width*.26),true)
	_round_band(canvas,center,radius,PI,TAU,0,width,Color("ff9c43"),BALL_SHADOW,alpha)

static func _draw_ball_panel(canvas: CanvasItem,center: Vector2,radius: float,angle: float,alpha: float) -> void:
	var points: PackedVector2Array=PackedVector2Array([center])
	for n in range(7):
		points.append(center+Vector2.RIGHT.rotated(angle-.44+float(n)/6.0*.88)*radius)
	canvas.draw_polygon(points,PackedColorArray([Color("e88a30",alpha),Color("f5a647",alpha),Color("ffd07b",alpha),Color("ffc064",alpha),Color("f4a144",alpha),Color("e18b35",alpha),Color("d77a2e",alpha),Color("ce6e29",alpha)]))
	var closed: PackedVector2Array=points.duplicate();closed.append(points[0])
	canvas.draw_polyline(closed,Color(BALL_SHADOW,alpha),maxf(1.3,radius*.11),true)
	canvas.draw_line(center,center+Vector2.RIGHT.rotated(angle)*radius,Color(BALL_SHADOW,alpha),maxf(1.0,radius*.075),true)

static func _draw_material_chips(canvas: CanvasItem,p: Vector2,color: Color,shadow: Color,size: float,reach: float,phase: float,alpha: float,count: int) -> void:
	for n in range(count):
		var angle: float=float(n)*2.399+.36
		var axis: Vector2=Vector2.RIGHT.rotated(angle)
		var side: Vector2=axis.orthogonal()
		var center: Vector2=p+axis*reach*(.34+phase*(.93+float(n%2)*.13))
		var points: PackedVector2Array=PackedVector2Array([center-axis*size,center+axis*size*.88,center+side*size*.46,center-axis*size*.29+side*size*.24])
		canvas.draw_colored_polygon(points,Color(color,alpha*.90))
		var edge: PackedVector2Array=points.duplicate();edge.append(points[0])
		canvas.draw_polyline(edge,Color(shadow,alpha*.83),maxf(.8,size*.15),true)

static func _contact_core(canvas: CanvasItem,p: Vector2,radius: float,color: Color,alpha: float,id: String,f: float) -> void:
	var polygon: PackedVector2Array=PackedVector2Array()
	if id=="chicken":
		for n in range(24):
			var angle: float=float(n)*TAU/24.0
			polygon.append(p+Vector2(cos(angle)*radius*.64,sin(angle)*radius*.87))
		canvas.draw_colored_polygon(polygon,Color(color,alpha*.92))
		canvas.draw_circle(p,radius*.35,Color(WHITE,alpha))
		_round_band(canvas,p,Vector2(radius*.58,radius*.80),-.56,.66,.0,maxf(1.2,radius*.10),WHITE,BALL_SHADOW,alpha*.79)
		return
	for n in range(12):
		var angle: float=float(n)*TAU/12.0-.18*f
		var reach: float=radius*(1.0 if n%2==0 else .24)
		polygon.append(p+Vector2(cos(angle),sin(angle))*reach)
	canvas.draw_colored_polygon(polygon,Color(color,alpha*.87))
	var inner: PackedVector2Array=PackedVector2Array()
	for point: Vector2 in polygon: inner.append(p+(point-p)*.63)
	canvas.draw_colored_polygon(inner,Color(WHITE,alpha))

static func _draw_ground_finish(canvas: CanvasItem,s: Dictionary,color: Color) -> void:
	var p: Vector2=Vector2(s["pos"].x,s["floor_y"])
	var radius: float=s["radius"]*(1.05+s["phase"]*1.52)
	for n in range(3):
		_curve(canvas,p,Vector2(radius,radius*.15),float(n)*2.1+.08,float(n)*2.1+1.16,maxf(1.25,s["height"]*.019),color,s["alpha"]*.58)
	for n in range(6):
		var direction: float=-1.0 if n%2==0 else 1.0
		var u: float=float(s["phase"])
		var q: Vector2=p+Vector2(direction*s["radius"]*(.26+u*(1.1+float(n)*.08)),-sin(u*PI)*s["height"]*(.12+float(n)*.022))
		var size: float=maxf(1.3,s["height"]*.021)
		canvas.draw_colored_polygon(PackedVector2Array([q+Vector2(-size,0),q+Vector2(size*.2,-size*1.45),q+Vector2(size,size*.4)]),Color(Color("a7bac5"),s["alpha"]*.77))

## Tapered strokes use line primitives; no self-intersecting fan polygons.
static func _trace(canvas: CanvasItem,points: Array,width: float,color: Color,alpha: float) -> void:
	if points.size()<2: return
	var count: int=points.size()-1
	for n in range(count):
		var u: float=(float(n)+.5)/float(count)
		var w: float=maxf(.7,width*pow(sin(PI*u),.65))
		var p: Vector2=points[n]
		var q: Vector2=points[n+1]
		canvas.draw_line(p,q,Color(INK,alpha*.43),w*1.65,true)
		canvas.draw_line(p,q,Color(color,alpha),w,true)
		canvas.draw_line(p,q,Color(1,.97,.91,alpha*.93),maxf(.6,w*.30),true)

static func _curve(canvas: CanvasItem,c: Vector2,radius: Vector2,begin: float,end: float,width: float,color: Color,alpha: float,rotation: float=0.0,core: bool=true) -> void:
	var points: Array[Vector2]=[]
	for n in range(13):
		var angle: float=lerpf(begin,end,float(n)/12.0)
		points.append(c+Vector2(cos(angle)*radius.x,sin(angle)*radius.y).rotated(rotation))
	if core: _trace(canvas,points,width,color,alpha)
	else:
		for n in range(12): canvas.draw_line(points[n],points[n+1],Color(color,alpha),width,true)

static func _spark(canvas: CanvasItem,p: Vector2,color: Color,radius: float,alpha: float,frame: float) -> void:
	for n in range(4):
		var d: Vector2=Vector2.RIGHT.rotated(float(n)*PI*.5+frame*.17)
		_trace(canvas,[p-d*radius,p,p+d*radius*.74],maxf(1.0,radius*.27),color,alpha)

static func _fragments(canvas: CanvasItem,p: Vector2,color: Color,radius: float,frame: float,count: int) -> void:
	for n in range(count):
		var angle: float=float(n)*2.399+frame*.07
		var v: Vector2=Vector2.RIGHT.rotated(angle)
		var offset: float=fposmod(frame*.10+float(n)*.21,1.0)
		var q: Vector2=p+v*radius*(.28+offset)
		_trace(canvas,[q,q+v*radius*.18],maxf(1.0,radius*.065),color,(1.0-offset)*.75)

static func _paper(canvas: CanvasItem,p: Vector2,size: float,rotation: float,alpha: float,contrast: bool=false) -> void:
	var axis: Vector2=Vector2.RIGHT.rotated(rotation)
	var side: Vector2=axis.orthogonal()
	var width: float=size*(.2+.8*absf(cos(rotation)))
	var pts: PackedVector2Array=PackedVector2Array([p-axis*width-side*size*.65,p+axis*width-side*size*.65,p+axis*width+side*size*.65,p-axis*width+side*size*.65])
	if contrast:
		var shadow: PackedVector2Array=PackedVector2Array()
		for point: Vector2 in pts: shadow.append(point+Vector2(1.1,1.5))
		canvas.draw_colored_polygon(shadow,Color(.12,.24,.32,alpha*.32))
		canvas.draw_polygon(pts,PackedColorArray([Color(.99,.99,1,alpha),Color(.84,.90,.96,alpha),Color(.74,.82,.89,alpha),Color(.94,.97,1,alpha)]))
	else:
		canvas.draw_colored_polygon(pts,Color(.94,.97,1,alpha))
	for n in range(4): canvas.draw_line(pts[n],pts[(n+1)%4],Color(Color("365169" if contrast else "47738c"),alpha*(.98 if contrast else .8)),1.15 if contrast else 1.0,true)
	canvas.draw_line(p-axis*width*.5,p+axis*width*.5,Color(Color("ee6270"),alpha),1.0,true)

static func _stamp(canvas: CanvasItem,p: Vector2,size: float,color: Color,alpha: float,frame: float) -> void:
	var axis: Vector2=Vector2.RIGHT.rotated(-.18+.04*sin(frame))
	var side: Vector2=axis.orthogonal()
	var pts: Array[Vector2]=[p-axis*size-side*size*.63,p+axis*size-side*size*.63,p+axis*size+side*size*.63,p-axis*size+side*size*.63]
	for n in range(4): _trace(canvas,[pts[n],pts[(n+1)%4]],maxf(1.2,size*.09),color,alpha)
	_trace(canvas,[p-axis*size*.38-side*size*.28,p-axis*size*.38+side*size*.28,p+axis*size*.32+side*size*.28],maxf(1.2,size*.09),color,alpha)
	_trace(canvas,[p+axis*size*.32-side*size*.28,p+axis*size*.32+side*size*.28],maxf(1.2,size*.09),color,alpha)

static func _drop(canvas: CanvasItem,p: Vector2,direction: Vector2,color: Color,alpha: float,width: float) -> void:
	_trace(canvas,[p-direction*.55,p,p+direction*.16],maxf(1,width),color,alpha)

static func _floor_ripple(canvas: CanvasItem,p: Vector2,radius: float,color: Color,frame: float,alpha: float) -> void:
	for n in range(3):
		var r: float=radius*(.55+float(n)*.22+.08*sin(frame*.3+n))
		_curve(canvas,p,Vector2(r,r*.19),.15+float(n)*1.2,1.05+float(n)*1.2,maxf(1.3,radius*.024),color,alpha*(1.0-float(n)*.18))

## Real archive tuples disambiguate two Notify U children sharing one name.
static func _roster_object_catalog(binding: Dictionary,state: Dictionary) -> Dictionary:
	var bundle: Dictionary=_load().get("bundles",{}).get(str(binding.get("bundle","")),{})
	var rank: int=0
	for child: Dictionary in bundle.get("source_objects",[]):
		if int(child.source_birth_frame)==int(state.get("birth_source_absolute_frame",-1)) and str(child.source_symbol)==str(state.get("symbol","")) and str(child.instance_name)==str(state.get("name","")):
			var result: Dictionary={"release_rank":rank,"collision_windows":child.get("collision_windows",[])}
			return result
		rank+=1
	return {}

static func _roster_checker_only(catalog: Dictionary,frame: int) -> bool:
	var checker: bool=false
	var damage: bool=false
	for window: Dictionary in catalog.get("collision_windows",[]):
		if frame<int(window.start) or frame>=int(window.end_exclusive):continue
		if str(window.kind) in ["checker","unregistered_hit"]:checker=true
		elif str(window.kind)=="hit" and not str(window.get("hit_id","")).is_empty():damage=true
	return checker and not damage

## Stage spans come from executable labels, actual HitVO windows, births and
## source control calls. They do not predict accepted contact or child lifetime.
static func _roster_cinema_phase(id: String,command: String,label: String,absolute: float,binding: Dictionary,bundle: Dictionary) -> Dictionary:
	var metadata: Dictionary=bundle.labels[label]
	var begin: float=float(metadata.frame)
	var end: float=float(metadata.source_end_frame)+1.0
	if absolute<begin or absolute>=end:return {"ready":false}
	var slot: String=str(binding.slot)
	var active_first: float=end
	var active_last: float=begin
	var active: bool=false
	var entry_transition: float=-1.0
	var recovery_start: float=end
	for region: Dictionary in bundle.get("regions",[]):
		var lo: float=float(bundle.start)+float(region.start)
		var hi: float=float(bundle.start)+float(region.end_exclusive)
		if hi<=begin or lo>=end:continue
		active_first=minf(active_first,maxf(lo,begin));active_last=maxf(active_last,minf(hi,end))
		if absolute>=lo and absolute<hi:active=true
	for birth: Variant in bundle.get("spawn_frames",[]):
		var lo: float=float(bundle.start)+float(birth)
		if lo<begin or lo>=end:continue
		active_first=minf(active_first,lo);active_last=maxf(active_last,minf(lo+4,end))
		if absolute>=lo and absolute<lo+4:active=true
	# EndBisha is an authored release transition even where a target checker
	# is the next real owner. EndAct opens only recovery, never confirmed success.
	for event: Dictionary in bundle.get("source_events",[]):
		var at: float=float(event.frame)
		if at<begin or at>=end:continue
		for call: Dictionary in event.get("calls",[]):
			if not call.get("supported",false) or not call.get("conditions",[]).is_empty():continue
			if call.get("method","")=="endBisha":
				active_first=minf(active_first,at);entry_transition=at
			elif call.get("method","")=="endAct":recovery_start=minf(recovery_start,at)
	var stage: String="prepare" if absolute<active_first else ("release" if active else ("combo" if absolute<active_last else "recover"))
	if entry_transition>=0 and absolute>=entry_transition and absolute<recovery_start and active_last<=entry_transition:stage="entry"
	if label.contains("_TF") and absolute<active_last:stage="impact"
	var motifs: Dictionary={"notify":{"I":"wait_phone_case","WI":"overhead_incoming_call","SI":"mute_all_99_badges","AIR_I":"falling_notification_board"},"wojak":{"U":"question_exclamation_child","SU":"slanted_rejection_punctuation","WU":"confirmed_exclamation_reply","I":"giant_question_pressure","WI":"target_split_parentheses","SI":"stacked_punctuation_climax","AIR_U":"actual_TF_reference_mark","AIR_I":"retreating_diagonal_question"}}
	var titles: Dictionary={"notify":{"I":"返信待ちの通知","WI":"着信の呼び出し","SI":"99+ 未読通知","AIR_I":"空中の通知ボード"},"wojak":{"U":"？！ の飛び道具","SU":"斜めの ／？！","WU":"命中したら !!!","I":"大きな ？！","WI":"挟み込む ( !! )","SI":"重なる !!! と ※","AIR_U":"着地したら ※","AIR_I":"退きながら ？！"}}
	var phase_begin: float=begin if stage=="prepare" else (active_last if stage=="recover" else active_first)
	var phase_end: float=active_first if stage=="prepare" else (end if stage=="recover" else maxf(active_last,active_first+1))
	var stage_words: Dictionary={"prepare":"構え", "release":"放つ", "combo":"連拍", "recover":"手を戻す", "entry":"踏み込む", "impact":"落下の一撃"}
	var title: String=str(stage_words.get(stage,stage))+" · "+str(titles[id].get(slot,""))
	if id=="notify" and slot=="SI" and label.contains("_CHK"):
		# The accepted CHK owns three different source HitVO windows. Its
		# authored final gap winds the bag before cbs, then releases the mute
		# outline. A whiff entry label can never use these windows.
		var local_regions: Array[Dictionary]=[]
		for region: Dictionary in bundle.get("regions",[]):
			if int(bundle.start)+int(region.start)>=int(metadata.frame) and int(bundle.start)+int(region.end_exclusive)<=int(metadata.source_end_frame)+1:local_regions.append(region)
		if local_regions.size()>=2:
			var final: Dictionary=local_regions.back();var previous: Dictionary=local_regions[local_regions.size()-2]
			var heavy_begin: float=float(bundle.start)+float(previous.end_exclusive)
			var final_begin: float=float(bundle.start)+float(final.start)
			var final_end: float=float(bundle.start)+float(final.end_exclusive)
			var first_end: float=float(bundle.start)+float(local_regions[0].end_exclusive)
			if absolute>=final_end:stage="recover";title="笑顔を戻してかばんを下げる";phase_begin=final_end;phase_end=end
			elif absolute>=final_begin:stage="impact";title="通知を一括ミュート";phase_begin=final_begin;phase_end=final_end
			elif absolute>=heavy_begin:stage="heavy";title="かばんを振りかぶる";phase_begin=heavy_begin;phase_end=final_begin
			elif absolute>=first_end:stage="combo";title="99+ 未読を連続処理";phase_begin=first_end;phase_end=heavy_begin
			else:stage="release";title="既読？ 最初の確認";phase_begin=begin;phase_end=first_end
	return {"ready":true,"id":id,"slot":slot,"binding_id":id+":"+command,"stage":stage,"title":title,"motif":motifs[id].get(slot,""),"progress":clampf((absolute-phase_begin)/maxf(1,phase_end-phase_begin),0,1),"source_label":label,"source_absolute_frame":absolute,"timing_source":"archived_source_frame","contains_character":false,"source_clock_mutated":false,"contact_confirmed":false}
