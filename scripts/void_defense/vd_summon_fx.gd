## 적 차원 소환 연출의 조절값 (VDUnit.appear · VDBattle._summon_impact 가 읽는다).
## 연출 연구실(FxLab)에서 실시간으로 바꾸고 저장하면 user://summon_fx.json 에 남아 실제 게임에도 그대로 쓰인다.
## PARAMS 의 def 가 코드 기본값. 연구실의 "값 복사" 로 받은 줄을 여기 def 에 옮기면 기본값이 된다.
class_name VDSummonFx

const SAVE_PATH := "user://summon_fx.json"

## 낙하·안착에 고를 수 있는 트윈 곡선 (option 파라미터의 값은 이 목록의 인덱스)
const TRANS_NAMES := ["LINEAR", "SINE", "QUAD", "CUBIC", "QUART", "EXPO", "BACK", "ELASTIC", "BOUNCE", "SPRING", "CIRC"]
const TRANS := [Tween.TRANS_LINEAR, Tween.TRANS_SINE, Tween.TRANS_QUAD, Tween.TRANS_CUBIC, Tween.TRANS_QUART,
	Tween.TRANS_EXPO, Tween.TRANS_BACK, Tween.TRANS_ELASTIC, Tween.TRANS_BOUNCE, Tween.TRANS_SPRING, Tween.TRANS_CIRC]

## [키, 그룹, 이름, 최소, 최대, 단계, 기본값] — 단계가 0 이면 TRANS_NAMES 중 고르는 옵션
const PARAMS := [
	["drop_height",    "1 낙하", "낙하 높이(px)",          0.0, 600.0, 5.0,   260.0],
	["boss_height",    "1 낙하", "보스 높이 배율",          0.5, 3.0,   0.05,  1.4],
	["drop_sec",       "1 낙하", "낙하 시간(초)",           0.03, 0.6,  0.01,  0.13],
	["drop_trans",     "1 낙하", "낙하 곡선 (EASE_IN)",     0.0, 10.0,  0.0,   2.0],
	["fall_x0",        "1 낙하", "시작 가로 배율",          0.02, 2.0,  0.01,  0.22],
	["fall_y0",        "1 낙하", "시작 세로 배율",          0.2, 4.0,   0.05,  1.9],
	["fall_x1",        "1 낙하", "착지 직전 가로 배율",     0.02, 2.0,  0.01,  0.3],
	["fall_y1",        "1 낙하", "착지 직전 세로 배율",     0.2, 4.0,   0.05,  1.6],
	["squash_x",       "2 꽂힘", "꽂힘 가로 배율",          0.5, 4.0,   0.05,  1.75],
	["squash_y",       "2 꽂힘", "꽂힘 세로 배율",          0.05, 1.0,  0.01,  0.32],
	["hold_x",         "2 꽂힘", "버팀 가로 배율",          0.5, 4.0,   0.05,  1.55],
	["hold_y",         "2 꽂힘", "버팀 세로 배율",          0.05, 1.0,  0.01,  0.45],
	["hold_sec",       "2 꽂힘", "버팀 시간(초)",           0.0, 0.4,   0.01,  0.06],
	["stretch_x",      "3 튕김", "튕김 가로 배율",          0.3, 1.5,   0.01,  0.78],
	["stretch_y",      "3 튕김", "튕김 세로 배율",          0.5, 2.5,   0.01,  1.32],
	["stretch_sec",    "3 튕김", "튕김 시간(초)",           0.02, 0.5,  0.01,  0.1],
	["stretch_white",  "3 튕김", "튕김 끝 흰빛(0~1)",       0.0, 1.0,   0.01,  0.35],
	["settle_sec",     "4 안착", "출렁임 시간(초)",         0.05, 2.0,  0.01,  0.5],
	["settle_trans",   "4 안착", "출렁임 곡선 (EASE_OUT)",  0.0, 10.0,  0.0,   7.0],
	["white_fade_sec", "4 안착", "흰빛 빠지는 시간(초)",    0.0, 1.5,   0.01,  0.28],
	["glow_size",      "빛",     "후광 크기",               0.0, 3.0,   0.05,  1.0],
	["glow_alpha",     "빛",     "후광 세기",               0.0, 1.0,   0.01,  1.0],
	["glow_fade_sec",  "빛",     "후광 사라지는 시간(초)",  0.0, 1.5,   0.01,  0.35],
	["shake",          "타격",   "화면 흔들림",             0.0, 1.0,   0.01,  0.32],
	["hitstop",        "타격",   "히트스탑(초)",            0.0, 0.25,  0.005, 0.035],
	["shockwave",      "타격",   "충격파 크기",             0.0, 1.5,   0.01,  0.3],
	["burst",          "타격",   "바닥 섬광 크기",          0.0, 0.6,   0.01,  0.13],
	["dust",           "타격",   "먼지 크기",               0.0, 3.0,   0.05,  1.3],
	["boss_impact",    "타격",   "보스 타격 배율",          0.5, 3.0,   0.05,  1.6],
	["portal",         "예고",   "균열(포털) 크기",         0.0, 1.0,   0.01,  0.34],
	["portal_sec",     "예고",   "균열 유지(초)",           0.0, 2.0,   0.05,  0.45],
	["interval",       "예고",   "적 사이 소환 간격(초)",   0.02, 1.0,  0.01,  0.17],
	["champ_delay",    "강적",   "강적 앞 뜸(초)",          0.0, 2.0,   0.05,  0.75],
	["champ_lead",     "강적",   "괴성→낙하(초)",           0.0, 2.0,   0.05,  0.6],
	["champ_rumble",   "강적",   "괴성 중 흔들림",          0.0, 1.0,   0.01,  0.3],
	["champ_portal",   "강적",   "강적 균열 배율",          0.5, 3.0,   0.05,  1.6],
	["champ_impact",   "강적",   "강적 타격 배율",          0.5, 3.0,   0.05,  1.5],
	["champ_shake",    "강적",   "강적 착지 흔들림",        0.0, 1.0,   0.01,  0.9],
	["champ_hitstop",  "강적",   "강적 히트스탑(초)",       0.0, 0.25,  0.005, 0.09],
]

static var values := {}
static var _loaded := false


static func defaults() -> Dictionary:
	var d := {}
	for p in PARAMS:
		d[p[0]] = p[6]
	return d


static func g(key: String) -> float:
	if not _loaded:
		load_saved()
	return float(values.get(key, 0.0))


static func trans(key: String) -> int:
	return TRANS[clampi(int(g(key)), 0, TRANS.size() - 1)]


static func set_value(key: String, v: float) -> void:
	if not _loaded:
		load_saved()
	values[key] = v


static func load_saved() -> void:
	_loaded = true
	values = defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		for k in data:
			if values.has(k):
				values[k] = float(data[k])


static func save() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(values, "\t"))
	return true


static func reset() -> void:
	_loaded = true
	values = defaults()


## 기본값과 다른 값만 "키 = 값" 줄로 (사용자가 복사해 공유하거나 PARAMS 기본값에 옮길 때)
static func describe(all := false) -> String:
	var lines := PackedStringArray()
	for p in PARAMS:
		var v := g(p[0])
		if all or not is_equal_approx(v, float(p[6])):
			var shown: String = TRANS_NAMES[int(v)] if p[5] == 0.0 else str(snappedf(v, 0.001))
			lines.append("%s = %s   # %s" % [p[0], shown, p[2]])
	return "\n".join(lines) if not lines.is_empty() else "(모두 기본값)"


## 연구실 머리줄: 전체 길이와 단계별 시간
static func summary() -> String:
	return "총 길이 %.2f초  (낙하 %.2f · 버팀 %.2f · 튕김 %.2f · 안착 %.2f)" % [VDUnit.appear_duration(),
		g("drop_sec"), g("hold_sec"), g("stretch_sec"), g("settle_sec")]


## 낙하 지점을 예고하는 균열(포털). 소환이 시작될 때.
static func play_portal(vfx: VDVfx, ground: Node, foot: Vector2, boss: bool) -> void:
	if g("portal") <= 0.0:
		return
	vfx.loop("portal", ground, foot, maxf(g("portal_sec"), 0.01) * (1.6 if boss else 1.0), g("portal") * (1.5 if boss else 1.0), 0.0,
		Color(1.0, 0.8, 1.0), Vector2(1.0, 0.5), 0.3, 2.5)


## 강적 예고: 크고 오래 소용돌이치는 붉은 기 도는 균열 + 바닥 마법진. 괴성과 함께 화면이 낮게 웅웅 떨린다.
static func play_champion_warn(vfx: VDVfx, ground: Node, camera: VDCamera, foot: Vector2) -> void:
	var k := g("champ_portal")
	var sec := maxf(g("portal_sec"), 0.01) * 1.6 + g("champ_lead")
	vfx.loop("portal", ground, foot, sec, g("portal") * 1.5 * k, 0.0, Color(1.0, 0.55, 0.85), Vector2(1.0, 0.5), 0.3, 3.5)
	vfx.loop("magic_circle", ground, foot, sec, 0.2 * k, 0.0, Color(0.9, 0.35, 0.8, 0.7), Vector2(1.0, 0.5), 0.35, -0.8)
	if camera:
		camera.shake(g("champ_rumble"))


## 강적 착지: 보스 타격 + 두 겹 충격파·위로 솟는 번개·처치급 폭발광, 더 센 흔들림과 히트스탑.
static func play_champion_impact(vfx: VDVfx, ground: Node, fx: Node, camera: VDCamera, foot: Vector2, top: float) -> void:
	play_impact(vfx, ground, fx, null, foot, true)
	var k := g("champ_impact")
	vfx.spawn("shockwave", ground, foot, g("shockwave") * g("boss_impact") * k * 1.5, 0.0, Color(1.0, 0.45, 0.8, 0.85), Vector2(1.0, 0.42), false, 1.0)
	vfx.spawn("kill_burst", fx, foot + Vector2(0, top * 0.5), 1.4 * k, randf() * TAU, Color(0.95, 0.6, 1.0))
	vfx.spawn("lightning", fx, foot + Vector2(0, top * 0.9), 0.55 * k, 0.0, Color(1.0, 0.6, 0.95))
	vfx.spawn("dust", ground, foot, g("dust") * g("boss_impact") * k, 0.0, Color(0.85, 0.75, 1.0, 0.9), Vector2.ONE, true)
	if camera:
		camera.shake(g("champ_shake"))
		if g("champ_hitstop") > 0.0:
			camera.hitstop(g("champ_hitstop"))


## 바닥에 꽂히는 순간의 타격감: 충격파·먼지·바닥 섬광 + 화면 흔들림·히트스탑.
static func play_impact(vfx: VDVfx, ground: Node, fx: Node, camera: VDCamera, foot: Vector2, boss: bool) -> void:
	var big := g("boss_impact") if boss else 1.0
	if g("shockwave") > 0.0:
		vfx.spawn("shockwave", ground, foot, g("shockwave") * big, 0.0, Color(0.8, 0.5, 1.0, 0.8), Vector2(1.0, 0.42), false, 1.4)
	if g("dust") > 0.0:
		vfx.spawn("dust", ground, foot, g("dust") * big, 0.0, Color(0.85, 0.75, 1.0, 0.9))
	if g("burst") > 0.0:
		vfx.spawn("burst", ground, foot, g("burst") * big, 0.0, Color(1.0, 0.8, 1.0, 0.85), Vector2(1.6, 0.5), false, 1.6)
	if boss:
		vfx.spawn("slam", fx, foot, 1.6, 0.0, Color(0.8, 0.6, 1.0))
	if camera:
		camera.shake(minf(g("shake") * big, 1.0))
		if g("hitstop") > 0.0:
			camera.hitstop(g("hitstop") * big)
