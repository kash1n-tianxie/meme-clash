extends RefCounted
## Source-owned material cels. Every cel is a separately constructed mesh;
## folded pages, rubber skin, fur tufts, crystals and foam change their shape.
## One indexed submission per layer, no character/image/ball duplicates.
const IDS := ["rio","chicken","cat","worker","shark"]
const SLOTS := ["U","SU","WU","AIR_U","I","WI","SI","AIR_I"]
const CELS := {"prepare":12,"release":16,"recover":8,"contact":12,"deflect":8}
const PALETTES := {
	"rio":[Color("104bbb"),Color("47dbfa"),Color("ffcf68"),Color("eaffff")],
	"chicken":[Color("281d19"),Color("ee7525"),Color("ffbd59"),Color("fff1cf")],
	"cat":[Color("662848"),Color("ee6dae"),Color("ffd8b6"),Color("fff4d6")],
	"worker":[Color("26384f"),Color("7eb5c8"),Color("f5e8cd"),Color("eb4b57")],
	"shark":[Color("075879"),Color("0cacd2"),Color("75e5ee"),Color("eaffff")]
}
const MATERIALS := {"rio":"faceted_holy_light","chicken":"folding_seamed_ball_skin","cat":"soft_fur_claw_tufts","worker":"curling_folded_documents","shark":"breaking_foam_droplets"}
static var _cache: Dictionary = {}
static var _cache_order: Array[String] = []
static var _observer := Callable()

static func set_draw_observer(callback: Callable = Callable()) -> void:
	_observer=callback

static func _v(value: Variant,fallback: Vector2=Vector2.ZERO) -> Vector2:
	if value is Vector2:return value
	if value is Array and value.size()>=2:return Vector2(float(value[0]),float(value[1]))
	return fallback

static func _ease(value: float) -> float:
	var t:=clampf(value,0,1)
	return t*t*(3-2*t)

static func _axis(s: Dictionary) -> Vector2:
	var anchors: Dictionary=s.get("anchors",{})
	var f:=float(s.get("facing",s.get("direction",1)))
	var id:=str(s.get("id",""));var slot:=str(s.get("slot","U"))
	if id=="rio" and anchors.has("weapon_tip") and anchors.has("weapon_grip"):
		var blade:=_v(anchors.weapon_tip)-_v(anchors.weapon_grip)
		if blade.length_squared()>.01:return blade.normalized()
	if s.has("attack_axis"):
		var attack:=_v(s.attack_axis)
		if attack.length_squared()>.01:return attack.normalized()
	if slot in ["WU","WI"]:return Vector2(f*.24,-1).normalized()
	if slot in ["AIR_U","AIR_I"]:return Vector2(f*.35,1).normalized()
	return Vector2(f,-.10).normalized()

static func _anchor(s: Dictionary) -> Vector2:
	var a: Dictionary=s.get("anchors",{})
	var id:=str(s.get("id",""));var fallback:=_v(s.get("position"))
	match id:
		"rio":return _v(a.get("weapon_tip"),fallback)
		"chicken":return _v(a.get("ball" if s.get("ball_visible",a.has("ball")) else "hand"),fallback)
		"cat":return _v(a.get("paw_tip"),fallback)
		"worker":return _v(a.get("briefcase"),fallback)
		"shark":return _v(a.get("front_foot"),fallback)
	return fallback

static func _packet(id: String,slot: String,stage: String,progress: float,frame: float,tier: int,origin: Vector2,axis: Vector2,h: float,opacity: float) -> Dictionary:
	var count:=int(CELS.get(stage,0))
	if count<=0:return {"ready":false,"body_copies":0,"source_clock_mutated":false}
	var phase:=clampf(progress,0,1)
	var cel:=mini(count-1,int(floor(phase*float(count-1))))
	var mix:=phase*float(count-1)-float(cel)
	var next:=mini(cel+1,count-1)
	return {"ready":true,"id":id,"slot":slot,"stage":stage,"progress":phase,"source_frame":frame,"cel":cel,"next_cel":next,"mix":mix,"cel_count":count,"tier":tier,"origin":origin,"axis":axis,"height":h,"opacity":clampf(opacity,0,1),"material":MATERIALS.get(id,""),"source_owned":true,"clock":"actor_30hz_or_confirmed_contact_visual_age","body_copies":0,"projectile_copies":0,"creates_contact":false,"source_clock_mutated":false,"changes_collision":false,"submitted_meshes_per_layer":1}

static func sample_actor(s: Dictionary) -> Dictionary:
	var id:=str(s.get("id",""));var slot:=str(s.get("slot",""))
	if not s.get("ready",false) or id not in IDS or slot not in SLOTS:return {"ready":false}
	var release: Dictionary=s.get("release_state",{})
	var stage: String="";var progress: float=0;var opacity: float=0
	if release.get("active",false):
		stage="release";progress=float(release.get("phase",0));opacity=.66*(1-.38*progress)
	elif float(release.get("prepare",0))>0:
		stage="prepare";progress=float(release.prepare);opacity=.19+.42*progress
	elif release.get("recovering",false):
		stage="recover";progress=float(release.get("recovery_phase",1));opacity=.42*pow(1-progress,1.55)
	else:return {"ready":false,"body_copies":0,"creates_contact":false}
	var frame:=float(s.get("frame",0))+clampf(float(s.get("source_clock",0))*30,0,.999)
	var result:=_packet(id,slot,stage,progress,frame,int(s.get("tier",1)),_anchor(s),_axis(s),maxf(1,float(s.get("height",90))),opacity)
	result["packet_kind"]="actor"
	result["source_label"]=str(s.get("label",""))
	result["source_absolute_frame"]=float(s.get("absolute_frame",s.get("frame",0)))+clampf(float(s.get("source_clock",0))*30,0,.999)
	result["real_release"]=bool(release.get("active",false))
	result["source_interval_start"]=int(release.get("start",-1))
	var interval_end:=int(release.get("recent_end",-1))
	if result.real_release:
		interval_end=-1
		var bundle: Dictionary=s.get("bundle",{})
		for region: Dictionary in bundle.get("regions",[]):
			if int(region.get("start",-2))==int(result.source_interval_start) and frame<float(region.get("end_exclusive",-1)):interval_end=int(region.end_exclusive)
		for birth: Variant in bundle.get("spawn_frames",[]):
			if int(birth)==int(result.source_interval_start):interval_end=int(birth)+4
	result["source_interval_end"]=interval_end
	return result

static func sample_contact(s: Dictionary) -> Dictionary:
	var id:=str(s.get("id",""));var slot:=str(s.get("slot",""))
	if not s.get("ready",false) or id not in IDS or slot not in SLOTS:return {"ready":false}
	var outcome:=str(s.get("outcome",""))
	if outcome not in ["hit","guard_break","guard","blocked","armor","steel","counter","bullet_clash"]:return {"ready":false}
	var confirmed:=outcome in ["hit","guard_break"]
	var final:=confirmed and bool(s.get("finisher",false))
	var progress:=clampf(float(s.get("phase",0)),0,1)
	var scale:=1.42 if final and int(s.get("tier",1))==3 else (1.17 if final else 1.0)
	var result:=_packet(id,slot,"contact" if confirmed else "deflect",progress,float(s.get("source_frame",0)),int(s.get("tier",1)),_v(s.get("pos")),_axis(s),maxf(1,float(s.get("height",90)))*scale,float(s.get("alpha",0))*.79)
	result["confirmed_contact"]=confirmed
	result["packet_kind"]="contact"
	result["finisher"]=final
	result["outcome"]=outcome
	return result

static func sample_object(s: Dictionary) -> Dictionary:
	var id:=str(s.get("id",""));var slot:=str(s.get("slot",""))
	if not s.get("ready",false) or id not in ["chicken","worker"] or slot not in SLOTS or s.get("normal_launcher",false) or s.get("bullet_hit",false) or not s.get("active_regions",false):return {"ready":false,"projectile_copies":0}
	var box: Rect2=s.get("box",Rect2())
	if not box.has_area():return {"ready":false}
	var frame:=float(s.get("frame",0))+clampf(float(s.get("source_clock",0))*30,0,.999)
	var velocity:=_v(s.get("velocity"),Vector2(float(s.get("facing",1)),0))
	var axis:=velocity.normalized() if velocity.length_squared()>.01 else _axis(s)
	# A material wake follows the actual child. It is never another ball/page
	# collider. Looping curls sample this child's clock and stop when it stops.
	var phase:=fposmod(frame/12.0,1.0)
	var result:=_packet(id,slot,"release",phase,frame,3 if slot=="SI" else 2,box.get_center(),axis,maxf(1,float(s.get("height",90)))*.64,.55)
	result["source_object"]=s.get("name","")
	result["packet_kind"]="child"
	result["birth_source_absolute_frame"]=s.get("birth_source_absolute_frame",-1)
	result["actual_box"]=box
	return result

static func _new_mesh() -> Dictionary:
	return {"points":PackedVector2Array(),"colors":PackedColorArray(),"indices":PackedInt32Array(),"parts":0,"bounds":Rect2()}

static func _triangle(mesh: Dictionary,a: Vector2,b: Vector2,c: Vector2,color: Color) -> void:
	if absf((b-a).cross(c-a))<.0000001:return
	var index: int=mesh.points.size()
	mesh.points.append_array(PackedVector2Array([a,b,c]))
	mesh.colors.append_array(PackedColorArray([color,color,color]))
	mesh.indices.append_array(PackedInt32Array([index,index+1,index+2]))

static func _fan(mesh: Dictionary,points: PackedVector2Array,color: Color) -> void:
	# Share each authored polygon's vertices. The ordered triangle corners and
	# per-corner RGBA remain identical to the previous expanded triangle soup.
	if points.size()<3:return
	var base: int=mesh.points.size()
	var indices:=PackedInt32Array()
	for n in range(1,points.size()-1):
		# Keep the original _triangle degeneracy threshold and winding.
		if absf((points[n]-points[0]).cross(points[n+1]-points[0]))<.0000001:continue
		indices.append_array(PackedInt32Array([base,base+n,base+n+1]))
	if not indices.is_empty():
		var colors:=PackedColorArray();colors.resize(points.size());colors.fill(color)
		mesh.points.append_array(points)
		mesh.colors.append_array(colors)
		mesh.indices.append_array(indices)
	mesh.parts=int(mesh.parts)+1

static func _ellipse(mesh: Dictionary,center: Vector2,radii: Vector2,color: Color,rotation: float=0) -> void:
	var points:=PackedVector2Array()
	for n in range(9):
		var angle:=TAU*float(n)/9
		points.append(center+Vector2(cos(angle)*radii.x,sin(angle)*radii.y).rotated(rotation))
	_fan(mesh,points,color)

static func _material_piece(mesh: Dictionary,id: String,p: Vector2,size: float,rotation: float,fold: float,index: int) -> void:
	var colors: Array=PALETTES[id]
	var axis:=Vector2.RIGHT.rotated(rotation);var side:=axis.orthogonal()
	match id:
		"rio":
			# A sapphire crystal has a dark rear face, a luminous edge and a
			# distinct gold conductor. Its facets are not one flat cyan triangle.
			var tip:=p+axis*size*(1.15+.45*fold)
			var root:=p-axis*size*.78
			var shoulder:=p+axis*size*.10+side*size*(.35+.16*fold)
			_fan(mesh,PackedVector2Array([root,p-side*size*.30,tip,shoulder]),colors[0])
			_triangle(mesh,root,p-side*size*.24,tip,colors[1])
			_triangle(mesh,root,tip,shoulder,colors[0].lightened(.19))
			_fan(mesh,PackedVector2Array([root+side*size*.035,tip-axis*size*.07,p+axis*size*.27+side*size*.10,p-axis*size*.33+side*size*.07]),colors[3])
			_triangle(mesh,p-side*size*.29,tip,p+axis*size*.08-side*size*.18,colors[2])
		"chicken":
			# Partial round basketball panels replace thin folded strips. Their
			# curved boundary and black seams identify rubber without fake balls.
			var root:=p-axis*size*.22
			var outline:=PackedVector2Array([root])
			var inner:=PackedVector2Array([root+axis*size*.065])
			for n in range(7):
				var angle:=lerpf(-.80,.76,float(n)/6.0)
				var radial:=axis*cos(angle)+side*sin(angle)
				outline.append(root+radial*size*(.97+.09*fold))
				inner.append(root+radial*size*(.89+.08*fold))
			_fan(mesh,outline,colors[0])
			_fan(mesh,inner,colors[1])
			_triangle(mesh,root+axis*size*.065,inner[2],inner[4],colors[2])
			var seam:=p+axis*size*.30
			_fan(mesh,PackedVector2Array([root-side*size*.035,seam-side*size*.025,outline[4],seam+side*size*.025,root+side*size*.035]),colors[0])
			_triangle(mesh,inner[2]-axis*size*.055,inner[3]-axis*size*.05,inner[3]-axis*size*.13,colors[3])
		"cat":
			# Cream tuft silhouette, plum underside and a small pink pad retain
			# furry material at native battle size rather than a pink flat bean.
			_fan(mesh,PackedVector2Array([p-axis*size*.65,p-axis*size*.39-side*size*.40,p+side*size*-.32,p+axis*size*.58-side*size*.43,p+axis*size*.43,p+axis*size*.67+side*size*.18,p+side*size*.37,p-axis*size*.45+side*size*.30]),colors[0])
			_fan(mesh,PackedVector2Array([p-axis*size*.53,p-axis*size*.30-side*size*.32,p+axis*size*.53-side*size*.30,p+axis*size*.29,p+axis*size*.47+side*size*.17,p-side*size*-.26]),colors[2])
			_ellipse(mesh,p-axis*size*.12+side*size*.03,Vector2(size*.22,size*.14),colors[1],rotation)
			for n in range(3):
				var base:=p+side*size*(float(n)-1)*.24
				var tip:=base+axis*size*(.76+fold*.64+float(n%2)*.17)
				_triangle(mesh,base-side*size*.13,tip,base+side*size*.16,colors[3])
		"worker":
			# Fold moves across the sheet each cel, changing both face and silhouette.
			var left:=p-axis*size*.76;var right:=p+axis*size*.76
			var hinge:=p+axis*size*lerpf(-.34,.30,fold)
			var corner:=right+side*size*(.53-fold*.35)
			_fan(mesh,PackedVector2Array([left-side*size*.50,hinge-side*size*.50,hinge+side*size*.50,left+side*size*.50]),colors[2])
			_fan(mesh,PackedVector2Array([hinge-side*size*.50,right-side*size*.38,corner,hinge+side*size*.50]),colors[1])
			_triangle(mesh,hinge+side*size*.50,corner,hinge+axis*size*.16+side*size*.10,colors[0])
			_triangle(mesh,left-side*size*.50,hinge-side*size*.50,left+side*size*.36,Color("fff9e9"))
			_triangle(mesh,hinge-side*size*.50,corner,hinge+side*size*.17,colors[1].lightened(.22))
			for n in range(2):
				var at:=left+axis*size*.22+side*size*(float(n)-.5)*.26
				_fan(mesh,PackedVector2Array([at,at+axis*size*.55,at+axis*size*.55+side*size*.044,at+side*size*.044]),colors[0])
			if index%3==0:_ellipse(mesh,left+axis*size*.39+side*size*.20,Vector2(size*.12,size*.15),colors[3],rotation)
		"shark":
			# A curved wave chip rolls around one rounded foam cap. Fixed topology
			# permits smooth indexed morphing through all source fractions.
			var tip:=p+axis*size*(1.05+.42*fold)
			_fan(mesh,PackedVector2Array([p-axis*size*.65,p-axis*size*.40-side*size*.41,p+axis*size*.18-side*size*.39,tip,p+axis*size*.29+side*size*.15,p+axis*size*.07+side*size*.35,p-axis*size*.38+side*size*.32]),colors[0])
			_fan(mesh,PackedVector2Array([p-axis*size*.46,p-axis*size*.23-side*size*.30,p+axis*size*.15-side*size*.29,tip-axis*size*.12,p+axis*size*.21+side*size*.09,p-axis*size*.23+side*size*.24]),colors[1])
			_triangle(mesh,p-side*size*.26,tip-axis*size*.15,p+axis*size*.18-side*size*.09,colors[2])
			_ellipse(mesh,p-axis*size*.20-side*size*(.10+.09*fold),Vector2(size*.31,size*(.16+.035*fold)),colors[3],rotation+.26)

static func _build_cel(id: String,slot: String,stage: String,index: int) -> Dictionary:
	var mesh:=_new_mesh()
	var count:=int(CELS[stage]);var t:=float(index)/maxf(1,float(count-1))
	var slot_index:=SLOTS.find(slot)
	var tier:=3 if slot=="SI" else (2 if slot in ["I","WI","AIR_I"] else 1)
	var pieces:=4 if tier==1 else (6 if tier==2 else 8)
	if stage=="deflect":pieces=3
	var compression:=sin(minf(t*2.0,1.0)*PI*.5)
	var opening:=_ease(clampf((t-.13)/.87,0,1))
	for n in range(pieces):
		var u:=float(n)/float(pieces)
		var angle:=u*TAU+.18*float(slot_index)+(.42 if n%2==0 else -.27)
		var direction:=Vector2.RIGHT.rotated(angle)
		var distance: float=.0;var position:=Vector2.ZERO;var size: float=.0;var rotation: float=.0
		var fold:=.5+.5*sin((t*.86+float(n)*.17)*TAU-PI*.5)
		match stage:
			"prepare":
				# Distinct curved intake trajectories converge into the actual anchor.
				distance=lerpf(.70+.11*float(n%3),.16,_ease(t))
				position=direction.rotated(t*(.56+.12*float(n%2)))*distance
				position.x*=.76;position.y*=.64
				size=(.045+.022*float(n%2))*(.47+.65*sin(t*PI*.75))
				rotation=angle+PI+t*.65
			"release":
				# Curl then disintegrate along the attack axis. The anchor is not copied.
				position=Vector2(.10+t*.42+u*.24,(float(n)-float(pieces-1)*.5)*.15)
				position.y+=sin((t*1.32+u)*PI)*(.12+.04*float(n%2))
				position.x+=sin(t*PI+u*TAU)*.07
				size=(.040+.014*float(n%3))*(1-.51*t)
				rotation=.1+sin(t*PI+u*TAU)*.42
			"recover":
				position=direction*(.17+t*(.39+.05*float(n%3)))
				position.y+=t*t*.31
				size=(.039+.011*float(n%2))*(1-.64*t)
				rotation=angle+t*(1.16+.23*float(n%2))
			"contact":
				# True contact compresses before unfolding; keep the chest center open.
				distance=.24+opening*(.52+.12*float(n%3))
				position=direction*distance
				position.x*=.63+.56*compression
				position.y*=.73+.18*opening
				position.y+=t*t*.16
				size=(.051+.018*float(n%3))*(.84+.21*compression-.37*opening)
				rotation=angle+sin(t*PI)*.64+t*.23
			"deflect":
				position=Vector2(-.13-t*.29,(float(n)-1)*(.17+t*.23))
				size=.031*(1-t*.45);rotation=PI+(float(n)-1)*.55+t*.35
		_material_piece(mesh,id,position,size,rotation,fold,n)
	# Cels retain their own topology. A later droplet can genuinely split, while
	# a folded page can have a moving hinge; no uniform transform can create it.
	var bounds:=Rect2()
	var has_point:=false
	for point: Vector2 in mesh.points:
		if not has_point:bounds=Rect2(point,Vector2.ZERO);has_point=true
		else:bounds=bounds.expand(point)
	mesh["bounds"]=bounds
	mesh["cel"]=index;mesh["stage"]=stage;mesh["material"]=MATERIALS[id]
	return mesh

static func cel_mesh(id: String,slot: String,stage: String,index: int) -> Dictionary:
	if id not in IDS or slot not in SLOTS or not CELS.has(stage):return _new_mesh()
	index=clampi(index,0,int(CELS[stage])-1)
	var key:=id+":"+slot+":"+stage+":"+str(index)
	if _cache.has(key):return _cache[key]
	var mesh:=_build_cel(id,slot,stage,index)
	_cache[key]=mesh;_cache_order.append(key)
	# Finite cache, and no retained native Canvas objects or capture actors.
	while _cache_order.size()>512:_cache.erase(_cache_order.pop_front())
	return mesh

static func render_mesh(packet: Dictionary) -> Dictionary:
	if not packet.get("ready",false):return _new_mesh()
	var current: Dictionary=cel_mesh(str(packet.id),str(packet.slot),str(packet.stage),int(packet.cel))
	var next: Dictionary=cel_mesh(str(packet.id),str(packet.slot),str(packet.stage),int(packet.next_cel))
	var mix:=float(packet.mix)
	var canonical: PackedVector2Array=current.points
	var upcoming: PackedVector2Array=next.points
	var current_colors: PackedColorArray=current.colors
	var next_colors: PackedColorArray=next.colors
	var current_indices: PackedInt32Array=current.indices
	var next_indices: PackedInt32Array=next.indices
	# The old soup had sequential indices, so an equal triangle count always
	# interpolated. Splitting foam can redistribute polygons without changing
	# that count. Preserve the old ordered-corner pairing in those rare cases.
	var interpolate: bool=current_indices.size()==next_indices.size()
	var shared_pairing: bool=canonical.size()==upcoming.size() and current_indices==next_indices
	var expanded_pairing: bool=interpolate and not shared_pairing
	var count: int=current_indices.size() if expanded_pairing else canonical.size()
	var points:=PackedVector2Array();points.resize(count)
	var colors:=PackedColorArray();colors.resize(count)
	var indices:=current_indices
	if expanded_pairing:
		indices=PackedInt32Array();indices.resize(count)
	var origin: Vector2=packet.origin;var axis: Vector2=packet.axis;var side:=axis.orthogonal();var h:=float(packet.height)
	var opacity:=float(packet.opacity)
	for n in range(count):
		var current_index: int=current_indices[n] if expanded_pairing else n
		var next_index: int=next_indices[n] if expanded_pairing else n
		var point: Vector2=canonical[current_index].lerp(upcoming[next_index],mix) if interpolate else canonical[current_index]
		# Keep the original floating point operation order as well as its shape.
		points[n]=origin+(axis*point.x+side*point.y)*h
		var color: Color=current_colors[current_index]
		if interpolate:color=color.lerp(next_colors[next_index],mix)
		color.a*=opacity;colors[n]=color
		if expanded_pairing:indices[n]=n
	return {"points":points,"colors":colors,"indices":indices,"parts":current.parts,"material":current.material,"cel":current.cel,"stage":current.stage,"interpolated_material_shape":interpolate,"submitted_meshes":0 if points.is_empty() else 1,"triangles":current_indices.size()/3}

static func _draw(canvas: CanvasItem,packet: Dictionary) -> Dictionary:
	if not packet.get("ready",false) or float(packet.get("opacity",0))<=.002:return packet
	var mesh:=render_mesh(packet)
	if mesh.indices.is_empty():return packet
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),mesh.indices,mesh.points,mesh.colors)
	if _observer.is_valid():_observer.call({"id":packet.id,"slot":packet.slot,"stage":packet.stage,"cel":packet.cel,"next_cel":packet.next_cel,"source_frame":packet.source_frame,"source_absolute_frame":packet.get("source_absolute_frame",-1),"source_label":packet.get("source_label",""),"source_interval_start":packet.get("source_interval_start",-1),"source_interval_end":packet.get("source_interval_end",-1),"packet_kind":packet.get("packet_kind",""),"real_release":packet.get("real_release",false),"confirmed_contact":packet.get("confirmed_contact",false),"source_object":packet.get("source_object",""),"mesh_submissions":1,"material":packet.material,"triangles":mesh.triangles})
	return packet

static func draw_actor(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:
	var packet:=sample_actor(s)
	if layer=="back":_draw(canvas,packet)
	return packet

static func draw_contact(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:
	var packet:=sample_contact(s)
	# Material fragments travel outside the center. One rear batch supports the
	# existing foreground contact nucleus without covering the victim's pose.
	if layer=="back":_draw(canvas,packet)
	return packet

static func draw_object(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:
	var packet:=sample_object(s)
	if layer=="back":_draw(canvas,packet)
	return packet
