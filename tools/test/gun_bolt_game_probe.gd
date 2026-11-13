## 건너 에너지 볼트를 실제 전투 화면 크기로 확인: VFX 쇼룸 크게 보기로 건너 평타·스킬·궁극기를 돌리며 찍는다.
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/GunBoltGameProbe.tscn
## 출력: docs/gun_bolt/slow_<id>_<n>.png  느리게(0.12배) 돌린 장면
##       docs/gun_bolt/real_<id>_<nnn>.png 실제 속도(1배)의 연속 프레임 (프레임마다 메모리에 잡아 두고 끝난 뒤 저장 → 속도가 밀리지 않는다)
## (헤드리스로 돌리면 캡처 없이 오류만 본다)
extends Node

const OUT := "res://docs/gun_bolt/"
const IDS := ["gunner_shot", "skill_gunner", "ult_gunner"]
const SLOW_SHOTS := 7
const REAL_FRAMES := 130


func _ready() -> void:
	var headless := DisplayServer.get_name() == "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var room: Control = load("res://scenes/void_defense/VfxShowroom.tscn").instantiate()
	add_child(room)
	await _wait(1.0)
	var list: Array = room._entries_of("전체")
	for id in IDS:
		var idx := -1
		for i in list.size():
			if list[i]["id"] == id:
				idx = i
		if idx < 0:
			print("[gun_bolt_game] missing ", id)
			continue
		# --- 실제 속도 연속 프레임
		room._open_focus(list, idx)
		await _wait(0.25)
		var frames: Array[Image] = []
		var dts := PackedFloat32Array()
		for n in REAL_FRAMES:
			await RenderingServer.frame_post_draw
			dts.append(get_process_delta_time())
			if not headless:
				frames.append(get_viewport().get_texture().get_image())
		for n in frames.size():
			frames[n].save_png("%sreal_%s_%03d.png" % [OUT, id, n])
		var sum := 0.0
		for d in dts:
			sum += d
		print("[gun_bolt_game] real %s frames=%d avg_dt=%.4f" % [id, dts.size(), sum / dts.size()])
		room._close_focus()
		await _wait(0.3)
		# --- 느리게
		room._open_focus(list, idx)
		await _wait(0.5)
		Engine.time_scale = 0.12
		for n in SLOW_SHOTS:
			await _wait(0.33)
			if not headless:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%sslow_%s_%d.png" % [OUT, id, n])
		Engine.time_scale = 1.0
		room._close_focus()
		await _wait(0.3)
		print("[gun_bolt_game] ok ", id)
	print("[gun_bolt_game] done")
	get_tree().quit(0)


func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await get_tree().process_frame
