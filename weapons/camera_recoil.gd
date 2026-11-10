class_name CameraRecoil
extends Node3D
## Pivot entre la tête et la caméra : porte le recul de visée et le ramène progressivement à zéro.
## Séparé de la rotation souris, il ne modifie jamais la visée de base du joueur.

@export var max_pitch_degrees: float = 12.0
@export var max_yaw_degrees: float = 6.0

var _pitch_degrees: float = 0.0
var _yaw_degrees: float = 0.0
var _recovery_speed: float = 10.0


func add_kick(pitch_degrees: float, yaw_degrees: float, recovery_speed: float) -> void:
	_pitch_degrees = minf(_pitch_degrees + pitch_degrees, max_pitch_degrees)
	_yaw_degrees = clampf(_yaw_degrees + yaw_degrees, -max_yaw_degrees, max_yaw_degrees)
	_recovery_speed = recovery_speed
	_apply()


func reset() -> void:
	_pitch_degrees = 0.0
	_yaw_degrees = 0.0
	_apply()


func get_pitch_degrees() -> float:
	return _pitch_degrees


func _process(delta: float) -> void:
	if is_zero_approx(_pitch_degrees) and is_zero_approx(_yaw_degrees):
		return
	var decay: float = exp(-_recovery_speed * delta)
	_pitch_degrees *= decay
	_yaw_degrees *= decay
	_apply()


func _apply() -> void:
	rotation = Vector3(deg_to_rad(_pitch_degrees), deg_to_rad(_yaw_degrees), 0.0)
