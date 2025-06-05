extends Node
class_name DialogueParser

# Dialogue data structure
var dialogue_data = {}
var current_node = "0"
var current_choices = []

# UI Components
var dialogue_box: RichTextLabel
var current_dialogue_lines = []
var current_line_index = 0
var is_displaying_dialogue = false

# Game state
var npc_reputations = {} # Dictionary to hold reputation for each NPC
var current_npc_id = ""
var memories = {
	"sad": {},
	"happy": {},
	"angry": {},
	"empty": {}
}

# NPC Color Configuration - Edit these in the editor!
@export var npc_color_overrides: Dictionary = {}
@export var default_speaker_color: Color = Color.YELLOW
@export var dialogue_text_color: Color = Color.BLACK

# Signals for UI updates
signal dialogue_updated(speaker: String, text: String)
signal choices_updated(choices: Array)
signal dialogue_ended()
signal line_displayed() # New signal for when a line finishes displaying
signal all_lines_complete() # New signal for when all lines in node are done

func _ready():
	# Initialize memory trees - each tree can hold multiple memories
	# memories["sad"]["0"] = false, memories["happy"]["1"] = true, etc.
	
	# Set up default NPC colors if none are configured
	if npc_color_overrides.is_empty():
		setup_default_colors()

# Set up some default NPC colors as examples
func setup_default_colors():
	npc_color_overrides = {
		"Bartender": Color.GREEN,
		"Hanna": Color.BLUE_VIOLET,
		"Owner": Color.REBECCA_PURPLE,
		"Venty": Color.MEDIUM_AQUAMARINE,
		"Waiter": Color.DARK_GREEN,
		"Old Lady": Color.DARK_ORANGE,
		"Mayor": Color.NAVY_BLUE
}

# Get color for a specific NPC name
func get_npc_color(npc_name: String) -> Color:
	# Case-insensitive lookup
	for key in npc_color_overrides.keys():
		if key.to_lower() == npc_name.to_lower():
			return npc_color_overrides[key]
	return default_speaker_color

# Add or update NPC color override
func set_npc_color(npc_name: String, color: Color):
	# Find existing key with case-insensitive match
	var existing_key = ""
	for key in npc_color_overrides.keys():
		if key.to_lower() == npc_name.to_lower():
			existing_key = key
			break
	
	if existing_key != "":
		# Update existing entry
		npc_color_overrides[existing_key] = color
	else:
		# Add new entry
		npc_color_overrides[npc_name] = color

# Remove NPC color override (will use default color)
func remove_npc_color(npc_name: String):
	# Find and remove key with case-insensitive match
	for key in npc_color_overrides.keys():
		if key.to_lower() == npc_name.to_lower():
			npc_color_overrides.erase(key)
			break

# Get all configured NPC names and their colors
func get_all_npc_colors() -> Dictionary:
	return npc_color_overrides.duplicate()

# Set up the dialogue box (call this from your scene)
func setup_dialogue_box(rich_text_label: RichTextLabel):
	dialogue_box = rich_text_label
	dialogue_box.bbcode_enabled = true
	dialogue_box.text = ""

# Parse the dialogue file
func parse_dialogue_file(file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Error: Could not open dialogue file: ", file_path)
		return false
	
	var content = file.get_as_text()
	file.close()
	
	return parse_dialogue_content(content)

# Parse dialogue content from string
func parse_dialogue_content(content: String) -> bool:
	dialogue_data.clear()
	var lines = content.split("\n")
	var current_node_id = ""
	var current_node_content = []
	
	for line in lines:
		line = line.strip_edges()
		if line.is_empty():
			continue
			
		# Check if this is a node header (e.g., "0::", "1::", etc.)
		if line.ends_with("::"):
			# Save previous node if it exists
			if current_node_id != "":
				dialogue_data[current_node_id] = parse_node_content(current_node_content)
			
			# Start new node
			current_node_id = line.substr(0, line.length() - 2)
			current_node_content = []
		else:
			# Add line to current node content
			current_node_content.append(line)
	
	# Save the last node
	if current_node_id != "":
		dialogue_data[current_node_id] = parse_node_content(current_node_content)
	
	print("Parsed ", dialogue_data.size(), " dialogue nodes")
	return true

# Parse individual node content
func parse_node_content(lines: Array) -> Dictionary:
	var node = {
		"dialogue": [],
		"choices": [],
		"commands": []
	}
	
	for line in lines:
		if line.begins_with(":choice_"):
			# Extract choice number and text
			var parts = line.split(": ", false, 1)
			var choice_id = parts[0].substr(1) # Remove the leading ':'
			var choice_text = parts[1] if parts.size() > 1 else "Sample choice text"
			node.choices.append({"id": choice_id, "text": choice_text})
		elif line.begins_with(":"):
			# This is a command - remove leading and trailing colons
			var command = line.substr(1) # Remove the leading ':'
			if command.ends_with(":"):
				command = command.substr(0, command.length() - 1) # Remove trailing ':'
			node.commands.append(command)
		else:
			# This is dialogue text
			if line.find(":") != -1:
				var parts = line.split(": ", false, 1)
				if parts.size() == 2:
					var speaker = parts[0]
					var text = parts[1]
					node.dialogue.append({"speaker": speaker, "text": text})
				else:
					node.dialogue.append({"speaker": "", "text": line})
			else:
				node.dialogue.append({"speaker": "", "text": line})
	
	return node

# Start dialogue from a specific node with NPC ID
func start_dialogue(node_id: String = "0", npc_id: String = "default"):
	current_node = node_id
	current_npc_id = npc_id
	
	# Initialize NPC reputation if it doesn't exist
	if not npc_reputations.has(npc_id):
		npc_reputations[npc_id] = 0
	
	display_current_node()

# Display the current dialogue node
func display_current_node():
	if not dialogue_data.has(current_node):
		print("Error: Node ", current_node, " not found!")
		return
	
	var node = dialogue_data[current_node]
	
	# Clear previous choices when entering a new node
	current_choices = []
	$"Dialogue Box".visible = false
	emit_signal("choices_updated", current_choices) # Send empty choices signal
	
	# Prepare dialogue lines for sequential display
	current_dialogue_lines = []
	for dialogue_line in node.dialogue:
		current_dialogue_lines.append(dialogue_line)
	
	# Start displaying dialogue line by line
	current_line_index = 0
	is_displaying_dialogue = true
	
	if current_dialogue_lines.size() > 0:
		display_current_line()
	else:
		# No dialogue lines, process commands and choices immediately
		finish_dialogue_display(node)

# Display the current dialogue line
func display_current_line():
	$TextureRect.visible = true
	if current_line_index >= current_dialogue_lines.size():
		return
	
	var dialogue_line = current_dialogue_lines[current_line_index]
	var formatted_text = format_dialogue_line(dialogue_line.speaker, dialogue_line.text)
	
	if dialogue_box:
		dialogue_box.text = formatted_text
	
	emit_signal("dialogue_updated", dialogue_line.speaker, dialogue_line.text)
	$"Dialogue Box".visible = true
	emit_signal("line_displayed")

# Progress to the next dialogue line (call this function to advance)
func progress_dialogue():
	if not is_displaying_dialogue:
		return false
	
	current_line_index += 1
	
	if current_line_index < current_dialogue_lines.size():
		# Show next line
		display_current_line()
		return true
	else:
		# All lines shown, finish dialogue display
		var node = dialogue_data[current_node]
		finish_dialogue_display(node)
		return false

# Finish displaying dialogue and process commands/choices
func finish_dialogue_display(node: Dictionary):
	is_displaying_dialogue = false
	
	# Process commands
	for command in node.commands:
		execute_command(command)
	
	# Set up choices
	if node.choices.size() > 0:
		current_choices = node.choices
		emit_signal("choices_updated", current_choices)
	else:
		# No choices means dialogue continues or ends
		if not node.commands.has("exit"):
			print("Warning: Node has no choices and no exit command")
	
	emit_signal("all_lines_complete")

# Format dialogue line for RichTextLabel with NPC-specific colors and black text
func format_dialogue_line(speaker: String, text: String) -> String:
	if speaker != "":
		var speaker_color = get_npc_color(speaker)
		var speaker_color_hex = "#" + speaker_color.to_html()
		var text_color_hex = "#" + dialogue_text_color.to_html()
		return "[color=" + speaker_color_hex + "]" + speaker + ":[/color] [color=" + text_color_hex + "]" + text + "[/color]"
	else:
		var text_color_hex = "#" + dialogue_text_color.to_html()
		return "[color=" + text_color_hex + "]" + text + "[/color]"

# Set the dialogue text color
func set_dialogue_text_color(color: Color):
	dialogue_text_color = color

# Get the current dialogue text color
func get_dialogue_text_color() -> Color:
	return dialogue_text_color

# Execute special commands
func execute_command(command: String):
	match command:
		"rep_positive":
			change_reputation(1)
		"rep_negative":
			change_reputation(-1)
		"exit":
			end_dialogue()
		_:
			if command.begins_with("memory_"):
				trigger_memory(command)
			else:
				print("Unknown command: ", command)

# Handle player choice selection
func select_choice(choice_index: int):
	if choice_index < 0 or choice_index >= current_choices.size():
		print("Error: Invalid choice index: ", choice_index)
		return
	
	var choice = current_choices[choice_index]
	var next_node = determine_next_node(choice.id)
	
	if next_node != "":
		current_node = next_node
		display_current_node()
	else:
		print("Error: Could not determine next node for choice: ", choice.id)

# Check if currently displaying dialogue line by line
func is_dialogue_in_progress() -> bool:
	return is_displaying_dialogue

# Skip to end of current dialogue node (show all remaining lines)
func skip_to_end_of_node():
	if not is_displaying_dialogue:
		return
	
	# Show all remaining dialogue lines at once
	var all_text = ""
	for i in range(current_dialogue_lines.size()):
		var dialogue_line = current_dialogue_lines[i]
		var formatted_line = format_dialogue_line(dialogue_line.speaker, dialogue_line.text)
		if i > 0:
			all_text += "\n\n"
		all_text += formatted_line
	
	if dialogue_box:
		dialogue_box.text = all_text
	
	# Finish the dialogue display
	var node = dialogue_data[current_node]
	finish_dialogue_display(node)

# Determine the next dialogue node based on choice
func determine_next_node(choice_id: String) -> String:
	# This maps choice IDs to next nodes based on your dialogue structure
	var base_node = current_node
	var choice_num = choice_id.replace("choice_", "")
	
	# Generate next node ID based on your dialogue structure
	var next_node = ""
	
	if base_node == "0":
		# From root node "0", choices lead directly to choice numbers: "1", "2", "3", "4"
		next_node = choice_num
	else:
		# For other nodes, append choice number: "1" + "1" = "11", "2" + "1" = "21", etc.
		next_node = base_node + choice_num
	
	# Check if the node exists
	if dialogue_data.has(next_node):
		return next_node
	else:
		print("Warning: Next node ", next_node, " does not exist")
		return ""

# Placeholder function for reputation changes
func change_reputation(amount: int):
	if current_npc_id == "":
		print("Warning: No current NPC set for reputation change")
		return
	
	npc_reputations[current_npc_id] += amount
	var current_rep = npc_reputations[current_npc_id]
	print("Reputation with ", current_npc_id, " changed by ", amount, ". Current reputation: ", current_rep)
	
	# You can add more complex reputation logic here
	if current_rep > 10:
		print("Player is well-liked by ", current_npc_id, "!")
	elif current_rep < -10:
		print("Player is disliked by ", current_npc_id, "!")

# Placeholder function for memory triggers
func trigger_memory(memory_command: String):
	print("Triggering memory: ", memory_command)
	
	# Extract memory type and ID (e.g., "memory_sad_0" -> emotion="sad", memory_id="0")
	var parts = memory_command.split("_")
	if parts.size() >= 3:
		var emotion = parts[1] # sad, happy, angry, empty
		var memory_id = parts[2] # 0, 1, 2, etc.
		
		# Validate emotion type
		if not memories.has(emotion):
			print("Warning: Unknown memory emotion: ", emotion)
			return
		
		# Unlock the memory in the appropriate tree
		memories[emotion][memory_id] = true
		print("Memory unlocked in ", emotion, " tree: ", memory_id)
		
		# Here you could trigger different effects based on memory tree
		match emotion:
			"happy":
				print("Playing happy memory flashback... (Positive emotional impact)")
			"sad":
				print("Playing sad memory flashback... (Melancholic emotional impact)")
			"angry":
				print("Playing angry memory flashback... (Intense emotional impact)")
			"empty":
				print("Playing empty memory flashback... (Void/neutral emotional impact)")

# Placeholder function for ending dialogue
func end_dialogue():
	var final_rep = npc_reputations.get(current_npc_id, 0)
	print("Dialogue with ", current_npc_id, " ended. Final reputation: ", final_rep)
	$TextureRect.visible = false
	dialogue_box.text = ""
	emit_signal("dialogue_ended")
	
	# Save game state, return to gameplay, etc.
	current_node = "0"
	current_choices.clear()
	current_npc_id = ""

# Utility functions
func get_npc_reputation(npc_id: String) -> int:
	return npc_reputations.get(npc_id, 0)

func get_current_npc_reputation() -> int:
	return npc_reputations.get(current_npc_id, 0)

func is_memory_unlocked(emotion: String, memory_id: String) -> bool:
	if not memories.has(emotion):
		return false
	return memories[emotion].get(memory_id, false)

func get_unlocked_memories_in_tree(emotion: String) -> Array:
	if not memories.has(emotion):
		return []
	
	var unlocked = []
	for memory_id in memories[emotion].keys():
		if memories[emotion][memory_id]:
			unlocked.append(memory_id)
	return unlocked

func get_all_unlocked_memories() -> Dictionary:
	var all_unlocked = {}
	for emotion in memories.keys():
		all_unlocked[emotion] = get_unlocked_memories_in_tree(emotion)
	return all_unlocked

func get_memory_tree_progress(emotion: String) -> Dictionary:
	if not memories.has(emotion):
		return {"unlocked": 0, "total": 0}
	
	var unlocked_count = 0
	var total_count = memories[emotion].size()
	
	for memory_id in memories[emotion].keys():
		if memories[emotion][memory_id]:
			unlocked_count += 1
	
	return {"unlocked": unlocked_count, "total": total_count}

# Debug function to print dialogue structure
func debug_print_dialogue():
	print("=== DIALOGUE DEBUG ===")
	for node_id in dialogue_data.keys():
		print("Node ", node_id, ":")
		var node = dialogue_data[node_id]
		for dialogue_line in node.dialogue:
			print("  ", dialogue_line.speaker, ": ", dialogue_line.text)
		for choice in node.choices:
			print("  Choice: ", choice.text)
		for command in node.commands:
			print("  Command: ", command)
		print("---")

# Additional utility functions for UI integration
func get_current_line_text() -> String:
	if current_line_index < current_dialogue_lines.size():
		var line = current_dialogue_lines[current_line_index]
		return format_dialogue_line(line.speaker, line.text)
	return ""

func get_progress_info() -> Dictionary:
	return {
		"current_line": current_line_index,
		"total_lines": current_dialogue_lines.size(),
		"is_displaying": is_displaying_dialogue
	}

# Get current available choices
func get_current_choices() -> Array:
	return current_choices

# Get a specific choice by index
func get_choice(index: int) -> Dictionary:
	if index >= 0 and index < current_choices.size():
		return current_choices[index]
	return {}

# Get choices as formatted strings for UI display
func get_choices_as_strings() -> Array:
	var choice_strings = []
	for i in range(current_choices.size()):
		var choice = current_choices[i]
		choice_strings.append(str(i + 1) + ". " + choice.text)
	return choice_strings

# Check if choices are available
func has_choices() -> bool:
	return current_choices.size() > 0
