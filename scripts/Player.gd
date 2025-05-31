extends CharacterBody3D

const SENSITIVITY = 0.003

# Speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 10.0
const SPEED_FACTOR = 1
const INERTIA_GROUND_MOVING = 7
const INERTIA_GROUND_STOPPING = 15
var max_speed

# Sliding & Jumping
const JUMP_VELOCITY = 4.5
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

# Capture in HTML5
func _input(event):
	if Input.is_action_just_pressed("ui_click"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Handle Sprint.
	if Input.is_action_pressed("ui_shift"):
		max_speed = SPRINT_SPEED
	else:
		max_speed = WALK_SPEED

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity = lerp(velocity, direction * max_speed, delta * INERTIA_GROUND_MOVING)
		else:
			velocity = lerp(velocity, Vector3.ZERO, delta * INERTIA_GROUND_STOPPING)
	else:
		# Falling
		velocity = lerp(velocity, direction * max_speed, delta * INERTIA_FALLING)
	
	# Head Bobbing
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	
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
