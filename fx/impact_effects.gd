class_name ImpactEffects
extends Node3D
## Étincelles d'impact (décor et cibles). Pool fixe de MeshInstance3D partageant un seul mesh.

@export var pool_size: int = 32
@export var lifetime: float = 0.14
@export var size: float = 0.12
@export var surface_color: Color = Color(1.0, 0.85, 0.5)
@export var target_color: Color = Color(1.0, 0.35, 0.3)

var _instances: Array[MeshInstance3D] = []
var _ages := PackedFloat32Array()
var _next_index: int = 0
var _active_count: int = 0
var _surface_material := StandardMaterial3D.new()
var _target_material := StandardMaterial3D.new()


func _ready() -> void:
	for material in [_surface_material, _target_material]:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_surface_material.albedo_color = surface_color
	_target_material.albedo_color = target_color
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	_ages.resize(pool_size)
	for index in pool_size:
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visible = false
		add_child(instance)
		_instances.append(instance)
		_ages[index] = -1.0
	DamageManager.surface_hit.connect(_on_surface_hit)
	DamageManager.hit_landed.connect(_on_hit_landed)


func _on_surface_hit(at: Vector3, normal: Vector3) -> void:
	_spawn(at + normal * 0.02, _surface_material)


func _on_hit_landed(_target: Node, info: DamageInfo, _killed: bool) -> void:
	_spawn(info.position, _target_material)


func _spawn(at: Vector3, material: Material) -> void:
	var index: int = _next_index
	_next_index = (_next_index + 1) % pool_size
	if _ages[index] < 0.0:
		_active_count += 1
		Diagnostics.active_effects += 1
	_ages[index] = 0.0
	var instance: MeshInstance3D = _instances[index]
	instance.material_override = material
	instance.global_position = at
	instance.scale = Vector3.ONE * size
	instance.visible = true


func _process(delta: float) -> void:
	if _active_count == 0:
		return
	for index in pool_size:
		if _ages[index] < 0.0:
			continue
		_ages[index] += delta
		var instance: MeshInstance3D = _instances[index]
		var t: float = _ages[index] / lifetime
		if t >= 1.0:
			_ages[index] = -1.0
			instance.visible = false
			_active_count -= 1
			Diagnostics.active_effects -= 1
			continue
		instance.scale = Vector3.ONE * maxf(size * (1.0 - t), 0.005)
