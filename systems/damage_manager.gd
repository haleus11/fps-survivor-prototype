extends Node
## Point central de résolution des dégâts : tirage critique, application, diffusion des événements.
## Les critiques ne dépendent jamais de la zone touchée.

signal hit_landed(target: Node, info: DamageInfo, killed: bool)
signal surface_hit(at: Vector3, normal: Vector3)

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func create_hit(base_damage: float, stats: PlayerStats, source: Node) -> DamageInfo:
	var info := DamageInfo.new()
	var damage_multiplier: float = 1.0
	var crit_chance: float = 0.0
	var crit_multiplier: float = 1.0
	if stats != null:
		damage_multiplier = stats.damage_multiplier
		crit_chance = stats.crit_chance
		crit_multiplier = stats.crit_multiplier
	info.amount = base_damage * damage_multiplier
	info.is_critical = _rng.randf() < crit_chance
	if info.is_critical:
		info.amount *= crit_multiplier
	info.source = source
	return info


## Applique les dégâts à une cible exposant apply_damage(info) -> bool. Retourne true si elle meurt.
func apply_hit(target: Node, info: DamageInfo) -> bool:
	if target == null or not target.has_method("apply_damage"):
		return false
	var killed: bool = target.call("apply_damage", info)
	hit_landed.emit(target, info, killed)
	return killed


func report_surface_hit(at: Vector3, normal: Vector3) -> void:
	surface_hit.emit(at, normal)
