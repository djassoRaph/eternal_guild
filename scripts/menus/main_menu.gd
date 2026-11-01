# main_menu.gd - Simple main menu for Eternal Guild
extends Control

const TAVERN_SCENE = "res://scenes/MainTavern.tscn"

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
	# Settings + Codex buttons created in code, placed just above Quit
	var settings_button := Button.new()
	settings_button.text = "Settings"
	settings_button.pressed.connect(_on_settings_pressed)
	$VBoxContainer.add_child(settings_button)
	$VBoxContainer.move_child(settings_button, quit_button.get_index())

	var codex_button := Button.new()
	codex_button.text = "Codex"
	codex_button.pressed.connect(_on_codex_pressed)
	$VBoxContainer.add_child(codex_button)
	$VBoxContainer.move_child(codex_button, quit_button.get_index())


func _on_settings_pressed() -> void:
	add_child(preload("res://scripts/menus/settings_menu.gd").new())

func _on_codex_pressed() -> void:
	var book = preload("res://scripts/menus/codex_menu.gd").new()
	book.opened_from = "main_menu"   # Story 18.1 review P1: the "[Codex] open:" line says where
	add_child(book)

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
	# Story 13.4: the one way into a new run, shared with the fall screen's New Run. begin_new_run() wipes the session's
	# run state (a New Game never inherits the old day/gold/roster) and has the hall make the new run's first save as it
	# loads (Epic 11). Story 5.1's naming screen and Epic 22's legacy transition hook in there.
	GameManager.begin_new_run()
	get_tree().change_scene_to_file(GameManager.NEW_RUN_SCENE)

func _on_continue_button_pressed():
	# Story 11.2: one resume path for Continue and the pause menu's Load. load_game() falls back to a backup when
	# the save is broken; resume_scene() is the saved scene, or the tavern's spawn point when it can't be resumed.
	if SaveSystem.load_game().is_empty():
		_show_message("Couldn't load the save.")   # DRAFT text
		return
	var notice := SaveSystem.load_notice()   # review P12: a backup was loaded; the banner outlives the scene change
	if notice != "":
		NotificationManager.show_banner(notice)
	get_tree().change_scene_to_file(SaveSystem.resume_scene())


func _show_message(text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = text
	dialog.title = "Continue"
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _on_quit_button_pressed():
	"""Quit game"""
	get_tree().quit()

func has_save_game() -> bool:
	"""Check if a save file exists (a backup counts: Continue loads it when the main file is broken)"""
	return SaveSystem.has_save_file()
