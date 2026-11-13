## 전투 중 한마디 (말풍선) 와 장소 카드. 전투를 멈추지 않는다 (기획서 8장: 대화창으로 진행을 끊지 않는다).
##   say(who, text)        왼쪽 위(배속 버튼 아래)에 얼굴 칩 + 이름 + 한 줄. 차례로 하나씩 보이고 저절로 사라진다.
##   shout(text, col)      보스 외침: 화면 위쪽 가운데에 크게 한 줄 (기믹 메시지 자리 아래).
##   place(name, sub, n)   새 방 도착: 왼쪽에서 「방 이름」 카드가 밀려 들어왔다 나간다.
## VDCaseRun 이 만든 CanvasLayer 안의 화면 전체 Control. 실제 시간으로 직접 진행한다.
class_name VDBark
extends Control

const GameFonts := preload("res://scripts/game_fonts.gd")
const BARK_RECT := Rect2(40, 112, 540, 96)
const SHOUT_RECT := Rect2(360, 270, 1200, 90)
const PLACE_RECT := Rect2(0, 214, 640, 110)
const IN := 0.22
const OUT := 0.25
const CPS := 46.0

var _queue: Array = []             # [{who, text, hold}]
var _cur := {}
var _t := 0.0
var _clock_us := 0
var _box: PanelContainer
var _chip_slot: Control
var _name: Label
var _text: Label
var _shout: Label
var _shout_t := -1.0
var _shout_hold := 2.4
var _place: Control
var _place_t := -1.0
var _place_title := ""
var _place_sub := ""
var _place_no := ""
var said: Array[String] = []       # 테스트용: 지금까지 띄운 대사
var _voice: VoiceBabble            # 옹알이 음성 (대화창보다 작게)
var _voice_ci := -1
var _ending := ""
var _shout_ci := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = VDData.font()
	theme = th
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", UiKit.comic_box(Color(0.08, 0.06, 0.17, 0.94), 14, 12))
	SceneSwitcher.pin(_box, Vector2(0, 0), BARK_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.modulate.a = 0.0
	add_child(_box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_box.add_child(h)
	_chip_slot = Control.new()
	_chip_slot.custom_minimum_size = Vector2(70, 70)
	_chip_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_chip_slot)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(vb)
	_name = UiKit.label("", 18, UiKit.CYAN, GameFonts.bold())
	vb.add_child(_name)
	_text = UiKit.label("", 22, UiKit.CREAM)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_text)

	_shout = UiKit.label("", 46, UiKit.GOLD, GameFonts.bold())
	UiKit.outlined(_shout, Color(0.14, 0.02, 0.1), 18)
	_shout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SceneSwitcher.pin(_shout, Vector2(0.5, 0), SHOUT_RECT)
	_shout.pivot_offset = SHOUT_RECT.size * 0.5
	_shout.modulate.a = 0.0
	add_child(_shout)

	_place = Control.new()
	_place.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneSwitcher.pin(_place, Vector2(0, 0), PLACE_RECT)
	_place.draw.connect(_draw_place)
	_place.visible = false
	add_child(_place)
	_voice = VoiceBabble.new()
	_voice.volume_db = -17.0
	add_child(_voice)
	_clock_us = Time.get_ticks_usec()


func say(who: String, text: String, hold := 3.4) -> void:
	_queue.append({"who": who, "text": text, "hold": hold})
	said.append(text)
	print("[bark] %s: %s" % [who, text])


## 대기 중인 대사를 비운다 (방이 바뀌거나 런이 끝날 때).
func clear() -> void:
	_queue.clear()
	_place_t = -1.0
	_place.visible = false
	if not _cur.is_empty():
		_t = maxf(_t, IN + float(_cur["hold"]))


func shout(text: String, col := UiKit.GOLD, hold := 2.4) -> void:
	_shout.text = "\"%s\"" % text
	_shout.add_theme_color_override("font_color", col)
	_shout_t = 0.0
	_shout_hold = hold
	_shout_ci = -1
	VoiceBabble.warm("boss")
	said.append(text)
	print("[bark] shout: %s" % text)


func place(title: String, sub: String, number: String) -> void:
	_place_title = title
	_place_sub = sub
	_place_no = number
	_place_t = 0.0
	_place.visible = true
	print("[bark] place: %s (%s)" % [title, number])


func _start(line: Dictionary) -> void:
	_cur = line
	_t = 0.0
	var c := CaseData.cast(String(line["who"]))
	for ch in _chip_slot.get_children():
		ch.queue_free()
	_chip_slot.add_child(UiKit.face_chip(String(line["who"]), 70.0))
	_name.text = String(c["name"])
	_name.add_theme_color_override("font_color", c["color"])
	_text.text = String(line["text"])
	_text.visible_characters = 0
	_voice_ci = -1
	_ending = VoiceBabble.ending_of(_text.text)
	VoiceBabble.warm(String(line["who"]))


func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf((now - _clock_us) / 1e6, 0.0, 0.1)
	_clock_us = now
	# 말풍선
	if _cur.is_empty():
		if not _queue.is_empty():
			_start(_queue.pop_front())
	else:
		_t += dt
		var hold := float(_cur["hold"])
		var k_in := clampf(_t / IN, 0.0, 1.0)
		var k_out := clampf((_t - IN - hold) / OUT, 0.0, 1.0)
		_box.modulate.a = k_in * (1.0 - k_out)
		_box.position.x = BARK_RECT.position.x - 50.0 * (1.0 - UIIntro.back_out(k_in)) - 30.0 * k_out
		_text.visible_characters = int(maxf(_t - IN * 0.5, 0.0) * CPS)
		var ci := mini(_text.visible_characters, _text.text.length()) - 1
		if ci >= 0 and ci != _voice_ci and k_out <= 0.0:
			_voice_ci = ci
			_voice.say(String(_cur["who"]), _text.text.substr(ci, 1), float(ci) / maxf(_text.text.length() - 1, 1.0), _ending)
		if k_out >= 1.0 or (not _queue.is_empty() and _t > IN + minf(hold, 1.6)):
			_cur = {}
			_box.modulate.a = 0.0
	# 보스 외침
	if _shout_t >= 0.0:
		_shout_t += dt
		var a := clampf(_shout_t / 0.12, 0.0, 1.0) * (1.0 - clampf((_shout_t - _shout_hold) / 0.4, 0.0, 1.0))
		_shout.modulate.a = a
		var s := 1.0 + 0.5 * maxf(0.0, 1.0 - _shout_t / 0.22)
		_shout.scale = Vector2(s, s)
		_shout.rotation = 0.012 * sin(_shout_t * 23.0) * maxf(0.0, 1.0 - _shout_t / 0.8)
		# 보스 외침: 낮은 목소리로 글자를 따라 읊는다
		var sci := int(_shout_t / 0.075)
		if sci != _shout_ci and sci < _shout.text.length():
			_shout_ci = sci
			_voice.say("boss", _shout.text.substr(sci, 1), float(sci) / maxf(_shout.text.length() - 1, 1.0), "!")
		if _shout_t > _shout_hold + 0.4:
			_shout_t = -1.0
	# 장소 카드
	if _place_t >= 0.0:
		_place_t += dt
		_place.queue_redraw()
		if _place_t > 3.2:
			_place_t = -1.0
			_place.visible = false


func _draw_place() -> void:
	var t := _place_t
	var k_in := UIIntro.back_out(clampf(t / 0.4, 0.0, 1.0))
	var k_out := clampf((t - 2.7) / 0.4, 0.0, 1.0)
	var x := -PLACE_RECT.size.x * (1.0 - k_in) - PLACE_RECT.size.x * k_out * k_out
	var a := 1.0 - k_out
	var w := PLACE_RECT.size.x
	# 기울어진 띠 두 겹 (전투 버튼·배너와 같은 사선)
	var skew := 34.0
	var band := PackedVector2Array([Vector2(x, 10), Vector2(x + w, 10), Vector2(x + w - skew, 96), Vector2(x, 96)])
	_place.draw_colored_polygon(PackedVector2Array([band[0] + Vector2(0, 8), band[1] + Vector2(14, 8), band[2] + Vector2(14, 8), band[3] + Vector2(0, 8)]), Color(UiKit.PINK, 0.9 * a))
	_place.draw_colored_polygon(band, Color(0.06, 0.04, 0.14, 0.95 * a))
	_place.draw_line(band[0], band[1], Color(UiKit.CYAN, a), 3.0)
	var f: Font = GameFonts.bold()
	_place.draw_string(f, Vector2(x + 44, 36), _place_no, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(UiKit.CYAN, a))
	_place.draw_string_outline(f, Vector2(x + 40, 80), "「%s」" % _place_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 8, Color(0.03, 0.02, 0.07, a))
	_place.draw_string(f, Vector2(x + 40, 80), "「%s」" % _place_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(UiKit.CREAM, a))
	var tw := f.get_string_size("「%s」" % _place_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	_place.draw_string(VDData.font(), Vector2(x + 54 + tw, 78), "— " + _place_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(UiKit.DIM, a))
