extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Reference to the Rogue model for rotation
@onready var rogue_model = $Rogue

func _ready():
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
	if Input.is_action_pressed("move_forward"):
		input_dir.y += 1  # Screen "up"
	if Input.is_action_pressed("move_backward"):  
		input_dir.y -= 1  # Screen "down"
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1  # Screen "left"
	if Input.is_action_pressed("move_right"):
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

func debug_positions():
	"""Debug position alignment"""
	print("=== DEBUG INFO ===")
	print("Player global position: ", global_position)
	print("Player velocity: ", velocity)
	print("On floor: ", is_on_floor())
	if rogue_model:
		print("Rogue local position: ", rogue_model.position)
		print("Rogue global position: ", rogue_model.global_position)
