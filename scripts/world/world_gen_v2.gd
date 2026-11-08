# world_gen_v2.gd — World Gen v2 (prototype; Raphael 2026-11-07: "our world is always the same shape ... noise stuff
# with rivers", "inspire from catlike", "the name generation too that azgaar has"). Every new run's world since
# 2026-11-08: New Game's map table (scenes/world/NewRunMap.tscn, scripts/world/map_table.gd) swaps it in, as the dev
# table (scenes/dev/MapTable.tscn) does. It extends HexMapGenerator and replaces only how the records are BUILT; the
# reveal, the tile instancing, the hex look (rivers included) and the record format are the parent's.
#
# The world, in passes (ideas after Catlike Coding's Hex Map series, MIT-0 code, and Red Blob Games' "Making maps with
# noise functions"; written fresh in GDScript):
#  1. Shape: a rectangle of hexes. A world type is rolled per seed (continent, archipelago, twin continents, inland
#     sea); its shape function, a domain-warped large-scale noise (so coasts twist), fine detail noise, and ridged noise
#     (long mountain ranges, only well inland) give each hex a height. A square bump sinks the map's border into sea.
#     Sea level is a quantile, so each type gets a steady share of land whatever the noise does.
#  2. Climate: moisture (noise, wetter near water and rivers) and temperature (colder north and higher up).
#  3. Water: every land hex drains to the sea by a priority flood (Barnes et al. 2014), which also fills hollows: a deep
#     enough fill is a lake, and so is a small low basin cut off from the ocean (a big one stays an inland sea). Rain
#     (moisture) is summed downstream; hexes carrying the most water are rivers. A river hex
#     knows the edges its water comes in by and leaves by, and takes the KayKit river tile and rotation that match.
#  4. Land: mountains and hills are the top land heights (quantiles), forest grows where it is wet, the rest is grass;
#     grass by water is coast (the hex look paints its beach).
#  5. People: settlements score land by river, coast and lake, spaced out; then 20-30 places to settle (settle_site),
#     the first on good land near the middle. The player picks one on the map table; settle_at() makes it the tavern
#     and reserves the Prior Ruins beside it.
#  6. Names (name_generator.gd): the world, each landmass or isle, forest, range, hill country, lake, river system and
#     settlement, each in the tongue of its latitude (Northmark, Heartland, Southreach; old Elder names for the world
#     and some ranges).
# One seeded RNG for the terrain choices (the parent's _rng), another for names: one seed is always the same world.
extends "res://scripts/world/HexMapGenerator.gd"

const NAME_GEN := preload("res://scripts/world/name_generator.gd")
const RIVER_DIR := "res://assets/environment/hexagons/rivers/"
## Each KayKit river tile and the edges its channel opens on. Edge k faces k * 60 deg in x / z: 0 east, 1 south-east,
## 2 south-west, 3 west, 4 north-west, 5 north-east. Measured from the meshes 2026-11-07 (an opening has a vertex near
## the edge's midpoint at the tile's base). A tile turned by k * 60 deg about +Y moves edge e to (e - k) mod 6.
const RIVER_TILES := {
	"hex_river_A": [0, 3], "hex_river_B": [3, 5], "hex_river_C": [3, 4],
	"hex_river_D": [1, 3, 5], "hex_river_E": [0, 3, 5], "hex_river_F": [0, 1, 3], "hex_river_G": [2, 3, 4],
	"hex_river_H": [0, 2, 3, 4], "hex_river_I": [1, 2, 4, 5], "hex_river_J": [0, 1, 2, 3],
	"hex_river_K": [1, 2, 3, 4, 5], "hex_river_L": [0, 1, 2, 3, 4, 5]}
const RIVER_STRAIGHT_ALT := "hex_river_A_curvy"   # the same edges as A, drawn with a bend
## Neighbour offsets in edge order (odd rows sit half a column right, as in HexGrid).
const EDGE_EVEN := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1)]
const EDGE_ODD := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)]
const TREES := [
	"res://assets/environment/hexagons/nature/trees_A_large.gltf",
	"res://assets/environment/hexagons/nature/trees_A_medium.gltf",
	"res://assets/environment/hexagons/nature/trees_B_large.gltf",
	"res://assets/environment/hexagons/nature/trees_B_medium.gltf",
]
const HILLS := [
	"res://assets/environment/hexagons/nature/hills_A_trees.gltf",
	"res://assets/environment/hexagons/nature/hills_B_trees.gltf",
	"res://assets/environment/hexagons/nature/hills_C_trees.gltf",
	"res://assets/environment/hexagons/nature/hill_single_A.gltf",
	"res://assets/environment/hexagons/nature/hill_single_B.gltf",
]
const KINDS := ["continent", "archipelago", "twin", "inland_sea"]
const LAND_SHARE := {"continent": 0.46, "archipelago": 0.30, "twin": 0.40, "inland_sea": 0.44}

## Hexes across and down (100 x 64 = 6,400).
@export var world_width: int = 100
@export var world_height: int = 64
## "random" rolls one per seed.
@export_enum("random", "continent", "archipelago", "twin", "inland_sea") var world_type: String = "random"
## About this share of the land carries a river.
@export_range(0.0, 0.2) var river_share: float = 0.06
## How many places to settle a world offers, rolled per world between x and y (game_config world_gen_tavern_sites).
@export var tavern_sites := Vector2i(20, 30)
## A place to settle keeps this many steps from every town (the old single tavern kept 3).
const SITE_TOWN_GAP := 3

var world_name := ""
var world_kind := ""
var tavern_coord := Vector2i.ZERO
var stats := {}             # counts for the preview and the table's title

var _w := 0
var _h := 0
var _c0 := 0
var _r0 := 0
var _nb := PackedInt32Array()   # 6 neighbour indices per hex (-1 off the map)
var _c1 := Vector2.ZERO          # shape centres (twin continents, the inland sea)
var _c2 := Vector2.ZERO
var _n_shape := FastNoiseLite.new()
var _n_detail := FastNoiseLite.new()
var _n_ridge := FastNoiseLite.new()
var _n_warp := FastNoiseLite.new()
var _n_moist := FastNoiseLite.new()
var _n_temp := FastNoiseLite.new()
var _hk := PackedFloat32Array()  # the priority flood's heap: keys, values, size
var _hv := PackedInt32Array()
var _hn := 0


# ── 1-6: the world ────────────────────────────────────────────────────────────

func _build_records() -> Array:
	_w = maxi(world_width, 12)
	_h = maxi(world_height, 12)
	_c0 = -_w / 2
	_r0 = -_h / 2
	var n := _w * _h
	world_kind = world_type if world_type in KINDS else KINDS[_rng.randi_range(0, KINDS.size() - 1)]
	_setup_noise()
	_nb = _neighbour_table()

	var px := PackedFloat32Array()
	var pz := PackedFloat32Array()
	px.resize(n)
	pz.resize(n)
	for i in n:
		var p := HexGrid.offset_to_world(_c0 + i % _w, _r0 + i / _w)
		px[i] = p.x
		pz[i] = p.z

	# 1. height, sea level by quantile, the border always sea
	var e := _heights(px, pz)
	for i in n:
		if _on_border(i):
			e[i] = -10.0
	var sea_level := _quantile(e, 1.0 - float(LAND_SHARE[world_kind]))
	var sea := PackedByteArray()
	sea.resize(n)
	var land_h := PackedFloat32Array()
	for i in n:
		sea[i] = 1 if e[i] <= sea_level else 0
		if sea[i] == 0:
			land_h.append(e[i] - sea_level)
	var max_h := 0.0
	for v in land_h:
		max_h = maxf(max_h, v)

	# 2. climate: distance to the sea, moisture, temperature
	var sea_dist := _distance_from(sea)
	var moist := PackedFloat32Array()
	var temp := PackedFloat32Array()
	moist.resize(n)
	temp.resize(n)
	for i in n:
		var near := 1.0 - minf(float(sea_dist[i]), 8.0) / 8.0
		moist[i] = clampf(_n_moist.get_noise_2d(px[i], pz[i]) * 0.5 + 0.5 + near * 0.12 - 0.02, 0.0, 1.0)
		var lat := (pz[i] / float(_h) + 1.0) * 0.5          # 0 north .. 1 south
		var hn := maxf(e[i] - sea_level, 0.0) / maxf(max_h, 0.001)
		temp[i] = clampf(lat * 0.8 + 0.2 - hn * 0.5 + _n_temp.get_noise_2d(px[i], pz[i]) * 0.1, 0.0, 1.0)

	# 3. water: priority flood (drainage + filled hollows), lakes, flow, rivers
	var filled := e.duplicate()
	var down := PackedInt32Array()
	down.resize(n)
	down.fill(-1)
	var order := _priority_flood(e, sea, filled, down)
	var lake := PackedByteArray()
	lake.resize(n)
	var lake_depth := maxf(max_h * 0.07, 0.01)
	for i in order:
		if filled[i] - e[i] > lake_depth:
			lake[i] = 1
	var basins := _enclosed_basins(sea, 60)   # low valleys cut off from the ocean: lakes, not "sea"
	for i in n:
		if basins[i] == 1:
			lake[i] = 1
	var flow := PackedFloat32Array()
	flow.resize(n)
	for k in range(order.size() - 1, -1, -1):
		var i: int = order[k]
		flow[i] += 0.4 + moist[i]
		var d := down[i]
		if d >= 0 and sea[d] == 0:
			flow[d] += flow[i]
	var land_flows := PackedFloat32Array()
	for i in order:
		if lake[i] == 0:
			land_flows.append(flow[i])
	var thr := maxf(_quantile(land_flows, 1.0 - river_share), 7.0)
	var river := PackedByteArray()
	river.resize(n)
	for i in order:
		if lake[i] == 0 and flow[i] >= thr:
			river[i] = 1
	for i in n:   # rivers water their banks
		if river[i] == 1:
			for k in 6:
				var nb := _nb[i * 6 + k]
				if nb >= 0:
					moist[nb] = minf(moist[nb] + 0.12, 1.0)

	# 4. land: mountains / hills by height quantile, forest by moisture, the rest grass; coast by water
	var q_mount := _quantile(land_h, 0.91) + sea_level
	var q_hill := _quantile(land_h, 0.80) + sea_level
	var recs := []
	var by_coord := {}
	for i in n:
		var c := Vector2i(_c0 + i % _w, _r0 + i / _w)
		var biome := "grass"
		if sea[i] == 1 or lake[i] == 1:
			biome = "sea"
		elif e[i] >= q_mount:
			biome = "mountain"
		elif e[i] >= q_hill:
			biome = "hills"
		elif moist[i] >= 0.58 - (0.06 if temp[i] < 0.3 else 0.0):
			biome = "forest"
		var rec := {
			"id": "hex_%d" % i, "coord": c, "biome": biome, "is_center": false, "is_zone": false,
			"location_name": "", "active_mission": null, "base_path": "", "base_rot_y": 0.0, "topper_paths": [],
			"is_lake": lake[i] == 1, "river_mask": 0, "river": "", "region": "", "feature": "",
			"culture": _culture(px[i], pz[i]), "height": snappedf(e[i] - sea_level, 0.001),
			"moisture": snappedf(moist[i], 0.01), "temperature": snappedf(temp[i], 0.01),
		}
		recs.append(rec)
		by_coord[c] = rec
	for i in n:
		if river[i] == 1:
			recs[i].river_mask = _river_mask(i, down, river, lake, flow)
	for rec in recs:
		if rec.biome == "grass" and rec.river_mask == 0 and not _sea_neighbors_of(rec, by_coord).is_empty():
			rec.biome = "coast"
	for rec in recs:
		if rec.biome == "coast":
			rec.base_rot_y = _coast_rotation(rec, by_coord)

	# 5. the settlements, then the places to settle (no tavern until the player picks one)
	_place_people(recs, px, pz)

	# 6. names
	_name_world(recs, down, river)

	var land := 0
	var rivers := 0
	var lakes := 0
	for rec in recs:
		if rec.biome != "sea":
			land += 1
		if rec.river_mask != 0:
			rivers += 1
		if rec.is_lake:
			lakes += 1
	stats = {"kind": world_kind, "hexes": n, "land": land, "river_hexes": rivers, "lake_hexes": lakes,
		"sites": recs.filter(func(r): return r.get("settle_site", false)).size()}
	return recs


# ── Shape ─────────────────────────────────────────────────────────────────────

func _setup_noise() -> void:
	var span := float(mini(_w, _h))      # half the world's shorter side, in world units (a hex is 2 across)
	var noises := [_n_shape, _n_detail, _n_ridge, _n_warp, _n_moist, _n_temp]
	for k in noises.size():
		var nz: FastNoiseLite = noises[k]
		nz.seed = map_seed + 1013 * (k + 1)
		nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		nz.fractal_type = FastNoiseLite.FRACTAL_FBM
	_n_shape.frequency = (2.2 if world_kind == "archipelago" else 1.0) / (span * 0.95)
	_n_shape.fractal_octaves = 3
	_n_detail.frequency = 0.07
	_n_detail.fractal_octaves = 3
	_n_ridge.frequency = 1.0 / (span * 0.5)
	_n_ridge.fractal_type = FastNoiseLite.FRACTAL_NONE
	_n_warp.frequency = 1.0 / (span * 0.9)
	_n_warp.fractal_octaves = 2
	_n_moist.frequency = 1.0 / (span * 0.6)
	_n_moist.fractal_octaves = 3
	_n_temp.frequency = 0.03
	_n_temp.fractal_octaves = 2
	var j := func() -> float: return _rng.randf_range(-0.12, 0.12)
	match world_kind:
		"twin":
			_c1 = Vector2(-0.46 + j.call(), j.call())
			_c2 = Vector2(0.46 + j.call(), j.call())
		"inland_sea":
			_c1 = Vector2(j.call(), j.call())


func _heights(px: PackedFloat32Array, pz: PackedFloat32Array) -> PackedFloat32Array:
	var n := px.size()
	var e := PackedFloat32Array()
	e.resize(n)
	var hw := float(_w)    # half the width in world units (columns are 2 apart)
	var hh := float(_h)
	var warp := minf(hw, hh) * (0.14 if world_kind == "archipelago" else 0.25)
	for i in n:
		var x := px[i]
		var z := pz[i]
		var qx := x + _n_warp.get_noise_2d(x, z) * warp
		var qz := z + _n_warp.get_noise_2d(x + 731.0, z - 417.0) * warp
		var s := _shape(qx / hw, qz / hh, qx, qz)
		if s > 0.55:
			s = 0.55 + (s - 0.55) * 0.35   # a flatter interior: the ranges below make the peaks, not the shape's middle
		var ridge := 1.0 - absf(_n_ridge.get_noise_2d(qx, qz))
		var inland := clampf((s - 0.45) * 3.0, 0.0, 1.0)
		var v := s + _n_detail.get_noise_2d(qx, qz) * 0.16 + ridge * ridge * ridge * 0.5 * inland
		var ux := x / hw
		var vz := z / hh
		var edge := 1.0 - (1.0 - ux * ux) * (1.0 - vz * vz)   # Red Blob Games' square bump: 0 inside, 1 at the border
		e[i] = v - smoothstep(0.55, 1.0, edge) * 0.9
	return e


## 0..1: how much this world type wants land at (u, v) in -1..1 (warped).
func _shape(u: float, v: float, qx: float, qz: float) -> float:
	var base := _n_shape.get_noise_2d(qx, qz) * 0.5 + 0.5
	match world_kind:
		"archipelago":
			return base * 0.9 + 0.05
		"twin":
			return maxf(_blob(u, v, _c1, 0.62), _blob(u, v, _c2, 0.62)) * 0.7 + base * 0.4
		"inland_sea":
			return (1.0 - (u * u + v * v) * 0.35) * 0.55 + base * 0.45 - _blob(u, v, _c1, 0.48) * 0.75
	return (1.0 - (u * u + v * v) * 0.5) * 0.45 + base * 0.6


func _blob(u: float, v: float, c: Vector2, r: float) -> float:
	return clampf(1.0 - Vector2(u, v).distance_to(c) / r, 0.0, 1.0)


# ── Water ─────────────────────────────────────────────────────────────────────

## Floods inward from every sea hex, lowest first: each land hex drains (down) to the neighbour that reached it, and its
## filled height rises just above that neighbour's, so hollows fill into flats a lake can sit in. Returns the land hexes
## in the order they were reached (lowest first; reversed, every hex comes before the hex it drains into).
func _priority_flood(e: PackedFloat32Array, sea: PackedByteArray, filled: PackedFloat32Array,
		down: PackedInt32Array) -> PackedInt32Array:
	var n := e.size()
	var seen := PackedByteArray()
	seen.resize(n)
	var order := PackedInt32Array()
	_hn = 0
	for i in n:
		if sea[i] == 1:
			seen[i] = 1
			_hpush(e[i], i)
	while _hn > 0:
		var cur := _hpop()
		for k in 6:
			var nb := _nb[cur * 6 + k]
			if nb < 0 or seen[nb] == 1:
				continue
			seen[nb] = 1
			filled[nb] = maxf(e[nb], filled[cur] + 0.0004)
			down[nb] = cur
			order.append(nb)
			_hpush(filled[nb], nb)
	return order


## The edges a river hex's water uses: out to the hex it drains into, in from every river (or lake) hex draining into
## it. A spring (no water coming in) takes its biggest feeder's edge, or the edge facing away, so the channel reads as
## a stream starting rather than a dead end.
func _river_mask(i: int, down: PackedInt32Array, river: PackedByteArray, lake: PackedByteArray,
		flow: PackedFloat32Array) -> int:
	var mask := 0
	var out_edge := -1
	var best_in := -1
	var best_flow := -1.0
	for k in 6:
		var nb := _nb[i * 6 + k]
		if nb < 0:
			continue
		if nb == down[i]:
			mask |= 1 << k
			out_edge = k
		elif down[nb] == i:
			if river[nb] == 1 or lake[nb] == 1:
				mask |= 1 << k
			elif flow[nb] > best_flow:
				best_flow = flow[nb]
				best_in = k
	if _bits(mask) <= 1:
		if best_in >= 0:
			mask |= 1 << best_in
		elif out_edge >= 0:
			mask |= 1 << ((out_edge + 3) % 6)
	return mask


## [tile name, turns]: the river tile whose openings, turned by turns * 60 deg, are exactly `mask`; failing that, the
## closest one (most shared openings, fewest extra ones).
func _river_tile(mask: int) -> Array:
	var best := ["hex_river_A", 0]
	var best_score := -100
	for tile in RIVER_TILES:
		var edges: Array = RIVER_TILES[tile]
		for k in 6:
			var m := 0
			for e in edges:
				m |= 1 << posmod(int(e) - k, 6)
			if m == mask:
				if tile == "hex_river_A" and _rng.randf() < 0.5:
					return [RIVER_STRAIGHT_ALT, k]
				return [tile, k]
			var score := _bits(m & mask) * 2 - _bits(m & ~mask) * 3 - _bits(mask & ~m) * 2
			if score > best_score:
				best_score = score
				best = [tile, k]
	return best


# ── People ────────────────────────────────────────────────────────────────────

## Good ground to live on: grass, coast or forest, by a river, a lake or the sea.
func _settle_score(rec: Dictionary, recs: Array, i: int) -> float:
	var s: float = {"grass": 1.0, "coast": 0.9, "forest": 0.5}.get(rec.biome, -10.0)
	if rec.river_mask != 0 or rec.is_center or rec.is_zone:
		return -10.0
	var ground := 0
	for k in 6:
		var nb := _nb[i * 6 + k]
		if nb < 0:
			continue
		var o: Dictionary = recs[nb]
		if o.biome != "sea":
			ground += 1
		if o.river_mask != 0:
			s += 0.7
		elif o.is_lake:
			s += 0.5
		elif o.biome == "sea":
			s += 0.25
	return s if ground >= 3 else -10.0   # solid ground round it: no town on a one-hex islet


func _place_people(recs: Array, px: PackedFloat32Array, pz: PackedFloat32Array) -> void:
	var n := recs.size()
	var land := 0
	for rec in recs:
		if rec.biome != "sea":
			land += 1

	# settlements: best ground first, spaced out (then the places to settle, _place_sites, keep clear of them)
	var want := clampi(int(round(land / 160.0)), 6, 48)
	var spacing := maxi(4, int(sqrt(float(land) / want) * 0.9))
	var cands := []
	for i in n:
		var s := _settle_score(recs[i], recs, i)
		if s > 0.0:
			cands.append([s + _rng.randf() * 0.6, i])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var buildings := ZONE_BUILDINGS.duplicate()
	for k in range(buildings.size() - 1, 0, -1):
		var j := _rng.randi_range(0, k)
		var t = buildings[k]
		buildings[k] = buildings[j]
		buildings[j] = t
	var placed := []
	while placed.size() < want and spacing >= 2:
		for cand in cands:
			if placed.size() >= want:
				break
			var rec: Dictionary = recs[cand[1]]
			if rec.is_zone:
				continue
			var ok := true
			for z in placed:
				if _hex_distance(rec.coord, z.coord) < spacing:
					ok = false
					break
			if ok:
				rec.is_zone = true
				rec["zone_building"] = buildings[placed.size() % buildings.size()]
				placed.append(rec)
		spacing -= 1
	_place_sites(recs, px, pz, placed, land)


## The places the player may settle (Raphael 2026-11-08: "put the N amount that was planned initially": the old
## settlement-choice plan's 20-30 places): tavern_sites.x..tavern_sites.y records get settle_site = true. Each is good
## ground (_settle_score), never a town, a river or a lake, at least SITE_TOWN_GAP steps from every town, with room for
## the Prior Ruins beside it (2+ dry land neighbours), spread over the land. The first is the old single pick (good
## ground near the middle, heartland preferred): tavern_coord, where the table opens. No hex is the tavern until
## settle_at().
func _place_sites(recs: Array, px: PackedFloat32Array, pz: PackedFloat32Array, towns: Array, land: int) -> void:
	var n := recs.size()
	var lo := maxi(1, mini(tavern_sites.x, tavern_sites.y))
	var want := _rng.randi_range(lo, maxi(lo, maxi(tavern_sites.x, tavern_sites.y)))
	var scored := []
	var best := -1
	var best_s := -INF
	for i in n:
		var s := _settle_score(recs[i], recs, i)
		if s <= 0.0 or not _site_ok(recs, i, towns):
			continue
		scored.append([s + _rng.randf() * 0.6, i])
		var m := s - (absf(px[i]) / float(_w) + absf(pz[i]) / float(_h)) * 2.2 + (0.3 if recs[i].culture == "heartland" else 0.0)
		if m > best_s:
			best_s = m
			best = i
	if best < 0:   # no good ground anywhere: the first land hex that isn't a town
		for i in n:
			if recs[i].biome != "sea" and not recs[i].is_zone:
				best = i
				break
	if best < 0:
		push_warning("[WorldGenV2] no land to settle on")
		return
	recs[best]["settle_site"] = true
	tavern_coord = recs[best].coord
	var sites := [recs[best]]
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var spacing := maxi(3, int(sqrt(float(land) / float(want)) * 0.8))
	while sites.size() < want and spacing >= 2:
		for c in scored:
			if sites.size() >= want:
				break
			var rec: Dictionary = recs[c[1]]
			if rec.get("settle_site", false):
				continue
			var ok := true
			for s in sites:
				if _hex_distance(rec.coord, s.coord) < spacing:
					ok = false
					break
			if ok:
				rec["settle_site"] = true
				sites.append(rec)
		spacing -= 1


## A place to settle: not a town, a river, a lake or the map's border; 2+ dry land neighbours that aren't towns (the
## Prior Ruins' room, pick_ruin_hex's biomes); SITE_TOWN_GAP steps or more from every town.
func _site_ok(recs: Array, i: int, towns: Array) -> bool:
	var rec: Dictionary = recs[i]
	if rec.is_zone or rec.river_mask != 0 or rec.is_lake or _on_border(i):
		return false
	var free := 0
	for k in 6:
		var nb := _nb[i * 6 + k]
		if nb >= 0 and recs[nb].biome in ["grass", "forest", "mountain", "coast"] and recs[nb].river_mask == 0 \
				and not recs[nb].is_zone:
			free += 1
	if free < 2:
		return false
	for z in towns:
		if _hex_distance(rec.coord, z.coord) < SITE_TOWN_GAP:
			return false
	return true


## The player settles at `site`, one of this world's settle_site records: it becomes the tavern (is_center, the
## tavern_site biome on a grass tile with the guild's tavern and banner, as _resolve_visuals draws it), the Prior Ruins
## are reserved beside it (dry land, the parent's rule, no RNG drawn), and no record keeps settle_site. False, and
## nothing changed, for any other record or once a tavern exists.
func settle_at(site: Dictionary) -> bool:
	if not site.get("settle_site", false) or _records.any(func(r): return r.get("is_center", false)) \
			or not _records.any(func(r): return is_same(r, site)):
		return false
	for r in _records:
		r.erase("settle_site")
	site.is_center = true
	site.biome = "tavern_site"
	site.base_path = GRASS_SCENE
	site.base_rot_y = 0.0
	site.topper_paths = [TAVERN_TOPPER, HOME_MARKER]
	tavern_coord = site.coord
	var dry := _records.filter(func(r): return r.get("river_mask", 0) == 0)
	var pick: Dictionary = pick_ruin_hex(dry, tavern_coord, map_seed)
	if pick.is_empty():
		push_warning("[WorldGenV2] ruin: no free land next to the tavern; none reserved.")
	else:
		mark_ruin(pick)
	return true


# ── Names ─────────────────────────────────────────────────────────────────────

func _culture(x: float, z: float) -> String:
	var lat := (z / float(_h) + 1.0) * 0.5 + _n_temp.get_noise_2d(x * 0.5, z * 0.5) * 0.08
	if lat < 0.34:
		return "northmark"
	if lat > 0.68:
		return "southreach"
	return "heartland"


func _name_world(recs: Array, down: PackedInt32Array, river: PackedByteArray) -> void:
	var nrng := RandomNumberGenerator.new()
	nrng.seed = map_seed ^ 0x5EED ^ hash(world_kind)   # each world type of a seed gets its own names
	var names = NAME_GEN.new(nrng)
	world_name = names.place("world", "elder")
	for rec in recs:
		if rec.is_zone:
			rec.location_name = names.make(rec.culture)
	# landmasses: the biggest are lands, the small ones isles
	var lands := _components(recs, func(r): return r.biome != "sea")
	var biggest := 1
	for comp in lands:
		biggest = maxi(biggest, comp.size())
	for comp in lands:
		if comp.size() < 4:
			continue
		var c0: String = recs[comp[0]].culture
		var kind := "land" if comp.size() >= biggest * 0.25 else "island"
		var nm: String = names.place(kind, c0)
		for i in comp:
			recs[i].region = nm
	# forests, ranges, hill country, lakes
	var feats := [["forest", 8, func(r): return r.biome == "forest"],
		["mountains", 3, func(r): return r.biome == "mountain"],
		["hills", 8, func(r): return r.biome == "hills"],
		["lake", 1, func(r): return r.is_lake]]
	for f in feats:
		for comp in _components(recs, f[2]):
			if comp.size() < f[1]:
				continue
			var tongue: String = recs[comp[0]].culture
			if f[0] == "mountains" and nrng.randf() < 0.5:
				tongue = "elder"
			var nm: String = names.place(f[0], tongue)
			for i in comp:
				recs[i].feature = nm
	# river systems, named at their mouth; a system shorter than 3 hexes stays a stream
	var mouth := {}
	var members := {}
	for i in recs.size():
		if river[i] == 0:
			continue
		var m := i
		var guard := 0
		while down[m] >= 0 and river[down[m]] == 1 and guard < 10000:
			m = down[m]
			guard += 1
		mouth[i] = m
		if not members.has(m):
			members[m] = []
		members[m].append(i)
	for m in members:
		if members[m].size() < 3:
			continue
		var nm: String = names.place("river", recs[m].culture)
		for i in members[m]:
			recs[i].river = nm


## Connected groups of hexes passing `test` (6-neighbour flood fill), biggest first.
func _components(recs: Array, test: Callable) -> Array:
	var n := recs.size()
	var seen := PackedByteArray()
	seen.resize(n)
	var out := []
	for i in n:
		if seen[i] == 1 or not test.call(recs[i]):
			continue
		var comp := [i]
		seen[i] = 1
		var head := 0
		while head < comp.size():
			var cur: int = comp[head]
			head += 1
			for k in 6:
				var nb := _nb[cur * 6 + k]
				if nb >= 0 and seen[nb] == 0 and test.call(recs[nb]):
					seen[nb] = 1
					comp.append(nb)
		out.append(comp)
	out.sort_custom(func(a, b): return a.size() > b.size())
	return out


# ── Visuals (all the RNG for looks happens here; the records keep the result) ─

func _resolve_visuals() -> void:
	for rec in _records:
		rec.topper_paths = []
		if rec.biome == "sea":
			rec.base_path = WATER_SCENE
			if _rng.randf() < (0.3 if rec.is_lake else sea_decor_chance * 0.3):
				rec.topper_paths.append(SEA_DECOR[_rng.randi_range(0, SEA_DECOR.size() - 1)])
		elif rec.river_mask != 0 and not rec.is_center and not rec.is_zone:
			var pick := _river_tile(rec.river_mask)
			rec.base_path = RIVER_DIR + str(pick[0]) + ".gltf"
			rec.base_rot_y = int(pick[1]) * PI / 3.0
		elif rec.biome == "coast":
			rec.base_path = COAST_VARIANTS[_rng.randi_range(0, COAST_VARIANTS.size() - 1)]
		else:
			rec.base_path = GRASS_SCENE
			match rec.biome:
				"forest":
					rec.topper_paths.append(TREES[_rng.randi_range(0, TREES.size() - 1)])
				"hills":
					rec.topper_paths.append(HILLS[_rng.randi_range(0, HILLS.size() - 1)])
				"mountain":
					rec.topper_paths.append(MOUNTAIN_TOPPERS[_rng.randi_range(0, MOUNTAIN_TOPPERS.size() - 1)])
				"tavern_site":
					rec.topper_paths.append(TAVERN_TOPPER)
					rec.topper_paths.append(HOME_MARKER)
				_:
					if _rng.randf() < grass_decor_chance * 0.5:
						rec.topper_paths.append(GRASS_DECOR[_rng.randi_range(0, GRASS_DECOR.size() - 1)])
		if rec.is_zone:
			rec.topper_paths = [rec.get("zone_building", ZONE_BUILDINGS[0])]


## The Prior Ruins go next to the tavern, and a v2 world has no tavern until the player settles: settle_at() reserves
## them (the parent's generation-time reservation assumes the centre hex).
func _reserve_ruin() -> void:
	pass


# ── Helpers ───────────────────────────────────────────────────────────────────

func _neighbour_table() -> PackedInt32Array:
	var t := PackedInt32Array()
	t.resize(_w * _h * 6)
	for i in _w * _h:
		var c := _c0 + i % _w
		var r := _r0 + i / _w
		var deltas: Array = EDGE_ODD if (r & 1) == 1 else EDGE_EVEN
		for k in 6:
			var d: Vector2i = deltas[k]
			var nc := c + d.x - _c0
			var nr := r + d.y - _r0
			t[i * 6 + k] = nr * _w + nc if nc >= 0 and nc < _w and nr >= 0 and nr < _h else -1
	return t


## Sea hexes not joined to the ocean round the map, in basins of at most `max_size` hexes (1 = such a hex). Those are
## lakes; a bigger enclosed basin stays an inland sea.
func _enclosed_basins(sea: PackedByteArray, max_size: int) -> PackedByteArray:
	var n := sea.size()
	var ocean := PackedByteArray()
	ocean.resize(n)
	var queue := PackedInt32Array()
	for i in n:
		if sea[i] == 1 and _on_border(i):
			ocean[i] = 1
			queue.append(i)
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		for k in 6:
			var nb := _nb[cur * 6 + k]
			if nb >= 0 and sea[nb] == 1 and ocean[nb] == 0:
				ocean[nb] = 1
				queue.append(nb)
	var out := PackedByteArray()
	out.resize(n)
	var seen := PackedByteArray()
	seen.resize(n)
	for i in n:
		if sea[i] == 0 or ocean[i] == 1 or seen[i] == 1:
			continue
		var comp := PackedInt32Array([i])
		seen[i] = 1
		var h := 0
		while h < comp.size():
			var cur := comp[h]
			h += 1
			for k in 6:
				var nb := _nb[cur * 6 + k]
				if nb >= 0 and sea[nb] == 1 and ocean[nb] == 0 and seen[nb] == 0:
					seen[nb] = 1
					comp.append(nb)
		if comp.size() <= max_size:
			for j in comp:
				out[j] = 1
	return out


func _on_border(i: int) -> bool:
	var c := i % _w
	var r := i / _w
	return c == 0 or r == 0 or c == _w - 1 or r == _h - 1


## Hexes from the nearest marked hex (multi-source breadth first); unreachable = 9999.
func _distance_from(marks: PackedByteArray) -> PackedInt32Array:
	var n := marks.size()
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(9999)
	var queue := PackedInt32Array()
	for i in n:
		if marks[i] == 1:
			dist[i] = 0
			queue.append(i)
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		for k in 6:
			var nb := _nb[cur * 6 + k]
			if nb >= 0 and dist[nb] > dist[cur] + 1:
				dist[nb] = dist[cur] + 1
				queue.append(nb)
	return dist


func _quantile(values: PackedFloat32Array, q: float) -> float:
	if values.is_empty():
		return 0.0
	var s := values.duplicate()
	s.sort()
	return s[clampi(int(q * (s.size() - 1)), 0, s.size() - 1)]


func _bits(m: int) -> int:
	var c := 0
	for k in 6:
		if m & (1 << k):
			c += 1
	return c


func _hpush(key: float, val: int) -> void:
	if _hn >= _hk.size():
		var size := maxi(64, _hk.size() * 2)
		_hk.resize(size)
		_hv.resize(size)
	var i := _hn
	_hn += 1
	while i > 0:
		var p := (i - 1) >> 1
		if _hk[p] <= key:
			break
		_hk[i] = _hk[p]
		_hv[i] = _hv[p]
		i = p
	_hk[i] = key
	_hv[i] = val


func _hpop() -> int:
	var top := _hv[0]
	_hn -= 1
	if _hn > 0:
		var key := _hk[_hn]
		var val := _hv[_hn]
		var i := 0
		while true:
			var l := i * 2 + 1
			if l >= _hn:
				break
			var r := l + 1
			var m := r if r < _hn and _hk[r] < _hk[l] else l
			if _hk[m] >= key:
				break
			_hk[i] = _hk[m]
			_hv[i] = _hv[m]
			i = m
		_hk[i] = key
		_hv[i] = val
	return top
