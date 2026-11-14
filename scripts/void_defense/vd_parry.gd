## VOID DEFENSE 패링: 보스의 [패링 공격]을 예고 → 강조된 영웅의 궁극기 단축키(또는 카드 탭)로 받아친다.
##   1) 예비  : 보스가 예비 동작을 한다 (def.window 초, 게임 시간). 별빛도 소리도 없다 — 몸짓과 대상 발밑의 경고 칸만 보고 준비한다.
##      시전  : 일격 직전(def.press 초 전) 보스 눈에서 별이 "팟—칭!" 하고 터진다 (Telegraph). 그 순간 노린 영웅의 분대 카드가 금빛으로 강조된다.
##              press 가 없는 공격(공허 감시자·군주)은 예비 동작이 따로 없어 시작하자마자 별이 뜬다.
##   2) 입력  : 별이 뜬 순간부터 일격이 닿기 전까지 그 영웅의 단축키 Z X C V 또는 카드 탭 → VDBattle.try_ult 가 먼저 try_parry 에 묻는다.
##              궁극기 게이지와 상관없이 받아친다. 다른 영웅의 키는 평소처럼 궁극기로 넘어간다.
##   3) 성공  : 일격이 튕겨 나간다 — 맞부딪친 자리에 별 폭발(Burst), 보스 무력화(기절) + 반격 피해, 영웅 궁극기 게이지 획득.
##      실패  : 일격이 그대로 들어간다 — 큰 피해 + 기절.
## 시전 주기는 VDEnemySkills.tick 이 돌린다 (VDData.PARRY). 보스가 예고 중 기절하거나 대상이 쓰러지면 취소.
##
## 예고·폭발 그림은 컨셉 PSD(assets/컨셉 원화/보스몹 컨셉.psd '몬스터 공격 예고 예시')를 그대로 쓴다:
##   별 star.png + shaders/parry_star.tres · 보라 빛기둥 pillar.png(더하기 두 겹) · 붉은 핵/고리/빛살 shaders/parry_glow.tres.
##   리소스 추출 tools/vfx/extract_parry_fx.py, 셰이더 생성 tools/shaders/build_parry_fx.gd, 배치 상수 vd_parry_layout.gd.
## 연출 수치는 vd_parry_fx.gd (연출 연구실 "패링" 에서 다듬는다).
## 연출 조각(fx_*)은 정적 함수다: 전투(VDBattle) · 연출 연구실 · VFX 쇼룸 칸이 같은 이름의 층(fx_root · ground_fx · vfx · camera · shockwave · audio,
## 있으면 world_top · juice)을 가진 host 를 넘겨 같이 쓴다. 피해·기절 같은 게임 처리는 이 노드의 _strike / _success 만 한다.
class_name VDParry
extends Node

const L := preload("res://scripts/void_defense/vd_parry_layout.gd")
const Fx := preload("res://scripts/void_defense/vd_parry_fx.gd")
const StarShader := preload("res://shaders/parry_star.tres")
const GlowShader := preload("res://shaders/parry_glow.tres")
const GOLD := Color(1.0, 0.9, 0.25)
const HOT := Color(1.0, 0.36, 0.12)
const FX_Z := 66                  # world_top 안: 피해 숫자(60) 위, 팝 글자(70) 아래
const COUNTER_DELAY := 0.14       # 받아친 뒤 반격이 꽂히기까지 (게임 시간)
const EARLY_LOCK := 0.5           # 입력 창이 열리기 전에 누르면 이만큼 입력이 잠긴다 (게임 시간)
const RAM_SHORT := 46.0           # 받아쳤을 때 뿔이 대상 앞 이만큼에서 막힌다 (px)

var b: VDBattle
var active := false
var attacker: VDUnit
var target: VDUnit
var def := {}
var t := 0.0
var window := 1.0
var _resolved := false
var _run := 0
var _tele: Telegraph
var _mark: Node2D
var _open := false                # 입력 창이 열렸다 (def.press 가 있으면 일격 직전 그만큼만 받는다)
var _lock := 0.0                  # 너무 일찍 눌러 입력이 잠긴 시각까지 (t 기준)
var early := 0                    # 테스트용: 너무 일찍 누른 횟수
var _beats := 0                   # 돌진형: 마지막으로 본 날갯짓 횟수 (내려칠 때마다 바닥 먼지)
var _beam := false                # 섬광형(def.style "beam"): 눈에 빛을 모았다가 광선을 쏜다 (공허 응시자의 두 번째 패링 공격)
var _orb: Node2D                  # 섬광형: 눈에 모이는 빛
var cues := 0                     # 테스트용: 별이 뜬 횟수
var _ram := false                 # 돌진형: 예고 동안 물러났다가 뿔로 들이받는다 (공허 응시자)
## 테스트용
var begun := 0
var parried := 0
var failed := 0
var cancelled := 0
var auto_parry := -1.0            # 0..1 이면 창의 그 지점에서 자동으로 받아친다
var last_counter := 0.0           # 마지막 반격 피해


static var _white: ImageTexture


static func white() -> ImageTexture:
	if _white == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	return _white


static func _add_mat() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## 별 한 장 (star.png + parry_star 셰이더). 원점 = 별 가운데.
static func make_star(col_glow := L.COL_STAR_GLOW) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(L.DIR + "star.png")
	var m := ShaderMaterial.new()
	m.shader = StarShader
	m.set_shader_parameter("col_glow", col_glow)
	m.set_shader_parameter("bloom_gain", Fx.g("bloom"))
	s.material = m
	return s


## 수식으로 그리는 빛 사각형 (parry_glow 셰이더): size = 한 변(px).
static func make_glow(size: float, col_glow: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = white()
	s.scale = Vector2.ONE * size / 2.0
	var m := ShaderMaterial.new()
	m.shader = GlowShader
	m.set_shader_parameter("col_glow", col_glow)
	s.material = m
	return s


static func sp(n: CanvasItem, key: String, v: Variant) -> void:
	(n.material as ShaderMaterial).set_shader_parameter(key, v)


## 예고 별: 보스 눈을 따라다닌다. pop() → (urgency 를 매 프레임 넣는다) → close().
## 트윈은 게임 시간을 따른다: 터지는 정점의 히트스탑 동안 가장 크게 부푼 모양으로 멈춰 "쫄깃"하게 읽힌다.
class Telegraph extends Node2D:
	var follow: Callable
	var k := 1.0                  # 원화 px → 월드 px
	var urgency := 0.0            # 0 예고 시작 ~ 1 일격 직전
	var on_ching: Callable
	var _pivot: Node2D            # 숨쉬기 배율 (별·핵)
	var _star: Sprite2D
	var _pillars: Array[Sprite2D] = []
	var _core: Sprite2D
	var _ring: Sprite2D
	var _t := 0.0
	var _closing := false
	var _core_half := 1.0         # 핵 사각형 반폭 (월드 px)

	func _ready() -> void:
		var fx := VDParry.Fx
		var lay := VDParry.L
		z_index = VDParry.FX_Z
		for i in 2:
			var p := Sprite2D.new()
			p.texture = load(lay.DIR + "pillar.png")
			p.material = VDParry._add_mat()
			p.position = lay.PILLAR_OFFSET * k
			p.modulate.a = 0.0
			add_child(p)
			_pillars.append(p)
		_pivot = Node2D.new()
		add_child(_pivot)
		# 붉은 핵: 흰 점(반지름 40) + 붉은 외부 광선(101) — 사각형 반폭을 1 로 본 비율로 넣는다
		var half_art: float = lay.CORE_RADIUS + lay.CORE_GLOW * 2.2
		_core_half = half_art * k * fx.g("core_k")
		_core = VDParry.make_glow(_core_half * 2.0, lay.COL_CORE_GLOW)
		VDParry.sp(_core, "core_r", lay.CORE_RADIUS / half_art)
		VDParry.sp(_core, "glow_r", lay.CORE_GLOW / half_art)
		VDParry.sp(_core, "rays", 6.0)
		_pivot.add_child(_core)
		_ring = VDParry.make_glow(lay.STAR_SIZE.x * 1.5 * k, lay.COL_STAR_GLOW)
		VDParry.sp(_ring, "core_r", 0.0)
		VDParry.sp(_ring, "glow_r", 0.001)
		VDParry.sp(_ring, "col_core", Color.BLACK)
		_ring.visible = false
		add_child(_ring)
		_star = VDParry.make_star()
		_pivot.add_child(_star)
		_star.scale = Vector2.ZERO
		_core.scale = Vector2.ZERO
		_track()

	func _track() -> void:
		if follow.is_valid():
			position = follow.call()

	func _process(delta: float) -> void:
		_t += delta
		_track()
		if _closing:
			return
		# 숨쉬기: 일격이 다가올수록 빠르고 크게 떨린다. 빛은 노랑 → 붉은 주황으로 달아오른다
		var fx := VDParry.Fx
		var lay := VDParry.L
		var beat := sin(_t * lerpf(fx.g("beat_lo"), fx.g("beat_hi"), urgency))
		_pivot.scale = Vector2.ONE * (1.0 + lerpf(fx.g("beat_amp") * 0.35, fx.g("beat_amp"), urgency) * beat)
		VDParry.sp(_star, "danger", smoothstep(0.3, 1.0, urgency))
		VDParry.sp(_star, "glow_gain", fx.g("glow") + 0.6 * urgency + 0.3 * beat)
		VDParry.sp(_core, "glow_r", lay.CORE_GLOW / (lay.CORE_RADIUS + lay.CORE_GLOW * 2.2) * (1.0 + 0.9 * urgency + 0.12 * beat))

	## 팟—칭!: 가로로 쫙 그어지고(팟) → 세로로 솟구쳐 정점에서 멈칫(히트스탑) → 탄성으로 제 모양에 꽂힌다(칭).
	func pop() -> void:
		var fx := VDParry.Fx
		var one := Vector2.ONE * k
		var fat: float = fx.g("fat")
		_star.scale = one * 0.04
		_star.rotation = fx.g("spin")
		VDParry.sp(_star, "flash", 1.0)
		VDParry.sp(_star, "fat", fat)
		var tw := create_tween()
		tw.tween_property(_star, "scale", Vector2(fx.g("slash_x"), fx.g("slash_y")) * k, fx.g("slash_sec")).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(_star, "scale", Vector2(fx.g("rise_x"), fx.g("rise_y")) * k, fx.g("rise_sec")).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_star, "rotation", 0.12, fx.g("rise_sec"))
		tw.tween_callback(_ching)
		tw.tween_property(_star, "scale", one, fx.g("settle_sec")).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_star, "rotation", 0.0, fx.g("settle_sec") * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_method(func(v: float) -> void: VDParry.sp(_star, "fat", v), fat, 0.0, fx.g("settle_sec") * 0.55)
		tw.parallel().tween_method(func(v: float) -> void: VDParry.sp(_star, "flash", v), 1.0, 0.0, fx.g("flash_sec"))
		# 빛기둥: 가늘게 솟았다가 넓게 번지고 자리 잡는다 (두 겹이 살짝 엇박). 터질 때만 진하고, 유지 중엔 별의 노란 빛이 읽히게 옅어진다
		for i in _pillars.size():
			var p := _pillars[i]
			p.scale = Vector2(0.15, 0.5) * k
			var pt := create_tween()
			pt.tween_interval(0.04 + 0.03 * i)
			pt.tween_property(p, "scale", Vector2(fx.g("pillar_wide"), 1.12) * k, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			pt.parallel().tween_property(p, "modulate:a", 1.0, 0.06)
			pt.tween_property(p, "scale", one, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pt.parallel().tween_property(p, "modulate:a", fx.g("pillar_hold"), 0.3)
		# 핵: 별보다 살짝 늦게 툭 튀어나온다 (make_glow 와 같은 배율: 2px 텍스처라 반폭 = scale)
		var full := Vector2.ONE * _core_half
		_core.scale = Vector2.ZERO
		var ct := create_tween()
		ct.tween_interval(fx.g("slash_sec") + fx.g("rise_sec") * 0.7)
		ct.tween_property(_core, "scale", full * 1.7, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ct.tween_property(_core, "scale", full, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ct.parallel().tween_method(func(v: float) -> void: VDParry.sp(_core, "ray_a", v), 1.3, 0.22, 0.4)

	func _ching() -> void:
		# 정점: 고리가 퍼져 나간다
		var a: float = VDParry.Fx.g("ring_a")
		if a > 0.0:
			_ring.visible = true
			var rt := create_tween()
			rt.tween_method(func(v: float) -> void:
				VDParry.sp(_ring, "ring_r", lerpf(0.08, 0.92, 1.0 - pow(1.0 - v, 3.0)))
				VDParry.sp(_ring, "ring_w", lerpf(0.09, 0.02, v))
				VDParry.sp(_ring, "ring_a", a * (1.0 - v)), 0.0, 1.0, VDParry.Fx.g("ring_sec"))
			rt.tween_callback(func() -> void: _ring.visible = false)
		if on_ching.is_valid():
			on_ching.call()

	## 일격 순간(fast) 또는 취소: 바늘 끝부터 가운데로 오그라들며 세로로 가늘게 닫힌다.
	## 실제 시간: 결판 순간의 히트스탑·슬로모션에 붙들려 남지 않게.
	func close(fast := false) -> void:
		if _closing:
			return
		_closing = true
		var sec := 0.07 if fast else 0.13
		var tw := create_tween().set_ignore_time_scale(true)
		tw.tween_method(func(v: float) -> void: VDParry.sp(_star, "fat", -v), 0.0, 1.0, sec)
		tw.parallel().tween_property(_star, "scale", Vector2(0.12, 1.5) * k, sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(_core, "scale", Vector2.ZERO, sec)
		for p in _pillars:
			tw.parallel().tween_property(p, "modulate:a", 0.0, sec * 1.6)
			tw.parallel().tween_property(p, "scale", Vector2(0.2, 1.3) * k, sec * 1.6)
		tw.tween_interval(sec)
		tw.tween_callback(queue_free)


## 패링 성공 폭발: 맞부딪친 자리에서 별 두 장(십자 + 45°)이 크게 터지고 금빛 고리·빛살이 퍼진다. 실제 시간 (히트스탑 중에도 번쩍).
class Burst extends Node2D:
	var k := 1.0

	func _ready() -> void:
		var fx := VDParry.Fx
		var sec: float = fx.g("burst_sec")
		z_index = VDParry.FX_Z + 1
		var glow := VDParry.make_glow(VDParry.L.STAR_SIZE.x * 2.4 * k * fx.g("burst_scale"), VDParry.GOLD)
		VDParry.sp(glow, "core_r", 0.07)
		VDParry.sp(glow, "glow_r", 0.34)
		VDParry.sp(glow, "rays", 12.0)
		add_child(glow)
		var stars: Array[Sprite2D] = []
		for i in 2:
			var s := VDParry.make_star(VDParry.GOLD)
			s.rotation = (PI * 0.25 if i == 1 else 0.0) + randf_range(-0.12, 0.12)
			VDParry.sp(s, "flash", 1.0)
			VDParry.sp(s, "fat", 0.85)
			add_child(s)
			stars.append(s)
		var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
		for i in stars.size():
			var s := stars[i]
			var big: float = (0.6 if i == 1 else 1.0) * fx.g("burst_scale") * k
			s.scale = Vector2(0.1, 0.1) * k
			tw.tween_property(s, "scale", Vector2(big, big) * 1.25, 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			tw.tween_property(s, "scale", Vector2(big * 0.55, big * 1.1), sec - 0.07).set_delay(0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_method(func(v: float) -> void: VDParry.sp(s, "fat", v), 0.85, -1.0, sec - 0.05).set_delay(0.05)
			tw.tween_method(func(v: float) -> void: VDParry.sp(s, "flash", v), 1.0, 0.0, sec * 0.75)
		tw.tween_method(func(v: float) -> void:
			var e := 1.0 - pow(1.0 - v, 3.0)
			VDParry.sp(glow, "ring_r", lerpf(0.05, 0.95, e))
			VDParry.sp(glow, "ring_w", lerpf(0.1, 0.015, v))
			VDParry.sp(glow, "ring_a", 1.8 * (1.0 - v))
			VDParry.sp(glow, "ray_a", 1.6 * (1.0 - v) * (1.0 - v))
			VDParry.sp(glow, "alpha_k", 1.0 - v * v), 0.0, 1.0, sec * 1.1)
		tw.chain().tween_callback(queue_free)


# ---------------------------------------------------------------- 연출 조각 (전투 · 연구실 · 쇼룸 공용)

## 예고·폭발을 그릴 층: 안개 위 월드 레이어가 있으면 거기(전투), 없으면 fx_root.
static func layer_of(h) -> Node:
	var top = h.get("world_top")
	return top if top != null and is_instance_valid(top) else h.fx_root


static func chest(u: VDUnit) -> Vector2:
	return u.position + Vector2(0, u._top * 0.55)


## 예고 별이 놓이는 눈 (월드).
static func eye_of(u: VDUnit) -> Vector2:
	var d: Dictionary = VDData.PARRY.get(u.id, {})
	return u.position + Vector2(u._facing * float(d.get("eye_x", 0.0)), u._top * float(d.get("eye", 0.62)) - lift_of(u))


## 파츠 애니메이션이 유닛을 띄워 올린 높이 (px, 공허 응시자의 패링 예비). 없으면 0.
static func lift_of(u: VDUnit) -> float:
	return float(u._parts.lift_now()) if u._parts != null and u._parts.has_method("lift_now") else 0.0


## 충돌 파편: 굵고 날카로운 쐐기가 방사형으로 튀어 나간다 (만화식 임팩트 스파크). 실제 시간.
class Shards extends Node2D:
	var col := VDParry.GOLD
	var k := 1.0
	var toward := Vector2.ZERO          # 0 이 아니면 그 방향 반대쪽(튕겨 나가는 쪽)으로 더 길게
	var _list: Array[Dictionary] = []
	var _t0 := 0.0
	var SEC := 0.34

	func _ready() -> void:
		z_index = VDParry.FX_Z + 2
		process_mode = Node.PROCESS_MODE_ALWAYS
		_t0 = Time.get_ticks_msec() / 1000.0
		SEC = maxf(VDParry.Fx.g("shard_sec"), 0.05)
		var n := maxi(3, int(VDParry.Fx.g("shard_n")))
		var a0 := randf() * TAU
		for i in n:
			var a := a0 + TAU * i / float(n) + randf_range(-0.16, 0.16)
			var dir := Vector2(cos(a), sin(a))
			var bias := 1.0 + (0.7 * maxf(0.0, -dir.dot(toward)) if toward != Vector2.ZERO else 0.0)
			_list.append({"dir": dir, "len": randf_range(70.0, 150.0) * k * bias * VDParry.Fx.g("shard_len"), "w": randf_range(9.0, 20.0) * k,
				"gap": randf_range(14.0, 30.0) * k, "lag": randf_range(0.0, 0.05), "white": i % 3 != 0})

	func _process(_delta: float) -> void:
		if Time.get_ticks_msec() / 1000.0 - _t0 > SEC + 0.06:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0 - _t0
		for s in _list:
			var p := clampf((t - float(s["lag"])) / SEC, 0.0, 1.0)
			if p <= 0.0 or p >= 1.0:
				continue
			var e := 1.0 - pow(1.0 - p, 4.0)
			var dir: Vector2 = s["dir"]
			var n := dir.orthogonal()
			# 꼬리가 머리를 따라잡으며 짧아진다: 머리는 금방 끝까지, 꼬리는 늦게
			var head: float = float(s["gap"]) + float(s["len"]) * e
			var tail: float = float(s["gap"]) + float(s["len"]) * pow(p, 1.5)
			var w: float = float(s["w"]) * (1.0 - p)
			var mid := lerpf(tail, head, 0.3)
			for pass_i in 2:
				var grow := 5.0 * k if pass_i == 0 else 0.0
				var c := VDParryImpact.INK if pass_i == 0 else (Color.WHITE if s["white"] else col)
				var cols := PackedColorArray([c, c, c])
				var p0 := dir * (tail - grow)
				var p1 := dir * (head + grow * 1.6)
				draw_primitive(PackedVector2Array([p0, dir * mid + n * (w + grow), p1]), cols, PackedVector2Array())
				draw_primitive(PackedVector2Array([p0, p1, dir * mid - n * (w + grow)]), cols, PackedVector2Array())


## 십자 섬광: 가로세로로 길게 번쩍 그어졌다 사라지는 렌즈 플레어 (누를 때를 알리는 신호 · 충돌점). 실제 시간.
static func fx_glint(h, at: Vector2, col := GOLD, k := 1.0) -> void:
	if k <= 0.0:
		return
	var n := Node2D.new()
	n.z_index = FX_Z + 3
	n.position = at
	layer_of(h).add_child(n)
	var one: float = Fx.g("star_scale") * k
	var tw := n.create_tween().set_ignore_time_scale(true).set_parallel(true)
	for i in 2:
		var s := make_star(col)
		sp(s, "flash", 1.0)
		sp(s, "fat", 0.2)
		s.rotation = PI * 0.5 * i
		s.scale = Vector2(0.2, 0.2) * one
		n.add_child(s)
		var wide := Vector2(3.4 if i == 0 else 2.0, 0.34) * one
		tw.tween_property(s, "scale", wide, 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector2(wide.x * 1.25, 0.0), 0.22).set_delay(0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(n.queue_free)


## 충돌 순간의 화면 연출 (있으면): 블러·색수차·집중선 + 굵은 파편.
static func fx_impact(h, at: Vector2, col: Color, amp: float, toward := Vector2.ZERO) -> void:
	var imp = h.get("parry_impact")
	if imp != null and is_instance_valid(imp):
		imp.kick(at, amp, col)
	if Fx.g("hit_shards") > 0.0:
		var sh := Shards.new()
		sh.col = col
		sh.k = Fx.g("hit_shards") * (0.75 + 0.25 * amp)
		sh.toward = toward
		sh.position = at
		layer_of(h).add_child(sh)


## 예고: 보스 눈에 별을 띄우고 팟—칭 (정점에서 히트스탑·슬로모션·줌 펀치·소리). urgency 는 부른 쪽이 0→1 로 넣고, 끝나면 close().
static func fx_telegraph(h, u: VDUnit) -> Telegraph:
	var tele := Telegraph.new()
	tele.k = Fx.g("star_scale")
	var wr: WeakRef = weakref(u)
	tele.follow = func() -> Vector2:
		var x := wr.get_ref() as VDUnit
		return eye_of(x) if x != null else tele.position
	tele.on_ching = func() -> void:
		if not is_instance_valid(h):
			return
		if Fx.g("tele_hitstop") > 0.0:
			h.camera.hitstop(Fx.g("tele_hitstop"))
		if Fx.g("tele_slow_sec") > 0.0:
			h.camera.slowmo(Fx.g("tele_slow_sec"), Fx.g("tele_slow"))
		h.camera.punch(Fx.g("tele_punch"))
		h.camera.shake(Fx.g("tele_shake"))
		h.audio.play("parry_ching", 0.0)
	layer_of(h).add_child(tele)
	tele.pop()
	h.audio.play("parry_warn", 0.0)
	return tele


## 노린 영웅 머리 위의 작은 금빛 별 (필드에서도 누가 대상인지 보이게). 위치는 부른 쪽이 따라 옮긴다 (mark_pos).
static func fx_mark(h, tgt: VDUnit) -> Node2D:
	var n := Node2D.new()
	n.z_index = FX_Z
	var s := make_star(GOLD)
	var one := Vector2.ONE * Fx.g("star_scale") * 0.3
	s.scale = Vector2.ZERO
	n.add_child(s)
	layer_of(h).add_child(n)
	n.position = mark_pos(tgt)
	var tw := n.create_tween()
	tw.tween_interval(0.12)
	tw.tween_property(s, "scale", one * 1.8, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "scale", one, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var spin := n.create_tween().set_loops()
	spin.tween_property(s, "rotation", 0.14, 0.16)
	spin.tween_property(s, "rotation", -0.14, 0.16)
	return n


static func mark_pos(tgt: VDUnit) -> Vector2:
	return tgt.position + Vector2(0, tgt._top - 34.0)


## 일격의 궤적: 한순간 그어지는 빛줄기 (굵게 번쩍 → 가늘어지며 사라짐).
static func fx_slash(h, from: Vector2, to: Vector2, col: Color) -> void:
	for i in 2:
		var ln := Line2D.new()
		ln.points = PackedVector2Array([from, to])
		ln.width = Fx.g("slash_w") * (1.0 if i == 0 else 0.3)
		ln.default_color = Color(col, 0.75) if i == 0 else Color(1, 1, 0.92)
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		ln.material = _add_mat()
		ln.z_index = FX_Z
		layer_of(h).add_child(ln)
		var tw := ln.create_tween().set_ignore_time_scale(true)
		tw.tween_property(ln, "width", 0.0, 0.22 if i == 0 else 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(ln.queue_free)


## 못 받아친 일격이 꽂힌다 (피해·기절은 부른 쪽).
static func fx_strike(h, u: VDUnit, tgt: VDUnit, from := Vector2.INF) -> void:
	var at := chest(tgt)
	fx_slash(h, eye_of(u) if from == Vector2.INF else from, at, HOT)
	h.vfx.spawn("hit_light", h.fx_root, at, Fx.g("fail_light"), randf() * TAU, HOT.lightened(0.2))
	h.vfx.spawn("burst", h.fx_root, at, 0.6, 0.0, HOT)
	var juice = h.get("juice")
	if juice != null:
		juice.scorch(tgt.position + Vector2(0, 4), HOT, 34.0)
	h.shockwave.add(at, "heavy")
	if Fx.g("wave_k") > 0.0:
		h.shockwave.add(at, "slam", 0.56 * Fx.g("wave_k"))
	fx_impact(h, at, HOT, Fx.g("hit_fail"), (at - (eye_of(u) if from == Vector2.INF else from)).normalized())
	h.camera.shake(Fx.g("fail_shake"))
	if Fx.g("fail_hitstop") > 0.0:
		h.camera.hitstop(Fx.g("fail_hitstop"))
	h.camera.punch(Fx.g("fail_punch"))
	h.audio.play("boss_slam", 0.03, 0.0, 0.9)
	h.audio.play("explode", 0.05, -3.0, 1.1)


## 받아쳤다: 일격이 영웅 앞에서 튕기며 별 폭발. 맞부딪친 자리를 돌려준다.
static func fx_clash(h, u: VDUnit, tgt: VDUnit, from := Vector2.INF) -> Vector2:
	var at := chest(tgt)
	var eye := eye_of(u) if from == Vector2.INF else from
	var clash := at + (eye - at).normalized() * 44.0
	fx_slash(h, eye, clash, HOT)
	var burst := Burst.new()
	burst.k = Fx.g("star_scale")
	burst.position = clash
	layer_of(h).add_child(burst)
	if Fx.g("ok_hitstop") > 0.0:
		h.camera.hitstop(Fx.g("ok_hitstop"))
	if Fx.g("ok_slow_sec") > 0.0:
		h.camera.slowmo(Fx.g("ok_slow_sec"), Fx.g("ok_slow"))
	h.camera.punch(Fx.g("ok_punch"))
	h.camera.shake(Fx.g("ok_shake"))
	if Fx.g("wave_k") > 0.0:
		h.shockwave.add(clash, "slam", Fx.g("wave_k"))
	if Fx.g("wave2_k") > 0.0:
		h.shockwave.add(clash, "boss", Fx.g("wave2_k"))
	fx_impact(h, clash, GOLD, 1.0, (clash - eye).normalized())
	fx_glint(h, clash, GOLD, Fx.g("glint"))
	h.vfx.spawn("hit_light", h.fx_root, clash, Fx.g("clash_light"), randf() * TAU, GOLD)
	h.vfx.spawn("burst", h.fx_root, clash, 0.7, 0.0, GOLD.lightened(0.3))
	h.vfx.spawn("shockwave", h.ground_fx, tgt.position, 0.8, 0.0, Color(GOLD, 0.9), Vector2(1.0, 0.5))
	var juice = h.get("juice")
	var imp = h.get("parry_impact")
	if imp != null and is_instance_valid(imp) and Fx.g("hit_type") > 0.0:
		imp.pop(at + Vector2(0, -150.0), "PARRY!")
	elif juice != null:
		juice.pop_world(at + Vector2(0, -112.0), "PARRY!", Color(1.0, 0.93, 0.45), 38.0, 0.6)
	h.audio.play("parry_ok", 0.0)
	h.audio.play("clash", 0.0, 1.0, 1.7)
	return clash


## 반격: 금빛 일섬이 보스에게 꽂힌다 (피해·무력화는 부른 쪽).
static func fx_counter(h, clash: Vector2, u: VDUnit) -> void:
	var hit_at := chest(u)
	fx_slash(h, clash, hit_at, GOLD)
	h.vfx.spawn("hit_light", h.fx_root, hit_at, Fx.g("counter_light"), randf() * TAU, GOLD)
	h.vfx.spawn("burst", h.fx_root, hit_at, 0.6, 0.0, GOLD)
	h.shockwave.add(hit_at, "heavy")
	h.camera.shake(Fx.g("counter_shake"))
	if Fx.g("counter_stop") > 0.0:
		h.camera.hitstop(Fx.g("counter_stop"))
	h.audio.play("knight_hit", 0.05, 2.0, 0.8)


# ---------------------------------------------------------------- 전투

func _init(battle: VDBattle) -> void:
	b = battle
	name = "Parry"


## 패링 공격 시작. 이미 진행 중이거나 궁극기 연출·조준 중이면 false.
func begin(u: VDUnit, tgt: VDUnit, d: Dictionary) -> bool:
	if active or b.ult.active or b.ult_aim.active or not is_instance_valid(u) or not is_instance_valid(tgt) or not tgt.alive:
		return false
	active = true
	_resolved = false
	attacker = u
	target = tgt
	def = d
	t = 0.0
	_open = false
	_lock = 0.0
	window = float(d["window"])
	_run = b._run_id
	begun += 1
	u.casting = true
	u.face(tgt.position.x - u.position.x)
	u.windup(tgt.position, window)
	_ram = String(d.get("style", "")) == "ram" and u._parts != null and u._parts.has_method("parry_windup")
	if _ram:
		# 날개를 격렬히 퍼덕이며 대상에게서 물러난다 (눈은 전부 대상을 쏘아본다)
		u._parts.parry_windup(window)
		u._parts.aim(tgt.position - u.position, window + 0.5)
		_beats = int(u._parts.get("downbeats")) if u._parts.get("downbeats") != null else 0
		if u.floating:
			b.float_move.retreat(u, tgt.position, window * 0.8, Fx.g("ram_back"))
	_beam = String(d.get("style", "")) == "beam" and u._parts != null and u._parts.has_method("beam_windup")
	if _beam:
		# 두 팔을 벌려 눈을 드러내고, 모든 눈이 대상을 쏘아보며 빛을 모은다
		u._parts.beam_windup(window)
		u._parts.aim(tgt.position - u.position, window + 0.5)
		_beam_charge(u)
	# 예비 동작 동안은 별빛도 소리도 없다: 몸짓과 대상 발밑의 경고 칸만 보고 준비한다. 별은 일격 직전(_cue)에 뜬다
	b.ult.spotlight([u, tgt], 0.3, window + 0.45)
	b.juice.telegraph(tgt, window, HOT)
	b.focus.add_heat(u.position, 3.0)
	print("[VD] parry telegraph: %s -> %s (%.2fs)" % [u.display_name, tgt.display_name, window])
	if press_from() <= 0.0:
		_open_window()
	return true


## 섬광형 예비: 눈에 붉은 빛이 커지고 사방에서 빛줄기가 빨려든다 (소리 없음).
func _beam_charge(u: VDUnit) -> void:
	if Fx.g("beam_charge") > 0.0:
		_orb = b.vfx.loop("orb", b.fx_root, eye_of(u), window + 0.1, 0.05, 0.0, HOT, Vector2.ONE, 0.1, 6.0)
		if _orb:
			_orb.create_tween().tween_property(_orb, "scale", _orb.scale * Fx.g("beam_charge"), window).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var n := int(Fx.g("beam_lines"))
	var wr: WeakRef = weakref(u)
	var run := _run
	for i in n:
		var delay := window * 0.9 * float(i) / float(maxi(n, 1))
		b.get_tree().create_timer(delay, false).timeout.connect(func() -> void:
			var x := wr.get_ref() as VDUnit
			if x == null or not active or _resolved or run != _run:
				return
			var a := randf() * TAU
			var ln := Line2D.new()
			var far := Vector2(cos(a), sin(a) * 0.7) * randf_range(150.0, 260.0)
			ln.points = PackedVector2Array([far, far * 0.72])
			ln.width = 5.0
			ln.default_color = Color(HOT.lightened(0.35), 0.85)
			ln.material = _add_mat()
			ln.z_index = FX_Z - 1
			ln.position = eye_of(x)
			layer_of(b).add_child(ln)
			var tw := ln.create_tween()
			tw.tween_method(func(v: float) -> void:
				ln.points = PackedVector2Array([far * (1.0 - v), far * maxf(0.0, 0.72 - v)])
				ln.width = 5.0 * (1.0 - 0.6 * v), 0.0, 1.0, 0.22)
			tw.tween_callback(ln.queue_free))


## 한순간 그어지는 굵은 광선 (섬광형의 일격 · 되받아친 광선).
func _beam_shot(from: Vector2, to: Vector2, col: Color) -> void:
	var beam := VDEnemySkills.Beam.new()
	beam.col = col
	beam.material = _add_mat()
	beam.z_index = FX_Z
	beam.follow = func() -> Array: return [from, to]
	layer_of(b).add_child(beam)
	var w: float = Fx.g("beam_w")
	var tw := beam.create_tween().set_ignore_time_scale(true)
	tw.tween_property(beam, "k", w * 1.4, 0.035)
	tw.tween_property(beam, "k", w, 0.05)
	tw.tween_property(beam, "k", 0.0, maxf(Fx.g("beam_sec"), 0.03)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(beam.queue_free)
	b.audio.play("lightning", 0.0, 4.0, 0.9)


func _process(delta: float) -> void:
	if not active or _resolved:
		return
	if _run != b._run_id or b.state != VDBattle.State.BATTLE or not is_instance_valid(attacker) or not attacker.alive \
			or attacker.stun_timer > 0.0 or not is_instance_valid(target) or not target.alive:
		_cancel()
		return
	t += delta
	var u := clampf(t / window, 0.0, 1.0)
	if is_instance_valid(_tele):
		_tele.urgency = clampf((t - press_from()) / maxf(window - press_from(), 0.05), 0.0, 1.0)
	if _beam:
		attacker.face(target.position.x - attacker.position.x)
		attacker._parts.aim(target.position - attacker.position, 0.5)
		if is_instance_valid(_orb):
			_orb.position = eye_of(attacker)
	if is_instance_valid(_mark):
		_mark.position = mark_pos(target)
	if not _open and t >= press_from():
		_open_window()
	if _ram:
		attacker.face(target.position.x - attacker.position.x)
		attacker._parts.aim(target.position - attacker.position, 0.5)
		_wing_dust(u)
	if auto_parry >= 0.0 and u >= auto_parry:
		try_parry(target.id)
		return
	if t >= window:
		_strike()


## 영웅 hid 의 궁극기 키·카드 입력. 그 영웅이 지금 패링 대상이면 받아치고 true (궁극기는 나가지 않는다).
func try_parry(hid: String) -> bool:
	if not active or _resolved or not is_instance_valid(target) or target.id != hid or not target.alive:
		return false
	if t < press_from():
		# 너무 빨랐다: 입력은 삼키고(궁극기가 헛나가지 않게) 잠깐 잠근다 — 연타로는 못 받아친다
		early += 1
		_lock = t + EARLY_LOCK
		b.juice.pop_world(chest(target) + Vector2(0, -96.0), "너무 빨라!", Color(0.75, 0.8, 1.0), 24.0, 0.45)
		b.audio.play("denied", 0.0)
		return true
	if t < _lock:
		return true
	_success()
	return true


## 입력을 받기 시작하는 시각 (예고 시작 기준). def.press 가 없으면 예고 내내 받는다.
func press_from() -> float:
	return maxf(0.0, window - float(def.get("press", window)))


## 입력 창이 열리는 순간 = 보스가 실제로 일격을 내지르는 순간: 보스 눈에서 별이 팟—칭 터지고(소리·히트스탑·슬로모션),
## 노린 영웅 머리 위 별과 분대 카드 강조가 함께 뜬다. 이 별을 보고 바로 누른다.
func _open_window() -> void:
	_open = true
	cues += 1
	var u := attacker
	var tgt := target
	u._cast_glow = 1.0
	b.juice.pop_world(u.position + Vector2(0, u._top - 54.0 - lift_of(u)), String(def["name"]) + "!", HOT.lightened(0.25), 27.0, 0.5)
	b.nebula_tuner.danger_flash()
	_tele = fx_telegraph(b, u)
	_mark = fx_mark(b, tgt)
	b.frame.parry_mark(tgt.id, true)


## 돌진형 예비: 날개를 내려칠 때마다 발밑 바닥에서 먼지가 일고 바닥이 울린다 (갈수록 세게).
func _wing_dust(urgency: float) -> void:
	var u := attacker
	var n = u._parts.get("downbeats")
	if n == null or int(n) == _beats:
		return
	_beats = int(n)
	if float(u._parts.get("flap_power")) < 0.3:
		return
	var dk: float = Fx.g("dust_k")
	if dk <= 0.0:
		return
	var k := (0.6 + 0.8 * urgency) * dk / 1.5
	var foot := u.position
	var out := signf(u.position.x - target.position.x)
	# 날개 바람이 바닥을 때려 양옆으로 퍼진다: 가운데 한 덩이 + 좌우로 밀려 나가는 두 덩이
	b.vfx.spawn("dust", b.ground_fx, foot + Vector2(randf_range(-12.0, 12.0), randf_range(-4.0, 6.0)), 1.5 * k, 0.0, Color(0.86, 0.8, 1.0, 0.75))
	for side in [-1.0, 1.0]:
		var puff: Node2D = b.vfx.spawn("dust", b.ground_fx, foot + Vector2(side * 46.0, randf_range(-6.0, 10.0)), 1.1 * k, 0.0, Color(0.8, 0.74, 1.0, 0.6))
		if puff != null:
			var tw := puff.create_tween()
			tw.tween_property(puff, "position", puff.position + Vector2(side * Fx.g("dust_spread") * (0.5 + 0.5 * urgency) + out * 30.0, randf_range(-8.0, 14.0)), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _beats % 2 == 0 and Fx.g("dust_ring") > 0.0:
		b.vfx.spawn("shockwave", b.ground_fx, foot, Fx.g("dust_ring") * (0.6 + 0.5 * urgency), 0.0, Color(0.8, 0.72, 1.0, 0.45), Vector2(1.0, 0.5))
	b.camera.shake(Fx.g("dust_shake") * (0.5 + urgency))


func _clear_fx(fast: bool) -> void:
	if is_instance_valid(_tele):
		_tele.close(fast)
	_tele = null
	if is_instance_valid(_mark):
		_mark.queue_free()
	_mark = null
	if is_instance_valid(_orb):
		_orb.queue_free()
	_orb = null


func _cancel() -> void:
	cancelled += 1
	_clear_fx(false)
	if is_instance_valid(target):
		b.frame.parry_mark(target.id, false)
	if is_instance_valid(attacker):
		attacker.release_windup()
		attacker.casting = false
		if _ram or _beam:
			attacker._parts.parry_cancel()
	active = false


## 돌진형: 뿔 끝이 대상 가슴(에서 short 만큼 앞)에 닿도록 순간적으로 들이받는다. 닿을 때까지 기다린 뒤 출발 때의 뿔 끝 자리를 돌려준다.
func _ram_dash(u: VDUnit, h: VDUnit, short: float) -> Vector2:
	var at := chest(h)
	u.face(h.position.x - u.position.x)
	var horn: Vector2 = u._parts.horn_offset()
	horn.x *= -u._facing
	var from := u.position + horn + Vector2(0, -lift_of(u))          # 날아오른 높이에서 내리꽂는다
	var dir := (at - from).normalized()
	u._parts.ram_start(rad_to_deg(atan2(dir.y, absf(dir.x))))
	if u._anim_tween:
		u._anim_tween.kill()
	u._anim_tween = u.create_tween()
	var ram_sec: float = Fx.g("ram_sec")
	u._anim_tween.tween_property(u, "position", at - dir * short - horn, ram_sec).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	u._anim_tween.tween_interval(0.5)   # 닿은 자리에 잠깐 붙든다 (떠다니기가 도로 끌고 가지 않게)
	if Fx.g("ram_dust") > 0.0:
		b.vfx.spawn("shockwave", b.ground_fx, u.position, 0.5 * Fx.g("ram_dust"), 0.0, Color(HOT, 0.8), Vector2(1.0, 0.5))
		b.vfx.spawn("dust", b.ground_fx, u.position, Fx.g("ram_dust"), 0.0, Color(1, 1, 1, 0.8))
	b.audio.play("whoosh", 0.0, 4.0, 0.7)
	b.camera.punch(0.04)
	b.camera.shake(0.3)
	await b.get_tree().create_timer(ram_sec, false).timeout
	return from


## 돌진형: 들이받은 뒤 자세를 풀고 그 자리에서 다시 떠다닌다.
func _ram_recover(u: VDUnit) -> void:
	if not is_instance_valid(u):
		return
	u._parts.ram_end()
	if u._anim_tween:
		u._anim_tween.kill()
	if u.floating:
		b.float_move.warp(u, u.position)


## 못 받아쳤다: 일격이 그대로 들어간다.
func _strike() -> void:
	_resolved = true
	failed += 1
	var u := attacker
	var h := target
	var run := _run
	var ram := _ram
	_clear_fx(true)
	b.frame.parry_mark(h.id, false)
	u.release_windup()
	var from := Vector2.INF
	if ram:
		from = await _ram_dash(u, h, 0.0)
		if run != _run or not is_instance_valid(u) or not u.alive or not is_instance_valid(h):
			_ram_recover(u)
			if is_instance_valid(u):
				u.casting = false
			if run == _run:
				active = false
			return
		u._parts.ram_impact()
	elif _beam:
		u._parts.beam_fire()
		from = eye_of(u)
		_beam_shot(from, chest(h), HOT)
	else:
		u.attack_anim(h.position)
	var at := chest(h)
	fx_strike(b, u, h, from)
	h.last_hit_by = u
	var dealt := h.take_damage(u.atk * float(def["dmg"]))
	b.dmg_log.spawn(at + Vector2(0, -16), int(dealt), true, h)
	if dealt > 0.0:
		b.hurt_glitch.kick(1.0, h.id)
		b.audio.voice(h.id, "hurt")
	if h.alive:
		h.stun(float(def["stun"]))
		b.dmg_log.spawn_status(at + Vector2(0, -50), "기절!", Color(1.0, 0.85, 0.4), h)
	print("[VD] parry failed: %s took %d" % [h.display_name, int(dealt)])
	await b.get_tree().create_timer(0.35, false).timeout
	if ram:
		_ram_recover(u)
	if is_instance_valid(u):
		u.casting = false
		u.atk_timer = 0.0
	if run == _run:
		active = false


## 받아쳤다: 일격이 영웅 앞에서 튕기고, 보스가 무력화된 채 반격을 맞는다.
func _success() -> void:
	_resolved = true
	parried += 1
	var u := attacker
	var h := target
	var run := _run
	var ram := _ram
	_clear_fx(true)
	b.frame.parry_mark(h.id, false, true)
	u.release_windup()
	var from := Vector2.INF
	if ram:
		# 뿔이 영웅 바로 앞에서 막히고, 보스는 튕겨 나간다
		from = await _ram_dash(u, h, RAM_SHORT)
		if run != _run or not is_instance_valid(u) or not u.alive or not is_instance_valid(h):
			_ram_recover(u)
			if is_instance_valid(u):
				u.casting = false
			if run == _run:
				active = false
			return
		u._parts.ram_impact()
		var back := (from - chest(h)).normalized()
		if u._anim_tween:
			u._anim_tween.kill()
		u._anim_tween = u.create_tween()
		u._anim_tween.tween_property(u, "position", u.position + back * Fx.g("ram_bounce") + Vector2(0, -22.0), 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		u._anim_tween.tween_interval(0.4)
	var beam := _beam
	if beam:
		u._parts.beam_fire()
		from = eye_of(u)
	var clash := fx_clash(b, u, h, from)
	if beam:
		_beam_shot(from, clash, HOT)
	h.face(u.position.x - h.position.x)
	h.attack_anim(u.position)
	h.cast_pulse()
	h.gain_ult(float(def.get("ult_gain", 0.0)))
	if Fx.g("ok_flash") > 0.0:
		b.ult.screen_flash(Fx.g("ok_flash"), 0.22)
	b.focus.add_heat(h.position, 3.0)
	print("[VD] parry success: %s (%.2f / %.2fs)" % [h.display_name, t, window])
	# 반격: 한 박자 뒤 금빛 일섬이 보스에게 꽂힌다
	await b.get_tree().create_timer(COUNTER_DELAY, false).timeout
	if run == _run and is_instance_valid(u) and u.alive and is_instance_valid(h):
		var hit_at := chest(u)
		if beam:
			_beam_shot(clash, eye_of(u), GOLD)      # 되받아친 광선이 눈으로 돌아간다
		fx_counter(b, clash, u)
		u.last_hit_by = h
		last_counter = u.take_damage(h.atk * float(def["counter"]) + u.max_hp * float(def["counter_hp"]))
		b.dmg_log.spawn(hit_at + Vector2(0, -16), int(last_counter), true, u)
		if u.alive:
			u.stun(float(def["stagger"]))
			b.dmg_log.spawn_status(hit_at + Vector2(0, -56), "무력화!", Color(1.0, 0.93, 0.45), u)
	if ram:
		await b.get_tree().create_timer(0.3, false).timeout
		_ram_recover(u)
	if is_instance_valid(u):
		u.casting = false
		u.atk_timer = 0.0
	if run == _run:
		active = false


## 새 판·방 이동: 남은 연출을 치운다.
func reset() -> void:
	_run = -1
	_clear_fx(true)
	if is_instance_valid(target) and b.frame:
		b.frame.parry_mark(target.id, false)
	active = false
	_resolved = false
