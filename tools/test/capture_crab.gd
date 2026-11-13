## 공허 수정게(파츠 몬스터) 자세 시트: 아이들 2장 · 걷기 · 예비 · 공격 · 피격 · 기절 · 사망을 한 장에 찍는다.
## VDPartsAnim 값을 고칠 때 확인하는 용도. 아래 줄은 크게 본 아이들과 공허 결정체(크기 비교).
## --smoke: 창 없이(--headless) 예비 → 공격 → 피격 → 기절 → 사망을 실제 시간으로 돌려 스크립트 오류만 확인한다.
##   godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/CrabCapture.tscn -- --out=D:/shots/crab.png
extends Node2D

const POSES := ["idle", "idle2", "walk", "wind", "strike", "hurt", "stun", "death"]

var out_path := "user://crab_poses.png"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
		elif a == "--smoke":
			_smoke()
			return
	var root := Node2D.new()
	root.scale = Vector2(1.5, 1.5)
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.17, 0.3)
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var units := []
	for c in POSES.size():
		var l := Label.new()
		l.text = POSES[c]
		l.position = Vector2(60 + c * 150, 6)
		l.add_theme_font_size_override("font_size", 20)
		root.add_child(l)
		var u := _unit("crab", Vector2(110 + c * 150, 190), root)
		units.append(u)
	var big := _unit("crab", Vector2(330, 610), root)
	big.scale = Vector2(2.2, 2.2)
	var faced := _unit("crab", Vector2(760, 560), root)
	faced.scale = Vector2(1.5, 1.5)
	faced.face(1.0)
	_unit("tank", Vector2(1010, 560), root)
	_unit("normal", Vector2(1150, 560), root)
	await get_tree().process_frame
	for u in [big, faced]:
		u._parts.update(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false)
	for c in POSES.size():
		var u: VDUnit = units[c]
		var p: VDPartsAnim = u._parts
		match POSES[c]:
			"idle": p.update(0.0, 0.6, 0.0, 0.0, 0.0, 0.0, false)
			"idle2": p.update(0.0, 1.8, 0.0, 0.0, 0.0, 0.0, false)
			"walk": p.update(0.0, 0.0, 0.0, 0.0, 1.0, PI * 0.5, false)
			"wind": p.update(0.0, 0.0, 0.0, 1.0, 0.0, 0.0, false)
			"strike":
				p.strike()
				p.update(0.08, 0.0, 0.0, 0.0, 0.0, 0.0, false)
			"hurt":
				p.hurt(1.0)
				p.update(0.03, 0.0, 0.0, 0.0, 0.0, 0.0, false)
			"stun":
				p.update(1.0, 0.0, 0.0, 0.0, 0.0, 0.0, true)
			"death": p.scatter(u)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_path)
	print("[crab] saved " + out_path)
	get_tree().quit()


func _unit(id: String, at: Vector2, root: Node2D) -> VDUnit:
	var u := VDUnit.new()
	u.setup(VDData.ENEMIES[id], id, 1, Vector2i.ZERO)
	u.position = at
	root.add_child(u)
	u.set_process(false)
	return u


func _smoke() -> void:
	var u := VDUnit.new()
	u.setup(VDData.ENEMIES["crab"], "crab", 1, Vector2i.ZERO)
	add_child(u)
	assert(u._parts != null and u._parts._parts.size() == 5)
	var to := Vector2(-100, 0)
	await get_tree().create_timer(0.2).timeout
	u.windup(to, 0.3)
	await get_tree().create_timer(0.3).timeout
	u.release_windup()
	u.attack_anim(to)
	await get_tree().create_timer(0.3).timeout
	u.take_damage(30.0, "번개")
	await get_tree().create_timer(0.2).timeout
	u.stun(0.3, true)
	u.moving = true
	await get_tree().create_timer(0.3).timeout
	u.moving = false
	u.take_damage(9999.0)
	await get_tree().create_timer(0.8).timeout
	print("[crab] smoke ok alive=%s top=%.1f" % [u.alive, u._top])
	get_tree().quit()
