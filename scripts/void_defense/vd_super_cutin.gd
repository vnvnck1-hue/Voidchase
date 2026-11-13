## 초궁극기 컷인: 화면 컨셉_2.psd 의 '궁극기 연출' 조각(tools/ult_cutin/extract_ult_cutin.py)으로 만든 전면 컷인.
##   0.00  화면이 어두워지고, 검은 지그재그 띠는 오른쪽에서 · 보라 테 띠(창)는 왼쪽에서 휙 날아온다 (기울기 스미어)
##   0.23  "핏칭!" — 두 띠가 맞물리는 순간: 창 흰 번쩍 · 화면 섬광 · 흔들림 · 대각 섬광 · 별 팝 · 띠 세로 찌그러짐
##         캐릭터는 가로로 늘어진 채 미끄러져 들어와 딱 멈춘다 → 천천히 줌인. 창 안에는 성운·먼지·속도선이 흐른다
##   0.39  눈에 반짝("칭~") · 스킬 이름 도장
##   0.78  "핏" — 띠가 가로 한 줄로 접히며 밝은 선이 퍼지고 사라진다 → play() 가 끝난다 (선은 조금 더 남는다)
## 트리가 일시정지돼도 돈다. 시간은 모두 실제 시간(배속·히트스탑과 무관). class_name 없음: preload 해서 쓴다.
## 위 박자(기본값 기준)·세기는 Fx(vd_super_cutin_fx.gd) — 연출 연구실에서 바꾸고 저장한 값을 읽는다.
extends CanvasLayer
const GameFonts := preload("res://scripts/game_fonts.gd")

const Layout := preload("res://scripts/void_defense/vd_ult_cutin_layout.gd")
const Fx := preload("res://scripts/void_defense/vd_super_cutin_fx.gd")

const BASE_COL := Color(0.62, 0.42, 0.92)   # 시안(마법사) 색. 다른 영웅은 띠·성운·별의 색상(hue)을 자기 색 쪽으로 돌린다
## 색상을 돌릴 조각 (띠 검정·창 마스크는 그대로)
const TINTED := ["sparkle_field", "sparkle_a", "sparkle_b", "band_frame", "sliver_1", "sliver_2", "sliver_3", "sliver_4", "nebula", "motes", "slash"]
const TITLE_POS := Vector2(470, 175)   # 스킬 이름 (띠 오른쪽 아래)

signal impact                 # "핏칭!" 순간 (부르는 쪽이 사운드·진동을 더할 때)

static var _cache := {}       # 텍스처 (prewarm)
static var _hue_shaders := {}  # blend_add 여부 -> 색상 회전 셰이더

var _flash_shader: Shader
var _root: Node2D             # 화면 중심, 디자인 → 화면 배율
var _shake_node: Node2D
var _band_black: Sprite2D
var _band_frame: Node2D       # 보라 테 + 창(클립) + 조각들
var _window: Sprite2D
var _content: Node2D          # 창 안: 띠 가로 늘림을 되돌린다
var _portrait: Sprite2D
var _speed_root: Node2D
var _dim: ColorRect
var _flash: ColorRect
var _t0 := 0.0
var _shake_amp := 0.0
var _shake_t := 0.0
var _speed_acc := 0.0
var _running := false
var _ended := false             # play() 의 기다림이 끝남
var _line_done := false         # 접힌 뒤 빛줄기가 다 사라짐 — 둘 다 끝나야 지운다 (먼저 지우면 play() 가 되살아날 곳이 없다)
var _muted := false
var _base_scale := Vector2.ONE
var _bold_font: Font
var _last := 0.0
var _hero := "mage"           # Layout.PORTRAITS 의 키
var _hue := 0.0               # BASE_COL 에서 영웅 색까지 돌릴 색상 (0~1)
var speed := 1.0              # 재생 배속 (연구실 슬로 모션). play() 전에 정한다
static var _flash_shader_s: Shader


func _init() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 셰이더는 한 번만 만든다: 컷인마다 새로 만들면 첫 그리기에서 매번 다시 컴파일되어 멈칫한다
	if _flash_shader_s == null:
		_flash_shader_s = Shader.new()
		_flash_shader_s.code = """shader_type canvas_item;
uniform float flash = 0.0;
uniform vec4 flash_col : source_color = vec4(1.0);
void fragment() { COLOR.rgb = mix(COLOR.rgb, flash_col.rgb, flash); }"""
	_flash_shader = _flash_shader_s


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0 * speed


func _f(key: String) -> float:
	return Fx.g(key)


## 전투가 시작될 때 불러 둔다: 컷인 첫 프레임에 텍스처를 읽으면 0.15초쯤 끊긴다.
static func prewarm() -> void:
	var names: Array = Layout.PIECES.keys()
	for p in Layout.PORTRAITS.values():
		names.append(p[0])
	for n in names:
		if not _cache.has(n):
			_cache[n] = load(Layout.DIR + n + ".png")


static func _tex(n: String) -> Texture2D:
	if not _cache.has(n):
		_cache[n] = load(Layout.DIR + n + ".png")
	return _cache[n]


func _sprite(parent: Node, n: String, add := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = n
	s.texture = _tex(n)
	s.position = Layout.PIECES[n][0]
	s.modulate.a = Layout.PIECES[n][1]
	if not is_zero_approx(_hue) and n in TINTED:
		s.material = _hue_mat(add)
	elif add:
		s.material = VDVfx.add_material()
	parent.add_child(s)
	return s


func _hue_mat(add: bool) -> ShaderMaterial:
	if not _hue_shaders.has(add):
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\n" + ("render_mode blend_add;\n" if add else "") + """uniform float hue = 0.0;
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec3 h = rgb2hsv(c.rgb);
	h.x = fract(h.x + hue);
	COLOR = vec4(hsv2rgb(h), c.a);
}"""
		_hue_shaders[add] = sh
	var m := ShaderMaterial.new()
	m.shader = _hue_shaders[add]
	m.set_shader_parameter("hue", _hue)
	return m


func _tint(c: Color) -> Color:
	return Color.from_hsv(fposmod(c.h + _hue, 1.0), c.s, c.v, c.a)


func _flash_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _flash_shader
	return m


func _seq() -> Tween:
	return create_tween().set_ignore_time_scale(true).set_speed_scale(speed)


func _tw() -> Tween:
	return _seq().set_parallel(true)


## await 가능: 띠가 접혀 전장이 다시 보이기 시작하면 끝난다.
## hero: Layout.PORTRAITS 의 영웅 id (초상·눈 위치). 마법사가 아니면 띠·성운 색을 col 쪽으로 돌린다.
func play(skill_name: String, hero_name: String, col: Color, audio: Node = null, voice := "", hero := "mage") -> void:
	_hero = hero if Layout.PORTRAITS.has(hero) else "mage"
	_hue = 0.0 if _hero == "mage" else col.h - BASE_COL.h
	var t_impact := _f("impact")
	var t_exit := _f("exit")
	var t_close := _f("close")
	_build(skill_name, hero_name, col)
	_t0 = _now()
	_last = _t0
	_running = true
	_sfx(audio, "whoosh", 0.0, 1.0, 1.35)
	var tw := _tw()
	# 딤 + 스파클 필드
	tw.tween_property(_dim, "color:a", _f("dim"), 0.1)
	var field: Sprite2D = _root.get_node("sparkle_field")
	field.modulate.a = 0.0
	tw.tween_property(field, "modulate:a", Layout.PIECES["sparkle_field"][1], 0.25).set_delay(t_impact)
	# 검은 띠: 오른쪽에서, 보라 띠: 왼쪽에서 — 기울어진 채 날아와 맞물린다
	var dist := _f("band_dist")
	_band_black.position.x += dist
	_band_black.skew = -_f("band_skew")
	tw.tween_property(_band_black, "position:x", _band_black.position.x - dist, t_impact).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_band_black, "skew", 0.0, t_impact + 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var frame_x := _band_frame.position.x
	_band_frame.position.x = frame_x - dist * 1.08
	_band_frame.skew = _f("band_skew") * 0.9
	tw.tween_property(_band_frame, "position:x", frame_x, t_impact).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(0.015)
	tw.tween_property(_band_frame, "skew", 0.0, t_impact + 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.015)
	# 캐릭터: 가로로 늘어진 채 왼쪽에서 미끄러져 와 딱 멈춤 → 천천히 줌인
	var p_pos := _portrait.position
	var p_sc := _portrait.scale
	var arrive := _f("arrive_sec")
	_portrait.position = p_pos + Vector2(-_f("slide"), 0)
	_portrait.scale = p_sc * Vector2(_f("smear_x"), _f("smear_y"))
	(_portrait.material as ShaderMaterial).set_shader_parameter("flash", 1.0)
	tw.tween_property(_portrait, "position", p_pos + Vector2(14, 0), arrive).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.06)
	tw.tween_property(_portrait, "scale", p_sc, arrive).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.06)
	tw.tween_property(_portrait.material, "shader_parameter/flash", 0.0, maxf(_f("silhouette_sec"), 0.001)).set_delay(t_impact)   # 흰 실루엣으로 날아와 멈추는 순간 색이 돌아온다
	var hold := _seq()
	var settled := 0.06 + arrive + 0.01
	hold.tween_interval(settled)
	hold.tween_property(_portrait, "scale", p_sc * _f("push_in"), maxf(t_exit - settled, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hold.parallel().tween_property(_portrait, "position", p_pos + Vector2(-6, -8), maxf(t_exit - settled, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 창 안 배경: 성운은 느리게, 먼지는 빠르게 흐른다
	var neb: Sprite2D = _content.get_node("nebula")
	var motes: Sprite2D = _content.get_node("motes")
	var drift := _f("drift")
	tw.tween_property(neb, "position:x", neb.position.x - 220.0 * drift, t_exit + t_close).from(neb.position.x + 160.0 * drift)
	tw.tween_property(motes, "position:x", motes.position.x - 520.0 * drift, t_exit + t_close).from(motes.position.x + 420.0 * drift)
	# 조각 띠: 반대쪽에서 날아와 꽂힌 뒤 살짝 떠다닌다
	var slivers := ["sliver_1", "sliver_2", "sliver_3", "sliver_4"]
	for i in slivers.size():
		var s: Sprite2D = _band_frame.get_node(slivers[i])
		var home := s.position
		var dir := 1.0 if home.x > 0.0 else -1.0
		s.position = home + Vector2(dir * _f("sliver_dist"), 0)
		var st := _seq()
		st.tween_interval(0.07 + i * 0.025)
		st.tween_property(s, "position", home, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		st.tween_property(s, "position", home + Vector2(-dir * 26.0, 0), maxf(t_exit - 0.3, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 맞물림 / 반짝 / 퇴장 박자
	# 박자 순서가 뒤집히게 조절해도 각자 제 시각에 오도록 따로 건다
	for cue in [[t_impact, _on_impact.bind(audio, col, voice)], [_f("glint"), _on_glint.bind(audio, col)], [t_exit, _on_exit.bind(audio)]]:
		var beat := _seq()
		beat.tween_interval(maxf(cue[0], 0.001))
		beat.tween_callback(cue[1])
	_title(skill_name, hero_name, col)
	await get_tree().create_timer((t_exit + t_close) / speed, true, false, true).timeout
	_ended = true
	if _line_done:
		queue_free()


func _sfx(audio: Node, n: String, pv: float, db: float, pitch: float) -> void:
	if not _muted and audio != null and is_instance_valid(audio):
		audio.play(n, pv, db, pitch)


func _on_impact(audio: Node, col: Color, voice: String) -> void:
	impact.emit()
	_sfx(audio, "super_ult", 0.0, 0.0, 1.0)   # "파칭~!" — ElevenLabs 8개 중 무작위 (전에는 합성 clash+boom)
	if voice != "":
		_sfx(audio, voice, 0.0, 0.0, 1.0)
	_shake_amp = _f("shake")
	_shake_t = 0.0
	# 전체 줌 펀치
	_root.scale = _base_scale * _f("zoom_punch")
	_tw().tween_property(_root, "scale", _base_scale, _f("zoom_sec")).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# 캐릭터 색수차 잔상: 빨강·파랑이 양옆으로 튀었다 모인다
	var split := _f("rgb_split")
	for k in (2 if split > 0.0 and _f("rgb_alpha") > 0.0 else 0):
		var g := Sprite2D.new()
		g.texture = _portrait.texture
		g.scale = _portrait.scale
		g.material = VDVfx.add_material()
		g.modulate = Fx.col("rgb_col_a", _f("rgb_alpha")) if k == 0 else Fx.col("rgb_col_b", _f("rgb_alpha"))
		var off := Vector2(-split if k == 0 else split, 4 if k == 0 else -4)
		g.position = _portrait.position + off
		_content.add_child(g)
		_content.move_child(g, _portrait.get_index() + 1)
		var gt := _tw()
		gt.tween_property(g, "position", _portrait.position, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		gt.tween_property(g, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		gt.chain().tween_callback(g.queue_free)
	# 화면 섬광 + 창 흰 번쩍
	_flash.color = Fx.col("flash_col", _f("flash"))
	_tw().tween_property(_flash, "color:a", 0.0, maxf(_f("flash_sec"), 0.001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var wf: ColorRect = _content.get_node("window_flash")
	wf.color.a = _f("window_flash")
	_tw().tween_property(wf, "color:a", 0.0, 0.07)
	# 띠 세로 찌그러짐 (맞물린 반동)
	for band: Node2D in [_band_black, _band_frame]:
		band.scale.y = _f("squash")
		_tw().tween_property(band, "scale:y", 1.0, _f("squash_sec")).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# 대각 섬광: 가늘게 번쩍 → 퍼지며 남는다
	var slash: Sprite2D = _root.get_node("slash")
	slash.modulate.a = 1.0
	slash.scale = Vector2(0.35, 1.5)
	var tw := _tw()
	tw.tween_property(slash, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(slash, "modulate:a", _f("slash_alpha"), 0.3).set_delay(0.08)
	# 별: 0 → 크게 튀었다 → 반짝반짝
	for n in ["sparkle_a", "sparkle_b"]:
		var s: Sprite2D = _root.get_node(n)
		s.modulate.a = 1.0
		s.scale = Vector2.ZERO
		s.rotation = -PI * 0.5
		var st := _seq()
		st.tween_property(s, "scale", Vector2.ONE * _f("sparkle_pop"), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		st.parallel().tween_property(s, "rotation", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		st.tween_property(s, "scale", Vector2.ONE, 0.15)
		for k in 3:   # 반짝반짝
			st.tween_property(s, "scale", Vector2.ONE * 0.72, 0.09).set_trans(Tween.TRANS_SINE)
			st.tween_property(s, "scale", Vector2.ONE * 1.12, 0.11).set_trans(Tween.TRANS_SINE)
	# 맞물린 자리에서 튀는 작은 별 조각
	for i in int(_f("sparks")):
		_spark(Vector2(randf_range(-700, 700), randf_range(-60, 40)), col)


func _on_glint(audio: Node, col: Color) -> void:
	_sfx(audio, "chime", 0.0, 2.0, 1.7)
	var g := Sprite2D.new()
	g.texture = _tex("sparkle_b")
	g.material = VDVfx.add_material()
	# 눈: 지금(밀려 들어오고 줌인 중인) 초상 위의 눈 자리를 반짝 노드 좌표로 옮긴다
	var eye := _shake_node.get_global_transform().affine_inverse() * (_portrait.get_global_transform() * (Layout.PORTRAITS[_hero][3] as Vector2))
	g.position = eye
	g.scale = Vector2.ZERO
	g.modulate = Fx.col("glint_col")
	_shake_node.add_child(g)
	var tw := _seq()
	tw.tween_property(g, "scale", Vector2.ONE * 0.95, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(g, "rotation", PI * 0.5, 0.45)
	tw.tween_property(g, "scale", Vector2.ZERO, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(g.queue_free)
	# 눈에서 퍼지는 고리
	var ring := _ring(Color(col.lightened(0.5), 0.9), 34.0)
	ring.position = eye
	_shake_node.add_child(ring)
	var rt := _tw()
	rt.tween_property(ring, "scale", Vector2.ONE * maxf(_f("ring"), 0.01), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring, "modulate:a", 0.0, 0.35)
	rt.chain().tween_callback(ring.queue_free)


func _on_exit(audio: Node) -> void:
	var t_close := _f("close")
	_sfx(audio, "whoosh", 0.0, 0.0, 1.8)
	var band_y: float = Layout.PIECES["band_frame"][0].y
	var tw := _tw()
	for band: Node2D in [_band_black, _band_frame]:
		tw.tween_property(band, "scale:y", 0.0, t_close).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw.tween_property(band, "position:y", band_y, t_close).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	for n in ["slash", "sparkle_a", "sparkle_b", "sparkle_field"]:
		tw.tween_property(_root.get_node(n), "modulate:a", 0.0, 0.12)
	var title: Node2D = _shake_node.get_node_or_null("Title")
	if title:
		tw.tween_property(title, "position:x", title.position.x + 900.0, t_close).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw.tween_property(title, "modulate:a", 0.0, t_close)
	tw.tween_property(_dim, "color:a", 0.0, 0.3).set_delay(t_close * 0.5)
	# 접힌 자리에서 밝은 선이 가로로 퍼지며 사라진다
	var line := Polygon2D.new()
	line.polygon = PackedVector2Array([Vector2(-1200, -7), Vector2(1200, -7), Vector2(1200, 7), Vector2(-1200, 7)])
	line.color = _tint(Fx.col("line_col"))
	line.position = Vector2(0, band_y)
	line.rotation = _band_frame.rotation
	line.scale = Vector2(0.3, 1.0)
	line.modulate.a = 0.0
	_shake_node.add_child(line)
	var lt := _seq()
	lt.tween_interval(t_close * 0.8)
	lt.tween_property(line, "modulate:a", 1.0, 0.02)
	lt.tween_property(line, "scale", Vector2(1.4, 0.1), _f("line_sec")).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	lt.parallel().tween_property(line, "modulate:a", 0.0, _f("line_sec"))
	lt.tween_callback(_on_line_done)


func _on_line_done() -> void:
	_line_done = true
	if _ended:
		queue_free()


## 연구실에서 다시 재생할 때: 화면·소리만 끄고 남은 박자는 조용히 흘려보낸 뒤 스스로 지워진다.
func abort() -> void:
	visible = false
	_muted = true


func _process(_delta: float) -> void:
	if not _running:
		return
	var now := _now()
	var dt := minf(now - _last, 0.05 * speed)
	_last = now
	var t := now - _t0
	# 흔들림: 맞물린 순간부터 빠르게 감쇠
	_shake_t += dt
	var amp := _shake_amp * exp(-_shake_t * _f("shake_decay"))
	_shake_node.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amp if amp > 0.5 else Vector2.ZERO
	# 창 안 속도선 (오른쪽 → 왼쪽)
	var gap := maxf(_f("speed_lines"), 0.005)
	if t > 0.05 and t < _f("exit"):
		_speed_acc += dt
		while _speed_acc > gap:
			_speed_acc -= gap
			_speed_line()


func _speed_line() -> void:
	var w: Vector2 = _window.texture.get_size()
	var l := Polygon2D.new()
	var ln := randf_range(180, 520)
	var th := randf_range(2.0, 5.0)
	l.polygon = PackedVector2Array([Vector2(0, -th * 0.5), Vector2(ln, -th * 0.2), Vector2(ln, th * 0.2), Vector2(0, th * 0.5)])
	l.color = Fx.col("speed_col", randf_range(0.25, 0.6))
	l.position = Vector2(w.x * 0.55, randf_range(-w.y * 0.45, w.y * 0.45))
	_speed_root.add_child(l)
	var tw := _tw()
	tw.tween_property(l, "position:x", -w.x * 0.55 - ln, randf_range(0.14, 0.24))
	tw.chain().tween_callback(l.queue_free)


func _spark(at: Vector2, col: Color) -> void:
	var s := Polygon2D.new()
	var pts := PackedVector2Array()
	var r := randf_range(8.0, 16.0)
	for k in 8:
		var a := TAU * k / 8.0
		pts.append(Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.28))
	s.polygon = pts
	s.color = col.lightened(randf_range(0.4, 0.8))
	s.material = VDVfx.add_material()
	s.position = at
	_shake_node.add_child(s)
	var dir := Vector2(randf_range(-1, 1), randf_range(-1.2, 0.4)).normalized() * randf_range(140, 320)
	var tw := _tw()
	tw.tween_property(s, "position", at + dir, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "rotation", randf_range(-4, 4), 0.45)
	tw.tween_property(s, "scale", Vector2.ZERO, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(s.queue_free)


func _ring(col: Color, r: float) -> Line2D:
	var l := Line2D.new()
	for k in 33:
		var a := TAU * k / 32.0
		l.add_point(Vector2(cos(a), sin(a)) * r)
	l.width = 5.0
	l.default_color = col
	l.material = VDVfx.add_material()
	return l


func _title(skill_name: String, hero_name: String, col: Color) -> void:
	var g := Node2D.new()
	g.name = "Title"
	g.position = TITLE_POS
	g.rotation = deg_to_rad(-1.6)
	g.skew = -0.22               # 앞으로 기운 글씨
	g.modulate.a = 0.0
	_shake_node.add_child(g)
	# 그림자 → 본문 순: 보라 그림자가 오른쪽 아래로 두껍게 깔린다
	var sh := _label(skill_name + "!", 84, col.darkened(0.55), col.darkened(0.55), 22)
	sh.position = Vector2(-414, -50)
	g.add_child(sh)
	var nm := _label(skill_name + "!", 84, Fx.col("title_fill"), Fx.col("title_ink"), 20)
	nm.position = Vector2(-420, -58)
	g.add_child(nm)
	var hn := _label(hero_name, 30, col.lightened(0.6), Fx.col("hero_ink"), 10)
	hn.position = Vector2(-440, -116)
	g.add_child(hn)
	g.scale = Vector2.ONE * _f("title_scale")
	var tw := _seq()
	tw.tween_interval(maxf(_f("glint") - 0.04, 0.001))
	tw.tween_property(g, "modulate:a", 1.0, 0.04)
	tw.parallel().tween_property(g, "scale", Vector2.ONE, _f("title_sec")).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_kick.bind(_f("title_kick")))


func _label(text: String, size: int, col: Color, outline_col: Color, outline: int) -> Label:
	if _bold_font == null:
		_bold_font = GameFonts.bold()   # 강조 역할
	var l := Label.new()
	l.text = text
	l.size = Vector2(840, size * 1.4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_font_override("font", _bold_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", outline_col)
	l.add_theme_constant_override("outline_size", outline)
	return l


# ---------------------------------------------------------------- 조립

func _build(_skill_name: String, _hero_name: String, _col: Color) -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := vp.y / 1080.0
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0)
	_dim.size = vp
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_root = Node2D.new()
	_root.position = vp * 0.5
	_base_scale = Vector2.ONE * s
	_root.scale = _base_scale
	add_child(_root)
	# 화면이 16:9 보다 넓으면 띠만 가로로 늘린다 (창 안 그림은 되돌린다)
	var kx := maxf(1.0, vp.x / s / 1980.0)
	_sprite(_root, "sparkle_field", true)
	for n in ["sparkle_a", "sparkle_b"]:
		_sprite(_root, n, true).modulate.a = 0.0
	_shake_node = Node2D.new()
	_root.add_child(_shake_node)
	_band_black = _sprite(_shake_node, "band_black")
	_band_black.scale.x = kx
	_band_frame = Node2D.new()
	_band_frame.position = Layout.PIECES["band_frame"][0]
	_shake_node.add_child(_band_frame)
	var fr := _sprite(_band_frame, "band_frame")
	fr.position = Vector2.ZERO
	fr.scale.x = kx
	for n in ["sliver_1", "sliver_2", "sliver_3", "sliver_4"]:
		var sl := _sprite(_band_frame, n)
		sl.position -= _band_frame.position
	_window = _sprite(_band_frame, "window")
	_window.position = Layout.PIECES["window"][0] - _band_frame.position
	_window.scale.x = kx
	_window.self_modulate = _tint(Fx.col("window_bg"))   # 창 바탕 (성운 띠 밖)
	_window.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_content = Node2D.new()
	_content.scale.x = 1.0 / kx
	_window.add_child(_content)
	var wc: Vector2 = Layout.PIECES["window"][0]
	for n in ["nebula", "motes"]:
		var sp := _sprite(_content, n)
		sp.position -= wc
		# 띠를 늘린 만큼 + 흐르는 거리만큼 넉넉히 늘린다 (창 끝에서 그림 가장자리가 드러나지 않게)
		sp.scale.x = kx * 1.3
	_speed_root = Node2D.new()
	_content.add_child(_speed_root)
	_portrait = Sprite2D.new()
	var pd: Array = Layout.PORTRAITS[_hero]
	_portrait.texture = _tex(pd[0])
	_portrait.position = pd[1] - wc
	_portrait.scale = Vector2.ONE * pd[2]
	_portrait.material = _flash_mat()
	_content.add_child(_portrait)
	var wf := ColorRect.new()
	wf.name = "window_flash"
	var wsz: Vector2 = _window.texture.get_size()
	wf.size = wsz * Vector2(kx, 1.0)
	wf.position = -wf.size * 0.5
	wf.color = Color(1, 1, 1, 0)
	wf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(wf)
	var slash := _sprite(_root, "slash", true)
	slash.modulate.a = 0.0
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.size = vp
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


## 흔들림을 최소 amp 로 다시 걷어찬다 (도장 찍힐 때).
func _kick(amp: float) -> void:
	_shake_amp = maxf(_shake_amp * exp(-_shake_t * _f("shake_decay")), amp)
	_shake_t = 0.0
