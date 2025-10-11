# fireplace_zone.gd
# Attach to: TavernNavigation/Interactive/FireplaceZone (Area3D)
extends Area3D

var player_nearby: bool = false

# References to visual elements (set in _ready)
@onready var fire_light: OmniLight3D
@onready var fire_particles: GPUParticles3D

func _ready():
	# Connect area signals
	body_entered.connect(_on_player_entered)
	body_exited.connect(_on_player_exited)
	
	# Connect to GameManager fuel changes for visual updates
	GameManager.fireplace_fuel_changed.connect(_update_fire_visuals)
	
	# Get references to visual elements
	fire_light = get_node_or_null("../../../Furniture/Fireplace/FireLight")
	fire_particles = get_node_or_null("../../../Furniture/Fireplace/FireParticles")
	
	# Initialize visuals
	_update_fire_visuals(GameManager.get_fireplace_fuel())
	
	print("🔥 Fireplace interaction zone ready")

func _on_player_entered(body):
	if body.name == "Player":
		player_nearby = true
		print("🔥 Player near fireplace")

func _on_player_exited(body):
	if body.name == "Player":
		player_nearby = false
		print("🚶 Player left fireplace")

func _input(event):
	# Only handle input if player is nearby
	if not player_nearby:
		return
	
	# Check for E key (interact action)
	if event.is_action_pressed("interact"):
		attempt_stoke_fire()

func attempt_stoke_fire():
	"""Try to stoke the fireplace"""
	var current_fuel = GameManager.get_fireplace_fuel()
	
	# Check if already at max
	if current_fuel >= 100.0:
		GameManager.log_message("🔥 The fire is already roaring at full strength!")
		return
	
	# Try to use firewood
	if GameManager.stoke_fireplace():
		# Success - play effects
		play_stoking_effects()
	else:
		# Failed - no firewood
		GameManager.log_message("❌ You need firewood to stoke the fire!")
		GameManager.log_message("💡 Buy firewood from your quarters before sleeping")

func play_stoking_effects():
	"""Visual/audio feedback for stoking fire"""
	# Particle burst effect
	if fire_particles:
		fire_particles.restart()
	
	# Light flicker effect
	if fire_light:
		var tween = create_tween()
		tween.tween_property(fire_light, "light_energy", fire_light.light_energy * 1.5, 0.2)
		tween.tween_property(fire_light, "light_energy", fire_light.light_energy, 0.3)
	
	# Success message already handled in GameManager.stoke_fireplace()

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
