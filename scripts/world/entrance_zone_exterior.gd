# entrance_zone_exterior.gd
# Attach to: Area3D at tavern door in ExteriorWorld scene
# Handles transition from exterior back to tavern interior
extends Area3D

# =============================================================================
# CONFIGURATION
# =============================================================================
@export var prompt_text := "Press E - Enter Tavern"
@export var interior_scene_path := "res://scenes/MainTavern.tscn"
@export var interior_spawn_position := Vector3(10, 0.5, 6)  # Near tavern entrance inside

# =============================================================================
# STATE
# =============================================================================
var player_in_zone: bool = false
var is_transitioning: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready():
	# Connect area signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Register with ZonePromptUI singleton
	_register_with_prompt_ui()
	
	print("Entrance zone (exterior) ready")

func _register_with_prompt_ui():
	"""Register this zone with the ZonePromptUI singleton"""
	# Wait a frame for autoloads to be ready
	await get_tree().process_frame
	
	var zone_ui = get_node_or_null("/root/ZonePromptUI")
	if zone_ui and zone_ui.has_method("register_zone"):
		zone_ui.register_zone(self, prompt_text)
		print("Entrance zone registered with ZonePromptUI")
	else:
		push_warning("EntranceZone: ZonePromptUI singleton not found!")

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _process(_delta: float) -> void:
	if player_in_zone and not is_transitioning:
		if Input.is_action_just_pressed("interact"):
			_enter_tavern()

# =============================================================================
# ZONE DETECTION
# =============================================================================

func _on_body_entered(body: Node3D) -> void:
	if _is_player(body):
		player_in_zone = true
		print("Player at tavern entrance - Press E to enter")

func _on_body_exited(body: Node3D) -> void:
	if _is_player(body):
		player_in_zone = false

func _is_player(body: Node3D) -> bool:
	return body.name == "Player" or body.is_in_group("player")

# =============================================================================
# SCENE TRANSITION
# =============================================================================

func _enter_tavern() -> void:
	"""Handle transition to tavern interior"""
	if is_transitioning:
		return
	
	is_transitioning = true
	print("Entering tavern...")
	print("   Path: ", interior_scene_path)
	print("   Spawn: ", interior_spawn_position)
	
	# Use PlayerManager if available (preferred method)
	var pm = get_node_or_null("/root/PlayerManager")
	if pm and pm.has_method("transition_to_scene"):
		pm.transition_to_scene(interior_scene_path, interior_spawn_position)
	else:
		# Fallback: direct scene change
		print("PlayerManager not found, using direct scene change")
		_fallback_transition()

func _fallback_transition() -> void:
	"""Fallback transition without PlayerManager"""
	# Clear zone prompts
	var zone_ui = get_node_or_null("/root/ZonePromptUI")
	if zone_ui and zone_ui.has_method("clear_all_zones"):
		zone_ui.clear_all_zones()
	
	# Simple scene change
	get_tree().change_scene_to_file(interior_scene_path)
