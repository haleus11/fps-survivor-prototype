extends CanvasLayer
## HUD du jalon 1 : réticule et overlay de diagnostic activable avec F3.

@export var player: FPSController

@onready var _debug_overlay: DebugOverlay = $DebugOverlay


func _ready() -> void:
	_debug_overlay.player = player


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_debug_overlay.visible = not _debug_overlay.visible
		get_viewport().set_input_as_handled()
