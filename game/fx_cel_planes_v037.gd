extends RefCounted
## Shared hard-edged, upper-left lighting for code-native material props.
## The input contour is unchanged; this helper contains no gameplay state.
static func _half_plane(points: PackedVector2Array, normal: Vector2, offset: float, positive: bool) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if points.is_empty(): return result
	var previous: Vector2 = points[-1]
	var previous_distance: float = normal.dot(previous) - offset
	for point: Vector2 in points:
		var distance: float = normal.dot(point) - offset
		var previous_inside: bool = previous_distance >= 0.0 if positive else previous_distance <= 0.0
		var inside: bool = distance >= 0.0 if positive else distance <= 0.0
		if inside != previous_inside:
			result.append(previous.lerp(point,previous_distance/(previous_distance-distance)))
		if inside: result.append(point)
		previous = point
		previous_distance = distance
	return result

static func split_convex(contour: PackedVector2Array, origin: Vector2, radius: float, light: Color, shadow: Color) -> Dictionary:
	var points: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var normal: Vector2 = Vector2(1.0,1.0).normalized()
	var offset: float = normal.dot(origin) + maxf(0.0,radius)*0.20
	var plane: int = 0
	for positive: bool in [false,true]:
		var polygon: PackedVector2Array = _half_plane(contour,normal,offset,positive)
		var start: int = points.size()
		points.append_array(polygon)
		for _point: Vector2 in polygon: colors.append(shadow if positive else light)
		for index: int in range(1,polygon.size()-1): indices.append_array(PackedInt32Array([start,start+index,start+index+1]))
		plane += 1
	return {"points":points,"colors":colors,"indices":indices,"planes":plane,"source_contour":contour,"changes_collision":false}
