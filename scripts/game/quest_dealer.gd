# quest_dealer.gd — the Quest Dealer (Story 25.13, catalogue G13; the "Desk Manager" of Epic 16): works the
# guild desk.
#
# Her station is the desk's WorkPoint (group work_point, the stool's seat centre). She sits DEALER_HIP_BACK in
# front of it (her own offset: the patrons' 0.40 would put her belly into the desk top), and the desk stool is
# baked into the desk's glTF, so she pulls it out, sits and shuffles in with it (K10): from the approach west
# of the stool, Interact while the stool slides back STOOL_PULL, a shuffle-step to the standing root, a turn
# to face the room, Sit_Chair_Down, then root and stool slide in together. Standing up is the reverse. Near
# the desk she walks with her hands in front (Walk_Bar): her arms would otherwise sweep the desk top.
# States follow Story 16.4's FSM (work_state IDLE = Write / BRIEFING = Brief / AVAILABLE = Sit_Chair_Idle);
# 16.4 drives her through set_work_state. Until then a cosmetic autopilot: BRIEFING while the recruitment or
# a mission screen is open (with a bark on its rising edge), AVAILABLE while the player is at the desk front,
# else writing. No game effects, no E. Call set_autopilot(false) before driving the API; while it is on, the
# autopilot owns the state.
extends "res://scripts/game/staff_npc.gd"

const DEALER_HIP_BACK := 0.32      # her seated root is this far in front of the WorkPoint (measured, T0)
const STOOL_PULL := 0.52           # the stool slides back this far while she sits down (measured, T3)
const SEAT_HEIGHT := 0.44
const SEATED_FRONT := -0.039       # Sit_Chair_Idle's front at desk-top height, from her root (measured)
const WALK_HALF_AT_DESK := 0.40    # Walk_Bar's half-width at desk-top height (measured 0.392)
const APPROACH_LOCAL := Vector3(-0.60, 0.0, -1.20)   # desk-local: west of the stool, clear of the desk top
const DESK_NEAR := 1.0             # within this of the desk top she shuffles (Walk_Bar)
const SLIDE_TIME := 0.5
const BARK_GAP := 20.0
const WORK_STATES := ["IDLE", "BRIEFING", "AVAILABLE"]
const QUILL := "Dealer_Quill"      # the body's prop node: shows while she is seated

@export var desk_path: NodePath
@export var recruitment_zone_path: NodePath
@export var recruitment_popup_path: NodePath

var _desk: Node3D = null
var _work_point: Node3D = null
var _stool: Node3D = null
var _zone: Area3D = null
var _popup: Node = null
var _seated := false
var _work := "IDLE"
var _slide := {}                   # an active slide: {from, to, stool_from, stool_to, t, then}
var _briefing_was := false
var _bark_cd := 0.0


func _states() -> Dictionary:
	return {"Idle": "Idle", "Walk": "Walking_A", "WalkBar": "Walk_Bar", "Interact": "Interact",
		"SitDown": "Sit_Chair_Down", "StandUp": "Sit_Chair_StandUp", "Write": "Write", "Brief": "Brief",
		"Available": "Sit_Chair_Idle"}


func _ready() -> void:
	_resolve_desk()
	_check_route_end()
	super._ready()


func _resolve_desk() -> void:
	_desk = get_node_or_null(desk_path) as Node3D if not desk_path.is_empty() else null
	if _desk == null:
		push_warning("[Staff] missing: the Quest Dealer's desk_path does not resolve")
		return
	for n in _desk.find_children("*", "Node3D", true, false):
		if n.is_in_group("work_point"):
			_work_point = n
			break
	if _work_point == null:
		push_warning("[Staff] missing: no work_point under the Quest Dealer's desk %s" % _desk.get_path())
	var m := _desk.get_node_or_null("Model")
	_stool = m.find_child("desk_stool", true, false) as Node3D if m else null
	if _stool == null:
		push_warning("[Staff] missing: no desk_stool under %s/Model; she sits without pulling it out" % _desk.get_path())
	_zone = get_node_or_null(recruitment_zone_path) as Area3D if not recruitment_zone_path.is_empty() else null
	_popup = get_node_or_null(recruitment_popup_path) if not recruitment_popup_path.is_empty() else null


## Her seated root for a work point: DEALER_HIP_BACK along its flat +Z, on the floor under the seat.
static func seated_root(work_point: Transform3D) -> Vector3:
	var f := Vector3(work_point.basis.z.x, 0.0, work_point.basis.z.z)
	f = f.normalized() if f.length() > 0.001 else Vector3(0, 0, 1)
	var p := work_point.origin + f * DEALER_HIP_BACK
	p.y = work_point.origin.y - SEAT_HEIGHT
	return p


func _seat() -> Vector3:
	return seated_root(_work_point.global_transform) if _work_point else global_position


func _facing_yaw() -> float:
	var f := _work_point.global_basis.z if _work_point else Vector3(0, 0, 1)
	return atan2(f.x, f.z)


func _standing_root() -> Vector3:
	var yaw := _facing_yaw()
	return _seat() - Vector3(sin(yaw), 0.0, cos(yaw)) * STOOL_PULL


func _approach() -> Vector3:
	return _desk.global_transform * APPROACH_LOCAL if _desk else global_position


## arrive_route must end at her approach point: MainTavern's route and APPROACH_LOCAL are one point twice.
func _check_route_end() -> void:
	if arrive_route.is_empty() or _desk == null:
		return
	var want := _approach()
	var last := arrive_route[arrive_route.size() - 1]
	var off := Vector2(last.x - want.x, last.z - want.z).length()
	if off > 0.2:
		push_warning("[Staff] mismatch: the Quest Dealer's arrive_route ends %.2f m from her approach point %s" % [off, want])


## The stool's centre in the world: its mesh's box centre (desk_stool's origin is the desk's, its vertices baked).
func _stool_centre() -> Vector3:
	if _stool == null:
		return _standing_root()
	var mi := _stool as MeshInstance3D
	if mi == null:
		var ms := _stool.find_children("*", "MeshInstance3D", true, false)
		mi = ms[0] as MeshInstance3D if not ms.is_empty() else null
	if mi and mi.mesh:
		return mi.global_transform * mi.get_aabb().get_center()
	if _work_point and _desk:
		return _work_point.global_position + _desk.global_basis * _stool.position
	return _standing_root()


# ------------------------------------------------------------------ the visual API (Story 16.4)

func work_state() -> String:
	return _work


func set_work_state(state: String) -> void:
	if not WORK_STATES.has(state):
		push_warning("[Staff] unknown: work state '%s' for the Quest Dealer" % state)
		return
	_work = state
	if _seated and not is_busy():
		play(_state_for(state))


func _state_for(work: String) -> String:
	return {"BRIEFING": "Brief", "AVAILABLE": "Available"}.get(work, "Write")


# ------------------------------------------------------------------ the seat

func place_at_station() -> void:
	stop_all()
	_slide = {}
	if _stool:
		_stool.position = Vector3.ZERO
	global_position = _seat()
	global_rotation = Vector3(0.0, _facing_yaw(), 0.0)
	_seated = true
	_work = "IDLE"
	play("Write")


func _walk_state_at(p: Vector3) -> String:
	if _desk == null:
		return "Walk"
	var l := _desk.global_transform.affine_inverse() * p
	var dx := maxf(absf(l.x) - 1.03, 0.0)
	var dz := maxf(absf(l.z) - 0.476, 0.0)
	return "WalkBar" if Vector2(dx, dz).length() < DESK_NEAR else "Walk"


func _take_station(then: Callable) -> void:
	if _seated:                                   # re-hired mid shuffle-out: straight back in with the stool
		play("Available")
		_slide_seat(_seat(), 0.0, func():
			play(_state_for(_work))
			then.call())
		return
	if _stool and absf(_stool.position.z + STOOL_PULL) < 0.01:   # the stool is out (re-hired standing up): sit again
		_sit_from_stand(then)
		return
	var to_stool := _stool_centre() - global_position
	turn_to(atan2(to_stool.x, to_stool.z), func():
		hold("Interact", state_length("Interact") * 0.4, func():
			_slide_stool(-STOOL_PULL, func(): _sit_from_stand(then))))


## From beside the pulled-out stool: step to the standing root, face the room, sit down and shuffle in; then
## the state asked for (a set_work_state during the walk-in holds).
func _sit_from_stand(then: Callable) -> void:
	walk(PackedVector3Array([_standing_root()]), func():
		turn_to(_facing_yaw(), func():
			hold("SitDown", state_length("SitDown"), func():
				_seated = true
				play("Available")
				_slide_seat(_seat(), 0.0, func():
					play(_state_for(_work))
					then.call()))))


## Fired: a re-hire starts writing, not in the state from before the fire. Reset here, not in _leave_station:
## fired on her way in she walks straight back out and _leave_station never runs.
func leave() -> void:
	_work = "IDLE"
	super.leave()


func _leave_station(then: Callable) -> void:
	if not _seated:
		if _wanted == "SitDown":      # fired mid Sit_Chair_Down: she stands up again first (standing up is the reverse)
			hold("StandUp", state_length("StandUp"), func(): _stool_home(then))
		else:
			_stool_home(then)         # fired before she sat (the stool pull, the step in): the stool goes back first
		return
	play("Available")
	_slide_seat(_standing_root(), -STOOL_PULL, func():
		_seated = false
		hold("StandUp", state_length("StandUp"), func(): _stool_home(then)))


## From beside the desk: to the approach point, then the stool back home (nothing to do if it is home).
func _stool_home(then: Callable) -> void:
	if _stool == null or absf(_stool.position.z) < 0.01:
		then.call()
		return
	var app := _approach()
	walk(PackedVector3Array([app]), func():
		var to_stool := _stool_centre() - global_position
		turn_to(atan2(to_stool.x, to_stool.z), func():
			hold("Interact", state_length("Interact") * 0.4, func():
				_slide_stool(0.0, then))))


func stop_all() -> void:
	super.stop_all()
	_slide = {}                       # a slide's callback would carry on an interrupted sit or stand


## Slide the stool (desk-local z) to `z` over SLIDE_TIME.
func _slide_stool(z: float, then: Callable) -> void:
	_slide = {"root_from": global_position, "root_to": global_position, "stool_from": _stool.position.z if _stool else 0.0,
		"stool_to": z, "t": 0.0, "then": then}


## Slide her root and the stool together (the shuffle in or out).
func _slide_seat(to: Vector3, stool_z: float, then: Callable) -> void:
	_slide = {"root_from": global_position, "root_to": to, "stool_from": _stool.position.z if _stool else 0.0,
		"stool_to": stool_z, "t": 0.0, "then": then}


func is_busy() -> bool:
	return super.is_busy() or not _slide.is_empty()


# ------------------------------------------------------------------ per tick

func _tick_work(delta: float) -> void:
	_bark_cd = maxf(0.0, _bark_cd - delta)
	if not _slide.is_empty() and not is_walking() and not is_turning() and _wait <= 0.0:
		_slide.t = minf(1.0, float(_slide.t) + delta / SLIDE_TIME)
		var k := 0.5 * (1.0 - cos(PI * float(_slide.t)))
		global_position = (_slide.root_from as Vector3).lerp(_slide.root_to, k)
		if _stool:
			_stool.position.z = lerpf(float(_slide.stool_from), float(_slide.stool_to), k)
		if float(_slide.t) >= 1.0:
			var done: Callable = _slide.then
			_slide = {}
			if done.is_valid():
				done.call()
		return
	_update_quill()
	if not autopilot or not _seated or _leaving or is_busy():
		return
	var briefing := _briefing_open()
	var want := "BRIEFING" if briefing else ("AVAILABLE" if _player_at_desk() else "IDLE")
	if briefing and not _briefing_was and _bark_cd <= 0.0:
		bark()
		_bark_cd = BARK_GAP
	_briefing_was = briefing
	if want != _work or anim_state() != _state_for(want):
		_work = want
		play(_state_for(want))


func _briefing_open() -> bool:
	if _popup and is_instance_valid(_popup) and _popup.get("visible"):
		return true
	for b in get_tree().get_nodes_in_group("mission_board"):
		if b.get("visible"):
			return true
	return false


func _player_at_desk() -> bool:
	if _zone == null or not is_instance_valid(_zone):
		return false
	var p := get_tree().get_first_node_in_group("player")
	if p == null and get_tree().current_scene:
		p = get_tree().current_scene.find_child("Player", true, false)
	return p is Node3D and _zone.overlaps_body(p)


func _update_quill() -> void:
	var q := model.find_child(QUILL, true, false) as Node3D if model else null
	if q:
		q.visible = _seated


func _prop_nodes() -> Array:
	return [QUILL]


func _bubble_height() -> float:
	return 1.95 if _seated else PatronSpeechBubble.HEAD_HEIGHT
