# zone_interactions.gd 
# Supports procedural world choice system and modding architecture
# Handles interior tavern zone interactions
extends Node3D

@onready var bar_area = $BarArea
@onready var mission_area = $MissionBoard  
@onready var recruitment_area = $RecruitmentDesk
@onready var bedroom_area = $NextDayArea
@onready var fireplace_area = %FireplaceArea

# var MissionBoardScene = preload("res://scenes/ui/MissionBoard.tscn")  # kept on disk as fallback
var WorldMapBoardScene = preload("res://scenes/world/WorldMapBoard.tscn")

# Player state tracking
var player_in_bedroom := false
var player_in_bar := false
var player_in_mission := false
var player_in_recruitment := false
var player_in_fireplace := false
var player_in_exit_zone := false  # NEW: Track exit zone

# UI open state tracking
var mission_board_open := false
var current_mission_board_instance = null


func _ready() -> void:
	setup_interaction_areas()
	_connect_exit_zone()


func _connect_exit_zone() -> void:
	"""Find and connect to exit zone to avoid input conflicts"""
	await get_tree().process_frame
	
	# Try to find exit zone in scene
	var exit_zone = get_tree().root.get_node_or_null("Node3D/SubViewportContainer/SubViewport/TavernNavigation/Architecture/FloorEntrance/exit area")
	if not exit_zone:
		# Try alternative paths
		exit_zone = _find_node_by_name(get_tree().current_scene, "exit area")
	
	if exit_zone and exit_zone is Area3D:
		exit_zone.body_entered.connect(_on_exit_zone_entered)
		exit_zone.body_exited.connect(_on_exit_zone_exited)
		print("zone_interactions: Connected to exit zone")
	else:
		print("zone_interactions: Exit zone not found (this is OK if not in tavern)")


func _find_node_by_name(root: Node, target: String) -> Node:
	if root.name == target:
		return root
	for child in root.get_children():
		var found = _find_node_by_name(child, target)
		if found:
			return found
	return null


func _on_exit_zone_entered(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_in_exit_zone = true


func _on_exit_zone_exited(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_in_exit_zone = false


func _input(event: InputEvent) -> void:
	# CRITICAL: Skip if player is in exit zone (let exit_zone handle it)
	if player_in_exit_zone:
		return
	
	# CRITICAL: Don't process zone input if ANY UI is open!
	var mission_boards = get_tree().get_nodes_in_group("mission_board")
	for board in mission_boards:
		if board.visible:
			return  # Let UI handle input
	
	var tavern_popup = get_node_or_null("/root/Node3D/GameUI/PopupManager/TavernManagementPopup")
	if tavern_popup and tavern_popup.visible:
		return
	
	var recruitment_popup = get_node_or_null("/root/Node3D/GameUI/PopupManager/RecruitmentPopup")
	if recruitment_popup and recruitment_popup.visible:
		return
	
	var bedroom_popup = get_node_or_null("/root/Node3D/GameUI/PopupManager/BedroomPopup")
	if bedroom_popup and bedroom_popup.visible:
		return
	
	# Handle E key - ONLY ONCE!
	if event.is_action_pressed("interact"):
		handle_interaction_priority()


func setup_interaction_areas() -> void:
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


func handle_interaction_priority() -> void:
	"""Handle E key with priority: Patrons > Zone interactions"""
	if GameManager.game_over_active:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		# Fallback path
		player = get_node_or_null("/root/Node3D/SubViewportContainer/SubViewport/Player")
	
	if not player:
		print("Player not found!")
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


func handle_zone_interactions() -> void:
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
	elif player_in_fireplace:
		# Fireplace interaction is handled by fireplace_zone.gd's own _input()
		# Do NOT duplicate the interaction here — it causes double-handling
		# fireplace_zone.gd opens the minigame when player presses E nearby
		pass
	else:
		print("DEBUG: No zone active!")


func open_tavern_management() -> void:
	"""Open beer management popup"""
	print("Attempting to open beer popup...")
	var tavern_popup = get_node("/root/Node3D/GameUI/PopupManager/TavernManagementPopup")
	if tavern_popup:
		if tavern_popup.visible:
			print("Tavern popup already open!")
			return
		
		print("Calling open_tavern_management...")
		tavern_popup.open_tavern_management()
		send_log_message("Looking at your stock")
	else:
		print("Beer popup not found!")


func open_mission_board() -> void:
	"""Open mission board with adventurer check"""
	
	if mission_board_open:
		print("Mission board already open!")
		return
	
	if current_mission_board_instance and is_instance_valid(current_mission_board_instance):
		if current_mission_board_instance.visible:
			print("Mission board instance already visible!")
			return
		else:
			print("Cleaning up invisible mission board instance")
			current_mission_board_instance.queue_free()
			current_mission_board_instance = null
	
	mission_board_open = true
	print("Opening mission board...")
	
	current_mission_board_instance = WorldMapBoardScene.instantiate()
	get_tree().root.add_child(current_mission_board_instance)
	
	if GameManager.available_missions.is_empty():
		GameManager.refresh_available_missions()
		print("Forced mission refresh on open")
	
	var adventurer_count = GameManager.get_adventurer_count()
	if adventurer_count == 0:
		send_log_message("You need to hire adventurers before checking the mission board!")
		send_log_message("Visit the recruitment desk first.")
		current_mission_board_instance.queue_free()
		current_mission_board_instance = null
		mission_board_open = false
		return
	
	send_log_message("Reviewing available contracts")
	send_log_message("Reviewing available missions")
	
	current_mission_board_instance.open_mission_board()
	
	current_mission_board_instance.board_closed.connect(func():
		mission_board_open = false
		print("Mission board flag reset via board_closed signal")
	)
	
	current_mission_board_instance.tree_exited.connect(func(): 
		mission_board_open = false
		current_mission_board_instance = null
		print("Mission board instance destroyed")
	)


func open_recruitment_desk() -> void:
	"""Open recruitment desk with duplicate prevention"""
	print("Opening recruitment desk...")
	
	var recruitment_popup = get_node_or_null("/root/Node3D/GameUI/PopupManager/RecruitmentPopup")
	if not recruitment_popup:
		print("Recruitment popup not found!")
		return
	
	if recruitment_popup.visible:
		print("Recruitment popup already open!")
		return
	
	recruitment_popup.open_recruitment_desk()
	send_log_message("Reviewing potential recruits")


func advance_day() -> void:
	"""Open bedroom popup instead of advancing day directly"""
	print("Opening bedroom/quarters...")
	open_bedroom_popup()


func open_bedroom_popup() -> void:
	"""Open bedroom management popup"""
	print("Attempting to open bedroom popup...")
	
	var bedroom_popup = get_node_or_null("/root/Node3D/GameUI/PopupManager/BedroomPopup")
	if not bedroom_popup:
		print("Bedroom popup not found!")
		if GameManager.has_method("advance_day"):
			GameManager.despawn_all_patrons()
			GameManager.advance_day()
			GameManager.cleanup_expired_recruitment_candidates()
		return
	
	if bedroom_popup.visible:
		print("Bedroom popup already open!")
		return
	
	print("Calling open_bedroom()...")
	bedroom_popup.open_bedroom()
	send_log_message("Reviewing the day before resting...")


# === AREA ENTER/EXIT HANDLERS ===
func _on_bar_entered(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_in_bar = true
		print("Player entered bar area")


func _on_bar_exited(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_in_bar = false
		print("Player left bar area")


func _on_mission_entered(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_in_mission = true
		print("Player entered mission area")


func _on_mission_exited(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_in_mission = false
		print("Player left mission area")


func _on_recruitment_entered(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_in_recruitment = true
		print("Player entered recruitment area")


func _on_recruitment_exited(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_in_recruitment = false
		print("Player left recruitment area")


func _on_nextday_entered(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_in_bedroom = true
		print("Player entered bedroom area - player_in_bedroom =", player_in_bedroom)


func _on_nextday_exited(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_in_bedroom = false
		print("Player left bedroom area")


func _on_fireplace_entered(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_in_fireplace = true
		print("Player entered fireplace area")


func _on_fireplace_exited(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_in_fireplace = false
		print("Player left Fireplace area")


func send_log_message(message: String) -> void:
	"""Send message to GameManager logging system"""
	if GameManager.has_method("log_message"):
		GameManager.log_message(message)
	else:
		print("LOG: ", message)
