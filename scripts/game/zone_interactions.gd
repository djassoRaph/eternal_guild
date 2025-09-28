# interactive.gd - ENHANCED VERSION with Patron-Recruitment Bridge
# Supports procedural world choice system and modding architecture
extends Node3D

@onready var bar_area = $BarArea
@onready var mission_area = $MissionBoard  
@onready var recruitment_area = $RecruitmentDesk
@onready var bedroom_area = $NextDayArea

# Player state tracking
var player_in_bedroom = false
var player_in_bar = false
var player_in_mission = false
var player_in_recruitment = false


func _ready():
	setup_interaction_areas()
	send_log_message("Enhanced Interactive areas connected!")

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

func setup_patron_tracking():
	"""Initialize patron tracking system for recruitment integration"""
	# Get reference to PatronSpawner if it exists
	var patron_spawner = get_node_or_null("../PatronSpawner")
	if patron_spawner:
		print("Connected to PatronSpawner for enhanced interactions")
		# Note: In future, connect to patron spawn/despawn signals
	else:
		print("PatronSpawner not found - will search manually for patrons")

func _input(event):
	if event.is_action_pressed("interact"):
		handle_interaction_priority()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_F9:  # Debug patron recruitment
			debug_patron_recruitment()

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
	print("🔑 E key detected! Checking zones...")
	
	if player_in_bar:
		open_beer_management()
	elif player_in_mission:
		open_mission_board()
	elif player_in_recruitment:
		open_recruitment_desk()
	elif player_in_bedroom:
		advance_day()
		

func open_beer_management():
	"""Open beer management popup"""
	print("🍺 Attempting to open beer popup...")
	var beer_popup = get_node("/root/Node3D/GameUI/PopupManager/BeerManagementPopup")
	if beer_popup:
		print("✅ Calling open_beer_management...")
		beer_popup.open_beer_management()
		send_log_message("Looking at your stock")
	else:
		print("❌ Beer popup not found!")

func open_mission_board():
	"""Open mission board with adventurer check"""
	var adventurer_count = GameManager.get_adventurer_count()
	if adventurer_count == 0:
		send_log_message("❌ You need to hire adventurers before checking the mission board!")
		send_log_message("💡 Visit the recruitment desk first.")
		return
	
	print("📋 Opening mission board...")
	var mission_popup = get_node("/root/Node3D/GameUI/PopupManager/MissionBoardPopup")
	if mission_popup:
		mission_popup.open_mission_board()
		send_log_message("Reviewing available missions")
	else:
		print("❌ Mission popup not found!")

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
	"""Handle day advancement"""
	print("🌙 Advancing to next day...")
	if GameManager.has_method("advance_day"):
		GameManager.advance_day()
		# Clear expired patron recruitment candidates
		GameManager.cleanup_expired_recruitment_candidates()
	
	send_log_message("You rest for the night and prepare for tomorrow's challenges.")

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
		print("Player entered bedroom area")

func _on_nextday_exited(body):
	if body.name == "Player":
		player_in_bedroom = false
		print("Player left bedroom area")

func send_log_message(message: String):
	"""Send message to GameManager logging system"""
	if GameManager.has_method("log_message"):
		GameManager.log_message(message)
	else:
		print("LOG: ", message)

# === DEBUG FUNCTIONS ===
func _input_debug(event):
	"""Debug functions for testing"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F9:  # Debug patron recruitment
			debug_patron_recruitment()

func debug_patron_recruitment():
	"""Debug function to test patron recruitment system"""
	print("=== PATRON RECRUITMENT DEBUG ===")
	print("Current recruitment pool size: ", GameManager.patron_recruitment_pool.size())
	for candidate in GameManager.patron_recruitment_pool:
		print("- ", candidate.name, " (", candidate.class, ") - ", candidate.hiring_cost, "g")
	print("================================")
