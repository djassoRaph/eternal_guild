# ZonePromptUI.gd
# Per-scene CanvasLayer — add as a child of any scene that needs zone prompts.
# Zones register themselves via the "zone_prompt_ui" group.
#
# One E owner (Story 25.10, decision J6): each frame the UI picks the E target — the NEAREST of the
# registered zones the player overlaps (flat distance to each zone's anchor, 0.2 m hysteresis) — and
# shows only its prompt. Zones that act on E ask owns_e(self) first, so one key press never does two
# things where zones crowd together (the hearth's fire, the cat and Den Fa sit within 2.5 m). owns_e()
# is also closed by a gate decided once per frame: a patron waiting to be served in range (they take E
# first, zone_interactions.gd), a paused tree, Game Over, or an open mission screen. Because the gate is
# cached, input handled this frame sees the state from before any serve that same press made. While the
# gate is closed the prompt is hidden too, so it never names an action E won't do.
extends CanvasLayer

const HYSTERESIS := 0.2   # metres: the current E target keeps it unless another is nearer by more than this

var prompt_label: Label
var active: bool = false
var current_zone: Area3D = null          # the current E target (kept for older callers)
var connected_zones: Dictionary = {}     # zone -> prompt text
var _anchors: Dictionary = {}            # zone -> Node3D or Vector3 (null: the zone's first shape)
var _hooked: Dictionary = {}             # zone -> [entered, exited, exiting] callables connected to it
var _player_ref: Node3D = null           # the player, cached (group "player", else a node named "Player")
var _gate := true
var _label_mine := false                 # the label shows a zone's prompt (not a manual show_prompt)

static func find(tree: SceneTree) -> Node:
	var nodes = tree.get_nodes_in_group("zone_prompt_ui")
	return nodes[0] if not nodes.is_empty() else null

func _ready():
	layer = 100
	add_to_group("zone_prompt_ui")
	create_prompt_ui()
	print("ZonePromptUI ready")

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

func register_zone(zone: Area3D, prompt_text: String, anchor = null) -> void:
	"""Register an Area3D zone with its prompt text; the anchor (Node3D or Vector3) is where distance to
	the player is measured (default: the zone's first CollisionShape3D)."""
	if not zone:
		push_warning("ZonePromptUI: Attempted to register null zone")
		return

	if connected_zones.has(zone):
		if anchor != null:
			_anchors[zone] = anchor
		print("Zone already registered: ", zone.name)
		return

	connected_zones[zone] = prompt_text
	_anchors[zone] = anchor
	_hook(zone)
	print("Registered zone: ", zone.name, " -> '", prompt_text, "'")

func set_anchor(zone: Area3D, anchor) -> void:
	"""Move a registered zone's distance anchor (e.g. the hearth's interact_point for the fire)."""
	if connected_zones.has(zone):
		_anchors[zone] = anchor

func claim(zone: Area3D, prompt_text: String, anchor = null) -> void:
	"""Register or update a zone that comes and goes (the cat, Den Fa): sticky until release()."""
	if not zone:
		return
	connected_zones[zone] = prompt_text
	_anchors[zone] = anchor
	_hook(zone)

func release(zone: Area3D) -> void:
	unregister_zone(zone)

func unregister_zone(zone: Area3D) -> void:
	"""Unregister a zone (call before freeing if needed)"""
	if not zone or not connected_zones.has(zone):
		return
	connected_zones.erase(zone)
	_anchors.erase(zone)
	if current_zone == zone:
		current_zone = null
		_refresh_label()
	print("Unregistered zone: ", zone.name)

func owns_e(zone: Area3D) -> bool:
	"""True while this zone is the E target and nothing else (patron, pause, Game Over, mission screen)
	takes the key. Decided once per frame in _process."""
	return _gate and zone != null and zone == current_zone and not get_tree().paused

func show_prompt(text: String) -> void:
	"""Manually show a prompt (for non-Area3D use cases)"""
	prompt_label.text = text
	prompt_label.visible = true
	active = true
	_label_mine = false

func hide_prompt() -> void:
	"""Manually hide the prompt"""
	prompt_label.visible = false
	active = false
	current_zone = null
	_label_mine = false

func is_active() -> bool:
	"""Check if a prompt is currently showing"""
	return active

func get_current_zone() -> Area3D:
	"""Get the current E target (the nearest zone the player is in), if any"""
	return current_zone

# =============================================================================
# THE E TARGET, ONCE PER FRAME
# =============================================================================

func _process(_delta: float) -> void:
	var player := _find_player()
	var best: Area3D = null
	var best_d := INF
	var keep_d := INF
	if player and player.is_inside_tree():
		for z in connected_zones.keys():
			if not is_instance_valid(z):
				connected_zones.erase(z)
				_anchors.erase(z)
				continue
			var area := z as Area3D
			if not area.is_inside_tree() or not area.monitoring or not area.overlaps_body(player):
				continue
			var d := _flat_distance(player.global_position, _anchor_position(area))
			if area == current_zone:
				keep_d = d
			if d < best_d:
				best_d = d
				best = area
	if best != null and best != current_zone and keep_d < INF and best_d > keep_d - HYSTERESIS:
		best = current_zone
	current_zone = best
	_gate = player != null and _gate_open(player)
	_refresh_label()

func _find_player() -> Node3D:
	if _player_ref and is_instance_valid(_player_ref) and _player_ref.is_inside_tree():
		return _player_ref
	_player_ref = get_tree().get_first_node_in_group("player") as Node3D
	if _player_ref == null and get_tree().current_scene:
		_player_ref = get_tree().current_scene.find_child("Player", true, false) as Node3D
	return _player_ref

func _gate_open(player: Node3D) -> bool:
	if get_tree().paused:
		return false
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.get("game_over_active"):
		return false
	for board in get_tree().get_nodes_in_group("mission_board"):
		if board.get("visible"):
			return false
	for p in get_tree().get_nodes_in_group("patrons"):
		if p.has_method("can_be_served_by") and p.can_be_served_by(player.global_position):
			return false
	return true

func _anchor_position(zone: Area3D) -> Vector3:
	var a = _anchors.get(zone)
	if a is Vector3:
		return a
	if a != null and is_instance_valid(a) and a is Node3D:
		return (a as Node3D).global_position
	for c in zone.get_children():
		if c is CollisionShape3D:
			return (c as CollisionShape3D).global_position
	return zone.global_position

static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _refresh_label() -> void:
	if current_zone != null and _gate and connected_zones.has(current_zone):
		prompt_label.text = connected_zones[current_zone]
		prompt_label.visible = true
		active = true
		_label_mine = true
	elif _label_mine:
		prompt_label.visible = false
		active = false
		_label_mine = false

func _hook(zone: Area3D) -> void:
	if _hooked.has(zone):
		return
	var calls := [_on_zone_entered.bind(zone), _on_zone_exited.bind(zone), _on_zone_freed.bind(zone)]
	_hooked[zone] = calls
	zone.body_entered.connect(calls[0])
	zone.body_exited.connect(calls[1])
	zone.tree_exiting.connect(calls[2])

func _unhook(zone: Area3D) -> void:
	var calls = _hooked.get(zone)
	_hooked.erase(zone)
	if calls == null or not is_instance_valid(zone):
		return
	for pair in [[zone.body_entered, calls[0]], [zone.body_exited, calls[1]], [zone.tree_exiting, calls[2]]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])

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
# INTERNAL SIGNAL HANDLERS (logging only: _process decides the prompt)
# =============================================================================

func _on_zone_entered(body: Node3D, zone: Area3D) -> void:
	if _is_player(body):
		print("Player entered zone: ", zone.name)

func _on_zone_exited(body: Node3D, zone: Area3D) -> void:
	if _is_player(body):
		print("Player exited zone: ", zone.name)

func _on_zone_freed(zone: Area3D) -> void:
	"""Clean up when a zone leaves the tree (freed or moved): it must register or claim again"""
	_unhook(zone)
	if connected_zones.has(zone):
		connected_zones.erase(zone)
		_anchors.erase(zone)
		if current_zone == zone:
			current_zone = null
			_refresh_label()
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
		_anchors.clear()
		current_zone = null

func clear_all_zones() -> void:
	"""Call this before scene transitions to clean up"""
	connected_zones.clear()
	_anchors.clear()
	current_zone = null
	_gate = false
	hide_prompt()
	print("All zones cleared")
