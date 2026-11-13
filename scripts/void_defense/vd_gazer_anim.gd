## 공허 응시자(VDRig.PARTS_ART "gazer", 첫 보스) 애니메이션: 눈 14개가 저마다 살아 움직이는 초승달 몸 + 본으로 날갯짓하는 날개 두 쌍.
## 본(Skeleton2D):  body ─ up0·up1·up2 (초승달 위쪽 팔) ─ lo0·lo1·lo2 (아래쪽 팔, 끝이 뿔) ─ tail (꼬리 지느러미)
##                        ─ wa0…2 (먼 쪽 뒷날개) ─ wb0…2 (먼 쪽 앞날개) ─ wc0…3 (가까운 쪽 앞날개) ─ wd0…2 (가까운 쪽 뒷날개)
## 눈(스프라이트): eye_N = 눈알(자식을 제 알파로 자른다) ─ pupil(동공) · over(외곽선·하이라이트). 몸통 본에 얹혀 따라 움직인다.
##
## 눈   · 훑어보기: 눈마다 제 박자로 시선을 휙휙 옮긴다(사카드). 가끔 옆 눈을 쳐다보고, 그러면 그 눈도 마주 봤다가 서로 딴 데로 튄다.
##      · 움찔: 눈알이 불쑥 부풀었다 떨리며 돌아오고(스프링) 그 순간 시선도 튄다. 동공은 조였다 풀렸다 한다.
##      · 깜빡임: 세로로 납작하게 감겼다 뜬다. 가끔 옆 눈으로 번진다.
##      · 주시: 공격 예비·공격·패링 예고 때는 모든 눈이 대상을 쏘아본다 (동공이 조여들고 눈알이 파르르 떤다).
##      · 피격: 눈을 질끈 감았다 뜨고 동공이 바늘처럼 줄어든 채 떤다.   기절: 동공이 제각각 빙글빙글 돈다.
## 날개 · 네 장이 잠자리처럼 번갈아 친다: 앞날개와 뒷날개가 엇박, 먼 쪽 쌍은 가까운 쪽보다 살짝 늦다. 끝으로 갈수록 한 박자 늦게 휜다.
##      · 앞뒤 날갯짓: 뿌리 본을 날개 축 기준으로 줄이고(길이 = 화면 앞뒤로 젓는 원근) 뒤집는다(폭이 0 을 지나 반전 = 날개를 비틀어 뒤집음).
##      · 내려칠 때마다 몸이 떠오른다. 가까운 앞날개가 내려칠 때마다 downbeats 가 1 늘어난다 (패링 예비 때 바닥 먼지를 일으키는 데 쓴다).
## 몸   · 초승달 두 팔이 숨 쉬듯 벌어졌다 오므라든다. 예비: 벌리며 뒤로 젖힘 → 공격: 콱 다물며 앞으로 쏠렸다가 탄성으로 돌아온다.
## 패링 · parry_windup(초): 날개 네 장을 격렬하게 퍼덕이며 높이 날아오르고(RISE px) 머리(뿔)를 낮춘다 → 끝 무렵 날개를 활짝 치켜든 채 움츠려 멈칫.
##      · ram_start(기울기): 뿔을 앞으로 내지르며 길게 늘어나고 날개는 뒤로 젖혀진다.  ram_impact(): 부딪쳐 찌그러지고 날개·눈알이 관성으로 쏠린다.
## 스킬 · cast_spread(on): 날개 네 장을 부채꼴로 치켜들어 파르르 떤다 (깃털 폭우 · 날개 폭풍의 예비).  gale_release(): 치켜든 날개를 한 번에 내리쳐 바람을 밀어낸다.
##      · spin(on): 초승달 몸이 톱날처럼 빙글빙글 돈다 (초승달 선회). 끄면 가까운 바른 각도로 돌아와 멈춘다.
##      · beam_windup(초): 두 팔을 벌려 눈을 드러내고 날개를 앞으로 감싸며 떤다 → beam_fire(): 반동 (만안 섬광, 두 번째 패링 공격).
## 원화는 왼쪽을 본다: 로컬 -x 가 앞, 회전 + 는 시계 방향(앞이 들린다). 위치 값은 화면 px 이고 _inv 로 텍스처 px 로 바꾼다.
class_name VDGazerAnim
extends VDPartsAnim

const D := preload("res://scripts/void_defense/vd_void_gazer_parts.gd")
const Fx := preload("res://scripts/void_defense/vd_parry_fx.gd")
const SPIN_DEG := 1150.0        # 초승달 선회: 초당 회전 (도)
const FLAP_SEC := 1.55          # 아이들 날갯짓 주기
const RAM_ROT := 24.0           # 돌진 때 몸을 돌려 뿔을 앞으로 내미는 각도 (도)
const HIND_LEAD := 2.5          # 뒷날개가 앞날개보다 앞서는 위상 (rad): 잠자리처럼 엇박
const FAR_LAG := 0.55           # 먼 쪽 쌍이 가까운 쪽보다 늦는 위상
const BODY_BONES := ["body", "up0", "up1", "up2", "lo0", "lo1", "lo2", "tail"]

var frenzy := 0.0               # (망령과 같은 이름: 쓰지 않지만 VDEnemySkills 가 건드려도 되게)
var downbeats := 0              # 가까운 앞날개가 내려친 횟수 (바깥에서 먼지 등을 맞춰 터뜨린다)
var flap_power := 0.0           # 지금 날갯짓 세기 0(아이들)~1(패링 예비의 격렬한 날갯짓)

var _visual: Node2D
var _bones := {}                # 이름 → Bone2D
var _rest := {}                 # 이름 → 본의 처음 위치 (비주얼 기준)
var _xf := {}                   # 이름 → 지금 변환 (비주얼 기준, 몸통 본만)
var _eyes: Array[Dictionary] = []
var _flap_ph := 0.0
var _beat_n := 0
var _wings: Array[Dictionary] = []
var _lift := 0.0                # 지금 날아오른 높이 (화면 px)
var _clock := 0.0
var _aim := Vector2.ZERO        # 쏘아볼 곳 (비주얼 기준 텍스처 px)
var _focus := 0.0               # 주시 남은 시간 (초)
# 패링
var _pw_on := false
var _pw := 0.0                  # 패링 예비 가중치 0~1
var _pw_t := 0.0
var _pw_sec := 2.0
var _ram_on := false
var _rm := 0.0                  # 돌진 자세 가중치
var _ram_tilt := 0.0
var _imp_t := 99.0              # 부딪친 뒤 지난 시간
# 스킬 자세
var _spread_on := false
var _sp := 0.0                  # 날개를 치켜들어 펼친 정도
var _gale_t := 99.0             # 날개 폭풍: 내리친 뒤 지난 시간
var _spin_on := false
var _spin := 0.0                # 선회 자세 가중치
var _spin_ang := 0.0            # 돈 각도 (도)
var _beam_on := false
var _bw := 0.0                  # 섬광 예비 가중치
var _bw_t := 0.0
var _bw_sec := 1.5


func setup(visual: Node2D) -> void:
	super.setup(visual)
	_visual = visual
	var skel := visual.get_node_or_null("Skeleton")
	if skel == null:
		return
	for b in skel.find_children("*", "Bone2D", true, false):
		_bones[str(b.name)] = b
	for part in D.PARTS:
		for bd in part.get("bones", []):
			_rest[String(bd[0])] = Vector2(bd[2], bd[3])
	for w in D.WINGS:
		var fore: bool = w["fore"]
		var near: bool = w["near"]
		_wings.append({"bones": w["bones"], "axis": float(w["axis"]),
			"ph": (0.0 if fore else HIND_LEAD) - (0.0 if near else FAR_LAG),
			"amp": (1.0 if fore else 1.25) * (1.0 if near else 0.85),       # 뒷날개·가까운 쪽이 더 크게 친다
			"flip": 0.34 if fore else 0.6,                                  # 아이들에서 날개를 비트는 정도 (0.5 를 넘으면 뒤집힌다)
			"sweep": 0.12 if fore else 0.2})
	var i := 0
	for part in D.PARTS:
		if part.get("kind", "") != "eye":
			continue
		var node := visual.get_node(String(part["name"])) as Sprite2D
		var r: float = part["r"]
		var pr: float = part["pr"]
		var rest_gaze: Vector2 = (part["pupil"] as Vector2) / maxf(r - pr * 0.55, 1.0)
		_eyes.append({
			"node": node, "pupil": node.get_node("pupil"), "pos": part["pos"], "bw": part["bw"], "r": r,
			"reach": maxf(r - pr * 0.55, 1.0),          # 동공 중심이 갈 수 있는 거리
			"gaze": rest_gaze, "goal": rest_gaze, "next": randf_range(0.1, 1.4),
			"tw": 0.0, "tw_v": 0.0, "next_tw": randf_range(0.4, 3.0), "jit": Vector2.RIGHT.rotated(randf() * TAU),
			"blink": -1.0, "blink_len": 1.0, "next_blink": randf_range(1.0, 7.0),
			"dil": 1.0, "dil_goal": 1.0, "ph": randf() * TAU, "spin": (1.0 if i % 2 == 0 else -1.0) * randf_range(5.0, 9.0),
			"look_back": -1, "near": [],
		})
		i += 1
	# 눈마다 가까운 이웃 둘 (서로 쳐다보기 · 깜빡임 번지기)
	for a in _eyes.size():
		var order := range(_eyes.size())
		order.erase(a)
		order.sort_custom(func(x: int, y: int) -> bool:
			return (_eyes[x]["pos"] as Vector2).distance_squared_to(_eyes[a]["pos"]) < (_eyes[y]["pos"] as Vector2).distance_squared_to(_eyes[a]["pos"]))
		_eyes[a]["near"] = order.slice(0, 3)


# ---------------------------------------------------------------- 바깥에서 부르는 것

## 쏘아볼 곳: d = 유닛 위치에서 대상까지 (화면 px). sec 동안 모든 눈이 그쪽을 본다.
func aim(d: Vector2, sec := 0.9) -> void:
	if _visual == null:
		return
	_aim = Vector2(d.x * signf(_visual.scale.x), d.y) * _inv
	_focus = maxf(_focus, sec)


func strike() -> void:
	super.strike()
	for e in _eyes:
		e["tw_v"] += randf_range(3.0, 5.0)
		e["dil"] = 0.6


func hurt(k: float) -> void:
	super.hurt(k)
	for e in _eyes:
		# 질끈: 눈마다 조금씩 어긋나게 감는다 (세게 맞을수록 오래)
		if randf() < 0.55 + 0.45 * _hurt_k:
			_start_blink(e, randf_range(0.0, 0.07), 1.0 + 1.6 * _hurt_k)
		e["dil"] = 0.5
		e["tw_v"] -= randf_range(2.0, 4.0) * (0.5 + _hurt_k)
		e["next"] = randf_range(0.05, 0.25)


## 패링 예비 동작 시작 (sec 초 동안). aim() 으로 대상도 넣어 준다.
func parry_windup(sec: float) -> void:
	_pw_on = true
	_pw_t = 0.0
	_pw_sec = maxf(sec, 0.1)


func parry_cancel() -> void:
	_pw_on = false
	_ram_on = false
	_beam_on = false


func cast_spread(on: bool) -> void:
	_spread_on = on


## 날개 폭풍: 치켜든 날개를 한 번에 내리친다.
func gale_release() -> void:
	_spread_on = false
	_gale_t = 0.0
	for e in _eyes:
		e["tw_v"] += randf_range(4.0, 7.0)
		e["dil"] = 0.6


func spin(on: bool) -> void:
	_spin_on = on


## 만안 섬광 예비 (sec 초). aim() 으로 대상도 넣어 준다.
func beam_windup(sec: float) -> void:
	_beam_on = true
	_bw_t = 0.0
	_bw_sec = maxf(sec, 0.1)


func beam_fire() -> void:
	_beam_on = false
	strike()


## 스킬 자세를 전부 푼다 (끊겼을 때).
func cast_cancel() -> void:
	_spread_on = false
	_spin_on = false
	_beam_on = false


## 돌진 시작. tilt_deg: 돌진 방향이 수평에서 아래로 기운 각도 (도).
func ram_start(tilt_deg: float) -> void:
	_pw_on = false
	_ram_on = true
	_ram_tilt = clampf(tilt_deg, -30.0, 30.0)
	_rm = 0.35
	for e in _eyes:
		e["goal"] = Vector2(0.7, randf_range(-0.2, 0.2))      # 관성: 동공이 뒤로 쏠린다
		e["next"] = 0.5


## 부딪쳤다 (명중이든 튕겨 나갔든).
func ram_impact() -> void:
	_imp_t = 0.0
	for e in _eyes:
		e["tw_v"] += randf_range(5.0, 8.0)
		e["goal"] = Vector2(-0.75, randf_range(-0.3, 0.3))     # 앞으로 쏠렸다가
		e["next"] = randf_range(0.08, 0.2)
		e["dil"] = 0.55


func ram_end() -> void:
	_ram_on = false


## 돌진 자세에서 뿔 끝이 유닛 원점에서 얼마나 떨어져 있는지 (화면 px, 왼쪽을 볼 때 기준).
func horn_offset() -> Vector2:
	var c: Vector2 = D.BODY_CENTER
	var tip: Vector2 = c + (D.HORN_TIP - c).rotated(deg_to_rad(RAM_ROT))
	return tip / _inv


## 지금 날아오른 높이 (화면 px, 위로 +).
func lift_now() -> float:
	return _lift


func reset() -> void:
	super.reset()
	_pw_on = false
	_ram_on = false
	_pw = 0.0
	_rm = 0.0
	_imp_t = 99.0
	_focus = 0.0
	_lift = 0.0
	flap_power = 0.0
	_spread_on = false
	_spin_on = false
	_beam_on = false
	_sp = 0.0
	_spin = 0.0
	_spin_ang = 0.0
	_bw = 0.0
	_gale_t = 99.0
	for bname in _bones:
		var b: Bone2D = _bones[bname]
		b.transform = Transform2D(0.0, b.rest.origin)
	for e in _eyes:
		var n: Sprite2D = e["node"]
		n.position = e["pos"]
		n.rotation = 0.0
		n.scale = Vector2.ONE
		n.modulate = Color.WHITE
		e["blink"] = -1.0
		e["tw"] = 0.0
		e["tw_v"] = 0.0
		e["dil"] = 1.0


## 사망: 눈알이 사방으로 튀어 나가고 날개·두 팔이 축 늘어진다.
func scatter(owner: Node) -> void:
	if _bones.is_empty():
		super.scatter(owner)
		return
	_scattered = true
	var center: Vector2 = D.BODY_CENTER
	var tw := owner.create_tween().set_parallel(true)
	for e in _eyes:
		var n: Sprite2D = e["node"]
		var dir: Vector2 = ((e["pos"] as Vector2) - center).normalized().rotated(randf_range(-0.5, 0.5))
		var far := randf_range(38.0, 96.0)
		tw.tween_property(n, "position", n.position + (dir * far + Vector2(0, -14.0)) * _inv, 0.36).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "rotation", n.rotation + randf_range(-2.4, 2.4), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "scale", Vector2.ONE * randf_range(1.15, 1.45), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_put_pupil(e, Vector2.ZERO, 0.4)
	for w in _wings:
		for k in 2:
			tw.tween_property(_bones[w["bones"][k]], "rotation", deg_to_rad(30.0 - 8.0 * k), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for bname in ["up0", "up1", "up2"]:
		tw.tween_property(_bones[bname], "rotation", deg_to_rad(-9.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for bname in ["lo0", "lo1", "lo2"]:
		tw.tween_property(_bones[bname], "rotation", deg_to_rad(-8.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- 매 프레임

func update(delta: float, t: float, phase: float, wind_glow: float, walk_amt: float, step: float, stunned: bool) -> void:
	if _bones.is_empty():
		super.update(delta, t, phase, wind_glow, walk_amt, step, stunned)
		return
	if _scattered:
		return
	_clock += delta
	_strike_t += delta
	_hurt_t += delta
	_imp_t += delta
	_focus = maxf(0.0, _focus - delta)
	if stunned:
		_pw_on = false
		_ram_on = false
		_spread_on = false
		_spin_on = false
		_beam_on = false
	_gale_t += delta
	if _beam_on:
		_bw_t += delta
	_sp = move_toward(_sp, 1.0 if _spread_on else 0.0, delta * (6.0 if _spread_on else 7.0))
	_bw = move_toward(_bw, 1.0 if _beam_on else 0.0, delta * (4.0 if _beam_on else 8.0))
	_spin = move_toward(_spin, 1.0 if _spin_on else 0.0, delta * (7.0 if _spin_on else 5.0))
	if _spin_on:
		_spin_ang += delta * SPIN_DEG * _spin
	elif _spin_ang != 0.0:
		# 가까운 바른 각도(한 바퀴의 배수)까지 마저 돌고 멈춘다
		var stop := ceilf(_spin_ang / 360.0) * 360.0
		_spin_ang = move_toward(_spin_ang, stop, delta * SPIN_DEG)
		if is_equal_approx(_spin_ang, stop):
			_spin_ang = 0.0
	if _pw_on:
		_pw_t += delta
	_pw = move_toward(_pw, 1.0 if _pw_on else 0.0, delta * (5.0 if _pw_on else 9.0))
	_rm = move_toward(_rm, 1.0 if _ram_on else 0.0, delta * (26.0 if _ram_on else 4.5))
	_wind = maxf(0.0 if (_pw_on or _ram_on) else wind_glow, _wind - delta / STRIKE_IN)
	_droop = move_toward(_droop, 1.0 if stunned else 0.0, delta * 4.5)

	var live := 1.0 - 0.85 * _droop
	var pk := clampf(_pw_t / _pw_sec, 0.0, 1.0)                        # 패링 예비 진행도
	var coil := smoothstep(0.84, 0.97, pk) * _pw                       # 끝 무렵: 날개를 치켜든 채 움츠려 멈칫
	var wild := _pw * (1.0 - coil)                                     # 격렬한 날갯짓
	var pw := _pw
	var rm := _rm
	var q := _strike_curve() if _strike_t < 2.0 else 0.0
	var wd := _wind
	var hk := _hurt_k * exp(-_hurt_t * 6.0) if _hurt_t < 2.0 else 0.0
	var hw := hk * cos(_hurt_t * 17.0)
	var iq := exp(-_imp_t * 6.5) * cos(_imp_t * 21.0) if _imp_t < 1.6 else 0.0   # 충돌 출렁임
	var ie := exp(-_imp_t * 5.0) if _imp_t < 1.6 else 0.0
	var gk := exp(-_gale_t * 4.2) if _gale_t < 1.6 else 0.0                    # 날개 폭풍: 내리친 여운
	var gs := gk * cos(_gale_t * 10.0)
	var bk := clampf(_bw_t / _bw_sec, 0.0, 1.0)                             # 섬광 예비 진행도
	var ws := sin(step) * walk_amt
	var yaw := sin(t * TAU / 6.4 + phase * 1.7) * live
	var breath := sin(t * TAU / 3.3 + phase) * live

	# ── 날갯짓 위상: 걸을수록·패링 예비일수록 빨라진다 ──
	var rate := TAU / FLAP_SEC * (1.0 + 1.1 * walk_amt) * live
	rate = lerpf(rate, TAU * lerpf(Fx.g("flap_lo"), Fx.g("flap_hi"), pk), wild)
	rate *= 1.0 - 0.92 * maxf(maxf(coil, rm), maxf(_sp, maxf(_spin, 0.6 * _bw)))
	_flap_ph += delta * rate
	var fp := _flap_ph + phase
	var amp := (13.0 + 6.0 * walk_amt) * live + Fx.g("flap_amp") * wild   # 날개 뿌리 각도 진폭 (도)
	var deep := clampf(wild + 0.35 * walk_amt, 0.0, 1.0)                 # 앞뒤로 젓고 뒤집는 정도
	flap_power = wild
	var down := _beat(fp)                                              # +1 = 가까운 앞날개가 다 내려친 순간
	var lift := 0.6 * _beat(fp - 0.9) + 0.4 * _beat(fp + HIND_LEAD - 0.9)   # 내려친 뒤 몸이 떠오른다 (앞·뒷날개가 번갈아 받친다)
	var n := int(floor((fp - 1.1) / TAU))
	if n != _beat_n:
		_beat_n = n
		downbeats += 1
	# 날아오르기: 예비 동안 날갯짓마다 울컥울컥 올라가 정점에서 멈칫, 돌진하며 한순간에 내리꽂힌다
	_lift = Fx.g("ram_rise") * (smoothstep(0.02, 0.8, pk) * pw + 0.07 * wild * down) * (1.0 - rm) + 46.0 * _sp * (1.0 - gk)
	var tremble := sin(_clock * 38.0) * maxf(_sp, _bw * (0.3 + 0.7 * bk))        # 힘을 모으며 파르르

	# ── 몸통 본: 떠오르기 · 젖힘 · 늘어남 ──
	var shake := Vector2(sin(_clock * 39.0) * 2.4 + sin(_clock * 71.0) * 1.2, sin(_clock * 47.0 + 1.0) * 2.0) * wild * (0.35 + 0.65 * pk)
	shake += Vector2(sin(_clock * 83.0), cos(_clock * 97.0)) * 1.6 * coil
	var body := Vector2(
		-20.0 * q + 6.0 * hw + 8.0 * wd + 1.5 * yaw - 2.0 * walk_amt + 7.0 * wild + 15.0 * coil - 6.0 * rm + 13.0 * iq + 18.0 * gk + 6.0 * _bw * bk,
		-_lift - (4.2 + 5.0 * wild) * lift - 1.5 * breath + 2.0 * wd + 8.0 * _droop - 2.0 * absf(ws) - 6.0 * wild + 9.0 * coil - 4.0 * ie) + shake
	var body_rot := 1.4 * yaw + 9.0 * wd - 15.0 * q + 6.0 * hw - 3.5 * walk_amt + 1.2 * ws \
		- 9.0 * wild - 15.0 * coil + (RAM_ROT - 0.45 * _ram_tilt) * rm - 13.0 * iq + 7.0 * _droop + 1.2 * down * live \
		+ 9.0 * _sp - 13.0 * gs - 7.0 * _bw - _spin_ang + 1.5 * tremble
	var sq := 0.02 * breath + 0.09 * wd - 0.15 * q + 0.03 * hk - 0.08 * coil + 0.2 * rm - 0.26 * iq - 0.1 * gs - 0.05 * _bw * bk
	sq *= 1.0 - _spin                                                  # 도는 동안은 찌그러뜨리지 않는다 (회전과 섞이면 일그러진다)
	_pose("body", body, body_rot, Vector2(1.0 + sq, 1.0 - sq * 0.85))

	# ── 초승달 두 팔: + 로 벌어진다 (위 팔은 시계, 아래 팔은 반시계) ──
	var jaw := 3.0 * breath + 19.0 * wd - 30.0 * q - 7.0 * hk + 7.0 * wild * (0.6 + 0.4 * sin(_clock * 19.0)) + 13.0 * coil \
		+ 17.0 * _bw - 9.0 * _spin + 8.0 * _sp - 14.0 * gk
	var up_open := jaw + 15.0 * rm + 9.0 * iq - 11.0 * _droop
	var lo_open := jaw - 7.0 * rm - 12.0 * iq + 10.0 * _droop
	var share := [0.42, 0.33, 0.25]
	for k in 3:
		var wob := 1.1 * sin(t * 2.3 + phase - k * 0.9) * live + hk * 5.0 * cos(_hurt_t * 15.0 - k * 0.9)
		_pose("up%d" % k, Vector2.ZERO, up_open * share[k] + wob, Vector2.ONE)
		_pose("lo%d" % k, Vector2.ZERO, -lo_open * share[k] - wob * 0.8, Vector2.ONE)
	_pose("tail", Vector2.ZERO, 9.0 * sin(t * TAU / 1.7 + phase) * live + 14.0 * ws + 9.0 * walk_amt + 24.0 * rm - 26.0 * q
		+ 18.0 * hk * cos(_hurt_t * 13.0) + 16.0 * _droop + 12.0 * wild * sin(_clock * 23.0) - 22.0 * iq, Vector2.ONE)

	# ── 날개 네 장: 뿌리부터 끝으로 한 박자씩 늦게 휜다 ──
	# 공통 자세: 예비 = 치켜듦(-), 멈칫 = 활짝 치켜들어 펼침, 돌진 = 뒤로 젖혀 납작(+), 충돌 = 관성으로 앞으로 쏠림(-), 기절 = 축 처짐(+)
	var base := -32.0 * _sp + 66.0 * gk - 26.0 * _bw + 22.0 * _spin + 4.0 * tremble - 9.0 * wd + 12.0 * q - 34.0 * coil + 24.0 * rm - 30.0 * iq + 24.0 * _droop - 5.0 * walk_amt + 9.0 * hk * cos(_hurt_t * 24.0)
	var still := maxf(maxf(coil, maxf(rm, _droop)), maxf(maxf(_sp, _spin), maxf(0.7 * _bw, gk)))                           # 날갯짓을 멈춘 자세: 비틀지 않고 편다
	for wi in _wings.size():
		var w: Dictionary = _wings[wi]
		var ph: float = fp + float(w["ph"])
		var names: Array = w["bones"]
		var wa: float = amp * float(w["amp"])
		# 앞뒤로 젓기: 길이가 줄었다 늘고(원근), 폭이 좁아지다 0 을 지나 뒤집힌다(비틀기). 내려칠 땐 활짝, 올릴 땐 접어 비튼다
		var sweep := 0.5 + 0.5 * sin(ph + 1.25)
		var twist := 0.5 - 0.5 * _beat(ph + 2.3)
		var fk: float = lerpf(float(w["flip"]), 0.92, deep) * (1.0 - still)
		var sk: float = lerpf(float(w["sweep"]), 0.42, deep) * (1.0 - still)
		var sx := 1.0 - sk * sweep + 0.1 * coil - 0.06 * rm + 0.05 * ie
		var sy := 1.0 - 2.0 * fk * twist * twist
		sy = (1.0 if sy >= 0.0 else -1.0) * maxf(absf(sy), 0.2)             # 폭 0(실선)은 건너뛴다: 한 프레임에 휙 뒤집힌다
		sx += 0.1 * _sp - 0.14 * _bw + 0.12 * gk
		sy *= 1.0 + 0.16 * coil - 0.34 * rm + 0.14 * iq + 0.16 * _sp - 0.3 * _spin + 0.2 * gk
		# 펼친 채 치켜든 자세는 날개마다 부채꼴로 벌어진다 (위 날개는 더 위로, 아래 날개는 덜)
		var fan: float = [-10.0, -4.0, 4.0, 12.0][wi] * maxf(coil, maxf(_sp, _bw)) + [5.0, 2.0, -2.0, -6.0][wi] * rm
		for k in names.size():
			var b := _beat(ph - 0.46 * k)
			var a: float = wa * (1.0 if k == 0 else 0.55 + 0.06 * k)
			var bone_rot: float = a * b + (base + fan) * (1.0 if k == 0 else 0.3)
			_pose_axis(names[k], bone_rot, Vector2(sx, sy) if k == 0 else Vector2.ONE, w["axis"])

	_body_xforms()
	_update_eyes(delta, stunned, wd, maxf(pw, _bw), bk if _beam_on else pk, maxf(coil, 0.8 * _bw * bk), hk)


## 날갯짓 곡선: 내려칠 때가 올릴 때보다 빠르다.
func _beat(ph: float) -> float:
	return sin(ph + 0.45 * sin(ph))


func _pose(bname: String, off: Vector2, rot_deg: float, scale: Vector2) -> void:
	var b: Bone2D = _bones.get(bname)
	if b:
		b.transform = Transform2D(deg_to_rad(rot_deg), scale, 0.0, b.rest.origin + off * _inv)


## 날개 본: 날개 축 방향(axis)을 기준으로 늘이고 줄인다 (scale.x = 길이, scale.y = 폭).
func _pose_axis(bname: String, rot_deg: float, scale: Vector2, axis: float) -> void:
	var b: Bone2D = _bones.get(bname)
	if b == null:
		return
	var m := Transform2D(axis + deg_to_rad(rot_deg), scale, 0.0, Vector2.ZERO) * Transform2D(-axis, Vector2.ZERO)
	m.origin = b.rest.origin
	b.transform = m


## 몸통 본들의 지금 변환을 비주얼 기준으로 모아 둔다 (눈을 얹는 데 쓴다).
func _body_xforms() -> void:
	for bname in BODY_BONES:
		var b: Bone2D = _bones.get(bname)
		if b == null:
			continue
		var parent := b.get_parent()
		var x := b.transform
		if parent is Bone2D:
			x = (_xf[str(parent.name)] as Transform2D) * x
		_xf[bname] = x


func _start_blink(e: Dictionary, delay: float, length: float) -> void:
	e["blink"] = -delay - 0.0001
	e["blink_len"] = length


## 감긴 정도 0~1: 빠르게 감고 → 잠깐 → 천천히 뜬다. bt = 깜빡임 시작부터 지난 시간(음수면 아직 대기).
func _lid(bt: float, length: float) -> float:
	if bt < 0.0:
		return 0.0
	if bt < 0.05:
		return bt / 0.05
	bt -= 0.05
	var hold := 0.05 * length
	if bt < hold:
		return 1.0
	bt -= hold
	return maxf(0.0, 1.0 - bt / 0.13)


func _update_eyes(delta: float, stunned: bool, wd: float, pw: float, pk: float, coil: float, hk: float) -> void:
	var focus := _focus > 0.0 or _pw_on or _beam_on
	var tension := maxf(wd, pw * (0.4 + 0.6 * pk))                   # 긴장: 떨림·동공 조임
	for i in _eyes.size():
		var e: Dictionary = _eyes[i]
		var n: Sprite2D = e["node"]
		# 몸통 본에 얹기 (본 가중치로 섞는다)
		var rest: Vector2 = e["pos"]
		var at := Vector2.ZERO
		var rot := 0.0
		for bname in e["bw"]:
			var x: Transform2D = _xf[bname]
			var w: float = e["bw"][bname]
			at += w * (x * (rest - (_rest[bname] as Vector2)))
			rot += w * x.get_rotation()

		# ── 시선 ──
		var goal: Vector2 = e["goal"]
		e["next"] -= delta
		if stunned:
			# 빙글빙글: 눈마다 방향·빠르기가 다르다
			var a: float = _clock * float(e["spin"]) + float(e["ph"])
			goal = Vector2(cos(a), sin(a)) * 0.72
			e["dil_goal"] = 1.12
		elif focus and not _ram_on:
			var d := _aim - at
			goal = d.normalized() * 0.6 if d.length() > 1.0 else Vector2.LEFT * 0.6
			e["dil_goal"] = lerpf(0.9, 0.7, tension)
			e["next"] = randf_range(0.05, 0.3)
		elif e["next"] <= 0.0:
			goal = _pick_gaze(i, e)
		e["goal"] = goal
		var gaze: Vector2 = (e["gaze"] as Vector2).lerp(goal, 1.0 - exp(-delta * (11.0 if stunned else 34.0)))
		e["gaze"] = gaze
		# 미세 떨림 (긴장할수록 크게)
		var ph: float = e["ph"]
		var tremor := Vector2(sin(_clock * 33.0 + ph), cos(_clock * 29.0 + ph * 1.7)) * (0.012 + 0.07 * tension + 0.09 * hk)

		# ── 움찔 (스프링) ──
		e["next_tw"] -= delta
		if e["next_tw"] <= 0.0 and not stunned:
			e["next_tw"] = randf_range(0.5, 2.8) * (1.0 - 0.55 * tension)
			e["tw_v"] += randf_range(2.2, 4.4) * (1.0 if randf() < 0.75 else -1.0)
			e["jit"] = Vector2.RIGHT.rotated(randf() * TAU)
			e["next"] = minf(e["next"], randf_range(0.0, 0.08))       # 움찔하며 시선도 튄다
			e["dil_goal"] = randf_range(0.82, 1.16)
		var tw: float = e["tw"]
		var tw_v: float = e["tw_v"]
		tw_v += (-460.0 * tw - 15.0 * tw_v) * delta
		tw += tw_v * delta
		tw = clampf(tw, -0.35, 0.45)
		e["tw"] = tw
		e["tw_v"] = tw_v

		# ── 깜빡임 ──
		var bt: float = e["blink"]
		if bt > -1.0:
			bt += delta
			if bt > 0.05 + 0.05 * float(e["blink_len"]) + 0.14:
				bt = -1.0
			e["blink"] = bt
		elif not stunned and not focus:
			e["next_blink"] -= delta
			if e["next_blink"] <= 0.0:
				e["next_blink"] = randf_range(2.2, 7.5)
				_start_blink(e, 0.0, 1.0)
				for j in e["near"]:                                   # 옆 눈으로 번진다
					if randf() < 0.35 and float(_eyes[j]["blink"]) <= -1.0:
						_start_blink(_eyes[j], randf_range(0.05, 0.12), 1.0)
				if randf() < 0.25:
					e["next_blink"] = 0.3                              # 두 번 깜빡
		var lid := _lid(bt, e["blink_len"]) if bt > -1.0 else 0.0
		lid = maxf(lid, 0.55 * maxf(_rm, _spin))                       # 돌진·선회: 눈을 가늘게 뜬다

		# ── 동공 크기 ──
		var dil: float = lerpf(e["dil"], e["dil_goal"], 1.0 - exp(-delta * 7.0))
		e["dil"] = dil

		var bulge := 1.0 + 0.85 * tw + 0.05 * tension * sin(_clock * 41.0 + ph) + 0.1 * coil
		n.position = at + (e["jit"] as Vector2) * tw * 5.0 * _inv
		n.rotation = rot
		n.scale = Vector2(bulge * (1.0 + 0.1 * lid), bulge * (1.0 - 0.88 * lid))
		_put_pupil(e, gaze + tremor, dil * (1.0 - 0.25 * tw))


## 동공 놓기: 가장자리로 갈수록 그 방향으로 납작해진다 (공의 옆면에 붙은 것처럼).
func _put_pupil(e: Dictionary, gaze: Vector2, dil: float) -> void:
	var m := minf(gaze.length(), 1.0)
	var th := gaze.angle()
	var edge := sqrt(1.0 - 0.5 * m * m)
	var x := Transform2D(th, Vector2(edge * dil, dil), 0.0, Vector2.ZERO) * Transform2D(-th, Vector2.ZERO)
	x.origin = gaze.limit_length(1.0) * float(e["reach"])
	(e["pupil"] as Sprite2D).transform = x


## 다음 시선: 아무 데나 · 옆 눈 쳐다보기(그 눈도 마주 본다) · 마주 본 뒤엔 반대로 튄다.
func _pick_gaze(i: int, e: Dictionary) -> Vector2:
	var back: int = e["look_back"]
	if back >= 0:
		# 누가 나를 쳐다봤다 → 마주 본다
		e["look_back"] = -1
		e["next"] = randf_range(0.25, 0.6)
		e["tw_v"] += 1.6
		return _toward(e, _eyes[back]) * 0.9
	var roll := randf()
	if roll < 0.3 and not (e["near"] as Array).is_empty():
		var j: int = (e["near"] as Array).pick_random()
		e["next"] = randf_range(0.35, 0.9)
		if randf() < 0.65:
			_eyes[j]["look_back"] = i
			_eyes[j]["next"] = randf_range(0.08, 0.22)
		return _toward(e, _eyes[j]) * 0.82
	if roll < 0.42:
		# 정면(앞쪽)을 힐끗
		e["next"] = randf_range(0.3, 0.8)
		return Vector2(-0.8, randf_range(-0.25, 0.35))
	if roll < 0.5:
		# 가운데로 돌아와 멍하니
		e["next"] = randf_range(0.5, 1.2)
		return Vector2(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15))
	# 아무 데나: 가끔 연달아 짧게 두리번거린다
	e["next"] = randf_range(0.12, 0.3) if randf() < 0.35 else randf_range(0.35, 1.5)
	return Vector2.RIGHT.rotated(randf() * TAU) * sqrt(randf_range(0.2, 1.0)) * 0.84


func _toward(e: Dictionary, other: Dictionary) -> Vector2:
	return ((other["pos"] as Vector2) - (e["pos"] as Vector2)).normalized()
