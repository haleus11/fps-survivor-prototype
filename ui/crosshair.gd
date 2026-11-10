extends Control
## Réticule provisoire dessiné au centre de l'écran.

@export var color: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.6)
@export var gap: float = 5.0
@export var arm_length: float = 8.0
@export var thickness: float = 2.0

const _DIRECTIONS := [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var center: Vector2 = size * 0.5
	for direction in _DIRECTIONS:
		var from: Vector2 = center + direction * (gap - 1.0)
		var to: Vector2 = center + direction * (gap + arm_length + 1.0)
		draw_line(from, to, outline_color, thickness + 2.0)
	for direction in _DIRECTIONS:
		var from: Vector2 = center + direction * gap
		var to: Vector2 = center + direction * (gap + arm_length)
		draw_line(from, to, color, thickness)
	draw_circle(center, 1.5, color)
