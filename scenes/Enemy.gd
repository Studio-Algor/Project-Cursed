extends Node3D

@export var max_hp = 10
var hp: float

func _ready() -> void:
	hp = max_hp

func take_damage(damage: float = 0):
	hp -= damage
	print("Enemy Hit!")
	print("  Damage: ", damage)
	print("  Current HP: ", hp)
	
	if hp <= 0:
		death()

func death():
	print("Enemy Died!")
	queue_free()  # Remove the enemy if HP is 0 or below
