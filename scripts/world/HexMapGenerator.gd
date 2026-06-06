extends Node3D
## HexMapGenerator.gd (Complete Seeded Procedural Blueprint)

@export var map_seed: int = 12345
@export var map_radius: int = 5  # Generates a large island (approx 91 tiles)

# Noise height thresholds (-1.0 to 1.0) to cluster biomes organics
@export_range(-1.0, 1.0) var threshold_sea: float = -0.35
@export_range(-1.0, 1.0) var threshold_coast: float = -0.15
@export_range(-1.0, 1.0) var threshold_grass: float = 0.3
@export_range(-1.0, 1.0) var threshold_forest: float = 0.65
# Anything above forest threshold automatically becomes "mountain"

# When true, renders WorldManager.world_map statically instead of generating a new world.
@export var display_mode: bool = false

# Signals for map interaction and timeline sequences
signal reveal_finished
signal tavern_hex_selected(record: Dictionary)

# ── Animation constants ───────────────────────────────────────────────────────
const LIFT_Y := 4.0
const SPIN_PERIOD := 0.5
const TOTAL_ROTATIONS := 3.25
const SETTLE_ROT_EXTRA := 0.75
const SETTLE_DURATION := 0.8

# ── Tile paths (Mountains & Grass are now default bases for toppers) ──────────
const GRASS_SCENE := "res://assets/environment/hexagons/base/hex_grass.gltf"
const WATER_SCENE := "res://assets/environment/hexagons/base/hex_water.gltf"

const RIVER_VARIANTS := [
	"res://assets/environment/hexagons/rivers/hex_river_B.gltf",
	"res://assets/environment/hexagons/rivers/hex_river_A_curvy.gltf",
	"res://assets/environment/hexagons/rivers/hex_river_F.gltf",
]
const COAST_VARIANTS := [
	"res://assets/environment/hexagons/coast/hex_coast_A.gltf",
	"res://assets/environment/hexagons/coast/hex_coast_B.gltf",
	"res://assets/environment/hexagons/coast/hex_coast_C.gltf",
]

const TOPPERS := {
	"forest": [
		"res://assets/environment/hexagons/nature/trees_A_large.gltf",
		"res://assets/environment/hexagons/nature/trees_A_medium.gltf",
		"res://assets/environment/hexagons/nature/hills_A_trees.gltf",
	],
	"mine": [
		"res://assets/environment/hexagons/blue/building_mine_blue.gltf",
	],
	"tavern_site": [
		"res://assets/environment/hexagons/blue/building_tavern_blue.gltf",
	],
	"mountain": [
		"res://assets/environment/hexagons/nature/mountain_A_grass_trees.gltf",
		"res://assets/environment/hexagons/nature/mountain_B.gltf",
	],
	"zone_location": [
		"res://assets/environment/hexagons/blue/building_mine_blue.gltf", 
	]
}

# The single global center coordinate in our dynamic system
const CENTER_COORD := Vector2i(0, 0)

# Runtime state tracking variables
var _records := []
var _grass_tiles: Array = []
var _biome_tiles: Array = []
var _active_tweens: Array = []
var _is_revealing: bool = false
var _noise := FastNoiseLite.new()

func _ready() -> void:
	_initialize_noise()
	if display_mode:
		display_stored_world()
	else:
		generate_and_reveal()

func _initialize_noise() -> void:
	_noise.seed = map_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.15 # Higher values = chaotic maps, Lower = smooth landmasses

# ── Public Entry Point ────────────────────────────────────────────────────────

func generate_and_reveal() -> void:
	if _is_revealing:
		print("[HexMapGenerator] Reveal already in progress — ignoring regenerate.")
		return

	_clear_map()
	
	_records = _build_seeded_records()
	print("[HexMapGenerator] Generated seeded layout:")
	for rec in _records:
		if rec.is_zone:
			print("  ZONE: %-8s  coord=%s  biome=%s  name=%s" % [rec.id, str(rec.coord), rec.biome, rec.location_name])
	
	_run_reveal()

# ── Teardown ──────────────────────────────────────────────────────────────────

func _clear_map() -> void:
	for tw in _active_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_active_tweens.clear()

	for gt in _grass_tiles:
		if is_instance_valid(gt):
			gt.queue_free()
	_grass_tiles.clear()

	for bt in _biome_tiles:
		if is_instance_valid(bt):
			bt.queue_free()
	_biome_tiles.clear()

	_records.clear()

# ── Reveal Coroutine Loop ─────────────────────────────────────────────────────

func _run_reveal() -> void:
	_is_revealing = true
	_spawn_all_tiles()

	# ── Phase: spin ──
	var hold: float = TOTAL_ROTATIONS * SPIN_PERIOD
	for gt in _grass_tiles:
		var tween := create_tween()
		_active_tweens.append(tween)
		tween.tween_property(gt, "rotation:x", TOTAL_ROTATIONS * TAU, hold) \
			 .from(0.0).set_trans(Tween.TRANS_LINEAR)

	await get_tree().create_timer(hold).timeout

	if _grass_tiles.is_empty():
		_is_revealing = false
		return

	# ── Phase: swap ──
	var swap_rot: float = TOTAL_ROTATIONS * TAU
	for i in _records.size():
		var bt: Node3D = _biome_tiles[i]
		if bt == null:
			continue
		bt.rotation.x = swap_rot
		_grass_tiles[i].visible = false
		bt.visible = true

	for gt in _grass_tiles:
		if is_instance_valid(gt):
			gt.queue_free()
	_grass_tiles.clear()

	# ── Phase: settle ──
	var final_rot: float = (TOTAL_ROTATIONS + SETTLE_ROT_EXTRA) * TAU
	for bt in _biome_tiles:
		if bt == null:
			continue
		var tween := create_tween()
		_active_tweens.append(tween)
		tween.set_parallel(true)
		tween.tween_property(bt, "rotation:x", final_rot, SETTLE_ROT_EXTRA * SPIN_PERIOD) \
			 .from(swap_rot).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(bt, "position:y", 0.0, SETTLE_DURATION) \
			 .from(LIFT_Y).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(SETTLE_DURATION).timeout
	_is_revealing = false
	reveal_finished.emit()

# ── Dynamic Tile Spawner ──────────────────────────────────────────────────────

func _spawn_all_tiles() -> void:
	for i in _records.size():
		var rec: Dictionary = _records[i]
		var base_pos := HexGrid.offset_to_world(rec.coord.x, rec.coord.y)
		base_pos.y = LIFT_Y

		# Grass placeholder (spin phase)
		var grass_packed: PackedScene = load(GRASS_SCENE)
		var gt := grass_packed.instantiate() as Node3D
		gt.name = rec.id + "_grass"
		gt.position = base_pos
		add_child(gt)
		_grass_tiles.append(gt)

		# Render Base Mesh Map
		var biome_path := _base_path_for(rec.biome)
		var biome_packed: PackedScene = load(biome_path)
		if biome_packed == null:
			push_error("[HexMapGenerator] Failed to load biome: " + biome_path)
			_biome_tiles.append(null)
			continue
			
		var bt := biome_packed.instantiate() as Node3D
		bt.name = rec.id
		bt.position = base_pos
		bt.visible = false
		
		# ── Align coastlines to face the ocean ──
		if rec.biome == "coast":
			_align_coast_tile(bt, rec)
		
		# Generate Natural Biome Toppers (Trees, Mountains)
		for tp in _topper_paths_for(rec.biome):
			var tp_packed: PackedScene = load(tp)
			if tp_packed != null:
				bt.add_child(tp_packed.instantiate() as Node3D)
				
		# Generate Interactivity Zone Topper (The 10 Towns)
		if rec.is_zone:
			var zone_variants: Array = TOPPERS["zone_location"]
			var zone_packed: PackedScene = load(zone_variants[0])
			if zone_packed != null:
				bt.add_child(zone_packed.instantiate() as Node3D)

		add_child(bt)
		_biome_tiles.append(bt)

		# Interaction Wiring
		if rec.is_center or rec.is_zone:
			_make_tile_clickable(bt, rec)

func _align_coast_tile(tile_mesh: Node3D, current_rec: Dictionary) -> void:
	var current_pos := HexGrid.offset_to_world(current_rec.coord.x, current_rec.coord.y)
	var closest_sea_pos := Vector3.ZERO
	var min_distance: float = 99999.0
	var found_water: bool = false
	
	# Look through all generated tiles to find the closest ocean neighbor
	for rec in _records:
		if rec.biome == "sea":
			var sea_pos := HexGrid.offset_to_world(rec.coord.x, rec.coord.y)
			var dist: float = current_pos.distance_to(sea_pos)
			if dist < min_distance:
				min_distance = dist
				closest_sea_pos = sea_pos
				found_water = true
				
	if found_water:
		# Calculate the directional vector on the flat ground plane (X, Z)
		var dir_to_water := (closest_sea_pos - current_pos).normalized()
		var angle: float = atan2(-dir_to_water.z, dir_to_water.x)
		
		# Snap the angle cleanly to the nearest 60 degrees (Hex orientation step)
		var hex_angle_step: float = deg_to_rad(60.0)
		var snapped_angle: float = round(angle / hex_angle_step) * hex_angle_step
		
		# Adjust this offset constant if KayKit's assets face backward by default
		const MESH_DIRECTION_OFFSET: float = 0.0 
		
		tile_mesh.rotation.y = snapped_angle + deg_to_rad(MESH_DIRECTION_OFFSET)

# ── Interactive Click Volumes ─────────────────────────────────────────────────

func _add_hover_area(tile: Node3D, rec: Dictionary) -> void:
	var area := Area3D.new()
	area.name = "HoverArea"
	area.set_meta("hex_id", rec["id"])
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = 1.0
	col.shape = shape
	area.add_child(col)
	tile.add_child(area)

func _make_tile_clickable(tile: Node3D, rec: Dictionary) -> void:
	var area := Area3D.new()
	area.name = "ClickArea"
	area.input_ray_pickable = true

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = 1.0
	col.shape = shape
	area.add_child(col)
	tile.add_child(area)

	area.input_event.connect(_on_tile_input_event.bind(rec))

func _on_tile_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int, rec: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if rec.is_center:
			print("[HexMapGenerator] Tavern hex clicked: ", rec.id)
			tavern_hex_selected.emit(rec)
		elif rec.is_zone:
			print("[HexMapGenerator] Zone settlement clicked: ", rec.location_name, " at ", rec.coord)

func get_records() -> Array:
	return _records

# ── Static Display Mode (Board Overlay Loading) ───────────────────────────────

func display_stored_world() -> void:
	var stored: Array = WorldManager.world_map
	if stored.is_empty():
		push_warning("[HexMapGenerator] display_mode: WorldManager.world_map is empty — nothing to render.")
		return
	_records = stored.duplicate(true)
	_spawn_tiles_static()

func _spawn_tiles_static() -> void:
	for rec in _records:
		var base_pos := HexGrid.offset_to_world(rec.coord.x, rec.coord.y)
		base_pos.y = 0.0

		var biome_path := _base_path_for(rec.biome)
		var biome_packed: PackedScene = load(biome_path)
		if biome_packed == null:
			push_error("[HexMapGenerator] Failed to load biome: " + biome_path)
			_biome_tiles.append(null)
			continue
		var bt := biome_packed.instantiate() as Node3D
		bt.name = rec.id
		bt.position = base_pos
		bt.visible = true
		
		# Align coastlines in static mode too
		if rec.biome == "coast":
			_align_coast_tile(bt, rec)
		
		# Base topper population
		for tp in _topper_paths_for(rec.biome):
			var tp_packed: PackedScene = load(tp)
			if tp_packed != null:
				bt.add_child(tp_packed.instantiate() as Node3D)
				
		# Re-render persistent zones
		if rec.get("is_zone", false):
			var zone_variants: Array = TOPPERS["zone_location"]
			var zone_packed: PackedScene = load(zone_variants[0])
			if zone_packed != null:
				bt.add_child(zone_packed.instantiate() as Node3D)
				
		add_child(bt)
		_biome_tiles.append(bt)
		_add_hover_area(bt, rec)

# ── Procedural Mathematics Builder ────────────────────────────────────────────

func _build_seeded_records() -> Array:
	var temp_records := []
	var land_hex_records := []
	var hex_index := 0
	
	# Programmatic generation of all coordinate layouts inside a grid radius
	for r in range(-map_radius, map_radius + 1):
		for q in range(-map_radius, map_radius + 1):
			# Math calculation converting spatial axial grids to odd-row offsets
			var col := q + (r - (r & 1)) / 2
			var row := r
			
			# Trim corners to achieve a clean hexagonal radial bounds outline
			if abs(q) + abs(r) + abs(-q-r) > map_radius * 2:
				continue
				
			var coord := Vector2i(col, row)
			var is_center := (coord == CENTER_COORD)
			var biome := "grass"
			
			if is_center:
				biome = "tavern_site"
			else:
				# Sample the noise system based on engine 3D world space vector calculations
				var world_pos := HexGrid.offset_to_world(coord.x, coord.y)
				var noise_val := _noise.get_noise_2d(world_pos.x, world_pos.z)
				var fractal_factor := _sample_mandelbrot(world_pos.x, world_pos.z) # 0.0 to 1.0
				
				#var noise_val := simplex_noise * fractal_factor # hmm ? 
				
				
				# Threshold stacking step logic
				if noise_val < threshold_sea:
					biome = "sea"
				elif noise_val < threshold_coast:
					biome = "coast"
				elif noise_val < threshold_grass:
					biome = "grass"
				elif noise_val < threshold_forest:
					biome = "forest"
				else:
					biome = "mountain"
			
			var rec := {
				"id": "hex_%d" % hex_index,
				"coord": coord,
				"biome": biome,
				"is_center": is_center,
				"is_zone": false,
				"location_name": "",
				"active_mission": null
			}
			
			temp_records.append(rec)
			
			# Validating viable terra-firma surface candidates for zone placements
			if not is_center and biome != "sea" and biome != "coast":
				land_hex_records.append(rec)
				
			hex_index += 1

	# Isolate pseudo-random parameters strictly inside our saving seed limits
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	
	var target_zone_count := mini(10, land_hex_records.size())
	for i in range(target_zone_count):
		var pick_idx := rng.randi() % land_hex_records.size()
		var chosen_rec: Dictionary = land_hex_records[pick_idx]
		
		chosen_rec["is_zone"] = true
		chosen_rec["location_name"] = "Settlement %d" % (i + 1)
		
		land_hex_records.remove_at(pick_idx)

	return temp_records

func _apply_fibonacci_settlements(temp_records: Array) -> void:
	var golden_angle: float = deg_to_rad(137.507764)
	var spiral_spacing: float = 1.8 # Controls how tight or spread out the spiral is
	var settlements_placed: int = 0
	var target_count := 10
	
	# Start iterating outward along the mathematical spiral indices
	# Skipping index 0 because that's our central tavern!
	for i in range(1, 200): 
		if settlements_placed >= target_count:
			break
			
		# Fermat's Spiral math using the Golden Angle
		var radius: float = spiral_spacing * sqrt(i)
		var theta: float = i * golden_angle
		
		# Convert polar coordinates to a flat 3D world space coordinate (X, Z)
		var target_world_pos := Vector3(
			radius * cos(theta),
			0.0,
			radius * sin(theta)
		)
		
		# Find the closest record in our map that matches this spot
		var best_rec: Dictionary = {}
		var min_dist: float = 99999.0
		
		for rec in temp_records:
			# Skip tiles that are water, coast, or already a zone/center
			if rec.biome == "sea" or rec.biome == "coast" or rec.is_center or rec.is_zone:
				continue
				
			var tile_pos := HexGrid.offset_to_world(rec.coord.x, rec.coord.y)
			var d: float = tile_pos.distance_to(target_world_pos)
			if d < min_dist:
				min_dist = d
				best_rec = rec
				
		# If we found a matching land tile nearby, snap the settlement to it!
		if not best_rec.is_empty() and min_dist < 2.5:
			settlements_placed += 1
			best_rec["is_zone"] = true
			# We can name it based on its sequential index in the Fibonacci spiral!
			best_rec["location_name"] = "Settlement %d" % settlements_placed



# Returns a value between 0.0 (inside the set) and 1.0 (escaped quickly)
func _sample_mandelbrot(world_x: float, world_z: float) -> float:
	# 1. Map your game world coordinates down to the Mandelbrot view window
	# The fractal lives tightly between Real (-2.0 to 0.5) and Imaginary (-1.25 to 1.25)
	var scale := 0.15 # Controls how "zoomed in" the fractal shape is
	var offset_x := -0.7 # Centers the island on a cool part of the fractal
	var offset_z := 0.0
	
	var cx: float = (world_x * scale) + offset_x
	var cz: float = (world_z * scale) + offset_z
	
	var x: float = 0.0
	var y: float = 0.0
	var iteration: int = 0
	var max_iterations: int = 32 # Higher = sharper fractal edges, more expensive
	
	# 2. Run the escape-time loop
	while (x*x + y*y <= 4.0) and (iteration < max_iterations):
		var xtemp: float = x*x - y*y + cx
		y = 2.0 * x * y + cz
		x = xtemp
		iteration += 1
		
	# Normalize to a 0.0 - 1.0 float
	return float(iteration) / float(max_iterations)



# ── Dynamic Fallback Visual Resolvers ──────────────────────────────────────────

func _base_path_for(biome: String) -> String:
	match biome:
		"coast": return COAST_VARIANTS[randi() % COAST_VARIANTS.size()]
		"sea":   return WATER_SCENE
		_:       return GRASS_SCENE # Forests, Mountains, Mines, and Zones sit above grass!

func _topper_paths_for(biome: String) -> Array:
	if biome not in TOPPERS:
		return []
	var options: Array = TOPPERS[biome]
	return [options[randi() % options.size()]]
