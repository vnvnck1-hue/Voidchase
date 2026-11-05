## Port of Unity MonsterBehavior (Assets/KSC_251206/script/MonsterBehavior.cs)
## Attach to the Node2D that had the component ("body"). Needs an Area2D child (the
## BoxCollider2D) for click detection.
class_name MonsterBehavior
extends Node2D

## Unity ParticleEffectSetting { ParticleSystem system; float delay; int repeatCount; }
@export var health_bar: HealthBar
@export var damage_per_hit: float = 10.0

@export var hit_effect_systems: Array[NodePath] = []
@export var hit_effect_delays: Array[float] = []
@export var hit_effect_repeat_counts: Array[int] = []

@export var color_effect_targets: Array[NodePath] = []

@export var hit_color: Color = Color(1, 0, 0, 1)
@export_range(0.0, 1.0) var flash_intensity: float = 1.0
@export_range(0.01, 1.0) var flash_duration: float = 0.1

@export var scale_multiplier: float = 1.2
@export var punch_duration: float = 0.15

@export var use_hit_stop: bool = true
@export_range(0.0, 0.5) var hit_stop_duration: float = 0.05
@export_range(0.0, 1.0) var hit_stop_time_scale: float = 0.0

@export var use_camera_shake: bool = true
@export var shake_magnitude: float = 0.1
@export var shake_duration: float = 0.1

const UNITS_TO_PX := 100.0

var _original_scale: Vector2
var _initial_camera_pos: Vector2
var _camera: Camera2D
var _color_targets: Array[SpriteColorLerp] = []

var _tween_token := 0
var _color_token := 0
var _shake_token := 0
static var _is_hit_stopping := false


func _ready() -> void:
	_original_scale = scale
	_camera = get_viewport().get_camera_2d()
	if _camera != null:
		_initial_camera_pos = _camera.position
	for p in color_effect_targets:
		var n := get_node_or_null(p)
		if n is SpriteColorLerp:
			_color_targets.append(n)
	if _color_targets.is_empty():
		refresh_targets()


## Unity RefreshTargets: GetComponentsInChildren<SpriteRenderer>(true) -> add SpriteColorLerp
func refresh_targets() -> void:
	_color_targets.clear()
	for sprite in _find_sprites(self):
		var comp := SpriteColorLerp.get_or_add(sprite)
		if not _color_targets.has(comp):
			_color_targets.append(comp)


func _find_sprites(node: Node) -> Array[CanvasItem]:
	var out: Array[CanvasItem] = []
	if node is Sprite2D or node is Polygon2D:
		out.append(node)
	for c in node.get_children():
		if c is UnityParticles2D:
			continue
		out.append_array(_find_sprites(c))
	return out


func _unhandled_input(event: InputEvent) -> void:
	# Unity: Input.GetMouseButtonDown(0) + Physics2D.OverlapPoint(mouseWorldPos)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_detect_click(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_detect_click(event.position)


func _detect_click(screen_pos: Vector2) -> void:
	# Unity: Camera.main.ScreenToWorldPoint(Input.mousePosition)
	var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var hits := space.intersect_point(params, 32)
	for h in hits:
		var collider: Node = h.get("collider")
		if collider == null:
			continue
		if collider == self or is_ancestor_of(collider):
			act()
			return


func _exit_tree() -> void:
	# Stop every running coroutine: once this node is out of the tree, get_tree() is null and
	# get_process_delta_time() is 0, so the frame loops below would spin forever.
	_tween_token += 1
	_color_token += 1
	_shake_token += 1
	if _is_hit_stopping:
		Engine.time_scale = 1.0
		_is_hit_stopping = false


func act() -> void:
	if health_bar != null:
		health_bar.take_damage(damage_per_hit)
	else:
		push_warning("HealthBar가 연결되지 않았습니다! Inspector에서 할당해주세요.")

	# 1. particles
	_play_all_particles()

	# 2. scale punch
	_tween_token += 1
	scale = _original_scale
	_scale_punch(_tween_token)

	# 3. color flash
	if not _color_targets.is_empty():
		_color_token += 1
		for target in _color_targets:
			if target != null:
				target.set_target_color(hit_color)
		_color_flash_routine(_color_token)

	# 4. hit stop
	if use_hit_stop:
		_hit_stop_routine()

	# 5. camera shake
	if use_camera_shake and _camera != null:
		_shake_token += 1
		_camera.position = _initial_camera_pos
		_camera_shake_routine(_shake_token)


func _camera_shake_routine(token: int) -> void:
	var tree := get_tree()
	var elapsed := 0.0
	while elapsed < shake_duration:
		var random_point := _random_inside_unit_circle() * shake_magnitude * UNITS_TO_PX
		_camera.position = _initial_camera_pos + Vector2(random_point.x, -random_point.y)
		# Unity uses unscaledDeltaTime here
		var ts := maxf(Engine.time_scale, 0.0001)
		elapsed += get_process_delta_time() / ts
		await tree.process_frame
		if token != _shake_token or not is_inside_tree() or not is_instance_valid(_camera):
			return
	_camera.position = _initial_camera_pos


func _random_inside_unit_circle() -> Vector2:
	var r := sqrt(randf())
	var a := randf() * TAU
	return Vector2(cos(a), sin(a)) * r


func _hit_stop_routine() -> void:
	_is_hit_stopping = true
	Engine.time_scale = hit_stop_time_scale
	# WaitForSecondsRealtime
	await get_tree().create_timer(hit_stop_duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_is_hit_stopping = false


func _play_all_particles() -> void:
	for i in hit_effect_systems.size():
		var ps := get_node_or_null(hit_effect_systems[i]) as UnityParticles2D
		if ps != null:
			var delay := hit_effect_delays[i] if i < hit_effect_delays.size() else 0.0
			var repeat := hit_effect_repeat_counts[i] if i < hit_effect_repeat_counts.size() else 1
			_delayed_particle_play(ps, delay, repeat)


func _delayed_particle_play(ps: UnityParticles2D, delay: float, repeat_count: int) -> void:
	var tree := get_tree()
	if delay > 0:
		await tree.create_timer(delay).timeout
	for i in repeat_count:
		if not is_instance_valid(ps) or not ps.is_inside_tree():
			return
		ps.stop()
		ps.play()
		if i < repeat_count - 1:
			await tree.create_timer(0.05).timeout


func _scale_punch(token: int) -> void:
	var tree := get_tree()
	var timer := 0.0
	var target_scale := _original_scale * scale_multiplier
	var expand_duration := punch_duration * 0.3
	while timer < expand_duration:
		scale = _original_scale.lerp(target_scale, timer / expand_duration)
		timer += get_process_delta_time()
		await tree.process_frame
		if token != _tween_token or not is_inside_tree():
			return
	timer = 0.0
	var restore_duration := punch_duration * 0.7
	while timer < restore_duration:
		scale = target_scale.lerp(_original_scale, timer / restore_duration)
		timer += get_process_delta_time()
		await tree.process_frame
		if token != _tween_token or not is_inside_tree():
			return
	scale = _original_scale


func _color_flash_routine(token: int) -> void:
	var tree := get_tree()
	var timer := 0.0
	for target in _color_targets:
		if target != null:
			target.set_lerp_value(flash_intensity)
	while timer < flash_duration:
		var c := lerpf(flash_intensity, 0.0, timer / flash_duration)
		for t in _color_targets:
			if t != null:
				t.set_lerp_value(c)
		timer += get_process_delta_time()
		await tree.process_frame
		if token != _color_token or not is_inside_tree():
			return
	for target in _color_targets:
		if target != null:
			target.set_lerp_value(0.0)
