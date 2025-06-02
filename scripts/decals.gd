extends Node3D

@export_category("Settings")
@export var decal_scene: PackedScene
@export var minimum_position: Vector3
@export var maximum_position: Vector3

@export var preserve_aspect_ratio: bool
@export var minimum_size: Vector2
@export var maximum_size: Vector2

@export var amount: int
@export var batch_size: int = 100  # Number of decals to spawn per batch

@export_category("Debug")
@export var debug = false

var thread: Thread
var mutex: Mutex
var semaphore: Semaphore
var should_exit: bool = false
var spawned_decals: Array[Node3D] = []

func _ready() -> void:
	if not decal_scene:
		push_error("Decal scene is not assigned!")
		return
	
	# Initialize threading objects
	thread = Thread.new()
	mutex = Mutex.new()
	semaphore = Semaphore.new()
	
	# Start the spawning process in a separate thread
	thread.start(_spawn_decals_threaded)

func _spawn_decals_threaded() -> void:
	var decals_created: int = 0
	var batch_decals: Array[Node3D] = []
	
	while decals_created < amount and not should_exit:
		# Calculate how many decals to create in this batch
		var remaining: int = amount - decals_created
		var current_batch_size: int = min(batch_size, remaining)
		
		# Create decals in batches to avoid UI freezing
		for i in range(current_batch_size):
			if should_exit:
				break
				
			var decal: MeshInstance3D = decal_scene.instantiate()
			
			# Generate random position uniformly between min and max
			var pos: Vector3 = Vector3(
				randf_range(minimum_position.x, maximum_position.x),
				randf_range(minimum_position.y, maximum_position.y),
				randf_range(minimum_position.z, maximum_position.z)
			)
			
			# Generate random size uniformly between min and max
			var size: Vector2
			if not preserve_aspect_ratio: size = Vector2(
				randf_range(minimum_size.x, maximum_size.x),
				randf_range(minimum_size.y, maximum_size.y),
			)
			else: size = Vector2.ONE * randf_range(minimum_size.x, maximum_size.x)
			
			pos.y += size.y / 2
			decal.position = pos
			decal.mesh = decal.mesh.duplicate()
			decal.mesh.size = size
			
			if debug:
				print("Decals: ")
				print("  Position: ", decal.position)
				print("  Sizes")
			
			
			batch_decals.append(decal)
		
		# Add the batch to the scene tree on the main thread
		if not batch_decals.is_empty():
			call_deferred("_add_decals_to_scene", batch_decals.duplicate())
			batch_decals.clear()
		
		decals_created += current_batch_size
		
		# Small delay to prevent overwhelming the system
		if decals_created < amount:
			OS.delay_msec(1)
	
	# Signal completion
	call_deferred("_on_spawning_complete")

func _add_decals_to_scene(decals: Array[Node3D]) -> void:
	mutex.lock()
	for decal in decals:
		add_child(decal)
		spawned_decals.append(decal)
	mutex.unlock()

func _on_spawning_complete() -> void:
	if debug: print("Finished spawning ", spawned_decals.size(), " decals")

func _exit_tree() -> void:
	# Clean up threading resources
	should_exit = true
	
	if thread and thread.is_started():
		thread.wait_to_finish()
	
	if mutex:
		mutex = null
	if semaphore:
		semaphore = null

# Utility function to get spawn progress (thread-safe)
func get_spawn_progress() -> float:
	if amount == 0:
		return 1.0
	
	mutex.lock()
	var progress: float = float(spawned_decals.size()) / float(amount)
	mutex.unlock()
	
	return progress

# Function to stop spawning early if needed
func stop_spawning() -> void:
	should_exit = true
