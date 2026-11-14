extends Node
const OUT := "res://docs/bio_lab_runtime_v2/"
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
	print("[bio] actual battle capture; theme=", b.background_theme, " tiles=", b.map.tiles.size())
	b.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)

