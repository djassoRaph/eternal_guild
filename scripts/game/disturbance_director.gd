# disturbance_director.gd — the hall's side of the tavern disturbances (Story 14.4). GameManager rolls today's event in the
# morning (advance_day) and keeps it (pending_disturbance, saved); this node, added by main_tavern.gd, shows it: in the
# hall's day phase (TavernLighting's phase, then GameBus.day_phase_changed), with no Game Over and no conversation open,
# the visitor (disturbance_npc.gd) appears at his type's spot with the type's banner, and the event is "fired". E on him
# opens his title of data/dialogue/disturbances.dialogue with a bridge kept here; when the box closes, the bridge's
# choice (bridge.choose(id) in the file) goes to GameManager.resolve_disturbance(), the outcome's line is a banner and he
# walks out. No choice (Esc, "Walk away"): he stays. Sleep (late_night) sends him off unresolved: the next morning
# applies the type's "ignored" outcome. A load during the day brings a fired event's visitor back (no banner again).
# No class_name: loaded by path.
extends Node

const NPC_SCRIPT := "res://scripts/npcs/disturbance_npc.gd"
const Runner := preload("res://scripts/dialogue/dialogue_runner.gd")
const DIALOGUE := "res://data/dialogue/disturbances.dialogue"
const CHECK_SECONDS := 1.0
const DEFAULT_EXIT := Vector3(8.7, 0.0, 3.3)   # PatronSpawner.entrance_position, when the hall has no spawner

## Where the visitor is added (the patrons' parent, TavernNavigation); found in the scene unless set first (tests).
var world_parent: Node3D = null
## The hall's phase: TavernLighting's at start ("day" without one), then GameBus.day_phase_changed's.
var phase := ""
var exit_point := DEFAULT_EXIT
var leave_timeout := 12.0
var npc: Node = null
var _bridge: RefCounted = null
var _box: Node = null
var _check_left := 0.0


func _ready() -> void:
	add_to_group("disturbance_director")
	var scene := get_tree().current_scene
	if world_parent == null and scene:
		var spawner := scene.find_child("PatronSpawner", true, false)
		if spawner and spawner.get_parent() is Node3D:
			world_parent = spawner.get_parent()
			var e = spawner.get("entrance_position")
			if e is Vector3:
				exit_point = e
	if phase == "" and scene:
		var lighting := scene.find_child("TavernLighting", true, false)
		phase = str(lighting.get("phase")) if lighting and lighting.get("phase") != null else "day"
	if phase == "":
		phase = "day"
	GameBus.day_phase_changed.connect(_on_day_phase)
	check()


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_SECONDS
		check()


## Whether today's event shows now (pure): today's, queued or already fired (a load), in the day phase, the run not
## fallen, no conversation open.
static func should_fire(ev: Dictionary, day: int, phase_now: String, game_over: bool, box_open: bool) -> bool:
	return not ev.is_empty() and int(ev.get("day", -1)) == day and str(ev.get("state", "")) in ["queued", "fired"] \
		and phase_now == "day" and not game_over and not box_open


## Show today's event if it is due and nobody is standing in for it yet.
func check() -> void:
	if npc != null and is_instance_valid(npc):
		return
	npc = null
	if world_parent == null or not is_instance_valid(world_parent):
		return
	var ev: Dictionary = GameManager.pending_disturbance
	if not should_fire(ev, GameManager.current_day, phase, GameManager.game_over_active, Runner.is_open()):
		return
	var data: Dictionary = GameManager.disturbance_types().get(str(ev.get("type", "")), {})
	var spot = data.get("spot")
	if not (spot is Array and spot.size() == 3):
		push_warning("[Disturbance] refuse: no spot for %s" % ev.get("type", "?"))
		return
	var first: bool = ev.get("state") == "queued"
	var n = load(NPC_SCRIPT).new()
	n.name = "Disturbance_%s" % ev.get("type", "visitor")
	n.leave_timeout = leave_timeout
	n.setup(str(data.get("body", "traveller")), str(data.get("prompt", "Press E - Talk")), exit_point)
	world_parent.add_child(n)
	n.global_position = Vector3(float(spot[0]), 0.0, float(spot[1]))
	n.rotation.y = deg_to_rad(float(spot[2]))
	n.talk_requested.connect(_on_talk_requested)
	npc = n
	GameManager.mark_disturbance_fired()
	print("[Disturbance] fire: %s (%s) at (%.2f, %.2f)%s" % [ev.get("type"), ev.get("truth"), float(spot[0]), float(spot[1]), "" if first else ", back after a load"])
	if first and str(data.get("banner", "")) != "":
		NotificationManager.show_banner(str(data.banner))


func _on_day_phase(p: String) -> void:
	phase = "late_night" if p == "reveal" else p
	if phase == "late_night" and npc != null and is_instance_valid(npc):
		npc.queue_free()   # sleep: he goes, unresolved; the morning applies "ignored"
		npc = null
	check()


func _on_talk_requested(who: Node) -> void:
	if _box != null and is_instance_valid(_box):
		return
	var ev: Dictionary = GameManager.pending_disturbance
	var data: Dictionary = GameManager.disturbance_types().get(str(ev.get("type", "")), {})
	var titles = data.get("titles", {})
	var title := str(titles.get(str(ev.get("truth", "")), "")) if titles is Dictionary else ""
	if title == "":
		push_warning("[Disturbance] refuse: no title for %s (%s)" % [ev.get("type", "?"), ev.get("truth", "?")])
		return
	_bridge = Runner.new_bridge()
	_box = Runner.start(who, DIALOGUE, title, _bridge)
	if _box:
		_box.closed.connect(_on_conversation_closed)


func _on_conversation_closed() -> void:
	_box = null
	var choice := str(_bridge.choice) if _bridge != null else ""
	_bridge = null
	if npc != null and is_instance_valid(npc):
		npc.conversation_over()
	if choice == "":
		return   # walked away: he stays, talk again later
	var out: Dictionary = GameManager.resolve_disturbance(choice)
	if out.is_empty():
		return   # an unknown choice: GameManager warned; he stays
	if str(out.get("line", "")) != "":
		NotificationManager.show_banner(str(out.line))
	if npc != null and is_instance_valid(npc):
		npc.leave()
	npc = null
