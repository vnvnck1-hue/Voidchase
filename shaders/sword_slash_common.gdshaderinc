// 검기 공용: 쿼드 UV(0..1) → 호를 따라가는 검기 좌표.
// 쿼드 중심이 호의 중심이다. 각도는 turns 단위(0 = 오른쪽, 0.25 = 아래, y 아래 방향).
//   u  : 휘두르는 진행 방향 0(시작) → 1(끝)
//   s  : 지금 보이는 구간 [tail, head] 안에서의 위치 0(꼬리) → 1(머리)
//   v  : 두께 방향 0(바깥 날) → 1(안쪽)
//   sd : 초승달까지의 부호 거리 (uv 단위, 음수 = 안)

uniform float radius = 0.42;       // 바깥 날 반지름 (쿼드 한 변 = 1)
uniform float thickness = 0.16;    // 가장 두꺼운 곳의 두께
uniform float arc_start = 0.58;    // 시작 각 (turns)
uniform float arc_sweep = 0.5;     // 휘두르는 각 (turns, + = 시계 방향)
uniform float head : hint_range(0.0, 1.0) = 1.0;  // 칼끝이 지나간 위치
uniform float tail : hint_range(0.0, 1.0) = 0.0;  // 꼬리가 따라온 위치
uniform float thin : hint_range(0.0, 1.0) = 1.0;  // 두께 배율. 바깥 날은 고정, 안쪽부터 얇아진다
uniform float taper_tail = 0.55;   // 꼬리 쪽 가늘어짐 지수
uniform float taper_head = 0.3;    // 머리 쪽 가늘어짐 지수 (작을수록 칼끝이 뭉툭)

uint ss_hash_u(uvec2 q) {
	q *= uvec2(1597334673u, 3812015801u);
	uint n = (q.x ^ q.y) * 1597334673u;
	return n ^ (n >> 16u);
}

float ss_hash(vec2 p) {
	return float(ss_hash_u(uvec2(ivec2(floor(p)) + ivec2(32768)))) / 4294967295.0;
}

float ss_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = ss_hash(i);
	float b = ss_hash(i + vec2(1.0, 0.0));
	float c = ss_hash(i + vec2(0.0, 1.0));
	float d = ss_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float ss_fbm(vec2 p) {
	return ss_noise(p) * 0.57 + ss_noise(p * 2.03 + 17.1) * 0.29 + ss_noise(p * 4.07 + 41.7) * 0.14;
}

void ss_slash(vec2 uv, out float u, out float s, out float v, out float sd, out float aa) {
	vec2 p = uv - 0.5;
	float r = length(p);
	float a = atan(p.y, p.x) / TAU;
	float sw = max(abs(arc_sweep), 1e-3);
	float da = fract((a - arc_start) * sign(arc_sweep));
	u = da / sw;
	// 호가 비어 있는 구간의 가운데를 기준으로, 시작 직전은 음수 u 로 둔다
	if (u > 0.5 * (1.0 / sw + 1.0)) {
		u -= 1.0 / sw;
	}
	float span = max(head - tail, 1e-4);
	s = (u - tail) / span;
	float sc = clamp(s, 0.0, 1.0);
	float pk = taper_tail / (taper_tail + taper_head);
	float norm = pow(pk, taper_tail) * pow(1.0 - pk, taper_head);
	float prof = pow(sc, taper_tail) * pow(1.0 - sc, taper_head) / norm;
	// 꼬리가 머리를 따라잡아 구간이 짧아지면 두께도 같이 줄인다 (짧고 뚱뚱한 물방울 방지)
	float w = thickness * thin * prof * smoothstep(0.0, 0.4, span);
	v = (radius - r) / max(w, 1e-4);
	sd = max(r - radius, (radius - w) - r);
	// 보이는 구간 밖은 호 길이 방향 거리를 더해 끝이 둥글게 닫히게 한다
	float along = max(-s, s - 1.0) * span * sw * TAU * radius;
	sd = max(sd, along);
	aa = max(fwidth(r), 1e-4);
}
