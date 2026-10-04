# player.gd
# Player controller: movement, jumping, patron interaction, and animations.
# Story 25.31 (AC 5, V10): the body comes from data/characters/player.json (read with FileAccess: no autoload), never a
# node baked into Player.tscn: model_path, then fallback_model_path, then LAST_RESORT_BODY (the old KayKit Rogue), with
# a "[Player] fallback:" warning. It is added before the model is aligned and the animations are set up, keeps the old
# Rogue's yaw (BODY_YAW_DEG), and on its own body takes anime_look.gd's toon look when look is "realistic" (or
# "anime"). Running_A plays at speed / run_ground_speed (V9: the clip's measured ground speed on that body), so the feet
# don't skate at the gameplay speed; Idle at 1.0; a fallback body plays at 1.0.
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
const PLAYER_DATA := "res://data/characters/player.json"
## The body when player.json's model and fallback are both missing or broken (the pre-25.31 body).
const LAST_RESORT_BODY := "res://assets/characters/models/kaykit_adventurers/Rogue.glb"
const ANIME_LOOK := "res://scripts/game/anime_look.gd"
const LOOKS := ["anime", "realistic"]
## The old Rogue node's yaw in Player.tscn (degrees about Y): the body keeps it.
const BODY_YAW_DEG := 172.07
const DialogueRunner := preload("res://scripts/dialogue/dialogue_runner.gd")

# =============================================================================
# STATE
# =============================================================================
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var nearby_patrons: Array = []
var is_moving: bool = false

# =============================================================================
# NODE REFERENCES
# =============================================================================
## Where the body comes from (tests point it at a fixture before the player enters the tree).
@export var data_path := PLAYER_DATA

var body_model: Node3D = null
var body_path := ""                 # the scene the body was instanced from
var body_look := ""                 # the look applied ("" on a fallback or an imported-look body)
var using_fallback := false
var run_rate := 1.0                 # Running_A's playback rate (speed / run_ground_speed on his own body)
@onready var animation_player: AnimationPlayer = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready():
	# Add to player group for easy identification
	add_to_group("player")
	
	print("Player controller ready")
	print("   Position: ", global_position)
	print("   Controls: WASD/ZQSD Move | E Interact | Space Jump")
	
	# Setup model
	_load_body()
	if body_model:
		_align_model_to_collision()
		_disable_model_collision(body_model)
		_setup_animations()
	else:
		push_warning("[Player] missing: no body could be loaded")


## The body from player.json: model_path, fallback_model_path, then LAST_RESORT_BODY (a missing file or a scene
## whose root is not a Node3D moves on to the next).
func _load_body() -> void:
	var spec := {}
	if FileAccess.file_exists(data_path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(data_path))
		if d is Dictionary:
			spec = d
	if spec.is_empty():
		push_warning("[Player] fallback: %s is missing or not an object" % data_path)
	var tried := []
	for p in [str(spec.get("model_path", "")), str(spec.get("fallback_model_path", "")), LAST_RESORT_BODY]:
		if p == "":
			continue
		var scene = load(p) if ResourceLoader.exists(p) else null
		var inst: Node = (scene as PackedScene).instantiate() if scene is PackedScene else null
		if inst is Node3D:
			body_model = inst as Node3D
			body_path = p
			break
		if inst:
			inst.free()
		tried.append(p)
	if body_model == null:
		return
	using_fallback = body_path != str(spec.get("model_path", ""))
	if using_fallback:
		push_warning("[Player] fallback: body %s is missing, using '%s'" % [tried, body_path])
	body_model.name = "Body"
	body_model.rotation.y = deg_to_rad(BODY_YAW_DEG)
	add_child(body_model)
	if using_fallback:
		return
	var look := str(spec.get("look", ""))
	if look in LOOKS:
		var look_script = load(ANIME_LOOK) if ResourceLoader.exists(ANIME_LOOK) else null
		if look_script is Script:
			look_script.apply(body_model)
			body_look = look
		else:
			push_warning("[Player] missing: the look script %s; the body keeps its imported look" % ANIME_LOOK)
	elif look != "":
		push_warning("[Player] unknown look '%s'; the body keeps its imported look" % look)
	var ground = spec.get("run_ground_speed")
	if (ground is float or ground is int) and is_finite(float(ground)) and float(ground) > 0.0:
		run_rate = speed / float(ground)

func _setup_animations():
	"""Find and configure the AnimationPlayer of the body"""
	animation_player = body_model.get_node_or_null("AnimationPlayer")
	
	if not animation_player:
		# Try searching recursively
		animation_player = _find_animation_player(body_model)
	
	if animation_player:
		print("Found AnimationPlayer with animations:")
		for anim_name in animation_player.get_animation_list():
			print("   - ", anim_name)
		
		# Start with idle animation
		_play_animation("Idle")
	else:
		push_warning("[Player] missing: no AnimationPlayer in the body %s" % body_path)

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
		if body_model:
			var target_rot = atan2(direction.x, direction.z)
			body_model.rotation.y = lerp_angle(body_model.rotation.y, target_rot, rotation_speed * delta)
	else:
		velocity.x = 0
		velocity.z = 0
		is_moving = false
	
	# Handle animation state changes
	if was_moving != is_moving:
		_update_movement_animation()
	
	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor() and not _jump_blocked():
		velocity.y = jump_velocity
	
	move_and_slide()

func _jump_blocked() -> bool:
	"""No jump while a screen holds the player (a dialogue box, a popup), nor on the frame a dialogue box
	closed: Space is ui_accept too, and the press that ended the conversation must not also jump (Story 10.2)."""
	for node in get_tree().get_nodes_in_group("blocks_player"):
		if node.visible:
			return true
	return DialogueRunner.just_closed()

func _get_input_direction() -> Vector2:
	"""Get normalized 2D input direction"""
	for node in get_tree().get_nodes_in_group("blocks_player"):
		if node.visible:
			return Vector2.ZERO

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
	
	animation_player.play(anim_name, blend_time, run_rate if anim_name == "Running_A" else 1.0)

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
	if not get_tree().get_nodes_in_group("dialogue_open").is_empty():   # the dialogue box has Enter/Space (Story 10.2)
		return
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
			print("Served: ", closest.patron_name if closest.get("patron_name") else closest.name)
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
	if not collision_shape or not body_model:
		return
	
	var shape = collision_shape.shape
	if shape is CapsuleShape3D:
		var capsule_bottom = -shape.height / 2
		body_model.position.y = capsule_bottom
		print("Model aligned to collision bottom: ", capsule_bottom)

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
