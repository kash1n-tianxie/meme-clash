extends RefCounted
## Decorative source-phase staging. Reads the accepted source branch only;
## never adds a clock, hit, freeze, camera transform or duplicate body.
const FX=preload("res://game/bvn_skill_fx.gd")
const INK:=Color("102b42")
const CREAM:=Color("fff2d7")
const ACCENT:={"rio":Color("72c8f2"),"chicken":Color("ffb550"),"cat":Color("f28cab"),"worker":Color("e96572"),"shark":Color("43d3df"),"notify":Color("ef707e"),"wojak":Color("dddde4")}
static var _caption_layouts: Dictionary={}

static func sample(state: Dictionary) -> Dictionary:
	var phase:=FX.cinematic_phase(state)
	if not phase.get("ready",false):return {"ready":false}
	var stage: String=phase["stage"]
	var p:=float(phase["progress"])
	var tier:=int(state["tier"])
	var envelope:=smoothstep(0.0,.42,p) if stage=="prepare" else (1.0-smoothstep(.10,.90,p) if stage=="recover" else 1.0)
	# A heavy source pose means an attempted heavy release. Successful finish
	# material is drawn only by FX.draw_contact after an actual accepted HitVO.
	var role:="anticipation" if stage=="prepare" else ("settle" if stage=="recover" else ("heavy_release" if stage in ["heavy","impact","descent"] else "release"))
	var strength:=.36+.48*p if role=="anticipation" else (.42 if role=="settle" else (1.0 if role=="heavy_release" else .78))
	return {"ready":true,"fighter_id":state["id"],"tier":tier,"stage":stage,"cue":phase["cue"],"subtitle":phase.get("subtitle",""),"motif":phase["motif"],"progress":p,"phase_role":role,"stage_strength":strength,"focus_alpha":(.15 if tier==3 else .065)*envelope*strength,"accent_alpha":(.50 if tier==3 else .24)*envelope*strength,"position":state["position"],"floor":state["floor"],"height":state["height"],"facing":state["facing"],"anchors":state.get("anchors",{}),"source_label":state["label"],"source_frame":phase["source_frame"],"source_clock":phase["source_clock"],"source_absolute_frame":phase["source_absolute_frame"],"clock_source":"accepted_source_branch","body_copies":0,"confirmed_finishing_hit":false,"center_clear_radius":float(state["height"])*1.8,"composition":"open_center_edge_motifs","tier_mark":"超必殺" if tier==3 else "必殺技"}

static func _edge_composition(canvas: CanvasItem, display: Dictionary, bounds: Rect2, reduced_motion: bool) -> void:
	if int(display["tier"])<3 or not bounds.has_area():return
	var alpha:=float(display["accent_alpha"])
	var color: Color=ACCENT[display["fighter_id"]]
	var w:=bounds.size.x
	var h:=bounds.size.y
	var p:=float(display["progress"])
	var origin:=bounds.position
	var motion:=0.0 if reduced_motion else sin(p*PI)*.018
	# The source camera's inverse bounds keep all four edge accents attached to
	# the visible viewport, including the high-air branch. The central combat
	# lane remains empty; these are decorative margins behind both real bodies.
	for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
		var inward:=Vector2(1 if corner.x==0 else -1,1 if corner.y==0 else -1)
		var at:=origin+Vector2(w*corner.x,h*corner.y)
		var polygon:=PackedVector2Array([at,at+Vector2(inward.x*w*(.115+motion),0),at+Vector2(inward.x*w*.028,inward.y*h*.18),at+Vector2(0,inward.y*h*.25)])
		canvas.draw_colored_polygon(polygon,Color(color,alpha*.23))
		canvas.draw_line(at+Vector2(inward.x*w*.027,inward.y*h*.045),at+Vector2(inward.x*w*.072,inward.y*h*.12),Color(CREAM,alpha*.42),2.3,true)
	# Large, translucent character emblems occupy the empty upper corners.
	# A paw emblem is never another cat; the basketball court emblem has no
	# rubber/seams and cannot be confused with a real source projectile.
	var radius:=minf(w*.038,h*.065)
	for sign_x: float in [-1.0,1.0]:
		var at:=origin+Vector2(w*(.12 if sign_x<0 else .88),h*.31)
		var ink:=Color(color,alpha*.24)
		match str(display["fighter_id"]):
			"cat":
				canvas.draw_circle(at+Vector2(0,radius*.20),radius*.61,ink)
				for n in range(3):canvas.draw_circle(at+Vector2((n-1)*radius*.62,-radius*(.50 if n==1 else .28)),radius*.28,ink)
			"chicken":
				_ellipse(canvas,at,Vector2(radius,radius*.42),.12,PI-.12,3.1,ink)
				_ellipse(canvas,at,Vector2(radius,radius*.42),PI+.12,TAU-.12,3.1,ink)
				canvas.draw_line(at-Vector2(radius*.65,0),at+Vector2(radius*.65,0),ink,2.0,true)
			"worker":
				for n in range(2):
					var paper:=Rect2(at-Vector2(radius*.68,radius*.70)+Vector2(n*radius*.30,n*radius*.20),Vector2(radius*1.06,radius*1.34))
					canvas.draw_rect(paper,ink,false,2.5)
					canvas.draw_line(paper.position+Vector2(radius*.16,radius*.34),paper.position+Vector2(radius*.82,radius*.34),ink,2.0,true)
			"shark":
				for n in range(3):
					var curl:=at+Vector2((n-1)*radius*.76,0)
					_ellipse(canvas,curl,Vector2(radius*.53,radius*.54),PI*.98,TAU+.15,3.3,ink)
			"rio":
				for n in range(3):
					var begin:=at+Vector2((n-1)*radius*.52,-radius*.74)
					canvas.draw_line(begin,begin+Vector2(-sign_x*radius*.30,radius*1.48),ink,3.4,true)

static func _ellipse(canvas: CanvasItem, at: Vector2, radius: Vector2, begin: float, end: float, width: float, color: Color) -> void:
	var points:=PackedVector2Array()
	for n in range(25):
		var angle:=lerpf(begin,end,float(n)/24.0)
		points.append(at+Vector2(cos(angle)*radius.x,sin(angle)*radius.y))
	canvas.draw_polyline(points,color,width,true)

static func draw_background(canvas: CanvasItem, state: Dictionary, bounds: Rect2, reduced_motion: bool=false) -> Dictionary:
	var display:=sample(state)
	if not display.get("ready",false):return display
	var alpha:=float(display["accent_alpha"])
	if alpha<=.001:return display
	canvas.draw_rect(bounds,Color(INK,float(display["focus_alpha"])))
	_edge_composition(canvas,display,bounds,reduced_motion)
	var at: Vector2=display["position"]
	var h:=float(display["height"])
	var stage: String=display["stage"]
	var p:=float(display["progress"])
	var color: Color=ACCENT[display["fighter_id"]]
	var floor_at:=Vector2(at.x,float(display["floor"])-2.0)
	# Low world-space accents communicate anticipation and recovery while the
	# real release/contact renderer owns the blade or basketball itself.
	if display["fighter_id"]=="rio":
		var extent:=h*(.68 if int(display["tier"])==2 else 1.10)
		if stage=="rotation":
			var spin:=0.0 if reduced_motion else p*TAU*2.0
			for sign_x: float in [-1.0,1.0]:
				_ellipse(canvas,floor_at,Vector2(extent,extent*.18),spin+(0.0 if sign_x>0 else PI),spin+(0.0 if sign_x>0 else PI)+1.25,3.2,Color(color,alpha))
		elif stage in ["prepare","open","combo","heavy","recover"]:
			var length:=extent*(.66+.20*p)
			for sign_x: float in [-1.0,1.0]:
				var begin:=floor_at+Vector2(sign_x*h*.28,3.0)
				canvas.draw_line(begin,begin+Vector2(sign_x*length,0),Color(color,alpha*.72),2.7,true)
			if stage=="heavy":
				_ellipse(canvas,floor_at,Vector2(extent*.80,extent*.17),PI+.22,TAU-.22,3.2,Color(CREAM,alpha*.62))
	elif display["fighter_id"]=="chicken":
		# Rounded court markings survive the source camera zoom. No pointed
		# lane, sword-like cut plane or invented contact appears on a miss.
		var radius:=h*(.64 if int(display["tier"])==2 else 1.06)
		var growth:=.78+.16*p
		_ellipse(canvas,floor_at,Vector2(radius*growth,radius*.24),.10,PI-.10,3.4,Color(color,alpha))
		_ellipse(canvas,floor_at,Vector2(radius*growth,radius*.24),PI+.20,TAU-.20,2.2,Color(color,alpha*.55))
		if stage in ["air_combo","descent","impact"]:
			for sign_x: float in [-1.0,1.0]:
				_ellipse(canvas,floor_at+Vector2(sign_x*radius*.84,0),Vector2(h*.11,h*.045),0,TAU,2.0,Color(CREAM,alpha*.65))
	elif display["fighter_id"]=="cat":
		# Three small paw pads and open forepaw sweeps stay at floor level;
		# rage adds rhythm while the real cat and contact effect remain visible.
		var extent:=h*(.63 if int(display["tier"])==2 else .98)
		for n in range(3):
			var paw_at:=floor_at+Vector2((n-1)*extent*.72,0)
			_ellipse(canvas,paw_at,Vector2(h*.13,h*.039),.10,PI-.10,2.2,Color(color,alpha*(.52 if stage=="recover" else .85)))
		if stage in ["combo","rage_combo","heavy","impact","grab_spin"]:
			_ellipse(canvas,floor_at,Vector2(extent,extent*.16),.16+p*.55,2.65+p*.55,2.8,Color(color,alpha*.72))
	elif display["fighter_id"]=="worker":
		# A sparse time-card/stamp registration, not a full-screen office panel.
		var extent:=h*(.68 if int(display["tier"])==2 else 1.02)
		var card:=Rect2(floor_at-Vector2(extent,h*.07),Vector2(extent*2,h*.14))
		for sign_x: float in [-1.0,1.0]:
			var corner:=floor_at+Vector2(sign_x*extent,-h*.055)
			canvas.draw_line(corner,corner-Vector2(sign_x*h*.22,0),Color(color,alpha),2.6,true)
			canvas.draw_line(corner,corner+Vector2(0,h*.11),Color(color,alpha*.75),2.0,true)
		if stage in ["paper_field","overtime_field","office_chain","impact","heavy"]:
			for n in range(5):
				var tick_at:=Vector2(lerpf(card.position.x,card.end.x,float(n+1)/6.0),floor_at.y)
				canvas.draw_line(tick_at,tick_at+Vector2(0,h*.037),Color(CREAM,alpha*.66),1.7,true)
	elif display["fighter_id"]=="shark":
		# Three sneaker wake rings, low and open. The final pressure splash is
		# owned by a confirmed contact, never by this decorative phase alone.
		var extent:=h*(.68 if int(display["tier"])==2 else 1.05)
		for n in range(3):
			var shoe_at:=floor_at+Vector2((n-1)*extent*.60,0)
			_ellipse(canvas,shoe_at,Vector2(h*(.15+.08*p),h*.048),.14,PI-.14,2.4,Color(color,alpha*.8))
		if stage in ["water_spin","water_hold","descent","heavy","impact"]:
			for n in range(2):_ellipse(canvas,floor_at,Vector2(extent*(.72+.19*n+.08*p),h*(.09+.035*n)),PI+.16,TAU-.16,2.4 if n==0 else 1.8,Color(color,alpha*(.69-.20*n)))
	return display

static func caption_layout(font: Font, display: Dictionary, at: Vector2, width: float) -> Dictionary:
	var size:=20
	var title: String=display["tier_mark"]+"  ·  "+str(display["cue"])
	var cache_key:=str(font.get_instance_id())+":"+str(width)+":"+title
	if _caption_layouts.has(cache_key):
		var cached: Dictionary=_caption_layouts[cache_key]
		return {"lines":cached.lines.duplicate(),"subtitle":_subtitle_line(font,display,width),"subtitle_size":15,"size":size,"line_height":26.0,"at":at,"width":width,"max_lines":cached.lines.size(),"actual_text_widths":cached.widths.duplicate()}
	var lines: Array[String]=[]
	var line:=""
	# Japanese has no spaces between most words. Wrap measured glyphs rather
	# than shrinking the cue below a readable 20-pixel instrument label.
	for glyph in title:
		if not line.is_empty() and font.get_string_size(line+glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
			lines.append(line.strip_edges());line=glyph
		else:line+=glyph
	if not line.is_empty():lines.append(line.strip_edges())
	var measured: Array=lines.map(func(text: String) -> float:return font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)
	if _caption_layouts.size()>=128:_caption_layouts.clear()
	_caption_layouts[cache_key]={"lines":lines.duplicate(),"widths":measured.duplicate()}
	return {"lines":lines,"subtitle":_subtitle_line(font,display,width),"subtitle_size":15,"size":size,"line_height":26.0,"at":at,"width":width,"max_lines":lines.size(),"actual_text_widths":measured}

static func _subtitle_line(font: Font,display: Dictionary,width: float) -> String:
	var text: String=str(display.get("subtitle",""))
	if text.is_empty() or text==str(display.get("cue","")):return ""
	while text.length()>1 and font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x>width:
		text=text.left(text.length()-2)+"…"
	return text

static func draw_caption(canvas: CanvasItem, font: Font, state: Dictionary, at: Vector2, width: float=400.0) -> Dictionary:
	var display:=sample(state)
	if not display.get("ready",false):return display
	var alpha:=clampf(float(display["accent_alpha"])*4.5,0.0,.95)
	if alpha<.01:return display
	var layout:=caption_layout(font,display,at,width)
	var color: Color=CREAM if int(display["tier"])==2 else ACCENT[display["fighter_id"]].lightened(.48)
	for n in range(layout.lines.size()):
		var baseline:=at+Vector2(0,n*float(layout.line_height))
		canvas.draw_string_outline(font,baseline,layout.lines[n],HORIZONTAL_ALIGNMENT_CENTER,width,int(layout.size),3,Color(INK,alpha))
		canvas.draw_string(font,baseline,layout.lines[n],HORIZONTAL_ALIGNMENT_CENTER,width,int(layout.size),Color(color,alpha))
	if not str(layout.subtitle).is_empty():
		var baseline: Vector2=at+Vector2(0,layout.lines.size()*float(layout.line_height)-4.0)
		canvas.draw_string_outline(font,baseline,layout.subtitle,HORIZONTAL_ALIGNMENT_CENTER,width,int(layout.subtitle_size),2,Color(INK,alpha*.74))
		canvas.draw_string(font,baseline,layout.subtitle,HORIZONTAL_ALIGNMENT_CENTER,width,int(layout.subtitle_size),Color(color,alpha*.70))
	display["caption_layout"]=layout
	return display
