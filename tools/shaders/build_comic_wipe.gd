## 팝아트 그래픽 와이프 화면 전환 VisualShader(shaders/comic_wipe.tres)를 노드 그래프로 생성한다. 손으로 고치지 말고 이 스크립트를 고쳐 다시 실행.
##   Godot --headless --path . -s res://tools/shaders/build_comic_wipe.gd
##
## 참고 그래픽(2026-11-09, 사용자 제공): 평면 색면, 삼각 파편, 하프톤 망점, 별 폭발 (형태). 색감은 두 번째 레퍼런스 "COLOR DROP #31"
## (어두운 차콜 바탕 + 핫핑크 + 흰색) 을 따른다: 색판 4장 = 짙은 회색 → 핫핑크 → 흰색 → 거의 검정, 망점·앞선 = 연핑크, 속도선·그라데이션 = 진한 핑크.
## 색 uniform 은 역할 이름(col_plane1~4 · col_accent · col_accent2)이라 팔레트를 바꿔도 노드 그래프는 그대로다.
## 모션그래픽의 '그래픽 와이프': 색판 여러 장이 시간차를 두고 한 방향으로 화면을 통째로 쓸고 들어와 덮고(0 → 0.5),
## 장면이 바뀐 뒤 같은 방향으로 꼬리를 끌며 빠져나간다(0.5 → 1). 색판 변에는 톱니 가시·떨어져 나는 파편·망점 띠·속도선이 붙는다.
## 마지막 색판의 입장이 정확히 0.5 에 끝나고 첫 퇴장이 0.5 에 시작해 중간에 멈추는 구간이 없다 (사용자 지적, 2026-11-09).
## (첫 버전의 '모서리에서 자라는 파편' 방식은 촌스럽고 단순하다는 평으로 폐기 — 2026-11-09)
##
## uniform preset 으로 두 가지:
##   0 슬래시 스택 : 기운 변의 색판 4장(plane1 → plane2 → plane3 → plane4)이 왼쪽 아래에서 오른쪽 위로 차례로 쓸고 들어와 쌓이고,
##                  걷힐 때는 위 판부터(plane4 → plane3 → plane2 → plane1) 빠져나가 색띠 꼬리가 남는다. plane2 앞변 망점, plane4 위 연핑크 망점, 별 폭발.
##   1 슬라이스   : 살짝 기운 가로 띠 6장이 번갈아 왼쪽/오른쪽에서 시간차로 꽂혀 들어와 줄무늬 색면을 만들고, 같은 순서로 빠져나간다.
##                  띠마다 앞변에 대비색 '입술'과 망점, 속도선.
## 도형은 전부 수식이라 해상도와 무관하고 가장자리는 1px 폭으로 안티에일리어싱. 망점 격자는 디자인 px 기준(view_size, dot_size) 45°.
## 마스크 계산은 Expression 노드 하나(Global Expression 함수 호출), 색 고르기·섞기·알파는 노드로 잇는다. 색은 모두 uniform.
extends SceneTree

const OUT := "res://shaders/comic_wipe.tres"
const F := VisualShader.TYPE_FRAGMENT
## canvas_item 프래그먼트 출력 포트 (VisualShaderNodeOutput 은 포트 조회 API 가 없다)
const OUT_COLOR := 0
const OUT_ALPHA := 1

const GLOBAL_CODE := """
// ---- 그래픽 와이프(graphic wipe) 도형 함수. 이름은 모두 gw_ 접두사 (uniform 이름과 겹치지 않게).
float gw_hash(float n) { return fract(sin(n * 127.1 + 311.7) * 43758.5453); }
// 쓸기 곡선: 급하게 출발해 급하게 멈춘다 (cubic in-out)
float gw_ease(float k) { k = clamp(k, 0.0, 1.0); return k < 0.5 ? 4.0 * k * k * k : 1.0 - pow(-2.0 * k + 2.0, 3.0) * 0.5; }
float gw_ease_out(float k) { k = clamp(k, 0.0, 1.0); return 1.0 - (1.0 - k) * (1.0 - k) * (1.0 - k); }
// 변의 위치: u 0..1 동안 lo → hi
float gw_pos(float u, float lo, float hi) { return mix(lo, hi, gw_ease(u)); }
float gw_tri(float c) { return 1.0 - abs(fract(c) * 2.0 - 1.0); }
// lo < x < hi 띠 (aa 폭으로 부드럽게)
float gw_band(float x, float lo, float hi, float aa) { return smoothstep(lo - aa, lo + aa, x) * (1.0 - smoothstep(hi - aa, hi + aa, x)); }

// 톱니 가시: 변을 따라가는 좌표 x 를 freq 칸으로 나눠 칸마다 직선 변 삼각형 하나. 길이(0.35~1배)·폭(칸의 55~95%)을 칸 해시로 변주.
float gw_saw(float x, float freq, float phase, float len, float sd) {
	float c = x * freq + phase;
	float cell = floor(c);
	float h = gw_hash(cell * 7.13 + sd);
	float w = mix(0.55, 0.95, gw_hash(cell * 3.71 + sd + 5.0));
	float s = clamp((gw_tri(c) - (1.0 - w)) / w, 0.0, 1.0);
	return len * mix(0.35, 1.0, h) * s;
}

// 하프톤: 45° 격자 셀 중심까지의 거리(셀 단위), 반지름 r 의 점 덮임
float gw_dotd(vec2 px, float dotpx) {
	vec2 gp = vec2(0.70710678 * (px.x - px.y), 0.70710678 * (px.x + px.y)) / dotpx;
	return length(fract(gp) - 0.5);
}
float gw_dotcov(float d, float r, float aa) { return r < 0.03 ? 0.0 : 1.0 - smoothstep(r - aa, r + aa, d); }

// 별 폭발 크기 배율: t0 부터 0.08 동안 튀어 오르며 나타나고, t0 + 0.22 부터 0.06 동안 줄어 사라진다
float gw_pop(float t, float t0) {
	float k = clamp((t - t0) / 0.08, 0.0, 1.0);
	float s = gw_ease_out(k) * (1.0 + 0.35 * sin(k * 3.14159));
	float v = clamp((t - (t0 + 0.22)) / 0.06, 0.0, 1.0);
	return s * (1.0 - v * v);
}

// 별 폭발: 기울인 어두운 마름모 바탕 + n 꼭짓점 별. 반환 (바탕, 별)
vec2 gw_star(vec2 d, float s, float n, float rot, float aa) {
	if (s <= 0.001) return vec2(0.0);
	float Rb = 0.085 * s;
	float Rs = 0.072 * s;
	vec2 dr = vec2(cos(rot) * d.x - sin(rot) * d.y, sin(rot) * d.x + cos(rot) * d.y);
	float sq = max(abs(dr.x), abs(dr.y));
	float bg = 1.0 - smoothstep(Rb - aa, Rb + aa, sq);
	float a = atan(d.y, d.x) - rot * 0.6;
	float m = 1.0 - abs(fract(a * n / 6.2831853) * 2.0 - 1.0);
	float re = Rs * mix(0.38, 1.0, pow(m, 2.4));
	float st = 1.0 - smoothstep(re - aa, re + aa, length(d));
	return vec2(bg, st);
}

// 변 좌표 x 를 따라 띄엄띄엄 놓인 가는 속도선: x 방향 띠 [x0, x0 + len]. ucoord 는 변을 따라가는 좌표.
float gw_streaks(float x, float ucoord, float x0, float dirsign, float freq, float sd, float aa) {
	float cs = ucoord * freq + gw_hash(sd + 3.0) * 9.0;
	float cl = floor(cs);
	float on = step(0.55, gw_hash(cl * 2.9 + sd + 50.0));
	float thin = smoothstep(0.78, 0.86, gw_tri(cs));
	float o0 = mix(0.03, 0.2, gw_hash(cl + sd + 60.0));
	float ol = mix(0.18, 0.5, gw_hash(cl * 1.3 + sd + 70.0));
	float a0 = x0 + dirsign * o0;
	float a1 = x0 + dirsign * (o0 + ol);
	return on * thin * gw_band(x, min(a0, a1), max(a0, a1), aa);
}

// 색판 안쪽 속도 줄무늬: 변 뒤쪽 [x0 - far, x0 - near] 구간에 진행 방향으로 뻗은 가는 줄 (칸의 절반만, 길이 변주)
float gw_stripes(float x, float ucoord, float x0, float dirsign, float freq, float sd, float aa) {
	float cs = ucoord * freq + gw_hash(sd + 5.0) * 9.0;
	float cl = floor(cs);
	float on = step(0.45, gw_hash(cl * 3.3 + sd + 80.0));
	float thin = smoothstep(0.74, 0.82, gw_tri(cs));
	float near = mix(0.08, 0.16, gw_hash(cl + sd + 90.0));
	float far = near + mix(0.14, 0.42, gw_hash(cl * 1.9 + sd + 100.0));
	float a0 = x0 - dirsign * near;
	float a1 = x0 - dirsign * far;
	return on * thin * gw_band(x, min(a0, a1), max(a0, a1), aa);
}

// ---- 프리셋 0: 슬래시 스택
// s = 진행 좌표(왼쪽 아래 → 오른쪽 위로 기운 변), v = 변을 따라가는 좌표. 판 k 의 앞변은 A[k] 부터, 뒷변(퇴장)은 B[k] 부터 0.24 동안 쓸고 간다.
void gw_slash(vec2 q, float t, float asp, float sd, float aa, float dd, float dotaa,
		out float mv, out float my, out float mm, out float md, out float mp, out float mo) {
	float slope = 0.42;
	float s = q.x + q.y * slope;
	float v = q.y - q.x * slope;
	float smax = 0.5 * asp + 0.5 * slope + 0.5;
	float smin = -smax;
	float A[4] = float[4](0.0, 0.087, 0.173, 0.26);     // 마지막 판이 0.26 + 0.24 = 0.5 에 다 들어온다
	float B[4] = float[4](0.76, 0.673, 0.587, 0.5);     // 위 판(어두운 보라)부터 0.5 에 바로 빠져나가기 시작, 마지막(보라)은 1.0 에 끝
	float FQ[4] = float[4](2.2, 3.4, 2.8, 4.2);
	float LN[4] = float[4](0.46, 0.3, 0.36, 0.22);
	float M[4];
	float LIP[4] = float[4](0.0, 0.0, 0.0, 0.0);   // 판 k 앞에 나는 작은 파편: 다음 판 색 (보라→분홍 · 노랑→어두운 보라 · 자홍→노랑 · 어두운 보라→보라)
	float LEAD[4];
	float TRAIL[4];
	for (int k = 0; k < 4; k++) {
		float fk = float(k);
		float lead = t < 0.5 ? gw_pos((t - A[k]) / 0.24, smin, smax) : smax + 1.0;
		float trail = t < 0.5 ? smin - 1.0 : gw_pos((t - B[k]) / 0.24, smin, smax);
		LEAD[k] = lead;
		TRAIL[k] = trail;
		float ph = gw_hash(sd + fk) * 9.0;
		// 큰 가시 + 사이사이 작은 가시를 겹쳐 계단처럼 규칙적이지 않게
		float jf = max(gw_saw(v, FQ[k], ph, LN[k], sd + fk), gw_saw(v, FQ[k] * 2.7, ph + 4.1, LN[k] * 0.45, sd + fk + 3.0));
		float jb = max(gw_saw(v, FQ[k] * 1.4, ph + 2.3, LN[k] * 0.7, sd + fk + 7.0), gw_saw(v, FQ[k] * 3.1, ph + 6.0, LN[k] * 0.3, sd + fk + 9.0));
		float m = gw_band(s, trail - jb, lead + jf, aa);
		// 앞변에서 떨어져 앞서 나는 파편 (칸의 절반 가까이) — 두 줄
		float c = v * FQ[k] + ph;
		float cell = floor(c);
		if (gw_hash(cell * 5.3 + sd + fk + 20.0) > 0.5) {
			float sh = clamp((gw_tri(c) - 0.45) / 0.55, 0.0, 1.0);
			float gap = mix(0.06, 0.2, gw_hash(cell + sd + 30.0 + fk));
			float ln = mix(0.2, 0.45, gw_hash(cell * 1.7 + sd + 40.0 + fk));
			float b0 = lead + LN[k] + gap;
			m = max(m, gw_band(s, b0, b0 + ln * sh, aa) * step(0.03, sh));
		}
		float c2 = v * FQ[k] * 1.9 + ph + 2.7;
		float cell2 = floor(c2);
		if (gw_hash(cell2 * 4.7 + sd + fk + 80.0) > 0.6) {
			float sh2 = clamp((gw_tri(c2) - 0.55) / 0.45, 0.0, 1.0);
			float gap2 = mix(0.25, 0.5, gw_hash(cell2 + sd + 90.0 + fk));
			float ln2 = mix(0.1, 0.25, gw_hash(cell2 * 1.3 + sd + 100.0 + fk));
			float b2 = lead + LN[k] + gap2;
			// 작은 파편은 다음 판 색(입술 색)으로
			LIP[k] = max(LIP[k], gw_band(s, b2, b2 + ln2 * sh2, aa) * step(0.03, sh2));
		}
		M[k] = m;
	}
	// 색판 안쪽 속도 줄무늬 (다음 판 색): 앞변 뒤 · 뒷변 앞
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		float st = gw_stripes(s, v, LEAD[k], 1.0, 30.0, sd + fk * 13.0, aa) + gw_stripes(s, v, TRAIL[k], -1.0, 30.0, sd + fk * 13.0 + 7.0, aa);
		LIP[k] = max(LIP[k], min(st, 1.0) * M[k] * (k == 2 ? 1.0 : 1.0 - M[k + 1]));
	}
	// 맨 앞을 가르는 분홍 선: 보라 판보다 먼저 0.14 동안 화면을 가로지른다 (퇴장 끝에도 한 번)
	float pre = gw_pos((t + 0.03) / 0.15, smin, smax);
	float post = gw_pos((t - 0.84) / 0.15, smin, smax);
	float line_a = t < 0.5 ? gw_band(s, pre - 0.05, pre, aa) : 0.0;
	float line_b = t >= 0.5 ? gw_band(s, post - 0.05, post, aa) : 0.0;
	mv = max(M[0], LIP[3]);
	my = max(M[1], LIP[2]);
	mm = M[2];
	md = max(M[3], LIP[1]);
	mp = max(LIP[0], max(line_a, line_b));
	// 노랑 앞변 앞 망점 띠: 보라 판 위에 노랑 점이 작아지며 사라진다
	float gy = (s - LEAD[1]) / 0.26;
	if (gy > 0.0 && gy < 1.0) my = max(my, gw_dotcov(dd, 0.72 * (1.0 - gy), dotaa) * mv);
	// 자홍 뒷변 뒤 망점 띠: 노랑 판 위에 분홍 점
	float gm = (TRAIL[2] - s) / 0.26;
	if (gm > 0.0 && gm < 1.0) mp = gw_dotcov(dd, 0.72 * (1.0 - gm), dotaa) * my;
	// 어두운 보라 판 위 분홍 망점 그라데이션 (오른쪽 위 모서리에서 번진다)
	vec2 corner = vec2(0.5 * asp, -0.5);
	float gc = clamp(1.0 - length(q - corner) / 0.95, 0.0, 1.0);
	mp = max(mp, gw_dotcov(dd, 0.62 * gc, dotaa) * md);
	// 색면 그라데이션 (레퍼런스의 자홍→분홍, 노랑→주황): 자홍 판은 변을 따라 분홍으로, 노랑 판은 왼쪽 아래로 갈수록 주황으로
	float gv = clamp((v + 0.6) / 1.2, 0.0, 1.0);
	mp = max(mp, M[2] * (1.0 - md) * smoothstep(0.25, 1.0, gv) * 0.85);
	float gyo = clamp((-(s) + 0.3) / 1.4, 0.0, 1.0);
	float orange_grad = M[1] * (1.0 - max(M[2], md)) * smoothstep(0.35, 1.0, gyo) * 0.7;
	// 속도선(주황): 첫 판(보라) 앞변 앞 · 마지막으로 빠지는 보라 판 뒷변 뒤
	mo = gw_streaks(s, v, LEAD[0] + LN[0], 1.0, 16.0, sd, aa) + gw_streaks(s, v, TRAIL[0] - LN[0], -1.0, 16.0, sd + 11.0, aa);
	mo = min(mo + orange_grad, 1.0);
}

void gw_put(int ci, float val, inout float a, inout float b, inout float c, inout float d) {
	if (ci == 0) a = max(a, val);
	else if (ci == 1) b = max(b, val);
	else if (ci == 2) c = max(c, val);
	else d = max(d, val);
}

// ---- 프리셋 1: 슬라이스. 기운 가로 띠 6장, 짝수 띠는 왼쪽에서 홀수 띠는 오른쪽에서, 위부터 시간차로.
void gw_slice(vec2 q, float t, float asp, float sd, float aa, float dd, float dotaa,
		out float mv, out float my, out float mm, out float md, out float mp, out float mo) {
	mv = 0.0; my = 0.0; mm = 0.0; md = 0.0; mp = 0.0; mo = 0.0;
	float tilt = 0.22;
	float bh = 0.25;
	float vv = q.y - q.x * tilt + 0.75;
	float fi = clamp(floor(vv / bh), 0.0, 5.0);
	float vl = vv - fi * bh;
	float dir = mod(fi, 2.0) < 0.5 ? 1.0 : -1.0;
	float x = q.x * dir;
	float xmax = 0.5 * asp + 0.35;
	float xmin = -xmax;
	float a = fi * 0.052 + gw_hash(sd + fi) * 0.016;        // 마지막 띠가 <= 0.276 + 0.22 = 0.5 에 다 들어온다
	float b = 0.5 + fi * 0.052 + gw_hash(sd + fi + 9.0) * 0.016;
	float lead = t < 0.5 ? gw_pos((t - a) / 0.22, xmin, xmax) : xmax + 1.0;
	float trail = t < 0.5 ? xmin - 1.0 : gw_pos((t - b) / 0.22, xmin, xmax);
	float slant = (vl / bh - 0.5) * 0.12;
	float ph = gw_hash(sd + fi + 4.0) * 9.0;
	float jf = gw_saw(vv, 12.0, ph, 0.11, sd + fi);
	float jb = gw_saw(vv, 14.0, ph + 1.7, 0.08, sd + fi + 7.0);
	float front = lead + slant + jf;
	float back = trail + slant - jb;
	float m = gw_band(x, back, front, aa);
	// 입술: 앞변(입장) · 뒷변(퇴장) 안쪽 0.09 폭의 대비색 띠
	float lipw = 0.09;
	float lip = m * max(smoothstep(front - lipw - aa, front - lipw + aa, x), 1.0 - smoothstep(back + lipw - aa, back + lipw + aa, x));
	// 망점: 앞변 앞 · 뒷변 뒤 0.14 폭, 입술 색 점이 작아지며 사라진다
	float gf = (x - front) / 0.14;
	float gb = (back - x) / 0.14;
	float dots = 0.0;
	if (gf > 0.0 && gf < 1.0) dots = gw_dotcov(dd, 0.7 * (1.0 - gf), dotaa);
	if (gb > 0.0 && gb < 1.0) dots = max(dots, gw_dotcov(dd, 0.7 * (1.0 - gb), dotaa));
	int ci = int(mod(fi * 3.0 + 1.0, 4.0));
	int li = (ci + 2) % 4;
	// 띠 안쪽 속도 줄무늬 (입술 색): 앞변 뒤 · 뒷변 앞
	float st = min(gw_stripes(x, vv, front - lipw, 1.0, 64.0, sd + fi * 13.0, aa) + gw_stripes(x, vv, back + lipw, -1.0, 64.0, sd + fi * 13.0 + 7.0, aa), 1.0) * m;
	gw_put(ci, m * (1.0 - lip) * (1.0 - st), mv, my, mm, md);
	gw_put(li, max(max(lip, dots), st), mv, my, mm, md);
	// 속도선(주황): 앞변 앞 · 뒷변 뒤
	mo = min(gw_streaks(x, vv, front + 0.02, 1.0, 40.0, sd + fi, aa) + gw_streaks(x, vv, back - 0.02, -1.0, 40.0, sd + fi + 11.0, aa), 1.0);
	// 다 덮이는 순간의 어두운 보라 슬랩: 0.38 부터 위에서 내려와 줄무늬를 가리고(0.5 전부), 0.5 부터 아래로 벗겨진다. 변은 톱니, 위에 분홍 망점 그라데이션
	float jag = gw_saw(q.x, 5.0, gw_hash(sd + 21.0) * 9.0, 0.14, sd + 21.0);
	float top = t < 0.5 ? -0.75 : gw_pos((t - 0.5) / 0.13, -0.75, 0.75);
	float bottom = t < 0.5 ? gw_pos((t - 0.37) / 0.13, -0.75, 0.75) : 0.75 + 1.0;
	float slab = gw_band(q.y, top + jag, bottom + jag, aa);
	if (slab > 0.001) {
		mv *= 1.0 - slab; my *= 1.0 - slab; mm *= 1.0 - slab; mo *= 1.0 - slab;
		md = max(md, slab);
		vec2 corner = vec2(-0.5 * asp, 0.5);
		float gc = clamp(1.0 - length(q - corner) / 1.0, 0.0, 1.0);
		mp = max(mp, gw_dotcov(dd, 0.62 * gc, dotaa) * slab);
	}
}
"""

## Expression 노드 본문. 포트 이름은 uniform 과 겹치지 않게 p_/o_ 접두사.
const MASK_CODE := """
vec2 q = (p_uv - 0.5) * vec2(p_aspect, 1.0);
float aa = 1.2 / p_view.y;
float t = clamp(p_prog, 0.0, 1.0);
float dd = gw_dotd(p_uv * p_view, p_dot);
float dotaa = 1.0 / p_dot;
float mv; float my; float mm; float md; float mp; float mo;
if (p_preset < 0.5) gw_slash(q, t, p_aspect, p_seed, aa, dd, dotaa, mv, my, mm, md, mp, mo);
else gw_slice(q, t, p_aspect, p_seed, aa, dd, dotaa, mv, my, mm, md, mp, mo);
o_v = mv;
o_y = my;
o_m = mm;
o_d = md;
o_p = mp;
o_o = mo;
// 별 폭발 (다 덮인 동안): 오른쪽 위 · 왼쪽 아래
vec2 s1 = gw_star(q - vec2(0.5 * p_aspect - 0.3, -0.33), gw_pop(t, 0.4), 9.0, 0.4 + t * 4.0, aa);
vec2 s2 = gw_star(q - vec2(-0.5 * p_aspect + 0.3, 0.3), gw_pop(t, 0.44) * 0.8, 9.0, 1.1 - t * 5.0, aa);
o_sbg = max(s1.x, s2.x);
o_star = max(s1.y, s2.y);
o_alpha = max(max(max(mv, my), max(mm, md)), max(max(mp, mo), max(o_sbg, o_star)));
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
	print("[comic_wipe] saved %s err=%d nodes=%d" % [OUT, err, _next_id - 2])
	print(vs.get_code())
	quit(0 if err == OK else 1)


func _build() -> void:
	# --- 함수 (Global Expression)
	var g := VisualShaderNodeGlobalExpression.new()
	g.set_expression(GLOBAL_CODE)
	g.size = Vector2(900, 1400)
	vs.add_node(F, g, Vector2(-2600, -1800), _next_id)
	_next_id += 1

	# --- 파라미터
	var progress := _fparam("progress", 0.0, 0.0, 1.0)
	var preset := _fparam("preset", 0.0, 0.0, 1.0)
	var aspect := _fparam("aspect", 1.7778, 0.5, 4.0)
	var seed := _fparam("seed", 0.0, 0.0, 100.0)
	var view := _param(VisualShaderNodeVec2Parameter.new(), "view_size", Vector2(1920, 1080))
	var dot_size := _fparam("dot_size", 14.0, 4.0, 40.0)
	# 팔레트 "COLOR DROP #31": 차콜 · 핫핑크 · 흰색
	var c_violet := _cparam("col_plane1", Color(0.16, 0.165, 0.19))     # 첫 판: 짙은 회색
	var c_yellow := _cparam("col_plane2", Color(0.95, 0.15, 0.37))      # 둘째 판: 핫핑크 (주 강조색)
	var c_magenta := _cparam("col_plane3", Color(0.98, 0.97, 0.97))     # 셋째 판: 흰색
	var c_deep := _cparam("col_plane4", Color(0.09, 0.09, 0.105))       # 넷째 판(다 덮인 화면): 거의 검정
	var c_pink := _cparam("col_accent", Color(1.0, 0.47, 0.64))         # 망점 · 앞선 · 흰 판 그라데이션: 연핑크
	var c_orange := _cparam("col_accent2", Color(0.78, 0.07, 0.28))     # 속도선 · 핫핑크 판 그라데이션: 진한 핑크

	# --- 마스크 (Expression 하나)
	_newcol()
	var S := VisualShaderNode.PORT_TYPE_SCALAR
	var outs := ["o_alpha", "o_v", "o_y", "o_m", "o_d", "o_p", "o_o", "o_sbg", "o_star"]
	var out_ports := []
	for o in outs:
		out_ports.append([o, S])
	var m := _expr(
		[["p_uv", VisualShaderNode.PORT_TYPE_VECTOR_2D], ["p_prog", S], ["p_preset", S], ["p_aspect", S], ["p_seed", S],
			["p_view", VisualShaderNode.PORT_TYPE_VECTOR_2D], ["p_dot", S]],
		out_ports, MASK_CODE,
		[_input("uv"), progress, preset, aspect, seed, view, dot_size])
	var o := {}
	for i in outs.size():
		o[outs[i]] = [m, i]

	# --- 색 섞기: plane1 → plane2 → plane3 → plane4 → 연핑크 망점 → 진한 핑크 속도선 → 별 바탕(핫핑크) → 별(흰색)
	_newcol()
	var col := _mix3(c_violet, c_yellow, o["o_y"])
	col = _mix3(col, c_magenta, o["o_m"])
	col = _mix3(col, c_deep, o["o_d"])
	col = _mix3(col, c_pink, o["o_p"])
	_newcol()
	col = _mix3(col, c_orange, o["o_o"])
	col = _mix3(col, c_yellow, o["o_sbg"])
	col = _mix3(col, c_magenta, o["o_star"])

	_newcol()
	_connect(col, OUT_COLOR)
	_connect(o["o_alpha"], OUT_ALPHA)


# ------------------------------------------------------------ 노드 헬퍼 (build_ui_glitch.gd 와 같은 꼴)
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
	# 색 파라미터는 vec4 → vec3 로 쓰려고 분해 후 다시 묶는다
	var d := _decompose4([_add(n), 0])
	return _compose3([d, 0], [d, 1], [d, 2])


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
