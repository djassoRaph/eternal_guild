# ==========================================
# FILE 2: SinglePatronSpawner.gd
# Only spawns one patron at a time, every 30 seconds
# ==========================================

extends Node3D
class_name SinglePatronSpawner

@export var spawn_interval: float = 30.0  # 30 seconds between spawns
var spawn_timer: float = 0.0
var current_patron: RealisticPatron = null

func _ready():
	print("Single Patron Spawner ready - spawns every 30 seconds")
	# First spawn after 10 seconds
	spawn_timer = spawn_interval - 10.0

func _process(delta):
	spawn_timer += delta
	
	# Only spawn if no current patron exists
	if spawn_timer >= spawn_interval and current_patron == null:
		spawn_single_patron()
		spawn_timer = 0.0

func spawn_single_patron():
	"""Spawn one patron if none exists"""
	current_patron = RealisticPatron.new()
	current_patron.name = "Knight_Patron"
	current_patron.patron_name = generate_knight_name()
	
	# Connect to cleanup when patron leaves
	current_patron.tree_exiting.connect(_on_patron_left)
	
	add_child(current_patron)
	print("Spawned: ", current_patron.patron_name)

func _on_patron_left():
	"""Clean up reference when patron leaves"""
	current_patron = null
	print("Patron left - can spawn new one in 30 seconds")

func generate_knight_name() -> String:
	"""Generate random knight names"""
	var names = ["Sir Gareth", "Sir Roland", "Sir Marcus", "Sir Tristan", "Sir Cedric"]
	return names[randi() % names.size()]

func force_patron_to_leave():
	"""Manually make current patron leave"""
	if current_patron and current_patron.current_state == RealisticPatron.PatronState.REQUESTING_SERVICE:
		current_patron.leave_disappointed()

# ==========================================
# FILE 3: Enhanced Player Service System
# Add this to your existing player.gd
# ==========================================

# Add this to your player.gd _input function:
func _input(event):
	# Your existing input handling...
	
	if event.is_action_pressed("interact"):  # E key
		attempt_patron_service()
	
	# Debug: Force patron to leave (optional)
	if event.is_action_pressed("ui_cancel"):  # ESC key
		force_patron_to_leave()

func attempt_patron_service():
	"""Try to serve nearby patrons"""
	# Check beer availability
	if not has_beer_to_serve():
		return
	
	# Find nearby patron needing service
	var nearby_patron = find_patron_needing_service()
	if nearby_patron:
		# Serve the patron
		if nearby_patron.serve_drink():
			consume_beer_for_service()
			log_service_success(nearby_patron.patron_name)

func has_beer_to_serve() -> bool:
	"""Check if player has beer to serve"""
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("get_current_beer"):
		var beer_count = main_scene.get_current_beer()
		if beer_count > 0:
			return true
		else:
			if main_scene.has_method("log_message"):
				main_scene.log_message("No beer in stock! Visit the bar to buy more.")
			return false
	return false

func consume_beer_for_service():
	"""Remove one beer from inventory when serving"""
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("update_beer"):
		main_scene.update_beer(-1)

func find_patron_needing_service() -> RealisticPatron:
	"""Find patron within service range who needs service"""
	var service_range = 2.0
	
	# Find all patron nodes
	var patrons = find_all_patrons()
	
	for patron in patrons:
		if patron is RealisticPatron:
			var distance = global_position.distance_to(patron.global_position)
			if distance <= service_range and patron.current_state == RealisticPatron.PatronState.REQUESTING_SERVICE:
				return patron
	
	# No patron found needing service
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message("No customers nearby need service.")
	
	return null

func find_all_patrons() -> Array:
	"""Find all patron nodes in the scene"""
	var patrons = []
	find_patrons_recursive(get_tree().current_scene, patrons)
	return patrons

func find_patrons_recursive(node: Node, patrons: Array):
	"""Recursively search for patron nodes"""
	if node is RealisticPatron:
		patrons.append(node)
	
	for child in node.get_children():
		find_patrons_recursive(child, patrons)

func log_service_success(patron_name: String):
	"""Log successful service"""
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message("Served beer to " + patron_name)

func force_patron_to_leave():
	"""Debug function to make patron leave"""
	var patrons = find_all_patrons()
	for patron in patrons:
		if patron is RealisticPatron:
			patron.leave_disappointed()
			break

# ==========================================
# SETUP INSTRUCTIONS
# ==========================================

"""
CUSTOMIZED SETUP:

1. TABLE COORDINATES:
   - Currently set to your table at x=0, y=0, z=3.059
   - Patron will walk directly to this position

2. SPAWNING:
   - Only ONE patron at a time
   - New patron every 30 seconds (only after previous one leaves)
   - No timer-based leaving (patron waits until served or forced to leave)

3. SERVICE INDICATOR:
   - Created in code (yellow sphere above head)
   - You can replace this with your own Godot scene setup

4. PAYMENT SYSTEM:
   - Base price: 6 gold (beer costs 5, profit margin)
   - Knight tip: 1-3 additional gold
   - Total payment: 7-9 gold per beer

5. COLLISION SETUP:
   - NPCs use layer 4
   - They collide with environment (layer 2)
   - Make sure your tavern walls/floor use layer 2

6. NO AUTOMATIC TIMEOUT:
   - Patron waits indefinitely until served
   - You control when they leave (ESC key for testing)

TO IMPLEMENT:
1. Create RealisticPatron.gd script
2. Add SinglePatronSpawner as Node3D in your scene
3. Update your player.gd with service code
4. Adjust table_position coordinates if needed
"""
