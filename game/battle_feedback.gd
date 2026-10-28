extends RefCounted
## Presentation adapter for BVN's HitType / defense / steel effect selection.
## Source selection: OpenBVN3.4@4d7bc991 EffectCtrler.as275–361,
## EffectManager.as41–63, EffectModel.as114–407. Source freeze remains separate.
## SPDX-License-Identifier: GPL-3.0-or-later
## Does not modify HitVOs, clocks, damage, freeze, camera or any random generator.
const HEAVY_TYPES := [3,5,6,7,8,9]
const INK := Color("162b40")
const WHITE := Color("fffbe9")
const GOLD := Color("ffd36c")
const CYAN := Color("65e4f4")

static func describe(source: Dictionary, result: Dictionary, defense_type: int = 0) -> Dictionary:
	var exact: Dictionary = source.get("source_hit_vo", {})
	var hit_type: int = int(exact.get("hitType", 1))
	var outcome := "hit"
	if bool(result.get("blocked", false)): outcome = "guard"
	elif bool(result.get("armor", false)): outcome = "steel"
	elif str(result.get("reaction", "")) == "hurt_action": outcome = "counter"
	elif bool(result.get("guard_break", false)): outcome = "guard_break"
	# Official hand defense turns cutting sparks into the striking guard family.
	var effect_type := hit_type
	if outcome == "guard" and defense_type == 1:
		if hit_type == 1: effect_type = 2
		elif hit_type == 6: effect_type = 3
	var family: String = {0:"none",1:"slash",2:"strike",3:"strike",4:"magic",5:"magic",6:"slash",7:"fire",8:"ice",9:"electric",10:"stone",11:"catch"}.get(effect_type, "magic")
	return {"ready":hit_type != 0, "hit_type":hit_type, "effect_type":effect_type, "family":family, "outcome":outcome, "heavy":hit_type in HEAVY_TYPES, "major":str(source.get("kind", "")) == "super", "hit_id":str(source.get("source_name", exact.get("id", ""))), "source_type":str(source.get("source_type", "actor")), "direction":int(source.get("hit_owner_facing", source.get("owner_facing", 1))), "contains_character":false}

static func sample(effect: Dictionary) -> Dictionary:
	var feedback: Dictionary = effect.get("feedback", {})
	if not bool(feedback.get("ready", false)): return {"ready":false}
	var duration := maxf(.001, float(effect.get("max", .18)))
	var age := float(effect.get("visual_age", duration-float(effect.get("life", duration))))
	if not is_finite(age) or age >= duration: return {"ready":false}
	var progress := clampf(age/duration, 0.0, 1.0)
	var pos: Vector2 = effect.get("pos", Vector2.ZERO)
	if not pos.is_finite(): return {"ready":false}
	var scale := clampf(float(feedback.get("body_height", 85.0))/85.0, .80, 1.15)
	var outcome: String = feedback["outcome"]
	var radius := (43.0 if feedback["heavy"] else 27.0)*scale
	if feedback["major"]: radius *= 1.16
	if outcome in ["steel", "counter"]: radius *= .58
	# A contact is a local energy break, not a torso-sized barrier. Release art
	# still depicts the actual source attack area on the separate world layer.
	if outcome == "guard": radius *= .58
	elif feedback["family"] in ["magic", "catch"]: radius *= .48
	var floor_y := float(feedback.get("floor_y", pos.y+200))
	# Floor accents belong to real low contacts, never an aerial hit's shadow.
	var floor_contact := bool(feedback.get("target_grounded", false)) and absf(floor_y-pos.y) <= maxf(32.0, float(feedback.get("body_height",85))*.42)
	return {"ready":true, "feedback":feedback, "pos":pos, "progress":progress, "elapsed":age, "radius":radius, "alpha":pow(1.0-progress,1.1), "core_alpha":pow(clampf(1.0-age/.045,0,1),1.8), "floor_y":floor_y, "floor_contact":floor_contact, "contains_character":false}

static func _color(family: String) -> Color:
	return {"slash":GOLD, "strike":GOLD, "magic":CYAN, "fire":Color("ff9b42"), "ice":Color("a9f2ff"), "electric":Color("c09bff"), "stone":Color("d8c6a1"), "catch":CYAN}.get(family, CYAN)

static func _fade(color: Color, alpha: float) -> Color:
	return Color(color, color.a*alpha)

static func _line(canvas: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float, alpha: float) -> void:
	# Opaque painted edges survive the pale pool deck at the actual 900x600
	# playfield. The footprint/lifetime still comes from the same source contact.
	var paint_width := maxf(2.05,width*1.20)
	canvas.draw_line(a,b,_fade(INK,alpha*.95),paint_width+2.3,true)
	canvas.draw_line(a,b,_fade(color,alpha),paint_width,true)

static func _burst(pos: Vector2, radius: float, points: int, phase: float, rotation: float) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for i in range(points*2):
		var angle := rotation+float(i)*TAU/float(points*2)
		var reach := radius*(1.0 if i%2==0 else .30)*(1.0+sin(float(i)*2.7)*.12)
		polygon.append(pos+Vector2(cos(angle),sin(angle))*reach*(.78+phase*.35))
	return polygon

## Same original two-row painted impact atlas, supplemented by HitType shapes.
## Draw calls stay in world units, independent of viewport resolution.
static func draw(canvas: CanvasItem, state: Dictionary, impact: Texture2D = null) -> void:
	if not bool(state.get("ready", false)): return
	var feedback: Dictionary = state["feedback"]
	var outcome: String = feedback["outcome"]
	var family: String = feedback["family"]
	var pos: Vector2 = state["pos"]
	var phase: float = state["progress"]
	var alpha: float = state["alpha"]
	var core_alpha: float=state.get("core_alpha",alpha)
	var radius: float = state["radius"]
	var direction: float = 1.0 if int(feedback["direction"]) >= 0 else -1.0
	var color := _color(family)
	if outcome == "guard":
		_draw_guard(canvas,pos,radius,phase,alpha,direction,family)
		return
	if outcome in ["steel", "counter"]:
		var ping := GOLD if outcome == "steel" else CYAN
		_line(canvas,pos+Vector2(-radius,-radius*.20),pos+Vector2(radius,radius*.20),ping,3.0,alpha)
		_line(canvas,pos+Vector2(-radius*.23,radius*.7),pos+Vector2(radius*.23,-radius*.7),WHITE,2.0,alpha)
		canvas.draw_arc(pos,radius*(.5+phase),0,TAU,20,_fade(ping,alpha*.65),2.0,false)
		return
	# Dense contact core is brief and small; no full-body white flash or actor copy.
	if family in ["strike", "stone"]:
		var rotation := -.25*direction
		canvas.draw_colored_polygon(_burst(pos,radius*.74+2,7,phase,rotation),_fade(INK,core_alpha*.85))
		canvas.draw_colored_polygon(_burst(pos,radius*.74,7,phase,rotation),_fade(color,core_alpha))
		canvas.draw_colored_polygon(_burst(pos,radius*.39,6,phase,rotation+.2),_fade(WHITE,core_alpha))
		for strand in range(3):
			var axis:=Vector2(direction,-.46+float(strand)*.44).normalized()
			_line(canvas,pos+axis*radius*(.34+phase*.82),pos+axis*radius*(.90+phase*.84),color,2.4 if feedback["heavy"] else 1.7,alpha*.85)
	elif family == "slash":
		var axis := Vector2(direction,-.55).normalized()
		var across := Vector2(-axis.y,axis.x)
		var length := radius*(1.5+phase*.55)
		var cut := PackedVector2Array([pos-axis*length,pos+across*radius*.18,pos+axis*length,pos-across*radius*.18])
		canvas.draw_colored_polygon(cut,_fade(INK,alpha*.88))
		var paint := PackedVector2Array([pos-axis*length*.93,pos+across*radius*.11,pos+axis*length*.93,pos-across*radius*.11])
		canvas.draw_polygon(paint,PackedColorArray([_fade(color.darkened(.18),alpha*.70),_fade(color.lightened(.30),alpha*.70),_fade(color,alpha*.70),_fade(color.darkened(.18),alpha*.70)]))
		_line(canvas,pos-axis*length*.94,pos+axis*length*.94,WHITE,2.7,alpha*(.30+.70*core_alpha))
		_line(canvas,pos-across*radius*.66,pos+across*radius*.66,color,2.5,alpha*.8)
	elif family == "electric":
		for strand in range(3):
			var points := PackedVector2Array()
			for i in range(6):
				var x := (float(i)/5.0-.5)*radius*2.4*direction
				var y := sin(i*2.4+strand*2.0+phase*4.0)*radius*.30+(strand-1)*radius*.23
				points.append(pos+Vector2(x,y))
			canvas.draw_polyline(points,_fade(INK,alpha*.8),5.0,false)
			canvas.draw_polyline(points,_fade(WHITE if strand==1 else color,alpha),2.5,false)
	elif family == "ice":
		for i in range(5):
			var angle := float(i)*TAU/5.0+phase*.12
			var axis := Vector2(cos(angle),sin(angle))
			var side := Vector2(-axis.y,axis.x)
			var shard := PackedVector2Array([pos+axis*radius*(.15+phase),pos+axis*radius*(1.0+phase*.4),pos+axis*radius*.6+side*radius*.11])
			canvas.draw_colored_polygon(shard,_fade(color,alpha))
	elif family == "fire":
		for i in range(5):
			var angle := float(i)*TAU/5.0-.3
			var axis := Vector2(cos(angle),sin(angle))
			var side := Vector2(-axis.y,axis.x)
			var flame := PackedVector2Array([pos+side*radius*.13,pos+axis*radius*(1.0+phase*.5),pos-side*radius*.13,pos-axis*radius*.15])
			canvas.draw_colored_polygon(flame,_fade(color,alpha*.8))
	else:
		if family == "catch":
			canvas.draw_arc(pos,radius*(.6+phase*.25),-.75,1.0,12,_fade(color,alpha),2.0,false)
			return
		# Short, angular energy splinters leave the defender's face/body readable.
		# No concentric full circles resembling the separate guard effect.
		canvas.draw_colored_polygon(_burst(pos,radius+2,5,phase,.35*direction),_fade(INK,core_alpha*.65))
		canvas.draw_colored_polygon(_burst(pos,radius,5,phase,.35*direction),_fade(color,core_alpha*.8))
		canvas.draw_colored_polygon(_burst(pos,radius*.42,4,phase,-.2*direction),_fade(WHITE,core_alpha))
		for i in range(3):
			var axis:=Vector2(cos(i*2.1+.4),sin(i*2.1+.4))
			_line(canvas,pos+axis*radius*(.55+phase*.5),pos+axis*radius*(1.05+phase*.6),WHITE,1.8,alpha*.75)
	# Procedural contact follows the source center without a long-lived atlas
	# square. The dense nucleus disappears during hitstop, revealing body recoil.
	canvas.draw_circle(pos,radius*.12*(1.0-phase*.7),_fade(WHITE,core_alpha))
	# Directional sparks are analytic, never global-RNG samples.
	for i in range(6 if feedback["heavy"] else 4):
		var angle := (float(i)*2.39996+.35)*direction
		var axis := Vector2(cos(angle),sin(angle))
		var head := pos+axis*radius*(.50+phase*1.35)
		_line(canvas,head-axis*(7.0+phase*5.0),head,color,1.7,alpha*.8)
	if outcome == "guard_break":
		for i in range(3):
			var start := float(i)*TAU/3+.16
			canvas.draw_arc(pos,radius*(.9+phase),start,start+1.0,10,_fade(CYAN,alpha),3.0,false)
	if feedback["heavy"] and state["floor_contact"]:
		var floor := Vector2(pos.x,state["floor_y"])
		var points := PackedVector2Array()
		for i in range(25):
			var angle := float(i)*TAU/24
			points.append(floor+Vector2(cos(angle)*radius*(.5+phase*1.6),sin(angle)*radius*.18))
		canvas.draw_polyline(points,_fade(color,alpha*.45),2.0,false)
		for i in range(4):
			var side := -1.0 if i%2==0 else 1.0
			var center := floor+Vector2(side*radius*(.2+phase*(.8+i*.15)),-sin(phase*PI)*radius*(.24+i*.08))
			canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(-3,0),center+Vector2(2,-4),center+Vector2(4,2)]),_fade(Color("dccb9a"),alpha))

static func _draw_guard(canvas: CanvasItem, pos: Vector2, radius: float, phase: float, alpha: float, direction: float, family: String) -> void:
	var center := pos+Vector2(-direction*radius*.20,0)
	var start := -.75 if direction>0 else PI-.75
	var reach := radius*(.85+phase*.20)
	canvas.draw_arc(center,reach,start,start+1.50,16,_fade(INK,alpha*.85),5.0,false)
	canvas.draw_arc(center,reach,start,start+1.50,16,_fade(CYAN,alpha),2.8,false)
	canvas.draw_arc(center,reach-2,start+.12,start+1.38,14,_fade(WHITE,alpha),1.4,false)
	var axis := Vector2(direction,-.65) if family=="slash" else Vector2(direction,0)
	_line(canvas,pos-axis*radius*.28,pos+axis*radius*.28,WHITE,2.0,alpha)
	for i in range(3):
		var origin := pos+Vector2(direction*radius*(.25+phase*.65),(i-1)*radius*.25)
		_line(canvas,origin,origin+Vector2(direction*8,(i-1)*5),CYAN,1.4,alpha*.8)
