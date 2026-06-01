extends Node3D

# Biome pool counts — tweak in inspector to change world composition.
@export var count_forest: int = 3
@export var count_mountain: int = 3
@export var count_mine: int = 1
@export var count_river: int = 3
@export var count_coast: int = 3
@export var count_sea: int = 1
# Remaining slots (out of 18 non-center hexes) fill with "grass".

# ── Animation constants ───────────────────────────────────────────────────────
# Measured from HexagoneWorld.tscn; spacing set to 2.0 (see HexGrid.gd).

## Tiles start this many units above their final Y = 0.
const LIFT_Y := 3.0

## One full X-axis rotation takes this many seconds.
const SPIN_PERIOD := 1.0

## 5.25 complete rotations → rotation.x ≡ π/2 (mod 2π) = edge-on at swap time.
## The top face is perpendicular to the camera, hiding the mesh swap.
const TOTAL_ROTATIONS := 5.25

## After the swap, 0.75 more rotations brings tiles to face-up (5.25 + 0.75 = 6.0 ≡ 0).
const SETTLE_ROT_EXTRA := 0.75

## Seconds for tiles to ease down from LIFT_Y to Y = 0 after the swap.
const SETTLE_DURATION := 0.8

# ── Tile scene paths ──────────────────────────────────────────────────────────

const GRASS_SCENE := "res://assets/environment/hexagons/base/hex_grass.gltf"

const MOUNTAIN_VARIANTS := [
	"res://assets/environment/hexagons/nature/mountain_A_grass_trees.gltf",
	"res://assets/environment/hexagons/nature/mountain_B.gltf",
]
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

# Toppers added as children of their base tile; one variant chosen randomly.
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
}

# ── Fixed coordinate layout (offset coords, 19 hexes) ────────────────────────
# Center (2,2) is always tavern_site — never shuffled.

const CENTER_COORD := Vector2i(2, 2)
const HEX_COORDS := [
	# row 0 (even)
	Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	# row 1 (odd — shifted right by HexGrid.ROW_OFFSET)
	Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
	# row 2 (even) — center hex is (2,2)
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
	# row 3 (odd)
	Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
	# row 4 (even)
	Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4),
]

# ── Runtime state ─────────────────────────────────────────────────────────────

var _records := []
var _grass_tiles: Array = []  # placeholder grass visible during spin phase
var _biome_tiles: Array = []  # final biome tiles, hidden until swap


func _ready() -> void:
	_records = _build_records()
	# TODO: persist via WorldManager + GameManager.get_save_data()
	print("[HexMapGenerator] Generated layout:")
	for rec in _records:
		print("  %-8s  coord=%s  biome=%s" % [rec.id, str(rec.coord), rec.biome])
	_run_reveal()


# ── Reveal coroutine ──────────────────────────────────────────────────────────

func _run_reveal() -> void:
	_spawn_all_tiles()

	# ── Phase: spin ──────────────────────────────────────────────────────────
	# All grass tiles tumble on their local X axis at the same speed.
	# TOTAL_ROTATIONS * SPIN_PERIOD ≈ 5.25 s; ends with tiles edge-on (π/2).
	var hold: float = TOTAL_ROTATIONS * SPIN_PERIOD
	for gt in _grass_tiles:
		var tween := create_tween()
		tween.tween_property(gt, "rotation:x", TOTAL_ROTATIONS * TAU, hold) \
			 .from(0.0).set_trans(Tween.TRANS_LINEAR)

	await get_tree().create_timer(hold).timeout

	# ── Phase: swap ──────────────────────────────────────────────────────────
	# All tiles are edge-on at this moment — the mesh swap is invisible.
	var swap_rot: float = TOTAL_ROTATIONS * TAU
	for i in _records.size():
		var bt: Node3D = _biome_tiles[i]
		if bt == null:
			continue
		bt.rotation.x = swap_rot
		_grass_tiles[i].visible = false
		bt.visible = true

	# Grass tiles served their purpose; free them now.
	for gt in _grass_tiles:
		gt.queue_free()
	_grass_tiles.clear()

	# ── Phase: settle ─────────────────────────────────────────────────────────
	# Tiles complete the remaining 0.75 rotation (landing face-up) while
	# simultaneously easing down from LIFT_Y to Y = 0.
	var final_rot: float = (TOTAL_ROTATIONS + SETTLE_ROT_EXTRA) * TAU
	for bt in _biome_tiles:
		if bt == null:
			continue
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(bt, "rotation:x", final_rot, SETTLE_ROT_EXTRA * SPIN_PERIOD) \
			 .from(swap_rot).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(bt, "position:y", 0.0, SETTLE_DURATION) \
			 .from(LIFT_Y).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ── Tile spawner ──────────────────────────────────────────────────────────────

func _spawn_all_tiles() -> void:
	for i in _records.size():
		var rec: Dictionary = _records[i]
		var base_pos := HexGrid.offset_to_world(rec.coord.x, rec.coord.y)
		base_pos.y = LIFT_Y

		# Grass placeholder — visible during the spin phase.
		var grass_packed: PackedScene = load(GRASS_SCENE)
		var gt := grass_packed.instantiate() as Node3D
		gt.name = rec.id + "_grass"
		gt.position = base_pos
		add_child(gt)
		_grass_tiles.append(gt)

		# Biome tile with toppers — hidden until the swap.
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
		for tp in _topper_paths_for(rec.biome):
			var tp_packed: PackedScene = load(tp)
			if tp_packed != null:
				bt.add_child(tp_packed.instantiate() as Node3D)
		add_child(bt)
		_biome_tiles.append(bt)


# ── Data builder (shuffle logic — do not modify) ──────────────────────────────

func _build_records() -> Array:
	var pool := []
	for _i in count_forest:   pool.append("forest")
	for _i in count_mountain: pool.append("mountain")
	for _i in count_mine:     pool.append("mine")
	for _i in count_river:    pool.append("river")
	for _i in count_coast:    pool.append("coast")
	for _i in count_sea:      pool.append("sea")
	var remainder := (HEX_COORDS.size() - 1) - pool.size()
	for _i in maxi(remainder, 0):
		pool.append("grass")
	pool.shuffle()

	var records := []
	var pool_idx := 0
	for i in HEX_COORDS.size():
		var coord: Vector2i = HEX_COORDS[i]
		var is_center := (coord == CENTER_COORD)
		var biome: String = "tavern_site" if is_center else pool[pool_idx]
		if not is_center:
			pool_idx += 1
		records.append({
			"id":        "hex_%d" % i,
			"coord":     coord,
			"biome":     biome,
			"is_center": is_center,
		})
	return records


func _base_path_for(biome: String) -> String:
	match biome:
		"mountain": return MOUNTAIN_VARIANTS[randi() % MOUNTAIN_VARIANTS.size()]
		"river":    return RIVER_VARIANTS[randi() % RIVER_VARIANTS.size()]
		"coast":    return COAST_VARIANTS[randi() % COAST_VARIANTS.size()]
		"sea":      return "res://assets/environment/hexagons/base/hex_water.gltf"
		_:          return "res://assets/environment/hexagons/base/hex_grass.gltf"


func _topper_paths_for(biome: String) -> Array:
	if biome not in TOPPERS:
		return []
	var options: Array = TOPPERS[biome]
	return [options[randi() % options.size()]]
