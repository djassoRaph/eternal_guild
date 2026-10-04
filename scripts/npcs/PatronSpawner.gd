# PatronSpawner.gd - NAVIGATION-ENABLED SPAWNING
extends Node3D
class_name PatronSpawner

@export var max_patrons: int = 3
@export var spawn_interval: float = 20.0

# Patron scene
const PATRON_SCENE = preload("res://scenes/npcs/RealisticPatron.tscn")

# Entrance and table positions
var entrance_position = Vector3(8.7, 0.0, 3.3)


var table_positions = [
	Vector3(-3.847, 0.0, -0.915),   # Table 1 - adjust these!
	Vector3(-2.1, 0.0, -2.5),   # Table 2
	Vector3(-2.715, 0.0, -3.5),   # Table 3
	Vector3(-4.2, 0.0, -2.8),       # Table 4 - ADD MORE!
	Vector3(-1.5, 0.0, -1.2),
]

# Seats (Story 25.6): scene seats first (Marker3D nodes in group "patron_seat", e.g. the bar stools),
# then the table spots above as the fallback (the tables get seat markers in Story 25.26).
# Each seat: {"approach": Vector3 (nav target), "sit": Transform3D of the marker, or null at a table spot}.
# occupied_tables / table_index keep their names (saves store table_index) but index this list.
var seats: Array = []

# State tracking
var active_patrons: Array = []
var occupied_tables: Dictionary = {}  # table_index: patron
var spawn_timer: Timer

# --- Eavesdropping (Story 8.5) ---
var eavesdrop_timer: Timer
var _eavesdropped_today: Dictionary = {}   # group key -> true (reset daily)
var _rumours: Array = []

func _ready():
	print("PatronSpawner initializing...")
	seats = build_seats([], table_positions)  # until the scene's seats are collected below

	# Set up spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.one_shot = false
	add_child(spawn_timer)

	# Eavesdropping (Story 8.5): periodically check if the player is loitering near a group
	# of drinking patrons; if so, let them overhear a rumour.
	_load_rumours()
	eavesdrop_timer = Timer.new()
	eavesdrop_timer.wait_time = 1.0
	eavesdrop_timer.one_shot = false
	eavesdrop_timer.timeout.connect(_check_eavesdrop)
	add_child(eavesdrop_timer)
	eavesdrop_timer.start()
	if GameManager.has_signal("day_changed"):
		GameManager.day_changed.connect(func(_d): _eavesdropped_today.clear())
	
	# Wait for scene to be ready
	await get_tree().create_timer(2.0).timeout
	_collect_seats()

	print("Spawning system ready")
	spawn_timer.start()

	# Restore patrons from a loaded save if there are any; otherwise spawn a fresh first patron.
	var saved: Array = GameManager.consume_restored_patrons() if GameManager.has_method("consume_restored_patrons") else []
	if saved.size() > 0:
		restore_patrons(saved)
	elif can_spawn_patron():
		spawn_patron()

func _on_spawn_timer_timeout():
	"""Try to spawn a patron on timer"""
	if can_spawn_patron():
		spawn_patron()

func can_spawn_patron() -> bool:
	"""Check if we can spawn a new patron"""
	if active_patrons.size() >= max_patrons:
		print("Max patrons reached (", active_patrons.size(), "/", max_patrons, ")")
		return false
	
	if get_available_table() == -1:
		print("No available tables")
		return false
	
	if GameManager.get_beer() <= 0:
		print("Out of beer!")
		return false
	
	return true

## How far behind a seat's sit root (away from what the seat faces) the patron is sent: the root of a
## bar stool lies inside the counter's navmesh margin, so the nav target is out where the mesh is and
## the sit-down slide covers the rest (review 2026-10-03).
const SEAT_APPROACH_BACK := 0.3

## Seats from scene markers first, then each fallback spot unless it is within 0.8 m of a scene seat.
## With no scene seats this is exactly the old table list.
static func build_seats(seat_transforms: Array, fallback_positions: Array) -> Array:
	var out := []
	for t in seat_transforms:
		var f: Vector3 = (t as Transform3D).basis.z
		f.y = 0.0
		var app: Vector3 = RealisticPatron.seat_root(t) - f.normalized() * SEAT_APPROACH_BACK
		out.append({"approach": app, "sit": t})
	for p in fallback_positions:
		var near := false
		for s in out:
			var r: Vector3 = RealisticPatron.seat_root(s.sit) if s.sit != null else s.approach
			if s.sit != null and Vector2(r.x - p.x, r.z - p.z).length() < 0.8:
				near = true
				break
		if not near:
			out.append({"approach": p, "sit": null})
	return out

func _collect_seats() -> void:
	var marks := []
	for n in get_tree().get_nodes_in_group("patron_seat"):
		if n is Node3D and (n as Node3D).is_inside_tree():
			marks.append((n as Node3D).global_transform)
	seats = build_seats(marks, table_positions)
	print("PatronSpawner: %d seats (%d from the scene, %d table spots)" % [seats.size(), marks.size(), seats.size() - marks.size()])

# Story 25.31 (AC 12; re-measured in the code review, P3): the widest seated half-width (Sit_Chair_Idle, every frame,
# the skinned body plus the props the game shows) over the whole realistic patron pool (the six townsfolk and the six
# class bodies) is the Mage's 0.449 m (the townsfolk's widest 0.436, the traveller's pack). At 1.17 two neighbours keep
# 1.17 - 2 x 0.449 = 0.27 m between them (0.30 between townsfolk), and the round bar's adjacent stools (sit roots
# 1.23 m apart) stay usable; KayKit's wide bodies needed 1.6.
const SEAT_ELBOW_ROOM := 1.17

## A free seat picked at random (roll in 0..1), preferring seats with elbow room from every
## occupied one; only when the hall is that full does anyone take a seat next to someone.
## Elbow room is kept between seat markers (the stools, measured at their sit roots) only: the
## table spots share a table, so they never crowd each other or push patrons to the bar.
static func pick_seat(seat_list: Array, occupied: Array, roll: float) -> int:
	var free := []
	var roomy := []
	for i in seat_list.size():
		if i in occupied:
			continue
		free.append(i)
		var crowded := false
		for j in occupied:
			if j >= 0 and j < seat_list.size() and seat_list[i].sit != null and seat_list[j].sit != null \
					and RealisticPatron.seat_root(seat_list[i].sit).distance_to(RealisticPatron.seat_root(seat_list[j].sit)) < SEAT_ELBOW_ROOM:
				crowded = true
				break
		if not crowded:
			roomy.append(i)
	var pool := roomy if not roomy.is_empty() else free
	if pool.is_empty():
		return -1
	return pool[mini(int(roll * pool.size()), pool.size() - 1)]

func get_available_table() -> int:
	"""Pick a random free seat, keeping elbow room when the hall allows it"""
	return pick_seat(seats, occupied_tables.keys(), randf())

func spawn_patron():
	"""Spawn a patron with walking behavior"""
	var table_index = get_available_table()
	if table_index == -1:
		print("No table available")
		return
	
	# Create patron
	var patron = PATRON_SCENE.instantiate()
	add_child(patron)
	
	# Position at entrance
	patron.global_position = entrance_position
	
	# Give patron their target seat (a stool's marker, or a table spot with no marker)
	var seat: Dictionary = seats[table_index]
	patron.setup_for_table(
		seat.approach,
		entrance_position,
		table_index,
		seat.sit
	)
	
	# Connect signals
	patron.patron_finished.connect(_on_patron_finished)
	patron.wants_to_be_served.connect(_on_patron_wants_service)
	
	# Track patron and table
	active_patrons.append(patron)
	occupied_tables[table_index] = patron
	
	print("🆕 Spawned patron '", patron.patron_name, "' → Table ", table_index)
	print("Active: ", active_patrons.size(), "/", max_patrons, " | Seats: ", occupied_tables.size(), "/", seats.size())

func restore_patrons(saved: Array) -> void:
	"""Rebuild patrons from save data at their exact positions/state (exact restore on load)."""
	for s in saved:
		var idx: int = int(s.get("table_index", -1))
		if idx < 0 or idx >= seats.size() or occupied_tables.has(idx):
			idx = get_available_table()
		var patron = PATRON_SCENE.instantiate()
		add_child(patron)  # _ready runs (random model); restore_from_save overrides it below
		var table_pos = seats[idx].approach if idx >= 0 else entrance_position
		patron.restore_from_save(s, table_pos, entrance_position, idx, seats[idx].sit if idx >= 0 else null)
		patron.patron_finished.connect(_on_patron_finished)
		patron.wants_to_be_served.connect(_on_patron_wants_service)
		active_patrons.append(patron)
		if idx >= 0:
			occupied_tables[idx] = patron
	print("Restored ", active_patrons.size(), " patron(s) from save")

func _on_patron_finished(patron: RealisticPatron):
	"""Clean up when patron leaves"""
	
	# Remove from active list
	if patron in active_patrons:
		active_patrons.erase(patron)
	
	# Free their table
	for table_idx in occupied_tables.keys():
		if occupied_tables[table_idx] == patron:
			occupied_tables.erase(table_idx)
			print("Table ", table_idx, " is now available")
			break
	
	# Remove patron from scene
	patron.queue_free()
	
	print("Patron left. Active: ", active_patrons.size(), "/", max_patrons)
	
	# Try to spawn replacement
	if can_spawn_patron() and randf() < 0.7:
		await get_tree().create_timer(randf_range(5.0, 15.0)).timeout
		if can_spawn_patron():
			spawn_patron()

func _on_patron_wants_service(patron: RealisticPatron):
	"""Patron signals they want service"""
	print("", patron.patron_name, " wants service!")
	# You can add notification to player here later

# Debug helpers
func get_patron_count() -> int:
	return active_patrons.size()

func get_available_table_count() -> int:
	return seats.size() - occupied_tables.size()

func despawn_all_patrons():
	"""Remove all patrons immediately (called when player sleeps)"""
	print("Despawning all patrons for night...")
	
	# Store count for logging
	var patron_count = active_patrons.size()
	
	# Remove all patrons
	for patron in active_patrons.duplicate():  # Use duplicate to avoid modification during iteration
		# Free their table
		for table_idx in occupied_tables.keys():
			if occupied_tables[table_idx] == patron:
				occupied_tables.erase(table_idx)
				break
		
		# Remove from scene
		if is_instance_valid(patron):
			patron.queue_free()
	
	# Clear arrays
	active_patrons.clear()
	occupied_tables.clear()
	
	print("Despawned " + str(patron_count) + " patron(s) for the night")
	print("Active: 0/" + str(max_patrons) + " | Seats: 0/" + str(seats.size()))

# =============================================================================
# EAVESDROPPING (Story 8.5)
# =============================================================================

func _load_rumours() -> void:
	var f = FileAccess.open("res://data/dialogue/rumours.json", FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_rumours = parsed.get("lines", [])

func _check_eavesdrop() -> void:
	if not PlayerManager or not is_instance_valid(PlayerManager.player):
		return
	var ppos: Vector3 = PlayerManager.player.global_position
	var range_m: float = DataManager.get_config("eavesdrop_range", 3.5)

	# Collect DRINKING patrons (state 2) within earshot of the player.
	var near: Array = []
	for p in active_patrons:
		if is_instance_valid(p) and p.current_state == 2 and p.global_position.distance_to(ppos) <= range_m:
			near.append(p)
	if near.size() < 2:
		return  # need a group of 2+ (a lone patron mutters nothing worth hearing)

	# One rumour per group per day: key by the sorted set of their tables.
	var idxs: Array = []
	for p in near:
		idxs.append(int(p.table_index))
	idxs.sort()
	var key := str(idxs)
	if _eavesdropped_today.has(key):
		return
	_eavesdropped_today[key] = true
	_fire_rumour()

func _fire_rumour() -> void:
	var line := _pick_rumour_line()
	if line == "":
		return
	WorldManager.overheard_rumours.append(line)   # Latest News feed pool (Epic 6 patch point)
	WorldBus.settlement_event.emit({"type": "rumour", "text": line})
	NotificationManager.show_banner("Overheard: " + line)
	print("[Eavesdrop] Rumour overheard (Latest News patch point): ", line)
	_maybe_spawn_rumour_mission()

func _maybe_spawn_rumour_mission() -> void:
	# A rumour has a chance to become an actual contract on the World Map, not just flavor text.
	var chance: float = DataManager.get_config("rumour_mission_chance", 0.2)
	if randf() > chance:
		return
	var candidates: Array = DataManager.generate_daily_missions_with_tiers(1, GameManager.mission_tier_unlocked)
	if candidates.is_empty():
		return
	var mission: Dictionary = candidates[0]
	if not WorldManager.assign_one_mission(mission):
		return  # no free hex right now — the rumour stays just flavor this time
	var follow_up := "A new contract has appeared on the board, spurred by what you overheard."
	WorldManager.overheard_rumours.append(follow_up)
	NotificationManager.show_banner(follow_up)
	print("[Eavesdrop] Rumour spawned a mission: ", mission.get("name", "?"))

func _pick_rumour_line() -> String:
	if _rumours.is_empty():
		return ""
	var raw: String = str(_rumours[randi() % _rumours.size()])
	return raw.replace("{place}", _random_place()).replace("{faction}", _random_faction())

func _random_place() -> String:
	var biomes = WorldManager.faction_data.get("biomes", []) if WorldManager else []
	if biomes is Array and not biomes.is_empty():
		var b = biomes[randi() % biomes.size()]
		if b is Dictionary:
			return b.get("name", "the frontier")
	return "the frontier"

func _random_faction() -> String:
	var names = WorldManager.faction_data.get("rival_guild_names", []) if WorldManager else []
	if names is Array and not names.is_empty():
		return str(names[randi() % names.size()])
	return "a rival guild"
