class_name SlopeBlock
extends StaticBody3D
## Relief praticable : tronc de pyramide (butte ou crête) aux pentes douces.
## Le maillage et la collision sont construits au chargement à partir des dimensions.
## Garder des pentes inférieures à 40° pour que le joueur et les ennemis puissent les gravir.

@export var base_size: Vector2 = Vector2(20.0, 20.0)
@export var top_size: Vector2 = Vector2(8.0, 8.0)
@export var height: float = 2.5
@export var material: Material

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()


func _ready() -> void:
	var bx: float = base_size.x * 0.5
	var bz: float = base_size.y * 0.5
	var tx: float = top_size.x * 0.5
	var tz: float = top_size.y * 0.5
	var b0 := Vector3(-bx, 0.0, -bz)
	var b1 := Vector3(bx, 0.0, -bz)
	var b2 := Vector3(bx, 0.0, bz)
	var b3 := Vector3(-bx, 0.0, bz)
	var t0 := Vector3(-tx, height, -tz)
	var t1 := Vector3(tx, height, -tz)
	var t2 := Vector3(tx, height, tz)
	var t3 := Vector3(-tx, height, tz)
	var center := Vector3(0.0, height * 0.5, 0.0)
	var faces: Array = [
		[t0, t1, t2, t3],
		[b0, b1, t1, t0],
		[b1, b2, t2, t1],
		[b2, b3, t3, t2],
		[b3, b0, t0, t3],
	]
	for face in faces:
		_add_quad(face, center)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material != null:
		mesh.surface_set_material(0, material)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([b0, b1, b2, b3, t0, t1, t2, t3])
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)


func _add_quad(quad: Array, center: Vector3) -> void:
	var centroid: Vector3 = (quad[0] + quad[1] + quad[2] + quad[3]) * 0.25
	_add_triangle(quad[0], quad[1], quad[2], centroid - center)
	_add_triangle(quad[0], quad[2], quad[3], centroid - center)


func _add_triangle(a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	# Godot considère comme face avant un triangle dont les sommets tournent dans le sens horaire vu de l'extérieur.
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.dot(outward) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	normal = normal.normalized()
	_vertices.append_array(PackedVector3Array([a, b, c]))
	_normals.append_array(PackedVector3Array([normal, normal, normal]))
