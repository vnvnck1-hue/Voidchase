// Port of Unity "CAT/2D/SpriteColorLerp" (Assets/KSC_251206/Shader/SpriteColorLerp.shader)
// final = lerp(texColor * vertexColor, (TargetColor.rgb, texAlpha), LerpValue)
shader_type canvas_item;
render_mode blend_mix;

uniform vec4 target_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float lerp_value : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec4 target = vec4(target_color.rgb, c.a);
	COLOR = mix(c, target, lerp_value);
}
