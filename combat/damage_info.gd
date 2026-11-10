class_name DamageInfo
extends RefCounted
## Description d'un impact résolu : montant final, critique, position et auteur.

var amount: float = 0.0
var is_critical: bool = false
var position: Vector3 = Vector3.ZERO
var normal: Vector3 = Vector3.UP
var direction: Vector3 = Vector3.FORWARD
## Nœud à l'origine des dégâts (le joueur pour ses armes).
var source: Node = null
