extends Node3D

@export_category("Info")
@export var NPC_name: String = "Bartender"
@export var DLG_path: String = "dialogue/bartender.txt"
var is_talking: bool = false
var dialogue_parser: DialogueParser

@export_category("Debug")
@export var debug: bool = false

func _ready() -> void:
	reset_dp_connection()
	
func find_dialogue_parser() -> DialogueParser:
	# Try to find DialogueParser in common locations
	var parser = get_node_or_null("/root/DialogueParser")
	if parser:
		return parser
	
	# Search in the scene tree
	var nodes = get_tree().get_nodes_in_group("Dialogue Parser")
	if nodes.size() > 0:
		return nodes[0]
	
	# Try to find it as a child of the main scene
	var main_scene = get_tree().current_scene
	if main_scene:
		for child in main_scene.get_children():
			if child is DialogueParser:
				return child
	
	print("Warning: DialogueParser not found!")
	return null

func talk() -> void:
	var player: CharacterBody3D = get_tree().get_nodes_in_group("Player")[0]
	if player.is_talking:
		return
	
	player.is_talking = true
	is_talking = true
	
	reset_dp_connection()
	var dialogue_box: RichTextLabel = dialogue_parser.find_child("Dialogue Box")
	dialogue_parser.setup_dialogue_box(dialogue_box)
	dialogue_parser.parse_dialogue_file(DLG_path)
	dialogue_parser.start_dialogue("0", NPC_name)

func _input(event: InputEvent) -> void:
	if not is_talking: return
	var choices = dialogue_parser.current_choices
	
	var choice = 0
	if event.is_action_pressed("ui_left"): choice = 1
	if event.is_action_pressed("ui_up"): choice = 2
	if event.is_action_pressed("ui_right"): choice = 3
	if event.is_action_pressed("ui_down"): choice = 4
	
	if choice == 0: return
	if debug:
		print("Choices: ", choices)
		print("Selected choice: ", choice)
	dialogue_parser.select_choice(choice-1) # Minus One cause the choices start at 0

func _on_dialogue_ended() -> void:
	is_talking = false

func reset_dp_connection() -> void:
	dialogue_parser = find_dialogue_parser()
	if not dialogue_parser.dialogue_ended.is_connected(_on_dialogue_ended):
		dialogue_parser.dialogue_ended.connect(_on_dialogue_ended)
