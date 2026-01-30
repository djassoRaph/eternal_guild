# exteriorworld.gd
# Main script for ExteriorWorld scene
extends Node3D


func _ready() -> void:
	print("🌍 ExteriorWorld: Scene loaded")
	
	# Wait for everything to initialize
	await get_tree().process_frame
	
	# Check if player exists
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		print("🌍 ExteriorWorld: Player found at ", players[0].global_position)
	else:
		print("🌍 ExteriorWorld: Waiting for PlayerManager to add player...")
	
	print("🌍 ExteriorWorld: Ready")
