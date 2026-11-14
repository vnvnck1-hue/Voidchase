## 유물 투사체 연출 (메시 + 셰이더판). VFX연구의 slash_flow 방식: 곡선을 따라 띠 메시를 만들고 그 위로 혜성 쉐입을 UV 오프셋으로 흘린다.
## 성좌판 슬롯(월드 좌표)에서 대상까지 2차 베지어 곡선. 착탄 순간 impact 를 쏜다 (피해·상태이상은 그때 적용).
##   bolt    뇌운 조각 — 슬롯 충전(별 반짝) → 지그재그 띠가 0.06초에 꽂힘(15fps 투스로 떨림) → 자홍/노랑/시안 → 꼬리부터 침식
##   comet   잉걸불   — VFX연구 flame 셰이더의 궤적판(vfx/flame/flame_trail.tres) 불덩이가 활처럼 날아감. 꼬리 불꽃이 궤적을 따라 휘며 일렁이고(빠를수록 길게)
##                     뒤로 옅은 3톤 띠가 따라붙음 → 착탄 순간 납작하게 퍼지며 침식(erosion)으로 타 없어짐 (BURN!)
##                     2026-11-09 사이파이 교체 때 플라즈마 트레이서로 바뀌었다가 2026-11-10 사용자 요청으로 불덩이로 되돌림. comet.flame_on = 0 이면 꼬리 띠만
##   frost   서리 결정 — 정지장 탄: 청록 트레이서 + 양옆 얇은 레일 띠, 착탄 반짝이 8 + STASIS!
##   feather 별 깃털  — 실드 패킷: 민트색 직선 띠가 아군에게, 착탄은 작은 버스트 + SHIELD!
##   essence 정수병   — 보라 가는 띠 3개가 쓰러진 적에게서 슬롯으로 (버스트 없음, 슬롯에서 반짝)
## 착탄: 몬스터 피격 파티클(VDTouchHit, 터치 게임 데모의 별 섬광 + 번개) + 만화 글자 팝 + ✦ 반짝이.
## 시간·크기·띠 모양·착탄 수치는 P(vd_relic_proj_fx.gd, 연출 연구실 "유물 투사체")에서 읽는다. 색도 P ("종류.col_*", 잉걸불 불꽃은 "comet.fl_*").
class_name VDRelicFx
extends Node2D

signal impact

const RibbonShader := preload("res://shaders/relic_ribbon.gdshader")
const P := preload("res://scripts/void_defense/relics/vd_relic_proj_fx.gd")
const FlameTrailShader := preload("res://vfx/flame/flame_trail.tres")   # VFX연구 flame 셰이더의 궤적판 (tools/shaders/build_flame_trail.gd)
const FlameTrailAddShader := preload("res://vfx/flame/flame_trail_add.tres")   # 같은 그래프의 blend_add 판 (에디티브 글로우 라이팅)
const SEGS := 56               # 띠 메시 세그먼트

## 만화 글자 (색은 P 의 "종류.col_*" — 연출 연구실 "유물 투사체" 의 "5 색"에서 바꾼다)
const WORDS := {"bolt": "BANG!", "comet": "BURN!", "frost": "STASIS!", "feather": "SHIELD!", "essence": ""}

var kind := "bolt"
var from := Vector2.ZERO
var to := Vector2.ZERO
var ctrl := Vector2.ZERO
var track := Callable()
var color := Color.WHITE
var life := 0.8
var flight := 0.5
var _t := 0.0
var _impacted := false
var _rng := RandomNumberGenerator.new()
var _ribbons: Array[Dictionary] = []     # {mesh: MeshInstance2D, mat, ctrl, delay, half_w, side, sway}
var _word: Label
var _sparks: Node2D
var _spark_list := []                     # {pos, t, life, size, col, rot}
var _zig := PackedFloat32Array()          # 번개 지그재그 오프셋 (세그먼트별)
var _zig_t := 0.0
var _size_k := 0.7                        # P.size_k (쏜 순간 값)
var _flame: MeshInstance2D                # 잉걸불 불덩이 (곡선 띠 + 궤적 불꽃 셰이더)
var _flame_mat: ShaderMaterial
var _shade: MeshInstance2D                # 맨 뒤 어두운 글로우 (같은 메시, layer 1)
var _shade_mat: ShaderMaterial
var _light: MeshInstance2D                # 불꽃 바로 아래 에디티브 글로우 라이팅 (같은 메시, layer 2, blend_add 판 셰이더)
var _light_mat: ShaderMaterial
var _flame_hw_k := 2.6                    # 불꽃 띠 반폭 = 반지름 × 이 값
var _flame_arc := PackedFloat32Array()    # 불꽃 띠 정점별 곡선 길이(px)


# ---------------------------------------------------------------- constructors

static func _base(parent: Node, kind_: String, from_: Vector2, to_: Vector2, col: Color, track_: Callable) -> VDRelicFx:
	var f := VDRelicFx.new()
	f.kind = kind_
	f.from = from_
	f.to = to_
	f.color = col
	f.track = track_
	f.z_index = 55
	f._rng.randomize()
	var tm := P.timing(kind_)
	f.flight = tm.x
	f.life = tm.y
	f._size_k = P.g("size_k")
	if kind_ != "essence":
		f._pick_ctrl(P.k(kind_, "curve"))
	parent.add_child(f)
	return f


## 번개: 0.1초 충전 → 0.06초에 꽂힘 → 0.2초 떨며 유지 → 꼬리부터 침식. 총 0.58초.
static func bolt(parent: Node, from_: Vector2, to_: Vector2, col: Color, track_ := Callable()) -> VDRelicFx:
	var f := _base(parent, "bolt", from_, to_, col, track_)
	f._add_ribbon(0.0, 1.0, 0.0)
	return f


## 불덩이: 0.46초 비행 (flame 셰이더 쿼드 + 옅은 꼬리 띠), 착탄 뒤 퍼지며 타 없어짐.
static func comet(parent: Node, from_: Vector2, to_: Vector2, col: Color, track_ := Callable()) -> VDRelicFx:
	var f := _base(parent, "comet", from_, to_, col, track_)
	f._add_ribbon(0.0, 1.0, 0.0)
	if P.k("comet", "flame_on") >= 0.5:   # 기본 켬 (2026-11-10 사용자 요청으로 불덩이 복귀). 0 이면 꼬리 띠만
		f._add_flame()
	return f


## 궤적 불꽃 띠 (메시는 _update_flame 이 매 프레임 곡선을 따라 다시 깐다)
## 같은 메시를 세 층으로 그린다: 맨 뒤 어두운 글로우(layer 1, z -1, 꼬리 띠 아래) · 에디티브 글로우 라이팅(layer 2, z 1, 더하기 블렌드) · 불꽃(layer 0, z 2).
## 빛을 불꽃 위에 얹으면 불꽃 색이 하얗게 날아가서 바로 아래에 둔다 (둘레·바닥만 밝힌다)
func _add_flame() -> void:
	var mesh := ArrayMesh.new()
	var t_off := _rng.randf_range(0.0, 100.0)   # 여러 발이 같은 모양으로 일렁이지 않게 (세 층은 같은 값이라 함께 일렁인다)
	_flame = _flame_layer(mesh, FlameTrailShader, 0.0, 2, t_off)
	_flame_mat = _flame.material
	_flame_mat.set_shader_parameter("core_threshold", P.k(kind, "flame_core"))   # 작게 그려지니 흰 코어를 줄여 주황 몸통이 보이게
	_shade = _flame_layer(mesh, FlameTrailShader, 1.0, -1, t_off)
	_shade_mat = _shade.material
	_shade_mat.set_shader_parameter("shade_width", P.k(kind, "shade_w"))
	_shade_mat.set_shader_parameter("shade_alpha", P.k(kind, "shade_a"))
	_shade_mat.set_shader_parameter("shade_flicker", P.k(kind, "shade_flick"))
	_shade_mat.set_shader_parameter("shade_len", P.k(kind, "shade_len"))
	_shade_mat.set_shader_parameter("shade_color", P.c(kind, "fl_shade"))
	_light = _flame_layer(mesh, FlameTrailAddShader, 2.0, 1, t_off)
	_light_mat = _light.material
	_light_mat.set_shader_parameter("light_width", P.k(kind, "light_w"))
	_light_mat.set_shader_parameter("light_intensity", P.k(kind, "light_i"))
	_light_mat.set_shader_parameter("light_flicker", P.k(kind, "light_flick"))
	# 띠 반폭(반지름 배): 뒤 글로우·빛이 띠 가장자리에서 잘리지 않게
	_flame_hw_k = maxf(2.6, maxf(1.3 + P.k(kind, "shade_w"), 1.15 + P.k(kind, "light_w")))


func _flame_layer(mesh: ArrayMesh, shader: Shader, layer: float, z: int, t_off: float) -> MeshInstance2D:
	var mi := MeshInstance2D.new()
	mi.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("layer", layer)
	mat.set_shader_parameter("time_offset", t_off)
	mat.set_shader_parameter("wave", P.k(kind, "flame_wave"))
	mat.set_shader_parameter("scroll_speed", P.k(kind, "flame_flow"))
	mi.material = mat
	mi.z_index = z
	mi.visible = false
	add_child(mi)
	return mi


static func frost(parent: Node, from_: Vector2, to_: Vector2, col: Color, track_ := Callable()) -> VDRelicFx:
	var f := _base(parent, "frost", from_, to_, col, track_)
	f._add_ribbon(0.0, 1.0, 0.0)
	# 좌우로 따라붙는 얇은 결정 띠 두 가닥 (같은 곡선, 가늘게, 살짝 뒤)
	var sw := P.k("frost", "side_w")
	var so := P.k("frost", "side_off")
	if sw > 0.0:
		f._add_ribbon(0.03, sw, so)
		f._add_ribbon(0.05, sw, -so)
	return f


static func feather(parent: Node, from_: Vector2, to_: Vector2, col: Color, track_ := Callable()) -> VDRelicFx:
	var f := _base(parent, "feather", from_, to_, col, track_)
	f._add_ribbon(0.0, 1.0, 0.0, P.k("feather", "sway"))
	return f


## 정수: from(쓰러진 적) → to(슬롯). 가는 띠 여럿(count)이 제각각 휘어(spread) 제 시간차(stagger)로 들어간다.
static func essence(parent: Node, from_: Vector2, to_: Vector2, col: Color) -> VDRelicFx:
	var f := _base(parent, "essence", from_, to_, col, Callable())
	f._pick_ctrl(0.0)
	var spread := P.k("essence", "spread")
	for i in maxi(1, int(P.k("essence", "count"))):
		var r := f._add_ribbon(i * P.k("essence", "stagger"), 1.0, 0.0)
		var mid := (from_ + to_) * 0.5
		var perp := (to_ - from_).orthogonal().normalized()
		r["ctrl"] = mid + perp * f._rng.randf_range(-spread, spread) + Vector2(0, f._rng.randf_range(-spread * 0.5, 10.0))
	return f


## 제어점: 중간점에서 옆으로 amount×거리, 위로 살짝. 슬롯이 화면 오른쪽 위라 활처럼 보인다.
func _pick_ctrl(amount: float) -> void:
	var d := to - from
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	ctrl = (from + to) * 0.5 + d.orthogonal().normalized() * d.length() * amount * side + Vector2(0, -d.length() * 0.1)


func _add_ribbon(delay: float, w_scale: float, side_off: float, sway := 0.0) -> Dictionary:
	var mi := MeshInstance2D.new()
	mi.mesh = ArrayMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = RibbonShader
	mat.set_shader_parameter("col_edge", P.c(kind, "col_edge"))
	mat.set_shader_parameter("col_body", P.c(kind, "col_body"))
	mat.set_shader_parameter("col_core", P.c(kind, "col_core"))
	mat.set_shader_parameter("col_hot", P.c(kind, "col_hot"))
	mat.set_shader_parameter("seed", float(_rng.randi_range(1, 900)))
	mat.set_shader_parameter("opacity", 0.0)
	# 띠 모양: 종류별 조절값 (번개는 꼬리가 거의 같은 굵기, 불덩이는 꼬리가 불꽃 혀처럼 갈라진다 …)
	for key in ["head_round", "tail_pow", "edge_w", "core_w", "hot_w", "hot_hdr", "distort", "streak_amt", "streak_speed"]:
		mat.set_shader_parameter(key, P.k(kind, key))
	mi.material = mat
	add_child(mi)
	var r := {"mesh": mi, "mat": mat, "ctrl": ctrl, "delay": delay, "half_w": P.k(kind, "half_w") * w_scale * _size_k, "side": side_off * _size_k, "sway": sway * _size_k}
	_ribbons.append(r)
	return r


func _ready() -> void:
	_sparks = Node2D.new()
	_sparks.z_index = 3
	_sparks.draw.connect(_draw_sparks)
	add_child(_sparks)
	if kind == "bolt":
		_charge_sparks()


# ---------------------------------------------------------------- curve

func _pos(k: float, c: Vector2) -> Vector2:
	k = clampf(k, 0.0, 1.0)
	return from.lerp(c, k).lerp(c.lerp(to, k), k)


func _dir(k: float, c: Vector2) -> Vector2:
	return (_pos(minf(k + 0.02, 1.0), c) - _pos(maxf(k - 0.02, 0.0), c)).normalized()


## 띠 메시 재생성: 곡선(+옆 오프셋·흔들림·지그재그)을 따라 일정 반폭의 삼각 스트립. UV.x = k, UV.y = 0/1.
func _build_mesh(r: Dictionary) -> void:
	var mesh: ArrayMesh = r["mesh"].mesh
	mesh.clear_surfaces()
	var c: Vector2 = r["ctrl"]
	var hw: float = r["half_w"]
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var pts: Array[Vector2] = []
	for i in SEGS + 1:
		var k := float(i) / SEGS
		var p := _pos(k, c)
		var d := _dir(k, c)
		var o := d.orthogonal()
		p += o * float(r["side"])
		if r["sway"] > 0.0:
			p += o * sin(k * TAU * 2.0 + _t * 3.0) * float(r["sway"]) * (1.0 - k * 0.5)
		if kind == "bolt" and _zig.size() == SEGS + 1:
			p += o * _zig[i] * sin(k * PI)
		pts.append(p)
	for i in SEGS + 1:
		var d: Vector2
		if i == 0:
			d = (pts[1] - pts[0]).normalized()
		elif i == SEGS:
			d = (pts[SEGS] - pts[SEGS - 1]).normalized()
		else:
			d = ((pts[i] - pts[i - 1]).normalized() + (pts[i + 1] - pts[i]).normalized()).normalized()
			if d.length() < 0.5:
				d = (pts[i + 1] - pts[i - 1]).normalized()
		var o := d.orthogonal() * hw
		var k := float(i) / SEGS
		verts.append(pts[i] + o)
		uvs.append(Vector2(k, 0.0))
		verts.append(pts[i] - o)
		uvs.append(Vector2(k, 1.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)


## 번개 지그재그: 15fps 로 다시 뽑는다 (투스). 큰 꺾임 몇 개 + 작은 잔떨림.
func _rejitter() -> void:
	_zig.resize(SEGS + 1)
	var kinks := int(P.k("bolt", "kinks"))
	var big := maxi(1, _rng.randi_range(kinks - 1, kinks + 1))
	var amp := P.k("bolt", "zig")
	var jit := P.k("bolt", "jitter")
	var knots: Array[float] = []
	for j in big + 2:
		knots.append(0.0 if (j == 0 or j == big + 1) else _rng.randf_range(-amp, amp))
	for i in SEGS + 1:
		var k := float(i) / SEGS * (big + 1)
		var j := int(floor(k))
		var f := k - j
		var a: float = knots[mini(j, big + 1)]
		var b: float = knots[mini(j + 1, big + 1)]
		_zig[i] = lerpf(a, b, f) + _rng.randf_range(-jit, jit)


# ---------------------------------------------------------------- update

func _process(dt: float) -> void:
	_t += dt
	if track.is_valid() and not _impacted:
		var aim = track.call()
		if aim is Vector2:
			to = aim
	# 긴 프레임 하나로 flight 와 life 를 한꺼번에 넘겨도 착탄(피해·보호막)은 반드시 낸다
	if not _impacted and _t >= flight:
		_impacted = true
		_on_impact()
		impact.emit()
	if _t >= life:
		queue_free()
		return
	match kind:
		"bolt":
			_update_bolt(dt)
		"comet":
			_update_comet()
		"frost":
			_update_frost()
		"feather":
			_update_feather()
		"essence":
			_update_essence()
	for r in _ribbons:
		_build_mesh(r)
	if _spark_list.is_empty():
		return
	for s in _spark_list:
		s["t"] += dt
	_spark_list = _spark_list.filter(func(s: Dictionary) -> bool: return s["t"] < s["life"])
	_sparks.queue_redraw()


## 비행 진행 0..1 → 곡선 위 머리 자리 (연구실 "비행 이징" 프리셋, 0 이면 종류별 기본 곡선)
func _fly(x: float) -> float:
	return P.fly(kind, int(P.k(kind, "ease")), x)


static func _seg(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func _out(x: float, p: float) -> float:
	return 1.0 - pow(1.0 - x, p)


func _drive(r: Dictionary, head: float, len_: float, erode: float, heat: float, opacity: float, width := 1.0) -> void:
	var m: ShaderMaterial = r["mat"]
	m.set_shader_parameter("head", head)
	m.set_shader_parameter("len", len_)
	m.set_shader_parameter("erode", erode)
	m.set_shader_parameter("heat", heat)
	m.set_shader_parameter("opacity", opacity)
	m.set_shader_parameter("width_scale", width)
	# 결·노이즈 시간은 15fps 로 홀드 (카툰: 투스)
	var fps := maxf(P.g("step_fps"), 1.0)
	m.set_shader_parameter("flow_t", floorf(_t * fps) / fps)


func _update_bolt(dt: float) -> void:
	var r := _ribbons[0]
	var charge := P.k("bolt", "charge")
	if _t < charge:
		_drive(r, 0.0, 0.5, 0.0, 1.0, 0.0)
		return
	_zig_t -= dt
	if _zig_t <= 0.0 or _zig.is_empty():
		_zig_t = 1.0 / maxf(P.g("step_fps"), 1.0)
		_rejitter()
	# 충전 → 꽂힘(flight 까지): 머리가 메시를 한 번에 휩쓴다. 그 뒤 hold 동안 유지, 그다음 꼬리 → 머리 침식
	var hold_end := flight + P.k("bolt", "hold")
	var erode_end := hold_end + P.k("bolt", "erode")
	var head := 0.05 + 0.95 * _fly(_seg(_t, charge, flight))
	var erode := _out(_seg(_t, hold_end, erode_end), 1.4)
	var heat := lerpf(1.0, 0.7, _seg(_t, flight + (hold_end - flight) * 0.55, erode_end - 0.05))
	var width := lerpf(1.25, 0.85, _seg(_t, flight, erode_end - 0.05))
	_drive(r, head, 1.0, erode, heat, 1.0 - _seg(_t, erode_end, erode_end + 0.06), width)


func _update_comet() -> void:
	var r := _ribbons[0]
	# 비행: 이징(기본 ease-in-out)으로 던져진 느낌. 꼬리는 0.2 → 0.55 로 길어진다
	var k := _seg(_t, 0.0, flight)
	var head := _fly(k)
	if _t >= flight:
		head = 1.0 + P.k(kind, "overshoot") * _seg(_t, flight, life)   # 착탄 뒤에도 흘러 나간다 (정지감 없음)
	var len_ := lerpf(P.k(kind, "len_start"), P.k(kind, "len_end"), _out(_seg(_t, 0.0, flight * 0.8), 1.6))
	var erode := _out(_seg(_t, flight, flight + P.k(kind, "erode_sec")), 1.3)
	var heat := lerpf(1.0, 0.65, _seg(_t, flight, flight + 0.2))
	var fade := _seg(_t, 0.0, 0.03) * (1.0 - _seg(_t, life - 0.05, life))
	_drive(r, head, len_, erode, heat, fade * P.k(kind, "trail"), lerpf(0.75, 1.0, _seg(_t, 0.0, 0.15)))
	_update_flame(k, head, fade)
	if _t < flight and _rng.randf() < P.k(kind, "spark_rate"):
		_spark(_pos(head, r["ctrl"]) + Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-14, 14)), _rng.randf_range(5.0, 9.0), P.c(kind, "col_spark"), 0.3)


## 불덩이: 곡선을 따라 깐 띠 메시(_build_flame_mesh) 위에 궤적 불꽃 셰이더(flame_trail.tres)를 그린다.
## 셰이더 좌표가 '머리에서 곡선을 따라 뒤로 몇 px' 이라 꼬리가 궤적을 따라 휘고, 결이 꼬리 쪽으로 흘러가며 물결친다.
## 비행 중: 머리 = 곡선 위 head 자리, 꼬리 길이는 속도(비행 이징 곡선의 기울기)가 빠를수록 길게, 지나온 거리보다 길어지지 않게.
## 착탄 뒤 erode_sec 동안: 머리가 조금 더 밀려 나가며 불덩이가 커지고(splat) 꼬리가 따라붙어 짧아지며 침식 1 → burn_out 으로 타 없어진다.
func _update_flame(k: float, head: float, fade: float) -> void:
	if _flame == null:
		return
	var r := P.k(kind, "flame_size") * _size_k * 0.3          # 불덩이 반지름 (원본 쿼드에서 불덩이 반폭 = 쿼드 폭의 0.3)
	var tail := P.k(kind, "flame_len") * 3.0                   # 꼬리 길이 (반지름 단위)
	var head_px: float
	if _t < flight:
		var kk := clampf(k, 0.0, 1.0)
		var speed := clampf((_fly(minf(kk + 0.02, 1.0)) - _fly(maxf(kk - 0.02, 0.0))) / 0.04 / 1.5, 0.0, 1.5)   # 이징 곡선의 기울기: 기본 곡선이면 0 → 1 (가운데) → 0
		r *= lerpf(0.55, 1.0, _out(_seg(_t, 0.0, 0.12), 2.0))   # 슬롯에서 튀어나오며 커진다
		tail *= 1.0 + P.k(kind, "speed_stretch") * speed
		_build_flame_mesh(r)
		head_px = _arc_at(head)
		_flame_mat.set_shader_parameter("erosion", 1.0)
	else:
		var e := _out(_seg(_t, flight, flight + P.k(kind, "erode_sec")), 1.3)
		r *= lerpf(1.0, P.k(kind, "splat"), e)
		tail *= lerpf(1.0, 0.35, e)
		_build_flame_mesh(r)
		head_px = _arc_at(1.0) + r * 0.8 * e
		_flame_mat.set_shader_parameter("erosion", lerpf(1.0, P.k(kind, "burn_out"), e))
	# 모양 값은 세 층에 똑같이 (같은 메시)
	for m: ShaderMaterial in [_flame_mat, _shade_mat, _light_mat]:
		m.set_shader_parameter("head_px", head_px)
		m.set_shader_parameter("radius_px", r)
		m.set_shader_parameter("half_w_px", r * _flame_hw_k)
		m.set_shader_parameter("tail_r", clampf(tail, 0.5, maxf(head_px / r - 0.8, 0.5)))   # 출발점에서 잘리지 않게
		m.set_shader_parameter("opacity", fade)
	# 색 타임라인: 출발(_a) → 착탄(_b). col_pow 곡선으로, 착탄 뒤에는 착탄 색 그대로
	var u := pow(_seg(_t, 0.0, flight), P.k(kind, "col_pow"))
	for key in ["head", "mid", "tail", "core", "glow"]:
		_flame_mat.set_shader_parameter(key + "_color", P.c(kind, "fl_%s_a" % key).lerp(P.c(kind, "fl_%s_b" % key), u))
	_light_mat.set_shader_parameter("light_color", P.c(kind, "fl_light_a").lerp(P.c(kind, "fl_light_b"), u))
	# 침식(착탄 뒤 타 없어짐)은 뒤 글로우·빛도 같이 따라가야 불꽃과 함께 갈라진다
	_shade_mat.set_shader_parameter("erosion", _flame_mat.get_shader_parameter("erosion"))
	_light_mat.set_shader_parameter("erosion", _flame_mat.get_shader_parameter("erosion"))
	_flame.visible = true
	_shade.visible = P.k(kind, "shade_a") > 0.0
	_light.visible = P.k(kind, "light_i") > 0.0


## 불꽃 띠 메시: 곡선(0..1) + 착탄점 너머로 끝 방향 연장(불덩이 앞쪽·착탄 뒤 밀려 나감 몫).
## UV.x = 출발점에서 잰 곡선 길이(px), UV.y = 가로 0..1.
func _build_flame_mesh(r: float) -> void:
	var pts: Array[Vector2] = []
	for i in SEGS + 1:
		pts.append(_pos(float(i) / SEGS, ctrl))
	var end_dir := (pts[SEGS] - pts[SEGS - 2]).normalized()
	for j in range(1, 7):
		pts.append(pts[SEGS] + end_dir * r * 4.0 * j / 6.0)
	_flame_arc.resize(pts.size())
	_flame_arc[0] = 0.0
	for i in range(1, pts.size()):
		_flame_arc[i] = _flame_arc[i - 1] + pts[i].distance_to(pts[i - 1])
	var hw := r * _flame_hw_k
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var o := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized().orthogonal() * hw
		verts.append(pts[i] + o)
		uvs.append(Vector2(_flame_arc[i], 0.0))
		verts.append(pts[i] - o)
		uvs.append(Vector2(_flame_arc[i], 1.0))
	var mesh: ArrayMesh = _flame.mesh
	mesh.clear_surfaces()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)


## 곡선 매개변수 k(0..1) 자리의 곡선 길이(px) — _build_flame_mesh 뒤에 부른다
func _arc_at(k: float) -> float:
	var f := clampf(k, 0.0, 1.0) * SEGS
	var i := mini(int(f), SEGS - 1)
	return lerpf(_flame_arc[i], _flame_arc[i + 1], f - i)


func _update_frost() -> void:
	var k := _seg(_t, 0.0, flight)
	var head := _fly(k)
	var i := 0
	for r in _ribbons:
		var lag: float = r["delay"]
		var kk := _seg(_t - lag, 0.0, flight)
		var h := _fly(kk)
		if _t - lag >= flight:
			h = 1.0 + P.k(kind, "overshoot") * _seg(_t - lag, flight, life)
		var len_end := P.k(kind, "len_end") * (1.0 if i == 0 else 0.67)
		var len_ := lerpf(P.k(kind, "len_start"), len_end, _out(_seg(_t - lag, 0.0, flight * 0.7), 1.5))
		var erode := _out(_seg(_t - lag, flight, flight + P.k(kind, "erode_sec")), 1.3)
		_drive(r, h, len_, erode, lerpf(1.0, 0.7, _seg(_t - lag, flight, flight + 0.2)), _seg(_t - lag, 0.0, 0.03) * (1.0 - _seg(_t, life - 0.05, life)))
		i += 1
	if _t < flight and _rng.randf() < P.k(kind, "spark_rate"):
		_spark(_pos(head, ctrl) + Vector2(_rng.randf_range(-16, 16), _rng.randf_range(-16, 16)), _rng.randf_range(4.0, 8.0), P.c(kind, "col_spark"), 0.28)


func _update_feather() -> void:
	var r := _ribbons[0]
	var k := _seg(_t, 0.0, flight)
	var head := _fly(k)
	if _t >= flight:
		head = 1.0 + P.k(kind, "overshoot") * _seg(_t, flight, life)
	var len_ := lerpf(P.k(kind, "len_start"), P.k(kind, "len_end"), _out(_seg(_t, 0.0, flight * 0.7), 1.5))
	var erode := _out(_seg(_t, flight, flight + P.k(kind, "erode_sec")), 1.2)
	_drive(r, head, len_, erode, lerpf(1.0, 0.7, _seg(_t, flight, flight + 0.25)), _seg(_t, 0.0, 0.04) * (1.0 - _seg(_t, life - 0.05, life)))
	if _t < flight and _rng.randf() < P.k(kind, "spark_rate"):
		_spark(_pos(head, r["ctrl"]) + Vector2(_rng.randf_range(-18, 18), _rng.randf_range(-18, 18)), _rng.randf_range(5.0, 10.0), P.c(kind, "col_spark"), 0.4)


func _update_essence() -> void:
	for r in _ribbons:
		var lag: float = r["delay"]
		var kk := _seg(_t - lag, 0.0, flight)
		var h := _fly(kk)
		if _t - lag >= flight:
			h = 1.0 + P.k(kind, "overshoot") * _seg(_t - lag, flight, life)
		var len_ := lerpf(P.k(kind, "len_start"), P.k(kind, "len_end"), _out(kk, 1.5))
		var erode := _out(_seg(_t - lag, flight - 0.02, flight - 0.02 + P.k(kind, "erode_sec")), 1.2)
		_drive(r, h, len_, erode, 1.0, _seg(_t - lag, 0.0, 0.03) * (1.0 - _seg(_t, life - 0.05, life)))
		if _t - lag > 0.0 and _t - lag < flight and _rng.randf() < P.k(kind, "spark_rate"):
			_spark(_pos(h, r["ctrl"]) + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8)), _rng.randf_range(3.0, 6.0), P.c(kind, "col_spark"), 0.3)
	if _impacted and _t < flight + 0.3 and _rng.randf() < 0.4:
		_spark(to + Vector2(_rng.randf_range(-22, 22), _rng.randf_range(-22, 22)), _rng.randf_range(4.0, 9.0), P.c(kind, "col_ring"), 0.3)


# ---------------------------------------------------------------- impact

func _on_impact() -> void:
	# 버스트 배율·광선 수(서리 6 = 눈꽃)·글자 크기·반짝이 수/반경은 P 의 종류별 "착탄" 값
	var at := to + (Vector2(0, -36.0) if kind == "feather" else Vector2.ZERO)
	var n := int(P.k(kind, "ring_n"))
	var rr := P.k(kind, "ring_r")
	match kind:
		"bolt":
			_spark_ring(at, n, rr, 10.0, P.c(kind, "col_ring"), 0.35)
		"comet":
			_spark_ring(at, n, rr, 8.0, P.c(kind, "col_ring"), 0.35)
		"frost":
			_spark_ring(at, n, rr, 8.0, P.c(kind, "col_ring"), 0.4)
		"feather":
			_spark_ring(at, n, rr, 7.0, P.c(kind, "col_ring"), 0.45)
		"essence":
			_spark_ring(at, n, rr, 6.0, P.c(kind, "col_ring"), 0.3)
			return
	if P.k(kind, "burst") > 0.0:
		_spawn_burst(at, P.k(kind, "burst"), P.k(kind, "heavy") >= 0.5)
	_word_pop(WORDS[kind], P.c(kind, "col_word"), int(P.k(kind, "word")))


## 착탄 피격 파티클 (VDTouchHit): 크기 = burst_size × 종류 배율 × size_k (기본 270 × 1 × 0.7 ≈ 전투 보통 타격), 속도 = 0.42 / burst_dur 배.
## 이 연출 노드는 곧 지워지므로 부모(fx_root)에 붙인다. 색 섞기는 몬스터 피격 조절값(tint_k)을 따른다.
func _spawn_burst(at: Vector2, scl: float, heavy: bool) -> void:
	var host: Node = get_parent() if get_parent() else self
	var pos := (position + at) if host != self else at
	VDTouchHit.spawn(host, pos, P.g("burst_size") * scl * _size_k / 420.0, heavy, P.c(kind, "col_spike"), 0.42 / maxf(P.g("burst_dur"), 0.02))


## 만화 글자: 기울어진 채 1.6배에서 튀어나와 0.16초 유지 뒤 위로 빠지며 사라진다.
func _word_pop(text: String, col: Color, size_: int) -> void:
	var size := int(round(size_ * P.g("word_k") * lerpf(1.0, _size_k, 0.6)))   # 글자는 읽혀야 해서 덜 줄인다
	if text == "" or size < 4:
		return
	_word = Label.new()
	_word.text = text
	var ls := LabelSettings.new()
	ls.font = VDData.font()
	ls.font_size = size
	ls.font_color = col
	ls.outline_size = int(size * 0.28)
	ls.outline_color = P.c("", "word_ink")
	ls.shadow_size = 0
	_word.label_settings = ls
	_word.z_index = 4
	_word.position = to + Vector2(18.0, -60.0 - size)
	_word.rotation = deg_to_rad(_rng.randf_range(-14.0, -6.0))
	_word.pivot_offset = Vector2(size * 1.2, size * 0.6)
	_word.scale = Vector2(1.6, 1.6)
	add_child(_word)
	var tw := create_tween()
	tw.tween_property(_word, "scale", Vector2(1.0, 1.0), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(P.g("word_hold"))
	tw.tween_property(_word, "position", _word.position + Vector2(0, -26.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_word, "scale", Vector2(1.15, 0.0), 0.14)
	tw.tween_callback(_word.queue_free)


# ---------------------------------------------------------------- 반짝이 ✦ (하드 엣지 4각 별, 팝)

func _spark(pos: Vector2, size: float, col: Color, life_: float) -> void:
	_spark_list.append({"pos": pos, "t": 0.0, "life": life_, "size": size * _size_k * P.g("spark_k"), "col": col, "rot": _rng.randf_range(-0.4, 0.4)})


func _spark_ring(center: Vector2, n: int, radius: float, size: float, col: Color, life_: float) -> void:
	for i in n:
		var a := TAU * i / n + _rng.randf_range(-0.25, 0.25)
		_spark(center + Vector2(cos(a), sin(a)) * radius * _size_k * _rng.randf_range(0.7, 1.15), size * _rng.randf_range(0.7, 1.3), col, life_ * _rng.randf_range(0.8, 1.2))


## 번개 충전: 슬롯 둘레에 별이 모였다 흩어진다
func _charge_sparks() -> void:
	for i in 6:
		var a := TAU * i / 6.0 + _rng.randf_range(-0.3, 0.3)
		_spark(from + Vector2(cos(a), sin(a)) * _rng.randf_range(14.0, 30.0), _rng.randf_range(5.0, 9.0), P.c("bolt", "col_spark"), 0.16)


func _draw_sparks() -> void:
	for s in _spark_list:
		var k: float = s["t"] / s["life"]
		var pop := sin(k * PI)
		var sz: float = s["size"] * (0.4 + 0.6 * pop)
		if sz < 1.5:   # 너무 작은 별은 삼각분할이 실패한다
			continue
		var p: Vector2 = s["pos"]
		var rot: float = s["rot"] + k * 0.8
		var pts := PackedVector2Array()
		var outer := PackedVector2Array()
		for i in 8:
			var ang := rot + TAU * i / 8.0
			var rr := sz if i % 2 == 0 else sz * 0.3
			pts.append(p + Vector2(cos(ang), sin(ang)) * rr)
			outer.append(p + Vector2(cos(ang), sin(ang)) * (rr + 2.0))
		_sparks.draw_colored_polygon(outer, P.c(kind, "col_edge", 0.9))
		_sparks.draw_colored_polygon(pts, s["col"])
