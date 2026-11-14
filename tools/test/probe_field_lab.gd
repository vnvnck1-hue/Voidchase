## 필드 연구실 자동 테스트 (2026-11-11).
##   1) 로비 목록(SceneSwitcher.SCENES)에 필드 연구실이 있다
##   2) 연구실 씬을 열면 전투(연습장)가 뜨고 패널이 만들어진다
##   3) 테마(공허·사막)마다 요소 6종의 색조·채도·명도·대비·불투명도·덧색이 해당 재질(fl_* uniform)에 들어간다
##      · "전체"는 나머지에 곱해진다 · 타일의 구역 색 띠 세기는 VDBoard.zone_k 로 간다
##   4) 원본 보기(C)는 보정을 끄고, 끄면 되돌아온다 · 초기화는 기본값으로 · 저장 → 다시 읽기가 값을 지킨다
##   5) 창이 있으면: 화면이 실제로 바뀌는지(명도를 낮추면 어두워지고, 채도를 0 으로 하면 무채색) 픽셀로 확인하고 장면을 저장한다
## 사용자 저장값은 건드리지 않는다 (임시 설정 파일을 쓰고 지운다).
##   godot --headless --path . res://tools/test/FieldLabProbe.tscn
##   godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/FieldLabProbe.tscn -- --out=res://docs/field_lab
extends Node

const FieldLook := preload("res://scripts/void_defense/vd_field_look.gd")
const TEST_CFG := "user://vd_field_look_test.cfg"
const TEST_THEME_CFG := "user://vd_world_theme_test.cfg"

var out_dir := ""
var _lab: Node
var _b: VDBattle
var _fails: Array[String] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	FieldLook.config_path = TEST_CFG
	VDWorldTheme.config_path = TEST_THEME_CFG
	_remove(TEST_CFG)
	_remove(TEST_THEME_CFG)
	FieldLook.clear_memory()
	var names := SceneSwitcher.SCENES.map(func(s: Dictionary) -> String: return s["name"])
	_check(names.has("FieldLab"), "lobby list has FieldLab")
	var entry: Dictionary = SceneSwitcher.SCENES[names.find("FieldLab")]
	_check(ResourceLoader.exists(entry["path"]), "scene file exists")
	_start.call_deferred(entry["path"])


func _start(path: String) -> void:
	if out_dir != "" and not _headless():
		# 로비 카드가 겹치지 않고 다 보이는지 (카드가 6장으로 늘었다)
		var lobby: Node = (load("res://scenes/Lobby.tscn") as PackedScene).instantiate()
		add_child(lobby)
		await _wait(7.0)
		await _shot("lobby")
		lobby.queue_free()
		await get_tree().process_frame
	_lab = (load(path) as PackedScene).instantiate()
	add_child(_lab)
	_run.call_deferred()


func _run() -> void:
	_b = _lab.battle
	_check(_b != null and _b.sandbox != null, "battle opened in sandbox mode")
	_check(_lab._panel != null and _lab._tabs.size() == FieldLook.GROUPS.size(), "panel with %d element tabs" % _lab._tabs.size())
	var t0 := Time.get_ticks_msec()
	while _b.state != VDBattle.State.BATTLE and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
	_check(_b.state == VDBattle.State.BATTLE, "sandbox battle running")
	await _wait(1.0)

	for theme in [VDWorldTheme.Kind.VOID, VDWorldTheme.Kind.DESERT]:
		_lab.set_theme(theme)
		var tname: String = VDWorldTheme.profile(theme)
		_check(_lab._profile == tname, "%s: profile follows theme" % tname)
		_lab.reset_all()
		await _wait(0.4)
		_check(_mats_default(), "%s: defaults leave every material untouched" % tname)
		var base := await _grab()
		await _shot("%s_01_original" % tname)

		# 요소마다 값을 넣고 재질을 확인
		var mats := _mats()
		var i := 0
		for g: String in mats:
			i += 1
			_lab.select_group(g)
			_check(_lab._sliders.has("hue") and _lab._sliders.has("sat") and _lab._sliders.has("val"), "%s/%s: hue·sat·val sliders" % [tname, g])
			var hue := 30.0 * i
			var sat := 0.2 + 0.1 * i
			var val := 0.5 + 0.05 * i
			_lab._sliders["hue"].value = hue      # 슬라이더를 직접 움직인다 (UI 경로)
			_lab._sliders["sat"].value = sat
			_lab.set_value(g, "val", val)
			_lab.set_value(g, "contrast", 1.2)
			_lab.set_value(g, "alpha", 0.9)
			_lab.set_value(g, "tint", Color(0.2, 0.4, 0.6))
			_lab.set_value(g, "tint_amount", 0.25)
			var m: ShaderMaterial = mats[g]
			var tint: Color = m.get_shader_parameter("fl_tint")
			var ok := _eq(m.get_shader_parameter("fl_hue"), hue / 360.0) and _eq(m.get_shader_parameter("fl_sat"), sat) \
				and _eq(m.get_shader_parameter("fl_val"), val) and _eq(m.get_shader_parameter("fl_contrast"), 1.2) \
				and _eq(m.get_shader_parameter("fl_alpha"), 0.9) and _eq(tint.a, 0.25) and _eq(tint.b, 0.6)
			_check(ok, "%s/%s: values reach the material" % [tname, g])
		_check(_lab._tabs["tile"].text.ends_with("●"), "%s: changed tab is marked" % tname)

		# 구역 색 띠
		_lab.select_group("tile")
		_check(_lab._sliders.has("zone"), "%s: tile has zone slider" % tname)
		_lab.set_value("tile", "zone", 1.8)
		_check(_eq(_b.board.zone_k, 1.8), "%s: zone strength reaches the board (%.2f)" % [tname, _b.board.zone_k])

		# 전체는 곱해진다
		_lab.set_value("all", "val", 0.5)
		_lab.set_value("all", "hue", 10.0)
		var tile_mat: ShaderMaterial = mats["tile"]
		_check(_eq(tile_mat.get_shader_parameter("fl_val"), 0.55 * 0.5), "%s: 'all' multiplies value (%.3f)" % [tname, float(tile_mat.get_shader_parameter("fl_val"))])
		_check(_eq(tile_mat.get_shader_parameter("fl_hue"), 40.0 / 360.0), "%s: 'all' adds hue" % tname)

		# 원본 보기
		_lab.set_bypass(true)
		_check(_mats_default() and _eq(_b.board.zone_k, 1.0), "%s: bypass shows the original" % tname)
		_lab.set_bypass(false)
		_check(_eq(tile_mat.get_shader_parameter("fl_sat"), 0.3), "%s: bypass off restores values" % tname)

		# 저장 → 다시 읽기
		_lab._flush()
		_check(FileAccess.file_exists(TEST_CFG), "%s: saved to cfg" % tname)
		FieldLook.reload_config()
		_check(_eq(FieldLook.get_v(tname, "tile", "sat"), 0.3) and _eq(FieldLook.get_v(tname, "all", "val"), 0.5) \
			and (FieldLook.get_v(tname, "tile", "tint") as Color).is_equal_approx(Color(0.2, 0.4, 0.6)), "%s: values survive reload" % tname)
		await _wait(0.3)
		await _shot("%s_02_all_changed" % tname)

		# 초기화
		_lab.select_group("tile")
		_lab.reset_group()
		_check(FieldLook.is_default(tname, "tile") and not FieldLook.is_default(tname), "%s: reset one element" % tname)
		_lab.reset_all()
		_check(FieldLook.is_default(tname) and _mats_default(), "%s: reset all" % tname)

		# 픽셀: 타일만 어둡게 / 전체 무채색
		if base != null:
			_lab.set_value("tile", "val", 0.35)
			_lab.set_value("tile", "sat", 0.5)
			await _wait(0.3)
			var dark := await _grab()
			await _shot("%s_03_tile_dim" % tname)
			_check(_luma(dark) < _luma(base) * 0.92, "%s: dimming tiles darkens the field (%.3f -> %.3f)" % [tname, _luma(base), _luma(dark)])
			_lab.reset_all()
			_lab.set_value("all", "sat", 0.0)
			await _wait(0.3)
			var grey := await _grab()
			await _shot("%s_04_all_grey" % tname)
			_check(_chroma(grey) < _chroma(base) * 0.75, "%s: zero saturation greys the background (%.3f -> %.3f)" % [tname, _chroma(base), _chroma(grey)])
			_lab.reset_all()
			_lab.set_value("bg", "val", 0.4)
			_lab.set_value("fog", "alpha", 0.3)
			_lab.set_value("tile", "sat", 0.6)
			_lab.set_value("tile", "val", 0.8)
			await _wait(0.3)
			await _shot("%s_05_readable_example" % tname)
			_lab.reset_all()
	_lab._flush()

	# 본 전투가 저장값을 읽는다: 값을 저장한 뒤 전투 씬을 따로 열어 재질을 확인
	FieldLook.set_v("desert", "tile", "sat", 0.45)
	FieldLook.set_v("void", "tile", "sat", 0.45)
	FieldLook.save()
	FieldLook.reload_config()
	var plain: VDBattle = (load("res://scenes/void_defense/VoidDefense.tscn") as PackedScene).instantiate()
	add_child(plain)
	await get_tree().process_frame
	_check(plain.sandbox == null, "plain battle (not sandbox)")
	_check(plain.board.material is ShaderMaterial and _eq((plain.board.material as ShaderMaterial).get_shader_parameter("fl_sat"), 0.45), "real battle reads the saved look")
	plain.queue_free()

	_remove(TEST_CFG)
	_remove(TEST_THEME_CFG)
	print("[field-lab-test] DONE fails=%d %s" % [_fails.size(), str(_fails)])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _mats() -> Dictionary:
	return {
		"tile": _b.board.material, "bg": _b._background_material, "prop_back": _b.props.back.material,
		"prop_front": _b.props.front.material, "fog": _b._fog_material,
	}


func _mats_default() -> bool:
	var mats := _mats()
	for g: String in mats:
		var m: ShaderMaterial = mats[g]
		if m == null:
			return false
		if not (_eq(m.get_shader_parameter("fl_hue"), 0.0) and _eq(m.get_shader_parameter("fl_sat"), 1.0) and _eq(m.get_shader_parameter("fl_val"), 1.0) \
				and _eq(m.get_shader_parameter("fl_contrast"), 1.0) and _eq(m.get_shader_parameter("fl_alpha"), 1.0) \
				and _eq((m.get_shader_parameter("fl_tint") as Color).a, 0.0)):
			return false
	return true


func _eq(a: Variant, b: float) -> bool:
	return a != null and absf(float(a) - b) < 0.001


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


## 화면 가운데(필드) 영역의 작은 이미지. 헤드리스면 null.
func _grab() -> Image:
	if _headless():
		return null
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var s := img.get_size()
	var r := Rect2i(int(s.x * 0.3), int(s.y * 0.25), int(s.x * 0.4), int(s.y * 0.45))
	var crop := img.get_region(r)
	crop.resize(64, 40, Image.INTERPOLATE_BILINEAR)
	return crop


func _luma(img: Image) -> float:
	var sum := 0.0
	for y in img.get_height():
		for x in img.get_width():
			sum += img.get_pixel(x, y).get_luminance()
	return sum / float(img.get_width() * img.get_height())


func _chroma(img: Image) -> float:
	var sum := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			sum += maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
	return sum / float(img.get_width() * img.get_height())


func _shot(shot_name: String) -> void:
	if out_dir == "" or _headless():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out_dir).path_join(shot_name + ".png"))


func _check(ok: bool, what: String) -> void:
	print("[field-lab-test] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)
