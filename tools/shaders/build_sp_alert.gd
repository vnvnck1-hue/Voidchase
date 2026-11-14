## 스킬 SP 알림 외곽선 VisualShader 를 노드 그래프로 생성한다 (2026-11-13). 손으로 고치지 말고 이 스크립트를 고쳐 다시 실행.
##   Godot --headless --path . -s res://tools/shaders/build_sp_alert.gd
##   → shaders/sp_alert_outline.tres
##
## 좌측 하단 턴테이블(VDTurntable)의 캐릭터 Sprite2D 에 건다: 쓸 SP 가 있는 캐릭터의 실루엣 둘레가 금빛 네온으로 숨쉬고,
## 아래에서 위로 스캔 띠가 훑고 지나간다 (사이파이 데이터 스캔). 텍스처 알파만으로 그리므로 스틸·스프라이트 시트·
## 리그(서브뷰포트 텍스처) 모두 같은 셰이더를 쓴다.
##   정점 단계: 외곽선·글로우가 스프라이트 사각형 밖으로 나갈 수 있게 사각형을 quad_pad(텍스처 px) 만큼 넓힌다.
##   프래그먼트: 프레임 사각형(frame_rect, UV) 밖은 알파 0 으로 본다 (시트의 옆 프레임이 새지 않게).
## uniform (VDTurntable 이 넣는다):
##   quad_rect·frame_rect  이 프레임의 UV 사각형 (xy 최소, zw 최대)      quad_tex_px·tex_px  1 / 텍스처 크기
##   quad_pad  넓힐 폭 (텍스처 px)        ppx  화면 1px 이 텍스처 몇 px 인지
##   t  실제 시간(초, 배속 무관)           strength  0 꺼짐 → 1 켜짐
##   body_tint  몸에 곱하는 색 (뒤 캐릭터 딤드. 외곽선은 딤드되지 않는다)    premult  1 이면 텍스처가 프리멀티플라이드(뷰포트)
##   outline_px · glow_px · line_color · core_color · pulse_speed · sweep_speed · sweep_width · sweep_gain
extends SceneTree

const V := VisualShader.TYPE_VERTEX
const F := VisualShader.TYPE_FRAGMENT
const OUT_OUT := "res://shaders/sp_alert_outline.tres"
const S_SCALAR := VisualShaderNode.PORT_TYPE_SCALAR
const S_V2 := VisualShaderNode.PORT_TYPE_VECTOR_2D
const S_V3 := VisualShaderNode.PORT_TYPE_VECTOR_3D
const S_V4 := VisualShaderNode.PORT_TYPE_VECTOR_4D

## 정점: 프레임 가운데 기준으로 어느 모서리인지 보고 바깥으로 민다
const VERTEX_CODE := """
vec2 sgn = sign(uv - (rect.xy + rect.zw) * 0.5);
out_vertex = vertex + sgn * pad;
out_uv = uv + sgn * pad * tex_px;
"""

const BODY_CODE := """
vec2 m = step(frame_rect.xy, uv) * step(uv, frame_rect.zw);
vec4 c = texture(TEXTURE, uv) * (m.x * m.y);
if (premult > 0.5 && c.a > 0.0001) {
	c.rgb /= c.a;
}
float k = clamp(strength, 0.0, 1.0);
vec2 px = tex_px * ppx;
float pulse = 0.5 + 0.5 * sin(t * pulse_speed);
// 네온 선: 실루엣 밖 line_r 안 (두 반지름으로 채워 두껍게), 코어: 실루엣에 붙은 안쪽 40%, 글로우: 그 바깥 두 고리
float line_r = (outline_px + 1.5 * pulse) * k;
float glow_w = glow_px * k * (0.8 + 0.4 * pulse);
float a_line = 0.0;
float a_core = 0.0;
float a_g1 = 0.0;
float a_g2 = 0.0;
if (k > 0.001) {
	// 반지름마다 둘레 여러 방향의 알파 최댓값 (프레임 사각형 밖은 0). 내장 TEXTURE 는 함수 인자로 못 넘겨 여기서 바로 돈다
	for (int i = 0; i < 16; i++) {
		float fi = float(i);
		vec2 d16 = vec2(cos(fi * 0.3926991), sin(fi * 0.3926991));
		vec2 u = uv + d16 * px * line_r;
		vec2 mm = step(frame_rect.xy, u) * step(u, frame_rect.zw);
		a_line = max(a_line, textureLod(TEXTURE, u, 0.0).a * mm.x * mm.y);
		if (i < 12) {
			vec2 d12 = vec2(cos((fi + 0.3) * 0.5235988), sin((fi + 0.3) * 0.5235988));
			u = uv + d12 * px * (line_r + glow_w * 0.45);
			mm = step(frame_rect.xy, u) * step(u, frame_rect.zw);
			a_g1 = max(a_g1, textureLod(TEXTURE, u, 0.0).a * mm.x * mm.y);
			d12 = vec2(cos((fi + 0.7) * 0.5235988), sin((fi + 0.7) * 0.5235988));
			u = uv + d12 * px * (line_r + glow_w);
			mm = step(frame_rect.xy, u) * step(u, frame_rect.zw);
			a_g2 = max(a_g2, textureLod(TEXTURE, u, 0.0).a * mm.x * mm.y);
		}
		if (i < 8) {
			vec2 d8 = vec2(cos((fi + 0.5) * 0.7853982), sin((fi + 0.5) * 0.7853982));
			u = uv + d8 * px * line_r * 0.5;
			mm = step(frame_rect.xy, u) * step(u, frame_rect.zw);
			a_line = max(a_line, textureLod(TEXTURE, u, 0.0).a * mm.x * mm.y);
			d8 = vec2(cos((fi + 0.25) * 0.7853982), sin((fi + 0.25) * 0.7853982));
			u = uv + d8 * px * line_r * 0.4;
			mm = step(frame_rect.xy, u) * step(u, frame_rect.zw);
			a_core = max(a_core, textureLod(TEXTURE, u, 0.0).a * mm.x * mm.y);
		}
	}
}
float outside = 1.0 - c.a;
float line = clamp(a_line - c.a, 0.0, 1.0) * k;
float core = clamp(a_core - c.a, 0.0, 1.0);
float glow = max(clamp(a_g1 - a_line, 0.0, 1.0) * (0.55 + 0.25 * pulse), clamp(a_g2 - a_g1, 0.0, 1.0) * (0.25 + 0.15 * pulse)) * k;
// 스캔 띠: 프레임 아래에서 위로 훑는다 (v 0 위 → 1 아래). 띠가 지나는 자리의 선은 하얗게, 몸은 선 색으로 번쩍
float v = (uv.y - frame_rect.y) / max(frame_rect.w - frame_rect.y, 0.00001);
float band_y = 1.2 - fract(t * sweep_speed) * 1.5;
float band = (1.0 - smoothstep(0.0, sweep_width, abs(v - band_y))) * k;
float tail = (1.0 - smoothstep(0.0, sweep_width * 4.0, v - band_y)) * step(band_y, v) * 0.35 * k;
vec3 line_rgb = mix(line_color, core_color, clamp(core * 0.75 + band, 0.0, 1.0));
vec3 body = c.rgb * body_tint;
body += line_color * (band + tail) * sweep_gain;
body += line_color * 0.08 * pulse * k;
// 합성: 몸 위에 선, 그 바깥에 글로우 (출력은 스트레이트 알파)
float edge_a = line;
float glow_a = glow * (1.0 - line);
float out_a = c.a + (edge_a + glow_a) * outside;
color = (body * c.a + line_rgb * edge_a * outside + line_color * glow_a * outside) / max(out_a, 0.0001);
alpha = out_a;
"""

var vs: VisualShader
var _next_id := 2
var _col := 0
var _row := 0
var _stage := F


func _init() -> void:
	vs = VisualShader.new()
	vs.mode = VisualShader.MODE_CANVAS_ITEM
	_build_vertex()
	_build_fragment()
	var err := ResourceSaver.save(vs, OUT_OUT)
	print("[sp-alert] saved %s err=%d nodes=%d" % [OUT_OUT, err, _next_id - 2])
	if OS.get_cmdline_user_args().has("--code"):
		print(vs.code)
	quit(0 if err == OK else 1)


func _build_vertex() -> void:
	_stage = V
	_col = 0
	_row = 0
	var rect := _param(VisualShaderNodeVec4Parameter.new(), "quad_rect", Vector4(0, 0, 1, 1))
	var tex_px := _param(VisualShaderNodeVec2Parameter.new(), "quad_tex_px", Vector2(0.001, 0.001))
	var pad := _fparam("quad_pad", 0.0, 0.0, 256.0)
	var vertex := _input("vertex")
	var uv := _input("uv")
	_newcol()
	var ex := _expr([["vertex", S_V2], ["uv", S_V2], ["rect", S_V4], ["tex_px", S_V2], ["pad", S_SCALAR]],
		[["out_vertex", S_V2], ["out_uv", S_V2]], VERTEX_CODE, [vertex, uv, rect, tex_px, pad])
	vs.connect_nodes(V, ex, 0, VisualShader.NODE_ID_OUTPUT, 0)   # Vertex
	vs.connect_nodes(V, ex, 1, VisualShader.NODE_ID_OUTPUT, 1)   # UV


func _build_fragment() -> void:
	_stage = F
	_col = 0
	_row = 0
	var frame_rect := _param(VisualShaderNodeVec4Parameter.new(), "frame_rect", Vector4(0, 0, 1, 1))
	var tex_px := _param(VisualShaderNodeVec2Parameter.new(), "tex_px", Vector2(0.001, 0.001))
	var ppx := _fparam("ppx", 1.0, 0.01, 64.0)
	var t := _fparam("t", 0.0, 0.0, 100000.0)
	var strength := _fparam("strength", 0.0, 0.0, 1.0)
	var premult := _fparam("premult", 0.0, 0.0, 1.0)
	var outline_px := _fparam("outline_px", 3.5, 0.0, 12.0)
	var glow_px := _fparam("glow_px", 9.0, 0.0, 30.0)
	var pulse_speed := _fparam("pulse_speed", 4.6, 0.0, 20.0)
	var sweep_speed := _fparam("sweep_speed", 0.55, 0.0, 4.0)
	var sweep_width := _fparam("sweep_width", 0.07, 0.005, 0.5)
	var sweep_gain := _fparam("sweep_gain", 0.5, 0.0, 2.0)
	var line_color := _cparam("line_color", Color(1.0, 0.82, 0.25))
	var core_color := _cparam("core_color", Color(1.0, 0.98, 0.9))
	var body_tint := _cparam("body_tint", Color(1, 1, 1))
	var uv := _input("uv")

	_newcol()
	var body := _expr(
		[["uv", S_V2], ["frame_rect", S_V4], ["tex_px", S_V2], ["ppx", S_SCALAR], ["t", S_SCALAR], ["strength", S_SCALAR], ["premult", S_SCALAR],
			["outline_px", S_SCALAR], ["glow_px", S_SCALAR], ["pulse_speed", S_SCALAR], ["sweep_speed", S_SCALAR], ["sweep_width", S_SCALAR], ["sweep_gain", S_SCALAR],
			["line_color", S_V3], ["core_color", S_V3], ["body_tint", S_V3]],
		[["color", S_V3], ["alpha", S_SCALAR]], BODY_CODE,
		[uv, frame_rect, tex_px, ppx, t, strength, premult, outline_px, glow_px, pulse_speed, sweep_speed, sweep_width, sweep_gain, line_color, core_color, body_tint])
	vs.connect_nodes(F, body, 0, VisualShader.NODE_ID_OUTPUT, 0)   # Color
	vs.connect_nodes(F, body, 1, VisualShader.NODE_ID_OUTPUT, 1)   # Alpha


# ------------------------------------------------------------ 노드 헬퍼 (build_relic_corrupt.gd 와 같은 모양, 단계만 _stage 로)

func _add(n: VisualShaderNode) -> int:
	var id := _next_id
	_next_id += 1
	vs.add_node(_stage, n, Vector2(_col * 600 - 1600, _row * 150 - 400), id)
	_row += 1
	return id


func _newcol() -> void:
	_col += 1
	_row = 0


func _feed(id: int, port: int, v) -> void:
	if v is Array:
		vs.connect_nodes(_stage, v[0], v[1], id, port)
	else:
		vs.get_node(_stage, id).set_input_port_default_value(port, v)


func _expr(inputs: Array, outputs: Array, code: String, feeds: Array) -> int:
	var n := VisualShaderNodeExpression.new()
	for i in inputs.size():
		n.add_input_port(i, inputs[i][1], inputs[i][0])
	for i in outputs.size():
		n.add_output_port(i, outputs[i][1], outputs[i][0])
	n.set_expression(code)
	n.size = Vector2(560, 60 + 34 * maxi(inputs.size(), outputs.size()))
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


## 색 파라미터 → vec3 (분해 후 다시 묶는다)
func _cparam(name: String, def: Color) -> Array:
	var n := VisualShaderNodeColorParameter.new()
	n.parameter_name = name
	n.default_value_enabled = true
	n.default_value = def
	var src := [_add(n), 0]
	var dn := VisualShaderNodeVectorDecompose.new()
	dn.op_type = VisualShaderNodeVectorBase.OP_TYPE_VECTOR_4D
	var d := _add(dn)
	_feed(d, 0, src)
	var cn := VisualShaderNodeVectorCompose.new()
	cn.op_type = VisualShaderNodeVectorBase.OP_TYPE_VECTOR_3D
	var c := _add(cn)
	_feed(c, 0, [d, 0])
	_feed(c, 1, [d, 1])
	_feed(c, 2, [d, 2])
	return [c, 0]
