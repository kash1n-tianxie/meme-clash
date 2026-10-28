extends RefCounted
const FrameFX=preload("res://game/bvn_frame_fx_v031.gd")
const CelPlanes=preload("res://game/fx_cel_planes_v037.gd")
## v0.37: crisp cel planes within the existing source-owned four-toe silhouette.
## The open foreground keeps the actual victim and confirmed hold readable.
const PINK := Color("ed6baf")
const PAD := Color("ffafd0")
const EDGE := Color("fff3d5")
const INK := Color("672d57")
const COOL := Color("a9e5f2")
const DUST := Color("caa18a")
const FUR := Color("ffe6c5")
const FUR_SHADE := Color("dca5a7")
const MOTIFS := {"U":"happy_paw_fan","SU":"low_dust_scratches","WU":"rising_paw_uppercut","AIR_U":"pouncing_paw_cone","I":"grab_bubble_paw_slam","WI":"shock_paw_column","SI":"rage_giant_claw_flurry","AIR_I":"falling_paw_meteor"}
const STYLE_PROFILES := {
	"U":[.58,.33,1.40,"fan_slap"],"SU":[.54,.46,1.37,"floor_rake"],
	"WU":[.67,.38,1.40,"uppercut"],"AIR_U":[.63,.37,1.42,"pounce"],
	"I":[.80,.49,1.60,"pursuit_then_hold"],"WI":[.91,.57,1.62,"startled_column"],
	"SI":[1.10,.62,1.72,"rage_flurry"],"AIR_I":[.97,.58,1.68,"meteor"]}

static func style_profile(slot: String) -> Dictionary:
	# Pure art dimensions, not attack reach. No time, collision or object state.
	if not STYLE_PROFILES.has(slot):return {"ready":false}
	var p: Array=STYLE_PROFILES[slot]
	return {"ready":true,"paw_radius_ratio":p[0],"wind_width_ratio":p[1],"max_wake_reach_ratio":p[2],"silhouette":p[3],"foreground_radius_ratio":.052,"body_copies":0,"creates_contact":false,"source_clock_mutated":false,"decorative_reach_only":true,"paw_count":1}

static func _point(value: Variant) -> Vector2:
	if value is Vector2:return value
	if value is Array and value.size()>=2:return Vector2(float(value[0]),float(value[1]))
	return Vector2(INF,INF)

static func _anchor(s: Dictionary,key: String) -> Vector2:return _point(s.get("anchors",{}).get(key))

static func geometry(s: Dictionary) -> Dictionary:
	if not s.get("ready",false) or str(s.get("id",""))!="cat":return {"ready":false}
	var paw:=_anchor(s,"paw_tip");var mouth:=_anchor(s,"mouth")
	if not paw.is_finite():return {"ready":false,"missing_anchor":true}
	var f:=float(s.get("facing",1));var h:=float(s.get("height",90.0));var slot:=str(s.get("slot",""))
	var direction:=Vector2(f,-.13).normalized()
	if slot in ["WU","WI"]:direction=Vector2(f*.28,-1).normalized()
	elif slot in ["SU","AIR_U","AIR_I"]:direction=Vector2(f*.42,1).normalized()
	elif slot=="SI":
		var frame:=float(s.get("frame",0))
		if frame>=138:direction=Vector2(f*.12,1).normalized()
		elif (frame>=67 and frame<76) or (frame>=84 and frame<95) or (frame>=105 and frame<114) or (frame>=122 and frame<138):direction=Vector2(f*.24,-1).normalized()
		elif (frame>=76 and frame<84) or (frame>=114 and frame<122):direction=Vector2(-f,-.12).normalized()
	elif slot=="I" and str(s.get("label",""))=="必杀_TF":direction=Vector2(f*.18,1).normalized()
	var bounds:=Rect2();var any_box:=false
	for value: Variant in s.get("boxes",[]):
		if value is Rect2 and value.has_area():bounds=bounds.merge(value) if any_box else value;any_box=true
	var release: Dictionary=s.get("release_state",{});var active:=bool(release.get("active",false))
	# Volume follows current HitVO, not a fabricated long-range projectile.
	var end:=paw+direction*h*(.50 if int(s.get("tier",1))==1 else .75)
	if any_box and active:
		var target:=bounds.get_center()
		if slot not in ["WU","WI","AIR_U","AIR_I","SI"]:target.x=bounds.end.x-h*.08 if f>0 else bounds.position.x+h*.08
		if target.distance_squared_to(paw)>h*h*.01:direction=(target-paw).normalized()
		end=target
	return {"ready":true,"origin":paw,"mouth":mouth,"mouth_visible":mouth.is_finite(),"direction":direction,"end":end,"collision_bounds":bounds,"has_collision_bounds":any_box,"active":active,"phase":clampf(float(release.get("phase",0)),0,1),"body_copies":0,"attached_to":"paw_tip","cut_lanes":3,"motif":MOTIFS.get(slot,"paw_energy"),"palette":"pink_pad_cream_claw_plum_shadow","solid_motif":true,"source_clock_mutated":false,"style":style_profile(slot),"creates_contact":false,"foreground_open":true}

static func amplification(s: Dictionary) -> Dictionary:
	return _amplification(s,geometry(s))

static func _amplification(s: Dictionary,g: Dictionary) -> Dictionary:
	var slot:=str(s.get("slot",""));var style: Dictionary=g.get("style",{})
	if not g.get("ready",false) or not style.get("ready",false):return {"ready":false}
	var h:=clampf(float(s.get("height",90)),32,180)
	return {"ready":true,"id":"cat","slot":slot,"tier":int(s.get("tier",1)),"motif":MOTIFS[slot],"body_copies":0,"changes_source":false,"creates_contact":false,"source_owned":true,"visual_scale":float(style.paw_radius_ratio)/.34,"extent":h*float(style.max_wake_reach_ratio),"paw_radius":h*float(style.paw_radius_ratio),"foreground_radius":h*float(style.foreground_radius_ratio),"decorative_only":true,"profile":style}

static func _curve(at: Vector2,direction: Vector2,length: float,bend: float,offset: float=0.0) -> PackedVector2Array:
	var side:=direction.orthogonal();var out:=PackedVector2Array()
	for n in range(13):
		var t:=float(n)/12.0;out.append(at+side*offset+direction*length*t+side*bend*sin(t*PI))
	return out

static func _stroke(canvas: CanvasItem,points: PackedVector2Array,width: float,color: Color,alpha: float) -> void:
	if points.size()<2 or alpha<=0:return
	var poly:=PackedVector2Array()
	# A fixed cross-axis makes this monotonically swept ribbon triangulable even
	# for a very short source region. No duplicate tip vertices or fractional
	# power of a negative floating-point sine at PI.
	var side: Vector2=(points[-1]-points[0]).normalized().orthogonal()
	poly.append(points[0])
	for index in range(1,points.size()-1):
		var t:=float(index)/float(points.size()-1);var shape:=pow(maxf(0,sin(t*PI)),.68)*width*.5
		poly.append(points[index]+side*shape)
	poly.append(points[-1])
	for index in range(points.size()-2,0,-1):
		var t:=float(index)/float(points.size()-1);var shape:=pow(maxf(0,sin(t*PI)),.68)*width*.5
		poly.append(points[index]-side*shape)
	canvas.draw_colored_polygon(poly,Color(color,alpha))

static func _ellipse(canvas: CanvasItem,at: Vector2,radii: Vector2,color: Color,alpha: float,rotation: float=0.0,edge: bool=false,fur: bool=false) -> void:
	if alpha<=.002 or radii.x<.1 or radii.y<.1:return
	# Preserve the exact outer paw/dust silhouette, with a single clean shadow
	# plane instead of a soft radial gradient. Both planes use one submission.
	var outline: PackedVector2Array=PackedVector2Array()
	for n in range(16):
		var angle: float=TAU*float(n)/16.0
		var rim: float=.975 if fur and n in [1,4,7,10,13] else 1.0
		outline.append(at+Vector2(cos(angle)*radii.x,sin(angle)*radii.y).rotated(rotation)*rim)
	var mesh: Dictionary=CelPlanes.split_convex(outline,at,maxf(radii.x,radii.y),Color(color,alpha),Color(color.lerp(INK,.24),alpha))
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),mesh.indices,mesh.points,mesh.colors)
	if edge:outline.append(outline[0]);canvas.draw_polyline(outline,Color(INK,alpha*.64),maxf(1.1,radii.x*.055),true)

static func _paw(canvas: CanvasItem,at: Vector2,radius: float,alpha: float,rotation: float=0.0,flatten: float=1.0) -> void:
	# One solid cream paw, pink pad and four substantial toes. This is a prop
	# silhouette, never a second cat body. Keep the old fixed draw budget.
	var r:=Vector2(radius,radius*flatten)
	_ellipse(canvas,at+Vector2(0,r.y*.26).rotated(rotation),Vector2(r.x*.64,r.y*.51),INK,alpha*.45,rotation)
	_ellipse(canvas,at+Vector2(0,r.y*.17).rotated(rotation),Vector2(r.x*.61,r.y*.49),FUR,alpha,rotation,true,true)
	_ellipse(canvas,at+Vector2(-r.x*.035,r.y*.23).rotated(rotation),Vector2(r.x*.35,r.y*.27),PINK,alpha,rotation)
	_ellipse(canvas,at+Vector2(-r.x*.115,r.y*.12).rotated(rotation),Vector2(r.x*.20,r.y*.085),PAD,alpha*.43,rotation-.12)
	for n in range(4):
		var angle:=-PI*.83+float(n)*PI*.22;var toe:=Vector2(cos(angle)*r.x*.69,sin(angle)*r.y*.63)
		var turn:=rotation+(float(n)-1.5)*.13
		_ellipse(canvas,at+(toe+Vector2(0,r.y*.055)).rotated(rotation),Vector2(r.x*.235,r.y*.29),FUR_SHADE,alpha*.59,turn)
		_ellipse(canvas,at+toe.rotated(rotation),Vector2(r.x*.22,r.y*.28),FUR,alpha,turn,true,true)
		_ellipse(canvas,at+(toe+Vector2(0,r.y*.055)).rotated(rotation),Vector2(r.x*.115,r.y*.13),PINK,alpha*.91,turn)
		# Cream claws are compact tapered triangles, distinct from the ribbons.
		var tip:=at+(toe+Vector2(0,-r.y*.19)).rotated(rotation)
		var nail:=PackedVector2Array([tip+Vector2(-r.x*.073,r.y*.065).rotated(turn),tip+Vector2(r.x*.073,r.y*.065).rotated(turn),tip+Vector2(r.x*.028,-r.y*.14).rotated(turn)])
		canvas.draw_colored_polygon(nail,Color(EDGE,alpha*.91))

static func _claw_fan(canvas: CanvasItem,at: Vector2,direction: Vector2,h: float,reach: float,phase: float,alpha: float,big: bool=false) -> void:
	var width:=h*(.23 if big else .16)
	# Filled tapered wind body gives the three cutting lanes actual volume.
	# The dark underside survives the brilliant cyan pool and cream stage floor.
	var wind:=_curve(at-direction*h*.08,direction,reach*(.82+phase*.18),h*.06)
	_stroke(canvas,wind,h*(.62 if big else .43),INK,alpha*.36)
	_stroke(canvas,wind,h*(.52 if big else .36),PAD,alpha*.41)
	for lane in range(3):
		var offset:=(float(lane)-1.0)*h*(.24 if big else .15)
		var points:=_curve(at,direction,reach*(.73+phase*.27),h*(.105 if big else .075),offset)
		_stroke(canvas,points,width*1.24,INK,alpha*.73);_stroke(canvas,points,width,PINK,alpha*.93);_stroke(canvas,points,width*.47,EDGE,alpha*.87)

static func _pounce_tail(canvas: CanvasItem,at: Vector2,axis: Vector2,h: float,reach: float,phase: float,alpha: float) -> void:
	# One fat pointed cream comet. No particle beam and no invented projectile.
	var side:=axis.orthogonal();var half:=h*.19*(1.0-phase*.28)
	var points:=PackedVector2Array([at-axis*reach*.68,at+side*half-axis*reach*.19,at+axis*reach*.40,at-side*half-axis*reach*.19])
	canvas.draw_colored_polygon(points,Color(INK,alpha*.59))
	for n in range(points.size()):points[n]=at+(points[n]-at)*.83
	canvas.draw_colored_polygon(points,Color(FUR,alpha*.67))

static func _burst(canvas: CanvasItem,at: Vector2,radius: float,alpha: float,rotation: float=0.0) -> void:
	var poly:=PackedVector2Array()
	for n in range(14):
		var angle:=TAU*float(n)/14.0+rotation;var length:=radius*(1.0 if n%2==0 else .42)
		poly.append(at+Vector2(cos(angle)*length,sin(angle)*length))
	canvas.draw_colored_polygon(poly,Color(INK,alpha*.8))
	for n in range(poly.size()):poly[n]=at+(poly[n]-at)*.82
	canvas.draw_colored_polygon(poly,Color(EDGE,alpha))

static func _dust(canvas: CanvasItem,at: Vector2,h: float,phase: float,alpha: float,facing: float) -> void:
	for n in range(5):
		var x:=float(n-2)*h*.12*(.7+phase*.8);var y:=-h*(.035+.055*float((n+1)%3))-phase*h*.08
		_ellipse(canvas,at+Vector2(x*facing,y),Vector2(h*(.075+.012*(n%2)),h*.045)*(1+phase*.3),DUST,alpha*.62,0,true)
		_ellipse(canvas,at+Vector2(x*facing-h*.018,y-h*.018),Vector2(h*.039,h*.014),EDGE,alpha*.5)

static func _shock(canvas: CanvasItem,at: Vector2,h: float,alpha: float,facing: float) -> void:
	var polygon:=PackedVector2Array([Vector2(-.05,-.20),Vector2(.05,-.20),Vector2(.035,.015),Vector2(-.035,.015)])
	for n in range(polygon.size()):polygon[n]=at+Vector2(polygon[n].x*facing,polygon[n].y)*h
	canvas.draw_colored_polygon(polygon,Color(EDGE,alpha))
	_ellipse(canvas,at+Vector2(0,h*.085),Vector2(h*.055,h*.049),PINK,alpha,0,true)

static func _bubbles(canvas: CanvasItem,at: Vector2,h: float,phase: float,alpha: float) -> void:
	for n in range(5):
		var angle:=float(n)*TAU/5.0+phase*1.6;var p:=at+Vector2(cos(angle),sin(angle))*h*(.37+phase*.17)
		var r:=h*(.040+.012*(n%3))
		_ellipse(canvas,p,Vector2(r,r),PAD,alpha*.31,0,true)
		_ellipse(canvas,p+Vector2(-r*.23,-r*.28),Vector2(r*.40,r*.26),EDGE,alpha*.76)

static func _fishbone(canvas: CanvasItem,at: Vector2,h: float,alpha: float,rotation: float) -> void:
	# Sparse cat-treat emblem, never a moving damage object.
	var axis:=Vector2(cos(rotation),sin(rotation));var side:=axis.orthogonal()
	canvas.draw_line(at-axis*h*.095,at+axis*h*.12,Color(INK,alpha),maxf(2,h*.031),true)
	canvas.draw_line(at-axis*h*.095,at+axis*h*.12,Color(EDGE,alpha),maxf(1,h*.015),true)
	for n in range(3):
		var base:=at+axis*h*(float(n)-1)*.050
		canvas.draw_line(base-side*h*.055,base+side*h*.055,Color(EDGE,alpha),maxf(1.5,h*.020),true)
	_ellipse(canvas,at+axis*h*.16,Vector2(h*.046,h*.032),EDGE,alpha,rotation,true)

static func draw_actor(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:
	var g:=geometry(s)
	if not g.get("ready",false):return g
	g["frame_fx"]=FrameFX.draw_actor(canvas,s,layer)
	var h:=clampf(float(s.get("height",90.0)),32,180);var tier:=int(s.get("tier",1));var f:=float(s.get("facing",1))
	var release: Dictionary=s.get("release_state",{});var paw: Vector2=g.origin;var axis: Vector2=g.direction
	var slot:=str(s.get("slot",""));var active:=bool(g.active);var phase:=float(g.phase)
	var boost:=_amplification(s,g)
	if not boost.get("ready",false):return g
	var style: Dictionary=boost.profile
	g["amplification"]=boost
	if not active:
		if layer!="back":return g
		var prepare:=float(release.get("prepare",0))
		if prepare>0:
			_paw(canvas,paw+Vector2(f*h*.20,-h*.16),h*(.14+.14*prepare)*(.88 if tier==1 else 1.14),.15+.34*prepare,f*.22)
			if slot in ["WI","SI"] and prepare>.52:_shock(canvas,paw+Vector2(-f*h*.10,-h*.25),h*.64,prepare*.76,f)
		elif release.get("recovering",false):
			var fade:=pow(1-float(release.get("recovery_phase",1)),1.5)*.4
			for n in range(2):_ellipse(canvas,paw+Vector2(f*h*(.10+.12*n),-h*(.02+.04*n)),Vector2(h*.028,h*.04),PAD,fade)
		return g
	var alpha:=.91*(1.0-.20*phase)
	if layer=="front":
		# Large shapes sit behind the one actual cat silhouette.
		_ellipse(canvas,paw,Vector2(h*.052,h*.031),EDGE,.79*(1-phase*.6),axis.angle());return g
	if layer!="back":return g
	var end: Vector2=g.end;var reach:=clampf(paw.distance_to(end),h*.32,h*float(style.max_wake_reach_ratio))
	var stamp_at:=paw+axis*reach*(.77+.16*phase);var stamp_radius:=h*float(style.paw_radius_ratio)*(.89+.11*sin(phase*PI))
	if g.has_collision_bounds:
		var bounds: Rect2=g.collision_bounds;stamp_at=bounds.get_center().lerp(stamp_at,.35)
		# Broader decoration extends outside a narrow HitVO, while the actual
		# attack endpoint remains the source region. Never enlarge collisions.
		stamp_at+=axis.orthogonal()*h*(.08 if slot in ["I","SI"] else 0.0)
	match slot:
		"SU":
			_claw_fan(canvas,paw,Vector2(f,.14).normalized(),h,reach,phase,alpha)
			_dust(canvas,Vector2(stamp_at.x,float(s.get("floor",stamp_at.y))),h*1.20,phase,alpha,f)
			_paw(canvas,Vector2(stamp_at.x,minf(stamp_at.y,float(s.get("floor",stamp_at.y))-h*.10)),stamp_radius,alpha*.88,PI*.50*f,.47)
		"WU","WI":
			_claw_fan(canvas,paw-axis*h*.11,axis,h,reach+h*.19,phase,alpha,tier>=2)
			_paw(canvas,stamp_at,stamp_radius,alpha,axis.angle()+PI*.5)
			if slot=="WI":_burst(canvas,stamp_at-axis*h*.31,h*.40,alpha*.49,phase*.4);_shock(canvas,stamp_at+Vector2(f*h*.44,-h*.31),h*.92,alpha*.90,f)
		"AIR_U","AIR_I":
			_pounce_tail(canvas,stamp_at,axis,h*(1.27 if slot=="AIR_I" else 1),reach,phase,alpha)
			_paw(canvas,stamp_at,stamp_radius,alpha,axis.angle()+PI*.5)
			if slot=="AIR_I":_bubbles(canvas,stamp_at,h*1.18,phase,alpha*.75)
		"I":
			var cinema: Dictionary=s.get("cinema_phase",{})
			var pursuit:=str(cinema.get("stage",""))=="pursuit"
			_claw_fan(canvas,paw,axis,h,reach,phase,alpha,true)
			# The source first uppercuts, then chases. A bigger paw is decoration;
			# bubbles/embrace accents begin only after the actual capture branch.
			_paw(canvas,stamp_at+axis.orthogonal()*h*.20,stamp_radius*(.85 if pursuit else 1),alpha*.90,axis.angle()+PI*.5)
			if pursuit:_shock(canvas,stamp_at+Vector2(-f*h*.36,-h*.31),h*.77,alpha*.80,f)
			elif str(s.get("label","")) in ["必杀_HIT","必杀_L","必杀_TF"]:_bubbles(canvas,stamp_at,h*1.26,phase,alpha*.85);_fishbone(canvas,stamp_at+axis.orthogonal()*h*.64,h*.95,alpha*.72,float(s.get("frame",0))*.04)
		"SI":
			_claw_fan(canvas,paw,axis,h,reach,phase,alpha,true);_paw(canvas,stamp_at,stamp_radius,alpha,axis.angle()+PI*.5)
			if float(s.get("frame",0))<138:
				# The spiked burst on top of the palm made its soft pad look cut
				# into hard facets. Two smaller soft fills retain this source accent
				# window and command count, inside the original burst's envelope.
				var relief_at: Vector2=stamp_at-axis*h*.19
				_ellipse(canvas,relief_at,Vector2(h*.36,h*.23),PINK,alpha*.24,axis.angle())
				_ellipse(canvas,relief_at-axis*h*.035,Vector2(h*.24,h*.14),PAD,alpha*.19,axis.angle())
				_shock(canvas,paw-axis*h*.13+axis.orthogonal()*h*.46,h*.87,alpha*.68,f)
		"U":
			_claw_fan(canvas,paw,axis,h,reach,phase,alpha);_paw(canvas,stamp_at,stamp_radius,alpha*.91,axis.angle()+PI*.5)
			_ellipse(canvas,stamp_at-axis*h*.14-axis.orthogonal()*h*.25,Vector2(h*.055,h*.037),PAD,alpha*.61,-.2)
	return g

static func draw_contact(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:
	if not s.get("ready",false) or str(s.get("id",""))!="cat":return {"ready":false}
	var at:=_point(s.get("pos"))
	if not at.is_finite():return {"ready":false}
	var h:=float(s.get("height",90.0));var p:=float(s.get("phase",0));var a:=float(s.get("alpha",1))
	var slot:=str(s.get("slot","U"));var tier:=int(s.get("tier",1));var outcome:=str(s.get("outcome","hit"))
	var confirmed:=outcome in ["hit","guard_break"];var final:=bool(s.get("finisher",false)) and confirmed
	var axis:=_point(s.get("attack_axis"))
	if not axis.is_finite() or axis.length_squared()<.01:axis=Vector2(float(s.get("direction",1)),-.32)
	axis=axis.normalized()
	var meta: Dictionary={"ready":true,"body_copies":0,"finisher":final,"motif":MOTIFS.get(slot,"paw_energy"),"solid_motif":true,"contact_confirmed":confirmed,"ground_stamp":false}
	meta["frame_fx"]=FrameFX.draw_contact(canvas,s,layer)
	if not confirmed:
		if layer=="front":_ellipse(canvas,at,Vector2(h*.085,h*.18),COOL,a*.35,axis.angle(),true);_paw(canvas,at-axis*h*.11,h*.12,a*.69,axis.angle()+PI*.5,.58)
		return meta
	if layer=="back":
		var size:=h*(.85 if final and tier==3 else (.65 if final else .32))
		_burst(canvas,at,size*(.85+p*.72),a*(.51 if final else .34),axis.angle())
		var reach:=h*(1.28 if final else (.72 if tier>=2 else .56))
		_claw_fan(canvas,at-axis*reach*.40,axis,h,reach,p,a,final)
		# Full palm stays behind both bodies. Its four toe beans extend past the
		# collision silhouette; the actual victim's face remains on top.
		_paw(canvas,at-axis*h*.16+axis.orthogonal()*h*.27,h*(.91 if final and tier==3 else (.72 if final else .39))*(1+p*.21),a*(.87 if final else .73),axis.angle()+PI*.5)
		if final:_bubbles(canvas,at,h*(1.52 if tier==3 else 1.17),p,a*.78)
		return meta
	if layer!="front":return meta
	# Small leading shavings provide foreground depth without a solid palm
	# hiding the reaction. Big pad/cloud material was painted behind the body.
	for n in range(2):
		var chip:=at+axis*h*(.16+.14*n)+axis.orthogonal()*h*(.16 if n==0 else -.16)
		_ellipse(canvas,chip,Vector2(h*.05,h*.023),EDGE,a*.82,axis.angle())
	if float(s.get("age",0))<.045:_ellipse(canvas,at,Vector2(h*.052,h*.028),EDGE,float(s.get("core_alpha",1))*.87,axis.angle())
	if final and bool(s.get("ground_splash",false)):
		var floor_at:=Vector2(at.x,float(s.get("floor_y",at.y)))
		_paw(canvas,floor_at+Vector2(0,-h*.028),h*(.70 if tier==3 else .52)*(1+p*.25),a*.69,0,.32)
		_dust(canvas,floor_at,h*(1.35 if tier==3 else 1),p,a,float(s.get("direction",1)));meta.ground_stamp=true
	if final and slot in ["I","SI","AIR_I"]:_fishbone(canvas,at+axis.orthogonal()*h*.48+axis*h*.23,h*(1 if tier==3 else .74),a*.75,axis.angle()+p*.6)
	return meta

static func draw_object(_canvas: CanvasItem,s: Dictionary,_layer: String) -> Dictionary:
	# No cat source binding spawns a projectile; artwork does not invent one.
	return {"ready":false,"body_copies":0,"source_has_projectile":false,"source_object":s.get("name","")}
