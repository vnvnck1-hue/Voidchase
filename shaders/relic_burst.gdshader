// 유물 착탄 버스트 (카툰). 쿼드 하나에: 노이즈로 깨진 블롭 3톤(테두리 → 몸통 → 코어) + 방사 광선(vfx_rays) + 얇은 충격 링.
// 첫 두 프레임은 순백 단색 섬광, 그 뒤 색이 들어오고, 후반에는 침식으로 갉아먹히며 사라진다 (알파 페이드 없음).
// t 는 0 → 1 (스크립트가 넣는다). UV 0..1, 중심 0.5.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

#include "res://shaders/vfx_lib.gdshaderinc"

uniform vec4 col_rim : source_color = vec4(0.45, 0.1, 0.6, 1.0);
uniform vec4 col_body : source_color = vec4(0.95, 0.3, 0.75, 1.0);
uniform vec4 col_core : source_color = vec4(1.0, 0.95, 0.75, 1.0);
uniform vec4 col_ray : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform vec4 col_ring : source_color = vec4(0.5, 0.95, 1.0, 1.0);
uniform float t = 0.0;
uniform float seed = 1.0;
uniform float blob = 0.42;             // 블롭 최대 반지름 (쿼드 반폭 = 1). 광선이 바깥으로 삐져나오게 작게
uniform float rays_count = 9.0;
uniform float ray_len = 0.5;           // 광선 끝 (UV 단위, 0.5 = 쿼드 가장자리)
uniform float ray_width = 0.05;
uniform float ring_on = 1.0;
uniform float jag = 0.32;              // 블롭 가장자리를 깨는 노이즈 양
uniform float flash_frames = 0.06;     // 순백 섬광 구간 (t)

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	// 크기: 앞쪽에 몰아서 커지고(ease-out³) 그 뒤 살짝 더 커지며 갉아먹힌다
	float grow = 1.0 - pow(1.0 - clamp(t / 0.3, 0.0, 1.0), 3.0);
	float R = mix(blob * 0.75, blob, grow) * (1.0 + 0.12 * smoothstep(0.3, 1.0, t));   // 첫 프레임부터 크게 (fast in)
	// 각도 노이즈로 가장자리를 깨서 동그라미가 아니라 터진 잉크 방울로
	float ang = atan(p.y, p.x);
	float n = vfx_perlin3(vec3(cos(ang) * 1.6, sin(ang) * 1.6, seed + t * 0.8), ivec3(65536), int(seed) * 7) ;
	float n2 = vfx_perlin3(vec3(p * 3.0, seed * 1.3 + t * 1.5), ivec3(65536), int(seed) * 13 + 5);
	float field = 1.0 - r / max(R, 1e-3) + n * jag + n2 * 0.2;
	// 후반 침식: 임계값이 올라가 바깥부터 깨져 나간다
	field -= smoothstep(0.4, 1.0, t) * 1.4;
	float aa = max(fwidth(field), 1e-3);
	float m = smoothstep(-aa, aa, field);
	vec3 c = col_rim.rgb;
	c = mix(c, col_body.rgb, smoothstep(0.22 - aa, 0.22 + aa, field));
	c = mix(c, col_core.rgb, smoothstep(0.52 - aa, 0.52 + aa, field));

	// 방사 광선: 블롭 바깥, 앞쪽에 길었다가 빠르게 줄어든다. 각도는 천천히 돈다
	float rl = ray_len * mix(0.55, 1.0, grow) * (1.0 - smoothstep(0.3, 0.7, t));
	float rays = vfx_rays(UV, vec2(0.5), rays_count, ray_width * (1.0 - t * 0.5), rl * 0.62, rl, seed * 0.07 + t * 0.04, 0.6, 0.004, int(seed));
	rays *= (1.0 - m) * step(0.02, rl);
	c = mix(c, col_ray.rgb, rays);
	float a = max(m, rays);

	// 충격 링: 얇고 단단한 원이 퍼지며 옅어진다 (가우시안 후광 없음)
	float rr = mix(0.25, 1.0, 1.0 - pow(1.0 - clamp(t, 0.0, 1.0), 2.2));
	float px = max(fwidth(r), 1e-3);
	float ring = (1.0 - smoothstep(0.014, 0.014 + px * 2.0, abs(r - rr))) * (1.0 - smoothstep(0.5, 0.95, t)) * ring_on;
	c = mix(c, col_ring.rgb, ring * (1.0 - a));
	a = max(a, ring);

	// 첫 두 프레임 순백 단색 (셀 스타일 섬광)
	c = mix(c, vec3(1.0), step(t, flash_frames) * m);
	COLOR = vec4(c * a, a);
}
