## GPU 위에 원화 좌표로 재조립한 면을 실제 원본 픽셀과 비교하고, 단독 블록 PNG를 만든다.
extends Node

const OUT := "res://docs/desert_station_tiles/"
var terrain := VDDesertTerrain.new()


func _ready() -> void:
	call_deferred("_run")


func _viewport(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	return vp


func _run() -> void:
	var source := Image.load_from_file("res://docs/background_concepts_v1/battle_desert_station_v3.png")
	var vp := _viewport(source.get_size())
	var faces := Node2D.new()
	vp.add_child(faces)
	faces.draw.connect(func() -> void:
		for patch: Dictionary in terrain.DEFINITION.data["patches"]:
			var polygon := PackedVector2Array()
			for p: Array in patch["source_points"]:
				polygon.append(Vector2(p[0], p[1]))
			terrain.draw_patch(faces, polygon, patch["name"])
	)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var rendered := vp.get_texture().get_image()
	rendered.save_png(OUT + "native_gpu_reassembly.png")
	var samples := 0
	var different := 0
	var max_error := 0
	for patch: Dictionary in terrain.DEFINITION.data["patches"]:
		var polygon := PackedVector2Array()
		for p: Array in patch["source_points"]:
			polygon.append(Vector2(p[0], p[1]))
		var rect: Array = patch["source_rect"]
		for y in range(rect[1], rect[1] + rect[3]):
			for x in range(rect[0], rect[0] + rect[2]):
				var pos := Vector2(x + 0.5, y + 0.5)
				if not Geometry2D.is_point_in_polygon(pos, polygon):
					continue
				var border := false
				for i in 4:
					if Geometry2D.get_closest_point_to_segment(pos, polygon[i], polygon[(i + 1) % 4]).distance_to(pos) < 3.0:
						border = true
						break
				if border:
					continue
				var a := source.get_pixel(x, y)
				var b := rendered.get_pixel(x, y)
				var error := roundi(255.0 * maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))))
				samples += 1
				max_error = maxi(max_error, error)
				if error > 1:
					different += 1
	var report := {"gpu_native_samples": samples, "pixels_with_error_over_1_of_255": different, "max_channel_error_0_255": max_error,
		"scope": "Native source-coordinate atlas reconstruction. Three-pixel polygon boundaries excluded; gameplay camera scale and grid normalization are separate."}
	var file := FileAccess.open(OUT + "gpu_pixel_check.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("[desert] native GPU pixel check: ", report)
	# Conventional single-block PNG for Sprite2D/TileSet consumers, using the same runtime faces.
	var block_vp := _viewport(Vector2i(168, 152))
	var block := Node2D.new()
	block.position = Vector2(0.8, 1.0)
	block_vp.add_child(block)
	block.draw.connect(func() -> void:
		terrain.draw_side(block, VDBoard._left, false, 1.0)
		terrain.draw_side(block, VDBoard._right, true, 1.0)
		terrain.draw_patch(block, VDBoard._top, "top_04")
	)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	block_vp.get_texture().get_image().save_png("res://assets/void_defense_desert/terrain/desert-station-block.png")
	get_tree().quit(0 if different == 0 else 1)
