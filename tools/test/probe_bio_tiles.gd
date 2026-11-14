extends Node

const BioTerrain := preload("res://scripts/void_defense/vd_bio_terrain.gd")
const OUT := "res://docs/bio_lab_runtime_v2/"
var failures: Array[String] = []
var report := {}

class CountTerrain extends "res://scripts/void_defense/vd_bio_terrain.gd":
	var counts := {"top": 0, "left": 0, "right": 0}
	func draw_patch(ci: CanvasItem, points: PackedVector2Array, label: String, alpha := 1.0) -> void:
		counts["top" if label.begins_with("top_") else ("left" if label.begins_with("side_left_") else "right")] += 1
		super.draw_patch(ci, points, label, alpha)


func _ready() -> void:
	run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("[bio] %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures.append(what)


func viewport(size: Vector2i) -> SubViewport:
	var v := SubViewport.new()
	v.size = size
	v.transparent_bg = true
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(v)
	return v


func image_of(v: SubViewport, file_name: String) -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var im := v.get_texture().get_image()
	im.save_png(OUT + file_name + ".png")
	return im


func run() -> void:
	check(is_equal_approx(VDData.TILE_W, 166.4) and is_equal_approx(VDData.TILE_H, 83.2), "game tile 166.4 x 83.2")
	check(is_equal_approx(VDBoard.FACE_H, 66.56), "game side height 66.56")
	var terrain := BioTerrain.new()
	check(terrain.DEFINITION.data["tile_size"] == [166.4, 83.2], "manifest matches current tile dimensions")
	check(is_equal_approx(float(terrain.DEFINITION.data["face_height"]), VDBoard.FACE_H), "manifest matches current side height")
	check(terrain.DEFINITION.data["patches"].size() == 9, "three variants x three independent faces")
	# Export actual GPU-composited blocks using precisely the same faces/polygons as gameplay.
	for i in range(1, 4):
		var v := viewport(Vector2i(168, 152))
		var n := Node2D.new()
		n.position = Vector2(0.8, 1)
		v.add_child(n)
		n.draw.connect(func() -> void:
			terrain.draw_patch(n, VDBoard._left, "side_left_%02d" % i)
			terrain.draw_patch(n, VDBoard._right, "side_right_%02d" % i)
			terrain.draw_patch(n, VDBoard._top, "top_%02d" % i)
		)
		var frame := await image_of(v, "block_%02d_game" % i)
		frame.save_png("res://assets/void_defense_bio/terrain/block_%02d_game.png" % i)
		check(frame.get_pixel(0, 0).a == 0.0 and frame.get_pixel(84, 42).a > 0.99, "block %d transparent exterior and solid top" % i)
		v.queue_free()
	# A room with a missing corner, an internal hole and a connected corridor.
	var v := viewport(Vector2i(1280, 900))
	var board := VDBoard.new()
	var spy := CountTerrain.new()
	board.bio_terrain = spy
	board.map = VDMap.new()
	for x in 4:
		for y in 4:
			if Vector2i(x, y) not in [Vector2i(2, 2), Vector2i(3, 3)]:
				board.map.tiles[Vector2i(x, y)] = {"kind": "room", "room": 0}
	for x in range(4, 7):
		board.map.tiles[Vector2i(x, 1)] = {"kind": "corridor", "room": -1}
	board.position = Vector2(500, 170)
	board.placement_mode = false
	board.set_theme(VDWorldTheme.Kind.BIO)
	v.add_child(board)
	var before := await image_of(v, "joined_board")
	var expected := {"top": board.map.tiles.size(), "left": 0, "right": 0}
	for cell: Vector2i in board.map.tiles:
		if not board.map.tiles.has(cell + Vector2i(0, 1)): expected["left"] += 1
		if not board.map.tiles.has(cell + Vector2i(1, 0)): expected["right"] += 1
	report["static_drawn_faces"] = spy.counts.duplicate()
	report["expected_exposed_faces"] = expected
	check(spy.counts == expected, "only exposed sides are drawn, including hole and corridor edges")
	var checked := 0
	var gaps := 0
	for cell: Vector2i in board.map.tiles:
		for step in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not board.map.tiles.has(cell + step): continue
			var origin := board.position + VDData.to_screen(Vector2(cell)) - VDBoard.TOP_CENTER
			var a: Vector2 = VDBoard._top[1] if step.x == 1 else VDBoard._top[3]
			var b: Vector2 = VDBoard._top[2]
			for t in range(1, 10):
				var p := Vector2i(origin + a.lerp(b, t / 10.0))
				checked += 1
				if before.get_pixelv(p).a < 0.99: gaps += 1
	check(gaps == 0, "shared tile edges have no transparent gaps: %d samples" % checked)
	report["shared_edge_samples"] = checked
	report["transparent_shared_edge_samples"] = gaps
	var cells: Array = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
	board.raise_tiles(cells, cells[0])
	await get_tree().create_timer(0.16).timeout
	check(not board._rise.is_empty(), "current board rise animation is active")
	await image_of(v, "rising_board")
	await get_tree().create_timer(1.0).timeout
	var after := await image_of(v, "settled_board")
	check(board._rise.is_empty(), "rise animation settles without changing map")
	var different := 0
	for y in before.get_height():
		for x in before.get_width():
			if before.get_pixel(x, y) != after.get_pixel(x, y): different += 1
	check(different == 0, "settled board matches original static render: %d differences" % different)
	report["settled_different_pixels"] = different
	# Switching uses existing settings and does not reset board/map/rise state.
	var old_map := board.map
	board.raise_tiles(cells, cells[0])
	var rise_before := board._rise.duplicate()
	for theme in [VDWorldTheme.Kind.VOID, VDWorldTheme.Kind.DESERT, VDWorldTheme.Kind.BIO]:
		board.set_theme(theme)
	check(board.map == old_map and board._rise == rise_before, "theme switching preserves map and rising cells")
	v.queue_free()
	report["failures"] = failures
	var f := FileAccess.open(OUT + "runtime_validation.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("[bio] DONE failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

