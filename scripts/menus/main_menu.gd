# MainMenu.gd - FIXED AND ENHANCED
extends Control

@onready var start_button = $VBoxContainer/StartButton
@onready var quit_button = $VBoxContainer/QuitButton
@onready var continue_button = $VBoxContainer/ContinueButton  # Fixed path


func _ready():
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	continue_button.pressed.connect(_on_continue_pressed)  # Fixed syntax
	
	# Show/hide continue button based on save file existence
	update_continue_button_visibility()

func update_continue_button_visibility():
	"""Show continue button only if save file exists"""
	if SaveSystem and SaveSystem.has_save_file():
		continue_button.visible = true
		continue_button.disabled = false
		
		# Optional: Show save info
		var save_info = SaveSystem.get_save_info()
		continue_button.text = "Continue (Day " + str(save_info.get("day", 1)) + ")"
	else:
		continue_button.visible = false

func _on_start_pressed():
	"""Start new game"""
	# Optional: Warn if save file exists
	if SaveSystem and SaveSystem.has_save_file():
		show_new_game_confirmation()
	else:
		start_new_game()

func _on_quit_pressed():
	get_tree().quit()

func _on_continue_pressed():
	"""Load existing save and continue game"""
	if SaveSystem and SaveSystem.load_game():
		# Load successful - go to main tavern scene
		get_tree().change_scene_to_file("res://scenes/MainTavern.tscn")
	else:
		# Load failed - show error
		show_error_message("Failed to load save file")

func start_new_game():
	"""Start fresh game"""
	# Reset GameManager to initial state
	if GameManager:
		GameManager.reset_game_state()
	
	get_tree().change_scene_to_file("res://scenes/MainTavern.tscn")

func show_new_game_confirmation():
	"""Confirm overwriting existing save"""
	var confirmation = ConfirmationDialog.new()
	confirmation.dialog_text = "Starting a new game will overwrite your existing save. Continue?"
	confirmation.title = "Overwrite Save?"
	confirmation.confirmed.connect(start_new_game)
	add_child(confirmation)
	confirmation.popup_centered()

func show_error_message(message: String):
	"""Show error dialog"""
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = message
	error_dialog.title = "Error"
	add_child(error_dialog)
	error_dialog.popup_centered()


func _on_continue_button_pressed() -> void:
	pass # Replace with function body.
