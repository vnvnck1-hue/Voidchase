## 궁극기 시전 연출 (고유 스킬에는 쓰지 않는다): 세명이 오리라(TrioChess) scripts/cinematic.gd 를 2D 로 옮긴 것.
##   intro(0.5초) - 전투가 멈추고(트리 일시정지) 레터박스 바(영웅 이름 + 스킬 이름!)가 내려온다. 무대가 어두워지고
##                  시전자만 밝게 남고(주변 딤드) 카메라가 시전자 쪽으로 30% 다가가 살짝 줌인한다.
##                  시전자만 움직인다: 웅크림 → 회전하며 뛰어오름 → 별 스파크·차임 → 착지 펀치 + 바닥 링.
##                  멈춰 있던 전투 이펙트는 숨겨서 궁극기만 눈에 들어오게 한다.
##   release(hold) - 전투가 재개된 뒤에도 hold 초 동안 무대를 어둡게 둔다 → 밝아진다.
## 3D 조명 대신: 어둡게 = 배경·바닥·프랍·다른 유닛 modulate. 시전자 강조 조명(스포트라이트)은 쓰지 않는다 — 딤드만으로 충분히 보인다.
## 시간은 모두 실제 시간(일시정지·배속·슬로모션과 무관).
class_name VDUltCinematic
extends RefCounted

const INTRO_TIME := 0.5
const STAGE_DIM := 0.38       # TrioChess 와 같은 값: 무대가 어두워지는 정도
const DIM_K := 1.4            # 2D 에선 조명 대신 곱셈이라 조금 더 세게 (밝기 1 - 0.38×1.4 ≈ 0.47)
const CAM_FOCUS := 0.3        # 카메라가 시전자 쪽으로 다가가는 비율
const ZOOM_KICK := 1.07       # TrioChess kick_fov(-1.2) 대응: 살짝 줌인
const SuperCutin := preload("res://scripts/void_defense/vd_super_cutin.gd")
## 초궁극기 전면 컷인을 쓰는 영웅 → 컷인 순간 목소리. 컷인 그림(화면 컨셉_2.psd '궁극기 연출')은 마법사 것뿐이다.
const SUPER_CUTIN := {"gunner": "voice_gunner_skill", "mage": "voice_mage_skill", "knight": "voice_knight_skill", "healer": "voice_healer_skill"}

var b: VDBattle
var stage: Node2D             # 일시정지 중에도 도는 무대 (intro 이펙트)
var active := false           # intro 진행 중 (다른 궁극기는 기다린다)
var _dim_users := 0
var _dim := 0.0
var _dim_tw: Tween
var _lit: Array = []          # 무대가 어두워도 밝게 남는 유닛 (시전자)
var _bars: Control
var cast_log: Array[String] = []   # 테스트용: intro 를 연 영웅 id


func _init(battle: VDBattle) -> void:
	b = battle
	stage = Node2D.new()
	stage.name = "UltStage"
	stage.z_index = 45           # 유닛 위, 전투 이펙트(fx_root 50) 아래
	stage.process_mode = Node.PROCESS_MODE_ALWAYS
	b.add_child(stage)


# ---------------------------------------------------------------- 무대 어둡게

func _dim_targets() -> Array:
	var out: Array = [b.bg_rect, b.ambient_motes, b.ambient_motes_front, b.board, b.props.back, b.props.front]
	for u in b.allies + b.enemies:
		if is_instance_valid(u) and not _lit.has(u):
			out.append(u)
	return out


func _set_dim(v: float) -> void:
	_dim = v
	var k := 1.0 - v * DIM_K
	for n in _dim_targets():
		if is_instance_valid(n):
			var c: Color = n.modulate
			n.modulate = Color(k, k, k, c.a)
	for u in _lit:
		if is_instance_valid(u):
			u.modulate = Color(1, 1, 1, u.modulate.a)


func _tween_dim(to: float, dur: float) -> void:
	if _dim_tw and _dim_tw.is_valid():
		_dim_tw.kill()
	_dim_tw = stage.create_tween().set_ignore_time_scale(true)
	_dim_tw.tween_method(_set_dim, _dim, to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- intro / release

## await 가능. release() 에 넘길 핸들을 돌려준다.
func intro(u: VDUnit, ult_name: String, col: Color) -> Dictionary:
	active = true
	_dim_users += 1
	cast_log.append(u.id)
	b.camera.cancel_effects()
	var tree := b.get_tree()
	tree.paused = true
	var old_mode := u.process_mode
	u.process_mode = Node.PROCESS_MODE_ALWAYS
	b.fx_root.visible = false          # 멈춘 전투 이펙트는 숨긴다: 궁극기만 보이게
	# 무대: 시전자만 남기고 어둡게
	_lit.append(u)
	_tween_dim(STAGE_DIM, 0.18)
	# 카메라: 시전자 쪽으로 30% + 살짝 줌인
	var cam := b.camera
	var focus_to := cam.position.lerp(u.position + Vector2(0, u._top * 0.45), CAM_FOCUS)
	var ct := stage.create_tween().set_ignore_time_scale(true).set_parallel(true)
	ct.tween_property(cam, "position", focus_to, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ct.tween_property(cam, "base_zoom", cam.base_zoom * ZOOM_KICK, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 초궁극기: 전면 컷인을 먼저 보여 준다 (스킬 이름은 컷인이 찍으므로 레터박스는 생략)
	if SUPER_CUTIN.has(u.id):
		await super_cutin(ult_name, u.display_name, col, SUPER_CUTIN[u.id], u.id)
		if not is_instance_valid(b) or not b.is_inside_tree():
			active = false
			return {"hero": null}
	else:
		cinema_bars(true, ult_name, u.display_name, col)
	b.audio.play("whoosh", 0.0, 0.0, 0.6)
	# 시전자 포즈: 웅크림 → 회전 점프 → 별 스파크 → 착지
	u._cast_glow = 1.0
	var chest := b._chest(u)
	var pose := u.create_tween().set_ignore_time_scale(true)
	pose.tween_callback(func() -> void: _punch(u, Vector2(1.3, 0.75), 0.25))
	pose.tween_property(u, "pose_lift", 55.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pose.parallel().tween_property(u, "pose_spin", 1.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pose.tween_callback(func() -> void:
		var c2 := Color(col.r * 1.2, col.g * 1.2, col.b * 1.2, 0.8)
		b.vfx.spawn("burst", stage, chest + Vector2(0, -55), 0.55, randf() * TAU, col.lightened(0.3))
		b.vfx.spawn("hit_light", stage, chest + Vector2(0, -55), 1.6, randf() * TAU, c2)
		_star_sparks(chest + Vector2(0, -55), col, 12)
		b.audio.play("chime", 0.0, 1.5, 0.7))
	pose.tween_property(u, "pose_lift", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	pose.tween_callback(func() -> void:
		u.pose_spin = 0.0
		_punch(u, Vector2(1.45, 0.6), 0.4)
		b.vfx.spawn("shockwave", stage, u.position, 0.9, 0.0, Color(col.r * 1.2, col.g * 1.2, col.b * 1.2, 0.8), Vector2(1.0, 0.5)))
	b.vfx.spawn("shockwave", stage, u.position, 0.5, 0.0, Color(col, 0.7), Vector2(1.0, 0.5), false, 0.5)
	await tree.create_timer(INTRO_TIME, true, false, true).timeout
	# 판이 바뀌었거나(재시작) 씬을 떠났으면 아무것도 건드리지 않는다
	if not is_instance_valid(b) or not b.is_inside_tree():
		active = false
		return {"hero": null}
	# 전투 재개 (무대는 어두운 채)
	b.fx_root.visible = true
	if is_instance_valid(u):
		u.process_mode = old_mode
		u.pose_lift = 0.0
		u.pose_spin = 0.0
	b.focus.hold_at(cam.position, cam.base_zoom.x)   # 카메라는 클로즈업 자리에서 전투 포커스로 부드럽게 돌아간다
	cinema_bars(false, "", "", col)
	tree.paused = false
	active = false
	screen_flash(0.12, 0.2)          # TrioChess hud.flash(0.12, 0.2)
	return {"hero": u}


## hold 초 동안 어두운 무대를 유지한다 → 밝아진다.
func release(handle: Dictionary, hold: float) -> void:
	var u: Variant = handle.get("hero")
	var t := 0.0
	var tree := b.get_tree()
	while t < hold:
		await tree.process_frame
		if not is_instance_valid(b) or not b.is_inside_tree():
			return
		if tree.paused:
			continue
		t += minf(tree.root.get_process_delta_time() / maxf(Engine.time_scale, 0.0001), 0.1)
	_lit.erase(u)
	_dim_users = maxi(0, _dim_users - 1)
	if _dim_users == 0:
		_tween_dim(0.0, 0.45)


## 적 특수 스킬용 가벼운 강조: 전투는 멈추지 않고, lit 만 밝게 남긴 채 무대를 dim 만큼 잠깐 어둡게 → hold 초(실제 시간) 뒤 밝아진다.
## 궁극기 무대가 더 어두우면 그쪽을 따른다.
func spotlight(lit: Array, dim: float, hold: float) -> void:
	var added: Array = []
	for u in lit:
		if is_instance_valid(u) and not _lit.has(u):
			_lit.append(u)
			added.append(u)
	_dim_users += 1
	_tween_dim(maxf(dim, _dim), 0.15)
	await b.get_tree().create_timer(hold, true, false, true).timeout
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	for u in added:
		_lit.erase(u)
	if _dim_users == 0:
		return   # 그사이 reset() 됐다
	_dim_users -= 1
	if _dim_users == 0:
		_tween_dim(0.0, 0.35)
	else:
		_set_dim(_dim)   # 남은 연출 중에 풀린 유닛도 어둡게


## 궁극기 조준 화면(VDUltAim)의 딤드: 전투는 이미 멈춰 있고, lit(살아 있는 유닛 전부)만 밝게 두고 무대를 dim 만큼 어둡게.
## on=false 면 lit 을 풀고 밝아진다 (바로 이어지는 intro 가 다시 어둡게 한다).
var _aim_lit: Array = []


func aim_dim(on: bool, lit: Array, dim: float) -> void:
	if on:
		for u in lit:
			if is_instance_valid(u) and not _lit.has(u):
				_lit.append(u)
				_aim_lit.append(u)
		_dim_users += 1
		_tween_dim(maxf(dim, _dim), 0.15)
		return
	if _aim_lit.is_empty() and _dim_users == 0:
		return
	for u in _aim_lit:
		_lit.erase(u)
	_aim_lit.clear()
	_dim_users = maxi(0, _dim_users - 1)
	if _dim_users == 0:
		_tween_dim(0.0, 0.25)
	else:
		_set_dim(_dim)


## 초궁극기 전면 컷인 (await 가능: 띠가 접히면 끝난다). 미리보기(설정 메뉴)도 이걸 부른다.
func super_cutin(ult_name: String, hero_name: String, col: Color, voice := "", hero := "mage") -> void:
	var c := SuperCutin.new()
	b.add_child(c)
	await c.play(ult_name, hero_name, col, b.audio, voice, hero)


## 하드 리셋 (새 판·게임 오버).
func reset() -> void:
	_dim_users = 0
	_lit.clear()
	_aim_lit.clear()
	active = false
	if b.get_tree():
		b.get_tree().paused = false
	b.fx_root.visible = true
	for c in stage.get_children():
		c.queue_free()
	_tween_dim(0.0, 0.3)
	cinema_bars(false, "", "", Color.WHITE)


# ---------------------------------------------------------------- 레터박스 (TrioChess hud.cinema_bars)

func cinema_bars(on: bool, ult_name: String, hero_name: String, col: Color) -> void:
	if not on:
		if _bars and is_instance_valid(_bars):
			var bars := _bars
			_bars = null
			var tw := bars.create_tween().set_parallel(true).set_ignore_time_scale(true)
			tw.tween_property(bars.get_child(0), "position:y", -130.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(bars.get_child(1), "offset_top", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(bars, "modulate:a", 0.0, 0.25)
			tw.chain().tween_callback(bars.queue_free)
		return
	if _bars and is_instance_valid(_bars):
		_bars.queue_free()
	_bars = Control.new()
	_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.process_mode = Node.PROCESS_MODE_ALWAYS
	_bars.z_index = 80
	b.hud_root.add_child(_bars)
	var top := ColorRect.new()
	top.color = Color(0.03, 0.02, 0.06, 0.55)
	top.anchor_right = 1.0
	top.offset_bottom = 120
	top.position.y = -130
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.add_child(top)
	var bot := ColorRect.new()
	bot.color = Color(0.03, 0.02, 0.06, 0.55)
	bot.anchor_top = 1.0
	bot.anchor_right = 1.0
	bot.anchor_bottom = 1.0
	bot.offset_top = 0
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.add_child(bot)
	var tw2 := _bars.create_tween().set_parallel(true).set_ignore_time_scale(true)
	tw2.tween_property(top, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(bot, "offset_top", -36.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var hn := _label(hero_name, 26, col.lightened(0.6), 8)
	top.add_child(hn)
	hn.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hn.offset_top = 6
	hn.offset_bottom = 40
	var nm := _label(ult_name + "!", 50, col.lightened(0.45), 14)
	top.add_child(nm)
	nm.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	nm.offset_top = 36
	nm.offset_bottom = 116
	nm.pivot_offset = Vector2(b.get_viewport_rect().size.x * 0.5, 45)
	nm.scale = Vector2(1.5, 1.5)
	nm.modulate.a = 0.0
	var tw3 := nm.create_tween().set_parallel(true).set_ignore_time_scale(true)
	tw3.tween_property(nm, "scale", Vector2.ONE, 0.3).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw3.tween_property(nm, "modulate:a", 1.0, 0.12).set_delay(0.08)


func _label(text: String, size: int, col: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", VDData.font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.1))
	l.add_theme_constant_override("outline_size", outline)
	return l


## 화면 전체 흰 섬광 (TrioChess hud.flash).
func screen_flash(alpha: float, dur: float) -> void:
	var f := ColorRect.new()
	f.color = Color(1, 1, 1, alpha)
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.z_index = 85
	b.hud_root.add_child(f)
	var tw := f.create_tween().set_ignore_time_scale(true)
	tw.tween_property(f, "color:a", 0.0, dur)
	tw.tween_callback(f.queue_free)


# ---------------------------------------------------------------- 연출 조각

## 찌그러졌다 튕기며 돌아오는 펀치 (TrioChess model.punch_scale).
func _punch(u: VDUnit, sc: Vector2, dur: float) -> void:
	if not is_instance_valid(u):
		return
	u.scale = sc
	var tw := u.create_tween().set_ignore_time_scale(true)
	tw.tween_property(u, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## 별 모양 스파크가 사방으로 튀었다가 아래로 떨어지며 사라진다 (TrioChess Vfx.sparks "star5").
func _star_sparks(at: Vector2, col: Color, n: int) -> void:
	for i in n:
		var s := Polygon2D.new()
		var pts := PackedVector2Array()
		var r := randf_range(7.0, 12.0)
		for k in 10:
			var a := TAU * k / 10.0 - PI * 0.5
			var rr := r if k % 2 == 0 else r * 0.45
			pts.append(Vector2(cos(a), sin(a)) * rr)
		s.polygon = pts
		s.color = col.lightened(randf_range(0.2, 0.6))
		s.position = at
		stage.add_child(s)
		var dir := Vector2.from_angle(randf() * TAU) * randf_range(70.0, 150.0)
		var tw := s.create_tween().set_ignore_time_scale(true).set_parallel(true)
		tw.tween_property(s, "position", at + dir + Vector2(0, 40), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "rotation", randf_range(-3.0, 3.0), 0.5)
		tw.tween_property(s, "scale", Vector2.ONE * 0.2, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(s.queue_free)
