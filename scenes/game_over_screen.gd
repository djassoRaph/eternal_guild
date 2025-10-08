# game_over_screen.gd
extends CanvasLayer

@onready var color_rect = $ColorRect
@onready var message_label = $ColorRect/CenterContainer/VBoxContainer/MessageLabel # FIX: Updated path to include ColorRect
@onready var game_over = %GameOverScreen

func show_game_over(reason: String):
	visible = true
	get_tree().paused = true
	# Display the reason to player
	if message_label:
		message_label.text = reason
		print("Displayed game over message: ", reason)
	else:
		print("ERROR: MessageLabel is null, cannot display game over message.")

func _ready():
	print("GameOverScreen found: ", game_over != null)
