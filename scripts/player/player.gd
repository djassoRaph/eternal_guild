extends CharacterBody3D
#player.gd
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var target_rotation = 0.0


var nearby_patrons: Array[RealisticPatron] = []
var interaction_range = 2.5

const SPEED = 6.0
const JUMP_VELOCITY = 4.5
const ROTATION_SPEED = 10.0


# Reference to the Rogue model for rotation
@onready var rogue_model = $Rogue

func _ready():
	print("Player controller ready - WASD: Move | E: Interact/Serve | Space: Jump")
	print("PLAYER SCRIPT IS RUNNING!")
	print("Position: ", global_position)
	print("Collision Layer: ", collision_layer)
	print("Collision Mask: ", collision_mask)
	
	# Align Rogue position if needed
	align_rogue_to_collision()
	
	# Disable any conflicting collision in Rogue model
	disable_rogue_collision_recursive(rogue_model)

func _physics_process(delta: float) -> void:
	# Get input as 2D vector first
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("move_forward"): # Z
		input_dir.y += 1  # Screen "up"
	if Input.is_action_pressed("move_backward"):   # S
		input_dir.y -= 1  # Screen "down"
	if Input.is_action_pressed("move_left"):  # Q
		input_dir.x -= 1  # Screen "left"
	if Input.is_action_pressed("move_right"): # D
		input_dir.x += 1  # Screen "right"
	
	# Convert 2D input to 3D isometric movement
	var direction = Vector3.ZERO
	if input_dir.length() > 0:
		# Isometric directions (matching your camera angle)
		var forward = Vector3(-1, 0, -1).normalized()  # Screen "up"
		var right = Vector3(1, 0, -1).normalized()     # Screen "right"
		
		direction = forward * input_dir.y + right * input_dir.x
		direction = direction.normalized()
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Only reset Y velocity when on ground
		if velocity.y < 0:
			velocity.y = 0
	
	# Apply horizontal movement WITHOUT affecting Y velocity
	if direction.length() > 0:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = 0
		velocity.z = 0
	
	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	# Rotate Rogue model to face movement direction
	if rogue_model and direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		rogue_model.rotation.y = lerp_angle(rogue_model.rotation.y, target_rotation, 5.0 * delta)
	
	# Move the character
	move_and_slide()


func handle_interaction():
	"""Handle interaction with NPCs and environment"""
	if Input.is_action_just_pressed("ui_select"):  # E key by default
		print("E key pressed - looking for patrons to serve...")



func find_serveable_patrons() -> Array[RealisticPatron]:
	"""Find all patrons within serving range that want service - FIXED FUNCTION"""
	var serveable: Array[RealisticPatron] = []
	
	# Method 1: Check PatronSpawner children
	var patron_spawner = get_node_or_null("../PatronSpawner")
	if patron_spawner:
		print("Found PatronSpawner, checking children...")
		for child in patron_spawner.get_children():
			if child is RealisticPatron:
				var patron = child as RealisticPatron
				var distance = global_position.distance_to(patron.global_position)
				print("Checking patron at distance: ", distance)
				
				if patron.can_be_served_by(global_position):
					serveable.append(patron)
					print("Added serveable patron!")
	else:
		print("PatronSpawner not found at ../PatronSpawner")
	
	# Method 2: Search entire scene tree for patrons (fallback)
	if serveable.size() == 0:
		print("Searching entire scene tree for patrons...")
		search_tree_for_patrons(get_tree().current_scene, serveable)
	
	return serveable


func search_tree_for_patrons(node: Node, serveable_array: Array[RealisticPatron]):
	"""Recursively search scene tree for RealisticPatron nodes"""
	if node is RealisticPatron:
		var patron = node as RealisticPatron
		if patron.can_be_served_by(global_position):
			serveable_array.append(patron)
			print("Found serveable patron in scene tree!")
	
	# Search children recursively
	for child in node.get_children():
		search_tree_for_patrons(child, serveable_array)


func _on_area_3d_body_entered(body):
	"""Handle entering interaction range with NPCs"""
	if body is RealisticPatron:
		nearby_patrons.append(body)
		print("Patron entered interaction range")
		
		
		
func _on_area_3d_body_exited(body):
	"""Handle leaving interaction range with NPCs"""
	if body is RealisticPatron and body in nearby_patrons:
		nearby_patrons.erase(body)
		print("Patron left interaction range")
		




func align_rogue_to_collision():
	"""Align Rogue model to collision shape"""
	if rogue_model:
		var collision_shape = $CollisionShape3D.shape as CapsuleShape3D
		if collision_shape:
			var capsule_bottom = -collision_shape.height / 2
			rogue_model.position.y = capsule_bottom
			print("Aligned Rogue to collision bottom: ", capsule_bottom)

func disable_rogue_collision_recursive(node: Node):
	"""Disable all collision in Rogue model to prevent conflicts"""
	if not node:
		return
		
	for child in node.get_children():
		if child is CollisionShape3D:
			child.disabled = true
			print("Disabled collision: " + str(child.get_path()))
		elif child is CharacterBody3D or child is StaticBody3D or child is RigidBody3D:
			# Disable collision layers for physics bodies
			child.collision_layer = 0
			child.collision_mask = 0
			print("Disabled physics body: " + str(child.get_path()))
		
		# Recurse into children
		disable_rogue_collision_recursive(child)

func _input(event):
	"""Debug controls"""
	if event.is_action_pressed("ui_accept"):  # Spacebar
		debug_positions()
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F7:  # Debug key
			print_debug_info()
		

func print_debug_info():
	"""Print debug information about player state"""
	print("=== PLAYER DEBUG ===")
	print("Position: ", global_position)
	print("Velocity: ", velocity)
	print("On floor: ", is_on_floor())
	print("Nearby patrons: ", nearby_patrons.size())
	print("==================")

func get_player_position() -> Vector3:
	return global_position



func debug_positions():
	"""Debug position alignment"""
	print("=== DEBUG INFO ===")
	print("Player global position: ", global_position)
	print("Player velocity: ", velocity)
	print("On floor: ", is_on_floor())
	if rogue_model:
		print("Rogue local position: ", rogue_model.position)
		print("Rogue global position: ", rogue_model.global_position)
