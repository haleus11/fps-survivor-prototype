extends Node
## Test automatisé du jalon 4 : vagues chronométrées, intensité, arrêt des apparitions à 00:00,
## élimination des restants, prime de fin de vague, entracte, lancement manuel, victoire.
## Les vagues sont raccourcies (5 s, 2 vagues) pour que le test reste rapide ;
## les valeurs réelles (10 vagues de 90 s) sont vérifiées dans la configuration.
## Lancement : godot --headless --path <dossier_du_projet> res://tests/milestone4_test.tscn

const GAME_SCENE: PackedScene = preload("res://game/game.tscn")
const TEST_WAVE_DURATION: float = 5.0

var _game: Node
var _player: FPSController
var _health: PlayerHealth
var _progress: PlayerProgress
var _manager: EnemyManager
var _waves: WaveManager
var _hud: CanvasLayer
var _intermission: CanvasLayer
var _game_over: CanvasLayer
var _real_config: WaveConfig
var _test_config: WaveConfig
var _started_waves: Array[int] = []
var _timer_finished_waves: Array[int] = []
var _victory_count: int = 0
var _wave_start_frame: int = 0
var _wave_end_frame: int = 0
var _passes: int = 0
var _failures: int = 0


func _ready() -> void:
	_real_config = load("res://data/waves/default_waves.tres") as WaveConfig
	_test_config = _real_config.duplicate() as WaveConfig
	_test_config.wave_count = 2
	_test_config.wave_duration = TEST_WAVE_DURATION
	_test_config.first_wave_delay = 0.5
	_test_config.spawn_rate_start = 4.0
	_test_config.spawn_rate_end = 8.0
	_test_config.max_alive_base = 6
	_test_config.max_alive_per_wave = 2
	_game = GAME_SCENE.instantiate()
	_game.process_mode = Node.PROCESS_MODE_PAUSABLE
	_waves = _game.get_node("WaveManager") as WaveManager
	_waves.config = _test_config
	add_child(_game)
	_player = _game.get_node("Player") as FPSController
	_health = _player.get_node("PlayerHealth") as PlayerHealth
	_progress = _player.get_node("PlayerProgress") as PlayerProgress
	_manager = _game.get_node("Enemies") as EnemyManager
	_hud = _game.get_node("HUD") as CanvasLayer
	_intermission = _game.get_node("WaveIntermission") as CanvasLayer
	_game_over = _game.get_node("GameOver") as CanvasLayer
	(_player.get_node("WeaponInventory") as WeaponInventory).require_mouse_capture = false
	_waves.wave_started.connect(_on_wave_started)
	_waves.wave_timer_finished.connect(_on_wave_timer_finished)
	_waves.victory.connect(func(_summary: Dictionary) -> void: _victory_count += 1)
	await _run_all()
	get_tree().paused = false
	print("")
	print("JALON 4 : %d test(s) réussi(s), %d échec(s)" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _run_all() -> void:
	_test_real_config()
	await _test_countdown()
	await _test_wave_one()
	await _test_intermission_and_wave_two()
	await _test_victory()


func _test_real_config() -> void:
	_check(_real_config.wave_count == 10, "Configuration : 10 vagues")
	_check(is_equal_approx(_real_config.wave_duration, 90.0), "Configuration : vagues de 90 s")
	_check(_real_config.get_spawn_rate(1, 1.0) > _real_config.get_spawn_rate(1, 0.0), "L'intensité augmente pendant la vague (%.2f → %.2f ennemis/s)" % [_real_config.get_spawn_rate(1, 0.0), _real_config.get_spawn_rate(1, 1.0)])
	_check(_real_config.get_spawn_rate(10, 0.5) > _real_config.get_spawn_rate(1, 0.5), "L'intensité augmente d'une vague à l'autre (%.2f → %.2f ennemis/s)" % [_real_config.get_spawn_rate(1, 0.5), _real_config.get_spawn_rate(10, 0.5)])
	_check(_real_config.get_max_alive(10) > _real_config.get_max_alive(1), "Population maximale croissante (%d → %d)" % [_real_config.get_max_alive(1), _real_config.get_max_alive(10)])
	_check(_real_config.get_health_multiplier(10) > 1.0 and is_equal_approx(_real_config.get_health_multiplier(1), 1.0), "Ennemis renforcés au fil des vagues (PV × %.2f en vague 10)" % _real_config.get_health_multiplier(10))
	_check(WaveManager.format_time(90.0) == "01:30" and WaveManager.format_time(0.2) == "00:01" and WaveManager.format_time(0.0) == "00:00", "Format du chronomètre mm:ss")


func _test_countdown() -> void:
	_check(_waves.state == WaveManager.State.COUNTDOWN, "Compte à rebours avant la vague 1")
	_check(_manager.get_active_count() == 0, "Aucun ennemi pendant le compte à rebours")
	await _wait_process(2)
	_check(_label("%WaveStatusLabel").begins_with("Début dans"), "HUD : compte à rebours affiché (« %s »)" % _label("%WaveStatusLabel"))
	await _wait_physics(40)
	_check(_waves.state == WaveManager.State.RUNNING and _waves.current_wave == 1, "La vague 1 démarre seule après le compte à rebours")
	_check(_started_waves.size() == 1 and _started_waves[0] == 1, "Signal de début de vague émis")
	await _wait_process(2)
	_check(_label("%WaveLabel") == "Vague 1 / 2", "HUD : numéro de vague (« %s »)" % _label("%WaveLabel"))
	_check(_label("%TimerLabel") == "00:05", "HUD : chronomètre au départ (« %s »)" % _label("%TimerLabel"))


func _test_wave_one() -> void:
	var max_seen: int = 0
	var max_alive: int = _test_config.get_max_alive(1)
	var timer_text_mid: String = ""
	var frame: int = 0
	while _waves.state == WaveManager.State.RUNNING and frame < 600:
		await _wait_physics(1)
		frame += 1
		_health.reset()
		max_seen = maxi(max_seen, _manager.get_active_count())
		if frame % 20 == 0:
			_kill_one()
		if frame == 150:
			await _wait_process(1)
			timer_text_mid = _label("%TimerLabel")
	_check(_waves.wave_spawns > 0, "Apparitions continues pendant la vague (%d ennemis)" % _waves.wave_spawns)
	_check(max_seen <= max_alive, "Population plafonnée (%d au plus pour %d autorisés)" % [max_seen, max_alive])
	_check(timer_text_mid == "00:03" or timer_text_mid == "00:02", "HUD : le chronomètre décroît (« %s » à mi-vague)" % timer_text_mid)
	_check_near(float(_wave_end_frame - _wave_start_frame) / 60.0, TEST_WAVE_DURATION, 0.05, "Durée de la vague respectée (s)")
	_check(_waves.state == WaveManager.State.CLEARING, "À 00:00 : phase d'élimination des restants")
	_check(_timer_finished_waves.size() == 1 and _timer_finished_waves[0] == 1, "Signal de fin de chronomètre émis")
	var spawns_at_zero: int = _waves.wave_spawns
	var alive_at_zero: int = _manager.get_active_count()
	_check(alive_at_zero > 0, "Des ennemis restent à éliminer (%d)" % alive_at_zero)
	for _step in 60:
		await _wait_physics(1)
		_health.reset()
	_check(_waves.wave_spawns == spawns_at_zero and _manager.get_active_count() <= alive_at_zero, "Plus aucune apparition après 00:00")
	await _wait_process(2)
	_check(_label("%TimerLabel") == "00:00", "HUD : chronomètre à 00:00")
	_check(_label("%WaveStatusLabel") == "Éliminez les ennemis restants : %d" % _manager.get_active_count(), "HUD : ennemis restants (« %s »)" % _label("%WaveStatusLabel"))
	_check(_waves.state == WaveManager.State.CLEARING, "La vague ne se termine pas tant qu'il reste des ennemis")
	var credits_before: int = _progress.credits
	var kills: int = _manager.get_active_count()
	_kill_all()
	await _wait_physics(3)
	var expected_bonus: int = _test_config.get_clear_bonus(1)
	var kill_credits: int = kills * _waves.get_current_enemy_data().credit_reward
	_check(_waves.state == WaveManager.State.INTERMISSION, "Tous les ennemis éliminés : vague terminée")
	_check(_progress.credits == credits_before + kill_credits + expected_bonus, "Prime de fin de vague versée (+%d crédits)" % expected_bonus)


func _test_intermission_and_wave_two() -> void:
	await _wait_process(2)
	_check(_intermission.get("is_shown") == true, "Entracte affiché")
	_check(get_tree().paused, "La partie est figée pendant l'entracte")
	_check(_intermission.get_node("%TitleLabel").text == "VAGUE 1 / 2 TERMINÉE", "Entracte : titre (« %s »)" % _intermission.get_node("%TitleLabel").text)
	_check((_intermission.get_node("%SummaryLabel").text as String).contains("prime de vague : %d" % _test_config.get_clear_bonus(1)), "Entracte : bilan avec la prime")
	var button: Button = _intermission.get_node("%NextWaveButton")
	_check(button.text == "Lancer la vague 2", "Entracte : bouton de lancement (« %s »)" % button.text)
	await _wait_physics(60)
	_check(_waves.current_wave == 1 and _waves.state == WaveManager.State.INTERMISSION, "La vague suivante attend le joueur")
	_check(_manager.get_active_count() == 0, "Aucune apparition pendant l'entracte")
	button.pressed.emit()
	await _wait_physics(2)
	_check(not get_tree().paused and _intermission.get("is_shown") == false, "Lancement manuel : la partie reprend")
	_check(_waves.state == WaveManager.State.RUNNING and _waves.current_wave == 2, "La vague 2 démarre")
	var data: EnemyData = _waves.get_current_enemy_data()
	var base_health: float = (_waves.base_enemy_data as EnemyData).max_health
	_check_near(data.max_health, base_health * _test_config.get_health_multiplier(2), 0.01, "Ennemis de la vague 2 renforcés (PV)")
	_check(data.contact_damage > (_waves.base_enemy_data as EnemyData).contact_damage, "Ennemis de la vague 2 renforcés (dégâts)")
	var enemy: Enemy = null
	for _step in 60:
		await _wait_physics(1)
		_health.reset()
		if _manager.get_active_count() > 0:
			enemy = _manager.get_active_enemies()[0]
			break
	var enemy_health: float = enemy.get_node("HealthComponent").get("max_health") if enemy != null else 0.0
	_check_near(enemy_health, data.max_health, 0.01, "Un ennemi apparu en vague 2 a les PV renforcés")


func _test_victory() -> void:
	var frame: int = 0
	while _waves.state == WaveManager.State.RUNNING and frame < 600:
		await _wait_physics(1)
		frame += 1
		_health.reset()
	_check(_waves.state == WaveManager.State.CLEARING, "Dernière vague : chronomètre à 00:00")
	_check(_victory_count == 0 and _game_over.get("is_shown") == false, "Pas de victoire tant qu'il reste des ennemis")
	_kill_all()
	await _wait_physics(3)
	await _wait_process(2)
	_check(_waves.state == WaveManager.State.VICTORY and _victory_count == 1, "Victoire après la dernière vague")
	_check(_game_over.get("is_shown") == true and _game_over.get("is_victory") == true, "Écran de victoire affiché")
	_check(_game_over.get_node("%Title").text == "VICTOIRE", "Titre « VICTOIRE »")
	_check((_game_over.get_node("%SummaryLabel").text as String).contains("Vague atteinte : 2 / 2"), "Bilan : vague atteinte")
	_check(_intermission.get("is_shown") == false, "Pas d'entracte après la dernière vague")
	_check(get_tree().paused, "La partie est figée sur l'écran de victoire")


func _on_wave_started(wave: int) -> void:
	_started_waves.append(wave)
	_wave_start_frame = Engine.get_physics_frames()


func _on_wave_timer_finished(wave: int) -> void:
	_timer_finished_waves.append(wave)
	_wave_end_frame = Engine.get_physics_frames()


func _label(path: String) -> String:
	return (_hud.get_node(path) as Label).text


func _kill_one() -> void:
	var enemies: Array[Enemy] = _manager.get_active_enemies()
	if not enemies.is_empty():
		_kill(enemies[0])


func _kill_all() -> void:
	for enemy in _manager.get_active_enemies().duplicate():
		_kill(enemy)


func _kill(enemy: Enemy) -> void:
	var info := DamageInfo.new()
	info.amount = 100000.0
	info.source = _player
	info.position = enemy.global_position
	enemy.apply_damage(info)


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
