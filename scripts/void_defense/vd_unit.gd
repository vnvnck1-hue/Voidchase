## 그레이박스 유닛: 원화 조립 씬의 캐릭터·몬스터(VDRig) + 이름 + HP 바. 아군/적 공용.
## 원화가 없는 id 는 예전 색 박스로 그린다.
## position 은 발(셀 중심) 기준이라 units_root 의 y_sort 가 그대로 깊이 정렬이 된다.
class_name VDUnit
extends Node2D

signal died(unit: VDUnit)

var id := ""
var display_name := ""
var team := 0                # 0 아군, 1 적
var cell := Vector2i.ZERO
var home_cell := Vector2i.ZERO
var max_hp := 100.0
var hp := 100.0
var atk := 10.0
var attack_range := 1
var atk_cd := 1.0
var move_cd := 1.0
var move_sec := 0.25
var armor := 0.0
var atk_timer := 0.0
var move_timer := 0.0
var is_boss := false
var is_healer := false
var essence := 0
var color := Color.WHITE
var moving := false

# 액티브 스킬 (아군만 mana_gain > 0)
var mana := 0.0
var mana_gain := 0.0         # 기본 공격 한 번에 차는 마나
var casting := false         # 스킬 연출 중: 이동·공격을 쉰다
var stun_timer := 0.0        # > 0 이면 행동 불가 (기절·빙결)
var frozen := false          # 기절이 빙결이면 얼음빛으로 물든다
var guard_timer := 0.0       # > 0 이면 받는 피해 감소
var guard_reduce := 0.0

# 유물 상태 (VDRelicRuntime 이 건다)
var shield := 0.0            # 피해를 먼저 흡수하는 보호막
var slow_timer := 0.0        # > 0 이면 공격·이동 간격이 slow_mult 배로 늘어난다
var slow_mult := 1.0
var burn_timer := 0.0        # > 0 이면 화상 (피해는 VDRelicRuntime 이 준다)
var burn_dps := 0.0
var last_hit_by = null       # 마지막으로 때린 쪽: VDUnit 또는 유물 id 문자열 (처치 판정용)

var _flash := 0.0
var _cast_glow := 0.0        # 시전 순간 몸이 빛나는 정도 (1 → 0)
var _move_tween: Tween
var _anim_tween: Tween

var visual: Node2D            # VDRig 비주얼 (없으면 박스)
var _overlay: Node2D          # 이름·HP 바: 비주얼 위에 그린다
var _top := -70.0             # 비주얼 위쪽 끝 y
var _base_dir := 1.0          # 원화가 바라보는 방향 (영웅 +1 오른쪽, 몬스터 -1 왼쪽)
var _facing := 1.0
var _idle := []               # [{node, pos, rot, scale, kind}]
var _t := 0.0
var _phase := 0.0

const STEP_SEC := 0.2         # 한 걸음(한 번 튀기) 시간
const WALK_BOUNCE := 9.0      # 튀어오르는 높이(px)
const WALK_SWAY := 7.0        # 좌우 기울기(도)
const WALK_SHIFT := 2.5       # 좌우 흔들림(px)
var _walk_t := 0.0
var _walk_amt := 0.0          # 0 서 있음 ~ 1 걷는 중 (부드럽게 전환)
var _last_pos := Vector2.ZERO

var alive: bool:
	get:
		return hp > 0.0


func setup(def: Dictionary, id_: String, team_: int, cell_: Vector2i, hp_mult := 1.0, atk_mult := 1.0) -> void:
	id = id_
	team = team_
	cell = cell_
	home_cell = cell_
	display_name = def["name"]
	color = def["color"]
	max_hp = floorf(float(def["hp"]) * hp_mult)
	hp = max_hp
	atk = floorf(float(def["atk"]) * atk_mult)
	attack_range = int(def["range"])
	atk_cd = float(def["atk_cd"])
	move_cd = float(def["move_cd"])
	move_sec = float(def.get("move_sec", 0.25))
	armor = float(def.get("armor", 0.0))
	is_boss = bool(def.get("boss", false))
	is_healer = bool(def.get("healer", false))
	essence = int(def.get("essence", 0))
	mana_gain = float(def.get("mana", 0))
	# 전원이 같은 프레임에 행동하지 않게 타이머를 흩뜨린다
	atk_timer = randf() * atk_cd * 0.5
	move_timer = randf() * move_cd * 0.5
	_build_visual()


func _build_visual() -> void:
	_phase = randf() * TAU
	visual = VDRig.build(id, team)
	if visual:
		add_child(visual)
		_top = VDRig.top_of(visual)
		_base_dir = 1.0 if team == 0 else -1.0
		_facing = _base_dir
		for c in visual.get_children():
			var kind := "body"
			if c.name == "head":
				kind = "head"
			elif str(c.name).begins_with("weapon"):
				kind = "weapon"
			elif team == 1:
				kind = "boss" if is_boss else "monster"
			_idle.append({"node": c, "pos": c.position, "rot": c.rotation, "scale": c.scale, "kind": kind})
	else:
		_top = -(104.0 if is_boss else 66.0) - 4.0
	_overlay = Node2D.new()
	_overlay.name = "Overlay"
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


## 가로 방향 dx 쪽을 바라보게 비주얼을 뒤집는다.
func face(dx: float) -> void:
	if visual == null or absf(dx) < 1.0:
		return
	_facing = signf(dx)
	visual.scale.x = absf(visual.scale.x) * _facing * _base_dir


func _redraw() -> void:
	queue_redraw()
	if _overlay:
		_overlay.queue_redraw()


func snap_to_cell() -> void:
	if _move_tween:
		_move_tween.kill()
	moving = false
	position = VDData.to_screen(Vector2(cell))


func move_to_cell(c: Vector2i, dur := 0.25) -> void:
	cell = c
	if _move_tween:
		_move_tween.kill()
	moving = true
	face(VDData.to_screen(Vector2(c)).x - position.x)
	_move_tween = create_tween()
	_move_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_move_tween.tween_property(self, "position", VDData.to_screen(Vector2(c)), dur)
	_move_tween.finished.connect(func() -> void: moving = false)


## 차원 소환: 공허에서 세로로 납작한 새하얀 빛줄기로 떨어져 바닥에 꽂히고(가로로 찌그러짐),
## 위로 튕겨 늘어났다가 쫀득하게 제 모습으로 돌아오며 흰빛이 빠진다. 착지 순간 on_land 를 부른다(충격 이펙트용).
## 타이밍·배율은 VDSummonFx (연출 연구실에서 조절).
static var _white_shader: Shader

func appear(on_land := Callable()) -> void:
	var sec := func(k: String) -> float: return maxf(VDSummonFx.g(k), 0.001)
	var foot := position
	_set_white(1.0)
	_ensure_glow()
	_glow.scale = _glow_base_scale * VDSummonFx.g("glow_size")
	_glow.modulate.a = VDSummonFx.g("glow_alpha")
	_set_airborne(true)
	# 1단계: 위에서 가늘고 길게 빛나는 채로 낙하 (가속)
	scale = Vector2(VDSummonFx.g("fall_x0"), VDSummonFx.g("fall_y0"))
	position = foot + Vector2(0, -VDSummonFx.g("drop_height") * (VDSummonFx.g("boss_height") if is_boss else 1.0))
	if _anim_tween:
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "position", foot, sec.call("drop_sec")).set_trans(VDSummonFx.trans("drop_trans")).set_ease(Tween.EASE_IN)
	_anim_tween.parallel().tween_property(self, "scale", Vector2(VDSummonFx.g("fall_x1"), VDSummonFx.g("fall_y1")), sec.call("drop_sec"))
	# 2단계: 꽂히는 순간 가로로 납작하게 퍼진다 (한 프레임 스냅 + 잠깐 버팀)
	_anim_tween.tween_callback(func() -> void:
		scale = Vector2(VDSummonFx.g("squash_x"), VDSummonFx.g("squash_y"))
		_airborne = false
		queue_redraw()
		if on_land.is_valid():
			on_land.call())
	_anim_tween.tween_property(self, "scale", Vector2(VDSummonFx.g("hold_x"), VDSummonFx.g("hold_y")), sec.call("hold_sec"))
	# 3단계: 위로 튕겨 늘어나며 원래 색이 돌아오기 시작
	var w3 := VDSummonFx.g("stretch_white")
	_anim_tween.tween_property(self, "scale", Vector2(VDSummonFx.g("stretch_x"), VDSummonFx.g("stretch_y")), sec.call("stretch_sec")).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tween.parallel().tween_method(_set_white, 1.0, w3, sec.call("stretch_sec"))
	_anim_tween.parallel().tween_property(_glow, "modulate:a", VDSummonFx.g("glow_alpha") * 0.45, sec.call("stretch_sec"))
	# 4단계: 쫀득하게 출렁이며 제자리 (탄성) + 흰빛·후광이 빠진다. 이름·HP 바는 이때 나타난다.
	_anim_tween.tween_callback(_set_airborne.bind(false))
	_anim_tween.tween_property(self, "scale", Vector2.ONE, sec.call("settle_sec")).set_trans(VDSummonFx.trans("settle_trans")).set_ease(Tween.EASE_OUT)
	_anim_tween.parallel().tween_method(_set_white, w3, 0.0, sec.call("white_fade_sec"))
	_anim_tween.parallel().tween_property(_glow, "modulate:a", 0.0, sec.call("glow_fade_sec"))


## 소환 연출 전체 길이(초): 낙하 + 버팀 + 튕김 + 안착 (VDBattle 이 마지막 적을 기다릴 때 쓴다)
static func appear_duration() -> float:
	return VDSummonFx.g("drop_sec") + VDSummonFx.g("hold_sec") + VDSummonFx.g("stretch_sec") + maxf(VDSummonFx.g("settle_sec"), maxf(VDSummonFx.g("white_fade_sec"), VDSummonFx.g("glow_fade_sec")))


var _airborne := false

## 낙하 중에는 발밑 링·그림자와 이름·HP 바를 숨긴다 (허공에서 함께 늘어나 보이지 않게).
func _set_airborne(on: bool) -> void:
	_airborne = on
	if _overlay:
		_overlay.visible = not on
	queue_redraw()


## 비주얼을 흰색 실루엣 쪽으로 섞는다 (0 원래 색 ~ 1 완전 흰색).
func _set_white(k: float) -> void:
	if visual == null:
		_flash = k
		_redraw()
		return
	if visual.material == null:
		if _white_shader == null:
			_white_shader = Shader.new()
			_white_shader.code = """shader_type canvas_item;
uniform float white : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, vec3(1.0), white), c.a);
}"""
		var m := ShaderMaterial.new()
		m.shader = _white_shader
		visual.material = m
		for c in visual.get_children():
			(c as CanvasItem).use_parent_material = true
	(visual.material as ShaderMaterial).set_shader_parameter("white", k)


var _glow: Sprite2D
var _glow_base_scale := Vector2.ONE

## 소환 빛의 보랏빛 후광: 몸 뒤에 가산 블렌드 방사형 그라데이션.
func _ensure_glow() -> void:
	if _glow:
		return
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 1.0, 1.0))
	g.set_color(1, Color(0.6, 0.2, 1.0, 0.0))
	g.add_point(0.35, Color(0.85, 0.5, 1.0, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_glow = Sprite2D.new()
	_glow.name = "SummonGlow"
	_glow.texture = tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.position = Vector2(0, _top * 0.5)
	_glow_base_scale = Vector2(1.3, absf(_top) / 128.0 * 1.8)
	_glow.scale = _glow_base_scale
	_glow.modulate.a = 0.0
	add_child(_glow)
	move_child(_glow, 0)


func attack_anim(toward: Vector2) -> void:
	if _anim_tween:
		_anim_tween.kill()
	var dir := (toward - position).normalized()
	face(toward.x - position.x)
	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "scale", Vector2(1.18, 0.88), 0.07)
	_anim_tween.parallel().tween_property(self, "position", position + dir * 10.0, 0.07)
	_anim_tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	_anim_tween.parallel().tween_property(self, "position", VDData.to_screen(Vector2(cell)), 0.12)


## 스킬 도약: 포물선을 그리며 c 로 뛰어 착지한다. 착지까지의 Tween 을 돌려준다.
func leap_to(c: Vector2i, dur: float, height: float) -> Tween:
	cell = c
	if _move_tween:
		_move_tween.kill()
	if _anim_tween:
		_anim_tween.kill()
	moving = false
	scale = Vector2.ONE
	var from := position
	var to := VDData.to_screen(Vector2(c))
	face(to.x - from.x)
	_move_tween = create_tween()
	_move_tween.tween_method(func(k: float) -> void:
		position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * height), 0.0, 1.0, dur)
	_move_tween.tween_property(self, "scale", Vector2(1.25, 0.8), 0.06)
	_move_tween.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return _move_tween


## 마나를 채운다 (가득 차면 VDBattle 이 스킬을 시전한다).
func gain_mana(amount: float) -> void:
	if mana_gain <= 0.0:
		return
	mana = minf(VDData.MAX_MANA, mana + amount)
	_redraw()


func mana_full() -> bool:
	return mana_gain > 0.0 and mana >= VDData.MAX_MANA


## 시전 순간: 몸이 빛나며 살짝 커졌다 돌아온다.
func cast_pulse() -> void:
	_cast_glow = 1.0
	if _anim_tween:
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "scale", Vector2(1.22, 1.22), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(self, "scale", Vector2.ONE, 0.2)


func stun(sec: float, freeze := false) -> void:
	if not alive:
		return
	if sec >= stun_timer:
		frozen = freeze
	stun_timer = maxf(stun_timer, sec)
	_redraw()


## 방어력과 가드를 적용한 실제 피해량을 돌려준다.
func take_damage(amount: float) -> float:
	if not alive:
		return 0.0
	if armor > 0.0:
		amount = ceilf(amount * (1.0 - armor))
	if guard_timer > 0.0:
		amount = floorf(amount * (1.0 - guard_reduce))
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
	hp = maxf(0.0, hp - amount)
	_flash = 1.0
	_redraw()
	if hp <= 0.0:
		_die()
	return amount


func heal(amount: float) -> void:
	if not alive:
		return
	hp = minf(max_hp, hp + amount)
	_redraw()


func revive_full() -> void:
	hp = max_hp
	visible = true
	modulate.a = 1.0
	scale = Vector2.ONE
	_redraw()


func _die() -> void:
	moving = false
	if _move_tween:
		_move_tween.kill()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(func() -> void: visible = false)
	died.emit(self)


## 전투 시간으로 상태 타이머를 줄인다 (VDBattle 이 전투 중에만 부른다).
func tick_status(dt: float) -> void:
	if stun_timer > 0.0:
		stun_timer = maxf(0.0, stun_timer - dt)
		if stun_timer == 0.0:
			frozen = false
		_redraw()
	if guard_timer > 0.0:
		guard_timer = maxf(0.0, guard_timer - dt)
		_redraw()
	if slow_timer > 0.0:
		slow_timer = maxf(0.0, slow_timer - dt)
		_redraw()
	if burn_timer > 0.0:
		burn_timer = maxf(0.0, burn_timer - dt)
		_redraw()


## 둔화 중이면 공격·이동 간격에 곱하는 배율.
func cd_mult() -> float:
	return slow_mult if slow_timer > 0.0 else 1.0


## 방을 넘어갈 때: 상태이상을 비운다. 마나는 다음 전투로 이어진다.
func reset_combat() -> void:
	casting = false
	stun_timer = 0.0
	frozen = false
	guard_timer = 0.0
	shield = 0.0
	slow_timer = 0.0
	burn_timer = 0.0
	last_hit_by = null
	_redraw()


func _process(delta: float) -> void:
	_cast_glow = maxf(0.0, _cast_glow - delta * 2.5)
	if visual:
		# 피격 섬광·시전 빛: 원화를 하얗게 밝힌다 (modulate 1 초과 = 가산 느낌). 빙결이면 얼음빛.
		var f := 1.0 + 1.6 * _flash + 0.9 * _cast_glow
		var tint := Color(0.55, 0.85, 1.45) if frozen and stun_timer > 0.0 else Color.WHITE
		visual.modulate = Color(tint.r * f, tint.g * f, tint.b * f)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		_redraw()
	if visual and alive:
		_t += delta
		_animate_idle()
		_animate_walk(delta)
	_last_pos = position


## 걷기: moving 동안 한 걸음(STEP_SEC)마다 통통 튀고, 걸음마다 몸을 좌우로 번갈아 기울인다.
## 멈추면 걸음 위상을 마저 끝내듯 부드럽게 바로 선다. 진행 방향은 실제 위치 변화로 정한다(복도 이동 포함).
func _animate_walk(delta: float) -> void:
	var vel := position - _last_pos
	if moving and absf(vel.x) > 0.3:
		face(vel.x)
	_walk_amt = move_toward(_walk_amt, 1.0 if moving else 0.0, delta * 8.0)
	if moving:
		_walk_t += delta
	elif _walk_amt == 0.0:
		_walk_t = 0.0
	var heavy := 0.45 if is_boss or armor > 0.0 else 1.0
	var step := _walk_t * PI / STEP_SEC
	# sin(step) 은 걸음마다 부호가 바뀌므로: |sin| = 매 걸음 튀어오름, sin = 왼발·오른발 번갈아 기울기
	var s := sin(step)
	var k := heavy * _walk_amt
	visual.position = Vector2(WALK_SHIFT * s * k, -absf(s) * WALK_BOUNCE * k)
	visual.rotation = deg_to_rad(WALK_SWAY) * s * k


## vd_visual_idle.gd 의 아이들을 유닛용으로 줄인 것: 영웅은 숨쉬기(몸통 늘었다 줄기, 머리·무기 따라 올라감),
## 보이들링은 찌그러짐·늘어남, 공허 군주는 느린 호흡.
func _animate_idle() -> void:
	var b := sin(_t * TAU / 2.6 + _phase)
	for it in _idle:
		var n: Node2D = it["node"]
		var pos: Vector2 = it["pos"]
		match it["kind"]:
			"body":
				n.scale = it["scale"] * Vector2(1.0 - 0.012 * b, 1.0 + 0.022 * b)
			"head":
				n.position = pos + Vector2(0, -3.0 * b)
				n.rotation = it["rot"] + deg_to_rad(1.6) * sin(_t * TAU / 4.4 + _phase)
			"weapon":
				n.position = pos + Vector2(0, -2.0 * b)
				n.rotation = it["rot"] + deg_to_rad(1.2) * sin(_t * TAU / 3.4 + _phase + 1.0)
			"monster":
				var s := sin(_t * TAU / 1.6 + _phase)
				if id == "skirmisher":
					n.position = pos + Vector2(0, 5.0 * s)
				else:
					var flex := s * (0.25 if armor > 0.0 else 1.0)
					n.scale = it["scale"] * Vector2(1.0 + 0.06 * flex, 1.0 - 0.07 * flex)
			"boss":
				var s := sin(_t * TAU / 3.8 + _phase)
				n.scale = it["scale"] * Vector2(1.0 + 0.012 * s, 1.0 + 0.018 * s)
				n.position = pos + Vector2(0, -3.0 * sin(_t * TAU / 7.6 + _phase))


func _draw() -> void:
	if _airborne:
		return
	# 발밑 셀 링 (아군 하늘색 / 적 붉은색) — 원화의 네온 셀 하이라이트 자리
	var ring := Color(0.5, 0.9, 1.0) if team == 0 else Color(1.0, 0.36, 0.46)
	var base := VDData.diamond(Vector2.ZERO, 6.0)
	draw_colored_polygon(base, Color(ring, 0.16))
	draw_polyline(base, Color(ring, 0.9), 2.0)
	if visual:
		# 발밑 그림자
		var sh := PackedVector2Array()
		var rx := 46.0 if is_boss else 30.0
		for i in 24:
			sh.append(Vector2.from_angle(TAU * i / 24.0) * Vector2(rx, rx * 0.4))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.35))
		return
	var w := 76.0 if is_boss else 44.0
	var h := 104.0 if is_boss else 66.0
	# 몸통 박스 (원화가 없는 유닛용)
	var body := Rect2(-w * 0.5, -h - 4.0, w, h)
	draw_rect(body, color.darkened(0.35))
	draw_rect(body.grow(-3.0), color)
	if team == 1:
		# 적은 눈 두 개로 "잔재" 느낌만
		var ey := body.position.y + h * 0.35
		draw_circle(Vector2(-w * 0.2, ey), 4.0, Color(0.95, 0.95, 1.0))
		draw_circle(Vector2(w * 0.2, ey), 4.0, Color(0.95, 0.95, 1.0))
	if _flash > 0.0:
		draw_rect(body, Color(1, 1, 1, _flash * 0.85))


## 이름 + HP 바. 비주얼 위쪽 끝(_top) 기준.
func _draw_overlay() -> void:
	var o := _overlay
	o.draw_string(VDData.font(), Vector2(-70.0, _top - 8.0), display_name, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 14, Color(1, 1, 1, 0.95))
	var bw := 60.0
	var bar := Rect2(-bw * 0.5, _top - 28.0, bw, 6.0)
	o.draw_rect(bar, Color(0, 0, 0, 0.6))
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	var hp_col := Color(0.3, 0.9, 0.4) if team == 0 else Color(1.0, 0.3, 0.35)
	o.draw_rect(Rect2(bar.position, Vector2(bw * ratio, 6.0)), hp_col)
	if shield > 0.0:
		# 보호막: HP 바 위에 겹치는 하늘색 띠
		o.draw_rect(Rect2(bar.position + Vector2(0, -3.0), Vector2(bw * clampf(shield / max_hp, 0.0, 1.0), 3.0)), Color(0.6, 0.95, 1.0))
	if burn_timer > 0.0:
		# 화상: 몸 옆에서 흔들리는 불꽃 점
		var bt := Time.get_ticks_msec() * 0.01
		for i in 2:
			o.draw_circle(Vector2(-14.0 + 28.0 * i, _top * 0.5 + sin(bt + i * 2.0) * 5.0), 4.0, Color(1.0, 0.55, 0.25, 0.85))
	if slow_timer > 0.0:
		# 둔화: 발밑 얼음빛 고리
		o.draw_arc(Vector2(0, -6.0), 22.0, 0.0, TAU, 24, Color(0.7, 0.9, 1.0, 0.7), 2.0)
	if mana_gain > 0.0:
		# 마나 바 (HP 바 바로 아래). 가득 차면 밝게 빛난다.
		var mb := Rect2(bar.position + Vector2(0, 8.0), Vector2(bw, 4.0))
		o.draw_rect(mb, Color(0, 0, 0, 0.6))
		var full := mana >= VDData.MAX_MANA
		o.draw_rect(Rect2(mb.position, Vector2(bw * mana / VDData.MAX_MANA, 4.0)), Color(0.55, 0.85, 1.0) if full else Color(0.25, 0.5, 1.0))
	if guard_timer > 0.0:
		# 가드: 몸을 감싸는 푸른 방패 고리
		var ga := clampf(guard_timer, 0.0, 0.5) * 2.0
		var gr := Vector2(0, _top * 0.5)
		o.draw_arc(gr, absf(_top) * 0.55, 0.0, TAU, 40, Color(0.55, 0.8, 1.0, 0.55 * ga), 3.0)
	if armor > 0.0 and _flash > 0.0:
		o.draw_arc(Vector2(0, _top * 0.5), absf(_top) * 0.6, 0.0, TAU, 40, Color(0.55, 0.8, 1.0, _flash * 0.65), 2.5, true)
	if stun_timer > 0.0 and not frozen:
		# 기절: 머리 위를 도는 별 세 개
		var tt := Time.get_ticks_msec() * 0.006
		for i in 3:
			var a := tt + TAU * i / 3.0
			o.draw_circle(Vector2(cos(a) * 18.0, _top - 40.0 + sin(a) * 6.0), 3.5, Color(1.0, 0.92, 0.4))
