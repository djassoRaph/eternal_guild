# ZonePromptUI.gd
# AUTOLOAD SINGLETON - Add to Project Settings > Autoload
# Shows 2D prompt at bottom of screen when player enters zones
# Scene-agnostic: works in any scene, zones register themselves
extends CanvasLayer

var prompt_label: Label
var active: bool = false
var current_zone: Area3D = null

# Track connected zones to avoid duplicate connections
var connected_zones: Dictionary = {}

func _ready():
	# Set layer high so it appears above game UI
	layer = 100
	create_prompt_ui()
	print("ZonePromptUI singleton ready")

func create_prompt_ui():
	"""Create the 2D prompt label"""
	prompt_label = Label.new()
	prompt_label.name = "ZonePromptLabel"
	add_child(prompt_label)
	
	# Position at bottom center of screen
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_top = 1.0
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_bottom = 1.0
	prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_label.offset_left = -300
	prompt_label.offset_top = -100
	prompt_label.offset_right = 300
	prompt_label.offset_bottom = -50
	
	# Styling
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 28)
	prompt_label.add_theme_color_override("font_color", Color(1, 1, 0))  # Yellow
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prompt_label.add_theme_constant_override("outline_size", 10)
	
	# Hide by default
	prompt_label.visible = false

# =============================================================================
# PUBLIC API - Zones call these to register/unregister
# =============================================================================

func register_zone(zone: Area3D, prompt_text: String) -> void:
	"""Register an Area3D zone with its prompt text. Zone will show prompt when player enters."""
	if not zone:
		push_warning("ZonePromptUI: Attempted to register null zone")
		return
	
	if connected_zones.has(zone):
		print("Zone already registered: ", zone.name)
		return
	
	# Store zone info
	connected_zones[zone] = prompt_text
	
	# Connect signals
	zone.body_entered.connect(_on_zone_entered.bind(zone, prompt_text))
	zone.body_exited.connect(_on_zone_exited.bind(zone))
	
	# Clean up when zone is freed
	zone.tree_exiting.connect(_on_zone_freed.bind(zone))
	
	print("Registered zone: ", zone.name, " -> '", prompt_text, "'")

func unregister_zone(zone: Area3D) -> void:
	"""Unregister a zone (call before freeing if needed)"""
	if not zone or not connected_zones.has(zone):
		return
	
	# Disconnect signals safely
	if zone.body_entered.is_connected(_on_zone_entered):
		zone.body_entered.disconnect(_on_zone_entered)
	if zone.body_exited.is_connected(_on_zone_exited):
		zone.body_exited.disconnect(_on_zone_exited)
	
	connected_zones.erase(zone)
	
	# Hide prompt if this was the active zone
	if current_zone == zone:
		hide_prompt()
	
	print("Unregistered zone: ", zone.name)

func show_prompt(text: String) -> void:
	"""Manually show a prompt (for non-Area3D use cases)"""
	prompt_label.text = text
	prompt_label.visible = true
	active = true

func hide_prompt() -> void:
	"""Manually hide the prompt"""
	prompt_label.visible = false
	active = false
	current_zone = null

func is_active() -> bool:
	"""Check if a prompt is currently showing"""
	return active

func get_current_zone() -> Area3D:
	"""Get the zone the player is currently in (if any)"""
	return current_zone

# =============================================================================
# LEGACY SUPPORT - For existing tavern zones
# =============================================================================

func connect_tavern_zones() -> void:
	"""Connect to existing tavern interior zones. Call this from MainTavern scene."""
	# Wait for scene to fully load
	await get_tree().process_frame
	await get_tree().process_frame
	
	var interactive_parent = get_tree().root.get_node_or_null("Node3D/SubViewportContainer/SubViewport/TavernNavigation/Interactive")
	if not interactive_parent:
		print("ZonePromptUI: Could not find Interactive parent (not in tavern?)")
		return
	
	var zone_configs = {
		"BarArea": "Press E - Tavern Management",
		"RecruitmentDesk": "Press E - Recruit Adventurers",
		"MissionBoard": "Press E - View Missions",
		"NextDayArea": "Press E - Rest & Plan",
		"FireplaceArea": "Press E - Tend Fire"
	}
	
	for zone_name in zone_configs.keys():
		var zone = interactive_parent.get_node_or_null(zone_name)
		if zone and zone is Area3D:
			register_zone(zone, zone_configs[zone_name])
		else:
			print("Could not find tavern zone: ", zone_name)
	
	print("Tavern zones connected")

# =============================================================================
# INTERNAL SIGNAL HANDLERS
# =============================================================================

func _on_zone_entered(body: Node3D, zone: Area3D, prompt_text: String) -> void:
	"""Show prompt when player enters zone"""
	if _is_player(body):
		current_zone = zone
		prompt_label.text = prompt_text
		prompt_label.visible = true
		active = true
		print("Player entered zone: ", zone.name)

func _on_zone_exited(body: Node3D, zone: Area3D) -> void:
	"""Hide prompt when player leaves zone"""
	if _is_player(body):
		# Only hide if exiting the currently active zone
		if current_zone == zone:
			prompt_label.visible = false
			active = false
			current_zone = null
			print("Player exited zone: ", zone.name)

func _on_zone_freed(zone: Area3D) -> void:
	"""Clean up when a zone is freed from tree"""
	if connected_zones.has(zone):
		connected_zones.erase(zone)
		if current_zone == zone:
			hide_prompt()
		print("Zone freed and cleaned up: ", zone.name if zone else "unknown")

func _is_player(body: Node3D) -> bool:
	"""Check if the body is the player"""
	return body.name == "Player" or body.is_in_group("player")

# =============================================================================
# SCENE CHANGE HANDLING
# =============================================================================

func _notification(what: int) -> void:
	# Clear all zones when scene changes
	if what == NOTIFICATION_PREDELETE:
		connected_zones.clear()
		current_zone = null

func clear_all_zones() -> void:
	"""Call this before scene transitions to clean up"""
	connected_zones.clear()
	hide_prompt()
	print("All zones cleared")
