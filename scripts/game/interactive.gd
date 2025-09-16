# Interactive.gd - Attach to Interactive Node3D
extends Node3D

@onready var bar_area = $BarArea
@onready var mission_area = $MissionBoard  
@onready var recruitment_area = $RecruitmentDesk
@onready var bedroom_area = $NextDayArea


var player_in_bedroom = false
var player_in_bar = false
var player_in_mission = false
var player_in_recruitment = false
var player_in_bedroomarea = false


func _ready():
	print("Script attached to: ", get_path())
	print("Looking for GameUI...")
	
	print("bar_area: ", bar_area)
	print("mission_area: ", mission_area) 
	print("recruitment_area: ", recruitment_area)
	print("nextday_area: ", bedroom_area)
	
	# Connect area signals
	bar_area.body_entered.connect(_on_bar_entered)
	bar_area.body_exited.connect(_on_bar_exited)
	
	bedroom_area.body_entered.connect(_on_nextday_entered)
	bedroom_area.body_exited.connect(_on_nextday_exited)
	
	mission_area.body_entered.connect(_on_mission_entered)
	mission_area.body_exited.connect(_on_mission_exited)
	
	recruitment_area.body_entered.connect(_on_recruitment_entered)
	recruitment_area.body_exited.connect(_on_recruitment_exited)
	
	send_log_message("Interactive areas connected!")


func _input(event):
	
	if event.is_action_pressed("interact"):
		var player = get_node("/root/Node3D/SubViewportContainer/SubViewport/Player")
		if player and player.has_method("try_serve_nearby_patron"):
			var served_patron = player.try_serve_nearby_patron()
			if served_patron:
				print("✅ Served a patron!")
				return  # Exit early, don't check zone interactions
				
		print("🔑 E key detected! player_in_bar: ", player_in_bar)
		if player_in_bar:
			print("🍺 Attempting to open beer popup...")
			var beer_popup = get_node("/root/Node3D/GameUI/PopupManager/BeerManagementPopup")
			print("🔍 Beer popup found: ", beer_popup)
			if beer_popup:
				print("✅ Calling open_beer_management...")
				beer_popup.open_beer_management()
				send_log_message("Looking at your stock")
			else:
				print("❌ Beer popup not found!")

		elif player_in_mission:
			# Check if player has any adventurers first
			var main_script = get_tree().current_scene
			if main_script and main_script.has_method("get_adventurer_count"):
				var adventurer_count = main_script.get_adventurer_count()
				if adventurer_count == 0:
					send_log_message("❌ You need to hire adventurers before checking the mission board!")
					send_log_message("💡 Visit the recruitment desk first.")
					return
			
			var mission_popup = get_node("/root/Node3D/GameUI/PopupManager/MissionBoardPopup")
			if mission_popup:
				mission_popup.open_mission_board()
				send_log_message("Examining available guild contracts...")
				
		elif player_in_recruitment:
			var recruitment_popup = get_node("/root/Node3D/GameUI/PopupManager/RecruitmentPopup")
			if recruitment_popup:
				recruitment_popup.open_recruitment_desk()
				send_log_message("Looking for new guild members...")
			
		
		elif player_in_bedroomarea:
			send_log_message("💤 Resting and advancing to the next day...")
			advance_day_interaction()

func _on_bar_entered(body):
	if body.name == "Player":
		player_in_bar = true
		print("💡 Press E to manage tavern")

func _on_bar_exited(body):
	if body.name == "Player":
		player_in_bar = false

func _on_mission_entered(body):
	if body.name == "Player":
		player_in_mission = true
		print("💡 Press E to view missions")

func _on_mission_exited(body):
	if body.name == "Player":
		player_in_mission = false

func _on_recruitment_entered(body):
	if body.name == "Player":
		player_in_recruitment = true
		print("💡 Press E to recruit adventurers")

func _on_recruitment_exited(body):
	if body.name == "Player":
		player_in_recruitment = false
		
func _on_nextday_entered(body):
	if body.name == "Player":
		player_in_bedroomarea = true
		print("Near bedroom door - Press E to rest")

func _on_nextday_exited(body):
	if body.name == "Player":
		player_in_bedroomarea = false
		
		
		
func send_log_message(message: String):
	var main_script = get_tree().current_scene
	if main_script and main_script.has_method("log_message"):
		await get_tree().process_frame  # Wait one frame
		main_script.log_message(message)
	else:
		print("Could not find main tavern script")

func advance_day_interaction():
	"""Handle the bedroom day advancement interaction"""
	if player_in_bedroomarea:
		GameManager.advance_day()
		send_log_message("Day advanced successfully!")
		
