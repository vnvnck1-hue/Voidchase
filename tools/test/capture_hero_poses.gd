## 영웅 파츠 자세 시트: 영웅 4명(행) × idle/wind/strike/cast/hurt(열)를 가중치 1 로 고정해 한 장에 찍는다.
## VDHeroPose.POSES 값을 고칠 때 원화에서 어떻게 보이는지 확인하는 용도.
##   godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/HeroPoses.tscn -- --out=D:/shots/poses.png
extends Node2D

const HEROES := ["knight", "gunner", "mage", "healer"]
const POSES := ["", "wind", "strike", "cast", "hurt"]

var out_path := "user://hero_poses.png"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
	# 프로젝트 화면 늘이기 때문에 1280x720 캡처에서 2/3 크기로 그려지므로 1.5 배로 키운다
	var root := Node2D.new()
	root.scale = Vector2(1.5, 1.5)
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.12, 0.24)
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	for c in POSES.size():
		var l := Label.new()
		l.text = POSES[c] if POSES[c] != "" else "idle"
		l.position = Vector2(110 + c * 160, 4)
		l.add_theme_font_size_override("font_size", 22)
		root.add_child(l)
	var units := []
	for r in HEROES.size():
		for c in POSES.size():
			var u := VDUnit.new()
			u.setup(VDData.HEROES[HEROES[r]], HEROES[r], 0, Vector2i.ZERO)
			u.position = Vector2(90 + c * 160, 130 + r * 112)
			root.add_child(u)
			u.set_process(false)   # 아이들 시간을 멈춘다: 자세만 비교
			if POSES[c] != "":
				u.set("_p_" + POSES[c], 1.0)
			units.append(u)
	await get_tree().process_frame
	for u in units:
		u._animate_idle()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_path)
	print("[poses] saved " + out_path)
	get_tree().quit()
