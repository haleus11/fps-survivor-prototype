extends Node
## Compteurs globaux affichés par l'overlay de diagnostic (F3).
## Les systèmes des jalons suivants (spawn, projectiles, effets) les mettront à jour.

var active_enemies: int = 0
var active_projectiles: int = 0
var active_effects: int = 0
var total_spawns: int = 0
var total_kills: int = 0
var separation_enabled: bool = true


func reset() -> void:
	active_enemies = 0
	active_projectiles = 0
	active_effects = 0
	total_spawns = 0
	total_kills = 0
