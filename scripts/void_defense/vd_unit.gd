## 그레이박스 유닛: 원화 조립 씬의 캐릭터·몬스터(VDRig) + 이름 + HP 바. 아군/적 공용.
## 원화가 없는 id 는 예전 색 박스로 그린다.
## position 은 발(셀 중심) 기준이라 units_root 의 y_sort 가 그대로 깊이 정렬이 된다.
class_name VDUnit
extends Node2D

signal died(unit: VDUnit)
signal ult_ready(unit: VDUnit)    # 궁극기 게이지가 막 가득 찬 순간 (카드를 탭하라는 연출)
signal stepped(unit: VDUnit)      # 걷는 중 두 걸음(STEP_SEC × 2)마다 — 발소리용

var id := ""
var display_name := ""
var team := 0                # 0 아군, 1 적
var cell := Vector2i.ZERO      # footprint 의 최소 꼭짓점 칸 (크기 1 이면 그 칸)
var home_cell := Vector2i.ZERO
var size := 1                  # footprint 한 변의 칸 수 (대형 적 2 = 4칸)
var max_hp := 100.0
var hp := 100.0
var atk := 10.0
var attack_range := 1
var atk_cd := 1.0
var move_cd := 1.0
var move_sec := 0.25
var armor := 0.0
var atk_timer := 0.0
var move_timer := 0.0
var is_boss := false
var is_healer := false
var essence := 0
var color := Color.WHITE
var moving := false

# 액티브 스킬 (아군만 mana_gain > 0)
var mana := 0.0
var mana_gain := 0.0         # 기본 공격 한 번에 차는 마나
var casting := false         # 스킬 연출 중: 이동·공격을 쉰다
## 떠다니는 유닛 (ENEMIES 의 "float"): 타일에 묶이지 않고 VDFloatMove 가 float_pos 를 연속으로 움직인다. cell 은 그 위치에서 매 틱 다시 구한다.
var floating := false
var float_pos := Vector2.ZERO
var float_speed := 0.0       # 0 머무름 ~ 1 빠르게 이동 (파츠 애니메이션의 걷기 정도로 쓴다)

# 궁극기 (아군만 ult_gain > 0): 기본 공격·피격으로 차고, 가득 차면 플레이어가 분대 카드를 탭해 쓴다
var ult := 0.0
var ult_gain := 0.0           # 기본 공격(힐러는 치유) 한 번에 차는 게이지
var stun_timer := 0.0        # > 0 이면 행동 불가 (기절·빙결)
var frozen := false          # 기절이 빙결이면 얼음빛으로 물든다
# 상태이상 [공중에 뜸] (롤의 에어본): knock_up() 이 건다. 떠 있는 동안 행동 불가 (stun 타이머를 같이 걸어 기존 행동 판정을 그대로 쓴다)
var air_timer := 0.0         # > 0 이면 공중에 떠 있다 (남은 초)
var air_total := 0.0
var air_height := 0.0        # 이번 띄우기의 최고 높이(px)
signal air_landed(u: VDUnit) # 공중에 뜸이 끝나 바닥에 떨어진 순간
var guard_timer := 0.0       # > 0 이면 받는 피해 감소
var guard_reduce := 0.0

# 유물 상태 (VDRelicRuntime 이 건다)
var shield := 0.0            # 피해를 먼저 흡수하는 보호막
var slow_timer := 0.0        # > 0 이면 공격·이동 간격이 slow_mult 배로 늘어난다
var slow_mult := 1.0
var burn_timer := 0.0        # > 0 이면 화상 (피해는 VDRelicRuntime 이 준다)
var burn_dps := 0.0
var last_hit_by = null       # 마지막으로 때린 쪽: VDUnit 또는 유물 id 문자열 (처치 판정용)
## 성장·스킬 보정 (VDGrowth 가 써 넣는다. TrioChess stats.gd 의 skill_fx 역할)
var level := 1
var dmg_reduce := 0.0        # 받는 피해 - (최대 0.75)
var dmg_bonus := 0.0         # 평타 피해 +
var field_bonus := 0.0       # 필드 기믹(증폭 패널) 위에 서 있는 동안 평타 피해·치유량 + (vd_field_gimmicks.gd)
var crit_bonus := 0.0        # 치명타 확률 +
var atk_speed := 0.0         # 공격 간격 ÷ (1 + x)
var mana_mult := 0.0         # 마나 획득 +
var heal_bonus := 0.0        # 내가 주는 회복량 +
var freeze_chance := 0.0     # 평타 빙결 확률
var bonus_hp := 0.0          # 스킬로 더해진 최대 체력 (레벨업 체력과 따로 센다)
## 기믹 (VDGimmicks): immune 이면 어떤 피해도 들어가지 않는다 (환술사가 살아 있는 동안의 환영). show_bar 는 적 HP 바 표시
## (TrioChess: 적의 HP 바는 교전이 시작될 때 붙는다 — 배치 단계에선 이름만).
var immune := false
var show_bar := true
var ghostly := false         # 반투명 (환영)

var _flash := 0.0
var _flash_el := ""             # 피격 색: 마지막으로 맞은 공격 속성 ("" 물리 = 흰빛만. vd_hit_fx.gd ELEMENT_KEY)
var _flash_age := 99.0          # 그 피격부터 지난 시간(초)
var _tint_on := false           # 피격 색 셰이더가 켜져 있는가 (꺼질 때 한 번 0 으로 돌린다)
var _cast_glow := 0.0        # 시전 순간 몸이 빛나는 정도 (1 → 0)
var _move_tween: Tween
var _anim_tween: Tween
var _death_tween: Tween

var visual: Node2D            # VDRig 비주얼 (없으면 박스)
var _overlay: Node2D          # 이름·HP 바: 비주얼 위에 그린다 (top_root 가 있으면 그 아래로 옮겨 무엇에도 가리지 않게)
## 이름·HP 바를 올려 둘 최상위 월드 노드 (VDBattle 이 안개 위 CanvasLayer 에 만든다). 없으면 유닛 자식으로 두고 z OVERLAY_Z.
static var top_root: Node2D
const OVERLAY_Z := 58         # top_root 가 없을 때: 유닛·이펙트(fx_root 50)·유물 투사체(55) 위, 피해 숫자(60) 아래
var _top := -70.0             # 비주얼 위쪽 끝 y
var _base_dir := 1.0          # 원화가 바라보는 방향 (영웅 +1 오른쪽, 몬스터 -1 왼쪽)
var _facing := 1.0
var _vis_sx := 1.0              # 비주얼 가로 배율 크기 (뒤집기·회전 연출의 기준)
var pose_lift := 0.0           # 궁극기 연출: 비주얼을 위로 띄우는 높이(px)
var pose_spin := 0.0           # 궁극기 연출: 0→1 이면 제자리에서 한 바퀴 (가로 폭을 cos 로)
var _vis_sy := 1.0
var _hit_sq := Vector2.ONE     # 피격 찌그러짐 배율 (몬스터): 맞는 순간 납작 → 길쭉 → 출렁이며 복귀
var _hit_recoil := 0.0         # 피격 밀림(px): 바라보는 반대쪽으로
var _hit_tween: Tween
var _hp_ghost := 1.0            # HP 바 잔상(비율): 맞으면 깎인 만큼 주황 띠가 남아 일정한 속도로 따라 내려온다
var _ghost_hold := 0.0
var _hp_shown := 1.0            # HP 바에 그리는 비율: 실제 HP 를 빠르게 스르륵 따라간다
var _bar_kick := 0.0            # HP 바 흔들림 (1 → 0)
var _heal_glow := 0.0           # 회복 받은 순간 초록빛 (1 → 0)
var _wind_glow := 0.0           # 공격 예비 동작 중 차오르는 빛 (0 → 1)
var winding := false            # 공격 예비 동작 중 (VDBattle 이 끝나면 공격)
var _ready_t := 0.0             # READY 펄스 경과 (마나가 찬 순간부터)
var _idle := []               # [{node, pos, rot, scale, kind}]
var _parts: VDPartsAnim        # 파츠 몬스터(머리·몸통·팔)면 이쪽이 파츠를 움직인다 (_idle 은 비운다)
var _t := 0.0
var _phase := 0.0

# 파츠 자세 (영웅만): 가중치 0~1 을 트윈하고 VDHeroPose.POSES 값 × 가중치를 숨쉬기 위에 더한다
var _pose := {}                # VDHeroPose.POSES[id] (없으면 빈 사전 = 자세 없음)
var _p_wind := 0.0
var _p_strike := 0.0
var _p_cast := 0.0
var _p_hurt := 0.0
var _pose_tween: Tween
var _cast_tween: Tween
var _hurt_tween: Tween
# 지연 추종: 몸이 가속하면 머리·무기가 스프링처럼 늦게 따라온다 (px, 비주얼 로컬 방향)
var _lag := Vector2.ZERO
var _lag_v := Vector2.ZERO
var _prev_world := Vector2.ZERO
var _prev_vel := Vector2.ZERO

## HP 바 피격 연출 (TrioChess 체력바 방식): 깎인 구간이 주황 잔상으로 남아 HP_DRAIN 속도로 줄어들고,
## 맞은 순간 GHOST_FLASH 초 동안은 흰색으로 번쩍. 아군 바는 체력이 낮아지면 노랑 → 빨강.
const HitFx := preload("res://scripts/void_defense/vd_hit_fx.gd")     # 몬스터 피격 몸 반응 조절값 (연출 연구실 "몬스터 피격")
const KillFx := preload("res://scripts/void_defense/vd_kill_fx.gd")   # 몬스터 사망 조절값 (연출 연구실 "몬스터 사망")
const HP_TRAIL := Color("f2900f")
const HP_DRAIN := 0.7          # 잔상이 줄어드는 속도 (비율/초)
const GHOST_FLASH := 0.12
const HP_MID := Color("ffc23f")    # 50% 이하
const HP_LOW := Color("ff5f6a")    # 25% 이하


static func hp_tint(ratio: float, base: Color) -> Color:
	return base if ratio > 0.5 else (HP_MID if ratio > 0.25 else HP_LOW)


## 잔상 색: 맞은 순간 흰색 → 주황.
static func ghost_col(hold: float) -> Color:
	return Color(1.0, 0.97, 0.9).lerp(HP_TRAIL, clampf(1.0 - hold / GHOST_FLASH, 0.0, 1.0))


const STEP_SEC := 0.2         # 한 걸음(한 번 튀기) 시간
const WALK_BOUNCE := 9.0      # 튀어오르는 높이(px)
const WALK_SWAY := 7.0        # 좌우 기울기(도)
const WALK_SHIFT := 2.5       # 좌우 흔들림(px)
var _walk_t := 0.0
var _walk_amt := 0.0          # 0 서 있음 ~ 1 걷는 중 (부드럽게 전환)
var _last_pos := Vector2.ZERO

var alive: bool:
	get:
		return hp > 0.0


func setup(def: Dictionary, id_: String, team_: int, cell_: Vector2i, hp_mult := 1.0, atk_mult := 1.0) -> void:
	id = id_
	team = team_
	cell = cell_
	home_cell = cell_
	display_name = def["name"]
	color = def["color"]
	max_hp = floorf(float(def["hp"]) * hp_mult)
	hp = max_hp
	atk = floorf(float(def["atk"]) * atk_mult)
	attack_range = int(def["range"])
	atk_cd = float(def["atk_cd"])
	move_cd = float(def["move_cd"])
	move_sec = float(def.get("move_sec", 0.25))
	armor = float(def.get("armor", 0.0))
	is_boss = bool(def.get("boss", false))
	is_healer = bool(def.get("healer", false))
	essence = int(def.get("essence", 0))
	mana_gain = float(def.get("mana", 0))
	if team == 0 and VDData.ULTS.has(id):
		ult_gain = float(VDData.ULTS[id]["gain"])
	size = int(def.get("size", 1))
	floating = bool(def.get("float", false))
	ghostly = bool(def.get("ghostly", false))
	show_bar = team == 0
	# 전원이 같은 프레임에 행동하지 않게 타이머를 흩뜨린다
	atk_timer = randf() * atk_cd * 0.5
	move_timer = randf() * move_cd * 0.5
	_build_visual()
	if ghostly and visual:
		visual.modulate.a = 0.55


func _build_visual() -> void:
	_phase = randf() * TAU
	visual = VDRig.build(id, team)
	if visual:
		add_child(visual)
		_top = VDRig.top_of(visual)
		_vis_sx = absf(visual.scale.x)
		_vis_sy = visual.scale.y
		_base_dir = 1.0 if team == 0 else -1.0
		_facing = _base_dir
		for c in visual.get_children():
			var kind := "body"
			if c.name == "head":
				kind = "head"
			elif str(c.name).begins_with("weapon"):
				kind = "weapon"
			elif team == 1:
				kind = "boss" if is_boss else "monster"
			_idle.append({"node": c, "pos": c.position, "rot": c.rotation, "scale": c.scale, "kind": kind})
		if team == 0:
			_pose = VDHeroPose.POSES.get(id, {})
		elif visual.has_meta("parts"):
			_idle.clear()
			_parts = visual.get_meta("parts_anim", VDPartsAnim).new()
			_parts.setup(visual)
	else:
		_top = -(104.0 if is_boss else 66.0) - 4.0
	_overlay = Node2D.new()
	_overlay.name = "Overlay"
	_overlay.draw.connect(_draw_overlay)
	_overlay.z_as_relative = false
	_overlay.z_index = OVERLAY_Z
	add_child(_overlay)
	if is_inside_tree():
		_lift_overlay()


## 가로 방향 dx 쪽을 바라보게 비주얼을 뒤집는다.
func face(dx: float) -> void:
	if visual == null or absf(dx) < 1.0:
		return
	_facing = signf(dx)
	visual.scale.x = absf(visual.scale.x) * _facing * _base_dir


func _redraw() -> void:
	queue_redraw()
	if _overlay:
		_overlay.queue_redraw()


## 최소 꼭짓점이 c 일 때 발밑(footprint 중심)의 화면 좌표.
func foot_at(c: Vector2i) -> Vector2:
	return VDData.to_screen(Vector2(c) + Vector2.ONE * (size - 1) * 0.5)


## 모션이 끝나고 돌아갈 자리: 보통은 제 칸의 발밑, 떠다니는 유닛은 지금 떠 있는 자리.
func rest_pos() -> Vector2:
	return float_pos if floating else foot_at(cell)


func occupies(c: Vector2i) -> bool:
	return c.x >= cell.x and c.y >= cell.y and c.x < cell.x + size and c.y < cell.y + size


## 최소 꼭짓점이 at 일 때 차지하는 칸들.
func footprint(at := cell) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in size:
		for y in size:
			out.append(at + Vector2i(x, y))
	return out


## 다른 유닛 / 칸까지의 거리 (footprint 사이 가장 가까운 칸끼리의 맨해튼).
func dist_to(other: VDUnit) -> int:
	return VDData.rect_dist(cell, size, other.cell, other.size)


func dist_to_cell(c: Vector2i) -> int:
	return VDData.rect_dist(cell, size, c, 1)


func snap_to_cell() -> void:
	if _move_tween:
		_move_tween.kill()
	moving = false
	position = foot_at(cell)
	float_pos = position


func move_to_cell(c: Vector2i, dur := 0.25) -> void:
	cell = c
	if _move_tween:
		_move_tween.kill()
	moving = true
	face(foot_at(c).x - position.x)
	_move_tween = create_tween()
	_move_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_move_tween.tween_property(self, "position", foot_at(c), dur)
	_move_tween.finished.connect(func() -> void: moving = false)


## 차원 소환: 공허에서 세로로 납작한 새하얀 빛줄기로 떨어져 바닥에 꽂히고(가로로 찌그러짐),
## 위로 튕겨 늘어났다가 쫀득하게 제 모습으로 돌아오며 흰빛이 빠진다. 착지 순간 on_land 를 부른다(충격 이펙트용).
## 타이밍·배율은 VDSummonFx (연출 연구실에서 조절).
static var _white_shader: Shader
## 궁극기 조준 대상 강조 (VDUltAim): 비주얼을 CanvasGroup 으로 감싸 shaders/unit_target_outline.gdshader 를 걸고 z 를 유닛 최상위로.
static var _target_shader: Shader
const TARGET_Z := 40            # 다른 유닛(y 정렬, z 0) 위 · 궁극기 무대(45)·조준 그림(46) 아래
const TARGET_GROUP_MARGIN := 26.0   # CanvasGroup 여백(로컬 px): 외곽선이 잘리지 않게. clear 는 그 바깥 샘플까지 덮는다
var _target_group: CanvasGroup
var _target_z_saved := 0

func appear(on_land := Callable()) -> void:
	var sec := func(k: String) -> float: return maxf(VDSummonFx.g(k), 0.001)
	var foot := position
	_set_white(1.0)
	_ensure_glow()
	_glow.scale = _glow_base_scale * VDSummonFx.g("glow_size")
	_glow.modulate.a = VDSummonFx.g("glow_alpha")
	_set_airborne(true)
	# 1단계: 위에서 가늘고 길게 빛나는 채로 낙하 (가속)
	scale = Vector2(VDSummonFx.g("fall_x0"), VDSummonFx.g("fall_y0"))
	position = foot + Vector2(0, -VDSummonFx.g("drop_height") * (VDSummonFx.g("boss_height") if is_boss else 1.0))
	if _anim_tween:
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "position", foot, sec.call("drop_sec")).set_trans(VDSummonFx.trans("drop_trans")).set_ease(Tween.EASE_IN)
	_anim_tween.parallel().tween_property(self, "scale", Vector2(VDSummonFx.g("fall_x1"), VDSummonFx.g("fall_y1")), sec.call("drop_sec"))
	# 2단계: 꽂히는 순간 가로로 납작하게 퍼진다 (한 프레임 스냅 + 잠깐 버팀)
	_anim_tween.tween_callback(func() -> void:
		scale = Vector2(VDSummonFx.g("squash_x"), VDSummonFx.g("squash_y"))
		_airborne = false
		queue_redraw()
		if on_land.is_valid():
			on_land.call())
	_anim_tween.tween_property(self, "scale", Vector2(VDSummonFx.g("hold_x"), VDSummonFx.g("hold_y")), sec.call("hold_sec"))
	# 3단계: 위로 튕겨 늘어나며 원래 색이 돌아오기 시작
	var w3 := VDSummonFx.g("stretch_white")
	_anim_tween.tween_property(self, "scale", Vector2(VDSummonFx.g("stretch_x"), VDSummonFx.g("stretch_y")), sec.call("stretch_sec")).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tween.parallel().tween_method(_set_white, 1.0, w3, sec.call("stretch_sec"))
	_anim_tween.parallel().tween_property(_glow, "modulate:a", VDSummonFx.g("glow_alpha") * 0.45, sec.call("stretch_sec"))
	# 4단계: 쫀득하게 출렁이며 제자리 (탄성) + 흰빛·후광이 빠진다. 이름·HP 바는 이때 나타난다.
	_anim_tween.tween_callback(_set_airborne.bind(false))
	_anim_tween.tween_property(self, "scale", Vector2.ONE, sec.call("settle_sec")).set_trans(VDSummonFx.trans("settle_trans")).set_ease(Tween.EASE_OUT)
	_anim_tween.parallel().tween_method(_set_white, w3, 0.0, sec.call("white_fade_sec"))
	_anim_tween.parallel().tween_property(_glow, "modulate:a", 0.0, sec.call("glow_fade_sec"))


## 소환 연출 전체 길이(초): 낙하 + 버팀 + 튕김 + 안착 (VDBattle 이 마지막 적을 기다릴 때 쓴다)
static func appear_duration() -> float:
	return VDSummonFx.g("drop_sec") + VDSummonFx.g("hold_sec") + VDSummonFx.g("stretch_sec") + maxf(VDSummonFx.g("settle_sec"), maxf(VDSummonFx.g("white_fade_sec"), VDSummonFx.g("glow_fade_sec")))


var _airborne := false

## 낙하 중에는 발밑 링·그림자와 이름·HP 바를 숨긴다 (허공에서 함께 늘어나 보이지 않게).
func _set_airborne(on: bool) -> void:
	_airborne = on
	if _overlay:
		_overlay.visible = not on and is_visible_in_tree()
	queue_redraw()


## 비주얼을 흰색 실루엣 쪽으로 섞는다 (0 원래 색 ~ 1 완전 흰색).
func _set_white(k: float) -> void:
	if visual == null:
		_flash = k
		_redraw()
		return
	if visual.material == null:
		if _white_shader == null:
			_white_shader = Shader.new()
			_white_shader.code = """shader_type canvas_item;
uniform float white : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_col = vec3(1.0);   // 덮는 색 (소환·물리 피격 = 흰색, 속성 피격 = 형광색)
uniform float shade = 0.0;            // 0 = 납작한 실루엣, 1 = 원화 명암을 남긴 채 물들임
void fragment() {
	vec4 c = COLOR;   // fragment 의 COLOR 는 이미 텍스처 × modulate. texture() 를 또 곱하면 색이 제곱돼 어두워진다
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 t = flash_col * mix(1.0, 0.7 + 0.9 * l, shade);
	COLOR = vec4(mix(c.rgb, t, white), c.a);
}"""
		var m := ShaderMaterial.new()
		m.shader = _white_shader
		visual.material = m
		for c in visual.get_children():
			(c as CanvasItem).use_parent_material = true
	var mat := visual.material as ShaderMaterial
	mat.set_shader_parameter("white", k)
	mat.set_shader_parameter("flash_col", Color.WHITE)
	mat.set_shader_parameter("shade", 0.0)


## 피격 색: 비주얼을 col 로 덮는다 (k 0~1, shade = 원화 명암 남기기). 흰 섬광 셰이더를 같이 쓴다.
func _set_tint(k: float, col: Color, shade: float) -> void:
	_set_white(k)
	if visual == null:
		return
	var mat := visual.material as ShaderMaterial
	mat.set_shader_parameter("flash_col", col)
	mat.set_shader_parameter("shade", shade)


## 맞은 순간: 몬스터는 실루엣이 순백으로 덮였다가(el_hold 초) 속성 공격이면 그 형광색으로 바뀌어 빠진다. strength 는 최대 세기(도트 피해는 약하게)
func _hit_tint(element: String, strength := 1.0) -> void:
	_flash = maxf(_flash, strength)
	_flash_el = element
	_flash_age = 0.0


## 지금 덮을 색: 처음 el_hold 초는 흰색, 그 뒤 0.05초에 걸쳐 속성색으로
func _flash_color() -> Color:
	if _flash_el == "":
		return Color.WHITE
	var u := clampf((_flash_age - HitFx.g("el_hold")) / 0.05, 0.0, 1.0)
	return Color.WHITE.lerp(HitFx.element_color(_flash_el), u)


## 궁극기 조준 대상 강조를 켜고 끈다. col 은 외곽선·물들이는 색, strength 는 물드는 세기(0~1).
## 켜면 비주얼을 CanvasGroup 아래로 옮겨(합친 실루엣에 외곽선) 유닛 z 를 TARGET_Z 로 올린다. 끄면 전부 원래대로.
func set_target_highlight(on: bool, col := Color(1.0, 0.35, 0.4), strength := 1.0) -> void:
	if visual == null:
		return
	if on:
		if _target_group == null:
			if _target_shader == null:
				_target_shader = load("res://shaders/unit_target_outline.gdshader")
			# 파츠가 use_parent_material 로 그룹 재질까지 타고 올라가지 않게 비주얼 자체 재질(흰 섬광)을 먼저 둔다
			if visual.material == null:
				_set_white(0.0)
			var g := CanvasGroup.new()
			g.name = "TargetGroup"
			g.fit_margin = TARGET_GROUP_MARGIN
			g.clear_margin = TARGET_GROUP_MARGIN * 2.0
			var m := ShaderMaterial.new()
			m.shader = _target_shader
			g.material = m
			var idx := visual.get_index()
			remove_child(visual)
			g.add_child(visual)
			add_child(g)
			move_child(g, idx)
			_target_group = g
			_target_z_saved = z_index
			z_index = TARGET_Z
		var m2 := _target_group.material as ShaderMaterial
		# 형광 네온: 외곽선은 col 그대로 완전 불투명, 안쪽 코어는 거의 흰빛, 바깥으로 같은 색 글로우. 몸은 살짝만 물들인다
		m2.set_shader_parameter("outline_color", Color(col, 1.0))
		m2.set_shader_parameter("tint_color", Color(col, 1.0))
		m2.set_shader_parameter("tint_k", 0.28 * strength)
		m2.set_shader_parameter("outline_px", 3.5 + 2.0 * strength)
		m2.set_shader_parameter("glow_px", 7.0 + 4.0 * strength)
		return
	if _target_group == null:
		return
	var g2 := _target_group
	_target_group = null
	var idx2 := g2.get_index()
	g2.remove_child(visual)
	remove_child(g2)
	add_child(visual)
	move_child(visual, idx2)
	g2.queue_free()
	z_index = _target_z_saved


## 강조 숨쉬기 (0~1): 외곽선 두께·몸 밝기. 조준 화면이 실제 시간으로 매 프레임 넣는다.
func set_target_pulse(k: float) -> void:
	if _target_group:
		(_target_group.material as ShaderMaterial).set_shader_parameter("pulse", k)


var _glow: Sprite2D
var _glow_base_scale := Vector2.ONE

## 소환 빛의 보랏빛 후광: 몸 뒤에 가산 블렌드 방사형 그라데이션.
func _ensure_glow() -> void:
	if _glow:
		return
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 1.0, 1.0))
	g.set_color(1, Color(0.6, 0.2, 1.0, 0.0))
	g.add_point(0.35, Color(0.85, 0.5, 1.0, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_glow = Sprite2D.new()
	_glow.name = "SummonGlow"
	_glow.texture = tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.position = Vector2(0, _top * 0.5)
	_glow_base_scale = Vector2(1.3, absf(_top) / 128.0 * 1.8)
	_glow.scale = _glow_base_scale
	_glow.modulate.a = 0.0
	add_child(_glow)
	move_child(_glow, 0)


## 공격 예비 동작: sec 동안 뒤로 움츠리며(가로로 눌림) 몸에 빛이 차오른다. 끝나면 VDBattle 이 release_windup + 공격.
## 영웅은 몸 찌그러짐을 절반만 쓰고 대신 파츠 자세(wind: 무기를 당기거나 들어 올림)로 예비 동작을 보인다.
func windup(toward: Vector2, sec: float) -> void:
	winding = true
	face(toward.x - position.x)
	if _parts and _parts.has_method("aim"):
		_parts.aim(toward - position, sec + 0.5)
	var k := 0.5 if team == 0 else 1.0
	if _hit_tween:
		_hit_tween.kill()
	_hit_tween = create_tween()
	_hit_tween.tween_property(self, "_hit_sq", Vector2(1.0 + 0.16 * k, 1.0 - 0.16 * k), sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hit_tween.parallel().tween_property(self, "_hit_recoil", 9.0 * k, sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hit_tween.parallel().tween_property(self, "_wind_glow", 1.0, sec)
	if not _pose.is_empty():
		if _pose_tween:
			_pose_tween.kill()
		_pose_tween = create_tween().set_parallel(true)
		_pose_tween.tween_property(self, "_p_wind", 1.0, sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_pose_tween.tween_property(self, "_p_strike", 0.0, sec)


## 예비 동작을 풀고 튕겨 나가듯 (늘어났다 제자리). 영웅의 wind 자세는 attack_anim 의 타격 자세가 이어받는다.
func release_windup() -> void:
	winding = false
	_wind_glow = 0.0
	if _hit_tween:
		_hit_tween.kill()
	_hit_recoil = 0.0
	var k := 0.5 if team == 0 else 1.0
	_hit_sq = Vector2(1.0 - 0.14 * k, 1.0 + 0.16 * k)
	_hit_tween = create_tween()
	_hit_tween.tween_property(self, "_hit_sq", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not _pose.is_empty() and _p_strike == 0.0:
		# 공격이 취소돼도(대상이 사정거리 밖) 자세가 남지 않게 풀어 둔다. 공격하면 _strike 가 바로 덮어쓴다.
		if _pose_tween:
			_pose_tween.kill()
		_pose_tween = create_tween()
		_pose_tween.tween_property(self, "_p_wind", 0.0, 0.12)


## 타격 자세: 예비 자세에서 순식간에 휘두르고(0.06초) 잠깐 버틴 뒤, 살짝 지나쳤다가(TRANS_BACK) 제자리 = 여운.
## 몸이 앞으로 튀어 나가는 만큼 머리·무기가 뒤로 처지게 지연 스프링도 걷어찬다.
func _strike() -> void:
	if _pose_tween:
		_pose_tween.kill()
	_pose_tween = create_tween()
	_pose_tween.tween_property(self, "_p_strike", 1.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose_tween.parallel().tween_property(self, "_p_wind", 0.0, 0.06)
	_pose_tween.tween_interval(0.08)
	_pose_tween.tween_property(self, "_p_strike", 0.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lag_v.x -= 260.0


func attack_anim(toward: Vector2) -> void:
	if not _pose.is_empty():
		face(toward.x - position.x)
		_strike()
	if _parts:
		_parts.strike()
	if _anim_tween:
		_anim_tween.kill()
	var dir := (toward - position).normalized()
	face(toward.x - position.x)
	if _parts and _parts.has_method("aim"):
		_parts.aim(toward - position, 0.55)
	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "scale", Vector2(1.18, 0.88), 0.07)
	_anim_tween.parallel().tween_property(self, "position", position + dir * 10.0, 0.07)
	_anim_tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	_anim_tween.parallel().tween_property(self, "position", rest_pos(), 0.12)


## 스킬 도약: 포물선을 그리며 c 로 뛰어 착지한다. 착지까지의 Tween 을 돌려준다.
func leap_to(c: Vector2i, dur: float, height: float) -> Tween:
	cell = c
	if _move_tween:
		_move_tween.kill()
	if _anim_tween:
		_anim_tween.kill()
	moving = false
	scale = Vector2.ONE
	var from := position
	var to := foot_at(c)
	face(to.x - from.x)
	_move_tween = create_tween()
	_move_tween.tween_method(func(k: float) -> void:
		position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * height), 0.0, 1.0, dur)
	_move_tween.tween_property(self, "scale", Vector2(1.25, 0.8), 0.06)
	_move_tween.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return _move_tween


## 순간이동 강하(보스 스킬): 세로로 가늘어지며 사라졌다가 hang 초 뒤 c 위 height 에서 나타나 drop 초 만에 내려꽂힌다.
## 칸은 바로 c 로 옮긴다(자리 예약). 착지 순간 on_land 를 부르고 납작해졌다 탄성으로 돌아온다.
func teleport_drop(c: Vector2i, face_x: float, vanish: float, hang: float, drop: float, height: float, on_land: Callable) -> void:
	cell = c
	if _move_tween:
		_move_tween.kill()
	if _anim_tween:
		_anim_tween.kill()
	moving = false
	var to := foot_at(c)
	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "scale", Vector2(0.12, 1.9), vanish).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_anim_tween.parallel().tween_property(self, "modulate:a", 0.0, vanish)
	_anim_tween.tween_callback(_set_airborne.bind(true))
	_anim_tween.tween_interval(hang)
	_anim_tween.tween_callback(func() -> void:
		position = to + Vector2(0, -height)
		scale = Vector2(0.55, 1.6)
		face(face_x - to.x))
	_anim_tween.tween_property(self, "position", to, drop).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_anim_tween.parallel().tween_property(self, "modulate:a", 1.0, drop * 0.5)
	_anim_tween.tween_callback(func() -> void:
		_set_airborne(false)
		scale = Vector2(1.45, 0.62)
		if on_land.is_valid():
			on_land.call())
	_anim_tween.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## 마나를 채운다 (가득 차면 VDBattle 이 스킬을 시전한다).
func gain_mana(amount: float) -> void:
	if mana_gain <= 0.0:
		return
	var was := mana >= VDData.MAX_MANA
	mana = minf(VDData.MAX_MANA, mana + amount * (1.0 + mana_mult))
	if not was and mana >= VDData.MAX_MANA:
		_ready_t = 0.0
	_redraw()


func mana_full() -> bool:
	return mana_gain > 0.0 and mana >= VDData.MAX_MANA


## 궁극기 게이지를 채운다 (쓰러져 있으면 차지 않는다).
func gain_ult(amount: float) -> void:
	if ult_gain <= 0.0 or not alive or amount <= 0.0:
		return
	var was := ult >= VDData.MAX_ULT
	ult = minf(VDData.MAX_ULT, ult + amount)
	if not was and ult >= VDData.MAX_ULT:
		ult_ready.emit(self)


func ult_full() -> bool:
	return ult_gain > 0.0 and ult >= VDData.MAX_ULT


## 쓰러진 아군을 일으킨다: 체력 ratio 로, 넘어진 자세·회색을 풀고 제자리에 선다. 마나·궁극기 게이지는 0 에서 다시.
func revive(ratio: float) -> void:
	set_process(true)
	if alive:
		return
	if _death_tween:
		_death_tween.kill()
	revive_full()
	if team == 1 and visual:
		# 몬스터(공허 촉수): 녹아내린 비주얼을 제 크기로 되돌린다
		visual.scale = Vector2(_vis_sx * _facing * _base_dir, _vis_sy)
		if _hit_tween:
			_hit_tween.kill()
		_hit_sq = Vector2.ONE
		_hit_recoil = 0.0
	hp = maxf(1.0, floorf(max_hp * ratio))
	_hp_ghost = hp / max_hp
	_hp_shown = _hp_ghost
	mana = 0.0
	ult = 0.0
	reset_combat()
	snap_to_cell()
	_heal_glow = 1.0
	_cast_glow = 1.0
	# 바닥에서 쑥 솟아오르듯: 납작 → 길쭉 → 제자리
	_hit_sq = Vector2(1.3, 0.4)
	if _hit_tween:
		_hit_tween.kill()
	_hit_tween = create_tween()
	_hit_tween.tween_property(self, "_hit_sq", Vector2(0.85, 1.2), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(self, "_hit_sq", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 시전 순간: 몸이 빛나며 살짝 커졌다 돌아온다.
func cast_pulse() -> void:
	_cast_glow = 1.0
	if not _pose.is_empty():
		# 시전 자세: 무기를 높이 치켜들고 고개를 든다 → 잠시 버텼다 내려놓는다
		if _cast_tween:
			_cast_tween.kill()
		_cast_tween = create_tween()
		_cast_tween.tween_property(self, "_p_cast", 1.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_cast_tween.tween_interval(0.4)
		_cast_tween.tween_property(self, "_p_cast", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_lag_v.y += 220.0
	if _anim_tween:
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "scale", Vector2(1.22, 1.22), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(self, "scale", Vector2.ONE, 0.2)


const AIR_HEIGHT := 92.0     # 공중에 뜸 기본 최고 높이(px). 대형·보스는 절반

## 상태이상 [공중에 뜸]: sec 초 동안 포물선으로 떠올랐다 떨어진다. 그동안 행동 불가.
## 대형·보스는 무거워 절반 높이로만 뜬다. 떨어지는 순간 납작하게 착지하고 air_landed 를 낸다.
func knock_up(sec: float, height := AIR_HEIGHT) -> void:
	if not alive or sec <= 0.0:
		return
	if air_timer > 0.0 and air_timer > sec:
		return   # 이미 더 오래 떠 있다
	air_total = sec
	air_timer = sec
	air_height = height * (0.5 if is_boss or size > 1 else 1.0)
	stun(sec)
	_redraw()


## 지금 떠 있는 높이(px): 0 → 최고 → 0 포물선 (중력처럼 빠르게 솟았다 꼭대기에서 잠깐 머물고 떨어진다)
func air_lift() -> float:
	if air_timer <= 0.0 or air_total <= 0.0:
		return 0.0
	var p := 1.0 - air_timer / air_total
	return air_height * 4.0 * p * (1.0 - p)


func stun(sec: float, freeze := false) -> void:
	if not alive:
		return
	if sec >= stun_timer:
		frozen = freeze
	stun_timer = maxf(stun_timer, sec)
	_redraw()


## 방어력과 가드를 적용한 실제 피해량을 돌려준다.
## element 는 공격 속성 ("" 물리 · "번개" · "화염" · "서리" · "정수") — 몬스터 피격 색. strength 는 번쩍임 세기 (도트 피해는 약하게)
func take_damage(amount: float, element := "", strength := 1.0) -> float:
	if not alive:
		return 0.0
	if immune:
		# 무적(환영): 맞은 티만 내고 피해는 0. 호출한 쪽이 IMMUNE 글자를 띄운다
		_hit_tint("")
		hit_punch(0.3)
		_redraw()
		return 0.0
	if armor > 0.0:
		amount = ceilf(amount * (1.0 - armor))
	if dmg_reduce > 0.0:
		amount = floorf(amount * (1.0 - minf(dmg_reduce, 0.75)))
	if guard_timer > 0.0:
		amount = floorf(amount * (1.0 - guard_reduce))
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
	if amount > 0.0:
		_ghost_hold = GHOST_FLASH
		_bar_kick = 1.0
	hp = maxf(0.0, hp - amount)
	gain_ult(amount / maxf(max_hp, 1.0) * VDData.ULT_PER_HURT)   # 맞을수록 궁극기가 빨리 찬다
	_hit_tint(element, strength)
	hit_punch(0.45 + 4.0 * amount / maxf(max_hp, 1.0))
	if _parts and amount > 0.0:
		_parts.hurt(0.5 + 3.0 * amount / maxf(max_hp, 1.0))
	if not _pose.is_empty() and amount > 0.0:
		# 피격 자세: 고개가 젖혀지고 몸이 뒤로 → 금방 돌아온다 (세게 맞을수록 깊게)
		if _hurt_tween:
			_hurt_tween.kill()
		_p_hurt = clampf(0.55 + 3.0 * amount / maxf(max_hp, 1.0), 0.55, 1.0)
		_hurt_tween = create_tween()
		_hurt_tween.tween_property(self, "_p_hurt", 0.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_lag_v.x -= 180.0 * _p_hurt
	_redraw()
	if hp <= 0.0:
		_die()
	return amount


## 몬스터 피격 스케일 트윈: 발밑 기준으로 확 납작해졌다(+뒤로 밀림) 위로 튀듯 늘어나고, 반대로 한 번 더 출렁인 뒤 제자리.
## power 0~1 (피해가 클수록 세게). 대형·보스는 묵직하게 덜 찌그러진다. 시간 배율을 따르므로 히트스탑 동안 납작한 채 멈춘다.
## 아군은 같은 모양을 약하게(0.45배): 움찔하고 살짝 밀린다.
## 몬스터의 모양·시간은 vd_hit_fx.gd "6 몸 반응" 값 (아군은 그 기본값 그대로).
func hit_punch(power: float) -> void:
	if visual == null:
		return
	var m := team == 1
	var a := clampf(power, 0.35, 1.0) * (0.6 if is_boss or size > 1 else 1.0) * (0.45 if team == 0 else 1.0)
	a *= HitFx.g("punch_k") if m else 1.0
	var sx := HitFx.g("punch_sx") if m else 0.42
	var sy := HitFx.g("punch_sy") if m else 0.36
	var rx := HitFx.g("punch_rx") if m else 0.2
	var ry := HitFx.g("punch_ry") if m else 0.3
	var wob := HitFx.g("punch_wob") if m else 0.09
	var up := HitFx.g("punch_sec") if m else 0.07
	if _hit_tween:
		_hit_tween.kill()
	_hit_sq = Vector2(1.0 + sx * a, 1.0 - sy * a)
	_hit_recoil = (HitFx.g("recoil_px") if m else 15.0) * a
	_hit_tween = create_tween()
	_hit_tween.tween_property(self, "_hit_sq", Vector2(1.0 - rx * a, 1.0 + ry * a), up).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hit_tween.parallel().tween_property(self, "_hit_recoil", 0.0, up * 22.0 / 7.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(self, "_hit_sq", Vector2(1.0 + wob * a, 1.0 - wob * 0.89 * a), up).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hit_tween.tween_property(self, "_hit_sq", Vector2.ONE, HitFx.g("settle_sec") if m else 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 피격 섬광만 (피해 없이 맞은 티: 연출 연구실)
func hit_flash(element := "") -> void:
	_hit_tint(element)
	_redraw()


func heal(amount: float) -> void:
	if not alive:
		return
	hp = minf(max_hp, hp + amount)
	_heal_glow = 1.0
	# 회복: 위로 쭉 늘어났다 쫀득하게 제자리 (피격과 반대 방향)
	if visual and not winding:
		if _hit_tween:
			_hit_tween.kill()
		_hit_sq = Vector2(0.9, 1.14)
		_hit_tween = create_tween()
		_hit_tween.tween_property(self, "_hit_sq", Vector2(1.05, 0.96), 0.1).set_trans(Tween.TRANS_SINE)
		_hit_tween.tween_property(self, "_hit_sq", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_redraw()


func revive_full() -> void:
	set_process(true)
	hp = max_hp
	_hp_ghost = 1.0
	_hp_shown = 1.0
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE
	if visual:
		visual.rotation = 0.0
		visual.position = Vector2.ZERO
	_p_wind = 0.0
	_p_strike = 0.0
	_p_cast = 0.0
	_p_hurt = 0.0
	_lag = Vector2.ZERO
	_lag_v = Vector2.ZERO
	if _parts:
		_parts.reset()
	_redraw()


func _die() -> void:
	moving = false
	if air_timer > 0.0 and visual:
		# 공중에서 쓰러지면 바닥으로 떨어진 뒤 녹아내린다
		air_timer = 0.0
		var fall := create_tween()
		fall.tween_property(visual, "position", Vector2(visual.position.x, 0.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.parallel().tween_property(visual, "rotation", 0.0, 0.14)
	if _move_tween:
		_move_tween.kill()
	var t := create_tween()
	_death_tween = t
	if team == 1 and visual:
		# 몬스터: 마지막 일격에 크게 찌그러졌다가 바닥으로 녹아내리듯 납작해지며 사라진다 (체액은 VDGoo 가 남긴다)
		if _hit_tween:
			_hit_tween.kill()
		# 모양·시간은 vd_kill_fx.gd "3 몸 찌그러짐"
		KillFx.body_tween(t, self, visual, _vis_sx * _facing * _base_dir, _vis_sy)
		if _parts:
			_parts.scatter(self)
	elif visual:
		# 아군: 뒤로 튕겨 쓰러진다(발밑 기준 회전 + 통통 튐) → 잠깐 누워 있다가 회색으로 바래며 사라진다
		winding = false
		if _hit_tween:
			_hit_tween.kill()
		_hit_sq = Vector2.ONE
		if not _pose.is_empty():
			# 쓰러지는 동안 고개가 젖혀진 피격 자세로 굳는다 (아이들이 멈춰 마지막 자세가 남는다)
			for tw in [_pose_tween, _cast_tween, _hurt_tween]:
				if tw:
					tw.kill()
			_p_wind = 0.0
			_p_strike = 0.0
			_p_cast = 0.0
			_p_hurt = 1.0
			_animate_idle()
		var back := -_facing
		var vp := visual.position
		t.tween_property(visual, "position", vp + Vector2(back * 26.0, -30.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(visual, "rotation", back * 0.9, 0.14)
		t.tween_property(visual, "position", vp + Vector2(back * 44.0, 0.0), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(visual, "rotation", back * 1.45, 0.16)
		t.tween_property(visual, "position", vp + Vector2(back * 50.0, -8.0), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(visual, "position", vp + Vector2(back * 52.0, 0.0), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(self, "modulate", Color(0.55, 0.5, 0.65, 1.0), 0.3)
		t.tween_interval(0.5)
		t.tween_property(self, "modulate:a", 0.0, 0.45)
	else:
		t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(func() -> void:
		visible = false
		_sync_overlay()      # HP 바 층도 숨긴 뒤
		set_process(false))  # 시체는 스테이지가 끝날 때까지 남아 있으니 매 프레임 갱신을 쉰다 (revive 가 다시 켠다)
	died.emit(self)


## 전투 시간으로 상태 타이머를 줄인다 (VDBattle 이 전투 중에만 부른다).
func tick_status(dt: float) -> void:
	if air_timer > 0.0:
		air_timer = maxf(0.0, air_timer - dt)
		if air_timer == 0.0:
			hit_punch(0.75)   # 착지: 납작하게 쿵
			air_landed.emit(self)
		_redraw()
	if stun_timer > 0.0:
		stun_timer = maxf(0.0, stun_timer - dt)
		if stun_timer == 0.0:
			frozen = false
		_redraw()
	if guard_timer > 0.0:
		guard_timer = maxf(0.0, guard_timer - dt)
		_redraw()
	if slow_timer > 0.0:
		slow_timer = maxf(0.0, slow_timer - dt)
		_redraw()
	if burn_timer > 0.0:
		burn_timer = maxf(0.0, burn_timer - dt)
		_redraw()


## 둔화 중이면 공격·이동 간격에 곱하는 배율.
func cd_mult() -> float:
	return slow_mult if slow_timer > 0.0 else 1.0


## 공격 간격 배율: 둔화 + 공격 속도 스킬(속사).
func atk_cd_mult() -> float:
	return cd_mult() / (1.0 + atk_speed)


## 방을 넘어갈 때: 상태이상을 비운다. 마나는 다음 전투로 이어진다.
func reset_combat() -> void:
	casting = false
	stun_timer = 0.0
	air_timer = 0.0
	frozen = false
	guard_timer = 0.0
	shield = 0.0
	slow_timer = 0.0
	burn_timer = 0.0
	last_hit_by = null
	_redraw()


func _process(delta: float) -> void:
	if floating and alive and not _airborne:
		# 떠다니는 유닛의 판정 칸 = 지금 화면에 보이는 자리. 전투 틱이 멈춘 동안(궁극기 연출 등)에도 어긋나지 않게 매 프레임 여기서 맞춘다
		var at := VDFloatMove.cell_at(self, position)
		if at != cell:
			cell = at
			queue_redraw()
	_sync_overlay()
	_cast_glow = maxf(0.0, _cast_glow - delta * 2.5)
	if visual:
		# 피격 섬광·시전 빛: 원화를 하얗게 밝힌다 (modulate 1 초과 = 가산 느낌). 빙결이면 얼음빛.
		# 몬스터의 피격 섬광은 밝기 곱이 아니라 셰이더로 실루엣을 덮는다 (아래 피격 색). 어두운 원화도 확실히 하얗게
		var f := 1.0 + 1.6 * _flash * (0.0 if team == 1 else 1.0) + 0.9 * _cast_glow
		var tint := Color(0.55, 0.85, 1.45) if frozen and stun_timer > 0.0 else Color.WHITE
		# 회복: 초록빛 / 예비 동작: 적은 붉게, 아군은 하얗게 달아오른다
		tint = tint.lerp(Color(0.75, 1.5, 0.8), _heal_glow * 0.7)
		if _wind_glow > 0.0:
			tint = tint.lerp(Color(1.7, 0.6, 0.7) if team == 1 else Color(1.4, 1.4, 1.4), _wind_glow * 0.55)
		visual.modulate = Color(tint.r * f, tint.g * f, tint.b * f)
	if _heal_glow > 0.0:
		# HP 바도 회복빛(연두)을 빼며 다시 그린다. 예전엔 여기서 다시 그리지 않아, 만피에서 회복을 받으면(체력이 안 움직임)
		# 다음 피격까지 바가 밝은 연두로 굳어 있었다 (2026-11-09 '가끔 체력바가 살짝 밝다' 버그)
		_heal_glow = maxf(0.0, _heal_glow - delta * 3.0)
		_redraw()
	# HP 바: 채움은 빠르게 스르륵, 잔상은 번쩍인 뒤 일정한 속도로 따라 내려온다. 회복이면 잔상은 바로 맞춘다
	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	if absf(_hp_shown - ratio) > 0.0005:
		_hp_shown = lerpf(_hp_shown, ratio, 1.0 - exp(-delta * 25.0))
		_redraw()
	else:
		_hp_shown = ratio
	if _hp_ghost < ratio:
		_hp_ghost = ratio
	elif _hp_ghost > ratio:
		_ghost_hold -= delta
		if _ghost_hold <= 0.0:
			_hp_ghost = move_toward(_hp_ghost, ratio, delta * HP_DRAIN)
		_redraw()
	if _bar_kick > 0.0:
		_bar_kick = maxf(0.0, _bar_kick - delta * 6.0)
		_redraw()
	if mana_full():
		_ready_t += delta
		_redraw()
	if _flash > 0.0:
		var fade := 5.0
		if team == 1:
			# 물리: 흰빛이 바로 빠진다. 속성: 순백(el_hold) → 형광색 꽉 찬 채(el_keep) 동안은 그대로 → el_fade 로 빠진다
			if _flash_el == "":
				fade = HitFx.g("white_fade")
			else:
				fade = 0.0 if _flash_age < HitFx.g("el_hold") + HitFx.g("el_keep") else HitFx.g("el_fade")
		_flash = maxf(0.0, _flash - delta * fade)
		_redraw()
	# 몬스터 피격 색: 흰 실루엣 → 속성 형광색 (vd_hit_fx.gd "8 피격 색")
	if team == 1 and visual:
		_flash_age += delta
		if _flash > 0.0:
			_tint_on = true
			var colored := _flash_el != "" and _flash_age >= HitFx.g("el_hold")
			_set_tint(minf(1.0, _flash * HitFx.g("white_k")), _flash_color(), HitFx.g("el_shade") if colored else 0.0)
		elif _tint_on:
			_tint_on = false
			_set_tint(0.0, Color.WHITE, 0.0)
	if visual and alive:
		_t += delta
		_animate_walk(delta)
		if not _pose.is_empty():
			_update_lag(delta)
		_animate_idle()
		if _parts:
			_parts.update(delta, _t, _phase, _wind_glow, maxf(_walk_amt, float_speed), _walk_t * PI / STEP_SEC, stun_timer > 0.0)
	_last_pos = position


## 지연 추종 스프링: 몸(유닛 위치 + 걷기 튐)의 가속도 반대로 머리·무기를 밀어 둔다.
## 앞으로 확 나가면 머리가 뒤로 처지고, 착지하면 아래로 출렁인다. 순간이동·스냅 같은 튀는 가속은 버린다.
func _update_lag(delta: float) -> void:
	if delta < 0.002:   # 히트스탑 중엔 그대로 멈춘다
		return
	var world := position + visual.position
	var vel := (world - _prev_world) / delta
	var acc := (vel - _prev_vel) / delta
	_prev_world = world
	_prev_vel = vel
	if acc.length() > 30000.0:
		acc = Vector2.ZERO
	var acc_local := Vector2(acc.x * signf(visual.scale.x), acc.y)
	_lag_v += (-VDHeroPose.LAG_K * _lag - VDHeroPose.LAG_DAMP * _lag_v - acc_local * VDHeroPose.LAG_GAIN * VDHeroPose.LAG_K) * delta
	_lag += _lag_v * delta
	_lag = _lag.clamp(Vector2.ONE * -VDHeroPose.LAG_MAX, Vector2.ONE * VDHeroPose.LAG_MAX)


## 파츠 하나에 더할 자세 오프셋 [pos(px), rot(rad)] — 포즈별 가중치 합.
func _pose_offset(part: String) -> Array:
	var p := Vector2.ZERO
	var r := 0.0
	for pn in VDHeroPose.POSE_NAMES:
		var w: float = get("_p_" + pn)
		if w == 0.0:
			continue
		var d: Dictionary = _pose[pn].get(part, {})
		if not d.is_empty():
			p += d["pos"] * w
			r += d["rot"] * w
	return [p, deg_to_rad(r)]


## 발밑 기준 몸 전체 기울기(rad): 몸통을 기울이면 머리·무기도 같은 축으로 함께 돈다.
func _pose_lean() -> float:
	var l := 0.0
	for pn in VDHeroPose.POSE_NAMES:
		l += float(_pose[pn].get("lean", 0.0)) * float(get("_p_" + pn))
	return deg_to_rad(l)


## 걷기: moving 동안 한 걸음(STEP_SEC)마다 통통 튀고, 걸음마다 몸을 좌우로 번갈아 기울인다.
## 멈추면 걸음 위상을 마저 끝내듯 부드럽게 바로 선다. 진행 방향은 실제 위치 변화로 정한다(복도 이동 포함).
func _animate_walk(delta: float) -> void:
	var vel := position - _last_pos
	if moving and absf(vel.x) > 0.3:
		face(vel.x)
	_walk_amt = move_toward(_walk_amt, 1.0 if moving else 0.0, delta * 8.0)
	if moving:
		var first := _walk_t == 0.0
		var before := int(_walk_t / STEP_SEC)
		_walk_t += delta
		var now := int(_walk_t / STEP_SEC)
		# 첫 걸음에 바로, 그 뒤 두 걸음에 한 번 (매 걸음은 넷이 같이 걸을 때 너무 잦다 — 마녀산장 발소리와 같은 규칙)
		if first or (now != before and now % 2 == 0):
			stepped.emit(self)
	elif _walk_amt == 0.0:
		_walk_t = 0.0
	var heavy := 0.45 if is_boss or armor > 0.0 else 1.0
	var step := _walk_t * PI / STEP_SEC
	# sin(step) 은 걸음마다 부호가 바뀌므로: |sin| = 매 걸음 튀어오름, sin = 왼발·오른발 번갈아 기울기
	var s := sin(step)
	var k := heavy * _walk_amt
	visual.position = Vector2(WALK_SHIFT * s * k, -absf(s) * WALK_BOUNCE * k)
	visual.rotation = deg_to_rad(WALK_SWAY) * s * k
	visual.position.y -= pose_lift
	visual.position.x -= _facing * _hit_recoil
	if air_timer > 0.0:
		# 공중에 뜸: 위로 떠오르며 뒤로 젖혀진다 (그림자는 바닥에 남아 작아진다 — _draw)
		var lift := air_lift()
		visual.position.y -= lift
		visual.rotation += -_facing * 0.32 * lift / maxf(air_height, 1.0)
	var sx := _vis_sx * _hit_sq.x
	if pose_spin != 0.0:
		var c := cos(pose_spin * TAU)
		sx *= c if absf(c) > 0.12 else 0.12 * (1.0 if c >= 0.0 else -1.0)
	visual.scale = Vector2(sx * _facing * _base_dir, _vis_sy * _hit_sq.y)


## vd_visual_idle.gd 의 아이들을 유닛용으로 줄인 것: 영웅은 숨쉬기(몸통 늘었다 줄기, 머리·무기 따라 올라감),
## 보이들링은 찌그러짐·늘어남, 공허 군주는 느린 호흡.
## 영웅은 그 위에 파츠 자세(VDHeroPose)와 지연 추종을 더한다: 몸 전체가 발밑 기준으로 기울고(lean),
## 머리·무기는 자세 오프셋 + 스프링 지연만큼 따로 움직인다.
func _animate_idle() -> void:
	var b := sin(_t * TAU / 2.6 + _phase)
	var posed := not _pose.is_empty()
	var lean := _pose_lean() if posed else 0.0
	for it in _idle:
		var n: Node2D = it["node"]
		var pos: Vector2 = it["pos"]
		var off := _pose_offset(str(n.name)) if posed else [Vector2.ZERO, 0.0]
		match it["kind"]:
			"body":
				n.scale = it["scale"] * Vector2(1.0 - 0.012 * b, 1.0 + 0.022 * b)
				if posed:
					n.position = pos.rotated(lean)
					n.rotation = it["rot"] + lean
			"head":
				var p: Vector2 = pos + Vector2(0, -3.0 * b) + off[0] + _lag
				n.position = p.rotated(lean)
				n.rotation = it["rot"] + deg_to_rad(1.6) * sin(_t * TAU / 4.4 + _phase) + off[1] + lean + _lag.x * 0.014
			"weapon":
				var p: Vector2 = pos + Vector2(0, -2.0 * b) + off[0] + _lag * 0.6
				n.position = p.rotated(lean)
				n.rotation = it["rot"] + deg_to_rad(1.2) * sin(_t * TAU / 3.4 + _phase + 1.0) + off[1] + lean + _lag.x * 0.022 + _lag.y * 0.01
			"monster":
				var s := sin(_t * TAU / 1.6 + _phase)
				if id == "skirmisher":
					n.position = pos + Vector2(0, 5.0 * s)
				else:
					var flex := s * (0.25 if armor > 0.0 else 1.0)
					n.scale = it["scale"] * Vector2(1.0 + 0.06 * flex, 1.0 - 0.07 * flex)
			"boss":
				var s := sin(_t * TAU / 3.8 + _phase)
				n.scale = it["scale"] * Vector2(1.0 + 0.012 * s, 1.0 + 0.018 * s)
				n.position = pos + Vector2(0, -3.0 * sin(_t * TAU / 7.6 + _phase))


func _draw() -> void:
	if _airborne:
		return
	# 발밑 셀 링 (아군 하늘색 / 적 붉은색) — 원화의 네온 셀 하이라이트 자리
	var ring := Color(0.5, 0.9, 1.0) if team == 0 else Color(1.0, 0.36, 0.46)
	# 떠다니는 유닛은 몸이 아니라 지금 판정에 쓰이는 칸(cell)에 링을 그린다 → 어느 타일을 밟고 있는지 보인다
	var base := VDData.diamond(foot_at(cell) - position if floating else Vector2.ZERO, 6.0, size)
	draw_colored_polygon(base, Color(ring, 0.16))
	draw_polyline(base, Color(ring, 0.9), 2.0)
	if visual:
		# 발밑 그림자
		var sh := PackedVector2Array()
		# 대형(2x2) 적은 네 다리가 2칸 마름모에 걸치므로 다리 폭만큼 넓게
		var rx := 46.0 if is_boss else (30.0 if size == 1 else 50.0 * size)
		# 공중에 뜸: 높이 뜰수록 그림자가 작고 옅어진다
		var up := air_lift() / maxf(air_height, 1.0)
		rx *= 1.0 - 0.35 * up
		for i in 24:
			sh.append(Vector2.from_angle(TAU * i / 24.0) * Vector2(rx, rx * 0.4))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.35 * (1.0 - 0.45 * up)))
		return
	var w := 76.0 if is_boss else 44.0
	var h := 104.0 if is_boss else 66.0
	# 몸통 박스 (원화가 없는 유닛용)
	var body := Rect2(-w * 0.5, -h - 4.0, w, h)
	draw_rect(body, color.darkened(0.35))
	draw_rect(body.grow(-3.0), color)
	if team == 1:
		# 적은 눈 두 개로 "잔재" 느낌만
		var ey := body.position.y + h * 0.35
		draw_circle(Vector2(-w * 0.2, ey), 4.0, Color(0.95, 0.95, 1.0))
		draw_circle(Vector2(w * 0.2, ey), 4.0, Color(0.95, 0.95, 1.0))
	if _flash > 0.0:
		draw_rect(body, Color(1, 1, 1, _flash * 0.85))


## 유닛 HP 바 (TrioChess hud.gd register_unit 이식): 폭 64(대형·보스 110) × 높이 12, 둥근 먹색 받침(INK) 위에
## 주황 잔상 → 채움(아군 초록 76cd2b / 적 붉은 ef3f55) → 위쪽 흰 광택 띠. 아군 바 왼쪽엔 금색 레벨 배지.
## 적 바는 교전이 시작될 때 나타난다 (show_bar). 체력이 가득 차 있어도 늘 그린다.
const BAR_W := 64.0
const BAR_W_BIG := 110.0
const BAR_H := 12.0
const BAR_INK := Color("16121f")
const BAR_HERO := Color("76cd2b")
const BAR_ENEMY := Color("ef3f55")
const BAR_GLOSS := Color(1, 1, 1, 0.3)
const BADGE_GOLD := Color("f4c542")
## HP 바 모양: 검은 테두리 상자(바 + BAR_PAD 사방) 모서리 반지름 BAR_RADIUS, 안쪽 채움은 같은 중심의 BAR_RADIUS - BAR_PAD.
## 채움·잔상·광택을 둥근 상자(StyleBoxFlat)로 그려 테두리 두께가 모서리에서도 일정하게 (예전엔 각진 사각형이라 모서리가 테두리를 파고들었다)
const BAR_PAD := 3.0
const BAR_RADIUS := 8
const MANA_RADIUS := 2                   # HP 바 아래 마나 바 (높이 4 → 알약 모양)
static var _bar_box: StyleBoxFlat
static var _fill_box: StyleBoxFlat       # 채움·잔상·광택 공용 (그리기 직전에 색·모서리를 바꿔 쓴다. draw 는 그 순간 값으로 굽는다)
static var _kick_box: StyleBoxFlat       # 피격 순간 바 둘레 흰 테
static var _badge_box: StyleBoxFlat
var drawn_heal := -1.0                   # 마지막으로 바를 그릴 때 쓴 회복빛 (테스트 확인용)


static func _ensure_boxes() -> void:
	if _bar_box == null:
		_bar_box = StyleBoxFlat.new()
		_bar_box.bg_color = BAR_INK
		_bar_box.set_corner_radius_all(BAR_RADIUS)
		_bar_box.corner_detail = 12
		_fill_box = StyleBoxFlat.new()
		_fill_box.corner_detail = 12
		_kick_box = StyleBoxFlat.new()
		_kick_box.draw_center = false
		_kick_box.set_border_width_all(2)
		_kick_box.set_corner_radius_all(BAR_RADIUS + 2)
		_kick_box.corner_detail = 12
		_badge_box = StyleBoxFlat.new()
		_badge_box.bg_color = BADGE_GOLD
		_badge_box.border_color = Color("8a5a12")
		_badge_box.set_border_width_all(1)
		_badge_box.set_corner_radius_all(6)


## HP 바 안쪽 칸(bar)을 왼쪽부터 ratio 만큼 col 로 채운다. 왼쪽 끝은 늘 안쪽 반지름으로 둥글고, 오른쪽 끝은
## 채움이 오른쪽 모서리 곡선 구간에 들어설수록 그만큼 둥글어진다 (중간에서 끊긴 채움은 곧게 잘린다).
## 반지름이 폭의 절반보다 크면 StyleBoxFlat 이 알아서 줄이므로 아주 짧은 채움도 칸 밖으로 삐져나가지 않는다.
## r_in: 칸 안쪽 모서리 반지름 (HP 바 = BAR_RADIUS - BAR_PAD, 마나 바 = 2).
static func _bar_fill(o: CanvasItem, bar: Rect2, ratio: float, col: Color, r_in := int(BAR_RADIUS - BAR_PAD)) -> void:
	var w := bar.size.x * clampf(ratio, 0.0, 1.0)
	if w <= 0.25:
		return
	var r_right := clampi(roundi(r_in - (bar.size.x - w)), 0, r_in)
	_fill_box.bg_color = col
	_fill_box.corner_radius_top_left = r_in
	_fill_box.corner_radius_bottom_left = r_in
	_fill_box.corner_radius_top_right = r_right
	_fill_box.corner_radius_bottom_right = r_right
	o.draw_style_box(_fill_box, Rect2(bar.position, Vector2(w, bar.size.y)))


## 이름 + HP 바. 비주얼 위쪽 끝(_top) 기준.
func _draw_overlay() -> void:
	var o := _overlay
	_ensure_boxes()
	o.draw_string(VDData.font(), Vector2(-70.0, _top - 8.0), display_name, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 14, Color(1, 1, 1, 0.95))
	var bw := BAR_W if (size == 1 and not is_boss) else BAR_W_BIG
	var kick := Vector2(sin(Time.get_ticks_msec() * 0.09) * 3.0, -2.0) * _bar_kick
	var bar := Rect2(Vector2(-bw * 0.5, _top - 24.0 - BAR_H) + kick, Vector2(bw, BAR_H))
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	if show_bar:
		o.draw_style_box(_bar_box, bar.grow(BAR_PAD))
		var hp_col := hp_tint(ratio, BAR_HERO) if team == 0 else BAR_ENEMY
		if _hp_ghost > _hp_shown:
			# 잔상: 방금 깎인 만큼 띠 (처음엔 흰색으로 번쩍, 곧 주황으로 일정하게 줄어든다)
			_bar_fill(o, bar, _hp_ghost, ghost_col(_ghost_hold))
		_bar_fill(o, bar, _hp_shown, hp_col.lerp(Color(0.85, 1.0, 0.85), _heal_glow * 0.8))
		drawn_heal = _heal_glow
		# 광택: 위쪽 가는 흰 띠 (채움 폭만큼, 둥근 끝이 채움 안쪽에 들어오게 양옆을 모서리 반지름만큼 비운다)
		var r_in := float(BAR_RADIUS) - BAR_PAD
		var gw := bw * _hp_shown - r_in * 2.0
		if gw > 1.0:
			_fill_box.bg_color = BAR_GLOSS
			_fill_box.set_corner_radius_all(1)
			o.draw_style_box(_fill_box, Rect2(bar.position + Vector2(r_in, 1.5), Vector2(gw, 3.0)))
		if _bar_kick > 0.6:
			_kick_box.border_color = Color(1, 1, 1, (_bar_kick - 0.6) * 1.5)
			_kick_box.set_border_width_all(2)
			_kick_box.set_corner_radius_all(BAR_RADIUS + 2)
			o.draw_style_box(_kick_box, bar.grow(BAR_PAD + 2.0))
		if team == 0 and level > 0:
			# 레벨 배지: 바 왼쪽에 금색 알약 "Lv.N" (TrioChess 영웅 바의 레벨 배지)
			var badge := Rect2(bar.position + Vector2(-34.0, -4.0), Vector2(28.0, 20.0))
			o.draw_style_box(_badge_box, badge)
			o.draw_string(VDData.font(), badge.position + Vector2(0, 14.5), "Lv%d" % level, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 11, Color(0.2, 0.1, 0.02))
	if shield > 0.0:
		# 보호막: HP 바 위에 겹치는 하늘색 띠
		o.draw_rect(Rect2(bar.position + Vector2(0, -5.0), Vector2(bw * clampf(shield / max_hp, 0.0, 1.0), 3.0)), Color(0.6, 0.95, 1.0))
	if burn_timer > 0.0:
		# 과열(2026-11-09 사이파이, 예전 화상 불꽃 점): 몸 옆에서 깜빡이는 붉은 경고 삼각형 둘
		var bt := Time.get_ticks_msec() * 0.001
		var on := fmod(bt * 4.0, 1.0) < 0.65
		for i in 2:
			var c := Vector2(-16.0 + 32.0 * i, _top * 0.5 - 4.0 * i)
			var tri := PackedVector2Array([c + Vector2(0, -6.0), c + Vector2(6.0, 5.0), c + Vector2(-6.0, 5.0)])
			o.draw_colored_polygon(tri, Color(1.0, 0.35, 0.4, 0.9 if on else 0.35))
			o.draw_line(c + Vector2(0, -2.5), c + Vector2(0, 1.5), Color(0.15, 0.02, 0.05, 0.9), 1.5)
	if slow_timer > 0.0:
		# 정지장(예전 얼음 고리): 발밑 납작한 점선 링이 천천히 돈다
		var st := Time.get_ticks_msec() * 0.0008
		for i in 8:
			var a0 := st + TAU * i / 8.0
			var pts := PackedVector2Array()
			for j in 5:
				var a := a0 + 0.45 * j / 4.0
				pts.append(Vector2(cos(a) * 24.0, -6.0 + sin(a) * 10.0))
			o.draw_polyline(pts, Color(0.35, 0.95, 1.0, 0.8), 2.0)
	if mana_gain > 0.0:
		# 마나 바 (HP 바 바로 아래). 가득 차면 밝게 빛난다.
		# 바탕·채움·READY 테두리 모두 같은 중심의 둥근 끝 (HP 바와 같은 모양 규칙)
		var mb := Rect2(bar.position + Vector2(0, BAR_H + 4.0), Vector2(bw, 4.0))
		_bar_fill(o, mb, 1.0, Color(0, 0, 0, 0.6), MANA_RADIUS)
		var full := mana >= VDData.MAX_MANA
		_bar_fill(o, mb, mana / VDData.MAX_MANA, Color(0.55, 0.85, 1.0) if full else Color(0.25, 0.5, 1.0), MANA_RADIUS)
		if full:
			# READY: 막 찼을 때 바가 크게 번쩍 → 이후 은은하게 숨쉰다 + 머리 위 작은 별
			var pop := clampf(1.0 - _ready_t * 2.5, 0.0, 1.0)
			var breathe := 0.35 + 0.25 * sin(_ready_t * 6.0)
			var g := 1.0 + 3.0 * pop
			_kick_box.border_color = Color(1.0, 0.95, 0.6, maxf(pop, breathe * 0.6))
			_kick_box.set_border_width_all(roundi(1.5 + pop * 2.0))
			_kick_box.set_corner_radius_all(MANA_RADIUS + roundi(g))
			o.draw_style_box(_kick_box, mb.grow(g))
			var sy := _top - 52.0 - 6.0 * pop + sin(_ready_t * 4.0) * 2.0
			var sr := 6.0 + 6.0 * pop
			o.draw_colored_polygon(PackedVector2Array([Vector2(0, sy - sr), Vector2(sr * 0.3, sy - sr * 0.3), Vector2(sr, sy), Vector2(sr * 0.3, sy + sr * 0.3), Vector2(0, sy + sr), Vector2(-sr * 0.3, sy + sr * 0.3), Vector2(-sr, sy), Vector2(-sr * 0.3, sy - sr * 0.3)]), Color(1.0, 0.95, 0.6, 0.9))
	if guard_timer > 0.0:
		# 가드: 몸을 감싸는 푸른 방패 고리
		var ga := clampf(guard_timer, 0.0, 0.5) * 2.0
		var gr := Vector2(0, _top * 0.5)
		o.draw_arc(gr, absf(_top) * 0.55, 0.0, TAU, 40, Color(0.55, 0.8, 1.0, 0.55 * ga), 3.0)
	if armor > 0.0 and _flash > 0.0:
		o.draw_arc(Vector2(0, _top * 0.5), absf(_top) * 0.6, 0.0, TAU, 40, Color(0.55, 0.8, 1.0, _flash * 0.65), 2.5, true)
	if stun_timer > 0.0 and not frozen and air_timer <= 0.0:
		# 기절(2026-11-09 사이파이, 예전 도는 별): 머리 위를 도는 사각 픽셀 셋이 계단식으로 깜빡인다 (시스템 오류 느낌)
		var tt := Time.get_ticks_msec() * 0.006
		var flick := int(Time.get_ticks_msec() / 90) % 3
		for i in 3:
			var a := tt + TAU * i / 3.0
			var c := Vector2(cos(a) * 18.0, _top - 40.0 + sin(a) * 6.0)
			o.draw_rect(Rect2(c - Vector2(3.5, 3.5), Vector2(7.0, 7.0)), Color(1.0, 0.95, 0.45) if i != flick else Color(0.4, 1.0, 1.0))


## 넉백: 바라보는 방향은 그대로 두고 c 로 빠르게 밀려난다 (감속).
func knockback_to(c: Vector2i, dur := 0.16) -> void:
	cell = c
	if _move_tween:
		_move_tween.kill()
	moving = true
	_move_tween = create_tween()
	_move_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_move_tween.tween_property(self, "position", foot_at(c), dur)
	_move_tween.finished.connect(func() -> void: moving = false)


# ---------------------------------------------------------------- 이름·HP 바 최상위

func _enter_tree() -> void:
	_lift_overlay()


func _exit_tree() -> void:
	if _overlay and _overlay.get_parent() != self:
		_overlay.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_overlay) and _overlay.get_parent() != self:
		_overlay.queue_free()


## 이름·HP 바를 top_root(안개 위 월드 레이어)로 옮긴다. 위치·보이기·투명도는 _sync_overlay 가 매 프레임 맞춘다.
func _lift_overlay() -> void:
	if _overlay == null or not is_instance_valid(top_root) or not top_root.is_inside_tree():
		return
	if _overlay.get_parent() == top_root:
		return
	if _overlay.get_parent():
		_overlay.get_parent().remove_child(_overlay)
	_overlay.z_as_relative = true
	_overlay.z_index = 0
	top_root.add_child(_overlay)
	_sync_overlay()


func _sync_overlay() -> void:
	if _overlay == null or _overlay.get_parent() == self:
		return
	_overlay.global_position = global_position
	_overlay.visible = is_visible_in_tree() and not _airborne
	# 투명도만 따라간다 (사망 페이드·순간이동). 색은 따라가지 않는다: 궁극기·스킬 딤드(modulate 어둡게)가 HP 바까지 어둡게 하지 않게
	_overlay.modulate = Color(1.0, 1.0, 1.0, modulate.a)


## 피해 숫자·상태 글자가 나오는 자리: HP 바 위쪽 끝 (보호막 띠 위) — 월드 좌표
func bar_top() -> Vector2:
	return global_position + Vector2(0, _top - 24.0 - BAR_H - 8.0)
