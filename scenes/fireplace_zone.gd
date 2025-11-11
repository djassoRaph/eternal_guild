# fireplace_zone.gd
# Attach to: TavernNavigation/Interactive/FireplaceArea (Area3D)
extends Area3D

# ===== FIREPLACE STATE MACHINE =====
enum FireplaceState {
	DORMANT,      # Cold, needs ignition
	IGNITING,     # Minigame in progress
	BURNING_HIGH, # High comfort, good tips
	BURNING_LOW,  # Low comfort, reduced tips
	DYING,        # Almost out
	COOLDOWN      # Failed attempt, wait period
}

var current_state: FireplaceState = FireplaceState.DORMANT
var fire_quality: float = 0.0  # 0-100
var cooldown_remaining: float = 0.0
var burn_time_remaining: float = 0.0

# ===== PLAYER INTERACTION =====
var player_nearby: bool = false

# ===== MINIGAME REFERENCE =====
var minigame_scene = preload("res://scenes/ui/FireplaceMinigamePanel.tscn")
var active_minigame = null

# ===== VISUAL ELEMENTS =====
@onready var fire_light: OmniLight3D
@onready var fire_particles: GPUParticles3D

# ===== SIGNALS =====
signal state_changed(new_state: FireplaceState)
signal quality_changed(new_quality: float)

func _ready():
	# Connect area signals for player detection
	body_entered.connect(_on_player_entered)
	body_exited.connect(_on_player_exited)
	
	# Connect to GameManager day cycle
	if GameManager.has_signal("day_changed"):
		GameManager.day_changed.connect(_on_day_changed)
	else:
		print("⚠️ GameManager doesn't have day_changed signal!")
	
	# Connect to GameManager fuel changes for visual updates
	if GameManager.has_signal("fireplace_fuel_changed"):
		GameManager.fireplace_fuel_changed.connect(_update_fire_visuals)
	
	# Get references to visual elements
	fire_light = get_node_or_null("../../../Furniture/Fireplace/FireLight")
	fire_particles = get_node_or_null("../../../Furniture/Fireplace/FireParticles")
	
	# Initialize visuals
	_update_fire_visuals(GameManager.get_fireplace_fuel())
	
	print("🔥 Fireplace interaction zone ready - Minigame system active")

func _process(delta):
	# Handle state timers
	match current_state:
		FireplaceState.BURNING_HIGH:
			_process_burning(delta)
		FireplaceState.BURNING_LOW:
			_process_burning(delta)
		FireplaceState.DYING:
			_process_dying(delta)
		FireplaceState.COOLDOWN:
			_process_cooldown(delta)

# ===== PLAYER DETECTION =====
func _on_player_entered(body):
	if body.name == "Player":
		player_nearby = true
		_show_interaction_prompt()
		print("🔥 Player near fireplace")

func _on_player_exited(body):
	if body.name == "Player":
		player_nearby = false
		_hide_interaction_prompt()
		print("🚶 Player left fireplace")

func _show_interaction_prompt():
	"""Show 'E - Manage Fire' prompt"""
	# TODO: Connect to your existing prompt UI system
	# Example: ZonePromptUI.show_prompt("E - Manage Fire")
	pass

func _hide_interaction_prompt():
	"""Hide interaction prompt"""
	# TODO: Connect to your existing prompt UI system
	# Example: ZonePromptUI.hide_prompt()
	pass

# ===== INTERACTION HANDLING =====
func _input(event):
	# Only handle input if player is nearby
	if not player_nearby:
		return
	
	# Check for E key (interact action)
	if event.is_action_pressed("interact"):
		_on_player_interact()

func _on_player_interact():
	"""Called when player presses E near fireplace"""
	
	# Check if in cooldown state
	if current_state == FireplaceState.COOLDOWN:
		var minutes_left = int(cooldown_remaining / 60.0)
		GameManager.log_message("😵 Still feeling dizzy from overbreathing... Try again in %d minutes" % minutes_left)
		return
	
	# Check if fire is already burning well
	if current_state == FireplaceState.BURNING_HIGH:
		GameManager.log_message("🔥 The fire is roaring nicely! No need to tend it right now.")
		return
	
	# Open minigame for DORMANT, BURNING_LOW, or DYING states
	if current_state in [FireplaceState.DORMANT, FireplaceState.BURNING_LOW, FireplaceState.DYING]:
		_open_minigame()

# ===== MINIGAME MANAGEMENT =====
func _open_minigame():
	"""Open the fireplace minigame window"""
	print("🔥 Opening fireplace minigame")
	
	# Instantiate minigame
	active_minigame = minigame_scene.instantiate()
	active_minigame.z_index = 100  # Force it to top
	
	# CRITICAL: Set minigame to process even when paused
	active_minigame.process_mode = Node.PROCESS_MODE_ALWAYS
	
	get_tree().root.add_child(active_minigame)
	
	# Pause game - player and NPCs will freeze
	get_tree().paused = true
	
	# Connect minigame signals
	if active_minigame.has_signal("minigame_completed"):
		active_minigame.minigame_completed.connect(_on_minigame_completed)
	
	# Update state
	current_state = FireplaceState.IGNITING
	state_changed.emit(current_state)

func _on_minigame_completed(success: bool, quality: float):
	"""Handle minigame completion"""
	print("🔥 Minigame completed - Success: %s, Quality: %.1f" % [success, quality])
	
	# Unpause game
	get_tree().paused = false
	
	if success:
		# SUCCESS - Fire is lit!
		fire_quality = quality
		
		if quality >= 80:
			# High quality fire
			current_state = FireplaceState.BURNING_HIGH
			burn_time_remaining = 4.0 * 3600.0  # 4 in-game hours
			GameManager.log_message("🔥 Perfect! The fire roars to life with beautiful flames!")
		else:
			# Moderate quality fire
			current_state = FireplaceState.BURNING_LOW
			burn_time_remaining = 3.0 * 3600.0  # 3 in-game hours
			GameManager.log_message("🔥 Good work! The fire burns steadily.")
		
		# Update GameManager fuel level (for tip calculations)
		GameManager.fireplace_fuel = int(fire_quality)
		quality_changed.emit(fire_quality)
		
		# Update visuals
		_update_fire_visuals(fire_quality)
		
		# Play success effects
		_play_ignition_effects()
		
	else:
		# FAILURE - Fire didn't light
		current_state = FireplaceState.COOLDOWN
		cooldown_remaining = 2.0 * 3600.0  # 2 in-game hours
		fire_quality = 0.0
		GameManager.fireplace_fuel = 0
		
		GameManager.log_message("😵 You overexerted yourself! The fire won't light...")
		GameManager.log_message("💡 Rest for a while before trying again")
		
		# Update visuals to show no fire
		_update_fire_visuals(0.0)
	
	state_changed.emit(current_state)
	
	# Clean up minigame
	if active_minigame:
		active_minigame.queue_free()
		active_minigame = null

# ===== STATE PROCESSING =====
func _process_burning(delta):
	"""Process burning states - count down burn time"""
	burn_time_remaining -= delta
	
	if burn_time_remaining <= 0:
		if current_state == FireplaceState.BURNING_HIGH:
			# Transition from high to low
			current_state = FireplaceState.BURNING_LOW
			burn_time_remaining = 2.0 * 3600.0  # 2 more hours
			fire_quality *= 0.5
			GameManager.fireplace_fuel = int(fire_quality)
			_update_fire_visuals(fire_quality)
			state_changed.emit(current_state)
			GameManager.log_message("🔥 The fire is starting to die down...")
			
		elif current_state == FireplaceState.BURNING_LOW:
			# Transition from low to dying
			current_state = FireplaceState.DYING
			burn_time_remaining = 30.0 * 60.0  # 30 minutes
			fire_quality *= 0.3
			GameManager.fireplace_fuel = int(fire_quality)
			_update_fire_visuals(fire_quality)
			state_changed.emit(current_state)
			GameManager.log_message("🔥 The fire needs attention soon!")

func _process_dying(delta):
	"""Process dying state - fire almost out"""
	burn_time_remaining -= delta
	
	if burn_time_remaining <= 0:
		# Fire goes out completely
		current_state = FireplaceState.DORMANT
		fire_quality = 0.0
		GameManager.fireplace_fuel = 0
		_update_fire_visuals(0.0)
		state_changed.emit(current_state)
		GameManager.log_message("💨 The fire has gone out completely.")

func _process_cooldown(delta):
	"""Process cooldown state - waiting to recover"""
	cooldown_remaining -= delta
	
	if cooldown_remaining <= 0:
		# Recovered from dizziness
		current_state = FireplaceState.DORMANT
		state_changed.emit(current_state)
		GameManager.log_message("😊 You feel better now. Ready to try lighting the fire again!")

# ===== DAY CYCLE INTEGRATION =====
func _on_day_changed(new_day: int):
	"""Reset fireplace state on new day"""
	print("🔥 New day - Resetting fireplace")
	
	# Reset all state
	current_state = FireplaceState.DORMANT
	fire_quality = 0.0
	GameManager.fireplace_fuel = 0
	cooldown_remaining = 0.0
	burn_time_remaining = 0.0
	
	# Update visuals
	_update_fire_visuals(0.0)
	
	state_changed.emit(current_state)

# ===== VISUAL EFFECTS =====
func _play_ignition_effects():
	"""Visual/audio feedback for successful fire ignition"""
	# Particle burst effect
	if fire_particles:
		fire_particles.restart()
	
	# Light flicker effect
	if fire_light:
		var tween = create_tween()
		tween.tween_property(fire_light, "light_energy", fire_light.light_energy * 1.8, 0.3)
		tween.tween_property(fire_light, "light_energy", fire_light.light_energy, 0.4)

func _update_fire_visuals(fuel_percent: float):
	"""Update fire visuals based on fuel level"""
	
	# === LIGHT INTENSITY ===
	if fire_light:
		# Range: 0.2 (nearly out) to 2.0 (roaring)
		fire_light.light_energy = 0.2 + (fuel_percent / 100.0) * 1.8
		
		# Color shift: Red (low) to Orange (high)
		var red = 1.0
		var green = 0.3 + (fuel_percent / 100.0) * 0.5  # 0.3 to 0.8
		var blue = 0.1
		fire_light.light_color = Color(red, green, blue)
	
	# === PARTICLE AMOUNT ===
	if fire_particles:
		# Range: 10 (dying embers) to 50 (full blaze)
		fire_particles.amount = int(10 + (fuel_percent / 100.0) * 40)
		
		# Emission strength
		var process_material = fire_particles.process_material as ParticleProcessMaterial
		if process_material:
			process_material.initial_velocity_min = 1.0 + (fuel_percent / 100.0) * 2.0
			process_material.initial_velocity_max = 2.0 + (fuel_percent / 100.0) * 3.0
	
	# === VISUAL STATE FEEDBACK ===
	if fuel_percent <= 0:
		pass  # Fire is completely out (handled by low light/particles)
	elif fuel_percent < 25:
		pass  # Dying fire (low visuals)
	elif fuel_percent < 50:
		pass  # Moderate fire
	elif fuel_percent < 75:
		pass  # Good fire
	else:
		pass  # Roaring fire (max visuals)
