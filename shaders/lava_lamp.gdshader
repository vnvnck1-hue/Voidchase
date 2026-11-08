// 라바램프 패널: 패널 텍스처(시안에서 추출) 안쪽 아래에서 둥근 액체 방울이 천천히 떠오르고 가라앉으며 서로 붙었다 떨어진다.
// 방울은 메타볼(2D 거리장 합)이라 가까워지면 목이 이어지고, 테두리에 얇은 밝은 테가 생겨 액체처럼 보인다.
// 두 겹: 밝은 방울(lava_color) + 어두운 방울(dark_color). edge_wobble > 0 이면 패널 윤곽 자체도 일렁인다(좌측 언덕 패널).
shader_type canvas_item;

uniform vec2 rect_size = vec2(1000.0, 400.0);   // 그려지는 크기(px). 방울을 원형으로 유지하려고 쓴다
uniform vec4 lava_color : source_color = vec4(0.33, 0.21, 0.56, 0.22);
uniform vec4 dark_color : source_color = vec4(0.0, 0.0, 0.0, 0.44);
uniform vec4 rim_color : source_color = vec4(0.62, 0.45, 1.0, 0.35);
uniform float region_top = 0.45;     // 방울이 사는 영역의 윗경계 (UV y). 그 아래에서만 보인다
uniform float blob_px = 46.0;        // 방울 기본 반지름(px)
uniform float speed = 0.22;
uniform float seed = 0.0;
uniform float edge_wobble = 0.0;     // 패널 윤곽 일렁임(px)
uniform float tint_mix = 1.0;        // 방울 색을 패널 위에 얹는 세기

float hash(float n) { return fract(sin(n * 127.1 + seed * 31.7) * 43758.5453); }

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i.x + i.y * 57.0);
	float b = hash(i.x + 1.0 + i.y * 57.0);
	float c = hash(i.x + (i.y + 1.0) * 57.0);
	float d = hash(i.x + 1.0 + (i.y + 1.0) * 57.0);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// 방울 i 의 중심(px)과 반지름: 가로로 느리게 흐르고, 세로로는 바닥에서 떠올랐다 가라앉는다
vec3 blob(float i, float t, float layer) {
	float h1 = hash(i * 3.1 + layer * 17.0);
	float h2 = hash(i * 7.7 + layer * 5.0);
	float h3 = hash(i * 1.3 + layer * 11.0);
	float x = fract(h1 + t * speed * (0.04 + 0.05 * h2) * (h3 > 0.5 ? 1.0 : -1.0)) * (rect_size.x + 2.0 * blob_px) - blob_px;
	x += sin(t * speed * (0.7 + h3) + h1 * 6.28) * blob_px * 0.8;
	float rise = 0.5 + 0.5 * sin(t * speed * (0.5 + 0.6 * h2) + h3 * 6.28);
	float floor_y = rect_size.y + blob_px * 0.35;
	float top_y = mix(rect_size.y, rect_size.y * region_top, 0.35 + 0.65 * h1);
	float y = mix(floor_y, top_y, rise * rise);
	float r = blob_px * (0.55 + 0.75 * h2) * (1.0 - 0.25 * rise);
	return vec3(x, y, r);
}

float field(vec2 p, float t, float layer, int count) {
	float f = 0.0;
	for (int i = 0; i < count; i++) {
		vec3 b = blob(float(i), t, layer);
		vec2 d = p - b.xy;
		f += (b.z * b.z) / max(dot(d, d), 1.0);
	}
	// 바닥에 고인 액체: 아래로 갈수록 장이 커진다
	f += smoothstep(rect_size.y - blob_px * 0.9, rect_size.y + blob_px * 0.3, p.y) * 1.2;
	return f;
}

void fragment() {
	float t = TIME + seed * 13.0;
	vec2 uv = UV;
	if (edge_wobble > 0.0) {
		vec2 q = UV * rect_size / 90.0;
		vec2 w = vec2(noise2(q + vec2(t * 0.25, 0.0)), noise2(q + vec2(5.2, t * 0.21))) - 0.5;
		uv += w * 2.0 * edge_wobble / rect_size;
	}
	vec4 base = texture(TEXTURE, uv) * COLOR;
	vec2 p = UV * rect_size;
	float region = smoothstep(region_top - 0.08, region_top + 0.12, UV.y);

	float f1 = field(p, t, 0.0, 9);
	float m1 = smoothstep(0.92, 1.08, f1);
	float rim1 = smoothstep(0.8, 0.95, f1) - smoothstep(0.98, 1.15, f1);
	float f2 = field(p + vec2(blob_px * 0.6, blob_px * 0.25), t * 0.8, 1.0, 7);
	float m2 = smoothstep(0.95, 1.12, f2);

	vec3 col = base.rgb;
	col = mix(col, dark_color.rgb, m2 * dark_color.a * region * tint_mix);
	col = mix(col, lava_color.rgb, m1 * lava_color.a * region * tint_mix);
	col += rim_color.rgb * rim1 * rim_color.a * region * tint_mix;
	COLOR = vec4(col, base.a);
}
