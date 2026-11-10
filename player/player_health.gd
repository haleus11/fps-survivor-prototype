class_name PlayerHealth
extends Node
## PV du joueur avec invulnérabilité globale courte après chaque coup reçu.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal died

@export var max_health: float = 100.0
## Durée pendant laquelle aucun autre dégât n'est appliqué après un coup (s).
@export var invulnerability_time: float = 0.2

var current_health: float = 0.0
var is_dead: bool = false

var _invulnerability_timer: float = 0.0


func _ready() -> void:
	reset()


func reset() -> void:
	current_health = max_health
	is_dead = false
	_invulnerability_timer = 0.0
	health_changed.emit(current_health, max_health)


func is_invulnerable() -> bool:
	return _invulnerability_timer > 0.0


func _physics_process(delta: float) -> void:
	if _invulnerability_timer > 0.0:
		_invulnerability_timer = maxf(_invulnerability_timer - delta, 0.0)


## Retourne true si les dégâts ont été appliqués.
func take_damage(amount: float, source: Node = null) -> bool:
	if is_dead or amount <= 0.0 or _invulnerability_timer > 0.0:
		return false
	current_health = maxf(current_health - amount, 0.0)
	_invulnerability_timer = invulnerability_time
	damaged.emit(amount, source)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		is_dead = true
		died.emit()
	return true


## Retourne les PV réellement rendus.
func heal(amount: float) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	var restored: float = minf(amount, max_health - current_health)
	if restored <= 0.0:
		return 0.0
	current_health += restored
	healed.emit(restored)
	health_changed.emit(current_health, max_health)
	return restored
