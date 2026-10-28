extends RefCounted
## v0.20 semantic material renderer. Reads actual move/prop/contact state only.
## No fighter copy, previous-body trail, damage, RNG, audio or gameplay clock here.
const Pixel = preload("res://game/pixel_fighter.gd")
const Release = preload("res://game/authored_skill_release.gd")
const INK = Color("18364b")
const WHITE = Color("fff7e8")
const STEEL = Color("6ab8d8")
const SAND = Color("c9a16a")
const PAW = Color("f47fb7")
const PAPER = Color("f5efda")
const STAMP = Color("e56c59")
const BALL = Color("ed8d34")
const SEAM = Color("593c32")
const SOLE = Color("3688d8")
const WATER = Color("67d7d9")
const MOVES = [
	"rio_drag_charge","rio_sword_lever","rio_brace_counter","rio_deadweight_crash","rio_sword_runaway",
	"cat_meme_sway","cat_startled_pop","cat_rolling_paw","cat_comment_combo","cat_chat_meltdown",
	"worker_folder_set","worker_case_upper","worker_polite_counter","worker_deadline_counter","worker_overtime_reject",
	"chicken_bounce_pass","chicken_rebound_pop","chicken_dribble_sway","chicken_alley_oop","chicken_final_dunk",
	"shark_shoe_dash","shark_tripod_spinner","shark_tripod_brace","shark_three_step_rush","shark_world_tour"
]
const SUPPORT_MOVES = ["chicken_air_contest"]
const CONFIRMED_DURATION = {"rio_sword_runaway":112.0,"cat_comment_combo":66.0,"cat_chat_meltdown":110.0,"worker_deadline_counter":62.0,"worker_overtime_reject":118.0,"chicken_alley_oop":70.0,"chicken_final_dunk":124.0,"shark_three_step_rush":58.0,"shark_world_tour":114.0}

static func _confirmed_frame(move: String, progress: float, visual: Dictionary) -> float:
	return float(visual.get("confirmed_frame",progress*float(CONFIRMED_DURATION.get(move,30.0))))

static func _beat_alpha(frame: float, marks: Array, length: float=8.0) -> float:
	var result:=0.0
	for mark in marks:
		var since: float=frame-float(mark)
		if since>=0.0 and since<length:result=maxf(result,1.0-since/length)
	return result

static func _fade(color: Color, alpha: float) -> Color:
	return Color(color,clampf(alpha,0.0,1.0)*color.a)

static func _stroke(canvas: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float, alpha: float=1.0) -> void:
	canvas.draw_line(a,b,_fade(INK,alpha*.65),width+2.0,false)
	canvas.draw_line(a,b,_fade(color,alpha),width,false)

static func _point(origin: Vector2, native: Vector2, direction: float) -> Vector2:
	return origin+Vector2(native.x*direction,native.y)

static func _arc(canvas: CanvasItem, center: Vector2, radius: float, start: float, stop: float, color: Color, width: float, alpha: float, direction: float=1.0, ratio: float=1.0) -> void:
	var points:=PackedVector2Array()
	for i in range(13):
		var angle:=lerpf(start,stop,float(i)/12.0)
		points.append(center+Vector2(cos(angle)*radius*direction,sin(angle)*radius*ratio))
	canvas.draw_polyline(points,_fade(INK,alpha*.45),width+2.0,false)
	canvas.draw_polyline(points,_fade(color,alpha),width,false)

static func _chip(canvas: CanvasItem, center: Vector2, size: float, color: Color, alpha: float, tilt: float=0.0) -> void:
	var pts:=PackedVector2Array()
	for point: Vector2 in [Vector2(-.55,.3),Vector2(.1,-.7),Vector2(.6,.4)]:
		pts.append(center+point.rotated(tilt)*size)
	canvas.draw_colored_polygon(pts,_fade(color,alpha))

static func _paper(canvas: CanvasItem, center: Vector2, size: float, alpha: float, angle: float=0.0) -> void:
	var pts:=PackedVector2Array()
	for point: Vector2 in [Vector2(-.6,-.35),Vector2(.6,-.35),Vector2(.6,.35),Vector2(-.6,.35)]:pts.append(center+point.rotated(angle)*size)
	canvas.draw_colored_polygon(pts,_fade(PAPER,alpha))
	pts.append(pts[0]);canvas.draw_polyline(pts,_fade(INK,alpha*.70),1.8,false)
	canvas.draw_line(center+Vector2(-.3,0).rotated(angle)*size,center+Vector2(.3,0).rotated(angle)*size,_fade(STAMP,alpha),1.3,false)

static func _claws(canvas: CanvasItem, center: Vector2, reach: float, phase: float, angle: float, direction: float, alpha: float=1.0) -> void:
	var axis:=Vector2(cos(angle)*direction,sin(angle))
	var side:=Vector2(-axis.y,axis.x)
	for i in range(3):
		var offset:=side*(i-1)*reach*.18
		var front:=center+offset+axis*reach*.45
		var back:=center+offset-axis*reach*(.25+.40*phase)
		_stroke(canvas,back,front,WHITE,2.8,alpha)
		canvas.draw_line(back,back+axis*reach*.35,_fade(PAW,alpha*.72),3.0,false)

static func _cracks(canvas: CanvasItem, floor: Vector2, radius: float, phase: float, alpha: float) -> void:
	for side in [-1.0,1.0]:
		var points:=PackedVector2Array([floor,floor+Vector2(side*radius*.34,-2),floor+Vector2(side*radius*.63,2),floor+Vector2(side*radius*(.72+phase*.28),-1)])
		canvas.draw_polyline(points,_fade(INK,alpha*.65),2.2,false)
		canvas.draw_polyline(points,_fade(SAND,alpha*.55),1.1,false)
		for i in range(3):
			_chip(canvas,floor+Vector2(side*radius*(.16+i*.24),-sin(phase*PI)*radius*(.16+i*.035)),radius*.09,SAND,alpha*.75,i*.7)

static func _feet(canvas: CanvasItem, floor: Vector2, reach: float, phase: float, direction: float, water: bool=false, alpha: float=1.0) -> void:
	for i in range(3):
		var x: float=(-reach*.24+i*reach*.24)*direction
		var p:=floor+Vector2(x,-1)
		_stroke(canvas,p-Vector2(direction*reach*(.18+phase*.22),0),p,SOLE,2.5,alpha*(1.0-i*.14))
		if water:_chip(canvas,p+Vector2(-direction*reach*.17,-sin(phase*PI)*reach*.10),reach*.055,WATER,alpha*.65,i*.6)

## Clip selection is explicit. This can also be used by integration fixtures.
static func visual_clip(id: String, visual: Dictionary) -> String:
	var move:=str(visual.get("semantic_move_id",visual.get("move_id","")))
	var stage:=str(visual.get("stage",visual.get("phase_name","startup")))
	var branch:=str(visual.get("branch",""))
	var candidate:=move+("__"+branch if not branch.is_empty() else "")+"_"+stage
	if Pixel.has_clip(id,candidate):return candidate
	candidate=move+"_"+stage
	return candidate if Pixel.has_clip(id,candidate) else move

## World-space draw. Root calls each layer once for each actual fighter.
## Prop owner_index filtering prevents a single entity being drawn twice.
static func draw(canvas: CanvasItem, actor: Variant, visual: Dictionary, props: Array, layer: String) -> void:
	if layer not in ["back","front"] or actor==null:return
	var id: String=actor.fighter_id
	var h: float=maxf(16.0,float(actor.body_height))
	var owner: int=int(actor.player_index)
	Release.draw_prop_wake(canvas,props,layer,owner,h,float(actor.stage_floor_y))
	draw_props(canvas,props,layer,owner,h,float(actor.stage_floor_y))
	if not bool(visual.get("ready",false)):return
	var move:=str(visual.get("semantic_move_id",visual.get("move_id","")))
	if move not in MOVES and move not in SUPPORT_MOVES:return
	var stage:=str(visual.get("stage","startup"))
	var phase:=clampf(float(visual.get("phase",visual.get("progress",0.0))),0.0,1.0)
	var direction: float=1.0 if actor.facing>=0 else -1.0
	var at: Vector2=actor.position
	var floor:=Vector2(at.x,float(actor.stage_floor_y))
	var pose:=Pixel.get_pose_state(id,visual_clip(id,visual),phase)
	var joints: Dictionary=pose.get("joint_positions",{})
	var unit: float=h/maxf(1.0,float(pose.get("native_height",h*.25))*4.0)
	var hand:=_point(at,joints.get("wrist",Vector2(12,-h*.45))/1.0*unit,direction)
	var rear_hand:=_point(at,joints.get("wrist_back",joints.get("wrist",Vector2.ZERO))*unit,direction)
	var tip:=_point(at,joints.get("weapon_tip",Vector2(20,-h*.5))*unit,direction)
	var active: bool=stage in ["active","confirmed"]
	var ready: bool=stage in ["charge","stance","counter"]
	var alpha:=1.0-smoothstep(.55,1.0,phase) if stage=="recovery" else 1.0
	Release.draw(canvas,actor,visual,props,layer,hand,tip,joints,unit)
	if id=="rio":_draw_rio(canvas,move,stage,phase,hand,tip,floor,h,direction,layer,active,ready,alpha,visual)
	elif id=="cat":_draw_cat(canvas,move,stage,phase,at,rear_hand if float(pose.get("pose",{}).get("rear_paw_front",0.0))>.5 else hand,floor,h,direction,layer,active,ready,alpha,visual)
	elif id=="worker":_draw_worker(canvas,move,stage,phase,at,hand,floor,h,direction,layer,active,ready,alpha,visual)
	elif id=="chicken":_draw_chicken(canvas,move,stage,phase,at,hand,floor,h,direction,layer,active,ready,alpha,visual)
	elif id=="shark":_draw_shark(canvas,move,stage,phase,at,floor,h,direction,layer,active,ready,alpha,visual,joints,unit)

static func _draw_rio(c: CanvasItem, move: String, stage: String, p: float, hand: Vector2, tip: Vector2, floor: Vector2, h: float, d: float, layer: String, active: bool, ready: bool, alpha: float, v: Dictionary) -> void:
	var axis:=tip-hand
	var blade_angle:=atan2(axis.y,axis.x*d)
	var radius:=axis.length()
	if layer=="back":
		if move=="rio_drag_charge" and not active:
			_stroke(c,floor+Vector2(-d*h*.27,0),Vector2(tip.x,floor.y),SAND,2.3,alpha*.50)
		elif move=="rio_sword_lever" and active:
			_arc(c,hand,radius,blade_angle+.45,blade_angle+.08,STEEL,h*.035,.72,d)
		elif move=="rio_deadweight_crash" and active:
			_cracks(c,Vector2(tip.x,floor.y),h*.55,p,alpha*.65)
		elif move=="rio_sword_runaway" and stage=="confirmed":
			var frame:=_confirmed_frame(move,p,v)
			var beat:=_beat_alpha(frame,[12,36,64,94],9.0)
			_arc(c,hand,radius*.96,blade_angle-.58,blade_angle+.08,STEEL,h*.065,.22+beat*.38,d,.75)
			if frame>=94:_cracks(c,Vector2(tip.x,floor.y),h*.60,clampf((frame-94)/18.0,0,1),alpha*.72)
		elif active:
			_arc(c,hand,radius,blade_angle-.32,blade_angle+.10,STEEL,h*.04,.64,d)
	elif move=="rio_brace_counter" and ready:
		_stroke(c,hand+axis*.18,hand+axis*.80,WHITE,1.6,.60)
	elif move=="rio_drag_charge" and str(v.get("charge_tier","weak"))=="strong" and stage=="charge":
		_stroke(c,hand+axis*.20,tip,WHITE,2.2,.92)
	elif active:
		_stroke(c,hand+axis*.75,tip,WHITE,1.8,alpha*.58)
		if move=="rio_deadweight_crash":_chip(c,Vector2(tip.x,floor.y-5),h*.08,SAND,alpha*.62,p)

static func _draw_cat(c: CanvasItem, move: String, stage: String, p: float, at: Vector2, hand: Vector2, floor: Vector2, h: float, d: float, layer: String, active: bool, ready: bool, alpha: float, v: Dictionary) -> void:
	var branch:=str(v.get("branch",""))
	if layer=="back":
		if move=="cat_startled_pop" and active:
			for i in range(5):
				var x: float=(i-2)*h*.055
				var y: float=-h*(.57+.09*sin(float(i)*.8))
				_chip(c,at+Vector2(x*d,y),h*.11,PAPER,alpha*.56,i*.2)
		elif move=="cat_rolling_paw" and active:
			for i in range(3):_chip(c,floor+Vector2(-d*h*(.18+i*.17),-3),h*.05,PAPER,.55*(1.0-p),i*.8)
		elif move=="cat_meme_sway" and ready:
			for i in range(2):c.draw_circle(floor+Vector2(-d*h*(.16+i*.20),-2),h*.025,_fade(PAW,.35))
		return
	if not active:return
	if move=="cat_startled_pop":return
	if move=="cat_rolling_paw":
		if p>.55:_claws(c,hand,h*.16,p,.38,d,alpha*.75)
	elif branch=="cat_grab":
		if bool(v.get("confirmed",false)):_arc(c,hand,h*.10,-.9,.9,PAW,2,.6,d)
	elif move in ["cat_comment_combo","cat_chat_meltdown"]:
		if stage=="confirmed":
			var frame:=_confirmed_frame(move,p,v)
			var marks: Array=[12,28,48] if move=="cat_comment_combo" else [12,30,52,74,92]
			var beat:=_beat_alpha(frame,marks,8.0)
			var down: bool=frame>=48 if move=="cat_comment_combo" else frame>=74
			if beat>0:_claws(c,hand,h*(.32 if down else .25),1.0-beat,.83 if down else (-.18 if frame<20 else .32),d,alpha*beat)
		else:_claws(c,hand,h*.22,p,-.12,d,alpha*.75)
	elif branch=="jump_claw":_claws(c,hand,h*.24,p,.65,d,alpha*.8)
	else:_claws(c,hand,h*.22,p,.04,d,alpha*.8)

static func _draw_worker(c: CanvasItem, move: String, stage: String, p: float, at: Vector2, hand: Vector2, floor: Vector2, h: float, d: float, layer: String, active: bool, ready: bool, alpha: float, v: Dictionary) -> void:
	if layer=="back":
		if move=="worker_overtime_reject" and stage=="confirmed" and _confirmed_frame(move,p,v)>=82.0:
			var origin: Vector2=v.get("confirmed_origin",Vector2(at.x,floor.y))
			var doorway:=Vector2(origin.x+d*h*2.10,floor.y)
			var visibility: float=smoothstep(82.0,90.0,_confirmed_frame(move,p,v))*(1.0-smoothstep(106.0,118.0,_confirmed_frame(move,p,v)))
			var pts:=PackedVector2Array([doorway+Vector2(-d*h*.2,0),doorway+Vector2(-d*h*.2,-h*1.14),doorway+Vector2(d*h*.2,-h*1.14),doorway+Vector2(d*h*.2,0)])
			c.draw_polyline(pts,_fade(INK,.52*visibility),h*.026,false)
			c.draw_polyline(pts,_fade(STAMP,.68*visibility),h*.014,false)
			for i in range(3):_paper(c,doorway+Vector2(d*(i-1)*h*.12,-h*(.15+p*.35)),h*.12,.60,i*.45+p)
		elif move=="worker_case_upper" and active:
			for i in range(2):_paper(c,hand+Vector2(-d*h*.09*i,-h*.12*p),h*.10,.63,i*.6-p)
		elif move=="worker_polite_counter" and stage=="confirmed":
			_stroke(c,floor+Vector2(d*h*.2,-1),floor+Vector2(d*h*.6,-1),STAMP,2.0,.45)
		return
	if move=="worker_case_upper" and stage in ["startup","active"]:
		# Opening is a short rigid lid above the held bag, never a towering paper blast.
		var length: float=h*.24
		var direction:=Vector2(d*cos(-.15-p*.95),sin(-.15-p*.95))*length
		_stroke(c,hand,hand+direction,INK,h*.065,.94)
		_stroke(c,hand+Vector2(0,-1),hand+direction+Vector2(0,-1),PAPER,1.5,.80)
	elif move=="worker_deadline_counter" and stage in ["startup","counter","recovery"]:
		var clock:=at+Vector2(-d*h*.20,-h*.64)
		c.draw_circle(clock,h*.13,_fade(PAPER,alpha))
		c.draw_arc(clock,h*.13,0,TAU,20,_fade(INK,alpha),2.5,false)
		c.draw_line(clock,clock+Vector2(-h*.067,h*.019),_fade(INK,alpha),2,false)
		c.draw_line(clock,clock+Vector2(0,-h*.085),_fade(STAMP,alpha),2,false)
	elif move=="worker_polite_counter" and ready:
		_stroke(c,hand+Vector2(-d*h*.07,0),hand+Vector2(d*h*.08,0),WHITE,1.8,.58)
	elif active and move in ["worker_deadline_counter","worker_overtime_reject"]:
		# Stamp silhouettes follow actual hand motion. Contact cores are a separate event pass.
		var beat: float=_beat_alpha(_confirmed_frame(move,p,v),[12,28,44] if move=="worker_deadline_counter" else [16,44,72,100],9.0) if stage=="confirmed" else .45
		if beat<=0.0:return
		var size: float=h*(.21 if move=="worker_deadline_counter" else .28)
		var rect:=Rect2(hand-Vector2.ONE*size*.5,Vector2.ONE*size)
		c.draw_rect(rect,_fade(STAMP,alpha*.75*beat),false,3.2)
		c.draw_line(rect.position,rect.end,_fade(STAMP,alpha*.80*beat),2,false)

static func _draw_chicken(c: CanvasItem, move: String, stage: String, p: float, at: Vector2, hand: Vector2, floor: Vector2, h: float, d: float, layer: String, active: bool, ready: bool, alpha: float, v: Dictionary) -> void:
	var has_ball: bool=bool(v.get("ball_in_hand",false))
	if layer=="back":
		if move=="chicken_dribble_sway" and stage in ["stance","active"]:
			_stroke(c,floor+Vector2(-d*h*.19,-1),floor+Vector2(d*h*.15,-1),SEAM,2,.43)
		elif move=="chicken_rebound_pop" and active and has_ball:
			_arc(c,hand,h*.18,-.25,-1.45,BALL,2.5,.55,d)
		elif move in ["chicken_alley_oop","chicken_final_dunk"] and stage=="confirmed":
			var frame:=_confirmed_frame(move,p,v)
			var origin: Vector2=v.get("confirmed_origin",Vector2(at.x,floor.y))
			var hoop:=Vector2(origin.x+d*h*.60,floor.y-h*(1.76 if move=="chicken_alley_oop" else 1.96))
			var final_frame: float=52.0 if move=="chicken_alley_oop" else 106.0
			var visible: float=smoothstep(final_frame-38.0,final_frame-24.0,frame)*(1.0-smoothstep(final_frame+8.0,final_frame+18.0,frame))
			if visible>0:
				_arc(c,hoop,h*.24,0,TAU,BALL,3.5,.82*visible,d,.24)
				for i in range(4):_stroke(c,hoop+Vector2((i-1.5)*h*.12,0),hoop+Vector2((i-1.5)*h*.07,h*.23),PAPER,1.8,.66*visible)
			var land:=_beat_alpha(frame,[final_frame],18.0)
			if land>0:
				for i in range(4):_chip(c,floor+Vector2((i-1.5)*h*.20,-sin((1.0-land)*PI)*h*.13),h*.075,BALL,land*.72,i*.5)
		elif move=="chicken_air_contest" and active:
			_arc(c,hand,h*.25,-.05,-1.20,BALL,3.0,.78,d)
		return
	# The real held basketball is drawn once by Pixel with ball_in_hand appearance.
	# Detached basketball is drawn once by draw_props; no translucent ball replicas.
	if active and move=="chicken_dribble_sway" and str(v.get("branch","")) in ["shoulder","jump_dunk","jump_shoulder","jump"]:
		_stroke(c,at+Vector2(d*h*.18,-h*.46),at+Vector2(d*h*.30,-h*.43),WHITE,1.8,alpha*.52)
	elif has_ball and stage=="startup" and move in ["chicken_alley_oop","chicken_final_dunk","chicken_air_contest"]:
		_stroke(c,hand+Vector2(-h*.05,-h*.08),hand+Vector2(h*.05,-h*.08),BALL,1.7,.54)
	elif has_ball and active and move in ["chicken_alley_oop","chicken_final_dunk","chicken_air_contest"]:
		# One short seam accent follows the real held ball; never another ball sprite.
		_stroke(c,hand+Vector2(-d*h*.06,-h*.07),hand+Vector2(d*h*.07,-h*.06),PAPER,2.0,.78)

static func _draw_shark(c: CanvasItem, move: String, stage: String, p: float, at: Vector2, floor: Vector2, h: float, d: float, layer: String, active: bool, ready: bool, alpha: float, v: Dictionary, joints: Dictionary, unit: float) -> void:
	var branch:=str(v.get("branch",""))
	if layer=="back":
		if move=="shark_shoe_dash":
			_feet(c,floor,h*.8,p,d,active,alpha*.66)
			if active and branch in ["hop_spin","spin","jump_spin"]:
				_arc(c,at+Vector2(0,-h*.28),h*.31,-.55,.92,SOLE,h*.035,.58,d,.44)
			if branch in ["brake","stop","feint"]:
				for i in range(3):_chip(c,floor+Vector2(d*h*(.10+i*.07),-sin(p*PI)*h*.08),h*.05,WATER,alpha*.65,i*.8)
		elif move=="shark_tripod_spinner" and active:
			_feet(c,floor,h*.46,p,d,false,.46)
		elif move=="shark_tripod_brace":
			_feet(c,floor,h*.65,p,d,false,.75)
		elif active:
			_feet(c,floor,h*.9,p,d,true,.64)
			if move=="shark_world_tour" and stage=="confirmed":
				var frame:=_confirmed_frame(move,p,v)
				if frame>=96:_cracks(c,floor,h*.47,clampf((frame-96)/18.0,0,1),.65)
		return
	if move=="shark_tripod_brace" and stage=="active":
		# Compact shoulder glint distinguishes actual short armor; no whole-body invulnerability bubble.
		_stroke(c,at+Vector2(d*h*.19,-h*.45),at+Vector2(d*h*.29,-h*.38),WHITE,2.4,.62)
	elif move=="shark_tripod_spinner" and active:
		var kick:=_point(at,joints.get("front_foot",Vector2.ZERO)*unit,d)
		_stroke(c,kick-Vector2(d*h*.05,h*.035),kick+Vector2(d*h*.12,h*.03),WHITE,1.8,alpha*.84)
	elif active and branch in ["slide","low_slide"]:
		_stroke(c,floor+Vector2(d*h*.25,-h*.08),floor+Vector2(d*h*.5,-h*.06),WHITE,2,alpha*.70)
	elif stage=="confirmed" and move in ["shark_three_step_rush","shark_world_tour"]:
		var frame:=_confirmed_frame(move,p,v)
		var marks: Array=[16,40] if move=="shark_three_step_rush" else [12,32,54,74,96]
		var beat:=_beat_alpha(frame,marks,8.0)
		if beat<=0:return
		var index: int=0
		if move=="shark_three_step_rush":index=0 if frame<28 else 2
		else:index=0 if frame<22 else (1 if frame<43 else (2 if frame<65 else 0))
		var key: String=["front_foot","middle_foot","back_foot"][index]
		var shoe:=_point(at,joints.get(key,Vector2.ZERO)*unit,d)
		_stroke(c,shoe+Vector2(-d*h*.04,-h*.05),shoe+Vector2(d*h*.21,-h*.06),WHITE,3.0,beat*.86)
		for i in range(2):_chip(c,shoe+Vector2(-d*h*(.07+i*.08),-h*.04),h*.06,WATER,beat*.68,i*.7)

## Only actual independent entities are presented; caller has already created them.
static func draw_props(canvas: CanvasItem, props: Array, layer: String, owner: int, body_height: float, stage_floor_y: float=0.0) -> void:
	for prop: Dictionary in props:
		if int(prop.get("owner_index",-1))!=owner:continue
		var kind:=str(prop.get("kind",""))
		var state:=str(prop.get("state",""))
		var at: Vector2=prop.get("position",Vector2.ZERO)
		if not at.is_finite():continue
		var phase:=clampf(float(prop.get("progress",0.0)),0.0,1.0)
		var d: float=1.0 if int(prop.get("facing",1))>=0 else -1.0
		if kind=="basketball" and state not in ["held","in_hand","removed"]:
			var radius: float=maxf(3.0,float(prop.get("radius",body_height*.095)))
			if layer=="back":
				var floor_y: float=float(prop.get("floor_y",stage_floor_y))
				canvas.draw_line(Vector2(at.x-radius*.6,floor_y),Vector2(at.x+radius*.6,floor_y),_fade(INK,.18),3,false)
				_stroke(canvas,at+Vector2(-d*radius*1.35,0),at+Vector2(-d*radius*.95,0),PAPER,1.4,.33 if state=="returning" else .55)
			else:
				canvas.draw_circle(at,radius,INK)
				canvas.draw_circle(at,radius-1.3,BALL if state!="returning" else BALL.lerp(PAPER,.13))
				canvas.draw_line(at+Vector2(-radius*.88,0),at+Vector2(radius*.88,0),SEAM,1.5,false)
				canvas.draw_line(at+Vector2(0,-radius*.88),at+Vector2(0,radius*.88),SEAM,1.5,false)
				_arc(canvas,at,radius*.65,-1.2,1.2,SEAM,1.0,.86,1.0)
		elif kind=="folder":
			var width: float=body_height*.33
			if layer=="back":
				var rect:=Rect2(at+Vector2(-width*.5,-width*.15),Vector2(width,width*.21))
				canvas.draw_rect(rect,_fade(INK,.90))
				canvas.draw_rect(rect.grow(-1.0),_fade(PAPER,.94))
				var fold:=PackedVector2Array([rect.position,rect.position+Vector2(width*.20,-width*(.12+.16*phase)),rect.position+Vector2(width*.48,0)])
				canvas.draw_colored_polygon(fold,_fade(STAMP,.80 if state=="armed" else .42))
				for i in range(3):
					var lit: bool=state=="armed" or phase>float(i)/3.0
					canvas.draw_circle(at+Vector2((i-1)*width*.16,-width*.03),1.6,_fade(STAMP,.86 if lit else .25))
			elif state in ["triggered","trigger"]:
				for i in range(3):_paper(canvas,at+Vector2((i-1)*width*.32,-sin(phase*PI)*width*.68),width*.35,1.0-phase,i*.7+phase)

## Contact pass belongs to a real contact event with its own visual_age.
## It cannot lock a target, create a hit or silently replay a successful cinematic.
static func draw_contact(canvas: CanvasItem, pos: Vector2, fighter_id: String, semantic_id: String, outcome: String, age: float, facing: int, scale: float=1.0) -> void:
	if (semantic_id not in MOVES and semantic_id not in SUPPORT_MOVES) or age<0.0 or age>=.22 or not pos.is_finite():return
	var p:=clampf(age/.22,0.0,1.0)
	var a:=pow(1.0-p,1.4)
	var d: float=1.0 if facing>=0 else -1.0
	var is_super: bool=semantic_id in ["rio_deadweight_crash","rio_sword_runaway","cat_comment_combo","cat_chat_meltdown","worker_deadline_counter","worker_overtime_reject","chicken_alley_oop","chicken_final_dunk","shark_three_step_rush","shark_world_tour","chicken_air_contest"]
	var reach: float=clampf(scale,.6,1.6)*(31.0 if is_super else 23.0)
	var color: Color={"rio":STEEL,"cat":PAW,"worker":STAMP,"chicken":BALL,"shark":SOLE}.get(fighter_id,WHITE)
	if outcome in ["guard","blocked"]:
		_arc(canvas,pos,reach*.56,-.74,.74,color,2.4,a,d)
		_stroke(canvas,pos+Vector2(-d*reach*.1,-reach*.15),pos+Vector2(d*reach*.2,reach*.1),WHITE,1.8,a)
		return
	if outcome in ["armor","steel"]:
		_stroke(canvas,pos-Vector2(reach*.25,0),pos+Vector2(reach*.25,0),WHITE,2,a)
		return
	if fighter_id=="rio":
		_stroke(canvas,pos+Vector2(-d*reach,-reach*.48),pos+Vector2(d*reach,reach*.48),WHITE,3.0,a)
		for i in range(4):_chip(canvas,pos+Vector2(d*reach*(.3+p*(.3+i*.2)),-reach*(.2+i*.14)*(1.0-p)),reach*.16,STEEL,a,i)
	elif fighter_id=="cat":
		_claws(canvas,pos,reach*1.12,p,-.35,d,a)
	elif fighter_id=="worker":
		var size: float=reach*(.60+p*.20)
		canvas.draw_rect(Rect2(pos-Vector2.ONE*size*.5,Vector2.ONE*size),_fade(STAMP,a),false,3.0)
		for i in range(3):_paper(canvas,pos+Vector2((i-1)*reach*.6,(-.25-p*.8)*reach),reach*.32,a,i*.9)
	elif fighter_id=="chicken":
		var pts:=PackedVector2Array([pos+Vector2(-d*reach,0),pos+Vector2(0,-reach*.4),pos+Vector2(d*reach*.55,0),pos+Vector2(0,reach*.4)])
		canvas.draw_colored_polygon(pts,_fade(BALL,a*.72))
		_stroke(canvas,pos-Vector2(0,reach*.45),pos+Vector2(0,reach*.45),WHITE,2.2,a)
		for i in range(3):_chip(canvas,pos+Vector2(d*reach*(.35+p*.8),(i-1)*reach*.3),reach*.12,SEAM,a,i)
	elif fighter_id=="shark":
		_stroke(canvas,pos-Vector2(d*reach*.7,0),pos+Vector2(d*reach*.8,0),WHITE,3.0,a)
		for i in range(3):_chip(canvas,pos+Vector2(d*reach*(.4+p*.6),(i-1)*reach*.28),reach*.18,WATER,a,i*.6)
	if age<.05:canvas.draw_circle(pos,reach*.11,_fade(WHITE,a))

static func coverage() -> Dictionary:
	return {"semantic_moves":MOVES.duplicate(),"support_moves":SUPPORT_MOVES.duplicate(),"release_profiles":Release.coverage(),"layers":["back","front"],"contains_character_copy":false,"uses_gameplay_rng":false,"has_contact_event_pass":true,"prop_kinds":["basketball","folder"]}
