# den_fa.gd — Den Fa, the Architect (Story 25.10, catalogue G9). "Over six feet four … In place of a
# face: a mirror mask, featureless."
#
# A regular by the tavern fire: at the demo start he sits on the hearth's bench (the Hearth's SitPoint)
# and stays there (decision J8). Stand beside him and "Press E - Talk to Den Fa" gives a short line in a
# speech bubble: placeholders from data/dialogue/den_fa_lines.json until Story 10.3 swaps the bubble
# for his Dialogue Manager states (talked(state) is the hook). stand(), walk_route(), point_at() and
# return_to_seat() are there for Epic 10's beats (the walk to the bar, the point at the pillar).
# No autoload, not a patron, no physics body (the bench collider must not push him): a hand-placed
# scene with one small script (J7), driven by an AnimationTree state machine built here.
#
# One E never does two things (J6): while seated he claims his TalkZone with the scene's ZonePromptUI,
# which gives E and the prompt to the nearest zone the player stands in (the hearth's fire and the cat
# are a step away) and closes E while a patron waits in range, the tree is paused, it is Game Over or a
# mission screen is open.
extends Node3D

signal talked(state: String)

const PROMPT := "Press E - Talk to Den Fa"
const LINES_PATH := "res://data/dialogue/den_fa_lines.json"
const DEN_FA_HIP_BACK := 0.55     # his root (feet) stands this far in front of the seat marker ...
const SEAT_SIDE := 0.48           # ... and this far to his right (the room side): he stands up clear of the chimney
const SEAT_HEIGHT := 0.45         # the bench top above his feet
const WALK_SPEED := 1.1           # m/s, the Walk clip's stride (about 1.4 m per 1.25 s cycle)
const TURN_SECONDS := 0.6
const COOLDOWN := 3.0
const MASK_SEATED := Vector3(0.145, 1.782, -0.288)   # mask centre from his root (x his left, z forward), Sit
const MASK_STANDING := Vector3(-0.01, 2.39, 0.172)   # ... Idle (measured on the rig in Blender)
const BUBBLE_SEATED := 2.35       # speech-bubble height above his root
const BUBBLE_STANDING := 3.05
const STATES := ["Sit", "SitDown", "StandUp", "Idle", "Walk", "Point"]

@export var seat_path: NodePath
@export var bar_route: PackedVector3Array
@export var pillar_target: NodePath

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _talk: Area3D = $TalkZone

var _tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var _seated := false
var _player: Node3D = null
var _prompt_ui: Node = null
var _prompt_label: Label3D = null
var _prompt_shown := false
var _cooldown := 0.0
var _lines: Array = []
var _last_line := -1
var _route := PackedVector3Array()
var _route_i := 0
var _walking := false
var _turning := false
var _after_walk := Callable()
var _queue: Array[Callable] = []  # walks and points wait here until he stands idle, then run in order


## Where his root stands when he sits on this seat marker (flat; y = the floor under the bench).
static func seat_root(seat: Transform3D) -> Vector3:
	var f := Vector3(seat.basis.z.x, 0.0, seat.basis.z.z)
	if f.length() < 0.001:
		push_warning("[DenFa] seat marker faces straight up or down: using +Z")
		f = Vector3(0, 0, 1)
	f = f.normalized()
	var right := Vector3(-f.z, 0.0, f.x)
	var p := seat.origin + f * DEN_FA_HIP_BACK + right * SEAT_SIDE
	p.y = seat.origin.y - SEAT_HEIGHT
	return p


## A line index for `count` lines that is never `last` again (-1 when there are none).
static func pick_line(count: int, last: int, roll: float) -> int:
	if count <= 0:
		return -1
	if count == 1:
		return 0
	roll = clampf(roll, 0.0, 0.999999)
	if last < 0 or last >= count:
		return int(roll * count)
	var i := int(roll * (count - 1))
	return i + 1 if i >= last else i


func _ready() -> void:
	_talk.body_entered.connect(_on_body_entered)
	_talk.body_exited.connect(_on_body_exited)
	_load_lines()
	_build_tree()
	var seat: Node3D = get_node_or_null(seat_path) as Node3D if not seat_path.is_empty() else null
	if seat:
		sit_at(seat)
	else:
		_playback.start("Idle")
	# The scene adds its ZonePromptUI in its own _ready (the tavern after two frames), so look for a while.
	for i in 30:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		_prompt_ui = preload("res://scripts/game/ZonePromptUI.gd").find(get_tree())
		if _prompt_ui:
			if _seated:
				_claim()
			return
	_prompt_label = Label3D.new()   # no ZonePromptUI in this scene: a small prompt over him instead
	_prompt_label.text = PROMPT
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.no_depth_test = true
	_prompt_label.pixel_size = 0.005
	_prompt_label.font_size = 40
	_prompt_label.outline_size = 10
	_prompt_label.modulate = Color(1, 1, 0)
	_prompt_label.position = Vector3(0, BUBBLE_SEATED + 0.2, 0)   # he is only talkable seated
	_prompt_label.visible = false
	add_child(_prompt_label)


func _build_tree() -> void:
	var sm := AnimationNodeStateMachine.new()
	for s in STATES:
		var node := AnimationNodeAnimation.new()
		node.animation = s
		sm.add_node(s, node)
	_link(sm, "Sit", "StandUp", false, 0.2)
	_link(sm, "StandUp", "Idle", true, 0.15)
	_link(sm, "Idle", "SitDown", false, 0.2)
	_link(sm, "SitDown", "Sit", true, 0.15)
	_link(sm, "Idle", "Walk", false, 0.25)
	_link(sm, "Walk", "Idle", false, 0.25)
	_link(sm, "Idle", "Point", false, 0.3)
	_link(sm, "Point", "Idle", true, 0.3)
	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	_tree.tree_root = sm
	add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_anim)
	_tree.active = true
	_playback = _tree.get("parameters/playback")


static func _link(sm: AnimationNodeStateMachine, a: String, b: String, at_end: bool, xfade: float) -> void:
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = xfade
	if at_end:
		t.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		t.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition(a, b, t)


func _load_lines() -> void:
	_lines = []
	if FileAccess.file_exists(LINES_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(LINES_PATH))
		if data is Dictionary and data.get("early") is Array:
			for l in data.early:
				if str(l).strip_edges() != "":
					_lines.append(str(l))
	if _lines.is_empty():
		push_warning("[DenFa] no early lines in %s: talking to him shows nothing" % LINES_PATH)


# ------------------------------------------------------------------ seat, walk, point

## Sit on this marker. snap: place him seated at once (the demo start); otherwise he turns to face the
## room from where he stands (his root), then sits down.
func sit_at(marker: Node3D, snap := true) -> void:
	var t := marker.global_transform
	var f := Vector3(t.basis.z.x, 0.0, t.basis.z.z)
	var yaw := atan2(f.x, f.z) if f.length() > 0.001 else 0.0
	_queue.clear()
	_walking = false
	global_position = seat_root(t)
	if snap:
		global_rotation = Vector3(0.0, yaw, 0.0)
		_seated = true
		_playback.start("Sit")
		_claim()
		return
	_turn_to(yaw, func():
		_seated = true
		_playback.travel("Sit")
		_claim())


func stand() -> void:
	if not _seated:
		return
	_seated = false
	if _prompt_ui and is_instance_valid(_prompt_ui):
		_prompt_ui.release(_talk)
	_playback.travel("Idle")


## Walk a polyline (world points). Waits until he stands idle (standing up first if seated).
func walk_route(points: PackedVector3Array, on_done := Callable()) -> void:
	if points.is_empty():
		if on_done.is_valid():
			on_done.call()
		return
	if not _ready_to_act():
		stand()
		_queue.append(walk_route.bind(points, on_done))
		return
	_route = points
	_route_i = 0
	_after_walk = on_done
	_walking = true
	_playback.travel("Walk")


## Turn to face a world point, then point at it (Point, then back to Idle).
func point_at(target: Vector3) -> void:
	if not _ready_to_act():
		stand()
		_queue.append(point_at.bind(target))
		return
	var to := target - global_position
	_turn_to(atan2(to.x, to.z), func(): _playback.travel("Point"))


## Point at the Hourglass Pillar (pillar_target, its HumAnchor in MainTavern): Epic 10's beat.
func point_at_pillar() -> bool:
	var target := get_node_or_null(pillar_target) as Node3D if not pillar_target.is_empty() else null
	if target == null:
		push_warning("[DenFa] pillar_target does not resolve: nothing to point at")
		return false
	point_at(target.global_position)
	return true


## Walk back along bar_route from wherever he is (the nearest route point), then sit down.
func return_to_seat() -> void:
	if _seated:
		return
	var seat: Node3D = get_node_or_null(seat_path) as Node3D if not seat_path.is_empty() else null
	if seat == null:
		push_warning("[DenFa] seat_path does not resolve: he can't sit down")
		return
	var back := PackedVector3Array()
	if not bar_route.is_empty():
		var k := 0
		for i in bar_route.size():
			if bar_route[i].distance_to(global_position) < bar_route[k].distance_to(global_position):
				k = i
		for i in range(k, -1, -1):
			back.append(bar_route[i])
	back.append(seat_root(seat.global_transform))
	walk_route(back, func(): sit_at(seat, false))


func _ready_to_act() -> bool:
	return not _seated and not _walking and not _turning and _playback.get_current_node() == "Idle"


func _turn_to(yaw: float, then: Callable) -> void:
	_turning = true
	var from := global_rotation.y
	var goal := from + wrapf(yaw - from, -PI, PI)
	var tw := create_tween()
	tw.tween_method(func(a: float): global_rotation = Vector3(0.0, a, 0.0), from, goal, TURN_SECONDS)
	tw.tween_callback(func():
		_turning = false
		then.call())


func _claim() -> void:
	if _prompt_ui and is_instance_valid(_prompt_ui):
		_prompt_ui.claim(_talk, PROMPT, self)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not _queue.is_empty() and _ready_to_act():
		var job: Callable = _queue.pop_front()
		job.call()
	if _walking:
		_step(delta)
	if _prompt_label:
		var want := can_talk()
		if want != _prompt_shown:
			_prompt_shown = want
			_prompt_label.visible = want


func _step(delta: float) -> void:
	var target := _route[_route_i]
	var to := target - global_position
	to.y = 0.0
	var step := WALK_SPEED * delta
	if to.length() <= step:
		global_position = target
		_route_i += 1
		if _route_i >= _route.size():
			_walking = false
			_playback.travel("Idle")
			if _after_walk.is_valid():
				var done := _after_walk
				_after_walk = Callable()
				_queue.push_front(done)
		return
	var dir := to.normalized()
	global_position += dir * step
	global_position.y = move_toward(global_position.y, target.y, step)
	var yaw := atan2(dir.x, dir.z)
	global_rotation = Vector3(0.0, lerp_angle(global_rotation.y, yaw, minf(1.0, 10.0 * delta)), 0.0)


# ------------------------------------------------------------------ talking (placeholder until Story 10.3)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo() and _cooldown <= 0.0 and can_talk():
		get_viewport().set_input_as_handled()
		talk()


## The player is beside him (seated) and E is his: the prompt UI's owner, and his own live checks agree.
func can_talk() -> bool:
	if not _seated or _player == null or not is_instance_valid(_player) or not is_inside_tree() or get_tree().paused:
		return false
	if _prompt_ui != null and is_instance_valid(_prompt_ui) and not _prompt_ui.owns_e(_talk):
		return false
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.get("game_over_active"):
		return false
	for board in get_tree().get_nodes_in_group("mission_board"):
		if board.get("visible"):
			return false
	for p in get_tree().get_nodes_in_group("patrons"):
		if p.has_method("can_be_served_by") and p.can_be_served_by(_player.global_position):
			return false
	return true


func talk() -> void:
	_cooldown = COOLDOWN
	if _lines.is_empty():
		push_warning("[DenFa] nothing to say: %s has no early lines" % LINES_PATH)
		return
	_last_line = pick_line(_lines.size(), _last_line, randf())
	_say(_lines[_last_line])
	talked.emit("early")


func _say(text: String) -> void:
	for c in get_children():          # one line at a time: a new one replaces the last
		if c is PatronSpeechBubble:
			c.queue_free()
	var bubble := PatronSpeechBubble.new()
	add_child(bubble)
	bubble.position.y = (BUBBLE_SEATED if _seated else BUBBLE_STANDING) - PatronSpeechBubble.HEAD_HEIGHT
	bubble.say(text, 3.5)


func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		_player = body


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player = null
