## 캐릭터 스킬창 (시안 PSD 화면 컨셉_2 '캐릭터 스킬창' 레이어): 보라 패널 + 머리띠(캐릭터 이름) + 정보 4줄 + 스킬 4줄 + 아래 말꼬리.
## 좌측 하단 턴테이블의 앞 캐릭터를 누르면 그 영웅 것이 캐릭터 머리 위로 열리고 다시 누르면 닫힌다 (VDBattle._on_turntable_pressed).
## 열린 채 턴테이블을 돌리면 닫히지 않고 다음 캐릭터 것으로 바뀐다. 배치·회복·길 선택 단계엔 분대 카드를 눌러도 열린다.
## 스킬 줄을 누르면 SP 하나로 그 스킬을 한 레벨 올린다 (VDGrowth.upgrade, 최대 VDData.SKILL_MAX). 가리킨 줄은 시안의
## 흰 강조 줄(더 크고 왼쪽으로 튀어나온)로 바뀐다. 생김새는 VDSkillWindowLayout(생성물) 수치 그대로: 상자는 StyleBoxFlat,
## 시안처럼 전체를 SKEW_DEG 만큼 기울여(세로변은 수직인 채 가로변만 기움) 그린다.
## 스킬 아이콘은 assets/textures/skill_icons/<skill id>.png (코덱스 요청: docs/stage_wave_port/CODEX_REQUESTS.md). 없으면 이름 첫 글자.
## class_name 없음: vd_battle.gd 가 preload 해서 쓴다.
extends Control
const GameFonts := preload("res://scripts/game_fonts.gd")

const Layout := preload("res://scripts/void_defense/vd_skill_window_layout.gd")
const ICON_DIR := "res://assets/textures/skill_icons/"
const PAD := Vector2(24.0, 24.0)             # 컨트롤 안에서 패널 왼쪽 위까지 여백 (그림자·강조 줄이 튀어나올 자리)
const EXTRA := Vector2(70.0, 80.0)           # 오른쪽·아래 여백 (강조 줄·말꼬리)
const Z := 250                               # 턴테이블 캐릭터(~220) 위, 유물 딤 막(400) 아래
const PIP_R := 4.0
const UP_COL := Color("ffd23f")
const MAX_COL := Color(0.55, 0.9, 0.6)
const NAME_DARK := Color(0.14, 0.08, 0.26)
const DESC_COL := Color(0.32, 0.25, 0.45)
const CLOSE_R := 11.0

var b: VDBattle
var hero := ""
var is_open := false          # 열려 있다 (닫히는 연출 중에는 visible 이어도 false)
var _anim := 0.0               # 열림 진행 0 → 1 (실제 시간)
var _swap := 0.0               # 열린 채 영웅이 바뀜: 1 → 0 (살짝 튐 + 머리띠 번쩍)
const OPEN_SPEED := 5.5        # 1/초
const CLOSE_SPEED := 9.0
var _hover_row := -1
var _hover_close := false
var _pop := {}                 # row -> 남은 튐 (1 → 0, 실제 시간)
var _clock_us := 0
var _xf: Transform2D
var _bold: Font
var _panel_box: StyleBoxFlat
var _row_box: StyleBoxFlat
var _row_hi_box: StyleBoxFlat
var _icon_box: StyleBoxFlat
var _icon_hi_box: StyleBoxFlat
var _header_box: StyleBoxFlat
var _icons := {}               # skill id -> Texture2D 또는 null


func setup(battle: VDBattle) -> void:
	b = battle
	visible = false
	z_index = Z
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rect := Rect2(Layout.PANEL_RECT.position - PAD, Layout.PANEL_RECT.size + PAD + EXTRA)
	SceneSwitcher.pin(self, Vector2(0, 0), rect)
	var a := deg_to_rad(Layout.SKEW_DEG)
	_xf = Transform2D(Vector2(1.0, tan(a)), Vector2(0.0, 1.0), PAD)
	pivot_offset = _xf * (Layout.TAIL[1] as Vector2)   # 말꼬리 끝: 여기서 솟아오르고 여기로 줄어든다
	# 강조 역할을 따르되, 한글이 "시스템" 이면 시안 글꼴(깔려 있을 때)을 먼저 찾는다
	_bold = GameFonts.variant("bold", PackedStringArray([Layout.NAME_FONT]), 800)
	_panel_box = _box(Layout.PANEL_FILL, Layout.PANEL_RADIUS, Layout.PANEL_BORDER, Layout.PANEL_BORDER_COLOR)
	_panel_box.shadow_color = Layout.PANEL_SHADOW_COLOR
	_panel_box.shadow_offset = Layout.PANEL_SHADOW_OFFSET
	_panel_box.shadow_size = int(Layout.PANEL_SHADOW_BLUR * 1.5)
	_header_box = _box(Layout.HEADER_FILL, Layout.PANEL_RADIUS, 0, Color.TRANSPARENT)
	_header_box.corner_radius_bottom_left = 0
	_header_box.corner_radius_bottom_right = 0
	_row_box = _box(Layout.ROW_FILL, Layout.ROW_RADIUS, 0, Color.TRANSPARENT)
	_row_hi_box = _box(Layout.ROW_HI_FILL, Layout.ROW_RADIUS, 0, Color.TRANSPARENT)
	_row_hi_box.shadow_color = Color(0, 0, 0, 0.25)
	_row_hi_box.shadow_size = 6
	_row_hi_box.shadow_offset = Vector2(3, 4)
	_icon_box = _box(Layout.ICON_FILL, Layout.ICON_RADIUS, Layout.ICON_BORDER, Layout.ICON_BORDER_COLOR)
	_icon_hi_box = _box(Layout.ICON_HI_FILL, Layout.ICON_RADIUS, Layout.ICON_BORDER, Layout.ICON_BORDER_COLOR)
	mouse_exited.connect(func() -> void:
		_hover_row = -1
		_hover_close = false
		queue_redraw())


static func _box(fill: Color, radius: float, border: int, border_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(round(radius)))
	sb.set_border_width_all(border)
	sb.border_color = border_col
	sb.anti_aliasing = true
	return sb


# ---------------------------------------------------------------- 열고 닫기

func toggle(hid: String) -> void:
	if is_open and hero == hid:
		close()
	else:
		open(hid)


## 연다. 이미 다른 영웅 것이 열려 있으면 닫지 않고 그 자리에서 내용만 바뀐다 (턴테이블을 돌릴 때: 살짝 튀며 머리띠가 번쩍).
func open(hid: String) -> void:
	if not VDData.HERO_SKILLS.has(hid):
		return
	if is_open and hero == hid:
		return
	var fresh := not visible
	hero = hid
	is_open = true
	visible = true
	_hover_row = -1
	_hover_close = false
	_pop.clear()
	if fresh:
		_anim = 0.0
		_swap = 0.0
		_clock_us = 0
		_apply_anim()
	else:
		_swap = 1.0
	refresh()


## 닫는다: 말꼬리 쪽으로 빠르게 줄어들며 사라진다. instant 면 바로 (새 판·게임 오버).
func close(instant := false) -> void:
	if not visible:
		return
	is_open = false
	_hover_row = -1
	_hover_close = false
	if instant:
		_anim = 0.0
		visible = false
		hero = ""


## 열림 진행(_anim)·전환 튐(_swap)을 배율·투명도로. 축은 말꼬리 끝이라 캐릭터 머리 위에서 위로 솟아오르는 것처럼 보인다.
func _apply_anim() -> void:
	var e := UIIntro.back_out(_anim) if is_open else _anim * _anim
	var s := lerpf(0.72, 1.0, e) * (1.0 - 0.045 * sin(_swap * PI))
	scale = Vector2(s, s)
	modulate.a = clampf(_anim * 3.0, 0.0, 1.0)


func refresh() -> void:
	queue_redraw()


func _process(_dt: float) -> void:
	if not visible:
		return
	var now := Time.get_ticks_usec()
	var dt := clampf((now - _clock_us) / 1000000.0, 0.0, 0.1) if _clock_us > 0 else 0.0
	_clock_us = now
	_anim = move_toward(_anim, 1.0 if is_open else 0.0, dt * (OPEN_SPEED if is_open else CLOSE_SPEED))
	_swap = maxf(0.0, _swap - dt * 4.5)
	if not is_open and _anim <= 0.0:
		visible = false
		hero = ""
		return
	_apply_anim()
	for k in _pop.keys():
		_pop[k] = maxf(0.0, float(_pop[k]) - dt * 3.0)
	queue_redraw()


# ---------------------------------------------------------------- 좌표

## 화면(컨트롤 로컬) 점 → 기울기를 뺀 패널 로컬 점.
func _to_panel(p: Vector2) -> Vector2:
	return _xf.affine_inverse() * p


func _row_rect(i: int, hi: bool) -> Rect2:
	var r: Rect2 = Layout.ROW_RECTS[i]
	if not hi:
		return r
	var cy := r.position.y + r.size.y * 0.5 + Layout.ROW_HI_DY
	return Rect2(r.position.x + Layout.ROW_HI_DX, cy - Layout.ROW_HI_H * 0.5, Layout.ROW_HI_W, Layout.ROW_HI_H)


func _close_center() -> Vector2:
	return Vector2(Layout.PANEL_RECT.size.x - 20.0, 20.0)


func _row_at(p: Vector2) -> int:
	for i in VDData.SKILL_SLOTS:
		if _row_rect(i, i == _hover_row).grow(2.0).has_point(p):
			return i
	return -1


## 패널·말꼬리 위에서만 마우스를 받는다 (바깥은 전장으로 통과).
func _has_point(p: Vector2) -> bool:
	if not visible or not is_open:
		return false
	var l := _to_panel(p)
	var body := Rect2(Vector2.ZERO, Layout.PANEL_RECT.size).grow(6.0)
	if body.has_point(l):
		return true
	if _row_at(l) >= 0:
		return true
	var tail: Array = Layout.TAIL
	var tb := Rect2(tail[0], Vector2.ZERO)
	for t in tail:
		tb = tb.expand(t)
	return tb.grow(4.0).has_point(l)


# ---------------------------------------------------------------- 입력

func _gui_input(event: InputEvent) -> void:
	if hero == "" or not is_open:
		return
	if event is InputEventMouseMotion:
		var l := _to_panel(event.position)
		var row := _row_at(l)
		var cl := l.distance_to(_close_center()) <= CLOSE_R + 4.0
		if row != _hover_row or cl != _hover_close:
			if row != _hover_row and row >= 0:
				b.audio.play("tick", 0.02, -10.0, 1.4)
			_hover_row = row
			_hover_close = cl
			queue_redraw()
		accept_event()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var l := _to_panel(event.position)
		accept_event()
		if l.distance_to(_close_center()) <= CLOSE_R + 4.0:
			b.audio.play("click")
			close()
			return
		var row := _row_at(l)
		if row < 0:
			return
		_try_upgrade(row)


func _try_upgrade(row: int) -> void:
	if b.growth.upgrade(hero, row):
		_pop[row] = 1.0
		b.audio.play("chime", 0.0, -2.0, 1.1 + 0.08 * b.growth.skill_level(hero, row))
		var sk: Dictionary = VDData.HERO_SKILLS[hero][row]
		var r := _row_rect(row, true)
		var at := get_global_transform_with_canvas() * (_xf * (r.position + Vector2(r.size.x * 0.55, 0.0)))
		b.juice.pop_text(at, "%s Lv.%d" % [sk["name"], b.growth.skill_level(hero, row)], UP_COL, 26.0, 0.5)
		var u: VDUnit = b.growth.unit_of(hero)
		if u:
			u.cast_pulse()
			b.vfx.spawn("burst", b.fx_root, b._chest(u), 0.5, 0.0, UP_COL)
	else:
		# SP 가 없거나 최대 레벨: 낮은 소리 + 살짝 흔들림
		b.audio.play("click", 0.0, -8.0, 0.6)
		_pop[row] = 0.4
	queue_redraw()


# ---------------------------------------------------------------- 그리기

func _icon_of(id: String) -> Texture2D:
	if not _icons.has(id):
		var path := ICON_DIR + id + ".png"
		_icons[id] = load(path) if ResourceLoader.exists(path) else null
	return _icons[id]


func _draw() -> void:
	if hero == "" or not VDData.HERO_SKILLS.has(hero):
		return
	var font := VDData.font()
	var g = b.growth   # VDGrowth (preload 라 정적 타입이 없다)
	var u: VDUnit = g.unit_of(hero)
	var hd: Dictionary = VDData.HEROES[hero]
	var psize: Vector2 = Layout.PANEL_RECT.size
	var t := Time.get_ticks_msec() * 0.001
	draw_set_transform_matrix(_xf)
	# 본체 (그림자 포함) + 머리띠 (본체 윗부분에 맞춰 자른다) + 말꼬리
	draw_style_box(_panel_box, Rect2(Vector2.ZERO, psize))
	var hr: Rect2 = Layout.HEADER_RECT
	var head := Rect2(Vector2(Layout.PANEL_BORDER, Layout.PANEL_BORDER), Vector2(psize.x - Layout.PANEL_BORDER * 2.0, hr.end.y - Layout.PANEL_BORDER))
	draw_style_box(_header_box, head)
	if _swap > 0.0:
		draw_rect(head, Color(1, 1, 1, 0.55 * _swap * _swap))   # 영웅이 바뀜: 머리띠가 번쩍
	var tail := PackedVector2Array(Layout.TAIL)
	draw_colored_polygon(tail, Layout.PANEL_FILL)
	draw_line(tail[0], tail[1], Layout.PANEL_BORDER_COLOR, Layout.PANEL_BORDER)
	draw_line(tail[1], tail[2], Layout.PANEL_BORDER_COLOR, Layout.PANEL_BORDER)
	# 이름 (머리띠 가운데) + 닫기
	draw_string(_bold, Vector2(0, Layout.NAME_POS.y + Layout.NAME_SIZE * 0.95), String(hd["name"]), HORIZONTAL_ALIGNMENT_CENTER, psize.x, Layout.NAME_SIZE, Layout.NAME_COLOR)
	var cc := _close_center()
	draw_circle(cc, CLOSE_R, Color(1, 1, 1, 0.9 if _hover_close else 0.45))
	draw_line(cc + Vector2(-4, -4), cc + Vector2(4, 4), NAME_DARK, 2.0)
	draw_line(cc + Vector2(-4, 4), cc + Vector2(4, -4), NAME_DARK, 2.0)
	# 정보 4줄
	var lv: int = g.level_of(hero)
	var sp: int = g.sp_of(hero)
	var lines: Array[String] = []
	lines.append("Lv.%d    EXP %d / %d" % [lv, g.exp_of(hero), g.need(hero)])
	if u:
		lines.append("HP %d / %d    ATK %d" % [int(u.hp), int(u.max_hp), int(u.atk)] if u.alive else "전투 불능  (HP %d  ATK %d)" % [int(u.max_hp), int(u.atk)])
	else:
		lines.append("HP %d    ATK %d" % [int(hd["hp"]), int(hd["atk"])])
	lines.append("고유 스킬 %s" % String(VDData.SKILLS[hero]["name"]))
	if sp > 0:
		lines.append("SP %d  —  스킬 줄을 눌러 올리세요" % sp)
	else:
		lines.append("SP 0  (레벨업마다 +1)")
	for i in lines.size():
		var col: Color = Layout.INFO_COLOR
		if i == 3 and sp > 0:
			col = Color(0.45, 0.12, 0.2).lerp(Color(0.8, 0.2, 0.3), 0.5 + 0.5 * sin(t * 5.0))
		draw_string(font, Vector2(Layout.INFO_POS.x, Layout.INFO_POS.y + i * Layout.INFO_PITCH + Layout.INFO_SIZE * 0.9), lines[i], HORIZONTAL_ALIGNMENT_LEFT, psize.x - Layout.INFO_POS.x - 12.0, Layout.INFO_SIZE, col)
	# 스킬 4줄: 가리킨 줄은 흰 강조 줄(크고 왼쪽으로 튀어나옴)
	var table: Array = VDData.HERO_SKILLS[hero]
	for i in VDData.SKILL_SLOTS:
		var hi := i == _hover_row
		var pop := float(_pop.get(i, 0.0))
		var r := _row_rect(i, hi)
		if pop > 0.0:
			r = r.grow_individual(2.0 * pop, 3.0 * pop, 2.0 * pop, 3.0 * pop)
		draw_style_box(_row_hi_box if hi else _row_box, r)
		var sk: Dictionary = table[i]
		var slv: int = g.skill_level(hero, i)
		var can: bool = g.can_upgrade(hero, i)
		# 아이콘 상자
		var ir := Rect2(r.position + (Layout.ICON_HI_OFFSET if hi else Layout.ICON_OFFSET), Layout.ICON_HI_SIZE if hi else Layout.ICON_SIZE)
		draw_style_box(_icon_hi_box if hi else _icon_box, ir)
		var tex := _icon_of(String(sk["id"]))
		if tex:
			var k := minf((ir.size.x - 10.0) / tex.get_width(), (ir.size.y - 10.0) / tex.get_height())
			var isz := tex.get_size() * k
			draw_texture_rect(tex, Rect2(ir.get_center() - isz * 0.5, isz), false, Color.WHITE if slv > 0 or hi else Color(1, 1, 1, 0.7))
		else:
			draw_string(_bold, Vector2(ir.position.x, ir.position.y + ir.size.y * 0.5 + 10.0), String(sk["name"]).left(1), HORIZONTAL_ALIGNMENT_CENTER, ir.size.x, 28, Color(1, 1, 1, 0.9 if hi else 0.75))
		# 이름 · 레벨 · 핍 · 설명
		var tx := ir.end.x + 10.0
		var tw := r.end.x - tx - 10.0
		var name_col := NAME_DARK if hi else Color(0.1, 0.06, 0.2)
		draw_string(_bold, Vector2(tx, r.position.y + 22.0), String(sk["name"]), HORIZONTAL_ALIGNMENT_LEFT, tw - 50.0, 16, name_col)
		var lv_text := "Lv.%d" % slv if slv > 0 else "미습득"
		draw_string(font, Vector2(tx, r.position.y + 21.0), lv_text, HORIZONTAL_ALIGNMENT_RIGHT, tw, 12, name_col if slv > 0 else DESC_COL)
		for p in VDData.SKILL_MAX:
			var c := Vector2(tx + 6.0 + p * (PIP_R * 2.0 + 5.0), r.position.y + 33.0)
			draw_circle(c, PIP_R, Color(0.95, 0.75, 0.25) if p < slv else Color(0, 0, 0, 0.18))
			if p < slv:
				draw_circle(c, PIP_R - 1.5, Color(1.0, 0.92, 0.6))
		draw_multiline_string(font, Vector2(tx, r.position.y + 50.0), String(sk["desc"]), HORIZONTAL_ALIGNMENT_LEFT, tw, 11, 2, DESC_COL)
		# UP 알약 (SP 가 있고 최대가 아닐 때) / MAX
		if can:
			var pulse := 0.5 + 0.5 * sin(t * 6.0 + i)
			var pill := Rect2(r.end - Vector2(46.0 + 4.0 * pulse, 30.0 + 2.0 * pulse), Vector2(38.0 + 4.0 * pulse, 20.0 + 2.0 * pulse))
			draw_rect(pill.grow(3.0), Color(UP_COL, 0.25 + 0.2 * pulse))
			draw_rect(pill, UP_COL)
			draw_string(_bold, Vector2(pill.position.x, pill.position.y + pill.size.y * 0.78), "UP", HORIZONTAL_ALIGNMENT_CENTER, pill.size.x, 13, Color(0.25, 0.14, 0.02))
		elif slv >= VDData.SKILL_MAX:
			var pill := Rect2(r.end - Vector2(48.0, 28.0), Vector2(40.0, 18.0))
			draw_rect(pill, Color(MAX_COL, 0.85))
			draw_string(_bold, Vector2(pill.position.x, pill.position.y + 14.0), "MAX", HORIZONTAL_ALIGNMENT_CENTER, pill.size.x, 12, Color(0.05, 0.2, 0.08))
	draw_set_transform(Vector2.ZERO)
