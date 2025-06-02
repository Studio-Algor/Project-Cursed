extends CharacterBody3D

@export_category("Stats")
@export var max_hp = 10
var hp: float
@export var max_speed = 10

@export var hit_particles_scene: PackedScene

@export_category("AI")
var player: Node3D
@onready var nav_agent = $NavigationAgent3D
@export var player_path: NodePath

@export_category("Debug")
@export var debug: bool

func _ready() -> void:
	player = get_node(player_path)
	hp = max_hp

func _process(_delta: float) -> void:
	velocity = Vector3.ZERO
	
	# Navigation
	nav_agent.set_target_position(player.global_transform.origin)
	var next_nav_point = nav_agent.get_next_path_position()
	velocity = (next_nav_point - global_transform.origin).normalized() * max_speed
	
	look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	
	if debug:
		print("Navigation: ")
		print("  Current Position: ", global_transform.origin)
		print("  Next Position:    ", next_nav_point)
	move_and_slide()



func take_damage(hit_position: Vector3, damage: float = 0):
	# Damage Calculations
	hp -= damage
	if debug:
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
	
	if debug: print("  Spawned Particles at: ", hit_particles.global_position)

func death():
	if debug: print("Enemy Died!")
	$"..".enemy_died()
	queue_free()  # Remove the enemy if HP is 0 or below
