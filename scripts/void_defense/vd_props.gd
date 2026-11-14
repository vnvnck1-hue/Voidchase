## VOID DEFENSE 그레이박스의 떠다니는 배경 프랍: 원화 조립 씬의 아치·기둥·바위·파편·깃발(VDRig.props())을
## 각 방 바닥 둘레의 허공에 흩뿌리고, 원화 조립 씬(vd_visual_idle.gd)과 같은 방식으로 위빙시킨다.
##   back  : 바닥보다 뒤(깊이 x+y 가 작은 쪽) — 보드보다 먼저 그려 바닥이 프랍 아래쪽을 가린다. 큰 프랍도 둔다.
##   front : 바닥보다 앞 — 유닛 위에 그려지므로 작은 파편·바위만, 바닥보다 낮게 띄운다.
## 새 방·복도가 프랍 자리를 지나가면 그 프랍은 사라진다(remove_near).
class_name VDProps
extends Node

const SCALE_MIN := 0.78
const SCALE_MAX := 1.02
const PER_ROOM := 14          # 방 하나당 프랍 수(자리가 모자라면 그보다 적게)
const RING := 4               # 방 바깥으로 몇 칸까지 둘지
const SPACING := 3            # 프랍끼리 최소 간격(맨해튼, 칸)
const SMALL_H := 100          # 텍스처 높이가 이보다 작으면 앞쪽에도 둘 수 있는 작은 프랍

var back := Node2D.new()
var front := Node2D.new()
var _defs: Array = []
var _items: Array[Dictionary] = []   # {holder, sprite, cell, kind, p, rot, skew}
var _t := 0.0


func _init() -> void:
	back.name = "PropsBack"
	front.name = "PropsFront"
	back.y_sort_enabled = true
	front.y_sort_enabled = true


func clear() -> void:
	for it in _items:
		(it["holder"] as Node).queue_free()
	_items.clear()


## room 둘레에 프랍을 흩뿌린다. delay >= 0 이면 그만큼 기다렸다가 아래에서 떠오르며 나타난다.
func scatter_room(map: VDMap, room: Dictionary, delay := -1.0) -> void:
	if _defs.is_empty():
		_defs = VDRig.props()
		if _defs.is_empty():
			return
	var small := _defs.filter(func(d: Dictionary) -> bool: return (d["texture"] as Texture2D).get_height() < SMALL_H)
	var cands: Array[Vector2i] = []
	for a in range(-RING, int(room.get("len", VDMap.ROOM_LEN)) + RING):
		for c in range(-RING, int(room.get("wid", VDMap.ROOM_WID)) + RING):
			var cell := VDMap.to_world(room, a, c)
			if not _near_tile(map, cell, 1):
				cands.append(cell)
	cands.shuffle()
	var placed := 0
	for cell in cands:
		if placed >= PER_ROOM:
			break
		if _crowded(cell):
			continue
		var behind := _is_behind(map, room, cell)
		var pool: Array = _defs if behind else small
		if pool.is_empty():
			continue
		_spawn(pool.pick_random(), cell, behind, delay)
		placed += 1


## 새 타일 cells 근처(2칸)에 걸린 프랍을 걷어낸다.
func remove_near(cells: Array) -> void:
	var hit_cells := {}
	for c in cells:
		hit_cells[c] = true
	for i in range(_items.size() - 1, -1, -1):
		var it: Dictionary = _items[i]
		var hit := false
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				if hit_cells.has(it["cell"] + Vector2i(dx, dy)):
					hit = true
		if hit:
			var h: Node2D = it["holder"]
			var t := h.create_tween()
			t.tween_property(h, "modulate:a", 0.0, 0.25)
			t.tween_callback(h.queue_free)
			_items.remove_at(i)


func _near_tile(map: VDMap, cell: Vector2i, r: int) -> bool:
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if map.tiles.has(cell + Vector2i(dx, dy)):
				return true
	return false


func _crowded(cell: Vector2i) -> bool:
	for it in _items:
		if VDData.manhattan(it["cell"], cell) < SPACING:
			return true
	return false


## 바닥보다 뒤에 있는지: 가장 가까운 방 타일보다 깊이(x+y)가 작으면 뒤.
func _is_behind(map: VDMap, room: Dictionary, cell: Vector2i) -> bool:
	var l := VDMap.to_local(room, cell)
	var near := VDMap.to_world(room, clampi(l.x, 0, int(room.get("len", VDMap.ROOM_LEN)) - 1), clampi(l.y, 0, int(room.get("wid", VDMap.ROOM_WID)) - 1))
	return cell.x + cell.y < near.x + near.y


func _spawn(def: Dictionary, cell: Vector2i, behind: bool, delay: float) -> void:
	var holder := Node2D.new()
	# 뒤쪽은 바닥 높이 근처, 앞쪽은 바닥보다 낮게 떠 있어 바닥·유닛을 덜 가린다
	var drop := randf_range(-10.0, 40.0) if behind else randf_range(40.0, 90.0)
	var base := VDData.to_screen(Vector2(cell)) + Vector2(0, drop)
	holder.position = base
	var sp := Sprite2D.new()
	sp.texture = def["texture"]
	sp.centered = false
	sp.offset = def["offset"]
	var s := randf_range(SCALE_MIN, SCALE_MAX)
	sp.scale = Vector2(s * (-1.0 if randf() < 0.4 else 1.0), s)
	sp.modulate = Color(0.92, 0.9, 1.0) if behind else Color(0.8, 0.76, 0.92)
	holder.use_parent_material = true   # 필드 색 보정 재질은 back / front 에 입힌다 (VDBattle.apply_field_look)
	sp.use_parent_material = true
	holder.add_child(sp)
	(back if behind else front).add_child(holder)
	var pname: String = def["name"]
	var kind := "banner" if pname == "star_banner" else "prop"
	_items.append({"holder": holder, "sprite": sp, "cell": cell, "kind": kind, "p": _params(pname), "rot": sp.rotation, "skew": sp.skew})
	if delay >= 0.0:
		holder.modulate.a = 0.0
		holder.position = base + Vector2(0, 120)
		var t := holder.create_tween().set_parallel(true)
		var d := delay + randf() * 0.4
		t.tween_property(holder, "position", base, 0.8).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(holder, "modulate:a", 1.0, 0.4).set_delay(d)


## vd_visual_idle.gd 의 _prop_params 와 같은 기준: 파편은 가볍게 크게, 돌은 중간, 아치·기둥은 아주 조금.
func _params(pname: String) -> Dictionary:
	var ph := randf()
	if pname.begins_with("chip"):
		return {"rot": 3.0, "bob": 5.0, "period": 2.6 + 1.2 * ph, "phase": ph}
	if pname.begins_with("rock"):
		return {"rot": 0.9, "bob": 2.5, "period": 3.6 + 1.6 * ph, "phase": ph}
	return {"rot": 0.45, "bob": 1.5, "period": 5.0 + 2.0 * ph, "phase": ph}


func _process(delta: float) -> void:
	_t += delta
	for it in _items:
		var sp: Sprite2D = it["sprite"]
		var p: Dictionary = it["p"]
		var ph: float = p["phase"] * TAU
		if it["kind"] == "banner":
			sp.skew = it["skew"] + 0.05 * sin(_t * 4.2 + ph) + 0.02 * sin(_t * 9.1 + ph)
			sp.rotation = it["rot"] + deg_to_rad(0.8) * sin(_t * 1.9 + ph)
		else:
			var w := TAU / float(p["period"])
			sp.rotation = it["rot"] + deg_to_rad(p["rot"]) * sin(_t * w + ph)
			sp.position = Vector2(0, p["bob"] * sin(_t * w * 0.7 + ph * 1.3))
