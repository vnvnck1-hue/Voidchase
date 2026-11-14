## 글꼴 바꾸기 검사 (scripts/game_fonts.gd · scripts/font_tuner.gd).
## 헤드리스: 글꼴 13종이 읽히는지, 역할 글꼴이 같은 객체로 남은 채 내용만 바뀌는지, 영어 글꼴에 없는 한글이 한글 글꼴로 이어지는지,
##   이미 떠 있는 Label 이 다시 만들지 않아도 크기가 바뀌는지, 저장·복원이 되는지 확인한다.
##   Godot --headless --path . res://tools/test/FontProbe.tscn
## 창으로 돌리면(서브 모니터) 로비·전투·패널을 조합마다 찍어 docs/fonts/game/ 에 저장한다.
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/FontProbe.tscn
## 끝나면 user://fonts.cfg 를 실행 전 상태로 되돌린다.
extends Node

const GameFonts := preload("res://scripts/game_fonts.gd")
const OUT := "res://docs/fonts/game/"
const SAMPLE := "마음 정리 상담소 READY! -1,240"

var _fail := 0
var _cfg_backup := ""
var _had_cfg := false


func _ready() -> void:
	var cfg_abs := ProjectSettings.globalize_path(GameFonts.CFG_PATH)
	_had_cfg = FileAccess.file_exists(cfg_abs)
	if _had_cfg:
		_cfg_backup = FileAccess.get_file_as_string(cfg_abs)
	await get_tree().process_frame
	_check_files()
	await _check_live()
	if DisplayServer.get_name() != "headless":
		await _capture()
	_restore_cfg(cfg_abs)
	print("[font_probe] %s (fail %d)" % ["OK" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _check_files() -> void:
	for k in GameFonts.KO:
		if k[2] == "":
			continue
		var f := load(k[2]) as FontFile
		_expect(f != null, "load " + k[2])
		if f != null:
			_expect(f.has_char("가".unicode_at(0)) and f.has_char("A".unicode_at(0)), "%s 한글·영문 글리프" % k[1])
			print("[font_probe] %-28s %s / %s  glyph '뷁'=%s" % [k[1], f.get_font_name(), f.get_font_style_name(), f.has_char("뷁".unicode_at(0))])
	for k in GameFonts.LATIN:
		if k[2] == "":
			continue
		var f := load(k[2]) as FontFile
		_expect(f != null, "load " + k[2])
		if f != null:
			_expect(f.has_char("A".unicode_at(0)) and f.has_char("7".unicode_at(0)), "%s 영문·숫자 글리프" % k[1])
			print("[font_probe] %-28s %s  한글=%s" % [k[1], f.get_font_name(), f.has_char("가".unicode_at(0))])


func _check_live() -> void:
	GameFonts.apply_preset(0)
	var body := VDData.font()
	var disp := VDDamageLog.font()
	_expect(body == GameFonts.body() and disp == GameFonts.display(), "VDData/VDDamageLog 이 역할 글꼴을 돌려줌")
	# 이미 떠 있는 Label: 테마 기본 글꼴 = 본문 역할, 덮어쓴 글꼴 = 숫자·타이틀 역할
	var holder := Control.new()
	holder.theme = Theme.new()
	holder.theme.default_font = body
	holder.theme.default_font_size = 40
	add_child(holder)
	var l_body := Label.new()
	l_body.text = SAMPLE
	holder.add_child(l_body)
	var l_disp := Label.new()
	l_disp.text = SAMPLE
	l_disp.add_theme_font_override("font", disp)
	l_disp.add_theme_font_size_override("font_size", 40)
	holder.add_child(l_disp)
	var ls := LabelSettings.new()
	ls.font = GameFonts.bold()
	ls.font_size = 40
	var l_set := Label.new()
	l_set.text = SAMPLE
	l_set.label_settings = ls
	holder.add_child(l_set)
	await get_tree().process_frame
	var base_w := [l_body.get_minimum_size().x, l_disp.get_minimum_size().x, l_set.get_minimum_size().x]
	print("[font_probe] 기본 폭 본문/숫자/강조 = %s · %s" % [base_w, GameFonts.describe()])
	for i in range(1, GameFonts.PRESETS.size()):
		GameFonts.apply_preset(i)
		await get_tree().process_frame
		var w := [l_body.get_minimum_size().x, l_disp.get_minimum_size().x, l_set.get_minimum_size().x]
		_expect(VDData.font() == body, "조합 %d 뒤에도 같은 글꼴 객체" % i)
		_expect(GameFonts.preset_index() == i, "조합 %d 선택이 인식됨" % i)
		# 숫자·타이틀은 모든 조합에서 기본(ARCO+맑은 고딕)과 다르게 바뀐다
		_expect(absf(w[1] - base_w[1]) > 1.0, "조합 %d: 이미 떠 있는 Label(덮어쓴 글꼴)이 다시 그려짐" % i)
		_expect(absf(w[2] - base_w[2]) > 1.0, "조합 %d: LabelSettings Label 이 다시 그려짐" % i)
		if GameFonts.PRESETS[i][1]["body"][0] != "system":
			_expect(absf(w[0] - base_w[0]) > 1.0, "조합 %d: 테마 기본 글꼴 Label 이 다시 그려짐" % i)
		print("[font_probe] 조합 %d %-22s 폭 %s" % [i, GameFonts.PRESETS[i][0], w])
	# 영어 글꼴(한글 없음)을 골라도 한글은 한글 글꼴로 이어진다
	GameFonts.set_role("display", "kart", "bangers")
	var d := GameFonts.display()
	_expect(d.has_char("가".unicode_at(0)) and d.has_char("A".unicode_at(0)), "Bangers + 카트 고딕: 한글이 대체 글꼴로 이어짐")
	var kart := load(GameFonts.KO[1][2]) as Font
	var ko_w := d.get_string_size("마음정리", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var kart_w := kart.get_string_size("마음정리", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	_expect(absf(ko_w - kart_w) < 0.5, "한글 부분은 카트 고딕 폭 (%.1f vs %.1f)" % [ko_w, kart_w])
	var bang := load(GameFonts.LATIN[2][2]) as Font
	_expect(absf(d.get_string_size("READY", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x - bang.get_string_size("READY", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x) < 0.5, "영문 부분은 Bangers 폭")
	# 가변 글꼴 굵기 (DynaPuff wght 700)
	GameFonts.set_role("display", "", "dynapuff")
	_expect(not (GameFonts.display() as FontVariation).variation_opentype.is_empty(), "DynaPuff 굵기 축 적용")
	# 와구리체에 없는 글자는 시스템 고딕으로
	GameFonts.set_role("bold", "waguri", "same")
	_expect(GameFonts.bold().has_char("뷁".unicode_at(0)), "와구리체에 없는 글자도 대체 글꼴로 그려짐")
	# 저장 → 다시 읽기
	var cfg := ConfigFile.new()
	_expect(cfg.load(GameFonts.CFG_PATH) == OK and cfg.get_value("fonts", "display_latin", "") == "dynapuff" and cfg.get_value("fonts", "bold_ko", "") == "waguri", "user://fonts.cfg 저장")
	GameFonts.apply_preset(0)
	_expect(GameFonts.preset_index() == 0, "기본 조합 복귀")
	# 설정 메뉴 항목과 패널
	SceneSwitcher.set_menu_open(true)
	await get_tree().process_frame
	var texts := []
	for c in SceneSwitcher._menu_box.get_children():
		if c is Button:
			texts.append((c as Button).text)
		elif c is VBoxContainer and c.get_child_count() > 0 and c.get_child(0) is Label:
			texts.append((c.get_child(0) as Label).text)
	_expect(texts.has("글꼴 조합") and texts.has("글꼴 바꾸기  (F5)"), "설정 메뉴에 글꼴 항목 (%s)" % [texts])
	SceneSwitcher.set_menu_open(false)
	var ev := InputEventKey.new()
	ev.keycode = KEY_F5
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(SceneSwitcher._font_tuner.is_open(), "F5 로 글꼴 패널 열림")
	SceneSwitcher._font_tuner.toggle()
	holder.queue_free()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# 씬 전환이 이 노드(현재 씬)를 지우지 않도록 빈 노드를 현재 씬으로 세운다
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	SceneSwitcher.go_lobby()
	await get_tree().create_timer(0.1).timeout
	while SceneSwitcher.is_loading():
		await get_tree().process_frame
	await get_tree().create_timer(2.5).timeout   # 로비 등장 연출
	for i in GameFonts.PRESETS.size():
		GameFonts.apply_preset(i)
		SceneSwitcher._font_tuner.refresh()
		if i == 0 or i == 1:
			SceneSwitcher._font_tuner.toggle()
			SceneSwitcher.set_menu_open(true)
		await _shot("lobby_%d" % i)
		if SceneSwitcher._font_tuner.is_open():
			SceneSwitcher._font_tuner.toggle()
		SceneSwitcher.set_menu_open(false)
	# 전투: 피해 숫자·배너·버튼
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	get_tree().current_scene.queue_free()
	get_tree().root.add_child(b)
	get_tree().current_scene = b
	while b.enemies.is_empty():
		await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	for i in [0, 1, 2]:
		GameFonts.apply_preset(i)
		await _shot("battle_place_%d" % i)
	b.start_battle()
	await get_tree().create_timer(2.6).timeout
	for i in [1, 0, 3]:
		GameFonts.apply_preset(i)
		get_tree().paused = true
		await _shot("battle_fight_%d" % i)
		get_tree().paused = false
		await get_tree().create_timer(0.5).timeout
	GameFonts.apply_preset(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + name + ".png")
	print("[font_probe] shot ", name, " · ", GameFonts.describe())


func _restore_cfg(abs_path: String) -> void:
	if _had_cfg:
		var f := FileAccess.open(abs_path, FileAccess.WRITE)
		f.store_string(_cfg_backup)
		f.close()
	elif FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fail += 1
		print("[font_probe] FAIL ", what)
