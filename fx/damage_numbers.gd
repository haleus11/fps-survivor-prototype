class_name DamageNumbers
extends Node3D
## Nombres de dégâts flottants. Pool fixe de Label3D : aucune allocation pendant le combat.
## Si le pool est plein, le plus ancien nombre est réutilisé (l'écran reste lisible).

@export var pool_size: int = 40
@export var lifetime: float = 0.65
@export var rise_distance: float = 0.8
@export var scatter: float = 0.25
@export var pixel_size: float = 0.005
@export var font_size: int = 40
@export var critical_font_size: int = 60
@export var normal_color: Color = Color(1.0, 1.0, 1.0)
@export var critical_color: Color = Color(1.0, 0.62, 0.1)

var _labels: Array[Label3D] = []
var _ages := PackedFloat32Array()
var _origins := PackedVector3Array()
var _next_index: int = 0
var _active_count: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_ages.resize(pool_size)
	_origins.resize(pool_size)
	for index in pool_size:
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.pixel_size = pixel_size
		label.outline_size = 10
		label.visible = false
		add_child(label)
		_labels.append(label)
		_ages[index] = -1.0
	DamageManager.hit_landed.connect(_on_hit_landed)


func _on_hit_landed(_target: Node, info: DamageInfo, _killed: bool) -> void:
	var index: int = _next_index
	_next_index = (_next_index + 1) % pool_size
	if _ages[index] < 0.0:
		_active_count += 1
		Diagnostics.active_effects += 1
	_ages[index] = 0.0
	var offset := Vector3(_rng.randf_range(-scatter, scatter), 0.25, _rng.randf_range(-scatter, scatter))
	_origins[index] = info.position + offset
	var label: Label3D = _labels[index]
	label.text = ("%d!" if info.is_critical else "%d") % roundi(info.amount)
	label.font_size = critical_font_size if info.is_critical else font_size
	label.modulate = critical_color if info.is_critical else normal_color
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	label.global_position = _origins[index]
	label.visible = true


func _process(delta: float) -> void:
	if _active_count == 0:
		return
	for index in pool_size:
		if _ages[index] < 0.0:
			continue
		_ages[index] += delta
		var label: Label3D = _labels[index]
		var t: float = _ages[index] / lifetime
		if t >= 1.0:
			_ages[index] = -1.0
			label.visible = false
			_active_count -= 1
			Diagnostics.active_effects -= 1
			continue
		var rise: float = 1.0 - (1.0 - t) * (1.0 - t)
		label.global_position = _origins[index] + Vector3.UP * rise_distance * rise
		var alpha: float = 1.0 - t * t
		label.modulate.a = alpha
		label.outline_modulate.a = alpha * 0.85
