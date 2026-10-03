# portrait_studio.gd — the dialogue portrait studio (Story 25.17, DP-1 … DP-5).
#
# Renders each requested speaker's dialogue portrait from data/dialogue/speakers.json's portrait_source and
# writes res://assets/characters/portraits/npc/<id>.png (512 × 512, opaque), then quits. A windowed run (it
# needs the GPU), from the project folder:
#   Godot --path . res://scenes/dev/PortraitStudio.tscn -- ids=den_fa,quest_dealer,bartender
# No ids: every speaker that has a portrait_source. out=<folder>: write previews there instead (the portraits
# stay as they are). Then import new PNGs headless (--headless --import); a re-render of an existing PNG is
# re-imported by the editor or the next --import.
#
# The look is the game's: LookDev's copy of MainTavern's render path (the tavern's effective ambient, one
# DirectionalLight, the EdgeQuad ink pass with the game's parameters), the body's runtime look (anime_look.apply
# for a variant or model whose look is "anime", the imported materials otherwise). Two portrait-scale changes:
# the edge pass samples 4 px away (linePixels; 1 in the game) so its ink still reads at the box's 160 px, and the
# one DirectionalLight is an "ink light" from behind the subject (the edge pass darkens a line by how little that
# light faces it, so every outline reads dark). The faces are lit by omni lights: a warm key in front of the face
# (an anime face sits in the toon's light band), a cool fill, a warm rim. A warm opaque backdrop stands behind
# the subject (no floor, no props). The environment's sky is never seen (the backdrop covers it); only metal
# reflects it: Den Fa's mirror mask shows a dark mirror with a tilted warm sweep and the key's glint.
# The framing is one rule for every speaker: the camera aims at the pose's bone plus eye_offset, the frame is
# FRAME_HEADS head heights tall and the eye line sits EYE_LINE from the top.
# A dev scene: the root isn't in "player_scene" (PlayerManager stands down), no autoload lookups, and it quits
# by itself: when done, on any error (exit code 1, a [PortraitStudio] error line) and at AUTO_QUIT_SECONDS at the
# latest (SaveSystem's 300 s autosave must never fire here). Loaded by path: no class_name.
extends Node3D

const SPEAKERS_PATH := "res://data/dialogue/speakers.json"
const STAFF_PATH := "res://data/characters/staff.json"
const ANIME_LOOK := "res://scripts/game/anime_look.gd"
const OUT_SIZE := 512                  # DP-5: the PNG's size
const AUTO_QUIT_SECONDS := 60.0        # save guard: a hard quit long before SaveSystem's 300 s autosave
const FRAME_HEADS := 2.6               # the frame is this many head heights tall (head and shoulders) ...
const EYE_LINE := 0.43                 # ... with the eye line (the mask's centre) this far down from the top
const SETTLE_FRAMES := 6               # frames after posing before the capture (shaders, sky radiance)
const BACKDROP_BEHIND := 3.0           # the backdrop stands this many frame heights behind the eyes
# The rig in camera space (x right, y up, z toward the camera). Key, fill and rim are omni lights placed round
# the eyes (in frame heights; no distance falloff, so every speaker's scale gets the same light). The ink light
# is the scene's one DirectionalLight: the edge pass darkens a line by how little that light faces it, so it
# shines from behind the subject (INK_FROM, a direction) and every outline reads dark.
const KEY_AT := Vector3(0.8, 0.75, 1.5)
const FILL_AT := Vector3(-1.4, -0.2, 0.9)
const RIM_AT := Vector3(-0.9, 0.9, -1.2)
const INK_FROM := Vector3(0.0, 0.3, -1.0)
const SKY_TILT_DEG := 12.0             # the mirror sky's horizon tilts this much across the view (see _frame)
const MIN_RUN_MS := 8000               # 4.4.1 can hang on quit while pipelines still compile: quit no sooner
const SOURCE_KEYS := ["model", "staff_variant", "look", "clip", "time", "bone", "camera"]
const CAMERA_KEYS := ["eye_offset", "head_height", "yaw_deg", "pitch_deg", "fov"]

@onready var _view: SubViewport = %Studio
@onready var _camera: Camera3D = %Camera3D
@onready var _subject_root: Node3D = %Subject
@onready var _key: OmniLight3D = %KeyLight
@onready var _ink: DirectionalLight3D = %InkLight
@onready var _fill: OmniLight3D = %FillLight
@onready var _rim: OmniLight3D = %RimLight
@onready var _backdrop: MeshInstance3D = %Backdrop
@onready var _info: Label = %Info
@onready var _env: Environment = (%WorldEnvironment as WorldEnvironment).environment

var _quitting := false
var _out_dir := ""        # out=<folder> on the command line: a preview written there, the portraits untouched


func _ready() -> void:
	get_tree().create_timer(AUTO_QUIT_SECONDS).timeout.connect(_on_save_guard_timeout)
	_view.size = Vector2i(OUT_SIZE, OUT_SIZE)
	print("[PortraitStudio] renderer: %s" % RenderingServer.get_current_rendering_method())
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out_dir = a.trim_prefix("out=")
	_run.call_deferred()


func _on_save_guard_timeout() -> void:
	_fail("save guard: still running after %d s, quitting before SaveSystem's autosave" % int(AUTO_QUIT_SECONDS))


func _run() -> void:
	var speakers := _read_json(SPEAKERS_PATH)
	var staff := _read_json(STAFF_PATH)
	var all: Dictionary = speakers.get("speakers", {}) if speakers.get("speakers") is Dictionary else {}
	if all.is_empty():
		_fail("load: %s has no speakers" % SPEAKERS_PATH)
		return
	var ids := requested_ids(OS.get_cmdline_user_args())
	if ids.is_empty():
		for id in all:
			if all[id] is Dictionary and all[id].get("portrait_source") is Dictionary:
				ids.append(id)
	if ids.is_empty():
		_fail("nothing to render: no speaker has a portrait_source")
		return
	var written := 0
	for id in ids:
		var entry = all.get(id)
		if not entry is Dictionary or not entry.get("portrait_source") is Dictionary:
			_fail("speaker '%s' has no portrait_source in %s" % [id, SPEAKERS_PATH])
			return
		var ok: bool = await _render(id, entry, staff)
		if not ok or _quitting:
			return
		written += 1
	print("[PortraitStudio] done: %d portrait(s)" % written)
	_info.text = "done: %d portrait(s) written (%s) | quitting" % [written, ", ".join(ids)]
	_quitting = true
	_quit(0)


## The speaker ids asked for on the command line (after --): ids=a,b,c. Empty: none asked (render them all).
static func requested_ids(args: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for a in args:
		if a.begins_with("ids="):
			for id in a.trim_prefix("ids=").split(",", false):
				out.append(id.strip_edges())
	return out


## Where a portrait_source's body comes from: {path, look, error}. model: that scene, its own look key;
## staff_variant "<role>/<variant>": the variant's model_path and look in staff.json (a variant swap re-renders).
static func resolve_source(src: Dictionary, staff: Dictionary) -> Dictionary:
	if src.has("staff_variant"):
		var parts := str(src.staff_variant).split("/")
		var roles: Dictionary = staff.get("roles", {}) if staff.get("roles") is Dictionary else {}
		var role = roles.get(parts[0]) if parts.size() == 2 else null
		var variants = role.get("variants") if role is Dictionary else null
		var v = variants.get(parts[1]) if variants is Dictionary else null
		if not v is Dictionary:
			return {"path": "", "look": "", "error": "staff variant '%s' is not in %s" % [src.staff_variant, STAFF_PATH]}
		var path := str(v.get("model_path", ""))
		if not ResourceLoader.exists(path):
			return {"path": path, "look": str(v.get("look", "")), "error": "staff variant '%s' has no body at '%s'" % [src.staff_variant, path]}
		return {"path": path, "look": str(v.get("look", "")), "error": ""}
	var model := str(src.get("model", ""))
	if model == "" or not ResourceLoader.exists(model):
		return {"path": model, "look": str(src.get("look", "")), "error": "no body at '%s'" % model}
	return {"path": model, "look": str(src.get("look", "")), "error": ""}


## What is wrong with a portrait_source's keys and numbers ("" when nothing is).
static func source_error(src: Dictionary) -> String:
	var unknown := src.keys().filter(func(k): return not k in SOURCE_KEYS)
	if not unknown.is_empty():
		return "unknown keys %s" % [unknown]
	if src.has("model") == src.has("staff_variant"):
		return "needs exactly one of model / staff_variant"
	if str(src.get("clip", "")) == "" or not (src.get("time", 0.0) is float or src.get("time", 0.0) is int) or float(src.get("time", 0.0)) < 0.0:
		return "needs a clip and a time ≥ 0"
	var cam = src.get("camera")
	if not cam is Dictionary:
		return "needs a camera"
	var missing := CAMERA_KEYS.filter(func(k): return not cam.has(k))
	if not missing.is_empty():
		return "camera lacks %s" % [missing]
	var eye = cam.eye_offset
	if not eye is Array or eye.size() != 3 or not eye.all(func(v): return v is float or v is int):
		return "camera.eye_offset is not [x, y, z]"
	if float(cam.head_height) <= 0.05 or float(cam.head_height) > 2.0:
		return "camera.head_height %s out of (0.05, 2] m" % cam.head_height
	if absf(float(cam.yaw_deg)) > 90.0 or absf(float(cam.pitch_deg)) > 45.0 or float(cam.fov) < 5.0 or float(cam.fov) > 60.0:
		return "camera angles out of range (yaw ≤ 90, pitch ≤ 45, fov 5 … 60)"
	return ""


func _render(id: String, entry: Dictionary, staff: Dictionary) -> bool:
	var src: Dictionary = entry.portrait_source
	var spec_error := source_error(src)
	if spec_error != "":
		_fail("%s's portrait_source: %s" % [id, spec_error])
		return false
	var where := resolve_source(src, staff)
	if str(where.error) != "":
		_fail("%s: %s" % [id, where.error])
		return false
	for old in _subject_root.get_children():   # the previous speaker's body
		old.free()
	var scene = load(str(where.path))
	if not scene is PackedScene:
		_fail("%s: '%s' is not a scene" % [id, where.path])
		return false
	var model: Node3D = (scene as PackedScene).instantiate() as Node3D
	if model == null:
		_fail("%s: '%s' doesn't instantiate a Node3D" % [id, where.path])
		return false
	_subject_root.add_child(model)
	if str(where.look) == "anime":
		var look = load(ANIME_LOOK)
		if not look is Script:
			_fail("%s: the anime look %s doesn't load" % [id, ANIME_LOOK])
			return false
		look.apply(model)
	elif str(where.look) != "":
		_fail("%s: unknown look '%s'" % [id, where.look])
		return false

	# The pose: one still frame of the clip.
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var clip := str(src.clip)
	if players.is_empty() or not (players[0] as AnimationPlayer).has_animation(clip):
		_fail("%s: no clip '%s' in %s" % [id, clip, where.path])
		return false
	var anim := players[0] as AnimationPlayer
	anim.play(clip)
	anim.seek(float(src.get("time", 0.0)), true)
	anim.pause()
	await get_tree().process_frame
	await get_tree().process_frame
	var skels := model.find_children("*", "Skeleton3D", true, false)
	var bone_name := str(src.get("bone", "head"))
	var bone := (skels[0] as Skeleton3D).find_bone(bone_name) if not skels.is_empty() else -1
	if bone < 0:
		_fail("%s: no bone '%s' in %s" % [id, bone_name, where.path])
		return false
	var skel := skels[0] as Skeleton3D
	var cam: Dictionary = src.camera
	var off: Array = cam.eye_offset
	var eye := (skel.global_transform * skel.get_bone_global_pose(bone)).origin \
		+ model.global_basis * Vector3(float(off[0]), float(off[1]), float(off[2]))
	_frame(eye, float(cam.head_height), float(cam.yaw_deg), float(cam.pitch_deg), float(cam.fov))
	_info.text = "%s | %s | %s %.2f s" % [id, str(where.path).get_file(), clip, float(src.get("time", 0.0))]

	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := _view.get_texture().get_image()
	if img == null or img.is_empty():
		_fail("%s: the viewport gave no image" % id)
		return false
	img.convert(Image.FORMAT_RGB8)   # opaque (DP-3: the box's frame is a plain panel)
	if img.get_size() != Vector2i(OUT_SIZE, OUT_SIZE):
		img.resize(OUT_SIZE, OUT_SIZE, Image.INTERPOLATE_LANCZOS)
	var path := str(entry.get("portrait", ""))
	if not path.begins_with("res://") or path.get_extension() != "png":
		_fail("%s: its portrait path '%s' is not a res:// .png" % [id, path])
		return false
	var dir := ProjectSettings.globalize_path(path.get_base_dir()) if _out_dir == "" else _out_dir
	var made := DirAccess.make_dir_recursive_absolute(dir)
	if made != OK:
		_fail("%s: can't make the folder %s (error %d)" % [id, dir, made])
		return false
	var file := dir.path_join(path.get_file())
	var err := img.save_png(file)
	if err != OK:
		_fail("%s: can't write %s (error %d)" % [id, file, err])
		return false
	print("[PortraitStudio] wrote %s (%dx%d)" % [path if _out_dir == "" else file, img.get_width(), img.get_height()])
	return true   # the body stays in view until the next speaker's render (or the quit) replaces it


## The one framing rule: the camera looks at the eye line from yaw/pitch round it, far enough for a frame
## FRAME_HEADS head heights tall at the eyes' depth, moved down so the eyes sit EYE_LINE from the top; the
## lights and the backdrop follow the camera.
func _frame(eye: Vector3, head_height: float, yaw_deg: float, pitch_deg: float, fov: float) -> void:
	var frame_h := FRAME_HEADS * head_height
	var dist := frame_h * 0.5 / tan(deg_to_rad(fov) * 0.5)
	var dir := (Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Basis(Vector3.RIGHT, deg_to_rad(-pitch_deg))) * Vector3.BACK
	var cam_basis := Basis.looking_at(-dir, Vector3.UP)
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = fov
	_camera.near = maxf(0.02, dist * 0.2)
	_camera.far = dist + frame_h * (BACKDROP_BEHIND + 2.0)
	_camera.global_transform = Transform3D(cam_basis, eye + dir * dist - cam_basis.y * (0.5 - EYE_LINE) * frame_h)
	# The mirror sky's horizon tilts across the view, so a mask reflects a diagonal sweep (a mirror), not a level band.
	_env.sky_rotation = Basis(cam_basis.z, deg_to_rad(SKY_TILT_DEG)).get_euler()
	_ink.global_transform = Transform3D(Basis.looking_at(-(cam_basis * INK_FROM).normalized(), Vector3.UP), eye)
	for pair in [[_key, KEY_AT], [_fill, FILL_AT], [_rim, RIM_AT]]:
		var light: OmniLight3D = pair[0]
		light.global_position = eye + cam_basis * (pair[1] as Vector3) * frame_h
		light.omni_range = frame_h * 6.0
	# The backdrop fills the view behind the subject (the camera's child: placed in camera space).
	var back := dist + frame_h * BACKDROP_BEHIND
	var h := 2.0 * back * tan(deg_to_rad(fov) * 0.5) * 1.15
	(_backdrop.mesh as QuadMesh).size = Vector2(h, h)
	_backdrop.position = Vector3(0.0, 0.0, -back)


func _fail(why: String) -> void:
	if _quitting:
		return
	_quitting = true
	push_error("[PortraitStudio] error: %s" % why)
	print("[PortraitStudio] error: %s" % why)
	_quit(1)


## Quit with `code`, but no sooner than MIN_RUN_MS after start: Godot 4.4.1 was seen to hang on a quit a couple
## of seconds into a run (pipelines still compiling); the hard quit at AUTO_QUIT_SECONDS stays the backstop.
func _quit(code: int) -> void:
	var wait_ms := MIN_RUN_MS - Time.get_ticks_msec()
	if wait_ms > 0:
		await get_tree().create_timer(wait_ms / 1000.0).timeout
	get_tree().quit(code)


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}
