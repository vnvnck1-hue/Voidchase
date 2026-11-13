## 절차 생성 맵: 전투 방들이 복도로 이어진 그래프. 방을 클리어하면 출구(앞/옆)를 1~2개 생성한다.
## 방은 world 셀 좌표계 위에 놓이고, 방 안의 위치는 (a, c) = (진행 방향 거리, 가로 위치) 로컬 좌표로 다룬다.
##   world = origin + dir * a + across * c      (across 는 dir 에 수직, 양의 성분)
## 방 모양은 TEMPLATES 의 셀 마스크 중 하나를 무작위로 고른다 (문자: A 아군 배치 구역, E 적 등장 구역, . 바닥, 공백 없음).
## 모양마다 크기(길이 8~14 · 폭 4~10)가 다르다 (2026-11-11 형태 7종 추가). 방 사전의 len / wid / door_c / exit_c / side_a 를 쓴다:
##   입구는 (a=0, c=door..door+1), 앞 출구는 (a=len-1, c=exit..exit+1), 옆 출구는 (a=side_a 두 줄, c=0 / c=wid-1).
##   입구와 앞 출구에는 반드시 바닥이 있어야 한다 (validate()). 옆 출구는 바닥이 없으면 그쪽 길이 안 생길 뿐이다.
##   통로 폭은 2칸 이상으로 둔다: 대형 적(2x2)이 지나가야 한다. E 칸은 12개 이상 (한 웨이브 최대 10마리 + 여유).
## 필드 기믹 (2026-11-11): 방마다 바닥 몇 칸에 "amp" 증폭 패널 · "shock" 방전 격자를 깐다 (room["fields"], 동작은 vd_field_gimmicks.gd).
class_name VDMap
extends RefCounted

const ROOM_LEN := 10          # 기본 길이 (연구실 등 옛 코드 호환용. 실제 값은 room["len"])
const ROOM_WID := 8           # 기본 폭 (실제 값은 room["wid"])
const CORRIDOR_MIN := 4
const CORRIDOR_MAX := 8

## 행 = c, 열 = a. 한 모양 안에서 모든 행의 길이는 같다.
##   door: 입구 c (두 칸 중 작은 쪽) · exit: 앞 출구 c (없으면 door) · side_a: 옆 출구 a (없으면 len-4)
const TEMPLATES := {
	# 1) 전장: 10x6 직사각형. 입구 쪽 4열이 아군, 안쪽 2열이 적.
	"field": {"name": "전장", "door": 2, "rows": [
		"AAAA....EE",
		"AAAA....EE",
		"AAAA....EE",
		"AAAA....EE",
		"AAAA....EE",
		"AAAA....EE",
	]},
	# 2) 협곡: 10x8, 가운데(a 3~5)가 좁아진다. 아군은 입구 쪽 넓은 광장, 적은 반대편 넓은 광장에서 몰려와 좁은 목을 지난다.
	"canyon": {"name": "협곡", "door": 2, "rows": [
		"AAA   ..EE",
		"AAA.  ..EE",
		"AAAA....EE",
		"AAAA....EE",
		"AAAA....EE",
		"AAAA....EE",
		"AAA.  ..EE",
		"AAA   ..EE",
	]},
	# 3) 광장: 10x8, 모서리를 깎은 넓은 마당. 아군은 입구 쪽 작은 구역, 적은 위·아래 두 모서리 주머니에서 양쪽으로 등장.
	"plaza": {"name": "광장", "door": 2, "rows": [
		"   ..EEE  ",
		" ...EEEE. ",
		"AAA.......",
		"AAA.......",
		"AAA.......",
		"AAA.......",
		" ...EEEE. ",
		"   ..EEE  ",
	]},
	# 4) 결투장: 8x6 좁은 방. 시작부터 코앞이라 진형을 펼 틈이 없다.
	"arena": {"name": "결투장", "door": 2, "rows": [
		" AA..EE ",
		"AAA..EEE",
		"AAA..EEE",
		"AAA..EEE",
		"AAA..EEE",
		" AA..EE ",
	]},
	# 5) 긴 회랑: 14x4. 적이 멀리서 한 줄로 달려온다 — 원거리가 오래 쏠 수 있다.
	"hall": {"name": "긴 회랑", "door": 1, "rows": [
		"AAA........EEE",
		"AAA........EEE",
		"AAA........EEE",
		"AAA........EEE",
	]},
	# 6) 고리: 10x8, 한가운데가 뚫린 구덩이(2x4). 적이 위·아래 두 갈래로 돌아온다.
	"ring": {"name": "고리", "door": 3, "rows": [
		" AAA...EE ",
		"AAAA...EEE",
		"AAA.  ..EE",
		"AAA.  ..EE",
		"AAA.  ..EE",
		"AAA.  ..EE",
		"AAAA...EEE",
		" AAA...EE ",
	]},
	# 7) 쌍다리: 11x8, 두 섬을 다리 둘(각 2칸 폭)이 잇는다. 사이는 허공이라 원거리는 건너 쏘고, 근접은 다리로만 온다.
	"bridge": {"name": "쌍다리", "door": 3, "rows": [
		"AAA     EEE",
		"AAA.....EEE",
		"AAA.....EEE",
		"AAA     EEE",
		"AAA     EEE",
		"AAA.....EEE",
		"AAA.....EEE",
		"AAA     EEE",
	]},
	# 8) 기둥 광장: 12x10 가장 큰 방. 기둥 자리(2x2 구멍) 둘이 길을 세 갈래로 나눈다.
	"pillars": {"name": "기둥 광장", "door": 4, "rows": [
		"  AA.....E  ",
		" AAA.....EE ",
		"AAAA  ...EEE",
		"AAAA  ...EEE",
		"AAA......EEE",
		"AAA......EEE",
		"AAAA  ...EEE",
		"AAAA  ...EEE",
		" AAA.....EE ",
		"  AA.....E  ",
	]},
	# 9) 비탈: 10x8 사선. 아군은 아래 왼쪽, 적은 위 오른쪽 — 입구와 출구가 엇갈린다.
	"slope": {"name": "비탈", "door": 5, "exit": 1, "rows": [
		"     ..EEE",
		"    ...EEE",
		"   ....EEE",
		"  .....EEE",
		"AAA.....  ",
		"AAAA...   ",
		"AAAA..    ",
		"AAA..     ",
	]},
	# 10) 십자로: 11x9. 적이 앞·위·아래 세 팔 끝에서 한꺼번에 조여 온다. 옆 출구는 위·아래 팔 끝.
	"cross": {"name": "십자로", "door": 3, "side_a": 4, "rows": [
		"    EEE    ",
		"    ...    ",
		"   .....   ",
		"AAAA....EEE",
		"AAAA....EEE",
		"AAAA....EEE",
		"   .....   ",
		"    ...    ",
		"    EEE    ",
	]},
}
const SHAPE_NAMES := {
	"field": "전장", "canyon": "협곡", "plaza": "광장", "arena": "결투장", "hall": "긴 회랑",
	"ring": "고리", "bridge": "쌍다리", "pillars": "기둥 광장", "slope": "비탈", "cross": "십자로",
}

## 필드 기믹 종류와 이름 (동작·그림은 vd_field_gimmicks.gd).
const FIELD_NAMES := {"amp": "증폭 패널", "shock": "방전 격자"}

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
	var rows: Array = TEMPLATES[shape]["rows"]
	for c in rows.size():
		var row: String = rows[c]
		for a in row.length():
			var ch := row[a]
			if ch != " ":
				cells[Vector2i(a, c)] = ch
	return cells


## avoid 와 다른 모양을 고른다 (같은 모양이 연달아 나오지 않게).
func _random_shape(avoid := "") -> String:
	var keys := TEMPLATES.keys()
	keys.erase(avoid)
	return keys[rng.randi_range(0, keys.size() - 1)]


## shape 를 주면 그 모양으로 (연구실·쇼룸·테스트), 비우면 무작위.
func create_root(shape := "") -> Dictionary:
	return _add_room(Vector2i.ZERO, Vector2i(1, 0), [], shape if TEMPLATES.has(shape) else _random_shape())


static func shape_len(shape: String) -> int:
	return String(TEMPLATES[shape]["rows"][0]).length()


static func shape_door(shape: String) -> int:
	return int(TEMPLATES[shape]["door"])


## 모든 모양이 규칙을 지키는지 (행 길이 · 입구/앞 출구 바닥 · A 4칸 이상 · E 12칸 이상). 어긴 내용을 돌려준다 (테스트용).
static func validate() -> Array[String]:
	var bad: Array[String] = []
	for shape: String in TEMPLATES:
		var t: Dictionary = TEMPLATES[shape]
		var rows: Array = t["rows"]
		var n := shape_len(shape)
		for r: String in rows:
			if r.length() != n:
				bad.append("%s: row length" % shape)
		var cells := _template_cells(shape)
		var door := int(t["door"])
		var ex := int(t.get("exit", door))
		for k in 2:
			if not cells.has(Vector2i(0, door + k)):
				bad.append("%s: no floor at door" % shape)
			if not cells.has(Vector2i(n - 1, ex + k)):
				bad.append("%s: no floor at exit" % shape)
		var na := 0
		var ne := 0
		for l in cells:
			na += int(cells[l] == "A")
			ne += int(cells[l] == "E")
		if na < 4 or ne < 12:
			bad.append("%s: A=%d E=%d" % [shape, na, ne])
		if not SHAPE_NAMES.has(shape):
			bad.append("%s: no name" % shape)
	return bad


## 방의 필드 기믹 칸 (world 셀). kind = "amp" | "shock".
static func field_cells(room: Dictionary, kind: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var f: Dictionary = room.get("fields", {})
	for l: Vector2i in f:
		if f[l] == kind:
			out.append(to_world(room, l.x, l.y))
	return out


## 필드 기믹 배치: 증폭 패널은 아군 구역에 하나(넓은 방은 가운데 바닥에 하나 더), 방전 격자는 가운데 바닥에 2~5칸.
## 방마다 둘 중 하나는 꼭 있다. 첫 방은 둘 다 (소개).
func _roll_fields(cells: Dictionary, first: bool) -> Dictionary:
	var out := {}
	var a_cells: Array = []
	var mid: Array = []
	var keys := cells.keys()
	keys.sort()   # 사전 순서에 기대지 않는다: 같은 시드면 같은 배치
	for l: Vector2i in keys:
		if cells[l] == "A":
			a_cells.append(l)
		elif cells[l] == ".":
			mid.append(l)
	var want_amp := first or rng.randf() < 0.75
	var want_shock := first or rng.randf() < 0.75
	if not want_amp and not want_shock:
		if rng.randf() < 0.5:
			want_amp = true
		else:
			want_shock = true
	if want_amp and not a_cells.is_empty():
		out[a_cells[rng.randi_range(0, a_cells.size() - 1)]] = "amp"
		if mid.size() >= 30:
			out[mid[rng.randi_range(0, mid.size() - 1)]] = "amp"
	if want_shock and not mid.is_empty():
		var n := clampi(mid.size() / 7, 2, 5)
		for i in n * 4:
			if n <= 0:
				break
			var l: Vector2i = mid[rng.randi_range(0, mid.size() - 1)]
			if out.has(l):
				continue
			out[l] = "shock"
			n -= 1
	return out


func _add_room(origin: Vector2i, dir: Vector2i, corridor: Array, shape: String) -> Dictionary:
	var cells := _template_cells(shape)
	var room := {
		"id": rooms.size(), "origin": origin, "dir": dir, "across": across_of(dir),
		"shape": shape, "len": shape_len(shape), "wid": TEMPLATES[shape]["rows"].size(), "cells": cells,
		"door_c": shape_door(shape), "exit_c": int(TEMPLATES[shape].get("exit", shape_door(shape))),
		"exits": [], "cleared": false, "entry_corridor": corridor,
		"fields": _roll_fields(cells, rooms.is_empty()),
	}
	var sa: int = int(TEMPLATES[shape].get("side_a", int(room["len"]) - 4))
	room["side_a"] = [sa, sa + 1]
	for l in cells:
		tiles[to_world(room, l.x, l.y)] = {"kind": "room", "room": room["id"]}
	for cell in corridor:
		if not tiles.has(cell):   # 옛 방을 가로지르는 비상 복도(cross)는 이미 있는 바닥을 그대로 쓴다
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
	if room["exits"].is_empty():
		# 그래도 막혔으면 가장 작은 방(결투장)으로, 앞·양옆 어느 쪽이든 더 멀리까지
		var opts: Array = [{"kind": "forward"}]
		for s in sides:
			opts.append({"kind": "side", "side": s})
		for L in range(2, CORRIDOR_MAX + 40):
			for o: Dictionary in opts:
				var opt := o.duplicate()
				opt["len"] = L
				opt["shape"] = "arena"
				if _try_exit(room, opt):
					break
			if not room["exits"].is_empty():
				break
	if room["exits"].is_empty():
		# 사방이 옛 방으로 둘러싸였다 (깊은 판에서 드물게): 앞 복도가 옛 바닥을 가로질러 빈 곳까지 뻗는다. 반드시 성공한다
		for L in range(CORRIDOR_MIN, 400):
			if _try_exit(room, {"kind": "forward", "len": L, "shape": "arena", "cross": true}):
				break
	return room["exits"]


func _try_exit(room: Dictionary, opt: Dictionary) -> bool:
	var L: int = opt.get("len", rng.randi_range(CORRIDOR_MIN, CORRIDOR_MAX))
	var corridor: Array = []
	var new_origin: Vector2i
	var new_dir: Vector2i
	var cells: Dictionary = room["cells"]
	var len: int = room["len"]
	var shape: String = opt.get("shape", _random_shape(room["shape"]))
	var door := shape_door(shape)
	if opt["kind"] == "forward":
		var ec: int = room["exit_c"]
		for c in [ec, ec + 1]:
			if not cells.has(Vector2i(len - 1, c)):
				return false
		for i in L:
			for c in [ec, ec + 1]:
				corridor.append(to_world(room, len + i, c))
		new_dir = room["dir"]
		new_origin = to_world(room, len + L, ec - door)   # 새 방의 입구(c=door)가 이 방의 앞 출구 열과 이어진다
	else:
		var side: int = opt["side"]
		var side_a: Array = room["side_a"]
		for a: int in side_a:
			if not cells.has(Vector2i(a, side)):
				return false
		var sgn := 1 if side > 0 else -1
		for i in range(1, L + 1):
			for a: int in side_a:
				corridor.append(to_world(room, a, side + sgn * i))
		new_dir = room["across"] * sgn
		var entry_c := side + sgn * (L + 1)
		# 새 방의 입구 두 칸(c=door, door+1)이 이 방의 side_a 복도와 이어지도록 원점을 잡는다
		if across_of(new_dir) == room["dir"]:
			new_origin = to_world(room, int(side_a[0]) - door, entry_c)
		else:
			new_origin = to_world(room, int(side_a[1]) + door, entry_c)
	# 충돌 검사: 복도 셀과 새 방(+1칸 여백)이 기존 타일과 겹치면 포기
	for cell in corridor:
		if tiles.has(cell) and not opt.get("cross", false):
			return false
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
