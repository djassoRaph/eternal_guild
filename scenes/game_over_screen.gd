extends CanvasLayer

@onready var color_rect = $ColorRect
@onready var message_label = $CenterContainer/VBoxContainer/MessageLabel
@onready var game_over = %GameOverScreen

func show_game_over(reason: String):
	visible = true
	get_tree().paused = true
	# Display the reason to player
	if message_label:
		message_label.text = reason

func _ready():
	print("GameOverScreen found: ", game_over != null)


func _on_main_menu_button_pressed() -> void:
	print("GameOverScreen found: ", game_over != null)
	print('Add code to return to main menu and remove data of current game.')
	pass # Replace with function body.
