extends SceneTree
## Headless probe for the standing art: per-panel texture, scale, drawn size and drop shadow.
## godot --headless --path . -s res://tools/test/probe_standing.gd

func _init() -> void:
	var inst: Node = load("res://scenes/Touch_Game_demo_anim.tscn").instantiate()
	root.add_child(inst)
	await process_frame
	await process_frame
	var sc: StandingCharacter = inst.get_node("BG_all/stand_character")
	var sprite: Sprite2D = sc.get_node("Sprite")
	var drop: Sprite2D = sc.get_node("DropShadow")
	print("children of stand_character: ", sc.get_children().map(func(n): return n.name))
	for i in sc.textures.size():
		sc.show_character(i)
		await process_frame
		var tex := sprite.texture
		if tex == null:
			print("panel %d: no texture (drop visible=%s)" % [i, drop.visible])
			continue
		var s := sprite.scale
		var fw := tex.get_width() / sprite.hframes
		var fh := tex.get_height() / sprite.vframes
		print("panel %d: %s frame %dx%d scale=%.3f drawn=%.0fx%.0f px | drop: visible=%s frame=%d pos=%s modulate=%s" % [i, tex.resource_path.get_file(), fw, fh, s.y, fw * s.x, fh * s.y, drop.visible, drop.frame, drop.position, drop.modulate])
	# rigged character: the rig copy
	sc.show_character(sc.rigged_index)
	await process_frame
	await process_frame
	var bg: Node = inst.get_node("BG_all")
	var av: Node2D = inst.get_node("BG_all/avatar")
	var grp: CanvasGroup = bg.get_node_or_null("avatarDropShadow")
	if grp == null:
		print("rig shadow: MISSING")
	else:
		print("rig shadow: index %d (avatar index %d) visible=%s self_modulate=%s pos=%s scale=%s" % [grp.get_index(), av.get_index(), grp.visible, grp.self_modulate, grp.position, grp.scale])
		var copy: Node2D = grp.get_node("RigCopy")
		var orig_cnt := av.find_children("*", "", true, false).size()
		var copy_cnt := copy.find_children("*", "", true, false).size()
		print("rig shadow: original %d nodes, copy %d nodes, anim players in copy %d, scripts in copy %d" % [orig_cnt, copy_cnt, copy.find_children("*", "AnimationPlayer", true, false).size(), copy.find_children("*", "", true, false).filter(func(n): return n.get_script() != null).size()])
		var ob: Bone2D = av.find_children("*", "Bone2D", true, false)[5]
		var cb: Bone2D = copy.get_node(av.get_path_to(ob))
		print("bone sample %s: orig %s copy %s" % [ob.name, ob.transform.origin, cb.transform.origin])
		var op: Polygon2D = av.get_node("body")
		var cp: Polygon2D = copy.get_node("body")
		print("body polygon: skeleton path copy=%s resolves=%s z=%d/%s" % [cp.skeleton, cp.get_node_or_null(cp.skeleton) != null, cp.z_index, cp.z_as_relative])
	# per-panel rig scenes (RIGS in apply_standing.py), e.g. the maid rig: shown instead of the still image
	var failed := 0
	for i in sc.rigs.size():
		if sc.rigs[i].is_empty():
			continue
		sc.show_character(i)
		await process_frame
		await process_frame
		var rig: Node2D = sc.get_node(sc.rigs[i])
		var rshadow: CanvasGroup = sc.get_node_or_null("%sDropShadow" % rig.name)
		var rap: AnimationPlayer = rig.get_node_or_null("AnimationPlayer")
		var ok := rig.visible and rig.process_mode == Node.PROCESS_MODE_INHERIT and not av.visible and not sprite.visible and rshadow != null and rshadow.visible and rshadow.get_index() == rig.get_index() - 1
		print("panel %d: rig %s visible=%s process=%d scale=%s anim=%s | olivia visible=%s | still sprite visible=%s | shadow %s idx %d (rig idx %d) | %s" % [
			i, rig.name, rig.visible, rig.process_mode, rig.scale, rap.current_animation if rap else "-", av.visible, sprite.visible,
			"ok" if rshadow else "MISSING", rshadow.get_index() if rshadow else -1, rig.get_index(), "OK" if ok else "FAILED"])
		if not ok:
			failed += 1
		# switching back to Olivia must hide the rig and its shadow
		sc.show_character(sc.rigged_index)
		await process_frame
		var back := av.visible and not rig.visible and rig.process_mode == Node.PROCESS_MODE_DISABLED and (rshadow == null or not rshadow.visible) and grp != null and grp.visible
		print("  back to Olivia: rig hidden=%s olivia visible=%s | %s" % [not rig.visible, av.visible, "OK" if back else "FAILED"])
		if not back:
			failed += 1
	print("RESULT: ", "OK" if failed == 0 else "FAILED (%d)" % failed)
	quit(0 if failed == 0 else 1)
