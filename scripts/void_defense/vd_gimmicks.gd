## 기믹 무리 행동 (TrioChess specials.gd 닌자·질주꾼·분열체 + main.gd 히드라·환술사 이식, 2026-11-08).
## VDBattle._tick_team 이 적마다 tick() 을, _on_unit_died 가 on_enemy_died() 를 부른다. 구성은 VDData.GIMMICKS.
##   균열 암살자: 가장 먼 영웅을 노리고, 사거리 밖이면 ASSASSIN_CD 마다 그 곁 빈 칸으로 도약(0.32초). 착지하면 바로 때린다.
##   공허 추적자: 걷지 않고 SPRINT_CD 마다 최대 SPRINT_DIST 칸을 0.18초에 질주. 재사용 대기 중엔 제자리에서 기다린다.
##   분열 잔재  : 쓰러지면 옆 빈 칸에 소잔재 2 (현재 웨이브 배율).
##   공허 촉수  : 쓰러지고 HYDRA_REVIVE 초 뒤 체력 가득 부활 (부활마다 능력치 +20%, 5번째에 ×2). 네 머리가 동시에 쓰러져 있으면 그대로 처치.
##   환영       : 환술사가 살아 있는 동안 immune (피해 0, IMMUNE 글자). 환술사가 쓰러지면 풀리고 또렷해진다.
## class_name 없음: 헤드리스 실행이 전역 클래스 캐시를 갱신하지 않으므로 preload 해서 쓴다.
extends RefCounted

const ASSASSIN_CD := 1.7
const ASSASSIN_HOP := 0.32
const ASSASSIN_HEIGHT := 90.0
const SPRINT_CD := 0.76
const SPRINT_DIST := 2
const SPRINT_SEC := 0.18
const SPLIT_COUNT := 2
const HYDRA_REVIVE := 2.0
## 촉수는 되살아날 때마다 처음 능력치(체력·공격력)의 HYDRA_GROW 씩 더 강해진다: 5번째 부활에 ×2 (2026-11-12).
## 동시 처치를 못 하는 전력이면 전투가 끝없이 늘어나던 문제 → 버틸수록 압박이 커져 결판이 난다. 상한 없음.
const HYDRA_GROW := 0.2
const HYDRA_COL := Color(0.85, 0.45, 1.0)
const ASSASSIN_COL := Color(0.75, 0.35, 0.95)

var b: VDBattle
var count := {"blink": 0, "dash": 0, "split": 0, "revive": 0, "immune_hits": 0, "hydra_clear": 0}   # 테스트용
var _ready_at := {}        # instance id -> 다음 행동 가능 시각 (게임 시간)
var _clock := 0.0
var _hydra_pending := {}   # instance id -> true (부활 대기 중)


func _init(battle: VDBattle) -> void:
	b = battle


## 전투 시작 (스테이지마다).
func begin() -> void:
	_ready_at.clear()
	_hydra_pending.clear()
	_clock = 0.0


## 매 물리 틱: 시계 + 환영 무적 갱신.
func tick_clock(dt: float) -> void:
	_clock += dt
	update_immunity()


## 적 하나의 특수 이동. 그 틱의 일반 이동·공격을 건너뛰어야 하면 true.
func tick(u: VDUnit, _dt: float) -> bool:
	match u.id:
		"assassin":
			return _tick_assassin(u)
		"sprinter":
			return _tick_sprinter(u)
	return false


# ---------------------------------------------------------------- 균열 암살자

func farthest_hero(u: VDUnit) -> VDUnit:
	var best: VDUnit = null
	var best_d := -1
	for a in b.allies:
		if not a.alive:
			continue
		var d := u.dist_to(a)
		if d > best_d:
			best_d = d
			best = a
	return best


func _tick_assassin(u: VDUnit) -> bool:
	var t := farthest_hero(u)
	if t == null or u.dist_to(t) <= u.attack_range:
		return false
	var key := u.get_instance_id()
	if _clock < float(_ready_at.get(key, 0.0)):
		return true   # 균열이 다시 열릴 때까지 제자리
	var land := _cell_beside(t, u)
	if land.x == -999:
		return true
	_ready_at[key] = _clock + ASSASSIN_CD
	count["blink"] += 1
	u.casting = true
	u.move_timer = 0.0
	b.vfx.spawn("dash", b.ground_fx, u.position, 1.1, 0.0, ASSASSIN_COL, Vector2.ONE, VDData.to_screen(Vector2(land)).x < u.position.x)
	b.vfx.spawn("burst", b.fx_root, b._chest(u), 0.35, 0.0, ASSASSIN_COL)
	b.audio.play("whoosh", 0.03, 2.0, 1.3)
	var uref: WeakRef = weakref(u)
	var tw := u.leap_to(land, ASSASSIN_HOP, ASSASSIN_HEIGHT)
	tw.finished.connect(func() -> void:
		var u2 := uref.get_ref() as VDUnit
		if u2 == null:
			return
		u2.casting = false
		u2.atk_timer = u2.atk_cd * u2.atk_cd_mult()   # 착지 즉시 공격
		b.vfx.spawn("dust", b.ground_fx, u2.position, 0.9, 0.0, Color(0.8, 0.6, 1.0, 0.8)))
	return true


## 대상 t 의 footprint 둘레 빈 칸 중 u 에게 가장 가까운 칸 (없으면 (-999,-999)).
func _cell_beside(t: VDUnit, u: VDUnit) -> Vector2i:
	var best := Vector2i(-999, -999)
	var best_d := 1 << 30
	for fc in t.footprint():
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c: Vector2i = fc + d
			if not b._fits(u, c) or t.occupies(c):
				continue
			var dd := VDData.manhattan(c, u.cell)
			if dd < best_d:
				best_d = dd
				best = c
	return best


# ---------------------------------------------------------------- 공허 추적자

func _tick_sprinter(u: VDUnit) -> bool:
	var t := b.tactics.pick_target(u, b.allies, b.enemies)
	if t == null or u.dist_to(t) <= u.attack_range:
		return false
	var key := u.get_instance_id()
	if _clock < float(_ready_at.get(key, 0.0)):
		return true   # 숨 고르기: 제자리
	# 접근 경로를 두 칸 앞서 본다 (칸을 임시로 옮겨 다음 칸을 묻는다)
	var start := u.cell
	var dest := start
	for i in SPRINT_DIST:
		var nx := b.tactics.approach_cell(u, t, b.allies)
		if nx == u.cell:
			break
		dest = nx
		u.cell = nx
	u.cell = start
	if dest == start:
		return true
	_ready_at[key] = _clock + SPRINT_CD
	count["dash"] += 1
	u.move_timer = 0.0
	b.vfx.spawn("dash", b.ground_fx, u.position, 1.3, 0.0, Color(1.0, 0.7, 0.95), Vector2.ONE, VDData.to_screen(Vector2(dest)).x < u.position.x)
	b.audio.play("whoosh", 0.05, -4.0, 1.6)
	u.move_to_cell(dest, SPRINT_SEC)
	return true


# ---------------------------------------------------------------- 사망 기믹

## 적이 쓰러졌다. true 를 돌려주면 "임시 사망"(공허 촉수 부활 대기): 정수·경험치·웨이브 클리어로 세지 않는다.
func on_enemy_died(u: VDUnit) -> bool:
	match u.id:
		"splitter":
			_split(u)
		"hydra":
			return _hydra_died(u)
		"illusionist":
			update_immunity()
	return false


func _split(u: VDUnit) -> void:
	var mult: float = b.wave_mult
	var cells := _free_around(u.cell, SPLIT_COUNT)
	for c in cells:
		var e := b._make_unit(VDData.ENEMIES["splitling"], "splitling", 1, c, mult * 0.7, b.wave_atk_mult)
		e.show_bar = true
		e.casting = true
		e.scale = Vector2(0.3, 0.3)
		var tw := e.create_tween()
		tw.tween_property(e, "scale", Vector2(1.15, 0.85), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(e, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void: e.casting = false)
		b.enemies.append(e)
		b.vfx.spawn("burst", b.fx_root, b._chest(e), 0.3, 0.0, Color(0.8, 0.6, 1.0))
		count["split"] += 1
	if not cells.is_empty():
		b.audio.play("enemy_spawn", 0.05, -4.0, 1.4)
		b.dmg_log.spawn_status(b._chest(u) + Vector2(0, -20), "분열!", Color(0.9, 0.7, 1.0), u)


## c 둘레(가까운 순) 빈 칸 n 개 (방 안, 다른 유닛 없음).
func _free_around(c: Vector2i, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in range(1, 4):
		var ring: Array[Vector2i] = []
		for a in range(-r, r + 1):
			for s in range(-r, r + 1):
				if maxi(absi(a), absi(s)) != r:
					continue
				var cc := c + Vector2i(a, s)
				if VDMap.in_room(b.room, cc) and not b._occupied(cc):
					ring.append(cc)
		ring.shuffle()
		for cc in ring:
			if out.size() < n and not out.has(cc):
				out.append(cc)
		if out.size() >= n:
			break
	return out


func _hydra_died(u: VDUnit) -> bool:
	var any_alive := false
	for e in b.enemies:
		if e.id == "hydra" and e.alive:
			any_alive = true
			break
	if not any_alive:
		# 네 머리가 동시에 쓰러졌다: 부활 대기를 모두 거두고 진짜 처치
		_hydra_pending.clear()
		count["hydra_clear"] += 1
		b.dmg_log.spawn_status(b._chest(u) + Vector2(0, -24), "촉수 소멸!", HYDRA_COL, u)
		return false
	var key := u.get_instance_id()
	_hydra_pending[key] = true
	var run: int = b._run_id
	var uref: WeakRef = weakref(u)
	b.get_tree().create_timer(HYDRA_REVIVE, false).timeout.connect(func() -> void:
		var u2 := uref.get_ref() as VDUnit
		if not is_instance_valid(b) or run != b._run_id or u2 == null or not _hydra_pending.has(key):
			return
		_hydra_pending.erase(key)
		if b.state != VDBattle.State.BATTLE or u2.alive:
			return
		var mult := hydra_grow(u2)
		u2.revive(1.0)
		u2.show_bar = true
		count["revive"] += 1
		b.vfx.spawn("burst", b.fx_root, b._chest(u2), 0.6, 0.0, HYDRA_COL)
		b.vfx.spawn("shockwave", b.ground_fx, u2.position, 0.5, 0.0, HYDRA_COL, Vector2(1.0, 0.5))
		b.audio.play("enemy_spawn", 0.05, -2.0, 0.8)
		b.dmg_log.spawn_status(b._chest(u2) + Vector2(0, -24), "재생! 강화 ×%.1f" % mult, HYDRA_COL, u2))
	return true


## 부활 직전에 부른다: 부활 횟수 +1, 처음 능력치 × (1 + HYDRA_GROW × 횟수) 로 최대 체력·공격력을 올린다. 배율을 돌려준다.
func hydra_grow(u: VDUnit) -> float:
	if not u.has_meta("hydra_base"):
		u.set_meta("hydra_base", Vector2(u.max_hp, u.atk))
	var n := int(u.get_meta("hydra_revives", 0)) + 1
	u.set_meta("hydra_revives", n)
	var base: Vector2 = u.get_meta("hydra_base")
	var mult := 1.0 + HYDRA_GROW * n
	u.max_hp = floorf(base.x * mult)
	u.atk = floorf(base.y * mult)
	return mult


# ---------------------------------------------------------------- 환술사

func illusionist_alive() -> bool:
	for e in b.enemies:
		if e.id == "illusionist" and e.alive:
			return true
	return false


func update_immunity() -> void:
	var il := illusionist_alive()
	for e in b.enemies:
		if e.id != "illusion":
			continue
		var was := e.immune
		e.immune = il and e.alive
		if was != e.immune and e.visual:
			e.visual.modulate.a = 0.55 if e.immune else 1.0
			if not e.immune and e.alive:
				b.dmg_log.spawn_status(b._chest(e) + Vector2(0, -20), "실체화!", Color(1.0, 0.8, 1.0), e)
