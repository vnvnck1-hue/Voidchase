## 잉걸불 궤적 불꽃 모양 확인: 빈 화면에 같은 곡선으로 여러 발을 쏘고 비행 비율별로 멈춰 한 장에 찍는다.
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/ProbeFlameTrail.tscn
## 출력: docs/fx_lab/flame_trail_probe.png
extends Node2D

const P := preload("res://scripts/void_defense/relics/vd_relic_proj_fx.gd")
const STOPS := [0.3, 0.55, 0.8, 1.15]   # 비행 시간 비율


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.16, 0.12, 0.22))
	P.reset()
	P.set_value("size_k", 1.0)
	Engine.time_scale = 0.1   # 첫 프레임 끊김에 멈춤 비율이 밀리지 않게
	var fl := P.timing("comet").x
	var fxs := []
	for i in STOPS.size():
		var y := 60.0 + i * 170.0
		var fx := VDRelicFx.comet(self, Vector2(60, y), Vector2(1180, y + 60), Color.ORANGE)
		fx.ctrl = Vector2(620, y - 90)
		for rb in fx._ribbons:
			rb["ctrl"] = fx.ctrl   # 꼬리 띠도 같은 곡선
		fxs.append(fx)
	var t := 0.0
	var done := 0
	while done < fxs.size():
		await get_tree().process_frame
		t += get_process_delta_time()   # 이미 time_scale 이 곱해진 값
		for i in fxs.size():
			if fxs[i] != null and fxs[i].is_processing() and t >= STOPS[i] * fl:
				fxs[i].set_process(false)   # 이 비율에서 멈춤 (셰이더 결은 TIME 으로 계속 흐른다)
				done += 1
	await get_tree().create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/fx_lab/flame_trail_probe.png")
	print("[flame_probe] done")
	get_tree().quit(0)
