# RealisticPatron.gd - FIXED MOVEMENT
extends CharacterBody3D
class_name RealisticPatron

# Movement and physics constants
const SPEED = 2.0
const GRAVITY = 9.8

# State machine enum
enum PatronState {
	WALKING_TO_TABLE,
	SITTING_WAITING,
	BEING_SERVED,
	DRINKING,
	LEAVING
}

# === OBJECT POOLING SUPPORT ===
signal patron_finished(patron_body: Node)

# State variables
var current_state = PatronState.WALKING_TO_TABLE
var current_target: Vector3

# Positions - WILL BE SET BY SPAWNER, NOT HARDCODED
var table_position: Vector3  # Set by spawner via metadata
var entrance_position: Vector3  # Set by spawner

# Service system variables
var wants_service = false
var has_been_served = false
var service_requested = false
var service_indicator: MeshInstance3D
var payment_amount: int

# Character data
var patron_name: String
var character_type: String = "Knight"
var drinking_duration: int = 8

# Timers
var sitting_timer: Timer
var drinking_timer: Timer
var departure_timer: Timer

# Scene references
var main_scene: Node

# Signals
signal patron_left
signal patron_wants_service
signal patron_served

func _ready():
	print("RealisticPatron initializing...")
	
	# Set up physics first
	setup_physics()
	
	# Get main scene reference
	main_scene = get_tree().current_scene
	
	# CRITICAL FIX: Get positions from metadata set by spawner
	if has_meta("target_table"):
		table_position = get_meta("target_table")
		print("✅ Got table position from metadata: ", table_position)
	else:
		print("⚠️ No target_table metadata! Using fallback position")
		table_position = global_position  # Stay in place as fallback
	
	# Generate patron data
	generate_patron_data()
	
	# Set initial target to table
	current_target = table_position
	
	# Create visual representation
	create_patron_model()
	
	# Create service indicator
	create_service_indicator()
	
	# Set up timers
	setup_timers()
	
	print("Patron '", patron_name, "' ready - walking to table at ", table_position)
	print("Current position: ", global_position)
	print("Distance to table: ", global_position.distance_to(table_position))

func setup_physics():
	"""Configure proper collision for patron"""
	# Set collision layers (NPCs use layer 4)
	collision_layer = 4
	collision_mask = 1  # Collide with environment
	
	# Add collision shape if not present
	if not get_children().any(func(child): return child is CollisionShape3D):
		var collision = CollisionShape3D.new()
		var shape = CapsuleShape3D.new()
		shape.height = 2.0
		shape.radius = 0.5
		collision.shape = shape
		add_child(collision)
		print("Added collision shape to patron")

func generate_patron_data():
	"""Generate new random patron data"""
	var names = ["Gareth", "Elara", "Thorin", "Lydia", "Marcus", "Sera", "Bjorn", "Isla", "Caius", "Vera"]
	var surnames = ["the Bold", "Ironforge", "Swiftblade", "Nightwhisper", "Goldbeard", "Stormwind"]
	
	patron_name = names[randi() % names.size()] + " " + surnames[randi() % surnames.size()]
	
	# Payment varies by settlement and time of day
	var base_payment = randi_range(6, 9)
	var time_bonus = 0
	
	var game_time = GameManager.current_day % 7
	if game_time == 0 or game_time == 6:
		time_bonus = randi_range(1, 3)
	
	payment_amount = base_payment + time_bonus
	
	# Settlement trait affects payment
	var settlement_trait = get_meta("settlement_trait", "")
	match settlement_trait:
		"Merchant":
			payment_amount += randi_range(2, 4)
		"Scout", "Hunter":
			payment_amount += randi_range(0, 1)
		"Scholar":
			payment_amount += randi_range(1, 2)
		"Knight", "Officer":
			payment_amount += randi_range(1, 3)
	
	print("Generated patron: ", patron_name, " will pay ", payment_amount, " gold")

func create_patron_model():
	"""Create simple visual representation"""
	var cylinder = MeshInstance3D.new()
	cylinder.name = "PatronBody"
	
	var mesh = CylinderMesh.new()
	mesh.height = 1.8
	mesh.top_radius = 0.3
	mesh.bottom_radius = 0.3
	cylinder.mesh = mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(randf(), randf(), randf())
	cylinder.material_override = material
	
	cylinder.position = Vector3(0, 0.9, 0)
	add_child(cylinder)

func create_service_indicator():
	"""Create yellow sphere above head when wanting service"""
	service_indicator = MeshInstance3D.new()
	service_indicator.name = "ServiceIndicator"
	
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	service_indicator.mesh = sphere
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.YELLOW
	material.emission = Color.YELLOW * 0.5
	service_indicator.material_override = material
	
	service_indicator.position = Vector3(0, 2.5, 0)
	service_indicator.visible = false
	add_child(service_indicator)

func setup_timers():
	"""Initialize behavior timers"""
	sitting_timer = Timer.new()
	sitting_timer.wait_time = 2.0
	sitting_timer.one_shot = true
	sitting_timer.timeout.connect(_on_sitting_timer_timeout)
	add_child(sitting_timer)
	
	drinking_timer = Timer.new()
	drinking_timer.wait_time = 8.0
	drinking_timer.one_shot = true
	drinking_timer.timeout.connect(_on_drinking_timer_timeout)
	add_child(drinking_timer)

func _physics_process(delta):
	"""Handle movement and physics"""
	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0
	
	# Handle state-based behavior
	match current_state:
		PatronState.WALKING_TO_TABLE:
			move_toward_target(delta)
		PatronState.SITTING_WAITING, PatronState.BEING_SERVED, PatronState.DRINKING:
			# Stay in place
			velocity.x = 0
			velocity.z = 0
		PatronState.LEAVING:
			move_toward_target(delta)
	
	move_and_slide()

func move_toward_target(delta):
	"""Move toward current target position - FIXED WITH BETTER DISTANCE CHECK"""
	var direction = (current_target - global_position).normalized()
	direction.y = 0  # Don't move vertically (gravity handles Y)
	
	# Only move if there's meaningful distance
	var distance_2d = Vector2(current_target.x - global_position.x, current_target.z - global_position.z).length()
	
	if distance_2d > 0.5:  # FIXED: 2D distance check, closer threshold
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		
		# Rotate to face movement direction
		if direction.length() > 0.1:
			var target_rotation = atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_rotation, delta * 5.0)
	else:
		# Close enough - stop horizontal movement
		velocity.x = 0
		velocity.z = 0
		_on_reached_target()

func _on_reached_target():
	"""Handle reaching the current target position"""
	match current_state:
		PatronState.WALKING_TO_TABLE:
			_arrive_at_table()
		PatronState.LEAVING:
			_leave_tavern()

func _arrive_at_table():
	"""Patron reaches table and sits down"""
	print("Patron ", patron_name, " arrives at table")
	current_state = PatronState.SITTING_WAITING
	
	# Visual sitting effect (scale down slightly)
	scale.y = 0.7
	
	# Start sitting timer before wanting service
	sitting_timer.start()
	
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message(patron_name + " sits down and looks around the tavern.")

func _on_sitting_timer_timeout():
	"""Patron settled in, now wants service"""
	wants_service = true
	service_indicator.visible = true
	current_state = PatronState.SITTING_WAITING
	
	print("Patron ", patron_name, " wants service!")
	
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message(patron_name + " signals for service.")
	
	patron_wants_service.emit()

func serve(player_position: Vector3) -> bool:
	"""Handle being served by player"""
	if not wants_service or has_been_served:
		print("Patron doesn't want service or already served")
		return false
	
	var distance = global_position.distance_to(player_position)
	if distance > 3.0:
		print("Player too far away: ", distance)
		return false
	
	# Check if enough beer
	if not GameManager.consume_beer_pints(1):
		if main_scene and main_scene.has_method("log_message"):
			main_scene.log_message("Out of beer! Cannot serve " + patron_name)
		return false
	
	# Successful service
	has_been_served = true
	wants_service = false
	service_indicator.visible = false
	current_state = PatronState.DRINKING
	
	# Start drinking timer
	drinking_timer.start()
	
	print("Served patron: ", patron_name, " for ", payment_amount, " gold")
	
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message("Served " + patron_name + " a refreshing pint!")
	
	patron_served.emit()
	return true

func _on_drinking_timer_timeout():
	"""Patron finished drinking, time to pay and leave"""
	print(patron_name, " finished drinking, paying ", payment_amount, " gold")
	
	# Pay the player
	GameManager.add_gold(payment_amount)
	
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message(patron_name + " pays " + str(payment_amount) + " gold and prepares to leave.")
	
	# Start leaving
	current_state = PatronState.LEAVING
	
	# Get entrance position from spawner or use fallback
	if has_meta("entrance_position"):
		current_target = get_meta("entrance_position")
	else:
		# Fallback - just move away from table
		current_target = global_position + Vector3(5, 0, 5)
	
	print("Patron leaving to: ", current_target)

func _leave_tavern():
	"""Patron exits the tavern"""
	print("Patron ", patron_name, " leaves the tavern")
	
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message(patron_name + " thanks you and leaves the tavern.")
	
	patron_left.emit()
	
	# Signal for object pooling
	patron_finished.emit(self)

func reset_patron_state():
	"""Reset patron to initial state for object pooling reuse"""
	current_state = PatronState.WALKING_TO_TABLE
	has_been_served = false
	service_requested = false
	wants_service = false
	
	# Reset timers
	if sitting_timer:
		sitting_timer.stop()
	if drinking_timer:
		drinking_timer.stop()
	
	# Reset visual indicators
	if service_indicator:
		service_indicator.visible = false
	
	# Reset scale
	scale = Vector3.ONE
	
	# Reset rotation
	rotation = Vector3.ZERO
	
	print("Patron state reset for pooling reuse")
