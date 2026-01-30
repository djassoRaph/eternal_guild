# exit_zone_interior.gd
# Attach to: Area3D node at tavern entrance/exit
# IMPORTANT: This Area3D must be INSIDE the SubViewport with the Player!
# Path should be: Node3D/SubViewportContainer/SubViewport/TavernNavigation/Architecture/FloorEntrance/exit area
extends Area3D


# =============================================================================
# CONFIGURATION
# =============================================================================
@export var prompt_text := "Press E - Exit Tavern"
@export var exterior_scene_path := "res://scenes/world/ExteriorWorld.tscn"
@export var exterior_spawn_position := Vector3(-19.584, 2.0, 5.0)


# =============================================================================
# STATE
# =============================================================================
var player_in_zone := false
var transitioning := false


# =============================================================================
# INITIALIZATION
# =============================================================================
func _ready() -> void:
	# Connect area signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Debug: Print our location in scene tree
	print("✅ Exit zone ready")
	print("   Path: ", get_path())
	print("   Collision layer: ", collision_layer)
	print("   Collision mask: ", collision_mask)
	
	# Register with ZonePromptUI
	await get_tree().process_frame
	var zone_ui = get_node_or_null("/root/ZonePromptUI")
	if zone_ui and zone_ui.has_method("register_zone"):
		zone_ui.register_zone(self, prompt_text)
		print("   Registered with ZonePromptUI")


# =============================================================================
# INPUT HANDLING
# =============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if not player_in_zone or transitioning:
		return
	
	if event.is_action_pressed("interact"):
		print("🚪 Exit zone: E pressed!")
		_do_transition()
		# Mark input as handled (safely)
		var vp = get_viewport()
		if vp:
			vp.set_input_as_handled()


# =============================================================================
# ZONE DETECTION
# =============================================================================
func _on_body_entered(body: Node3D) -> void:
	print("🔍 Exit zone: Body entered -> ", body.name, " (groups: ", body.get_groups(), ")")
	
	if body.name == "Player" or body.is_in_group("player"):
		player_in_zone = true
		print("✅ Exit zone: PLAYER DETECTED!")


func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		player_in_zone = false
		print("🚪 Exit zone: Player left")


# =============================================================================
# MANUAL DETECTION (Fallback if signals don't work)
# =============================================================================
func _physics_process(_delta: float) -> void:
	# Skip if already detected via signals
	if player_in_zone:
		return
	
	# Fallback: manually check for overlapping bodies
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body.name == "Player" or body.is_in_group("player"):
			if not player_in_zone:
				player_in_zone = true
				print("✅ Exit zone: Player detected via overlap check!")
			return
	
	# If we were in zone but no player found, reset
	if player_in_zone and bodies.is_empty():
		player_in_zone = false


# =============================================================================
# SCENE TRANSITION
# =============================================================================
func _do_transition() -> void:
	if transitioning:
		return
	
	transitioning = true
	print("🚀 Exiting tavern...")
	print("   Target: ", exterior_scene_path)
	print("   Spawn: ", exterior_spawn_position)
	
	# Clear zone prompts
	var zone_ui = get_node_or_null("/root/ZonePromptUI")
	if zone_ui and zone_ui.has_method("clear_all_zones"):
		zone_ui.clear_all_zones()
	
	# Use PlayerManager if available
	var pm = get_node_or_null("/root/PlayerManager")
	if pm and pm.has_method("transition_to_scene"):
		print("   Using PlayerManager...")
		pm.transition_to_scene(exterior_scene_path, exterior_spawn_position)
	else:
		# Direct transition
		print("   Direct scene change...")
		get_tree().change_scene_to_file(exterior_scene_path)
