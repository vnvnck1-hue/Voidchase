## Port of Unity IKManager2D: runs every LimbSolver2D in order, after animation (LateUpdate).
## Place this node AFTER the AnimationPlayer in tree order (process_priority also set high).
class_name IKManager2D
extends Node

@export_range(0.0, 1.0) var weight: float = 1.0
@export var solvers: Array[NodePath] = []
@export var always_update: bool = true

var _solvers: Array[LimbSolver2D] = []


func _ready() -> void:
	process_priority = 100
	for p in solvers:
		var s := get_node_or_null(p) as LimbSolver2D
		if s != null:
			_solvers.append(s)
	for s in _solvers:
		s.initialize()


func _process(_delta: float) -> void:
	update_manager()


func update_manager() -> void:
	for s in _solvers:
		if s == null or not s.is_inside_tree() or not s.can_process():
			continue
		if not s.is_valid():
			s.initialize()
		s.update_ik(weight)
