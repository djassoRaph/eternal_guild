# disturbance_npc.gd — a tavern disturbance's visitor (Story 14.4): the stranger, the drunk, the mourner, the rival's man.
# A townsfolk body by variant id (data/characters/townsfolk.json; the patrons' loader and look: RealisticPatron's statics,
# as villager.gd does). An unknown variant, or one whose body files are missing, takes the patrons' fallback body
# (RealisticPatron.FALLBACK_MODELS[0], flagged using_fallback; code review P14), never another townsperson. He stands
# where the director puts him, idle, carrying his event's key ([day, type, truth]; the director sends him away when it is
# no longer today's, review P7). His talk zone (a 1.2 m sphere, TD-11) is given E by the scene's ZonePromptUI (one E
# owner a frame, Story 25.10): E while it is his emits talk_requested, and the director opens the conversation. leave()
# releases E at once and walks him out to the patrons' exit on the navmesh (a NavigationAgent3D, as patrons walk), freed
# there; not out within leave_timeout seconds, he fades over fade_seconds (TD-6, review P13), then is freed. Built in code
# by disturbance_director.gd (no scene file). No class_name: loaded by path.
extends CharacterBody3D

signal talk_requested(npc: Node)
signal left(npc: Node)

const PATRON_SCRIPT := "res://scripts/npcs/RealisticPatron.gd"
const ZONE_UI := preload("res://scripts/game/ZonePromptUI.gd")
const TALK_RADIUS := 1.2       # TD-11: the talk zone (a sphere at chest height); the spots keep 2.3 m from other E zones
const WALK_SPEED := 1.4        # m/s, a walk out (patrons run at 2.5)
const ARRIVE := 0.6            # this close to the exit counts as out
const COOLDOWN := 1.0          # seconds after a talk before E is his again

var variant_id := "traveller"
var prompt := "Press E - Talk to the stranger"
var exit_point := Vector3(8.7, 0.0, 3.3)
var leave_timeout := 12.0
var fade_seconds := 1.0        # TD-6: not out in time, he fades this long before he goes (0: at once)
var event_key: Array = []      # the director's: [day, type, truth] of the event he stands in for
var pool_override: Array = []  # tests: a townsfolk pool instead of townsfolk.json's
var body_variant: Dictionary = {}
var body_path := ""
var using_fallback := false
var model: Node3D = null
var talk_zone: Area3D = null
var leaving := false
var fading := false
var _anim: AnimationPlayer = null
var _agent: NavigationAgent3D = null
var _ui: Node = null
var _player: Node3D = null
var _leave_left := 0.0
var _walk_rate := 1.0
var _cooldown := 0.0
var _fade_geoms: Array = []


## Set before the node enters the tree (the director): the body's variant id, the prompt, where the exit is.
func setup(variant: String, prompt_text: String, exit_at: Vector3) -> void:
	variant_id = variant
	prompt = prompt_text
	exit_point = exit_at


func _ready() -> void:
	add_to_group("disturbance_npc")
	collision_layer = 0b00000010   # as patrons: the world collides with him, he doesn't block other NPCs
	collision_mask = 0b00000001
	var cap := CollisionShape3D.new()
	cap.shape = CapsuleShape3D.new()
	(cap.shape as CapsuleShape3D).radius = 0.35
	(cap.shape as CapsuleShape3D).height = 1.7
	cap.position = Vector3(0, 0.85, 0)
	add_child(cap)
	_spawn_body()
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.5
	_agent.target_desired_distance = ARRIVE
	_agent.max_speed = WALK_SPEED
	_agent.radius = 0.4
	_agent.height = 1.8
	add_child(_agent)
	talk_zone = Area3D.new()
	talk_zone.name = "TalkZone"
	var zs := CollisionShape3D.new()
	zs.shape = SphereShape3D.new()
	(zs.shape as SphereShape3D).radius = TALK_RADIUS
	zs.position = Vector3(0, 1.0, 0)
	talk_zone.add_child(zs)
	add_child(talk_zone)
	talk_zone.body_entered.connect(_on_body_entered)
	talk_zone.body_exited.connect(_on_body_exited)
	_play("Idle")
	# The hall adds its ZonePromptUI two frames after load: look for it a while (the_cat.gd, den_fa.gd).
	for i in 30:
		if not is_inside_tree() or leaving:
			return
		_ui = ZONE_UI.find(get_tree())
		if _ui:
			_ui.claim(talk_zone, prompt, self)
			return
		await get_tree().process_frame


func _spawn_body() -> void:
	var ps = load(PATRON_SCRIPT)
	var pool: Array = pool_override if not pool_override.is_empty() else ps.townsfolk_pool()
	var variant := {}
	for v in pool:
		if str(v.get("id", "")) == variant_id:
			variant = v
	var fallback_variant := {"id": "fallback", "model_path": str(ps.FALLBACK_MODELS[0])}
	var forced := false
	if variant.is_empty():
		push_warning("[Disturbance] fallback: no townsfolk variant '%s'; the patrons' fallback body" % variant_id)
		variant = fallback_variant
		forced = true
	var body: Dictionary = ps.instance_body(variant)
	if body.node == null and not forced:
		push_warning("[Disturbance] fallback: no body file for variant '%s'; the patrons' fallback body" % variant_id)
		variant = fallback_variant
		forced = true
		body = ps.instance_body(variant)
	if body.node == null:
		push_warning("[Disturbance] missing: no body for variant '%s'" % variant_id)
		return
	model = body.node
	model.name = "VisitorModel"
	add_child(model)
	body_variant = variant
	body_path = str(body.path)
	using_fallback = forced or body.fallback
	ps.dress_body(model, variant, using_fallback)
	_walk_rate = ps.clip_rate(variant, "walk_ground_speed", WALK_SPEED, using_fallback)
	var aps := model.find_children("*", "AnimationPlayer", true, false)
	_anim = aps[0] as AnimationPlayer if not aps.is_empty() else null


func _play(anim_name: String) -> void:
	if _anim == null or not _anim.has_animation(anim_name) or _anim.current_animation == anim_name:
		return
	_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_anim.play(anim_name, 0.2, _walk_rate if anim_name == "Walking_A" else 1.0)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player = body


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player = null


## E is his: the player is in his zone, the ZonePromptUI gives him E (its gate: no dialogue open, no pause, no Game Over,
## no mission screen, no patron waiting in range), and he isn't on his way out.
func can_talk() -> bool:
	if leaving or _cooldown > 0.0 or _player == null or not is_instance_valid(_player) or not is_inside_tree():
		return false
	if _ui != null and is_instance_valid(_ui):
		return _ui.owns_e(talk_zone)
	return get_tree().get_nodes_in_group("dialogue_open").is_empty() and not get_tree().paused


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo() and can_talk():
		get_viewport().set_input_as_handled()
		_cooldown = COOLDOWN
		talk_requested.emit(self)


## The conversation closed: E is his again after the cooldown.
func conversation_over() -> void:
	_cooldown = COOLDOWN


## Walk out: E released at once; the patrons' exit on the navmesh; freed there, or faded and freed after leave_timeout.
func leave() -> void:
	if leaving:
		return
	leaving = true
	_release()
	_leave_left = leave_timeout
	if _agent and is_inside_tree():
		_agent.target_position = exit_point
	_play("Walking_A")


func _release() -> void:
	if _ui != null and is_instance_valid(_ui) and talk_zone != null:
		_ui.release(talk_zone)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if not leaving or fading:
		return
	_leave_left -= delta
	var to := exit_point - global_position
	to.y = 0.0
	if to.length() <= ARRIVE:
		_gone()
		return
	if _leave_left <= 0.0:
		_fade_out()
		return
	var next := _agent.get_next_path_position() if _agent and not _agent.is_navigation_finished() else exit_point
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = to
	dir = dir.normalized()
	velocity = Vector3(dir.x * WALK_SPEED, velocity.y - 9.8 * delta if not is_on_floor() else 0.0, dir.z * WALK_SPEED)
	move_and_slide()
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, 8.0 * delta))


## Not out in time (no path, a blocked way): he stops and fades over fade_seconds (every mesh's transparency), then goes.
func _fade_out() -> void:
	fading = true
	_play("Idle")
	if fade_seconds <= 0.0:
		_gone()
		return
	_fade_geoms = find_children("*", "GeometryInstance3D", true, false)
	var tw := create_tween()
	tw.tween_method(_set_fade, 0.0, 1.0, fade_seconds)
	tw.finished.connect(_gone)


func _set_fade(a: float) -> void:
	for g in _fade_geoms:
		if is_instance_valid(g):
			(g as GeometryInstance3D).transparency = a


func _gone() -> void:
	set_physics_process(false)
	left.emit(self)
	queue_free()


func _exit_tree() -> void:
	_release()
