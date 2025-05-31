extends Node3D


const RAY_LENGTH = 1000.0

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_click"):
		# Prepare the Ray
		var camera: Camera3D = $"../Head/Camera3D"
		var ro = camera.global_position
		var rd = camera.get_global_transform().basis.z * -1
		var rm = ro + rd * RAY_LENGTH
		
		# Shoot the ray
		var space_state = get_world_3d().direct_space_state
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
