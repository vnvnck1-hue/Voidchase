## 연출 연구실 "유물 투사체" → 잉걸불(comet) 한 발을 쏘고 비행·착탄·소멸을 순서대로 캡처한다 (flame 셰이더 불덩이 확인용).
## 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/RelicCometCapture.tscn
## 출력: docs/fx_lab/relic_comet_*.png
extends Node

const OUT := "res://docs/fx_lab/"
const RelicProjFx := preload("res://scripts/void_defense/relics/vd_relic_proj_fx.gd")
const SHOTS := [0.2, 0.45, 0.7, 0.9, 1.05, 1.3, 1.6]   # 비행 시간 비율 (1 = 착탄)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var lab: Node = load("res://scenes/void_defense/FxLab.tscn").instantiate()
	add_child(lab)
	await _wait(0.3)
	lab.call("_open", "relic")   # 저장된 연구실 값(user://relic_proj_fx.json) 그대로 — 실제 전투와 같은 값
	lab.set("_auto", false)
	await _wait(1.0)
	# 대상 드롭다운에서 잉걸불을 고른 것처럼 (패널을 다시 짓고 바로 한 발 쏜다)
	var ci := RelicProjFx.KINDS.find("comet")
	for opt in lab.find_children("*", "OptionButton", true, false):
		if opt.item_count == RelicProjFx.KINDS.size():
			opt.select(ci)
			opt.item_selected.emit(ci)
			break
	Engine.time_scale = 0.2   # 0.15초 비행도 여러 장 잡히게 (타이머·연출 모두 게임 시간)
	var fl := RelicProjFx.timing("comet").x
	var t0 := 0.0
	for s in SHOTS:
		await _wait((s - t0) * fl)
		t0 = s
		await _shot("relic_comet_%03d" % int(round(s * 100.0)))
	# 조절 패널 맨 아래 (색 줄: 컬러 피커)
	Engine.time_scale = 1.0
	for sc in lab.find_children("*", "ScrollContainer", true, false):
		sc.scroll_vertical = 100000
	await _wait(0.2)
	await _shot("relic_comet_panel")
	print("[relic_comet] done")
	get_tree().quit(0)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
