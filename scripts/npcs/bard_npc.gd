# bard_npc.gd — the travelling Bard's body in the hall (Epic 9, Stories 9.1/9.2). A tavern visitor like the King's
# messenger: it extends royal_messenger_npc.gd by path (a townsfolk body by variant id with the patrons' loader and look,
# the 1.2 m talk zone given E by the scene's ZonePromptUI, talk_requested, the talk cooldown, the walk in from the porch
# through the front door, then on the navmesh to the wait spot; leave() walks out to the porch, freed there). With
# approach off he never walks up to the player: he waits at the door. His own parts: a PLACEHOLDER lute built from
# primitives (Story 25.12's H9 replaces it; on his back while he walks and waits, in his hands while he plays), a speech
# bubble line (say), and, Story 9.2, the walk to the perform spot and the performance. The hall's controller
# (scripts/game/bard.gd) decides when he comes and what a talk does. Built in code; no class_name: loaded by path.
extends "res://scripts/npcs/royal_messenger_npc.gd"

const LUTE_WOOD := Color(0.42, 0.26, 0.13)
const LUTE_DARK := Color(0.12, 0.07, 0.04)
const BARD_COOLDOWN := 1.0    # after a talk, before E is his again (the visitors' second, not the messenger's three)
const DEFAULT_HEAD_TOP := 1.92

## The lute's poses ({carry: {bone, offset, rotation_deg}, play: {...}, scale}; data/narrative/bard.json). Set before
## the node enters the tree (the controller).
var lute_cfg: Dictionary = {}
var lute: Node3D = null
var lute_pose := ""
var _lute_attach: Node3D = null
## Story 9.2, set by the controller: where and how he plays.
var perform_spot := Vector3.ZERO
var perform_yaw_deg := 90.0
var perform_clip := "Interact"
var indicator_text := "♪"
var music_stream: AudioStream = null
var music_volume_db := -10.0
var perform_walk_timeout := 30.0
## The sign over his head while he plays, and his music (a non-positional player on the Music bus: the hall's 3D world
## is inside a SubViewport with no 3D listener set up).
var indicator: Label3D = null
var music: AudioStreamPlayer = null
var _perform_left := 0.0
var _bob := 0.0
var _clip_warned := false


func _ready() -> void:
	super()   # the body, the agent, the talk zone and its E; group royal_messenger (taken off below)
	remove_from_group("royal_messenger")   # not the King's messenger: his controller and Test 53 count that group
	add_to_group("bard")
	cooldown_seconds = BARD_COOLDOWN
	approach = false
	_build_lute()
	set_lute_pose("carry")


## The prompt his talk zone shows ("Press E - Talk to the Bard" at the door; Story 9.2: "… Listen to the Bard").
func set_prompt(text: String) -> void:
	prompt = text
	if _ui != null and is_instance_valid(_ui) and talk_zone != null and not leaving:
		_ui.claim(talk_zone, text, self)


## Turn to face a point at once (the player, when a conversation opens).
func face_now(at: Vector3) -> void:
	var d := _flat(at - global_position)
	if d.length() > 0.05:
		rotation.y = atan2(d.x, d.z)


## One line in a speech bubble over his head (a leaving line).
func say(line: String, seconds := 3.5) -> void:
	if line == "" or not is_inside_tree():
		return
	for c in get_children():
		if c is PatronSpeechBubble:
			c.queue_free()
	var b := PatronSpeechBubble.new()
	add_child(b)
	b.position.y = head_top() + 0.45 - PatronSpeechBubble.HEAD_HEIGHT
	b.say(line, seconds)


## His body's head top (the variant's head_top, the patrons' number).
func head_top() -> float:
	var h = body_variant.get("head_top")
	return float(h) if (h is float or h is int) and not using_fallback else DEFAULT_HEAD_TOP


# ---------------------------------------------------------------- the performance (Story 9.2)

## Let in: walk (on the navmesh) to the perform spot, then play. Not there after perform_walk_timeout: placed there.
func go_perform() -> void:
	if leaving:
		return
	mode = "to_perform"
	_perform_left = perform_walk_timeout
	_aim(perform_spot)


## He is playing already (a load, the hall re-entered): at the perform spot, playing.
func place_performing() -> void:
	global_position = perform_spot
	_begin_performance()


func is_performing() -> bool:
	return mode == "performing"


func _begin_performance() -> void:
	mode = "performing"
	velocity = Vector3.ZERO
	rotation.y = deg_to_rad(perform_yaw_deg)
	set_lute_pose("play")
	_show_indicator(true)
	_start_music()
	_play_perform_clip()
	print("[Bard] plays at (%.2f, %.2f)" % [global_position.x, global_position.z])


## The playing stops (closing time, the walk out): the music, the sign, the lute back on his back.
func stop_performing() -> void:
	_show_indicator(false)
	_stop_music()
	set_lute_pose("carry")
	if mode in ["to_perform", "performing"]:
		mode = ""


func leave() -> void:
	stop_performing()
	super()


func _play_perform_clip() -> void:
	if _anim == null:
		return
	var clip := perform_clip
	if not _anim.has_animation(clip):
		if not _clip_warned:
			_clip_warned = true
			push_warning("[Bard] fallback: his body has no clip '%s'; he plays Idle" % clip)
		clip = "Idle"
	if _anim.current_animation != clip or not _anim.is_playing():
		_anim.play(clip, 0.2)


func _show_indicator(on: bool) -> void:
	if on and indicator_text != "":
		if indicator == null or not is_instance_valid(indicator):
			indicator = Label3D.new()
			indicator.name = "PlayingSign"
			indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			indicator.no_depth_test = true          # over the ink-outline quad (godot-dev-gotchas: render_priority >= 1)
			indicator.render_priority = 3
			indicator.outline_render_priority = 2
			indicator.font_size = 72
			indicator.outline_size = 14
			indicator.pixel_size = 0.006
			indicator.modulate = Color(1.0, 0.86, 0.45)
			add_child(indicator)
		indicator.text = indicator_text
		indicator.position = Vector3(0.0, head_top() + 0.35, 0.0)
		indicator.visible = true
	elif indicator != null and is_instance_valid(indicator):
		indicator.visible = false


func _start_music() -> void:
	if music_stream == null:
		return
	if music == null or not is_instance_valid(music):
		music = AudioStreamPlayer.new()
		music.name = "BardMusic"
		music.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
		add_child(music)
	music.stream = music_stream
	music.volume_db = music_volume_db
	if not music.playing:
		music.play()


func _stop_music() -> void:
	if music != null and is_instance_valid(music):
		music.stop()


func _physics_process(delta: float) -> void:
	super(delta)
	if leaving or fading:
		return
	match mode:
		"to_perform":
			_perform_left -= delta
			if _flat(perform_spot - global_position).length() <= STEP_ARRIVE:
				_begin_performance()
			elif _perform_left <= 0.0:
				print("[Bard] not at his spot after %.0f s: placed there" % perform_walk_timeout)
				global_position = perform_spot
				_begin_performance()
			else:
				_step_toward(perform_spot, delta)
		"performing":
			_play_perform_clip()
			if indicator != null and is_instance_valid(indicator) and indicator.visible:
				_bob += delta
				indicator.position.y = head_top() + 0.35 + sin(_bob * 3.0) * 0.06


# ---------------------------------------------------------------- the placeholder lute

## A lute from primitives: a pear body (a flattened sphere), a sound hole, the neck and the bent-back head. Its long axis
## is local +Y (the neck up), its face +Z.
func _build_lute() -> void:
	lute = Node3D.new()
	lute.name = "PlaceholderLute"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = LUTE_WOOD
	wood.roughness = 0.75
	var dark := StandardMaterial3D.new()
	dark.albedo_color = LUTE_DARK
	dark.roughness = 0.9
	var body := MeshInstance3D.new()
	body.name = "LuteBody"
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	body.mesh = sm
	body.scale = Vector3(1.0, 1.25, 0.45)
	body.position = Vector3(0.0, -0.12, 0.0)
	body.material_override = wood
	lute.add_child(body)
	var hole := MeshInstance3D.new()
	hole.name = "LuteRose"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.04
	cm.height = 0.006
	hole.mesh = cm
	hole.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	hole.position = Vector3(0.0, -0.06, 0.073)
	hole.material_override = dark
	lute.add_child(hole)
	var neck := MeshInstance3D.new()
	neck.name = "LuteNeck"
	var nb := BoxMesh.new()
	nb.size = Vector3(0.05, 0.36, 0.03)
	neck.mesh = nb
	neck.position = Vector3(0.0, 0.2, 0.0)
	neck.material_override = wood
	lute.add_child(neck)
	var head := MeshInstance3D.new()
	head.name = "LuteHead"
	var hb := BoxMesh.new()
	hb.size = Vector3(0.06, 0.12, 0.03)
	head.mesh = hb
	head.position = Vector3(0.0, 0.42, -0.03)
	head.rotation_degrees = Vector3(-25.0, 0.0, 0.0)
	head.material_override = dark
	lute.add_child(head)
	var s = lute_cfg.get("scale", 1.0)
	if (s is float or s is int) and float(s) > 0.0:
		lute.scale = Vector3.ONE * float(s)


## Put the lute in a pose of lute_cfg ("carry" or "play"): on a BoneAttachment3D of the pose's bone (the body's
## skeleton), at its offset and rotation. No skeleton or no such bone: on him, at the pose's offset above the hips, with
## one warning.
func set_lute_pose(pose: String) -> void:
	if lute == null or pose == lute_pose:
		return
	var p = lute_cfg.get(pose)
	if not (p is Dictionary):
		p = {}
	var bone := str(p.get("bone", "chest"))
	var host: Node3D = null
	var sk: Skeleton3D = null
	if model != null:
		var sks := model.find_children("*", "Skeleton3D", true, false)
		sk = sks[0] as Skeleton3D if not sks.is_empty() else null
	if sk != null and sk.find_bone(bone) >= 0:
		if _lute_attach == null or not is_instance_valid(_lute_attach) or (_lute_attach is BoneAttachment3D and (_lute_attach as BoneAttachment3D).bone_name != bone):
			if _lute_attach != null and is_instance_valid(_lute_attach) and _lute_attach != self:
				_lute_attach.queue_free()
			var ba := BoneAttachment3D.new()
			ba.name = "LuteSlot"
			ba.bone_name = bone
			sk.add_child(ba)
			_lute_attach = ba
		host = _lute_attach
	else:
		push_warning("[Bard] fallback: no bone '%s' on his body; the lute hangs from him" % bone)
		_lute_attach = self
		host = self
	if lute.get_parent() != host:
		if lute.get_parent() != null:
			lute.get_parent().remove_child(lute)
		host.add_child(lute)
	lute.position = _v3_or(p.get("offset"), Vector3.ZERO) + (Vector3(0.0, 1.3, 0.0) if host == self else Vector3.ZERO)
	lute.rotation_degrees = _v3_or(p.get("rotation_deg"), Vector3.ZERO)
	lute_pose = pose


static func _v3_or(v, fallback: Vector3) -> Vector3:
	if v is Array and (v as Array).size() == 3 and (v as Array).all(func(x): return (x is int or x is float) and is_finite(float(x))):
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return fallback
