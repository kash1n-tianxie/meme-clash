extends RefCounted
const FrameFX=preload("res://game/bvn_frame_fx_v031.gd")
## v0.32 broken foam volumes, curved shore wash and source-owned ocean cels.
## Fixed subdivisions, no runtime textures, global random calls, extra hits or actor copies.
const AQUA := Color("19c7dc")
const LIGHT := Color("e8ffff")
const DEEP := Color("08486c")
const SEA := Color("087bba")
const FOAM_SHADOW := Color("166781")
const PATTERNS := {"U":"surging_tide_wall","SU":"low_rolling_breaker","WU":"rising_sea_column","AIR_U":"diagonal_waterfall","I":"great_wave_shark_jaw","WI":"spiral_ocean_vortex","SI":"tsunami_waterfall","AIR_I":"aerial_falling_cascade"}
const AMPLIFICATION := {"U":1.41,"SU":1.35,"WU":1.52,"AIR_U":1.44,"I":1.59,"WI":1.51,"SI":1.72,"AIR_I":1.58}
const MIN_HEIGHT_H := {"U":1.94,"SU":.96,"WU":2.04,"AIR_U":1.94,"I":2.72,"WI":1.50,"SI":3.22,"AIR_I":2.70}
const MIN_REAR_WIDTH_H := {"U":1.55,"SU":1.35,"I":2.10}
const OCEAN_ATLAS=preload("res://assets/fx/v037/shark/ocean-animation.png")
const OCEAN_CELL := 362.0
const ARC_SEGMENTS := 20
const SHEET_SEGMENTS := 12
static var _draw_observer:=Callable()
static var _ocean_indices:=PackedInt32Array()

static func amplification(state: Dictionary) -> Dictionary:
	var slot:=str(state.get("slot","U"));var scale:=float(AMPLIFICATION.get(slot,1.0))
	var h:=clampf(float(state.get("height",90.0)),1.0,4096.0)
	return {"ready":bool(state.get("ready",false)) and str(state.get("id",""))=="shark","id":"shark","slot":slot,"tier":int(state.get("tier",1)),"motif":PATTERNS.get(slot,"ocean_contact"),"visual_scale":scale,"extent":Vector2(h*maxf(scale,float(MIN_REAR_WIDTH_H.get(slot,0.0))),h*float(MIN_HEIGHT_H.get(slot,1.0))),"minimum_height_h":float(MIN_HEIGHT_H.get(slot,1.0)),"minimum_rear_width_h":float(MIN_REAR_WIDTH_H.get(slot,0.0)),"body_copies":0,"changes_source":false,"creates_contact":false,"source_owned":true,"horizontal_leading_edge_is_source_region":slot in ["U","SU","I"],"rotated_air_waterfall_is_decorative":slot=="AIR_U","fixed_mesh_quads":16,"mesh_vertices":25,"mesh_triangles":32,"cell_submission":"indexed_triangle_array","front_open_window":true}

static func set_draw_observer(callback: Callable=Callable()) -> void:
	_draw_observer=callback

static func ocean_vertex(target: Rect2,kind: String,sample: float,u: float,v: float) -> Vector2:
	# Flowing banks, a narrow falling throat and an expanding foot make the
	# waterfall a changing volume instead of a scaled rectangular picture.
	var width: float=.63+.35*sin(v*PI*.5) if kind=="waterfall" else .94+.06*sin(v*PI)
	var drift: float=sin(sample*.81+v*5.7)*.027*sin(v*PI)
	var x: float=.5+(u-.5)*width+drift
	var ripple: float=sin(u*TAU+sample*.83)*.012*sin(v*PI)
	# The lower shore rolls unevenly instead of exposing a rectangular base.
	# Clamp inside the original visual field; this never changes its HitVO.
	var wash: float=sin(u*TAU*1.7+sample*.71)*.035*pow(v,4.0)
	return target.position+target.size*Vector2(clampf(x,0,1),clampf(v+ripple+wash,0,1))

## Decorative vertices stop at the actual source floor; their paint fades out
## before that edge. Neither the source region nor its collision is modified.
static func floor_sample_v033(point: Vector2,floor_y: float,band: float) -> Vector3:
	if not is_finite(floor_y):return Vector3(point.x,point.y,1.0)
	var fade: float=clampf((floor_y-point.y)/maxf(1.0,band),0.0,1.0)
	fade=fade*fade*(3.0-2.0*fade)
	return Vector3(point.x,minf(point.y,floor_y),fade)

static func ocean_mesh(target: Rect2,kind: String,sample: float,region: Rect2,alpha: float,texture_size: Vector2,floor_y: float=INF,world_origin: Vector2=Vector2.ZERO,world_rotation: float=0.0,world_facing: float=1.0) -> Dictionary:
	# The original fixed 4 by 4 grid retains all pixel-center UVs and vertex
	# RGBA. Its 32 triangles now require only one command per painted cel.
	if _ocean_indices.is_empty():
		for row in range(4):
			for col in range(4):
				var a:=row*5+col;var b:=a+1;var c:=a+6;var d:=a+5
				_ocean_indices.append_array(PackedInt32Array([a,b,c,a,c,d]))
	var rows: Array[float]=[0.0,.20,.55,.84,1.0]
	var cols: Array[float]=[0.0,.12,.50,.88,1.0]
	var weights: Array[float]=[0.0,.87,1.0,.87,0.0]
	var vertical: Array[float]=[.0 if kind=="waterfall" else .68,.91,1.0,.87,0.0]
	var points:=PackedVector2Array();var uvs:=PackedVector2Array();var colors:=PackedColorArray()
	for row in range(5):
		for col in range(5):
			var point: Vector2=ocean_vertex(target,kind,sample,cols[col],rows[row])
			var floor_fade: float=1.0
			if is_finite(floor_y):
				var world: Vector2=world_origin+Vector2(point.x*world_facing,point.y).rotated(world_rotation)
				var shore: Vector3=floor_sample_v033(world,floor_y,maxf(6.0,target.size.y*.13))
				var local: Vector2=(Vector2(shore.x,shore.y)-world_origin).rotated(-world_rotation)
				point=Vector2(local.x*world_facing,local.y)
				floor_fade=shore.z
			points.append(point)
			uvs.append((region.position+Vector2(lerpf(.5,region.size.x-.5,cols[col]),lerpf(.5,region.size.y-.5,rows[row])))/texture_size)
			var edge_alpha: float=.76+.24*pow(sin(float(col)*1.7+sample*.42),2.0) if row>=3 else 1.0
			colors.append(_tint(Color.WHITE,alpha*weights[col]*vertical[row]*edge_alpha*floor_fade))
	return {"indices":_ocean_indices,"points":points,"uvs":uvs,"colors":colors,"quads":16,"triangles":32}

static func _ocean_frame(canvas: CanvasItem,bounds: Rect2,kind: String,sample: float,facing: float,alpha: float,rotation: float=0,crop: Rect2=Rect2(),floor_y: float=INF) -> void:
	if not bounds.has_area() or alpha<=.002:return
	var index: int=clampi(int(floor(sample)),0,5)
	var next: int=mini(index+1,5)
	var mix: float=clampf(sample-float(index),0,1)
	var start: int=0 if kind=="wave" else 6
	var target:=Rect2(-bounds.size*.5,bounds.size)
	canvas.draw_set_transform(bounds.get_center(),rotation,Vector2(facing,1))
	for cel in [index,next]:
		var amount: float=(1-mix if cel==index else mix)
		if index==next:amount=1.0
		var cell: int=start+cel
		var region:=Rect2(float(cell%4)*OCEAN_CELL,float(cell/4)*OCEAN_CELL,OCEAN_CELL,OCEAN_CELL)
		if crop.has_area():region=Rect2(region.position+crop.position*OCEAN_CELL,crop.size*OCEAN_CELL)
		if amount>.005:
			# The source clock owns both painted cels and the curved surface.
			var texture_size:=Vector2(OCEAN_ATLAS.get_width(),OCEAN_ATLAS.get_height())
			var mesh: Dictionary=ocean_mesh(target,kind,sample,region,alpha*amount,texture_size,floor_y,bounds.get_center(),rotation,facing)
			RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),mesh.indices,mesh.points,mesh.colors,mesh.uvs,PackedInt32Array(),PackedFloat32Array(),OCEAN_ATLAS.get_rid())
		if index==next:break
	canvas.draw_set_transform(Vector2.ZERO)

static func _ocean_pose(state: Dictionary,bounds: Rect2) -> Dictionary:
	var slot: String=str(state.get("slot",""))
	var h: float=float(state.get("height",90))
	var release: Dictionary=state.get("release_state",{})
	var style:=amplification(state)
	var frame: float=float(state.get("frame",0))+float(state.get("source_clock",0))*30.0
	var first: float=float(release.get("first",0))
	var floor_y: float=float(state.get("floor",bounds.end.y))
	var bottom: float=minf(bounds.end.y,floor_y)
	var visual:=Rect2(bounds.position,Vector2(bounds.size.x,maxf(8,bottom-bounds.position.y)))
	var kind: String="wave"
	var rotation: float=PI if slot=="WU" else 0.0
	var curtain: Dictionary={}
	var end: float=first+1
	for region: Dictionary in state.get("bundle",{}).get("regions",[]):end=maxf(end,float(region.get("end_exclusive",first+1)))
	var sample: float=clampf((frame-first)/maxf(1,end-first)*5.0,0,5)
	if slot in ["WU","AIR_U","SI","AIR_I"]:
		kind="waterfall"
		sample=fmod(maxf(0,frame-first)*.43,5.999)
		if sample>5:sample=10-sample
	if slot=="U":
		# The foam rises above this intentionally narrow original pressure HitVO.
		# Its horizontal leading edge remains inside the real source range.
		var height: float=maxf(bounds.size.y,h*float(style.minimum_height_h))
		visual=Rect2(bounds.position.x,bottom-height,bounds.size.x,height)
	elif slot=="I":
		var height: float=maxf(visual.size.y,h*float(style.minimum_height_h))
		visual=Rect2(bounds.position.x,bottom-height,bounds.size.x,height)
		sample=1.35+sample*.73
	elif slot=="SU":
		# The source low kick reaches through the floor. Its harmless foamy curl
		# remains above the stage, so that a low wave is still legible as sea water.
		var height: float=clampf(visual.size.y,h*float(style.minimum_height_h),h*1.46)
		visual=Rect2(bounds.position.x,bottom-height,bounds.size.x,height)
	elif slot=="WI":sample=fmod(maxf(0,frame-first)*.35,5.999);sample=minf(sample,5.0)
	elif slot=="AIR_U":
		# Air water starts at the actual face / kicking shoe and falls diagonally
		# FORWARD. It never grows an empty column above the airborne shark / HUD.
		var facing:=float(state.get("facing",1.0))
		var root: Vector2=state.get("position",bounds.get_center())
		var jaw:=_point(state,"jaw",root-Vector2(0,h*.55))
		var shoe:=_point(state,"front_foot",root)
		var width:=clampf(bounds.size.x,h*.72,h*1.10)
		rotation=-facing*.29
		var axis:=Vector2(facing*sin(.29),cos(.29))
		var origin:=jaw.lerp(shoe,.38)
		origin.y=maxf(origin.y,jaw.y+h*.075)+width*.5*sin(.29)
		var available:=maxf(8.0,(floor_y-origin.y-width*.5*sin(.29))/axis.y)
		var length:=minf(h*float(style.minimum_height_h),available)
		var center:=origin+axis*length*.5
		visual=Rect2(center-Vector2(width,length)*.5,Vector2(width,length))
		curtain={"origin":origin,"axis":axis,"length":length,"width":width,"decorative_only":true,"starts_below_actual_jaw":true,"source_collision_unchanged":true}
	elif slot in ["WU","SI","AIR_I"]:
		var height: float=maxf(visual.size.y,h*float(style.minimum_height_h))
		visual=Rect2(visual.position.x,bottom-height,visual.size.x,height)
	if slot in ["U","SU","I"]:
		# Width is added BEHIND the original range. The leading source HitVO edge
		# stays identical in both facings; a bigger wave never promises extra reach.
		var width:=maxf(visual.size.x,h*float(style.minimum_rear_width_h))
		var facing:=float(state.get("facing",1.0))
		visual=Rect2(bounds.end.x-width if facing>0.0 else bounds.position.x,visual.position.y,width,visual.size.y)
	return {"rect":visual,"kind":kind,"sample":sample,"rotation":rotation,"curtain":curtain}

static func _point(state: Dictionary,key: String,fallback: Vector2) -> Vector2:
	var found: Variant=state.get("anchors",{}).get(key,fallback)
	if found is Vector2:return found
	if found is Array and found.size()>=2:return Vector2(float(found[0]),float(found[1]))
	return fallback

static func _tint(color: Color,alpha: float) -> Color:
	return Color(color.r,color.g,color.b,clampf(alpha,0,1))

static func _line(canvas: CanvasItem,points: PackedVector2Array,width: float,color: Color,alpha: float,floor_y: float=INF,fade_band: float=8.0) -> void:
	if points.size()<2 or alpha<=.002:return
	if not is_finite(floor_y):
		canvas.draw_polyline(points,_tint(color,alpha),maxf(.7,width),true)
		return
	var bounded: PackedVector2Array=PackedVector2Array()
	var colors: PackedColorArray=PackedColorArray()
	for point: Vector2 in points:
		var shore: Vector3=floor_sample_v033(point,floor_y-maxf(.4,width*.5),fade_band)
		bounded.append(Vector2(shore.x,shore.y));colors.append(_tint(color,alpha*shore.z))
	canvas.draw_polyline_colors(bounded,colors,maxf(.7,width),true)

static func _poly(canvas: CanvasItem,points: PackedVector2Array,color: Color,alpha: float) -> void:
	if points.size()>2 and alpha>.002:canvas.draw_colored_polygon(points,_tint(color,alpha))

static func _bounds(state: Dictionary) -> Rect2:
	var result:=Rect2()
	for found: Variant in state.get("boxes",[]):
		if found is Rect2 and found.has_area():result=found if not result.has_area() else result.merge(found)
	return result

static func _strip_fill(canvas: CanvasItem,left: PackedVector2Array,right: PackedVector2Array,color: Color,alpha: float) -> void:
	# A hooked crest can fold over itself. Explicit strip triangles avoid a
	# self-intersecting polygon and never ask Canvas to triangulate that fold.
	for n in range(mini(left.size(),right.size())-1):
		var a: Vector2=left[n];var b: Vector2=left[n+1]
		var c: Vector2=right[n+1];var d: Vector2=right[n]
		if absf((b-a).cross(c-a))>1.0:_poly(canvas,PackedVector2Array([a,b,c]),color,alpha)
		if absf((c-a).cross(d-a))>1.0:_poly(canvas,PackedVector2Array([a,c,d]),color,alpha)

static func _arc(center: Vector2,radii: Vector2,start: float,end: float,rotation: float=0) -> PackedVector2Array:
	var points:=PackedVector2Array()
	# Geometry is deliberately bounded even for the source's very large SI field.
	for n in range(ARC_SEGMENTS+1):
		var a: float=lerpf(start,end,float(n)/float(ARC_SEGMENTS))
		var chop: float=1.0+.058*sin(a*7.0+.6)+.024*sin(a*13.0)
		points.append(center+Vector2(cos(a)*radii.x,sin(a)*radii.y).rotated(rotation)*chop)
	return points

static func _ellipse(canvas: CanvasItem,center: Vector2,radii: Vector2,start: float,end: float,width: float,color: Color,alpha: float,rotation: float=0) -> void:
	_line(canvas,_arc(center,radii,start,end,rotation),width,color,alpha)

static func _foam_edge(canvas: CanvasItem,path: PackedVector2Array,width: float,alpha: float) -> void:
	# Connected irregular foam paint has a broken, scalloped silhouette rather
	# than equally spaced dots or a single straight white laser line.
	if path.size()<3:return
	var inside:=PackedVector2Array();var outside:=PackedVector2Array()
	for n in range(path.size()):
		var tangent: Vector2=path[mini(n+1,path.size()-1)]-path[maxi(n-1,0)]
		var normal:=tangent.normalized().orthogonal()
		var thickness: float=width*(.46+.32*sin(float(n)*1.83)+.23*sin(float(n)*3.09+.5))
		inside.append(path[n]-normal*maxf(width*.19,thickness))
		outside.append(path[n]+normal*maxf(width*.28,thickness*.79))
	_strip_fill(canvas,outside,inside,FOAM_SHADOW,alpha*.96)
	_line(canvas,path,maxf(1.1,width*.35),LIGHT,alpha*.98)
	for n in range(2,path.size()-1,3):
		var tip: Vector2=outside[n].lerp(outside[n+1],.3)
		var tangent: Vector2=(path[n+1]-path[n-1]).normalized()
		_poly(canvas,PackedVector2Array([inside[n],outside[n],tip+tangent*width*.77,inside[n]+tangent*width*.43]),LIGHT,alpha*.97)

static func ribbon_mesh_v033(center: Vector2,radii: Vector2,start: float,end: float,thickness: float,alpha: float,front: bool=false,rotation: float=0.0,floor_y: float=INF,flow_sample: float=0.0) -> Dictionary:
	# A single four-row indexed surface has gaps, a scalloped crest and an
	# inward alpha falloff. It replaces the opaque geometric ring plus many
	# separately triangulated foam strips, retaining an open body center.
	var outside: PackedVector2Array=_arc(center,radii,start,end,rotation)
	var scales: Array[float]=[1.0,maxf(.20,1-thickness*.16),maxf(.20,1-thickness*.45),maxf(.14,1-thickness)]
	var strengths: Array[float]=[.27,.91,.26,0.0]
	if front:strengths.assign([.12,.76,.14,0.0])
	var points: PackedVector2Array=PackedVector2Array();points.resize((ARC_SEGMENTS+1)*4)
	var colors: PackedColorArray=PackedColorArray();colors.resize(points.size())
	var indices: PackedInt32Array=PackedInt32Array()
	for n in range(ARC_SEGMENTS+1):
		var t: float=float(n)/float(ARC_SEGMENTS)
		var fade: float=pow(maxf(0,sin(t*PI)),.43)
		if n in [6,8,13,15]:fade*=.36
		var radial: Vector2=outside[n]-center
		# Foam occupies broken moving bands within this exact fixed sheet. The
		# source sample, not wall time, opens the center and carries the highlights.
		var roll: float=.5+.5*sin(t*TAU*2.6-flow_sample*.77)
		var foam: float=.5+.5*sin(t*TAU*4.0+flow_sample*1.19)
		foam=foam*foam
		for row in range(4):
			var point: Vector2=center+radial*scales[row]
			var shore: Vector3=floor_sample_v033(point,floor_y,maxf(5.0,radii.y*.27))
			points[n*4+row]=Vector2(shore.x,shore.y)
			var color: Color=DEEP if row==0 else (LIGHT.lerp(AQUA,.12+.28*roll) if row==1 else (SEA.lerp(AQUA,.19+.24*roll) if row==2 else SEA))
			var breakup: float=.25+.34*roll if row==0 else (.08+.92*foam if row==1 else (.08+.34*roll*roll))
			colors[n*4+row]=_tint(color,alpha*fade*strengths[row]*breakup*shore.z)
		if n==ARC_SEGMENTS or n in [6,7,13,14]:continue
		for row in range(3):
			var a: int=n*4+row;var b: int=a+4
			indices.append_array(PackedInt32Array([a,b,b+1,a,b+1,a+1]))
	return {"indices":indices,"points":points,"colors":colors}

static func _ribbon(canvas: CanvasItem,center: Vector2,radii: Vector2,start: float,end: float,thickness: float,alpha: float,front: bool=false,rotation: float=0.0,floor_y: float=INF,flow_sample: float=0.0) -> void:
	if alpha<=.002:return
	var mesh: Dictionary=ribbon_mesh_v033(center,radii,start,end,thickness,alpha,front,rotation,floor_y,flow_sample)
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),mesh.indices,mesh.points,mesh.colors)

static func _droplet(canvas: CanvasItem,base: Vector2,axis: Vector2,size: float,alpha: float) -> void:
	var direction: Vector2=axis.normalized() if axis.length_squared()>.001 else Vector2.UP
	var normal: Vector2=direction.orthogonal()
	var points:=PackedVector2Array([base+direction*size*1.50,base+direction*size*.71+normal*size*.39,base+normal*size*.51,base-direction*size*.29+normal*size*.38,base-direction*size*.43,base-direction*size*.29-normal*size*.38,base-normal*size*.51,base+direction*size*.71-normal*size*.39])
	_poly(canvas,points,DEEP,alpha*.83)
	for n in range(points.size()):points[n]=base+(points[n]-base)*.78
	_poly(canvas,points,AQUA,alpha*.99)
	_poly(canvas,PackedVector2Array([base+normal*size*.13,base+direction*size*.88,base+direction*size*.36+normal*size*.24]),LIGHT,alpha*.94)

static func _breaker(canvas: CanvasItem,bounds: Rect2,facing: float,phase: float,alpha: float,front: bool=false,jaw: bool=false,floor_y: float=INF) -> void:
	if not bounds.has_area():return
	var length: float=bounds.size.x*(.72+.28*phase)
	var tall: float=bounds.size.y
	var start_x: float=bounds.position.x if facing>0 else bounds.end.x
	var base_y: float=bounds.end.y
	# A bespoke breaking-wave silhouette: low tail, steep face, heavy curled
	# crest and hooked hollow. The filled silhouette replaces the old beam bank.
	var outline:=PackedVector2Array([
		Vector2(0,.97),Vector2(.00,.83),Vector2(.14,.79),Vector2(.29,.65),
		Vector2(.42,.40),Vector2(.53,.19),Vector2(.67,.075),Vector2(.81,.045),
		Vector2(.94,.12),Vector2(1,.27),Vector2(.99,.39),Vector2(.91,.38),
		Vector2(.88,.28),Vector2(.80,.235),Vector2(.71,.26),Vector2(.665,.36),
		Vector2(.69,.465),Vector2(.79,.53),Vector2(.905,.51),Vector2(.96,.455),
		Vector2(.925,.625),Vector2(.82,.725),Vector2(.665,.73),Vector2(.55,.66),
		Vector2(.46,.73),Vector2(.50,.92),Vector2(.73,.98),
		Vector2(.59,.975),Vector2(.43,.945),Vector2(.29,.99),Vector2(.13,.945)])
	var world: PackedVector2Array=PackedVector2Array()
	var floor_weights: PackedFloat32Array=PackedFloat32Array()
	for n in range(outline.size()):
		var raw: Vector2=outline[n]
		var chop: float=sin(float(n)*1.7+phase*TAU)*.018 if n>1 and n<25 else 0.0
		var shore: Vector3=floor_sample_v033(Vector2(start_x+facing*raw.x*length,base_y+(raw.y-1+chop)*tall),floor_y,maxf(6.0,tall*.23))
		world.append(Vector2(shore.x,shore.y));floor_weights.append(shore.z)
	if not front:
		# SI's former two flat fills exposed a cyan wedge beneath the painted
		# waterfall and a hard geometric curl. Shade the existing water body
		# once, then let its uneven lower shore become fully transparent.
		var colors:=PackedColorArray()
		for n in range(world.size()):
			var raw: Vector2=outline[n]
			var shore: float=clampf((1.0-raw.y)/.34,0.0,1.0)
			shore=shore*shore*(3.0-2.0*shore)
			var crest: float=clampf((.40-raw.y)/.34,0.0,1.0)
			var lit: Color=SEA.lerp(AQUA,crest*.43)
			if n>=12 and n<=19:lit=lit.lerp(DEEP,.46)
			if n>=25:shore*=.10
			colors.append(_tint(lit,alpha*shore*.60*floor_weights[n]))
		canvas.draw_polygon(world,colors)
		var flow:=PackedVector2Array()
		for n in range(2,25):
			var raw: Vector2=outline[n]
			flow.append(Vector2(start_x+facing*(raw.x-.016)*length,base_y+(raw.y-1)*tall+tall*.09))
		_line(canvas,flow,maxf(2,tall*.047),AQUA,alpha*.27,floor_y,maxf(6.0,tall*.23))
		var curl:=PackedVector2Array()
		for n in range(12,20):curl.append(world[n])
		_line(canvas,curl,maxf(1.2,tall*.020),DEEP,alpha*.49,floor_y,maxf(6.0,tall*.23))
		for section: Vector2i in [Vector2i(5,10),Vector2i(11,14),Vector2i(17,20)]:
			var foam:=PackedVector2Array()
			for n in range(section.x,section.y):foam.append(world[n])
			_line(canvas,foam,maxf(2.0,tall*.037),LIGHT,alpha*.82)
	else:
		# This narrow transparent crest remains visible across an overlapping
		# attacker/victim, while the main mass stays behind the bodies.
		var crest:=PackedVector2Array()
		for n in range(3,20):crest.append(world[n])
		var inner:=PackedVector2Array()
		for n in range(crest.size()):inner.append(crest[n]+Vector2(-facing*length*.015,tall*.12))
		_strip_fill(canvas,crest,inner,AQUA,alpha*.43)
		_foam_edge(canvas,crest,maxf(4.3,tall*.106),alpha)
		for n in range(6):
			var index: int=7+mini(n,5)*2
			var direction:=Vector2(facing*(.50+n*.10),-.80+n*.10).normalized()
			_droplet(canvas,world[index]+direction*tall*(.05+phase*.22),direction,maxf(2.6,tall*.065),alpha*.94)
	if jaw:
		# The ocean jaw is a scalloped foamy lower lip attached to this wave body.
		var lower:=PackedVector2Array()
		for n in range(9):
			var t: float=float(n)/8
			var y: float=base_y-tall*(.14+.13*sin(t*PI))
			if n%2==1:y-=tall*.13
			lower.append(Vector2(start_x+facing*length*t,y))
		if front:_foam_edge(canvas,lower,maxf(3,tall*.065),alpha*.96)
		else:_line(canvas,lower,maxf(4,tall*.115),AQUA,alpha*.69)

static func _tail_swell(canvas: CanvasItem,bounds: Rect2,facing: float,phase: float,alpha: float,front: bool) -> void:
	# The long bank uses one curved painted fill instead of a third atlas mesh.
	# Its front edge remains the exact edge of the source's pressure region.
	var top:=PackedVector2Array();var bottom:=PackedVector2Array()
	for n in range(9):
		var t:=float(n)/8.0
		var x:=bounds.position.x+bounds.size.x*(t if facing>0 else 1.0-t)
		var height:=bounds.size.y*(.42+.38*sin(t*PI*.70)+.08*sin(t*TAU+phase*PI))
		top.append(Vector2(x,bounds.end.y-height))
		var shore:=bounds.size.y*(.028+.045*pow(sin(t*PI*3.0+phase*.71),2.0))
		bottom.append(Vector2(x,bounds.end.y-shore))
	if front:_foam_edge(canvas,top,maxf(2.0,bounds.size.y*.058),alpha*.71)
	else:
		var polygon:=top.duplicate()
		for n in range(bottom.size()-1,-1,-1):polygon.append(bottom[n])
		var colors:=PackedColorArray()
		for n in range(top.size()):colors.append(_tint(SEA.lerp(AQUA,float(n%3)*.07),alpha*.86))
		for n in range(bottom.size()-1,-1,-1):colors.append(_tint(DEEP,alpha*.025))
		canvas.draw_polygon(polygon,colors)
		_line(canvas,top,maxf(2.0,bounds.size.y*.09),AQUA,alpha*.77)

static func _cascade_crown(canvas: CanvasItem,bounds: Rect2,phase: float,alpha: float,rising: bool) -> void:
	var crest:=PackedVector2Array()
	for n in range(9):
		var t:=float(n)/8.0
		var y:=bounds.position.y+bounds.size.y*.09
		if rising:y=bounds.end.y-bounds.size.y*.20
		crest.append(Vector2(bounds.position.x+bounds.size.x*t,y-sin(t*PI)*minf(bounds.size.y*.12,bounds.size.x*.24)*(1+phase*.13)))
	_foam_edge(canvas,crest,maxf(3.0,minf(bounds.size.x,bounds.size.y)*.083),alpha)
	for n in range(3):
		var at:=crest[2+n*2]
		var axis:=Vector2(float(n-1)*.58,-1.0).normalized()
		_droplet(canvas,at+axis*bounds.size.y*.058*phase,axis,maxf(3.0,minf(bounds.size.x,bounds.size.y)*.065),alpha*.83)

static func _air_curtain_ridge(canvas: CanvasItem,curtain: Dictionary,facing: float,phase: float,front: bool) -> void:
	var origin: Vector2=curtain.origin;var axis: Vector2=curtain.axis
	var width: float=float(curtain.width);var length: float=float(curtain.length)
	var edge:=Vector2(facing*axis.y,-facing*axis.x)
	var crest:=PackedVector2Array()
	for n in range(7):
		var t:=lerpf(.16,1.0,float(n)/6.0)
		crest.append(origin+axis*length*t+edge*width*(.28+.11*sin(t*PI)))
	if front:
		_foam_edge(canvas,crest,maxf(3.0,width*.11),.88)
		for n in [2,4,6]:
			var direction: Vector2=(edge*.65+axis*.55).normalized()
			_droplet(canvas,crest[n]+direction*width*phase*.14,direction,maxf(2.3,width*.07),.86)
	else:
		_line(canvas,crest,maxf(5.0,width*.17),DEEP,.91)
		_line(canvas,crest,maxf(3.2,width*.11),AQUA,.93)

static func _jaw_teeth(canvas: CanvasItem,bounds: Rect2,facing: float,phase: float,alpha: float) -> void:
	# Large blue-white foam teeth are attached to the wave, with an open mouth
	# around the struck body. The source regions remain the only damaging shape.
	var span:=minf(bounds.size.x,bounds.size.y*1.18)
	var start:=bounds.end.x-span if facing>0 else bounds.position.x
	for side in [-1.0,1.0]:
		for n in range(5):
			var t: float=(float(n)+.5)/5.0
			var x:=start+span*t
			var arc:=sin(t*PI)
			var center:=Vector2(x,bounds.get_center().y+side*bounds.size.y*(.24+.09*arc))
			var width:=span*.063
			var depth:=bounds.size.y*(.11+.04*arc)*(1-phase*.20)
			_poly(canvas,PackedVector2Array([center+Vector2(-width,side*depth*.13),center+Vector2(width,side*depth*.13),center-Vector2(facing*width*.17,side*depth)]),LIGHT,alpha*.81)

static func geometry(state: Dictionary) -> Dictionary:
	var slot: String=str(state.get("slot",""))
	var anchors: Dictionary=state.get("anchors",{})
	var ready: bool=bool(state.get("ready",false)) and str(state.get("id",""))=="shark"
	if state.has("position"):ready=ready and anchors.has("jaw") and anchors.has("front_foot") and (anchors.has("third_foot") or anchors.has("rear_foot"))
	var outcome: String=str(state.get("outcome",""))
	return {"ready":ready,"motif":str(PATTERNS.get(slot,"ocean_contact")),"material":"animated_hand_painted_ocean_12_cels","tier":state.get("tier",0),"finisher":state.get("finisher",false),"source_confirmed":state.get("finisher",false) and outcome in ["hit","guard_break","counter"],"body_copies":0,"opaque_plate":false,"clock_mutated":false,"requires_actual_release":true,"collision_bounds":_bounds(state),"fill_layer":"back","front_open_window":true,"max_curve_segments":ARC_SEGMENTS,"animated_water_cels":12,"atlas_cached":true,"origin":_point(state,"front_foot",state.get("position",Vector2.ZERO)),"amplification":amplification(state)}

static func draw_actor(canvas: CanvasItem,state: Dictionary,layer: String) -> Dictionary:
	var info:=geometry(state)
	if not info.ready or layer not in ["back","front"]:return info
	info["frame_fx"]=FrameFX.draw_actor(canvas,state,layer)
	var position: Vector2=state.get("position",Vector2.ZERO)
	var source_floor: float=float(state.get("floor",position.y))
	var h: float=float(state.get("height",90))
	var f: float=float(state.get("facing",1))
	var slot: String=str(state.get("slot",""))
	var flow_sample: float=(float(state.get("frame",0))+float(state.get("source_clock",0))*30.0)*.18
	var release: Dictionary=state.get("release_state",{})
	var style:=amplification(state);var scale:=float(style.visual_scale)
	var active: bool=bool(release.get("active",false))
	var phase: float=float(release.get("phase",0))
	var front: Vector2=_point(state,"front_foot",position)
	var rear: Vector2=_point(state,"rear_foot",_point(state,"third_foot",position))
	var jaw: Vector2=_point(state,"jaw",position)
	var tail: Vector2=_point(state,"tail",rear)
	var is_front: bool=layer=="front"
	if not active:
		var prepare: float=float(release.get("prepare",0))
		var fade: float=1-float(release.get("recovery_phase",1)) if release.get("recovering",false) else 0.0
		# Foamy little shoe puddles settle during the source's own recovery.
		if (prepare>0 and int(state.get("tier",0))>=2) or fade>0:
			var a: float=prepare*.22+fade*.36
			var center:=front.lerp(rear,.5)
			_ribbon(canvas,center,Vector2(h*(.43+fade*.14),h*.135),.15,PI*.94,.46,a,is_front,0.0,source_floor,flow_sample)
			if is_front and fade>0:
				for n in range(3):_droplet(canvas,center+Vector2((n-1)*h*.2,-h*(.04+fade*.1)),Vector2((n-1)*.5,-1),h*.035,fade*.62)
		return info
	var bounds:=_bounds(state)
	# These pinned eight bindings have actor HitVOs, no born projectile. A source
	# interval without its live actor region cannot paint a damaging distant wave.
	if not bounds.has_area():return info
	var ocean:=_ocean_pose(state,bounds)
	var volume_alpha: float=(.12 if slot=="U" else .24) if is_front else .97
	if slot in ["U","I","SU"]:
		var area: Rect2=ocean.rect
		if slot=="U" and is_front:
			# Foreground foam stays at the shoes/waist, opening the victim's face
			# and body reaction. The full-height exaggerated rear wave is intact.
			area=Rect2(area.position+Vector2(0,area.size.y*.38),Vector2(area.size.x,area.size.y*.62))
		var width: float=minf(area.size.x,area.size.y*1.30)
		var head:=Rect2(Vector2(area.end.x-width if f>0 else area.position.x,area.position.y),Vector2(width,area.size.y))
		var tail_width: float=maxf(0,area.size.x-width*.58)
		if tail_width>1:
			var trail:=Rect2(Vector2(area.position.x if f>0 else area.end.x-tail_width,area.end.y-area.size.y*.57),Vector2(tail_width,area.size.y*.57))
			_tail_swell(canvas,trail,f,phase,(.22 if slot=="U" else .31) if is_front else .93,is_front)
		_ocean_frame(canvas,head,"wave",ocean.sample,f,(.12 if slot=="U" else .38) if is_front else .98,0.0,Rect2(),source_floor)
		if slot in ["U","I"] and area.size.x>width*1.42:
			# A second animated breaker in the extended tide keeps the crest visible
			# when the source's very long final pressure region reaches offscreen.
			var near_offset: float=0.0 if slot=="I" else area.size.x*.30
			var near_x: float=area.position.x+near_offset if f>0 else area.end.x-near_offset-width
			var near:=Rect2(Vector2(clampf(near_x,area.position.x,area.end.x-width),area.position.y),Vector2(width,area.size.y))
			_ocean_frame(canvas,near,"wave",clampf(ocean.sample+.56,0,5),f,(.10 if slot=="U" else .32) if is_front else .94,0.0,Rect2(),source_floor)
		if slot=="I" and is_front:
			var mouth:=Rect2(bounds.position.x,bounds.end.y-bounds.size.y*.42,bounds.size.x,bounds.size.y*.42)
			_breaker(canvas,mouth,f,phase,.38,true,true,source_floor)
		elif slot=="I":_jaw_teeth(canvas,head,f,phase,.95)
	elif slot=="WI":
		var spin: float=flow_sample
		var spin_size: float=minf(bounds.size.x,bounds.size.y)*minf(1.17,.91*scale)
		var center:=bounds.get_center()
		# Separate depths and open arcs surround the real spinning body. No
		# square wave cel is rotated as an opaque wheel through the victim.
		if not is_front:
			for n in range(3):
				var angle:=spin+float(n)*TAU/3.0
				var radii:=Vector2(spin_size*(.40+.028*n),spin_size*(.27+.024*n))
				_ribbon(canvas,center,radii,angle,angle+PI*1.12,.31,.80,false,-.15,source_floor,flow_sample)
				if n<2:
					var point:=center+Vector2(cos(angle)*radii.x,sin(angle)*radii.y)
					var crest:=Rect2(point-Vector2(spin_size*.25,spin_size*.19),Vector2(spin_size*.50,spin_size*.38))
					_ocean_frame(canvas,crest,"wave",fposmod(ocean.sample+n*1.4,5.0),f,.75,angle*.18,Rect2(),source_floor)
		else:
			_ribbon(canvas,center,Vector2(spin_size*.44,spin_size*.29),.13,PI-.13,.22,.45,true,0.0,source_floor,flow_sample)
	elif slot=="WU":_ocean_frame(canvas,ocean.rect,ocean.kind,ocean.sample,-f,volume_alpha,PI,Rect2(),source_floor)
	else:_ocean_frame(canvas,ocean.rect,ocean.kind,ocean.sample,f,volume_alpha,ocean.rotation,Rect2(),source_floor)
	if slot=="AIR_U" and not ocean.curtain.is_empty():
		_air_curtain_ridge(canvas,ocean.curtain,f,phase,is_front)
	if not is_front and slot in ["WU","SI","AIR_I"]:
		_cascade_crown(canvas,ocean.rect,phase,.85,slot=="WU")
		if slot=="SI":
			var foot: Rect2=Rect2(ocean.rect.position.x,ocean.rect.end.y-h*.82,ocean.rect.size.x,h*.82)
			_breaker(canvas,foot,f,phase,.87,false,true,source_floor)
	# Secondary paint only supports a recognizable animated ocean mass.
	if slot=="WI":
		if is_front:
			for n in range(3):_droplet(canvas,bounds.get_center()+Vector2((n-1)*h*.29,h*.24),Vector2((n-1)*.3,-.6),h*.035,.63)

	if is_front:
		var end_x: float=bounds.end.x if f>0 else bounds.position.x
		for n in range(3):_droplet(canvas,Vector2(end_x-f*h*.08,bounds.get_center().y+(n-1)*h*.13),Vector2(f,-.5+n*.4),h*.039*minf(scale,1.55),.86)
	if _draw_observer.is_valid():_draw_observer.call({"slot":slot,"layer":layer,"source_absolute_frame":state.get("absolute_frame",-1),"source_fraction":state.get("source_clock",0),"atlas_sample":ocean.sample,"atlas_group":ocean.kind,"actual_region":bounds,"water_rect":ocean.rect,"alpha":volume_alpha,"real_atlas_submitted":true})
	return info

static func draw_object(_canvas: CanvasItem,state: Dictionary,_layer: String) -> Dictionary:
	# These eight source bindings do not create a projectile; never invent one.
	return geometry(state)

static func draw_contact(canvas: CanvasItem,state: Dictionary,layer: String) -> Dictionary:
	var info:=geometry(state)
	if not info.ready or layer not in ["back","front"]:return info
	info["frame_fx"]=FrameFX.draw_contact(canvas,state,layer)
	var p: Vector2=state.get("pos",Vector2.ZERO)
	var h: float=float(state.get("height",90))
	var a: float=float(state.get("alpha",0))
	var phase: float=float(state.get("phase",0))
	var outcome: String=str(state.get("outcome","hit"))
	var f: float=float(state.get("direction",1))
	var final: bool=bool(state.get("finisher",false)) and outcome in ["hit","guard_break","counter"]
	var tier: int=int(state.get("tier",1))
	var is_front: bool=layer=="front"
	var small_front: bool=is_front and str(state.get("slot",""))=="U"
	if small_front:a*=.65
	if outcome in ["guard","blocked","armor","steel","bullet_clash"]:
		# Water buckles outward against a guarded body, never closes the final wave.
		_ribbon(canvas,p,Vector2(h*.17,h*.24),-.85,.85,.43,a,is_front,0 if f>0 else PI)
		if is_front:
			for n in range(3):_droplet(canvas,p+Vector2(f*h*(.1+phase*.23),(n-1)*h*.14),Vector2(f,(n-1)*.5),h*.035,a)
		return info
	if not is_front:
		var foam_width: float=h*(2.08 if final else .97)
		var foam_height: float=h*(1.47 if final else .76)
		_ocean_frame(canvas,Rect2(p-Vector2(foam_width*.52,foam_height*.48),Vector2(foam_width,foam_height)),"wave",clampf(phase*5,0,5),f,a*(.96 if final else .76))
	var radius: float=h*(.67 if tier>=3 else .53) if final else h*(.28 if tier>=2 else .21)
	radius*=1+phase*.54
	if small_front:radius*=.72
	# A readable opening in the split breaker keeps the target's physical reaction visible.
	for side in [-1.0,1.0]:
		var center:=p+Vector2(side*radius*.48,radius*.10)
		_ribbon(canvas,center,Vector2(radius*.76,radius*.81),-PI*.86 if side>0 else -PI*.14,PI*.34 if side>0 else PI*1.06,.43,a,is_front)
	if layer=="back" and final and bool(state.get("floor_contact",false)):
		var ground:=Vector2(p.x,float(state.get("floor_y",p.y)))
		var bank:=Rect2(ground-Vector2(radius*1.1,radius*.46),Vector2(radius*2.2,radius*.46))
		_breaker(canvas,bank,f,phase,a,false)
	if not is_front:return info
	if float(state.get("age",0))<.04:canvas.draw_circle(p,h*(.055 if final else .031),_tint(LIGHT,a*.88))
	for n in range(8 if final else 5):
		var angle: float=-PI*.92+float(n)*(PI*1.75/float(7 if final else 4))
		var axis:=Vector2(cos(angle)*f,sin(angle))
		_droplet(canvas,p+axis*radius*(.57+phase*.48),axis,h*(.067 if final else .043),a)
	if final:
		# Two real-contact collapsing wave jaws: visible ocean mass and chunky foam teeth.
		var width: float=h*(1.02 if tier>=3 else .77)*(1+phase*.22)
		var opening: float=h*(.39 if tier>=3 else .29)*(1-phase*.30)
		for side in [-1.0,1.0]:
			var crest:=PackedVector2Array();var mass:=PackedVector2Array()
			for n in range(11):
				var t: float=float(n)/10.0
				var x: float=(t-.5)*width*2
				var curve: float=sin(t*PI)*opening
				var tooth: float=h*.08 if n%2==1 else 0.0
				crest.append(p+Vector2(x,side*(curve-tooth)))
				mass.append(p+Vector2(x,side*(curve+h*.12)))
			var body:=crest.duplicate()
			for n in range(mass.size()-1,-1,-1):body.append(mass[n])
			_poly(canvas,body,AQUA,a*.31)
			_line(canvas,crest,h*.052,DEEP,a*.97)
			_line(canvas,crest,h*.025,LIGHT,a*.98)
			for n in [1,3,5,7,9]:canvas.draw_circle(crest[n],h*.028,_tint(LIGHT,a*.96))
	return info
