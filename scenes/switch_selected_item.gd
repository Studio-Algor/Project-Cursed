extends Control

@export var idle_position: Vector2 = Vector2(240, -217)
var is_throwing: bool = false
var is_idle = true

@export_category("Debug")
@export var debug: bool = false

func _ready() -> void:
	$Item.visible = is_idle
	queue_animation("idle")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_previous_weapon"): $"../../Player".previous_item()
	if event.is_action_pressed("ui_next_weapon"): $"../../Player".next_item()

func queue_animation(animation_name: String) -> void:
	for child in get_children(): if child is AnimatedSprite2D:
		var animator: AnimatedSprite2D = child
		if animation_name == "throwing":
			animator.position = Vector2(340, -120)
			$Item.visible = false
			is_idle = false
		if animation_name == "idle": animator.position = idle_position
		animator.play(animation_name)

func _on_hand_bottom_animation_finished() -> void:
	# Play idle animation when another animation finishes
	for child in get_children(): if child is AnimatedSprite2D:
		var animator: AnimatedSprite2D = child
		if debug: print("Going Back to Idle for Hand")
		animator.position = idle_position
		animator.visible = true
		animator.play("idle")
		is_idle = true
		$Item.visible = true

func _on_hand_top_animation_finished() -> void:
	$"Hand (Top)".visible = false
	$"Hand (Top)2".visible = false
	$"Hand (Top)3".visible = false
