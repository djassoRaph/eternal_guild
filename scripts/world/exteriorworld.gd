# exteriorworld.gd
# Main script for ExteriorWorld scene
extends Node3D

const CLOCK_LABEL := "res://scripts/ui/clock_label.gd"   # Story 3.7: the corner clock (loaded by path)


## Story 3.7 (K-19): time passes outside too: the exterior is a day scene, so the day clock runs here.
func _enter_tree() -> void:
	add_to_group("day_clock_scene")


func _ready() -> void:
	var zui_script = preload("res://scripts/game/ZonePromptUI.gd")
	var zui = zui_script.new()
	add_child(zui)
	# Story 3.7 (CL-17): no top bar out here, so a small corner clock (the hall's words)
	var clock_label = CanvasLayer.new()
	clock_label.name = "ClockLabel"
	clock_label.set_script(load(CLOCK_LABEL))
	add_child(clock_label)
	# Story 11.3: the pause menu outside (Esc): Save, Load, Save & Exit... as in the hall. It builds its own buttons
	# and pauses the tree while open.
	var pause_menu = CanvasLayer.new()
	pause_menu.name = "PauseMenu"
	pause_menu.set_script(preload("res://scripts/menus/pause_menu.gd"))
	pause_menu.handles_escape = true
	add_child(pause_menu)
	# the screen's edge pass by game_config "edge_pass" (scripts/game/edge_pass.gd)
	preload("res://scripts/game/edge_pass.gd").apply(get_node_or_null("Camera3D"))
	# the exterior look (scripts/world/exterior_look.gd; brainstorm 2026-11-03: Raphael's Octopath shot) by game_config
	# "exterior_look" (true when absent)
	var dm := get_node_or_null("/root/DataManager")
	if dm == null or bool(dm.get_config("exterior_look", true)):
		var look: Node = preload("res://scripts/world/exterior_look.gd").new()
		look.name = "ExteriorLook"
		add_child(look)

	await get_tree().process_frame
	
	# Check if player exists
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		print("ExteriorWorld: Player found at ", players[0].global_position)
	else:
		print("ExteriorWorld: Waiting for PlayerManager to add player...")
	
	print("ExteriorWorld: Ready")
