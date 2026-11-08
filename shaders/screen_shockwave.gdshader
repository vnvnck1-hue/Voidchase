// 화면 쇼크웨이브: 맞은 자리에서 둥근 띠가 퍼지며 띠 둘레의 화면을 바깥쪽으로 밀어 일렁이게 한다.
// 월드(배경·바닥·유닛·이펙트) 위, 앞 안개·HUD 아래의 CanvasLayer 에 화면 전체 ColorRect 로 올린다.
// 웨이브 값은 VDShockwave 가 매 프레임 넣는다 (최대 6개, 세기 0 이면 꺼짐).
shader_type canvas_item;
render_mode unshaded;

const int MAX_WAVES = 6;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 res = vec2(1920.0, 1080.0);   // 보이는 화면 크기 (캔버스 px)
uniform vec4 waves[6];                     // 중심 x, 중심 y (화면 px, 위가 0), 반지름 px, 세기
uniform vec4 bands[6];                     // 띠 두께 px, 위아래 납작함(1 = 원), 밝기, 0
uniform float push = 0.6;                  // 띠 두께 대비 최대로 미는 거리
uniform float chroma = 0.2;                // 미는 거리 대비 색 어긋남 (최대 3px)
uniform float glow = 0.05;                 // 띠 가운데를 밝히는 양

void fragment() {
	vec2 px = SCREEN_UV * res;
	vec2 off = vec2(0.0);
	float lit = 0.0;
	for (int i = 0; i < MAX_WAVES; i++) {
		vec4 w = waves[i];
		vec4 b = bands[i];
		if (w.w <= 0.0) {
			continue;
		}
		// 바닥 원근에 맞춰 세로로 납작한 타원 띠
		vec2 d = px - w.xy;
		vec2 de = vec2(d.x, d.y / b.y);
		float dist = length(de);
		float x = (dist - w.z) / b.x;          // 띠 안에서 -1(안쪽) ~ 1(바깥쪽)
		if (x <= -1.0 || x >= 1.0 || dist < 0.5) {
			continue;
		}
		// 안쪽 반은 안으로, 바깥쪽 반은 밖으로 밀리는 S 자: 띠가 렌즈처럼 굴절돼 보인다. 양 끝은 0.
		float f = sin(x * PI) * (1.0 - abs(x));
		float bump = 1.0 - x * x;
		vec2 dir = normalize(vec2(de.x, de.y * b.y));
		off += dir * f * w.w * b.x * push;
		lit += bump * bump * w.w * b.z;
	}
	vec2 suv = clamp((px - off) / res, vec2(0.0), vec2(1.0));
	vec4 c = textureLod(screen_tex, suv, 0.0);
	float m = length(off);
	if (m > 0.01) {
		vec2 ca = (off / m) * min(m * chroma, 3.0) / res;
		c.r = textureLod(screen_tex, clamp(suv - ca, vec2(0.0), vec2(1.0)), 0.0).r;
		c.b = textureLod(screen_tex, clamp(suv + ca, vec2(0.0), vec2(1.0)), 0.0).b;
	}
	c.rgb += lit * glow;
	COLOR = vec4(c.rgb, 1.0);
}
