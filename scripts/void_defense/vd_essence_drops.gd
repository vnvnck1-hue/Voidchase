## 공허 정수 드롭: 세명이 오리라(TrioChess) 동전 연출을 2D 로 옮긴 것.
##   처치 → 결정이 적에게서 튀어나와 포물선(0.4초)으로 바닥에 떨어지고 틱 소리 + 두 번 통통 → 그 자리에서 빙글빙글 돌며 대기
##   전투가 모두 끝나면 collect(): 0.25 + 0.03×i 초 간격으로 하나씩 화면 좌표의 HUD 아이콘이 되어
##   카메라 쪽으로 다가오듯 크게 부풀며 들렸다가(0.22초) 곡선(2차 베지어, 0.5초, 점점 빨라짐)을 그리며 작아지면서
##   정수 표시로 빨려 들어가고, 도착마다 틱 + 숫자 증가·튕김.
## 원본: TrioChess scripts/vfx.gd coin() · main.gd _collect_coins() · hud.gd _fly_to_pill().
class_name VDEssenceDrops
extends RefCounted

const FIELD_PX := 58.0            # 바닥 결정 크기 (px)
const FLY_PX := 40.0              # HUD 로 날아가는 아이콘 크기 (TrioChess 40×40)
const LAND_R := Vector2(30, 15)   # 떨어지는 자리: 적 발밑 둘레 타원 (아이소 바닥)

var b: VDBattle
var drops: Array[Dictionary] = []   # {node: Node2D, amount: int}
var icon: Texture2D                 # 돌아가는 3D 결정 렌더 (VDEssenceGem3D)


func _init(battle: VDBattle) -> void:
	b = battle
	icon = VDEssenceGem3D.texture_for(battle)


## 바닥에 깔린 정수 합계 (아직 HUD 에 들어가지 않은 것).
func pending() -> int:
	var n := 0
	for d in drops:
		n += int(d["amount"])
	return n


## 처치 지점에서 결정 하나(보스는 여러 개로 나눠)를 튀어나오게 한다.
func spawn(foot: Vector2, top: float, amount: int, pieces := 1) -> void:
	pieces = maxi(1, mini(pieces, amount))
	var each := amount / pieces
	for i in pieces:
		var a := each + (amount - each * pieces if i == 0 else 0)
		_spawn_one(foot, top, a, i * 0.05)


func _spawn_one(foot: Vector2, top: float, amount: int, delay: float) -> void:
	var n := Node2D.new()
	n.position = foot + Vector2(0, top * 0.5)
	n.z_index = 5
	var shadow := Sprite2D.new()                 # 바닥 그림자: 떠오르면 작아진다
	shadow.texture = _shadow_tex()
	shadow.modulate = Color(0.05, 0.0, 0.1, 0.45)
	shadow.name = "Shadow"
	n.add_child(shadow)
	var glow := Sprite2D.new()                   # 은은한 보랏빛 광채 (TrioChess 동전의 발광 재질 대신)
	glow.texture = _shadow_tex()
	glow.scale = Vector2(1.6, 3.2)
	glow.position = Vector2(0, -22)
	glow.modulate = Color(0.75, 0.45, 1.0, 0.55)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	n.add_child(glow)
	var pulse := glow.create_tween().set_loops()
	pulse.tween_property(glow, "modulate:a", 0.25, 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "modulate:a", 0.55, 0.6).set_trans(Tween.TRANS_SINE)
	var sp := Sprite2D.new()
	sp.texture = icon
	sp.offset = Vector2(0, -VDEssenceGem3D.PX * 0.42)
	sp.scale = Vector2.ONE * FIELD_PX / VDEssenceGem3D.PX
	sp.name = "Gem"
	n.add_child(sp)
	b.ground_fx.add_child(n)
	drops.append({"node": n, "amount": amount})
	# 포물선: 시작점(몸통) → 발밑 둘레 착지점, 위로 0.7 타일만큼 부푼다 (TrioChess: sin(kπ)·0.7)
	var ang := randf() * TAU
	var land := foot + Vector2(cos(ang) * LAND_R.x, sin(ang) * LAND_R.y) * randf_range(0.5, 1.0)
	var start := n.position
	var arc := 60.0
	shadow.position = land - start
	var fly := func(k: float) -> void:
		n.position = start.lerp(land, k) + Vector2(0, -sin(k * PI) * arc)
		shadow.position = land - n.position
		shadow.scale = Vector2.ONE * lerpf(0.55, 1.0, k)
	var tw := n.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(fly, 0.0, 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: b.audio.play("tick", 0.03, -4.0, 1.6))
	# 두 번 통통 (0.09 + 0.09)
	tw.tween_property(sp, "position:y", -8.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "position:y", 0.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 그 자리에서 빙글빙글: 3D 결정이 렌더 안에서 Y 축으로 돈다 (VDEssenceGem3D.SPIN_SEC)


## 전투 종료: 바닥의 결정을 하나씩 HUD 아이콘(target)으로 빨아들인다. 도착할 때마다 on_arrive(amount).
## 모두 도착할 때까지 걸리는 실제 시간(초)을 돌려준다.
func collect(target: Control, on_arrive: Callable) -> float:
	var list := drops.duplicate()
	drops.clear()
	var last := 0.0
	var i := 0
	for d in list:
		var n: Node2D = d["node"]
		var amount: int = d["amount"]
		if not is_instance_valid(n):
			on_arrive.call(amount)
			continue
		var delay := 0.25 + 0.03 * i
		i += 1
		last = delay + LIFT_SEC + FLY_SEC
		b.get_tree().create_timer(delay, true, false, true).timeout.connect(func() -> void:
			if not is_instance_valid(n):
				return
			var gem := n.get_node("Gem") as Sprite2D
			var ct := b.get_viewport().get_canvas_transform()
			var sp := ct * (n.global_position + gem.offset * gem.scale.y)
			n.queue_free()
			# 바닥 결정의 화면 크기에서 시작해야 아이콘으로 바뀌는 순간 크기가 튀지 않는다
			_fly(sp, FIELD_PX * ct.get_scale().y / FLY_PX, target, func() -> void: on_arrive.call(amount)))
	return last


## 빨려 들어가기 (TrioChess hud._fly_to_pill 를 더 쥬시하게):
##   1) 들림(LIFT_SEC): 바닥 크기에서 카메라 쪽으로 다가오듯 PEAK_S 배까지 부풀며 살짝 떠오르고 하얗게 번쩍 (튕기는 BACK 이징)
##   2) 빨림(FLY_SEC): 2차 베지어(중간점을 옆으로 흔들고 위로 띄움)로 정수 표시까지, 점점 빨라지며 END_S 배로 줄어 쏙 들어간다.
##      나는 방향으로 늘어나고(속도 늘임) 살짝 기울어진다. 뒤의 광채도 함께 줄어든다.
const LIFT_SEC := 0.22
const FLY_SEC := 0.5
const PEAK_S := 2.2               # 카메라에 가까워진 크기 (FLY_PX 기준 배율)
const END_S := 0.45               # 정수 표시에 들어갈 때 크기
const LIFT_PX := 46.0             # 들릴 때 위로 뜨는 거리


func _fly(from: Vector2, start_s: float, target: Control, on_arrive: Callable) -> void:
	var ic := TextureRect.new()
	ic.texture = icon
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size = Vector2(FLY_PX, FLY_PX)
	ic.pivot_offset = ic.size * 0.5
	ic.position = from - ic.size * 0.5
	ic.scale = Vector2.ONE * start_s
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.z_index = 90
	var glow := TextureRect.new()                # 뒤의 보랏빛 광채 (더하기 합성)
	glow.texture = _shadow_tex()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(FLY_PX, FLY_PX) * 2.2
	glow.position = (ic.size - glow.size) * 0.5
	glow.modulate = Color(0.8, 0.5, 1.0, 0.0)
	glow.show_behind_parent = true
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	ic.add_child(glow)
	b.hud_root.add_child(ic)
	var top := from + Vector2(randf_range(-14, 14), -LIFT_PX)
	var lift := func(k: float) -> void:
		ic.global_position = from.lerp(top, k) - ic.size * 0.5
		ic.scale = Vector2.ONE * lerpf(start_s, PEAK_S, k)
		ic.modulate = Color(1.9, 1.7, 2.0).lerp(Color.WHITE, clampf(k, 0.0, 1.0))   # 들리는 순간 번쩍
		glow.modulate.a = 0.8 * clampf(k, 0.0, 1.0)
	var dest := target.get_global_rect().get_center()
	var side := randf_range(-80, 80)
	var mid := top.lerp(dest, 0.5) + Vector2(side, -110)
	var prev := [top]
	var step := func(k: float) -> void:
		var a := top.lerp(mid, k)
		var c := mid.lerp(dest, k)
		var p := a.lerp(c, k)
		ic.global_position = p - ic.size * 0.5
		var s := lerpf(PEAK_S, END_S, k * k)
		var v: Vector2 = p - prev[0]
		prev[0] = p
		# 속도 늘임: 빨라질수록 나는 방향(세로 성분 위주)으로 길어지고 옆으로 가늘어진다
		var stretch := clampf(v.length() / 40.0, 0.0, 0.35)
		ic.scale = Vector2(s * (1.0 - stretch * 0.5), s * (1.0 + stretch))
		ic.rotation = clampf(v.x / 120.0, -0.35, 0.35)
		glow.modulate.a = 0.8 * (1.0 - k * 0.6)
	var tw := ic.create_tween().set_ignore_time_scale(true)
	tw.tween_method(lift, 0.0, 1.0, LIFT_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(step, 0.0, 1.0, FLY_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		ic.queue_free()
		b.audio.play("tick", 0.0, 0.0, 1.8)
		on_arrive.call())


## 새 판·재시작: 바닥에 남은 결정을 치운다.
func clear() -> void:
	for d in drops:
		if is_instance_valid(d["node"]):
			d["node"].queue_free()
	drops.clear()


static var _shadow: Texture2D


static func _shadow_tex() -> Texture2D:
	if _shadow == null:
		var g := GradientTexture2D.new()
		g.width = 40
		g.height = 16
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		g.gradient = gr
		_shadow = g
	return _shadow
