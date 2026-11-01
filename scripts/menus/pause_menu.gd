# pause_menu.gd - the pause menu: Main Menu, Load, Save, Save & Exit, Quit (+ Settings, Codex built in code)
# MainTavern's scene has it with its buttons (PauseMenu CanvasLayer); main_tavern.gd opens and closes it (Esc, and
# its SubViewport freeze). A scene without one (ExteriorWorld, Story 11.3) adds this script to a bare CanvasLayer:
# the buttons are built here, and with `handles_escape` the menu reads Esc itself and pauses the tree.
extends CanvasLayer

const SAVE_FAILED_TEXT := "Save failed — please check disk space"
const SAVED_BANNER_TEXT := "Game saved"   # DRAFT text

## Story 11.3: set by a scene that has no Esc handler of its own (ExteriorWorld).
var handles_escape := false

var main_menu_button: Button
var load_button: Button
var save_button: Button
var save_exit_button: Button
var quit_button: Button

func _ready():
	# Start hidden
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if get_node_or_null("VBoxContainer") == null:
		_build_buttons()
	main_menu_button = get_node_or_null("VBoxContainer/MainMenuButton")
	load_button = get_node_or_null("VBoxContainer/Load")
	save_button = get_node_or_null("VBoxContainer/Save")
	save_exit_button = get_node_or_null("VBoxContainer/Save&Exit")
	quit_button = get_node_or_null("VBoxContainer/QuitButton")

	# Connect buttons
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
		print("Main Menu button connected")
	else:
		print("Main Menu button not found")

	if load_button:
		load_button.pressed.connect(_on_load_pressed)
		print("Load button connected")
	else:
		print("Load button not found")

	if save_button:
		save_button.pressed.connect(_on_save_pressed)
		print("Save button connected")
	else:
		print("Save button not found")

	if save_exit_button:
		save_exit_button.pressed.connect(_on_save_exit_pressed)
		print("Save & Exit button connected")
	else:
		print("Save & Exit button not found")

	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
		print("Quit button connected")
	else:
		print("Quit button not found")

	# Settings + Codex buttons (created in code, placed just above Quit)
	var settings_button := Button.new()
	settings_button.name = "Settings"
	settings_button.text = "Settings"
	settings_button.pressed.connect(_on_settings_pressed)
	$VBoxContainer.add_child(settings_button)
	if quit_button:
		$VBoxContainer.move_child(settings_button, quit_button.get_index())

	var codex_button := Button.new()
	codex_button.name = "Codex"
	codex_button.text = "Codex"
	codex_button.pressed.connect(_on_codex_pressed)
	$VBoxContainer.add_child(codex_button)
	if quit_button:
		$VBoxContainer.move_child(codex_button, quit_button.get_index())

	print("Pause menu initialized with all buttons")


## Story 11.3: the same five buttons as MainTavern's PauseMenu, for a scene that adds this script on its own.
func _build_buttons() -> void:
	layer = 110   # over the scene's HUD and the E prompts (ZonePromptUI is layer 100; it doesn't update while paused)
	var dim := ColorRect.new()
	dim.name = "PauseBackground"
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.name = "VBoxContainer"
	box.custom_minimum_size = Vector2(170, 0)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	for pair in [["MainMenuButton", "Main Menu"], ["Load", "Load Game"], ["Save", "Save Game"],
			["Save&Exit", "Save & Exit"], ["QuitButton", "Quit Game"]]:
		var b := Button.new()
		b.name = pair[0]
		b.text = pair[1]
		box.add_child(b)


## Story 11.3: outside, Esc opens and closes the menu. The overlays that own Esc first (settings, codex, the map
## board) read it in _input and mark it handled, so it never gets here while they're open.
func _unhandled_input(event: InputEvent) -> void:
	if not handles_escape or not event.is_action_pressed("ui_cancel"):
		return
	if not visible and _a_board_is_open():
		return
	get_viewport().set_input_as_handled()
	if visible:
		close_menu()
	else:
		open_menu()


func _a_board_is_open() -> bool:
	for b in get_tree().get_nodes_in_group("mission_board"):
		if b is CanvasItem and b.visible:
			return true
	return false


## Story 11.3: open / close through the scene that owns the menu when it has a toggle (the hall's main_tavern.gd
## also freezes and thaws its SubViewport there); otherwise the menu pauses and unpauses the tree itself.
func open_menu() -> void:
	if visible:
		return
	var o = _owner_with_toggle()
	if o:
		o.toggle_pause_menu()
	else:
		visible = true
		get_tree().paused = true
		print("Game paused")


func close_menu() -> void:
	if not visible:
		return
	var o = _owner_with_toggle()
	if o:
		o.toggle_pause_menu()
	else:
		visible = false
		get_tree().paused = false
		print("Game resumed")


func _owner_with_toggle() -> Node:
	var p := get_parent()
	return p if p != null and p.has_method("toggle_pause_menu") else null


func _on_main_menu_pressed():
	"""Return to main menu with confirmation"""
	print("Main Menu button pressed")
	show_confirmation(
		"Return to main menu? Any unsaved progress will be lost.",
		_return_to_main_menu
	)

func _on_load_pressed():
	"""Load game from save file"""
	print("Load button pressed")

	if not SaveSystem.has_save_file():
		show_message("No save file found!")
		return

	show_confirmation(
		"Load saved game?\nCurrent progress will be lost.",
		_load_game
	)

func _on_save_pressed():
	"""Save, then back to the game (Story 11.3)"""
	print("Save button pressed")
	if not SaveSystem.save_game():
		show_message(SAVE_FAILED_TEXT)
		return
	# Close at once through the owner (the hall thaws its world) and say so with a banner. The old modal + 1 s wait
	# closed the menu with its own toggle, which left the hall's SubViewport frozen until Esc was pressed twice.
	close_menu()
	NotificationManager.show_banner(SAVED_BANNER_TEXT)


# Fix: save-first handler — previously bypassed by stale .tscn signal connection
func _on_save_exit_pressed():
	"""Save, and only after a confirmed write leave for the main menu (Story 11.3)."""
	print("Save & Exit pressed")
	if not SaveSystem.save_game():
		# The session stays as it is: the menu open, the game paused, the save on disk untouched.
		push_warning("[PauseMenu] warn: Save & Exit: the save failed, staying in the game")
		show_message(SAVE_FAILED_TEXT)
		return
	# Leave straight away: no timed await or modal before the transition (a "Game saved!" popup once swallowed it).
	_return_to_main_menu()



func _on_quit_pressed():
	"""Quit to desktop with confirmation"""
	print("Quit button pressed")
	show_confirmation(
		"Quit game?\nAny unsaved progress will be lost.",
		_quit_game
	)


func _on_settings_pressed():
	"""Open the settings overlay (works over the paused game)"""
	add_child(preload("res://scripts/menus/settings_menu.gd").new())

func _on_codex_pressed():
	"""Open the Codex overlay (works over the paused game). Story 18.1 review P7: as the scene's LAST child, so it reads
	every key before the HUD, the F12 panel and the hall (it is modal); Esc closes only the book, this menu stays."""
	var book = preload("res://scripts/menus/codex_menu.gd").new()
	book.opened_from = "pause_menu"
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else self
	host.add_child(book)

func _return_to_main_menu():
	"""Actually return to main menu"""
	print("Returning to main menu...")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _load_game():
	"""Load the save and go where it was made (Story 11.2: the same resume path as Continue)"""
	print("Loading save file...")

	if SaveSystem.load_game().is_empty():
		show_message("Couldn't load the save.")   # DRAFT text
		return
	var notice := SaveSystem.load_notice()   # review P12: a backup was loaded; the banner outlives the scene change
	if notice != "":
		NotificationManager.show_banner(notice)
	get_tree().paused = false
	get_tree().change_scene_to_file(SaveSystem.resume_scene())

func _quit_game():
	"""Actually quit the application"""
	print("Quitting game...")
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
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()
