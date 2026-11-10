class_name DebugSpawner
extends Node
## Générateur de test du jalon 3 : maintient une population d'ennemis autour du joueur.
## F4 ajoute une salve d'ennemis. Il sera remplacé par le gestionnaire de vagues au jalon 4.

@export var enabled: bool = true
@export var enemy_manager: EnemyManager
@export var player: FPSController
@export var enemy_data: EnemyData
@export var target_count: int = 20
@export var spawn_interval: float = 0.35
@export var burst_count: int = 25
@export var start_delay: float = 2.0
@export var min_distance: float = 14.0
@export var max_distance: float = 24.0
@export var arena_half_extent: float = 47.0
## Hauteur de sol maximale acceptée : évite d'apparaître sur le dessus d'un pilier ou d'un bloc.
@export var max_ground_height: float = 2.6
@export var max_attempts: int = 10

var _timer: float = 0.0
var _pending_burst: int = 0
var _rng := RandomNumberGenerator.new()
var _query := PhysicsShapeQueryParameters3D.new()
var _ground_ray := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_rng.randomize()
	_timer = start_delay
	var probe := SphereShape3D.new()
	probe.radius = 0.7
	_query.shape = probe
	_ground_ray.collision_mask = 1
	# Monde + joueur : on n'apparaît ni dans un obstacle ni sur le joueur.
	_query.collision_mask = 1 | 2


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spawn_burst"):
		spawn_burst(burst_count)
		get_viewport().set_input_as_handled()


## La salve est traitée au prochain pas physique (requêtes d'espace physique).
func spawn_burst(count: int) -> void:
	_pending_burst += count


func _physics_process(delta: float) -> void:
	if enemy_manager == null or player == null:
		return
	while _pending_burst > 0:
		_pending_burst -= 1
		spawn_one()
	if not enabled:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = spawn_interval
	if enemy_manager.get_active_count() < target_count:
		spawn_one()


func spawn_one() -> Enemy:
	var point: Vector3 = find_spawn_point()
	if not point.is_finite():
		return null
	return enemy_manager.spawn_enemy(enemy_data, point)


## Point libre sur un anneau autour du joueur, dans l'arène. Vector3.INF si aucun point trouvé.
func find_spawn_point() -> Vector3:
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	for _attempt in max_attempts:
		var angle: float = _rng.randf() * TAU
		var distance: float = _rng.randf_range(min_distance, max_distance)
		var candidate: Vector3 = player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		if absf(candidate.x) > arena_half_extent or absf(candidate.z) > arena_half_extent:
			continue
		# Le sol n'est plus plat : on cherche sa hauteur sous le point candidat.
		# Hauteurs absolues : le candidat hérite de la hauteur du joueur, qui peut être sur une butte.
		_ground_ray.from = Vector3(candidate.x, 10.0, candidate.z)
		_ground_ray.to = Vector3(candidate.x, -2.0, candidate.z)
		var ground: Dictionary = space.intersect_ray(_ground_ray)
		if ground.is_empty():
			continue
		var ground_position: Vector3 = ground["position"]
		if ground_position.y > max_ground_height:
			continue
		candidate.y = ground_position.y + 0.05
		_query.transform = Transform3D(Basis.IDENTITY, candidate + Vector3(0.0, 1.2, 0.0))
		if space.intersect_shape(_query, 1).is_empty():
			return candidate
	return Vector3.INF
