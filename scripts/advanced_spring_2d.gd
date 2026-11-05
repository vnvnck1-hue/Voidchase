## Port of Unity AdvancedSpring2D (Assets/KSC_251206/script/AdvancedSpring2D.cs), runtime part.
## All physics is computed in Unity space (metres, y-up, CCW degrees) and converted to the
## Godot node at the end so the feel matches the original exactly.
## Runs in _process after the AnimationPlayer (LateUpdate equivalent): tree order places
## this node after the animated parent chain.
class_name AdvancedSpring2D
extends Node2D

const PX := 100.0

enum SpringPreset { CUSTOM, SOFT_HAIR, HEAVY_TAIL, LIGHT_SILK, BOUNCY_JELLY, STIFF_METAL }

@export var preset: SpringPreset = SpringPreset.CUSTOM
@export_range(0.0, 10.0) var max_distance: float = 1.0
@export_range(0.0, 180.0) var max_rotation: float = 45.0
@export_range(0.01, 1.0) var elasticity: float = 0.2
@export_range(0.01, 1.0) var softness: float = 0.15
@export_range(0.0, 200.0) var reaction_force: float = 20.0
## In Unity local units (metres, y-up)
@export var physics_pivot_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 20.0) var wind_strength: float = 0.0
@export_range(0.0, 10.0) var wind_speed: float = 2.0
@export var target_transform: Node2D
@export var invert_rotation: bool = false
@export_range(-180.0, 180.0) var rotation_bias: float = 0.0
@export var use_position: bool = true
@export var use_rotation: bool = true
@export var lock_x: bool = false
@export var lock_y: bool = false
@export var teleport_threshold: float = 10.0
## Saved pose from Unity (local to target, Unity units / degrees)
@export var saved_local_pivot_pos: Vector2 = Vector2.ZERO
@export var saved_local_rotation_z: float = 0.0
@export var is_initialized: bool = false

var _pos_velocity := Vector2.ZERO
var _current_position_offset := Vector2.ZERO
var _rot_velocity := 0.0
var _current_rotation_offset := 0.0
var _last_world_pos := Vector2.ZERO
var _last_flipped := false
var _c_inertia := 0.0
var _c_elasticity := 0.0
var _c_softness := 0.0
var _c_max_dist := 0.0
var _c_max_rot := 0.0
var _is_sleeping := false
var _time := 0.0
var _noise := FastNoiseLite.new()


# --- Unity-space helpers -------------------------------------------------------------
static func _u_pos(godot_pos: Vector2) -> Vector2:
	return Vector2(godot_pos.x / PX, -godot_pos.y / PX)

static func _g_pos(unity_pos: Vector2) -> Vector2:
	return Vector2(unity_pos.x * PX, -unity_pos.y * PX)

## Unity world Z rotation (degrees, CCW) of a node
static func _u_rot_deg(n: Node2D) -> float:
	return -rad_to_deg(n.global_rotation)

## Unity Transform.TransformPoint (local Unity point -> Unity world point)
static func _transform_point(n: Node2D, local_u: Vector2) -> Vector2:
	return _u_pos(n.to_global(_g_pos(local_u)))

static func _inverse_transform_point(n: Node2D, world_u: Vector2) -> Vector2:
	return _u_pos(n.to_local(_g_pos(world_u)))

## TransformDirection: rotation only
static func _transform_direction(n: Node2D, local_u: Vector2) -> Vector2:
	var rot := n.global_rotation
	var v := Vector2(local_u.x, -local_u.y).rotated(rot)
	return Vector2(v.x, -v.y)

## InverseTransformVector: inverse rotation + inverse scale
static func _inverse_transform_vector(n: Node2D, world_u: Vector2) -> Vector2:
	var g := n.global_transform
	var basis := Transform2D(g.x, g.y, Vector2.ZERO)
	var v := basis.affine_inverse() * Vector2(world_u.x, -world_u.y)
	return Vector2(v.x, -v.y)

static func _lossy_scale(n: Node2D) -> Vector2:
	return n.global_transform.get_scale()

static func _delta_angle(a: float, b: float) -> float:
	var d := fposmod(b - a + 180.0, 360.0) - 180.0
	return d


func _apply_preset() -> void:
	match preset:
		SpringPreset.SOFT_HAIR: elasticity = 0.15; softness = 0.2; reaction_force = 15
		SpringPreset.HEAVY_TAIL: elasticity = 0.1; softness = 0.3; reaction_force = 40
		SpringPreset.LIGHT_SILK: elasticity = 0.3; softness = 0.1; reaction_force = 10
		SpringPreset.BOUNCY_JELLY: elasticity = 0.25; softness = 0.05; reaction_force = 30
		SpringPreset.STIFF_METAL: elasticity = 0.6; softness = 0.5; reaction_force = 50
		_: pass


func _update_cache() -> void:
	_c_inertia = pow(reaction_force / 50.0, 2.0) * 100.0
	_c_elasticity = pow(elasticity, 2.0) * 500.0
	_c_softness = softness * 20.0
	_c_max_dist = pow(max_distance / 10.0, 2.0) * 10.0
	_c_max_rot = pow(max_rotation / 180.0, 2.0) * 180.0


func capture_pose() -> void:
	if target_transform == null:
		return
	var world_pivot_pos := _transform_point(self, physics_pivot_offset)
	var pure_world_pivot := world_pivot_pos - _transform_direction(target_transform, _current_position_offset)
	saved_local_pivot_pos = _inverse_transform_point(target_transform, pure_world_pivot)
	var current_pure_rot_z := _u_rot_deg(self) - (_current_rotation_offset * signf(_lossy_scale(target_transform).x)) - rotation_bias
	saved_local_rotation_z = _delta_angle(_u_rot_deg(target_transform), current_pure_rot_z)
	is_initialized = true
	reset_physics()


func reset_physics() -> void:
	_current_position_offset = Vector2.ZERO
	_current_rotation_offset = 0.0
	_pos_velocity = Vector2.ZERO
	_rot_velocity = 0.0
	_is_sleeping = false
	if target_transform != null:
		_last_world_pos = _u_pos(target_transform.global_position)


func _ready() -> void:
	# run after AnimationPlayer (LateUpdate equivalent)
	process_priority = 10
	_apply_preset()
	_update_cache()
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = 1.0
	if target_transform != null and not is_initialized:
		capture_pose()
	reset_physics()


func _process(delta: float) -> void:
	if target_transform == null or not is_initialized:
		return
	_time += delta
	var target_pos := _u_pos(target_transform.global_position)
	var world_delta := target_pos - _last_world_pos
	_last_world_pos = target_pos

	# sleep logic
	if world_delta.length_squared() < 0.000001 and _pos_velocity.length_squared() < 0.0001 and absf(_rot_velocity) < 0.01 and wind_strength <= 0:
		if _is_sleeping:
			return
		_is_sleeping = true
	else:
		_is_sleeping = false

	var flipped := _lossy_scale(target_transform).x < 0
	if flipped != _last_flipped:
		_last_flipped = flipped
		reset_physics()
		return

	var dt := delta
	if dt <= 0 or dt > 0.1:
		dt = 0.016

	if world_delta.length() > teleport_threshold:
		reset_physics()
		return
	var local_delta := _inverse_transform_vector(target_transform, world_delta)

	if use_position:
		_pos_velocity -= local_delta * _c_inertia
		_pos_velocity -= _current_position_offset * _c_elasticity * dt
		_pos_velocity = _pos_velocity.lerp(Vector2.ZERO, dt * _c_softness)
		_current_position_offset += _pos_velocity * dt
		if lock_x: _current_position_offset.x = 0
		if lock_y: _current_position_offset.y = 0
		_current_position_offset = _current_position_offset.limit_length(_c_max_dist)

	if use_rotation:
		var torque := (local_delta.y * saved_local_pivot_pos.x) - (local_delta.x * saved_local_pivot_pos.y)
		_rot_velocity -= torque * _c_inertia * 10.0 * (-1.0 if invert_rotation else 1.0)
		if wind_strength > 0:
			var n := _noise.get_noise_2d(_time * wind_speed, float(get_instance_id() % 1000) * 0.1) * 0.5  # ~PerlinNoise - 0.5
			_rot_velocity += n * wind_strength * 100.0 * dt
		_rot_velocity -= _current_rotation_offset * _c_elasticity * dt
		_rot_velocity = lerpf(_rot_velocity, 0.0, dt * _c_softness)
		_current_rotation_offset += _rot_velocity * dt
		_current_rotation_offset = clampf(_current_rotation_offset, -_c_max_rot, _c_max_rot)

	# final apply (Unity: world rotation then world position via pivot)
	var flip_sign := signf(_lossy_scale(target_transform).x)
	var final_rot_u := _u_rot_deg(target_transform) + saved_local_rotation_z + (_current_rotation_offset * flip_sign) + rotation_bias
	global_rotation = deg_to_rad(-final_rot_u)

	var target_world_pivot := _transform_point(target_transform, saved_local_pivot_pos + _current_position_offset)
	var applied_world_pivot := _transform_point(self, physics_pivot_offset)
	global_position += _g_pos(target_world_pivot - applied_world_pivot)
