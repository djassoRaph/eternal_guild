# GameManager.gd - Autoload Singleton
extends Node

const AStatus = AdventurerStatus.Status

# === CORE GAME STATE ===
var gold: int = 1000
var gold_peak: int = 1000   # the most gold this run has held (Story 13.4: the fall screen; Fame, Story 20.1)
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
var _tax_warnings: int = 0   # a bad tax_* config is warned about once a run (Story 13.1; New Game re-arms it)
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
var _no_traits_warned := false   # an empty traits.json is warned about once a session (Story 4.2)
const TRAIT_WOUND_DAYS := 2      # Reckless's injury on a successful contract (Story 4.2 review P2): days WOUNDED
var game_over_active: bool = false
var last_run_summary: Dictionary = {}   # the run's numbers frozen at the fall (Story 13.4, run_summary); not saved
var beer_shortage_days: int = 0
var adventurer_morale: Dictionary = {}  # adventurer_id -> morale level (1-3)

# === Progression Tracking ===
var total_missions_completed: int = 0
var tavern_reputation: int = 0
var reputation_peak_tier: int = 0   # the highest reputation tier index this run has reached (Story 14.6 review P9; saved; New Game: 0)
var taxes_paid_count: int = 0

var active_missions: Array = []       # Missions currently in progress with countdown timers
var pending_reports: Array = []       # Resolved mission results waiting to be shown in morning briefing
var has_pending_briefing: bool = false # Flag for morning briefing UI to check
var _party_missions_warned := false   # a bad demo_party_missions is warned about once a session (Story 6.5)
var _party_missions_warnings: Array = []   # what that gate let through (Story 6.5 review P7, P8)

# === Dialogue state (Story 10.2): what conversations may notice this run, read through dialogue_bridge.gd ===
var adventurers_hired_this_run: int = 0
var deaths_this_run: int = 0
var fallen_this_run: Array = []        # Story 14.4 review P4: this run's dead, by name (the mourner's lost one), saved per run
var dialogue_flags: Dictionary = {}    # conversation flag id -> true (e.g. "den_fa_first_contact"), saved per run
# Den Fa's state (Story 10.3): "early" -> "mid" -> "late", forward only, moved by adjust_reputation() at the
# tiers named in game_config.json's den_fa_state_tiers; saved per run; GuildBus.den_fa_state_changed on each step
# earned in play (loading a save and New Game are silent).
const DEN_FA_STATES := ["early", "mid", "late"]
const DEN_FA_DEFAULT_TIERS := {"mid": "Known", "late": "Trusted"}
const DEN_FA_UNREACHABLE := 1 << 30    # a tier index no reputation reaches (too few tiers for Mid and Late)
var den_fa_state: String = "early"
var _den_fa_tier_warnings: int = 0     # a bad den_fa_state_tiers is warned about once a run (New Game re-arms it)
## Story 18.5 (DC-12): Den Fa has said his line about the Codex in the hall this run (the book on the trunk opens
## directly after that). Saved with the run's dialogue state; a New Game or New Run resets it (he says it again).
var codex_first_opened := false



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
	call_deferred("_add_day_clock")   # Story 3.7: the one persistent day clock (a child, so it lives across scenes)

func _apply_config():
	gold = DataManager.get_config("starting_gold", 1000)
	gold_peak = gold   # a run starts at its starting gold (Story 13.4)
	beer_stock = DataManager.get_config("starting_beer", 5)
	max_adventurers = DataManager.get_config("max_adventurers", 5)
	max_firewood_storage = DataManager.get_config("max_firewood_storage", 10)
	firewood_stock = DataManager.get_config("starting_firewood", 0)
	fireplace_fuel = DataManager.get_config("starting_fireplace_fuel", 0.0)
	tax_due_day = int(tax_config().first_due_day)   # the first due day (Story 13.1: game_config.json tax_due_day)
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
	if staff.is_empty():
		_reset_staff_state()   # Story 16.1: the profile's starting staff before any New Game or load (a direct hall launch)
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
	gold_peak = maxi(gold_peak, gold)   # Story 13.4: income is the only way up
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

func adjust_reputation(delta: int, reason := "") -> void:
	"""Single-authority reputation mutator (Epic 14) — clamps at 0, moves Den Fa's state forward (Story 10.3),
	then (Story 14.6, DP-5) GuildBus.reputation_adjusted(the change applied, the new value, reason) when it moved,
	GuildBus.reputation_tier_changed(old label, new label) when the tier changed, GuildBus.reputation_tier_reached(label)
	the first time this run reaches a tier (review P9: reputation_peak_tier; the banner's signal), and reputation_changed
	as before. A load and a New Game set the value directly: the new signals mean "earned in play"."""
	var old := tavern_reputation
	var tiers := reputation_tier_list(DataManager.get_config("reputation_tiers", []))
	var old_tier := reputation_tier_index_for(old, tiers)
	tavern_reputation = maxi(0, tavern_reputation + delta)
	_update_den_fa_state()
	var applied := tavern_reputation - old
	if applied != 0:
		print("[GameManager] reputation: %+d %s (now %d)" % [applied, reason, tavern_reputation])
		GuildBus.reputation_adjusted.emit(applied, tavern_reputation, reason)
	var new_tier := reputation_tier_index_for(tavern_reputation, tiers)
	if new_tier != old_tier:
		GuildBus.reputation_tier_changed.emit(str(tiers[old_tier].get("label", "")), str(tiers[new_tier].get("label", "")))
	if new_tier > reputation_peak_tier:
		reputation_peak_tier = new_tier
		GuildBus.reputation_tier_reached.emit(str(tiers[new_tier].get("label", "")))
	reputation_changed.emit(tavern_reputation)
	_update_demo_ending()   # Story 10.7: reputation is one of the demo ending's two conditions

## Story 14.6 review P9: the run's highest tier from a save (pure): the saved index, never below the loaded reputation's
## tier (`current_index`); an older save without one, or junk, is that tier.
static func reputation_peak_from_save(v, current_index: int) -> int:
	return maxi(maxi(0, _save_int(v, 0)), current_index)

# === Reputation gains (Story 14.6, DP-3) ===
# Each source's gain is a game_config.json key (a profile can override it: the demo's are faster). The top level is the
# full game's: today's numbers, so a group success and a satisfied patron give 0 there, and a zero gain makes no call.
const REP_DEFAULTS := {"rep_mission_success": 2, "rep_mission_failure": -1, "rep_party_mission_success": 0,
	"rep_party_mission_failure": -1, "rep_dismiss": -1, "rep_patron_satisfied": 0}
var _rep_warnings: int = 0          # a bad rep_* value is warned about once a run (New Game re-arms it)
var _death_mult_warnings: int = 0   # a bad death_chance_multiplier, the same (Story 14.6, K-8)

## A gain's value (pure): a whole number as itself; missing -> REP_DEFAULTS' (today's), silently; anything else -> today's,
## with a warning text appended to `warn`.
static func rep_gain_from(key: String, v, warn: Array = []) -> int:
	var d: int = int(REP_DEFAULTS.get(key, 0))
	if v == null:
		return d
	var n = _whole_number(v)
	if n == null:
		warn.append("[GameManager] fallback: %s is %s, not a whole number; using %d" % [key, v, d])
		return d
	return int(n)

## A reputation source's gain for the active profile (rep_gain_from on game_config.json), warned once a run.
func rep_gain(key: String) -> int:
	var warn: Array = []
	var g := rep_gain_from(key, DataManager.get_config(key), warn)
	if not warn.is_empty() and _rep_warnings == 0:
		_rep_warnings += 1
		push_warning(warn[0])
	return g

## Move reputation by a source's gain, with its reason; a zero gain makes no call (no signal).
func _gain_reputation(key: String, reason: String) -> void:
	var d := rep_gain(key)
	if d != 0:
		adjust_reputation(d, reason)

## A patron finished their drink and paid (RealisticPatron, whoever served them): rep_patron_satisfied (Story 14.6; PRD
## §4.9, reputation from fulfilled patron service; 0 in the full game).
func patron_satisfied() -> void:
	_gain_reputation("rep_patron_satisfied", "patron_satisfied")

## Staff at the start (Story 25.13, K9: "Available right away in the demo. But then have to unlock in the
## real game"): in the demo profile the roles listed in demo_start_staff are hired from the first morning;
## in the full profile nobody is until Epic 16 hires them.
static func staff_hired_by_profile(profile: String, start_staff: Array, role: String) -> bool:
	return profile == "demo" and start_staff.has(role)

# === STAFF (Epic 16) ===
# Story 16.1: one record per staff role in data/characters/staff.json, owned here (the single authority, like
# den_fa_state) and saved as "staff": {staff_id "<role>/<variant>", role, variant, name (the role's display name: no
# personal names yet, 25.13 K8), daily_wage (game_config.json staff_wages, so a profile can override it), hired,
# on_strike, owed, missed_days}. Seeded from the profile (staff_hired_by_profile: the demo's starting staff, K9) on New
# Game, on a save without staff, and once at data-ready. hire_staff / dismiss_staff are the one way in and out; they
# emit GuildBus.staff_hired / staff_fired, which the hall's staff walk in and out on. GameManager never listens to them
# (Test 19 drives the bodies by emitting them itself). Story 16.5 pays the staff each morning (apply_staff_wages).
const STAFF_DATA_PATH := "res://data/characters/staff.json"
var staff: Array = []
var _staff_roles_cache = null      # staff.json's roles, read once a session
var _staff_warned := {}            # warning text -> true: each bad staff config is warned about once a session

## staff.json's roles (role -> its data), read once ({} with a warning when the file has none).
func staff_roles() -> Dictionary:
	if _staff_roles_cache == null:
		var data = JSON.parse_string(FileAccess.get_file_as_string(STAFF_DATA_PATH)) if FileAccess.file_exists(STAFF_DATA_PATH) else null
		var roles = data.get("roles") if data is Dictionary else null
		_staff_roles_cache = roles if roles is Dictionary else {}
		if _staff_roles_cache.is_empty():
			_staff_warn("[GameManager] missing: no staff roles in %s" % STAFF_DATA_PATH)
	return _staff_roles_cache

func _staff_warn(text: String) -> void:
	if not _staff_warned.has(text):
		_staff_warned[text] = true
		push_warning(text)

static func staff_id_for(role: String, variant: String) -> String:
	return "%s/%s" % [role, variant]

## A staff name at the start of a sentence ("the Bartender" -> "The Bartender").
static func staff_title(staff_name: String) -> String:
	return staff_name.substr(0, 1).to_upper() + staff_name.substr(1)

## A role's daily wage from game_config.json's staff_wages ({daily_wage: {role: N}}; Story 16.1, pure). A missing, bad
## or non-positive value is 1, with a warning text appended to `warn`.
static func staff_wage_from(cfg, role: String, warn: Array = []) -> int:
	var table = cfg.get("daily_wage") if cfg is Dictionary else null
	var v = table.get(role) if table is Dictionary else null
	if (v is int or v is float) and int(v) > 0:
		return int(v)
	warn.append("[GameManager] fallback: staff_wages.daily_wage.%s is %s: 1 gold a day" % [role, v])
	return 1

## A fresh record for a role (pure): its default variant and display name, its wage from `wage_cfg`, nothing owed.
static func staff_record_for(role: String, data: Dictionary, wage_cfg, hired: bool, warn: Array = []) -> Dictionary:
	var variant := str(data.get("default_variant", ""))
	return {"staff_id": staff_id_for(role, variant), "role": role, "variant": variant, "name": str(data.get("display_name", role)),
		"daily_wage": staff_wage_from(wage_cfg, role, warn), "hired": hired, "on_strike": false, "owed": 0, "missed_days": 0}

## A run's starting staff (Story 16.1, SR-3, pure): one record per role in `roles`, sorted by role id, hired by the
## profile's rule (staff_hired_by_profile: in "demo" the roles in `start_staff`; in "full" nobody).
static func staff_seed(roles: Dictionary, profile: String, start_staff: Array, wage_cfg, warn: Array = []) -> Array:
	var ids: Array = roles.keys().filter(func(k): return k is String and roles[k] is Dictionary)
	ids.sort()
	var out: Array = []
	for role in ids:
		out.append(staff_record_for(role, roles[role], wage_cfg, staff_hired_by_profile(profile, start_staff, role), warn))
	return out

func _staff_profile() -> String:
	return str(DataManager.get_config("profile", "full"))

func _staff_start() -> Array:
	var s = DataManager.get_config("demo_start_staff", [])
	return s if s is Array else []

## The starting staff for today's config (warnings pushed once).
func _seeded_staff() -> Array:
	var warn: Array = []
	var out := staff_seed(staff_roles(), _staff_profile(), _staff_start(), DataManager.get_config("staff_wages", {}), warn)
	for w in warn:
		_staff_warn(w)
	return out

## A role's record ({} for a role with none). The dictionary itself: GameManager's code writes it, others only read.
func staff_record(role: String) -> Dictionary:
	for r in staff:
		if r is Dictionary and r.get("role") == role:
			return r
	return {}

func staff_record_by_id(staff_id: String) -> Dictionary:
	for r in staff:
		if r is Dictionary and r.get("staff_id") == staff_id:
			return r
	return {}

## Whether a staff role is hired: its record (Story 16.1); a role with no record follows the profile's rule (25.13's,
## so nothing changes before the records are seeded). The hall's staff ask this when they load (staff_npc.gd).
func is_staff_hired(role: String) -> bool:
	var r := staff_record(role)
	if not r.is_empty():
		return r.get("hired") == true
	return staff_hired_by_profile(_staff_profile(), _staff_start(), role)

## Hired and not on strike: the staff's automation runs only then (Stories 16.3, 16.4).
func is_staff_working(role: String) -> bool:
	return is_staff_hired(role) and staff_record(role).get("on_strike") != true

## Why a role can't be hired now (Story 16.1, pure; Story 16.2's panel shows it): "" when it can. In order: an unknown
## role, already hired, locked, then the gold. Locked follows the profile's unlock rule (ctx.unlock, staff_unlock_from;
## none: by tier): by tier, below the role's unlock_tier ("Joins at <tier>."); by gold peak (K-7, the demo: 150), while
## the run's gold peak is below the threshold ("Joins at N gold.", whatever the tier). A role among the demo's starting
## staff is never locked in the demo profile. The gold: the first day's wage (Story 16.5, SW-5) plus what the role is still
## owed (K-12: an unpaid debt stays with the role). ctx: profile, start_staff, tier_index, tiers (the reputation tier
## labels, lowest first), gold; optionally unlock, gold_peak, warn (an Array). DRAFT text.
static func staff_hire_block_for(record: Dictionary, role_data: Dictionary, ctx: Dictionary) -> String:
	if record.is_empty() or role_data.is_empty():
		return "Unknown staff."
	if record.get("hired") == true:
		return "Already hired."
	var start = ctx.get("start_staff", [])
	var demo_start: bool = ctx.get("profile") == "demo" and start is Array and (start as Array).has(record.get("role"))
	if not demo_start:
		var unlock = ctx.get("unlock")
		if unlock is Dictionary and unlock.get("rule") == "gold_peak":
			var threshold := int(unlock.get("gold_peak", 0))
			if int(ctx.get("gold_peak", 0)) < threshold:
				return "Joins at %d gold." % threshold
		else:
			var need := staff_unlock_index(role_data, ctx)
			if int(ctx.get("tier_index", 0)) < need:
				var tiers: Array = ctx.get("tiers", [])
				return "Joins at %s." % (tiers[need] if need >= 0 and need < tiers.size() else "a higher reputation")
	if int(ctx.get("gold", 0)) < staff_hire_cost(record):
		return "Not enough gold."
	return ""

## What hiring a role costs now (pure): the first day's wage plus what the role is still owed (K-12).
static func staff_hire_cost(record: Dictionary) -> int:
	return int(record.get("daily_wage", 1)) + maxi(0, int(record.get("owed", 0)))

## The tier index (in ctx.tiers) a role unlocks at (staff.json unlock_tier); an unknown label counts as the highest tier,
## with a warning text in ctx.warn (pure).
static func staff_unlock_index(role_data: Dictionary, ctx: Dictionary) -> int:
	var tiers: Array = ctx.get("tiers", [])
	var label := str(role_data.get("unlock_tier", ""))
	var i := tiers.find(label)
	if i < 0:
		var w = ctx.get("warn")
		if w is Array:
			w.append("[GameManager] fallback: unknown unlock_tier '%s' for %s: the highest tier" % [label, role_data.get("display_name", "?")])
		i = maxi(0, tiers.size() - 1)
	return i

## The live context staff_hire_block_for reads (today's profile, reputation tier and gold). Story 14.6 (K-7): also the
## active unlock rule (`unlock`: staff_unlock_rule()) and the run's gold peak, which staff_hire_block_for locks by (Epic 16
## review P2).
func staff_ctx() -> Dictionary:
	var tiers := reputation_tier_list(DataManager.get_config("reputation_tiers", []))
	return {"profile": _staff_profile(), "start_staff": _staff_start(), "tier_index": reputation_tier_index_for(tavern_reputation, tiers),
		"tiers": tiers.map(func(t): return str(t.get("label", ""))), "gold": gold, "warn": [],
		"unlock": staff_unlock_rule(), "gold_peak": gold_peak}

# Story 14.6 (K-7, Raphael 2026-11-01: "in the demo the Bartender and the Quest Dealer are not hired at start; they become
# hireable once the guild has reached 300 gold, and stay unlocked"; amended the same day to 150 gold, the pacing model
# showing nobody reaches 300 in a demo): game_config.json staff_unlock, by profile.
const STAFF_UNLOCK_DEFAULT := {"rule": "tier"}

## The staff unlock rule (pure): {"rule": "tier"} (each role at its staff.json unlock_tier: the full game, Story 16.1) or
## {"rule": "gold_peak", "gold_peak": N} (every role once the run's gold peak reaches N). Missing: tier, silently; anything
## else: tier, with a warning text in `warn`.
static func staff_unlock_from(cfg, warn: Array = []) -> Dictionary:
	if cfg == null:
		return STAFF_UNLOCK_DEFAULT.duplicate()
	if cfg is Dictionary:
		var rule := str(cfg.get("rule", ""))
		if rule == "tier":
			return {"rule": "tier"}
		var n = _whole_number(cfg.get("gold_peak"))
		if rule == "gold_peak" and n != null and int(n) >= 0:
			return {"rule": "gold_peak", "gold_peak": int(n)}
	warn.append("[GameManager] fallback: staff_unlock %s is not {rule: tier} or {rule: gold_peak, gold_peak: a whole number >= 0}; by tier" % [cfg])
	return STAFF_UNLOCK_DEFAULT.duplicate()

## The active profile's staff unlock rule (game_config.json staff_unlock; the demo's: a gold peak of 150).
func staff_unlock_rule() -> Dictionary:
	var warn: Array = []
	var r := staff_unlock_from(DataManager.get_config("staff_unlock"), warn)
	for w in warn:
		_staff_warn(w)
	return r

## Why `role` can't be hired now ("" when it can): staff_hire_block_for with today's values.
func staff_hire_block_reason(role: String) -> String:
	var ctx := staff_ctx()
	var data = staff_roles().get(role)
	var why := staff_hire_block_for(staff_record(role), data if data is Dictionary else {}, ctx)
	for w in ctx.warn:
		_staff_warn(w)
	return why

## Hire a staff role (Story 16.1; Story 16.2's panel calls it): "" when hired, else the reason, with nothing changed.
## The first day's wage, and what the role is still owed (K-12), are paid at once through spend_gold (Story 16.5, SW-5;
## one staff_wage_paid for the total); then GuildBus.staff_hired: the body walks in through the front door (25.13).
func hire_staff(role: String) -> String:
	var why := staff_hire_block_reason(role)
	if why != "":
		return why
	var rec := staff_record(role)
	var wage := int(rec.get("daily_wage", 1))
	var debt := maxi(0, int(rec.get("owed", 0)))
	if not spend_gold(wage + debt):
		return "Not enough gold."
	rec.hired = true
	rec.on_strike = false
	rec.owed = 0
	rec.missed_days = 0
	log_message("[GameManager] staff: hired %s (%d gold a day)" % [rec.name, wage])
	if debt > 0:
		log_message("[GameManager] staff: paid %s's back wages (%d gold)" % [rec.name, debt])
		log_message("Paid %s's back wages: %d gold." % [rec.name, debt])
	log_message("%s is on the payroll. %d gold a day." % [staff_title(str(rec.name)), wage])
	EconomyBus.staff_wage_paid.emit(str(rec.staff_id), wage + debt)   # the first day's wage and the debt (Story 16.5, K-12)
	GuildBus.staff_hired.emit(str(rec.staff_id), role)
	return ""

## Dismiss a hired staff role (Story 16.1; the panel's Dismiss): "" when done, else the reason. The record is cleared
## first (not hired, no strike; a striker's debt stays with the role, K-12: hiring them back pays it), then a striker's
## staff_strike_changed(false), then GuildBus.staff_fired: the body walks out.
func dismiss_staff(role: String) -> String:
	var rec := staff_record(role)
	if rec.is_empty():
		return "Unknown staff."
	if rec.get("hired") != true:
		return "Not hired."
	_release_staff(rec, "[GameManager] staff: dismissed %s" % rec.name, "%s leaves the guild's service." % staff_title(str(rec.name)))
	return ""

## Clear a staff record and tell the bus (dismissed, or left unpaid: Story 16.5). What they are owed stays (K-12).
func _release_staff(rec: Dictionary, system_line: String, player_line: String) -> void:
	var was_striking: bool = rec.get("on_strike") == true
	rec.hired = false
	rec.on_strike = false
	rec.missed_days = 0
	log_message(system_line)
	log_message(player_line)
	if was_striking:
		GuildBus.staff_strike_changed.emit(str(rec.staff_id), false)
	GuildBus.staff_fired.emit(str(rec.staff_id), str(rec.role))

## F12 (Story 16.1): a hired role's strike flag set by hand (testers, Stage D); staff_strike_changed on a change.
func debug_set_staff_strike(role: String, on: bool) -> void:
	var rec := staff_record(role)
	if rec.is_empty() or rec.get("hired") != true or (rec.get("on_strike") == true) == on:
		return
	rec.on_strike = on
	log_message("[GameManager] staff: debug strike %s for %s" % ["on" if on else "off", rec.name])
	GuildBus.staff_strike_changed.emit(str(rec.staff_id), on)

func _staff_save_data() -> Dictionary:
	return {"staff": staff.duplicate(true), "desk_round_day": desk_round_day}

## Story 16.1: the saved staff, read defensively (Story 11.2's rule) and silently (no staff signal: the hall's staff read
## the records when it loads). No key (every save before 16.1): the profile's starting staff; not a list: the same, with a
## warning. Junk entries, unknown and duplicate roles are dropped; each value is checked; a role the save lacks is not hired.
## What a role is owed is kept while it is on strike or not hired (K-12: the debt stays with the role); its missed days
## only on strike.
## Story 16.4: the day of the Quest Dealer's last morning round. A save that doesn't say (every save before 16.4) or says
## junk counts today's round as run (review P4: Continue never sends anyone out the moment the hall loads).
func _load_staff_data(data: Dictionary) -> void:
	_load_staff_records(data.get("staff"))
	desk_round_day = maxi(0, _save_int(data.get("desk_round_day"), current_day))

func _load_staff_records(raw) -> void:
	if raw == null:
		_reset_staff_state()
		return
	if not (raw is Array):
		_staff_warn("[GameManager] load: staff is not a list: the profile's starting staff")
		_reset_staff_state()
		return
	var roles := staff_roles()
	var cfg = DataManager.get_config("staff_wages", {})
	var by_role := {}
	for e in raw:
		if not (e is Dictionary) or not (e.get("role") is String) or not roles.has(e.role) or by_role.has(e.role) \
				or not (roles[e.role] is Dictionary):
			continue
		var rec := staff_record_for(e.role, roles[e.role], cfg, false)
		var variants = roles[e.role].get("variants")
		if e.get("variant") is String and variants is Dictionary and variants.has(e.variant):
			rec.variant = e.variant
			rec.staff_id = staff_id_for(e.role, e.variant)
		if e.get("name") is String and (e.name as String).strip_edges() != "":
			rec.name = e.name
		var w := _save_int(e.get("daily_wage"), int(rec.daily_wage))
		rec.daily_wage = w if w > 0 else int(rec.daily_wage)
		rec.hired = e.get("hired") is bool and e.hired
		rec.on_strike = rec.hired and e.get("on_strike") is bool and e.on_strike
		rec.owed = maxi(0, _save_int(e.get("owed"), 0)) if (rec.on_strike or not rec.hired) else 0
		rec.missed_days = maxi(0, _save_int(e.get("missed_days"), 0)) if rec.on_strike else 0
		by_role[e.role] = rec
	var ids: Array = roles.keys().filter(func(k): return k is String and roles[k] is Dictionary)
	ids.sort()
	var out: Array = []
	for role in ids:
		out.append(by_role[role] if by_role.has(role) else staff_record_for(role, roles[role], cfg, false))
	staff = out

## New Game (and a save without staff): the profile's starting staff.
func _reset_staff_state() -> void:
	staff = _seeded_staff()
	desk_round_day = 0

## Story 16.5 (SW-2): a hired staff member leaves on the morning this many wages in a row went unpaid
## (game_config.json staff_wages.missed_days_to_leave, so a profile can override it). Missing or bad: 3, with a warning.
func staff_missed_days_to_leave() -> int:
	var cfg = DataManager.get_config("staff_wages", {})
	var v = cfg.get("missed_days_to_leave") if cfg is Dictionary else null
	if (v is int or v is float) and float(v) == float(int(v)) and int(v) >= 1:
		return int(v)
	_staff_warn("[GameManager] fallback: staff_wages.missed_days_to_leave is %s: 3" % [v])
	return 3

## Story 16.5: the staff's daily wages, paid each morning right after the adventurers' (advance_day), so before the tax.
## Each hired member is paid in full through spend_gold (the gold authority) or not at all (SW-1): paid ->
## EconomyBus.staff_wage_paid. Short of the wage -> on strike (owes it, missed 1): staff_wage_unpaid, then
## GuildBus.staff_strike_changed(true). A striker isn't paid automatically (the player pays the back wage, Story 16.2's
## panel): each further morning adds the wage to what is owed and counts one more missed day (staff_wage_unpaid); at
## missed_days_to_leave they leave (the record cleared, the debt kept with the role: K-12; staff_strike_changed(false),
## staff_fired). Each unpaid morning logs the player's sentence (staff_unpaid_text, the banner's) beside the system line
## (review P5: a banner can wait its turn). Returns the gold paid. One log line for the total ("the end-of-day summary",
## 16.5 AC 4: the event log).
func apply_staff_wages() -> int:
	var paid := 0
	var leave_after := staff_missed_days_to_leave()
	for rec in staff:
		if not (rec is Dictionary) or rec.get("hired") != true:
			continue
		var wage := wage_of(rec)
		var id := str(rec.staff_id)
		if rec.get("on_strike") != true:
			if spend_gold(wage):
				paid += wage
				EconomyBus.staff_wage_paid.emit(id, wage)
				continue
			rec.on_strike = true
			rec.owed = wage
			rec.missed_days = 1
			log_message("[GameManager] staff: %s unpaid (missed 1, owes %d)" % [rec.name, rec.owed])
			if leave_after > 1:
				log_message(staff_unpaid_text(str(rec.name), 1, leave_after))
			EconomyBus.staff_wage_unpaid.emit(id)
			GuildBus.staff_strike_changed.emit(id, true)
		else:
			rec.owed = maxi(0, int(rec.get("owed", 0))) + wage
			rec.missed_days = maxi(0, int(rec.get("missed_days", 0))) + 1
			log_message("[GameManager] staff: %s unpaid (missed %d, owes %d)" % [rec.name, rec.missed_days, rec.owed])
			if int(rec.missed_days) < leave_after:
				log_message(staff_unpaid_text(str(rec.name), int(rec.missed_days), leave_after))
			EconomyBus.staff_wage_unpaid.emit(id)
		if int(rec.missed_days) >= leave_after:
			_release_staff(rec, "[GameManager] staff: %s left (unpaid %d days)" % [rec.name, rec.missed_days],
				"%s has left the guild, unpaid." % staff_title(str(rec.name)))
	if paid > 0:
		log_message("Paid %d gold in staff wages." % paid)
	return paid

## Story 16.5: an unpaid morning in the player's words (the banner's and the log's; pure). `missed`: unpaid mornings in a
## row; `leave_after`: staff_wages.missed_days_to_leave. DRAFT (Raphael rewrites).
static func staff_unpaid_text(staff_name: String, missed: int, leave_after: int) -> String:
	var who := staff_title(staff_name)
	if missed >= leave_after:
		return "%s has left the guild, unpaid." % who
	if missed <= 1:
		return "%s hasn't been paid — on strike.%s" % [who, " Leaves tomorrow if unpaid." if leave_after == 2 else ""]
	if missed == leave_after - 1:
		return "%s leaves tomorrow if unpaid." % who
	return "%s is still unpaid (%d days)." % [who, missed]

## Story 16.5 (SW-3): pay a striker's back wage (Story 16.2's panel, F12): "" when paid, else the reason, with nothing
## changed. Through spend_gold; the record cleared (no strike, nothing owed); then EconomyBus.staff_wage_paid and
## GuildBus.staff_strike_changed(false): their work resumes. DRAFT text.
func pay_staff_back_wage(role: String) -> String:
	var rec := staff_record(role)
	if rec.is_empty():
		return "Unknown staff."
	if rec.get("hired") != true or rec.get("on_strike") != true:
		return "Not on strike."
	var owed := maxi(0, int(rec.get("owed", 0)))
	if gold < owed or (owed > 0 and not spend_gold(owed)):
		return "Not enough gold (%d)." % owed
	rec.on_strike = false
	rec.owed = 0
	rec.missed_days = 0
	log_message("[GameManager] staff: paid %s's back wages (%d gold)" % [rec.name, owed])
	log_message("Paid %s's back wages: %d gold." % [rec.name, owed])
	EconomyBus.staff_wage_paid.emit(str(rec.staff_id), owed)
	GuildBus.staff_strike_changed.emit(str(rec.staff_id), false)
	return ""

# --- Story 16.4: the Quest Dealer's morning round (FR-65; GDD: the Desk Manager "auto-distributes minor quests to Minor
# Arcana; the player keeps full Major Arcana dispatch control") ---
# Once a morning, while she works, her brain (quest_dealer_ai.gd) calls desk_round(): the READY Minor Arcana with the
# best odds go out on open solo contracts of tier <= desk_auto_max_tier, only at desk_auto_min_chance or better, at most
# desk_auto_per_day, each through dispatch_adventurers (Story 6.5's one front door). Major Arcana, party contracts and long
# odds stay the player's. The numbers are staff_automation's in game_config.json (a profile can override them).
var desk_round_day: int = 0      # the day her last round ran (saved with the staff records; New Game 0)
const DESK_DEFAULTS := {"per_day": 1, "max_tier": 1, "min_chance": 70}   # 70: the World Map's "Good fit" line (Story 6.5)

## The open contracts on the map (pure): [{hex_id, mission}] for each hex record holding a contract nobody is out on.
static func open_map_contracts_in(records: Array) -> Array:
	var out: Array = []
	for rec in records:
		if rec is Dictionary and rec.get("active_mission") is Dictionary and rec.get("locked") != true:
			out.append({"hex_id": str(rec.get("id", "")), "mission": rec.active_mission})
	return out

## Whether an adventurer's Tarot card is a Minor Arcana one (pure; `card_lookup`: card id -> the deck's card). An empty or
## unknown card is not: the player decides for them.
static func is_minor_arcana(adv: Dictionary, card_lookup: Callable) -> bool:
	var id := str(adv.get("tarot_card", ""))
	if id == "":
		return false
	var card = card_lookup.call(id)
	return card is Dictionary and card.get("arcana") == "minor"

## The round's picks (pure): [{id, mission, hex_id, chance}]. `ready`: the READY Minor Arcana; `contracts`:
## open_map_contracts_in's; `cfg`: per_day, max_tier, min_chance; `estimate`: (adventurer, mission) -> chance. Solo
## contracts of tier <= max_tier only, chance >= min_chance; the best chance first (ties: roster order, then map order);
## each adventurer and each contract once; at most per_day.
static func desk_contract_picks(ready: Array, contracts: Array, cfg: Dictionary, estimate: Callable) -> Array:
	var pairs: Array = []
	for ai in ready.size():
		var adv = ready[ai]
		if not (adv is Dictionary):
			continue
		for ci in contracts.size():
			var c = contracts[ci]
			var m = c.get("mission") if c is Dictionary else null
			if not (m is Dictionary) or required_party_size(m) != 1 or int(m.get("tier", 99)) > int(cfg.get("max_tier", 1)):
				continue
			var chance := int(estimate.call(adv, m))
			if chance < int(cfg.get("min_chance", DESK_DEFAULTS.min_chance)):
				continue
			pairs.append({"id": adv.get("id"), "mission": m, "hex_id": str(c.get("hex_id", "")), "chance": chance, "ai": ai, "ci": ci})
	pairs.sort_custom(func(x, y): return x.chance > y.chance or (x.chance == y.chance and (x.ai < y.ai or (x.ai == y.ai and x.ci < y.ci))))
	var out: Array = []
	var used_a := {}
	var used_c := {}
	for p in pairs:
		if out.size() >= int(cfg.get("per_day", 1)):
			break
		if used_a.has(p.ai) or used_c.has(p.ci):
			continue
		used_a[p.ai] = true
		used_c[p.ci] = true
		out.append({"id": p.id, "mission": p.mission, "hex_id": p.hex_id, "chance": p.chance})
	return out

## staff_automation's desk_auto_* (pure): {per_day, max_tier, min_chance}; a bad or missing value takes DESK_DEFAULTS',
## with a warning text in `warn`.
static func desk_config_from(cfg, warn: Array = []) -> Dictionary:
	var out := {}
	for k in [["desk_auto_per_day", "per_day", 0], ["desk_auto_max_tier", "max_tier", 1], ["desk_auto_min_chance", "min_chance", 0]]:
		var v = cfg.get(k[0]) if cfg is Dictionary else null
		if (v is int or v is float) and float(v) == float(int(v)) and int(v) >= int(k[2]):
			out[k[1]] = int(v)
		else:
			out[k[1]] = DESK_DEFAULTS[k[1]]
			warn.append("[GameManager] fallback: staff_automation.%s is %s: %s" % [k[0], v, DESK_DEFAULTS[k[1]]])
	return out

## The Quest Dealer's morning round (Story 16.4): what she sent ([{name, mission, hex_id, chance}]). Nothing (and the day
## not spent) unless she works (hired, not on strike) and today's round hasn't run.
func desk_round() -> Array:
	if game_over_active or not is_staff_working("desk_manager") or desk_round_day == current_day:
		return []
	desk_round_day = current_day
	var warn: Array = []
	var cfg := desk_config_from(DataManager.get_config("staff_automation", {}), warn)
	for w in warn:
		_staff_warn(w)
	var ready: Array = []
	for adv in adventurers:
		if adv is Dictionary and not_ready_reason(adv) == "" and is_minor_arcana(adv, func(id): return DataManager.get_tarot_card(id)):
			ready.append(adv)
	var picks := desk_contract_picks(ready, open_map_contracts_in(WorldManager.world_map), cfg,
		func(a, m): return estimate_success([a], m))
	var sent: Array = []
	for p in picks:
		var who := str(find_adventurer(p.id).get("name", "?"))
		var title := str(p.mission.get("name", "a contract"))
		var why := dispatch_adventurers([p.id], p.mission, p.hex_id)
		if why != "":
			push_warning("[GameManager] desk: %s -> %s (%s) refused: %s" % [who, title, p.hex_id, why])
			continue
		log_message("[GameManager] desk: %s -> %s (%s), chance %d%%" % [who, title, p.hex_id, p.chance])
		log_message("The Quest Dealer sent %s on %s." % [who, title])
		sent.append({"name": who, "mission": title, "hex_id": p.hex_id, "chance": p.chance})
	if sent.is_empty():
		print("[GameManager] desk: no minor contract for a Minor Arcana on day %d" % current_day)
	return sent

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
	"""Dispatch an adventurer on a mission. Does NOT resolve it — just starts the timer. It checks nothing: the World
	Map goes through dispatch_adventurers() (Story 6.5), which checks first."""
	var duration = mission.get("duration_days", 1)

	adventurer.status = AStatus.ON_MISSION
	adventurer["current_mission"] = mission.get("name", "Unknown Mission")

	var active_entry = {
		"adventurer": adventurer,
		"mission": mission,
		"days_remaining": duration,
		"total_duration": duration,
		"success_chance": estimate_success([adventurer], mission),
		"sent_day": current_day,
		"hex_id": hex_id
	}
	active_entry.merge(deployment_record([adventurer], mission, hex_id, current_day))   # Story 6.5 (DD-4)

	active_missions.append(active_entry)
	_lock_hex(hex_id)
	_log_dispatch(active_entry, [adventurer])

	log_message("" + adventurer.name + " departs on: " + mission.get("name", "?") + " (" + str(int(duration)) + " day" + ("s" if int(duration) > 1 else "") + ")")

	adventurer_roster_changed.emit()
	mission_dispatched.emit([adventurer], mission, hex_id)


func send_party_on_mission(party: Array, mission: Dictionary, hex_id: String = ""):
	"""Dispatch a party on a mission. Does NOT resolve — starts the timer. Checks nothing (see send_on_mission)."""
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
		# Story 6.5 (DD-2): the chance the World Map showed is the one _resolve_party_mission rolls.
		"success_chance": estimate_success(party, mission),
		"sent_day": current_day,
		"hex_id": hex_id
	}
	active_entry.merge(deployment_record(party, mission, hex_id, current_day))   # Story 6.5 (DD-4)

	active_missions.append(active_entry)
	_lock_hex(hex_id)
	_log_dispatch(active_entry, party)

	var names = ", ".join(party.map(func(a): return a.name))
	log_message("Party departs on: " + mission.get("name", "?") + " (" + str(int(duration)) + " day" + ("s" if int(duration) > 1 else "") + ")")
	log_message("   Party: " + names)

	adventurer_roster_changed.emit()
	mission_dispatched.emit(party, mission, hex_id)


# --- Story 6.5: click-to-assign dispatch (the World Map's scroll) ---

## The one way the World Map sends adventurers out (DD-3). Everything is checked first and nothing changes when it
## refuses: returns "" when they're on their way, else a short reason the scroll shows (DRAFT text). Only READY
## adventurers go (INTEGRATION_CONTRACT_DISPATCH.md §2), exactly as many as the mission needs, each once, and only onto
## a hex that still holds this mission and nobody is out on. send_on_mission / send_party_on_mission do the work.
func dispatch_adventurers(adventurer_ids: Array, mission: Dictionary, hex_id: String = "") -> String:
	if mission.is_empty():
		return "That contract is gone."
	var party: Array = []
	var seen := {}
	for raw_id in adventurer_ids:
		var key = _id_key(raw_id)
		if seen.has(key):
			return "Each adventurer can only go once."
		seen[key] = true
		var adv := find_adventurer(key)
		if adv.is_empty():
			return "That adventurer isn't in the guild."
		var why := not_ready_reason(adv)
		if why != "":
			return why
		party.append(adv)
	var need := required_party_size(mission)
	if party.size() != need:
		return "Pick %d adventurer%s." % [need, "" if need == 1 else "s"]
	if hex_id != "":
		var hex := _hex_record(hex_id)
		var on_hex = hex.get("active_mission")
		if hex.is_empty() or not (on_hex is Dictionary and (is_same(on_hex, mission) or on_hex == mission)):
			return "That contract is gone."
		if is_hex_taken(hex):
			return "Someone is already out on this contract."
		hex.erase("locked")   # review P6: a stale lock (a debug reset cleared the entries, not the locks)
	if need == 1:
		send_on_mission(party[0], mission, hex_id)
	else:
		send_party_on_mission(party, mission, hex_id)
	return ""


## How many adventurers a mission needs (DD-5): `required_adventurers` (every template has it; Tier 3 says 3), else
## `party_required` (true = 2, a number = that many), else 1.
static func required_party_size(mission: Dictionary) -> int:
	var req = mission.get("required_adventurers", 0)
	if (req is int or req is float) and int(req) > 0:
		return int(req)
	var party_raw = mission.get("party_required", false)
	if party_raw is bool:
		return 2 if party_raw else 1
	if party_raw is int or party_raw is float:
		return maxi(1, int(party_raw))
	return 1


## The one success estimate (DD-2): the World Map's scroll shows it, dispatch stores it on the entry, the resolvers roll
## it. One adventurer: calculate_mission_success_chance(); a party: party_chance_from() of their own chances.
func estimate_success(party: Array, mission: Dictionary) -> int:
	var chances: Array = []
	for adv in party:
		if adv is Dictionary:
			chances.append(calculate_mission_success_chance(adv, mission))
	return party_chance_from(chances)


## A party's chance from its members' own: the integer average + 5 per extra member, clamped 10-95 (the party rule
## since Epic 6). One member: theirs; nobody: 0.
static func party_chance_from(chances: Array) -> int:
	if chances.is_empty():
		return 0
	if chances.size() == 1:
		return int(chances[0])
	var total := 0
	for c in chances:
		total += int(c)
	var average := int(float(total) / float(chances.size()))   # truncated, as the integer average always was
	return clampi(average + (chances.size() - 1) * 5, 10, 95)


## An adventurer's status as the enum (a loaded save may hold a float or a label).
static func status_of(adventurer: Dictionary) -> int:
	var s = adventurer.get("status", AStatus.READY)
	if s is String:
		return AdventurerStatus.from_save(s)
	return int(s)


## Why this adventurer can't be sent, as the scroll says it; "" = READY, the only status that may go. DRAFT text.
static func not_ready_reason(adventurer: Dictionary) -> String:
	if AdventurerStatus.is_available(status_of(adventurer)):
		return ""
	var who := str(adventurer.get("name", "They"))
	match status_of(adventurer):
		AdventurerStatus.Status.ON_MISSION:
			return "%s is out on a contract." % who
		AdventurerStatus.Status.RESTING:
			return "%s is resting." % who
		AdventurerStatus.Status.WOUNDED:
			return "%s is wounded." % who
		AdventurerStatus.Status.DEAD:
			return "%s is gone." % who
	return "%s can't go." % who


## The roster's own dictionary for an id (the World Map's ids: `id`, else `name`; a JSON float id matches its int, via
## _id_key from Story 11.2). {} when nobody on the roster has it.
func find_adventurer(adventurer_id) -> Dictionary:
	var key = _id_key(adventurer_id)
	for adv in adventurers:
		if adv is Dictionary and _same_id(_id_key(adv.get("id", adv.get("name"))), key):
			return adv
	return {}


static func _same_id(a, b) -> bool:
	return typeof(a) == typeof(b) and a == b


## An adventurer's trait as UI text, {name, description}, or {} when they have none (DD-10). The same lookup the
## mission formula uses, so the scroll never shows a trait that isn't applied, and never a raw key. Since Story 4.2 every
## applicant draws a trait from traits.json and keeps it when hired; the hire panel and the roster show it with this too.
func trait_info(adventurer: Dictionary) -> Dictionary:
	var key := str(adventurer.get("personality", "")).strip_edges()
	if key == "":
		return {}
	var data := get_trait_data(key)
	var shown := str(data.get("display_name", ""))
	if shown == "":
		return {}
	return {"name": shown, "description": str(data.get("description", ""))}


## The Deployment Record (DD-4, INTEGRATION_CONTRACT_DISPATCH.md §4), stored on the active_missions entry itself so it is
## saved with it. adventurer_ids follow the party's order (Story 11.2's relink reads them by index). return_day: the day
## process_mission_returns resolves it (days_remaining reaches 0 on that morning's advance).
static func deployment_record(party: Array, mission: Dictionary, hex_id: String, day: int) -> Dictionary:
	var duration := maxi(1, int(mission.get("duration_days", 1)))
	var ids: Array = []
	for a in party:
		ids.append(a.get("id", a.get("name")) if a is Dictionary else null)
	return {"adventurer_ids": ids, "mission_id": str(mission.get("id", mission.get("name", ""))), "location_id": hex_id,
		"dispatch_day": day, "return_day": day + duration, "travel_duration": duration, "direction": "outbound"}


## What a deployed marker says about an active entry (DD-8): who is out, the day they're back, the chance they left with
## (-1 = not stored). An entry saved before Story 6.5 has no record: back day = today + the days left.
static func deployment_view(entry: Dictionary, today: int) -> Dictionary:
	var party: Array = []
	if entry.get("party") is Array:
		party = entry.party
	elif entry.get("adventurer") is Dictionary:
		party = [entry.adventurer]
	var names: Array = []
	for a in party:
		if a is Dictionary:
			names.append(str(a.get("name", "?")))
	var back = entry.get("return_day")
	var left = entry.get("days_remaining", 0)
	var return_day: int = int(back) if (back is int or back is float) else today + maxi(0, int(left) if (left is int or left is float) else 0)
	var sc = entry.get("success_chance")
	return {"party": party, "names": names, "return_day": return_day, "chance": int(sc) if (sc is int or sc is float) else -1}


## The active entry out on a hex, or {}.
func deployment_for_hex(hex_id: String) -> Dictionary:
	if hex_id == "":
		return {}
	for entry in active_missions:
		if entry is Dictionary and str(entry.get("location_id", entry.get("hex_id", ""))) == hex_id:
			return entry
	return {}


## deployment_view() of the entry out on a hex, with the estimate standing in for a chance an old entry never stored,
## and its mission. {} when nobody is out there.
func deployment_info(hex_id: String) -> Dictionary:
	var entry := deployment_for_hex(hex_id)
	if entry.is_empty():
		return {}
	var view := deployment_view(entry, current_day)
	if int(view.chance) < 0 and entry.get("mission") is Dictionary:
		view.chance = estimate_success(view.party, entry.mission)
	view["mission"] = entry.get("mission", {})
	return view


## The day an adventurer out on a mission is back, or -1 (not out, or no entry for them). The entry holding this very
## dictionary wins over one that only shares its id (Story 4.3 review: a stale or colliding entry can't steal the day).
func return_day_for(adventurer: Dictionary) -> int:
	var id = _id_key(adventurer.get("id", adventurer.get("name")))
	for pass_by_id in [false, true]:
		for entry in active_missions:
			if not (entry is Dictionary):
				continue
			var view := deployment_view(entry, current_day)
			for a in view.party:
				if (not pass_by_id and is_same(a, adventurer)) or (pass_by_id and a is Dictionary and _same_id(_id_key(a.get("id", a.get("name"))), id)):
					return int(view.return_day)
	return -1


## The World Map record for a hex id, or {}.
func _hex_record(hex_id: String) -> Dictionary:
	if hex_id == "":
		return {}
	for hex in WorldManager.world_map:
		if hex is Dictionary and str(hex.get("id", "")) == hex_id:
			return hex
	return {}


## Whether someone is out on this hex: it is locked AND an active entry is there. A lock with no entry is stale (the
## F10 / debug resets clear active_missions, not the locks) and doesn't count (review P6).
func is_hex_taken(hex: Dictionary) -> bool:
	return hex.get("locked", false) and not deployment_for_hex(str(hex.get("id", ""))).is_empty()


## Review P1: a resolved entry gives its contract up: its hex is unlocked and loses the mission (when it still holds this
## one), and the mission leaves today's pool, so the same contract can't be run and paid twice. The pool may hold a
## loaded copy, so the same dictionary is looked for first, then an equal one. True when anything changed.
func _release_hex(entry: Dictionary) -> bool:
	var changed := false
	var mission = entry.get("mission")
	var hex := _hex_record(str(entry.get("location_id", entry.get("hex_id", ""))))
	if not hex.is_empty():
		if hex.has("locked"):
			hex.erase("locked")
			changed = true
		var on_hex = hex.get("active_mission")
		if mission is Dictionary and on_hex is Dictionary and (is_same(on_hex, mission) or on_hex == mission):
			hex["active_mission"] = null
			changed = true
	if mission is Dictionary:
		var at := -1
		for i in available_missions.size():
			if is_same(available_missions[i], mission):
				at = i
				break
		if at < 0:
			at = available_missions.find(mission)
		if at >= 0:
			available_missions.remove_at(at)
			changed = true
	return changed


## The dispatched hex is locked by the owner of dispatch (it used to be the board's job); _release_hex unlocks it when
## the mission resolves. No hex (the legacy board) locks nothing.
func _lock_hex(hex_id: String) -> void:
	var hex := _hex_record(hex_id)
	if not hex.is_empty():
		hex["locked"] = true


func _log_dispatch(entry: Dictionary, party: Array) -> void:
	print(dispatch_line(entry, party))


## The NFR-10 line for a dispatch: `[GameManager] dispatch: Ada -> Clear the Cellar (hex_12), back day 7, chance 82%`.
static func dispatch_line(entry: Dictionary, party: Array) -> String:
	var names := ", ".join(party.map(func(a): return str(a.get("name", "?"))))
	var where := str(entry.get("location_id", ""))
	var mission = entry.get("mission")
	return "[GameManager] dispatch: %s -> %s (%s), back day %d, chance %d%%" % [names,
		mission.get("name", "?") if mission is Dictionary else "?", where if where != "" else "no hex",
		int(entry.get("return_day", 0)), int(entry.get("success_chance", 0))]


## How many party missions a refresh must carry (DD-7). Party templates start at Tier 2, which the first tax (Day 30)
## unlocks, so a demo session never meets one: the demo profile asks for `per_refresh` of them from `from_day`
## (game_config.json demo_party_missions; per_refresh 0 = off). The full profile: 0 (Tier 2 brings them). A missing or
## bad config gives 0 and one text in `warn`.
static func party_missions_wanted(profile: String, cfg, day: int, warn: Array = []) -> int:
	if profile != "demo":
		return 0
	if not (cfg is Dictionary):
		warn.append("[GameManager] fallback: demo_party_missions is missing or not an object; no party missions before Tier 2")
		return 0
	var from_day = cfg.get("from_day")
	var per = cfg.get("per_refresh")
	if not (from_day is int or from_day is float) or not (per is int or per is float) or int(per) < 0:
		warn.append("[GameManager] fallback: demo_party_missions needs a number from_day and a per_refresh of 0 or more; no party missions before Tier 2")
		return 0
	return int(per) if day >= int(from_day) else 0


## A mission pool carrying at least `wanted` party missions: solo ones are replaced from the end by copies of
## `party_templates`, in their order. The count stays; a party mission is never removed; the input isn't changed.
static func with_party_missions(missions: Array, party_templates: Array, wanted: int) -> Array:
	var out := missions.duplicate()
	if wanted <= 0 or party_templates.is_empty():
		return out
	var have := 0
	for m in out:
		if m is Dictionary and required_party_size(m) >= 2:
			have += 1
	var t := 0
	var i := out.size() - 1
	while have < wanted and i >= 0:
		var m = out[i]
		if not (m is Dictionary and required_party_size(m) >= 2):
			out[i] = (party_templates[t % party_templates.size()] as Dictionary).duplicate(true)
			t += 1
			have += 1
		i -= 1
	return out


## This refresh's party rule from game_config.json: {wanted, max_tier}. A bad config is warned about once a session.
func _party_missions_for_refresh() -> Dictionary:
	var cfg = DataManager.get_config("demo_party_missions")
	var warn: Array = []
	var wanted := party_missions_wanted(str(DataManager.get_config("profile", "full")), cfg, current_day, warn)
	if not warn.is_empty():
		_warn_party_missions_once(warn[0])
	var max_tier := 2
	if cfg is Dictionary and (cfg.get("max_tier") is int or cfg.get("max_tier") is float):
		max_tier = int(cfg.max_tier)
	return {"wanted": wanted, "max_tier": max_tier}


func _warn_party_missions_once(text: String) -> void:
	if _party_missions_warned:
		return
	_party_missions_warned = true
	_party_missions_warnings.append(text)
	push_warning(text)


## Fresh copies of the party templates up to a tier, each varied like the daily pool's, shuffled.
func _party_templates_up_to(max_tier: int) -> Array:
	var out: Array = []
	for t in DataManager.mission_types.get("mission_templates", []):
		if t is Dictionary and int(t.get("tier", 1)) <= max_tier and required_party_size(t) >= 2:
			var m: Dictionary = t.duplicate(true)
			DataManager.add_mission_variety(m)
			out.append(m)
	out.shuffle()
	return out


func get_trait_data(personality: String) -> Dictionary:
	"""Look up trait modifiers from DataManager. Returns empty dict if not found. The key is matched in lower case
	(Story 4.2): traits.json's keys are lower case, and saves from before 4.2 hold applicants' "Brave" / "Greedy"."""
	var key := personality.strip_edges().to_lower()
	if key == "":
		return {}
	var traits = DataManager.character_traits
	var positive = traits.get("positive_traits", {})
	var negative = traits.get("negative_traits", {})
	return positive.get(key, negative.get(key, {}))

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

		# The trait's bonus gold (Lucky, Greedy), logged in the trait's name (Story 4.2 review P2)
		reward += _trait_bonus_gold(adventurer, reward)

		add_gold(reward)
		adventurer.missions_completed += 1
		adventurer.gold_earned += reward

		# SUCCESS: Adventurer needs rest (1 day minimum); a Reckless one may come back hurt instead (review P2)
		adventurer.status = AStatus.RESTING
		adventurer.recovery = 1
		_trait_hurt_on_success(adventurer)

		total_missions_completed += 1
		_gain_reputation("rep_mission_success", "mission_success")   # Story 14.6: the gain is config
		GameManager.check_tier_unlocks()

		if announce:
			_log_solo_success(adventurer, mission, reward)
	else:
		adventurer.missions_failed += 1
		_gain_reputation("rep_mission_failure", "mission_failure")   # Story 14.6
		log_message("FAILED! " + adventurer.name + " failed the mission: " + mission.name)

		# FAILURE ONLY: Handle injury and death consequences (they set the status: WOUNDED or DEAD). The old
		# `injured` flag (Reckless's pre-4.2 no-op, review P2) is dropped from any record that still holds it.
		adventurer.erase("injured")
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
		var share: int = reward / maxi(1, party.size())
		var bonuses := 0

		for adventurer in party:
			# SUCCESS: All party members need rest; each one's trait bonus on their own share (review P2: it was
			# solo-only), and a Reckless one may come back hurt
			var bonus := _trait_bonus_gold(adventurer, share)
			bonuses += bonus
			adventurer.status = AStatus.RESTING
			adventurer.recovery = 1  # 1 day rest for successful party missions
			adventurer.missions_completed += 1
			adventurer.gold_earned += share + bonus
			_trait_hurt_on_success(adventurer)
			check_adventurer_level_up(adventurer)
		reward += bonuses
		add_gold(reward)
		_gain_reputation("rep_party_mission_success", "party_mission_success")   # Story 14.6: once a mission (0 in the full game)

		if announce:
			_log_party_success(mission, reward)
	else:
		log_message("PARTY FAILED! Mission " + mission.name + " was catastrophic")
		_gain_reputation("rep_party_mission_failure", "party_mission_failure")  # one hit per failed mission, not per member
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
	var released := false

	for i in range(active_missions.size()):
		var entry = active_missions[i]
		entry.days_remaining -= 1

		if entry.days_remaining <= 0:
			resolved_indices.append(i)
			var report = _resolve_mission(entry)
			pending_reports.append(report)
			# Story 6.5 review P1: the hex is unlocked and the contract is done (off the hex and today's pool).
			if _release_hex(entry):
				released = true
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
	if released:
		missions_changed.emit()   # the map and the hall's notice board drop the finished contracts

	if pending_reports.size() > 0:
		has_pending_briefing = true
		# Story 7.1 (Reveal-Before-Display) — every outcome is already applied to game state
		# (roster, gold, statuses) and every death is already in codex.dat. Persist the save
		# NOW, before the reveal sequencer plays, so the panels are purely cosmetic and a
		# crash or quit mid-reveal still leaves an already-correct save on disk.
		if SaveSystem.run_active:   # Story 11.2 review P1: only a live run saves on its own
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

	# Reckless's injury_chance acts in complete_mission on a success (Story 4.2 review P2; on a failure it changed
	# nothing: the failure wounds or kills anyway).
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

	# Story 6.5 (DD-2): roll the chance stored at dispatch (what the World Map showed). An entry saved before 6.5 has
	# none: estimate_success() is the same average + 5 per extra member this always computed.
	var stored = entry.get("success_chance")
	var final_chance: int = int(stored) if (stored is int or stored is float) else estimate_success(party, mission)

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


## Epic 16 review P1: the morning reports live only in memory (a save holds none: Story 7.1 applies and saves every outcome
## before the reveal), so a Load drops any the session before it hadn't shown.
func _clear_unsaved_reports() -> void:
	pending_reports.clear()
	has_pending_briefing = false

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


# === TAX CYCLE (Epic 13) ===
# Story 13.1: every number from game_config.json's tax_* keys (tax_config), every event on EconomyBus:
# tax_warning on the configured days before the due day; on the first collection morning of a cycle
# tax_demand_triggered, then the payment (spend_gold: gold_changed, then tax_paid); a morning that can't pay sends
# tax_overdue(days left) until the grace runs out, then the guild falls (bankruptcy). Payment is automatic.

## Today's tax numbers: the fallback for each tax_* key of game_config.json (Story 13.1, DT-4).
const TAX_DEFAULTS := {"first_due_day": 30, "interval_days": 30, "base_amount": 1000, "per_adventurer": 5, "grace_days": 3,
	"warning_days": [7, 3, 1]}
## game_config.json key -> [tax_config field, the smallest whole number it accepts].
const TAX_CONFIG_KEYS := {"tax_due_day": ["first_due_day", 1], "tax_interval_days": ["interval_days", 1],
	"tax_base_amount": ["base_amount", 0], "tax_per_adventurer": ["per_adventurer", 0], "tax_grace_period_days": ["grace_days", 1]}

## The tax cycle's numbers from the config's tax_* keys (pure): {first_due_day, interval_days, base_amount,
## per_adventurer, grace_days, warning_days (largest first), warnings}. A missing key takes today's number silently; a
## bad one (not a whole number, or below its minimum; warning days not a list of whole numbers >= 1) takes it too, and
## `warnings` gets a "[GameManager] fallback: ..." text naming the key, for the caller to push.
static func tax_config_from(raw: Dictionary) -> Dictionary:
	var out := TAX_DEFAULTS.duplicate(true)
	var warnings: Array = []
	for key in TAX_CONFIG_KEYS:
		if not raw.has(key):
			continue
		var field: String = TAX_CONFIG_KEYS[key][0]
		var minimum: int = TAX_CONFIG_KEYS[key][1]
		var n = _whole_number(raw[key])
		if n == null or int(n) < minimum:
			warnings.append("[GameManager] fallback: %s %s is not a whole number >= %d; using %d" % [key, raw[key], minimum, TAX_DEFAULTS[field]])
		else:
			out[field] = int(n)
	if raw.has("tax_warning_days"):
		var w = raw["tax_warning_days"]
		var days: Array = []
		var good: bool = w is Array and not (w as Array).is_empty()
		if good:
			for v in w:
				var n = _whole_number(v)
				if n == null or int(n) < 1:
					good = false
					break
				if not days.has(int(n)):
					days.append(int(n))
		if good:
			days.sort()
			days.reverse()
			out["warning_days"] = days
		else:
			warnings.append("[GameManager] fallback: tax_warning_days %s is not a list of whole numbers >= 1; using %s" % [w, TAX_DEFAULTS.warning_days])
	out["warnings"] = warnings
	return out

## An int, or a float with no fraction (JSON reads every number as a float), as an int; anything else: null.
static func _whole_number(v):
	if v is int:
		return v
	if v is float and is_finite(v) and v == floorf(v):
		return int(v)
	return null

## What a cycle's tax costs (pure): the base plus a share per adventurer on the roster.
static func tax_amount_for(roster_size: int, cfg: Dictionary) -> int:
	return int(cfg.get("base_amount", TAX_DEFAULTS.base_amount)) + int(cfg.get("per_adventurer", TAX_DEFAULTS.per_adventurer)) * maxi(0, roster_size)

## tax_config_from() for game_config.json, its warnings pushed once a run (New Game re-arms them).
func tax_config() -> Dictionary:
	var raw := {}
	for key in TAX_CONFIG_KEYS.keys() + ["tax_warning_days"]:
		var v = DataManager.get_config(key)
		if v != null:
			raw[key] = v
	var cfg := tax_config_from(raw)
	if not cfg.warnings.is_empty() and _tax_warnings == 0:
		_tax_warnings += 1
		for w in cfg.warnings:
			push_warning(w)
	return cfg

## The tax due this cycle with today's roster.
func current_tax_amount() -> int:
	return tax_amount_for(adventurers.size(), tax_config())

## The hall's event-log line for a tax warning (Story 13.1 review P13: the wording, out of check_tax_deadline). Pure.
static func tax_warning_log_line(days_left: int, amount: int) -> String:
	if days_left == 1:
		return "Tax payment due TOMORROW! Need " + str(amount) + " gold!"
	return "Tax payment due in " + str(days_left) + " days. Need " + str(amount) + " gold."

## The hall's welcome text's tax line (Story 14.6: MainTavern.tscn said "every 30 days, 1000 gold" whatever the profile;
## main_tavern.gd puts this in its place at load). Pure. DRAFT wording (Raphael rewrites). `today` (review P11): on or
## after the due day (a grace day: the tax unpaid) the line says it is overdue since that day.
static func tax_rule_line(cfg: Dictionary, next_due_day: int, today := 0) -> String:
	var interval := int(cfg.get("interval_days", TAX_DEFAULTS.interval_days))
	var base := int(cfg.get("base_amount", TAX_DEFAULTS.base_amount))
	var per := int(cfg.get("per_adventurer", TAX_DEFAULTS.per_adventurer))
	var amount := ("%d gold" % base) if per <= 0 else ("%d gold, plus %d for each adventurer," % [base, per])
	var every := "every day" if interval == 1 else ("every %d days" % interval)
	var when := ("overdue since Day %d" % next_due_day) if today > 0 and today >= next_due_day else ("the next is due on Day %d" % next_due_day)
	return "- Taxes: %s %s; %s. Gold and beer are your lifelines: run out of both and it's over." % [amount, every, when]

## Runs each morning (advance_day): a warning on a configured day before the due day; from the due day on, the payment.
func check_tax_deadline():
	var days_until_tax := tax_due_day - current_day
	if days_until_tax <= 0:
		handle_tax_payment()
		return
	check_tax_warning()

## The warning half of check_tax_deadline: on a configured day before the due day, the log line and
## EconomyBus.tax_warning (the banner). True when it warned. Story 14.6 review P10: also run once at a run's start (the
## hall's first load after New Game), so a first tax due within the warning days (the demo's Day 3) is warned on Day 1,
## which has no morning.
func check_tax_warning() -> bool:
	var cfg := tax_config()
	var days_until_tax := tax_due_day - current_day
	if days_until_tax <= 0 or not (cfg.warning_days as Array).has(days_until_tax):
		return false
	var amount := tax_amount_for(adventurers.size(), cfg)
	log_message(tax_warning_log_line(days_until_tax, amount))
	print("[GameManager] tax: warning, due in %d day(s), %d gold" % [days_until_tax, amount])
	EconomyBus.tax_warning.emit(days_until_tax, amount)
	return true

## The due morning and each grace morning: the demand (first morning of the cycle only), then the payment or the grace.
func handle_tax_payment():
	var cfg := tax_config()
	var tax_amount := tax_amount_for(adventurers.size(), cfg)
	var grace_period: int = cfg.grace_days
	if tax_grace_days == 0:
		print("[GameManager] tax: demand %d gold, due day %d" % [tax_amount, tax_due_day])
		EconomyBus.tax_demand_triggered.emit(tax_amount, tax_due_day)

	if spend_gold(tax_amount):
		tax_due_day += int(cfg.interval_days)
		tax_grace_days = 0
		taxes_paid_count += 1
		log_message("Paid " + str(tax_amount) + " gold in taxes. Next due: Day " + str(tax_due_day))
		print("[GameManager] tax: paid %d gold, next due day %d" % [tax_amount, tax_due_day])
		EconomyBus.tax_paid.emit(tax_amount)
		check_tier_unlocks()
		_update_demo_ending()   # Story 10.7: the taxes paid are the demo ending's other condition
	else:
		tax_grace_days += 1
		log_message("OVERDUE: Cannot pay taxes (%d gold needed). Grace period: %d/%d days." % [tax_amount, tax_grace_days, grace_period])

		if tax_grace_days >= grace_period:
			trigger_game_over("bankruptcy", "Failed to pay taxes after the grace period. The guild is seized.")
		else:
			var days_left := grace_period - tax_grace_days
			log_message("" + str(days_left) + " day(s) remaining before the guild is shut down.")
			print("[GameManager] tax: overdue, %d day(s) left" % days_left)
			EconomyBus.tax_overdue.emit(days_left)


# === Tavern disturbances (Story 14.4) ===
# GameManager, the day authority, rolls them: each morning (advance_day, after the tax) yesterday's event is settled (seen
# and left unresolved: its type's "ignored" outcome; never seen: dropped), then today's is picked: a disturbance_schedule
# entry for today first (the demo's Day-2 thief), else below disturbance_reputation_below, out of the cooldown, on a
# daily-chance roll, a type by weight among those whose conditions hold, a truth by weight. One at a time, saved. The
# hall's director (scripts/game/disturbance_director.gd) shows it in the day phase and calls mark_disturbance_fired();
# a conversation's choice comes back through resolve_disturbance(). Types: data/disturbances/disturbances.json.
const DISTURBANCE_DEFAULTS := {"reputation_below": 50, "daily_chance": 0.3, "cooldown_days": 3, "schedule": []}
const DISTURBANCE_STATES := ["queued", "fired"]
var pending_disturbance: Dictionary = {}   # {type, truth, day, state (queued | fired), subject}; {} when none
var last_disturbance_day: int = 0          # the day the last event was queued (the cooldown counts from it)
var _disturbance_warnings: int = 0         # a bad disturbance config is warned about once a run (New Game re-arms it)
## Review P3: this morning's ignored outcome's line (logged at once); the hall's director shows it as a banner once the
## day begins (after the briefing) and clears it. Not saved.
var disturbance_note := ""

## The disturbance types (DataManager.disturbances.types; {} when the file has none).
func disturbance_types() -> Dictionary:
	var t = DataManager.disturbances.get("types") if DataManager.disturbances is Dictionary else null
	return t if t is Dictionary else {}

## The roll's numbers from the config's disturbance_* keys (pure): {reputation_below, daily_chance, cooldown_days,
## schedule: [{day, type, truth}]}. A missing key takes DISTURBANCE_DEFAULTS' silently; a bad one takes it with a warning
## text in `warn`; a schedule entry without a whole day >= 1 and a type is skipped with a warning text.
static func disturbance_config_from(raw: Dictionary, warn: Array = []) -> Dictionary:
	var out := DISTURBANCE_DEFAULTS.duplicate(true)
	for k in [["disturbance_reputation_below", "reputation_below"], ["disturbance_cooldown_days", "cooldown_days"]]:
		if not raw.has(k[0]):
			continue
		var n = _whole_number(raw[k[0]])
		if n == null or int(n) < 0:
			warn.append("[GameManager] fallback: %s %s is not a whole number >= 0; using %s" % [k[0], raw[k[0]], out[k[1]]])
		else:
			out[k[1]] = int(n)
	if raw.has("disturbance_daily_chance"):
		var c = raw.disturbance_daily_chance
		if (c is int or c is float) and is_finite(float(c)) and float(c) >= 0.0 and float(c) <= 1.0:
			out.daily_chance = float(c)
		else:
			warn.append("[GameManager] fallback: disturbance_daily_chance %s is not a number from 0 to 1; using %s" % [c, out.daily_chance])
	if raw.has("disturbance_schedule"):
		var s = raw.disturbance_schedule
		if not (s is Array):
			warn.append("[GameManager] fallback: disturbance_schedule %s is not a list; none" % [s])
		else:
			for e in s:
				var d = _whole_number(e.get("day")) if e is Dictionary else null
				if d == null or int(d) < 1 or not (e.get("type") is String):
					warn.append("[GameManager] fallback: disturbance_schedule entry %s needs a whole day >= 1 and a type; skipped" % [e])
					continue
				out.schedule.append({"day": int(d), "type": str(e.type), "truth": str(e.get("truth", ""))})
	return out

## disturbance_config_from() for game_config.json (the active profile's values), its warnings pushed once a run.
func disturbance_config() -> Dictionary:
	var raw := {}
	for k in ["disturbance_reputation_below", "disturbance_daily_chance", "disturbance_cooldown_days", "disturbance_schedule"]:
		var v = DataManager.get_config(k)
		if v != null:
			raw[k] = v
	var warn: Array = []
	var cfg := disturbance_config_from(raw, warn)
	_warn_disturbance(warn)
	return cfg

func _warn_disturbance(warn: Array) -> void:
	if not warn.is_empty() and _disturbance_warnings == 0:
		_disturbance_warnings += 1
		for w in warn:
			push_warning(w)

## A type's truth by its truths' weights (pure; names in order; "plain" when it has none). `roll` in [0, 1).
static func pick_truth(type_data: Dictionary, roll: float) -> String:
	var truths = type_data.get("truths")
	if not (truths is Dictionary) or (truths as Dictionary).is_empty():
		return "plain"
	var names: Array = (truths as Dictionary).keys()
	names.sort()
	var total := 0.0
	for n in names:
		total += maxf(0.0, float(truths[n]) if (truths[n] is int or truths[n] is float) else 0.0)
	if total <= 0.0:
		return str(names[0])
	var x := clampf(roll, 0.0, 0.999999) * total
	for n in names:
		x -= maxf(0.0, float(truths[n]) if (truths[n] is int or truths[n] is float) else 0.0)
		if x < 0.0:
			return str(n)
	return str(names[-1])

## Today's event, or {} (pure). `rolls`: [chance, type, truth], each in [0, 1). A schedule entry for `day` wins over the
## gate, the cooldown and the chance (its truth if it names a known one, else by weight); an unknown scheduled type, or
## one whose min_deaths this run hasn't reached (review P4), is skipped with a warning text. Else: reputation below the gate, `day - last_day` at least the cooldown (no event yet:
## always), the chance roll below daily_chance, then a type by weight (names in order) among those with a weight > 0 whose
## conditions hold (min_deaths), then the truth.
static func pick_disturbance(day: int, reputation: int, last_day: int, deaths: int, cfg: Dictionary, types: Dictionary,
		rolls: Array, warn: Array = []) -> Dictionary:
	var r: Array = rolls if rolls.size() >= 3 else [1.0, 0.0, 0.0]
	for e in cfg.get("schedule", []):
		if int(e.get("day", 0)) != day:
			continue
		var st := str(e.get("type", ""))
		if not (types.get(st) is Dictionary):
			warn.append("[GameManager] fallback: disturbance_schedule names an unknown type '%s' on day %d; skipped" % [st, day])
			continue
		if deaths < deaths_needed(types[st]):
			warn.append("[GameManager] fallback: disturbance_schedule's %s on day %d needs %d death(s) this run (min_deaths); skipped" % [st, day, deaths_needed(types[st])])
			continue
		var tr := str(e.get("truth", ""))
		var known = types[st].get("truths")
		if tr == "" or not (known is Dictionary and (known as Dictionary).has(tr)):
			tr = pick_truth(types[st], float(r[2]))
		return {"type": st, "truth": tr, "day": day, "state": "queued", "subject": ""}
	if reputation >= int(cfg.get("reputation_below", 50)):
		return {}
	if last_day > 0 and day - last_day < int(cfg.get("cooldown_days", 3)):
		return {}
	if float(r[0]) >= float(cfg.get("daily_chance", 0.3)):
		return {}
	var names: Array = types.keys().filter(func(k): return types[k] is Dictionary)
	names.sort()
	var eligible: Array = []
	var total := 0.0
	for n in names:
		var d: Dictionary = types[n]
		var w = d.get("weight", 0)
		if not (w is int or w is float) or float(w) <= 0.0 or deaths < deaths_needed(d):
			continue
		eligible.append(n)
		total += float(w)
	if eligible.is_empty():
		return {}
	var x := clampf(float(r[1]), 0.0, 0.999999) * total
	var pick: String = eligible[-1]
	for n in eligible:
		x -= float(types[n].weight)
		if x < 0.0:
			pick = n
			break
	return {"type": pick, "truth": pick_truth(types[pick], float(r[2])), "day": day, "state": "queued", "subject": ""}

## The deaths this run a type needs before it can come (pure): conditions.min_deaths, else 0.
static func deaths_needed(type_data) -> int:
	var cond = type_data.get("conditions") if type_data is Dictionary else null
	var md = _whole_number(cond.get("min_deaths", 0)) if cond is Dictionary else null
	return maxi(0, int(md)) if md != null else 0

## An outcome of the data (pure): {rep, gold, line} for a type, a truth and a choice (or "ignored"); {} when it has none.
static func disturbance_outcome(types: Dictionary, type: String, truth: String, choice: String) -> Dictionary:
	var d = types.get(type)
	var by_truth = d.get("outcomes", {}).get(truth) if d is Dictionary and d.get("outcomes") is Dictionary else null
	var o = by_truth.get(choice) if by_truth is Dictionary else null
	if not (o is Dictionary):
		return {}
	var rep = _whole_number(o.get("rep", 0))
	var g = _whole_number(o.get("gold", 0))
	return {"rep": int(rep) if rep != null else 0, "gold": int(g) if g != null else 0, "line": str(o.get("line", ""))}

## The morning's step (advance_day): settle the event of another day (yesterday's; review P7: any day but today, so a debug
## jump back can't freeze the rolls), then roll today's. `rolls` (tests): [chance, type, truth].
func _advance_disturbances(rolls: Array = []) -> void:
	if game_over_active:
		return
	var p := pending_disturbance
	if not p.is_empty() and int(p.get("day", 0)) != current_day:
		pending_disturbance = {}
		if p.get("state") == "fired":
			_note_ignored(_apply_disturbance_outcome(p, "ignored", "disturbance_ignored"))
		else:
			print("[GameManager] disturbance: dropped %s (%s) from day %d (never seen)" % [p.get("type"), p.get("truth"), int(p.get("day", 0))])
	if not pending_disturbance.is_empty():
		return
	if demo_ending_today():   # Story 10.7 (KM-9 as built): the King's messenger's day has no disturbance (one visitor a day)
		print("[GameManager] disturbance: none today, the King's messenger comes")
		return
	var warn: Array = []
	var r := rolls if rolls.size() >= 3 else [randf(), randf(), randf()]
	var e := pick_disturbance(current_day, tavern_reputation, last_disturbance_day, deaths_this_run, disturbance_config(), disturbance_types(), r, warn)
	_warn_disturbance(warn)
	if e.is_empty():
		return
	if deaths_needed(disturbance_types().get(e.type)) > 0:
		e.subject = _last_fallen_name()
	pending_disturbance = e
	last_disturbance_day = current_day
	print("[GameManager] disturbance: queued %s (%s) for day %d" % [e.type, e.truth, current_day])

## Review P3: an ignored outcome, told: its line in the morning's log (with what it cost) before anything else that
## morning can end the run (advance_day's soft-lock check), and kept for the hall's banner (disturbance_note).
func _note_ignored(out: Dictionary) -> void:
	var line := str(out.get("line", ""))
	if line == "":
		return
	log_message(ignored_log_line(out))
	disturbance_note = line

## The morning log's line for an ignored outcome (pure): the outcome's line, then what it cost or gave.
static func ignored_log_line(out: Dictionary) -> String:
	var parts := []
	if int(out.get("gold", 0)) != 0:
		parts.append("%+d gold" % int(out.gold))
	if int(out.get("rep", 0)) != 0:
		parts.append("%+d reputation" % int(out.rep))
	var line := str(out.get("line", ""))
	return line if parts.is_empty() else "%s (%s)" % [line, ", ".join(parts)]

## The newest name among this run's fallen ("" when none): the mourner's lost one. Review P4: run-scoped (the codex's
## list outlives runs and loads); an older save's deaths have no names kept: none, and her line without a name.
func _last_fallen_name() -> String:
	return str(fallen_this_run[-1]) if not fallen_this_run.is_empty() else ""

## The hall showed today's event (the director): queued -> fired. False when there is none for today.
func mark_disturbance_fired() -> bool:
	if pending_disturbance.is_empty() or int(pending_disturbance.get("day", -1)) != current_day:
		return false
	pending_disturbance.state = "fired"
	return true

## The conversation's choice for today's shown event (the director, when the box closes): the data's outcome applied
## (reason "disturbance_resolved"), the event cleared; {rep, gold, line}. No event shown today, or a choice the outcomes
## don't have ("ignored" is the morning's, not a choice): {} with a warning, nothing changed.
func resolve_disturbance(choice: String) -> Dictionary:
	var p := pending_disturbance
	if p.is_empty() or int(p.get("day", -1)) != current_day or p.get("state") != "fired":
		push_warning("[GameManager] refuse: no disturbance shown today to resolve (%s)" % choice)
		return {}
	if choice == "ignored" or disturbance_outcome(disturbance_types(), str(p.type), str(p.truth), choice).is_empty():
		push_warning("[GameManager] refuse: %s (%s) has no outcome '%s'" % [p.type, p.truth, choice])
		return {}
	pending_disturbance = {}
	return _apply_disturbance_outcome(p, choice, "disturbance_resolved")

## Apply an outcome: gold first (a loss takes what there is, never below 0), then reputation through the authority with
## the reason; then GuildBus.disturbance_resolved with what was applied. {rep, gold, line}.
func _apply_disturbance_outcome(p: Dictionary, choice: String, reason: String) -> Dictionary:
	var o := disturbance_outcome(disturbance_types(), str(p.get("type", "")), str(p.get("truth", "")), choice)
	var g := int(o.get("gold", 0))
	var gold_delta := 0
	if g > 0:
		add_gold(g)
		gold_delta = g
	elif g < 0:
		var take := mini(-g, gold)
		if take > 0 and spend_gold(take):
			gold_delta = -take
	var before := tavern_reputation
	if int(o.get("rep", 0)) != 0:
		adjust_reputation(int(o.rep), reason)
	var rep_delta := tavern_reputation - before
	print("[GameManager] disturbance: %s (%s) %s: rep %+d, gold %+d" % [p.get("type"), p.get("truth"), choice, rep_delta, gold_delta])
	GuildBus.disturbance_resolved.emit(str(p.get("type", "")), choice, rep_delta, gold_delta)
	return {"rep": rep_delta, "gold": gold_delta, "line": str(o.get("line", ""))}

## F12 (Story 14.4): today's event made `type` with `truth` (by weight when it isn't one of the type's), queued: the hall
## shows it in the day phase. False for an unknown type, or one whose min_deaths this run hasn't reached (review P4).
func debug_queue_disturbance(type: String, truth := "") -> bool:
	var d = disturbance_types().get(type)
	if not (d is Dictionary):
		return false
	if deaths_this_run < deaths_needed(d):
		push_warning("[GameManager] refuse: %s needs %d death(s) this run (min_deaths)" % [type, deaths_needed(d)])
		return false
	var known = d.get("truths")
	var tr := truth if known is Dictionary and (known as Dictionary).has(truth) else pick_truth(d, randf())
	pending_disturbance = {"type": type, "truth": tr, "day": current_day, "state": "queued",
		"subject": _last_fallen_name() if deaths_needed(d) > 0 else ""}
	last_disturbance_day = current_day
	print("[GameManager] disturbance: debug queued %s (%s) for day %d" % [type, tr, current_day])
	return true

func _disturbance_save_data() -> Dictionary:
	return {"pending_disturbance": pending_disturbance.duplicate(), "last_disturbance_day": last_disturbance_day}

## Story 14.4: the saved event, read defensively and silently: no key (an older save) -> none; an unknown type, a bad day
## or state -> none, with a warning.
func _load_disturbance_data(data: Dictionary) -> void:
	last_disturbance_day = maxi(0, _save_int(data.get("last_disturbance_day"), 0))
	pending_disturbance = {}
	var p = data.get("pending_disturbance")
	if p == null or (p is Dictionary and (p as Dictionary).is_empty()):
		return
	var d = _whole_number(p.get("day")) if p is Dictionary else null
	if not (p is Dictionary) or not (disturbance_types().get(str(p.get("type", ""))) is Dictionary) or d == null \
			or not (str(p.get("state", "")) in DISTURBANCE_STATES):
		push_warning("[GameManager] load: pending_disturbance %s is not a known event; none" % [p])
		return
	pending_disturbance = {"type": str(p.type), "truth": str(p.get("truth", "plain")), "day": int(d), "state": str(p.state),
		"subject": str(p.get("subject", ""))}

func _reset_disturbance_state() -> void:
	pending_disturbance = {}
	last_disturbance_day = 0
	_disturbance_warnings = 0
	disturbance_note = ""

# === The demo's ending: the King's messenger (Story 10.7) ===
# Demo profile only (sprint-change-proposal-2026-10-31.md K-2, K-3): when the guild's reputation is at least
# demo_ending.min_reputation AND at least demo_ending.min_taxes_paid taxes are paid (game_config.json, profiles.demo), the
# ending is due the next morning; that morning it is "coming" and the hall (scripts/game/royal_messenger.gd) shows the
# King's messenger in the day phase ("waiting" once he walked in); when the player has heard him, "ended": no automatic
# save after that (SaveSystem.run_active false), and a save never holds "ended" (written as "waiting"), so Continue replays
# the final day. Forward only, never twice; the full game (and enabled false) never evaluates it. The rules are pure, in
# scripts/game/demo_ending_rules.gd. GuildBus.demo_ending_changed for every move in play; a load and New Game are silent.
const DemoEndingRules := preload("res://scripts/game/demo_ending_rules.gd")
var demo_ending: Dictionary = {}       # {} | {state: due | coming | waiting | ended, day, returning}
var _demo_ending_warnings: int = 0     # a bad demo_ending config is warned about once a run (New Game re-arms it)

## The resolved demo_ending config for the run's profile ({active, min_reputation, min_taxes_paid}); its warnings pushed
## once a run, in the demo only (the full game never reads the numbers).
func demo_ending_config() -> Dictionary:
	var cfg := DemoEndingRules.config_from(DataManager.get_config("demo_ending"), DataManager.is_demo())
	if not (cfg.warnings as Array).is_empty() and DataManager.is_demo() and _demo_ending_warnings == 0:
		_demo_ending_warnings += 1
		for w in cfg.warnings:
			push_warning(w)
	return cfg

## The trigger (adjust_reputation, a tax paid, a load): both conditions met today -> due the next morning. `announce`
## false (a load) is silent.
func _update_demo_ending(announce := true) -> void:
	if not demo_ending.is_empty():
		return
	var cfg := demo_ending_config()
	var next := DemoEndingRules.queue_if_met(demo_ending, tavern_reputation, taxes_paid_count, current_day, cfg)
	if next.is_empty():
		return
	demo_ending = next
	print("[GameManager] demo ending: due day %d (reputation %d/%d, taxes %d/%d)%s" % [int(next.day), tavern_reputation,
		int(cfg.min_reputation), taxes_paid_count, int(cfg.min_taxes_paid), "" if announce else ", on load"])
	if announce:
		GuildBus.demo_ending_changed.emit("due", int(next.day))

## The morning's step (advance_day, before the disturbance roll): a due ending's day, or yesterday's unheard messenger ->
## "coming" today. Nothing after the fall, and nothing when the config is off (the full game).
func _advance_demo_ending() -> void:
	if game_over_active or demo_ending.is_empty() or not demo_ending_config().active:
		return
	var next := DemoEndingRules.morning(demo_ending, current_day)
	if next == demo_ending:
		return
	demo_ending = next
	print("[GameManager] demo ending: the King's messenger comes today (day %d)%s" % [current_day, ", again" if next.get("returning") == true else ""])
	GuildBus.demo_ending_changed.emit("coming", current_day)

## Today is the King's messenger's day (coming or already in the hall): the hall's other visitors stand down.
func demo_ending_today() -> bool:
	return str(demo_ending.get("state", "")) in ["coming", "waiting"] and int(demo_ending.get("day", -1)) == current_day

## The hall: the messenger walked in (coming today -> waiting). False, with a warning, from any other state.
func demo_ending_arrived() -> bool:
	if str(demo_ending.get("state", "")) != "coming" or int(demo_ending.get("day", -1)) != current_day:
		push_warning("[GameManager] refuse: the King's messenger isn't coming today (%s)" % [demo_ending])
		return false
	demo_ending = {"state": "waiting", "day": current_day, "returning": demo_ending.get("returning") == true}
	print("[GameManager] demo ending: the King's messenger is in the hall (day %d)" % current_day)
	GuildBus.demo_ending_changed.emit("waiting", current_day)
	return true

## The hall: the player heard him (waiting -> ended). The demo is over: no automatic save from now on (the save on disk
## stays this day's last one), then the end card. False, with a warning, from any other state.
func demo_ending_heard() -> bool:
	if str(demo_ending.get("state", "")) != "waiting":
		push_warning("[GameManager] refuse: nobody waiting to be heard (%s)" % [demo_ending])
		return false
	demo_ending = {"state": "ended", "day": int(demo_ending.get("day", current_day)), "returning": demo_ending.get("returning") == true}
	SaveSystem.run_active = false   # KM-7: no timer or end-of-day autosave can write the ended run
	print("[GameManager] demo ending: the King's request heard on day %d; the demo ends (the save stays this day's)" % current_day)
	GuildBus.demo_ending_changed.emit("ended", int(demo_ending.day))
	return true

## F12 (KM-13): the King's messenger comes today, whatever the conditions. False (a warning) when the run's profile isn't
## the demo or demo_ending is off: the full game never shows him.
func debug_demo_ending_now() -> bool:
	if not demo_ending_config().active:
		push_warning("[GameManager] refuse: the demo ending is off for this run's profile (%s)" % DataManager.get_profile())
		return false
	demo_ending = {"state": "coming", "day": current_day, "returning": false}
	print("[GameManager] demo ending: debug, the King's messenger comes today (day %d)" % current_day)
	GuildBus.demo_ending_changed.emit("coming", current_day)
	return true

func _demo_ending_save_data() -> Dictionary:
	return {"demo_ending": DemoEndingRules.for_save(demo_ending)}

## The saved ending, read defensively (junk -> none, with a warning), then re-evaluated silently: an older save (or a
## config change) that already meets both conditions is due the next morning.
func _load_demo_ending_data(data: Dictionary) -> void:
	var r := DemoEndingRules.from_save(data.get("demo_ending"))
	if str(r.warning) != "":
		push_warning(r.warning)
	demo_ending = r.state
	_update_demo_ending(false)

func _reset_demo_ending_state() -> void:
	demo_ending = {}
	_demo_ending_warnings = 0

# === THE BARD (Epic 9, Stories 9.1-9.5) ===
# A travelling bard visits some days. The morning (advance_day, after the disturbance roll) rolls today's visit
# (bard_visit: {day, state, hook, arrive_minute, wait_until}; saved): a schedule entry (profiles.demo: day 3), else the
# reputation tier, the cooldown and the chance. One visitor a day (decision K-20): no visit on the King's messenger's
# day nor on a day with a tavern disturbance. The hall (scripts/game/bard.gd) shows him at his minute in its open hours;
# he waits at the door (waiting), is let in (performing, Story 9.2) or turned away / tired of waiting (refused). The next
# morning settles the visit. The rules are pure, in scripts/game/bard_rules.gd. GuildBus.bard_visit_changed for every
# move in play; a load and New Game are silent.
const BardRules := preload("res://scripts/game/bard_rules.gd")
var bard_visit: Dictionary = {}       # {} | {day, state: coming | waiting | performing | refused, hook, arrive_minute, wait_until}
var bard_last_visit_day: int = 0      # the day the last visit was queued (the cooldown counts from it)
var _bard_warnings: int = 0           # a bad bard_* config is warned about once a run (New Game re-arms it)

## The bard_* keys of the run's profile, checked (bard_rules.config_from), plus min_tier_index (the tier list of the
## profile); its warnings pushed once a run.
func bard_config() -> Dictionary:
	var raw := {}
	for k in BardRules.KEYS:
		var v = DataManager.get_config(k)
		if v != null:
			raw[k] = v
	var warn: Array = []
	var cfg := BardRules.config_from(raw, warn)
	cfg.min_tier_index = BardRules.tier_index_of(str(cfg.min_tier), reputation_tier_list(DataManager.get_config("reputation_tiers", [])), warn)
	_warn_bard(warn)
	return cfg

func _warn_bard(warn: Array) -> void:
	if not warn.is_empty() and _bard_warnings == 0:
		_bard_warnings += 1
		for w in warn:
			push_warning(w)

## Today's visit exists (any state).
func bard_today() -> bool:
	return not bard_visit.is_empty() and int(bard_visit.get("day", -1)) == current_day

## The morning's step (advance_day, after the disturbance roll): settle another day's visit, then roll today's. `rolls`
## (tests): [chance, arrival] in [0, 1).
func _advance_bard(rolls: Array = []) -> void:
	if game_over_active:
		return
	var v := bard_visit
	if not v.is_empty() and int(v.get("day", 0)) != current_day:
		bard_visit = {}
		_end_bard_day(v)
	if not bard_visit.is_empty():
		return
	if demo_ending_today():
		print("[GameManager] bard: none today, the King's messenger comes (one visitor a day)")
		return
	if not pending_disturbance.is_empty() and int(pending_disturbance.get("day", -1)) == current_day:
		print("[GameManager] bard: none today, a tavern disturbance is due (one visitor a day)")
		return
	var cfg := bard_config()
	var r := rolls if rolls.size() >= 2 else [randf(), randf()]
	var e := BardRules.pick_visit(current_day, get_reputation_tier_index(), int(cfg.min_tier_index), bard_last_visit_day, cfg, r)
	if e.is_empty():
		return
	bard_visit = e
	bard_last_visit_day = current_day
	_bard_moved("coming", "queued for %s%s" % [DayClockRules.format_time(float(e.arrive_minute)), ", with a hook" if e.hook else ""])

## The night after a visit (advance_day): a visit never decided is closed as turned away (nothing changes); Story 9.2
## adds what a performance leaves behind.
func _end_bard_day(v: Dictionary) -> void:
	if str(v.get("state", "")) in ["coming", "waiting"]:
		print("[GameManager] bard: day %d's visit ended undecided (as turned away)" % int(v.get("day", 0)))

func _bard_moved(state: String, note := "") -> void:
	print("[GameManager] bard: %s (day %d)%s" % [state, int(bard_visit.get("day", current_day)), (": " + note) if note != "" else ""])
	GuildBus.bard_visit_changed.emit(state, int(bard_visit.get("day", current_day)))

## The hall: he reached the door (coming -> waiting); he waits wait_hours of clock time from now. False, with a warning,
## from any other state.
func bard_arrived() -> bool:
	if not bard_today() or str(bard_visit.get("state", "")) != "coming":
		push_warning("[GameManager] refuse: no bard coming today (%s)" % [bard_visit])
		return false
	bard_visit.state = "waiting"
	bard_visit.wait_until = int(ceil(day_clock_minutes + float(bard_config().wait_hours) * 60.0))
	_bard_moved("waiting", "until %s" % DayClockRules.format_time(float(bard_visit.wait_until)))
	return true

## The hall: turned away ("refused") or tired of waiting ("timeout"): coming / waiting -> refused. Nothing else changes
## (Story 9.3). False, with a warning, from any other state.
func refuse_bard(reason: String) -> bool:
	if not bard_today() or not (str(bard_visit.get("state", "")) in ["coming", "waiting"]):
		push_warning("[GameManager] refuse: no bard at the door to turn away (%s)" % [bard_visit])
		return false
	bard_visit.state = "refused"
	_bard_moved("refused", reason)
	return true

## The hall: the player let him play (waiting -> performing). False, with a warning, from any other state.
func allow_bard() -> bool:
	if not bard_today() or str(bard_visit.get("state", "")) != "waiting":
		push_warning("[GameManager] refuse: no bard waiting to be let in (%s)" % [bard_visit])
		return false
	bard_visit.state = "performing"
	_bard_moved("performing")
	return true

## F12 (Story 9.1): the Bard comes today (at the clock's minute now, so the hall shows him at once in its open hours),
## whatever the rolls; `hook` forces a quest hook if he plays (Story 9.4). Refused on the messenger's day.
func debug_queue_bard(hook := false) -> bool:
	if demo_ending_today():
		push_warning("[GameManager] refuse: the King's messenger's day has no other visitor")
		return false
	bard_visit = {"day": current_day, "state": "coming", "hook": hook, "arrive_minute": int(floor(day_clock_minutes)), "wait_until": -1}
	bard_last_visit_day = current_day
	_bard_moved("coming", "debug")
	return true

func _bard_save_data() -> Dictionary:
	return {"bard_visit": bard_visit.duplicate(), "bard_last_visit_day": bard_last_visit_day}

## The saved visit, read defensively (junk -> none, with a warning; an older save -> none and 0).
func _load_bard_data(data: Dictionary) -> void:
	bard_last_visit_day = maxi(0, _save_int(data.get("bard_last_visit_day"), 0))
	var r := BardRules.visit_from_save(data.get("bard_visit"))
	if str(r.warning) != "":
		push_warning(r.warning)
	bard_visit = r.visit

func _reset_bard_state() -> void:
	bard_visit = {}
	bard_last_visit_day = 0
	_bard_warnings = 0

# === THE DAY CLOCK (Story 3.7; decision log K-14…K-19) ===
# The time of day is GameManager's (day_clock_minutes: minutes since midnight of the day's start, 6:00 = 360, 2:00 the
# next morning = 1560; saved, CL-9). The persistent DayClock node (scripts/game/day_clock.gd, this node's child) ticks it
# in every day scene and is the one sender of GameBus.day_phase_changed; the rules are scripts/game/day_clock_rules.gd.
# advance_day() puts it back at the start before anything else of the morning (and long before the day's autosave).
const DayClockRules := preload("res://scripts/game/day_clock_rules.gd")
const DAY_CLOCK_SCRIPT := "res://scripts/game/day_clock.gd"
var day_clock_minutes: float = 360.0
var pending_night := ""                # "nod_off": the clock took the player to the hall to sleep (CL-16; never saved)
var _day_clock_warnings: int = 0       # a bad day_clock config is warned about once a run (New Game re-arms it)

func _add_day_clock() -> void:
	if get_node_or_null("DayClock") != null:
		return
	var c = load(DAY_CLOCK_SCRIPT).new()
	c.name = "DayClock"
	add_child(c)

## The persistent DayClock node (null before _ready's deferred add).
func day_clock_node() -> Node:
	return get_node_or_null("DayClock")

## The clock's config for the run's profile (day_clock_rules.config_from: minutes; its warnings pushed once a run).
func day_clock_config() -> Dictionary:
	var cfg := DayClockRules.config_from(DataManager.get_config("day_clock"), DataManager.get_config("day_clock_seconds_per_hour"))
	if not (cfg.warnings as Array).is_empty() and _day_clock_warnings == 0:
		_day_clock_warnings += 1
		for w in cfg.warnings:
			push_warning(w)
	return cfg

## The phase of the day now ("morning" … "late_night").
func day_clock_phase() -> String:
	return DayClockRules.phase_for(day_clock_minutes, day_clock_config())

## "" when the guildmaster may sleep (from sleep_from_hour, K-16), else the bedroom's line.
func day_clock_sleep_block() -> String:
	return DayClockRules.sleep_block(day_clock_minutes, day_clock_config())

## The clock back at the day's start (a new day, a new run).
func _start_day_clock() -> void:
	day_clock_minutes = float(day_clock_config().start)

## New Game: 6:00, no pending night, the warnings re-armed, the node's session forgotten.
func _reset_day_clock() -> void:
	_day_clock_warnings = 0
	pending_night = ""
	_start_day_clock()
	var c := day_clock_node()
	if c != null and c.has_method("reset_session"):
		c.reset_session()

## A save's clock (CL-9): its minute; none (older saves) → the start; junk → the start + warning; at or past the end →
## one minute before it (the nod-off follows at once).
func _load_day_clock(data: Dictionary) -> void:
	var r := DayClockRules.from_save(data.get("day_clock_minutes"), day_clock_config())
	if str(r.warning) != "":
		push_warning(r.warning)
	day_clock_minutes = float(r.minutes)
	pending_night = ""
	var c := day_clock_node()
	if c != null and c.has_method("reset_session"):
		c.reset_session()

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
	
	# Log the new recruits (none when the deck has no card left to deal: review P8, no "seeking" line over nobody)
	if not daily_recruits.is_empty():
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
	# Story 4.2 (DH-7): every applicant draws one trait from traits.json (MOD-2: the keys come from the data)
	var trait_keys := trait_ids(DataManager.character_traits)
	if trait_keys.is_empty() and not _no_traits_warned:
		_no_traits_warned = true
		push_warning("[GameManager] fallback: data/characters/traits.json defines no traits; applicants come without one")

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

		# The trait (Story 4.2, DH-7), kept in `personality`, the field the mission maths read. The effects traits.json
		# defines for the applicant themself act now, so the panel shows true numbers: all_stats before the cost and the
		# tier are worked out, cost_multiplier on the daily wage.
		var personality: String = trait_keys[randi() % trait_keys.size()] if not trait_keys.is_empty() else ""
		var trait_data := get_trait_data(personality)
		var plus := trait_stat_bonus(trait_data)
		for stat in ["strength", "dexterity", "intelligence", "endurance"]:
			recruit[stat] += plus

		# Calculate hiring cost based on stats
		var stat_total = recruit.strength + recruit.dexterity + recruit.intelligence + recruit.endurance
		recruit.hiring_cost = max(8, stat_total * 2 + randi_range(-5, 10))
		recruit.experience_tier = _tier_for_stat_total(stat_total, tiers)
		recruit.daily_wage = trait_wage(_wage_for_tier(recruit.experience_tier, tiers, wage_min, wage_max), trait_data)

		# Background flavour
		var backgrounds = ["Former soldier", "Ex-bandit", "Scholar's apprentice", "Village hero", "Wandering mercenary", "Fallen noble", "Guild dropout", "Self-taught warrior"]

		recruit.personality = personality
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
	"""An id no adventurer has ever had (Story 4.2, DH-8): the counter first jumps past every id in use or remembered."""
	next_adventurer_id = next_free_id(next_adventurer_id, _taken_ids())
	var id = next_adventurer_id
	next_adventurer_id += 1
	return id

func generate_recruit_id() -> int:
	return generate_unique_id()

## The larger of `counter` and one above every id in `taken` (Story 4.2, DH-8, pure). Ids are ints; a loaded save's
## whole floats and number strings count as ints (_id_key); anything else is ignored.
static func next_free_id(counter: int, taken: Array) -> int:
	var next := counter
	for raw in taken:
		var k = _id_key(raw)
		if k is int and k >= next:
			next = k + 1
	return next

## Every adventurer id in use or remembered: the roster, the hire pool, everyone out on a mission (and the ids their
## Deployment Records list), and the codex's fallen heroes. The codex outlives the run and the counter restarts at 1 in
## a fresh session, while SaveSystem.record_fallen_hero skips a death whose id is already there: a new run must never
## hand out a fallen hero's id.
func _taken_ids() -> Array:
	var out: Array = []
	for list in [adventurers, daily_recruits]:
		for a in list:
			if a is Dictionary:
				out.append(a.get("id"))
	for e in active_missions:
		if not (e is Dictionary):
			continue
		if e.get("adventurer") is Dictionary:
			out.append(e.adventurer.get("id"))
		if e.get("party") is Array:
			for p in e.party:
				if p is Dictionary:
					out.append(p.get("id"))
		if e.get("adventurer_ids") is Array:
			out.append_array(e.adventurer_ids)
	var fallen = SaveSystem.codex_data.get("fallen_heroes", [])
	if fallen is Array:
		for h in fallen:
			if h is Dictionary:
				out.append(h.get("id"))
	var finds = SaveSystem.codex_data.get("artifacts_found", [])   # Story 18.3 review P3: a finder's id is never handed out again
	if finds is Array:
		for a in finds:
			if a is Dictionary and a.has("found_by_id"):
				out.append(a.get("found_by_id"))
	return out

## Story 4.2 (DH-1): the hire desk always has the day's applicants. advance_day makes the pool each morning; a day that
## never had one (Day 1 of a New Game, a run that never slept) gets it when the desk first opens. Hired out on the same
## day, it stays empty until the next morning. True when a pool was made.
func ensure_hire_pool() -> bool:
	if daily_recruits.is_empty() and recruit_refresh_day < current_day:
		generate_daily_recruits()
		return true
	return false

## Story 4.2 (DH-2): why this applicant can't be hired now, as the hire panel says it; "" when they can. Checked in this
## order: still in today's pool (by id), a free place on the roster, the gold. DRAFT text.
func hire_block_reason(recruit: Dictionary) -> String:
	if not _in_hire_pool(recruit):
		return "No longer available"
	if adventurers.size() >= max_adventurers:
		return "Roster full"
	if gold < int(recruit.get("hiring_cost", 10)):
		return "Not enough gold"
	return ""

func _in_hire_pool(recruit: Dictionary) -> bool:
	var key = _id_key(recruit.get("id"))
	if key == null:
		return false
	for r in get_available_recruits():
		if r is Dictionary and _same_id(_id_key(r.get("id")), key):
			return true
	return false

## The trait keys traits.json defines, positive then negative (Story 4.2, DH-7, pure): what applicants draw from.
static func trait_ids(traits) -> Array:
	var out: Array = []
	if not (traits is Dictionary):
		return out
	for group in ["positive_traits", "negative_traits"]:
		var g = traits.get(group)
		if g is Dictionary:
			for k in g:
				if k is String and k != "" and g[k] is Dictionary:
					out.append(k)
	return out

## +N to each of the four stats when an applicant is made: traits.json's all_stats (Experienced). Pure.
static func trait_stat_bonus(trait_data: Dictionary) -> int:
	var v = trait_data.get("all_stats", 0)
	return int(v) if (v is int or v is float) else 0

## An applicant's daily wage under traits.json's cost_multiplier (Greedy x1.5), rounded up; none: the wage. Pure.
static func trait_wage(wage: int, trait_data: Dictionary) -> int:
	var m = trait_data.get("cost_multiplier", 1.0)
	if not (m is int or m is float) or float(m) <= 0.0:
		return wage
	return ceili(float(wage) * float(m))

## An adventurer's daily wage as the record holds it (1 when it holds none). Story 4.3 (DR-3): the hire panel, the roster
## and apply_daily_wages read it here, so the wage shown is the wage paid.
static func wage_of(adventurer: Dictionary) -> int:
	var w = adventurer.get("daily_wage", 1)
	return int(w) if (w is int or w is float) else 1

## A drink preference as the UI says it, from game_config.json's drink_labels (MOD-2): "Drinks mead"; an id with no
## label: "Drinks <id>"; no preference: "". Pure.
static func drink_label(drink, labels) -> String:
	if drink == null or str(drink) == "":
		return ""
	if labels is Dictionary and labels.get(str(drink)) is String:
		return labels[str(drink)]
	return "Drinks %s" % str(drink)

## An adventurer's or applicant's drink line (drink_label with the game's labels).
func drink_text(adventurer: Dictionary) -> String:
	return drink_label(adventurer.get("drink_preference"), DataManager.get_config("drink_labels", {}))

## The deck card an adventurer or applicant carries (Story 4.2): the deck's entry for their `tarot_card`, else just the
## name their record kept ({name: tarot_name}), else {}.
func tarot_card_of(adventurer: Dictionary) -> Dictionary:
	var card := DataManager.get_tarot_card(str(adventurer.get("tarot_card", "")))
	if not card.is_empty():
		return card
	var shown := str(adventurer.get("tarot_name", ""))
	return {"name": shown} if shown != "" else {}

## Story 4.2 review P8: every card of the deck has been dealt this run (on the roster or hired before), so no
## applicant can ever come again. False with no deck loaded (the generator then makes card-less applicants).
func deck_exhausted() -> bool:
	return not DataManager.get_all_tarot_ids().is_empty() and _get_available_tarot_ids().is_empty()

## Story 4.2 review P9: an applicant saved before 4.2 holds a capitalised trait word ("Greedy"); it gets the key and the
## wage that trait sets (trait_wage). Lower-case keys (made since 4.2) and words with no trait data are left alone, so
## the multiplier is never applied twice. True when the record changed.
func heal_applicant_trait(rec: Dictionary) -> bool:
	var p = rec.get("personality")
	if not (p is String) or (p as String).strip_edges() == "" or p == (p as String).to_lower():
		return false
	var key := (p as String).strip_edges().to_lower()
	var data := get_trait_data(key)
	if data.is_empty():
		return false
	rec["personality"] = key
	rec["daily_wage"] = trait_wage(wage_of(rec), data)
	return true

## Story 4.2 review P10: an applicant whose id someone else holds too (the roster, someone out, the codex's fallen,
## another applicant; old saves restarted ids at 1 every session) gets a fresh one. Returns how many were re-keyed.
func _rekey_colliding_applicants() -> int:
	var n := 0
	for rec in daily_recruits:
		if not (rec is Dictionary):
			continue
		var key = _id_key(rec.get("id"))
		var holders := 0
		for t in _taken_ids():
			if _same_id(_id_key(t), key):
				holders += 1
		if holders > 1:
			rec["id"] = generate_unique_id()
			n += 1
	return n

## Story 4.2 review P2: the bonus gold an adventurer's trait adds to their `share` of a successful contract (reward_bonus:
## Lucky +20 %, Greedy +10 %), logged in the trait's own name. 0 without one.
func _trait_bonus_gold(adventurer: Dictionary, share: int) -> int:
	var rb = get_trait_data(str(adventurer.get("personality", ""))).get("reward_bonus", 0.0)
	if not (rb is int or rb is float):
		return 0
	var bonus := int(share * float(rb))
	if bonus > 0:
		log_message("%s (%s): +%d bonus gold." % [str(adventurer.get("name", "?")), str(trait_info(adventurer).get("name", "?")), bonus])
	return bonus

## Story 4.2 review P2: Reckless's injury_chance on a SUCCESSFUL contract: they come back hurt (WOUNDED for
## TRAIT_WOUND_DAYS) instead of resting. A failure already wounds or kills, so that is where the chance means something;
## nothing is stored on the record (the old `injured` flag is gone). True when it happened.
func _trait_hurt_on_success(adventurer: Dictionary) -> bool:
	var ic = get_trait_data(str(adventurer.get("personality", ""))).get("injury_chance", 0.0)
	if not (ic is int or ic is float) or float(ic) <= 0.0 or randf() >= float(ic):
		return false
	adventurer["status"] = AStatus.WOUNDED
	adventurer["recovery"] = TRAIT_WOUND_DAYS
	adventurer["injuries_sustained"] = int(adventurer.get("injuries_sustained", 0)) + 1
	log_message("%s (%s) came back hurt: %d days to heal." % [str(adventurer.get("name", "?")), str(trait_info(adventurer).get("name", "?")), TRAIT_WOUND_DAYS])
	return true

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
	_start_day_clock()   # Story 3.7: 6:00 before anyone hears of the new day (and so in the day's autosave)
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
	apply_staff_wages()   # Story 16.5: the staff, right after the adventurers (and so before the tax)

	# Show availability status
	log_daily_availability_status()
	
	# Process beer consumption and other daily events
	var beer_adequate = process_adventurer_beer_consumption()
	process_mission_returns()
	process_daily_operations_with_beer()
	check_tax_deadline()
	if game_over_active:
		return   # Story 13.4 review P6: the guild fell this morning (the tax): the night ends here (it saved itself)
	_advance_demo_ending()    # Story 10.7: a due ending's morning: the King's messenger comes today (before the roll below)
	_advance_disturbances()   # Story 14.4: yesterday's event settled, today's rolled
	_advance_bard()           # Epic 9: yesterday's visit settled, today's rolled (none on a visitor's day: K-20)
	
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

	# Soft-lock detection (Story 13.4: the GDD's rule, with the hire authority's affordability)
	_check_soft_lock()

	# The day's autosave, now that the whole night is done (Story 11.2 review P5: it used to run on day_changed,
	# before wages, missions, the fire and recruits, so Sleep -> quit -> Continue skipped a night). A game over
	# already saved itself.
	if not game_over_active:
		SaveSystem.save_end_of_day()


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
	_gain_reputation("rep_dismiss", "dismiss")   # Story 14.6
	adventurers.erase(adventurer)
	var rep_note := (", %d reputation" % rep_gain("rep_dismiss")) if rep_gain("rep_dismiss") != 0 else ""   # Story 14.6 review P15
	log_message("%s has been dismissed (paid %d gold%s)." % [adventurer.get("name", "?"), severance, rep_note])
	adventurer_roster_changed.emit()
	return true

func hire_adventurer(recruit: Dictionary) -> bool:
	"""Hire an applicant from today's pool. Story 4.2 (DH-2): everything is checked first (hire_block_reason), so a
	refused hire changes nothing and emits nothing (a full roster used to spend, then refund). The trait is kept
	(`personality`, DH-7) and the adventurer joins READY."""
	var why := hire_block_reason(recruit)
	if why != "":
		log_message("Cannot hire " + str(recruit.get("name", "?")) + ": " + why + ".")
		return false
	var hiring_cost := int(recruit.get("hiring_cost", 10))
	spend_gold(hiring_cost)  # deducts + emits gold_changed → EconomyBus (hire_block_reason checked the gold)

	# Clean recruit data and add to roster
	var new_adventurer = recruit.duplicate()
	new_adventurer.erase("hiring_cost")
	new_adventurer.erase("background")
	new_adventurer.erase("availability")

	_normalize_adventurer_ints(new_adventurer)  # coerce JSON-loaded floats/strings → int (status "Unknown" fix)
	new_adventurer["status"] = AStatus.READY   # whatever the applicant record held
	new_adventurer["hire_day"] = current_day  # Story 7.1 — cemetery record shows "served day X→Y"
	adventurers.append(new_adventurer)
	var hired_card = new_adventurer.get("tarot_card", "")
	if hired_card != "" and not hired_tarot_cards.has(hired_card):
		hired_tarot_cards.append(hired_card)  # never re-offer this card this run (Epic 4.1)
	remove_hired_recruit(recruit)  # Remove from available pool
	if daily_recruits.is_empty():
		recruit_refresh_day = current_day   # review P1: hired out today, so the desk doesn't make a second pool today
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
		if s is String:
			adv["status"] = AdventurerStatus.from_save(s)
		elif s is int or s is float:
			adv["status"] = int(s)
		else:
			adv["status"] = AStatus.READY   # junk / null (Story 11.2: int(null) aborted the load)
	for k in ["recovery", "hiring_cost", "daily_wage", "id", "strength", "dexterity", "intelligence", "endurance", "missions_completed", "missions_failed", "gold_earned", "injuries_sustained"]:
		if adv.has(k) and adv[k] is float:
			adv[k] = int(adv[k])
	adv.erase("injured")   # Story 4.2 review P2: Reckless's old no-op flag never outlives a load or a hire

# === SAVE/LOAD SYSTEM ===

# Set by load_save_data() so the Continue flow can return the player to the scene they saved in.
var saved_player_scene: String = ""

# Set by main_menu.gd's _start_new_game(), consumed by main_tavern.gd's _ready(). Forces an
# immediate disk save the moment a brand-new game's tavern loads, so New Game -> quit before the
# Day-2 autosave -> Continue restores the fresh game instead of stale state from the prior run.
var pending_new_game_save: bool = false

## Story 13.4 (DG-5): where a new run starts (today the world map; Story 5.1 puts the guild naming screen in front).
const NEW_RUN_SCENE := "res://scenes/HexMapTest.tscn"

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
	# Story 11.2 review (P7): no patron live yet but some waiting to be restored (the hall seats them 2 s after it
	# loads, or the run resumed outside): a save keeps the waiting ones.
	if out.is_empty() and not restored_patrons.is_empty():
		return restored_patrons.duplicate(true)
	return out

func get_save_data() -> Dictionary:
	print("Gathering save data...")

	var save_adventurers = adventurers.duplicate(true)
	for adv in save_adventurers:
		if adv.has("status") and adv.status is int:
			adv.status = AdventurerStatus.for_save(adv.status)

	var data = {
		# The run's profile (Story 14.6 review P5, K-13 provisional): a load keeps the profile the run was saved under
		"profile": DataManager.get_profile(),

		# Core resources
		"gold": gold,
		"gold_peak": gold_peak,   # Story 13.4
		"beer_stock": beer_stock,

		# Time tracking
		"current_day": current_day,
		"day_clock_minutes": day_clock_minutes,   # Story 3.7: the time of day (a Continue resumes it, CL-9)
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
		"hired_tarot_cards": hired_tarot_cards.duplicate(),   # never offered again this run (Epic 4.1; Story 11.2)

		# Missions
		"available_missions": available_missions,
		
		# Patron recruitment pool
		"patron_recruitment_pool": patron_recruitment_pool,

		# Progression
		"total_missions_completed": total_missions_completed,
		"tavern_reputation": tavern_reputation,
		"reputation_peak_tier": reputation_peak_tier,   # Story 14.6 review P9
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
	data.merge(_staff_save_data())     # the staff records (Story 16.1)
	data.merge(_disturbance_save_data())   # today's tavern disturbance and the cooldown (Story 14.4)
	data.merge(_demo_ending_save_data())   # the demo's ending (Story 10.7; "ended" saved as "waiting")
	data.merge(_bard_save_data())   # the Bard's visit (Epic 9)

	print("   Saved: ", data.keys().size(), " fields")
	print("   Day: ", data.current_day, ", Gold: ", data.gold)

	return data

func load_save_data(data: Dictionary):
	"""Load game state from save data - COMPLETE VERSION"""
	print("Loading save data into GameManager...")
	
	# Every value is read defensively (Story 11.2): a junk or null value loads as its default instead of
	# aborting the load half-way; keys this build doesn't know are ignored.
	DataManager.set_run_profile(profile_from_save(data))   # Story 14.6 review P5: first, every config read below is the run's
	# Core resources
	gold = _save_int(data.get("gold"), 10)
	gold_peak = gold_peak_from_save(data.get("gold_peak"), gold, _save_int(DataManager.get_config("starting_gold", 1000), 1000))   # Story 13.4 (+ review P12)
	beer_stock = _save_int(data.get("beer_stock"), 0)

	# Time tracking
	current_day = _save_int(data.get("current_day"), 1)
	_load_day_clock(data)   # Story 3.7 (after the run's profile is set: the day's length is the profile's)
	tax_due_day = _save_int(data.get("tax_due_day"), 30)

	# Adventurers
	adventurers = _save_dicts(data.get("adventurers"))
	for adv in adventurers:
		_normalize_adventurer_ints(adv)
	max_adventurers = DataManager.get_config("max_adventurers", 5)

	# Beer shortage tracking
	beer_shortage_days = _save_int(data.get("beer_shortage_days"), 0)
	adventurer_morale = _morale_from_save(data.get("adventurer_morale"))

	# Firewood system
	firewood_stock = _save_int(data.get("firewood_stock"), 0)
	fireplace_fuel = _save_float(data.get("fireplace_fuel"), 100.0)

	# Recruitment
	daily_recruits = _save_dicts(data.get("daily_recruits"))
	for rec in daily_recruits:
		_normalize_adventurer_ints(rec)
		heal_applicant_trait(rec)   # Story 4.2 review P9: a pre-4.2 "Greedy" applicant gets the key and its wage
	recruit_refresh_day = _save_int(data.get("recruit_refresh_day"), 0)
	_load_hired_tarot_cards(data.get("hired_tarot_cards"))

	# Missions
	available_missions = _save_dicts(data.get("available_missions"))

	# Patron recruitment pool
	patron_recruitment_pool = _save_array(data.get("patron_recruitment_pool"))

	# Progression
	total_missions_completed = _save_int(data.get("total_missions_completed"), 0)
	tavern_reputation = _save_int(data.get("tavern_reputation"), 0)
	reputation_peak_tier = reputation_peak_from_save(data.get("reputation_peak_tier"), get_reputation_tier_index())   # review P9
	taxes_paid_count = _save_int(data.get("taxes_paid_count"), 0)
	mission_tier_unlocked = _save_int(data.get("mission_tier_unlocked"), 1)
	active_missions = _save_dicts(data.get("active_missions"))
	_relink_active_missions()

	# ID counter
	next_adventurer_id = _save_int(data.get("next_adventurer_id"), 1)
	_rekey_colliding_applicants()   # Story 4.2 review P10: an old save's applicant sharing a taken id gets a new one

	# Tax grace period
	tax_grace_days = _save_int(data.get("tax_grace_days"), 0)
	_clear_unsaved_reports()

	# Run counters + conversation flags (Story 10.2; older saves have none)
	_load_dialogue_data(data)
	_load_staff_data(data)   # the staff records (Story 16.1; an older save: the profile's starting staff)
	_load_disturbance_data(data)   # Story 14.4 (an older save: none)
	_load_demo_ending_data(data)   # Story 10.7 (an older save: none, then re-evaluated silently)
	_load_bard_data(data)   # Epic 9 (an older save: no visit)

	# World map (restore hex grid so mission board works after load) + the Latest News rumours (Story 11.2)
	var world_data = data.get("world_data", {})
	if world_data is Dictionary and not world_data.is_empty():
		WorldManager.load_save_data(world_data)
	else:
		WorldManager.clear_world()   # review P13: no map, tavern hex or rumours from the run before

	# Player position — hand it to PlayerManager so the loaded scene spawns the player there
	# (SaveSystem.resume_scene() drops it again when the saved scene can't be resumed).
	var spot: Dictionary = SaveSystem.player_spot(data)
	if spot.is_empty():
		PlayerManager.clear_pending_spawn()
	else:
		PlayerManager.pending_spawn_position = Vector3(spot.x, spot.y, spot.z)
		PlayerManager.has_pending_spawn = true
	var scene = data.get("player_scene", "")
	saved_player_scene = scene if scene is String else ""
	restored_patrons = _save_array(data.get("patrons_active"))

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
	reputation_changed.emit(tavern_reputation)   # Story 11.2: the HUD's reputation, the notice board, the hire pool
	missions_changed.emit()
	recruitment_pool_changed.emit()

	print("Game state loaded successfully")
	print("   Day: ", current_day)
	print("   Gold: ", gold)
	print("   Beer: ", beer_stock)
	print("   Adventurers: ", adventurers.size())
	print("   Firewood: ", firewood_stock)
	print("   Fuel: ", fireplace_fuel, "%")

# === Load helpers (Story 11.2) ===

## Story 14.6 review P5 (K-13, provisional): the profile a save was made under (pure): its "profile"; an older save
## without one, junk or "" is the full game (the demo build shipped after the full game's saves existed).
static func profile_from_save(data: Dictionary) -> String:
	var p = data.get("profile")
	return p if p is String and p != "" else "full"

## A saved number read defensively: an int or a float (or a numeric string) as itself, anything else (null, junk)
## as `fallback`. int(null) aborts load_save_data half-way and leaves a half-loaded run.
static func _save_int(v, fallback: int) -> int:
	if v is int or v is float:
		return int(v)
	if v is String and (v as String).is_valid_float():
		return int(float(v))
	return fallback

static func _save_float(v, fallback: float) -> float:
	if v is int or v is float:
		return float(v)
	if v is String and (v as String).is_valid_float():
		return float(v)
	return fallback

## A saved list: anything that isn't an Array loads as [].
static func _save_array(v) -> Array:
	return (v as Array).duplicate() if v is Array else []

## A saved list of records (roster, recruits, missions): [] unless an Array; entries that aren't Dictionaries drop.
static func _save_dicts(v) -> Array:
	if not (v is Array):
		return []
	return (v as Array).filter(func(e): return e is Dictionary)

## Morale is keyed by the adventurer's int id, but JSON brings the keys back as Strings ("60"), so every lookup
## missed and each adventurer read as neutral after a load. Numeric keys go back to ints, levels to ints.
static func _morale_from_save(v) -> Dictionary:
	var out := {}
	if not (v is Dictionary):
		return out
	for k in v:
		var key = k
		if k is String and (k as String).is_valid_int():
			key = int(k)
		elif k is float:
			key = int(k)
		out[key] = _save_int(v[k], 2)
	return out

## The tarot cards hired this run (never offered again, Epic 4.1). A save from before Story 11.2 has none: the
## cards of the adventurers on the roster are the best guess.
func _load_hired_tarot_cards(v) -> void:
	hired_tarot_cards = []
	var source: Array = v if v is Array else adventurers.map(func(a): return a.get("tarot_card", ""))
	for c in source:
		if c is String and c != "" and not hired_tarot_cards.has(c):
			hired_tarot_cards.append(c)

## In play an active_missions entry holds the roster's own adventurer dicts (send_on_mission); a JSON load brings
## back copies, so the mission's resolution updated the copy and left the roster adventurer On Mission for good.
## Each entry's adventurer / party member becomes the roster dict with the same id again: the member's own id when
## it is on the roster (review P9: a reordered "adventurer_ids" can't swap two adventurers), else the entry's
## "adventurer_ids" (Story 6.5) at the same place; an id on neither keeps the saved copy, normalised, with a
## warning. The entry's day counts and chance come back as ints (review P8: JSON makes them floats).
func _relink_active_missions() -> void:
	var by_id := {}
	for adv in adventurers:
		by_id[_id_key(adv.get("id"))] = adv
	for entry in active_missions:
		var ids = entry.get("adventurer_ids", [])
		if not (ids is Array):
			ids = []
		if entry.has("party"):
			var party = entry.get("party")
			if not (party is Array):
				entry["party"] = []
				continue
			var linked: Array = []
			for i in party.size():
				var member = party[i]
				linked.append(_roster_or_copy(by_id, _member_id(by_id, member, ids, i), member, entry))
			entry["party"] = linked
		elif entry.get("adventurer") is Dictionary:
			var a: Dictionary = entry["adventurer"]
			entry["adventurer"] = _roster_or_copy(by_id, _member_id(by_id, a, ids, 0), a, entry)
		for k in ["days_remaining", "total_duration", "sent_day", "success_chance", "dispatch_day", "return_day", "travel_duration"]:
			if entry.get(k) is float:
				entry[k] = int(entry[k])
		if entry.get("adventurer_ids") is Array:
			entry["adventurer_ids"] = (entry["adventurer_ids"] as Array).map(func(i): return _id_key(i))

## The id a saved member re-links by: its own when that is on the roster, else adventurer_ids[i], else its own.
static func _member_id(by_id: Dictionary, member, ids: Array, i: int):
	var own = member.get("id") if member is Dictionary else null
	if by_id.has(_id_key(own)):
		return own
	if i < ids.size():
		return ids[i]
	return own

func _roster_or_copy(by_id: Dictionary, id, saved, entry: Dictionary):
	var key = _id_key(id)
	if by_id.has(key):
		return by_id[key]
	var m = entry.get("mission")
	push_warning("[GameManager] load: adventurer %s on '%s' is not on the roster; keeping the saved copy"
		% [id, m.get("name", "?") if m is Dictionary else "?"])
	if saved is Dictionary:
		_normalize_adventurer_ints(saved)
	return saved

## A saved id as the roster keys it: JSON turns int ids into floats (61.0).
static func _id_key(v):
	if v is float and v == floorf(v):
		return int(v)
	if v is String and (v as String).is_valid_int():
		return int(v)
	return v

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
		"fallen_this_run": fallen_this_run.duplicate(),   # Story 14.4 review P4
		"dialogue_flags": dialogue_flags.duplicate(),
		"den_fa_state": den_fa_state,
		"codex_first_opened": codex_first_opened,   # Story 18.5
	}

func _load_dialogue_data(data: Dictionary) -> void:
	adventurers_hired_this_run = _save_count(data.get("adventurers_hired_this_run", 0))
	deaths_this_run = _save_count(data.get("deaths_this_run", 0))
	var names = data.get("fallen_this_run", [])   # Story 14.4 review P4: names only; an older save has none
	fallen_this_run = (names as Array).filter(func(n): return n is String and n != "") if names is Array else []
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
	# Story 18.5: Den Fa's line about the Codex was said this run (a bool; an older save or junk: not yet).
	var heard = data.get("codex_first_opened", false)
	codex_first_opened = heard if heard is bool else false

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
	fallen_this_run = []
	dialogue_flags = {}
	den_fa_state = "early"            # silently, like a load: no den_fa_state_changed
	_den_fa_tier_warnings = 0         # "once a run": a New Game warns again
	codex_first_opened = false        # Story 18.5: Den Fa says his line about the Codex again in a new run

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

## The guild falls. `failure_type` is the cause key (bankruptcy, soft_lock; Story 21.3 adds no_survivors), `reason` a
## sentence for the log. Story 13.4: the run is recorded before anything hears of it (DG-2): last_run_summary is frozen,
## SaveSystem.end_run() writes the codex.dat entry and moves the save out of the slot; then GameManager stops and
## game_over_triggered(cause) goes out (GameBus too); the hall's "The Guild Falls" screen listens. Once only.
func trigger_game_over(failure_type: String, reason: String):
	if game_over_active:
		return  # Prevent multiple game overs

	game_over_active = true
	log_message("FAILURE: " + reason)
	log_message("GAME OVER!")
	log_message("[GameManager] fall: %s on day %d" % [failure_type, current_day])

	last_run_summary = run_summary(failure_type)
	SaveSystem.end_run(last_run_summary)

	# Stop all game processes
	set_process_mode(Node.PROCESS_MODE_DISABLED)

	# DG-1: the cause key is the payload (the screen's reason line is data/reveal/guild_falls.json's, keyed by it)
	game_over_triggered.emit(failure_type)

## Story 13.4 (DG-3): the run's numbers at the fall: the screen's three stats and codex.dat's guild_history entry.
## days_survived: a fall comes at a day's start, so the days before it. No heir (legacy_adventurer null): a fall carries
## nobody over until Epics 21/22.
func run_summary(cause: String) -> Dictionary:
	var alive := 0
	for adv in adventurers:
		if adv is Dictionary and adv.get("status") != AStatus.DEAD:
			alive += 1
	return {"cause": cause, "ending": "fall", "end_day": current_day, "days_survived": maxi(0, current_day - 1),
		"adventurers_lost": deaths_this_run, "adventurers_hired": adventurers_hired_this_run, "survivors": alive,
		"gold_peak": maxi(gold_peak, gold), "gold_at_end": gold, "missions_completed": total_missions_completed,
		"taxes_paid": taxes_paid_count, "reputation": tavern_reputation, "legacy_adventurer": null,
		"timestamp": Time.get_unix_time_from_system()}

## Story 13.4: a saved gold_peak, never below the loaded gold nor the run's starting gold (review P12: an old save could
## read below it); an old save (no key) or junk: the loaded gold. Pure; the caller passes the active starting gold.
static func gold_peak_from_save(v, gold_now: int, starting := 0) -> int:
	return maxi(maxi(_save_int(v, gold_now), gold_now), starting)

## Story 13.4 (DG-9, review P2: "no way back", pure): the guild can't go on when no adventurer is alive, no applicant can
## be hired with the gold, and the bar can't earn (can_earn_at_bar: no beer to sell, not the price of a pint).
## Story 4.2 review P8: with the whole deck dealt (`deck_out`) no applicant will ever come again, so an empty roster with
## nobody hireable is the end whatever the bar can earn.
static func is_soft_locked(alive: int, hireable: int, can_earn: bool, deck_out := false) -> bool:
	return alive <= 0 and hireable <= 0 and (deck_out or not can_earn)

## Story 13.4 review P2 (pure): the bar can still make money: beer in stock to sell, or the gold for one pint to buy.
static func can_earn_at_bar(beer: int, gold_now: int, pint_price: int) -> bool:
	return beer > 0 or gold_now >= pint_price

## Today's applicants the hire authority (hire_block_reason, Story 4.2) would let the guild hire now.
func hireable_count() -> int:
	var n := 0
	for r in get_available_recruits():
		if r is Dictionary and hire_block_reason(r) == "":
			n += 1
	return n

## The morning's soft-lock check (the end of advance_day): the fall when the guild can't go on (review P2: no way back);
## close to it (no one to send, gold under soft_lock_gold_below) it only warns.
func _check_soft_lock() -> void:
	if game_over_active:
		return   # review P6: a guild that fell this morning is not checked again
	var alive := 0
	for adv in adventurers:
		if adv is Dictionary and adv.get("status") != AStatus.DEAD:
			alive += 1
	var hireable := hireable_count()
	var price := _save_int(DataManager.get_config("beer_pint_price", 1), 1)
	if is_soft_locked(alive, hireable, can_earn_at_bar(beer_stock, gold, price), deck_exhausted()):
		log_message("[GameManager] warn: soft-lock condition detected on day %d" % current_day)
		log_message("The guild cannot recover. No adventurers, no funds, no prospects.")
		trigger_game_over("soft_lock", "The Eternal Guild fades into history — abandoned and forgotten.")
	elif alive <= 0 and hireable <= 0 and gold < _save_int(DataManager.get_config("soft_lock_gold_below", 8), 8):
		log_message("[GameManager] warn: low gold (%d) and no one to send on day %d; the bar can still earn" % [gold, current_day])

## Story 13.4 (DG-5): the one way into a new run, shared by the main menu's New Game and the fall screen's New Run:
## the run state reset (nothing carried over) and the new run's first save made when the hall loads. Story 5.1's naming
## screen goes in front of NEW_RUN_SCENE; Epic 22's LegacyTransition wraps this (execute_total_wipe) or follows The
## Reading (execute) for a run with an heir. Callers change scene to NEW_RUN_SCENE.
func begin_new_run() -> void:
	DataManager.clear_run_profile()   # Story 14.6 review P5: a new run takes game_config.json's profile
	reset_game_state()
	pending_new_game_save = true

func reset_game_state():
	print("Resetting game state...")
	_tax_warnings = 0   # a bad tax config is warned about again in the new run (Story 13.1)
	_rep_warnings = 0          # Story 14.6: the rep gains and the death multiplier, too
	_death_mult_warnings = 0
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
	WorldManager.reset_run_state()  # no Latest News rumours from the previous run (Story 11.2)
	# Story 11.2 review: nothing waiting from the last run's load (P7: its patrons, scene and spot), and no live run
	# until New Game's first save (P1: the automatic saves wait for it).
	restored_patrons = []
	saved_player_scene = ""
	PlayerManager.clear_pending_spawn()
	SaveSystem.run_active = false

	# Missions
	available_missions.clear()
	active_missions.clear()      # adventurers currently out — must not carry into a new run
	pending_reports.clear()
	has_pending_briefing = false
	mission_refresh_day = 1

	# Progression / run stats (a New Game must not inherit the previous run's progress)
	total_missions_completed = 0
	tavern_reputation = 0
	reputation_peak_tier = 0   # Story 14.6 review P9
	taxes_paid_count = 0
	tax_grace_days = 0
	mission_tier_unlocked = 1
	_reset_dialogue_state()  # run counters + conversation flags (Story 10.2)
	_reset_staff_state()     # the profile's starting staff (Story 16.1)
	_reset_disturbance_state()   # Story 14.4
	_reset_demo_ending_state()   # Story 10.7
	_reset_bard_state()   # Epic 9
	_reset_day_clock()   # Story 3.7: 6:00

	# Game state
	game_over_active = false
	last_run_summary = {}   # Story 13.4
	
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
		total += wage_of(adv)   # the wage the roster shows (Story 4.3)
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
			SaveSystem.record_artifact_found(artifact_id, recipient)   # Story 18.3: the finder, for the Codex
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
	
	var final_death_chance = base_death_chance * danger_multiplier * death_chance_multiplier() + beer_penalty   # Story 14.6, K-8
	
	# Cap at 80% max death chance (always some hope)
	return min(final_death_chance, 0.8)

## Story 14.6 (K-8, Raphael 2026-11-01: deaths likelier in the demo): game_config.json death_chance_multiplier scales the
## level's base x the danger step (the beer penalty is added after; the 80% cap stays). Pure: a number >= 0 as itself;
## missing -> 1, silently; anything else -> 1, with a warning text in `warn`.
static func death_multiplier_from(v, warn: Array = []) -> float:
	if v == null:
		return 1.0
	if (v is int or v is float) and is_finite(float(v)) and float(v) >= 0.0:
		return float(v)
	warn.append("[GameManager] fallback: death_chance_multiplier is %s, not a number >= 0; using 1" % [v])
	return 1.0

## The active profile's death multiplier (the demo's 2, the full game's 1), warned once a run.
func death_chance_multiplier() -> float:
	var warn: Array = []
	var m := death_multiplier_from(DataManager.get_config("death_chance_multiplier"), warn)
	if not warn.is_empty() and _death_mult_warnings == 0:
		_death_mult_warnings += 1
		push_warning(warn[0])
	return m

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
	# The death itself, first (D3 review P0): the resolvers build the morning report from this same dictionary
	# ("alive" = status != DEAD; a party's casualties and each member's fate), so without it every death read as a
	# return and the Reveal's death beat (Story 7.3) never played. Stories 19.5 and 9.5 rely on it.
	adventurer["status"] = AStatus.DEAD
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
	fallen_this_run.append(str(adventurer.get("name", "")))   # Story 14.4 review P4: the mourner names this run's dead
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
	"""Refresh the mission pool with tier restrictions. Story 6.5: the demo profile's refresh also carries party
	missions (DD-7), and missions_changed fires once the missions are on their hexes, so an open World Map draws them."""
	if DataManager and DataManager.has_method("generate_daily_missions_with_tiers"):
		var new_missions = DataManager.generate_daily_missions_with_tiers(6, mission_tier_unlocked)
		var party_rule := _party_missions_for_refresh()
		if int(party_rule.wanted) > 0:
			var party_templates := _party_templates_up_to(int(party_rule.max_tier))
			if party_templates.is_empty():
				_warn_party_missions_once("[GameManager] fallback: no party templates up to tier %d; no party missions this refresh" % int(party_rule.max_tier))
			new_missions = with_party_missions(new_missions, party_templates, int(party_rule.wanted))
		available_missions.clear()
		for mission in new_missions:
			available_missions.append(mission)
		mission_refresh_day = current_day
		print("Refreshed missions (Tier ", mission_tier_unlocked, "): ", available_missions.size(), " missions loaded")
	else:
		# Fallback
		var fallback_missions = generate_fallback_missions()
		available_missions.clear()
		for mission in fallback_missions:
			available_missions.append(mission)
		print("Using fallback missions")
	WorldManager.assign_missions_to_hexes(available_missions)
	missions_changed.emit()   # after the hexes hold them (Story 6.5); the hall's notice board recounts on this too (Story 25.7 review)


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
