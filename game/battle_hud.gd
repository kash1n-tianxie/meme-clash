extends RefCounted
## HD fight instruments over the pixel arena. This module only reads match state.
## Layout reference: 5DPLAY OpenBleachVsNaruto (GPL-3.0-or-later), pinned
## 4d7bc9913ec6b609ba521ff86b6066bff134a736, embed/fight mc_044 / mc_040.
## Frames, colors and Japanese typography below are project-authored graphics;
## no upstream portrait, bitmap, SWF or Flash timeline animation is used here.
const T = preload("res://game/summer_theme.gd")
const HitRules = preload("res://game/bvn_hit_rules.gd")
const PlayableTimeline = preload("res://game/bvn_playable_timeline.gd")
const RosterPortrait = preload("res://game/bvn_roster_portrait_v034.gd")
static var unsupported_super_uses: Dictionary={}
const EMPTY := Color("23465C")
const BAR_WIDTH := 430.0
const INK := Color("102B42")
const HP_LIGHT := Color("FFF1B6")
const HP_GOLD := Color("FFBD45")
const METER_WIDTH := 324.0
const RESOURCE_RAIL_WIDTH := 394.0
const RESOURCE_RAIL_Y := 914.0
const RESOURCE_RAIL_HEIGHT := 44.0
const RESOURCE_RAIL_FONT := 20
const CONTROL_SIDEBAR := Rect2(18,244,318,284)
const CONTROL_LABEL_SIZE := 20
const CONTROL_KEY_SIZE := 22
const CONTROL_MIN_OPACITY := .32
const CONTROL_OUTLINE_OPACITY := .95
const TRAINING_FOOTER_SIZE := 16
const SIDEBAR_KEY_ALIASES := {"Left":"←","Right":"→","Up":"↑","Down":"↓","Backspace":"Bksp","PageUp":"PgUp","PageDown":"PgDn","Page Up":"PgUp","Page Down":"PgDn","Delete":"Del","Insert":"Ins","PrintScreen":"PrtSc","Print Screen":"PrtSc","CapsLock":"Caps","Caps Lock":"Caps","ScrollLock":"ScrLk","Scroll Lock":"ScrLk","Kp Divide":"KP÷","Kp Multiply":"KP×"}
static var sidebar_key_names: Dictionary={}
static var control_layout_signature: Array=[]
static var control_layout_commands: Array[Dictionary]=[]
static var control_layout_font: Font
static var control_detail_rect := Rect2()
static var control_visible_rect := CONTROL_SIDEBAR
static var portrait_metadata: Dictionary={}
static var portrait_textures: Dictionary={}
static var portraits_loaded := false

static func _poly(c, points: PackedVector2Array, color: Color, outline: Color=Color.TRANSPARENT, thickness: float=2.0) -> void:
	c.draw_colored_polygon(points,color)
	if outline.a>0:
		var closed: PackedVector2Array=points.duplicate()
		closed.append(points[0])
		c.draw_polyline(closed,outline,thickness,true)

static func _label(b, text: String, at: Vector2, size: int, color: Color, width: float=-1, alignment: int=HORIZONTAL_ALIGNMENT_LEFT, outlined: bool=false) -> void:
	if outlined: b.draw_string_outline(b.font,at,text,alignment,width,size,3,T.CREAM)
	b.draw_string(b.font,at,text,alignment,width,size,color)

static func _mirror(points: PackedVector2Array, side: int) -> PackedVector2Array:
	if side==0: return points
	var result := PackedVector2Array()
	for p in points: result.append(Vector2(1280-p.x,p.y))
	return result

static func _key(b, side: int, slot: int) -> String:
	return OS.get_keycode_string(int(b.key_bindings[side][slot]))

static func _fit_label(b, text: String, at: Vector2, size: int, color: Color, width: float, align: int=HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var fitted := size
	while fitted>14 and b.font.get_string_size(text,align,-1,fitted).x>width: fitted-=1
	_label(b,text,at,fitted,color,width,align)

## One source-pixel crop API shared by every fighter; metadata is authored with the master art.
static func portrait_source(fighter_id: String) -> Dictionary:
	if RosterPortrait.supports(fighter_id):
		var pose: Dictionary=RosterPortrait.pose(fighter_id,"cutin",0.0,true)
		if not bool(pose.get("ready",false)):return {}
		var texture: Texture2D=RosterPortrait.texture(str(pose["atlas"]))
		if texture==null:return {}
		return {"texture":texture,"region":pose["region"],"parts":[pose["region"]]}
	if not portraits_loaded:
		portraits_loaded=true
		var path := "res://assets/art/portraits.json"
		if FileAccess.file_exists(path):
			var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary: portrait_metadata=parsed.get("portraits",{})
		var modern_path := "res://assets/art/visual_v18/metadata.json"
		if FileAccess.file_exists(modern_path):
			var modern=JSON.parse_string(FileAccess.get_file_as_string(modern_path))
			if modern is Dictionary and int(modern.get("version",0)) == 1:
				portrait_metadata.merge(modern.get("portraits",{}),true)
	var path: String="res://assets/art/visual_v18/"+fighter_id+".png"
	if not ResourceLoader.exists(path): path="res://assets/art/"+fighter_id+".png"
	if not portrait_textures.has(fighter_id) and ResourceLoader.exists(path):
		portrait_textures[fighter_id]=load(path)
	var texture: Texture2D=portrait_textures.get(fighter_id)
	if not texture: return {}
	var size: Vector2=texture.get_size()
	var spec: Dictionary=portrait_metadata.get(fighter_id,{})
	var raw: Array=spec.get("source_rect",[])
	var region: Rect2
	if raw.size()==4:
		region=Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3])).intersection(Rect2(Vector2.ZERO,size))
	else:
		# A generic square near the top is only a safe interim fallback before art calibration.
		var edge: float=minf(size.x,size.y)*.62
		region=Rect2((size.x-edge)*.5,size.y*.045,edge,edge)
	if region.size.x<=0 or region.size.y<=0: return {}
	var parts: Array[Rect2]=[]
	for item in spec.get("source_parts",[]):
		if not item is Array or item.size()!=4: continue
		var part: Rect2=Rect2(float(item[0]),float(item[1]),float(item[2]),float(item[3])).intersection(region)
		if part.size.x>0 and part.size.y>0: parts.append(part)
	if parts.is_empty(): parts.append(region)
	return {"texture":texture,"region":region,"parts":parts,"calibrated":raw.size()==4}

static func draw_portrait(b, fighter_id: String, rect: Rect2) -> void:
	var source: Dictionary=portrait_source(fighter_id)
	if source.is_empty(): return
	var region: Rect2=source["region"]
	# Contain the whole face: never change its aspect ratio to fit a frame.
	var scale: float=minf(rect.size.x/region.size.x,rect.size.y/region.size.y)
	var size: Vector2=region.size*scale
	var origin: Vector2=rect.position+(rect.size-size)*.5
	for part in source["parts"]:
		b.draw_texture_rect_region(source["texture"],Rect2(origin+(part.position-region.position)*scale,part.size*scale),part)

static func draw_hud(b) -> void:
	for side in range(2):
		var actor=b.fighters[side]
		var ink: Color=T.CORAL if side==0 else T.SEA
		_draw_health(b,side,ink)
		_draw_meter(b,side,ink)
		_draw_defense_status(b,side)
		var combo: int=actor.combo_hits if actor.combo_hits>0 else actor.last_combo_hits
		if combo>=2 and actor.combo_reset>0 and b.cinema_time<=0:
			var damage: int=actor.combo_damage if actor.combo_hits>0 else actor.last_combo_damage
			_draw_combo(b,combo,damage,1-side)
	_draw_timer(b)
	_draw_controls(b)
	if b.mode=="training":
		# Keep the footer clear of the 4:3 viewport edge without compressing its text.
		b.draw_set_transform(Vector2(0,b.HEIGHT-728))
		_draw_training(b)
		b.draw_set_transform(Vector2.ZERO)
	else:
		_overlay_label(b,"ESC ポーズ  /  F3 ガイド表示",Vector2(432,b.HEIGHT-12),20,1.0,416,HORIZONTAL_ALIGNMENT_CENTER)

## One joined top instrument, following BVN's portrait / HP / energy / clock
## hierarchy. Geometry is original; the source SWF bitmaps are not imported.
static func health_layout(side: int) -> Dictionary:
	var x: float=128.0 if side==0 else 722.0
	return {"face_rect":Rect2(24 if side==0 else 1171,22,85,79),
		"hp_rect":Rect2(x,48,BAR_WIDTH,30),"energy_rect":Rect2(x,111,BAR_WIDTH,7),
		"name_rect":Rect2(x,15,BAR_WIDTH,28),
		"hp_text_rect":Rect2(x+72 if side==0 else x+176,86,182,22),
		"energy_text_rect":Rect2(x+280 if side==0 else x,86,150,22),
		"instrument_rect":Rect2(12 if side==0 else 701,11,567,120)}

static func _draw_health(b, side: int, ink: Color) -> void:
	var actor=b.fighters[side]
	var align: int=HORIZONTAL_ALIGNMENT_LEFT if side==0 else HORIZONTAL_ALIGNMENT_RIGHT
	var layout: Dictionary=health_layout(side)
	var hp_rect: Rect2=layout.hp_rect
	var x: float=hp_rect.position.x
	# A continuous dark silhouette makes the name, HP and stamina one unit.
	_poly(b,_mirror(PackedVector2Array([Vector2(119,15),Vector2(560,15),Vector2(578,42),Vector2(564,123),Vector2(116,123)]),side),INK)
	b.draw_line(Vector2(x,19),Vector2(x+BAR_WIDTH,19),ink,3,true)
	_fit_label(b,actor.display_name,Vector2(x,38),25,T.CREAM,BAR_WIDTH,align)
	# The colored offset edge identifies the player, without separate paper tags.
	_poly(b,_mirror(PackedVector2Array([Vector2(12,17),Vector2(124,11),Vector2(117,123),Vector2(19,131)]),side),ink,INK,3)
	_poly(b,_mirror(PackedVector2Array([Vector2(18,18),Vector2(117,16),Vector2(111,119),Vector2(24,124)]),side),INK,T.CREAM,2)
	b.draw_rect(Rect2(layout.face_rect.position-Vector2(1,1),layout.face_rect.size+Vector2(2,2)),Color("325A72"))
	draw_portrait(b,actor.fighter_id,layout.face_rect)
	var badge_x: float=23.0 if side==0 else 1172.0
	_poly(b,PackedVector2Array([Vector2(badge_x,104),Vector2(badge_x+85,104),Vector2(badge_x+82,123),Vector2(badge_x-2,123)]),ink)
	_label(b,"1P" if side==0 else ("2P" if b.mode=="local" else "CPU"),Vector2(badge_x,120),19,INK,82,HORIZONTAL_ALIGNMENT_CENTER)
	# Actual HP and the existing delayed trail share the exact same range.
	_poly(b,_mirror(PackedVector2Array([Vector2(123,44),Vector2(566,44),Vector2(560,83),Vector2(121,83)]),side),INK,T.CREAM,2)
	b.draw_rect(hp_rect,EMPTY)
	var trail: float=BAR_WIDTH*clampf(float(b.hp_trail[side])/1000,0,1)
	var hp: float=BAR_WIDTH*clampf(float(actor.hp)/1000,0,1)
	b.draw_rect(Rect2(x if side==0 else x+BAR_WIDTH-trail,48,trail,30),T.CORAL.darkened(.16))
	var start: float=x if side==0 else x+BAR_WIDTH-hp
	var low: bool=actor.hp<=250
	for stripe in range(10):
		var fill: Color=T.CORAL.lightened(.24).lerp(T.CORAL.darkened(.08),float(stripe)/9.0) if low else HP_LIGHT.lerp(HP_GOLD,float(stripe)/9.0)
		b.draw_rect(Rect2(start,48+stripe*3,hp,3),fill)
	if hp>0:
		b.draw_line(Vector2(start,49),Vector2(start+hp,49),T.CREAM,2,true)
		var end: float=start+hp if side==0 else start
		b.draw_line(Vector2(end,48),Vector2(end,78),T.CREAM,2,true)
	for tick in range(1,10):
		var tx: float=x+tick*BAR_WIDTH/10
		b.draw_line(Vector2(tx,74),Vector2(tx,78),Color(INK,.35),1,true)
	b.draw_line(Vector2(x,83),Vector2(x+BAR_WIDTH,83),ink,3,true)
	# The compact lower branch contains wins, exact HP and exact stamina.
	for win in range(2):
		var px: float=x+win*28 if side==0 else x+BAR_WIDTH-18-win*28
		var won: bool=int(b.wins[side])>win
		_poly(b,PackedVector2Array([Vector2(px+9,89),Vector2(px+18,98),Vector2(px+9,107),Vector2(px,98)]),T.SUN if won else EMPTY,T.CREAM,1.5)
		if won:
			b.draw_line(Vector2(px+5,98),Vector2(px+8,102),INK,2,true)
			b.draw_line(Vector2(px+8,102),Vector2(px+13,94),INK,2,true)
	var hp_text: Rect2=layout.hp_text_rect
	_label(b,"HP %d / 1000" % actor.hp,Vector2(hp_text.position.x,104),20,T.CREAM,hp_text.size.x,align)
	var energy: float=clampf(float(actor.energy),0,100)
	var energy_text: Rect2=layout.energy_text_rect
	_label(b,"体力 %d%s" % [floori(energy)," !" if actor.energy_overload else ""],Vector2(energy_text.position.x,104),20,T.CORAL if actor.energy_overload else T.SEA,energy_text.size.x,align)
	var energy_rect: Rect2=layout.energy_rect
	b.draw_rect(energy_rect,EMPTY)
	var stamina_fill: float=energy_rect.size.x*energy/100
	b.draw_rect(Rect2(x if side==0 else x+BAR_WIDTH-stamina_fill,111,stamina_fill,7),T.CORAL if actor.energy_overload else T.SEA)
	for tick in range(1,5):
		b.draw_line(Vector2(x+tick*BAR_WIDTH/5,111),Vector2(x+tick*BAR_WIDTH/5,118),INK,2,true)

## Short, current-state observations for ordinary matches. Never infer an
## action permission from a pose, held key, old impact or a future landing.
static func defense_status(b, side: int) -> Dictionary:
	if b.mode not in ["local", "cpu"] or b.paused or b.phase != "active" or b.cinema_time > 0: return {}
	if b.playable_world and b.playable_world.bisha_owner >= 0: return {}
	var actor = b.fighters[side]
	if actor.hp <= 0: return {}
	if actor.can_bvn_floor_recovery():
		return {"kind":"floor_recovery", "text":_sidebar_key(b,side,6)+" 受け身可", "actionable":true, "color":T.SUN}
	if actor.state == "getup":
		return {"kind":"recovering", "text":"受け身中" if actor.source_label == "起身" else "起き上がり", "actionable":false, "color":T.CREAM}
	if actor.state == "guard_stun":
		return {"kind":"guard_stun", "text":"ガード硬直", "actionable":false, "color":T.CORAL}
	if actor.state == "guard":
		if not bool(actor.last_intent.get("guard",false)):
			return {"kind":"guard_resume", "text":"防御戻し", "actionable":false, "color":T.CREAM}
		if actor.guarding:
			return {"kind":"guard", "text":"防御中", "actionable":false, "color":T.SEA}
		return {"kind":"guard_prepare", "text":"防御準備", "actionable":false, "color":T.CREAM}
	return {}

static func defense_status_layout(side: int) -> Dictionary:
	# Leave the joined HP/stamina instrument and existing combo card clear.
	return {"rect":Rect2(128 if side == 0 else 1000,136,152,26), "font_size":18}

static func _draw_defense_status(b, side: int) -> void:
	var status: Dictionary = defense_status(b,side)
	if status.is_empty(): return
	var layout: Dictionary = defense_status_layout(side)
	var rect: Rect2 = layout.rect
	b.draw_rect(rect,Color(INK,.94))
	b.draw_line(rect.position,rect.position+Vector2(rect.size.x,0),status.color,2,true)
	_fit_label(b,str(status.text),rect.position+Vector2(5,20),int(layout.font_size),status.color,rect.size.x-10,HORIZONTAL_ALIGNMENT_CENTER)


static func _draw_timer(b) -> void:
	_poly(b,PackedVector2Array([Vector2(605,14),Vector2(675,14),Vector2(704,54),Vector2(684,105),Vector2(596,105),Vector2(576,54)]),INK,T.CREAM,2)
	b.draw_polyline(PackedVector2Array([Vector2(591,39),Vector2(610,20),Vector2(670,20),Vector2(689,39)]),T.SUN,3,true)
	var text: String="∞" if b.mode=="training" else "%02d" % ceili(b.round_timer)
	_label(b,text,Vector2(579,77),63,T.CORAL if b.mode!="training" and b.round_timer<=10 else T.CREAM,122,HORIZONTAL_ALIGNMENT_CENTER)
	_label(b,"練習" if b.mode=="training" else "第%dラウンド" % b.round_number,Vector2(582,101),16,T.SUN,116,HORIZONTAL_ALIGNMENT_CENTER)

static func _keycap(b, key: String, rect: Rect2, available: bool, color: Color) -> void:
	_poly(b,PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end-Vector2(5,0),rect.position+Vector2(-5,rect.size.y)]),color if available else T.CREAM,T.NAVY,1.5)
	_fit_label(b,key,rect.position+Vector2(0,rect.size.y-6),20,T.NAVY,rect.size.x-3,HORIZONTAL_ALIGNMENT_CENTER)

## Read the active body's authored labels. A full Qi rail does not supply a
## missing air/upper super; the footer is informational and changes no controls.
static func _unsupported_super_use(fighter_id: String, label: String) -> String:
	var key: String=fighter_id+":"+label
	if unsupported_super_uses.has(key): return str(unsupported_super_uses[key])
	var use := ""
	for event in PlayableTimeline.definition(fighter_id,label).get("events",[]):
		for call in event.get("calls",[]):
			if call.get("supported",false) and str(call.get("method",""))=="doWanKai": use="変身（未対応）"
	unsupported_super_uses[key]=use
	return use

static func resource_action_state(b, side: int) -> Dictionary:
	var actor=b.fighters[side]
	var entries: Array[Dictionary]=[]
	var major: String=_sidebar_key(b,side,8)
	var candidates: Array[Dictionary]=[]
	candidates.assign([
		{"command":"super","label":"必杀","input":major,"cost":100},
		{"command":"super_up","label":"上必杀","input":_sidebar_key(b,side,2)+"+"+major,"cost":100},
		{"command":"super_down","label":"超必杀","input":_sidebar_key(b,side,3)+"+"+major,"cost":300},
	] if actor.grounded else [{"command":"air_super","label":"空中必杀","input":"空中 "+major,"cost":100}])
	var one_bar: Array[String]=[]
	var three_bar: Array[String]=[]
	var unavailable: Array[String]=[]
	for entry in candidates:
		var binding: Dictionary=load("res://game/bvn_skill_bindings.gd").binding_for(str(actor.fighter_id),str(entry.command)) if b.source_bindings_enabled else {}
		if b.source_bindings_enabled:
			if binding.is_empty(): continue
			entry["name"]=str(binding["name_ja"])
			entry["cost"]=int(binding["cost"])
		elif not actor.source_has_label(str(entry.label)): continue
		entry["use"]="" if b.source_bindings_enabled else _unsupported_super_use(str(actor.fighter_id),str(entry.label))
		entry["implemented"]=str(entry.use).is_empty()
		entries.append(entry)
		if not entry.implemented:
			unavailable.append(str(entry.input)+"："+str(entry.use))
			continue
		if int(entry.cost)==100: one_bar.append(str(entry.input))
		else: three_bar.append(str(entry.input))
	var costs: Array[String]=[]
	if not one_bar.is_empty(): costs.append("/".join(one_bar)+"：1格")
	if not three_bar.is_empty(): costs.append(" / ".join(three_bar)+"：3格")
	costs.append_array(unavailable)
	var transformation_use: String="" if b.source_bindings_enabled else _unsupported_super_use(str(actor.fighter_id),"万解")
	if actor.grounded and not transformation_use.is_empty(): costs.append(transformation_use)
	var available: bool=not one_bar.is_empty() or not three_bar.is_empty()
	var prop_available: bool=true
	if actor.authored_skills_enabled and actor.fighter_id=="chicken":
		prop_available=bool(actor.authored_visual_state().get("ball_in_hand",true))
	for entry in entries: entry["prop_available"]=prop_available
	var minimum: int=100 if not one_bar.is_empty() else 300
	var ready: bool=available and prop_available and float(actor.hype)>=minimum
	return {"grounded":actor.grounded,"entries":entries,"available":available,"prop_available":prop_available,"ready":ready,
		"caption":"ボール回収中" if not prop_available else (("必殺可" if ready else "必殺 %d格" % (minimum/100)) if available else "空中なし"),
		"footer":"ボール回収後に必殺可" if not prop_available else ("  ".join(costs) if available else "空中必殺なし"), "transformation_use":transformation_use}

static func directional_super_binding(b, side: int) -> String:
	var inputs: Array[String]=[]
	for entry in resource_action_state(b,side).entries:
		if str(entry.command) in ["super_up","super_down"] and entry.get("implemented",true): inputs.append(str(entry.input))
	return " / ".join(inputs) if not inputs.is_empty() else "—"

## Fixed corner instruments. The center floor and training footer stay clear.
## Labels and the three Qi segments occupy separate rows, without changing
## resources, source permissions, actor placement or the camera.
static func resource_rail_layout(b, side: int) -> Dictionary:
	var actor=b.fighters[side]
	var qi: float=clampf(float(actor.hype),0,HitRules.QI_MAX)
	var resource: Dictionary=resource_action_state(b,side)
	var x: float=18.0 if side==0 else 1280.0-18.0-RESOURCE_RAIL_WIDTH
	# Enough Qi is not the same as a current source permission: during hurt,
	# getup and recovery the command can still be forbidden. Describe Qi only.
	var caption: String="気OK" if resource.ready else "気不足"
	if not bool(resource.available):
		caption="未対応" if resource.entries.any(func(entry: Dictionary) -> bool: return not bool(entry.implemented)) else ("空中×" if not actor.grounded else "必殺×")
	if not bool(resource.get("prop_available",true)): caption="回収中"
	if actor.authored_is_active() and actor.action in ["super","super_down","super_up"]: caption="必殺中"
	return {"rect":Rect2(x,RESOURCE_RAIL_Y,RESOURCE_RAIL_WIDTH,RESOURCE_RAIL_HEIGHT),
		"qi_rect":Rect2(x+8,RESOURCE_RAIL_Y,114,25),
		"gauge_rect":Rect2(x+8,RESOURCE_RAIL_Y+26,RESOURCE_RAIL_WIDTH-16,14),
		"gauge_layer":"separate",
		"super_rect":Rect2(x+132,RESOURCE_RAIL_Y,160,25),
		"burst_rect":Rect2(x+300,RESOURCE_RAIL_Y,86,25),
		"font_size":RESOURCE_RAIL_FONT,"baseline":RESOURCE_RAIL_Y+21,"qi":qi,
		"qi_text":"気%d/300" % floori(qi),"super_text":_sidebar_key(b,side,8)+" "+caption,
		"burst_text":_sidebar_key(b,side,9)+(" ○" if actor.can_hurt_break() else " ×"),
		"super_ready":resource.ready,"super_available":resource.available,"escape_available":actor.can_hurt_break(),
		"caption":caption,"entries":resource.entries,"cost_details":resource.footer}

static func _draw_meter(b, side: int, ink: Color) -> void:
	var layout: Dictionary=resource_rail_layout(b,side)
	var rect: Rect2=layout.rect
	_poly(b,PackedVector2Array([rect.position+Vector2(5,0),rect.position+Vector2(rect.size.x,0),rect.end-Vector2(5,0),rect.position+Vector2(0,rect.size.y)]),INK,T.CREAM,1.5)
	var gauge: Rect2=layout.gauge_rect
	var segment_width: float=(gauge.size.x-6)/3
	for segment in range(3):
		var part: float=clampf((float(layout.qi)-segment*100)/100,0,1)
		var tx: float=gauge.position.x+(segment if side==0 else 2-segment)*(segment_width+3)
		var fill: float=segment_width*part
		b.draw_rect(Rect2(tx,gauge.position.y,segment_width,gauge.size.y),EMPTY)
		# Each completed100Qi segment is a full gold block, with real partial fill.
		b.draw_rect(Rect2(tx if side==0 else tx+segment_width-fill,gauge.position.y,fill,gauge.size.y),T.SUN if part>=1 else ink)
		b.draw_line(Vector2(tx,gauge.position.y),Vector2(tx+segment_width,gauge.position.y),Color(T.CREAM,.24),1,true)
		if fill>0:
			var start: float=tx if side==0 else tx+segment_width-fill
			b.draw_line(Vector2(start,gauge.position.y),Vector2(start+fill,gauge.position.y),T.SUN if part>=1 else ink,2,true)
	for item in [[layout.qi_text,layout.qi_rect,HORIZONTAL_ALIGNMENT_LEFT,T.CREAM],
		[layout.super_text,layout.super_rect,HORIZONTAL_ALIGNMENT_CENTER,T.SUN if layout.super_ready else T.CREAM],
		[layout.burst_text,layout.burst_rect,HORIZONTAL_ALIGNMENT_CENTER,T.SUN if layout.escape_available else T.CREAM]]:
		var area: Rect2=item[1]
		var at:=Vector2(area.position.x,layout.baseline)
		b.draw_string_outline(b.font,at,str(item[0]),int(item[2]),area.size.x,RESOURCE_RAIL_FONT,2,INK)
		_label(b,str(item[0]),at,RESOURCE_RAIL_FONT,item[3],area.size.x,int(item[2]))

## Cue and combo sit under the top instruments, above the compact key guide.
## Pure screen-space placement: no camera, timer or source-action writes.
static func caption_anchor(_side: int) -> Dictionary:
	return {"at":Vector2(496,166),"width":288.0}

static func combo_layout(side: int) -> Dictionary:
	return {"rect":Rect2(292 if side==0 else 786,143,202,86),"number_width":72.0}

static func _draw_combo(b, count: int, damage: int, side: int) -> void:
	var layout: Dictionary=combo_layout(side)
	var rect: Rect2=layout.rect
	var ink: Color=T.CORAL if side==0 else T.SEA
	b.draw_set_transform(rect.position)
	var number: String=str(count)
	var size:=60
	while size>32 and b.font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>72: size-=1
	b.draw_string_outline(b.font,Vector2(0,58),number,HORIZONTAL_ALIGNMENT_CENTER,72,size,6,INK)
	b.draw_string_outline(b.font,Vector2(0,58),number,HORIZONTAL_ALIGNMENT_CENTER,72,size,2,T.CREAM)
	_label(b,number,Vector2(0,58),size,T.SUN,72,HORIZONTAL_ALIGNMENT_CENTER)
	b.draw_string_outline(b.font,Vector2(82,29),"連撃",HORIZONTAL_ALIGNMENT_LEFT,120,25,3,INK)
	_label(b,"連撃",Vector2(82,29),25,T.CREAM,120)
	var damage_text: String="%d ダメージ" % damage
	b.draw_string_outline(b.font,Vector2(82,55),damage_text,HORIZONTAL_ALIGNMENT_LEFT,120,18,3,INK)
	_fit_label(b,damage_text,Vector2(82,55),18,T.CREAM,120)
	b.draw_line(Vector2(83,64),Vector2(201,64),INK,5,true)
	b.draw_line(Vector2(83,64),Vector2(201,64),ink,2,true)
	b.draw_set_transform(Vector2.ZERO)

static func _sidebar_key(b, side: int, slot: int) -> String:
	var code: int=int(b.key_bindings[side][slot])
	if not sidebar_key_names.has(code):
		var text: String=OS.get_keycode_string(code)
		sidebar_key_names[code]=str(SIDEBAR_KEY_ALIASES.get(text,text))
	return str(sidebar_key_names[code])

## Expose the displayed current bindings for the native sidebar verification.
static func control_sidebar_rows(b) -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	var names := ["移動","上方向","下・防御","攻撃","ジャンプ","瞬歩","技","必殺","脱出"]
	var slots := [-1,2,3,4,5,6,7,8,9]
	for index in range(names.size()):
		var row := {"name":names[index],"keys":[]}
		for side in range(2):
			var key: String=_sidebar_key(b,side,0)+"/"+_sidebar_key(b,side,1) if index==0 else _sidebar_key(b,side,slots[index])
			row["keys"].append(key)
		rows.append(row)
	return rows

## Preserve legibility instead of shrinking long bindings to 8px at 800x600.
## Direction arrows refer to the actual up/down keys in the basic rows above.
static func _sidebar_binding_lines(b, value: String, width: float, directional: bool=false) -> Array[String]:
	if directional:
		for side in range(2):
			var up: String=_sidebar_key(b,side,2)
			var down: String=_sidebar_key(b,side,3)
			var major: String=_sidebar_key(b,side,8)
			value=value.replace(up+"+"+major+" / "+down+"+"+major,up+"/"+down+"+"+major)
		if b.font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,CONTROL_LABEL_SIZE).x>width-4:
			for side in range(2):
				value=value.replace(_sidebar_key(b,side,2)+"/"+_sidebar_key(b,side,3)+"+","↑/↓+")
				value=value.replace(_sidebar_key(b,side,2)+"+","↑+").replace(_sidebar_key(b,side,3)+"+","↓+")
			if b.font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,CONTROL_LABEL_SIZE).x>width-4 and value.contains("+"):
				# Keep the chord sign next to the direction; a long rebound key
				# has the full next line instead of losing space to that sign.
				return [value.get_slice("+",0).replace("/","")+"+",value.get_slice("+",1)]
	elif value.contains("/") and b.font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,CONTROL_LABEL_SIZE).x>width-4:
		var parts: PackedStringArray=value.split("/",false,1)
		return [parts[0],parts[1]]
	return [value]

static func _control_text(value: String, at: Vector2, size: int, width: float=-1, alignment: int=HORIZONTAL_ALIGNMENT_LEFT) -> Dictionary:
	return {"text":value,"at":at,"size":size,"width":width,"alignment":alignment}

static func _sidebar_binding_commands(b, value: String, rect: Rect2, directional: bool=false) -> Array[Dictionary]:
	var commands: Array[Dictionary]=[]
	var lines: Array[String]=_sidebar_binding_lines(b,value,rect.size.x,directional)
	for index in range(lines.size()):
		var size: int=CONTROL_KEY_SIZE if lines.size()==1 else CONTROL_LABEL_SIZE
		while size>CONTROL_LABEL_SIZE and b.font.get_string_size(lines[index],HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>rect.size.x-4: size-=1
		var baseline: float=rect.position.y+rect.size.y*.5+float(size)*.34
		if lines.size()>1: baseline=rect.position.y+20+index*24
		commands.append(_control_text(lines[index],Vector2(rect.position.x,baseline),size,rect.size.x,HORIZONTAL_ALIGNMENT_CENTER))
	return commands

static func control_extra_notes(b) -> Array[String]:
	var notes: Array[String]=["上／下攻撃：キャラ別"]
	var actor=b.fighters[0]
	# Both caught-object entry labels and source catch slots exist in all five
	# profiles; this is an input hint, never a promise of a successful grab.
	if actor.source_has_label("摔1") and actor.source_has_label("摔2"):
		notes.append("横＋攻撃/技：密着投げ" if b.source_bindings_enabled else "横＋攻撃：密着投げ")
	notes.append("空中技：キャラ別")
	# The current formal air defaults do not universally expose jumpDown.
	if not actor.grounded and actor.command_enabled("fastfall"):
		notes.append("空中 ↓＋跳ぶ：急降下")
	return notes

static func _overlay_label(b, value: String, at: Vector2, size: int, opacity: float, width: float=-1, alignment: int=HORIZONTAL_ALIGNMENT_LEFT) -> void:
	# Both ink and outline yield when a body crosses a mandatory key label.
	b.draw_string_outline(b.font,at,value,alignment,width,size,3,Color(0.02,0.03,0.05,CONTROL_OUTLINE_OPACITY if opacity>=.99 else opacity*.875))
	b.draw_string(b.font,at,value,alignment,width,size,Color(1,1,1,opacity))

static func control_overlay_opacity(b) -> float:
	var area: Rect2=control_visible_rect
	for actor in b.fighters:
		var body: Rect2=actor.body_box()
		if actor.is_attacking(): body=body.grow(150)
		if b.world_rect_to_screen(body).intersects(area): return CONTROL_MIN_OPACITY
	for release in b.skill_releases:
		var position: Vector2=release.get("pos",Vector2.ZERO)
		var owner: int=int(release.get("owner",-1))
		if owner>=0 and owner<b.fighters.size() and b.fighters[owner].is_attacking(): position=b.fighters[owner].position
		var major: bool=str(release.get("move","")).begins_with("super")
		var reach: Vector2=Vector2(700,500) if major else Vector2(430,340)
		var center: Vector2=position+Vector2(float(release.get("facing",1))*reach.x*.22,-reach.y*.5)
		if b.world_rect_to_screen(Rect2(center-reach*.5,reach)).intersects(area): return CONTROL_MIN_OPACITY
	return 1.0

## The formal body collider can be narrower than the visible head/arms. Read
## the same foot origin and body_height passed to the pixel renderer, then
## conservatively contain its silhouette instead of testing only that collider.
## No full pose sampling, actor-position cache key, or reserved stage column.
static func control_actor_screen_rect(b, actor) -> Rect2:
	var height: float=float(actor.body_height)
	if not actor.source_runtime_enabled and actor.pixel_script:
		height=float(actor.pixel_script._load_rig(actor.fighter_id).get("rig",{}).get("world_height",height))
	var width: float=height*(1.8 if actor.fighter_id=="shark" else .95)
	return b.world_rect_to_screen(Rect2(actor.position+Vector2(-width*.5,-height*1.12),Vector2(width,height*1.17)))

static func control_details_occluded(b) -> bool:
	if control_detail_rect.size.x<=0 or control_detail_rect.size.y<=0:
		return false
	for actor in b.fighters:
		if actor.visible and control_actor_screen_rect(b,actor).intersects(control_detail_rect):
			return true
	return false

## Compact rows keep every input visible while reserving no stage column.
## Each pair is measured with the current font and wraps as a whole, so a
## rebound Backspace / PageDown key remains readable rather than clipped.
static func _compact_control_groups(b) -> Array:
	var p:=0
	var up: String=_sidebar_key(b,p,2)
	var down: String=_sidebar_key(b,p,3)
	var skill: String=_sidebar_key(b,p,7)
	var major: String=_sidebar_key(b,p,8)
	return [
		[{"name":"移動","key":_sidebar_key(b,p,0)+"/"+_sidebar_key(b,p,1)},{"name":"上方向","key":up}],
		[{"name":"下・防御","key":down},{"name":"攻撃","key":_sidebar_key(b,p,4)}],
		[{"name":"ジャンプ","key":_sidebar_key(b,p,5)},{"name":"瞬歩","key":_sidebar_key(b,p,6)},{"name":"脱出","key":_sidebar_key(b,p,9)}],
		[{"name":"技","key":skill},{"name":"下技","key":down+"+"+skill},{"name":"上技","key":up+"+"+skill}],
		[{"name":"必殺","key":major},{"name":"上必殺","key":up+"+"+major},{"name":"気100","key":""}],
		[{"name":"超必殺","key":down+"+"+major},{"name":"気300","key":""}],
		[{"name":"空中技","key":skill},{"name":"空中必殺","key":major}],
	]

static func _compact_control_layout(b) -> Array[Dictionary]:
	var commands: Array[Dictionary]=[]
	commands.append(_control_text("操作 1P",Vector2(18,264),CONTROL_KEY_SIZE))
	commands.append(_control_text("F3 詳細"+("・2P" if b.mode=="local" else ""),Vector2(164,264),CONTROL_LABEL_SIZE,172,HORIZONTAL_ALIGNMENT_RIGHT))
	var cursor:=295.0
	for group: Array in _compact_control_groups(b):
		var x:=18.0
		for entry: Dictionary in group:
			var label: String=entry.name
			var key: String=entry.key
			var label_width: float=b.font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,CONTROL_LABEL_SIZE).x
			var key_width: float=b.font.get_string_size(key,HORIZONTAL_ALIGNMENT_LEFT,-1,CONTROL_KEY_SIZE).x
			var pair_width: float=label_width+(8+key_width if not key.is_empty() else 0)
			if x>18 and x+pair_width>CONTROL_SIDEBAR.end.x:
				x=18;cursor+=30
			commands.append(_control_text(label,Vector2(x,cursor),CONTROL_LABEL_SIZE,label_width+1))
			if not key.is_empty(): commands.append(_control_text(key,Vector2(x+label_width+8,cursor),CONTROL_KEY_SIZE,key_width+1))
			x+=pair_width+18
		cursor+=30
	control_detail_rect=Rect2()
	control_visible_rect=Rect2(18,244,318,cursor-244)
	return _measure_control_bounds(b,commands)

static func control_visibility(b) -> int:
	var value: Variant = b.get("controls_visibility")
	if value is int: return clampi(int(value), 0, 2)
	return 2 if bool(b.show_controls) else 1

static func _build_control_layout(b) -> Array[Dictionary]:
	var mode: int = control_visibility(b)
	if mode == 0:
		control_detail_rect = Rect2()
		control_visible_rect = Rect2()
		return []
	if mode == 1: return _compact_control_layout(b)
	var commands: Array[Dictionary]=[]
	var local: bool=b.mode=="local"
	commands.append(_control_text("操作・F3 閉じる",Vector2(18,264),CONTROL_LABEL_SIZE,318))
	var columns: Array[Rect2]=[]
	if local: columns.assign([Rect2(116,0,102,30),Rect2(226,0,110,30)])
	else: columns.append(Rect2(116,0,220,30))
	for side in range(columns.size()):
		var col: Rect2=columns[side]
		commands.append(_control_text("1P" if side==0 else "2P",Vector2(col.position.x,291),CONTROL_KEY_SIZE,col.size.x,HORIZONTAL_ALIGNMENT_CENTER))
	var rows: Array[Dictionary]=control_sidebar_rows(b)
	var cursor: float=298
	for row in rows:
		var height: float=30
		for side in range(columns.size()):
			if _sidebar_binding_lines(b,str(row["keys"][side]),columns[side].size.x).size()>1: height=48
		commands.append(_control_text(str(row["name"]),Vector2(18,cursor+height*.5+7),CONTROL_LABEL_SIZE,94))
		for side in range(columns.size()):
			var col: Rect2=columns[side]
			commands.append_array(_sidebar_binding_commands(b,str(row["keys"][side]),Rect2(col.position.x,cursor,col.size.x,height)))
		cursor+=height
	var first_detail: int=commands.size()
	commands.append(_control_text("方向技・気を使い分け" if b.source_bindings_enabled else "方向派生はキャラ別",Vector2(18,cursor+32),CONTROL_LABEL_SIZE,318))
	cursor+=43
	var derivative_names := ["攻撃","技","必殺"]
	for index in range(3):
		var values: Array[String]=[]
		var height: float=30
		for side in range(columns.size()):
			var value: String=directional_super_binding(b,side) if index==2 else _sidebar_key(b,side,2)+"/"+_sidebar_key(b,side,3)+"+"+_sidebar_key(b,side,[4,7][index])
			values.append(value)
			if _sidebar_binding_lines(b,value,columns[side].size.x,true).size()>1: height=48
		commands.append(_control_text(derivative_names[index],Vector2(18,cursor+height*.5+7),CONTROL_LABEL_SIZE,94))
		for side in range(columns.size()):
			var col: Rect2=columns[side]
			commands.append_array(_sidebar_binding_commands(b,values[side],Rect2(col.position.x,cursor,col.size.x,height),true))
		cursor+=height
	for note: String in control_extra_notes(b):
		if cursor+33>810: break
		commands.append(_control_text(note,Vector2(18,cursor+33),CONTROL_LABEL_SIZE,318))
		cursor+=28
	control_detail_rect=Rect2()
	control_visible_rect=Rect2(18,244,318,cursor-244+12)
	for index in range(first_detail,commands.size()):
		var command: Dictionary=commands[index]
		command["detail"]=true
		var size: int=int(command.size)
		var width: float=b.font.get_string_size(command.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		var x: float=command.at.x
		if int(command.alignment)==HORIZONTAL_ALIGNMENT_CENTER: x+=(float(command.width)-width)*.5
		var text_rect:=Rect2(Vector2(x,command.at.y-b.font.get_ascent(size)),Vector2(width,b.font.get_height(size))).grow(4)
		control_detail_rect=text_rect if control_detail_rect.size==Vector2.ZERO else control_detail_rect.merge(text_rect)
	return _measure_control_bounds(b,commands)

static func _measure_control_bounds(b, commands: Array[Dictionary]) -> Array[Dictionary]:
	var rows: Dictionary={}
	for command: Dictionary in commands:
		var size: int=int(command.size)
		var extent: float=b.font.get_string_size(command.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		var x: float=command.at.x
		if int(command.alignment)==HORIZONTAL_ALIGNMENT_CENTER: x+=(float(command.width)-extent)*.5
		elif int(command.alignment)==HORIZONTAL_ALIGNMENT_RIGHT: x+=float(command.width)-extent
		command["bounds"]=Rect2(Vector2(x,command.at.y-b.font.get_ascent(size)),Vector2(extent,b.font.get_height(size))).grow(4)
		var row: int=roundi(command.at.y)
		rows[row]=command.bounds if not rows.has(row) else rows[row].merge(command.bounds)
	for command: Dictionary in commands: command["row_bounds"]=rows[roundi(command.at.y)]
	return commands

static func _control_occlusion_regions(b) -> Array[Rect2]:
	var regions: Array[Rect2]=[]
	for actor in b.fighters:
		if actor.visible: regions.append(control_actor_screen_rect(b,actor))
	for release in b.skill_releases:
		var position: Vector2=release.get("pos",Vector2.ZERO)
		var owner: int=int(release.get("owner",-1))
		if owner>=0 and owner<b.fighters.size() and b.fighters[owner].is_attacking(): position=b.fighters[owner].position
		var major: bool=str(release.get("move","")).begins_with("super")
		var reach: Vector2=Vector2(700,500) if major else Vector2(430,340)
		var center: Vector2=position+Vector2(float(release.get("facing",1))*reach.x*.22,-reach.y*.5)
		regions.append(b.world_rect_to_screen(Rect2(center-reach*.5,reach)))
	return regions

static func _invalidate_control_font() -> void:
	control_layout_signature.clear()

static func _control_signature(b) -> Array:
	# Own the binding values: an in-place rebinding must not also mutate the
	# saved signature. Resource state and occlusion are deliberately absent.
	var first=b.fighters[0]
	return [b.font.get_instance_id(),b.key_bindings.duplicate(true),b.mode=="local",control_visibility(b),
		str(first.fighter_id),str(b.fighters[1].fighter_id),bool(b.source_bindings_enabled),bool(first.grounded),bool(b.fighters[1].grounded),
		control_visibility(b) == 2 and not first.grounded and first.command_enabled("fastfall")]

static func _draw_controls(b) -> void:
	if control_visibility(b) == 0:
		control_detail_rect = Rect2()
		control_visible_rect = Rect2()
		return
	if control_layout_font!=b.font:
		if control_layout_font and control_layout_font.changed.is_connected(_invalidate_control_font):
			control_layout_font.changed.disconnect(_invalidate_control_font)
		control_layout_font=b.font
		control_layout_font.changed.connect(_invalidate_control_font)
		control_layout_signature.clear()
	var signature: Array=_control_signature(b)
	if signature!=control_layout_signature:
		control_layout_commands=_build_control_layout(b)
		control_layout_signature=signature
	# Only layout is retained. Moving bodies/releases still fade this exact
	# text immediately, and training observations are read elsewhere each draw.
	var regions: Array[Rect2]=_control_occlusion_regions(b)
	for command: Dictionary in control_layout_commands:
		var covered:=false
		var optional: bool=bool(command.get("detail",false))
		var bounds: Rect2=command.row_bounds if optional else command.bounds
		for region: Rect2 in regions:
			if region.intersects(bounds): covered=true;break
		# Fold only the optional text directly over a performer or effect.
		# Clear rows retain their full contrast even if another row is covered.
		if covered and optional: continue
		_overlay_label(b,command.text,command.at,int(command.size),CONTROL_MIN_OPACITY if covered else 1.0,float(command.width),int(command.alignment))

static func training_panel_state(b) -> Dictionary:
	var sparring: bool = b.training_recipe == "sparring"
	var difficulty: String = str({"easy":"かんたん", "normal":"ふつう", "hard":"むずかしい"}.get(b.difficulty, "ふつう"))
	var progress: Dictionary = b.get_training_progress() if b.has_method("get_training_progress") else {"stage":b.training_stage,"total":0,"status":"ready","steps":[]}
	var lesson: bool = b.training_recipe in ["full_normal", "hit_confirm"]
	var next_input := "課題を確認"
	var stage: int = int(progress.get("stage", b.training_stage))
	var total: int = int(progress.get("total", 0))
	if lesson:
		var steps: Array = progress.get("steps", [])
		if stage < steps.size():
			var step: Dictionary = steps[stage]
			next_input = "自動追撃を確認" if int(step.get("key_slot", -1)) < 0 else "次 " + training_step_binding(b, step) + " を当てる"
		if str(progress.get("status", "")) == "complete":
			next_input = "課題達成"
		elif str(progress.get("status", "")) == "failed":
			next_input = "Rでやり直し"
	var title: String = {"full_normal":"通常攻撃・全段", "hit_confirm":"命中からの派生"}.get(b.training_recipe, "トレーニング")
	var display_message: String = str(b.training_message)
	if lesson:
		# Keep the live source result, but avoid shrinking the resource/retry
		# explanation and a long route into one unreadable 4:3 line.
		match str(progress.get("status", "ready")):
			"ready": display_message = "一段ずつ命中を確認" if b.training_recipe == "full_normal" else "命中を見て派生を確認"
			"complete": display_message = "全%d段の命中を確認！" % total if b.training_recipe == "full_normal" else "命中と派生を確認！"
			"running": display_message = "最初の命中を確認しよう" if stage == 0 else ("命中を確認・自動追撃を待とう" if next_input == "自動追撃を確認" else "命中を確認・許可中に次を入力")
			"failed":
				if display_message.contains("ガード"): display_message = "ガード・耐えられました。Rで再挑戦"
				elif display_message.contains("順番"): display_message = "入力の順番を確認。Rで再挑戦"
				elif display_message.contains("中断"): display_message = "攻撃が中断されました。Rで再挑戦"
				else: display_message = "間合い・命中・次の許可を確認。Rで再挑戦"
	return {"sparring":sparring, "lesson":lesson, "title":"実戦練習" if sparring else title, "difficulty":"CPU："+difficulty, "message":str(b.training_message), "display_message":display_message, "footer":"R リセット / KOで再開 / ESC ポーズ" if sparring else ("気300開始・以後は実戦同様 / Rリセット / Tガード" if lesson else "R リセット / T ガード / ESC ポーズ"), "show_steps":not sparring, "stage":stage, "total":total, "progress":progress, "next_input":next_input}


static func training_step_binding(b, step: Dictionary) -> String:
	var slot: int = int(step.get("key_slot", -1))
	if slot < 0: return "自動追撃"
	var keys: Array[String] = []
	for modifier: Variant in step.get("modifiers", []): keys.append(_sidebar_key(b,0,int(modifier)))
	keys.append(_sidebar_key(b,0,slot))
	return ("空中 " if str(step.get("command", "")).begins_with("air_") else "") + "+".join(keys)


## Read the live action/resource gates, not the last impact's historical message.
## endAct is only an observation of recovery: range, bullets and invulnerability
## still matter. This presentation never predicts a guaranteed punish or combo.
static func training_live_state(b) -> Dictionary:
	var player=b.fighters[0]
	var opponent=b.fighters[1]
	var energy: int=floori(clampf(float(player.energy),0,100))
	var guard_key: String=_sidebar_key(b,0,3)
	var attack_key: String=_sidebar_key(b,0,4)
	var result := {"left":"体力 %d  %s 防御" % [energy,guard_key],"right":attack_key+" 攻撃・間合いを確認","kind":"neutral","resource_warning":false,"afterlag":false,"energy":energy,"guard_key":guard_key,"attack_key":attack_key,"hurt_break_key":_sidebar_key(b,0,9)}
	if player.energy_overload:
		result["left"]="過負荷：距離を取ろう"
		result["resource_warning"]=true
	elif energy<=20:
		result["left"]="体力 %d：防御継続に注意" % energy
		result["resource_warning"]=true
	elif player.guarding or player.state=="guard_stun":
		result["left"]="防御中・体力 %d" % energy
	if b.paused or b.phase!="active" or b.cinema_time>0:
		result["kind"]="waiting"
		result["right"]="ポーズ中" if b.paused else ("必殺演出中" if b.cinema_time>0 else "再開を待とう")
		return result
	if player.hp<=0 or opponent.hp<=0:
		result["kind"]="ko"; result["right"]="次の勝負へ"
		return result
	if player.is_combo_locked():
		result["kind"]="hurt"; result["right"]="被ダメージ中"
		if player.can_hurt_break(): result["left"]=result["hurt_break_key"]+" / LB 脱出可・気100"
		return result
	if player.state=="guard_stun":
		result["kind"]="guard_stun"; result["right"]="ガード硬直中"
		return result
	# Releasing defense enters the source DEFENSE_RESUME before idle restores
	# J/K/L permissions. state=guard is not covered by is_locked().
	if player.state=="guard" and not bool(player.last_intent.get("guard",false)):
		result["kind"]="guard_resume"; result["right"]="防御を戻し中：行動待ち"
		return result
	if player.is_locked() or player.is_protected():
		result["kind"]="self_locked"
		result["right"]="自分の後隙：行動待ち" if player.end_act_reached() else "自分の動作中"
		return result
	# A released bullet/trap can outlive its owner's endAct. Do not offer an
	# offensive cue while that opponent-owned object is still in the world.
	if b.playable_world:
		for object in b.playable_world.objects:
			# Read current allegiance after reflection and current source regions;
			# the owner's recovery/next move never determines object lifetime.
			if object.removed or object.owner_index!=1: continue
			for hit: Dictionary in object.hits():
				var area: Rect2=hit.get("area",Rect2())
				if not area.has_area(): continue
				result["kind"]="projectile"
				result["right"]="飛び道具にも注意" if object.kind=="bullet" else "残る攻撃にも注意"
				return result
	for projectile: Dictionary in b.projectiles:
		if int(projectile.get("owner",-1))==1 and float(projectile.get("life",0))>0:
			result["kind"]="projectile"; result["right"]="飛び道具にも注意"
			return result
	if opponent.is_attacking():
		if opponent.end_act_reached() and not opponent._hit_frame_active() and not opponent.is_protected():
			result["kind"]="recovery"; result["right"]="後隙 / 距離を確認"; result["afterlag"]=true
		elif opponent._hit_frame_active():
			result["kind"]="active"; result["right"]="攻撃中："+guard_key+" 防御"
		elif opponent.action_time<float(opponent.action_data.get("startup",.1)):
			result["kind"]="startup"; result["right"]="相手は技の準備中"
		else:
			result["kind"]="acting"; result["right"]="相手は動作中"
	elif opponent.guarding or opponent.state=="guard_stun":
		result["kind"]="guard"; result["right"]="相手はガード中"
	elif opponent.is_combo_locked():
		result["kind"]="opponent_hurt"; result["right"]="相手がよろけ中"
	return result


static func _draw_training(b) -> void:
	var up: String=_key(b,0,2)
	var down: String=_key(b,0,3)
	var attack: String=_key(b,0,4)
	var skill: String=_key(b,0,7)
	var super_key: String=_key(b,0,8)
	var labels := {"attack":attack,"attack1":attack,"attack2":attack,"attack3":attack,"attack4":attack,"attack5":attack,"sweep":down+"+"+attack,"launcher":up+"+"+attack,"jump":_key(b,0,5),"dash":_key(b,0,6),"air_light":"空中"+attack,"air_slam":"空中"+down+"+"+skill,"air_skill":"空中"+skill,"skill1":skill,"skill2":up+"+"+skill,"skill3":down+"+"+skill,"super":super_key,"super_up":up+"+"+super_key,"super_down":down+"+"+super_key,"hurt_break":_key(b,0,9),"burst":_key(b,0,9)}
	_poly(b,PackedVector2Array([Vector2(423,619),Vector2(862,619),Vector2(855,705),Vector2(416,705)]),INK,T.CREAM,1.5)
	_poly(b,PackedVector2Array([Vector2(423,619),Vector2(593,619),Vector2(588,644),Vector2(420,644)]),T.SEA)
	var panel: Dictionary=training_panel_state(b)
	_label(b,panel["title"],Vector2(432,639),18,T.NAVY)
	if panel["sparring"]:
		_label(b,panel["difficulty"],Vector2(602,639),16,T.CREAM,240,HORIZONTAL_ALIGNMENT_RIGHT)
		var live: Dictionary=training_live_state(b)
		_fit_label(b,live["left"],Vector2(432,662),15,T.CREAM,229)
		_fit_label(b,live["right"],Vector2(668,662),15,T.CREAM,176,HORIZONTAL_ALIGNMENT_RIGHT)
		if live["resource_warning"]: b.draw_line(Vector2(432,666),Vector2(653,666),T.CORAL,3,true)
		if live["afterlag"]: b.draw_line(Vector2(670,666),Vector2(844,666),T.SUN,3,true)
		_fit_label(b,panel["message"],Vector2(432,690),17,T.CREAM,410,HORIZONTAL_ALIGNMENT_CENTER)
		_overlay_label(b,panel["footer"],Vector2(431,716),TRAINING_FOOTER_SIZE,1.0,414,HORIZONTAL_ALIGNMENT_CENTER)
		return
	var total: int = int(panel["total"])
	var stage: int = int(panel["stage"])
	if total <= 0:
		total = 3
		stage = b.training_stage
	_label(b,"%d / %d" % [stage,total],Vector2(628,639),18,T.CREAM,72,HORIZONTAL_ALIGNMENT_RIGHT)
	for step in range(total):
		var sx: float=752+step*20
		_poly(b,PackedVector2Array([Vector2(sx,626),Vector2(sx+6,632),Vector2(sx,638),Vector2(sx-6,632)]),T.SUN if stage>step else EMPTY,T.CREAM,1.5)
	_fit_label(b,panel["next_input"] if panel["lesson"] else "入力 "+str(labels.get(b.last_inputs[0],"―")),Vector2(432,663),18,T.CREAM,229)
	_label(b,"ガード "+("ON" if b.training_guard else "OFF"),Vector2(668,662),16,T.CREAM,176,HORIZONTAL_ALIGNMENT_RIGHT)
	_fit_label(b,panel["display_message"],Vector2(432,690),18,T.CREAM,410,HORIZONTAL_ALIGNMENT_CENTER)
	_overlay_label(b,panel["footer"],Vector2(431,716),TRAINING_FOOTER_SIZE,1.0,414,HORIZONTAL_ALIGNMENT_CENTER)
