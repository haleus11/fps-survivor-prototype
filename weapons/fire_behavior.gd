class_name FireBehavior
extends Resource
## Stratégie de tir d'une arme. Chaque type de tir (hitscan, projectile…) en hérite.


func fire(_weapon: Weapon) -> void:
	push_warning("FireBehavior.fire() doit être redéfini.")
