class_name Enemy
extends CharacterBody3D
## Ennemi standard : poursuit le joueur, inflige des dégâts de contact.
## Les instances sont réutilisées par l'EnemyManager (pool) : jamais de queue_free en jeu.

signal died(enemy: Enemy, info: DamageInfo)
signal fell_out(enemy: Enemy)

const BODY_RADIUS: float = 0.45
const PLAYER_RADIUS: float = 0.4
const CONTACT_HEIGHT: float = 1.5
const ACTIVE_LAYER: int = 4
## Monde + joueur : les ennemis ne se bloquent pas entre eux (la séparation est gérée à part).
const ACTIVE_MASK: int = 3
const KILL_Y: float = -20.0
const STUCK_SPEED_RATIO: float = 0.25
const STUCK_TIME: float = 0.4
const DETOUR_TIME: float = 1.2
const PARKED_POSITION := Vector3(0.0, -500.0, 0.0)

var data: EnemyData
var target: FPSController
var target_health: PlayerHealth
## Vitesse de séparation horizontale calculée chaque pas physique par l'EnemyManager.
var separation: Vector3 = Vector3.ZERO
var is_active: bool = false

var _material := StandardMaterial3D.new()
var _flash_timer: float = 0.0
var _contact_timer: float = 0.0
var _stuck_timer: float = 0.0
var _detour_timer: float = 0.0
var _detour_sign: float = 1.0

@onready var _health: HealthComponent = $HealthComponent
@onready var _body_mesh: MeshInstance3D = $Body


func _ready() -> void:
	_body_mesh.material_override = _material


func activate(enemy_data: EnemyData, at: Vector3, player: FPSController, player_health: PlayerHealth) -> void:
	data = enemy_data
	target = player
	target_health = player_health
	_health.max_health = data.max_health
	_health.reset()
	global_position = at
	velocity = Vector3.ZERO
	separation = Vector3.ZERO
	_contact_timer = 0.0
	_flash_timer = 0.0
	_stuck_timer = 0.0
	_detour_timer = 0.0
	_detour_sign = 1.0 if randf() < 0.5 else -1.0
	_material.albedo_color = data.body_color
	collision_layer = ACTIVE_LAYER
	collision_mask = ACTIVE_MASK
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	is_active = true


func deactivate() -> void:
	is_active = false
	visible = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	separation = Vector3.ZERO
	process_mode = Node.PROCESS_MODE_DISABLED
	global_position = PARKED_POSITION


## Interface commune des cibles : retourne true si l'impact tue l'ennemi.
func apply_damage(info: DamageInfo) -> bool:
	if not is_active or _health.is_dead:
		return false
	var killed: bool = _health.apply_damage(info.amount)
	_material.albedo_color = data.critical_flash_color if info.is_critical else data.hit_flash_color
	_flash_timer = data.hit_flash_duration
	if killed:
		died.emit(self, info)
	return killed


func get_health() -> float:
	return _health.current_health


func get_contact_distance() -> float:
	return BODY_RADIUS + PLAYER_RADIUS + data.contact_reach


func _physics_process(delta: float) -> void:
	if not is_active or target == null:
		return
	_update_flash(delta)
	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	var distance: float = to_target.length()
	var chase_direction: Vector3 = to_target / distance if distance > 0.001 else Vector3.ZERO
	var move_direction: Vector3 = chase_direction
	if _detour_timer > 0.0:
		_detour_timer -= delta
		var side := Vector3(-chase_direction.z, 0.0, chase_direction.x) * _detour_sign
		move_direction = (side + chase_direction * 0.2).normalized()
	var desired: Vector3 = (move_direction * data.move_speed + separation).limit_length(data.move_speed * 1.25)
	var horizontal: Vector2 = Vector2(velocity.x, velocity.z).move_toward(Vector2(desired.x, desired.z), data.acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	if not is_on_floor():
		velocity.y -= data.gravity * delta
	move_and_slide()
	_face(chase_direction, delta)
	_update_stuck(distance, delta)
	_update_contact(distance, delta)
	if global_position.y < KILL_Y:
		fell_out.emit(self)


func _face(direction: Vector3, delta: float) -> void:
	if direction == Vector3.ZERO:
		return
	var yaw: float = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-data.turn_speed * delta))


## Contournement minimal : bloqué contre un obstacle, l'ennemi longe le décor d'un côté fixe.
func _update_stuck(distance: float, delta: float) -> void:
	# Seul un blocage contre le décor déclenche le contournement (pas la pression de la foule).
	if _detour_timer > 0.0 or not is_on_wall() or distance < get_contact_distance() + 1.0:
		_stuck_timer = 0.0
		return
	var real_velocity: Vector3 = get_real_velocity()
	real_velocity.y = 0.0
	if real_velocity.length() < data.move_speed * STUCK_SPEED_RATIO:
		_stuck_timer += delta
		if _stuck_timer >= STUCK_TIME:
			_stuck_timer = 0.0
			_detour_timer = DETOUR_TIME
	else:
		_stuck_timer = 0.0


func _update_contact(distance: float, delta: float) -> void:
	_contact_timer = maxf(_contact_timer - delta, 0.0)
	if _contact_timer > 0.0 or target_health == null:
		return
	if distance > get_contact_distance():
		return
	var height: float = target.global_position.y - global_position.y
	if absf(height) > CONTACT_HEIGHT:
		return
	# L'attaque est consommée même si le joueur est invulnérable : chaque ennemi frappe au plus toutes les 0,75 s.
	target_health.take_damage(data.contact_damage, self)
	_contact_timer = data.contact_interval


func _update_flash(delta: float) -> void:
	if _flash_timer <= 0.0:
		return
	_flash_timer -= delta
	if _flash_timer <= 0.0:
		_material.albedo_color = data.body_color
