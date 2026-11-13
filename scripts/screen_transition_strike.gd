## 번개 화면 전환 두 프리셋의 연출 (2026-11-12): "번개 일섬"(style 0) · "번개 재단"(style 1).
## 사용자가 그린 키 프레임(assets/컨셉 원화/화면-컨셉_4_트랜지션.gif)은 흐름만 잡은 것 — 번개가 대각선으로 먼저 치고 →
## 어두운 판이 그 대각선으로 닫히고 → 어두워진 뒤 → 열린다 — 이라, 그 흐름에 예비 동작·가속·충돌·여운을 넣어 다시 연출했다.
##   일섬: 번개 쐐기가 두 모서리에서 치고 들어옴 → 판이 다가오다 움찔 물러남 → 가속해 쾅 맞물림(섬광·흔들림·지그재그 번개·파편)
##         → 어두운 채 이음매만 남음 → 이음매가 다시 달아오름 → 판이 튕겨 나가듯 열리고 번개는 반대편으로 빠져나감
##   재단: 가는 번개가 화면을 벰 → 베인 두 쪽이 대각선을 따라 어긋남 → 대각선과 나란한 칼날 띠가 바깥부터 엇갈려 꽂힘
##         → 마지막 두 띠가 이음매에서 스치며 섬광 → 이음매 쪽 띠부터 그대로 빠져나가고 어긋난 장면이 출렁이며 제자리로
## 그림은 shaders/lightning_wipe.gdshader, 지그재그 번개는 PSD 원화 텍스처(assets/textures/transition/lightning_zig_1·2.png).
## 여기서는 progress(0 → 0.5 덮기 → 1 걷기)를 셰이더 값으로 바꾸기만 한다: 같은 progress 는 늘 같은 그림(캡처·연구실 정지 화면).
## 조절값은 scripts/screen_transition_fx.gd (sk_* 일섬 · ct_* 재단 · zz_* 공통), 연출 연구실 "화면 전환" 에서 고친다.
## class_name 없음: screen_transition.gd 가 preload 해서 쓴다.
extends Control

const SHADER := preload("res://shaders/lightning_wipe.gdshader")
const Fx := preload("res://scripts/screen_transition_fx.gd")
const Data := preload("res://scripts/screen_transition_lightning_data.gd")
const OVERLAP := 0.07         # 일섬: 다 닫힌 판이 대각선을 넘어 겹치는 깊이 (톱니 변 사이로 빈틈이 안 남게)
const NEAR := 0.34            # 일섬: 판이 다가와 멈칫하는 자리의 틈
const BAND := 0.17            # 일섬: 뒤판이 앞판보다 바깥에 머무는 간격
const FLICKER_FPS := 24.0     # 지그재그 번개가 깜박이는 박자
## 지그재그 번개 깜박임: 충돌 뒤 프레임마다 [어느 그림(-1 = 꺼짐), 불투명도, 좌우 뒤집기]
const ZIG_HIT := [[1, 1.0, false], [0, 0.9, false], [-1, 0.0, false], [1, 0.8, true], [0, 0.55, true], [-1, 0.0, false], [1, 0.35, false]]
const ZIG_OPEN := [[0, 0.7, true], [-1, 0.0, false], [1, 1.0, false], [0, 0.8, false], [1, 0.45, true]]

var style := 0                # 0 일섬 · 1 재단
var _rect: ColorRect
var _mat: ShaderMaterial
var _zig_root: Node2D
var _zigs: Array[Sprite2D] = []
var _p := 0.0
var _opaque := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("style", float(style))
	_rect.material = _mat
	add_child(_rect)
	_zig_root = Node2D.new()
	add_child(_zig_root)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for z in Data.ZIGS:
		var s := Sprite2D.new()
		s.texture = load(z[1])
		var r: Rect2 = z[2]
		s.position = r.get_center()
		s.scale = r.size / s.texture.get_size()
		s.material = add
		s.visible = false
		_zig_root.add_child(s)
		_zigs.append(s)
	resized.connect(_fit)
	_fit()
	set_progress(_p)


func _fit() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_zig_root.position = size * 0.5
	var k := maxf(size.x / Data.MOCK_SIZE.x, size.y / Data.MOCK_SIZE.y)
	_zig_root.scale = Vector2(k, k)


## 지금 화면이 완전히 가려져 있는가
func is_opaque() -> bool:
	return _opaque


func set_progress(p: float) -> void:
	_p = clampf(p, 0.0, 1.0)
	if _mat == null:
		return
	_rect.visible = _p > 0.0 and _p < 1.0
	for z in _zigs:
		z.visible = false
	_opaque = false
	if not _rect.visible:
		return
	for k in ["bolt", "glow", "plate", "dark"]:
		_mat.set_shader_parameter("col_" + k, Fx.col("zz_" + k))
	var v := _strike(_p) if style == 0 else _cut(_p)
	for k in v:
		_mat.set_shader_parameter(k, v[k])


# ── 곡선
static func _sat(x: float) -> float:
	return clampf(x, 0.0, 1.0)


static func _out_expo(x: float) -> float:
	x = _sat(x)
	return 1.0 if x >= 1.0 else 1.0 - pow(2.0, -10.0 * x)


static func _out_pow(x: float, n: float) -> float:
	return 1.0 - pow(1.0 - _sat(x), n)


static func _out_back(x: float, over := 1.9) -> float:
	x = _sat(x) - 1.0
	return 1.0 + (over + 1.0) * x * x * x + over * x * x


static func _out_elastic(x: float) -> float:
	x = _sat(x)
	if x <= 0.0 or x >= 1.0:
		return x
	return pow(2.0, -9.0 * x) * sin((x * 10.0 - 0.75) * TAU / 3.0) + 1.0


## 충돌 뒤 공통: 섬광·흔들림·파편·지그재그 번개. since = 충돌 뒤 지난 덮기 비율, secs = 초
func _impact(v: Dictionary, since: float, secs: float) -> void:
	v["flash"] = 0.62 * Fx.g("zz_flash") * exp(-since * 13.0)
	v["shake"] = 0.028 * Fx.g("zz_shake") * exp(-since * 9.0) * cos(since * 58.0)
	v["spark_t"] = 1.0 - exp(-since * 9.0)
	v["spark_a"] = minf(since * 30.0, 1.0) * 0.9 * minf(Fx.g("zz_sparks"), 1.0)
	_flicker(ZIG_HIT, secs)


func _flicker(frames: Array, secs: float) -> void:
	var i := int(floor(secs * FLICKER_FPS))
	if secs < 0.0 or i >= frames.size():
		return
	var f: Array = frames[i]
	if int(f[0]) < 0:
		return
	var z := _zigs[int(f[0])]
	z.visible = true
	z.modulate.a = clampf(float(f[1]) * Fx.g("zz_zig"), 0.0, 1.0)
	z.flip_h = f[2]
	z.flip_v = f[2]      # 중심 대칭으로 뒤집어야 대각선 방향이 유지된다


# ── 번개 일섬
## 판의 틈: 화면 밖에서 다가옴(감속) → 움찔 물러남 → 가속해 맞물려 겹침
static func _jaw(x: float, lead: float, clash: float, pull: float) -> float:
	var a := lead * 0.85
	var b := maxf(clash - 0.22, a + 0.02)
	if x <= a:
		return lerpf(1.35, NEAR, _out_pow(x / a, 3.0))
	if x <= b:
		return lerpf(NEAR, NEAR + pull, smoothstep(a, b, x))
	return lerpf(NEAR + pull, -OVERLAP, pow(_sat((x - b) / (clash - b)), 2.4))


func _strike(p: float) -> Dictionary:
	var lead := Fx.g("sk_lead")
	var clash := Fx.g("sk_clash")
	var pull := Fx.g("sk_pull")
	var split_k := Fx.g("zz_split")
	var v := {"shear": 0.0, "slit": 0.0, "strips_in": 0.0, "strips_out": 0.0, "flash": 0.0, "shake": 0.0, "spark_t": 0.0, "spark_a": 0.0}
	if p <= 0.5:
		var x := p * 2.0
		var g0 := _jaw(x, lead, clash, pull)
		v["gaps"] = Vector3(g0, _jaw(x - 0.035, lead, clash, pull) + BAND, _jaw(x - 0.07, lead, clash, pull) + BAND * 2.0)
		v["tilt"] = 0.30 * clampf(g0 / NEAR, 0.0, 1.4)
		v["dim"] = 0.42 * smoothstep(0.0, lead, x)
		v["bolt_tip"] = _out_expo(x / lead)
		v["split"] = split_k * (0.004 * smoothstep(0.0, lead, x) + 0.012 * smoothstep(clash - 0.2, clash, x))
		if x < clash:
			v["bolt_w"] = 1.0
			v["bolt_hot"] = 0.35 * smoothstep(clash - 0.12, clash, x)
			v["seam"] = 0.22 * smoothstep(lead * 0.4, lead, x) + 0.5 * smoothstep(clash - 0.1, clash, x)
			v["darken"] = 0.0
			v["back"] = 0.0
		else:
			var since := x - clash
			_opaque = true
			_impact(v, since, since * Fx.g("sk_in_dur"))
			v["bolt_w"] = (1.0 + 0.6 * exp(-since * 30.0)) * (1.0 - smoothstep(0.03, 0.22, since))
			v["bolt_hot"] = exp(-since * 10.0)
			v["seam"] = 0.1 + 1.7 * exp(-since * 9.0)
			v["darken"] = smoothstep(0.0, 0.26, since)
			v["back"] = 1.0
	else:
		var y := (p - 0.5) * 2.0
		var ignite := 0.14
		var yy := _sat((y - ignite) / (1.0 - ignite))
		var g0 := -OVERLAP + 1.5 * _out_pow(yy, 3.0)
		v["gaps"] = Vector3(g0, -OVERLAP + 1.5 * _out_pow(yy - 0.07, 3.0) + BAND, -OVERLAP + 1.5 * _out_pow(yy - 0.14, 3.0) + BAND * 2.0)
		v["tilt"] = -0.30 * clampf(g0 / NEAR, 0.0, 1.4)
		v["dim"] = 0.42 * (1.0 - smoothstep(0.15, 0.85, yy))
		v["spark_t"] = 1.0 + yy * 2.6
		v["spark_a"] = 0.9 * minf(Fx.g("zz_sparks"), 1.0) * (1.0 - smoothstep(0.05, 0.5, yy))
		_flicker(ZIG_OPEN, (y - ignite * 0.35) * Fx.g("sk_out_dur"))
		if y < ignite:
			var r := y / ignite
			_opaque = true
			v["bolt_tip"] = 1.0
			v["bolt_w"] = 0.55 * r * r
			v["bolt_hot"] = r
			v["seam"] = 0.1 + 1.7 * r * r
			v["darken"] = 1.0
			v["back"] = 1.0
			v["split"] = 0.0
			v["shake"] = 0.006 * Fx.g("zz_shake") * r * sin(y * 400.0)
		else:
			v["bolt_tip"] = 1.0 + _out_pow(yy, 2.0)
			v["bolt_w"] = 0.32 * pow(1.0 - yy, 2.0) + 0.5 * exp(-yy * 16.0)
			v["bolt_hot"] = 1.0 - yy
			v["seam"] = 1.8 * exp(-yy * 7.0) * (1.0 - yy)
			v["darken"] = 1.0 - smoothstep(0.0, 0.3, yy)
			v["back"] = 0.0
			v["flash"] = 0.7 * Fx.g("zz_flash") * exp(-yy * 9.0)
			v["shake"] = 0.02 * Fx.g("zz_shake") * exp(-yy * 8.0) * cos(yy * 42.0)
			v["split"] = split_k * 0.016 * pow(1.0 - yy, 2.0)
	return v


# ── 번개 재단
func _cut(p: float) -> Dictionary:
	var clash := Fx.g("ct_clash")
	var cut := 0.03 * Fx.g("ct_cut")
	var split_k := Fx.g("zz_split")
	var v := {"gaps": Vector3(3, 3, 3), "tilt": 0.0, "band_w": Fx.g("ct_band"), "flash": 0.0, "shake": 0.0, "spark_t": 0.0, "spark_a": 0.0}
	if p <= 0.5:
		var x := p * 2.0
		var start := 0.16      # 띠가 꽂히기 시작하는 때
		v["strips_out"] = 0.0
		v["bolt_tip"] = _out_expo(x / 0.16)
		v["shear"] = cut * _out_back((x - 0.06) / 0.2)
		v["slit"] = 0.011 * smoothstep(0.06, 0.2, x)
		v["dim"] = 0.45 * smoothstep(0.0, 0.25, x)
		v["split"] = split_k * (0.014 * exp(-absf(x - 0.1) * 14.0) + 0.004)
		v["strips_in"] = _sat((x - start) / (clash - start))
		if x < clash:
			var beat := 0.75 + 0.25 * sin(x * 190.0)    # 베인 자리의 빛이 떨린다
			v["bolt_w"] = 0.34 * (1.0 + 1.6 * exp(-x * 26.0))
			v["bolt_hot"] = 0.5 + 0.5 * exp(-x * 14.0)
			v["seam"] = 0.95 * smoothstep(0.02, 0.1, x) * beat + 0.6 * exp(-absf(x - 0.08) * 30.0)
			v["flash"] = 0.22 * Fx.g("zz_flash") * exp(-absf(x - 0.07) * 40.0)
			v["darken"] = 0.0
			v["back"] = 0.0
		else:
			var since := x - clash
			_opaque = true
			_impact(v, since, since * Fx.g("ct_in_dur"))
			v["bolt_w"] = 0.9 * exp(-since * 16.0)
			v["bolt_hot"] = exp(-since * 10.0)
			v["seam"] = 0.1 + 1.7 * exp(-since * 9.0)
			v["darken"] = smoothstep(0.0, 0.26, since)
			v["back"] = 1.0
	else:
		var y := (p - 0.5) * 2.0
		var ignite := 0.12
		var yy := _sat((y - ignite) / (1.0 - ignite))
		v["strips_in"] = 1.0
		v["strips_out"] = _sat((y - ignite) / (0.86 - ignite))
		v["slit"] = 0.0
		v["dim"] = 0.45 * (1.0 - smoothstep(0.2, 0.9, yy))
		v["spark_t"] = 1.0 + yy * 2.6
		v["spark_a"] = 0.9 * minf(Fx.g("zz_sparks"), 1.0) * (1.0 - smoothstep(0.05, 0.5, yy))
		_flicker(ZIG_OPEN, (y - ignite * 0.35) * Fx.g("ct_out_dur"))
		if y < ignite:
			var r := y / ignite
			_opaque = true
			v["bolt_tip"] = 1.0
			v["bolt_w"] = 0.4 * r * r
			v["bolt_hot"] = 1.0
			v["seam"] = 0.1 + 1.7 * r * r
			v["darken"] = 1.0
			v["back"] = 1.0
			v["shear"] = -cut
			v["split"] = 0.0
		else:
			v["bolt_tip"] = 1.0 + _out_pow(yy, 2.0)
			v["bolt_w"] = 0.4 * pow(1.0 - yy, 3.0)
			v["bolt_hot"] = 1.0 - yy
			v["seam"] = 1.8 * exp(-yy * 6.0) * (1.0 - yy)
			v["darken"] = 1.0 - smoothstep(0.0, 0.25, yy)
			v["back"] = 0.0
			v["flash"] = 0.5 * Fx.g("zz_flash") * exp(-yy * 10.0)
			v["shake"] = 0.014 * Fx.g("zz_shake") * exp(-yy * 8.0) * cos(yy * 42.0)
			# 어긋나 있던 새 장면이 출렁이며 제자리로
			v["shear"] = -cut * (1.0 - _out_elastic((yy - 0.08) / 0.75))
			v["split"] = split_k * 0.014 * pow(1.0 - yy, 2.0)
	return v
