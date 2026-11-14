## 몬스터 사망 연출 조절값 + 재생. vd_hit_fx.gd 와 같은 모양(PARAMS · g · save …)이라 연출 연구실("몬스터 사망")이 그대로 다룬다.
## 연구실에서 바꾸고 저장하면 user://kill_fx.json 에 남아 실제 전투에도 그대로 쓰인다.
##   피격 파티클(VDTouchHit) · 몸 찌그러짐→녹아내림(VDUnit._die) · 체액(VDGoo) · 화면 쇼크웨이브 · 셰이크·히트스탑·슬로모션
## play() 는 전투(VDBattle._on_unit_died)와 연구실이 같이 부른다. 정수·유물·경험치 같은 게임 쪽 처리는 전투가 따로 한다.
## PARAMS 의 def 가 코드 기본값(2026-11-09 이전 하드코딩 값과 같다). 연구실의 "값 복사" 로 받은 줄을 여기 def 에 옮기면 기본값이 된다.
## class_name 없음: preload 해서 쓴다.
extends RefCounted

const SAVE_PATH := "user://kill_fx.json"
const TRANS_NAMES := []          # 곡선 고르는 옵션 없음 (연구실 공용 인터페이스)

## [키, 그룹, 이름, 최소, 최대, 단계, 기본값]
const PARAMS := [
	["spark",        "1 피격 파티클", "별 섬광 크기 (보통 적, 0=끔)",       0.0, 1.5,  0.01, 0.0],
	["spark_boss",   "1 피격 파티클", "별 섬광 크기 (보스, 0=끔)",          0.0, 1.5,  0.01, 0.6],
	["spark_col_r",  "1 피격 파티클", "색 R",                              0.0, 1.0,  0.01, 0.9],
	["spark_col_g",  "1 피격 파티클", "색 G",                              0.0, 1.0,  0.01, 0.6],
	["spark_col_b",  "1 피격 파티클", "색 B",                              0.0, 1.0,  0.01, 1.0],
	["squash_x",     "2 몸 찌그러짐", "마지막 일격: 가로 퍼짐(배)",         0.5, 2.5,  0.01, 1.4],
	["squash_y",     "2 몸 찌그러짐", "마지막 일격: 세로 눌림(배)",         0.1, 1.5,  0.01, 0.66],
	["pop_x",        "2 몸 찌그러짐", "튀어 오름: 가로(배)",                0.3, 2.0,  0.01, 0.82],
	["pop_y",        "2 몸 찌그러짐", "튀어 오름: 세로(배)",                0.5, 2.5,  0.01, 1.22],
	["pop_sec",      "2 몸 찌그러짐", "튀어 오르는 시간(초)",               0.01, 0.6, 0.01, 0.08],
	["melt_x",       "2 몸 찌그러짐", "녹아내림: 가로(배)",                 0.3, 3.0,  0.01, 1.6],
	["melt_y",       "2 몸 찌그러짐", "녹아내림: 세로(배)",                 0.0, 1.0,  0.01, 0.12],
	["melt_sec",     "2 몸 찌그러짐", "녹아내리는 시간(초)",                0.02, 1.5, 0.01, 0.22],
	["fade_delay",   "2 몸 찌그러짐", "투명해지기 시작(초, 녹기 시작부터)", 0.0, 1.0,  0.01, 0.06],
	["fade_sec",     "2 몸 찌그러짐", "투명해지는 시간(초)",                0.02, 1.5, 0.01, 0.22],
	["goo_on",       "3 체액",        "바닥 체액 (0=끔, 1=켬)",             0.0, 1.0,  1.0,  1.0],
	["goo_size",     "3 체액",        "체액 크기(배)",                      0.2, 3.0,  0.01, 1.0],
	["goo_delay",    "3 체액",        "철퍽 시점(초)",                      0.0, 1.0,  0.01, 0.1],
	["goo_drops",    "3 체액",        "튀는 방울 수(배)",                   0.0, 3.0,  0.01, 1.0],
	["goo_alpha",    "3 체액",        "체액 불투명도 (낮을수록 덜 보임)",    0.05, 1.0, 0.01, 0.45],
	["goo_gloss",    "3 체액",        "광택 세기 (0=끔)",                   0.0, 1.0,  0.01, 0.3],
	["goo_life",     "3 체액",        "사라지기 시작까지(초)",              0.5, 30.0, 0.1,  5.0],
	["goo_fade",     "3 체액",        "스며들며 사라지는 시간(초)",          0.1, 6.0,  0.05, 2.0],
	["wave",         "4 쇼크웨이브",  "화면 일렁임 세기 (보통 적, 0=끔)",   0.0, 3.0,  0.01, 1.0],
	["wave_boss",    "4 쇼크웨이브",  "화면 일렁임 세기 (보스, 0=끔)",      0.0, 3.0,  0.01, 1.0],
	["ring_boss",    "4 쇼크웨이브",  "보스 바닥 고리 크기 (0=끔)",         0.0, 3.0,  0.01, 1.3],
	["shake",        "5 화면",        "흔들림 (보통 적)",                   0.0, 1.0,  0.01, 0.55],
	["shake_boss",   "5 화면",        "흔들림 (보스)",                      0.0, 1.0,  0.01, 1.0],
	["hitstop",      "5 화면",        "히트스탑(초, 보통 적)",              0.0, 0.4,  0.005, 0.06],
	["hitstop_boss", "5 화면",        "히트스탑(초, 보스)",                 0.0, 0.6,  0.005, 0.16],
	["slowmo_k",     "5 화면",        "슬로모션 길이(배, 0=끔)",            0.0, 3.0,  0.01, 1.0],
	["slowmo_scale", "5 화면",        "슬로모션 배속(배, 1=등급 기본)",     0.2, 3.0,  0.01, 1.0],
]

static var values := {}
static var version := 0
static var _loaded := false


static func defaults() -> Dictionary:
	var d := {}
	for p in PARAMS:
		d[p[0]] = float(p[6])
	return d


static func g(key: String) -> float:
	if not _loaded:
		load_saved()
	return float(values.get(key, 0.0))


static func col(base: String) -> Color:
	return Color(g(base + "_r"), g(base + "_g"), g(base + "_b"))


static func set_value(key: String, v: float) -> void:
	if not _loaded:
		load_saved()
	values[key] = v
	version += 1


static func load_saved() -> void:
	_loaded = true
	values = defaults()
	version += 1
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
	version += 1


## 기본값과 다른 값만 "키 = 값" 줄로
static func describe(all := false) -> String:
	var lines := PackedStringArray()
	for p in PARAMS:
		var v := g(p[0])
		if all or not is_equal_approx(v, float(p[6])):
			lines.append("%s = %s   # %s" % [p[0], str(snappedf(v, 0.001)), p[2]])
	return "\n".join(lines) if not lines.is_empty() else "(모두 기본값)"


## 연구실 머리줄
static func summary() -> String:
	return "별 섬광 x%.2f (보스 x%.2f)  ·  녹기 %.2f초  ·  체액 %s  ·  흔들림 %.2f  ·  히트스탑 %.3f초" % [
		g("spark"), g("spark_boss"), g("pop_sec") + g("melt_sec"),
		"x%.2f" % g("goo_size") if g("goo_on") >= 0.5 else "끔", g("shake"), g("hitstop")]


## 몬스터가 쓰러진 순간의 연출 (몸 찌그러짐은 VDUnit._die 가 body_tween() 으로 따로 한다).
## goo · shockwave 는 없으면(null) 건너뛴다. at = 가슴 높이.
## full = false: 임시 사망(촉수 등 부활 대기) — 흔들림·히트스탑만. (폭발 시트 kill_burst 는 2026-11-09 사용자 요청으로 뺐다)
static func play(u: VDUnit, at: Vector2, vfx: VDVfx, fx_root: Node, ground_fx: Node, camera: VDCamera, goo, shockwave, full := true) -> void:
	var boss := u.is_boss
	camera.shake(g("shake_boss" if boss else "shake"))
	var hs := g("hitstop_boss" if boss else "hitstop")
	if hs > 0.0:
		camera.hitstop(hs)
	if not full:
		return
	var sk := g("spark_boss" if boss else "spark")
	if sk > 0.0:
		vfx.spawn("burst", fx_root, at, sk, 0.0, col("spark_col"))
	if goo != null and g("goo_on") >= 0.5:
		goo.splat(u, g("goo_delay"), g("goo_size"), g("goo_drops"))
	var wk := g("wave_boss" if boss else "wave")
	if shockwave != null and wk > 0.0:
		shockwave.add(at, "boss" if boss else "kill", wk)
	if boss and g("ring_boss") > 0.0:
		vfx.spawn("shockwave", ground_fx, u.position, g("ring_boss"), 0.0, Color(0.9, 0.7, 1.0), Vector2(1.0, 0.5))
	slowmo(camera, int(VDData.ENEMIES.get(u.id, {}).get("tier", 0)))


## 등급별 사망 슬로모션 (VDData.DEATH_SLOWMO) × slowmo_k (길이) · slowmo_scale (배속). 아군 쓰러짐은 VDBattle._death_slowmo 그대로.
static func slowmo(camera: VDCamera, tier: int) -> void:
	var k := g("slowmo_k")
	if k <= 0.0:
		return
	var s: Array = VDData.DEATH_SLOWMO[clampi(tier, 0, VDData.DEATH_SLOWMO.size() - 1)]
	camera.slowmo(float(s[0]) * k, clampf(float(s[1]) * g("slowmo_scale"), 0.02, 1.0))


## 몬스터 몸: 마지막 일격에 크게 찌그러졌다가 바닥으로 녹아내리듯 납작해지며 사라진다. sx/sy = 원래 비주얼 배율(방향 포함).
static func body_tween(t: Tween, unit: VDUnit, visual: Node2D, sx: float, sy: float) -> void:
	visual.scale = Vector2(sx * g("squash_x"), sy * g("squash_y"))
	t.tween_property(visual, "scale", Vector2(sx * g("pop_x"), sy * g("pop_y")), g("pop_sec")).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(visual, "scale", Vector2(sx * g("melt_x"), sy * g("melt_y")), g("melt_sec")).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(unit, "modulate:a", 0.0, g("fade_sec")).set_delay(g("fade_delay"))
