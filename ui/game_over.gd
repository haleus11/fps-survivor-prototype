extends CanvasLayer
## Écran de fin de partie (défaite ou victoire) : fige la partie, libère la souris,
## affiche le bilan et propose de recommencer.

@export var player_health: PlayerHealth
@export var player_progress: PlayerProgress
@export var wave_manager: WaveManager
@export var defeat_color: Color = Color(1.0, 0.35, 0.3)
@export var victory_color: Color = Color(0.45, 1.0, 0.5)

var is_shown: bool = false
var is_victory: bool = false

@onready var _root: Control = $Root
@onready var _dim: ColorRect = $Root/Dim
@onready var _title_label: Label = %Title
@onready var _summary_label: Label = %SummaryLabel
@onready var _restart_button: Button = %RestartButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	_root.visible = false
	_restart_button.pressed.connect(_on_restart_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	if player_health != null:
		player_health.died.connect(show_game_over)
	if wave_manager != null:
		wave_manager.victory.connect(_on_victory)


func show_game_over() -> void:
	_show(false)


func show_victory() -> void:
	_show(true)


func _on_victory(_summary: Dictionary) -> void:
	show_victory()


func _show(victory: bool) -> void:
	if is_shown:
		return
	is_shown = true
	is_victory = victory
	_title_label.text = "VICTOIRE" if victory else "DÉFAITE"
	_title_label.add_theme_color_override("font_color", victory_color if victory else defeat_color)
	_dim.color = Color(0.0, 0.18, 0.05, 0.7) if victory else Color(0.25, 0.0, 0.0, 0.7)
	var lines := PackedStringArray()
	if wave_manager != null and wave_manager.config != null:
		lines.append("Vague atteinte : %d / %d" % [wave_manager.current_wave, wave_manager.config.wave_count])
	if player_progress != null:
		lines.append("Éliminations : %d" % player_progress.kills)
		lines.append("XP : %d" % player_progress.xp)
		lines.append("Crédits : %d" % player_progress.credits)
	_summary_label.text = "\n".join(lines)
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
