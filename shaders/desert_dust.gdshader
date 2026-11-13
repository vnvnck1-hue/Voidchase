// 화면 가장자리의 모래바람. 전장 중앙은 맑게 두고, 길게 늘어진 먼지가 한 방향으로 지나간다.
shader_type canvas_item;
#include "res://shaders/field_look.gdshaderinc"   // 필드 연구실 색 보정 (fl_*)

uniform vec4 fog_color : source_color = vec4(0.61, 0.34, 0.20, 1.0);
uniform vec4 wisp_color : source_color = vec4(0.68, 0.405, 0.24, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.30;
uniform float reach : hint_range(0.0, 1.0) = 0.22;
uniform float wisp_scale : hint_range(0.5, 8.0) = 2.4;
uniform float wisp_speed : hint_range(0.0, 0.3) = 0.07;
uniform float wisp_amount : hint_range(0.0, 1.0) = 0.45;
uniform float wisp_glow : hint_range(0.0, 1.0) = 0.35;
uniform float aspect = 1.7778;
uniform float wisp_phase = -1.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = mod(floor(p), 256.0);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(mod(i + vec2(1.0, 0.0), 256.0)), u.x),
		mix(hash(mod(i + vec2(0.0, 1.0), 256.0)), hash(mod(i + 1.0, 256.0)), u.x), u.y);
}

void fragment() {
	vec2 uv = UV - 0.5;
	vec2 p = uv * vec2(aspect, 1.0) * wisp_scale;
	float t = wisp_phase >= 0.0 ? wisp_phase : TIME * wisp_speed;
	vec2 wind = p - vec2(t * 3.0, t * 0.55);
	float broad = noise(wind * vec2(0.8, 4.5));
	float fine = noise(wind * vec2(1.8, 24.0) + 4.3);
	float dist = length(uv * vec2(1.15, 1.5)) * 2.0;
	float shift = (0.5 - reach) * 0.65;
	float push = (broad - 0.5) * wisp_amount * 0.38;
	float mask = smoothstep(0.55 + shift, 1.25 + shift, dist + push);
	float edges = smoothstep(0.78 + shift * 0.3, 1.10, max(abs(uv.x), abs(uv.y)) * 2.0 + push);
	mask = max(mask, edges);
	float density = mix(0.8, 0.35 + broad * 0.85 + fine * 0.20, wisp_amount);
	float alpha = clamp(mask * density * strength, 0.0, 0.65);
	vec3 col = mix(fog_color.rgb, wisp_color.rgb, fine * wisp_glow);
	COLOR = fl_apply(vec4(col, alpha));
}
