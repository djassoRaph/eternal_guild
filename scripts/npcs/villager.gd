# villager.gd — a townsperson in ExteriorWorld (Story 25.14).
#
# Stands at a post (no waypoints) or walks a loop of waypoints, pausing at each stop. When the player
# passes close, says one line of the Villager's Voice (narrative-design.md: the ambient Social Mirror)
# in the patrons' speech bubble. Overheard, never addressed: no prompt, no input. The body is a
# townsfolk variant from data/characters/townsfolk.json (MOD-3), the same bodies patrons use.
# MVP per the narrative: "static placement or simple scripted paths" (NPCPresenceManager is V2).
extends CharacterBody3D

const BARKS_PATH := "res://data/dialogue/villager_barks.json"
const REGISTERS := ["grievance", "mirror", "paranoia"]   # escalating; weights live in the data
const BUBBLE_SCRIPT := preload("res://scripts/fx/patron_speech_bubble.gd")
const GRAVITY := 9.8
const HEAR_RADIUS := 6.0        # the player overhears within this distance
const ARRIVE_DIST := 0.3
const BUBBLE_SCALE := 1.5       # the town camera is about twice as wide as the tavern's; keep the words readable
const BUBBLE_GAP := 0.45        # (25.31 S2) the scaled text's centre this far over a measured head
const FALL_LIMIT := 5.0         # this far below where it started = fell through the ground: put it back
const QUIET_GAP := Vector2(4.0, 8.0)   # seconds of quiet after a bubble ends before anyone speaks again
const RECENT_BARKS := 6         # lines the whole village avoids repeating

@export var variant_id: String = "local"
@export var waypoints: PackedVector3Array = PackedVector3Array()   # world positions (XZ used); empty = stands
@export var walk_speed: float = 1.2
@export var pause_range: Vector2 = Vector2(2.0, 5.0)
@export var bark_cooldown_range: Vector2 = Vector2(25.0, 45.0)

static var _barks_cache = null
static var _speaking := 0       # villager bubbles on screen; a new bark waits for silence (pause-proof)
static var _quiet_left := 0.0   # game-time quiet after the last bubble (ticked once per physics frame)
static var _quiet_frame := -1
static var _recent_barks: Array = []

var body_variant: Dictionary = {}   # the townsfolk.json entry the body came from
var using_fallback := false
var body_look := ""
var walk_rate := 1.0                # Walking_A's playback rate on this body (V9)
var _model: Node3D = null
var _anim: AnimationPlayer = null
var _home := Vector3.ZERO
var _settled := false
var _next := 0
var _pause := 0.0
var _stuck := 0.0
var _cooldown := 0.0
var _listen := 0.0
var _player_was_near := false


func _ready() -> void:
	add_to_group("villagers")
	collision_layer = 0b00000010   # as patrons: the world collides with us, we don't collide with each other
	collision_mask = 0b00000001
	_home = global_position
	_spawn_model()
	_cooldown = randf_range(3.0, 10.0)   # stagger the first barks
	_pause = randf_range(0.0, pause_range.y)
	_play("Idle")


func _spawn_model() -> void:
	var pool := RealisticPatron.townsfolk_pool()
	var variant := {}
	for v in pool:
		if str(v.get("id", "")) == variant_id:
			variant = v
	if variant.is_empty() and not pool.is_empty():
		variant = pool[0]   # unknown id: any townsperson rather than nobody
		push_warning("Villager %s: unknown variant '%s', using %s" % [name, variant_id, str(variant.get("model_path", "")).get_file()])
	# Story 25.31 S2 (AC 12, V11): the patrons' body path: the model, else its fallback; the look gate on its own body
	# (the toon look, the hand-slot props hidden), Walking_A at walk_speed / walk_ground_speed (V9), the bubble above
	# the measured head.
	var body := RealisticPatron.instance_body(variant)
	if body.node == null:
		push_warning("Villager %s: no body for variant '%s'" % [name, variant_id])
		return
	if body.fallback:
		push_warning("[Villager] fallback: %s is missing, using '%s'" % [variant.get("model_path", ""), body.path])
	_model = body.node
	_model.name = "VillagerModel"
	add_child(_model)
	body_variant = variant
	using_fallback = body.fallback
	body_look = RealisticPatron.dress_body(_model, variant, using_fallback)
	walk_rate = RealisticPatron.clip_rate(variant, "walk_ground_speed", walk_speed, using_fallback)
	var aps := _model.find_children("*", "AnimationPlayer", true, false)
	_anim = aps[0] as AnimationPlayer if not aps.is_empty() else null


## The bubble's lift (parent-local): its scaled text BUBBLE_GAP over the measured standing head, or 0 (the old
## height) on a fallback / unmeasured body.
func bubble_lift() -> float:
	var t = body_variant.get("head_top")
	if using_fallback or not (t is float or t is int) or not is_finite(float(t)):
		return 0.0
	return float(t) + BUBBLE_GAP - BUBBLE_SCRIPT.HEAD_HEIGHT * BUBBLE_SCALE


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return   # time_scale 0: nothing moves, and no 0/0 velocity
	if Engine.get_physics_frames() != _quiet_frame:
		_quiet_frame = Engine.get_physics_frames()
		_quiet_left = maxf(_quiet_left - delta, 0.0)
	if global_position.y < _home.y - FALL_LIMIT:
		global_position = _home   # fell through the ground somehow: back where it started
		velocity = Vector3.ZERO
	var walker := waypoints.size() >= 2
	if not walker and _settled:
		# Standing at a post: once landed, no more physics, so the player walking through can't shove
		# them off it (villagers collide with the player; the player passes through villagers).
		_play("Idle")
		_listen_for_player(delta)
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	var moving := false
	velocity.x = 0.0
	velocity.z = 0.0
	if walker:
		if _pause > 0.0:
			_pause -= delta
		else:
			var here := global_position
			var target := waypoints[_next]
			if Vector2(target.x - here.x, target.z - here.z).length() <= ARRIVE_DIST:
				_next = (_next + 1) % waypoints.size()
				_pause = randf_range(pause_range.x, pause_range.y)
				_stuck = 0.0
			else:
				var step := step_toward(here, target, walk_speed, delta)
				velocity.x = (step.x - here.x) / delta
				velocity.z = (step.z - here.z) / delta
				_face(Vector3(velocity.x, 0.0, velocity.z), delta)
				moving = true
	var before := global_position
	move_and_slide()
	if not walker and is_on_floor():
		_settled = true
	if moving:
		# Blocked (a player standing in the way, a prop): give up on this stop after two seconds.
		_stuck = _stuck + delta if (global_position - before).length() < walk_speed * delta * 0.2 else 0.0
		if _stuck > 2.0:
			_next = (_next + 1) % waypoints.size()
			_stuck = 0.0
	_play("Walking_A" if moving else "Idle")
	_listen_for_player(delta)


func _face(dir: Vector3, delta: float) -> void:
	if _model == null or dir.length() < 0.001:
		return
	var yaw := atan2(dir.x, dir.z) - global_rotation.y   # the model faces +Z; the root may be turned
	_model.rotation.y = lerp_angle(_model.rotation.y, yaw, clampf(delta * 8.0, 0.0, 1.0))


## As RealisticPatron._patron_play_animation: loop the clip on the shared resource, then play it.
## Villagers only use looping clips (Idle, Walking_A), the same way patrons use them.
func _play(anim_name: String) -> void:
	if _anim == null or not _anim.has_animation(anim_name) or _anim.current_animation == anim_name:
		return
	_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_anim.play(anim_name, 0.2, walk_rate if anim_name == "Walking_A" else 1.0)


## Once per half second: when the player is close, and this villager hasn't spoken to them yet on this
## visit, speak when its own cooldown is over, no other villager's bubble is showing and the quiet gap
## after the last one has passed. Leaving the radius resets the visit. Recent lines aren't repeated.
func _listen_for_player(delta: float) -> void:
	_cooldown -= delta
	_listen -= delta
	if _listen > 0.0:
		return
	_listen = 0.5
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := player != null and player.global_position.distance_to(global_position) <= HEAR_RADIUS
	if not near:
		_player_was_near = false
		return
	if _player_was_near or _cooldown > 0.0 or _speaking > 0 or _quiet_left > 0.0:
		return
	var line := pick_bark(_barks(), randf(), randf(), _recent_barks)
	if line == "":
		return
	_recent_barks.append(line)
	while _recent_barks.size() > RECENT_BARKS:
		_recent_barks.pop_front()
	var bubble = BUBBLE_SCRIPT.new()
	bubble.scale = Vector3.ONE * BUBBLE_SCALE
	bubble.position.y = bubble_lift()
	add_child(bubble)
	_speaking += 1
	bubble.tree_exited.connect(_on_bubble_gone)
	bubble.say(line, 4.0)
	_player_was_near = true
	_cooldown = randf_range(bark_cooldown_range.x, bark_cooldown_range.y)


func _on_bubble_gone() -> void:
	_speaking = maxi(_speaking - 1, 0)
	_quiet_left = randf_range(QUIET_GAP.x, QUIET_GAP.y)


static func _barks() -> Dictionary:
	if _barks_cache == null:
		_barks_cache = {}
		var f := FileAccess.open(BARKS_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_barks_cache = parsed
	return _barks_cache


## A register by weight (grievance, mirror, paranoia, in that order), then a line from it that isn't
## in `avoid` (RealisticPatron.fresh_line). Rolls are in [0, 1); "" when there's nothing usable.
static func pick_bark(data: Dictionary, roll_register: float, roll_line: float, avoid: Array = []) -> String:
	var regs = data.get("registers", {})
	if not regs is Dictionary:
		return ""
	var usable := []
	var total := 0.0
	for r in REGISTERS:
		var reg = regs.get(r, {})
		if reg is Dictionary and reg.get("lines", []) is Array and not (reg.get("lines", []) as Array).is_empty():
			var w := maxf(float(reg.get("weight", 0)), 0.0)
			if w > 0.0:
				usable.append([w, reg.lines])
				total += w
	if total <= 0.0:
		return ""
	var x := clampf(roll_register, 0.0, 0.999999) * total
	for u in usable:
		x -= u[0]
		if x < 0.0:
			return RealisticPatron.fresh_line(u[1], avoid, roll_line)
	return ""


## One walking step in XZ: speed × dt toward the target, never past it; y is left to gravity.
static func step_toward(pos: Vector3, target: Vector3, speed: float, dt: float) -> Vector3:
	var flat := Vector2(target.x - pos.x, target.z - pos.z)
	var dist := flat.length()
	var move := minf(speed * dt, dist)
	if dist < 0.00001:
		return pos
	var d := flat / dist * move
	return Vector3(pos.x + d.x, pos.y, pos.z + d.y)
