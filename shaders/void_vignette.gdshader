// 화면 가장자리를 공허의 기체가 덮는 안개. 맵이 화면 밖으로 사라지는 느낌을 준다.
// 예전 방사형 + 가장자리 그라데이션을 바탕 마스크로 쓰고, 그 경계를 흐르는 기체(도메인 워핑 fbm)로 일렁이게 한다.
//   - 마스크 경계가 노이즈로 밀렸다 당겨지며 천천히 흐른다 (wisp_amount 만큼)
//   - 안개 안쪽도 짙고 옅은 결이 흐르고, 결의 밝은 부분은 wisp_color 로 은은하게 빛난다
// 파라미터는 VDNebulaTuner(배경 조정 패널)에서 실시간으로 바꾼다. 기본값은 사용자가 패널로 맞춘 값(2026-11-05).
shader_type canvas_item;

uniform vec4 fog_color : source_color = vec4(0.046, 0.028, 0.082, 1.0);
uniform vec4 wisp_color : source_color = vec4(0.105, 0.046, 0.342, 1.0);  // 기체 결의 밝은 부분
uniform float radial_inner : hint_range(0.0, 1.5) = 0.55;   // 이 반지름까지는 맑음
uniform float radial_outer : hint_range(0.0, 2.0) = 1.25;   // 여기서 안개 최대
uniform float edge_start : hint_range(0.0, 1.0) = 0.72;     // 가장자리 안개 시작 (중심 기준 0..1)
uniform float strength : hint_range(0.0, 1.0) = 0.82;
uniform float bottom_boost : hint_range(0.0, 1.0) = 0.25;   // 아래쪽을 조금 더 깊게
uniform float reach : hint_range(0.0, 1.0) = 0.33;           // 안개가 안쪽으로 파고드는 정도 (0.5 = 예전 그라데이션과 같음)
uniform float wisp_scale : hint_range(0.5, 8.0) = 7.05;      // 기체 결의 크기 (클수록 잘다)
uniform float wisp_speed : hint_range(0.0, 0.3) = 0.25;     // 흐르는 속도
uniform float wisp_amount : hint_range(0.0, 1.0) = 0.84;     // 경계 일렁임·결의 세기 (0 = 예전처럼 매끈)
uniform float wisp_glow : hint_range(0.0, 1.0) = 0.73;      // 결의 밝은 부분 세기
uniform float aspect = 1.7778;
uniform float wisp_phase = -1.0;  // 흐름 위상(누적 시간 x 속도). 음수면 TIME * wisp_speed

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
	for (int i = 0; i < 4; i++) {
		v += amp * noise(p);
		p = rot * p * 2.02 + vec2(1.7, 9.2);
		amp *= 0.5;
	}
	return v / 0.9375;
}

void fragment() {
	vec2 uv = UV - 0.5;
	// 바탕 마스크: 예전 그라데이션. reach 로 맑은 영역을 넓히거나 좁힌다
	float shift = (0.5 - reach) * 0.8;
	vec2 r = vec2(uv.x * 1.15, uv.y * 1.5);
	float radial_d = length(r) * 2.0;
	float ex_d = abs(uv.x) * 2.0;
	float ey_d = abs(uv.y) * 2.0;

	// 흐르는 기체: 큰 흐름 w 로 휘게 한 fbm 두 장
	vec2 p = UV * vec2(aspect, 1.0) * wisp_scale;
	float t = wisp_phase >= 0.0 ? wisp_phase : TIME * wisp_speed;
	vec2 w = vec2(fbm(p * 0.6 + vec2(t, -t * 0.4)), fbm(p * 0.6 + vec2(5.2, 1.3) - vec2(t * 0.6, -t))) - 0.5;
	float n = fbm(p + 1.8 * w + vec2(-t * 1.3, t * 0.5));
	float n2 = fbm(p * 1.7 + 2.4 * w + vec2(t * 0.8, t * 1.1) + 3.7);
	// 경계를 노이즈로 밀고 당긴다 (거리값에 더해 경계가 구불거리며 흐름)
	float push = (n - 0.5) * 0.7 * wisp_amount;
	float radial = smoothstep(radial_inner + shift, radial_outer + shift, radial_d + push);
	float ex = smoothstep(edge_start + shift * 0.5, 1.0, ex_d + push * 0.6);
	float ey = smoothstep(edge_start + shift * 0.5, 1.0, ey_d + push * 0.6);
	float bottom = smoothstep(0.1, 0.5, uv.y + push * 0.3) * bottom_boost;
	float mask = clamp(max(radial, max(ex, ey)) + bottom, 0.0, 1.0);
	// 안개 안쪽의 짙고 옅은 결
	float density = mix(1.0, 0.55 + 0.75 * n2, wisp_amount);
	float a = clamp(mask * density, 0.0, 1.0) * strength;
	// 결의 밝은 부분: 안개가 옅어지기 시작하는 경계 근처와 n2 가 높은 곳에서 은은하게
	float glow = smoothstep(0.55, 0.85, n2) * smoothstep(0.05, 0.6, mask) * (1.0 - mask * 0.5) * wisp_glow;
	vec3 col = mix(fog_color.rgb, wisp_color.rgb, glow);
	COLOR = vec4(col, a);
}
