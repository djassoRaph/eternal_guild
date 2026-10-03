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
	_sync_prompt()
	
	# Register with ZonePromptUI singleton
	_register_with_prompt_ui()
	
	print("Entrance zone (exterior) ready")

func _register_with_prompt_ui():
	await get_tree().process_frame
	var zui_script = preload("res://scripts/game/ZonePromptUI.gd")
	var zone_ui = zui_script.find(get_tree())
	if zone_ui:
		zone_ui.register_zone(self, prompt_text)
	else:
		push_warning("EntranceZone: ZonePromptUI not found in scene")

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
		_sync_prompt()
		print("Player at tavern entrance - Press E to enter")

func _on_body_exited(body: Node3D) -> void:
	if _is_player(body):
		player_in_zone = false
		_sync_prompt()

## The door's floating "Press E" label draws through walls and trees (no depth test), so it shows
## only while the player stands in the zone (review 2026-10-03).
func _sync_prompt() -> void:
	var label := get_node_or_null("InteractionPrompt") as Label3D
	if label:
		label.visible = player_in_zone and not is_transitioning

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
	_sync_prompt()
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
	var zui_script = preload("res://scripts/game/ZonePromptUI.gd")
	var zone_ui = zui_script.find(get_tree())
	if zone_ui:
		zone_ui.clear_all_zones()
	get_tree().change_scene_to_file(interior_scene_path)
