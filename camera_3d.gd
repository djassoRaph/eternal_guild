# FollowCamera.gd - Attach to Camera3D at root level
extends Camera3D

@export var follow_speed: float = 5.0
@export var camera_offset: Vector3 = Vector3(8, 8, 8)

@export var zoom_speed: float = 2.0
@export var min_zoom: float = 8.0   # Close zoom
@export var max_zoom: float = 25.0  # Far zoom
@export var zoom_smoothing: float = 8.0

var player: CharacterBody3D
var target_zoom: float


func _ready():
	# Find the player
	player = find_player_node()
	
	if player:
		print("✓ Camera found player: ", player.name)
		# Set camera to isometric view
		projection = PROJECTION_ORTHOGONAL
		size = 15
		rotation_degrees = Vector3(-30, 45, 0)
		target_zoom = size  # Add this line!
	else:
		print("❌ Camera could not find player!")

func _input(event):
	"""Handle mouse wheel zoom"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Zoom in (smaller size = closer view)
			target_zoom = max(min_zoom, target_zoom - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom out (larger size = farther view)  
			target_zoom = min(max_zoom, target_zoom + zoom_speed)

func find_player_node() -> CharacterBody3D:
	"""Search entire scene for CharacterBody3D named Player"""
	print("🔍 Searching entire scene for Player...")
	var root_node = get_tree().current_scene
	return find_player_recursive(root_node)

func find_player_recursive(node: Node) -> CharacterBody3D:
	"""Recursively search for player"""
	print("Checking node: ", node.name, " (", node.get_class(), ")")
	
	if node.name == "Player" and node is CharacterBody3D:
		print("✓ Found player at path: ", node.get_path())
		return node
	
	for child in node.get_children():
		var result = find_player_recursive(child)
		if result:
			return result
	
	return null

func _process(delta):
	"""Follow the player smoothly and handle zoom"""
	if not player:
		return
	
	# Smooth zoom
	size = lerp(size, target_zoom, zoom_smoothing * delta)
	
	# Calculate where camera should be
	var target_position = player.global_position + camera_offset
	
	# Move camera smoothly to that position
	global_position = global_position.lerp(target_position, follow_speed * delta)
