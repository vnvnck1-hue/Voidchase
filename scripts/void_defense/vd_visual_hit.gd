## VOID DEFENSE 원화 조립 씬의 몬스터 클릭 피격. 터치 게임 데모(MonsterBehavior)의 연출을 그대로 옮겼다:
##   클릭 지점에 타격 파티클(별 섬광 + 낙뢰, scenes/void_defense/vd_hit_vfx.tscn) → 스케일 펀치 → 화이트 플래시
##   (SpriteColorLerp 셰이더) → 히트스톱 → 화면 흔들림 → 떠오르는 데미지 숫자 → 오른쪽 데미지 로그.
## 몬스터는 HP 를 가지며 0 이 되면 찌그러져 사라졌다가 잠시 후 다시 나타난다. 보스는 상단 체력바 채움이 줄어든다.
## 클릭 판정은 스프라이트의 불투명 픽셀(Sprite2D.is_pixel_opaque) 기준, 앞에 그려진 몬스터가 우선이다.
extends Node

const HIT_VFX := preload("res://scenes/void_defense/vd_hit_vfx.tscn")
const ColorLerp := preload("res://scripts/sprite_color_lerp.gd")
const VDDataS := preload("res://scripts/void_defense/vd_data.gd")

const NAMES := {"void_lord": "공허 군주", "voidling_back": "보이들링 A", "voidling_mid": "보이들링 B", "voidling_front": "보이들링 C"}
const MAX_HP := {"void_lord": 1000, "voidling_back": 100, "voidling_mid": 100, "voidling_front": 100}
const LOG_LINES := 8

# 터치 데모 body 의 값(데모 몬스터는 576px, 여기 몬스터는 150~585px 이라 펀치는 조금 키웠다)
var hit_color := Color(1, 1, 1, 1)
var flash_intensity := 0.75
var flash_duration := 0.08
var scale_multiplier := 1.12
var punch_duration := 0.12
var hit_stop_duration := 0.05
var hit_stop_time_scale := 0.0136
var shake_magnitude := 4.0
var shake_duration := 0.06
var respawn_delay := 1.6

var canvas: Node2D
var shake_target: Node2D
var _monsters: Array[Dictionary] = []   # {wrapper, sprite, id, hp, lerp, alive, tween}
var _fx_root: Node2D
var _log_label: Label
var _log: PackedStringArray = []
var _boss_fill: Sprite2D
var _boss_fill_w := 0.0
var _hit_stopping := false
var _shake_token := 0
var _shake_base := Vector2.ZERO


func setup(canvas_: Node2D, shake_target_: Node2D, hud: CanvasLayer) -> void:
	canvas = canvas_
	shake_target = shake_target_
	_fx_root = Node2D.new()
	_fx_root.name = "HitFx"
	_fx_root.z_index = 20
	canvas.add_child(_fx_root)
	for m in canvas.get_node("Monsters").get_children():
		var sp := m.get_node_or_null("sprite") as Sprite2D
		if sp == null:
			continue
		var lerp := ColorLerp.get_or_add(sp)
		lerp.set_target_color(hit_color)
		lerp.set_lerp_value(0.0)
		_monsters.append({"wrapper": m, "sprite": sp, "id": String(m.name), "hp": MAX_HP.get(m.name, 100), "lerp": lerp, "alive": true, "tween": null})
	_boss_fill = canvas.get_node_or_null("UI/boss_hp_fill") as Sprite2D
	if _boss_fill:
		_boss_fill_w = _boss_fill.texture.get_width()
		_boss_fill.region_enabled = true
		_boss_fill.region_rect = Rect2(0, 0, _boss_fill_w, _boss_fill.texture.get_height())
	_build_log(hud)
	print("[vd_visual_hit] %d monsters clickable" % _monsters.size())


func _build_log(hud: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.02, 0.1, 0.62)
	sb.border_color = Color(0.8, 0.55, 1.0, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	SceneSwitcher.pin(panel, Vector2(1, 0), Rect2(1920 - 420, 110, 400, 0))
	panel.custom_minimum_size = Vector2(400, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)
	var title := Label.new()
	title.text = "DAMAGE LOG  (몬스터를 클릭)"
	title.add_theme_font_override("font", VDDataS.font())
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))
	vb.add_child(title)
	_log_label = Label.new()
	_log_label.add_theme_font_override("font", VDDataS.font())
	_log_label.add_theme_font_size_override("font_size", 16)
	_log_label.add_theme_color_override("font_color", Color(0.95, 0.93, 1.0))
	_log_label.text = "-"
	vb.add_child(_log_label)


func _unhandled_input(event: InputEvent) -> void:
	# 합성 클릭(테스트 러너)은 마우스 위치를 갱신하지 않으므로 이벤트 좌표를 캔버스 로컬로 바꿔 쓴다
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		_click(canvas.make_input_local(event).position)


func _click(canvas_pos: Vector2) -> void:
	# 앞에 그려진(트리 뒤쪽) 몬스터부터 검사
	var global_pos := canvas.to_global(canvas_pos)
	for i in range(_monsters.size() - 1, -1, -1):
		var m := _monsters[i]
		if not m["alive"]:
			continue
		var sp: Sprite2D = m["sprite"]
		var local := sp.to_local(global_pos)
		if sp.is_pixel_opaque(local):
			_hit(m, canvas_pos)
			return


func _hit(m: Dictionary, at: Vector2) -> void:
	var wrapper: Node2D = m["wrapper"]
	var feet: Vector2 = wrapper.position
	var is_boss: bool = m["id"] == "void_lord"
	# 데미지: 8~15, 20% 치명타 x2
	var crit := randf() < 0.2
	var dmg := randi_range(8, 15) * (2 if crit else 1)
	m["hp"] = maxi(int(m["hp"]) - dmg, 0)

	# 1. 타격 파티클: 별 섬광은 클릭 지점, 낙뢰는 몬스터 발밑으로 떨어진다
	var vfx: Node2D = HIT_VFX.instantiate()
	vfx.position = at
	var s := 1.0 if is_boss else 0.55
	vfx.scale = Vector2(s, s)
	_fx_root.add_child(vfx)
	var lightning := vfx.get_node_or_null("vfx_Lightning") as Node2D
	if lightning:
		# 데모에서 낙뢰 글로우는 루트 아래 168px(발밑)에 있다 → 글로우가 발밑에 오도록 루트를 올린다
		lightning.position = (feet - at) / s - Vector2(0, 168.45 * 1.0244)
	for c in vfx.get_children():
		if c.has_method("play"):
			c.play(true)
	get_tree().create_timer(2.5).timeout.connect(vfx.queue_free)

	# 2. 스케일 펀치 (발밑 피벗 기준) + 클릭 반대쪽으로 살짝 밀림
	var old: Tween = m["tween"]
	if old:
		old.kill()
	wrapper.scale = Vector2.ONE
	wrapper.position = feet
	var push := (feet - at).normalized() * 5.0
	push.y = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(wrapper, "scale", Vector2.ONE * scale_multiplier, punch_duration * 0.3)
	tw.tween_property(wrapper, "position", feet + push, punch_duration * 0.3)
	tw.chain().tween_property(wrapper, "scale", Vector2.ONE, punch_duration * 0.7)
	tw.tween_property(wrapper, "position", feet, punch_duration * 0.7)
	m["tween"] = tw

	# 3. 화이트 플래시
	var lerp: Node = m["lerp"]
	lerp.set_lerp_value(flash_intensity)
	var ct := create_tween()
	ct.tween_method(lerp.set_lerp_value, flash_intensity, 0.0, flash_duration)

	# 4. 히트스톱  5. 화면 흔들림
	_hit_stop()
	_shake()

	# 6. 데미지 숫자 + 로그
	_number(at, dmg, crit)
	_log_line("%s  -%d%s  (HP %d/%d)" % [NAMES.get(m["id"], m["id"]), dmg, "  치명타!" if crit else "", m["hp"], MAX_HP.get(m["id"], 100)])
	if is_boss and _boss_fill:
		var ratio := float(m["hp"]) / float(MAX_HP["void_lord"])
		var bt := create_tween()
		bt.tween_method(_set_boss_fill, _boss_fill.region_rect.size.x / _boss_fill_w, ratio, 0.15)
	if m["hp"] <= 0:
		_die(m)


func _set_boss_fill(ratio: float) -> void:
	_boss_fill.region_rect = Rect2(0, 0, maxf(_boss_fill_w * ratio, 0.0), _boss_fill.texture.get_height())
	_boss_fill.visible = ratio > 0.002


func _die(m: Dictionary) -> void:
	m["alive"] = false
	var wrapper: Node2D = m["wrapper"]
	var feet: Vector2 = wrapper.position
	_log_line("%s 격파!" % NAMES.get(m["id"], m["id"]))
	var old: Tween = m["tween"]
	if old:
		old.kill()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(wrapper, "scale", Vector2(1.35, 0.05), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(wrapper, "modulate", Color(1, 1, 1, 0), 0.28)
	tw.chain().tween_interval(respawn_delay)
	tw.chain().tween_callback(func() -> void:
		m["hp"] = MAX_HP.get(m["id"], 100)
		wrapper.position = feet
		wrapper.scale = Vector2(0.2, 0.2)
		wrapper.modulate = Color(1, 1, 1, 0)
		m["alive"] = true
		if m["id"] == "void_lord" and _boss_fill:
			_set_boss_fill(1.0)
		_log_line("%s 재출현" % NAMES.get(m["id"], m["id"]))
	)
	tw.chain().tween_property(wrapper, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(wrapper, "modulate", Color(1, 1, 1, 1), 0.2)
	m["tween"] = tw


func _hit_stop() -> void:
	if _hit_stopping:
		return
	_hit_stopping = true
	Engine.time_scale = hit_stop_time_scale
	await get_tree().create_timer(hit_stop_duration, true, false, true).timeout
	if is_inside_tree():
		Engine.time_scale = 1.0
	_hit_stopping = false


func _exit_tree() -> void:
	_shake_token += 1
	if _hit_stopping:
		Engine.time_scale = 1.0
		_hit_stopping = false


func _shake() -> void:
	_shake_token += 1
	var token := _shake_token
	if shake_target == null:
		return
	var t := 0.0
	while t < shake_duration:
		var r := sqrt(randf()) * shake_magnitude
		var a := randf() * TAU
		shake_target.position = _shake_base + Vector2(cos(a), sin(a)) * r
		await get_tree().process_frame
		if token != _shake_token or not is_inside_tree():
			return
		t += get_process_delta_time() / maxf(Engine.time_scale, 0.0001)
	shake_target.position = _shake_base


## 떠오르는 데미지 숫자 (캔버스 좌표, 치명타는 크고 노랗게)
func _number(at: Vector2, dmg: int, crit: bool) -> void:
	var l := Label.new()
	l.text = "-%d" % dmg
	l.add_theme_font_override("font", VDDataS.font())
	l.add_theme_font_size_override("font_size", 42 if crit else 28)
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if crit else Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.02, 0.25, 1))
	l.add_theme_constant_override("outline_size", 8 if crit else 6)
	l.z_index = 60
	l.position = at + Vector2(randf_range(-14, 14) - 40, -70)
	l.size = Vector2(80, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.scale = Vector2(0.4, 0.4)
	l.pivot_offset = l.size * 0.5
	_fx_root.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE * (1.25 if crit else 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 55.0, 0.8).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(l.queue_free)


func _log_line(s: String) -> void:
	_log.append(s)
	while _log.size() > LOG_LINES:
		_log.remove_at(0)
	_log_label.text = "\n".join(_log)
	print("[damage] " + s)
