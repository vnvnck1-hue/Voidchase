## 워프(하이퍼스페이스) 화면 전환 VisualShader(shaders/warp_dive.tres)를 노드 그래프로 생성한다. 손으로 고치지 말고 이 스크립트를 고쳐 다시 실행.
##   Godot --headless --path . -s res://tools/shaders/build_warp_dive.gd
##
## "환자의 머릿속으로 들어간다" (2026-11-12, 사용자 레퍼런스: 어두운 남색 바탕 + 가운데에서 뻗는 흰·분홍·파랑 빛줄기 + 무지개 색 번짐).
## progress 0 → 0.5 (덮기): 지금 장면이 가운데로 빨려 들며 방사형으로 늘어나고(확대 + 방사 블러 + 색 분산), 블록 단위로 깨지며
##                          빛줄기 터널로 바뀐다. 빛줄기는 점점 길어지고 빨라진다. 0.5 에서 장면은 완전히 가려진다.
## progress 0.5 → 1 (걷기): 터널 끝의 빛이 부풀어 번쩍하고, 가운데에서 블록 단위로 구멍이 열리며 새 장면이 방사 블러에서 또렷해진다.
## 2026-11-12 추가(사용자 요청): 워프 러시의 장면 색 단계화(toon_amt) + 집중선을 디지털 SF 풍으로 변조한 wp_focus (가는 발광선 · 데이터 토막 · 색 분산).
## 디지털 느낌: 화면 비율의 사각 회랑 격자(프레임·패널이 스쳐 지나감), 데이터 조각처럼 끊긴 가는 빛줄기, 블록 모자이크·가로 조각 밀림, 주사선.
##
## 그래프: [타이밍] → [장면 샘플] · [빛줄기] · [회랑 격자·빛] · [덮임 마스크] (각각 Expression, 함수는 Global Expression 의 wp_*)
##         → 색 고르기·섞기·더하기는 노드. 색·세기는 모두 uniform (scripts/screen_transition_fx.gd 의 wp_* 조절값).
## travel(빛줄기가 흘러간 거리)은 러너가 progress 에서 계산해 넣는다: 덮기·걷기 시간이 달라도 속도가 0.5 에서 이어지게.
extends SceneTree

const OUT := "res://shaders/warp_dive.tres"
const F := VisualShader.TYPE_FRAGMENT
const OUT_COLOR := 0
const S := VisualShaderNode.PORT_TYPE_SCALAR
const V2 := VisualShaderNode.PORT_TYPE_VECTOR_2D
const V3 := VisualShaderNode.PORT_TYPE_VECTOR_3D

const GLOBAL_CODE := """
// ---- 워프 전환 함수. 이름은 모두 wp_ 접두사.
uniform sampler2D wp_screen : hint_screen_texture, repeat_disable, filter_linear;
float wp_hash(float n) { return fract(sin(n * 127.1 + 311.7) * 43758.5453); }
float wp_hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// 장면: 가운데 c 를 향해 scale 배로 당겨 읽고, 거기서 다시 blur 만큼 안쪽으로 14번 훑어 방사형으로 늘인다.
// disp > 0 이면 훑는 위치에 따라 빨강 → 초록 → 파랑 가중치를 줘서 늘어난 끝이 무지개로 갈라진다.
vec3 wp_scene(vec2 suv, vec2 c, float scale, float blur, float disp, float jit) {
	vec3 acc = vec3(0.0);
	vec3 wsum = vec3(0.0);
	for (int i = 0; i < 14; i++) {
		float t = (float(i) + jit) / 14.0;
		float s = scale * (1.0 - blur * t);
		vec3 smp = texture(wp_screen, c + (suv - c) * s).rgb;
		vec3 spec = vec3(clamp(1.0 - 2.0 * t, 0.0, 1.0), clamp(1.0 - abs(2.0 * t - 1.0), 0.0, 1.0), clamp(2.0 * t - 1.0, 0.0, 1.0)) + 0.06;
		vec3 w = mix(vec3(1.0), spec, disp);
		acc += smp * w;
		wsum += w;
	}
	return acc / wsum;
}

// 빛줄기 한 겹: 각도를 n 칸으로 나눠 칸마다 줄 하나(켜짐 확률 on, 반폭 wid 칸, 가장자리 번짐 halo).
// 반지름은 log 로 펴서(멀수록 길고 빠르게 = 원근) trav 만큼 바깥으로 흐르는 토막(길이 len)으로 끊는다. 머리(바깥 끝)가 밝고 꼬리로 갈수록 어둡다.
// soft = 머리 쪽이 부드럽게 사라지는 길이(굵은 광선은 길게 번지고, 가는 줄은 또렷이 끊긴다).
// bits > 0 이면 토막을 다시 bits 칸으로 잘라 군데군데 어둡게: 데이터 조각.
float wp_layer(float r, float a, float n, float trav, float len, float on, float wid, float halo, float soft, float bits, float sd, float vy) {
	float ac = a / 6.2831853 * n;
	float cell = mod(floor(ac), n);
	float f = abs(fract(ac) - 0.5);
	float h0 = wp_hash(cell * 1.31 + sd);
	if (h0 > on) return 0.0;
	float h1 = wp_hash(cell * 2.17 + sd + 11.0);
	float h2 = wp_hash(cell * 3.71 + sd + 23.0);
	float h3 = wp_hash(cell * 5.13 + sd + 37.0);
	float h4 = wp_hash(cell * 7.77 + sd + 51.0);
	float rr = max(r, 0.003);
	float w = wid * mix(0.3, 1.0, h1);
	float aaf = n / (6.2831853 * rr * vy);
	float ang = 1.0 - smoothstep(w - aaf, w + aaf, f);
	ang = max(ang, halo * pow(max(1.0 - f * 2.0, 0.0), 2.5));
	float fr = 1.2 * mix(0.7, 1.4, h2);
	float u = log2(rr) * fr - trav * mix(0.6, 1.6, h3) + h4 * 7.0;
	float fu = fract(u);
	float L = clamp(len * mix(0.55, 1.15, h1), 0.04, 0.94);
	float aau = fr * 1.5 / (rr * 0.693 * vy);
	float dash = pow(min(fu / L, 1.0), 1.6) * (1.0 - smoothstep(L - aau - soft, L + aau, fu));
	if (bits > 0.5) dash *= mix(0.2, 1.0, step(0.45, wp_hash(cell * 5.7 + floor(u * bits) * 3.1 + sd)));
	return ang * dash * mix(0.5, 1.0, h3);
}

// 빛줄기 세 겹(굵은 광선 · 중간 · 가는 데이터 줄)을 채널마다 반지름·각도를 조금씩 어긋나게 읽어 가장자리가 무지개로 번진다.
vec3 wp_streaks(vec2 q, float trav, float warp, float ca, float sd, float vy) {
	float r = length(q);
	float a = atan(q.y, q.x);
	vec3 o = vec3(0.0);
	for (int k = 0; k < 3; k++) {
		float fk = float(k) - 1.0;
		float rr = r * (1.0 + fk * 0.03 * ca);
		float aa = a + fk * 0.022 * ca;
		float v = 2.1 * wp_layer(rr, aa, 12.0, trav * 0.45, mix(0.45, 0.98, warp), 0.45, 0.3, 0.55, 0.16, 0.0, sd, vy);
		v += 0.95 * wp_layer(rr, aa, 64.0, trav, mix(0.06, 0.8, warp), 0.5, 0.2, 0.3, 0.06, 0.0, sd + 17.0, vy);
		v += 0.85 * wp_layer(rr, aa, 170.0, trav * 1.3, mix(0.05, 0.7, warp), 0.45, 0.24, 0.0, 0.0, 7.0, sd + 41.0, vy);
		o[k] = v;
	}
	return o * smoothstep(0.012, 0.13, r);
}

// 디지털 집중선: 워프 러시(build_warp_rush.gd)의 집중선을 SF 풍으로 변조한 것. 바깥에서 가운데로 꽂히는 선이지만 굵은 쐐기 대신
// 1~3px 의 가는 발광선이고, 길이 방향으로 바코드처럼 데이터 토막으로 끊긴다. 끝(tip)은 격자에 맞춰 끊기고 밝은 머리 블록이 붙는다.
// 몇몇 칸은 옅은 스캔 빔(반투명 쐐기)을 깐다. 더하기(가산)로 칠해 빛난다.
float wp_focus(float r, float a, float n, float rin, float on, float wid, float sd, float vy) {
	float ac = a / 6.2831853 * n;
	float cell = mod(floor(ac), n);
	float f = abs(fract(ac) - 0.5);
	if (wp_hash(cell * 1.31 + sd) > on) return 0.0;
	float tip = rin * mix(0.55, 1.6, wp_hash(cell * 2.3 + sd + 3.0));
	tip = floor(tip * 28.0 + 0.5) / 28.0;
	float span = r - tip;
	if (span <= 0.0) return 0.0;
	float aaf = n / (6.2831853 * max(r, 0.003) * vy);
	float w = min(wid, aaf * mix(0.8, 3.0, wp_hash(cell * 3.1 + sd + 5.0)));
	float core = 1.0 - smoothstep(w - aaf, w + aaf, f);
	float beam = step(0.72, wp_hash(cell * 4.3 + sd + 7.0)) * 0.13 * (1.0 - smoothstep(wid - aaf, wid + aaf, f)) * clamp(span / 0.3, 0.0, 1.0);
	float seg = floor(span * mix(18.0, 46.0, wp_hash(cell * 6.1 + sd + 13.0)));
	float code = step(0.38, wp_hash(seg * 1.7 + cell * 9.1 + sd));
	float w3 = min(w * 3.0 + aaf, 0.5);
	float head = (1.0 - smoothstep(0.02, 0.03, span)) * (1.0 - smoothstep(w3 - aaf, w3 + aaf, f));
	return core * mix(0.22, 1.0, code) + beam + head * 1.6;
}

// 사각 회랑: 화면 비율의 네모 프레임이 안쪽에서 바깥으로 스쳐 지나가고, 벽마다 세로줄 6칸. 몇몇 칸은 패널처럼 켜진다(panel).
float wp_grid(vec2 q, float asp, float trav, float sd, out float panel) {
	vec2 w = vec2(abs(q.x) / asp, abs(q.y)) * 2.0;
	float m = max(max(w.x, w.y), 0.0005);
	bool side = w.x > w.y;
	float wall = side ? (q.x > 0.0 ? 0.0 : 1.0) : (q.y > 0.0 ? 2.0 : 3.0);
	float t = side ? q.y * 2.0 / m : q.x / asp * 2.0 / m;
	float cu = log2(m) * 1.5 - trav * 0.8;
	float ct = t * 3.0;
	float fw = fwidth(cu);
	float l1 = 1.0 - smoothstep(max(fw * 1.1, 0.012), max(fw * 1.1, 0.012) + fw, abs(fract(cu + 0.5) - 0.5));
	float ft = min(fwidth(ct), 0.5);
	float l2 = 1.0 - smoothstep(ft * 0.9, ft * 1.9, abs(fract(ct + 0.5) - 0.5));
	float fade = (1.0 - smoothstep(0.12, 0.4, fw)) * smoothstep(0.05, 0.3, m);
	float ph = wp_hash2(vec2(floor(cu), floor(ct) + wall * 13.0) + sd);
	panel = step(0.86, ph) * fade;
	float bright = mix(0.45, 1.0, step(0.6, wp_hash(floor(cu) * 3.3 + sd)));
	return max(l1 * bright, l2 * 0.6) * fade;
}
"""

## 타이밍: progress 하나를 각 부분의 세기로 푼다.
const TIMING_CODE := """
float x = clamp(p_prog * 2.0, 0.0, 1.0);
float y = clamp(p_prog * 2.0 - 1.0, 0.0, 1.0);
float yy = clamp((y - 0.1) / 0.9, 0.0, 1.0);
float e = 1.0 - pow(1.0 - yy, 3.0);
float rmax = 0.5 * length(vec2(p_aspect, 1.0));
if (p_prog < 0.5) {
	o_warp = pow(x, 1.5);
	o_scale = 1.0 - 0.32 * pow(x, 2.4);
	o_blur = 0.55 * pow(x, 1.6);
	o_disp = clamp(x * 3.0 * p_chroma, 0.0, 1.0);
	o_glitch = p_digit * smoothstep(0.02, 0.22, x);
	o_samp = smoothstep(0.06, 0.6, x);
	o_gamp = smoothstep(0.35, 0.9, x);
	o_gs = 0.03 + 0.13 * x * x;
	o_ga = 1.1 * x * x;
	o_flash = 0.0;
	o_hole = -1.0;
	o_ring = 0.0;
	o_ringw = 0.05;
	o_toon = smoothstep(0.0, 0.3, x);
	o_lon = 0.6 * smoothstep(0.0, 0.3, x);
	o_rin = rmax * mix(0.85, 0.12, pow(x, 0.8));
} else {
	float k = 1.0 - yy;
	o_warp = pow(k, 1.2);
	o_scale = 1.0 + 0.16 * k * k;
	o_blur = 0.45 * pow(k, 2.5);
	o_disp = clamp(k * 2.0 * p_chroma, 0.0, 1.0);
	o_glitch = p_digit * (1.0 - smoothstep(0.3, 0.8, yy));
	o_samp = 1.0 - smoothstep(0.35, 0.95, yy);
	o_gamp = 1.0 - smoothstep(0.1, 0.6, yy);
	float bump = exp(-pow((y - 0.12) / 0.08, 2.0));
	o_gs = 0.16 + 0.16 * smoothstep(0.0, 0.3, y);
	o_ga = 1.1 * (1.0 - smoothstep(0.05, 0.6, yy)) + 0.25 * bump;
	o_flash = 0.3 * p_flash * bump;
	o_hole = rmax * 1.3 * e - 0.1 * (1.0 - e);
	o_ring = p_flash * smoothstep(0.0, 0.1, yy) * pow(k, 1.5);
	o_ringw = 0.03 + 0.06 * yy;
	o_toon = 1.0 - smoothstep(0.4, 0.9, yy);
	o_lon = 0.6 * (1.0 - smoothstep(0.3, 0.9, yy));
	o_rin = rmax * mix(0.12, 1.3, yy);
}
"""

## 장면 샘플: 가로 조각 밀림 + 블록 모자이크로 '디지털화'한 좌표를 방사 블러로 읽는다.
const SCENE_CODE := """
vec2 suv = p_suv;
float gt = floor(p_prog * 70.0);
float row = floor(suv.y * 46.0);
float rh = wp_hash(row * 1.7 + gt * 13.1 + p_seed);
suv.x += step(0.8, rh) * (wp_hash(row + gt * 3.3) - 0.5) * 0.09 * p_glitch;
vec2 bid = floor(suv * p_view / 30.0);
float pick = step(1.0 - 0.38 * p_glitch, wp_hash2(bid + vec2(gt * 0.37, p_seed)));
suv = mix(suv, (bid + 0.5) * 30.0 / p_view, pick);
float jit = wp_hash2(p_suv * p_view + p_prog * 100.0);
vec3 c = wp_scene(suv, vec2(0.5), p_scale, p_blur, p_disp, jit);
c = mix(c, floor(c * 5.0 + 0.5) / 5.0, p_toon * p_toonamt);   // 색 단계화 (워프 러시와 같은 5단)
c += max(c - 0.55, vec3(0.0)) * p_warp * 1.6;   // 밝은 곳이 빛줄기로 늘어난다
o_scene = c;
"""

const STREAK_CODE := """
vec2 q = (p_suv - 0.5) * vec2(p_aspect, 1.0);
vec3 si = vec3(0.0);
float amp = p_amp * p_streak;
if (amp > 0.001) si = wp_streaks(q, p_travel, p_warp, p_chroma, p_seed, p_view.y) * amp;
// 디지털 집중선: 두 벌(촘촘한 것 · 듬성한 것)을 채널마다 각도를 어긋나게 읽어 색이 갈라진다. tick 마다 씨앗이 바뀌어 깜박인다.
float fon = p_lon * p_focus;
if (fon > 0.001) {
	float fr = length(q);
	float fa = atan(q.y, q.x);
	float fsd = p_seed + p_tick * 7.3;
	for (int k = 0; k < 3; k++) {
		float ka = fa + (float(k) - 1.0) * 0.0035 * p_chroma;
		si[k] += 0.9 * wp_focus(fr, ka, 76.0, p_rin, fon, 0.3, fsd, p_view.y) + 0.8 * wp_focus(fr, ka, 30.0, p_rin * 1.25, fon * 0.6, 0.36, fsd + 31.0, p_view.y);
	}
}
float scan = 1.0 - 0.16 * step(0.5, fract(p_suv.y * p_view.y / 4.0));   // 주사선
o_i = si * scan;
o_tint = 0.5 + 0.5 * sin(atan(q.y, q.x) * 2.0 + p_seed + p_travel * 0.4);
o_hot = smoothstep(0.3, 1.1, si.g);
"""

const GRID_CODE := """
vec2 q = (p_suv - 0.5) * vec2(p_aspect, 1.0);
float panel;
float g = wp_grid(q, p_aspect, p_travel, p_seed, panel);
o_grid = (g * 0.55 + panel * 0.2) * p_gamp * p_grid;
float r = length(q);
o_vig = 0.24 * exp(-r * 2.6) * p_warp;
o_glow = p_ga * exp(-r * r / (2.0 * p_gs * p_gs));
"""

## 덮임 마스크: 덮을 때는 블록마다 다른 문턱으로 장면이 터널로 바뀌고(바깥부터), 걷을 때는 가운데 구멍이 블록 단위로 넓어진다.
const MASK_CODE := """
vec2 q = (p_suv - 0.5) * vec2(p_aspect, 1.0);
float r = length(q);
vec2 bid = floor(p_suv * p_view / 26.0);
float bh = wp_hash2(bid + p_seed * 1.7);
vec2 bq = ((bid + 0.5) * 26.0 / p_view - 0.5) * vec2(p_aspect, 1.0);
float rb = length(bq);
if (p_prog < 0.5) {
	float c = p_prog * 2.0 * (1.0 + 0.3 * rb);
	float th = mix(0.45, 0.92, bh);
	o_tunnel = mix(smoothstep(0.4, 0.95, c), smoothstep(th - 0.05, th, c), p_digit);
	o_ringc = vec3(0.0);
} else {
	float dd = p_hole - mix(r, rb + (bh - 0.5) * 0.16, p_digit);
	o_tunnel = 1.0 - smoothstep(-0.008, 0.008, dd);
	vec3 rr = vec3(r * (1.0 + 0.06 * p_chroma), r, r * (1.0 - 0.06 * p_chroma)) - p_hole;
	o_ringc = p_ring * exp(-(rr * rr) / (p_ringw * p_ringw));
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
	print("[warp_dive] saved %s err=%d nodes=%d" % [OUT, err, _next_id - 2])
	quit(0 if err == OK else 1)


func _build() -> void:
	var g := VisualShaderNodeGlobalExpression.new()
	g.set_expression(GLOBAL_CODE)
	g.size = Vector2(900, 1200)
	vs.add_node(F, g, Vector2(-2600, -1800), _next_id)
	_next_id += 1

	# --- 파라미터
	var progress := _fparam("progress", 0.0, 0.0, 1.0)
	var travel := _fparam("travel", 0.0, 0.0, 50.0)
	var aspect := _fparam("aspect", 1.7778, 0.5, 4.0)
	var seed := _fparam("seed", 0.0, 0.0, 100.0)
	var view := _param(VisualShaderNodeVec2Parameter.new(), "view_size", Vector2(1920, 1080))
	var chroma := _fparam("chroma", 1.0, 0.0, 2.0)
	var digit := _fparam("digit", 0.7, 0.0, 1.0)
	var grid_amt := _fparam("grid_amt", 0.6, 0.0, 1.5)
	var streak_amt := _fparam("streak_amt", 1.0, 0.0, 2.0)
	var flash_amt := _fparam("flash_amt", 1.0, 0.0, 2.0)
	var tick := _fparam("tick", 0.0, 0.0, 200.0)
	var toon_amt := _fparam("toon_amt", 1.0, 0.0, 1.0)
	var focus_amt := _fparam("focus_amt", 1.0, 0.0, 1.6)
	_newcol()
	var c_bg := _cparam("col_bg", Color(0.012, 0.012, 0.07))      # 터널 바탕: 깊은 남색
	var c_a := _cparam("col_a", Color(0.2, 0.42, 1.0))            # 빛줄기·격자: 전기 파랑
	var c_b := _cparam("col_b", Color(1.0, 0.35, 0.75))           # 빛줄기: 분홍
	var c_core := _cparam("col_core", Color(1.0, 0.97, 1.0))      # 뜨거운 심·섬광
	var suv := _input("screen_uv")

	# --- 타이밍
	_newcol()
	var t_outs := ["o_warp", "o_scale", "o_blur", "o_disp", "o_glitch", "o_samp", "o_gamp", "o_gs", "o_ga", "o_flash", "o_hole", "o_ring", "o_ringw", "o_toon", "o_lon", "o_rin"]
	var tm := _expr([["p_prog", S], ["p_aspect", S], ["p_chroma", S], ["p_digit", S], ["p_flash", S]],
		t_outs.map(func(n): return [n, S]), TIMING_CODE, [progress, aspect, chroma, digit, flash_amt])
	var t := {}
	for i in t_outs.size():
		t[t_outs[i]] = [tm, i]

	# --- 그림 조각 네 개
	_newcol()
	var scene := [_expr([["p_suv", V2], ["p_view", V2], ["p_prog", S], ["p_scale", S], ["p_blur", S], ["p_disp", S], ["p_glitch", S], ["p_seed", S], ["p_warp", S], ["p_toon", S], ["p_toonamt", S]],
		[["o_scene", V3]], SCENE_CODE, [suv, view, progress, t["o_scale"], t["o_blur"], t["o_disp"], t["o_glitch"], seed, t["o_warp"], t["o_toon"], toon_amt]), 0]
	var st := _expr([["p_suv", V2], ["p_aspect", S], ["p_view", V2], ["p_travel", S], ["p_warp", S], ["p_chroma", S], ["p_seed", S], ["p_amp", S], ["p_streak", S], ["p_tick", S], ["p_lon", S], ["p_rin", S], ["p_focus", S]],
		[["o_i", V3], ["o_tint", S], ["o_hot", S]], STREAK_CODE, [suv, aspect, view, travel, t["o_warp"], chroma, seed, t["o_samp"], streak_amt, tick, t["o_lon"], t["o_rin"], focus_amt])
	var gr := _expr([["p_suv", V2], ["p_aspect", S], ["p_travel", S], ["p_seed", S], ["p_gamp", S], ["p_grid", S], ["p_gs", S], ["p_ga", S], ["p_warp", S]],
		[["o_grid", S], ["o_vig", S], ["o_glow", S]], GRID_CODE, [suv, aspect, travel, seed, t["o_gamp"], grid_amt, t["o_gs"], t["o_ga"], t["o_warp"]])
	var mk := _expr([["p_suv", V2], ["p_aspect", S], ["p_view", V2], ["p_prog", S], ["p_digit", S], ["p_seed", S], ["p_hole", S], ["p_ring", S], ["p_ringw", S], ["p_chroma", S]],
		[["o_tunnel", S], ["o_ringc", V3]], MASK_CODE, [suv, aspect, view, progress, digit, seed, t["o_hole"], t["o_ring"], t["o_ringw"], chroma])

	# --- 색: 터널 바탕 · 빛줄기 색 · 격자
	_newcol()
	var bg := _mix3(c_bg, c_a, [gr, 1])                       # 가운데로 갈수록 파랗게 밝아지는 바탕
	var tint := _mix3(c_a, c_b, [st, 1])                      # 각도에 따라 파랑 ↔ 분홍
	var streak_col := _mix3(tint, c_core, [st, 2])            # 밝은 줄은 흰 심
	var streaks := _op3(VisualShaderNodeVectorOp.OP_MUL, streak_col, [st, 0])
	var grid_on := _fmul([gr, 0], [mk, 0])                    # 격자는 터널로 바뀐 곳에만
	var grid_col := _mix3(Vector3.ZERO, c_a, grid_on)
	var glow_col := _mix3(Vector3.ZERO, c_core, [gr, 2])
	var flash_col := _mix3(Vector3.ZERO, c_core, t["o_flash"])

	# --- 합치기: 장면 ↔ 터널 바탕, 그 위에 격자 · 빛줄기 · 가운데 빛 · 구멍 테두리 고리 · 섬광을 더한다
	_newcol()
	var col := _mix3(scene, bg, [mk, 0])
	col = _op3(VisualShaderNodeVectorOp.OP_ADD, col, grid_col)
	col = _op3(VisualShaderNodeVectorOp.OP_ADD, col, streaks)
	col = _op3(VisualShaderNodeVectorOp.OP_ADD, col, glow_col)
	col = _op3(VisualShaderNodeVectorOp.OP_ADD, col, [mk, 1])
	col = _op3(VisualShaderNodeVectorOp.OP_ADD, col, flash_col)
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
