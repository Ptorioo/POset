extends Node2D

@export var level = 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_pressed() -> void:
	# 1. Load and create the game scene
	var game_scene = load("res://game.tscn")
	var game_instance = game_scene.instantiate()
	
	game_instance.current_level = level

	# 2. Hide all existing subnodes
	for child in get_children():
		if child is CanvasItem:
			child.hide()
			
	# 3. Add the game loop as a child of the root node
	add_child(game_instance)

func _on_return() -> void:
	for child in get_children():
		if child is CanvasItem:
			child.hide()
	
