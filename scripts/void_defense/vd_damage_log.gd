## 피해 숫자 — 헥스 블레이드 scripts/presentation/damage_log.gd 를 그대로 가져와 2D(Camera2D) 화면에 맞춘 것.
## 연출·그래픽·ARCO 글꼴은 원본 그대로이고, 바뀐 것은 셋뿐이다:
##   - 월드 점이 Vector3 → Vector2 (Camera2D 의 캔버스 변환으로 화면에 투영)
##   - 글자 크기: 원본 34/54 (1280×800) → 이 게임(1920×1080, 원화 캐릭터 150px) 기준 40/60
##   - J 키 프리셋 전환은 뺐다 (기본 BOUNCE, --dmglog=stack 인자는 유지)
## 원본 설명:
##   크게 튀어나오는 팝 · 세로 눌림 · 위로 튀는 포물선 · 강타 기울기 · ARCO 글꼴.
##   불투명 짙은 남보라 두꺼운 외곽선 + 아래 그림자. 강타는 첫 0.1초 흰빛으로 번쩍였다가 노랑.
##   연속 타격 열기: 같은 대상을 끊김 없이(0.75초 안에 다음 타격) 때릴수록 크림 → 노랑 → 주황 → 붉은 분홍.
##   BOUNCE — 위로 튀어 올랐다가 중력으로 떨어지며 사라짐 (기본) / STACK — 머리 위에 쌓이는 기둥.
##   숫자는 전장(월드)에 캐릭터와 같은 층으로 그린다: 생긴 월드 점 + 월드 오프셋. 카메라가 움직이면 함께 움직인다.
##   크기·이동량은 월드 px (전투 줌 1.18 기준 화면에서 원본보다 살짝 작게). 글자는 화면 배율만큼 큰 크기로 래스터해서
##   줌인돼도 흐려지지 않게 그린다. 실제 시간(히트스탑·슬로모션에 멈추지 않게).
class_name VDDamageLog
extends Node2D

# ── 크기 · 색 (월드 px) ──
const SIZE := 32.0
const SIZE_BIG := 48.0
const SIZE_STATUS := 27.0
const FLASH := Color("ffffff")
const INK := Color("1b0b38")          # 외곽선
const OUTLINE := 0.26                 # 외곽선 두께 = 글자 크기 × 이 값
const SHADOW := Color(0.04, 0.0, 0.10, 0.55)
const SHADOW_OFF := 0.09

# ── 시간 ──
const LIFE := 0.95
const LIFE_BIG := 1.2
const LIFE_STATUS := 1.1
const FADE_FROM := 0.68
const POP := 1.55
const POP_BIG := 1.8
const POP_T := 0.13
const SQUASH := 0.45
const SQUASH_T := 0.08
const FLASH_T := 0.1

# ── 움직임 (화면 px) ──
const RISE := 290.0
const RISE_RAND := 0.3
const ARC_SPREAD := 36.0
const GRAVITY := 1200.0
const DRAG := 0.90
const SINK := 18.0
const JITTER := Vector2(14, 5)
const TILT := 0.10
const TILT_BIG := 11.0
const SPIN := 0.6
const MAX := 24
const PER_TARGET := 6
const STACK := 0.68
const STACK_RATE := 22.0
const EDGE := 12.0

# ── BOUNCE 프리셋 ──
const B_RISE := 380.0
const B_SPREAD := 70.0
const B_GRAVITY := 1250.0
const B_DRAG := 0.985
const B_LIFE := 0.85
const B_LIFE_BIG := 1.0
const B_FADE_FROM := 0.55
const B_SPIN := 1.2

const PRESETS := ["stack", "bounce"]
static var preset := "bounce"
static var _arg_read := false

# ── 연속 타격 열기 (heat 0 → 1) ──
const CHAIN_GAP := 0.75
const CHAIN_FULL := 14
const HEAT_RAMP := [Color("fffaf0"), Color("fff1a0"), Color("ffc93a"), Color("ff8a2a"), Color("ff3b5c")]
const HEAT_BIG_MIN := 0.4
const HEAT_INK := Color("3d0717")
const HEAT_GLOW := Color("ff6a1e")
const HEAT_SIZE := 0.1
const HEAT_POP := 0.12
const POP_MAX := 1.9
const HEAT_SQUASH := 0.05
const HEAT_TILT := 0.3
const HEAT_RISE := 0.08
const HEAT_LIFE := 0.1
const HEAT_SHAKE := 1.5
const HEAT_GLOW_A := 0.22
const HEAT_GLOW_W := 0.08

static var _font: Font

var entries: Array = []
var _last_us := 0
var _chain := {}
var count_spawned := 0          # 테스트용


static func use(name := "") -> String:
	if name == "":
		name = PRESETS[(PRESETS.find(preset) + 1) % PRESETS.size()]
	if name in PRESETS:
		preset = name
	return preset


static func _read_arg() -> void:
	if _arg_read:
		return
	_arg_read = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dmglog="):
			use(a.substr(9))


static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/ARCO.otf") as Font
		if _font == null:
			_font = ThemeDB.fallback_font
	return _font


func _ready() -> void:
	_read_arg()


func _heat(target: Object) -> float:
	if target == null:
		return 0.0
	var now := Time.get_ticks_msec() * 0.001
	var id := target.get_instance_id()
	var c: Array = _chain.get(id, [0, -99.0])
	var n: int = (int(c[0]) + 1) if now - float(c[1]) < CHAIN_GAP else 1
	_chain[id] = [n, now]
	if _chain.size() > 64:
		for k in _chain.keys():
			if now - float(_chain[k][1]) > CHAIN_GAP:
				_chain.erase(k)
	return clampf(float(n - 1) / float(CHAIN_FULL - 1), 0.0, 1.0)


func chain_of(target: Object) -> int:
	if target == null or not _chain.has(target.get_instance_id()):
		return 0
	var c: Array = _chain[target.get_instance_id()]
	return int(c[0]) if Time.get_ticks_msec() * 0.001 - float(c[1]) < CHAIN_GAP else 0


static func heat_color(h: float) -> Color:
	var x := clampf(h, 0.0, 1.0) * (HEAT_RAMP.size() - 1)
	var i := mini(int(x), HEAT_RAMP.size() - 2)
	return (HEAT_RAMP[i] as Color).lerp(HEAT_RAMP[i + 1], x - i)


## 새 숫자 하나. anchor 는 월드(캔버스) 좌표.
func spawn(anchor: Vector2, value: int, big: bool, target: Object = null) -> Dictionary:
	var h := _heat(target)
	var bounce := preset == "bounce"
	var half := deg_to_rad(B_SPREAD if bounce else ARC_SPREAD) * 0.5
	var ang := -PI * 0.5 + randf_range(-1.0, 1.0) * half
	var spd := (B_RISE if bounce else RISE) * (1.0 + randf_range(-RISE_RAND, RISE_RAND) * 0.5) * (1.12 if big else 1.0) * (1.0 + HEAT_RISE * h)
	var tilt := 1.0 + HEAT_TILT * h
	var e := {
		"anchor": anchor,
		"off": Vector2(randf_range(-0.5, 0.5) * JITTER.x, randf_range(-0.5, 0.5) * JITTER.y),
		"vx": cos(ang) * spd,
		"vy": sin(ang) * spd,
		"rot": (randf_range(-1.0, 1.0) * deg_to_rad(TILT_BIG) if big else randf_range(-TILT, TILT)) * tilt,
		"vr": (cos(ang) * B_SPIN + randf_range(-0.3, 0.3)) if bounce else randf_range(-SPIN, SPIN),
		"t": 0.0,
		"life": ((B_LIFE_BIG if big else B_LIFE) if bounce else (LIFE_BIG if big else LIFE)) + HEAT_LIFE * h,
		"mode": preset,
		"big": big,
		"value": value,
		"text": str(value),
		"col": heat_color(maxf(h, HEAT_BIG_MIN) if big else h),
		"target": weakref(target) if target else null,
		"born": Time.get_ticks_msec() * 0.001,
		"status": false,
		"pop": minf((POP_BIG if big else POP) + HEAT_POP * h, POP_MAX),
		"lift": 0.0,
		"lift_to": 0.0,
		"heat": h,
	}
	if not bounce:
		_stack(e)
	_push(e)
	return e


func _stack(e: Dictionary) -> void:
	if e.target == null:
		return
	var tgt: Object = e.target.get_ref()
	if tgt == null:
		return
	var push := (SIZE_BIG if e.big else SIZE) * (1.0 + HEAT_SIZE * float(e.heat)) * STACK
	var mine: Array = []
	for o: Dictionary in entries:
		if o.mode == "stack" and o.target != null and o.target.get_ref() == tgt and float(o.t) < float(o.life) * FADE_FROM:
			o.lift_to = float(o.lift_to) + push
			mine.append(o)
	var extra := mine.size() + 1 - PER_TARGET
	for i in maxi(0, extra):
		var o: Dictionary = mine[i]
		o.t = maxf(float(o.t), float(o.life) * FADE_FROM)


func bump(e: Dictionary) -> void:
	e.t = minf(float(e.t), 0.03)


## 상태 글자 (포물선 없이 감속하며 떠오름). 회복 "+N", 정수 획득 등에 쓴다.
func spawn_status(anchor: Vector2, text: String, col: Color, target: Object = null) -> void:
	var top := 0.0
	for o: Dictionary in entries:
		if not o.status and target != null and o.target != null and o.target.get_ref() == target:
			top = maxf(top, float(o.lift_to) + (SIZE_BIG if o.big else SIZE) * 0.5)
	_push({
		"anchor": anchor, "off": Vector2(0, -36.0 - top), "vx": 0.0, "vy": -72.0,
		"rot": 0.0, "vr": 0.0, "t": 0.0, "life": LIFE_STATUS, "big": false, "value": 0, "text": text, "col": col,
		"target": weakref(target) if target else null, "born": Time.get_ticks_msec() * 0.001, "status": true, "pop": POP,
		"lift": 0.0, "lift_to": 0.0, "heat": 0.0, "mode": "status",
	})


func _push(e: Dictionary) -> void:
	count_spawned += 1
	entries.append(e)
	if entries.size() > MAX:
		entries = entries.slice(entries.size() - MAX)


func _process(_dt: float) -> void:
	var us := Time.get_ticks_usec()
	var dt := 0.0 if _last_us == 0 else minf((us - _last_us) * 1e-6, 0.1)
	_last_us = us
	if entries.is_empty():
		return
	var drag := pow(DRAG, dt * 60.0)
	var bdrag := pow(B_DRAG, dt * 60.0)
	var keep: Array = []
	for e: Dictionary in entries:
		e.t = float(e.t) + dt
		e.lift = lerpf(float(e.lift), float(e.lift_to), 1.0 - exp(-STACK_RATE * dt))
		if e.status:
			e.off.y += float(e.vy) * dt
			e.vy = float(e.vy) * pow(0.93, dt * 60.0)
		elif e.mode == "bounce":
			e.vy = (float(e.vy) + B_GRAVITY * dt) * bdrag
			e.vx = float(e.vx) * bdrag
			e.off += Vector2(e.vx, e.vy) * dt
			e.rot = float(e.rot) + float(e.vr) * dt
		else:
			e.vy = minf((float(e.vy) + GRAVITY * dt) * drag, SINK)
			e.vx = float(e.vx) * drag
			e.off += Vector2(e.vx, e.vy) * dt
			e.vr = float(e.vr) * pow(0.95, dt * 60.0)
			e.rot = float(e.rot) + float(e.vr) * dt
		if float(e.t) < float(e.life):
			keep.append(e)
	entries = keep
	queue_redraw()


func _draw() -> void:
	if entries.is_empty():
		return
	# 월드에 그린다. 글자는 화면 배율(z)만큼 큰 크기로 래스터한 뒤 1/z 로 줄여 줌인돼도 선명하게
	var z := maxf(get_canvas_transform().get_scale().x, 0.1)
	var f := font()
	for e: Dictionary in entries:
		var t := float(e.t)
		var k := t / float(e.life)
		var fade_from := B_FADE_FROM if e.mode == "bounce" else FADE_FROM
		var pop := 1.0 + (float(e.pop) - 1.0) * maxf(0.0, 1.0 - t / POP_T)
		var shrink := 1.0 - 0.25 * smoothstep(fade_from, 1.0, k)
		var h := float(e.heat)
		var sq_y := 1.0 + (SQUASH + HEAT_SQUASH * h) * maxf(0.0, 1.0 - t / SQUASH_T)
		var sq_x := 1.0 / maxf(0.55, sq_y)
		var base := SIZE_STATUS if e.status else (SIZE_BIG if e.big else SIZE)
		var want := maxf(8.0, base * (1.0 + HEAT_SIZE * h) * pop * shrink)
		var sz: int = (roundi(base * z * 0.5) * 2) if want < base * 1.3 else (roundi(base * z * 0.8) * 2)
		var sc := want / float(sz)
		var a := 1.0 - smoothstep(fade_from, 1.0, k)
		var text: String = e.text
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var at := Vector2(-tw * 0.5, (f.get_ascent(sz) - f.get_descent(sz)) * 0.5)
		var p: Vector2 = (e.anchor as Vector2) + (e.off as Vector2) - Vector2(0, float(e.lift))
		if h > 0.0 and t < 0.2:
			p += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * HEAT_SHAKE * h * (1.0 - t / 0.2)
		var ol := maxi(4, roundi(sz * OUTLINE))
		draw_set_transform(p, float(e.rot), Vector2(sq_x, sq_y) * sc)
		draw_string_outline(f, at + Vector2(0, sz * SHADOW_OFF), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, ol, Color(SHADOW, SHADOW.a * a))
		if h > 0.05:
			var ga := HEAT_GLOW_A * (0.6 + 0.4 * maxf(0.0, 1.0 - t / 0.25)) * h * a
			draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, ol + roundi(sz * HEAT_GLOW_W * snappedf(h, 0.25)) + 2, Color(HEAT_GLOW, ga))
		draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, ol, Color(INK.lerp(HEAT_INK, h), a))
		var c: Color = e.col
		if e.big:
			c = FLASH.lerp(c, smoothstep(0.0, FLASH_T, t))
		draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(c, a))
	draw_set_transform(Vector2.ZERO)
