extends RefCounted
## Material light and settling paint sit on the existing pool floor. These are
## not extra actors, attacks or clocks; every sample uses the caller's source.
const PALETTES := {
	"rio": [Color("184fa4"), Color("ffd06b")],
	"chicken": [Color("844d2b"), Color("ffc474")],
	"cat": [Color("733f69"), Color("ffc4d9")],
	"worker": [Color("3e5367"), Color("fff0cf")],
	"shark": [Color("07547a"), Color("bdebf0")]
}

static func sample(s: Dictionary, contact: bool = false) -> Dictionary:
	var id := str(s.get("id", ""))
	if not s.get("ready", false) or not PALETTES.has(id): return {"ready": false}
	var release: Dictionary = s.get("release_state", {})
	var power := 0.0
	var phase := 0.0
	var at: Vector2 = s.get("position", Vector2.ZERO)
	var floor_y := float(s.get("floor", at.y))
	var grounded := bool(s.get("grounded", false))
	if contact:
		grounded = bool(s.get("ground_splash", s.get("floor_contact", false)))
		at = s.get("pos", Vector2.ZERO)
		floor_y = float(s.get("floor_y", at.y))
		power = float(s.get("alpha", 0.0)) * (.86 if s.get("finisher", false) else .48)
		phase = float(s.get("phase", 0.0))
	else:
		power = .54 if release.get("active", false) else float(release.get("prepare", 0.0)) * .30
		if release.get("recovering", false): power = pow(maxf(0.0, 1.0 - float(release.get("recovery_phase", 1.0))), 1.6) * .38
		phase = float(release.get("phase", release.get("recovery_phase", 0.0)))
	var h := maxf(16.0, float(s.get("height", 90.0)))
	return {"ready": grounded and power > .004, "id": id, "at": Vector2(at.x, floor_y), "height": h, "power": power, "phase": phase, "tier": int(s.get("tier", 1)), "contact": contact, "body_copies": 0, "changes_source": false}

static func _ellipse(canvas: CanvasItem, at: Vector2, radii: Vector2, color: Color, alpha: float) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for n in range(20):
		var angle := TAU * float(n) / 20.0
		points.append(at + Vector2(cos(angle), sin(angle)) * radii)
		colors.append(Color(color, alpha * (.45 + .55 * maxf(0.0, -sin(angle)))))
	canvas.draw_polygon(points, colors)

static func draw(canvas: CanvasItem, s: Dictionary, layer: String, contact: bool = false) -> Dictionary:
	var g := sample(s, contact)
	if not g.ready or layer not in ["back", "front"]: return g
	var h: float = g.height
	var power: float = g.power
	var p: float = g.phase
	var at: Vector2 = g.at
	var palette: Array = PALETTES[g.id]
	var spread := h * (.40 + float(g.tier) * .07) * (1.0 + p * .36)
	if layer == "back":
		# The same oblique light as the pool floor: dark contact underneath,
		# reflected material toward the camera, no rectangle or glowing disk.
		_ellipse(canvas, at + Vector2(0, 2), Vector2(spread, h * .054), palette[0], power * .24)
		_ellipse(canvas, at + Vector2(-h * .03, h * .021), Vector2(spread * .78, h * .032), palette[1], power * .18)
		return g
	if not contact and not s.get("release_state", {}).get("recovering", false): return g
	for n in range(3):
		var side := float(n) - 1.0
		var q := at + Vector2(side * spread * (.70 + p * .19), -h * .014)
		var radius := h * (.022 + float(n % 2) * .011) * (1.0 - p * .28)
		match str(g.id):
			"shark":
				_ellipse(canvas, q, Vector2(radius * 2.3, radius * .49), palette[0], power * .50)
				_ellipse(canvas, q - Vector2(0, radius * .12), Vector2(radius * 1.5, radius * .24), palette[1], power * .81)
			"cat":
				_ellipse(canvas, q, Vector2(radius, radius * .49), palette[0], power * .34)
				for toe in [-1, 0, 1]: _ellipse(canvas, q + Vector2(toe * radius * .65, -radius * .62), Vector2(radius * .34, radius * .22), palette[1], power * .60)
			"worker":
				var paper := PackedVector2Array([q + Vector2(-radius, 0), q + Vector2(radius * .72, -radius * .26), q + Vector2(radius, radius * .19), q + Vector2(-radius * .82, radius * .31)])
				canvas.draw_colored_polygon(paper, Color(palette[1], power * .59))
			"rio", "chicken":
				var chip := PackedVector2Array([q + Vector2(-radius * 1.2, 0), q + Vector2(radius * .41, -radius * .40), q + Vector2(radius, radius * .21), q + Vector2(-radius * .59, radius * .27)])
				canvas.draw_colored_polygon(chip, Color(palette[0], power * .52))
				canvas.draw_line(q - Vector2(radius * .56, 0), q + Vector2(radius * .45, -radius * .11), Color(palette[1], power * .61), 1.0, true)
	return g
