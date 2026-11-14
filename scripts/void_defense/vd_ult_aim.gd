## 궁극기 조준 화면: 조준이 필요한 궁극기(VDData.ULTS 의 aim)의 카드를 탭하면 전투가 멈추고 전장이 어두워진다.
## 슬레이 더 스파이어처럼 그 영웅 카드에서 곡선 화살표가 마우스(손가락)까지 뻗어 무엇을 노리는지 보여 준다.
##   cone  - 건너 집중 포화: 시전자 발밑에서 마우스 쪽으로 부채꼴, 안에 든 적에 붉은 고리
##   enemy - 마법사 체인 라이트닝: 마우스 가까운 적에 화살표가 달라붙고, 번개가 튈 경로를 점선으로
## 대상이 된 적은 매 프레임 VDUnit.set_target_highlight 로 강조한다: 유닛 중 최상위로 올리고(z) 붉은 외곽선 + 붉게 물든 몸
## (CanvasGroup + shaders/unit_target_outline.gdshader). 체인은 첫 대상만 붉고 뒤로 튀는 적은 하늘색.
## 필드를 누르면 시전, 같은 카드를 다시 누르거나 우클릭·Esc 면 취소. 트리가 멈춰 있어도 돈다 (PROCESS_MODE_ALWAYS).
## class_name 없음: vd_battle.gd 가 preload 해서 쓴다.
extends CanvasLayer

const SNAP_PX := 90.0 * VDData.TILE_SCALE          # 마우스에서 이 거리(월드 px) 안의 적에 달라붙는다
const DIM := 0.5                # 조준 중 무대 어둡기 (VDUltCinematic 딤드와 같은 방식)

var b: VDBattle
var active := false
var caster: VDUnit
var kind := ""
var _arrow: Node2D               # 화면 좌표: 카드 → 마우스 화살표
var _world: Node2D               # 월드 좌표, 유닛 위(z 46): 체인 경로 점선
var _ground: Node2D              # 월드 좌표, 유닛 아래(units_root 바로 앞): 부채꼴·대상 발밑 고리 — 몬스터가 고리를 덮는다
var _hint: Label
var _target: VDUnit = null       # enemy 조준: 지금 노리는 적
var _t := 0.0
var _confirm: Callable           # (caster, aim) 시전
var mouse_override: Variant = null   # 테스트: 실제 커서 대신 이 화면 좌표(Vector2)를 쓴다
var _press_at: Variant = null       # 이번 누름 위치 (누르는 순간만)
var _highlighted: Array[VDUnit] = []   # 지금 강조 중인 대상 (set_target_highlight 켜 둔 유닛)
const TARGET_RED := Color(1.0, 0.12, 0.38)    # 형광 핑크레드 (외곽선 네온)
const CHAIN_BLUE := Color(0.3, 0.95, 1.0)     # 형광 시안 (체인 뒷순위)


func setup(battle: VDBattle, on_confirm: Callable) -> void:
	b = battle
	_confirm = on_confirm
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_arrow = Node2D.new()
	_arrow.draw.connect(_draw_arrow)
	add_child(_arrow)
	_hint = Label.new()
	_hint.add_theme_font_override("font", VDData.font())
	_hint.add_theme_font_size_override("font_size", 26)
	_hint.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.1))
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var band := StyleBoxFlat.new()   # 글자 뒤 어두운 띠: 전장 위에서도 읽히게
	band.bg_color = Color(0.04, 0.02, 0.08, 0.6)
	band.content_margin_top = 6
	band.content_margin_bottom = 6
	_hint.add_theme_stylebox_override("normal", band)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	add_child(_hint)
	_world = Node2D.new()
	_world.name = "UltAimWorld"
	_world.z_index = 46            # 유닛 위, 전투 이펙트 아래 (궁극기 무대와 같은 높이)
	_world.process_mode = Node.PROCESS_MODE_ALWAYS
	_world.draw.connect(_draw_world)
	b.add_child(_world)
	_ground = Node2D.new()
	_ground.name = "UltAimGround"
	_ground.process_mode = Node.PROCESS_MODE_ALWAYS
	_ground.draw.connect(_draw_ground)
	b.add_child(_ground)
	b.move_child(_ground, b.units_root.get_index())   # 바닥·바닥 이펙트 위, 유닛 아래


func begin(u: VDUnit, aim_kind: String) -> void:
	if active:
		cancel()
	active = true
	caster = u
	_press_at = null
	kind = aim_kind
	_target = null
	_t = 0.0
	b.get_tree().paused = true
	var lit: Array = []
	for x in b.allies + b.enemies:
		if x.alive:
			lit.append(x)
	b.ult.aim_dim(true, lit, DIM)
	b.fx_root.visible = false       # 멈춘 전투 이펙트·피해 숫자는 숨긴다: 조준 대상만 보이게
	b.dmg_log.visible = false
	b.audio.play("whoosh", 0.0, 0.0, 0.6)
	var ud: Dictionary = VDData.ULTS[u.id]
	_hint.text = "%s — %s\n필드를 눌러 시전 · 카드를 다시 누르거나 우클릭하면 취소" % [ud["name"], "방향을 고르세요" if kind == "cone" else "첫 대상을 고르세요"]
	_hint.add_theme_color_override("font_color", u.color.lightened(0.55))
	_hint.visible = true
	_layout_hint()
	_update_target()


func cancel() -> void:
	if not active:
		return
	_end()
	b.audio.play("click", 0.0, -4.0, 0.8)


func _end() -> void:
	active = false
	_hint.visible = false
	_set_highlights([])
	b.ult.aim_dim(false, [], 0.0)
	b.fx_root.visible = true
	b.dmg_log.visible = true
	if b.get_tree():
		b.get_tree().paused = false
	_arrow.queue_redraw()
	_world.queue_redraw()
	_ground.queue_redraw()


func _layout_hint() -> void:
	var vs := b.get_viewport().get_visible_rect().size
	_hint.position = Vector2(0, 150)
	_hint.size = Vector2(vs.x, 80)


# ---------------------------------------------------------------- 입력

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_press_at = null
		_update_target()
		return
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()   # 조준 중엔 카드·전장 다른 입력을 막는다
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			press(event.position)
	elif event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


## 화면 좌표 p 를 눌렀다: 시전자 카드면 취소, 아니면 그 자리로 시전 (적 조준인데 대상이 없으면 거절).
func press(p: Vector2) -> void:
	if not active:
		return
	if b.frame.card_at(p) == caster.id:
		cancel()
		return
	_press_at = p                  # 터치는 이동 없이 바로 누르므로 누른 자리를 조준점으로
	_update_target()
	var aim: Variant = null
	if kind == "enemy":
		if _target == null:
			b.audio.play("denied", 0.0, -2.0)
			return
		aim = _target
	else:
		aim = _mouse_world()
	var u := caster
	_end()
	_confirm.call(u, aim)


func _mouse_screen() -> Vector2:
	if mouse_override is Vector2:
		return mouse_override
	if _press_at is Vector2:
		return _press_at
	return b.get_viewport().get_mouse_position()


func _mouse_world() -> Vector2:
	return b.get_viewport().get_canvas_transform().affine_inverse() * _mouse_screen()


func _update_target() -> void:
	if kind != "enemy":
		return
	var m := _mouse_world()
	var best: VDUnit = null
	var best_d := SNAP_PX
	for e in b.enemies:
		if not e.alive:
			continue
		var d := minf(m.distance_to(b._chest(e)), m.distance_to(e.position))
		if d < best_d:
			best_d = d
			best = e
	_target = best


func _process(delta: float) -> void:
	if not active:
		return
	_t += minf(delta / maxf(Engine.time_scale, 0.0001), 0.1)   # 실제 시간 (히트스톱 중에도 흐른다)
	if b.state != VDBattle.State.BATTLE or not is_instance_valid(caster) or not caster.alive:
		_end()
		return
	_update_highlights()
	_arrow.queue_redraw()
	_world.queue_redraw()
	_ground.queue_redraw()


# ---------------------------------------------------------------- 대상 강조

## 지금 궁극기가 맞힐 적: cone 은 부채꼴 안 전부(붉게), enemy 는 체인 경로(첫 대상 붉게, 나머지 하늘색).
func _targets_now() -> Array:
	var out: Array = []   # [[VDUnit, Color, strength], ...]
	if not is_instance_valid(caster):
		return out
	var ud: Dictionary = VDData.ULTS[caster.id]
	match kind:
		"cone":
			for e in b.ults.in_cone(caster, _mouse_world(), ud):
				out.append([e, TARGET_RED, 1.0])
		"enemy":
			if _target != null and is_instance_valid(_target) and _target.alive:
				var path: Array[VDUnit] = b.ults.chain_path(caster, _target, ud)
				for i in path.size():
					out.append([path[i], TARGET_RED if i == 0 else CHAIN_BLUE, 1.0 if i == 0 else 0.6])
	return out


func _update_highlights() -> void:
	var now := _targets_now()
	_set_highlights(now)
	var pulse := 0.5 + 0.5 * sin(_t * 7.0)
	for row in now:
		(row[0] as VDUnit).set_target_pulse(pulse)


## 강조 집합을 rows([[unit, col, strength]]) 로 맞춘다: 빠진 유닛은 끄고, 새 유닛은 켠다 (색은 매번 갱신).
func _set_highlights(rows: Array) -> void:
	var keep: Array[VDUnit] = []
	for row in rows:
		var u: VDUnit = row[0]
		if is_instance_valid(u):
			u.set_target_highlight(true, row[1], row[2])
			keep.append(u)
	for u in _highlighted:
		if is_instance_valid(u) and not keep.has(u):
			u.set_target_highlight(false)
	_highlighted = keep


# ---------------------------------------------------------------- 그리기

## 화살표 끝: enemy 조준이면 대상 가슴(화면 좌표), 아니면 마우스.
func _arrow_end() -> Vector2:
	if kind == "enemy" and _target != null:
		return b.get_viewport().get_canvas_transform() * b._chest(_target)
	return _mouse_screen()


func _draw_arrow() -> void:
	if not active:
		return
	var p0: Vector2 = b.frame.card_anchor(caster.id)
	var p3 := _arrow_end()
	var valid := kind != "enemy" or _target != null
	var col := caster.color.lightened(0.45) if valid else Color(0.75, 0.7, 0.8)
	# 카드 위 고리: 이 카드가 쏜다
	var pulse := 0.5 + 0.5 * sin(_t * 8.0)
	_arrow.draw_arc(p0, 26.0 + 4.0 * pulse, 0.0, TAU, 40, Color(col, 0.8), 4.0, true)
	# 곡선: 카드에서 위로 솟았다가 목표로 내려온다 (3차 베지어)
	var rise := clampf(absf(p0.y - p3.y) * 0.5 + 80.0, 80.0, 360.0)
	var p1 := p0 + Vector2(0, -rise)
	var p2 := p3 + (p1 - p3) * 0.35
	var n := 13
	var flow := fmod(_t * 1.6, 1.0)            # 마디가 끝 쪽으로 흐른다
	for i in n:
		var s := (float(i) + flow) / n
		if s > 0.9 or s < 0.04:
			continue
		var pt := _bez(p0, p1, p2, p3, s)
		var tan := (_bez(p0, p1, p2, p3, minf(s + 0.01, 1.0)) - pt).normalized()
		var nrm := tan.orthogonal()
		var w := lerpf(11.0, 20.0, s)
		# 꺾쇠(>) 마디: 어두운 테두리 위에 밝은 선
		var v := PackedVector2Array([pt - tan * w * 0.55 + nrm * w, pt + tan * w * 0.45, pt - tan * w * 0.55 - nrm * w])
		_arrow.draw_polyline(v, Color(0.06, 0.02, 0.1, 0.85), 13.0)
		_arrow.draw_polyline(v, Color(col, lerpf(0.75, 1.0, s)), 7.0)
	# 화살촉
	var end_tan := (p3 - _bez(p0, p1, p2, p3, 0.93)).normalized()
	var en := end_tan.orthogonal()
	var head := PackedVector2Array([p3 + end_tan * 12.0, p3 - end_tan * 44.0 + en * 32.0, p3 - end_tan * 30.0, p3 - end_tan * 44.0 - en * 32.0])
	_arrow.draw_colored_polygon(head, Color(0.05, 0.02, 0.08, 0.8))
	var inner := PackedVector2Array()
	for q in head:
		inner.append(p3 + (q - p3) * 0.78)
	_arrow.draw_colored_polygon(inner, col)


static func _bez(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3


## 유닛 아래: 부채꼴과 대상 발밑 고리. 강조된 몬스터(z 40)·다른 유닛이 고리를 덮어 고리가 발밑에 깔린다.
func _draw_ground() -> void:
	if not active:
		return
	var ud: Dictionary = VDData.ULTS[caster.id]
	var col := caster.color.lightened(0.3)
	var pulse := 0.5 + 0.5 * sin(_t * 7.0)
	match kind:
		"cone":
			var m := _mouse_world()
			var poly := VDUlts.cone_polygon(caster, m, ud)
			_ground.draw_colored_polygon(poly, Color(col, 0.22 + 0.08 * pulse))
			var outline := poly.duplicate()
			outline.append(poly[0])
			_ground.draw_polyline(outline, Color(col.lightened(0.3), 0.9), 3.0, true)
			for e in b.ults.in_cone(caster, m, ud):
				_ring(e, TARGET_RED, pulse)
		"enemy":
			for e in b.enemies:
				if e.alive and e != _target:
					_ring(e, Color(1, 1, 1, 0.35), 0.0)
			if _target != null:
				var path: Array[VDUnit] = b.ults.chain_path(caster, _target, ud)
				for i in path.size():
					_ring(path[i], TARGET_RED if i == 0 else CHAIN_BLUE, pulse if i == 0 else 0.0)


## 유닛 위: 체인 라이트닝이 튈 경로 점선 (가슴에서 가슴으로).
func _draw_world() -> void:
	if not active or kind != "enemy" or _target == null:
		return
	var ud: Dictionary = VDData.ULTS[caster.id]
	var path: Array[VDUnit] = b.ults.chain_path(caster, _target, ud)
	for i in range(1, path.size()):
		_dashed(b._chest(path[i - 1]), b._chest(path[i]), Color(CHAIN_BLUE, 0.8))


## 적 발밑 고리 (이소 타원).
func _ring(e: VDUnit, col: Color, pulse: float) -> void:
	var r := 42.0 * e.size + 6.0 * pulse
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(e.foot_at(e.cell) + Vector2(cos(a) * r, sin(a) * r * 0.5))
	_ground.draw_polyline(pts, Color(0, 0, 0, col.a * 0.5), 6.0, true)
	_ground.draw_polyline(pts, col, 3.0, true)


func _dashed(a: Vector2, c: Vector2, col: Color) -> void:
	var len := a.distance_to(c)
	var dir := (c - a) / maxf(len, 0.001)
	var s := fmod(_t * 60.0, 20.0)
	while s < len:
		_world.draw_line(a + dir * s, a + dir * minf(s + 11.0, len), col, 3.0, true)
		s += 20.0
