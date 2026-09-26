# bartender.gd — the Bartender (Story 25.13, catalogue G12): works the inside of the round bar.
#
# Stations: the five serve points (stood at SERVE_R, facing the counter) and the restock station at the
# kegs (φ 180, RESTOCK_R, facing the island), found by NodePath under bar_path — the B12 marker by a search
# scoped to BackBar, never a global find_child("work_point") (the desk's glTF has one too).
# Inside the ring he shuffles (Walk_Bar) along arcs round its centre, never straight chords, at a radius
# that clears the shelf, the kegs and the counter (ring_radius_at: 1.80, 1.90 by the kegs, 1.98 in the
# flap gap; measured on his skinned body, Story 25.13 T3). He enters and leaves through the flap.
# States follow Story 16.3's FSM (work_state IDLE / SERVING / RESTOCKING); 16.3 drives him through
# serve_toward / restock / enter_idle and connects drink_handed to serve_patron(). Until then a cosmetic
# autopilot keeps him wiping ("rarely stops moving") and restocks when the beer runs out. No game effects.
extends "res://scripts/game/staff_npc.gd"

signal drink_handed(target: Vector3)

const RING_R := 1.80               # the serve markers' radius
const KEG_R := 1.90                # past the kegs (|φ - 180| <= 30°): clears the kegs and the counter
const KEG_HALF_DEG := 30.0
const KEG_RAMP_DEG := 12.0
const GAP_R := 1.98                # inside the counter's flap gap (|φ - 180| <= 6°)
const GAP_HALF_DEG := 6.0
const GAP_RAMP_TO_DEG := 12.0
const RESTOCK_R := 1.98            # the restock station (B12's work_point is at 1.80: his stride hits the rack there)
const SERVE_R := 1.76              # 0.04 in from the serve markers: his beard clears the counter top
const FLAP_R := 3.70               # the flap entrance, on the navmesh (the end of his arrive_route)
const BAR_INNER := 3.2             # inside this radius he shuffles
const WALK_BAR_HALF_LOW := 0.408   # Walk_Bar's half-width at the kegs' height (0.26-0.49 m), measured
const WALK_BAR_HALF_SHELF := 0.413 # ... at the shelf's lowest tier (0.3-0.6 m)
const WALK_BAR_HALF_MID := 0.445   # ... up to the counter top (0.6-1.12 m)
const CAMERA_VISIBLE := [0, 1, 2, 4]   # serve points 01, 02, 03, 05 (04 is behind the pillar)
const SERVE_RELEASE_AT := 0.6
const WIPE_DWELL := Vector2(6.0, 12.0)
const BARK_GAP := Vector2(45.0, 90.0)
const RESTOCK_INDEX := 5

@export var bar_path: NodePath

var _center := Vector3.ZERO
var _stands: Array = []            # [{"pos": Vector3, "yaw": float, "phi": float}] x5, then the restock station
var _stool_roots: Array = []       # where a seated patron's root is, per stool
var _station := -1
var _work := "IDLE"
var _dwell := 0.0
var _bark_cd := 0.0
var _tankard: Node3D = null
var _rng := RandomNumberGenerator.new()


func _states() -> Dictionary:
	return {"Idle": "Idle", "Walk": "Walking_A", "WalkBar": "Walk_Bar", "Wipe": "Wipe", "Pour": "Pour",
		"Serve": "Serve", "Restock": "Restock"}


func _ready() -> void:
	_rng.randomize()
	_resolve_bar()
	super._ready()
	var eb := get_node_or_null("/root/EconomyBus")
	if eb and eb.has_signal("beer_changed"):
		eb.beer_changed.connect(_on_beer)


func _resolve_bar() -> void:
	var bar := get_node_or_null(bar_path) as Node3D if not bar_path.is_empty() else null
	if bar == null:
		push_warning("[Staff] missing: the Bartender's bar_path does not resolve")
		return
	_center = bar.global_position
	for i in range(1, 6):
		var sp := bar.get_node_or_null("ServePoints/serve_point_0%d" % i) as Node3D
		if sp == null:
			continue
		var d := sp.global_position - _center
		var phi := atan2(d.x, d.z)
		var f := sp.global_basis.z
		_stands.append({"pos": ring_point(_center, phi, SERVE_R), "yaw": atan2(f.x, f.z), "phi": phi})
	var back := bar.get_node_or_null("BackBar")
	var wp := back.find_child("work_point", true, false) as Node3D if back else null
	var rphi := PI
	var ryaw := 0.0
	if wp:
		var d := wp.global_position - _center
		rphi = atan2(d.x, d.z)
		var f := wp.global_basis.z
		ryaw = atan2(f.x, f.z)
	_stands.append({"pos": ring_point(_center, rphi, RESTOCK_R), "yaw": ryaw, "phi": rphi})
	for n in bar.find_children("SeatPoint", "Node3D", true, false):
		_stool_roots.append(RealisticPatron.seat_root((n as Node3D).global_transform))


# ------------------------------------------------------------------ the ring (statics)

## The walk radius at ring angle phi (radians; 0 = +Z): 1.80, swinging out past the kegs and into the flap gap.
static func ring_radius_at(phi: float) -> float:
	var d := absf(rad_to_deg(wrapf(phi - PI, -PI, PI)))
	if d <= GAP_HALF_DEG:
		return GAP_R
	if d <= GAP_RAMP_TO_DEG:
		var t := (d - GAP_HALF_DEG) / (GAP_RAMP_TO_DEG - GAP_HALF_DEG)
		return GAP_R + (KEG_R - GAP_R) * 0.5 * (1.0 - cos(PI * t))
	if d <= KEG_HALF_DEG:
		return KEG_R
	if d >= KEG_HALF_DEG + KEG_RAMP_DEG:
		return RING_R
	var u := (d - KEG_HALF_DEG) / KEG_RAMP_DEG
	return KEG_R + (RING_R - KEG_R) * 0.5 * (1.0 - cos(PI * u))


static func ring_point(center: Vector3, phi: float, r: float) -> Vector3:
	return center + Vector3(sin(phi) * r, 0.0, cos(phi) * r)


## An arc round the ring from one angle to another, the shorter way, sampled every `step` metres.
static func ring_arc(center: Vector3, from_phi: float, to_phi: float, step := 0.25) -> PackedVector3Array:
	var out := PackedVector3Array()
	var span := wrapf(to_phi - from_phi, -PI, PI)
	if absf(absf(span) - PI) < 1e-6:
		span = PI
	var n := maxi(1, int(ceil(absf(span) * KEG_R / step)) + 1)
	for i in n + 1:
		var phi := from_phi + span * float(i) / n
		out.append(ring_point(center, phi, ring_radius_at(phi)))
	return out


## The station (by position) nearest a target, flat distance.
static func nearest_station(stations: Array, target: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in stations.size():
		var s: Vector3 = stations[i]
		var d := Vector2(s.x - target.x, s.z - target.z).length()
		if d < best_d:
			best_d = d
			best = i
	return best


# ------------------------------------------------------------------ the visual API (Story 16.3)

func work_state() -> String:
	return _work


func set_autopilot(on: bool) -> void:
	autopilot = on


func enter_idle() -> void:
	stop_all()
	_drop_props()
	_work = "IDLE"
	_dwell = 0.0


## Pour at the taps, carry it to the serve point nearest the target, set it on the counter: drink_handed at
## the release (Story 16.3 connects it to serve_patron()); then back to IDLE.
func serve_toward(target: Vector3) -> void:
	if _stands.size() < 6:
		return
	stop_all()
	_work = "SERVING"
	_go_to(RESTOCK_INDEX, func():
		_hold_tankard()
		hold("Pour", state_length("Pour"), func():
			var serve_points := []
			for i in 5:
				serve_points.append(_stands[i].pos)
			var i := nearest_station(serve_points, target)
			_go_to(i, func():
				hold("Serve", state_length("Serve") * SERVE_RELEASE_AT, func():
					_drop_props()
					drink_handed.emit(target)
					if _rng.randf() < 0.5:
						bark()
					hold("", state_length("Serve") * (1.0 - SERVE_RELEASE_AT), func():
						_work = "IDLE"
						_start_wiping())))))


## Restock at the kegs until told otherwise (Story 16.3: RESTOCKING while the drink is out).
func restock(active: bool) -> void:
	stop_all()
	if active:
		_work = "RESTOCKING"
		_go_to(RESTOCK_INDEX, func(): play("Restock"))
	else:
		_work = "IDLE"
		_dwell = 0.0


# ------------------------------------------------------------------ stations and paths

func place_at_station() -> void:
	stop_all()
	if _stands.is_empty():
		play("Idle")
		return
	_station = 0
	global_position = _stands[0].pos
	global_rotation = Vector3(0.0, _stands[0].yaw, 0.0)
	_work = "IDLE"
	_start_wiping()


func _start_wiping() -> void:
	play("Wipe")
	_dwell = _rng.randf_range(WIPE_DWELL.x, WIPE_DWELL.y)


func _walk_state_at(p: Vector3) -> String:
	return "WalkBar" if Vector2(p.x - _center.x, p.z - _center.z).length() < BAR_INNER else "Walk"


## From where he is to a station: the flap leg if he is outside the counter, then an arc, then the stand spot.
func _route_to(index: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var here := global_position - _center
	var r := Vector2(here.x, here.z).length()
	var phi := atan2(here.x, here.z)
	if r > 2.5:                                         # outside the counter: in through the flap first
		for rr in [2.70, RESTOCK_R]:
			out.append(ring_point(_center, PI, rr))
		phi = PI
	else:
		out.append(ring_point(_center, phi, ring_radius_at(phi)))
	var to: Dictionary = _stands[index]
	for p in ring_arc(_center, phi, to.phi):
		out.append(p)
	out.append(to.pos)
	return out


func _go_to(index: int, then := Callable()) -> void:
	if index < 0 or index >= _stands.size():
		return
	if _station == index and global_position.distance_to(_stands[index].pos) < 0.02:
		turn_to(_stands[index].yaw, then)
		return
	_station = -1
	walk(_route_to(index), func():
		turn_to(_stands[index].yaw, func():
			_station = index
			if then.is_valid():
				then.call()))


func _take_station(then: Callable) -> void:
	_go_to(0, func():
		_work = "IDLE"
		_start_wiping()
		then.call())


func _leave_station(then: Callable) -> void:
	var here := global_position - _center
	var phi := atan2(here.x, here.z)
	var out := PackedVector3Array()
	if Vector2(here.x, here.z).length() > 2.5:          # already on the flap leg (fired on his way in): straight out
		out.append(ring_point(_center, PI, FLAP_R))
	else:
		out.append(ring_point(_center, phi, ring_radius_at(phi)))
		for p in ring_arc(_center, phi, PI):
			out.append(p)
		for rr in [2.70, FLAP_R]:
			out.append(ring_point(_center, PI, rr))
	_station = -1
	walk(out, then)


# ------------------------------------------------------------------ the autopilot (cosmetic)

func _tick_work(delta: float) -> void:
	_bark_cd = maxf(0.0, _bark_cd - delta)
	if _tankard and is_instance_valid(_tankard):              # the tankard stays upright every tick
		_tankard.global_basis = Basis(Vector3.UP, global_rotation.y).scaled(Vector3.ONE * RealisticPatron.TANKARD_HELD_SCALE)
	if not autopilot or _leaving or is_busy() or not _queue.is_empty() or _stands.size() < 6:
		return
	var beer := _beer()
	if _work == "SERVING":
		return
	if beer <= 0:
		if _work != "RESTOCKING" or _station != RESTOCK_INDEX:
			_work = "RESTOCKING"
			_go_to(RESTOCK_INDEX, func(): play("Restock"))
		elif anim_state() != "Restock":
			play("Restock")
		return
	if _work == "RESTOCKING":
		_work = "IDLE"
		_dwell = 0.0
	if _station < 0 or _station == RESTOCK_INDEX:
		_go_to(_pick_station(), func(): _start_wiping())
		return
	if anim_state() != "Wipe":
		_start_wiping()
	_dwell -= delta
	if _bark_cd <= 0.0 and _patron_near(_station):
		bark()
		_bark_cd = _rng.randf_range(BARK_GAP.x, BARK_GAP.y)
	if _dwell <= 0.0:
		_go_to(_pick_station(), func(): _start_wiping())


func _pick_station() -> int:
	var busy := CAMERA_VISIBLE.filter(func(i): return i != _station and _patron_near(i))
	if not busy.is_empty():
		return busy[_rng.randi() % busy.size()]
	var others := CAMERA_VISIBLE.filter(func(i): return i != _station)
	return others[_rng.randi() % others.size()] if not others.is_empty() else 0


## A patron sits on the stool this station faces (positions only: within 0.3 m of a stool's seat root).
func _patron_near(index: int) -> bool:
	if index < 0 or index >= 5 or not is_inside_tree():
		return false
	var s: Vector3 = _stands[index].pos
	for p in get_tree().get_nodes_in_group("patrons"):
		if not (p is Node3D) or not is_instance_valid(p):
			continue
		var pp := (p as Node3D).global_position
		for root in _stool_roots:
			var rv: Vector3 = root
			if Vector2(pp.x - rv.x, pp.z - rv.z).length() < 0.3 and Vector2(rv.x - s.x, rv.z - s.z).length() < 2.5:
				return true
	return false


func _beer() -> int:
	var gm := get_node_or_null("/root/GameManager")
	return int(gm.get_beer_pints()) if gm and gm.has_method("get_beer_pints") else 1


func _on_beer(v) -> void:
	if autopilot and int(v) <= 0 and _work == "IDLE" and present and not _leaving:
		stop_all()                                         # stop wiping: the autopilot sends him to restock


# ------------------------------------------------------------------ props

func play(state: String) -> void:
	super.play(state)
	var cloth := model.find_child("Bartender_ClothHand", true, false) as Node3D if model else null
	if cloth:
		cloth.visible = state == "Wipe"


func _hold_tankard() -> void:
	_drop_props()
	if model == null:
		return
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var att := BoneAttachment3D.new()
	att.name = "TankardSlot"
	att.bone_name = "handslot.r"
	(sks[0] as Skeleton3D).add_child(att)
	var scene := load(RealisticPatron.TANKARD_FULL) as PackedScene
	if scene:
		_tankard = scene.instantiate() as Node3D
		att.add_child(_tankard)


func _drop_props() -> void:
	if _tankard and is_instance_valid(_tankard):
		_tankard.get_parent().queue_free()
	_tankard = null


func _bubble_height() -> float:
	return PatronSpeechBubble.HEAD_HEIGHT
