// 사막: 내려다보는 모래 지면. 등각 방향의 낮은 사구와 한 방향으로 흐르는 잔모래.
// 공허의 구름/발광 알갱이를 재착색하지 않고, 무광 지면과 바람 결을 별도로 만든다.
shader_type canvas_item;
#include "res://shaders/field_look.gdshaderinc"   // 필드 연구실 색 보정 (fl_*)

uniform vec4 col_deep : source_color = vec4(0.30, 0.13, 0.09, 1.0);
uniform vec4 col_night : source_color = vec4(0.49, 0.25, 0.145, 1.0);
uniform vec4 col_lilac : source_color = vec4(0.61, 0.34, 0.20, 1.0);
uniform vec4 col_gas : source_color = vec4(0.68, 0.405, 0.24, 1.0);
uniform vec4 col_glow : source_color = vec4(0.78, 0.525, 0.33, 1.0);
uniform float flow_speed : hint_range(0.0, 0.2) = 0.04;
uniform float scale : hint_range(0.5, 6.0) = 1.7;
uniform float glow_amount : hint_range(0.0, 1.0) = 0.20;
uniform float aspect = 1.7778;
uniform vec2 parallax = vec2(0.0);
uniform float phase = -1.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	i = mod(i, 256.0);
	return mix(mix(hash(i), hash(mod(i + vec2(1.0, 0.0), 256.0)), u.x),
		mix(hash(mod(i + vec2(0.0, 1.0), 256.0)), hash(mod(i + 1.0, 256.0)), u.x), u.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0) * scale + parallax;
	float t = phase >= 0.0 ? phase : TIME * flow_speed;
	// y=0.5*x 방향의 넓은 모래 물결. 수평선 없이 화면 전체를 내려다보는 지면으로 쓴다.
	float across = p.y * 2.0 - p.x;
	float bend = noise(p * 0.75 + vec2(2.4, 7.1));
	float ridge = sin(across * 5.0 + sin(p.x * 1.8) * 0.7 + bend * 2.4) * 0.5 + 0.5;
	float crest = smoothstep(0.40, 0.62, ridge);
	float lee = smoothstep(0.70, 0.92, ridge);
	vec3 col = mix(col_night.rgb, col_gas.rgb, crest * 0.78);
	col = mix(col, col_deep.rgb, lee * 0.27);
	col = mix(col, col_lilac.rgb, noise(p * 1.1 + 9.0) * 0.20);
	// 바람을 따라 가늘고 길게 흐르는 모래 먼지. 모래 언덕 자체는 움직이지 않는다.
	vec2 wind = p - vec2(t * 2.4, t * 0.45);
	float streak = noise(wind * vec2(1.4, 32.0));
	float veil = smoothstep(0.60, 0.87, streak) * noise(wind * vec2(1.1, 3.2) + 4.0);
	col = mix(col, col_glow.rgb, veil * (0.10 + glow_amount * 0.14));
	// 작고 드문 모래 알갱이. 별처럼 발광하거나 깜빡이지 않는다.
	vec2 g = wind * vec2(75.0, 150.0);
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float grain = step(0.982, hash(mod(id, 256.0))) * (1.0 - smoothstep(0.04, 0.23, length(f * vec2(0.65, 1.8))));
	col = mix(col, col_glow.rgb, grain * 0.20);
	float texture_grain = hash(floor((p + 20.0) * 360.0)) - 0.5;
	col += vec3(texture_grain * 0.012);
	COLOR = fl_apply(vec4(col, 1.0));
}
