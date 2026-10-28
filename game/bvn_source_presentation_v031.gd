extends RefCounted
## Copyright (C) 2021-2026 5DPLAY Game Studio; Godot adaptation (C) 2026.
## SPDX-License-Identifier: GPL-3.0-or-later
## Drawing-only adapter of EffectShakeHandler / ShineEffectView. The character
## wrapper folds pulse X/Y into Y upstream; this version deliberately preserves
## the two supplied axes and the wrapper's2x pulse multiplier as requested. Stage units scale by the existing 1.6.
const FPS := 30.0
const STAGE_SCALE := 1.6
const POWER_MAX := 10.0
var holds: Dictionary = {}
var power := Vector2.ZERO
var lose := Vector2.ZERO
var direction := Vector2.ONE
var axis_frame := Vector2i.ZERO
var offset := Vector2.ZERO
var clock := 0.0
var elapsed := 0.0
var flashes: Array[Dictionary] = []
var flash_clock := 0.0
var flash_frame := 0
var trace: Array[Dictionary] = []

func reset() -> void:
	holds.clear();power=Vector2.ZERO;lose=Vector2.ZERO;direction=Vector2.ONE
	axis_frame=Vector2i.ZERO;offset=Vector2.ZERO;clock=0;elapsed=0
	flashes.clear();flash_clock=0;flash_frame=0;trace.clear()

static func argument(args: Array, index: int, fallback: Variant) -> Variant:
	return args[index] if index<args.size() and args[index]!=null else fallback

func event(owner: int, serial: int, method: String, args: Array) -> void:
	match method:
		"startShake":
			var axes:=Vector2(float(argument(args,0,0)),float(argument(args,1,3)))
			if axes.is_finite():holds[owner]={"serial":serial,"axes":axes.abs().min(Vector2.ONE*POWER_MAX)}
		"endShake":holds.erase(owner);_refresh_hold_offset()
		"shake":
			var axes:=Vector2(float(argument(args,0,0)),float(argument(args,1,3)))
			var duration:=float(argument(args,2,0))
			if axes.is_finite() and is_finite(duration):_pulse(axes*2.0,duration)
		"shine":
			var rgb:=int(argument(args,0,0xffffff)) & 0xffffff
			var dark:=rgb<=(0xffffff>>1)
			flashes.append({"color":Color.hex(rgb*256+255),"alpha":(.3 if rgb==0xffffff else .2)*(.8 if dark else 1.0),"source_rgb":rgb,"source_blend":"darken" if dark else "add"})
			if flashes.size()>8:flashes.pop_front()
		_:return
	if trace.size()<512:trace.append({"owner":owner,"serial":serial,"method":method,"arguments":args.duplicate(true),"presentation_time":elapsed})

func _pulse(axes: Vector2, duration: float) -> void:
	# Upstream rejects a weaker pulse, caps at10, and decays each second
	# animation frame. time=0 means the EffectShakeHandler default500ms.
	if power.x>absf(axes.x) or power.y>absf(axes.y):return
	for axis in range(2):
		if axes[axis]==0:continue
		if power[axis]==0:
			direction[axis]=signf(axes[axis]);power[axis]=absf(axes[axis])
		else:power[axis]+=absf(axes[axis])*.5
		power[axis]=minf(POWER_MAX,power[axis])
		lose[axis]=maxf(1.0,ceilf(power[axis]/((duration if duration>0 else .5)*FPS)))

func reconcile(actors: Array) -> void:
	# FighterMcCtrler.idle / doAction also end a held shake. A label branch in
	# the same accepted action must not end it; an interruption or new serial must.
	var ended:=false
	for owner: Variant in holds.keys():
		if int(owner)<0 or int(owner)>=actors.size():holds.erase(owner);ended=true;continue
		var actor: Variant=actors[int(owner)]
		if not actor.source_doing_action or int(actor.action_serial)!=int(holds[owner].serial):holds.erase(owner);ended=true
	if ended:_refresh_hold_offset()

func _refresh_hold_offset() -> void:
	var active:=power
	var held:=Vector2.ZERO
	for record: Dictionary in holds.values():held=held.max(record.axes)
	active+=held
	for axis in range(2):offset[axis]=signf(offset[axis])*active[axis]

func advance(delta: float, paused: bool=false) -> void:
	if paused or delta<=0:return
	elapsed+=delta;clock+=delta;flash_clock+=delta
	while clock+.0000001>=1.0/FPS:
		clock-=1.0/FPS;_animate()
	while flash_clock+.0000001>=1.0/60.0:
		flash_clock-=1.0/60.0;flash_frame+=1
		# FPS_GAME60 / FPS_SHINE_EFFECT15 gives renderGap3, loseAlpha4%.
		if flash_frame%3==0:
			for flash: Dictionary in flashes:flash.alpha=float(flash.alpha)-.04
			flashes=flashes.filter(func(flash: Dictionary)->bool:return float(flash.alpha)>.05)

func _animate() -> void:
	var hold:=Vector2.ZERO
	for record: Dictionary in holds.values():hold=hold.max(record.axes)
	for axis in range(2):
		var amount:=hold[axis]+power[axis]
		if amount<=0:offset[axis]=0;continue
		offset[axis]=amount*direction[axis] if amount>0 else 0.0
		if power[axis]>0 and axis_frame[axis]%2==0:
			power[axis]=maxf(0.0,power[axis]-lose[axis])
			if power[axis]<lose[axis]:power[axis]=0;axis_frame[axis]=0;lose[axis]=0
		axis_frame[axis]+=1;direction[axis]*=-1
		# A pulse finishing must not cancel an independently held shake.
		if hold[axis]==0 and power[axis]==0:offset[axis]=0

func sample_shake() -> Vector2:
	# Remove ended holders immediately, rather than retaining their last displacement.
	var active:=Vector2.ZERO
	for record: Dictionary in holds.values():active=active.max(record.axes)
	active+=power
	return Vector2(offset.x if active.x>0 else 0.0,offset.y if active.y>0 else 0.0)*STAGE_SCALE

func contact_shake(amplitude: float) -> Vector2:
	# Local deterministic oscillation never consumes the combat/AI RNG stream.
	var tick:=int(floor(elapsed*60.0))
	return Vector2(sin(float(tick)*2.399)*5.0,cos(float(tick)*1.731)*3.0)*amplitude
