// 화면 CRT 효과. SceneSwitcher 가 띄우는 CanvasLayer(99) 의 전체 화면 ColorRect 에 걸려 그 아래 모든 것을 브라운관처럼 보이게 한다.
// 값은 scripts/crt_overlay.gd 의 프리셋/조정 패널(F7)이 넣는다. 길이 단위 px 는 1080p 기준이고 실제 해상도에 맞춰 늘인다.
//   1) 화면 휨(curvature) + 둥근 모서리(corner) 로 유리면 느낌      2) 색수차(aberration) · 가로 색 번짐(bleed)
//   3) 블룸(bloom, 스크린 텍스처 밉맵)                                  4) 밝기·대비·채도·형광체 색조(tint)
//   5) 주사선(scan_*) · 형광체 줄무늬(mask_*) · 인터레이스 떨림           6) 비네트 · 깜빡임 · 흘러내리는 띠(roll) · 노이즈 · 가로 떨림(jitter)
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;

group_uniforms glass;
uniform float curvature : hint_range(0.0, 0.3) = 0.0;      // 화면 휨 (0 = 평면)
uniform float corner : hint_range(0.0, 0.2) = 0.0;         // 둥근 모서리 반지름
uniform float edge_fade : hint_range(0.0005, 0.05) = 0.004; // 테두리 경계 부드러움
group_uniforms color;
uniform float aberration : hint_range(0.0, 6.0) = 0.0;     // 색수차 (px, 가장자리로 갈수록 세짐)
uniform float bleed : hint_range(0.0, 6.0) = 0.0;          // 가로 색 번짐 (px)
uniform float bloom : hint_range(0.0, 1.0) = 0.0;          // 밝은 곳 번짐
uniform float bloom_radius : hint_range(1.0, 16.0) = 5.0;  // 번짐 반지름 (px)
uniform float brightness : hint_range(0.5, 2.0) = 1.0;
uniform float contrast : hint_range(0.5, 1.6) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float tint_r : hint_range(0.5, 1.5) = 1.0;         // 형광체 색조 (채널 배율)
uniform float tint_g : hint_range(0.5, 1.5) = 1.0;
uniform float tint_b : hint_range(0.5, 1.5) = 1.0;
group_uniforms lines;
uniform float scan_strength : hint_range(0.0, 1.0) = 0.0;  // 주사선 어둡기
uniform float scan_pitch : hint_range(1.5, 12.0) = 3.0;    // 주사선 간격 (px)
uniform float scan_sharp : hint_range(0.5, 6.0) = 1.5;     // 주사선 날카로움
uniform float mask_strength : hint_range(0.0, 1.0) = 0.0;  // 형광체 세로 줄무늬 (RGB)
uniform float mask_pitch : hint_range(1.0, 6.0) = 2.0;     // 줄무늬 한 칸 폭 (실제 px)
uniform float interlace : hint_range(0.0, 1.0) = 0.0;      // 주사선이 프레임마다 반 칸씩 번갈아 (떨림)
group_uniforms time;
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_size : hint_range(0.2, 1.5) = 0.8;  // 어두워지기 시작하는 반지름
uniform float flicker : hint_range(0.0, 0.3) = 0.0;        // 밝기 깜빡임
uniform float noise_amount : hint_range(0.0, 0.5) = 0.0;   // 지직거림
uniform float roll_strength : hint_range(0.0, 1.0) = 0.0;  // 흘러내리는 어두운 띠
uniform float roll_speed : hint_range(0.0, 2.0) = 0.25;
uniform float roll_height : hint_range(0.02, 0.6) = 0.18;
uniform float jitter : hint_range(0.0, 6.0) = 0.0;         // 줄마다 가로 떨림 (px)

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float k = res.y / 1080.0;              // 1080p 기준 px → 실제 px
	vec2 px = SCREEN_PIXEL_SIZE * k;       // 1080p 기준 1px 를 UV 로

	// 1) 유리면: 배럴 왜곡. 모서리가 화면 끝에 닿도록 (1+curvature) 로 되돌린다
	vec2 c = SCREEN_UV * 2.0 - 1.0;
	vec2 cc = c;
	cc.x *= 1.0 + c.y * c.y * curvature;
	cc.y *= 1.0 + c.x * c.x * curvature;
	cc /= 1.0 + curvature;
	vec2 uv = cc * 0.5 + 0.5;
	// 둥근 모서리 마스크 (휜 좌표 기준)
	vec2 q = abs(cc) - (1.0 - corner);
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner;
	float edge = 1.0 - smoothstep(-edge_fade, edge_fade, d);

	// 6) 가로 떨림 (줄 단위, 60fps 박자)
	if (jitter > 0.0) {
		float row = floor(uv.y * res.y / (2.0 * k));
		uv.x += (hash12(vec2(row, floor(TIME * 60.0))) - 0.5) * 2.0 * jitter * px.x;
	}

	// 2) 색수차 + 가로 색 번짐
	float ab = aberration * mix(0.3, 1.0, length(cc) * 0.7071) * px.x;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(ab, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(ab, 0.0)).b;
	if (bleed > 0.0) {
		vec2 bo = vec2(bleed * px.x, 0.0);
		vec3 l = texture(screen_tex, uv - bo).rgb;
		vec3 r = texture(screen_tex, uv + bo).rgb;
		vec3 soft = (l + col + r) / 3.0;
		col = soft - luma(soft) + luma(col);   // 밝기는 그대로, 색만 번진다
	}

	// 3) 블룸: 밉맵으로 흐린 화면의 밝은 부분을 더한다
	if (bloom > 0.0) {
		vec2 bo = px * bloom_radius;
		vec3 g = textureLod(screen_tex, uv, 2.0).rgb * 2.0;
		g += textureLod(screen_tex, uv + vec2(bo.x, 0.0), 1.5).rgb;
		g += textureLod(screen_tex, uv - vec2(bo.x, 0.0), 1.5).rgb;
		g += textureLod(screen_tex, uv + vec2(0.0, bo.y), 1.5).rgb;
		g += textureLod(screen_tex, uv - vec2(0.0, bo.y), 1.5).rgb;
		g /= 6.0;
		col += g * g * bloom * 1.6;
	}

	// 4) 색 보정
	col = (col - 0.5) * contrast + 0.5;
	col = mix(vec3(luma(col)), col, saturation);
	col *= vec3(tint_r, tint_g, tint_b) * brightness;

	// 5) 주사선 · 형광체 줄무늬. 간격은 실제 px 정수로 맞춰 모아레를 막는다 (주사선은 1080p 기준 값을 해상도에 맞게 늘인 뒤 반올림)
	vec2 spx = uv * res;        // 실제 px 좌표 (휜 화면 기준)
	float pitch = max(1.0, round(scan_pitch * k));
	float phase = interlace * 0.5 * step(0.5, fract(TIME * 30.0));
	float s = pow(0.5 + 0.5 * cos(TAU * (spx.y / pitch + phase)), scan_sharp);
	col *= 1.0 - scan_strength * (1.0 - s);
	if (mask_strength > 0.0) {
		float m = mod(floor(FRAGCOORD.x / max(1.0, round(mask_pitch))), 3.0);
		vec3 mk = vec3(float(m < 0.5), float(m > 0.5 && m < 1.5), float(m > 1.5));
		col *= mix(vec3(1.0), mk * 1.3 + 0.35, mask_strength);
	}

	// 6) 비네트 · 깜빡임 · 띠 · 노이즈
	float vd = length(cc * vec2(1.0, 0.85));
	col *= 1.0 - vignette * smoothstep(vignette_size, vignette_size + 0.75, vd);
	if (flicker > 0.0) {
		float f = (hash12(vec2(floor(TIME * 24.0), 3.0)) - 0.5) * 0.6 + sin(TIME * 73.0) * 0.4;
		col *= 1.0 + flicker * f;
	}
	if (roll_strength > 0.0) {
		float rd = fract(uv.y - TIME * roll_speed + 0.5) - 0.5;
		float band = smoothstep(roll_height, 0.0, abs(rd));
		col *= 1.0 - roll_strength * 0.28 * band;
	}
	if (noise_amount > 0.0) {
		col += (hash12(uv * res + fract(TIME) * 100.0) - 0.5) * noise_amount;
	}

	COLOR = vec4(max(col, vec3(0.0)) * edge, 1.0);
}
