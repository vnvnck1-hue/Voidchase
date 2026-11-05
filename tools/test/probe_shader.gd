extends SceneTree
## Renders panel_02.png with several canvas shaders side by side and prints a sampled pixel of each.

const VARIANTS := {
	"none": "",
	"mul": "shader_type canvas_item;\nvoid fragment() { COLOR *= texture(TEXTURE, UV); }",
	"assign": "shader_type canvas_item;\nvoid fragment() { COLOR = texture(TEXTURE, UV) * COLOR; }",
	"tex_only": "shader_type canvas_item;\nvoid fragment() { COLOR = texture(TEXTURE, UV); }",
	"outline": "res://shaders/panel_outline.gdshader",
}

func _init() -> void:
	var tex: Texture2D = load("res://assets/textures/char_panels/panel_02.png")
	var root2d := Node2D.new()
	root.add_child(root2d)
	var i := 0
	for k in VARIANTS:
		var s := Sprite2D.new()
		s.texture = tex
		s.position = Vector2(200 + i * 330, 300)
		if VARIANTS[k] != "":
			var m := ShaderMaterial.new()
			if VARIANTS[k].begins_with("res://"):
				m.shader = load(VARIANTS[k])
			else:
				var sh := Shader.new()
				sh.code = VARIANTS[k]
				m.shader = sh
			s.material = m
		root2d.add_child(s)
		i += 1
	for f in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	i = 0
	for k in VARIANTS:
		var p := Vector2(200 + i * 330, 300) + Vector2(-101, 88.5)  # texel (49,203) = src (560,250) = (214,70,88)
		print("%-9s %s" % [k, img.get_pixel(int(p.x), int(p.y))])
		i += 1
	quit()
