// VOID DEFENSE 배경: 공허의 밤하늘. 짙은 남색 하늘 아래로 푸르게 빛나는 기체가 천천히 흐르고 섞인다.
// 기본값은 사용자가 배경 조정 패널로 맞춘 값(2026-11-05: 모양 0.33 = scale 1.724, 속도 0.11, 컬러 #291286).
// 팔레트는 패널 규칙(VDNebulaTuner._follow)대로 처음 레퍼런스 팔레트(남색 하늘 + 푸른 기체)를 #291286 쪽으로 옮긴 값이다.
//   - 큰 흐름(저주파 워핑)을 따라 세 층이 흐르고 섞인다: 라일락 덩어리 → 푸른 기체(가장자리가 부드럽게 빛남) → 앞쪽 밝은 구름
//   - 아래쪽일수록 기체가 짙고, 위쪽은 맑은 하늘
//   - parallax 는 카메라 움직임을 아주 조금 따라가 깊이감을 준다 (vd_camera.gd 가 매 프레임 넣는다)
shader_type canvas_item;

uniform vec4 col_deep : source_color = vec4(0.054, 0.033, 0.096, 1.0);    // 하늘 위쪽
uniform vec4 col_night : source_color = vec4(0.099, 0.065, 0.192, 1.0);   // 하늘 아래쪽
uniform vec4 col_lilac : source_color = vec4(0.283, 0.195, 0.384, 1.0);   // 라일락빛 덩어리
uniform vec4 col_gas : source_color = vec4(0.161, 0.071, 0.525, 1.0);     // 푸른 기체
uniform vec4 col_glow : source_color = vec4(0.293, 0.277, 0.640, 1.0);     // 기체 가장자리 빛
uniform float flow_speed : hint_range(0.0, 0.2) = 0.11;
uniform float scale : hint_range(0.5, 6.0) = 1.724;
uniform float gas_amount : hint_range(0.0, 1.0) = 0.9;
uniform float glow_amount : hint_range(0.0, 1.0) = 0.8;
uniform float dot_amount : hint_range(0.0, 1.0) = 0.7;
uniform float aspect = 1.7778;
uniform vec2 parallax = vec2(0.0);
uniform float phase = -1.0;   // 흐름 위상(누적 시간 x 속도). 음수면 TIME * flow_speed

// 작은 크기 값만 다루는 해시(Hoskins hash12). 큰 좌표에서 칸 경계 값이 어긋나 직선 이음새가 생기지 않도록
// noise() 에서 격자 좌표를 256 칸 주기로 감싼 뒤 넣는다.
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
	float a = hash(i0);
	float b = hash(vec2(i1.x, i0.y));
	float c = hash(vec2(i0.x, i1.y));
	float d = hash(i1);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// 옥타브 수를 고를 수 있는 fbm. 옥타브가 적을수록 둥글고 부드러운 덩어리가 된다.
float fbm_n(vec2 p, int octaves) {
	float v = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		if (i >= octaves) {
			break;
		}
		v += amp * noise(p);
		norm += amp;
		p = rot * p * 2.02 + vec2(1.7, 9.2);
		amp *= 0.5;
	}
	return v / norm;
}

// 떠도는 빛 알갱이 한 겹: 칸마다 하나, 천천히 위로 흐르며 반짝인다.
float dots(vec2 p, float t, float density, float size) {
	vec2 g = p * density + vec2(0.0, t);
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(mod(id, 256.0));
	if (h < 0.72) {
		return 0.0;
	}
	vec2 off = vec2(hash(mod(id, 256.0) + 0.37), hash(mod(id, 256.0) + 0.71)) - 0.5;
	float d = length(f - off * 0.6);
	float tw = 0.55 + 0.45 * sin(t * 8.0 + h * 40.0);
	return smoothstep(size, 0.0, d) * tw;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv - 0.5) * vec2(aspect, 1.0) * scale + parallax;
	// phase 를 스크립트가 넣으면(VDNebulaTuner) 그걸 쓴다: 속도가 바뀌어도 무늬가 튀지 않고 이어서 빨라진다
	float t = phase >= 0.0 ? phase : TIME * flow_speed;
	// 아래쪽일수록 기체가 짙다 (위쪽은 맑은 남색 하늘)
	float low = smoothstep(0.0, 0.9, uv.y);
	float mask = 0.3 + 0.7 * low;

	// 큰 흐름: 아주 낮은 주파수의 워핑 벡터. 모든 층이 이 흐름을 따라 천천히 휘어진다.
	vec2 w = vec2(fbm_n(p * 0.5 + vec2(t, 0.0), 3), fbm_n(p * 0.5 + vec2(4.1, -t), 3)) - 0.5;

	// 1) 뒤: 라일락빛 덩어리 (느리게)
	float b = fbm_n(p * 0.55 + 1.3 * w + vec2(-t * 0.6, t * 0.2), 3);
	float back = smoothstep(0.48, 0.7, b) * (0.4 + 0.6 * low);

	// 2) 가운데: 푸른 기체 — 서로 섞이며 흐른다 (워핑 두 단계)
	vec2 w2 = vec2(fbm_n(p * 0.8 + 1.8 * w + vec2(1.7, 9.2) + t * 0.8, 4),
		fbm_n(p * 0.8 + 1.8 * w + vec2(8.3, 2.8) - t * 0.6, 4)) - 0.5;
	float m = fbm_n(p * 0.75 + 1.5 * w2 + 0.8 * w, 4);
	float gas = smoothstep(0.44, 0.68, m) * mask;
	// 부드럽게 번지는 가장자리 빛 (기체 경계에서 가장 밝다) + 안쪽의 은은한 빛
	float rim = gas * (1.0 - gas) * 4.0;
	float inner = smoothstep(0.6, 0.85, m) * mask;

	// 3) 앞: 아래쪽에 밝게 피어오르는 구름 덩어리
	float fr = fbm_n(p * 0.9 + 1.2 * w2 + vec2(t * 1.3, -t * 0.4), 3);
	float front = smoothstep(0.56, 0.76, fr) * low * low;

	vec3 col = mix(col_deep.rgb, col_night.rgb, smoothstep(0.0, 1.0, uv.y));
	col = mix(col, col_lilac.rgb, back * 0.55);
	col = mix(col, col_gas.rgb, gas * gas_amount);
	col += col_glow.rgb * (rim * 0.32 + inner * 0.22) * glow_amount;
	col = mix(col, mix(col_gas.rgb, col_glow.rgb, 0.55), front * 0.55);

	// 빛 알갱이 두 겹 (가까운 쪽은 크고 빠르게)
	float d1 = dots(p + parallax * 0.5, t * 2.0, 2.2, 0.10);
	float d2 = dots(p + vec2(3.3, 1.1) + parallax, t * 3.5, 1.3, 0.07);
	col += col_glow.rgb * (d1 * 0.55 + d2 * 0.8) * dot_amount;

	COLOR = vec4(col, 1.0);
}
