extends RefCounted
## A visual safe frame only. The BVN map camera, actor roots and bounds are intact.
static func fit_air_reaction(zoom: float, offset: Vector2, points: Array[Dictionary], viewport: Vector2) -> Dictionary:
	var original: Dictionary={"zoom":zoom,"offset":offset,"adjusted":false}
	var high_reaction:=false
	var top:=INF;var bottom:=-INF
	for entry: Dictionary in points:
		if not entry.get("visible",true):continue
		var head: Vector2=entry.get("head",Vector2.ZERO)
		var feet: Vector2=entry.get("feet",head)
		var height:=maxf(16.0,float(entry.get("height",90)))
		top=minf(top,head.y-height*.20);bottom=maxf(bottom,feet.y+height*.08)
		if entry.get("air_reaction",false):high_reaction=true
	var ceiling:=viewport.y*.1625
	var floor_limit:=viewport.y*.92
	if not high_reaction or not is_finite(top) or not is_finite(bottom) or top*zoom+offset.y>=ceiling:return original
	var fitted_zoom:=zoom*minf(1.0,(floor_limit-ceiling)/maxf(1,(bottom-top)*zoom))
	var factor:=fitted_zoom/maxf(.0001,zoom)
	var fitted_offset:=Vector2(viewport.x*.5+(offset.x-viewport.x*.5)*factor,offset.y*factor)
	fitted_offset.y=clampf(fitted_offset.y,ceiling-top*fitted_zoom,floor_limit-bottom*fitted_zoom)
	return {"zoom":fitted_zoom,"offset":fitted_offset,"adjusted":true,"source_map_camera_unchanged":true}
