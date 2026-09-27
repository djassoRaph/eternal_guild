# staff_npc.gd — what the Bartender and the Quest Dealer share (Story 25.13, catalogue G12/G13).
#
# The hire seam: in the demo profile they are at their stations from the first morning; in the full game
# they are hidden until GuildBus.staff_hired names their role, then walk in from the porch through the front
# door, and on staff_fired walk out the same way (Story 16.1's contract; GameManager.is_staff_hired decides
# at load). The model is loaded from data/characters/staff.json by role and variant, with a KayKit body as
# the fallback (MOD-3/MOD-6). Everything that moves happens in tick(delta) — the walk, the turns, the
# timers, the door hold, the AnimationTree (callback mode MANUAL) — so tests can step it by hand
# (manual_tick). Visuals only: no GameManager writes, no E, no physics body, no autoload.
# bartender.gd and quest_dealer.gd extend this script by path (no class_name).
extends Node3D

signal arrived_at_station
signal left_tavern

const STAFF_DATA := "res://data/characters/staff.json"
const HALL_SPEED := 0.82        # Walking_A's stride, m/s (measured in Blender, Story 25.13 T0)
const BAR_SPEED := 0.48         # Walk_Bar: 45% of that stride, the shuffle for tight spots
const TURN_RATE := 4.5          # rad/s for turns in place
const DOOR_REACH := 2.5         # hold the front door from this far before it until this far past it
const CLIP_FALLBACK := {"Walk_Bar": "Walking_A", "Wipe": "Interact", "Serve": "Interact", "Pour": "PickUp",
	"Restock": "Use_Item", "Write": "Sit_Chair_Idle", "Brief": "Sit_Chair_Idle"}
const LOOPING := ["Idle", "Walking_A", "Walk_Bar", "Sit_Chair_Idle", "Wipe", "Restock", "Write", "Brief"]

@export var role := ""
## Empty: the role's default_variant in staff.json (Epic 16's candidates each name one).
@export var variant := ""
## -1 asks GameManager.is_staff_hired (the demo starts them hired); 0 / 1 force it (tests, LookDev).
@export var hired_at_start_override := -1
## The porch first, the station's approach last (tavern world coordinates).
@export var arrive_route := PackedVector3Array()
@export var door_path: NodePath
## Tests step tick() by hand; the game ticks from _process.
@export var manual_tick := false

var model: Node3D
var anim: AnimationPlayer
var tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var present := false
## The role's name from staff.json (display_name), for the UIs of Epic 10 and Epic 16 (read, never shown here).
var display_name := ""
var autopilot := true
var using_fallback := false

var _barks: Array = []
var _last_bark := -1
var _path := PackedVector3Array()
var _path_i := 0
var _path_state := "Walk"
var _path_speed := HALL_SPEED
var _path_done := Callable()
var _turn_goal := NAN
var _turn_done := Callable()
var _wait := 0.0
var _wait_done := Callable()
var _door: Node = null
var _holding_door := false
var _leaving := false
var _route_phase := ""          # "in" / "out" while walking arrive_route, "station" from its end to the station, "" there
var _state_len := {}            # state name -> its clip length (s)
var _wanted := ""               # the state last asked for (the tree's current node lags a pending travel by a frame)


# ------------------------------------------------------------------ the parts a role fills in

## State name -> clip name (subclasses).
func _states() -> Dictionary:
	return {"Idle": "Idle", "Walk": "Walking_A", "WalkBar": "Walk_Bar"}

## Where he or she stands to work, at once (the demo's first frame, or a load while hired).
func place_at_station() -> void:
	pass

## From the end of arrive_route to the station; call `then` when there.
func _take_station(then: Callable) -> void:
	then.call()

## From the station back to the end of arrive_route; call `then` when there.
func _leave_station(then: Callable) -> void:
	then.call()

## Which walk (state) a spot needs: the shuffle where it is tight.
func _walk_state_at(_p: Vector3) -> String:
	return "Walk"

## The role's own per-tick work (autopilot, timers).
func _tick_work(_delta: float) -> void:
	pass

## Height of the bubble above the root (standing vs seated).
func _bubble_height() -> float:
	return PatronSpeechBubble.HEAD_HEIGHT

## The prop nodes the role's own body carries by name (subclasses): a missing one is warned about at load.
func _prop_nodes() -> Array:
	return []


# ------------------------------------------------------------------ setup

func _ready() -> void:
	_load_data()
	_load_model()
	_build_tree()
	var bus := get_node_or_null("/root/GuildBus")
	if bus:
		bus.staff_hired.connect(_on_staff_hired)
		bus.staff_fired.connect(_on_staff_fired)
	_door = get_node_or_null(door_path) if not door_path.is_empty() else null
	if hired_at_start():
		present = true
		visible = true
		place_at_station()
	else:
		present = false
		visible = false


func hired_at_start() -> bool:
	if hired_at_start_override >= 0:
		return hired_at_start_override == 1
	var gm := get_node_or_null("/root/GameManager")
	return gm != null and gm.has_method("is_staff_hired") and gm.is_staff_hired(role)


## The cosmetic autopilot on or off. Stories 16.3 and 16.4 turn it off before they drive the API.
func set_autopilot(on: bool) -> void:
	autopilot = on


func _load_data() -> void:
	var data = null
	if FileAccess.file_exists(STAFF_DATA):
		data = JSON.parse_string(FileAccess.get_file_as_string(STAFF_DATA))
	var r = data.get("roles", {}).get(role) if data is Dictionary and data.get("roles") is Dictionary else null
	if not r is Dictionary:
		push_warning("[Staff] missing: no role '%s' in %s" % [role, STAFF_DATA])
		return
	display_name = str(r.get("display_name", role))
	for l in r.get("barks", []):
		if str(l).strip_edges() != "":
			_barks.append(str(l))


func _variant_spec() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(STAFF_DATA)) if FileAccess.file_exists(STAFF_DATA) else null
	var r = data.get("roles", {}).get(role, {}) if data is Dictionary and data.get("roles") is Dictionary else {}
	var variants: Dictionary = r.get("variants", {}) if r is Dictionary and r.get("variants") is Dictionary else {}
	var want := variant if variant != "" else str(r.get("default_variant", "")) if r is Dictionary else ""
	if not variants.has(want):
		if variant != "":
			push_warning("[Staff] fallback: unknown variant '%s' for %s, using the default" % [variant, role])
		want = str(r.get("default_variant", "")) if r is Dictionary else ""
	return variants.get(want, {}) if variants.get(want) is Dictionary else {}


func _load_model() -> void:
	var spec := _variant_spec()
	var path := str(spec.get("model_path", ""))
	var scene: PackedScene = null
	if path != "" and ResourceLoader.exists(path):
		scene = load(path) as PackedScene
	if scene == null:
		var fb := str(spec.get("fallback_model_path", ""))
		push_warning("[Staff] fallback: %s's model '%s' is missing, using '%s'" % [role, path, fb])
		if fb != "" and ResourceLoader.exists(fb):
			scene = load(fb) as PackedScene
			using_fallback = true
			path = fb
	if scene == null:
		push_warning("[Staff] missing: no body for %s" % role)
		return
	var inst := scene.instantiate()
	model = inst as Node3D
	if model == null:
		if inst:
			inst.free()
		push_warning("[Staff] missing: %s's body '%s' has no Node3D root" % [role, path])
		return
	model.name = "Model"
	add_child(model)
	var aps := model.find_children("*", "AnimationPlayer", true, false)
	anim = aps[0] if not aps.is_empty() else null
	if using_fallback:
		_hide_hand_items()
	else:
		for p in _prop_nodes():
			if model.find_child(str(p), true, false) == null:
				push_warning("[Staff] missing: prop %s on %s's body '%s'" % [p, role, path])


func _hide_hand_items() -> void:
	"""On a KayKit fallback body, hide the weapons and items hanging from the hand slots."""
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk := sks[0] as Skeleton3D
	for a in model.find_children("*", "BoneAttachment3D", true, false):
		var b := sk.find_bone((a as BoneAttachment3D).bone_name)
		if b >= 0 and sk.get_bone_name(sk.get_bone_parent(b)).begins_with("handslot"):
			(a as Node3D).visible = false


func _build_tree() -> void:
	if anim == null:
		return
	var sm := AnimationNodeStateMachine.new()
	var states := _states()
	var available := anim.get_animation_list()
	for s in states:
		var original: String = states[s]
		var clip := resolve_clip(available, original)
		if clip == "":
			push_warning("[Staff] missing: %s has neither %s nor a fallback clip" % [role, original])
		elif clip != original:
			push_warning("[Staff] fallback: %s has no clip %s, playing %s" % [role, original, clip])
		var node := AnimationNodeAnimation.new()
		node.animation = clip
		if "use_custom_timeline" in node:
			# the tree owns the loop modes for any body (a swapped GLB imports its clips unlooped): the shared
			# Animation resources are never written (the patrons rewrite KayKit's loop_mode)
			node.use_custom_timeline = true
			node.timeline_length = anim.get_animation(clip).length if anim.has_animation(clip) else 1.0
			node.stretch_time_scale = false
			node.loop_mode = Animation.LOOP_LINEAR if LOOPING.has(original) else Animation.LOOP_NONE
		sm.add_node(s, node)
		_state_len[s] = anim.get_animation(clip).length if anim.has_animation(clip) else 1.0
	for a in states:
		for b in states:
			if a != b:
				var t := AnimationNodeStateMachineTransition.new()
				t.xfade_time = 0.2
				sm.add_transition(a, b, t)
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	tree.tree_root = sm
	model.add_child(tree)                              # its root_node ".." is the model, as the clips expect
	tree.anim_player = tree.get_path_to(anim)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true
	playback = tree.get("parameters/playback")


## The clip a state plays on a body with `available` clips: its own, else CLIP_FALLBACK's, else Idle ("" if none).
static func resolve_clip(available: PackedStringArray, clip: String) -> String:
	if available.has(clip):
		return clip
	if CLIP_FALLBACK.has(clip) and available.has(str(CLIP_FALLBACK[clip])):
		return str(CLIP_FALLBACK[clip])
	return "Idle" if available.has("Idle") else ""


# ------------------------------------------------------------------ states and time

func play(state: String) -> void:
	if playback == null:
		return
	var cur := playback.get_current_node()
	if cur == "":
		playback.start(state)
	elif cur == state and _wanted != state:
		playback.start(state, false)   # a travel elsewhere is pending: travel() back to the current node would not cancel it
	elif cur != state and playback.get_fading_from_node() != "":
		playback.start(cur, false)     # mid-crossfade a travel waits for the fade to end (a walk would play the old clip
		playback.travel(state)         # for up to 0.2 s): end the fade on the current node, then travel from it at once
	else:
		playback.travel(state)
	_wanted = state


func anim_state() -> String:
	return playback.get_current_node() if playback else ""


func state_length(state: String) -> float:
	return float(_state_len.get(state, 1.0))


func is_walking() -> bool:
	return _path_i < _path.size()


func is_turning() -> bool:
	return not is_nan(_turn_goal)


func is_busy() -> bool:
	return is_walking() or is_turning() or _wait > 0.0


func _process(delta: float) -> void:
	if not manual_tick:
		tick(delta)


func tick(delta: float) -> void:
	if delta <= 0.0 or not present:
		return
	if is_walking():
		_step_path(delta)
	elif is_turning():
		_step_turn(delta)
	elif _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_wait = 0.0
			var done := _wait_done
			_wait_done = Callable()
			if done.is_valid():
				done.call()
	if not present:                  # the walk-out ended this tick (_gone): no work, no new hold on the door
		return
	_tick_work(delta)
	_update_door()
	if tree:
		tree.advance(delta)


# ------------------------------------------------------------------ moving

## Walk a polyline (world points); the state follows the spot (the hall walk or the shuffle).
func walk(points: PackedVector3Array, then := Callable()) -> void:
	_path = points
	_path_i = 0
	_path_done = then
	if points.is_empty():
		_finish_path()
		return
	_set_walk_state(global_position)


func _set_walk_state(p: Vector3) -> void:
	var st := _walk_state_at(p)
	_path_speed = BAR_SPEED if st == "WalkBar" else HALL_SPEED
	if _wanted != st:
		play(st)
	_path_state = st


func _step_path(delta: float) -> void:
	var left := _path_speed * delta
	while left > 0.0 and _path_i < _path.size():
		var target := _path[_path_i]
		var to := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
		var d := to.length()
		if d <= left:
			global_position = Vector3(target.x, target.y, target.z)
			left -= d
			_path_i += 1
		else:
			var dir := to / d
			global_position += dir * left
			global_position.y = move_toward(global_position.y, target.y, absf(target.y - global_position.y) * left / d)
			_face_toward(dir, delta)
			left = 0.0
	if _path_i < _path.size():
		var st := _walk_state_at(global_position)
		if st != _path_state:
			_set_walk_state(global_position)
	else:
		_finish_path()


func _face_toward(dir: Vector3, delta: float) -> void:
	var yaw := atan2(dir.x, dir.z)
	global_rotation = Vector3(0.0, lerp_angle(global_rotation.y, yaw, minf(1.0, 10.0 * delta)), 0.0)


func _finish_path() -> void:
	_path = PackedVector3Array()
	_path_i = 0
	var done := _path_done
	_path_done = Callable()
	if done.is_valid():
		done.call()


## Turn in place to a yaw (radians), then call `then`.
func turn_to(yaw: float, then := Callable()) -> void:
	_turn_goal = yaw
	_turn_done = then


func _step_turn(delta: float) -> void:
	var cur := global_rotation.y
	var diff := wrapf(_turn_goal - cur, -PI, PI)
	var step := TURN_RATE * delta
	if absf(diff) <= step:
		global_rotation = Vector3(0.0, _turn_goal, 0.0)
		_turn_goal = NAN
		var done := _turn_done
		_turn_done = Callable()
		if done.is_valid():
			done.call()
	else:
		global_rotation = Vector3(0.0, cur + signf(diff) * step, 0.0)


## Hold `state` for `seconds`, then call `then` (a one-shot's length, a dwell). A one-shot that is already
## the current node starts over: travel() to the current node is a no-op, so the hold would time a clip half done.
func hold(state: String, seconds: float, then := Callable()) -> void:
	if state != "":
		var replay := playback != null and playback.get_current_node() == state and not LOOPING.has(_states().get(state, ""))
		play(state)
		if replay:
			playback.start(state, true)
	_wait = maxf(seconds, 0.001)
	_wait_done = then


func stop_all() -> void:
	_path = PackedVector3Array()
	_path_i = 0
	_path_done = Callable()
	_turn_goal = NAN
	_turn_done = Callable()
	_wait = 0.0
	_wait_done = Callable()
	_route_phase = ""


# ------------------------------------------------------------------ the front door

func _update_door() -> void:
	if _door == null or not is_instance_valid(_door) or not _door.has_method("hold_open"):
		return
	var dp := (_door as Node3D).global_position
	var near := Vector2(global_position.x - dp.x, global_position.z - dp.z).length() <= DOOR_REACH and is_walking()
	if near and not _holding_door:
		_door.hold_open(self)
		_holding_door = true
	elif not near and _holding_door:
		_release_door()


func _release_door() -> void:
	if _holding_door and _door and is_instance_valid(_door) and _door.has_method("release_hold"):
		_door.release_hold(self)
	_holding_door = false


func _exit_tree() -> void:
	_release_door()


# ------------------------------------------------------------------ hired and fired

func _on_staff_hired(_staff_id: String, r: String) -> void:
	if r != role:
		return
	if present and not _leaving:
		return
	if _leaving:
		_leaving = false                  # a hire during the walk-out turns them back
		var was := _route_phase
		stop_all()
		if was == "out":                  # on the route: back in from the segment they are on
			var s := _route_segment_index()
			var ahead := PackedVector3Array()
			for i in range(s + 1, arrive_route.size()):
				ahead.append(arrive_route[i])
			_route_phase = "in"
			walk(ahead, _end_route_in)
		else:                             # still leaving the station: take it again from here
			_route_phase = "station"
			_take_station(_arrived)
		return
	arrive()


func _on_staff_fired(_staff_id: String, r: String) -> void:
	if r != role or not present or _leaving:
		return
	leave()


## Walk in from the porch to the station.
func arrive() -> void:
	stop_all()
	present = true
	visible = true
	_leaving = false
	if arrive_route.is_empty():
		place_at_station()
		arrived_at_station.emit()
		return
	global_position = arrive_route[0]
	var rest := PackedVector3Array()
	for i in range(1, arrive_route.size()):
		rest.append(arrive_route[i])
	var d := arrive_route[1] - arrive_route[0] if arrive_route.size() > 1 else Vector3(0, 0, -1)
	global_rotation = Vector3(0.0, atan2(d.x, d.z), 0.0)
	_route_phase = "in"
	walk(rest, _end_route_in)


func _end_route_in() -> void:
	_route_phase = "station"          # still arriving (the take-station leg): the API is refused until _arrived
	_take_station(_arrived)


func _arrived() -> void:
	_route_phase = ""
	arrived_at_station.emit()


## Walk out: to the end of arrive_route by the station's own path, then the route reversed; hide on the porch.
## Fired during the walk-in, they go back from the route segment they are on.
func leave() -> void:
	var was := _route_phase
	stop_all()
	_leaving = true
	_drop_props()
	_release_door()
	if was == "in":
		_walk_route_out(_route_segment_index())
		return
	_leave_station(func(): _walk_route_out(arrive_route.size() - 1))


## arrive_route from index `from` back to the porch, then hide.
func _walk_route_out(from: int) -> void:
	var back := PackedVector3Array()
	for i in range(from, -1, -1):
		back.append(arrive_route[i])
	_route_phase = "out"
	walk(back, _gone)


func _gone() -> void:
	_release_door()
	_route_phase = ""
	_leaving = false
	present = false
	visible = false
	left_tavern.emit()


## The arrive_route segment (i, i + 1) nearest to where they stand.
func _route_segment_index() -> int:
	var best := 0
	var best_d := INF
	for i in range(arrive_route.size() - 1):
		var q := Geometry3D.get_closest_point_to_segment(global_position, arrive_route[i], arrive_route[i + 1])
		var dist := q.distance_to(global_position)
		if dist < best_d:
			best_d = dist
			best = i
	return best


func _drop_props() -> void:
	pass


# ------------------------------------------------------------------ barks

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


func bark() -> void:
	if _barks.is_empty() or not is_inside_tree() or get_tree().paused:
		return
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.get("game_over_active"):
		return
	_last_bark = pick_line(_barks.size(), _last_bark, randf())
	for c in get_children():          # one line at a time: a new one replaces the last
		if c is PatronSpeechBubble:
			c.queue_free()
	var bubble := PatronSpeechBubble.new()
	add_child(bubble)
	bubble.position.y = _bubble_height() - PatronSpeechBubble.HEAD_HEIGHT
	bubble.say(_barks[_last_bark], 3.5)
