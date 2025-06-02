extends Control

var is_paused = false
var dialogue_parser: DialogueParser
var memory_descriptions = {}

@export_category("General")
@export var pause_on_startup = false

@export_category("Tabs")
@export var tabs: Array[Control]
var current_tab = 0

@export_category("Memory Texts")
@export var happy_memory_label: RichTextLabel
@export var sad_memory_label: RichTextLabel
@export var angry_memory_label: RichTextLabel
@export var empty_memory_label: RichTextLabel

@export_category("Debug")
@export var debug = false

func _ready() -> void:
	select_tab(current_tab)
	pause(pause_on_startup)
	
	# Find the DialogueParser in the scene
	dialogue_parser = find_dialogue_parser()
	if dialogue_parser:
		# Connect to dialogue parser signals if needed
		if not dialogue_parser.dialogue_ended.is_connected(_on_dialogue_ended):
			dialogue_parser.dialogue_ended.connect(_on_dialogue_ended)
	
	# Load memory descriptions
	load_memory_descriptions()
	
	# Update memory displays
	update_memory_displays()

func find_dialogue_parser() -> DialogueParser:
	# Try to find DialogueParser in common locations
	var parser = get_node_or_null("/root/DialogueParser")
	if parser:
		return parser
	
	# Search in the scene tree
	var nodes = get_tree().get_nodes_in_group("dialogue_parser")
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

func load_memory_descriptions():
	var file = FileAccess.open("res://dialogue/memories.txt", FileAccess.READ)
	if not file:
		print("Error: Could not open memories.txt file")
		return
	
	var content = file.get_as_text()
	file.close()
	
	# Parse the memory descriptions
	var lines = content.split("\n")
	for line in lines:
		line = line.strip_edges()
		if line.is_empty():
			continue
		
		var parts = line.split(": ", false, 1)
		if parts.size() == 2:
			var memory_id = parts[0]
			var description = parts[1]
			memory_descriptions[memory_id] = description

func _input(event: InputEvent) -> void:
	# Pausing
	if event.is_action_pressed("ui_cancel"):
		is_paused = not is_paused
		pause(is_paused)
	
	# Change Tab
	if event.is_action_pressed("ui_left"):
		current_tab -= 1
		if current_tab < 0:
			if debug: print("Already reached first tab")
			current_tab = 0
		select_tab(current_tab)
	if event.is_action_pressed("ui_right"):
		current_tab += 1
		if current_tab >= tabs.size():
			if debug: print("Already reached final tab")
			current_tab = tabs.size() - 1
		select_tab(current_tab)

func pause(paused: bool):
	if paused: 
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# Update memory displays when pausing
		update_memory_displays()
	else: 
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if debug: print("Game Paused")
	get_tree().paused = paused
	$"../HUD & Gun".visible = not paused
	visible = paused

func update_memory_displays():
	if not dialogue_parser:
		return
	
	# Update each emotion category
	update_emotion_memories("happy", happy_memory_label)
	update_emotion_memories("sad", sad_memory_label)
	update_emotion_memories("angry", angry_memory_label)
	update_emotion_memories("empty", empty_memory_label)

func update_emotion_memories(emotion: String, label: RichTextLabel):
	if not label or not dialogue_parser:
		return
	
	var unlocked_memories = dialogue_parser.get_unlocked_memories_in_tree(emotion)
	var memory_text = ""
	
	# Set emotion-specific header with color
	var emotion_color = get_emotion_color(emotion)
	var emotion_title = emotion.capitalize() + " Memories"
	memory_text = "[center][b][color=" + emotion_color + "]" + emotion_title + "[/color][/b][/center]\n\n"
	
	if unlocked_memories.size() == 0:
		memory_text += "[center][i]No memories unlocked yet...[/i][/center]"
	else:
		# Sort the unlocked memories by ID
		# unlocked_memories.sort()
		
		for memory_id in unlocked_memories:
			var memory_key = emotion + "_" + str(memory_id)
			if memory_descriptions.has(memory_key):
				var description = memory_descriptions[memory_key]
				memory_text += "- " + description + "\n\n"
	
	label.text = memory_text

func get_emotion_color(emotion: String) -> String:
	match emotion:
		"happy":
			return "#FFD700"  # Gold
		"sad":
			return "#4169E1"  # Royal Blue
		"angry":
			return "#DC143C"  # Crimson
		"empty":
			return "#708090"  # Slate Gray
		_:
			return "#FFFFFF"  # White

# Called when dialogue ends to refresh memory displays
func _on_dialogue_ended():
	if is_paused:
		update_memory_displays()

# Debug function to manually trigger memory unlock (for testing)
func debug_unlock_memory(emotion: String, memory_id: String):
	if dialogue_parser and debug:
		dialogue_parser.memories[emotion][memory_id] = true
		print("Debug: Unlocked memory ", emotion, "_", memory_id)
		update_memory_displays()

# Get memory progress for UI (optional)
func get_memory_progress(emotion: String) -> Dictionary:
	if dialogue_parser:
		return dialogue_parser.get_memory_tree_progress(emotion)
	return {"unlocked": 0, "total": 0}

# Get all memory progress (optional)
func get_all_memory_progress() -> Dictionary:
	var progress = {}
	for emotion in ["happy", "sad", "angry", "empty"]:
		progress[emotion] = get_memory_progress(emotion)
	return progress

func select_tab(index: int):
	if debug: print("Changed tab to index: ", index)
	for tab in tabs:
		tab.visible = false
	tabs.get(index).visible = true
