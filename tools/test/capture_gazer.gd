## 공허 응시자(첫 보스: 파츠 + 본 리그 + 눈 14개) 애니메이션 확인.
## VDGazerAnim.update 를 정해진 간격으로 직접 돌려(실시간이 아니라 결정적) 프레임을 한 장에 이어 붙인다.
##   --sheet=idle    아이들 2.4초를 12장 (날갯짓 한 바퀴 + 눈 훑어보기·움찔·깜빡임)
##   --sheet=combat  이동 · 예비 · 공격 3장 · 피격 3장 · 기절 2장 · 사망 2장
##   --sheet=parry   패링 예비 2초(6장) · 멈칫 · 돌진 · 충돌 3장 · 기절
##   --smoke         창 없이(--headless) 유닛으로 예비 → 공격 → 피격 → 기절 → 패링 예비 → 돌진 → 사망을 돌려 스크립트 오류만 확인
##   godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/GazerCapture.tscn -- --sheet=idle --out=D:/shots/gazer_idle.png
extends Node2D

const CELL := Vector2i(640, 480)
const DT := 1.0 / 60.0

var out_path := "user://gazer.png"
var _u: VDUnit
var _p: VDGazerAnim
var _t := 0.0
var _wind := 0.0
var _walk := 0.0
var _stun := false


func _ready() -> void:
	var sheet := "idle"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
		elif a.begins_with("--sheet="):
			sheet = a.substr(8)
		elif a == "--smoke":
			_smoke()
			return
	seed(7)
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.17, 0.3)
	bg.size = get_viewport_rect().size
	add_child(bg)
	_u = VDUnit.new()
	_u.setup(VDData.ENEMIES["gazer"], "gazer", 1, Vector2i.ZERO)
	var holder := Node2D.new()
	holder.scale = Vector2(1.15, 1.15)
	holder.position = Vector2(300, 468)
	add_child(holder)
	_u.position = Vector2.ZERO
	holder.add_child(_u)
	_u.set_process(false)
	_p = _u._parts as VDGazerAnim
	_p.aim(Vector2(-300, 40), 0.0)
	# [앞으로 돌릴 시간(초), 그 전에 할 일, 라벨]
	var plan: Array = []
	match sheet:
		"idle":
			for i in 12:
				plan.append([0.2, "", "idle %.1fs" % (0.2 * (i + 1))])
		"combat":
			plan = [[0.6, "walk", "move"], [0.3, "wind", "windup"], [0.03, "strike", "strike +0.03"], [0.07, "", "strike +0.10"], [0.14, "", "strike +0.24"],
				[0.5, "", "idle"], [0.03, "hurt", "hurt +0.03"], [0.08, "", "hurt +0.11"], [0.2, "", "hurt +0.31"],
				[0.5, "stun", "stun"], [0.4, "", "stun +0.4"], [0.2, "death", "death"]]
		"parry":
			plan = [[0.2, "pw", "telegraph 0.2s"], [0.4, "", "0.6s"], [0.4, "", "1.0s"], [0.4, "", "1.4s"], [0.35, "", "1.75s"], [0.22, "", "1.97s (coil)"],
				[0.05, "ram", "ram +0.05"], [0.08, "", "ram +0.13"], [0.02, "impact", "impact +0.02"], [0.08, "", "impact +0.10"],
				[0.25, "ramend", "recover"], [0.5, "stun", "stunned"]]
	var img_sheet := Image.create(CELL.x * 4, CELL.y * 3, false, Image.FORMAT_RGBA8)
	var label := Label.new()
	label.position = Vector2(14, 8)
	label.add_theme_font_size_override("font_size", 26)
	add_child(label)
	_run(0.5)
	for i in plan.size():
		var s: Array = plan[i]
		match s[1]:
			"walk": _walk = 1.0
			"wind":
				_walk = 0.0
				_wind = 1.0
				_p.aim(Vector2(-300, 40), 1.0)
			"strike":
				_wind = 0.0
				_p.strike()
				_p.aim(Vector2(-300, 40), 0.5)
			"hurt": _p.hurt(1.0)
			"stun": _stun = true
			"death": _p.scatter(_u)
			"pw":
				_p.parry_windup(2.0)
				_p.aim(Vector2(-320, 60), 3.0)
			"ram": _p.ram_start(8.0)
			"impact": _p.ram_impact()
			"ramend": _p.ram_end()
		_run(float(s[0]))
		label.text = String(s[2])
		if s[1] == "death":
			await get_tree().create_timer(float(s[0])).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img_sheet.blit_rect(img, Rect2i(0, 0, CELL.x, CELL.y), Vector2i((i % 4) * CELL.x, (i / 4) * CELL.y))
	img_sheet.save_png(out_path)
	print("[gazer] saved %s (%d frames)" % [out_path, plan.size()])
	get_tree().quit()


func _run(sec: float) -> void:
	var n := maxi(1, roundi(sec / DT))
	for i in n:
		_t += DT
		_p.update(DT, _t, 0.0, _wind, _walk, _t * 6.0, _stun)


func _smoke() -> void:
	var u := VDUnit.new()
	u.setup(VDData.ENEMIES["gazer"], "gazer", 1, Vector2i.ZERO)
	add_child(u)
	var p := u._parts as VDGazerAnim
	assert(p != null and p._eyes.size() == 14 and p._bones.size() == 21)
	var to := Vector2(-200, 0)
	await get_tree().create_timer(0.3).timeout
	u.windup(to, 0.3)
	await get_tree().create_timer(0.3).timeout
	u.release_windup()
	u.attack_anim(to)
	await get_tree().create_timer(0.3).timeout
	u.take_damage(30.0, "번개")
	await get_tree().create_timer(0.2).timeout
	u.stun(0.3, false)
	await get_tree().create_timer(0.4).timeout
	p.parry_windup(0.4)
	await get_tree().create_timer(0.45).timeout
	p.ram_start(10.0)
	await get_tree().create_timer(0.15).timeout
	p.ram_impact()
	await get_tree().create_timer(0.2).timeout
	p.ram_end()
	u.revive_full()
	u.take_damage(99999.0)
	await get_tree().create_timer(0.8).timeout
	print("[gazer] smoke ok alive=%s top=%.1f eyes=%d bones=%d horn=%s" % [u.alive, u._top, p._eyes.size(), p._bones.size(), p.horn_offset()])
	get_tree().quit()
