class_name HealthComponent
extends Node
## Points de vie réutilisables (mannequin, ennemis).

signal damaged(amount: float, current_health: float)
signal died

@export var max_health: float = 100.0

var current_health: float = 0.0
var is_dead: bool = false


func _ready() -> void:
	reset()


func reset() -> void:
	current_health = max_health
	is_dead = false


## Retourne true si ces dégâts provoquent la mort.
func apply_damage(amount: float) -> bool:
	if is_dead or amount <= 0.0:
		return false
	current_health = maxf(current_health - amount, 0.0)
	damaged.emit(amount, current_health)
	if current_health <= 0.0:
		is_dead = true
		died.emit()
		return true
	return false
