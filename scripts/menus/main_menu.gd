# main_menu.gd - Simple main menu for Eternal Guild
extends Control

const TAVERN_SCENE = "res://scenes/MainTavern.tscn"
const HEX_MAP_SCENE = "res://scenes/HexMapTest.tscn"

@onready var start_button = $VBoxContainer/StartButton
@onready var continue_button = $VBoxContainer/ContinueButton
@onready var quit_button = $VBoxContainer/QuitButton

func _ready():
	print("Main Menu Ready")
	start_button.pressed.connect(_on_start_button_pressed)
	continue_button.pressed.connect(_on_continue_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	continue_button.disabled = not has_save_game()
	_add_settings_button()


func _add_settings_button() -> void:
	# Settings button created in code, placed just above Quit
	var settings_button := Button.new()
	settings_button.text = "Settings"
	settings_button.pressed.connect(_on_settings_pressed)
	$VBoxContainer.add_child(settings_button)
	$VBoxContainer.move_child(settings_button, quit_button.get_index())


func _on_settings_pressed() -> void:
	add_child(preload("res://scripts/menus/settings_menu.gd").new())

func _on_start_button_pressed():
	# Guard against silently overwriting an existing save (Story 2.1)
	if has_save_game():
		var dialog = ConfirmationDialog.new()
		dialog.dialog_text = "You have a saved game.\nStarting a new game will overwrite it. Continue?"
		dialog.title = "Overwrite Save?"
		dialog.ok_button_text = "New Game"
		dialog.confirmed.connect(_start_new_game)
		dialog.canceled.connect(dialog.queue_free)
		add_child(dialog)
		dialog.popup_centered()
	else:
		_start_new_game()

func _start_new_game():
	# GameManager is an autoload — it holds state for the whole session. Wipe any in-memory
	# state from a prior game or Continue so a New Game never inherits the old day/gold/roster.
	GameManager.reset_game_state()
	get_tree().change_scene_to_file(HEX_MAP_SCENE)

func _on_continue_button_pressed():
	if SaveSystem.load_game():
		# Return the player to the scene they saved in (falls back to the tavern).
		var target = GameManager.saved_player_scene
		if target == "" or not ResourceLoader.exists(target):
			target = TAVERN_SCENE
		get_tree().change_scene_to_file(target)

func _on_quit_button_pressed():
	"""Quit game"""
	get_tree().quit()

func has_save_game() -> bool:
	"""Check if a save file exists"""
	return FileAccess.file_exists(SaveSystem.SAVE_FILE)
