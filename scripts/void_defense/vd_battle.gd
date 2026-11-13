## VOID DEFENSE 그레이박스 프로토타입 — 절차 생성 맵을 전진하며 싸우는 전투 루프.
##   PLACEMENT(현재 방 입구 쪽 4열에서 드래그 배치) → [배치 완료 / Space] → SPAWNING("치료 시작") → BATTLE(실시간 자동전투)
##   → 적 전멸: TRANSITION(그 자리에서 회복·정수 회수, 출구 생성 — 진형은 다음 방 도착 때 잡는다)
##   → CHOOSE_PATH(갈림길이면 플레이어가 길 선택, 외길이면 자동) → TRAVEL(복도를 따라 다음 방으로 이동)
##   → 다음 방에서 저장된 진형으로 자리 잡고 PLACEMENT (전투는 다시 플레이어가 시작)
##   → 아군 전멸: GAMEOVER(다시 도전)
class_name VDBattle
extends Node2D

signal wave_cleared(wave: int)          # 스테이지(방)의 마지막 웨이브까지 전멸 = 구역 클리어
signal subwave_cleared(wave: int)       # 스테이지 안 웨이브 하나 전멸 (마지막이 아닌 것)
signal game_over(wave: int)
signal state_changed(state: int)
signal champion_spawned(unit: VDUnit)   # 웨이브의 강적이 (맨 마지막에) 내려앉기 시작함

enum State { PLACEMENT, SPAWNING, BATTLE, TRANSITION, CHOOSE_PATH, TRAVEL, GAMEOVER }

const WAVE_HEAL := 50.0
const SPORE_FLIGHT_SEC := 0.34
const WRAITH_FLIGHT_SEC := 0.3   # 공허 망령 구체 비행 시간
const SHELL_FLIGHT_SEC := 0.42   # 공허 망루 포탄 비행 시간
const TRAVEL_SEC_PER_TILE := 0.11
const BATTLE_ZOOM := 1.18      # 전투(적 등장~전멸) 동안 카메라 줌인 배율
const ZOOM_IN_SEC := 0.7
const ZOOM_OUT_SEC := 0.45
## 구역 클리어 연출 타임라인 (실제 시간, 초). 한꺼번에 몰리지 않게 한 박자씩 띄운다:
##   마지막 처치(1초 슬로모션 + 처치 지점 줌인) → 배너 → 회복(아군별로 차례) → 배너가 빠진 뒤 유물 보상 → 새 길이 솟아오름
const CLEAR_SLOWMO := [1.0, 0.15]    # 구역의 마지막 적: 클리어 슬로모션 [초, 배율] (2026-11-09 2초 → 1초로 절반)
const FINALE_SLOWMO := [2.0, 0.15]   # 거점 함락(패배): 가장 긴 슬로모션 [초, 배율]
const FINALE_ZOOM := 1.32            # 마지막 처치 지점으로 줌인
const CLEAR_BANNER_AT := 0.7         # 마지막 처치 → "치료 성공" 배너 (슬로모션이 풀리기 시작할 무렵, 슬로모션의 70%)
const CLEAR_BANNER_HOLD := 1.8
const CLEAR_COLLECT_AT := 0.5       # 배너 → 바닥의 정수가 HUD 로 빨려 들어가기 시작
const CLEAR_HEAL_AT := 1.1           # 배너 → 회복 시작
const CLEAR_HEAL_GAP := 0.22         # 아군 한 명씩 회복되는 간격
const CLEAR_REWARD_GAP := 0.35       # 배너가 빠진 뒤 → 유물 보상
const CLEAR_EXITS_AT := 1.0          # 유물 보상 → 새 길이 솟아오름
const ARRIVE_BREATH := 0.6           # 새 구역 도착 → 적 소환 시작
const BATTLE_START_SEC := 0.9        # "치료 시작" 배너 → 실제 전투
## 궁극기 뒤 어두운 무대를 유지하는 시간(초): 스킬 이펙트가 끝날 무렵까지 (TrioChess: 기본 1.1)
const ULT_HOLD := {"knight": 0.9, "gunner": 0.9, "mage": 1.1, "healer": 1.0}
## 치명타 (아군 평타): 확률·배율. 치명타는 큰 숫자 + 짧은 히트스탑 + 줌 펀치 + CRITICAL! 글자.
const CRIT_CHANCE := 0.15
const CRIT_MULT := 1.6
## 적 공격 예비 동작(게임 시간, 초): 움츠리며 달아오른 뒤 때린다. 보스·망루는 대상 발밑에 경고도 띄운다.
const WINDUP := {"normal": 0.16, "fast": 0.1, "skirmisher": 0.2, "tank": 0.24, "crab": 0.3, "wraith": 0.34, "longneck": 0.4, "boss": 0.36, "watcher": 0.38, "gazer": 0.42}

var state: State = State.PLACEMENT
## 진행 (TrioChess 무리 → 서브웨이브 이식): stage = 몇 번째 방, wave_in_stage = 그 방의 몇 번째 웨이브, wave = 누적 웨이브(난이도).
var wave := 1
var stage := 1
var wave_in_stage := 1
var gimmick := ""              # 이번 스테이지의 기믹 무리 id ("" 없음)
var gimmick_wave := 0          # 기믹 무리가 나오는 웨이브 순서
var wave_mult := 1.0           # 현재 웨이브의 적 배율 (분열 소잔재 등 뒤늦게 생기는 적이 쓴다)
var wave_atk_mult := 1.0       # 현재 웨이브의 적 공격력 배율 (VDData.atk_scaling: 체력보다 완만한 선형)
var _sub_pending := false     # 다음 웨이브가 내려앉는 중 (그 사이 전멸 판정 금지)
var essence := 0
var allies: Array[VDUnit] = []
var enemies: Array[VDUnit] = []
var map: VDMap
var room := {}                 # 현재 전투 방
var formation := {}            # hero id -> 방 로컬 (a, c). 배치 완료 시 저장, 다음 방에서 재사용
var exits: Array = []          # 현재 갈림길 후보

var board: VDBoard
var tile_glitch: VDTileGlitch
var props: VDProps
var units_root: Node2D
var fx_root: Node2D
const GAME_SPEEDS := [1.0, 1.5, 2.0]   # 속도 버튼이 차례로 바꾸는 배속
var camera: VDCamera
var nebula_tuner: VDNebulaTuner
var background_theme: int = VDWorldTheme.Kind.DESERT
var _background_material: ShaderMaterial
var _fog_material: ShaderMaterial
var _fog_layer: CanvasLayer     # 앞 안개 레이어(5)
var _reveal_layer: CanvasLayer  # 입장 연출 덧판(VDFogReveal) 레이어(7): 유닛 이름·HP 바(6)까지 덮고 HUD(10) 아래
var fog_reveal: VDFogReveal     # 입장 연출이 도는 동안만 (끝나면 스스로 지워진다)
var audio: VDAudio
var vfx: VDVfx
var ground_fx: Node2D          # 바닥 이펙트(포털·마법진·먼지): 보드 위, 유닛 아래
var dmg_log: VDDamageLog       # 피해 숫자: 헥스 블레이드 DamageLog 이식(ARCO 글꼴·팝·포물선·연타 열기)
var world_top: Node2D           # 안개 위 월드 레이어 (HP 바 · 피해 숫자 · 팝 글자)
var skills: VDSkills          # 고유 스킬 시전 (마나가 차면 자동, 전투는 멈추지 않는다)
var ults: VDUlts              # 궁극기 시전 (게이지가 차면 플레이어가 카드를 탭)
var ult_aim                   # 궁극기 조준 화면 (VDUltAim: 카드 → 필드 화살표)
var fallen: Array[VDUnit] = []   # 쓰러진 순서 (힐러 궁극기 부활 대상)
var auto_ult := false         # 테스트: 궁극기가 차면 자동 조준으로 바로 쓴다
var float_move: VDFloatMove       # 떠다니는 적(공허 망령)의 타일 없는 위빙 이동
var parry: VDParry                # 보스 패링 공격: 예고 → 노려진 영웅의 궁극기 키로 받아치기
var enemy_skills: VDEnemySkills   # 적 특수 스킬 (재사용 대기가 차면 자동: 망루 레이저 · 군주 순간이동 강하)
var tactics: VDTactics            # 역할별 전투 AI: 누구를 노리고 어디로 걸을지 (가로막기·거리 유지·측면 침투·돌격)
var impact: VDImpact              # 칸 물리·위치 보너스: 넉백·벽꿍·충돌, 측면·후방 일격
var flow: VDFlow                  # 전투 흐름의 굴곡: 증원·공허 오염 바닥·공허 파편 도약
var relic_board: VDRelicBoard  # 유물 성좌판 상태 (칸·유물·보관함)
var relics: VDRelicRuntime     # 유물 발동기 (전투 이벤트 → 효과)
var relic_hud: VDRelicHud      # 성좌판 HUD (드래그 배치·보상 선택)
var banner: VDBanner            # 화면 가운데 띠 배너 ("치료 성공" · "치료 시작")
var essence_drops: VDEssenceDrops   # 공허 정수: 전투 중 바닥에 흩뿌려졌다가 클리어 때 HUD 로 빨려 들어간다 (TrioChess 동전)
var goo: VDGoo                     # 몬스터 체액: 처치 자리 바닥에 둥근 체액 덩어리가 남는다
var ult: VDUltCinematic          # 궁극기 시전 연출 (TrioChess Cinematic)
var sandbox: VDSandbox = null       # 전투 연습장 (연출 연구실에서 열면): 고른 영웅만, 웨이브·보상·게임 오버 없이 반복
static var sandbox_request: Array = []   # 연출 연구실이 씬을 바꾸기 전에 넣는 영웅 목록 (비어 있으면 보통 전투)
var bg_rect: ColorRect          # 선택한 테마의 배경 (궁극기 연출이 어둡게 한다)
var hud_root: Control           # HUD 최상위 (날아가는 정수 아이콘이 붙는다)
var _essence_icon: TextureRect  # 정수 표시 옆 아이콘 = 흡수 목표
var turntable: VDTurntable     # 좌측 하단 캐릭터 턴테이블
var juice: VDJuice              # 손맛 연출 모음 (경고·꼬리·그을음·콤보·팝 글자)
var shockwave                  # 화면 쇼크웨이브 (VDShockwave): 맞은 자리에서 화면이 둥글게 일렁인다
var _boss_ghost: ProgressBar    # 보스 HP 잔상 바 (보스 바 뒤에서 늦게 따라 내려온다)
var _boss_ghost_hold := 0.0
var _wave_bar                    # VDStageProgress: 상단 가운데 스테이지 진행도 (PSD 진행도 바)
var _wave_from := 0              # enemies 중 지금 웨이브가 시작되는 인덱스 (그 뒤로 붙는 분열·증원도 이 웨이브)
var _wave_plan := 0.0            # 지금 웨이브에 내려앉을 적들의 계획된 총 체력 (내려앉는 동안 바가 차오르게)
var _landing := false            # 전투 중 다음 웨이브가 내려앉는 중 (진행도 바가 그 구획을 꽉 찬 채로 둔다)
var _gray: ColorRect            # 게임 오버: 전장이 흑백으로 바랜다
var _over_title: Label
var _over_stats: Label
var _btn_retry: Button

var _dragging: VDUnit = null
var _spawning := false          # 적 등장 연출 진행 중 (배치 완료 버튼 잠금)
var _pending_start := false     # 등장 중에 배치 완료를 눌렀으면 끝나고 시작
var _run_id := 0               # 재시작 시 진행 중이던 코루틴을 무효화
var _cam_target := Vector2.ZERO   # 방 중심 (이동 중에는 분대 중심). 전투 중 포커스는 focus 가 정한다
const VDCombatFocus := preload("res://scripts/void_defense/vd_combat_focus.gd")
const VDBattleFrame := preload("res://scripts/void_defense/vd_battle_frame.gd")
const VDUltAim := preload("res://scripts/void_defense/vd_ult_aim.gd")
const VDMainButton := preload("res://scripts/void_defense/vd_main_button.gd")
const VDHurtGlitch := preload("res://scripts/void_defense/vd_hurt_glitch.gd")
const VDGlitchTuner := preload("res://scripts/void_defense/vd_glitch_tuner.gd")
const VDShockwave := preload("res://scripts/void_defense/vd_shockwave.gd")
const VDScreenGlitch := preload("res://scripts/void_defense/vd_screen_glitch.gd")
const VDGrowth := preload("res://scripts/void_defense/vd_growth.gd")
const VDGimmicks := preload("res://scripts/void_defense/vd_gimmicks.gd")
const VDSkillWindow := preload("res://scripts/void_defense/vd_skill_window.gd")
const HitFx := preload("res://scripts/void_defense/vd_hit_fx.gd")     # 몬스터 피격 화면 반응 배율 (연출 연구실)
const CartoonHit := preload("res://scripts/void_defense/vd_cartoon_hit_fx.gd")   # 카툰 몬스터 피격 파티클 (연출 연구실 "몬스터 피격 · 카툰")
const KillFx := preload("res://scripts/void_defense/vd_kill_fx.gd")   # 몬스터 사망 연출 (연출 연구실 "몬스터 사망")
const VDStageProgress := preload("res://scripts/void_defense/vd_stage_progress.gd")   # 스테이지 진행도 (웨이브 구획 + 몬스터 전체 체력)
var growth                     # 영웅 성장 (VDGrowth): 처치 경험치 → 레벨업 → SP → 스킬 레벨
const VDFieldGimmicks := preload("res://scripts/void_defense/vd_field_gimmicks.gd")
const VDFieldLook := preload("res://scripts/void_defense/vd_field_look.gd")   # 필드 색 보정 (로비 → 필드 연구실)
var field                      # 필드 기믹 (VDFieldGimmicks): 증폭 패널 · 방전 격자. ground_fx 의 자식
var gimmicks                   # 기믹 무리 행동 (VDGimmicks): 암살자 도약·추적자 질주·분열·촉수 부활·환영 무적
var skill_window               # 캐릭터 스킬창 (VDSkillWindow, 시안 PSD): 배치 단계에 분대 카드를 누르면 열린다
var hurt_glitch: VDHurtGlitch   # 아군 피격 때 HUD 그림 테두리가 가로로 뾰족하게 튀는 카툰 글리치
var glitch_tuner: VDGlitchTuner
var parry_impact: VDParryImpact     # 패링 충돌 화면 연출: 방사형 블러·색수차·집중선 + PARRY! 타이포
var screen_glitch: VDScreenGlitch   # 아군 피격·성좌판 침식 때 화면 전체가 가로로 찢어지며 청록/자홍으로 갈라지는 글리치
var focus := VDCombatFocus.new()   # 전투 카메라: 치열한 곳을 부드럽게 따라가며 살짝 줌인/아웃
var _cam_clock_us := 0
var _zoom_tween: Tween
var _essence_at_start := 0      # 이번 구역 전투 시작 때 정수 (클리어 배너 부제에 획득량 표시)

# HUD
var _lbl_wave: Label
var _lbl_msg: Label
var _lbl_essence: Label
var _lbl_boss: Label
var _boss_bar: ProgressBar
var _btn_main: VDMainButton    # 배치 완료(Space) / 진행 상태 표시
var _btn_speed: Button
var _path_box: HBoxContainer
var frame: VDBattleFrame        # 시안 HUD 틀: 상단 바·하단 패널(라바램프)·분대 카드·아이템 슬롯 (VDBattleFrame)
var _over_panel: Control
var _lbl_over: Label
var _msg_tween: Tween


func _exit_tree() -> void:
	# 궁극기 연출·조준 중에 씬을 떠나면 그 코루틴이 다시 돌지 않는다: 멈춘 트리를 남기지 않는다 (연구실 전투 연습장 포함)
	get_tree().paused = false


func _ready() -> void:
	randomize()
	print("[VD] VoidDefense ready (main_scene=%s)" % ProjectSettings.get_setting("application/run/main_scene"))
	audio = VDAudio.new()
	add_child(audio)
	skills = VDSkills.new(self)
	ults = VDUlts.new(self)
	enemy_skills = VDEnemySkills.new(self)
	parry = VDParry.new(self)
	add_child(parry)
	float_move = VDFloatMove.new(self)
	tactics = VDTactics.new(self)
	impact = VDImpact.new(self)
	flow = VDFlow.new(self)
	growth = VDGrowth.new(self)
	growth.leveled.connect(_on_leveled)
	gimmicks = VDGimmicks.new(self)
	essence_drops = VDEssenceDrops.new(self)
	goo = VDGoo.new(self)
	juice = VDJuice.new(self)
	add_child(juice)
	relic_board = VDRelicBoard.new()
	relics = VDRelicRuntime.new(self, relic_board)
	_build_world()
	field = VDFieldGimmicks.new()
	field.name = "FieldGimmicks"
	field.b = self
	ground_fx.add_child(field)
	_build_hud()
	if not sandbox_request.is_empty():
		sandbox = VDSandbox.new(self, sandbox_request.duplicate())
		sandbox_request.clear()   # 한 번만: 로비에서 다시 들어오면 보통 전투
		add_child(sandbox)
	_new_run()
	if get_tree().current_scene == self:
		play_intro()   # 로비·연구실에서 들어왔을 때만. 테스트 러너(자식으로 붙임)는 필요하면 직접 부른다


## 전투 입장 연출 (2026-11-09): 코믹 파편 전환의 가운데 구멍이 다 열리면(SceneSwitcher.intro_lead() 뒤) 화면 전체를 덮은
## 하프톤 안개(배경 조정 패널의 저장값)가 중앙에서
## 타원으로 열리며 전장이 드러나고(VDFogReveal, 유닛 HP 바 층 위·HUD 아래의 레이어 7), 구멍이 화면 가장자리에 닿을 즈음
## HUD 조각들이 시각적 위계대로 각자의 방향에서 들어온다:
##   상단 바·명판(위) → 하단 띠·우측 뒷패널 → 분대 카드 한 장씩(아래) → 진행 표시·배속·턴테이블(왼쪽) →
##   웨이브 바·정수(위) → 성좌판(오른쪽) → 마지막에 가운데 큰 버튼(아래)이 올라와 톡 튄다.
const INTRO_FOG_DELAY := 0.25   # 전환 없이 바로 들어왔을 때: 다 덮인 안개가 잠깐 보인 뒤 열린다
const INTRO_FOG_AFTER_WIPE := 0.05   # 코믹 파편 전환 뒤: 구멍이 열리자마자 안개가 이어서 열린다
const INTRO_HUD_T0 := 0.85      # 첫 HUD 조각이 움직이기 시작하는 시각 (안개 구멍이 가운데를 다 열고 가장자리로 번질 때)


func play_intro() -> void:
	if is_instance_valid(fog_reveal):
		fog_reveal.queue_free()
	var aspect := bg_rect.size.x / maxf(bg_rect.size.y, 1.0)
	var lead := SceneSwitcher.intro_lead()
	var fog_delay := lead + (INTRO_FOG_AFTER_WIPE if lead > 0.0 else INTRO_FOG_DELAY)
	fog_reveal = VDFogReveal.play(_reveal_layer, nebula_tuner.halftone_params(), aspect, fog_delay)
	var t0 := fog_delay + (INTRO_HUD_T0 - INTRO_FOG_DELAY)
	var cards_done := frame.play_intro(t0)
	UIIntro.stagger([_lbl_wave, _btn_speed], UIIntro.FROM_LEFT, t0 + 0.15, 0.08, 0.45, 120.0)
	UIIntro.slide(turntable, UIIntro.FROM_LEFT, t0 + 0.25, 0.65, 320.0, true, UIIntro.Ease.QUINT)
	UIIntro.slide(_wave_bar, UIIntro.FROM_TOP, t0 + 0.3, 0.5, 110.0)
	UIIntro.slide(_lbl_essence, UIIntro.FROM_TOP, t0 + 0.38, 0.45, 90.0)
	UIIntro.slide(relic_hud.backdrop, UIIntro.FROM_RIGHT, t0 + 0.4, 0.6, 260.0, true, UIIntro.Ease.QUINT)
	UIIntro.slide(relic_hud, UIIntro.FROM_RIGHT, t0 + 0.48, 0.55, 220.0)
	var main_tw := UIIntro.slide(_btn_main, UIIntro.FROM_BOTTOM, cards_done - 0.15, 0.5, 160.0)
	main_tw.finished.connect(func() -> void: _btn_main.bump(1.2))


# ---------------------------------------------------------------- build

func _build_world() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	# 배경/앞 안개의 재질 객체는 유지하고, 아래에서 저장된 테마의 셰이더를 적용한다.
	var bg := ColorRect.new()
	bg_rect = bg
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_mat := ShaderMaterial.new()
	_background_material = bg_mat
	bg_mat.shader = load("res://shaders/void_nebula.gdshader")
	bg.material = bg_mat
	bg_layer.add_child(bg)

	props = VDProps.new()
	add_child(props)
	add_child(props.back)        # 바닥 뒤 프랍: 보드보다 먼저
	board = VDBoard.new()
	add_child(board)
	# 타일 글리치: 보드 위·바닥 이펙트 아래 (의뢰인의 마음을 옮긴 디지털 세계 — 타일이 가끔 치지직거린다)
	tile_glitch = VDTileGlitch.new()
	tile_glitch.board = board
	add_child(tile_glitch)
	SceneSwitcher.add_choice_setting(self, "타일 글리치  (F4)", VDTileGlitch.LABELS,
		func() -> int: return VDTileGlitch.selected, tile_glitch.set_style)
	SceneSwitcher.add_setting(self, "바닥 기억 로그", tile_glitch.toggle_log, tile_glitch.is_log_on)
	ground_fx = Node2D.new()
	ground_fx.name = "GroundFx"
	add_child(ground_fx)
	units_root = Node2D.new()
	units_root.y_sort_enabled = true
	add_child(units_root)
	add_child(props.front)       # 바닥 앞 프랍: 유닛 위
	fx_root = Node2D.new()
	fx_root.z_index = 50
	add_child(fx_root)
	vfx = VDVfx.new()
	add_child(vfx)

	camera = VDCamera.new()
	camera.position_smoothing_enabled = false   # 부드러움은 focus(smooth damp)가 맡는다 — 두 번 거르면 굼떠진다
	camera.bg_material = bg_mat
	add_child(camera)
	camera.make_current()
	ult = VDUltCinematic.new(self)
	VDUltCinematic.SuperCutin.prewarm()   # 컷인 첫 프레임이 끊기지 않게 텍스처를 미리 읽는다

	# 화면 쇼크웨이브: 월드를 다 그린 화면을 읽어 비튼다 (앞 안개·HUD 는 비틀지 않는다)
	shockwave = VDShockwave.new()
	add_child(shockwave)
	SceneSwitcher.add_setting(self, "쇼크웨이브", shockwave.toggle, shockwave.is_on)
	shockwave.struck.connect(func(at: Vector2, kind: String, k: float) -> void:
		essence_drops.blast(_floor_under(at), kind, k)
		tile_glitch.on_struck(_floor_under(at), kind, k))

	# 앞 안개/모래바람: 월드 위, HUD 아래. 전장 가장자리의 분위기를 만든다.
	var fog_layer := CanvasLayer.new()
	fog_layer.layer = 5
	add_child(fog_layer)
	_fog_layer = fog_layer
	var fog := ColorRect.new()
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	_fog_material = mat
	mat.shader = load("res://shaders/void_vignette.gdshader")
	fog.material = mat
	fog_layer.add_child(fog)
	# 안개 위 월드 레이어: 유닛 이름·HP 바와 전투 글자(피해 숫자·팝 글자)를 여기에 그려 유닛·이펙트·안개에 가리지 않게.
	# 카메라(줌·흔들림)를 그대로 따라가므로 좌표는 월드 그대로다. HUD(10) 아래.
	var top_layer := CanvasLayer.new()
	top_layer.layer = 6
	top_layer.follow_viewport_enabled = true
	add_child(top_layer)
	world_top = Node2D.new()
	world_top.name = "WorldTop"
	top_layer.add_child(world_top)
	VDUnit.top_root = world_top
	_reveal_layer = CanvasLayer.new()
	_reveal_layer.layer = 7
	add_child(_reveal_layer)
	# 셰이더 기본 aspect 는 16:9 라서 화면 비율이 바뀌면(울트라와이드 등) 무늬가 늘어난다. 실제 비율을 넣어 준다.
	var fit_aspect := func() -> void:
		var ar := bg.size.x / maxf(bg.size.y, 1.0)
		bg_mat.set_shader_parameter("aspect", ar)
		mat.set_shader_parameter("aspect", ar)
	bg.resized.connect(fit_aspect)
	fit_aspect.call()
	# 배경 조정 패널: 공허 배경(모양·속도·컬러)과 앞 안개를 실시간으로 (앞 안개 색도 배경 컬러를 따라간다)
	nebula_tuner = VDNebulaTuner.new()
	nebula_tuner.style_setter = set_fog_style
	set_background_theme(VDWorldTheme.load_selected(), false)
	var tuner_layer := CanvasLayer.new()
	tuner_layer.layer = 20
	add_child(tuner_layer)
	tuner_layer.add_child(nebula_tuner)
	SceneSwitcher.add_choice_setting(self, "배경 테마", VDWorldTheme.LABELS,
		func() -> int: return background_theme, set_background_theme)
	SceneSwitcher.add_choice_setting(self, "앞 안개 스타일", VDWorldTheme.FOG_LABELS,
		func() -> int: return VDWorldTheme.fog_style, set_fog_style)
	SceneSwitcher.add_setting(self, "배경 조정  (F10)", nebula_tuner.toggle, nebula_tuner.is_open)


## 전투/방/카메라를 재시작하지 않고 타일·배경·앞 안개·유적 프랍을 한 번에 바꾼다.
func set_background_theme(value: int, persist := true) -> void:
	if value not in [VDWorldTheme.Kind.VOID, VDWorldTheme.Kind.DESERT]:
		return
	background_theme = value
	VDWorldTheme.select(value, persist)
	board.set_theme(value)
	_background_material.shader = VDWorldTheme.background(value)
	_fog_material.shader = VDWorldTheme.foreground(value)
	var aspect := bg_rect.size.x / maxf(bg_rect.size.y, 1.0)
	_background_material.set_shader_parameter("aspect", aspect)
	_fog_material.set_shader_parameter("aspect", aspect)
	nebula_tuner.setup(_background_material, _fog_material, VDWorldTheme.profile(value))
	var show_ruins := value == VDWorldTheme.Kind.VOID
	props.back.visible = show_ruins
	props.front.visible = show_ruins
	apply_field_look()


## 필드 색 보정(vd_field_look.gd)을 타일·프랍·배경·앞 안개에 입힌다. 테마가 바뀌거나 필드 연구실에서 값을 바꾸면 다시 부른다.
func apply_field_look() -> void:
	if board == null or props == null:
		return
	var profile := VDWorldTheme.profile(background_theme)
	for pair in [["tile", board], ["prop_back", props.back], ["prop_front", props.front]]:
		var item: CanvasItem = pair[1]
		if item.material == null:
			item.material = VDFieldLook.new_material()
		VDFieldLook.apply(profile, pair[0], item.material)
	VDFieldLook.apply(profile, "bg", _background_material)
	VDFieldLook.apply(profile, "fog", _fog_material)
	var zone := float(VDFieldLook.effective(profile, "tile")["zone"])
	if not is_equal_approx(board.zone_k, zone):
		board.zone_k = zone
		board.queue_redraw()


## 앞 안개 스타일(기체 / 하프톤)만 바꾼다. 테마·전투 상태는 그대로, 조정 패널은 새 셰이더의 기본값·저장값을 다시 읽는다.
func set_fog_style(value: int, persist := true) -> void:
	if value not in [VDWorldTheme.FogStyle.GAS, VDWorldTheme.FogStyle.HALFTONE]:
		return
	VDWorldTheme.select_fog_style(value, persist)
	_fog_material.shader = VDWorldTheme.foreground(background_theme)
	_fog_material.set_shader_parameter("aspect", bg_rect.size.x / maxf(bg_rect.size.y, 1.0))
	nebula_tuner.setup(_background_material, _fog_material, VDWorldTheme.profile(background_theme))
	apply_field_look()


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	# HUD 전체를 CanvasGroup 하나로 그린다: 피격 글리치 셰이더가 알파가 있는 HUD 버퍼를 받아 그림의 테두리를 휜다.
	# Control 의 부모가 Node2D 면 앵커가 화면을 따라가지 않으므로 루트 크기를 보이는 화면 크기에 직접 맞춘다.
	var hud_group := CanvasGroup.new()
	hud_group.name = "HudGroup"
	hud.add_child(hud_group)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = VDData.font()
	theme.default_font_size = 20
	root.theme = theme
	hud_group.add_child(root)
	hud_root = root
	var fit_root := func() -> void: root.size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(fit_root)
	fit_root.call()
	frame = VDBattleFrame.new()
	root.add_child(frame)
	frame.setup(VDData.HERO_ORDER)
	frame.card_pressed.connect(_on_card_pressed)
	ult_aim = VDUltAim.new()
	add_child(ult_aim)
	ult_aim.setup(self, _cast_ult)
	# 피해 숫자·상태 글자는 안개 위 월드 레이어에: HP 바 위에서 튀어나와 카메라와 함께 움직인다 (HP 바 위에 그린다)
	dmg_log = VDDamageLog.new()
	dmg_log.z_index = 60
	world_top.add_child(dmg_log)
	banner = VDBanner.new()
	root.add_child(banner)
	relic_hud = VDRelicHud.new()
	root.add_child(relic_hud)
	relic_hud.setup(self, relic_board, relics)
	skill_window = VDSkillWindow.new()
	root.add_child(skill_window)
	skill_window.setup(self)
	parry_impact = VDParryImpact.new()
	add_child(parry_impact)
	SceneSwitcher.add_setting(self, "패링 충돌 화면 연출", parry_impact.toggle, parry_impact.is_on)
	screen_glitch = VDScreenGlitch.new()
	add_child(screen_glitch)
	SceneSwitcher.add_setting(self, "화면 글리치", screen_glitch.toggle, screen_glitch.is_on)
	hurt_glitch = VDHurtGlitch.new()
	add_child(hurt_glitch)
	# 맞은 영웅 카드에만 가시 + 그 카드 흔들림·피격 색 + 화면 전체 글리치 (같은 순간, 같은 세기)
	hurt_glitch.setup(hud_group, frame.glitch_targets, func(hid: String, s: float, p: Dictionary) -> void:
		frame.hit_card(hid, s, p)
		screen_glitch.kick(s, "hit"))
	hurt_glitch.prewarm.call_deferred()
	# 글리치 조정 패널 (설정 메뉴 · F9): 배경 조정 패널 오른쪽에 뜬다
	glitch_tuner = VDGlitchTuner.new()
	glitch_tuner.setup(hurt_glitch, screen_glitch)
	var glitch_layer := CanvasLayer.new()
	glitch_layer.layer = 20
	add_child(glitch_layer)
	glitch_layer.add_child(glitch_tuner)
	SceneSwitcher.add_setting(self, "글리치 조정  (F9)", glitch_tuner.toggle, glitch_tuner.is_open)
	SceneSwitcher.add_setting(self, "초궁극기 컷인 미리보기  (F8)", preview_super_cutin)
	SceneSwitcher.add_setting(self, "유물 전부 지급 (테스트)", func() -> void:
		for id in VDRelicData.RELIC_ORDER:
			relic_board.add_to_tray(id))

	# 상단 바(시안) 왼쪽 보라 띠 위: 진행 표시와 배속 버튼. 스테이지 명판(W-S)은 VDBattleFrame 이 오른쪽에 그린다
	_lbl_wave = _label(root, "", Vector2(40, 20), 24, Color(1, 1, 1))

	# 1920x1080 기준 좌표를 SceneSwitcher.pin 으로 화면 가운데·오른쪽에 붙인다(울트라와이드 대응)
	_lbl_msg = _label(root, "", Vector2(460, 222), 26, Color(1.0, 0.85, 0.42))
	SceneSwitcher.pin(_lbl_msg, Vector2(0.5, 0), Rect2(460, 222, 1000, 40))   # 스테이지 진행도·보스 바 아래
	_lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_msg.z_index = VDRelicHud.Z_DIM + 20   # 유물 칸 호버 딤 위에서도 안내가 읽히게
	# 안내 띠: 가운데가 진하고 양끝이 흐려지는 남보라 띠 + 외곽선 글자
	var msg_band := StyleBoxTexture.new()
	var band_g := GradientTexture2D.new()
	var band_gr := Gradient.new()
	band_gr.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	band_gr.colors = PackedColorArray([Color(0.08, 0.03, 0.16, 0.0), Color(0.08, 0.03, 0.16, 0.82), Color(0.08, 0.03, 0.16, 0.82), Color(0.08, 0.03, 0.16, 0.0)])
	band_g.gradient = band_gr
	band_g.width = 64
	band_g.height = 4
	msg_band.texture = band_g
	_lbl_msg.add_theme_stylebox_override("normal", msg_band)
	_lbl_msg.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.2))
	_lbl_msg.add_theme_constant_override("outline_size", 8)
	_lbl_msg.modulate.a = 0.0

	# 스테이지 진행도: 상단 가운데. 화면 컨셉_3.psd 진행도 바 (텍스처 838x125 = PSD 1676x250 의 0.44배로). 보스 바는 그 아래
	_wave_bar = VDStageProgress.new()
	SceneSwitcher.pin(_wave_bar, Vector2(0.5, 0), Rect2(591.3, 60, 737.4, 110))   # 시안처럼 위 명판 윗변이 y 78 (PSD 104/1440)
	root.add_child(_wave_bar)
	_wave_bar.visible = false

	_lbl_boss = _label(root, "", Vector2(660, 162), 22, Color(1, 0.9, 0.95))
	SceneSwitcher.pin(_lbl_boss, Vector2(0.5, 0), Rect2(660, 162, 600, 30))
	_lbl_boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 보스 바: 뒤에 잔상 바(흰→주황)를 깔고, 앞 바는 배경을 비워 잔상이 비쳐 보이게 한다
	_boss_ghost = ProgressBar.new()
	SceneSwitcher.pin(_boss_ghost, Vector2(0.5, 0), Rect2(660, 194, 600, 18))
	_boss_ghost.show_percentage = false
	_boss_ghost.add_theme_stylebox_override("fill", _flat(Color(1.0, 0.85, 0.6)))
	_boss_ghost.add_theme_stylebox_override("background", _flat(Color(0.1, 0.05, 0.15)))
	root.add_child(_boss_ghost)
	_boss_bar = ProgressBar.new()
	SceneSwitcher.pin(_boss_bar, Vector2(0.5, 0), Rect2(660, 194, 600, 18))
	_boss_bar.show_percentage = false
	_boss_bar.add_theme_stylebox_override("fill", _flat(Color(0.9, 0.2, 0.3)))
	_boss_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	root.add_child(_boss_bar)
	_boss_bar.visibility_changed.connect(func() -> void:
		_boss_ghost.visible = _boss_bar.visible
		_boss_ghost.value = _boss_bar.value)
	_lbl_boss.visible = false
	_boss_bar.visible = false

	_lbl_essence = _label(root, "", Vector2(1540, 28), 28, Color(0.85, 0.7, 1.0))
	SceneSwitcher.pin(_lbl_essence, Vector2(1, 0), Rect2(1250, 16, 240, 44))   # 스테이지 명판 왼쪽 (오른쪽 끝은 설정 버튼)
	_lbl_essence.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_essence_icon = TextureRect.new()
	_essence_icon.texture = VDEssenceGem3D.texture_for(self)   # 3D 결정 렌더 (바닥 결정과 같은 텍스처)
	_essence_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_essence_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_essence_icon.size = Vector2(40, 40)
	_essence_icon.pivot_offset = Vector2(20, 20)
	_essence_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 화이트닝: 정수가 하나 들어올 때마다 flash 를 1 로 올렸다 내려 아이콘이 하얗게 번쩍인다
	var flash_sh := Shader.new()
	flash_sh.code = "shader_type canvas_item;\nuniform float flash : hint_range(0.0, 1.0) = 0.0;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV) * COLOR;\n\tCOLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);\n}\n"
	var flash_mat := ShaderMaterial.new()
	flash_mat.shader = flash_sh
	_essence_icon.material = flash_mat
	_lbl_essence.add_child(_essence_icon)
	_lbl_essence.resized.connect(_place_essence_icon)

	_btn_speed = Button.new()
	SceneSwitcher.pin(_btn_speed, Vector2(0, 0), Rect2(40, 58, 110, 36))   # 진행 표시 아래
	_btn_speed.focus_mode = Control.FOCUS_NONE
	_btn_speed.mouse_entered.connect(func() -> void: VDJuice.bump(_btn_speed, 0.35))
	_btn_speed.pressed.connect(_toggle_speed)
	root.add_child(_btn_speed)
	_refresh_speed_label()

	# 갈림길 선택 버튼 (화면 중앙 아래, 선택 중에만 표시)
	_path_box = HBoxContainer.new()
	SceneSwitcher.pin(_path_box, Vector2(0.5, 1), Rect2(560, 780, 800, 70))
	_path_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_path_box.add_theme_constant_override("separation", 30)
	_path_box.visible = false
	root.add_child(_path_box)

	_btn_main = VDMainButton.new()
	SceneSwitcher.pin(_btn_main, Vector2(0.5, 1), Rect2(672, 968, 350, 82))   # 좌측 캐릭터 패널과 분대 카드 사이
	_btn_main.pressed.connect(start_battle)
	root.add_child(_btn_main)

	# 캐릭터 턴테이블 (좌측 하단): 스탠딩을 둥글게 세우고 돌려 본다
	turntable = VDTurntable.new()
	root.add_child(turntable)

	# 게임오버 오버레이
	_over_panel = Control.new()
	_over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over_panel.visible = false
	_over_panel.z_index = 500   # 턴테이블 캐릭터(z 최대 ~200)보다 위
	root.add_child(_over_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over_panel.add_child(center)
	var vb2 := VBoxContainer.new()
	vb2.add_theme_constant_override("separation", 18)
	vb2.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb2)
	_over_title = Label.new()
	_over_title.text = "거점 함락"
	_over_title.add_theme_font_size_override("font_size", 96)
	_over_title.add_theme_color_override("font_color", Color(1.0, 0.42, 0.5))
	_over_title.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.1))
	_over_title.add_theme_constant_override("outline_size", 22)
	_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb2.add_child(_over_title)
	_lbl_over = Label.new()
	_lbl_over.add_theme_font_size_override("font_size", 30)
	_lbl_over.add_theme_color_override("font_color", Color(0.85, 0.78, 1.0))
	_lbl_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb2.add_child(_lbl_over)
	_over_stats = Label.new()
	_over_stats.add_theme_font_size_override("font_size", 40)
	_over_stats.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_over_stats.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.22))
	_over_stats.add_theme_constant_override("outline_size", 10)
	_over_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb2.add_child(_over_stats)
	var retry_wrap := CenterContainer.new()
	vb2.add_child(retry_wrap)
	_btn_retry = VDMainButton.new()
	_btn_retry.text = "다시 도전"
	_btn_retry.show_key = false
	_btn_retry.custom_minimum_size = Vector2(320, 82)
	_btn_retry.pressed.connect(restart)
	retry_wrap.add_child(_btn_retry)


func _label(parent: Node, text: String, pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _flat(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(8)
	return sb


# ---------------------------------------------------------------- run / units

func _new_run() -> void:
	_run_id += 1
	parry.reset()
	for e in enemies:
		e.queue_free()
	enemies.clear()
	_wave_from = 0
	_wave_plan = 0.0
	for a in allies:
		a.queue_free()
	allies.clear()
	map = VDMap.new()
	map.rng.randomize()
	for arg in OS.get_cmdline_user_args():   # --vdseed=N : 맵 생성을 재현(테스트·캡처용)
		if arg.begins_with("--vdseed="):
			map.rng.seed = int(arg.substr(9))
	room = map.create_root(force_shape)
	board.map = map
	board.current_room = room
	board.exits = []
	board.show_exits = false
	props.clear()
	props.scatter_room(map, room)
	nebula_tuner.clear_moods()
	formation.clear()
	var taken := {}
	for hid in (sandbox.heroes if sandbox else VDData.HERO_ORDER):
		var def: Dictionary = VDData.HEROES[hid]
		var local: Vector2i = VDMap.nearest_zone_cell(room, def["start"], "A", taken)
		taken[local] = true
		formation[hid] = local
		var u := _make_unit(def, hid, 0, VDMap.to_world(room, local.x, local.y))
		allies.append(u)
	wave = 1
	stage = 1
	wave_in_stage = 1
	_sub_pending = false
	_landing = false
	_roll_gimmick()
	growth.reset()
	growth.apply_all()
	if skill_window:
		skill_window.close()
	essence = 0
	exits = []
	essence_drops.clear()
	goo.clear()
	impact.reset()
	if ult_aim.active:
		ult_aim._end()
	ult.reset()
	fallen.clear()
	relic_board.reset()
	relics.reset()
	if relic_hud:
		relic_hud.reset_run()
	_refresh_essence()
	_over_panel.visible = false
	_lbl_boss.visible = false
	_boss_bar.visible = false
	_path_box.visible = false
	_cam_target = VDData.to_screen(VDMap.center_f(room))
	camera.position = _cam_target
	camera.reset_smoothing()
	focus.reset(_cam_target, camera.base_zoom.x)
	if sandbox:
		sandbox.begin(_run_id)   # 전투 연습장: 배치 단계 없이 고른 적을 세우고 바로 전투
		return
	_set_state(State.PLACEMENT)
	_spawn_wave(_run_id)   # 분대가 자리 잡은 뒤 적이 먼저 등장: 배치 단계에서 위치가 보인다


func _make_unit(def: Dictionary, id: String, team: int, cell: Vector2i, hp_mult := 1.0, atk_mult := 1.0) -> VDUnit:
	var u := VDUnit.new()
	u.setup(def, id, team, cell, hp_mult, atk_mult)
	units_root.add_child(u)
	u.snap_to_cell()
	u.died.connect(_on_unit_died)
	# 고유 스킬은 마나가 차면 바로 나가므로 READY 연출은 궁극기 게이지에만 (카드를 탭하라는 신호)
	u.ult_ready.connect(func(x: VDUnit) -> void:
		if state == State.BATTLE:
			juice.ready_burst(x)
			frame.pop_card(x.id, 0.8))
	if team == 0:
		u.stepped.connect(func(_x: VDUnit) -> void:
			if state == State.TRAVEL:   # 스테이지(방) 사이 이동 때만 발소리
				audio.play("step", 0.08))
	return u


func _unit_at(cell: Vector2i, list: Array[VDUnit]) -> VDUnit:
	for u in list:
		if u.alive and u.occupies(cell):
			return u
	return null


## except 는 무시한다 (대형 유닛이 자기 칸을 밟고 이동할 때).
## 떠다니는 유닛은 칸을 차지하지 않는다 (그 아래로 지나가거나 같은 칸에 설 수 있다).
func _occupied(cell: Vector2i, except: VDUnit = null) -> bool:
	for list in [allies, enemies]:
		for u: VDUnit in list:
			if u.alive and u != except and not u.floating and u.occupies(cell):
				return true
	return false


## u 의 footprint 를 최소 꼭짓점 at 에 놓을 수 있는가 (방 안 + 다른 유닛과 겹치지 않음).
func _fits(u: VDUnit, at: Vector2i) -> bool:
	for c in u.footprint(at):
		if not VDMap.in_room(room, c) or (not u.floating and _occupied(c, u)):
			return false
	return true


# ---------------------------------------------------------------- input

## Space: 배치 완료 (적이 아직 등장 중이면 끝난 뒤 시작). 입력칸 등 GUI 가 먼저 쓰면 여기까지 오지 않는다.
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		preview_super_cutin()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		_show_msg("타일 글리치: %s" % tile_glitch.cycle(), 1.2)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE and state == State.PLACEMENT:
		start_battle()
		get_viewport().set_input_as_handled()
		return
	# Z X C V: 분대 카드 순서대로 궁극기 (카드 탭과 같다). 조준 중의 같은 키 취소·다른 키 전환은 VDUltAim 이 받는다.
	if event is InputEventKey and event.pressed and not event.echo and state == State.BATTLE:
		var hid: String = frame.hero_for_key(event)
		if hid != "":
			try_ult(hid)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if state == State.PLACEMENT:
				_begin_drag()
			elif state == State.CHOOSE_PATH:
				_click_exit(_mouse_cell())
		else:
			_end_drag()
	elif event is InputEventMouseMotion and _dragging and state == State.PLACEMENT:
		_update_drag()


func _mouse_cell() -> Vector2i:
	return VDData.to_cell(board.get_local_mouse_position())


func _placement_valid(cell: Vector2i, u: VDUnit) -> bool:
	if VDMap.zone(room, cell) != "A":
		return false
	var other := _unit_at(cell, allies)
	return other == null or other == u


## 드래그: 집으면 쑥 들어 올려 커지고, 움직이는 방향으로 살짝 기운다. 놓으면 찌그러지며 착지,
## 놓을 수 없는 칸이면 원래 자리로 고무줄처럼 튕겨 돌아간다.
func _begin_drag() -> void:
	var u := _unit_at(_mouse_cell(), allies)
	if u == null:
		return
	_dragging = u
	u.z_index = 100
	var tw := u.create_tween().set_ignore_time_scale(true)
	tw.tween_property(u, "scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	audio.play("tick", 0.05, -6.0, 1.4)
	_update_drag()


func _update_drag() -> void:
	var target := board.get_local_mouse_position() + Vector2(0, -26)
	_dragging.rotation = lerpf(_dragging.rotation, clampf((target.x - _dragging.position.x) * 0.01, -0.3, 0.3), 0.35)
	_dragging.position = target
	var c := _mouse_cell()
	board.set_hover(c, _placement_valid(c, _dragging))


func _end_drag() -> void:
	if _dragging == null:
		return
	var c := _mouse_cell()
	var u := _dragging
	var tw := u.create_tween().set_ignore_time_scale(true)
	if _placement_valid(c, u):
		if c != u.cell:
			audio.play("place")
			vfx.spawn("dust", ground_fx, VDData.to_screen(Vector2(c)), 0.9)
		u.cell = c
		var land := u.foot_at(c)
		# 착지: 떨어지며 찌그러졌다 쫀득하게 제자리
		tw.tween_property(u, "position", land, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(u, "rotation", 0.0, 0.08)
		tw.tween_property(u, "scale", Vector2(1.25, 0.78), 0.05)
		tw.tween_property(u, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		# 놓을 수 없는 칸: 붉게 번쩍이고 원래 자리로 튕겨 돌아간다
		audio.play("tick", 0.0, -4.0, 0.6)
		u._flash = 0.6
		tw.tween_property(u, "position", u.foot_at(u.cell), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(u, "rotation", 0.0, 0.2)
		tw.parallel().tween_property(u, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(u) and _dragging != u:
			u.snap_to_cell())
	u.z_index = 0
	_dragging = null
	board.set_hover(Vector2i(-1, -1), false, false)


func _click_exit(cell: Vector2i) -> void:
	for i in exits.size():
		var ex: Dictionary = exits[i]
		if cell in ex["corridor"] or VDMap.in_room(map.rooms[ex["room_id"]], cell):
			choose_path(i)
			return


## 테스트/외부용: 영웅을 현재 방의 로컬 (a, c) 로 바로 옮긴다.
func place_hero(id: String, local: Vector2i) -> bool:
	for u in allies:
		var cell := VDMap.to_world(room, local.x, local.y)
		if u.id == id and _placement_valid(cell, u):
			u.cell = cell
			u.snap_to_cell()
			return true
	return false


# ---------------------------------------------------------------- flow

## 배치 완료: 적은 이미 등장해 있으므로 짧은 "치료 시작" 연출 뒤 바로 전투. 적이 아직 등장 중이면 끝난 뒤 시작한다.
func start_battle() -> void:
	if state != State.PLACEMENT:
		return
	if _dragging:
		_end_drag()   # 끌던 영웅을 먼저 내려놓는다 (안 그러면 전투 중에 놓여 진형·실제 칸이 어긋난다)
	if _spawning:
		_pending_start = true
		return
	for a in allies:
		a.home_cell = a.cell
		formation[a.id] = VDMap.to_local(room, a.cell)
	audio.play("click")
	_begin_battle(_run_id)


func _begin_battle(run: int) -> void:
	_set_state(State.SPAWNING)
	_essence_at_start = essence
	audio.play("wave_start", 0.0)
	banner.play("치료 시작", "", Color(1.0, 0.55, 0.75), 0.35, false)
	# 배너가 박힌 뒤 한 박자 늦게 잠들어 있던 적이 깨어난다: 작게 움찔 (한 마리씩 살짝 시간차)
	await _wait_real(0.35)
	if run != _run_id or state != State.SPAWNING:
		return
	var i := 0
	for e in enemies:
		if e.alive:
			var tw := e.create_tween()
			tw.tween_interval(0.05 * i)
			tw.tween_property(e, "scale", Vector2(1.18, 0.86), 0.08)
			tw.tween_property(e, "scale", Vector2.ONE, 0.16)
			i += 1
	await _wait_real(BATTLE_START_SEC - 0.35)
	if run != _run_id or state != State.SPAWNING:
		return
	_set_state(State.BATTLE)
	tactics.reset()
	flow.begin()
	field.begin()
	gimmicks.begin()
	gimmicks.update_immunity()
	relics.on_battle_start()


## 테스트·캡처용: 비어 있지 않으면 모든 스테이지의 첫 웨이브가 이 기믹 무리다 (명령줄 --vdgimmick=<id> 로도 지정).
var force_gimmick := ""
## 테스트·캡처용: 비어 있지 않으면 새 판의 첫 방이 이 모양이다 (VDMap.TEMPLATES 의 키).
var force_shape := ""


## 이번 스테이지의 기믹 무리 추첨 (새 판·새 방마다).
func _roll_gimmick() -> void:
	if force_gimmick == "":
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--vdgimmick="):
				force_gimmick = arg.substr(12)
	if force_gimmick != "" and VDData.GIMMICKS.has(force_gimmick):
		gimmick = force_gimmick
		gimmick_wave = 1
		return
	var g := VDData.roll_gimmick(stage)
	gimmick = String(g[0])
	gimmick_wave = int(g[1])
	if gimmick != "":
		print("[VD] stage %d gimmick: %s at wave %d" % [stage, gimmick, gimmick_wave])


func is_gimmick_wave() -> bool:
	return gimmick != "" and wave_in_stage == gimmick_wave


## 적 등장: 방의 E 구역 셀을 섞어 차례로 솟아난다.
##   mid = false (스테이지 첫 웨이브): 배치 단계에서 미리 등장. 끝나면 배치 완료 버튼이 열린다. HP 바는 교전 시작 때 붙는다.
##   mid = true  (2번째 웨이브부터): 전투 중에 내려앉는다. 땅에 닿을 때까지는 행동하지 않고(casting), HP 바를 단 채 나타난다.
func _spawn_wave(run: int, mid := false) -> void:
	_landing = mid
	if not mid:
		_spawning = true
		_refresh_main_button()
	var types := VDData.wave_enemies(stage, wave_in_stage, gimmick if is_gimmick_wave() else "")
	var mult := VDData.scaling(wave)
	wave_mult = mult
	wave_atk_mult = VDData.atk_scaling(wave)
	# 웨이브 진행도: 이 웨이브의 적은 enemies 의 지금 끝부터. 계획 총 체력을 먼저 잡아 두면 내려앉을 때마다 바가 차오른다
	_wave_from = enemies.size()
	_wave_plan = 0.0
	for t in types:
		_wave_plan += floorf(float(VDData.ENEMIES[t]["hp"]) * mult * 0.7)
	_wave_bar.reset(wave_in_stage == 1)
	print("[VD] room %d (%s) / stage %d wave %d/%d (total %d)%s: %d enemies %s (x%.2f)" % [room["id"], room["shape"], stage, wave_in_stage, VDData.waves_in_stage(stage), wave, (" [" + gimmick + "]") if is_gimmick_wave() else "", types.size(), str(types), mult])
	if is_gimmick_wave():
		var gd: Dictionary = VDData.GIMMICKS[gimmick]
		_show_msg("기믹 무리 — %s: %s" % [gd["name"], gd["hint"]], 3.2)
	elif not mid:
		_show_msg("공허의 잔재가 균열에서 나타난다...", 1.4)
	var spots: Array = VDMap.local_cells(room, "E")
	spots.shuffle()
	var used := {}
	# 강적(중급·보스 중 가장 센 적)은 맨 마지막에, 한 박자 뜸을 들이고 괴성과 함께 내려앉는다.
	var champ := _champion_index(types)
	var rest: Array[int] = []
	for i in types.size():
		if i != champ:
			rest.append(i)
	# 자리는 강적·대형 적(4칸)부터 잡는다 (넓은 자리가 쪼개지기 전에). 등장도 대형 적이 먼저.
	rest.sort_custom(func(a: int, b: int) -> bool: return _enemy_size(types[a]) > _enemy_size(types[b]))
	var cells := {}
	for i in ([champ] if champ >= 0 else []) + rest:
		var sz := _enemy_size(types[i])
		var cell := _random_spawn_cell(spots, used, sz)
		if cell.x == -999:
			continue
		for x in sz:
			for y in sz:
				used[cell + Vector2i(x, y)] = true
		cells[i] = cell
	for i in rest + ([champ] if champ >= 0 else []):
		if run != _run_id:
			return
		if not cells.has(i):
			continue
		var t := types[i]
		var def: Dictionary = VDData.ENEMIES[t]
		var e := _make_unit(def, t, 1, cells[i], mult * 0.7, wave_atk_mult)
		var foot := e.position
		var heavy := e.is_boss or e.size > 1
		if mid:
			# 전투 중 등장: 내려앉을 때까지 행동 금지, HP 바는 바로
			e.show_bar = true
			e.casting = true
			var er: WeakRef = weakref(e)
			get_tree().create_timer(VDUnit.appear_duration() + VDSummonFx.g("champ_delay") + VDSummonFx.g("champ_lead"), false).timeout.connect(func() -> void:
				var e2 := er.get_ref() as VDUnit
				if e2 != null:
					e2.casting = false)
		if i == champ:
			# 강적: 잠깐 정적 → 큰 균열·괴성·낮은 흔들림 → 낙하. 그동안 몸은 숨겨 둔다.
			e.visible = false
			await get_tree().create_timer(VDSummonFx.g("champ_delay")).timeout
			if run != _run_id:
				e.queue_free()
				return
			print("[VD] champion: %s" % t)
			audio.play("boss_roar", 0.0, 0.0, 1.0 if e.is_boss else 1.15)
			VDSummonFx.play_champion_warn(vfx, ground_fx, camera, foot)
			if not e.is_boss:
				_show_msg("강적 출현: " + e.display_name, 1.6)
			await get_tree().create_timer(VDSummonFx.g("champ_lead")).timeout
			if run != _run_id:
				e.queue_free()
				return
			e.visible = true
			e.appear(func() -> void:
				VDSummonFx.play_champion_impact(vfx, ground_fx, fx_root, camera, foot, e._top)
				audio.play("boss_spawn", 0.05))
			enemies.append(e)
			champion_spawned.emit(e)
		else:
			# 차원 소환: 새하얀 빛줄기로 떨어져 바닥에 꽂힌다. 꽂히는 순간 충격파·먼지·섬광 + 화면 흔들림.
			# 값은 VDSummonFx (로비 → 연출 연구실에서 조절)
			e.appear(VDSummonFx.play_impact.bind(vfx, ground_fx, fx_root, camera, foot, heavy))
			enemies.append(e)
			audio.play("boss_spawn" if heavy else "enemy_spawn", 0.12)
			# 균열(포털)이 바닥에서 소용돌이치며 낙하 지점을 예고한다
			VDSummonFx.play_portal(vfx, ground_fx, foot, heavy)
		if e.is_boss:
			_lbl_boss.text = e.display_name
			_lbl_boss.visible = true
			_boss_bar.visible = true
			nebula_tuner.set_boss(true)   # 배경이 더 강렬하고 빠르게: 위험 연출
			_show_msg("보스 등장: " + e.display_name, 1.6)
		await get_tree().create_timer(maxf(VDSummonFx.g("interval"), 0.01)).timeout
	await get_tree().create_timer(VDUnit.appear_duration() + 0.1).timeout   # 마지막 적의 출렁임이 끝날 때까지
	if run != _run_id:
		return
	if mid:
		_sub_pending = false
		_landing = false
		gimmicks.update_immunity()
		# 내려앉는 동안 다 쓰러뜨렸으면 (드물다) 바로 다음 판정
		if state == State.BATTLE and _alive_count(enemies) == 0 and not flow.pending():
			_on_enemies_down(run, VDData.to_screen(VDMap.center_f(room)))
		return
	_spawning = false
	_refresh_main_button()
	if _pending_start:
		_pending_start = false
		start_battle()


## 전투 중 다음 웨이브: SUBWAVE_DELAY 뒤 알림 없이 균열에서 내려앉는다 (TrioChess 서브웨이브).
## 모두 내려앉을 때까지(_sub_pending) 전투 시뮬레이션은 멈춰 있다 (_physics_process).
func _next_subwave(run: int) -> void:
	_sub_pending = true
	subwave_cleared.emit(wave)
	print("[VD] stage %d wave %d/%d cleared -> next" % [stage, wave_in_stage, VDData.waves_in_stage(stage)])
	for a in allies:
		if a.alive:
			a.reset_combat()   # 기절·가드만 푼다. 체력·마나·게이지는 그대로
	await _wait_real(VDData.SUBWAVE_DELAY)
	if run != _run_id or state != State.BATTLE:
		_sub_pending = false
		return
	wave += 1
	wave_in_stage += 1
	_refresh_wave_label()
	# 2026-11-09: "N차 웨이브!" 띠·소리는 띄우지 않는다 (진행은 상단 웨이브 진행도가 보여 준다)
	_spawn_wave(run, true)


## 적이 모두 쓰러졌다: 스테이지의 마지막 웨이브면 구역 클리어, 아니면 다음 웨이브.
func _on_enemies_down(run: int, last_at: Vector2) -> void:
	if wave_in_stage < VDData.waves_in_stage(stage):
		_next_subwave(run)
	else:
		_finish_wave(run, last_at)


## 웨이브의 강적: 중급(tier 1) 이상 중 등급 → 체력이 가장 높은 적의 인덱스. 일반 적뿐이면 -1.
static func _champion_index(types: Array[String]) -> int:
	var best := -1
	for i in types.size():
		var d: Dictionary = VDData.ENEMIES[types[i]]
		if int(d.get("tier", 0)) < 1:
			continue
		if best < 0:
			best = i
			continue
		var b: Dictionary = VDData.ENEMIES[types[best]]
		if int(d["tier"]) > int(b["tier"]) or (int(d["tier"]) == int(b["tier"]) and float(d["hp"]) > float(b["hp"])):
			best = i
	return best


static func _enemy_size(t: String) -> int:
	return int(VDData.ENEMIES[t].get("size", 1))


## sz > 1 이면 footprint 전체가 비어 있어야 한다. E 구역 안에 들어가는 자리를 먼저, 없으면 아군 구역만 피해 방 안 아무 데나.
func _random_spawn_cell(spots: Array, used: Dictionary, sz := 1) -> Vector2i:
	for strict in [true, false]:
		for l in spots:
			var c := VDMap.to_world(room, l.x, l.y)
			var ok := true
			for x in sz:
				for y in sz:
					var f := c + Vector2i(x, y)
					var z := VDMap.zone(room, f)
					if used.has(f) or _occupied(f) or z == "" or z == "A" or (strict and z != "E"):
						ok = false
			if ok:
				return c
		if sz == 1:
			break
	return Vector2i(-999, -999)


func _on_unit_died(u: VDUnit) -> void:
	if u.team == 1:
		var at := _chest(u)
		# 기믹: 분열(소잔재 생성) · 촉수(임시 사망 → 부활 대기) · 환술사(환영 무적 해제)
		var temporary: bool = gimmicks.on_enemy_died(u)
		audio.play("boss_die" if u.is_boss else "enemy_die", 0.05)
		# 폭발·별 섬광·체액·쇼크웨이브·흔들림·히트스탑·슬로모션: vd_kill_fx.gd (연출 연구실 "몬스터 사망")
		KillFx.play(u, at, vfx, fx_root, ground_fx, camera, goo, shockwave, not temporary)
		if temporary:
			print("[VD] enemy down (temporary): %s" % u.display_name)
			return
		juice.on_kill(at)
		# 정수는 바로 들어오지 않고 바닥에 흩뿌려진다 (클리어 때 HUD 로 흡수)
		# 파편처럼 여러 조각으로 흩뿌린다: 보통 2 · 정수가 많으면 3 · 보스 5 (2026-11-10 개수 절반으로)
		essence_drops.spawn(u.position, u._top, u.essence, 5 if u.is_boss else clampi(u.essence / 4, 2, 3))
		if u.is_boss:
			nebula_tuner.set_boss(false)
		print("[VD] enemy down: %s  (+%d essence)" % [u.display_name, u.essence])
		relics.on_enemy_killed(u)
		# 경험치 (TrioChess EXP_PER_KILL): 처치한 영웅 전액, 나머지는 나눠서. 보스·중간급은 tier 만큼 더
		if not sandbox:
			var exp := VDData.EXP_PER_KILL * (1 + int(VDData.ENEMIES.get(u.id, {}).get("tier", 0)))
			growth.grant_kill_exp(u.last_hit_by if u.last_hit_by is VDUnit and (u.last_hit_by as VDUnit).team == 0 else null, exp)
		if state == State.BATTLE and _alive_count(enemies) == 0 and not flow.pending() and not _sub_pending:
			if sandbox:
				sandbox.on_enemies_down()   # 연습장: 클리어 연출 대신 같은 적을 다시 세운다
			else:
				_on_enemies_down(_run_id, u.position)
	else:
		print("[VD] hero down: %s" % u.display_name)
		audio.play("hero_down", 0.0)
		nebula_tuner.danger_flash()   # 배경·앞 안개가 잠시 붉고 빠르게: 위험 알림
		_death_slowmo(VDData.ALLY_DEATH_TIER)
		vfx.spawn("lightning", fx_root, u.position + Vector2(0, u._top * 0.9), 0.6, 0.0, Color(1.0, 0.45, 0.55))
		vfx.spawn("burst", fx_root, _chest(u), 0.45, 0.0, Color(1.0, 0.4, 0.5))
		# 쓰러지는 자리: 먼지 + 붉은 충격파, 분대 카드는 금이 가며 '전투 불능' 도장
		var uref: WeakRef = weakref(u)
		get_tree().create_timer(0.3).timeout.connect(func() -> void:
			var u2 := uref.get_ref() as VDUnit
			if u2 != null:
				vfx.spawn("dust", ground_fx, u2.position + Vector2(-u2._facing * 50.0, 0), 1.6, 0.0, Color(1, 1, 1, 0.8))
				vfx.spawn("shockwave", ground_fx, u2.position, 0.6, 0.0, Color(1.0, 0.4, 0.5), Vector2(1.0, 0.5))
				camera.shake(0.3))
		frame.card_down(u.id)
		fallen.erase(u)
		fallen.append(u)
		if state == State.BATTLE and _alive_count(allies) == 0:
			if sandbox:
				sandbox.on_heroes_down()    # 연습장: 게임 오버 없이 일으켜 세운다
			else:
				_do_game_over()


## 사망 연출: 등급별로 잠깐 슬로모션 (기본 적 < 중간급 적·아군 < 보스).
func _death_slowmo(tier: int) -> void:
	var s: Array = VDData.DEATH_SLOWMO[clampi(tier, 0, VDData.DEATH_SLOWMO.size() - 1)]
	camera.slowmo(float(s[0]), float(s[1]))


func _alive_count(list: Array[VDUnit]) -> int:
	var n := 0
	for u in list:
		if u.alive:
			n += 1
	return n


## 구역 클리어 연출. 타임라인은 CLEAR_* 상수 (실제 시간이라 슬로모션·배속에 늘어지지 않는다).
func _finish_wave(run: int, last_at: Vector2) -> void:
	_set_state(State.TRANSITION)
	print("[VD] room %d cleared (wave %d)  essence=%d" % [room["id"], wave, essence])
	wave_cleared.emit(wave)
	_lbl_boss.visible = false
	_boss_bar.visible = false
	for a in allies:
		a.reset_combat()   # 기절·가드 해제 (마나는 이어진다)
	relics.on_battle_end()
	var boss_room := VDData.is_boss_stage(stage)
	# 1) 마지막 처치: 가장 긴 슬로모션 + 처치 지점으로 줌인. 화면이 숨을 고른다
	camera.slowmo(float(CLEAR_SLOWMO[0]), float(CLEAR_SLOWMO[1]))
	camera.shake(0.6)
	_cam_target = last_at.lerp(VDData.to_screen(VDMap.center_f(room)), 0.35)
	_zoom_to(FINALE_ZOOM, 0.7)
	vfx.spawn("shockwave", ground_fx, last_at, 1.1, 0.0, Color(0.9, 0.7, 1.0), Vector2(1.0, 0.5))
	await _wait_real(CLEAR_BANNER_AT)
	if run != _run_id:
		return
	# 2) "치료 성공" 배너 + 카메라가 방 전체로 물러난다
	_cam_target = VDData.to_screen(VDMap.center_f(room))
	_zoom_to(1.0, 0.9)
	audio.play("wave_clear", 0.0)
	vfx.spawn("shockwave", ground_fx, VDData.to_screen(VDMap.center_f(room)), 1.6, 0.0, Color(1.0, 0.9, 0.5), Vector2(1.0, 0.5))
	var sub := "스테이지 %d 정화 완료 (웨이브 %d)  ·  공허 정수 +%d" % [stage, VDData.waves_in_stage(stage), essence - _essence_at_start + essence_drops.pending()]
	var banner_sec := banner.play("치료 성공", sub, Color(1.0, 0.45, 0.35) if boss_room else Color(1.0, 0.78, 0.3), CLEAR_BANNER_HOLD)
	await _wait_real(CLEAR_COLLECT_AT)
	if run != _run_id:
		return
	# 3) 바닥에 흩뿌려진 정수가 하나씩 HUD 로 빨려 들어간다 (TrioChess 동전 회수)
	var collect_sec := essence_drops.collect(_essence_icon, _on_essence_arrive)
	var wait_heal := maxf(CLEAR_HEAL_AT - CLEAR_COLLECT_AT, collect_sec + 0.15)
	await _wait_real(wait_heal)
	if run != _run_id:
		return
	# 4) 회복: 아군 한 명씩 차례로
	var healed := CLEAR_COLLECT_AT + wait_heal - CLEAR_HEAL_AT   # 배너 기준 경과 시간 보정 (아래 유물 대기 계산용)
	for a in allies:
		if not a.alive:
			continue
		var before := a.hp
		a.heal(WAVE_HEAL)
		var gain := int(a.hp - before)
		if gain > 0:
			audio.play("heal", 0.05, -4.0)
			vfx.spawn("heal", fx_root, _chest(a), 0.5, 0.0, Color(0.8, 1.0, 0.8))
			dmg_log.spawn_status(_chest(a), "+%d" % gain, Color(0.55, 1.0, 0.6), a)
			await _wait_real(CLEAR_HEAL_GAP)
			healed += CLEAR_HEAL_GAP
			if run != _run_id:
				return
	# 5) 배너가 다 빠진 뒤 유물 보상 (화면에 하나씩만)
	await _wait_real(maxf(banner_sec - CLEAR_HEAL_AT - healed, 0.0) + CLEAR_REWARD_GAP)
	if run != _run_id:
		return
	_relic_rewards()
	await _wait_real(CLEAR_EXITS_AT)
	if run != _run_id:
		return
	for e in enemies:
		e.queue_free()
	enemies.clear()
	room["cleared"] = true
	_wave_from = 0
	_wave_plan = 0.0
	var before := map.tiles.duplicate()
	exits = map.generate_exits(room)
	print("[VD] exits from room %d: %s" % [room["id"], str(exits.map(func(x): return x["label"]))])
	# 새 복도·방 블록이 바닥 아래에서 시간차로 솟아오르고, 그 둘레에 떠다니는 프랍이 따라 떠오른다
	var new_cells := map.tiles.keys().filter(func(c: Vector2i) -> bool: return not before.has(c))
	if not new_cells.is_empty():
		props.remove_near(new_cells)
		var rise := board.raise_tiles(new_cells, VDMap.to_world(room, int(room["len"]) - 1, int(room["exit_c"])))
		# 석판 솟아오르는 소리: 다음 웨이브가 보스·대형 적이면 공허 에너지가 섞인 소리
		audio.play("slab_rise_boss" if VDData.is_hard_stage(stage + 1) else "slab_rise", 0.03)
		for ex in exits:
			props.scatter_room(map, map.rooms[ex["room_id"]], rise * 0.5)
		await get_tree().create_timer(rise * 0.85).timeout
		if run != _run_id:
			return
	board.exits = exits
	board.show_exits = true
	board.queue_redraw()
	_set_state(State.CHOOSE_PATH)
	if exits.size() == 1:
		_show_msg("길이 하나뿐 — 전진합니다", 1.2)
		await get_tree().create_timer(0.8).timeout
		if run != _run_id or state != State.CHOOSE_PATH:
			return
		choose_path(0)
	else:
		_show_msg("갈림길!  빛나는 길을 클릭하거나 아래 버튼으로 선택", 3.0)


## 갈림길 선택 → 복도를 따라 다음 방으로 이동 → 저장된 진형으로 재배치.
func choose_path(i: int) -> void:
	if state != State.CHOOSE_PATH or i < 0 or i >= exits.size():
		return
	var ex: Dictionary = exits[i]
	var next_room: Dictionary = map.rooms[ex["room_id"]]
	print("[VD] path chosen: %d (%s) -> room %d" % [i, ex["label"], next_room["id"]])
	audio.play("click")
	board.show_exits = false
	_path_box.visible = false
	_set_state(State.TRAVEL)
	_travel(_run_id, ex, next_room)


func _travel(run: int, ex: Dictionary, next_room: Dictionary) -> void:
	var corridor: Array = ex["corridor"]
	var longest := 0.0
	var k := 0
	var taken := {}
	for a in allies:
		# 저장한 진형 자리가 이 방 모양의 아군 구역에 없으면 가장 가까운 아군 칸으로
		var local: Vector2i = VDMap.nearest_zone_cell(next_room, formation[a.id], "A", taken)
		taken[local] = true
		formation[a.id] = local
		var dest := VDMap.to_world(next_room, local.x, local.y)
		if not a.alive:
			a.cell = dest
			a.home_cell = dest
			a.snap_to_cell()
			continue
		var lane := k % 2
		var waypoints: Array[Vector2i] = [corridor[lane], corridor[corridor.size() - 2 + lane], dest]
		var tw := create_tween()
		tw.tween_interval(0.12 * k)
		# 출발 순서가 올 때부터 걷기 애니메이션(VDUnit.moving)
		tw.tween_callback(func() -> void:
			a.moving = true
			vfx.spawn("dash", ground_fx, a.position, 1.0, 0.0, Color.WHITE, Vector2.ONE, a.position.x > VDData.to_screen(Vector2(corridor[0])).x))
		var prev := a.cell
		var total := 0.12 * k
		for wp in waypoints:
			var d := float(VDData.manhattan(prev, wp))
			var dur := maxf(0.15, d * TRAVEL_SEC_PER_TILE)
			tw.tween_property(a, "position", VDData.to_screen(Vector2(wp)), dur)
			total += dur
			prev = wp
		a.cell = dest
		a.home_cell = dest
		tw.tween_callback(func() -> void: a.moving = false)
		longest = maxf(longest, total)
		k += 1
	await get_tree().create_timer(longest + 0.2).timeout
	if run != _run_id:
		return
	room = next_room
	board.current_room = room
	board.exits = []
	exits = []
	for a in allies:
		a.snap_to_cell()
	wave += 1
	stage += 1
	wave_in_stage = 1
	_roll_gimmick()
	_cam_target = VDData.to_screen(VDMap.center_f(room))
	_spawning = true   # 도착 직후 한 박자: 숨을 고른 뒤 적이 나타난다 (그 사이 전투 시작 잠금)
	_set_state(State.PLACEMENT)
	_show_msg("새 구역(%s) 도착 — 적의 위치를 보고 진형을 잡은 뒤 치료를 시작하세요 (Space)%s" % [VDMap.SHAPE_NAMES[room["shape"]], _field_hint()], 2.4 if _field_hint() == "" else 3.6)
	await _wait_real(ARRIVE_BREATH)
	if run != _run_id:
		return
	_spawn_wave(_run_id)


## 이 방의 필드 기믹 안내 (없으면 ""). 도착 메시지 끝에 붙인다.
func _field_hint() -> String:
	var kinds := {}
	for l in room.get("fields", {}):
		kinds[room["fields"][l]] = true
	var parts: Array[String] = []
	if kinds.has("amp"):
		parts.append("증폭 패널: 올라선 영웅 공격·치유 +%d%%" % int(VDFieldGimmicks.AMP_BONUS * 100.0))
	if kinds.has("shock"):
		parts.append("방전 격자: 주기적으로 감전 (적·아군 모두)")
	return "" if parts.is_empty() else "\n" + "  ·  ".join(parts)


## 게임 오버: 마지막 아군이 쓰러지는 2초 슬로모션 → 화면 전체 패배 글리치(큰 폭발 → 들끓음 · 띠 끊김, 약 2.6초) 와 함께
## 전장이 흑백으로 바램 → "거점 함락" 배너가 뜨는 자리가 글리치되며 가라앉음(screen_glitch.burst_rect) → 패널도 같은 식으로 등장(제목 팡 → 기록 숫자가 굴러 올라감 →
## 다시 도전 버튼이 늦게 튀어나옴). 모두 실제 시간. (2026-11-09 패배 글리치 연출)
func _do_game_over() -> void:
	_set_state(State.GAMEOVER)
	print("[VD] GAME OVER at wave %d" % wave)
	ult.reset()
	game_over.emit(wave)
	var run := _run_id
	camera.slowmo(FINALE_SLOWMO[0], FINALE_SLOWMO[1])
	audio.play("defeat", 0.0)
	screen_glitch.kick(1.0, "defeat")
	camera.shake(0.7)
	_set_gray(true)
	await _wait_real(1.1)
	if run != _run_id:
		return
	screen_glitch.burst_rect(Rect2(0, 540 - 170, 1920, 340), 0.6)
	var hold := banner.play("거점 함락", "분대가 모두 쓰러졌습니다", Color(1.0, 0.35, 0.45), 1.0)
	await _wait_real(hold * 0.75)
	if run != _run_id:
		return
	_show_over_panel()


func _show_over_panel() -> void:
	var final_wave := wave
	var final_ess := essence
	_lbl_over.text = "구역 %d 에서 함락" % [room["id"] + 1]
	screen_glitch.burst_rect(Rect2(0, 540 - 260, 1920, 520), 0.75)
	_over_panel.visible = true
	_over_panel.modulate.a = 0.0
	_btn_retry.modulate.a = 0.0
	_btn_retry.disabled = true
	_over_title.pivot_offset = _over_title.size * 0.5
	_over_title.scale = Vector2(2.2, 0.4)
	var tw := _over_panel.create_tween().set_ignore_time_scale(true)
	tw.tween_property(_over_panel, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(_over_title, "scale", Vector2(0.9, 1.15), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_over_title, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: camera.shake(0.4))
	# 기록: 0 부터 굴러 올라가며 틱
	tw.tween_method(func(k: float) -> void:
		var w := int(round(final_wave * k))
		var e := int(round(final_ess * k))
		var txt := "도달 WAVE  %d      공허 정수  %d" % [w, e]
		if txt != _over_stats.text:
			_over_stats.text = txt
			audio.play("tick", 0.02, -8.0, 1.2 + 0.6 * k), 0.0, 1.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		VDJuice.bump(_over_stats, 0.6)
		audio.play("chime", 0.0, -4.0))
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		_btn_retry.disabled = false
		VDJuice.bump(_btn_retry, 1.0))
	tw.tween_property(_btn_retry, "modulate:a", 1.0, 0.2)


## 전장 흑백: 화면 텍스처를 회색으로 섞는 오버레이를 HUD 아래 층에 깐다.
func _set_gray(on: bool) -> void:
	if _gray == null:
		var layer := CanvasLayer.new()
		layer.layer = 5
		add_child(layer)
		_gray = ColorRect.new()
		_gray.set_anchors_preset(Control.PRESET_FULL_RECT)
		_gray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.3, 0.55, 0.15));
	vec3 grey = vec3(g) * vec3(0.92, 0.88, 1.0) * 0.75;
	COLOR = vec4(mix(c, grey, amount), 1.0);
}"""
		var m := ShaderMaterial.new()
		m.shader = sh
		_gray.material = m
		layer.add_child(_gray)
	var mat := _gray.material as ShaderMaterial
	_gray.visible = true
	if on:
		var tw := _gray.create_tween().set_ignore_time_scale(true)
		tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("amount", v), 0.0, 1.0, 1.2)
	else:
		mat.set_shader_parameter("amount", 0.0)
		_gray.visible = false


func restart() -> void:
	_set_gray(false)
	frame.reset_cards()
	_new_run()
	audio.play("click")


func _set_state(s: State) -> void:
	state = s
	if s != State.BATTLE and flow:
		flow.clear_tiles()   # flow.tick 은 전투 중에만 불려 지난 방의 공허 타일이 남는다
	if s != State.BATTLE and field:
		field.stop()
	board.placement_mode = (s == State.PLACEMENT)
	board.queue_redraw()
	# 전투에 집중: 배치 완료(적 등장)부터 살짝 줌인, 전투가 끝나면(클리어·게임 오버) 바로 원래대로
	match s:
		State.SPAWNING:
			_zoom_to(BATTLE_ZOOM, ZOOM_IN_SEC)
		State.PLACEMENT, State.TRANSITION, State.GAMEOVER:
			_zoom_to(1.0, ZOOM_OUT_SEC)
			nebula_tuner.set_boss(false)   # 전투가 끝나면 보스 연출도 풀린다
	var old_text := _btn_main.text
	match s:
		State.PLACEMENT:
			_refresh_main_button()
		State.SPAWNING:
			_btn_main.text = "치료 시작!"
			_btn_main.disabled = true
		State.BATTLE:
			_btn_main.text = "치료 중"
			_btn_main.disabled = true
			# 교전 시작: 적 HP 바가 붙는다 (TrioChess: bars appear once the camp turns hostile)
			for e in enemies:
				if not e.show_bar:
					e.show_bar = true
					e._bar_kick = 1.0
					e._redraw()
		State.TRANSITION:
			_btn_main.text = "회복 중..."
			_btn_main.disabled = true
		State.CHOOSE_PATH:
			_btn_main.text = "길 선택"
			_btn_main.disabled = true
			_rebuild_path_buttons()
		State.TRAVEL:
			_btn_main.text = "이동 중..."
			_btn_main.disabled = true
		State.GAMEOVER:
			_btn_main.text = "게임 오버"
			_btn_main.disabled = true
	if _btn_main.text != old_text:
		_btn_main.bump()
	_refresh_wave_label()
	if skill_window and (s == State.SPAWNING or s == State.BATTLE or s == State.GAMEOVER or s == State.TRAVEL):
		skill_window.close()   # 전투가 시작되면 스킬창은 닫힌다 (SP 는 다음 배치 때 쓴다)
	state_changed.emit(s)


## 큰 방(기둥 광장 12x10 등)은 그만큼 물러나 보여 준다. 기준은 옛 최대 크기 10x8 (len + wid = 18).
func _room_zoom() -> float:
	if room.is_empty():
		return 1.0
	return clampf(18.0 / float(int(room["len"]) + int(room["wid"])), 0.8, 1.0) * _giant_zoom()


## 거대한 적(VDData.ENEMIES 의 "zoom" — 공허 응시자)이 살아 있으면 그만큼 더 물러나 보여 준다.
func _giant_zoom() -> float:
	var z := 1.0
	for e in enemies:
		if is_instance_valid(e) and e.alive:
			z = minf(z, float(VDData.ENEMIES.get(e.id, {}).get("zoom", 1.0)))
	return z


func _zoom_to(z: float, dur: float) -> void:
	z *= _room_zoom()
	if _zoom_tween:
		_zoom_tween.kill()
	if camera.base_zoom.is_equal_approx(Vector2(z, z)):
		return
	# base_zoom 위에 카메라 위빙의 줌 호흡이 곱해진다
	_zoom_tween = create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_zoom_tween.tween_property(camera, "base_zoom", Vector2(z, z), dur)


## 배치 단계 버튼: 적이 등장 중이면 잠그고, 끝나면 "배치 완료".
func _refresh_main_button() -> void:
	if state != State.PLACEMENT:
		return
	var was_locked := _btn_main.disabled
	_btn_main.text = "적 등장 중..." if _spawning else "배치 완료"
	_btn_main.disabled = _spawning
	if was_locked and not _spawning:
		_btn_main.bump(1.3)   # 배치 완료가 열리는 순간: 크게 튀며 반짝
		audio.play("chime", 0.0, -8.0, 1.5)


func _rebuild_path_buttons() -> void:
	for c in _path_box.get_children():
		c.queue_free()
	if exits.size() < 2:
		_path_box.visible = false
		return
	for i in exits.size():
		var b := VDMainButton.new()
		b.text = "길 %d  %s" % [i + 1, exits[i]["label"]]
		b.custom_minimum_size = Vector2(260, 72)
		b.show_key = false
		b.pressed.connect(choose_path.bind(i))
		b.mouse_entered.connect(func() -> void:
			board.exit_hover = i
			audio.play("tick", 0.03, -8.0, 1.3))
		b.mouse_exited.connect(func() -> void:
			if board.exit_hover == i:
				board.exit_hover = -1)
		_path_box.add_child(b)
		# 차례로 아래에서 튀어 오른다
		b.modulate.a = 0.0
		var tw := b.create_tween().set_ignore_time_scale(true)
		tw.tween_interval(0.12 * i)
		tw.tween_property(b, "modulate:a", 1.0, 0.12)
		tw.parallel().tween_callback(b.bump.bind(1.2))
	board.exit_hover = -1
	_path_box.visible = true


# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	if state != State.BATTLE:
		return
	if _sub_pending:
		return   # 다음 웨이브가 다 내려앉을 때까지 전투를 멈춘다 (영웅·적·증원·유물 모두)
	gimmicks.tick_clock(delta)
	_tick_team(allies, enemies, delta)
	_tick_team(enemies, allies, delta)
	tactics.tick(delta)
	if sandbox == null:
		flow.tick(delta)   # 증원·공허 오염 바닥은 연습장에선 쓰지 않는다
		field.tick(delta)  # 필드 기믹(증폭 패널·방전 격자)도 마찬가지
	relics.tick(delta)


func _tick_team(team_units: Array[VDUnit], foes: Array[VDUnit], dt: float) -> void:
	for u in team_units:
		if not u.alive:
			continue
		u.tick_status(dt)
		if u.floating:
			float_move.tick(u, dt, u.stun_timer <= 0.0 and not u.has_meta("blinking") and not (sandbox and not sandbox.acts(u)))
		# 기절·빙결 중이거나 스킬 연출 중이면 쉰다 (타이머도 멈춘다)
		if u.stun_timer > 0.0 or u.casting or u.winding:
			continue
		# 전투 연습장: 자동 전투를 끈 영웅·반격을 끈 적은 서 있기만 한다 (버튼으로만 행동)
		if sandbox and not sandbox.acts(u):
			continue
		# 테스트: 궁극기가 차면 자동 조준으로 바로 쓴다 (플레이에선 카드 탭)
		if auto_ult and u.team == 0 and u.ult_full() and not u.moving and not ult.active and _alive_count(foes) > 0:
			_cast_ult(u, _auto_aim(u))
			continue
		# 롤토체스식 자동 시전: 기본 공격으로 마나가 가득 차면 다음 행동 대신 고유 스킬.
		# 전투는 멈추지 않는다 (멈춤 연출은 궁극기에만): 짧은 히트스톱 + 줌 펀치 + 시전자만 남기고 무대를 잠깐 살짝 어둡게.
		if u.mana_full() and not u.moving and _alive_count(foes) > 0:
			cast_skill(u)
			continue
		# 적 특수 스킬: 재사용 대기가 차면 이동·공격 대신 시전 (궁극기 연출 중엔 기다린다)
		if u.team == 1 and not u.moving and not ult.active and enemy_skills.tick(u, dt):
			continue
		u.atk_timer += dt
		u.move_timer += dt
		# 기믹 무리 특수 이동: 암살자 도약 · 추적자 질주 (사거리 밖일 때만, 안이면 평소처럼 때린다)
		if u.team == 1 and not u.moving and gimmicks.tick(u, dt):
			continue
		var target := tactics.pick_target(u, foes, team_units)
		if target == null:
			continue
		var move_ready := u.move_timer >= u.move_cd * u.cd_mult() and not u.moving and not u.floating   # 떠다니는 유닛은 VDFloatMove 가 움직인다
		# 공허 파편 도약: 멀리 있는 후열 영웅의 등 뒤로 뛰어든다
		if u.team == 1 and move_ready and flow.try_leap(u, foes):
			u.move_timer = 0.0
			continue
		# 거리 유지·오염 회피: 근접 적이 붙거나 발밑이 공허로 물들면 쏘기 전에 한 칸 물러난다 (재사용 대기 동안은 그 자리에서 쏜다)
		if move_ready:
			var back := tactics.retreat_cell(u, foes, target)
			if back != u.cell:
				u.move_timer = 0.0
				_step_unit(u, back, u.move_sec * 0.8)
				if u.id == "gunner":
					u.atk_timer = u.atk_cd * u.atk_cd_mult()   # 백스텝 사격: 내려서자마자 쏜다
				continue
		if u.is_healer:
			var patient := _most_wounded(u, team_units)
			if patient != null and u.atk_timer >= u.atk_cd * u.atk_cd_mult() and u.dist_to(patient) <= u.attack_range:
				heal_once(u, patient)
				continue
			if patient != null and u.dist_to(patient) > u.attack_range:
				target = patient   # 다친 아군 곁으로 간다 (사거리에 들 때까지)
		var d := u.dist_to(target)
		if d <= u.attack_range:
			if target.team == u.team:
				continue
			if u.atk_timer >= u.atk_cd * u.atk_cd_mult() and not u.moving:
				u.atk_timer = 0.0
				if u.team == 1 or VDHeroPose.WINDUP.has(u.id):
					_windup_attack(u, target)   # 움츠렸다가(영웅은 무기를 당겼다가) 때린다 (보스·망루는 발밑 경고)
				else:
					_do_attack(u, target)
		elif move_ready:
			var next := tactics.approach_cell(u, target, foes)
			if next != u.cell:
				u.move_timer = 0.0
				_step_unit(u, next, u.move_sec)
			else:
				u.move_timer = u.move_cd * u.cd_mult() * 0.6   # 막혔으면 이동 주기의 40% 뒤 다시 길을 찾는다 (매 틱 길찾기 방지)


## 힐러의 일반 행동: 회복 한 번 (전투 연습장 일반 공격 버튼도 쓴다).
func heal_once(u: VDUnit, patient: VDUnit) -> void:
	u.atk_timer = 0.0
	var amount := floorf(u.atk * 1.5 * (1.0 + u.heal_bonus + u.field_bonus))
	patient.heal(amount)
	u.gain_ult(u.ult_gain)
	u.gain_mana(u.mana_gain)
	u.attack_anim(patient.position)
	audio.play("heal")
	# 힐러 발밑 마법진 + 대상 위 회복 반짝임
	vfx.loop("magic_circle", ground_fx, u.position, 0.35, 0.2, 0.0, Color(0.6, 1.0, 0.7), Vector2(1.0, 0.5), 0.3, 1.5)
	vfx.spawn("heal", fx_root, _chest(patient), 0.5, 0.0, Color(0.8, 1.0, 0.8))
	dmg_log.spawn_status(_chest(patient), "+%d" % int(amount), Color(0.55, 1.0, 0.6), patient)


## 고유 스킬 시전 (마나를 비우고): 짧은 히트스톱 + 줌 펀치 + 시전자만 남기고 무대를 잠깐 살짝 어둡게. 전투 연습장 버튼도 쓴다.
func cast_skill(u: VDUnit) -> bool:
	u.mana = 0.0
	u.atk_timer = 0.0
	if not skills.cast(u):
		return false
	frame.pop_card(u.id, 0.6)
	camera.hitstop(0.13)
	camera.punch(0.04)
	camera.shake(0.12)
	ult.spotlight([u], 0.18, 0.5)
	return true


## 한 칸 이동 + 발밑 먼지(공허 파편은 대시 자국) + 대형 유닛 쿵.
func _step_unit(u: VDUnit, next: Vector2i, sec: float) -> void:
	if u.id == "fast":
		var left := VDData.to_screen(Vector2(next)).x < u.position.x
		vfx.spawn("dash", ground_fx, u.position, 0.85, 0.0, Color(0.85, 0.55, 1.0), Vector2.ONE, left, 1.8)
	else:
		vfx.spawn("dust", ground_fx, u.position, 1.0, 0.0, Color(1, 1, 1, 0.7))
	u.move_to_cell(next, sec)
	if u.is_boss or u.size > 1:
		juice.heavy_step(u, sec)


## 공격 한 번: 마나·모션·소리·이펙트·유물 트리거, 그리고 즉시 또는 투사체 비행 뒤 판정.
func _do_attack(u: VDUnit, target: VDUnit) -> void:
	u.gain_mana(u.mana_gain)
	u.attack_anim(target.position)
	_play_attack_sfx(u)
	_attack_vfx(u, target)
	if u.team == 0:
		relics.on_ally_attack(u, target)   # 유물 트리거: 평타 횟수·특정 영웅 공격
	if u.id == "mage":
		_delayed_hit(u, target, 0.22)   # 오브가 날아간 뒤 명중
	elif u.id == "gunner":
		_delayed_hit(u, target, VDGunBolt.FLIGHT)   # 볼트가 날아간 뒤 명중
	elif u.id == "skirmisher":
		_delayed_hit(u, target, SPORE_FLIGHT_SEC)
	elif u.id == "wraith" or u.id == "watcher" or u.id == "gazer":
		_delayed_hit(u, target, WRAITH_FLIGHT_SEC)
	elif u.id == "longneck":
		_delayed_hit(u, target, SHELL_FLIGHT_SEC)
	else:
		if u.id == "fast":
			u.move_timer = 0.0
		_apply_hit(u, target)


## 적 공격: WINDUP 초(게임 시간, 일시정지 중엔 멈춤) 동안 예비 동작 → 그때도 사정거리 안이면 공격.
func _windup_attack(u: VDUnit, target: VDUnit) -> void:
	var sec: float = WINDUP.get(u.id, VDHeroPose.WINDUP.get(u.id, 0.16))
	u.windup(target.position, sec)
	if u.is_boss or u.size > 1:
		juice.telegraph(target, sec)
	var run := _run_id
	await get_tree().create_timer(sec, false).timeout
	if not is_instance_valid(u):
		return
	u.release_windup()
	if run != _run_id or state != State.BATTLE or not u.alive or u.stun_timer > 0.0:
		return
	if not is_instance_valid(target) or not target.alive or u.dist_to(target) > u.attack_range:
		target = tactics.pick_target(u, allies if u.team == 1 else enemies, enemies if u.team == 1 else allies)
		if target == null or u.dist_to(target) > u.attack_range:
			return
	_do_attack(u, target)


## 피해 적용 + 명중 연출 + 숫자.
func _apply_hit(u: VDUnit, target: VDUnit) -> void:
	if not is_instance_valid(target) or not target.alive:
		return
	target.last_hit_by = u
	var crit := u.team == 0 and randf() < CRIT_CHANCE + u.crit_bonus
	var pos_mult := impact.flank(u, target)   # 등 뒤 x1.5 · 옆 x1.2
	# 마법사 오브는 비전(자홍) 피격 색, 나머지 평타는 물리(흰빛)
	var dealt := target.take_damage(u.atk * (CRIT_MULT if crit else 1.0) * pos_mult * (1.0 + u.dmg_bonus + u.field_bonus),"정수" if u.id == "mage" else "")
	if target.immune and dealt <= 0.0:
		# 환영 무적: 숫자 대신 IMMUNE
		dmg_log.spawn_status(_chest(target) + Vector2(0, -16), "IMMUNE", Color(0.8, 0.75, 1.0), target)
		gimmicks.count["immune_hits"] += 1
		if u.team == 0:
			u.gain_ult(u.ult_gain * 0.5)
		return
	if u.team == 0:
		u.gain_ult(u.ult_gain)
		if u.freeze_chance > 0.0 and target.alive and randf() < u.freeze_chance:
			target.stun(0.6, true)   # 빙결 스킬: 평타에 짧은 빙결
			vfx.spawn("burst", fx_root, _chest(target), 0.4, 0.0, Color(0.7, 0.9, 1.0))
	if u.id == "skirmisher" or u.id == "longneck" or u.id == "wraith":
		audio.play("ally_hurt", 0.1)
	if target.team == 0 and dealt > 0.0:
		# 피해 비율이 클수록·보스일수록 조금 더 세게 (기본은 아주 미세하게)
		hurt_glitch.kick(minf(1.0, 0.4 + dealt / maxf(target.max_hp, 1.0) * 1.5 + (0.3 if u.is_boss else 0.0)), target.id)
		audio.voice(target.id, "hurt")   # 캐릭터 피격 추임새 (영웅별 쿨다운은 VDAudio)
	_hit_vfx(u, target)
	_hit_feel(u)
	impact.after_hit(u, target)   # 넉백 → 벽꿍·충돌
	if u.team == 0:
		shockwave.add(_chest(target), "heavy" if crit or u.id == "knight" else "light")
	elif u.is_boss:
		shockwave.add(_chest(target), "heavy")
	focus.add_heat(target.position, 1.6 if (u.is_boss or target.is_boss) else 1.0)   # 명중한 곳으로 시선이 조금 끌린다
	dmg_log.spawn(_chest(target) + Vector2(0, -16), int(dealt), crit or u.atk >= 50.0 or u.is_boss, target)
	if crit:
		# 치명타: 묵직한 스파크 + 짧은 멈춤 + 줌 펀치 + CRITICAL! 글자
		vfx.spawn("hit_light", fx_root, _chest(target), 3.3, randf() * TAU, Color(1.0, 0.8, 0.5))
		camera.hitstop(0.07)
		camera.punch(0.035)
		camera.shake(0.2)
		juice.pop_world(_chest(target) + Vector2(randf_range(-24, 24), -96), "CRITICAL!", Color(1.0, 0.55, 0.3), 24.0, 0.2)
		audio.play("knight_hit", 0.05, -3.0, 1.4)


## 분대 카드 탭: 전투 중엔 궁극기, 그 밖(배치·회복·길 선택)엔 그 영웅의 스킬창을 연다/닫는다.
func _on_card_pressed(hid: String) -> void:
	if state == State.BATTLE:
		try_ult(hid)
	elif skill_window:
		audio.play("click")
		skill_window.toggle(hid)


## 레벨업 연출 (TrioChess: 기둥 + 금빛 플래시 + LEVEL UP! + 차임): 금빛 폭발·번개 기둥·글자·카드 톡.
func _on_leveled(u: VDUnit, lv: int) -> void:
	if not is_instance_valid(u) or not u.is_inside_tree():
		return
	var at := _chest(u)
	vfx.spawn("burst", fx_root, at, 0.8, 0.0, Color(1.0, 0.9, 0.5))
	vfx.spawn("lightning", fx_root, u.position + Vector2(0, u._top * 0.9), 0.7, 0.0, Color(1.0, 0.92, 0.6))
	vfx.spawn("shockwave", ground_fx, u.position, 0.7, 0.0, Color(1.0, 0.85, 0.4), Vector2(1.0, 0.5))
	juice.pop_world(at + Vector2(0, -90), "LEVEL UP!", Color(1.0, 0.85, 0.35), 26.0, 0.5)
	dmg_log.spawn_status(at + Vector2(0, -40), "Lv.%d" % lv, Color(1.0, 0.95, 0.6), u)
	audio.play("chime", 0.0, -2.0, 1.25)
	u._bar_kick = 1.0
	u.cast_pulse()
	frame.pop_card(u.id, 0.7)
	if skill_window and skill_window.visible and skill_window.hero == u.id:
		skill_window.refresh()


## 분대 카드 탭: 궁극기 게이지가 찼으면 시전 (조준이 필요하면 조준 화면부터). 아니면 거절 소리 + 남은 충전량.
func try_ult(hid: String) -> void:
	# 패링: 이 영웅이 지금 보스의 패링 공격 대상이면 궁극기 대신 받아친다 (게이지와 상관없이)
	if state == State.BATTLE and parry.try_parry(hid):
		return
	if state != State.BATTLE or ult.active or ult_aim.active:
		return
	var u: VDUnit = null
	for a in allies:
		if a.id == hid:
			u = a
	if u == null or not u.alive:
		return
	# 고유 스킬 시전 중이어도 받는다: 궁극기는 그 스킬이 끝난 뒤 이어서 나간다 (_cast_ult)
	if not u.ult_full() or u.stun_timer > 0.0 or _alive_count(enemies) == 0:
		audio.play("denied", 0.0, -2.0)
		var why := "기절 중" if u.stun_timer > 0.0 else "충전 %d%%" % int(u.ult / VDData.MAX_ULT * 100.0)
		dmg_log.spawn_status(_chest(u) + Vector2(0, -30), why, Color(0.8, 0.78, 0.9), u)
		return
	var kind: String = VDData.ULTS[u.id]["aim"]
	if kind == "":
		_cast_ult(u, null)
	else:
		ult_aim.begin(u, kind)


## 지금 이 영웅의 궁극기를 쓸 수 있는가 (try_ult 가 거절하지 않을 조건).
func ult_ready(hid: String) -> bool:
	for a in allies:
		if a.id == hid:
			return a.alive and a.ult_full() and a.stun_timer <= 0.0 and _alive_count(enemies) > 0
	return false


## 테스트용 자동 조준: 건너는 가장 가까운 적 쪽, 마법사는 가장 가까운 적.
func _auto_aim(u: VDUnit) -> Variant:
	var e := _nearest(u, enemies)
	match VDData.ULTS[u.id]["aim"]:
		"cone":
			return e.position if e else u.position + Vector2(100, 0)
		"enemy":
			return e
	return null


## 궁극기: TrioChess 처럼 intro(전투 정지·레터박스·포즈, 마법사는 전면 컷인) → 궁극기 → 어두운 무대를 hold 초 유지.
## aim: 건너 = 조준한 월드 좌표, 마법사 = 첫 대상, 그 외 null.
func _cast_ult(u: VDUnit, aim: Variant) -> void:
	var run := _run_id
	var ud: Dictionary = growth.ult_def(u.id)
	u.ult = 0.0
	frame.pop_card(u.id, 1.0)   # 분대 카드가 앞으로 튀어나온다
	var handle: Dictionary = await ult.intro(u, ud["name"], u.color)
	# 고유 스킬이 아직 돌고 있으면(도약·연사) 끝날 때까지 어두운 무대에서 잠깐 기다린다
	var waited := 0.0
	while is_instance_valid(u) and u.casting and waited < 1.5:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	if not is_instance_valid(u):
		return
	if run != _run_id or not u.alive or state != State.BATTLE or not ults.cast(u, aim):
		u.ult = VDData.MAX_ULT   # 못 썼으면 게이지를 돌려준다
		ult.release(handle, 0.0)
		return
	ult.release(handle, float(ULT_HOLD.get(u.id, 1.1)))


## 가장 먼저 쓰러져 아직 누워 있는 아군 (없으면 null).
func first_fallen() -> VDUnit:
	for a in fallen:
		if is_instance_valid(a) and not a.alive:
			return a
	return null


## pref 가 비어 있으면 pref, 아니면 near 주변에서 pref 에 가장 가까운 빈 칸 (방 안).
func free_cell_near(pref: Vector2i, near: Vector2i) -> Vector2i:
	if VDMap.in_room(room, pref) and not _occupied(pref):
		return pref
	var best := near
	var best_d := 1 << 30
	for r in range(1, 6):
		for a in range(-r, r + 1):
			for c in range(-r, r + 1):
				var cell := near + Vector2i(a, c)
				if not VDMap.in_room(room, cell) or _occupied(cell):
					continue
				var d := VDData.manhattan(cell, pref) * 10 + VDData.manhattan(cell, near)
				if d < best_d:
					best_d = d
					best = cell
		if best_d < (1 << 30):
			break
	return best


## 힐러 궁극기로 일어난 아군: 카드의 '전투 불능' 도장을 걷고 쓰러진 목록에서 뺀다.
func on_hero_revived(u: VDUnit) -> void:
	fallen.erase(u)
	frame.card_up(u.id)
	audio.play("chime", 0.0, 2.0, 1.2)
	print("[VD] hero revived: %s" % u.display_name)


## 설정 메뉴 · F8: 마법사 초궁극기 컷인만 재생한다 (스킬은 쓰지 않음). 실제 시전처럼 그동안 전투를 멈춘다.
var _preview_cutin := 0


func preview_super_cutin() -> void:
	if ult.active:
		return
	ult.active = true
	var tree := get_tree()
	var was := tree.paused
	tree.paused = true
	# 누를 때마다 다음 영웅 (건너 → 마법사 → 기사 → 힐러)
	var ids: Array = VDUltCinematic.SUPER_CUTIN.keys()
	var id: String = ids[_preview_cutin % ids.size()]
	_preview_cutin += 1
	var h: Dictionary = VDData.HEROES[id]
	await ult.super_cutin(VDData.ULTS[id]["name"], h["name"], h["color"], VDUltCinematic.SUPER_CUTIN[id], id)
	tree.paused = was
	if not is_inside_tree():
		return
	ult.active = false


## 유물 피해: 영웅 피해와 같은 길(take_damage·숫자·명중 연출)을 쓴다. 처치도 같은 died 시그널로 돈다.
func relic_damage(target: VDUnit, amount: float, relic_id: String, col: Color, big: bool) -> float:
	if not is_instance_valid(target) or not target.alive or amount <= 0.0:
		return 0.0
	target.last_hit_by = relic_id
	# 유물 태그(번개·화염·서리·정수)가 곧 피격 색. 도트 피해(big = false)는 약하게 번쩍인다
	var dealt := target.take_damage(amount, String(VDRelicData.def(relic_id).get("tag", "")), 1.0 if big else HitFx.g("tick_k"))
	var at := _chest(target)
	if big:
		vfx.spawn("hit_light", fx_root, at, 1.4, randf() * TAU, col)
		focus.add_heat(target.position, 0.8)
	dmg_log.spawn(at + Vector2(0, -16), int(dealt), big, target)
	return dealt


## 구역 클리어 보상: (확률) 침식 → RELIC_EVERY 구역마다 유물 3택1 제시 (슬롯 카드가 섞인다. 칸은 자동으로 열리지 않는다).
func _relic_rewards() -> void:
	var boss_room := VDData.is_boss_stage(stage)
	var corrupted := false
	if boss_room or randf() < VDRelicData.CORRUPT_CHANCE:
		var c := relic_board.corrupt_random()
		if c.x >= 0:
			corrupted = true
			_show_msg("공허가 성좌판을 침식했습니다!  (우클릭으로 정화)", 2.0)
			screen_glitch.kick(1.0, "corrupt")   # 화면 전체가 길게 찢어지며 어두워진다
			print("[VD] relic board corrupted at %s" % str(c))
	if not relic_reward_due():
		var left := VDRelicData.RELIC_EVERY - stage % VDRelicData.RELIC_EVERY
		if not corrupted:
			_show_msg("다음 유물까지 %d구역" % left, 1.6)
		print("[VD] no relic this room (next in %d)" % left)
		return
	var locked := relic_board.locked_count()
	if locked == 0 and relic_board.slot_count() > 0:
		# 더 열 칸이 없는데 슬롯이 남았다: 정수로 바꿔 준다
		var n := relic_board.take_slots()
		_on_essence_arrive(n * VDRelicData.SLOT_REFUND)
		_show_msg("성좌판이 가득 차 남은 슬롯 %d개를 정수 %d 로 바꿨습니다" % [n, n * VDRelicData.SLOT_REFUND], 2.0)
	var ids := VDRelicData.roll_offer(relic_board.rng, locked, stage == VDRelicData.RELIC_EVERY, relic_board.open_count() == 0)
	relic_hud.offer(ids)
	print("[VD] relic offer: %s  open=%d locked=%d fired=%s" % [str(ids), relic_board.open_count(), locked, str(relics.fire_count)])


## 연출 박자용 대기: 실제 시간 (슬로모션·히트스탑·배속과 무관).
func _wait_real(sec: float) -> void:
	await get_tree().create_timer(maxf(sec, 0.0), true, false, true).timeout


## 이번 구역 클리어에 유물 보상이 있는가 (RELIC_EVERY 번째 구역마다).
func relic_reward_due() -> bool:
	return stage % VDRelicData.RELIC_EVERY == 0


## 타격감: 약한 카메라 셰이크 + 짧은 히트스탑. 아군의 묵직한 공격(기사)·보스 공격은 조금 더 세게.
## 적이 아군을 때릴 때는 셰이크만 (보스만 히트스탑).
func _hit_feel(u: VDUnit) -> void:
	if u.team == 0:
		# 배율은 vd_hit_fx.gd "7 화면" (연출 연구실 "몬스터 피격")
		var heavy := u.id == "knight"
		camera.shake((0.45 if heavy else 0.32) * HitFx.g("shake_k"))
		if HitFx.g("hitstop_k") > 0.0:
			camera.hitstop((0.05 if heavy else 0.03) * HitFx.g("hitstop_k"))
	else:
		camera.shake(0.5 if u.is_boss else 0.28)
		if u.is_boss:
			camera.hitstop(0.05)


func _delayed_hit(u: VDUnit, target: VDUnit, delay: float) -> void:
	var run := _run_id
	var shot_wave := wave
	await get_tree().create_timer(delay, false).timeout   # 궁극기 연출로 트리가 멈춘 동안 날아가던 탄이 맞지 않게
	if run != _run_id or wave != shot_wave or state != State.BATTLE or not is_instance_valid(u):
		return
	_apply_hit(u, target)


## 유닛의 가슴 높이(비주얼 위쪽 끝의 55%). 원화 유닛은 150px 안팎, 박스 유닛은 70px.
func _chest(u: VDUnit) -> Vector2:
	return u.position + Vector2(0, u._top * 0.55)


## 공격 순간의 연출(공격자 쪽): 기사 베기 궤적 / 건너 총구 섬광 + 에너지 볼트 / 마법사 오브 투사체.
func _attack_vfx(u: VDUnit, target: VDUnit) -> void:
	var from := _chest(u)
	var to := _chest(target)
	var dir := (to - from).normalized()
	match u.id:
		"knight":
			# 검기: 기사 가슴 앞에서 대상 쪽으로 위→아래 초승달. 바깥 날이 대상에 닿도록 크기를 거리에 맞춘다
			# (근접 한 칸 기준. 멀리 있는 대상이라도 너무 커지지 않게 묶는다)
			var reach := clampf(from.distance_to(to), 60.0, 120.0)
			var center := from + dir * reach * 0.25
			VDSwordSlash.spawn(fx_root, center, reach * 0.75 / 0.42, dir.angle(), dir.x < 0.0)
		"gunner":
			var muzzle := from + dir * 40.0
			vfx.spawn("gun_flash", fx_root, muzzle, 1.2, dir.angle())
			VDGunBolt.fire(fx_root, muzzle, to)   # 에너지 볼트 (비주얼 셰이더). 명중은 _do_attack 이 비행 시간만큼 늦춘다
		"mage":
			juice.trail(vfx.projectile("orb", fx_root, from + Vector2(0, -10), to, 0.22, 0.2, Color(0.85, 0.6, 1.0), 8.0), Color(0.75, 0.5, 1.0), 10.0)
		"skirmisher":
			var muzzle := from + Vector2(u._facing * 21.0, 0.0)
			var tint := Color(1.0, 0.35, 0.8)
			vfx.spawn("hit_light", fx_root, muzzle, 1.0, dir.angle(), tint)
			juice.trail(vfx.projectile("orb", fx_root, muzzle, to, SPORE_FLIGHT_SEC, 0.14, tint, 8.0, _homing(target, to)), tint, 7.0)
		"wraith":
			# 후드 속 핵에서 보랏빛 공허 구체
			var muzzle := u.position + Vector2(u._facing * 10.0, u._top * 0.46)
			var tint := Color(0.85, 0.4, 1.0)
			vfx.spawn("hit_light", fx_root, muzzle, 1.3, (to - muzzle).angle(), tint)
			juice.trail(vfx.projectile("orb", fx_root, muzzle, to, WRAITH_FLIGHT_SEC, 0.17, tint, 9.0, _homing(target, to)), tint, 9.0)
		"gazer":
			# 가장 큰 눈에서 붉은 자홍 광탄
			var muzzle := VDParry.eye_of(u)
			var tint := Color(1.0, 0.3, 0.5)
			vfx.spawn("hit_light", fx_root, muzzle, 1.6, (to - muzzle).angle(), tint)
			juice.trail(vfx.projectile("orb", fx_root, muzzle, to, WRAITH_FLIGHT_SEC, 0.2, tint, 9.0, _homing(target, to)), tint, 10.0)
		"watcher":
			# 큰 눈에서 붉은 주황 광탄 (패링 예고 별이 뜨는 그 눈)
			var muzzle := VDParry.eye_of(u)
			var tint := Color(1.0, 0.45, 0.3)
			vfx.spawn("hit_light", fx_root, muzzle, 1.6, (to - muzzle).angle(), tint)
			juice.trail(vfx.projectile("orb", fx_root, muzzle, to, WRAITH_FLIGHT_SEC, 0.2, tint, 9.0, _homing(target, to)), tint, 10.0)
		"longneck":
			# 머리 위 쌍포에서 붉은 포탄 두 발 (원화 머리 끝 근처에서 바라보는 쪽으로 살짝 벌려서)
			var tint := Color(1.0, 0.3, 0.38)
			for side in [-1.0, 1.0]:
				var muzzle := u.position + Vector2(u._facing * 18.0 + side * 22.0, u._top * 0.9)
				vfx.spawn("hit_light", fx_root, muzzle, 1.2, (to - muzzle).angle(), tint)
				juice.trail(vfx.projectile("orb", fx_root, muzzle, to, SHELL_FLIGHT_SEC, 0.18, tint, 10.0, _homing(target, to)), tint, 9.0)
		_:
			pass


## 유도탄이 따라갈 지점: 대상의 가슴, 대상이 쓰러졌거나 해제됐으면 처음 겨눈 자리.
## 대상은 약한 참조로 잡는다 (람다가 유닛을 직접 잡으면 비행 중 해제될 때 "Lambda capture was freed" 오류가 난다).
func _homing(target: VDUnit, fallback: Vector2) -> Callable:
	var wr: WeakRef = weakref(target)
	return func() -> Vector2:
		var t := wr.get_ref() as VDUnit
		return _chest(t) if t != null and t.alive else fallback


## 명중 순간의 연출(대상 쪽): 직업별 스파크, 적의 공격은 보라-붉은 스파크.
## 아군이 몬스터를 때릴 때는 카툰 피격(vd_cartoon_hit_fx.gd "on")이 켜져 있으면 직업별 스파크 대신 그것을 쓴다:
## 공격자 → 대상 방향으로 터지고, 기사는 강타 크기.
func _hit_vfx(u: VDUnit, target: VDUnit) -> void:
	var at := _chest(target)
	if u.team == 0 and target.team == 1 and CartoonHit.enabled():
		CartoonHit.spawn(fx_root, at, target.position - u.position, u.id == "knight")
		return
	if u.id == "skirmisher":
		vfx.spawn("burst", fx_root, at, 0.35, 0.0, Color(1.0, 0.35, 0.8))
		juice.scorch(target.position + Vector2(randf_range(-10, 10), 4), Color(1.0, 0.35, 0.8), 18.0)
		return
	if u.id == "wraith":
		vfx.spawn("burst", fx_root, at, 0.4, 0.0, Color(0.85, 0.4, 1.0))
		juice.scorch(target.position + Vector2(randf_range(-10, 10), 4), Color(0.8, 0.35, 1.0), 20.0)
		return
	if u.id == "gazer":
		vfx.spawn("burst", fx_root, at, 0.5, 0.0, Color(1.0, 0.3, 0.5))
		juice.scorch(target.position + Vector2(randf_range(-10, 10), 4), Color(1.0, 0.3, 0.5), 24.0)
		return
	if u.id == "watcher":
		vfx.spawn("burst", fx_root, at, 0.5, 0.0, Color(1.0, 0.45, 0.3))
		juice.scorch(target.position + Vector2(randf_range(-10, 10), 4), Color(1.0, 0.45, 0.3), 24.0)
		return
	if u.id == "longneck":
		vfx.spawn("burst", fx_root, at, 0.5, 0.0, Color(1.0, 0.35, 0.4))
		vfx.spawn("dust", ground_fx, target.position, 1.2, 0.0, Color(1, 0.8, 0.8, 0.8))
		juice.scorch(target.position + Vector2(randf_range(-10, 10), 4), Color(1.0, 0.35, 0.4), 26.0)
		return
	if u.team == 1:
		vfx.spawn("hit_light", fx_root, at, 1.8, randf() * TAU, Color(1.0, 0.55, 0.75))
		return
	match u.id:
		"knight":
			vfx.spawn("hit_light", fx_root, at, 2.7, randf_range(-0.6, 0.6), Color(0.9, 0.95, 1.0))   # 어두운 꽃 모양 hit_heavy 는 2026-11-09 사용자 요청으로 삭제
		"gunner":
			vfx.spawn("gun_hit", fx_root, at, 0.55, randf() * TAU)
		"mage":
			vfx.spawn("burst", fx_root, at, 0.45, 0.0, Color(0.85, 0.55, 1.0))
		_:
			vfx.spawn("hit_light", fx_root, at, 1.4, randf() * TAU)


## 공격자별 효과음: 아군은 직업별 공격음 + 명중음, 적은 공격음 + 아군 피격음.
func _play_attack_sfx(u: VDUnit) -> void:
	if u.team == 1:
		audio.play("enemy_attack", 0.12)
		if u.id != "skirmisher" and u.id != "longneck" and u.id != "wraith" and u.id != "watcher" and u.id != "gazer":
			audio.play("ally_hurt", 0.1)
		return
	match u.id:
		"knight":
			audio.play("knight_attack", 0.08, 0.0, 1.3)
			audio.play("knight_hit", 0.1)
		"gunner":
			audio.play("gun", 0.08)
			audio.play("gun_hit", 0.1)
		"mage":
			audio.play("mage_cast", 0.05)
			audio.play("mage_hit", 0.1)
		_:
			audio.play("enemy_hit", 0.1)


func _nearest(u: VDUnit, foes: Array[VDUnit]) -> VDUnit:
	var best: VDUnit = null
	var best_d := 1 << 30
	for f in foes:
		if not f.alive:
			continue
		var d := u.dist_to(f)
		if d < best_d:
			best_d = d
			best = f
	return best


func _most_wounded(healer: VDUnit, team_units: Array[VDUnit]) -> VDUnit:
	var best: VDUnit = null
	var best_ratio := 0.75
	for a in team_units:
		if not a.alive or a == healer:
			continue
		var r := a.hp / a.max_hp
		if r < best_ratio:
			best_ratio = r
			best = a
	return best


## 현재 방 안에서만 한 칸 전진 (전투는 방 안에 갇힌다).
## 대형 유닛은 footprint 전체가 들어갈 자리로만 움직인다.
func _step_toward(u: VDUnit, target: VDUnit) -> Vector2i:
	var best := u.cell
	var best_d := u.dist_to(target)
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nc: Vector2i = u.cell + dir
		if not _fits(u, nc):
			continue
		var nd := VDData.rect_dist(nc, u.size, target.cell, target.size)
		if nd < best_d:
			best_d = nd
			best = nc
	return best


# ---------------------------------------------------------------- hud / camera

## 몸통(가슴)에서 터진 충격점을 그 유닛의 발밑 바닥점으로 내린다 (바닥 정수 물리는 바닥 거리로 잰다).
func _floor_under(at: Vector2) -> Vector2:
	for u in allies + enemies:
		if is_instance_valid(u) and absf(at.x - u.position.x) < 60.0 and at.y <= u.position.y + 10.0 and at.y >= u.position.y + u._top - 30.0:
			return u.position
	return at


func _process(delta: float) -> void:
	essence_drops.tick(delta)
	for a in allies:
		var stat := "Lv.%d  HP %d/%d  ATK %d" % [a.level, int(a.hp), int(a.max_hp), int(a.atk)] if a.alive else "전투 불능"
		frame.set_hero(a.id, a.hp / a.max_hp, a.mana / VDData.MAX_MANA, a.mana_full(), a.alive, stat, a.ult / VDData.MAX_ULT, a.ult_full() and state == State.BATTLE,
			growth.level_of(a.id), growth.sp_of(a.id) if state != State.BATTLE else 0)
	_update_wave_bar()
	if _boss_bar.visible:
		for e in enemies:
			if e.is_boss:
				var v := 100.0 * e.hp / e.max_hp
				if v < _boss_bar.value - 0.01:
					_boss_ghost_hold = 0.35
					VDJuice.bump(_boss_bar, 0.12)
				_boss_bar.value = v
				break
		# 잔상: 잠깐 버텼다가 따라 내려온다 (실제 시간)
		_boss_ghost_hold -= get_process_delta_time() / maxf(Engine.time_scale, 0.05)
		if _boss_ghost.value < _boss_bar.value or _boss_ghost_hold <= 0.0:
			_boss_ghost.value = maxf(_boss_bar.value, move_toward(_boss_ghost.value, _boss_bar.value, 0.5 + (_boss_ghost.value - _boss_bar.value) * 0.08))
	# 카메라: 전투 중엔 가장 치열한 곳(+ 전장 폭에 맞춘 줌), 이동 중엔 분대 중심, 그 외엔 현재 방 중심.
	# 실제 시간으로 움직인다(히트스탑·배속과 무관). 상태 전환 줌 트윈이 도는 동안은 트윈이 줌을 맡는다.
	# delta / time_scale 는 히트스탑이 시작·끝나는 프레임에 최대 25배로 튀므로 시계로 잰다
	var now_us := Time.get_ticks_usec()
	var dt := clampf((now_us - _cam_clock_us) / 1000000.0, 0.0, 0.1) if _cam_clock_us > 0 else 0.0
	_cam_clock_us = now_us
	var zoom_tweening := _zoom_tween != null and _zoom_tween.is_running()
	if zoom_tweening or state != State.BATTLE:
		focus.sync_zoom(camera.base_zoom.x)
	match state:
		State.BATTLE:
			focus.track(dt, allies, enemies, _cam_target, get_viewport_rect().size, BATTLE_ZOOM * _room_zoom())
			if not zoom_tweening:
				camera.base_zoom = Vector2(focus.zoom, focus.zoom)
		State.TRAVEL:
			var sum := Vector2.ZERO
			var n := 0
			for a in allies:
				if a.alive:
					sum += a.position
					n += 1
			if n > 0:
				_cam_target = sum / n
			focus.follow(dt, _cam_target, true)
		_:
			focus.follow(dt, _cam_target)
	camera.position = focus.pos


func _refresh_wave_label() -> void:
	var text := "스테이지 %d  ·  WAVE %d/%d" % [stage, wave_in_stage, VDData.waves_in_stage(stage)]
	if VDData.is_boss_stage(stage):
		text += "  ·  보스"
	if gimmick != "" and gimmick_wave >= wave_in_stage and state != State.PLACEMENT:
		text += "  ·  기믹: " + String(VDData.GIMMICKS[gimmick]["name"]) + ("" if is_gimmick_wave() else " (%d차)" % gimmick_wave)
	_lbl_wave.text = text
	frame.set_stage(wave_in_stage, stage)


func _refresh_essence() -> void:
	_lbl_essence.text = "공허 정수  %d" % essence
	_place_essence_icon()


## 정수 아이콘을 글자 바로 왼쪽에 둔다 (라벨은 오른쪽 정렬).
func _place_essence_icon() -> void:
	if _essence_icon == null:
		return
	var font := _lbl_essence.get_theme_font("font")
	var fs := _lbl_essence.get_theme_font_size("font_size")
	var w := font.get_string_size(_lbl_essence.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if font else 0.0
	_essence_icon.position = Vector2(_lbl_essence.size.x - w - 46.0, (_lbl_essence.size.y - 40.0) * 0.5)


## 날아온 정수가 도착: 숫자가 오르고 아이콘만 하나씩 꿀꺽 삼키듯 쫀득하게 출렁인다 (글자 크기는 그대로).
##   가로로 납작하게 눌렸다(삼킴) → 세로로 길게 부풀고 → 탄성으로 출렁이며 제자리. 동시에 하얗게 번쩍했다 원래 색.
##   반짝이 몇 개가 아이콘에서 튀어 나간다.
## 연달아 도착하면 이전 출렁임을 끊고 지금 크기에서 다시 시작한다 (겹친 Tween 이 크기를 꼬지 않게).
var _essence_icon_tw: Tween


func _on_essence_arrive(amount: int) -> void:
	essence += amount
	_refresh_essence()
	var ic := _essence_icon
	ic.pivot_offset = ic.size * 0.5
	if _essence_icon_tw:
		_essence_icon_tw.kill()
	_essence_icon_tw = ic.create_tween().set_ignore_time_scale(true)
	_essence_icon_tw.tween_property(ic, "scale", Vector2(1.45, 0.72), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_essence_icon_tw.tween_property(ic, "scale", Vector2(0.86, 1.5), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_essence_icon_tw.tween_property(ic, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_essence_icon_tw.parallel().tween_method(func(v: float) -> void: (ic.material as ShaderMaterial).set_shader_parameter("flash", v),
		1.0, 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	(ic.material as ShaderMaterial).set_shader_parameter("flash", 1.0)
	var at := ic.get_global_rect().get_center()
	for i in 3:
		VDEssenceDrops.sparkle(hud_root, at + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 26.0), 0.8)


## 안내 띠: 세로로 납작하게 펼쳐지며 나타나 톡 튀고, 머문 뒤 위로 접히며 사라진다. 실제 시간.
func _show_msg(text: String, dur := 1.6) -> void:
	_lbl_msg.text = text
	_lbl_msg.pivot_offset = _lbl_msg.size * 0.5
	if _msg_tween:
		_msg_tween.kill()
	_lbl_msg.modulate.a = 0.0
	_lbl_msg.scale = Vector2(1.15, 0.2)
	_msg_tween = create_tween().set_ignore_time_scale(true)
	_msg_tween.tween_property(_lbl_msg, "modulate:a", 1.0, 0.08)
	_msg_tween.parallel().tween_property(_lbl_msg, "scale", Vector2(0.97, 1.12), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_msg_tween.tween_property(_lbl_msg, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_msg_tween.tween_interval(dur)
	_msg_tween.tween_property(_lbl_msg, "scale", Vector2(1.05, 0.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_msg_tween.parallel().tween_property(_lbl_msg, "modulate:a", 0.0, 0.22)


## 정수 소모: 숫자가 붉게 번쩍이며 움찔하고, -N 이 아이콘에서 떨어져 나간다.
func spend_essence(amount: int) -> void:
	essence -= amount
	_refresh_essence()
	VDJuice.bump(_lbl_essence, -0.5)
	var tw := _lbl_essence.create_tween().set_ignore_time_scale(true)
	_lbl_essence.modulate = Color(1.6, 0.5, 0.6)
	tw.tween_property(_lbl_essence, "modulate", Color.WHITE, 0.4)
	var at := _essence_icon.get_global_rect().get_center()
	var l := juice.pop_text(at + Vector2(0, 30), "-%d" % amount, Color(1.0, 0.45, 0.55), 30.0, 0.15)
	var drop := l.create_tween().set_ignore_time_scale(true)
	drop.tween_property(l, "position:y", l.position.y + 40.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _toggle_speed() -> void:
	audio.play("click")
	VDJuice.bump(_btn_speed, 1.0)
	# x1 → x1.5 → x2 → x1. 히트스탑 중이어도 배속이 꼬이지 않게 camera 를 거친다
	var cur := camera.game_speed()
	var next: float = GAME_SPEEDS[0]
	for sp in GAME_SPEEDS:
		if sp > cur + 0.01:
			next = sp
			break
	camera.set_game_speed(next)
	_refresh_speed_label()


func _refresh_speed_label() -> void:
	var sp := camera.game_speed()
	_btn_speed.text = "속도 x%s" % ("%.1f" % sp).trim_suffix(".0")
	# 배속이 높을수록 글자가 뜨거운 색
	var hot := clampf((sp - 1.0) / 1.0, 0.0, 1.0)
	_btn_speed.add_theme_color_override("font_color", Color.WHITE.lerp(Color(1.0, 0.55, 0.3), hot))
	_btn_speed.add_theme_color_override("font_hover_color", Color.WHITE.lerp(Color(1.0, 0.65, 0.4), hot))


## 스테이지 진행도: 이 웨이브 적(enemies[_wave_from..])의 남은 체력 합 / 총 체력 (계획값과 실제 최대 체력 합 중 큰 쪽) + 웨이브 순서.
## 배치·등장·전투 중에만 보인다.
func _update_wave_bar() -> void:
	var show := state == State.PLACEMENT or state == State.SPAWNING or state == State.BATTLE
	var cur := 0.0
	var total := 0.0
	var alive := 0
	if show:
		for i in range(mini(_wave_from, enemies.size()), enemies.size()):
			var e := enemies[i]
			if not is_instance_valid(e):
				continue
			total += e.max_hp
			if e.alive:
				cur += maxf(e.hp, 0.0)
				alive += 1
		total = maxf(total, _wave_plan)
	_wave_bar.visible = show and total > 0.0
	if _wave_bar.visible:
		_wave_bar.set_values(cur, total, alive, wave_in_stage, VDData.waves_in_stage(stage), _landing)
