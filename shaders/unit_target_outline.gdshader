// 궁극기 조준 대상 강조 (VDUnit.set_target_highlight): 유닛 비주얼을 감싼 CanvasGroup 에 건다.
// CanvasGroup 은 자식 파츠를 한 장으로 합쳐 백버퍼에 그리고, 이 셰이더가 그 합친 그림(screen_texture)을 읽는다.
// 그래서 외곽선은 파츠 하나하나가 아니라 합쳐진 실루엣 바깥에만 생긴다 (파츠가 겹치는 자리엔 선이 안 생긴다).
// 형광 네온 튜브 느낌: 실루엣에 붙은 안쪽 띠는 거의 흰빛(코어), 그 바깥 outline_px 까지는 outline_color 완전 불투명,
// 다시 glow_px 까지는 같은 색이 바깥으로 사그라드는 글로우.
//   outline_px   네온 선 두께 (화면 px)      glow_px   선 바깥 글로우 폭 (화면 px)
//   outline_color 네온 색                    tint_color/tint_k  몸을 물들이는 색·세기
//   pulse 0~1    숨쉬기 (스크립트가 매 프레임 넣는다): 선이 두꺼워지고 글로우·몸이 밝아진다
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 outline_color : source_color = vec4(1.0, 0.12, 0.38, 1.0);
uniform float outline_px : hint_range(0.0, 12.0) = 4.0;
uniform float glow_px : hint_range(0.0, 24.0) = 8.0;
uniform vec4 tint_color : source_color = vec4(1.0, 0.12, 0.38, 1.0);
uniform float tint_k : hint_range(0.0, 1.0) = 0.28;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

// 반지름 r(화면 px) 둘레 n 방향의 알파 최댓값
float ring_alpha(vec2 uv, vec2 psz, float r, int n, float ofs) {
	float a = 0.0;
	for (int i = 0; i < 24; i++) {
		if (i >= n) {
			break;
		}
		float ang = (float(i) + ofs) * 6.2831853 / float(n);
		a = max(a, textureLod(screen_texture, uv + vec2(cos(ang), sin(ang)) * psz * r, 0.0).a);
	}
	return a;
}

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;   // 백버퍼는 프리멀티플라이드
	}
	float line_r = outline_px + 1.5 * pulse;
	float glow_r = line_r + glow_px;
	// 선: 실루엣 밖 line_r 안 (두 반지름으로 채워 두껍게), 코어: 실루엣에 붙은 안쪽 40%
	float a_line = max(ring_alpha(SCREEN_UV, SCREEN_PIXEL_SIZE, line_r, 16, 0.0), ring_alpha(SCREEN_UV, SCREEN_PIXEL_SIZE, line_r * 0.5, 8, 0.5));
	float a_core = ring_alpha(SCREEN_UV, SCREEN_PIXEL_SIZE, line_r * 0.4, 8, 0.25);
	// 글로우: 선 바깥 glow_r 까지 두 고리로 거칠게, 바깥일수록 옅게
	float a_g1 = ring_alpha(SCREEN_UV, SCREEN_PIXEL_SIZE, line_r + glow_px * 0.45, 12, 0.3);
	float a_g2 = ring_alpha(SCREEN_UV, SCREEN_PIXEL_SIZE, glow_r, 12, 0.7);
	float outside = 1.0 - c.a;
	float line = clamp(a_line - c.a, 0.0, 1.0);
	float core = clamp(a_core - c.a, 0.0, 1.0);
	float glow = max(clamp(a_g1 - a_line, 0.0, 1.0) * (0.55 + 0.25 * pulse), clamp(a_g2 - a_g1, 0.0, 1.0) * (0.25 + 0.15 * pulse));
	// 선 색: 네온은 코어가 거의 희다
	vec3 line_rgb = mix(outline_color.rgb, vec3(1.0, 0.97, 1.0), core * 0.75);
	// 몸: 살짝 물들이고 숨쉬기에 맞춰 밝아진다
	vec3 body = mix(c.rgb, tint_color.rgb, tint_k * (0.75 + 0.25 * pulse));
	body *= 1.0 + 0.18 * pulse;
	// 합성: 몸 위에 선, 그 바깥에 글로우
	float edge_a = line * outline_color.a;
	float glow_a = glow * outline_color.a * (1.0 - line);
	float out_a = c.a + (edge_a + glow_a) * outside;
	vec3 rgb = (body * c.a + line_rgb * edge_a * outside + outline_color.rgb * glow_a * outside) / max(out_a, 1e-4);
	COLOR = vec4(rgb, out_a) * COLOR;
}
