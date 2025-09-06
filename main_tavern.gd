extends Node3D

@onready var game_log = $GameUI/MainArea/TavernView/LogContainer/EventLog
@onready var log_container = $GameUI/MainArea/TavernView/LogContainer
@onready var day_label = $GameUI/TopStatsBar/DayLabel
@onready var gold_label = $GameUI/TopStatsBar/GoldLabel
@onready var beer_label = $GameUI/TopStatsBar/BeerLabel

func _ready():

	print("=== DEBUGGING @ONREADY ===")
	print("@onready game_log: ", game_log)
	print("Direct path works: ", $GameUI/MainArea/TavernView/LogContainer/EventLog)
	print("Node exists check: ", has_node("GameUI/MainArea/TavernView/LogContainer/EventLog"))
	
	log_message("Game started successfully!")
	# Allow this node to process input even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_pause_menu()

func toggle_pause_menu():
	print("Toggle called!")
	var pause_menu = get_node("PauseMenu")
	print("Found pause menu: ", pause_menu)
	pause_menu.visible = !pause_menu.visible
	get_tree().paused = pause_menu.visible


func _on_main_menu_button_pressed() -> void:
	print("on_main_menu_button log")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MainMenu.tscn")


func _on_quit_button_pressed() -> void:
	print("_on_quit_button_pressed log")
	get_tree().quit()

		
func send_log_message(message: String):
	var main_script = get_node("/root/Node3D")
	if main_script and main_script.has_method("log_message"):
		main_script.log_message(message)

func log_message(message: String):
	print("log_message function called with: ", message)
	if game_log and game_log is RichTextLabel:
		print("game_log found, current text length: ", game_log.text.length())
		if game_log.text == "":
			print("Text is empty, adding welcome messages")
			game_log.text = "Welcome to the Eternal Guild!\n"
			game_log.text += "Day 1 begins...\n"
			game_log.text += "Your adventure starts here.\n"
			game_log.text += "---\n"
			game_log.text += message
		else:
			print("Text exists, appending message")
			game_log.text += "\n" + message
		
		print("Final text content: ", game_log.text)
		print("Text length after update: ", game_log.text.length())
		
		# Scroll to bottom
		await get_tree().process_frame
		if log_container and log_container.get_v_scroll_bar():
			log_container.get_v_scroll_bar().value = log_container.get_v_scroll_bar().max_value
			print("Scrolled to bottom")
	else:
		print("game_log is null or wrong type: ", game_log)
		print("LOG: " + message)
