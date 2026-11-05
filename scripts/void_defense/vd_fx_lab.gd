## 연출 연구실: 몬스터 차원 소환 연출(VDSummonFx)을 실시간으로 조절하며 반복 재생한다.
## 실제 전투와 같은 보드·이펙트·카메라(셰이크·히트스탑)를 쓰고, 값을 바꾸면 잠시 뒤 바로 다시 재생한다.
## "저장" 하면 user://summon_fx.json 에 남아 VOID DEFENSE 전투에도 그대로 쓰인다.
##   Space 재생 · R 자동 반복 토글 · Esc 로비
extends Node2D

const PANEL_W := 560.0
const ZOOM := 1.7
const TARGETS := [
	["공허 잔재", "normal", 1], ["공허 파편", "fast", 1], ["공허 포자", "skirmisher", 1],
	["공허 결정체", "tank", 1], ["공허 군주 (보스)", "boss", 1], ["웨이브 (5마리)", "normal", 5],
]
const REPLAY_GAP := 0.7          # 자동 반복: 연출이 끝나고 다음 재생까지(초)
const EDIT_DELAY := 0.3          # 값을 바꾼 뒤 이만큼 손을 떼면 다시 재생

var map: VDMap
var room := {}
var board: VDBoard
var ground_fx: Node2D
var units_root: Node2D
var fx_root: Node2D
var vfx: VDVfx
var camera: VDCamera
var audio: VDAudio

var _enemies: Array[VDUnit] = []
var _run := 0
var _target := 0
var _auto := true
var _speed := 1.0
var _dirty := false
var _edit_timer := -1.0
var _rows := {}                  # key -> {"slider", "spin"} 또는 {"opt"}
var _lbl_status: Label
var _lbl_total: Label
var _lbl_title: Label
var _chk_auto: CheckBox
var _lbl_speed: Label


func _ready() -> void:
	randomize()
	VDSummonFx.load_saved()
	audio = VDAudio.new()
	add_child(audio)
	_build_world()
	_build_ui()
	_refresh_status()
	replay()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# ---------------------------------------------------------------- world

func _build_world() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_mat := ShaderMaterial.new()
	bg_mat.shader = load("res://shaders/void_nebula.gdshader")
	bg.material = bg_mat
	bg_layer.add_child(bg)
	bg.resized.connect(func() -> void: bg_mat.set_shader_parameter("aspect", bg.size.x / maxf(bg.size.y, 1.0)))

	map = VDMap.new()
	map.rng.seed = 7
	room = map.create_root()
	board = VDBoard.new()
	board.placement_mode = false
	add_child(board)
	board.map = map
	board.current_room = room
	ground_fx = Node2D.new()
	add_child(ground_fx)
	units_root = Node2D.new()
	units_root.y_sort_enabled = true
	add_child(units_root)
	fx_root = Node2D.new()
	fx_root.z_index = 50
	add_child(fx_root)
	vfx = VDVfx.new()
	add_child(vfx)

	camera = VDCamera.new()
	camera.bg_material = bg_mat
	add_child(camera)
	camera.make_current()
	camera.base_zoom = Vector2(ZOOM, ZOOM)


## 적 구역(E) 셀들의 무게중심 (월드 셀 좌표)
func _e_center() -> Vector2:
	var cells := _e_cells()
	var sum := Vector2.ZERO
	for c in cells:
		sum += Vector2(c)
	return sum / maxf(cells.size(), 1.0)


func _e_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for l in VDMap.local_cells(room, "E"):
		out.append(VDMap.to_world(room, l.x, l.y))
	return out


# ---------------------------------------------------------------- play

func replay() -> void:
	_run += 1
	var run := _run
	for e in _enemies:
		e.queue_free()
	_enemies.clear()
	for n in ground_fx.get_children() + fx_root.get_children():
		n.queue_free()
	var t: Array = TARGETS[_target]
	var center := _e_center()
	var cells := _e_cells()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_squared_to(center) < Vector2(b).distance_squared_to(center))
	var count: int = mini(t[2], cells.size())
	if count > 1:
		cells = cells.slice(0, count * 2)
		cells.shuffle()
	# 왼쪽 조절 패널에 가리지 않게 소환 지점을 패널 오른쪽 영역 가운데로 (유닛 키만큼 조금 아래로)
	var focus := Vector2(cells[0]) if count == 1 else center
	var z := ZOOM * (0.8 if t[1] == "boss" or count > 1 else 1.0)
	camera.base_zoom = Vector2(z, z)
	camera.position = VDData.to_screen(focus) - Vector2(PANEL_W * 0.5, 90.0) / z
	for i in count:
		if run != _run:
			return
		_spawn(t[1], cells[i])
		if i < count - 1:
			await get_tree().create_timer(maxf(VDSummonFx.g("interval"), 0.01)).timeout
	if not _auto:
		return
	await get_tree().create_timer(VDUnit.appear_duration() + REPLAY_GAP).timeout
	if run == _run and _auto:
		replay()


func _spawn(id: String, cell: Vector2i) -> void:
	var u := VDUnit.new()
	u.setup(VDData.ENEMIES[id], id, 1, cell)
	units_root.add_child(u)
	u.snap_to_cell()
	_enemies.append(u)
	var foot := VDData.to_screen(Vector2(cell))
	u.appear(VDSummonFx.play_impact.bind(vfx, ground_fx, fx_root, camera, foot, u.is_boss))
	audio.play("boss_spawn" if u.is_boss else "enemy_spawn", 0.12)
	VDSummonFx.play_portal(vfx, ground_fx, foot, u.is_boss)


func _process(delta: float) -> void:
	if _edit_timer >= 0.0:
		# 슬라이더를 끄는 동안은 기다렸다가 손을 떼면(값 변화가 멈추면) 다시 재생 — 실시간 기준
		_edit_timer -= delta / maxf(Engine.time_scale, 0.0001)
		if _edit_timer < 0.0:
			replay()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				replay()
			KEY_R:
				_chk_auto.button_pressed = not _chk_auto.button_pressed


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = VDData.font()
	theme.default_font_size = 17
	root.theme = theme
	layer.add_child(root)

	# 왼쪽 조절 패널 (위아래 꽉 차게)
	var panel := PanelContainer.new()
	panel.anchor_bottom = 1.0
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = PANEL_W
	panel.offset_bottom = 0
	panel.add_theme_stylebox_override("panel", _flat(Color(0.08, 0.05, 0.14, 0.9), 0))
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	_lbl_title = _label(vb, "연출 연구실 · 몬스터 등장", 28, Color(0.95, 0.9, 1.0))
	var help := _label(vb, "값을 바꾸고 손을 떼면 바로 다시 재생 · [Space] 재생 · [R] 자동 반복", 14, Color(0.75, 0.7, 0.9))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_total = _label(vb, "", 15, Color(1.0, 0.85, 0.45))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	var group := ""
	for p in VDSummonFx.PARAMS:
		if p[1] != group:
			group = p[1]
			var gl := _label(list, "— " + group, 18, Color(0.85, 0.65, 1.0))
			gl.custom_minimum_size.y = 34
			gl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_add_row(list, p)

	# 아래 버튼들
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)
	_button(grid, "저장", _on_save)
	_button(grid, "저장값으로 되돌리기", _on_revert)
	_button(grid, "기본값으로", _on_defaults)
	_button(grid, "바뀐 값 복사", _on_copy)
	_button(grid, "전체 값 복사", _on_copy.bind(true))
	_button(grid, "로비로", func() -> void: SceneSwitcher.go_lobby())
	_lbl_status = _label(vb, "", 14, Color(0.7, 0.9, 0.75))
	_lbl_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# 오른쪽 아래 재생 바
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _flat(Color(0.1, 0.06, 0.18, 0.88), 10))
	SceneSwitcher.pin(bar, Vector2(1, 1), Rect2(PANEL_W + 40, 990, 1920 - PANEL_W - 80, 64))
	root.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(hb)
	var play := _button(hb, "▶ 재생", replay)
	play.custom_minimum_size = Vector2(160, 44)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.add_theme_font_size_override("font_size", 20)
	_chk_auto = CheckBox.new()
	_chk_auto.text = "자동 반복"
	_chk_auto.button_pressed = _auto
	_chk_auto.focus_mode = Control.FOCUS_NONE
	_chk_auto.toggled.connect(func(on: bool) -> void:
		_auto = on
		if on:
			replay())
	hb.add_child(_chk_auto)
	_label(hb, "대상", 17, Color(0.85, 0.8, 0.95))
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	for t in TARGETS:
		opt.add_item(t[0])
	opt.item_selected.connect(func(i: int) -> void:
		_target = i
		replay())
	hb.add_child(opt)
	_label(hb, "배속", 17, Color(0.85, 0.8, 0.95))
	var sp := HSlider.new()
	sp.min_value = 0.05
	sp.max_value = 1.0
	sp.step = 0.05
	sp.value = 1.0
	sp.custom_minimum_size = Vector2(180, 0)
	sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sp.focus_mode = Control.FOCUS_NONE
	hb.add_child(sp)
	_lbl_speed = _label(hb, "x1.00", 17, Color(1, 1, 1))
	_lbl_speed.custom_minimum_size.x = 56
	sp.value_changed.connect(func(v: float) -> void:
		_speed = v
		camera.set_game_speed(v)
		_lbl_speed.text = "x%.2f" % v)


func _add_row(parent: Control, p: Array) -> void:
	var key: String = p[0]
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	parent.add_child(hb)
	var title := _label(hb, p[2], 15, Color(0.92, 0.9, 1.0))
	title.custom_minimum_size.x = 190
	title.tooltip_text = key
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	if p[5] == 0.0:
		var opt := OptionButton.new()
		opt.focus_mode = Control.FOCUS_NONE
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for n in VDSummonFx.TRANS_NAMES:
			opt.add_item(n)
		opt.select(int(VDSummonFx.g(key)))
		opt.item_selected.connect(func(i: int) -> void: _on_value(key, float(i)))
		hb.add_child(opt)
		_rows[key] = {"opt": opt}
		return
	var slider := HSlider.new()
	slider.min_value = p[3]
	slider.max_value = p[4]
	slider.step = p[5]
	slider.value = VDSummonFx.g(key)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	hb.add_child(slider)
	var spin := SpinBox.new()
	spin.min_value = p[3]
	spin.max_value = p[4]
	spin.step = p[5]
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.value = VDSummonFx.g(key)
	spin.custom_minimum_size.x = 104
	hb.add_child(spin)
	# 기본값 표시용 리셋 버튼
	var rst := Button.new()
	rst.text = "↺"
	rst.tooltip_text = "기본값 %s" % str(p[6])
	rst.focus_mode = Control.FOCUS_NONE
	hb.add_child(rst)
	slider.value_changed.connect(func(v: float) -> void:
		spin.set_value_no_signal(v)
		_on_value(key, v))
	spin.value_changed.connect(func(v: float) -> void:
		slider.set_value_no_signal(v)
		_on_value(key, v))
	rst.pressed.connect(func() -> void: spin.value = p[6])
	_rows[key] = {"slider": slider, "spin": spin}


func _on_value(key: String, v: float) -> void:
	VDSummonFx.set_value(key, v)
	_dirty = true
	_edit_timer = EDIT_DELAY
	_refresh_status()


func _sync_rows() -> void:
	for key in _rows:
		var r: Dictionary = _rows[key]
		var v := VDSummonFx.g(key)
		if r.has("opt"):
			(r["opt"] as OptionButton).select(int(v))
		else:
			(r["slider"] as HSlider).set_value_no_signal(v)
			(r["spin"] as SpinBox).set_value_no_signal(v)


func _on_save() -> void:
	if VDSummonFx.save():
		_dirty = false
		_refresh_status("저장했습니다 → " + ProjectSettings.globalize_path(VDSummonFx.SAVE_PATH))
	else:
		_refresh_status("저장 실패")


func _on_revert() -> void:
	VDSummonFx.load_saved()
	_sync_rows()
	_dirty = false
	_refresh_status("저장된 값으로 되돌렸습니다")
	replay()


func _on_defaults() -> void:
	VDSummonFx.reset()
	_sync_rows()
	_dirty = true
	_refresh_status("코드 기본값으로 바꿨습니다 (저장하면 반영)")
	replay()


func _on_copy(all := false) -> void:
	var text := VDSummonFx.describe(all)
	DisplayServer.clipboard_set(text)
	_refresh_status("클립보드에 복사했습니다:\n" + text)


func _refresh_status(msg := "") -> void:
	_lbl_title.text = "연출 연구실 · 몬스터 등장" + ("  *" if _dirty else "")
	_lbl_total.text = "총 길이 %.2f초  (낙하 %.2f · 버팀 %.2f · 튕김 %.2f · 안착 %.2f)" % [VDUnit.appear_duration(),
		VDSummonFx.g("drop_sec"), VDSummonFx.g("hold_sec"), VDSummonFx.g("stretch_sec"), VDSummonFx.g("settle_sec")]
	if msg != "":
		_lbl_status.text = msg
	elif _dirty:
		_lbl_status.text = "저장 안 됨 — 바뀐 값은 이번 실행 동안 전투에도 적용됩니다. 다음 실행에도 쓰려면 저장하세요."
	else:
		_lbl_status.text = "저장된 값 사용 중"


func _label(parent: Node, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _flat(col: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb
