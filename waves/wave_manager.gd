class_name WaveManager
extends Node
## Déroulement de la partie : compte à rebours, vague chronométrée avec apparitions continues
## d'intensité croissante, arrêt des apparitions à 00:00, élimination des ennemis restants,
## prime de fin de vague, entracte (lancement manuel de la vague suivante), victoire après la dernière vague.

signal wave_started(wave: int)
signal wave_timer_finished(wave: int)
signal wave_cleared(wave: int, summary: Dictionary)
signal victory(summary: Dictionary)

enum State { WAITING, COUNTDOWN, RUNNING, CLEARING, INTERMISSION, VICTORY }

@export var config: WaveConfig
@export var base_enemy_data: EnemyData
@export var enemy_manager: EnemyManager
## Recherche des points d'apparition (distance au joueur, sol, obstacles).
@export var spawn_finder: DebugSpawner
@export var player_progress: PlayerProgress
## Désactivé par les tests des jalons précédents.
@export var auto_start: bool = true
## Nombre maximal d'apparitions dans un même pas physique (lisse les rattrapages).
@export var max_spawns_per_step: int = 3

var state: State = State.WAITING
var current_wave: int = 0
var time_left: float = 0.0
var countdown_left: float = 0.0
var wave_spawns: int = 0

var _wave_enemy_data: EnemyData
var _spawn_budget: float = 0.0
var _start_kills: int = 0
var _start_xp: int = 0
var _start_credits: int = 0


func _ready() -> void:
	if auto_start and config != null:
		state = State.COUNTDOWN
		countdown_left = config.first_wave_delay


func _physics_process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			countdown_left -= delta
			if countdown_left <= 0.0:
				start_next_wave()
		State.RUNNING:
			_update_running(delta)
		State.CLEARING:
			if enemy_manager.get_active_count() == 0:
				_finish_wave()


func start_next_wave() -> void:
	if config == null or current_wave >= config.wave_count:
		return
	if state == State.RUNNING or state == State.CLEARING or state == State.VICTORY:
		return
	current_wave += 1
	time_left = config.wave_duration
	countdown_left = 0.0
	wave_spawns = 0
	_spawn_budget = 1.0
	_wave_enemy_data = _build_enemy_data(current_wave)
	if player_progress != null:
		_start_kills = player_progress.kills
		_start_xp = player_progress.xp
		_start_credits = player_progress.credits
	state = State.RUNNING
	wave_started.emit(current_wave)


func get_wave_progress() -> float:
	if config == null or config.wave_duration <= 0.0:
		return 1.0
	return clampf(1.0 - time_left / config.wave_duration, 0.0, 1.0)


func get_remaining_enemies() -> int:
	return enemy_manager.get_active_count() if enemy_manager != null else 0


func get_current_enemy_data() -> EnemyData:
	return _wave_enemy_data


func is_last_wave() -> bool:
	return config != null and current_wave >= config.wave_count


static func format_time(seconds: float) -> String:
	var total: int = ceili(maxf(seconds, 0.0))
	@warning_ignore("integer_division")
	var minutes: int = total / 60
	return "%02d:%02d" % [minutes, total % 60]


func _update_running(delta: float) -> void:
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		# 00:00 : plus aucune apparition, il faut éliminer les ennemis restants.
		state = State.CLEARING
		_spawn_budget = 0.0
		wave_timer_finished.emit(current_wave)
		return
	var max_alive: int = config.get_max_alive(current_wave)
	_spawn_budget += config.get_spawn_rate(current_wave, get_wave_progress()) * delta
	# Population au plafond : la cadence ne s'accumule pas en réserve.
	_spawn_budget = minf(_spawn_budget, float(max_spawns_per_step))
	var spawned_this_step: int = 0
	while _spawn_budget >= 1.0 and spawned_this_step < max_spawns_per_step:
		if enemy_manager.get_active_count() >= max_alive:
			break
		_spawn_budget -= 1.0
		spawned_this_step += 1
		var point: Vector3 = spawn_finder.find_spawn_point()
		if point.is_finite() and enemy_manager.spawn_enemy(_wave_enemy_data, point) != null:
			wave_spawns += 1


func _finish_wave() -> void:
	var bonus: int = config.get_clear_bonus(current_wave)
	if player_progress != null:
		player_progress.add_credits(bonus)
	var summary: Dictionary = {
		"wave": current_wave,
		"wave_count": config.wave_count,
		"kills": player_progress.kills - _start_kills if player_progress != null else 0,
		"xp": player_progress.xp - _start_xp if player_progress != null else 0,
		"credits": player_progress.credits - _start_credits if player_progress != null else 0,
		"bonus": bonus,
	}
	if is_last_wave():
		state = State.VICTORY
		victory.emit(summary)
	else:
		state = State.INTERMISSION
		wave_cleared.emit(current_wave, summary)


func _build_enemy_data(wave: int) -> EnemyData:
	var scaled: EnemyData = base_enemy_data.duplicate() as EnemyData
	scaled.max_health = base_enemy_data.max_health * config.get_health_multiplier(wave)
	scaled.contact_damage = base_enemy_data.contact_damage * config.get_damage_multiplier(wave)
	scaled.move_speed = base_enemy_data.move_speed * config.get_speed_multiplier(wave)
	return scaled
