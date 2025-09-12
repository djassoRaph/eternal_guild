# ==========================================
# REALISTIC NPC PATRON SYSTEM
# Based on your specific requirements and tavern layout
# ==========================================

# FILE 1: RealisticPatron.gd
extends CharacterBody3D
class_name RealisticPatron

enum PatronState {
	ENTERING,
	FINDING_SEAT,
	SITTING,
	REQUESTING_SERVICE,
	DRINKING,
	LEAVING
}

# Customized settings based on your requirements
@export var move_speed: float = 2.0
@export var patience_time: float = 120.0  # 2 minutes before leaving

var current_state: PatronState = PatronState.ENTERING
var target_position: Vector3
var is_moving: bool = false
var state_timer: float = 0.0
var patron_name: String = "Sir Knight"

# Visual components
var knight_model: Node3D
var service_indicator: MeshInstance3D

# Your tavern coordinates (based on your screenshot)
var entrance_pos: Vector3 = Vector3(0, 0, 4)  # Tavern entrance
var table_position: Vector3 = Vector3(0, 0, 3.059)  # Your table coordinates

func _ready():
	setup_patron_components()
	enter_tavern()

func setup_patron_components():
	"""Setup patron with collision and visual model"""
	print("Creating patron: ", patron_name)
	
	# Setup collision for movement
	setup_collision()
	
	# Try to load Knight model or create placeholder
	setup_visual_model()
	
	# Service indicator will be created in Godot scene, not code
	
	# Set collision layers for NPCs
	collision_layer = 4  # NPCs on layer 4
	collision_mask = 2   # NPCs collide with environment (layer 2)
	
	# Start at entrance
	position = entrance_pos

func setup_collision():
	"""Basic collision for NPC movement"""
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.3
	collision.shape = capsule
	add_child(collision)

func setup_visual_model():
	"""Load visual model or create simple placeholder"""
	# Try loading your Knight model
	var knight_path = "res://characters/models/kaykit_adventurers/Knight.glb"
	
	if ResourceLoader.exists(knight_path):
		var knight_scene = load(knight_path)
		if knight_scene:
			knight_model = knight_scene.instantiate()
			knight_model.name = "KnightModel"
			disable_model_collision(knight_model)
			add_child(knight_model)
			print("Loaded Knight model")
			return
	
	# Simple placeholder
	create_simple_placeholder()

func create_simple_placeholder():
	"""Simple colored capsule if model fails"""
	var mesh_instance = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.height = 1.8
	capsule.radius = 0.3
	mesh_instance.mesh = capsule
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.7, 0.8)  # Silver for knight
	mesh_instance.material_override = material
	
	add_child(mesh_instance)
	knight_model = mesh_instance

func disable_model_collision(node: Node):
	"""Remove collision from imported model"""
	for child in node.get_children():
		if child is CollisionShape3D:
			child.disabled = true
		elif child is CharacterBody3D or child is StaticBody3D:
			child.collision_layer = 0
			child.collision_mask = 0
		disable_model_collision(child)

func _physics_process(delta):
	update_patron_behavior(delta)
	handle_movement(delta)

func update_patron_behavior(delta):
	"""State machine for patron behavior"""
	state_timer += delta
	
	match current_state:
		PatronState.ENTERING:
			if not is_moving:
				find_table_seat()
		
		PatronState.FINDING_SEAT:
			if not is_moving:
				sit_at_table()
		
		PatronState.SITTING:
			if state_timer > 3.0:  # Sit for 3 seconds before requesting
				request_service()
		
		PatronState.REQUESTING_SERVICE:
			# Wait indefinitely until served or manually told to leave
			# No automatic timeout - you control when they leave
			pass
		
		PatronState.DRINKING:
			if state_timer > 8.0:  # Drink for 8 seconds
				leave_satisfied()
		
		PatronState.LEAVING:
			if not is_moving:
				despawn_patron()

func handle_movement(delta):
	"""Basic movement physics"""
	if not is_moving:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	var direction = (target_position - global_position)
	direction.y = 0
	
	if direction.length() < 0.3:
		is_moving = false
		velocity = Vector3.ZERO
		on_destination_reached()
	else:
		direction = direction.normalized()
		velocity = direction * move_speed
		
		# Rotate model to face movement
		if knight_model and direction.length() > 0.1:
			var target_rotation = atan2(direction.x, direction.z)
			knight_model.rotation.y = lerp_angle(knight_model.rotation.y, target_rotation, 4.0 * delta)
	
	move_and_slide()

func enter_tavern():
	"""Patron enters tavern"""
	current_state = PatronState.ENTERING
	state_timer = 0.0
	print(patron_name, " enters the tavern")

func find_table_seat():
	"""Move to the table position you specified"""
	current_state = PatronState.FINDING_SEAT
	state_timer = 0.0
	move_to_position(table_position)
	print(patron_name, " heads to table")

func sit_at_table():
	"""Sit down and get ready to request service"""
	current_state = PatronState.SITTING
	state_timer = 0.0
	
	# Make shorter to simulate sitting
	if knight_model:
		knight_model.scale.y = 0.7
	
	print(patron_name, " sits at table")

func request_service():
	"""Request service - you'll handle indicator in scene"""
	current_state = PatronState.REQUESTING_SERVICE
	state_timer = 0.0
	
	# Send signal to main game that this patron wants service
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message(patron_name + " wants to order!")
	
	# You can add service indicator here or handle in scene
	show_service_request()
	
	print(patron_name, " requests service")

func show_service_request():
	"""Show that patron wants service - you can customize this"""
	# Simple approach: create indicator if it doesn't exist
	if not service_indicator:
		service_indicator = MeshInstance3D.new()
		service_indicator.name = "ServiceRequest"
		service_indicator.position = Vector3(0, 2.5, 0)
		
		var sphere = SphereMesh.new()
		sphere.radius = 0.15
		service_indicator.mesh = sphere
		
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.YELLOW
		material.emission = Color.YELLOW
		material.emission_energy = 0.8
		service_indicator.material_override = material
		
		add_child(service_indicator)
	
	service_indicator.visible = true

func serve_drink():
	"""Called when player serves this patron"""
	if current_state != PatronState.REQUESTING_SERVICE:
		return false
	
	current_state = PatronState.DRINKING
	state_timer = 0.0
	
	if service_indicator:
		service_indicator.visible = false
	
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message(patron_name + ": Excellent ale, thank you!")
	
	print(patron_name, " is served and starts drinking")
	return true

func leave_satisfied():
	"""Leave and pay according to your game's pricing"""
	current_state = PatronState.LEAVING
	state_timer = 0.0
	
	# Reset scale
	if knight_model:
		knight_model.scale.y = 1.0
	
	# Payment based on your beer pricing system
	# Check your existing beer price and add profit margin
	var payment = calculate_payment()
	
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("update_gold"):
		main_scene.update_gold(payment)
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message(patron_name + " paid " + str(payment) + " gold!")
	
	move_to_position(entrance_pos)
	print(patron_name, " leaves satisfied, paid ", payment, " gold")

func calculate_payment() -> int:
	"""Calculate payment based on your game economy"""
	# Your beer costs 5 gold to buy, so selling price should be 6-8 gold
	# Knights are wealthy so they pay well and tip
	var base_price = 6  # Base selling price
	var tip = randi_range(1, 3)  # Generous tip
	return base_price + tip

func leave_disappointed():
	"""Force patron to leave without payment"""
	current_state = PatronState.LEAVING
	state_timer = 0.0
	
	if knight_model:
		knight_model.scale.y = 1.0
	if service_indicator:
		service_indicator.visible = false
	
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message(patron_name + " leaves disappointed!")
	
	move_to_position(entrance_pos)
	print(patron_name, " leaves without paying")

func despawn_patron():
	"""Remove from scene"""
	print(patron_name, " has left the tavern")
	queue_free()

func move_to_position(pos: Vector3):
	"""Start moving to position"""
	target_position = pos
	is_moving = true

func on_destination_reached():
	"""Called when reaching destination"""
	print(patron_name, " reached destination")
