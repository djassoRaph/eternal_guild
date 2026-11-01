# bard_rules.gd — the Bard's rules (Epic 9, Stories 9.1-9.5), pure and static. GameManager keeps the visit (bard_visit:
# {day, state, hook, arrive_minute, wait_until}; saved) and calls these; the hall's controller (scripts/game/bard.gd) and
# Tests 39-43 feed them fixtures. Time is the day clock's (Story 3.7): minutes since midnight of the day's start
# (6:00 = 360, 23:00 = 1380, 0:00 = 1440).
#
# The visit (9.1): a schedule entry for today (profiles.demo: day 3, with a hook) wins over every gate; else the guild's
# reputation tier at least bard_min_tier, bard_cooldown_days since the last visit and a roll under bard_daily_chance. He
# arrives at a minute rolled in bard_arrival_hours (the hall's open hours, day_clock_rules.OPEN_PHASES), waits
# bard_wait_hours of clock time at the door, and plays (if let in) until the clock's closing hour.
#
# No class_name: loaded by path (GameManager preloads it); no autoload names in here.
extends RefCounted

## The visit's states, in order: queued in the morning, at the door, let in, turned away (or tired of waiting).
const STATES := ["coming", "waiting", "performing", "refused"]
## game_config.json's bard_* keys -> their names here, and the values used when a key is missing (DRAFT numbers).
const KEYS := {
	"bard_daily_chance": "daily_chance", "bard_cooldown_days": "cooldown_days", "bard_min_tier": "min_tier",
	"bard_schedule": "schedule", "bard_arrival_hours": "arrival_hours", "bard_arrival_delay_seconds": "arrival_delay_seconds",
	"bard_wait_hours": "wait_hours",
}
const DEFAULTS := {
	"daily_chance": 0.25, "cooldown_days": 3, "min_tier": "Known", "schedule": [], "arrival_hours": [11.0, 19.0],
	"arrival_delay_seconds": 5.0, "wait_hours": 3.0,
}


# ---------------------------------------------------------------- config (Story 9.1)

## The bard_* keys of `raw` (the active profile's values) checked, as DEFAULTS' names. A missing key takes its default
## silently; a bad one takes it with one "[GameManager] fallback: bard_…" text in `warn`; a schedule entry without a whole
## day >= 2 is skipped with a text (Day 1 has no morning roll).
static func config_from(raw: Dictionary, warn: Array = []) -> Dictionary:
	var out := DEFAULTS.duplicate(true)
	for k in KEYS:
		if not raw.has(k):
			continue
		var v = raw[k]
		var name: String = KEYS[k]
		match name:
			"daily_chance":
				if _num(v) and float(v) >= 0.0 and float(v) <= 1.0:
					out[name] = float(v)
					continue
			"cooldown_days":
				if _whole(v) and int(v) >= 0:
					out[name] = int(v)
					continue
			"min_tier":
				if v is String and v != "":
					out[name] = v
					continue
			"arrival_hours":
				if v is Array and (v as Array).size() == 2 and _num(v[0]) and _num(v[1]) and float(v[0]) <= float(v[1]) \
						and float(v[0]) >= 0.0 and float(v[1]) <= 30.0:
					out[name] = [float(v[0]), float(v[1])]
					continue
			"arrival_delay_seconds":
				if _num(v) and float(v) >= 0.0 and float(v) <= 600.0:
					out[name] = float(v)
					continue
			"wait_hours":
				if _num(v) and float(v) > 0.0 and float(v) <= 20.0:
					out[name] = float(v)
					continue
			"schedule":
				if v is Array:
					for e in v:
						if e is Dictionary and _whole(e.get("day")) and int(e.day) >= 2:
							var entry := {"day": int(e.day), "hook": e.get("hook") == true}
							if _num(e.get("hour")):
								entry.hour = float(e.hour)
							out.schedule.append(entry)
						else:
							warn.append("[GameManager] fallback: bard_schedule entry %s needs a whole day >= 2; skipped" % [e])
					continue
		warn.append("[GameManager] fallback: %s %s is not valid; using %s" % [k, v, DEFAULTS[name]])
	return out


## The index of the tier labelled `label` in `tiers` (a reputation_tier_list); an unknown label: 1 (the first tier above
## the base), with one text in `warn`.
static func tier_index_of(label: String, tiers: Array, warn: Array = []) -> int:
	for i in tiers.size():
		if tiers[i] is Dictionary and str(tiers[i].get("label", "")) == label:
			return i
	warn.append("[GameManager] fallback: bard_min_tier '%s' is not a reputation tier; using the second tier" % label)
	return mini(1, maxi(0, tiers.size() - 1))


# ---------------------------------------------------------------- the visit (Story 9.1)

## Today's visit, or {} (pure). `rolls`: [chance, arrival], each in [0, 1). A schedule entry for `day` wins over the tier,
## the cooldown and the chance (its `hook` and `hour` carried); else the tier at least `min_tier_index`, `day - last_day`
## at least the cooldown (no visit yet: always), then the chance. The arrival minute is rolled in arrival_hours.
static func pick_visit(day: int, tier_index: int, min_tier_index: int, last_day: int, cfg: Dictionary, rolls: Array) -> Dictionary:
	var r: Array = rolls if rolls.size() >= 2 else [1.0, 0.0]
	for e in cfg.get("schedule", []):
		if int(e.get("day", 0)) != day:
			continue
		var minute := arrive_minute(cfg, float(r[1]))
		if e.has("hour"):
			minute = int(round(float(e.hour) * 60.0))
		return {"day": day, "state": "coming", "hook": e.get("hook") == true, "arrive_minute": minute, "wait_until": -1}
	if tier_index < min_tier_index:
		return {}
	if last_day > 0 and day - last_day < int(cfg.get("cooldown_days", 3)):
		return {}
	if float(r[0]) >= float(cfg.get("daily_chance", 0.25)):
		return {}
	return {"day": day, "state": "coming", "hook": false, "arrive_minute": arrive_minute(cfg, float(r[1])), "wait_until": -1}


## The minute he comes to the door: arrival_hours' span at `roll` in [0, 1), whole minutes.
static func arrive_minute(cfg: Dictionary, roll: float) -> int:
	var h: Array = cfg.get("arrival_hours", DEFAULTS.arrival_hours)
	var lo := float(h[0]) * 60.0
	var hi := float(h[1]) * 60.0
	return int(floor(lo + clampf(roll, 0.0, 0.999999) * (hi - lo)))


## Whether he walks in now (pure): today's visit "coming", its minute reached, one of the hall's open phases, the run not
## fallen and nothing holding the hall (another visitor, a screen, a conversation).
static func may_arrive(visit: Dictionary, day: int, phase: String, minutes: float, open_phases: Array, game_over: bool,
		blocked: bool) -> bool:
	return str(visit.get("state", "")) == "coming" and int(visit.get("day", -1)) == day and phase in open_phases \
		and minutes >= float(visit.get("arrive_minute", 0)) and not game_over and not blocked


## Whether a waiting Bard's patience ran out (pure): waiting, and the clock at or past wait_until.
static func wait_over(visit: Dictionary, minutes: float) -> bool:
	return str(visit.get("state", "")) == "waiting" and float(visit.get("wait_until", -1)) >= 0.0 \
		and minutes >= float(visit.get("wait_until", 0))


## A saved visit (pure) as {visit, warning}: none ({} or missing) -> {} silently; junk, an unknown state or a bad day ->
## {} with a warning; a good one read back with whole numbers.
static func visit_from_save(v) -> Dictionary:
	if v == null or (v is Dictionary and (v as Dictionary).is_empty()):
		return {"visit": {}, "warning": ""}
	if not (v is Dictionary) or not (str(v.get("state", "")) in STATES) or not _whole(v.get("day")) or int(v.day) < 1:
		return {"visit": {}, "warning": "[GameManager] load: bard_visit %s is not a visit; none" % [v]}
	return {"visit": {"day": int(v.day), "state": str(v.state), "hook": v.get("hook") == true,
		"arrive_minute": int(v.get("arrive_minute", 0)) if _num(v.get("arrive_minute")) else 0,
		"wait_until": int(v.get("wait_until", -1)) if _num(v.get("wait_until")) else -1}, "warning": ""}


## A line index for `count` lines that is never `last` again (-1 when there are none); `roll` in [0, 1).
static func pick_index(count: int, last: int, roll: float) -> int:
	if count <= 0:
		return -1
	if count == 1:
		return 0
	roll = clampf(roll, 0.0, 0.999999)
	if last < 0 or last >= count:
		return int(roll * count)
	var i := int(roll * (count - 1))
	return i + 1 if i >= last else i


static func _num(v) -> bool:
	return (v is int or v is float) and is_finite(float(v))


static func _whole(v) -> bool:
	return _num(v) and is_equal_approx(float(v), roundf(float(v)))
