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

func _on_start_button_pressed():
	get_tree().change_scene_to_file(HEX_MAP_SCENE)

func _on_continue_button_pressed():
	if load_game_state():
		get_tree().change_scene_to_file(TAVERN_SCENE)

func _on_quit_button_pressed():
	"""Quit game"""
	get_tree().quit()

func has_save_game() -> bool:
	"""Check if a save file exists"""
	return FileAccess.file_exists(SaveSystem.SAVE_FILE)

func load_game_state() -> bool:
	"""Load the game state"""
	var save_file = FileAccess.open("user://savegame.dat", FileAccess.READ)
	if save_file:
		# Load your game data here
		# For now, just close the file
		save_file.close()
		return true
	return false
