## 공허 망령 촉수 스킬의 촉수 VisualShader(shaders/wraith_tentacle.tres)를 노드 그래프로 생성한다. 손으로 고치지 말고 이 스크립트를 고쳐 다시 실행.
##   Godot --headless --path . -s res://tools/shaders/build_wraith_tentacle.gd
##
## 컨셉(assets/컨셉 원화/몬스터 스킬.psd 의 모양 1 + 외부 광선 + 레이어 3·5)을 띠 메시 위에 수식으로 그린다.
## 띠 메시는 VDWraithTentacle 이 본 사슬(Skeleton2D)에 실어 휘두른다: UV.x = 뿌리 0 → 끝 1, UV.y = 가로 0..1.
##   - 굵기: 뿌리는 굵고 끝으로 갈수록 가늘어져 둥글게 끝난다 (body_w · tip_w)
##   - 색: 뿌리 어두운 남보라(col_base) → 보라(col_mid) → 끝 연보라(col_tip), 한쪽 가장자리를 따라 흐르는 밝은 띠(col_sheen),
##         반대쪽은 살짝 어둡게, 가장자리엔 보랏빛 테(col_glow)
##   - 바깥: 가운데~끝은 보랏빛 후광(외부 광선), 뿌리 쪽은 어두운 연기 그림자(레이어 5)
##   - flash: 찌른 순간 끝이 하얗게 번쩍, alpha_k: 전체 나타남·사라짐
## 몸통은 보통 섞기, 후광은 더하기에 가깝게 한 장에 그리려고 blend_premul_alpha 를 쓴다 (색 = 몸통 + 후광, 알파 = 몸통 + 연기).
extends SceneTree

const OUT := "res://shaders/wraith_tentacle.tres"
const BLEND_PREMUL := 4   # VisualShader modes/blend (canvas_item): 0 mix, 1 add, 2 sub, 3 mul, 4 premul_alpha
const F := VisualShader.TYPE_FRAGMENT
const OUT_COLOR := 0
const OUT_ALPHA := 1
const PV2 := VisualShaderNode.PORT_TYPE_VECTOR_2D
const PV3 := VisualShaderNode.PORT_TYPE_VECTOR_3D
const PS := VisualShaderNode.PORT_TYPE_SCALAR

var vs: VisualShader
var _next_id := 2
var _col := 0
var _row := 0


func _init() -> void:
	vs = VisualShader.new()
	vs.mode = VisualShader.MODE_CANVAS_ITEM
	vs.set("flags/unshaded", true)
	vs.set("modes/blend", BLEND_PREMUL)
	_build()
	var err := ResourceSaver.save(vs, OUT)
	print("[wraith_tentacle] saved %s err=%d nodes=%d" % [OUT, err, _next_id - 2])
	print(vs.get_code().get_slice("void fragment", 0))
	quit(0 if err == OK else 1)


func _build() -> void:
	var body_w := _fparam("body_w", 0.6, 0.1, 1.0)          # 뿌리에서 몸통이 띠 반폭에서 차지하는 비율
	var tip_w := _fparam("tip_w", 0.16, 0.02, 1.0)          # 끝 굵기 (뿌리 대비)
	var glow_w := _fparam("glow_w", 0.16, 0.01, 1.0)        # 후광이 퍼지는 폭 (띠 반폭 단위)
	var glow_i := _fparam("glow_i", 1.0, 0.0, 3.0)
	var flow := _fparam("flow_speed", 7.0, 0.0, 20.0)       # 밝은 띠가 끝 쪽으로 흐르는 속도
	var seed := _fparam("seed", 0.0, 0.0, 10.0)
	var flash := _fparam("flash", 0.0, 0.0, 1.0)
	var alpha_k := _fparam("alpha_k", 1.0, 0.0, 1.0)
	_newcol()
	var c_base := _cparam("col_base", Color(0.13, 0.07, 0.25))
	var c_mid := _cparam("col_mid", Color(0.38, 0.17, 0.72))
	var c_tip := _cparam("col_tip", Color(0.86, 0.62, 1.0))
	var c_sheen := _cparam("col_sheen", Color(0.74, 0.4, 1.0))
	var c_glow := _cparam("col_glow", Color(0.56, 0.2, 0.98))
	_newcol()
	var paint := _expr(
		[["uv", PV2], ["time", PS], ["body_w", PS], ["tip_w", PS], ["glow_w", PS], ["glow_i", PS], ["flow_speed", PS], ["seed", PS],
			["flash", PS], ["alpha_k", PS], ["col_base", PV3], ["col_mid", PV3], ["col_tip", PV3], ["col_sheen", PV3], ["col_glow", PV3]],
		[["rgb_out", PV3], ["a_out", PS]],
		"""float along = uv.x;
float side = (uv.y - 0.5) * 2.0;                      // -1..1
// 굵기: 뿌리 굵고 → 끝 가늘게 → 둥근 끝
float taper = 1.0 - smoothstep(0.1, 1.0, along);
float wide = mix(tip_w, 1.0, pow(taper, 0.8));
wide *= sqrt(clamp((0.975 - along) / 0.04, 0.0, 1.0));
float half_body = body_w * wide;
float dist = abs(side);
float soft = 0.03;
float body = (1.0 - smoothstep(half_body - soft, half_body + soft, dist)) * step(0.0005, wide);
// 길이 방향 색
vec3 shade = mix(col_base, col_mid, smoothstep(0.04, 0.48, along));
shade = mix(shade, col_tip, smoothstep(0.42, 0.93, along));
// 몸통 안 가로 좌표 -1..1
float inner = side / max(half_body, 0.001);
// 한쪽 가장자리를 따라 흐르는 밝은 띠
float streak = 0.55 + 0.45 * sin(along * 10.0 - time * flow_speed + seed * 6.2831);
float sheen = exp(-pow((inner - 0.38) / 0.34, 2.0)) * smoothstep(0.1, 0.55, along) * streak;
shade = mix(shade, col_sheen, sheen * 0.8);
// 반대쪽은 어둡게 (끝으로 갈수록 풀린다)
shade *= 1.0 - 0.4 * smoothstep(0.0, -1.0, inner) * (1.0 - smoothstep(0.45, 0.95, along));
// 가장자리 보랏빛 테
float rim = smoothstep(0.7, 1.0, abs(inner));
shade = mix(shade, col_glow * 1.2, rim * 0.6 * smoothstep(0.08, 0.5, along));
// 찌른 순간 끝이 번쩍
shade = mix(shade, vec3(1.0, 0.95, 1.0), flash * smoothstep(0.55, 0.97, along) * 0.85);
// 바깥: 가운데~끝은 후광, 뿌리는 어두운 연기
float out_d = max(dist - half_body, 0.0);
float halo = exp(-out_d / max(glow_w, 0.001)) * (1.0 - body);
float lit = smoothstep(0.06, 0.4, along);
float tip_fade = 1.0 - smoothstep(0.985, 1.0, along);
float strip = smoothstep(1.0, 0.82, dist) * smoothstep(0.0, 0.03, along) * tip_fade;
float pulse = 0.85 + 0.15 * sin(time * 9.0 + seed * 4.0 + along * 5.0);
vec3 halo_rgb = col_glow * halo * lit * glow_i * pulse * (1.0 + flash * 1.5 * smoothstep(0.5, 1.0, along));
float smoke = halo * (1.0 - lit) * 0.55;
float root_fade = smoothstep(0.0, 0.035, along);
rgb_out = (shade * body * root_fade + halo_rgb * strip) * alpha_k;
a_out = (body * root_fade + (smoke + halo * lit * 0.22) * strip * (1.0 - body)) * alpha_k;""",
		[_input("uv"), _input("time"), body_w, tip_w, glow_w, glow_i, flow, seed, flash, alpha_k, c_base, c_mid, c_tip, c_sheen, c_glow])
	_connect([paint, 0], OUT_COLOR)
	_connect([paint, 1], OUT_ALPHA)


# ------------------------------------------------------------ 노드 헬퍼 (build_flame_trail.gd 와 같은 꼴)

func _add(n: VisualShaderNode) -> int:
	var id := _next_id
	_next_id += 1
	vs.add_node(F, n, Vector2(_col * 340 - 1200, _row * 150 - 500), id)
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
	n.size = Vector2(700, 60 + 34 * maxi(inputs.size(), outputs.size()))
	var id := _add(n)
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
