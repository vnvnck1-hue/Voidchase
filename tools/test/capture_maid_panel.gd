extends SceneTree
## Runs the character showcase scene, selects the maid's panel and screenshots the window a few times
## (entrance, then the rig idle), then switches to Olivia's panel for one more shot. Needs a window:
##   godot --path . --screen 1 --position 4380,80 --resolution 1280x720 -s res://tools/test/capture_maid_panel.gd
## Shots go to docs/maid_rig/panel_shots/.

const OUT := "res://docs/maid_rig/panel_shots/"
const MAID_PANEL := 5   # RIGS key in tools/expand/apply_standing.py
const OLIVIA_PANEL := 7


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var inst: Node = load("res://scenes/Touch_Game_demo_anim.tscn").instantiate()
	root.add_child(inst)
	await create_timer(1.0).timeout
	var list: Node = inst.get_node("BG_all/characters_list")
	list.select(MAID_PANEL)
	var prev := 0.0
	for d in [0.4, 1.5, 3.5, 6.0]:
		await create_timer(d - prev).timeout
		prev = d
		await _snap("maid_%.1fs.png" % d)
	list.select(OLIVIA_PANEL)
	await create_timer(3.0).timeout
	await _snap("olivia_after_switch.png")
	list.select(MAID_PANEL)
	await create_timer(3.0).timeout
	await _snap("maid_after_switch_back.png")
	quit()


func _snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(OUT + name)
	print("[capture_maid_panel] saved ", OUT + name, " ", img.get_size())
