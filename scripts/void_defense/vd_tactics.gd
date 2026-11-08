## VOID DEFENSE 역할별 전투 AI: 누구를 노리고 어디로 걸을지 유닛 종류마다 다르게 정한다.
## VDBattle._tick_team 이 pick_target → retreat_cell → approach_cell 순서로 묻는다.
##   guard   (기사)            : 후열(원거리·힐러)을 노리는 적을 막으러 간다 · 옆에 붙은 적을 도발해 자기를 치게 한다
##   kite    (건너·마법사·포자·망루): 근접 적이 붙으면 한 칸 물러난다(재사용 대기) · 사거리 안에선 약한 적부터 마무리
##   support (힐러)            : 다친 아군 곁으로 간다 · 적이 붙으면 물러난다
##   flank   (공허 파편)        : 앞줄을 돌아 후열을 노린다 · 도발에 걸리지 않는다
##   charge  (공허 결정체)      : 기사에게 곧장 밀고 들어온다
##   brawl   (그 밖·보스)       : 가장 가까운 상대
class_name VDTactics
extends RefCounted

const ROLE := {
	"knight": "guard", "gunner": "kite", "mage": "kite", "healer": "support",
	"fast": "flank", "skirmisher": "kite", "longneck": "kite", "tank": "charge",
}
const KITE_CD := 2.4            # 한 번 물러난 뒤 다시 물러나기까지 (그 사이엔 그 자리에서 쏜다)
const GUARD_ALERT := 3          # 적이 후열 아군에서 이 거리 안이면 기사가 막으러 간다
const TAUNT_RANGE := 1          # 기사와 이 거리 안의 적은 기사를 친다
const FLANK_AVOID_COST := 4     # 측면 침투: 노리는 대상이 아닌 상대 옆 칸을 지나는 비용
const FLANK_BACKLINE_BONUS := 5 # 측면 침투: 후열 대상은 이만큼 가깝게 친다
const VOID_AVOID_COST := 6      # 영웅 길 찾기: 공허 오염(경고 포함) 칸을 지나는 비용
const DETOUR_MAX := 6          # 길 찾기 결과가 직선 거리보다 이만큼 넘게 길면 그냥 직진 (막혀 있으면 기다린다)
const TAUNT_TEXT_GAP := 3.0
const TAUNT_COL := Color(0.55, 0.75, 1.0)
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var b: VDBattle
var retreat_count := {}         # 테스트용: 유닛 id 별 물러난 횟수
var taunt_count := 0            # 테스트용: 도발로 대상이 기사로 바뀐 횟수
var _clock := 0.0               # 전투 시간 (게임 시간)
var _kite_ready := {}           # instance id -> 다시 물러날 수 있는 시각
var _taunt_shown := {}          # instance id -> 도발 글자를 띄운 시각
var _last_target := {}          # instance id -> 직전 대상 instance id


func _init(battle: VDBattle) -> void:
	b = battle


func tick(dt: float) -> void:
	_clock += dt


static func role_of(u: VDUnit) -> String:
	if u.is_boss:
		return "brawl"
	return ROLE.get(u.id, "brawl")


static func is_backline(u: VDUnit) -> bool:
	return u.attack_range > 1 or u.is_healer


## 공격 대상. mates 는 u 의 아군 목록.
func pick_target(u: VDUnit, foes: Array[VDUnit], mates: Array[VDUnit]) -> VDUnit:
	var role := role_of(u)
	var t: VDUnit = null
	if u.team == 1 and role != "flank":
		t = _taunter(u, foes)
	if t == null:
		match role:
			"guard":
				t = _threat_to_backline(u, foes, mates)
			"kite", "support":
				t = _weakest_in_range(u, foes)
			"flank":
				t = _flank_target(u, foes)
			"charge":
				t = _first_role(foes, "guard")
	if t == null:
		t = b._nearest(u, foes)
	_note_target(u, t)
	return t


## 근접 상대가 붙어 있고 물러날 수 있으면 물러날 칸, 아니면 u.cell.
func retreat_cell(u: VDUnit, foes: Array[VDUnit], target: VDUnit) -> Vector2i:
	if u.team == 0 and b.flow.is_hazard(u, u.cell):
		return _escape_void(u, foes, target)
	var role := role_of(u)
	if role != "kite" and role != "support":
		return u.cell
	if _clock < float(_kite_ready.get(u.get_instance_id(), 0.0)):
		return u.cell
	var cur := _safety(u, u.cell, foes)
	if cur > 1:
		return u.cell
	var best := u.cell
	var best_score := -1.0
	for dir: Vector2i in DIRS:
		var nc: Vector2i = u.cell + dir
		if not b._fits(u, nc):
			continue
		var s := _safety(u, nc, foes)
		if s <= cur:
			continue
		var score := float(s)
		if target != null and VDData.rect_dist(nc, u.size, target.cell, target.size) <= u.attack_range:
			score += 0.5   # 물러난 자리에서도 쏠 수 있으면 더 좋다
		if score > best_score:
			best_score = score
			best = nc
	if best != u.cell:
		_kite_ready[u.get_instance_id()] = _clock + KITE_CD
		retreat_count[u.id] = int(retreat_count.get(u.id, 0)) + 1
	return best


## 대상을 사거리에 넣을 수 있는 칸 쪽으로 한 칸 (다익스트라). 측면 침투는 다른 상대 옆을 돌아간다.
func approach_cell(u: VDUnit, target: VDUnit, foes: Array[VDUnit]) -> Vector2i:
	var avoid := role_of(u) == "flank" and target.team != u.team
	var start := u.cell
	var cost := {start: 0}
	var first := {start: start}
	var closed := {}
	var open: Array[Vector2i] = [start]
	while not open.is_empty():
		var bi := 0
		for i in range(1, open.size()):
			if cost[open[i]] < cost[open[bi]]:
				bi = i
		var c: Vector2i = open[bi]
		open.remove_at(bi)
		if closed.has(c):
			continue
		closed[c] = true
		if c != start and VDData.rect_dist(c, u.size, target.cell, target.size) <= u.attack_range:
			if int(cost[c]) > u.dist_to(target) + DETOUR_MAX:
				break
			return first[c]
		for dir: Vector2i in DIRS:
			var nc: Vector2i = c + dir
			if closed.has(nc) or not b._fits(u, nc):
				continue
			var nd: int = int(cost[c]) + 1
			if avoid and _near_other(u, nc, foes, target):
				nd += FLANK_AVOID_COST
			if u.team == 0 and b.flow.is_hazard(u, nc):
				nd += VOID_AVOID_COST
			if nd < int(cost.get(nc, 1 << 30)):
				cost[nc] = nd
				first[nc] = nc if c == start else first[c]
				open.append(nc)
	return b._step_toward(u, target)


# ---------------------------------------------------------------- targeting

## 옆에 붙은 기사 (도발). 대상이 기사로 바뀌는 순간 "도발" 글자를 띄운다.
func _taunter(u: VDUnit, foes: Array[VDUnit]) -> VDUnit:
	for f in foes:
		if f.alive and role_of(f) == "guard" and u.dist_to(f) <= TAUNT_RANGE:
			var id := u.get_instance_id()
			if _last_target.get(id, 0) != f.get_instance_id():
				taunt_count += 1
				if _clock - float(_taunt_shown.get(id, -99.0)) >= TAUNT_TEXT_GAP:
					_taunt_shown[id] = _clock
					b.dmg_log.spawn_status(b._chest(u), "도발", TAUNT_COL, u)
			return f
	return null


## 후열 아군에게 가장 바짝 다가온 적. 기사가 이미 근접전 중이면 후열이 실제로 맞을 때(붙었을 때)만 빠져나간다.
func _threat_to_backline(u: VDUnit, foes: Array[VDUnit], mates: Array[VDUnit]) -> VDUnit:
	var engaged := false
	for f in foes:
		if f.alive and u.dist_to(f) <= 1:
			engaged = true
			break
	var alert := 1 if engaged else GUARD_ALERT
	var best: VDUnit = null
	var best_s := 1 << 30
	for m in mates:
		if m == u or not m.alive or not is_backline(m):
			continue
		for f in foes:
			if not f.alive:
				continue
			var dm := m.dist_to(f)
			if dm > alert:
				continue
			var s := dm * 10 + u.dist_to(f)
			if s < best_s:
				best_s = s
				best = f
	return best


## 사거리 안에서 체력 비율이 가장 낮은 상대 (마무리). 없으면 null → 가장 가까운 상대.
func _weakest_in_range(u: VDUnit, foes: Array[VDUnit]) -> VDUnit:
	var best: VDUnit = null
	var best_r := 2.0
	for f in foes:
		if not f.alive or u.dist_to(f) > u.attack_range:
			continue
		var r := f.hp / f.max_hp
		if r < best_r:
			best_r = r
			best = f
	return best


func _flank_target(u: VDUnit, foes: Array[VDUnit]) -> VDUnit:
	var best: VDUnit = null
	var best_s := 1 << 30
	for f in foes:
		if not f.alive:
			continue
		var s := u.dist_to(f) - (FLANK_BACKLINE_BONUS if is_backline(f) else 0)
		if s < best_s:
			best_s = s
			best = f
	return best


func _first_role(foes: Array[VDUnit], role: String) -> VDUnit:
	for f in foes:
		if f.alive and role_of(f) == role:
			return f
	return null


func _note_target(u: VDUnit, t: VDUnit) -> void:
	_last_target[u.get_instance_id()] = t.get_instance_id() if t != null else 0


## u 가 직전에 노린 상대 (살아 있을 때만). 측면·후방 판정과 도약 착지 방향에 쓴다.
func target_of(u: VDUnit) -> VDUnit:
	var tid: int = _last_target.get(u.get_instance_id(), 0)
	if tid == 0:
		return null
	var t := instance_from_id(tid) as VDUnit
	return t if t != null and t.alive else null


## 영웅이 공허 오염 칸 위에 있으면 오염이 아닌 옆 칸으로 (근접 적에게서 먼 칸, 대상 사거리 안을 먼저).
func _escape_void(u: VDUnit, foes: Array[VDUnit], target: VDUnit) -> Vector2i:
	var best := u.cell
	var best_score := -INF
	for dir: Vector2i in DIRS:
		var nc: Vector2i = u.cell + dir
		if not b._fits(u, nc) or b.flow.is_hazard(u, nc):
			continue
		var score := float(mini(_safety(u, nc, foes), 3))
		if target != null and VDData.rect_dist(nc, u.size, target.cell, target.size) <= u.attack_range:
			score += 0.5
		if score > best_score:
			best_score = score
			best = nc
	return best


# ---------------------------------------------------------------- grid

## at 에 섰을 때 가장 가까운 근접 상대까지 거리 (근접 상대가 없으면 큰 값).
func _safety(u: VDUnit, at: Vector2i, foes: Array[VDUnit]) -> int:
	var m := 99
	for f in foes:
		if f.alive and f.attack_range <= 1:
			m = mini(m, VDData.rect_dist(at, u.size, f.cell, f.size))
	return m


func _near_other(u: VDUnit, at: Vector2i, foes: Array[VDUnit], target: VDUnit) -> bool:
	for f in foes:
		if f.alive and f != target and VDData.rect_dist(at, u.size, f.cell, f.size) <= 1:
			return true
	return false
