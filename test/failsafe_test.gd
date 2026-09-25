extends SceneTree

## Standalone failsafe tests — no framework, no autoloads needed.
## Run via CLI:
##   "E:\Godot installer\Godot_v4.4.1-stable_win64.exe" --headless --script res://test/failsafe_test.gd --path "F:\GAME I AM MAKING\shiningsun"
## Test 5 (asset-path integrity, Epic 25 / Story 25.1) checks every res:// path referenced
## from data/**/*.json against disk; known gaps live in res://test/asset_path_allowlist.json.
## Test 6 (ruin reservation, Story 25.2) loads HexMapGenerator.gd / WorldManager.gd, which name
## autoloads; those names only resolve once the engine has registered the autoloads, so the suite
## runs from _initialize() rather than _init(). Autoloads start either way (they always did); the
## tests themselves still use none of them. A watchdog guarantees the run ends (SaveSystem's
## 300 s autosave must never fire from a test run).

const ASSET_ALLOWLIST_PATH := "res://test/asset_path_allowlist.json"
const WORLDGEN_FIXTURE_PATH := "res://test/fixtures/worldgen_seed_12345.json"
const RUIN_TOPPER_PATH := "res://assets/environment/custom/d1_prior_ruins.gltf"
const WATCHDOG_SECONDS := 60.0
const TAVERN_SCENE_PATH := "res://scenes/MainTavern.tscn"
const TAVERN_COLLIDERS_FIXTURE := "res://test/fixtures/tavern_colliders.json"
const ARCH_PATH := "SubViewportContainer/SubViewport/TavernNavigation/Architecture/"
const SHELL_KIT := ["b9_floor", "b9_wall_full", "b9_wall_window", "b9_wall_doorway", "b9_wall_low",
	"b9_post_full", "b9_post_low", "b9_beam", "b10_door_frame", "b10_door_leaf"]
# New colliders added by Story 25.3 (world AABB [x, y, z] ranges): the south-wall gap either side
# of the front door, and the two back corner holes Raphael asked to close (2026-09-24).
const SHELL_NEW_COLLIDERS := {
	"Shell/NearWalls/GapColliderWest/CollisionShape3D": [[6.73, 8.4], [0.0, 4.0], [4.33, 4.63]],
	"Shell/NearWalls/GapColliderEast/CollisionShape3D": [[10.8, 14.84], [0.0, 4.0], [4.33, 4.63]],
	"Shell/FarWalls/CornerCollider/CollisionShape3D": [[-5.15, -4.85], [0.0, 4.0], [-19.17, -16.66]],
	"Shell/NearWalls/CornerColliderEast/CollisionShape3D": [[14.84, 15.14], [0.0, 4.0], [-19.17, -16.59]],
}
# Story 25.8: the Guild Tavern outside (A1), its hex miniature (A2) and the home marker (C9).
const A1_PATH := "res://assets/environment/custom/a1_guild_tavern.gltf"
const A2_PATH := "res://assets/environment/custom/a2_guild_tavern_mini.gltf"
const C9_PATH := "res://assets/environment/custom/c9_home_marker.gltf"
const OLD_TAVERN_PATH := "res://assets/environment/hexagons/blue/building_tavern_blue.gltf"
const EXTERIOR_SCENE_PATH := "res://scenes/world/ExteriorWorld.tscn"
const EXIT_ZONE_SCRIPT_PATH := "res://scripts/world/exit_zone_interior.gd"
const EDGE_SHADER_PATH := "res://assets/shaders/edge_detection.gdshader"
const PLAYER_RADIUS := 0.5   # Player.tscn CapsuleShape3D radius
# Story 25.29: the exterior terrain (hill, path, stream), bridge, village and forest.
const TERRAIN_PATH := "res://assets/environment/custom/a6_exterior_terrain.gltf"
const BRIDGE_PATH := "res://assets/environment/custom/a6_bridge.gltf"
const HEIGHTFIELD_FIXTURE := "res://test/fixtures/exterior_heightfield.json"
const SEATED_GROUPS := ["Village/", "Yard/", "Forest/", "Scatter/", "Props/"]
const SEATED_ROOT_NODES := ["GuildTavern", "barrel2", "candle_thin_lit_obj", "candle_thin_lit_obj (1)"]

var _pass_count := 0
var _fail_count := 0
var _elapsed := 0.0


func _initialize() -> void:
	print("\n========== FAILSAFE TESTS ==========\n")

	test_save_load_round_trip()
	test_loot_rng_distribution()
	test_mission_success_formula()
	test_adventurer_status_transitions()
	test_asset_path_integrity()
	test_ruin_reservation()
	test_tavern_shell()
	test_tavern_exterior()
	test_exterior_world()

	print("\n====================================")
	print("PASSED: %d  |  FAILED: %d" % [_pass_count, _fail_count])
	if _fail_count > 0:
		print("*** SOME TESTS FAILED ***")
	else:
		print("All tests passed.")
	print("====================================\n")
	quit()


func _process(delta: float) -> bool:
	_elapsed += delta
	if _elapsed > WATCHDOG_SECONDS:
		print("*** WATCHDOG: suite did not finish within %d s — aborting ***" % int(WATCHDOG_SECONDS))
		return true
	return false


func check(condition: bool, label: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % label)
	else:
		_fail_count += 1
		print("  FAIL: %s" % label)


# --- Mirror of GameManager.roll_loot() for isolated testing ---
static func _roll_loot() -> String:
	var roll = randf()
	if roll < 0.05:
		return "artifact"
	elif roll < 0.25:
		return "equipment"
	else:
		return "gold"


# --- Mirror of GameManager.calculate_mission_success_chance() core formula ---
static func _calc_mission_chance(adventurer: Dictionary, mission: Dictionary) -> int:
	var base_chance = 50
	var success_factors = mission.get("success_factors", ["strength"])
	var stat_bonus = 0
	for factor in success_factors:
		match factor:
			"strength": stat_bonus += adventurer.get("strength", 0) * 3
			"dexterity": stat_bonus += adventurer.get("dexterity", 0) * 3
			"intelligence": stat_bonus += adventurer.get("intelligence", 0) * 3
			"endurance": stat_bonus += adventurer.get("endurance", 0) * 2
	var experience_bonus = adventurer.get("missions_completed", 0) * 2
	var danger_penalty = mission.get("danger", 1) * 8
	var final_chance = base_chance + stat_bonus + experience_bonus - danger_penalty
	return clampi(final_chance, 10, 95)


# --- Test 1: Save/Load Round-Trip ---
func test_save_load_round_trip() -> void:
	print("[Test 1] Save/Load Round-Trip")
	var test_data := {
		"current_day": 5,
		"gold": 1234,
		"beer_stock": 3,
		"adventurers": [{"name": "TestHero", "class": "Fighter"}],
		"flag": true,
		"ratio": 0.75,
		"nested": {"a": 1, "b": [2, 3]},
		"schema_version": 1,
	}

	var json_string = JSON.stringify(test_data, "\t")
	var json = JSON.new()
	var err = json.parse(json_string)
	check(err == OK, "JSON parse succeeds")

	var parsed: Dictionary = json.data
	check(int(parsed["current_day"]) == 5, "current_day == 5")
	check(int(parsed["gold"]) == 1234, "gold == 1234")
	check(int(parsed["beer_stock"]) == 3, "beer_stock == 3")
	check(parsed["flag"] == true, "flag is true")
	check(absf(parsed["ratio"] - 0.75) < 0.001, "ratio ~= 0.75")
	check(int(parsed["schema_version"]) == 1, "schema_version == 1")
	check(parsed["nested"] is Dictionary, "nested is Dictionary")
	check(parsed["adventurers"] is Array, "adventurers is Array")
	check((parsed["adventurers"] as Array).size() == 1, "adventurers has 1 entry")
	print("")


# --- Test 2: Loot RNG Distribution ---
func test_loot_rng_distribution() -> void:
	print("[Test 2] Loot RNG Distribution")
	var counts := {"gold": 0, "equipment": 0, "artifact": 0}
	var total := 1000

	for i in total:
		var result = _roll_loot()
		if counts.has(result):
			counts[result] += 1
		else:
			check(false, "roll_loot returned unknown category: %s" % result)

	var sum = counts["gold"] + counts["equipment"] + counts["artifact"]
	check(sum == total, "all %d rolls accounted for" % total)
	check(counts["gold"] >= 600 and counts["gold"] <= 850, "gold in [600, 850]: %d" % counts["gold"])
	check(counts["equipment"] >= 100 and counts["equipment"] <= 350, "equipment in [100, 350]: %d" % counts["equipment"])
	check(counts["artifact"] >= 5 and counts["artifact"] <= 120, "artifact in [5, 120]: %d" % counts["artifact"])
	print("")


# --- Test 3: Mission Success Formula ---
func test_mission_success_formula() -> void:
	print("[Test 3] Mission Success Formula (core formula, no trait modifiers)")

	var zero_adv := {"strength": 0, "dexterity": 0, "intelligence": 0, "endurance": 0, "missions_completed": 0}
	var zero_mission := {"success_factors": ["strength"], "danger": 0}
	var result_zero = _calc_mission_chance(zero_adv, zero_mission)
	check(result_zero == 50, "zero stats / zero danger => 50: got %d" % result_zero)

	var high_adv := {"strength": 10, "dexterity": 10, "intelligence": 10, "endurance": 10, "missions_completed": 20}
	var easy_mission := {"success_factors": ["strength", "dexterity"], "danger": 1}
	var result_high = _calc_mission_chance(high_adv, easy_mission)
	check(result_high == 95, "high stats / easy => capped 95: got %d" % result_high)

	var low_adv := {"strength": 1, "dexterity": 1, "intelligence": 1, "endurance": 1, "missions_completed": 0}
	var hard_mission := {"success_factors": ["strength"], "danger": 8}
	var result_low = _calc_mission_chance(low_adv, hard_mission)
	check(result_low == 10, "low stats / hard => capped 10: got %d" % result_low)
	print("")


# --- Test 4: AdventurerStatus Transitions ---
func test_adventurer_status_transitions() -> void:
	print("[Test 4] AdventurerStatus Transitions")

	check(AdventurerStatus.can_transition(AdventurerStatus.Status.READY, AdventurerStatus.Status.ON_MISSION), "READY -> ON_MISSION allowed")
	check(AdventurerStatus.can_transition(AdventurerStatus.Status.ON_MISSION, AdventurerStatus.Status.RESTING), "ON_MISSION -> RESTING allowed")
	check(AdventurerStatus.can_transition(AdventurerStatus.Status.ON_MISSION, AdventurerStatus.Status.DEAD), "ON_MISSION -> DEAD allowed")
	check(AdventurerStatus.can_transition(AdventurerStatus.Status.RESTING, AdventurerStatus.Status.READY), "RESTING -> READY allowed")
	check(AdventurerStatus.can_transition(AdventurerStatus.Status.WOUNDED, AdventurerStatus.Status.RESTING), "WOUNDED -> RESTING allowed")
	check(AdventurerStatus.can_transition(AdventurerStatus.Status.WOUNDED, AdventurerStatus.Status.DEAD), "WOUNDED -> DEAD allowed")

	check(not AdventurerStatus.can_transition(AdventurerStatus.Status.DEAD, AdventurerStatus.Status.READY), "DEAD -> READY blocked")
	check(not AdventurerStatus.can_transition(AdventurerStatus.Status.DEAD, AdventurerStatus.Status.RESTING), "DEAD -> RESTING blocked")
	check(AdventurerStatus.is_terminal(AdventurerStatus.Status.DEAD), "DEAD is terminal")
	check(not AdventurerStatus.is_terminal(AdventurerStatus.Status.READY), "READY is not terminal")
	print("")


# --- Test 5: Asset-Path Integrity (Epic 25 / Story 25.1) ---
# Every res:// string in data/**/*.json must exist on disk, unless allowlisted with a
# reason and an owner. Exact-path and invalid-JSON entries are stale-guarded: once the
# gap is fixed the test fails until the owning story removes its allowlist entry.
func test_asset_path_integrity() -> void:
	print("[Test 5] Asset-Path Integrity (data/*.json -> files on disk)")

	var allow = _read_json(ASSET_ALLOWLIST_PATH)
	var allow_ok: bool = allow is Dictionary and int(allow.get("schema_version", 0)) == 1
	check(allow_ok, "allowlist parses, schema_version == 1")
	if not allow_ok:
		print("")
		return

	var missing_paths: Array = allow.get("missing_paths", [])
	var missing_prefixes: Array = allow.get("missing_prefixes", [])
	var known_invalid: Array = allow.get("known_invalid_json", [])
	var allow_entries: Array = missing_paths + missing_prefixes + known_invalid
	var documented := allow_entries.all(func(e): return str(e.get("reason", "")) != "" and str(e.get("owner", "")) != "")
	check(documented, "every allowlist entry has a reason and an owner (%d entries)" % allow_entries.size())

	var exact_missing: Array = missing_paths.map(func(e): return str(e.get("path", "")))
	var prefixes: Array = missing_prefixes.map(func(e): return str(e.get("prefix", "")))
	var invalid_files: Array = known_invalid.map(func(e): return str(e.get("file", "")))

	var json_files: Array[String] = []
	_collect_json_files("res://data", json_files)
	var refs: Array[String] = []
	var parse_failures: Array[String] = []
	for file_path in json_files:
		var parsed = _read_json(file_path)
		if parsed == null:
			parse_failures.append(file_path)
		else:
			_collect_res_strings(parsed, refs)

	var unexpected_invalid: Array = parse_failures.filter(func(p): return not invalid_files.has(p))
	check(json_files.size() > 0 and unexpected_invalid.is_empty(),
		"%d data JSON files parse or are known-invalid; unexpected parse failures: %s" % [json_files.size(), unexpected_invalid])
	for invalid_file in invalid_files:
		check(parse_failures.has(invalid_file), "known-invalid JSON still fails to parse (else remove it from the allowlist): %s" % invalid_file)

	var found := 0
	var allowlisted := 0
	var unexpected_missing: Array[String] = []
	for ref in refs:
		if _res_exists(ref):
			found += 1
		elif exact_missing.has(ref) or prefixes.any(func(pre): return ref.begins_with(pre)):
			allowlisted += 1
		else:
			unexpected_missing.append(ref)
	check(unexpected_missing.is_empty(), "%d res:// refs: %d found, %d allowlisted, %d missing %s" % [
		refs.size(), found, allowlisted, unexpected_missing.size(), unexpected_missing.slice(0, 5)])
	for path in exact_missing:
		check(not _res_exists(path), "allowlisted path still missing (else remove it from the allowlist): %s" % path)
	print("")


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return json.data


static func _collect_json_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect_json_files(dir_path.path_join(sub), out)
	for file_name in dir.get_files():
		if file_name.get_extension() == "json":
			out.append(dir_path.path_join(file_name))


static func _collect_res_strings(value: Variant, out: Array[String]) -> void:
	if value is Dictionary:
		for v in value.values():
			_collect_res_strings(v, out)
	elif value is Array:
		for v in value:
			_collect_res_strings(v, out)
	elif value is String and value.begins_with("res://"):
		out.append(value)


static func _res_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


# --- Test 6: Ruin Reservation, Mission Exclusion, World-Gen Drift Guard (Story 25.2) ---
# One land hex next to the tavern becomes the Prior Ruins (Story 6.2), picked from the seed
# without drawing from the RNG, so every other hex must match the pre-change baseline fixture.
func test_ruin_reservation() -> void:
	print("[Test 6] Ruin reservation + mission exclusion + world-gen drift guard")
	var gen_script = load("res://scripts/world/HexMapGenerator.gd")
	var wm_script = load("res://systems/WorldManager.gd")
	check(gen_script != null and wm_script != null, "HexMapGenerator.gd and WorldManager.gd load")
	if gen_script == null or wm_script == null:
		print("")
		return
	check(ResourceLoader.exists(RUIN_TOPPER_PATH), "D1 topper exists: %s" % RUIN_TOPPER_PATH)
	var has_eligible: bool = wm_script.get_script_method_list().any(func(m): return m.name == "is_mission_eligible")
	check(has_eligible, "WorldManager.is_mission_eligible() exists")

	for seed_value in [1, 12345, 987654]:
		var gen = gen_script.new()
		var recs := _generate_world(gen, seed_value)
		var ruins := recs.filter(func(r): return r.get("is_ruin", false))
		check(ruins.size() == 1, "seed %d: exactly one ruin hex (got %d)" % [seed_value, ruins.size()])
		if ruins.size() == 1:
			var ruin: Dictionary = ruins[0]
			check(gen._hex_distance(ruin.coord, Vector2i.ZERO) == 1 and ruin.biome != "sea" and not ruin.is_zone,
				"seed %d: ruin %s is a land hex next to the tavern (biome %s)" % [seed_value, ruin.id, ruin.biome])
			check(ruin.topper_paths == [RUIN_TOPPER_PATH] and ruin.get("ruin_discovered", true) == false,
				"seed %d: ruin uses the D1 topper and starts undiscovered" % seed_value)
			var again := _generate_world(gen, seed_value)
			var again_ruins := again.filter(func(r): return r.get("is_ruin", false))
			check(again_ruins.size() == 1 and again_ruins[0].id == ruin.id, "seed %d: same seed -> same ruin hex" % seed_value)
			if has_eligible:
				var land_neighbour = null
				var sea_hex = null
				for r in recs:
					if sea_hex == null and r.biome == "sea":
						sea_hex = r
					if land_neighbour == null and not r.get("is_ruin", false) and not r.is_center \
							and r.biome != "sea" and gen._hex_distance(r.coord, Vector2i.ZERO) == 1:
						land_neighbour = r
				check(not wm_script.is_mission_eligible(ruin), "seed %d: ruin hex is not mission-eligible" % seed_value)
				check(land_neighbour == null or wm_script.is_mission_eligible(land_neighbour),
					"seed %d: an ordinary land hex next to the tavern stays eligible" % seed_value)
				check(sea_hex == null or not wm_script.is_mission_eligible(sea_hex), "seed %d: sea stays ineligible" % seed_value)
		if seed_value == 12345:
			_check_worldgen_drift(recs)
		gen.free()
	print("")


func _generate_world(gen: Node, seed_value: int) -> Array:
	gen.randomize_seed_on_generate = false
	gen.map_seed = seed_value
	gen._generate_records()
	return gen._records.duplicate(true)


# Every record must match the baseline fixture captured before Story 25.2 changed the
# generator; the ruin hex (25.2) and the tavern hex (25.8) may differ only in their toppers.
func _check_worldgen_drift(recs: Array) -> void:
	var fixture = _read_json(WORLDGEN_FIXTURE_PATH)
	if not fixture is Dictionary:
		check(false, "world-gen fixture readable: %s" % WORLDGEN_FIXTURE_PATH)
		return
	var expected: Dictionary = fixture.get("records", {})
	var mismatches: Array = []
	for rec in recs:
		var row = expected.get(rec.id)
		if row == null:
			mismatches.append(rec.id + " (missing from fixture)")
			continue
		var actual := [rec.biome, rec.base_path, rec.topper_paths, rec.is_zone, rec.get("zone_building", "")]
		if rec.get("is_ruin", false) or rec.get("is_center", false):
			actual[2] = row[2]   # the ruin's and the tavern hex's toppers are the intended changes
		if actual != row:
			mismatches.append(rec.id)
	check(recs.size() == int(fixture.get("record_count", -1)) and mismatches.is_empty(),
		"seed 12345: %d records match the pre-change baseline; mismatches: %s" % [recs.size(), mismatches.slice(0, 5)])
	var centre := recs.filter(func(r): return r.get("is_center", false))
	check(centre.size() == 1 and centre[0].topper_paths == [A2_PATH, C9_PATH],
		"seed 12345: the tavern hex carries the A2 miniature + C9 home marker (%s)" % [centre[0].topper_paths if centre.size() == 1 else "no centre"])


# --- Test 7: Tavern Shell (Story 25.3) ---
# Reads MainTavern.tscn through SceneState (no instancing, so no gameplay scripts run):
# the seven original architecture colliders must be unchanged (the navmesh is baked from
# static colliders), the new shell colliders must exist where the story puts them, and the
# B9/B10 kit files must exist.
func test_tavern_shell() -> void:
	print("[Test 7] Tavern shell: kit files, original colliders unchanged, new colliders placed")
	for id in SHELL_KIT:
		check(ResourceLoader.exists("res://assets/environment/custom/%s.gltf" % id), "kit piece exists: %s" % id)

	var aabbs := _scene_box_collider_aabbs(TAVERN_SCENE_PATH)
	var fixture = _read_json(TAVERN_COLLIDERS_FIXTURE)
	if not fixture is Dictionary:
		check(false, "tavern collider fixture readable")
		print("")
		return
	var expected: Dictionary = fixture.get("colliders", {})
	for name in expected:
		var key: String = ARCH_PATH + name + "/StaticBody3D/CollisionShape3D"
		check(aabbs.has(key) and _aabb_close(aabbs[key], expected[name]),
			"original collider unchanged: %s %s" % [name, aabbs.get(key, "MISSING")])
	for rel in SHELL_NEW_COLLIDERS:
		var key: String = ARCH_PATH + rel
		check(aabbs.has(key) and _aabb_close(aabbs[key], SHELL_NEW_COLLIDERS[rel]),
			"new shell collider in place: %s %s" % [rel.get_slice("/", 2), aabbs.get(key, "MISSING")])
	print("")


## World-space AABB ([x, y, z] ranges) of every BoxShape3D CollisionShape3D in a scene file,
## computed from SceneState transforms without instancing the scene.
static func _scene_box_collider_aabbs(scene_path: String) -> Dictionary:
	var state: SceneState = (load(scene_path) as PackedScene).get_state()
	var local := {}    # node path -> Transform3D
	var parents := {}  # node path -> parent path
	var shapes := {}   # node path -> BoxShape3D
	for i in state.get_node_count():
		var path := str(state.get_node_path(i)).trim_prefix("./")
		parents[path] = str(state.get_node_path(i, true)).trim_prefix("./")
		var tf := Transform3D.IDENTITY
		for p in state.get_node_property_count(i):
			var prop := state.get_node_property_name(i, p)
			if prop == "transform":
				tf = state.get_node_property_value(i, p)
			elif prop == "shape" and state.get_node_property_value(i, p) is BoxShape3D:
				shapes[path] = state.get_node_property_value(i, p)
		local[path] = tf
	var out := {}
	for path in shapes:
		var world := Transform3D.IDENTITY
		var cur: String = path
		while cur != "" and cur != "." and local.has(cur):
			world = local[cur] * world
			cur = parents[cur]
		var half: Vector3 = shapes[path].size * 0.5
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				for sz in [-1, 1]:
					var pt: Vector3 = world * Vector3(sx * half.x, sy * half.y, sz * half.z)
					lo = lo.min(pt)
					hi = hi.max(pt)
		out[path] = [[lo.x, hi.x], [lo.y, hi.y], [lo.z, hi.z]]
	return out


static func _aabb_close(a: Array, b: Array, tol := 0.011) -> bool:
	for axis in 3:
		for end in 2:
			if absf(float(a[axis][end]) - float(b[axis][end])) > tol:
				return false
	return true


# --- Test 8: Guild Tavern exterior + map miniature (Story 25.8) ---
# Map: the tavern hex carries A2 + C9, also for old saves (display mode). Exterior (SceneState only,
# nothing instanced): A1 replaces the stock tavern, the entrance zone and the "Press E" label sit at
# A1's door, the player arriving from the tavern lands in front of the door (outside the zone and
# outside A1's collision), and the exterior camera has the ink-outline quad (decision D2).
func test_tavern_exterior() -> void:
	print("[Test 8] Guild Tavern exterior (A1), map miniature (A2), home marker (C9)")
	for p in [A1_PATH, A2_PATH, C9_PATH]:
		check(ResourceLoader.exists(p), "asset exists: %s" % p.get_file())

	var gen_script = load("res://scripts/world/HexMapGenerator.gd")
	var consts: Dictionary = gen_script.get_script_constant_map() if gen_script else {}
	check(consts.get("TAVERN_TOPPER") == A2_PATH and consts.get("HOME_MARKER") == C9_PATH,
		"HexMapGenerator: TAVERN_TOPPER = A2, HOME_MARKER = C9")
	var has_helper: bool = gen_script != null and gen_script.get_script_method_list().any(
		func(m): return m.name == "home_toppers_for")
	check(has_helper, "HexMapGenerator.home_toppers_for() exists")
	if has_helper:
		var old_save := {"is_center": true, "topper_paths": [OLD_TAVERN_PATH]}
		var other := {"is_center": false, "topper_paths": ["res://assets/x.gltf"]}
		check(gen_script.home_toppers_for(old_save) == [A2_PATH, C9_PATH], "old save: the tavern hex renders A2 + C9")
		check(gen_script.home_toppers_for(other) == ["res://assets/x.gltf"], "old save: other hexes render what they stored")

	var ext := _scene_nodes(EXTERIOR_SCENE_PATH)
	check(not ext.values().any(func(n): return n.instance == OLD_TAVERN_PATH),
		"ExteriorWorld no longer instances building_tavern_blue")
	var a1_keys := ext.keys().filter(func(k): return ext[k].instance == A1_PATH)
	check(a1_keys.size() == 1, "ExteriorWorld instances A1 once %s" % [a1_keys])
	if a1_keys.size() != 1:
		print("")
		return
	var a1_xf: Transform3D = ext[a1_keys[0]].world
	var a1 := _scene_nodes(A1_PATH)
	var door := Vector3.INF
	var a1_boxes: Array = []   # world-space [[x0, x1], [z0, z1]] of A1's collision proxies
	for k in a1:
		if str(k).ends_with("interact_point"):
			door = a1_xf * (a1[k].world as Transform3D).origin
		var shape = a1[k].props.get("shape")
		if shape is ConvexPolygonShape3D:
			var lo := Vector3(INF, INF, INF)
			var hi := Vector3(-INF, -INF, -INF)
			for pt in (shape as ConvexPolygonShape3D).points:
				var w: Vector3 = a1_xf * ((a1[k].world as Transform3D) * pt)
				lo = lo.min(w)
				hi = hi.max(w)
			a1_boxes.append([[lo.x, hi.x], [lo.z, hi.z]])
	check(door != Vector3.INF, "A1 has its interact_point marker (door) %s" % [door])
	check(a1_boxes.size() >= 3, "A1 imports its collision proxies (%d convex shapes)" % a1_boxes.size())
	if door == Vector3.INF:
		print("")
		return

	var tavern := _scene_nodes(TAVERN_SCENE_PATH)
	var spawn = null
	for k in tavern:
		if str(k).ends_with("Interactive/ExitArea"):
			spawn = tavern[k].props.get("exterior_spawn_position")
	if spawn == null:
		spawn = load(EXIT_ZONE_SCRIPT_PATH).get_property_default_value("exterior_spawn_position")
	var s2 := Vector2(spawn.x, spawn.z)
	var d2 := Vector2(door.x, door.z)
	check(s2.distance_to(d2) <= 3.0, "arrival spawn %s lands within 3 m of A1's door %s" % [spawn, door])
	check(not a1_boxes.any(func(b): return _circle_hits_rect(s2, PLAYER_RADIUS, b)),
		"arrival spawn is outside A1's collision")

	var zone_boxes := _scene_box_collider_aabbs(EXTERIOR_SCENE_PATH)
	var zone = zone_boxes.get("TavernEntranceZone/CollisionShape3D")
	check(zone != null, "TavernEntranceZone has a box shape")
	if zone != null:
		var zone_xz := [zone[0], zone[2]]
		check(_circle_hits_rect(d2, 0.6, zone_xz), "entrance zone sits at A1's door %s" % [zone_xz])
		check(not _circle_hits_rect(s2, PLAYER_RADIUS, zone_xz), "arriving player starts outside the entrance zone")

	var label = ext.get("TavernEntranceZone/InteractionPrompt")
	check(label != null and Vector2(label.world.origin.x, label.world.origin.z).distance_to(d2) <= 1.5,
		"'Press E' label floats at the door (D1) %s" % [label.world.origin if label else "missing"])
	# The full-screen ink quad (render_priority 0) repaints the screen from the opaque pass, so a
	# transparent Label3D must draw after it or it vanishes (seen in-scene, 2026-09-25).
	check(label != null and int(label.props.get("render_priority", 0)) > 0 and label.props.get("no_depth_test", false),
		"'Press E' label draws after the ink quad and through the wall")
	var has_edge := ext.keys().any(func(k): return str(k).begins_with("Camera3D/") and \
		_is_edge_material(ext[k].props.get("surface_material_override/0")))
	check(has_edge, "exterior camera has the ink-outline quad (D2)")
	print("")


## Every node of a scene file via SceneState (nothing instanced):
## path -> {world: Transform3D, instance: String, props: Dictionary}.
static func _scene_nodes(scene_path: String) -> Dictionary:
	var state: SceneState = (load(scene_path) as PackedScene).get_state()
	var nodes := {}
	var parents := {}
	for i in state.get_node_count():
		var path := str(state.get_node_path(i)).trim_prefix("./")
		parents[path] = str(state.get_node_path(i, true)).trim_prefix("./")
		var props := {}
		for p in state.get_node_property_count(i):
			props[state.get_node_property_name(i, p)] = state.get_node_property_value(i, p)
		var inst := state.get_node_instance(i)
		nodes[path] = {"local": props.get("transform", Transform3D.IDENTITY), "props": props,
			"instance": inst.resource_path if inst else ""}
	for path in nodes:
		var world := Transform3D.IDENTITY
		var cur: String = path
		while cur != "" and cur != "." and nodes.has(cur):
			world = nodes[cur].local * world
			cur = parents[cur]
		nodes[path]["world"] = world
	return nodes


static func _circle_hits_rect(c: Vector2, r: float, rect: Array) -> bool:
	var nearest := Vector2(clampf(c.x, rect[0][0], rect[0][1]), clampf(c.y, rect[1][0], rect[1][1]))
	return nearest.distance_to(c) < r


# --- Test 9: Exterior ground, forest and village (Story 25.29) ---
# The terrain is both the drawn and the walked ground (the old Ground box drew at y -0.11 but
# collided at +0.25, so everything floated). Every placed building, tree, rock and prop must sit on
# the terrain height (heightfield fixture exported with the terrain); trees stay off the path, the
# stream and the buildings; the bridge deck and the play-area bounds have collision.
func test_exterior_world() -> void:
	print("[Test 9] Exterior ground, forest and village")
	for p in [TERRAIN_PATH, BRIDGE_PATH]:
		check(ResourceLoader.exists(p), "asset exists: %s" % p.get_file())
	check(ResourceLoader.exists(TERRAIN_PATH) and _scene_has_shape(TERRAIN_PATH, "ConcavePolygonShape3D"),
		"terrain imports a trimesh collider")
	check(ResourceLoader.exists(BRIDGE_PATH) and _scene_has_shape(BRIDGE_PATH, "ConcavePolygonShape3D"),
		"bridge deck imports a trimesh collider")
	var hf = _read_json(HEIGHTFIELD_FIXTURE)
	if not hf is Dictionary:
		check(false, "heightfield fixture readable")
		print("")
		return
	var ext := _scene_nodes(EXTERIOR_SCENE_PATH)
	check(not ext.has("Ground"), "the old Ground box is gone")
	check(ext.values().any(func(n): return n.instance == TERRAIN_PATH), "ExteriorWorld instances the terrain")
	check(ext.values().any(func(n): return n.instance == BRIDGE_PATH), "ExteriorWorld instances the bridge")

	var floating := []
	var seated := 0
	var trees_bad := []
	var tree_count := 0
	var buildings := []
	for k in ext:
		var key := str(k)
		if key.begins_with("Village/") and key.count("/") == 1 and ext[k].instance.contains("/blue/"):
			buildings.append((ext[k].world as Transform3D).origin)
	for k in ext:
		var key := str(k)
		var n: Dictionary = ext[k]
		var grouped: bool = SEATED_GROUPS.any(func(g): return key.begins_with(g))
		var is_placed: bool = n.instance != "" or n.props.has("mesh")
		if not ((grouped and is_placed and key.count("/") <= 2) or key in SEATED_ROOT_NODES):
			continue
		var o: Vector3 = (n.world as Transform3D).origin
		var ground := _hf_height(hf, o.x, o.z)
		seated += 1
		# Floating is the bug (shadows detach); a little sinking is fine, and near the hill's creases
		# the bilinear fixture sits a touch above the true ground.
		if o.y - ground > 0.15 or ground - o.y > 0.35:
			floating.append("%s y=%.2f ground=%.2f" % [key, o.y, ground])
		if key.begins_with("Forest/"):
			tree_count += 1
			var on_path := _dist_to_polyline(Vector2(o.x, o.z), hf.path) < float(hf.path_half) + 0.3
			var in_stream := absf(o.x - _hf_stream_x(hf, o.z)) < float(hf.stream_half) + 0.3
			var in_building: bool = buildings.any(func(b): return Vector2(b.x, b.z).distance_to(Vector2(o.x, o.z)) < 2.5)
			if on_path or in_stream or in_building:
				trees_bad.append(key)
	check(seated >= 50 and floating.is_empty(),
		"%d placed nodes sit on the terrain (≤ 0.15 m above, ≤ 0.35 m sunk); off: %s" % [seated, floating.slice(0, 4)])
	check(tree_count >= 100, "the forest has %d trees and rocks" % tree_count)
	check(trees_bad.is_empty(), "no tree or rock on the path, stream or a building: %s" % [trees_bad.slice(0, 4)])
	check(buildings.size() >= 7, "the village has %d buildings" % buildings.size())
	var bounds := ext.keys().filter(func(k): return str(k).begins_with("Bounds/") and ext[k].props.get("shape") is BoxShape3D)
	check(ext.has("Bounds") and bounds.size() >= 4, "play-area bounds: %d walls" % bounds.size())
	print("")


static func _scene_has_shape(scene_path: String, shape_class: String) -> bool:
	var nodes := _scene_nodes(scene_path)
	return nodes.values().any(func(n): return n.props.get("shape") != null and n.props.get("shape").get_class() == shape_class)


static func _hf_height(hf: Dictionary, x: float, z: float) -> float:
	var step := float(hf.step)
	var fx := (x - float(hf.x0)) / step
	var fz := (z - float(hf.z0)) / step
	var i := clampi(int(floor(fx)), 0, int(hf.nx) - 2)
	var j := clampi(int(floor(fz)), 0, int(hf.nz) - 2)
	var tx := clampf(fx - i, 0.0, 1.0)
	var tz := clampf(fz - j, 0.0, 1.0)
	var H: Array = hf.heights
	var a := lerpf(float(H[j][i]), float(H[j][i + 1]), tx)
	var b := lerpf(float(H[j + 1][i]), float(H[j + 1][i + 1]), tx)
	return lerpf(a, b, tz)


static func _hf_stream_x(hf: Dictionary, z: float) -> float:
	var s: Array = hf.stream
	for k in s.size() - 1:
		if float(s[k][0]) <= z and z <= float(s[k + 1][0]):
			var t := (z - float(s[k][0])) / maxf(float(s[k + 1][0]) - float(s[k][0]), 0.0001)
			return lerpf(float(s[k][1]), float(s[k + 1][1]), t)
	return float(s[0][1]) if z < float(s[0][0]) else float(s[-1][1])


static func _dist_to_polyline(p: Vector2, pts: Array) -> float:
	var best := INF
	for k in pts.size() - 1:
		var a := Vector2(pts[k][0], pts[k][1])
		var b := Vector2(pts[k + 1][0], pts[k + 1][1])
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best


static func _is_edge_material(mat) -> bool:
	return mat is ShaderMaterial and (mat as ShaderMaterial).shader != null \
		and (mat as ShaderMaterial).shader.resource_path == EDGE_SHADER_PATH
