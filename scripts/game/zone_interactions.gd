# zone_interactions.gd 
# Supports procedural world choice system and modding architecture
extends Node3D

@onready var bar_area = $BarArea
@onready var mission_area = $MissionBoard  
@onready var recruitment_area = $RecruitmentDesk
@onready var bedroom_area = $NextDayArea
@onready var fireplace_area = %FireplaceArea


var MissionBoardScene = preload("res://scenes/ui/MissionBoard.tscn")


# Player state tracking
var player_in_bedroom = false
var player_in_bar = false
var player_in_mission = false
var player_in_recruitment = false
var player_in_fireplace = false


func _input(event):
	# Handle E key for all zone interactions
	if event.is_action_pressed("interact"):  # This is the E key!
		handle_interaction_priority()
		
func _ready():
	setup_interaction_areas()
	

func setup_interaction_areas():
	"""Connect all interaction area signals"""
	bar_area.body_entered.connect(_on_bar_entered)
	bar_area.body_exited.connect(_on_bar_exited)
	
	bedroom_area.body_entered.connect(_on_nextday_entered)
	bedroom_area.body_exited.connect(_on_nextday_exited)
	
	mission_area.body_entered.connect(_on_mission_entered)
	mission_area.body_exited.connect(_on_mission_exited)
	
	recruitment_area.body_entered.connect(_on_recruitment_entered)
	recruitment_area.body_exited.connect(_on_recruitment_exited)

	fireplace_area.body_entered.connect(_on_fireplace_entered)
	fireplace_area.body_exited.connect(_on_fireplace_exited)

func setup_patron_tracking():
	"""Initialize patron tracking system for recruitment integration"""
	# Get reference to PatronSpawner if it exists
	var patron_spawner = get_node_or_null("../PatronSpawner")
	if patron_spawner:
		print("Connected to PatronSpawner for enhanced interactions")
		# Note: In future, connect to patron spawn/despawn signals
	else:
		print("PatronSpawner not found - will search manually for patrons")

func handle_interaction_priority():
	"""Handle E key with priority: Patrons > Zone interactions"""
	if GameManager.game_over_active:
		return
	var player = get_node("/root/Node3D/SubViewportContainer/SubViewport/Player")
	if not player:
		print("❌ Player not found!")
		return
	var served_patron = try_serve_nearby_patron(player)
	if served_patron:
		return  
	handle_zone_interactions()

func try_serve_nearby_patron(player) -> bool:
	"""Try to serve patrons needing service"""
	if player and player.has_method("try_serve_nearby_patron"):
		var served = player.try_serve_nearby_patron()
		return served != null
	return false


func handle_zone_interactions():
	"""Handle zone-based interactions (existing functionality)"""	
	if player_in_bar:
		open_tavern_management()
	elif player_in_mission:
		open_mission_board()
	elif player_in_recruitment:
		open_recruitment_desk()
	elif player_in_bedroom:
		print("DEBUG: Calling advance_day()...") 
		advance_day()
	elif player_in_fireplace:  # New: Handle fireplace here for consistency
		var fireplace_script = get_node_or_null("%FireplaceArea")  # Get the Area3D with script
		if fireplace_script and fireplace_script.has_method("attempt_stoke_fire"):
			fireplace_script.attempt_stoke_fire()
		else:
			print("WARNING: Fireplace script not found!")
	else:
		print("DEBUG: No zone active!")
	





func open_tavern_management():
	"""Open beer management popup"""
	print("🍺 Attempting to open beer popup...")
	var tavern_popup = get_node("/root/Node3D/GameUI/PopupManager/TavernManagementPopup")
	if tavern_popup:
		print("✅ Calling open_tavern_management...")
		tavern_popup.open_tavern_management()
		send_log_message("Looking at your stock")
	else:
		print("❌ Beer popup not found!")

func open_mission_board():
	"""Open mission board with adventurer check"""
	print("📋 Opening mission board...")
	var mission_board_instance = MissionBoardScene.instantiate()
	get_tree().root.add_child(mission_board_instance)  # Add to root or a UI layer (e.g., /root/Node3D/GameUI)
	# Optionally position/center: mission_board_instance.position = get_viewport().size / 2 - mission_board_instance.size / 2
	
	# Force mission refresh if empty
	if GameManager.available_missions.is_empty():
		GameManager.refresh_available_missions()
		print("Forced mission refresh on open")
	
	# Check adventurers and handle UI internally
	var adventurer_count = GameManager.get_adventurer_count()
	if adventurer_count == 0:
		send_log_message("❌ You need to hire adventurers before checking the mission board!")
		send_log_message("💡 Visit the recruitment desk first.")
		mission_board_instance.queue_free()  # Clean up if no adventurers
		return
	
	send_log_message("Reviewing available contracts")
	send_log_message("Reviewing available missions")
	# Let the instance handle its own open logic
	mission_board_instance.open_mission_board()

func open_recruitment_desk():
	"""Open recruitment desk with patron integration"""
	print("👥 Opening recruitment desk...")
	var recruitment_popup = get_node("/root/Node3D/GameUI/PopupManager/RecruitmentPopup")
	if recruitment_popup:
		recruitment_popup.open_recruitment_desk()  # Call the popup's function
		send_log_message("Reviewing potential recruits")
	else:
		print("❌ Recruitment popup not found!")

func advance_day():
	"""Open bedroom popup instead of advancing day directly"""
	print("🌙 Opening bedroom/quarters...")
	open_bedroom_popup()


func open_bedroom_popup():
	"""Open bedroom management popup"""
	print("🛏️ Attempting to open bedroom popup...")
	
	var bedroom_popup = get_node("/root/Node3D/GameUI/PopupManager/BedroomPopup")
	if bedroom_popup:
		print("✅ Calling open_bedroom()...")
		bedroom_popup.open_bedroom()
		send_log_message("Reviewing the day before resting...")
	else:
		print("❌ Bedroom popup not found!")
		# Fallback: advance day directly if popup missing
		if GameManager.has_method("advance_day"):
			GameManager.despawn_all_patrons()
			GameManager.advance_day()
			GameManager.cleanup_expired_recruitment_candidates()
	
# === AREA ENTER/EXIT HANDLERS ===
func _on_bar_entered(body):
	if body.name == "Player":
		player_in_bar = true
		print("Player entered bar area")

func _on_bar_exited(body):
	if body.name == "Player":
		player_in_bar = false
		print("Player left bar area")

func _on_mission_entered(body):
	if body.name == "Player":
		player_in_mission = true
		print("Player entered mission area")

func _on_mission_exited(body):
	if body.name == "Player":
		player_in_mission = false
		print("Player left mission area")

func _on_recruitment_entered(body):
	if body.name == "Player":
		player_in_recruitment = true
		print("Player entered recruitment area")

func _on_recruitment_exited(body):
	if body.name == "Player":
		player_in_recruitment = false
		print("Player left recruitment area")

func _on_nextday_entered(body):
	if body.name == "Player":
		player_in_bedroom = true
		print("✅ Player entered bedroom area - player_in_bedroom =", player_in_bedroom)

func _on_nextday_exited(body):
	if body.name == "Player":
		player_in_bedroom = false
		print("Player left bedroom area")
		

func _on_fireplace_entered(body):
	if body.name == "Player":
		player_in_fireplace = true
		print("Player entered fireplace area")
		
func _on_fireplace_exited(body):
	if body.name == "Player": 
		player_in_fireplace = false
		print("Player left Fireplace area")
		
func send_log_message(message: String):
	"""Send message to GameManager logging system"""
	if GameManager.has_method("log_message"):
		GameManager.log_message(message)
	else:
		print("LOG: ", message)
