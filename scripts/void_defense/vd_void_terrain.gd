## 기존 공허 타일의 UV·아치 반전·그림자·외곽 덧그리기를 그대로 보존한다.
class_name VDVoidTerrain
extends RefCounted

const BASE_TILE := preload("res://assets/void_defense_original/background/terrain/violet-ruins-base-tile.png")
const EDGE_TILE := preload("res://assets/void_defense_original/background/terrain/violet-ruins-edge-tile.png")
const FACE_H := 44.0 * VDData.TILE_SCALE
const HALF_W := VDData.TILE_W * 0.5
const HALF_H := VDData.TILE_H * 0.5
const GROUND_SIZE := Vector2(VDData.TILE_W, VDData.TILE_H + FACE_H)
const TOP_CENTER := Vector2(HALF_W, HALF_H)
const RIM_REACH := 0.48

static var _top := PackedVector2Array([
	Vector2(HALF_W, 0), Vector2(VDData.TILE_W, HALF_H),
	Vector2(HALF_W, VDData.TILE_H), Vector2(0, HALF_H),
])
static var _left := PackedVector2Array([
	Vector2(0, HALF_H), Vector2(HALF_W, VDData.TILE_H),
	Vector2(HALF_W, GROUND_SIZE.y), Vector2(0, HALF_H + FACE_H),
])
static var _right := PackedVector2Array([
	Vector2(HALF_W, VDData.TILE_H), Vector2(VDData.TILE_W, HALF_H),
	Vector2(VDData.TILE_W, HALF_H + FACE_H), Vector2(HALF_W, GROUND_SIZE.y),
])
static var _top_uv := _face_uv(_top, 0.04)
static var _left_uv := _face_uv(_left, 0.09)
static var _right_uv := _face_uv(_right, 0.09)
static var _edge_right_uv := PackedVector2Array([_left_uv[1], _left_uv[0], _left_uv[3], _left_uv[2]])
static var _rim_uv := _rim_strip(_top_uv, 2, TOP_CENTER / GROUND_SIZE)
static var _outline := PackedVector2Array([_top[0], _top[1], _top[2], _top[3], _top[0]])


static func _face_uv(points: PackedVector2Array, inset: float) -> PackedVector2Array:
	var center := (points[0] + points[2]) * 0.5
	var uv := PackedVector2Array()
	for p in points:
		uv.append(p.lerp(center, inset) / GROUND_SIZE)
	return uv


static func _rim_strip(points: PackedVector2Array, edge: int, center: Vector2) -> PackedVector2Array:
	var a := points[edge]
	var b := points[(edge + 1) % 4]
	return PackedVector2Array([a, b, b.lerp(center, RIM_REACH), a.lerp(center, RIM_REACH)])


func _draw_rim(ci: CanvasItem, edge: int, alpha: float) -> void:
	var fade := PackedColorArray([Color(1.0, 1.0, 1.0, alpha), Color(1.0, 1.0, 1.0, alpha),
		Color(1.0, 1.0, 1.0, 0.0), Color(1.0, 1.0, 1.0, 0.0)])
	ci.draw_polygon(_rim_strip(_top, edge, TOP_CENTER), fade, _rim_uv, EDGE_TILE)


func draw_cell(ci: CanvasItem, alpha: float, left_exposed: bool, right_exposed: bool,
		draw_left: bool, draw_right: bool, back_right_exposed: bool, back_left_exposed: bool) -> void:
	var tint := PackedColorArray([Color(1.0, 1.0, 1.0, alpha)])
	if draw_left:
		ci.draw_polygon(_left, tint, _left_uv, EDGE_TILE if left_exposed else BASE_TILE)
	if right_exposed:
		ci.draw_polygon(_right, PackedColorArray([Color(0.78, 0.74, 0.84, alpha)]), _edge_right_uv, EDGE_TILE)
	elif draw_right:
		ci.draw_polygon(_right, tint, _right_uv, BASE_TILE)
	ci.draw_polygon(_top, tint, _top_uv, BASE_TILE)
	if back_right_exposed:
		_draw_rim(ci, 0, alpha)
	if right_exposed:
		_draw_rim(ci, 1, alpha)
	if left_exposed:
		_draw_rim(ci, 2, alpha)
	if back_left_exposed:
		_draw_rim(ci, 3, alpha)
	ci.draw_polyline(_outline, Color(0.25, 0.17, 0.32, 0.82 * alpha), 1.5, true)
