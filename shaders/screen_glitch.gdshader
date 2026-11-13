// 화면 전체 '나쁜 피해' 글리치 (틱톡식 청록/자홍 분리). VDScreenGlitch(CanvasLayer 13) 의 전체 화면 ColorRect 에 걸린다.
//   1) 화면을 가로 띠(굵은 띠 band_* · 가는 띠 fine_*)로 잘라 일부를 좌우로 민다 (띠마다 난수, seed 가 박자마다 바뀐다)
//   2) 전체에 채널 분리: R 은 오른쪽·아래, G 는 왼쪽·위에서 가져와 왼쪽 가장자리는 청록, 오른쪽 가장자리는 자홍으로 갈라진다
//   3) 밝은 부분(캐릭터·HUD)은 더 멀리 떨어진 자리에 납작한 청록/자홍 잔상(ghost)을 남긴다 (참고 그림의 색 복사본)
//   4) 전체를 살짝 어둡게 (darken) 해 '나쁜 일' 느낌을 준다      5) dropout: 굵은 띠가 통째로 끊겨 평면이 된다 (패배: 신호가 끊기는 느낌)
// amount 는 0..1 세기 포락선, seed 는 박자마다 바뀌는 난수. 길이 단위 px 는 1080p 기준이고 해상도에 맞춰 늘인다.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform float split_px : hint_range(0.0, 30.0) = 9.0;         // 채널 분리 거리
uniform float band_count : hint_range(2.0, 40.0) = 12.0;      // 굵은 띠 수
uniform float band_shift_px : hint_range(0.0, 200.0) = 70.0;  // 굵은 띠 최대 밀림
uniform float band_chance : hint_range(0.0, 1.0) = 0.35;      // 밀리는 굵은 띠 비율 (amount 에 비례)
uniform float fine_count : hint_range(10.0, 200.0) = 90.0;    // 가는 띠 수
uniform float fine_shift_px : hint_range(0.0, 300.0) = 160.0; // 가는 띠 최대 밀림 (길게 찢어지는 선)
uniform float fine_chance : hint_range(0.0, 1.0) = 0.25;
uniform float ghost_px : hint_range(0.0, 60.0) = 22.0;        // 잔상 거리
uniform float ghost_strength : hint_range(0.0, 1.0) = 0.8;
uniform float ghost_thresh : hint_range(0.0, 1.0) = 0.55;     // 이 밝기 이상인 곳만 잔상
uniform float darken : hint_range(0.0, 1.0) = 0.2;
uniform float dropout : hint_range(0.0, 1.0) = 0.0;      // 굵은 띠가 통째로 끊겨 검정/청록/자홍 평면이 되는 비율 (패배)

const vec3 CYAN = vec3(0.145, 0.957, 0.933);     // #25F4EE
const vec3 MAGENTA = vec3(0.996, 0.173, 0.333);  // #FE2C55

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// 띠 하나의 밀림 (px, 부호 포함). 활성 띠만 0 이 아니다
float band_shift(float y, float count, float chance, float max_px, float salt) {
	float b = floor(y * count + hash12(vec2(seed, salt)) * count);
	float r = hash12(vec2(b * 1.37 + salt, seed));
	if (r > chance * amount) {
		return 0.0;
	}
	float m = hash12(vec2(b + 7.0, seed * 0.77 + salt));
	float sgn = hash12(vec2(b + 3.0, seed + salt)) < 0.5 ? -1.0 : 1.0;
	return sgn * max_px * pow(m, 0.6) * amount;
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float k = res.y / 1080.0;
	vec2 px = SCREEN_PIXEL_SIZE * k;
	vec2 uv = SCREEN_UV;

	// 1) 띠 밀림
	float shift = band_shift(uv.y, band_count, band_chance, band_shift_px, 1.0)
		+ band_shift(uv.y, fine_count, fine_chance, fine_shift_px, 2.0);
	vec2 suv = uv + vec2(shift * px.x, 0.0);

	// 2) 채널 분리 (왼쪽 청록 · 오른쪽 자홍)
	vec2 sp = vec2(split_px, split_px * 0.35) * px * amount;
	vec3 cR = texture(screen_tex, suv + sp).rgb;
	vec3 cL = texture(screen_tex, suv - sp).rgb;
	vec3 col = vec3(cR.r, cL.g, max(cL.b, cR.b));

	// 3) 밝은 곳의 납작한 청록/자홍 잔상
	if (ghost_strength > 0.0) {
		vec2 gp = vec2(ghost_px, ghost_px * 0.3) * px * amount;
		float gc = smoothstep(ghost_thresh, ghost_thresh + 0.25, luma(texture(screen_tex, suv - gp).rgb));
		float gm = smoothstep(ghost_thresh, ghost_thresh + 0.25, luma(texture(screen_tex, suv + gp).rgb));
		float g = ghost_strength * amount;
		col = max(col, CYAN * gc * g);
		col = max(col, MAGENTA * gm * g);
	}

	// 5) 띠 끊김 (패배): 굵은 띠 몇 개가 검정 또는 납작한 청록/자홍 평면으로 바뀐다
	if (dropout > 0.0) {
		float cb = floor(uv.y * band_count + hash12(vec2(seed, 1.0)) * band_count);
		if (hash12(vec2(cb + 13.0, seed * 0.91)) < dropout * amount) {
			float pick = hash12(vec2(cb + 21.0, seed));
			vec3 flat_col = pick < 0.6 ? vec3(0.0) : (pick < 0.8 ? CYAN * 0.55 : MAGENTA * 0.55);
			col = mix(col, flat_col, 0.88);
		}
	}

	// 4) 어둡게
	col *= 1.0 - darken * amount;
	COLOR = vec4(col, 1.0);
}
