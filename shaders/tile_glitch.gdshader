// 전투 필드 타일 글리치 (2026-11-11, scripts/void_defense/vd_tile_glitch.gd).
// 타일 윗면 마름모마다 폴리곤 하나를 깔고, 그 아래 이미 그려진 화면(배경+보드)을 읽어 타일 단위로 비튼다.
// 타일 번호는 정점 위치(보드 좌표)에서 역산하므로 테마(공허/사막)와 상관없이 같은 셰이더를 쓴다.
//   style 0 신호 잡음   : 가로 띠가 밀리고 색이 갈라지는 '치지직'
//   style 1 데이터 붕괴 : 타일이 등각 픽셀 블록으로 깨지고 일부 블록은 비트 무늬의 빈 데이터로
//   style 2 기억 홀로그램: 타일이 와이어프레임 홀로그램으로 바뀌며 뇌파(파형)가 바닥을 지나간다
// 공통: 기억 스캔선(sweep)이 전장을 훑고, pulses 로 충격·구역 로딩 물결이 타일 단위로 번진다.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform int style = 0;
uniform float u_time = 0.0;
uniform float amount = 1.0;        // 전체 세기
uniform float density = 0.035;     // 한 박자에 타일 하나가 글리치를 일으킬 확률
uniform float rate = 1.2;          // 박자 (회/초)
uniform float step_fps = 14.0;     // 지직거림 박자 (무늬가 바뀌는 횟수/초)
uniform float sweep = 0.3;         // 기억 스캔선 세기 (0 = 없음)
uniform float sweep_period = 9.0;  // 스캔선이 전장을 한 번 훑는 시간(초)
uniform vec2 sweep_range = vec2(0.0, 12.0);   // 맵의 깊이(x+y) 범위
uniform vec2 half_tile = vec2(83.2, 41.6);
uniform vec3 col_a : source_color = vec3(0.15, 0.96, 0.93);
uniform vec3 col_b : source_color = vec3(1.0, 0.2, 0.62);
// xy = 중심 칸, z = 시작 시각(u_time 기준), w = 세기(0 이면 빈 칸) / x = 속도(칸/초), y = 수명(초), z = 최대 반경(칸)
uniform vec4 pulses[6];
uniform vec4 pulse_shape[6];

varying vec2 wpos;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	wpos = VERTEX;
}

void fragment() {
	// 보드 좌표 1px 이 화면 UV 로 얼마인지 (카메라 줌·창 크기와 무관하게)
	vec2 uvw = vec2(dFdx(SCREEN_UV.x) / dFdx(wpos.x), dFdy(SCREEN_UV.y) / dFdy(wpos.y));
	vec2 ab = wpos / half_tile;
	vec2 g = vec2(ab.x + ab.y, ab.y - ab.x) * 0.5;   // 등각 칸 좌표
	vec2 cell = floor(g + 0.5);
	vec2 l = g - cell;                               // 칸 안 좌표 (-0.5 .. 0.5)
	float st = floor(u_time * step_fps);
	float h0 = h21(cell * 1.37 + 3.1);

	// 1) 가끔 혼자 지직거리는 타일
	float t = u_time * rate + h0 * 61.0;
	float ep = floor(t);
	float ph = t - ep;
	float on = step(h21(cell + ep * vec2(17.3, 9.7)), density);
	float dur = mix(0.2, 0.6, h21(cell * 2.1 + ep));
	float k = on * step(ph, dur);
	// 2) 충격·구역 로딩 물결
	for (int i = 0; i < 6; i++) {
		vec4 p = pulses[i];
		vec4 s = pulse_shape[i];
		float age = u_time - p.z;
		if (p.w > 0.0 && age >= 0.0 && age < s.y) {
			float d = length(cell - p.xy);
			float ring = 1.0 - smoothstep(0.0, 1.3, abs(d - age * s.x));
			k = max(k, ring * p.w * (1.0 - age / s.y) * step(d, s.z + 0.5));
		}
	}
	// 지직: 박자마다 세기가 툭툭 끊긴다
	k *= mix(0.35, 1.0, step(0.3, h21(cell + st * 0.731)));
	k = clamp(k * amount, 0.0, 1.0);

	vec3 rgb = vec3(0.0);
	float a = 0.0;
	if (k > 0.002) {
		if (style == 0) {
			float bh = mix(5.0, 16.0, h21(vec2(st, cell.x + cell.y * 7.0)));
			float band = floor(wpos.y / bh);
			float bhv = h21(vec2(band, st * 1.3 + h0 * 9.0));
			float shift = bhv > 0.5 ? (h21(vec2(band * 3.1, st)) - 0.5) * 2.0 : 0.0;
			float dx = shift * 30.0 * k;
			float ca = 5.0 * k + abs(dx) * 0.25;
			vec3 c;
			c.r = texture(screen_tex, SCREEN_UV + vec2((dx + ca) * uvw.x, 0.0)).r;
			c.g = texture(screen_tex, SCREEN_UV + vec2(dx * uvw.x, 0.0)).g;
			c.b = texture(screen_tex, SCREEN_UV + vec2((dx - ca) * uvw.x, 0.0)).b;
			float line = step(0.92, h21(vec2(band * 7.7, st + 2.0)));
			c += mix(col_a, col_b, step(0.5, h21(vec2(band * 5.3 + 1.7, st + 31.0)))) * line * 0.8;
			c *= 1.0 - 0.55 * step(0.9, h21(vec2(band * 1.9, st + 11.0)));
			c += (h21(floor(wpos / 2.0) + st) - 0.5) * 0.2 * k;
			rgb = c;
			a = 1.0;
		} else if (style == 1) {
			float n = floor(mix(3.0, 7.0, h21(cell + floor(st / 3.0))));
			vec2 fl = (l + 0.5) * n;
			vec2 bl = floor(fl);
			vec2 fb = fl - bl;
			vec2 src = (bl + 0.5) / n - 0.5;
			float bhv = h21(bl + cell * 13.0 + floor(st / 2.0) * vec2(3.1, 7.7));
			if (bhv > 0.7) {
				src += (vec2(h21(bl + st), h21(bl.yx + st + 5.0)) - 0.5) * 2.0 / n;
			}
			vec2 dg = src - l;
			vec2 dworld = vec2((dg.x - dg.y) * half_tile.x, (dg.x + dg.y) * half_tile.y);
			vec3 c = texture(screen_tex, SCREEN_UV + dworld * uvw).rgb;
			c = mix(c, floor(c * 5.0 + 0.5) / 5.0, 0.6);
			if (bhv < 0.24) {
				vec2 sb = floor(fb * 3.0);
				float bit = step(0.55, h21(sb + bl * 5.0 + st));
				c = mix(vec3(0.02, 0.03, 0.07), col_a, bit * 0.6);
			} else if (bhv > 0.9) {
				c = mix(c, col_b, 0.55);
			}
			float edge = min(1.0, step(fb.x, 0.07) + step(fb.y, 0.07));
			c += col_a * edge * 0.3;
			rgb = c;
			a = step(h21(bl * 1.7 + cell * 5.3), k * 1.5);
		} else {
			float jit = (h21(vec2(floor(wpos.y / 3.0), st)) - 0.5) * 5.0 * k;
			vec3 s = texture(screen_tex, SCREEN_UV + vec2(jit * uvw.x, 0.0)).rgb;
			float lum = dot(s, vec3(0.3, 0.55, 0.15));
			vec3 c = mix(vec3(0.01, 0.05, 0.11), col_a, lum * 0.85 + 0.08);
			c *= 0.72 + 0.28 * step(0.5, fract(wpos.y / 4.0 - u_time * 5.0));
			float e = max(abs(l.x), abs(l.y));
			float wire = smoothstep(0.45, 0.485, e);
			vec2 f = fract((l + 0.5) * 4.0);
			float gdist = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
			float grid = 1.0 - smoothstep(0.0, 0.07, gdist);
			c += col_a * (wire * 0.9 + grid * 0.2);
			// 뇌파: 칸의 한 축을 따라 흐르는 파형 (가끔 뾰족하게 튄다)
			float x = l.x + 0.5;
			float tt = u_time * 0.9 + h0 * 5.0;
			float p = fract(x * 1.6 - tt);
			float spike = exp(-pow((p - 0.5) * 14.0, 2.0)) * 0.27 - exp(-pow((p - 0.62) * 18.0, 2.0)) * 0.13;
			float wv = 0.03 * sin(x * 40.0 - tt * 20.0) - spike;
			float eeg = (1.0 - smoothstep(0.012, 0.032, abs(l.y - wv))) * step(abs(l.x), 0.43);
			c = mix(c, mix(vec3(1.0), col_b, 0.25), eeg * 0.95);
			rgb = c;
			a = clamp(k * 1.7, 0.0, 1.0) * 0.94;
		}
	}
	// 3) 기억 스캔선: 깊이 방향으로 전장을 훑으며 타일 테두리를 잠깐 밝힌다
	if (sweep > 0.0) {
		float depth = g.x + g.y;
		float span = sweep_range.y - sweep_range.x + 8.0;
		float pos = sweep_range.x - 4.0 + fract(u_time / sweep_period) * span;
		float d = depth - pos;
		float trail = d < 0.0 ? exp(d * 1.5) : 0.0;
		float e2 = max(abs(l.x), abs(l.y));
		float edge2 = smoothstep(0.4, 0.5, e2);
		float front = 1.0 - smoothstep(0.0, 0.07, abs(d));
		float sa = clamp(sweep * (trail * edge2 * 0.6 + front * 0.55), 0.0, 1.0);
		float a_out = a + sa * (1.0 - a);
		rgb = (rgb * a * (1.0 - sa) + col_a * sa) / max(a_out, 0.0001);
		a = a_out;
	}
	COLOR = vec4(rgb, a);
}
