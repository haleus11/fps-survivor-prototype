extends CanvasLayer
## Entracte entre deux vagues : fige la partie, libère la souris, affiche le bilan de la vague
## et lance la vague suivante quand le joueur est prêt. L'armurerie s'y ajoutera plus tard.

@export var wave_manager: WaveManager

var is_shown: bool = false

@onready var _root: Control = $Root
@onready var _title_label: Label = %TitleLabel
@onready var _summary_label: Label = %SummaryLabel
@onready var _next_button: Button = %NextWaveButton


func _ready() -> void:
	_root.visible = false
	_next_button.pressed.connect(_on_next_pressed)
	if wave_manager != null:
		wave_manager.wave_cleared.connect(show_summary)


func show_summary(wave: int, summary: Dictionary) -> void:
	is_shown = true
	_title_label.text = "VAGUE %d / %d TERMINÉE" % [wave, summary["wave_count"]]
	_summary_label.text = "Éliminations : %d\nXP gagnée : %d\nCrédits gagnés : %d (dont prime de vague : %d)" % [
		summary["kills"], summary["xp"], summary["credits"], summary["bonus"]]
	_next_button.text = "Lancer la vague %d" % (wave + 1)
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_next_button.grab_focus()


func _on_next_pressed() -> void:
	if not is_shown:
		return
	is_shown = false
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if wave_manager != null:
		wave_manager.start_next_wave()
