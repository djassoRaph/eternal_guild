# bard.gd — the hall's side of the travelling Bard (Epic 9, Stories 9.1/9.2). GameManager keeps the visit (bard_visit:
# coming -> waiting -> performing | refused; saved) and rolls it in the morning; this node, added by main_tavern.gd,
# shows it. When today's visit is "coming", the day clock has reached its minute, the hall's phase is one of its open
# hours (day_clock_rules.OPEN_PHASES: day, dusk, evening; TavernLighting's, read live, else the last
# GameBus.day_phase_changed), the run hasn't fallen and nothing holds the hall (a conversation, the briefing, a blocking
# screen, another visitor: a disturbance's or the King's messenger (one visitor at a time, K-20), a card reveal, the
# frozen world), it waits arrival_delay_seconds of that, then the Bard (bard_npc.gd) appears on the porch and walks in
# through the front door to the wait spot; an event banner says he is at the door; the state is "waiting". E opens his
# door title (data/dialogue/bard.dialogue: door_first once a run, then door_N, never the same twice in a row) with a
# bridge kept here; when the box closes: "allow" -> GameManager.allow_bard() and he goes to play (Story 9.2); "refuse"
# -> GameManager.refuse_bard("refused") and he walks out; nothing -> he keeps waiting. Not decided by wait_until (clock
# time, bard_wait_hours), or at late night, he moves on: refuse_bard("timeout"), a leaving line in a bubble, a banner,
# the walk out. A load during his visit places him back (at the wait spot). The night (the visit is no longer today's)
# takes him away. The content is data/narrative/bard.json (DRAFT). No class_name: loaded by path.
extends Node

const NPC_SCRIPT := "res://scripts/npcs/bard_npc.gd"
const DATA_PATH := "res://data/narrative/bard.json"
const Runner := preload("res://scripts/dialogue/dialogue_runner.gd")
const DayClockRules := preload("res://scripts/game/day_clock_rules.gd")
const BardRules := preload("res://scripts/game/bard_rules.gd")
const CHECK_SECONDS := 1.0
const FIRST_FLAG := "bard_first_visit"   # set by door_first (bridge.mark_seen) and when its first line shows
## Every key bard.json may hold, with the value used when the file (or the key) is missing.
const DEFAULTS := {
	"bard": {"body": "merchant", "speaker": "bard", "dialogue": "res://data/dialogue/bard.dialogue",
		"porch": [9.6, -0.33, 6.2], "route_in": [[9.6, 0.0, 3.4]], "wait_spot": [13.5, 2.5, -115.0],
		"perform_spot": [-3.25, 0.5, 90.0], "walk_in_timeout_seconds": 12.0, "perform_clip": "Interact",
		"lute": {"carry": {"bone": "chest", "offset": [0.0, 0.05, -0.22], "rotation_deg": [0.0, 0.0, 35.0]},
			"play": {"bone": "chest", "offset": [0.0, -0.12, 0.24], "rotation_deg": [0.0, 0.0, 60.0]}, "scale": 1.0},
		"indicator": "♪", "music_path": "", "music_volume_db": -10.0},
	"text": {"prompt_door": "Press E - Talk to the Bard", "prompt_play": "Press E - Listen to the Bard",
		"banner_arrival": "A travelling bard is waiting at the door.", "banner_refused": "The Bard moves on.",
		"banner_timeout": "The Bard got tired of waiting and moved on."},
	"leave_lines": ["No one at the door. The road it is."],
}
const POINT_KEYS := ["porch"]
const SPOT_KEYS := ["wait_spot", "perform_spot"]
const POINT_LIST_KEYS := ["route_in"]

## Where his body is added (the patrons' parent, TavernNavigation); found in the scene unless set first (tests).
var world_parent: Node3D = null
## The hall's TavernLighting (its `phase` read live); found unless set first (tests). None: `phase`.
var lighting: Node = null
## The last GameBus.day_phase_changed ("reveal" is late_night); at start the lighting's, or "day" without one.
var phase := ""
## bard.json, merged over DEFAULTS. Tests may set `data_override` (merged the same way) before the node enters.
var data: Dictionary = {}
var data_override: Dictionary = {}
## The day clock's minutes (tests); unset: GameManager.day_clock_minutes.
var minutes_provider: Callable
## The player (tests; for facing him when a conversation opens); unset: PlayerManager's.
var player_provider: Callable
var npc: Node = null
var _bridge: RefCounted = null
var _box: Node = null
var _box_title := ""
var _counting := false      # the arrival delay is running (everything was clear when it started)
var _delay_left := 0.0
var _check_left := 0.0
static var _last_door := -1   # the door opening he used last (never twice in a row; the session's)


func _ready() -> void:
	add_to_group("bard_controller")
	data = merged(load_data(DATA_PATH), data_override)
	var scene := get_tree().current_scene
	if world_parent == null and scene:
		var spawner := scene.find_child("PatronSpawner", true, false)
		if spawner and spawner.get_parent() is Node3D:
			world_parent = spawner.get_parent()
	if lighting == null and scene:
		lighting = scene.find_child("TavernLighting", true, false)
	if phase == "":
		phase = _lighting_phase()
	if phase == "":
		phase = "day"
	GameBus.day_phase_changed.connect(_on_day_phase)
	check()


func _process(delta: float) -> void:
	if _counting and _delay_left > 0.0:
		_delay_left -= delta
		if _delay_left <= 0.0:
			check()
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_SECONDS
		check()


## bard.json, or {} with one warning when it is missing or broken (DEFAULTS stand in).
static func load_data(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("[Bard] fallback: %s is missing; the built-in defaults" % path)
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary):
		push_warning("[Bard] fallback: %s is not a JSON object; the built-in defaults" % path)
		return {}
	return d


## DEFAULTS with `over` on top, one level deep per section (lists and the lute's object replaced whole). A key DEFAULTS
## doesn't know, and "_comment", are dropped; a value is taken only when it fits its default's type (a point 3 numbers; a
## spot [x, z, yaw]; a list of points; a list of strings), else the default stays with one "[Bard] fallback: ..." warning.
static func merged(from_file: Dictionary, over: Dictionary = {}) -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate(true)
	for src in [from_file, over]:
		for k in src:
			if str(k).begins_with("_") or not out.has(k):
				continue
			if out[k] is Dictionary:
				if not (src[k] is Dictionary):
					push_warning("[Bard] fallback: %s is %s, not an object; the defaults" % [k, src[k]])
					continue
				for kk in src[k]:
					if str(kk).begins_with("_") or not (out[k] as Dictionary).has(kk):
						continue
					if fits(str(kk), out[k][kk], src[k][kk]):
						out[k][kk] = src[k][kk]
					else:
						push_warning("[Bard] fallback: %s.%s %s doesn't fit; the default %s" % [k, kk, src[k][kk], out[k][kk]])
			elif fits(str(k), out[k], src[k]):
				out[k] = src[k]
			else:
				push_warning("[Bard] fallback: %s %s doesn't fit; the default %s" % [k, src[k], out[k]])
	return out


## Whether `v` may replace `default` for `key` (pure).
static func fits(key: String, default, v) -> bool:
	if key in POINT_KEYS or key in SPOT_KEYS:
		return is_point(v)
	if key in POINT_LIST_KEYS:
		return v is Array and not (v as Array).is_empty() and (v as Array).all(func(q): return is_point(q))
	if default is Array:
		return v is Array and not (v as Array).is_empty() and (v as Array).all(func(x): return x is String and x != "")
	if default is Dictionary:
		return v is Dictionary
	if default is bool:
		return v is bool
	if default is int or default is float:
		return (v is int or v is float) and is_finite(float(v))
	if default is String:
		return v is String
	return typeof(v) == typeof(default)


static func is_point(v) -> bool:
	return v is Array and (v as Array).size() == 3 and (v as Array).all(func(x): return (x is int or x is float) and is_finite(float(x)))


static func _v3(v) -> Vector3:
	return Vector3(float(v[0]), float(v[1]), float(v[2])) if is_point(v) else Vector3.ZERO


## A spot [x, z, yaw_deg] as a floor point (y 0).
static func spot_point(v) -> Vector3:
	return Vector3(float(v[0]), 0.0, float(v[1])) if is_point(v) else Vector3.ZERO


# ---------------------------------------------------------------- when he comes

## The day clock's minutes now.
func minutes() -> float:
	return float(minutes_provider.call()) if minutes_provider.is_valid() else float(GameManager.day_clock_minutes)


## The hall's phase now: TavernLighting's, read live, else the last GameBus phase.
func phase_now() -> String:
	var p := _lighting_phase()
	return p if p != "" else phase


func _lighting_phase() -> String:
	if lighting == null or not is_instance_valid(lighting):
		return ""
	var p = lighting.get("phase")
	return str(p) if p != null else ""


## What holds the hall, so he doesn't walk in yet ("" when nothing): a conversation, the morning briefing, a blocking
## screen, another visitor (K-20), a pending card reveal, the frozen world.
func blocker() -> String:
	if Runner.is_open():
		return "a conversation"
	for g in ["morning_briefing", "blocks_player", "mission_board"]:
		for n in get_tree().get_nodes_in_group(g):
			if n.get("visible") != false:
				return g
	for g in ["disturbance_npc", "royal_messenger"]:
		for n in get_tree().get_nodes_in_group(g):
			if not n.is_queued_for_deletion():
				return "a visitor"
	if _card_reveal_pending():
		return "a card reveal"
	var scene := get_tree().current_scene
	if scene and scene.has_method("is_world_frozen") and scene.is_world_frozen():
		return "the world is frozen"
	var svc = scene.get_node_or_null("SubViewportContainer") if scene else null
	if svc is Node and (svc as Node).process_mode == Node.PROCESS_MODE_DISABLED:
		return "the world is frozen"
	return ""


func _card_reveal_pending() -> bool:
	var nm = get_tree().root.get_node_or_null("NotificationManager")
	if nm != null and nm.has_method("card_reveal_pending"):
		return bool(nm.card_reveal_pending())
	return not get_tree().get_nodes_in_group("card_reveal").is_empty()


## Show today's Bard when he is due in the hall; time him out at the door; send away one whose visit is over.
func check() -> void:
	var v: Dictionary = GameManager.bard_visit
	var today: bool = GameManager.bard_today()
	var st := str(v.get("state", ""))
	var now := phase_now()
	if npc != null and is_instance_valid(npc):
		if not today:
			print("[Bard] gone: his visit is over (the night)")
			npc.queue_free()
			npc = null
			return
		if st == "waiting" and not _box_open() and (BardRules.wait_over(v, minutes()) or not (now in DayClockRules.OPEN_PHASES)):
			_timeout()
		elif st == "refused" and not npc.leaving:
			npc.leave()
		return
	npc = null
	if world_parent == null or not is_instance_valid(world_parent) or not today or GameManager.game_over_active:
		_counting = false
		return
	if st == "waiting":
		if BardRules.wait_over(v, minutes()) or not (now in DayClockRules.OPEN_PHASES):
			_timeout()   # the player came back after his patience ran out: he has gone (no body, the banner)
		else:
			_spawn(true)   # a load (or the hall re-entered) during his wait: back at the wait spot, no banner
		return
	if not BardRules.may_arrive(v, GameManager.current_day, now, minutes(), DayClockRules.OPEN_PHASES,
			GameManager.game_over_active, blocker() != ""):
		_counting = false   # the delay starts again once nothing is in the way
		return
	if not _counting:
		_counting = true
		_delay_left = float(GameManager.bard_config().arrival_delay_seconds)
	if _delay_left > 0.0:
		return
	_counting = false
	_spawn(false)


func _box_open() -> bool:
	return _box != null and is_instance_valid(_box)


func _spawn(placed: bool) -> void:
	var m: Dictionary = data.bard
	var n = load(NPC_SCRIPT).new()
	n.name = "Bard"
	n.setup(str(m.get("body", "merchant")), str(data.text.get("prompt_door", "Press E - Talk")), _v3(m.get("porch")))
	n.lute_cfg = m.get("lute", {}) if m.get("lute") is Dictionary else {}
	n.wait_spot = spot_point(m.get("wait_spot"))
	n.wait_yaw_deg = float(m.wait_spot[2]) if is_point(m.get("wait_spot")) else 180.0
	var route: Array = []
	for q in m.get("route_in", []):
		route.append(_v3(q))
	n.route = route
	n.approach = false
	n.walk_in_timeout = float(m.get("walk_in_timeout_seconds", 12.0))
	world_parent.add_child(n)
	n.talk_requested.connect(_on_talk_requested)
	npc = n
	if placed:
		n.place_waiting()
		print("[Bard] back at the wait spot (a load)")
		return
	n.global_position = _v3(m.get("porch"))
	n.walk_in()
	GameManager.bard_arrived()
	print("[Bard] walks in (day %d, %s)" % [GameManager.current_day, DayClockRules.format_time(minutes())])
	var banner := str(data.text.get("banner_arrival", ""))
	if banner != "":
		NotificationManager.show_banner(banner, true)   # an event banner: it waits its turn


## His patience ran out (or the night came): turned away by the clock. A leaving line if he is here, the banner, the walk.
func _timeout() -> void:
	if not GameManager.refuse_bard("timeout"):
		return
	var lines: Array = data.get("leave_lines", [])
	if npc != null and is_instance_valid(npc):
		if not lines.is_empty():
			npc.say(str(lines[randi() % lines.size()]))
		npc.leave()
	var banner := str(data.text.get("banner_timeout", ""))
	if banner != "":
		NotificationManager.show_banner(banner, true)


func _on_day_phase(p: String) -> void:
	phase = "late_night" if p == "reveal" else p
	_counting = false
	check()


# ---------------------------------------------------------------- talking

## The door title to play (pure but for the roll): door_first until the flag is set (if the file has it), then one of
## door_1..N (whatever numbers the file has), never `last` again. "" when the file has none. Returns [title, index].
static func door_title(titles: Dictionary, numbered: Array, first_seen: bool, last: int, roll: float) -> Array:
	if not first_seen and titles.has("door_first"):
		return ["door_first", last]
	var i := BardRules.pick_index(numbered.size(), last, roll)
	return ["", last] if i < 0 else [str(numbered[i]), i]


func _on_talk_requested(who: Node) -> void:
	if _box_open():
		return
	var st := str(GameManager.bard_visit.get("state", ""))
	if not GameManager.bard_today() or st != "waiting":
		if who.has_method("conversation_over"):
			who.conversation_over()
		return
	var path := str(data.bard.get("dialogue", ""))
	var res := Runner.load_dialogue(path)
	if res == null:
		return
	_bridge = Runner.new_bridge()
	var titles: Dictionary = res.get("titles") if res.get("titles") is Dictionary else {}
	var pick := door_title(titles, Runner.numbered_titles(res, "door_"), _bridge.seen(FIRST_FLAG), _last_door, randf())
	var title := str(pick[0])
	if title == "":
		push_warning("[Bard] refuse: %s has no door_first or door_N title" % path)
		return
	_box = Runner.open(who, res, title, _bridge)
	if _box == null:
		return
	_last_door = int(pick[1])
	_box_title = title
	_box.closed.connect(_on_conversation_closed)
	if title == "door_first":
		_bridge.mark_seen(FIRST_FLAG)   # seen from here even if the file's own mark_seen line goes missing
	var p = player_provider.call() if player_provider.is_valid() else (PlayerManager.player if is_instance_valid(PlayerManager.player) else null)
	if p is Node3D and who.has_method("face_now"):
		who.face_now((p as Node3D).global_position)


func _on_conversation_closed() -> void:
	_box = null
	var choice := str(_bridge.choice) if _bridge != null else ""
	_bridge = null
	if npc != null and is_instance_valid(npc):
		npc.conversation_over()
	match choice:
		"":
			pass   # Esc or "(Walk away.)": he keeps waiting
		"allow":
			if GameManager.allow_bard():
				_start_performing()
		"refuse":
			if GameManager.refuse_bard("refused"):
				if npc != null and is_instance_valid(npc):
					npc.leave()
				var banner := str(data.text.get("banner_refused", ""))
				if banner != "":
					NotificationManager.show_banner(banner, true)
		_:
			push_warning("[Bard] ignore: an unknown choice '%s' from %s" % [choice, _box_title])


## Story 9.2: he goes to play.
func _start_performing() -> void:
	pass
