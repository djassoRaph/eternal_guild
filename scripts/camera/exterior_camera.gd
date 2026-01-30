# exterior_camera.gd
# Attach to Camera3D in ExteriorWorld scene
# Follows player with isometric perspective
extends Camera3D


@export var follow_speed: float = 5.0
@export var camera_offset: Vector3 = Vector3(15, 20, 15)
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 15.0
@export var max_zoom: float = 40.0

var player: CharacterBody3D = null
var target_zoom: float = 25.0


func _ready() -> void:
	print("📷 ExteriorCamera: Initializing...")
	
	# Set up orthographic isometric view
	projection = PROJECTION_ORTHOGONAL
	size = 25.0
	target_zoom = size
	
	# Isometric rotation (same as interior camera)
	rotation_degrees = Vector3(-30, 45, 0)
	
	# Make this camera current
	current = true
	
	# Find player after a short delay
	await get_tree().process_frame
	await get_tree().process_frame
	_find_player()
	
	print("📷 ExteriorCamera: Ready")


func _find_player() -> void:
	# Try group first
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		print("📷 ExteriorCamera: Found player via group")
		return
	
	# Search scene
	var root = get_tree().current_scene
	player = _search_for_player(root)
	
	if player:
		print("📷 ExteriorCamera: Found player: ", player.name)
	else:
		print("📷 ExteriorCamera: No player found yet, will keep looking...")


func _search_for_player(node: Node) -> CharacterBody3D:
	if node.name == "Player" and node is CharacterBody3D:
		return node
	for child in node.get_children():
		var found = _search_for_player(child)
		if found:
			return found
	return null


func _unhandled_input(event: InputEvent) -> void:
	# Mouse wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = max(min_zoom, target_zoom - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = min(max_zoom, target_zoom + zoom_speed)


func _process(delta: float) -> void:
	# Keep trying to find player
	if not player or not is_instance_valid(player):
		_find_player()
		return
	
	# Smooth zoom
	size = lerp(size, target_zoom, 8.0 * delta)
	
	# Follow player
	var target_pos = player.global_position + camera_offset
	global_position = global_position.lerp(target_pos, follow_speed * delta)
