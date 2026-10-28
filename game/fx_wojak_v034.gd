extends RefCounted
## Source-owned punctuation; open centers preserve the real whole-body art.
const INK: Color = Color("13181e")
const WHITE: Color = Color("f4f1e8")
const MOTIFS: Dictionary = {"U":"question_exclamation_child","SU":"slanted_rejection_punctuation","WU":"confirmed_exclamation_reply","I":"giant_question_pressure","WI":"target_split_parentheses","SI":"stacked_punctuation_climax","AIR_U":"actual_TF_reference_mark","AIR_I":"retreating_diagonal_question"}
const TOKENS: Dictionary = {"U":"?!","SU":"/?!","WU":"!!!","I":"?!","WI":"!!","SI":"!!!","AIR_U":"!","AIR_I":"?!"}

static func _v(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Array and value.size()>=2: return Vector2(float(value[0]),float(value[1]))
	return Vector2.INF
static func _clock(s: Dictionary) -> float:
	return float(s.get("frame",0))+(clampf(float(s.get("source_clock",0))*30.0,0,.999) if s.get("source_playing",true) else 0.0)
static func _packet(s: Dictionary) -> Dictionary:
	return {"ready":true,"motif":MOTIFS.get(str(s.get("slot","")),"ordinary_punctuation"),"shapes":[],"body_copies":0,"projectile_copies":0,"creates_contact":false,"source_clock_mutated":false,"changes_collision":false,"confirmed_finish":false,"generic_beam":false,"punctuation_only":true,"clock":"source_actor_child_or_confirmed_contact_age"}
static func _glyph(at: Vector2,size: Vector2,text: String,alpha: float,angle: float=0.0,kind: String="glyph") -> Dictionary:
	return {"at":at,"size":size,"kind":kind,"text":text,"alpha":clampf(alpha,0,1),"angle":angle,"phase":0.0}
static func _valid(s: Dictionary) -> bool:
	return bool(s.get("ready",false)) and str(s.get("id",""))=="wojak"
static func actor_geometry(s: Dictionary) -> Dictionary:
	if not _valid(s): return {"ready":false}
	var anchors: Dictionary = s.get("anchors",{})
	var hand: Vector2 = _v(anchors.get("hand")); var head: Vector2 = _v(anchors.get("anatomy_head")); var chest: Vector2 = _v(anchors.get("anatomy_chest"))
	if not hand.is_finite() or not head.is_finite() or not chest.is_finite(): return {"ready":false,"missing_anchor":true}
	var p: Dictionary = _packet(s); p["origin"]=hand; p["attached_to"]=["hand","anatomy_head","anatomy_chest"]
	var h: float = clampf(float(s.get("height",90)),16,180); var f: float = float(s.get("facing",1)); var slot: String = str(s.get("slot","U"))
	var release: Dictionary = s.get("release_state",{}); var active: bool = bool(release.get("active",false)); var prepare: float = float(release.get("prepare",0)); var recovery: float = float(release.get("recovery_phase",1))
	var alpha: float = .86 if active else (.18+.52*prepare if prepare>0 else .35*pow(1-recovery,1.5) if release.get("recovering",false) else 0.0)
	if alpha<=.002: return p
	var phase: float = _clock(s); var pulse: float = .95+.05*sin(phase*.21)
	var scale: float = .70 if active else .37
	var token: String = str(TOKENS.get(slot,"!")); var angle: float = -.18*f if slot in ["SU","AIR_I"] else 0.0
	var origin: Vector2 = hand+Vector2(f*h*.37,-h*.12 if slot!="AIR_I" else h*.23)
	if slot=="WU" and not str(s.get("label","")).ends_with("_HIT"): token="…"; scale=.42
	if slot=="SI":
		var stage: String = str(s.get("cinema_phase",{}).get("stage","prepare"))
		# Real actor HitVO windows are sampled as release. Gaps may be combo;
		# they must never become the condition for the active peak.
		scale=1.04 if active and stage in ["release","combo","heavy","impact"] else .52
		p.shapes.append(_glyph(chest+Vector2(-f*h*.65,-h*.15),Vector2(h*.55,h*.52),"!!!",alpha*.68,-f*.13))
		p.shapes.append(_glyph(head+Vector2(f*h*.57,-h*.10),Vector2(h*.38,h*.38),"※",alpha*.54,f*.12))
	elif slot=="WI":
		p.shapes.append(_glyph(head+Vector2(-f*h*.43,0),Vector2(h*.20,h*.63),"(",alpha*.65))
		p.shapes.append(_glyph(head+Vector2(f*h*.43,0),Vector2(h*.20,h*.63),")",alpha*.65))
	p.shapes.append(_glyph(origin,Vector2(h*scale*.82,h*scale*pulse),token,alpha,angle))
	if slot=="AIR_U" and s.get("grounded",false) and str(s.get("label","")).ends_with("_TF"):
		var position: Vector2 = _v(s.get("position",Vector2.ZERO))
		p.shapes.append(_glyph(Vector2(position.x,float(s.get("floor",position.y))-h*.04),Vector2(h*.96,h*.15),"※",alpha*.87,0,"stamp"))
	return p

static func object_geometry(s: Dictionary) -> Dictionary:
	if not _valid(s) or s.get("removed",false) or s.get("timeout",false): return {"ready":false}
	var box: Rect2 = s.get("box",Rect2())
	if not box.has_area(): return {"ready":false}
	var h: float = clampf(float(s.get("height",90)),16,180); var center: Vector2 = box.get_center(); var slot: String = str(s.get("slot","U"))
	var checker: bool = bool(s.get("checker_only",false)) or str(s.get("name",""))=="zh10atm"
	var active: bool = bool(s.get("active_regions",false)); var alpha: float = .17 if checker else .91 if active else .36
	var p: Dictionary = _packet(s); var token: String = "…" if checker else str(TOKENS.get(slot,"?!"))
	p.merge({"center":center,"token":token,"source_objects_drawn":1,"source_position":s.get("position",center),"checker_only":checker,"damage_material":not checker and active,"birth":s.get("birth_source_absolute_frame",-1)},true)
	if checker:
		p.shapes.append(_glyph(center,Vector2(h*.38,h*.21),"…",alpha)); return p
	var size: Vector2 = Vector2(clampf(box.size.x,h*.70,h*1.75),clampf(box.size.y,h*.63,h*1.15))
	var motion: float = sin(_clock(s)*.19)*.045
	if slot=="WI":
		p.shapes.append(_glyph(center-Vector2(size.x*.47,0),Vector2(h*.24,size.y*1.22),"(",alpha))
		p.shapes.append(_glyph(center+Vector2(size.x*.47,0),Vector2(h*.24,size.y*1.22),")",alpha))
		p.shapes.append(_glyph(center-Vector2(size.x*.25,size.y*.10),Vector2(h*.35,size.y*.83),"!",alpha,motion))
		p.shapes.append(_glyph(center+Vector2(size.x*.25,-size.y*.10),Vector2(h*.35,size.y*.83),"!",alpha,-motion))
	else:
		p.shapes.append(_glyph(center,size,token,alpha,motion if slot!="SU" else -.23))
		p.shapes.append(_glyph(center-Vector2(size.x*.51,0),Vector2(h*.20,size.y*1.08),"[" if slot=="I" else "(",alpha*.72))
		p.shapes.append(_glyph(center+Vector2(size.x*.51,0),Vector2(h*.20,size.y*1.08),"]" if slot=="I" else ")",alpha*.72))
	return p

static func contact_geometry(s: Dictionary) -> Dictionary:
	var outcome: String = str(s.get("outcome",""))
	if not _valid(s) or not s.get("confirmed",true) or s.get("checker_only",false) or outcome not in ["hit","guard_break","guard","blocked","armor","steel","counter","bullet_clash"]: return {"ready":false}
	var at: Vector2 = _v(s.get("pos",s.get("position")))
	if not at.is_finite(): return {"ready":false}
	var p: Dictionary = _packet(s); var h: float = clampf(float(s.get("height",90)),16,180); var f: float = float(s.get("direction",s.get("facing",1)))
	var alpha: float = clampf(float(s.get("alpha",1)),0,1); var phase: float = clampf(float(s.get("phase",0)),0,1); var slot: String = str(s.get("slot","U"))
	var hit: bool = outcome in ["hit","guard_break"]; var final: bool = hit and bool(s.get("finisher",false)); p["confirmed_finish"]=final
	if not hit:
		p.shapes.append(_glyph(at,Vector2(h*.58,h*.43),"()" if outcome in ["guard","blocked"] else "…",alpha*.70)); return p
	if final and int(s.get("tier",1))==3:
		p["open_center_radius"]=h*.30
		p.shapes.append(_glyph(at+Vector2(-f*h*.83,-h*.10),Vector2(h*.82,h*1.62),"?",alpha*.95,-f*.12))
		p.shapes.append(_glyph(at+Vector2(f*h*.83,-h*.10),Vector2(h*.65,h*1.62),"!",alpha*.95,f*.10))
		p.shapes.append(_glyph(at+Vector2(-f*h*.65,h*.50),Vector2(h*.36,h*.36),"※",alpha*.73,phase*.15))
		p.shapes.append(_glyph(at+Vector2(f*h*.62,-h*.64),Vector2(h*.40,h*.55),"!!!",alpha*.68,-f*.14))
	else:
		var reach: float = 1.13 if final else .74 if int(s.get("tier",1))>=2 else .55
		p.shapes.append(_glyph(at+Vector2(f*h*.50,-h*.12),Vector2(h*reach*.67,h*reach),"?!" if slot in ["U","I","AIR_I"] else "!!!" if slot in ["WU","SI"] else "!",alpha,-f*.13))
		p.shapes.append(_glyph(at+Vector2(-f*h*.38,h*.16),Vector2(h*.31,h*.36),"※" if slot=="AIR_U" else "…",alpha*.72))
	return p

static func normal_actor_geometry(s: Dictionary) -> Dictionary:
	if not _valid(s) or not s.get("normal_source",false) or str(s.get("source_profile",""))!="sasuke_susanoo" or s.get("normal_hit_ids",[]).is_empty(): return {"ready":false}
	var hand: Vector2 = _v(s.get("anchors",{}).get("hand"))
	if not hand.is_finite(): return {"ready":false}
	var p: Dictionary = _packet(s); var h: float = clampf(float(s.get("height",90)),16,180); var f: float = float(s.get("facing",1))
	p["motif"]="actual_normal_source_punctuation"; p["origin"]=hand
	p.shapes.append(_glyph(hand+Vector2(f*h*.20,-h*.04),Vector2(h*.28,h*.47),"!",.84,-f*.18+sin(_clock(s)*.20)*.025))
	p.shapes.append(_glyph(hand-Vector2(f*h*.14,-h*.10),Vector2(h*.29,h*.15),"…",.52,-f*.18))
	return p
static func normal_object_geometry(s: Dictionary) -> Dictionary:
	if not _valid(s) or not s.get("normal_source",false) or not s.get("normal_object",false) or str(s.get("source_profile",""))!="sasuke_susanoo": return {"ready":false}
	if str(s.get("name",""))!="k5mc" or str(s.get("source_symbol",s.get("symbol","")))!="元件/mc_076" or str(s.get("source_origin_label",""))!="砍5" or not str(s.get("binding_id","")).is_empty(): return {"ready":false}
	if int(s.get("birth_source_absolute_frame",s.get("source_spawn_absolute_frame",-1)))!=295: return {"ready":false}
	var packet: Dictionary = s.duplicate(true)
	packet["slot"]="U"; packet["active_regions"]=not s.get("normal_hit_ids",[]).is_empty()
	packet["checker_only"]=not packet.active_regions
	var result: Dictionary = object_geometry(packet)
	if result.get("ready",false): result["motif"]="actual_k5_source_punctuation"
	return result

static func normal_contact_geometry(s: Dictionary) -> Dictionary:
	if not _valid(s) or not s.get("normal_source",false) or str(s.get("source_profile",""))!="sasuke_susanoo" or not s.get("confirmed",false): return {"ready":false}
	var maximum: float = float(s.get("max",.18)); var age: float = float(s.get("visual_age",maximum-float(s.get("life",maximum))))
	if maximum<=0 or age<0 or age>=maximum: return {"ready":false}
	var packet: Dictionary = s.duplicate(true)
	packet["slot"]="NORMAL"; packet["tier"]=1; packet["finisher"]=false; packet["phase"]=clampf(age/maximum,0,1); packet["alpha"]=pow(1-packet.phase,1.35)
	return contact_geometry(packet)

static func _paths(symbol: String) -> Dictionary:
	if symbol=="?": return {"paths":[[Vector2(-.28,-.27),Vector2(-.23,-.41),Vector2(-.07,-.48),Vector2(.13,-.46),Vector2(.27,-.33),Vector2(.24,-.17),Vector2(.10,-.06),Vector2(0,.08),Vector2(0,.20)]],"dots":[Vector2(0,.43)]}
	if symbol=="!": return {"paths":[[Vector2(0,-.48),Vector2(0,.19)]],"dots":[Vector2(0,.43)]}
	if symbol=="…": return {"paths":[],"dots":[Vector2(-.32,.10),Vector2(0,.10),Vector2(.32,.10)]}
	if symbol=="※": return {"paths":[[Vector2(-.28,-.28),Vector2(.28,.28)],[Vector2(-.28,.28),Vector2(.28,-.28)]],"dots":[Vector2(0,-.43),Vector2(.43,0),Vector2(0,.43),Vector2(-.43,0)]}
	if symbol=="/": return {"paths":[[Vector2(-.28,.47),Vector2(.28,-.47)]],"dots":[]}
	if symbol in ["[","]"]:
		var side: float = -1 if symbol=="[" else 1
		return {"paths":[[Vector2(-side*.08,-.46),Vector2(side*.33,-.46),Vector2(side*.33,.46),Vector2(-side*.08,.46)]],"dots":[]}
	var side: float = -1 if symbol=="(" else 1
	return {"paths":[[Vector2(-side*.03,-.47),Vector2(side*.20,-.36),Vector2(side*.34,-.17),Vector2(side*.38,0),Vector2(side*.34,.17),Vector2(side*.20,.36),Vector2(-side*.03,.47)]],"dots":[]}
static func symbol_primitives(shape: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []; var text: String = str(shape.get("text","")); var size: Vector2 = shape.size; var at: Vector2 = shape.at; var angle: float = float(shape.get("angle",0))
	if text.is_empty() or text.length()>3: return out
	var width: float = size.x/float(text.length()); var stroke: float = maxf(1.3,minf(width,size.y)*.11)
	for index: int in range(text.length()):
		var glyph: Dictionary = _paths(text.substr(index,1)); var center: Vector2 = Vector2(-size.x*.5+width*(float(index)+.5),0)
		for path: Array in glyph.paths:
			var points: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in path: points.append(at+(center+Vector2(point.x*width,point.y*size.y)).rotated(angle))
			out.append({"kind":"stroke","points":points,"width":stroke})
		for point: Vector2 in glyph.dots:
			out.append({"kind":"dot","at":at+(center+Vector2(point.x*width,point.y*size.y)).rotated(angle),"radius":maxf(.85,minf(width,size.y)*.088)})
	return out
static func _paint(canvas: CanvasItem,shape: Dictionary) -> void:
	var alpha: float = float(shape.alpha)
	if alpha<=.002: return
	for part: Dictionary in symbol_primitives(shape):
		if part.kind=="stroke":
			canvas.draw_polyline(part.points,Color(WHITE,alpha*.94),part.width*1.82,true)
			canvas.draw_polyline(part.points,Color(INK,alpha),part.width,true)
		else:
			canvas.draw_circle(part.at,part.radius*1.52,Color(WHITE,alpha*.94))
			canvas.draw_circle(part.at,part.radius,Color(INK,alpha))
static func _draw(canvas: CanvasItem,packet: Dictionary,layer: String,draw_layer: String="back") -> Dictionary:
	if packet.get("ready",false) and layer==draw_layer:
		for shape: Dictionary in packet.shapes: _paint(canvas,shape)
	return packet
static func draw_actor(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:
	var geometry: Dictionary=s["geometry"] if s.get("geometry") is Dictionary else actor_geometry(s)
	return _draw(canvas,geometry,layer)
static func draw_object(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary: return _draw(canvas,object_geometry(s),layer)
static func draw_contact(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:
	var geometry: Dictionary=s["geometry"] if s.get("geometry") is Dictionary else contact_geometry(s)
	return _draw(canvas,geometry,layer,"front")
static func draw_normal_actor(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary: return _draw(canvas,normal_actor_geometry(s),layer)
static func draw_normal_object(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary: return _draw(canvas,normal_object_geometry(s),layer)
static func draw_normal_contact(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary: return _draw(canvas,normal_contact_geometry(s),layer,"front")
## Undrawn compatibility helper for the earlier contour regression.
static func drop_points(at: Vector2,size: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array([at-Vector2(0,size.y*.51)])
	for n: int in range(13):
		var angle: float = lerpf(-PI*.25,PI*1.25,float(n)/12.0)
		points.append(at+Vector2(cos(angle)*size.x*.5,sin(angle)*size.y*.26+size.y*.13))
	return points
