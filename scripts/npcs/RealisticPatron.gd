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
var nav_agent: NavigationAgent3D

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
var patron_origin: String = ""
var patron_origin_type: String = ""   # traveler/local/soldier/trader — keys ambient chatter (Story 8.4)

# Visuals
var service_indicator: MeshInstance3D
var patron_body_mesh: Node3D       # Set dynamically after model swap
var animation_player: AnimationPlayer = null  # NEW

# All available patron models — add more paths here anytime
var character_models = [
	"res://assets/characters/models/kaykit_adventurers/Mage.glb",
	"res://assets/characters/models/kaykit_adventurers/Rogue.glb",
	"res://assets/characters/models/kaykit_adventurers/Knight.glb",
	"res://assets/characters/models/kaykit_adventurers/Barbarian.glb",
	"res://assets/characters/models/kaykit_adventurers/Rogue_Hooded.glb",
]

# Timers
var sitting_timer: Timer
var drinking_timer: Timer

# Scene references
var main_scene: Node

# Signals
signal patron_finished(patron: RealisticPatron)
signal wants_to_be_served(patron: RealisticPatron)

func _ready():
	print("RealisticPatron initializing...")
	
	add_to_group("patrons")  # ← ADD THIS LINE
	collision_mask = 0b00000001
	collision_layer = 0b00000010
	print("Patron collision: Layer 2, Mask 1 (no NPC-to-NPC collision)")

	# Swap to a random model before anything else
	_swap_to_random_model()

	# Get NavigationAgent3D
	if has_node("NavigationAgent3D"):
		nav_agent = get_node("NavigationAgent3D")
	else:
		nav_agent = NavigationAgent3D.new()
		nav_agent.name = "NavigationAgent3D"
		add_child(nav_agent)

	# Create service indicator
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
		nav_agent.avoidance_layers = 0b00000010
		nav_agent.avoidance_mask = 0b00000010
		nav_agent.navigation_finished.connect(_on_navigation_finished)

	print("Patron ready")

# =============================================================================
# RANDOM MODEL SWAP
# =============================================================================

func _swap_to_random_model():
	"""Remove any existing model child and load a random one"""
	# Remove old hardcoded model node (e.g. Mage in RealisticPatron.tscn)
	for child in get_children():
		if child is Node3D and not child is CollisionShape3D and not child is NavigationAgent3D:
			child.queue_free()

	# Pick a random model
	var model_path = character_models[randi() % character_models.size()]
	var model_resource = load(model_path)

	if not model_resource:
		push_warning("RealisticPatron: Could not load model: " + model_path)
		return

	patron_body_mesh = model_resource.instantiate()
	patron_body_mesh.name = "PatronModel"
	add_child(patron_body_mesh)

	print("Patron model: ", model_path.get_file())

	# Find AnimationPlayer inside the loaded model
	animation_player = _find_animation_player(patron_body_mesh)

	if animation_player:
		print("Patron AnimationPlayer found")
		_patron_play_animation("Idle")
	else:
		push_warning("RealisticPatron: No AnimationPlayer in " + model_path.get_file())

func _find_animation_player(node: Node) -> AnimationPlayer:
	"""Recursively search for AnimationPlayer in model"""
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
	return null

# =============================================================================
# PATRON ANIMATIONS
# =============================================================================

func _patron_play_animation(anim_name: String) -> void:
	if not animation_player:
		return
	if not animation_player.has_animation(anim_name):
		return  # Silently skip — not all models have all animations
	if animation_player.current_animation == anim_name:
		return

	# Force loop
	var anim = animation_player.get_animation(anim_name)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR

	animation_player.play(anim_name, 0.2)

# =============================================================================
# PHYSICS & MOVEMENT
# =============================================================================

func _physics_process(delta: float):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0

	match current_state:
		PatronState.WALKING_TO_TABLE, PatronState.LEAVING:
			_navigate_with_agent(delta)
		PatronState.SITTING_WAITING, PatronState.DRINKING:
			velocity.x = 0
			velocity.z = 0

	move_and_slide()

	if service_indicator and service_indicator.visible:
		var time = Time.get_ticks_msec() / 1000.0
		service_indicator.position.y = 2.2 + sin(time * 3.0) * 0.15

func _navigate_with_agent(delta: float):
	if not nav_agent:
		return

	if nav_agent.is_navigation_finished():
		velocity.x = 0
		velocity.z = 0
		_patron_play_animation("Idle")
		return

	var next_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_position)
	direction.y = 0

	if direction.length() > 0.01:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED

		if patron_body_mesh:
			var target_rotation = atan2(direction.x, direction.z)
			patron_body_mesh.rotation.y = lerp_angle(patron_body_mesh.rotation.y, target_rotation, delta * 8.0)

		_patron_play_animation("Running_A")

func _on_navigation_finished():
	match current_state:
		PatronState.WALKING_TO_TABLE:
			_arrive_at_table()
		PatronState.LEAVING:
			_leave_tavern()

func _arrive_at_table():
	print("", patron_name, " arrived at table ", table_index)
	current_state = PatronState.SITTING_WAITING
	_patron_play_animation("Idle")

	if patron_body_mesh:
		patron_body_mesh.scale.y = 0.8

	sitting_timer.wait_time = randf_range(2.0, 5.0)
	sitting_timer.start()

func _leave_tavern():
	print("", patron_name, " reached the exit and is leaving")
	patron_finished.emit(self)

# =============================================================================
# SERVICE SYSTEM
# =============================================================================

func can_be_served_by(player_position: Vector3) -> bool:
	if current_state != PatronState.SITTING_WAITING:
		return false
	if has_been_served:
		return false
	var distance = global_position.distance_to(player_position)
	return distance <= 3.0

func serve_patron():
	if current_state != PatronState.SITTING_WAITING:
		print("Patron is not waiting for service.")
		return false

	if not GameManager.consume_beer_pints(1):
		print("Out of beer!")
		return false

	sitting_timer.stop()
	service_indicator.visible = false
	has_been_served = true
	wants_service = false

	current_state = PatronState.DRINKING
	drinking_timer.wait_time = randf_range(8.0, 15.0)
	drinking_timer.start()

	print("", patron_name, " is now drinking")
	_start_ambient_chatter()  # Story 8.4 — a floating one-liner while they drink
	return true

# =============================================================================
# TIMER CALLBACKS
# =============================================================================

func on_sitting_timer_timeout():
	if current_state == PatronState.SITTING_WAITING and not has_been_served:
		wants_service = true
		service_indicator.visible = true
		wants_to_be_served.emit(self)
		print("", patron_name, " wants service!")

func on_drinking_timer_timeout():
	if current_state == PatronState.DRINKING:
		print("", patron_name, " finished drinking. Pays ", payment_amount, "g")
		GameManager.add_gold(payment_amount)

		# Coin-burst juice at the patron (Story 3.4 visual reward + SFX)
		var coin_burst = preload("res://scripts/fx/coin_reward.gd").new()
		var burst_host = get_parent()
		if burst_host:
			burst_host.add_child(coin_burst)
			coin_burst.global_position = global_position + Vector3(0, 1.5, 0)
			coin_burst.burst()

		var origin_note = " (from " + patron_origin + ")" if patron_origin != "" else ""
		GameManager.log_message("• " + patron_name + origin_note + " finished drinking. Pays " + str(payment_amount) + " gold")

		if patron_body_mesh:
			patron_body_mesh.scale.y = 1.0

		current_state = PatronState.LEAVING

		await get_tree().process_frame
		if nav_agent:
			nav_agent.target_position = entrance_position
			print("", patron_name, " is walking to exit at ", entrance_position)
		else:
			_leave_tavern()

# =============================================================================
# AMBIENT CHATTER (Story 8.4)
# =============================================================================

func _start_ambient_chatter() -> void:
	# After a short beat, float one ambient line above the patron's head. Fire-and-forget:
	# called without await so it never blocks the serve path.
	await get_tree().create_timer(randf_range(1.5, 3.0)).timeout
	if current_state != PatronState.DRINKING:
		return  # left or got interrupted — skip
	var line := _pick_ambient_line()
	if line == "" or line == "...":
		return
	# preload by path (like coin_reward) so this compiles even before the editor scans the
	# new script into the global class registry.
	var bubble = preload("res://scripts/fx/patron_speech_bubble.gd").new()
	add_child(bubble)  # child of the patron, so it rides along and cleans up with them
	bubble.say(line)

func _pick_ambient_line() -> String:
	# Data-driven (MOD-2): lines live in data/dialogue/patron_lines.json under "ambient",
	# keyed by origin type, with a "default" fallback.
	if DataManager == null:
		return ""
	var ctx := patron_origin_type if patron_origin_type != "" else "default"
	var line := DataManager.get_dialogue_line("ambient", ctx)
	if line == "..." and ctx != "default":
		line = DataManager.get_dialogue_line("ambient", "default")
	return line

# =============================================================================
# INITIALIZATION
# =============================================================================

func create_service_indicator():
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

	service_indicator.position = Vector3(0, 2.2, 0)
	service_indicator.visible = false
	add_child(service_indicator)

func setup_for_table(target_table: Vector3, entrance: Vector3, idx: int):
	table_position = target_table
	entrance_position = entrance
	table_index = idx

	var first_names = ["Gareth", "Elara", "Thorin", "Lydia", "Marcus", "Sera", "Kael", "Mira"]
	var surnames = ["Bold", "Ironforge", "Swiftblade", "Goldbeard", "Stormbringer", "Shadowmend"]
	patron_name = first_names[randi() % first_names.size()] + " " + surnames[randi() % surnames.size()]
	payment_amount = randi_range(6, 12)

	var origins = [
		# travelers passing through
		{"label": "the bridge crossroads", "type": "traveler"},
		{"label": "the north road", "type": "traveler"},
		{"label": "the eastern pass", "type": "traveler"},
		{"label": "the merchant caravan", "type": "trader"},
		{"label": "the river docks", "type": "trader"},
		# locals
		{"label": "the commons", "type": "local"},
		{"label": "the lower district", "type": "local"},
		# garrison / keep
		{"label": "the old keep", "type": "soldier"},
		{"label": "the guard post", "type": "soldier"},
		# wilderness
		{"label": "the forest road", "type": "traveler"},
		{"label": "the eastern farms", "type": "traveler"},
	]
	var picked = origins[randi() % origins.size()]
	patron_origin = picked["label"]
	patron_origin_type = picked["type"]
	print("", patron_name, " is from ", patron_origin, " (", patron_origin_type, ")")

	await get_tree().create_timer(0.1).timeout
	if nav_agent:
		nav_agent.target_position = table_position
		print("", patron_name, " walking to table ", table_index, " at ", table_position)
