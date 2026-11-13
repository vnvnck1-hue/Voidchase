## VFX 쇼룸 한 칸: 자기만의 SubViewport 안에 전투와 같은 월드(성운 배경·바닥·유닛·이펙트 층·카메라·쇼크웨이브)를 두고
## VFX 하나(entry)를 반복 재생한다. SubViewport 는 논리 크기 1920x1080 (size_2d_override) 이라 화면 전체 효과(컷인·글리치·와이프)도
## 전투에서처럼 그려지고, 실제 픽셀은 칸 크기만큼만 든다. 화면 밖으로 스크롤된 칸은 그리기·처리를 멈춘다(set_active).
## entry: {"id", "title", "cat", "used", "play": Callable(tile) -> float (한 번 재생 길이, 초)}
extends SubViewportContainer

const DESIGN := Vector2(1920, 1080)
const GAP := 0.6                 # 한 번 재생이 끝나고 다음 재생까지(초)
const ZOOM_K := 1.45           # 전투보다 더 당겨 본다 (칸이 작아서)

## 히트스탑·슬로모션은 Engine.time_scale(전역)을 바꾼다: 칸이 여럿 도는 쇼룸에서는 크게 보기 칸만 허락한다.
class TileCamera extends VDCamera:
	var allow_time := false

	func hitstop(sec: float) -> void:
		if allow_time:
			super.hitstop(sec)

	func slowmo(sec: float, scale: float) -> void:
		if allow_time:
			super.slowmo(sec, scale)

var entry: Dictionary
var vp: SubViewport
var world: Node2D
var map: VDMap
var room := {}
var board: VDBoard
var ground_fx: Node2D
var units_root: Node2D
var fx_root: Node2D
var vfx: VDVfx
var dmg_log: VDDamageLog
var camera: TileCamera
var audio: VDAudio
var goo: VDGoo
var shockwave
var bg_mat: ShaderMaterial
## 재생마다 새로 붙는 화면 레이어(컷인·와이프·글리치 등)를 담는 곳. clear() 가 비운다
var scratch: Node
var units: Array[VDUnit] = []
var run := 0                     # clear() 마다 오른다: 이전 재생의 await 가 돌아와도 멈추게
var active := true
var big := false                 # 크게 보기 칸 (소리·히트스탑 허락)
## VDJuice 가 전투(VDBattle)에서 쓰는 이름 그대로: 칸이 b 대신 들어간다
var juice: VDJuice
var world_top: Node2D            # 전장 팝 글자 (전투는 안개 위 레이어, 여기는 월드 그대로)
var hud_root: Control            # ensure_hud() 로 만든다
var _run_id: int:
	get:
		return run
var _hud_group: CanvasGroup
var _frame                       # VDBattleFrame (ensure_frame)
var _screen_glitch               # VDScreenGlitch (ensure_screen_glitch)
var _hurt_glitch                 # VDHurtGlitch (ensure_hurt_glitch)


func setup(e: Dictionary, px: Vector2i, big_ := false) -> void:
	entry = e
	big = big_
	stretch = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(px)
	size = Vector2(px)
	vp = SubViewport.new()
	vp.size = px
	vp.size_2d_override = Vector2i(DESIGN)
	vp.size_2d_override_stretch = true
	vp.handle_input_locally = false
	vp.gui_disable_input = true
	vp.audio_listener_enable_2d = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	_build_world()


func _build_world() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	vp.add_child(bg_layer)
	var bg := ColorRect.new()
	bg.size = DESIGN
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_mat = ShaderMaterial.new()
	bg_mat.shader = load("res://shaders/void_nebula.gdshader")
	bg_mat.set_shader_parameter("aspect", DESIGN.x / DESIGN.y)
	bg.material = bg_mat
	bg_layer.add_child(bg)

	world = Node2D.new()
	vp.add_child(world)
	map = VDMap.new()
	map.rng.seed = 7
	room = map.create_root("plaza")   # 시드 7 이 고르던 모양 그대로 (모양이 늘어도 쇼룸 무대는 고정)
	board = VDBoard.new()
	board.placement_mode = false
	world.add_child(board)
	board.map = map
	board.current_room = room
	ground_fx = Node2D.new()
	world.add_child(ground_fx)
	units_root = Node2D.new()
	units_root.y_sort_enabled = true
	world.add_child(units_root)
	fx_root = Node2D.new()
	fx_root.z_index = 50
	world.add_child(fx_root)
	vfx = VDVfx.new()
	world.add_child(vfx)
	dmg_log = VDDamageLog.new()
	dmg_log.z_index = 60
	world.add_child(dmg_log)
	audio = VDAudio.new()
	audio.enabled = big
	world.add_child(audio)
	camera = TileCamera.new()
	camera.allow_time = big
	camera.bg_material = bg_mat
	world.add_child(camera)
	goo = VDGoo.new(self)
	shockwave = preload("res://scripts/void_defense/vd_shockwave.gd").new()
	vp.add_child(shockwave)
	scratch = Node.new()
	vp.add_child(scratch)
	world_top = world
	juice = VDJuice.new(self)
	world.add_child(juice)
	look_at_cells(enemy_cells().slice(0, 1), 1.6)


## 칸을 트리에 붙인 뒤 부른다 (카메라는 트리 안에서만 현재 카메라가 된다)
func start() -> void:
	camera.make_current()
	_loop()


func _loop() -> void:
	while is_inside_tree():
		clear()
		var my := run
		var dur := 2.0
		var r = entry["play"].call(self)
		if r is float or r is int:
			dur = float(r)
		await wait(dur + GAP)
		if my != run:
			return


## 재생 사이 기다리기: 꺼진(화면 밖) 칸은 켜질 때까지 기다린다
func wait(sec: float) -> void:
	var left := sec
	while left > 0.0 and is_inside_tree():
		await get_tree().process_frame
		if active:
			left -= get_process_delta_time()
	while not active and is_inside_tree():
		await get_tree().process_frame


func clear() -> void:
	run += 1
	for u in units:
		if is_instance_valid(u):
			u.queue_free()
	units.clear()
	for n in ground_fx.get_children() + fx_root.get_children() + scratch.get_children():
		n.queue_free()
	goo.clear()
	shockwave.clear()


## 칸이 화면에 보일 때만 그리고 돈다
func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	vp.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


# ---------------------------------------------------------------- 재생 함수들이 쓰는 도우미

## 이 재생이 아직 유효한가 (await 뒤에 확인)
func alive(my: int) -> bool:
	return my == run and is_inside_tree()


func enemy_cells() -> Array[Vector2i]:
	return _cells("E")


func ally_cells() -> Array[Vector2i]:
	return _cells("A")


## 방 칸 중 kind 구역을, 구역 가운데에 가까운 순서로
func _cells(kind: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for l in VDMap.local_cells(room, kind):
		out.append(VDMap.to_world(room, l.x, l.y))
	var c := Vector2.ZERO
	for w in out:
		c += Vector2(w)
	c /= maxf(out.size(), 1.0)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_squared_to(c) < Vector2(b).distance_squared_to(c))
	return out


func spawn_unit(id: String, cell: Vector2i, team := 1) -> VDUnit:
	var u := VDUnit.new()
	var def: Dictionary = VDData.ENEMIES[id] if team == 1 else VDData.HEROES[id]
	u.setup(def, id, team, cell)
	units_root.add_child(u)
	u.snap_to_cell()
	units.append(u)
	return u


## 몸통 가운데 (전투의 VDBattle._chest 와 같은 높이)
func chest(u: VDUnit) -> Vector2:
	return u.position + Vector2(0, u._top * 0.55)


func _chest(u: VDUnit) -> Vector2:
	return chest(u)


## 전투와 같은 HUD 층: CanvasLayer 10 → CanvasGroup(피격 글리치가 HUD 버퍼를 받는다) → Control. 재생이 바뀌어도 남는다
func ensure_hud() -> Control:
	if hud_root:
		return hud_root
	var hud := CanvasLayer.new()
	hud.layer = 10
	vp.add_child(hud)
	_hud_group = CanvasGroup.new()
	hud.add_child(_hud_group)
	hud_root = Control.new()
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = VDData.font()
	theme.default_font_size = 20
	hud_root.theme = theme
	hud_root.size = DESIGN
	_hud_group.add_child(hud_root)
	return hud_root


## 아래쪽 분대 카드 (VDBattleFrame) — 전투와 같게 HUD 안에
func ensure_frame():
	if _frame:
		return _frame
	_frame = preload("res://scripts/void_defense/vd_battle_frame.gd").new()
	ensure_hud().add_child(_frame)
	_frame.setup(VDData.HERO_ORDER)
	_frame.set_stage(1, 1)
	return _frame


func ensure_screen_glitch():
	if _screen_glitch == null:
		_screen_glitch = preload("res://scripts/void_defense/vd_screen_glitch.gd").new()
		vp.add_child(_screen_glitch)
	return _screen_glitch


## 아군 피격 HUD 글리치: 전투(vd_battle.gd _build_hud)와 같게 맞은 카드 흔들림 + 화면 글리치를 함께
func ensure_hurt_glitch():
	if _hurt_glitch:
		return _hurt_glitch
	var frame = ensure_frame()
	var sg = ensure_screen_glitch()
	_hurt_glitch = preload("res://scripts/void_defense/vd_hurt_glitch.gd").new()
	vp.add_child(_hurt_glitch)
	_hurt_glitch.setup(_hud_group, frame.glitch_targets, func(hid: String, s: float, p: Dictionary) -> void:
		frame.hit_card(hid, s, p)
		sg.kick(s, "hit"))
	_hurt_glitch.prewarm.call_deferred()
	return _hurt_glitch


## 주어진 칸들이 화면 가운데 오도록 카메라를 맞춘다 (zoom = 전투 줌 배율)
func look_at_cells(cells: Array, zoom := 1.6, lift := 90.0) -> void:
	if cells.is_empty():
		return
	var c := Vector2.ZERO
	for w in cells:
		c += VDData.to_screen(Vector2(w))
	c /= float(cells.size())
	look_at(c - Vector2(0, lift / zoom), zoom)


## zoom 은 전투 줌 기준 배율: 칸이 작아 ZOOM_K 만큼 더 당겨 본다
func look_at(world_pos: Vector2, zoom := 1.6) -> void:
	camera.position = world_pos
	camera.base_zoom = Vector2(zoom, zoom) * ZOOM_K
	camera.zoom = camera.base_zoom


## 화면 좌표(1920x1080) → 월드 좌표
func screen_to_world(p: Vector2) -> Vector2:
	return camera.position + (p - DESIGN * 0.5) / camera.base_zoom   # 카메라를 막 옮긴 프레임에도 맞게


## 재생 함수 안에서 쓰는 기다리기: 실제 시간이 아니라 칸의 시간으로 (꺼진 칸은 멈춘다)
func after(sec: float) -> void:
	await wait(sec)
