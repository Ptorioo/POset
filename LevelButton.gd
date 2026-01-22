# LevelButton.gd
extends Control

var level_number = 1
var unlocked = 1

func set_level(num):
	var level_number = num
	$"start/RichTextLabel".text = "Lv. " + str(num)
	
	print("init")
	# Check if level is locked (example logic)
	# if num > unlocked:
	# 	 disabled = true
		
