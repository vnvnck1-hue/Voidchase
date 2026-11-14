## 몬스터 체액: 처치된 자리 바닥에 둥근 공허 체액 덩어리를 남긴다.
##   철퍽: 가운데서 퍼지며 1.18배까지 넘쳤다 출렁이며 자리 잡고(가장자리가 잠깐 일렁임), 작은 방울들이 포물선으로 튀어 둘레에 떨어진다.
##   덩어리는 아이소 바닥에 맞춰 세로 0.5 로 눌린 울퉁불퉁한 원 + 짙은 테두리 + 안쪽 밝은 웅덩이 + 광택 점.
## 바닥에 묻지 않게 반투명하게 깔리고(goo_alpha · goo_gloss), goo_life 초가 지나면 살짝 오그라들며 바닥에 스며들듯
## goo_fade 초에 걸쳐 사라진다 (값은 vd_kill_fx.gd "3 체액" — 연출 연구실 "몬스터 사망"). 새 판에 clear. 너무 많아지면 오래된 것부터 지운다.
class_name VDGoo
extends RefCounted

const KillFx := preload("res://scripts/void_defense/vd_kill_fx.gd")
const SINK_SCALE := 0.82        # 사라질 때 이만큼 오그라든다 (마르며 스며드는 느낌)

const BASE_R := 31.0            # 일반 몬스터 덩어리 반지름(px, 가로)
const ISO_Y := 0.5              # 아이소 바닥 눌림
const SPREAD_SEC := 0.42        # 퍼지는 시간
const WOBBLE_SEC := 0.9         # 가장자리 일렁임이 가라앉는 시간
const MAX_PUDDLES := 160        # 방울 웅덩이 포함 (처치당 5~10개)
const BODY := Color(0.44, 0.13, 0.66)      # 공허 체액 기본색 (적 색을 조금 섞는다)

var b                   # VDBattle 또는 연출 연구실 (ground_fx · get_tree 만 쓴다)
var puddles: Array[Node2D] = []
var _gen := 0           # clear() 마다 오른다


func _init(battle: Node) -> void:
	b = battle

## u 가 죽은 자리에 체액을 남긴다. delay: 몸이 녹아내리는 연출 뒤에 철퍽. size_k · drops_k: 크기·방울 수 배율 (vd_kill_fx.gd)
func splat(u: VDUnit, delay := 0.1, size_k := 1.0, drops_k := 1.0) -> void:
	var k := (2.2 if u.is_boss else (1.7 if u.size > 1 else (1.25 if u.armor > 0.0 else 1.0))) * size_k
	var col := BODY.lerp(u.color.lightened(0.5), 0.3)
	var foot := u.position
	var gen := _gen
	b.get_tree().create_timer(delay, false).timeout.connect(func() -> void:
		if not is_instance_valid(b) or gen != _gen:
			return
		_make(foot, BASE_R * k * randf_range(0.9, 1.1), col)
		var drops := roundi((4 + int(k * 2.0)) * drops_k)
		for i in drops:
			_droplet(foot, BASE_R * k, col))


func _make(at: Vector2, r: float, col: Color) -> Node2D:
	var n := Node2D.new()
	n.position = at
	n.z_index = 0
	var seed_ := randf() * 100.0
	var lobes := [randf_range(0.0, TAU), randf_range(0.0, TAU), randf_range(0.0, TAU)]
	var st := {"grow": 0.0, "wob": 1.0}
	n.draw.connect(func() -> void: _draw_blob(n, r, col, st, seed_, lobes))
	_layer().add_child(n)
	puddles.append(n)
	_trim()
	var tw := n.create_tween()
	tw.tween_method(func(v: float) -> void:
		st["grow"] = v
		n.queue_redraw(), 0.0, 1.0, SPREAD_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(v: float) -> void:
		st["wob"] = v
		n.queue_redraw(), 1.0, 0.0, WOBBLE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 일정 시간 뒤 스며들며 사라진다: 옅어지면서 살짝 오그라든다 (게임 시간: 히트스탑·슬로모션을 따른다)
	var fade := maxf(KillFx.g("goo_fade"), 0.05)
	var life := n.create_tween()
	life.tween_interval(maxf(KillFx.g("goo_life"), 0.0) + randf_range(0.0, 0.6))
	life.tween_property(n, "modulate:a", 0.0, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	life.parallel().tween_property(n, "scale", Vector2.ONE * SINK_SCALE, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	life.tween_callback(n.queue_free)
	return n


## 작은 방울: 몸통 높이에서 튀어 올라 둘레에 떨어져 작은 웅덩이가 된다.
func _droplet(foot: Vector2, r: float, col: Color) -> void:
	var ang := randf() * TAU
	var land := foot + Vector2(cos(ang), sin(ang) * ISO_Y) * r * randf_range(1.15, 2.0)
	var dot := Node2D.new()
	var dr := r * randf_range(0.12, 0.22)
	dot.draw.connect(func() -> void:
		dot.draw_circle(Vector2.ZERO, dr, col.darkened(0.45))
		dot.draw_circle(Vector2(-dr * 0.25, -dr * 0.25), dr * 0.72, col)
		dot.draw_circle(Vector2(-dr * 0.35, -dr * 0.4), dr * 0.25, Color(1, 0.9, 1, 0.7 * KillFx.g("goo_gloss"))))
	dot.position = foot
	dot.z_index = 4

	_layer().add_child(dot)
	var from := foot + Vector2(0, -r * 0.4)
	var arc := r * randf_range(1.2, 2.0)
	var tw := dot.create_tween()
	tw.tween_method(func(t: float) -> void:
		dot.position = from.lerp(land, t) + Vector2(0, -sin(t * PI) * arc), 0.0, 1.0, randf_range(0.28, 0.4))
	var gen := _gen
	tw.tween_callback(func() -> void:
		dot.queue_free()
		if gen == _gen:
			_make(land, dr * randf_range(1.3, 1.8), col))


func _draw_blob(n: Node2D, r: float, col: Color, st: Dictionary, seed_: float, lobes: Array) -> void:
	var g: float = st["grow"]
	if g <= 0.001:
		return
	var w: float = st["wob"]
	var rr := r * g
	var t := Time.get_ticks_msec() / 1000.0
	var outer := _ring(rr * 1.08, seed_, lobes, w, t)
	var body := _ring(rr, seed_, lobes, w, t)
	var dome := _ring(rr * 0.8, seed_ + 1.5, lobes, w, t, Vector2(-rr * 0.04, -rr * 0.16))
	var inner := _ring(rr * 0.5, seed_ + 3.0, lobes, w, t, Vector2(-rr * 0.12, -rr * 0.26))
	n.draw_colored_polygon(outer, Color(col.darkened(0.6), 0.9))
	n.draw_colored_polygon(body, Color(col.darkened(0.2), 0.95))
	n.draw_colored_polygon(dome, Color(col, 0.97))
	n.draw_colored_polygon(inner, Color(col.lightened(0.28), 0.9))
	# 광택: 왼쪽 위 길쭉한 하이라이트 + 작은 점
	var hl := Vector2(-rr * 0.3, -rr * 0.32)
	n.draw_set_transform(hl, -0.25, Vector2(1.0, 0.42))
	var gloss := KillFx.g("goo_gloss")
	n.draw_circle(Vector2.ZERO, rr * 0.24, Color(1.0, 0.9, 1.0, 0.6 * gloss))
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	n.draw_circle(hl + Vector2(rr * 0.3, rr * 0.08), rr * 0.055, Color(1.0, 0.92, 1.0, 0.6 * gloss))


## 울퉁불퉁한 원(바닥에 눌림). 반지름은 늘 양수라 다각형이 꼬이지 않는다. w>0 이면 가장자리가 일렁인다.
func _ring(r: float, seed_: float, lobes: Array, w: float, t: float, off := Vector2.ZERO) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var seg := 28
	for i in seg:
		var a := TAU * i / seg
		var m := 1.0 + 0.09 * sin(a * 3.0 + lobes[0]) + 0.06 * sin(a * 5.0 + lobes[1] + seed_) + 0.04 * sin(a * 7.0 + lobes[2])
		m += w * 0.12 * sin(a * 6.0 + t * 18.0 + seed_)
		pts.append(off + Vector2(cos(a), sin(a) * ISO_Y) * r * m)
	return pts


func _trim() -> void:
	# 사라지며 지워진 웅덩이를 뺀다 (filter 는 타입 없는 배열을 돌려주므로 assign. 지워진 노드라 인자는 타입 없이)
	puddles.assign(puddles.filter(func(p) -> bool: return is_instance_valid(p)))
	while puddles.size() > MAX_PUDDLES:
		var old: Node2D = puddles.pop_front()
		var tw := old.create_tween()
		tw.tween_property(old, "modulate:a", 0.0, 1.2)
		tw.tween_callback(old.queue_free)


var _group: CanvasGroup

## 체액 전부를 담는 CanvasGroup: 겹친 덩어리 층(테두리·몸통·웅덩이)을 먼저 합친 뒤 통째로 goo_alpha 만큼 반투명하게.
## (노드마다 투명도를 낮추면 겹친 가운데가 다시 진해진다.) ground_fx 맨 아래라 다른 바닥 이펙트(포털·충격파·정수) 밑에 깔린다.
func _layer() -> CanvasGroup:
	if not is_instance_valid(_group) or _group.get_parent() != b.ground_fx:
		_group = CanvasGroup.new()
		_group.name = "Goo"
		b.ground_fx.add_child(_group)
		b.ground_fx.move_child(_group, 0)
	_group.self_modulate.a = KillFx.g("goo_alpha")
	return _group


## 새 판·재시작: 체액을 치운다.
func clear() -> void:
	_gen += 1   # 아직 철퍽하지 않은 지연 체액·날아가는 방울도 새 판에 웅덩이를 만들지 않게
	for p in puddles:
		if is_instance_valid(p):
			p.queue_free()
	puddles.clear()
