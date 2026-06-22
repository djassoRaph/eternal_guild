# FireplaceMinigamePanel.gd
extends Control

# ===== SIGNALS =====
signal minigame_completed(success: bool, quality: float)

# ===== NODE REFERENCES =====
@onready var fireplace_drop_zone = $CenterContainer/MinigameContainer/MarginContainer/MainVBox/ContentHBox/FireplaceArea/MarginContainer/DropZone
@onready var log_container = $CenterContainer/MinigameContainer/MarginContainer/MainVBox/ContentHBox/LogStackArea/LogContainer
@onready var pump_gauge_container = $CenterContainer/MinigameContainer/MarginContainer/MainVBox/WindPumpSection/PumpGaugeContainer
@onready var pump_indicator = %PumpIndicator  # This one HAS unique name
@onready var green_zone = $CenterContainer/MinigameContainer/MarginContainer/MainVBox/WindPumpSection/PumpGaugeContainer/GreenZone
@onready var pump_click_area = $CenterContainer/MinigameContainer/MarginContainer/MainVBox/WindPumpSection/PumpGaugeContainer/ClickArea
@onready var lungs_bar = $CenterContainer/MinigameContainer/MarginContainer/MainVBox/LungCapacitySection/LungsProgressBar
@onready var ignition_bar = $CenterContainer/MinigameContainer/MarginContainer/MainVBox/IgnitionProgressSection/IgnitionProgressBar
@onready var status_label = $CenterContainer/MinigameContainer/MarginContainer/MainVBox/StatusLabel
@onready var close_button = $CenterContainer/MinigameContainer/MarginContainer/MainVBox/ButtonContainer/CloseButton
@onready var start_button = $CenterContainer/MinigameContainer/MarginContainer/MainVBox/ButtonContainer/StartPumpingButton

# ===== GAME STATE =====
enum MinigameState {
	PLACING_LOGS,    # Player dragging logs
	READY_TO_PUMP,   # 2+ logs placed, can start pumping
	PUMPING,         # Active pumping phase
	SUCCESS,         # Fire lit successfully
	FAILURE          # Ran out of air or blew fire out
}

var current_state: MinigameState = MinigameState.PLACING_LOGS

# ===== LOG MANAGEMENT =====
var max_logs: int = 5
var logs_placed: int = 0
var dragging_log = null
var drag_offset: Vector2 = Vector2.ZERO
var placed_log_positions: Array = []  # Track where logs were placed

# ===== PUMP MECHANICS =====
var is_pumping: bool = false
var pump_pressure: float = 0.0  # 0-100, shows on indicator
var lung_capacity: float = 100.0
var ignition_progress: float = 0.0

# Pump settings
const PRESSURE_BUILD_RATE: float = 90.0  # How fast pressure builds while holding
const PRESSURE_DECAY_RATE: float = 100.0  # How fast pressure drops when released
const LUNG_DEPLETION_RATE: float = 10.0  # Per second while holding (was 20 - now 25% less)
const IGNITION_GAIN_IN_GREEN: float = 90.0  # Per second in green zone (was 30 - now 33% more)
const IGNITION_DECAY_RATE: float = 2.0  # Per second when not pumping (was 5 - now 40% less)
const IGNITION_PENALTY_IN_YELLOW: float = 15.0  # Per second in yellow zone

# Win/fail thresholds
const WIN_IGNITION_THRESHOLD: float = 100.0
const MIN_QUALITY_THRESHOLD: float = 50.0

# ===== GREEN ZONE WIGGLE =====
var green_zone_center: float = 400.0  # Base position
var green_zone_wiggle_speed: float = 1.5  # Oscillation speed (was 2.0 - now slower)
var green_zone_wiggle_amount: float = 35.0  # How far it moves (was 50 - now less movement)
var wiggle_time: float = 0.0

# ===== OPTIMAL LOG PLACEMENT =====
var optimal_log_spot: Vector2 = Vector2.ZERO
var placement_tolerance: float = 80.0  # Generous for MVP

# ===== INITIALIZATION =====
func _ready():
	print("Fireplace minigame initializing...")
	
	# Debug: Check if all nodes exist
	if not fireplace_drop_zone:
		print("ERROR: fireplace_drop_zone not found!")
	if not log_container:
		print("ERROR: log_container not found!")
	if not pump_gauge_container:
		print("ERROR: pump_gauge_container not found!")
	if not pump_indicator:
		print("ERROR: pump_indicator not found!")
	if not green_zone:
		print("ERROR: green_zone not found!")
	if not pump_click_area:
		print("ERROR: pump_click_area not found!")
	if not lungs_bar:
		print("ERROR: lungs_bar not found!")
	if not ignition_bar:
		print("ERROR: ignition_bar not found!")
	if not status_label:
		print("ERROR: status_label not found!")
	if not close_button:
		print("ERROR: close_button not found!")
	if not start_button:
		print("ERROR: start_button not found!")
	
	print("All nodes loaded successfully!")
	
	# Setup buttons with error checking
	if close_button:
		print("Connecting close button...")
		close_button.pressed.connect(_on_close_button_pressed)
		print("Close button connected")
	else:
		print("Close button not found!")
	
	if start_button:
		print("Connecting start button...")
		start_button.pressed.connect(_on_start_pumping_pressed)
		print("Start button connected")
	else:
		print("Start button not found!")
	
	if pump_click_area:
		print("Connecting pump area...")
		pump_click_area.button_down.connect(_on_pump_button_down)
		pump_click_area.button_up.connect(_on_pump_button_up)
		print("Pump area connected")
	else:
		print("Pump click area not found!")
	
	# Make logs draggable
	_setup_draggable_logs()
	
	# Generate first optimal spot
	_generate_new_optimal_spot()
	
	# Initial state
	_update_status("Drag logs into the fireplace (need at least 2)")
	
	print("Fireplace minigame ready!")

func _input(event):
	"""Handle all input - manual hit detection for logs since gui_input doesn't work on TextureRect"""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		print("Mouse click detected at: ", mouse_pos, " pressed: ", event.pressed)
		
		if event.pressed:
			# Check if clicking on a log or button
			_check_log_click(mouse_pos)
		else:
			# Release
			if dragging_log:
				# Stop dragging log
				_stop_dragging_log(mouse_pos)
			elif is_pumping:
				# Stop pumping
				print("MANUALLY DETECTED PUMP RELEASE - Stopping pump!")
				_on_pump_button_up()
		
		# CRITICAL: Don't consume the event so buttons can still work!
		# (Don't call accept_event() or set_input_as_handled())

func _check_log_click(click_pos: Vector2):
	"""Check if click position hits any log OR BUTTONS OR PUMP GAUGE"""
	
	# Check if clicking on PUMP GAUGE (during pumping phase)
	if current_state == MinigameState.PUMPING and pump_gauge_container:
		var gauge_rect = pump_gauge_container.get_global_rect()
		if gauge_rect.has_point(click_pos):
			print("MANUALLY DETECTED PUMP GAUGE CLICK - Starting pump!")
			_on_pump_button_down()
			return
	
	# Check if clicking on Start Pumping button (manual detection as backup)
	if start_button and not start_button.disabled:
		var button_rect = start_button.get_global_rect()
		if button_rect.has_point(click_pos):
			print("MANUALLY DETECTED START BUTTON CLICK!")
			_on_start_pumping_pressed()
			return
	
	# Check if clicking on Give Up button
	if close_button:
		var close_rect = close_button.get_global_rect()
		if close_rect.has_point(click_pos):
			print("MANUALLY DETECTED CLOSE BUTTON CLICK!")
			_on_close_button_pressed()
			return
	
	# Only check logs if not in pumping phase
	if current_state == MinigameState.PUMPING:
		return
	
	var logs = log_container.get_children()
	for log in logs:
		if log is TextureRect and not log.get_meta("is_placed"):
			var log_rect = log.get_global_rect()
			if log_rect.has_point(click_pos):
				print("Clicked on log ", log.get_meta("log_index"), "!")
				_start_dragging_log(log, click_pos - log.global_position)
				return

func _setup_draggable_logs():
	"""Setup logs for manual dragging detection"""
	print("Setting up draggable logs (manual hit detection)...")
	
	var logs = log_container.get_children()
	print("Found ", logs.size(), " log nodes")
	
	for i in range(logs.size()):
		var log = logs[i]
		if log is TextureRect:
			# Store metadata
			log.set_meta("log_index", i)
			log.set_meta("is_placed", false)
			print("    Log ", i, " ready for manual detection")
		else:
			print("    Node ", i, " is not a TextureRect!")

# ===== LOG DRAGGING SYSTEM =====
# Note: Using manual _input() hit detection instead of gui_input 
# because TextureRect.gui_input signal doesn't fire reliably

func _start_dragging_log(log: TextureRect, local_pos: Vector2):
	"""Start dragging a log"""
	dragging_log = log
	drag_offset = local_pos
	
	# Reparent to root for free movement
	var global_pos = log.global_position
	log.get_parent().remove_child(log)
	add_child(log)
	log.global_position = global_pos
	
	print("Started dragging log ", log.get_meta("log_index"))

func _stop_dragging_log(drop_position: Vector2):
	"""Stop dragging and check if dropped in fireplace"""
	if not dragging_log:
		return
	
	var log = dragging_log
	dragging_log = null
	
	# Check if dropped in fireplace zone
	var drop_zone_rect = fireplace_drop_zone.get_global_rect()
	
	if drop_zone_rect.has_point(drop_position):
		# PLACED IN FIREPLACE!
		_place_log_in_fireplace(log, drop_position)
	else:
		# NOT in fireplace - return to stack
		_return_log_to_stack(log)

func _place_log_in_fireplace(log: TextureRect, drop_position: Vector2):
	"""Place log in fireplace and check quality"""
	
	# Convert global position to local within drop zone
	# For Control nodes, we need to calculate relative position manually
	var local_pos = drop_position - fireplace_drop_zone.global_position
	
	print("Placing log at local pos: ", local_pos)
	
	# Calculate distance from optimal spot
	var distance = local_pos.distance_to(optimal_log_spot)
	var quality = _calculate_placement_quality(distance)
	
	# Reparent to drop zone
	remove_child(log)
	fireplace_drop_zone.add_child(log)
	log.position = local_pos - log.size / 2  # Center on cursor
	
	# Mark as placed
	log.set_meta("is_placed", true)
	log.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Can't drag anymore
	
	# Reduce opacity slightly to show it's placed
	log.modulate = Color(0.8, 0.8, 0.8, 1.0)
	
	logs_placed += 1
	placed_log_positions.append({"position": local_pos, "quality": quality})
	
	# Feedback
	var quality_text = _get_quality_feedback(quality)
	print("Log placed! Quality: ", quality_text, " (", quality, ")")
	
	# Generate new optimal spot for next log
	_generate_new_optimal_spot()
	
	# Check if ready to pump
	print("Checking readiness: logs_placed = ", logs_placed)
	if logs_placed >= 2:
		print("Enough logs! Enabling button...")
		current_state = MinigameState.READY_TO_PUMP
		start_button.disabled = false
		_update_status("Ready! Click 'Start Pumping' when ready (" + str(logs_placed) + "/5 logs placed)")
		print("   State: ", current_state)
		print("   Button disabled: ", start_button.disabled)
	else:
		_update_status("Good! Place at least " + str(2 - logs_placed) + " more log(s)")

func _return_log_to_stack(log: TextureRect):
	"""Return log to original position in stack"""
	var log_index = log.get_meta("log_index")
	
	# Remove from wherever it is
	log.get_parent().remove_child(log)
	
	# Add back to log container at original position
	log_container.add_child(log)
	log_container.move_child(log, log_index)
	
	# Reset to default
	log.position = Vector2.ZERO
	log.modulate = Color(1, 1, 1, 1)
	
	print("Log returned to stack")

func _calculate_placement_quality(distance: float) -> float:
	"""Calculate placement quality based on distance from optimal spot"""
	if distance <= placement_tolerance * 0.3:
		return 1.0  # Perfect
	elif distance <= placement_tolerance * 0.6:
		return 0.8  # Good
	elif distance <= placement_tolerance:
		return 0.6  # Okay
	else:
		return 0.4  # Poor

func _get_quality_feedback(quality: float) -> String:
	"""Get text feedback for placement quality"""
	if quality >= 0.9:
		return "PERFECT!"
	elif quality >= 0.7:
		return "Good"
	elif quality >= 0.5:
		return "Okay"
	else:
		return "Poor"

func _generate_new_optimal_spot():
	"""Generate a new random optimal log placement position"""
	var drop_zone_size = fireplace_drop_zone.size
	
	# Random position within fireplace, with some margin
	var margin = 50.0
	optimal_log_spot = Vector2(
		randf_range(margin, drop_zone_size.x - margin),
		randf_range(margin, drop_zone_size.y - margin)
	)
	
	print("New optimal spot: ", optimal_log_spot)
	
	# TODO: Optionally show visual hint (subtle glow or X marker)

# ===== PUMP PHASE =====
func _on_start_pumping_pressed():
	"""Start the pumping phase"""
	print("START PUMPING BUTTON PRESSED!")
	print("   Current state: ", current_state)
	print("   Logs placed: ", logs_placed)
	
	if current_state != MinigameState.READY_TO_PUMP:
		print("   Wrong state! Need READY_TO_PUMP")
		return
	
	current_state = MinigameState.PUMPING
	start_button.disabled = true
	start_button.text = "PUMPING..."
	
	_update_status("Hold the pump gauge to blow air! Watch the green zone!")
	
	print("Pumping phase started!")

func _on_pump_button_down():
	"""Player started holding pump button"""
	print("_on_pump_button_down called! Current state: ", current_state)
	
	if current_state != MinigameState.PUMPING:
		print("   Wrong state! Not in PUMPING mode")
		return
	
	is_pumping = true
	print("Started pumping - is_pumping = true")

func _on_pump_button_up():
	"""Player released pump button"""
	is_pumping = false
	print("Stopped pumping")

# ===== MAIN LOOP =====
func _process(delta: float):
	# Update dragging visual
	if dragging_log:
		dragging_log.global_position = get_global_mouse_position() - drag_offset
	
	# Update pump indicator position
	_update_pump_indicator()
	
	# Wiggle green zone during pumping
	if current_state == MinigameState.PUMPING:
		_update_green_zone_wiggle(delta)
		_process_pumping(delta)

func _update_pump_indicator():
	"""Update indicator position based on pump PRESSURE (not mouse!)"""
	# Indicator position based on current pressure (0-100)
	var gauge_width = pump_gauge_container.size.x - pump_indicator.size.x
	var indicator_x = (pump_pressure / 100.0) * gauge_width
	
	pump_indicator.position.x = indicator_x

func _update_green_zone_wiggle(delta: float):
	"""Animate the green zone wiggling left/right"""
	wiggle_time += delta * green_zone_wiggle_speed
	
	# Sine wave oscillation
	var wiggle_offset = sin(wiggle_time) * green_zone_wiggle_amount
	
	# Update green zone position (centered around base position)
	var new_position = green_zone_center + wiggle_offset
	green_zone.position.x = new_position

func _process_pumping(delta: float):
	"""Handle pumping mechanics - pressure builds when holding, decays when released"""
	
	# Debug every 30 frames
	if Engine.get_process_frames() % 30 == 0:
		print("Processing pump: is_pumping=", is_pumping, " pressure=", pump_pressure, " ignition=", ignition_progress, " lungs=", lung_capacity)
	
	if is_pumping:
		# BUILD PRESSURE while holding
		pump_pressure += PRESSURE_BUILD_RATE * delta
		pump_pressure = min(100.0, pump_pressure)
		
		# Deplete lung capacity
		lung_capacity -= LUNG_DEPLETION_RATE * delta
		lung_capacity = max(0.0, lung_capacity)
		
		# Check which zone the PRESSURE puts us in
		var zone = _get_zone_at_pressure(pump_pressure)
		
		match zone:
			"green":
				# GOOD! Add ignition progress
				ignition_progress += IGNITION_GAIN_IN_GREEN * delta
				ignition_progress = min(WIN_IGNITION_THRESHOLD, ignition_progress)
			
			"yellow":
				# BAD! Lose progress and extra lung capacity
				ignition_progress -= IGNITION_PENALTY_IN_YELLOW * delta
				ignition_progress = max(0.0, ignition_progress)
				lung_capacity -= LUNG_DEPLETION_RATE * 0.5 * delta  # Extra penalty
			
			"red":
				# NEUTRAL - no progress gained or lost, but still depletes lungs
				pass
		
		# Check for blowout (too much yellow zone)
		if zone == "yellow" and ignition_progress <= 0:
			_fail_minigame("You blew the fire out with too much air!")
			return
	
	else:
		# DECAY PRESSURE when not holding
		pump_pressure -= PRESSURE_DECAY_RATE * delta
		pump_pressure = max(0.0, pump_pressure)
		
		# Natural ignition decay when not pumping
		ignition_progress -= IGNITION_DECAY_RATE * delta
		ignition_progress = max(0.0, ignition_progress)
	
	# Update UI
	lungs_bar.value = lung_capacity
	ignition_bar.value = ignition_progress
	
	# Check win condition
	if ignition_progress >= WIN_IGNITION_THRESHOLD:
		var quality = _calculate_final_quality()
		_win_minigame(quality)
		return
	
	# Check fail condition
	if lung_capacity <= 0:
		_fail_minigame("You ran out of breath!")
		return

func _get_zone_at_pressure(pressure: float) -> String:
	"""Determine which zone (red/green/yellow) a pressure value is in"""
	# Convert pressure (0-100) to position on gauge
	var gauge_width = pump_gauge_container.size.x
	var pressure_position = (pressure / 100.0) * gauge_width
	
	var green_left = green_zone.position.x
	var green_right = green_zone.position.x + green_zone.size.x
	
	var yellow_left = pump_gauge_container.size.x - 200.0  # Yellow zone width is 200
	
	if pressure_position >= green_left and pressure_position <= green_right:
		return "green"
	elif pressure_position >= yellow_left:
		return "yellow"
	else:
		return "red"

# ===== WIN/FAIL CONDITIONS =====
func _calculate_final_quality() -> float:
	"""Calculate fire quality based on log placement and performance"""
	
	# Base quality from logs placed
	var log_quality = 0.0
	for log_data in placed_log_positions:
		log_quality += log_data["quality"]
	
	if placed_log_positions.size() > 0:
		log_quality /= placed_log_positions.size()  # Average quality
	
	# Bonus for placing more logs
	var log_count_bonus = (logs_placed / float(max_logs)) * 20.0
	
	# Bonus for efficient lung usage
	var lung_efficiency_bonus = (lung_capacity / 100.0) * 20.0
	
	# Final quality (0-100)
	var final_quality = (log_quality * 60.0) + log_count_bonus + lung_efficiency_bonus
	
	return clamp(final_quality, 0.0, 100.0)

func _win_minigame(quality: float):
	"""Fire successfully lit!"""
	current_state = MinigameState.SUCCESS
	
	var quality_text = "Perfect!" if quality >= 80.0 else "Good!"
	_update_status("SUCCESS! " + quality_text + " The fire roars to life!")
	
	print("Minigame won! Quality: ", quality)
	
	# Wait a moment, then emit completion
	await get_tree().create_timer(1.5).timeout
	minigame_completed.emit(true, quality)
	queue_free()

func _fail_minigame(reason: String):
	"""Failed to light fire"""
	current_state = MinigameState.FAILURE
	
	_update_status("FAILED: " + reason)
	
	print("Minigame failed: ", reason)
	
	# Wait a moment, then emit completion
	await get_tree().create_timer(2.0).timeout
	minigame_completed.emit(false, 0.0)
	queue_free()

# ===== UI HELPERS =====
func _update_status(message: String):
	"""Update status label"""
	status_label.text = message

func _on_close_button_pressed():
	"""Give up and close minigame"""
	print("CLOSE BUTTON PRESSED - Player gave up on minigame")
	
	# Unpause game first
	get_tree().paused = false
	
	# Emit failure signal
	minigame_completed.emit(false, 0.0)
	
	# Remove window
	queue_free()
