extends CanvasLayer
## Menu pause (Échap) : met l'arbre en pause, libère la souris, règle la sensibilité.

## Ressource partagée avec le joueur : modifier la sensibilité ici agit immédiatement en jeu.
@export var movement_config: PlayerMovementConfig

@onready var _root: Control = $Root
@onready var _sensitivity_slider: HSlider = %SensitivitySlider
@onready var _sensitivity_value_label: Label = %SensitivityValue
@onready var _resume_button: Button = %ResumeButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	_root.visible = false
	_resume_button.pressed.connect(_on_resume_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	if movement_config != null:
		_sensitivity_slider.value = movement_config.mouse_sensitivity
	else:
		_sensitivity_slider.editable = false
	_sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	_update_sensitivity_label()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_root.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	if paused:
		_resume_button.grab_focus()


func _on_resume_pressed() -> void:
	set_paused(false)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_sensitivity_changed(value: float) -> void:
	if movement_config != null:
		movement_config.mouse_sensitivity = value
	_update_sensitivity_label()


func _update_sensitivity_label() -> void:
	_sensitivity_value_label.text = "%.2f °/px" % _sensitivity_slider.value
