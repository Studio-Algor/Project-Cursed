extends Control

@export var idle_position = Vector2(-141, -272)
@export var max_bullets = 6
var current_bullets = max_bullets
var is_idle = true 

@export_category("Debug")
@export var debug = false
const RAY_LENGTH = 1000.0

func _ready() -> void:
	queue_animation("idle")

func _physics_process(delta: float) -> void:
	if is_idle and Input.is_action_just_pressed("ui_click"):
		if current_bullets > 0:
			shoot()
		else:
			reload()
			
	if is_idle and current_bullets < max_bullets and Input.is_action_just_pressed("ui_reload"):
		reload()


func queue_animation(animation_name: String) -> void:
	var animator: AnimatedSprite2D = $AnimatedSprite2D
	if animation_name == "shoot": animator.position = Vector2(18, -38)
	if animation_name == "reload": animator.position = Vector2(5, -22)
	if animation_name == "idle": animator.position = idle_position
	animator.play(animation_name)

func _on_animated_sprite_2d_animation_finished() -> void:
	# Play idle animation when another animation finishes
	var animator: AnimatedSprite2D = $AnimatedSprite2D
	if debug: print("Going Back to Idle")
	animator.position = idle_position
	animator.play("idle")
	is_idle = true

func shoot():
	is_idle = false
	current_bullets -= 1
	queue_animation("shoot")
	
	# Prepare the Ray
	var camera: Camera3D = $"../../Player/Head/Camera3D"
	var ro = camera.global_position
	var rd = camera.get_global_transform().basis.z * -1
	var rm = ro + rd * RAY_LENGTH
	
	# Shoot the ray
	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ro, rm)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = (1 << 32) - 1
	query.collision_mask &= ~(1 << 1)
	var result: Dictionary = space_state.intersect_ray(query)
	
	# Check if it hit an enemy
	var is_enemy
	if not result.is_empty():
		is_enemy = result.collider.is_in_group("Enemies")
	if is_enemy:
		result.collider.take_damage(result.position, 1)

func reload():
	is_idle = false
	current_bullets = max_bullets
	queue_animation("reload")
