# main_menu.gd - Simple main menu for Eternal Guild
extends Control

# Path to your existing tavern scene
const TAVERN_SCENE = "res://scenes/MainTavern.tscn"
const ASCII_WORLD_SCENE = "res://scenes/world/ASCIIWorldSelection.tscn"

# UI References from your existing scene
@onready var start_button = $VBoxContainer/StartButton
@onready var continue_button = $VBoxContainer/ContinueButton
@onready var quit_button = $VBoxContainer/QuitButton

# Add a new button for procedural world
var procedural_button: Button

func _ready():
	print("Main Menu Ready")
	
	# Connect existing buttons
	start_button.pressed.connect(_on_start_button_pressed)
	continue_button.pressed.connect(_on_continue_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	
	# Add a new button for procedural world selection
	add_procedural_world_button()
	
	# Disable continue if no save exists
	continue_button.disabled = not has_save_game()

func add_procedural_world_button():
	"""Add a button for ASCII world selection between Start and Continue"""
	procedural_button = Button.new()
	procedural_button.text = "Choose Starting Location (ASCII Map)"
	
	# Insert it after the Start button
	var vbox = $VBoxContainer
	vbox.add_child(procedural_button)
	vbox.move_child(procedural_button, 2)  # Place it after Start button
	
	procedural_button.pressed.connect(_on_procedural_button_pressed)

func _on_start_button_pressed():
	"""Original start - goes directly to tavern"""
	print("Starting classic game...")
	get_tree().change_scene_to_file(TAVERN_SCENE)

func _on_procedural_button_pressed():
	"""New option - choose location on ASCII map first"""
	print("Opening ASCII world selection...")
	
	# Check if ASCII scene exists
	if not FileAccess.file_exists(ASCII_WORLD_SCENE):
		# If ASCII scene doesn't exist yet, just go to tavern
		print("ASCII scene not found, loading tavern directly")
		get_tree().change_scene_to_file(TAVERN_SCENE)
	else:
		# Load ASCII world selection
		get_tree().change_scene_to_file(ASCII_WORLD_SCENE)

func _on_continue_button_pressed():
	"""Continue saved game"""
	if load_game_state():
		get_tree().change_scene_to_file(TAVERN_SCENE)

func _on_quit_button_pressed():
	"""Quit game"""
	get_tree().quit()

func has_save_game() -> bool:
	"""Check if a save file exists"""
	return FileAccess.file_exists("user://savegame.dat")

func load_game_state() -> bool:
	"""Load the game state"""
	var save_file = FileAccess.open("user://savegame.dat", FileAccess.READ)
	if save_file:
		# Load your game data here
		# For now, just close the file
		save_file.close()
		return true
	return false
