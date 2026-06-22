# game_over_screen.gd
extends CanvasLayer

@onready var color_rect = $ColorRect
@onready var game_over = %GameOverScreen
@onready var center_container = $CenterContainer
@onready var message_label = $ColorRect/CenterContainer/VBoxContainer/MessageLabel # FIX: Updated path to include ColorRect
@onready var main_menu_button = $CenterContainer/VBoxContainer/MainMenuButton

var fade_duration = 0.5

func _ready():
	# Start hidden
	visible = false
	color_rect.modulate.a = 0.0
	if main_menu_button and main_menu_button.has_signal("pressed"):
		main_menu_button.pressed.connect(_on_main_menu_button_pressed)
		print("Game Over button connected")
	else:
		print("Main menu button not found in game over screen")
	
	print("GameOverScreen initialized")


func show_game_over(reason: String):
	"""Display game over with fade to black effect"""
	print("GAME OVER: ", reason)
	
	# CRITICAL: Pause the game immediately
	get_tree().paused = true
	
	# Make overlay visible
	visible = true
	color_rect.visible = true
	center_container.visible = true
	
	# Set the failure message
	if message_label:
		message_label.text = "YOU LOST YOUR TAVERN\n\n" + reason + "\n\nClick below to return to main menu"
		print("Message set: ", message_label.text)
	
	# Fade to black animation
	await fade_to_black()
	
	# Show the message and button after fade
	center_container.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(center_container, "modulate:a", 1.0, 0.5)

func fade_to_black():
	"""Animate fade to black"""
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 0.95, fade_duration)
	await tween.finished

func _on_main_menu_button_pressed():
	"""Return to main menu"""
	print("Returning to main menu...")
	
	# Unpause the game before changing scenes
	get_tree().paused = false
	
	# Reset GameManager to clean state
	if GameManager and GameManager.has_method("reset_game_state"):
		GameManager.reset_game_state()
	
	# Change to main menu scene
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
