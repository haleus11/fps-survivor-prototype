class_name FPSController
extends CharacterBody3D
## Contrôleur FPS arcade : ZQSD, sprint, saut simple, caméra souris.
## Le corps ne tourne qu'autour de l'axe vertical (lacet) ; le tangage est porté par la tête.

@export var config: PlayerMovementConfig

## Multiplicateur appliqué à la marche et au sprint (réservé aux bonus de vitesse).
var speed_multiplier: float = 1.0
var is_sprinting: bool = false

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _spawn_transform: Transform3D

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/RecoilPivot/Camera3D


func _ready() -> void:
	if config == null:
		push_warning("FPSController : aucune PlayerMovementConfig assignée, valeurs par défaut utilisées.")
		config = PlayerMovementConfig.new()
	_camera.fov = config.field_of_view
	_spawn_transform = global_transform
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			apply_look(motion.relative)
		return
	var button := event as InputEventMouseButton
	if button != null and button.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Reprend la capture après une perte de focus de la fenêtre.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_update_jump_timers(delta)
	_apply_gravity(delta)
	_try_jump()
	_apply_horizontal_movement(delta)
	move_and_slide()
	if global_position.y < config.kill_plane_y:
		respawn()


## Applique un déplacement souris exprimé en pixels.
func apply_look(relative: Vector2) -> void:
	var radians_per_pixel: float = deg_to_rad(config.mouse_sensitivity)
	rotation.y = wrapf(rotation.y - relative.x * radians_per_pixel, -PI, PI)
	var pitch_direction: float = 1.0 if config.invert_y else -1.0
	var max_pitch: float = deg_to_rad(config.max_pitch_degrees)
	_head.rotation.x = clampf(_head.rotation.x + relative.y * radians_per_pixel * pitch_direction, -max_pitch, max_pitch)


func respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _update_jump_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = config.coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = config.jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	velocity.y = maxf(velocity.y - config.gravity * delta, -config.max_fall_speed)


func _try_jump() -> void:
	var wants_jump: bool = _jump_buffer_timer > 0.0 or Input.is_action_just_pressed("jump")
	var can_jump: bool = is_on_floor() or _coyote_timer > 0.0
	if not (wants_jump and can_jump):
		return
	velocity.y = config.jump_velocity
	# Consommer les deux tolérances empêche tout second saut avant le prochain contact au sol.
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0


func _apply_horizontal_movement(delta: float) -> void:
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var has_input: bool = input_vector != Vector2.ZERO
	is_sprinting = has_input and Input.is_action_pressed("sprint")
	var base_speed: float = config.sprint_speed if is_sprinting else config.walk_speed
	var direction: Vector3 = global_transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)
	var target: Vector2 = Vector2(direction.x, direction.z) * base_speed * speed_multiplier
	var on_floor: bool = is_on_floor()
	var rate: float
	if has_input:
		rate = config.ground_acceleration if on_floor else config.air_acceleration
	else:
		rate = config.ground_deceleration if on_floor else config.air_deceleration
	var horizontal: Vector2 = Vector2(velocity.x, velocity.z).move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
