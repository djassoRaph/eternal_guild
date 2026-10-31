# quest_dealer_ai.gd — the Quest Dealer's brain (Story 16.4): IDLE / BRIEFING / AVAILABLE on staff_ai.gd's LimboAI
# machine, driving 25.13's visual API (set_work_state, set_autopilot), plus her morning round (FR-65).
#   While she works (hired, not on strike) and sits at the desk, the brain owns her state (her autopilot off):
#     BRIEFING (Brief) while a screen she briefs over is up (the hire desk, a mission screen, the morning reports; a bark
#       as it opens, 25.13's rule) or while her round runs;
#     AVAILABLE (Sit_Chair_Idle) while the player stands at the desk front;
#     else IDLE (Write).
#   Otherwise (a strike, walking in or out, not seated) her cosmetic autopilot is back and the machine rests in IDLE.
#   The morning round: GameBus.day_changed arms it (and so does setup, on a morning whose round hasn't run:
#     GameManager.desk_round_day). Once she works and sits, no screen is up and the game runs, she waits
#     desk_round_delay_seconds (staff_automation in game_config.json), then briefs, GameManager.desk_round() sends who it
#     sends (dispatch_adventurers), she says so (staff.json round_barks, DRAFT), holds the Brief a moment, and writes.
# The hire panel does not open by itself when the player walks up (SQ-6: the desk keeps its E). Timers use the tick's
# delta, never the wall clock.
extends "res://scripts/game/staff_ai.gd"

const DEFAULT_DELAY := 4.0
const BRIEF_HOLD := 2.0

var round_delay := DEFAULT_DELAY
var last_round: Array = []       # what her last round sent (for tests and the log)
var _armed := false
var _delay_left := 0.0
var _round_left := 0.0           # > 0 while her round's Brief is held
var _last_round_line := -1


func _build() -> void:
	add_state("IDLE", _enter.bind("IDLE"), _update.bind("IDLE"))
	add_state("BRIEFING", _enter.bind("BRIEFING"), _update.bind("BRIEFING"))
	add_state("AVAILABLE", _enter.bind("AVAILABLE"), _update.bind("AVAILABLE"))
	for from in ["IDLE", "BRIEFING", "AVAILABLE"]:
		for to in ["IDLE", "BRIEFING", "AVAILABLE"]:
			if from != to:
				add_transition(from, to, to.to_lower())
	add_transition_from_any("IDLE", "reset")


func _after_setup() -> void:
	round_delay = round_delay_from(_config())
	var gb := npc.get_node_or_null("/root/GameBus")
	if gb:
		gb.day_changed.connect(_on_day_changed)
	var gm := _gm()
	if gm and int(gm.get("desk_round_day")) != int(gm.get("current_day")):
		_arm()


func _config():
	var dm := npc.get_node_or_null("/root/DataManager")
	return dm.get_config("staff_automation", {}) if dm else {}


## staff_automation.desk_round_delay_seconds (pure): a number >= 0, else DEFAULT_DELAY with a warning.
static func round_delay_from(cfg) -> float:
	var v = cfg.get("desk_round_delay_seconds") if cfg is Dictionary else null
	if (v is int or v is float) and is_finite(float(v)) and float(v) >= 0.0:
		return float(v)
	push_warning("[Staff] fallback: staff_automation.desk_round_delay_seconds is %s: %.1f s" % [v, DEFAULT_DELAY])
	return DEFAULT_DELAY


func _gm() -> Node:
	return npc.get_node_or_null("/root/GameManager")

func _on_day_changed(_day: int) -> void:
	_arm()

func _arm() -> void:
	_armed = true
	_delay_left = round_delay

## She works and sits at the desk: the brain drives her.
func _on_duty() -> bool:
	var gm := _gm()
	return gm != null and gm.is_staff_working("desk_manager") and npc.can_drive()

func _game_running() -> bool:
	var gm := _gm()
	return not npc.get_tree().paused and not (gm and gm.get("game_over_active"))


# ------------------------------------------------------------------ every update

func _before_update(delta: float) -> void:
	if not _on_duty():
		_round_left = 0.0
		npc.set_autopilot(true)       # cosmetic while she isn't working or isn't seated
		return
	npc.set_autopilot(false)
	if _round_left > 0.0:
		_round_left = maxf(0.0, _round_left - delta)
		return
	if _armed and _game_running() and not npc.screen_open():
		_delay_left -= delta
		if _delay_left <= 0.0:
			_armed = false
			_run_round()


func _run_round() -> void:
	var gm := _gm()
	if gm == null:
		return
	last_round = gm.desk_round()
	_round_left = BRIEF_HOLD
	if not last_round.is_empty():
		var line := _round_line(last_round[0])
		if line != "":
			npc.say(line)


## A round line from staff.json's round_barks with {name} and {mission} filled (never the same line twice running).
func _round_line(sent: Dictionary) -> String:
	var gm := _gm()
	var role = gm.staff_roles().get("desk_manager", {}) if gm else {}
	var lines: Array = role.get("round_barks", []) if role is Dictionary and role.get("round_barks") is Array else []
	if lines.is_empty():
		return ""
	_last_round_line = npc.pick_line(lines.size(), _last_round_line, randf())
	return str(lines[_last_round_line]).replace("{name}", str(sent.get("name", ""))).replace("{mission}", str(sent.get("mission", "")))


## The state she should be in now.
func _wanted_state() -> String:
	if _round_left > 0.0 or npc.screen_open():
		return "BRIEFING"
	if npc.player_at_desk():
		return "AVAILABLE"
	return "IDLE"


# ------------------------------------------------------------------ the states

func _enter(state_name: String) -> void:
	if not _on_duty():
		return
	npc.set_work_state(state_name)
	if state_name == "BRIEFING" and _round_left <= 0.0:
		npc.brief_bark()              # a screen opened (her round says its own line)

func _update(_delta: float, state_name: String) -> void:
	if not _on_duty():
		if state_name != "IDLE":
			request("reset")
		return
	var want := _wanted_state()
	if want != state_name:
		request(want.to_lower())
		return
	if npc.work_state() != state_name or (npc.anim_state() != npc.pose_for(state_name) and not npc.is_busy()):
		npc.set_work_state(state_name)   # a pose asked for while she was busy (sliding, sitting) lands now
