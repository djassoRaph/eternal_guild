# pause_menu.gd - COMPLETE PAUSE MENU WITH SAVE/LOAD
extends CanvasLayer

@onready var main_menu_button = $VBoxContainer/MainMenuButton
@onready var load_button = $VBoxContainer/Load
@onready var save_button = $VBoxContainer/Save
@onready var save_exit_button = $VBoxContainer/"Save&Exit"
@onready var quit_button = $VBoxContainer/QuitButton

func _ready():
	# Start hidden
	visible = false

	# Connect buttons
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
		print("✅ Main Menu button connected")
	else:
		print("⚠️ Main Menu button not found")
		
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
		print("✅ Load button connected")
	else:
		print("⚠️ Load button not found")
		
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
		print("✅ Save button connected")
	else:
		print("⚠️ Save button not found")
		
	if save_exit_button:
		save_exit_button.pressed.connect(_on_save_exit_pressed)
		print("✅ Save & Exit button connected")
	else:
		print("⚠️ Save & Exit button not found")
		
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
		print("✅ Quit button connected")
	else:
		print("⚠️ Quit button not found")
	
	print("Pause menu initialized with all buttons")
	

func find_button_by_text(button_text: String) -> Button:
	"""Recursively find a button by its text"""
	return _search_for_button(self, button_text)


func _search_for_button(node: Node, button_text: String) -> Button:
	"""Helper function to recursively search for button"""
	if node is Button and node.text == button_text:
		return node
	
	for child in node.get_children():
		var result = _search_for_button(child, button_text)
		if result:
			return result
	
	return null


func _input(event):
	"""Toggle pause menu with ESC key"""
	if event.is_action_pressed("ui_cancel") and not get_tree().paused:
		toggle_pause()

func toggle_pause():
	"""Toggle pause state"""
	visible = !visible
	get_tree().paused = visible
	
	if visible:
		print("⏸️ Game paused")
	else:
		print("▶️ Game resumed")

func _on_main_menu_pressed():
	"""Return to main menu with confirmation"""
	print("🏠 Main Menu button pressed")
	show_confirmation(
		"Return to main menu? Any unsaved progress will be lost.",
		_return_to_main_menu
	)

func _on_load_pressed():
	"""Load game from save file"""
	print("📂 Load button pressed")
	
	if not SaveSystem:
		show_message("❌ Save system not available")
		return
	
	if not SaveSystem.has_save_file():
		show_message("❌ No save file found!")
		return
	
	show_confirmation(
		"Load saved game?\nCurrent progress will be lost.",
		_load_game
	)

func _on_save_pressed():
	"""Save current game"""
	print("💾 Save button pressed")
	
	if not SaveSystem:
		show_message("❌ Save system not available")
		return
	
	var success = SaveSystem.save_game()
	if success:
		show_message("✅ Game saved successfully!")
		# Close pause menu after a short delay
		await get_tree().create_timer(1.0).timeout
		if visible:  # Only close if still open
			toggle_pause()
	else:
		show_message("❌ Failed to save game")


func _on_save_exit_pressed():
	"""Save and exit to main menu"""
	print("💾🏠 Save & Exit pressed")
	
	if SaveSystem:
		var success = SaveSystem.save_game()
		if success:
			show_message("✅ Game saved!")
			await get_tree().create_timer(1.0).timeout
			_return_to_main_menu()
		else:
			show_message("❌ Failed to save game\nReturning to menu anyway...")
			await get_tree().create_timer(1.5).timeout
			_return_to_main_menu()
	else:
		_return_to_main_menu()



func _on_quit_pressed():
	"""Quit to desktop with confirmation"""
	print("👋 Quit button pressed")
	show_confirmation(
		"Quit game?\nAny unsaved progress will be lost.",
		_quit_game
	)


func _return_to_main_menu():
	"""Actually return to main menu"""
	print("🏠 Returning to main menu...")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _load_game():
	"""Actually load the save file"""
	print("📂 Loading save file...")
	
	if SaveSystem and SaveSystem.load_game():
		show_message("✅ Game loaded!\nReloading scene...")
		await get_tree().create_timer(1.0).timeout
		# Reload the scene to refresh everything
		get_tree().paused = false
		get_tree().reload_current_scene()
	else:
		show_message("❌ Failed to load game")

func _quit_game():
	"""Actually quit the application"""
	print("👋 Quitting game...")
	get_tree().quit()

# === DIALOG HELPERS ===

func show_confirmation(message: String, callback: Callable):
	"""Show confirmation dialog"""
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = message
	dialog.title = "Confirm"
	dialog.confirmed.connect(func(): 
		callback.call()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()

func show_message(message: String):
	"""Show simple message dialog"""
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Info"
	dialog.confirmed.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()
