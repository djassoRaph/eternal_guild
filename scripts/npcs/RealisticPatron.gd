# RealisticPatron.gd
extends CharacterBody3D
class_name RealisticPatron

# Movement constants (no longer used)
const SPEED = 2.5
const GRAVITY = 9.8

# State machine
enum PatronState {
	WALKING_TO_TABLE,
	SITTING_WAITING,
	DRINKING,
	LEAVING
}

# Navigation (no longer used for movement)
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

# State
var current_state = PatronState.SITTING_WAITING
var table_position: Vector3
var entrance_position: Vector3
var table_index: int = -1

# Service
var wants_service = false
var has_been_served = false
var payment_amount: int = 8
var patron_name: String = "Patron"

# Visuals
@onready var service_indicator: MeshInstance3D = $ServiceIndicator
@onready var patron_body_mesh: Node3D = $Mage

# Timers
@onready var sitting_timer: Timer = $SittingTimer
@onready var drinking_timer: Timer = $DrinkingTimer

# Scene references
var main_scene: Node

# Signals
signal patron_finished(patron: RealisticPatron)
signal wants_to_be_served(patron: RealisticPatron)

func _ready():
	print("🧍 RealisticPatron initializing...")
	
	main_scene = get_tree().current_scene
	
	if not sitting_timer:
		sitting_timer = Timer.new()
		sitting_timer.name = "SittingTimer"
		add_child(sitting_timer)
		sitting_timer.timeout.connect(on_sitting_timer_timeout)
	
	if not drinking_timer:
		drinking_timer = Timer.new()
		drinking_timer.name = "DrinkingTimer"
		add_child(drinking_timer)
		drinking_timer.timeout.connect(on_drinking_timer_timeout)
	
	print("✅ Patron ready")

func _physics_process(delta: float):
	# No movement code here for now!
	pass

# CRITICAL FIX: Add this function to make the 'can_be_served_by' call valid.
func can_be_served_by(player_position: Vector3) -> bool:
	"""Checks if the patron is in the right state and close enough to be served."""
	var distance = global_position.distance_to(player_position)
	var serving_range = 2.0 # You can adjust this value
	
	return current_state == PatronState.SITTING_WAITING and distance <= serving_range

func set_up_for_static_spawn():
	"""Sets up patron to immediately wait for service without walking."""
	global_position = Vector3(8.7, 0.0, 3.3)
	current_state = PatronState.SITTING_WAITING
	wants_service = true
	sitting_timer.wait_time = randi_range(15, 30)
	sitting_timer.start()
	service_indicator.visible = true
	wants_to_be_served.emit(self)
	
	print("🧍 Patron is now waiting at the bar.")

func serve_patron():
	"""The player serves the patron a drink."""
	if current_state != PatronState.SITTING_WAITING:
		print("❌ Patron is not waiting for service.")
		return
	
	sitting_timer.stop()
	service_indicator.visible = false
	
	current_state = PatronState.DRINKING
	drinking_timer.wait_time = randi_range(10, 20)
	drinking_timer.start()
	print("🍺 Patron is now drinking.")

func on_sitting_timer_timeout():
	"""Patron gets impatient and leaves."""
	if current_state == PatronState.SITTING_WAITING:
		print("😡 Patron got impatient and is leaving.")
		current_state = PatronState.LEAVING
		patron_finished.emit(self)

func on_drinking_timer_timeout():
	"""Patron finished drinking and pays."""
	if current_state == PatronState.DRINKING:
		print("💰 Patron finished drinking. Paying...")
		GameManager.add_gold(payment_amount)
		current_state = PatronState.LEAVING
		patron_finished.emit(self)
