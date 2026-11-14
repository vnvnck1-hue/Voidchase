extends Node
const OUT := "res://docs/bio_lab_props_runtime/"
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	VDWorldTheme.select(VDWorldTheme.Kind.BIO, false)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_tree().root.content_scale_size = Vector2i(1920, 1080)
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	var deadline := Time.get_ticks_msec() + 20000
	while b.enemies.is_empty():
		await get_tree().process_frame
		if Time.get_ticks_msec() > deadline:
			get_tree().quit(1)
			return
	await get_tree().create_timer(1.5).timeout
	b.start_battle()
	await get_tree().create_timer(2.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "actual_battle.png")
	var props: Array = []
	for item in b.bio_props.items:
		if item["room_id"] != b.room["id"]: continue
		var sprite: Sprite2D = item["sprite"]
		var screen_rect: Rect2 = sprite.get_global_transform_with_canvas() * sprite.get_rect()
		var cells: Array = []
		for cell in item["cells"]: cells.append([cell.x, cell.y])
		props.append({"id": item["id"], "screen_rect": [screen_rect.position.x, screen_rect.position.y, screen_rect.size.x, screen_rect.size.y], "support_cells": cells, "rotation": sprite.rotation, "scale": [sprite.scale.x, sprite.scale.y]})
	var f := FileAccess.open(OUT + "capture_props.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"viewport": [1920,1080], "theme": b.background_theme, "playable_tiles": b.map.tiles.size(), "props": props}, "\t"))
	f.close()
	print("[bio-props] actual battle captured; theme=", b.background_theme, " props=", props.size())
	b.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if props.size() == 3 else 1)

