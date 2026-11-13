## 다이브 한 번(런)의 바깥 고리: 전투(VDBattle) 위에 '의뢰'를 얹는다. docs/FTUE_분석_및_구조설계.md 3.4~3.8
## 허브가 VDBattle.mode_request 를 넣고 들어왔을 때만 생긴다 (연구실·테스트의 전투는 예전 그대로).
##   mode "case"    의뢰: 방 N개(CaseData) + 마지막 방 보스. 방마다 장소 카드·입장 대사·클리어 리액션, 보스 외침,
##                  보스 방을 뺀 모든 방에서 기억 조각(유물) 3택1, 마지막 방을 정리하면 마지막 문 대화 → 기억 로그 → 결과.
##   mode "endless" 무한 야근: 예전의 끝없는 전투 + 일시정지·결과 화면만.
## 공통: 튜토리얼 코치(VDCoach), 일시정지 메뉴(Esc), 결과 화면(VDResultScreen)과 시간의 결정 정산, 허브 강화 적용.
## VDBattle 이 부르는 곳: begin_run (_new_run 끝) · on_wave_types · on_boss_spawn · on_unit_died · finish (마지막 방 클리어 / 전멸).
class_name VDCaseRun
extends Node

const ROOM_CRYSTAL := 2
const CLEAR_CRYSTAL := 10
const FIRST_CLEAR_CRYSTAL := 5
const ENDLESS_ROOM_CRYSTAL := 1
const BOSS_HP_MARKS := [0.75, 0.5, 0.25]

var b: VDBattle
var mode := "case"
var case_id := "harin"
var data := {}
var bark: VDBark
var coach: VDCoach
var stats := {"rooms": 0, "kills": 0}
var finished := false
var heal_mult := 1.0
var result: VDResultScreen
var _layer: CanvasLayer           # 말풍선·코치 (HUD 위)
var _top: CanvasLayer             # 일시정지·기억 로그·결과
var _pause: VDPauseMenu
var _busy_story := false          # 마지막 문 대화·기억 로그가 도는 중
var _announced := 0               # 장소 카드를 띄운 마지막 방
var _seen_types := {}
var _boss_mark := 0
var _known_relics := {}
var _offer_hinted := false
var _await_pick := false          # 유물 3택1 이 떠 있었다: 다음에 들어오는 새 유물만 기억 한 줄로 소개한다


func _init(battle: VDBattle, request: Dictionary) -> void:
	b = battle
	mode = String(request.get("mode", "case"))
	case_id = String(request.get("case", "harin"))
	data = CaseData.get_case(case_id)
	if data.is_empty():
		mode = "endless"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	bark = VDBark.new()
	_layer.add_child(bark)
	coach = VDCoach.new()
	_layer.add_child(coach)
	_top = CanvasLayer.new()
	_top.layer = 40
	add_child(_top)
	b.state_changed.connect(_on_state)
	b.wave_cleared.connect(_on_room_cleared)
	b.subwave_cleared.connect(_on_subwave_cleared)
	b.relic_board.changed.connect(_on_relics_changed)
	SceneSwitcher.esc_guard = _on_esc


func _exit_tree() -> void:
	if SceneSwitcher.esc_guard == Callable(self, "_on_esc"):
		SceneSwitcher.esc_guard = Callable()


func is_case() -> bool:
	return mode == "case"


func room_total() -> int:
	return CaseData.room_count(case_id) if is_case() else 0


func is_final_room() -> bool:
	return is_case() and b.stage >= room_total()


func _room(stage: int) -> Dictionary:
	var rooms: Array = data.get("rooms", [])
	return rooms[clampi(stage - 1, 0, rooms.size() - 1)] if not rooms.is_empty() else {}


## 상단 왼쪽 진행 글자 (VDBattle._refresh_wave_label).
func wave_label(stage: int, wi: int, waves: int) -> String:
	return "방 %d/%d 「%s」  ·  WAVE %d/%d" % [stage, room_total(), String(_room(stage).get("name", "")), wi, waves]


# ---------------------------------------------------------------- 런 시작

## 새 판 (VDBattle._new_run 끝, 배치 단계로 들어가기 직전).
func begin_run() -> void:
	finished = false
	_busy_story = false
	stats = {"rooms": 0, "kills": 0}
	_seen_types.clear()
	_known_relics.clear()
	for id in b.relic_board.tray:   # 시작 보관함의 조각은 소개하지 않는다 (고를 때만 기억 한 줄)
		_known_relics[id] = true
	_boss_mark = 0
	_offer_hinted = false
	bark.clear()
	coach.clear()
	if is_instance_valid(result):
		result.queue_free()
	result = null
	_apply_upgrades()
	for a in b.allies:
		if not a.ult_ready.is_connected(_on_ult_ready):
			a.ult_ready.connect(_on_ult_ready)
	_announced = 1
	var run := b._run_id
	# 입장 연출(전환·안개 열림·HUD 슬라이드)이 끝날 무렵 장소 카드와 첫 대사
	var lead := SceneSwitcher.intro_lead() + 1.7
	await b._wait_real(lead)
	if run != b._run_id or finished:
		return
	_announce(1)
	await b._wait_real(1.6)
	if run != b._run_id or finished:
		return
	var placing := func() -> bool: return b.state != VDBattle.State.PLACEMENT
	coach.show_hint("place", "영웅을 끌어서 하늘색 칸 안에서 자리를 바꿀 수 있어요. 기사는 앞줄, 건너·마법사는 뒷줄이 좋아요.", Callable(), placing, 7.0)
	_hint_relic_place()
	coach.show_hint("start", "자리를 다 잡았으면 [배치 완료] — Space 키로도 시작합니다.", func() -> Rect2: return b._btn_main.get_global_rect(), placing, 30.0)


## 허브 강화 적용 (GameSave.UPGRADES): 새 판마다 유닛이 새로 만들어지므로 겹쳐 쌓이지 않는다.
func _apply_upgrades() -> void:
	var vital := GameSave.upgrade_value("vital") / 100.0
	var spark := GameSave.upgrade_value("spark") / 100.0
	for a in b.allies:
		if vital > 0.0:
			a.max_hp = floorf(a.max_hp * (1.0 + vital))
			a.hp = a.max_hp
		if spark > 0.0 and a.ult_gain > 0.0:
			a.ult = VDData.MAX_ULT * minf(spark, 0.99)
		a._redraw()
	heal_mult = 1.0 + GameSave.upgrade_value("rest") / 100.0
	var pocket := GameSave.upgrade_value("pocket")
	if pocket > 0:
		b.essence += pocket
		b._refresh_essence()


## 장소 카드 + 입장 대사.
func _announce(stage: int) -> void:
	_announced = stage
	if not is_case():
		return
	var room := _room(stage)
	bark.place(String(room.get("name", "")), String(data.get("place_sub", "")), "ROOM %d / %d" % [stage, room_total()])
	b.audio.play("chime", 0.0, -8.0, 0.8)
	if stage == 1 and GameSave.sessions(case_id) > 0 and data.has("revisit_line"):
		bark.say(String(data["revisit_line"][0]), String(data["revisit_line"][1]), 2.4)
	var enter: Array = room.get("enter", [])
	if enter.size() >= 2:
		bark.say(String(enter[0]), String(enter[1]))


# ---------------------------------------------------------------- 전투 이벤트

func _on_state(s: int) -> void:
	if finished:
		return
	match s:
		VDBattle.State.PLACEMENT:
			if b.stage != _announced:
				_announce(b.stage)
			if b.stage > 1:
				_hint_relic_place()
		VDBattle.State.BATTLE:
			if b.stage == 1:
				coach.show_hint("auto", "전투는 자동으로 흘러갑니다. 파란 마나가 가득 차면 고유 스킬이 저절로 나가요.", Callable(), Callable(), 6.0)
			elif b.stage == 2:
				coach.show_hint("speed", "왼쪽 위 [속도] 버튼으로 전투를 빠르게 볼 수 있어요.", func() -> Rect2: return b._btn_speed.get_global_rect(), Callable(), 6.0)
		VDBattle.State.CHOOSE_PATH:
			if b.exits.size() >= 2:
				coach.show_hint("path", "갈림길! 빛나는 길을 누르거나 아래 버튼으로 다음에 들를 방을 고르세요.", func() -> Rect2: return b._path_box.get_global_rect(),
					func() -> bool: return b.state != VDBattle.State.CHOOSE_PATH, 20.0)
			_hint_relic_place()


## 첫 방의 첫 웨이브가 끝나면 마법사 궁극기 게이지를 가득 채워 준다: 첫 런에서 궁극기를 반드시 한 번 써 보게 (시나리오 S6 의 보장).
func _on_subwave_cleared(_wave: int) -> void:
	if finished or b.stage != 1 or GameSave.hint_seen("ult"):
		return
	for a in b.allies:
		if a.id == "mage" and a.alive:
			a.gain_ult(VDData.MAX_ULT)


func _on_ult_ready(u: VDUnit) -> void:
	if finished or not is_instance_valid(u):
		return
	var hid := u.id
	coach.show_hint("ult", "카드가 타오르면 궁극기 준비 완료!  카드를 누르거나 [%s] 키를 눌러 보세요." % b.frame.key_label(hid),
		func() -> Rect2: return _card_rect(hid),
		func() -> bool: return not is_instance_valid(u) or not u.ult_full(), 25.0)


func _card_rect(hid: String) -> Rect2:
	var i: int = b.frame._heroes.find(hid)
	if i < 0:
		return Rect2()
	return b.frame.cards.get_global_transform_with_canvas() * b.frame._card_rect(i)


func _on_room_cleared(_wave: int) -> void:
	if finished:
		return
	stats["rooms"] = int(stats["rooms"]) + 1
	if not is_case():
		return
	var lines: Array = _room(b.stage).get("clear", [])
	if lines.is_empty():
		return
	var line: Array = lines[randi() % lines.size()]
	var run := b._run_id
	await b._wait_real(VDBattle.CLEAR_BANNER_AT + 1.4)
	if run == b._run_id and not finished:
		bark.say(String(line[0]), String(line[1]))


## 적 구성이 정해졌다 (VDBattle._spawn_wave): 처음 보는 엉킨 생각이면 별명으로 소개.
func on_wave_types(types: Array) -> void:
	if not is_case() or finished:
		return
	var tangles: Dictionary = data.get("tangles", {})
	for t in types:
		if _seen_types.has(t) or not tangles.has(t):
			continue
		_seen_types[t] = true
		var tg: Array = tangles[t]
		b._show_msg("엉킨 생각 「%s」 —  \"%s\"" % [String(tg[0]), String(tg[1])], 2.6)
		return


## 보스가 내려앉았다: 이름표를 의뢰의 이름으로 바꾸고 패링 안내.
func on_boss_spawn(e: VDUnit) -> void:
	if finished:
		return
	if is_case() and data.has("boss"):
		var bd: Dictionary = data["boss"]
		b._lbl_boss.text = "「%s」" % String(bd["name"])
		b._show_msg("가장 큰 응어리 「%s」 —  \"%s\"" % [String(bd["name"]), String(bd["alias"])], 3.0)
	if VDData.PARRY.has(e.id) or e.id == "gazer":
		coach.show_hint("parry", "보스가 별을 띄우며 영웅을 노리면, 강조된 카드의 키(Z·X·C·V)를 눌러 받아칠 수 있어요.", Callable(), Callable(), 9.0)


func on_unit_died(u: VDUnit) -> void:
	if not finished and u.team == 1:
		stats["kills"] = int(stats["kills"]) + 1


## 새 유물이 들어왔다: 의뢰인의 기억 한 줄.
func _on_relics_changed() -> void:
	var ids: Array = []
	for id in b.relic_board.tray:
		ids.append(id)
	for c in b.relic_board.relics:
		ids.append(b.relic_board.relics[c])
	var memories: Dictionary = data.get("memories", {})
	for id in ids:
		if _known_relics.has(id) or VDRelicData.is_slot(String(id)):
			continue
		_known_relics[id] = true
		if _await_pick and is_case() and not finished and memories.has(id):
			bark.say("client", "(기억)  " + String(memories[id]), 4.0)
	_await_pick = false


func relic_count() -> int:
	var n := b.relic_board.relics.size()
	for id in b.relic_board.tray:
		if not VDRelicData.is_slot(String(id)):
			n += 1
	return n


func _hint_relic_place() -> void:
	var has := false
	for id in b.relic_board.tray:
		has = true
	if has:
		coach.show_hint("relic_place", "보관함의 조각을 성좌판의 열린 칸에 끌어다 놓으면 전투에서 저절로 발동합니다. 슬롯 카드는 잠긴 칸을 엽니다.",
			func() -> Rect2: return b.relic_hud.get_global_transform_with_canvas() * b.relic_hud.tray_rect(0).merge(b.relic_hud.tray_rect(maxi(b.relic_board.tray.size() - 1, 0))),
			func() -> bool: return b.relic_board.tray.is_empty() or b.state == VDBattle.State.BATTLE, 25.0)


func _process(_dt: float) -> void:
	if finished or b == null:
		return
	if b.relic_hud.has_offer():
		_await_pick = true
	# 유물 3택1 이 처음 떴을 때
	if not _offer_hinted and b.relic_hud.has_offer():
		_offer_hinted = true
		coach.show_hint("relic_pick", "되찾은 기억 조각이에요. 셋 중 하나를 고르면 보관함으로 들어갑니다.", Callable(),
			func() -> bool: return not b.relic_hud.has_offer(), 30.0)
	# 보스 외침: 체력 75 / 50 / 25%
	if is_case() and b.state == VDBattle.State.BATTLE and _boss_mark < BOSS_HP_MARKS.size() and data.has("boss"):
		for e in b.enemies:
			if is_instance_valid(e) and e.is_boss and e.alive:
				if e.hp / e.max_hp <= float(BOSS_HP_MARKS[_boss_mark]):
					var shouts: Array = data["boss"]["shouts"]
					bark.shout(String(shouts[mini(_boss_mark, shouts.size() - 1)]), UiKit.GOLD if _boss_mark < 2 else Color(0.8, 0.85, 1.0))
					_boss_mark += 1
				break


# ---------------------------------------------------------------- 일시정지

## SceneSwitcher 의 Esc · [상담소로]: 여기서 받는다 (true = 처리함).
func _on_esc() -> bool:
	if finished or _busy_story:
		return true   # 결과·엔딩 중에는 버튼으로만 나간다
	if is_instance_valid(_pause):
		_pause.resume()
		return true
	if b.ult_aim.active or b.ult.active:
		return true   # 궁극기 조준·연출 중에는 그쪽이 Esc 를 쓴다
	_pause = VDPauseMenu.new()
	_pause.info = ("「%s」 · 방 %d / %d · 정리한 방 %d" % [String(data.get("title", "")), b.stage, room_total(), int(stats["rooms"])]) if is_case() \
		else "무한 야근 · 방 %d · 정리한 방 %d" % [b.stage, int(stats["rooms"])]
	_pause.restart_requested.connect(func() -> void: b.restart())
	_pause.abort_requested.connect(func() -> void: finish(false, true))
	_top.add_child(_pause)
	b.audio.play("click")
	return true


# ---------------------------------------------------------------- 끝: 정산 → (완료면 엔딩) → 결과

func _crystals(cleared: bool, first_clear: bool) -> Array:
	var rooms := int(stats["rooms"])
	if not is_case():
		return [rooms * ENDLESS_ROOM_CRYSTAL, "정리한 방 %d × %d" % [rooms, ENDLESS_ROOM_CRYSTAL]]
	var n := maxi(rooms * ROOM_CRYSTAL, 1)
	var note := "정리한 방 %d × %d" % [rooms, ROOM_CRYSTAL] if rooms > 0 else "참가 1"
	if cleared:
		n += CLEAR_CRYSTAL
		note += "  +  의뢰 완료 %d" % CLEAR_CRYSTAL
	if first_clear:
		n += FIRST_CLEAR_CRYSTAL
		note += "  +  첫 완료 %d" % FIRST_CLEAR_CRYSTAL
	return [n, note]


## 다이브가 끝났다. cleared = 마지막 방까지 정리, aborted = 일시정지 메뉴에서 중단.
func finish(cleared: bool, aborted := false) -> void:
	if finished:
		return
	finished = true
	coach.clear()
	if aborted:
		b.ult.reset()
		b._set_state(VDBattle.State.GAMEOVER)   # 결과 화면 뒤에서 전투가 계속 돌지 않게
	var first_unlock := GameSave.total_sessions() == 0
	var first_clear := cleared and is_case() and not GameSave.is_cleared(case_id)
	var gain: Array = _crystals(cleared, first_clear)
	var session := GameSave.sessions(case_id) + 1
	if is_case():
		GameSave.record_session(case_id, cleared, int(stats["rooms"]), int(gain[0]))
	else:
		GameSave.add_crystals(int(gain[0]))
	print("[case] finish cleared=%s aborted=%s rooms=%d kills=%d crystals=+%d" % [cleared, aborted, int(stats["rooms"]), int(stats["kills"]), int(gain[0])])
	var d := {
		"cleared": cleared, "aborted": aborted, "mode": mode,
		"case_no": int(data.get("no", 0)), "case_title": String(data.get("title", "")), "client": String(data.get("client", "")),
		"session": session, "rooms": int(stats["rooms"]), "room_total": room_total(), "kills": int(stats["kills"]),
		"relics": relic_count(), "essence": b.essence, "crystals": int(gain[0]), "crystal_note": String(gain[1]),
		"postcard": String(data.get("postcard", "")) if first_clear else "", "first_unlock": first_unlock and is_case(),
	}
	if cleared and is_case():
		await _play_ending()
	elif is_case() and not aborted and data.has("defeat_line"):
		bark.clear()
		bark.say(String(data["defeat_line"][0]), String(data["defeat_line"][1]), 3.0)
		await b._wait_real(1.6)
	if not is_inside_tree():
		return
	_show_result(d)


## 의뢰 완료: 마지막 문 대화(의뢰인이 직접 연다) → 기억 로그 3장 → 반장 한마디.
func _play_ending() -> void:
	_busy_story = true
	await b._wait_real(2.6)   # 방 클리어 리액션(반장의 왕관 이야기)을 읽을 틈
	if not is_inside_tree():
		return
	var door: Array = data.get("door", [])
	if not door.is_empty():
		var dlg := StoryDialog.play(self, door, 0.7, 45)
		await dlg.finished
	if not is_inside_tree():
		return
	var cards: Array = data.get("ending", [])
	if not cards.is_empty():
		var log_view := VDMemoryLog.new()
		log_view.cards = cards
		_top.add_child(log_view)
		b.audio.play("chime", 0.0, -4.0, 0.9)
		await log_view.finished
	if not is_inside_tree():
		return
	if data.has("ending_line"):
		var dlg2 := StoryDialog.play(self, [data["ending_line"]], 0.7, 45)
		await dlg2.finished
	_busy_story = false


func _show_result(d: Dictionary) -> void:
	result = VDResultScreen.new()
	result.setup(d, b.audio)
	result.to_hub.connect(func() -> void:
		get_tree().paused = false
		SceneSwitcher.esc_guard = Callable()
		SceneSwitcher.go_lobby())
	result.retry.connect(func() -> void:
		get_tree().paused = false
		b.restart())
	_top.add_child(result)
