extends Control

@export var levels: Array[PackedScene]
@export var level_intro_strings: Array[String]
@export var instant_loading_screen: bool = false
var level_index = 0
var current_level: Node

func _ready() -> void:
	load_next_level()

# Called when the node enters the scene tree for the first time.
func load_next_level() -> void:
	# Deload previous one
	if current_level != null: current_level.queue_free()
	
	# Set up visuals and play audio
	$"Loading Screen".visible = true
	set_loading_screen_text(level_intro_strings.get(level_index))
	if not instant_loading_screen:
		$"Loading Screen/Transition".play()
		await get_tree().create_timer(2).timeout
		$"Loading Screen/Transition".stop()
		
	# Load next one
	if not instant_loading_screen: await get_tree().create_timer(.5).timeout
	current_level = levels.get(level_index).instantiate()
	add_child(current_level)
	var enemies: Node = current_level.find_child("Enemies")
	if enemies:
		enemies.spawn_enemies()
	
	# Wrap up
	level_index += 1
	$"Loading Screen".visible = false

func set_loading_screen_text(text: String) -> void:
	if text == null: text = ""
	var children: Array[Node] = $"Loading Screen".get_children()
	for child in children: if child is RichTextLabel: child.text = text
