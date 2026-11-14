## UI 등장 애니메이션 공용 헬퍼 (2026-11-09): 모션 그래픽처럼 메뉴·HUD 조각이 각자의 방향에서 화면 안쪽으로
## 미끄러져 들어오고(살짝 넘치고 되돌아오는 탄성), 시각적 위계대로 시간차를 두어 차례로 나타난다.
## 로비(scripts/lobby.gd)와 VOID DEFENSE 전투 입장(vd_battle.gd · vd_battle_frame.gd)이 쓴다.
##
## 자리는 Control 의 offset_* 를 통째로 밀어서 잡는다: anchor(SceneSwitcher.pin)는 그대로라 애니메이션 중에 창 크기가
## 바뀌어도 제자리를 다시 찾고, 끝나면 원래 offset 으로 정확히 돌아온다.
## Tween 을 쓰지 않고 조각마다 붙는 작은 러너 노드(이 클래스)가 자기 시계로 돈다: 씬 전환 직후·셰이더 첫 컴파일처럼
## 한 프레임이 길어지면 Tween/타이머는 그 프레임에 끝까지 뛰어 등장 연출이 통째로 사라지는데, 러너는 프레임 간격을
## MAX_DT 로 잘라 그런 순간에도 애니메이션이 보인다. time_scale 과 무관한 실제 시간이다.
## 모든 함수는 호출 즉시 '숨은 상태'(밀려난 자리 · 투명)를 만들어 첫 프레임부터 보이지 않게 한다 (_ready 안에서 부르면 된다).
class_name UIIntro
extends Node

signal finished   # 이 조각의 모든 트랙이 끝남 (바로 뒤에 스스로 지워진다)

const DUR := 0.5        # 기본 길이 (초)
const DIST := 160.0     # 기본 이동 거리 (디자인 px)
const MAX_DT := 1.0 / 24.0
const FROM_LEFT := Vector2(-1, 0)
const FROM_RIGHT := Vector2(1, 0)
const FROM_TOP := Vector2(0, -1)
const FROM_BOTTOM := Vector2(0, 1)

enum Ease { BACK, QUINT, SINE }

var target: Control
var _tracks: Array[Dictionary] = []   # {kind, delay, dur, ease, ...}
var _t := 0.0
var _clock_us := 0


## c 를 dir 쪽(화면 바깥)에서 delay 초 뒤 dur 동안 제자리로. fade 면 투명 → 불투명도 함께. 반환한 러너의 finished 로 이어 쓸 수 있다.
## ease: Ease.BACK(기본, 살짝 넘침) · Ease.QUINT(큰 그림, 넘침 없음) · Ease.SINE.
static func slide(c: Control, dir: Vector2, delay: float, dur := DUR, dist := DIST, fade := true, ease := Ease.BACK) -> UIIntro:
	var r := _runner(c)
	var base := PackedFloat32Array([c.offset_left, c.offset_right, c.offset_top, c.offset_bottom])
	r._tracks.append({"kind": "slide", "delay": delay, "dur": dur, "ease": ease, "base": base, "d": dir.normalized() * dist})
	if fade:
		r._tracks.append({"kind": "fade", "a0": _alpha_of(c), "delay": delay, "dur": minf(dur * 0.55, 0.3), "ease": Ease.SINE})
	r._apply(0.0)
	return r


## c 가 가운데에서 from 배율로 작게 시작해 제 크기로 톡 커진다 (달·아이콘·배지).
static func pop(c: Control, delay: float, dur := 0.45, from := 0.5, fade := true) -> UIIntro:
	var r := _runner(c)
	var center := func() -> void: c.pivot_offset = c.size * 0.5
	center.call()
	if not c.has_meta(&"_uiintro_pivot"):   # 람다는 매번 새것이라 is_connected 로는 중복을 못 막는다
		c.set_meta(&"_uiintro_pivot", true)
		c.resized.connect(center)
	r._tracks.append({"kind": "pop", "delay": delay, "dur": dur, "ease": Ease.BACK, "from": from})
	if fade:
		r._tracks.append({"kind": "fade", "a0": _alpha_of(c), "delay": delay, "dur": minf(dur * 0.5, 0.25), "ease": Ease.SINE})
	r._apply(0.0)
	return r


## 투명 → 불투명만 (바탕 띠 · 안내 문구).
static func fade(c: Control, delay: float, dur := 0.4) -> UIIntro:
	var r := _runner(c)
	r._tracks.append({"kind": "fade", "a0": _alpha_of(c), "delay": delay, "dur": dur, "ease": Ease.SINE})
	r._apply(0.0)
	return r


## 여러 개를 같은 방향에서 step 초 간격으로 차례로. 마지막 것이 시작하는 시각(delay 누적)을 돌려준다.
static func stagger(items: Array, dir: Vector2, delay: float, step := 0.08, dur := DUR, dist := DIST, ease := Ease.BACK) -> float:
	var t := delay
	for c in items:
		if c is Control:
			slide(c, dir, t, dur, dist, true, ease)
			t += step
	return t - step


## c 에 붙은 러너 (없으면 만든다). 한 조각에 여러 트랙(이동 + 페이드)이 같은 시계로 돈다.
static func _runner(c: Control) -> UIIntro:
	for n in c.get_children():
		if n is UIIntro:
			return n
	var r := UIIntro.new()
	r.name = "UIIntro"
	r.target = c
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	r._clock_us = Time.get_ticks_usec()
	c.add_child(r)
	return r


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf((now - _clock_us) / 1_000_000.0, 0.0, MAX_DT)
	_clock_us = now
	_t += dt
	_apply(_t)
	for tr in _tracks:
		if _t < float(tr["delay"]) + float(tr["dur"]):
			return
	finished.emit()
	queue_free()


## 시각 t 의 모습으로 조각을 놓는다 (t = 0 이 '숨은 상태').
func _apply(t: float) -> void:
	if not is_instance_valid(target):
		return
	for tr in _tracks:
		var k := clampf((t - float(tr["delay"])) / maxf(float(tr["dur"]), 0.001), 0.0, 1.0)
		var e := _ease(k, tr["ease"])
		match tr["kind"]:
			"slide":
				var base: PackedFloat32Array = tr["base"]
				var d: Vector2 = tr["d"] * (1.0 - e)
				target.offset_left = base[0] + d.x
				target.offset_right = base[1] + d.x
				target.offset_top = base[2] + d.y
				target.offset_bottom = base[3] + d.y
			"fade":
				target.modulate.a = e * float(tr["a0"])
			"pop":
				target.scale = Vector2.ONE * lerpf(float(tr["from"]), 1.0, e)


## 페이드가 끝날 알파: 컨트롤 자신의 반투명(예: 로비 원화 0.92)을 지킨다. 이미 숨겨진 채(0)면 1.
static func _alpha_of(c: Control) -> float:
	return c.modulate.a if c.modulate.a > 0.01 else 1.0


static func _ease(x: float, kind: int) -> float:
	match kind:
		Ease.BACK:
			return back_out(x)
		Ease.QUINT:
			return 1.0 - pow(1.0 - x, 5.0)
		_:
			return sin(x * PI * 0.5)


## 0→1 입력을 '살짝 넘치고 되돌아오는' 탄성 곡선으로 (Tween.TRANS_BACK EASE_OUT 과 같은 모양). 직접 그리는 요소도 쓴다.
static func back_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var y := x - 1.0
	return 1.0 + c3 * y * y * y + c1 * y * y
