## 다이브 중 일시정지 메뉴 (Esc): 계속하기 · 처음부터 다시 · 중단하고 상담소로.
## 예전에는 Esc 한 번에 확인 없이 로비로 나가 런이 사라졌다 (FTUE 진단 9). 열려 있는 동안 트리를 멈춘다.
class_name VDPauseMenu
extends Control

signal resumed
signal restart_requested
signal abort_requested

const GameFonts := preload("res://scripts/game_fonts.gd")

var info := ""                    # 가운데 한 줄: 지금 어디까지 왔는지
var _panel: PanelContainer
var _was_paused := false
var _prev_scale := 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var th := Theme.new()
	th.default_font = VDData.font()
	theme = th
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.09, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	add_child(UiKit.screen_fx(0.07, 0.5))
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.comic_box(Color(0.08, 0.06, 0.17, 0.97), 18, 36))
	SceneSwitcher.pin(_panel, Vector2(0.5, 0.5), Rect2(660, 280, 600, 520))
	_panel.pivot_offset = Vector2(300, 260)
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	_panel.add_child(vb)
	vb.add_child(UiKit.tag("PAUSED · 접속 유지 중", UiKit.CYAN, 18))
	var title := UiKit.label("잠깐 쉬어요", 56, UiKit.CREAM, GameFonts.bold())
	vb.add_child(title)
	var sub := UiKit.label(info, 21, UiKit.DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(sub)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(gap)
	var b1 := UiKit.button("계속하기  (Esc)", UiKit.CYAN, 26, Vector2(0, 70))
	b1.pressed.connect(resume)
	vb.add_child(b1)
	var b2 := UiKit.button("처음부터 다시", UiKit.VIOLET, 22, Vector2(0, 58))
	b2.pressed.connect(func() -> void:
		_close()
		restart_requested.emit())
	vb.add_child(b2)
	var b3 := UiKit.button("중단하고 상담소로  (결정은 정산됩니다)", UiKit.PINK, 22, Vector2(0, 58))
	b3.pressed.connect(func() -> void:
		_close()
		abort_requested.emit())
	vb.add_child(b3)
	_was_paused = get_tree().paused
	get_tree().paused = true
	_panel.scale = Vector2(0.9, 0.9)
	create_tween().set_ignore_time_scale().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func resume() -> void:
	_close()
	resumed.emit()


func _close() -> void:
	if is_queued_for_deletion():
		return
	get_tree().paused = _was_paused
	queue_free()
