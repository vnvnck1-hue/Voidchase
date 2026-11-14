## HP 바 · 피해 숫자 캡처: 전투 연습장(자동 전투, 영웅 넷)을 열고 싸우는 동안 몇 장 찍는다.
##   HP 바가 유닛·이펙트·앞 안개에 가리지 않는지, 피해 숫자가 HP 바 위에서 나오는지, 글자 크기(60%)를 눈으로 본다.
##   창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/VDBarCapture.tscn -- --out=DIR
extends Node

var out_dir := "res://docs/fx_lab/bars"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir) if out_dir.begins_with("res://") else out_dir)
	VDBattle.sandbox_request = VDData.HERO_ORDER.duplicate()
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	var t := 0.0
	while b.state != VDBattle.State.BATTLE and t < 10.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	_check(VDUnit.top_root != null and b.allies[0]._overlay.get_parent() == b.world_top, "hp bars live in the top layer")
	# 영웅이 다가가 맞붙을 때까지 기다렸다가 짧은 간격으로
	await get_tree().create_timer(5.0, true, false, true).timeout
	for i in 8:
		await get_tree().create_timer(0.45, true, false, true).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png((ProjectSettings.globalize_path(out_dir) if out_dir.begins_with("res://") else out_dir).path_join("bars_%d.png" % i))
	print("[bar-capture] DONE")
	get_tree().quit()


func _check(ok: bool, what: String) -> void:
	print("[bar-capture] %s: %s" % ["ok" if ok else "FAIL", what])
