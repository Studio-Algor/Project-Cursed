extends Control

@export var levels: Array[PackedScene]
@export var instant_loading_screen: bool = false
var level_index = 0
var current_level: Node

func _ready() -> void:
	load_next_level()

# Called when the node enters the scene tree for the first time.
func load_next_level() -> void:
	$"Loading Screen".visible = true
	if current_level != null: current_level.queue_free()
	if not instant_loading_screen: await get_tree().create_timer(2).timeout
	current_level = levels.get(level_index).instantiate()
	add_child(current_level)
	level_index += 1
	$"Loading Screen".visible = false
