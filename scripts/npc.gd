extends Node3D

@export_category("Info")
@export var NPC_name: String = "Bartender"
@export var DLG_path: String = "res://dialogue/bartender.txt"
var is_talking: bool = false

@export_category("Debug")
@export var debug: bool = false

func _ready() -> void:
	pass

func talk() -> void:
	var player: CharacterBody3D = $"../../Player"
	if player.is_talking:
		return
	
	player.is_talking = true
	is_talking = true
	
	var dialogue_handler = $"../../Dialogue Handler"
	var dialogue_box: RichTextLabel = $"../../Dialogue Handler/Dialogue Box"
	dialogue_handler.setup_dialogue_box(dialogue_box)
	dialogue_handler.parse_dialogue_file(DLG_path)
	dialogue_handler.start_dialogue("0", NPC_name)

func _input(event: InputEvent) -> void:
	if not is_talking: return
	var dialogue_handler: DialogueParser = $"../../Dialogue Handler"
	var choices = dialogue_handler.current_choices
	
	var choice = 0
	if event.is_action_pressed("ui_left"): choice = 1
	if event.is_action_pressed("ui_up"): choice = 2
	if event.is_action_pressed("ui_right"): choice = 3
	if event.is_action_pressed("ui_down"): choice = 4
	
	if choice == 0: return
	if debug:
		print("Choices: ", choices)
		print("Selected choice: ", choice)
	dialogue_handler.select_choice(choice-1) # Minus One cause the choices start at 0

func _on_dialogue_handler_dialogue_ended() -> void:
	is_talking = false
