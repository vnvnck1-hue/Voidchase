## 건너 투사체 '에너지 볼트' VisualShader(vfx/gun_bolt/gun_bolt.tres)를 노드 그래프로 생성한다. 손으로 고치지 말고 이 스크립트를 고쳐 다시 실행.
##   Godot --headless --path . -s res://tools/shaders/build_gun_bolt.gd
## (텍스처가 먼저 있어야 한다: tools/vfx/build_gun_bolt_textures.py → Godot --headless --import)
##
## 가로로 긴 쿼드 한 장에 텍스처 4장을 겹친다 (UV.x 0 = 꼬리, 1 = 촉):
##   bolt_flow   ×2  꼬리 쪽으로 흘러가는 노이즈 (속도·배율이 다른 두 벌) → 굽이침·가장자리 갉기·어두운 틈·청록 줄
##   bolt_shape      실루엣 3겹 거리장 (R 바깥 / G 가운데 / B 코어). 흐름 노이즈로 좌표를 흔들어 읽고 문턱값으로 셀 경계를 낸다.
##                   촉은 칼같이, 꼬리로 갈수록 경계를 풀어 모션 블러처럼 번진다
##   bolt_shards     몸통 둘레에서 뒤로 쓸려 가는 각진 조각
##   bolt_ramp   ×4  길이 방향 색 띠 (바깥 / 가운데 / 코어 / 후광)
## layer = 0 몸통(섞기). layer = 1 이면 후광만 그린다: 같은 그래프를 blend_add 로 한 벌 더 저장(OUT_ADD)해 몸통 아래에 깐다.
## 코드(VDGunBolt)가 넣는 값: len_k(꼬리 길이 비율: 발사 직후 자라고 착탄 뒤 촉으로 빨려 든다) · erosion · opacity · seed
extends SceneTree

const OUT := "res://vfx/gun_bolt/gun_bolt.tres"
const OUT_ADD := "res://vfx/gun_bolt/gun_bolt_add.tres"
const TEX := "res://assets/vfx/void_defense/gun_bolt/"
const BLEND_ADD := 1
const F := VisualShader.TYPE_FRAGMENT
const OUT_COLOR := 0
const OUT_ALPHA := 1
const PV2 := VisualShaderNode.PORT_TYPE_VECTOR_2D
const PV3 := VisualShaderNode.PORT_TYPE_VECTOR_3D
const PV4 := VisualShaderNode.PORT_TYPE_VECTOR_4D
const PS := VisualShaderNode.PORT_TYPE_SCALAR

var vs: VisualShader
var _next_id := 2
var _col := 0
var _row := 0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://vfx/gun_bolt"))
	var bad := 0
	for out in [OUT, OUT_ADD]:
		vs = VisualShader.new()
		vs.mode = VisualShader.MODE_CANVAS_ITEM
		vs.set("flags/unshaded", true)
		if out == OUT_ADD:
			vs.set("modes/blend", BLEND_ADD)
		_next_id = 2
		_col = 0
		_row = 0
		_build()
		var err := ResourceSaver.save(vs, out)
		bad += int(err != OK)
		print("[gun_bolt] saved %s err=%d nodes=%d" % [out, err, _next_id - 2])
	print(vs.get_code().get_slice("void fragment", 0))
	quit(0 if bad == 0 else 1)


func _build() -> void:
	# --- 코드가 매 프레임 넣는 값
	var len_k := _fparam("len_k", 1.0, 0.05, 1.0)
	var erosion := _fparam("erosion", 1.0, 0.0, 4.0)
	var opacity := _fparam("opacity", 1.0, 0.0, 1.0)
	var seed := _fparam("seed", 0.0, 0.0, 100.0)
	var layer := _fparam("layer", 0.0, 0.0, 1.0)
	# --- 결
	_newcol()
	var flow_speed := _fparam("flow_speed", 2.2, 0.0, 8.0)
	var wave := _fparam("wave", 0.07, 0.0, 0.3)
	var flutter := _fparam("flutter", 0.02, 0.0, 0.2)
	var bend := _fparam("bend", 0.07, -0.3, 0.3)
	var edge_hard := _fparam("edge_hard", 0.012, 0.001, 0.1)
	var edge_soft := _fparam("edge_soft", 0.13, 0.001, 0.4)
	var slit_k := _fparam("slit_k", 0.75, 0.0, 1.0)
	var cyan_k := _fparam("cyan_k", 0.5, 0.0, 1.0)
	var shard_k := _fparam("shard_k", 0.5, 0.0, 1.0)
	var glow_w := _fparam("glow_width", 0.2, 0.01, 0.5)
	var glow_a := _fparam("glow_alpha", 0.5, 0.0, 2.0)
	var core_boost := _fparam("core_boost", 0.0, 0.0, 2.0)
	_newcol()
	var c_slit := _cparam("slit_color", Color(0.10, 0.09, 0.36))
	var c_cyan := _cparam("cyan_color", Color(0.36, 0.92, 0.86))
	var c_tint := _cparam("tint", Color(1, 1, 1))
	# --- 좌표: 흐름 노이즈 두 벌 (꼬리 쪽으로 흘러간다)
	_newcol()
	var coords := _expr(
		[["uv", PV2], ["time", PS], ["seed", PS], ["flow_speed", PS], ["len_k", PS], ["bend", PS]],
		[["uv_a", PV2], ["uv_b", PV2], ["flow_t", PS]],
		"""flow_t = time * flow_speed + seed * 3.7;
// 볼트가 짧을 때(len_k 작음)도 결 크기는 그대로: 촉 기준 거리로 읽는다
float back = (1.0 - uv.x);
// 결이 일직선으로 흐르지 않게: 꼬리로 갈수록 휘고(bend), 위아래로 부챗살처럼 벌어진다
float arc = bend * back * back * 2.2;
float fan = 1.0 / (1.0 + back * 0.55);
float yc = (uv.y - 0.5) * fan + 0.5 + arc;
uv_a = fract(vec2(-back * 0.9 + flow_t * 0.55 + seed * 0.37, yc * 0.9 + seed * 0.61));
uv_b = fract(vec2(-back * 1.6 + flow_t * 0.9 + seed * 0.83, yc * 1.4 + seed * 0.29));""",
		[_input("uv"), _input("time"), seed, flow_speed, len_k, bend])
	_newcol()
	var flow_a := _tex("bolt_flow.png", [coords, 0])
	var flow_b := _tex("bolt_flow.png", [coords, 1])
	# --- 실루엣을 읽을 좌표 (굽이침) + 조각·색 띠 좌표
	_newcol()
	var warp := _expr(
		[["uv", PV2], ["fa", PV4], ["fb", PV4], ["flow_t", PS], ["len_k", PS], ["wave", PS], ["flutter", PS], ["seed", PS], ["bend", PS]],
		[["shape_uv", PV2], ["shard_uv", PV2], ["ramp_out", PV2], ["ramp_mid", PV2], ["ramp_core", PV2], ["ramp_glow", PV2], ["along", PS]],
		"""float lk = max(len_k, 0.05);
// 꼬리를 len_k 만큼만 남긴다: 촉(1)은 그대로, 뒤쪽이 촉으로 당겨진다
along = 1.0 - (1.0 - uv.x) / lk;
float tailw = clamp(1.0 - along, 0.0, 1.0);
float n = fa.r - 0.5;
float m = fb.g - 0.5;
// 촉은 거의 안 흔들리고 꼬리로 갈수록 크게 굽이친다
// (세로로 잘게 변하는 노이즈로 흔들면 줄마다 따로 밀려 가장자리가 계단처럼 찢어진다 → 세로로 매끈한 물결만 쓴다)
float sway = (sin(along * 6.0 + flow_t * 2.6 + seed) + 0.6 * sin(along * 13.0 + flow_t * 4.3 + seed * 2.1)) * wave * 0.5 * (0.05 + 1.2 * tailw * tailw);
sway += sin(along * 23.0 + flow_t * 7.0) * flutter * tailw * tailw;
// 꼬리 전체가 완만하게 휜다 (곧은 창이 아니라 살짝 처진 불꽃 꼬리)
sway += bend * tailw * tailw;
shape_uv = clamp(vec2(along, uv.y + sway), vec2(0.003), vec2(0.997));
shard_uv = fract(vec2(along * 2.3 + flow_t * 0.16 + seed * 0.53, uv.y * 1.7 + sway * 0.4));
float rx = clamp(along + n * 0.10 * (0.3 + tailw), 0.01, 0.99);
ramp_out = vec2(rx, 0.125);
ramp_mid = vec2(rx, 0.375);
ramp_core = vec2(clamp(along + m * 0.10, 0.01, 0.99), 0.625);
ramp_glow = vec2(clamp(along, 0.01, 0.99), 0.875);""",
		[_input("uv"), flow_a, flow_b, [coords, 2], len_k, wave, flutter, seed, bend])
	_newcol()
	var shape := _tex("bolt_shape.png", [warp, 0])
	var shards := _tex("bolt_shards.png", [warp, 1])
	var r_out := _tex("bolt_ramp.png", [warp, 2])
	var r_mid := _tex("bolt_ramp.png", [warp, 3])
	var r_core := _tex("bolt_ramp.png", [warp, 4])
	var r_glow := _tex("bolt_ramp.png", [warp, 5])
	# --- 겹치기
	_newcol()
	var comp := _expr(
		[["uv", PV2], ["along", PS], ["sdf", PV4], ["fa", PV4], ["fb", PV4], ["shard", PV4],
			["c_out", PV4], ["c_mid", PV4], ["c_core", PV4], ["c_glow", PV4],
			["erosion", PS], ["opacity", PS], ["layer", PS], ["flow_t", PS],
			["edge_hard", PS], ["edge_soft", PS], ["slit_k", PS], ["cyan_k", PS], ["shard_k", PS],
			["glow_width", PS], ["glow_alpha", PS], ["core_boost", PS],
			["slit_color", PV3], ["cyan_color", PV3], ["tint", PV3]],
		[["col", PV3], ["alpha", PS]],
		"""float tailw = clamp(1.0 - along, 0.0, 1.0);
float inside = step(0.0, along);                      // len_k 로 잘린 뒤쪽은 비운다
float tongue = fb.b;
float streak = fa.r;
float fine = fa.g;
// 거리장: 0.5 = 가장자리. 꼬리로 갈수록 크게 갉는다 (촉은 손그림 실루엣 그대로)
float e_out = sdf.r - (tongue - 0.38) * erosion * (0.008 + 0.20 * tailw * tailw);
float e_mid = sdf.g - (tongue - 0.42) * erosion * (0.004 + 0.10 * tailw * tailw);
float e_core = sdf.b - (tongue - 0.45) * erosion * (0.005 + 0.11 * tailw * tailw);
// 촉은 칼같은 셀 경계, 꼬리는 번진다 (모션 블러)
float tw = tailw * tailw;
float s_out = mix(edge_hard, edge_soft, smoothstep(0.42, 0.95, tailw));
float s_mid = mix(edge_hard, edge_soft * 0.6, smoothstep(0.45, 1.0, tailw));
float a_out = smoothstep(0.5 - s_out, 0.5 + s_out, e_out);
float a_mid = smoothstep(0.5 - s_mid, 0.5 + s_mid, e_mid);
float a_core = smoothstep(0.5 - edge_hard, 0.5 + edge_hard, e_core);
// 꼬리 끝은 옅어진다
float body_fade = smoothstep(0.0, 0.42, along);
a_out *= mix(0.12, 1.0, smoothstep(0.0, 0.5, along));   // 꼬리는 어둡고 흐릿하게 사라진다
a_mid *= mix(0.4, 1.0, smoothstep(0.05, 0.5, along));
vec3 c = c_out.rgb;
// 몸통 속 어두운 틈: 긴 결이 진한 곳 (가운데 층 밖, 몸통 중간)
float slit = smoothstep(0.70, 0.76, streak) * (1.0 - a_mid) * smoothstep(0.15, 0.4, along) * (1.0 - smoothstep(0.7, 0.9, along));
c = mix(c, slit_color, slit * slit_k);
// 바깥 층 안쪽 띠: 가장자리보다 조금 밝게 (두 톤 셀)
float band = smoothstep(0.5 + 0.03, 0.5 + 0.03 + s_out, e_out);
c = mix(c, mix(c_out.rgb, c_mid.rgb, 0.45), band * 0.4 * (1.0 - slit));
// 위쪽 껍질은 더 어둡게 (레퍼런스: 위는 짙은 남색, 아래는 밝은 보라)
c *= mix(0.68, 1.0, smoothstep(0.38, 0.56, uv.y));
c = mix(c, c_mid.rgb, a_mid);
// 가운데 층 경계의 하늘색 선: 꼬리~중간에서 층 가장자리를 따라 가늘게 빛난다
float rim = a_mid * (1.0 - smoothstep(0.5 + 0.014, 0.5 + 0.034, e_mid)) * smoothstep(0.18, 0.34, along) * (1.0 - smoothstep(0.62, 0.8, along));
c = mix(c, vec3(0.50, 0.74, 1.0), rim * 0.85);
// 청록 줄: 가운데 층 속 가는 결 (꼬리~중간)
float cy = smoothstep(0.66, 0.72, fine) * a_mid * smoothstep(0.38, 0.48, along) * (1.0 - smoothstep(0.58, 0.70, along));
cy *= 1.0 - smoothstep(0.02, 0.07, abs(uv.y - 0.5));
c = mix(c, cyan_color, cy * cyan_k);
c = mix(c, c_core.rgb, a_core);
c += c_core.rgb * a_core * core_boost;
// 후광: 실루엣 밖으로 번지는 빛 (꼬리는 파랑, 촉은 분홍). 결을 따라 줄무늬가 진다
float g = smoothstep(0.5 - glow_width, 0.5 + 0.05, sdf.r + (streak - 0.5) * 0.10 * (0.4 + tailw));
g = g * g * (0.65 + 0.5 * streak) * mix(0.45, 1.0, smoothstep(0.1, 0.7, along));   // 꼬리 후광은 약하게
float quad_fade = smoothstep(0.0, 0.10, uv.y) * smoothstep(1.0, 0.90, uv.y) * smoothstep(0.0, 0.06, uv.x) * smoothstep(1.0, 0.985, uv.x);
// 조각: 몸통 바로 바깥에서만, 번호마다 켜졌다 꺼진다
float nearb = smoothstep(0.5 - 0.30, 0.5 - 0.08, sdf.r) * (1.0 - a_out) * smoothstep(0.25, 0.5, along);
float on = step(fract(shard.g * 7.31 + floor(flow_t * 0.6 + shard.g * 5.0) * 0.37), shard_k);
float sh = smoothstep(0.45, 0.6, shard.r) * nearb * on;
vec3 shard_col = mix(c_out.rgb, c_mid.rgb, fract(shard.g * 3.7));
col = mix(c_glow.rgb, c, a_out);
alpha = max(a_out, g * glow_alpha * 0.5);
col = mix(col, shard_col, sh);
alpha = max(alpha, sh);
if (layer > 0.5) {
	// 더하기 후광 판: 몸통 아래에 깔려 둘레와 바닥을 밝힌다
	col = c_glow.rgb * (0.7 + 0.6 * a_core);
	alpha = g * glow_alpha;
}
col *= tint;
alpha *= opacity * quad_fade * inside;""",
		[_input("uv"), [warp, 6], shape, flow_a, flow_b, shards, r_out, r_mid, r_core, r_glow,
			erosion, opacity, layer, [coords, 2],
			edge_hard, edge_soft, slit_k, cyan_k, shard_k, glow_w, glow_a, core_boost,
			c_slit, c_cyan, c_tint])
	_newcol()
	_connect([comp, 0], OUT_COLOR)
	_connect([comp, 1], OUT_ALPHA)


func _tex(file: String, uv: Array) -> Array:
	var n := VisualShaderNodeTexture.new()
	n.texture = load(TEX + file)
	var id := _add(n)
	_feed(id, 0, uv)
	_row += 1
	return [id, 0]


# ------------------------------------------------------------ 노드 헬퍼 (build_flame_trail.gd 와 같은 꼴)

func _add(n: VisualShaderNode) -> int:
	var id := _next_id
	_next_id += 1
	vs.add_node(F, n, Vector2(_col * 340 - 1600, _row * 150 - 600), id)
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


func _connect(src: Array, dst_port: int) -> void:
	vs.connect_nodes(F, src[0], src[1], VisualShader.NODE_ID_OUTPUT, dst_port)


func _expr(inputs: Array, outputs: Array, code: String, feeds: Array) -> int:
	var n := VisualShaderNodeExpression.new()
	for i in inputs.size():
		n.add_input_port(i, inputs[i][1], inputs[i][0])
	for i in outputs.size():
		n.add_output_port(i, outputs[i][1], outputs[i][0])
	n.set_expression(code)
	n.size = Vector2(620, 60 + 34 * maxi(inputs.size(), outputs.size()))
	var id := _add(n)
	_row += 6
	for i in feeds.size():
		_feed(id, i, feeds[i])
	return id


func _input(name: String) -> Array:
	var n := VisualShaderNodeInput.new()
	n.input_name = name
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
	var id := _add(n)
	var d := VisualShaderNodeVectorDecompose.new()
	d.op_type = VisualShaderNodeVectorBase.OP_TYPE_VECTOR_4D
	var did := _add(d)
	_feed(did, 0, [id, 0])
	var c := VisualShaderNodeVectorCompose.new()
	c.op_type = VisualShaderNodeVectorBase.OP_TYPE_VECTOR_3D
	var cid := _add(c)
	for i in 3:
		_feed(cid, i, [did, i])
	return [cid, 0]
