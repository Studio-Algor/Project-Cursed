extends Node3D

@export var NPC_name: String = "Bartender"
@export var DLG_path: String = "res://dialogue/bartender.dlg"
var is_talking: bool = false

func _ready() -> void:
	talk()

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
