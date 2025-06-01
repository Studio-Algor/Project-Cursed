extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_dialogue_handler_choices_updated(choices: Array) -> void:
	if choices.is_empty(): 
		$Middle.visible = false
		$"../Crosshair".visible = true
		for child in get_children():
			if child is RichTextLabel: child.text = ""
		return
	else:
		$Middle.visible = true
		$"../Crosshair".visible = false
		for choice in choices:
			$Middle.visible = true
			var box = find_child(choice.id)
			box.text = choice.text
