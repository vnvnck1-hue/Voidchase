// 필드 연구실 (2026-11-11, scripts/void_defense/vd_field_look.gd): 전투 배경 요소의 색 보정.
// 색조·채도·명도·대비·덧색·불투명도를 요소(타일 / 배경 / 프랍 / 앞 안개)마다 따로 넣는다. 기본값은 "그대로".
uniform float fl_hue = 0.0;        // 색조 이동 (바퀴 수: 0.5 = 180도)
uniform float fl_sat = 1.0;        // 채도 배율
uniform float fl_val = 1.0;        // 명도 배율
uniform float fl_contrast = 1.0;   // 대비 (0.5 회색 기준)
uniform float fl_alpha = 1.0;      // 불투명도 배율
uniform vec4 fl_tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);   // 덧색 (a = 섞는 정도)

vec3 fl_rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 fl_hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

vec4 fl_apply(vec4 c) {
	vec3 h = fl_rgb2hsv(c.rgb);
	h.x = fract(h.x + fl_hue);
	h.y = clamp(h.y * fl_sat, 0.0, 1.0);
	h.z = h.z * fl_val;
	vec3 rgb = fl_hsv2rgb(h);
	rgb = (rgb - 0.5) * fl_contrast + 0.5;
	rgb = mix(rgb, fl_tint.rgb, fl_tint.a);
	return vec4(clamp(rgb, 0.0, 1.0), c.a * fl_alpha);
}
