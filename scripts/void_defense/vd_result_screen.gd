## 다이브 결과 화면 (완료 · 전멸 · 중단 공통). docs/FTUE_분석_및_구조설계.md 3.6
##   머리표 → 제목이 팡 → 기록이 한 줄씩 굴러 올라감 → 시간의 결정 환산 → (완료) 엽서가 뒤집히며 등장 → (첫 다이브) 허브 해금 알림 → 버튼.
##   버튼: [상담소로] (Space/Enter) · [다시 다이브] (R). 클릭/Space 로 연출을 끝까지 당길 수 있다.
## 실제 시간으로 직접 진행한다. VDCaseRun 이 만든 CanvasLayer 안의 화면 전체 Control.
class_name VDResultScreen
extends Control

signal to_hub
signal retry

const GameFonts := preload("res://scripts/game_fonts.gd")
const VDMainButton := preload("res://scripts/void_defense/vd_main_button.gd")
const ROW_AT := 0.9               # 첫 기록 줄이 뜨는 시각
const ROW_STEP := 0.32
const COUNT_SEC := 0.45

var data := {}
var audio: VDAudio
var _t := 0.0
var _clock_us := 0
var _end := 0.0                   # 모든 연출이 끝나는 시각 (이때 버튼이 열린다)
var _dim: ColorRect
var _panel: PanelContainer
var _tag: Label
var _title: Label
var _sub: Label
var _rows: Array = []             # [{box, value: Label, to: int, fmt, at}]
var _crystal_box: Control
var _crystal: Label
var _crystal_note: Label
var _crystal_at := 0.0
var _postcard: PanelContainer
var _postcard_at := -1.0
var _unlock: Label
var _unlock_at := -1.0
var _buttons: HBoxContainer
var _btn_hub: VDMainButton
var _btn_retry: Button
var _ticked := {}
var _closed := false


## d: {cleared, mode, case_no, case_title, client, session, rooms, room_total, kills, relics, essence,
##     crystals, crystal_note, postcard (글 또는 ""), first_unlock, aborted}
func setup(d: Dictionary, audio_: VDAudio) -> void:
	data = d
	audio = audio_


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var th := Theme.new()
	th.default_font = VDData.font()
	th.default_font_size = 22
	theme = th
	var cleared := bool(data.get("cleared", false))
	var accent := UiKit.GOLD if cleared else UiKit.CYAN
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.04, 0.03, 0.11, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	add_child(UiKit.screen_fx(0.05, 0.6))

	var has_card := String(data.get("postcard", "")) != ""
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.comic_box(Color(0.08, 0.06, 0.17, 0.96), 18, 40))
	var px := 300.0 if has_card else 510.0
	SceneSwitcher.pin(_panel, Vector2(0.5, 0.5), Rect2(px, 130, 900, 790))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_panel.add_child(vb)
	var mode := String(data.get("mode", "case"))
	_tag = UiKit.tag("CASE %02d · 「%s」 · %d회기" % [int(data.get("case_no", 1)), String(data.get("case_title", "")), int(data.get("session", 1))] if mode == "case" else "무한 야근 · 기록", accent, 20)
	vb.add_child(_tag)
	var title := "의뢰 완료" if cleared else ("상담 중단" if bool(data.get("aborted", false)) else "오늘 상담은 여기까지")
	if mode != "case":
		title = "야근 끝"
	_title = UiKit.label(title, 84, accent, GameFonts.bold())
	UiKit.outlined(_title, Color(0.03, 0.02, 0.07), 18)
	_title.pivot_offset = Vector2(0, 60)
	vb.add_child(_title)
	var sub := ""
	if mode == "case":
		sub = "%s 님의 마음이 한결 가벼워졌습니다." % String(data.get("client", "")) if cleared else "%s 님, 다음 회기에 또 봬요. 결정은 그대로 남습니다." % String(data.get("client", ""))
	else:
		sub = "수고했어요. 야근 수당은 결정으로."
	_sub = UiKit.label(sub, 24, UiKit.DIM)
	vb.add_child(_sub)
	vb.add_child(_gap(10))

	var rows := [
		["정리한 방", int(data.get("rooms", 0)), "%d / " + str(int(data.get("room_total", 0))) if mode == "case" else "%d"],
		["치운 엉킨 생각", int(data.get("kills", 0)), "%d"],
		["되찾은 기억 조각", int(data.get("relics", 0)), "%d"],
		["모은 정수", int(data.get("essence", 0)), "%d"],
	]
	var at := ROW_AT
	for r in rows:
		var h := HBoxContainer.new()
		h.modulate.a = 0.0
		var k := UiKit.label(String(r[0]), 28, UiKit.CREAM)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(k)
		var v := UiKit.label("0", 34, UiKit.CREAM, GameFonts.display())
		h.add_child(v)
		vb.add_child(h)
		_rows.append({"box": h, "value": v, "to": int(r[1]), "fmt": String(r[2]), "at": at})
		at += ROW_STEP
	vb.add_child(_gap(6))
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.14)
	line.custom_minimum_size = Vector2(0, 2)
	vb.add_child(line)

	# 시간의 결정
	_crystal_at = at + 0.15
	var ch := HBoxContainer.new()
	ch.modulate.a = 0.0
	_crystal_box = ch
	var ck := VBoxContainer.new()
	ck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ck.add_child(UiKit.label("시간의 결정", 32, UiKit.GOLD, GameFonts.bold()))
	_crystal_note = UiKit.label(String(data.get("crystal_note", "")), 17, UiKit.MUTED)
	ck.add_child(_crystal_note)
	ch.add_child(ck)
	_crystal = UiKit.label("+0", 64, UiKit.GOLD, GameFonts.display())
	UiKit.outlined(_crystal, Color(0.03, 0.02, 0.07), 12)
	_crystal.pivot_offset = Vector2(60, 40)
	ch.add_child(_crystal)
	vb.add_child(ch)
	_end = _crystal_at + COUNT_SEC + 0.3

	if bool(data.get("first_unlock", false)):
		_unlock_at = _end
		_unlock = UiKit.label("상담소에 새 메뉴가 열렸습니다 —  분대 · 강화 · 엽서 벽", 22, UiKit.CYAN, GameFonts.bold())
		_unlock.add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.CYAN, 0.12), Color(UiKit.CYAN, 0.7), 2, 10, 14))
		_unlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_unlock.modulate.a = 0.0
		vb.add_child(_unlock)
		_end += 0.5
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(fill)

	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 30)
	_buttons.modulate.a = 0.0
	vb.add_child(_buttons)
	_btn_retry = UiKit.button("다시 다이브  (R)", UiKit.PINK, 24, Vector2(260, 70))
	_btn_retry.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_btn_retry.pressed.connect(_emit.bind("retry"))
	_buttons.add_child(_btn_retry)
	_btn_hub = VDMainButton.new()
	_btn_hub.text = "상담소로"
	_btn_hub.custom_minimum_size = Vector2(340, 88)
	_btn_hub.pressed.connect(_emit.bind("hub"))
	_buttons.add_child(_btn_hub)
	_btn_hub.disabled = true
	_btn_retry.disabled = true

	# 엽서 (완료 시): 패널 오른쪽에서 뒤집히며 등장
	if has_card:
		_postcard_at = _end
		_end += 0.9
		_postcard = PanelContainer.new()
		_postcard.add_theme_stylebox_override("panel", UiKit.comic_box(Color(0.97, 0.94, 0.86), 8, 30))
		SceneSwitcher.pin(_postcard, Vector2(0.5, 0.5), Rect2(1240, 300, 400, 460))
		_postcard.pivot_offset = Vector2(200, 230)
		_postcard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_postcard.modulate.a = 0.0
		add_child(_postcard)
		var pv := VBoxContainer.new()
		pv.add_theme_constant_override("separation", 18)
		_postcard.add_child(pv)
		pv.add_child(UiKit.tag("POSTCARD · 엽서 획득", Color(0.5, 0.42, 0.7), 16))
		var crown := Control.new()
		crown.custom_minimum_size = Vector2(0, 120)
		crown.draw.connect(func() -> void:
			var c := Vector2(crown.size.x * 0.5, 66.0)
			var pts := PackedVector2Array([c + Vector2(-76, 36), c + Vector2(-84, -30), c + Vector2(-40, 2), c + Vector2(0, -46), c + Vector2(40, 2), c + Vector2(84, -30), c + Vector2(76, 36)])
			crown.draw_colored_polygon(pts, Color(1.0, 0.82, 0.38))
			pts.append(pts[0])
			crown.draw_polyline(pts, Color(0.16, 0.1, 0.24), 5.0, true)
			for dx: float in [-40.0, 0.0, 40.0]:
				crown.draw_circle(c + Vector2(dx, 16), 7.0, Color(1.0, 0.36, 0.62)))
		pv.add_child(crown)
		var txt := UiKit.label(String(data["postcard"]), 26, Color(0.16, 0.13, 0.26))
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.add_theme_constant_override("line_spacing", 8)
		pv.add_child(txt)
	_clock_us = Time.get_ticks_usec()


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func _k(t: float, start: float, dur: float) -> float:
	return clampf((t - start) / dur, 0.0, 1.0)


func _tick(key: String, pitch := 1.0) -> void:
	if _ticked.has(key):
		return
	_ticked[key] = true
	if audio:
		audio.play("tick" if not key.begins_with("chime") else "chime", 0.02, -6.0, pitch)


func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf((now - _clock_us) / 1e6, 0.0, 1.0 / 20.0)
	_clock_us = now
	_t += dt
	_dim.color.a = 0.86 * _k(_t, 0.0, 0.35)
	_panel.modulate.a = _k(_t, 0.1, 0.25)
	# 제목: 가로로 길게 눌렸다가 쫀득하게
	var tk := _k(_t, 0.3, 0.4)
	_title.modulate.a = minf(tk * 4.0, 1.0)
	_title.scale = Vector2(lerpf(1.5, 1.0, UIIntro.back_out(tk)), lerpf(0.5, 1.0, UIIntro.back_out(tk)))
	_sub.modulate.a = _k(_t, 0.6, 0.3)
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var k := _k(_t, float(r["at"]), 0.2)
		(r["box"] as Control).modulate.a = k
		var ck := _k(_t, float(r["at"]), COUNT_SEC)
		(r["value"] as Label).text = String(r["fmt"]) % int(round(int(r["to"]) * ck))
		if k > 0.0:
			_tick("row%d" % i, 1.1 + 0.12 * i)
	# 결정: 굴러 올라가고 끝에 톡
	var ca := _k(_t, _crystal_at, 0.2)
	_crystal_box.modulate.a = ca
	var cc := _k(_t, _crystal_at, COUNT_SEC)
	_crystal.text = "+%d" % int(round(int(data.get("crystals", 0)) * cc))
	var pop := _k(_t, _crystal_at + COUNT_SEC, 0.3)
	var s := 1.0 + 0.35 * sin(pop * PI) if pop > 0.0 and pop < 1.0 else 1.0
	_crystal.scale = Vector2(s, s)
	if cc >= 1.0:
		_tick("chime_crystal", 1.2)
	if _unlock:
		var uk := _k(_t, _unlock_at, 0.3)
		_unlock.modulate.a = uk
		if uk > 0.0:
			_tick("chime_unlock", 1.5)
	if _postcard:
		var pk := _k(_t, _postcard_at, 0.6)
		_postcard.modulate.a = minf(pk * 3.0, 1.0)
		# 뒤집기: 가로 폭이 0 → 1, 살짝 기울어 내려앉는다
		_postcard.scale = Vector2(absf(cos((1.0 - UIIntro.back_out(pk)) * PI)), 1.0) * lerpf(1.25, 1.0, pk)
		_postcard.rotation = lerpf(0.3, 0.045, UIIntro.back_out(pk))
		if pk > 0.0:
			_tick("chime_card", 1.0)
	var bk := _k(_t, _end, 0.25)
	_buttons.modulate.a = bk
	if bk > 0.0 and _btn_hub.disabled:
		_btn_hub.disabled = false
		_btn_retry.disabled = false
		_btn_hub.bump(1.2)


func _emit(what: String) -> void:
	if _closed:
		return
	_closed = true
	if audio:
		audio.play("click")
	if what == "hub":
		to_hub.emit()
	else:
		retry.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _t < _end:
		_t = _end   # 연출을 끝까지 당긴다


func _unhandled_key_input(event: InputEvent) -> void:
	if _closed or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		if _t < _end:
			_t = _end
		else:
			_emit("hub")
	elif event.keycode == KEY_R and _t >= _end:
		get_viewport().set_input_as_handled()
		_emit("retry")


## 연출이 끝나 버튼이 열렸는가 (테스트용).
func ready_for_input() -> bool:
	return _t >= _end + 0.25
