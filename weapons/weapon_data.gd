class_name WeaponData
extends Resource
## Données d'une arme. Une nouvelle arme = une nouvelle ressource (+ éventuellement une scène visuelle).

enum FireMode { SEMI_AUTO, AUTOMATIC }

@export_group("Identité")
@export var id: StringName = &""
@export var display_name: String = ""
@export var view_scene: PackedScene

@export_group("Tir")
## Logique de tir (hitscan, multi-projectiles, projectile physique…).
@export var fire_behavior: FireBehavior
@export var fire_mode: FireMode = FireMode.SEMI_AUTO
@export var damage: float = 10.0
## Cadence maximale en tirs par minute. L'intervalle entre tirs en découle : 60 / cadence.
@export var fire_rate_rpm: float = 300.0
@export var projectile_count: int = 1
@export var max_range: float = 100.0
@export var projectile_speed: float = 0.0
@export var explosion_radius: float = 0.0

@export_group("Chargeur")
@export var magazine_size: int = 12
@export var reload_time: float = 1.2

@export_group("Dispersion")
@export var spread_min_degrees: float = 0.5
@export var spread_max_degrees: float = 2.0
@export var spread_per_shot_degrees: float = 0.5
@export var spread_recovery_degrees_per_second: float = 6.0

@export_group("Recul")
## Recul de visée : décalage de la caméra par tir, puis retour progressif.
@export var recoil_pitch_degrees: float = 1.0
@export var recoil_yaw_degrees: float = 0.3
@export var recoil_recovery_speed: float = 10.0
## Recul visuel de l'arme à l'écran.
@export var view_kick_distance: float = 0.04
@export var view_kick_degrees: float = 5.0

@export_group("Audio")
@export var fire_sound: AudioStream
@export var reload_start_sound: AudioStream
@export var reload_end_sound: AudioStream
@export var empty_sound: AudioStream

@export_group("Économie")
@export var price: int = 0
@export var compatible_modules: Array[Resource] = []


func get_fire_interval() -> float:
	return 60.0 / maxf(fire_rate_rpm, 1.0)
