extends SceneTree
## Renders the VoidDefenseVisualTest `Canvas` at 1:1 into a 1672x941 SubViewport, saves the PNG and
## compares it with docs/void_defense_original/reassembled.png (the pixel-exact PNG recomposition).
## Needs a window (headless cannot render); run on the sub monitor:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 -s res://tools/test/capture_vd_visual.gd
## Output: docs/void_defense_original/godot_capture.png and godot_diff.png (differences in red).

const SCENE := "res://scenes/void_defense/VoidDefenseVisualTest.tscn"
const REF := "res://docs/void_defense_original/reassembled.png"
const OUT := "res://docs/void_defense_original/godot_capture.png"
const DIFF := "res://docs/void_defense_original/godot_diff.png"
const SIZE := Vector2i(1672, 941)


func _init() -> void:
	var inst: Node2D = load(SCENE).instantiate()
	root.add_child(inst)
	await process_frame
	var canvas: Node2D = inst.get_node("Canvas")
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	canvas.get_parent().remove_child(canvas)
	vp.add_child(canvas)
	canvas.position = Vector2.ZERO
	canvas.scale = Vector2.ONE
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(OUT)
	print("[capture_vd_visual] saved ", OUT, " ", img.get_size())
	var ref := Image.load_from_file(ProjectSettings.globalize_path(REF))
	if ref == null or ref.get_size() != img.get_size():
		print("[capture_vd_visual] reference missing or size mismatch")
		quit(1)
		return
	ref.convert(Image.FORMAT_RGBA8)
	var diff := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var n_any := 0
	var n_big := 0
	var max_d := 0
	for y in SIZE.y:
		for x in SIZE.x:
			var a := img.get_pixel(x, y)
			var b := ref.get_pixel(x, y)
			var d := int(round(maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b)) * 255.0))
			if d > 0:
				n_any += 1
				max_d = maxi(max_d, d)
				if d > 8:
					n_big += 1
					diff.set_pixel(x, y, Color(1, 0, 0, 1))
				else:
					diff.set_pixel(x, y, Color(1, 1, 0, 0.6))
			else:
				diff.set_pixel(x, y, Color(b.r, b.g, b.b, 0.25))
	diff.save_png(DIFF)
	var total := SIZE.x * SIZE.y
	print("[capture_vd_visual] pixels differing: %d of %d (%.3f%%), >8/255: %d (%.3f%%), max channel diff %d" % [n_any, total, 100.0 * n_any / total, n_big, 100.0 * n_big / total, max_d])
	print("[capture_vd_visual] diff image ", DIFF)
	quit(0)
