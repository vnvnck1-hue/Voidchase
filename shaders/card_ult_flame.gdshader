shader_type canvas_item;
render_mode blend_add;
// 궁극기 준비 카드: 분대 카드 윤곽을 따라 황금빛 불꽃이 위로 타오른다 (에디티브, HUD CanvasGroup 밖 레이어에 그린다).
// 마녀산장 card_burn_glow.gdshader 에서 가져온 것: 카드 윤곽 기준 거리로 번지는 빛 + 정수 해시 노이즈(card_burn_noise.gdshaderinc 의
// hash·vnoise·fbm)로 일렁이는 불선. 여기서는 연소선 대신, 위로 흐르는 fbm 이 윤곽에서 멀수록 높아지는 문턱에 깎여 불 혀가 된다.
// 윤곽까지 거리는 미리 구운 부호 거리장(TEXTURE = tools/battle_ui/build_card_sdf.py 가 만든 card_sdf/*.png)에서 읽는다
// — 알파를 여러 반지름으로 넓혀 근사하던 card_burn_glow 방식은 불 혀 끝이 계단처럼 깨져서.
//   (1) 불 혀   — 윗변은 길게, 옆은 짧게, 아랫변은 거의 없이 (윤곽 법선이 위를 볼수록 멀리 닿는다)
//   (2) 후광   — 윤곽 둘레 전체의 옅은 금빛
//   (3) 테두리 — 카드 안쪽 가장자리를 따라 흐르는 밝은 금빛 띠
//   (4) 불티   — 윗변 위로 날아오르는 작은 불씨
// 그림 사각형 = SDF 텍스처 전체 (카드보다 build_card_sdf.PAD 만큼 넓다). 거리 단위는 패널 텍스처 px.

uniform vec2 tex_size = vec2(428.0, 437.0);   // SDF 텍스처 크기(px)
uniform float sdf_range = 104.0;              // build_card_sdf.RANGE
uniform float intensity : hint_range(0.0, 2.0, 0.01) = 1.0;   // 0 이면 꺼짐, 막 찼을 땐 잠깐 1 이상

group_uniforms Color;
uniform vec4 hot_color : source_color = vec4(1.0, 0.98, 0.84, 1.0);
uniform vec4 gold_color : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.58, 0.1, 1.0);

group_uniforms Flame;
/** 윗변 불 혀 길이(px) */
uniform float top_reach : hint_range(0.0, 104.0, 0.5) = 100.0;
/** 옆변 불 혀 길이(px) */
uniform float side_reach : hint_range(0.0, 104.0, 0.5) = 34.0;
/** 아랫변 불 혀 길이(px) */
uniform float bottom_reach : hint_range(0.0, 104.0, 0.5) = 10.0;
/** 불 혀 무늬 크기(px, 클수록 굵은 혀) */
uniform float tongue_px : hint_range(4.0, 80.0, 0.5) = 22.0;
/** 위로 흐르는 속도(무늬 크기/초) */
uniform float rise_speed : hint_range(0.0, 6.0, 0.01) = 2.2;
/** 혀가 끊기는 정도 (클수록 가늘고 들쭉날쭉) */
uniform float tongue_cut : hint_range(0.0, 1.5, 0.01) = 0.45;
uniform float flame_strength : hint_range(0.0, 3.0, 0.01) = 1.8;
uniform float halo_strength : hint_range(0.0, 2.0, 0.01) = 0.55;
/** 후광 번짐 거리(px) */
uniform float halo_px : hint_range(1.0, 60.0, 0.5) = 13.0;
uniform float rim_strength : hint_range(0.0, 3.0, 0.01) = 1.25;
/** 테두리 띠 두께(px) */
uniform float rim_px : hint_range(0.0, 20.0, 0.1) = 5.0;
uniform float ember_amount : hint_range(0.0, 1.0, 0.01) = 0.6;

// ---- card_burn_noise.gdshaderinc (마녀산장) 에서 가져온 노이즈 ----
// 정수 해시: 실수 해시는 GPU 반올림 오차로 격자 경계에서 값이 어긋나 세로 단차가 생긴다
float hash(vec2 p) {
	uvec2 q = uvec2(ivec2(p)) * uvec2(1597334673u, 3812015801u);
	uint n = (q.x ^ q.y) * 1597334673u;
	return float(n) * (1.0 / 4294967295.0);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p, float gain) {
	float v = 0.0;
	float amp = 1.0;
	float total = 0.0;
	for (int i = 0; i < 4; i++) {
		v += amp * vnoise(p);
		total += amp;
		p = p * 2.03 + vec2(17.1, 9.7);
		amp *= gain;
	}
	return v / total;
}
// ----

float sdist(sampler2D tex, vec2 uv) {
	return (texture(tex, uv).r - 0.5) * 2.0 * sdf_range;   // 윤곽 밖 +, 안 - (px)
}

void fragment() {
	vec2 px = UV * tex_size;
	float sd = sdist(TEXTURE, UV);
	// 윤곽 법선(밖 방향): 거리장 기울기
	vec2 e = 2.0 / tex_size;
	vec2 g = vec2(sdist(TEXTURE, UV + vec2(e.x, 0.0)) - sdist(TEXTURE, UV - vec2(e.x, 0.0)),
		sdist(TEXTURE, UV + vec2(0.0, e.y)) - sdist(TEXTURE, UV - vec2(0.0, e.y)));
	vec2 nrm = length(g) > 1e-4 ? normalize(g) : vec2(0.0, -1.0);
	float up = clamp(-nrm.y, 0.0, 1.0);
	float down = clamp(nrm.y, 0.0, 1.0);
	float reach = mix(side_reach, top_reach, up * up);
	reach = mix(reach, bottom_reach, down);
	float t = TIME;
	float out_side = step(0.0, sd);

	// (1) 불 혀: 위로 흐르며 살짝 좌우로 흔들리는 fbm. 윤곽에서 멀수록 문턱이 올라가 혀끝만 남는다
	vec2 q = px / tongue_px;
	q.x += 0.35 * sin(q.y * 0.7 + t * 1.3);
	float n = fbm(vec2(q.x, q.y + t * rise_speed), 0.55);
	float n2 = vnoise(vec2(q.x * 2.2 + 5.3, q.y * 1.6 + t * rise_speed * 1.8));
	float d01 = clamp(sd / max(reach, 1.0), 0.0, 1.0);
	float fuel = n * 0.85 + n2 * 0.3 + 0.02;
	float th = d01 * (0.55 + tongue_cut * 0.6);
	float body = smoothstep(th, th + 0.12, fuel) * (1.0 - smoothstep(0.85, 1.0, d01));
	float flame = body * pow(1.0 - d01, 0.7) * out_side;
	vec3 col = mix(edge_color.rgb, gold_color.rgb, smoothstep(0.25, 0.75, 1.0 - d01));
	col = mix(col, hot_color.rgb, smoothstep(0.75, 1.0, 1.0 - d01) * body);

	// (2) 후광: 윤곽 둘레 전체
	float halo = exp(-max(sd, 0.0) / halo_px) * out_side * (0.8 + 0.2 * n2);

	// (3) 테두리: 카드 안쪽 rim_px 띠, 노이즈로 일렁인다
	float rim = (1.0 - out_side) * smoothstep(-rim_px, 0.0, sd) * (0.55 + 0.6 * n2);

	// (4) 불티: 윗변 위 격자마다 하나, 일부만 켜져 위로 날아오른다
	float ember = 0.0;
	if (ember_amount > 0.0) {
		vec2 gq = vec2(px.x / 26.0, px.y / 26.0 + t * 1.6);
		vec2 cell = floor(gq);
		float h = hash(cell + vec2(31.0, 7.0));
		vec2 p = vec2(hash(cell + vec2(3.0, 1.0)), hash(cell + vec2(9.0, 5.0))) * 0.7 + 0.15;
		float dd = length(fract(gq) - p);
		float zone = out_side * up * smoothstep(top_reach * 1.25, top_reach * 0.3, sd);
		ember = step(1.0 - ember_amount * 0.4, h) * smoothstep(0.13, 0.0, dd) * zone * (0.55 + 0.45 * sin(t * 8.0 + h * 40.0));
	}

	vec3 rgb = col * flame * flame_strength + gold_color.rgb * halo * halo_strength
		+ mix(gold_color.rgb, hot_color.rgb, 0.6) * rim * rim_strength + hot_color.rgb * ember * 1.5;
	COLOR = vec4(rgb * intensity * COLOR.rgb, 1.0);
}
