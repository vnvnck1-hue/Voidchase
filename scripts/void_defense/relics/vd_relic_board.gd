## 성좌판 상태: 10칸의 잠김/열림/침식과 올려 둔 유물(+회전), 보관함(tray). 그림·입력은 VDRelicHud, 발동은 VDRelicRuntime.
## 보관함에는 유물 id 와 "슬롯"(VDRelicData.SLOT_ID)이 섞여 들어간다. 슬롯은 잠긴 칸에 놓아 그 칸을 여는 데만 쓰고(unlock_from_tray), 열린 칸에는 못 놓는다.
## 전투 중에는 VDBattle 이 편집을 막는다 (여기서는 규칙만 검사한다).
## 소켓: 유물의 ports(변 0..5)를 회전만큼 돌린 것이 실제 소켓. 소켓이 이웃 유물에 닿으면 그 이웃이 port_effect 를 받고,
##       chain 유물은 소켓으로 이어진 유물의 발동을 받는다 (어느 쪽 소켓이든 닿으면 "연결").
class_name VDRelicBoard
extends RefCounted

signal changed
signal cell_fx(c: Vector2i, kind: String)   # 칸 연출: "unlock" · "corrupt" · "purify" · "place" · "rotate" (VDRelicHud 가 그린다)

enum Cell { LOCKED, OPEN, CORRUPT }

var cells := {}            # Vector2i -> Cell
var relics := {}           # Vector2i -> relic id (놓인 칸만)
var rots := {}             # Vector2i -> 회전 (0..5, 60° 단위)
var tray: Array[String] = []
var rng := RandomNumberGenerator.new()


func reset() -> void:
	cells.clear()
	relics.clear()
	rots.clear()
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


## 슬롯을 놓아 열 수 있는 칸인가 (잠긴 칸).
func can_unlock(c: Vector2i) -> bool:
	return cells.has(c) and cells[c] == Cell.LOCKED


func is_slot(i: int) -> bool:
	return i >= 0 and i < tray.size() and VDRelicData.is_slot(tray[i])


## 보관함의 슬롯 수.
func slot_count() -> int:
	var n := 0
	for id in tray:
		if VDRelicData.is_slot(id):
			n += 1
	return n


func locked_count() -> int:
	var n := 0
	for c in cells:
		if cells[c] == Cell.LOCKED:
			n += 1
	return n


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


# ---------------------------------------------------------------- sockets

func rot_of(c: Vector2i) -> int:
	return int(rots.get(c, 0))


## c 에 놓인 유물의 실제 소켓 방향들 (회전 적용).
func ports_of(c: Vector2i) -> Array[int]:
	var out: Array[int] = []
	var id := relic_at(c)
	if id == "":
		return out
	var r := rot_of(c)
	for d in VDRelicData.ports_of_def(id):
		out.append(posmod(int(d) + r, 6))
	return out


## c 의 소켓 하나가 nb 쪽 변에 있는가.
func port_to(c: Vector2i, nb: Vector2i) -> bool:
	for d in ports_of(c):
		if VDRelicData.neighbor_in(c, d) == nb:
			return true
	return false


## 두 유물이 소켓으로 이어져 있는가 (어느 쪽 소켓이든 상대 변에 닿으면).
func linked(a: Vector2i, b: Vector2i) -> bool:
	return relics.has(a) and relics.has(b) and (port_to(a, b) or port_to(b, a))


## c 와 소켓으로 이어진 이웃 유물 칸들.
func socket_links(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for nb in VDRelicData.neighbors(c):
		if linked(c, nb):
			out.append(nb)
	return out


## c 가 이웃의 소켓에서 받는 보정 합: {"haste": 가속, "power": 위력}. 이웃의 소켓이 c 쪽 변에 닿아야 받는다.
func socket_bonus(c: Vector2i) -> Dictionary:
	var out := {"haste": 0.0, "power": 0.0}
	for nb in VDRelicData.neighbors(c):
		if relics.has(nb) and port_to(nb, c):
			var ef := VDRelicData.port_effect_of(relics[nb])
			out["haste"] += float(ef.get("haste", 0.0))
			out["power"] += float(ef.get("power", 0.0))
	return out


# ---------------------------------------------------------------- edits

## 보관함 i번째 유물을 c 에 놓는다. 칸에 유물이 있으면 자리를 바꾼다. 새로 놓인 유물은 회전 0. 슬롯은 여기로 못 놓는다 (unlock_from_tray).
func place_from_tray(i: int, c: Vector2i) -> bool:
	if i < 0 or i >= tray.size() or not can_place(c) or is_slot(i):
		return false
	var id := tray[i]
	tray.remove_at(i)
	if relics.has(c):
		tray.insert(i, relics[c])
	relics[c] = id
	rots[c] = 0
	cell_fx.emit(c, "place")
	changed.emit()
	return true


## 보드 위 유물을 다른 칸으로 옮긴다 (유물이 있으면 맞바꾼다). 회전은 유물을 따라간다.
func move(from: Vector2i, to: Vector2i) -> bool:
	if not relics.has(from) or not can_place(to) or from == to:
		return false
	var id: String = relics[from]
	var r := rot_of(from)
	if relics.has(to):
		relics[from] = relics[to]
		rots[from] = rot_of(to)
	else:
		relics.erase(from)
		rots.erase(from)
	relics[to] = id
	rots[to] = r
	cell_fx.emit(to, "place")
	changed.emit()
	return true


## 60° × steps 회전 (유물이 있을 때만).
func rotate(c: Vector2i, steps := 1) -> bool:
	if not relics.has(c):
		return false
	rots[c] = posmod(rot_of(c) + steps, 6)
	cell_fx.emit(c, "rotate")
	changed.emit()
	return true


func to_tray(c: Vector2i) -> bool:
	if not relics.has(c):
		return false
	tray.append(relics[c])
	relics.erase(c)
	rots.erase(c)
	changed.emit()
	return true


func add_to_tray(id: String) -> void:
	tray.append(id)
	changed.emit()


## 보관함 i번째 슬롯을 잠긴 칸 c 에 놓아 연다 (유저 드래그). 슬롯이 아니거나 잠긴 칸이 아니면 거절.
func unlock_from_tray(i: int, c: Vector2i) -> bool:
	if not is_slot(i) or not can_unlock(c):
		return false
	tray.remove_at(i)
	cells[c] = Cell.OPEN
	cell_fx.emit(c, "unlock")
	changed.emit()
	return true


## 잠긴 칸 c 를 그냥 연다 (테스트·디버그용. 게임 흐름에서는 unlock_from_tray 만 쓴다).
func unlock_cell(c: Vector2i) -> bool:
	if not can_unlock(c):
		return false
	cells[c] = Cell.OPEN
	cell_fx.emit(c, "unlock")
	changed.emit()
	return true


## 보관함의 슬롯을 전부 뺀다 (더 열 칸이 없을 때 정수로 바꿔 주기 위해). 뺀 수를 돌려준다.
func take_slots() -> int:
	var n := 0
	var i := 0
	while i < tray.size():
		if VDRelicData.is_slot(tray[i]):
			tray.remove_at(i)
			n += 1
		else:
			i += 1
	if n > 0:
		changed.emit()
	return n


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
	cell_fx.emit(c, "corrupt")
	changed.emit()
	return c


func purify(c: Vector2i) -> bool:
	if state_of(c) != Cell.CORRUPT:
		return false
	cells[c] = Cell.OPEN
	cell_fx.emit(c, "purify")
	changed.emit()
	return true


## 놓인 유물 목록: [{cell, id, rot}] (보드 순서).
func placed() -> Array:
	var out := []
	for c in VDRelicData.BOARD_CELLS:
		if relics.has(c):
			out.append({"cell": c, "id": relics[c], "rot": rot_of(c)})
	return out
