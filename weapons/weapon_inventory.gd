class_name WeaponInventory
extends Node
## Trois emplacements : 1 et 2 = armes principales, 3 = pistolet permanent.
## Lit les entrées (tir, rechargement, changement d'arme) ; la logique de tir reste dans Weapon.

signal active_weapon_changed(weapon: Weapon)

const SLOT_COUNT: int = 3
const SIDEARM_SLOT: int = 2

@export var starting_sidearm: WeaponData
@export var auto_reload_when_empty: bool = true
## Un clic légèrement trop tôt en semi-automatique est mémorisé pendant cette durée (s).
@export var semi_auto_buffer_time: float = 0.12
## Ignore le tir tant que la souris n'est pas capturée (évite un tir au clic de reprise).
@export var require_mouse_capture: bool = true

@export_group("Références")
@export var owner_body: CollisionObject3D
@export var aim_camera: Camera3D
@export var stats: PlayerStats
@export var recoil: CameraRecoil
@export var view_pivot: Node3D

var _slots: Array[Weapon] = []
var _active_slot: int = -1
var _fire_buffer: float = 0.0


func _ready() -> void:
	_slots.resize(SLOT_COUNT)
	if starting_sidearm != null:
		equip_weapon(starting_sidearm, SIDEARM_SLOT)
		switch_to_slot(SIDEARM_SLOT)


func equip_weapon(weapon_data: WeaponData, slot: int) -> Weapon:
	if weapon_data == null or slot < 0 or slot >= SLOT_COUNT:
		push_error("WeaponInventory : équipement invalide (emplacement %d)." % slot)
		return null
	_remove_weapon(slot)
	var weapon := Weapon.new()
	weapon.name = "Weapon_%s" % weapon_data.id
	add_child(weapon)
	var weapon_view: WeaponView = null
	if weapon_data.view_scene != null and view_pivot != null:
		weapon_view = weapon_data.view_scene.instantiate() as WeaponView
		if weapon_view != null:
			view_pivot.add_child(weapon_view)
			weapon_view.visible = false
	weapon.setup(weapon_data, owner_body, aim_camera, stats, recoil, weapon_view)
	_slots[slot] = weapon
	if slot == _active_slot:
		weapon.set_active(true)
		active_weapon_changed.emit(weapon)
	return weapon


func get_active_weapon() -> Weapon:
	if _active_slot < 0:
		return null
	return _slots[_active_slot]


func get_active_slot() -> int:
	return _active_slot


func get_weapon_in_slot(slot: int) -> Weapon:
	if slot < 0 or slot >= SLOT_COUNT:
		return null
	return _slots[slot]


func switch_to_slot(slot: int) -> bool:
	if slot < 0 or slot >= SLOT_COUNT or slot == _active_slot or _slots[slot] == null:
		return false
	var previous: Weapon = get_active_weapon()
	if previous != null:
		previous.set_active(false)
	_active_slot = slot
	_fire_buffer = 0.0
	var weapon: Weapon = _slots[slot]
	weapon.set_active(true)
	active_weapon_changed.emit(weapon)
	return true


func cycle_weapon(step: int) -> void:
	for offset in range(1, SLOT_COUNT):
		var slot: int = posmod(_active_slot + offset * step, SLOT_COUNT)
		if _slots[slot] != null:
			switch_to_slot(slot)
			return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("weapon_1"):
		switch_to_slot(0)
	elif event.is_action_pressed("weapon_2"):
		switch_to_slot(1)
	elif event.is_action_pressed("weapon_3"):
		switch_to_slot(SIDEARM_SLOT)
	elif event.is_action_pressed("weapon_next"):
		cycle_weapon(1)
	elif event.is_action_pressed("weapon_prev"):
		cycle_weapon(-1)
	elif event.is_action_pressed("reload"):
		var weapon: Weapon = get_active_weapon()
		if weapon != null:
			weapon.start_reload()


func _physics_process(delta: float) -> void:
	var weapon: Weapon = get_active_weapon()
	if weapon == null:
		return
	weapon.tick(delta)
	_handle_trigger(weapon, delta)
	if auto_reload_when_empty and weapon.current_ammo <= 0 and not weapon.is_reloading:
		weapon.start_reload()


func _handle_trigger(weapon: Weapon, delta: float) -> void:
	if require_mouse_capture and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_fire_buffer = 0.0
		return
	var just_pressed: bool = Input.is_action_just_pressed("fire")
	if weapon.current_ammo <= 0:
		_fire_buffer = 0.0
		if just_pressed and not weapon.is_reloading:
			weapon.play_empty_click()
		return
	if weapon.data.fire_mode == WeaponData.FireMode.AUTOMATIC:
		if Input.is_action_pressed("fire"):
			weapon.try_fire()
		return
	if just_pressed:
		_fire_buffer = semi_auto_buffer_time
	if _fire_buffer > 0.0 and weapon.try_fire():
		_fire_buffer = 0.0
	else:
		_fire_buffer = maxf(_fire_buffer - delta, 0.0)


func _remove_weapon(slot: int) -> void:
	var existing: Weapon = _slots[slot]
	if existing == null:
		return
	if existing.view != null:
		existing.view.queue_free()
	existing.queue_free()
	_slots[slot] = null
