## 상담소 허브 (게임의 첫 화면이자 런과 런 사이의 집). docs/FTUE_분석_및_구조설계.md 3장.
##   부팅: 타이틀(scripts/hub/hub_title.gd, 앱을 켠 뒤 한 번) → 첫 실행이면 프롤로그(StoryDialog) 뒤 곧장 첫 다이브 → 그 뒤로는 허브.
##   허브: 모니터룸 원화 위에 반장(왼쪽 아래, 상황별 말풍선)과 탭 패널(오른쪽).
##     의뢰  — 의뢰 카드(의뢰인·고민·회기·진행) + [다이브 시작] (Space/Enter). 완료 뒤엔 무한 야근·다음 의뢰 예고.
##     분대  — 영웅 4인 프로필 · 고유 스킬 · 궁극기
##     강화  — 시간의 결정으로 사는 영구 강화 (GameSave.UPGRADES)
##     엽서 벽 — 의뢰인마다 1장
##     연구실 — 개발 도구(연출 연구실·쇼룸 등 SceneSwitcher.SCENES 의 나머지) + 안내 다시 보기·세이브 초기화
##   분대·강화·엽서 벽은 첫 의뢰를 한 번 다녀오면 "NEW" 와 함께 열린다 (이기든 지든 메타 고리를 한 바퀴 돌게).
## 숫자키: 1 = 다이브, 2~ = 연구실 도구 (예전 로비의 바로가기 유지). 모드 안에서는 Esc 로 돌아온다.
## 명령줄(테스트): `-- --skip-title` 타이틀 생략 · `--no-prologue` 프롤로그 생략.
extends Control

const GameFonts := preload("res://scripts/game_fonts.gd")
const HubTitle := preload("res://scripts/hub/hub_title.gd")
const VDMainButton := preload("res://scripts/void_defense/vd_main_button.gd")
const ART := "res://assets/textures/hub/hub_rewind_room.png"   # 컨셉 원화 로비_모니터룸_2종_v12/02 의 사본
const CHIEF_SHEET := "res://assets/textures/standing/char_02_idle.png"
const CHIEF_GRID := Vector2i(8, 8)
const CHIEF_FRAMES := 57
const CHIEF_FPS := 10.0
const BATTLE := 1                     # SceneSwitcher.SCENES 의 메인전투
const TABS := [["case", "의뢰"], ["squad", "분대"], ["upgrade", "강화"], ["postcards", "엽서 벽"], ["lab", "연구실"]]
const LOCKABLE := ["squad", "upgrade", "postcards"]
const PANEL_RECT := Rect2(1010, 176, 850, 800)
const IDLE_LINES := [
	"오늘도 영업 중이에요. 쪽지부터 확인해요.",
	"커피는 다이브 전에. 다녀와서 마시면 잠이 안 와요.",
	"모니터 좀 닦아야 하는데… 내일 해요, 내일.",
	"남의 마음에 들어갈 땐, 신발은 벗고.",
]

static var _booted := false           # 타이틀은 앱을 켠 뒤 한 번만

var case_id := "harin"
var _art: TextureRect
var _ui: Control                      # 허브 UI 전체 (타이틀·프롤로그 동안 숨긴다)
var _header: Array[Control] = []
var _tab_bar: HBoxContainer
var _tab_btns := {}                   # id -> Button
var _panel: PanelContainer
var _page: VBoxContainer
var _tab := "case"
var _chief: TextureRect
var _chief_atlas: AtlasTexture
var _chief_cell := Vector2.ZERO
var _bubble: PanelContainer
var _bubble_text: Label
var _crystal: Label
var _hint: Label
var _dive: VDMainButton
var _audio: VDAudio
var _ambience: Ambience
var _voice: VoiceBabble
var _speak_id := 0
var _title: Control
var _dialog: StoryDialog
var _clock_us := 0
var _t := 0.0
var _busy := false                    # 타이틀·프롤로그·다이브 전환 중: 허브 입력을 받지 않는다
var _wipe_armed := 0.0                # 세이브 초기화 버튼: 한 번 더 눌러야 실행 (남은 초)
var _idle_i := 0
## 예전 로비를 쓰던 캡처 도구용: 등장 연출이 미는 조각들 (탭 패널 · 반장)
var _cards: Array[PanelContainer] = []
var _moon_slot: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font = VDData.font()
	th.default_font_size = 20
	theme = th
	_audio = VDAudio.new()
	add_child(_audio)
	_ambience = Ambience.new("hub")
	add_child(_ambience)
	_voice = VoiceBabble.new()
	_voice.volume_db = -15.0
	add_child(_voice)
	SceneSwitcher.add_setting(self, "배경음", func() -> void: _ambience.set_on(not _ambience.is_on()), _ambience.is_on)
	SceneSwitcher.add_setting(self, "대사 음성", func() -> void: GameSave.set_voice_on(not GameSave.voice_on()), GameSave.voice_on)
	_build_background()
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	_build_header()
	_build_chief()
	_build_tabs()
	_build_footer()
	_show_tab("case", false)
	_clock_us = Time.get_ticks_usec()
	var args := OS.get_cmdline_user_args()
	var main := get_tree().current_scene == self or get_tree().current_scene == null
	if main and not _booted and not args.has("--skip-title"):
		_booted = true
		_start_title()
	elif main and GameSave.is_first_run() and not args.has("--no-prologue"):
		_booted = true
		_start_prologue()
	else:
		_booted = _booted or main
		_play_intro(SceneSwitcher.intro_lead())
		_greet(SceneSwitcher.intro_lead())


# ---------------------------------------------------------------- 부팅 흐름

func _start_title() -> void:
	_busy = true
	_ui.modulate.a = 0.0
	_title = HubTitle.new()
	add_child(_title)
	_title.done.connect(func() -> void:
		_title = null
		if GameSave.is_first_run() and not OS.get_cmdline_user_args().has("--no-prologue"):
			_start_prologue()
		else:
			_busy = false
			_ui.modulate.a = 1.0
			_play_intro(0.0)
			_greet())


## 첫 실행: 접수된 쪽지 → 반장 → 분대 한 마디씩 → 곧장 첫 다이브 (허브 메뉴는 다녀온 뒤에 열린다).
func _start_prologue() -> void:
	_busy = true
	_ui.modulate.a = 0.0
	var c := CaseData.get_case(case_id)
	var lines := [
		["note", String(c["note"]), "— " + String(c["client"])],
		["chief", "의뢰네요. 다들 일어나요, 오늘 할 일 생겼어요."],
		["knight", "드디어 일이다!"],
		["gunner", "쪽지 글씨가 엄청 반듯하네. 지우개 자국은 세 군데."],
		["mage", "…시끄러운 머리면, 귀마개부터 챙겨야겠네요."],
		["healer", "하린 씨, 많이 피곤하겠어요."],
		["chief", "자, 접속 준비. 남의 마음이에요 — 신발은 벗고 들어가요."],
	]
	_dialog = StoryDialog.play(self, lines, 0.5)
	_dialog.finished.connect(func() -> void:
		_dialog = null
		GameSave.mark_prologue_seen()
		dive())


## 다이브: 의뢰 런으로 들어간다. mode "case" (의뢰) | "endless" (무한 야근).
func dive(mode := "case") -> void:
	if SceneSwitcher.is_loading():
		return
	_busy = true
	_audio.play("wave_start", 0.0, -4.0)
	_ambience.fade_out(0.8)
	var c := CaseData.get_case(case_id)
	VDBattle.mode_request = {"mode": mode, "case": case_id}
	SceneSwitcher.loading_caption = String(c["loading"]) if mode == "case" else "야근 구역에 접속하는 중"
	SceneSwitcher.loading_tip = CaseData.random_tip()
	print("[hub] dive %s (%s)" % [mode, case_id])
	SceneSwitcher.switch_to(BATTLE)


# ---------------------------------------------------------------- 배경 · 머리글

func _build_background() -> void:
	var base := ColorRect.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.color = Color(0.1, 0.07, 0.2)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	if ResourceLoader.exists(ART):
		_art = UiKit.cover(load(ART))
		# 패럴랙스 여유: 화면보다 조금 크게
		_art.offset_left = -30
		_art.offset_right = 30
		_art.offset_top = -18
		_art.offset_bottom = 18
		add_child(_art)
	# 왼쪽(반장 자리)과 오른쪽(패널 자리)을 살짝 눌러 글자가 읽히게
	for side in 2:
		var g := Gradient.new()
		g.set_color(0, Color(0.05, 0.03, 0.12, 0.78))
		g.set_color(1, Color(0.05, 0.03, 0.12, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0.0 if side == 0 else 1.0, 0)
		gt.fill_to = Vector2(0.42 if side == 0 else 0.3, 0)
		var shade := TextureRect.new()
		shade.texture = gt
		shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
	add_child(UiKit.screen_fx(0.05, 0.5))


func _build_header() -> void:
	var logo := UiKit.label("VOID DEFENSE", 30, UiKit.CYAN, GameFonts.display())
	UiKit.outlined(logo, UiKit.INK, 10)
	logo.position = Vector2(60, 36)
	_ui.add_child(logo)
	var title := UiKit.label("야간 마음 정리 상담소", 54, UiKit.CREAM, GameFonts.bold())
	UiKit.outlined(title, UiKit.INK, 16)
	title.position = Vector2(58, 70)
	_ui.add_child(title)
	_hint = UiKit.label("", 19, UiKit.DIM)
	UiKit.outlined(_hint, UiKit.INK, 6)
	_hint.position = Vector2(62, 146)
	_ui.add_child(_hint)
	_header = [logo, title, _hint]
	# 시간의 결정 (오른쪽 위, 설정 톱니 왼쪽)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiKit.box(Color(0.07, 0.05, 0.15, 0.85), Color(UiKit.GOLD, 0.6), 2, 22, 10))
	SceneSwitcher.pin(chip, Vector2(1, 0), Rect2(1590, 16, 250, 46))
	chip.tooltip_text = "시간의 결정: 다이브를 마칠 때마다 받습니다. [강화] 에서 씁니다."
	_ui.add_child(chip)
	_crystal = UiKit.label("", 22, UiKit.GOLD, GameFonts.bold())
	_crystal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(_crystal)
	_header.append(chip)
	_refresh_crystal()


func _refresh_crystal() -> void:
	_crystal.text = "시간의 결정  %d" % GameSave.crystals()


func _build_footer() -> void:
	var foot := UiKit.label("1 다이브 · 2~%d 연구실 도구 · F11 전체화면" % (SceneSwitcher.SCENES.size() - 1), 15, UiKit.MUTED)
	SceneSwitcher.pin(foot, Vector2(1, 1), Rect2(1010, 1040, 850, 24))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui.add_child(foot)


# ---------------------------------------------------------------- 반장

func _build_chief() -> void:
	if ResourceLoader.exists(CHIEF_SHEET):
		var sheet: Texture2D = load(CHIEF_SHEET)
		_chief_cell = sheet.get_size() / Vector2(CHIEF_GRID)
		_chief_atlas = AtlasTexture.new()
		_chief_atlas.atlas = sheet
		_chief_atlas.region = Rect2(Vector2.ZERO, _chief_cell)
		_chief = TextureRect.new()
		_chief.texture = _chief_atlas
		_chief.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_chief.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		SceneSwitcher.pin(_chief, Vector2(0, 1), Rect2(70, 420, 520, 640))
		_chief.pivot_offset = Vector2(260, 640)
		_chief.mouse_filter = Control.MOUSE_FILTER_STOP
		_chief.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_chief.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not _busy:
				_idle_i += 1
				say(IDLE_LINES[_idle_i % IDLE_LINES.size()])
				_audio.play("tick", 0.05, -6.0, 1.3))
		_ui.add_child(_chief)
		_moon_slot = _chief
	# 말풍선 (반장 머리 오른쪽 위)
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", UiKit.comic_box(Color(0.98, 0.96, 0.9), 22, 22))
	SceneSwitcher.pin(_bubble, Vector2(0, 1), Rect2(470, 440, 470, 120))
	_bubble.pivot_offset = Vector2(40, 110)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.modulate.a = 0.0
	_ui.add_child(_bubble)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_bubble.add_child(vb)
	var who := UiKit.label("반장", 17, Color(0.85, 0.25, 0.3), GameFonts.bold())
	vb.add_child(who)
	_bubble_text = UiKit.label("", 23, Color(0.13, 0.1, 0.22))
	_bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_text.custom_minimum_size = Vector2(420, 0)
	vb.add_child(_bubble_text)


## 반장이 한마디 한다 (말풍선이 톡 튀며 뜬다).
func say(text: String) -> void:
	_bubble_text.text = text
	_speak(text)
	_bubble.reset_size()
	_bubble.modulate.a = 1.0
	_bubble.scale = Vector2(0.6, 0.6)
	var tw := _bubble.create_tween().set_ignore_time_scale()
	tw.tween_property(_bubble, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _chief:
		_chief.scale = Vector2(1.04, 0.96)
		_chief.create_tween().set_ignore_time_scale().tween_property(_chief, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## 말풍선 글을 따라 반장이 옹알거린다 (글은 한 번에 뜨므로 소리만 글자 박자로 흘린다).
func _speak(text: String) -> void:
	_speak_id += 1
	var id := _speak_id
	VoiceBabble.warm("chief")
	var ending := VoiceBabble.ending_of(text)
	var n := mini(text.length(), 34)
	for i in n:
		if id != _speak_id or not is_inside_tree():
			return
		_voice.say("chief", text.substr(i, 1), float(i) / maxf(n - 1, 1.0), ending)
		await get_tree().create_timer(0.068, true, false, true).timeout


## 허브에 들어왔을 때의 첫 마디: 지난 다이브 결과와 새로 열린 탭에 따라.
func _greet(lead := 0.0) -> void:
	var fresh := GameSave.take_new_tabs()
	var line := ""
	if not fresh.is_empty():
		line = "수고했어요. 결정이 좀 모였죠? [강화] 부터 눌러 봐요. 처음 건 싼 걸로."
		_audio.play("chime", 0.0, -6.0)
	elif GameSave.last_result() == "clear" and GameSave.sessions(case_id) > 0:
		line = "하린 씨, 토요일에 합주한대요. …한 집 더 갈래요?"
	elif GameSave.last_result() == "retreat":
		line = "한 번에 다 못 치워요. 강화 좀 하고, 다시 가 봐요."
	elif not GameSave.hub_unlocked():
		line = "쪽지 왔어요. 오른쪽 의뢰 카드 보고, 준비되면 다이브."
	else:
		line = IDLE_LINES[randi() % IDLE_LINES.size()]
	_hint.text = "AM 02:14 · 영업 중 · " + ("다음 쪽지를 기다리는 중" if GameSave.is_cleared(case_id) else "의뢰 1건 접수")
	get_tree().create_timer(lead + 1.5, true, false, true).timeout.connect(func() -> void:   # 반장·패널이 다 들어온 뒤에
		if is_inside_tree() and not _busy:
			say(line))


# ---------------------------------------------------------------- 탭

func _build_tabs() -> void:
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 8)
	SceneSwitcher.pin(_tab_bar, Vector2(1, 0), Rect2(PANEL_RECT.position.x, 110, PANEL_RECT.size.x, 56))
	_ui.add_child(_tab_bar)
	for t in TABS:
		var id := String(t[0])
		var b := UiKit.button(String(t[1]), UiKit.CYAN, 24, Vector2(150, 56))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_tab_pressed.bind(id))
		b.mouse_entered.connect(func() -> void: _audio.play("tick", 0.03, -10.0, 1.4))
		_tab_bar.add_child(b)
		_tab_btns[id] = b
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.comic_box(UiKit.PANEL, 16, 30))
	SceneSwitcher.pin(_panel, Vector2(1, 0), PANEL_RECT)
	_ui.add_child(_panel)
	_cards = [_panel]
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 16)
	_panel.add_child(_page)
	_refresh_tabs()


func _locked(id: String) -> bool:
	return LOCKABLE.has(id) and not GameSave.hub_unlocked()


func _refresh_tabs() -> void:
	var fresh := GameSave.take_new_tabs()
	for t in TABS:
		var id := String(t[0])
		var b: Button = _tab_btns[id]
		var locked := _locked(id)
		b.text = String(t[1]) + ("  ●" if fresh.has(id) else "")
		b.modulate = Color(1, 1, 1, 0.45) if locked else Color.WHITE
		b.add_theme_color_override("font_color", UiKit.INK if id == _tab else (UiKit.GOLD if fresh.has(id) else UiKit.CREAM))
		b.add_theme_color_override("font_hover_color", UiKit.INK if id == _tab else Color.WHITE)
		var on := UiKit.box(UiKit.CYAN, UiKit.INK, 3, 8, 12)
		if id == _tab:
			b.add_theme_stylebox_override("normal", on)
			b.add_theme_stylebox_override("hover", on)
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_stylebox_override("hover")
			b.add_theme_stylebox_override("normal", UiKit.box(Color(0.1, 0.08, 0.2, 0.88), Color(UiKit.CYAN, 0.35), 2, 8, 12))
			b.add_theme_stylebox_override("hover", UiKit.box(Color(0.17, 0.12, 0.32, 0.96), UiKit.CYAN, 2, 8, 12))


func _on_tab_pressed(id: String) -> void:
	if _busy:
		return
	if _locked(id):
		_audio.play("tick", 0.0, -4.0, 0.6)
		say("거긴 첫 의뢰를 다녀오면 열어 줄게요. 일단 다이브부터.")
		return
	_audio.play("click")
	_show_tab(id)


func _show_tab(id: String, animate := true) -> void:
	_tab = id
	if LOCKABLE.has(id):
		GameSave.mark_tab_seen(id)
	for c in _page.get_children():
		_page.remove_child(c)
		c.queue_free()
	_dive = null
	match id:
		"case": _page_case()
		"squad": _page_squad()
		"upgrade": _page_upgrade()
		"postcards": _page_postcards()
		"lab": _page_lab()
	_refresh_tabs()
	if animate:
		_panel.pivot_offset = _panel.size * 0.5
		_panel.scale = Vector2(0.985, 0.97)
		_panel.create_tween().set_ignore_time_scale().tween_property(_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _row(sep := 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _spacer(h := 0.0) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	if h == 0.0:
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


func _fact(key: String, value: String, col := UiKit.CREAM) -> HBoxContainer:
	var h := _row(18)
	var k := UiKit.label(key, 20, UiKit.MUTED)
	k.custom_minimum_size = Vector2(130, 0)
	h.add_child(k)
	h.add_child(UiKit.label(value, 24, col))
	return h


# ---------------------------------------------------------------- 탭: 의뢰

func _page_case() -> void:
	var c := CaseData.get_case(case_id)
	var cleared := GameSave.is_cleared(case_id)
	var sess := GameSave.sessions(case_id)
	var rooms := CaseData.room_count(case_id)
	var head := _row()
	head.add_child(UiKit.tag("CASE %02d" % int(c["no"]), UiKit.CYAN, 20))
	head.add_child(UiKit.tag("완료 · 다시 방문 가능" if cleared else ("접수됨" if sess == 0 else "상담 진행 중"), UiKit.GOLD if cleared else UiKit.PINK, 20))
	_page.add_child(head)
	var name_row := _row(20)
	var nm := UiKit.label(String(c["client"]), 64, UiKit.CREAM, GameFonts.bold())
	name_row.add_child(nm)
	var age := UiKit.label(String(c["age"]), 22, UiKit.DIM)
	age.size_flags_vertical = Control.SIZE_SHRINK_END
	name_row.add_child(age)
	_page.add_child(name_row)
	# 고민 한 줄: 쪽지 카드
	var note := PanelContainer.new()
	note.add_theme_stylebox_override("panel", UiKit.comic_box(Color(0.97, 0.94, 0.86), 6, 22))
	_page.add_child(note)
	var q := UiKit.label("\"%s\"" % String(c["worry"]), 28, Color(0.16, 0.13, 0.26))
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_child(q)
	_page.add_child(_fact("마음 풍경", "「%s」" % String(c["title"])))
	_page.add_child(_fact("회기", "%d회기째" % (sess + 1) if sess > 0 else "첫 상담"))
	# 진행: 방마다 칸 하나 (마지막은 보스)
	var prog := _row(18)
	var pk := UiKit.label("진행", 20, UiKit.MUTED)
	pk.custom_minimum_size = Vector2(130, 0)
	prog.add_child(pk)
	var pips := _row(8)
	var best := GameSave.best_room(case_id)
	for i in rooms:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(74 if i < rooms - 1 else 96, 26)
		var done := i < best
		var col := (UiKit.GOLD if i == rooms - 1 else UiKit.CYAN) if done else Color(1, 1, 1, 0.1)
		pip.add_theme_stylebox_override("panel", UiKit.box(col, UiKit.INK if done else Color(1, 1, 1, 0.18), 2, 6, 0))
		pip.tooltip_text = String(c["rooms"][i]["name"]) if done or i == 0 else "???"
		pips.add_child(pip)
	prog.add_child(pips)
	prog.add_child(UiKit.label("%d / %d" % [best, rooms], 20, UiKit.DIM))
	_page.add_child(prog)
	_page.add_child(_fact("완료 보상", "의뢰인의 엽서 1장  ·  시간의 결정", UiKit.GOLD))
	_page.add_child(_spacer())
	# 다이브 버튼 (전투의 큰 버튼과 같은 모양)
	var wrap := CenterContainer.new()
	_page.add_child(wrap)
	_dive = VDMainButton.new()
	_dive.text = "다시 방문" if cleared else ("다이브 시작" if sess == 0 else "다시 다이브")
	_dive.custom_minimum_size = Vector2(420, 96)
	_dive.pressed.connect(dive.bind("case"))
	wrap.add_child(_dive)
	# 완료 뒤: 무한 야근 + 다음 의뢰 예고
	if cleared:
		var extra := _row(14)
		extra.alignment = BoxContainer.ALIGNMENT_CENTER
		var endless := UiKit.button("무한 야근  (끝없는 모드)", UiKit.PINK, 20, Vector2(300, 50))
		endless.pressed.connect(dive.bind("endless"))
		extra.add_child(endless)
		_page.add_child(extra)
		var t := CaseData.NEXT_TEASER
		var teaser := PanelContainer.new()
		teaser.add_theme_stylebox_override("panel", UiKit.box(Color(0.07, 0.05, 0.14, 0.9), Color(1, 1, 1, 0.14), 2, 10, 16))
		_page.add_child(teaser)
		var tv := VBoxContainer.new()
		teaser.add_child(tv)
		tv.add_child(UiKit.tag("CASE %02d · %s" % [int(t["no"]), String(t["status"])], UiKit.MUTED, 16))
		var tn := UiKit.label(String(t["note"]), 19, UiKit.DIM)
		tv.add_child(tn)
	else:
		_page.add_child(_spacer(6))


# ---------------------------------------------------------------- 탭: 분대

func _page_squad() -> void:
	_page.add_child(UiKit.tag("SQUAD · 정리 분대", UiKit.CYAN, 20))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	_page.add_child(grid)
	for hid in ["knight", "gunner", "mage", "healer"]:
		var cast := CaseData.cast(hid)
		var prof: Dictionary = CaseData.PROFILES[hid]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(386, 330)
		card.add_theme_stylebox_override("panel", UiKit.box(Color(0.12, 0.09, 0.23, 0.95), Color(cast["color"], 0.7), 2, 12, 16))
		grid.add_child(card)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 7)
		card.add_child(vb)
		var top := _row(14)
		top.add_child(UiKit.face_chip(hid, 92.0))
		var tv := VBoxContainer.new()
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_child(UiKit.label(String(cast["name"]), 32, cast["color"], GameFonts.bold()))
		tv.add_child(UiKit.label(String(prof["role"]), 17, UiKit.DIM))
		top.add_child(tv)
		vb.add_child(top)
		var line := UiKit.label(String(prof["line"]), 17, UiKit.CREAM)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(line)
		for kv in [["고유 스킬", String(VDData.SKILLS[hid]["name"])], ["궁극기", String(VDData.ULTS[hid]["name"])], ["좋아하는 것", String(prof["like"])], ["싫어하는 것", String(prof["hate"])]]:
			var h := _row(10)
			var k := UiKit.label(String(kv[0]), 15, UiKit.MUTED)
			k.custom_minimum_size = Vector2(92, 0)
			h.add_child(k)
			var v := UiKit.label(String(kv[1]), 16, UiKit.CREAM)
			v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(v)
			vb.add_child(h)


# ---------------------------------------------------------------- 탭: 강화

func _page_upgrade() -> void:
	var head := _row()
	head.add_child(UiKit.tag("UPGRADE · 상담소 강화", UiKit.CYAN, 20))
	head.add_child(UiKit.tag("보유 결정 %d" % GameSave.crystals(), UiKit.GOLD, 20))
	_page.add_child(head)
	var sub := UiKit.label("다이브를 마칠 때마다(중단해도) 시간의 결정을 받습니다. 강화는 다음 다이브부터 적용됩니다.", 17, UiKit.DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(sub)
	for id in GameSave.UPGRADE_ORDER:
		var def: Dictionary = GameSave.UPGRADES[id]
		var lv := GameSave.upgrade_level(id)
		var mx := GameSave.upgrade_max(id)
		var cost := GameSave.upgrade_cost(id)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiKit.box(Color(0.12, 0.09, 0.23, 0.95), Color(UiKit.VIOLET, 0.5), 2, 12, 18))
		_page.add_child(card)
		var h := _row(18)
		card.add_child(h)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_theme_constant_override("separation", 6)
		h.add_child(tv)
		var nrow := _row(12)
		nrow.add_child(UiKit.label(String(def["name"]), 27, UiKit.CREAM, GameFonts.bold()))
		if lv > 0:
			nrow.add_child(UiKit.label(String(def["unit"]) % GameSave.upgrade_value(id), 21, UiKit.CYAN))
		tv.add_child(nrow)
		tv.add_child(UiKit.label(String(def["desc"]) + " (단계마다)", 17, UiKit.DIM))
		var pips := _row(6)
		for i in mx:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(38, 12)
			pip.add_theme_stylebox_override("panel", UiKit.box(UiKit.CYAN if i < lv else Color(1, 1, 1, 0.1), UiKit.INK, 2, 4, 0))
			pips.add_child(pip)
		tv.add_child(pips)
		var buy := UiKit.button("완료" if cost < 0 else "결정 %d" % cost, UiKit.GOLD, 22, Vector2(150, 62))
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy.disabled = cost < 0 or GameSave.crystals() < cost
		buy.pressed.connect(_buy.bind(id))
		h.add_child(buy)


func _buy(id: String) -> void:
	if not GameSave.buy_upgrade(id):
		return
	_audio.play("chime", 0.0, -3.0, 1.2)
	_refresh_crystal()
	VDJuice.bump(_crystal, 0.8)
	say("%s, 다음 다이브부터 적용돼요." % String(GameSave.UPGRADES[id]["name"]))
	_show_tab("upgrade", false)


# ---------------------------------------------------------------- 탭: 엽서 벽

func _page_postcards() -> void:
	var owned := GameSave.postcards()
	_page.add_child(UiKit.tag("POSTCARDS · 엽서 벽  %d / 6" % owned.size(), UiKit.CYAN, 20))
	var sub := UiKit.label("의뢰를 완료하면 의뢰인이 엽서를 한 장 보내옵니다.", 17, UiKit.DIM)
	_page.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	_page.add_child(grid)
	for i in 6:
		var cid: String = CaseData.CASE_ORDER[i] if i < CaseData.CASE_ORDER.size() else ""
		var has := cid != "" and owned.has(cid)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(252, 300)
		grid.add_child(card)
		if has:
			var c := CaseData.get_case(cid)
			card.add_theme_stylebox_override("panel", UiKit.comic_box(Color(0.97, 0.94, 0.86), 6, 18))
			card.rotation = deg_to_rad([-2.0, 1.5, -1.0][i % 3])
			var vb := VBoxContainer.new()
			vb.add_theme_constant_override("separation", 10)
			card.add_child(vb)
			vb.add_child(UiKit.tag("CASE %02d · 「%s」" % [int(c["no"]), String(c["title"])], Color(0.5, 0.42, 0.7), 14))
			var stamp := Control.new()
			stamp.custom_minimum_size = Vector2(0, 86)
			stamp.draw.connect(_draw_crown.bind(stamp))
			vb.add_child(stamp)
			var txt := UiKit.label(String(c["postcard"]), 19, Color(0.16, 0.13, 0.26))
			txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vb.add_child(txt)
		else:
			card.add_theme_stylebox_override("panel", UiKit.box(Color(0.07, 0.05, 0.14, 0.75), Color(1, 1, 1, 0.14), 2, 8, 18))
			var q := UiKit.label("?", 90, Color(1, 1, 1, 0.12), GameFonts.display())
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			card.add_child(q)


## 엽서 그림 자리: 종이 왕관 (새 원화가 올 때까지 도형으로).
func _draw_crown(on: Control) -> void:
	var c := Vector2(on.size.x * 0.5, 50.0)
	var pts := PackedVector2Array([c + Vector2(-56, 26), c + Vector2(-62, -22), c + Vector2(-30, 2), c + Vector2(0, -34), c + Vector2(30, 2), c + Vector2(62, -22), c + Vector2(56, 26)])
	on.draw_colored_polygon(pts, Color(1.0, 0.82, 0.38))
	pts.append(pts[0])
	on.draw_polyline(pts, Color(0.16, 0.1, 0.24), 4.0, true)
	for dx: float in [-30.0, 0.0, 30.0]:
		on.draw_circle(c + Vector2(dx, 12), 5.0, Color(1.0, 0.36, 0.62))


# ---------------------------------------------------------------- 탭: 연구실 (개발 도구)

func _page_lab() -> void:
	_page.add_child(UiKit.tag("LAB · 연구실 (개발 도구)", UiKit.CYAN, 20))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i in range(1, SceneSwitcher.SCENES.size()):
		var m: Dictionary = SceneSwitcher.SCENES[i]
		var b := UiKit.button("", UiKit.VIOLET, 20, Vector2(0, 78))
		b.pressed.connect(_enter.bind(i))
		list.add_child(b)
		var h := _row(16)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 16
		h.offset_right = -16
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		var num := UiKit.label(str(i), 34, UiKit.VIOLET, GameFonts.display())
		num.custom_minimum_size = Vector2(36, 0)
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(num)
		var tv := VBoxContainer.new()
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tv)
		tv.add_child(UiKit.label(String(m["title"]) + ("  · 무한 모드 바로가기" if i == BATTLE else ""), 22, UiKit.CREAM))
		var d := UiKit.label(String(m["desc"]), 14, UiKit.MUTED)
		d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		d.custom_minimum_size = Vector2(640, 0)
		tv.add_child(d)
	var tools := _row(10)
	_page.add_child(tools)
	var hints := UiKit.button("튜토리얼 안내 다시 보기", UiKit.CYAN, 17, Vector2(0, 46))
	hints.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hints.pressed.connect(func() -> void:
		GameSave.reset_hints()
		GameSave.set_hints_enabled(true)
		_audio.play("click")
		say("안내를 처음부터 다시 켜 뒀어요."))
	tools.add_child(hints)
	var wipe := UiKit.button("세이브 초기화", UiKit.PINK, 17, Vector2(0, 46))
	wipe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wipe.pressed.connect(func() -> void:
		if _wipe_armed <= 0.0:
			_wipe_armed = 3.0
			wipe.text = "한 번 더 누르면 초기화"
			return
		GameSave.wipe()
		_wipe_armed = 0.0
		_audio.play("click")
		_refresh_crystal()
		_show_tab("lab", false)
		say("기록을 다 지웠어요. 다음에 켜면 처음부터예요."))
	tools.add_child(wipe)


func _enter(index: int) -> void:
	if _busy:
		return
	print("[lobby] enter mode %d" % index)
	if index == BATTLE:
		dive("endless")   # 연구실에서 여는 메인전투 = 예전의 끝없는 전투
		return
	SceneSwitcher.switch_to(index)


# ---------------------------------------------------------------- 등장 · 매 프레임 · 입력

## 허브 등장: 머리글(왼쪽에서) → 반장(아래에서) → 탭(위에서 차례로) → 패널(오른쪽에서) → 다이브 버튼이 톡.
func _play_intro(lead: float) -> void:
	var t := UIIntro.stagger(_header.slice(0, 3), UIIntro.FROM_LEFT, lead + 0.05, 0.08, 0.5, 140.0)
	UIIntro.slide(_header[3], UIIntro.FROM_TOP, lead + 0.2, 0.45, 80.0)
	if _chief:
		UIIntro.slide(_chief, UIIntro.FROM_BOTTOM, lead + 0.12, 0.7, 220.0, true, UIIntro.Ease.QUINT)
	UIIntro.slide(_tab_bar, UIIntro.FROM_TOP, lead + 0.18, 0.45, 70.0)   # 칸 안의 버튼은 따로 밀지 않는다 (HBox 가 자리를 잡기 전이라 전부 x 0 으로 모인다)
	var p := UIIntro.slide(_panel, UIIntro.FROM_RIGHT, t + 0.02, 0.6, 260.0, true, UIIntro.Ease.QUINT)
	p.finished.connect(func() -> void:
		if _dive:
			_dive.bump(1.2))


func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf((now - _clock_us) / 1e6, 0.0, 0.1)
	_clock_us = now
	_t += dt
	if _chief_atlas:
		var f := int(_t * CHIEF_FPS) % CHIEF_FRAMES
		_chief_atlas.region = Rect2(Vector2(f % CHIEF_GRID.x, f / CHIEF_GRID.x) * _chief_cell, _chief_cell)
	if _art:
		# 마우스 패럴랙스: 배경이 반대쪽으로 아주 조금 밀린다
		var m := (get_local_mouse_position() / maxf(size.x, 1.0) - Vector2(0.5, 0.28)).clamp(Vector2(-0.6, -0.6), Vector2(0.6, 0.6))
		_art.position = _art.position.lerp(Vector2(-30, -18) - m * Vector2(22, 12), minf(dt * 4.0, 1.0))
	if _wipe_armed > 0.0:
		_wipe_armed -= dt
		if _wipe_armed <= 0.0 and _tab == "lab":
			_show_tab("lab", false)


func _unhandled_input(event: InputEvent) -> void:
	if _busy or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and _tab == "case":
		dive("case")
		get_viewport().set_input_as_handled()
		return
	# 숫자키: 1 = 다이브, 2~ = 연구실 도구 (예전 로비의 바로가기)
	var n := -1
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		n = event.keycode - KEY_0
	elif event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_9:
		n = event.keycode - KEY_KP_0
	if n == 1:
		dive("case")
	elif n >= 2 and n < SceneSwitcher.SCENES.size():
		_enter(n)
