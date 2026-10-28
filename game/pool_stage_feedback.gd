extends RefCounted
## Pure scenery; never changes a contact, clock, source state or random seed.
const INK:=Color("193c59")
const WATER:=Color("37b9ce")
const FOAM:=Color("fff8e8")

static func floor_duration(event: Dictionary) -> float:
	return .50 if int(event.get("type",1))==2 else (.34 if int(event.get("type",1))==0 else .28)

## Original three hitFloor types adapted to wet pool tiles. This stage layer
## belongs to the actual source event; a jump or whiff never manufactures it.
## Narrow rising spray = bounce, low scuff = secondary fall, tile/foam crown
## = heavy down. No extra attacker, collision, camera impulse or world hole.
static func draw_floor_impact(canvas: CanvasItem,event: Dictionary) -> void:
	var duration:=floor_duration(event)
	var age:=float(event.get("age",0.0))
	if age<0 or age>=duration:return
	var kind:=int(event.get("type",1))
	var p:=age/duration
	var at: Vector2=event.get("position",Vector2.ZERO)
	var power:=clampf(float(event.get("strength",1.0)),.5,5.0)
	var heavy:=kind==2
	var alpha:=pow(1.0-p,1.35)*(.90 if heavy else .64)
	var extent: float=(24.0+power*10.0)*(1.0+p*1.35)
	# Broken rim arcs, rather than a closed, straight-bottomed flat oval.
	for section in range(4):
		var arc:=PackedVector2Array()
		for i in range(9):
			var a:=TAU*(float(section)*.25+.022+float(i)*.025)
			arc.append(at+Vector2(cos(a)*extent,sin(a)*(3.0+p*7.0)-1.0))
		canvas.draw_polyline(arc,Color(INK,alpha*.35),3.1 if heavy else 1.8,true)
		canvas.draw_polyline(arc,Color(FOAM,alpha),1.7 if heavy else 1.1,true)
	var count:=12 if heavy else (7 if kind==0 else 5)
	for i in range(count):
		var side: float=1 if i%2==0 else -1
		var spread:=float(i)/float(count)*.6+.4
		var speed:=Vector2(side*(28.0+float(i)*12.0)*(.65+power*.14),-(110.0+float(i%4)*32.0) if kind==0 else -(64.0+float(i%3)*23.0)*(1.0+power*.10))
		var pos:=at+Vector2(side*spread*9.0,-2.0)+speed*age+Vector2(0,310.0*age*age)
		if heavy and i%3==0:
			var size:=3.8+float(i%2)*1.5
			var angle:=age*side*(5.0+float(i%3))
			var piece:=PackedVector2Array()
			for v: Vector2 in [Vector2(-size,0),Vector2(-size*.55,-size),Vector2(size,-size*.40),Vector2(size*.8,size*.7)]:piece.append(pos+v.rotated(angle))
			canvas.draw_colored_polygon(piece,Color(FOAM,alpha))
			canvas.draw_line(piece[2],piece[3],Color(INK,alpha*.70),1.4,true)
		else:_droplet(canvas,pos,speed+Vector2(0,620.0*age),2.6 if heavy else (2.0 if kind==0 else 1.7),alpha*.80)
	if heavy:
		# A short wet compression crown expands only at the true impact.
		for i in range(5):
			var center:=at+Vector2((float(i)-2.0)*extent*.33,-3.0)
			var h: float=sin(p*PI)*power*(5.0+float(i%2)*2.0)
			var crown:=PackedVector2Array([center+Vector2(-7,0),center+Vector2(-4,-h*.6),center+Vector2(0,-h),center+Vector2(3,-h*.7),center+Vector2(7,0)])
			canvas.draw_colored_polygon(crown,Color(WATER,alpha*.58))
			canvas.draw_polyline(crown,Color(FOAM,alpha*.78),1.3,true)

static func _ellipse(canvas: CanvasItem, at: Vector2, radius: Vector2, color: Color, width: float) -> void:
	var points:=PackedVector2Array()
	for i in range(33):
		var a:=TAU*float(i)/32.0
		points.append(at+Vector2(cos(a),sin(a))*radius)
	canvas.draw_polyline(points,color,width,true)

static func _droplet(canvas: CanvasItem, at: Vector2, axis: Vector2, size: float, alpha: float) -> void:
	var n:=axis.normalized()
	var side:=Vector2(-n.y,n.x)
	var body:=PackedVector2Array([at+n*size*1.5])
	for i in range(11):
		var angle:=PI/3.0+PI*4.0/3.0*float(i)/10.0
		body.append(at+side*sin(angle)*size*.48+n*(cos(angle)*.55-.08)*size)
	canvas.draw_colored_polygon(body,Color(WATER,alpha))
	body.append(body[0]);canvas.draw_polyline(body,Color(INK,alpha*.65),1.2,true)
	canvas.draw_line(at,at+n*size*.77,Color(FOAM,alpha*.8),1.3,true)

static func draw_landing(canvas: CanvasItem, event: Dictionary) -> void:
	var age: float=event.get("age",0.0)
	if age<0.0 or age>=.36:return
	var p:=age/.36
	var point: Vector2=event["position"]
	var strength: float=clampf(float(event.get("speed",180.0))/800.0,.25,1.0)
	var alpha: float=(1.0-p)*.58
	_ellipse(canvas,point,Vector2(14.0+p*(32.0+strength*31.0),3.0+p*5.0),Color(WATER,alpha),2.0)
	for i in range(6):
		var sign_x:=1.0 if i%2==0 else -1.0
		var velocity:=Vector2(sign_x*(42.0+i*17.0)*strength,-(60.0+float(i%3)*31.0)*strength)
		var drop:=point+velocity*age+Vector2(0,240.0*age*age)
		_droplet(canvas,drop,velocity+Vector2(0,480.0*age),2.0+strength*2.0,alpha)

static func draw_feet(canvas: CanvasItem, actor: Variant, anchors: Dictionary) -> void:
	if not actor.grounded or not actor.visible or actor.state not in ["walk","run","dash"]:return
	var phase:=fposmod(float(actor.walk_clock)*(5.0 if actor.state=="dash" else 3.5),1.0)
	var step_phase:=fposmod(phase*2.0,1.0)
	var sole: Vector2=anchors.get("front_foot",actor.position)
	sole.y=actor.stage_floor_y-1.0
	var direction:=signf(actor.velocity.x)
	var alpha: float=(1.0-step_phase)*.35
	var center:=sole+Vector2(-direction*step_phase*16.0,0)
	_ellipse(canvas,center,Vector2(6.0+step_phase*12.0,2.0+step_phase*2.0),Color(INK,alpha*.25),1.2)
	for i in range(3):
		var offset:=Vector2(-direction*(5.0+i*4.0+step_phase*18.0),-sin(step_phase*PI)*(3.0+i*2.0))
		_droplet(canvas,center+offset,Vector2(-direction,-.7),1.4+float(i)*.35,alpha)

static func draw_contact(canvas: CanvasItem, effect: Dictionary, state: Dictionary) -> void:
	if not state.get("ready",false) or str(state.get("outcome","hit")) in ["guard","armor","bullet_clash"]:return
	var age: float=state.get("age",0.0)
	var duration: float=state.get("duration",.25)
	if age<0.0 or age>=duration:return
	var tier: int=state.get("tier",1)
	var finish: bool=state.get("finisher",false)
	# A nearby airborne body is not a ground strike. Only the real low contact
	# classified by the source feedback can break the pool-side surface.
	if not finish or not state.get("ground_splash",false):return
	var point: Vector2=effect.get("pos",Vector2.ZERO)
	var floor_y: float=effect.get("floor_y",point.y)
	point.y=floor_y-2.0
	var p:=age/duration
	var amplitude:=1.0+float(tier)*.34
	var alpha: float=(1.0-p)*(.62 if finish else .35)
	_ellipse(canvas,point,Vector2((18.0+p*65.0)*amplitude,4.0+p*9.0),Color(INK,alpha*.55),3.0)
	_ellipse(canvas,point+Vector2(0,-2),Vector2((15.0+p*57.0)*amplitude,3.0+p*8.0),Color(WATER,alpha),2.3)
	for i in range(8 if tier>=3 else 5):
		var direction:=1.0 if i%2==0 else -1.0
		var v:=Vector2(direction*(62.0+float(i)*19.0)*amplitude,-(91.0+float(i%3)*39.0)*amplitude)
		var drop:=point+v*age+Vector2(0,360.0*age*age)
		_droplet(canvas,drop,v+Vector2(0,720.0*age),3.0 if tier>=3 else 2.2,alpha)
	if finish and tier>=2:
		for i in range(5):
			var side:=1.0 if i%2==0 else -1.0
			var chip:=point+Vector2(side*(25.0+i*26.0)*age*amplitude,-(63.0+i*18.0)*age+320.0*age*age)
			var size:=3.0+float(i%2)
			var polygon:=PackedVector2Array([chip+Vector2(-size,0),chip+Vector2(size,-size),chip+Vector2(size+1,size),chip+Vector2(-size*.6,size)])
			canvas.draw_colored_polygon(polygon,Color(FOAM,alpha))
			canvas.draw_line(polygon[2],polygon[3],Color(INK,alpha),1.5,true)
