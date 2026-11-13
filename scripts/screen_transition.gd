## 팝아트 그래픽 와이프 화면 전환 (2026-11-09): 노랑·보라·자홍·어두운 보라 색판이 시간차를 두고 한 방향으로 화면을 통째로
## 쓸고 들어와 덮고, 장면을 바꾼 뒤 같은 방향으로 꼬리를 끌며 빠져나간다. 그림은 전부 shaders/comic_wipe.tres (VisualShader,
## tools/shaders/build_comic_wipe.gd 가 생성) 의 progress 0 → 1 이 그린다. 0.5 가 완전히 덮인 순간.
## 프리셋 다섯 가지(PRESET_NAMES): 0 슬래시 스택 · 1 슬라이스 (둘은 셰이더 uniform preset) · 2 번개 닫힘 (원화 프레임 그대로) ·
## 3 번개 일섬 (기본값) · 4 번개 재단 — 3·4 는 원화의 흐름을 다시 연출한 것 (scripts/screen_transition_strike.gd + shaders/lightning_wipe.gdshader). 설정 메뉴 [화면 전환] 에서 고르고 user://transition.cfg 에 저장.
## 번개 닫힘은 셰이더가 아니라 사용자가 그린 프레임(화면 컨셉_4.psd '화면 트랜지션')의 도형을 보간하는 scripts/screen_transition_lightning.gd 가 그린다:
## 번개가 대각선으로 치고 들어오고 → 모서리의 어두운 판이 그 대각선으로 닫히고 → 어두워진 뒤(0.5) → 같은 애니메이션을 되감아 열린다. 덮기/걷기 시간은 조절값 lt_in_dur/lt_out_dur.
## 5 워프 다이브 (2026-11-12): 환자의 머릿속으로 빨려 들어가는 하이퍼스페이스 연출. shaders/warp_dive.tres (VisualShader, tools/shaders/build_warp_dive.gd 가 생성).
## 장면이 방사형으로 늘어나며 빛줄기 터널이 되고(0.5), 터널 끝의 빛에서 새 장면이 열린다. 5·6 은 일반 화면 전환이 아니라 **전투 진입 전환**이다: 전투를 시작할 때만 쓰고(SceneSwitcher SCENES 의 "enter_wipe"), 설정 메뉴 [전투 진입 전환] 에서 따로 고른다 (ENTER_PRESETS · get_enter).
## 6 워프 러시 (2026-11-12): 워프 다이브의 카툰 버전 — 훨씬 빠르고, 집중선·톱니 테두리·잉크 선·평면 색 띠·스톱모션 박자. shaders/warp_rush.tres (tools/shaders/build_warp_rush.gd).
## 색·망점 간격·덮기/걷기 시간은 scripts/screen_transition_fx.gd 의 조절값(연출 연구실 "화면 전환", user://transition_fx.json)을 쓴다.
## 연구실에서는 preset_override 로 프리셋을 지정하고 layer 를 낮춰(패널 아래) 반복 재생한다. 시계는 Engine.time_scale 을 따라 연구실 배속이 먹는다.
## 흐름: start() → progress 0 → 0.5 (IN_DUR) → covered 신호(여기서 SceneSwitcher 가 씬을 바꾼다) → reveal() → 0.5 → 1 (OUT_DUR) → finished → 스스로 지워짐.
## 시계는 UIIntro 처럼 프레임 간격을 MAX_DT 로 잘라 쓴다: 씬 전환 직후의 긴 프레임에 걷히는 연출이 통째로 넘어가지 않게.
## 캡처·연구용으로는 preview(p) 로 progress 를 직접 둘 수 있다. 모양은 전환마다 seed 가 달라 조금씩 다르다.
## 새 씬의 등장 연출은 SceneSwitcher.intro_lead() (= time_to_open()) 만큼 늦춰 시작한다: 가운데 구멍이 다 열린(progress OPEN_AT)
## 순간부터 안개·HUD 연출이 이어지도록. 이 시계와 UIIntro 시계는 둘 다 MAX_DT 로 잘라 돌아 긴 프레임에도 어긋나지 않는다.
extends CanvasLayer

signal covered    # progress 가 0.5 에 닿아 화면이 다 가려진 상태 (여기서 씬을 바꾼다)
signal finished   # 다 걷히고 지워지기 직전

const SHADER := preload("res://shaders/comic_wipe.tres")
const Fx := preload("res://scripts/screen_transition_fx.gd")
const CFG_PATH := "user://transition.cfg"
const Lightning := preload("res://scripts/screen_transition_lightning.gd")
const Strike := preload("res://scripts/screen_transition_strike.gd")
const WARP_SHADER := preload("res://shaders/warp_dive.tres")
const RUSH_SHADER := preload("res://shaders/warp_rush.tres")
const PRESET_NAMES := ["슬래시 스택", "슬라이스", "번개 닫힘 (원화 그대로)", "번개 일섬", "번개 재단", "워프 다이브", "워프 러시 (카툰)"]
const PRESET_LIGHTNING := 2
const PRESET_STRIKE := 3     # 번개 일섬 (4 = 번개 재단): Strike 가 그린다
const PRESET_WARP := 5       # 워프 다이브 (6 = 워프 러시): 셰이더가 화면 텍스처를 읽어 _rect 에 직접 그린다
const PRESET_RUSH := 6
const DEFAULT_PRESET := 3    # 저장된 선택이 없을 때
const CFG_VERSION := 3       # 이보다 낮은 저장(번개 일섬·재단이 없던 때): 새 기본값으로 한 번 옮긴다
const LAYER := 125           # SceneSwitcher 톱니·설정 메뉴(100)·로딩 화면(120) 위: 로딩이 끝난 뒤 그 위를 덮는다
## 장면이 드러나는 progress: 색판 프리셋은 마지막 판이 화면 가운데를 지날 때(≈ 0.88), 번개 닫힘은 되감기가 K1 포즈(번개만 남고 판이 물러남)에 닿을 때
## 일섬은 판이 튕겨 나간 직후, 재단은 이음매 쪽 띠가 절반쯤 빠져나갔을 때
## 워프는 가운데 구멍이 화면 끝까지 거의 다 열렸을 때
const OPEN_AT := [0.88, 0.88, 0.84, 0.68, 0.74, 0.74, 0.7]

## 일반 화면 전환(설정 메뉴 [화면 전환])으로 고를 수 있는 프리셋 수: PRESET_NAMES 의 앞 다섯 개
const GENERAL_COUNT := 5
## 전투 진입 전환(설정 메뉴 [전투 진입 전환])으로 고를 수 있는 프리셋. 전투를 시작할 때만 쓴다.
const ENTER_PRESETS := [PRESET_WARP, PRESET_RUSH]
const DEFAULT_ENTER := 1     # ENTER_PRESETS 의 순번: 워프 러시

static var _preset := -1     # -1 = 아직 cfg 를 안 읽음
static var _enter := -1      # 전투 진입 전환 (ENTER_PRESETS 의 순번). -1 = 아직 cfg 를 안 읽음
const REVEAL_WAIT := 2.0 / 30.0   # reveal() 이 새 씬의 첫 그림을 기다리는 두 프레임의 어림값
const MAX_DT := 1.0 / 24.0

var progress := 0.0
var preset_override := -1    # 연구실용: 0 이상이면 저장된 프리셋 대신 이 프리셋
var layer_override := -1     # 연구실용: 0 이상이면 LAYER 대신 이 레이어 (패널 아래)
var use_time_scale := false  # 연구실용: 재생 속도 슬라이더(Engine.time_scale)를 따른다. 씬 전환은 옛 씬의 히트스톱에 끌려가지 않게 실제 시간
var _fx_version := -1
var _rect: ColorRect
var _view: Control            # 번개 프리셋의 그림 (2 = Lightning, 3·4 = Strike). 색판 프리셋이면 null
var _pid := 0                 # 이 전환의 프리셋
var _mat: ShaderMaterial
var _phase := 0              # 0 대기 · 1 덮는 중 · 2 덮인 채 대기 · 3 걷는 중
var _t := 0.0
var _clock_us := 0


static func get_preset() -> int:
	if _preset < 0:
		var cfg := ConfigFile.new()
		_preset = DEFAULT_PRESET
		if cfg.load(CFG_PATH) == OK and int(cfg.get_value("transition", "version", 1)) >= CFG_VERSION:
			_preset = int(cfg.get_value("transition", "preset", DEFAULT_PRESET))
			if _preset < 0 or _preset >= GENERAL_COUNT:   # 전투 진입 전환이 일반 전환 목록에 있던 때의 저장
				_preset = DEFAULT_PRESET
	return _preset


static func set_preset(i: int) -> void:
	_preset = clampi(i, 0, GENERAL_COUNT - 1)
	_save_cfg()


## 일반 화면 전환 이름 (설정 메뉴 [화면 전환] 의 선택지)
static func general_names() -> Array:
	return PRESET_NAMES.slice(0, GENERAL_COUNT)


## 전투 진입 전환 이름 (설정 메뉴 [전투 진입 전환] 의 선택지)
static func enter_names() -> Array:
	return ENTER_PRESETS.map(func(p: int) -> String: return PRESET_NAMES[p])


## 고른 전투 진입 전환 (ENTER_PRESETS 의 순번)
static func get_enter() -> int:
	if _enter < 0:
		var cfg := ConfigFile.new()
		_enter = DEFAULT_ENTER
		if cfg.load(CFG_PATH) == OK:
			_enter = clampi(int(cfg.get_value("transition", "enter", DEFAULT_ENTER)), 0, ENTER_PRESETS.size() - 1)
	return _enter


static func set_enter(i: int) -> void:
	_enter = clampi(i, 0, ENTER_PRESETS.size() - 1)
	_save_cfg()


## 고른 전투 진입 전환의 프리셋 번호 (PRESET_NAMES 의 순번)
static func enter_preset() -> int:
	return ENTER_PRESETS[get_enter()]


## 두 선택을 함께 저장한다 (한쪽만 쓰면 다른 쪽이 지워진다)
static func _save_cfg() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("transition", "preset", get_preset())
	cfg.set_value("transition", "enter", get_enter())
	cfg.set_value("transition", "version", CFG_VERSION)
	cfg.save(CFG_PATH)


func _ready() -> void:
	layer = layer_override if layer_override >= 0 else LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP   # 전환 중 클릭이 아래로 새지 않게
	_mat = ShaderMaterial.new()
	_pid = preset_override if preset_override >= 0 else get_preset()
	_mat.shader = RUSH_SHADER if _pid == PRESET_RUSH else (WARP_SHADER if _pid == PRESET_WARP else SHADER)
	_mat.set_shader_parameter("seed", randf() * 100.0)
	_mat.set_shader_parameter("preset", float(mini(_pid, 1)))
	_apply_fx()
	add_child(_rect)
	if _pid >= PRESET_LIGHTNING and _pid < PRESET_WARP:
		_rect.color = Color(0, 0, 0, 0)      # 클릭만 막는 투명 판, 그림은 _view
		if _pid == PRESET_LIGHTNING:
			_view = Lightning.new()
		else:
			_view = Strike.new()
			_view.style = _pid - PRESET_STRIKE
		add_child(_view)
	else:
		_rect.material = _mat
	_fit()
	get_viewport().size_changed.connect(_fit)
	_apply()


## 화면 디자인 px 크기·비율을 셰이더에 넘긴다 (망점 간격은 디자인 px 기준, 도형은 비율 보정).
func _fit() -> void:
	var s := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("view_size", s)
	_mat.set_shader_parameter("aspect", s.x / maxf(s.y, 1.0))


func start() -> void:
	_play_sound()
	_phase = 1
	_t = 0.0
	_clock_us = Time.get_ticks_usec()
	progress = 0.0
	_apply()


## 전환 소리: 조절값 snd_pick (0 끔 · 1~3 · 4 무작위), snd_db. 이 노드는 씬이 바뀌어도 남으므로 자식 플레이어로 낸다.
var last_sound := ""   # 테스트용: 마지막으로 낸 파일 경로
func _play_sound() -> void:
	var pick := int(Fx.g("snd_pick"))
	if pick <= 0:
		return
	var i := randi() % Fx.SOUNDS.size() if pick > Fx.SOUNDS.size() else pick - 1
	var p := AudioStreamPlayer.new()
	p.stream = load(Fx.SOUNDS[i])
	p.volume_db = Fx.g("snd_db")
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	last_sound = Fx.SOUNDS[i]


## covered 뒤에 부른다. wait_frames 만큼 새 씬이 첫 화면을 그릴 틈을 두고 걷어낸다 (씬이 이미 그려져 있으면 0).
func reveal(wait_frames := 2) -> void:
	for i in wait_frames:
		await get_tree().process_frame
	_phase = 3
	_t = 0.0
	_clock_us = Time.get_ticks_usec()


## 덮는 시간 / 걷히는 시간 (초): 연구실 조절값
static func in_dur(preset := -1) -> float:
	return Fx.g(Fx.DUR_KEYS[_pick(preset)][0])


static func out_dur(preset := -1) -> float:
	return Fx.g(Fx.DUR_KEYS[_pick(preset)][1])


static func _pick(preset: int) -> int:
	return preset if preset >= 0 else get_preset()


## 걷기 중 장면이 드러날 때(progress OPEN_AT)까지 걸리는 시간(초)
static func open_part(preset := -1) -> float:
	var p := _pick(preset)
	return out_dur(p) * (OPEN_AT[p] - 0.5) / 0.5


## 아직 만들어지지 않은(곧 start 할) 전환이 장면을 드러낼 때까지의 어림 시간: 띄우기 전 프레임 + 덮기 전체 + 걷기 중 OPEN_AT 까지
static func full_lead(wait_frames := 2, preset := -1) -> float:
	return wait_frames / 30.0 + in_dur(preset) + open_part(preset)


## 워프: 빛줄기가 흘러간 거리. 덮는 동안 가속(끝에서 wp_speed), 걷는 동안 같은 속도에서 감속 — 두 구간의 길이가 달라도 0.5 에서 속도가 이어진다.
static func warp_travel(p: float, pre := "wp_") -> float:
	var a := Fx.g(pre + "speed") * Fx.g(pre + "in_dur") / 2.5
	if p <= 0.5:
		return a * pow(p * 2.0, 2.5)
	return a + Fx.g(pre + "speed") * Fx.g(pre + "out_dur") / 2.5 * (1.0 - pow(2.0 - p * 2.0, 2.5))


## 워프 러시: 스톱모션 프레임 번호. progress 를 지난 시간(초)으로 바꿔 wr_fps 박자로 끊는다 (같은 progress = 같은 그림).
static func rush_tick(p: float, pre := "wr_") -> float:
	var secs := p * 2.0 * Fx.g(pre + "in_dur") if p <= 0.5 else Fx.g(pre + "in_dur") + (p * 2.0 - 1.0) * Fx.g(pre + "out_dur")
	return floorf(secs * Fx.g(pre + "fps"))


## 조절값(색·망점)이 바뀌었으면 재질에 다시 넣는다
func _apply_fx() -> void:
	if _fx_version != Fx.version:
		_fx_version = Fx.version
		if _pid == PRESET_RUSH:
			Fx.apply_rush(_mat)
		elif _pid == PRESET_WARP:
			Fx.apply_warp(_mat)
		else:
			Fx.apply(_mat)


## 장면이 드러날 때(progress OPEN_AT)까지 남은 어림 시간(초). 새 씬의 등장 연출은 이만큼 늦춰 시작한다.
func time_to_open() -> float:
	var open_part := open_part(_pid)
	match _phase:
		1:
			return maxf(in_dur(_pid) - _t, 0.0) + REVEAL_WAIT + open_part
		2:
			return REVEAL_WAIT + open_part
		3:
			return maxf(open_part - _t, 0.0)
	return 0.0


## progress 를 직접 둔다 (캡처·연구용). 자동 진행은 멈춘다.
func preview(p: float) -> void:
	_phase = 0
	progress = clampf(p, 0.0, 1.0)
	_apply()


func _apply() -> void:
	if _pid >= PRESET_WARP:
		_rect.visible = progress > 0.0 and progress < 1.0   # 양 끝은 장면 그대로라 화면 텍스처를 읽을 필요가 없다
		_mat.set_shader_parameter("progress", progress)
		var pre := "wr_" if _pid == PRESET_RUSH else "wp_"
		_mat.set_shader_parameter("travel", warp_travel(progress, pre))
		_mat.set_shader_parameter("tick", rush_tick(progress, pre))   # 집중선이 새로 그려지는 박자 (다이브도 디지털 집중선에 쓴다)
	elif _pid >= PRESET_STRIKE:
		_view.set_progress(progress)
	elif _view:
		_view.set_close(1.0 - absf(2.0 * progress - 1.0))   # 0.5 까지 닫히고, 같은 길을 되감아 열린다
	else:
		_mat.set_shader_parameter("progress", progress)


func _process(_delta: float) -> void:
	_apply_fx()
	if _phase == 0 or _phase == 2:
		return
	var now := Time.get_ticks_usec()
	_t += clampf((now - _clock_us) / 1_000_000.0, 0.0, MAX_DT) * (Engine.time_scale if use_time_scale else 1.0)
	_clock_us = now
	if _phase == 1:
		var k := minf(_t / in_dur(_pid), 1.0)
		progress = 0.5 * k
		_apply()
		if k >= 1.0:
			_phase = 2
			covered.emit()
	else:
		var k := minf(_t / out_dur(_pid), 1.0)
		progress = 0.5 + 0.5 * k
		_apply()
		if k >= 1.0:
			_phase = 0
			finished.emit()
			queue_free()
