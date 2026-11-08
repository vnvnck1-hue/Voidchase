## 유물 투사체 연출 (메시 + 셰이더판). VFX연구의 slash_flow 방식: 곡선을 따라 띠 메시를 만들고 그 위로 혜성 쉐입을 UV 오프셋으로 흘린다.
## 성좌판 슬롯(월드 좌표)에서 대상까지 2차 베지어 곡선. 착탄 순간 impact 를 쏜다 (피해·상태이상은 그때 적용).
##   bolt    뇌운 조각 — 슬롯 충전(별 반짝) → 지그재그 띠가 0.06초에 꽂힘(15fps 투스로 떨림) → 자홍/노랑/시안 → 꼬리부터 침식
##   comet   잉걸불   — 불덩이 혜성(카툰 3톤) 이 활처럼 날아감, 꼬리 길이가 늘어남 → 착탄 뒤 머리가 더 흘러 나가며 침식
##   frost   서리 결정 — 시안 혜성 + 양옆 얇은 결정 띠, 착탄 링이 눈꽃(6광선)
##   feather 별 깃털  — 금빛 띠가 좌우로 흔들리며 아군에게, 착탄은 작은 금색 버스트
##   essence 정수병   — 보라 가는 띠 3개가 쓰러진 적에게서 슬롯으로 (버스트 없음, 슬롯에서 반짝)
## 착탄: 버스트 쿼드(relic_burst.gdshader: 깨진 블롭 3톤 + 광선 + 링 + 순백 섬광) + 만화 글자 팝 + ✦ 반짝이.
## 시간·크기·띠 모양·착탄 수치는 P(vd_relic_proj_fx.gd, 연출 연구실 "유물 투사체")에서 읽는다. 색은 아래 STYLE.
class_name VDRelicFx
extends Node2D

signal impact

const RibbonShader := preload("res://shaders/relic_ribbon.gdshader")
const BurstShader := preload("res://shaders/relic_burst.gdshader")
const P := preload("res://scripts/void_defense/relics/vd_relic_proj_fx.gd")
const SEGS := 56               # 띠 메시 세그먼트
static var _quad_tex: ImageTexture


## 셰이더 쿼드용 흰 64×64 텍스처 (PlaceholderTexture2D 는 런타임에 그려지지 않는다).
static func quad_texture() -> ImageTexture:
	if _quad_tex == null:
		var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_quad_tex = ImageTexture.create_from_image(img)
	return _quad_tex

## 유물별 팔레트·형태 (edge → body → core → hot). 목업: 번개 = 자홍·노랑·시안, 서리 = 남색·파랑·시안·흰색.
const STYLE := {
	"bolt": {"edge": Color(0.42, 0.06, 0.55), "body": Color(0.95, 0.25, 0.8), "core": Color(1.0, 0.88, 0.35), "hot": Color(0.8, 1.0, 1.0),
		"ray": Color(1.0, 0.92, 0.3), "burst_body": Color(0.98, 0.35, 0.8), "burst_rim": Color(0.45, 0.08, 0.6), "ring": Color(0.5, 0.95, 1.0),
		"word": "BANG!", "word_col": Color(0.45, 1.0, 0.35)},
	"comet": {"edge": Color(0.62, 0.1, 0.05), "body": Color(1.0, 0.45, 0.08), "core": Color(1.0, 0.82, 0.3), "hot": Color(1.0, 0.98, 0.8),
		"ray": Color(1.0, 0.85, 0.3), "burst_body": Color(1.0, 0.5, 0.12), "burst_rim": Color(0.6, 0.1, 0.05), "ring": Color(1.0, 0.75, 0.3),
		"word": "BURN!", "word_col": Color(1.0, 0.6, 0.2)},
	"frost": {"edge": Color(0.05, 0.12, 0.45), "body": Color(0.15, 0.45, 0.98), "core": Color(0.45, 0.9, 1.0), "hot": Color(0.95, 1.0, 1.0),
		"ray": Color(0.9, 1.0, 1.0), "burst_body": Color(0.35, 0.75, 1.0), "burst_rim": Color(0.08, 0.2, 0.6), "ring": Color(0.8, 0.98, 1.0),
		"word": "FREEZE!", "word_col": Color(0.6, 0.95, 1.0)},
	"feather": {"edge": Color(0.55, 0.3, 0.05), "body": Color(1.0, 0.72, 0.2), "core": Color(1.0, 0.92, 0.55), "hot": Color(1.0, 1.0, 0.9),
		"ray": Color(1.0, 0.95, 0.6), "burst_body": Color(1.0, 0.82, 0.35), "burst_rim": Color(0.6, 0.35, 0.05), "ring": Color(1.0, 0.95, 0.7),
		"word": "GUARD!", "word_col": Color(1.0, 0.9, 0.45)},
	"essence": {"edge": Color(0.3, 0.08, 0.5), "body": Color(0.65, 0.35, 0.95), "core": Color(0.85, 0.65, 1.0), "hot": Color(1.0, 0.95, 1.0),
		"ray": Color(0.9, 0.8, 1.0), "burst_body": Color(0.7, 0.4, 1.0), "burst_rim": Color(0.3, 0.08, 0.5), "ring": Color(0.9, 0.8, 1.0),
		"word": "", "word_col": Color(0.9, 0.8, 1.0)},
}

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
var _burst: Sprite2D
var _burst_mat: ShaderMaterial
var _burst_t0 := -1.0
var _burst_dur := 0.42
var _burst_size := 270.0
var _word: Label
var _sparks: Node2D
var _spark_list := []                     # {pos, t, life, size, col, rot}
var _zig := PackedFloat32Array()          # 번개 지그재그 오프셋 (세그먼트별)
var _zig_t := 0.0
var _size_k := 0.7                        # P.size_k (쏜 순간 값)


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


## 불덩이: 0.46초 비행, 착탄 뒤 0.35초 동안 꼬리가 흘러 나가며 침식.
static func comet(parent: Node, from_: Vector2, to_: Vector2, col: Color, track_ := Callable()) -> VDRelicFx:
	var f := _base(parent, "comet", from_, to_, col, track_)
	f._add_ribbon(0.0, 1.0, 0.0)
	return f


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
	var st: Dictionary = STYLE[kind]
	var mi := MeshInstance2D.new()
	mi.mesh = ArrayMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = RibbonShader
	mat.set_shader_parameter("col_edge", st["edge"])
	mat.set_shader_parameter("col_body", st["body"])
	mat.set_shader_parameter("col_core", st["core"])
	mat.set_shader_parameter("col_hot", st["hot"])
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
	if not _impacted and _t >= flight:
		_impacted = true
		_on_impact()
		impact.emit()
	_update_burst()
	for s in _spark_list:
		s["t"] += dt
	_spark_list = _spark_list.filter(func(s: Dictionary) -> bool: return s["t"] < s["life"])
	_sparks.queue_redraw()


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
	var head := 0.05 + 0.95 * _out(_seg(_t, charge, flight), 2.0)
	var erode := _out(_seg(_t, hold_end, erode_end), 1.4)
	var heat := lerpf(1.0, 0.7, _seg(_t, flight + (hold_end - flight) * 0.55, erode_end - 0.05))
	var width := lerpf(1.25, 0.85, _seg(_t, flight, erode_end - 0.05))
	_drive(r, head, 1.0, erode, heat, 1.0 - _seg(_t, erode_end, erode_end + 0.06), width)


func _update_comet() -> void:
	var r := _ribbons[0]
	# 비행: ease-in-out 으로 던져진 느낌. 꼬리는 0.2 → 0.55 로 길어진다
	var k := _seg(_t, 0.0, flight)
	var head := k * k * (3.0 - 2.0 * k)
	if _t >= flight:
		head = 1.0 + P.k(kind, "overshoot") * _seg(_t, flight, life)   # 착탄 뒤에도 흘러 나간다 (정지감 없음)
	var len_ := lerpf(P.k(kind, "len_start"), P.k(kind, "len_end"), _out(_seg(_t, 0.0, flight * 0.8), 1.6))
	var erode := _out(_seg(_t, flight, flight + P.k(kind, "erode_sec")), 1.3)
	var heat := lerpf(1.0, 0.65, _seg(_t, flight, flight + 0.2))
	_drive(r, head, len_, erode, heat, _seg(_t, 0.0, 0.03) * (1.0 - _seg(_t, life - 0.05, life)), lerpf(0.75, 1.0, _seg(_t, 0.0, 0.15)))
	if _t < flight and _rng.randf() < P.k(kind, "spark_rate"):
		_spark(_pos(head, r["ctrl"]) + Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-14, 14)), _rng.randf_range(5.0, 9.0), STYLE[kind]["core"], 0.3)


func _update_frost() -> void:
	var k := _seg(_t, 0.0, flight)
	var head := _out(k, 1.3)
	var i := 0
	for r in _ribbons:
		var lag: float = r["delay"]
		var kk := _seg(_t - lag, 0.0, flight)
		var h := _out(kk, 1.3)
		if _t - lag >= flight:
			h = 1.0 + P.k(kind, "overshoot") * _seg(_t - lag, flight, life)
		var len_end := P.k(kind, "len_end") * (1.0 if i == 0 else 0.67)
		var len_ := lerpf(P.k(kind, "len_start"), len_end, _out(_seg(_t - lag, 0.0, flight * 0.7), 1.5))
		var erode := _out(_seg(_t - lag, flight, flight + P.k(kind, "erode_sec")), 1.3)
		_drive(r, h, len_, erode, lerpf(1.0, 0.7, _seg(_t - lag, flight, flight + 0.2)), _seg(_t - lag, 0.0, 0.03) * (1.0 - _seg(_t, life - 0.05, life)))
		i += 1
	if _t < flight and _rng.randf() < P.k(kind, "spark_rate"):
		_spark(_pos(head, ctrl) + Vector2(_rng.randf_range(-16, 16), _rng.randf_range(-16, 16)), _rng.randf_range(4.0, 8.0), Color(0.9, 0.98, 1.0), 0.28)


func _update_feather() -> void:
	var r := _ribbons[0]
	var k := _seg(_t, 0.0, flight)
	var head := k * k * (3.0 - 2.0 * k)
	if _t >= flight:
		head = 1.0 + P.k(kind, "overshoot") * _seg(_t, flight, life)
	var len_ := lerpf(P.k(kind, "len_start"), P.k(kind, "len_end"), _out(_seg(_t, 0.0, flight * 0.7), 1.5))
	var erode := _out(_seg(_t, flight, flight + P.k(kind, "erode_sec")), 1.2)
	_drive(r, head, len_, erode, lerpf(1.0, 0.7, _seg(_t, flight, flight + 0.25)), _seg(_t, 0.0, 0.04) * (1.0 - _seg(_t, life - 0.05, life)))
	if _t < flight and _rng.randf() < P.k(kind, "spark_rate"):
		_spark(_pos(head, r["ctrl"]) + Vector2(_rng.randf_range(-18, 18), _rng.randf_range(-18, 18)), _rng.randf_range(5.0, 10.0), Color(1.0, 0.95, 0.6), 0.4)


func _update_essence() -> void:
	for r in _ribbons:
		var lag: float = r["delay"]
		var kk := _seg(_t - lag, 0.0, flight)
		var h := kk * kk * (3.0 - 2.0 * kk)
		if _t - lag >= flight:
			h = 1.0 + P.k(kind, "overshoot") * _seg(_t - lag, flight, life)
		var len_ := lerpf(P.k(kind, "len_start"), P.k(kind, "len_end"), _out(kk, 1.5))
		var erode := _out(_seg(_t - lag, flight - 0.02, flight - 0.02 + P.k(kind, "erode_sec")), 1.2)
		_drive(r, h, len_, erode, 1.0, _seg(_t - lag, 0.0, 0.03) * (1.0 - _seg(_t, life - 0.05, life)))
		if _t - lag > 0.0 and _t - lag < flight and _rng.randf() < P.k(kind, "spark_rate"):
			_spark(_pos(h, r["ctrl"]) + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8)), _rng.randf_range(3.0, 6.0), STYLE[kind]["core"], 0.3)
	if _impacted and _t < flight + 0.3 and _rng.randf() < 0.4:
		_spark(to + Vector2(_rng.randf_range(-22, 22), _rng.randf_range(-22, 22)), _rng.randf_range(4.0, 9.0), STYLE[kind]["hot"], 0.3)


# ---------------------------------------------------------------- impact

func _on_impact() -> void:
	var st: Dictionary = STYLE[kind]
	# 버스트 배율·광선 수(서리 6 = 눈꽃)·글자 크기·반짝이 수/반경은 P 의 종류별 "착탄" 값
	var at := to + (Vector2(0, -36.0) if kind == "feather" else Vector2.ZERO)
	var n := int(P.k(kind, "ring_n"))
	var rr := P.k(kind, "ring_r")
	match kind:
		"bolt":
			_spark_ring(at, n, rr, 10.0, Color(1, 1, 1), 0.35)
		"comet":
			_spark_ring(at, n, rr, 8.0, Color(1.0, 0.9, 0.5), 0.35)
		"frost":
			_spark_ring(at, n, rr, 8.0, Color(0.9, 1.0, 1.0), 0.4)
		"feather":
			_spark_ring(at, n, rr, 7.0, Color(1.0, 0.98, 0.7), 0.45)
		"essence":
			_spark_ring(at, n, rr, 6.0, st["hot"], 0.3)
			return
	if P.k(kind, "burst") > 0.0:
		_spawn_burst(at, P.k(kind, "burst"), P.k(kind, "rays"), 1.0)
	_word_pop(st["word"], st["word_col"], int(P.k(kind, "word")))


func _spawn_burst(at: Vector2, scl: float, rays: float, ring: float) -> void:
	var st: Dictionary = STYLE[kind]
	_burst = Sprite2D.new()
	_burst.texture = quad_texture()
	_burst.position = at
	_burst_size = P.g("burst_size")
	_burst_dur = maxf(P.g("burst_dur"), 0.02)
	_burst.scale = Vector2.ONE * (_burst_size * scl * _size_k / 64.0)
	_burst.rotation = _rng.randf_range(-0.3, 0.3)
	_burst.z_index = 2
	_burst_mat = ShaderMaterial.new()
	_burst_mat.shader = BurstShader
	_burst_mat.set_shader_parameter("col_rim", st["burst_rim"])
	_burst_mat.set_shader_parameter("col_body", st["burst_body"])
	_burst_mat.set_shader_parameter("col_core", Color(1.0, 0.97, 0.85))
	_burst_mat.set_shader_parameter("col_ray", st["ray"])
	_burst_mat.set_shader_parameter("col_ring", st["ring"])
	_burst_mat.set_shader_parameter("rays_count", rays)
	_burst_mat.set_shader_parameter("ring_on", ring)
	_burst_mat.set_shader_parameter("seed", float(_rng.randi_range(1, 500)))
	_burst_mat.set_shader_parameter("t", 0.0)
	_burst.material = _burst_mat
	add_child(_burst)
	_burst_t0 = _t


func _update_burst() -> void:
	if _burst == null:
		return
	var k := (_t - _burst_t0) / _burst_dur
	if k >= 1.0:
		_burst.queue_free()
		_burst = null
		return
	_burst_mat.set_shader_parameter("t", k)


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
	ls.outline_color = Color(0.08, 0.02, 0.14)
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
		_spark(from + Vector2(cos(a), sin(a)) * _rng.randf_range(14.0, 30.0), _rng.randf_range(5.0, 9.0), Color(1.0, 0.95, 0.7), 0.16)


func _draw_sparks() -> void:
	var st: Dictionary = STYLE[kind]
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
		_sparks.draw_colored_polygon(outer, Color(st["edge"], 0.9))
		_sparks.draw_colored_polygon(pts, s["col"])
