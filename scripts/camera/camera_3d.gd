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
		projection = PROJECTION_ORTHOGONAL
		size = 15
		rotation_degrees = Vector3(-30, 45, 0)
		target_zoom = size 
		cull_mask = 3  # Binary: 0b00000011 (bits 0 and 1 = layers 1 and 2)
		print("✅ Camera cull_mask set to see layers 1 and 2")
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
			
# In camera_3d.gd, change _input to _unhandled_input
func _unhandled_input(event):
	"""Handle mouse wheel zoom - uses unhandled to avoid UI conflicts"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = max(min_zoom, target_zoom - zoom_speed)
			get_viewport().set_input_as_handled()  # Mark as handled
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = min(max_zoom, target_zoom + zoom_speed)
			get_viewport().set_input_as_handled()

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
