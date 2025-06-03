extends Node3D

@export_category("Stats")
@export var direct_damage: float = 0
@export var throwing_speed: float = 10.0  # Added default value
@export var is_affected_by_gravity: bool = true
@export var explosion_damage: float = 0

@export_category("Sizes")
@export var direct_radius: float = .2
@export var explosion_radius: float = 5

var bodies_entered: Array[Node3D]

@export_category("Debug")
@export var debug: bool = false

var has_exploded: bool = false
var velocity: Vector3 = Vector3.ZERO
var gravity: float = 9.8
var is_thrown: bool = false

func _ready():
	if debug: print("Throwable initialized: ", self.name)
	$Mesh.mesh.size = Vector2.ONE * direct_radius * 2
	$Direct/DH.shape.radius = direct_radius * 2
	$Explosion/EH.shape.radius = explosion_radius
	$Explosion/GPUParticles3D.one_shot = false
	$Explosion/GPUParticles3D.emitting = false
	$Explosion/GPUParticles3D.scale = Vector3.ONE * explosion_radius / 2

func _process(delta: float) -> void:
	if has_exploded:
		return
	
	# Only move if the object has been thrown
	if not is_thrown:
		return
	
	# Apply gravity if enabled
	if is_affected_by_gravity:
		velocity.y -= gravity * delta
	
	# Apply movement
	global_position += velocity * delta

func _on_direct_body_entered(body: Node3D) -> void:
	if has_exploded:
		return
		
	if debug: print("Direct Hit on Throwable: ", self.name, " hit ", body.name)
	
	# Apply direct damage
	if direct_damage > 0 and body.has_method("take_damage"):
		body.take_damage(global_position, direct_damage)
		if debug: print("Applied direct damage: ", direct_damage, " to ", body.name)
	
	# Trigger explosion
	if explosion_damage > 0:
		explode()
	else:
		# If no explosion, just remove the throwable
		queue_free()

func _on_explosion_body_entered(body: Node3D) -> void:
	bodies_entered.append(body)
	if not has_exploded: 
		return
		
	if debug: print("Explosion Hit on Throwable: ", self.name, " hit ", body.name)
	
	# Apply explosion damage
	if explosion_damage > 0 and body.has_method("take_damage"):
		body.take_damage(global_position, explosion_damage)
		if debug: print("Applied explosion damage: ", explosion_damage, " to ", body.name)

func set_direction(new_direction: Vector3):
	var normalized_direction = new_direction.normalized()
	velocity = normalized_direction * throwing_speed
	is_thrown = true
	if debug: print("Direction set to: ", normalized_direction, " with speed: ", throwing_speed)

func explode():
	"""Manually trigger explosion"""
	if has_exploded:
		return
		
	$Mesh.visible = false
	$Explosion/GPUParticles3D.one_shot = true
	$Explosion/GPUParticles3D.emitting = true
	if debug: print("Manual explosion triggered on: ", self.name)
	for body in bodies_entered:
		if body.is_in_group("Enemies"):
			if debug: print("Applied explosion damage: ", explosion_damage, " to ", body.name)
			body.take_damage(body.global_position, explosion_damage)
	has_exploded = true
	velocity = Vector3.ZERO

func _on_explosion_finished():
	"""Called when explosion animation/effect is complete"""
	if debug: print("Explosion finished, removing throwable: ", self.name)
	queue_free()

func throw(player_velocity: Vector3 = Vector3.ZERO, throw_offset: Vector3 = Vector3.ZERO):
	# More robust way to get the camera
	var player_nodes = get_tree().get_nodes_in_group("Player")
	if player_nodes.size() == 0:
		if debug: print("No player found in group 'Player'")
		return
	
	var player = player_nodes[0]
	var head = player.find_child("Head")
	if not head:
		if debug: print("Head node not found in player")
		return
	
	var camera = head.find_child("Camera3D")
	if not camera:
		if debug: print("Camera3D not found in head")
		return
	
	# Get the forward direction from camera
	var throw_direction = -camera.get_global_transform().basis.z
	
	# Calculate throw position using camera's transform and offset
	var camera_transform = camera.get_global_transform()
	var throw_position = camera_transform.origin + camera_transform.basis * throw_offset
	
	# Set the item's position to the calculated throw position
	global_position = throw_position
	
	# Set initial velocity with throw direction and speed
	velocity = throw_direction * throwing_speed + player_velocity
	is_thrown = true
	
	if debug:
		print("Thrown from position: ", throw_position)
		print("Thrown with direction: ", throw_direction)
		print("Final velocity: ", velocity)

func _on_explosion_body_exited(body: Node3D) -> void:
	if bodies_entered.has(body): bodies_entered.erase(body)
