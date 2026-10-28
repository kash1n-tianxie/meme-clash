extends RefCounted
## A shared, freshly illustrated pool arena in 1280-world coordinates.
## Scenery draws at native resolution beneath the transparent pixel-actor layer.

static var _texture: Texture2D
static var _sky: GradientTexture2D
static var _aerial_sky: Texture2D
static var _palette_material: ShaderMaterial
const AERIAL_SKY_PATH := "res://assets/art/visual_v27/sky_extension.png"
const AUTHORED_FLOOR_UV := 0.78

static func palette_material() -> ShaderMaterial:
	if _palette_material==null:
		_palette_material=ShaderMaterial.new()
		_palette_material.shader=load("res://assets/art/visual_v28/pool_palette.gdshader")
		var painted:=stage_texture()
		if painted:
			_palette_material.set_shader_parameter("painted_pixel_size",Vector2.ONE/painted.get_size())
	return _palette_material

static func stage_texture() -> Texture2D:
	if not _texture:
		var path := "res://assets/art/visual_v25/pool_stage.png"
		if not ResourceLoader.exists(path):path="res://assets/art/visual_v18/pool_stage.png"
		if not ResourceLoader.exists(path): path = "res://assets/pixel/stage_pool.png"
		if ResourceLoader.exists(path): _texture=load(path) as Texture2D
	return _texture

static func sky_texture() -> GradientTexture2D:
	if not _sky:
		var gradient:=Gradient.new()
		gradient.colors=PackedColorArray([Color("53baf0"),Color("bce8f8")])
		_sky=GradientTexture2D.new()
		_sky.gradient=gradient
		_sky.fill_from=Vector2(0.5,0)
		_sky.fill_to=Vector2(0.5,1)
	return _sky

static func aerial_sky_texture() -> Texture2D:
	if _aerial_sky==null and ResourceLoader.exists(AERIAL_SKY_PATH):_aerial_sky=load(AERIAL_SKY_PATH) as Texture2D
	return _aerial_sky

static func aerial_sky_layout(width: float,height: float,extension: float) -> Dictionary:
	var texture:=aerial_sky_texture()
	var size:=texture.get_size() if texture else Vector2(1536,1024)
	var scale:=maxf((width+4.0)/maxf(1,size.x),(height*1.12+4.0)/maxf(1,size.y))
	var displayed:=size*scale
	var margin:=displayed-Vector2(width,height)
	var parallax:=minf(maxf(0,extension)*.035,maxf(0,margin.y-2.0))
	return {"rect":Rect2(Vector2(-margin.x*.5,-parallax),displayed),"alpha":smoothstep(height*.25,height*.62,extension),"screen_coverage":Rect2(Vector2(-margin.x*.5,-parallax),displayed).encloses(Rect2(0,0,width,height)),"changes_source_camera":false,"contains_floor":false}

static func stage_layout(width: float, height: float, floor_y: float = NAN) -> Dictionary:
	var texture:=stage_texture()
	var source_size:=texture.get_size() if texture else Vector2(1280,720)
	var image_height:=width * source_size.y / maxf(1.0,source_size.x)
	var floor_line:=height-(1.0-AUTHORED_FLOOR_UV)*image_height if is_nan(floor_y) else floor_y
	var image_top:=floor_line-AUTHORED_FLOOR_UV*image_height
	return {"image_rect":Rect2(0,image_top,width,image_height),"source_size":source_size,"floor_y":floor_line,"floor_uv":AUTHORED_FLOOR_UV,"sky_extension":maxf(0.0,image_top)}

static func top_feather_alpha(fraction: float,extension: float,height: float) -> float:
	# Begin fading against the matching gradient before painted aerial clouds
	# appear. A partial aerial layer cannot leave an opaque plate-top rectangle.
	var feather:=smoothstep(0.0,maxf(1.0,height*.12),extension)
	return lerpf(1.0,smoothstep(0.0,1.0,clampf(fraction,0.0,1.0)),feather)

static func draw_stage(surface: Node2D, time: float, reduced: bool=false, height: float=720.0, width: float=1280.0, floor_y: float=NAN) -> void:
	# Color treatment is inside the original texture draw. The camera/floor,
	# cloud overscan and top-edge feather remain the same authored geometry.
	if surface.material!=palette_material():surface.material=palette_material()
	var layout:=stage_layout(width,height,floor_y)
	var sky_extension: float=layout.sky_extension
	var image_rect: Rect2=layout.image_rect
	var texture:=stage_texture()
	if texture:
		# Retain the painted aspect ratio even when the official map is wider
		# than the authored1280 canvas. The same painted floor UV stays aligned
		# to the live map floor; this is scenery only, with no collision role.
		if sky_extension>0:
			# Aerial source-camera moves can put the live floor thousands of pixels
			# below view. Extend sky, never stretch the plate's palm trees/buildings.
			surface.draw_texture_rect(sky_texture(),Rect2(0,0,width,sky_extension),false)
			var aerial:=aerial_sky_texture()
			if aerial!=null:
				var sky:=aerial_sky_layout(width,height,sky_extension)
				# Overscanned sky fills an aerial viewport with real painted cloud
				# depth. Only decoration has limited parallax; source camera,
				# actor positions, the pool floor and its registration stay exact.
				if sky.alpha>0:surface.draw_texture_rect(aerial,sky.rect,false,Color(1,1,1,sky.alpha))
		if sky_extension>0 and image_rect.position.y<height:
			# Feather only the original sky's upper edge into its painted aerial
			# continuation. The opaque floor and original registration stay exact.
			var source_size: Vector2=texture.get_size()
			var blend_height: float=minf(image_rect.size.y*.10,height*.12)
			var source_blend: float=blend_height*source_size.y/image_rect.size.y
			for band in range(24):
				var top: float=float(band)/24.0;var bottom: float=float(band+1)/24.0
				var alpha: float=top_feather_alpha((top+bottom)*.5,sky_extension,height)
				surface.draw_texture_rect_region(texture,Rect2(image_rect.position+Vector2(0,top*blend_height),Vector2(width,(bottom-top)*blend_height)),Rect2(0,top*source_blend,source_size.x,(bottom-top)*source_blend),Color(1,1,1,alpha))
			surface.draw_texture_rect_region(texture,Rect2(image_rect.position+Vector2(0,blend_height),Vector2(width,image_rect.size.y-blend_height)),Rect2(0,source_blend,source_size.x,source_size.y-source_blend))
		else:surface.draw_texture_rect(texture,image_rect,false)
	else:
		surface.draw_rect(Rect2(0,0,width,height),Color("fff8e8"))
	# The glints share the painting's uniform scale and anchor, so they do not
	# float off the water after the aspect correction.
	var art_scale:=image_rect.size.y/720.0
	surface.draw_set_transform(image_rect.position,0.0,Vector2.ONE*art_scale)
	var clock:=0.0 if reduced else time
	# Low-amplitude sea glints are deliberately separate from impact flashes.
	for index in range(8):
		var phase:=float(index)*2.399
		var brightness:=clampf(sin(clock*1.4+phase)*0.5+0.5,0.0,1.0)
		var x:=float((index*173+91)%int(width/art_scale))
		var y:=float(232+(index*29)%104)
		x=snappedf(x,4.0)
		y=snappedf(y,4.0)
		if brightness>0.76:
			surface.draw_rect(Rect2(x,y,8.0 if index%3==0 else 4.0,4),Color(0.96,1.0,0.94,(brightness-0.76)*0.20))
	# Tiny reflected glints stay outside the central feet and collision space.
	for side in [0.0,width/art_scale-152.0]:
		for index in range(7):
			var alpha:=(0.07+sin(clock*1.2+index*1.7)*0.025)
			surface.draw_rect(Rect2(side+index*16,404+index%3*12,8,4),Color(0.9,1.0,1.0,alpha))

	surface.draw_set_transform(Vector2.ZERO)

static func light_color() -> Color:
	return Color(1.0,0.98,0.91)
