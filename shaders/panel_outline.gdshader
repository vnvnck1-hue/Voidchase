// Soft outline drawn around the opaque shape of a sprite (used for the selected character panel).
// The panel textures are padded with transparent pixels so the outline has room to draw.
// Note: in canvas_item shaders the fragment COLOR input is already vertex colour * TEXTURE, so the
// modulate is carried over from vertex() separately and the texture is sampled only once here.
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.96, 0.92, 1.0, 1.0);
uniform float outline_px : hint_range(0.0, 16.0) = 5.0;
uniform float strength : hint_range(0.0, 1.0) = 0.0;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float a = 0.0;
	if (strength > 0.001) {
		vec2 px = TEXTURE_PIXEL_SIZE * outline_px;
		for (int i = 0; i < 16; i++) {
			float ang = float(i) * 0.39269908;
			a = max(a, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px).a);
		}
	}
	float edge = clamp(a - col.a, 0.0, 1.0) * strength * outline_color.a;
	float out_a = col.a + edge * (1.0 - col.a);
	vec3 out_rgb = (col.rgb * col.a + outline_color.rgb * edge * (1.0 - col.a)) / max(out_a, 1e-4);
	COLOR = vec4(out_rgb, out_a) * v_modulate;
}
