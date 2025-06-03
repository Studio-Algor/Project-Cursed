extends CharacterBody3D

@export_category("Stats")
@export var max_hp: float = 10
var hp: float
var is_attacking = false
@export var max_speed = 10
@export var melee_range = 1
@export var melee_damage = 10

@export var hit_particles_scene: PackedScene

@export_category("AI")
var player: Node3D
@onready var nav_agent = $NavigationAgent3D

@export_category("Debug")
@export var debug: bool

func _ready() -> void:
	player = $"../../Level Universal/Player"
	hp = max_hp

func _process(_delta: float) -> void:
	# Navigation
	if is_in_melee_range() and not is_attacking:
		if debug: print("Attacking the Player")
		queue_animation("melee")
	if not is_attacking: move_to_player()

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

func move_to_player():
	velocity = Vector3.ZERO
	nav_agent.set_target_position(player.global_transform.origin)
	var next_nav_point = nav_agent.get_next_path_position()
	velocity = (next_nav_point - global_transform.origin).normalized() * max_speed
	
	look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)

	if debug:
		print("Navigation: ")
		print("  Current Position: ", global_transform.origin)
		print("  Next Position:    ", next_nav_point)
	move_and_slide()

func queue_animation(animation_name: String) -> void:
	if animation_name == "melee":
			is_attacking = true
	for child in find_child("Animators").get_children(): if child is AnimatedSprite3D:
		child.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		child.play(animation_name)

func _on_animated_sprite_3d_animation_finished() -> void:
	for child in find_child("Animators").get_children(): if child is AnimatedSprite3D:
		child.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	# Finished the attack
	if is_in_melee_range(): player.take_damage(melee_damage)
	queue_animation("idle")
	is_attacking = false

func is_in_melee_range() -> bool:
	return (global_position - player.global_position).length() <= melee_range
