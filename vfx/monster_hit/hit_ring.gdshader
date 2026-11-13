// 충격파 링. 메시 없이 쿼드 UV 로 원을 만들고, 극좌표로 샘플한 침식 맵으로 끊어 먹는다.
// 균일한 알파 페이드 대신 링 일부가 먼저 끊기면서 사라진다 (원문 "Dissolve Shader").
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

uniform sampler2D erosion : repeat_enable, filter_linear;
uniform float life = 0.0;

uniform vec4 col_hot : source_color = vec4(1.0, 0.95, 0.75, 1.0);
uniform vec4 col_body : source_color = vec4(1.0, 0.6, 0.18, 1.0);
uniform vec4 col_rim : source_color = vec4(0.23, 0.1, 0.06, 1.0);   // 밝은 배경용 바깥 테두리
uniform float rim_width = 0.007;
uniform float radius_start = 0.18;      // UV 반지름 (0.5 = 쿼드 가장자리)
uniform float radius_end = 0.46;
uniform float width_start = 0.05;
uniform float width_end = 0.0;
uniform float erode = 0.25;            // 약하게: 점선 찌꺼기 대신 두께가 0 으로 줄며 끊긴다
uniform float squash = 1.0;             // 1 미만이면 진행 방향으로 납작한 타원
uniform float angle_offset = 0.0;

varying float v_t;

void vertex() {
	v_t = clamp(life, 0.0, 1.0);
}

void fragment() {
	float t = v_t;
	vec2 p = UV - 0.5;
	p.x /= squash;
	float r = length(p);
	float ang = atan(p.y, p.x) / 6.2831853 + 0.5 + angle_offset;

	float ease = 1.0 - pow(1.0 - t, 4.0);   // ease-out quart: 처음에 확 퍼지고 끝에서 멈춘다
	float R = mix(radius_start, radius_end, ease);
	// 두께는 반지름보다 빨리 줄인다. 반지름처럼 ease-out 을 쓰면 가는 머리카락 원이 오래 남는다
	float W = mix(width_end, width_start, pow(1.0 - t, 1.6));

	// 각도 배율은 정수여야 0↔1 이음매에서 무늬가 이어진다 (godot-notes)
	float n = texture(erosion, vec2(ang * 3.0, r * 1.5 + t * 0.4)).r;
	float d = abs(r - R) - W;
	float keep = n - pow(t, 1.3) * erode * 1.15;     // 진행할수록 침식 맵의 낮은 곳부터 끊긴다

	float aa = clamp(fwidth(r), 1e-4, 0.01);
	float vis = smoothstep(aa, -aa, d) * smoothstep(0.0, 0.03, keep);
	// 링의 바깥(진행) 가장자리를 뜨겁게: 반지름 바깥쪽 절반
	float hot = smoothstep(-aa, aa, r - R) * step(t, 0.45);
	vec3 rgb = mix(col_body.rgb, col_hot.rgb, hot);
	float keep_mask = smoothstep(0.0, 0.03, keep);
	float rim = smoothstep(aa, -aa, d - rim_width * step(0.001, W)) * keep_mask;
	float a_rim = max(rim - vis, 0.0);
	COLOR = vec4(rgb * vis + col_rim.rgb * a_rim, vis + a_rim);
}
