extends CharacterBody3D

const SENSITIVITY = 0.003
var is_talking: bool = false

@export_category("Stats")
@export var max_hp: float
var hp: float

@export_category("Inventory")
@export var inventory_items: Array[PackedScene]
@export var inventory_amount: Array[int]
@export var item_held_index = 0
@export var throw_offset: Vector3 = Vector3.ZERO
@export var empty_hand_texture: CompressedTexture2D
var last_thrown_item: Node3D

# Speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 10.0
const SPEED_FACTOR = 1
const INERTIA_GROUND_MOVING = 7
const INERTIA_GROUND_STOPPING = 15
var max_speed

# Sliding & Jumping
const JUMP_VELOCITY = 5
const INERTIA_FALLING = 3
const SLIDE_FACTOR = 5

# Head bobbing
const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.3

# FOV
const BASE_FOV = 90
const FOV_CHANGE = 1.5

# Objects
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var footsteps: AudioStreamPlayer = $Footsteps

@export_category("Debug")
@export var debug: bool = false

func _ready() -> void:
	if inventory_amount[item_held_index] == 0: $"../HUD & Gun/Throwing/Item".texture = empty_hand_texture
	hp = max_hp

# Capture in HTML5
func _input(_event):
	if Input.is_action_just_pressed("ui_click") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
	if Input.is_action_just_pressed("ui_right_click") and inventory_amount[item_held_index] > 0 and $"../HUD & Gun/Throwing".is_idle and $"../HUD & Gun/Gun".is_idle:
		throw_current_item()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_talking:
		$Jump.play()
		velocity.y = JUMP_VELOCITY

	# Handle Sprint.
	if Input.is_action_pressed("ui_shift"):
		footsteps.pitch_scale = 1.5
		max_speed = SPRINT_SPEED
	else:
		footsteps.pitch_scale = 1
		max_speed = WALK_SPEED

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var moving_on_ground = input_dir.length() > 0 and is_on_floor() and not is_talking
	if footsteps.playing != moving_on_ground: footsteps.playing = moving_on_ground
	if is_on_floor():
		if direction and not is_talking:
			velocity = lerp(velocity, direction * max_speed, delta * INERTIA_GROUND_MOVING)
		else:
			velocity = lerp(velocity, Vector3.ZERO, delta * INERTIA_GROUND_STOPPING)
	else:
		# Falling
		velocity = lerp(velocity, direction * max_speed, delta * INERTIA_FALLING)
	
	# Head Bobbing
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob) * velocity.length() / max_speed
	
	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	 
	move_and_slide()

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(t_bob * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func _on_dialogue_handler_dialogue_ended() -> void:
	is_talking = false

func throw_current_item() -> void:
	$"../HUD & Gun/Throwing".queue_animation("throwing")
	inventory_amount[item_held_index] -= 1
	await get_tree().create_timer(.2).timeout # Throw delay
	last_thrown_item = inventory_items[item_held_index].instantiate()
	
	$"../Throwables".add_child(last_thrown_item)
	last_thrown_item.global_position = $Head.global_position

	last_thrown_item.throw(velocity, throw_offset)
	
	if inventory_amount[item_held_index] == 0: $"../HUD & Gun/Throwing/Item".texture = empty_hand_texture

func previous_item():
	if item_held_index > 0: item_held_index -= 1
	elif debug: print("Leftmost Item Already Selected")
	
func next_item():
	if item_held_index < inventory_items.size() - 1: item_held_index += 1
	elif debug: print("Rightmost Item Already Selected")

func take_damage(damage: float = 0):
	$Hit.play()
	# Damage Calculations
	hp -= damage
	if debug:
		print("Enemy Hit!")
		print("  Damage: ", damage)
		print("  Current HP: ", hp)
		print("  Position: ", global_position)
		
	if hp <= 0:
		death()
		
func death():
	pass
