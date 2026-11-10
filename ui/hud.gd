extends CanvasLayer
## HUD : réticule dynamique, hitmarkers, arme active, munitions, rechargement,
## messages temporaires (critique / élimination) et overlay de diagnostic (F3).

@export var player: FPSController
@export var weapon_inventory: WeaponInventory
@export var feed_duration: float = 0.9
@export var low_ammo_ratio: float = 0.25
@export var ammo_color: Color = Color(1.0, 1.0, 1.0)
@export var low_ammo_color: Color = Color(1.0, 0.35, 0.3)
@export var critical_feed_color: Color = Color(1.0, 0.62, 0.1)
@export var kill_feed_color: Color = Color(1.0, 0.3, 0.25)

var _shown_weapon: Weapon = null
var _shown_ammo: int = -1
var _shown_magazine: int = -1
var _feed_timer: float = 0.0

@onready var _debug_overlay: DebugOverlay = $DebugOverlay
@onready var _crosshair: Crosshair = $Crosshair
@onready var _weapon_name_label: Label = %WeaponNameLabel
@onready var _ammo_label: Label = %AmmoLabel
@onready var _reload_bar: ProgressBar = %ReloadBar
@onready var _feed_label: Label = %FeedLabel
@onready var _hit_sound: AudioStreamPlayer = %HitSound
@onready var _critical_sound: AudioStreamPlayer = %CriticalSound
@onready var _kill_sound: AudioStreamPlayer = %KillSound


func _ready() -> void:
	_debug_overlay.player = player
	_reload_bar.visible = false
	_feed_label.modulate.a = 0.0
	DamageManager.hit_landed.connect(_on_hit_landed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_debug_overlay.visible = not _debug_overlay.visible
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var weapon: Weapon = weapon_inventory.get_active_weapon() if weapon_inventory != null else null
	_update_weapon_panel(weapon)
	_update_crosshair_gap(weapon)
	if _feed_timer > 0.0:
		_feed_timer = maxf(_feed_timer - delta, 0.0)
		_feed_label.modulate.a = clampf(_feed_timer / (feed_duration * 0.4), 0.0, 1.0)


func _update_weapon_panel(weapon: Weapon) -> void:
	if weapon == null:
		if _shown_weapon != null or _shown_ammo != -1:
			_weapon_name_label.text = "Aucune arme"
			_ammo_label.text = ""
			_reload_bar.visible = false
			_shown_weapon = null
			_shown_ammo = -1
		return
	if weapon != _shown_weapon:
		_shown_weapon = weapon
		_weapon_name_label.text = weapon.data.display_name
		_shown_ammo = -1
	var magazine: int = weapon.get_magazine_size()
	if weapon.current_ammo != _shown_ammo or magazine != _shown_magazine:
		_shown_ammo = weapon.current_ammo
		_shown_magazine = magazine
		_ammo_label.text = "%d / ∞" % weapon.current_ammo
		var is_low: bool = weapon.current_ammo <= int(magazine * low_ammo_ratio)
		_ammo_label.modulate = low_ammo_color if is_low else ammo_color
	_reload_bar.visible = weapon.is_reloading
	if weapon.is_reloading:
		_reload_bar.value = weapon.get_reload_progress()


func _update_crosshair_gap(weapon: Weapon) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if weapon == null or camera == null:
		_crosshair.set_spread_gap(0.0)
		return
	# Conversion de l'angle de dispersion en pixels à l'écran (FOV vertical).
	var half_height: float = get_viewport().get_visible_rect().size.y * 0.5
	var spread_ratio: float = tan(deg_to_rad(weapon.current_spread_degrees)) / tan(deg_to_rad(camera.fov * 0.5))
	_crosshair.set_spread_gap(spread_ratio * half_height)


func _on_hit_landed(_target: Node, info: DamageInfo, killed: bool) -> void:
	if player == null or info.source != player:
		return
	if killed:
		_crosshair.show_hitmarker(Crosshair.HitKind.KILL)
		_kill_sound.play()
		_show_feed("ÉLIMINATION CRITIQUE" if info.is_critical else "ÉLIMINATION", kill_feed_color)
	elif info.is_critical:
		_crosshair.show_hitmarker(Crosshair.HitKind.CRITICAL)
		_critical_sound.play()
		_show_feed("CRITIQUE  %d" % roundi(info.amount), critical_feed_color)
	else:
		_crosshair.show_hitmarker(Crosshair.HitKind.NORMAL)
		_hit_sound.play()


func _show_feed(text: String, color: Color) -> void:
	_feed_label.text = text
	_feed_label.modulate = color
	_feed_timer = feed_duration
