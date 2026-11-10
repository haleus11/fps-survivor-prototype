extends CanvasLayer
## Écran de défaite : fige la partie, libère la souris, affiche le bilan et propose de recommencer.

@export var player_health: PlayerHealth
@export var player_progress: PlayerProgress

var is_shown: bool = false

@onready var _root: Control = $Root
@onready var _summary_label: Label = %SummaryLabel
@onready var _restart_button: Button = %RestartButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	_root.visible = false
	_restart_button.pressed.connect(_on_restart_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	if player_health != null:
		player_health.died.connect(show_game_over)


func show_game_over() -> void:
	if is_shown:
		return
	is_shown = true
	if player_progress != null:
		_summary_label.text = "Éliminations : %d\nXP : %d\nCrédits : %d" % [player_progress.kills, player_progress.xp, player_progress.credits]
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_restart_button.grab_focus()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	Diagnostics.reset()
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().quit()
