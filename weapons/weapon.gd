class_name Weapon
extends Node
## Instance d'arme en jeu : chargeur, cadence, rechargement, dispersion et recul.
## Le comportement de tir est délégué à WeaponData.fire_behavior, le visuel à WeaponView.

signal fired
signal reload_started(duration: float)
signal reload_finished
signal reload_cancelled

## Calques touchés par les tirs : 1 = décor, 3 = ennemis.
const HIT_COLLISION_MASK: int = 1 | 4
## Tolérance sur la cadence pour absorber les erreurs d'arrondi du pas physique.
const COOLDOWN_EPSILON: float = 0.0001

var data: WeaponData
var view: WeaponView
var current_ammo: int = 0
var current_spread_degrees: float = 0.0
var is_reloading: bool = false

var _cooldown: float = 0.0
var _last_delta: float = 0.0
var _reload_remaining: float = 0.0
var _reload_duration: float = 0.0
var _owner_body: CollisionObject3D
var _aim: Node3D
var _stats: PlayerStats
var _recoil: CameraRecoil
var _fire_audio: AudioStreamPlayer
var _mechanism_audio: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func setup(weapon_data: WeaponData, owner_body: CollisionObject3D, aim: Node3D, stats: PlayerStats, recoil: CameraRecoil, weapon_view: WeaponView) -> void:
	data = weapon_data
	_owner_body = owner_body
	_aim = aim
	_stats = stats
	_recoil = recoil
	view = weapon_view
	_rng.randomize()
	_fire_audio = _create_audio_player(data.fire_sound, 4)
	_mechanism_audio = _create_audio_player(null, 1)
	current_ammo = get_magazine_size()
	current_spread_degrees = data.spread_min_degrees


func set_active(active: bool) -> void:
	if not active:
		cancel_reload()
	if view != null:
		view.visible = active
		if active:
			view.play_equip()


func tick(delta: float) -> void:
	_last_delta = delta
	_cooldown = maxf(_cooldown - delta, -1.0)
	current_spread_degrees = move_toward(current_spread_degrees, data.spread_min_degrees, data.spread_recovery_degrees_per_second * delta)
	if is_reloading:
		_reload_remaining -= delta
		if _reload_remaining <= 0.0:
			_finish_reload()
	if view != null:
		view.reload_progress = get_reload_progress() if is_reloading else -1.0


func is_ready_to_fire() -> bool:
	return not is_reloading and current_ammo > 0 and _cooldown <= COOLDOWN_EPSILON


func try_fire() -> bool:
	if not is_ready_to_fire():
		return false
	if data.fire_behavior == null:
		push_error("Arme %s : aucun FireBehavior assigné." % data.id)
		return false
	current_ammo -= 1
	# Le reliquat d'un pas physique est conservé pour une cadence moyenne exacte en tir continu.
	var carry: float = _cooldown if _cooldown > -_last_delta else 0.0
	_cooldown = carry + get_fire_interval()
	data.fire_behavior.fire(self)
	current_spread_degrees = minf(current_spread_degrees + data.spread_per_shot_degrees, data.spread_max_degrees)
	if _recoil != null:
		var yaw: float = _rng.randf_range(-data.recoil_yaw_degrees, data.recoil_yaw_degrees)
		_recoil.add_kick(data.recoil_pitch_degrees, yaw, data.recoil_recovery_speed)
	if view != null:
		view.play_fire(data.view_kick_distance, data.view_kick_degrees)
	if data.fire_sound != null:
		_fire_audio.play()
	fired.emit()
	return true


func play_empty_click() -> void:
	_play_mechanism(data.empty_sound)


func start_reload() -> bool:
	if is_reloading or current_ammo >= get_magazine_size():
		return false
	is_reloading = true
	_reload_duration = get_reload_duration()
	_reload_remaining = _reload_duration
	_play_mechanism(data.reload_start_sound)
	reload_started.emit(_reload_duration)
	return true


func cancel_reload() -> void:
	if not is_reloading:
		return
	is_reloading = false
	_reload_remaining = 0.0
	if view != null:
		view.reload_progress = -1.0
	reload_cancelled.emit()


func get_magazine_size() -> int:
	var multiplier: float = _stats.magazine_multiplier if _stats != null else 1.0
	# Arrondi à l'entier supérieur ; la tolérance évite qu'un 12,0000001 devienne 13.
	return maxi(1, ceili(data.magazine_size * multiplier - 0.0001))


func get_fire_interval() -> float:
	var multiplier: float = _stats.fire_rate_multiplier if _stats != null else 1.0
	return data.get_fire_interval() / maxf(multiplier, 0.01)


func get_reload_duration() -> float:
	var multiplier: float = _stats.reload_speed_multiplier if _stats != null else 1.0
	return data.reload_time / maxf(multiplier, 0.01)


func get_reload_progress() -> float:
	if not is_reloading or _reload_duration <= 0.0:
		return 0.0
	return clampf(1.0 - _reload_remaining / _reload_duration, 0.0, 1.0)


## Direction de tir aléatoire dans le cône de dispersion courant (répartition uniforme sur le disque).
func get_spread_direction() -> Vector3:
	var spread_radians: float = deg_to_rad(current_spread_degrees)
	var radius: float = tan(spread_radians) * sqrt(_rng.randf())
	var angle: float = _rng.randf() * TAU
	var local_direction := Vector3(cos(angle) * radius, sin(angle) * radius, -1.0)
	return (_aim.global_transform.basis * local_direction).normalized()


func cast_ray(direction: Vector3, max_distance: float) -> Dictionary:
	var origin: Vector3 = _aim.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_distance, HIT_COLLISION_MASK)
	if _owner_body != null:
		query.exclude = [_owner_body.get_rid()]
	return _aim.get_world_3d().direct_space_state.intersect_ray(query)


func process_hit(hit: Dictionary, direction: Vector3, base_damage: float) -> void:
	var hit_position: Vector3 = hit["position"]
	var hit_normal: Vector3 = hit["normal"]
	var collider := hit.get("collider") as Node
	if collider != null and collider.has_method("apply_damage"):
		var info: DamageInfo = DamageManager.create_hit(base_damage, _stats, _owner_body)
		info.position = hit_position
		info.normal = hit_normal
		info.direction = direction
		DamageManager.apply_hit(collider, info)
	else:
		DamageManager.report_surface_hit(hit_position, hit_normal)


func _finish_reload() -> void:
	is_reloading = false
	current_ammo = get_magazine_size()
	_play_mechanism(data.reload_end_sound)
	reload_finished.emit()


func _play_mechanism(stream: AudioStream) -> void:
	if stream == null:
		return
	_mechanism_audio.stream = stream
	_mechanism_audio.play()


func _create_audio_player(stream: AudioStream, polyphony: int) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.max_polyphony = polyphony
	add_child(player)
	return player
