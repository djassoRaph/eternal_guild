# RealisticPatron.gd - COMPLETE NAVIGATION SYSTEM
extends CharacterBody3D
class_name RealisticPatron

# Movement constants
const SPEED = 2.5
const GRAVITY = 9.8

# State machine
enum PatronState {
	WALKING_TO_TABLE,
	SITTING_WAITING,
	DRINKING,
	LEAVING
}

# Navigation - CRITICAL FOR PATHFINDING
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

# State
var current_state = PatronState.WALKING_TO_TABLE
var table_position: Vector3
var entrance_position: Vector3
var table_index: int = -1

# Service
var wants_service = false
var has_been_served = false
var payment_amount: int = 8
var patron_name: String = "Patron"

# Visuals
var service_indicator: MeshInstance3D
var patron_body_mesh: Node3D

# Timers
var sitting_timer: Timer
var drinking_timer: Timer

# Scene references
var main_scene: Node

# Signals
signal patron_finished(patron: RealisticPatron)
signal wants_to_be_served(patron: RealisticPatron)

func _ready():
	print("🧍 RealisticPatron initializing with NavigationAgent3D...")
	
	main_scene = get_tree().current_scene
	
	# Ensure navigation agent exists
	if not has_node("NavigationAgent3D"):
		var new_nav = NavigationAgent3D.new()
		new_nav.name = "NavigationAgent3D"
		add_child(new_nav)
		nav_agent = new_nav
		print("✅ Created NavigationAgent3D node")
	
	# Configure navigation agent
	nav_agent.path_desired_distance = 0.3
	nav_agent.target_desired_distance = 0.3
	nav_agent.max_speed = SPEED
	nav_agent.radius = 0.3
	nav_agent.height = 1.8
	nav_agent.avoidance_enabled = true
	
	# Wait for physics frame for navigation to be ready
	call_deferred("_setup_navigation")
	
	# Create visuals
	create_patron_visual()
	create_service_indicator()
	
	# Set up timers
	setup_timers()
	
	# Set up collision
	setup_collision()
	
	print("✅ Patron ready with navigation")

func _setup_navigation():
	"""Called after navigation system is ready"""
	# Get target from metadata (set by spawner)
	if has_meta("target_table"):
		table_position = get_meta("target_table")
		entrance_position = get_meta("entrance_position")
		table_index = get_meta("table_index")
		
		# Set navigation target
		nav_agent.target_position = table_position
		print("🎯 Patron ", patron_name, " navigating to table ", table_index, " at ", table_position)
	else:
		print("⚠️ No target table metadata set!")

func _physics_process(delta):
	"""Handle movement and state"""
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0
	
	# Handle state-based behavior
	match current_state:
		PatronState.WALKING_TO_TABLE:
			_navigate_with_agent(delta)
		PatronState.LEAVING:
			_navigate_with_agent(delta)
		PatronState.SITTING_WAITING, PatronState.DRINKING:
			velocity.x = 0
			velocity.z = 0
	
	move_and_slide()

func _navigate_with_agent(delta):
	"""Use NavigationAgent3D for pathfinding"""
	
	# Check if reached destination
	if nav_agent.is_navigation_finished():
		velocity.x = 0
		velocity.z = 0
		_on_reached_destination()
		return
	
	# Get next path position
	var next_path_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_position)
	direction.y = 0  # Don't move vertically
	
	# Apply movement
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	
	# Rotate to face movement direction
	if direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 5.0)

func _on_reached_destination():
	"""Called when NavigationAgent reaches its target"""
	match current_state:
		PatronState.WALKING_TO_TABLE:
			_arrive_at_table()
		PatronState.LEAVING:
			_leave_tavern()

func _arrive_at_table():
	"""Patron reaches table and sits down"""
	print("🪑 ", patron_name, " arrived at table ", table_index)
	current_state = PatronState.SITTING_WAITING
	
	# Sitting visual effect
	if patron_body_mesh:
		patron_body_mesh.scale.y = 0.7
	
	# Wait before wanting service
	sitting_timer.start()
	
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message(patron_name + " sits down at a table.")

func _on_sitting_timer_timeout():
	"""Patron wants service"""
	wants_service = true
	service_indicator.visible = true
	
	print("🍺 ", patron_name, " wants service!")
	wants_to_be_served.emit(self)
	
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message(patron_name + " signals for service!")

func serve(player_position: Vector3) -> bool:
	"""Player serves this patron"""
	
	if not wants_service or has_been_served:
		print("Patron doesn't want service or already served")
		return false
	
	var distance = global_position.distance_to(player_position)
	if distance > 3.0:
		print("Player too far to serve: ", distance)
		return false
	
	# Check beer availability
	if not GameManager.consume_beer_pints(1):
		if main_scene and main_scene.has_method("log_message"):
			main_scene.log_message("Out of beer!")
		return false
	
	# Successful service!
	has_been_served = true
	wants_service = false
	service_indicator.visible = false
	current_state = PatronState.DRINKING
	
	# Stand up visual
	if patron_body_mesh:
		patron_body_mesh.scale.y = 1.0
	
	drinking_timer.start()
	
	print("✅ Successfully served ", patron_name)
	
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message("Served " + patron_name + " a beer!")
	
	return true

func can_be_served_by(player_position: Vector3) -> bool:
	"""Check if patron can be served from player's position"""
	if not wants_service or has_been_served:
		return false
	return global_position.distance_to(player_position) <= 3.0

func _on_drinking_timer_timeout():
	"""Patron finished drinking, time to pay and leave"""
	print("💰 ", patron_name, " pays ", payment_amount, " gold")
	
	# Pay player
	GameManager.add_gold(payment_amount)
	
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message(patron_name + " pays " + str(payment_amount) + " gold and prepares to leave.")
	
	# Start leaving
	current_state = PatronState.LEAVING
	
	# Stand up
	if patron_body_mesh:
		patron_body_mesh.scale.y = 1.0
	
	# Navigate to exit
	nav_agent.target_position = entrance_position
	print("🚪 ", patron_name, " leaving to: ", entrance_position)

func _leave_tavern():
	"""Patron exits tavern"""
	print("👋 ", patron_name, " left the tavern")
	
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message(patron_name + " leaves the tavern.")
	
	# Signal for cleanup
	patron_finished.emit(self)

# === SETUP FUNCTIONS ===

func setup_collision():
	"""Set up collision shape for patron"""
	if not has_node("CollisionShape3D"):
		var collision = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		
		var capsule = CapsuleShape3D.new()
		capsule.radius = 0.3
		capsule.height = 1.8
		collision.shape = capsule
		
		collision.position = Vector3(0, 0.9, 0)
		add_child(collision)
		
		print("✅ Created collision shape")

func create_patron_visual():
	"""Create simple cylinder visual for patron"""
	
	var available_models = [
		"res://scenes/npcs/PatronFarmer.tscn",
		"res://scenes/npcs/PatronKnight.tscn",
		"res://scenes/npcs/PatronMage.tscn",
		"res://scenes/npcs/PatronRogue.tscn",
		# Modders can add more here via JSON
	]
	
	var random_model_path = available_models[randi() % available_models.size()]
	
	if ResourceLoader.exists(random_model_path):
		var model_scene = load(random_model_path)
		if model_scene:
			patron_body_mesh = model_scene.instantiate()
			
			# KayKit models typically need Y offset
			# Adjust if feet are below ground
			patron_body_mesh.position = Vector3(0, 1.0, 0)
			
			add_child(patron_body_mesh)
			print("✅ Loaded KayKit model: ", random_model_path)
			return
	
	# Fallback: Create simple cylinder if model fails
	print("⚠️ Model failed to load, using fallback cylinder")
	create_fallback_cylinder()

func create_fallback_cylinder():
	"""Fallback visual if KayKit models don't load"""
	patron_body_mesh = MeshInstance3D.new()
	patron_body_mesh.name = "PatronBody"
	
	var cylinder = CylinderMesh.new()
	cylinder.height = 1.8
	cylinder.top_radius = 0.3
	cylinder.bottom_radius = 0.3
	patron_body_mesh.mesh = cylinder
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(randf_range(0.3, 0.9), randf_range(0.3, 0.9), randf_range(0.3, 0.9))
	patron_body_mesh.material_override = material
	
	patron_body_mesh.position = Vector3(0, 0.9, 0)
	add_child(patron_body_mesh)

func create_service_indicator():
	"""Create yellow sphere that appears when patron wants service"""
	service_indicator = MeshInstance3D.new()
	service_indicator.name = "ServiceIndicator"
	
	var sphere = SphereMesh.new()
	sphere.radius = 0.25
	service_indicator.mesh = sphere
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.YELLOW
	material.emission_enabled = true
	material.emission = Color.YELLOW * 0.8
	service_indicator.material_override = material
	
	service_indicator.position = Vector3(0, 2.5, 0)
	service_indicator.visible = false
	add_child(service_indicator)

func setup_timers():
	"""Create and configure timers"""
	sitting_timer = Timer.new()
	sitting_timer.wait_time = randf_range(1.5, 3.0)
	sitting_timer.one_shot = true
	sitting_timer.timeout.connect(_on_sitting_timer_timeout)
	add_child(sitting_timer)
	
	drinking_timer = Timer.new()
	drinking_timer.wait_time = randf_range(6.0, 10.0)
	drinking_timer.one_shot = true
	drinking_timer.timeout.connect(_on_drinking_timer_timeout)
	add_child(drinking_timer)

func generate_patron_data():
	"""Generate random patron information"""
	var first_names = ["Gareth", "Elara", "Thorin", "Lydia", "Marcus", "Sera", "Kael", "Mira"]
	var surnames = ["Bold", "Ironforge", "Swiftblade", "Goldbeard", "Stormbringer", "Shadowmend"]
	
	patron_name = first_names[randi() % first_names.size()] + " " + surnames[randi() % surnames.size()]
	payment_amount = randi_range(6, 12)
	
	print("Generated patron: ", patron_name, " (pays ", payment_amount, "g)")

# === POOLING SUPPORT ===

func reinitialize_for_spawn(target: Vector3, entrance: Vector3, idx: int):
	"""Reinitialize patron for object pooling reuse"""
	
	# Set positions
	global_position = entrance
	table_position = target
	entrance_position = entrance
	table_index = idx
	
	# Set metadata for navigation setup
	set_meta("target_table", target)
	set_meta("entrance_position", entrance)
	set_meta("table_index", idx)
	
	# Set navigation target
	if nav_agent:
		nav_agent.target_position = target
	
	# Reset state
	current_state = PatronState.WALKING_TO_TABLE
	has_been_served = false
	wants_service = false
	service_indicator.visible = false
	
	if patron_body_mesh:
		patron_body_mesh.scale = Vector3.ONE
	
	# Generate new data
	generate_patron_data()
	
	# Stop any running timers
	if sitting_timer and sitting_timer.time_left > 0:
		sitting_timer.stop()
	if drinking_timer and drinking_timer.time_left > 0:
		drinking_timer.stop()
	
	print("🔄 Patron reinitialized: ", patron_name)
