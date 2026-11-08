// 검기 A: 셀 초승달 (애니 툰). VFX연구 vfx/sword_slash/slash_cel.gdshader 에서 가져왔다.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

#include "res://shaders/sword_slash_common.gdshaderinc"

group_uniforms look;
uniform vec4 col_edge : source_color = vec4(1.0, 1.0, 1.0, 1.0);   // 칼날 (가장 밝음)
uniform vec4 col_body : source_color = vec4(0.45, 0.86, 1.0, 1.0);
uniform vec4 col_rim : source_color = vec4(0.09, 0.22, 0.72, 1.0);  // 안쪽 테 (어두운 받침)
uniform vec4 col_glow : source_color = vec4(0.15, 0.5, 1.0, 1.0);
uniform float edge_band = 0.26;    // v 기준 칼날 밴드 폭
uniform float body_band = 0.7;
uniform float energy = 1.0;        // HDR 배율 (임팩트 프레임에 올린다)
uniform float glow = 0.6;
uniform float glow_width = 0.025;
group_uniforms anim;
uniform float split : hint_range(0.0, 1.0) = 0.0;  // 꼬리부터 결 방향 줄로 갈라짐
uniform float flash : hint_range(0.0, 1.0) = 0.0;  // 1 = 순백 단색
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;

void fragment() {
	float u, s, v, sd, aa;
	ss_slash(UV, u, s, v, sd, aa);
	float m = 1.0 - smoothstep(-aa, aa, sd);

	// 꼬리 쪽은 흰 날이 사라지고 몸통도 좁아져서 머리 → 꼬리로 명도가 떨어진다
	float eb = edge_band * smoothstep(0.05, 0.55, s);
	float bb = body_band * mix(0.55, 1.0, s);
	float fv = max(fwidth(v), 1e-3);
	vec3 c = mix(col_edge.rgb, col_body.rgb, smoothstep(eb - fv, eb + fv, v));
	c = mix(c, col_rim.rgb, smoothstep(bb - fv, bb + fv, v));

	// 갈라짐: v 방향으로 촘촘한 노이즈 → 호를 따라 달리는 줄. 칼날 쪽이 가장 오래 남는다
	float n = ss_noise(vec2(v * 9.0 + seed, u * 2.5 + seed * 3.1));
	n += (1.0 - clamp(v, 0.0, 1.0)) * 0.35;
	float th = split * 1.7 - s * 0.55;
	m *= smoothstep(th - 0.03, th + 0.03, n);

	// 셀 글로우: 부드러운 후광 대신 단단한 2단 밴드 (안쪽 진함 / 바깥 옅음)
	float od = max(sd, 0.0);
	float g = (0.6 * (1.0 - smoothstep(glow_width * 0.45 - aa, glow_width * 0.45 + aa, od))
		+ 0.4 * (1.0 - smoothstep(glow_width - aa, glow_width + aa, od)));
	g *= glow * smoothstep(-0.1, 0.4, s) * step(0.0, sd);
	// 임팩트 배율은 칼날 밴드에만 준다. 몸통·테까지 올리면 HDR 블룸으로 단계가 뭉개진다
	float hot = 1.0 - smoothstep(eb - fv, eb + fv, v);
	// 셀 플래시: 그라데이션 없이 몸 전체를 순백 단색으로 (스윕 프레임)
	c = mix(c, col_edge.rgb, flash);
	vec3 rgb = c * mix(1.0, energy, hot) * m + col_glow.rgb * g * (1.0 - m);
	COLOR = vec4(rgb, max(m, g * 0.5)) * opacity;
}
