// 번개 화면 전환 두 프리셋의 그림 (2026-11-12). 사용자가 그린 키 프레임(화면 컨셉_4.psd '화면 트랜지션')의 흐름
// — 번개가 대각선으로 먼저 치고 → 어두운 판이 그 대각선으로 닫히고 → 어두워진 뒤 → 열린다 — 을 바탕으로 다시 연출한 것.
//   style 0 "번개 일섬": 두 모서리의 판이 가위처럼 대각선으로 맞물려 닫힌다 (움찔 → 쾅 → 섬광)
//   style 1 "번개 재단": 번개가 화면을 베어 두 쪽이 어긋나고, 대각선과 나란한 칼날 띠가 엇갈려 꽂혀 닫힌다
// 시간에 따른 값(틈·번개 끝·섬광·흔들림…)은 전부 scripts/screen_transition_strike.gd 가 progress 에서 계산해 uniform 으로 넣는다.
// 좌표: 화면 높이 = 1, 화면 중심 원점. u = 대각선 방향(왼쪽 아래 → 오른쪽 위), s = 대각선에서 떨어진 거리(+ 가 오른쪽 아래).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float style = 0.0;
uniform float aspect = 1.7778;
uniform vec3 gaps = vec3(3.0);      // 일섬: 판 세 겹의 틈 (대각선에서 변까지)
uniform float tilt = 0.0;           // 일섬: 가위 각 (u 에 따른 틈 차이)
uniform float darken = 0.0;         // 판 색 → 다 덮인 어두운 색
uniform float back = 0.0;           // 판 아래 바탕 (1 = 완전히 가림)
uniform float dim = 0.0;            // 장면 보랏빛 어두워짐
uniform float bolt_tip = 0.0;       // 번개 쐐기 끝의 진행 (0 화면 밖 → 1 다 뻗음 → 2 반대편으로 빠져나감)
uniform float bolt_w = 0.0;         // 번개 쐐기 굵기 배율
uniform float bolt_hot = 0.0;       // 번개가 하얗게 달아오름
uniform float seam = 0.0;           // 대각선 이음매의 빛
uniform float flash = 0.0;          // 화면 전체 섬광
uniform float shake = 0.0;          // 충돌 흔들림 (s 방향)
uniform float split = 0.0;          // 장면 색 갈라짐 (대각선 방향)
uniform float shear = 0.0;          // 재단: 베인 두 쪽이 대각선을 따라 어긋난 거리
uniform float slit = 0.0;           // 재단: 베인 자리의 틈
uniform float strips_in = 0.0;      // 재단: 칼날 띠가 꽂히는 진행
uniform float strips_out = 0.0;     // 재단: 칼날 띠가 빠져나가는 진행
uniform float band_w = 0.118;       // 재단: 칼날 띠 굵기
uniform float spark_t = 0.0;        // 파편이 날아간 정도
uniform float spark_a = 0.0;
uniform vec3 col_bolt : source_color = vec3(0.93, 0.82, 1.0);
uniform vec3 col_glow : source_color = vec3(0.56, 0.25, 1.0);
uniform vec3 col_plate : source_color = vec3(0.184, 0.051, 0.443);
uniform vec3 col_dark : source_color = vec3(0.051, 0.039, 0.149);

const vec2 D = vec2(0.9187, -0.3950);   // 대각선 방향 (기울기 0.43, 원화와 같다)
const vec2 N = vec2(0.3950, 0.9187);
const float STAG = 0.9;                 // 재단: 띠 사이 시간차 (띠 하나가 움직이는 시간 대비)
const float TIP = 0.24;                 // 재단: 띠 끝의 뾰족한 길이

float hash(float x) {
	return fract(sin(x * 127.1 + 3.7) * 43758.5453);
}

// 번개 계단: 길게 오르다 툭 꺾이는 톱니 (-0.5 .. 0.5)
float notch(float x) {
	float f = fract(x);
	return (f < 0.84 ? f / 0.84 : 1.0 - (f - 0.84) / 0.16) - 0.5;
}

void fragment() {
	vec2 q = (UV - 0.5) * vec2(aspect, 1.0);
	float aa = fwidth(q.y) * 1.2;
	float u = dot(q, D);
	float s = dot(q, N) + shake;
	float sd = s >= 0.0 ? 1.0 : -1.0;
	float reach = 0.5 * aspect * D.x + 0.5 * abs(D.y);   // 화면 모서리까지의 u

	// ── 장면: 베인 두 쪽 어긋남 + 색 갈라짐 + 보랏빛 딤
	vec2 inv = vec2(1.0 / aspect, 1.0);
	vec2 suv = SCREEN_UV + D * shear * sd * inv;
	vec2 so = D * split * inv;
	vec3 col = vec3(texture(screen_tex, suv + so).r, texture(screen_tex, suv).g, texture(screen_tex, suv - so).b);
	col = mix(col, col_plate, dim);

	vec3 settled = mix(col_dark, col_plate, 0.10);
	col = mix(col, settled, back);
	vec3 violet = mix(col_plate, col_glow, 0.65);

	if (style < 0.5) {
		// ── 일섬: 판 세 겹 × 두 쪽. 앞판(0)이 대각선에서 맞물리고 뒤판은 바깥에 층을 남긴다
		for (int j = 0; j < 3; j++) {
			float fj = float(j);
			float g = gaps[j];
			float amp = 0.08 + 0.05 * fj;
			float e_lo = g + tilt * u + amp * notch(u / 1.27 + 0.31 + 0.37 * fj);
			float e_up = g - tilt * u + amp * notch(-u / 1.27 + 0.12 + 0.41 * fj);
			float d_lo = s - e_lo;
			float d_up = -s - e_up;
			float m = max(smoothstep(-aa, aa, d_lo), smoothstep(-aa, aa, d_up));
			float dd = max(d_lo, d_up);   // 변에서 안쪽으로 들어온 거리
			vec3 base = mix(col_plate, col_dark, 0.22 * fj);
			vec3 c = mix(base, mix(col_dark, base, 0.16 + 0.07 * fj), darken);
			// 변의 빛: 얇은 선 + 안쪽으로 번지는 보랏빛 (움직이는 동안만)
			float live = 1.0 - darken;
			c += violet * 0.55 * exp(-max(dd, 0.0) / 0.09) * live * (j == 0 ? 1.0 : 0.45);
			c = mix(c, mix(col_glow, col_bolt, 0.5), smoothstep(0.012, 0.004, dd) * live * (j == 0 ? 0.9 : 0.4));
			col = mix(col, c, m);
		}
	} else {
		// ── 재단: 베인 자리의 어두운 틈
		col = mix(col, col_dark, smoothstep(aa, -aa, abs(s) - slit * (1.0 + 0.5 * abs(u))) * step(0.0001, slit));
		// 대각선과 나란한 칼날 띠: 바깥 띠부터 길이 방향으로 꽂히고(이웃 띠는 반대쪽에서), 이음매 쪽 띠부터 그대로 빠져나간다
		float a_s = abs(s);
		float band = floor(a_s / band_w);
		float f = fract(a_s / band_w);
		float nb = floor((0.5 * aspect * N.x + 0.5 * N.y) / band_w) + 1.0;
		float dir = (mod(band, 2.0) < 0.5 ? 1.0 : -1.0) * sd;
		float uu = u * dir + TIP * abs(2.0 * f - 1.0);
		float span = 2.0 * reach + TIP + 0.3;
		float k_in = clamp(strips_in * (1.0 + STAG) - (nb - 1.0 - min(band, nb - 1.0)) / nb * STAG, 0.0, 1.0);
		float k_out = clamp(strips_out * (1.0 + STAG) - min(band, nb - 1.0) / nb * STAG, 0.0, 1.0);
		float lead = -reach - 0.15 + span * pow(k_in, 1.7);
		float trail = -reach - 0.15 + span * (1.0 - pow(1.0 - k_out, 3.0));
		float d_in = lead - uu;
		float d_out = uu - trail;
		float m = smoothstep(-aa, aa, d_in) * smoothstep(-aa, aa, d_out) * step(0.0001, k_in);
		vec3 base = mix(col_plate, col_dark, 0.5 * mod(band, 3.0) / 2.0);
		vec3 c = mix(base, mix(col_dark, base, 0.14 + 0.10 * mod(band, 3.0) / 2.0), darken);
		c *= 1.0 - 0.22 * smoothstep(0.10, 0.0, f) * (1.0 - 0.5 * darken);       // 띠 사이 골
		float moving_in = 1.0 - smoothstep(0.9, 1.0, k_in);
		float moving_out = step(0.0001, k_out);
		c += violet * 0.7 * (exp(-max(d_in, 0.0) / 0.16) * moving_in + exp(-max(d_out, 0.0) / 0.12) * moving_out);
		c = mix(c, col_bolt, max(smoothstep(0.016, 0.005, d_in) * moving_in, smoothstep(0.016, 0.005, d_out) * moving_out));
		col = mix(col, c, m);
	}

	// ── 파편: 대각선을 따라 흩어지는 길쭉한 타원 (원화의 타원 조각)
	if (spark_a > 0.001) {
		for (int i = 0; i < 14; i++) {
			float fi = float(i);
			float h1 = hash(fi), h2 = hash(fi + 17.0), h3 = hash(fi + 41.0), h4 = hash(fi + 73.0);
			float s0 = (h2 * 2.0 - 1.0) * 0.42;
			float way = s0 >= 0.0 ? 1.0 : -1.0;
			vec2 c0 = vec2((h1 * 2.0 - 1.0) * reach * 0.85 + way * (0.2 + 0.9 * h3) * spark_t, s0 * (0.25 + 0.75 * min(spark_t, 1.0)));
			vec2 r = vec2(0.035 + 0.075 * h4, 0.006 + 0.007 * h1) * (0.4 + 0.6 * min(spark_t * 3.0, 1.0));
			float e = length((vec2(u, s) - c0) / r);
			col = mix(col, mix(violet, col_glow, h3), smoothstep(1.0 + aa / r.y, 1.0 - aa / r.y, e) * spark_a);
		}
	}

	// ── 번개 쐐기: 두 모서리에서 대각선을 따라 서로를 향해 치고 들어온다
	if (bolt_w > 0.001) {
		for (int k = 0; k < 2; k++) {
			float way = k == 0 ? 1.0 : -1.0;
			float bu = u * way;
			float bs = s * way;
			float tip = bolt_tip <= 1.0 ? mix(-reach - 0.2, reach * 0.3, bolt_tip) : mix(reach * 0.3, reach * 3.4, bolt_tip - 1.0);
			float ramp_len = reach * 2.3;
			// 뒤따르는 보라 쐐기
			float behind2 = tip - 0.30 - bu;
			float w2 = bolt_w * (0.15 * clamp(behind2 / ramp_len, 0.0, 1.0) + 0.03 * smoothstep(0.42, 0.44, behind2));
			float off2 = style > 0.5 ? -0.5 * w2 : -0.035 * bolt_w;
			float m2 = step(0.0, behind2) * smoothstep(-aa, aa, bs - off2) * smoothstep(-aa, aa, off2 + w2 - bs);
			col = mix(col, mix(col_glow, vec3(1.0), bolt_hot * 0.5), m2);
			// 밝은 쐐기 + 번개 미늘(끝 뒤쪽에서 한 번 굵어진다)
			float behind = tip - bu;
			float w1 = bolt_w * (0.082 * clamp(behind / ramp_len, 0.0, 1.0) + 0.034 * smoothstep(0.60, 0.62, behind));
			float off1 = style > 0.5 ? -0.5 * w1 : 0.006;
			float m1 = step(0.0, behind) * smoothstep(-aa, aa, bs - off1) * smoothstep(-aa, aa, off1 + w1 - bs);
			col = mix(col, mix(col_bolt, vec3(1.0), bolt_hot), m1);
		}
	}

	// ── 이음매 빛과 전체 섬광
	float gl = seam * (exp(-abs(s) / 0.010) + 0.38 * exp(-abs(s) / 0.07));
	col += mix(col_glow, vec3(1.0), 0.55) * gl;
	col += mix(col_bolt, vec3(1.0), 0.4) * flash;
	COLOR = vec4(col, 1.0);
}
