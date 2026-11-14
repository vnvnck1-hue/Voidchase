## 앞 안개 '하프톤' 스타일 캡처: 공허·사막 테마에서 기체/하프톤 앞 안개를 같은 방에서 찍어 docs/fog_halftone/ 에 저장한다.
## 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/HalftoneFogCapture.tscn
##   <테마>_<스타일>.png : 전체 화면 · crop_<테마>_halftone.png : 왼쪽 아래 가장자리 3배 확대 · tuner_halftone.png : 조정 패널(F10)+설정 메뉴
## 헤드리스로 돌리면 그림 없이 스타일 전환·저장·복원과 패널 슬라이더 표시만 확인한다.
extends Node

const OUT := "res://docs/fog_halftone/"
const CONFIG := OUT + "test_settings/"
const CROP := Rect2i(0, 420, 400, 225)   # 1280x720 기준: 왼쪽 아래 안개 가장자리
var failures: Array[String] = []


func _check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)
	print("[halftone] %s %s" % ["PASS" if ok else "FAIL", description])


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONFIG))
	for file_name in ["world.cfg", "vd_nebula.cfg", "vd_desert.cfg"]:
		ConfigFile.new().save(CONFIG + file_name)
	VDWorldTheme.config_path = CONFIG + "world.cfg"
	VDWorldTheme._loaded = false
	VDWorldTheme.load_selected()
	call_deferred("_run")


func _new_battle() -> VDBattle:
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	b.nebula_tuner.config_directory = CONFIG
	b.set_background_theme(b.background_theme, false)
	return b


func _shot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + name + ".png")
	return img


func _run() -> void:
	var headless := DisplayServer.get_name() == "headless"
	var b := _new_battle()
	while b.enemies.is_empty():
		await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	_check(VDWorldTheme.fog_style == VDWorldTheme.FogStyle.GAS, "default style is gas")
	var tuner := b.nebula_tuner
	# 두 테마 x 두 스타일
	for theme in [VDWorldTheme.Kind.VOID, VDWorldTheme.Kind.DESERT]:
		b.set_background_theme(theme, false)
		var tag := VDWorldTheme.profile(theme)
		b.set_fog_style(VDWorldTheme.FogStyle.GAS, false)
		_check(b._fog_material.shader == VDWorldTheme.VOID_FOG if theme == VDWorldTheme.Kind.VOID else b._fog_material.shader == VDWorldTheme.DESERT_FOG, "%s gas uses theme fog shader" % tag)
		if not headless:
			await _shot("%s_gas" % tag)
		b.set_fog_style(VDWorldTheme.FogStyle.HALFTONE, false)
		_check(b._fog_material.shader == VDWorldTheme.HALFTONE_FOG, "%s halftone uses halftone shader" % tag)
		_check(tuner._fog_sliders["ht_size"].visible and not tuner._fog_sliders["wisp_scale"].visible, "%s halftone panel shows ht sliders only" % tag)
		if not headless:
			var img := await _shot("%s_halftone" % tag)
			var crop := img.get_region(CROP)
			crop.resize(CROP.size.x * 3, CROP.size.y * 3, Image.INTERPOLATE_NEAREST)
			crop.save_png(OUT + "crop_%s_halftone.png" % tag)
	# 슬라이더 값은 스타일별로 따로 저장되고 스타일 전환 뒤에도 남는다
	tuner._on_fog(22.0, "ht_size")
	b.set_fog_style(VDWorldTheme.FogStyle.GAS, false)
	_check(tuner._fog_sliders["wisp_scale"].visible and not tuner._fog_sliders["ht_size"].visible, "gas panel shows gas sliders only")
	b.set_fog_style(VDWorldTheme.FogStyle.HALFTONE, true)
	_check(is_equal_approx(float(tuner._fogv["ht_size"]), 22.0), "halftone slider value survives style round trip")
	# 저장·복원
	VDWorldTheme._loaded = false
	VDWorldTheme.load_selected()
	_check(VDWorldTheme.fog_style == VDWorldTheme.FogStyle.HALFTONE, "fog style reloads from config")
	# 설정 메뉴 항목
	SceneSwitcher.set_menu_open(true)
	var option := SceneSwitcher._menu_box.find_child("FogStyle", true, false) as OptionButton
	_check(option != null and option.item_count == 2 and option.get_item_text(1) == "하프톤", "settings menu has fog style choice")
	if option:
		option.emit_signal("item_selected", VDWorldTheme.FogStyle.GAS)
		_check(VDWorldTheme.fog_style == VDWorldTheme.FogStyle.GAS and b._fog_material.shader != VDWorldTheme.HALFTONE_FOG, "settings menu switches style")
		option.emit_signal("item_selected", VDWorldTheme.FogStyle.HALFTONE)
	if not headless:
		tuner.toggle()
		await _shot("tuner_halftone")
		tuner.toggle()
	SceneSwitcher.set_menu_open(false)
	tuner._reset_values()
	tuner._sync_controls()
	tuner._apply()
	print("[halftone] values: ", tuner.values_text())
	print("[halftone] DONE failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
