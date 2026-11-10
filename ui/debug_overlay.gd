class_name DebugOverlay
extends PanelContainer
## Overlay de diagnostic : performances, compteurs globaux et état du joueur.

## Fréquence de rafraîchissement du texte (s) : évite de reconstruire la chaîne à chaque frame.
@export var refresh_interval: float = 0.25

var player: FPSController

var _time_accumulator: float = 0.0
var _frame_accumulator: int = 0

@onready var _label: Label = $Label


func _process(delta: float) -> void:
	_time_accumulator += delta
	_frame_accumulator += 1
	if _time_accumulator < refresh_interval:
		return
	var average_frame_ms: float = _time_accumulator / float(_frame_accumulator) * 1000.0
	_time_accumulator = 0.0
	_frame_accumulator = 0
	if visible:
		_label.text = _build_text(average_frame_ms)


func _build_text(average_frame_ms: float) -> String:
	var lines := PackedStringArray([
		"DIAGNOSTIC (F3)",
		"FPS : %d" % roundi(Engine.get_frames_per_second()),
		"Frame moyenne : %.2f ms" % average_frame_ms,
		"Ennemis actifs : %d" % Diagnostics.active_enemies,
		"Projectiles : %d" % Diagnostics.active_projectiles,
		"Effets : %d" % Diagnostics.active_effects,
		"Spawns totaux : %d" % Diagnostics.total_spawns,
		"Kills totaux : %d" % Diagnostics.total_kills,
	])
	if player != null:
		var player_position: Vector3 = player.global_position
		lines.append("Vitesse horizontale : %.2f m/s" % player.get_horizontal_speed())
		lines.append("État : %s" % _movement_state())
		lines.append("Position : (%.1f, %.1f, %.1f)" % [player_position.x, player_position.y, player_position.z])
	var mouse_captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	lines.append("Souris : %s" % ("capturée" if mouse_captured else "libre"))
	return "\n".join(lines)


func _movement_state() -> String:
	if not player.is_on_floor():
		return "en l'air"
	if player.is_sprinting:
		return "sprint"
	if player.get_horizontal_speed() > 0.1:
		return "marche"
	return "immobile"
