## 아군 피격 글리치 VisualShader(shaders/ui_glitch.tres)를 노드 그래프로 생성한다. 손으로 고치지 말고 이 스크립트를 고쳐 다시 실행.
##   Godot --headless --path . -s res://tools/shaders/build_ui_glitch.gd
##
## HUD 전체를 감싼 CanvasGroup 에 건다 (화면 텍스처 = HUD 버퍼).
## 카툰식 '가로' 가시 글리치: HUD 그림의 좌/우를 향한 테두리에서 가로 방향으로만 도형을 붙인다.
##   - 삼각 가시(모양 0) / 네모 턱(모양 1): 테두리 밖으로 튀어나온 도형을 그 자리 채움색 한 색으로 칠하고,
##     밑동의 원래 외곽선(폭 = 외곽선 두께 + erase_extra)도 채움색으로 지운다 → 안쪽 그림은 그대로
##   - 안으로 패인 홈(밀림 부호가 향함과 반대): 그 도형만큼 비운다
##   - 도형의 바깥 경계(밑변 제외)를 수식(선분 거리)으로 구해 외곽선을 두른다 → 뒤에 다른 HUD 가 있어도,
##     가시 옆면이 비스듬해도 두께가 일정하다
## 가시 슬롯 4개의 값은 scripts/void_defense/vd_hurt_glitch.gd 가 매 박자 넣어 준다 (텍스처에서 잰 색·외곽선 두께 포함).
##   spike_aN = (테두리 x, 가운데 y, 반높이, 밀림 x)   ← 화면 디자인 px
##   spike_bN = (향함 +1 오른쪽/-1 왼쪽, 모양 0 삼각/1 네모, 외곽선 두께 px, 켜짐)
##   fill_colorN / ink_colorN = 채움색 / 외곽선색
## 슬롯 반복이 필요한 도형 판정만 Global Expression 함수로 두고, 색 고르기·섞기·알파는 노드로 잇는다.
extends SceneTree

const OUT := "res://shaders/ui_glitch.tres"
const F := VisualShader.TYPE_FRAGMENT
## canvas_item 프래그먼트 출력 포트 (VisualShaderNodeOutput 은 포트 조회 API 가 없다)
const OUT_COLOR := 0
const OUT_ALPHA := 1
const SLOTS := 4

const GLOBAL_CODE := """
float vdg_seg(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float h = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
	return length(p - a - ab * h);
}

// 슬롯 하나의 판정: 0 없음 / 1 채움 / 2 비움 / 3 외곽선.
//   o = 테두리에서 바깥쪽으로 잰 가로 거리(홈은 안쪽으로), t = 가운데에서 잰 세로 거리
float vdg_spike_kind(vec2 p, vec4 a, vec4 b, float km, float ko, float ke) {
	if (b.w < 0.5) return 0.0;
	float f = b.x;
	bool dent = a.w * f < 0.0;
	float o = (p.x - a.x) * f;
	if (dent) o = -o;
	float t = p.y - a.y;
	float hh = max(a.z, 1.0);
	float L = abs(a.w);
	if (L < 0.5) return 0.0;
	float w_in = b.z * km;             // 도형 안쪽(그림 쪽) 외곽선 두께
	float s = b.z + ke;               // 밑동에서 지울 원래 외곽선 폭
	vec2 q = vec2(o, t);
	float d;
	bool in_s;
	if (b.y > 0.5) {
		d = min(min(vdg_seg(q, vec2(0.0, -hh), vec2(L, -hh)), vdg_seg(q, vec2(L, -hh), vec2(L, hh))), vdg_seg(q, vec2(L, hh), vec2(0.0, hh)));
		in_s = o >= 0.0 && o <= L && abs(t) <= hh;
	} else {
		d = min(vdg_seg(q, vec2(0.0, -hh), vec2(L, 0.0)), vdg_seg(q, vec2(0.0, hh), vec2(L, 0.0)));
		in_s = o >= 0.0 && abs(t) < hh && o <= L * (1.0 - abs(t) / hh);
	}
	if (!dent) {
		if (in_s) return d < w_in ? 3.0 : 1.0;
		if (d < ko) return 3.0;
		if (o < 0.0 && o > -s && abs(t) < hh) return 1.0;   // 밑동의 원래 외곽선 지우기
		return 0.0;
	}
	// 홈: 도형 자리는 비우고, 남은 그림 쪽(o < 0 이 아니라 도형 밖이면서 그림 안쪽) 경계에 외곽선
	if (in_s) return d < ko ? 3.0 : 2.0;
	if (o >= 0.0 && d < w_in) return 3.0;
	return 0.0;
}

// 4슬롯 합치기: 외곽선 > 비움 > 채움. slot = 결정한 슬롯.
float vdg_spikes(vec2 p, vec4 A[4], vec4 B[4], float km, float ko, float ke, out float slot) {
	float kind = 0.0;
	slot = 0.0;
	for (int i = 0; i < 4; i++) {
		float k = vdg_spike_kind(p, A[i], B[i], km, ko, ke);
		if (k > kind) {
			kind = k;
			slot = float(i);
		}
	}
	return kind;
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
	print("[glitch] saved %s err=%d nodes=%d" % [OUT, err, _next_id - 2])
	print(vs.get_code())
	quit(0 if err == OK else 1)


func _build() -> void:
	# --- 함수 (Global Expression)
	var g := VisualShaderNodeGlobalExpression.new()
	g.set_expression(GLOBAL_CODE)
	g.size = Vector2(900, 900)
	vs.add_node(F, g, Vector2(-2600, -1400), _next_id)
	_next_id += 1

	# --- 파라미터
	var view := _param(VisualShaderNodeVec2Parameter.new(), "view_size", Vector2(1920, 1080))
	var a := []
	var b := []
	for i in SLOTS:
		a.append(_param(VisualShaderNodeVec4Parameter.new(), "spike_a%d" % i, Vector4.ZERO))
	for i in SLOTS:
		b.append(_param(VisualShaderNodeVec4Parameter.new(), "spike_b%d" % i, Vector4.ZERO))
	var fills := []
	var inks := []
	for i in SLOTS:
		fills.append(_cparam("fill_color%d" % i, Color(0.5, 0.16, 0.9)))
	for i in SLOTS:
		inks.append(_cparam("ink_color%d" % i, Color(0.1, 0.09, 0.14)))
	var ink_mul := _fparam("ink_mul", 0.75, 0.0, 3.0)
	var ink_out := _fparam("ink_out", 1.5, 0.0, 10.0)
	var erase_extra := _fparam("erase_extra", 3.5, 0.0, 10.0)

	# --- 화면 좌표 → 디자인 px
	_newcol()
	var p := _vop2(VisualShaderNodeVectorOp.OP_MUL, _input("screen_uv"), view)

	# --- 도형 판정 (4슬롯)
	_newcol()
	var sp := _expr(
		[["p", VisualShaderNode.PORT_TYPE_VECTOR_2D]] + _slot_ports()
			+ [["k_ink", VisualShaderNode.PORT_TYPE_SCALAR], ["k_out", VisualShaderNode.PORT_TYPE_SCALAR], ["k_erase", VisualShaderNode.PORT_TYPE_SCALAR]],
		[["kind", VisualShaderNode.PORT_TYPE_SCALAR], ["slot", VisualShaderNode.PORT_TYPE_SCALAR]],
		"vec4 A[4] = vec4[4](a0, a1, a2, a3);\nvec4 B[4] = vec4[4](b0, b1, b2, b3);\nkind = vdg_spikes(p, A, B, k_ink, k_out, k_erase, slot);",
		[p] + a + b + [ink_mul, ink_out, erase_extra])
	var kind := [sp, 0]
	var slot := [sp, 1]

	# kind → 마스크 세 개 (1 채움 / 2 비움 / 3 외곽선)
	_newcol()
	var is_fill := _band(kind, 1.0)
	var is_clear := _band(kind, 2.0)
	var is_ink := _band(kind, 3.0)

	# --- 원래 HUD (CanvasGroup 버퍼는 미리 곱한 알파 → 알파로 나눈다)
	_newcol()
	var sc := _decompose4(_screen_tex(_input("screen_uv")))
	var base := _compose3(_unpremul([sc, 0], [sc, 3]), _unpremul([sc, 1], [sc, 3]), _unpremul([sc, 2], [sc, 3]))

	# --- 슬롯 색 고르기
	_newcol()
	var fill_col := _select(fills, slot)
	var ink_col := _select(inks, slot)

	# --- 섞기: 원래 → 채움 → 외곽선, 알파: 비움이면 0, 도형이면 1
	_newcol()
	var c1 := _mix3(base, fill_col, is_fill)
	var c2 := _mix3(c1, ink_col, is_ink)
	var a0 := _fop(VisualShaderNodeFloatOp.OP_MUL, [sc, 3], _fop(VisualShaderNodeFloatOp.OP_SUB, 1.0, is_clear))
	var a1 := _fop(VisualShaderNodeFloatOp.OP_MAX, a0, _fop(VisualShaderNodeFloatOp.OP_MAX, is_fill, is_ink))

	_newcol()
	_connect(c2, OUT_COLOR)
	_connect(a1, OUT_ALPHA)


func _slot_ports() -> Array:
	var ports := []
	for i in SLOTS:
		ports.append(["a%d" % i, VisualShaderNode.PORT_TYPE_VECTOR_4D])
	for i in SLOTS:
		ports.append(["b%d" % i, VisualShaderNode.PORT_TYPE_VECTOR_4D])
	return ports


## x 가 v 와 같으면 1 (정수 값 kind 용): step(v - 0.5, x) - step(v + 0.5, x)
func _band(x: Array, v: float) -> Array:
	return _fop(VisualShaderNodeFloatOp.OP_SUB, _step(v - 0.5, x), _step(v + 0.5, x))


## slot(0..3) 번째 색: 0번에서 시작해 슬롯 번호를 넘을 때마다 다음 색으로 바꾼다.
func _select(cols: Array, slot: Array) -> Array:
	var c: Array = cols[0]
	for i in range(1, cols.size()):
		c = _mix3(c, cols[i], _step(float(i) - 0.5, slot))
	return c


# ------------------------------------------------------------ 노드 헬퍼
# 입력은 [노드 id, 포트] 배열이거나 숫자(포트 기본값으로 들어간다).

func _add(n: VisualShaderNode) -> int:
	var id := _next_id
	_next_id += 1
	vs.add_node(F, n, Vector2(_col * 300 - 1600, _row * 150 - 400), id)
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
	n.size = Vector2(520, 60 + 34 * maxi(inputs.size(), outputs.size()))
	var id := _add(n)
	_row += 3
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
	# 색 파라미터는 vec4 → vec3 로 쓰려고 분해 후 다시 묶는다
	var d := _decompose4([_add(n), 0])
	return _compose3([d, 0], [d, 1], [d, 2])


func _fop(op: int, a, b) -> Array:
	var n := VisualShaderNodeFloatOp.new()
	n.operator = op
	var id := _add(n)
	_feed(id, 0, a)
	_feed(id, 1, b)
	return [id, 0]


func _unpremul(c: Array, a: Array) -> Array:
	return _fop(VisualShaderNodeFloatOp.OP_DIV, c, _fop(VisualShaderNodeFloatOp.OP_MAX, a, 0.0001))


func _step(edge, x) -> Array:
	var n := VisualShaderNodeStep.new()
	n.op_type = VisualShaderNodeStep.OP_TYPE_SCALAR
	var id := _add(n)
	_feed(id, 0, edge)
	_feed(id, 1, x)
	return [id, 0]


func _vop2(op: int, a, b) -> Array:
	var n := VisualShaderNodeVectorOp.new()
	n.op_type = VisualShaderNodeVectorBase.OP_TYPE_VECTOR_2D
	n.operator = op
	var id := _add(n)
	_feed(id, 0, a)
	_feed(id, 1, b)
	return [id, 0]


func _mix3(a, b, w) -> Array:
	var n := VisualShaderNodeMix.new()
	n.op_type = VisualShaderNodeMix.OP_TYPE_VECTOR_3D_SCALAR
	var id := _add(n)
	_feed(id, 0, a)
	_feed(id, 1, b)
	_feed(id, 2, w)
	return [id, 0]


func _compose3(x, y, z) -> Array:
	var n := VisualShaderNodeVectorCompose.new()
	n.op_type = VisualShaderNodeVectorBase.OP_TYPE_VECTOR_3D
	var id := _add(n)
	_feed(id, 0, x)
	_feed(id, 1, y)
	_feed(id, 2, z)
	return [id, 0]


func _decompose4(v: Array) -> int:
	var n := VisualShaderNodeVectorDecompose.new()
	n.op_type = VisualShaderNodeVectorBase.OP_TYPE_VECTOR_4D
	var id := _add(n)
	_feed(id, 0, v)
	return id


## 화면(= CanvasGroup 의 HUD 버퍼) 샘플.
func _screen_tex(uv: Array) -> Array:
	var n := VisualShaderNodeTexture.new()
	n.source = VisualShaderNodeTexture.SOURCE_SCREEN
	var id := _add(n)
	_feed(id, 0, uv)
	return [id, 0]
