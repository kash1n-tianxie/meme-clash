extends RefCounted
## Release-only animation over the original painted alpha shapes.
## Geometry/UV slices unfold along the move, flow, then separate and dissolve.
## No RNG, new texture, actor trail, collision or gameplay event is created here.

const COLORS={"rio":Color("a5efff"),"cat":Color("ffccfa"),"shark":Color("a9faff"),"worker":Color("fff0c4"),"chicken":Color("ffe791")}

static func sample(state: Dictionary) -> Dictionary:
	if not state.get("ready",false): return {"ready":false}
	var id: String=state["id"]
	var phase: float=state["phase"]
	var direction: String=state["direction"]
	var vertical:=direction in ["rising","sky_fan"]
	var major:=str(state["clip"]).begins_with("super")
	var columns:=3 if vertical else 12
	var rows:=12 if vertical else (3 if major else 2)
	var size: Vector2=state["world_size"]
	var anchor: Vector2=state["anchor"]
	var origin: Vector2=state["position"]-anchor*size
	var front:=smoothstep(0.0,.27,phase)*1.18
	var erosion:=smoothstep(.61,1.0,phase)*1.50-.30
	var pieces: Array[Dictionary]=[]
	var colors: Color=COLORS.get(id,Color.WHITE)
	for y in range(rows):
		for x in range(columns):
			var uv_rect:=Rect2(float(x)/columns,float(y)/rows,1.0/columns,1.0/rows)
			var center:=uv_rect.get_center()
			var distance:=1.0-center.y if vertical else center.x
			var points:=PackedVector2Array()
			var alphas:=PackedFloat32Array()
			var opacity:=0.0
			for corner: Vector2 in [Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)]:
				var uv:=uv_rect.position+corner*uv_rect.size
				var along:=1.0-uv.y if vertical else uv.x
				var across:=uv.x if vertical else uv.y
				var branch:=sin(across*TAU*1.5)*.025
				var revealed:=smoothstep(along-.10+branch,along+.10+branch,front)
				var remains:=1.0-smoothstep(along-.14+across*.04,along+.14+across*.04,erosion)
				var alpha:=revealed*remains*float(state["opacity"])
				alphas.append(alpha);opacity=maxf(opacity,alpha)
				var at:=origin+uv*size
				var flow:=sin((1.0-uv.y if vertical else uv.x)*TAU-phase*TAU*2.0)
				var envelope:=sin(uv.x*PI)*sin(uv.y*PI)
				# A continuous field shares all interior vertices. At peak release the
				# picture ripples as a connected shape, rather than detached rectangles.
				var amplitude: float=(6.0 if id=="shark" else (3.0 if id=="worker" else 4.0))
				if vertical: at.x+=flow*amplitude*envelope
				else: at.y+=flow*amplitude*envelope
				# Only the recovery tail breaks into particles, well behind the actors.
				var detach:=smoothstep(.67,1.0,phase)
				var spread: Vector2=Vector2((center.x-.5)*20.0,-18.0-center.y*12.0)
				if vertical: spread=Vector2((center.x-.5)*38.0,-16.0-distance*28.0)
				if id=="worker": spread.x+=sin(float(x*7+y*3))*10.0
				at+=spread*detach
				points.append(at)
			if opacity>=.002: pieces.append({"points":points,"uv_rect":uv_rect,"opacity":opacity,"alphas":alphas})
	var sparks: Array[Dictionary]=[]
	var spark_window:=smoothstep(.05,.18,phase)*(1.0-smoothstep(.78,1.0,phase))
	for n in range(8 if major else 4):
		var travel:=fposmod(phase*1.65+float(n)*.173,1.0)
		var side:=sin(float(n)*2.399+phase*3.0)
		var point:=Vector2.ZERO
		var velocity:=Vector2.ZERO
		if vertical:
			point=Vector2((.2+float(n%3)*.27)*size.x,(1.0-travel)*size.y)
			velocity=Vector2(side*2.0,-12.0)
		else:
			point=Vector2(travel*size.x,(.2+float(n%3)*.27)*size.y)
			velocity=Vector2(14.0,side*2.0)
		var opacity:=spark_window*sin(travel*PI)*.6
		sparks.append({"position":origin+point,"tail":velocity,"opacity":opacity,"style":"paper" if id=="worker" else ("water" if id=="shark" else ("claw" if id=="cat" else ("ember" if id=="chicken" else "blade")))})
	return {"ready":true,"pieces":pieces,"sparks":sparks,"color":colors,"phase":phase,"direction":direction,"major":major,"source_kind":"original_painted_shape_with_directional_mesh_release"}

static func draw(canvas: CanvasItem,state: Dictionary,texture: Texture2D,facing: int,tint: Color) -> void:
	var motion:=sample(state)
	if not motion.get("ready",false): return
	var source: Array=state["source_rect"]
	var rect:=Rect2(float(source[0]),float(source[1]),float(source[2]),float(source[3]))
	for piece: Dictionary in motion["pieces"]:
		var points:=PackedVector2Array()
		for point: Vector2 in piece["points"]: points.append(Vector2(point.x*facing,point.y))
		var uv:=PackedVector2Array()
		var uv_rect: Rect2=piece["uv_rect"]
		for corner: Vector2 in [Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)]:
			uv.append((rect.position+(uv_rect.position+corner*uv_rect.size)*rect.size)/texture.get_size())
		var colors:=PackedColorArray()
		for alpha: float in piece["alphas"]:
			var color:=tint;color.a*=alpha;colors.append(color)
		canvas.draw_polygon(points,colors,uv,texture)
	for spark: Dictionary in motion["sparks"]:
		var color: Color=motion["color"]*tint
		color.a*=float(spark["opacity"])
		var position: Vector2=spark["position"]
		var tail: Vector2=spark["tail"]
		position.x*=facing; tail.x*=facing
		if spark["style"]=="paper":
			var tilt:=Vector2(2.0*sin(float(motion["phase"])*TAU+position.x),0)
			canvas.draw_colored_polygon(PackedVector2Array([position+Vector2(-3,-4)+tilt,position+Vector2(4,-3)-tilt,position+Vector2(3,4)-tilt,position+Vector2(-4,3)+tilt]),color)
		elif spark["style"]=="water":
			canvas.draw_colored_polygon(PackedVector2Array([position-tail,position+Vector2(-3,0),position+tail*.2,position+Vector2(3,0)]),color)
		elif spark["style"]=="claw":
			for offset in [-4.0,0.0,4.0]: canvas.draw_line(position+Vector2(0,offset)-tail,position+Vector2(0,offset),color,2,false)
		elif spark["style"]=="ember":
			canvas.draw_rect(Rect2(position-Vector2(2,2),Vector2(4,4)),color)
		else:
			canvas.draw_line(position-tail,position,color,2,false)
