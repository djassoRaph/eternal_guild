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
const SHARED_COOLDOWN := 8.0    # seconds between any two villager barks, so bubbles never overlap
const ARRIVE_DIST := 0.3
const BUBBLE_SCALE := 1.5       # the town camera is about twice as wide as the tavern's; keep the words readable

@export var variant_id: String = "local"
@export var waypoints: PackedVector3Array = PackedVector3Array()   # world positions (XZ used); empty = stands
@export var walk_speed: float = 1.2
@export var pause_range: Vector2 = Vector2(2.0, 5.0)
@export var bark_cooldown_range: Vector2 = Vector2(25.0, 45.0)

static var _barks_cache = null
static var _last_bark_time := -1000.0

var _model: Node3D = null
var _anim: AnimationPlayer = null
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
	_spawn_model()
	_cooldown = randf_range(3.0, 10.0)   # stagger the first barks
	_pause = randf_range(0.0, pause_range.y)
	_play("Idle")


func _spawn_model() -> void:
	var pool := RealisticPatron.townsfolk_pool()
	var path := ""
	for v in pool:
		if str(v.get("id", "")) == variant_id:
			path = str(v.get("model_path", ""))
	if path == "" and not pool.is_empty():
		path = str(pool[0].get("model_path", ""))   # unknown id: any townsperson rather than nobody
	if path == "" or not ResourceLoader.exists(path):
		push_warning("Villager: no body for variant '%s'" % variant_id)
		return
	_model = (load(path) as PackedScene).instantiate()
	_model.name = "VillagerModel"
	add_child(_model)
	var aps := _model.find_children("*", "AnimationPlayer", true, false)
	_anim = aps[0] as AnimationPlayer if not aps.is_empty() else null


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	var moving := false
	velocity.x = 0.0
	velocity.z = 0.0
	if waypoints.size() >= 2:
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
	var yaw := atan2(dir.x, dir.z) - rotation.y   # the model faces +Z; the root may be turned in the scene
	_model.rotation.y = lerp_angle(_model.rotation.y, yaw, clampf(delta * 8.0, 0.0, 1.0))


## As RealisticPatron._patron_play_animation: loop the clip on the shared resource, then play it.
## Villagers only use looping clips (Idle, Walking_A), the same way patrons use them.
func _play(anim_name: String) -> void:
	if _anim == null or not _anim.has_animation(anim_name) or _anim.current_animation == anim_name:
		return
	_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_anim.play(anim_name, 0.2)


func _listen_for_player(delta: float) -> void:
	_cooldown -= delta
	_listen -= delta
	if _listen > 0.0:
		return
	_listen = 0.5
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := player != null and player.global_position.distance_to(global_position) <= HEAR_RADIUS
	if near and not _player_was_near and _cooldown <= 0.0:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_bark_time >= SHARED_COOLDOWN:
			var line := pick_bark(_barks(), randf(), randf())
			if line != "":
				var bubble = BUBBLE_SCRIPT.new()
				bubble.scale = Vector3.ONE * BUBBLE_SCALE
				add_child(bubble)
				bubble.say(line, 4.0)
				_last_bark_time = now
				_cooldown = randf_range(bark_cooldown_range.x, bark_cooldown_range.y)
	_player_was_near = near


static func _barks() -> Dictionary:
	if _barks_cache == null:
		_barks_cache = {}
		var f := FileAccess.open(BARKS_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_barks_cache = parsed
	return _barks_cache


## A register by weight (grievance, mirror, paranoia, in that order), then a line from it.
## Rolls are in [0, 1); "" when the data has nothing to say.
static func pick_bark(data: Dictionary, roll_register: float, roll_line: float) -> String:
	var regs: Dictionary = data.get("registers", {})
	var total := 0.0
	for r in REGISTERS:
		total += maxf(float(regs.get(r, {}).get("weight", 0)), 0.0)
	if total <= 0.0:
		return ""
	var x := clampf(roll_register, 0.0, 0.999999) * total
	for r in REGISTERS:
		var reg: Dictionary = regs.get(r, {})
		x -= maxf(float(reg.get("weight", 0)), 0.0)
		if x < 0.0:
			var lines: Array = reg.get("lines", [])
			if lines.is_empty():
				return ""
			return str(lines[mini(int(clampf(roll_line, 0.0, 0.999999) * lines.size()), lines.size() - 1)])
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
