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
var fire_quality: float = 0.0  # 0-100, continuously drains while burning
var cooldown_remaining: float = 0.0

# Band durations (seconds) — loaded from game_config.json. Each is how long fire_quality
# takes to drain across one band (100->50, 50->20, 20->0); ~7-min full burn for testing.
var _burn_high: float = 240.0
var _burn_low: float = 120.0
var _dying: float = 60.0
var _fail_cooldown: float = 30.0

# Fuel-band thresholds (%): fire_quality glides down through these and the burning
# state is derived from whichever band it sits in.
const FUEL_HIGH_FLOOR: float = 50.0
const FUEL_LOW_FLOOR: float = 20.0
var _last_pushed_fuel: int = -1  # throttles HUD pushes to whole-% changes

# ===== PLAYER INTERACTION =====
var player_nearby: bool = false
var _anchor_tries := 0   # frames spent waiting to anchor the E prompt on the hearth (Story 25.10)

# ===== MINIGAME REFERENCE =====
var minigame_scene = preload("res://scenes/ui/FireplaceMinigamePanel.tscn")
var active_minigame = null

# ===== VISUAL ELEMENTS =====
# The 3D hearth (scenes/game/Hearth.tscn, group "hearth") owns the fire's look: light, flames,
# sparks, smoke, ember glow and logs. This zone pushes the fuel to it (Story 25.5).
var _hearth: Node3D = null

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
		print("GameManager doesn't have day_changed signal!")
	
	# Connect to GameManager fuel changes for visual updates
	if GameManager.has_signal("fireplace_fuel_changed"):
		GameManager.fireplace_fuel_changed.connect(_update_fire_visuals)
	
	# Burn durations from config (tunable — see game_config.json)
	if DataManager:
		_burn_high = float(DataManager.get_config("fire_burn_high_seconds", _burn_high))
		_burn_low = float(DataManager.get_config("fire_burn_low_seconds", _burn_low))
		_dying = float(DataManager.get_config("fire_dying_seconds", _dying))
		_fail_cooldown = float(DataManager.get_config("fire_cooldown_seconds", _fail_cooldown))

	# The hearth that shows the fire. (The old relative paths to Furniture/Fireplace climbed one
	# level too far, landed under SubViewport and returned null, so the fire never changed; 25.5.)
	_hearth = get_tree().get_first_node_in_group("hearth") as Node3D
	if _hearth == null:
		push_warning("[Fireplace] no node in group 'hearth': the fire has no visuals")

	# Initialize visuals
	_update_fire_visuals(GameManager.get_fireplace_fuel())
	
	print("Fireplace interaction zone ready - Minigame system active")

func _process(delta):
	if not has_meta("prompt_anchored") and _anchor_tries < 600:   # once the prompt UI has registered this zone
		_anchor_tries += 1                                           # (give up after ~10 s: no hearth marker)
		var ui = preload("res://scripts/game/ZonePromptUI.gd").find(get_tree())
		if ui and ui.connected_zones.has(self):
			_anchor_on_hearth(ui)
	# Handle state timers
	match current_state:
		FireplaceState.BURNING_HIGH, FireplaceState.BURNING_LOW, FireplaceState.DYING:
			_process_fire_decay(delta)
		FireplaceState.COOLDOWN:
			_process_cooldown(delta)

# ===== PLAYER DETECTION =====
func _on_player_entered(body):
	if body.name == "Player":
		player_nearby = true
		_show_interaction_prompt()
		print("Player near fireplace")

func _on_player_exited(body):
	if body.name == "Player":
		player_nearby = false
		_hide_interaction_prompt()
		print("Player left fireplace")

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
		# One E owner (Story 25.10, J6): beside the hearth the player can also stand in the cat's or Den Fa's
		# zone; the prompt UI gives E to the nearest (and to a waiting patron, a pause or Game Over first).
		var ui = preload("res://scripts/game/ZonePromptUI.gd").find(get_tree())
		if ui and ui.connected_zones.has(self) and not ui.owns_e(self):
			return
		_on_player_interact()

func _anchor_on_hearth(ui) -> void:
	"""The fire's E distance is measured from where it is tended: the hearth's interact_point."""
	if _hearth and not has_meta("prompt_anchored"):
		var p = _hearth.find_child("interact_point", true, false)
		if p:
			ui.set_anchor(self, p)
			set_meta("prompt_anchored", true)

func _on_player_interact():
	"""Called when player presses E near fireplace"""
	
	# Check if in cooldown state
	if current_state == FireplaceState.COOLDOWN:
		var minutes_left = int(cooldown_remaining / 60.0)
		GameManager.log_message("Still feeling dizzy from overbreathing... Try again in %d minutes" % minutes_left)
		return
	
	# Check if fire is already burning well
	if current_state == FireplaceState.BURNING_HIGH:
		GameManager.log_message("The fire is roaring nicely! No need to tend it right now.")
		return
	
	# Open minigame for DORMANT, BURNING_LOW, or DYING states
	if current_state in [FireplaceState.DORMANT, FireplaceState.BURNING_LOW, FireplaceState.DYING]:
		# Can't light a fire without firewood — need at least 2 logs to build it
		if GameManager.get_firewood_stock() < 2:
			GameManager.log_message("Not enough firewood to light the fire (need 2). Buy some from your quarters.")
			return
		_open_minigame()

# ===== MINIGAME MANAGEMENT =====
func _exit_tree():
	# If the minigame is still open when this zone leaves the tree (e.g. Esc → Main Menu mid-game),
	# free it so it doesn't orphan on the root and linger over the next scene — and un-pause. (Bugfix)
	if active_minigame and is_instance_valid(active_minigame):
		active_minigame.queue_free()
		active_minigame = null
	if _hearth and is_instance_valid(_hearth):
		_hearth.set_placed_logs(0)
	if get_tree():
		get_tree().paused = false

func _open_minigame():
	"""Open the fireplace minigame window"""
	print("Opening fireplace minigame")
	
	# Instantiate minigame
	active_minigame = minigame_scene.instantiate()
	active_minigame.z_index = 100  # Force it to top
	
	# CRITICAL: Set minigame to process even when paused
	active_minigame.process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect the minigame's logs to real firewood stock (caps how many logs can be placed)
	active_minigame.available_firewood = GameManager.get_firewood_stock()

	get_tree().root.add_child(active_minigame)
	
	# Pause game - player and NPCs will freeze
	get_tree().paused = true
	
	# Connect minigame signals
	if active_minigame.has_signal("minigame_completed"):
		active_minigame.minigame_completed.connect(_on_minigame_completed)
	# Each placed log shows up on the hearth's andirons while the minigame is open
	if _hearth and active_minigame.has_signal("log_placed"):
		active_minigame.log_placed.connect(_hearth.set_placed_logs)
	
	# Update state
	current_state = FireplaceState.IGNITING
	state_changed.emit(current_state)

func _on_minigame_completed(success: bool, quality: float):
	"""Handle minigame completion"""
	print("Minigame completed - Success: %s, Quality: %.1f" % [success, quality])
	if _hearth:
		_hearth.set_placed_logs(0)  # the placed logs are burning now (or taken back); the fuel decides

	# Unpause game
	get_tree().paused = false
	
	if success:
		# SUCCESS - Fire is lit! Burn the firewood (logs) used to build it.
		var logs_used: int = active_minigame.logs_placed if active_minigame else 2
		GameManager.consume_firewood(logs_used)

		# Stoke: ADD this light's quality on top of whatever is still burning (capped at
		# 100) so re-lighting a dying fire builds it back up instead of resetting to 0.
		fire_quality = min(100.0, fire_quality + quality)
		_last_pushed_fuel = -1  # force a fresh HUD push

		# Derive the burning state from the new fuel level
		if fire_quality > FUEL_HIGH_FLOOR:
			current_state = FireplaceState.BURNING_HIGH
		elif fire_quality > FUEL_LOW_FLOOR:
			current_state = FireplaceState.BURNING_LOW
		else:
			current_state = FireplaceState.DYING

		if fire_quality >= 80.0:
			GameManager.log_message("Perfect! The fire roars to life with beautiful flames!")
		else:
			GameManager.log_message("Good work! The fire burns steadily.")
		
		# Update GameManager fuel level (for tip calculations)
		GameManager.set_fireplace_fuel(fire_quality)
		quality_changed.emit(fire_quality)
		
		# Update visuals
		_update_fire_visuals(fire_quality)
		
		# Play success effects
		_play_ignition_effects()
		
	else:
		# FAILURE - Fire didn't light
		current_state = FireplaceState.COOLDOWN
		cooldown_remaining = _fail_cooldown
		fire_quality = 0.0
		GameManager.set_fireplace_fuel(0.0)

		GameManager.log_message("You overexerted yourself! The fire won't light...")
		GameManager.log_message("Rest for a while before trying again")
		
		# Update visuals to show no fire
		_update_fire_visuals(0.0)
	
	state_changed.emit(current_state)
	
	# Clean up minigame
	if active_minigame:
		active_minigame.queue_free()
		active_minigame = null

# ===== STATE PROCESSING =====
func _process_fire_decay(delta):
	"""Continuously drain fire_quality so the HUD % ticks down smoothly every frame
	instead of snapping at stage boundaries. Drain rate depends on the band — a lower
	fire fades faster (100->50 over _burn_high, 50->20 over _burn_low, 20->0 over _dying)."""
	var rate: float
	if fire_quality > FUEL_HIGH_FLOOR:
		rate = (100.0 - FUEL_HIGH_FLOOR) / max(_burn_high, 0.001)
	elif fire_quality > FUEL_LOW_FLOOR:
		rate = (FUEL_HIGH_FLOOR - FUEL_LOW_FLOOR) / max(_burn_low, 0.001)
	else:
		rate = FUEL_LOW_FLOOR / max(_dying, 0.001)

	fire_quality = max(0.0, fire_quality - rate * delta)

	if fire_quality <= 0.0:
		current_state = FireplaceState.DORMANT
		_last_pushed_fuel = 0
		GameManager.set_fireplace_fuel(0.0)
		_update_fire_visuals(0.0)
		state_changed.emit(current_state)
		GameManager.log_message("The fire has gone out completely.")
		return

	_apply_fire_state()

func _apply_fire_state():
	"""Derive the burning state from the current fuel band (logging each crossing) and
	push the value to the HUD only when the whole-number % changes — smooth, not 60x/s."""
	var new_state := current_state
	if fire_quality > FUEL_HIGH_FLOOR:
		new_state = FireplaceState.BURNING_HIGH
	elif fire_quality > FUEL_LOW_FLOOR:
		new_state = FireplaceState.BURNING_LOW
	else:
		new_state = FireplaceState.DYING

	if new_state != current_state:
		current_state = new_state
		state_changed.emit(current_state)
		if new_state == FireplaceState.BURNING_LOW:
			GameManager.log_message("The fire is starting to die down...")
		elif new_state == FireplaceState.DYING:
			GameManager.log_message("The fire needs attention soon!")

	var pct := int(round(fire_quality))
	if pct != _last_pushed_fuel:
		_last_pushed_fuel = pct
		GameManager.set_fireplace_fuel(fire_quality)
		_update_fire_visuals(fire_quality)

func _process_cooldown(delta):
	"""Process cooldown state - waiting to recover"""
	cooldown_remaining -= delta
	
	if cooldown_remaining <= 0:
		# Recovered from dizziness
		current_state = FireplaceState.DORMANT
		state_changed.emit(current_state)
		GameManager.log_message("You feel better now. Ready to try lighting the fire again!")

# ===== DAY CYCLE INTEGRATION =====
func _on_day_changed(new_day: int):
	"""Reset fireplace state on new day — fire goes out overnight"""
	print("New day - Fire has gone out overnight")

	# Reset all state
	current_state = FireplaceState.DORMANT
	fire_quality = 0.0
	cooldown_remaining = 0.0
	_last_pushed_fuel = -1

	# Update GameManager through the proper setter
	GameManager.set_fireplace_fuel(0.0)

	# Update visuals
	_update_fire_visuals(0.0)

	state_changed.emit(current_state)

	GameManager.log_message("The fire has gone out overnight. Light it to earn tips!")

# ===== VISUAL EFFECTS =====
func _play_ignition_effects():
	"""Visual feedback for a successful ignition: the hearth flashes and the flames burst."""
	if _hearth:
		_hearth.play_ignition()

func _update_fire_visuals(fuel_percent: float):
	"""Push the fuel level to the hearth; hearth.gd fire_look() decides light, flames, sparks,
	smoke, ember glow and logs from the same bands as this state machine (0 = dark)."""
	if _hearth:
		_hearth.set_fire_level(fuel_percent)
