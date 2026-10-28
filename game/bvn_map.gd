# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2021-2024, 5DPLAY Game Studio. Original GameCamera author: kyo (2011).
# GDScript adaptation of MapMain, FloorVO, MapLayer, GameCamera and GameLogic.
# Source: https://github.com/5DPLAY-Game-Studio/BleachVsNaruto
# Commit: 891f5776dbdf3cbf40919e27aa8d6e77a5f66c97
# This program is free software: redistribute/modify under GNU GPL v3 or later.
# Provided WITHOUT ANY WARRANTY; see the included GNU GPL license.
# Flash MovieClip metadata is supplied explicitly by configure(); source formulas
# and their non-zero-bounds conventions are preserved, rather than replaced by
# Godot Camera2D heuristics. This module does not draw or modify stage artwork.
extends RefCounted

const UPSTREAM_COMMIT := "891f5776dbdf3cbf40919e27aa8d6e77a5f66c97"
const UPSTREAM_URL := "https://github.com/5DPLAY-Game-Studio/BleachVsNaruto"
const LAYER_ORDER := ["bg", "map", "fighters", "front_fix", "front"]

var left := 0.0
var right := 0.0
var bottom := 0.0
var player_bottom := 0.0
var p1pos := Vector2.ZERO
var p2pos := Vector2.ZERO
var screen_size := Vector2(800,600)
var stage_size := Vector2(800,600)
var side_offset := 10.0 # GameConfig.as:95, not a fighter radius.
var focus_x := true
var focus_y := true
var offset_x := 0.0
var offset_y := 0.0
var auto_zoom := true
var auto_zoom_min := 1.0
var auto_zoom_max := 2.5
var tween_speed := 5 # 2.5 / (FPS_ANIMATE30 / FPS_GAME60), GameStage.as:490.
var fix_border := true
var stage_bounds := Rect2(0,-1000,800,600)
var _zoom := 1.0
var _stage_scale := 1.0
var _rect := Rect2(0,0,800,600)
var _target_rect := Rect2(0,0,800,600)
var _border_min := Vector2.ZERO
var _border_max := Vector2.ZERO
var _focus: Array[Vector2] = []
var _manual_point := Vector2.INF
var _floors: Array[Dictionary] = []
var _layers: Dictionary = {}
var _optical_frames: Dictionary = {}
var _optical_alpha: Dictionary = {}

## Marker names mirror MapMain.initialize: line_left/right/bottom/player_bottom,
## p1/p2, floor:[{xFrom,xTo,y}], layers:{map/front/front_fix/bg:Vector2}.
## Scalar line values replace a Flash DisplayObject.x or .y. Missing markers
## stay zero exactly as upstream. Supply actual stage geometry; never infer it
## from image pixels. One call establishes new map/camera state.
func configure(markers: Dictionary, viewport_size: Vector2=Vector2(800,600), map_layer_size: Vector2=Vector2(800,600)) -> void:
	assert(viewport_size.x>0 and viewport_size.y>0)
	assert(map_layer_size.x>0)
	screen_size=viewport_size
	stage_size=Vector2(map_layer_size.x,screen_size.y) # MapMain.as:252-254.
	left=float(markers.get("line_left",0.0))
	right=float(markers.get("line_right",0.0))
	bottom=float(markers.get("line_bottom",0.0))
	player_bottom=float(markers.get("line_player_bottom",0.0))
	p1pos=_point(markers.get("p1",Vector2.ZERO))
	p2pos=_point(markers.get("p2",Vector2.ZERO))
	var y_offset=screen_size.y-bottom # MapMain.as:212-241.
	bottom+=y_offset
	player_bottom+=y_offset
	if markers.has("p1"): p1pos.y+=y_offset
	if markers.has("p2"): p2pos.y+=y_offset
	_floors.clear()
	for value: Dictionary in markers.get("floor",[]):
		_floors.append({"xFrom":float(value.get("xFrom",0)),"xTo":float(value.get("xTo",0)),"y":float(value.get("y",0))+y_offset})
	_layers.clear()
	var layer_positions: Dictionary=markers.get("layers",{})
	for name: String in ["bg","map","front","front_fix"]:
		if not layer_positions.has(name): continue
		var position=_point(layer_positions[name])
		if name!="bg": position.y+=y_offset
		_layers[name]=position
	offset_y=get_map_bottom_distance()
	stage_bounds=Rect2(0,-1000,stage_size.x,stage_size.y) # GameStage.as:489.
	_rect=Rect2(Vector2.ZERO,screen_size)
	_target_rect=_rect
	_zoom=1.0
	_stage_scale=1.0
	_focus.clear()
	_manual_point=Vector2.INF
	_optical_frames.clear()
	_optical_alpha.clear()
	set_zoom(1.0)

static func _point(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Vector2i: return Vector2(value)
	if value is Array and value.size()>=2: return Vector2(float(value[0]),float(value[1]))
	return Vector2.ZERO

func get_stage_size() -> Vector2:
	return stage_size

func get_map_bottom_distance() -> float:
	return bottom-player_bottom

## MapMain.as:260-267 / FloorVO.as:35-37. Strict ends and speed band;
## touching an exact platform edge is not a hit, and zero speed never hits.
func get_floor_hit_test(x: float, y: float, speed: float) -> Dictionary:
	for floor_data: Dictionary in _floors:
		if y>float(floor_data["y"])-speed and y<float(floor_data["y"])+speed and x>float(floor_data["xFrom"]) and x<float(floor_data["xTo"]):
			return floor_data.duplicate()
	return {}

func get_screen_rect(with_tween: bool=false) -> Rect2:
	return _rect if with_tween else _target_rect

func get_zoom(with_tween: bool=false) -> float:
	return _stage_scale if with_tween else _zoom

func set_stage_bounds(value: Rect2) -> void:
	stage_bounds=value
	set_zoom(_zoom)

## GameCamera.as:162-179. Bounds.x/y are multiplied by target zoom and
## width/height hold the maximum scroll value, not Rect2.end. Preserve this
## source convention for parity; use zero horizontal origin with this stage.
func set_zoom(value: float) -> void:
	assert(value>0.0)
	_zoom=value
	_target_rect.size=screen_size/_zoom
	_border_min=stage_bounds.position*_zoom
	_border_max=stage_bounds.size-screen_size/_zoom

func set_camera_x(value: float) -> void:
	if fix_border:
		if value<_border_min.x: value=_border_min.x
		if value>_border_max.x: value=_border_max.x
	_target_rect.position.x=value
	if tween_speed>1: _rect.position.x+=(value-_rect.position.x)/float(tween_speed)
	else: _rect.position.x=value

func set_camera_y(value: float) -> void:
	if fix_border:
		if value<_border_min.y: value=_border_min.y
		if value>_border_max.y: value=_border_max.y
	_target_rect.position.y=value
	if tween_speed>1: _rect.position.y+=(value-_rect.position.y)/float(tween_speed)
	else: _rect.position.y=value

func focus(points: Array) -> void:
	_focus.clear()
	for point: Variant in points: _focus.append(_point(point))
	_manual_point=Vector2.INF

func move_camera(point: Vector2) -> void:
	_focus.clear()
	_manual_point=point

func move_center() -> void:
	move_camera(stage_size*.5)

## Call once per upstream-equivalent logic tick. There is intentionally no delta
## exponential filter: GameCamera.as uses a fixed per-render divisor. For more
## than two focuses it uses the first and last only, as the AS3 implementation.
func step_camera(points: Array=[], no_tween: bool=false) -> Dictionary:
	if not points.is_empty(): focus(points)
	if _focus.is_empty() and _manual_point==Vector2.INF: return get_camera_state()
	var old_tween=tween_speed
	if no_tween: tween_speed=0
	var point: Vector2=_manual_point if _focus.is_empty() else _focus[0]
	if _focus.size()>1:
		var a: Vector2=_focus[0]
		var b: Vector2=_focus[-1]
		var distance=Vector2(absf(b.x-a.x),absf(b.y-a.y))
		if focus_x: point.x=minf(a.x,b.x)+distance.x*.5
		if focus_y: point.y=minf(a.y,b.y)+distance.y*.5
		if auto_zoom:
			var zoom_x=_zoom
			var zoom_y=_zoom
			if focus_x: zoom_x=screen_size.x/distance.x*.8 if distance.x!=0 else INF
			if focus_y: zoom_y=screen_size.y/distance.y*.8 if distance.y!=0 else INF
			set_zoom(clampf(minf(zoom_x,zoom_y),auto_zoom_min,auto_zoom_max))
	if focus_x: set_camera_x(point.x-screen_size.x*.5/_zoom-offset_x)
	if focus_y: set_camera_y(point.y-screen_size.y*.5/_zoom-offset_y)
	if _stage_scale!=_zoom:
		if tween_speed>1: _stage_scale+=(_zoom-_stage_scale)/float(tween_speed)
		else: _stage_scale=_zoom
		# Source `(screen / scale + 1) >> 0`: truncate positive coordinates.
		_rect.size=Vector2(int(screen_size.x/_stage_scale+1),int(screen_size.y/_stage_scale+1))
	tween_speed=old_tween
	return get_camera_state()

func update_now() -> Dictionary:
	return step_camera([],true)

func get_world_transform() -> Transform2D:
	return Transform2D(Vector2(_stage_scale,0),Vector2(0,_stage_scale),-_rect.position*_stage_scale)

## GameStage.as:105-113. HUD/popups can project world anchors using this API;
## render-only shake can be added by the caller after this official transform.
func world_to_screen(point: Vector2) -> Vector2:
	return (point-_rect.position)*_stage_scale

func screen_to_world(point: Vector2) -> Vector2:
	return point/_stage_scale+_rect.position

## MapMain.as:270-295 + GameStage.as:210-225. bg stays outside the camera.
## front_fix stays in world coordinates; front adds 0.1 scroll parallax and
## clamps its local y to no less than the original normalized placement.
func get_layer_states() -> Dictionary:
	var states: Dictionary={}
	for name: String in _layers:
		var position: Vector2=_layers[name]
		if name=="front":
			position.x+=(-_rect.position.x)*.1
			position.y=maxf(position.y,position.y+(-_rect.position.y+bottom)*.1)
		var local=Transform2D(0,position)
		states[name]={"position":position,"camera_affected":name!="bg","transform":local if name=="bg" else get_world_transform()*local,"order":LAYER_ORDER.find(name)}
	states["fighters"]={"position":Vector2.ZERO,"camera_affected":true,"transform":get_world_transform(),"order":2}
	return states

## MapLayer.as:133-177,315-337. Prop rectangles must already be in the same
## world coordinates as sprite getArea() rectangles. Per-layer two-tick update.
## This is usable only with separate foreground props, not a flattened PNG.
func update_foreground_optical(layer_name: String, props: Array, sprite_areas: Array, smoothing: bool=false) -> Array:
	if smoothing: return _optical_alpha.get(layer_name,[])
	var frame=int(_optical_frames.get(layer_name,0))+1
	_optical_frames[layer_name]=frame
	if frame<2: return _optical_alpha.get(layer_name,[])
	_optical_frames[layer_name]=0
	var alpha: Array=[]
	for prop: Rect2 in props:
		var value=1.0
		for area: Rect2 in sprite_areas:
			if area.has_area() and prop.intersects(area): value=.5;break
		alpha.append(value)
	_optical_alpha[layer_name]=alpha
	return alpha

## Direct GameLogic.as:296-342 port. Position is the sprite origin, not its body
## radius. The target (non-tweened) camera rect constrains moving FighterMain
## only when target zoom reaches autoZoomMin. Rendering remains tweened.
func fix_sprite_position(position: Vector2, velocity_x: float=0.0, is_fighter: bool=true, allow_cross_xy: bool=false, allow_cross_bottom: bool=false) -> Dictionary:
	var fixed=position
	var min_x=left+side_offset
	var max_x=right-side_offset
	var touched=false
	if not allow_cross_xy:
		if is_fighter and velocity_x!=0.0 and _zoom==auto_zoom_min:
			var camera_left=_target_rect.position.x/_zoom+side_offset
			var camera_right=camera_left+_target_rect.size.x-side_offset
			if min_x<camera_left: min_x=camera_left
			if max_x>camera_right: max_x=camera_right
		if fixed.x<=min_x: fixed.x=min_x;touched=true
		if fixed.x>=max_x: fixed.x=max_x;touched=true
	if not allow_cross_bottom and fixed.y>bottom: fixed.y=bottom
	return {"position":fixed,"touch_side":touched,"touch_side_updated":not allow_cross_xy,"left":min_x,"right":max_x}

func get_camera_state() -> Dictionary:
	return {"source":"5DPLAY BVN GameCamera/MapMain","commit":UPSTREAM_COMMIT,"target_rect":_target_rect,"render_rect":_rect,"target_zoom":_zoom,"render_zoom":_stage_scale,"transform":get_world_transform(),"map_left":left,"map_right":right,"map_bottom":bottom,"player_bottom":player_bottom,"bottom_distance":get_map_bottom_distance(),"floor_count":_floors.size(),"layer_order":LAYER_ORDER}
