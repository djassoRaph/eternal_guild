extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

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
	
	# Store the y-velocity to re-apply it later
	var y_velocity = velocity.y
	
	# Apply horizontal movement
	velocity = direction * speed
	
	# Re-apply the y-velocity
	velocity.y = y_velocity
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	# Move the character
	move_and_slide()
