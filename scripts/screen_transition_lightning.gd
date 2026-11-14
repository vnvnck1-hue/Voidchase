## 번개 닫힘 화면 전환의 그림 (2026-11-12). 사용자가 한 장씩 그린 4프레임(assets/컨셉 원화/화면 컨셉_4.psd 의 '화면 트랜지션' 그룹,
## gif assets/컨셉 원화/화면-컨셉_4_트랜지션.gif)을 그대로 쓴다: 프레임마다 같은 벡터 도형(번개 쐐기·줄기, 어두운 판 6장, 타원 파편)이
## 자리만 다르므로, 도형 꼭짓점을 키 포즈 K0..K3 로 뽑아(scripts/screen_transition_lightning_data.gd, 생성물) 그 사이를 보간한다.
##   K0 트랜지션_4 (리와인드 프레임 = 가장 벌어진 포즈) → K1 트랜지션_1 (번개가 가운데를 가로지름) → K2 트랜지션_2 (대각선만 남기고 닫힘,
##   지그재그 번개) → K3 트랜지션_3 (다 닫힘, 어두움)
## set_close(c) 의 c 는 닫힘 정도 0(아무것도 없음) → 1(다 덮임). 러너(screen_transition.gd)가 덮을 때 0→1, 걷을 때 같은 길을 1→0 으로
## 되감는다(리와인드). 키 포즈가 놓이는 c 는 KEY_AT, K0 앞은 K0→K1 이동을 거꾸로 늘려 화면 밖에서 들어오게 한다(번개가 판보다 먼저 치고 들어온다).
## 화면 맞춤: 시안(3440x1440)을 화면 중심에 두고 화면을 다 덮도록 같은 비율로 키운다(cover). 16:9 에서는 시안의 좌우가 잘린다.
## 다 덮인 화면은 K3 의 판들이 시안 전체를 덮지만, 비율·보간과 무관하게 빈틈이 없도록 조각 아래에 바탕판(COVER_COLOR)을 K2→K3 사이에 채운다.
## class_name 없음: screen_transition.gd 가 preload 해서 쓴다.
extends Control

const Data := preload("res://scripts/screen_transition_lightning_data.gd")
## 키 포즈 K0..K3 이 놓이는 닫힘 정도. gif 실측(프레임 간격 100ms, 어두운 프레임 200ms)에 맞춘 값: 덮는 시간 0.36초 기준
## K1 ≈ 0.12초 · K2 ≈ 0.20초 · K3 ≈ 0.27초, 그 뒤 ~1.0 은 어두운 프레임 유지.
const KEY_AT := [0.14, 0.32, 0.56, 0.74]
const ENTER_REACH := 3.0     # K0 앞: (K0 - K1) 을 이 배수만큼 더 물린 자리에서 들어온다 (화면 밖)
const ZIG_FADE := 0.03       # 지그재그 번개가 켜지고 꺼지는 c 폭 (손그림 프레임처럼 거의 툭 바뀐다)

var _root: Node2D
var _dim: ColorRect
var _back: ColorRect
var _polys: Array[Polygon2D] = []
var _pts: Array = []          # 조각별 [K0..K3 의 PackedVector2Array] (데이터의 Vector2 배열을 한 번 바꿔 둔 것)
var _zigs: Array[Sprite2D] = []
var _c := -1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim = _plate()
	_back = _plate()
	_root = Node2D.new()
	add_child(_root)
	for p in Data.PIECES:
		var keys := []
		for k in p["pts"]:
			keys.append(PackedVector2Array(k))
		_pts.append(keys)
		var poly := Polygon2D.new()
		poly.antialiased = true
		_root.add_child(poly)
		_polys.append(poly)
	for z in Data.ZIGS:
		var s := Sprite2D.new()
		s.texture = load(z[1])
		s.centered = false
		var r: Rect2 = z[2]
		s.position = r.position
		s.scale = r.size / s.texture.get_size()
		s.visible = false
		_root.add_child(s)
		_zigs.append(s)
	resized.connect(_fit)
	_fit()
	set_close(maxf(_c, 0.0))


func _plate() -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color(0, 0, 0, 0)
	add_child(r)
	return r


func _fit() -> void:
	if _root == null:
		return
	_root.position = size * 0.5
	var k := maxf(size.x / Data.MOCK_SIZE.x, size.y / Data.MOCK_SIZE.y)
	_root.scale = Vector2(k, k)


## c 를 키 포즈 구간으로: [구간 번호 i (−1 = K0 앞), 구간 안 위치 0..1]. i 구간은 K(i) → K(i+1), 마지막 키 뒤는 [3, 0].
static func _segment(c: float) -> Array:
	if c < KEY_AT[0]:
		return [-1, c / KEY_AT[0]]
	for i in 3:
		if c < KEY_AT[i + 1]:
			return [i, (c - KEY_AT[i]) / (KEY_AT[i + 1] - KEY_AT[i])]
	return [3, 0.0]


func set_close(c: float) -> void:
	_c = clampf(c, 0.0, 1.0)
	if _root == null:
		return
	var seg := _segment(_c)
	var i: int = seg[0]
	var f: float = seg[1]
	for n in _polys.size():
		var piece: Dictionary = Data.PIECES[n]
		var pts: Array = _pts[n]
		var cols: Array = piece["col"]
		var kind: int = piece["kind"]
		var poly := _polys[n]
		var alpha := 1.0
		var out: PackedVector2Array
		var col: Color
		if i < 0:
			out = _enter(pts[0], pts[1], kind, f)
			col = cols[0]
			poly.visible = f > 0.0
		elif i >= 3:
			out = pts[3]
			col = cols[3]
			poly.visible = not out.is_empty()
		else:
			var a: PackedVector2Array = pts[i]
			var b: PackedVector2Array = pts[i + 1]
			if b.is_empty():          # 다음 포즈에 없는 조각(번개 쐐기): 제자리에서 빠르게 사라진다
				out = a
				alpha = clampf(1.0 - f / 0.6, 0.0, 1.0)
			else:
				out = _lerp_pts(a, b, f)
			col = (cols[i] as Color).lerp(cols[i + 1], f)
			poly.visible = alpha > 0.0 and not out.is_empty()
		if poly.visible:
			poly.polygon = out
			poly.color = Color(col.r, col.g, col.b, alpha)
	# 지그재그 번개: 제 키 포즈 앞뒤 절반 구간 동안만 보인다 (1번은 K1 둘레, 2번은 K1·K2 중간부터 K3 직전까지)
	for n in _zigs.size():
		var z: Array = Data.ZIGS[n]
		var k: int = z[0]
		var on := lerpf(KEY_AT[k - 1], KEY_AT[k], 0.5)
		var off := lerpf(KEY_AT[k], KEY_AT[k + 1], 0.5 if n < _zigs.size() - 1 else 0.6)
		var a := minf(smoothstep(on, on + ZIG_FADE, _c), 1.0 - smoothstep(off - ZIG_FADE, off, _c)) * float(z[3])
		_zigs[n].visible = a > 0.0
		_zigs[n].modulate.a = a
	# 딤: 0 → K0 의 불투명도 → … (K2·K3 은 밝기/대비 보정으로 어두워진다: 덮임 색 쪽으로)
	var dim_col: Color
	var dim_a: float
	if i < 0:
		dim_col = Data.DIM[0][0]
		dim_a = Data.DIM[0][1] * f
	elif i >= 3:
		dim_col = Data.COVER_COLOR
		dim_a = Data.DIM[3][1]
	else:
		var dark := [0.0, 0.0, 0.45, 1.0]
		dim_col = (Data.DIM[i][0] as Color).lerp(Data.COVER_COLOR, lerpf(dark[i], dark[i + 1], f))
		dim_a = lerpf(Data.DIM[i][1], Data.DIM[i + 1][1], f)
	_dim.color = Color(dim_col.r, dim_col.g, dim_col.b, dim_a)
	# 바탕판: K2 → K3 사이에 차올라 K3 부터는 완전히 불투명 (씬 교체가 비치지 않게)
	var cover := smoothstep(KEY_AT[2], KEY_AT[3], _c)
	_back.color = Color(Data.COVER_COLOR.r, Data.COVER_COLOR.g, Data.COVER_COLOR.b, cover)


## 지금 화면이 완전히 가려져 있는가 (검증용)
func is_opaque() -> bool:
	return _back != null and _back.color.a >= 1.0


static func _lerp_pts(a: PackedVector2Array, b: PackedVector2Array, f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(a.size())
	for j in a.size():
		out[j] = a[j].lerp(b[j], f)
	return out


## K0 앞(f 0 → 1): 번개 쐐기·줄기는 K0→K1 이동 방향의 반대쪽 멀리에서 감속하며 치고 들어오고(먼저 도착),
## 어두운 판은 같은 식으로 일정한 속도로 밀려 들어온다. 타원 파편은 제자리에서 점으로부터 커진다.
static func _enter(k0: PackedVector2Array, k1: PackedVector2Array, kind: int, f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(k0.size())
	if kind == 3:
		var mid := Vector2.ZERO
		for p in k0:
			mid += p
		mid /= maxf(k0.size(), 1.0)
		var g := smoothstep(0.45, 1.0, f)
		for j in k0.size():
			out[j] = mid.lerp(k0[j], g)
		return out
	var e := (1.0 - pow(1.0 - f, 3.0)) if kind == 2 else f
	var back := (1.0 - e) * ENTER_REACH
	for j in k0.size():
		out[j] = k0[j] + (k0[j] - k1[j]) * back
	return out
