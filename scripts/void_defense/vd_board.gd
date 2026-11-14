## VDMap의 방과 복도를 선택한 테마(공허 유적 / 사막 정거장)의 타일로 그린다.
## 현재 방에는 아군 배치 구역/적 스폰 구역 색을 깔고, 갈림길 선택 중엔 출구 복도를 빛나게 표시한다.
## 새로 생긴 방·복도 블록은 raise_tiles() 로 바닥 아래에서 무작위 시간차로 솟아오른다.
class_name VDBoard
extends Node2D

const FACE_H := VDData.TILE_W * VDDesertTerrain.FACE_RATIO
const HALF_W := VDData.TILE_W * 0.5
const HALF_H := VDData.TILE_H * 0.5
const GROUND_SIZE := Vector2(VDData.TILE_W, VDData.TILE_H + FACE_H)
const TOP_CENTER := Vector2(HALF_W, HALF_H)
var terrain := VDDesertTerrain.new()
var void_terrain := VDVoidTerrain.new()
const BioTerrain := preload("res://scripts/void_defense/vd_bio_terrain.gd")
var bio_terrain := BioTerrain.new()
var theme_id: int = VDWorldTheme.Kind.VOID
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

static var _top_outline := PackedVector2Array([_top[0], _top[1], _top[2], _top[3], _top[0]])

var map: VDMap
var current_room := {}
var placement_mode := true
var hover_cell := Vector2i(-1, -1)
var hover_valid := false
var hover_on := false
var exits: Array = []
var show_exits := false
var zone_k := 1.0               # 아군 배치·적 등장 구역 색 띠의 세기 (필드 연구실, vd_field_look.gd 의 tile/zone)
var exit_hover := -1           # 길 선택 버튼에 마우스를 올린 출구: 그 길만 밝게, 나머지는 흐리게

## 새 타일 솟아오르기: 셀 -> 시작 시각(_clock 기준). 끝난 셀은 지운다.
const RISE_SEC := 0.5
const RISE_DEPTH := 150.0     # 시작 깊이(px, 아래쪽)
const RISE_STAGGER := 0.035   # 기준점에서 한 칸 멀어질 때마다 늦어지는 시간
const RISE_JITTER := 0.3      # 블록마다 무작위로 더 늦어지는 시간(최대)
var _rise := {}
var _clock := 0.0

## 맵이 방마다 커지므로 블록 전체는 바뀔 때만 다시 그린다. 매 프레임 다시 그리는 것은 작은 층뿐:
##   보드 자신 = 솟아오르는 띠보다 뒤(깊이 x+y 작음) 블록, _mid = 솟아오르는 띠, _front = 띠보다 앞 블록 + 거점 깃발,
##   _overlay = 깜빡이는 출구 표시·드래그 커서. 깊이 순서는 층을 나눠도 그대로다.
var _mid: Node2D
var _front: Node2D
var _overlay: Node2D
var _band := Vector2i(1, 0)   # 솟아오르는 띠의 깊이 범위 [x, y] (x > y 면 없음)
## 깊이(x+y) 순으로 정렬한 셀 목록. 맵이나 타일 수가 바뀔 때만 다시 정렬한다 (타일은 늘기만 한다).
var _sorted_cells: Array = []
var _sorted_n := -1
var _sorted_map: VDMap


func _ready() -> void:
	_mid = _layer("RisingBand", _draw_cells.bind(1))
	_front = _layer("Front", _draw_front)
	_overlay = _layer("Overlay", _draw_overlay)
	# 필드 색 보정 재질(보드에 입힌다)은 블록 층만 따라간다. 출구 표시·드래그 커서(오버레이)는 원래 색 그대로
	_mid.use_parent_material = true
	_front.use_parent_material = true


func set_theme(value: int) -> void:
	theme_id = value
	queue_redraw()  # _draw()가 솟아오르는 띠·앞쪽 층도 같이 갱신한다.


func _layer(n: String, fn: Callable) -> Node2D:
	var l := Node2D.new()
	l.name = n
	l.draw.connect(fn)
	add_child(l)
	return l


## cells 를 바닥 아래에서 시간차로 솟아오르게 한다. from 에 가까운 블록부터, 조금씩 무작위로.
## 마지막 블록이 다 올라올 때까지 걸리는 시간(초)을 돌려준다.
func raise_tiles(cells: Array, from: Vector2i) -> float:
	var longest := 0.0
	for cell: Vector2i in cells:
		var delay: float = VDData.manhattan(cell, from) * RISE_STAGGER + randf() * RISE_JITTER
		_rise[cell] = _clock + delay
		longest = maxf(longest, delay + RISE_SEC)
	_update_band()
	queue_redraw()
	return longest


## 솟아오르는 블록 + 그 블록 때문에 옆면이 달라지는 위(y-1)·왼쪽(x-1) 이웃의 깊이 범위.
func _update_band() -> void:
	_band = Vector2i(1, 0)
	for cell: Vector2i in _rise:
		var d := cell.x + cell.y
		if _band.x > _band.y:
			_band = Vector2i(d - 1, d)
		else:
			_band = Vector2i(mini(_band.x, d - 1), maxi(_band.y, d))


## 0 = 띠 뒤(보드 자신), 1 = 띠(_mid), 2 = 띠 앞(_front). 띠가 없으면 모두 0.
func _layer_of(cell: Vector2i) -> int:
	if _band.x > _band.y:
		return 0
	var d := cell.x + cell.y
	return 0 if d < _band.x else (1 if d <= _band.y else 2)


## 살짝 튀어 오르는 ease-out-back (오버슈트 작게).
static func _ease_out_back(u: float) -> float:
	var c1 := 1.0
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(u - 1.0, 3) + c1 * pow(u - 1.0, 2)


func set_hover(c: Vector2i, valid: bool, on := true) -> void:
	hover_cell = c
	hover_valid = valid
	hover_on = on
	_overlay.queue_redraw()


func _draw() -> void:
	_draw_cells(0)
	# 다른 층도 보드 상태(블록, 현재 방, exits, show_exits)에 따라 함께 갱신
	_mid.queue_redraw()
	_front.queue_redraw()
	_overlay.queue_redraw()


## 띠 앞 블록 + 현재 방 입구의 거점 깃발.
func _draw_front() -> void:
	_draw_cells(2)
	if not current_room.is_empty():
		var f := VDData.to_screen(VDMap.to_world_f(current_room, -1.3, float(current_room.get("door_c", 2)) + 0.5))
		_front.draw_line(f, f + Vector2(0, -96), Color(0.82, 0.78, 0.92), 4.0)
		_front.draw_colored_polygon(PackedVector2Array([f + Vector2(0, -96), f + Vector2(56, -80), f + Vector2(0, -62)]), Color(0.55, 0.3, 0.88))
		_front.draw_string(VDData.font(), f + Vector2(-50, 24), "거점", HORIZONTAL_ALIGNMENT_CENTER, 100.0, 16, Color(0.9, 0.85, 1.0))


## layer 에 속한 블록만 ci 에 그린다 (_layer_of).
func _draw_cells(layer: int) -> void:
	if map == null:
		return
	var ci: CanvasItem = [self, _mid, _front][layer]
	var cur_id: int = current_room.get("id", -1)
	# 1)+2) 블록: 깊이(x+y) 순으로 옆면 → 윗면. 솟아오르는 중인 블록은 아래로 내려 그리고 옅게 한다.
	if map.tiles.size() != _sorted_n or map != _sorted_map:
		_sorted_cells = map.tiles.keys()
		_sorted_cells.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return p.x + p.y < q.x + q.y)
		_sorted_n = map.tiles.size()
		_sorted_map = map
	for cell: Vector2i in _sorted_cells:
		if _layer_of(cell) != layer:
			continue
		var lift := 0.0
		var alpha := 1.0
		if _rise.has(cell):
			var u: float = (_clock - _rise[cell]) / RISE_SEC
			if u < 0.0:
				continue  # 아직 솟아오르기 전: 안 보임
			lift = (1.0 - _ease_out_back(minf(u, 1.0))) * RISE_DEPTH
			alpha = clampf(u * 3.0, 0.0, 1.0)
		var c := VDData.to_screen(Vector2(cell)) + Vector2(0, lift)
		ci.draw_set_transform(c - TOP_CENTER)
		# 옆면: 아래쪽(y+1)·오른쪽(x+1) 이웃이 없거나, 어느 한쪽이 솟아오르는 중이라 높이가 다를 때
		var moving := _rise.has(cell)
		var n_down := cell + Vector2i(0, 1)
		var n_right := cell + Vector2i(1, 0)
		var left_exposed := not map.tiles.has(n_down)
		var right_exposed := not map.tiles.has(n_right)
		var draw_left := left_exposed or moving or _rise.has(n_down)
		var draw_right := right_exposed or moving or _rise.has(n_right)
		if theme_id == VDWorldTheme.Kind.VOID:
			void_terrain.draw_cell(ci, alpha, left_exposed, right_exposed, draw_left, draw_right,
				not map.tiles.has(cell + Vector2i.UP), not map.tiles.has(cell + Vector2i.LEFT))
		elif theme_id == VDWorldTheme.Kind.BIO:
			bio_terrain.draw_cell(ci, cell, alpha, draw_left, draw_right)
		else:
			if draw_left:
				terrain.draw_side(ci, _left, false, alpha)
			if draw_right:
				terrain.draw_side(ci, _right, true, alpha)
			terrain.draw_top(ci, _top, cell, alpha)
		var t: Dictionary = map.tiles[cell]
		if t["room"] == cur_id and t["kind"] == "room":
			var z := VDMap.zone(current_room, cell)
			if z == "A" and placement_mode:
				ci.draw_colored_polygon(_top, Color(0.5, 0.9, 1.0, 0.18 * alpha * zone_k))
				ci.draw_polyline(_top_outline, Color(0.65, 0.9, 1.0, minf(0.30 * alpha * zone_k, 1.0)), 1.0)
			elif z == "E":
				ci.draw_colored_polygon(_top, Color(1.0, 0.35, 0.5, 0.16 * alpha * zone_k))
	ci.draw_set_transform(Vector2.ZERO)


## 출구 표시(갈림길 선택 중, 깜빡임) + 드래그 중 대상 셀. 블록 위, 보드 좌표계 그대로.
func _draw_overlay() -> void:
	var o := _overlay
	# 1) 출구 표시 (갈림길 선택 중)
	if show_exits:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
		var t := Time.get_ticks_msec() / 1000.0
		for i in exits.size():
			var ex: Dictionary = exits[i]
			var hot := exit_hover == i
			var dim := exit_hover >= 0 and not hot
			var gold := Color(1.0, 0.95, 0.7) if hot else Color(1.0, 0.85, 0.35)
			var a := 0.35 if dim else 1.0
			var cells: Array = ex["corridor"]
			for j in cells.size():
				var cell: Vector2i = cells[j]
				var pts := VDData.diamond(VDData.to_screen(Vector2(cell)), 4.0)
				# 올린 길: 입구에서 출구 쪽으로 빛이 흘러간다
				var wave := 0.5 + 0.5 * sin(t * 8.0 - j * 0.9) if hot else pulse
				o.draw_colored_polygon(pts, Color(gold, (0.18 + 0.18 * wave + (0.25 if hot else 0.0)) * a))
				o.draw_polyline(pts, Color(gold, 0.9 * a), 3.5 if hot else 2.0)
			var first: Vector2i = cells[0]
			var p := VDData.to_screen(Vector2(first)) + Vector2(0, -40 - (8.0 + 4.0 * sin(t * 6.0) if hot else 0.0))
			o.draw_string(VDData.font(), p + Vector2(-80, 0), "길 %d  %s" % [i + 1, ex["label"]], HORIZONTAL_ALIGNMENT_CENTER, 160.0, 26 if hot else 22, Color(gold, a))
	# 2) 드래그 중 대상 셀
	if hover_on and hover_cell != Vector2i(-1, -1):
		var pts := VDData.diamond(VDData.to_screen(Vector2(hover_cell)), 3.0)
		var col := Color(0.5, 1.0, 1.0) if hover_valid else Color(1.0, 0.3, 0.3)
		o.draw_colored_polygon(pts, Color(col, 0.25))
		o.draw_polyline(pts, col, 3.0)


func _process(delta: float) -> void:
	_clock += delta
	if not _rise.is_empty():
		for cell in _rise.keys():
			if _clock - _rise[cell] >= RISE_SEC:
				_rise.erase(cell)
		if _rise.is_empty():
			_update_band()
			queue_redraw()       # 다 올라왔다: 띠를 없애고 한 번 전체를 다시 그린다
		else:
			_mid.queue_redraw()  # 솟아오르는 띠만
	# 깜빡이는 출구 표시는 오버레이만 다시 그린다 (맵 전체를 매 프레임 다시 그리던 것이 갈림길 렉의 원인)
	if show_exits:
		_overlay.queue_redraw()
