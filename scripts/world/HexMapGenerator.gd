extends Node3D
## HexMapGenerator.gd — Island generator: simplex noise + radial falloff.
##
## Design rules honored here:
##  - Generated ONCE per new game. Every visual choice (which mesh variant,
##    which rotation) is resolved at generation time and STORED in the record.
##    display_mode re-instantiates exactly what the record says — zero RNG.
##  - One seeded RNG (_rng) drives everything. Same seed = same world.
##  - Regenerate rolls a fresh seed (toggleable in Inspector).

# ── Tuning (Inspector) ────────────────────────────────────────────────────────
@export var map_radius: int = 20                    # 6 → 127 hexes, 7 → 169
@export var randomize_seed_on_generate: bool = true
@export var map_seed: int = 12345                  # used when randomize is off

# Elevation thresholds on 0..1 AFTER falloff is applied.
# (Renamed from threshold_* on purpose — stale Inspector overrides of the old
#  names can't silently fight the new math.)
@export_range(0.0, 1.0) var sea_level: float = 0.10
@export_range(0.0, 1.0) var forest_level: float = 0.50
@export_range(0.0, 1.0) var mountain_level: float = 0.75
@export_range(0.0, 4.0) var falloff_strength: float = 2.2
@export_range(0.01, 1.0) var noise_frequency: float = 0.3

@export var settlement_count: int = 10
@export var settlement_min_spacing: int = 2        # hex distance between zones

# Chance of a small decorative prop on otherwise-plain tiles.
@export_range(0.0, 1.0) var grass_decor_chance: float = 0.5
@export_range(0.0, 1.0) var sea_decor_chance: float = 0.5

# Rotate this if KayKit coast meshes face the wrong way (degrees).
@export var coast_mesh_offset_deg: float = 0.1

# When true, renders WorldManager.world_map statically instead of generating.
@export var display_mode: bool = false

# ── Signals ───────────────────────────────────────────────────────────────────
signal reveal_finished
signal tavern_hex_selected(record: Dictionary)

# ── Animation constants ───────────────────────────────────────────────────────
const LIFT_Y := 4.0
const SPIN_PERIOD := 0.5
const TOTAL_ROTATIONS := 3.25
const SETTLE_ROT_EXTRA := 0.75
const SETTLE_DURATION := 0.8

# ── Asset paths ───────────────────────────────────────────────────────────────
const GRASS_SCENE := "res://assets/environment/hexagons/base/hex_grass.gltf"
const WATER_SCENE := "res://assets/environment/hexagons/base/hex_water.gltf"

const COAST_VARIANTS := [
	"res://assets/environment/hexagons/coast/hex_coast_A.gltf",
	"res://assets/environment/hexagons/coast/hex_coast_B.gltf",
	"res://assets/environment/hexagons/coast/hex_coast_C.gltf",
	"res://assets/environment/hexagons/coast/hex_coast_D.gltf",
	"res://assets/environment/hexagons/coast/hex_coast_E.gltf",
]

const FOREST_TOPPERS := [
	"res://assets/environment/hexagons/nature/trees_A_large.gltf",
	"res://assets/environment/hexagons/nature/trees_A_medium.gltf",
	"res://assets/environment/hexagons/nature/trees_B_large.gltf",
	"res://assets/environment/hexagons/nature/trees_B_medium.gltf",
	"res://assets/environment/hexagons/nature/hills_A_trees.gltf",
	"res://assets/environment/hexagons/nature/hills_B_trees.gltf",
	"res://assets/environment/hexagons/nature/hills_C_trees.gltf",
]

const MOUNTAIN_TOPPERS := [
	"res://assets/environment/hexagons/nature/mountain_A_grass.gltf",
	"res://assets/environment/hexagons/nature/mountain_A_grass_trees.gltf",
	"res://assets/environment/hexagons/nature/mountain_B_grass.gltf",
	"res://assets/environment/hexagons/nature/mountain_B_grass_trees.gltf",
	"res://assets/environment/hexagons/nature/mountain_C_grass.gltf",
	"res://assets/environment/hexagons/nature/mountain_C_grass_trees.gltf",
]

const GRASS_DECOR := [
	"res://assets/environment/hexagons/nature/rock_single_A.gltf",
	"res://assets/environment/hexagons/nature/rock_single_B.gltf",
	"res://assets/environment/hexagons/nature/rock_single_C.gltf",
	"res://assets/environment/hexagons/nature/tree_single_A.gltf",
	"res://assets/environment/hexagons/nature/tree_single_B.gltf",
	"res://assets/environment/hexagons/nature/trees_A_small.gltf",
	"res://assets/environment/hexagons/nature/trees_B_small.gltf",
	"res://assets/environment/hexagons/nature/hill_single_A.gltf",
	"res://assets/environment/hexagons/nature/hill_single_B.gltf",
]

const SEA_DECOR := [
	"res://assets/environment/hexagons/nature/waterlily_A.gltf",
	"res://assets/environment/hexagons/nature/waterlily_B.gltf",
	"res://assets/environment/hexagons/nature/waterplant_A.gltf",
	"res://assets/environment/hexagons/nature/waterplant_B.gltf",
	"res://assets/environment/hexagons/nature/waterplant_C.gltf",
]

const TAVERN_TOPPER := "res://assets/environment/hexagons/blue/building_tavern_blue.gltf"

# Each settlement gets a distinct building — shuffled per seed.
const ZONE_BUILDINGS := [
	"res://assets/environment/hexagons/blue/building_castle_blue.gltf",
	"res://assets/environment/hexagons/blue/building_church_blue.gltf",
	"res://assets/environment/hexagons/blue/building_market_blue.gltf",
	"res://assets/environment/hexagons/blue/building_windmill_blue.gltf",
	"res://assets/environment/hexagons/blue/building_lumbermill_blue.gltf",
	"res://assets/environment/hexagons/blue/building_barracks_blue.gltf",
	"res://assets/environment/hexagons/blue/building_watermill_blue.gltf",
	"res://assets/environment/hexagons/blue/building_mine_blue.gltf",
	"res://assets/environment/hexagons/blue/building_home_A_blue.gltf",
	"res://assets/environment/hexagons/blue/building_blacksmith_blue.gltf",
]

const CENTER_COORD := Vector2i(0, 0)

# Odd-r offset neighbor deltas (matches HexGrid: odd rows shifted +X).
const NEIGHBORS_EVEN := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1),
	Vector2i(-1, -1), Vector2i(0, 1), Vector2i(-1, 1),
]
const NEIGHBORS_ODD := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, -1),
	Vector2i(0, -1), Vector2i(1, 1), Vector2i(0, 1),
]

# ── Runtime state ─────────────────────────────────────────────────────────────
var _records := []
var _grass_tiles: Array = []
var _biome_tiles: Array = []
var _active_tweens: Array = []
var _is_revealing: bool = false
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _scene_cache := {}   # path -> PackedScene; gltf loads are not free


func _ready() -> void:
	if display_mode:
		display_stored_world()
	else:
		generate_and_reveal()


# ── Public entry point ────────────────────────────────────────────────────────

func generate_and_reveal() -> void:
	if _is_revealing:
		print("[HexMapGenerator] Reveal already in progress — ignoring regenerate.")
		return

	if randomize_seed_on_generate:
		map_seed = randi()
	_rng.seed = map_seed
	_noise.seed = map_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = noise_frequency
	print("[HexMapGenerator] Generating world with seed: ", map_seed)

	_clear_map()
	_records = _build_records()
	_resolve_visuals()

	for rec in _records:
		if rec.is_zone:
			print("  ZONE: %-8s coord=%s biome=%s name=%s" %
				[rec.id, str(rec.coord), rec.biome, rec.location_name])

	_run_reveal()


# ── World building ────────────────────────────────────────────────────────────

func _build_records() -> Array:
	var recs := []
	var by_coord := {}   # Vector2i -> record, for adjacency passes

	# Pass 1: elevation -> base biome
	var hex_index := 0
	for r in range(-map_radius, map_radius + 1):
		for q in range(-map_radius, map_radius + 1):
			if abs(q) + abs(r) + abs(-q - r) > map_radius * 2:
				continue
			var col := q + (r - (r & 1)) / 2
			var coord := Vector2i(col, r)
			var is_center := (coord == CENTER_COORD)

			var biome: String
			if is_center:
				biome = "tavern_site"
			else:
				var dist := _hex_distance(coord, CENTER_COORD)
				var dist_norm := float(dist) / float(map_radius)
				var world_pos := HexGrid.offset_to_world(coord.x, coord.y)
				# 0..1 elevation, sunk toward the edges -> island silhouette
				var elevation := (_noise.get_noise_2d(world_pos.x, world_pos.z) + 1.0) * 0.5
				elevation -= pow(dist_norm, 3.0) * falloff_strength

				if dist >= map_radius:
					biome = "sea"   # hard guarantee: water frames the island
				elif elevation < sea_level:
					biome = "sea"
				elif elevation < forest_level:
					biome = "grass"
				elif elevation < mountain_level:
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
				"active_mission": null,
				"base_path": "",
				"base_rot_y": 0.0,
				"topper_paths": [],
			}
			recs.append(rec)
			by_coord[coord] = rec
			hex_index += 1

	# Pass 2: coast = GRASS adjacent to sea. Forests and mountains that touch
	# water stay as they are (reads as cliffs); beaches only on open grass.
	for rec in recs:
		if rec.biome != "grass":
			continue
		if not _sea_neighbors_of(rec, by_coord).is_empty():
			rec.biome = "coast"

	# Pass 3: settlements on land, spaced apart
	_place_settlements(recs)

	# Pass 4: coast rotation toward actual adjacent water
	for rec in recs:
		if rec.biome == "coast":
			rec.base_rot_y = _coast_rotation(rec, by_coord)

	return recs


func _place_settlements(recs: Array) -> void:
	var candidates := []
	for rec in recs:
		if rec.is_center or rec.biome == "sea" or rec.biome == "coast":
			continue
		if _hex_distance(rec.coord, CENTER_COORD) < settlement_min_spacing:
			continue
		candidates.append(rec)

	var buildings := ZONE_BUILDINGS.duplicate()
	# Fisher-Yates with the seeded RNG (Array.shuffle() uses the global RNG)
	for i in range(buildings.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = buildings[i]
		buildings[i] = buildings[j]
		buildings[j] = tmp

	var placed := []
	var spacing := settlement_min_spacing
	while placed.size() < settlement_count and spacing >= 0:
		var pool := candidates.duplicate()
		while not pool.is_empty() and placed.size() < settlement_count:
			var idx := _rng.randi_range(0, pool.size() - 1)
			var pick: Dictionary = pool[idx]
			pool.remove_at(idx)
			if pick.is_zone:
				continue
			var ok := true
			for z in placed:
				if _hex_distance(pick.coord, z.coord) < spacing:
					ok = false
					break
			if ok:
				pick.is_zone = true
				pick.location_name = "Settlement %d" % (placed.size() + 1)
				pick["zone_building"] = buildings[placed.size() % buildings.size()]
				placed.append(pick)
		# Couldn't fit them all at this spacing — relax and try again.
		spacing -= 1

	if placed.size() < settlement_count:
		push_warning("[HexMapGenerator] Only placed %d/%d settlements." %
			[placed.size(), settlement_count])


# ── Visual resolution (all RNG happens HERE, results stored in records) ──────

func _resolve_visuals() -> void:
	for rec in _records:
		match rec.biome:
			"sea":
				rec.base_path = WATER_SCENE
				if _rng.randf() < sea_decor_chance:
					rec.topper_paths.append(SEA_DECOR[_rng.randi_range(0, SEA_DECOR.size() - 1)])
			"coast":
				rec.base_path = COAST_VARIANTS[_rng.randi_range(0, COAST_VARIANTS.size() - 1)]
			"forest":
				rec.base_path = GRASS_SCENE
				rec.topper_paths.append(FOREST_TOPPERS[_rng.randi_range(0, FOREST_TOPPERS.size() - 1)])
			"mountain":
				rec.base_path = GRASS_SCENE
				rec.topper_paths.append(MOUNTAIN_TOPPERS[_rng.randi_range(0, MOUNTAIN_TOPPERS.size() - 1)])
			"tavern_site":
				rec.base_path = GRASS_SCENE
				rec.topper_paths.append(TAVERN_TOPPER)
			_:  # plain grass
				rec.base_path = GRASS_SCENE
				if _rng.randf() < grass_decor_chance:
					rec.topper_paths.append(GRASS_DECOR[_rng.randi_range(0, GRASS_DECOR.size() - 1)])

		# Settlement building replaces nature toppers on its hex (no more
		# mine-glued-to-mountain collisions).
		if rec.is_zone:
			rec.topper_paths = [rec.get("zone_building", ZONE_BUILDINGS[0])]


# ── Hex math helpers ──────────────────────────────────────────────────────────

func _offset_to_axial(c: Vector2i) -> Vector2i:
	return Vector2i(c.x - (c.y - (c.y & 1)) / 2, c.y)


func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var aa := _offset_to_axial(a)
	var bb := _offset_to_axial(b)
	var dq := aa.x - bb.x
	var dr := aa.y - bb.y
	return (abs(dq) + abs(dr) + abs(dq + dr)) / 2


func _neighbors_of(coord: Vector2i) -> Array:
	var deltas: Array = NEIGHBORS_ODD if (coord.y & 1) == 1 else NEIGHBORS_EVEN
	var result := []
	for d in deltas:
		result.append(coord + d)
	return result


func _sea_neighbors_of(rec: Dictionary, by_coord: Dictionary) -> Array:
	var seas := []
	for n in _neighbors_of(rec.coord):
		if by_coord.has(n) and by_coord[n].biome == "sea":
			seas.append(by_coord[n])
	return seas


func _coast_rotation(rec: Dictionary, by_coord: Dictionary) -> float:
	var seas := _sea_neighbors_of(rec, by_coord)
	if seas.is_empty():
		return 0.0
	var here := HexGrid.offset_to_world(rec.coord.x, rec.coord.y)
	var dir := Vector3.ZERO
	for s in seas:
		var sp := HexGrid.offset_to_world(s.coord.x, s.coord.y)
		dir += (sp - here).normalized()
	if dir.length() < 0.01:
		# Water on opposite sides cancels out — just face the first one.
		var sp0 := HexGrid.offset_to_world(seas[0].coord.x, seas[0].coord.y)
		dir = (sp0 - here).normalized()
	dir = dir.normalized()
	var angle := atan2(-dir.z, dir.x)
	var step := deg_to_rad(60.0)
	return snappedf(angle, step) + deg_to_rad(coast_mesh_offset_deg)


# ── Scene cache ───────────────────────────────────────────────────────────────

func _load_scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]


# ── Tile instantiation (shared by reveal + static modes) ──────────────────────

func _instantiate_tile(rec: Dictionary) -> Node3D:
	var packed := _load_scene(rec.base_path)
	if packed == null:
		push_error("[HexMapGenerator] Failed to load: " + rec.base_path)
		return null
	var bt := packed.instantiate() as Node3D
	bt.name = rec.id
	bt.rotation.y = rec.get("base_rot_y", 0.0)
	for tp in rec.topper_paths:
		var tp_packed := _load_scene(tp)
		if tp_packed != null:
			bt.add_child(tp_packed.instantiate() as Node3D)
	return bt


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


# ── Reveal coroutine ──────────────────────────────────────────────────────────

func _run_reveal() -> void:
	_is_revealing = true
	_spawn_all_tiles()

	# Phase: spin
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

	# Phase: swap
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

	# Phase: settle
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


func _spawn_all_tiles() -> void:
	for i in _records.size():
		var rec: Dictionary = _records[i]
		var base_pos := HexGrid.offset_to_world(rec.coord.x, rec.coord.y)
		base_pos.y = LIFT_Y

		# Grass placeholder (spin phase)
		var gt := _load_scene(GRASS_SCENE).instantiate() as Node3D
		gt.name = rec.id + "_grass"
		gt.position = base_pos
		add_child(gt)
		_grass_tiles.append(gt)

		# Real tile, hidden until swap
		var bt := _instantiate_tile(rec)
		if bt == null:
			_biome_tiles.append(null)
			continue
		bt.position = base_pos
		bt.visible = false
		add_child(bt)
		_biome_tiles.append(bt)

		if rec.is_center or rec.is_zone:
			_make_tile_clickable(bt, rec)


# ── Static display mode (renders WorldManager.world_map exactly as stored) ────

func display_stored_world() -> void:
	var stored: Array = WorldManager.world_map
	if stored.is_empty():
		push_warning("[HexMapGenerator] display_mode: WorldManager.world_map is empty — nothing to render.")
		return
	_records = stored.duplicate(true)
	_spawn_tiles_static()


func _spawn_tiles_static() -> void:
	for rec in _records:
		if rec.get("base_path", "") == "":
			push_warning("[HexMapGenerator] Record %s has no base_path — old-format save?" % rec.get("id", "?"))
			continue
		var bt := _instantiate_tile(rec)
		if bt == null:
			_biome_tiles.append(null)
			continue
		bt.position = HexGrid.offset_to_world(rec.coord.x, rec.coord.y)
		bt.visible = true
		add_child(bt)
		_biome_tiles.append(bt)
		_add_hover_area(bt, rec)


# ── Interactive click volumes ─────────────────────────────────────────────────

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
