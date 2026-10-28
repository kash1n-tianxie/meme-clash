extends RefCounted
## Exact OpenBVN3.4 EffectModel/EffectCtrler freeze selector.
## SPDX-License-Identifier: GPL-3.0-or-later
## OpenBleachVsNaruto@4d7bc9913ec6b609ba521ff86b6066bff134a736:
## EffectModel.as114–325/374–424, EffectCtrler.as291–361/471–485.
const FPS_GAME := 60
const HIT_FREEZE := {1:50,2:50,3:400,4:50,5:400,6:400,7:400,8:400,9:400,11:400}

static func frames_for_ms(time_ms: int, fps_game: int = FPS_GAME, enabled: bool = true) -> int:
	# AS3 int conversion truncates; source ignores zero/sub-frame requests.
	if not enabled or time_ms < 1: return 0
	return maxi(0,int(float(time_ms)/1000.0*fps_game))

static func select(hit_type: int, outcome: String, defense_type: int = 0) -> Dictionary:
	var effect_id := ""
	var freeze_ms := 0
	var selected_type := hit_type
	if outcome == "counter":
		# FighterMcCtrler.beHit1456–1460 branches before any effect call.
		return {"ready":true,"effect_id":"","freeze_ms":0,"frames":0,"effect_type":hit_type}
	if outcome == "guard_break":
		# doBreakDefense1955–1956: guard first, then break_def replaces freeze.
		effect_id="break_def"; freeze_ms=500
	elif outcome == "steel":
		if hit_type != 0:
			effect_id="steel_hit_kan" if hit_type in [1,6] else "steel_hit_qdj" if hit_type in [2,3] else "steel_hit_mfdj"
			freeze_ms=400
	elif outcome == "guard":
		if defense_type == 1:
			if hit_type == 1: selected_type=2
			elif hit_type == 6: selected_type=3
		if selected_type != 0:
			# NONE has no effect; every unregistered nonzero guard falls back to5.
			if not selected_type in [1,2,3,4,5,6,7,8,9]: selected_type=5
			effect_id="defense_%d" % selected_type
			freeze_ms=int(HIT_FREEZE[selected_type])
	elif HIT_FREEZE.has(hit_type):
		effect_id="hit_%d" % hit_type; freeze_ms=int(HIT_FREEZE[hit_type])
	return {"ready":true,"effect_id":effect_id,"freeze_ms":freeze_ms,"frames":frames_for_ms(freeze_ms),"effect_type":selected_type}

static func from_contact(source: Dictionary, result: Dictionary, defense_type: int = 0, enabled: bool = true) -> Dictionary:
	var exact: Variant=source.get("source_hit_vo",null)
	if not exact is Dictionary or not exact.has("hitType"):
		return {"ready":false} # Existing legacy fallback remains separate.
	if not bool(result.get("hit",false)):
		return {"ready":true,"effect_id":"","freeze_ms":0,"frames":0}
	var outcome := "hit"
	if bool(result.get("blocked",false)): outcome="guard"
	elif bool(result.get("armor",false)): outcome="steel"
	elif str(result.get("reaction",""))=="hurt_action": outcome="counter"
	elif bool(result.get("guard_break",false)): outcome="guard_break"
	var effect := select(int(exact["hitType"]),outcome,defense_type)
	if not enabled: effect["frames"]=0
	return effect
