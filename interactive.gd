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

var beer_popup: AcceptDialog
var mission_popup: AcceptDialog
var recruitment_popup: AcceptDialog

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
	print("next line is log_message(\"testing\") function")
	send_log_message("LOG A MESSAGE INSIDE ")
	print("previous line is log_message(\"testing\") function")
	send_log_message("aye")



func create_popups():
	"""Create simple popup dialogs"""
	print("Creating popups...")
	
	# Beer management popup
	beer_popup = AcceptDialog.new()
	beer_popup.title = "Tavern Management"
	beer_popup.dialog_text = "Beer Stock: 5\nGold: 30\n\n[Buy Beer] [Sell Beer]"
	beer_popup.size = Vector2(300, 200)
	add_child(beer_popup)
	send_log_message("Beer popup created")
	print("Beer popup created: ", beer_popup != null)
	
	# Mission popup
	mission_popup = AcceptDialog.new()
	mission_popup.title = "Mission Board"
	mission_popup.dialog_text = "Available Missions:\n- Clear Slimes (5-10g)\n- Escort Merchant (40-60g)"
	mission_popup.size = Vector2(400, 250)
	add_child(mission_popup)
	send_log_message("mission popup created")
	print("Mission popup created: ", mission_popup != null)
	
	# Recruitment popup
	recruitment_popup = AcceptDialog.new()
	recruitment_popup.title = "Recruitment Office"
	recruitment_popup.dialog_text = "Available Recruits:\n- Brom (Fighter) - 10g\n- Lyra (Mage) - 15g"
	recruitment_popup.size = Vector2(350, 200)
	add_child(recruitment_popup)
	send_log_message("recruit popup created")
	print("Recruitment popup created: ", recruitment_popup != null)

func _input(event):
		
	if event.is_action_pressed("interact"):
		if player_in_bar:
			if not beer_popup:
				beer_popup = AcceptDialog.new()
				beer_popup.title = "Tavern Management"
				beer_popup.dialog_text = "Manage your tavern here!\n\nBeer Stock: 5\nGold: 30"
				add_child(beer_popup)
				print("Created beer popup")
			beer_popup.popup_centered()
			
		elif player_in_mission:
			if not mission_popup:
				mission_popup = AcceptDialog.new()
				mission_popup.title = "Mission Board"
				mission_popup.dialog_text = "Available Missions:\n\n- Clear Slimes (5-10g)\n- Escort Merchant (40-60g)"
				add_child(mission_popup)
				print("Created mission popup")
			mission_popup.popup_centered()
			
		elif player_in_recruitment:
			if not recruitment_popup:
				recruitment_popup = AcceptDialog.new()
				recruitment_popup.title = "Recruitment Office"  
				recruitment_popup.dialog_text = "Available Recruits:\n\n- Brom (Fighter) - 10g\n- Lyra (Mage) - 15g"
				add_child(recruitment_popup)
				print("Created recruitment popup")
			recruitment_popup.popup_centered()

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
	var main_script = get_node("/root/Node3D")
	if main_script and main_script.has_method("log_message"):
		main_script.log_message(message)
	else:
		print("Could not find main tavern script")
