#player.gd
extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


var target_rotation = 0.0

var nearby_patrons: Array[RealisticPatron] = []
var interaction_range = 2.5

const SPEED = 6.0
const JUMP_VELOCITY = 4.5
const ROTATION_SPEED = 10.0

@onready var game_manager = get_node("/root/GameManager")

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


func _unhandled_input(event):
	if event.is_action_pressed("ui_accept"):
		# Get the closest patron in range
		var closest_patron = get_closest_patron_in_range()

		# Check if a patron was found and if they can be served
		if closest_patron and closest_patron.has_method("can_be_served_by") and closest_patron.can_be_served_by(global_position):
			# Now call the serve_patron function
			closest_patron.serve_patron()
			game_manager.serve_customer_beer()
			print("✅ Player served a patron!")
		else:
			# Handle other interactions, such as buying beer at the bar
			var bar_area = get_node_or_null("TavernNavigation/Interactive/BarArea")
			if bar_area and bar_area.has_method("interact_with_player"):
				bar_area.interact_with_player()


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


func get_closest_patron_in_range() -> RealisticPatron:
	var closest_patron: RealisticPatron = null
	var min_distance = INF

	for patron in nearby_patrons:
		var distance = global_position.distance_to(patron.global_position)
		if distance < min_distance:
			min_distance = distance
			closest_patron = patron

	if closest_patron and min_distance <= interaction_range:
		return closest_patron
	return null
		
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
