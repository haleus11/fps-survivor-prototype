class_name PlayerProgress
extends Node
## XP, crédits et éliminations de la partie en cours (le Level-Up arrivera au jalon 5).

signal xp_changed(total: int)
signal credits_changed(total: int)

var xp: int = 0
var credits: int = 0
var kills: int = 0


func add_kill_rewards(xp_amount: int, credit_amount: int) -> void:
	kills += 1
	add_xp(xp_amount)
	add_credits(credit_amount)


func add_xp(amount: int) -> void:
	xp += amount
	xp_changed.emit(xp)


func add_credits(amount: int) -> void:
	credits += amount
	credits_changed.emit(credits)
