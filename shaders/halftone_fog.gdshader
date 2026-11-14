// 앞 안개 '하프톤' 스타일 (2026-11-09). 서브컬처·일본 애니메이션 그래픽에서 쓰는 망점(스크린톤) 그라데이션으로 가장자리를 덮는다.
//   맑은 중앙 → 안개 색 도트가 점점 커지며 → 솔리드 안개 → 그 안쪽에 밝은 도트가 점점 작아지며 사라진다 (투톤 하프톤).
// 도트 격자는 화면 픽셀 기준(1080p 기준 px, 기본 45° 회전)이라 카메라 줌·흔들림과 상관없이 고정된다. 경계는 fbm 노이즈로 천천히 일렁인다.
// 색은 VDNebulaTuner 가 배경 컬러를 따라 넣는다 (fog_color = 안개 본색, wisp_color = 밝은 도트 색). ht_* 는 패널 슬라이더.
shader_type canvas_item;
#include "res://shaders/field_look.gdshaderinc"   // 필드 연구실 색 보정 (fl_*)

uniform vec4 fog_color : source_color = vec4(0.054, 0.033, 0.096, 1.0);
uniform vec4 wisp_color : source_color = vec4(0.293, 0.277, 0.640, 1.0);
uniform float ht_strength : hint_range(0.0, 1.0) = 0.92;   // 안개(도트) 불투명도
uniform float ht_reach : hint_range(0.0, 1.0) = 0.33;      // 안쪽으로 파고드는 정도 (0.5 = 예전 그라데이션과 같음)
uniform float ht_size : hint_range(4.0, 40.0) = 14.0;      // 도트 간격 (1080p 기준 px)
uniform float ht_angle : hint_range(0.0, 90.0) = 45.0;     // 격자 각도 (45 = 전형적인 스크린톤)
uniform float ht_light : hint_range(0.0, 1.0) = 0.70;      // 솔리드 안쪽 밝은 도트 띠의 폭·크기
uniform float ht_wobble : hint_range(0.0, 1.0) = 0.35;     // 경계 일렁임 (0 = 매끈한 기하 경계)
uniform float ht_speed : hint_range(0.0, 0.3) = 0.06;      // 일렁임 흐름 속도
uniform float bottom_boost : hint_range(0.0, 1.0) = 0.25;  // 아래쪽을 조금 더 깊게
uniform float aspect = 1.7778;
uniform float wisp_phase = -1.0;  // 흐름 위상(누적 시간 x 속도). 음수면 TIME * ht_speed
// 입장 연출 (VDFogReveal): reveal 0 = 화면 전체가 솔리드 안개, 1 = 평소. 그 사이엔 중앙에서 타원 구멍이 열리며
// 구멍 테두리가 망점 그라데이션(작은 도트 → 큰 도트 → 솔리드 → 안쪽 밝은 도트)이 된다. 격자는 평소 안개와 같은 화면 격자라 겹쳐도 어긋나지 않는다.
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float edge_mask : hint_range(0.0, 1.0) = 1.0;    // 0 이면 가장자리 안개를 끄고 reveal 구멍만 그린다 (연출 덧판용)
uniform float reveal_width : hint_range(0.1, 1.0) = 0.45; // 구멍 테두리 망점 띠의 폭 (radial 거리 단위)

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec2 i0 = mod(i, 256.0);
	vec2 i1 = mod(i + 1.0, 256.0);
	return mix(mix(hash(i0), hash(vec2(i1.x, i0.y)), u.x), mix(hash(vec2(i0.x, i1.y)), hash(i1), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 3; i++) {
		v += amp * noise(p);
		p = rot * p * 2.02 + vec2(1.7, 9.2);
		amp *= 0.5;
	}
	return v / 0.875;
}

// 셀 중심에서의 거리 d 를 반지름 r 의 원으로 자른 덮임(0..1). aa 는 셀 단위로 약 1 픽셀.
float dot_cover(float d, float r, float aa) {
	return 1.0 - smoothstep(r - aa, r + aa, d);
}

void fragment() {
	vec2 uv = UV - 0.5;
	// 바탕 마스크: void_vignette 와 같은 방사형 + 가장자리 그라데이션. reach 로 맑은 영역을 넓히거나 좁힌다
	float shift = (0.5 - ht_reach) * 0.8;
	vec2 r = vec2(uv.x * 1.15, uv.y * 1.5);
	float radial_d = length(r) * 2.0;
	float ex_d = abs(uv.x) * 2.0;
	float ey_d = abs(uv.y) * 2.0;
	// 경계 일렁임: 느린 fbm 으로 거리값을 밀고 당긴다
	vec2 p = UV * vec2(aspect, 1.0) * 3.0;
	float t = wisp_phase >= 0.0 ? wisp_phase : TIME * ht_speed;
	float n = fbm(p + vec2(-t * 1.3, t * 0.5));
	float push = (n - 0.5) * 0.6 * ht_wobble;
	float radial = smoothstep(0.55 + shift, 1.25 + shift, radial_d + push);
	float ex = smoothstep(0.72 + shift * 0.5, 1.0, ex_d + push * 0.6);
	float ey = smoothstep(0.72 + shift * 0.5, 1.0, ey_d + push * 0.6);
	float bottom = smoothstep(0.1, 0.5, uv.y + push * 0.3) * bottom_boost;
	float m = clamp(max(radial, max(ex, ey)) + bottom, 0.0, 1.0) * edge_mask;
	if (reveal < 1.0) {
		// 구멍 반지름: -0.3(중앙까지 다 덮음) → 2.5(띠 안쪽 끝까지 모서리 밖). 경계는 가장자리 안개와 같은 fbm 으로 일렁인다
		float rr = mix(-0.3, 2.5, reveal);
		m = max(m, smoothstep(rr - reveal_width, rr, radial_d + push));
	}

	// 화면 픽셀 격자: 1080p 기준 px 를 실제 해상도에 맞춰 늘리고(k), 각도만큼 회전
	float k = max((1.0 / SCREEN_PIXEL_SIZE.y) / 1080.0, 0.25);
	float cell = max(ht_size * k, 2.0);
	float ang = radians(ht_angle);
	mat2 rot = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
	vec2 g = (rot * FRAGCOORD.xy) / cell;
	float aa = 0.9 / cell;

	// A: 안개 색 도트 — 맑은 곳에서 작게 시작해 커지다가(0.82 셀 ≈ 이웃과 맞닿음) 솔리드로 합쳐진다
	float ta = smoothstep(0.0, 0.62, m);
	float ra = ta * 0.82;
	float da = length(fract(g) - 0.5);
	float cover = dot_cover(da, ra, aa);
	cover = max(cover, smoothstep(0.60, 0.68, m));
	// B: 솔리드 안쪽의 밝은 도트 — 경계 근처에서 크고 깊어질수록 작아진다 (반 칸 어긋난 격자라 A 도트 사이에 앉는다)
	float tb = smoothstep(0.58, 1.0, m);
	float rb = (1.0 - tb) * 0.5 * ht_light;
	float db = length(fract(g + 0.5) - 0.5);
	float light = dot_cover(db, rb, aa) * step(0.001, rb) * cover;
	vec3 col = mix(fog_color.rgb, wisp_color.rgb, light);
	COLOR = fl_apply(vec4(col, cover * ht_strength));
}
