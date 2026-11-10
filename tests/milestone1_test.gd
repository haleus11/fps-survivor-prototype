extends Node
## Test automatisé du jalon 1 (déplacements, saut, collisions, caméra, pause).
## Lancement : godot --headless --path <dossier_du_projet> res://tests/milestone1_test.tscn
## Code de sortie : 0 si tout passe, 1 sinon.

const GAME_SCENE: PackedScene = preload("res://game/game.tscn")
const TEST_START := Vector3(0.0, 0.05, 10.0)
const ALL_ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint"]

var _player: FPSController
var _head: Node3D
var _passes: int = 0
var _failures: int = 0


func _ready() -> void:
	var game: Node = GAME_SCENE.instantiate()
	# Les ennemis du générateur de test perturberaient ces mesures.
	game.get_node("DebugSpawner").set("enabled", false)
	# Pas de vagues automatiques : ce test pilote lui-même les ennemis.
	game.get_node("WaveManager").set("auto_start", false)
	# Ce nœud de test tourne toujours ; la partie doit rester soumise à la pause.
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	_player = game.get_node("Player") as FPSController
	_head = _player.get_node("Head") as Node3D
	await _run_all()
	_release_all()
	print("")
	print("JALON 1 : %d test(s) réussi(s), %d échec(s)" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _run_all() -> void:
	await _test_ground_and_walk()
	await _test_directions()
	await _test_sprint_and_stop()
	await _test_jump()
	await _test_no_double_jump()
	await _test_wall_collision()
	await _test_obstacle_not_climbable()
	_test_mouse_look()
	await _test_pause()
	await _test_kill_plane()


func _test_ground_and_walk() -> void:
	_teleport(TEST_START)
	await _wait_physics(20)
	_check(_player.is_on_floor(), "Le joueur repose sur le sol")
	var start_z: float = _player.global_position.z
	Input.action_press("move_forward")
	await _wait_physics(45)
	_check_near(_player.get_horizontal_speed(), _player.config.walk_speed, 0.05, "Vitesse de marche")
	_check(_player.global_position.z < start_z - 2.0, "Z fait avancer vers l'avant de la caméra")
	_check(not _player.is_sprinting, "Pas de sprint sans Shift")
	Input.action_release("move_forward")
	await _wait_physics(20)


func _test_directions() -> void:
	var cases := {"move_right": Vector3.RIGHT, "move_left": Vector3.LEFT, "move_back": Vector3.BACK}
	for action in cases.keys():
		var expected: Vector3 = cases[action]
		_teleport(TEST_START)
		await _wait_physics(5)
		Input.action_press(action)
		await _wait_physics(10)
		var horizontal: Vector3 = Vector3(_player.velocity.x, 0.0, _player.velocity.z).normalized()
		_check(horizontal.dot(expected) > 0.99, "Direction correcte pour %s" % action)
		Input.action_release(action)
		await _wait_physics(15)


func _test_sprint_and_stop() -> void:
	_teleport(TEST_START)
	await _wait_physics(5)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait_physics(45)
	_check_near(_player.get_horizontal_speed(), _player.config.sprint_speed, 0.05, "Vitesse de sprint")
	_check(_player.is_sprinting, "État sprint actif")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _wait_physics(15)
	_check_near(_player.get_horizontal_speed(), 0.0, 0.01, "Arrêt en moins de 0,25 s")


func _test_jump() -> void:
	_teleport(TEST_START)
	await _wait_physics(10)
	var result: Dictionary = await _measure_jump(-1)
	var expected: float = _expected_jump_height()
	_check_near(result["height"], expected, expected * 0.1, "Hauteur de saut")
	_check(result["landed"], "Retour au sol après le saut")


func _test_no_double_jump() -> void:
	_teleport(TEST_START)
	await _wait_physics(10)
	var result: Dictionary = await _measure_jump(15)
	_check(result["height"] < _expected_jump_height() * 1.1, "Pas de double saut")
	await _wait_physics(20)
	_check(_player.is_on_floor(), "Pas de saut parasite à l'atterrissage")


func _test_wall_collision() -> void:
	_teleport(Vector3(20.0, 0.05, -44.0))
	await _wait_physics(5)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait_physics(90)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var z: float = _player.global_position.z
	_check(z > -50.0 + 0.35 and z < -49.0, "Collision avec le mur d'enceinte (z = %.2f)" % z)
	await _wait_physics(15)


func _test_obstacle_not_climbable() -> void:
	# Pilier en (10, -10), 2 × 3 × 2 m : on fonce dessus en sautant plusieurs fois.
	_teleport(Vector3(10.0, 0.05, -5.0))
	await _wait_physics(5)
	Input.action_press("move_forward")
	for _attempt in 4:
		Input.action_press("jump")
		await _wait_physics(1)
		Input.action_release("jump")
		await _wait_physics(40)
	Input.action_release("move_forward")
	await _wait_physics(30)
	var final_position: Vector3 = _player.global_position
	var blocked: bool = final_position.y < 0.5 and final_position.z > -9.0 + 0.35
	_check(blocked, "Obstacle non escaladable (y = %.2f, z = %.2f)" % [final_position.y, final_position.z])


func _test_mouse_look() -> void:
	_teleport(TEST_START)
	var config: PlayerMovementConfig = _player.config
	var up_sign: float = -1.0 if config.invert_y else 1.0
	_player.apply_look(Vector2(0.0, -100000.0))
	_check_near(rad_to_deg(_head.rotation.x), config.max_pitch_degrees * up_sign, 0.01, "Limite verticale (haut)")
	_player.apply_look(Vector2(0.0, 200000.0))
	_check_near(rad_to_deg(_head.rotation.x), -config.max_pitch_degrees * up_sign, 0.01, "Limite verticale (bas)")
	var yaw_before: float = _player.rotation.y
	_player.apply_look(Vector2(100.0, 0.0))
	var expected_yaw: float = yaw_before - deg_to_rad(100.0 * config.mouse_sensitivity)
	_check_near(_player.rotation.y, expected_yaw, 0.0001, "Rotation horizontale proportionnelle à la sensibilité")
	_check(is_zero_approx(_player.rotation.x) and is_zero_approx(_player.rotation.z), "Le corps ne bascule jamais")
	_teleport(TEST_START)


func _test_pause() -> void:
	_teleport(TEST_START)
	await _wait_physics(5)
	_send_action("pause")
	await _wait_process(3)
	_check(get_tree().paused, "Échap met le jeu en pause")
	var frozen: Vector3 = _player.global_position
	Input.action_press("move_forward")
	await _wait_physics(20)
	_check(_player.global_position.is_equal_approx(frozen), "Joueur figé pendant la pause")
	Input.action_release("move_forward")
	_send_action("pause")
	await _wait_process(3)
	_check(not get_tree().paused, "Échap reprend la partie")
	await _wait_physics(10)


func _test_kill_plane() -> void:
	_player.global_position = Vector3(0.0, -25.0, 0.0)
	await _wait_physics(2)
	_check(_player.global_position.y > -1.0, "Retour au point d'apparition sous le kill plane")


func _measure_jump(second_press_frame: int) -> Dictionary:
	var ground_y: float = _player.global_position.y
	var peak: float = ground_y
	var landed: bool = false
	Input.action_press("jump")
	await _wait_physics(1)
	Input.action_release("jump")
	for frame in 120:
		if frame == second_press_frame:
			Input.action_press("jump")
		elif frame == second_press_frame + 1:
			Input.action_release("jump")
		await _wait_physics(1)
		peak = maxf(peak, _player.global_position.y)
		if frame > 5 and _player.is_on_floor():
			landed = true
			break
	return {"height": peak - ground_y, "landed": landed}


func _expected_jump_height() -> float:
	var config: PlayerMovementConfig = _player.config
	return config.jump_velocity * config.jump_velocity / (2.0 * config.gravity)


func _teleport(target_position: Vector3) -> void:
	_player.global_position = target_position
	_player.rotation = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	_head.rotation = Vector3.ZERO


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


func _release_all() -> void:
	for action in ALL_ACTIONS:
		Input.action_release(action)


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
