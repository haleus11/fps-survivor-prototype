class_name TrainingDummy
extends StaticBody3D
## Mannequin de test immobile : encaisse les dégâts, clignote, disparaît à la mort puis réapparaît.

@export var respawn_delay: float = 1.5
@export var hit_flash_duration: float = 0.08
@export var base_color: Color = Color(0.55, 0.62, 0.7)
@export var hit_color: Color = Color(1.0, 1.0, 1.0)
@export var critical_color: Color = Color(1.0, 0.62, 0.1)

var _material := StandardMaterial3D.new()
var _flash_timer: float = 0.0
var _respawn_timer: float = 0.0

@onready var _health: HealthComponent = $HealthComponent
@onready var _mesh: MeshInstance3D = $Mesh
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _label: Label3D = $HealthLabel


func _ready() -> void:
	_material.albedo_color = base_color
	_mesh.material_override = _material
	_update_label()


func apply_damage(info: DamageInfo) -> bool:
	if _health.is_dead:
		return false
	var killed: bool = _health.apply_damage(info.amount)
	_material.albedo_color = critical_color if info.is_critical else hit_color
	_flash_timer = hit_flash_duration
	if killed:
		_die()
	_update_label()
	return killed


func reset_dummy() -> void:
	_respawn_timer = 0.0
	_health.reset()
	_collision.set_deferred("disabled", false)
	_mesh.visible = true
	_material.albedo_color = base_color
	_update_label()


func get_health() -> float:
	return _health.current_health


func is_dead() -> bool:
	return _health.is_dead


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_material.albedo_color = base_color
	if _respawn_timer > 0.0:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			reset_dummy()


func _die() -> void:
	_collision.set_deferred("disabled", true)
	_mesh.visible = false
	_respawn_timer = respawn_delay


func _update_label() -> void:
	if _health.is_dead:
		_label.text = "ÉLIMINÉ"
	else:
		_label.text = "%d / %d" % [ceili(_health.current_health), ceili(_health.max_health)]
