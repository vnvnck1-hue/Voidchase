## 적 차원 소환 연출(낙하 → 꽂힘 → 늘어남 → 출렁임)을 느린 배속으로 프레임별 캡처한다.
## 첫 적 주변을 잘라 docs/void_defense_summon/f_XX.png 로 저장. 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/VDSummonCapture.tscn
extends Node

const OUT := "res://docs/void_defense_summon/"
const SLOW := 0.3
const SHOTS := 40
const CROP := Vector2i(260, 340)

var _b: VDBattle


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(_b)
	while _b.enemies.is_empty():
		await get_tree().process_frame
	var e: VDUnit = _b.enemies[0]
	Engine.time_scale = SLOW
	var vp := get_viewport()
	var t0 := Time.get_ticks_msec()
	for i in SHOTS:
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		# 화면 좌표 → 뷰포트 이미지 좌표 (창 스트레치 배율 보정)
		var foot: Vector2 = (e.get_parent() as Node2D).get_global_transform_with_canvas() * VDData.to_screen(Vector2(e.cell))
		foot *= Vector2(img.get_size()) / vp.get_visible_rect().size
		var r := Rect2i(Vector2i(foot) - Vector2i(CROP.x / 2, CROP.y - 60), CROP)
		r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img.get_region(r).save_png(OUT + "f_%02d.png" % i)
		if i == 8:
			img.save_png(OUT + "full_08.png")
		print("[summon] f_%02d  t=%dms  scale=%s  foot=%s  img=%s" % [i, Time.get_ticks_msec() - t0, e.scale, foot, img.get_size()])
		# 화면 프레임 4장마다 한 장
		for k in 3:
			await get_tree().process_frame
	Engine.time_scale = 1.0
	get_tree().quit(0)
