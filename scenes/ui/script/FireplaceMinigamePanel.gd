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
var available_firewood: int = 5  # Set by fireplace_zone before _ready — caps placeable logs to real firewood stock
var dragging_log = null
var drag_offset: Vector2 = Vector2.ZERO
var placed_log_positions: Array = []  # Track where logs were placed
var target_marker: Control  # glowing ring showing where to drop the next log

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
var green_zone_wiggle_speed: float = 2.5  # Oscillation speed — livelier target (feel-tune to taste)
var green_zone_wiggle_amount: float = 60.0  # How far it drifts — more movement = more challenge (feel-tune to taste)
var wiggle_time: float = 0.0

# ===== OPTIMAL LOG PLACEMENT =====
var optimal_log_spot: Vector2 = Vector2.ZERO
var placement_tolerance: float = 80.0  # Generous for MVP

# ===== INITIALIZATION =====
func _ready():
	# CloseButton.pressed is wired in the .tscn; wire the rest here (manual hit-detection backs these up).
	if start_button:
		start_button.pressed.connect(_on_start_pumping_pressed)
	if pump_click_area:
		pump_click_area.button_down.connect(_on_pump_button_down)
		pump_click_area.button_up.connect(_on_pump_button_up)

	_apply_hearth_theme()
	_setup_draggable_logs()
	_create_target_marker()
	_update_status("Drag logs onto the glowing spot in the pit (at least 2).")

	await get_tree().process_frame  # let layout settle so the pit has a real size
	_generate_new_optimal_spot()

func _apply_hearth_theme():
	"""Warm hearth restyle — applied in code so the .tscn stays structural."""
	var amber := Color(0.90, 0.58, 0.24)
	var cream := Color(0.94, 0.88, 0.72)
	var ember := Color(0.72, 0.28, 0.12)

	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.14, 0.10, 0.08, 0.98)
	frame.border_color = Color(0.55, 0.34, 0.16, 0.95)
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(12)
	frame.set_content_margin_all(6)
	var mc := get_node_or_null("CenterContainer/MinigameContainer")
	if mc:
		mc.add_theme_stylebox_override("panel", frame)

	var base := "CenterContainer/MinigameContainer/MarginContainer/MainVBox/"
	var title := get_node_or_null(base + "TitleLabel")
	if title:
		title.add_theme_color_override("font_color", amber)
	if status_label:
		status_label.add_theme_color_override("font_color", cream)
	var pit_bg := get_node_or_null(base + "ContentHBox/FireplaceArea/MarginContainer/FireplaceBackground")
	if pit_bg:
		pit_bg.color = Color(0.09, 0.05, 0.03, 1.0)

	# Section labels + the pump-zone explanation (clarity)
	var pump_label := get_node_or_null(base + "WindPumpSection/PumpLabel")
	if pump_label:
		pump_label.text = "💨 Wind Pump — hold to fill the green, ease off the yellow"
		pump_label.add_theme_color_override("font_color", cream)
	for lbl_path in ["LungCapacitySection/LungsLabel", "IgnitionProgressSection/IgnitionLabel", "ContentHBox/LogStackArea/StackTitle"]:
		var lbl := get_node_or_null(base + lbl_path)
		if lbl:
			lbl.add_theme_color_override("font_color", cream)

	_style_bar(ignition_bar, Color(0.88, 0.38, 0.14), Color(0.18, 0.10, 0.07))
	_style_bar(lungs_bar, Color(0.38, 0.62, 0.85), Color(0.10, 0.14, 0.18))
	_style_button(start_button, ember, cream)
	_style_button(close_button, Color(0.28, 0.24, 0.20), cream)
	if pump_indicator:
		pump_indicator.color = cream

func _style_bar(bar, fill: Color, bg: Color):
	if not bar:
		return
	var fs := StyleBoxFlat.new()
	fs.bg_color = fill
	fs.set_corner_radius_all(4)
	var bs := StyleBoxFlat.new()
	bs.bg_color = bg
	bs.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fs)
	bar.add_theme_stylebox_override("background", bs)

func _style_button(btn, bg: Color, fg: Color):
	if not btn:
		return
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(6)
	s.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", s)
	var h := StyleBoxFlat.new()
	h.bg_color = bg.lightened(0.18)
	h.set_corner_radius_all(6)
	h.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_color_override("font_color", fg)

func _create_target_marker():
	"""A glowing ring showing where to drop the next log — fixes the invisible-target flaw."""
	target_marker = Panel.new()
	target_marker.custom_minimum_size = Vector2(72, 72)
	target_marker.size = Vector2(72, 72)
	target_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.95, 0.6, 0.25, 0.13)
	s.border_color = Color(1.0, 0.72, 0.32, 0.75)
	s.set_border_width_all(3)
	s.set_corner_radius_all(36)
	target_marker.add_theme_stylebox_override("panel", s)
	if fireplace_drop_zone:
		fireplace_drop_zone.add_child(target_marker)

func _update_target_marker():
	if target_marker:
		target_marker.position = optimal_log_spot - target_marker.size / 2

func _input(event):
	"""Handle all input - manual hit detection for logs since gui_input doesn't work on TextureRect"""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		
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
	"""Setup logs for manual dragging detection. Only as many logs as the player has firewood are usable."""
	print("Setting up draggable logs (manual hit detection)...")

	var logs = log_container.get_children()
	print("Found ", logs.size(), " log nodes; available firewood = ", available_firewood)

	var usable: int = min(available_firewood, logs.size())
	for i in range(logs.size()):
		var log = logs[i]
		if log is TextureRect:
			# Store metadata
			log.set_meta("log_index", i)
			if i < usable:
				# Backed by real firewood — playable
				log.set_meta("is_placed", false)
				log.visible = true
				log.modulate = Color(1, 1, 1, 1)
				print("    Log ", i, " ready for manual detection")
			else:
				# No firewood for this log — hide and lock it out (is_placed=true makes click-detection skip it)
				log.set_meta("is_placed", true)
				log.visible = false
				print("    Log ", i, " disabled (insufficient firewood)")
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
		current_state = MinigameState.READY_TO_PUMP
		start_button.disabled = false
		_update_status(quality_text + " placement! Ready to pump — or add up to " + str(max_logs - logs_placed) + " more (" + str(logs_placed) + "/5).")
	else:
		_update_status(quality_text + " placement! Place at least " + str(2 - logs_placed) + " more log.")

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
	# Fall back to a sensible area if the pit hasn't been laid out yet (avoids off-pit targets)
	if drop_zone_size.x < 120 or drop_zone_size.y < 120:
		drop_zone_size = Vector2(360, 260)

	# Random position within fireplace, with some margin
	var margin = 50.0
	optimal_log_spot = Vector2(
		randf_range(margin, max(margin + 1.0, drop_zone_size.x - margin)),
		randf_range(margin, max(margin + 1.0, drop_zone_size.y - margin))
	)
	
	_update_target_marker()

# ===== PUMP PHASE =====
func _on_start_pumping_pressed():
	"""Start the pumping phase"""
	if current_state != MinigameState.READY_TO_PUMP:
		return

	current_state = MinigameState.PUMPING
	start_button.disabled = true
	start_button.text = "PUMPING..."
	if target_marker:
		target_marker.visible = false  # placing done — hide the target
	_update_status("Hold the gauge to pump — catch the green sweet spot, avoid the yellow!")

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
	
	# Pulse the target marker while placing logs
	if target_marker and target_marker.visible:
		target_marker.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 280.0)

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
