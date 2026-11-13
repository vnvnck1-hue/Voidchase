## 타이틀 화면 (앱을 켠 뒤 한 번): 검정 → 부팅 로그 몇 줄 → 어둡게 깔린 상담소 위로 달과 로고가 뜬다 → "아무 키나 눌러 접속".
## 허브(scripts/lobby.gd) 위에 덮는 Control. 입력을 받으면 가로 줄이 닫히듯 걷히고 done 을 낸다.
## 실제 시간으로 직접 진행한다 (긴 프레임에 Tween 연출이 통째로 사라지지 않게 — UIIntro 와 같은 이유).
extends Control

signal done

const GameFonts := preload("res://scripts/game_fonts.gd")
const ART := "res://assets/textures/hub/title_static_lounge.png"   # 컨셉 원화 로비_모니터룸_2종_v12/01 의 사본
const BOOT := [
	"STATIC LOUNGE OS  v0.9.2",
	"> 뇌파 모니터 ........ OK",
	"> 다이브 체어 ........ OK",
	"> 분대 대기실 ........ 4명 대기 중",
	"> 접수함 ............. 쪽지 1건",
]
const BOOT_STEP := 0.2            # 부팅 로그 한 줄 간격
const LOGO_AT := 1.35             # 로고가 뜨는 시각
const PROMPT_AT := 2.3            # 이때부터 입력을 받는다 (그 전 입력은 연출을 끝까지 당긴다)
const OUT_SEC := 0.45

var _t := 0.0
var _clock_us := 0
var _out := -1.0                  # >= 0 이면 걷히는 중 (경과)
var _art: TextureRect
var _black: ColorRect
var _boot: Label
var _moon: Control
var _logo: Label
var _sub: Label
var _prompt: Label
var _notice: Label
var _ver: Label
var _bars: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	var th := Theme.new()
	th.default_font = VDData.font()
	theme = th
	_black = ColorRect.new()
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.color = Color(0.02, 0.012, 0.05)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	if ResourceLoader.exists(ART):
		_art = UiKit.cover(load(ART))
		_art.modulate = Color(0.42, 0.36, 0.62, 0.0)
		add_child(_art)
	# 달: 오른쪽 위에서 천천히 떠오른다 (기획서: 큰 달 = 밤새 켜 둔 스탠드)
	_moon = Control.new()
	_moon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneSwitcher.pin(_moon, Vector2(0.5, 0.5), Rect2(660, 110, 600, 600))
	_moon.draw.connect(_draw_moon)
	_moon.modulate.a = 0.0
	add_child(_moon)
	add_child(UiKit.screen_fx(0.09, 0.8))

	_boot = UiKit.label("", 20, Color(UiKit.CYAN, 0.85))
	_boot.add_theme_constant_override("line_spacing", 8)
	SceneSwitcher.pin(_boot, Vector2(0, 0), Rect2(70, 60, 900, 260))
	add_child(_boot)

	_logo = UiKit.label("VOID DEFENSE", 150, UiKit.CREAM, GameFonts.display())
	UiKit.outlined(_logo, Color(0.05, 0.02, 0.12), 26)
	_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SceneSwitcher.pin(_logo, Vector2(0.5, 0.5), Rect2(260, 330, 1400, 220))
	_logo.pivot_offset = Vector2(700, 110)
	_logo.modulate.a = 0.0
	add_child(_logo)
	_sub = UiKit.label("—  야간 마음 정리 상담소  —", 36, UiKit.CYAN, GameFonts.bold())
	UiKit.outlined(_sub, Color(0.05, 0.02, 0.12), 12)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneSwitcher.pin(_sub, Vector2(0.5, 0.5), Rect2(460, 548, 1000, 56))
	_sub.modulate.a = 0.0
	add_child(_sub)

	_prompt = UiKit.label("아무 키나 눌러 접속", 34, UiKit.CREAM, GameFonts.bold())
	UiKit.outlined(_prompt, Color(0.05, 0.02, 0.12), 12)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneSwitcher.pin(_prompt, Vector2(0.5, 1), Rect2(460, 800, 1000, 56))
	_prompt.modulate.a = 0.0
	add_child(_prompt)
	_notice = UiKit.label("이 게임은 누구나 겪는 고민을 가볍게 그린 이야기입니다. 실제로 힘든 마음이 있다면 가까운 사람이나 상담 기관과 이야기해 보세요.", 17, Color(UiKit.DIM, 0.8))
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneSwitcher.pin(_notice, Vector2(0.5, 1), Rect2(260, 1000, 1400, 30))
	_notice.modulate.a = 0.0
	add_child(_notice)
	_ver = UiKit.label("PROTOTYPE BUILD", 15, Color(UiKit.MUTED, 0.9), GameFonts.bold())
	SceneSwitcher.pin(_ver, Vector2(0, 1), Rect2(40, 1036, 400, 24))
	add_child(_ver)

	# 걷힐 때: 위아래에서 검은 띠가 닫혔다 열린다
	_bars = Control.new()
	_bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(_draw_bars)
	add_child(_bars)
	_clock_us = Time.get_ticks_usec()


func _draw_moon() -> void:
	var c := _moon.size * 0.5
	for i in 5:
		_moon.draw_circle(c, 300.0 - i * 14.0, Color(0.62, 0.45, 0.95, 0.035 + i * 0.012))
	_moon.draw_circle(c, 225.0, Color(0.5, 0.36, 0.78, 0.5))
	_moon.draw_circle(c + Vector2(-14, -12), 205.0, Color(0.66, 0.52, 0.92, 0.55))
	# 하프톤 점: 달 아래쪽이 망점으로 흩어진다 (전투 화면의 코믹 하프톤과 같은 언어)
	var step := 22.0
	var y := c.y + 20.0
	while y < c.y + 225.0:
		var k := (y - c.y - 20.0) / 205.0
		var x := c.x - 225.0
		while x < c.x + 225.0:
			var p := Vector2(x + (step * 0.5 if int(y / step) % 2 == 0 else 0.0), y)
			if p.distance_to(c) < 222.0:
				_moon.draw_circle(p, 1.5 + 6.5 * k, Color(0.16, 0.09, 0.33, 0.55))
			x += step
		y += step


func _draw_bars() -> void:
	if _out < 0.0:
		return
	var k := clampf(_out / OUT_SEC, 0.0, 1.0)
	var close := sin(k * PI)                       # 0 → 1 → 0
	var h := size.y * 0.5 * close
	_bars.draw_rect(Rect2(0, 0, size.x, h), Color(0.02, 0.012, 0.05))
	_bars.draw_rect(Rect2(0, size.y - h, size.x, h), Color(0.02, 0.012, 0.05))
	_bars.draw_rect(Rect2(0, h - 3.0, size.x, 3.0), Color(UiKit.CYAN, close))
	_bars.draw_rect(Rect2(0, size.y - h, size.x, 3.0), Color(UiKit.PINK, close))


static func _k(t: float, start: float, dur: float) -> float:
	return clampf((t - start) / dur, 0.0, 1.0)


func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf((now - _clock_us) / 1e6, 0.0, 1.0 / 20.0)
	_clock_us = now
	_t += dt
	# 부팅 로그: 한 줄씩
	var n := clampi(int(_t / BOOT_STEP) + 1, 0, BOOT.size())
	_boot.text = "\n".join(BOOT.slice(0, n)) + ("  _" if int(_t * 3.0) % 2 == 0 and n < BOOT.size() else "")
	_boot.modulate.a = 1.0 - 0.75 * _k(_t, LOGO_AT, 0.5)
	if _art:
		_art.modulate.a = _k(_t, 0.7, 0.9)
	var mk := _k(_t, 0.8, 1.2)
	_moon.modulate.a = mk
	_moon.position.y = _moon.offset_top + size.y * 0.5 + 90.0 * (1.0 - UIIntro.back_out(mk) if mk < 1.0 else 0.0)
	# 로고: 크게 번쩍 들어와 자리 잡는다
	var lk := _k(_t, LOGO_AT, 0.4)
	_logo.modulate.a = minf(lk * 3.0, 1.0)
	var s := lerpf(1.6, 1.0, UIIntro.back_out(lk))
	_logo.scale = Vector2(s, s) * (1.0 + 0.008 * sin(_t * 1.6))
	_sub.modulate.a = _k(_t, LOGO_AT + 0.35, 0.35)
	_notice.modulate.a = _k(_t, PROMPT_AT, 0.5)
	_prompt.modulate.a = _k(_t, PROMPT_AT, 0.3) * (0.55 + 0.45 * sin((_t - PROMPT_AT) * 4.0))
	if _out >= 0.0:
		_out += dt
		_bars.queue_redraw()
		if _out >= OUT_SEC * 0.5:
			# 띠가 다 닫힌 순간: 안쪽을 지워 허브가 드러나게
			for c: CanvasItem in [_black, _art, _moon, _logo, _sub, _prompt, _notice, _boot, _ver]:
				if c:
					c.visible = false
			mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _out >= OUT_SEC:
			done.emit()
			queue_free()


func _input(event: InputEvent) -> void:
	if _out >= 0.0:
		return
	var go: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode not in [KEY_F11, KEY_F12, KEY_F5, KEY_F6, KEY_F7]) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.position.y > 80.0)
	if not go:
		return
	get_viewport().set_input_as_handled()
	if _t < PROMPT_AT:
		_t = PROMPT_AT   # 연출 중이면 끝까지 당긴다 (한 번 더 누르면 접속)
		return
	enter()


## 걷기 시작 (테스트가 직접 부르기도 한다).
func enter() -> void:
	if _out < 0.0:
		_out = 0.0


## 띠가 닫히기까지 남은 시간: 허브가 이 뒤에 등장 연출을 시작한다.
func time_to_open() -> float:
	return OUT_SEC * 0.5
