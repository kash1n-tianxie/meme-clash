extends RefCounted
const FrameFX=preload("res://game/bvn_frame_fx_v031.gd")
## Basketball materials over immutable BVN actor and child clocks.
## v0.32: one actual ball; broken seam trajectories, hoops and court impact.
const RUBBER := Color("ff812b")
const LIGHT := Color("ffd18a")
const POWER := Color("ffac38")
const CREAM := Color("fff3cb")
const SHADOW := Color("733525")
const SEAM := Color("241b18")
const NET := Color("f7f7da")
const NET_EDGE := Color("52677d")
const DUST := Color("c29b78")
const MOTIFS := {"U":"oversize_spin_pass_panels","SU":"rebounding_low_court_breaker","WU":"underhand_rising_rubber_fountain","AIR_U":"diagonal_down_pass_compression","I":"three_source_balls_progressive_power","WI":"rising_alley_oop_spiral","SI":"giant_woven_hoop_dunk","AIR_I":"carried_ball_meteor_dunk"}
const AMPLIFICATION := {"U":1.38,"SU":1.44,"WU":1.52,"AIR_U":1.43,"I":1.52,"WI":1.64,"SI":1.78,"AIR_I":1.66}
static var _source_fx: Variant

static func amplification(s: Dictionary) -> Dictionary:
	var slot:=str(s.get("slot","U"));var scale:=float(AMPLIFICATION.get(slot,1.0))
	var height:=clampf(float(s.get("height",90.0)),1.0,4096.0)
	return {"ready":bool(s.get("ready",false)) and str(s.get("id",""))=="chicken","id":"chicken","slot":slot,"tier":int(s.get("tier",1)),"motif":MOTIFS.get(slot,"rubber_ball"),"visual_scale":scale,"extent":Vector2(height*scale,height*scale),"body_copies":0,"changes_source":false,"creates_contact":false,"source_owned":true,"actual_sphere_scale":1.0,"visual_reach_is_damage_reach":false,"ball_count_from_source_children_only":true}

static func _source() -> Variant:
	if _source_fx==null:_source_fx=load("res://game/bvn_skill_fx.gd")
	return _source_fx

static func _v(value: Variant) -> Vector2:
	if value is Vector2:return value
	if value is Array and value.size()>=2:return Vector2(float(value[0]),float(value[1]))
	return Vector2(INF,INF)

static func geometry(s: Dictionary) -> Dictionary:
	if not s.get("ready",false) or str(s.get("id",""))!="chicken":return {"ready":false}
	var anchors: Dictionary=s.get("anchors",{})
	var ball_visible:=bool(s.get("ball_visible",anchors.has("ball")))
	var origin:=_v(anchors.get("ball" if ball_visible else "hand"))
	if not origin.is_finite():return {"ready":false,"missing_anchor":true}
	var h:=float(s.get("height",90.0));var f:=float(s.get("facing",1))
	var slot:=str(s.get("slot","U"));var direction:=Vector2(f,-.05)
	if slot in ["WU","WI"]:direction=Vector2(f*.20,-1).normalized()
	elif slot in ["AIR_U","AIR_I"]:direction=Vector2(f*.30,1).normalized()
	elif slot=="SI":direction=Vector2(f*.34,-1 if float(s.get("frame",0))<123 else 1).normalized()
	var bounds:=Rect2();var has_bounds:=false
	for value: Variant in s.get("boxes",[]):
		if value is Rect2 and value.has_area():bounds=bounds.merge(value) if has_bounds else value;has_bounds=true
	var release: Dictionary=s.get("release_state",{})
	var r:=h*(.155 if int(s.get("tier",1))==1 else .19)
	if ball_visible and anchors.has("ball_rim"):
		var measured:=_v(anchors.ball_rim)
		if measured.is_finite():r=clampf(origin.distance_to(measured),h*.09,h*.24)
	return {"ready":true,"origin":origin,"axis":direction,"ball_visible":ball_visible,"ball_radius":r,"active":bool(release.get("active",false)),"phase":float(release.get("phase",0)),"collision_bounds":bounds,"has_collision_bounds":has_bounds,"motif":MOTIFS.get(slot,"rubber_ball"),"solid_motif":true,"seamed_rubber":true,"render_silhouette":"round_rubber_and_net","cut_lanes":[],"attached_to":"ball" if ball_visible else "hand","body_copies":0,"source_clock_mutated":false,"creates_contact":false,"amplification":amplification(s)}

static func _polygon(canvas: CanvasItem,points: PackedVector2Array,color: Color,alpha: float) -> void:
	if points.size()>=3 and alpha>.002:canvas.draw_colored_polygon(points,Color(color,clampf(alpha,0,1)))

static func _ellipse(canvas: CanvasItem,center: Vector2,radius: Vector2,color: Color,alpha: float,rotation: float=0.0) -> void:
	if radius.x<=0 or radius.y<=0:return
	var points:=PackedVector2Array()
	for n in range(24):
		var angle:=TAU*float(n)/24.0
		points.append(center+Vector2(cos(angle)*radius.x,sin(angle)*radius.y).rotated(rotation))
	_polygon(canvas,points,color,alpha)

static func _band_shape(center: Vector2,radius: Vector2,begin: float,end: float,width: float,rotation: float) -> PackedVector2Array:
	var points:=PackedVector2Array()
	for pass_index in range(2):
		for index in range(25):
			var n:=index if pass_index==0 else 24-index
			var angle:=lerpf(begin,end,float(n)/24.0)
			var push:=width*.5 if pass_index==0 else -width*.5
			points.append(center+Vector2(cos(angle)*(radius.x+push),sin(angle)*(radius.y+push)).rotated(rotation))
	return points

static func _trajectory_sample(raw: Vector2,span: float,floor_limit: float) -> Vector3:
	# Only decorative trails compress into the court's depth. Position and
	# opacity share one bounded sample; real source balls/hoops never use it.
	if not is_finite(floor_limit):return Vector3(raw.x,raw.y,1.0)
	var knee:=floor_limit-span
	if raw.y<=knee:return Vector3(raw.x,raw.y,1.0)
	var fade:=exp(-(raw.y-knee)/span)
	return Vector3(raw.x,knee+span*(1.0-fade),fade)

static func _rubber_band(canvas: CanvasItem,center: Vector2,radius: Vector2,begin: float,end: float,width: float,rotation: float,alpha: float,bright: bool=false,floor_limit: float=INF) -> void:
	if alpha<=.002 or minf(radius.x,radius.y)<=0:return
	# A thin, interrupted ball trajectory. The old broad curled orange sheet
	# looked like banana skin and covered the lower HUD during alley-oops.
	# One indexed batch replaces three filled sheets and two rounded caps.
	width=minf(width,minf(radius.x,radius.y)*.17)
	var points:=PackedVector2Array();points.resize(75)
	var colors:=PackedColorArray();colors.resize(75)
	var indices:=PackedInt32Array()
	var shoulder:=maxf(1.0,minf(radius.x,radius.y)*.24)
	for n in range(25):
		var t:=float(n)/24.0;var angle:=lerpf(begin,end,t)
		var fade:=clampf(minf(t,1-t)*9.0,0,1)
		var radial:=Vector2(cos(angle),sin(angle))
		for row in range(3):
			var push:=width*(.5-float(row)*.5)
			var raw:=center+Vector2(radial.x*(radius.x+push),radial.y*(radius.y+push)).rotated(rotation)
			var sample:=_trajectory_sample(raw,shoulder,floor_limit)
			points[n*3+row]=Vector2(sample.x,sample.y)
			var color:=LIGHT if row==0 else ((POWER if bright else RUBBER) if row==1 else SHADOW)
			colors[n*3+row]=Color(color,alpha*fade*sample.z*(.90 if row==0 else (.96 if row==1 else .74)))
		if n==24 or n in [5,13,20]:continue
		for row in range(2):
			var a:=n*3+row;var b:=a+3
			indices.append_array(PackedInt32Array([a,b,b+1,a,b+1,a+1]))
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),indices,points,colors)
	# Black curved panel seams distinguish basketball force from sword light.
	for n in [8,16,22]:
		var angle:=lerpf(begin,end,float(n)/24.0)
		var curve:=PackedVector2Array()
		for row in range(4):
			var u:=float(row)/3.0;var a:=angle+sin(u*PI)*.05
			var push:=width*lerpf(-.44,.44,u)
			var raw:=center+Vector2(cos(a)*(radius.x+push),sin(a)*(radius.y+push)).rotated(rotation)
			var sample:=_trajectory_sample(raw,shoulder,floor_limit)
			curve.append(Vector2(sample.x,sample.y))
		var raw_center:=center+Vector2(cos(angle)*radius.x,sin(angle)*radius.y).rotated(rotation)
		var seam_sample:=_trajectory_sample(raw_center,shoulder,floor_limit)
		canvas.draw_polyline(curve,Color(SEAM,alpha*.93*seam_sample.z),maxf(1.1,width*.17),true)

static func _hoop_arc(canvas: CanvasItem,center: Vector2,radius: Vector2,begin: float,end: float,width: float,alpha: float) -> void:
	# The physical-looking rim remains a continuous metal hoop; it is never
	# confused with the deliberately broken source-ball trajectory above.
	_polygon(canvas,_band_shape(center,radius,begin,end,width*1.12,0),SHADOW,alpha*.95)
	_polygon(canvas,_band_shape(center,radius,begin,end,width,0),RUBBER,alpha)
	_polygon(canvas,_band_shape(center,radius+Vector2.ONE*width*.13,begin,end,width*.18,0),LIGHT,alpha*.86)

static func _rubber_chips(canvas: CanvasItem,at: Vector2,h: float,phase: float,alpha: float,count: int,axis_angle: float=0) -> void:
	for n in range(count):
		var angle:=axis_angle+float(n)*2.399+.31
		var point:=at+Vector2.RIGHT.rotated(angle)*h*(.17+phase*(.48+float(n%2)*.13))
		_source()._draw_ball_panel(canvas,point,h*(.071+.012*(n%3))*(1-phase*.35),angle+phase*.57,alpha*.9)

static func _court_dust(canvas: CanvasItem,at: Vector2,h: float,phase: float,alpha: float,large: bool=false) -> void:
	var span:=h*(1.3 if large else .64)*(.69+phase*.68)
	for n in range(5 if large else 3):
		var side:=float(n)-float(4 if large else 2)*.5
		var point:=at+Vector2(side*span*.35,-h*(.018+.025*(n%2))-h*phase*(.08+.015*n))
		_ellipse(canvas,point,Vector2(h*(.16+.02*(n%2)),h*.05)*(1+phase*.59),DUST,alpha*.42)
		_ellipse(canvas,point+Vector2(-h*.05,-h*.027),Vector2(h*.09,h*.035),LIGHT,alpha*.25)
	_rubber_band(canvas,at,Vector2(span*.74,span*.16),.10,PI-.10,h*(.075 if large else .044),0,alpha*.73,true)

static func _panel_spiral(canvas: CanvasItem,at: Vector2,radius: Vector2,width: float,rotation: float,phase: float,alpha: float,ascending: bool=false,floor_limit: float=INF) -> void:
	# A broken alley-oop trace curls behind the actual ball, with a separate
	# reverse seam pulse. No wide rubber sheet or second sphere is introduced.
	var turn:=phase*.68
	_rubber_band(canvas,at,radius,2.05+turn,4.54+turn,width,rotation,alpha,true,floor_limit)
	_rubber_band(canvas,at,radius*1.25,2.49+turn,3.92+turn,width*.45,rotation,alpha*.64,false,floor_limit)
	if ascending:
		_rubber_band(canvas,at-axis_from_angle(rotation)*width*.58,radius*.73,1.97+turn,3.96+turn,width*.31,rotation,alpha*.69,true,floor_limit)

static func axis_from_angle(angle: float) -> Vector2:
	return Vector2(cos(angle),sin(angle))

static func _bounce_marks(canvas: CanvasItem,at: Vector2,h: float,phase: float,alpha: float) -> void:
	# Flattened compression shapes read as successive court bounces. All three
	# remain floor paint, not round balls with an apparent independent hitbox.
	for n in range(3):
		var side:=float(n)-1.0
		var position:=at+Vector2(side*h*(.25+phase*.17),-h*.025)
		_rubber_band(canvas,position,Vector2(h*(.16+.04*(n%2)),h*.041),.10,PI-.10,h*.035,0,alpha*(.75 if n==1 else .38),true)

static func skin_slice_points(center: Vector2,radius: Vector2,begin: float,end: float,rotation: float=0.0) -> PackedVector2Array:
	var points:=PackedVector2Array()
	for pass_index in range(2):
		for index in range(17):
			var n:=index if pass_index==0 else 16-index
			var t:=float(n)/16.0;var angle:=lerpf(begin,end,t)
			var thickness:=.37+.18*sin(t*PI)
			var scale:=1.0 if pass_index==0 else 1.0-thickness
			points.append(center+Vector2(cos(angle)*radius.x,sin(angle)*radius.y).rotated(rotation)*scale)
	return points

static func _ball_skin_slice(canvas: CanvasItem,center: Vector2,radius: Vector2,begin: float,end: float,rotation: float,alpha: float) -> void:
	_rubber_band(canvas,center,radius,begin,end,minf(radius.x,radius.y)*.13,rotation,alpha,true)
	# Small stamped basketball panels remain below the head lane. Their
	# partial-disc silhouettes read as rubber chips, never additional balls.
	for t: float in [.27,.67]:
		var angle:=lerpf(begin,end,t)
		var at:=center+Vector2(cos(angle)*radius.x,sin(angle)*radius.y).rotated(rotation)
		_source()._draw_ball_panel(canvas,at,minf(radius.x,radius.y)*.19,angle+rotation,alpha*.81)

static func lower_skin_lane(s: Dictionary) -> Dictionary:
	var h:=float(s.get("height",90.0));var anchors: Dictionary=s.get("anchors",{})
	var ball_visible:=bool(s.get("ball_visible",anchors.has("ball")))
	var at:=_v(anchors.get("ball" if ball_visible else "hand"))
	var position:=_v(s.get("position",at+Vector2(0,h*.5)))
	if not at.is_finite() or not position.is_finite():return {"ready":false}
	var f:=float(s.get("facing",1));var slot:=str(s.get("slot","U"))
	var center:=Vector2(at.x+f*h*.10,maxf(at.y+h*.29,position.y-h*.19))
	return {"ready":false,"disabled_reason":"foreground_lane_has_no_actual_source_ball","center":center,"radius":Vector2(h*(.31 if slot=="WU" else .28),h*(.22 if slot=="WU" else .20)),"begin":.05,"end":PI-.09,"upper_bound":center.y,"owner_lower_body":position.y-h*.19,"decorative_skin_section":true,"actual_ball_spheres":0}

static func _net(canvas: CanvasItem,center: Vector2,radius: float,alpha: float,phase: float,front: bool=false) -> void:
	var ellipse:=Vector2(radius,radius*.27)
	var height:=radius*(.46+sin(phase*PI)*.10)
	var sway:=sin(phase*TAU*2.0)*radius*.07*(1.0-phase)
	if not front:
		_hoop_arc(canvas,center,ellipse,PI,TAU,radius*.13,alpha)
		for n in range(6):
			var u:=float(n)/5.0;var x:=lerpf(-radius*.88,radius*.88,u)
			var top:=center+Vector2(x,radius*.08)
			var bottom:=center+Vector2(x*.58+sway,radius*.15+height+sin(u*PI)*radius*.055)
			canvas.draw_line(top,bottom,Color(NET_EDGE,alpha*.97),maxf(2.8,radius*.033),true)
			canvas.draw_line(top,bottom,Color(NET,alpha),maxf(1.45,radius*.017),true)
			if n<5:
				var next_x:=lerpf(-radius*.88,radius*.88,float(n+1)/5)
				for row in range(2):
					var p:=.30+row*.29
					var other:=center+Vector2(next_x*lerpf(1,.58,p+.14)+sway*(p+.14),radius*.10+height*(p+.14)+sin((u+.2)*PI)*radius*.035)
					canvas.draw_line(top.lerp(bottom,p),other,Color(NET,alpha*.92),maxf(1.25,radius*.014),true)
	else:
		# Open the central sixty percent of the foreground hoop for the victim's
		# head and chest. The complete rear hoop / weave keeps the dunk readable.
		_hoop_arc(canvas,center,ellipse,.025,PI*.30,radius*.14,alpha*.34)
		_hoop_arc(canvas,center,ellipse,PI*.70,PI-.025,radius*.14,alpha*.34)

static func draw_actor(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:
	var g:=geometry(s)
	if not g.get("ready",false):return g
	g["frame_fx"]=FrameFX.draw_actor(canvas,s,layer)
	var h:=float(s.get("height",90.0));var tier:=int(s.get("tier",1));var f:=float(s.get("facing",1))
	var release: Dictionary=s.get("release_state",{});var slot:=str(s.get("slot","U"));var phase:=float(g.phase)
	var at: Vector2=g.origin;var axis: Vector2=g.axis;var rotation:=axis.angle()
	var r:=maxf(h*.14,float(g.ball_radius));var alpha:=.93*(1-.17*phase)
	var style:=amplification(s);var scale:=float(style.visual_scale)
	if layer=="front":
		# A short foreground rubber quarter-ring remains visible when a carried
		# downward ball and its rear fan are occluded by the chicken's own belly.
		# It has no complete sphere or opaque central plate over either fighter.
		if g.active and slot in ["AIR_U","AIR_I"]:
			_rubber_band(canvas,at+axis*h*.055,Vector2(r*1.65,r*1.26),-.68,.68,h*(.095 if tier==1 else .13),rotation,alpha*.86,tier>=2)
			_rubber_chips(canvas,at+axis*h*.11,h*.51,phase,alpha*.79,2,rotation)
		elif g.active and slot in ["U","WU"]:
			# Unowned lower skin is suppressed: the actual held ball and confirmed
			# contact already supply orange/seam cues without a strip over the shoes.
			var lane:=lower_skin_lane(s)
			if lane.ready:_ball_skin_slice(canvas,lane.center,lane.radius,float(lane.begin),float(lane.end),0.0,alpha*.88)
		return g
	if layer!="back":return g
	if not g.active:
		var prepare:=float(release.get("prepare",0))
		if prepare>0:
			var tension:=lerpf(.67,1.20,prepare)
			_rubber_band(canvas,at,Vector2(r*1.67,r*1.08)*tension,-2.5,-.4,h*.080,rotation,(.25 if tier==1 else .35)+prepare*.43,true)
			if tier==3:_court_dust(canvas,Vector2(s.position.x,float(s.get("floor",s.position.y))),h*.72,prepare,.42*prepare)
		elif release.get("recovering",false):
			var recovery:=float(release.get("recovery_phase",1))
			_rubber_chips(canvas,at,h*.52,recovery,pow(1-recovery,1.7)*.41,2,rotation)
		return g
	var radius:=Vector2(h*(.44 if tier==1 else .64),h*(.30 if tier==1 else .48))*scale
	var width:=h*(.14 if tier==1 else .20)*lerpf(1.0,scale,.66)
	var trail_floor:=float(s.get("floor",s.position.y))-h*.055
	match slot:
		"U":
			_ball_skin_slice(canvas,at-axis*h*.13,radius,2.05+phase*.34,4.59+phase*.34,rotation,alpha)
		"SU":
			_rubber_band(canvas,at,Vector2(radius.x,radius.y*.57),1.20,3.84,width*1.12,rotation,alpha)
			if s.get("grounded",false):
				var floor_at:=Vector2(at.x,float(s.get("floor",at.y)))
				_court_dust(canvas,floor_at,h*1.26,phase,alpha*.88)
				_bounce_marks(canvas,floor_at,h,phase,alpha)
		"WU":
			_ball_skin_slice(canvas,at-axis*h*.10,Vector2(radius.x*.87,radius.y*1.40),1.67+phase*.32,4.49+phase*.32,rotation,alpha)
			_rubber_chips(canvas,at,h*.98,phase,alpha*.78,3,rotation)
		"AIR_U":
			_rubber_band(canvas,at-axis*h*.10,Vector2(radius.x*.94,radius.y*1.25),2.00,4.15,width*1.08,rotation,alpha)
			_rubber_band(canvas,at-axis*h*.23,radius*.78,2.61,3.81,width*.33,rotation,alpha*.66,true)
			_rubber_chips(canvas,at,h*.87,phase,alpha*.76,3,rotation)
		"I":
			# The three projectile spheres belong to their source children only.
			var rank:=3 if float(s.get("frame",0))>=65 else (2 if float(s.get("frame",0))>=44 else 1)
			_rubber_band(canvas,at-axis*h*.13,radius*(.78+float(rank)*.17),2.08,4.20,width*(.70+float(rank)*.19),rotation,alpha,rank==3)
			_rubber_chips(canvas,at,h*(.60+float(rank)*.17),phase,alpha*.72,2+rank,rotation)
		"WI":
			_panel_spiral(canvas,at-axis*h*.12,Vector2(radius.x*.87,radius.y*1.39),width*1.12,rotation,phase,alpha,true,trail_floor)
		"SI":
			var cinema: Dictionary=s.get("cinema_phase",{})
			if cinema.get("stage","") in ["descent","impact"]:
				_panel_spiral(canvas,at-axis*h*.11,Vector2(radius.x*.88,radius.y*1.35),width*1.19,rotation,phase,alpha,true,trail_floor)
				# The large woven hoop is reserved for the actual cbs child/impact.
				_rubber_chips(canvas,at,h*1.33,phase,alpha*.84,5,rotation)
			else:
				_panel_spiral(canvas,at-axis*h*.1,Vector2(radius.x*.94,radius.y*1.23),width,rotation,phase,alpha,true,trail_floor)
		"AIR_I":
			_panel_spiral(canvas,at-axis*h*.12,Vector2(radius.x*1.11,radius.y*1.37),width*1.13,rotation,phase,alpha,true,trail_floor)
			_rubber_chips(canvas,at,h*1.21,phase,alpha*.84,4,rotation)
	return g

static func draw_object(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:
	if not s.get("ready",false) or str(s.get("id",""))!="chicken" or layer!="back":return {"ready":false}
	var box: Rect2=s.get("box",Rect2());var h:=float(s.get("height",90));var slot:=str(s.get("slot",""))
	var g: Dictionary=s.get("geometry",{});var c:=box.get_center()
	if s.get("normal_launcher",false):
		_source()._draw_normal_launcher(canvas,s)
		return {"ready":true,"body_copies":0,"normal_launcher_preserved":true}
	FrameFX.draw_object(canvas,s,layer)
	if slot=="SI":
		var source_frame:=float(s.get("frame",0))+float(s.get("source_clock",0))*30
		var phase:=clampf(source_frame/maxf(1,float(s.get("frame_count",1))-1),0,1)
		var active:=bool(s.get("active_regions",false));var alpha:=.91 if active else .39*(1-phase)
		var at:=Vector2(c.x,minf(box.end.y,float(s.get("floor",box.end.y)))-h*.30)
		var span:=clampf(box.size.x*.47,h*.38,h*1.38)
		# The cbs child has one actual hoop. Its last-hit frame supplies a new
		# contact-centered hoop, so the field fades to floor dust during that
		# authored terminal window rather than stacking two enormous hoops.
		if source_frame<31:_net(canvas,at,span,alpha,phase)
		if active:_court_dust(canvas,Vector2(c.x,float(s.get("floor",box.end.y))),h*1.46,phase,alpha*.74,true)
		return {"ready":true,"body_copies":0,"source_object":s.get("name",""),"motif":"source_cbs_dunk_net","confirmed_finishing_hit":false,"source_clock_mutated":false}
	# The original v0.26 rubber shader texture/seams draw exactly one actual ball.
	_source()._draw_ball(canvas,c,box,s)
	var radius:=float(g.get("radius",h*.15));var axis:=_v(g.get("axis",Vector2(float(s.get("facing",1)),0)))
	var final_ball:=bool(g.get("strong_projectile",false))
	if not s.get("bullet_hit",false):
		var wake_scale:=1.33 if final_ball else 1.19
		_rubber_band(canvas,c-axis*radius*.74,Vector2(radius*(2.21 if final_ball else 1.90),radius*1.32)*wake_scale,2.35,3.89,radius*(.55 if final_ball else .39),axis.angle(),.94,final_ball)
		if slot=="SU":
			var floor_at:=Vector2(c.x,float(s.get("floor",c.y)));var bounce:=fposmod(float(s.get("frame",0))*.06,1)
			_court_dust(canvas,floor_at,h*.76,bounce,.52)
			_bounce_marks(canvas,floor_at,h*.56,bounce,.71)
	return {"ready":true,"body_copies":0,"actual_ball_spheres":0 if s.get("bullet_hit",false) else 1,"source_object":s.get("name",""),"motif":"power_third_ball" if final_ball else "source_round_pass","strong_projectile":final_ball,"birth_source_absolute_frame":s.get("birth_source_absolute_frame",-1),"rubber_texture_preserved":true,"cut_lanes":[],"confirmed_finishing_hit":false,"source_clock_mutated":false}

static func _basketball_impact(canvas: CanvasItem,s: Dictionary) -> void:
	var at: Vector2=_v(s.get("pos"));var h:=float(s.get("height",90))
	var phase:=float(s.get("phase",0));var alpha:=float(s.get("alpha",1))
	var axis:=_v(s.get("attack_axis",Vector2(float(s.get("direction",1)),0)))
	if not axis.is_finite() or axis.length_squared()<.01:axis=Vector2.RIGHT
	axis=axis.normalized()
	var radius:=h*(.41 if s.get("finisher",false) else .26)*(1+phase*.42)
	# Real contact squashes rubber perpendicular to its arrival direction.
	# Keep it as an open seam-and-compression flash, never a pale full disc.
	_rubber_band(canvas,at,Vector2(radius*.55,radius),-.78,.76,h*.052,axis.angle(),alpha*.87,true)
	_rubber_band(canvas,at-axis*h*.035,Vector2(radius*.76,radius*.81),2.20,3.76,h*.034,axis.angle(),alpha*.66)
	if float(s.get("age",0))<.065:
		var core:=clampf(1-float(s.get("age",0))/.065,0,1)
		var side:=axis.orthogonal()
		var seam:=PackedVector2Array([at-side*h*.09-axis*h*.014,at-axis*h*.036,at+side*h*.09-axis*h*.014])
		canvas.draw_polyline(seam,Color(SEAM,alpha*core),maxf(1.7,h*.022),true)
		canvas.draw_line(at-axis*h*.083,at+axis*h*.052,Color(LIGHT,alpha*core),maxf(1.3,h*.018),true)

static func draw_contact(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:
	if not s.get("ready",false) or str(s.get("id",""))!="chicken":return {"ready":false}
	var at:=_v(s.get("pos"));var axis:=_v(s.get("attack_axis"))
	if not at.is_finite():return {"ready":false}
	if not axis.is_finite() or axis.length_squared()<.01:axis=Vector2(float(s.get("direction",1)),-.23)
	axis=axis.normalized()
	var outcome:=str(s.get("outcome","hit"));var final:=bool(s.get("finisher",false)) and outcome in ["hit","guard_break"]
	var h:=float(s.get("height",90));var tier:=int(s.get("tier",1));var phase:=float(s.get("phase",0));var alpha:=float(s.get("alpha",1))
	var meta: Dictionary={"ready":true,"body_copies":0,"source_clock_mutated":false,"contact_confirmed":outcome in ["hit","guard_break"],"finisher":final,"net_finish":false,"round_rubber":true,"cut_lanes":[]}
	meta["frame_fx"]=FrameFX.draw_contact(canvas,s,layer)
	if outcome in ["guard","blocked","armor","steel","counter","bullet_clash"]:
		if layer=="front":
			_rubber_band(canvas,at-axis*h*.045,Vector2(h*.14,h*.23),-.78,.78,h*.070,axis.angle(),alpha*.97,true)
			_rubber_chips(canvas,at,h*.42,phase,alpha*.83,2,axis.angle()+PI)
		return meta
	var basket:=final and str(s.get("contact_motif","")) in ["dunk_rim","alley_oop"]
	var reach:=h*(1.42 if final and tier==3 else (1.10 if final else .55))
	if layer=="back":
		if basket:
			_net(canvas,at+Vector2(0,-h*.13),reach*.77,alpha,phase)
			# The dunk's rubber compression and curved skin fragments also stay
			# behind the body after its brief true-contact nucleus; no pale face veil.
			_basketball_impact(canvas,s)
			meta.net_finish=true
		else:
			_rubber_band(canvas,at,Vector2(reach,reach*.69)*(.77+phase*.52),.28,2.67,h*(.235 if final else .12),axis.angle(),alpha*.92,final)
			_rubber_band(canvas,at,Vector2(reach*.83,reach*.58)*(1+phase*.34),3.25,5.3,h*(.18 if final else .083),axis.angle(),alpha*.86)
		_rubber_chips(canvas,at,h*(1.53 if final and tier==3 else (1.23 if final else .76)),phase,alpha,6 if final else 3,axis.angle())
		return meta
	if layer!="front":return meta
	if float(s.get("age",0))<.045:
		var core:=float(s.get("core_alpha",1))
		_ellipse(canvas,at,Vector2(h*.068,h*.14),RUBBER,core*.96,axis.angle())
		_ellipse(canvas,at-axis*h*.02,Vector2(h*.031,h*.081),CREAM,core*.94,axis.angle())
	if not basket:_basketball_impact(canvas,s)
	if basket:_net(canvas,at+Vector2(0,-h*.13),reach*.77,alpha*.81,phase,true);meta.net_finish=true
	if final and bool(s.get("ground_splash",false)):
		_court_dust(canvas,Vector2(at.x,float(s.get("floor_y",at.y))),h*(1.78 if tier==3 else 1.34),phase,alpha,tier==3)
	return meta
