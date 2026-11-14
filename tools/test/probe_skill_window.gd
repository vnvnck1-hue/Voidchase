## 턴테이블 캐릭터 → 스킬창 열기/닫기/전환 + SP 알림 외곽선 점검 (2026-11-13).
##   헤드리스: Godot --headless --path . res://tools/test/SkillWindowProbe.tscn   (PASS/FAIL)
##   캡처:     Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/SkillWindowProbe.tscn
##             → docs/skill_window/*.png
extends Node

const OUT := "res://docs/skill_window/"
var failures: Array[String] = []
var b: VDBattle


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
	print("[skill-window] %s %s" % ["PASS" if ok else "FAIL", what])


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	call_deferred("_run")


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")


## 턴테이블 캐릭터 i 를 누른다 (고도 안에서 만든 이벤트를 턴테이블에 직접 넣는다. OS 입력 아님)
func _click(i: int) -> void:
	var tt := b.turntable
	var r := tt._rect_of(i)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	# 다른 캐릭터에 가리지 않은 점을 찾아 누른다
	for gy in 12:
		for gx in 7:
			var p := r.position + r.size * Vector2((gx + 0.5) / 7.0, (gy + 0.5) / 12.0)
			if tt.item_at(p) == i:
				ev.position = p
				tt._gui_input(ev)
				return
	_check(false, "no visible point on character %d" % i)


func _run() -> void:
	b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	while b.allies.size() < 4:
		await get_tree().process_frame
	await _wait(3.5)   # 입장 연출이 끝날 때까지
	var tt := b.turntable
	var sw = b.skill_window
	var front := tt.hero_of(tt.selected)
	_check(front != "" and VDData.HERO_SKILLS.has(front), "front character maps to a hero (%s)" % front)
	_check(not sw.is_open and not tt.is_alerting(front), "starts closed with no alert")
	await _shot("00_idle")

	# SP 알림: 앞(시트) · 리그(올리비아=mage) 에 SP
	b.growth.data[front]["sp"] = 2
	b.growth.data["mage"]["sp"] = 1
	await _wait(0.8)
	_check(tt.is_alerting(front) and tt.is_alerting("mage") and not tt.is_alerting("gunner"), "heroes with SP get the outline alert")
	await _shot("01_alert")

	# 앞 캐릭터를 누르면 열린다
	_click(tt.selected)
	await _wait(0.6)
	_check(sw.is_open and sw.visible and sw.hero == front, "tapping the front character opens its skill window (%s)" % sw.hero)
	await _shot("02_open")

	# 열린 채 캐릭터를 바꾸면 다음 캐릭터 창으로
	tt.select_next(1)
	await _wait(0.12)
	await _shot("03_switching")
	await _wait(0.6)
	var next := tt.hero_of(tt.selected)
	_check(next != front and sw.is_open and sw.hero == next, "turning the table keeps the window open on the next hero (%s)" % sw.hero)
	await _shot("04_switched")

	# 뒤 캐릭터를 눌러 바꿔도 열린 채 따라간다
	# (맨 뒤 캐릭터는 앞 캐릭터에 완전히 가려 누를 수 없다 → 옆 캐릭터를 누른다)
	var side := posmod(tt.selected + 1, VDTurntable.ROSTER.size())
	_click(side)
	await _wait(0.7)
	_check(tt.selected == side and sw.is_open and sw.hero == tt.hero_of(side), "tapping a side character switches the open window (%s)" % sw.hero)
	var mi := tt.index_of_hero("mage")
	tt.select(mi)
	await _wait(0.7)
	_check(sw.is_open and sw.hero == "mage", "window follows to the rig character (%s)" % sw.hero)
	await _shot("05_mage_open")

	# 스킬을 찍어 SP 를 다 쓰면 알림이 꺼진다
	sw._try_upgrade(0)
	await _wait(0.6)
	_check(b.growth.sp_of("mage") == 0 and not tt.is_alerting("mage"), "spending the last SP clears the alert")
	_check(tt.is_alerting(front), "the other hero keeps its alert")

	# 다시 누르면 닫힌다
	_click(tt.selected)
	await _wait(0.5)
	_check(not sw.is_open and not sw.visible, "tapping the front character again closes the window")
	await _shot("06_closed")

	# 닫힌 채 돌리면 열리지 않는다
	tt.select(tt.index_of_hero(front))
	await _wait(0.6)
	_check(not sw.is_open, "turning while closed stays closed")
	await _shot("07_alert_front")

	# 분대 카드로도 열리고 턴테이블이 그 영웅으로 돈다 (배치 단계)
	if b.state != VDBattle.State.BATTLE:
		b._on_card_pressed("gunner")
		await _wait(0.6)
		_check(sw.is_open and sw.hero == "gunner" and tt.hero_of(tt.selected) == "gunner", "squad card opens the window and turns the table")
		b._on_card_pressed("gunner")
		await _wait(0.4)
		_check(not sw.is_open, "squad card again closes it")

	print("[skill-window] %s (%d failures)" % ["ALL PASS" if failures.is_empty() else "FAILED", failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
