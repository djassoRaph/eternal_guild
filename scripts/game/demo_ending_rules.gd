# demo_ending_rules.gd — the demo ending's rules (Story 10.7; sprint-change-proposal-2026-10-31.md K-2, K-3), pure and
# static: GameManager (the day authority) keeps the state and calls these; Test 53 feeds them fixtures.
# The state is {} (nothing yet) or {"state", "day", "returning"}:
#   "due"     — both conditions held on day - 1 (reputation >= min_reputation AND taxes paid >= min_taxes_paid): the
#               King's messenger comes on `day` (the next morning);
#   "coming"  — today is his day: the hall shows him once the day phase begins;
#   "waiting" — he is in the hall (or was, and the day hasn't ended);
#   "ended"   — the player heard him: the demo is over. Memory only: a save writes it as "waiting", so Continue replays
#               the final day and he comes again.
# `returning` (true from his second morning on) picks the hall's "he's back" banner.
# No class_name: GameManager and the hall preload it by path; no autoload names in here.
extends RefCounted

## The states a save may hold ("ended" is saved as "waiting").
const SAVED_STATES := ["due", "coming", "waiting"]
const DEFAULT_MIN_REPUTATION := 32
const DEFAULT_MIN_TAXES := 2


## The demo_ending config (game_config.json, the run's profile resolved) as {active, min_reputation, min_taxes_paid,
## warnings}. active = the profile is the demo AND enabled is true (the full game never runs it, whatever the file says).
## No block (or not an object): inactive, silently. A bad number (not a whole number; min_reputation < 0, min_taxes_paid
## < 1): its default, with a "[GameManager] fallback: demo_ending ..." text in `warnings`.
static func config_from(raw, is_demo: bool) -> Dictionary:
	var out := {"active": false, "min_reputation": DEFAULT_MIN_REPUTATION, "min_taxes_paid": DEFAULT_MIN_TAXES, "warnings": []}
	if not (raw is Dictionary):
		return out
	for k in [["min_reputation", 0], ["min_taxes_paid", 1]]:
		if not raw.has(k[0]):
			continue
		var n = whole(raw[k[0]])
		if n == null or int(n) < int(k[1]):
			out.warnings.append("[GameManager] fallback: demo_ending.%s %s is not a whole number >= %d; using %d" % [k[0], raw[k[0]], k[1], out[k[0]]])
		else:
			out[k[0]] = int(n)
	out.active = is_demo and raw.get("enabled") == true
	return out


## The trigger: with no state yet, an active config and both conditions met on `day`, the ending is due on day + 1;
## anything else (inactive, a condition short, a state already set) returns `state` unchanged (the same instance).
static func queue_if_met(state: Dictionary, reputation: int, taxes_paid: int, day: int, cfg: Dictionary) -> Dictionary:
	if not bool(cfg.get("active", false)) or not state.is_empty():
		return state
	if reputation >= int(cfg.get("min_reputation", DEFAULT_MIN_REPUTATION)) and taxes_paid >= int(cfg.get("min_taxes_paid", DEFAULT_MIN_TAXES)):
		return {"state": "due", "day": day + 1, "returning": false}
	return state


## The morning step (advance_day): "due" on or after its day -> "coming" today; "coming" or "waiting" from an earlier day
## (he wasn't heard) -> "coming" today. `returning` (the "he's back" banner) only once he has been in the hall
## ("waiting"); a "coming" day on which he never walked in carries its flag over (review P7). Anything else (none, "due"
## before its day, today's "coming" or "waiting", "ended"): unchanged.
static func morning(state: Dictionary, day: int) -> Dictionary:
	var s := str(state.get("state", ""))
	if s == "due" and day >= int(state.get("day", 0)):
		return {"state": "coming", "day": day, "returning": false}
	if (s == "coming" or s == "waiting") and day > int(state.get("day", 0)):
		return {"state": "coming", "day": day, "returning": s == "waiting" or state.get("returning") == true}
	return state


## What a save holds: "ended" as "waiting" (Continue replays the final day); anything else as it is (a copy).
static func for_save(state: Dictionary) -> Dictionary:
	var out := state.duplicate()
	if str(state.get("state", "")) == "ended":
		out.state = "waiting"
	return out


## A saved state, read defensively: {"state": <the state or {}>, "warning": ""}. None (an older save, {}) -> {} silently;
## not a Dictionary, an unknown state or no whole day >= 1 -> {} with a "[GameManager] load: ..." warning text.
static func from_save(v) -> Dictionary:
	if v == null or (v is Dictionary and (v as Dictionary).is_empty()):
		return {"state": {}, "warning": ""}
	var d = whole(v.get("day")) if v is Dictionary else null
	if not (v is Dictionary) or not (str(v.get("state", "")) in SAVED_STATES) or d == null or int(d) < 1:
		return {"state": {}, "warning": "[GameManager] load: demo_ending %s is not a known state; none" % [v]}
	return {"state": {"state": str(v.state), "day": int(d), "returning": v.get("returning") == true}, "warning": ""}


## An int, or a float with no fraction (JSON reads every number as a float), as an int; anything else: null.
static func whole(v):
	if v is int:
		return v
	if v is float and is_finite(v) and v == floorf(v):
		return int(v)
	return null
