## 잉걸불 투사체용 '궤적 불꽃' VisualShader(vfx/flame/flame_trail.tres)를 노드 그래프로 생성한다. 손으로 고치지 말고 이 스크립트를 고쳐 다시 실행.
##   Godot --headless --path . -s res://tools/shaders/build_flame_trail.gd
##
## VFX연구 flame.tres(쿼드 위에 위로 타는 툰 불꽃)를 '궤적을 따라 흐르는 불덩이'로 바꾼 판.
## 쿼드 대신 곡선을 따라 깐 띠 메시(VDRelicFx._build_flame_mesh)에 건다:
##   UV.x = 출발점에서 잰 곡선 길이(px), UV.y = 띠 가로 0..1
## 그래서 좌표가 '머리에서 뒤로 몇 px, 옆으로 몇 px' 이 되고, 꼬리가 궤적을 따라 휘어진다 (종이처럼 고정된 쿼드가 아님).
##   along  = (head_px - UV.x) / radius_px   머리 뒤로 잰 거리 (불덩이 반지름 단위, 앞쪽은 음수)
##   across = 가로 거리 / radius_px
## 모양·색 계산은 flame.tres 와 같다 (노이즈 A 로 가로 흔들기 → 위로 갈수록 가늘게 → 위쪽만 늘인 원 거리장 → 노이즈 B 로 갉기
## → 테두리/코어/후광, 아래→위 그라데이션). 바뀐 곳:
##   - 노이즈가 꼬리 쪽으로 흘러간다 (scroll_speed): 앞으로 날아가는 불이 뒤로 쓸려 나가는 느낌
##   - 꼬리에 물결(wave): 뒤로 갈수록 크게 좌우로 굽이친다 → 일렁임
##   - 꼬리 길이(tail_r)·반지름·침식은 코드가 매 프레임 넣는다 (빠를수록 길게, 착탄 뒤 타 없어짐)
##   - 색: 아래→위 2색 대신 머리 → 가운데 → 꼬리 3색 (head/mid/tail_color). 코드가 비행 시간에 따라 '출발' → '착탄' 색으로 바꿔 넣는다
##   - layer = 1 이면 불꽃 대신 뒤에 깔리는 어두운 글로우만 그린다 (같은 메시를 두 번째 노드가 불꽃 아래·꼬리 띠 아래에 그림).
##     불꽃과 같은 노이즈·물결로 가장자리가 일렁인다 (shade_flicker), 꼬리는 shade_len 배로 더 길게
##   - layer = 2 이면 에디티브 글로우 라이팅만 그린다: 불덩이 둘레로 넓게 퍼지는 빛, 노이즈로 깜빡인다.
##     블렌드가 더하기여야 해서 같은 그래프를 blend_add 로 한 벌 더 저장한다 (OUT_ADD) — 세 번째 노드가 불꽃 바로 아래에 그림
##     (위에 얹으면 불꽃 색이 하얗게 날아간다: 빛은 둘레·바닥을 밝히고 불꽃은 제 색 그대로)
extends SceneTree

const OUT := "res://vfx/flame/flame_trail.tres"
const OUT_ADD := "res://vfx/flame/flame_trail_add.tres"
const BLEND_ADD := 1   # VisualShader modes/blend (canvas_item): 0 mix, 1 add
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
	var bad := 0
	for out in [OUT, OUT_ADD]:
		vs = VisualShader.new()
		vs.mode = VisualShader.MODE_CANVAS_ITEM
		vs.set("flags/unshaded", true)   # 원본처럼: 어두운 화면 톤에 같이 어두워지지 않게
		if out == OUT_ADD:
			vs.set("modes/blend", BLEND_ADD)
		_next_id = 2
		_col = 0
		_row = 0
		_build()
		var err := ResourceSaver.save(vs, out)
		bad += int(err != OK)
		print("[flame_trail] saved %s err=%d nodes=%d" % [out, err, _next_id - 2])
		print(vs.get_code().get_slice("void fragment", 0))   # render_mode·uniform 확인용
	quit(0 if bad == 0 else 1)


func _build() -> void:
	# --- 코드가 매 프레임 넣는 값 (궤적·크기·수명)
	var head := _fparam("head_px", 0.0, 0.0, 4000.0)
	var half_w := _fparam("half_w_px", 60.0, 1.0, 400.0)
	var radius := _fparam("radius_px", 24.0, 1.0, 200.0)
	var tail_r := _fparam("tail_r", 4.5, 0.5, 12.0)
	var erosion := _fparam("erosion", 1.0, 0.0, 6.0)
	var opacity := _fparam("opacity", 1.0, 0.0, 1.0)
	# --- 불꽃 결 (flame.tres 와 같은 이름·기본값 + 흐름/물결)
	_newcol()
	var time_offset := _fparam("time_offset", 0.0, 0.0, 100.0)
	var scroll := _fparam("scroll_speed", 1.1, 0.0, 4.0)
	var distortion := _fparam("distortion", 0.8, 0.0, 2.0)
	var taper := _fparam("taper", 0.45, 0.0, 2.0)
	var wave := _fparam("wave", 0.8, 0.0, 2.0)
	var wave_freq := _fparam("wave_freq", 1.1, 0.1, 4.0)
	var edge_soft := _fparam("edge_softness", 0.01, 0.001, 0.3)
	var rim_w := _fparam("rim_width", 0.12, 0.0, 0.5)
	var core_th := _fparam("core_threshold", 0.45, 0.0, 1.0)
	var glow_w := _fparam("glow_width", 0.45, 0.0, 2.0)
	var glow_a := _fparam("glow_alpha", 0.55, 0.0, 1.0)
	# --- 뒤에 깔리는 어두운 글로우 (layer = 1 인 두 번째 메시가 그린다)
	var layer := _fparam("layer", 0.0, 0.0, 1.0)
	var shade_w := _fparam("shade_width", 1.2, 0.0, 3.0)
	var shade_a := _fparam("shade_alpha", 0.65, 0.0, 1.0)
	var shade_fl := _fparam("shade_flicker", 1.0, 0.0, 2.0)
	var shade_len := _fparam("shade_len", 1.25, 0.5, 3.0)
	# --- 에디티브 글로우 라이팅 (layer = 2, blend_add 판)
	var light_w := _fparam("light_width", 1.6, 0.0, 4.0)
	var light_i := _fparam("light_intensity", 0.6, 0.0, 4.0)
	var light_fl := _fparam("light_flicker", 0.6, 0.0, 2.0)
	_newcol()
	# 머리 → 가운데 → 꼬리 그라데이션 (코드가 비행 시간에 따라 '출발' → '착탄' 색으로 바꿔 넣는다)
	var c_head := _cparam("head_color", Color(1, 0.78, 0.25))
	var c_mid := _cparam("mid_color", Color(1, 0.45, 0.1))
	var c_tail := _cparam("tail_color", Color(1, 0.25, 0.05))
	var c_core := _cparam("core_color", Color(1, 1, 0.85))
	var c_glow := _cparam("glow_color", Color(1, 0.3, 0.05))
	var c_shade := _cparam("shade_color", Color(0.14, 0.02, 0.05))
	var c_light := _cparam("light_color", Color(1.0, 0.45, 0.12))
	# --- 궤적 좌표: UV(곡선 길이 px, 가로 0..1) → 머리 기준 along·across, 흐르는 노이즈 좌표 둘
	_newcol()
	var coords := _expr(
		[["uv", PV2], ["time", PS], ["head_px", PS], ["half_w_px", PS], ["radius_px", PS], ["time_offset", PS], ["scroll_speed", PS]],
		[["along", PS], ["across", PS], ["uv_a", PV2], ["uv_b", PV2], ["edge_fade", PS]],
		"""float r = max(radius_px, 0.001);
along = (head_px - uv.x) / r;
across = (uv.y - 0.5) * 2.0 * half_w_px / r;
float t = (time + time_offset) * scroll_speed;
// 노이즈 A: 크게, 꼬리 쪽으로 흘러간다 (along - t). B: 잘게, 더 빨리
uv_a = fract(vec2(across * 0.09 + time_offset * 0.37, (along - t * 9.0) * 0.08));
uv_b = fract(vec2(across * 0.16 + time_offset * 0.61, (along - t * 14.0) * 0.15));
// 띠 메시 가장자리에서 후광이 칼같이 잘리지 않게
edge_fade = smoothstep(0.0, 0.06, uv.y) * smoothstep(1.0, 0.94, uv.y) * smoothstep(0.0, r * 1.5, uv.x);   // 출발점(띠 시작)에서도 부드럽게""",
		[_input("uv"), _input("time"), head, half_w, radius, time_offset, scroll])
	# --- 노이즈 텍스처 두 장 (flame.tres 와 같은 FastNoiseLite 설정)
	_newcol()
	var noise_a := _noise_tex([coords, 2], 0.008, 2)
	var noise_b := _noise_tex([coords, 3], 0.014, 3)
	# --- 불꽃 모양·색
	_newcol()
	var shape := _expr(
		[["along", PS], ["across", PS], ["na", PV4], ["nb", PV4], ["time", PS], ["time_offset", PS], ["scroll_speed", PS],
			["tail_r", PS], ["distortion", PS], ["taper", PS], ["wave", PS], ["wave_freq", PS], ["erosion", PS],
			["edge_softness", PS], ["rim_width", PS], ["core_threshold", PS], ["glow_width", PS], ["glow_alpha", PS],
			["head_color", PV3], ["mid_color", PV3], ["tail_color", PV3], ["core_color", PV3], ["glow_color", PV3], ["opacity", PS], ["edge_fade", PS],
			["layer", PS], ["shade_width", PS], ["shade_alpha", PS], ["shade_color", PV3], ["shade_flicker", PS], ["shade_len", PS],
			["light_width", PS], ["light_intensity", PS], ["light_flicker", PS], ["light_color", PV3]],
		[["col", PV3], ["alpha", PS]],
		"""float n1 = na.r - 0.5;
float n2 = nb.r;
float sb = max(along, 0.0);                       // 머리 뒤쪽만
float tr = max(tail_r, 0.5);
float sf = clamp(along / tr, 0.0, 1.0);           // 꼬리 비율 0(불덩이) → 1(꼬리 끝)
float t = (time + time_offset) * scroll_speed;
// 뒤로 갈수록 가늘게 (먼저 좁히고 그다음 흔들어야 꼬리가 궤적에서 떨어져 나가지 않는다)
float xd = across * (1.0 + sb * taper);
// 가로 흔들기: 노이즈 A (머리는 거의 둥글게, 꼬리로 갈수록 크게) + 꼬리 쪽으로 흘러가는 물결
xd += n1 * distortion * (0.5 + 0.6 * sb) + sin(along * wave_freq - t * 7.0) * wave * sf * 1.2;
// 꼬리 쪽만 tail_r 만큼 늘인 원 거리장 (앞쪽은 둥근 머리)
float dy = along > 0.0 ? along / tr : along;
float field = 1.0 - length(vec2(xd, dy));
// 노이즈 B 로 갉기: 머리는 살짝, 꼬리 끝으로 갈수록 크게 (끝이 혀처럼 갈라진다)
field -= n2 * erosion * (0.12 + 0.8 * sf);
float mask = smoothstep(0.0, edge_softness, field);
float rim = 1.0 - smoothstep(edge_softness, edge_softness + rim_width, field);
float core = smoothstep(core_threshold, core_threshold + edge_softness, field + n1 * 0.5);
float glow = smoothstep(-glow_width, 0.0, field);
glow *= glow;
// 머리(0) → 꼬리(1) 그라데이션: 노이즈로 경계가 일렁인다. 0~0.5 머리→가운데, 0.5~1 가운데→꼬리
float grad = smoothstep(0.0, 1.0, sf * 1.1 + n1 * 0.35);
vec3 c = mix(mix(head_color, mid_color, clamp(grad * 2.0, 0.0, 1.0)), tail_color, clamp(grad * 2.0 - 1.0, 0.0, 1.0));
c = mix(c, tail_color, rim * 0.85);
c = mix(c, core_color, core);
col = mix(glow_color, c, mask);
alpha = max(mask, glow * glow_alpha) * opacity * edge_fade;
// 뒤 어두운 글로우 (layer 1): 불꽃과 같은 노이즈·물결로 일렁이는 넓은 그림자. 꼬리는 shade_len 배 더 길게
if (layer > 0.5 && layer < 1.5) {
	float trs = tr * shade_len;
	float sfs = clamp(along / trs, 0.0, 1.0);
	float xs = across * (1.0 + sb * taper * 0.4);
	xs += (n1 * distortion * (0.7 + 0.7 * sb) + sin(along * wave_freq * 0.8 - t * 6.0 + 1.3) * wave * sfs * 0.9) * shade_flicker;
	float dys = along > 0.0 ? along / trs : along;
	float fs = 1.0 - length(vec2(xs, dys));
	fs -= (n2 - 0.35) * shade_flicker * (0.25 + 0.9 * sfs);     // 가장자리가 혀처럼 갈라진다
	float a = smoothstep(-shade_width, 0.3, fs);
	a *= 1.0 - shade_flicker * 0.12 * (0.5 + 0.5 * sin(t * 9.0 - along * 0.7));   // 숨 쉬듯 진하기가 흔들린다
	col = shade_color;
	alpha = a * shade_alpha * opacity * edge_fade;
}
// 에디티브 글로우 라이팅 (layer 2, blend_add): 불덩이 둘레로 light_width(반지름 배)만큼 퍼지는 빛.
// 머리가 가장 밝고 꼬리 쪽으로 늘어지며, 노이즈와 빠른 맥동으로 깜빡인다
if (layer > 1.5) {
	float trl = max(tr * 0.7, 0.5);
	float xl = across + n1 * distortion * 0.6 * light_flicker;
	float dl = along > 0.0 ? along / trl : along;
	float d = length(vec2(xl, dl));
	float fall = clamp(1.0 - d / (1.0 + light_width), 0.0, 1.0);
	fall = fall * fall * (0.55 + 0.45 * fall);                 // 가운데 뜨겁고 바깥은 부드럽게
	float pulse = 1.0 + light_flicker * ((n2 - 0.5) * 0.9 + 0.18 * sin(t * 17.0 + time_offset));
	col = light_color * light_intensity * max(pulse, 0.0);
	alpha = fall * opacity * edge_fade;
}""",
		[[coords, 0], [coords, 1], noise_a, noise_b, _input("time"), time_offset, scroll,
			tail_r, distortion, taper, wave, wave_freq, erosion,
			edge_soft, rim_w, core_th, glow_w, glow_a,
			c_head, c_mid, c_tail, c_core, c_glow, opacity, [coords, 4],
			layer, shade_w, shade_a, c_shade, shade_fl, shade_len,
			light_w, light_i, light_fl, c_light])
	_newcol()
	_connect([shape, 0], OUT_COLOR)
	_connect([shape, 1], OUT_ALPHA)


func _noise_tex(uv: Array, freq: float, octaves: int) -> Array:
	var fn := FastNoiseLite.new()
	fn.frequency = freq
	fn.fractal_octaves = octaves
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.noise = fn
	var n := VisualShaderNodeTexture.new()
	n.texture = nt
	var id := _add(n)
	_feed(id, 0, uv)
	_row += 1
	return [id, 0]


# ------------------------------------------------------------ 노드 헬퍼 (build_ui_glitch.gd 와 같은 꼴)
# 입력은 [노드 id, 포트] 배열이거나 숫자(포트 기본값으로 들어간다).

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
	# 색 파라미터(vec4) → vec3
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
