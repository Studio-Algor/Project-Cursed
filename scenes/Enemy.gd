extends Node3D

@export var max_hp = 10
var hp: float

@export var hit_particles_scene: PackedScene

func _ready() -> void:
	hp = max_hp

func take_damage(hit_position: Vector3, damage: float = 0):
	# Damage Calculations
	hp -= damage
	print("Enemy Hit!")
	print("  Damage: ", damage)
	print("  Current HP: ", hp)
	print("  Position: ", global_position)
	
	# Effects
	spawn_particles(hit_position)
	
	if hp <= 0:
		death()

func spawn_particles(hit_position: Vector3):
	var hit_particles: Node3D = hit_particles_scene.instantiate()
	$"..".add_child(hit_particles)
	hit_particles.global_position = hit_position
	var particles = hit_particles.find_children("*", "CPUParticles3D")
	for particle in particles:
		particle.emitting = true
	
	print("  Spawned Particles at: ", hit_particles.global_position)

func death():
	print("Enemy Died!")
	queue_free()  # Remove the enemy if HP is 0 or below
