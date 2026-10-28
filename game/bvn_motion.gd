extends RefCounted
## Copyright (C) 2021-2024 5DPLAY Game Studio; Godot port (C) 2026.
## SPDX-License-Identifier: GPL-3.0-or-later
## BaseGameSprite.as:247-255,357-390,524-555 and GameConfig.as:35-39,152-153.
## Official BVN commit 891f5776dbdf3cbf40919e27aa8d6e77a5f66c97.
## Flash uses per-tick velocity and SPEED_PLUS=.5 at 60Hz; Godot stores px/sec.
## The conversion preserves the source's separate impulse, damping and gravity.

const LOGIC_FPS := 60.0
const ANIMATION_FPS := 30.0
const STAGE_SCALE := 1.6
const SPEED_PLUS := ANIMATION_FPS/LOGIC_FPS
const VELOCITY_UNIT := ANIMATION_FPS*STAGE_SCALE
const G := 12.0
const G_ADD := 1.2
const G_ON_FLOOR := 4.0
var gravity := G_ON_FLOOR

func reset(on_floor: bool=true) -> void:
	gravity=G_ON_FLOOR if on_floor else 0.0

func step_horizontal(velocity_x: float,delta: float,damping_x: float=0.0) -> Dictionary:
	var movement:=velocity_x*delta
	var next:=move_toward(velocity_x,0.0,damping_x*SPEED_PLUS*2.0*VELOCITY_UNIT*delta*LOGIC_FPS)
	return {"displacement":movement,"velocity":next}

## A single fixed physics tick is the source's renderVelocity+applayG update.
## Source y damping is linear weaken(), rather than an exponential lerp.
func step_vertical(velocity_y: float,delta: float,damping_y: float=.5,apply_gravity: bool=true) -> Dictionary:
	var frame_units:=delta*LOGIC_FPS
	var source_velocity:=velocity_y/VELOCITY_UNIT
	var movement:=source_velocity*SPEED_PLUS*STAGE_SCALE*frame_units
	# GameMainLogicCtrl.applayG runs before BaseGameSprite.renderVelocity damping.
	if not apply_gravity or source_velocity<0:
		gravity=0.0
	else:
		gravity=minf(G,gravity+G_ADD*SPEED_PLUS*frame_units)
		movement+=gravity*SPEED_PLUS*STAGE_SCALE*frame_units
	if damping_y>0:
		source_velocity=move_toward(source_velocity,0.0,damping_y*SPEED_PLUS*2.0*frame_units)
	return {"displacement":movement,"velocity":source_velocity*VELOCITY_UNIT,"gravity":gravity*VELOCITY_UNIT}
