# player.gd
# Player controller with KayKit animation support
# Supports: Movement, jumping, patron interaction, and animations
extends CharacterBody3D

# =============================================================================
# EXPORTS
# =============================================================================
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var rotation_speed: float = 10.0

# =============================================================================
# CONSTANTS
# =============================================================================
const INTERACTION_RANGE = 2.5

# =============================================================================
# STATE
# =============================================================================
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var nearby_patrons: Array = []
var is_moving: bool = false

# =============================================================================
# NODE REFERENCES
# =============================================================================
@onready var rogue_model: Node3D = $Rogue
@onready var animation_player: AnimationPlayer = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready():
	# Add to player group for easy identification
	add_to_group("player")
	
	print("✅ Player controller ready")
	print("   Position: ", global_position)
	print("   Controls: WASD/ZQSD Move | E Interact | Space Jump")
	
	# Setup model
	if rogue_model:
		_align_model_to_collision()
		_disable_model_collision(rogue_model)
		_setup_animations()
	else:
		push_warning("Player: Rogue model not found!")

func _setup_animations():
	"""Find and configure the AnimationPlayer from the Rogue model"""
	# KayKit models have AnimationPlayer as a child
	animation_player = rogue_model.get_node_or_null("AnimationPlayer")
	
	if not animation_player:
		# Try searching recursively
		animation_player = _find_animation_player(rogue_model)
	
	if animation_player:
		print("✅ Found AnimationPlayer with animations:")
		for anim_name in animation_player.get_animation_list():
			print("   - ", anim_name)
		
		# Start with idle animation
		_play_animation("Idle")
	else:
		push_warning("Player: No AnimationPlayer found in Rogue model")

func _find_animation_player(node: Node) -> AnimationPlayer:
	"""Recursively search for AnimationPlayer"""
	if node is AnimationPlayer:
		return node
	
	for child in node.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
	
	return null

# =============================================================================
# PHYSICS & MOVEMENT
# =============================================================================

func _physics_process(delta: float) -> void:
	# Get input as 2D vector
	var input_dir = _get_input_direction()
	
	# Convert to isometric 3D movement
	var direction = _input_to_isometric(input_dir)
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0:
		velocity.y = 0
	
	# Apply horizontal movement
	var was_moving = is_moving
	if direction.length() > 0.1:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		is_moving = true
		
		# Rotate model to face movement direction
		if rogue_model:
			var target_rot = atan2(direction.x, direction.z)
			rogue_model.rotation.y = lerp_angle(rogue_model.rotation.y, target_rot, rotation_speed * delta)
	else:
		velocity.x = 0
		velocity.z = 0
		is_moving = false
	
	# Handle animation state changes
	if was_moving != is_moving:
		_update_movement_animation()
	
	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	move_and_slide()

func _get_input_direction() -> Vector2:
	"""Get normalized 2D input direction"""
	var input = Vector2.ZERO
	
	if Input.is_action_pressed("move_forward"):  # W or Z
		input.y += 1
	if Input.is_action_pressed("move_backward"):  # S
		input.y -= 1
	if Input.is_action_pressed("move_left"):  # A or Q
		input.x -= 1
	if Input.is_action_pressed("move_right"):  # D
		input.x += 1
	
	return input.normalized() if input.length() > 0 else input

func _input_to_isometric(input: Vector2) -> Vector3:
	"""Convert 2D screen input to 3D isometric world direction"""
	if input.length() < 0.1:
		return Vector3.ZERO
	
	# Isometric axes (matching camera angle)
	var forward = Vector3(-1, 0, -1).normalized()  # Screen "up"
	var right = Vector3(1, 0, -1).normalized()     # Screen "right"
	
	var direction = forward * input.y + right * input.x
	return direction.normalized()

# =============================================================================
# ANIMATION
# =============================================================================

func _play_animation(anim_name: String, blend_time: float = 0.2) -> void:
	if not animation_player:
		return
	if not animation_player.has_animation(anim_name):
		push_warning("Player: Animation not found: ", anim_name)
		return
	if animation_player.current_animation == anim_name:
		return
	
	var anim = animation_player.get_animation(anim_name)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR
	
	animation_player.play(anim_name, blend_time)

func _update_movement_animation() -> void:
	"""Update animation based on movement state"""
	if is_moving:
		_play_animation("Running_A")
	else:
		_play_animation("Idle")

# =============================================================================
# INTERACTION
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	# E key interaction is handled by zone_interactions.gd
	# This is a backup for direct patron interaction
	if event.is_action_pressed("ui_accept"):
		_try_interact_with_patron()

func try_serve_nearby_patron() -> RealisticPatron:
	"""Find and serve nearby patrons - called by zone_interactions.gd"""
	var all_patrons = get_tree().get_nodes_in_group("patrons")
	
	if all_patrons.is_empty():
		return null
	
	# Find patrons that want service and are close enough
	var serveable: Array = []
	for patron in all_patrons:
		if patron.has_method("can_be_served_by") and patron.can_be_served_by(global_position):
			serveable.append(patron)
	
	if serveable.is_empty():
		return null
	
	# Find closest
	var closest = serveable[0]
	var closest_dist = global_position.distance_to(closest.global_position)
	
	for patron in serveable:
		var dist = global_position.distance_to(patron.global_position)
		if dist < closest_dist:
			closest = patron
			closest_dist = dist
	
	# Attempt service
	if closest.has_method("serve_patron"):
		var success = closest.serve_patron()
		if success:
			print("✅ Served: ", closest.patron_name if closest.get("patron_name") else closest.name)
			return closest
	
	return null

func _try_interact_with_patron() -> void:
	"""Backup patron interaction via ui_accept"""
	var patron = try_serve_nearby_patron()
	if patron:
		if GameManager and GameManager.has_method("serve_customer_beer"):
			GameManager.serve_customer_beer()

func get_closest_patron_in_range() -> RealisticPatron:
	"""Get the closest patron within interaction range"""
	var closest: RealisticPatron = null
	var min_distance = INF
	
	for patron in nearby_patrons:
		if not is_instance_valid(patron):
			continue
		var distance = global_position.distance_to(patron.global_position)
		if distance < min_distance:
			min_distance = distance
			closest = patron
	
	if closest and min_distance <= INTERACTION_RANGE:
		return closest
	return null

# =============================================================================
# MODEL SETUP
# =============================================================================

func _align_model_to_collision() -> void:
	"""Align model to stand at the bottom of collision capsule"""
	var collision_shape = get_node_or_null("CollisionShape3D")
	if not collision_shape or not rogue_model:
		return
	
	var shape = collision_shape.shape
	if shape is CapsuleShape3D:
		var capsule_bottom = -shape.height / 2
		rogue_model.position.y = capsule_bottom
		print("✅ Model aligned to collision bottom: ", capsule_bottom)

func _disable_model_collision(node: Node) -> void:
	"""Recursively disable collision on model children to prevent conflicts"""
	if not node:
		return
	
	for child in node.get_children():
		if child is CollisionShape3D:
			child.disabled = true
		elif child is PhysicsBody3D:
			child.collision_layer = 0
			child.collision_mask = 0
		
		_disable_model_collision(child)
