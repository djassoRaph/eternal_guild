extends Node2D


func _ready():
	var test_screen = get_node("GameUI/GameOverScreen")
	print("GameOverScreen found: ", test_screen != null)
