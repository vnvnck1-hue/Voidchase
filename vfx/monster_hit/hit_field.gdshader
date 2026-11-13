// 흑백 거리장 텍스처 하나를 진행도(life)에 따라 여러 임계값으로 잘라 하드 3톤 + 어두운 테두리로 그린다.
// 코어 플래시(Sprite2D, 스크립트가 life 를 넣음)와 파티클(GPUParticles2D, INSTANCE_CUSTOM.y)에 같이 쓴다.
//   field   : 바깥 0 → 중심 1 거리장 (hit_star / spark / blob)
//   erosion : 타일 침식 맵. 사라질 때 균일하게 흐려지지 않고 갉아먹힌다
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

uniform sampler2D field : repeat_disable, filter_linear;
uniform sampler2D erosion : repeat_enable, filter_linear;

uniform bool use_particle_life = false;
uniform float life = 0.0;               // use_particle_life 가 꺼져 있을 때 스크립트가 넣는다

uniform vec4 col_hot : source_color = vec4(1.0);
uniform vec4 col_mid : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform vec4 col_body : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform vec4 col_rim : source_color = vec4(0.12, 0.03, 0.05, 1.0);
uniform float hot_gain = 1.0;           // 1 초과면 글로우가 번진다 (셀 밴드는 1.25 이하)

uniform float all_white_until = 0.0;    // 이 진행도 전에는 전체를 순백 단색으로 (접촉 프레임)
uniform float hot_until = 0.35;         // 흰 코어가 남아 있는 진행도
uniform float mid_until = 0.7;          // 노랑 띠가 남아 있는 진행도
uniform float cut_start = 0.02;         // 보이는 경계 임계값: 처음
uniform float cut_end = 0.85;           // 보이는 경계 임계값: 끝 (1 근처면 다 사라짐)
uniform float cut_power = 1.6;          // >1 이면 천천히 줄다가 끝에서 빨리 사라짐
uniform float band_mid = 0.14;          // 경계 안쪽으로 노랑 시작까지 거리
uniform float band_hot = 0.32;          // 경계 안쪽으로 흰색 시작까지 거리
uniform float rim_width = 0.05;         // 어두운 테두리 두께 (0 이면 없음)
uniform float erode = 0.0;              // 침식 세기. 진행도에 비례해 커진다
uniform float erode_scale = 1.0;
uniform vec2 erode_offset = vec2(0.0);

uniform float back_taper = 1.0;         // >1 이면 UV.x < 0.5 (뒤쪽) 절반의 형태를 그 배율만큼 짧게
uniform float stretch_start = 1.0;      // 파티클: 진행 방향(Y) 늘림 배율 처음 → 끝
uniform float stretch_end = 1.0;

varying float v_life;
varying vec2 v_seed;

void vertex() {
	v_life = use_particle_life ? INSTANCE_CUSTOM.y : life;
	// 파티클마다 다른 침식 무늬를 쓰도록 INSTANCE_ID 로 오프셋
	v_seed = use_particle_life ? vec2(float(INSTANCE_ID) * 0.37, float(INSTANCE_ID) * 0.61) : erode_offset;
	if (use_particle_life) {
		// align_y 가 켜져 있으면 로컬 Y 가 속도 방향이다. 빠른 초반에 길고 느려지면 짧아진다
		VERTEX.y *= mix(stretch_start, stretch_end, clamp(v_life, 0.0, 1.0));
	}
}

float cut_at(float f, float c) {
	float aa = clamp(fwidth(f), 1e-4, 0.05);
	return smoothstep(c - aa, c + aa, f);
}

void fragment() {
	float t = clamp(v_life, 0.0, 1.0);
	vec2 uv = UV;
	if (uv.x < 0.5) {
		uv.x = 0.5 + (uv.x - 0.5) * back_taper;
	}
	float f = uv.x < 0.0 ? 0.0 : texture(field, uv).r;
	float n = texture(erosion, UV * erode_scale + v_seed).r;

	// 진행도 0 인 첫 프레임에 c = 0 이면 텍스처 빈 영역(f = 0)이 반투명하게 칠해져 쿼드가 사각형으로 보인다. 하한을 둔다
	float c = max(mix(cut_start, cut_end, pow(t, cut_power)) + (n - 0.5) * erode * t, 0.02);

	float vis = cut_at(f, c);
	// 테두리 임계값이 0 이하로 내려가면 텍스처의 빈 영역(f = 0)까지 칠해진다. 0.01 아래로 내리지 않는다
	float rim = rim_width > 0.0 ? cut_at(f, max(c - rim_width, 0.01)) : vis;
	float mid = t < mid_until ? cut_at(f, c + band_mid) : 0.0;
	float hot = t < hot_until ? cut_at(f, c + band_hot) : 0.0;

	vec3 rgb = mix(col_body.rgb, col_mid.rgb, mid);
	rgb = mix(rgb, col_hot.rgb * hot_gain, hot);
	if (t < all_white_until) {
		rgb = col_hot.rgb * hot_gain;
	}

	// premul: 몸통은 불투명하게 덮고, 테두리는 어두운 색으로 덮는다
	float a_body = vis * COLOR.a;
	float a_rim = (rim - vis) * col_rim.a * COLOR.a;
	COLOR = vec4(rgb * a_body + col_rim.rgb * a_rim, a_body + a_rim);
}
