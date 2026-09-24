extends SceneTree

## Standalone failsafe tests — no framework, no autoloads needed.
## Run via CLI:
##   "E:\Godot installer\Godot_v4.4.1-stable_win64.exe" --headless --script res://test/failsafe_test.gd --path "F:\GAME I AM MAKING\shiningsun"
## Test 5 (asset-path integrity, Epic 25 / Story 25.1) checks every res:// path referenced
## from data/**/*.json against disk; known gaps live in res://test/asset_path_allowlist.json.

const ASSET_ALLOWLIST_PATH := "res://test/asset_path_allowlist.json"

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("\n========== FAILSAFE TESTS ==========\n")

	test_save_load_round_trip()
	test_loot_rng_distribution()
	test_mission_success_formula()
	test_adventurer_status_transitions()
	test_asset_path_integrity()

	print("\n====================================")
	print("PASSED: %d  |  FAILED: %d" % [_pass_count, _fail_count])
	if _fail_count > 0:
		print("*** SOME TESTS FAILED ***")
	else:
		print("All tests passed.")
	print("====================================\n")
	quit()


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
