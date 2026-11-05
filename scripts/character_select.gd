## Character select strip at the bottom of the screen.
## The panels are the pieces of the original characters_list.png (sliced per panel, see
## tools/expand/slice_panels.py) placed exactly where the single image used to be, so the look is
## unchanged; each panel is now clickable. Selecting a character replays the avatar entrance.
## Only one rigged character exists so far, so every selection shows the same (placeholder) avatar.
class_name CharacterSelect
extends Node2D

signal character_selected(index: int)

## AnimationPlayer holding the "entrance" animation (avatar slide-in, name drop, stars).
@export var entrance_player: NodePath
## Background sprite; the < > arrows baked into it become prev/next buttons.
@export var background: NodePath
## Arrow centres in background texture pixels (main_BG_2_wide.png) and their hit radius (px).
@export var arrow_left_px := Vector2(890, 515)
@export var arrow_right_px := Vector2(1503, 515)
@export var arrow_radius_px := 48.0
## Index of the panel selected at start (-1: none).
@export var default_selection := 0
## Brightness of locked panels (metadata "locked" = true): dimmed to read as unavailable.
@export var locked_dim := 0.45
@export var hover_scale := 1.04
@export var selected_scale := 1.08
@export var selected_lift := -10.0
@export var outline_shader: Shader

## Placeholder names until each character gets its own rig/portrait data.
const NAMES := ["Character 1", "Character 2", "Character 3", "", "", "Character 4", "Character 5", "Character 6"]

var panels: Array[Sprite2D] = []
var _base_pos: Array[Vector2] = []
var _locked: Array[bool] = []
var selected := -1
var hovered := -1
var _tweens: Dictionary = {}
var _arrow_hover := 0  # -1 left, 1 right, 0 none


func _ready() -> void:
	for c in get_children():
		if c is Sprite2D:
			var s := c as Sprite2D
			panels.append(s)
			_base_pos.append(s.position)
			_locked.append(bool(s.get_meta("locked", false)) or bool(s.get_meta("empty", false)))
			if outline_shader != null:
				var m := ShaderMaterial.new()
				m.shader = outline_shader
				m.set_shader_parameter("strength", 0.0)
				s.material = m
	for i in panels.size():
		if _locked[i]:
			panels[i].self_modulate = Color(locked_dim, locked_dim, locked_dim, 1.0)
	if default_selection >= 0 and default_selection < panels.size() and not _locked[default_selection]:
		_apply_selection(default_selection, false)


func character_indices() -> Array[int]:
	var out: Array[int] = []
	for i in panels.size():
		if not _locked[i]:
			out.append(i)
	return out


func select(index: int) -> void:
	if index < 0 or index >= panels.size():
		return
	if _locked[index]:
		_shake(index)
		return
	if index == selected:
		_pop(index)
		return
	_apply_selection(index, true)


func select_next(step: int) -> void:
	var ids := character_indices()
	if ids.is_empty():
		return
	var cur := ids.find(selected)
	var nxt: int = ids[(cur + step + ids.size()) % ids.size()] if cur >= 0 else ids[0]
	select(nxt)


func _apply_selection(index: int, replay: bool) -> void:
	var prev := selected
	selected = index
	if prev >= 0:
		_update_panel(prev)
	_update_panel(index)
	panels[index].z_index = 1
	if prev >= 0 and prev != index:
		panels[prev].z_index = 0
	if replay:
		var ep := get_node_or_null(entrance_player) as AnimationPlayer
		if ep != null and ep.has_animation("entrance"):
			ep.stop()
			ep.play("entrance")
	var label: String = NAMES[index] if index < NAMES.size() else ""
	print("[character_select] selected panel %d (%s) - placeholder avatar shown" % [index, label])
	character_selected.emit(index)


func _update_panel(i: int) -> void:
	var s := panels[i]
	var target_scale := 1.0
	var lift := 0.0
	var outline := 0.0
	var bright := locked_dim if _locked[i] else 1.0
	if i == selected:
		target_scale = selected_scale
		lift = selected_lift
		outline = 1.0
	elif i == hovered and not _locked[i]:
		target_scale = hover_scale
		bright = 1.08
	_kill_tween(i)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "scale", Vector2.ONE * target_scale, 0.22)
	tw.tween_property(s, "position", _base_pos[i] + Vector2(0, lift), 0.22)
	tw.tween_property(s, "self_modulate", Color(bright, bright, bright, 1.0), 0.15).set_trans(Tween.TRANS_SINE)
	var mat := s.material as ShaderMaterial
	if mat != null:
		var from: float = float(mat.get_shader_parameter("strength"))
		tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("strength", v), from, outline, 0.18).set_trans(Tween.TRANS_SINE)
	_tweens[i] = tw


func _kill_tween(i: int) -> void:
	if _tweens.has(i) and is_instance_valid(_tweens[i]):
		(_tweens[i] as Tween).kill()


func _pop(i: int) -> void:
	var s := panels[i]
	_kill_tween(i)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2.ONE * (selected_scale * 1.06), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "scale", Vector2.ONE * selected_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tweens[i] = tw


func _shake(i: int) -> void:
	var s := panels[i]
	_kill_tween(i)
	var base := _base_pos[i]
	var tw := create_tween()
	for k in 3:
		tw.tween_property(s, "position", base + Vector2(6 - 2 * k, 0), 0.04)
		tw.tween_property(s, "position", base - Vector2(6 - 2 * k, 0), 0.04)
	tw.tween_property(s, "position", base, 0.04)
	_tweens[i] = tw


## Topmost panel whose opaque pixels contain the world position, or -1.
func panel_at(world: Vector2) -> int:
	for i in range(panels.size() - 1, -1, -1):
		var s := panels[i]
		if not s.visible or s.texture == null:
			continue
		var local := s.to_local(world)
		var size := s.texture.get_size()
		var p := local + (size * 0.5 if s.centered else Vector2.ZERO) - s.offset
		if p.x < 0.0 or p.y < 0.0 or p.x >= size.x or p.y >= size.y:
			continue
		if s.is_pixel_opaque(local):
			return i
	return -1


## -1 / 1 when the world position is over the < / > arrow of the background, else 0.
func arrow_at(world: Vector2) -> int:
	var bg := get_node_or_null(background) as Sprite2D
	if bg == null:
		return 0
	for pair in [[arrow_left_px, -1], [arrow_right_px, 1]]:
		var centre: Vector2 = bg.to_global(bg.offset + pair[0])
		var r: float = arrow_radius_px * absf(bg.global_scale.x)
		if world.distance_to(centre) <= r:
			return pair[1]
	return 0


## World position of a mouse event (works for real input and for synthetic events from tests).
func _event_world(event: InputEvent) -> Vector2:
	var local_ev := make_input_local(event) as InputEventMouse
	return to_global(local_ev.position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var world := _event_world(event)
		var h := panel_at(world)
		_arrow_hover = arrow_at(world) if h < 0 else 0
		if h != hovered:
			var old := hovered
			hovered = h
			if old >= 0:
				_update_panel(old)
			if h >= 0:
				_update_panel(h)
		var pointing := (h >= 0 and not _locked[h]) or _arrow_hover != 0
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if pointing else Input.CURSOR_ARROW)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world := _event_world(event)
		var h := panel_at(world)
		if h >= 0:
			select(h)
			get_viewport().set_input_as_handled()
			return
		var a := arrow_at(world)
		if a != 0:
			select_next(a)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT:
			select_next(-1)
		elif event.keycode == KEY_RIGHT:
			select_next(1)
