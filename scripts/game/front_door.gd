# front_door.gd
# Tavern front door (Story 25.3, catalogue B10). Both leaves swing out toward the porch
# when a CharacterBody3D (patron, player, later the Bard or the Elder) enters the trigger,
# and swing shut once the trigger has been empty for close_delay seconds. Walkers without a
# body (the staff, Story 25.13) hold it open with hold_open(self) and let go with release_hold(self).
# The leaves have no collision and the trigger blocks nothing, so the door never gets in
# the way of navigation. door_opened / door_closed are for the creak SFX (Story 25.24).
extends Node3D

signal door_opened
signal door_closed

## How far each leaf swings, in degrees.
@export var open_angle_degrees: float = 100.0
@export var open_duration: float = 0.25
@export var close_duration: float = 0.35
## Seconds the trigger must stay empty before the door closes.
@export var close_delay: float = 0.6

# Per hinge: the left leaf opens with a negative turn, the mirrored right leaf with a
# positive one, so both swing toward +Z (outside).
const SWING_SIGN: Array[float] = [-1.0, 1.0]

@onready var _trigger: Area3D = $Trigger
@onready var _hinges: Array[Node3D] = [$HingeLeft, $HingeRight]

var _closed_angles: Array[float] = []
var _bodies: Dictionary = {}  # instance_id -> true, CharacterBody3D only
var _holders: Dictionary = {}  # instance_id -> true, walkers without a body (hold_open / release_hold)
var _is_open := false
var _tween: Tween
var _close_timer: Timer


func _ready() -> void:
	for hinge in _hinges:
		_closed_angles.append(hinge.rotation.y)
	_close_timer = Timer.new()
	_close_timer.one_shot = true
	_close_timer.timeout.connect(_on_close_timer_timeout)
	add_child(_close_timer)
	_trigger.body_entered.connect(_on_body_entered)
	_trigger.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	_bodies[body.get_instance_id()] = true
	_close_timer.stop()
	if not _is_open:
		_swing(true)


func _on_body_exited(body: Node3D) -> void:
	if not _bodies.erase(body.get_instance_id()):
		return
	_prune_holders()
	if _bodies.is_empty() and _holders.is_empty():
		_close_timer.start(close_delay)


## Hold the door open for a walker without a body (it stays open while any holder or body is there).
func hold_open(holder: Object) -> void:
	if holder == null:
		return
	_holders[holder.get_instance_id()] = true
	_close_timer.stop()
	if not _is_open:
		_swing(true)


## Let go of the door; it closes close_delay after the last holder and body have gone.
func release_hold(holder: Object) -> void:
	if holder == null or not _holders.erase(holder.get_instance_id()):
		return
	_prune_holders()
	if _bodies.is_empty() and _holders.is_empty():
		_close_timer.start(close_delay)


func _prune_holders() -> void:
	for id in _holders.keys():
		if not is_instance_id_valid(id):
			_holders.erase(id)


func _on_close_timer_timeout() -> void:
	_prune_holders()
	if _bodies.is_empty() and _holders.is_empty() and _is_open:
		_swing(false)


func _swing(open: bool) -> void:
	_is_open = open
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT if open else Tween.EASE_IN_OUT)
	for i in _hinges.size():
		var target := _closed_angles[i]
		if open:
			target += deg_to_rad(open_angle_degrees) * SWING_SIGN[i]
		_tween.tween_property(_hinges[i], "rotation:y", target, open_duration if open else close_duration)
	if open:
		print("[FrontDoor] opened")
		door_opened.emit()
	else:
		print("[FrontDoor] closed")
		door_closed.emit()
