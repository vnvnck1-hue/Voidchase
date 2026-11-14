extends Node

const OUT := "res://docs/field_diorama_concepts_2026-11-13/"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_tree().root.content_scale_size = Vector2i(1920, 1080)
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	var deadline := Time.get_ticks_msec() + 25000
	while b.enemies.is_empty():
		await get_tree().process_frame
		if Time.get_ticks_msec() > deadline:
			print("[field-diorama] enemy spawn timed out")
			get_tree().quit(1)
			return
	await get_tree().create_timer(1.5).timeout
	b.start_battle()
	await get_tree().create_timer(2.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "battle_capture.png")
	print("[field-diorama] captured actual battle at ", get_viewport().get_texture().get_size())
	get_tree().quit(0)

