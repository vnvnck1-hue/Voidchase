## 궁극기 준비 카드 불꽃(card_ult_flame) 캡처: 전투가 붙으면 건너·기사 궁극기 게이지를 채우고 카드 쪽을 시간차로 몇 장 찍는다.
##   godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/UltFlameCapture.tscn -- --out=D:/shots
extends Node

var out_dir := "user://ult_flame"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	await get_tree().create_timer(1.0).timeout
	b.start_battle()
	while b.state != VDBattle.State.BATTLE:
		await get_tree().process_frame
	for e in b.enemies:   # 찍는 동안 전투가 끝나지 않게
		e.max_hp *= 30.0
		e.hp = e.max_hp
	for a in b.allies:
		if a.id in ["gunner", "knight"]:
			a.gain_ult(VDData.MAX_ULT)
	for i in 4:
		await get_tree().create_timer(0.12 if i == 0 else 0.45).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("flame_%d.png" % i))
	print("[ult-flame] saved " + out_dir)
	get_tree().quit()
