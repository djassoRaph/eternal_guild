# day_clock_rules.gd — the day clock's rules (Story 3.7; decision log K-14…K-19), pure and static. GameManager keeps the
# clock's state (day_clock_minutes, saved) and its config; the persistent DayClock node (day_clock.gd, GameManager's
# child) ticks it in every day scene and is the one sender of GameBus.day_phase_changed; Test 70 feeds these fixtures.
#
# Time is "minutes since midnight of the day's start": 6:00 = 360, 23:00 = 1380, 0:00 = 1440, 2:00 the next morning =
# 1560. A day runs from start_hour to end_hour (6 → 26 = 2:00) in real time: seconds_per_hour real seconds per in-game
# hour (the demo's 18: a 6-minute day, K-14; the full game's 30: 10 minutes, K-18).
#
# Phases: each phase's start hour, in order (TavernLighting's names: morning 6, day 9, dusk 17, evening 19, late_night
# 23; "dawn" is the Departure's, never on the clock). The hall's open hours (OPEN_PHASES: day, dusk, evening) are when
# its visitors may walk in (CL-13). Patrons per phase: patron_phase_rates (rate_for).
#
# No class_name: loaded by path (GameManager preloads it); no autoload names in here.
extends RefCounted

const PHASE_NAMES := ["morning", "day", "dusk", "evening", "late_night", "dawn"]   # TavernLighting.PHASES
## The hall's open hours (Story 3.7 CL-13): the tavern's visitors and the King's messenger may walk in.
const OPEN_PHASES := ["day", "dusk", "evening"]
const MAX_SECONDS_PER_HOUR := 600.0
const DEFAULT_SECONDS_PER_HOUR := 30.0
## day_clock's keys and their defaults (hours; display_step_minutes in minutes; wake_spot hall coordinates).
const DEFAULTS := {
	"start_hour": 6.0,
	"end_hour": 26.0,
	"phases": {"morning": 6.0, "day": 9.0, "dusk": 17.0, "evening": 19.0, "late_night": 23.0},
	"sleep_from_hour": 20.0,
	"closing_hour": 24.0,
	"tired_warning_hour": 25.0,
	"display_step_minutes": 10,
	"wake_spot": [14.0, 0.5, -13.4],
}
## A patron row when the table has none for a phase: the spawner's own values (today's 20 s, 5).
const RATE_FALLBACK := {"spawn_interval": 20.0, "max_patrons": 5}
const MAX_PATRONS_LIMIT := 12
const TEXT_PATH := "res://data/narrative/day_clock.json"
## The clock's words (DRAFT, Raphael rewrites); data/narrative/day_clock.json overrides each.
const TEXT_DEFAULTS := {
	"phase_names": {"morning": "Morning", "day": "Day", "dusk": "Dusk", "evening": "Evening", "late_night": "Late night",
		"dawn": "Dawn"},
	"too_early": "It's too early to sleep.",
	"sleep_from": "(from %s)",
	"last_call": "Last call.",
	"closing": "The last guests head home.",
	"tired": "It's late. Find your bed, or you'll fall asleep where you stand.",
	"nod_off": "You nod off where you stand…",
}

static var _text: Dictionary = {}


# ---------------------------------------------------------------- config

## day_clock (the object) and day_clock_seconds_per_hour (a number), the run's profile resolved, as
## {start, end, phases: [[start_minutes, name], ...], sleep_from, closing, tired, step, wake_spot: Vector3,
## seconds_per_hour, warnings}. Minutes throughout. No object (missing, or not an object) or no number: the defaults,
## silently. A bad value inside: its default, with one "[GameManager] fallback: day_clock …" text in `warnings`.
static func config_from(raw, seconds_per_hour_raw) -> Dictionary:
	var warn: Array = []
	var d: Dictionary = raw if raw is Dictionary else {}
	var start := _hour(d, "start_hour", 0.0, 23.99, warn)
	var end := _hour(d, "end_hour", start + 0.01, start + 24.0, warn)
	var phases := _phases(d.get("phases"), d.has("phases"), start, end, warn)
	var sleep_from := _hour(d, "sleep_from_hour", start, end - 0.001, warn)
	var closing := _hour(d, "closing_hour", start, end, warn)
	var tired := _hour(d, "tired_warning_hour", start, end - 0.001, warn)
	var step := int(DEFAULTS.display_step_minutes)
	if d.has("display_step_minutes"):
		var s = d.display_step_minutes
		if _num(s) and float(s) >= 1.0 and float(s) <= 60.0 and is_equal_approx(float(s), roundf(float(s))):
			step = int(s)
		else:
			warn.append("[GameManager] fallback: day_clock.display_step_minutes %s is not a whole number 1..60; using %d" % [s, step])
	var ws: Array = DEFAULTS.wake_spot
	if d.has("wake_spot"):
		var w = d.wake_spot
		if w is Array and (w as Array).size() == 3 and (w as Array).all(func(x): return _num(x)):
			ws = w
		else:
			warn.append("[GameManager] fallback: day_clock.wake_spot %s is not three numbers; using %s" % [w, DEFAULTS.wake_spot])
	var sph := DEFAULT_SECONDS_PER_HOUR
	if seconds_per_hour_raw != null:
		if _num(seconds_per_hour_raw) and float(seconds_per_hour_raw) > 0.0 and float(seconds_per_hour_raw) <= MAX_SECONDS_PER_HOUR:
			sph = float(seconds_per_hour_raw)
		else:
			warn.append("[GameManager] fallback: day_clock_seconds_per_hour %s is not a number in (0, %d]; using %d" % [
				seconds_per_hour_raw, int(MAX_SECONDS_PER_HOUR), int(DEFAULT_SECONDS_PER_HOUR)])
	return {"start": start * 60.0, "end": end * 60.0, "phases": phases, "sleep_from": sleep_from * 60.0,
		"closing": closing * 60.0, "tired": tired * 60.0, "step": step,
		"wake_spot": Vector3(float(ws[0]), float(ws[1]), float(ws[2])), "seconds_per_hour": sph, "warnings": warn}


## A key's hour in [lo, hi], else its default (when the default fits) with a warning; a missing key: the default, with a
## warning only when the object exists but lacks it.
static func _hour(d: Dictionary, key: String, lo: float, hi: float, warn: Array) -> float:
	var def := float(DEFAULTS[key])
	if not d.has(key):
		if not d.is_empty():
			warn.append("[GameManager] fallback: day_clock.%s is missing; using %s" % [key, def])
		return def
	var v = d[key]
	if _num(v) and float(v) >= lo and float(v) <= hi:
		return float(v)
	warn.append("[GameManager] fallback: day_clock.%s %s is not a number in [%s, %s]; using %s" % [key, v, lo, hi, def])
	return def


## The phase table as [[start_minutes, name], ...] in order. It must start at `start`, rise strictly, stay before `end`
## and name only TavernLighting's phases; anything else: the default table, with a warning.
static func _phases(v, present: bool, start: float, end: float, warn: Array) -> Array:
	var out: Array = []
	var ok := v is Dictionary
	if ok:
		var pairs: Array = []
		for k in v:
			if str(k).begins_with("_"):
				continue
			if not (str(k) in PHASE_NAMES) or not _num(v[k]):
				ok = false
				break
			pairs.append([float(v[k]) * 60.0, str(k)])
		pairs.sort_custom(func(a, b): return a[0] < b[0])
		if ok and (pairs.is_empty() or not is_equal_approx(pairs[0][0], start * 60.0)):
			ok = false
		for i in range(1, pairs.size()):
			if not ok:
				break
			if pairs[i][0] <= pairs[i - 1][0]:
				ok = false
		if ok and pairs.back()[0] >= end * 60.0:
			ok = false
		if ok:
			out = pairs
	if not ok:
		if present:
			warn.append("[GameManager] fallback: day_clock.phases %s must start at start_hour, rise strictly, end before end_hour and name only %s; using the defaults" % [v, PHASE_NAMES])
		out = []
		for k in DEFAULTS.phases:
			out.append([float(DEFAULTS.phases[k]) * 60.0, str(k)])
		out.sort_custom(func(a, b): return a[0] < b[0])
	return out


static func _num(v) -> bool:
	return (v is int or v is float) and is_finite(float(v))


# ---------------------------------------------------------------- time

## The phase at `minutes`: the last phase starting at or before it (before the first: the first; past the end: the last).
static func phase_for(minutes: float, cfg: Dictionary) -> String:
	var ph: Array = cfg.get("phases", [])
	if ph.is_empty():
		return ""
	var p: String = ph[0][1]
	for e in ph:
		if minutes >= float(e[0]):
			p = e[1]
	return p


## The phases to send going from `from` to `to`, in order: every phase after `from` up to and including `to`. The same
## phase: none. Going back (the minutes returned to the start: a new day) or from an unknown phase: just `to`.
static func phases_between(from: String, to: String, cfg: Dictionary) -> Array:
	if from == to:
		return []
	var names: Array = (cfg.get("phases", []) as Array).map(func(e): return e[1])
	var a := names.find(from)
	var b := names.find(to)
	if a < 0 or b < 0 or b < a:
		return [to]
	return names.slice(a + 1, b + 1)


## "18:40": hours mod 24, no leading zero, minutes floored to `step`.
static func format_time(minutes: float, step: int = 1) -> String:
	var m := int(floor(minutes))
	var st := maxi(step, 1)
	m -= posmod(m, st)
	return "%d:%02d" % [posmod(m / 60, 24), posmod(m, 60)]


## In-game minutes per real second (× the debug speed).
static func minutes_per_second(cfg: Dictionary, speed: float = 1.0) -> float:
	return 60.0 / maxf(float(cfg.get("seconds_per_hour", DEFAULT_SECONDS_PER_HOUR)), 0.001) * speed


static func can_sleep(minutes: float, cfg: Dictionary) -> bool:
	return minutes >= float(cfg.get("sleep_from", 1200.0))


## "" when sleep is allowed, else "It's too early to sleep. (from 20:00)" (DRAFT words from day_clock.json).
static func sleep_block(minutes: float, cfg: Dictionary) -> String:
	if can_sleep(minutes, cfg):
		return ""
	return "%s %s" % [text("too_early"), str(text("sleep_from")) % format_time(float(cfg.get("sleep_from", 1200.0)), 1)]


## At or after closing: the guests not yet served go home (CL-6).
static func is_closing(minutes: float, cfg: Dictionary) -> bool:
	return minutes >= float(cfg.get("closing", 1440.0))


## A saved clock (CL-9) as {minutes, warning}: none (an older save) → the start, silently; junk or before the start → the
## start, with a warning; at or past the end (saved during a night) → one minute before the end, so the nod-off follows.
static func from_save(v, cfg: Dictionary) -> Dictionary:
	var start := float(cfg.get("start", 360.0))
	var end := float(cfg.get("end", 1560.0))
	if v == null:
		return {"minutes": start, "warning": ""}
	if not _num(v) or float(v) < start:
		return {"minutes": start, "warning": "[GameManager] fallback: the saved day_clock_minutes %s is not a time of the day; %s" % [v, format_time(start)]}
	if float(v) >= end:
		return {"minutes": end - 1.0, "warning": ""}
	return {"minutes": float(v), "warning": ""}


# ---------------------------------------------------------------- patrons

## A phase's patron row from patron_phase_rates as {spawn_interval (s; 0 = no timed spawns), max_patrons, warning}. No
## table, no row or a bad row: `fallback` (the spawner's own values), with a warning when the table exists.
static func rate_for(phase: String, rates, fallback: Dictionary = RATE_FALLBACK) -> Dictionary:
	var out := {"spawn_interval": float(fallback.get("spawn_interval", 20.0)), "max_patrons": int(fallback.get("max_patrons", 5)), "warning": ""}
	if not (rates is Dictionary):
		return out
	var row = (rates as Dictionary).get(phase)
	if row is Dictionary and _num(row.get("spawn_interval")) and float(row.spawn_interval) >= 0.0 \
			and _num(row.get("max_patrons")) and int(row.max_patrons) >= 0 and int(row.max_patrons) <= MAX_PATRONS_LIMIT \
			and is_equal_approx(float(row.max_patrons), roundf(float(row.max_patrons))):
		out.spawn_interval = float(row.spawn_interval)
		out.max_patrons = int(row.max_patrons)
	else:
		out.warning = "[Patrons] fallback: patron_phase_rates.%s %s is not {spawn_interval >= 0, max_patrons 0..%d}; using %s s, %d" % [
			phase, row, MAX_PATRONS_LIMIT, out.spawn_interval, out.max_patrons]
	return out


# ---------------------------------------------------------------- words

## The clock's words: day_clock.json over TEXT_DEFAULTS (DRAFT). `key` "phase_names" returns the dictionary.
static func text(key: String):
	if _text.is_empty():
		_text = TEXT_DEFAULTS.duplicate(true)
		if FileAccess.file_exists(TEXT_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(TEXT_PATH))
			if parsed is Dictionary:
				for k in parsed:
					if str(k).begins_with("_") or not _text.has(k):
						continue
					if _text[k] is Dictionary and parsed[k] is Dictionary:
						for kk in parsed[k]:
							if parsed[k][kk] is String:
								_text[k][kk] = parsed[k][kk]
					elif parsed[k] is String:
						_text[k] = parsed[k]
	return _text.get(key, "")


static func phase_name(phase: String) -> String:
	var names = text("phase_names")
	return str(names.get(phase, phase.capitalize())) if names is Dictionary else phase.capitalize()


## The HUD's line: "20:40 · Evening".
static func hud_text(minutes: float, cfg: Dictionary) -> String:
	return "%s · %s" % [format_time(minutes, int(cfg.get("step", 10))), phase_name(phase_for(minutes, cfg))]
