extends CanvasLayer

@onready var color_rect = $ColorRect
@onready var message_label = $CenterContainer/VBoxContainer/MessageLabel  # You'll need to add these UI nodes

func show_game_over(reason: String):
	visible = true
	get_tree().paused = true
	# Display the reason to player
	if message_label:
		message_label.text = reason

func _ready():
	var test_screen = get_node("GameUI/GameOverScreen")
	print("GameOverScreen found: ", test_screen != null)
