## 패링 연출의 VisualShader 세 장을 노드 그래프로 생성한다. 손으로 고치지 말고 이 스크립트를 고쳐 다시 실행.
##   Godot --headless --path . -s res://tools/shaders/build_parry_fx.gd
##
## 컨셉: assets/컨셉 원화/보스몹 컨셉.psd 의 '몬스터 공격 예고 예시' · '캐릭터 강조 효과 예시' (리소스 추출은 tools/vfx/extract_parry_fx.py).
##   shaders/parry_star.tres   예고 별 (모양 1 복사 24 + 노란 외부 광선). 스프라이트 텍스처 star.png: R 모양 · G 좁은 빛 · B 넓은 빛.
##       흰 몸통은 그대로 덮고 빛은 더한다 (blend_premul_alpha). fat > 0 이면 빛까지 몸통으로 부풀고(터지는 순간),
##       fat < 0 이면 바늘 끝부터 가운데로 오그라든다(닫힐 때). danger 는 빛을 노랑 → 붉은 주황으로, flash 는 전체를 희게.
##   shaders/parry_glow.tres   붉은 핵(타원 1 + 붉은 외부 광선) · 퍼지는 고리 · 가는 빛살. 수식만으로 그린다 (더하기).
##   shaders/parry_beam.tres   카드 강조 빛(레이어 67): 그린 그라디언트 위에 세로 결 + 위로 흐르는 띠 + 밑에서 차오르는 reveal (더하기).
extends SceneTree

const OUT_DIR := "res://shaders/"
const BLEND_ADD := 1      # VisualShader modes/blend (canvas_item): 0 mix, 1 add, 2 sub, 3 mul, 4 premul_alpha
const BLEND_PREMUL := 4
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
var _ok := true


func _init() -> void:
	_begin(BLEND_PREMUL)
	_build_star()
	_save("parry_star.tres")
	_begin(BLEND_ADD)
	_build_glow()
	_save("parry_glow.tres")
	_begin(BLEND_ADD)
	_build_beam()
	_save("parry_beam.tres")
	quit(0 if _ok else 1)


func _begin(blend: int) -> void:
	vs = VisualShader.new()
	vs.mode = VisualShader.MODE_CANVAS_ITEM
	vs.set("flags/unshaded", true)
	vs.set("modes/blend", blend)
	_next_id = 2
	_col = 0
	_row = 0


func _save(file: String) -> void:
	var err := ResourceSaver.save(vs, OUT_DIR + file)
	print("[parry_fx] saved %s err=%d nodes=%d" % [file, err, _next_id - 2])
	if err != OK:
		_ok = false


func _build_star() -> void:
	var fat := _fparam("fat", 0.0, -1.0, 1.0)
	var flash := _fparam("flash", 0.0, 0.0, 1.0)
	var danger := _fparam("danger", 0.0, 0.0, 1.0)
	var glow_gain := _fparam("glow_gain", 1.0, 0.0, 4.0)
	var bloom_gain := _fparam("bloom_gain", 0.45, 0.0, 4.0)
	var alpha_k := _fparam("alpha_k", 1.0, 0.0, 1.0)
	_newcol()
	var c_glow := _cparam("col_glow", Color(1.0, 0.965, 0.0))
	var c_hot := _cparam("col_hot", Color(1.0, 0.33, 0.05))
	_newcol()
	var tex := _sprite_tex(_input("uv"))
	var paint := _expr(
		[["tex", PV4], ["time", PS], ["fat", PS], ["flash", PS], ["danger", PS], ["glow_gain", PS], ["bloom_gain", PS], ["alpha_k", PS],
			["col_glow", PV3], ["col_hot", PV3]],
		[["rgb_out", PV3], ["a_out", PS]],
		"""float grow = max(fat, 0.0);
float shrink = max(-fat, 0.0);
// 몸통: 그린 모양 그대로. 부풀 때는 좁은 빛(G)까지 몸통이 된다
float puff = smoothstep(1.0 - grow * 0.93, 1.06 - grow * 0.93, tex.g) * step(0.001, grow);
float body = max(tex.r, puff);
// 오그라들 때: 넓은 빛(B)은 가운데가 가장 밝다 → 문턱을 올리면 바늘 끝부터 사라진다
float keep = mix(1.0, smoothstep(shrink * 0.9, shrink * 0.9 + 0.14, tex.b), step(0.001, shrink));
body *= keep;
float glow = tex.g * keep;
float bloom = tex.b * mix(1.0, keep, 0.6);
vec3 gcol = mix(col_glow, col_hot, danger);
float glint = 0.86 + 0.14 * sin(time * 21.0);
vec3 light = gcol * (glow * glow_gain * (1.0 - body) + bloom * bloom_gain) * glint;
light += vec3(1.0, 0.98, 0.9) * flash * (glow * 1.1 + bloom * 0.8);
rgb_out = (vec3(1.0) * body + light) * alpha_k;
a_out = body * alpha_k;""",
		[tex, _input("time"), fat, flash, danger, glow_gain, bloom_gain, alpha_k, c_glow, c_hot])
	_connect([paint, 0], OUT_COLOR)
	_connect([paint, 1], OUT_ALPHA)


func _build_glow() -> void:
	var core_r := _fparam("core_r", 0.16, 0.0, 1.0)        # 반지름 (사각형 반폭 = 1)
	var glow_r := _fparam("glow_r", 0.42, 0.01, 2.0)
	var ring_r := _fparam("ring_r", 0.0, 0.0, 1.2)
	var ring_w := _fparam("ring_w", 0.05, 0.001, 0.5)
	var ring_a := _fparam("ring_a", 0.0, 0.0, 2.0)
	var rays := _fparam("rays", 8.0, 2.0, 24.0)
	var ray_a := _fparam("ray_a", 0.0, 0.0, 2.0)
	var spin := _fparam("spin", 0.0, -10.0, 10.0)
	var alpha_k := _fparam("alpha_k", 1.0, 0.0, 1.0)
	_newcol()
	var c_core := _cparam("col_core", Color(1.0, 1.0, 1.0))
	var c_glow := _cparam("col_glow", Color(1.0, 0.188, 0.0))
	_newcol()
	var paint := _expr(
		[["uv", PV2], ["time", PS], ["core_r", PS], ["glow_r", PS], ["ring_r", PS], ["ring_w", PS], ["ring_a", PS], ["rays", PS], ["ray_a", PS],
			["spin", PS], ["alpha_k", PS], ["col_core", PV3], ["col_glow", PV3]],
		[["rgb_out", PV3], ["a_out", PS]],
		"""vec2 p = uv - 0.5;
float d = length(p) * 2.0;
float core = 1.0 - smoothstep(core_r - 0.015, core_r + 0.015, d);
float g = exp(-pow(max(d - core_r, 0.0) / max(glow_r, 0.001), 1.35) * 2.4);
float ring = (1.0 - smoothstep(0.0, ring_w, abs(d - ring_r))) * ring_a;
float ang = atan(p.y, p.x) + spin + time * 0.6;
float ray = pow(abs(cos(ang * rays * 0.5)), 28.0) * smoothstep(1.0, 0.15, d) * smoothstep(core_r, core_r + 0.12, d) * ray_a;
float edge = 1.0 - smoothstep(0.86, 1.0, d);
vec3 c = col_core * core + col_glow * (g * (1.0 - core) + ray) + mix(col_glow, vec3(1.0), 0.65) * ring;
rgb_out = c * edge * alpha_k;
a_out = 1.0;""",
		[_input("uv"), _input("time"), core_r, glow_r, ring_r, ring_w, ring_a, rays, ray_a, spin, alpha_k, c_core, c_glow])
	_connect([paint, 0], OUT_COLOR)
	_connect([paint, 1], OUT_ALPHA)


func _build_beam() -> void:
	var gain := _fparam("gain", 1.0, 0.0, 4.0)
	var reveal := _fparam("reveal", 1.0, 0.0, 1.0)        # 0 = 밑동만, 1 = 끝까지
	var base := _fparam("base", 1.0, 0.0, 1.0)            # 밑동이 있는 쪽: 1 = 아래(uv.y 1), 0 = 위
	var flow := _fparam("flow", 1.6, 0.0, 8.0)
	var alpha_k := _fparam("alpha_k", 1.0, 0.0, 1.0)
	_newcol()
	var c_tint := _cparam("tint", Color(1.0, 1.0, 1.0))
	_newcol()
	var tex := _sprite_tex(_input("uv"))
	var paint := _expr(
		[["tex", PV4], ["uv", PV2], ["time", PS], ["gain", PS], ["reveal", PS], ["base", PS], ["flow", PS], ["alpha_k", PS], ["tint", PV3]],
		[["rgb_out", PV3], ["a_out", PS]],
		"""// 밑동에서 잰 거리 0..1
float h = mix(uv.y, 1.0 - uv.y, base);
float mask = 1.0 - smoothstep(reveal - 0.12, reveal + 0.02, h);
// 세로 결: 가는 빛줄기 다발
float streak = 0.72 + 0.28 * sin(uv.x * 52.0 + sin(uv.x * 17.0) * 2.5);
// 밑동에서 끝으로 흐르는 밝은 띠
float band = fract(h * 0.9 - time * flow * 0.5);
float run = exp(-pow((band - 0.5) * 5.5, 2.0));
vec3 c = tex.rgb * tint * gain * streak * (0.82 + 0.5 * run);
c += vec3(1.0, 1.0, 0.85) * run * 0.22 * gain;
rgb_out = c * tex.a * mask * alpha_k;
a_out = 1.0;""",
		[tex, _input("uv"), _input("time"), gain, reveal, base, flow, alpha_k, c_tint])
	_connect([paint, 0], OUT_COLOR)
	_connect([paint, 1], OUT_ALPHA)


# ------------------------------------------------------------ 노드 헬퍼 (build_wraith_tentacle.gd 와 같은 꼴)

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


## 캔버스 아이템 자신의 텍스처(Sprite2D.texture)를 읽는다.
func _sprite_tex(uv: Array) -> Array:
	var n := VisualShaderNodeTexture.new()
	n.source = VisualShaderNodeTexture.SOURCE_2D_TEXTURE
	var id := _add(n)
	_feed(id, 0, uv)
	return [id, 0]


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
