# control.gd
extends Control

func _ready():
	print("test file script ready")
	
	# Wait for card to be fully ready
	await get_tree().process_frame
	
	var card = $SingleMissionCard
	
	if card == null:
		print("ERROR: Card node not found!")
		return
	
	print("Card found:", card)
	
	var test_mission = {
		"name": "Clear Slime Nest",
		"description": "Local farm overrun by slimes",
		"reward_range": [10, 20],
		"danger": 2,
		"success_factors": ["strength", "endurance"]
	}
	
	var test_adventurers = [
		{"name": "Gareth", "class": "Fighter", "strength": 7, "missions_completed": 5},
		{"name": "Lyra", "class": "Rogue", "dexterity": 8, "missions_completed": 3}
	]
	
	print("before setup", test_mission)
	await card.setup(test_mission, test_adventurers)
	print("Setup completed!")
	
	card.mission_started.connect(_on_mission_started)

func _on_mission_started(mission, adventurer):
	print("Mission started: ", mission.name)
	print("Sent: ", adventurer.name)
