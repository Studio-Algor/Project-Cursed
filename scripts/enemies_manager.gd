extends Node

signal spawning_finished

@export_category("Enemies")
@export var enemies_data: Array[EnemySpawnData]
@export_category("Debug")
@export var debug: bool = false

var spawn_thread: Thread
var mutex: Mutex
var spawning_complete: bool = false
var checking_enemies: bool = false
var enemy_check_timer: SceneTreeTimer

func _ready():
	spawn_enemies()

func spawn_enemies():
	if enemies_data.is_empty():
		if debug: print("No enemy data configured")
		return
	
	# Initialize threading components
	spawn_thread = Thread.new()
	mutex = Mutex.new()
	spawning_complete = false
	
	# Start spawning on separate thread
	spawn_thread.start(_spawn_enemies_threaded)
	
	if debug: print("Started enemy spawning on background thread")

func _spawn_enemies_threaded():
	var spawn_data: Array[Dictionary] = []
	
	# Calculate spawn positions on background thread
	for enemy_config in enemies_data:
		if not enemy_config or not enemy_config.scene:
			continue
		
		# Validate bounds before processing
		if enemy_config.position_bounds_min.x >= enemy_config.position_bounds_max.x or \
		   enemy_config.position_bounds_min.z >= enemy_config.position_bounds_max.z:
			if debug: print("Error: Invalid position bounds for enemy config - min >= max")
			continue
		
		# Calculate deadzone center for this enemy config
		var deadzone_center = (enemy_config.position_bounds_min + enemy_config.position_bounds_max) * 0.5
		
		if debug: 
			print("Processing enemy config:")
			print("  Bounds min: ", enemy_config.position_bounds_min)
			print("  Bounds max: ", enemy_config.position_bounds_max)
			print("  Deadzone center: ", deadzone_center)
			print("  Deadzone radius: ", enemy_config.deadzone_radius)
			print("  Amount to spawn: ", enemy_config.amount)
		
		for i in enemy_config.amount:
			# Initialize with a safe default position first
			var random_pos: Vector3 = Vector3(
				(enemy_config.position_bounds_min.x + enemy_config.position_bounds_max.x) * 0.5,
				(enemy_config.position_bounds_min.y + enemy_config.position_bounds_max.y) * 0.5,
				(enemy_config.position_bounds_min.z + enemy_config.position_bounds_max.z) * 0.5
			)
			
			var attempts = 0
			var max_attempts = 100
			var position_found = false
			
			# Keep generating positions until we find one outside the deadzone
			while attempts < max_attempts:
				var candidate_pos = Vector3(
					randf_range(enemy_config.position_bounds_min.x, enemy_config.position_bounds_max.x),
					randf_range(enemy_config.position_bounds_min.y, enemy_config.position_bounds_max.y),
					randf_range(enemy_config.position_bounds_min.z, enemy_config.position_bounds_max.z)
				)
				
				# Check if position is outside deadzone cylinder (only X and Z matter for cylinder)
				var horizontal_distance = Vector2(
					candidate_pos.x - deadzone_center.x,
					candidate_pos.z - deadzone_center.z
				).length()
				
				if horizontal_distance > enemy_config.deadzone_radius:
					random_pos = candidate_pos
					position_found = true
					break  # Position is valid, outside deadzone
				
				attempts += 1
			
			# If we couldn't find a valid position after max attempts, try to find one at bounds edges
			if not position_found:
				if debug: print("Warning: Could not find position outside deadzone after ", max_attempts, " attempts. Trying bounds edges.")
				
				# Try positions at the corners/edges of bounds
				var edge_positions = [
					Vector3(enemy_config.position_bounds_min.x, random_pos.y, enemy_config.position_bounds_min.z),
					Vector3(enemy_config.position_bounds_max.x, random_pos.y, enemy_config.position_bounds_min.z),
					Vector3(enemy_config.position_bounds_min.x, random_pos.y, enemy_config.position_bounds_max.z),
					Vector3(enemy_config.position_bounds_max.x, random_pos.y, enemy_config.position_bounds_max.z)
				]
				
				for edge_pos in edge_positions:
					var edge_distance = Vector2(
						edge_pos.x - deadzone_center.x,
						edge_pos.z - deadzone_center.z
					).length()
					
					if edge_distance > enemy_config.deadzone_radius:
						random_pos = edge_pos
						position_found = true
						break
				
				if not position_found:
					if debug: print("Warning: Even edge positions are inside deadzone. Check your deadzone radius vs bounds size.")
			
			if debug: print("Final spawn position for enemy ", i, ": ", random_pos)
			spawn_data.append({
				"scene": enemy_config.scene,
				"position": random_pos
			})
	
	# Thread-safe completion flag
	mutex.lock()
	spawning_complete = true
	mutex.unlock()
	
	# Schedule instantiation on main thread
	call_deferred("_instantiate_enemies", spawn_data)

func _instantiate_enemies(spawn_data: Array[Dictionary]):
	# This runs on the main thread for safe scene tree manipulation
	for data in spawn_data:
		var enemy_instance = data.scene.instantiate()
		add_child(enemy_instance)
		enemy_instance.global_position = data.position
		enemy_instance.add_to_group("Enemies")
		
		# Connect death signal if the enemy has one
		if enemy_instance.has_signal("died"):
			enemy_instance.died.connect(enemy_died)
		elif enemy_instance.has_method("connect_death_signal"):
			enemy_instance.connect_death_signal(enemy_died)
	
	if debug: print("Spawned ", spawn_data.size(), " enemies")
	
	# Emit signal that spawning is finished
	spawning_finished.emit()

func enemy_died() -> void:
	if checking_enemies:
		# Reset the timer if already checking
		if enemy_check_timer:
			enemy_check_timer = get_tree().create_timer(2.0)
		return
	
	checking_enemies = true
	enemy_check_timer = get_tree().create_timer(2.0)
	await enemy_check_timer.timeout # Wait for the check
	
	var children: Array[Node] = get_children()
	var all_enemies_dead: bool = true
	
	for child in children: 
		if child.is_in_group("Enemies"): 
			all_enemies_dead = false
			break
	
	if all_enemies_dead:
		if debug: print("No enemies left, loading next scene.")
		get_tree().root.get_child(0).load_next_level()
	else:
		if debug: print("Enemies remaining: ", count_enemies())
	
	checking_enemies = false

func count_enemies() -> int:
	var count = 0
	for child in get_children():
		if child.is_in_group("Enemies"):
			count += 1
	return count

func _exit_tree():
	# Clean up thread resources
	if spawn_thread and spawn_thread.is_started():
		spawn_thread.wait_to_finish()
	if mutex:
		mutex = null
