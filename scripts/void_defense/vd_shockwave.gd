## 화면 쇼크웨이브 (shaders/screen_shockwave.gdshader). 맞은 자리(월드 점)에서 둥근 띠가 퍼지며 화면이 일렁인다.
## 월드 위·앞 안개 아래 CanvasLayer(4) 에 화면 전체 ColorRect 하나. 웨이브가 없으면 숨겨 둔다.
## 웨이브는 월드 좌표에 붙어 있어 카메라가 움직여도 제자리에서 퍼지고, 게임 시간으로 돈다
## (히트스탑에 같이 멈추고 슬로모션에 같이 느려진다).
## 종류: light(평타) · heavy(치명타·기사) · kill(처치) · boss(보스 처치) · slam(궁극기·내려찍기)
extends CanvasLayer

const MAX_WAVES := 6
## amp: 세기 · speed: 퍼지는 속도(월드 px/초) · thick: 띠 두께(월드 px) · life: 수명(초)
const KINDS := {
	"light": {"amp": 0.5, "speed": 620.0, "thick": 20.0, "life": 0.38},
	"heavy": {"amp": 0.9, "speed": 780.0, "thick": 32.0, "life": 0.55},
	"kill": {"amp": 1.2, "speed": 900.0, "thick": 48.0, "life": 0.8},
	"boss": {"amp": 1.6, "speed": 1050.0, "thick": 70.0, "life": 1.1},
	"slam": {"amp": 1.3, "speed": 950.0, "thick": 56.0, "life": 0.85},
}
const FLAT := 0.62   # 띠 세로 납작함 (바닥 원근)

static var enabled := true

var _rect: ColorRect
var _mat: ShaderMaterial
var _list: Array[Dictionary] = []
var _waves := PackedVector4Array()
var _bands := PackedVector4Array()


func _init() -> void:
	layer = 4
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/screen_shockwave.gdshader")
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)
	_waves.resize(MAX_WAVES)
	_bands.resize(MAX_WAVES)


## world_at 에서 kind 웨이브를 하나 띄운다. k 로 세기만 더 키우거나 줄인다.
func add(world_at: Vector2, kind := "light", k := 1.0) -> void:
	if not enabled:
		return
	var d: Dictionary = KINDS.get(kind, KINDS["light"])
	_list.append({"at": world_at, "r": 6.0, "amp0": float(d["amp"]) * k, "amp": float(d["amp"]) * k,
		"speed": float(d["speed"]), "thick": float(d["thick"]), "life": float(d["life"]), "t": 0.0})
	if _list.size() > MAX_WAVES:
		_list.pop_front()


func clear() -> void:
	_list.clear()
	_rect.visible = false


func toggle() -> void:
	enabled = not enabled
	if not enabled:
		clear()


func is_on() -> bool:
	return enabled


func _process(delta: float) -> void:
	for w in _list:
		w["t"] += delta
		var p: float = w["t"] / w["life"]
		# 처음엔 빠르게 퍼지다 점점 느려지고, 세기는 부드럽게 0 으로
		w["r"] += w["speed"] * delta * (1.0 - 0.55 * p)
		w["amp"] = w["amp0"] * maxf(0.0, 1.0 - p) * maxf(0.0, 1.0 - p * 0.3)
	_list = _list.filter(func(w: Dictionary) -> bool: return w["t"] < w["life"])
	_rect.visible = not _list.is_empty()
	if not _rect.visible:
		return
	var vp := get_viewport()
	var xf := vp.get_canvas_transform()
	var z := xf.get_scale().x
	for i in MAX_WAVES:
		if i < _list.size():
			var w := _list[i]
			var c: Vector2 = xf * w["at"]
			_waves[i] = Vector4(c.x, c.y, w["r"] * z, w["amp"])
			_bands[i] = Vector4(w["thick"] * z, FLAT, 1.0, 0.0)
		else:
			_waves[i] = Vector4.ZERO
			_bands[i] = Vector4.ZERO
	_mat.set_shader_parameter("res", vp.get_visible_rect().size)
	_mat.set_shader_parameter("waves", _waves)
	_mat.set_shader_parameter("bands", _bands)
