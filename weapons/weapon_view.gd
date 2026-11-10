class_name WeaponView
extends Node3D
## Représentation visuelle d'une arme : recul visuel, flash de bouche, animations procédurales
## de rechargement et de sortie. Aucune logique de jeu ici.

@export var kick_return_speed: float = 16.0
@export var flash_duration: float = 0.045
@export var equip_return_speed: float = 12.0
@export var equip_offset: Vector3 = Vector3(0.0, -0.18, 0.05)
@export var reload_offset: Vector3 = Vector3(0.0, -0.1, 0.04)
@export var reload_roll_degrees: float = 35.0
@export var reload_pitch_degrees: float = 12.0

## Progression du rechargement (0 → 1), -1 hors rechargement. Écrit par Weapon.
var reload_progress: float = -1.0

var _kick: float = 0.0
var _kick_distance: float = 0.0
var _kick_degrees: float = 0.0
var _equip: float = 0.0
var _flash_timer: float = 0.0
var _rest_transform: Transform3D

@onready var _model: Node3D = $Model
@onready var _flash: Node3D = get_node_or_null("Model/Muzzle/Flash")


func _ready() -> void:
	_rest_transform = _model.transform
	if _flash != null:
		_flash.visible = false


func play_fire(kick_distance: float, kick_degrees: float) -> void:
	_kick = 1.0
	_kick_distance = kick_distance
	_kick_degrees = kick_degrees
	if _flash != null:
		_flash_timer = flash_duration
		_flash.rotation.z = randf() * TAU
		_flash.visible = true


func play_equip() -> void:
	_equip = 1.0


func _process(delta: float) -> void:
	_kick *= exp(-kick_return_speed * delta)
	_equip *= exp(-equip_return_speed * delta)
	var reload_amount: float = sin(reload_progress * PI) if reload_progress >= 0.0 else 0.0
	var offset: Vector3 = Vector3(0.0, 0.0, _kick * _kick_distance) + equip_offset * _equip + reload_offset * reload_amount
	var pitch: float = deg_to_rad(_kick * _kick_degrees + reload_amount * reload_pitch_degrees - _equip * 25.0)
	var roll: float = deg_to_rad(reload_amount * reload_roll_degrees)
	var model_transform: Transform3D = _rest_transform
	model_transform.origin += offset
	model_transform.basis = _rest_transform.basis * Basis.from_euler(Vector3(pitch, 0.0, roll))
	_model.transform = model_transform
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and _flash != null:
			_flash.visible = false
