# staff_ai.gd — what the staff's brains share (Epic 16): a LimboAI state machine (LimboHSM, asset 3787) built in code,
# one LimboState per state delegating to the brain's own callbacks. Story 16.3 (the Bartender) and 16.4 (the Quest
# Dealer) extend this file by path (no class_name).
# The HSM's update mode is MANUAL: the staff member's own tick(delta) updates it (staff_npc.gd), right after the walk and
# the timers and only while they are present, so a test steps it with manual_tick exactly like the body.
# This is the only game script that names LimboAI's classes: if LimboAI ever goes (an engine upgrade without a build of
# it), this file becomes a plain state machine with the same methods and the brains don't change.
# State callbacks never dispatch directly: they request() an event, which update() (or go()) dispatches once the
# callback has returned, so a transition never starts inside another one.
extends Node

var npc: Node3D = null
var hsm: LimboHSM = null
var _states := {}            # state name -> its LimboState
var _pending := ""           # an event requested inside a callback, dispatched after it


## Build the machine for a staff member (staff_npc.gd enable_automation() calls it once, after adding the brain).
func setup(staff_npc: Node3D) -> void:
	npc = staff_npc
	hsm = LimboHSM.new()
	hsm.name = "HSM"
	hsm.update_mode = LimboHSM.MANUAL
	add_child(hsm)
	_build()
	hsm.initialize(npc)
	hsm.set_active(true)
	_flush()
	_after_setup()


## The role's states and transitions (subclasses).
func _build() -> void:
	pass

## After the machine is running (subclasses: signals, config).
func _after_setup() -> void:
	pass

## Every update, before the active state's (subclasses: what all states read, e.g. who is waiting).
func _before_update(_delta: float) -> void:
	pass


## A state: its callbacks are optional; the first state added is the initial one.
func add_state(state_name: String, enter := Callable(), update_cb := Callable(), exit := Callable()) -> void:
	var s := LimboState.new()
	s.name = state_name
	if enter.is_valid():
		s.call_on_enter(enter)
	if update_cb.is_valid():
		s.call_on_update(update_cb)
	if exit.is_valid():
		s.call_on_exit(exit)
	hsm.add_child(s)
	_states[state_name] = s
	if hsm.initial_state == null:
		hsm.initial_state = s

func add_transition(from: String, to: String, event: String) -> void:
	hsm.add_transition(_states[from], _states[to], StringName(event))

## From any state.
func add_transition_from_any(to: String, event: String) -> void:
	hsm.add_transition(hsm.ANYSTATE, _states[to], StringName(event))


## Ask for an event from inside a state callback: dispatched once the callback has returned.
func request(event: String) -> void:
	_pending = event

## Dispatch an event now (from outside the machine: a signal handler).
func go(event: String) -> void:
	if hsm == null:
		return
	hsm.dispatch(StringName(event))
	_flush()

func update(delta: float) -> void:
	if hsm == null:
		return
	_before_update(delta)
	hsm.update(delta)
	_flush()

func _flush() -> void:
	var n := 0
	while _pending != "" and n < 4:      # an enter may ask for one more step; never loop forever
		var e := _pending
		_pending = ""
		hsm.dispatch(StringName(e))
		n += 1

## The active state's name ("" before setup).
func state() -> String:
	var s = hsm.get_active_state() if hsm else null
	return str(s.name) if s else ""

func state_names() -> Array:
	return _states.keys()
