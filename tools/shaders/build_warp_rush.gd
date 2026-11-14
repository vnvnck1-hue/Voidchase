## 카툰 워프 화면 전환 VisualShader(shaders/warp_rush.tres)를 노드 그래프로 생성한다. 손으로 고치지 말고 이 스크립트를 고쳐 다시 실행.
##   Godot --headless --path . -s res://tools/shaders/build_warp_rush.gd
##
## "워프 다이브"(build_warp_dive.gd)의 두 번째 버전 (2026-11-12, 사용자 요청: 훨씬 속도감 있게 + 카툰 느낌).
## 부드러운 빛 대신 만화 연출로 그린다: 집중선(바깥에서 가운데로 꽂히는 쐐기), 톱니 테두리, 잉크 외곽선, 평면 색 띠, 망점, 스톱모션 박자(tick 마다 선이 새로 그려짐).
## progress 0 → 0.5 (덮기): 장면이 가운데로 확 당겨지며(확대 + 방사 블러 + 색 단계화) 집중선이 꽂히고, 톱니 테두리의 터널이 바깥에서 안으로 닫힌다.
##                          가운데에는 톱니 섬광이 커지고, 끝에서 화면이 번쩍한다.
## progress 0.5 → 1 (걷기): 번쩍임에서 톱니 모양 구멍이 터지듯 열리고(잉크 선 · 흰 띠 · 분홍 띠가 따라 나감), 새 장면이 살짝 튕기며 자리 잡는다.
##
## 그래프: [타이밍] → [장면 샘플] · [터널 색 띠] · [집중선] · [테두리 마스크] (각각 Expression, 함수는 Global Expression 의 wr_*)
##         → 평면 색을 Mix 노드로 차례로 덮어 칠한다 (만화 채색 순서: 바탕 → 선 → 테두리 → 섬광). 색·세기는 uniform (screen_transition_fx.gd 의 wr_*).
## travel(터널이 흘러간 거리)과 tick(스톱모션 프레임 번호)은 러너가 progress 에서 계산해 넣는다.
extends SceneTree

const OUT := "res://shaders/warp_rush.tres"
const F := VisualShader.TYPE_FRAGMENT
const OUT_COLOR := 0
const S := VisualShaderNode.PORT_TYPE_SCALAR
const V2 := VisualShaderNode.PORT_TYPE_VECTOR_2D
const V3 := VisualShaderNode.PORT_TYPE_VECTOR_3D

const GLOBAL_CODE := """
// ---- 카툰 워프 함수. 이름은 모두 wr_ 접두사.
uniform sampler2D wr_screen : hint_screen_texture, repeat_disable, filter_linear;
float wr_hash(float n) { return fract(sin(n * 127.1 + 311.7) * 43758.5453); }
float wr_band(float x, float lo, float hi, float aa) { return smoothstep(lo - aa, lo + aa, x) * (1.0 - smoothstep(hi - aa, hi + aa, x)); }

// 장면: 가운데로 scale 배 당겨 읽고 blur 만큼 안쪽으로 8번 훑는다 (짧고 거친 방사 블러)
vec3 wr_scene(vec2 suv, float scale, float blur, float jit) {
	vec3 acc = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float t = (float(i) + jit) / 8.0;
		acc += texture(wr_screen, vec2(0.5) + (suv - 0.5) * scale * (1.0 - blur * t)).rgb;
	}
	return acc / 8.0;
}

// 톱니: 각도를 n 칸으로 나눠 칸마다 직선 변 가시 하나 (높이는 칸 해시로 변주). 0..1
float wr_spike(float a, float n, float sd) {
	float ac = a / 6.2831853 * n;
	float cell = mod(floor(ac), n);
	float f = abs(fract(ac) - 0.5) * 2.0;
	return (1.0 - f) * mix(0.3, 1.0, wr_hash(cell * 3.7 + sd));
}

// 집중선 한 벌: 각도 n 칸 중 켜진 칸(on)마다 쐐기 하나. 끝(tip)은 반지름 rin 근처(칸마다 다름)이고 바깥으로 갈수록 굵어진다. 가장자리는 1px AA 의 딱딱한 선.
float wr_focus(float r, float a, float n, float rin, float on, float wid, float sd, float vy) {
	float ac = a / 6.2831853 * n;
	float cell = mod(floor(ac), n);
	float f = abs(fract(ac) - 0.5);
	if (wr_hash(cell * 1.31 + sd) > on) return 0.0;
	float tip = rin * mix(0.55, 1.6, wr_hash(cell * 2.3 + sd + 3.0));
	float span = r - tip;
	if (span <= 0.0) return 0.0;
	float w = wid * mix(0.35, 1.0, wr_hash(cell * 3.1 + sd + 5.0)) * clamp(span / 0.45, 0.0, 1.0);
	float aaf = n / (6.2831853 * max(r, 0.003) * vy);
	return 1.0 - smoothstep(w - aaf, w + aaf, f);
}
"""

const TIMING_CODE := """
float x = clamp(p_prog * 2.0, 0.0, 1.0);
float y = clamp(p_prog * 2.0 - 1.0, 0.0, 1.0);
float rmax = 0.5 * length(vec2(p_aspect, 1.0));
o_rmax = rmax;
if (p_prog < 0.5) {
	o_scale = 1.0 - 0.5 * x * x;
	o_blur = 0.5 * pow(x, 1.3);
	o_toon = smoothstep(0.0, 0.3, x);
	o_lon = 0.62 * smoothstep(0.0, 0.3, x);
	o_rin = rmax * mix(0.8, 0.1, pow(x, 0.8));
	o_iris = mix(rmax * 1.3, -0.3, pow(x, 1.7));
	o_burst = x > 0.25 ? 0.3 * pow((x - 0.25) / 0.75, 1.5) : -1.0;
	o_hole = -1.0;
	o_bandk = 1.0;
	o_wide = 0.0;
	o_flash = 0.8 * p_flash * smoothstep(0.86, 1.0, x);
} else {
	float yy = clamp((y - 0.05) / 0.95, 0.0, 1.0);
	float k = 1.0 - yy;
	float e = 1.0 - k * k * k;
	o_scale = 1.0 + 0.2 * exp(-5.0 * yy) * cos(9.0 * yy) * k;   // 살짝 지나쳤다가 튕겨 돌아온다
	o_blur = 0.35 * k * k * k;
	o_toon = 1.0 - smoothstep(0.4, 0.9, yy);
	o_lon = 0.62 * (1.0 - smoothstep(0.3, 0.9, yy));
	o_rin = rmax * mix(0.1, 1.3, yy);
	o_iris = -1.0;
	o_burst = -1.0;
	o_hole = rmax * 1.4 * e - 0.3 * (1.0 - e);
	o_bandk = 1.0 - 0.6 * yy;
	o_wide = 0.35 * k * k * k;
	o_flash = 0.8 * p_flash * exp(-pow(y / 0.08, 2.0));
}
"""

## 장면: 방사 블러로 당겨 읽고 색을 단계로 끊는다 (셀 채색 느낌)
const SCENE_CODE := """
float jit = wr_hash(dot(floor(p_suv * p_view), vec2(1.0, 57.0)) * 0.013 + p_tick);
vec3 c = wr_scene(p_suv, p_scale, p_blur, jit);
vec3 post = floor(c * 5.0 + 0.5) / 5.0;
o_scene = mix(c, post, p_toon * p_toonamt);
"""

## 터널: log 반지름 띠 세 가지 색(바탕 · 중간 · 밝음)이 바깥으로 흐른다. 띠 경계는 톱니로 삐죽. 가장자리로 갈수록 커지는 45° 망점.
const TUNNEL_CODE := """
vec2 q = (p_suv - 0.5) * vec2(p_aspect, 1.0);
float r = max(length(q), 0.002);
float a = atan(q.y, q.x);
float bv = fract(log2(r) * 1.1 - p_travel * 0.5 + 0.16 * wr_spike(a, 16.0, p_seed + 3.0));
float fw = 1.1 * 1.5 / (r * 0.693 * p_view.y);
float tail = 1.0 - smoothstep(1.0 - 2.0 * fw, 1.0, bv);
o_mid = smoothstep(0.5 - fw, 0.5 + fw, bv) * tail;
o_light = smoothstep(0.8 - fw, 0.8 + fw, bv) * tail;
vec2 px = p_suv * p_view;
vec2 gp = vec2(0.70710678 * (px.x - px.y), 0.70710678 * (px.x + px.y)) / 13.0;
float rad = 0.5 * smoothstep(0.35, 1.05, r / p_rmax);
o_dots = rad < 0.04 ? 0.0 : 0.5 * (1.0 - smoothstep(rad - 0.07, rad + 0.07, length(fract(gp) - 0.5)));
"""

## 집중선 세 벌(잉크 · 분홍 · 흰색). tick 마다 씨앗이 바뀌어 프레임마다 새로 그린 선처럼 떨린다.
const LINES_CODE := """
vec2 q = (p_suv - 0.5) * vec2(p_aspect, 1.0);
float r = length(q);
float a = atan(q.y, q.x);
float sd = p_seed + p_tick * 7.3;
float on = p_lon * p_lines;
o_k = wr_focus(r, a, 38.0, p_rin * 1.15, on * 0.7, 0.2, sd + 11.0, p_view.y);
o_p = wr_focus(r, a, 22.0, p_rin * 1.3, on * 0.5, 0.28, sd + 23.0, p_view.y);
o_w = wr_focus(r, a, 60.0, p_rin, on, 0.22, sd, p_view.y);
"""

## 테두리: 덮기 = 바깥에서 닫히는 톱니 터널 경계(잉크 선 + 분홍 띠) + 가운데 톱니 섬광(흰 → 분홍 → 잉크).
##         걷기 = 가운데서 터지는 톱니 구멍. 구멍 밖으로 잉크 선 · 흰 띠 · 분홍 띠 · 잉크 선이 따라 나간다.
const MASK_CODE := """
vec2 q = (p_suv - 0.5) * vec2(p_aspect, 1.0);
float r = length(q);
float a = atan(q.y, q.x);
float aa = 1.5 / p_view.y;
float sd = p_seed + p_tick * 3.1;
float sp = max(wr_spike(a, 10.0, sd), 0.6 * wr_spike(a, 26.0, sd + 7.0));
if (p_prog < 0.5) {
	float d = r - (p_iris + 0.26 * sp);
	o_t = smoothstep(-aa, aa, d);
	o_eink = wr_band(d, -0.018, 0.0, aa);
	o_epink = wr_band(d, 0.0, 0.03, aa);
	float on = step(0.0, p_burst);
	float db = r - p_burst * (0.5 + 0.5 * max(wr_spike(a, 14.0, sd + 19.0), 0.5 * wr_spike(a, 34.0, sd + 29.0)));
	o_bw = on * (1.0 - smoothstep(-aa, aa, db));
	o_bp = on * wr_band(db, 0.0, 0.026, aa);
	o_bk = on * wr_band(db, 0.026, 0.04, aa);
} else {
	float d = r - (p_hole + 0.28 * sp);
	float k = p_bandk;
	float w1 = 0.02 * k;
	float w2 = w1 + 0.09 * k + p_wide;
	float w3 = w2 + 0.04 * k;
	o_t = smoothstep(-aa, aa, d);
	o_eink = wr_band(d, 0.0, w1, aa) * smoothstep(0.02, 0.07, p_hole + 0.28 * sp);
	o_epink = 0.0;
	o_bw = wr_band(d, w1, w2, aa);
	o_bp = wr_band(d, w2, w3, aa);
	o_bk = wr_band(d, w3, w3 + 0.014 * k, aa);
}
"""

var vs: VisualShader
var _next_id := 2
var _col := 0
var _row := 0


func _init() -> void:
	vs = VisualShader.new()
	vs.mode = VisualShader.MODE_CANVAS_ITEM
	_build()
	var err := ResourceSaver.save(vs, OUT)
	print("[warp_rush] saved %s err=%d nodes=%d" % [OUT, err, _next_id - 2])
	quit(0 if err == OK else 1)


func _build() -> void:
	var g := VisualShaderNodeGlobalExpression.new()
	g.set_expression(GLOBAL_CODE)
	g.size = Vector2(900, 900)
	vs.add_node(F, g, Vector2(-2600, -1500), _next_id)
	_next_id += 1

	# --- 파라미터
	var progress := _fparam("progress", 0.0, 0.0, 1.0)
	var travel := _fparam("travel", 0.0, 0.0, 50.0)
	var tick := _fparam("tick", 0.0, 0.0, 200.0)
	var aspect := _fparam("aspect", 1.7778, 0.5, 4.0)
	var seed := _fparam("seed", 0.0, 0.0, 100.0)
	var view := _param(VisualShaderNodeVec2Parameter.new(), "view_size", Vector2(1920, 1080))
	var lines_amt := _fparam("lines_amt", 1.0, 0.0, 1.6)
	var toon_amt := _fparam("toon_amt", 1.0, 0.0, 1.0)
	var flash_amt := _fparam("flash_amt", 1.0, 0.0, 2.0)
	_newcol()
	var c_bg := _cparam("col_bg", Color(0.07, 0.06, 0.25))        # 터널 바탕: 짙은 남보라
	var c_a := _cparam("col_a", Color(0.25, 0.5, 1.0))            # 터널 밝은 띠: 파랑
	var c_b := _cparam("col_b", Color(1.0, 0.3, 0.65))            # 강조: 분홍 (집중선 · 테두리 띠)
	var c_core := _cparam("col_core", Color(1.0, 0.98, 1.0))      # 흰 집중선 · 섬광
	var c_ink := _cparam("col_ink", Color(0.03, 0.02, 0.09))      # 잉크 선 · 망점
	var suv := _input("screen_uv")

	# --- 타이밍
	_newcol()
	var t_outs := ["o_rmax", "o_scale", "o_blur", "o_toon", "o_lon", "o_rin", "o_iris", "o_burst", "o_hole", "o_bandk", "o_wide", "o_flash"]
	var tm := _expr([["p_prog", S], ["p_aspect", S], ["p_flash", S]], t_outs.map(func(n): return [n, S]), TIMING_CODE, [progress, aspect, flash_amt])
	var t := {}
	for i in t_outs.size():
		t[t_outs[i]] = [tm, i]

	# --- 그림 조각 네 개
	_newcol()
	var scene := [_expr([["p_suv", V2], ["p_view", V2], ["p_tick", S], ["p_scale", S], ["p_blur", S], ["p_toon", S], ["p_toonamt", S]],
		[["o_scene", V3]], SCENE_CODE, [suv, view, tick, t["o_scale"], t["o_blur"], t["o_toon"], toon_amt]), 0]
	var tn := _expr([["p_suv", V2], ["p_aspect", S], ["p_view", V2], ["p_travel", S], ["p_seed", S], ["p_rmax", S]],
		[["o_mid", S], ["o_light", S], ["o_dots", S]], TUNNEL_CODE, [suv, aspect, view, travel, seed, t["o_rmax"]])
	var ln := _expr([["p_suv", V2], ["p_aspect", S], ["p_view", V2], ["p_tick", S], ["p_seed", S], ["p_lon", S], ["p_rin", S], ["p_lines", S]],
		[["o_k", S], ["o_p", S], ["o_w", S]], LINES_CODE, [suv, aspect, view, tick, seed, t["o_lon"], t["o_rin"], lines_amt])
	var mk_outs := ["o_t", "o_eink", "o_epink", "o_bw", "o_bp", "o_bk"]
	var mk := _expr([["p_suv", V2], ["p_aspect", S], ["p_view", V2], ["p_prog", S], ["p_tick", S], ["p_seed", S], ["p_iris", S], ["p_burst", S], ["p_hole", S], ["p_bandk", S], ["p_wide", S]],
		mk_outs.map(func(n): return [n, S]), MASK_CODE, [suv, aspect, view, progress, tick, seed, t["o_iris"], t["o_burst"], t["o_hole"], t["o_bandk"], t["o_wide"]])
	var m := {}
	for i in mk_outs.size():
		m[mk_outs[i]] = [mk, i]

	# --- 터널 평면 색: 바탕 → 중간 띠(바탕과 파랑 사이) → 밝은 띠(파랑) → 가장자리 망점(잉크)
	_newcol()
	var mid_col := _mix3(c_bg, c_a, 0.38)
	var tun := _mix3(c_bg, mid_col, [tn, 0])
	tun = _mix3(tun, c_a, [tn, 1])
	tun = _mix3(tun, c_ink, [tn, 2])

	# --- 만화 채색 순서로 덮어 칠한다
	_newcol()
	var col := _mix3(scene, tun, m["o_t"])
	col = _mix3(col, c_ink, [ln, 0])            # 잉크 집중선
	col = _mix3(col, c_b, [ln, 1])              # 분홍 집중선
	col = _mix3(col, c_core, [ln, 2])           # 흰 집중선
	col = _mix3(col, c_ink, m["o_eink"])        # 테두리 잉크 선
	col = _mix3(col, c_b, m["o_epink"])         # 테두리 분홍 띠
	_newcol()
	col = _mix3(col, c_b, m["o_bp"])            # 섬광 · 구멍을 따라 나가는 분홍 띠
	col = _mix3(col, c_ink, m["o_bk"])          # 그 바깥 잉크 선
	col = _mix3(col, c_core, m["o_bw"])         # 흰 섬광 · 흰 띠
	col = _mix3(col, c_core, t["o_flash"])      # 화면 번쩍
	_newcol()
	vs.connect_nodes(F, col[0], col[1], VisualShader.NODE_ID_OUTPUT, OUT_COLOR)


# ------------------------------------------------------------ 노드 헬퍼 (build_comic_wipe.gd 와 같은 꼴)
# 입력은 [노드 id, 포트] 배열이거나 값(포트 기본값으로 들어간다).

func _add(n: VisualShaderNode) -> int:
	var id := _next_id
	_next_id += 1
	vs.add_node(F, n, Vector2(_col * 360 - 1600, _row * 150 - 400), id)
	_row += 1
	return id


func _newcol() -> void:
	_col += 1
	_row = 0


func _feed(id: int, port: int, v) -> void:
	if v is Array:
		vs.connect_nodes(F, v[0], v[1], id, port)
	else:
		vs.get_node(F, id).set_input_port_default_value(port, v)


func _expr(inputs: Array, outputs: Array, code: String, feeds: Array) -> int:
	var n := VisualShaderNodeExpression.new()
	for i in inputs.size():
		n.add_input_port(i, inputs[i][1], inputs[i][0])
	for i in outputs.size():
		n.add_output_port(i, outputs[i][1], outputs[i][0])
	n.set_expression(code)
	n.size = Vector2(620, 60 + 34 * maxi(inputs.size(), outputs.size()))
	var id := _add(n)
	_row += 4
	for i in feeds.size():
		_feed(id, i, feeds[i])
	return id


func _input(name: String) -> Array:
	var n := VisualShaderNodeInput.new()
	n.input_name = name
	return [_add(n), 0]


func _param(n: VisualShaderNodeParameter, name: String, def: Variant) -> Array:
	n.parameter_name = name
	n.set("default_value_enabled", true)
	n.set("default_value", def)
	return [_add(n), 0]


func _fparam(name: String, def: float, lo: float, hi: float) -> Array:
	var n := VisualShaderNodeFloatParameter.new()
	n.parameter_name = name
	n.hint = VisualShaderNodeFloatParameter.HINT_RANGE
	n.min = lo
	n.max = hi
	n.default_value_enabled = true
	n.default_value = def
	return [_add(n), 0]


func _cparam(name: String, def: Color) -> Array:
	var n := VisualShaderNodeColorParameter.new()
	n.parameter_name = name
	n.default_value_enabled = true
	n.default_value = def
	var d := VisualShaderNodeVectorDecompose.new()
	d.op_type = VisualShaderNodeVectorBase.OP_TYPE_VECTOR_4D
	var did := _add(d)
	_feed(did, 0, [_add(n), 0])
	var c := VisualShaderNodeVectorCompose.new()
	c.op_type = VisualShaderNodeVectorBase.OP_TYPE_VECTOR_3D
	var cid := _add(c)
	for i in 3:
		_feed(cid, i, [did, i])
	return [cid, 0]


func _mix3(a, b, w) -> Array:
	var n := VisualShaderNodeMix.new()
	n.op_type = VisualShaderNodeMix.OP_TYPE_VECTOR_3D_SCALAR
	var id := _add(n)
	_feed(id, 0, a)
	_feed(id, 1, b)
	_feed(id, 2, w)
	return [id, 0]


func _op3(op: int, a, b) -> Array:
	var n := VisualShaderNodeVectorOp.new()
	n.op_type = VisualShaderNodeVectorBase.OP_TYPE_VECTOR_3D
	n.operator = op
	var id := _add(n)
	_feed(id, 0, a)
	_feed(id, 1, b)
	return [id, 0]


func _fmul(a, b) -> Array:
	var n := VisualShaderNodeFloatOp.new()
	n.operator = VisualShaderNodeFloatOp.OP_MUL
	var id := _add(n)
	_feed(id, 0, a)
	_feed(id, 1, b)
	return [id, 0]
