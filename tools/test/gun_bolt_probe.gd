## 건너 에너지 볼트 모양 확인: 레퍼런스와 같은 어두운 바탕에 큰 볼트 한 발 + 게임 크기 볼트 여러 방향 + 발사 직후(짧은 꼬리).
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/GunBoltProbe.tscn
## 출력: docs/gun_bolt/probe.png (+ probe_b.png: 0.25초 뒤, 결이 흐르는지 비교용)
extends Node2D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.18, 0.23, 0.27))
	# 큰 볼트 (레퍼런스 구도)
	VDGunBolt.fire(self, Vector2(100, 300), Vector2(1840, 300), 0.14, 8.0).freeze()
	# 게임 크기: 여러 방향
	var c := Vector2(420, 800)
	for i in 6:
		var d := Vector2.from_angle(TAU * i / 6.0 + 0.2)
		VDGunBolt.fire(self, c, c + d * 240.0).freeze()
	# 게임 크기 2배 가로 + 꼬리 길이 단계
	for i in 4:
		var y := 640.0 + i * 110.0
		VDGunBolt.fire(self, Vector2(900, y), Vector2(1800, y), 0.14, 2.0).freeze([0.3, 0.55, 0.8, 1.0][i])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/gun_bolt"))
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/gun_bolt/probe.png")
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/gun_bolt/probe_b.png")
	print("[gun_bolt_probe] done")
	get_tree().quit(0)
