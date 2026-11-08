## 로비(연출 연구실 카드)와 연출 연구실 화면을 캡처한다: 연출 목록 → 몬스터 등장 → 목록 → 초궁극기 컷인 → 목록 → 궁극기 카드 불꽃.
## 각 연출에서 값 하나를 바꿔 다시 재생되는지도 본다. 바꾼 값은 저장하지 않고 버린다.
## 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/FxLabCapture.tscn
## 출력: docs/fx_lab/*.png
extends Node

const OUT := "res://docs/fx_lab/"
const CutinFx := preload("res://scripts/void_defense/vd_super_cutin_fx.gd")
const CardFlameFx := preload("res://scripts/void_defense/vd_card_flame_fx.gd")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var lobby: Node = load("res://scenes/Lobby.tscn").instantiate()
	add_child(lobby)
	await _wait(0.5)
	await _shot("01_lobby")
	lobby.queue_free()
	var lab: Node = load("res://scenes/void_defense/FxLab.tscn").instantiate()
	add_child(lab)
	await _wait(0.3)
	await _shot("02_picker")
	# 몬스터 등장: 꽂힌 직후 · 튕김 · 안착 후
	lab.call("_open", "summon")
	await _wait(VDSummonFx.g("drop_sec") + 0.02)
	await _shot("03_summon_land")
	await _wait(0.1)
	await _shot("04_summon_stretch")
	await _wait(0.8)
	await _shot("05_summon_settled")
	# 값 바꾸기 → 손 뗀 뒤 다시 재생되는지
	lab.call("_on_value", "squash_x", 3.0)
	lab.call("_on_value", "squash_y", 0.15)
	print("[fx_lab] dirty=%s describe:\n%s" % [lab.get("_dirty"), VDSummonFx.describe()])
	await _wait(lab.get("EDIT_DELAY") + VDSummonFx.g("drop_sec") + 0.03)
	await _shot("06_summon_edited_land")
	VDSummonFx.load_saved()   # 테스트 값은 저장하지 않고 버린다
	# 목록으로 → 초궁극기 컷인
	lab.call("_show_picker")
	await _wait(0.2)
	lab.call("_open", "cutin")
	await _real(CutinFx.g("impact") + 0.03)
	await _shot("07_cutin_impact")
	await _real(0.5)
	await _shot("08_cutin_hold")
	# 이름 도장 크게·색수차 크게 바꾸고 다시 재생되는지
	lab.call("_on_value", "rgb_split", 90.0)
	lab.call("_on_value", "title_scale", 4.5)
	print("[fx_lab] cutin describe:\n%s" % CutinFx.describe())
	await _real(lab.get("EDIT_DELAY") + CutinFx.g("impact") + 0.03)
	await _shot("09_cutin_edited_impact")
	CutinFx.load_saved()
	# 목록으로 → 궁극기 카드 불꽃: 실제 분대 카드가 타오르는지, 값을 바꾸면 바로 바뀌는지
	lab.call("_show_picker")
	await _wait(0.2)
	lab.call("_open", "flame")
	await _real(1.2)
	await _shot("10_flame")
	lab.call("_on_value", "top_reach", 45.0)
	lab.call("_on_value", "flame_strength", 2.8)
	lab.call("_on_value", "edge_color_g", 0.25)
	print("[fx_lab] flame describe:\n%s" % CardFlameFx.describe())
	await _real(0.3)
	await _shot("11_flame_edited")
	CardFlameFx.load_saved()
	get_tree().quit(0)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout   # 게임 시간 (히트스탑만큼 같이 늦어진다)


func _real(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout   # 실제 시간 (컷인은 실제 시간으로 돈다)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
	print("[fx_lab] shot ", name)
