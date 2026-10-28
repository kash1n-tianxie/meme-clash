extends RefCounted
const FrameFX=preload("res://game/bvn_frame_fx_v031.gd")
## v0.32 lit office props and folding paper: every shape uses a real source
## action / child / accepted contact. No clocks, actors or hitboxes are created.
const INK := Color("25394f")
const RED := Color("ec344d")
const RED_DARK := Color("982f46")
const BLUE := Color("4396ba")
const BLUE_DARK := Color("28536c")
const GOLD := Color("f2bb66")
const PAPER := Color("fff6de")
const PAPER_SHADE := Color("c9d0c9")
const WOOD := Color("ac6948")
const STAMP_FONT := preload("res://assets/fonts/NotoSansJP.ttf")
const MOTIFS := {"U":"briefcase_document_sweep","SU":"low_stamp_break","WU":"rising_document_tornado","AIR_U":"air_briefcase_paper_fan","I":"document_stack_approval_stamp","WI":"clock_delivery_chain","SI":"overtime_cyclone_clockout_stamp","AIR_I":"heavy_briefcase_drop"}
const STYLE_PROFILES := {
	"U":[1.54,.29,.31,"briefcase_fan"],"SU":[1.52,.39,.34,"low_giant_stamp"],
	"WU":[1.46,.34,.26,"paper_helix"],"AIR_U":[1.55,.31,.37,"aircase"],
	"I":[1.55,.70,.33,"approval_stack"],"WI":[1.62,.57,.42,"delivery_clock"],
	"SI":[1.70,.83,.64,"clockout_cyclone"],"AIR_I":[1.65,.48,.56,"heavy_case"]}

static func style_profile(slot: String) -> Dictionary:
	if not STYLE_PROFILES.has(slot):return {"ready":false}
	var p: Array=STYLE_PROFILES[slot]
	return {"ready":true,"gain":p[0],"stamp_ratio":p[1],"prop_ratio":p[2],"silhouette":p[3],"foreground_sheet_budget":3,"foreground_open":true,"decorative_only":true,"changes_source":false}

static func amplification(s: Dictionary) -> Dictionary:
	return _amplification(s,actor_geometry(s))

static func _amplification(s: Dictionary,g: Dictionary) -> Dictionary:
	var slot:=str(s.get("slot",""));var style: Dictionary=g.get("style",{})
	if not g.get("ready",false) or not style.get("ready",false):return {"ready":false}
	var h:=clampf(float(s.get("height",90)),32,180)
	return {"ready":true,"id":"worker","slot":slot,"tier":int(s.get("tier",1)),"motif":MOTIFS[slot],"body_copies":0,"changes_source":false,"creates_contact":false,"source_owned":true,"visual_scale":float(style.gain),"extent":h*(1.95 if slot=="SI" else 1.48),"decorative_only":true,"profile":style}

static func _v(value: Variant, fallback := Vector2.ZERO) -> Vector2:
	if value is Vector2:return value
	if value is Array and value.size()>=2:return Vector2(float(value[0]),float(value[1]))
	return fallback

static func _anchor(s: Dictionary,key: String) -> Vector2:
	return _v(s.get("anchors",{}).get(key,s.get("position",Vector2.ZERO)))

static func _line(canvas: CanvasItem,points: PackedVector2Array,color: Color,width: float,alpha: float) -> void:
	if alpha>.001 and points.size()>1:canvas.draw_polyline(points,Color(color,clampf(alpha,0,1)),maxf(.8,width),true)

static func _poly(canvas: CanvasItem,points: PackedVector2Array,color: Color,alpha: float,edge: float=0.0,relief: bool=false) -> void:
	if points.size()<3 or alpha<=.001:return
	var lower:=points[0];var upper:=points[0]
	for point: Vector2 in points:lower=lower.min(point);upper=upper.max(point)
	var colors: PackedColorArray=PackedColorArray()
	for point: Vector2 in points:
		var up: float=1.0-(point.y-lower.y)/maxf(1.0,upper.y-lower.y)
		var lateral: float=1.0-(point.x-lower.x)/maxf(1.0,upper.x-lower.x)
		var paint: Color=color.lerp(PAPER,up*(.12 if relief else .085)).lerp(INK,(1.0-up)*(.19 if relief else .14))
		if relief:paint=paint.lerp(PAPER,lateral*.07)
		colors.append(Color(paint,clampf(alpha,0,1)))
	if relief:
		var center: Vector2=Vector2.ZERO
		for point: Vector2 in points:center+=point
		center/=float(points.size())
		var surface: PackedVector2Array=PackedVector2Array([center]);surface.append_array(points)
		var surface_colors: PackedColorArray=PackedColorArray([Color(color.lerp(PAPER,.15),clampf(alpha,0.0,1.0))]);surface_colors.append_array(colors)
		var indices: PackedInt32Array=PackedInt32Array()
		for n in range(points.size()):indices.append_array(PackedInt32Array([0,n+1,((n+1)%points.size())+1]))
		RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),indices,surface,surface_colors)
	else:canvas.draw_polygon(points,colors)
	if edge>0:
		var outline:=points.duplicate();outline.append(outline[0]);_line(canvas,outline,INK,edge,alpha*.86)

static func _ellipse(canvas: CanvasItem,p: Vector2,radii: Vector2,color: Color,alpha: float,rotation: float=0.0,edge: float=0.0) -> void:
	var points: PackedVector2Array=PackedVector2Array([p+Vector2(-radii.x*.12,-radii.y*.16).rotated(rotation)])
	var outline: PackedVector2Array=PackedVector2Array()
	var colors: PackedColorArray=PackedColorArray([Color(color.lerp(PAPER,.19),clampf(alpha,0.0,1.0))])
	var indices: PackedInt32Array=PackedInt32Array()
	for n in range(20):
		var angle: float=float(n)*TAU/20.0
		var point: Vector2=p+Vector2(cos(angle)*radii.x,sin(angle)*radii.y).rotated(rotation)
		points.append(point);outline.append(point)
		var light: float=clampf(.46-.22*cos(angle+rotation)-.31*sin(angle+rotation),0.0,1.0)
		colors.append(Color(color.lerp(PAPER,light*.21).lerp(INK,(1.0-light)*.26),clampf(alpha,0.0,1.0)))
		indices.append_array(PackedInt32Array([0,n+1,((n+1)%20)+1]))
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),indices,points,colors)
	if edge>0.0:outline.append(outline[0]);_line(canvas,outline,INK,edge,alpha*.86)

static func _page(canvas: CanvasItem,p: Vector2,size: float,rotation: float,alpha: float,stamp := false) -> void:
	# Folded corner + substantial dark underside keep paper readable in the pool.
	var x:=Vector2.RIGHT.rotated(rotation);var y:=x.orthogonal()
	# Side-on sheets narrow and show their underside instead of keeping the
	# same face-on rectangle while orbiting through every depth of the helix.
	var w:=size*.66*(.69+.31*absf(cos(rotation*1.7)));var h:=size*.88
	var points:=PackedVector2Array([p-x*w-y*h,p+x*w*.62-y*h,p+x*w-y*h*.65,p+x*w+y*h,p-x*w+y*h])
	var shadow:=PackedVector2Array()
	for point in points:shadow.append(point+x*size*.09+y*size*.10)
	_poly(canvas,shadow,BLUE_DARK,alpha*.42)
	_poly(canvas,points,PAPER.lerp(PAPER_SHADE,maxf(0.0,sin(rotation))*.24),alpha,maxf(.85,size*.045),true)
	_poly(canvas,PackedVector2Array([p+x*w*.62-y*h,p+x*w*.62-y*h*.65,p+x*w-y*h*.65]),PAPER_SHADE,alpha)
	_line(canvas,PackedVector2Array([p-x*w*.65-y*h*.40,p+x*w*.35-y*h*.40]),BLUE,maxf(1,size*.07),alpha*.9)
	for n in range(2):
		var q:=p+y*h*(float(n)*.29-.04)
		_line(canvas,PackedVector2Array([q-x*w*.63,q+x*w*.40]),INK,maxf(.8,size*.055),alpha*.6)
	if stamp:_seal(canvas,p+y*h*.40,size*.21,alpha*.9,rotation)

static func _seal(canvas: CanvasItem,p: Vector2,size: float,alpha: float,rotation := 0.0,text := "済") -> void:
	# Real Japanese lettering + open ink corners. No fake glyph, solid red
	# gift-shaped plate or filled rectangle is laid over the victim's body.
	var x:=Vector2.RIGHT.rotated(rotation);var y:=x.orthogonal()
	for side_x: float in [-1.0,1.0]:
		for side_y: float in [-1.0,1.0]:
			var corner:=p+x*size*side_x+y*size*.72*side_y
			var bracket:=PackedVector2Array([corner-x*size*.32*side_x,corner,corner-y*size*.28*side_y])
			_line(canvas,bracket,PAPER,maxf(1.3,size*.18),alpha*.88)
			_line(canvas,bracket,RED_DARK,maxf(1.0,size*.13),alpha)
			_line(canvas,bracket,RED,maxf(.8,size*.09),alpha)
	var font_size:=maxi(3,int(size*(1.02 if text.length()>1 else 1.04)))
	var text_size:=STAMP_FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	# Lettering stays upright for instant recognition; the rubber edge can tilt
	# with impact. Coordinates stay in the caller's current world draw basis.
	var baseline:=p+Vector2(-text_size.x*.5,(STAMP_FONT.get_ascent(font_size)-STAMP_FONT.get_descent(font_size))*.5)
	canvas.draw_string_outline(STAMP_FONT,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,maxi(1,int(size*.14)),Color(PAPER,alpha))
	canvas.draw_string(STAMP_FONT,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(RED_DARK,alpha))
	canvas.draw_string(STAMP_FONT,baseline+Vector2(-size*.008,-size*.012),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(RED,alpha))

static func _stamp(canvas: CanvasItem,p: Vector2,size: float,alpha: float,rotation := 0.0) -> void:
	# Solid red rubber base, bevel, collar and wooden mushroom handle.
	var x:=Vector2.RIGHT.rotated(rotation);var y:=x.orthogonal()
	_poly(canvas,PackedVector2Array([p-x*size-y*size*.19,p+x*size-y*size*.19,p+x*size+y*size*.30,p-x*size+y*size*.30]),RED_DARK,alpha,maxf(1.5,size*.085))
	_poly(canvas,PackedVector2Array([p-x*size-y*size*.19,p+x*size-y*size*.19,p+x*size*.88-y*size*.37,p-x*size*.86-y*size*.37]),RED,alpha)
	_line(canvas,PackedVector2Array([p-x*size*.82-y*size*.24,p+x*size*.77-y*size*.24]),PAPER,maxf(1.1,size*.075),alpha*.75)
	_poly(canvas,PackedVector2Array([p-x*size*.22-y*size*.30,p+x*size*.22-y*size*.30,p+x*size*.17-y*size*.75,p-x*size*.17-y*size*.75]),WOOD,alpha,maxf(1.0,size*.07))
	_ellipse(canvas,p-y*size*.78,Vector2(size*.42,size*.21),WOOD,alpha,rotation,maxf(1.4,size*.075))
	_ellipse(canvas,p-y*size*.85-x*size*.04,Vector2(size*.29,size*.08),GOLD,alpha*.85,rotation)

static func _briefcase(canvas: CanvasItem,p: Vector2,size: float,alpha: float,rotation := 0.0) -> void:
	# A thick rounded document case with visible handle, leather side and latch.
	# This single prop is anchored to the existing measured bag, never an actor.
	var x:=Vector2.RIGHT.rotated(rotation);var y:=x.orthogonal()
	var face:=PackedVector2Array([p-x*size*.86-y*size*.53,p+x*size*.86-y*size*.53,p+x*size-y*size*.37,p+x*size+y*size*.57,p-x*size+y*size*.57,p-x*size-y*size*.37])
	var shadow:=PackedVector2Array()
	for point in face:shadow.append(point+x*size*.12+y*size*.10)
	_poly(canvas,shadow,INK,alpha*.89)
	_poly(canvas,face,BLUE_DARK,alpha,maxf(1.4,size*.095))
	_line(canvas,PackedVector2Array([p-x*size*.76-y*size*.22,p+x*size*.77-y*size*.22]),BLUE,maxf(1.3,size*.11),alpha*.96)
	_line(canvas,PackedVector2Array([p-x*size*.30-y*size*.53,p-x*size*.27-y*size*.85,p+x*size*.26-y*size*.85,p+x*size*.30-y*size*.53]),INK,maxf(2,size*.15),alpha)
	_poly(canvas,PackedVector2Array([p-x*size*.12-y*size*.24,p+x*size*.12-y*size*.24,p+x*size*.10+y*size*.07,p-x*size*.10+y*size*.07]),GOLD,alpha)
	_line(canvas,PackedVector2Array([p-x*size*.77+y*size*.38,p+x*size*.77+y*size*.38]),PAPER_SHADE,maxf(.9,size*.04),alpha*.66)

static func _stack(canvas: CanvasItem,p: Vector2,width: float,height: float,phase: float,alpha: float) -> void:
	# Three visibly thick layers replace a cloud of tiny identical rectangles.
	# Their extremities are derived from the existing child's physical area.
	for n in range(3):
		var sway:=sin(phase*TAU+float(n)*.8)*width*.10
		var center:=p+Vector2(sway,(float(n)-1.0)*height*.29)
		var points:=PackedVector2Array([center+Vector2(-width*.47,-height*.095),center+Vector2(width*.42,-height*.13),center+Vector2(width*.50,height*.035),center+Vector2(-width*.39,height*.13)])
		var shadow:=PackedVector2Array()
		for point in points:shadow.append(point+Vector2(width*.035,height*.035))
		_poly(canvas,shadow,BLUE_DARK,alpha*.67)
		_poly(canvas,points,PAPER,alpha,maxf(1.1,width*.012),true)
		_line(canvas,PackedVector2Array([center+Vector2(-width*.33,height*.040),center+Vector2(width*.37,-height*.026)]),PAPER_SHADE,maxf(1,height*.018),alpha)

static func _clock(canvas: CanvasItem,p: Vector2,radius: float,source_frame: float,alpha: float) -> void:
	_ellipse(canvas,p+Vector2(radius*.04,radius*.065),Vector2.ONE*radius*1.10,INK,alpha*.82)
	_ellipse(canvas,p,Vector2.ONE*radius,BLUE,alpha)
	_ellipse(canvas,p,Vector2.ONE*radius*.84,PAPER,alpha)
	# Two short relief arcs make rim thickness and the inset dial visible at
	# battle resolution. Both remain inside the original casing radius.
	var bevel: PackedVector2Array=PackedVector2Array()
	var inset: PackedVector2Array=PackedVector2Array()
	for n in range(11):
		var u: float=float(n)/10.0
		bevel.append(p+Vector2.RIGHT.rotated(lerpf(PI*.92,PI*1.72,u))*radius*.93)
		inset.append(p+Vector2.RIGHT.rotated(lerpf(PI*.04,PI*.78,u))*radius*.855)
	_line(canvas,bevel,PAPER.lerp(BLUE,.29),maxf(1.1,radius*.036),alpha*.84)
	_line(canvas,inset,BLUE_DARK,maxf(.8,radius*.020),alpha*.48)
	for n in range(12):
		var direction:=Vector2.RIGHT.rotated(float(n)*TAU/12.0)
		_line(canvas,PackedVector2Array([p+direction*radius*.67,p+direction*radius*.78]),INK,maxf(1.1,radius*.055),alpha*.85)
	var hand:=Vector2.UP.rotated(source_frame*.030)
	_line(canvas,PackedVector2Array([p,p+hand*radius*.64]),RED,maxf(1.8,radius*.087),alpha)
	_line(canvas,PackedVector2Array([p,p+Vector2.UP.rotated(-.7)*radius*.40]),INK,maxf(1.6,radius*.074),alpha)
	_ellipse(canvas,p,Vector2.ONE*radius*.095,RED_DARK,alpha)
	# A broad translucent reflection reads as curved glass, not a white sticker.
	# It remains inside the same dial; hands retain their exact source rotation.
	_ellipse(canvas,p-Vector2(radius*.21,radius*.33),Vector2(radius*.40,radius*.16),Color.WHITE,alpha*.19,-.60)

static func _paper_fan(canvas: CanvasItem,origin: Vector2,end: Vector2,h: float,phase: float,alpha: float,big := false) -> void:
	var travel:=end-origin
	if travel.length_squared()<4:travel=Vector2(h*.65,0)
	var direction:=travel.normalized();var side:=direction.orthogonal()
	var width:=h*(.44 if big else .32)
	# Actual paper silhouettes replace the old translucent tapered energy lane.
	# A folded, outlined leading form and overlapping trailing pages remain
	# readable at first release, even when the target stands over the caster.
	# Larger readable pages with fewer ink/text calls than the old confetti.
	var count:=6 if big else 5
	for n in range(count):
		var u:=fposmod(float(n)/float(count)+phase*.26,1.0)
		var q:=origin+travel*(.07+u*.90)+side*sin(u*PI)*width*(.60 if n%2==0 else -.56)
		_page(canvas,q,h*(.195 if big else .166),direction.angle()+.42+sin(float(n)+phase*2.0)*.38,alpha,n==count-1)
	_page(canvas,end-direction*h*.075,h*(.265 if big else .22),direction.angle()-.24,alpha,true)

static func _burst(canvas: CanvasItem,p: Vector2,radius: float,alpha: float,rotation := 0.0) -> void:
	var poly:=PackedVector2Array()
	for n in range(16):
		var a:=float(n)*TAU/16.0+rotation
		poly.append(p+Vector2(cos(a),sin(a))*radius*(1.0 if n%2==0 else .40))
	_poly(canvas,poly,INK,alpha*.87)
	for n in range(poly.size()):poly[n]=p+(poly[n]-p)*.88
	_poly(canvas,poly,GOLD,alpha*.90)
	for n in range(poly.size()):poly[n]=p+(poly[n]-p)*.66
	_poly(canvas,poly,PAPER,alpha)

static func _ink_splash(canvas: CanvasItem,p: Vector2,h: float,phase: float,alpha: float,red := true) -> void:
	var color:=RED if red else BLUE
	for n in range(8):
		var angle:=float(n)*2.399+.30
		var direction:=Vector2(cos(angle),sin(angle)*.42)
		var center:=p+direction*h*(.11+phase*.44)
		_ellipse(canvas,center,Vector2(h*(.042+.008*(n%3)),h*.023)*(1+phase*.28),color,alpha*.9,angle,maxf(.8,h*.009))

static func actor_geometry(s: Dictionary) -> Dictionary:
	var missing: Array=[]
	for key: String in ["hand","briefcase"]:
		if not s.get("anchors",{}).has(key) or not _anchor(s,key).is_finite():missing.append(key)
	var slot:=str(s.get("slot",""));var release: Dictionary=s.get("release_state",{})
	return {"ready":s.get("ready",false) and str(s.get("id","worker"))=="worker" and missing.is_empty(),"motif":MOTIFS.get(slot,"office_material"),"body_copies":0,"missing":missing,"source_clock_mutated":false,"generic_energy_orbs":0,"solid_material":true,"active":release.get("active",false),"measured_attachment":"briefcase","foreground_open":true,"style":style_profile(slot)}

static func draw_actor(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:
	var g:=actor_geometry(s)
	if not g.ready:return g
	g["frame_fx"]=FrameFX.draw_actor(canvas,s,layer)
	var h:=clampf(float(s.get("height",90.0)),32,180);var f:=float(s.get("facing",1))
	var t:=float(s.get("frame",0))+float(s.get("source_clock",0))*30.0
	var slot:=str(s.get("slot",""));var tier:=int(s.get("tier",1))
	var hand:=_anchor(s,"hand");var bag:=_anchor(s,"briefcase")
	var paper:=_anchor(s,"paper_origin") if s.get("anchors",{}).has("paper_origin") else hand
	var p:=_v(s.get("position",Vector2.ZERO));var release: Dictionary=s.get("release_state",{})
	var active:=bool(release.get("active",false));var phase:=float(release.get("phase",0))
	var boost:=_amplification(s,g)
	if not boost.get("ready",false):return g
	var style: Dictionary=boost.profile
	g["amplification"]=boost
	if layer=="front":
		# Only a small material glint crosses the body. Full volume is behind both
		# fighters, so heavy office motifs never erase a face or the contact pose.
		if active and slot in ["U","SU","AIR_U","AIR_I"]:_ellipse(canvas,bag,Vector2(h*.075,h*.023),PAPER,.83,f*.38)
		if active and slot in ["U","AIR_U"]:
			# The two compact bag sweeps can sit entirely behind a close opponent.
			# Their paper wake crosses the lower contact region in the front pass;
			# it contains no character drawing and does not cover the target's face.
			var visible_boxes: Array=s.get("boxes",[])
			if not visible_boxes.is_empty():
				var visible_box: Rect2=visible_boxes[0]
				var visible_end:=Vector2(visible_box.end.x if f>0 else visible_box.position.x,visible_box.get_center().y)
				if slot=="AIR_U":visible_end=visible_box.get_center()+Vector2(f*h*.14,h*.18)
				# Three loose sheets sit below the contact chest. Full fan/solid
				# case remains behind both bodies, leaving their hands and faces free.
				var flight:=visible_end-bag
				for n in range(int(style.foreground_sheet_budget)):
					var u:=.40+float(n)*.24
					_page(canvas,bag+flight*u+Vector2(0,h*.23),h*.088,(-.5+float(n)*.37)*f,.88,n==2)
		return g
	if layer!="back":return g
	if not active:
		var prepare:=float(release.get("prepare",0))
		if prepare>0:
			if tier>=2:_clock(canvas,p+Vector2(-f*h*.72,-h*.68),h*(.22+.15*prepare),t,.25+prepare*.38)
			elif slot in ["U","AIR_U"]:_page(canvas,bag+Vector2(f*h*.18,-h*.17),h*(.095+.08*prepare),-f*.27,.23+.36*prepare,false)
			if slot=="SI":
				for n in range(4):
					var a:=float(n)*TAU/4.0+t*.04
					_page(canvas,p+Vector2(cos(a)*h*.69,sin(a)*h*.37-h*.43),h*.14,a*.40,.35+prepare*.35,n==0)
		elif release.get("recovering",false):
			var fade:=pow(maxf(0,1-float(release.get("recovery_phase",1))),1.4)*.52
			for n in range(3):_page(canvas,bag+Vector2(f*h*(.10+n*.10),-h*(.02+n*.06)),h*.057,t*.06+n*.40,fade,n==0)
		return g
	var boxes: Array=s.get("boxes",[])
	var box: Rect2=boxes[0] if not boxes.is_empty() else Rect2(paper-Vector2(h*.08,h*.10),Vector2(h*.16,h*.20))
	var edge:=Vector2(box.end.x if f>0 else box.position.x,box.get_center().y)
	match slot:
		"U":
			_paper_fan(canvas,bag,edge,h,phase,.95)
			_briefcase(canvas,bag,h*float(style.prop_ratio),.92,-f*(.14+phase*.33))
		"SU":
			var end:=box.get_center()
			_paper_fan(canvas,bag,end,h,phase,.95)
			_stamp(canvas,end+Vector2(0,-h*.05),h*float(style.stamp_ratio),.95,-f*.20)
			_ink_splash(canvas,Vector2(end.x,minf(box.end.y,float(s.get("floor",end.y)))),h*1.27,phase,.83)
		"WU":
			# This is the measured release hand only. The independently registered
			# zh3mc child draws the actual towering source area after child frame 3.
			for n in range(3):_page(canvas,paper+Vector2(f*h*(n*.065),-h*(.12+n*.16)),h*.13,float(n)*.31+t*.045,.91,n==1)
		"AIR_U":
			var down:=box.get_center()+Vector2(f*h*.14,h*.18)
			_paper_fan(canvas,bag,down,h,phase,.95)
			_briefcase(canvas,bag,h*float(style.prop_ratio),.97,f*.36)
			for n in range(2):_page(canvas,bag+Vector2(-f*h*.19*(n+1),-h*.11*(n+1)),h*.11,t*.10+n*.25,.93,n==1)
		"I":
			# Birth frame40 is a release seam; real child volume is drawn below.
			_page(canvas,paper+Vector2(f*h*.21,0),h*.26,-f*.24,.97,true)
		"WI":
			_clock(canvas,p+Vector2(-f*h*.80,-h*.81),h*float(style.prop_ratio),t,.93)
			if t>=189:
				var center:=box.get_center()
				_stamp(canvas,center+Vector2(0,-h*.14),h*float(style.stamp_ratio),.97,-f*.10)
				for n in range(5):_page(canvas,center+Vector2(sin(n*2.4)*h*.27,-h*(.15+n*.22)),h*.15,sin(t*.07+n)*.40,.94,n==0)
			else:
				_paper_fan(canvas,bag,edge,h,phase,.98,true)
				_seal(canvas,edge+Vector2(-f*h*.08,h*.17),h*.26,.93,-f*.10)
		"SI":
			# All 27 source contacts keep their original width and time. Visible
			# documents orbit the caster locally rather than drawing a screen plate.
			_clock(canvas,p+Vector2(-f*h*1.10,-h*.98),h*float(style.prop_ratio),t,.94)
			if t<179:
				for n in range(12):
					var a:=float(n)*2.399+t*.055*f
					var ring:=.58+.26*float(n%3)
					var q:=p+Vector2(cos(a)*h*ring*1.30,sin(a)*h*ring*.69-h*.56)
					_page(canvas,q,h*(.18+.027*(n%3)),a*.38,.95,n%6==0)
				for n in range(4):
					var a:=float(n)*TAU/4.0+t*.032*f
					_page(canvas,p+Vector2(cos(a)*h*1.68,sin(a)*h*.97-h*.55),h*.26,a+.22,.97,n==0)
			else:
				_stamp(canvas,p+Vector2(f*h*.46,-h*.50),h*float(style.stamp_ratio),.98,-f*.15)
				for n in range(8):
					var a:=float(n)*2.399
					_page(canvas,p+Vector2(cos(a)*h*(.63+phase*.75),sin(a)*h*.55-h*.44),h*.19,a+phase,.95,n==0)
		"AIR_I":
			_paper_fan(canvas,bag,box.get_center()+Vector2(f*h*.15,h*.18),h,phase,.97,true)
			_briefcase(canvas,bag+Vector2(0,h*.07),h*float(style.prop_ratio),.97,f*.24)
	return g

static func draw_object(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:
	var result: Dictionary={"ready":bool(s.get("ready",false)),"body_copies":0,"motif":"physical_document_stack","source_clock_mutated":false,"solid_material":true}
	if not result.ready or layer!="back":return result
	var box: Rect2=s.get("box",Rect2())
	if not box.has_area():return result
	var active:=bool(s.get("active_regions",false));var t:=float(s.get("frame",0))+float(s.get("source_clock",0))*30.0
	result["frame_fx"]=FrameFX.draw_object(canvas,s,layer)
	var slot:=str(s.get("slot",""));var h:=maxf(32,float(s.get("height",90)))
	var style:=style_profile(slot)
	result["style"]=style
	if slot=="WU":
		result["material_visible"]=active and t>=3
		if not result.material_visible:return result
		var bottom:=minf(box.end.y,float(s.get("floor",box.end.y)))
		var extent:=bottom-box.position.y
		if extent<=0:return result
		# Continuous broad paper helix is bounded to the real narrow translated
		# tower. Every sheet uses the child's actual area, never remote origin.
		var width:=maxf(4,minf(box.size.x*.49,h*.23))
		var length:=minf(extent,h*12.0)
		var steps:=clampi(int(length/(h*.24)),12,34)
		var size:=clampf(box.size.x*.40,5.4,h*.22)
		for n in range(steps):
			var u:=fposmod(float(n)/float(steps)+t*.013,1.0)
			var angle:=u*TAU*6+t*.11
			var q:=Vector2(box.get_center().x+sin(angle)*width*.56,bottom-size-u*length)
			_page(canvas,q,size,cos(angle)*.48,.96,n%8==0)
			if n%4==0:_ellipse(canvas,q+Vector2(-width*.14,size*.18),Vector2(width*.57,size*.22),BLUE,.24,cos(angle)*.30)
		result["motif"]="filled_document_helix"
		result["sheet_budget"]=34
	else:
		if not active:return result
		var center:=box.get_center();var size:=clampf(box.size.x*.23,9,h*.26)
		if slot=="I":_stack(canvas,center,minf(box.size.x*.79,h*1.8),minf(box.size.y*.62,h*2.2),fposmod(t*.017,1),.95)
		for n in range(7):
			var u:=fposmod(float(n)/7.0+t*.017,1.0)
			var q:=center+Vector2(sin(u*TAU)*minf(box.size.x*.35,h*.70),(u-.5)*minf(box.size.y,h*2.8))
			_page(canvas,q,size,sin(float(n)+t*.14)*.55,.94,n==3)
		if slot=="I":
			var final_window:=t>=49 and t<53
			result["final_window"]=final_window
			if final_window:
				_stamp(canvas,center+Vector2(0,-h*.08),minf(h*float(style.get("stamp_ratio",.70)),box.size.x*.48),.98,-.13)
				_seal(canvas,center+Vector2(0,h*.28),minf(h*.42,box.size.x*.29),.94,-.13)
			else:_seal(canvas,center,minf(h*.25,box.size.x*.19),.83,-.10)
	return result

static func draw_contact(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:
	var result: Dictionary={"ready":bool(s.get("ready",false)),"body_copies":0,"source_clock_mutated":false,"motif":"briefcase_paper_stamp","solid_material":true}
	if not result.ready:return result
	result["frame_fx"]=FrameFX.draw_contact(canvas,s,layer)
	var outcome:=str(s.get("outcome","hit"));var p:=_v(s.get("pos",Vector2.ZERO))
	var h:=float(s.get("height",90));var a:=clampf(float(s.get("alpha",0)),0,1)
	var phase:=float(s.get("phase",0));var f:=float(s.get("direction",1));var tier:=int(s.get("tier",1))
	var slot:=str(s.get("slot","U"));var final:=bool(s.get("finisher",false)) and outcome=="hit"
	result["confirmed_finisher"]=final
	if layer=="back":
		if outcome=="hit":
			var radius:=h*(.54 if tier==1 else (1.18 if final and tier==3 else (.91 if final else .66)))
			_burst(canvas,p,radius*(.80+phase*.24),a*.87,-f*.15)
			if final:
				var stamp_size:=h*(.66 if tier==2 else .96)
				_stamp(canvas,p+Vector2(-f*h*.20,-h*.10-phase*h*.12),stamp_size,a,-f*.17)
				if tier==3:_clock(canvas,p+Vector2(-f*h*.94,-h*.23),h*.57,float(s.get("source_frame",0)),a*.89)
		return result
	if layer!="front":return result
	if outcome in ["guard","blocked"]:
		# A physical upright report card catches the attack; no impact seal.
		_page(canvas,p+Vector2(f*h*.065,0),h*.115,-f*.13,a*.88,false)
		for n in range(4):
			var dir:=Vector2(f,(-1 if n%2==0 else 1)*(.6+.2*n)).normalized()
			_ellipse(canvas,p+dir*h*(.10+phase*.22),Vector2(h*.043,h*.015),BLUE,a*.90,dir.angle())
		result["motif"]="deflected_document_guard"
		return result
	if outcome in ["armor","steel","counter","bullet_clash"]:
		_burst(canvas,p,h*.19,a*.82,f*.20)
		for n in range(3):_page(canvas,p+Vector2((n-1)*h*.12,-phase*h*.15),h*.041,n*.55,a*.65,false)
		result["motif"]="stopped_briefcase_corner"
		return result
	var count:=4 if tier==1 else (7 if final else 5)
	for n in range(count):
		var angle:=float(n)*2.399+.2
		var dir:=Vector2(cos(angle),sin(angle))
		var size:=h*(.108 if tier==1 else (.157 if final else .123))
		# Dense material hits project away from the collision, leaving a small
		# clear chest area; the closer two sheets stay below the contact point.
		var chip_at:=p+dir*h*(.43+phase*(.59 if final else .42))
		if n<2:chip_at.y=maxf(chip_at.y,p.y+h*.17)
		_page(canvas,chip_at,size,float(n)*.38+phase*1.5,a*.96,n==count-1)
	if final:
		# The final accepted HitVO leaves a clear red ink mark low on the victim;
		# its face is kept free and ordinary multihits never draw this motif.
		var stamp_text: String="退勤" if slot=="SI" else "承認"
		_ink_splash(canvas,p+Vector2(0,h*.10),h*(1.3 if tier==3 else 1.0),phase,a)
		_seal(canvas,p+Vector2(f*h*.12,h*.20),h*(.22 if tier==2 else .31),a*.93,-f*.17,stamp_text)
		result["motif"]="confirmed_clockout_stamp" if slot=="SI" else "confirmed_approval_stamp"
		result["stamp_text"]=stamp_text
		result["stamp_center_filled"]=false
	elif slot=="SU":_ink_splash(canvas,p,h*.90,phase,a*.83)
	elif slot in ["U","AIR_U","AIR_I"]:_ink_splash(canvas,p,h*.74,phase,a*.76,false)
	return result
