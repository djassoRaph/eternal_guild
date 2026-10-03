# GameManager.gd - Autoload Singleton
extends Node

const AStatus = AdventurerStatus.Status

# === CORE GAME STATE ===
var gold: int = 1000
var beer_stock: int = 5
var current_day: int = 1
var max_adventurers: int = 5
var adventurers: Array = []
var available_missions: Array = []  # Changed from Dictionary to Array
var recruitment_manager = null
var patron_recruitment_pool = []  # Patrons interested in joining
var firewood_stock: int = 0
var fireplace_fuel: float = 0.0  # Starts at 0% (fire is out)
var max_firewood_storage: int = 10
var daily_patron_visits: int = 0  # Track patrons for fuel drain
var mission_tier_unlocked: int = 1
var next_adventurer_id: int = 1
var hired_tarot_cards: Array = []   # Tarot card ids hired this run — never re-offered (Epic 4.1)
var tax_due_day: int = 30
var tax_grace_days: int = 0  # Days into grace period after missed tax (0 = not in grace)
var daily_operating_cost: int = 5

# === UI UPDATE SIGNALS ===
signal gold_changed(new_amount: int)
signal beer_changed(new_amount: int)  
signal day_changed(new_day: int)
signal adventurer_roster_changed()
signal missions_changed
signal recruitment_pool_changed
signal game_over_triggered(reason: String)
signal firewood_changed(new_amount: int)
signal fireplace_fuel_changed(new_percentage: float)
signal mission_dispatched(adventurers: Array, mission, hex_id: String)
signal missions_resolved(reports)
signal morning_briefing_ready(reports)
signal reputation_changed(new_value: int)


var mission_refresh_day: int = 1
var recruit_refresh_day: int = 1
var daily_recruits: Array = []
var game_over_active: bool = false
var beer_shortage_days: int = 0
var adventurer_morale: Dictionary = {}  # adventurer_id -> morale level (1-3)

# === Progression Tracking ===
var total_missions_completed: int = 0
var tavern_reputation: int = 0
var taxes_paid_count: int = 0

var active_missions: Array = []       # Missions currently in progress with countdown timers
var pending_reports: Array = []       # Resolved mission results waiting to be shown in morning briefing
var has_pending_briefing: bool = false # Flag for morning briefing UI to check

# === Dialogue state (Story 10.2): what conversations may notice this run, read through dialogue_bridge.gd ===
var adventurers_hired_this_run: int = 0
var deaths_this_run: int = 0
var dialogue_flags: Dictionary = {}    # conversation flag id -> true (e.g. "den_fa_first_contact"), saved per run
# Den Fa's state (Story 10.3): "early" -> "mid" -> "late", forward only, moved by adjust_reputation() at the
# tiers named in game_config.json's den_fa_state_tiers; saved per run; GuildBus.den_fa_state_changed on each step
# earned in play (loading a save and New Game are silent).
const DEN_FA_STATES := ["early", "mid", "late"]
const DEN_FA_DEFAULT_TIERS := {"mid": "Known", "late": "Trusted"}
const DEN_FA_UNREACHABLE := 1 << 30    # a tier index no reputation reaches (too few tiers for Mid and Late)
var den_fa_state: String = "early"
var _den_fa_tier_warnings: int = 0     # a bad den_fa_state_tiers is warned about once a run (New Game re-arms it)



# Tier unlock conditions
var tier_requirements = {
	1: {"always_unlocked": true},  # Starting tier
	2: {"taxes_paid": 1, "description": "Pay first tax (Day 30)"},
	3: {"reputation": 50, "day": 60, "missions_completed": 10, "description": "Build reputation and experience"}
}


# === INITIALIZATION ===
func _ready():
	print("GameManager singleton initialized")
	DataManager.data_ready.connect(_on_data_ready)
	_bridge_signals_to_buses()

func _apply_config():
	gold = DataManager.get_config("starting_gold", 1000)
	beer_stock = DataManager.get_config("starting_beer", 5)
	max_adventurers = DataManager.get_config("max_adventurers", 5)
	max_firewood_storage = DataManager.get_config("max_firewood_storage", 10)
	firewood_stock = DataManager.get_config("starting_firewood", 0)
	fireplace_fuel = DataManager.get_config("starting_fireplace_fuel", 0.0)
	tax_due_day = DataManager.get_config("tax_due_day", 30)
	daily_operating_cost = DataManager.get_config("daily_operating_cost", 1)

func _bridge_signals_to_buses():
	gold_changed.connect(func(v): EconomyBus.gold_changed.emit(v))
	beer_changed.connect(func(v): EconomyBus.beer_changed.emit(v))
	firewood_changed.connect(func(v): EconomyBus.firewood_changed.emit(v))
	fireplace_fuel_changed.connect(func(v): EconomyBus.fireplace_fuel_changed.emit(v))
	day_changed.connect(func(v): GameBus.day_changed.emit(v))
	game_over_triggered.connect(func(r): GameBus.game_over_triggered.emit(r))
	morning_briefing_ready.connect(func(r): GameBus.morning_briefing_ready.emit(r))
	adventurer_roster_changed.connect(func(): AdventurerBus.adventurer_roster_changed.emit())
	recruitment_pool_changed.connect(func(): AdventurerBus.recruitment_pool_changed.emit())
	mission_dispatched.connect(func(a, m, h): AdventurerBus.mission_dispatched.emit(a, m, h))
	missions_resolved.connect(func(r): AdventurerBus.missions_resolved.emit(r))
	reputation_changed.connect(func(v): GuildBus.reputation_changed.emit(v))
	missions_changed.connect(func(): AdventurerBus.missions_changed.emit())
	


func _on_data_ready():
	_apply_config()
	print("Config applied - Gold: ", gold, " Beer: ", beer_stock, " Max adventurers: ", max_adventurers)
	refresh_missions()

func refresh_missions():
	print("DEBUG: refresh_missions() called on day ", current_day)
	available_missions = DataManager.generateAvailableMissions()
	print("DEBUG: Generated missions: ", available_missions.size())
	log_message("New guild contracts have been posted!")

# === GOLD MANAGEMENT ===
func add_gold(amount: int):
	"""Add gold and notify all systems"""
	gold += amount
	gold_changed.emit(gold)
	print("Added ", amount, " gold. Total: ", gold)

func spend_gold(amount: int) -> bool:
	"""Spend gold if sufficient funds available"""
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		print("Spent ", amount, " gold. Remaining: ", gold)
		return true
	else:
		print("Insufficient gold. Need ", amount, " but have ", gold)
		return false

func adjust_reputation(delta: int) -> void:
	"""Single-authority reputation mutator (Epic 14) — clamps at 0, moves Den Fa's state forward (Story 10.3),
	emits reputation_changed."""
	tavern_reputation = maxi(0, tavern_reputation + delta)
	_update_den_fa_state()
	reputation_changed.emit(tavern_reputation)

## Staff at the start (Story 25.13, K9: "Available right away in the demo. But then have to unlock in the
## real game"): in the demo profile the roles listed in demo_start_staff are hired from the first morning;
## in the full profile nobody is until Epic 16 hires them.
static func staff_hired_by_profile(profile: String, start_staff: Array, role: String) -> bool:
	return profile == "demo" and start_staff.has(role)

## Whether a staff role is hired (Story 25.13 stub). Story 16.1 replaces this with the staff records,
## keeping the demo's starting staff.
func is_staff_hired(role: String) -> bool:
	var start = DataManager.get_config("demo_start_staff", [])
	return staff_hired_by_profile(str(DataManager.get_config("profile", "full")), start if start is Array else [], role)

func get_reputation_tier() -> Dictionary:
	"""Highest reputation_tiers entry (data/config/game_config.json) the guild currently qualifies
	for. Never empty — falls back to the base tier. Same list and index as get_reputation_tier_index()."""
	var tiers := reputation_tier_list(DataManager.get_config("reputation_tiers", []))
	return tiers[reputation_tier_index_for(tavern_reputation, tiers)]

## The current tier's index in reputation_tier_list() (0 = Unknown … 4 = Honored with today's config); the
## dialogue bridge's reputation_tier_index (Story 10.2 review: label and index come from one list).
func get_reputation_tier_index() -> int:
	return reputation_tier_index_for(tavern_reputation, reputation_tier_list(DataManager.get_config("reputation_tiers", [])))

## The config's reputation tiers sorted by threshold, with the base tier (0, "Unknown") first when the
## config has no entry at threshold 0 or below. Never empty.
static func reputation_tier_list(raw) -> Array:
	var tiers := []
	if raw is Array:
		for t in raw:
			if t is Dictionary:
				tiers.append(t)
	tiers.sort_custom(func(a, b): return int(a.get("threshold", 0)) < int(b.get("threshold", 0)))
	if tiers.is_empty() or int(tiers[0].get("threshold", 0)) > 0:
		tiers.push_front({"threshold": 0, "label": "Unknown", "tip_bonus": 0.0, "recruit_stat_bonus": 0})
	return tiers

## The index of the highest tier in `tiers` (a reputation_tier_list) that `reputation` reaches.
static func reputation_tier_index_for(reputation: int, tiers: Array) -> int:
	var index := 0
	for i in tiers.size():
		if reputation >= int(tiers[i].get("threshold", 0)):
			index = i
	return index

func get_gold() -> int:
	"""Get current gold amount"""
	return gold

func purchase_firewood(bundles: int, cost: int) -> bool:
	"""Purchase firewood for the fireplace"""
	# Check storage capacity
	if firewood_stock + bundles > max_firewood_storage:
		log_message("Not enough storage space! (Max: " + str(max_firewood_storage) + " bundles)")
		return false
	
	# Check if can afford
	if not spend_gold(cost):
		log_message("Insufficient gold to buy firewood (Need " + str(cost) + " gold)")
		return false
	
	# Purchase successful
	firewood_stock += bundles
	firewood_changed.emit(firewood_stock)
	
	log_message("Purchased " + str(bundles) + " bundle(s) of firewood for " + str(cost) + " gold")
	log_message("Firewood stock: " + str(firewood_stock) + "/" + str(max_firewood_storage))
	
	return true



# === BEER MANAGEMENT ===
func add_beer(amount: int):
	"""Add beer stock and notify systems"""
	beer_stock += amount
	beer_changed.emit(beer_stock)
	print("Added ", amount, " beer. Total: ", beer_stock)

func consume_drink(drink_type: String, amount: int = 1) -> bool:
	"""SINGLE authority for drink consumption (Story 3.4). Beer is the MVP drink; add
	mead/cider/wine cases here as they come online. Returns false if stock is short (no crash)."""
	match drink_type:
		"beer":
			if beer_stock < amount:
				return false
			beer_stock -= amount
			beer_changed.emit(beer_stock)
			return true
		_:
			push_warning("consume_drink: unknown drink '%s'" % drink_type)
			return false

func consume_beer(amount: int) -> bool:
	"""Thin wrapper — routes through consume_drink() (the single authority)."""
	return consume_drink("beer", amount)

func get_beer() -> int:
	"""Get current beer stock"""
	return beer_stock

# === DAY MANAGEMENT ===
func get_day() -> int:
	"""Get current day number"""
	return current_day

func get_adventurer_count() -> int:
	"""Get total number of adventurers"""
	return adventurers.size()

func get_ready_adventurers() -> Array:
	var ready = []
	for adv in adventurers:
		if AdventurerStatus.is_available(adv.get("status", AStatus.READY)):
			ready.append(adv)
	return ready

func is_adventurer_available(adventurer: Dictionary) -> bool:
	return AdventurerStatus.is_available(adventurer.status)

func get_unavailable_adventurers() -> Array:
	var unavailable = []
	for adv in adventurers:
		if not AdventurerStatus.is_available(adv.status):
			unavailable.append(adv)
	return unavailable

func can_form_party(minimum_size: int = 2) -> bool:
	"""Check if enough adventurers available for party mission"""
	return get_ready_adventurers().size() >= minimum_size

func get_max_party_size() -> int:
	"""Get maximum party size based on available adventurers"""
	return get_ready_adventurers().size()

func get_max_adventurers() -> int:
	"""Get maximum adventurer capacity"""
	return max_adventurers

# === MISSION SYSTEM ===
func send_on_mission(adventurer: Dictionary, mission: Dictionary, hex_id: String = ""):
	"""Dispatch an adventurer on a mission. Does NOT resolve it — just starts the timer."""
	var duration = mission.get("duration_days", 1)

	adventurer.status = AStatus.ON_MISSION
	adventurer["current_mission"] = mission.get("name", "Unknown Mission")

	var active_entry = {
		"adventurer": adventurer,
		"mission": mission,
		"days_remaining": duration,
		"total_duration": duration,
		"success_chance": calculate_mission_success_chance(adventurer, mission),
		"sent_day": current_day,
		"hex_id": hex_id
	}

	active_missions.append(active_entry)

	log_message("" + adventurer.name + " departs on: " + mission.get("name", "?") + " (" + str(duration) + " day" + ("s" if duration > 1 else "") + ")")

	adventurer_roster_changed.emit()
	mission_dispatched.emit([adventurer], mission, hex_id)


func send_party_on_mission(party: Array, mission: Dictionary, hex_id: String = ""):
	"""Dispatch a party on a mission. Does NOT resolve — starts the timer."""
	var duration = mission.get("duration_days", 1)

	for adventurer in party:
		adventurer.status = AStatus.ON_MISSION
		adventurer["current_mission"] = mission.get("name", "Unknown Mission")

	var active_entry = {
		"party": party,
		"mission": mission,
		"days_remaining": duration,
		"total_duration": duration,
		"is_party_mission": true,
		"sent_day": current_day,
		"hex_id": hex_id
	}

	active_missions.append(active_entry)

	var names = ", ".join(party.map(func(a): return a.name))
	log_message("Party departs on: " + mission.get("name", "?") + " (" + str(duration) + " day" + ("s" if duration > 1 else "") + ")")
	log_message("   Party: " + names)

	adventurer_roster_changed.emit()
	mission_dispatched.emit(party, mission, hex_id)


func get_trait_data(personality: String) -> Dictionary:
	"""Look up trait modifiers from DataManager. Returns empty dict if not found."""
	var traits = DataManager.character_traits
	var positive = traits.get("positive_traits", {})
	var negative = traits.get("negative_traits", {})
	return positive.get(personality, negative.get(personality, {}))

func calculate_mission_success_chance(adventurer: Dictionary, mission: Dictionary) -> int:
	"""Calculate success chance — extracted from mission_board.gd for reuse"""
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

	# Apply personality trait modifier
	var trait_data = get_trait_data(adventurer.get("personality", ""))
	var trait_bonus = 0

	if trait_data.has("mission_bonus"):
		trait_bonus += int(trait_data.mission_bonus * 100)

	if trait_data.has("danger_resistance") and mission.get("danger", 1) >= 3:
		trait_bonus += int(trait_data.danger_resistance * 100)

	final_chance += trait_bonus

	return clampi(final_chance, 10, 95)


func complete_mission(adventurer: Dictionary, mission: Dictionary, success: bool, announce := true) -> int:
	"""Enhanced mission completion with mandatory recovery period. Returns the actual gold
	reward paid out (0 on failure) — Epic 12: the reveal report needs the real amount, not
	the mission's config range. The overnight resolver passes announce = false and logs the
	success itself once the loot roll's gold has joined the reward, so the log line, the gold
	total and the morning report show the same amount."""
	var reward := 0
	if success:
		reward = randi_range(mission.reward_range[0], mission.reward_range[1])

		# Lucky trait: bonus reward on success
		var trait_data = get_trait_data(adventurer.get("personality", ""))
		if trait_data.has("reward_bonus"):
			var bonus = int(reward * trait_data.reward_bonus)
			if bonus > 0:
				reward += bonus
				log_message("" + adventurer.name + "'s luck paid off! +" + str(bonus) + " bonus gold.")

		add_gold(reward)
		adventurer.missions_completed += 1
		adventurer.gold_earned += reward

		# SUCCESS: Adventurer needs rest (1 day minimum)
		adventurer.status = AStatus.RESTING
		adventurer.recovery = 1

		total_missions_completed += 1
		adjust_reputation(2)
		GameManager.check_tier_unlocks()

		if announce:
			_log_solo_success(adventurer, mission, reward)
	else:
		adventurer.missions_failed += 1
		adjust_reputation(-1)
		log_message("FAILED! " + adventurer.name + " failed the mission: " + mission.name)

		# FAILURE ONLY: Handle injury and death consequences
		if adventurer.get("injured", false):
			adventurer.status = AStatus.WOUNDED
			adventurer.recovery = randi_range(2, 5)
		else:
			adventurer.status = AStatus.RESTING
			adventurer.recovery = 1

		handle_party_failure_consequences(adventurer, mission)

	# Clear mission tracking
	adventurer.erase("current_mission")
	# Emit signal so UI updates
	adventurer_roster_changed.emit()

	return reward



func complete_party_mission(party: Array, mission: Dictionary, success: bool, announce := true) -> int:
	"""Enhanced party missions with recovery periods. Returns the actual gold reward paid
	out (0 on failure) — Epic 12: the reveal report needs the real amount, not the
	mission's config range. announce = false: the caller logs the success (see
	complete_mission)."""
	var reward := 0
	if success:
		reward = randi_range(mission.reward_range[0], mission.reward_range[1])
		add_gold(reward)

		for adventurer in party:
			# SUCCESS: All party members need rest
			adventurer.status = AStatus.RESTING
			adventurer.recovery = 1  # 1 day rest for successful party missions
			adventurer.missions_completed += 1
			adventurer.gold_earned += reward / party.size()
			check_adventurer_level_up(adventurer)

		if announce:
			_log_party_success(mission, reward)
	else:
		log_message("PARTY FAILED! Mission " + mission.name + " was catastrophic")
		adjust_reputation(-1)  # one reputation hit per failed mission, not per party member
		for adventurer in party:
			handle_party_failure_consequences(adventurer, mission)
			# CRITICAL FIX: Emit signal so UI updates
			adventurer_roster_changed.emit()

	return reward


func _log_solo_success(adventurer: Dictionary, mission: Dictionary, reward: int) -> void:
	log_message("SUCCESS! " + adventurer.name + " completed " + mission.name + " and earned " + str(reward) + " gold!")
	log_message("" + adventurer.name + " rests for 1 day to recover their strength")


func _log_party_success(mission: Dictionary, reward: int) -> void:
	log_message("PARTY SUCCESS! Completed " + mission.name + " and earned " + str(reward) + " gold!")
	log_message("Party members rest for 1 day after their successful mission")



# === DAILY PROCESSING ===
func process_mission_returns():
	"""Tick down active mission timers. Resolve any that hit 0. Store results for morning briefing."""
	var resolved_indices = []

	for i in range(active_missions.size()):
		var entry = active_missions[i]
		entry.days_remaining -= 1

		if entry.days_remaining <= 0:
			resolved_indices.append(i)
			var report = _resolve_mission(entry)
			pending_reports.append(report)
			# Clear the hex lock so this hex re-enters circulation after resolution.
			var hex_id: String = entry.get("hex_id", "")
			if hex_id != "":
				for hex in WorldManager.world_map:
					if hex["id"] == hex_id:
						hex.erase("locked")
						break
		else:
			var mission_name = entry.mission.get("name", "Unknown")
			var days_left = entry.days_remaining
			if entry.get("is_party_mission", false):
				log_message("Party on " + mission_name + " — " + str(days_left) + " day" + ("s" if days_left > 1 else "") + " remaining")
			else:
				var adv_name = entry.adventurer.get("name", "Someone")
				log_message("" + adv_name + " on " + mission_name + " — " + str(days_left) + " day" + ("s" if days_left > 1 else "") + " remaining")

	resolved_indices.reverse()
	for idx in resolved_indices:
		active_missions.remove_at(idx)

	if pending_reports.size() > 0:
		has_pending_briefing = true
		# Story 7.1 (Reveal-Before-Display) — every outcome is already applied to game state
		# (roster, gold, statuses) and every death is already in codex.dat. Persist the save
		# NOW, before the reveal sequencer plays, so the panels are purely cosmetic and a
		# crash or quit mid-reveal still leaves an already-correct save on disk.
		SaveSystem.save_game_state("reveal_presave", true)
		morning_briefing_ready.emit(pending_reports)


func _resolve_mission(entry: Dictionary) -> Dictionary:
	"""Roll the dice for a completed mission and return a report dictionary."""
	var result: Dictionary
	if entry.get("is_party_mission", false):
		result = _resolve_party_mission(entry)
	else:
		result = _resolve_solo_mission(entry)
	on_mission_resolved(result)
	return result


func _resolve_solo_mission(entry: Dictionary) -> Dictionary:
	"""Resolve a solo mission and apply consequences to the adventurer."""
	var adventurer = entry.adventurer
	var mission = entry.mission
	var success_chance = entry.success_chance
	var roll = randi() % 100 + 1
	var success = roll <= success_chance

	# Reckless trait: extra injury chance on failure
	var trait_data = get_trait_data(adventurer.get("personality", ""))
	if not success and trait_data.has("injury_chance"):
		if randf() < trait_data.injury_chance:
			adventurer["injured"] = true

	var reward := complete_mission(adventurer, mission, success, false)

	# Epic 12 — one loot roll per resolved mission, success only (failure already has its own
	# consequences via handle_party_failure_consequences()). Gold tier folds into `reward`
	# silently; equipment/artifact surface in the report for the reveal panel.
	var loot_report = null
	if success:
		var loot := _roll_and_apply_loot(adventurer, reward)
		if loot.get("tier") == "gold":
			var bonus: int = loot.get("bonus", 0)
			if bonus > 0:
				add_gold(bonus)
				adventurer.gold_earned += bonus
				reward += bonus
		else:
			loot_report = loot
		# Logged after the loot gold, so the line names the full payout, like the morning report.
		_log_solo_success(adventurer, mission, reward)

	return {
		"type": "solo",
		"mission_name": mission.get("name", "Unknown"),
		"adventurer_name": adventurer.get("name", "Unknown"),
		"adventurer_class": adventurer.get("class", "Unknown"),
		"portrait": adventurer.get("portrait", ""),
		"adventurer_id": adventurer.get("id", ""),
		"success": success,
		"roll": roll,
		"success_chance": success_chance,
		"reward": reward,
		"loot": loot_report,
		"duration": entry.total_duration,
		"alive": adventurer.get("status") != AStatus.DEAD,
		"injured": adventurer.get("status") == AStatus.WOUNDED,
		"category": mission.get("category", "combat")
	}


func _resolve_party_mission(entry: Dictionary) -> Dictionary:
	"""Resolve a party mission and apply consequences."""
	var party = entry.party
	var mission = entry.mission

	var total_chance = 0
	for adv in party:
		total_chance += calculate_mission_success_chance(adv, mission)
	var avg_chance = total_chance / party.size()

	var party_bonus = (party.size() - 1) * 5
	var final_chance = clampi(avg_chance + party_bonus, 10, 95)

	var roll = randi() % 100 + 1
	var success = roll <= final_chance

	var reward := complete_party_mission(party, mission, success, false)

	# Epic 12 — same one-roll-per-mission rule as the solo path. All party members are alive
	# on a success (death/injury only happen in the failure branch), so any member can be the
	# equipment recipient — pick one at random.
	var loot_report = null
	if success and not party.is_empty():
		var recipient = party[randi() % party.size()]
		var loot := _roll_and_apply_loot(recipient, reward)
		if loot.get("tier") == "gold":
			var bonus: int = loot.get("bonus", 0)
			if bonus > 0:
				add_gold(bonus)
				reward += bonus
		else:
			loot_report = loot
	if success:
		_log_party_success(mission, reward)  # after the loot gold, as in the solo path

	var member_names = party.map(func(a): return a.get("name", "?"))
	var casualties = party.filter(func(a): return a.get("status") == AStatus.DEAD)
	var injured = party.filter(func(a): return a.get("status") == AStatus.WOUNDED)

	var members := []
	for a in party:
		var st = a.get("status")
		var m_fate := "returned"
		if st == AStatus.DEAD:
			m_fate = "dead"
		elif st == AStatus.WOUNDED:
			m_fate = "wounded"
		members.append({
			"name": a.get("name", "?"),
			"class": a.get("class", ""),
			"portrait": a.get("portrait", ""),
			"id": a.get("id", ""),
			"tarot_card": a.get("tarot_card", ""),
			"fate": m_fate
		})

	return {
		"type": "party",
		"mission_name": mission.get("name", "Unknown"),
		"party_members": member_names,
		"members": members,
		"party_size": party.size(),
		"success": success,
		"roll": roll,
		"success_chance": final_chance,
		"reward": reward,
		"loot": loot_report,
		"duration": entry.total_duration,
		"casualties": casualties.map(func(a): return a.get("name", "?")),
		"injured": injured.map(func(a): return a.get("name", "?")),
		"category": mission.get("category", "combat")
	}


func get_and_clear_pending_reports() -> Array:
	"""Called by MorningBriefing UI to consume the pending reports."""
	var reports = pending_reports.duplicate()
	pending_reports.clear()
	has_pending_briefing = false
	return reports

func process_adventurer_recovery():
	for adventurer in adventurers:
		if adventurer.status in [AStatus.WOUNDED, AStatus.RESTING] and adventurer.has("recovery"):
			adventurer.recovery -= 1

			if adventurer.recovery <= 0:
				var old_status = adventurer.status
				adventurer.status = AStatus.READY
				adventurer.erase("recovery")

				match old_status:
					AStatus.WOUNDED:
						log_message("" + adventurer.name + " has fully recovered from injuries!")
					AStatus.RESTING:
						log_message("" + adventurer.name + " is refreshed and ready for new missions!")
			else:
				match adventurer.status:
					AStatus.WOUNDED:
						log_message("" + adventurer.name + " continues healing (" + str(adventurer.recovery) + " days remaining)")
					AStatus.RESTING:
						log_message("" + adventurer.name + " is still resting (" + str(adventurer.recovery) + " days remaining)")


func check_tax_deadline():
	var days_until_tax = tax_due_day - current_day

	if days_until_tax == 7:
		log_message("Tax payment due in 7 days. Amount: " + str(1000 + adventurers.size() * 5) + " gold.")
	elif days_until_tax == 3:
		log_message("Tax payment due in 3 days! Need " + str(1000 + adventurers.size() * 5) + " gold.")
	elif days_until_tax == 1:
		log_message("Tax payment due TOMORROW! Need " + str(1000 + adventurers.size() * 5) + " gold!")
	elif days_until_tax <= 0:
		handle_tax_payment()

func handle_tax_payment():
	var tax_amount = 1000 + (adventurers.size() * 5)

	if spend_gold(tax_amount):
		tax_due_day += 30
		tax_grace_days = 0
		taxes_paid_count += 1
		log_message("Paid " + str(tax_amount) + " gold in taxes. Next due: Day " + str(tax_due_day))
		check_tier_unlocks()
	else:
		tax_grace_days += 1
		log_message("OVERDUE: Cannot pay taxes (" + str(tax_amount) + " gold needed). Grace period: " + str(tax_grace_days) + "/3 days.")

		if tax_grace_days >= 3:
			trigger_game_over("bankruptcy", "Failed to pay taxes after 3-day grace period. The guild is seized.")
		else:
			var days_left = 3 - tax_grace_days
			log_message("" + str(days_left) + " day(s) remaining before the guild is shut down.")
		
		
# === LOGGING SYSTEM ===
func log_message(message: String):
	"""Send message to game log"""
	print("LOG: ", message)
	
	# Try to find and update the event log
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message(message)

# === RECRUITMENT SYSTEM ===
func generate_daily_recruits(count: int = -1):
	"""Generate the daily hire pool. count < 0 → use hire_pool_min/max from config (Epic 4.1)."""
	if count < 0:
		var lo = int(DataManager.get_config("hire_pool_min", 3))
		var hi = int(DataManager.get_config("hire_pool_max", 5))
		count = randi_range(lo, max(lo, hi))
	daily_recruits.clear()
	
	print("Generating ", count, " new recruits for day ", current_day)
	daily_recruits = generate_fallback_recruits(count)
	recruit_refresh_day = current_day
	
	# Log the new recruits
	log_message("New adventurers seeking employment at the guild!")
	for recruit in daily_recruits:
		var cost = recruit.get("hiring_cost", 10)
		log_message("• " + recruit.name + " the " + recruit.class + " — " + str(recruit.get("tarot_name", "")) + " (Hiring cost: " + str(cost) + " gold)")

	# Notify listeners → bridges to AdventurerBus.recruitment_pool_changed (Epic 4.1)
	recruitment_pool_changed.emit()

const DEFAULT_ADVENTURER_CLASSES := ["Fighter", "Rogue", "Mage", "Healer"]

## game_config.json › adventurer_classes, checked: a non-empty list of class names, else the defaults
## (an empty or malformed list used to crash the hire pool with a modulo by zero). Story 25.9 review.
static func valid_class_list(raw) -> Array:
	if raw is Array and not raw.is_empty() and raw.all(func(c): return c is String and c != ""):
		return raw
	push_warning("[GameManager] adventurer_classes is empty or malformed (%s); using %s" % [raw, DEFAULT_ADVENTURER_CLASSES])
	return DEFAULT_ADVENTURER_CLASSES.duplicate()

func generate_fallback_recruits(count: int) -> Array:
	"""Generate recruits when DataManager is not available"""
	var recruits = []
	var classes = valid_class_list(DataManager.get_config("adventurer_classes", DEFAULT_ADVENTURER_CLASSES))
	var names = DataManager.get_config("adventurer_names", ["Thara", "Bronn", "Lysa", "Gareth", "Mira", "Dain", "Vera", "Kael", "Nina", "Rex"])
	var drinks = DataManager.get_config("drink_preferences", ["beer", "mead", "none"])
	var tiers = DataManager.get_config("experience_tiers", ["Novice", "Seasoned", "Veteran"])
	var wage_min = int(DataManager.get_config("adventurer_wage_min", 1))
	var wage_max = int(DataManager.get_config("adventurer_wage_max", 3))
	# Unique-Tarot pool: whole deck minus cards on the roster and hired this run (Epic 4.1)
	var deck_available = not DataManager.get_all_tarot_ids().is_empty()
	var available_cards = _get_available_tarot_ids()
	var reputation_stat_bonus: int = get_reputation_tier().get("recruit_stat_bonus", 0)  # Epic 14

	# Avoid handing out a name already on the roster (or already picked earlier in this same
	# batch) — the 10-name pool collides fast once you've hired a few adventurers. Falls back
	# to allowing a repeat only if every name is genuinely taken, rather than looping forever.
	var used_names := {}
	for adv in adventurers:
		used_names[adv.get("name", "")] = true

	for i in count:
		var card_id = ""
		if deck_available:
			if available_cards.is_empty():
				break  # deck exhausted — cannot assign a unique card
			card_id = available_cards.pop_back()
		var card = DataManager.get_tarot_card(card_id) if card_id != "" else {}
		var drink = drinks[randi() % drinks.size()] if drinks.size() > 0 else "none"

		var available_names: Array = names.filter(func(n): return not used_names.has(n))
		var chosen_name: String = available_names[randi() % available_names.size()] if not available_names.is_empty() else names[randi() % names.size()]
		used_names[chosen_name] = true

		var recruit = {
			"id": generate_recruit_id(),
			"name": chosen_name,
			"class": classes[randi() % classes.size()],
			"status": AStatus.READY,
			"recovery": 0,
			"missions_completed": 0,
			"missions_failed": 0,
			"gold_earned": 0,
			"injuries_sustained": 0,
			"tarot_card": card_id,
			"tarot_name": card.get("name", ""),
			"portrait": card.get("portrait", ""),
			"drink_preference": drink,
		}
		
		# Generate random stats — reputation_stat_bonus rewards a well-regarded guild with
		# slightly better recruits (Epic 14 / T3-2)
		recruit.strength = randi_range(2, 8) + reputation_stat_bonus
		recruit.dexterity = randi_range(2, 8) + reputation_stat_bonus
		recruit.intelligence = randi_range(2, 8) + reputation_stat_bonus
		recruit.endurance = randi_range(2, 8) + reputation_stat_bonus
		
		# Class-based stat adjustments
		var bonus := recruit_class_bonus(recruit.class)
		for stat in bonus:
			recruit[stat] += bonus[stat]

		# Calculate hiring cost based on stats
		var stat_total = recruit.strength + recruit.dexterity + recruit.intelligence + recruit.endurance
		recruit.hiring_cost = max(8, stat_total * 2 + randi_range(-5, 10))
		recruit.experience_tier = _tier_for_stat_total(stat_total, tiers)
		recruit.daily_wage = _wage_for_tier(recruit.experience_tier, tiers, wage_min, wage_max)
		
		# Add personality and background flavor
		var personalities = ["Brave", "Cautious", "Greedy", "Noble", "Mysterious", "Cheerful", "Grim", "Ambitious"]
		var backgrounds = ["Former soldier", "Ex-bandit", "Scholar's apprentice", "Village hero", "Wandering mercenary", "Fallen noble", "Guild dropout", "Self-taught warrior"]
		
		recruit.personality = personalities[randi() % personalities.size()]
		recruit.background = backgrounds[randi() % backgrounds.size()]
		recruit.availability = randi_range(3, 7)  # Days they'll stay available
		
		recruits.append(recruit)
	
	return recruits

## Recruit stat bonus per class for the daily hire pool. The first four keep their original values;
## Barbarian and Ranger (the D-3 demo list, Story 25.9) mirror data/characters/classes.json.
static func recruit_class_bonus(cls: String) -> Dictionary:
	match cls:
		"Fighter":
			return {"strength": 2, "endurance": 1}
		"Rogue":
			return {"dexterity": 2, "intelligence": 1}
		"Mage":
			return {"intelligence": 2, "dexterity": 1}
		"Healer":
			return {"intelligence": 1, "endurance": 2}
		"Barbarian":
			return {"strength": 3, "endurance": 2, "intelligence": -1}
		"Ranger":
			return {"dexterity": 2, "endurance": 1}
	return {}

func _get_available_tarot_ids() -> Array:
	"""All deck card ids minus those on the roster and hired this run, shuffled. Epic 4.1."""
	var used := {}
	for adv in adventurers:
		var c = adv.get("tarot_card", "")
		if c != "":
			used[c] = true
	for c in hired_tarot_cards:
		used[c] = true
	var available: Array = []
	for id in DataManager.get_all_tarot_ids():
		if id != "" and not used.has(id):
			available.append(id)
	available.shuffle()
	return available

func _tier_for_stat_total(total: int, tiers: Array) -> String:
	"""Map a recruit's stat total onto the experience-tier bands (data-driven). Epic 4.1."""
	if tiers.is_empty():
		return "Novice"
	var t = clampf(float(total - 10) / 25.0, 0.0, 0.999)  # stat totals span ~10..35
	var idx = clampi(int(t * tiers.size()), 0, tiers.size() - 1)
	return tiers[idx]

func _wage_for_tier(tier: String, tiers: Array, wmin: int, wmax: int) -> int:
	"""Scale daily wage across [wmin..wmax] by tier index. Epic 4.1."""
	if tiers.size() <= 1:
		return wmin
	var idx = tiers.find(tier)
	if idx < 0:
		idx = 0
	var frac = float(idx) / float(tiers.size() - 1)
	return int(round(wmin + frac * (wmax - wmin)))

func generate_unique_id() -> int:
	var id = next_adventurer_id
	next_adventurer_id += 1
	return id

func generate_recruit_id() -> int:
	return generate_unique_id()

func get_available_recruits() -> Array:
	"""Get current list of available recruits"""
	var current_recruits = []
	for recruit in daily_recruits:
		var days_since_generation = current_day - recruit_refresh_day
		if days_since_generation < recruit.get("availability", 5):
			current_recruits.append(recruit)
		else:
			print("Recruit ", recruit.name, " is no longer available (expired)")
	
	return current_recruits

func remove_hired_recruit(recruit: Dictionary):
	"""Remove a recruit from the available pool after hiring"""
	for i in range(daily_recruits.size()):
		if daily_recruits[i].get("id") == recruit.get("id"):
			daily_recruits.remove_at(i)
			print("Removed hired recruit: ", recruit.name)
			break

func despawn_all_patrons():
	"""Remove all patrons from tavern when day ends"""
	var patron_spawner = get_node_or_null("/root/Node3D/SubViewportContainer/SubViewport/TavernNavigation/PatronSpawner")
	if patron_spawner and patron_spawner.has_method("despawn_all_patrons"):
		patron_spawner.despawn_all_patrons()
		log_message("All patrons have left for the night")

func get_firewood_stock() -> int:
	return firewood_stock

func consume_firewood(amount: int) -> int:
	"""Consume up to `amount` firewood bundles (used by the fireplace minigame). Returns the amount actually consumed."""
	var consumed: int = min(amount, firewood_stock)
	if consumed > 0:
		firewood_stock -= consumed
		firewood_changed.emit(firewood_stock)
		log_message("Burned " + str(consumed) + " log(s). Firewood: " + str(firewood_stock) + "/" + str(max_firewood_storage))
	return consumed

func get_fireplace_fuel() -> float:
	return fireplace_fuel

func get_max_firewood_storage() -> int:
	return max_firewood_storage


# Enhanced advance_day function
func advance_day():
	"""Enhanced day advancement with availability reporting"""
	current_day += 1
	day_changed.emit(current_day)
	on_day_advanced(current_day)
	fireplace_fuel = 0.0  # Fire dies completely
	fireplace_fuel_changed.emit(fireplace_fuel)
	log_message("Day " + str(current_day) + " begins - the fire has gone out overnight")
	print("Day ", current_day, " begins!")
	log_message("=== Day " + str(current_day) + " ===")
	
	# Process recovery FIRST (makes adventurers available)
	process_adventurer_recovery()

	# Deduct daily wages before the morning briefing (Story 4.4)
	apply_daily_wages()
	
	# Show availability status
	log_daily_availability_status()
	
	# Process beer consumption and other daily events
	var beer_adequate = process_adventurer_beer_consumption()
	process_mission_returns()
	process_daily_operations_with_beer()
	check_tax_deadline()
	
	# Show daily status if beer shortage is active
	if beer_shortage_days > 0:
		log_message(get_guild_status_report())
	
	# Check for complete guild collapse
	if adventurers.size() == 0 and beer_shortage_days > 0:
		log_message("GUILD COLLAPSE: No adventurers remain!")
		log_message("Consider hiring new recruits and restocking beer immediately.")
	
	# Recruitment and mission refresh
	var days_since_recruit_refresh = current_day - recruit_refresh_day
	if days_since_recruit_refresh >= 2 or daily_recruits.size() == 0:
		generate_daily_recruits()  # config-driven count — hire_pool_min/max (Epic 4.1)
	
	if current_day % 2 == 0:
		refresh_available_missions()
		log_message("New guild contracts have been posted!")
	
	# End of day summary with availability
	var availability_report = get_guild_availability_report()
	log_message("Gold: " + str(gold) + " | Beer: " + str(beer_stock) + " pints | Available: " + str(availability_report["ready"]) + "/" + str(adventurers.size()))

	# Soft-lock detection
	if adventurers.size() == 0 and gold < 8 and daily_recruits.size() == 0:
		log_message("The guild cannot recover. No adventurers, no funds, no prospects.")
		trigger_game_over("soft_lock", "The Eternal Guild fades into history — abandoned and forgotten.")


func generate_fallback_missions() -> Array:
	"""Generate fallback missions when DataManager is not available"""
	var base_missions = [
		{"name": "Clear Slimes", "danger": 1, "reward_range": [5, 10], "party_required": false, "category": "combat"},
		{"name": "Escort Merchant", "danger": 2, "reward_range": [15, 25], "party_required": true, "category": "escort"},
		{"name": "Gather Herbs", "danger": 1, "reward_range": [8, 15], "party_required": false, "category": "gathering"},
		{"name": "Investigate Bandits", "danger": 3, "reward_range": [25, 40], "party_required": true, "category": "investigation"},
		{"name": "Deliver Supplies", "danger": 2, "reward_range": [12, 22], "party_required": false, "category": "delivery"},
		{"name": "Repair Fortifications", "danger": 3, "reward_range": [30, 50], "party_required": true, "category": "construction"}
	]
	
	# Add variety to prevent identical missions
	var selected_missions = []
	base_missions.shuffle()
	
	for i in min(4, base_missions.size()):
		var mission = base_missions[i].duplicate()
		
		# Add location variety
		var locations = ["(Northern Route)", "(Eastern Frontier)", "(Mountain Pass)", "(Coastal Road)", "(Ancient Ruins)", "(Border Region)"]
		mission.name += " " + locations[randi() % locations.size()]
		
		# Add slight reward variation
		var variance = randi_range(-2, 3)
		mission.reward_range[0] = max(3, mission.reward_range[0] + variance)
		mission.reward_range[1] = max(5, mission.reward_range[1] + variance)
		
		selected_missions.append(mission)
	
	return selected_missions

func cleanup_expired_recruitment_candidates():
	"""Remove expired patron recruitment candidates"""
	patron_recruitment_pool = patron_recruitment_pool.filter(func(candidate): 
		candidate.availability_window -= 1
		return candidate.availability_window > 0
	)

# Enhanced hiring function
func dismiss_adventurer(adventurer: Dictionary) -> bool:
	"""Remove an adventurer from the roster. Cannot dismiss if on mission."""
	if adventurer.get("status") == AStatus.ON_MISSION:
		log_message("Cannot dismiss " + adventurer.get("name", "?") + " — they are currently on a mission.")
		return false

	var severance = 5  # Flat severance cost
	if gold < severance:
		log_message("Not enough gold to dismiss " + adventurer.get("name", "?") + " (need " + str(severance) + ").")
		return false  # blocked — adventurer remains, nothing deducted

	spend_gold(severance)  # deducts + emits gold_changed → EconomyBus
	adjust_reputation(-1)
	adventurers.erase(adventurer)
	log_message("" + adventurer.get("name", "?") + " has been dismissed (paid " + str(severance) + " gold, -1 reputation).")
	adventurer_roster_changed.emit()
	return true

func hire_adventurer(recruit: Dictionary) -> bool:
	"""Enhanced adventurer hiring with recruit pool management"""
	var hiring_cost = recruit.get("hiring_cost", 10)
	
	if not spend_gold(hiring_cost):
		log_message("Insufficient gold to hire " + recruit.name + " (Need " + str(hiring_cost) + " gold)")
		return false
		
	if adventurers.size() >= max_adventurers:
		print("Roster full! Cannot hire ", recruit.name)
		add_gold(hiring_cost)  # Refund
		log_message("Roster full! Cannot hire more adventurers (Maximum: " + str(max_adventurers) + ")")
		return false
	
	# Clean recruit data and add to roster
	var new_adventurer = recruit.duplicate()
	new_adventurer.erase("hiring_cost")
	new_adventurer.erase("personality")
	new_adventurer.erase("background") 
	new_adventurer.erase("availability")
	
	_normalize_adventurer_ints(new_adventurer)  # coerce JSON-loaded floats/strings → int (status "Unknown" fix)
	new_adventurer["hire_day"] = current_day  # Story 7.1 — cemetery record shows "served day X→Y"
	adventurers.append(new_adventurer)
	var hired_card = new_adventurer.get("tarot_card", "")
	if hired_card != "" and not hired_tarot_cards.has(hired_card):
		hired_tarot_cards.append(hired_card)  # never re-offer this card this run (Epic 4.1)
	remove_hired_recruit(recruit)  # Remove from available pool
	_count_hire()
	adventurer_roster_changed.emit()
	on_adventurer_hired(new_adventurer)

	log_message("Hired " + recruit.name + " the " + recruit.class + " for " + str(hiring_cost) + " gold!")
	log_message("Current roster: " + str(adventurers.size()) + "/" + str(max_adventurers) + " adventurers")

	return true

func _normalize_adventurer_ints(adv: Dictionary) -> void:
	"""Godot's JSON.parse loads saved ints as floats (and roster statuses as strings). Coerce an
	adventurer/recruit's integer fields back so status enums match and displays don't show '5.0'."""
	if adv.has("status"):
		var s = adv["status"]
		adv["status"] = AdventurerStatus.from_save(s) if s is String else int(s)
	for k in ["recovery", "hiring_cost", "daily_wage", "id", "strength", "dexterity", "intelligence", "endurance", "missions_completed", "missions_failed", "gold_earned", "injuries_sustained"]:
		if adv.has(k) and adv[k] is float:
			adv[k] = int(adv[k])

# === SAVE/LOAD SYSTEM ===

# Set by load_save_data() so the Continue flow can return the player to the scene they saved in.
var saved_player_scene: String = ""

# Set by main_menu.gd's _start_new_game(), consumed by main_tavern.gd's _ready(). Forces an
# immediate disk save the moment a brand-new game's tavern loads, so New Game -> quit before the
# Day-2 autosave -> Continue restores the fresh game instead of stale state from the prior run.
var pending_new_game_save: bool = false

func _player_pos_array() -> Array:
	if PlayerManager and is_instance_valid(PlayerManager.player):
		var p = PlayerManager.player.global_position
		return [p.x, p.y, p.z]
	return []

func _current_scene_path() -> String:
	var cs = get_tree().current_scene
	return cs.scene_file_path if cs else ""

# Patrons captured at save time, held here until the tavern's PatronSpawner restores them.
var restored_patrons: Array = []

func consume_restored_patrons() -> Array:
	var p := restored_patrons
	restored_patrons = []
	return p

func _gather_patrons_save() -> Array:
	var out: Array = []
	for p in get_tree().get_nodes_in_group("patrons"):
		if is_instance_valid(p) and p.has_method("to_save"):
			out.append(p.to_save())
	return out

func get_save_data() -> Dictionary:
	print("Gathering save data...")

	var save_adventurers = adventurers.duplicate(true)
	for adv in save_adventurers:
		if adv.has("status") and adv.status is int:
			adv.status = AdventurerStatus.for_save(adv.status)

	var data = {
		# Core resources
		"gold": gold,
		"beer_stock": beer_stock,

		# Time tracking
		"current_day": current_day,
		"tax_due_day": tax_due_day,

		# Adventurers
		"adventurers": save_adventurers,
		"max_adventurers": max_adventurers,
		
		# Beer shortage tracking
		"beer_shortage_days": beer_shortage_days,
		"adventurer_morale": adventurer_morale,
		
		# Firewood system
		"firewood_stock": firewood_stock,
		"fireplace_fuel": fireplace_fuel,
		
		# Recruitment
		"daily_recruits": daily_recruits,
		"recruit_refresh_day": recruit_refresh_day,
		
		# Missions
		"available_missions": available_missions,
		
		# Patron recruitment pool
		"patron_recruitment_pool": patron_recruitment_pool,

		# Progression
		"total_missions_completed": total_missions_completed,
		"tavern_reputation": tavern_reputation,
		"taxes_paid_count": taxes_paid_count,
		"mission_tier_unlocked": mission_tier_unlocked,
		"active_missions": active_missions,

		# ID counter
		"next_adventurer_id": next_adventurer_id,

		# Tax grace period
		"tax_grace_days": tax_grace_days,

		# World map (hex grid needed by mission board after load)
		"world_data": WorldManager.get_save_data(),

		# Player position + the scene they were in (restored on Continue)
		"player_position": _player_pos_array(),
		"player_scene": _current_scene_path(),

		# Live patrons (restored at their exact positions/state on load)
		"patrons_active": _gather_patrons_save(),
	}
	data.merge(_dialogue_save_data())  # run counters + conversation flags (Story 10.2)

	print("   Saved: ", data.keys().size(), " fields")
	print("   Day: ", data.current_day, ", Gold: ", data.gold)

	return data

func load_save_data(data: Dictionary):
	"""Load game state from save data - COMPLETE VERSION"""
	print("Loading save data into GameManager...")
	
	# Core resources
	gold = int(data.get("gold", 10))
	beer_stock = int(data.get("beer_stock", 0))
	
	# Time tracking
	current_day = int(data.get("current_day", 1))
	tax_due_day = int(data.get("tax_due_day", 30))
	
	# Adventurers
	adventurers = data.get("adventurers", [])
	for adv in adventurers:
		_normalize_adventurer_ints(adv)
	max_adventurers = DataManager.get_config("max_adventurers", 5)
	
	# Beer shortage tracking
	beer_shortage_days = int(data.get("beer_shortage_days", 0))
	adventurer_morale = data.get("adventurer_morale", {})
	
	# Firewood system
	firewood_stock = int(data.get("firewood_stock", 0))
	fireplace_fuel = data.get("fireplace_fuel", 100.0)
	
	# Recruitment
	daily_recruits = data.get("daily_recruits", [])
	for rec in daily_recruits:
		_normalize_adventurer_ints(rec)
	recruit_refresh_day = int(data.get("recruit_refresh_day", 0))
	
	# Missions
	available_missions = data.get("available_missions", [])
	
	# Patron recruitment pool
	patron_recruitment_pool = data.get("patron_recruitment_pool", [])

	# Progression
	total_missions_completed = int(data.get("total_missions_completed", 0))
	tavern_reputation = int(data.get("tavern_reputation", 0))
	taxes_paid_count = int(data.get("taxes_paid_count", 0))
	mission_tier_unlocked = int(data.get("mission_tier_unlocked", 1))
	active_missions = data.get("active_missions", [])

	# ID counter
	next_adventurer_id = int(data.get("next_adventurer_id", 1))

	# Tax grace period
	tax_grace_days = int(data.get("tax_grace_days", 0))

	# Run counters + conversation flags (Story 10.2; older saves have none)
	_load_dialogue_data(data)

	# World map (restore hex grid so mission board works after load)
	var world_data = data.get("world_data", {})
	if not world_data.is_empty():
		WorldManager.load_save_data(world_data)

	# Player position — hand it to PlayerManager so the loaded scene spawns the player there.
	var ppos = data.get("player_position", [])
	if ppos is Array and ppos.size() == 3:
		PlayerManager.pending_spawn_position = Vector3(ppos[0], ppos[1], ppos[2])
		PlayerManager.has_pending_spawn = true
	saved_player_scene = data.get("player_scene", "")
	restored_patrons = data.get("patrons_active", [])

	# Reset game over state
	game_over_active = false
	
	# Re-enable processing
	set_process_mode(Node.PROCESS_MODE_INHERIT)
	
	# Emit all signals to update UI
	gold_changed.emit(gold)
	beer_changed.emit(beer_stock)
	day_changed.emit(current_day)
	firewood_changed.emit(firewood_stock)
	fireplace_fuel_changed.emit(fireplace_fuel)
	adventurer_roster_changed.emit()
	
	print("Game state loaded successfully")
	print("   Day: ", current_day)
	print("   Gold: ", gold)
	print("   Beer: ", beer_stock)
	print("   Adventurers: ", adventurers.size())
	print("   Firewood: ", firewood_stock)
	print("   Fuel: ", fireplace_fuel, "%")
	
# === Dialogue state (Story 10.2) ===
# Small helpers so the failsafe suite can test the counters without hiring, killing or loading (they
# spend gold, write the codex and reload the world).

func _count_hire() -> void:
	adventurers_hired_this_run += 1

func _count_death() -> void:
	deaths_this_run += 1

func _dialogue_save_data() -> Dictionary:
	return {
		"adventurers_hired_this_run": adventurers_hired_this_run,
		"deaths_this_run": deaths_this_run,
		"dialogue_flags": dialogue_flags.duplicate(),
		"den_fa_state": den_fa_state,
	}

func _load_dialogue_data(data: Dictionary) -> void:
	adventurers_hired_this_run = _save_count(data.get("adventurers_hired_this_run", 0))
	deaths_this_run = _save_count(data.get("deaths_this_run", 0))
	var flags = data.get("dialogue_flags", {})
	dialogue_flags = flags.duplicate() if flags is Dictionary else {}
	# Den Fa's state (Story 10.3): an older save has none (early); an unknown value is early with a warning.
	# Then re-evaluated against the loaded reputation (a config change lands at once), never backwards, and
	# silently: GuildBus.den_fa_state_changed means "earned in play", not "restored from a save".
	var state = data.get("den_fa_state", "early")
	if not DEN_FA_STATES.has(state):
		push_warning("[GameManager] load: unknown den_fa_state %s: Den Fa starts early" % [state])
		state = "early"
	den_fa_state = state
	_update_den_fa_state(false)

## A saved counter, parsed defensively: null, junk or a negative number load as 0 (int(null) would abort
## load_save_data half-way).
static func _save_count(v) -> int:
	if v is int or v is float:
		return maxi(0, int(v))
	if v is String and (v as String).is_valid_float():
		return maxi(0, int(float(v)))
	return 0

func _reset_dialogue_state() -> void:
	adventurers_hired_this_run = 0
	deaths_this_run = 0
	dialogue_flags = {}
	den_fa_state = "early"            # silently, like a load: no den_fa_state_changed
	_den_fa_tier_warnings = 0         # "once a run": a New Game warns again

## Den Fa's state for a reputation tier index (Story 10.3, pure): "late" at late_index or above, "mid" at
## mid_index or above, else "early"; never earlier than `current` (an unknown current counts as early).
static func den_fa_state_for(current: String, tier_index: int, mid_index: int, late_index: int) -> String:
	var want := 2 if tier_index >= late_index else (1 if tier_index >= mid_index else 0)
	return DEN_FA_STATES[maxi(DEN_FA_STATES.find(current), want)]

## The tier indexes (in `tiers`, a reputation_tier_list) where Den Fa moves to mid and late, from config
## `cfg` ({"mid": label, "late": label}). An unknown label, late at or below mid, or no config: the defaults
## (Known, Trusted), else the second and third tiers, and a warning text naming the tiers used for the caller
## to push (pure: {mid, late, warning}). With fewer than 3 tiers there is no room for both: Mid and Late are
## unreachable (DEN_FA_UNREACHABLE) and he stays early.
static func den_fa_tier_indexes(cfg, tiers: Array) -> Dictionary:
	var labels: Array = tiers.map(func(t): return str(t.get("label", "")))
	var mid := labels.find(str(cfg.get("mid", ""))) if cfg is Dictionary else -1
	var late := labels.find(str(cfg.get("late", ""))) if cfg is Dictionary else -1
	if mid >= 0 and late > mid:
		return {"mid": mid, "late": late, "warning": ""}
	var head := "[GameManager] fallback: den_fa_state_tiers %s doesn't name two tiers of reputation_tiers in rising order" % [cfg]
	mid = labels.find(DEN_FA_DEFAULT_TIERS.mid)
	late = labels.find(DEN_FA_DEFAULT_TIERS.late)
	if mid < 0 or late <= mid:   # the defaults aren't in this list either: the second and third tiers
		if tiers.size() < 3:     # no room for Mid and Late above the base tier: he stays early
			return {"mid": DEN_FA_UNREACHABLE, "late": DEN_FA_UNREACHABLE + 1,
				"warning": "%s, and reputation_tiers has %d tier(s), fewer than 3: Den Fa stays early" % [head, tiers.size()]}
		mid = 1
		late = 2
	return {"mid": mid, "late": late, "warning": "%s: using mid %s, late %s" % [head, labels[mid], labels[late]]}

## den_fa_tier_indexes() for a config and the raw reputation_tiers, warning once a run.
func _den_fa_tiers_from(cfg, raw_tiers) -> Dictionary:
	var r := den_fa_tier_indexes(cfg, reputation_tier_list(raw_tiers))
	if r.warning != "" and _den_fa_tier_warnings == 0:
		_den_fa_tier_warnings += 1
		push_warning(r.warning)
	return r

## Move Den Fa's state forward if the reputation has reached his next tier, one state at a time: a jump across
## both tiers is early -> mid, then mid -> late (review patch: no state is skipped). GuildBus.den_fa_state_changed
## means "earned in play": `announce` false (loading a save) moves him without it.
func _update_den_fa_state(announce := true) -> void:
	var raw = DataManager.get_config("reputation_tiers", [])
	var at := _den_fa_tiers_from(DataManager.get_config("den_fa_state_tiers"), raw)
	var target := den_fa_state_for(den_fa_state, reputation_tier_index_for(tavern_reputation, reputation_tier_list(raw)), at.mid, at.late)
	var from := maxi(0, DEN_FA_STATES.find(den_fa_state))   # an unknown value counts as early
	den_fa_state = DEN_FA_STATES[from]
	for i in range(from, DEN_FA_STATES.find(target)):
		var old: String = DEN_FA_STATES[i]
		den_fa_state = DEN_FA_STATES[i + 1]
		if announce:
			print("[GameManager] advance: Den Fa %s -> %s (reputation %d)" % [old, den_fa_state, tavern_reputation])
			GuildBus.den_fa_state_changed.emit(old, den_fa_state)
		else:
			print("[GameManager] load: Den Fa %s -> %s (reputation %d)" % [old, den_fa_state, tavern_reputation])

func get_patron_recruitment_pool() -> Array:
	"""Get current patron recruitment candidates"""
	return patron_recruitment_pool

func clear_patron_recruitment_pool():
	"""Clear all patron recruitment candidates (for testing)"""
	patron_recruitment_pool.clear()
	print("Patron recruitment pool cleared")


# In GameManager.gd
func check_additional_failure_conditions():
	"""Check for other game over conditions"""
	
	# No adventurers and no gold to hire new ones
	#if adventurers.size() == 0 and gold < 20:
	#	pass
	#	trigger_game_over("no_adventurers", "No adventurers and insufficient gold to hire new ones")
	
	# Extended period without income
	if beer_stock == 0 and gold < 5 and current_day > 10:
		pass
		trigger_game_over("abandoned_tavern", "Tavern abandoned - no customers for too long")

func trigger_game_over(failure_type: String, reason: String):
	"""Trigger game over state and stop all game processes"""
	if game_over_active:
		return  # Prevent multiple game overs
		
	game_over_active = true
	log_message("FAILURE: " + reason)
	log_message("GAME OVER!")
	
	# Stop all game processes
	set_process_mode(Node.PROCESS_MODE_DISABLED)
	
	# Emit signal to show game over screen
	game_over_triggered.emit("Tax Bankruptcy: " + reason)


func reset_game_state():
	print("Resetting game state...")
	_apply_config()
	current_day = 1

	adventurers.clear()
	beer_shortage_days = 0
	adventurer_morale.clear()
	
	# Recruitment
	daily_recruits.clear()
	recruit_refresh_day = 0
	patron_recruitment_pool.clear()
	hired_tarot_cards.clear()  # fresh deck for a new run (Epic 4.1)
	
	# Missions
	available_missions.clear()
	active_missions.clear()      # adventurers currently out — must not carry into a new run
	pending_reports.clear()
	has_pending_briefing = false
	mission_refresh_day = 1

	# Progression / run stats (a New Game must not inherit the previous run's progress)
	total_missions_completed = 0
	tavern_reputation = 0
	taxes_paid_count = 0
	tax_grace_days = 0
	mission_tier_unlocked = 1
	_reset_dialogue_state()  # run counters + conversation flags (Story 10.2)
	
	# Game state
	game_over_active = false
	
	# Re-enable processing
	set_process_mode(Node.PROCESS_MODE_INHERIT)
	
	# Emit all signals to refresh UI
	gold_changed.emit(gold)
	beer_changed.emit(beer_stock)
	day_changed.emit(current_day)
	firewood_changed.emit(firewood_stock)
	fireplace_fuel_changed.emit(fireplace_fuel)
	adventurer_roster_changed.emit()
	
	print("Game state reset to initial values")



func process_adventurer_beer_consumption() -> bool:
	"""Handle daily beer consumption with harsh consequences for shortages"""
	var adventurer_count = adventurers.size()
	var pints_needed = adventurer_count
	
	if adventurer_count == 0:
		beer_shortage_days = 0  # Reset when no adventurers
		return true
	
	print("Processing beer consumption: Need ", pints_needed, " pints, have ", beer_stock, " pints")
	
	if beer_stock >= pints_needed:
		# Sufficient beer - happy adventurers
		consume_beer_pints(pints_needed)
		beer_shortage_days = 0  # Reset shortage counter
		
		# Set all adventurers to high morale
		for adventurer in adventurers:
			adventurer_morale[adventurer.get("id", adventurer.name)] = 3
		
		log_message("Adventurers enjoyed their daily rations (" + str(pints_needed) + " pints)")
		log_message("Guild morale is high - adventurers are content!")
		return true
	else:
		# Beer shortage - apply harsh consequences
		beer_shortage_days += 1
		log_message("BEER SHORTAGE - Day " + str(beer_shortage_days) + "!")
		log_message("Need " + str(pints_needed) + " pints, only have " + str(beer_stock) + " pints")
		
		apply_beer_shortage_consequences()
		return false
		
		
		
func apply_beer_shortage_consequences():
	"""Apply escalating consequences for beer shortages"""
	
	# Consume what beer we have
	if beer_stock > 0:
		var partial_consumption = beer_stock
		consume_beer_pints(partial_consumption)
		log_message("Shared remaining " + str(partial_consumption) + " pint(s) among adventurers")
	
	# Apply consequences based on shortage duration
	match beer_shortage_days:
		1:
			apply_day_1_shortage()
		2:
			apply_day_2_shortage()
		_:
			apply_extended_shortage()
			
func apply_day_1_shortage():
	"""Day 1 shortage: Immediate mission penalty"""
	log_message("Day 1 Shortage Effects:")
	log_message("• Adventurer morale dropping")
	log_message("• Mission success rates reduced by 25%")
	log_message("• Adventurers grumbling about poor conditions")
	
	# Set all adventurers to low morale
	for adventurer in adventurers:
		adventurer_morale[adventurer.get("id", adventurer.name)] = 1
	
	# Add flavor text
	var complaints = [
		"\"Where's our daily ale? This is no way to run a guild!\"",
		"\"My throat's parched and my spirits are low...\"",
		"\"Other guilds take better care of their people.\"",
		"\"How can we fight on empty mugs?\""
	]
	log_message(complaints[randi() % complaints.size()])

func apply_day_2_shortage():
	"""Day 2 shortage: Mission penalties + departure risk"""
	log_message("Day 2 Shortage Effects:")
	log_message("• Mission success rates reduced by 50%")
	log_message("• Adventurers considering leaving the guild")
	log_message("• Guild reputation at risk")
	
	# 50% chance each adventurer leaves
	var leaving_adventurers = []
	for adventurer in adventurers:
		if randf() < 0.5:
			leaving_adventurers.append(adventurer)
	
	# Process departures
	for adventurer in leaving_adventurers:
		adventurers.erase(adventurer)
		adventurer_morale.erase(adventurer.get("id", adventurer.name))
		log_message("" + adventurer.name + " (" + adventurer.class + ") left the guild!")
		log_message("\"" + adventurer.name + " said: 'I can't work under these conditions!'\"")
	
	if leaving_adventurers.size() > 0:
		log_message("" + str(leaving_adventurers.size()) + " adventurer(s) abandoned the guild!")
		adventurer_roster_changed.emit()
	else:
		log_message("Fortunately, all adventurers decided to stay... for now.")

func apply_extended_shortage():
	"""Day 3+ shortage: Guaranteed departures"""
	log_message("Day " + str(beer_shortage_days) + " Shortage - Critical!")
	log_message("• Guild conditions are unbearable")
	log_message("• Adventurers abandoning their posts")
	log_message("• Reputation plummeting throughout the region")
	
	# Guaranteed departures after day 2
	if adventurers.size() > 0:
		var leaving = adventurers.pop_back()
		adventurer_morale.erase(leaving.get("id", leaving.name))
		log_message("" + leaving.name + " (" + leaving.class + ") abandoned the guild!")
		
		var harsh_messages = [
			"\"" + leaving.name + " packed their belongings in disgust.\"",
			"\"" + leaving.name + " said this guild is a disgrace to adventurers.\"",
			"\"" + leaving.name + " vowed never to return to such poor management.\"",
			"\"" + leaving.name + " left without even saying goodbye.\""
		]
		log_message(harsh_messages[randi() % harsh_messages.size()])
		adventurer_roster_changed.emit()
		
		if adventurers.size() == 0:
			log_message("All adventurers have abandoned the guild!")
			log_message("The tavern sits empty, your reputation in ruins...")

# === MISSION SUCCESS RATE MODIFICATIONS ===
func get_beer_shortage_penalty() -> int:
	"""Get mission success penalty based on beer shortage duration"""
	match beer_shortage_days:
		0:
			return 0   # No penalty
		1:
			return 25  # -25% success rate
		2:
			return 50  # -50% success rate
		_:
			return 75  # -75% success rate (near-impossible missions)

func get_adventurer_morale_bonus(adventurer: Dictionary) -> int:
	"""Get mission bonus/penalty based on individual adventurer morale"""
	var adventurer_id = adventurer.get("id", adventurer.name)
	var morale = adventurer_morale.get(adventurer_id, 2)  # Default to neutral
	
	match morale:
		3:
			return 10   # +10% when happy
		2:
			return 0    # No modifier when neutral
		1:
			return -15  # -15% when unhappy (stacks with shortage penalty)
		_:
			return 0

# === INTEGRATION WITH EXISTING MISSION SYSTEM ===
func calculate_mission_success_with_beer_effects(base_chance: int, adventurer: Dictionary) -> int:
	"""Apply beer shortage and morale effects to mission success calculation"""
	var shortage_penalty = get_beer_shortage_penalty()
	var morale_effect = get_adventurer_morale_bonus(adventurer)
	
	var modified_chance = base_chance - shortage_penalty + morale_effect
	
	# Log the effects for transparency
	if shortage_penalty > 0:
		log_message("Beer shortage penalty: -" + str(shortage_penalty) + "%")
	if morale_effect != 0:
		var effect_text = "+" if morale_effect > 0 else ""
		log_message("" + adventurer.name + " morale effect: " + effect_text + str(morale_effect) + "%")
	
	# Ensure minimum 5% chance, maximum 95%
	return clampi(modified_chance, 5, 95)

# === DAILY PROCESSING INTEGRATION ===
func apply_daily_wages() -> int:
	"""Deduct each roster adventurer's daily wage (all statuses except DEAD) at day start,
	before the morning briefing. Gold floors at 0 (never negative). Empty roster = no-op.
	Emits gold_changed once. Story 4.4."""
	var total := 0
	for adv in adventurers:
		if adv.get("status") == AStatus.DEAD:
			continue  # dead adventurers draw no wage (defensive — should be removed at Reveal)
		total += int(adv.get("daily_wage", 1))
	if total <= 0:
		return 0  # nothing owed — no deduction, no signal
	var paid := total
	if total > gold:
		paid = gold  # pay what we can; floor at 0
		log_message("[GameManager] warn: insufficient gold for wages on day " + str(current_day))
	gold = max(0, gold - paid)
	gold_changed.emit(gold)
	log_message("Paid " + str(paid) + " gold in adventurer wages (" + str(total) + " owed).")
	return paid

func process_daily_operations_with_beer():
	# Wages moved to apply_daily_wages() (Story 4.4 — per-adventurer, runs before the briefing).
	pass

# === STATUS REPORTING ===
func get_guild_status_report() -> String:
	"""Generate a comprehensive guild status report"""
	var report = "=== GUILD STATUS REPORT ===\n"
	report += "Day: " + str(current_day) + "\n"
	report += "Gold: " + str(gold) + "\n"
	report += "Beer Stock: " + str(beer_stock) + " pints\n"
	report += "Adventurers: " + str(adventurers.size()) + "/" + str(max_adventurers) + "\n"
	
	if beer_shortage_days > 0:
		report += "BEER SHORTAGE: Day " + str(beer_shortage_days) + "\n"
		report += "Mission Penalty: -" + str(get_beer_shortage_penalty()) + "%\n"
	else:
		report += "Beer supplies adequate\n"
	
	# Morale breakdown
	var high_morale = 0
	var neutral_morale = 0
	var low_morale = 0
	
	for adventurer in adventurers:
		var morale = adventurer_morale.get(adventurer.get("id", adventurer.name), 2)
		match morale:
			3: high_morale += 1
			2: neutral_morale += 1
			1: low_morale += 1
	
	report += "Morale - High: " + str(high_morale) + ", Neutral: " + str(neutral_morale) + ", Low: " + str(low_morale) + "\n"
	report += "========================\n"
	
	return report


func add_beer_pints(pints: int):
	"""Add beer stock in pints and notify systems"""
	beer_stock += pints
	beer_changed.emit(beer_stock)
	print("Added ", pints, " pint(s). Total: ", beer_stock, " pints")

func consume_beer_pints(pints: int) -> bool:
	"""Thin wrapper — routes through consume_drink() (the single authority)."""
	return consume_drink("beer", pints)

func get_beer_pints() -> int:
	"""Get current beer stock in pints"""
	return beer_stock

# count_active_patrons() removed — fuel drain now handled by fireplace_zone.gd


func set_fireplace_fuel(new_value: float):
	"""Called by fireplace_zone.gd to update fuel level. Single source of truth."""
	var old_fuel = fireplace_fuel
	fireplace_fuel = clampf(new_value, 0.0, 100.0)
	if int(old_fuel) != int(fireplace_fuel):
		fireplace_fuel_changed.emit(fireplace_fuel)

# stoke_fireplace() removed 2026-07-05 — dead code (zero callers). Fireplace stoking runs through
# the minigame → consume_firewood(), which is now the single firewood drain authority. (Story 3.3)

func _process(_delta):
	# Fireplace fuel is now managed entirely by fireplace_zone.gd state machine
	# GameManager only holds the value for tip calculations
	# See fireplace_zone.gd for the burn state machine (DORMANT → BURNING_HIGH → BURNING_LOW → DYING)
	pass





func calculate_patron_tip() -> Dictionary:
	"""Calculate tip based on fireplace comfort level + reputation (Epic 14). Returns breakdown for UI feedback."""
	var base_tip = 6.0
	var comfort_ratio = fireplace_fuel / 100.0
	var reputation_bonus: float = get_reputation_tier().get("tip_bonus", 0.0)
	var tip_amount = int(base_tip * comfort_ratio * (1.0 + reputation_bonus))

	var comfort_desc = ""
	if comfort_ratio >= 0.75:
		comfort_desc = "Cozy atmosphere"
	elif comfort_ratio >= 0.5:
		comfort_desc = "Warm enough"
	elif comfort_ratio >= 0.25:
		comfort_desc = "A bit chilly"
	else:
		comfort_desc = "Freezing cold"

	return {
		"amount": tip_amount,
		"comfort_ratio": comfort_ratio,
		"comfort_desc": comfort_desc,
		"fire_percent": int(fireplace_fuel),
		"reputation_bonus": reputation_bonus
	}


# === CUSTOMER SERVICE WITH CLEAR ECONOMICS ===
func serve_customer_beer() -> int:
	"""Serve beer to customer with fire-based tip calculation"""
	if consume_beer_pints(1):
		var payment = 6  # Base payment for beer
		var tip_info = calculate_patron_tip()  # Fire-based tip
		var tip = tip_info.amount
		var total = payment + tip

		add_gold(total)
		daily_patron_visits += 1  # Track for statistics

		if tip > 0:
			log_message("Served 1 pint: " + str(payment) + "g + " + str(tip) + "g tip (" + tip_info.comfort_desc + " — Fire: " + str(tip_info.fire_percent) + "%)")
		else:
			log_message("Served 1 pint: " + str(payment) + "g — No tip! (" + tip_info.comfort_desc + ")")
		
		return total
	else:
		log_message("Cannot serve customer - no beer available!")
		return 0
		
		
func get_adventurer_status_description(adventurer: Dictionary) -> String:
	match adventurer.status:
		AStatus.READY:
			return "Available for missions"
		AStatus.WOUNDED:
			var days = adventurer.get("recovery", 0)
			return "Wounded (" + str(days) + " day" + ("s" if days != 1 else "") + " remaining)"
		AStatus.RESTING:
			var days = adventurer.get("recovery", 0)
			return "Resting (" + str(days) + " day" + ("s" if days != 1 else "") + " remaining)"
		AStatus.ON_MISSION:
			return "Currently on mission"
		_:
			return "Status unknown"


func get_guild_availability_report() -> Dictionary:
	"""Get comprehensive availability report"""
	var ready = get_ready_adventurers()
	var unavailable = get_unavailable_adventurers()
	
	var resting_count = 0
	var injured_count = 0
	var on_mission_count = 0
	
	for adv in unavailable:
		match adv.status:
			AStatus.RESTING:
				resting_count += 1
			AStatus.WOUNDED:
				injured_count += 1
			AStatus.ON_MISSION:
				on_mission_count += 1
	
	return {
		"total_adventurers": adventurers.size(),
		"ready": ready.size(),
		"resting": resting_count,
		"injured": injured_count,
		"on_mission": on_mission_count,
		"availability_percentage": (ready.size() * 100) / max(1, adventurers.size())
	}



func log_daily_availability_status():
	"""Log current availability status each morning"""
	var report = get_guild_availability_report()
	
	if report["ready"] == 0:
		log_message("NO ADVENTURERS AVAILABLE for missions today!")
	elif report["ready"] == report["total_adventurers"]:
		log_message("All " + str(report["total_adventurers"]) + " adventurers are ready for missions")
	else:
		log_message("Guild Status: " + str(report["ready"]) + "/" + str(report["total_adventurers"]) + " adventurers available")
		
		if report["injured"] > 0:
			log_message("" + str(report["injured"]) + " adventurer(s) recovering from injuries")
		if report["resting"] > 0:
			log_message("" + str(report["resting"]) + " adventurer(s) resting after missions")

func check_adventurer_level_up(adventurer: Dictionary):
	"""Placeholder for level up system"""
	pass

func handle_party_failure_consequences(adventurer: Dictionary, mission: Dictionary):
	"""Handle the brutal consequences of mission failure"""
	var adventurer_level = get_adventurer_level(adventurer)
	var death_chance = calculate_death_chance(adventurer_level, mission.danger)
	
	var death_roll = randf()
	
	log_message("" + adventurer.name + " faces danger (Level " + str(adventurer_level) + " vs Danger " + str(mission.danger) + ")")
	log_message("Death chance: " + str(int(death_chance * 100)) + "% (Rolled: " + str(int(death_roll * 100)) + ")")
	
	if death_roll < death_chance:
		# ADVENTURER DIES
		handle_adventurer_death(adventurer, mission)
	else:
		# INJURED BUT SURVIVES
		handle_adventurer_injury(adventurer, mission)

static func roll_loot() -> String:
	var roll = randf()
	if roll < 0.05:
		return "artifact"
	elif roll < 0.25:
		return "equipment"
	else:
		return "gold"

func _roll_and_apply_loot(recipient: Dictionary, base_reward: int) -> Dictionary:
	"""Epic 12 — rolls a loot tier via roll_loot() and applies its effect. Called once per
	successful mission resolution (not per party member). Returns a dict describing what
	happened; callers fold the "gold" tier silently into the mission reward and only surface
	"equipment"/"artifact" in the reveal report — per 01_VISION.md, loot isn't a battle-report
	line, so most successes (75% of them) should look exactly like they always have."""
	var tier := roll_loot()
	match tier:
		"equipment":
			var item_id := DataManager.get_random_equipment_id()
			if item_id == "":
				return {"tier": "gold", "bonus": 0}  # no equipment data loaded — fall back quietly
			var def: Dictionary = DataManager.equipment.get(item_id, {})
			var stat: String = def.get("stat", "")
			var bonus: int = int(def.get("bonus", 0))
			if stat != "" and recipient.has(stat):
				recipient[stat] = int(recipient.get(stat, 0)) + bonus
			recipient["equipped_item"] = {
				"id": item_id,
				"name": def.get("display_name", item_id),
				"stat": stat,
				"bonus": bonus,
			}
			return {"tier": "equipment", "name": def.get("display_name", item_id)}
		"artifact":
			var artifact_id := DataManager.get_random_artifact_id()
			if artifact_id == "":
				return {"tier": "gold", "bonus": 0}
			SaveSystem.record_artifact_found(artifact_id)
			var def: Dictionary = DataManager.artifacts.get(artifact_id, {})
			return {"tier": "artifact", "name": def.get("display_name", artifact_id)}
		_:  # "gold"
			var bonus := int(base_reward * randf_range(0.10, 0.25))
			return {"tier": "gold", "bonus": bonus}

func calculate_death_chance(adventurer_level: int, mission_danger: int) -> float:
	"""Calculate death chance based on your design requirements"""
	var base_death_chance: float
	
	# Death rates by adventurer level (your specified rates)
	match adventurer_level:
		1:
			base_death_chance = 0.35  # 35% base death rate (30-40% range)
		2, 3:
			base_death_chance = 0.175  # 17.5% base death rate (15-20% range)
		4, 5:
			base_death_chance = 0.075  # 7.5% base death rate (5-10% range)
		_:
			base_death_chance = 0.05   # 5% for veterans (level 6+)
	
	# Mission danger multiplier
	var danger_multiplier = 1.0 + (mission_danger - 1) * 0.3  # +30% per danger level above 1
	
	# Beer shortage penalty (from existing system)
	var beer_penalty = 0.0
	if beer_shortage_days > 0:
		beer_penalty = beer_shortage_days * 0.1  # +10% death chance per day of shortage
	
	var final_death_chance = base_death_chance * danger_multiplier + beer_penalty
	
	# Cap at 80% max death chance (always some hope)
	return min(final_death_chance, 0.8)

func get_adventurer_level(adventurer: Dictionary) -> int:
	"""Calculate adventurer level based on completed missions"""
	var missions_completed = adventurer.get("missions_completed", 0)
	
	if missions_completed < 3:
		return 1  # Fresh recruits
	elif missions_completed < 8:
		return 2  # Some experience
	elif missions_completed < 15:
		return 3  # Proven survivors
	elif missions_completed < 25:
		return 4  # Experienced adventurers
	elif missions_completed < 40:
		return 5  # Veterans
	else:
		return 6  # Legendary heroes

func handle_adventurer_death(adventurer: Dictionary, mission: Dictionary):
	"""Handle permanent adventurer death with dramatic narrative"""
	var death_messages = [
		adventurer.name + " fought valiantly but was overwhelmed",
		adventurer.name + " made the ultimate sacrifice during " + mission.name,
		"The guild mourns the loss of " + adventurer.name,
		adventurer.name + " fell in battle, but their courage will be remembered"
	]
	
	log_message("" + death_messages[randi() % death_messages.size()])
	
	# Story 7.1 — commit the death to the eternal layer BEFORE any reveal panel plays:
	# cemetery/codex record first, then the legacy-layer signal, then drop from the active
	# roster. The morning-briefing reveal only ever reads this already-committed state.
	SaveSystem.record_fallen_hero(adventurer)
	LegacyBus.adventurer_died.emit(adventurer)

	# Remove from adventurer roster
	adventurers.erase(adventurer)
	_count_death()
	adventurer_roster_changed.emit()
	on_adventurer_died(adventurer)

	# Death has economic consequences - funeral costs
	var funeral_cost = randi_range(5, 15)
	if spend_gold(funeral_cost):
		log_message("Paid " + str(funeral_cost) + " gold for " + adventurer.name + "'s funeral")
	else:
		log_message("Could not afford proper funeral rites for " + adventurer.name)
	
	# Check for guild collapse
	if adventurers.size() == 0:
		log_message("ALL ADVENTURERS HAVE PERISHED!")
		log_message("Visit the recruitment desk immediately to rebuild your guild!")

func handle_adventurer_injury(adventurer: Dictionary, mission: Dictionary):
	var injury_severity = randi_range(2, 5)

	adventurer.status = AStatus.WOUNDED
	adventurer.recovery = injury_severity
	adventurer.injuries_sustained = adventurer.get("injuries_sustained", 0) + 1
	
	log_message("" + adventurer.name + " survived but is badly injured")
	log_message("" + adventurer.name + " needs " + str(injury_severity) + " day(s) to recover")



func check_tier_unlocks():
	"""Check and unlock new mission tiers based on progression"""
	var previous_tier = mission_tier_unlocked
	
	# Check Tier 2 unlock
	if mission_tier_unlocked == 1 and taxes_paid_count >= 1:
		mission_tier_unlocked = 2
		log_message("TIER 2 MISSIONS UNLOCKED!")
		log_message("New contract types are now available at the mission board.")
	
	# Check Tier 3 unlock
	elif mission_tier_unlocked == 2 and tavern_reputation >= 50 and current_day >= 60 and total_missions_completed >= 10:
		mission_tier_unlocked = 3
		log_message("TIER 3 MISSIONS UNLOCKED!")
		log_message("Elite contracts are now available - high risk, high reward!")
	
	# Refresh missions if tier changed
	if mission_tier_unlocked > previous_tier:
		refresh_available_missions()



func get_tier_unlock_status(tier: int) -> Dictionary:
	"""Get unlock status for a specific tier"""
	if tier == 1:
		return {"unlocked": true, "description": "Basic guild contracts"}
	
	var requirements = tier_requirements.get(tier, {})
	var status = {"unlocked": false, "missing": [], "description": requirements.get("description", "")}
	
	if tier == 2:
		if taxes_paid_count >= requirements.get("taxes_paid", 1):
			status.unlocked = true
		else:
			status.missing.append("Pay first tax (Day " + str(tax_due_day) + ")")
	
	elif tier == 3:
		status.unlocked = true  # Start assuming unlocked
		
		if tavern_reputation < requirements.get("reputation", 50):
			status.unlocked = false
			status.missing.append("Reputation: " + str(tavern_reputation) + "/" + str(requirements.get("reputation", 50)))
		
		if current_day < requirements.get("day", 60):
			status.unlocked = false
			status.missing.append("Day: " + str(current_day) + "/" + str(requirements.get("day", 60)))
		
		if total_missions_completed < requirements.get("missions_completed", 10):
			status.unlocked = false
			status.missing.append("Missions: " + str(total_missions_completed) + "/" + str(requirements.get("missions_completed", 10)))
	
	return status

func refresh_available_missions():
	"""Refresh the mission pool with tier restrictions"""
	if DataManager and DataManager.has_method("generate_daily_missions_with_tiers"):
		var new_missions = DataManager.generate_daily_missions_with_tiers(6, mission_tier_unlocked)
		available_missions.clear()
		for mission in new_missions:
			available_missions.append(mission)
		mission_refresh_day = current_day
		missions_changed.emit()
		print("Refreshed missions (Tier ", mission_tier_unlocked, "): ", available_missions.size(), " missions loaded")
	else:
		# Fallback
		var fallback_missions = generate_fallback_missions()
		available_missions.clear()
		for mission in fallback_missions:
			available_missions.append(mission)
		missions_changed.emit()   # the hall's notice board recounts on this too (Story 25.7 review)
		print("Using fallback missions")
	WorldManager.assign_missions_to_hexes(available_missions)


# === MOD-8 PLUGIN HOOKS ===

# MOD-8 plugin hook — logic added per system epic
func on_patron_spawned(patron_data: Dictionary) -> void:
	GameBus.patron_spawned.emit(patron_data)

# MOD-8 plugin hook — logic added per system epic
func on_mission_resolved(mission_result: Dictionary) -> void:
	GameBus.mission_resolved.emit(mission_result)

# MOD-8 plugin hook — logic added per system epic
func on_day_advanced(day_number: int) -> void:
	GameBus.day_advanced.emit(day_number)

# MOD-8 plugin hook — logic added per system epic
func on_adventurer_hired(adventurer_data: Dictionary) -> void:
	AdventurerBus.adventurer_hired.emit(adventurer_data)

# MOD-8 plugin hook — logic added per system epic
func on_adventurer_died(adventurer_data: Dictionary) -> void:
	AdventurerBus.adventurer_died.emit(adventurer_data)
