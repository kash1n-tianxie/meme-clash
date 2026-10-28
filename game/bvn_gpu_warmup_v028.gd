extends SubViewport
## A real, tiny, offscreen render pass during arena preparation. No simulation,
## force_draw, screenshot readback, frame rate limit or combat clocks are used.
var textures: Array[Texture2D]=[]
var meshes: Array[ArrayMesh]=[]
var canvas: Node2D
var submitted_frames:=0

func add_texture(texture: Texture2D) -> void:
	if texture!=null and not textures.has(texture):
		textures.append(texture)
		if is_instance_valid(canvas):canvas.queue_redraw()

func _ready() -> void:
	size=Vector2i(32,32)
	disable_3d=true
	transparent_bg=true
	render_target_update_mode=SubViewport.UPDATE_ALWAYS
	canvas=Node2D.new()
	var material:=ShaderMaterial.new()
	material.shader=load("res://game/bvn_body_light.gdshader")
	canvas.material=material
	canvas.draw.connect(_submit_textures)
	add_child(canvas)
	RenderingServer.frame_post_draw.connect(_after_native_draw)
	canvas.queue_redraw()

func _submit_textures() -> void:
	# Retain mesh Resources while native draw commands hold their RIDs.
	# Eight columns give every atlas a real nonempty piece of this viewport.
	for index in range(textures.size()):
		var origin:=Vector2(float(index%8)*4.0,float(index/8)*4.0)
		if index>=meshes.size():
			var mesh:=ArrayMesh.new()
			var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(origin.x,origin.y,0),Vector3(origin.x+4,origin.y,0),Vector3(origin.x+4,origin.y+4,0),Vector3(origin.x,origin.y+4,0)])
			arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
			arrays[Mesh.ARRAY_COLOR]=PackedColorArray([Color.WHITE,Color.WHITE,Color.WHITE,Color.WHITE])
			arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			meshes.append(mesh)
		canvas.draw_mesh(meshes[index],textures[index])

func _after_native_draw() -> void:
	submitted_frames+=1
	if submitted_frames>=2:
		RenderingServer.frame_post_draw.disconnect(_after_native_draw)
		render_target_update_mode=SubViewport.UPDATE_DISABLED
		queue_free()
