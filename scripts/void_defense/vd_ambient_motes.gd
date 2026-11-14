## 전투 필드 엠비언트 티끌 (2026-11-13): 화면 아래에서 오른쪽 위 사선으로 천천히 떠오르는 작은 빛 알갱이.
## 두 층: 뒤 층(front=false) 은 배경 앞·보드 뒤, 앞 층(front=true) 은 가끔 필드·캐릭터 위를 크고 흐리게 빠르게 스쳐 지나가 공간감을 준다.
## 배경 CanvasLayer(-10) 의 배경 셰이더 바로 위 · 보드 뒤에 그린다 → 보드 바깥 빈 공간에서만 보이고 유닛·HUD 를 가리지 않는다.
## 화면 좌표로 돌며, 카메라가 움직이면 깊이에 따라 살짝 반대로 밀려 시차가 생긴다. 색은 배경 테마를 따른다.
## 실제 시간으로 돈다 (히트스탑·슬로모션에 멈칫하지 않는 배경 분위기).
class_name VDAmbientMotes
extends Node2D

const PALETTES := {
	"void": [Color(0.72, 0.55, 1.0), Color(0.45, 0.85, 1.0), Color(1.0, 0.6, 0.95)],
	"desert": [Color(1.0, 0.78, 0.45), Color(1.0, 0.92, 0.7), Color(0.55, 0.9, 1.0)],
	"bio": [Color(0.45, 1.0, 0.85), Color(0.55, 0.85, 1.0), Color(0.85, 1.0, 0.6)],
}
const BASE_COUNT := 64          # 1280x720 기준 개수 (화면 넓이에 비례)
const PARALLAX := 0.18          # 카메라 이동 대비 가장 가까운 티끌이 밀리는 비율
const TILT := Vector2(0.45, 0.8) # 올라가는 만큼 오른쪽으로 흐르는 비율 (사선 각도 약 24~39도)
## 앞 층: 카메라 바로 앞을 지나는 큰 빛 번짐. 몇 개 안 되고, 하나가 지나가면 몇 초 쉬었다 다시 나온다.
const FRONT_COUNT := 5
const FRONT_WAIT := Vector2(1.5, 9.0)
const FRONT_PARALLAX := 0.55

static var enabled := true
static var _tex: Texture2D

var camera: Camera2D
## true 면 앞 층 (VDBattle 이 안개 레이어 맨 아래에 따로 하나 더 둔다)
var front := false
var _palette: Array = PALETTES["void"]
var _motes: Array[Dictionary] = []
var _last_cam := Vector2.INF
var _last_usec := 0
var _t := 0.0


func _ready() -> void:
	name = "AmbientMotesFront" if front else "AmbientMotes"
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	if _tex == null:
		_tex = _make_glow()
	visible = enabled
	get_viewport().size_changed.connect(_refill)
	_refill()


func set_theme_profile(profile: String) -> void:
	_palette = PALETTES.get(profile, PALETTES["void"])
	for m in _motes:
		m.color = _palette[randi() % _palette.size()]


func toggle() -> void:
	enabled = not enabled
	visible = enabled


func is_on() -> bool:
	return enabled


func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size


## 화면 크기에 맞춰 개수를 맞추고, 처음엔 화면 전체에 흩뿌려 빈 화면에서 시작하지 않게 한다.
func _refill() -> void:
	var s := _screen()
	var area := (s.x * s.y) / (1280.0 * 720.0)
	var want := clampi(int(round(FRONT_COUNT * area)), 3, 12) if front else clampi(int(round(BASE_COUNT * area)), 24, 160)
	while _motes.size() > want:
		_motes.pop_back()
	while _motes.size() < want:
		var m := {}
		_spawn(m, true)
		_motes.append(m)


func _spawn(m: Dictionary, anywhere := false) -> void:
	var s := _screen()
	var k := s.y / 720.0
	var depth := randf()                       # 0 = 멀리(작고 느림·흐림) .. 1 = 가까이
	m.depth = depth
	m.tilt = randf_range(TILT.x, TILT.y)
	# 사선으로 오른쪽으로 흘러가므로 왼쪽 화면 밖에서도 태어나게 해 왼쪽이 비지 않게 한다
	var x0 := -s.y * TILT.y * 0.7
	m.pos = Vector2(randf_range(x0, s.x), (randf_range(0.15, 1.05) if anywhere else randf_range(1.02, 1.12)) * s.y)
	m.phase = randf() * TAU
	m.color = _palette[randi() % _palette.size()]
	m.age = 0.0 if not anywhere else 1.0
	m.wait = 0.0
	if front:
		# 카메라 바로 앞: 크고 흐리고 빠르다. 화면 끝까지 지나가며, 지나간 뒤 잠시 쉬었다 나온다
		m.pos.y = randf_range(1.05, 1.2) * s.y
		m.speed = randf_range(70.0, 120.0) * k
		m.size = randf_range(9.0, 18.0) * k
		m.sway = randf_range(10.0, 30.0) * k
		m.sway_f = randf_range(0.2, 0.45)
		m.tw_f = randf_range(0.4, 0.9)
		m.alpha = randf_range(0.55, 0.85)
		m.top = -0.25 * s.y
		m.age = 0.0
		m.wait = randf_range(FRONT_WAIT.x, FRONT_WAIT.y) * (0.5 if anywhere else 1.0)
		return
	m.speed = lerpf(10.0, 42.0, depth) * randf_range(0.8, 1.25) * k
	m.size = lerpf(2.4, 6.5, depth * depth) * randf_range(0.8, 1.2) * k
	m.sway = randf_range(6.0, 22.0) * k
	m.sway_f = randf_range(0.25, 0.7)
	m.tw_f = randf_range(1.2, 3.5)              # 반짝임
	m.alpha = lerpf(0.6, 1.0, depth) * randf_range(0.7, 1.0)
	m.top = randf_range(0.05, 0.45) * s.y       # 여기쯤에서 사라진다 (위로 갈수록 엷어짐)


func _process(_delta: float) -> void:
	if visible != enabled:   # 설정 토글은 뒤·앞 층이 함께 따른다
		visible = enabled
	if not visible:
		_last_usec = 0
		return
	var now := Time.get_ticks_usec()
	var dt := 0.0 if _last_usec == 0 else minf((now - _last_usec) / 1000000.0, 0.1)
	_last_usec = now
	_t += dt
	var push := Vector2.ZERO
	if camera != null and is_instance_valid(camera):
		var c := camera.get_screen_center_position() * camera.zoom
		if _last_cam != Vector2.INF:
			push = -(c - _last_cam) * (FRONT_PARALLAX if front else PARALLAX)
		_last_cam = c
	var s := _screen()
	for m in _motes:
		if m.wait > 0.0:
			m.wait -= dt
			continue
		m.age += dt
		m.pos += Vector2(m.tilt, -1.0) * m.speed * dt   # 오른쪽 위 사선
		m.pos += push * (1.0 if front else 0.25 + 0.75 * m.depth)
		var margin: float = m.size * 4.0
		if m.pos.y < m.top - 30.0 or m.pos.y > s.y * 1.3 or m.pos.x > s.x + margin + 40.0:
			_spawn(m)
	queue_redraw()


func _draw() -> void:
	var s := _screen()
	for m in _motes:
		if m.wait > 0.0:
			continue
		# 흔들림은 진행 방향에 수직으로 (사선 흐름을 유지한 채 살랑인다)
		var side := Vector2(1.0, m.tilt).normalized()
		var p: Vector2 = m.pos + side * sin(_t * m.sway_f + m.phase) * m.sway
		var x := p.x
		var y := p.y
		# 아래에서 나타나고(fade in) 정해진 높이에 가까워지면 사라진다
		var a_in := clampf(m.age / 1.2, 0.0, 1.0)
		var a_top := clampf((y - m.top) / (s.y * 0.25), 0.0, 1.0)
		var tw := 0.6 + 0.4 * sin(_t * m.tw_f * TAU * 0.5 + m.phase * 3.0)
		var a: float = m.alpha * a_in * a_top * tw
		if a <= 0.01:
			continue
		var col: Color = m.color
		if front:
			# 초점이 맞지 않은 가까운 빛: 심 없이 넓게 번진 원 두 겹
			var rf: float = m.size * 2.6
			draw_texture_rect(_tex, Rect2(x - rf, y - rf, rf * 2.0, rf * 2.0), false, Color(col.r, col.g, col.b, a * 0.7))
			var rc: float = m.size * 1.1
			draw_texture_rect(_tex, Rect2(x - rc, y - rc, rc * 2.0, rc * 2.0), false,
				Color(lerpf(col.r, 1.0, 0.35), lerpf(col.g, 1.0, 0.35), lerpf(col.b, 1.0, 0.35), a * 0.85))
			continue
		var r: float = m.size * 3.5
		draw_texture_rect(_tex, Rect2(x - r, y - r, r * 2.0, r * 2.0), false, Color(col.r, col.g, col.b, a * 0.8))
		var core: float = m.size * 1.2
		draw_texture_rect(_tex, Rect2(x - core, y - core, core * 2.0, core * 2.0), false,
			Color(lerpf(col.r, 1.0, 0.6), lerpf(col.g, 1.0, 0.6), lerpf(col.b, 1.0, 0.6), a))


## 부드러운 빛 알갱이 텍스처: 가운데 밝은 심 + 바깥으로 빠르게 꺼지는 번짐.
static func _make_glow() -> Texture2D:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for yy in n:
		for xx in n:
			var d := Vector2(xx - c, yy - c).length() / c
			var v := clampf(1.0 - d, 0.0, 1.0)
			v = pow(v, 2.2) + 0.6 * pow(clampf(1.0 - d * 2.2, 0.0, 1.0), 3.0)
			img.set_pixel(xx, yy, Color(1, 1, 1, clampf(v, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
