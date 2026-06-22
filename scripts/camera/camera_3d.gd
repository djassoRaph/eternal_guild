# camera_3d.gd
# Attach to Camera3D inside SubViewport in MainTavern
# Follows player with isometric perspective and zoom control
extends Camera3D


@export var follow_speed: float = 5.0
@export var camera_offset: Vector3 = Vector3(8, 8, 8)
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 8.0
@export var max_zoom: float = 25.0
@export var zoom_smoothing: float = 8.0

var player: CharacterBody3D = null
var target_zoom: float = 12.0


func _ready() -> void:
	print("Interior Camera: Initializing...")
	
	# Set up orthographic isometric projection
	projection = PROJECTION_ORTHOGONAL
	size = 12.0
	target_zoom = size
	
	# Set rotation for isometric view (should already be set in editor, but ensure it)
	# rotation_degrees = Vector3(-30, 45, 0)  # Uncomment if needed
	
	# Set cull mask to see player (layer 1) and patrons (layer 2)
	cull_mask = 3  # Binary: 0b11 = layers 1 and 2
	print("Interior Camera: Cull mask set to ", cull_mask)
	
	# Find player
	_find_player()
	
	if player:
		print("Interior Camera: Found player at start")
	else:
		print("Interior Camera: Will search for player...")


func _find_player() -> void:
	"""Find player using multiple methods"""
	
	# Method 1: Check group
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		print("Interior Camera: Found player via group: ", player.get_path())
		return
	
	# Method 2: Search in same viewport
	var viewport = get_viewport()
	if viewport:
		for child in viewport.get_children():
			var found = _search_recursive(child)
			if found:
				player = found
				print("Interior Camera: Found player in viewport: ", player.get_path())
				return
	
	# Method 3: Search entire scene
	var root = get_tree().current_scene
	if root:
		var found = _search_recursive(root)
		if found:
			player = found
			print("Interior Camera: Found player in scene: ", player.get_path())
			return
	
	# Method 4: Ask PlayerManager
	var pm = get_node_or_null("/root/PlayerManager")
	if pm and pm.has_method("get_player"):
		var pm_player = pm.get_player()
		if pm_player and is_instance_valid(pm_player):
			player = pm_player
			print("Interior Camera: Got player from PlayerManager")
			return


func _search_recursive(node: Node) -> CharacterBody3D:
	"""Recursively search for player node"""
	if node.name == "Player" and node is CharacterBody3D:
		return node
	
	for child in node.get_children():
		var found = _search_recursive(child)
		if found:
			return found
	
	return null


func _unhandled_input(event: InputEvent) -> void:
	"""Handle mouse wheel zoom"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = max(min_zoom, target_zoom - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = min(max_zoom, target_zoom + zoom_speed)


func _process(delta: float) -> void:
	# Keep trying to find player if we don't have one
	if not player or not is_instance_valid(player):
		_find_player()
		if not player:
			return
	
	# Smooth zoom
	size = lerp(size, target_zoom, zoom_smoothing * delta)
	
	# Calculate target position (player + offset)
	var target_position = player.global_position + camera_offset
	
	# Smoothly move camera to follow player
	global_position = global_position.lerp(target_position, follow_speed * delta)
