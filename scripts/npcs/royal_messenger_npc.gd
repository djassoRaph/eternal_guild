# royal_messenger_npc.gd — the King's messenger's body in the hall (Story 10.7, the demo's ending). A tavern visitor like
# the disturbances' (it extends disturbance_npc.gd by path: a townsfolk body by variant id with the patrons' loader and
# look, the 1.2 m talk zone given E by the scene's ZonePromptUI, talk_requested, the cooldown, leave() on the navmesh),
# plus how he moves (KM-4): from the porch he walks the route in through the front door, straight and without physics (the
# porch is a step below the hall; his body still opens the door), then to the
# player along the navmesh (a NavigationAgent3D; straight at the target when there is no path, as the visitors walk out),
# stopping stop_distance short and facing them, re-aimed at most every repath_seconds when they moved more than 1.5 m;
# not there after approach_timeout (or no player in the hall, or approach off) he walks to the wait spot and waits, facing
# the hall. Not inside the door after walk_in_timeout, he is placed at the last route point. The hall's controller
# (scripts/game/royal_messenger.gd) decides when he comes and what a talk does. Built in code (no scene file); no
# class_name: loaded by path.
extends "res://scripts/npcs/disturbance_npc.gd"

signal settled(npc: Node, where: String)   # he stopped: "player" (beside them) or "wait" (at the wait spot)

const REPATH_MOVE := 1.5      # the player moved this far from where he was aiming: aim again (at most every repath_seconds)
const STEP_ARRIVE := 0.35     # this close to a route point or the wait spot counts as there
const STOP_SLACK := 0.1       # beside the player: within stop_distance + this; the stop point itself: within this

var route: Array = []                 # world points walked first, in order (inside the door)
var wait_spot := Vector3.ZERO
var wait_yaw_deg := 180.0
var approach := true
var stop_distance := 1.3   # inside the talk zone's reach (1.2 + the player's 0.5 capsule): E works without a step
var repath_seconds := 1.5
var approach_timeout := 25.0
var walk_in_timeout := 12.0
## The player to walk to: a Callable returning a Node3D or null (the hall's controller; tests). Unset: PlayerManager's.
var player_provider: Callable
## "" (placed, idle), "walking_in", "approaching", "to_wait", "by_player", "waiting".
var mode := ""
var _route_i := 0
var _target := Vector3.ZERO
var _phase_left := 0.0
var _repath_left := 0.0
var _aimed_at := Vector3.INF


func _ready() -> void:
	super()   # the body, the agent, the talk zone and its E (claimed once the ZonePromptUI is there)
	remove_from_group("disturbance_npc")   # not one of the disturbances: their director and Test 38 count that group
	add_to_group("royal_messenger")


## Walk in: from where he stands (the porch) along `route`, then to the player (or the wait spot).
func walk_in() -> void:
	_route_i = 0
	if route.is_empty():
		_after_route()
		return
	mode = "walking_in"
	_phase_left = walk_in_timeout
	_aim(route[0])


## He is in the hall already (a load, a scene re-entered): at the wait spot, then one approach to the player.
func place_waiting() -> void:
	global_position = wait_spot
	rotation.y = deg_to_rad(wait_yaw_deg)
	_after_route()


func _after_route() -> void:
	var p := _player_node()
	if approach and p != null:
		mode = "approaching"
		_phase_left = approach_timeout
		_repath_left = 0.0
		_aim(_stop_point(p.global_position))
	else:
		_go_wait()


func _go_wait() -> void:
	mode = "to_wait"
	_aim(wait_spot)


func _aim(at: Vector3) -> void:
	_target = at
	if _agent and is_inside_tree():
		_agent.target_position = at
	_play("Walking_A")


## The spot stop_distance short of `p`, on the line from him to it.
func _stop_point(p: Vector3) -> Vector3:
	_aimed_at = p
	var d := Vector3(global_position.x - p.x, 0.0, global_position.z - p.z)
	if d.length() < 0.01:
		return p
	return p + d.normalized() * stop_distance


func _player_node() -> Node3D:
	var p = player_provider.call() if player_provider.is_valid() else (PlayerManager.player if is_instance_valid(PlayerManager.player) else null)
	return p if p is Node3D and is_instance_valid(p) and (p as Node3D).is_inside_tree() else null


func _physics_process(delta: float) -> void:
	super(delta)   # the talk cooldown; the walk out once leaving
	if leaving or fading:
		return
	match mode:
		"walking_in":
			_phase_left -= delta
			if _flat(_target - global_position).length() <= STEP_ARRIVE:
				_route_i += 1
				if _route_i < route.size():
					_aim(route[_route_i])
				else:
					_after_route()
			elif _phase_left <= 0.0:
				var last: Vector3 = route[-1]
				print("[DemoEnding] the messenger isn't through the door after %.0f s: placed inside" % walk_in_timeout)
				global_position = last
				_after_route()
			else:
				_glide_toward(_target, delta)
		"approaching":
			var p := _player_node()
			if p == null:
				_go_wait()
				return
			_phase_left -= delta
			_repath_left -= delta
			var to_player := _flat(p.global_position - global_position)
			if to_player.length() <= stop_distance + STOP_SLACK:
				_stand("by_player", p.global_position)
				return
			if _phase_left <= 0.0:
				print("[DemoEnding] the messenger didn't reach the guild master in %.0f s: he waits by the door" % approach_timeout)
				_go_wait()
				return
			if _repath_left <= 0.0 and _flat(p.global_position - _aimed_at).length() > REPATH_MOVE:
				_repath_left = repath_seconds
				_aim(_stop_point(p.global_position))
			if _flat(_target - global_position).length() <= STOP_SLACK:
				_play("Idle")   # as close as the navmesh lets him: the player comes the rest of the way
				_face(p.global_position, delta)
			else:
				_step_toward(_target, delta)
		"to_wait":
			if _flat(wait_spot - global_position).length() <= STEP_ARRIVE:
				_stand("waiting", Vector3.INF)
			else:
				_step_toward(wait_spot, delta)
		"by_player":
			var p2 := _player_node()
			if p2 != null:
				_face(p2.global_position, delta)
				if _flat(p2.global_position - global_position).length() > stop_distance + REPATH_MOVE + 1.0:
					mode = "approaching"   # the player walked off: follow once more, with a fresh clock
					_phase_left = approach_timeout
					_aim(_stop_point(p2.global_position))


func _stand(where: String, face_at: Vector3) -> void:
	mode = where
	velocity = Vector3.ZERO
	_play("Idle")
	if where == "waiting":
		rotation.y = deg_to_rad(wait_yaw_deg)
	elif face_at != Vector3.INF:
		var d := _flat(face_at - global_position)
		if d.length() > 0.01:
			rotation.y = atan2(d.x, d.z)
	settled.emit(self, "player" if where == "by_player" else "wait")


func _step_toward(at: Vector3, delta: float) -> void:
	var next := _agent.get_next_path_position() if _agent and not _agent.is_navigation_finished() else at
	var dir := _flat(next - global_position)
	if dir.length() < 0.01:
		dir = _flat(at - global_position)
	if dir.length() < 0.001:
		return
	dir = dir.normalized()
	velocity = Vector3(dir.x * WALK_SPEED, velocity.y - 9.8 * delta if not is_on_floor() else 0.0, dir.z * WALK_SPEED)
	move_and_slide()
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, 8.0 * delta))
	_play("Walking_A")


## The walk in: straight along the route, without physics (the staff's porch-to-hall leg, known clear). The porch is a
## 0.33 m step below the hall floor that a capsule can't climb with move_and_slide (Stage D 2026-11-01: he stood in the
## doorway); his body still opens the door (its trigger sees him).
func _glide_toward(at: Vector3, delta: float) -> void:
	var d := at - global_position
	var flat := _flat(d)
	if flat.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), minf(1.0, 8.0 * delta))
	global_position = global_position.move_toward(at, WALK_SPEED * delta)
	velocity = Vector3.ZERO
	_play("Walking_A")


func _face(at: Vector3, delta: float) -> void:
	var d := _flat(at - global_position)
	if d.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(1.0, 6.0 * delta))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
