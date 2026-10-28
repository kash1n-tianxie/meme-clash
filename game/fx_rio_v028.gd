extends RefCounted
const FrameFX=preload("res://game/bvn_frame_fx_v031.gd")
## v0.32: faceted sapphire blade, gold conduits and source-clock reflections.
## All release/contact times are supplied by the archived BVN HitVO clock.
const STEEL := Color("2187ec")
const SILVER := Color("dbfaff")
const CORE := Color("1247c2")
const INK := Color("081c56")
const GOLD := Color("ffd264")
const CYAN := Color("4cedff")
const BRONZE := Color("bd7823")
const EARTH := Color("b49987")
const DECORATIVE_FACE_ALPHA := .14
const DECORATIVE_EDGE_ALPHA := .49
const MOTIFS := {"U":"wide_steel_crescent","SU":"counter_low_earth_blade","WU":"rising_steel_edge","AIR_U":"diagonal_air_cut","I":"stepped_heavy_swordwheel","WI":"ascending_giant_blade_combo","SI":"giant_blade_drop_fracture","AIR_I":"airborne_heavy_press"}
const GIANT_PROFILES := {
	"U":{"scale":2.15,"height_min":1.34,"height_max":2.02,"width":.27,"sweep":1.37},
	"SU":{"scale":2.35,"height_min":1.46,"height_max":2.16,"width":.32,"sweep":1.43},
	"WU":{"scale":2.22,"height_min":1.43,"height_max":2.12,"width":.28,"sweep":1.32},
	"AIR_U":{"scale":2.28,"height_min":1.40,"height_max":2.08,"width":.28,"sweep":1.29},
	"I":{"scale":2.86,"height_min":1.82,"height_max":2.51,"width":.36,"sweep":1.62},
	"WI":{"scale":2.73,"height_min":1.80,"height_max":2.48,"width":.34,"sweep":1.51},
	"SI":{"scale":3.68,"height_min":2.32,"height_max":3.10,"width":.46,"sweep":1.95},
	"AIR_I":{"scale":2.92,"height_min":1.88,"height_max":2.62,"width":.38,"sweep":1.59}
}

static func _v(value: Variant) -> Vector2:
	if value is Vector2:return value
	if value is Array and value.size()>=2:return Vector2(float(value[0]),float(value[1]))
	return Vector2(INF,INF)

static func geometry(s: Dictionary) -> Dictionary:
	if not s.get("ready",false) or str(s.get("id",""))!="rio":return {"ready":false}
	var anchors: Dictionary=s.get("anchors",{})
	var grip:=_v(anchors.get("weapon_grip"));var tip:=_v(anchors.get("weapon_tip"))
	if not grip.is_finite() or not tip.is_finite():return {"ready":false,"missing_anchor":true}
	var h:=float(s.get("height",90.0));var blade:=tip-grip
	if blade.length_squared()<h*h*.0001:return {"ready":false,"missing_anchor":true}
	var release: Dictionary=s.get("release_state",{})
	var bounds:=Rect2();var has_bounds:=false
	for value: Variant in s.get("boxes",[]):
		if value is Rect2 and value.has_area():bounds=bounds.merge(value) if has_bounds else value;has_bounds=true
	return {"ready":true,"grip":grip,"tip":tip,"axis":blade.normalized(),"blade_length":blade.length(),"active":bool(release.get("active",false)),"phase":float(release.get("phase",0)),"collision_bounds":bounds,"has_collision_bounds":has_bounds,"motif":MOTIFS.get(str(s.get("slot","")),"painted_steel"),"body_copies":0,"attached_to":["weapon_grip","weapon_tip"],"solid_motif":true,"source_clock_mutated":false,"creates_contact":false}

static func _ease(value: float) -> float:
	var t:=clampf(value,0,1)
	return t*t*(3.0-2.0*t)

## Every size/opacity derives from this sampled source state. The extension
## is painted steel, never an additional HitVO, projectile or attack range.
## Keeping the near spine on the front and the broad face behind the actors
## joins the original cel sword into one blade without hiding hands/faces.
static func weapon_enlargement(s: Dictionary) -> Dictionary:
	var g:=geometry(s)
	if not g.get("ready",false):return g
	var slot:=str(s.get("slot","U"))
	var profile: Dictionary=GIANT_PROFILES.get(slot,GIANT_PROFILES["U"])
	var h:=maxf(1.0,float(s.get("height",90)))
	var release: Dictionary=s.get("release_state",{})
	var cinema: Dictionary=s.get("cinema_phase",{})
	var stage:=str(cinema.get("stage",""))
	var prepare:=float(release.get("prepare",0))
	if stage in ["prepare","open"]:prepare=maxf(prepare,float(cinema.get("progress",0)))
	var growth:=0.0
	var visibility:=0.0
	if g.active:
		growth=1.0
		visibility=1.0
	elif prepare>0:
		growth=_ease(clampf((prepare-.10)/.90,0,1))
		visibility=.22+.59*growth
	elif release.get("recovering",false):
		growth=1.0-_ease(float(release.get("recovery_phase",1)))
		visibility=pow(growth,1.25)*.67
	elif int(s.get("tier",1))>=2 and stage in ["entry","combo","heavy","rotation","rise","descent"]:
		# Between the real multi-hit windows retain a softer single sword.
		# This is a held weapon transition, not a fabricated active release.
		growth=.77
		visibility=.42
	var source_length:=float(g.blade_length)
	# Foreshortened cels do not suddenly become a sixteen-times-longer sword;
	# unusually long original cels are retained rather than clamped shorter.
	var ceiling:=maxf(source_length,minf(h*float(profile.height_max),source_length*8.0))
	var minimum:=minf(ceiling,maxf(source_length,h*float(profile.height_min)))
	var peak:=clampf(source_length*float(profile.scale),minimum,ceiling)
	if slot=="SI" and stage in ["rise","descent"]:peak=maxf(source_length,minf(minf(h*3.30,source_length*8.0),peak*1.10))
	var visual_length:=lerpf(float(g.blade_length),peak,growth)
	var root_distance:=maxf(h*.082,float(g.blade_length)*.075)
	var source_reach:=float(g.blade_length)
	if g.has_collision_bounds:
		var bounds: Rect2=g.collision_bounds
		for corner: Vector2 in [bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]:
			source_reach=maxf(source_reach,(corner-Vector2(g.grip)).dot(Vector2(g.axis)))
	var core_length:=minf(visual_length,maxf(float(g.blade_length),source_reach))
	var width:=h*lerpf(.15,float(profile.width),growth)
	var tier:=int(s.get("tier",1))
	var result: Dictionary={"ready":true,"slot":slot,"grip":g.grip,"axis":g.axis,"root":Vector2(g.grip)+Vector2(g.axis)*root_distance,"root_distance":root_distance,"source_tip":g.tip,"tip":Vector2(g.grip)+Vector2(g.axis)*visual_length,"length":visual_length,"peak_length":peak,"source_blade_length":g.blade_length,"core_length":core_length,"width":width,"growth":growth,"visibility":visibility,"active":g.active,"phase":g.phase,"sweep_scale":float(profile.sweep),"decorative_extension":visual_length>source_reach,"source_reach":source_reach,"body_copies":0,"weapon_copies":1,"source_clock_mutated":false,"creates_contact":false,"changes_hit_range":false,"attached_to":["weapon_grip","weapon_tip"],"stage":stage,"tier":tier,"radiant":true,"prepare":prepare,"ring_radius":Vector2(h*(.32+.40*growth),h*(.19+.25*growth)),"beam_length":visual_length*(1.32 if tier==3 else 1.10),"beam_width":h*(.51 if tier==3 else .32),"beam_alpha":visibility*(.41 if tier==3 else .25) if bool(g.active) and tier>=2 else 0.0,"energy_particles":5 if tier==3 else 3,"beam_source_owned":true,"energy_phase":float(g.phase) if bool(g.active) else prepare}
	result["hull"]=_giant_blade_hull(result)
	result["beam_hull"]=_radiant_beam_hull(result)
	result["near_cover_extra"]=h*.14 if slot=="U" else 0.0
	result["near_cover_upper_bias"]=.16 if slot=="U" else 0.0
	return result

static func _giant_blade_hull(weapon: Dictionary) -> PackedVector2Array:
	var root: Vector2=weapon.root
	var axis: Vector2=weapon.axis
	var side:=axis.orthogonal()
	var length:=maxf(.1,float(weapon.length)-float(weapon.root_distance))
	var width:=float(weapon.width)
	var top_lift:=0.0
	return PackedVector2Array([root-side*width*.20,root+axis*length*.14-side*width*(.59+top_lift),root+axis*length*.79-side*width*(.45+top_lift*.5),root+axis*length,root+axis*length*.83+side*width*.43,root+axis*length*.11+side*width*.46])

static func _radiant_beam_hull(weapon: Dictionary) -> PackedVector2Array:
	var root: Vector2=weapon.root
	var axis: Vector2=weapon.axis
	var side:=axis.orthogonal()
	var length:=float(weapon.beam_length)
	var width:=float(weapon.beam_width)
	return PackedVector2Array([root-side*width*.12,root+axis*length*.16-side*width*.61,root+axis*length*.83-side*width*.69,root+axis*length,root+axis*length*.83+side*width*.69,root+axis*length*.16+side*width*.61])

static func _radiant_spell(canvas: CanvasItem,weapon: Dictionary) -> void:
	var a:=float(weapon.visibility)
	if a<=.002 or float(weapon.growth)<=.002:return
	var root: Vector2=weapon.root
	var axis: Vector2=weapon.axis
	var side:=axis.orthogonal()
	var h:=float(weapon.width)/maxf(.15,lerpf(.15,float(GIANT_PROFILES.get(str(weapon.slot),GIANT_PROFILES["U"]).width),float(weapon.growth)))
	var phase:=float(weapon.energy_phase)
	var tier:=int(weapon.tier)
	var beam_alpha:=float(weapon.beam_alpha)
	if beam_alpha>.002:
		# A source-owned sapphire/gold light column surrounds the one sword.
		# It has volume and a pointed release edge, never a second collider.
		_poly(canvas,weapon.beam_hull,CORE,beam_alpha)
		var length:=float(weapon.beam_length)
		var width:=float(weapon.beam_width)
		_poly(canvas,PackedVector2Array([root+axis*length*.12-side*width*.09,root+axis*length*.30-side*width*.37,root+axis*length*.86-side*width*.36,root+axis*length*.96,root+axis*length*.86+side*width*.36,root+axis*length*.30+side*width*.37]),CYAN,beam_alpha*.92)
		_poly(canvas,PackedVector2Array([root+axis*length*.22-side*width*.032,root+axis*length*.90-side*width*.12,root+axis*length*.98,root+axis*length*.90+side*width*.12,root+axis*length*.22+side*width*.032]),GOLD,beam_alpha*1.19)
	# A tilted, open light ring wraps the middle of the blade. Thin gold rim
	# plus a wider cyan face read as a halo, with the fighter visible inside.
	var center:=root+axis*float(weapon.length)*(.38 if weapon.active else .48)
	var radius: Vector2=weapon.ring_radius*(.86+phase*.19)
	var ring_width:=h*(.052 if tier==1 else .067)
	var begin:=-1.77+phase*.34
	var end:=1.00+phase*.34
	_poly(canvas,_crescent_shape(center,radius,begin,end,ring_width,axis.angle()+.32),CYAN,a*.52)
	_poly(canvas,_crescent_shape(center,radius,begin,end,ring_width*.26,axis.angle()+.32,ring_width*.25),GOLD,a*.90)
	for n in range(int(weapon.energy_particles)):
		var sign_value: float=-1.0 if n%2==0 else 1.0
		var travel: float=.34+float(n)*.11
		var distance:=h*((.18+phase*.69) if weapon.active else (.98-.73*float(weapon.growth)))
		var at:=root+axis*float(weapon.length)*travel+side*sign_value*distance
		var direction:=(-side*sign_value if not weapon.active else (axis*.65+side*sign_value*.45).normalized())
		var cross:=direction.orthogonal()
		var size:=h*(.046 if tier==1 else .062)
		_poly(canvas,PackedVector2Array([at-direction*size*1.35-cross*size*.40,at+direction*size*1.65,at-direction*size*.50+cross*size*.49]),GOLD if n%2==0 else CYAN,a*.83)

static func amplification(s: Dictionary) -> Dictionary:
	var result:=weapon_enlargement(s)
	if not result.get("ready",false):return result
	result["id"]="rio"
	result["tier"]=int(s.get("tier",1))
	result["motif"]=MOTIFS.get(str(s.get("slot","U")),"painted_steel")
	result["changes_source"]=false
	result["source_owned"]=true
	result["weapon_reach"]=result.length
	result["weapon_width"]=result.width
	result["visual_scale"]=float(result.length)/maxf(.1,float(result.source_blade_length))
	# The front near face is the opaque cover of the existing cel sword.
	# The much larger rear face fades into translucent decorative energy.
	result["core_alpha"]=minf(1.0,float(result.visibility)*1.23)
	result["back_core_alpha"]=float(result.visibility)*(.91 if result.decorative_extension else .97)
	result["tail_face_alpha"]=float(result.back_core_alpha)*DECORATIVE_FACE_ALPHA
	result["tail_edge_alpha"]=float(result.back_core_alpha)*.99*DECORATIVE_EDGE_ALPHA
	return result

static func weapon_vertex_alpha(weapon: Dictionary,point: Vector2,alpha: float,glowing_edge: bool=false) -> float:
	var distance: float=(point-Vector2(weapon.grip)).dot(Vector2(weapon.axis))
	var core:=float(weapon.core_length)
	var tail:=maxf(.001,float(weapon.length)-core)
	var fade:=_ease(clampf((distance-core)/tail,0,1))
	return clampf(alpha*lerpf(1.0,DECORATIVE_EDGE_ALPHA if glowing_edge else DECORATIVE_FACE_ALPHA,fade),0,1)

static func weapon_paint_points(weapon: Dictionary,points: PackedVector2Array) -> PackedVector2Array:
	# Insert collinear vertices at the core boundary and halfway through the
	# energy tail. This preserves the silhouette and keeps GPU interpolation
	# from making the genuinely reachable near face translucent prematurely.
	var result:=points.duplicate()
	var core:=float(weapon.core_length)
	var tail:=float(weapon.length)-core
	var axis: Vector2=weapon.axis
	var grip: Vector2=weapon.grip
	var planes: Array[float]=[]
	if tail>.001:planes.append_array([core,core+tail*.55])
	# Collinear reflection boundaries leave the hull/hand relationship intact.
	# They let vertex lighting form a moving narrow highlight instead of
	# interpolating one uniform blue face from its six outer corners.
	var center:=.24+float(weapon.energy_phase)*.55
	for u: float in [center-.12,center,center+.12]:
		planes.append(float(weapon.root_distance)+(float(weapon.length)-float(weapon.root_distance))*clampf(u,0,1))
	for plane: float in planes:
		var split:=PackedVector2Array()
		for n in range(result.size()):
			var a:=result[n]
			var b:=result[(n+1)%result.size()]
			var da: float=(a-grip).dot(axis)-plane
			var db: float=(b-grip).dot(axis)-plane
			split.append(a)
			if (da<-.001 and db>.001) or (da>.001 and db<-.001):split.append(a.lerp(b,da/(da-db)))
		result=split
	return result

static func _weapon_poly(canvas: CanvasItem,weapon: Dictionary,original_points: PackedVector2Array,color: Color,alpha: float,outline: bool=false,glowing_edge: bool=false) -> void:
	if alpha<=.002 or original_points.size()<3:return
	var points:=weapon_paint_points(weapon,original_points)
	var lower:=points[0]
	var upper:=points[0]
	for point: Vector2 in points:lower=lower.min(point);upper=upper.max(point)
	var colors:=PackedColorArray()
	var edges:=PackedColorArray()
	var axis: Vector2=weapon.axis;var side:=axis.orthogonal()
	var length:=maxf(1,float(weapon.length)-float(weapon.root_distance))
	var width:=maxf(1,float(weapon.width))
	var reflection_center:=.24+float(weapon.energy_phase)*.55
	for point: Vector2 in points:
		var up: float=1.0-(point.y-lower.y)/maxf(1.0,upper.y-lower.y)
		var local:=point-Vector2(weapon.root)
		var along:=local.dot(axis)/length
		var across:=local.dot(side)/width
		var reflection:=pow(maxf(0,1-absf(along-reflection_center)/.12),2.0)
		var edge_light:=clampf(.48-across*.42,0,1)
		var lit: Color=color.lerp(SILVER,up*.08+edge_light*.13+reflection*.33).lerp(INK,(1-edge_light)*.24)
		colors.append(Color(lit,weapon_vertex_alpha(weapon,point,alpha,glowing_edge)))
		edges.append(Color(INK,weapon_vertex_alpha(weapon,point,alpha*.96,glowing_edge)))
	canvas.draw_polygon(points,colors)
	if outline:
		var edge:=points.duplicate()
		edge.append(points[0])
		edges.append(edges[0])
		canvas.draw_polyline_colors(edge,edges,1.6,true)

static func _near_facet_points(points: PackedVector2Array,root: Vector2,axis: Vector2,width: float,length: float,bevel: float,span: float) -> PackedVector2Array:
	if bevel<=.001:return points
	# Clip existing face paint at the same oblique terminal plane. This avoids
	# a short foreshortened cel leaving a rectangular dark facet past the join.
	var side: Vector2=axis.orthogonal()
	var result: PackedVector2Array=PackedVector2Array()
	for n in range(points.size()):
		var a: Vector2=points[n]
		var b: Vector2=points[(n+1)%points.size()]
		var da: float=(a-root).dot(axis)+bevel*((a-root).dot(side)/width+.54)/span-length
		var db: float=(b-root).dot(axis)+bevel*((b-root).dot(side)/width+.54)/span-length
		if da<=0:result.append(a)
		if (da<0 and db>0) or (da>0 and db<0):result.append(a.lerp(b,da/(da-db)))
	return result

static func near_blade_surface(weapon: Dictionary) -> Dictionary:
	var root: Vector2=weapon.root
	var axis: Vector2=weapon.axis
	var side: Vector2=axis.orthogonal()
	var width: float=weapon.width
	var length: float=maxf(.1,float(weapon.length)-float(weapon.root_distance))
	var near_length: float=maxf(.1,minf(length,float(weapon.source_blade_length)-float(weapon.root_distance)+float(weapon.get("near_cover_extra",0))))
	var far: Vector2=root+axis*near_length
	var upper_bias: float=weapon.get("near_cover_upper_bias",0)
	# Retract only the U cover's lower corner inside its existing extra cover.
	# The original cel tip stays covered; the giant outer hull never changes.
	var source_core: float=maxf(0.0,float(weapon.source_blade_length)-float(weapon.root_distance))
	var available_cover: float=maxf(0.0,near_length-source_core)
	var bevel: float=minf(width*.28,minf(available_cover*.42,near_length*.33))
	# The fade starts beyond the real cel tip even on the retracted corner.
	# A short cover never uncovers the source sword just to hide a material seam.
	var blend_width: float=minf(width*.36,(available_cover-bevel)*.94)
	var span: float=.92+upper_bias
	var upper_end: Vector2=far-side*width*.54
	var lower_end: Vector2=far-axis*bevel+side*width*(.38+upper_bias)
	var steel_upper: Vector2=far-axis*bevel*(.54-.38)/span-side*width*.38
	var steel_lower: Vector2=far-axis*bevel*(.54-.09)/span-side*width*.09
	var gold_upper: Vector2=far-axis*bevel*(.54-.48)/span-side*width*.48
	var gold_lower: Vector2=far-axis*bevel*(.54-.35)/span-side*width*.35
	var reflection: PackedVector2Array=PackedVector2Array([root+axis*near_length*.22-side*width*.17,root+axis*near_length*.49-side*width*.29,root+axis*near_length*.69-side*width*.13,root+axis*near_length*.50-side*width*.20])
	var shade_near: PackedVector2Array=PackedVector2Array([root+axis*near_length*.15+side*width*.22,root+axis*near_length*.43-side*width*.10,root+axis*near_length*.59+side*width*.04,root+axis*near_length*.36+side*width*.30])
	var shade_far: PackedVector2Array=PackedVector2Array([root+axis*near_length*.39-side*width*.16,root+axis*near_length*.71-side*width*.08,root+axis*near_length*.94+side*width*.22,root+axis*near_length*.67+side*width*.07])
	var ridge: PackedVector2Array=PackedVector2Array([root+axis*near_length*.18+side*width*.10,root+axis*near_length*.41+side*width*.16,root+axis*near_length*.72-side*width*.005,root+axis*near_length*.93+side*width*.055,root+axis*near_length*.72+side*width*.030,root+axis*near_length*.40+side*width*.22,root+axis*near_length*.18+side*width*.13])
	return {"length":near_length,"bevel":bevel,"span":span,"blend_width":blend_width,"face":PackedVector2Array([root-side*width*.19,root+axis*near_length*.20-side*width*.57,upper_end,lower_end,root+axis*near_length*.13+side*width*(.38+upper_bias*.5)]),"steel":PackedVector2Array([root-side*width*.12,steel_upper,steel_lower,root-side*width*.018]),"gold":PackedVector2Array([root-side*width*.11,root+axis*near_length*.20-side*width*.50,gold_upper,gold_lower,root+axis*near_length*.20-side*width*.38,root-side*width*.05]),"shade_near":_near_facet_points(shade_near,root,axis,width,near_length,bevel,span),"shade_far":_near_facet_points(shade_far,root,axis,width,near_length,bevel,span),"ridge":_near_facet_points(ridge,root,axis,width,near_length,bevel,span),"reflection":_near_facet_points(reflection,root,axis,width,near_length,bevel,span),"join":PackedVector2Array([upper_end,lower_end])}

static func _near_end_distance(weapon: Dictionary,near: Dictionary,point: Vector2) -> float:
	var local: Vector2=point-Vector2(weapon.root)
	var axis: Vector2=weapon.axis
	return float(near.length)-local.dot(axis)-float(near.bevel)*(local.dot(axis.orthogonal())/float(weapon.width)+.54)/float(near.span)

static func near_blade_paint(weapon: Dictionary,near: Dictionary,original_points: PackedVector2Array,color: Color,alpha: float) -> Dictionary:
	var points: PackedVector2Array=original_points
	var band: float=near.blend_width
	if band>.001:
		# Collinear half-band and start vertices keep the source core opaque.
		# Interpolation is local to this one existing face, without another layer.
		for distance: float in [band,band*.5]:
			var split: PackedVector2Array=PackedVector2Array()
			for n in range(points.size()):
				var a: Vector2=points[n]
				var b: Vector2=points[(n+1)%points.size()]
				var da: float=_near_end_distance(weapon,near,a)-distance
				var db: float=_near_end_distance(weapon,near,b)-distance
				split.append(a)
				if (da<-.001 and db>.001) or (da>.001 and db<-.001):split.append(a.lerp(b,da/(da-db)))
			points=split
	var lower: Vector2=points[0]
	var upper: Vector2=points[0]
	for point: Vector2 in points:lower=lower.min(point);upper=upper.max(point)
	var colors: PackedColorArray=PackedColorArray()
	for point: Vector2 in points:
		var up: float=1.0-(point.y-lower.y)/maxf(1.0,upper.y-lower.y)
		var lateral: float=1.0-(point.x-lower.x)/maxf(1.0,upper.x-lower.x)
		var lit: Color=color.lerp(SILVER,up*.21+lateral*.10).lerp(INK,(1.0-up)*.22)
		var strength: float=_ease(clampf(_near_end_distance(weapon,near,point)/band,0.0,1.0)) if band>.001 else 1.0
		lit=lit.lerp(color.lerp(INK,.10),(1.0-strength)*.60)
		colors.append(Color(lit,clampf(alpha*strength,0,1)))
	return {"points":points,"colors":colors}

static func _near_blade_poly(canvas: CanvasItem,weapon: Dictionary,near: Dictionary,points: PackedVector2Array,color: Color,alpha: float) -> void:
	if alpha<=.002 or points.size()<3:return
	var paint: Dictionary=near_blade_paint(weapon,near,points,color,alpha)
	canvas.draw_polygon(paint.points,paint.colors)

static func _giant_blade(canvas: CanvasItem,weapon: Dictionary,layer: String,gilded: bool) -> void:
	var alpha:=float(weapon.visibility)
	if alpha<=.002 or float(weapon.growth)<=.002:return
	var root: Vector2=weapon.root
	var axis: Vector2=weapon.axis
	var side:=axis.orthogonal()
	var length:=maxf(.1,float(weapon.length)-float(weapon.root_distance))
	var width:=float(weapon.width)
	var top_lift:=0.0
	if layer=="back":
		# Broad single sapphire silhouette. The decorative far end is
		# less opaque than the original sword/reachable collision core.
		var face_alpha:=float(weapon.get("back_core_alpha",alpha*(.91 if weapon.decorative_extension else .97)))
		_weapon_poly(canvas,weapon,weapon.hull,INK,face_alpha,true)
		_weapon_poly(canvas,weapon,PackedVector2Array([root-side*width*.13,root+axis*length*.16-side*width*(.49+top_lift),root+axis*length*.78-side*width*(.35+top_lift*.5),root+axis*length*.94,root+axis*length*.81+side*width*.32,root+axis*length*.13+side*width*.34]),CORE,face_alpha*.99)
		_weapon_poly(canvas,weapon,PackedVector2Array([root,root+axis*length*.94,root+axis*length*.81+side*width*.32,root+axis*length*.13+side*width*.34]),STEEL,face_alpha*.87)
		# Alternating oblique crystal faces catch different light directions;
		# they form one blade surface instead of duplicated sword silhouettes.
		_weapon_poly(canvas,weapon,PackedVector2Array([root+axis*length*.13+side*width*.34,root+axis*length*.46+side*width*.08,root+axis*length*.57+side*width*.32]),CORE.darkened(.19),face_alpha*.78)
		_weapon_poly(canvas,weapon,PackedVector2Array([root+axis*length*.46+side*width*.08,root+axis*length*.77+side*width*.03,root+axis*length*.57+side*width*.32]),CYAN,face_alpha*.38,false,true)
		_weapon_poly(canvas,weapon,PackedVector2Array([root+axis*length*.57+side*width*.32,root+axis*length*.77+side*width*.03,root+axis*length*.91,root+axis*length*.81+side*width*.32]),STEEL.darkened(.22),face_alpha*.77)
		# The gold bevel is a thick metal facet with a bronze inner cut. The
		# blue body retains contrast instead of being filled with white glow.
		_weapon_poly(canvas,weapon,PackedVector2Array([root+axis*length*.15-side*width*(.55+top_lift),root+axis*length*.79-side*width*(.41+top_lift*.5),root+axis*length*.97,root+axis*length*.77-side*width*(.25+top_lift*.5),root+axis*length*.17-side*width*(.37+top_lift)]),GOLD,face_alpha*.99,false,true)
		_weapon_poly(canvas,weapon,PackedVector2Array([root+axis*length*.17-side*width*(.37+top_lift),root+axis*length*.77-side*width*(.25+top_lift*.5),root+axis*length*.91,root+axis*length*.76-side*width*(.20+top_lift*.5),root+axis*length*.18-side*width*(.30+top_lift)]),BRONZE,face_alpha*.78)
		_weapon_poly(canvas,weapon,PackedVector2Array([root+axis*length*.14,root+axis*length*.94,root+axis*length*.18+side*width*.085]),CYAN,face_alpha*.96,false,true)
		_weapon_poly(canvas,weapon,PackedVector2Array([root+axis*length*.13+side*width*.40,root+axis*length*.83+side*width*.37,root+axis*length*.95,root+axis*length*.82+side*width*.31,root+axis*length*.14+side*width*.33]),GOLD,face_alpha*.92,false,true)
		# Three original diamond channels are carved into the blue face.
		for n in range(3):
			var center:=root+axis*length*(.30+float(n)*.19)+side*width*.19
			var size:=width*(.086 if gilded else .065)
			_weapon_poly(canvas,weapon,PackedVector2Array([center-axis*size*1.15,center-side*size*.62,center+axis*size*1.15,center+side*size*.62]),INK,face_alpha)
			_weapon_poly(canvas,weapon,PackedVector2Array([center-axis*size*.76,center-side*size*.31,center+axis*size*.76,center+side*size*.31]),GOLD if gilded else CYAN,face_alpha*.97,false,true)
	elif layer=="front":
		# The near cover follows the old cel's exact axis. Its U terminal edge
		# ends on one oblique facet inside the existing cover, not a second tip.
		var near: Dictionary=near_blade_surface(weapon)
		# The U cel has a broad upper bevel above its anchor axis. Follow that
		# side of the near sword face so its old white short tip cannot poke out.
		var cover_alpha:=float(weapon.get("core_alpha",minf(1.0,alpha*1.23)))
		_near_blade_poly(canvas,weapon,near,near.face,CORE,cover_alpha)
		_near_blade_poly(canvas,weapon,near,near.steel,STEEL,cover_alpha*.97)
		# The old near cover concealed every rear crystal face during close SI
		# shots. Carve unequal, non-parallel facets into this same opaque face.
		# All vertices stay inside the existing near cover; no second tip appears.
		_near_blade_poly(canvas,weapon,near,near.shade_near,INK,cover_alpha*.91)
		_near_blade_poly(canvas,weapon,near,near.shade_far,CORE.darkened(.33),cover_alpha*.94)
		_near_blade_poly(canvas,weapon,near,near.ridge,CYAN,cover_alpha*.89)
		_near_blade_poly(canvas,weapon,near,near.reflection,SILVER,cover_alpha*.47)
		_near_blade_poly(canvas,weapon,near,near.gold,GOLD,cover_alpha*.98)

static func _poly(canvas: CanvasItem,points: PackedVector2Array,color: Color,alpha: float,outline: bool=false) -> void:
	if alpha<=.002 or points.size()<3:return
	var lower:=points[0];var upper:=points[0]
	for point: Vector2 in points:lower=lower.min(point);upper=upper.max(point)
	var colors:=PackedColorArray()
	for point: Vector2 in points:
		var up: float=1.0-(point.y-lower.y)/maxf(1.0,upper.y-lower.y)
		# Preserve the shaded blade faces; a common upper-left light catches
		# steel wakes and earth chips rather than making flat solid stickers.
		var lateral:=1.0-(point.x-lower.x)/maxf(1.0,upper.x-lower.x)
		var lit: Color=color.lerp(SILVER,up*.21+lateral*.10).lerp(INK,(1.0-up)*.22)
		colors.append(Color(lit,clampf(alpha,0,1)))
	canvas.draw_polygon(points,colors)
	if outline:
		var edge:=points.duplicate();edge.append(points[0]);canvas.draw_polyline(edge,Color(INK,alpha*.96),1.6,true)

static func _crescent_shape(center: Vector2,radius: Vector2,begin: float,end: float,width: float,rotation: float=0.0,offset: float=0.0) -> PackedVector2Array:
	var points:=PackedVector2Array()
	# Close-up / foreshortened sword cels have a shorter painted blade. Keep
	# the inner rim positive so a wide SI wake cannot fold through its center.
	var bounded_width: float=minf(width,maxf(.1,minf(radius.x,radius.y)*.90))
	# One simple curved surface. Rounded/tapered end faces remain distinct,
	# preventing duplicate endpoints or self-crossing ribbon triangulations.
	for pass_index in range(2):
		for index in range(19):
			var n:=index if pass_index==0 else 18-index
			var t:=float(n)/18.0;var angle:=lerpf(begin,end,t)
			var shape:=bounded_width*(.19+.81*pow(maxf(0,sin(t*PI)),.57))
			var radial:=offset+(shape*.50 if pass_index==0 else -shape*.50)
			points.append(center+Vector2(cos(angle)*(radius.x+radial),sin(angle)*(radius.y+radial)).rotated(rotation))
	return points

static func _steel_crescent(canvas: CanvasItem,center: Vector2,radius: Vector2,begin: float,end: float,width: float,rotation: float,alpha: float,gilded: bool=false) -> void:
	if alpha<=.002:return
	# The sword is solid, its moving wake is translucent energy. A bounded
	# indexed sheet keeps the outer sweep and bright crest while opening two
	# transparent breaks; the old four opaque bands read as a second blue board.
	var bounded:=minf(width,maxf(.1,minf(radius.x,radius.y)*.90))
	var points:=PackedVector2Array();points.resize(76)
	var colors:=PackedColorArray();colors.resize(76)
	var indices:=PackedInt32Array()
	var offsets: Array[float]=[.57,.31,-.05,-.50]
	var strengths: Array[float]=[.23,.95,.45,0.0]
	for n in range(19):
		var t:=float(n)/18.0;var angle:=lerpf(begin,end,t)
		var shape:=bounded*(.19+.81*pow(maxf(0,sin(t*PI)),.57))
		var fade:=pow(maxf(0,sin(t*PI)),.22)
		if n in [6,7,12,13]:fade*=.56
		var radial:=Vector2(cos(angle),sin(angle))
		for row in range(4):
			var push:=shape*offsets[row]
			points[n*4+row]=center+Vector2(radial.x*(radius.x+push),radial.y*(radius.y+push)).rotated(rotation)
			var color:=INK if row==0 else ((GOLD if gilded else SILVER) if row==1 else (STEEL if row==2 else CORE))
			colors[n*4+row]=Color(color,alpha*fade*strengths[row])
		if n==18 or n in [6,12]:continue
		for row in range(3):
			var a:=n*4+row;var b:=a+4
			indices.append_array(PackedInt32Array([a,b,b+1,a,b+1,a+1]))
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),indices,points,colors)

static func _blade_plane(canvas: CanvasItem,origin: Vector2,axis: Vector2,length: float,width: float,alpha: float,gilded: bool=false) -> void:
	var side:=axis.orthogonal()
	var points:=PackedVector2Array([origin-axis*length*.48-side*width*.12,origin-axis*length*.32-side*width*.55,origin+axis*length*.43-side*width*.43,origin+axis*length*.60,origin+axis*length*.31+side*width*.48,origin-axis*length*.33+side*width*.38])
	_poly(canvas,points,INK,alpha,true)
	var face:=PackedVector2Array([origin-axis*length*.38-side*width*.07,origin-axis*length*.23-side*width*.41,origin+axis*length*.39-side*width*.31,origin+axis*length*.53,origin+axis*length*.27+side*width*.30,origin-axis*length*.24+side*width*.24])
	_poly(canvas,face,STEEL,alpha*.96)
	_poly(canvas,PackedVector2Array([origin-axis*length*.31,origin+axis*length*.47,origin+axis*length*.27+side*width*.24,origin-axis*length*.23+side*width*.19]),SILVER,alpha*.83)
	_poly(canvas,PackedVector2Array([origin-axis*length*.23-side*width*.34,origin+axis*length*.39-side*width*.29,origin+axis*length*.47,origin+axis*length*.36-side*width*.19,origin-axis*length*.23-side*width*.23]),GOLD if gilded else CORE,alpha*.96)

static func _chip(canvas: CanvasItem,at: Vector2,axis: Vector2,radius: float,alpha: float,color: Color=STEEL) -> void:
	var side:=axis.orthogonal()
	_poly(canvas,PackedVector2Array([at-axis*radius*.6-side*radius*.46,at+axis*radius*.9-side*radius*.11,at+axis*radius*.32+side*radius*.43,at-axis*radius*.48+side*radius*.31]),color,alpha,true)
	_poly(canvas,PackedVector2Array([at-axis*radius*.49-side*radius*.30,at+axis*radius*.68-side*radius*.1,at-axis*radius*.25+side*radius*.07]),SILVER,alpha*.79)

static func _shavings(canvas: CanvasItem,at: Vector2,axis: Vector2,h: float,phase: float,alpha: float,count: int=4) -> void:
	for n in range(count):
		var angle: float=axis.angle()+(float(n)-float(count-1)*.5)*.58
		var direction:=Vector2(cos(angle),sin(angle));var reach:=h*(.22+phase*.47+float(n%2)*.13)
		_chip(canvas,at+direction*reach,direction,h*(.038+.012*(n%3))*(1-phase*.25),alpha*(.88-.07*n),GOLD if n%3==0 else STEEL)

static func _earth_shock(canvas: CanvasItem,at: Vector2,h: float,phase: float,alpha: float,large: bool=false) -> void:
	var span:=h*(1.10 if large else .66)*(.72+phase*.80)
	for n in range(6 if large else 4):
		var side:=float(n)-float(5 if large else 3)*.5
		var pos:=at+Vector2(side*span*.30,-h*(.035+.06*(n%2))-h*phase*(.12+.025*n))
		var direction:=Vector2(side*.38,-1).normalized()
		_chip(canvas,pos,direction,h*(.069+.018*(n%3)),alpha*.79,EARTH)
		var dust:=PackedVector2Array()
		for point in range(9):
			var angle:=TAU*float(point)/9.0
			dust.append(pos+Vector2(cos(angle)*h*.10,sin(angle)*h*.048)*(1+phase*.70))
		_poly(canvas,dust,EARTH,alpha*.27)
	# Ground fissures are flat ink/amber triangles; they cannot resemble sea foam.
	for side: int in [-1,1]:
		var a:=at+Vector2(side*span*.13,0)
		var b:=at+Vector2(side*span*.61,h*.035)
		var c:=at+Vector2(side*span,h*.011)
		_poly(canvas,PackedVector2Array([a,b+Vector2(0,h*.037),c,b-Vector2(0,h*.015)]),INK,alpha*.76)

static func _heavy_break(canvas: CanvasItem,at: Vector2,axis: Vector2,h: float,phase: float,alpha: float) -> void:
	# A confirmed tier-three collision fractures into large metal cut faces.
	# The open center and rear layer keep the actual victim's body readable.
	for n in range(7):
		var angle:=axis.angle()+(float(n)-3.0)*.74
		var direction:=Vector2(cos(angle),sin(angle));var flank:=direction.orthogonal()
		var near:=h*(.34+phase*.18);var far:=h*(1.28+.27*(n%3)+phase*.35)
		var base:=at+direction*near;var point:=at+direction*far
		var width:=h*(.16+.052*(n%2))*(1-phase*.36)
		_poly(canvas,PackedVector2Array([base-flank*width,point-flank*width*.14,point+direction*h*.08,base+flank*width*.80]),INK,alpha)
		_poly(canvas,PackedVector2Array([base-flank*width*.72,point,base+flank*width*.57]),STEEL,alpha*.94)
		_poly(canvas,PackedVector2Array([base-flank*width*.23,point+direction*h*.04,base+flank*width*.21]),GOLD if n%2==0 else SILVER,alpha*.96)

static func draw_actor(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:
	var g:=geometry(s)
	if not g.get("ready",false):return g
	g["frame_fx"]=FrameFX.draw_actor(canvas,s,layer)
	var giant:=amplification(s)
	g["amplification"]=giant
	var h:=float(s.get("height",90.0));var tier:=int(s.get("tier",1));var f:=float(s.get("facing",1))
	var slot:=str(s.get("slot","U"));var release: Dictionary=s.get("release_state",{})
	var grip: Vector2=g.grip;var tip: Vector2=g.tip;var blade: Vector2=g.axis;var phase:=float(g.phase)
	var length:=clampf(float(g.blade_length),h*.32,h*1.52)
	if layer=="front":
		_giant_blade(canvas,giant,layer,tier==3)
		# The leading glint is on the same extended blade, not a second sword.
		if g.active:
			var glint:=Vector2(giant.tip)-blade*h*.045
			_chip(canvas,glint,blade,h*(.048 if tier==1 else .061),.97,GOLD if tier==3 else SILVER)
		return g
	if layer!="back":return g
	if not g.active:
		_radiant_spell(canvas,giant)
		_giant_blade(canvas,giant,layer,tier==3)
		var prepare:=float(release.get("prepare",0))
		if prepare>0:
			var point:=grip.lerp(Vector2(giant.tip),.68+.21*prepare)
			_chip(canvas,point,blade,h*(.055+.054*prepare),.40+.48*prepare,GOLD if tier==3 else SILVER)
			if tier>=2 and prepare>.62:_shavings(canvas,Vector2(giant.tip),-blade,h*.49,1-prepare,.59*prepare,3)
		elif release.get("recovering",false):
			_shavings(canvas,Vector2(giant.tip),blade,h*.61,float(release.get("recovery_phase",1)),pow(1-float(release.get("recovery_phase",1)),1.5)*.65,2)
		return g
	var width:=h*(.218 if tier==1 else (.315 if tier==2 else .43))
	var wake_length:=lerpf(length,float(giant.length),.64)
	var radius:=Vector2(wake_length*.66+h*.09,wake_length*.50+h*.08)
	var rotation:=blade.angle()-f*.20
	var alpha:=.81*(1-.20*phase)
	var extended_tip: Vector2=giant.tip
	var center:=grip.lerp(extended_tip,.38)
	var cinema: Dictionary=s.get("cinema_phase",{})
	_radiant_spell(canvas,giant)
	match slot:
		"U":
			_steel_crescent(canvas,center,radius,-1.50+phase*.43,1.05+phase*.43,width,rotation,alpha)
			_shavings(canvas,extended_tip,blade,h*.77,phase,alpha*.68,3)
		"SU":
			_steel_crescent(canvas,center,Vector2(radius.x*1.15,radius.y*.45),-.85+phase*.35,1.55+phase*.35,width*1.03,rotation,alpha)
			if s.get("grounded",false):_earth_shock(canvas,Vector2(extended_tip.x,float(s.get("floor",tip.y))),h*1.05,phase,alpha*.71)
		"WU":
			_steel_crescent(canvas,center,Vector2(radius.x*.82,radius.y*1.25),-1.84+phase*.52,.86+phase*.52,width*1.08,rotation,alpha)
			_shavings(canvas,extended_tip,Vector2(f*.25,-1).normalized(),h*.90,phase,alpha*.73,4)
		"AIR_U":
			_steel_crescent(canvas,center,Vector2(radius.x*1.05,radius.y*.76),-.84+phase*.38,1.23+phase*.38,width*.86,rotation,alpha*.83)
			_shavings(canvas,extended_tip,Vector2(f*.35,1).normalized(),h*.73,phase,alpha*.68,3)
		"I":
			_steel_crescent(canvas,center,radius*1.13,-1.42+phase*.46,1.38+phase*.46,width,rotation,alpha,true)
			_shavings(canvas,extended_tip,blade,h*1.06,phase,alpha*.81,5)
		"WI":
			_steel_crescent(canvas,center,Vector2(radius.x*.95,radius.y*1.31),-1.8+phase*.70,1.02+phase*.70,width,rotation,alpha,true)
			_steel_crescent(canvas,center-blade*h*.07,radius*.72,1.74+phase*.45,3.32+phase*.45,width*.38,rotation,alpha*.71)
			_shavings(canvas,extended_tip,Vector2(f*.15,-1).normalized(),h*1.13,phase,alpha*.86,5)
		"SI":
			if cinema.get("stage","")=="rotation":
				var spin:=float(s.get("absolute_frame",0))*f*.23
				_steel_crescent(canvas,center,Vector2(wake_length*.69,wake_length*.48),spin,spin+2.49,width*1.12,0,alpha,true)
				_steel_crescent(canvas,center,Vector2(wake_length*.53,wake_length*.35),spin+PI,spin+PI+1.82,width*.45,0,alpha*.62)
			elif float(s.get("frame",0))>=226:
				# The single held giant blade supplies the heavy drop silhouette.
				# Only its broad open wake is added, never a detached second blade.
				_steel_crescent(canvas,center,Vector2(radius.x*.92,radius.y*1.24),-1.42+phase*.48,.80+phase*.48,width*.71,rotation,alpha*.69,true)
				_shavings(canvas,extended_tip,blade,h*1.42,phase,alpha*.88,7)
			else:
				_steel_crescent(canvas,center,radius*1.21,-1.69+phase*.75,1.12+phase*.75,width,rotation,alpha,true)
				_shavings(canvas,extended_tip,blade,h*1.26,phase,alpha*.79,5)
		"AIR_I":
			_steel_crescent(canvas,center,Vector2(radius.x*.82,radius.y*1.18),-1.29+phase*.57,.92+phase*.57,width*.76,rotation,alpha*.76)
			_shavings(canvas,extended_tip,blade,h*1.13,phase,alpha*.87,5)
	# Draw the bevelled face last on the rear layer so the steel structure
	# remains clear through its own sweeping wake.
	_giant_blade(canvas,giant,layer,tier==3)
	return g

static func draw_contact(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:
	if not s.get("ready",false) or str(s.get("id",""))!="rio":return {"ready":false}
	var at:=_v(s.get("pos"))
	if not at.is_finite():return {"ready":false}
	var h:=float(s.get("height",90.0));var p:=float(s.get("phase",0));var a:=float(s.get("alpha",1))
	var axis:=_v(s.get("attack_axis"))
	if not axis.is_finite() or axis.length_squared()<.01:axis=Vector2(float(s.get("direction",1)),-.25)
	axis=axis.normalized()
	var tier:=int(s.get("tier",1));var outcome:=str(s.get("outcome","hit"));var final:=bool(s.get("finisher",false)) and outcome in ["hit","guard_break"]
	var motif:=str(s.get("contact_motif","blade_entry"))
	var meta: Dictionary={"ready":true,"body_copies":0,"finisher":final,"contact_confirmed":outcome in ["hit","guard_break"],"motif":motif,"solid_motif":true,"ground_fracture":false,"source_clock_mutated":false}
	meta["frame_fx"]=FrameFX.draw_contact(canvas,s,layer)
	if outcome in ["guard","blocked"]:
		if layer=="front":
			_steel_crescent(canvas,at-axis*h*.04,Vector2(h*.12,h*.24),-.9,.9,h*.075,axis.angle(),a*.94)
			_shavings(canvas,at,-axis,h*.36,p,a*.81,3)
		return meta
	if outcome in ["armor","steel","counter","bullet_clash"]:
		if layer=="front":_blade_plane(canvas,at,axis,h*.29,h*.095,a);_shavings(canvas,at,axis,h*.37,p,a,3)
		return meta
	var reach:=h*(1.65 if final and tier==3 else (1.17 if final else (.61 if tier==1 else .78)))*(.80+p*.48)
	if layer=="back":
		# The confirmed collision owns this open gold/cyan halo; a cast alone
		# cannot release a contact nucleus or a finishing burst.
		var glow_radius:=Vector2(reach*.91,reach*.63)
		_poly(canvas,_crescent_shape(at,glow_radius,-1.30+p*.67,1.28+p*.67,h*(.10 if final else .064),axis.angle()),CYAN,a*.58)
		_poly(canvas,_crescent_shape(at,glow_radius,-1.30+p*.67,1.28+p*.67,h*(.031 if final else .021),axis.angle(),h*.026),GOLD,a*.91)
		if final and tier==3:_heavy_break(canvas,at,axis,h,p,clampf(a*1.35,0,.98))
		if motif=="blade_rotation":
			_steel_crescent(canvas,at,Vector2(reach*.92,reach*.63),-.37+p*.57,2.33+p*.57,h*(.31 if final else .19),axis.angle(),a*.92,final)
		elif motif=="blade_drop":
			var down:=Vector2(float(s.get("direction",1))*.18,1).normalized()
			# A deep, thick cut opens to either side of the true collision.
			# No detached blade crosses the victim and impersonates the weapon.
			_steel_crescent(canvas,at,Vector2(reach*.91,reach*.62),.15,2.67,h*(.27 if final else .15),down.angle(),a*.82,final)
			if final:
				for sign_value: int in [-1,1]:
					var side:=down.orthogonal()*float(sign_value)
					var near:=at+side*h*.29-down*h*.22
					var far:=at+side*reach*.93-down*reach*.49
					_poly(canvas,PackedVector2Array([near-down*h*.08,far-down*h*.14,far+side*h*.13,near+down*h*.09]),CORE,a*.87,true)
					_poly(canvas,PackedVector2Array([near,far,near+down*h*.055]),GOLD if tier==3 else SILVER,a*.94)
		else:
			var rotate:=axis.angle()-(.44 if motif=="blade_rise" else .04)
			_steel_crescent(canvas,at-axis*reach*.14,Vector2(reach,reach*.71),-1.36+p*.30,1.26+p*.30,h*(.35 if final and tier==3 else (.24 if final else .16)),rotate,a*.92,final)
		_shavings(canvas,at,axis,h*(1.55 if final and tier==3 else (1.08 if final else .67)),p,a*.91,7 if final and tier==3 else (5 if final else 3))
		return meta
	if layer!="front":return meta
	# The victim remains visible through the center after the true 45ms nucleus.
	if float(s.get("core_alpha",0))>.001:
		_chip(canvas,at,axis,h*(.105 if final else .067),float(s.get("core_alpha",0)),GOLD if final and tier==3 else SILVER)
	_shavings(canvas,at+axis*h*.10,axis,h*(1.04 if final else .62),p,a*.94,3 if final else 2)
	if final and bool(s.get("ground_splash",false)):
		_earth_shock(canvas,Vector2(at.x,float(s.get("floor_y",at.y))),h*(1.92 if tier==3 else 1.40),p,a,tier==3)
		meta.ground_fracture=true
	if outcome=="guard_break":_shavings(canvas,at,-axis,h*.73,p,a,4)
	return meta

static func draw_object(canvas: CanvasItem,s: Dictionary,layer: String) -> Dictionary:
	# The archived normal launcher remains owned by its real source child.
	if not s.get("ready",false) or str(s.get("id",""))!="rio":return {"ready":false}
	if s.get("normal_launcher",false) and layer=="back":
		load("res://game/bvn_skill_fx.gd")._draw_normal_launcher(canvas,s)
		return {"ready":true,"body_copies":0,"source_object":s.get("name",""),"normal_launcher_preserved":true}
	return {"ready":false,"body_copies":0,"source_object":s.get("name",""),"source_has_skill_projectile":false}
