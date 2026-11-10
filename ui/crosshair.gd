class_name Crosshair
extends Control
## Réticule dynamique (l'écart suit la dispersion de l'arme) et hitmarker.

enum HitKind { NORMAL, CRITICAL, KILL }

@export var color: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.6)
@export var min_gap: float = 4.0
@export var arm_length: float = 8.0
@export var thickness: float = 2.0

@export_group("Hitmarker")
@export var hitmarker_duration: float = 0.15
@export var hit_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var critical_color: Color = Color(1.0, 0.62, 0.1, 1.0)
@export var kill_color: Color = Color(1.0, 0.22, 0.2, 1.0)
@export var hit_size: float = 7.0
@export var critical_size: float = 10.0
@export var kill_size: float = 13.0

const _DIRECTIONS := [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
const _DIAGONALS := [Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071), Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071)]

var _gap: float = 4.0
var _drawn_gap: float = -1.0
var _hit_timer: float = 0.0
var _hit_total: float = 1.0
var _hit_kind: HitKind = HitKind.NORMAL


func _ready() -> void:
	resized.connect(queue_redraw)


func set_spread_gap(gap: float) -> void:
	_gap = maxf(gap, min_gap)
	if absf(_gap - _drawn_gap) > 0.25:
		queue_redraw()


func show_hitmarker(kind: HitKind) -> void:
	# Un marqueur plus fort (élimination > critique > normal) n'est pas écrasé par un plus faible.
	if _hit_timer > 0.0 and kind < _hit_kind:
		return
	_hit_kind = kind
	_hit_total = hitmarker_duration * (1.0 if kind == HitKind.NORMAL else 1.6)
	_hit_timer = _hit_total
	queue_redraw()


func _process(delta: float) -> void:
	if _hit_timer > 0.0:
		_hit_timer = maxf(_hit_timer - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	_drawn_gap = _gap
	var center: Vector2 = size * 0.5
	for direction in _DIRECTIONS:
		var from: Vector2 = center + direction * (_gap - 1.0)
		var to: Vector2 = center + direction * (_gap + arm_length + 1.0)
		draw_line(from, to, outline_color, thickness + 2.0)
	for direction in _DIRECTIONS:
		var from: Vector2 = center + direction * _gap
		var to: Vector2 = center + direction * (_gap + arm_length)
		draw_line(from, to, color, thickness)
	draw_circle(center, 1.5, color)
	if _hit_timer <= 0.0:
		return
	var marker_color: Color = hit_color
	var marker_size: float = hit_size
	var marker_thickness: float = thickness
	if _hit_kind == HitKind.CRITICAL:
		marker_color = critical_color
		marker_size = critical_size
		marker_thickness = thickness + 1.0
	elif _hit_kind == HitKind.KILL:
		marker_color = kill_color
		marker_size = kill_size
		marker_thickness = thickness + 1.5
	marker_color.a *= _hit_timer / _hit_total
	var inner: float = 5.0
	for diagonal in _DIAGONALS:
		var from: Vector2 = center + diagonal * inner
		var to: Vector2 = center + diagonal * (inner + marker_size)
		draw_line(from, to, marker_color, marker_thickness)
