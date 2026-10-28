extends SubViewport
## Prepare only the selected fighters' first cast-font paths during the intro.
## This viewport is never displayed and owns no actors or gameplay clocks.
const Bindings = preload("res://game/bvn_skill_bindings.gd")
const COMMANDS: Array[String] = ["super","super_up","super_down","air_super"]
var font_rows: Array[Dictionary] = []
var submitted_frames: int = 0
var canvas: Node2D

func prepare(ids: Array, font: Font) -> void:
	font_rows.clear()
	var selected: Array[String] = []
	if font==null:return
	for id: String in ids:
		if id in selected:continue
		selected.append(id)
		for command: String in COMMANDS:
			var text: String=str(Bindings.binding_for(id,command).get("name_ja",""))
			if not text.is_empty():font_rows.append({"text":text,"font":font,"size":25,"outline":3,"width":font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,25).x+6.0,"alignment":HORIZONTAL_ALIGNMENT_CENTER})
	if "worker" in selected:
		var worker: Script=load("res://game/fx_worker_v027.gd")
		font_rows.append({"text":"済","font":worker.STAMP_FONT,"size":3,"outline":1,"width":-1.0,"alignment":HORIZONTAL_ALIGNMENT_LEFT})
	# The present titles fit comfortably; measurement also contains a longer
	# localized binding without truncating its final glyphs during preparation.
	var width: float=32.0
	for row: Dictionary in font_rows:
		var row_font: Font=row.font
		width=maxf(width,maxf(float(row.width),row_font.get_string_size(row.text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(row.size)).x)+32.0)
	size=Vector2i(ceili(width),maxi(56,font_rows.size()*40+16))

func _ready() -> void:
	if font_rows.is_empty():queue_free();return
	disable_3d=true
	transparent_bg=true
	render_target_update_mode=SubViewport.UPDATE_ALWAYS
	canvas=Node2D.new()
	canvas.draw.connect(_submit_fonts)
	add_child(canvas)
	RenderingServer.frame_post_draw.connect(_after_native_draw)
	canvas.queue_redraw()

func _submit_fonts() -> void:
	for index: int in range(font_rows.size()):
		var row: Dictionary=font_rows[index]
		var row_font: Font=row.font
		var at: Vector2=Vector2(16,32+index*40)
		canvas.draw_string_outline(row_font,at,row.text,int(row.alignment),float(row.width),int(row.size),int(row.outline),Color(.05,.04,.09,.95))
		canvas.draw_string(row_font,at,row.text,int(row.alignment),float(row.width),int(row.size),Color.WHITE)

func _after_native_draw() -> void:
	if get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)<=0:return
	submitted_frames+=1
	if submitted_frames>=2:
		render_target_update_mode=SubViewport.UPDATE_DISABLED
		RenderingServer.frame_post_draw.disconnect(_after_native_draw)
		queue_free()

func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_after_native_draw):
		RenderingServer.frame_post_draw.disconnect(_after_native_draw)
