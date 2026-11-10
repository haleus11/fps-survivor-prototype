class_name PlayerMovementConfig
extends Resource
## Paramètres de déplacement et de caméra du joueur, modifiables sans toucher au code.

@export_group("Déplacement")
## Vitesse de marche (m/s).
@export var walk_speed: float = 6.0
## Vitesse de sprint (m/s).
@export var sprint_speed: float = 9.0
## Accélération au sol (m/s²). 80 → vitesse de marche atteinte en ~0,08 s.
@export var ground_acceleration: float = 80.0
## Décélération au sol sans entrée (m/s²).
@export var ground_deceleration: float = 70.0
## Accélération en l'air avec entrée (m/s²).
@export var air_acceleration: float = 30.0
## Freinage en l'air sans entrée (m/s²). Faible pour conserver l'élan du saut.
@export var air_deceleration: float = 4.0

@export_group("Saut")
## Vitesse verticale initiale du saut (m/s). Hauteur ≈ v² / (2 × gravité).
@export var jump_velocity: float = 7.0
## Gravité appliquée au joueur (m/s²).
@export var gravity: float = 22.0
@export var max_fall_speed: float = 40.0
## Tolérance après avoir quitté le sol pendant laquelle le saut reste possible (s).
@export var coyote_time: float = 0.1
## Un appui sur Espace juste avant l'atterrissage est mémorisé pendant cette durée (s).
@export var jump_buffer_time: float = 0.1

@export_group("Caméra")
## Sensibilité souris en degrés par pixel.
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity: float = 0.1
@export var invert_y: bool = false
## Limite verticale de la caméra (degrés, vers le haut et vers le bas).
@export_range(10.0, 89.0, 0.5) var max_pitch_degrees: float = 85.0
@export_range(60.0, 120.0, 1.0) var field_of_view: float = 90.0

@export_group("Sécurité")
## Sous cette altitude, le joueur est replacé à son point d'apparition.
@export var kill_plane_y: float = -20.0
