## 카툰 몬스터 피격 파티클 조절값 + 재생. VFX연구 저장소의 "몬스터 피격" 예제(vfx/monster_hit/monster_hit.gd)를 그대로 가져왔다.
##   코어 플래시(별 3톤 + 어두운 테두리) · 타격 선 · 충격파 링(침식 맵) · 스파크(속도 방향 늘림) · 체액 방울(중력)
## vd_hit_fx.gd 와 같은 모양(PARAMS · g · set_value · save · load_saved · reset · describe · summary)이라 연출 연구실("몬스터 피격 · 카툰")이 그대로 다룬다.
## 연구실에서 바꾸고 저장하면 user://cartoon_hit_fx.json 에 남아 실제 전투에도 그대로 쓰인다.
## 키 이름은 monster_hit.gd 의 @export 이름과 같다 (spawn 이 그대로 넣는다). 색은 "키_r/_g/_b" 세 줄.
## "on" 이 1 이면 전투에서 아군이 몬스터를 때릴 때(VDBattle._hit_vfx) 직업별 스파크 대신 이것을 쓴다.
## class_name 없음: preload 해서 쓴다.
extends RefCounted

const MonsterHit := preload("res://vfx/monster_hit/monster_hit.gd")
const SAVE_PATH := "user://cartoon_hit_fx.json"
const TRANS_NAMES := []          # 곡선 고르는 옵션 없음 (연구실 공용 인터페이스)
const LIVE_MAX := 24             # 동시에 살아 있는 최대 개수 (넘으면 오래된 것부터 지움)

## [키, 그룹, 이름, 최소, 최대, 단계, 기본값]
const PARAMS := [
	["on",                "0 사용",       "전투 몬스터 피격에 사용 (0=기존, 1=카툰)", 0.0, 1.0, 1.0, 1.0],
	["scale",             "1 크기",       "전체 크기 (1 = 몸통 200px 기준)",   0.1, 2.0, 0.01, 0.4],
	["heavy_k",           "1 크기",       "강타 크기 배 (기사·치명타)",        0.5, 2.5, 0.01, 1.3],
	["flash_life",        "2 코어 플래시", "수명(초)",                          0.03, 0.4, 0.005, 0.135],
	["flash_size",        "2 코어 플래시", "크기(px)",                          50.0, 400.0, 1.0, 205.0],
	["flash_stretch",     "2 코어 플래시", "타격 방향 늘림",                    0.5, 2.5, 0.05, 1.5],
	["flash_push",        "2 코어 플래시", "몸 쪽으로 밀어 넣기(px)",           0.0, 60.0, 1.0, 16.0],
	["flash_back_taper",  "2 코어 플래시", "뒤쪽 가시 줄임(배)",                1.0, 3.0, 0.05, 1.9],
	["flash_rim",         "2 코어 플래시", "어두운 테두리 두께",                0.0, 0.2, 0.005, 0.09],
	["flash_erode",       "2 코어 플래시", "갉아먹는 세기",                     0.0, 2.0, 0.05, 0.9],
	["flash_hot_until",   "2 코어 플래시", "흰 코어 남는 비율",                 0.0, 1.0, 0.05, 0.5],
	["streak_life",       "3 타격 선",    "수명(초, 0=끔)",                    0.0, 0.3, 0.005, 0.1],
	["streak_length",     "3 타격 선",    "길이(px)",                          50.0, 600.0, 5.0, 270.0],
	["streak_width",      "3 타격 선",    "굵기(px)",                          2.0, 40.0, 0.5, 18.0],
	["ring_delay",        "4 충격파 링",  "시작 지연(초)",                     0.0, 0.2, 0.005, 0.05],
	["ring_life",         "4 충격파 링",  "수명(초, 0=끔)",                    0.0, 0.5, 0.005, 0.16],
	["ring_size",         "4 충격파 링",  "크기(px)",                          60.0, 500.0, 5.0, 230.0],
	["ring_width",        "4 충격파 링",  "시작 두께",                         0.0, 0.15, 0.005, 0.05],
	["ring_erode",        "4 충격파 링",  "끊김 세기",                         0.0, 1.5, 0.05, 0.25],
	["ring_cut",          "4 충격파 링",  "그리기 멈추는 진행도",              0.3, 1.0, 0.01, 0.82],
	["spark_amount",      "5 스파크",     "개수",                              0.0, 64.0, 1.0, 12.0],
	["spark_life",        "5 스파크",     "수명(초)",                          0.05, 1.0, 0.01, 0.24],
	["spark_life_random", "5 스파크",     "수명 흩어짐",                       0.0, 1.0, 0.05, 0.35],
	["spark_speed_min",   "5 스파크",     "속도 최소(px/초)",                  0.0, 3000.0, 10.0, 900.0],
	["spark_speed_max",   "5 스파크",     "속도 최대(px/초)",                  0.0, 3000.0, 10.0, 1600.0],
	["spark_damping_min", "5 스파크",     "감쇠 최소",                         0.0, 6000.0, 50.0, 1500.0],
	["spark_damping_max", "5 스파크",     "감쇠 최대",                         0.0, 6000.0, 50.0, 2200.0],
	["spark_spread",      "5 스파크",     "퍼짐 각도(도)",                     0.0, 180.0, 1.0, 40.0],
	["spark_gravity",     "5 스파크",     "중력",                              -2000.0, 3000.0, 50.0, 600.0],
	["spark_scale_min",   "5 스파크",     "크기 최소",                         0.05, 2.0, 0.01, 0.22],
	["spark_scale_max",   "5 스파크",     "크기 최대",                         0.05, 2.0, 0.01, 0.7],
	["spark_stretch",     "5 스파크",     "속도 방향 늘림(배)",                1.0, 6.0, 0.1, 3.4],
	["spark_rim",         "5 스파크",     "어두운 테두리 두께",                0.0, 0.3, 0.005, 0.11],
	["ichor_amount",      "6 체액",       "개수",                              0.0, 64.0, 1.0, 10.0],
	["ichor_delay",       "6 체액",       "시작 지연(초)",                     0.0, 0.3, 0.005, 0.05],
	["ichor_life",        "6 체액",       "수명(초)",                          0.05, 1.5, 0.01, 0.3],
	["ichor_speed_min",   "6 체액",       "속도 최소(px/초)",                  0.0, 3000.0, 10.0, 620.0],
	["ichor_speed_max",   "6 체액",       "속도 최대(px/초)",                  0.0, 3000.0, 10.0, 1100.0],
	["ichor_damping_min", "6 체액",       "감쇠 최소",                         0.0, 3000.0, 50.0, 200.0],
	["ichor_damping_max", "6 체액",       "감쇠 최대",                         0.0, 3000.0, 50.0, 400.0],
	["ichor_spread",      "6 체액",       "퍼짐 각도(도)",                     0.0, 180.0, 1.0, 38.0],
	["ichor_gravity",     "6 체액",       "중력",                              -1000.0, 5000.0, 50.0, 1900.0],
	["ichor_lift",        "6 체액",       "위로 드는 정도 (0=정확히 뒤로)",    0.0, 2.0, 0.05, 1.25],
	["ichor_scale_min",   "6 체액",       "크기 최소",                         0.05, 2.0, 0.01, 0.14],
	["ichor_scale_max",   "6 체액",       "크기 최대",                         0.05, 2.0, 0.01, 0.42],
	["ichor_stretch",     "6 체액",       "속도 방향 늘림(배)",                1.0, 4.0, 0.1, 1.9],
	["col_hot_r",         "7 색", "불꽃 흰 코어 R", 0.0, 2.0, 0.01, 1.0],
	["col_hot_g",         "7 색", "불꽃 흰 코어 G", 0.0, 2.0, 0.01, 0.98],
	["col_hot_b",         "7 색", "불꽃 흰 코어 B", 0.0, 2.0, 0.01, 0.9],
	["col_mid_r",         "7 색", "불꽃 노랑 R", 0.0, 1.0, 0.01, 1.0],
	["col_mid_g",         "7 색", "불꽃 노랑 G", 0.0, 1.0, 0.01, 0.82],
	["col_mid_b",         "7 색", "불꽃 노랑 B", 0.0, 1.0, 0.01, 0.25],
	["col_body_r",        "7 색", "불꽃 주황 R", 0.0, 1.0, 0.01, 1.0],
	["col_body_g",        "7 색", "불꽃 주황 G", 0.0, 1.0, 0.01, 0.42],
	["col_body_b",        "7 색", "불꽃 주황 B", 0.0, 1.0, 0.01, 0.1],
	["col_rim_r",         "7 색", "어두운 테두리 R", 0.0, 1.0, 0.01, 0.16],
	["col_rim_g",         "7 색", "어두운 테두리 G", 0.0, 1.0, 0.01, 0.04],
	["col_rim_b",         "7 색", "어두운 테두리 B", 0.0, 1.0, 0.01, 0.06],
	["col_ring_hot_r",    "7 색", "링 가장자리 R", 0.0, 1.0, 0.01, 1.0],
	["col_ring_hot_g",    "7 색", "링 가장자리 G", 0.0, 1.0, 0.01, 0.95],
	["col_ring_hot_b",    "7 색", "링 가장자리 B", 0.0, 1.0, 0.01, 0.75],
	["col_ring_r",        "7 색", "링 R", 0.0, 1.0, 0.01, 1.0],
	["col_ring_g",        "7 색", "링 G", 0.0, 1.0, 0.01, 0.6],
	["col_ring_b",        "7 색", "링 B", 0.0, 1.0, 0.01, 0.18],
	["col_ichor_r",       "7 색", "체액 R", 0.0, 1.0, 0.01, 0.78],
	["col_ichor_g",       "7 색", "체액 G", 0.0, 1.0, 0.01, 0.16],
	["col_ichor_b",       "7 색", "체액 B", 0.0, 1.0, 0.01, 0.5],
	["col_ichor_hi_r",    "7 색", "체액 하이라이트 R", 0.0, 1.0, 0.01, 1.0],
	["col_ichor_hi_g",    "7 색", "체액 하이라이트 G", 0.0, 1.0, 0.01, 0.55],
	["col_ichor_hi_b",    "7 색", "체액 하이라이트 B", 0.0, 1.0, 0.01, 0.8],
	["col_ichor_rim_r",   "7 색", "체액 테두리 R", 0.0, 1.0, 0.01, 0.14],
	["col_ichor_rim_g",   "7 색", "체액 테두리 G", 0.0, 1.0, 0.01, 0.02],
	["col_ichor_rim_b",   "7 색", "체액 테두리 B", 0.0, 1.0, 0.01, 0.1],
]
## PARAMS 중 monster_hit.gd 에 넣지 않는 키 (이 스크립트가 쓰는 값)
const OWN_KEYS := ["on", "scale", "heavy_k"]
const INT_KEYS := ["spark_amount", "ichor_amount"]
const COLOR_BASES := ["col_hot", "col_mid", "col_body", "col_rim", "col_ring_hot", "col_ring", "col_ichor", "col_ichor_hi", "col_ichor_rim"]

static var values := {}
static var version := 0
static var _loaded := false
static var _live: Array = []     # 오래된 것부터 (weakref)


static func defaults() -> Dictionary:
	var d := {}
	for p in PARAMS:
		d[p[0]] = float(p[6])
	return d


static func g(key: String) -> float:
	if not _loaded:
		load_saved()
	return float(values.get(key, 0.0))


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
	return "%s  ·  크기 x%.2f (강타 x%.2f)  ·  스파크 %d · 체액 %d" % [
		"전투에 사용" if g("on") >= 0.5 else "전투에는 기존 파티클", g("scale"), g("heavy_k"), int(g("spark_amount")), int(g("ichor_amount"))]


static func enabled() -> bool:
	return g("on") >= 0.5


## 한 번 재생. dir = 타격이 밀고 가는 방향(공격자 → 대상). 끝나면 스스로 지운다.
static func spawn(parent: Node, pos: Vector2, dir: Vector2, heavy := false) -> Node2D:
	if parent == null:
		return null
	_trim()
	var h: Node2D = MonsterHit.new()
	for p in PARAMS:
		var key: String = p[0]
		if key in OWN_KEYS or key.begins_with("col_"):
			continue
		h.set(key, int(g(key)) if key in INT_KEYS else g(key))
	for base in COLOR_BASES:
		h.set(base, Color(g(base + "_r"), g(base + "_g"), g(base + "_b")))
	h.size = g("scale") * (g("heavy_k") if heavy else 1.0)
	h.hit_dir = dir if dir.length() > 0.01 else Vector2.RIGHT
	h.seed_value = randi()
	h.position = pos
	parent.add_child(h)
	h.play()
	# 가장 늦게 끝나는 레이어(체액: 지연 + 수명 × 흩어짐 여유) 뒤에 지운다
	var life := maxf(maxf(g("ichor_delay") + g("ichor_life") * 1.2, maxf(g("spark_life"), g("ring_delay") + g("ring_life"))),
		maxf(g("flash_life"), g("streak_life"))) + 0.1
	h.get_tree().create_timer(life, false).timeout.connect(func() -> void:
		if is_instance_valid(h):
			h.queue_free())
	_live.append(weakref(h))
	return h


## 동시에 너무 많으면 가장 오래된 것부터 지운다
static func _trim() -> void:
	_live = _live.filter(func(w: WeakRef) -> bool: return w.get_ref() != null)
	while _live.size() >= LIVE_MAX and not _live.is_empty():
		var old = _live.pop_front().get_ref()
		if old:
			old.queue_free()
