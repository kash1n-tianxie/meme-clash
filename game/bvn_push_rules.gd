extends RefCounted
## Copyright (C) 2021-2026 5DPLAY Game Studio; Godot port (C) 2026.
## SPDX-License-Identifier: GPL-3.0-or-later
## GameMainLogicCtrl.as:186-309, BVN 891f5776dbdf3cbf40919e27aa8d6e77a5f66c97.
## Source move(vec) also multiplies SPEED_PLUS. Inputs/outputs here use source units.

static func fill_vec(value: float,a: Dictionary,b: Dictionary) -> Vector2:
	var rate:=clampf(float(b.get("heavy",2))/float(a.get("heavy",2))*.5,.1,.9)
	var result:=Vector2(value*rate,value*(1.0-rate))
	if a.get("touch_side",false) and b.get("touch_side",false): result=Vector2(value,value)
	elif a.get("touch_side",false): result=Vector2(0,value)
	elif b.get("touch_side",false): result=Vector2(value,0)
	return result

static func resolve(a: Dictionary,b: Dictionary,speed_plus: float=.5) -> Vector2:
	if a.get("cross",false) or b.get("cross",false): return Vector2.ZERO
	var body_a: Rect2=a.get("body",Rect2())
	var body_b: Rect2=b.get("body",Rect2())
	var overlap:=body_a.intersection(body_b)
	if overlap.size.x<=0 or overlap.size.y<=0: return Vector2.ZERO
	var av: float=a.get("velocity",0)
	var bv: float=b.get("velocity",0)
	var left: bool=float(a["x"])<float(b["x"])
	if left and ((av<0 and av<bv) or (bv>0 and bv>av)): return Vector2.ZERO
	if not left and ((av>0 and av>bv) or (bv<0 and bv<av)): return Vector2.ZERO
	var displacement:=Vector2.ZERO
	if overlap.size.x>2:
		var spread:=fill_vec(5.0*speed_plus,a,b)
		displacement+=Vector2(-spread.x,spread.y) if left else Vector2(spread.x,-spread.y)
	if av!=0:
		var motion:=fill_vec(av,a,b)
		displacement+=Vector2(-motion.x,motion.y)
	if bv!=0:
		var motion:=fill_vec(bv,a,b)
		displacement+=Vector2(motion.x,-motion.y)
	return displacement*speed_plus
