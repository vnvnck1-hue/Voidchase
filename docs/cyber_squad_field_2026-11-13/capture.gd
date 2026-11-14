extends Node

const OUT := "res://docs/cyber_squad_field_2026-11-13/"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_tree().root.content_scale_size = Vector2i(1920, 1080)
	var battle: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(battle)
	var deadline := Time.get_ticks_msec() + 25000
	while battle.enemies.is_empty():
		await get_tree().process_frame
		if Time.get_ticks_msec() > deadline:
			get_tree().quit(1)
			return
	await get_tree().create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "field_before.png")
	for unit in battle.allies:
		print("[cyber-squad] ", unit.id, " feet=", unit.get_global_transform_with_canvas().origin)
	print("[cyber-squad] captured actual field; theme=", battle.background_theme)
	battle.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)
