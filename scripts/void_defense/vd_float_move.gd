## 떠다니는 적(VDData.ENEMIES 의 "float": true — 공허 망령)의 이동. 타일에 묶이지 않고 방 위를 계속 위빙하며 떠다닌다.
##   - 위치는 화면 좌표로 연속으로 움직인다 (VDUnit.float_pos). 다른 유닛과 겹쳐도 된다 (VDBattle._occupied 가 떠 있는 유닛을 세지 않는다).
##   - 피격·사거리 판정에 쓰는 칸(VDUnit.cell)은 매 틱 지금 위치에서 다시 구한다 → 떠다니는 대로 밟고 있는 칸이 따라온다.
##   - 움직임: 목적지를 고르고 → 가속해 가고 → 잠깐 머물다 → 다시 고른다. 천천히 맴돌기(SLOW)와 휙 가로지르기(FAST)를 섞는다.
##     아군이 바짝 붙으면 멀리 휙 빠진다. 가는 동안에도 좌우·상하로 일렁이는 위빙을 얹는다 (빠를수록 진행 방향의 옆으로 크게).
##   - 촉수 난타를 쓰려는데 아군이 너무 가까우면 적당한 거리까지 먼저 물러난다 (back_off — VDEnemySkills 가 지시).
##   - 기절·순간이동 중에는 멈춘다 (active = false). 스킬 시전 중에는 느리게만 떠 있는다.
## VDBattle._tick_team 이 떠 있는 유닛마다 tick() 을 부른다. 순간이동은 warp() 로 자리를 옮긴다.
class_name VDFloatMove
extends RefCounted

const FAST_CHANCE := 0.4
const SLOW_SPEED := Vector2(48.0, 95.0)       # px/초 (최소, 최대)
const FAST_SPEED := Vector2(250.0, 360.0)
const SLOW_REACH := 3                          # 천천히 맴돌 때 한 번에 가는 거리 (칸)
const KEEP_AWAY := 3                           # 아군과 벌리고 싶은 거리 (칸)
const CROWDED := 1                             # 아군이 이 안으로 들어오면 휙 빠진다

var b: VDBattle
var fast_moves := 0               # 테스트용
var slow_moves := 0
var back_offs := 0                # 테스트용: 스킬을 쓰려고 물러난 횟수
var retreats := 0                 # 테스트용: 패링 돌진 예비로 물러난 횟수


func _init(battle: VDBattle) -> void:
	b = battle


func _state(u: VDUnit) -> Dictionary:
	if not u.has_meta("float_st"):
		u.float_pos = u.position
		u.set_meta("float_st", {"base": u.position, "vel": Vector2.ZERO, "dest": u.position, "wait": randf_range(0.1, 0.5),
			"speed": 40.0, "fast": false, "t": randf() * 20.0})
	return u.get_meta("float_st")


## 지금 위치(화면 좌표)에 선 footprint 의 최소 꼭짓점 칸.
static func cell_at(u: VDUnit, p: Vector2) -> Vector2i:
	var a := p.x / (VDData.TILE_W * 0.5)
	var c := p.y / (VDData.TILE_H * 0.5)
	var half := (u.size - 1) * 0.5
	return Vector2i(roundi((a + c) * 0.5 - half), roundi((c - a) * 0.5 - half))


## 순간이동: 떠 있는 기준 위치를 통째로 옮긴다.
func warp(u: VDUnit, to: Vector2) -> void:
	var st := _state(u)
	st["base"] = to
	st["dest"] = to
	st["vel"] = Vector2.ZERO
	st["wait"] = randf_range(0.5, 1.0)
	st["fast"] = false
	st.erase("force")
	u.float_pos = to
	u.position = to
	u.cell = cell_at(u, to)


func tick(u: VDUnit, dt: float, active: bool) -> void:
	var st := _state(u)
	st["t"] += dt
	var base: Vector2 = st["base"]
	var vel: Vector2 = st["vel"]
	var want := Vector2.ZERO
	if active or (st.get("force", false) and u.stun_timer <= 0.0):   # 패링 예비 물러나기(retreat)는 연습장의 적 행동 끔과 상관없이 움직인다
		var to: Vector2 = (st["dest"] as Vector2) - base
		var dist := to.length()
		if dist < 8.0:
			st["wait"] -= dt
			if st["wait"] <= 0.0 and not u.casting:
				_pick(u, st)
		else:
			var speed: float = st["speed"] * (0.35 if u.casting and not st.get("force", false) else 1.0)
			want = to / dist * speed * clampf(dist / 30.0, 0.45, 1.0)   # 다가가면 감속
	# 공격 모션(앞으로 찔렀다 돌아옴)이 위치를 쥐고 있는 동안은 기준 위치도 멈춘다 (끝났을 때 멀리 벌어져 튀지 않게)
	var held := u._anim_tween != null and u._anim_tween.is_running()
	vel = vel.lerp(want, 1.0 - exp(-dt * (7.0 if st["fast"] else 3.2)))
	if not held:
		base += vel * dt
	st["base"] = base
	st["vel"] = vel
	# 위빙: 느린 8자 일렁임 + 빠르게 갈 때는 진행 방향 옆으로 크게 흔들린다
	var t: float = st["t"]
	var k := clampf(vel.length() / FAST_SPEED.x, 0.0, 1.0)
	var off := Vector2(sin(t * 1.15) * 15.0 + sin(t * 2.7 + 1.3) * 5.0, sin(t * 0.9 + 0.6) * 7.0 + cos(t * 2.1) * 3.0) * (1.0 - 0.5 * k)
	if k > 0.02:
		off += vel.normalized().orthogonal() * sin(t * 7.5) * 16.0 * k
	if not active:
		off *= 0.25
	u.float_pos = base + off
	u.float_speed = k
	# 모션이 위치를 쥐고 있는 동안은 건드리지 않고, 끝나면 부드럽게 따라붙는다
	if not held:
		if u.position.distance_to(u.float_pos) > 60.0:
			# 다른 곳에서 옮겨 놓았다 (연습장에서 끌어 옮기기 등): 되돌리지 않고 그 자리에서 다시 떠다닌다
			warp(u, u.position)
		else:
			u.position = u.position.lerp(u.float_pos, 1.0 - exp(-dt * 20.0))
	# 판정 칸은 VDUnit._process 가 매 프레임 지금 보이는 자리에서 구한다 (전투 틱이 멈춰도 어긋나지 않게)
	u.queue_redraw()   # 발밑 칸 링이 밟은 칸을 따라가게
	# 가장 가까운 아군을 본다
	var foe := _nearest(u)
	if foe and absf(foe.position.x - u.position.x) > 12.0 and not u.winding:
		u.face(foe.position.x - u.position.x)


## 아군과 want 칸 이상 벌어지도록 물러나라는 지시 (촉수 난타를 쓰기 전). 이미 그만큼 떨어져 있으면 true.
## 너무 멀리 가지 않고 want ~ want + 2 칸인 자리 중 지금 자리에서 가장 가까운 곳으로 빠르게 간다. 한 번 지시하면 도착할 때까지 유지.
func back_off(u: VDUnit, want: int) -> bool:
	var st := _state(u)
	var here := cell_at(u, u.position)
	if _gap(u, here) >= want:
		st.erase("ordered")
		return true
	if st.has("ordered") and _gap(u, cell_at(u, st["dest"])) >= want:
		return false   # 가는 중 (목적지가 아직 충분히 멀다)
	var best := here
	var best_score := 1 << 30
	var far := here
	var far_gap := -1
	for local in b.room["cells"]:
		var at: Vector2i = VDMap.to_world(b.room, local.x, local.y)
		if not _in_room(u, at):
			continue
		var gap := _gap(u, at)
		if gap > far_gap:
			far_gap = gap
			far = at
		if gap < want or gap > want + 2:
			continue
		var score := VDData.manhattan(at, here)
		if score < best_score:
			best_score = score
			best = at
	if best == here:
		best = far   # 적당한 자리가 없으면 가장 먼 곳으로
	st["dest"] = u.foot_at(best)
	st["fast"] = true
	st["speed"] = FAST_SPEED.y
	st["wait"] = 0.15
	st["ordered"] = true
	back_offs += 1
	return false


## 패링 돌진 예비 (공허 응시자): from(노린 대상)에게서 곧장 멀어져 want px 만큼 거리를 벌린다. sec 초 안에 간다.
## 방 밖(필드 밖)으로 나가도 된다 — 돌진할 거리를 벌리는 것이 먼저다. 화면 위아래로는 덜 벗어나게 세로 성분을 눌러 준다.
## 시전 중 감속을 무시한다(force). 끝나면 돌진(VDParry._ram_dash)이 대상 앞으로 데려오고, 취소되면 다음 _pick 이 방 안으로 돌아오게 한다.
func retreat(u: VDUnit, from: Vector2, sec: float, want := 640.0) -> void:
	var st := _state(u)
	var away := u.position - from
	if away.length() < 1.0:
		away = Vector2(float(u._facing) * -1.0, 0.0)
	away = Vector2(away.x, away.y * 0.45)
	if absf(away.x) < 0.35 * away.length():
		away.x = (1.0 if away.x >= 0.0 else -1.0) * 0.35 * away.length()   # 거의 위아래로 겹쳐 있어도 옆으로 빠진다
	away = away.normalized()
	var best: Vector2 = from + away * maxf(want, u.position.distance_to(from))
	# 방 밖은 괜찮지만 화면 밖으로 사라지면 예비 동작이 안 보인다: 보이는 화면 안쪽(키 + 날아오를 높이만큼 여유)으로 당긴다
	var vp := b.get_viewport()
	if vp != null:
		var view: Rect2 = vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
		var top_room: float = absf(u._top) + VDParry.Fx.g("ram_rise") + 30.0
		if view.size.x > 520.0 and view.size.y > top_room + 80.0:
			best.x = clampf(best.x, view.position.x + 250.0, view.end.x - 250.0)
			best.y = clampf(best.y, view.position.y + top_room, view.end.y - 40.0)
	st["dest"] = best
	st["fast"] = true
	st["force"] = true
	st["speed"] = maxf(best.distance_to(st["base"]) / maxf(sec, 0.1) * 1.7, 90.0)
	st["wait"] = sec
	st.erase("ordered")
	retreats += 1


## 다음 목적지. 방 안(footprint 전부)이면 어디든 — 다른 유닛이 있어도 된다.
func _pick(u: VDUnit, st: Dictionary) -> void:
	st.erase("ordered")
	st.erase("force")
	var here := cell_at(u, st["base"])
	var crowded := _gap(u, here) <= CROWDED
	var fast := crowded or randf() < FAST_CHANCE
	var pool: Array[Vector2i] = []
	var fallback: Array[Vector2i] = []
	var best_gap := -1
	for local in b.room["cells"]:
		var at: Vector2i = VDMap.to_world(b.room, local.x, local.y)
		if at == here or not _in_room(u, at):
			continue
		var gap := _gap(u, at)
		var step := VDData.manhattan(at, here)
		fallback.append(at)
		if crowded:
			# 붙었으면 가장 먼 쪽으로
			if gap > best_gap:
				best_gap = gap
				pool = [at]
			elif gap == best_gap:
				pool.append(at)
		elif fast:
			if step >= 3 and gap >= KEEP_AWAY and gap <= u.attack_range:
				pool.append(at)
		elif step <= SLOW_REACH and gap >= mini(KEEP_AWAY, _gap(u, here)):
			pool.append(at)
	if pool.is_empty():
		pool = fallback
	if pool.is_empty():
		st["wait"] = 0.5
		return
	var at: Vector2i = pool.pick_random()
	st["dest"] = u.foot_at(at) + Vector2(randf_range(-22.0, 22.0), randf_range(-11.0, 11.0))
	st["fast"] = fast
	st["speed"] = randf_range(FAST_SPEED.x, FAST_SPEED.y) if fast else randf_range(SLOW_SPEED.x, SLOW_SPEED.y)
	st["wait"] = randf_range(0.25, 0.7) if fast else randf_range(0.0, 0.4)
	if fast:
		fast_moves += 1
	else:
		slow_moves += 1


func _in_room(u: VDUnit, at: Vector2i) -> bool:
	for c in u.footprint(at):
		if not VDMap.in_room(b.room, c):
			return false
	return true


func _gap(u: VDUnit, at: Vector2i) -> int:
	var gap := 99
	for a in b.allies:
		if a.alive:
			gap = mini(gap, VDData.rect_dist(at, u.size, a.cell, a.size))
	return gap


func _nearest(u: VDUnit) -> VDUnit:
	var best: VDUnit = null
	for a in b.allies:
		if a.alive and (best == null or a.position.distance_squared_to(u.position) < best.position.distance_squared_to(u.position)):
			best = a
	return best
