shader_type canvas_item;
render_mode blend_add;
// 궁극기 준비 카드: 분대 카드 윤곽을 따라 '오버차지' 에너지가 뿜어 나온다 (에디티브, HUD CanvasGroup 밖 레이어에 그린다).
// 2026-11-09 사이파이 리스타일: 예전 황금 불꽃(불 혀 + 불티)을 디지털 에너지 줄기 + 홀로그램 스윕 + 사각 픽셀로 바꿨다.
// uniform 이름은 조절값(vd_card_flame_fx.gd 의 키)과 저장 파일을 그대로 쓰려고 예전 이름을 유지한다
// (top_reach = 윗변 줄기 길이, tongue_px = 줄기 간격, ember_amount = 픽셀 양 …).
// 윤곽까지 거리는 미리 구운 부호 거리장(TEXTURE = tools/battle_ui/build_card_sdf.py 가 만든 card_sdf/*.png)에서 읽는다.
//   (1) 에너지 줄기 — 윤곽에서 바깥으로 뻗는 가는 기둥들. 기둥마다 길이가 계단식으로 바뀌고(이퀄라이저처럼),
//                    안에서 밝은 대시가 바깥으로 흐른다. 윗변은 길게, 옆은 짧게, 아랫변은 거의 없이.
//   (2) 후광       — 윤곽 둘레 전체의 옅은 빛
//   (3) 테두리     — 카드 안쪽 가장자리 띠. 가는 주사선 + 대각으로 훑고 지나가는 홀로그램 스윕
//   (4) 픽셀       — 윗변 위로 떠오르며 깜빡이는 작은 사각 픽셀
// 그림 사각형 = SDF 텍스처 전체 (카드보다 build_card_sdf.PAD 만큼 넓다). 거리 단위는 패널 텍스처 px.

uniform vec2 tex_size = vec2(428.0, 437.0);   // SDF 텍스처 크기(px)
uniform float sdf_range = 104.0;              // build_card_sdf.RANGE
uniform float intensity : hint_range(0.0, 2.0, 0.01) = 1.0;   // 0 이면 꺼짐, 막 찼을 땐 잠깐 1 이상

group_uniforms Color;
/** 가장 밝은 곳 (윤곽 가까이·대시 심지) */
uniform vec4 hot_color : source_color = vec4(0.9, 1.0, 1.0, 1.0);
/** 본색 (줄기 몸통·후광·테두리) */
uniform vec4 gold_color : source_color = vec4(0.3, 0.85, 1.0, 1.0);
/** 끝 색 (줄기 끝·바깥) */
uniform vec4 edge_color : source_color = vec4(0.72, 0.35, 1.0, 1.0);

group_uniforms Flame;
/** 윗변 줄기 길이(px) */
uniform float top_reach : hint_range(0.0, 104.0, 0.5) = 100.0;
/** 옆변 줄기 길이(px) */
uniform float side_reach : hint_range(0.0, 104.0, 0.5) = 34.0;
/** 아랫변 줄기 길이(px) */
uniform float bottom_reach : hint_range(0.0, 104.0, 0.5) = 10.0;
/** 줄기 간격(px, 클수록 굵고 성긴 줄기) */
uniform float tongue_px : hint_range(4.0, 80.0, 0.5) = 22.0;
/** 바깥으로 흐르는 속도 + 길이가 바뀌는 박자 */
uniform float rise_speed : hint_range(0.0, 6.0, 0.01) = 2.2;
/** 줄기 성김 (클수록 짧은 줄기가 많고 대시가 짧다) */
uniform float tongue_cut : hint_range(0.0, 1.5, 0.01) = 0.45;
uniform float flame_strength : hint_range(0.0, 3.0, 0.01) = 1.8;
uniform float halo_strength : hint_range(0.0, 2.0, 0.01) = 0.55;
/** 후광 번짐 거리(px) */
uniform float halo_px : hint_range(1.0, 60.0, 0.5) = 13.0;
uniform float rim_strength : hint_range(0.0, 3.0, 0.01) = 1.25;
/** 테두리 띠 두께(px) */
uniform float rim_px : hint_range(0.0, 20.0, 0.1) = 5.0;
/** 떠오르는 사각 픽셀 양 */
uniform float ember_amount : hint_range(0.0, 1.0, 0.01) = 0.6;

// 정수 해시: 실수 해시는 GPU 반올림 오차로 격자 경계에서 값이 어긋나 세로 단차가 생긴다 (마녀산장 card_burn_noise)
float hash(vec2 p) {
	uvec2 q = uvec2(ivec2(p)) * uvec2(1597334673u, 3812015801u);
	uint n = (q.x ^ q.y) * 1597334673u;
	return float(n) * (1.0 / 4294967295.0);
}

// 윤곽 밖 +, 안 - (px). TEXTURE 를 사용자 함수 인자로 넘기면 셰이더 컴파일러가 custom_samplers 오류를 내므로 매크로로 읽는다
#define SDIST(uv) ((texture(TEXTURE, uv).r - 0.5) * 2.0 * sdf_range)

void fragment() {
	vec2 px = UV * tex_size;
	float sd = SDIST(UV);
	// 윤곽 법선(밖 방향): 거리장 기울기
	vec2 e = 2.0 / tex_size;
	vec2 g = vec2(SDIST(UV + vec2(e.x, 0.0)) - SDIST(UV - vec2(e.x, 0.0)),
		SDIST(UV + vec2(0.0, e.y)) - SDIST(UV - vec2(0.0, e.y)));
	vec2 nrm = length(g) > 1e-4 ? normalize(g) : vec2(0.0, -1.0);
	float up = clamp(-nrm.y, 0.0, 1.0);
	float down = clamp(nrm.y, 0.0, 1.0);
	float reach = mix(side_reach, top_reach, up * up);
	reach = mix(reach, bottom_reach, down);
	float t = TIME;
	float out_side = step(0.0, sd);
	float d01 = clamp(sd / max(reach, 1.0), 0.0, 1.0);

	// (1) 에너지 줄기: 윤곽을 따라 늘어선 기둥(가로 좌표 = 법선에 수직인 축). 윗변·아랫변은 x, 옆변은 y 로 나눈다
	float along = abs(nrm.y) > abs(nrm.x) ? px.x : px.y;
	float pitch = max(tongue_px * 0.5, 3.0);
	float col_id = floor(along / pitch);
	float in_col = fract(along / pitch);
	float bar = smoothstep(0.0, 0.12, in_col) * smoothstep(0.62, 0.48, in_col);   // 기둥 폭 ≈ 간격의 절반
	float beat = floor(t * (1.5 + rise_speed * 1.2));                              // 길이가 바뀌는 박자 (계단식)
	float h = mix(hash(vec2(col_id, beat)), hash(vec2(col_id, beat + 1.0)), 0.25);
	float len01 = clamp(0.18 + h * (1.05 - tongue_cut * 0.45), 0.0, 1.0);          // 이 기둥이 닿는 비율
	float body = bar * (1.0 - smoothstep(len01 - 0.08, len01, d01));
	// 안에서 바깥으로 흐르는 밝은 대시
	float dash_len = max(reach * 0.32, 6.0);
	float dash = step(0.45 + tongue_cut * 0.3, fract(sd / dash_len - t * rise_speed * 0.6 + hash(vec2(col_id, 7.0))));
	// 가는 가로 주사선 (3px 마다 한 줄이 어둡다)
	float scan = 0.72 + 0.28 * step(1.0, mod(floor(px.y), 3.0));
	float flame = body * (0.45 + 0.55 * dash) * scan * pow(1.0 - d01, 0.5) * out_side;
	vec3 col = mix(edge_color.rgb, gold_color.rgb, smoothstep(0.15, 0.7, 1.0 - d01));
	col = mix(col, hot_color.rgb, dash * smoothstep(0.55, 1.0, 1.0 - d01));

	// (2) 후광: 윤곽 둘레 전체 (주사선만큼 살짝 줄무늬)
	float halo = exp(-max(sd, 0.0) / halo_px) * out_side * (0.85 + 0.15 * scan);

	// (3) 테두리: 카드 안쪽 rim_px 띠 + 대각 홀로그램 스윕
	float rim_band = (1.0 - out_side) * smoothstep(-rim_px, 0.0, sd);
	float sweep_u = fract((px.x + px.y) / (tex_size.x + tex_size.y) * 1.4 - t * 0.55);
	float sweep = smoothstep(0.0, 0.06, sweep_u) * smoothstep(0.16, 0.06, sweep_u);
	float rim = rim_band * (0.5 + 0.25 * scan + 1.1 * sweep);
	// 스윕은 카드 안쪽으로도 옅게 번진다 (유리 반사)
	float glass = (1.0 - out_side) * smoothstep(-rim_px * 6.0, -rim_px, sd) * (1.0 - smoothstep(-rim_px, 0.0, sd)) * sweep * 0.35;

	// (4) 사각 픽셀: 윗변 위 격자마다 하나, 일부만 켜져 위로 떠오르며 계단식으로 깜빡인다
	float ember = 0.0;
	if (ember_amount > 0.0) {
		vec2 gq = vec2(px.x / 24.0, px.y / 24.0 + t * 1.4);
		vec2 cell = floor(gq);
		float hh = hash(cell + vec2(31.0, 7.0));
		vec2 p = vec2(hash(cell + vec2(3.0, 1.0)), hash(cell + vec2(9.0, 5.0))) * 0.6 + 0.2;
		vec2 dd = abs(fract(gq) - p);
		float sq = step(max(dd.x, dd.y), 0.075);
		float zone = out_side * up * smoothstep(top_reach * 1.25, top_reach * 0.3, sd);
		float blink = step(0.35, fract(t * 3.0 + hh * 7.0));
		ember = step(1.0 - ember_amount * 0.4, hh) * sq * zone * blink;
	}

	vec3 rgb = col * flame * flame_strength + gold_color.rgb * halo * halo_strength
		+ mix(gold_color.rgb, hot_color.rgb, 0.5 + 0.5 * sweep) * rim * rim_strength
		+ hot_color.rgb * glass * rim_strength + hot_color.rgb * ember * 1.4;
	COLOR = vec4(rgb * intensity * COLOR.rgb, 1.0);
}
