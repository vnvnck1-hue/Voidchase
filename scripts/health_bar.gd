## Port of Unity HealthBar (Assets/KSC_251206/script/HealthBar.cs)
## Unity Image.fillAmount (horizontal, origin left) -> TextureProgressBar.value (0..1).
class_name HealthBar
extends Control

@export var fill_image: TextureProgressBar
@export var damage_effect_image: TextureProgressBar

@export var max_health: float = 100.0
@export var current_health: float = 100.0

@export var fill_color: Color = Color(0, 1, 0, 1)

@export var effect_delay: float = 0.5
@export var effect_speed: float = 1.0

@export var damage_gradient: Gradient
@export var gradient_speed: float = 5.0

@export var regen_delay: float = 5.0
@export var regen_speed: float = 50.0

var _last_damage_time: float
var _current_effect_delay_timer: float
var _time: float = 0.0  # Unity Time.time (scaled)


func _ready() -> void:
	current_health = max_health
	_last_damage_time = -regen_delay
	_update_color_settings()
	update_health_bar_immediate()


func _process(delta: float) -> void:
	_time += delta
	_update_damage_effect_size(delta)
	_update_damage_effect_color()
	_update_regeneration(delta)


func _update_color_settings() -> void:
	if fill_image != null:
		fill_image.tint_progress = fill_color


func _update_damage_effect_color() -> void:
	if damage_effect_image != null and damage_gradient != null:
		var t := pingpong(_time * gradient_speed, 1.0)
		damage_effect_image.tint_progress = damage_gradient.sample(t)


func take_damage(amount: float) -> void:
	current_health -= amount
	if current_health < 0:
		current_health = 0
	_last_damage_time = _time
	_current_effect_delay_timer = effect_delay
	if fill_image != null:
		fill_image.value = current_health / max_health


func _update_damage_effect_size(delta: float) -> void:
	if damage_effect_image == null or fill_image == null:
		return
	if damage_effect_image.value > fill_image.value:
		if _current_effect_delay_timer > 0:
			_current_effect_delay_timer -= delta
		else:
			damage_effect_image.value -= effect_speed * delta
	else:
		damage_effect_image.value = fill_image.value


func _update_regeneration(delta: float) -> void:
	if _time - _last_damage_time > regen_delay and current_health < max_health:
		current_health += regen_speed * delta
		if current_health > max_health:
			current_health = max_health
		var ratio := current_health / max_health
		if fill_image != null:
			fill_image.value = ratio
		if damage_effect_image != null:
			damage_effect_image.value = ratio


func update_health_bar_immediate() -> void:
	var ratio := current_health / max_health
	if fill_image != null:
		fill_image.value = ratio
	if damage_effect_image != null:
		damage_effect_image.value = ratio


func set_images(fill: TextureProgressBar, damage_effect: TextureProgressBar) -> void:
	fill_image = fill
	damage_effect_image = damage_effect
