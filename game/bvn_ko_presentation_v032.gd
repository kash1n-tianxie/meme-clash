extends RefCounted
## Copyright (C) 2021-2026 5DPLAY Game Studio; Godot adaptation (C) 2026.
## SPDX-License-Identifier: GPL-3.0-or-later
## Ground ordinary KO presentation only: literal pinned MC-before-hurt counters.
## HP, winner, input lock, actor/source state, label and all physics stay intact.
## The existing corpse deceleration still differs from the original .1 -> 2;
## missing GameEndCtrler parameters are not guessed or added here.
var record: Dictionary = {}

func reset() -> void:
	record.clear()

func begin(stun_frames: int, hit_type: int, source_generation: int) -> bool:
	# The real ordinary settlement has minimum4. Do not invent a hold from HP0.
	if not record.is_empty() or stun_frames < 4: return false
	record = {"ready":true, "stage":"hold", "hold_remaining":stun_frames,
		"initial_hold":stun_frames, "delay_remaining":-1, "animation_callbacks":0,
		"hurt_animation_frame":0, "hurt_animation_stopped":hit_type == 11,
		"source_generation":source_generation, "floor_emitted":false}
	return true

func step(animation_boundary: bool, grounded: bool, eligible: bool) -> Dictionary:
	if record.is_empty(): return {}
	# This deliberately excludes air conversion, live recovery and flying KO.
	if not eligible or not grounded:
		reset()
		return {}
	if not animation_boundary or str(record.stage) == "dead": return {}
	record.animation_callbacks = int(record.animation_callbacks) + 1
	# FighterMcCtrler.renderAnimate runs FighterMC BEFORE renderHurtAnimate.
	match str(record.stage):
		"down":
			record.stage = "dead" # case4 !alive returns before the15-frame timer.
		"bounce":
			var previous_delay: int = int(record.delay_remaining)
			record.delay_remaining = previous_delay - 1
			if previous_delay <= 0: record.stage = "down"
		"hold":
			if not bool(record.hurt_animation_stopped):
				record.hurt_animation_frame = mini(7, int(record.hurt_animation_frame) + 1)
			var previous_hold: int = int(record.hold_remaining)
			record.hold_remaining = previous_hold - 1
			if previous_hold <= 0:
				record.stage = "bounce"
				record.delay_remaining = 2 # delay-- <=0 takes3 FUTURE MC callbacks.
				record.floor_emitted = true
				return {"event":"ground_ko_down", "type":1, "strength":2.0,
					"ko_callback":int(record.animation_callbacks), "ko_initial_hold":int(record.initial_hold)}
	return {}

func snapshot() -> Dictionary:
	return record.duplicate()
