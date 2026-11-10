extends Node
## Test automatisé du jalon 2 : pistolet, hitscan, chargeur, rechargement, critiques, recul, mannequin.
## Lancement : godot --headless --path <dossier_du_projet> res://tests/milestone2_test.tscn
## Code de sortie : 0 si tout passe, 1 sinon.

const GAME_SCENE: PackedScene = preload("res://game/game.tscn")
const DUMMY_SCENE: PackedScene = preload("res://targets/training_dummy.tscn")
const PLAYER_START := Vector3(0.0, 0.05, 0.0)

var _game: Node
var _player: FPSController
var _head: Node3D
var _inventory: WeaponInventory
var _stats: PlayerStats
var _recoil: CameraRecoil
var _pistol: Weapon
var _dummy: TrainingDummy
var _hits: Array[Dictionary] = []
var _surface_hits: int = 0
var _shots: int = 0
var _passes: int = 0
var _failures: int = 0


func _ready() -> void:
	_game = GAME_SCENE.instantiate()
	# Les ennemis du générateur de test perturberaient ces mesures.
	_game.get_node("DebugSpawner").set("enabled", false)
	# Pas de vagues automatiques : ce test pilote lui-même les ennemis.
	_game.get_node("WaveManager").set("auto_start", false)
	# Les mannequins ne font plus partie de l'arène de jeu : le test place le sien en (0, 0, -7).
	var targets := Node3D.new()
	targets.name = "TestTargets"
	_game.add_child(targets)
	var dummy: Node3D = DUMMY_SCENE.instantiate()
	dummy.name = "DummyNear"
	dummy.position = Vector3(0.0, 0.0, -7.0)
	targets.add_child(dummy)
	_game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_game)
	_player = _game.get_node("Player") as FPSController
	_head = _player.get_node("Head") as Node3D
	_inventory = _player.get_node("WeaponInventory") as WeaponInventory
	_stats = _player.get_node("PlayerStats") as PlayerStats
	_recoil = _player.get_node("Head/RecoilPivot") as CameraRecoil
	_dummy = _game.get_node("TestTargets/DummyNear") as TrainingDummy
	# En mode headless la souris ne peut pas être capturée.
	_inventory.require_mouse_capture = false
	DamageManager.hit_landed.connect(_on_hit_landed)
	DamageManager.surface_hit.connect(_on_surface_hit)
	await _wait_physics(2)
	_pistol = _inventory.get_active_weapon()
	if _pistol == null:
		_check(false, "Une arme est active au démarrage")
	else:
		_pistol.fired.connect(_on_fired)
		await _run_all()
	Input.action_release("fire")
	print("")
	print("JALON 2 : %d test(s) réussi(s), %d échec(s)" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _run_all() -> void:
	await _test_loadout()
	await _test_single_shot()
	await _test_critical_shot()
	await _test_semi_auto_hold()
	await _test_fire_rate_and_spread()
	await _test_recoil()
	await _test_auto_reload()
	await _test_manual_reload()
	await _test_kill_and_respawn()
	await _test_wall_impact()
	await _test_switch_interrupts_reload()


func _test_loadout() -> void:
	_check(_pistol.data.id == &"pistol", "Pistolet équipé au départ")
	_check(_inventory.get_active_slot() == WeaponInventory.SIDEARM_SLOT, "Pistolet dans l'emplacement 3")
	_check(_inventory.get_weapon_in_slot(0) == null and _inventory.get_weapon_in_slot(1) == null, "Emplacements principaux vides")
	_check(_pistol.current_ammo == 12 and _pistol.get_magazine_size() == 12, "Chargeur de 12")
	_send_action("weapon_1")
	await _wait_physics(2)
	_check(_inventory.get_active_slot() == WeaponInventory.SIDEARM_SLOT, "Touche 1 sans arme : le pistolet reste actif")
	var ammo_label: Label = _game.get_node("HUD").get_node("%AmmoLabel")
	await _wait_process(2)
	_check(ammo_label.text == "12 / ∞", "HUD : affichage « 12 / ∞ » (obtenu « %s »)" % ammo_label.text)


func _test_single_shot() -> void:
	_stats.crit_chance_bonus = -1.0
	_dummy.reset_dummy()
	await _prepare_shot(0.0)
	var ammo_before: int = _pistol.current_ammo
	await _click()
	await _wait_physics(2)
	_check(_pistol.current_ammo == ammo_before - 1, "Un clic consomme une balle")
	_check(_hits.size() == 1, "Le tir hitscan touche le mannequin")
	if _hits.size() == 1:
		var info: DamageInfo = _hits[0]["info"]
		_check_near(info.amount, 25.0, 0.001, "Dégâts de base du pistolet")
		_check(not info.is_critical, "Aucun critique avec 0 % de chance")
		_check_near(_dummy.get_health(), 125.0, 0.001, "PV du mannequin mis à jour")


func _test_critical_shot() -> void:
	_stats.crit_chance_bonus = 1.0
	await _prepare_shot(0.0)
	await _click()
	await _wait_physics(2)
	_check(_hits.size() == 1, "Le tir critique touche le mannequin")
	if _hits.size() == 1:
		var info: DamageInfo = _hits[0]["info"]
		_check(info.is_critical, "Critique avec 100 % de chance")
		_check_near(info.amount, 37.5, 0.001, "Dégâts critiques = 25 × 1,5")
	_stats.crit_chance_bonus = -1.0


func _test_semi_auto_hold() -> void:
	await _prepare_shot(0.0)
	Input.action_press("fire")
	await _wait_physics(60)
	Input.action_release("fire")
	_check(_shots == 1, "Semi-automatique : maintenir le clic = un seul tir (obtenu %d)" % _shots)


func _test_fire_rate_and_spread() -> void:
	await _prepare_shot(0.0)
	var highest_spread: float = 0.0
	for frame in 60:
		if frame % 2 == 0:
			Input.action_press("fire")
		else:
			Input.action_release("fire")
		await _wait_physics(1)
		highest_spread = maxf(highest_spread, _pistol.current_spread_degrees)
	Input.action_release("fire")
	_check(_shots >= 4 and _shots <= 6, "Cadence max 300/min : 4 à 6 tirs en 1 s de clics (obtenu %d)" % _shots)
	_check(highest_spread > _pistol.data.spread_min_degrees, "La dispersion augmente après un tir (%.2f°)" % highest_spread)
	_check(highest_spread <= _pistol.data.spread_max_degrees + 0.001, "La dispersion reste sous le maximum")
	await _wait_physics(60)
	_check_near(_pistol.current_spread_degrees, _pistol.data.spread_min_degrees, 0.001, "La dispersion revient à sa valeur initiale")


func _test_recoil() -> void:
	await _prepare_shot(0.0)
	await _click()
	# Le tir est traité au pas physique suivant : on attend qu'il soit effectué.
	await _wait_physics(1)
	_check(_shots == 1, "Le tir de test du recul est parti")
	_check(_recoil.get_pitch_degrees() > 0.5, "Recul de visée appliqué (%.2f°)" % _recoil.get_pitch_degrees())
	await _wait_physics(60)
	await _wait_process(2)
	_check(_recoil.get_pitch_degrees() < 0.05, "Le recul revient progressivement à zéro (%.3f°)" % _recoil.get_pitch_degrees())


func _test_auto_reload() -> void:
	await _prepare_shot(0.0)
	for _frame in 300:
		if _pistol.current_ammo <= 0:
			break
		await _click()
		await _wait_physics(1)
	Input.action_release("fire")
	await _wait_physics(1)
	_check(_pistol.current_ammo == 0 and _pistol.is_reloading, "Rechargement automatique quand le chargeur est vide")
	var shots_before: int = _shots
	for _frame in 10:
		await _click()
	_check(_shots == shots_before, "Tir impossible pendant le rechargement")
	# Environ 12 pas physiques se sont déjà écoulés depuis le début du rechargement.
	var frames: int = 12
	while _pistol.is_reloading and frames < 200:
		await _wait_physics(1)
		frames += 1
	_check(frames >= 66 and frames <= 78, "Durée de rechargement ≈ 1,2 s (%d frames à 60 Hz)" % frames)
	_check(_pistol.current_ammo == 12, "Chargeur plein après rechargement")


func _test_manual_reload() -> void:
	await _prepare_shot(0.0)
	for _shot in 3:
		await _click()
		await _wait_physics(14)
	_check(_pistol.current_ammo == 9, "Trois tirs consomment trois balles")
	_send_action("reload")
	await _wait_physics(1)
	_check(_pistol.is_reloading, "R lance le rechargement")
	await _wait_physics(80)
	_check(not _pistol.is_reloading and _pistol.current_ammo == 12, "Rechargement manuel terminé")
	_send_action("reload")
	await _wait_physics(1)
	_check(not _pistol.is_reloading, "R avec un chargeur plein est ignoré")


func _test_kill_and_respawn() -> void:
	_dummy.reset_dummy()
	await _prepare_shot(0.0)
	var shots_needed: int = 0
	var killed: bool = false
	for _shot in 10:
		_hits.clear()
		await _click()
		await _wait_physics(19)
		shots_needed += 1
		if not _hits.is_empty() and _hits[-1]["killed"]:
			killed = true
			break
	_check(killed and shots_needed == 6, "Élimination du mannequin en 6 tirs de 25 sur 150 PV (obtenu %d)" % shots_needed)
	_check(_dummy.is_dead(), "Le mannequin est marqué éliminé")
	await _wait_physics(roundi(_dummy.respawn_delay * 60.0) + 15)
	_check(not _dummy.is_dead() and is_equal_approx(_dummy.get_health(), 150.0), "Le mannequin réapparaît avec tous ses PV")


func _test_wall_impact() -> void:
	await _prepare_shot(-PI * 0.5)
	_surface_hits = 0
	await _click()
	await _wait_physics(2)
	_check(_surface_hits == 1 and _hits.is_empty(), "Tir dans le décor : impact visible, aucun dégât")


func _test_switch_interrupts_reload() -> void:
	await _prepare_shot(0.0)
	_inventory.equip_weapon(_pistol.data, 0)
	await _click()
	await _wait_physics(14)
	await _click()
	await _wait_physics(2)
	var ammo_before_switch: int = _pistol.current_ammo
	_send_action("reload")
	await _wait_physics(5)
	_check(_pistol.is_reloading, "Rechargement lancé avant le changement d'arme")
	_send_action("weapon_1")
	await _wait_physics(2)
	_check(_inventory.get_active_slot() == 0, "Touche 1 : passage à l'arme principale 1")
	_check(not _pistol.is_reloading, "Changer d'arme interrompt le rechargement")
	await _wait_physics(90)
	_send_action("weapon_3")
	await _wait_physics(2)
	_check(_inventory.get_active_slot() == WeaponInventory.SIDEARM_SLOT, "Touche 3 : retour au pistolet")
	_check(_pistol.current_ammo == ammo_before_switch, "Le changement d'arme ne recharge pas l'arme précédente")
	_send_action("weapon_next")
	await _wait_physics(2)
	_check(_inventory.get_active_slot() == 0, "Molette : arme suivante (3 → 1)")
	_send_action("weapon_prev")
	await _wait_physics(2)
	_check(_inventory.get_active_slot() == WeaponInventory.SIDEARM_SLOT, "Molette : arme précédente (1 → 3)")


## Place le joueur face au mannequin proche (yaw = 0) ou dans une autre direction, chargeur plein.
func _prepare_shot(yaw: float) -> void:
	Input.action_release("fire")
	_player.global_position = PLAYER_START
	_player.rotation = Vector3(0.0, yaw, 0.0)
	_player.velocity = Vector3.ZERO
	_head.rotation = Vector3.ZERO
	_recoil.reset()
	await _wait_physics(30)
	_pistol.cancel_reload()
	_pistol.current_ammo = _pistol.get_magazine_size()
	_hits.clear()
	_shots = 0


func _click() -> void:
	Input.action_press("fire")
	await _wait_physics(1)
	Input.action_release("fire")


func _on_hit_landed(target: Node, info: DamageInfo, killed: bool) -> void:
	_hits.append({"target": target, "info": info, "killed": killed})


func _on_surface_hit(_at: Vector3, _normal: Vector3) -> void:
	_surface_hits += 1


func _on_fired() -> void:
	_shots += 1


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
