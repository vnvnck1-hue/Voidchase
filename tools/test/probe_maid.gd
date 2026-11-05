extends SceneTree
## Headless probe for the maid rig: node counts, setup-pose placement of every part against
## layout.json, and a few samples of the idle animation.
##   godot --headless --path . -s res://tools/test/probe_maid.gd

const LAYOUT := "res://spine_parts_maid_v2/layout.json"


func _init() -> void:
	var inst: Node2D = load("res://scenes/characters/maid_rig.tscn").instantiate()
	root.add_child(inst)
	await process_frame
	var bones := inst.find_children("*", "Bone2D", true, false)
	var sprites := inst.find_children("*", "Sprite2D", true, false)
	var clips := inst.find_children("*", "Polygon2D", true, false)
	var ap: AnimationPlayer = inst.get_node("AnimationPlayer")
	print("bones %d  sprites %d  clips %d  animations %s" % [bones.size(), sprites.size(), clips.size(), ap.get_animation_list()])
	var failed := 0
	for s in sprites:
		if s.texture == null:
			print("  MISSING TEXTURE: ", s.name)
			failed += 1

	# setup pose: every part centre must land on its layout.json centre (origin = floor centre)
	var f := FileAccess.open(ProjectSettings.globalize_path(LAYOUT).replace("res://", ""), FileAccess.READ)
	if f == null:
		f = FileAccess.open(LAYOUT, FileAccess.READ)
	var layout: Dictionary = JSON.parse_string(f.get_as_text())
	var origin := Vector2(layout.canvas.width / 2.0, layout.canvas.height)
	ap.stop()
	ap.play("RESET")
	ap.advance(0.0)
	await process_frame
	var worst := 0.0
	for sp in layout.sprites:
		var node: Sprite2D = null
		for s in sprites:
			if s.name == sp.name:
				node = s
		if node == null:
			print("  MISSING PART: ", sp.name)
			failed += 1
			continue
		var expect := Vector2(sp.x + sp.width / 2.0, sp.y + sp.height / 2.0) - origin
		var got := node.global_position - inst.global_position
		var err := (got - expect).length()
		worst = maxf(worst, err)
		if err > 0.01:
			print("  OFFSET %s: got %s expected %s" % [sp.name, got, expect])
			failed += 1
		var z := node.z_index if node.get_parent() is Bone2D else (node.get_parent() as CanvasItem).z_index
		if z != int(sp.drawOrder) and int(sp.drawOrder) != 0:
			print("  Z %s: %d expected %d" % [sp.name, z, sp.drawOrder])
			failed += 1
	print("setup pose: worst part offset %.4f px" % worst)

	# idle samples
	var sk: Node2D = inst.get_node("Skeleton")
	var head: Bone2D = sk.get_node("pelvis/torso/neck/head")
	var tail: Bone2D = sk.get_node("pelvis/torso/neck/head/ponytail")
	var torso: Bone2D = sk.get_node("pelvis/torso")
	var eye: Bone2D = sk.get_node("pelvis/torso/neck/head/eye_l")
	var iris: Sprite2D = sk.get_node("pelvis/torso/neck/head/eye_l/clip_iris_l/iris_screen_left")
	var foot: Bone2D = sk.get_node("pelvis/thigh_l/shin_l/foot_l")
	var foot0 := foot.global_position
	var anim := ap.get_animation("idle")
	print("idle: length %.3f loop %d tracks %d" % [anim.length, anim.loop_mode, anim.get_track_count()])
	ap.play("idle")
	var min_eye := 1.0
	# 0.70 / 3.50 / 4.50 = shut frames of the three blinks; 2.6-3.3 = the look-left hold (iris x < setup 41.2)
	for t in [0.0, 0.63, 0.70, 1.27, 1.9, 2.6, 3.0, 3.3, 3.5, 3.6, 4.5, 5.0]:
		ap.seek(t, true)
		await process_frame
		min_eye = minf(min_eye, eye.scale.y)
		print("  t=%.2f torso %s rot %.2f deg | head rot %.2f | ponytail rot %.2f | eye_l scale.y %.2f | iris %s | foot drift %.3f" % [
			t, torso.position, rad_to_deg(torso.rotation), rad_to_deg(head.rotation), rad_to_deg(tail.rotation),
			eye.scale.y, iris.position, (foot.global_position - foot0).length()])
	print("blink reached scale.y %.2f" % min_eye)
	ap.play("rig_check")
	ap.seek(1.2, true)
	await process_frame
	print("rig_check: head %.1f ponytail %.1f forearm_r %.1f shin_l %.1f" % [rad_to_deg(head.rotation), rad_to_deg(tail.rotation),
		rad_to_deg((sk.get_node("pelvis/torso/upper_arm_r/forearm_r") as Node2D).rotation), rad_to_deg((sk.get_node("pelvis/thigh_l/shin_l") as Node2D).rotation)])
	print("RESULT: ", "OK" if failed == 0 else "FAILED (%d)" % failed)
	quit(0 if failed == 0 else 1)
