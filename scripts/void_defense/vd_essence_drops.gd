## 공허 정수 드롭: 세명이 오리라(TrioChess) 동전 연출을 2D 로 옮긴 것.
##   처치 → 결정이 파편처럼 여러 조각으로 몸에서 위로 솟구쳐 사방에 흩뿌려지고, 떨어지면 통통 튄 뒤
##   관성으로 바닥을 미끄러지다(진행 방향으로 살짝 기울었다 섬) 멈춰 그 자리에서 빙글빙글 돌며 대기
##   대기 중에도 물리(tick·blast): 전투 충격에 튕겨 날아가고, 유닛 발에 차여 굴러간다
##   전투가 모두 끝나면 collect(): 0.25 + 0.03×i 초 간격으로 하나씩 화면 좌표의 HUD 아이콘이 되어
##   카메라 쪽으로 다가오듯 크게 부풀며 들렸다가(0.22초) 곡선(2차 베지어, 0.5초, 점점 빨라짐)을 그리며 작아지면서
##   정수 표시로 빨려 들어가고, 도착마다 틱 + 숫자 증가·튕김.
## 원본: TrioChess scripts/vfx.gd coin() · main.gd _collect_coins() · hud.gd _fly_to_pill().
class_name VDEssenceDrops
extends RefCounted

const FIELD_PX := 58.0            # 바닥 결정 크기 (px)
const FLY_PX := 40.0              # HUD 로 날아가는 아이콘 크기 (TrioChess 40×40)
## 처치 분출: 조각마다 위로 SPRAY_UP 속도로 솟구치고, 바닥 방향으로 SPRAY_OUT 속도로 흩어진다 (아이소라 세로는 ISO 배)
const SPRAY_UP := Vector2(500.0, 700.0)
const SPRAY_OUT := Vector2(60.0, 120.0)   # 2026-11-10 너무 멀리 퍼져 절반 이하로
const SHARD_K := 0.78             # 여러 조각으로 나뉠 때 조각 크기 배율

var b: VDBattle
var drops: Array[Dictionary] = []   # {node: Node2D, amount: int}
var icon: Texture2D                 # 돌아가는 3D 결정 렌더 (VDEssenceGem3D)
var _gen := 0                       # clear() 마다 오른다: 이전 런의 수거 타이머·비행이 새 런에 정수를 더하지 않게
var _collecting: Array[Dictionary] = []   # collect() 로 넘어가 아직 날아오르지 않은 결정 (clear 가 거둔다)


func _init(battle: VDBattle) -> void:
	b = battle
	icon = VDEssenceGem3D.texture_for(battle)


## 바닥에 깔린 정수 합계 (아직 HUD 에 들어가지 않은 것).
func pending() -> int:
	var n := 0
	for d in drops:
		n += int(d["amount"])
	return n


## 처치 지점에서 결정을 pieces 조각으로 나눠 흩뿌린다. 조각은 고른 각도(+흔들림)로 퍼져 서로 겹치지 않게 날아간다.
func spawn(foot: Vector2, top: float, amount: int, pieces := 1) -> void:
	pieces = maxi(1, mini(pieces, amount))
	var each := amount / pieces
	var a0 := randf() * TAU
	for i in pieces:
		var a := each + (amount - each * pieces if i == 0 else 0)
		var ang := a0 + TAU * i / pieces + randf_range(-0.45, 0.45)
		_spawn_one(foot, top, a, i * 0.018, ang, SHARD_K if pieces > 1 else 1.0)


## 소팅: 결정 노드(n)는 유닛과 같은 units_root(y 정렬)에 넣고 position 을 바닥점으로 둔다
##   → 캐릭터보다 앞(아래쪽)에 있으면 앞에, 뒤(위쪽)에 있으면 캐릭터 뒤에 그려진다. 떠오름은 자식 position.y 로만.
## 그림자는 바닥에 깔려야 하므로 따로 ground_fx(z 0, 유닛 아래)에 두고 매 프레임 결정 바닥점을 따라간다.
func _spawn_one(foot: Vector2, top: float, amount: int, delay: float, ang := randf() * TAU, size := 1.0) -> void:
	var n := Node2D.new()
	n.position = foot
	var shadow := Sprite2D.new()                 # 바닥 그림자: 떠오르면 작아진다
	shadow.texture = _shadow_tex()
	shadow.modulate = Color(0.05, 0.0, 0.1, 0.45)
	shadow.position = foot
	b.ground_fx.add_child(shadow)
	var glow := Sprite2D.new()                   # 은은한 보랏빛 광채 (TrioChess 동전의 발광 재질 대신)
	glow.texture = _shadow_tex()
	glow.scale = Vector2(1.6, 3.2)
	glow.position = Vector2(0, -22)
	glow.modulate = Color(0.75, 0.45, 1.0, 0.55)
	glow.name = "Glow"
	glow.material = VDVfx.add_material()
	n.add_child(glow)
	var pulse := glow.create_tween().set_loops()
	pulse.tween_property(glow, "modulate:a", 0.25, 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "modulate:a", 0.55, 0.6).set_trans(Tween.TRANS_SINE)
	var sp := Sprite2D.new()
	sp.texture = icon
	sp.offset = Vector2(0, -VDEssenceGem3D.PX * 0.42)
	sp.scale = Vector2.ONE * FIELD_PX / VDEssenceGem3D.PX * size
	sp.name = "Gem"
	n.add_child(sp)
	b.units_root.add_child(n)
	# 파편 분출: 몸통 높이에서 위로 세게 솟구치고 ang 방향으로 흩어진다. 궤적·착지·미끄러짐은 물리(tick)가 그린다
	var h0 := maxf(0.0, -top * 0.5)
	var vh := randf_range(SPRAY_UP.x, SPRAY_UP.y)
	var out := randf_range(SPRAY_OUT.x, SPRAY_OUT.y)
	drops.append({"node": n, "shadow": shadow, "home": foot, "amount": amount, "wait": delay, "h": h0, "vh": vh, "size": size,
		"v": Vector2(cos(ang), sin(ang) * ISO) * out, "spin": randf_range(-14.0, 14.0), "squash": 0.0})
	_pose(drops.back())
	# 그 자리에서 빙글빙글: 3D 결정이 렌더 안에서 Y 축으로 돈다 (VDEssenceGem3D.SPIN_SEC)


# ---------------------------------------------------------------- 바닥 물리
## 바닥에 깔린 결정은 전투의 여파에 반응한다: 쇼크웨이브(평타·치명타·처치·내려찍기)가 터진 자리 둘레의
## 결정이 바깥으로 튕겨 날아가 통통 튀고, 걸어가는 유닛 발에 차이면 굴러간다.
## 높이 h(위쪽 +)와 바닥 좌표 position 을 따로 들고, 아이소 바닥이라 세로 거리는 ISO 만큼 납작하다.
const GRAVITY := 1700.0           # px/초²
const BOUNCE := 0.36              # 땅에 닿을 때 세로 반발
const BOUNCE_FRICTION := 0.75     # 땅에 닿을 때 바닥 속도 유지율
const ROLL_DRAG := 3.0            # 바닥에서 미끄러질 때 속도 비례 감쇠 (1/초)
const SLIDE_FRICTION := 120.0     # 바닥에서 미끄러질 때 일정 마찰 (px/초²): 끝에 스르륵 멈춘다
## 생성 자리(처치 지점 발밑)에서 너무 멀어지지 않게: STRAY_R(바닥 px, 아이소 보정) 넘게 벗어나면
## 넘은 만큼 용수철처럼 끌어당기고 바깥으로 가는 속도를 깎는다
const STRAY_R := 60.0
const STRAY_PULL := 22.0          # 넘은 거리 1px 당 끌어당기는 가속 (px/초²)
const STRAY_DAMP := 8.0           # 넘어선 상태에서 바깥 방향 속도 감쇠 (1/초)
const SLIDE_LEAN := 0.0022        # 미끄러지는 속도(px/초) → 진행 방향으로 기우는 각(rad)
const ISO := 0.5                  # 아이소 바닥 세로 납작함 (TILE_H / TILE_W)
const KICK_R := 30.0              # 유닛 발에 차이는 거리 (바닥 px, 아이소 보정)
## 충격 종류별 (VDShockwave.KINDS 와 같은 이름): r 반경(바닥 px) · up 위로 튀는 속도 · out 바깥으로 밀리는 속도
## 2026-11-10 out 을 약 절반으로: 위로는 튀어도 옆으로는 덜 밀린다
const BLASTS := {
	"light": {"r": 120.0, "up": 240.0, "out": 60.0},
	"heavy": {"r": 170.0, "up": 380.0, "out": 110.0},
	"kill": {"r": 230.0, "up": 500.0, "out": 150.0},
	"boss": {"r": 380.0, "up": 720.0, "out": 220.0},
	"slam": {"r": 320.0, "up": 640.0, "out": 200.0},
}

var _tick_cd := 0.0               # 착지 틱 소리 간격 (한꺼번에 우르르 떨어질 때 소리가 뭉개지지 않게)


## at(월드 바닥점) 에서 kind 충격: 반경 안의 결정을 가까울수록 세게 위·바깥으로 튕긴다.
func blast(at: Vector2, kind := "light", k := 1.0) -> void:
	var d: Dictionary = BLASTS.get(kind, BLASTS["light"])
	var r: float = d["r"] * sqrt(k)
	for e in drops:
		if not is_instance_valid(e["node"]):
			continue
		var off: Vector2 = e["node"].position - at
		var flat := Vector2(off.x, off.y / ISO)            # 아이소 보정한 실제 바닥 거리
		var dist := flat.length()
		if dist >= r:
			continue
		var f := 1.0 - dist / r
		f = f * (0.75 + 0.25 * f) * randf_range(0.8, 1.2)
		var dir := flat.normalized() if dist > 2.0 else Vector2.from_angle(randf() * TAU)
		dir = dir.rotated(randf_range(-0.35, 0.35))
		var out := float(d["out"]) * k * f
		e["v"] += Vector2(dir.x, dir.y * ISO) * out
		e["vh"] = minf(maxf(e["vh"], 0.0) + float(d["up"]) * k * f, 1100.0)
		e["spin"] += randf_range(-1.0, 1.0) * (4.0 + out * 0.04)
		e["wait"] = 0.0


## 매 프레임(게임 시간: 히트스탑에 멈추고 슬로모션에 느려진다).
func tick(dt: float) -> void:
	_tick_cd -= dt
	if dt <= 0.0:
		return
	var units: Array = b.allies + b.enemies
	for e in drops:
		var n: Node2D = e["node"]
		if not is_instance_valid(n):
			continue
		if e["wait"] > 0.0:
			e["wait"] -= dt
			continue
		_kick_by_units(e, units)
		var h: float = e["h"]
		var vh: float = e["vh"]
		var v: Vector2 = e["v"]
		var resting := h <= 0.0 and vh <= 0.0 and v.length_squared() < 4.0
		if not resting:
			vh -= GRAVITY * dt
			h += vh * dt
			if h <= 0.0:
				h = 0.0
				if vh < -150.0:   # 이보다 약하면 더 튀지 않고 미끄러지기 시작
					var hit := -vh
					vh = hit * BOUNCE
					v *= BOUNCE_FRICTION
					e["spin"] *= 0.6
					e["squash"] = clampf(hit / 900.0, 0.0, 0.45)
					if hit > 160.0 and _tick_cd <= 0.0:
						_tick_cd = 0.05
						b.audio.play("tick", 0.03, lerpf(-12.0, -4.0, clampf(hit / 700.0, 0.0, 1.0)), randf_range(1.5, 1.8))
				else:
					vh = 0.0
			if h <= 0.0:
				# 관성 미끄러짐: 속도 비례 감쇠 + 일정 마찰로 서서히 멈춘다
				v *= exp(-ROLL_DRAG * dt)
				v = v.move_toward(Vector2.ZERO, SLIDE_FRICTION * dt)
			v = _tether(e, n.position, v, dt)
			# 바닥 밖으로 나가려 하면 그 축만 되튕긴다 (낭떠러지·벽 대신)
			var next := n.position + v * dt
			if not _on_floor(next):
				if _on_floor(Vector2(next.x, n.position.y)):
					v.y = -v.y * 0.5
				elif _on_floor(Vector2(n.position.x, next.y)):
					v.x = -v.x * 0.5
				else:
					v = -v * 0.5
				next = n.position + v * dt
				if not _on_floor(next):
					next = n.position
			n.position = next
		e["h"] = h
		e["vh"] = vh
		e["v"] = v
		var gem := n.get_node("Gem") as Sprite2D
		if h > 0.0:
			gem.rotation += float(e["spin"]) * dt
		else:
			# 바닥에서는 미끄러지는 쪽으로 살짝 기울었다가 멈추면 꼿꼿이 선다 (결정은 서서 돈다)
			var lean := clampf(v.x * SLIDE_LEAN, -0.45, 0.45)
			gem.rotation = lerp_angle(gem.rotation, lean, 1.0 - exp(-12.0 * dt))
			e["spin"] = lerpf(e["spin"], 0.0, 1.0 - exp(-8.0 * dt))
		e["squash"] = lerpf(e["squash"], 0.0, 1.0 - exp(-14.0 * dt))
		_pose(e)


## 생성 자리(home)에서 STRAY_R 넘게 벗어났으면 용수철처럼 끌어당긴다 (아이소 보정 거리).
func _tether(e: Dictionary, p: Vector2, v: Vector2, dt: float) -> Vector2:
	var off: Vector2 = p - e["home"]
	var flat := Vector2(off.x, off.y / ISO)
	var dist := flat.length()
	if dist <= STRAY_R:
		return v
	var dir := flat / dist                       # 바깥 방향 (아이소 보정 공간)
	var vf := Vector2(v.x, v.y / ISO)
	var outward := vf.dot(dir)
	if outward > 0.0:
		vf -= dir * outward * (1.0 - exp(-STRAY_DAMP * dt))
	vf -= dir * (dist - STRAY_R) * STRAY_PULL * dt
	return Vector2(vf.x, vf.y * ISO)


## 걸어가는 유닛 발에 닿으면 발 반대쪽으로 살짝 차인다.
func _kick_by_units(e: Dictionary, units: Array) -> void:
	if e["h"] > 6.0:
		return
	var p: Vector2 = e["node"].position
	for u in units:
		if not is_instance_valid(u) or not u.alive:
			continue
		var off: Vector2 = p - u.position
		var flat := Vector2(off.x, off.y / ISO)
		var dist := flat.length()
		if dist >= KICK_R:
			continue
		var dir := flat.normalized() if dist > 1.0 else Vector2.from_angle(randf() * TAU)
		var f := 1.0 - dist / KICK_R
		e["v"] += Vector2(dir.x, dir.y * ISO) * 90.0 * f
		e["vh"] = maxf(e["vh"], 100.0 * f)
		e["spin"] += randf_range(-3.0, 3.0) * f


func _on_floor(p: Vector2) -> bool:
	return b.map == null or b.map.tiles.has(VDData.to_cell(p))


## 높이·찌그러짐을 노드에 반영: 결정과 광채는 h 만큼 떠오르고, 그림자는 높을수록 작고 옅어진다.
func _pose(e: Dictionary) -> void:
	var n: Node2D = e["node"]
	var h: float = e["h"]
	var gem := n.get_node("Gem") as Sprite2D
	var base := FIELD_PX / VDEssenceGem3D.PX * float(e.get("size", 1.0))
	var sq: float = e["squash"]
	gem.position.y = -h
	gem.scale = Vector2(base * (1.0 + sq), base * (1.0 - sq))
	var glow := n.get_node("Glow") as Sprite2D
	glow.position.y = -22.0 - h
	var shadow := e["shadow"] as Sprite2D
	shadow.position = n.position
	var hk := clampf(h / 160.0, 0.0, 1.0)
	shadow.scale = Vector2.ONE * lerpf(1.0, 0.45, hk) * float(e.get("size", 1.0))
	shadow.modulate.a = lerpf(0.45, 0.18, hk)


## 전투 종료: 바닥의 결정을 하나씩 HUD 아이콘(target)으로 빨아들인다. 도착할 때마다 on_arrive(amount).
## 모두 도착할 때까지 걸리는 실제 시간(초)을 돌려준다.
func collect(target: Control, on_arrive: Callable) -> float:
	var list := drops.duplicate()
	drops.clear()
	_collecting.append_array(list)
	var g := _gen
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
			if g != _gen or not is_instance_valid(n):
				return
			_collecting.erase(d)
			var gem := n.get_node("Gem") as Sprite2D
			var ct := b.get_viewport().get_canvas_transform()
			var sp := ct * (n.global_position + gem.position + gem.offset * gem.scale.y)
			n.queue_free()
			_free_shadow(d)
			# 바닥 결정의 화면 크기에서 시작해야 아이콘으로 바뀌는 순간 크기가 튀지 않는다
			_fly(sp, FIELD_PX * float(d.get("size", 1.0)) * ct.get_scale().y / FLY_PX, target, func() -> void:
				if g == _gen:
					on_arrive.call(amount)))
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
	glow.material = VDVfx.add_material()
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
	var trail := [0.0]                           # 반짝이 뿌린 거리 누적 (일정 간격마다 하나)
	var step := func(k: float) -> void:
		var a := top.lerp(mid, k)
		var c := mid.lerp(dest, k)
		var p := a.lerp(c, k)
		ic.global_position = p - ic.size * 0.5
		trail[0] += p.distance_to(prev[0])
		while trail[0] >= SPARKLE_GAP:
			trail[0] -= SPARKLE_GAP
			sparkle(b.hud_root, p, 1.0 - k * 0.4)
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


## 트레일 반짝이: 빨려 가는 결정이 지나간 자리에 십자 별빛이 잠깐 남아 두 번 깜빡이며(트윙클) 사라진다.
const SPARKLE_GAP := 18.0          # 이만큼 날아갈 때마다 하나 (화면 px)
const SPARKLE_COLORS := [Color(1, 1, 1), Color(0.9, 0.75, 1.0), Color(0.75, 0.6, 1.0), Color(1.0, 0.85, 0.98)]


## parent(화면 좌표 Control) 의 at 에 반짝이 하나. s 로 크기 배율.
static func sparkle(parent: Control, at: Vector2, s := 1.0) -> void:
	var sp := TextureRect.new()
	sp.texture = _sparkle_tex()
	sp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var px := randf_range(14.0, 30.0) * s
	sp.size = Vector2(px, px)
	sp.pivot_offset = sp.size * 0.5
	sp.rotation = randf_range(-0.3, 0.3)
	sp.scale = Vector2.ZERO
	sp.modulate = SPARKLE_COLORS.pick_random()
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.z_index = 89
	sp.material = VDVfx.add_material()
	parent.add_child(sp)
	sp.global_position = at + Vector2(randf_range(-10, 10), randf_range(-10, 10)) - sp.size * 0.5
	var life := randf_range(0.35, 0.6)
	var tw := sp.create_tween().set_ignore_time_scale(true)
	# 반짝(크게) → 살짝 꺼짐 → 다시 반짝(작게) → 사라짐. 그동안 천천히 돌며 아래로 조금 흘러내린다
	tw.tween_property(sp, "scale", Vector2.ONE * 1.15, life * 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "scale", Vector2.ONE * 0.35, life * 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sp, "scale", Vector2.ONE * 0.8, life * 0.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sp, "scale", Vector2.ZERO, life * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(sp, "modulate:a", 0.0, life * 0.4)
	var drift := sp.create_tween().set_ignore_time_scale(true).set_parallel()
	drift.tween_property(sp, "rotation", sp.rotation + randf_range(-1.2, 1.2), life)
	drift.tween_property(sp, "position:y", sp.position.y + randf_range(6.0, 18.0), life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(sp.queue_free)


static var _sparkle: Texture2D


## 네 갈래 십자 별빛 (가운데 둥근 빛 + 가는 빛줄기). 흰색, 색은 modulate 로.
static func _sparkle_tex() -> Texture2D:
	if _sparkle == null:
		const N := 48
		var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
		var c := (N - 1) * 0.5
		for y in N:
			for x in N:
				var dx := absf(x - c) / c
				var dy := absf(y - c) / c
				var ray := exp(-dy * 22.0) * maxf(0.0, 1.0 - dx) + exp(-dx * 22.0) * maxf(0.0, 1.0 - dy)
				var core := exp(-(dx * dx + dy * dy) * 30.0)
				var a := clampf(ray * 0.9 + core, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_sparkle = ImageTexture.create_from_image(img)
	return _sparkle


func _free_shadow(d: Dictionary) -> void:
	if is_instance_valid(d.get("shadow")):
		d["shadow"].queue_free()


## 새 판·재시작: 바닥에 남은 결정을 치운다.
func clear() -> void:
	_gen += 1
	for d in drops + _collecting:
		if is_instance_valid(d["node"]):
			d["node"].queue_free()
		_free_shadow(d)
	drops.clear()
	_collecting.clear()


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
