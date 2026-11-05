## 성좌판 상태: 10칸의 잠김/열림/침식과 올려 둔 유물, 보관함(tray). 그림·입력은 VDRelicHud, 발동은 VDRelicRuntime.
## 전투 중에는 VDBattle 이 편집을 막는다 (여기서는 규칙만 검사한다).
class_name VDRelicBoard
extends RefCounted

signal changed

enum Cell { LOCKED, OPEN, CORRUPT }

var cells := {}            # Vector2i -> Cell
var relics := {}           # Vector2i -> relic id (놓인 칸만)
var tray: Array[String] = []
var rng := RandomNumberGenerator.new()


func reset() -> void:
	cells.clear()
	relics.clear()
	tray.clear()
	for i in VDRelicData.BOARD_CELLS.size():
		cells[VDRelicData.BOARD_CELLS[i]] = Cell.OPEN if i < VDRelicData.START_UNLOCKED else Cell.LOCKED
	for id in VDRelicData.STARTING_TRAY:
		tray.append(id)
	changed.emit()


# ---------------------------------------------------------------- queries

func state_of(c: Vector2i) -> Cell:
	return cells.get(c, Cell.LOCKED)


func is_open(c: Vector2i) -> bool:
	return state_of(c) == Cell.OPEN


func relic_at(c: Vector2i) -> String:
	return relics.get(c, "")


func can_place(c: Vector2i) -> bool:
	return is_open(c)


func open_count() -> int:
	var n := 0
	for c in cells:
		if cells[c] != Cell.LOCKED:
			n += 1
	return n


## 이웃 중 유물이 놓인 칸 수.
func adjacent_relics(c: Vector2i) -> int:
	var n := 0
	for nb in VDRelicData.neighbors(c):
		if relics.has(nb):
			n += 1
	return n


## 이웃 중 열려 있고 비어 있는 칸 수 (잠긴 칸·침식 칸은 세지 않는다).
func empty_neighbors(c: Vector2i) -> int:
	var n := 0
	for nb in VDRelicData.neighbors(c):
		if is_open(nb) and not relics.has(nb):
			n += 1
	return n


func corrupt_neighbors(c: Vector2i) -> int:
	var n := 0
	for nb in VDRelicData.neighbors(c):
		if state_of(nb) == Cell.CORRUPT:
			n += 1
	return n


## 같은 열 바로 위 칸에 유물이 있는가.
func relic_above(c: Vector2i) -> bool:
	return relics.has(Vector2i(c.x, c.y - 1))


## 성좌판 최상단 줄인가 (r == 0).
func is_top_row(c: Vector2i) -> bool:
	return c.y == 0


# ---------------------------------------------------------------- edits

## 보관함 i번째 유물을 c 에 놓는다. 칸에 유물이 있으면 자리를 바꾼다.
func place_from_tray(i: int, c: Vector2i) -> bool:
	if i < 0 or i >= tray.size() or not can_place(c):
		return false
	var id := tray[i]
	tray.remove_at(i)
	if relics.has(c):
		tray.insert(i, relics[c])
	relics[c] = id
	changed.emit()
	return true


## 보드 위 유물을 다른 칸으로 옮긴다 (유물이 있으면 맞바꾼다).
func move(from: Vector2i, to: Vector2i) -> bool:
	if not relics.has(from) or not can_place(to) or from == to:
		return false
	var id: String = relics[from]
	if relics.has(to):
		relics[from] = relics[to]
	else:
		relics.erase(from)
	relics[to] = id
	changed.emit()
	return true


func to_tray(c: Vector2i) -> bool:
	if not relics.has(c):
		return false
	tray.append(relics[c])
	relics.erase(c)
	changed.emit()
	return true


func add_to_tray(id: String) -> void:
	tray.append(id)
	changed.emit()


## 잠긴 칸을 위에서부터 n개 연다. 실제로 연 수를 돌려준다.
func unlock(n: int) -> int:
	var opened := 0
	for c in VDRelicData.BOARD_CELLS:
		if opened >= n:
			break
		if cells[c] == Cell.LOCKED:
			cells[c] = Cell.OPEN
			opened += 1
	if opened > 0:
		changed.emit()
	return opened


func corrupt_count() -> int:
	var n := 0
	for c in cells:
		if cells[c] == Cell.CORRUPT:
			n += 1
	return n


## 열려 있고 비어 있는 칸 하나를 침식시킨다. 침식된 칸을 돌려준다 (없으면 (-1,-1)).
func corrupt_random() -> Vector2i:
	if corrupt_count() >= VDRelicData.CORRUPT_MAX:
		return Vector2i(-1, -1)
	var pool: Array[Vector2i] = []
	for c in VDRelicData.BOARD_CELLS:
		if cells[c] == Cell.OPEN and not relics.has(c):
			pool.append(c)
	if pool.is_empty():
		return Vector2i(-1, -1)
	var c: Vector2i = pool[rng.randi() % pool.size()]
	cells[c] = Cell.CORRUPT
	changed.emit()
	return c


func purify(c: Vector2i) -> bool:
	if state_of(c) != Cell.CORRUPT:
		return false
	cells[c] = Cell.OPEN
	changed.emit()
	return true


## 놓인 유물 목록: [{cell, id}] (보드 순서).
func placed() -> Array:
	var out := []
	for c in VDRelicData.BOARD_CELLS:
		if relics.has(c):
			out.append({"cell": c, "id": relics[c]})
	return out
