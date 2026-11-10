class_name EnemyManager
extends Node3D
## Pool d'ennemis, séparation locale par grille spatiale, récompenses de kill et butin de soin.

signal enemy_killed(enemy: Enemy, info: DamageInfo)

@export var enemy_scene: PackedScene
@export var heal_pickup_scene: PackedScene
@export var player: FPSController
@export var player_health: PlayerHealth
@export var player_progress: PlayerProgress
## Instances créées au chargement : aucun instancing pendant le combat tant que ce nombre suffit.
@export var initial_pool_size: int = 120
@export var max_enemies: int = 300

@export_group("Séparation")
@export var separation_enabled: bool = true
@export var separation_radius: float = 1.3
@export var separation_strength: float = 4.0
@export var cell_size: float = 2.0

@export_group("Butin")
@export var max_heal_pickups: int = 8

var _active: Array[Enemy] = []
var _free: Array[Enemy] = []
var _grid: Dictionary = {}
var _positions := PackedVector3Array()
var _pickup_root: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	cell_size = maxf(cell_size, separation_radius)
	_pickup_root = Node3D.new()
	_pickup_root.name = "Pickups"
	add_child(_pickup_root)
	for _index in initial_pool_size:
		_free.append(_create_enemy())
	Diagnostics.separation_enabled = separation_enabled
	_publish_counts()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_separation"):
		set_separation_enabled(not separation_enabled)
		get_viewport().set_input_as_handled()


func set_separation_enabled(enabled: bool) -> void:
	separation_enabled = enabled
	Diagnostics.separation_enabled = enabled
	if not enabled:
		for enemy in _active:
			enemy.separation = Vector3.ZERO


func spawn_enemy(enemy_data: EnemyData, at: Vector3) -> Enemy:
	if enemy_data == null or _active.size() >= max_enemies:
		return null
	var enemy: Enemy = _free.pop_back() if not _free.is_empty() else _create_enemy()
	enemy.activate(enemy_data, at, player, player_health)
	_active.append(enemy)
	Diagnostics.total_spawns += 1
	_publish_counts()
	return enemy


func get_active_count() -> int:
	return _active.size()


func get_active_enemies() -> Array[Enemy]:
	return _active


func get_pool_size() -> int:
	return _active.size() + _free.size()


func clear_enemies() -> void:
	for enemy in _active.duplicate():
		_release(enemy)


func spawn_heal_pickup(at: Vector3) -> HealPickup:
	if heal_pickup_scene == null or get_pickup_count() >= max_heal_pickups:
		return null
	var pickup := heal_pickup_scene.instantiate() as HealPickup
	pickup.player = player
	pickup.player_health = player_health
	_pickup_root.add_child(pickup)
	pickup.global_position = Vector3(at.x, 0.0, at.z)
	return pickup


func get_pickup_count() -> int:
	var count: int = 0
	for child in _pickup_root.get_children():
		if not child.is_queued_for_deletion():
			count += 1
	return count


func clear_pickups() -> void:
	for child in _pickup_root.get_children():
		child.queue_free()


func _physics_process(_delta: float) -> void:
	if separation_enabled and _active.size() > 1:
		_update_separation()


func _create_enemy() -> Enemy:
	var enemy := enemy_scene.instantiate() as Enemy
	add_child(enemy)
	enemy.deactivate()
	enemy.died.connect(_on_enemy_died)
	enemy.fell_out.connect(_release)
	return enemy


func _release(enemy: Enemy) -> void:
	var index: int = _active.find(enemy)
	if index == -1:
		return
	_active[index] = _active[_active.size() - 1]
	_active.pop_back()
	enemy.deactivate()
	_free.append(enemy)
	_publish_counts()


func _on_enemy_died(enemy: Enemy, info: DamageInfo) -> void:
	var death_position: Vector3 = enemy.global_position
	var enemy_data: EnemyData = enemy.data
	_release(enemy)
	Diagnostics.total_kills += 1
	if player_progress != null:
		player_progress.add_kill_rewards(enemy_data.xp_reward, enemy_data.credit_reward)
	if _rng.randf() < enemy_data.heal_drop_chance:
		spawn_heal_pickup(death_position)
	enemy_killed.emit(enemy, info)


## Grille spatiale reconstruite à chaque pas : chaque ennemi ne compare que les 9 cellules voisines.
func _update_separation() -> void:
	var count: int = _active.size()
	var inverse_cell: float = 1.0 / cell_size
	_grid.clear()
	_positions.resize(count)
	for index in count:
		var position_now: Vector3 = _active[index].global_position
		_positions[index] = position_now
		var key := Vector2i(floori(position_now.x * inverse_cell), floori(position_now.z * inverse_cell))
		if _grid.has(key):
			_grid[key].append(index)
		else:
			_grid[key] = [index]
	var radius_squared: float = separation_radius * separation_radius
	for index in count:
		var origin: Vector3 = _positions[index]
		var cell_x: int = floori(origin.x * inverse_cell)
		var cell_z: int = floori(origin.z * inverse_cell)
		var push := Vector3.ZERO
		for offset_x in range(-1, 2):
			for offset_z in range(-1, 2):
				var key := Vector2i(cell_x + offset_x, cell_z + offset_z)
				if not _grid.has(key):
					continue
				for other_index in _grid[key]:
					if other_index == index:
						continue
					var other: Vector3 = _positions[other_index]
					var away := Vector3(origin.x - other.x, 0.0, origin.z - other.z)
					var distance_squared: float = away.length_squared()
					if distance_squared >= radius_squared:
						continue
					if distance_squared < 0.0001:
						# Positions confondues : direction stable propre à la paire.
						away = Vector3.RIGHT.rotated(Vector3.UP, float((index * 7 + other_index * 13) % 360))
						distance_squared = 0.0001
					var distance: float = sqrt(distance_squared)
					push += away.normalized() * (1.0 - distance / separation_radius)
		_active[index].separation = push * separation_strength


func _publish_counts() -> void:
	Diagnostics.active_enemies = _active.size()
