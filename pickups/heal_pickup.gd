class_name HealPickup
extends Node3D
## Soin lâché rarement par un ennemi : ramassé au contact si le joueur n'a pas tous ses PV.

@export var heal_amount: float = 15.0
@export var pickup_radius: float = 1.3
@export var lifetime: float = 20.0
@export var blink_time: float = 3.0
@export var bob_height: float = 0.15
@export var spin_speed: float = 2.0

var player: FPSController
var player_health: PlayerHealth

var _age: float = 0.0

@onready var _visual: Node3D = $Visual


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	if player == null or player_health == null or player_health.is_dead:
		return
	if player_health.current_health >= player_health.max_health:
		return
	var offset: Vector3 = player.global_position - global_position
	if absf(offset.y) > 2.0:
		return
	offset.y = 0.0
	if offset.length() <= pickup_radius:
		player_health.heal(heal_amount)
		queue_free()


func _process(delta: float) -> void:
	_visual.position.y = 0.6 + sin(_age * 3.0) * bob_height
	_visual.rotate_y(spin_speed * delta)
	if lifetime - _age < blink_time:
		_visual.visible = fmod(_age, 0.25) < 0.15
