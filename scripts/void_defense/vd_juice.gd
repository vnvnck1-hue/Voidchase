## 손맛 연출 모음 (VDBattle 이 하나 들고 쓴다. VFX 쇼룸 칸도 같은 이름의 필드를 갖춰 그대로 쓴다). 각 연출은 짧고 스스로 사라진다.
##   telegraph : 보스·망루의 공격 예비 동작 동안 대상 발밑에 붉은 경고 마름모가 차오르고, 때리는 순간 번쩍
##   trail     : 투사체 뒤에 가늘어지며 사라지는 꼬리
##   scorch    : 착탄 지점 바닥 그을음 (천천히 사라짐)
##   heavy_step: 대형 적·보스가 한 칸 내딛을 때 쿵 (먼지 + 작은 충격파 + 아주 약한 흔들림)
##   on_kill   : 짧은 간격 연속 처치 → DOUBLE! / TRIPLE! / N COMBO! 글자 + 점점 높아지는 소리
##   pop_world : 전장(월드) 점에서 ARCO 글자가 팡 튀어나왔다 떠오르며 사라진다 (READY! · CRITICAL! · 콤보 · 적 스킬 이름)
##   pop_text  : 같은 글자를 HUD 화면 좌표에 (정수 -N 같은 UI 글자)
##   bump      : Control 을 톡 튀게 (버튼·라벨)
## 실제 시간으로 도는 것(글자·콤보 판정)은 슬로모션에 늘어지지 않는다.
class_name VDJuice
extends Node

const WORLD_TEXT_SCALE := 0.6   # 전장 팝 글자(CRITICAL!·강타!·READY!·콤보 등) 크기 배율 (피해 숫자 VDDamageLog 와 같은 60%)
const COMBO_GAP := 1.1          # 이 시간(실제 초) 안에 다음 처치면 콤보가 이어진다
const COMBO_WORDS := ["", "", "DOUBLE!", "TRIPLE!", "QUADRA!"]

var b                # VDBattle 또는 VFX 쇼룸 칸 (ground_fx · fx_root · world_top · hud_root · vfx · camera · audio · _run_id · _chest)
var _combo := 0
var _combo_at := -100.0


func _init(battle: Node) -> void:
	b = battle
	process_mode = Node.PROCESS_MODE_ALWAYS


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


# ---------------------------------------------------------------- 전투

## 대상 발밑 경고: sec(게임 시간) 동안 안쪽부터 차오르는 붉은 마름모. 끝나면 번쩍이며 사라진다.
func telegraph(target: VDUnit, sec: float, col := Color(1.0, 0.25, 0.35)) -> void:
	if not is_instance_valid(target):
		return
	var n := Node2D.new()
	n.position = target.foot_at(target.cell)
	n.z_index = 0   # 바닥 경고는 유닛 아래 (ground_fx 가 units_root 앞이라 z 0 이면 저절로 발밑에 깔린다)
	var st := {"k": 0.0, "flash": 0.0}
	var sz := target.size
	n.draw.connect(func() -> void:
		var k: float = st["k"]
		var outer := VDData.diamond(Vector2.ZERO, 4.0, sz)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		n.draw_colored_polygon(outer, Color(col, 0.12 + 0.1 * pulse + st["flash"] * 0.5))
		n.draw_polyline(outer + PackedVector2Array([outer[0]]), Color(col, 0.7 + 0.3 * pulse), 2.5)
		if k > 0.02:
			var inner := PackedVector2Array()
			for p in outer:
				inner.append(p * k)
			n.draw_colored_polygon(inner, Color(col.lightened(0.2), 0.35 + 0.3 * k + st["flash"] * 0.4)))
	b.ground_fx.add_child(n)
	var tw := n.create_tween()
	tw.tween_method(func(v: float) -> void:
		st["k"] = v
		n.queue_redraw(), 0.0, 1.0, maxf(sec, 0.05))
	tw.tween_method(func(v: float) -> void:
		st["flash"] = v
		n.queue_redraw(), 1.0, 0.0, 0.18)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.22)
	tw.tween_callback(n.queue_free)


## 투사체 꼬리: 스프라이트가 지나간 자리를 기억해 점점 가늘고 흐리게 그린다.
func trail(s: Node2D, col: Color, width := 8.0) -> void:
	if s == null:
		return
	var n := Node2D.new()
	n.z_index = s.z_index - 1
	n.material = VDVfx.add_material()
	var pts: Array[Vector2] = []
	var st := {"fade": 1.0}
	n.draw.connect(func() -> void:
		var c := pts.size()
		for i in range(1, c):
			var k := float(i) / c
			n.draw_line(pts[i - 1], pts[i], Color(col, k * 0.8 * st["fade"]), width * k, true)
		if c > 0:
			n.draw_circle(pts[c - 1], width * 0.6, Color(1, 1, 1, 0.6 * st["fade"])))
	s.get_parent().add_child(n)
	var sref: WeakRef = weakref(s)          # 투사체가 먼저 사라진다: 람다가 해제된 객체를 붙잡지 않게
	var follow := func() -> void:
		var sp := sref.get_ref() as Node2D
		if sp != null:
			pts.append(sp.position)
			if pts.size() > 10:
				pts.pop_front()
		else:
			st["fade"] = maxf(0.0, st["fade"] - 0.15)
			if pts.size() > 1:
				pts.pop_front()
			if st["fade"] <= 0.0:
				n.queue_free()
				return
		n.queue_redraw()
	b.get_tree().process_frame.connect(follow)
	n.tree_exiting.connect(func() -> void: b.get_tree().process_frame.disconnect(follow))


## 착탄 그을음: 바닥에 어두운 타원 + 색 테두리, 2.5초 뒤 서서히 사라진다.
func scorch(at: Vector2, col: Color, r := 22.0) -> void:
	var n := Node2D.new()
	n.position = at
	var ang := randf() * TAU
	n.draw.connect(func() -> void:
		var pts := PackedVector2Array()
		for i in 18:
			var a := TAU * i / 18.0
			var m := 1.0 + 0.18 * sin(a * 3.0 + ang) + 0.1 * sin(a * 5.0 + ang * 2.0)
			pts.append(Vector2(cos(a), sin(a) * 0.5) * r * m)
		n.draw_colored_polygon(pts, Color(0.08, 0.02, 0.1, 0.55))
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(p * 0.55)
		n.draw_colored_polygon(inner, Color(col, 0.35)))
	b.ground_fx.add_child(n)
	n.scale = Vector2.ONE * 0.4
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.5)
	tw.tween_property(n, "modulate:a", 0.0, 1.0)
	tw.tween_callback(n.queue_free)


## 대형 적·보스 발걸음: 이동이 끝나는 순간 쿵.
func heavy_step(u: VDUnit, land_after: float) -> void:
	var run: int = b._run_id
	var uref: WeakRef = weakref(u)
	b.get_tree().create_timer(land_after * 0.9, false).timeout.connect(func() -> void:
		var u2 := uref.get_ref() as VDUnit
		if run != b._run_id or u2 == null or not u2.alive:
			return
		var k := 1.4 if u2.is_boss else 1.0
		b.vfx.spawn("dust", b.ground_fx, u2.position, 1.5 * k, 0.0, Color(1, 1, 1, 0.8))
		b.vfx.spawn("shockwave", b.ground_fx, u2.position, 0.45 * k, 0.0, Color(0.85, 0.7, 1.0, 0.7), Vector2(1.0, 0.5))
		b.camera.shake(0.18 * k)
		b.audio.play("boss_slam" if u2.is_boss else "knight_hit", 0.08, -10.0, 0.6))


## 처치 콤보: 연속 처치 수에 따라 글자 + 음높이가 올라가는 차임.
func on_kill(world_at: Vector2) -> void:
	var now := _now()
	_combo = _combo + 1 if now - _combo_at <= COMBO_GAP else 1
	_combo_at = now
	if _combo < 2:
		return
	var word: String = COMBO_WORDS[_combo] if _combo < COMBO_WORDS.size() else "%d COMBO!" % _combo
	var col := Color(1.0, 0.85, 0.35).lerp(Color(1.0, 0.35, 0.6), clampf((_combo - 2) / 3.0, 0.0, 1.0))
	pop_world(world_at + Vector2(0, -120), word, col, 17.0 + 2.5 * minf(_combo, 6), 0.9)
	b.audio.play("chime", 0.0, -2.0, 1.0 + 0.12 * (_combo - 2))
	b.camera.shake(0.12)


## 피해 숫자와 같은 모양의 ARCO 글자 라벨 (외곽선 + 아래 그림자).
func _text_label(text: String, col: Color, size: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", VDDamageLog.font())
	l.add_theme_font_size_override("font_size", int(size))
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("1b0b38"))
	l.add_theme_constant_override("outline_size", int(size * 0.26))
	l.add_theme_color_override("font_shadow_color", Color(0.04, 0.0, 0.1, 0.55))
	l.add_theme_constant_override("shadow_offset_y", int(size * 0.09))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 전장(월드) 글자: 캐릭터 머리 위 같은 월드 점에서 팡 튀어나와(가로로 넓게 → 세로로 → 제자리) 머문 뒤
## 위로 떠오르며 사라진다. 카메라와 함께 움직인다. size 는 월드 px. 화면 배율만큼 크게 래스터해 선명하게. 실제 시간.
## 2026-11-09: 전투 글자는 부르는 크기의 WORLD_TEXT_SCALE(60%) 로 그린다. 안개 위 월드 레이어(b.world_top)에 붙어 HP 바 위에 보인다.
func pop_world(world_at: Vector2, text: String, col: Color, size := 28.0, hold := 0.6) -> Node2D:
	size *= WORLD_TEXT_SCALE
	var z := maxf(b.get_viewport().get_canvas_transform().get_scale().x, 0.1)
	var holder := Node2D.new()
	holder.position = world_at
	holder.z_index = 70                  # 피해 숫자(60) 위
	holder.rotation = randf_range(-0.08, 0.08)
	var l := _text_label(text, col, roundf(size * z))
	holder.add_child(l)
	(b.world_top if is_instance_valid(b.world_top) else b).add_child(holder)
	l.reset_size()
	l.position = -l.size * 0.5
	var k := 1.0 / z
	holder.scale = Vector2(1.7, 0.55) * k
	var tw := holder.create_tween().set_ignore_time_scale(true)
	tw.tween_property(holder, "scale", Vector2(0.9, 1.15) * k, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "scale", Vector2.ONE * k, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(holder, "position:y", world_at.y - size * 1.1, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(holder, "modulate:a", 0.0, 0.35)
	tw.tween_callback(holder.queue_free)
	return holder


## 화면(HUD) 좌표 글자: UI 에 붙는 글자용 (정수 -N 등). 크게 팡 → 제자리 → 위로 떠오르며 사라진다. 실제 시간.
func pop_text(screen_at: Vector2, text: String, col: Color, size := 40.0, hold := 0.6) -> Label:
	var l := _text_label(text, col, size)
	l.z_index = 80
	b.hud_root.add_child(l)
	l.reset_size()
	l.pivot_offset = l.size * 0.5
	l.position = screen_at - l.size * 0.5
	l.scale = Vector2(1.7, 0.55)
	l.rotation = randf_range(-0.08, 0.08)
	var tw := l.create_tween().set_ignore_time_scale(true)
	tw.tween_property(l, "scale", Vector2(0.9, 1.15), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(l, "position:y", l.position.y - 40.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.35)
	tw.tween_callback(l.queue_free)
	return l


## 마나가 막 찬 유닛: 몸 주변 빛 + READY! 글자 + 차임.
func ready_burst(u: VDUnit) -> void:
	if not is_instance_valid(u):
		return
	b.vfx.spawn("burst", b.fx_root, b._chest(u), 0.35, 0.0, Color(1.0, 0.95, 0.6))
	b.vfx.spawn("shockwave", b.ground_fx, u.position, 0.5, 0.0, Color(1.0, 0.9, 0.5), Vector2(1.0, 0.5))
	pop_world(u.position + Vector2(0, u._top - 56.0), "READY!", Color(1.0, 0.92, 0.45), 24.0, 0.35)
	b.audio.play("chime", 0.03, -6.0, 1.3)


# ---------------------------------------------------------------- UI

## Control 을 톡 튀게: 커졌다(가로로 살짝 넓게) 탄성으로 제자리. 실제 시간.
static func bump(c: Control, k := 1.0) -> void:
	if c == null or not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween().set_ignore_time_scale(true)
	c.scale = Vector2(1.0 + 0.22 * k, 1.0 - 0.1 * k)
	tw.tween_property(c, "scale", Vector2(1.0 - 0.06 * k, 1.0 + 0.08 * k), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
