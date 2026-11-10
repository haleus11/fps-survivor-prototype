extends Node
## Test automatisé du jalon 3 : ennemis, poursuite, contact, invulnérabilité, récompenses,
## pool, soin, séparation, charge de 150 ennemis, contournement d'obstacle et défaite.
## Lancement : godot --headless --path <dossier_du_projet> res://tests/milestone3_test.tscn

const GAME_SCENE: PackedScene = preload("res://game/game.tscn")
const PLAYER_START := Vector3(0.0, 0.05, 0.0)
const ENEMY_Y: float = 0.05

var _game: Node
var _player: FPSController
var _head: Node3D
var _inventory: WeaponInventory
var _stats: PlayerStats
var _health: PlayerHealth
var _progress: PlayerProgress
var _manager: EnemyManager
var _spawner: DebugSpawner
var _pistol: Weapon
## Ressource partagée avec le générateur : modifiée temporairement par certains tests.
var _enemy_data: EnemyData
var _hits: Array[Dictionary] = []
var _passes: int = 0
var _failures: int = 0


func _ready() -> void:
	_enemy_data = load("res://data/enemies/standard_enemy.tres") as EnemyData
	_game = GAME_SCENE.instantiate()
	_game.process_mode = Node.PROCESS_MODE_PAUSABLE
	_game.get_node("DebugSpawner").set("enabled", false)
	add_child(_game)
	_player = _game.get_node("Player") as FPSController
	_head = _player.get_node("Head") as Node3D
	_inventory = _player.get_node("WeaponInventory") as WeaponInventory
	_stats = _player.get_node("PlayerStats") as PlayerStats
	_health = _player.get_node("PlayerHealth") as PlayerHealth
	_progress = _player.get_node("PlayerProgress") as PlayerProgress
	_manager = _game.get_node("Enemies") as EnemyManager
	_spawner = _game.get_node("DebugSpawner") as DebugSpawner
	_inventory.require_mouse_capture = false
	DamageManager.hit_landed.connect(_on_hit_landed)
	await _wait_physics(2)
	_pistol = _inventory.get_active_weapon()
	await _run_all()
	Input.action_release("fire")
	print("")
	print("JALON 3 : %d test(s) réussi(s), %d échec(s)" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _run_all() -> void:
	await _test_initial_state()
	await _test_chase_and_contact()
	await _test_global_invulnerability()
	await _test_kill_rewards_and_pool()
	await _test_heal_drop()
	await _test_separation()
	await _test_stress()
	await _test_obstacle_detour()
	await _test_game_over()


func _test_initial_state() -> void:
	_check(is_equal_approx(_health.current_health, 100.0) and is_equal_approx(_health.max_health, 100.0), "Le joueur commence à 100 / 100 PV")
	_check(_progress.xp == 0 and _progress.credits == 0, "XP et crédits à zéro au départ")
	_check(_manager.get_active_count() == 0 and Diagnostics.active_enemies == 0, "Aucun ennemi actif au départ")
	_check(_manager.get_pool_size() >= 120, "Pool préchargé (obtenu %d instances)" % _manager.get_pool_size())
	await _wait_process(2)
	var health_label: Label = _game.get_node("HUD").get_node("%HealthLabel")
	_check(health_label.text == "PV  100 / 100", "HUD : PV affichés (obtenu « %s »)" % health_label.text)


func _test_chase_and_contact() -> void:
	await _reset_scene_state()
	var enemy: Enemy = _manager.spawn_enemy(_enemy_data, Vector3(12.0, ENEMY_Y, 0.0))
	_check(enemy != null and enemy.is_active, "Un ennemi apparaît depuis le pool")
	_check(Diagnostics.active_enemies == 1 and Diagnostics.total_spawns >= 1, "Compteurs de diagnostic mis à jour")
	var start_distance: float = _horizontal_distance(enemy)
	await _wait_physics(30)
	var speed: float = Vector2(enemy.velocity.x, enemy.velocity.z).length()
	_check_near(speed, _enemy_data.move_speed, 0.3, "L'ennemi poursuit à sa vitesse configurée")
	_check(_horizontal_distance(enemy) < start_distance - 1.5, "L'ennemi se rapproche du joueur")
	var first_hit_frame: int = -1
	var second_hit_frame: int = -1
	for frame in 360:
		await _wait_physics(1)
		if first_hit_frame == -1 and _health.current_health < 100.0:
			first_hit_frame = frame
		if second_hit_frame == -1 and _health.current_health < 90.0:
			second_hit_frame = frame
			break
	_check(first_hit_frame != -1, "Le contact inflige des dégâts")
	_check(_horizontal_distance(enemy) > 0.8, "L'ennemi ne traverse pas le joueur (%.2f m)" % _horizontal_distance(enemy))
	_check(second_hit_frame != -1 and is_equal_approx(_health.current_health, 80.0), "Deux contacts = 2 × 10 PV (PV : %.0f)" % _health.current_health)
	var interval_frames: int = second_hit_frame - first_hit_frame
	_check(interval_frames >= 44 and interval_frames <= 47, "Intervalle de contact ≈ 0,75 s (obtenu %d frames à 60 Hz)" % interval_frames)


func _test_global_invulnerability() -> void:
	await _reset_scene_state()
	_check(_health.take_damage(5.0), "Dégâts appliqués hors invulnérabilité")
	_check(not _health.take_damage(5.0), "Invulnérabilité immédiatement après un coup")
	await _wait_physics(13)
	_check(_health.take_damage(5.0), "Invulnérabilité terminée après 0,2 s")
	await _reset_scene_state()
	_manager.spawn_enemy(_enemy_data, Vector3(1.0, ENEMY_Y, 0.0))
	_manager.spawn_enemy(_enemy_data, Vector3(-1.0, ENEMY_Y, 0.0))
	await _wait_physics(3)
	_check_near(_health.current_health, 90.0, 0.001, "Deux ennemis au contact simultané : un seul coup appliqué")


func _test_kill_rewards_and_pool() -> void:
	await _reset_scene_state()
	_enemy_data.heal_drop_chance = 0.0
	var pool_before: int = _manager.get_pool_size()
	var kills_before: int = Diagnostics.total_kills
	var enemy: Enemy = _manager.spawn_enemy(_enemy_data, Vector3(0.0, ENEMY_Y, -5.0))
	var killed: bool = await _shoot_until_dead(enemy)
	_check(killed, "Ennemi éliminé au pistolet (40 PV = 2 tirs de 25)")
	_check(_progress.xp == 5 and _progress.credits == 4, "Récompense directe : +5 XP, +4 crédits (obtenu %d XP, %d crédits)" % [_progress.xp, _progress.credits])
	_check(Diagnostics.total_kills == kills_before + 1 and Diagnostics.active_enemies == 0, "Compteurs : kill compté, plus d'ennemi actif")
	_check(not enemy.is_active and not enemy.visible and enemy.collision_layer == 0, "L'ennemi éliminé retourne au pool (inactif, invisible, sans collision)")
	await _wait_process(2)
	var xp_label: Label = _game.get_node("HUD").get_node("%XpLabel")
	var credits_label: Label = _game.get_node("HUD").get_node("%CreditsLabel")
	_check(xp_label.text == "XP : 5" and credits_label.text == "Crédits : 4", "HUD : XP et crédits affichés")
	var reused: Enemy = _manager.spawn_enemy(_enemy_data, Vector3(0.0, ENEMY_Y, -8.0))
	_check(reused == enemy, "Le pool réutilise l'instance libérée")
	_check(_manager.get_pool_size() == pool_before, "Aucune nouvelle instance créée")
	_check_near(reused.get_health(), _enemy_data.max_health, 0.001, "L'ennemi réutilisé repart avec tous ses PV")
	_manager.clear_enemies()


func _test_heal_drop() -> void:
	await _reset_scene_state()
	_enemy_data.heal_drop_chance = 1.0
	var enemy: Enemy = _manager.spawn_enemy(_enemy_data, Vector3(0.0, ENEMY_Y, -5.0))
	await _shoot_until_dead(enemy)
	_enemy_data.heal_drop_chance = 0.03
	_check(_manager.get_pickup_count() == 1, "Soin lâché à la mort (chance forcée à 100 %)")
	var pickup: Node3D = _first_pickup()
	if pickup == null:
		return
	await _wait_physics(13)
	_health.take_damage(30.0)
	_check_near(_health.current_health, 70.0, 0.001, "PV à 70 avant ramassage")
	_player.global_position = Vector3(pickup.global_position.x, PLAYER_START.y, pickup.global_position.z)
	await _wait_physics(3)
	_check_near(_health.current_health, 85.0, 0.001, "Ramassage : +15 PV")
	_check(_manager.get_pickup_count() == 0, "Le soin disparaît une fois ramassé")
	_health.reset()
	_manager.spawn_heal_pickup(Vector3(4.0, 0.0, 4.0))
	_player.global_position = Vector3(4.0, PLAYER_START.y, 4.0)
	await _wait_physics(3)
	_check(_manager.get_pickup_count() == 1, "PV pleins : le soin reste au sol")
	_manager.clear_pickups()


func _test_separation() -> void:
	await _reset_scene_state()
	_manager.set_separation_enabled(true)
	_spawn_cluster(Vector3(-12.0, ENEMY_Y, 0.0), 30)
	await _wait_physics(60)
	var spaced: float = _average_nearest_distance()
	_manager.clear_enemies()
	_send_action("toggle_separation")
	_check(not _manager.separation_enabled and not Diagnostics.separation_enabled, "F6 désactive la séparation")
	_spawn_cluster(Vector3(-12.0, ENEMY_Y, 0.0), 30)
	await _wait_physics(60)
	var packed: float = _average_nearest_distance()
	_manager.clear_enemies()
	_send_action("toggle_separation")
	_check(_manager.separation_enabled, "F6 réactive la séparation")
	_check(spaced > 0.6 and spaced > packed * 2.0, "La séparation écarte les ennemis (%.2f m avec, %.2f m sans)" % [spaced, packed])


func _test_stress() -> void:
	await _reset_scene_state()
	_spawner.spawn_burst(150)
	await _wait_physics(2)
	_check(_manager.get_active_count() == 150, "Salve de 150 ennemis (obtenu %d)" % _manager.get_active_count())
	_check(Diagnostics.active_enemies == _manager.get_active_count(), "Diagnostic : ennemis actifs cohérents")
	var too_close: int = 0
	for enemy in _manager.get_active_enemies():
		if _horizontal_distance(enemy) < _spawner.min_distance - 0.5:
			too_close += 1
	_check(too_close == 0, "Apparition à distance du joueur")
	var physics_total: float = 0.0
	for _frame in 90:
		await _wait_physics(1)
		physics_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	print("[INFO]   Temps physique moyen avec 150 ennemis : %.2f ms" % (physics_total / 90.0 * 1000.0))
	var escaped: int = 0
	for enemy in _manager.get_active_enemies():
		var at: Vector3 = enemy.global_position
		if at.y < -1.0 or absf(at.x) > 30.0 or absf(at.z) > 30.0:
			escaped += 1
	_check(escaped == 0, "Aucun ennemi hors de l'arène ou sous le sol")
	_manager.clear_enemies()
	_check(_manager.get_active_count() == 0 and Diagnostics.active_enemies == 0, "Nettoyage : 0 ennemi actif")


func _test_obstacle_detour() -> void:
	await _reset_scene_state()
	_player.global_position = Vector3(0.0, PLAYER_START.y, 22.0)
	var enemy: Enemy = _manager.spawn_enemy(_enemy_data, Vector3(0.0, ENEMY_Y, 11.0))
	var reached: bool = false
	for _frame in 480:
		await _wait_physics(1)
		_health.reset()
		if _horizontal_distance(enemy) < 2.5:
			reached = true
			break
	_check(reached, "L'ennemi contourne la barrière pour atteindre le joueur")


func _test_game_over() -> void:
	await _reset_scene_state()
	_health.take_damage(95.0)
	await _wait_physics(13)
	_manager.spawn_enemy(_enemy_data, Vector3(1.0, ENEMY_Y, 0.0))
	await _wait_physics(3)
	var game_over_root: Control = _game.get_node("GameOver/Root")
	_check(_health.is_dead and _health.current_health <= 0.0, "Le joueur meurt à 0 PV")
	_check(game_over_root.visible and get_tree().paused, "Écran de défaite affiché, partie figée")
	_send_action("pause")
	await _wait_process(1)
	var pause_root: Control = _game.get_node("PauseMenu/Root")
	_check(get_tree().paused and not pause_root.visible, "Échap ne relance pas la partie après la défaite")
	get_tree().paused = false


func _reset_scene_state() -> void:
	_manager.clear_enemies()
	_manager.clear_pickups()
	_player.global_position = PLAYER_START
	_player.rotation = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	_head.rotation = Vector3.ZERO
	await _wait_physics(15)
	_health.reset()
	_hits.clear()


## Tir au pistolet légèrement vers le bas, droit devant (axe -Z), jusqu'à la mort de l'ennemi.
func _shoot_until_dead(enemy: Enemy) -> bool:
	_stats.crit_chance_bonus = -1.0
	_head.rotation.x = deg_to_rad(-8.0)
	_pistol.cancel_reload()
	_pistol.current_ammo = _pistol.get_magazine_size()
	for _shot in 4:
		Input.action_press("fire")
		await _wait_physics(1)
		Input.action_release("fire")
		await _wait_physics(14)
		if not enemy.is_active:
			break
	_stats.crit_chance_bonus = 0.0
	_head.rotation.x = 0.0
	for hit in _hits:
		if hit["target"] == enemy and hit["killed"]:
			return true
	return false


func _spawn_cluster(center: Vector3, count: int) -> void:
	for index in count:
		var offset := Vector3(float(index % 6) * 0.08, 0.0, floorf(index / 6.0) * 0.08)
		_manager.spawn_enemy(_enemy_data, center + offset)


func _average_nearest_distance() -> float:
	var enemies: Array[Enemy] = _manager.get_active_enemies()
	if enemies.size() < 2:
		return 0.0
	var total: float = 0.0
	for enemy in enemies:
		var best: float = INF
		for other in enemies:
			if other == enemy:
				continue
			var offset: Vector3 = other.global_position - enemy.global_position
			best = minf(best, Vector2(offset.x, offset.z).length())
		total += best
	return total / float(enemies.size())


func _first_pickup() -> Node3D:
	for child in _manager.get_node("Pickups").get_children():
		if not child.is_queued_for_deletion():
			return child as Node3D
	return null


func _horizontal_distance(enemy: Enemy) -> float:
	var offset: Vector3 = enemy.global_position - _player.global_position
	return Vector2(offset.x, offset.z).length()


func _on_hit_landed(target: Node, info: DamageInfo, killed: bool) -> void:
	_hits.append({"target": target, "info": info, "killed": killed})


func _send_action(action_name: String) -> void:
	var press := InputEventAction.new()
	press.action = action_name
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action_name
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func _wait_physics(frames: int) -> void:
	for _frame in frames:
		await get_tree().physics_frame


func _wait_process(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("[OK]     " + label)
	else:
		_failures += 1
		push_error("[ÉCHEC] " + label)
		print("[ÉCHEC]  " + label)


func _check_near(value: float, expected: float, tolerance: float, label: String) -> void:
	var detail: String = " (obtenu %.3f, attendu %.3f ± %.3f)" % [value, expected, tolerance]
	_check(absf(value - expected) <= tolerance, label + detail)
