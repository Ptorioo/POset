extends Node2D

var level_button_scene = preload("res://LevelButton.tscn")
@onready var grid = $"CanvasLayer/ScrollContainer/GridContainer"

func _ready():
	for i in range(1, 31): # 1 to 15
		var btn = level_button_scene.instantiate()
		grid.add_child(btn)
		btn.set_level(i)
		btn.get_children()[0].pressed.connect(_on_level_selected.bind(i))
		print("what")

func _on_level_selected(level_num):
	var game_scene = load("res://game.tscn")
	var new_scene = game_scene.instantiate()

	new_scene.current_level = level_num 

	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	queue_free()
