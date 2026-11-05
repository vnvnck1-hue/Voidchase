extends SceneTree
## Renders the rigged Olivia avatar alone (transparent background) to a PNG for the portrait panel.
##   godot --path . --screen 1 --position 4380,80 --resolution 1280x720 -s res://tools/expand/capture_olivia.gd

const OUT := "res://assets/textures/standing/olivia_render.png"

func _init() -> void:
	var inst: Node = load("res://scenes/Touch_Game_demo_anim.tscn").instantiate()
	root.add_child(inst)
	await process_frame
	for p in ["BG_all/EntrancePlayer", "BG_all/ListPlayer", "BG_all/AnimationPlayer"]:
		var ap := inst.get_node_or_null(p) as AnimationPlayer
		if ap:
			ap.stop()
	var avatar: Node2D = inst.get_node("BG_all/avatar")
	var vp := SubViewport.new()
	vp.size = Vector2i(1800, 2200)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cam := Camera2D.new()
	vp.add_child(cam)
	avatar.get_parent().remove_child(avatar)
	vp.add_child(avatar)
	avatar.visible = true
	avatar.process_mode = Node.PROCESS_MODE_INHERIT
	avatar.position = Vector2.ZERO
	avatar.scale = Vector2.ONE
	var shadow := avatar.get_node_or_null("Shadow")
	if shadow:
		shadow.visible = false
	cam.position = Vector2(0, -900)
	cam.make_current()
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(OUT)
	print("[capture_olivia] saved ", OUT, " ", img.get_size())
	quit()
