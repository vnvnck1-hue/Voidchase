// 유물 투사체 리본 (VFX연구 slash_flow 방식의 2D 투사체판).
// 곡선 띠 메시(UV.x = 궤적 0 출발 → 1 도착, UV.y = 폭 0..1) 위로 혜성 모양을 head/len 오프셋으로 흘린다.
// 쉐입은 수식 프로파일(둥근 머리 + 가늘어지는 꼬리)이고, 결 노이즈가 진행 방향으로 흘러 속도선을 만들며,
// 소멸은 꼬리 → 머리 순서의 알파 침식. 색은 4톤 하드 램프(테두리 → 몸통 → 코어 → 핫) — 카툰풍, 글로우로 번지지 않는다.
// blend_premul_alpha: rgb 는 더해지는 빛, alpha 는 배경을 덮는 양. 몸통은 불투명 셀, 핫 코어만 HDR 을 조금 더한다.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

#include "res://shaders/vfx_lib.gdshaderinc"

group_uniforms look;
uniform vec4 col_edge : source_color = vec4(0.05, 0.1, 0.4, 1.0);    // 바깥 테두리: 어두운 받침 (밝은 배경에서도 읽힌다)
uniform vec4 col_body : source_color = vec4(0.15, 0.4, 0.95, 1.0);
uniform vec4 col_core : source_color = vec4(0.45, 0.9, 1.0, 1.0);
uniform vec4 col_hot : source_color = vec4(0.92, 1.0, 1.0, 1.0);
uniform float hot_hdr = 1.15;          // 핫 코어 HDR 배율 (얇은 면적에만)
uniform float edge_w = 0.16;           // 테두리 두께 (반폭 비율)
uniform float core_w = 0.42;           // 코어 시작 (반폭 비율, 중심이 1)
uniform float hot_w = 0.72;            // 핫 코어 시작
uniform float head_round = 0.2;        // 머리 둥근 캡 길이 (꼬리 길이 비율)
uniform float tail_pow = 0.6;          // 꼬리 가늘어짐 (작을수록 두껍게 오래 남는다)
uniform float streak_amt = 0.3;        // 결이 톤 경계를 흔드는 양 (속도선)
uniform float distort = 0.14;          // 가장자리 노이즈 (꼬리일수록 크다)
uniform float seed = 3.0;

group_uniforms anim;
uniform float head = 1.0;              // 머리가 놓인 메시 x
uniform float len = 0.5;               // 꼬리 길이 (메시 x 단위)
uniform float flow_t = 0.0;            // 노이즈 패닝 시간 (스크립트가 넣는다)
uniform float streak_speed = 3.0;      // 결이 진행 방향으로 흐르는 속도
uniform float erode = 0.0;             // 0 → 1 침식 (꼬리부터)
uniform float erode_soft = 0.1;
uniform float tail_bias = 1.2;
uniform float heat = 1.0;              // 1 → 0.6 : 핫·코어가 줄어 식는다
uniform float width_scale = 1.0;
uniform float opacity = 1.0;
uniform float end_fade = 0.02;         // 메시 양 끝 페이드

float fbm2(vec2 p, float z, int sd) {
	ivec3 per = ivec3(65536);
	float a = vfx_perlin3(vec3(p, z), per, sd) * 0.5 + 0.5;
	float b = vfx_perlin3(vec3(p * 2.1, z * 1.7), per, sd + 131) * 0.5 + 0.5;
	return (a * 0.65 + b * 0.35);
}

void fragment() {
	float t = flow_t;
	float tx = (UV.x - head) / max(len, 1e-4) + 1.0;   // 1 머리, 0 꼬리 끝
	float txc = clamp(tx, 0.0, 1.0);
	float ac = abs(UV.y * 2.0 - 1.0);                  // 0 중심 → 1 가장자리

	// 혜성 프로파일: 머리 캡은 반원, 그 뒤는 멱함수로 가늘어진다
	float hr = max(head_round, 1e-3);
	float cap = clamp((tx - (1.0 - hr)) / hr, 0.0, 1.0);
	float w_cap = sqrt(max(1.0 - cap * cap, 0.0));
	float w_tail = pow(clamp(txc / (1.0 - hr), 0.0, 1.0), tail_pow);
	float w = (tx > 1.0 - hr ? w_cap : w_tail) * width_scale;
	// 가장자리 흔들기 (꼬리일수록 크게, 머리 캡은 매끈하게)
	float n1 = fbm2(vec2(UV.x * 5.0 - t * 1.1, UV.y * 2.0 + seed), t * 0.6, int(seed) + 11) - 0.5;
	w += n1 * distort * (1.0 - txc * 0.7) * (1.0 - cap);
	// 중심 기준 정규화 필드: 1 중심, 0 가장자리, 음수 바깥
	float fn = 1.0 - ac / max(w, 1e-4);
	float inside = step(0.0, tx) * step(tx, 1.0);

	// 결: 진행 방향으로 빠르게 흐르는 길쭉한 노이즈 → 톤 경계를 흔들어 속도선이 된다
	float st = fbm2(vec2(UV.x * 9.0 - t * streak_speed, UV.y * 1.2 + seed * 0.3), t * 0.25, int(seed) + 23) - 0.5;
	float fn2 = fn + st * streak_amt;

	// 침식: 꼬리부터 임계값이 올라간다 (slash_flow 의 tail_bias 방식)
	float th = erode * (1.0 + erode_soft + tail_bias) - tail_bias * txc;
	float aa = max(fwidth(fn), 1e-3);
	float mask = smoothstep(-aa, aa, fn) * inside;
	float keep = smoothstep(th, th + erode_soft, fn2 + 0.5);
	float a = mask * keep;
	a *= smoothstep(0.0, end_fade, UV.x) * (1.0 - smoothstep(1.0 - end_fade, 1.0, UV.x));

	// 4톤 하드 램프. heat 가 내려가면 코어·핫 임계값이 올라가 식는다 (몸통은 유지)
	float cool = (1.0 - heat) * 0.5;
	float e1 = edge_w;
	float e2 = core_w + cool;
	float e3 = hot_w + cool * 1.4;
	float aa2 = aa * 1.5;
	vec3 c = col_edge.rgb;
	c = mix(c, col_body.rgb, smoothstep(e1 - aa2, e1 + aa2, fn2));
	// 코어는 머리 쪽 65% 에만, 핫은 머리 쪽 45% 에만 (꼬리는 몸통 색으로 식는다)
	float core_zone = smoothstep(0.3, 0.5, txc);
	float hot_zone = smoothstep(0.5, 0.65, txc);
	c = mix(c, col_core.rgb, smoothstep(e2 - aa2, e2 + aa2, fn2) * core_zone);
	c = mix(c, col_hot.rgb * hot_hdr, smoothstep(e3 - aa2, e3 + aa2, fn2) * hot_zone);
	// 침식 경계: 갉아먹히는 가장자리가 코어 색으로 빛난다
	float rim = smoothstep(th, th + erode_soft * 0.4, fn2 + 0.5) * (1.0 - smoothstep(th + erode_soft * 0.4, th + erode_soft, fn2 + 0.5));
	c = mix(c, col_core.rgb * 1.3, rim * step(0.02, erode));

	COLOR = vec4(c * a, a) * opacity;
}
