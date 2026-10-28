extends RefCounted
## Compact animated motion materials. Reads actual stages/contacts/props only.
## No body copies, colored panels, fake balls, damage, RNG or game-clock writes.
const Pixel = preload("res://game/pixel_fighter.gd")
const FONT = preload("res://assets/fonts/NotoSansJP.ttf")
const INK = Color("173249")
const WHITE = Color("fff9ed")
const STEEL = Color("3fc4fa")
const ICE = Color("ccf4ff")
const DUST = Color("dfc7a0")
const PINK = Color("ff6bb7")
const PAPER = Color("fff4dd")
const RED = Color("f35767")
const ORANGE = Color("f78220")
const WATER = Color("19c3c8")
const DURATIONS = {"rio_sword_runaway":112.0,"cat_comment_combo":66.0,"cat_chat_meltdown":110.0,"worker_deadline_counter":62.0,"worker_overtime_reject":118.0,"chicken_alley_oop":70.0,"chicken_final_dunk":124.0,"shark_three_step_rush":58.0,"shark_world_tour":114.0}
const PROFILES = {
	"rio_drag_charge":[1,"blade-tip sparks and horizontal steel slice"],"rio_sword_lever":[1,"upward actual-blade trail and fulcrum dust"],"rio_brace_counter":[1,"sword-edge glint and reverse counter slice"],"rio_deadweight_crash":[2,"blade descent and segmented ground split"],"rio_sword_runaway":[3,"circling blade trails with staggered heavy landing"],
	"cat_meme_sway":[1,"huh punctuation and direction-changing paw cuts"],"cat_startled_pop":[1,"arched fur ticks and brief startled spark"],"cat_rolling_paw":[1,"rolling tear droplets and soft water streak"],"cat_comment_combo":[2,"alternating three tapered claw cuts"],"cat_chat_meltdown":[3,"changing claw directions and brief double-paw pressure"],
	"worker_folder_set":[1,"fluttering physical paperwork and settling dust"],"worker_case_upper":[1,"bag-lid flick and opening paper flight"],"worker_polite_counter":[1,"case rim glint and forward paper gust"],"worker_deadline_counter":[2,"clock hand glint and compact red contact stamps"],"worker_overtime_reject":[3,"paper escort and perspective door trim snap"],
	"chicken_bounce_pass":[1,"one actual basketball with narrow seam wake"],"chicken_rebound_pop":[1,"short rising single-ball streak"],"chicken_dribble_sway":[1,"court-foot sweeps and dribble direction change"],"chicken_alley_oop":[2,"lift seam trail and compressed dunk ripple"],"chicken_final_dunk":[3,"staggered dance strokes and sharply compressed dunk rings"],"chicken_air_contest":[2,"one-ball short upward contest streak"],
	"shark_shoe_dash":[1,"three foot wakes and broken braking water curl"],"shark_tripod_spinner":[1,"near-foot segmented circular water stroke"],"shark_tripod_brace":[1,"three sole glints and compact shoulder splash"],"shark_three_step_rush":[2,"separate shoe-driven water cuts"],"shark_world_tour":[3,"multi-angle shoe droplets and brief three-sole floor ripple"]
}

static func profile(move: String) -> Dictionary:
	if not PROFILES.has(move):return {"ready":false}
	var rank: int=int(PROFILES[move][0])
	return {"ready":true,"rank":rank,"startup_span_h":[.65,1.0,1.2][rank-1],"release_span_h":[1.5,2.4,3.4][rank-1],"shape":PROFILES[move][1],"layer":"back","ordinary_attack":false,"miss_has_release":true,"confirmed_only_finisher":true,"render_style":"compact_motion_material","solid_panels":false,"weapon_motion_following":true,"blend_hint":"additive_on_isolated_release_canvas","contrast":"narrow white core / colored falloff / fine ink rim"}

static func coverage() -> Dictionary:
	return {"moves":PROFILES.keys(),"count":PROFILES.size(),"character_copy":false,"fake_ball_entities":false,"ordinary_j_modified":false,"shapes_are_directional":true,"solid_panels":false,"render_style":"compact_motion_material"}

static func _alpha(color: Color, amount: float) -> Color:
	return Color(color,clampf(amount,0.0,1.0)*color.a)

static func _trace(c: CanvasItem, points: PackedVector2Array, color: Color, h: float, strength: float, width: float=.035) -> void:
	if strength<=.02 or points.size()<2:return
	var glow:=maxf(2.2,h*width*3.4)
	c.draw_polyline(points,_alpha(color,strength*.11),glow,false)
	c.draw_polyline(points,_alpha(INK,strength*.52),maxf(2.0,h*width*1.35),false)
	c.draw_polyline(points,_alpha(color,strength*.86),maxf(1.7,h*width*1.12),false)
	for i in range(points.size()-1):
		var t:=float(i+1)/float(points.size())
		var local_width:=maxf(.60,h*width*(.18+.82*sin(t*PI))*.53)
		c.draw_line(points[i],points[i+1],_alpha(WHITE,strength*(.30+.70*sin(t*PI))),local_width,false)

static func _curve(c: CanvasItem, origin: Vector2, end: Vector2, bend: float, color: Color, h: float, d: float, strength: float, width: float=.04, start: float=0.0, stop: float=1.0) -> void:
	var points:=PackedVector2Array();var axis:=end-origin
	var normal:=Vector2(-axis.y,axis.x).normalized()
	for i in range(12):
		var t:=lerpf(start,stop,float(i)/11.0)
		points.append(origin.lerp(end,t)+normal*sin(t*PI)*bend*d)
	_trace(c,points,color,h,strength,width)

static func _arc(c: CanvasItem, at: Vector2, radius: float, start: float, stop: float, ratio: float, color: Color, h: float, d: float, strength: float, width: float=.04) -> void:
	var points:=PackedVector2Array()
	for i in range(15):
		var angle:=lerpf(start,stop,float(i)/14.0)
		points.append(at+Vector2(cos(angle)*radius*d,sin(angle)*radius*ratio))
	_trace(c,points,color,h,strength,width)

static func _spark(c: CanvasItem, at: Vector2, length: float, color: Color, h: float, d: float, p: float, amount: int=4, strength: float=1.0) -> void:
	for i in range(amount):
		var direction:=Vector2(cos(-1.05+i*.56)*d,sin(-1.05+i*.56))
		var offset:=direction*length*(.20+p*.85)+Vector2(0,p*p*h*.08)
		var tail:=length*(.19+.08*(i%2))*(1.0-p*.72)
		_trace(c,PackedVector2Array([at+offset-direction*tail,at+offset]),color,h,strength*(1.0-p),.025)

static func _ellipse(c: CanvasItem, at: Vector2, diameter: float, color: Color, h: float, d: float, p: float, strength: float=1.0, rings: int=2) -> void:
	for i in range(rings):
		var radius:=diameter*(.22+p*.30+i*.13)
		var vertical: float=.12+float(i)*.018
		for segment in range(3):
			var start:=segment*TAU/3.0+.14+p*.26+i*.10
			_arc(c,at+Vector2(0,-1),radius,start,start+1.38,vertical,color,h,d,strength*(1.0-p)*(1.0-i*.20),.035-i*.004)

static func _droplets(c: CanvasItem, at: Vector2, h: float, d: float, p: float, strength: float, count: int=5) -> void:
	for i in range(count):
		var t:=fposmod(p+float(i)*.13,1.0)
		var origin:=at+Vector2(-d*h*(.10+i*.13+t*.30),-h*(.08+sin(t*PI)*(.20+i*.035)))
		var length:=h*(.052+.012*(i%2))
		var points:=PackedVector2Array([origin+Vector2(0,-length),origin+Vector2(d*length*.40,0),origin+Vector2(0,length*.58),origin+Vector2(-d*length*.35,0)])
		c.draw_colored_polygon(points,_alpha(WATER,strength*(1.0-t)*.82))
		c.draw_line(origin+Vector2(0,-length*.30),origin+Vector2(0,length*.20),_alpha(WHITE,strength*(1.0-t)),maxf(1.0,h*.012),false)

static func _paper(c: CanvasItem, at: Vector2, size: float, angle: float, d: float, strength: float) -> void:
	var points:=PackedVector2Array()
	for q in [Vector2(-.5,-.34),Vector2(.5,-.34),Vector2(.5,.34),Vector2(-.5,.34)]:
		var v: Vector2=(q*size).rotated(angle);points.append(at+Vector2(v.x*d,v.y))
	c.draw_colored_polygon(points,_alpha(PAPER,strength*.90))
	var edge:=points.duplicate();edge.append(points[0]);c.draw_polyline(edge,_alpha(INK,strength*.75),maxf(1.0,size*.06),false)
	var horizontal:=Vector2(size*.26,0).rotated(angle)
	c.draw_line(at-Vector2(horizontal.x*d,horizontal.y),at+Vector2(horizontal.x*d,horizontal.y),_alpha(RED,strength*.72),maxf(1.0,size*.065),false)

static func _papers(c: CanvasItem, at: Vector2, end: Vector2, h: float, d: float, p: float, count: int, strength: float) -> void:
	for i in range(count):
		var t:=fposmod(p*.50+float(i)/maxf(1.0,count),1.0)
		var center:=at.lerp(end,t)+Vector2(d*sin(t*TAU+i)*h*.08,-sin(t*PI)*h*.16)
		_paper(c,center,h*(.11+.028*(i%3)),p*2.3+i*.61,d,strength*(.30+.70*sin(t*PI)))

static func _stamp(c: CanvasItem, at: Vector2, h: float, word: String, d: float, p: float, strength: float) -> void:
	var size:=Vector2(h*.65,h*.36)*(1.0+p*.16)
	var angle: float=-.10+p*.08;var points:=PackedVector2Array()
	for q in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]:
		var v: Vector2=(q*size).rotated(angle);points.append(at+Vector2(v.x*d,v.y))
	points.append(points[0]);c.draw_polyline(points,_alpha(INK,strength*.65),maxf(2.0,h*.035),false)
	c.draw_polyline(points,_alpha(RED,strength),maxf(1.8,h*.023),false)
	var font_size:=maxi(9,int(h*.15));var pos:=at+Vector2(-FONT.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*.5,h*.052)
	c.draw_string_outline(FONT,pos,word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,2,_alpha(INK,strength*.65))
	c.draw_string(FONT,pos,word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,_alpha(RED,strength))

static func _beat(frame: float, marks: Array, tail: float=9.0) -> float:
	var weight:=0.0
	for mark in marks:
		var since: float=frame-float(mark)
		if since>=0 and since<tail:weight=maxf(weight,1.0-since/tail)
	return weight

static func _frame(move: String, p: float, v: Dictionary) -> float:
	return maxf(0,float(v.get("confirmed_frame",p*float(DURATIONS.get(move,30.0)))))

static func _claws(c: CanvasItem, hand: Vector2, h: float, span: float, angle: float, d: float, p: float, strength: float) -> void:
	var axis:=Vector2(cos(angle)*d,sin(angle));var side:=Vector2(-axis.y,axis.x)
	for i in range(3):
		var start:=hand+side*(i-1)*h*.10-axis*h*.05
		var end:=start+axis*span*(.76+i*.10)
		_curve(c,start,end,(i-1)*h*.06,PINK,h,d,strength*(1.0-i*.09),.043,0.0,clampf(.56+p*.44,0,1))

static func _water_curl(c: CanvasItem, at: Vector2, h: float, span: float, d: float, p: float, strength: float, low: bool=false) -> void:
	_curve(c,at-Vector2(d*span*.27,0),at+Vector2(d*span*.55,-h*(.09 if low else .24)),-h*(.10 if low else .30),WATER,h,d,strength,.043)
	_arc(c,at+Vector2(d*span*.35,-h*.12),h*(.20 if low else .30),-1.9,.50,.80,WATER,h,d,strength*.86,.038)
	_droplets(c,at+Vector2(d*span*.29,-h*.08),h,d,p,strength,4)

static func _blade(c: CanvasItem, move: String, actor: Variant, v: Dictionary, hand: Vector2, tip: Vector2, h: float, span: float, d: float, p: float, strength: float) -> void:
	var axis:=tip-hand;var angle:=atan2(axis.y,axis.x*d)
	var radius:=minf(axis.length(),span*.70)
	var sweep: float=.60 if move=="rio_sword_lever" else .42
	if move=="rio_deadweight_crash":sweep=.82
	if move=="rio_sword_runaway":sweep=.72
	var clip:=move+("__"+str(v["branch"]) if not str(v.get("branch","")).is_empty() else "")+"_"+str(v.get("stage","active"))
	var previous:=Pixel.get_pose_state("rio",clip,maxf(0,p-.08))
	if previous.get("ready",false):
		var unit: float=h/(float(previous["native_height"])*4.0)
		var old_tip: Vector2=previous["joint_positions"]["weapon_tip"]*unit
		old_tip=actor.position+Vector2(old_tip.x*d,old_tip.y)
		var delta: float=absf((old_tip-hand).angle()-(tip-hand).angle())
		if delta<1.20:sweep=clampf(maxf(delta,sweep*.48),.18,.82)
	_arc(c,hand,radius,angle-sweep,angle+.04,1.0,STEEL,h,d,strength,.055)
	_arc(c,hand,radius*.82,angle-sweep*.72,angle-.03,1.0,ICE,h,d,strength*.42,.026)
	_spark(c,tip,h*.24,STEEL,h,d,fposmod(p*1.6,1),3,strength*.65)

static func draw(c: CanvasItem, actor: Variant, v: Dictionary, props: Array, layer: String, hand: Vector2, tip: Vector2, joints: Dictionary, unit: float) -> void:
	if layer!="back" or not bool(v.get("ready",false)):return
	var move:=str(v.get("semantic_move_id",""));var spec:=profile(move)
	if not spec["ready"]:return
	var at: Vector2=actor.position;var h: float=maxf(16,float(actor.body_height))
	var d: float=1 if actor.facing>=0 else -1;var floor:=Vector2(at.x,float(actor.stage_floor_y))
	var stage:=str(v.get("stage","startup"));var p:=clampf(float(v.get("phase",0)),0,1);var frame:=_frame(move,p,v)
	var span: float=h*float(spec["release_span_h"])
	var windup: bool=stage in ["startup","charge","stance","counter"]
	var strength: float=(.38+.38*p) if windup else (1.0 if stage!="recovery" else 1.0-smoothstep(.02,.48,p))
	if stage=="confirmed":strength*=1.0-smoothstep(float(DURATIONS.get(move,30.0))-7.0,float(DURATIONS.get(move,30.0)),frame)
	if strength<=.02:return
	var id: String=actor.fighter_id
	if id=="rio":
		if windup:
			_trace(c,PackedVector2Array([hand+(tip-hand)*.32,hand+(tip-hand)*.82]),STEEL,h,strength,.026)
			_spark(c,tip,h*.20,STEEL,h,d,p,3,strength)
			if move=="rio_drag_charge":_ellipse(c,Vector2(tip.x,floor.y),h*.65,DUST,h,d,p,strength*.57,1)
		else:
			var beat: float=_beat(frame,[12,36,64,94],9) if stage=="confirmed" and move=="rio_sword_runaway" else 1.0
			_blade(c,move,actor,v,hand,tip,h,span,d,p,strength*(.35+beat*.65))
			if move=="rio_deadweight_crash" or (move=="rio_sword_runaway" and stage=="confirmed" and frame>=94):
				var ground_p: float=clampf((frame-94)/15.0,0,1) if stage=="confirmed" else p
				_ellipse(c,Vector2(tip.x,floor.y),span*.70,DUST,h,d,ground_p,strength,2)
				_spark(c,Vector2(tip.x,floor.y-3),h*.65,DUST,h,d,ground_p,6,strength)
	elif id=="cat":
		if windup:
			if move=="cat_meme_sway":
				var pos:=at+Vector2(-d*h*.30,-h*.83)
				c.draw_string_outline(FONT,pos,"?",HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(12,int(h*.24)),2,_alpha(INK,strength))
				c.draw_string(FONT,pos,"?",HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(12,int(h*.24)),_alpha(PINK,strength))
			elif move=="cat_rolling_paw":_droplets(c,at+Vector2(-d*h*.08,-h*.55),h,d,p,strength,3)
			else:_spark(c,hand,h*.18,PINK,h,d,p,3,strength)
		else:
			var branch:=str(v.get("branch",""))
			if move=="cat_startled_pop":
				for i in range(5):
					var mark:=at+Vector2((i-2)*h*.07,-h*(.71+.05*sin(i)))
					_trace(c,PackedVector2Array([mark,mark+Vector2((i-2)*h*.025,-h*.15)]),PINK,h,strength*(1-p*.65),.029)
			elif move=="cat_rolling_paw":
				_water_curl(c,at+Vector2(-d*h*.30,-h*.10),h,h*1.1,d,p,strength*.63,true)
				_droplets(c,at+Vector2(-d*h*.18,-h*.24),h,d,p,strength,5)
			elif move=="cat_meme_sway" and branch.is_empty():_curve(c,floor+Vector2(-d*h*.34,-1),floor+Vector2(d*h*.25,-1),-h*.08,PINK,h,d,strength*.48,.025)
			elif branch=="cat_grab":_arc(c,hand,h*.33,-.85,.85,.74,PINK,h,d,strength,.032)
			else:
				var marks: Array=[12,28,48] if move=="cat_comment_combo" else [12,30,52,74,92]
				var beat: float=_beat(frame,marks,8) if stage=="confirmed" else 1.0
				var down: bool=stage=="confirmed" and frame>=(48 if move=="cat_comment_combo" else 74)
				var angle: float=.68 if down or branch=="jump_claw" else (-.24 if frame<20 else .20)
				_claws(c,hand,h,span*.57,angle,d,p,strength*(.20+beat*.80))
				if down:_ellipse(c,Vector2(hand.x,floor.y),span*.56,PINK,h,d,fposmod(frame/12.0,1),strength*beat,1)
	elif id=="worker":
		if windup:
			if move in ["worker_polite_counter","worker_deadline_counter"]:_trace(c,PackedVector2Array([hand-Vector2(d*h*.10,0),hand+Vector2(d*h*.18,-h*.05)]),RED,h,strength,.03)
			else:_papers(c,hand,hand+Vector2(d*h*.45,-h*.40),h,d,p,3,strength)
		else:
			var end:=hand+Vector2(d*span*.48,-h*.08)
			if move=="worker_folder_set":end=Vector2(hand.x+d*h*.40,floor.y-4)
			elif move=="worker_case_upper":end=hand+Vector2(d*h*.22,-h*.65)
			var number: int=4 if int(spec["rank"])==1 else (6 if int(spec["rank"])==2 else 8)
			_papers(c,hand,end,h,d,p,number,strength)
			if stage=="confirmed" and move in ["worker_polite_counter","worker_deadline_counter","worker_overtime_reject"]:
				var marks: Array=[12] if move=="worker_polite_counter" else ([12,28,44] if move=="worker_deadline_counter" else [16,44,72,100])
				var beat:=_beat(frame,marks,8)
				var target: Vector2=v.get("target_position",at+Vector2(d*h,0))
				_stamp(c,target+Vector2(0,-h*.38),h,"却下" if move=="worker_overtime_reject" else "定時",d,1-beat,strength*beat)
			if move=="worker_overtime_reject" and stage=="confirmed" and frame>=94:
				var origin: Vector2=v.get("confirmed_origin",floor)
				var door:=Vector2(origin.x+d*h*2.1,floor.y)
				var beat:=_beat(frame,[100],13)
				_spark(c,door+Vector2(0,-h*.48),h*.64,PAPER,h,d,1-beat,5,strength*beat)
	elif id=="chicken":
		var ball: Vector2=v.get("ball_position",hand)
		if bool(v.get("ball_in_hand",false)):ball=hand
		var branch:=str(v.get("branch",""))
		if windup:
			_arc(c,ball,h*.19,-2.5,-.30,.74,ORANGE,h,d,strength,.03)
			_curve(c,floor-Vector2(d*h*.20,0),floor+Vector2(d*h*.35,-1),-h*.05,ORANGE,h,d,strength*.53,.025)
		else:
			if move in ["chicken_bounce_pass","chicken_rebound_pop","chicken_air_contest"]:
				var vertical: bool=move!="chicken_bounce_pass"
				var behind:=ball+Vector2(-d*h*.58,h*.40 if vertical else h*.03)
				_curve(c,behind,ball,-h*.05,ORANGE,h,d,strength,.047)
				_curve(c,behind+Vector2(0,h*.035),ball+Vector2(0,h*.035),-h*.02,STEEL,h,d,strength*.34,.024)
			elif move=="chicken_dribble_sway":
				var reverse: float=-d if branch in ["fake_shot","fake","feint"] else d
				_curve(c,at+Vector2(-reverse*h*.4,-h*.35),hand,-h*.13,ORANGE,h,reverse,strength*.81,.044)
				_ellipse(c,floor,h*.63,ORANGE,h,d,p,strength*.50,1)
			else:
				var final_f: float=52 if move=="chicken_alley_oop" else 106
				var marks: Array=[20,52] if move=="chicken_alley_oop" else [16,40,70,106]
				var beat:=_beat(frame,marks,10) if stage=="confirmed" else 1.0
				var end:=hand;var start:=hand+Vector2(-d*h*.35,h*.65)
				if stage=="confirmed" and frame>=final_f:start=hand-Vector2(d*h*.25,h*.85)
				var airborne: bool=stage=="confirmed" and at.y<floor.y-h*.05
				if airborne:
					# Readable rubber-orange wake stays attached to the actual held ball,
					# including the interval between true contact beats. No second ball.
					start=hand+Vector2(-d*h*.18,h*.48 if frame<final_f else -h*.48)
					_curve(c,start,end,-h*.025,ORANGE,h,d,strength*.98,.070)
				else:_curve(c,start,end,-h*.15,ORANGE,h,d,strength*(.35+beat*.65),.060)
				if not airborne:_curve(c,start+Vector2(-d*h*.06,0),end,-h*.22,STEEL,h,d,strength*.43,.025)
				if stage=="confirmed" and frame>=final_f:
					var impact_p:=clampf((frame-final_f)/16.0,0,1)
					_ellipse(c,Vector2(hand.x,floor.y),span*.73,ORANGE,h,d,impact_p,strength,3)
					_spark(c,Vector2(hand.x,floor.y-3),h*.47,ORANGE,h,d,impact_p,5,strength)
	elif id=="shark":
		var branch:=str(v.get("branch",""))
		if windup:
			for key: String in ["front_foot","middle_foot","back_foot"]:
				var local: Vector2=joints.get(key,Vector2.ZERO)*unit
				var foot:=at+Vector2(local.x*d,local.y)
				_trace(c,PackedVector2Array([foot-Vector2(d*h*.09,1),foot+Vector2(d*h*.11,1)]),WATER,h,strength*.72,.028)
		else:
			if move=="shark_tripod_spinner":
				for key: String in ["front_foot","middle_foot","back_foot"]:
					var local: Vector2=joints.get(key,Vector2.ZERO)*unit
					var foot:=at+Vector2(local.x*d,local.y)
					var is_kick: bool=key=="front_foot"
					_arc(c,foot,h*(.18 if is_kick else .12),-2.65,.32,.46,WATER,h,d,strength*(1.0 if is_kick else .80),.052 if is_kick else .034)
					if is_kick:_droplets(c,foot,h,d,p,strength,3)
			elif move=="shark_tripod_brace":_water_curl(c,at+Vector2(d*h*.15,-h*.36),h,h*.90,d,p,strength)
			elif move=="shark_shoe_dash":
				var brake: bool=branch in ["brake","stop","feint"]
				_water_curl(c,floor+Vector2(d*h*(.12 if brake else -.28),-2),h,span*.72,-d if brake else d,p,strength,true)
				if branch in ["spin","hop_spin","jump_spin"]:_arc(c,at+Vector2(0,-h*.20),h*.49,-2.4,.35,.44,WATER,h,d,strength,.045)
			else:
				var marks: Array=[16,40] if move=="shark_three_step_rush" else [12,32,54,74,96]
				var beat:=_beat(frame,marks,9) if stage=="confirmed" else 1.0
				var index: int=0 if frame<22 else (1 if frame<43 else (2 if frame<65 else 0))
				var key: String=["front_foot","middle_foot","back_foot"][index]
				var local: Vector2=joints.get(key,Vector2.ZERO)*unit
				var foot:=at+Vector2(local.x*d,local.y)
				_water_curl(c,foot,h,span*.52,d,p,strength*(.45+beat*.55),true)
				if move=="shark_world_tour" and stage=="confirmed" and frame>=96:
					var final_p:=clampf((frame-96)/15.0,0,1)
					_ellipse(c,floor,span*.80,WATER,h,d,final_p,strength,3)
					_droplets(c,floor,h,d,final_p,strength,7)

static func draw_prop_wake(c: CanvasItem,props: Array,layer: String,owner: int,h: float,floor_y: float) -> void:
	if layer!="back":return
	for prop: Dictionary in props:
		if int(prop.get("owner_index",-1))!=owner or str(prop.get("kind",""))!="basketball":continue
		var state:=str(prop.get("state","held"))
		if state not in ["outbound","returning"]:continue
		var at: Vector2=prop.get("position",Vector2.ZERO)
		if not at.is_finite():continue
		var d: float=1.0 if int(prop.get("facing",1))>=0 else -1.0
		var returning: bool=state=="returning"
		var start:=at-Vector2(d*h*(.32 if returning else .62),0)
		_curve(c,start,at,-h*.045,STEEL if returning else ORANGE,h,d,.38 if returning else .86,.024 if returning else .042)
		if bool(prop.get("bounced",false)) and not returning:
			_ellipse(c,Vector2(at.x,floor_y),h*.70,ORANGE,h,d,fposmod(float(prop.get("age",0))/18.0,1),.55,1)
