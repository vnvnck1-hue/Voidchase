// UI 조각(유물 보상 카드 · 제목)이 글리치되며 '물질화'하는 사이파이 등장 셰이더. CanvasGroup 에 걸어 쓴다
// (CanvasGroup 은 자식을 백버퍼에 그린 뒤 이 셰이더로 다시 그린다. 기본 CanvasGroup 셰이더처럼 screen_texture 를 읽고 알파를 되돌린다).
// progress 0 → 1 로 스크립트가 민다 (vd_relic_hud._show_next_offer).
//   0.0~0.12  흰 섬광 실루엣          0~0.45  일부 가로 띠가 납작한 청록/자홍 실루엣
//   전 구간   가로 띠 좌우 밀림 · 청록/자홍 채널 분리 · 띠 단위 난수 순서로 켜짐(reveal) · 홀로그램 주사선 · 밝기 깜빡임 — 모두 (1-progress) 에 비례
// 박자: step_fps 로 난수가 바뀐다. 길이 px 는 실제 화면 px.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float step_fps = 24.0;
uniform float slice_px = 14.0;       // 가로 띠 높이
uniform float shift_px = 46.0;       // 띠 최대 밀림
uniform float split_px = 10.0;       // 채널 분리 (progress 0 일 때)
uniform float scan_px = 3.0;         // 홀로그램 주사선 간격
uniform float scan_dark = 0.45;      // 주사선 어둡기 (progress 0 일 때)

const vec3 CYAN = vec3(0.145, 0.957, 0.933);
const vec3 MAGENTA = vec3(0.996, 0.173, 0.333);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec4 grab(vec2 suv) {
	vec4 c = textureLod(screen_texture, suv, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	return c;
}

void fragment() {
	float t = clamp(1.0 - progress, 0.0, 1.0);
	if (t <= 0.0) {
		COLOR *= grab(SCREEN_UV);
	} else {
		float seed = floor(TIME * step_fps);
		float band = floor(FRAGCOORD.y / max(slice_px, 1.0));
		// 띠 밀림: 초반엔 거의 모든 띠, 끝날수록 드물게
		float r = hash12(vec2(band, seed));
		float active = step(r, 0.15 + 0.7 * t);
		float sh = (hash12(vec2(band + 3.0, seed * 0.73)) - 0.5) * 2.0 * shift_px * t * active;
		vec2 suv = SCREEN_UV + vec2(sh * SCREEN_PIXEL_SIZE.x, 0.0);
		// 채널 분리 (왼쪽 청록 · 오른쪽 자홍)
		vec2 sp = vec2(split_px * t * SCREEN_PIXEL_SIZE.x, 0.0);
		vec4 cR = grab(suv + sp);
		vec4 cL = grab(suv - sp);
		vec4 cC = grab(suv);
		vec4 col = vec4(cR.r, cL.g, max(cL.b, cR.b), max(cC.a, max(cL.a, cR.a) * 0.9));
		// 켜짐: 띠마다 고정 난수 순서로 (progress 가 커지면 다 켜진다) + 박자마다 몇 띠는 깜빡 꺼짐
		float order = hash12(vec2(band + 17.0, 4.0));
		float reveal = step(order, progress * 1.7 + 0.2);   // 0.5 쯤이면 거의 다 켜지고 그 뒤는 밀림·분리만 남는다
		float blink = step(0.08 * t, hash12(vec2(band + 29.0, seed + 1.0)));
		col.a *= reveal * blink;
		// 납작한 청록/자홍 실루엣 (초반) 과 흰 섬광 (맨 처음)
		float flat_k = smoothstep(0.38, 0.08, progress) * step(0.4, hash12(vec2(band + 5.0, seed)));
		vec3 sil = hash12(vec2(band, seed + 2.0)) < 0.5 ? CYAN : MAGENTA;
		col.rgb = mix(col.rgb, sil, flat_k);
		col.rgb = mix(col.rgb, vec3(1.0), smoothstep(0.12, 0.0, progress) * 0.85);
		// 홀로그램 주사선 · 깜빡임
		float sl = 0.5 + 0.5 * cos(FRAGCOORD.y / max(scan_px, 1.0) * 6.2831853);
		col.rgb *= 1.0 - scan_dark * t * sl;
		col.rgb *= 1.0 + t * (hash12(vec2(seed, 9.0)) - 0.5) * 0.5;
		COLOR *= col;
	}
}
