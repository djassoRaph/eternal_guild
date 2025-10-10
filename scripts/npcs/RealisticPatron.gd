# RealisticPatron.gd - COMPLETE WALKING SYSTEM
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

# Navigation
var nav_agent: NavigationAgent3D  # Created/found in _ready()

# State
var current_state = PatronState.WALKING_TO_TABLE  # Start walking!
var table_position: Vector3
var entrance_position: Vector3
var table_index: int = -1

# Service
var wants_service = false
var has_been_served = false
var payment_amount: int = 8
var patron_name: String = "Patron"

# Visuals
var service_indicator: MeshInstance3D  # Created in _ready()
@onready var patron_body_mesh: Node3D = $Mage

# Timers
var sitting_timer: Timer  # Created in _ready()
var drinking_timer: Timer  # Created in _ready()

# Scene references
var main_scene: Node

# Signals
signal patron_finished(patron: RealisticPatron)
signal wants_to_be_served(patron: RealisticPatron)

func _ready():
	print("🧍 RealisticPatron initializing...")
	
	main_scene = get_tree().current_scene
	
	# Get NavigationAgent3D
	if has_node("NavigationAgent3D"):
		nav_agent = get_node("NavigationAgent3D")
	else:
		# Create it if it doesn't exist
		nav_agent = NavigationAgent3D.new()
		nav_agent.name = "NavigationAgent3D"
		add_child(nav_agent)
	
	# Get Mage model if it exists
	if has_node("Mage"):
		patron_body_mesh = get_node("Mage")
	
	# Create service indicator (yellow sphere)
	create_service_indicator()
	
	# Create timers
	sitting_timer = Timer.new()
	sitting_timer.name = "SittingTimer"
	sitting_timer.one_shot = true
	add_child(sitting_timer)
	sitting_timer.timeout.connect(on_sitting_timer_timeout)
	
	drinking_timer = Timer.new()
	drinking_timer.name = "DrinkingTimer"
	drinking_timer.one_shot = true
	add_child(drinking_timer)
	drinking_timer.timeout.connect(on_drinking_timer_timeout)
	
	# Configure NavigationAgent3D
	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 0.5
		nav_agent.max_speed = SPEED
		nav_agent.radius = 0.4
		nav_agent.height = 1.8
		nav_agent.avoidance_enabled = true
		
		# Connect navigation finished signal
		nav_agent.navigation_finished.connect(_on_navigation_finished)
	
	print("✅ Patron ready")

func _physics_process(delta: float):
	"""Handle movement and physics"""
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0
	
	# Handle state-based movement
	match current_state:
		PatronState.WALKING_TO_TABLE, PatronState.LEAVING:
			_navigate_with_agent(delta)
		PatronState.SITTING_WAITING, PatronState.DRINKING:
			# Stop moving when sitting
			velocity.x = 0
			velocity.z = 0
	
	move_and_slide()
	
	# Animate service indicator (make it bob up and down)
	if service_indicator and service_indicator.visible:
		var time = Time.get_ticks_msec() / 1000.0
		service_indicator.position.y = 2.2 + sin(time * 3.0) * 0.15

func _navigate_with_agent(delta: float):
	"""Use NavigationAgent3D to walk to target"""
	
	if not nav_agent:
		return
	
	# Check if navigation is finished
	if nav_agent.is_navigation_finished():
		velocity.x = 0
		velocity.z = 0
		return
	
	# Get next path position
	var next_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_position)
	direction.y = 0  # Keep movement horizontal
	
	# Move toward next position
	if direction.length() > 0.01:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		
		# Rotate character model to face movement direction
		if patron_body_mesh:
			var target_rotation = atan2(direction.x, direction.z)
			patron_body_mesh.rotation.y = lerp_angle(patron_body_mesh.rotation.y, target_rotation, delta * 8.0)

func _on_navigation_finished():
	"""Called when NavigationAgent reaches target"""
	match current_state:
		PatronState.WALKING_TO_TABLE:
			_arrive_at_table()
		PatronState.LEAVING:
			_leave_tavern()

func _arrive_at_table():
	"""Patron reaches table and sits down"""
	print("🪑 ", patron_name, " arrived at table ", table_index)
	current_state = PatronState.SITTING_WAITING
	
	# Visual: shrink character slightly (sitting pose)
	if patron_body_mesh:
		patron_body_mesh.scale.y = 0.8
	
	# Wait a moment, then signal for service
	sitting_timer.wait_time = randf_range(2.0, 5.0)
	sitting_timer.start()

func _leave_tavern():
	"""Patron exits the tavern"""
	print("🚪 ", patron_name, " reached the exit and is leaving")
	patron_finished.emit(self)

# === SERVICE SYSTEM ===

func can_be_served_by(player_position: Vector3) -> bool:
	"""Check if player can serve this patron"""
	if current_state != PatronState.SITTING_WAITING:
		return false
	
	if has_been_served:
		return false
		
	var distance = global_position.distance_to(player_position)
	return distance <= 3.0  # Serving range

func serve_patron():
	"""Player serves this patron a drink"""
	if current_state != PatronState.SITTING_WAITING:
		print("❌ Patron is not waiting for service.")
		return false
	
	# Check beer availability
	if not GameManager.consume_beer_pints(1):
		print("⚠️ Out of beer!")
		return false
	
	# Service successful!
	sitting_timer.stop()
	service_indicator.visible = false
	has_been_served = true
	wants_service = false
	
	current_state = PatronState.DRINKING
	drinking_timer.wait_time = randf_range(8.0, 15.0)
	drinking_timer.start()
	
	print("🍺 ", patron_name, " is now drinking")
	return true

# === TIMER CALLBACKS ===

func on_sitting_timer_timeout():
	"""Patron signals they want service"""
	if current_state == PatronState.SITTING_WAITING and not has_been_served:
		wants_service = true
		service_indicator.visible = true
		wants_to_be_served.emit(self)
		print("🍺 ", patron_name, " wants service!")

func on_drinking_timer_timeout():
	"""Patron finishes drinking and leaves"""
	if current_state == PatronState.DRINKING:
		print("💰 ", patron_name, " finished drinking. Pays ", payment_amount, "g")
		GameManager.add_gold(payment_amount)
		
		# Stand up and leave
		if patron_body_mesh:
			patron_body_mesh.scale.y = 1.0
		
		current_state = PatronState.LEAVING
		
		# Set navigation to entrance (wait a frame for nav to be ready)
		await get_tree().process_frame
		if nav_agent:
			nav_agent.target_position = entrance_position
			print("🚶 ", patron_name, " is walking to exit at ", entrance_position)
		else:
			# No navigation available, leave immediately
			_leave_tavern()

# === INITIALIZATION ===

func create_service_indicator():
	"""Create the yellow sphere that appears when patron wants service"""
	service_indicator = MeshInstance3D.new()
	service_indicator.name = "ServiceIndicator"
	
	var sphere = SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	service_indicator.mesh = sphere
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.YELLOW
	material.emission_enabled = true
	material.emission = Color.YELLOW * 0.8
	service_indicator.material_override = material
	
	service_indicator.position = Vector3(0, 2.2, 0)  # Hover above patron
	service_indicator.visible = false
	add_child(service_indicator)

func setup_for_table(target_table: Vector3, entrance: Vector3, idx: int):
	"""Initialize patron with target table"""
	table_position = target_table
	entrance_position = entrance
	table_index = idx
	
	# Generate random patron data
	var first_names = ["Gareth", "Elara", "Thorin", "Lydia", "Marcus", "Sera", "Kael", "Mira"]
	var surnames = ["Bold", "Ironforge", "Swiftblade", "Goldbeard", "Stormbringer", "Shadowmend"]
	patron_name = first_names[randi() % first_names.size()] + " " + surnames[randi() % surnames.size()]
	payment_amount = randi_range(6, 12)
	
	# Set navigation target after a brief delay (let physics settle)
	await get_tree().create_timer(0.1).timeout
	if nav_agent:
		nav_agent.target_position = table_position
		print("🎯 ", patron_name, " walking to table ", table_index, " at ", table_position)
