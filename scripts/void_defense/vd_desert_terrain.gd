## 사막 정거장 원화에서 그대로 잘라낸 면을 그린다.
## UV inset / 반전 / 재착색 / 중복 테두리 없이 원본의 두 옆면을 각각 사용한다.
class_name VDDesertTerrain
extends RefCounted

const ATLAS := preload("res://assets/void_defense_desert/terrain/desert-station-atlas.png")
const DEFINITION := preload("res://assets/void_defense_desert/terrain/desert-station.json")
const TOP_COUNT := 8
const FACE_RATIO := 0.4

var _uvs: Dictionary = {}


func _init() -> void:
	var size := Vector2(ATLAS.get_size())
	for patch: Dictionary in DEFINITION.data["patches"]:
		var uv := PackedVector2Array()
		for point: Array in patch["atlas_points"]:
			uv.append(Vector2(point[0], point[1]) / size)
		_uvs[patch["name"]] = uv


func draw_top(ci: CanvasItem, points: PackedVector2Array, cell: Vector2i, alpha: float) -> void:
	# 좌표로만 결정해 재그리기/방 이동/솟아오르기 중에도 표면이 바뀌지 않는다.
	var index := posmod(cell.x * 3 + cell.y * 5, TOP_COUNT) + 1
	draw_patch(ci, points, "top_%02d" % index, alpha)


func draw_side(ci: CanvasItem, points: PackedVector2Array, right: bool, alpha: float) -> void:
	draw_patch(ci, points, "side_right" if right else "side_left", alpha)


func draw_patch(ci: CanvasItem, points: PackedVector2Array, name: String, alpha := 1.0) -> void:
	ci.draw_polygon(points, PackedColorArray([Color(1.0, 1.0, 1.0, alpha)]), _uvs[name], ATLAS)
