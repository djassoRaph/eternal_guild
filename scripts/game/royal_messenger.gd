# royal_messenger.gd — the hall's side of the demo's ending (Story 10.7; sprint-change-proposal-2026-10-31.md K-2, K-3).
# GameManager keeps the ending's state (demo_ending: due -> coming -> waiting -> ended; demo profile only) and makes it
# "coming" on its morning; this node, added by main_tavern.gd, shows it. When today's is "coming", the hall's phase is
# "day" (TavernLighting's, read live, else the last GameBus.day_phase_changed), the run hasn't fallen, the world isn't
# frozen (the pause menu, a fall), and nothing else holds the screen (a conversation, the morning briefing, a blocking
# screen, a tavern disturbance's visitor, a pending Tarot card reveal: Story 17.3's NotificationManager.card_reveal_pending()
# or its "card_reveal" group), it waits arrival_delay_seconds of that, then the King's messenger (royal_messenger_npc.gd)
# appears on the porch and walks in through the front door, an event banner says he is asking for the guild master, and
# the state is "waiting". He walks to the player (or waits by the door). E opens his conversation
# (data/dialogue/royal_messenger.dialogue) with a bridge kept here; when the box closes with bridge.choice "heard",
# _play_ending() runs: GameManager.demo_ending_heard() (no automatic save after it), _stop_hall() (the world frozen and the
# tree paused), _play_court_panel() (Story 10.1's seam: a "story_panels" director's play(panel_id), awaited; a no-op while
# none exists) and _open_end_card() (scripts/ui/demo_end_card.gd: "to be continued", then the main menu). Esc before the
# request leaves him waiting. Sleep (late_night) sends him off unheard: the next morning he comes again. A load during his
# day ("waiting") places him at the wait spot. The content is data/narrative/demo_ending.json (DRAFT). This node runs while
# the tree is paused (main_tavern.gd's root is ALWAYS), so the ending's coroutine goes on under the frozen hall. No
# class_name: loaded by path.
extends Node

const NPC_SCRIPT := "res://scripts/npcs/royal_messenger_npc.gd"
const CARD_SCRIPT := "res://scripts/ui/demo_end_card.gd"
const Runner := preload("res://scripts/dialogue/dialogue_runner.gd")
const DATA_PATH := "res://data/narrative/demo_ending.json"
const MAIN_MENU := "res://scenes/MainMenu.tscn"
const CHECK_SECONDS := 1.0
## Every key demo_ending.json may hold, with the value used when the file (or the key) is missing.
const DEFAULTS := {
	"messenger": {"body": "guard", "speaker": "royal_messenger", "dialogue": "res://data/dialogue/royal_messenger.dialogue",
		"title": "deliver", "porch": [9.6, -0.33, 6.2], "route_in": [[9.6, 0.0, 3.4]], "wait_spot": [6.0, 0.75, 180.0],
		"approach": true, "approach_stop_m": 1.3, "repath_seconds": 1.5, "approach_timeout_seconds": 25.0,
		"walk_in_timeout_seconds": 12.0, "arrival_delay_seconds": 10.0},
	"text": {"banner_arrival": "A messenger of the King has come. He's asking for the guild master.",
		"banner_return": "The King's messenger is back. He still has word for the guild master.",
		"prompt": "Press E - Hear the King's messenger"},
	"panel_id": "the_kings_request",
	"end_card": {"title": "To be continued", "lines": ["The King has sent for your guild."], "kickstarter_line": "",
		"button": "Return to the main menu", "min_seconds": 3.0, "fade_seconds": 1.0},
}

## Where his body is added (the patrons' parent, TavernNavigation); found in the scene unless set first (tests).
var world_parent: Node3D = null
## The hall's TavernLighting (its `phase` read live); found unless set first (tests). None: `phase`.
var lighting: Node = null
## The last GameBus.day_phase_changed ("reveal" is late_night); at start the lighting's, or "day" without one.
var phase := ""
## demo_ending.json, merged over DEFAULTS. Tests may set `data_override` (merged the same way) before the node enters.
var data: Dictionary = {}
var data_override: Dictionary = {}
## The player the messenger walks to (tests); unset: PlayerManager's.
var player_provider: Callable
## How the end card leaves for the main menu (tests record it); unset: change_scene_to_file.
var scene_changer: Callable
var npc: Node = null
var ending := false
var end_card: Node = null
var _bridge: RefCounted = null
var _box: Node = null
var _counting := false      # the arrival delay is running (everything was clear when it started)
var _delay_left := 0.0
var _check_left := 0.0


func _ready() -> void:
	add_to_group("demo_ending")
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
	if ending:
		return
	if _counting and _delay_left > 0.0:
		_delay_left -= delta
		if _delay_left <= 0.0:
			check()
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_SECONDS
		check()


## demo_ending.json, or {} with one warning when it is missing or broken (DEFAULTS stand in).
static func load_data(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("[DemoEnding] fallback: %s is missing; the built-in defaults" % path)
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary):
		push_warning("[DemoEnding] fallback: %s is not a JSON object; the built-in defaults" % path)
		return {}
	return d


## DEFAULTS with `over` on top, one level deep per section (a missing key keeps its default; "_comment" dropped).
static func merged(from_file: Dictionary, over: Dictionary = {}) -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate(true)
	for src in [from_file, over]:
		for k in src:
			if str(k).begins_with("_") or not out.has(k):
				continue
			if out[k] is Dictionary and src[k] is Dictionary:
				for kk in src[k]:
					out[k][kk] = src[k][kk]
			elif not (out[k] is Dictionary):
				out[k] = src[k]
	return out


## Whether the messenger may walk in now (pure): today's ending is coming, the day phase, no fall, nothing in the way.
static func may_arrive(state: Dictionary, day: int, phase_now: String, game_over: bool, blocked: bool) -> bool:
	return str(state.get("state", "")) == "coming" and int(state.get("day", -1)) == day and phase_now == "day" \
		and not game_over and not blocked


## The hall's phase now: TavernLighting's, read live, else the last GameBus phase.
func phase_now() -> String:
	var p := _lighting_phase()
	return p if p != "" else phase


func _lighting_phase() -> String:
	if lighting == null or not is_instance_valid(lighting):
		return ""
	var p = lighting.get("phase")
	return str(p) if p != null else ""


## What holds the screen or the hall, so he doesn't walk in yet ("" when nothing): a conversation, the morning briefing,
## a blocking screen (the hire desk, the World Map, the fall), a disturbance's visitor, a pending card reveal (17.3),
## the frozen world (the pause menu).
func blocker() -> String:
	if Runner.is_open():
		return "a conversation"
	for g in ["morning_briefing", "blocks_player", "mission_board"]:
		for n in get_tree().get_nodes_in_group(g):
			if n.get("visible") != false:
				return g
	for n in get_tree().get_nodes_in_group("disturbance_npc"):
		if not n.is_queued_for_deletion():
			return "a visitor"
	if card_reveal_pending(get_tree()):
		return "a card reveal"
	var scene := get_tree().current_scene
	var svc = scene.get_node_or_null("SubViewportContainer") if scene else null
	if svc is Node and (svc as Node).process_mode == Node.PROCESS_MODE_DISABLED:
		return "the world is frozen"
	return ""


## Story 17.3's hook (agreed with its story): NotificationManager.card_reveal_pending() when it exists, else a node in group
## "card_reveal".
static func card_reveal_pending(tree: SceneTree) -> bool:
	var nm = tree.root.get_node_or_null("NotificationManager")
	if nm != null and nm.has_method("card_reveal_pending"):
		return bool(nm.card_reveal_pending())
	return not tree.get_nodes_in_group("card_reveal").is_empty()


## Show today's messenger when he is due in the hall; send off one whose day is over.
func check() -> void:
	if ending:
		return
	var st: Dictionary = GameManager.demo_ending
	var today: bool = GameManager.demo_ending_today()
	if npc != null and is_instance_valid(npc):
		if not today or not GameManager.demo_ending_config().active:
			print("[DemoEnding] send away: the messenger's day is over (%s)" % [st])
			npc.queue_free()
			npc = null
		return
	npc = null
	if world_parent == null or not is_instance_valid(world_parent) or not GameManager.demo_ending_config().active:
		return
	if str(st.get("state", "")) == "waiting" and today:
		if phase_now() != "late_night" and not GameManager.game_over_active:
			_spawn(true)   # a load (or the hall re-entered) during his day: back at the wait spot, no banner
		return
	var blocked := blocker()
	if not may_arrive(st, GameManager.current_day, phase_now(), GameManager.game_over_active, blocked != ""):
		_counting = false   # the delay starts again once nothing is in the way
		return
	if not _counting:
		_counting = true
		_delay_left = float(data.messenger.get("arrival_delay_seconds", 10.0))
	if _delay_left > 0.0:
		return
	_counting = false
	_spawn(false)


func _spawn(placed: bool) -> void:
	var m: Dictionary = data.messenger
	var n = load(NPC_SCRIPT).new()
	n.name = "RoyalMessenger"
	n.setup(str(m.get("body", "guard")), str(data.text.get("prompt", "Press E - Talk")), _v3(m.get("porch")))
	var ws = m.get("wait_spot")
	n.wait_spot = Vector3(float(ws[0]), 0.0, float(ws[1])) if ws is Array and ws.size() == 3 else Vector3.ZERO
	n.wait_yaw_deg = float(ws[2]) if ws is Array and ws.size() == 3 else 180.0
	var route: Array = []
	for q in m.get("route_in", []):
		route.append(_v3(q))
	n.route = route
	n.approach = m.get("approach", true) == true
	n.stop_distance = float(m.get("approach_stop_m", 1.3))
	n.repath_seconds = float(m.get("repath_seconds", 1.5))
	n.approach_timeout = float(m.get("approach_timeout_seconds", 25.0))
	n.walk_in_timeout = float(m.get("walk_in_timeout_seconds", 12.0))
	if player_provider.is_valid():
		n.player_provider = player_provider
	world_parent.add_child(n)
	n.talk_requested.connect(_on_talk_requested)
	npc = n
	if placed:
		n.place_waiting()
		print("[DemoEnding] the King's messenger is back at the wait spot (a load)")
		return
	n.global_position = _v3(m.get("porch"))
	n.walk_in()
	var returning: bool = GameManager.demo_ending.get("returning") == true
	GameManager.demo_ending_arrived()
	print("[DemoEnding] the King's messenger walks in (day %d%s)" % [GameManager.current_day, ", again" if returning else ""])
	var banner := str(data.text.get("banner_return" if returning else "banner_arrival", ""))
	if banner != "":
		NotificationManager.show_banner(banner, true)   # an event banner: it waits its turn, no warning pushes it out


static func _v3(v) -> Vector3:
	if v is Array and v.size() == 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ZERO


func _on_day_phase(p: String) -> void:
	phase = "late_night" if p == "reveal" else p
	if phase == "late_night" and npc != null and is_instance_valid(npc) and not ending:
		npc.queue_free()   # sleep: he goes, unheard; the next morning he comes again
		npc = null
	_counting = false
	check()


func _on_talk_requested(who: Node) -> void:
	if ending or (_box != null and is_instance_valid(_box)):
		return
	_bridge = Runner.new_bridge()
	_box = Runner.start(who, str(data.messenger.get("dialogue", "")), str(data.messenger.get("title", "deliver")), _bridge)
	if _box:
		_box.closed.connect(_on_conversation_closed)


func _on_conversation_closed() -> void:
	_box = null
	var choice := str(_bridge.choice) if _bridge != null else ""
	_bridge = null
	if npc != null and is_instance_valid(npc):
		npc.conversation_over()
	if choice == "heard":
		_play_ending()


## The demo's end (KM-7): heard -> the hall stopped -> Story 10.1's court panel (if any) -> the end card. Awaits only
## signals and SceneTree timers that run while paused, so it goes on under the frozen hall.
func _play_ending() -> void:
	if ending:
		return
	if not GameManager.demo_ending_heard():
		return
	ending = true
	_stop_hall()
	await _play_court_panel()
	_open_end_card()


## The hall stops: its world frozen (main_tavern.gd's root runs ALWAYS, so a tree pause alone leaves the player, patrons
## and staff running; 13.4 review P1), then the tree paused. Nothing unfreezes it: the end card leaves the scene.
func _stop_hall() -> void:
	stop_hall(get_tree())


## Freeze the current scene's world (its set_world_frozen when it has one, Story 18.1; else the fall screen's two lines:
## the SubViewportContainer disabled, the mouse off it) and pause the tree. The end card calls it too when opened alone.
static func stop_hall(tree: SceneTree) -> void:
	var scene := tree.current_scene
	if scene and scene.has_method("set_world_frozen"):
		scene.set_world_frozen(true)
	elif scene:
		var svc = scene.get_node_or_null("SubViewportContainer")
		if svc is Control:
			(svc as Control).process_mode = Node.PROCESS_MODE_DISABLED
			(svc as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.paused = true


## Story 10.1's seam (agreed with its story): a "story_panels" director's play(panel_id) -> null, or an object whose
## `finished` is awaited. No director (today), an empty id, or play() returning null: nothing.
func _play_court_panel() -> void:
	var id := str(data.get("panel_id", ""))
	if id == "":
		return
	var d = get_tree().get_first_node_in_group("story_panels")
	if d == null or not d.has_method("play"):
		return
	var p = d.play(id)
	if p != null and p is Object and (p as Object).has_signal("finished"):
		print("[DemoEnding] the court panel '%s' plays before the end card" % id)
		await p.finished


func _open_end_card() -> void:
	var card = load(CARD_SCRIPT).new()
	card.text = data.end_card
	card.scene_changer = scene_changer if scene_changer.is_valid() else Callable()
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	host.add_child(card)
	end_card = card
	print("[DemoEnding] the end card")
