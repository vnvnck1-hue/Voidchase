## 연출 연구실: 들어오면 다듬을 연출을 목록(MODES)에서 고르고, 그 연출의 조절값을 실시간으로 바꾸며 반복 재생한다.
##   몬스터 등장  — VDSummonFx (user://summon_fx.json)
##   초궁극기 컷인 — vd_super_cutin_fx.gd (user://super_cutin_fx.json)
##   궁극기 카드 오버차지 — vd_card_flame_fx.gd (user://card_flame_fx.json): 실제 분대 카드(VDBattleFrame)를 띄워 값이 바로 보인다
##   유물 투사체 — relics/vd_relic_proj_fx.gd (user://relic_proj_fx.json): 화면 오른쪽 위(성좌판 자리)에서 적·아군에게 실제 VDRelicFx 를 쏜다.
##     대상 목록 = 투사체 종류. 패널에는 공통 값 + 고른 종류의 값만 보인다
##   몬스터 피격 — vd_hit_fx.gd (user://hit_fx.json): 터치 게임 데모의 피격 파티클(VDTouchHit). 세워 둔 적을 차례로 때린다 (클릭해도 때림)
##     + 몸 반응(찌그러짐·밀림·하얀 번쩍임)과 아군이 때릴 때의 화면 흔들림·히트스탑 배율
##     카툰 피격이 켜져 있으면(vd_cartoon_hit_fx.gd "on") 파티클은 전투와 같게 카툰 피격으로 보인다
##   몬스터 피격 · 카툰 — vd_cartoon_hit_fx.gd (user://cartoon_hit_fx.json): VFX연구의 카툰 피격(vfx/monster_hit). 플래시·타격 선·링·스파크·체액·색.
##     아군 쪽에서 몬스터 쪽으로 때린 방향으로 터진다. 몸 반응·화면은 "몬스터 피격" 값을 그대로 쓴다
##   몬스터 사망 — vd_kill_fx.gd (user://kill_fx.json): 별 섬광·몸이 녹아내림·체액·쇼크웨이브·흔들림·슬로모션. 세워 둔 적을 차례로 쓰러뜨리고 다시 세운다 (클릭하면 그 적을 바로 처치)
##   화면 전환 — scripts/screen_transition_fx.gd (user://transition_fx.json): 그래픽 와이프(scripts/screen_transition.gd)를 필드 위에서 반복 재생.
##     대상 목록 = 프리셋(슬래시 스택/슬라이스). 색판 4색·강조색 2색·망점 간격·덮기/걷기 시간. 배속 슬라이더로 느리게 볼 수 있다
## 조절값 스크립트는 같은 모양(PARAMS · g · set_value · save · load_saved · reset · describe · summary)이라 패널은 하나로 그린다.
## 실제 전투와 같은 보드·이펙트·카메라(셰이크·히트스탑)를 쓰고, 값을 바꾸면 잠시 뒤 바로 다시 재생한다.
## "저장" 하면 VOID DEFENSE 전투에도 그대로 쓰인다.
##   목록: 숫자키로 고르기 · 연구 중: Space 재생 · R 자동 반복 토글 · H 패널 숨기기 · Tab 연출 목록 · Esc 로비
extends Node2D

const CutinFx := preload("res://scripts/void_defense/vd_super_cutin_fx.gd")
const CardFlameFx := preload("res://scripts/void_defense/vd_card_flame_fx.gd")
const RelicProjFx := preload("res://scripts/void_defense/relics/vd_relic_proj_fx.gd")
const HitFx := preload("res://scripts/void_defense/vd_hit_fx.gd")
const CartoonHit := preload("res://scripts/void_defense/vd_cartoon_hit_fx.gd")
const KillFx := preload("res://scripts/void_defense/vd_kill_fx.gd")
const ParryFx := preload("res://scripts/void_defense/vd_parry_fx.gd")
const WipeFx := preload("res://scripts/screen_transition_fx.gd")
const ScreenTransition := preload("res://scripts/screen_transition.gd")
const WIPE_LAYER := 35           # 연구실 패널(40) 아래 · 컷인(30) 위
const KILL_TARGETS := ["보통 적 넷 차례로", "보스 하나"]
const PARRY_TARGETS := ["성공 · 실패 번갈아", "패링 성공만", "패링 실패만 (일격)"]
const VDShockwave := preload("res://scripts/void_defense/vd_shockwave.gd")
const HIT_TARGETS := ["물리 · 보통 + 강타 번갈아", "물리 · 보통 타격만", "물리 · 강타만", "번개 (형광 노랑)", "화염 (형광 주황)", "서리 (형광 청록)", "비전·정수 (형광 자홍)"]
const HIT_ELEMENT := ["", "", "", "번개", "화염", "서리", "정수"]   # HIT_TARGETS 순서 → 피격 색 속성
const FxColors := preload("res://scripts/void_defense/vd_fx_colors.gd")
## 투사체 종류 → 색을 빌려 올 유물 (전투와 같은 색)
const RELIC_OF := {"bolt": "thunder_shard", "comet": "ember", "frost": "frost_crystal", "feather": "star_feather", "essence": "essence_vial"}
const RELIC_ORIGIN := Vector2(-230.0, 190.0)   # 투사체 출발점: 화면 오른쪽 위에서 (성좌판 칸 자리)
const BattleFrame := preload("res://scripts/void_defense/vd_battle_frame.gd")
const FLAME_TARGETS := ["4장 모두", "건너", "마법사", "기사", "힐러"]   # 0 = 전부, 나머지는 VDData.HERO_ORDER 순서
const MODES := [
	{"id": "summon", "title": "몬스터 등장", "desc": "차원 균열에서 적이 떨어져 꽂히는 소환 연출. 낙하·찌그러짐·튕김·타격감."},
	{"id": "cutin", "title": "초궁극기 컷인", "desc": "궁극기 전면 컷인. 띠가 맞물리는 박자·섬광·흔들림·캐릭터 등장·스킬 이름 도장."},
	{"id": "flame", "title": "궁극기 카드 오버차지", "desc": "궁극기 게이지가 찬 분대 카드 둘레의 에너지 줄기. 줄기 길이·간격·밝기·후광·스윕·픽셀·색·켜짐 타이밍."},
	{"id": "relic", "title": "유물 투사체", "desc": "성좌판 유물이 쏘는 투사체 5종. 비행 시간·곡선·꼬리·띠 굵기와 모양·번개 꺾임·착탄 버스트·글자·반짝이. 몬스터를 끌어 옮기고 클릭해 바로 발사."},
	{"id": "hit", "title": "몬스터 피격", "desc": "몬스터가 맞을 때: 터지는 파티클(별 섬광 + 번개) 크기·속도·색, 몸 찌그러짐·밀림·하얀 번쩍임, 화면 흔들림·히트스탑. 몬스터를 클릭하면 바로 때림."},
	{"id": "cartoon_hit", "title": "몬스터 피격 · 카툰", "desc": "VFX연구에서 만든 카툰 피격 파티클: 3톤 별 섬광·타격 선·충격파 링·스파크·체액 방울의 크기·시간·속도·색. 전투 적용 켜기/끄기. 몬스터를 클릭하면 바로 때림."},
	{"id": "kill", "title": "몬스터 사망", "desc": "몬스터가 쓰러질 때: 별 섬광·몸이 녹아내리는 모양과 시간·바닥 체액·화면 쇼크웨이브·흔들림·히트스탑·슬로모션. 몬스터를 클릭하면 바로 처치."},
	{"id": "parry", "title": "패링", "desc": "보스의 패링 공격: 눈에서 별이 팟—칭 터지는 예고(스케일 트윈 박자·크기·빛기둥·핵·고리), 유지 중 떨림, 예고·성공 순간의 히트스탑·슬로모션·흔들림, 성공 별 폭발, 분대 카드 강조(빛기둥·반짝이·키캡)."},
	{"id": "wipe", "title": "화면 전환", "desc": "장면을 바꿀 때 화면을 통째로 쓸고 가는 그래픽 와이프. 대상에서 프리셋(슬래시 스택·슬라이스·번개 닫힘·번개 일섬·번개 재단·워프 다이브·워프 러시)을 고르면 그 프리셋의 조절값(시간·타격감·색)만 나온다. 배속으로 천천히 본다."},
	{"id": "battle", "title": "전투 연습장", "desc": "실제 전투를 연습 모드로. 캐릭터를 골라 자동 전투, 일반 공격·고유 스킬·궁극기를 버튼으로 마음대로. 몬스터를 끌어 옮기고 클릭하면 공격."},
]

const PANEL_W := 560.0
const ZOOM := 1.7
const TARGETS := [
	["공허 잔재", "normal", 1], ["공허 파편", "fast", 1], ["공허 포자", "skirmisher", 1],
	["공허 결정체", "tank", 1], ["공허 수정게", "crab", 1], ["공허 망령 (4칸)", "wraith", 1], ["공허 망루 (4칸)", "longneck", 1], ["공허 군주 (보스)", "boss", 1], ["공허 감시자 (보스)", "watcher", 1], ["공허 응시자 (첫 보스)", "gazer", 1], ["웨이브 (5마리)", "normal", 5],
]
const REPLAY_GAP := 0.7          # 자동 반복: 연출이 끝나고 다음 재생까지(초)
const EDIT_DELAY := 0.3          # 값을 바꾼 뒤 이만큼 손을 떼면 다시 재생

var map: VDMap
var room := {}
var board: VDBoard
var ground_fx: Node2D
var units_root: Node2D
var fx_root: Node2D
var vfx: VDVfx
var camera: VDCamera
var audio: VDAudio

var _enemies: Array[VDUnit] = []
var _run := 0
var _mode := ""                  # MODES 의 id. "" 이면 목록 화면
var _fx                          # 지금 다듬는 연출의 조절값 스크립트 (VDSummonFx / CutinFx)
var _cutin: CanvasLayer          # 재생 중인 컷인
var _target := 0
var _auto := true
var _speed := 1.0
var _dirty := false
var _edit_timer := -1.0
var _rows := {}                  # key -> {"slider", "spin"} 또는 {"opt"}
var _lbl_status: Label
var _lbl_total: Label
var _lbl_title: Label
var _chk_auto: CheckBox
var _lbl_speed: Label
var _ui: CanvasLayer             # 연구 화면 UI (연출을 바꾸면 새로 짓는다)
var _panel: Control
var _picker: CanvasLayer         # 연출 목록
var _flame_layer: CanvasLayer    # 불꽃 연구: 실제 분대 카드 HUD
var _flame_frame                 # VDBattleFrame
var _ally: VDUnit                # 유물 투사체 연구: 별 깃털 대상
var _origin_mark: Node2D         # 유물 투사체 연구: 출발점(성좌판 칸) 표시
var _drag := {}                  # 유물 투사체 연구: 누르고 있는 유닛 {"unit", "from", "moved"}
var goo: VDGoo                    # 몬스터 사망 연구: 바닥 체액
var parry_impact: VDParryImpact  # 패링 충돌 화면 연출 (VDParry.fx_impact 가 찾는다)
var shockwave                    # 몬스터 사망 연구: 화면 쇼크웨이브 (VDShockwave)
var _wipe: CanvasLayer           # 화면 전환 연구: 재생 중인 전환


func _ready() -> void:
	randomize()
	VDSummonFx.load_saved()
	CutinFx.load_saved()
	CardFlameFx.load_saved()
	RelicProjFx.load_saved()
	HitFx.load_saved()
	CartoonHit.load_saved()
	KillFx.load_saved()
	ParryFx.load_saved()
	WipeFx.load_saved()
	audio = VDAudio.new()
	add_child(audio)
	_build_world()
	_show_picker()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# ---------------------------------------------------------------- world

func _build_world() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_mat := ShaderMaterial.new()
	bg_mat.shader = load("res://shaders/void_nebula.gdshader")
	bg.material = bg_mat
	bg_layer.add_child(bg)
	bg.resized.connect(func() -> void: bg_mat.set_shader_parameter("aspect", bg.size.x / maxf(bg.size.y, 1.0)))

	map = VDMap.new()
	map.rng.seed = 7
	room = map.create_root("plaza")   # 시드 7 이 고르던 모양 그대로 (모양이 늘어도 연구실 무대는 고정)
	board = VDBoard.new()
	board.placement_mode = false
	add_child(board)
	board.map = map
	board.current_room = room
	ground_fx = Node2D.new()
	add_child(ground_fx)
	units_root = Node2D.new()
	units_root.y_sort_enabled = true
	add_child(units_root)
	fx_root = Node2D.new()
	fx_root.z_index = 50
	add_child(fx_root)
	vfx = VDVfx.new()
	add_child(vfx)

	camera = VDCamera.new()
	camera.bg_material = bg_mat
	add_child(camera)
	camera.make_current()
	camera.base_zoom = Vector2(ZOOM, ZOOM)
	goo = VDGoo.new(self)
	shockwave = VDShockwave.new()
	add_child(shockwave)
	parry_impact = VDParryImpact.new()
	add_child(parry_impact)


## 적 구역(E) 셀들의 무게중심 (월드 셀 좌표)
func _e_center() -> Vector2:
	var cells := _e_cells()
	var sum := Vector2.ZERO
	for c in cells:
		sum += Vector2(c)
	return sum / maxf(cells.size(), 1.0)


## 아군 칸들의 화면 위치 평균 (카툰 피격의 공격 방향 기준)
func _ally_side() -> Vector2:
	var sum := Vector2.ZERO
	var cells := VDMap.local_cells(room, "A")
	for l in cells:
		sum += VDData.to_screen(Vector2(VDMap.to_world(room, l.x, l.y)))
	return sum / float(cells.size()) if not cells.is_empty() else Vector2(-2000.0, 0.0)


func _e_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for l in VDMap.local_cells(room, "E"):
		out.append(VDMap.to_world(room, l.x, l.y))
	return out


# ---------------------------------------------------------------- play

func _clear_stage() -> void:
	_run += 1
	_edit_timer = -1.0
	for e in _enemies:
		e.queue_free()
	_enemies.clear()
	for n in ground_fx.get_children() + fx_root.get_children():
		n.queue_free()
	goo.puddles.clear()
	shockwave.clear()
	if is_instance_valid(_cutin):
		_cutin.abort()
	_cutin = null
	if is_instance_valid(_wipe):
		_wipe.queue_free()
	_wipe = null


func replay() -> void:
	match _mode:
		"summon":
			_replay_summon()
		"cutin":
			_replay_cutin()
		"flame":
			_replay_flame()
		"relic":
			_replay_relic()
		"hit", "cartoon_hit":
			_replay_hit()
		"kill":
			_replay_kill()
		"parry":
			_replay_parry()
		"wipe":
			_replay_wipe()


## 화면 전환: 필드 위에 전환을 띄워 덮기 → (장면 교체 자리) → 걷기 를 한 번 돌리고, 자동 반복이면 잠시 뒤 다시.
func _replay_wipe() -> void:
	_clear_stage()
	var run := _run
	_cutin_stage()
	var w := ScreenTransition.new()
	w.layer_override = WIPE_LAYER
	w.preset_override = _target
	w.use_time_scale = true
	add_child(w)
	_wipe = w
	w.start()
	await w.covered
	if run != _run or not is_instance_valid(w):
		return
	w.reveal(0)
	await w.finished
	if run != _run:
		return
	_wipe = null
	if _auto:
		await get_tree().create_timer(REPLAY_GAP).timeout
		if run == _run and _auto:
			replay()


func _replay_summon() -> void:
	_clear_stage()
	var run := _run
	var t: Array = TARGETS[_target]
	var center := _e_center()
	var cells := _e_cells()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_squared_to(center) < Vector2(b).distance_squared_to(center))
	var count: int = mini(t[2], cells.size())
	if count > 1:
		cells = cells.slice(0, count * 2)
		cells.shuffle()
	# 왼쪽 조절 패널에 가리지 않게 소환 지점을 패널 오른쪽 영역 가운데로 (유닛 키만큼 조금 아래로)
	var focus := Vector2(cells[0]) if count == 1 else center
	var z := ZOOM * (0.6 if t[1] == "gazer" else 0.8 if t[1] == "boss" or t[1] == "watcher" or t[1] == "gazer" or t[1] == "longneck" or t[1] == "wraith" or count > 1 else 1.0)
	camera.base_zoom = Vector2(z, z)
	camera.position = VDData.to_screen(focus) - Vector2(PANEL_W * 0.5, 90.0) / z
	for i in count:
		if run != _run:
			return
		_spawn(t[1], cells[i])
		if i < count - 1:
			await get_tree().create_timer(maxf(VDSummonFx.g("interval"), 0.01)).timeout
	if not _auto:
		return
	await get_tree().create_timer(VDUnit.appear_duration() + REPLAY_GAP).timeout
	if run == _run and _auto:
		replay()


## 컷인: 전장 앞에 적 몇을 세워 두고(배경용) 컷인을 띄운다. 컷인은 실제 시간으로 돌고 배속 슬라이더만큼 느려진다.
func _replay_cutin() -> void:
	var had_stage := not _enemies.is_empty()
	if is_instance_valid(_cutin):
		_cutin.abort()
	_run += 1
	_edit_timer = -1.0
	var run := _run
	if not had_stage:
		_cutin_stage()
	var id: String = VDUltCinematic.SUPER_CUTIN.keys()[_target]
	var h: Dictionary = VDData.HEROES[id]
	_cutin = VDUltCinematic.SuperCutin.new()
	_cutin.speed = _speed
	add_child(_cutin)
	_cutin.play(VDData.ULTS[id]["name"], h["name"], h["color"], audio, VDUltCinematic.SUPER_CUTIN[id], id)
	if not _auto:
		return
	await get_tree().create_timer(CutinFx.duration() / _speed + REPLAY_GAP, true, false, true).timeout
	if run == _run and _auto:
		replay()


## 불꽃: 실제 분대 카드를 띄우고(처음 한 번) 고른 카드만 궁극기 준비 상태로 → 막 찬 것처럼 다시 확 타오르게.
## 값은 CardFlameFx 를 카드가 매 프레임 확인해 셰이더에 바로 넣는다 (재생 없이도 슬라이더가 곧장 보인다).
func _replay_flame() -> void:
	_run += 1
	_edit_timer = -1.0
	var run := _run
	_ensure_card_frame()
	for i in VDData.HERO_ORDER.size():
		var hid: String = VDData.HERO_ORDER[i]
		var on := _target == 0 or _target == i + 1
		_flame_frame.set_hero(hid, 0.8, 0.5, false, true, "", 1.0 if on else 0.4, on)
		if on:
			_flame_frame.reignite(hid)
	if not _auto:
		return
	await get_tree().create_timer(CardFlameFx.g("flare_sec") + 2.5).timeout
	if run == _run and _auto:
		replay()


## 실제 분대 카드 HUD (궁극기 카드 오버차지 · 패링 카드 강조 연구가 같이 쓴다). 목록으로 나가면 치운다.
func _ensure_card_frame():
	if _flame_frame == null:
		_flame_layer = CanvasLayer.new()
		_flame_layer.layer = 5
		add_child(_flame_layer)
		var root := Control.new()
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var theme := Theme.new()
		theme.default_font = VDData.font()
		root.theme = theme
		root.size = get_viewport().get_visible_rect().size
		# 카드가 아래 재생 바에 가리지 않게: 오른쪽 아래를 기준으로 키우고 위로 올린다
		root.pivot_offset = root.size
		root.scale = Vector2(1.35, 1.35)
		root.position.y = -150.0
		_flame_layer.add_child(root)
		_flame_frame = BattleFrame.new()
		root.add_child(_flame_frame)
		_flame_frame.setup(VDData.HERO_ORDER)
		_flame_frame.set_stage(1, 1)
	return _flame_frame


## 패링: 공허 감시자와 기사를 마주 세우고 예고(팟—칭 + 카드 강조) → 받아침 또는 일격. 전투와 같은 조각(VDParry.fx_*)을 쓴다.
## 기다림은 게임 시간이라 배속 슬라이더로 박자를 천천히 볼 수 있다.
var _parry_flip := false


func _replay_parry() -> void:
	_clear_stage()
	var run := _run
	var d: Dictionary = VDData.PARRY["watcher"]
	var window := float(d["window"])
	var center := _e_center()
	var cells := _e_cells()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_squared_to(center) < Vector2(b).distance_squared_to(center))
	var u := VDUnit.new()
	u.setup(VDData.ENEMIES["watcher"], "watcher", 1, cells[0])
	for c in cells:
		if _cell_free(c, u):
			u.cell = c
			break
	units_root.add_child(u)
	u.snap_to_cell()
	_enemies.append(u)
	# 영웅: 아군 구역에서 보스와 가장 가까운 칸
	var best := Vector2i.ZERO
	var best_d := INF
	for l in VDMap.local_cells(room, "A"):
		var w: Vector2i = VDMap.to_world(room, l.x, l.y)
		var dist := Vector2(w).distance_squared_to(Vector2(u.cell))
		if dist < best_d:
			best_d = dist
			best = w
	var h := VDUnit.new()
	h.setup(VDData.HEROES["knight"], "knight", 0, best)
	units_root.add_child(h)
	h.snap_to_cell()
	_enemies.append(h)
	h.face(u.position.x - h.position.x)
	u.face(h.position.x - u.position.x)
	var z := ZOOM * 0.72
	camera.base_zoom = Vector2(z, z)
	camera.position = (u.position + h.position) * 0.5 + Vector2(0, 40.0) - Vector2(PANEL_W * 0.5, 90.0) / z
	var frame = _ensure_card_frame()
	# 카드는 전투와 같은 크기로 아래에 (불꽃 연구처럼 키우면 보스를 가린다). 재생 바 위로만 살짝 올린다
	var card_root: Control = frame.get_parent()
	card_root.scale = Vector2.ONE
	card_root.position.y = -80.0
	for hid in VDData.HERO_ORDER:
		frame.set_hero(hid, 0.8, 0.5, false, true, "", 0.4, false)
		frame.parry_mark(hid, false)
	await get_tree().create_timer(0.6).timeout
	if run != _run:
		return
	var ok := _target == 1 or (_target == 0 and _parry_flip)
	_parry_flip = not _parry_flip
	u.windup(h.position, window)
	u._cast_glow = 1.0
	var tele := VDParry.fx_telegraph(self, u)
	var mark := VDParry.fx_mark(self, h)
	frame.parry_mark("knight", true)
	var hold := window * (0.62 if ok else 1.0)
	tele.create_tween().tween_property(tele, "urgency", hold / window, hold)
	await get_tree().create_timer(hold).timeout
	if run != _run:
		return   # 무대를 새로 지었다: 별·표식은 _clear_stage 가 치웠고 카드 강조는 새 재생이 끈다
	mark.queue_free()
	tele.close(true)
	u.release_windup()
	if ok:
		frame.parry_mark("knight", false, true)
		var clash := VDParry.fx_clash(self, u, h)
		h.attack_anim(u.position)
		h.cast_pulse()
		await get_tree().create_timer(VDParry.COUNTER_DELAY).timeout
		if run != _run:
			return
		VDParry.fx_counter(self, clash, u)
		u.hit_punch(1.0)
		u.hit_flash("")
	else:
		frame.parry_mark("knight", false)
		u.attack_anim(h.position)
		VDParry.fx_strike(self, u, h)
		h.hit_punch(1.0)
		h.hit_flash("")
	if not _auto:
		return
	await get_tree().create_timer(1.8).timeout
	if run == _run and _auto:
		replay()


## 유물 투사체: 적 몇(+ 별 깃털용 아군 하나)을 세워 두고, 화면 오른쪽 위(성좌판 칸 자리)에서 고른 종류를 쏜다.
## 착탄 반응(움찔·흔들림·히트스탑)은 전투(VDRelicRuntime)와 비슷하게.
func _replay_relic() -> void:
	_run += 1
	_edit_timer = -1.0
	var run := _run
	if _enemies.is_empty():
		_cutin_stage()
	if _ally == null:
		var a_cells := VDMap.local_cells(room, "A")
		if not a_cells.is_empty():
			var center := _e_center()
			var best: Vector2i = VDMap.to_world(room, a_cells[0].x, a_cells[0].y)
			for l in a_cells:
				var w := VDMap.to_world(room, l.x, l.y)
				if Vector2(w).distance_squared_to(center) < Vector2(best).distance_squared_to(center):
					best = w
			_ally = VDUnit.new()
			_ally.setup(VDData.HEROES["knight"], "knight", 0, best)
			units_root.add_child(_ally)
			_ally.snap_to_cell()
	var kind: String = RelicProjFx.KINDS[_target]
	_fire_relic(_ally if kind == "feather" and _ally != null else _enemies[randi() % _enemies.size()])
	if not _auto:
		return
	await get_tree().create_timer(RelicProjFx.timing(kind).y + REPLAY_GAP).timeout
	if run == _run and _auto:
		replay()


## 고른 종류의 투사체를 target 에게 한 발 (자동 재생 · 몬스터 클릭 둘 다)
func _fire_relic(target: VDUnit) -> void:
	var run := _run
	var kind: String = RelicProjFx.KINDS[_target]
	var col := VDRelicData.color_of(RELIC_OF[kind])
	# 출발점: 지금 카메라 기준 화면 오른쪽 위 → 월드
	var vp := get_viewport().get_visible_rect().size
	var screen := Vector2(vp.x, 0.0) + RELIC_ORIGIN
	var origin := camera.get_screen_center_position() + (screen - vp * 0.5) / camera.zoom   # 카메라를 막 옮긴 첫 프레임에도 맞게
	_mark_origin(origin)
	var chest := target.position + Vector2(0, target._top * 0.55)
	var track := func() -> Vector2: return target.position + Vector2(0, target._top * 0.55)
	var fx: VDRelicFx
	match kind:
		"bolt":
			fx = VDRelicFx.bolt(fx_root, origin, chest, col, track)
			audio.play("mage_cast", 0.05, 4.0)
		"comet":
			fx = VDRelicFx.comet(fx_root, origin, chest, col, track)
			audio.play("gun", 0.08, -6.0)
		"frost":
			fx = VDRelicFx.frost(fx_root, origin, chest, col, track)
		"feather":
			fx = VDRelicFx.feather(fx_root, origin, chest, col, track)
		"essence":
			fx = VDRelicFx.essence(fx_root, chest, origin, col)   # 쓰러진 적 → 슬롯
	fx.impact.connect(func() -> void:
		if run == _run and is_instance_valid(target):
			_relic_hit(kind, target, col))


## 유물 투사체 착탄 반응 (VDRelicRuntime 과 비슷하게, 피해 없이)
func _relic_hit(kind: String, target: VDUnit, col: Color) -> void:
	var chest := target.position + Vector2(0, target._top * 0.55)
	if target.team == 1:
		# 전투의 relic_damage 처럼 유물 태그 = 피격 색
		target.hit_flash({"bolt": "번개", "comet": "화염", "frost": "서리"}.get(kind, ""))
	match kind:
		"bolt":
			vfx.spawn("lightning", fx_root, target.position + Vector2(0, target._top * 0.6), 0.45, 0.0, col)
			target.hit_punch(0.9)
			audio.play("mage_hit", 0.05, 2.0)
			camera.shake(0.45)
			camera.hitstop(0.03)
		"comet":
			vfx.spawn("burst", fx_root, chest, 0.35, randf() * TAU, col)
			target.hit_punch(0.6)
			audio.play("knight_hit", 0.08, -8.0)
		"frost":
			target.hit_punch(0.5)
			audio.play("mage_hit", 0.05, -6.0)
		"feather":
			vfx.spawn("heal", fx_root, chest, 0.6, 0.0, col)
			audio.play("heal", 0.05, -2.0)
		"essence":
			audio.play("essence", 0.05)


## 몬스터 피격: 적 넷을 세워 두고 차례로 한 대씩 (대상: 번갈아 / 보통만 / 강타만). 전투와 같은 vfx.spawn("burst") 를 부른다
func _replay_hit() -> void:
	_run += 1
	_edit_timer = -1.0
	var run := _run
	if _enemies.is_empty():
		_cutin_stage()
	var order := _enemies.duplicate()
	for i in order.size():
		if run != _run:
			return
		var u: VDUnit = order[i]
		if is_instance_valid(u):
			_hit_unit(u, _target == 2 or ((_target == 0 or _target >= 3) and i % 2 == 1))
		await get_tree().create_timer(0.22).timeout
	if not _auto:
		return
	await get_tree().create_timer(1.0 + REPLAY_GAP).timeout
	if run == _run and _auto:
		replay()


var _tap_heavy := false


## 클릭한 몬스터를 한 대 (번갈아 모드면 보통·강타를 번갈아)
func _tap_unit(u: VDUnit) -> void:
	if _mode == "relic":
		_fire_relic(u)
		return
	if _mode == "kill":
		_kill_unit(u)
		return
	_tap_heavy = not _tap_heavy
	_hit_unit(u, _target == 2 or ((_target == 0 or _target >= 3) and _tap_heavy))


## 피격 반응 (피해 없이): 보통 0.35 · 강타 0.6 배율 — 전투의 일반 공격·처치급 타격과 같은 배율.
## 몸 반응·번쩍임은 VDUnit 이 HitFx 값으로, 화면은 전투의 _hit_feel 과 같게 (보통 = 건너, 강타 = 기사)
## 파티클은 전투와 같게: 카툰 피격이 켜져 있으면(또는 카툰 연구 중이면) 아군 쪽 → 몬스터 방향으로 카툰 피격
func _hit_unit(u: VDUnit, heavy: bool) -> void:
	var chest := u.position + Vector2(0, u._top * 0.55)
	if _mode == "cartoon_hit" or CartoonHit.enabled():
		CartoonHit.spawn(fx_root, chest, u.position - _ally_side(), heavy)
	else:
		vfx.spawn("burst", fx_root, chest, 0.6 if heavy else 0.35, 0.0, Color(1.0, 0.35, 0.8))
	u.hit_punch(0.9 if heavy else 0.5)
	u.hit_flash(HIT_ELEMENT[_target])
	audio.play("knight_hit", 0.08, -6.0 if heavy else -10.0)
	camera.shake((0.45 if heavy else 0.32) * HitFx.g("shake_k"))
	if HitFx.g("hitstop_k") > 0.0:
		camera.hitstop((0.05 if heavy else 0.03) * HitFx.g("hitstop_k"))


## 몬스터 사망: 적(보통 넷 또는 보스)을 세워 두고 차례로 쓰러뜨린다 (sequence = false 면 세우기만: 클릭으로 처치).
## 다 쓰러지면 _kill_unit 이 다시 세운다 (자동 반복이면 또 차례로 쓰러뜨림)
func _replay_kill(sequence := true) -> void:
	_clear_stage()
	var run := _run
	_kill_stage()
	if not sequence:
		return
	await get_tree().create_timer(0.5).timeout
	for u in _enemies.duplicate():
		if run != _run:
			return
		if is_instance_valid(u) and u.alive:
			_kill_unit(u)
		await get_tree().create_timer(0.7).timeout


func _kill_stage() -> void:
	if _target == 0:
		_cutin_stage()
		return
	var center := _e_center()
	var cells := _e_cells()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_squared_to(center) < Vector2(b).distance_squared_to(center))
	var u := VDUnit.new()
	u.setup(VDData.ENEMIES["boss"], "boss", 1, cells[0])
	for c in cells:           # 대형: 몸 전체가 방 안에 드는 가장 가운데 칸
		if _cell_free(c, u):
			u.cell = c
			break
	units_root.add_child(u)
	u.snap_to_cell()
	_enemies.append(u)
	var z := ZOOM * 0.8
	camera.base_zoom = Vector2(z, z)
	camera.position = VDData.to_screen(center) - Vector2(PANEL_W * 0.5, 90.0) / z


## 마지막 일격 → 실제 전투와 같은 사망 연출 (VDUnit._die 의 몸 + KillFx.play). 모두 쓰러지면 잠시 뒤 다시 세운다
func _kill_unit(u: VDUnit) -> void:
	if not u.alive:
		return
	var at := u.position + Vector2(0, u._top * 0.55)
	vfx.spawn("burst", fx_root, at, 0.6, 0.0, Color(1.0, 0.35, 0.8))   # 처치급 타격 (전투의 마지막 한 대)
	u.take_damage(u.hp + 99999.0)
	audio.play("boss_die" if u.is_boss else "enemy_die", 0.05)
	KillFx.play(u, at, vfx, fx_root, ground_fx, camera, goo, shockwave)
	for e in _enemies:
		if is_instance_valid(e) and e.alive:
			return
	var run := _run
	await get_tree().create_timer(1.6).timeout
	if run == _run and _mode == "kill":
		_replay_kill(_auto)


## 출발점 표시: 성좌판 칸처럼 작은 육각 테두리
func _mark_origin(at: Vector2) -> void:
	if _origin_mark == null:
		_origin_mark = Node2D.new()
		_origin_mark.z_index = 54
		_origin_mark.draw.connect(func() -> void:
			var pts := VDRelicData.hex_points(Vector2.ZERO, 26.0)
			pts.append(pts[0])
			_origin_mark.draw_colored_polygon(VDRelicData.hex_points(Vector2.ZERO, 26.0), Color(0.08, 0.04, 0.16, 0.7))
			_origin_mark.draw_polyline(pts, Color(0.75, 0.6, 1.0, 0.9), 2.5))
		add_child(_origin_mark)
	_origin_mark.position = at
	_origin_mark.scale = Vector2.ONE / camera.zoom.x
	_origin_mark.visible = true


func _cutin_stage() -> void:
	var cells := _e_cells()
	cells.shuffle()
	for i in mini(4, cells.size()):
		var id: String = ["normal", "fast", "tank", "skirmisher"][i]
		var u := VDUnit.new()
		u.setup(VDData.ENEMIES[id], id, 1, cells[i])
		units_root.add_child(u)
		u.snap_to_cell()
		_enemies.append(u)
	var z := ZOOM * 0.8
	camera.base_zoom = Vector2(z, z)
	camera.position = VDData.to_screen(_e_center()) - Vector2(PANEL_W * 0.5, 90.0) / z


func _spawn(id: String, cell: Vector2i) -> void:
	var u := VDUnit.new()
	u.setup(VDData.ENEMIES[id], id, 1, cell)
	units_root.add_child(u)
	u.snap_to_cell()
	_enemies.append(u)
	var foot := u.position
	var heavy := u.is_boss or u.size > 1
	u.appear(VDSummonFx.play_impact.bind(vfx, ground_fx, fx_root, camera, foot, heavy))
	audio.play("boss_spawn" if heavy else "enemy_spawn", 0.12)
	VDSummonFx.play_portal(vfx, ground_fx, foot, heavy)


func _process(delta: float) -> void:
	if _edit_timer >= 0.0:
		# 슬라이더를 끄는 동안은 기다렸다가 손을 떼면(값 변화가 멈추면) 다시 재생 — 실시간 기준
		_edit_timer -= delta / maxf(Engine.time_scale, 0.0001)
		if _edit_timer < 0.0:
			replay()


## 끄는 중의 이동·놓기는 GUI 보다 먼저 받는다 (패널 위에서 놓아도 끌기가 끝나게)
func _input(event: InputEvent) -> void:
	if not _drag.is_empty() and event is InputEventMouse and _drag_input(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if (_mode == "relic" or _mode == "hit" or _mode == "cartoon_hit" or _mode == "kill") and _drag_input(event):
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _mode == "":
		var i: int = event.keycode - KEY_1
		if i >= 0 and i < MODES.size():
			_open(MODES[i]["id"])
		return
	match event.keycode:
		KEY_SPACE:
			replay()
		KEY_R:
			_chk_auto.button_pressed = not _chk_auto.button_pressed
		KEY_H:
			_panel.visible = not _panel.visible
		KEY_TAB:
			_show_picker()


## 유물 투사체 연구: 필드의 몬스터(와 별 깃털용 아군)를 끌어 옮기고, 끌지 않고 클릭하면 그 대상에게 바로 한 발.
## 놓은 칸이 방 밖이거나 다른 유닛이 있으면 원래 칸으로 튕겨 돌아간다. 처리했으면 true.
func _drag_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var u := _unit_at_screen(event.position)
			if u == null:
				return false
			_drag = {"unit": u, "from": event.position, "moved": false}
			return true
		if _drag.is_empty():
			return false
		var u: VDUnit = _drag["unit"]
		var moved: bool = _drag["moved"]
		_drag = {}
		if not is_instance_valid(u):
			return true
		if moved:
			_drop_unit(u, _board_pos(event.position))
		else:
			_tap_unit(u)
		return true
	if event is InputEventMouseMotion and not _drag.is_empty():
		var u: VDUnit = _drag["unit"]
		if not is_instance_valid(u):
			_drag = {}
			return true
		if not _drag["moved"] and event.position.distance_to(_drag["from"]) > 8.0:
			_drag["moved"] = true
			u.z_index = 100
			u.create_tween().tween_property(u, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			audio.play("tick", 0.05, -6.0, 1.4)
		if _drag["moved"]:
			var m := _board_pos(event.position)
			u.position = m + Vector2(0, -20)
			var c := VDData.to_cell(m)
			board.set_hover(c, _cell_free(c, u))
		return true
	return false


## 화면(이벤트) 좌표 → 보드 좌표. OS 마우스 위치 대신 이벤트 좌표를 써서 주입한 입력에도 맞다
func _board_pos(screen: Vector2) -> Vector2:
	return board.get_global_transform_with_canvas().affine_inverse() * screen


func _unit_at_screen(screen: Vector2) -> VDUnit:
	var m := _board_pos(screen)
	var c := VDData.to_cell(m)
	var units: Array[VDUnit] = _enemies.duplicate()
	if _ally != null:
		units.append(_ally)
	for u in units:
		if is_instance_valid(u) and u.alive and u.occupies(c):
			return u
	# 칸이 아니라 몸통을 눌러도 집히게 (키 큰 유닛)
	var best: VDUnit = null
	var best_d := 70.0
	for u in units:
		if not is_instance_valid(u) or not u.alive:
			continue
		var d := m.distance_to(u.position + Vector2(0, u._top * 0.5))
		if d < best_d:
			best_d = d
			best = u
	return best


## u 의 footprint 를 at 에 놓을 수 있는가 (방 안 + 다른 유닛과 겹치지 않음)
func _cell_free(at: Vector2i, u: VDUnit) -> bool:
	var others: Array[VDUnit] = _enemies.duplicate()
	if _ally != null:
		others.append(_ally)
	for c in u.footprint(at):
		if not VDMap.in_room(room, c):
			return false
		for o in others:
			if o != u and is_instance_valid(o) and o.occupies(c):
				return false
	return true


func _drop_unit(u: VDUnit, at: Vector2) -> void:
	var c := VDData.to_cell(at)
	board.set_hover(Vector2i(-1, -1), false, false)
	var tw := u.create_tween()
	if _cell_free(c, u):
		u.cell = c
		audio.play("place")
		vfx.spawn("dust", ground_fx, u.foot_at(c), 0.9)
		tw.tween_property(u, "position", u.foot_at(c), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(u, "scale", Vector2(1.2, 0.82), 0.05)
		tw.tween_property(u, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		audio.play("tick", 0.0, -4.0, 0.6)
		tw.tween_property(u, "position", u.foot_at(u.cell), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(u, "scale", Vector2.ONE, 0.3)
	tw.tween_callback(func() -> void:
		if is_instance_valid(u):
			u.z_index = 0
			u.snap_to_cell())


# ---------------------------------------------------------------- 연출 목록

func _show_picker() -> void:
	_clear_stage()
	if _flame_layer:
		_flame_layer.queue_free()
		_flame_layer = null
		_flame_frame = null
	if _ally:
		_ally.queue_free()
		_ally = null
	if _origin_mark:
		_origin_mark.visible = false
	_mode = ""
	_fx = null
	if _ui:
		_ui.queue_free()
		_ui = null
	camera.set_game_speed(1.0)
	_speed = 1.0
	camera.base_zoom = Vector2(ZOOM, ZOOM)
	camera.position = VDData.to_screen(_e_center())
	_picker = CanvasLayer.new()
	_picker.layer = 10
	add_child(_picker)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font = VDData.font()
	theme.default_font_size = 18
	root.theme = theme
	_picker.add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.01, 0.07, 0.55)
	root.add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(Color(0.08, 0.05, 0.14, 0.94), 14))
	SceneSwitcher.pin(panel, Vector2(0.5, 0.5), Rect2(960 - 450, 40, 900, 0))   # 연출 8개가 화면 안에 들게 위쪽부터
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	_label(vb, "연출 연구실", 34, Color(0.95, 0.9, 1.0))
	_label(vb, "다듬을 연출을 고르세요", 17, Color(0.75, 0.7, 0.9))
	for i in MODES.size():
		var m: Dictionary = MODES[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 84)
		b.add_theme_stylebox_override("normal", _flat(Color(0.14, 0.09, 0.24, 0.95), 10))
		b.add_theme_stylebox_override("hover", _flat(Color(0.24, 0.15, 0.4, 0.98), 10))
		b.add_theme_stylebox_override("pressed", _flat(Color(0.32, 0.2, 0.52, 1.0), 10))
		b.pressed.connect(_open.bind(m["id"]))
		vb.add_child(b)
		var inner := VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 18
		inner.offset_right = -18
		inner.offset_top = 12
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(inner)
		var t := _label(inner, "%d   %s" % [i + 1, m["title"]], 24, Color(1.0, 0.92, 0.6))
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var d := _label(inner, m["desc"], 15, Color(0.82, 0.78, 0.92))
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := _button(vb, "로비로", func() -> void: SceneSwitcher.go_lobby())
	back.custom_minimum_size.y = 44


func _open(id: String) -> void:
	if id == "battle":
		# 전투 연습장은 실제 전투 씬(VDBattle)을 연습 모드로 연다 (스킬·궁극기·AI 가 전투에 묶여 있어 그대로 쓴다)
		VDBattle.sandbox_request = ["knight"]
		SceneSwitcher.switch_to(VDSandbox.scene_index("VoidDefense_greybox"))
		return
	if _picker:
		_picker.queue_free()
		_picker = null
	_mode = id
	_fx = ParryFx if id == "parry" else CutinFx if id == "cutin" else (CardFlameFx if id == "flame" else (RelicProjFx if id == "relic" else (HitFx if id == "hit" else (CartoonHit if id == "cartoon_hit" else (KillFx if id == "kill" else (WipeFx if id == "wipe" else VDSummonFx))))))
	_target = ScreenTransition.get_preset() if id == "wipe" else 0
	_dirty = false
	_rows.clear()
	if id == "cutin":
		VDUltCinematic.SuperCutin.prewarm()
	_build_ui()
	_refresh_status()
	replay()


func _mode_title() -> String:
	for m in MODES:
		if m["id"] == _mode:
			return m["title"]
	return ""


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40                 # 컷인(30) 위: 재생 중에도 패널 값이 보인다. 전체 화면으로 보려면 H
	add_child(layer)
	_ui = layer
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = VDData.font()
	theme.default_font_size = 17
	root.theme = theme
	layer.add_child(root)

	# 왼쪽 조절 패널 (위아래 꽉 차게)
	var panel := PanelContainer.new()
	panel.anchor_bottom = 1.0
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = PANEL_W
	panel.offset_bottom = 0
	panel.add_theme_stylebox_override("panel", _flat(Color(0.08, 0.05, 0.14, 0.9), 0))
	root.add_child(panel)
	_panel = panel
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var back := _button(vb, "◀ 연출 목록  (Tab)", _show_picker)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_lbl_title = _label(vb, "", 28, Color(0.95, 0.9, 1.0))
	var help_text := "값을 바꾸고 손을 떼면 바로 다시 재생 · [Space] 재생 · [R] 자동 반복 · [H] 패널 숨기기"
	if _mode == "relic":
		help_text += "\n필드의 몬스터를 끌어 옮기기 · 클릭하면 그 몬스터에게 바로 발사"
	elif _mode == "hit" or _mode == "cartoon_hit":
		help_text += "\n필드의 몬스터를 끌어 옮기기 · 클릭하면 그 몬스터를 바로 때림"
	elif _mode == "parry":
		help_text += "\n배속을 낮추면 팟—칭 박자가 천천히 보인다 · 판정 수치(입력 창·피해)는 VDData.PARRY"
	elif _mode == "kill":
		help_text += "\n필드의 몬스터를 끌어 옮기기 · 클릭하면 그 몬스터를 바로 처치 (다 쓰러지면 다시 세움)"
	elif _mode == "wipe":
		help_text += "\n색은 재생 중에도 바로 바뀐다 · 실제 게임의 프리셋은 설정 메뉴 [화면 전환] 에서 고른다"
	var help := _label(vb, help_text, 14, Color(0.75, 0.7, 0.9))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_total = _label(vb, "", 15, Color(1.0, 0.85, 0.45))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	var group := ""
	var params: Array = _fx.PARAMS
	var i := 0
	while i < params.size():
		var p: Array = params[i]
		if (_mode == "relic" and not RelicProjFx.visible_for(p[0], RelicProjFx.KINDS[_target])) or (_mode == "wipe" and not WipeFx.visible_for(p[0], _target)):
			i += 1
			continue
		if p[1] != group:
			group = p[1]
			var gl := _label(list, "— " + group, 18, Color(0.85, 0.65, 1.0))
			gl.custom_minimum_size.y = 34
			gl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		# 색: "키_r/_g/_b" 세 줄을 컬러 피커 한 줄로
		var base := FxColors.base_at(params, i)
		if base != "":
			_add_color_row(list, base, p, params[i + 1], params[i + 2])
			i += 3
			continue
		_add_row(list, p)
		i += 1

	# 아래 버튼들
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)
	_button(grid, "저장", _on_save)
	_button(grid, "저장값으로 되돌리기", _on_revert)
	_button(grid, "기본값으로", _on_defaults)
	_button(grid, "바뀐 값 복사", _on_copy)
	_button(grid, "전체 값 복사", _on_copy.bind(true))
	_button(grid, "로비로", func() -> void: SceneSwitcher.go_lobby())
	_lbl_status = _label(vb, "", 14, Color(0.7, 0.9, 0.75))
	_lbl_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# 오른쪽 아래 재생 바
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _flat(Color(0.1, 0.06, 0.18, 0.88), 10))
	SceneSwitcher.pin(bar, Vector2(1, 1), Rect2(PANEL_W + 40, 990, 1920 - PANEL_W - 80, 64))
	root.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(hb)
	var play := _button(hb, "▶ 재생", replay)
	play.custom_minimum_size = Vector2(160, 44)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.add_theme_font_size_override("font_size", 20)
	_chk_auto = CheckBox.new()
	_chk_auto.text = "자동 반복"
	_chk_auto.button_pressed = _auto
	_chk_auto.focus_mode = Control.FOCUS_NONE
	_chk_auto.toggled.connect(func(on: bool) -> void:
		_auto = on
		if on:
			replay())
	hb.add_child(_chk_auto)
	_label(hb, "대상", 17, Color(0.85, 0.8, 0.95))
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	if _mode == "cutin":
		for id in VDUltCinematic.SUPER_CUTIN:
			opt.add_item(VDData.HEROES[id]["name"])
	elif _mode == "flame":
		for t in FLAME_TARGETS:
			opt.add_item(t)
	elif _mode == "relic":
		for t in RelicProjFx.KIND_NAMES:
			opt.add_item(t)
	elif _mode == "hit" or _mode == "cartoon_hit":
		for t in HIT_TARGETS:
			opt.add_item(t)
	elif _mode == "kill":
		for t in KILL_TARGETS:
			opt.add_item(t)
	elif _mode == "parry":
		for t in PARRY_TARGETS:
			opt.add_item(t)
	elif _mode == "wipe":
		for t in ScreenTransition.PRESET_NAMES:
			opt.add_item(t)
	else:
		for t in TARGETS:
			opt.add_item(t[0])
	opt.select(_target)
	opt.item_selected.connect(func(i: int) -> void:
		_target = i
		if _mode == "relic" or _mode == "wipe":
			# 종류(프리셋)마다 조절값 줄이 달라 패널을 새로 짓는다
			_ui.queue_free()
			_rows.clear()
			_build_ui()
			_refresh_status()
		replay())
	hb.add_child(opt)
	_label(hb, "배속", 17, Color(0.85, 0.8, 0.95))
	var sp := HSlider.new()
	sp.min_value = 0.05
	sp.max_value = 1.0
	sp.step = 0.05
	sp.value = _speed   # 유물 모드처럼 UI 를 다시 지어도 지금 배속을 유지한다
	sp.custom_minimum_size = Vector2(180, 0)
	sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sp.focus_mode = Control.FOCUS_NONE
	hb.add_child(sp)
	_lbl_speed = _label(hb, "x%.2f" % _speed, 17, Color(1, 1, 1))
	_lbl_speed.custom_minimum_size.x = 56
	sp.value_changed.connect(func(v: float) -> void:
		_speed = v
		camera.set_game_speed(v)
		_lbl_speed.text = "x%.2f" % v)


func _add_row(parent: Control, p: Array) -> void:
	var key: String = p[0]
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	parent.add_child(hb)
	var title := _label(hb, p[2], 15, Color(0.92, 0.9, 1.0))
	title.custom_minimum_size.x = 190
	title.tooltip_text = key
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	if p[5] == 0.0:
		var opt := OptionButton.new()
		opt.focus_mode = Control.FOCUS_NONE
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for n in _fx.TRANS_NAMES:
			opt.add_item(n)
		opt.select(int(_fx.g(key)))
		opt.clip_text = true               # 긴 프리셋 이름이 줄을 밀어내지 않게
		opt.custom_minimum_size.x = 120
		hb.add_child(opt)
		_rows[key] = {"opt": opt}
		var curve: Control = null
		if _mode == "relic":
			curve = _ease_preview(hb, key)
			_rows[key]["curve"] = curve
		opt.item_selected.connect(func(i: int) -> void:
			_on_value(key, float(i))
			if curve:
				curve.queue_redraw())
		return
	var slider := HSlider.new()
	slider.min_value = p[3]
	slider.max_value = p[4]
	slider.step = p[5]
	slider.value = _fx.g(key)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	hb.add_child(slider)
	var spin := SpinBox.new()
	spin.min_value = p[3]
	spin.max_value = p[4]
	spin.step = p[5]
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.value = _fx.g(key)
	spin.custom_minimum_size.x = 104
	hb.add_child(spin)
	# 기본값 표시용 리셋 버튼
	var rst := Button.new()
	rst.text = "↺"
	rst.tooltip_text = "기본값 %s" % str(p[6])
	rst.focus_mode = Control.FOCUS_NONE
	hb.add_child(rst)
	slider.value_changed.connect(func(v: float) -> void:
		spin.set_value_no_signal(v)
		_on_value(key, v))
	spin.value_changed.connect(func(v: float) -> void:
		slider.set_value_no_signal(v)
		_on_value(key, v))
	rst.pressed.connect(func() -> void: spin.value = p[6])
	_rows[key] = {"slider": slider, "spin": spin}


## 비행 이징 곡선 미리보기: 가로 = 비행 시간, 세로 = 출발 → 착탄. 점선 = 0·1 (Back·Elastic 은 넘었다 돌아온다)
func _ease_preview(parent: Control, key: String) -> Control:
	var kind := key.get_slice(".", 0)
	var c := Control.new()
	c.custom_minimum_size = Vector2(64, 30)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var w := c.size.x
		var h := c.size.y
		var y0 := h * 0.8                 # 출발 (0)
		var y1 := h * 0.2                 # 착탄 (1)
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.05, 0.03, 0.1, 0.8))
		c.draw_dashed_line(Vector2(0, y0), Vector2(w, y0), Color(1, 1, 1, 0.2), 1.0, 3.0)
		c.draw_dashed_line(Vector2(0, y1), Vector2(w, y1), Color(1, 1, 1, 0.2), 1.0, 3.0)
		var i := int(_fx.g(key))
		var pts := PackedVector2Array()
		for s in 33:
			var x := s / 32.0
			pts.append(Vector2(x * w, lerpf(y0, y1, RelicProjFx.fly(kind, i, x))))
		c.draw_polyline(pts, Color(1.0, 0.85, 0.4), 2.0, true))
	parent.add_child(c)
	return c


## 색 한 줄: 컬러 피커(누르면 팔레트) + 16진 표시 + 기본값 버튼. 값은 키_r/_g/_b 세 float 로 저장된다.
## 채널 최대가 1 보다 크면(HDR 색) 피커도 1 을 넘길 수 있게 둔다.
func _add_color_row(parent: Control, base: String, pr: Array, pg: Array, pb: Array) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	parent.add_child(hb)
	var name: String = pr[2]
	var title := _label(hb, name.trim_suffix(" R"), 15, Color(0.92, 0.9, 1.0))
	title.custom_minimum_size.x = 190
	title.tooltip_text = base + "_r/_g/_b"
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	var pick := ColorPickerButton.new()
	pick.edit_alpha = false
	pick.focus_mode = Control.FOCUS_NONE
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.custom_minimum_size.y = 26
	pick.color = _color_of(base)
	hb.add_child(pick)
	var hdr := float(pr[4]) > 1.0
	pick.get_picker().color_mode = ColorPicker.MODE_RGB
	if hdr:
		pick.get_picker().color_mode = ColorPicker.MODE_LINEAR   # 1 넘는 HDR 값 그대로
	var hex := _label(hb, "", 14, Color(0.8, 0.78, 0.9))
	hex.custom_minimum_size.x = 104
	var def := Color(pr[6], pg[6], pb[6])
	var rst := Button.new()
	rst.text = "↺"
	rst.tooltip_text = "기본값 #%s" % def.to_html(false)
	rst.focus_mode = Control.FOCUS_NONE
	hb.add_child(rst)
	var show := func(c: Color) -> void:
		hex.text = ("#" + c.to_html(false)) if c.r <= 1.0 and c.g <= 1.0 and c.b <= 1.0 else "%.2f %.2f %.2f" % [c.r, c.g, c.b]
	show.call(pick.color)
	var put := func(c: Color) -> void:
		show.call(c)
		_fx.set_value(base + "_r", c.r)
		_fx.set_value(base + "_g", c.g)
		_on_value(base + "_b", c.b)        # 마지막 채널로 더러움·다시 재생 처리
	pick.color_changed.connect(put)
	rst.pressed.connect(func() -> void:
		pick.color = def
		put.call(def))
	_rows[base] = {"color": pick, "show": show}


func _color_of(base: String) -> Color:
	return Color(_fx.g(base + "_r"), _fx.g(base + "_g"), _fx.g(base + "_b"))


func _on_value(key: String, v: float) -> void:
	_fx.set_value(key, v)
	_dirty = true
	_edit_timer = EDIT_DELAY if _mode != "flame" else -1.0   # 불꽃은 카드가 값을 바로 받으므로 다시 재생하지 않는다
	_refresh_status()


func _sync_rows() -> void:
	for key in _rows:
		var r: Dictionary = _rows[key]
		var v: float = _fx.g(key)
		if r.has("color"):
			var c := _color_of(key)
			(r["color"] as ColorPickerButton).color = c
			(r["show"] as Callable).call(c)
		elif r.has("opt"):
			(r["opt"] as OptionButton).select(int(v))
			if r.get("curve"):
				(r["curve"] as Control).queue_redraw()
		else:
			(r["slider"] as HSlider).set_value_no_signal(v)
			(r["spin"] as SpinBox).set_value_no_signal(v)


func _on_save() -> void:
	if _fx.save():
		_dirty = false
		_refresh_status("저장했습니다 → " + ProjectSettings.globalize_path(_fx.SAVE_PATH))
	else:
		_refresh_status("저장 실패")


func _on_revert() -> void:
	_fx.load_saved()
	_sync_rows()
	_dirty = false
	_refresh_status("저장된 값으로 되돌렸습니다")
	replay()


func _on_defaults() -> void:
	_fx.reset()
	_sync_rows()
	_dirty = true
	_refresh_status("코드 기본값으로 바꿨습니다 (저장하면 반영)")
	replay()


func _on_copy(all := false) -> void:
	var text: String = _fx.describe(all)
	DisplayServer.clipboard_set(text)
	_refresh_status("클립보드에 복사했습니다:\n" + text)


func _refresh_status(msg := "") -> void:
	_lbl_title.text = "연출 연구실 · " + _mode_title() + ("  *" if _dirty else "")
	_lbl_total.text = _fx.summary(RelicProjFx.KINDS[_target]) if _mode == "relic" else (_fx.summary(_target) if _mode == "wipe" else _fx.summary())
	if msg != "":
		_lbl_status.text = msg
	elif _dirty:
		_lbl_status.text = "저장 안 됨 — 바뀐 값은 이번 실행 동안 전투에도 적용됩니다. 다음 실행에도 쓰려면 저장하세요."
	else:
		_lbl_status.text = "저장된 값 사용 중"


func _label(parent: Node, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _flat(col: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb
