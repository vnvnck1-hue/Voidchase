## 공허 정수 3D 아이콘 캡처: 결정 렌더 단독(회전 여러 각도) + 전장 HUD·바닥 결정 화면.
## 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/EssenceGemCapture.tscn -- --out=<폴더>
extends Node

var _out := "user://essence_gem"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	await get_tree().create_timer(1.5).timeout
	var c := VDData.to_screen(VDMap.center_f(b.room))
	for i in 4:
		b.essence_drops.spawn(c + Vector2(-120 + i * 80, 30), -80.0, 10)
	await get_tree().create_timer(1.0).timeout
	var vp := b.get_node("EssenceGem3D") as SubViewport
	for i in 4:
		vp.get_texture().get_image().save_png(_out.path_join("gem_%d.png" % i))
		await get_tree().create_timer(0.2).timeout
	get_viewport().get_texture().get_image().save_png(_out.path_join("screen.png"))
	print("[gem] saved to %s" % _out)
	get_tree().quit(0)
