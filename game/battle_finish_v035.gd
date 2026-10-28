extends RefCounted
## Post-KO presentation only. The receipt comes from an actual fatal contact;
## this layer never resolves hits, spends qi or promotes a hit to a final hit.
var receipt: Dictionary = {}
var age: float = 0.0
var kind: String = ""

func reset() -> void:
	receipt.clear(); age=0.0; kind=""

func begin(contact: Dictionary, winner: int, loser_hp: float) -> bool:
	reset()
	if winner<0 or loser_hp>0 or contact.is_empty(): return false
	if int(contact.get("owner",-1))!=winner or not bool(contact.get("fatal",false)): return false
	if contact.get("outcome","") not in ["hit","guard_break"] or int(contact.get("tier",0))<2: return false
	receipt=contact.duplicate(true)
	kind="super_ko" if int(receipt.tier)>=3 else "skill_ko"
	return true

func advance(delta: float) -> void:
	if not kind.is_empty(): age+=maxf(0.0,delta)

func contact_hold() -> bool:
	return not kind.is_empty() and age<(.18 if kind=="super_ko" else .12)

func victory_ready() -> bool:
	return kind.is_empty() or age>=1.05

func draw_overlay(battle: Node2D) -> void:
	if kind.is_empty(): return
	var major: bool=kind=="super_ko"
	var ink:=Color("152c46")
	var cream:=Color("fff6df")
	var accent: Color=Color("ffdc59") if major else Color("82dddf")
	var id: String=str(receipt.get("fighter_id",""))
	var motion: float=0.0 if battle.reduced_motion else 1.0
	var impact_alpha: float=clampf(1.0-age/1.1,0.0,1.0)
	# Keep the actual bodies readable throughout the hit hold and tail.
	battle.draw_rect(Rect2(0,145,1280,759),Color(ink,.22*impact_alpha))
	var point: Vector2=battle.world_to_screen(receipt.get("pos",Vector2(640,600)))
	if age<.78:
		var spread: float=70.0+age*95.0*motion
		for i in range(8):
			var angle: float=i*TAU/8.0
			var at: Vector2=point+Vector2(cos(angle),sin(angle))*(spread+24)
			if id=="wojak":
				battle._text(["!","?","※","!"][i%4],at,36 if i%2 else 52,Color(cream,impact_alpha))
			elif id=="worker":
				battle.draw_set_transform(at,angle*.2)
				battle.draw_rect(Rect2(-15,-20,30,40),Color(cream,impact_alpha))
				battle.draw_line(Vector2(-9,-8),Vector2(9,-8),Color(ink,impact_alpha),2)
				battle.draw_line(Vector2(-9,0),Vector2(5,0),Color(ink,impact_alpha),2)
				battle.draw_set_transform(Vector2.ZERO)
			else:
				battle.draw_line(at,at+Vector2(cos(angle),sin(angle))*30,Color(accent,impact_alpha),4)
	var arrive: float=clampf(age/.16,0.0,1.0)
	var exit_tail: float=clampf((age-.85)/.24,0.0,1.0)
	var y: float=lerpf(333.0,183.0,exit_tail)
	var height: float=lerpf(128.0,80.0,exit_tail)
	var slide: float=(1.0-arrive)*100.0*motion
	var band:=PackedVector2Array([Vector2(-slide,y+22),Vector2(1280-slide,y),Vector2(1280-slide,y+height-20),Vector2(-slide,y+height)])
	battle.draw_colored_polygon(band,Color(ink,.94))
	battle.draw_line(Vector2(0,y+21),Vector2(1280,y),accent,4)
	var title: String="SUPER K.O.!!" if major else "SKILL K.O.!"
	var size: int=int(lerpf(64,39,exit_tail))
	battle._hud_text(title,Vector2(-slide,y+height*.62),size,accent,1280,HORIZONTAL_ALIGNMENT_CENTER)
	var formal: String=str(receipt.get("title",""))
	var tail_label: String="終撃命中" if bool(receipt.get("finisher",false)) else "決着の一撃"
	if age<1.05:
		battle._hud_text(formal+"  /  "+tail_label,Vector2(0,y+height-9),22,cream,1280,HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var winner: int=int(receipt.owner)
		battle._hud_text(battle.fighters[winner].display_name+" の勝ち！",Vector2(0,316),30,ink,1280,HORIZONTAL_ALIGNMENT_CENTER)
