# exteriorworld.gd
# Main script for ExteriorWorld scene
extends Node3D


func _ready() -> void:
	var zui_script = preload("res://scripts/game/ZonePromptUI.gd")
	var zui = zui_script.new()
	add_child(zui)
	# Story 11.3: the pause menu outside (Esc): Save, Load, Save & Exit... as in the hall. It builds its own buttons
	# and pauses the tree while open.
	var pause_menu = CanvasLayer.new()
	pause_menu.name = "PauseMenu"
	pause_menu.set_script(preload("res://scripts/menus/pause_menu.gd"))
	pause_menu.handles_escape = true
	add_child(pause_menu)
	# the screen's edge pass by game_config "edge_pass" (scripts/game/edge_pass.gd)
	preload("res://scripts/game/edge_pass.gd").apply(get_node_or_null("Camera3D"))

	await get_tree().process_frame
	
	# Check if player exists
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		print("ExteriorWorld: Player found at ", players[0].global_position)
	else:
		print("ExteriorWorld: Waiting for PlayerManager to add player...")
	
	print("ExteriorWorld: Ready")
