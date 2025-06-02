extends Node

@export_category("Debug")
@export var debug: bool = false

func enemy_died() -> void:
	await get_tree().create_timer(2).timeout # Wait for the check
	var children: Array[Node] = get_children()
	var all_enemies_dead: bool = true
	for child in children: if child.is_in_group("Enemies"): all_enemies_dead = false
	
	if all_enemies_dead:
		if debug: print("No enemies left, loading next scene.")
		get_tree().root.get_child(0).load_next_level()
	else:
		if debug: print("Children: ", get_children())
