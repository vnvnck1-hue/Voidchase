extends Node
const Props := preload("res://scripts/void_defense/vd_bio_props.gd")
const OUT := "res://docs/bio_lab_props_runtime/"
var failures: Array[String] = []
var results: Array[Dictionary] = []


func _ready() -> void:
	run.call_deferred()


func check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
	print("[bio-props] %s %s" % ["PASS" if ok else "FAIL", what])


func audit(props: Node2D, map: VDMap, room: Dictionary) -> bool:
	var valid: bool = props.room_count(room["id"]) == 3
	var used := {}
	for item in props.items:
		var connected := false
		var sprite: Sprite2D = item["sprite"]
		valid = valid and sprite.scale == Vector2.ONE and sprite.rotation == 0.0 and not sprite.flip_h
		for cell in item["cells"]:
			valid = valid and not map.tiles.has(cell) and not used.has(cell)
			used[cell] = true
			for step in [Vector2i(1, 0), Vector2i(0, 1)]:
				if map.tiles.has(cell + step):
					connected = true
		valid = valid and connected
	# All four view corners fit the ordinary HUD-free bounds at the framed camera.
	for view in [Vector2(1920, 1080), Vector2(1280, 720), Vector2(2560, 1080)]:
		var framing: Dictionary = props.frame_camera(room, view, VDData.to_screen(VDMap.center_f(room)), 1.18)
		var bounds: Rect2 = props.frame_bounds(room)
		var screen := Rect2((bounds.position - (framing["position"] as Vector2)) * float(framing["zoom"]) + view * 0.5, bounds.size * float(framing["zoom"]))
		valid = valid and screen.position.x >= view.x * 0.04 - 1 and screen.end.x <= view.x * 0.89 + 1
		valid = valid and screen.position.y >= view.y * 0.15 - 1 and screen.end.y <= view.y * 0.81 + 1
	return valid


func run() -> void:
	for shape: String in VDMap.TEMPLATES:
		for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var map := VDMap.new()
			map.rng.seed = 2
			var room := map._add_room(Vector2i.ZERO, dir, [], shape)
			var original := map.tiles.duplicate(true)
			var props := Props.new()
			add_child(props)
			props.scatter_room(map, room)
			var count := props.items.size()
			var transforms: Array = props.items.map(func(item: Dictionary) -> Vector2: return item["base"])
			props.scatter_room(map, room)
			var ok := audit(props, map, room) and props.items.size() == count and map.tiles == original and transforms == props.items.map(func(item: Dictionary) -> Vector2: return item["base"])
			check(ok, "%s dir=%s count=%d, fixed placement, no gameplay overlap, HUD framing" % [shape, dir, count])
			results.append({"shape": shape, "dir": [dir.x, dir.y], "props": count, "ok": ok})
			# A future playable cell must remove an overlapping decoration immediately.
			if not props.items.is_empty():
				var blocked: Vector2i = props.items[0]["cells"][0]
				map.tiles[blocked] = {"kind": "corridor", "room": 9}
				props.remove_near([blocked])
				for item in props.items:
					check(blocked not in item["cells"], "new playable floor removes any overlapping prop")
			props.queue_free()
			await get_tree().process_frame
	var f := FileAccess.open(OUT + "placement_validation.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"layouts": results, "failures": failures}, "\t"))
	f.close()
	print("[bio-props] DONE layouts=", results.size(), " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

