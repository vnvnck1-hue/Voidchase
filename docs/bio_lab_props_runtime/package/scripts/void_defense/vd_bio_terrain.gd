## 승인 바이오 에셋을 현재 보드의 면별 폴리곤에 그린다.
## 그림을 늘린 단독 스프라이트를 배치하지 않고 기존 인접면 숨김/상승 경로를 사용한다.
extends RefCounted

const ATLAS := preload("res://assets/void_defense_bio/terrain/bio-lab-atlas.png")
const DEFINITION := preload("res://assets/void_defense_bio/terrain/bio-lab.json")
var _uvs: Dictionary = {}


func _init() -> void:
	var size := Vector2(ATLAS.get_size())
	for patch: Dictionary in DEFINITION.data["patches"]:
		var uv := PackedVector2Array()
		for point: Array in patch["atlas_points"]:
			uv.append(Vector2(point[0], point[1]) / size)
		_uvs[patch["name"]] = uv


func variant_of(cell: Vector2i) -> int:
	# 원화처럼 표식/배수구를 드물게 섞고 대각선 줄무늬 반복을 피한다.
	var h := posmod((cell.x * 73856093) ^ (cell.y * 19349663), 100)
	return 2 if h < 5 else (3 if h < 10 else 1)


func draw_cell(ci: CanvasItem, cell: Vector2i, alpha: float, draw_left: bool, draw_right: bool) -> void:
	var index := variant_of(cell)
	if draw_left:
		draw_patch(ci, VDBoard._left, "side_left_%02d" % index, alpha)
	if draw_right:
		draw_patch(ci, VDBoard._right, "side_right_%02d" % index, alpha)
	draw_patch(ci, VDBoard._top, "top_%02d" % index, alpha)


func draw_patch(ci: CanvasItem, points: PackedVector2Array, name: String, alpha := 1.0) -> void:
	ci.draw_polygon(points, PackedColorArray([Color(1.0, 1.0, 1.0, alpha)]), _uvs[name], ATLAS)

