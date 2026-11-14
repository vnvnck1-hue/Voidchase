## 성좌판 침식 칸 VisualShader 두 종을 노드 그래프로 생성한다 (2026-11-09). 손으로 고치지 말고 이 스크립트를 고쳐 다시 실행.
##   Godot --headless --path . -s res://tools/shaders/build_relic_corrupt.gd
##
## 칸마다 VDRelicHud 가 칸보다 조금 넓은 ColorRect(QUAD) 를 HUD 그림 뒤(show_behind_parent)에 깔고 이 셰이더를 건다.
## 육각형은 수식(평평한 윗변 flat-top 거리장)으로 그린다. 좌표 p = 칸 중심 기준 px (y 아래).
##   shaders/relic_corrupt_glitch.tres  프리셋 0 "데이터 붕괴" — 가로 찢김 · 블록 단위로 갉아먹는 침식 전선 · 깜빡이는 오염 블록 ·
##                                      아래로 흐르는 데드 픽셀 · 자홍/청록 RGB 분리 테두리 · 깨진 경고 육각 · 주사선
##   shaders/relic_corrupt_infect.tres  프리셋 1 "나노 감염" — 가운데 특이점(검은 핵 + 도는 강착 고리) · 회로처럼 꺾인 혈관(체비쇼프 보로노이)에
##                                      바깥으로 흐르는 맥동 · 감염되는 육각 미세 격자 · 빨려 드는 나노 입자 · 테두리에서 뻗는 촉수
## 공통 uniform (VDRelicHud 가 넣는다): rect_px · hex_r · spawn(0 정상 칸 → 1 완전 침식, 정화 때 거꾸로) · hover · jolt(거절·침식 순간 튐) · seed
## 그래프: 입력(UV·TIME) → p(px) → [스타일] 좌표 왜곡 → 육각 거리 → 레이어들(바탕·패턴·테두리) → 합성 → 출력.
extends SceneTree

const F := VisualShader.TYPE_FRAGMENT
const OUT_COLOR := 0
const OUT_ALPHA := 1
const S_SCALAR := VisualShaderNode.PORT_TYPE_SCALAR
const S_V2 := VisualShaderNode.PORT_TYPE_VECTOR_2D
const S_V3 := VisualShaderNode.PORT_TYPE_VECTOR_3D
const S_V4 := VisualShaderNode.PORT_TYPE_VECTOR_4D

## 두 스타일이 같이 쓰는 함수
const COMMON_CODE := """
// 정수 해시 (실수 해시는 GPU 반올림으로 격자 경계가 어긋난다). 입력은 floor 해서 정수 칸으로
float rc_hash(vec2 p) {
	uvec2 q = uvec2(ivec2(floor(p))) * uvec2(1597334673u, 3812015801u);
	uint n = (q.x ^ q.y) * 1597334673u;
	return float(n) * (1.0 / 4294967295.0);
}

float rc_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(rc_hash(i), rc_hash(i + vec2(1.0, 0.0)), u.x), mix(rc_hash(i + vec2(0.0, 1.0)), rc_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 평평한 윗변(flat-top) 육각형 거리장. r = 내접 반지름 (윗변까지). 안쪽 음수
float rc_hex(vec2 p, float r) {
	const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	p = abs(p);
	p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
	p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
	return length(p) * sign(p.y);
}

// 띠 하나 (거리 d 가 0 근처 w 폭에서 1)
float rc_line(float d, float w) {
	return 1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, abs(d));
}
"""

## 프리셋 0: 데이터 붕괴
const GLITCH_WARP := """
// 가로 찢김: 5px 띠마다 박자(step_fps)로 일부가 좌우로 밀린다. 가끔 큰 글리치 프레임 (14px 띠가 크게)
float tk = floor(t * step_fps);
float row = floor((p.y + 400.0) / 5.0);
float on = step(0.84 - hover * 0.12 - jolt * 0.4, rc_hash(vec2(row, tk + seed * 31.0)));
float sh = (rc_hash(vec2(row * 1.7 + 3.0, tk * 1.3 + seed)) - 0.5) * 2.0 * tear_px * on;
float big_t = floor(t * 3.0);
float big = step(0.9 - jolt * 0.6, rc_hash(vec2(big_t, seed * 7.0 + 5.0)));
sh += big * (rc_hash(vec2(floor((p.y + 400.0) / 14.0), big_t + 9.0)) - 0.5) * 28.0;
q = vec2(p.x + sh * spawn, p.y);
"""

const GLITCH_BODY := """
float r_in = hex_r * 0.8660254;
float d = rc_hex(q, r_in);
float inside = 1.0 - smoothstep(-1.0, 0.5, d);
float tk = floor(t * step_fps);
// 블록 격자
vec2 g = (q + 400.0) / block_px;
vec2 blk = floor(g);
vec2 fb = fract(g);
vec2 bc = (blk + 0.5) * block_px - 400.0;
float bn = rc_hash(blk + seed * 13.0);
// 침식 전선: 가운데서 블록 단위로 퍼진다 (블록마다 들쭉날쭉)
float reach = spawn * r_in * 1.45;
float rad = length(bc) + (bn - 0.5) * 22.0;
infected = step(rad, reach);
float front = infected * (1.0 - step(rad, reach - block_px * 1.6)) * (1.0 - step(0.999, spawn));
float gap = step(0.14, fb.x) * step(0.14, fb.y);
// 오염 블록: 정해진 블록 일부가 박자마다 깜빡이며 자홍/청록
float fixed_set = step(0.84 - hover * 0.06, rc_hash(blk * 1.31 + seed * 3.0));
float flick = step(0.32, rc_hash(blk + vec2(tk, seed * 2.0)));
float hot = step(0.982 - jolt * 0.05, rc_hash(blk + vec2(tk * 0.5 + 7.0, seed)));
// 스캔 막대: 위아래로 훑으며 지나가는 자리의 블록을 더 많이 켠다
float scan_y = mod(t * 34.0 + seed * 7.0, r_in * 2.8) - r_in * 1.4;
float sweep = 1.0 - smoothstep(0.0, 12.0, abs(q.y - scan_y));
float sweep_line = rc_line(q.y - scan_y, 1.4);
float sweep_set = step(0.62, rc_hash(blk * 1.31 + seed * 3.0)) * sweep;
vec3 tile = mix(col_main, col_alt, step(0.55, rc_hash(blk + seed + 2.0)));
// 데드 픽셀 줄기: 블록 열마다 가는 줄기가 아래로 흘러내린다
float colx = blk.x;
float has = step(0.55, rc_hash(vec2(colx, seed + 13.0)));
float spd = 18.0 + 46.0 * rc_hash(vec2(colx, seed + 9.0));
float len = 8.0 + 34.0 * rc_hash(vec2(colx, seed + 5.0));
float dy = mod(q.y + 400.0 - t * spd - rc_hash(vec2(colx, seed + 11.0)) * 120.0, 96.0);
float drip = has * (1.0 - smoothstep(0.0, len, dy)) * step(0.3, fb.x) * step(fb.x, 0.7);
// 주사선
float scan = 0.78 + 0.22 * step(1.0, mod(floor(q.y + 400.0), 3.0));
// 깨진 경고 육각 (가운데): 둘레가 조각나 돌며 깜빡
float ang = atan(q.y, q.x);
float dc = rc_hex(q, r_in * 0.3);
float seg = step(0.34, fract(ang / 6.2831853 * 6.0 + floor(t * step_fps) * 0.06));
float blink = 0.55 + 0.45 * step(0.5, fract(t * 1.7));
float icon = rc_line(dc, 3.0) * seg * blink;
float bar = step(abs(q.x), 2.4) * step(-r_in * 0.19, q.y) * step(q.y, r_in * 0.05) + step(length(q - vec2(0.0, r_in * 0.14)), 2.6);   // 가운데 '!'
// 바탕: 감염 전 = 평소 칸 바탕, 감염 = 공허색
vec3 vbg = mix(col_void, col_main * 0.16, rc_vnoise(q * 0.07 + vec2(t * 0.25, seed)) * 0.9);
vec3 col = mix(col_cell, vbg, infected);
col = mix(col, tile * 0.95, clamp(fixed_set * flick + sweep_set, 0.0, 1.0) * gap * infected * 0.9);
col = mix(col, col_alt * 1.2, sweep_line * infected * 0.7);
col = mix(col, vec3(1.0), hot * gap * infected);
col += col_main * drip * infected * 0.85;
col = mix(col, col_alt, front * gap);
col = mix(col, mix(col_main * 1.3, vec3(1.0, 0.85, 0.95), 0.35), clamp(icon + bar * blink, 0.0, 1.0) * infected);
col *= scan;
float a = inside * mix(cell_alpha, 0.95, infected);
// 테두리: 평소 테두리 → 자홍/청록 RGB 분리 + 흰 심지
float sp = smoothstep(0.0, 0.5, spawn);
float split = 2.5 + jolt * 4.0 + hover * 1.0;
float e0 = rc_line(rc_hex(q + vec2(split, 0.0), r_in), 3.0);
float e1 = rc_line(rc_hex(q - vec2(split, 0.0), r_in), 3.0);
float e2 = rc_line(d, 2.0);
float dash = step(0.18, fract((ang / 6.2831853) * 18.0 - t * 0.35));
float eg = rc_line(d, 6.0) * edge_alpha;
vec3 ec = col_main * e0 + col_alt * e1 + vec3(1.0) * e2 * 0.85 * dash;
float ea = clamp(max(max(e0, e1), e2 * dash), 0.0, 1.0) * sp;
col = mix(col, col_edge, eg * (1.0 - sp));
a = max(a, eg * (1.0 - sp));
col = mix(col, ec / max(ea, 0.001) * sp, ea);
a = max(a, ea);
// 바깥 번짐 (자홍 후광)
float halo = exp(-max(d, 0.0) / 9.0) * (1.0 - inside) * 0.4 * sp;
col = mix(col, col_main, halo * (1.0 - a));
a = max(a, halo);
color = col * (1.0 + hover * 0.35 + jolt * 0.5) * intensity;
alpha = a;
"""

## 프리셋 1: 나노 감염
const INFECT_WARP := """
// 특이점 렌즈: 가운데로 갈수록 좌표가 천천히 소용돌이친다
float rr = length(p);
float sw = (1.2 + hover * 0.8 + jolt * 2.0) * exp(-rr / 26.0) * spawn;
float c = cos(sw * sin(t * 0.6) + sw), s = sin(sw * sin(t * 0.6) + sw);
q = mat2(vec2(c, s), vec2(-s, c)) * p;
"""

const INFECT_BODY := """
float r_in = hex_r * 0.8660254;
float d = rc_hex(p, r_in);
float inside = 1.0 - smoothstep(-1.0, 0.5, d);
float rr = length(p);
float ang = atan(p.y, p.x);
// 감염 전선: 각도 노이즈로 울퉁불퉁하게 가운데서 퍼진다
float nf = rc_vnoise(vec2(ang * 1.9 + seed * 5.0, t * 0.4));
float reach = spawn * r_in * 1.5;
float fd = rr + (nf - 0.5) * 18.0 - reach;
infected = 1.0 - smoothstep(-1.0, 1.0, fd);
float front = rc_line(fd, 3.0) * (1.0 - step(0.999, spawn));
// 바탕: 가장자리로 갈수록 보랏빛이 짙어지는 공허
vec3 col = mix(col_void, col_main * 0.13, smoothstep(r_in * 0.2, r_in, rr));
// 육각 미세 격자 (감염된 나노 타일)
vec2 hp = q / cell_px;
vec2 hq = vec2(hp.x * 1.1547, hp.y + hp.x * 0.57735);   // 축 좌표 근사
vec2 hi = floor(hq);
vec2 hf = fract(hq);
float edge_g = min(min(hf.x, hf.y), min(1.0 - hf.x, 1.0 - hf.y));
float grid = 1.0 - smoothstep(0.03, 0.09, edge_g);
float lit = step(0.9 - hover * 0.05, rc_hash(hi + vec2(floor(t * 2.5), seed * 11.0)));
// 회로 혈관: 체비쇼프 보로노이 경계 (축에 붙은 꺾인 선 = 회로 기판)
vec2 vg = q / vein_px + seed * 3.7;
vec2 vi = floor(vg);
float f1 = 9.0;
float f2 = 9.0;
for (int y = -1; y <= 1; y++) {
	for (int x = -1; x <= 1; x++) {
		vec2 o = vec2(float(x), float(y));
		vec2 h = vec2(rc_hash(vi + o), rc_hash(vi + o + 17.0));
		vec2 dv = vi + o + 0.15 + 0.7 * h - vg;
		float dd = max(abs(dv.x), abs(dv.y));
		if (dd < f1) { f2 = f1; f1 = dd; } else if (dd < f2) { f2 = dd; }
	}
}
float vein = 1.0 - smoothstep(0.015, 0.045, f2 - f1);
float pulse = smoothstep(0.66, 1.0, fract(rr / 24.0 - t * pulse_speed));
// 특이점: 검은 핵 + 도는 강착 고리
float core_r = 8.0 + 1.5 * sin(t * 3.0) + hover * 2.0;
float ring = rc_line(rr - core_r - 3.0, 2.2) * (0.55 + 0.45 * sin(ang * 5.0 - t * 5.0));
float core = 1.0 - smoothstep(core_r - 1.0, core_r, rr);
float glow = exp(-max(rr - core_r, 0.0) / 10.0);
// 빨려 드는 나노 입자 (사각)
float mote = 0.0;
for (int i = 0; i < 7; i++) {
	float fi = float(i);
	float life = fract(t * (0.22 + 0.05 * fi) + rc_hash(vec2(fi, seed * 9.0)));
	float mr = r_in * 0.95 * (1.0 - life);
	float ma = rc_hash(vec2(fi, seed + 3.0)) * 6.2831853 + life * 2.5;
	vec2 mp = vec2(cos(ma), sin(ma)) * mr;
	vec2 dm = abs(p - mp);
	mote += step(max(dm.x, dm.y), 1.6) * smoothstep(0.0, 0.2, life);
}
col = mix(col, col_main * 0.75, grid * 0.18);
col = mix(col, col_main * 0.8, lit * (1.0 - grid) * 0.35);
col = mix(col, col_main * 1.1, vein * 0.75);
col = mix(col, col_alt * 1.35, vein * pulse);
col += col_main * glow * 0.55;
col = mix(col, col_alt * 1.2, ring);
col = mix(col, vec3(0.0), core);
col = mix(col, vec3(1.0), clamp(mote, 0.0, 1.0) * 0.9);
// 감염 전은 평소 칸, 전선은 밝은 청록
col = mix(col_cell, col, infected);
col = mix(col, col_alt * 1.3, front);
float a = inside * mix(cell_alpha, 0.96, infected);
// 테두리: 평소 테두리 → 보라 테두리 위를 기어가는 밝은 조각 + 바깥으로 뻗는 촉수
float sp = smoothstep(0.0, 0.5, spawn);
float eg = rc_line(d, 6.0) * edge_alpha;
float crawl = smoothstep(0.6, 1.0, sin(ang * 3.0 - t * 2.2) * 0.5 + 0.5);
float e = rc_line(d, 3.0);
float sector = ang / 6.2831853 * 30.0;
float sid = floor(sector);
float sx = abs(fract(sector) - 0.5);
float tlen = (3.0 + 12.0 * rc_hash(vec2(sid, floor(t * 4.0) + seed))) * step(0.55, rc_hash(vec2(sid, seed + 21.0)));
float tendril = step(sx, 0.05) * step(0.0, d) * (1.0 - smoothstep(tlen * 0.6, tlen, d)) * sp;
vec3 ec = mix(col_main, col_alt, crawl);
col = mix(col, col_edge, eg * (1.0 - sp));
a = max(a, eg * (1.0 - sp));
col = mix(col, ec, e * sp);
a = max(a, e * sp);
col = mix(col, col_alt, tendril);
a = max(a, tendril * 0.9);
float halo = exp(-max(d, 0.0) / 10.0) * (1.0 - inside) * 0.38 * sp * (0.8 + 0.2 * sin(t * 2.0));
col = mix(col, col_main, halo * (1.0 - a));
a = max(a, halo);
color = col * (1.0 + hover * 0.3 + jolt * 0.6) * intensity;
alpha = a;
"""

const STYLES := [
	{"out": "res://shaders/relic_corrupt_glitch.tres", "warp": GLITCH_WARP, "body": GLITCH_BODY,
		"col_main": Color(1.0, 0.16, 0.62), "col_alt": Color(0.25, 0.95, 1.0), "col_void": Color(0.03, 0.006, 0.06),
		"floats": [["tear_px", 7.0, 0.0, 30.0], ["block_px", 6.0, 2.0, 20.0], ["step_fps", 12.0, 1.0, 30.0]]},
	{"out": "res://shaders/relic_corrupt_infect.tres", "warp": INFECT_WARP, "body": INFECT_BODY,
		"col_main": Color(0.62, 0.24, 1.0), "col_alt": Color(0.35, 1.0, 0.92), "col_void": Color(0.02, 0.0, 0.05),
		"floats": [["cell_px", 7.0, 3.0, 20.0], ["vein_px", 16.0, 6.0, 40.0], ["pulse_speed", 0.9, 0.0, 4.0]]},
]

var vs: VisualShader
var _next_id := 2
var _col := 0
var _row := 0


func _init() -> void:
	var ok := true
	for st in STYLES:
		vs = VisualShader.new()
		vs.mode = VisualShader.MODE_CANVAS_ITEM
		_next_id = 2
		_col = 0
		_row = 0
		_build(st)
		var err := ResourceSaver.save(vs, st["out"])
		print("[corrupt] saved %s err=%d nodes=%d" % [st["out"], err, _next_id - 2])
		ok = ok and err == OK
	quit(0 if ok else 1)


func _build(st: Dictionary) -> void:
	var g := VisualShaderNodeGlobalExpression.new()
	g.set_expression(COMMON_CODE)
	g.size = Vector2(900, 700)
	vs.add_node(F, g, Vector2(-2600, -1400), _next_id)
	_next_id += 1

	# --- 파라미터 (공통 → 스타일 전용 → 색)
	var rect := _param(VisualShaderNodeVec2Parameter.new(), "rect_px", Vector2(200, 180))
	var hex_r := _fparam("hex_r", 63.0, 20.0, 120.0)
	var spawn := _fparam("spawn", 1.0, 0.0, 1.0)
	var hover := _fparam("hover", 0.0, 0.0, 1.0)
	var jolt := _fparam("jolt", 0.0, 0.0, 1.0)
	var seed := _fparam("seed", 0.0, 0.0, 100.0)
	var intensity := _fparam("intensity", 1.0, 0.0, 3.0)
	var cell_alpha := _fparam("cell_alpha", 0.77, 0.0, 1.0)
	var edge_alpha := _fparam("edge_alpha", 0.77, 0.0, 1.0)
	var extras := []
	for f in st["floats"]:
		extras.append(_fparam(f[0], f[1], f[2], f[3]))
	var col_main := _cparam("col_main", st["col_main"])
	var col_alt := _cparam("col_alt", st["col_alt"])
	var col_void := _cparam("col_void", st["col_void"])
	var col_cell := _cparam("col_cell", Color(13.0 / 255.0, 8.0 / 255.0, 24.0 / 255.0))
	var col_edge := _cparam("col_edge", Color(95.0 / 255.0, 81.0 / 255.0, 142.0 / 255.0))
	var time := _input("time")

	# --- 칸 중심 기준 px 좌표
	_newcol()
	var p := _expr([["uv", S_V2], ["rect", S_V2]], [["p", S_V2]], "p = (uv - vec2(0.5)) * rect;", [_input("uv"), rect])

	# --- 좌표 왜곡 (찢김 / 특이점 렌즈)
	_newcol()
	var warp_in := [["p", S_V2], ["t", S_SCALAR], ["spawn", S_SCALAR], ["hover", S_SCALAR], ["jolt", S_SCALAR], ["seed", S_SCALAR]]
	var warp_feed := [[p, 0], time, spawn, hover, jolt, seed]
	if st["out"].contains("glitch"):
		warp_in += [["tear_px", S_SCALAR], ["step_fps", S_SCALAR]]
		warp_feed += [extras[0], extras[2]]
	var q := _expr(warp_in, [["q", S_V2]], st["warp"], warp_feed)

	# --- 본체: 바탕·패턴·테두리 합성
	_newcol()
	var body_in := [["p", S_V2], ["q", S_V2], ["t", S_SCALAR], ["spawn", S_SCALAR], ["hover", S_SCALAR], ["jolt", S_SCALAR], ["seed", S_SCALAR],
		["hex_r", S_SCALAR], ["intensity", S_SCALAR], ["cell_alpha", S_SCALAR], ["edge_alpha", S_SCALAR]]
	var body_feed := [[p, 0], [q, 0], time, spawn, hover, jolt, seed, hex_r, intensity, cell_alpha, edge_alpha]
	for i in st["floats"].size():
		body_in.append([st["floats"][i][0], S_SCALAR])
		body_feed.append(extras[i])
	body_in += [["col_main", S_V3], ["col_alt", S_V3], ["col_void", S_V3], ["col_cell", S_V3], ["col_edge", S_V3]]
	body_feed += [col_main, col_alt, col_void, col_cell, col_edge]
	var body := _expr(body_in, [["color", S_V3], ["alpha", S_SCALAR], ["infected", S_SCALAR]], st["body"], body_feed)

	_newcol()
	_connect([body, 0], OUT_COLOR)
	_connect([body, 1], OUT_ALPHA)


# ------------------------------------------------------------ 노드 헬퍼 (build_ui_glitch.gd 와 같은 모양)

func _add(n: VisualShaderNode) -> int:
	var id := _next_id
	_next_id += 1
	vs.add_node(F, n, Vector2(_col * 600 - 1600, _row * 150 - 400), id)
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
