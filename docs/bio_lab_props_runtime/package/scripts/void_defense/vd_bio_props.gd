## 바이오 연구실: 전투 칸 바깥의 연결된 장식 받침에 고정 배치한다.
## 장식 칸은 VDMap에 추가하지 않으며 유닛 배치/이동/필드 기믹과 겹치지 않는다.
extends Node2D

const Terrain := preload("res://scripts/void_defense/vd_bio_terrain.gd")
const DEFINITIONS := [
	{"id": "chamber", "texture": preload("res://assets/void_defense_bio/props/prop_01_cultivation_chamber.png"), "size": Vector2i(2, 2), "anchor": Vector2(119.5, 255), "target": Vector2(0.70, 0.45)},
	{"id": "hydroponics", "texture": preload("res://assets/void_defense_bio/props/prop_02_hydroponic_rack.png"), "size": Vector2i(1, 2), "anchor": Vector2(119.5, 141), "target": Vector2(0.27, 0.45)},
	{"id": "cooler", "texture": preload("res://assets/void_defense_bio/props/prop_03_sample_cooler.png"), "size": Vector2i(1, 1), "anchor": Vector2(62.5, 121), "target": Vector2(0.88, 0.64)},
]
var items: Array[Dictionary] = []
var deck_material: Material
var _map: VDMap
var _terrain := Terrain.new()


func clear() -> void:
	for item in items:
		(item["holder"] as Node).queue_free()
	items.clear()


func set_deck_material(value: Material) -> void:
	deck_material = value
	for item in items:
		(item["deck"] as Node2D).material = value


func _cells(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in size.x:
		for y in size.y:
			out.append(origin + Vector2i(x, y))
	return out


func _center(cells: Array[Vector2i]) -> Vector2:
	var sum := Vector2.ZERO
	for cell in cells:
		sum += VDData.to_screen(Vector2(cell))
	return sum / cells.size()


func _sprite_rect(def: Dictionary, p: Vector2) -> Rect2:
	var texture: Texture2D = def["texture"]
	return Rect2(p - def["anchor"], texture.get_size())


func _occupied(cell: Vector2i) -> bool:
	if _map.tiles.has(cell):
		return true
	for item in items:
		if cell in item["cells"]:
			return true
	return false


func _outside_cells(map: VDMap, room_cells: Array[Vector2i]) -> Dictionary:
	var lo := room_cells[0]
	var hi := room_cells[0]
	for cell in room_cells:
		lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.y))
		hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.y))
	lo -= Vector2i(3, 3)
	hi += Vector2i(3, 3)
	var open: Array[Vector2i] = []
	var outside := {}
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			var cell := Vector2i(x, y)
			if (x == lo.x or x == hi.x or y == lo.y or y == hi.y) and not map.tiles.has(cell):
				outside[cell] = true
				open.append(cell)
	var i := 0
	while i < open.size():
		var cell := open[i]
		i += 1
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + step
			if next.x < lo.x or next.x > hi.x or next.y < lo.y or next.y > hi.y:
				continue
			if not map.tiles.has(next) and not outside.has(next):
				outside[next] = true
				open.append(next)
	return outside


func scatter_room(map: VDMap, room: Dictionary, delay := -1.0) -> void:
	_map = map
	var room_cells: Array[Vector2i] = []
	var room_rect := Rect2()
	for local: Vector2i in room["cells"]:
		var cell := VDMap.to_world(room, local.x, local.y)
		var p := VDData.to_screen(Vector2(cell))
		room_rect = Rect2(p, Vector2.ZERO) if room_cells.is_empty() else room_rect.expand(p)
		room_cells.append(cell)
	var outside := _outside_cells(map, room_cells)
	for def: Dictionary in DEFINITIONS:
		var exists := false
		for item in items:
			if item["room_id"] == room["id"] and item["id"] == def["id"]:
				exists = true
				break
		if exists:
			continue
		var best: Array[Vector2i] = []
		var best_score := INF
		var origins := {}
		var target := room_rect.position + room_rect.size * (def["target"] as Vector2)
		var size: Vector2i = def["size"]
		for edge in room_cells:
			# Exterior rear-facing edges, including stepped arms; enclosed pits stay empty.
			if outside.has(edge + Vector2i.LEFT):
				origins[Vector2i(edge.x - size.x, edge.y - size.y / 2)] = true
			if outside.has(edge + Vector2i.UP):
				origins[Vector2i(edge.x - size.x / 2, edge.y - size.y)] = true
		for origin: Vector2i in origins:
			var cells := _cells(origin, size)
			var valid := true
			var attached := false
			for cell in cells:
				if _occupied(cell) or not outside.has(cell):
					valid = false
					break
				for step in [Vector2i(1, 0), Vector2i(0, 1)]:
					var neighbor: Vector2i = cell + step
					if neighbor in room_cells:
						attached = true
			if not valid or not attached:
				continue
			var center := _center(cells)
			var rect := _sprite_rect(def, center)
			for item in items:
				if rect.grow(18).intersects(item["rect"]):
					valid = false
					break
			if not valid:
				continue
			var score := center.distance_squared_to(target)
			if score < best_score:
				best_score = score
				best = cells
		if not best.is_empty():
			_spawn(def, room["id"], best, delay)
	for item in items:
		(item["deck"] as Node2D).queue_redraw()


func _spawn(def: Dictionary, room_id: int, cells: Array[Vector2i], delay: float) -> void:
	var base := _center(cells)
	var holder := Node2D.new()
	holder.name = "%s_%d" % [def["id"], room_id]
	holder.position = base
	holder.use_parent_material = true
	add_child(holder)
	var deck := Node2D.new()
	deck.material = deck_material
	holder.add_child(deck)
	deck.draw.connect(_draw_deck.bind(deck, cells, base))
	var sprite := Sprite2D.new()
	sprite.texture = def["texture"]
	sprite.centered = false
	sprite.offset = -def["anchor"]
	sprite.use_parent_material = true
	holder.add_child(sprite)
	items.append({"id": def["id"], "room_id": room_id, "cells": cells, "holder": holder, "deck": deck, "sprite": sprite, "base": base, "rect": _sprite_rect(def, base)})
	if delay >= 0.0:
		holder.modulate.a = 0.0
		holder.position.y += 120.0
		var tw := holder.create_tween().set_parallel(true)
		tw.tween_property(holder, "position", base, 0.8).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(holder, "modulate:a", 1.0, 0.4).set_delay(delay)


func _draw_deck(node: Node2D, cells: Array[Vector2i], base: Vector2) -> void:
	var sorted := cells.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x + a.y < b.x + b.y)
	for cell: Vector2i in sorted:
		node.draw_set_transform(VDData.to_screen(Vector2(cell)) - base - VDBoard.TOP_CENTER)
		if not _occupied(cell + Vector2i(0, 1)):
			_terrain.draw_patch(node, VDBoard._left, "side_left_01")
		if not _occupied(cell + Vector2i(1, 0)):
			_terrain.draw_patch(node, VDBoard._right, "side_right_01")
		_terrain.draw_patch(node, VDBoard._top, "top_01")
	node.draw_set_transform(Vector2.ZERO)


func remove_near(new_cells: Array) -> void:
	for i in range(items.size() - 1, -1, -1):
		var hit := false
		for cell in items[i]["cells"]:
			if cell in new_cells:
				hit = true
				break
		if hit:
			# Remove immediately before newly walkable floor is revealed.
			(items[i]["holder"] as Node2D).visible = false
			(items[i]["holder"] as Node2D).queue_free()
			items.remove_at(i)
	for item in items:
		(item["deck"] as Node2D).queue_redraw()


func room_count(room_id: int) -> int:
	var count := 0
	for item in items:
		if item["room_id"] == room_id:
			count += 1
	return count


func frame_bounds(room: Dictionary) -> Rect2:
	var bounds := Rect2()
	var started := false
	for local: Vector2i in room["cells"]:
		var p := VDData.to_screen(Vector2(VDMap.to_world(room, local.x, local.y)))
		var tile := Rect2(p - VDBoard.TOP_CENTER, VDBoard.GROUND_SIZE)
		bounds = bounds.merge(tile) if started else tile
		started = true
	for item in items:
		if item["room_id"] != room["id"]:
			continue
		bounds = bounds.merge(item["rect"])
		for cell in item["cells"]:
			bounds = bounds.merge(Rect2(VDData.to_screen(Vector2(cell)) - VDBoard.TOP_CENTER, VDBoard.GROUND_SIZE))
	return bounds


## Keep props inside the HUD-free view; preserve the existing combat focus where possible.
func frame_camera(room: Dictionary, view: Vector2, desired: Vector2, zoom: float) -> Dictionary:
	var bounds := frame_bounds(room).grow(24)
	var safe := Rect2(view * Vector2(0.04, 0.15), view * Vector2(0.85, 0.66))
	var z := minf(zoom, minf(safe.size.x / bounds.size.x, safe.size.y / bounds.size.y))
	var lo := bounds.end - (safe.end - view * 0.5) / z
	var hi := bounds.position - (safe.position - view * 0.5) / z
	var position := Vector2(clampf(desired.x, lo.x, maxf(hi.x, lo.x)), clampf(desired.y, lo.y, maxf(hi.y, lo.y)))
	return {"position": position, "zoom": z}

