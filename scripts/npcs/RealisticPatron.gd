extends CharacterBody3D
class_name RealisticPatron

# Addresses all the parse errors from the console
# Movement and physics constants
const SPEED = 2.0
const GRAVITY = 9.8

# State machine enum - FIXED: Properly declared
enum PatronState {
	WALKING_TO_TABLE,
	SITTING_WAITING,
	BEING_SERVED,
	DRINKING,
	LEAVING
}

# === OBJECT POOLING SUPPORT ===
signal patron_finished(patron_body: Node)

# State variables - FIXED: All declared
var current_state = PatronState.WALKING_TO_TABLE
var current_target: Vector3

# Positions - FIXED: Declared as variables
var table_position = Vector3(0, 3.0, 3.059)
var entrance_position = Vector3(10.7, 3.0, 6.3)

# Service system variables - FIXED: All declared  
var wants_service = false
var has_been_served = false
var service_requested = false  # Added missing variable
var service_indicator: MeshInstance3D
var payment_amount: int

# Character data - FIXED: All declared
var patron_name: String
var character_type: String = "Knight"
var drinking_duration: int = 8  # Added missing variable

# Timers - FIXED: Declared
var sitting_timer: Timer
var drinking_timer: Timer
var departure_timer: Timer  # Added missing variable

# Scene references - FIXED: Declared
var main_scene: Node

# Signals - FIXED: Properly declared
signal patron_left
signal patron_wants_service
signal patron_served

func _ready():
	print("RealisticPatron initializing...")
	
	# Set up physics first
	setup_physics()
	
	# Get main scene reference
	main_scene = get_tree().current_scene
	
	# Generate patron data
	generate_patron_data()
	
	# Set initial target
	current_target = table_position
	
	# Create visual representation
	create_patron_model()
	
	# Create service indicator
	create_service_indicator()
	
	# Set up timers
	setup_timers()
	
	print("Patron '", patron_name, "' ready - walking to table")

func can_chat() -> bool:
	"""Check if patron is available for conversation"""
	return has_been_served and current_state == PatronState.DRINKING

func setup_physics():
	"""Configure proper collision for patron - FIXED FUNCTION"""
	# Set collision layers (NPCs use layer 4)
	collision_layer = 1
	collision_mask = 1  # Collide with environment (layer 2)
	
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
	"""Generate new random patron data - ENHANCED FOR POOLING"""
	var names = ["Gareth", "Elara", "Thorin", "Lydia", "Marcus", "Sera", "Bjorn", "Isla", "Caius", "Vera"]
	var surnames = ["the Bold", "Ironforge", "Swiftblade", "Nightwhisper", "Goldbeard", "Stormwind"]
	
	# Generate full name
	patron_name = names[randi() % names.size()] + " " + surnames[randi() % surnames.size()]
	
	# Payment varies by settlement and time of day
	var base_payment = randi_range(6, 9)
	var time_bonus = 0
	
	# Time-based payment variation
	var game_time = GameManager.current_day % 7  # Weekly cycle
	if game_time == 0 or game_time == 6:  # Weekend premium
		time_bonus = randi_range(1, 3)
	
	payment_amount = base_payment + time_bonus
	
	# Settlement trait affects payment
	var settlement_trait = get_meta("settlement_trait", "")
	match settlement_trait:
		"Merchant":
			payment_amount += randi_range(2, 4)  # Wealthy merchants tip well
		"Scout", "Hunter":
			payment_amount += randi_range(0, 1)  # Modest frontier folk
		"Scholar":
			payment_amount += randi_range(1, 2)  # Appreciative but not wealthy
		"Knight", "Officer":
			payment_amount += randi_range(1, 3)  # Honor-bound to pay fairly
	
	print("Generated patron: ", patron_name, " (", settlement_trait, ") will pay ", payment_amount, " gold")

func enhanced_departure():
	"""Enhanced departure with pooling return"""
	print(patron_name, " thanks you and prepares to leave")
	
	# Create departure movement
	var exit_position = Vector3(8.7, 0.0, 3.3)  # Entrance/exit
	var departure_tween = create_tween()
	departure_tween.tween_property(self, "global_position", exit_position, 2.0)
	departure_tween.tween_callback(complete_departure)

func complete_departure():
	"""Complete departure and signal for pool return"""
	print("Patron ", patron_name, " has left the tavern")
	
	# Emit signal for PatronSpawner to handle pool return
	patron_finished.emit(self)

# === ENHANCED INTERACTION WITH POOLING AWARENESS ===
func create_patron_model():
	"""Create visual representation - POOLING OPTIMIZED"""
	# Check if model already exists (from pooling)
	var existing_model = get_node_or_null("PatronModel")
	if existing_model:
		print("Reusing existing patron model for ", patron_name)
		return
	
	# Create new model if needed
	var model_path = "res://assets/characters/models/kaykit_adventurers/Knight.glb"
	var model_scene = load(model_path)
	
	if model_scene:
		var model_instance = model_scene.instantiate()
		model_instance.name = "PatronModel"
		model_instance.position.y = -1.0
		add_child(model_instance)
		print("Created new model for ", patron_name)
	else:
		create_fallback_model()

func create_fallback_model():
	"""Create fallback model - POOLING AWARE"""
	var existing_mesh = get_node_or_null("FallbackMesh")
	if existing_mesh:
		# Reuse existing fallback
		var material = existing_mesh.get_surface_override_material(0)
		if material:
			# Change color for visual variety
			var colors = [Color.BLUE, Color.RED, Color.GREEN, Color.YELLOW, Color.PURPLE]
			material.albedo_color = colors[randi() % colors.size()]
		return
	
	# Create new fallback
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "FallbackMesh"
	var capsule = CapsuleMesh.new()
	capsule.height = 2.0
	capsule.top_radius = 0.3
	capsule.bottom_radius = 0.3
	mesh_instance.mesh = capsule
	
	var material = StandardMaterial3D.new()
	var colors = [Color.BLUE, Color.RED, Color.GREEN, Color.YELLOW, Color.PURPLE]
	material.albedo_color = colors[randi() % colors.size()]
	mesh_instance.set_surface_override_material(0, material)
	
	add_child(mesh_instance)
	print("Created fallback model for ", patron_name)

func cleanup_patron_resources():
	"""Clean up patron-specific resources before pool return"""
	# Remove any temporary nodes
	var temp_nodes = get_children().filter(func(child): return child.name.begins_with("temp_"))
	for node in temp_nodes:
		node.queue_free()
	
	# Clean up any pending signals
	if has_signal("patron_finished"):
		# Disconnect any extra connections
		pass
	
	print("Cleaned up resources for ", patron_name)

# === SETTLEMENT INTEGRATION - FIXED ===
func apply_settlement_behavior():
	"""Apply settlement-specific behavior patterns"""
	var settlement_trait = get_meta("settlement_trait", "")  # Fixed variable name
	
	match settlement_trait:  # Fixed to use correct variable
		"Merchant":
			# Merchants stay longer, tip better
			drinking_duration = randi_range(10, 15)
		"Scout", "Hunter":
			# Quick drinkers, always alert
			drinking_duration = randi_range(5, 8)
		"Scholar":
			# Contemplative, moderate stay
			drinking_duration = randi_range(8, 12)
		"Knight", "Officer":
			# Disciplined, consistent timing
			drinking_duration = 10
		_:
			# Default behavior
			drinking_duration = randi_range(6, 10)

# === DEBUG FUNCTIONS FOR POOLING ===
func get_pooling_debug_info() -> Dictionary:
	"""Get debug information about patron pooling state"""
	return {
		"patron_name": patron_name,
		"current_state": PatronState.keys()[current_state],
		"has_been_served": has_been_served,
		"payment_amount": payment_amount,
		"settlement_trait": get_meta("settlement_trait", "none"),
		"table_index": get_meta("table_index", -1),
		"pool_id": get_meta("pool_id", -1)
	}

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
	
	service_indicator.position = Vector3(0, 2.5, 0)  # Above head
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
	"""Handle movement and physics - FIXED FUNCTION"""
	# Handle state-based behavior
	match current_state:
		PatronState.WALKING_TO_TABLE:
			move_toward_target(delta)
		PatronState.SITTING_WAITING:
			# Stay in place, wait for service
			velocity.x = 0
			velocity.z = 0
		PatronState.LEAVING:
			move_toward_target(delta)
	move_and_slide()

func move_toward_target(delta):
	"""Move toward current target position - FIXED FUNCTION"""
	var direction = (current_target - global_position).normalized()
	direction.y = 0  # Don't move vertically
	
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	# Rotate to face movement direction
	if direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 5.0)
	
	if Engine.get_process_frames() % 60 == 0:  # Every second
		var distance_to_target = global_position.distance_to(current_target)
	
	# Check if reached target
	var distance_to_target = global_position.distance_to(current_target)
	if distance_to_target < 4.0:
		_on_reached_target()

func _on_reached_target():
	"""Handle reaching the current target position - FIXED FUNCTION"""
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

func can_be_served_by(player_position: Vector3) -> bool:
	"""Check if player is close enough to serve this patron"""
	return wants_service and global_position.distance_to(player_position) <= 2.0

func serve(server_position: Vector3) -> bool:
	"""Attempt to serve the patron"""
	if not can_be_served_by(server_position):
		return false
	
	# Check if main scene has beer inventory
	if main_scene and main_scene.has_method("get_current_beer"):
		var beer_count = main_scene.get_current_beer()
		if beer_count <= 0:
			if main_scene.has_method("log_message"):
				main_scene.log_message("No beer in stock to serve " + patron_name + "!")
			return false
	
	# Successful service
	print("Serving ", patron_name)
	
	wants_service = false
	has_been_served = true
	service_indicator.visible = false
	current_state = PatronState.BEING_SERVED
	
	# Process payment and beer
	if main_scene:
		if main_scene.has_method("update_gold"):
			main_scene.update_gold(payment_amount)
		if main_scene.has_method("update_beer"):
			main_scene.update_beer(-1)
		if main_scene.has_method("log_message"):
			main_scene.log_message("Served " + patron_name + " for " + str(payment_amount) + " gold!")
	
	# Start drinking
	current_state = PatronState.DRINKING
	drinking_timer.start()
	
	patron_served.emit()
	return true

func _on_drinking_timer_timeout():
	"""Patron finishes drinking and prepares to leave"""
	print("Patron ", patron_name, " finished drinking")
	
	# Stand up (restore scale)
	scale.y = 1.0
	
	# Set target to entrance and leave
	current_target = entrance_position
	current_state = PatronState.LEAVING
	
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message(patron_name + " finishes their drink and prepares to leave.")

func _leave_tavern():
	"""Patron exits the tavern"""
	print("Patron ", patron_name, " leaves the tavern")
	
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message(patron_name + " thanks you and leaves the tavern.")
	
	patron_left.emit()
	queue_free()

func reset_patron_state():
	"""Reset patron to initial state for object pooling reuse"""
	# Reset core state
	current_state = PatronState.WALKING_TO_TABLE
	has_been_served = false
	service_requested = false
	
	# Reset timers
	if drinking_timer and drinking_timer.is_valid():
		drinking_timer.stop()
	if departure_timer and departure_timer.is_valid():
		departure_timer.stop()
	
	# Reset visual indicators
	if service_indicator:
		service_indicator.queue_free()
		service_indicator = null
	
	# Reset model position and rotation
	rotation = Vector3.ZERO
	
	# Clear any existing tweens
	if get_tree():
		var tweens = get_tree().get_processed_tweens()
		for tween in tweens:
			if tween.is_valid():
				tween.kill()
	
	# Reset collision
	setup_physics()
	
	print("Patron state reset for pooling reuse")
