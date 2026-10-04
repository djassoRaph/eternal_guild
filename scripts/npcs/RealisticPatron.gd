# RealisticPatron.gd - COMPLETE WALKING SYSTEM
extends CharacterBody3D
class_name RealisticPatron

# Movement constants
const SPEED = 2.5
const GRAVITY = 9.8

# Seats and drinks (Story 25.6; re-measured for the realistic cast in Story 25.31 S2.0, R-5). The realistic
# sit clips (REAL-1 and REAL-2, refit_sit for a 0.45 m chair) put the hips 0.397 m behind the character root,
# the seat 0.45 m up and the soles on the floor (KayKit's: 0.40 / 0.44). Every patron_seat marker is a bar stool
# (BarStool.tscn: b2_bar_stool_tall.gltf, seat 0.72 m, seated elbows at the 1.10 m counter top, a foot ring and a
# footrest 0.45 m under the seat), so a patron on a seat marker stands its root on the floor SIT_HIP_BACK in front
# of the seat centre, facing the way the marker's +Z points, and its body rides up SIT_LIFT onto the stool (the
# soles on the footrest). Table spots (no marker) sit at the clip's own 0.45 m with no lift.
const SIT_HIP_BACK := 0.397
const SIT_CLIP_SEAT := 0.45      # the sit clips' seat height (realistic bodies; KayKit's 0.44)
const BAR_STOOL_SEAT := 0.72     # the bar stool's seat_point above the floor
const SIT_SEAT_HEIGHT := BAR_STOOL_SEAT   # a seat marker's height above the floor (seat_root puts the root under it)
const SIT_LIFT := BAR_STOOL_SEAT - SIT_CLIP_SEAT   # 0.27: the body's lift on a stool (its soles on the footrest)
const SIT_LIFT_SECONDS := 0.6    # the lift eases in while Sit_Chair_Down plays (and out with StandUp)
const TANKARD_FULL := "res://assets/environment/custom/h1_tankard_full.gltf"
const TANKARD_EMPTY := "res://assets/environment/custom/h1_tankard_empty.gltf"
const TANKARD_EMPTY_AT := 0.7    # the tankard is empty at 70% of the drinking time
const TANKARD_HELD_SCALE := 1.8  # chunky in the hand, like KayKit's props; true size on the counter

# The body's look (Story 25.31 S2, AC 9/12, V11; AH-16 / Q5): a townsfolk.json entry with look "realistic" (or
# "anime", the same path) takes anime_look.gd's toon look on ITS OWN body; its fallback_model_path (today's KayKit
# body) loads when the model is missing or broken, and keeps its imported look. On its own body: the hand slots'
# props (the old woman's cane) are HIDDEN (R-9 refined: hands empty; shown only when the game needs them), Running_A
# plays at SPEED / run_ground_speed (V9: the clip's measured ground speed on that body, so the feet don't skate at
# the gameplay speed), the held tankard is drawn at the entry's tankard_scale, and the speech bubble and the service
# emote sit above the entry's measured seated head (sit_head_top).
const LOOKS := ["anime", "realistic"]
const ANIME_LOOK := "res://scripts/game/anime_look.gd"
const HAND_SLOTS := ["handslot.l", "handslot.r"]
const BUBBLE_GAP := 0.30         # the speech bubble's text this far above a measured head
const INDICATOR_GAP := 0.38      # the beer emote's centre this far above a measured seated head
const INDICATOR_Y := 2.2         # the emote's height on a body with no measured head (KayKit's)

# State machine (Epic 8 — split the old SITTING_WAITING into SEATED, the pre-service beat, and
# WAITING_SERVICE, once the sitting timer fires and the beer-mug indicator shows. WAITING_SERVICE
# is appended rather than inserted so WALKING_TO_TABLE/SEATED/DRINKING/LEAVING keep their old
# ordinals — old saves' int-encoded `state` field stays valid; see _enter_restored_state()).
enum PatronState {
	WALKING_TO_TABLE,
	SEATED,
	DRINKING,
	LEAVING,
	WAITING_SERVICE
}

# Navigation
var nav_agent: NavigationAgent3D

# State
var current_state = PatronState.WALKING_TO_TABLE
var table_position: Vector3
var entrance_position: Vector3
var table_index: int = -1
var seat_transform = null        # Transform3D of the patron_seat marker, or null at a table spot

# Service
var wants_service = false
var has_been_served = false
var payment_amount: int = 8
var patron_name: String = "Patron"
var patron_origin: String = ""
var patron_origin_type: String = ""   # traveler/local/soldier/trader — keys ambient chatter (Story 8.4)

# Visuals
var service_indicator: Sprite3D
var patron_body_mesh: Node3D       # Set dynamically after model swap
var animation_player: AnimationPlayer = null  # NEW
var current_model_path: String = ""  # remembered so save/restore keeps the same model (the ENTRY's model_path)
var body_variant: Dictionary = {}    # the townsfolk.json entry the body came from ({} for a bare path)
var body_path: String = ""           # the file actually instanced (the fallback's when the model failed)
var using_fallback := false
var body_look := ""                  # the look applied ("" on a fallback or an imported-look body)
var run_rate := 1.0                  # Running_A's playback rate on this body
var tankard_scale := TANKARD_HELD_SCALE

# Patron bodies come from data (Story 25.14): townsfolk variants plus adventurers passing through,
# each with the origin type it belongs to. This list is only the fallback when the file is missing
# or empty (MOD-6).
const TOWNSFOLK_PATH := "res://data/characters/townsfolk.json"
const FALLBACK_MODELS := [
	"res://assets/characters/models/kaykit_adventurers/Mage.glb",
	"res://assets/characters/models/kaykit_adventurers/Rogue.glb",
	"res://assets/characters/models/kaykit_adventurers/Knight.glb",
	"res://assets/characters/models/kaykit_adventurers/Barbarian.glb",
	"res://assets/characters/models/kaykit_adventurers/Rogue_Hooded.glb",
	"res://assets/characters/custom/healer.glb",
	"res://assets/characters/custom/ranger.glb",
]
const FALLBACK_NAMES := ["Gareth", "Elara", "Thorin", "Lydia", "Marcus", "Sera", "Kael", "Mira"]
const FALLBACK_SURNAMES := ["Bold", "Ironforge", "Swiftblade", "Goldbeard", "Stormbringer", "Shadowmend"]

# Where patrons come from; the type keys patron_lines.json (ambient chatter, origin flavours) and
# must match the body they're given.
const ORIGINS := [
	{"label": "the bridge crossroads", "type": "traveler"},
	{"label": "the north road", "type": "traveler"},
	{"label": "the eastern pass", "type": "traveler"},
	{"label": "the forest road", "type": "traveler"},
	{"label": "the merchant caravan", "type": "trader"},
	{"label": "the river docks", "type": "trader"},
	{"label": "the commons", "type": "local"},
	{"label": "the lower district", "type": "local"},
	{"label": "the eastern farms", "type": "local"},
	{"label": "the mill", "type": "local"},
	{"label": "the old keep", "type": "soldier"},
	{"label": "the guard post", "type": "soldier"},
]

static var _townsfolk_doc_cache = null

# Ambient chatter memory: the last few lines said by any patron, so the hall doesn't echo itself.
const RECENT_AMBIENT := 4
static var _recent_ambient: Array = []

# Timers
var sitting_timer: Timer
var drinking_timer: Timer
var empty_timer: Timer           # swaps the full tankard for the empty one

# The H1 tankard in the right hand while drinking (Story 25.6; the drink clip is Story 25.16)
var _tankard: Node3D = null
var _hidden_items: Array = []

# Scene references
var main_scene: Node

# Signals
signal patron_finished(patron: RealisticPatron)
signal wants_to_be_served(patron: RealisticPatron)

func _ready():
	print("RealisticPatron initializing...")
	
	add_to_group("patrons")  # ← ADD THIS LINE
	collision_mask = 0b00000001
	collision_layer = 0b00000010
	print("Patron collision: Layer 2, Mask 1 (no NPC-to-NPC collision)")

	# Swap to a random model before anything else
	_swap_to_random_model()

	# Get NavigationAgent3D
	if has_node("NavigationAgent3D"):
		nav_agent = get_node("NavigationAgent3D")
	else:
		nav_agent = NavigationAgent3D.new()
		nav_agent.name = "NavigationAgent3D"
		add_child(nav_agent)

	# Create service indicator
	create_service_indicator()

	# Create timers
	sitting_timer = Timer.new()
	sitting_timer.name = "SittingTimer"
	sitting_timer.one_shot = true
	add_child(sitting_timer)
	sitting_timer.timeout.connect(on_sitting_timer_timeout)

	drinking_timer = Timer.new()
	drinking_timer.name = "DrinkingTimer"
	drinking_timer.one_shot = true
	add_child(drinking_timer)
	drinking_timer.timeout.connect(on_drinking_timer_timeout)

	empty_timer = Timer.new()
	empty_timer.name = "EmptyTimer"
	empty_timer.one_shot = true
	add_child(empty_timer)
	empty_timer.timeout.connect(_on_tankard_empty)

	# Configure NavigationAgent3D
	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 0.5
		nav_agent.max_speed = SPEED
		nav_agent.radius = 0.4
		nav_agent.height = 1.8
		nav_agent.avoidance_enabled = true
		nav_agent.avoidance_layers = 0b00000010
		nav_agent.avoidance_mask = 0b00000010
		nav_agent.navigation_finished.connect(_on_navigation_finished)

	print("Patron ready")

# =============================================================================
# RANDOM MODEL SWAP
# =============================================================================

func _swap_to_random_model():
	var v := pick_variant(townsfolk_pool(), "", randf())
	_swap_to_model(str(v.get("model_path", FALLBACK_MODELS[0])), v)

## data/characters/townsfolk.json, parsed once ({} when missing or broken).
static func _townsfolk_doc() -> Dictionary:
	if _townsfolk_doc_cache == null:
		_townsfolk_doc_cache = {}
		var f := FileAccess.open(TOWNSFOLK_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_townsfolk_doc_cache = parsed
	return _townsfolk_doc_cache

## The patron and villager bodies: townsfolk.json's variants (entries that aren't objects with a
## model_path are skipped), or the fallback models as plain entries (no origin type, weight 1) when
## the file has none. Copies, so a caller can't change the cached data for everyone else.
static func townsfolk_pool() -> Array:
	var variants = _townsfolk_doc().get("variants", [])
	if variants is Array:
		var good: Array = (variants as Array).filter(func(v): return v is Dictionary and str(v.get("model_path", "")) != "")
		if not good.is_empty():
			return good.map(func(v): return (v as Dictionary).duplicate(true))
	return FALLBACK_MODELS.map(func(p): return {"id": str(p).get_file().get_basename(), "model_path": p, "origin_type": "", "weight": 1.0})

## Weighted pick among the variants of one origin type ("" = the whole pool). An origin type no
## variant covers falls back to the whole pool, so a patron always gets a body; if every weight is
## zero the pick is even. roll is in [0, 1).
static func pick_variant(pool: Array, origin_type: String, roll: float) -> Dictionary:
	var cands := pool.filter(func(v): return origin_type == "" or str(v.get("origin_type", "")) == origin_type)
	if cands.is_empty():
		cands = pool
	if cands.is_empty():
		return {}
	var r := clampf(roll, 0.0, 0.999999)
	var total := 0.0
	for v in cands:
		total += maxf(float(v.get("weight", 1.0)), 0.0)
	if total <= 0.0:
		return cands[mini(int(r * cands.size()), cands.size() - 1)]
	var x := r * total
	for v in cands:
		x -= maxf(float(v.get("weight", 1.0)), 0.0)
		if x < 0.0:
			return v
	return cands[-1]

## A name that fits the body: the variant's pool ("feminine" / "masculine"), or both for "any".
## Missing, empty or malformed pools fall back to the built-in names.
static func pick_name(variant: Dictionary, roll_first: float, roll_last: float) -> String:
	var raw = _townsfolk_doc().get("names", {})
	var pools: Dictionary = raw if raw is Dictionary else {}
	var key := str(variant.get("names", "any"))
	var firsts: Array = []
	for k in (["feminine", "masculine"] if key == "any" else [key]):
		var pool = pools.get(k, [])
		if pool is Array:
			firsts += pool
	if firsts.is_empty():
		firsts = FALLBACK_NAMES
	var lasts_raw = pools.get("surnames", [])
	var lasts: Array = lasts_raw if lasts_raw is Array and not lasts_raw.is_empty() else FALLBACK_SURNAMES
	var i := mini(int(clampf(roll_first, 0.0, 0.999999) * firsts.size()), firsts.size() - 1)
	var j := mini(int(clampf(roll_last, 0.0, 0.999999) * lasts.size()), lasts.size() - 1)
	return "%s %s" % [firsts[i], lasts[j]]

## The pool entry whose model_path is `path` ({} when none: an old save's path, a bare fallback file).
static func variant_of(path: String) -> Dictionary:
	for v in townsfolk_pool():
		if str(v.get("model_path", "")) == path:
			return v
	return {}


## A variant's body, instanced: its model_path, else its fallback_model_path (a missing file or a scene whose root
## is not a Node3D moves on). {"node": Node3D or null, "path": the file used, "fallback": the fallback was used}.
static func instance_body(variant: Dictionary) -> Dictionary:
	var model := str(variant.get("model_path", ""))
	for p in [model, str(variant.get("fallback_model_path", ""))]:
		if p == "":
			continue
		var res = load(p) if ResourceLoader.exists(p) else null
		var inst: Node = (res as PackedScene).instantiate() if res is PackedScene else null
		if inst is Node3D:
			return {"node": inst, "path": p, "fallback": p != model}
		if inst:
			inst.free()
	return {"node": null, "path": "", "fallback": false}


## The look gate on a body just instanced from `variant` (V11): on its own body, look "realistic" / "anime" takes
## anime_look.gd's toon look and the hand-slot props are hidden (R-9 refined); a fallback body keeps its imported
## look and its items (KayKit's). Returns the look applied ("" for none).
static func dress_body(model: Node3D, variant: Dictionary, fallback: bool) -> String:
	if fallback or model == null:
		return ""
	var look := str(variant.get("look", ""))
	if look == "":
		return ""
	if not look in LOOKS:
		push_warning("[Patron] unknown look '%s' for %s; the body keeps its imported look" % [look, variant.get("id", "?")])
		return ""
	for a in hand_props(model):
		(a as Node3D).visible = false
	var look_script = load(ANIME_LOOK) if ResourceLoader.exists(ANIME_LOOK) else null
	if not look_script is Script:
		push_warning("[Patron] missing: the look script %s; the body keeps its imported look" % ANIME_LOOK)
		return ""
	look_script.apply(model)
	return look


## The BoneAttachment3Ds that hang from a hand slot: on the slot itself, or on an item bone whose parent is one (the
## glTF import gives a bone-parented prop an item bone of its own, KayKit's way: the old woman's cane is
## OldWoman_Cane <- handslot.r).
static func hand_props(model: Node) -> Array:
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return []
	var sk := sks[0] as Skeleton3D
	var out := []
	for a in model.find_children("*", "BoneAttachment3D", true, false):
		var b := sk.find_bone(str((a as BoneAttachment3D).bone_name))
		if b < 0:
			continue
		var par := sk.get_bone_parent(b)
		if sk.get_bone_name(b) in HAND_SLOTS or (par >= 0 and sk.get_bone_name(par) in HAND_SLOTS):
			out.append(a)
	return out


## A clip's playback rate on a variant's own body: gameplay speed / the clip's measured ground speed (V9), 1.0 on a
## fallback body or without a measurement.
static func clip_rate(variant: Dictionary, key: String, speed: float, fallback: bool) -> float:
	var g = variant.get(key)
	if fallback or not (g is float or g is int) or not is_finite(float(g)) or float(g) <= 0.0:
		return 1.0
	return speed / float(g)


func _swap_to_model(model_path: String, variant: Dictionary = {}) -> void:
	"""Load a specific model, replacing any current one. Used for random spawn AND save-restore. The variant (its
	pool entry; looked up by model_path when not given) brings the fallback, the look and the measured numbers."""
	if variant.is_empty():
		variant = variant_of(model_path)
	if variant.is_empty():
		variant = {"model_path": model_path}
	# Load first: a bad path keeps the current body rather than leaving an invisible patron.
	var body := instance_body(variant)
	if body.node == null:
		push_warning("RealisticPatron: Could not load model: " + model_path)
		return
	if body.fallback:
		push_warning("[Patron] fallback: %s is missing, using '%s'" % [model_path, body.path])
	# Remove the existing model (the .tscn's built-in one on first call, or a prior PatronModel
	# on restore). Never remove the service indicator, timers, collision, or nav agent.
	for child in get_children():
		if child is Node3D and not (child is CollisionShape3D) and not (child is NavigationAgent3D) and child != service_indicator:
			child.queue_free()

	current_model_path = model_path
	body_variant = variant
	body_path = body.path
	using_fallback = body.fallback
	patron_body_mesh = body.node
	patron_body_mesh.name = "PatronModel"
	add_child(patron_body_mesh)
	body_look = dress_body(patron_body_mesh, variant, using_fallback)
	run_rate = clip_rate(variant, "run_ground_speed", SPEED, using_fallback)
	var ts = variant.get("tankard_scale")
	tankard_scale = float(ts) if not using_fallback and (ts is float or ts is int) and float(ts) > 0.0 else TANKARD_HELD_SCALE
	print("Patron model: ", body_path.get_file())

	# Find AnimationPlayer inside the loaded model
	animation_player = _find_animation_player(patron_body_mesh)
	if animation_player:
		_patron_play_animation("Idle")
	else:
		push_warning("RealisticPatron: No AnimationPlayer in " + model_path.get_file())

func _find_animation_player(node: Node) -> AnimationPlayer:
	"""Recursively search for AnimationPlayer in model"""
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
	return null

# =============================================================================
# PATRON ANIMATIONS
# =============================================================================

func _patron_play_animation(anim_name: String, loop: bool = true) -> void:
	if not animation_player:
		return
	if not animation_player.has_animation(anim_name):
		return  # Silently skip — not all models have all animations
	if animation_player.current_animation == anim_name:
		return

	var anim = animation_player.get_animation(anim_name)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE

	animation_player.play(anim_name, 0.2, run_rate if anim_name == "Running_A" else 1.0)

# =============================================================================
# PHYSICS & MOVEMENT
# =============================================================================

func _physics_process(delta: float):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0

	match current_state:
		PatronState.WALKING_TO_TABLE, PatronState.LEAVING:
			_navigate_with_agent(delta)
		PatronState.SEATED, PatronState.WAITING_SERVICE, PatronState.DRINKING:
			velocity.x = 0
			velocity.z = 0

	move_and_slide()

	if service_indicator and service_indicator.visible:
		var time = Time.get_ticks_msec() / 1000.0
		service_indicator.position.y = seated_head_height(INDICATOR_GAP, INDICATOR_Y) + sin(time * 3.0) * 0.15

## Height above the patron's origin `gap` over its seated head: the entry's measured sit_head_top (+ SIT_LIFT on a
## stool), or `default` on a fallback body / an entry with no measurement.
func seated_head_height(gap: float, default: float) -> float:
	var t = body_variant.get("sit_head_top")
	if using_fallback or not (t is float or t is int) or not is_finite(float(t)):
		return default
	return float(t) + (SIT_LIFT if seat_transform != null else 0.0) + gap


func _navigate_with_agent(delta: float):
	if not nav_agent:
		return

	if nav_agent.is_navigation_finished():
		velocity.x = 0
		velocity.z = 0
		_patron_play_animation("Idle")
		return

	var next_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_position)
	direction.y = 0

	if direction.length() > 0.01:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED

		if patron_body_mesh:
			var target_rotation = atan2(direction.x, direction.z)
			patron_body_mesh.rotation.y = lerp_angle(patron_body_mesh.rotation.y, target_rotation, delta * 8.0)

		_patron_play_animation("Running_A")

func _on_navigation_finished():
	match current_state:
		PatronState.WALKING_TO_TABLE:
			_arrive_at_table()
		PatronState.LEAVING:
			_leave_tavern()

func _arrive_at_table():
	print("", patron_name, " arrived at table ", table_index)
	current_state = PatronState.SEATED
	if seat_transform != null:
		_settle_on_seat(true)

	# Real sit-down transition (KayKit models all carry Sit_Chair_Down/Idle). Fire-and-forget —
	# NOT awaited here. An earlier version awaited animation_player.animation_finished directly
	# in this function and it hung in real gameplay (never reproduced in isolated headless
	# tests — only caught by actually playing), permanently stranding every patron in SEATED.
	# The sitting timer must not depend on the animation completing.
	_play_sit_down_then_idle()

	sitting_timer.wait_time = randf_range(2.0, 5.0)
	sitting_timer.start()

const _SIT_DOWN_SECONDS := 0.85  # measured Sit_Chair_Down length (0.8s) + a small safety margin

func _play_sit_down_then_idle() -> void:
	# Timer-based, not animation_player.animation_finished — that signal proved unreliable in
	# real gameplay (see _arrive_at_table()'s comment). A plain SceneTree timer is the same
	# mechanism _start_ambient_chatter() already uses successfully elsewhere in this file.
	if animation_player and animation_player.has_animation("Sit_Chair_Down"):
		_patron_play_animation("Sit_Chair_Down", false)
		await get_tree().create_timer(_SIT_DOWN_SECONDS).timeout
		if current_state != PatronState.SEATED and current_state != PatronState.WAITING_SERVICE:
			return  # served/interrupted while sitting down — don't stomp whatever's playing now
	_patron_play_animation("Sit_Chair_Idle")

func _leave_tavern():
	print("", patron_name, " reached the exit and is leaving")
	patron_finished.emit(self)

# =============================================================================
# SEATS (Story 25.6)
# =============================================================================

## Where the patron's root stands to sit on a seat marker: 0.40 m in front of the seat centre
## (along the marker's +Z, the sitter's facing), on the floor under the seat.
static func seat_root(seat: Transform3D) -> Vector3:
	var f := seat.basis.z
	f.y = 0.0
	f = f.normalized()
	var p := seat.origin + f * SIT_HIP_BACK
	p.y = seat.origin.y - SIT_SEAT_HEIGHT
	return p

func _settle_on_seat(animate: bool) -> void:
	"""Slide onto the seat's root spot and face the way the seat faces (e.g. a bar stool → the bar)."""
	var target := seat_root(seat_transform)
	var dest := Vector3(target.x, global_position.y, target.z)
	var f: Vector3 = seat_transform.basis.z
	if patron_body_mesh:
		patron_body_mesh.rotation.y = atan2(f.x, f.z)
		if animate:
			create_tween().tween_property(patron_body_mesh, "position:y", SIT_LIFT, SIT_LIFT_SECONDS) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			patron_body_mesh.position.y = SIT_LIFT
	if animate:
		create_tween().tween_property(self, "global_position", dest, 0.25)
	else:
		global_position = dest

# =============================================================================
# THE TANKARD (Story 25.6)
# =============================================================================

func _hold_tankard(full: bool) -> void:
	"""Put an H1 tankard (full or empty) in the right hand, hiding the model's right-hand items."""
	_drop_tankard()
	if not patron_body_mesh:
		return
	var skels := patron_body_mesh.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	var skel := skels[0] as Skeleton3D
	var slot := skel.find_bone("handslot.r")
	if slot < 0:
		return
	for a in patron_body_mesh.find_children("*", "BoneAttachment3D", true, false):
		# KayKit's items hang on child bones of handslot.r, and so do route RL's props: the glTF import gives a
		# bone-parented prop an item bone of its own under the slot (OldWoman_Cane <- handslot.r); b == slot catches an
		# attachment on the slot itself (the outgoing TankardSlot)
		var b := skel.find_bone((a as BoneAttachment3D).bone_name)
		if b >= 0 and (b == slot or skel.get_bone_parent(b) == slot) and (a as Node3D).visible:
			(a as Node3D).visible = false
			_hidden_items.append(a)
	var att := BoneAttachment3D.new()
	att.name = "TankardSlot"
	att.bone_name = "handslot.r"
	skel.add_child(att)
	var scene := load(TANKARD_FULL if full else TANKARD_EMPTY) as PackedScene
	if scene:
		var mug := scene.instantiate() as Node3D
		att.add_child(mug)
		_stand_tankard_upright(mug)
	_tankard = att

func _stand_tankard_upright(mug, frames_left := 2) -> void:
	"""The hand bone is tilted in the sit pose; once the attachment has followed the bone, turn the
	tankard upright in the patron's own frame (it then rides the hand with that offset).
	Waits through one-shot process_frame connections, not awaits: a patron freed or taken out of the
	tree meanwhile just drops out (the awaits used to call get_tree() on a null tree)."""
	if not is_inside_tree():
		return
	if frames_left > 0:
		get_tree().process_frame.connect(_stand_tankard_upright.bind(mug, frames_left - 1), CONNECT_ONE_SHOT)
		return
	if is_instance_valid(mug) and (mug as Node3D).is_inside_tree() and patron_body_mesh:
		(mug as Node3D).global_basis = Basis(patron_body_mesh.global_basis.get_rotation_quaternion()).scaled(Vector3.ONE * tankard_scale)

func _on_tankard_empty() -> void:
	if current_state == PatronState.DRINKING:
		_hold_tankard(false)

func _drop_tankard() -> void:
	if _tankard and is_instance_valid(_tankard):
		_tankard.queue_free()
	_tankard = null
	for a in _hidden_items:
		if is_instance_valid(a):
			(a as Node3D).visible = true
	_hidden_items.clear()

# =============================================================================
# SERVICE SYSTEM
# =============================================================================

func can_be_served_by(player_position: Vector3) -> bool:
	if current_state != PatronState.WAITING_SERVICE:
		return false
	if has_been_served:
		return false
	var distance = global_position.distance_to(player_position)
	return distance <= 3.0

func serve_patron():
	if current_state != PatronState.WAITING_SERVICE:
		print("Patron is not waiting for service.")
		return false

	if not GameManager.consume_beer_pints(1):
		print("Out of beer!")
		return false

	sitting_timer.stop()
	service_indicator.visible = false
	has_been_served = true
	wants_service = false

	current_state = PatronState.DRINKING
	drinking_timer.wait_time = randf_range(8.0, 15.0)
	drinking_timer.start()
	_hold_tankard(true)
	empty_timer.wait_time = drinking_timer.wait_time * TANKARD_EMPTY_AT
	empty_timer.start()

	print("", patron_name, " is now drinking")
	_play_cheer_then_settle()  # fire-and-forget, same pattern as the chatter call below
	_start_ambient_chatter()  # Story 8.4 — a floating one-liner while they drink
	return true

const _CHEER_SECONDS := 1.72  # measured Cheer length (1.667s) + a small safety margin

func _play_cheer_then_settle() -> void:
	# Not awaited by serve_patron() — player.gd reads serve_patron()'s bool return synchronously,
	# so this has to run as its own fire-and-forget coroutine rather than inline. Timer-based,
	# not animation_player.animation_finished — see _arrive_at_table()'s comment for why.
	if animation_player and animation_player.has_animation("Cheer"):
		_patron_play_animation("Cheer", false)
		await get_tree().create_timer(_CHEER_SECONDS).timeout
		if current_state != PatronState.DRINKING:
			return  # already moved on (e.g. left) — don't stomp whatever's playing now
	_patron_play_animation("Sit_Chair_Idle")

# =============================================================================
# TIMER CALLBACKS
# =============================================================================

func on_sitting_timer_timeout():
	if current_state == PatronState.SEATED and not has_been_served:
		current_state = PatronState.WAITING_SERVICE
		wants_service = true
		service_indicator.visible = true
		wants_to_be_served.emit(self)
		print("", patron_name, " wants service!")

func on_drinking_timer_timeout():
	if current_state == PatronState.DRINKING:
		print("", patron_name, " finished drinking. Pays ", payment_amount, "g")
		GameManager.add_gold(payment_amount)

		# Coin-burst juice at the patron (Story 3.4 visual reward + SFX)
		var coin_burst = preload("res://scripts/fx/coin_reward.gd").new()
		var burst_host = get_parent()
		if burst_host:
			burst_host.add_child(coin_burst)
			coin_burst.global_position = global_position + Vector3(0, 1.5, 0)
			coin_burst.burst()

		var origin_note = " (from " + patron_origin + ")" if patron_origin != "" else ""
		GameManager.log_message("• " + patron_name + origin_note + " finished drinking. Pays " + str(payment_amount) + " gold")

		# Real stand-up transition before walking to the exit. Still DRINKING (stationary) while
		# it plays — current_state only flips to LEAVING once they're actually back on their feet.
		# Timer-based, not animation_player.animation_finished — see _arrive_at_table()'s comment
		# for why: that signal hung in real gameplay when awaited directly in a function like
		# this one, which — unlike the fire-and-forget helpers — genuinely needs to block the
		# state transition until the animation is done.
		if animation_player and animation_player.has_animation("Sit_Chair_StandUp"):
			_patron_play_animation("Sit_Chair_StandUp", false)
			if patron_body_mesh and patron_body_mesh.position.y > 0.0:   # down off the stool while standing up
				create_tween().tween_property(patron_body_mesh, "position:y", 0.0, SIT_LIFT_SECONDS) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			await get_tree().create_timer(_SIT_DOWN_SECONDS).timeout  # StandUp measures the same 0.8s as Sit_Chair_Down

		_drop_tankard()
		if patron_body_mesh:
			patron_body_mesh.position.y = 0.0
		current_state = PatronState.LEAVING

		await get_tree().process_frame
		if nav_agent:
			nav_agent.target_position = entrance_position
			print("", patron_name, " is walking to exit at ", entrance_position)
		else:
			_leave_tavern()

# =============================================================================
# AMBIENT CHATTER (Story 8.4)
# =============================================================================

func _start_ambient_chatter() -> void:
	# After a short beat, float one ambient line above the patron's head. Fire-and-forget:
	# called without await so it never blocks the serve path.
	await get_tree().create_timer(randf_range(1.5, 3.0)).timeout
	if current_state != PatronState.DRINKING:
		return  # left or got interrupted — skip
	var line := _pick_ambient_line()
	if line == "" or line == "...":
		return
	# preload by path (like coin_reward) so this compiles even before the editor scans the
	# new script into the global class registry.
	var bubble_script := preload("res://scripts/fx/patron_speech_bubble.gd")
	var bubble = bubble_script.new()
	var hh := float(bubble_script.HEAD_HEIGHT)
	bubble.position.y = seated_head_height(BUBBLE_GAP, hh) - hh   # above a measured seated head (25.31 S2)
	add_child(bubble)  # child of the patron, so it rides along and cleans up with them
	bubble.say(line)

func _pick_ambient_line() -> String:
	# Data-driven (MOD-2): lines live in data/dialogue/patron_lines.json under "ambient",
	# keyed by origin type, with a "default" fallback. The last few lines said in the hall aren't
	# repeated (village-life playtest, 2026-09-25: one line came up four times in 150 s).
	if DataManager == null:
		return ""
	var ctx := patron_origin_type if patron_origin_type != "" else "default"
	var amb = DataManager.dialogue_lines.get("ambient", {})
	var lines: Array = amb.get(ctx, []) if amb is Dictionary else []
	if lines.is_empty() and amb is Dictionary:
		lines = amb.get("default", [])
	var line := fresh_line(lines, _recent_ambient, randf())
	if line != "":
		_recent_ambient.append(line)
		while _recent_ambient.size() > RECENT_AMBIENT:
			_recent_ambient.pop_front()
	return line

## A line that wasn't said recently: start at the rolled line and step on past recent ones; if every
## line is recent, the rolled one ("" when there are none). Shared with villagers' barks.
static func fresh_line(lines: Array, recent: Array, roll: float) -> String:
	if lines.is_empty():
		return ""
	var start := mini(int(clampf(roll, 0.0, 0.999999) * lines.size()), lines.size() - 1)
	for k in lines.size():
		var candidate := str(lines[(start + k) % lines.size()])
		if not candidate in recent:
			return candidate
	return str(lines[start])

# =============================================================================
# INITIALIZATION
# =============================================================================

func create_service_indicator():
	# A little billboarded beer emote above the head instead of a raw yellow sphere.
	service_indicator = Sprite3D.new()
	service_indicator.name = "ServiceIndicator"
	service_indicator.texture = _get_service_emote_texture()
	service_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	service_indicator.no_depth_test = true
	service_indicator.pixel_size = 0.006
	service_indicator.position = Vector3(0, 2.2, 0)
	service_indicator.visible = false
	add_child(service_indicator)

static var _emote_tex: Texture2D = null

static func _get_service_emote_texture() -> Texture2D:
	# Draw a beer mug inside a parchment bubble once, then reuse for every patron.
	if _emote_tex:
		return _emote_tex
	var s := 96
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cream := Color(0.98, 0.93, 0.85)
	var border := Color(0.94, 0.62, 0.15)
	var mug := Color(0.72, 0.40, 0.12)
	var foam := Color(0.98, 0.96, 0.90)
	var c := s / 2.0
	var r := s * 0.46
	for y in s:
		for x in s:
			var d := Vector2(x - c, y - c).length()
			if d <= r:
				img.set_pixel(x, y, border if d > r - 3.0 else cream)
	var bx0 := int(s * 0.34); var bx1 := int(s * 0.58)
	var by0 := int(s * 0.36); var by1 := int(s * 0.70)
	for y in range(by0, by1):
		for x in range(bx0, bx1):
			img.set_pixel(x, y, mug)
	for y in range(int(s * 0.29), by0 + 3):
		for x in range(bx0 - 1, bx1 + 1):
			img.set_pixel(x, y, foam)
	var hx0 := bx1; var hx1 := int(s * 0.70)
	var hy0 := int(s * 0.46); var hy1 := int(s * 0.62)
	for y in range(hy0, hy1):
		for x in range(hx0, hx1):
			if x == hx0 or x == hx1 - 1 or y == hy0 or y == hy1 - 1:
				img.set_pixel(x, y, mug)
	_emote_tex = ImageTexture.create_from_image(img)
	return _emote_tex

# =============================================================================
# SAVE / RESTORE (exact patron restore on load)
# =============================================================================

func to_save() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"state": current_state,
		"table_index": table_index,
		"name": patron_name,
		"origin": patron_origin,
		"origin_type": patron_origin_type,
		"payment": payment_amount,
		"has_been_served": has_been_served,
		"wants_service": wants_service,
		"model_path": current_model_path,
	}

func restore_from_save(save: Dictionary, table_pos: Vector3, entrance: Vector3, idx: int, seat = null) -> void:
	table_position = table_pos
	entrance_position = entrance
	table_index = idx
	seat_transform = seat
	patron_name = save.get("name", patron_name)
	patron_origin = save.get("origin", "")
	patron_origin_type = save.get("origin_type", "")
	payment_amount = int(save.get("payment", 8))
	has_been_served = save.get("has_been_served", false)

	var mp: String = save.get("model_path", "")
	var v := variant_of(mp) if mp != "" else {}
	if v.is_empty():
		# Saves from before model_path, a body since removed, or a body no longer in the pool (AH-7: the KayKit
		# townsfolk GLBs stay on disk as fallbacks, so "missing" isn't enough): a body of the saved origin type,
		# so a patron from the old keep still looks like a guard.
		v = pick_variant(townsfolk_pool(), patron_origin_type, randf())
		mp = str(v.get("model_path", ""))
	if mp != "" and mp != current_model_path:
		_swap_to_model(mp, v)

	var pos = save.get("position", [])
	if pos is Array and pos.size() == 3:
		global_position = Vector3(pos[0], pos[1], pos[2])

	_enter_restored_state(int(save.get("state", PatronState.SEATED)), save)

func _enter_restored_state(st: int, save: Dictionary) -> void:
	current_state = st
	if seat_transform != null and st in [PatronState.SEATED, PatronState.WAITING_SERVICE, PatronState.DRINKING]:
		_settle_on_seat(false)
	match st:
		PatronState.DRINKING:
			# Snap straight into the seated pose on restore — no transition animation needed,
			# they were already sitting when the save was made.
			_patron_play_animation("Sit_Chair_Idle")
			drinking_timer.wait_time = randf_range(8.0, 15.0)
			drinking_timer.start()
			_hold_tankard(true)
			empty_timer.wait_time = drinking_timer.wait_time * TANKARD_EMPTY_AT
			empty_timer.start()
		PatronState.SEATED:
			_patron_play_animation("Sit_Chair_Idle")
			if save.get("wants_service", false):
				# Old saves (pre-Epic-8 granularity) parked a "wants service" patron under this
				# same ordinal — honour the flag and promote straight to WAITING_SERVICE.
				current_state = PatronState.WAITING_SERVICE
				wants_service = true
				if service_indicator:
					service_indicator.visible = true
			else:
				sitting_timer.wait_time = randf_range(2.0, 5.0)
				sitting_timer.start()
		PatronState.WAITING_SERVICE:
			_patron_play_animation("Sit_Chair_Idle")
			wants_service = true
			if service_indicator:
				service_indicator.visible = true
		PatronState.WALKING_TO_TABLE:
			if nav_agent:
				nav_agent.target_position = table_position
		PatronState.LEAVING:
			if nav_agent:
				nav_agent.target_position = entrance_position

func setup_for_table(target_table: Vector3, entrance: Vector3, idx: int, seat = null):
	table_position = target_table
	entrance_position = entrance
	table_index = idx
	seat_transform = seat

	payment_amount = randi_range(6, 12)

	# Story 25.14: the body first (weighted: ~80% townsfolk, the rest adventurers passing through),
	# then an origin of the same type, so the guard is from the keep and the merchant from the docks,
	# and a name that fits the body.
	var variant := pick_variant(townsfolk_pool(), "", randf())
	var mp := str(variant.get("model_path", ""))
	if mp != "" and mp != current_model_path:
		_swap_to_model(mp, variant)
	var otype := str(variant.get("origin_type", ""))
	var labels := ORIGINS.filter(func(o): return o.type == otype)
	if labels.is_empty():
		labels = ORIGINS
	var picked: Dictionary = labels[randi() % labels.size()]
	patron_origin = picked["label"]
	patron_origin_type = picked["type"]
	patron_name = pick_name(variant, randf(), randf())
	print("", patron_name, " is from ", patron_origin, " (", patron_origin_type, ")")

	await get_tree().create_timer(0.1).timeout
	if nav_agent:
		nav_agent.target_position = table_position
		print("", patron_name, " walking to table ", table_index, " at ", table_position)
