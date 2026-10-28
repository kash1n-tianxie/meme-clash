extends RefCounted
## Red/white notification materials. Every projectile is a real source child.
const RED: Color=Color("e94359")
const RIM: Color=Color("9c243e")
const WHITE: Color=Color("fff8ec")
const CHECK: Color=Color("38a777")
const PHONE: Color=Color("59bfc3")
const FONT: Font=preload("res://assets/fonts/NotoSansJP.ttf")
const MOTIFS: Dictionary={"U":"phone_two_source_pings","SU":"three_unread_source_bubbles","WU":"seen_phone_check","I":"wait_phone_case","WI":"overhead_incoming_call","SI":"mute_all_99_badges","AIR_U":"phone_reminder_landing","AIR_I":"falling_notification_board"}

static func _v(value: Variant) -> Vector2:
	if value is Vector2:return value
	if value is Array and value.size()>=2:return Vector2(float(value[0]),float(value[1]))
	return Vector2.INF
static func _clock(s: Dictionary) -> float:
	return float(s.get("frame",0))+clampf(float(s.get("source_clock",0))*30.0,0,.999) if bool(s.get("source_playing",true)) else float(s.get("frame",0))
static func _packet(s: Dictionary) -> Dictionary:
	return {"ready":true,"motif":MOTIFS.get(str(s.get("slot","")),"notification"),"shapes":[],"body_copies":0,"projectile_copies":0,"creates_contact":false,"source_clock_mutated":false,"changes_collision":false,"confirmed_finish":false,"clock":"source_actor_child_or_confirmed_contact_age"}
static func _shape(at: Vector2,size: Vector2,kind: String,alpha: float,token: String="") -> Dictionary:
	return {"at":at,"size":size,"kind":kind,"alpha":clampf(alpha,0,1),"token":token}

static func actor_geometry(s: Dictionary) -> Dictionary:
	if not s.get("ready",false) or str(s.get("id",""))!="notify":return {"ready":false}
	var anchors: Dictionary=s.get("anchors",{})
	var hand: Vector2=_v(anchors.get("hand"));var phone: Vector2=_v(anchors.get("phone"));var bag: Vector2=_v(anchors.get("bag_grip",anchors.get("bag")))
	if not hand.is_finite() or not phone.is_finite() or not bag.is_finite():return {"ready":false,"missing_anchor":true}
	var result: Dictionary=_packet(s);var shapes: Array=result.shapes
	var h: float=clampf(float(s.get("height",90)),16,180);var f: float=float(s.get("facing",1))
	var release: Dictionary=s.get("release_state",{});var slot: String=str(s.get("slot","U"))
	var active: bool=bool(release.get("active",false));var prepare: float=float(release.get("prepare",0))
	var recovery: float=float(release.get("recovery_phase",1));var phase: float=float(release.get("phase",0))
	var cinema: Dictionary=s.get("cinema_phase",{});var stage: String=str(cinema.get("stage",""));var stage_phase: float=float(cinema.get("progress",0))
	var alpha: float=.98 if active else (.35+.52*prepare if prepare>0 else (.38*pow(1-recovery,1.6) if release.get("recovering",false) else 0.0))
	if slot=="SI" and stage=="heavy":alpha=.88
	result["origin"]=phone;result["attached_to"]=["hand","phone","bag_grip"]
	if alpha<=.002:return result
	# Tiny screen edges belong to the measured phone, never to a guessed face.
	shapes.append(_shape(phone,Vector2(h*.12,h*.20),"phone",alpha))
	if slot in ["U","SU"]:
		shapes.append(_shape(phone+Vector2(f*h*.13,-h*.035),Vector2(h*.06,h*.06),"spark",alpha*.65))
	elif slot=="WU":
		shapes.append(_shape(hand+Vector2(f*h*.13,-h*.06),Vector2(h*.20,h*.20),"tick_preview",alpha*.58))
	elif slot in ["I","AIR_I"]:
		var at: Vector2=phone+Vector2(f*h*.24,h*.04 if slot=="I" else h*.15)
		shapes.append(_shape(at,Vector2(h*.74,h*.57)*(1.0+phase*.08),"case",alpha*.89))
	elif slot=="WI":
		shapes.append(_shape(phone+Vector2(f*h*.18,-h*.14),Vector2(h*.23,h*.18),"call",alpha*.73))
	elif slot=="SI":
		# Local unread badges sit behind the actor; the real bag/body still draw.
		for n in range(3 if active or stage=="heavy" else 1):
			var t: float=float(n)*2.1+_clock(s)*.065
			var fold: float=clampf((stage_phase-float(n)*.19)/.52,0,1) if stage=="heavy" else (1.0 if stage=="impact" else 0.0)
			var radial: Vector2=Vector2(cos(t)*h*.42,sin(t)*h*.22-h*.08)*(1.0-fold*.71)
			var at: Vector2=bag+radial
			shapes.append(_shape(at,Vector2(h*.31*(1.0-fold*.76),h*.20*(1.0-fold*.48)),"fold_badge" if fold>.72 else "badge",alpha*.88,"99+"))
	elif slot=="AIR_U":
		shapes.append(_shape(hand+Vector2(f*h*.12,h*.10),Vector2(h*.14,h*.17),"alert",alpha*.64))
	# The source TF label and physical grounded flag must agree. An attempted
	# airborne release cannot create a ground confirmation or shock ring.
	if slot in ["WI","AIR_U","AIR_I"] and bool(s.get("grounded",false)) and str(s.get("label","")).contains("_TF"):
		var position: Vector2=s.get("position",Vector2.ZERO)
		var at: Vector2=Vector2(position.x,float(s.get("floor",position.y))-h*.04)
		shapes.append(_shape(at,Vector2(h*.70,h*.075),"case",alpha*.72))
		for n in range(3):
			var offset: Vector2=Vector2((n-1)*h*(.23+phase*.12),-h*(.04+phase*.11))
			shapes.append(_shape(at+offset,Vector2(h*.10,h*.025),"glass",alpha*(1-phase)*.63))
	return result

static func object_geometry(s: Dictionary) -> Dictionary:
	if not s.get("ready",false) or str(s.get("id",""))!="notify" or s.get("removed",false):return {"ready":false}
	var box: Rect2=s.get("box",Rect2());if not box.has_area():return {"ready":false}
	var result: Dictionary=_packet(s);var h: float=clampf(float(s.get("height",90)),16,180)
	var slot: String=str(s.get("slot","U"));var token: String="1";var name: String=str(s.get("name",""))
	if slot=="U":token="3" if str(s.get("symbol","")).ends_with("mc_044") or int(s.get("source_release_rank",0))>0 else "1"
	elif slot=="SU":token="!" if name=="zh31atm" else ("call" if name=="zh32atm" else "dot")
	else:token="99+" if slot=="SI" else "call"
	var center: Vector2=box.get_center();var size: Vector2=Vector2(clampf(box.size.x,h*.19,h*.55),clampf(box.size.y,h*.14,h*.32))
	var traveling: bool=bool(s.get("hit_able",true)) and not bool(s.get("bullet_hit",false)) and not bool(s.get("timeout",false))
	var alpha: float=.94 if traveling else .34
	# Bullet timelines can loop. Their frame_count is not a lifetime; only
	# the actual removed/hit/hold state determines whether this object exists.
	result.merge({"center":center,"token":token,"source_objects_drawn":1,"source_position":s.get("position",center),"birth":s.get("birth_source_absolute_frame",-1),"source_hold_ticks":s.get("hold_ticks",-1),"traveling":traveling},true)
	result.shapes.append(_shape(center,size*(.96+.025*sin(_clock(s)*.37)),"bubble",alpha,token))
	var velocity: Vector2=s.get("velocity",Vector2.ZERO)
	if traveling and velocity.length_squared()>.01:
		var axis: Vector2=velocity.normalized()
		for n in range(2):result.shapes.append(_shape(center-axis*(size.x*.58+h*.06*n),Vector2(h*.023,h*.023),"spark",.38-.11*n))
	return result

static func contact_geometry(s: Dictionary) -> Dictionary:
	var outcome: String=str(s.get("outcome",""))
	if not s.get("ready",false) or str(s.get("id",""))!="notify" or not s.get("confirmed",true) or outcome not in ["hit","guard_break","guard","blocked","armor","steel","counter","bullet_clash"]:return {"ready":false}
	var at: Vector2=_v(s.get("pos"));if not at.is_finite():return {"ready":false}
	var result: Dictionary=_packet(s);var h: float=clampf(float(s.get("height",90)),16,180);var a: float=float(s.get("alpha",1))
	var hit: bool=outcome in ["hit","guard_break"]
	var final: bool=hit and bool(s.get("finisher",false));result["confirmed_finish"]=final
	var slot: String=str(s.get("slot","U"))
	if final and slot=="SI":
		var phase: float=float(s.get("phase",0))
		result["open_center"]=true
		result.shapes.append(_shape(at+Vector2(0,h*.06),Vector2(h*1.02,h*(1.22+phase*.12)),"mute",a*.96))
		for n in range(7):
			var angle: float=float(n)*2.399
			var orbit: Vector2=Vector2(cos(angle),sin(angle))
			var pos: Vector2=at+orbit*h*(.61+phase*.35)
			result.shapes.append(_shape(pos,Vector2(h*(.16-.06*phase),h*.05),"glass",a*(1-phase)*.82))
	else:result.shapes.append(_shape(at,Vector2(h*(.55 if final else .28),h*(.38 if final else .23)),"tick" if hit and slot=="WU" else ("burst" if hit else "deflect"),a*.94))
	return result

static func _rounded(at: Vector2,size: Vector2) -> PackedVector2Array:
	var radius: float=minf(size.x,size.y)*.25;var points: PackedVector2Array=PackedVector2Array()
	for corner in range(4):
		var angle: float=-PI*.5+corner*PI*.5
		var center: Vector2=at+Vector2((1 if corner in [0,1] else -1)*(size.x*.5-radius),(-1 if corner in [0,3] else 1)*(size.y*.5-radius))
		for n in range(6):points.append(center+Vector2.from_angle(angle+float(n)*PI*.1)*radius)
	return points
static func _stroke(canvas: CanvasItem,points: PackedVector2Array,color: Color,alpha: float,width: float=2.0) -> void:
	canvas.draw_polyline(points,Color(color,alpha),width,true)
static func _paint(canvas: CanvasItem,shape: Dictionary) -> void:
	var at: Vector2=shape.at;var size: Vector2=shape.size;var a: float=shape.alpha;var kind: String=shape.kind
	if a<=.002:return
	if kind in ["bubble","badge"]:
		canvas.draw_colored_polygon(_rounded(at+Vector2(0,size.y*.08),size*1.06),Color(RIM,a*.83))
		canvas.draw_colored_polygon(_rounded(at,size),Color(RED,a))
		if kind=="bubble":canvas.draw_colored_polygon(_rounded(at-Vector2(0,size.y*.045),size*Vector2(.86,.75)),Color(WHITE,a))
		var token: String=str(shape.token)
		if token in ["call","dot"]:
			_paint(canvas,_shape(at,size*.51,"call" if token=="call" else "spark",a))
		else:
			var font_size: int=maxi(9,int(size.y*.58));var width: float=FONT.get_string_size(token,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			canvas.draw_string(FONT,at+Vector2(-width*.5,size.y*.20),token,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(WHITE if kind=="badge" else RED,a))
	elif kind in ["phone","case","deflect","fold_badge"]:
		var points: PackedVector2Array=_rounded(at,size);points.append(points[0])
		if kind=="case":_stroke(canvas,points,RIM,a*.88,maxf(3,size.y*.073))
		_stroke(canvas,points,PHONE if kind=="phone" else RED,a,maxf(1.8,size.y*.065))
		if kind=="phone":canvas.draw_line(at+Vector2(-size.x*.18,size.y*.26),at+Vector2(size.x*.18,size.y*.26),Color(WHITE,a),1.3,true)
		elif kind=="case":
			canvas.draw_line(at+size*Vector2(-.33,-.33),at+size*Vector2(.11,-.33),Color(WHITE,a*.92),maxf(1.8,size.y*.032),true)
			canvas.draw_line(at+size*Vector2(.33,.13),at+size*Vector2(.33,.30),Color(PHONE,a*.78),maxf(1.6,size.y*.035),true)
	elif kind in ["tick","tick_preview"]:
		_stroke(canvas,PackedVector2Array([at+size*Vector2(-.37,.0),at+size*Vector2(-.10,.26),at+size*Vector2(.39,-.30)]),CHECK if kind=="tick" else PHONE,a,maxf(2,size.y*.11))
	elif kind=="call":
		_stroke(canvas,PackedVector2Array([at+size*Vector2(-.28,-.28),at+size*Vector2(-.20,.12),at+size*Vector2(.15,.31),at+size*Vector2(.30,.12)]),RED,a,maxf(2,size.y*.10))
		canvas.draw_arc(at+size*Vector2(.08,-.06),size.y*.32,-1.25,-.15,10,Color(PHONE,a*.75),1.5,true)
	elif kind=="mute":
		var points: PackedVector2Array=PackedVector2Array([at+size*Vector2(-.42,.34),at+size*Vector2(-.31,.17),at+size*Vector2(-.28,-.23),at+size*Vector2(-.17,-.40),at+size*Vector2(0,-.46),at+size*Vector2(.17,-.40),at+size*Vector2(.28,-.23),at+size*Vector2(.31,.17),at+size*Vector2(.42,.34),at+size*Vector2(-.42,.34)])
		_stroke(canvas,points,RIM,a,maxf(3,size.y*.032))
		_stroke(canvas,points,WHITE,a*.91,maxf(1.5,size.y*.014))
		canvas.draw_arc(at+size*Vector2(0,.34),size.y*.075,0,PI,9,Color(RED,a),maxf(2,size.y*.026),true)
		canvas.draw_line(at-size*.36,at+size*.36,Color(RED,a),maxf(3,size.y*.029),true)
	elif kind=="glass":
		var points: PackedVector2Array=PackedVector2Array([at+size*Vector2(-.5,.48),at+size*Vector2(.0,-.48),at+size*Vector2(.5,.08)])
		_stroke(canvas,points,WHITE,a,maxf(1.8,size.y*.21))
		canvas.draw_line(points[1],points[2],Color(PHONE,a*.75),1.3,true)
	elif kind in ["alert","burst"]:
		for n in range(3):
			var axis: Vector2=Vector2.from_angle(-.9+float(n)*1.02)
			canvas.draw_line(at+axis*size.y*.29,at+axis*size.y*.57,Color(RED,a),maxf(1.6,size.y*.08),true)
	else:canvas.draw_circle(at,minf(size.x,size.y)*.5,Color(RED,a))
static func _draw(canvas: CanvasItem,packet: Dictionary,layer: String,draw_layer: String="back") -> Dictionary:
	if packet.get("ready",false) and layer==draw_layer:
		for shape: Dictionary in packet.shapes:_paint(canvas,shape)
	return packet
static func draw_actor(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:
	var geometry: Dictionary=s["geometry"] if s.get("geometry") is Dictionary else actor_geometry(s)
	return _draw(canvas,geometry,layer)
static func draw_object(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:return _draw(canvas,object_geometry(s),layer)
static func draw_contact(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:
	var geometry: Dictionary=s["geometry"] if s.get("geometry") is Dictionary else contact_geometry(s)
	return _draw(canvas,geometry,layer,"front")
