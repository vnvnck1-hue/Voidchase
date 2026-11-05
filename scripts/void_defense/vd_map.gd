## 절차 생성 맵: 전투 방들이 복도로 이어진 그래프. 방을 클리어하면 출구(앞/옆)를 1~2개 생성한다.
## 방은 world 셀 좌표계 위에 놓이고, 방 안의 위치는 (a, c) = (진행 방향 거리, 가로 위치) 로컬 좌표로 다룬다.
##   world = origin + dir * a + across * c      (across 는 dir 에 수직, 양의 성분)
## 방 모양은 TEMPLATES 의 셀 마스크 3종 중 하나를 무작위로 고른다 (문자: A 아군 배치 구역, E 적 등장 구역, . 바닥, 공백 없음).
## 어느 모양이든 입구는 (a=0, c=2..3), 앞 출구는 (a=len-1, c=2..3), 옆 출구는 (a=6..7, c=0 / c=wid-1) 에 바닥이 있어야 한다.
class_name VDMap
extends RefCounted

const ROOM_LEN := 10          # 모든 템플릿의 진행 방향 길이 (a: 0..9)
const ROOM_WID := 8           # 템플릿 최대 폭 (프랍 흩뿌리기 등 바깥 둘레 계산용)
const CORRIDOR_MIN := 4
const CORRIDOR_MAX := 8
const FORWARD_C := [2, 3]     # 앞 복도가 지나는 c 열
const SIDE_A := [6, 7]        # 옆 복도가 붙는 a 행

## 행 = c, 열 = a. 모든 행의 길이는 ROOM_LEN.
const TEMPLATES := {
	# 1) 전장: 10x6 직사각형. 입구 쪽 4열이 아군, 안쪽 2열이 적.
	"field": [
		"AAAA....EE",
		"AAAA....EE",
		"AAAA....EE",
		"AAAA....EE",
		"AAAA....EE",
		"AAAA....EE",
	],
	# 2) 협곡: 10x8, 가운데(a 3~5)가 좁아진다. 아군은 입구 쪽 넓은 광장, 적은 반대편 넓은 광장에서 몰려와 좁은 목을 지난다.
	"canyon": [
		"AAA   ..EE",
		"AAA.  ..EE",
		"AAAA....EE",
		"AAAA....EE",
		"AAAA....EE",
		"AAAA....EE",
		"AAA.  ..EE",
		"AAA   ..EE",
	],
	# 3) 광장: 10x8, 모서리를 깎은 넓은 마당. 아군은 입구 쪽 작은 구역, 적은 위·아래 두 모서리 주머니에서 양쪽으로 등장.
	"plaza": [
		"   ..EEE  ",
		" ...EEEE. ",
		"AAA.......",
		"AAA.......",
		"AAA.......",
		"AAA.......",
		" ...EEEE. ",
		"   ..EEE  ",
	],
}
const SHAPE_NAMES := {"field": "전장", "canyon": "협곡", "plaza": "광장"}

var tiles := {}               # Vector2i -> {"kind": "room"|"corridor", "room": int}
var rooms: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()


static func across_of(dir: Vector2i) -> Vector2i:
	return Vector2i(absi(dir.y), absi(dir.x))


static func to_world(room: Dictionary, a: int, c: int) -> Vector2i:
	return room["origin"] + room["dir"] * a + room["across"] * c


## 소수 로컬 좌표(중심점 등)용.
static func to_world_f(room: Dictionary, a: float, c: float) -> Vector2:
	return Vector2(room["origin"]) + Vector2(room["dir"]) * a + Vector2(room["across"]) * c


static func to_local(room: Dictionary, cell: Vector2i) -> Vector2i:
	var v: Vector2i = cell - room["origin"]
	var d: Vector2i = room["dir"]
	var x: Vector2i = room["across"]
	return Vector2i(v.x * d.x + v.y * d.y, v.x * x.x + v.y * x.y)


static func in_room(room: Dictionary, cell: Vector2i) -> bool:
	return room["cells"].has(to_local(room, cell))


## 셀의 구역 문자: "A" 아군 배치, "E" 적 등장, "." 바닥, "" 방 밖.
static func zone(room: Dictionary, cell: Vector2i) -> String:
	return room["cells"].get(to_local(room, cell), "")


## 구역 문자가 z 인 로컬 셀 목록.
static func local_cells(room: Dictionary, z: String) -> Array:
	var out: Array = []
	for l in room["cells"]:
		if room["cells"][l] == z:
			out.append(l)
	return out


## local 에서 가장 가까운 z 구역 셀 (taken 에 있는 셀은 제외). 진형을 모양이 다른 방으로 옮길 때 쓴다.
static func nearest_zone_cell(room: Dictionary, local: Vector2i, z: String, taken: Dictionary = {}) -> Vector2i:
	if room["cells"].get(local, "") == z and not taken.has(local):
		return local
	var best := local
	var best_d := 1 << 30
	for l in local_cells(room, z):
		if taken.has(l):
			continue
		var d: int = absi(l.x - local.x) * 2 + absi(l.y - local.y)   # 진행 방향 차이를 더 무겁게: 앞뒤 자리를 지킨다
		if d < best_d:
			best_d = d
			best = l
	return best


static func center_f(room: Dictionary) -> Vector2:
	var sum := Vector2.ZERO
	for l in room["cells"]:
		sum += Vector2(l)
	var avg := sum / maxf(1.0, room["cells"].size())
	return to_world_f(room, avg.x, avg.y)


static func dir_label(dir: Vector2i) -> String:
	match dir:
		Vector2i(1, 0): return "↘"
		Vector2i(-1, 0): return "↖"
		Vector2i(0, 1): return "↙"
		Vector2i(0, -1): return "↗"
	return "?"


static func _template_cells(shape: String) -> Dictionary:
	var cells := {}
	var rows: Array = TEMPLATES[shape]
	for c in rows.size():
		var row: String = rows[c]
		for a in row.length():
			var ch := row[a]
			if ch != " ":
				cells[Vector2i(a, c)] = ch
	return cells


func _random_shape() -> String:
	var keys := TEMPLATES.keys()
	return keys[rng.randi_range(0, keys.size() - 1)]


func create_root() -> Dictionary:
	return _add_room(Vector2i.ZERO, Vector2i(1, 0), [], _random_shape())


func _add_room(origin: Vector2i, dir: Vector2i, corridor: Array, shape: String) -> Dictionary:
	var cells := _template_cells(shape)
	var room := {
		"id": rooms.size(), "origin": origin, "dir": dir, "across": across_of(dir),
		"shape": shape, "len": ROOM_LEN, "wid": TEMPLATES[shape].size(), "cells": cells,
		"exits": [], "cleared": false, "entry_corridor": corridor,
	}
	for l in cells:
		tiles[to_world(room, l.x, l.y)] = {"kind": "room", "room": room["id"]}
	for cell in corridor:
		tiles[cell] = {"kind": "corridor", "room": room["id"]}
	rooms.append(room)
	return room


## 방 클리어 후 호출: 출구 1~2개(앞 + 확률적으로 옆)를 만들고 다음 방까지 미리 깔아 둔다.
func generate_exits(room: Dictionary) -> Array:
	if not room["exits"].is_empty():
		return room["exits"]
	var sides := [0, int(room["wid"]) - 1]
	if rng.randf() < 0.5:
		sides.reverse()
	_try_exit(room, {"kind": "forward"})
	if rng.randf() < 0.7:
		_try_exit(room, {"kind": "side", "side": sides[0]})
	if room["exits"].is_empty():
		for s in sides:
			if _try_exit(room, {"kind": "side", "side": s}):
				break
	if room["exits"].is_empty():
		for L in range(CORRIDOR_MAX + 1, CORRIDOR_MAX + 14):
			if _try_exit(room, {"kind": "forward", "len": L}):
				break
	return room["exits"]


func _try_exit(room: Dictionary, opt: Dictionary) -> bool:
	var L: int = opt.get("len", rng.randi_range(CORRIDOR_MIN, CORRIDOR_MAX))
	var corridor: Array = []
	var new_origin: Vector2i
	var new_dir: Vector2i
	var cells: Dictionary = room["cells"]
	var len: int = room["len"]
	if opt["kind"] == "forward":
		for c in FORWARD_C:
			if not cells.has(Vector2i(len - 1, c)):
				return false
		for i in L:
			for c in FORWARD_C:
				corridor.append(to_world(room, len + i, c))
		new_dir = room["dir"]
		new_origin = to_world(room, len + L, 0)
	else:
		var side: int = opt["side"]
		for a in SIDE_A:
			if not cells.has(Vector2i(a, side)):
				return false
		var sgn := 1 if side > 0 else -1
		for i in range(1, L + 1):
			for a in SIDE_A:
				corridor.append(to_world(room, a, side + sgn * i))
		new_dir = room["across"] * sgn
		var entry_c := side + sgn * (L + 1)
		# 새 방의 c=2,3 이 이 방의 a=6,7 복도와 이어지도록 원점을 잡는다
		if across_of(new_dir) == room["dir"]:
			new_origin = to_world(room, SIDE_A[0] - 2, entry_c)
		else:
			new_origin = to_world(room, SIDE_A[1] + 2, entry_c)
	# 충돌 검사: 복도 셀과 새 방(+1칸 여백)이 기존 타일과 겹치면 포기
	for cell in corridor:
		if tiles.has(cell):
			return false
	var shape := _random_shape()
	var probe := {"origin": new_origin, "dir": new_dir, "across": across_of(new_dir)}
	for l in _template_cells(shape):
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if tiles.has(to_world(probe, l.x + d.x, l.y + d.y)):
				return false
	var new_room := _add_room(new_origin, new_dir, corridor, shape)
	room["exits"].append({
		"kind": opt["kind"], "corridor": corridor, "room_id": new_room["id"],
		"label": ("앞 " if opt["kind"] == "forward" else "옆 ") + dir_label(new_dir) + " · " + SHAPE_NAMES[shape],
	})
	return true
