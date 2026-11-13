## 대화 연출 (프롤로그 · 마지막 문 · 엔딩 한마디): 화면을 살짝 어둡게 하고 화자의 전신 그림을 세운 뒤 아래 대사창에 한 글자씩 찍는다.
##   넘기기: 클릭 / Space / Enter (찍는 중이면 먼저 다 보여 준다) · 건너뛰기: [건너뛰기] 버튼 / Esc / 길게 누르기(0.6초)
## 줄 형식: ["화자 id", "대사"] (CaseData.CAST). 화자가 "note" 면 대사창 대신 가운데에 쪽지 카드를 띄운다.
## 초상이 없는 화자(의뢰인·단말)는 신호 파형이 흐르는 홀로그램 패널로 세운다 (새 캐릭터 원화 없이).
## 실제 시간으로 돈다 (슬로모션·일시정지 무관). 끝나면 finished 를 내고 스스로 지워진다.
class_name StoryDialog
extends CanvasLayer

signal finished

const GameFonts := preload("res://scripts/game_fonts.gd")
const DESIGN := Vector2(1920, 1080)
const CPS := 38.0                 # 초당 글자 수
const HOLD_SKIP := 0.6
const BOX := Rect2(330, 770, 1260, 230)
const PORTRAIT_H := 760.0

var lines: Array = []
var dim := 0.62                   # 뒤 화면을 어둡게 하는 정도
var auto_free := true

var _root: Control
var _shade: ColorRect
var _box: PanelContainer
var _name: Label
var _text: Label
var _next: Label
var _portrait: TextureRect
var _holo: Control
var _note: PanelContainer
var _note_text: Label
var _note_sign: Label
var _skip: Button
var _i := -1
var _shown := 0.0
var _typing := false
var _clock_us := 0
var _hold := 0.0
var _pressing := false
var _who := ""
var _done := false
var _t := 0.0
var _blip: AudioStreamPlayer      # 글자가 찍히는 소리 (화자마다 높낮이가 다르다)
var _blip_at := 0
const BLIP_PITCH := {"chief": 1.0, "knight": 0.84, "gunner": 1.22, "mage": 0.72, "healer": 1.1, "client": 1.36, "note": 0.6}


static func play(parent: Node, lines_: Array, dim_ := 0.62, layer_ := 60) -> StoryDialog:
	var d := StoryDialog.new()
	d.lines = lines_
	d.dim = dim_
	d.layer = layer_
	parent.add_child(d)
	return d


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_blip = AudioStreamPlayer.new()
	_blip.stream = VDAudio._make(0.045, func(t: float) -> float: return sin(TAU * 720.0 * t) * exp(-t * 70.0) * 0.5)
	_blip.volume_db = -19.0
	add_child(_blip)
	_build()
	_clock_us = Time.get_ticks_usec()
	_advance()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var th := Theme.new()
	th.default_font = VDData.font()
	th.default_font_size = 22
	_root.theme = th
	add_child(_root)
	_root.gui_input.connect(_on_gui)
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.03, 0.02, 0.08, 0.0)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_shade)
	create_tween().set_ignore_time_scale().tween_property(_shade, "color:a", dim, 0.25)

	# 화자 그림 (왼쪽 아래에 선다)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneSwitcher.pin(_portrait, Vector2(0, 1), Rect2(40, 1080 - PORTRAIT_H - 10, 560, PORTRAIT_H))
	_portrait.modulate.a = 0.0
	_root.add_child(_portrait)
	_holo = Control.new()
	_holo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneSwitcher.pin(_holo, Vector2(0, 1), Rect2(110, 430, 380, 330))
	_holo.modulate.a = 0.0
	_holo.draw.connect(_draw_holo)
	_root.add_child(_holo)

	# 대사창
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", UiKit.comic_box(Color(0.09, 0.07, 0.19, 0.96), 16, 30))
	SceneSwitcher.pin(_box, Vector2(0.5, 1), BOX)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(vb)
	_name = UiKit.label("", 30, UiKit.CYAN, GameFonts.bold())
	UiKit.outlined(_name, Color(0.03, 0.02, 0.07), 8)
	vb.add_child(_name)
	_text = UiKit.label("", 32, UiKit.CREAM)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_constant_override("line_spacing", 8)
	vb.add_child(_text)
	_next = UiKit.label("▼", 22, UiKit.PINK)
	_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(_next)

	# 쪽지 카드 (가운데)
	_note = PanelContainer.new()
	var nsb := UiKit.comic_box(Color(0.97, 0.94, 0.86), 6, 44)
	_note.add_theme_stylebox_override("panel", nsb)
	SceneSwitcher.pin(_note, Vector2(0.5, 0.5), Rect2(560, 300, 800, 400))
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.visible = false
	_note.pivot_offset = Vector2(400, 200)
	_root.add_child(_note)
	var nvb := VBoxContainer.new()
	nvb.add_theme_constant_override("separation", 26)
	nvb.alignment = BoxContainer.ALIGNMENT_CENTER
	_note.add_child(nvb)
	var head := UiKit.tag("접수된 쪽지", Color(0.45, 0.4, 0.6), 18)
	nvb.add_child(head)
	_note_text = UiKit.label("", 38, Color(0.16, 0.13, 0.26))
	_note_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_text.add_theme_constant_override("line_spacing", 12)
	nvb.add_child(_note_text)
	_note_sign = UiKit.label("", 30, Color(0.35, 0.3, 0.5))
	_note_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nvb.add_child(_note_sign)

	_skip = UiKit.button("건너뛰기  ▶▶", UiKit.PINK, 18, Vector2(170, 44))
	SceneSwitcher.pin(_skip, Vector2(1, 0), Rect2(1650, 28, 190, 44))
	_skip.pressed.connect(skip)
	_root.add_child(_skip)


func _draw_holo() -> void:
	var c := CaseData.cast(_who)
	var col: Color = c["color"]
	var sz := _holo.size
	var r := Rect2(Vector2.ZERO, sz)
	_holo.draw_style_box(UiKit.box(Color(col.darkened(0.82), 0.9), Color(col, 0.9), 3, 14, 0), r)
	# 스캔선
	var y := 10.0
	while y < sz.y - 8.0:
		_holo.draw_line(Vector2(8, y), Vector2(sz.x - 8, y), Color(col, 0.07), 1.0)
		y += 6.0
	# 흐르는 신호 파형 (말할 때 진폭이 커진다)
	var amp := 46.0 if _typing else 16.0
	var pts := PackedVector2Array()
	for i in 61:
		var x := 26.0 + (sz.x - 52.0) * i / 60.0
		var env := sin(PI * i / 60.0)
		var v := sin(i * 0.55 + _t * 7.0) * 0.6 + sin(i * 1.7 - _t * 11.0) * 0.4
		pts.append(Vector2(x, sz.y * 0.5 + v * amp * env))
	_holo.draw_polyline(pts, col.lightened(0.25), 4.0, true)
	_holo.draw_polyline(pts, Color(col, 0.25), 12.0, true)
	var f := GameFonts.bold()
	_holo.draw_string(f, Vector2(22, 38), "SIGNAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(col, 0.9))
	_holo.draw_string(f, Vector2(22, sz.y - 20), "● LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UiKit.PINK, 0.6 + 0.4 * sin(_t * 5.0)))


func _advance() -> void:
	_i += 1
	if _i >= lines.size():
		_finish()
		return
	var line: Array = lines[_i]
	var who := String(line[0])
	var text := String(line[1])
	if who == "note":
		_show_note(text, String(line[2]) if line.size() > 2 else "")
		return
	_note.visible = false
	_box.visible = true
	var c := CaseData.cast(who)
	_name.text = String(c["name"])
	_name.add_theme_color_override("font_color", c["color"])
	_text.text = text
	_text.visible_characters = 0
	_shown = 0.0
	_typing = true
	_next.visible = false
	_blip_at = 0
	if who != _who:
		_who = who
		_swap_portrait(c)
	# 대사창이 살짝 튄다
	_box.pivot_offset = _box.size * 0.5
	_box.scale = Vector2(1.0, 0.94)
	create_tween().set_ignore_time_scale().tween_property(_box, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _swap_portrait(c: Dictionary) -> void:
	var path := String(c["portrait"])
	var has := path != "" and ResourceLoader.exists(path)
	var show: Control = _portrait if has else _holo
	var hide: Control = _holo if has else _portrait
	if has:
		_portrait.texture = load(path)
	hide.modulate.a = 0.0
	show.modulate.a = 0.0
	var home_x := float(show.get_meta("home_x", show.position.x))
	show.set_meta("home_x", home_x)
	show.position.x = home_x - 60.0
	var tw := create_tween().set_ignore_time_scale().set_parallel()
	tw.tween_property(show, "modulate:a", 1.0, 0.18)
	tw.tween_property(show, "position:x", home_x, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_note(text: String, sign_: String) -> void:
	_box.visible = false
	_portrait.modulate.a = 0.0
	_holo.modulate.a = 0.0
	_who = ""
	_note.visible = true
	_note_text.text = text
	_note_text.visible_characters = 0
	_note_sign.text = sign_
	_note_sign.modulate.a = 0.0
	_shown = 0.0
	_blip_at = 0
	_typing = true
	_note.scale = Vector2(0.7, 0.7)
	_note.rotation = -0.12
	_note.modulate.a = 0.0
	var tw := create_tween().set_ignore_time_scale().set_parallel()
	tw.tween_property(_note, "modulate:a", 1.0, 0.2)
	tw.tween_property(_note, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_note, "rotation", -0.025, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _typing_label() -> Label:
	return _note_text if _note.visible else _text


func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf((now - _clock_us) / 1e6, 0.0, 0.1)
	_clock_us = now
	_t += dt
	if _done:
		return
	if _typing:
		var l := _typing_label()
		_shown += CPS * dt * (0.7 if _note.visible else 1.0)
		var total := l.get_total_character_count()
		l.visible_characters = mini(int(_shown), total)
		if int(_shown) >= _blip_at + 3 and int(_shown) < total:
			_blip_at = int(_shown)
			_blip.pitch_scale = float(BLIP_PITCH.get("note" if _note.visible else _who, 1.0)) * randf_range(0.96, 1.05)
			_blip.play()
		if int(_shown) >= total:
			_end_typing()
	else:
		_next.modulate.a = 0.55 + 0.45 * sin(_t * 6.0)
	if _holo.modulate.a > 0.01:
		_holo.queue_redraw()
	if _pressing:
		_hold += dt
		if _hold >= HOLD_SKIP:
			skip()


func _end_typing() -> void:
	_typing = false
	var l := _typing_label()
	l.visible_characters = -1
	_next.visible = not _note.visible
	if _note.visible:
		create_tween().set_ignore_time_scale().tween_property(_note_sign, "modulate:a", 1.0, 0.3)


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pressing = event.pressed
		_hold = 0.0
		if event.pressed:
			step()


func _unhandled_key_input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			step()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			skip()
			get_viewport().set_input_as_handled()


## 한 번 넘기기: 찍는 중이면 다 보여 주고, 다 찍혔으면 다음 줄.
func step() -> void:
	if _done:
		return
	if _typing:
		_end_typing()
	else:
		_advance()


func skip() -> void:
	if not _done:
		_finish()


func _finish() -> void:
	_done = true
	_pressing = false
	var tw := create_tween().set_ignore_time_scale()
	tw.tween_property(_root, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func() -> void:
		finished.emit()
		if auto_free:
			queue_free())


func is_done() -> bool:
	return _done
