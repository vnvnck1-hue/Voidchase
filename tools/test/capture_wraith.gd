## 공허 망령(파츠 + 본 리그) 자세 시트: 아이들 2장 · 걷기 · 예비 · 공격 · 피격 · 기절 · 사망을 한 장에 찍는다.
## VDWraithAnim 값을 고칠 때 확인하는 용도. 아래 줄은 크게 본 아이들·반대쪽을 보는 모습·크기 비교(수정게·결정체·잔재).
## --seq: 실제 시간으로 아이들 → 예비 → 공격 → 피격 → 기절을 돌리며 12 프레임을 한 장에 이어 붙인다 (움직임이 이어지는지 확인).
## --smoke: 창 없이(--headless) 예비 → 공격 → 피격 → 기절 → 사망을 실제 시간으로 돌려 스크립트 오류만 확인한다.
##   godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/WraithCapture.tscn -- --out=D:/shots/wraith.png
extends Node2D

const POSES := ["idle", "idle2", "walk", "wind", "strike", "hurt", "stun", "death"]

var out_path := "user://wraith_poses.png"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
		elif a == "--smoke":
			_smoke()
			return
	if OS.get_cmdline_user_args().has("--seq"):
		_seq()
		return
	var root := Node2D.new()
	root.scale = Vector2.ONE * (get_viewport_rect().size.x / 1280.0)   # 창 크기와 상관없이 시트가 화면을 채우게
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.17, 0.3)
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var units := []
	for c in POSES.size():
		var l := Label.new()
		l.text = POSES[c]
		l.position = Vector2(40 + c * 158, 6)
		l.add_theme_font_size_override("font_size", 20)
		root.add_child(l)
		units.append(_unit("wraith", Vector2(84 + c * 158, 230), root))
	var big := _unit("wraith", Vector2(280, 690), root)
	big.scale = Vector2(2.5, 2.5)
	var faced := _unit("wraith", Vector2(760, 680), root)
	faced.scale = Vector2(1.5, 1.5)
	faced.face(1.0)
	_unit("crab", Vector2(960, 680), root)
	_unit("tank", Vector2(1090, 680), root)
	_unit("normal", Vector2(1200, 680), root)
	await get_tree().process_frame
	big._parts.update(0.0, 0.3, 0.0, 0.0, 0.0, 0.0, false)
	faced._parts.update(0.0, 1.5, 0.0, 0.0, 0.0, 0.0, false)
	for c in POSES.size():
		var u: VDUnit = units[c]
		var p: VDPartsAnim = u._parts
		match POSES[c]:
			"idle": p.update(0.0, 0.65, 0.0, 0.0, 0.0, 0.0, false)
			"idle2": p.update(0.0, 1.95, 0.0, 0.0, 0.0, 0.0, false)
			"walk": p.update(0.0, 0.0, 0.0, 0.0, 1.0, PI * 0.5, false)
			"wind": p.update(0.0, 0.0, 0.0, 1.0, 0.0, 0.0, false)
			"strike":
				p.strike()
				p.update(0.1, 0.0, 0.0, 0.0, 0.0, 0.0, false)
			"hurt":
				p.hurt(1.0)
				p.update(0.04, 0.0, 0.0, 0.0, 0.0, 0.0, false)
			"stun":
				p.update(1.0, 0.0, 0.0, 0.0, 0.0, 0.0, true)
			"death": p.scatter(u)
	await get_tree().create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_path)
	print("[wraith] saved " + out_path)
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
	u.setup(VDData.ENEMIES["wraith"], "wraith", 1, Vector2i.ZERO)
	add_child(u)
	var p := u._parts as VDWraithAnim
	assert(p != null and p._parts.size() == 8 and p._chains.size() == 3 and p._hood != null)
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
	u.revive_full()
	u.take_damage(9999.0)
	await get_tree().create_timer(0.8).timeout
	print("[wraith] smoke ok alive=%s top=%.1f bones=%d" % [u.alive, u._top, p._chains["t3"].size()])
	get_tree().quit()


func _seq() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.17, 0.3)
	bg.size = get_viewport_rect().size
	add_child(bg)
	var u := VDUnit.new()
	u.setup(VDData.ENEMIES["wraith"], "wraith", 1, Vector2i.ZERO)
	# attack_anim 이 유닛을 제 칸 자리·배율 1 로 되돌리므로, 확대와 위치는 부모 노드로 준다
	var holder := Node2D.new()
	holder.scale = Vector2(2.6, 2.6)
	add_child(holder)
	u.position = u.foot_at(u.cell)
	holder.position = Vector2(300, 440) - u.position * 2.6
	holder.add_child(u)
	var to := u.position + Vector2(-200, 0)
	# [시각(초), 그때 할 일]
	var shots := [[0.3, ""], [0.9, ""], [1.5, "wind"], [1.7, ""], [1.84, "strike"], [1.9, ""], [1.98, ""], [2.15, ""],
		[2.5, "hurt"], [2.56, ""], [2.75, ""], [3.3, "stun"], [3.9, ""]]
	var cell := Vector2i(600, 520)
	var sheet := Image.create(cell.x * 4, cell.y * 3, false, Image.FORMAT_RGBA8)
	var t0 := Time.get_ticks_msec()
	var n := 0
	for s in shots:
		while (Time.get_ticks_msec() - t0) / 1000.0 < float(s[0]):
			await get_tree().process_frame
		match s[1]:
			"wind": u.windup(to, 0.34)
			"strike":
				u.release_windup()
				u.attack_anim(to)
			"hurt": u.take_damage(30.0)
			"stun": u.stun(1.0, false)
		if s[1] == "wind" or s[1] == "strike" or s[1] == "hurt" or s[1] == "stun":
			continue
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, cell.x, cell.y), Vector2i((n % 4) * cell.x, (n / 4) * cell.y))
		n += 1
	sheet.save_png(out_path)
	print("[wraith] saved seq %d frames" % n)
	get_tree().quit()
