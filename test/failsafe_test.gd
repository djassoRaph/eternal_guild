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
# Story 25.4: the Hourglass Pillar (B6) at the centre of the round bar, with reveal stages.
const PILLAR_PATH := "res://assets/environment/custom/b6_hourglass_pillar.gltf"
const PILLAR_SCENE_PATH := "res://scenes/game/HourglassPillar.tscn"
const PILLAR_SCRIPT_PATH := "res://scripts/game/hourglass_pillar.gd"
const PILLAR_RING_CENTRE := Vector3(7.74, 0.1, -8.22)   # TavernCounterCircular origin, floor top
const GAME_CONFIG_PATH := "res://data/config/game_config.json"
const PILLAR_STAGES := {
	0: ["pillar_foundation", "pillar_base", "pillar_stub"],
	1: ["pillar_foundation", "pillar_base", "pillar_band_low"],
	2: ["pillar_foundation", "pillar_base", "pillar_band_low", "pillar_hourglass"],
	3: ["pillar_foundation", "pillar_base", "pillar_band_low", "pillar_hourglass", "pillar_band_high"],
	4: ["pillar_foundation", "pillar_base", "pillar_band_low", "pillar_hourglass", "pillar_band_high", "pillar_capital"],
}

const HEARTH_PATH := "res://assets/environment/custom/b1_hearth.gltf"
const FIREWOOD_LOG_PATH := "res://assets/environment/custom/h3_firewood_log.gltf"
const FIREWOOD_BUNDLE_PATH := "res://assets/environment/custom/h3_firewood_bundle.gltf"
const HEARTH_SCENE_PATH := "res://scenes/game/Hearth.tscn"
const HEARTH_SCRIPT_PATH := "res://scripts/game/hearth.gd"
const FIRE_ZONE_SCRIPT_PATH := "res://scenes/fireplace_zone.gd"
const MINIGAME_SCRIPT_PATH := "res://scenes/ui/script/FireplaceMinigamePanel.gd"
const HEARTH_SPOT := Vector3(-4.87, 0.1, -9.3)     # on the far wall's inner face, floor top
const HEARTH_APPROACH := Vector3(-2.5, 1.0, -9.3)  # where the player stands to tend the fire
const HEARTH_BLOCKED := Vector2(-3.6, -9.3)       # on the navmesh before 25.5; beside the chimney body after
                                                   # (the 0.2 m apron is under the agents' 0.25 m climb, so it stays walkable)
const HEARTH_OBJECTS := ["hearth_stone", "mantel", "mantel_props", "andirons", "ember_bed", "hearth_runes"]
const HEARTH_MARKERS := ["sit_point", "interact_point", "fire_point", "smoke_point", "onibi_point"]

const ROUND_BAR_PATH := "res://assets/environment/custom/b2_round_bar.gltf"
const BAR_STOOL_PATH := "res://assets/environment/custom/b2_bar_stool.gltf"
const BACK_BAR_PATH := "res://assets/environment/custom/b12_back_bar.gltf"
const TANKARD_FULL_PATH := "res://assets/environment/custom/h1_tankard_full.gltf"
const TANKARD_EMPTY_PATH := "res://assets/environment/custom/h1_tankard_empty.gltf"
const ROUND_BAR_SCENE_PATH := "res://scenes/game/RoundBar.tscn"
const BAR_STOOL_SCENE_PATH := "res://scenes/game/BarStool.tscn"
const SPAWNER_SCRIPT_PATH := "res://scripts/npcs/PatronSpawner.gd"
const PATRON_SCRIPT_PATH := "res://scripts/npcs/RealisticPatron.gd"
const OLD_BAR_NODES := ["Architecture/TavernCounterCircular", "Architecture/Keg", "Furniture/Bar/BarCounter",
	"Furniture/Stool2", "Furniture/Stool3", "Furniture/Stool4", "Furniture/Plate"]

const DESK_PATH := "res://assets/environment/custom/b3_guild_desk.gltf"
const BOARD_PATH := "res://assets/environment/custom/b4_mission_board.gltf"
const DESK_SCENE_PATH := "res://scenes/game/GuildDesk.tscn"
const NOTICE_SCENE_PATH := "res://scenes/game/GuildNoticeBoard.tscn"
const NOTICE_SCRIPT_PATH := "res://scripts/game/notice_board.gd"
const DESK_SPOT := Vector3(11.6, 0.1, -4.3)      # the guild desk's floor centre, facing +z (the room)
const BOARD_SPOT := Vector3(4.3, 0.1, -14.5)     # under the board on the partition's face, facing +z
const OLD_DESK_NODES := ["Furniture/Desk/MissionDesk", "Furniture/Chairs/Chair6", "Furniture/MissionBoard", "Environment/DeskLight"]

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
	test_hourglass_pillar()
	test_hearth()
	test_round_bar()
	test_desk_and_board()

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
			"instance": inst.resource_path if inst else "", "type": str(state.get_node_type(i)),
			"groups": Array(state.get_node_groups(i)).map(func(g): return str(g))}
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


# --- Test 10: The Hourglass Pillar (Story 25.4) ---
# Segments and glow materials in the asset, the stage -> segments mapping (pure static function),
# the demo stage in game_config.json, the placement at the round bar's centre, the collider and hum
# anchor in the pillar scene, and the re-baked navmesh routing around the pillar.
func test_hourglass_pillar() -> void:
	print("[Test 10] The Hourglass Pillar")
	var has_asset := ResourceLoader.exists(PILLAR_PATH)
	check(has_asset, "asset exists: %s" % PILLAR_PATH.get_file())
	var nodes := _scene_nodes(PILLAR_PATH) if has_asset else {}
	for seg in PILLAR_STAGES[4] + ["pillar_stub"]:
		check(nodes.keys().any(func(k): return str(k).ends_with(seg)), "segment present: %s" % seg)
	var wrong := []
	var glow := 0
	for k in nodes:
		var mesh = nodes[k].props.get("mesh")
		if not mesh is Mesh:
			continue
		for s in (mesh as Mesh).get_surface_count():
			var m := (mesh as Mesh).surface_get_material(s) as StandardMaterial3D
			if m == null:
				continue
			if m.emission_enabled:
				glow += 1
			if (m.emission_enabled and m.roughness != 0.0) or (not m.emission_enabled and m.roughness <= 0.0):
				wrong.append("%s/%s r=%.2f" % [str(k).get_file(), m.resource_name, m.roughness])
	check(glow >= 3 and wrong.is_empty(), "glow surfaces at roughness 0, the rest > 0 (%d glow; wrong: %s)" % [glow, wrong])

	var script = load(PILLAR_SCRIPT_PATH) if ResourceLoader.exists(PILLAR_SCRIPT_PATH) else null
	var has_map: bool = script != null and script.get_script_method_list().any(func(m): return m.name == "segments_for_stage")
	check(has_map, "hourglass_pillar.gd has segments_for_stage()")
	if has_map:
		for stage in PILLAR_STAGES:
			check(Array(script.segments_for_stage(stage)) == PILLAR_STAGES[stage], "stage %d shows %s" % [stage, PILLAR_STAGES[stage]])
		check(Array(script.segments_for_stage(-1)) == PILLAR_STAGES[0] and Array(script.segments_for_stage(99)) == PILLAR_STAGES[4],
			"out-of-range stages clamp to 0 and 4")
	var cfg = _read_json(GAME_CONFIG_PATH)
	var demo_stage = cfg.get("pillar_reveal_stage") if cfg is Dictionary else null
	check(demo_stage != null and int(demo_stage) >= 0 and int(demo_stage) <= 4, "game_config pillar_reveal_stage = %s" % [demo_stage])

	var tav := _scene_nodes(TAVERN_SCENE_PATH)
	var hits := tav.keys().filter(func(k): return tav[k].instance == PILLAR_SCENE_PATH)
	check(hits.size() == 1 and (tav[hits[0]].world as Transform3D).origin.distance_to(PILLAR_RING_CENTRE) < 0.05,
		"MainTavern has the pillar at the round bar's centre %s" % [hits])
	var ps := _scene_nodes(PILLAR_SCENE_PATH) if ResourceLoader.exists(PILLAR_SCENE_PATH) else {}
	check(ps.values().any(func(n): return n.props.get("shape") is CylinderShape3D), "pillar scene has a cylinder collider")
	check(ps.keys().any(func(k): return str(k).ends_with("HumAnchor")), "pillar scene has a HumAnchor for the hum (25.24)")
	var nav = null
	for k in tav:
		if str(k).ends_with("TavernNavigation"):
			nav = tav[k].props.get("navigation_mesh")
	# The on-mesh point is 4.3 m out: since Story 25.6 the round bar's counter covers r 2.4..3.1.
	check(nav is NavigationMesh and not _nav_contains(nav, PILLAR_RING_CENTRE.x, PILLAR_RING_CENTRE.z)
		and _nav_contains(nav, PILLAR_RING_CENTRE.x + 4.3, PILLAR_RING_CENTRE.z),
		"navmesh routes around the pillar (floor level: centre off, 4.3 m away on)")
	print("")



# --- Test 11: The Hearth and firewood (Story 25.5) ---
# B1 objects, markers and collision proxies; the tri budgets and the glow rule for B1 and H3; the fire
# look (pure static functions in hearth.gd, bands identical to fireplace_zone.gd); the Hearth scene
# (group, light, particles WITH draw passes, log pile, wood store, sit point); the zone and minigame
# wiring; and the hall: grey boxes gone, the hearth at its spot facing the room, the prompt zone
# reachable, the navmesh routed round the apron.
func test_hearth() -> void:
	print("[Test 11] The Hearth and firewood")
	for p in [HEARTH_PATH, FIREWOOD_LOG_PATH, FIREWOOD_BUNDLE_PATH]:
		check(ResourceLoader.exists(p), "asset exists: %s" % p.get_file())
	var nodes := _scene_nodes(HEARTH_PATH) if ResourceLoader.exists(HEARTH_PATH) else {}
	var names := nodes.keys().map(func(k): return str(k).get_file())
	var wanted: Array = HEARTH_OBJECTS + HEARTH_MARKERS
	for i in 5:
		wanted.append("log_slot_%d" % (i + 1))
	for i in 10:
		wanted.append("store_slot_%02d" % (i + 1))
	var missing := wanted.filter(func(n): return not n in names)
	check(not nodes.is_empty() and missing.is_empty(), "B1 objects and markers present (missing: %s)" % [missing])
	var convex := nodes.values().filter(func(n): return n.props.get("shape") is ConvexPolygonShape3D).size()
	check(convex >= 3, "B1 has %d convex collision proxies (body, apron, seat)" % convex)
	for spec in [[HEARTH_PATH, 5000, 3], [FIREWOOD_LOG_PATH, 300, 0], [FIREWOOD_BUNDLE_PATH, 300, 0]]:
		var st := _mesh_stats(spec[0]) if ResourceLoader.exists(spec[0]) else {"tris": 0, "glow": 0, "wrong": ["missing"]}
		check(st.tris > 0 and st.tris <= spec[1], "%s: %d tris (budget %d)" % [str(spec[0]).get_file(), st.tris, spec[1]])
		check(st.glow >= spec[2] and st.wrong.is_empty(),
			"%s: glow surfaces at roughness 0, the rest > 0 (%d glow; wrong: %s)" % [str(spec[0]).get_file(), st.glow, st.wrong])

	var hs = load(HEARTH_SCRIPT_PATH) if ResourceLoader.exists(HEARTH_SCRIPT_PATH) else null
	var has_look: bool = hs != null and hs.get_script_method_list().any(func(m): return m.name == "fire_look")
	check(has_look, "hearth.gd has fire_look()")
	if has_look:
		var zc: Dictionary = (load(FIRE_ZONE_SCRIPT_PATH) as Script).get_script_constant_map()
		var hi := float(zc.get("FUEL_HIGH_FLOOR", 50.0))
		var lo := float(zc.get("FUEL_LOW_FLOOR", 20.0))
		var bands := [[0.0, "out"], [0.5, "dying"], [lo, "dying"], [lo + 0.5, "low"], [hi, "low"], [hi + 0.5, "high"], [100.0, "high"]]
		for b in bands:
			check(hs.fire_look(b[0]).band == b[1], "fuel %.1f reads %s (zone floors %d / %d)" % [b[0], b[1], hi, lo])
		var o: Dictionary = hs.fire_look(0.0)
		check(o.light == 0.0 and o.flames == 0.0 and o.sparks == 0.0 and o.ember_glow == 0.0 and o.smoke == 0.0 and o.logs == 0,
			"out is dark: no light, flames, sparks, glow, smoke or logs %s" % [o])
		var d: Dictionary = hs.fire_look(10.0)
		var l: Dictionary = hs.fire_look(35.0)
		var h: Dictionary = hs.fire_look(80.0)
		for key in ["light", "flame_size", "flames", "ember_glow"]:
			check(h[key] > l[key] and l[key] > d[key] and d[key] > 0.0,
				"%s ranks high > low > dying > out (%.2f / %.2f / %.2f)" % [key, h[key], l[key], d[key]])
		check(d.smoke > h.smoke and h.smoke > 0.0, "a dying fire smoulders more than a high one (%.2f > %.2f)" % [d.smoke, h.smoke])
		check(d.logs == 1 and l.logs >= 2 and l.logs <= 3 and h.logs >= 3 and h.logs <= 5,
			"logs on the andirons: dying 1, low 2-3, high 3-5 (%d / %d / %d)" % [d.logs, l.logs, h.logs])
		check(hs.logs_shown(0.0, 0) == 0 and hs.logs_shown(0.0, 2) == 2 and hs.logs_shown(10.0, 0) == 1 and hs.logs_shown(80.0, 4) == 5,
			"logs_shown adds the placed logs to the burning ones, capped at 5")
		check(hs.store_shown(-3) == 0 and hs.store_shown(0) == 0 and hs.store_shown(4) == 4 and hs.store_shown(25) == 10,
			"store_shown shows one log per unit of stock, 0..10")

	var hsn := _scene_nodes(HEARTH_SCENE_PATH) if ResourceLoader.exists(HEARTH_SCENE_PATH) else {}
	var hstate: SceneState = (load(HEARTH_SCENE_PATH) as PackedScene).get_state() if not hsn.is_empty() else null
	check(hstate != null and "hearth" in Array(hstate.get_node_groups(0)), "Hearth.tscn root is in group 'hearth'")
	check(hsn.values().any(func(n): return n.instance == HEARTH_PATH), "Hearth.tscn instances the B1 model")
	check(hsn.has("FireLight") and hsn.FireLight.type == "OmniLight3D", "Hearth.tscn has the FireLight")
	for pn in ["FireParticles", "Embers", "Smoke"]:
		check(hsn.has(pn) and hsn[pn].type == "GPUParticles3D" and hsn[pn].props.get("draw_pass_1") is Mesh
			and hsn[pn].props.get("process_material") is ParticleProcessMaterial,
			"%s is a GPUParticles3D with a draw pass and a process material" % pn)
	var pile := hsn.keys().filter(func(k): return str(k).begins_with("LogPile/") and hsn[k].instance == FIREWOOD_LOG_PATH)
	var store := hsn.keys().filter(func(k): return str(k).begins_with("WoodStore/") and hsn[k].instance == FIREWOOD_LOG_PATH)
	check(pile.size() == 5 and store.size() == 10, "LogPile has %d H3 logs (5), WoodStore %d (10)" % [pile.size(), store.size()])
	check(hsn.has("SitPoint") and hsn.SitPoint.type == "Marker3D", "Hearth.tscn reserves a SitPoint for Den Fa (25.10)")

	var mg = load(MINIGAME_SCRIPT_PATH) as Script
	check(mg != null and mg.get_script_signal_list().any(func(sg): return sg.name == "log_placed"),
		"FireplaceMinigamePanel has signal log_placed")
	var zsrc := (load(FIRE_ZONE_SCRIPT_PATH) as GDScript).source_code
	check(zsrc.contains('get_first_node_in_group("hearth")') and not zsrc.contains("../../../Furniture"),
		"fireplace_zone.gd finds the hearth by group (the old ../../../Furniture path resolved to null)")

	var tav := _scene_nodes(TAVERN_SCENE_PATH)
	var boxes := tav.keys().filter(func(k): return str(k).get_file() in ["FireplaceBack", "FireplaceBase", "Mantel"])
	check(boxes.is_empty(), "the fireplace grey boxes are gone %s" % [boxes])
	var hits := tav.keys().filter(func(k): return tav[k].instance == HEARTH_SCENE_PATH)
	var placed: bool = hits.size() == 1 and (tav[hits[0]].world as Transform3D).origin.distance_to(HEARTH_SPOT) < 0.05
	var facing: bool = hits.size() == 1 and (tav[hits[0]].world as Transform3D).basis.z.normalized().dot(Vector3.RIGHT) > 0.99
	check(placed and facing, "MainTavern has one hearth at %s facing +x into the room %s" % [HEARTH_SPOT, hits])
	var w5 := tav.keys().filter(func(k): return str(k).ends_with("FarWalls/West_5"))
	check(w5.size() == 1 and str(tav[w5[0]].instance).ends_with("b9_wall_full.gltf"), "West_5 behind the chimney is a full wall panel")
	var zone_box := AABB()
	for k in tav:
		if str(k).ends_with("Interactive/FireplaceArea/CollisionShape3D") and tav[k].props.get("shape") is BoxShape3D:
			var size: Vector3 = (tav[k].props.shape as BoxShape3D).size
			zone_box = (tav[k].world as Transform3D) * AABB(-size / 2, size)
	var nav = null
	for k in tav:
		if str(k).ends_with("TavernNavigation"):
			nav = tav[k].props.get("navigation_mesh")
	check(zone_box.has_point(HEARTH_APPROACH) and nav is NavigationMesh and _nav_contains(nav, HEARTH_APPROACH.x, HEARTH_APPROACH.z),
		"the Tend Fire zone %s covers a reachable spot in front of the apron" % [zone_box])
	check(nav is NavigationMesh and not _nav_contains(nav, HEARTH_BLOCKED.x, HEARTH_BLOCKED.y),
		"navmesh routes round the hearth's chimney body (%s is off the mesh)" % [HEARTH_BLOCKED])
	print("")


## Tri count and the ink/glow rule over every mesh in a scene file: emissive surfaces at roughness 0,
## everything else above 0.
static func _mesh_stats(scene_path: String) -> Dictionary:
	var tris := 0
	var glow := 0
	var wrong := []
	var nodes := _scene_nodes(scene_path)
	for k in nodes:
		var mesh = nodes[k].props.get("mesh")
		if not mesh is Mesh:
			continue
		for s in (mesh as Mesh).get_surface_count():
			tris += ((mesh as Mesh).surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			var m := (mesh as Mesh).surface_get_material(s) as StandardMaterial3D
			if m == null:
				continue
			if m.emission_enabled:
				glow += 1
			if (m.emission_enabled and m.roughness != 0.0) or (not m.emission_enabled and m.roughness <= 0.0):
				wrong.append("%s/%s r=%.2f" % [str(k).get_file(), m.resource_name, m.roughness])
	return {"tris": tris, "glow": glow, "wrong": wrong}


# --- Test 12: The Round Bar and drinks service (Story 25.6) ---
# B2 ring, bar stool, B12 back-bar island and H1 tankards (budgets, glow rule, objects, markers,
# trimesh colliders, the walkway between island and counter); the BarStool / RoundBar scenes (seat
# group, 12 stools facing the centre, serve points); seats from the scene (PatronSpawner.build_seats,
# RealisticPatron.seat_root, the tankard props); and the hall: old bar pieces gone, the bar at the
# pillar, navmesh round the counter with every stool reachable.
func test_round_bar() -> void:
	print("[Test 12] The Round Bar and drinks service")
	for spec in [[ROUND_BAR_PATH, 6000, 1], [BAR_STOOL_PATH, 150, 0], [BACK_BAR_PATH, 3000, 0],
			[TANKARD_FULL_PATH, 300, 0], [TANKARD_EMPTY_PATH, 300, 0]]:
		var ok := ResourceLoader.exists(spec[0])
		check(ok, "asset exists: %s" % str(spec[0]).get_file())
		var st := _mesh_stats(spec[0]) if ok else {"tris": 0, "glow": 0, "wrong": ["missing"]}
		check(st.tris > 0 and st.tris <= spec[1] and st.glow >= spec[2] and st.wrong.is_empty(),
			"%s: %d tris (budget %d), glow rule (%d glow; wrong: %s)" % [str(spec[0]).get_file(), st.tris, spec[1], st.glow, st.wrong])
	var bar := _scene_nodes(ROUND_BAR_PATH) if ResourceLoader.exists(ROUND_BAR_PATH) else {}
	var bar_names := bar.keys().map(func(k): return str(k).get_file())
	var want := ["bar_ring", "bar_flap", "bar_runes", "foot_rail", "flap_point"]
	for i in 5:
		want.append("serve_point_%02d" % (i + 1))
	check(not bar.is_empty() and want.all(func(n): return n in bar_names), "B2 objects and markers present")
	var island := _scene_nodes(BACK_BAR_PATH) if ResourceLoader.exists(BACK_BAR_PATH) else {}
	var island_names := island.keys().map(func(k): return str(k).get_file())
	check(not island.is_empty() and ["back_shelf", "keg_rack", "keg_beer", "keg_mead", "work_point", "tap_beer", "tap_mead"].all(
		func(n): return n in island_names), "B12 island objects (shelf, rack, beer and mead kegs) and markers present")
	var counter_in := _shape_radius(bar, true)
	var island_out := _shape_radius(island, false)
	check(counter_in > 0.0 and island_out > 0.0 and counter_in - island_out >= 1.0,
		"trimesh colliders; the Bartender's walkway is %.2f m (counter r %.2f - island r %.2f, need >= 1.0)" % [counter_in - island_out, counter_in, island_out])
	var stool := _scene_nodes(BAR_STOOL_PATH) if ResourceLoader.exists(BAR_STOOL_PATH) else {}
	var seat_y := -1.0
	for k in stool:
		if str(k).get_file() == "seat_point":
			seat_y = (stool[k].world as Transform3D).origin.y
	check(absf(seat_y - 0.44) <= 0.05, "the stool's seat_point is at %.2f m (0.44, the KayKit chair height)" % seat_y)

	var bs := _scene_nodes(BAR_STOOL_SCENE_PATH) if ResourceLoader.exists(BAR_STOOL_SCENE_PATH) else {}
	var seat_local := Transform3D.IDENTITY
	var seat_ok := false
	for k in bs:
		if "patron_seat" in bs[k].groups and bs[k].type == "Marker3D":
			seat_ok = true
			seat_local = bs[k].world
	check(seat_ok, "BarStool.tscn has a Marker3D in group patron_seat")
	var rb := _scene_nodes(ROUND_BAR_SCENE_PATH) if ResourceLoader.exists(ROUND_BAR_SCENE_PATH) else {}
	var stools := rb.keys().filter(func(k): return rb[k].instance == BAR_STOOL_SCENE_PATH)
	var facing_ok := true
	for k in stools:
		var t: Transform3D = rb[k].world
		var r := Vector2(t.origin.x, t.origin.z).length()
		var inward := Vector3(-t.origin.x, 0, -t.origin.z).normalized()
		if absf(r - 3.95) >= 0.05 or t.basis.z.normalized().dot(inward) <= 0.99:
			facing_ok = false
	check(stools.size() == 12 and facing_ok, "RoundBar has %d stools (12) at r 3.95 facing the bar" % stools.size())
	var serves := rb.keys().filter(func(k): return rb[k].type == "Marker3D" and "serve_point" in rb[k].groups)
	check(serves.size() == 5, "RoundBar has %d serve points for the Bartender (5)" % serves.size())
	check(rb.values().any(func(n): return n.instance == BACK_BAR_PATH), "RoundBar instances the B12 island")

	var sp = load(SPAWNER_SCRIPT_PATH) as Script
	var rp = load(PATRON_SCRIPT_PATH) as Script
	var has_api: bool = sp != null and rp != null and sp.get_script_method_list().any(func(m): return m.name == "build_seats") \
		and rp.get_script_method_list().any(func(m): return m.name == "seat_root")
	check(has_api, "PatronSpawner.build_seats() and RealisticPatron.seat_root() exist")
	if has_api:
		var seat_t := Transform3D(Basis.looking_at(Vector3(0, 0, 1), Vector3.UP, true), Vector3(0, 0.54, -3.95))   # +Z toward the centre
		var root: Vector3 = rp.seat_root(seat_t)
		check(root.distance_to(Vector3(0, 0.1, -3.55)) < 0.02, "seat_root: 0.40 m in front of the seat, on the floor (%s)" % root)
		var far := Vector3(-3.0, 0, -1.0)
		var near := Vector3(0.1, 0, -3.5)
		var only_tables: Array = sp.build_seats([], [far, near])
		check(only_tables.size() == 2 and only_tables.all(func(s): return s.sit == null) and only_tables[0].approach == far,
			"build_seats with no scene seats is the old table list")
		var mixed: Array = sp.build_seats([seat_t], [far, near])
		check(mixed.size() == 2 and mixed[0].sit is Transform3D and mixed[0].approach.distance_to(root) < 0.01 and mixed[1].approach == far,
			"build_seats: scene seats first, table spots kept unless within 0.8 m of a seat")
	var tank_ok: bool = rp != null and ResourceLoader.exists(str(rp.get_script_constant_map().get("TANKARD_FULL", ""))) \
		and ResourceLoader.exists(str(rp.get_script_constant_map().get("TANKARD_EMPTY", "")))
	check(tank_ok, "RealisticPatron's tankard props point at the H1 files")

	var tav := _scene_nodes(TAVERN_SCENE_PATH)
	var gone := tav.keys().filter(func(k): return OLD_BAR_NODES.any(func(p): return str(k).ends_with("TavernNavigation/" + p)))
	check(gone.is_empty(), "the old bar pieces are gone %s" % [gone])
	var tscn_text := FileAccess.get_file_as_string(TAVERN_SCENE_PATH)
	check(not tscn_text.contains("TavernCounterCircular.glb"), "MainTavern no longer needs the gitignored TavernCounterCircular.glb")
	var hits := tav.keys().filter(func(k): return tav[k].instance == ROUND_BAR_SCENE_PATH)
	check(hits.size() == 1 and (tav[hits[0]].world as Transform3D).origin.distance_to(PILLAR_RING_CENTRE) < 0.05,
		"MainTavern has the round bar at the pillar %s" % [hits])
	var nav = null
	for k in tav:
		if str(k).ends_with("TavernNavigation"):
			nav = tav[k].props.get("navigation_mesh")
	if hits.size() == 1 and nav is NavigationMesh:
		var t_bar: Transform3D = tav[hits[0]].world
		var c := t_bar.origin
		check(not _nav_contains(nav, c.x, c.z + 2.7), "navmesh: the counter is solid (r 2.7 in front is off)")
		check(_nav_contains(nav, c.x, c.z - 3.7), "navmesh: the flap entrance (r 3.7 behind) is on")
		var off := []
		for k in stools:
			var seat_w: Transform3D = t_bar * (rb[k].world as Transform3D) * seat_local
			var a: Vector3 = rp.seat_root(seat_w) if has_api else seat_w.origin
			var out := Vector3(a.x - c.x, 0, a.z - c.z).normalized()
			var p := a + out * 0.3
			if not _nav_contains(nav, p.x, p.z):
				off.append("(%.2f, %.2f)" % [p.x, p.z])
		check(stools.size() == 12 and off.is_empty(), "navmesh: every stool's approach is reachable (off: %s)" % [off])
	else:
		check(false, "navmesh checks need the bar in MainTavern")
	print("")



# --- Test 13: The guild desk and mission board (Story 25.7) ---
# B3 desk and B4 board (budgets, glow rule, objects, markers: the Quest Dealer's work_point at seat
# height facing the customer side; the 8 notices); notices_shown (the board shows today's contracts);
# the scenes (DeskLight, work_point group, the board in group notice_board and never in the UI's
# mission_board group); and the hall: old pieces gone, desk and board placed facing the room, each
# prompt zone covering its interact point on the navmesh, the desk solid.
func test_desk_and_board() -> void:
	print("[Test 13] The guild desk and mission board")
	for spec in [[DESK_PATH, 2500, 1], [BOARD_PATH, 2500, 1]]:
		var ok := ResourceLoader.exists(spec[0])
		check(ok, "asset exists: %s" % str(spec[0]).get_file())
		var st := _mesh_stats(spec[0]) if ok else {"tris": 0, "glow": 0, "wrong": ["missing"]}
		check(st.tris > 0 and st.tris <= spec[1] and st.glow >= spec[2] and st.wrong.is_empty(),
			"%s: %d tris (budget %d), glow rule (%d glow; wrong: %s)" % [str(spec[0]).get_file(), st.tris, spec[1], st.glow, st.wrong])
	var desk := _scene_nodes(DESK_PATH) if ResourceLoader.exists(DESK_PATH) else {}
	var dn := {}
	for k in desk:
		dn[str(k).get_file()] = desk[k]
	check(["desk", "desk_dressing", "desk_stool", "work_point", "chronicle_point", "candle_point", "interact_point"].all(func(n): return dn.has(n)),
		"B3 objects and markers present")
	var wp: Transform3D = dn.work_point.world if dn.has("work_point") else Transform3D()
	check(absf(wp.origin.y - 0.44) <= 0.05 and wp.basis.z.normalized().dot(Vector3.BACK) > 0.99,
		"the Quest Dealer's work_point sits at %.2f m facing the customer side" % wp.origin.y)
	check(desk.values().any(func(n): return n.props.get("shape") is ConcavePolygonShape3D), "B3 has its trimesh collider")
	var board := _scene_nodes(BOARD_PATH) if ResourceLoader.exists(BOARD_PATH) else {}
	var bnames := board.keys().map(func(k): return str(k).get_file())
	var notices := bnames.filter(func(n): return str(n).begins_with("notice_"))
	check(notices.size() == 8 and "interact_point" in bnames, "B4 has 8 separate notices and an interact_point (%d)" % notices.size())

	var nb = load(NOTICE_SCRIPT_PATH) if ResourceLoader.exists(NOTICE_SCRIPT_PATH) else null
	var has_fn: bool = nb != null and nb.get_script_method_list().any(func(m): return m.name == "notices_shown")
	check(has_fn and nb.notices_shown(-1) == 0 and nb.notices_shown(0) == 0 and nb.notices_shown(3) == 3
		and nb.notices_shown(8) == 8 and nb.notices_shown(12) == 8, "notices_shown: one per available contract, 0..8")
	if has_fn:
		var a := {"name": "Wolves"}
		var b := {"name": "Bandits"}
		check(nb.open_contracts([a, b], []) == 2 and nb.open_contracts([a, b], [{"mission": a, "days_remaining": 2}]) == 1
			and nb.open_contracts([], [{"mission": a}]) == 0, "open_contracts: today's pool minus the contracts already taken")
	var gd := _scene_nodes(DESK_SCENE_PATH) if ResourceLoader.exists(DESK_SCENE_PATH) else {}
	check(gd.has("DeskLight") and gd.DeskLight.type == "OmniLight3D"
		and gd.values().any(func(n): return n.type == "Marker3D" and "work_point" in n.groups),
		"GuildDesk.tscn has its DeskLight and a work_point marker (group work_point)")
	var nbs := _scene_nodes(NOTICE_SCENE_PATH) if ResourceLoader.exists(NOTICE_SCENE_PATH) else {}
	var root_groups: Array = nbs.get(".", {}).get("groups", [])
	check(nbs.values().any(func(n): return n.instance == BOARD_PATH) and "notice_board" in root_groups and not "mission_board" in root_groups,
		"GuildNoticeBoard.tscn: the B4 model, group notice_board, never the UI's mission_board group")

	var tav := _scene_nodes(TAVERN_SCENE_PATH)
	var gone := tav.keys().filter(func(k): return OLD_DESK_NODES.any(func(p): return str(k).ends_with("TavernNavigation/" + p)))
	check(gone.is_empty(), "the old desk box, its chair and light, and the board box are gone %s" % [gone])
	var nav = null
	for k in tav:
		if str(k).ends_with("TavernNavigation"):
			nav = tav[k].props.get("navigation_mesh")
	for spec in [[DESK_SCENE_PATH, DESK_SPOT, "RecruitmentDesk", desk], [NOTICE_SCENE_PATH, BOARD_SPOT, "MissionBoard", board]]:
		var hits := tav.keys().filter(func(k): return tav[k].instance == spec[0])
		var placed: bool = hits.size() == 1 and (tav[hits[0]].world as Transform3D).origin.distance_to(spec[1]) < 0.05 \
			and (tav[hits[0]].world as Transform3D).basis.z.normalized().dot(Vector3.BACK) > 0.99
		check(placed, "MainTavern has %s at %s facing the room %s" % [str(spec[0]).get_file(), spec[1], hits])
		if not placed:
			continue
		var ip := Vector3.ZERO
		for k in spec[3]:
			if str(k).get_file() == "interact_point":
				ip = (tav[hits[0]].world as Transform3D) * (spec[3][k].world as Transform3D).origin
		var zone := AABB()
		for k in tav:
			if str(k).ends_with("Interactive/%s/CollisionShape3D" % spec[2]) and tav[k].props.get("shape") is BoxShape3D:
				var size: Vector3 = (tav[k].props.shape as BoxShape3D).size
				zone = (tav[k].world as Transform3D) * AABB(-size / 2, size)
		check(zone.has_point(ip + Vector3(0, 1.0, 0)) and nav is NavigationMesh and _nav_contains(nav, ip.x, ip.z),
			"the %s zone %s covers its interact point %s, which is on the navmesh" % [spec[2], zone, ip])
	check(nav is NavigationMesh and not _nav_contains(nav, DESK_SPOT.x, DESK_SPOT.z + 0.35), "navmesh: the desk front is solid")
	print("")

## Radius (xz) of a scene's trimesh collider: the smallest vertex radius (inner = true) or the largest.
static func _shape_radius(nodes: Dictionary, inner: bool) -> float:
	for k in nodes:
		var sh = nodes[k].props.get("shape")
		if sh is ConcavePolygonShape3D:
			var best := INF if inner else 0.0
			for v in (sh as ConcavePolygonShape3D).get_faces():
				var r := Vector2(v.x, v.z).length()
				best = minf(best, r) if inner else maxf(best, r)
			return best
	return -1.0

## Floor-level only: a solid prop's flat top can bake into a small unreachable island above it.
static func _nav_contains(nav: NavigationMesh, x: float, z: float, max_y := 1.0) -> bool:
	var v := nav.get_vertices()
	for i in nav.get_polygon_count():
		var poly := nav.get_polygon(i)
		if v[poly[0]].y > max_y:
			continue
		var inside := false
		for a in poly.size():
			var p1 := v[poly[a]]
			var p2 := v[poly[(a + 1) % poly.size()]]
			if (p1.z > z) != (p2.z > z) and x < p1.x + (z - p1.z) * (p2.x - p1.x) / (p2.z - p1.z):
				inside = not inside
		if inside:
			return true
	return false


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
