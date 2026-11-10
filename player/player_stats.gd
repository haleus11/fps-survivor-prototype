class_name PlayerStats
extends Node
## Statistiques globales du joueur, appliquées à toutes les armes.
## Les bonus sont additifs ; le Level-Up (jalon 5) les modifiera et appliquera les plafonds.

@export var data: PlayerStatsData

var damage_bonus: float = 0.0
var fire_rate_bonus: float = 0.0
var crit_chance_bonus: float = 0.0
var crit_multiplier_bonus: float = 0.0
var magazine_bonus: float = 0.0
var reload_speed_bonus: float = 0.0

var damage_multiplier: float:
	get:
		return 1.0 + damage_bonus
var fire_rate_multiplier: float:
	get:
		return 1.0 + fire_rate_bonus
var crit_chance: float:
	get:
		return clampf(data.base_crit_chance + crit_chance_bonus, 0.0, 1.0)
var crit_multiplier: float:
	get:
		return data.base_crit_multiplier + crit_multiplier_bonus
var magazine_multiplier: float:
	get:
		return 1.0 + magazine_bonus
var reload_speed_multiplier: float:
	get:
		return 1.0 + reload_speed_bonus


func _init() -> void:
	data = PlayerStatsData.new()
