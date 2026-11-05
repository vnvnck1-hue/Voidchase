## 로비(연출 연구실 카드)와 연출 연구실 화면을 캡처한다. 연구실에서 값 하나를 바꿔 다시 재생되는지도 본다.
## 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/FxLabCapture.tscn
## 출력: docs/fx_lab/*.png
extends Node

const OUT := "res://docs/fx_lab/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var lobby: Node = load("res://scenes/Lobby.tscn").instantiate()
	add_child(lobby)
	await _wait(0.5)
	await _shot("01_lobby")
	lobby.queue_free()
	var lab: Node = load("res://scenes/void_defense/FxLab.tscn").instantiate()
	add_child(lab)
	# 첫 재생: 꽂힌 직후 · 튕김 · 안착 후
	await _wait(VDSummonFx.g("drop_sec") + 0.02)
	await _shot("02_lab_land")
	await _wait(0.1)
	await _shot("03_lab_stretch")
	await _wait(0.8)
	await _shot("04_lab_settled")
	# 값 바꾸기 → 손 뗀 뒤 다시 재생되는지
	lab.call("_on_value", "squash_x", 3.0)
	lab.call("_on_value", "squash_y", 0.15)
	print("[fx_lab] dirty=%s describe:\n%s" % [lab.get("_dirty"), VDSummonFx.describe()])
	await _wait(lab.get("EDIT_DELAY") + VDSummonFx.g("drop_sec") + 0.03)
	await _shot("05_lab_edited_land")
	VDSummonFx.load_saved()   # 테스트 값은 저장하지 않고 버린다
	get_tree().quit(0)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout   # 게임 시간 (히트스탑만큼 같이 늦어진다)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
	print("[fx_lab] shot ", name)
