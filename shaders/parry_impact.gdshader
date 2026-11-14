// 패링 충돌 화면 연출 (VDParryImpact): 맞부딪친 점을 중심으로 방사형 블러 + 색수차 + 만화 집중선.
// 화면 전체 ColorRect 에 올린다. k(세기 0~1)는 VDParryImpact 가 실제 시간으로 넣는다 (히트스탑 중에도 움직인다).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 center = vec2(0.5, 0.5);      // 충돌점 (화면 UV)
uniform float aspect = 1.7778;
uniform float k = 0.0;                     // 전체 세기 (0 이면 원본 그대로)
uniform float blur = 0.06;                 // 방사형 블러: 가장자리에서 중심 쪽으로 끌리는 거리 (UV)
uniform float chroma = 0.012;              // 색수차: R/B 가 방사 방향으로 갈라지는 거리 (UV)
uniform float lines = 0.8;                 // 집중선 농도
uniform float seed = 0.0;                  // 집중선 무늬 (몇 프레임마다 바뀌어 지글거린다)
uniform vec4 line_col : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform float flash = 0.0;                 // 충돌 순간 색 반전 섬광 (임팩트 프레임)

float hash(float n) {
	return fract(sin(n * 127.1 + seed * 311.7) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - center;
	vec2 da = vec2(d.x * aspect, d.y);
	float dist = length(da);
	float edge = smoothstep(0.05, 0.75, dist);

	// 방사형 블러 + 색수차: 중심은 또렷하고 가장자리로 갈수록 크게
	vec3 col = vec3(0.0);
	float amt = blur * k * edge;
	float ca = chroma * k * (0.35 + edge);
	vec2 dir = normalize(d + vec2(1e-5));
	const int N = 8;
	for (int i = 0; i < N; i++) {
		float f = float(i) / float(N - 1);
		vec2 p = uv - d * amt * f;
		col.r += texture(screen_tex, p + dir * ca).r;
		col.g += texture(screen_tex, p).g;
		col.b += texture(screen_tex, p - dir * ca).b;
	}
	col /= float(N);

	// 임팩트 프레임: 한순간 밝기를 뒤집어 금빛으로 물들인다
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 inv = mix(vec3(0.06, 0.02, 0.1), tint.rgb * 1.15, smoothstep(0.55, 0.2, luma));
	col = mix(col, inv, flash);

	// 집중선: 각도를 잘게 나눠 일부 칸만 가장자리에서 중심 쪽으로 뻗는 쐐기
	float ang = atan(da.y, da.x) / 6.28318 + 0.5;
	float cells = 96.0;
	float id = floor(ang * cells);
	float fr = fract(ang * cells);
	float pick = step(0.62, hash(id));
	float reach = mix(0.28, 0.62, hash(id + 17.0));            // 이 반지름 밖에서만 보인다
	float wedge = smoothstep(reach, reach + 0.5, dist);         // 바깥으로 갈수록 굵다
	float shape = 1.0 - abs(fr - 0.5) * 2.0;
	float ln = pick * step(1.0 - wedge * mix(0.5, 1.0, hash(id + 5.0)), shape) * step(reach, dist);
	col = mix(col, line_col.rgb, ln * lines * k);

	// 가장자리를 살짝 물들여 시선을 중심으로 모은다
	col = mix(col, col * tint.rgb, 0.35 * k * edge);
	COLOR = vec4(col, 1.0);
}
