## VOID DEFENSE 칸 물리와 위치 보너스. VDBattle._apply_hit 이 피해 전에 flank() 를, 피해 뒤에 after_hit() 를 부른다.
##   측면·후방: 대상이 노리는 쪽의 반대편(등 뒤)에서 치면 x1.5 "후방 일격", 옆에서 치면 x1.2 "측면"
##   넉백: 기사는 세 번째 평타마다 강타로 적을 2칸, 공허 결정체·공허 군주는 매 타격 영웅을 1칸 밀어낸다
##   벽꿍: 밀려나다 방 벽에 막히면 추가 피해 + 기절 / 충돌: 다른 유닛에 부딪히면 둘 다 피해 + 짧은 기절
class_name VDImpact
extends RefCounted

const BACK_MULT := 1.5
const SIDE_MULT := 1.2
const BACK_DOT := -0.45        # 대상→공격자 와 대상→대상의 목표 사이 코사인이 이보다 작으면 등 뒤
const SIDE_DOT := 0.35         # 이보다 작으면 옆
const KNIGHT_EVERY := 3        # 기사: n 번째 평타마다 강타 넉백
const PUSH := {"knight": 2, "tank": 1, "boss": 1}
const PUSH_SEC := 0.09         # 한 칸 밀려나는 시간
const WALL_DMG := 0.7          # 벽꿍 피해 = 미는 쪽 공격력 x
const WALL_STUN := 0.8
const BUMP_DMG := 0.4          # 충돌 피해 (둘 다)
const BUMP_STUN := 0.3
const WALL_COL := Color(1.0, 0.78, 0.3)
const BUMP_COL := Color(1.0, 0.6, 0.45)
const BACK_COL := Color(1.0, 0.42, 0.7)
const SIDE_COL := Color(0.85, 0.7, 1.0)

var b: VDBattle
var count := {"back": 0, "side": 0, "push": 0, "wall": 0, "bump": 0}   # 테스트용
var _swings := {}              # instance id -> 기사 평타 수 (새 판마다 reset)


func _init(battle: VDBattle) -> void:
	b = battle


func reset() -> void:
	_swings.clear()


## 공격자 위치에 따른 피해 배율. 대상이 지금 노리는 상대가 없거나 공격자 자신이면 1.
func flank(u: VDUnit, target: VDUnit) -> float:
	var faced := b.tactics.target_of(target)
	if faced == null or faced == u:
		return 1.0
	var look := Vector2(faced.cell - target.cell)
	var from := Vector2(u.cell - target.cell)
	if look.length_squared() < 0.01 or from.length_squared() < 0.01:
		return 1.0
	var dot := look.normalized().dot(from.normalized())
	if dot < BACK_DOT:
		count["back"] += 1
		b.dmg_log.spawn_status(b._chest(target) + Vector2(0, -34), "후방 일격", BACK_COL, target)
		return BACK_MULT
	if dot < SIDE_DOT:
		count["side"] += 1
		b.dmg_log.spawn_status(b._chest(target) + Vector2(0, -34), "측면", SIDE_COL, target)
		return SIDE_MULT
	return 1.0


## 평타 명중 뒤: 넉백 판정.
func after_hit(u: VDUnit, target: VDUnit) -> void:
	if not target.alive or target.is_boss or target.size > 1:
		return
	var key := "boss" if u.is_boss else u.id
	if not PUSH.has(key):
		return
	if u.id == "knight":
		var id := u.get_instance_id()
		_swings[id] = int(_swings.get(id, 0)) + 1
		if int(_swings[id]) % KNIGHT_EVERY != 0:
			return
		b.juice.pop_world(b._chest(target) + Vector2(0, -80), "강타!", Color(0.6, 0.8, 1.0), 22.0, 0.15)
	push(u, target, _push_dir(u, target), int(PUSH[key]))


## target 을 dir 로 cells 칸 민다. 막히면 그 자리에서 벽꿍/충돌.
func push(src: VDUnit, target: VDUnit, dir: Vector2i, cells: int) -> void:
	if dir == Vector2i.ZERO or target.winding or target.casting:
		return
	var at := target.cell
	var blocked := ""
	var other: VDUnit = null
	for i in cells:
		var nc := at + dir
		if not VDMap.in_room(b.room, nc):
			blocked = "wall"
			break
		other = _unit_on(nc, target)
		if other != null:
			blocked = "bump"
			break
		at = nc
	if at != target.cell:
		count["push"] += 1
		var steps := VDData.manhattan(at, target.cell)
		target.knockback_to(at, PUSH_SEC * steps)
		b.vfx.spawn("dust", b.ground_fx, target.position, 1.1, 0.0, Color(1, 1, 1, 0.75))
	if blocked == "":
		return
	var delay := PUSH_SEC * maxf(1.0, VDData.manhattan(at, target.cell))
	var run := b._run_id
	await b.get_tree().create_timer(delay, false).timeout
	if run != b._run_id or not is_instance_valid(target) or not target.alive:
		return
	var at_px := b._chest(target) + Vector2(dir.x - dir.y, 0) * 30.0
	if blocked == "wall":
		count["wall"] += 1
		_slam_damage(src, target, src.atk * WALL_DMG, WALL_STUN)
		b.juice.pop_world(at_px + Vector2(0, -70), "벽꿍!", WALL_COL, 26.0, 0.2)
		b.vfx.spawn("hit_light", b.fx_root, at_px, 2.7, randf() * TAU, WALL_COL)
		b.shockwave.add(at_px, "heavy")
		b.camera.hitstop(0.08)
		b.camera.shake(0.35)
		b.audio.play("knight_hit", 0.05, -2.0, 0.8)
	elif is_instance_valid(other) and other.alive:
		count["bump"] += 1
		_slam_damage(src, target, src.atk * BUMP_DMG, BUMP_STUN)
		_slam_damage(src, other, src.atk * BUMP_DMG, BUMP_STUN)
		b.juice.pop_world(at_px + Vector2(0, -70), "충돌!", BUMP_COL, 24.0, 0.15)
		b.vfx.spawn("hit_light", b.fx_root, at_px, 1.6, randf() * TAU, BUMP_COL)
		b.shockwave.add(at_px, "light")
		b.camera.shake(0.25)
		b.audio.play("enemy_hit", 0.05)


func _slam_damage(src: VDUnit, t: VDUnit, amount: float, stun_sec: float) -> void:
	if not t.alive:
		return
	if is_instance_valid(src):
		t.last_hit_by = src
	var dealt := t.take_damage(amount)
	b.dmg_log.spawn(b._chest(t) + Vector2(0, -16), int(dealt), true, t)
	if t.alive:
		t.stun(stun_sec)


## 미는 쪽 → 대상 방향의 주된 축 한 칸.
static func _push_dir(u: VDUnit, target: VDUnit) -> Vector2i:
	var d := Vector2(target.cell - u.cell) + Vector2(target.size - u.size, target.size - u.size) * 0.5
	if absf(d.x) < 0.01 and absf(d.y) < 0.01:
		return Vector2i.ZERO
	if absf(d.x) >= absf(d.y):
		return Vector2i(int(signf(d.x)), 0)
	return Vector2i(0, int(signf(d.y)))


func _unit_on(c: Vector2i, except: VDUnit) -> VDUnit:
	for list in [b.allies, b.enemies]:
		var x := b._unit_at(c, list)
		if x != null and x != except:
			return x
	return null
