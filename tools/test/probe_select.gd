extends SceneTree
## Headless probe for the character select hit tests: godot --headless --path . -s res://tools/test/probe_select.gd

func _init() -> void:
	var inst: Node = load("res://scenes/Touch_Game_demo_anim.tscn").instantiate()
	root.add_child(inst)
	await process_frame
	await process_frame
	var cs: CharacterSelect = inst.get_node("BG_all/characters_list")
	var bg: Sprite2D = inst.get_node("BG_all/BG")
	print("bg offset ", bg.offset, " scale ", bg.global_scale, " arrowR centre ", bg.to_global(bg.offset + cs.arrow_right_px))
	print("background node: ", cs.get_node_or_null(cs.background))
	print("arrow_at R: ", cs.arrow_at(Vector2(253.5, -98.7)), "  arrow_at L: ", cs.arrow_at(Vector2(-259.4, -98.7)))
	print("panel_at: ", cs.panel_at(Vector2(-22.4, 244.5)), " ", cs.panel_at(Vector2(496.4, 194)), " ", cs.panel_at(Vector2(253.5, -98.7)))
	print("list pos ", cs.global_position)
	quit()
