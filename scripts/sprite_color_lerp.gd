## Port of Unity CAT.Utility.SpriteColorLerp (Assets/KSC_251206/script/SpriteColorLerp.cs)
## Attach as a child Node of a CanvasItem (Sprite2D / Polygon2D). It swaps the parent's
## material for the SpriteColorLerp shader and drives its uniforms, like Unity's
## MaterialPropertyBlock on the SpriteRenderer.
class_name SpriteColorLerp
extends Node

const SHADER := preload("res://shaders/sprite_color_lerp.gdshader")

@export var target_color: Color = Color(1, 0, 0, 1)
@export_range(0.0, 1.0) var lerp_value: float = 0.0
@export var always_update: bool = false
@export var update_threshold: float = 0.001

var _renderer: CanvasItem
var _material: ShaderMaterial
var _last_target_color: Color = Color(-1, -1, -1, -1)
var _last_lerp_value: float = -1.0
var _is_dirty: bool = true

## Mirrors Unity's TargetColor property (sets dirty only on change).
var TargetColor: Color:
	get: return target_color
	set(value):
		if target_color != value:
			target_color = value
			_is_dirty = true

var LerpValue: float:
	get: return lerp_value
	set(value):
		var new_value: float = clampf(value, 0.0, 1.0)
		if absf(lerp_value - new_value) > update_threshold:
			lerp_value = new_value
			_is_dirty = true


static func get_or_add(renderer: CanvasItem) -> SpriteColorLerp:
	for c in renderer.get_children():
		if c is SpriteColorLerp:
			return c
	var comp := SpriteColorLerp.new()
	comp.name = "SpriteColorLerp"
	renderer.add_child(comp)
	return comp


func _enter_tree() -> void:
	_initialize_components()
	_setup_material()
	force_update()


func _ready() -> void:
	_initialize_components()
	_setup_material()
	force_update()


func _initialize_components() -> void:
	if _renderer == null:
		_renderer = get_parent() as CanvasItem


func _setup_material() -> void:
	if _renderer == null:
		return
	var m := _renderer.material as ShaderMaterial
	if m != null and m.shader == SHADER:
		_material = m
		return
	# Unity shares one material and uses a per-renderer property block; in Godot each
	# renderer needs its own ShaderMaterial instance for per-instance uniforms.
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_renderer.material = _material


func _process(_delta: float) -> void:
	# Unity: LateUpdate -> update when alwaysUpdate or dirty
	if always_update or _is_dirty:
		_update_material_properties()
		_is_dirty = false


func _update_material_properties() -> void:
	if _renderer == null or _material == null:
		return
	var has_changed := false
	if _last_target_color != target_color:
		_last_target_color = target_color
		has_changed = true
	if absf(_last_lerp_value - lerp_value) > update_threshold:
		_last_lerp_value = lerp_value
		has_changed = true
	if has_changed:
		_material.set_shader_parameter("target_color", target_color)
		_material.set_shader_parameter("lerp_value", lerp_value)


func force_update() -> void:
	_is_dirty = true
	_last_lerp_value = -1.0
	_update_material_properties()


func set_lerp_value(value: float) -> void:
	LerpValue = value


func set_target_color(color: Color) -> void:
	TargetColor = color


func set_target_color_and_lerp(color: Color, lerp: float) -> void:
	target_color = color
	lerp_value = clampf(lerp, 0.0, 1.0)
	_is_dirty = true


func set_animation_mode(use_animation: bool) -> void:
	always_update = use_animation


func refresh_material() -> void:
	_setup_material()
	force_update()


func lerp_to_target_color(duration: float) -> void:
	_run_lerp(1.0, duration)


func lerp_to_original_color(duration: float) -> void:
	_run_lerp(0.0, duration)


var _lerp_token: int = 0

func _run_lerp(target_value: float, duration: float) -> void:
	_lerp_token += 1
	var token := _lerp_token
	var start_value := lerp_value
	var elapsed := 0.0
	var previous_always_update := always_update
	always_update = true
	var tree := get_tree()
	while elapsed < duration:
		await tree.process_frame
		if token != _lerp_token or not is_inside_tree():
			return
		elapsed += get_process_delta_time()
		LerpValue = lerpf(start_value, target_value, elapsed / duration)
	LerpValue = target_value
	always_update = previous_always_update
