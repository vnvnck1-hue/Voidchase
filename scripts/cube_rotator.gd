## Port of Unity CubeRotator (Assets/Scripts/CubeRotator.cs)
## transform.Rotate(x*dt, y*dt, z*dt) in local space, every frame.
extends Node3D

@export var rotation_speed_x: float = 0.0
@export var rotation_speed_y: float = 90.0
@export var rotation_speed_z: float = 0.0


func _process(delta: float) -> void:
	# Unity's Rotate(eulers) applies Quaternion.Euler(eulers) (Z, then X, then Y) in local
	# space. Unity is left-handed (camera looks +Z), Godot right-handed (camera looks -Z);
	# mirroring the view along Z flips the sign of rotations about X and Y.
	var q := Quaternion(Vector3(0, 0, 1), deg_to_rad(rotation_speed_z * delta))
	q = Quaternion(Vector3(1, 0, 0), deg_to_rad(-rotation_speed_x * delta)) * q
	q = Quaternion(Vector3(0, 1, 0), deg_to_rad(-rotation_speed_y * delta)) * q
	quaternion = quaternion * q
