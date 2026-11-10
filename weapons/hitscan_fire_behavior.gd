class_name HitscanFireBehavior
extends FireBehavior
## Tir instantané : un rayon par projectile, avec la dispersion courante de l'arme.


func fire(weapon: Weapon) -> void:
	var data: WeaponData = weapon.data
	for _projectile in maxi(data.projectile_count, 1):
		var direction: Vector3 = weapon.get_spread_direction()
		var hit: Dictionary = weapon.cast_ray(direction, data.max_range)
		if hit.is_empty():
			continue
		weapon.process_hit(hit, direction, data.damage)
