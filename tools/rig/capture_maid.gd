extends SceneTree
## Renders the maid rig off-screen (transparent SubViewport, canvas scale 1) for inspection:
##   docs/maid_rig/setup_render.png  RESET pose, 1325x1790, to diff against spine_parts_maid_v2/setup-pose.png
##   docs/maid_rig/rig_check.png     end pose of the rig_check animation
##   docs/maid_rig/idle/frame_NN.png idle loop sampled at IDLE_FPS (half size), for the preview sheet / gif
## Needs a window (the dummy renderer cannot draw); run on the sub monitor:
##   godot --path . --screen 1 --position 4380,80 --resolution 1280x720 -s res://tools/rig/capture_maid.gd

const OUT := "res://docs/maid_rig/"
const IDLE_FPS := 15.0
const IDLE_SCALE := 0.5


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "idle"))
	var rig: Node2D = load("res://scenes/characters/maid_rig.tscn").instantiate()
	var ap: AnimationPlayer = rig.get_node("AnimationPlayer")
	var vp := SubViewport.new()
	vp.size = Vector2i(1325, 1790)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cam := Camera2D.new()
	vp.add_child(cam)
	vp.add_child(rig)
	rig.position = Vector2.ZERO
	cam.position = Vector2(0, -895)  # canvas centre: origin is the floor centre of the 1325x1790 canvas
	await process_frame
	cam.make_current()

	ap.stop()
	ap.play("RESET")
	ap.advance(0.0)
	await _snap(vp, OUT + "setup_render.png")

	ap.play("rig_check")
	ap.seek(1.2, true)
	await _snap(vp, OUT + "rig_check.png")

	var anim := ap.get_animation("idle")
	var n := int(round(anim.length * IDLE_FPS))
	vp.size = Vector2i(int(1325 * IDLE_SCALE), int(1790 * IDLE_SCALE))
	cam.zoom = Vector2(IDLE_SCALE, IDLE_SCALE)
	ap.play("idle")
	for i in n:
		ap.seek(i / IDLE_FPS, true)
		await _snap(vp, OUT + "idle/frame_%02d.png" % i)
	print("[capture_maid] done: %d idle frames" % n)

	# face close-up at the animation's own frame rate (canvas 1:1): blink and gaze detail
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "face"))
	vp.size = Vector2i(560, 380)
	cam.zoom = Vector2.ONE
	cam.position = Vector2(470 - 662.5, 540 - 1790)  # canvas (470, 540): both eyes + brows + mouth
	var fps := 1.0 / anim.step
	var nf := int(round(anim.length * fps))
	for i in nf:
		ap.seek(i / fps, true)
		await _snap(vp, OUT + "face/frame_%03d.png" % i)
	print("[capture_maid] done: %d face frames @ %.0f fps" % [nf, fps])
	quit()


func _snap(vp: SubViewport, path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(path)
	print("[capture_maid] saved ", path, " ", img.get_size())
