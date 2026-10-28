extends RefCounted
## Original v0.20 meme skills. Candidate timing is 60 Hz; pinned BVN data is untouched.
## Battle owns contacts, hit stop, map constraints and object-world advancement.

const SLOTS := ["skill1","skill2","skill3","super","super_down"]
const MOVES := {
	"rio":{"skill1":"rio_drag_charge","skill2":"rio_sword_lever","skill3":"rio_brace_counter","super":"rio_deadweight_crash","super_down":"rio_sword_runaway"},
	"cat":{"skill1":"cat_meme_sway","skill2":"cat_startled_pop","skill3":"cat_rolling_paw","super":"cat_comment_combo","super_down":"cat_chat_meltdown"},
	"worker":{"skill1":"worker_folder_set","skill2":"worker_case_upper","skill3":"worker_polite_counter","super":"worker_deadline_counter","super_down":"worker_overtime_reject"},
	"chicken":{"super_up":"chicken_air_contest","skill1":"chicken_bounce_pass","skill2":"chicken_rebound_pop","skill3":"chicken_dribble_sway","super":"chicken_alley_oop","super_down":"chicken_final_dunk"},
	"shark":{"skill1":"shark_shoe_dash","skill2":"shark_tripod_spinner","skill3":"shark_tripod_brace","super":"shark_three_step_rush","super_down":"shark_world_tour"}
}
const NAMES := {
	"rio_drag_charge":"ずるずる、よいしょ！","rio_sword_lever":"大剣てこ上げ","rio_brace_counter":"剣のうしろに隠れる","rio_deadweight_crash":"もう持てない！","rio_sword_runaway":"大剣、暴走します！",
	"cat_meme_sway":"Huh? ステップ","cat_startled_pop":"ぎゃっ！","cat_rolling_paw":"泣きながらゴロゴロ","cat_comment_combo":"コメント欄ねこパンチ","cat_chat_meltdown":"猫ミーム大炎上",
	"worker_folder_set":"ここに置いておきます","worker_case_upper":"カバン返し","worker_polite_counter":"お帰りください","worker_deadline_counter":"定時です","worker_overtime_reject":"残業、却下！",
	"chicken_bounce_pass":"ワンバウンド・パス","chicken_rebound_pop":"リバウンド！","chicken_dribble_sway":"二年半ステップ","chicken_air_contest":"空中ボール争奪","chicken_alley_oop":"ひとりアリウープ","chicken_final_dunk":"最優秀練習生・ラストダンク",
	"shark_shoe_dash":"トラララ・スタート","shark_tripod_spinner":"三脚スピナー","shark_tripod_brace":"三点支持！","shark_three_step_rush":"ワン、ツー、トララ！","shark_world_tour":"三足ワールドツアー"
}
# [startup, active, recovery, first power, hitType, reach in body-height units]
const SPECS := {
	"rio_drag_charge":[18,6,26,65,6,1.15],"rio_sword_lever":[16,8,32,80,6,.9],"rio_brace_counter":[6,18,24,90,6,.9],"rio_deadweight_crash":[22,8,36,150,6,1.35],"rio_sword_runaway":[24,6,44,50,6,1.0],
	"cat_meme_sway":[8,18,16,0,2,.6],"cat_startled_pop":[10,8,30,65,2,.5],"cat_rolling_paw":[18,10,28,70,2,.8],"cat_comment_combo":[14,6,30,30,2,.7],"cat_chat_meltdown":[18,6,38,40,2,.8],
	"worker_folder_set":[18,0,18,0,2,.6],"worker_case_upper":[14,8,30,65,2,.55],"worker_polite_counter":[6,20,26,80,2,.8],"worker_deadline_counter":[4,28,32,160,2,.8],"worker_overtime_reject":[22,6,40,40,2,.8],
	"chicken_air_contest":[14,12,30,145,2,1.0],"chicken_bounce_pass":[18,0,20,0,2,.7],"chicken_rebound_pop":[12,8,30,70,2,.7],"chicken_dribble_sway":[8,20,16,0,2,.7],"chicken_alley_oop":[16,6,34,30,2,.7],"chicken_final_dunk":[20,6,42,40,2,.8],
	"shark_shoe_dash":[10,18,24,0,2,.8],"shark_tripod_spinner":[14,10,30,75,2,.8],"shark_tripod_brace":[18,8,32,80,2,.9],"shark_three_step_rush":[14,6,32,40,2,.8],"shark_world_tour":[22,6,42,40,2,.9]
}
const FOLLOWUPS := {
	"rio_sword_runaway":[[12,65],[36,65],[64,65],[94,85]],
	"cat_comment_combo":[[12,30],[28,35],[48,55]],"cat_chat_meltdown":[[12,45],[30,45],[52,50],[74,50],[92,70]],
	"worker_polite_counter":[[12,45]],"rio_brace_counter":[[12,55]],"worker_deadline_counter":[[12,40],[28,40],[44,40]],"worker_overtime_reject":[[16,60],[44,60],[72,70],[100,90]],
	"chicken_alley_oop":[[20,40],[52,100]],"chicken_final_dunk":[[16,50],[40,55],[70,65],[106,130]],
	"shark_three_step_rush":[[16,50],[40,70]],"shark_world_tour":[[12,45],[32,45],[54,55],[74,55],[96,90]]
}

var actor: Node2D
var active := false
var move_id := ""
var slot := ""
var frame := 0.0
var phase_frame := 0.0
var stage := "startup"
var branch := ""
var confirmed := false
var contact := "miss"
var charge_tier := "weak"
var release_queued := false
var release_frame := -1.0
var action_spec: Array = []
var used_hits: Dictionary = {}
var serial := 0
var facing := 1
var target_ref: WeakRef
var current_target: WeakRef
var last_visual: Dictionary = {}
var hint := ""
var hint_time := 0.0
var ball: Dictionary = {}
var folder: Dictionary = {}
var object_serial := 0
var last_held_u := false
var confirmed_origin := Vector2.ZERO
var choreography_events: Dictionary = {}

func _init(owner: Node2D = null) -> void:
	actor=owner

func has_slot(command: String) -> bool:
	return MOVES.has(actor.fighter_id) and MOVES[actor.fighter_id].has(command)

func can_cancel(command: String) -> bool:
	return active and confirmed and slot in ["skill1","skill2","skill3"] and command in ["super","super_down"] and phase_frame>=6 and phase_frame<=20

func ball_in_hand() -> bool:
	return ball.is_empty()

func begin(command: String) -> bool:
	if not has_slot(command): return false
	if actor.hp<=0 or not actor.grounded or actor.state in ["hurt","launch","juggle","slam","down","getup","escape","burst","guard_stun","throw_hold","ko"]:
		actor.reject_reason="今は動けません"; return false
	if actor.fighter_id=="chicken" and command=="skill1" and not ball_in_hand():
		recall_ball(); hint="ボール回収中"; hint_time=.5; actor.clear_buffer(); return true
	if active and not can_cancel(command): actor.reject_reason="技の後隙です"; return false
	if not active and not actor.command_enabled(command): actor.reject_reason="接続できない"; return false
	if actor.fighter_id=="chicken" and command in ["super","super_up","super_down"] and not ball_in_hand():
		hint="ボール回収中"; hint_time=1.1; actor.reject_reason=hint; return false
	if actor.fighter_id=="worker" and command=="skill1" and not folder.is_empty():
		hint="設置済み"; hint_time=.8; actor.reject_reason=hint; return false
	var cost: float=300.0 if command=="super_down" else (100.0 if command in ["super","super_up"] else 0.0)
	if actor.hype<cost: actor.reject_reason="気が足りない"; return false
	actor.hype-=cost
	move_id=str(MOVES[actor.fighter_id][command]); slot=command; action_spec=SPECS[move_id].duplicate()
	if move_id=="chicken_rebound_pop" and not ball_in_hand(): action_spec=[14,6,28,45,2,.5]
	active=true; frame=0; phase_frame=0; stage="charge" if move_id=="rio_drag_charge" else "startup"
	branch=""; confirmed=false; contact="miss"; charge_tier="weak"; release_queued=false; release_frame=-1.0; used_hits.clear(); target_ref=null; choreography_events.clear(); confirmed_origin=actor.position
	actor.action_serial+=1; serial=actor.action_serial; facing=actor.facing
	actor.state="attack"; actor.state_time=0; actor.action=slot; actor.action_time=0
	actor.action_data={"authored":true,"semantic_move_id":move_id,"kind":"super" if cost>0 else "special","startup":float(action_spec[0])/60,"active":float(action_spec[1])/60,"recovery":float(action_spec[2])/60,"damage":int(action_spec[3]),"feedback":"super" if cost>0 else "heavy","label":NAMES[move_id]}
	actor.guarding=false; actor.crouching=false; actor.attack_hit=false; actor.attack_contact=false; actor.armor_used=false
	actor.contact_result=""; actor.route_closed=false; actor.hit_targets.clear(); actor.clear_buffer(); actor._clear_bvn_defense()
	actor.velocity=Vector2.ZERO; actor.bvn_damping=Vector2(0,.5); actor.bvn_apply_gravity=true
	actor.invulnerable=0; actor.source_allow_be_hit=true; actor.source_steel=false; actor.source_super_steel=false; actor.source_cross=false; actor.source_hurt_action=""
	actor.source_doing_action=false; actor.source_playing=false; actor.source_doing_air_action=false; actor.source_is_jumping=false
	actor.source_permissions.clear(); actor.source_snapshot={}; actor.source_hit_target.clear(); actor.source_hit_confirmations.clear()
	actor.source_generation+=1; actor.action_started.emit(slot)
	return true

func input(intent: Dictionary) -> void:
	last_held_u=bool(intent.get("held_U",intent.get("held_u",false)))
	if not active: return
	if actor.fighter_id=="chicken" and not ball_in_hand() and bool(intent.get("fresh_U",false)) and stage!="stance": recall_ball()
	if move_id=="rio_drag_charge" and stage=="charge" and not last_held_u and not release_queued:
		release_queued=true; release_frame=frame
	if stage!="stance" or not branch.is_empty(): return
	var pick: String=""
	if bool(intent.get("fresh_J",false)): pick="J"
	elif bool(intent.get("fresh_K",false)): pick="K"
	elif bool(intent.get("fresh_U",false)): pick="U"
	if pick.is_empty(): return
	if move_id=="cat_meme_sway":
		if pick=="J": _branch("low_pounce",[10,6,22,50,2,.7])
		elif pick=="K": _branch("jump_claw",[14,8,18,55,2,.75]); _hop(-270.0)
		else: _branch("cat_grab",[8,6,30,70,11,.45])
	elif move_id=="chicken_dribble_sway":
		if pick=="J": _branch("shoulder",[14,8,26,65,2,.8])
		elif pick=="K": _branch("jump_shoulder",[18,8,24,70,2,.8]); _hop(-290.0)
		else: _branch("fake_shot",[0,0,16,0,2,.5]); stage="recovery"
	elif move_id=="shark_shoe_dash":
		if pick=="J": _branch("slide",[10,8,28,65,2,.95])
		elif pick=="K": _branch("spin",[14,8,26,70,2,.85]); _hop(-260.0)
		else: _branch("brake",[0,0,18,0,2,.5]); stage="recovery"
	actor.clear_buffer()

func _branch(name: String, spec: Array) -> void:
	branch=name; action_spec=spec; phase_frame=0; stage="startup"; used_hits.clear()
	actor.action_data["startup"]=float(spec[0])/60; actor.action_data["active"]=float(spec[1])/60; actor.action_data["recovery"]=float(spec[2])/60

func _hop(impulse: float) -> void:
	actor.velocity.y=impulse; actor.grounded=false; actor.bvn_motion.reset(false); actor.bvn_damping.y=.5

func step(delta: float) -> void:
	hint_time=maxf(0,hint_time-delta)
	if not active: return
	if actor.hp<=0 or actor.state!="attack" or actor.action!=slot:
		interrupt(); return
	var amount: float=maxf(0,delta)*60.0
	frame+=amount; phase_frame+=amount; actor.action_time=frame/60.0
	actor.source_steel=false
	if move_id=="rio_drag_charge" and stage=="charge":
		charge_tier="strong" if frame>=42 and (not release_queued or release_frame>=42) else "weak"
		actor.source_steel=frame>=18 and frame<30 and not actor.armor_used
		actor.velocity.x=-facing*25.0 if frame<18 else 0.0
		if (release_queued and frame>=18) or frame>=48:
			action_spec=[0,8 if charge_tier=="strong" else 6,34 if charge_tier=="strong" else 26,110 if charge_tier=="strong" else 65,6,1.55 if charge_tier=="strong" else 1.15]
			stage="active"; phase_frame=0; actor.velocity.x=facing*55.0
		return
	if stage=="confirmed":
		var victim: Node2D=target_ref.get_ref() if target_ref else null
		if not is_instance_valid(victim) or victim.hp<=0 or victim.state in ["escape","burst","ko","idle","walk","guard"]:
			_restore_directed_motion()
			stage="recovery"; phase_frame=float(action_spec[0])+float(action_spec[1]); contact="interrupted"
		elif phase_frame>=_confirmed_duration():
			_restore_directed_motion()
			actor.velocity.x=0
			if actor.grounded or phase_frame>=_confirmed_duration()+60: finish()
		else: _confirmed_motion(victim)
		return
	var start: float=float(action_spec[0]); var attack: float=float(action_spec[1]); var recovery: float=float(action_spec[2])
	var is_stance: bool=move_id in ["cat_meme_sway","chicken_dribble_sway","shark_shoe_dash"] and branch.is_empty()
	var is_counter: bool=move_id in ["rio_brace_counter","worker_polite_counter","worker_deadline_counter"]
	stage="startup" if phase_frame<start else (("stance" if is_stance else ("counter" if is_counter else "active")) if phase_frame<start+attack else "recovery")
	actor.velocity.x=0.0
	if move_id=="chicken_air_contest" and phase_frame>=12 and not choreography_events.has("contest_hop"):
		choreography_events["contest_hop"]=true; _hop(-420.0)
	if is_stance:
		if move_id=="shark_shoe_dash" and phase_frame<start+attack: actor.velocity.x=facing*430.0
		elif move_id in ["cat_meme_sway","chicken_dribble_sway"] and phase_frame<start: actor.velocity.x=-facing*235.0
	if branch in ["low_pounce","shoulder","slide","jump_shoulder","spin","jump_claw"] and phase_frame<start+attack:
		actor.velocity.x=facing*(310.0 if branch in ["slide","shoulder"] else 220.0)
	if move_id=="cat_rolling_paw" and phase_frame>=8 and phase_frame<start+attack: actor.velocity.x=facing*370.0
	if move_id=="shark_tripod_brace":
		actor.source_steel=phase_frame>=8 and phase_frame<18 and not actor.armor_used
		if stage=="active": actor.velocity.x=facing*240.0
	if move_id=="worker_folder_set" and phase_frame>=start and not used_hits.has("placed"):
		object_serial+=1; folder={"position":actor.position+Vector2(facing*actor.body_width*.9,0),"age":0.0,"serial":object_serial,"facing":facing,"state":"arming"}; used_hits["placed"]=true
	if move_id=="chicken_bounce_pass" and phase_frame>=start and not used_hits.has("launched"):
		_launch_ball(); used_hits["launched"]=true
	if move_id=="chicken_rebound_pop" and phase_frame>=start and not used_hits.has("launched"):
		if ball_in_hand(): _launch_ball(true)
		used_hits["launched"]=true
	if phase_frame>=start+attack+recovery:
		# Hop branches retain their actual landing recovery; they cannot end mid-air.
		if (branch in ["jump_claw","jump_shoulder","spin"] or move_id=="chicken_air_contest") and not actor.grounded:
			stage="recovery"; actor.velocity.x=0
		else: finish()

func _restore_directed_motion() -> void:
	actor.bvn_apply_gravity=true; actor.bvn_damping.y=.5

func _enter_confirmed(victim: Node2D, result: String) -> void:
	confirmed=true; contact=result; stage="confirmed"; phase_frame=0; target_ref=weakref(victim)
	confirmed_origin=Vector2(actor.position.x,actor.stage_floor_y); choreography_events.clear()
	actor.source_steel=false

func _event_hop(key: String, at_frame: float, impulse: float) -> void:
	if phase_frame>=at_frame and not choreography_events.has(key):
		choreography_events[key]=true; _hop(impulse)

func _confirmed_motion(victim: Node2D) -> void:
	# Actual movement uses BVN velocity/damping. No target transform, crossing,
	# global catch box, or frozen hurt timers is applied by the director.
	actor.facing=facing
	var separation: float=maxf(82,actor.body_height*.92)
	if actor.fighter_id=="shark": separation=maxf(104,actor.body_height*1.12)
	elif actor.fighter_id=="rio": separation=maxf(96,actor.body_height)
	var step_offset: float=0.0
	if move_id=="rio_sword_runaway": step_offset=sin(phase_frame*TAU/48)*18
	elif move_id=="shark_world_tour": step_offset=sin(phase_frame*TAU/42)*18
	var minimum_gap: float=maxf(72,(actor.body_width+victim.body_width)*.8)
	var desired_gap: float=maxf(minimum_gap,separation+step_offset)
	var goal_x: float=victim.position.x-facing*desired_gap
	goal_x=clampf(goal_x,confirmed_origin.x-260,confirmed_origin.x+260)
	actor.velocity.x=clampf((goal_x-actor.position.x)*7,-300,300)
	if move_id=="cat_comment_combo": _event_hop("paw_hop",2,-240)
	if move_id=="shark_world_tour":
		_event_hop("shoe_hop_one",28,-250); _event_hop("shoe_hop_two",62,-250)
	var airborne_director: bool=move_id in ["chicken_alley_oop","chicken_final_dunk","cat_chat_meltdown"]
	if not airborne_director: return
	var takeoff: float=20 if move_id=="chicken_final_dunk" else 2
	var impulse: float=-700 if move_id=="chicken_final_dunk" else (-550 if move_id=="chicken_alley_oop" else -450)
	_event_hop("confirm_takeoff",takeoff,impulse)
	var events: Array=FOLLOWUPS[move_id]
	var drop_frame: float=float(events[-1][0])
	var hold_frame: float=40 if move_id=="chicken_final_dunk" else 18
	if phase_frame>=drop_frame:
		if not choreography_events.has("confirm_drop"):
			choreography_events["confirm_drop"]=true; _restore_directed_motion()
			actor.velocity.y=420; actor.grounded=false; actor.bvn_motion.reset(false)
	elif phase_frame>=hold_frame:
		# A bounded airborne follow keeps the limb and real victim at finite reach.
		# The victim remains freely escapable; all hit/hurt/velocity is Battle-owned.
		actor.bvn_apply_gravity=false; actor.bvn_damping.y=0
		var goal_y: float=clampf(victim.position.y-24,actor.stage_floor_y-230,actor.stage_floor_y-35)
		actor.velocity.y=clampf((goal_y-actor.position.y)*8,-240,240)
		actor.grounded=false

func _follow_area() -> Rect2:
	# Finite actor-relative reach. Choreography must put the actor in range;
	# the hit box is never expanded to include the victim's body box.
	var reach: float=1.55 if actor.fighter_id in ["cat","worker"] else 1.8
	return _area(reach)

func _choreography_hit(value: Dictionary, follow_index: int=-1) -> Dictionary:
	var exact: Dictionary=value["source_hit_vo"]
	var events: Array=FOLLOWUPS.get(move_id,[])
	var final_hit: bool=follow_index>=0 and follow_index==events.size()-1
	if final_hit and move_id in ["chicken_alley_oop","chicken_final_dunk","cat_chat_meltdown"]:
		value["reaction"]="slam"; exact["hity"]=15.0; exact["hurtType"]=1; exact["isApplyG"]=true
	elif (follow_index<0 and move_id in ["chicken_alley_oop","cat_chat_meltdown"]) or (move_id=="chicken_final_dunk" and follow_index==0):
		value["reaction"]="launch"; exact["hity"]=-3.0 if move_id=="cat_chat_meltdown" else -4.0
		exact["hurtType"]=0; exact["isApplyG"]=false
	elif (not final_hit and move_id in ["chicken_alley_oop","cat_chat_meltdown"]) or (move_id=="chicken_final_dunk" and follow_index>=1 and not final_hit):
		# Source subtracts 3 from an airborne hity: 3 means a true zero impulse.
		exact["hity"]=3.0; exact["hurtType"]=0; exact["isApplyG"]=false
		if move_id=="chicken_final_dunk": exact["hurtTime"]=700
	if not final_hit:
		if move_id=="worker_overtime_reject": exact["hitx"]=4.0 if follow_index==0 else 2.0
		elif move_id in ["shark_world_tour","shark_three_step_rush","rio_sword_runaway"]: exact["hitx"]=1.4
	value["knockback"]=float(exact["hitx"])*48; value["stun"]=float(exact["hurtTime"])*.001
	value["authored_follow_index"]=follow_index
	return value

func _confirmed_duration() -> float:
	var events: Array=FOLLOWUPS.get(move_id,[])
	return float(events[-1][0])+18 if not events.is_empty() else 30.0

func finish() -> void:
	last_visual=visual_state(); last_visual["ended"]=true
	active=false; _restore_directed_motion(); actor.source_steel=false; actor.velocity.x=0; actor.route_closed=true; actor.clear_buffer()
	if actor.source_runtime_enabled: actor.source_idle()
	else: actor.state="idle" if actor.grounded else "jump"; actor.action=""; actor.action_data.clear()

func interrupt() -> void:
	if not active:
		if not ball.is_empty(): recall_ball()
		return
	if move_id=="worker_folder_set" and frame<36: folder.clear()
	if not ball.is_empty(): recall_ball()
	active=false; _restore_directed_motion(); actor.source_steel=false; confirmed=false; target_ref=null; used_hits.clear(); last_visual.clear()

func reset() -> void:
	active=false; move_id=""; slot=""; frame=0; phase_frame=0; stage="startup"; branch=""; confirmed=false
	contact="miss"; used_hits.clear(); choreography_events.clear(); confirmed_origin=Vector2.ZERO; target_ref=null; current_target=null; ball.clear(); folder.clear(); last_visual.clear(); hint=""; hint_time=0

func world_step(delta: float, target: Node2D) -> void:
	if is_instance_valid(target): current_target=weakref(target)
	hint_time=maxf(0,hint_time-delta) if not active else hint_time
	if actor.hp<=0: reset(); return
	if not folder.is_empty():
		folder["age"]=float(folder["age"])+delta*60.0
		folder["state"]="armed" if float(folder["age"])>=24 else "arming"
		if float(folder["age"])>=150: folder.clear()
	if ball.is_empty(): return
	ball["age"]=float(ball["age"])+delta*60.0
	var point: Vector2=ball["position"]
	if ball["state"]=="outbound":
		var motion: Vector2=ball["velocity"]; motion.y+=1800.0*delta; point+=motion*delta
		if point.y>=actor.stage_floor_y-18 and motion.y>0:
			point.y=actor.stage_floor_y-18
			if not bool(ball["bounced"]): motion.y=-560.0; ball["bounced"]=true
			else: recall_ball()
		ball["velocity"]=motion; ball["position"]=point
		if float(ball["age"])>=(22 if bool(ball.get("rebound",false)) else 60) or absf(point.x-float(ball["origin_x"]))>=maxf(270,actor.body_width*3.0): recall_ball()
	else:
		var destination: Vector2=_hand_position(); var difference: Vector2=destination-point
		if difference.length()<=maxf(20,800*delta): ball.clear(); return
		ball["position"]=point+difference.normalized()*800.0*delta

func _hand_position() -> Vector2:
	return actor.position+Vector2(actor.facing*actor.body_width*.35,-actor.body_height*.6)

func _launch_ball(rebound: bool=false) -> void:
	if not ball.is_empty(): return
	object_serial+=1
	ball={"position":_hand_position(),"velocity":Vector2(facing*150,-500) if rebound else Vector2(facing*620,360),"origin_x":actor.position.x,"age":0.0,"state":"outbound","serial":object_serial,"facing":facing,"bounced":false,"hit":false,"rebound":rebound,"semantic_move_id":"chicken_rebound_pop" if rebound else "chicken_bounce_pass","power":70 if rebound else 50}

func recall_ball() -> void:
	if not ball.is_empty(): ball["state"]="returning"; ball["hit"]=true

func _area(reach: float, upper: bool=false, circular: bool=false) -> Rect2:
	var height: float=maxf(100,actor.body_height)
	var width: float=maxf(50,actor.body_width*.5)
	if circular: return Rect2(actor.position+Vector2(-height*.6,-height*.9),Vector2(height*1.2,height*.8))
	if upper:
		return Rect2(actor.position+Vector2(-width*.4 if facing>0 else -height*reach,-height*1.6),Vector2(height*reach+width*.4,height*.9))
	return Rect2(actor.position+Vector2(width*.2 if facing>0 else -height*reach-width*.2,-height*.82),Vector2(height*reach,height*.72))

func _descriptor(key: String, area: Rect2, power: int, hit_type: int, reaction: String="hurt", prop_kind: String="") -> Dictionary:
	var kind: String="throw" if hit_type==11 else ("super" if slot in ["super","super_up","super_down"] and prop_kind.is_empty() else "special")
	var exact: Dictionary={"id":key,"power":power,"powerRate":1.0,"hitx":7.0 if reaction=="down" else (0.0 if stage=="confirmed" or move_id in FOLLOWUPS else 4.0),"hity":6.0 if reaction=="down" else 0.0,"hurtTime":500 if move_id in FOLLOWUPS else 300,"hurtType":1 if reaction=="down" else 0,"hitType":hit_type,"isBreakDef":hit_type==11,"isReal":false,"isApplyG":true,"checkDirect":true}
	return {"authored_hit":true,"authored_prop":prop_kind,"area":area,"source_hit_vo":exact,"source_name":key,"hit_id":key,"serial":serial,"semantic_move_id":move_id,"move":slot,"kind":kind,"damage":power,"knockback":float(exact["hitx"])*48.0,"stun":float(exact["hurtTime"])*.001,"reaction":reaction,"owner_x":actor.position.x,"owner_facing":facing,"hit_owner_facing":facing,"has_owner":true,"feedback":"super" if kind=="super" else "heavy","authored_stage":stage}

func hits() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if actor.hp<=0: return result
	if not ball.is_empty() and ball["state"]=="outbound" and not bool(ball["hit"]):
		var point: Vector2=ball["position"]
		var saved_move: String=move_id; var saved_slot: String=slot
		move_id=str(ball["semantic_move_id"]); slot="skill2" if bool(ball.get("rebound",false)) else "skill1"
		var value: Dictionary=_descriptor("ball_"+str(ball["serial"]),Rect2(point-Vector2(18,18),Vector2(36,36)),int(ball["power"]),2,"hurt","basketball")
		value["serial"]=int(ball["serial"]); value["owner_facing"]=int(ball["facing"]); value["hit_owner_facing"]=int(ball["facing"])
		result.append(value); move_id=saved_move; slot=saved_slot
	if not folder.is_empty() and folder["state"]=="armed":
		var victim: Node2D=current_target.get_ref() if current_target else null
		if is_instance_valid(victim) and victim.grounded and victim.state not in ["down","getup","slam","ko","escape","burst"]:
			var point: Vector2=folder["position"]
			var saved_move: String=move_id; var saved_slot: String=slot
			move_id="worker_folder_set"; slot="skill1"
			var value: Dictionary=_descriptor("folder_"+str(folder["serial"]),Rect2(point+Vector2(-34,-32),Vector2(68,32)),45,2,"down","folder")
			value["serial"]=int(folder["serial"]); result.append(value); move_id=saved_move; slot=saved_slot
	if not active: return result
	if stage=="confirmed":
		var events: Array=FOLLOWUPS.get(move_id,[])
		for i in range(events.size()):
			var event: Array=events[i]; var key: String="follow_"+str(serial)+"_"+str(i)
			if phase_frame>=float(event[0]) and phase_frame<float(event[0])+6 and not used_hits.has(key):
				var victim: Node2D=target_ref.get_ref() if target_ref else null
				if not is_instance_valid(victim): continue
				var final_hit: bool=i==events.size()-1
				result.append(_choreography_hit(_descriptor(key,_follow_area(),int(event[1]),6 if actor.fighter_id=="rio" else 2,"down" if final_hit else "hurt"),i))
		return result
	if stage!="active" or int(action_spec[3])<=0: return result
	if move_id=="chicken_rebound_pop" and int(action_spec[3])==70: return result # actual short-arc ball owns this contact
	var key: String="strike_"+str(serial)+"_"+branch
	if used_hits.has(key): return result
	var upper: bool=move_id in ["rio_sword_lever","cat_startled_pop","worker_case_upper","chicken_rebound_pop","chicken_air_contest"]
	var zone: Rect2=_area(float(action_spec[5]),upper,move_id=="shark_tripod_spinner")
	if branch=="cat_grab":
		var victim: Node2D=current_target.get_ref() if current_target else null
		if not is_instance_valid(victim) or not victim.grounded or victim.state in ["down","getup","slam","ko","escape","burst"]: return result
	var reaction: String="down" if move_id in ["cat_rolling_paw","rio_deadweight_crash"] or branch=="cat_grab" else "hurt"
	result.append(_choreography_hit(_descriptor(key,zone,int(action_spec[3]),int(action_spec[4]),reaction)))
	return result

func notify_contact(hit: Dictionary, answer: Dictionary, target: Node2D) -> void:
	if not bool(answer.get("hit",false)): return
	var prop_kind: String=str(hit.get("authored_prop",""))
	if prop_kind=="basketball":
		if not ball.is_empty() and int(hit.get("serial",-1))==int(ball["serial"]): ball["hit"]=true; recall_ball()
		return
	if prop_kind=="folder": folder.clear(); return
	if not active or int(hit.get("serial",-1))!=serial: return
	used_hits[str(hit.get("source_name",hit.get("hit_id","")))]=true
	actor.attack_contact=true; actor.attack_hit=not bool(answer.get("blocked",false)); actor.contact_result="guard" if not actor.attack_hit else "hit"
	contact=actor.contact_result
	if bool(answer.get("blocked",false)) or bool(answer.get("armor",false)): return
	if stage=="confirmed": return
	if FOLLOWUPS.has(move_id):
		_enter_confirmed(target,"hit")
	else: confirmed=true

func receive_contact(source: Dictionary, attacker: Node2D) -> Dictionary:
	if not active or stage!="counter" or not is_instance_valid(attacker): return {"handled":false}
	# O's energy explosion is an ownerless area, never a close body strike.
	if not bool(source.get("has_owner",true)) or str(source.get("source_type",""))=="energy_explode": return {"handled":false}
	if source.get("kind","") in ["throw","super"] or not str(source.get("authored_prop","")).is_empty(): return {"handled":false}
	var exact: Dictionary=source.get("source_hit_vo",{})
	if int(exact.get("hitType",1))==11 or str(source.get("source_type","")) in ["bullet","attacker","independent","source_object"] or bool(source.get("independent",false)) or bool(source.get("projectile",false)): return {"handled":false}
	if (attacker.position.x-actor.position.x)*facing<0 or absf(attacker.position.x-actor.position.x)>actor.body_height*2.0: return {"handled":false}
	_enter_confirmed(attacker,"counter")
	var first_power: int=40 if move_id=="worker_deadline_counter" else (35 if move_id=="rio_brace_counter" else 35)
	var key: String="counter_"+str(serial); used_hits[key]=true
	var strike: Dictionary=_descriptor(key,attacker.body_box(),first_power,6 if actor.fighter_id=="rio" else 2)
	strike["counter_confirmed"]=true
	return {"handled":true,"counter":true,"hit":strike,"semantic_move_id":move_id}

func visual_state() -> Dictionary:
	var duration: float=1.0; var clock: float=phase_frame
	if stage=="charge": duration=48.0; clock=frame
	elif stage=="confirmed": duration=_confirmed_duration()
	elif not action_spec.is_empty():
		if stage=="startup": duration=maxf(1,float(action_spec[0]))
		elif stage in ["active","counter","stance"]: duration=maxf(1,float(action_spec[1])); clock=phase_frame-float(action_spec[0])
		else: duration=maxf(1,float(action_spec[2])); clock=phase_frame-float(action_spec[0])-float(action_spec[1])
	var face: String="huh" if move_id=="cat_meme_sway" else ("cry" if move_id in ["cat_rolling_paw","cat_chat_meltdown"] else ("startled" if move_id=="cat_startled_pop" else "happy"))
	if stage=="confirmed" and actor.fighter_id=="cat": face=["happy","huh","cry","happy"][mini(3,int(phase_frame/20))]
	if not active: face="happy"
	var appearance: Dictionary={"ball_in_hand":ball_in_hand(),"cat_face":face}
	return {"ready":active,"active":active,"semantic_move_id":move_id,"slot":slot,"stage":stage,"phase":clampf(clock/duration,0,1),"progress":clampf(clock/duration,0,1),"frame":frame,"confirmed_frame":phase_frame if stage=="confirmed" else -1,"confirmed_origin":confirmed_origin,"target_position":target_ref.get_ref().position if target_ref and is_instance_valid(target_ref.get_ref()) else actor.position,"branch":branch,"charge_tier":charge_tier,"confirmed":confirmed,"contact":contact,"appearance":appearance,"ball_in_hand":ball_in_hand(),"ball_position":ball.get("position",_hand_position()),"ball_state":ball.get("state","held"),"trap_state":folder.get("state","none"),"owner_index":actor.player_index,"facing":facing,"hint":hint if hint_time>0 else "","name_ja":NAMES.get(move_id,"")}

func prop_state() -> Array[Dictionary]:
	var values: Array[Dictionary]=[]
	if not ball.is_empty():
		values.append({"kind":"basketball","position":ball["position"],"state":ball["state"],"progress":clampf(float(ball["age"])/60,0,1),"age":ball["age"],"facing":ball["facing"],"owner_index":actor.player_index,"serial":ball["serial"],"bounced":ball["bounced"],"damaging":ball["state"]=="outbound" and not bool(ball["hit"]),"semantic_move_id":ball["semantic_move_id"]})
	if not folder.is_empty():
		values.append({"kind":"folder","position":folder["position"],"state":folder["state"],"progress":clampf(float(folder["age"])/24,0,1),"age":folder["age"],"facing":folder["facing"],"owner_index":actor.player_index,"serial":folder["serial"],"damaging":folder["state"]=="armed","semantic_move_id":"worker_folder_set"})
	return values
