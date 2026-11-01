# bartender_ai.gd — the Bartender's brain (Story 16.3): IDLE -> SERVING -> RESTOCKING -> IDLE on staff_ai.gd's LimboAI machine,
# driving 25.13's visual API (serve_toward, restock, enter_idle, set_autopilot, drink_handed).
#   IDLE: 25.13's cosmetic autopilot (wiping, moving between the stations). While he works (hired, not on strike,
#     GameManager.is_staff_working), the beer out -> RESTOCKING; a patron on one of the round bar's stools who has waited
#     bartender_react_seconds (staff_automation in game_config.json) -> SERVING, the longest-waiting first. Table patrons
#     are the player's: he serves from inside the ring and never leaves it (SB-3).
#   SERVING: the autopilot off; serve_toward(the patron): the pour at the taps, the serve at the station facing their
#     stool. At the release (drink_handed) the patron's own serve_patron() takes the pint (consume_beer_pints ->
#     consume_drink("beer"): the player's path, SB-4); the patron then drinks and pays as for the player. Served by
#     someone else, gone, a strike: he stops (enter_idle). Fired: nothing more (he walks out on his own).
#   RESTOCKING: restock(true) at the kegs while the beer is out; with beer again he retries the patron he was serving if
#     they still wait, else back to IDLE. He never hands anything over without beer (SB-5).
# No orders while the game is paused or over. Wait times are summed from the tick's delta, never the wall clock.
extends "res://scripts/game/staff_ai.gd"

const DEFAULT_REACT := 3.0

var react_seconds := DEFAULT_REACT
var target: Node3D = null          # the patron being served (or retried after a restock)
var _waits := {}                   # instance id -> seconds a stool patron has waited
var _handed := false               # the release happened: SERVING ends with his serve


func _build() -> void:
	add_state("IDLE", _idle_enter, _idle_update)
	add_state("SERVING", _serving_enter, _serving_update)
	add_state("RESTOCKING", _restock_enter, _restock_update)
	add_transition("IDLE", "SERVING", "order")
	add_transition("SERVING", "IDLE", "done")
	add_transition("SERVING", "IDLE", "cancel")
	add_transition("SERVING", "RESTOCKING", "dry")
	add_transition("IDLE", "RESTOCKING", "dry")
	add_transition("RESTOCKING", "SERVING", "stocked")
	add_transition("RESTOCKING", "IDLE", "done")
	add_transition_from_any("IDLE", "reset")


func _after_setup() -> void:
	react_seconds = react_seconds_from(_config())
	npc.drink_handed.connect(_on_drink_handed)
	npc.arrived_at_station.connect(_on_arrived)


func _config():
	return DataManager.get_config("staff_automation", {})


## staff_automation.bartender_react_seconds (pure): a number >= 0, else DEFAULT_REACT with a warning.
static func react_seconds_from(cfg) -> float:
	var v = cfg.get("bartender_react_seconds") if cfg is Dictionary else null
	if (v is int or v is float) and is_finite(float(v)) and float(v) >= 0.0:
		return float(v)
	push_warning("[Staff] fallback: staff_automation.bartender_react_seconds is %s: %.1f s" % [v, DEFAULT_REACT])
	return DEFAULT_REACT


func _gm() -> Node:
	return GameManager   # the autoload by name (NFR-9, review P11)

func _working() -> bool:
	var gm := _gm()
	return gm != null and gm.is_staff_working("bartender")

func _beer() -> int:
	var gm := _gm()
	return int(gm.get_beer_pints()) if gm else 0

## He may take an order: working, free to be driven (present, not arriving or leaving), the game running.
func _can_order() -> bool:
	var gm := _gm()
	return _working() and npc.can_drive() and not npc.get_tree().paused and not (gm and gm.get("game_over_active"))

static func _waiting(p) -> bool:
	return is_instance_valid(p) and p.has_method("is_waiting_for_service") and p.is_waiting_for_service()


# ------------------------------------------------------------------ every update

func _before_update(delta: float) -> void:
	var seen := {}
	for p in npc.get_tree().get_nodes_in_group("patrons"):
		if not (p is Node3D) or not p.has_method("serve_patron") or not _waiting(p):
			continue
		if npc.station_for_patron((p as Node3D).global_position) < 0:
			continue                                   # a table seat: the player's
		var id: int = p.get_instance_id()
		seen[id] = true
		_waits[id] = float(_waits.get(id, 0.0)) + delta
	for id in _waits.keys():
		if not seen.has(id):
			_waits.erase(id)


## The stool patron who has waited longest, if that is at least react_seconds.
func _pick() -> Node3D:
	var best: Node3D = null
	var best_t := -1.0
	for id in _waits:
		var t: float = _waits[id]
		var o = instance_from_id(id)
		if t >= react_seconds and t > best_t and o is Node3D and _waiting(o):
			best = o
			best_t = t
	return best


# ------------------------------------------------------------------ IDLE

func _idle_enter() -> void:
	target = null
	_handed = false
	npc.set_autopilot(true)

func _idle_update(_delta: float) -> void:
	if not _working() or not npc.can_drive():
		return
	if _beer() <= 0:
		request("dry")
		return
	if not _can_order():
		return
	var p := _pick()
	if p:
		target = p
		request("order")


# ------------------------------------------------------------------ SERVING

func _serving_enter() -> void:
	_handed = false
	npc.set_autopilot(false)
	if _beer() <= 0:
		request("dry")
		return
	if not _waiting(target) or not npc.serve_toward(target.global_position):
		request("cancel")

func _serving_update(_delta: float) -> void:
	if not npc.can_drive():
		request("cancel")                  # fired (on his way out) or not there: nothing more to do
		return
	if _handed:
		if npc.work_state() == "IDLE":     # the serve's tail is over
			request("done")
		return
	if not _working() or not _waiting(target):
		npc.enter_idle()                   # a strike, or the patron served by someone else / gone
		request("cancel")

func _on_drink_handed(_at: Vector3) -> void:
	if state() != "SERVING" or _handed:
		return
	if not _waiting(target):
		_handed = true                     # nothing to hand over: his serve ends as it is
		return
	if target.serve_patron():
		_handed = true                     # the pint is theirs; SERVING ends with his serve
	else:
		go("dry")                          # the beer ran out between the pour and the release


# ------------------------------------------------------------------ RESTOCKING

func _restock_enter() -> void:
	npc.set_autopilot(false)
	if not npc.restock(true):
		request("done")

func _restock_update(_delta: float) -> void:
	if not _working() or not npc.can_drive():
		if npc.can_drive():
			npc.restock(false)
		request("done")
		return
	if _beer() <= 0:
		return
	if _waiting(target):
		request("stocked")                 # retry the patron he was serving
	else:
		npc.restock(false)
		request("done")


func _on_arrived() -> void:
	if state() == "IDLE":
		npc.set_autopilot(true)
	else:
		go("reset")
