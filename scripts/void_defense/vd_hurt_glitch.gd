## 아군 피격 글리치 (카툰식 · 가로축 전용): HUD 전체를 감싼 CanvasGroup 에 shaders/ui_glitch.tres(VisualShader)를 걸어
## 맞은 영웅의 우측 하단 초상화 카드에서만, 좌/우를 향한 테두리 몇 군데에 가로로 뾰족한 가시 · 네모 턱이 튀어나오거나 홈이 패인다.
## 같은 순간 그 카드가 흔들리고 피격 색(흰 섬광 → 붉은 기)이 든다 (on_hit → VDBattleFrame.hit_card). 가시는 흔들리는 카드를 따라간다.
## 도형은 그 자리 채움색 한 색으로 칠하고 그 변의 외곽선 색·두께로 다시 두른다 (시안: 깔끔한 카툰 쉐입).
## 셰이더는 tools/shaders/build_ui_glitch.gd 가 생성한다.
##
## 가시 자리: 대상(HUD 조각 텍스처 + 화면 변환)마다 텍스처 알파에서 '세로로 곧게 선 좌/우 테두리' 점을 미리 뽑고,
## 점마다 외곽선 색 · 외곽선 두께 · 그 안쪽 채움색을 재 둔다. kick 때 맞은 영웅 카드의 점 중에서 고른다.
## 대상은 target_provider() 가 [{id, tex, xf, max_x}] 로 준다 (VDBattleFrame.glitch_targets: 영웅 카드, 흔들림 포함).
## 박자: 실제 시간 step_fps 로 끊긴 프레임 hold_frames 장 동안 켜지고, 가끔 중간에 한 번 모양이 바뀐 뒤 꺼진다 (감쇠 없음).
## 값(P)은 VDGlitchTuner(설정 → 글리치 조정, F9)가 바꾸고 user://vd_glitch.cfg 에 저장한다.
extends Node

const SHADER := preload("res://shaders/ui_glitch.tres")
const SLOTS := 4
const CFG_PATH := "user://vd_glitch.cfg"

## 조정 값: [키, 이름, 최소, 최대, 간격, 기본]
const PARAMS := [
	["step_fps", "박자 (초당 프레임)", 4.0, 30.0, 1.0, 15.0],
	["hold_frames", "지속 (박자 수)", 1.0, 10.0, 1.0, 2.0],
	["reshape_chance", "중간에 모양 바뀔 확률", 0.0, 1.0, 0.05, 1.0],
	["spike_max", "가시 수 (최대)", 1.0, 4.0, 1.0, 4.0],
	["len_min", "가시 길이 최소 (px)", 2.0, 120.0, 1.0, 21.0],
	["len_max", "가시 길이 최대 (px)", 2.0, 160.0, 1.0, 138.0],
	["height_min", "가시 반높이 최소 (px)", 2.0, 80.0, 1.0, 5.0],
	["height_max", "가시 반높이 최대 (px)", 2.0, 120.0, 1.0, 16.0],
	["zigzag_chance", "두 갈래(지그재그) 확률", 0.0, 1.0, 0.05, 1.0],
	["slab_chance", "네모 턱 확률", 0.0, 1.0, 0.05, 0.2],
	["dent_chance", "안으로 패인 홈 확률", 0.0, 1.0, 0.05, 0.8],
	["ink_mul", "외곽선 두께 배율 (원래 두께 기준)", 0.0, 3.0, 0.05, 0.75],
	["ink_out", "외곽선 바깥 덧칠 (px)", 0.0, 10.0, 0.5, 1.5],
	["erase_extra", "밑동 외곽선 지움 여유 (px)", 0.0, 10.0, 0.5, 3.5],
	["shake_px", "카드 흔들림 세기 (px)", 0.0, 30.0, 0.5, 9.0],
	["shake_time", "카드 흔들림 시간 (초)", 0.05, 1.0, 0.01, 0.28],
	["shake_fps", "카드 흔들림 박자 (초당)", 6.0, 60.0, 1.0, 30.0],
	["flash_white", "흰 섬광 시간 (초)", 0.0, 0.3, 0.01, 0.05],
	["flash_time", "붉은 기 빠지는 시간 (초)", 0.05, 1.5, 0.01, 0.4],
	["flash_red", "붉은 기 세기", 0.0, 1.0, 0.05, 0.75],
	["cooldown", "재발동 간격 (초)", 0.0, 2.0, 0.05, 0.3],
]

var P := {}                      # 키 -> 값
var group: CanvasGroup
var target_provider: Callable    # () -> Array[{id, tex, xf, max_x}]
var on_hit: Callable             # (hero_id, strength, P) -> 카드 흔들림·피격 색

var _mat: ShaderMaterial
var _spikes: Array = []          # {tid, tp: 텍스처 점, dy, hh, off, facing, profile, w, ink, fill} (화면 위치는 매 프레임 다시 잰다)
var _frame := -1
var _frames := 0
var _reshape_at := -1
var _next_us := 0
var _last_kick_us := -1_000_000_000
var _edge_cache := {}            # "경로|max_x" -> Array[{p: Vector3(x, y, 향함), ink, fill, w}]


func _init() -> void:
	reset_values()
	load_values()


func setup(group_: CanvasGroup, provider: Callable, hit_cb: Callable) -> void:
	group = group_
	target_provider = provider
	on_hit = hit_cb
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER


func reset_values() -> void:
	for p in PARAMS:
		P[p[0]] = p[5]


## strength 0..1 (가시 수·길이·흔들림에 반영), hero_id: 맞은 영웅 (그 카드에만 가시. 없으면 아무 카드).
func kick(strength: float, hero_id := "") -> void:
	if group == null:
		return
	var now := Time.get_ticks_usec()
	if now - _last_kick_us < int(float(P["cooldown"]) * 1_000_000.0) and _frame >= 0:
		return
	_last_kick_us = now
	var s := clampf(strength, 0.0, 1.0)
	_spikes.clear()
	var n := clampi(roundi(lerpf(1.0, float(P["spike_max"]), s)), 1, SLOTS)
	var targets: Array = target_provider.call() if target_provider.is_valid() else []
	if targets.is_empty():
		return
	var t := _pick_target(targets, hero_id)
	var tries := 0
	while _spikes.size() < n and tries < 12:
		tries += 1
		_add_spike(t, s)
	if _spikes.is_empty():
		return
	if on_hit.is_valid():
		on_hit.call(t["id"], s, P)
	_frames = int(P["hold_frames"])
	_reshape_at = randi_range(1, _frames - 1) if _frames >= 2 and randf() < float(P["reshape_chance"]) else -1
	_frame = 0
	_next_us = now + _step_us()
	_apply()


func is_active() -> bool:
	return _frame >= 0


## 쿨다운·진행 중인 글리치를 무시하고 바로 다시 켤 수 있게 한다 (조정 패널의 테스트 버튼).
func reset_timer() -> void:
	_last_kick_us = -1_000_000_000
	_frame = -1


func _step_us() -> int:
	return int(1_000_000.0 / maxf(float(P["step_fps"]), 1.0))


func _process(_delta: float) -> void:
	if _frame < 0:
		return
	var now := Time.get_ticks_usec()
	if now >= _next_us:
		_next_us = now + _step_us()
		_frame += 1
		if _frame >= _frames:
			_frame = -1
			_spikes.clear()
		elif _frame == _reshape_at:
			_reshape()
	_apply()                               # 박자 사이에도: 흔들리는 카드를 따라간다


func _pick_target(targets: Array, hero_id: String) -> Dictionary:
	for t in targets:
		if t["id"] == hero_id:
			return t
	return targets[randi() % targets.size()]


## 대상 하나의 테두리 점 하나에 가시(또는 지그재그 두 개)를 단다.
func _add_spike(t: Dictionary, s: float) -> void:
	var xf: Transform2D = t["xf"]
	# 화면 안(가장자리 24px 안쪽)에 보이는 테두리 점만 (오른쪽 패널처럼 화면 밖으로 걸친 조각이 있다)
	var view := Rect2(Vector2.ZERO, group.get_viewport().get_visible_rect().size).grow(-24.0)
	var pts := _edges(t["tex"], float(t.get("max_x", 1e9))).filter(func(q: Dictionary) -> bool:
		return view.has_point(xf * Vector2(q["p"].x, q["p"].y)))
	if pts.is_empty():
		return
	var e: Dictionary = pts[randi() % pts.size()]
	var sx := xf.x.length()
	var facing := float(e["p"].z) * signf(xf.x.x)
	var length := lerpf(float(P["len_min"]), float(P["len_max"]), randf() * (0.5 + 0.5 * s))
	var hh := lerpf(float(P["height_min"]), float(P["height_max"]), randf())
	var profile := 1.0 if randf() < float(P["slab_chance"]) else 0.0
	if profile > 0.5:
		length *= 0.45                       # 네모 턱은 짧게
	var dent := randf() < float(P["dent_chance"])
	var off := roundf(facing * length * (-0.6 if dent else 1.0))
	_spikes.append(_spike(t, e, sx, facing, hh, off, profile))
	# 두 갈래: 같은 테두리 바로 아래(또는 위)에 짧은 이빨 하나 더 (시안 오른쪽처럼)
	if _spikes.size() < SLOTS and profile < 0.5 and not dent and randf() < float(P["zigzag_chance"]):
		var p0: Vector3 = e["p"]
		var y2 := p0.y + (1.0 if randf() < 0.5 else -1.0) * hh * 1.5 / maxf(sx, 0.001)
		var best: Dictionary = {}
		var bd := 6.0
		for q in pts:
			var pq: Vector3 = q["p"]
			if pq.z == p0.z and absf(pq.x - p0.x) < 16.0 and absf(pq.y - y2) < bd:
				bd = absf(pq.y - y2)
				best = q
		if not best.is_empty():
			_spikes.append(_spike(t, best, sx, facing, hh * 0.7, roundf(off * 0.55), 0.0))


func _spike(t: Dictionary, e: Dictionary, sx: float, facing: float, hh: float, off: float, profile: float) -> Dictionary:
	var p: Vector3 = e["p"]
	return {"tid": t["id"], "tp": Vector2(p.x, p.y), "dy": 0.0, "hh": hh, "off": off, "facing": facing, "profile": profile,
		"w": float(e["w"]) * sx, "ink": e["ink"], "fill": e["fill"]}


## 중간 박자: 길이를 다시 굴리고(가끔 반대로 패이게) 한 개는 위아래로 살짝 옮긴다.
func _reshape() -> void:
	for sp in _spikes:
		if randf() < 0.2:
			sp["off"] = roundf(-float(sp["off"]) * 0.5)
		else:
			sp["off"] = roundf(float(sp["off"]) * randf_range(0.5, 1.35))
	var sp: Dictionary = _spikes[randi() % _spikes.size()]
	sp["dy"] = float(sp["dy"]) + randf_range(-1.0, 1.0) * float(sp["hh"]) * 0.6


func _apply() -> void:
	if _frame < 0 or _spikes.is_empty():
		group.material = null              # 꺼져 있을 땐 기본 CanvasGroup 그대로
		return
	group.material = _mat
	_mat.set_shader_parameter("view_size", group.get_viewport().get_visible_rect().size)
	var xfs := {}
	var tints := {}
	for t in target_provider.call():
		xfs[t["id"]] = t["xf"]
		tints[t["id"]] = t.get("tint", Color.WHITE)
	for i in SLOTS:
		if i < _spikes.size():
			var sp: Dictionary = _spikes[i]
			var pos: Vector2 = xfs.get(sp["tid"], Transform2D.IDENTITY) * sp["tp"]
			_mat.set_shader_parameter("spike_a%d" % i, Vector4(pos.x, pos.y + float(sp["dy"]), sp["hh"], sp["off"]))
			_mat.set_shader_parameter("spike_b%d" % i, Vector4(sp["facing"], sp["profile"], sp["w"], 1.0))
			var tint: Color = tints.get(sp["tid"], Color.WHITE)   # 카드 피격 색(섬광·붉은 기)을 가시에도
			_mat.set_shader_parameter("fill_color%d" % i, (sp["fill"] * tint).clamp())
			_mat.set_shader_parameter("ink_color%d" % i, (sp["ink"] * tint).clamp())
		else:
			_mat.set_shader_parameter("spike_b%d" % i, Vector4.ZERO)
	for key in ["ink_mul", "ink_out", "erase_extra"]:
		_mat.set_shader_parameter(key, float(P[key]))


# ---------------------------------------------------------------- 테두리 후보

## 텍스처 알파에서 좌/우를 향한 '곧게 선' 테두리 점을 뽑는다 (3px 간격 행). 텍스처마다 한 번만.
##   p.z 향함 +1: 왼쪽이 그림(오른쪽을 향한 변), -1: 오른쪽이 그림.
##   ink = 외곽선 색 (테두리 1px 안쪽), w = 외곽선 두께 (텍스처 px, 외곽선이 없는 단색 면이면 0),
##   fill = 외곽선 안쪽 채움색 (그 둘레에서 가장 많은 색)
func _edges(tex: Texture2D, max_x: float) -> Array:
	var key := "%s|%d" % [tex.resource_path, int(minf(max_x, 1e6))]
	if _edge_cache.has(key):
		return _edge_cache[key]
	var out := []
	_edge_cache[key] = out
	var img := tex.get_image()
	if img == null:
		return out
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var xmax := mini(w, int(max_x))
	for y in range(8, h - 8, 3):
		var row := y * w * 4 + 3
		var prev := data[row] >= 128
		for x in range(1, xmax):
			var cur := data[row + x * 4] >= 128
			if cur == prev:
				continue
			prev = cur
			var facing := -1 if cur else 1            # 그림이 왼쪽이면(cur 투명) 오른쪽을 향한 변
			var inside := x if cur else x - 1
			# 또렷한 변: 안쪽 4px 은 거의 불투명, 바깥 5px 은 거의 투명. 위아래 7px 에서도 같은 변이 이어져야 (세로로 선 변)
			if _crisp(data, w, inside, y, facing):
				var m := _measure(img, inside, y, -facing)
				m["p"] = Vector3(x, y, facing)
				out.append(m)
	return out


static func _crisp(data: PackedByteArray, w: int, inside: int, y: int, facing: int) -> bool:
	for dy in [-7, 0, 7]:
		var yy: int = y + dy
		var xi := inside - facing * 4
		var xo := inside + facing * 5
		if xi < 0 or xi >= w:
			return false
		if data[(yy * w + xi) * 4 + 3] < 230:
			return false
		if xo >= 0 and xo < w and data[(yy * w + xo) * 4 + 3] > 25:
			return false
	return true


## 테두리 안쪽(dir 방향)으로 외곽선 색·두께와 채움색을 잰다.
static func _measure(img: Image, inside: int, y: int, dir: int) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var ink := img.get_pixel(clampi(inside + dir, 0, w - 1), y)
	var thick := 1
	while thick < 16 and _close(img.get_pixel(clampi(inside + dir * (thick + 1), 0, w - 1), y), ink):
		thick += 1
	ink.a = 1.0
	if thick >= 14:
		# 외곽선 없는 단색 면: 도형도 같은 색, 외곽선 없음
		return {"ink": ink, "fill": ink, "w": 0.0}
	# 채움색: 외곽선 너머 10px × 위아래 9px 에서 가장 많은 색 (머리카락 선 같은 가는 선은 밀린다)
	var bins := {}
	for k in range(thick + 2, thick + 12):
		for dy in range(-4, 5, 2):
			var c := img.get_pixel(clampi(inside + dir * k, 0, w - 1), clampi(y + dy, 0, h - 1))
			if c.a < 0.9:
				continue
			var key := (int(c.r * 7.99) << 6) | (int(c.g * 7.99) << 3) | int(c.b * 7.99)
			var b: Array = bins.get(key, [0, Color(0, 0, 0, 0)])
			b[0] += 1
			b[1] += c
			bins[key] = b
	# 검은 선화 색은 다른 색이 하나라도 있으면 고르지 않는다 (가시가 시커멓게 되지 않게)
	var fill := ink
	var best := 0.0
	for b in bins.values():
		var c: Color = b[1] / float(b[0])
		var score := float(b[0]) * (0.05 if c.get_luminance() < 0.12 else 1.0)
		if score > best:
			best = score
			fill = c
	fill.a = 1.0
	return {"ink": ink, "fill": fill, "w": float(thick)}


static func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.24 and a.a > 0.9


## 대상 텍스처의 테두리를 미리 뽑아 둔다 (첫 피격 때 끊기지 않게).
func prewarm() -> void:
	if not target_provider.is_valid():
		return
	for t in target_provider.call():
		_edges(t["tex"], float(t.get("max_x", 1e9)))


# ---------------------------------------------------------------- 저장

func save_values() -> void:
	var cf := ConfigFile.new()
	for p in PARAMS:
		cf.set_value("glitch", p[0], P[p[0]])
	cf.save(CFG_PATH)


func load_values() -> void:
	var cf := ConfigFile.new()
	if cf.load(CFG_PATH) != OK:
		return
	for p in PARAMS:
		P[p[0]] = clampf(float(cf.get_value("glitch", p[0], P[p[0]])), p[2], p[3])


func values_text() -> String:
	var s := "glitch:"
	for p in PARAMS:
		s += "  %s=%s" % [p[0], str(snappedf(float(P[p[0]]), 0.001))]
	return s
