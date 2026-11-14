## 테마 드롭다운·프로필/선택 저장·전투 중 전환·공허 렌더 회귀·모래 움직임을 실제 렌더러에서 확인한다.
extends Node

const OUT := "res://docs/world_themes/"
const CONFIG := OUT + "test_settings/"
var battle: VDBattle
var failures: Array[String] = []
var results := {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CONFIG)
	for file_name in ["world.cfg", "vd_nebula.cfg", "vd_desert.cfg", "vd_bio.cfg"]:
		ConfigFile.new().save(CONFIG + file_name)
	VDWorldTheme.config_path = CONFIG + "world.cfg"
	VDWorldTheme.select(VDWorldTheme.Kind.DESERT, false)
	call_deferred("_run")


func _check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)
	print("[theme] %s %s" % ["PASS" if ok else "FAIL", description])


func _new_battle() -> VDBattle:
	var next: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(next)
	next.nebula_tuner.config_directory = CONFIG
	next.set_background_theme(next.background_theme, false)
	return next


func _shot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	frame.save_png(OUT + name + ".png")
	return frame


func _run() -> void:
	battle = _new_battle()
	await get_tree().create_timer(2.0).timeout
	_check(battle.background_theme == VDWorldTheme.Kind.DESERT, "default desert palette + tile package")
	_check(battle.board.theme_id == VDWorldTheme.Kind.DESERT and not battle.props.back.visible and not battle.props.front.visible, "desert hides floating void ruins")
	var map_before := battle.map
	var room_before: Dictionary = battle.room.duplicate(true)
	var hero_cells: Array = battle.allies.map(func(unit: VDUnit) -> Vector2i: return unit.cell)
	var state_before := battle.state
	SceneSwitcher.set_menu_open(true)
	var option := SceneSwitcher._menu_box.find_child("BackgroundTheme", true, false) as OptionButton
	_check(option != null and option.item_count == 3 and option.get_item_text(0) == "공허" and option.get_item_text(1) == "사막" and option.get_item_text(2) == "바이오 연구실", "settings contains the three named theme choices")
	await _shot("desert_settings")
	option.emit_signal("item_selected", VDWorldTheme.Kind.VOID)
	_check(battle.background_theme == VDWorldTheme.Kind.VOID and battle.board.theme_id == VDWorldTheme.Kind.VOID, "real dropdown applies void tiles")
	_check(battle._background_material.shader == VDWorldTheme.VOID_BG and battle._fog_material.shader == VDWorldTheme.VOID_FOG, "void switches both shader layers")
	_check(battle.props.back.visible and battle.props.front.visible, "void restores original props")
	_check(battle.map == map_before and battle.room == room_before and battle.state == state_before
		and battle.allies.map(func(unit: VDUnit) -> Vector2i: return unit.cell) == hero_cells, "theme choice preserves room, state and units")
	await _shot("void_settings")
	SceneSwitcher.set_menu_open(false)
	# Tweaks must survive round trips without leaking between theme profiles.
	battle.nebula_tuner._on_speed(0.023)
	battle.nebula_tuner._on_fog(0.22, "strength")
	battle.set_background_theme(VDWorldTheme.Kind.DESERT, false)
	battle.nebula_tuner._on_speed(0.063)
	battle.nebula_tuner._on_fog(0.37, "strength")
	battle.set_background_theme(VDWorldTheme.Kind.VOID, false)
	_check(is_equal_approx(battle.nebula_tuner._speed, 0.023) and is_equal_approx(battle.nebula_tuner._fogv["strength"], 0.22), "void adjustments kept independently")
	battle.set_background_theme(VDWorldTheme.Kind.DESERT, false)
	_check(is_equal_approx(battle.nebula_tuner._speed, 0.063) and is_equal_approx(battle.nebula_tuner._fogv["strength"], 0.37), "desert adjustments kept independently")
	battle.set_background_theme(VDWorldTheme.Kind.BIO, false)
	battle.nebula_tuner._on_speed(0.041)
	battle.nebula_tuner._on_fog(0.19, "strength")
	_check(battle.nebula_tuner._config_path.ends_with("vd_bio.cfg"), "bio uses an independent background profile")
	battle.set_background_theme(VDWorldTheme.Kind.VOID, false)
	_check(is_equal_approx(battle.nebula_tuner._speed, 0.023), "switch from bio preserves void adjustments")
	battle.set_background_theme(VDWorldTheme.Kind.BIO, false)
	_check(is_equal_approx(battle.nebula_tuner._speed, 0.041) and is_equal_approx(battle.nebula_tuner._fogv["strength"], 0.19), "bio adjustments kept independently")
	_check(battle.board.theme_id == VDWorldTheme.Kind.BIO and not battle.props.back.visible and not battle.props.front.visible, "bio selects its runtime terrain and hides floating ruins")
	_check(battle.bio_props.visible and battle.bio_props.room_count(battle.room["id"]) == 3, "bio displays all three fixed lab props")
	battle.set_background_theme(VDWorldTheme.Kind.DESERT, false)
	_check(not battle.bio_props.visible, "desert hides lab props")
	battle.set_background_theme(999, false)
	_check(battle.background_theme == VDWorldTheme.Kind.DESERT, "invalid choices cannot break current theme")
	# Defaults for visual QA, without overwriting the profile round-trip evidence.
	battle.nebula_tuner._reset_values()
	battle.nebula_tuner._sync_controls()
	battle.nebula_tuner._apply()
	await _shot("desert_placement")
	# Fixed camera + phases: only the sand background changes in the empty top-left crop.
	battle.camera.set_process(false)
	battle.nebula_tuner.set_process(false)
	battle._background_material.set_shader_parameter("phase", 1.0)
	battle._fog_material.set_shader_parameter("wisp_phase", 1.0)
	var frame_a := await _shot("desert_wind_a")
	battle._background_material.set_shader_parameter("phase", 1.8)
	battle._fog_material.set_shader_parameter("wisp_phase", 1.8)
	var frame_b := await _shot("desert_wind_b")
	var wind_changed := 0
	for y in range(160, 260):
		for x in range(20, 180):
			if frame_a.get_pixel(x, y) != frame_b.get_pixel(x, y):
				wind_changed += 1
	_check(wind_changed > 500, "sand and dust visibly move: %d background pixels" % wind_changed)
	results["wind_changed_background_pixels"] = wind_changed
	battle.camera.set_process(true)
	battle.nebula_tuner.set_process(true)
	battle.start_battle()
	var wait_sec := 0.0
	while battle.state != VDBattle.State.BATTLE and wait_sec < 8.0:
		await get_tree().create_timer(0.1).timeout
		wait_sec += 0.1
	_check(battle.state == VDBattle.State.BATTLE, "combat starts with desert theme")
	battle.set_background_theme(VDWorldTheme.Kind.VOID, false)
	_check(battle.state == VDBattle.State.BATTLE and battle.map == map_before, "switch to void during active combat without reset")
	await _shot("void_battle")
	battle.set_background_theme(VDWorldTheme.Kind.DESERT, false)
	await _shot("desert_battle")
	# Verify board animation data is not cleared by a theme switch.
	var cells: Array = battle.map.tiles.keys().slice(0, 3)
	battle.board.raise_tiles(cells, cells[0])
	var rise_before := battle.board._rise.duplicate()
	battle.set_background_theme(VDWorldTheme.Kind.VOID, true)
	_check(battle.board._rise == rise_before, "switch preserves tile-rise animation")
	VDWorldTheme._loaded = false
	_check(VDWorldTheme.load_selected() == VDWorldTheme.Kind.VOID, "last choice reloads from config")
	battle.queue_free()
	await get_tree().process_frame
	battle = _new_battle()
	_check(battle.background_theme == VDWorldTheme.Kind.VOID and battle.board.theme_id == VDWorldTheme.Kind.VOID, "new battle restores saved theme")
	battle.queue_free()
	await get_tree().process_frame
	await _compare_legacy_void()
	results["failures"] = failures
	var report := FileAccess.open(OUT + "theme_test.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(results, "\t"))
	report.close()
	print("[theme] DONE failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _compare_legacy_void() -> void:
	var test_map := VDMap.new()
	for x in 3:
		for y in 3:
			if Vector2i(x, y) != Vector2i(2, 2):
				test_map.tiles[Vector2i(x, y)] = {"kind": "room", "room": 0}
	var views: Array[SubViewport] = []
	for legacy in [true, false]:
		var view := SubViewport.new()
		view.size = Vector2i(768, 512)
		view.transparent_bg = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(view)
		var node: Node2D
		if legacy:
			node = load(OUT + "reference_void_board.gd").new()
		else:
			node = VDBoard.new()
			node.set_theme(VDWorldTheme.Kind.VOID)
		node.map = test_map
		node.position = Vector2(384, 120)
		view.add_child(node)
		views.append(view)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var before := views[0].get_texture().get_image()
	var after := views[1].get_texture().get_image()
	before.save_png(OUT + "void_legacy_board.png")
	after.save_png(OUT + "void_theme_board.png")
	var difference := 0
	for y in before.get_height():
		for x in before.get_width():
			if before.get_pixel(x, y) != after.get_pixel(x, y):
				difference += 1
	results["void_legacy_board_different_pixels"] = difference
	_check(difference == 0, "void board matches pre-desert renderer: %d different pixels" % difference)
	for view in views:
		view.queue_free()
