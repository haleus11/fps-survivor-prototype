class_name WaveConfig
extends Resource
## Paramètres de la partie en vagues, réglables sans toucher au code.
## Intensité = cadence d'apparition (ennemis par seconde), qui monte pendant la vague et d'une vague à l'autre.

@export_group("Partie")
@export var wave_count: int = 10
## Durée du chronomètre de chaque vague (s).
@export var wave_duration: float = 90.0
## Compte à rebours avant la première vague (s).
@export var first_wave_delay: float = 3.0

@export_group("Intensité pendant une vague")
## Ennemis par seconde au début de la vague 1.
@export var spawn_rate_start: float = 0.6
## Ennemis par seconde à la fin de la vague 1.
@export var spawn_rate_end: float = 1.2
## Hausse de la cadence par vague : × (1 + valeur × (vague - 1)).
@export var spawn_rate_growth_per_wave: float = 0.22

@export_group("Population")
@export var max_alive_base: int = 35
@export var max_alive_per_wave: int = 12
@export var max_alive_cap: int = 180

@export_group("Renforcement des ennemis par vague")
## Chaque valeur s'ajoute par vague : × (1 + valeur × (vague - 1)).
@export var health_growth_per_wave: float = 0.12
@export var damage_growth_per_wave: float = 0.06
@export var speed_growth_per_wave: float = 0.015

@export_group("Récompenses de fin de vague")
@export var clear_bonus_base: int = 20
@export var clear_bonus_per_wave: int = 10


## progress : 0 au lancement de la vague, 1 quand le chronomètre atteint 00:00.
func get_spawn_rate(wave: int, progress: float) -> float:
	var rate: float = lerpf(spawn_rate_start, spawn_rate_end, clampf(progress, 0.0, 1.0))
	return rate * _growth(spawn_rate_growth_per_wave, wave)


func get_max_alive(wave: int) -> int:
	return mini(max_alive_base + max_alive_per_wave * (wave - 1), max_alive_cap)


func get_health_multiplier(wave: int) -> float:
	return _growth(health_growth_per_wave, wave)


func get_damage_multiplier(wave: int) -> float:
	return _growth(damage_growth_per_wave, wave)


func get_speed_multiplier(wave: int) -> float:
	return _growth(speed_growth_per_wave, wave)


func get_clear_bonus(wave: int) -> int:
	return clear_bonus_base + clear_bonus_per_wave * wave


func _growth(per_wave: float, wave: int) -> float:
	return 1.0 + per_wave * float(maxi(wave - 1, 0))
