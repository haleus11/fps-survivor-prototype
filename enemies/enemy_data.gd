class_name EnemyData
extends Resource
## Paramètres d'un type d'ennemi, réglables sans toucher au code.

@export var id: StringName = &"standard"
@export var display_name: String = "Rôdeur"

@export_group("Combat")
@export var max_health: float = 40.0
@export var contact_damage: float = 10.0
## Délai minimal entre deux attaques de contact d'un même ennemi (s).
@export var contact_interval: float = 0.75
## Portée de contact ajoutée au contact des capsules (m).
@export var contact_reach: float = 0.3

@export_group("Déplacement")
@export var move_speed: float = 4.5
@export var acceleration: float = 30.0
@export var turn_speed: float = 10.0
@export var gravity: float = 22.0

@export_group("Récompenses")
@export var xp_reward: int = 5
@export var credit_reward: int = 4
@export_range(0.0, 1.0) var heal_drop_chance: float = 0.03

@export_group("Visuel")
@export var body_color: Color = Color(0.85, 0.25, 0.2)
@export var hit_flash_color: Color = Color(1.0, 1.0, 1.0)
@export var critical_flash_color: Color = Color(1.0, 0.62, 0.1)
@export var hit_flash_duration: float = 0.08
