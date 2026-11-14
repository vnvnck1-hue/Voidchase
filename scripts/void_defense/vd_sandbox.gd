## 전투 연습장: 연출 연구실 "전투 연습장" 이 실제 전투(VDBattle)를 이 모드로 연다 (VDBattle.sandbox_request).
## 스킬·궁극기·AI·타격감이 전투에 묶여 있어 전투 씬을 그대로 쓰고, 이 노드가 흐름만 바꾼다:
##   고른 영웅만 세우고, 배치·웨이브·클리어 보상·게임 오버 없이 고른 적을 계속 다시 세운다 (다 쓰러지면 다시 소환, 영웅이 다 쓰러지면 일으킴).
##   자동 전투 [T]: 켜면 평소처럼 알아서 싸운다 (마나가 차면 고유 스킬도 자동). 끄면 영웅은 버튼으로만 행동한다.
##   일반 공격 [Q] · 고유 스킬 [W] · 궁극기 [E]: 조작할 영웅이 즉시 쓴다 (게이지는 버튼이 채운다). 대상은 클릭한 몬스터, 없으면 가장 가까운 적.
##   필드의 몬스터·영웅을 끌어 옮기기 · 몬스터를 클릭하면 대상으로 고르고 바로 일반 공격 · 영웅을 클릭하면 조작할 영웅으로.
class_name VDSandbox
extends CanvasLayer

const ENEMY_SETS := [
	["공허 잔재 ×3", ["normal", "normal", "normal"]],
	["섞어서 5마리", ["normal", "fast", "skirmisher", "tank", "crab"]],
	["공허 결정체 ×2", ["tank", "tank"]],
	["공허 수정게", ["crab"]],
	["공허 수정게 ×2", ["crab", "crab"]],
	["공허 망루 (4칸)", ["longneck"]],
	["공허 군주 (보스)", ["boss"]],
	["웨이브 (7마리)", ["normal", "normal", "fast", "skirmisher", "tank", "crab", "normal"]],
]
const HP_MULTS := [["체력 ×1", 1.0], ["체력 ×3", 3.0], ["체력 ×10", 10.0]]
const RESPAWN_SEC := 1.2       # 적이 다 쓰러지고 다시 세우기까지
const REVIVE_SEC := 1.5        # 영웅이 다 쓰러지고 일으키기까지
const DASH_SEC := 0.16         # 수동 일반 공격: 근접 영웅이 대상 곁으로 붙는 시간

## 연습장 설정은 영웅을 바꿔 전투를 새로 열어도 이어진다
static var _set_i := 1
static var _hp_i := 1
static var _auto := true
static var _enemy_fight := false

var b: VDBattle
var heroes: Array = []          # 세울 영웅 id (VDBattle._new_run 이 읽는다)
var target: VDUnit = null       # 클릭해서 고른 몬스터
var _control := 0               # heroes 중 조작할 영웅
var _spawn_id := 0
var _drag := {}                 # {"unit", "from", "moved"}
var _ring: Node2D               # 고른 몬스터 발밑 표시
var _opt_control: OptionButton
var _chk_auto: CheckBox
var _lbl_info: Label


static func scene_index(scene_name: String) -> int:
	for i in SceneSwitcher.SCENES.size():
		if SceneSwitcher.SCENES[i]["name"] == scene_name:
			return i
	return -1


func _init(battle: VDBattle, hero_ids: Array) -> void:
	b = battle
	heroes = hero_ids
	layer = 45


func _ready() -> void:
	_build_ui()
	_ring = Node2D.new()
	_ring.z_index = 2
	_ring.visible = false
	_ring.draw.connect(func() -> void:
		var pts := PackedVector2Array()
		for i in 41:
			var a := TAU * i / 40.0
			pts.append(Vector2(cos(a) * 46.0, sin(a) * 23.0))
		_ring.draw_polyline(pts, Color(1.0, 0.85, 0.3, 0.95), 3.0, true))
	b.ground_fx.add_child(_ring)


# ---------------------------------------------------------------- 흐름 (VDBattle 이 부른다)

## 새 판(_new_run 끝): 고른 적을 세우고 바로 전투
func begin(_run: int) -> void:
	target = null
	_spawn_id += 1
	var sid := _spawn_id
	b._set_state(VDBattle.State.SPAWNING)   # 전투 줌인, 소환 동안은 아무도 움직이지 않는다
	var types: Array = ENEMY_SETS[_set_i][1].duplicate()
	types.sort_custom(func(x: String, y: String) -> bool: return VDBattle._enemy_size(x) > VDBattle._enemy_size(y))   # 넓은 자리부터
	var spots: Array = VDMap.local_cells(b.room, "E")
	spots.shuffle()
	var used := {}
	for t in types:
		var sz := VDBattle._enemy_size(t)
		var cell := b._random_spawn_cell(spots, used, sz)
		if cell.x == -999:
			continue
		for x in sz:
			for y in sz:
				used[cell + Vector2i(x, y)] = true
		var e := b._make_unit(VDData.ENEMIES[t], t, 1, cell, float(HP_MULTS[_hp_i][1]), 1.0)
		var foot := e.position
		var heavy := e.is_boss or e.size > 1
		e.appear(VDSummonFx.play_impact.bind(b.vfx, b.ground_fx, b.fx_root, b.camera, foot, heavy))
		b.enemies.append(e)
		b.audio.play("boss_spawn" if heavy else "enemy_spawn", 0.12)
		VDSummonFx.play_portal(b.vfx, b.ground_fx, foot, heavy)
		await get_tree().create_timer(0.12).timeout
		if sid != _spawn_id:
			return
	await get_tree().create_timer(VDUnit.appear_duration() + 0.1).timeout
	if sid == _spawn_id:
		b._set_state(VDBattle.State.BATTLE)


func on_enemies_down() -> void:
	var sid := _spawn_id
	await get_tree().create_timer(RESPAWN_SEC).timeout
	if sid == _spawn_id and b._alive_count(b.enemies) == 0:
		respawn_enemies()


func on_heroes_down() -> void:
	# 메서드에 묶어 연결: 그 사이 연습장을 나가 이 노드가 해제되면 연결도 함께 끊긴다
	get_tree().create_timer(REVIVE_SEC).timeout.connect(_revive_heroes.bind(_spawn_id))


func _revive_heroes(sid: int) -> void:
	if sid != _spawn_id:
		return
	for a in b.allies:
		if not a.alive:
			a.revive(1.0)
			b.on_hero_revived(a)


## 지금 적을 치우고 고른 적을 다시 세운다
func respawn_enemies() -> void:
	for e in b.enemies:
		e.queue_free()
	b.enemies.clear()
	b.essence_drops.clear()
	b.goo.clear()
	begin(b._run_id)


## 이 유닛이 이번 틱에 스스로 행동하는가 (VDBattle._tick_team)
func acts(u: VDUnit) -> bool:
	if not _drag.is_empty() and _drag["unit"] == u and _drag["moved"]:
		return false   # 들고 있는 동안은 쉰다
	return _auto if u.team == 0 else _enemy_fight


# ---------------------------------------------------------------- 조작

func hero() -> VDUnit:
	var hid: String = heroes[clampi(_control, 0, heroes.size() - 1)]
	for a in b.allies:
		if a.id == hid:
			return a
	return null


func _ready_to_act(u: VDUnit) -> bool:
	return u != null and u.alive and b.state == VDBattle.State.BATTLE and not b.ult.active and not b.ult_aim.active \
		and not u.casting and not u.winding and u.stun_timer <= 0.0


func _target_for(u: VDUnit) -> VDUnit:
	if is_instance_valid(target) and target.alive:
		return target
	return b._nearest(u, b.enemies)


## 일반 공격: 공격 간격을 무시하고 바로 (영웅의 무기 당기기 예비 동작은 그대로). 근접은 대상 곁으로 붙어서, 원거리는 사거리 무시.
## 힐러는 가장 다친 아군 회복.
func attack() -> void:
	var u := hero()
	if not _ready_to_act(u):
		return
	if u.is_healer:
		var patient := b._most_wounded(u, b.allies)
		b.heal_once(u, patient if patient != null else u)
		return
	var tgt := _target_for(u)
	if tgt == null:
		return
	u.atk_timer = 0.0
	# 근접 영웅이 멀리 있으면 대상 곁 빈 칸으로 한달음에 붙고 나서 친다 (원거리는 그 자리에서)
	if u.dist_to(tgt) > u.attack_range and u.attack_range <= 1:
		var c := b.free_cell_near(u.cell, tgt.cell)
		if c != u.cell and u.dist_to_cell(c) > 0:
			b._step_unit(u, c, DASH_SEC)
			await get_tree().create_timer(DASH_SEC, false).timeout
			if not is_instance_valid(u) or not u.alive or not is_instance_valid(tgt) or not tgt.alive:
				return
	var sec: float = VDHeroPose.WINDUP.get(u.id, 0.0)
	if sec > 0.0:
		u.windup(tgt.position, sec)
		await get_tree().create_timer(sec, false).timeout
		if not is_instance_valid(u):
			return
		u.release_windup()
		if not u.alive or not is_instance_valid(tgt) or not tgt.alive:
			return
	b._do_attack(u, tgt)


## 고유 스킬: 마나와 상관없이 바로
func skill() -> void:
	var u := hero()
	if not _ready_to_act(u):
		return
	if not b.cast_skill(u):
		b.audio.play("denied", 0.0, -2.0)


## 궁극기: 게이지를 채우고 카드를 누른 것과 같게 (조준이 필요한 영웅은 조준 화면이 뜬다)
func ultimate() -> void:
	var u := hero()
	if u == null or not u.alive:
		return
	u.ult = VDData.MAX_ULT
	b.try_ult(u.id)


func _set_heroes(ids: Array) -> void:
	heroes = ids
	_control = 0
	target = null
	b.restart()
	_refresh_control()


# ---------------------------------------------------------------- 입력: 끌어 옮기기 · 클릭

## 끄는 중의 이동·놓기는 GUI 보다 먼저 받는다 (패널·카드 위에서 놓아도 끌기가 끝나게)
func _input(event: InputEvent) -> void:
	if not _drag.is_empty() and event is InputEventMouse:
		_unhandled_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				attack()
			KEY_W:
				skill()
			KEY_E:
				ultimate()
			KEY_T:
				_chk_auto.button_pressed = not _chk_auto.button_pressed
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if b.ult_aim.active or b.ult.active:
		_drag = {}
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var u := _unit_at_screen(event.position)
			if u != null:
				_drag = {"unit": u, "from": event.position, "moved": false}
				get_viewport().set_input_as_handled()
			return
		if _drag.is_empty():
			return
		var u: VDUnit = _drag["unit"]
		var moved: bool = _drag["moved"]
		_drag = {}
		get_viewport().set_input_as_handled()
		if not is_instance_valid(u):
			return
		if moved:
			_drop(u, _board_pos(event.position))
		elif u.team == 1:
			target = u
			attack()
		else:
			var i := heroes.find(u.id)
			if i >= 0:
				_control = i
				_refresh_control()
	elif event is InputEventMouseMotion and not _drag.is_empty():
		var u: VDUnit = _drag["unit"]
		if not is_instance_valid(u):
			_drag = {}
			return
		if not _drag["moved"] and event.position.distance_to(_drag["from"]) > 8.0:
			_drag["moved"] = true
			u.z_index = 100
			u.create_tween().set_ignore_time_scale(true).tween_property(u, "scale", Vector2(1.15, 1.15), 0.1) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			b.audio.play("tick", 0.05, -6.0, 1.4)
		if _drag["moved"]:
			var m := _board_pos(event.position)
			u.position = m + Vector2(0, -20)
			var c := VDData.to_cell(m)
			b.board.set_hover(c, b._fits(u, c))
		get_viewport().set_input_as_handled()


## 화면(이벤트) 좌표 → 보드 좌표. OS 마우스 위치 대신 이벤트 좌표를 써서 주입한 입력에도 맞다
func _board_pos(screen: Vector2) -> Vector2:
	return b.board.get_global_transform_with_canvas().affine_inverse() * screen


func _unit_at_screen(screen: Vector2) -> VDUnit:
	var m := _board_pos(screen)
	var c := VDData.to_cell(m)
	var units: Array[VDUnit] = []
	for u in b.enemies + b.allies:
		if is_instance_valid(u) and u.alive and u.visible:
			units.append(u)
	for u in units:
		if u.occupies(c):
			return u
	# 칸이 아니라 몸통을 눌러도 집히게 (키 큰 유닛)
	var best: VDUnit = null
	var best_d := 70.0
	for u in units:
		var d := m.distance_to(u.position + Vector2(0, u._top * 0.5))
		if d < best_d:
			best_d = d
			best = u
	return best


## 놓기: 방 안 빈 칸이면 그 칸에 찌그러지며 착지, 아니면 원래 칸으로 튕겨 돌아간다
func _drop(u: VDUnit, at: Vector2) -> void:
	var c := VDData.to_cell(at)
	b.board.set_hover(Vector2i(-1, -1), false, false)
	var tw := u.create_tween().set_ignore_time_scale(true)
	if b._fits(u, c):
		u.cell = c
		b.audio.play("place")
		b.vfx.spawn("dust", b.ground_fx, u.foot_at(c), 0.9)
		tw.tween_property(u, "position", u.foot_at(c), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(u, "scale", Vector2(1.2, 0.82), 0.05)
		tw.tween_property(u, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		b.audio.play("tick", 0.0, -4.0, 0.6)
		tw.tween_property(u, "position", u.foot_at(u.cell), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(u, "scale", Vector2.ONE, 0.3)
	tw.tween_callback(func() -> void:
		if is_instance_valid(u):
			u.z_index = 0
			u.snap_to_cell())


func _process(_dt: float) -> void:
	var on := is_instance_valid(target) and target.alive
	_ring.visible = on
	if on:
		_ring.position = target.position
	# 분대 카드: 연습에 안 나온 영웅은 회색으로
	for hid in VDData.HERO_ORDER:
		if not heroes.has(hid):
			b.frame.set_hero(hid, 0.0, 0.0, false, false, "연습 제외")
	var u := hero()
	if u != null:
		_lbl_info.text = "%s  ·  마나 %d%%  ·  궁극기 %d%%" % [u.display_name, int(u.mana / VDData.MAX_MANA * 100.0), int(u.ult / VDData.MAX_ULT * 100.0)]


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = VDData.font()
	theme.default_font_size = 17
	root.theme = theme
	add_child(root)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.14, 0.88)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	SceneSwitcher.pin(panel, Vector2(0, 0), Rect2(16, 120, 430, 0))
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 7)
	panel.add_child(vb)

	var top := HBoxContainer.new()
	vb.add_child(top)
	_label(top, "전투 연습장", 24, Color(1.0, 0.92, 0.6)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(top, "◀ 연출 연구실", func() -> void: SceneSwitcher.switch_to(scene_index("FxLab")))

	# 캐릭터: 한 명 또는 4명 모두
	var choices: Array = []
	for hid in VDData.HERO_ORDER:
		choices.append([VDData.HEROES[hid]["name"], [hid]])
	choices.append(["4명 모두", VDData.HERO_ORDER.duplicate()])
	var opt_hero := _option(vb, "캐릭터", choices.map(func(c: Array) -> String: return c[0]))
	for i in choices.size():
		if choices[i][1] == heroes:
			opt_hero.select(i)
	opt_hero.item_selected.connect(func(i: int) -> void: _set_heroes(choices[i][1].duplicate()))
	_opt_control = _option(vb, "조작", [])
	_opt_control.item_selected.connect(func(i: int) -> void: _control = i)
	_refresh_control()

	var opt_set := _option(vb, "적", ENEMY_SETS.map(func(s: Array) -> String: return s[0]))
	opt_set.select(_set_i)
	opt_set.item_selected.connect(func(i: int) -> void:
		_set_i = i
		respawn_enemies())
	var opt_hp := _option(vb, "적 체력", HP_MULTS.map(func(s: Array) -> String: return s[0]))
	opt_hp.select(_hp_i)
	opt_hp.item_selected.connect(func(i: int) -> void:
		_hp_i = i
		respawn_enemies())

	var checks := HBoxContainer.new()
	checks.add_theme_constant_override("separation", 16)
	vb.add_child(checks)
	_chk_auto = _check(checks, "자동 전투 [T]", _auto, func(on: bool) -> void: _auto = on)
	_check(checks, "적도 싸우기", _enemy_fight, func(on: bool) -> void: _enemy_fight = on)

	var acts_row := HBoxContainer.new()
	acts_row.add_theme_constant_override("separation", 6)
	vb.add_child(acts_row)
	for a in [["일반 공격 [Q]", attack], ["고유 스킬 [W]", skill], ["궁극기 [E]", ultimate]]:
		var bt := _button(acts_row, a[0], a[1])
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bt.custom_minimum_size.y = 46
	_button(vb, "적 다시 세우기", respawn_enemies)
	_lbl_info = _label(vb, "", 15, Color(1.0, 0.85, 0.45))
	var help := _label(vb, "몬스터·영웅을 끌어 옮기기 · 몬스터 클릭 = 대상으로 골라 바로 일반 공격 · 영웅 클릭 = 조작할 영웅\n" +
		"자동 전투를 끄면 영웅은 버튼으로만 움직인다 (공격 간격·마나·게이지 무시, 근접은 대상 곁으로 붙어서 친다). 조준하는 궁극기는 화면을 눌러 조준", 14, Color(0.78, 0.74, 0.92))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 400


func _refresh_control() -> void:
	if _opt_control == null:
		return
	_opt_control.clear()
	for hid in heroes:
		_opt_control.add_item(VDData.HEROES[hid]["name"])
	_opt_control.select(clampi(_control, 0, heroes.size() - 1))
	_opt_control.get_parent().visible = heroes.size() > 1


func _option(parent: Control, title: String, items: Array) -> OptionButton:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	parent.add_child(hb)
	_label(hb, title, 16, Color(0.85, 0.8, 0.95)).custom_minimum_size.x = 70
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for it in items:
		opt.add_item(it)
	hb.add_child(opt)
	return opt


func _check(parent: Control, text: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(cb)
	parent.add_child(c)
	return c


func _label(parent: Node, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var bt := Button.new()
	bt.text = text
	bt.focus_mode = Control.FOCUS_NONE
	bt.pressed.connect(cb)
	parent.add_child(bt)
	return bt
