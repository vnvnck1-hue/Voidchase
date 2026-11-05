## Port of Unity 2D Animation IK: LimbSolver2D + Solver2D + IKChain2D (two-bone analytic IK).
## Chain: [upper_limb, lower_limb, effector]; target is a separate Node2D.
## Angles here are Godot radians (y-down, CW positive). Unity's SignedAngle(a,b) in y-up CCW
## space equals -angle_to in Godot's y-down space, and both local rotation compositions are
## expressed consistently in Godot space, so the solver reproduces Unity's result mirrored.
class_name LimbSolver2D
extends Node2D

@export var constrain_rotation: bool = true
@export var solve_from_default_pose: bool = true
@export_range(0.0, 1.0) var weight: float = 1.0
@export var flip: bool = false
@export var effector: Node2D
@export var target: Node2D
## [upper, lower, effector]
@export var chain_transforms: Array[NodePath] = []
## Default local rotations (Godot radians) for RestoreDefaultPose
@export var default_local_rotations: Array[float] = []

var _transforms: Array[Node2D] = []
var _stored: Array[float] = []
var _last_final_weight := 0.0
var _valid := false


func initialize() -> void:
	_transforms.clear()
	for p in chain_transforms:
		var n := get_node_or_null(p) as Node2D
		_transforms.append(n)
	if effector == null and _transforms.size() == 3:
		effector = _transforms[2]
	if default_local_rotations.size() != _transforms.size():
		default_local_rotations.clear()
		for t in _transforms:
			default_local_rotations.append(t.rotation if t != null else 0.0)
	_stored.resize(_transforms.size())
	_valid = _transforms.size() == 3 and _transforms[0] != null and _transforms[1] != null and _transforms[2] != null and effector == _transforms[2]


func is_valid() -> bool:
	return _valid


## Solver2D.UpdateIK(globalWeight)
func update_ik(global_weight: float) -> void:
	if target == null:
		return
	if not _valid:
		initialize()
		if not _valid:
			return
	var final_weight := global_weight * weight
	var weight_changed := absf(final_weight - _last_final_weight) > 0.0001
	_last_final_weight = final_weight
	if final_weight == 0.0 and not weight_changed:
		return
	if final_weight < 1.0:
		_store_local_rotations()
	# Prepare: restore default pose
	if solve_from_default_pose:
		var count := 3 if constrain_rotation else 2
		for i in count:
			_transforms[i].rotation = default_local_rotations[i]
	var lengths := _prepare_lengths()
	var positions := [_transforms[0].global_position, _transforms[1].global_position, _transforms[2].global_position]
	_do_update_ik(target.global_position, lengths, positions)
	if constrain_rotation:
		effector.global_rotation = target.global_rotation
	if final_weight < 1.0:
		_blend_fk_to_ik(final_weight)


func _prepare_lengths() -> Array[float]:
	# IKChain2D.PrepareLengths: parent.TransformVector(child.localPosition).magnitude
	var lengths: Array[float] = [0.0, 0.0]
	for index in range(2, 0, -1):
		var current := _transforms[index]
		var parent := _transforms[index - 1]
		var g := parent.global_transform
		var v := Transform2D(g.x, g.y, Vector2.ZERO) * current.position
		lengths[index - 1] = v.length()
	return lengths


func _do_update_ik(target_position: Vector2, lengths: Array[float], positions: Array) -> void:
	var upper := _transforms[0]
	var lower := _transforms[1]
	var target_local := upper.to_local(target_position)
	target_position = upper.to_global(target_local)
	if target_local.length_squared() > 0.0:
		var angles := _limb_solve(target_position, lengths, positions)
		if angles.is_empty():
			return
		# Unity (y-up, CCW):  upperAngle = SignedAngle(right, targetLocal) + SignedAngle(lower.localPosition, right) + flip * angles[0]
		# In Godot (y-down) the visual CCW angle from a to b is -a.angle_to(b).
		var flip_sign := -1.0 if flip else 1.0
		var upper_angle_ccw := -Vector2.RIGHT.angle_to(target_local) + -(lower.position.angle_to(Vector2.RIGHT)) + flip_sign * float(angles[0])
		upper.rotation += -upper_angle_ccw  # CCW (Unity) -> Godot CW-positive
		var target_in_lower := lower.to_local(target_position)
		var lower_angle_ccw := -Vector2.RIGHT.angle_to(target_in_lower) + -(effector.position.angle_to(Vector2.RIGHT))
		lower.rotation += -lower_angle_ccw


## Limb.Solve -> [angle0, angle1] in radians (both >= 0), or [] when lengths invalid
static func _limb_solve(target_position: Vector2, lengths: Array[float], positions: Array) -> Array:
	if lengths[0] == 0.0 or lengths[1] == 0.0:
		return []
	var start_to_end: Vector2 = target_position - positions[0]
	var dist := start_to_end.length()
	var sqr_dist := start_to_end.length_squared()
	var sqr_parent := lengths[0] * lengths[0]
	var sqr_target := lengths[1] * lengths[1]
	var out := [0.0, 0.0]
	if dist <= 0.0:
		return out
	var angle0_cos := (sqr_dist + sqr_parent - sqr_target) / (2.0 * lengths[0] * dist)
	var angle1_cos := (sqr_dist - sqr_parent - sqr_target) / (2.0 * lengths[0] * lengths[1])
	if angle0_cos >= -1.0 and angle0_cos <= 1.0 and angle1_cos >= -1.0 and angle1_cos <= 1.0:
		out[0] = acos(angle0_cos)
		out[1] = acos(angle1_cos)
	return out


func _store_local_rotations() -> void:
	for i in _transforms.size():
		_stored[i] = _transforms[i].rotation


func _blend_fk_to_ik(final_weight: float) -> void:
	var count := 3 if constrain_rotation else 2
	for i in count:
		_transforms[i].rotation = lerp_angle(_stored[i], _transforms[i].rotation, final_weight)
