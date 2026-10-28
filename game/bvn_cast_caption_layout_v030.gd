extends RefCounted
## Display-only skill-name placement. All inputs are measured screen rectangles;
## no actor, camera, source clock or damage object is read or modified here.

static func _finite(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite() and rect.has_area()

static func _clear(rect: Rect2, obstacles: Array[Rect2], gap: float) -> bool:
	for obstacle: Rect2 in obstacles:
		if rect.grow(gap).intersects(obstacle):return false
	return true

static func _upward(rect: Rect2, safe: Rect2, obstacles: Array[Rect2], gap: float) -> Dictionary:
	var out:=rect
	out.position.x=clampf(out.position.x,safe.position.x,safe.end.x-out.size.x)
	out.position.y=clampf(out.position.y,safe.position.y,safe.end.y-out.size.y)
	# Every rejection moves strictly above a conflicting rectangle. This finite
	# sweep cannot oscillate between an opponent's face and the controls text.
	for step in range(obstacles.size()+2):
		if _clear(out,obstacles,gap):return {"ready":true,"rect":out,"steps":step}
		var next_y:=out.position.y
		for obstacle: Rect2 in obstacles:
			if out.grow(gap).intersects(obstacle):next_y=minf(next_y,obstacle.position.y-gap-out.size.y)
		if next_y<safe.position.y or is_equal_approx(next_y,out.position.y):break
		out.position.y=next_y
	return {"ready":false}

static func layout(request: Dictionary) -> Dictionary:
	var result: Dictionary={"ready":false,"visible":false,"changes_source":false,"source_clock_mutated":false,"changes_camera":false,"body_copies":0}
	var label:=str(request.get("label",""))
	if label.is_empty():result["reason"]="empty_name";return result
	# A child carrying an old major binding must never claim a currently drawn
	# actor caption. The caller supplies these facts from the actual live actor.
	if bool(request.get("major",false)) and bool(request.get("source_caption_visible",false)) and bool(request.get("source_actor_active",false)) and bool(request.get("source_owned",false)) and not bool(request.get("child_only",false)):
		result.merge({"ready":true,"reason":"owned_source_caption","label":label,"duplicate_caption":false},true)
		return result
	var desired: Rect2=request.get("desired_rect",Rect2())
	var arena: Rect2=request.get("arena",Rect2(0,0,1280,960))
	if not _finite(desired) or not _finite(arena):result["reason"]="invalid_measurement";return result
	var margin:=maxf(0,float(request.get("screen_margin",16)))
	var top:=maxf(arena.position.y+margin,float(request.get("minimum_y",232)))
	var bottom:=minf(arena.end.y-margin,float(request.get("maximum_y",arena.end.y-35)))
	var safe:=Rect2(Vector2(arena.position.x+margin,top),Vector2(arena.size.x-margin*2,bottom-top))
	if not _finite(safe) or desired.size.x>safe.size.x or desired.size.y>safe.size.y:
		result["reason"]="no_measured_space";return result
	var obstacles: Array[Rect2]=[]
	for raw: Variant in request.get("obstacles",[]):
		if raw is Rect2 and _finite(raw):obstacles.append(raw)
	var gap:=maxf(0,float(request.get("gap",6)))
	var first:=_upward(desired,safe,obstacles,gap)
	var chosen: Dictionary=first
	# Upward placement wins. If the source jumps beneath the HUD, try nearby
	# horizontal gaps at the same or an earlier height; never push text onto
	# the feet, force an arena sidebar or move a fighter to make space.
	if not first.get("ready",false):
		var x_values: Array[float]=[safe.position.x,safe.end.x-desired.size.x,(safe.position.x+safe.end.x-desired.size.x)*.5]
		for obstacle: Rect2 in obstacles:
			x_values.append(obstacle.end.x+gap)
			x_values.append(obstacle.position.x-gap-desired.size.x)
		x_values.sort_custom(func(a: float,b: float)->bool:return absf(a-desired.position.x)<absf(b-desired.position.x))
		for x: float in x_values:
			var candidate:=desired;candidate.position.x=x
			var attempt:=_upward(candidate,safe,obstacles,gap)
			if attempt.get("ready",false):chosen=attempt;break
	if not chosen.get("ready",false):
		result.merge({"ready":true,"label":label,"reason":"temporarily_occluded","duplicate_caption":false},true)
		return result
	var rect: Rect2=chosen.rect
	result.merge({"ready":true,"visible":true,"label":label,"rect":rect,"baseline":rect.position.y+float(request.get("ascent",desired.size.y*.8)),"size":int(request.get("size",18)),"major":bool(request.get("major",false)),"reason":"clear_screen_gap","moved_up":rect.position.y<desired.position.y,"moved_sideways":not is_equal_approx(rect.position.x,desired.position.x),"duplicate_caption":false,"foreground_body_clear":true},true)
	return result
