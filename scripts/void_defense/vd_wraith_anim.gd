## 공허 망령(VDRig.PARTS_ART "wraith") 애니메이션: 해파리처럼 자락을 오므렸다 펴며 떠다니는 후드 + 본으로 휘는 촉수.
## 파츠(스프라이트): 고리 ring · 수정 조각 c_l c_tl c_tr c_r · 핵 core · 펜던트 pendant · 문장 crest
## 본(Skeleton2D):   hood(몸통) ─ flap_l · flap_r(자락)  ─ t1_0… · t2_0… · t3_0…(촉수 사슬, 뿌리 → 끝)
##   아이들  자락을 오므리면(pulse) 한 박자 뒤 몸이 떠오르고(lift), 그 움직임이 촉수 뿌리에서 끝으로 물결쳐 내려간다.
##           고리는 몸보다 늦게 따라오고 수정 조각은 고리를 따라 차례로 출렁인다. 핵은 구멍 안에서 따로 떠서 맥동한다.
##   걷기    자락이 뒤로 젖혀지고 촉수 물결이 빨라진다.
##   예비    몸을 뒤로 젖히고 자락을 활짝 펴며 촉수를 위아래로 벌려 말아 올린다. 핵이 커지며 밝아진다.
##   공격    자락을 확 오므리며 앞으로 쏠리고, 촉수가 뿌리부터 차례로 채찍처럼 휘둘린다. 핵이 번쩍인다.
##   피격    몸이 젖혀지고 수정 조각이 바깥으로 튀었다 돌아오며, 촉수에 충격이 끝까지 타고 내려간다.
##   광란    촉수 난타 중(frenzy): 앞으로 쏠린 채 온몸이 격렬하게 떨고 뒤틀리며, 자락이 퍼덕이고 수정 조각이 튀고 제 촉수가 마구 요동친다.
##   기절    자락·촉수가 축 늘어지고 핵이 어두워진다.
##   사망    조각들이 흩어지고 촉수가 말린다 (몸 찌그러짐·사라짐은 KillFx.body_tween).
## 원화는 왼쪽을 본다: 로컬 -x 가 앞, 회전 + 는 시계 방향. 위치 값은 화면 px 이고 _inv 로 텍스처 px 로 바꾼다.
class_name VDWraithAnim
extends VDPartsAnim

const PULSE_SEC := 2.6          # 자락을 오므렸다 펴는 주기
const WAVE_SEC := 1.9           # 촉수 물결 주기
const BONE_LAG := 0.022         # 충격·채찍이 본 하나를 지나는 시간 (초)
const CRYSTALS := ["c_l", "c_tl", "c_tr", "c_r"]
## 촉수별: 벌어지는 쪽(-1 위 · +1 아래), 물결 위상, 채찍 총 각도(도), 늘어질 때 꺾이는 첫 본·총 각도
const CHAINS := {
	"t1": {"spread": -1.0, "phase": 0.0, "whip": -34.0, "droop_from": 0, "droop": 58.0},
	"t2": {"spread": -0.25, "phase": 2.1, "whip": -42.0, "droop_from": 0, "droop": 46.0},
	"t3": {"spread": 1.0, "phase": 4.0, "whip": -50.0, "droop_from": 4, "droop": 30.0},
}

var _hood: Bone2D
var _flap_l: Bone2D
var _flap_r: Bone2D
var _chains := {}               # 이름 → Array[Bone2D] (뿌리 → 끝)
var _wave_t := 0.0              # 걷는 동안 더 빨리 흐르는 촉수 물결 시간
var _pend := 0.0                # 펜던트 흔들림 (도)
var _pend_v := 0.0
var _prev_bx := 0.0
## 광란: 촉수 난타를 쓰는 동안 1 (VDEnemySkills 가 켜고 끈다). 몸이 격렬하게 떨고 뒤틀리며 자락·고리·수정·제 촉수가 마구 요동친다.
var frenzy := 0.0
var _frenzy := 0.0
var _fz_t := 0.0


func setup(visual: Node2D) -> void:
	super.setup(visual)
	var skel := visual.get_node_or_null("Skeleton")
	if skel == null:
		return
	_hood = skel.get_node("hood")
	_flap_l = _hood.get_node("flap_l")
	_flap_r = _hood.get_node("flap_r")
	for cname in CHAINS:
		var bones: Array[Bone2D] = []
		var b := _hood.get_node_or_null(cname + "_0") as Bone2D
		while b:
			bones.append(b)
			b = b.get_node_or_null("%s_%d" % [cname, bones.size()]) as Bone2D
		_chains[cname] = bones


func reset() -> void:
	super.reset()
	_pend = 0.0
	_pend_v = 0.0
	_wave_t = 0.0
	frenzy = 0.0
	_frenzy = 0.0
	if _parts.has("core"):
		(_parts["core"]["node"] as Sprite2D).modulate = Color.WHITE
	if _hood == null:
		return
	for b in [_hood, _flap_l, _flap_r]:
		_rest(b)
	for bones in _chains.values():
		for b in bones:
			_rest(b)


func _rest(b: Bone2D) -> void:
	b.position = b.rest.origin
	b.rotation = 0.0
	b.scale = Vector2.ONE


## 사망: 조각은 바깥으로 튕겨 나가고, 자락은 처지고, 촉수는 끝으로 갈수록 말린다.
func scatter(owner: Node) -> void:
	if _hood == null:
		super.scatter(owner)
		return
	_scattered = true
	var center: Vector2 = _hood.rest.origin
	var tw := owner.create_tween().set_parallel(true)
	for pname in _parts:
		var n: Sprite2D = _parts[pname]["node"]
		var dir: Vector2 = ((_parts[pname]["pos"] as Vector2) - center).normalized()
		var far := 14.0 if pname == "core" else randf_range(26.0, 44.0)
		tw.tween_property(n, "position", n.position + (dir * far + Vector2(0, -8.0)) * _inv, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "rotation", n.rotation + signf(dir.x + 0.01) * randf_range(0.6, 1.5), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_flap_l, "rotation", deg_to_rad(-22.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_flap_r, "rotation", deg_to_rad(22.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for cname in _chains:
		var bones: Array = _chains[cname]
		var curl: float = (-1.0 if CHAINS[cname]["spread"] < 0.0 else 1.0) * deg_to_rad(150.0) / maxf(bones.size(), 1.0)
		for i in bones.size():
			var b: Bone2D = bones[i]
			tw.tween_property(b, "rotation", b.rotation + curl * (0.3 + float(i) / bones.size()), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 공격 곡선 (a = 공격부터 지난 시간): 0 → 1 로 휘두르고 잠깐 버틴 뒤, 반대쪽으로 한 번 지나쳤다가 잦아든다.
func _curve(a: float) -> float:
	if a <= 0.0 or a > 2.0:
		return 0.0
	if a < STRIKE_IN:
		var k := a / STRIKE_IN
		return 1.0 - (1.0 - k) * (1.0 - k)
	a -= STRIKE_IN
	if a < STRIKE_HOLD:
		return 1.0
	a -= STRIKE_HOLD
	return exp(-a * 6.0) * cos(a * 13.0)


func update(delta: float, t: float, phase: float, wind_glow: float, walk_amt: float, step: float, stunned: bool) -> void:
	if _hood == null:
		super.update(delta, t, phase, wind_glow, walk_amt, step, stunned)
		return
	if _scattered:
		return
	_strike_t += delta
	_hurt_t += delta
	_wind = maxf(wind_glow, _wind - delta / STRIKE_IN)
	_droop = move_toward(_droop, 1.0 if stunned else 0.0, delta * 4.0)
	_frenzy = move_toward(_frenzy, frenzy, delta * (9.0 if frenzy > _frenzy else 4.0))
	_fz_t += delta
	_wave_t += delta * (0.9 * walk_amt + 2.6 * _frenzy)
	var fz := _frenzy
	var ft := _fz_t

	var live := 1.0 - 0.8 * _droop
	var ph := t * TAU / PULSE_SEC + phase
	var pulse := sin(ph) * live                         # +1 = 자락을 오므린 순간
	var flap := sin(ph - 0.45) * live                   # 자락은 몸통 수축보다 조금 늦다
	var lift := sin(ph - 1.15) * live                   # 오므린 뒤에 떠오른다
	var yaw := sin(t * TAU / 6.2 + phase * 1.7) * live
	var q := _curve(_strike_t)
	var wd := _wind
	var hk := _hurt_k * exp(-_hurt_t * 6.0) if _hurt_t < 2.0 else 0.0
	var hw := hk * cos(_hurt_t * 16.0)
	var ws := sin(step) * walk_amt
	var flash := exp(-_strike_t * 8.0) if _strike_t < 1.0 else 0.0

	# ── 후드(몸통 본): 떠오르기 · 젖힘 · 수축 ──
	var body := Vector2(-11.0 * q + 4.0 * hw + 3.5 * wd + 1.5 * yaw + 2.0 * walk_amt, -5.0 * lift + 2.5 * wd + 5.0 * _droop - 2.0 * absf(ws))
	var body_rot := 1.6 * yaw + 6.0 * wd - 10.0 * q + 6.0 * hw + 4.0 * walk_amt + 1.5 * ws
	# 광란: 앞으로 쏠린 채 온몸이 빠르게 떨고 좌우로 크게 뒤틀린다 (느린 큰 흔들림 + 빠른 떨림)
	body += fz * Vector2(-7.0 + 6.0 * sin(ft * 13.0) + 3.0 * sin(ft * 41.0), 4.5 * sin(ft * 17.0 + 1.0) + 2.5 * sin(ft * 47.0))
	body_rot += fz * (-7.0 + 9.0 * sin(ft * 11.0) + 3.5 * sin(ft * 37.0))
	_hood.position = _hood.rest.origin + body * _inv
	_hood.rotation = deg_to_rad(body_rot)
	var fz_sq := fz * 0.07 * sin(ft * 23.0)             # 광란: 몸이 빠르게 부풀었다 오므라든다
	_hood.scale = Vector2(1.0 - 0.035 * pulse + 0.05 * wd - 0.07 * q + 0.03 * hk + fz_sq, 1.0 + 0.03 * pulse - 0.05 * wd + 0.06 * q - 0.03 * hk - fz_sq)
	# 자락: + 로 돌리면 왼쪽 자락 끝이 들린다 (오른쪽은 반대)
	var fl := -8.0 * flap + 13.0 * wd - 20.0 * q - 9.0 * _droop + 7.0 * hk * cos(_hurt_t * 13.0 + 0.5) + fz * (10.0 + 17.0 * sin(ft * 21.0))
	_flap_l.rotation = deg_to_rad(fl - 9.0 * walk_amt + 4.0 * ws)
	_flap_r.rotation = deg_to_rad(-fl - 7.0 * hk * cos(_hurt_t * 11.0 + 1.4) + 7.0 * hk * cos(_hurt_t * 13.0 + 0.5) - 5.0 * walk_amt + 4.0 * ws)

	var hx := _hood.transform
	var hp := _hood.rest.origin
	var hr := _hood.rotation

	# ── 후드에 얹힌 파츠: 문장 · 핵 · 펜던트 ──
	_ride("crest", hx, hp, hr, Vector2(1.2 * hw, -1.4 * sin(ph - 1.9) * live - 2.5 * hk), 2.0 * sin(ph - 1.9) * live + 7.0 * hw - 4.0 * q)
	var core_s := 1.0 + 0.05 * sin(t * TAU / 1.3 + phase) * live + 0.3 * wd + 0.45 * flash - 0.12 * _droop + fz * (0.3 + 0.18 * sin(ft * 29.0))
	_ride("core", hx, hp, 0.0, Vector2(-1.2 * yaw - 2.0 * q, -2.4 * sin(ph - 2.4) * live - 1.5 * wd),
		3.0 * sin(t * TAU / 3.1 + phase) * live, Vector2(core_s, core_s))
	if _parts.has("core"):
		var v := (1.0 + 0.12 * sin(t * TAU / 1.3 + phase) * live + 0.7 * wd + 1.1 * flash + fz * (0.9 + 0.5 * sin(ft * 33.0))) * (1.0 - 0.5 * _droop)
		(_parts["core"]["node"] as Sprite2D).modulate = Color(v, v, v)
	# 펜던트: 몸이 좌우로 움직이면 뒤늦게 따라 흔들리는 추 (감쇠 스프링)
	if delta > 0.0:
		var vx := clampf((body.x - _prev_bx) / delta, -300.0, 300.0)
		var target := vx * 0.22
		_pend_v += (70.0 * (target - _pend) - 5.5 * _pend_v) * delta
		_pend += _pend_v * delta
	_prev_bx = body.x
	_ride("pendant", hx, hp, 0.0, Vector2.ZERO, _pend + 6.0 * sin(ph - 2.0) * live + 14.0 * hk * cos(_hurt_t * 9.0) + 10.0 * ws + 9.0 * wd)

	# ── 고리와 수정 조각: 몸보다 늦게 떠오르고, 조각은 고리를 따라 차례로 출렁인다 ──
	if _parts.has("ring"):
		var ring_rest: Vector2 = _parts["ring"]["pos"]
		var ring_off := Vector2(body.x * 0.7 - 2.0 * hw, -5.0 * sin(ph - 2.0) * live - 5.0 * wd + 5.0 * q - 4.0 * hk + 6.0 * _droop + body.y * 0.3)
		var ring_rot := deg_to_rad(2.6 * sin(t * TAU / 3.7 + phase) * live + 0.5 * body_rot + 7.0 * hw + fz * 9.0 * sin(ft * 15.0 + 0.7))
		var ring_scale := Vector2(1.0 + 0.04 * wd - 0.06 * q, 1.0 + 0.07 * sin(t * TAU / 3.7 + phase + 1.3) * live + 0.1 * wd)
		var rx := Transform2D(ring_rot, ring_scale, 0.0, ring_rest + ring_off * _inv)
		_ride("ring", rx, ring_rest, ring_rot, Vector2.ZERO, 0.0, ring_scale)
		for i in CRYSTALS.size():
			var cn: String = CRYSTALS[i]
			if not _parts.has(cn):
				continue
			var out: Vector2 = ((_parts[cn]["pos"] as Vector2) - ring_rest).normalized()
			var a := t * TAU / 2.1 + phase - i * 1.35
			var jolt := hk * (1.0 + 0.5 * cos(_hurt_t * 14.0 + i * 1.7))
			var off := Vector2(1.6 * cos(a), -3.2 * sin(a)) * live + out * (6.0 * wd - 5.0 * q + 9.0 * jolt) + Vector2(0, -3.0 * wd + 5.0 * _droop * (0.6 + 0.2 * i))
			# 광란: 수정 조각이 바깥으로 벌어져 제각각 튄다
			off += fz * (out * (7.0 + 5.0 * sin(ft * 19.0 + i * 2.1)) + Vector2(3.0 * sin(ft * 27.0 + i * 1.3), 4.0 * cos(ft * 23.0 + i * 1.9)))
			_ride(cn, rx, ring_rest, 0.0, off, 7.0 * sin(a - 0.8) * live + 18.0 * jolt * (1.0 if i % 2 == 0 else -1.0) + 10.0 * wd * signf(out.x) - 12.0 * _droop * signf(out.x))

	# ── 촉수 본 사슬 ──
	var wave_ph := (t + _wave_t) * TAU / WAVE_SEC + phase
	for cname in _chains:
		var bones: Array = _chains[cname]
		var cfg: Dictionary = CHAINS[cname]
		var n := bones.size()
		var spread: float = cfg["spread"]
		var from: int = cfg["droop_from"]
		for i in n:
			var u := float(i) / maxf(n - 1, 1.0)
			# 물결: 뿌리에서 끝으로 흘러가고 끝으로 갈수록 커진다
			var rot := (1.6 + 4.2 * u) * (live + 0.5 * walk_amt + 1.6 * fz) * sin(wave_ph - i * 0.72 + float(cfg["phase"]))
			# 몸이 떠오르내리는 움직임이 본마다 조금씩 늦게 전해진다 (몸이 오르면 촉수 끝은 처진다)
			rot += 2.4 * (0.5 + u) * live * cos(ph - 1.15 - 0.32 * (i + 1))
			# 몸 기울임을 일부 되돌려 촉수가 통째로 따라 돌지 않게
			if i == 0:
				rot -= body_rot * 0.6
			# 예비: 위아래로 벌려 말아 올리며 떤다
			rot += wd * (spread * 5.0 * (0.4 + u) + 0.8 * sin(t * 43.0 + i * 1.3))
			# 공격: 뿌리부터 차례로 휘둘린다
			rot += float(cfg["whip"]) / n * _curve(_strike_t - BONE_LAG * i) * (0.6 + 0.8 * u)
			# 피격: 충격이 끝까지 타고 내려간다
			var ht := _hurt_t - BONE_LAG * i
			if ht > 0.0 and ht < 2.0:
				rot += _hurt_k * exp(-ht * 5.5) * cos(ht * 15.0) * (5.0 + 5.0 * u) * (1.0 if spread <= 0.0 else -1.0)
			# 걷기: 뒤로 나부낀다 (아래 촉수는 들리고 위 촉수는 눕는다)
			rot += walk_amt * (-spread * 1.6 * (1.0 - u) + 1.2 * ws)
			# 기절: 뿌리 쪽 몇 마디가 꺾여 아래로 늘어진다
			if i >= from and i < from + 4:
				rot += float(cfg["droop"]) * _droop * [0.4, 0.3, 0.2, 0.1][i - from]
			(bones[i] as Bone2D).rotation = deg_to_rad(rot)


## 스프라이트 파츠를 xf(피벗 pivot 이 움직인 변환) 위에 얹는다: 기준 위치를 xf 로 옮기고 off(화면 px)·회전(도)을 더한다.
func _ride(pname: String, xf: Transform2D, pivot: Vector2, base_rot: float, off: Vector2, rot_deg: float, scale := Vector2.ONE) -> void:
	if not _parts.has(pname):
		return
	var it: Dictionary = _parts[pname]
	var n: Sprite2D = it["node"]
	n.position = xf * ((it["pos"] as Vector2) - pivot) + off * _inv
	n.rotation = base_rot + deg_to_rad(rot_deg)
	n.scale = scale
