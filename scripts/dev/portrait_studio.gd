# portrait_studio.gd — the dialogue portrait studio (Story 25.17, DP-1 … DP-5).
#
# Renders each requested speaker's dialogue portrait from data/dialogue/speakers.json's portrait_source and
# writes res://assets/characters/portraits/npc/<id>.png (512 × 512, opaque), then quits. A windowed run (it
# needs the GPU), from the project folder:
#   Godot --path . res://scenes/dev/PortraitStudio.tscn -- ids=den_fa,quest_dealer,bartender
# No ids: every speaker that has a portrait_source. out=<folder> (absolute, or res://): write previews there
# instead (the portraits stay as they are). The whole request is checked before the first write (plan()): an
# unknown argument, id or speaker without a portrait_source, an empty ids= or out=, a relative out=, a bad
# source, a body without the clip, time or bone, a bad or shared portrait path: an error line, nothing written.
# Then import a NEW PNG headless (--headless --import) and make two edits in its .png.import by hand,
# mipmaps/generate=true and detect_3d/compress_to=0 (compress/mode is already 0; DP-5), and import again; a
# re-render of an existing PNG keeps its .import and is re-imported by the editor or the next --import.
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
# by itself: when done, and on any error (exit code 1, a [PortraitStudio] error line). SaveSystem's autosave must
# never fire here, whatever game_config's autosave_interval_seconds says: the save guard (a budget per speaker,
# guard_seconds()) asks the studio to quit, and a watchdog thread kills the process a few seconds later if it is
# still running (the hard stop; a killed process's exit code is the OS's, 0 on Windows: its error line is the
# record). Both come by half the autosave interval. Loaded by path: no class_name.
extends Node3D

const SPEAKERS_PATH := "res://data/dialogue/speakers.json"
const STAFF_PATH := "res://data/characters/staff.json"
const GAME_CONFIG_PATH := "res://data/config/game_config.json"
const ANIME_LOOK := "res://scripts/game/anime_look.gd"
const OUT_SIZE := 512                  # DP-5: the PNG's size
# The save guard: SaveSystem autosaves every autosave_interval_seconds (300 when the config has none; a Timer
# given a value that isn't a positive number keeps its default 1 s). The guard's budget is a base plus a share per
# speaker (a cold run compiles each body's shaders); it never runs past GUARD_SHARE of the autosave interval.
const AUTOSAVE_DEFAULT_SECONDS := 300.0
const TIMER_DEFAULT_SECONDS := 1.0
const GUARD_SHARE := 0.5
const GUARD_BASE_SECONDS := 20.0
const GUARD_PER_SPEAKER_SECONDS := 10.0
const HARD_STOP_GRACE_SECONDS := 5.0   # the save guard asks to quit; the watchdog kills the process this much later
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
const LOOKS := ["", "anime", "realistic"]   # a body's runtime look: its imported materials, or anime_look.gd's (25.31: "realistic" too)

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
var _autosave := AUTOSAVE_DEFAULT_SECONDS
var _guard := Vector2.ZERO     # seconds after start: x the save guard asks to quit, y the watchdog's hard stop
var _watchdog: Thread = null
var _watch_stop := false       # set on leaving the tree: the watchdog returns and is joined


func _ready() -> void:
	# The save guard first, before anything can hang: its budget counts the speakers asked for.
	var args := OS.get_cmdline_user_args()
	var data := _read_json(SPEAKERS_PATH)
	var speakers: Dictionary = data.speakers if data.get("speakers") is Dictionary else {}
	_autosave = autosave_seconds(_read_json(GAME_CONFIG_PATH))
	_guard = guard_seconds(_speaker_count(args, speakers), _autosave)
	_watchdog = Thread.new()
	_watchdog.start(_watch.bind(int(_guard.y * 1000.0)))
	get_tree().create_timer(maxf(_guard.x - Time.get_ticks_msec() / 1000.0, 0.0), true, false, true).timeout.connect(_on_save_guard_timeout)
	_view.size = Vector2i(OUT_SIZE, OUT_SIZE)
	print("[PortraitStudio] renderer: %s; save guard at %.0f s, hard stop at %.0f s (autosave every %.0f s)" % [
		RenderingServer.get_current_rendering_method(), _guard.x, _guard.y, _autosave])
	_run.call_deferred(args)


func _exit_tree() -> void:
	_watch_stop = true
	if _watchdog != null and _watchdog.is_started():
		_watchdog.wait_to_finish()


func _on_save_guard_timeout() -> void:
	var why := "save guard: still running %.0f s after start (SaveSystem autosaves every %.0f s): quitting; the hard stop follows at %.0f s" % [
		Time.get_ticks_msec() / 1000.0, _autosave, _guard.y]
	if _quitting:   # a quit is under way and hasn't finished: the watchdog's hard stop ends it
		push_error("[PortraitStudio] error: %s" % why)
		print("[PortraitStudio] error: %s" % why)
		return
	_fail(why)


## The hard stop, on its own thread (the main loop may be what hangs, so a SceneTree timer can't be the backstop):
## at hard_ms after start it kills the process, whether or not a quit was asked for. Once the studio has left the
## tree the main loop has ended (nothing can autosave any more): the watchdog stops and is joined.
func _watch(hard_ms: int) -> void:
	while not _watch_stop:
		if Time.get_ticks_msec() >= hard_ms:
			var why := "hard stop: still running %.0f s after start, killing the process (SaveSystem's autosave must never fire here)" % (hard_ms / 1000.0)
			push_error("[PortraitStudio] error: %s" % why)
			print("[PortraitStudio] error: %s" % why)
			OS.kill(OS.get_process_id())
			return
		OS.delay_msec(50)


func _run(args: PackedStringArray) -> void:
	var speakers := _read_json(SPEAKERS_PATH)
	var all: Dictionary = speakers.get("speakers", {}) if speakers.get("speakers") is Dictionary else {}
	if all.is_empty():
		_fail("load: %s has no speakers" % SPEAKERS_PATH)
		return
	var p := plan(args, all, _read_json(STAFF_PATH))
	if str(p.error) != "":
		_fail(str(p.error))
		return
	for job in p.jobs:   # every folder before the first render: a folder that can't be made writes nothing
		var dir := str(job.file).get_base_dir()
		var made := DirAccess.make_dir_recursive_absolute(dir)
		if made != OK:
			_fail("%s: can't make the folder %s (error %d)" % [job.id, dir, made])
			return
	var written := PackedStringArray()
	for job in p.jobs:
		if _quitting:
			return
		var ok: bool = await _render(job)
		if not ok or _quitting:
			return
		written.append(str(job.id))
	print("[PortraitStudio] done: %d portrait(s) in %.1f s" % [written.size(), Time.get_ticks_msec() / 1000.0])
	_info.text = "done: %d portrait(s) written (%s) | quitting" % [written.size(), ", ".join(written)]
	_quitting = true
	_quit(0)


## The command line after --: ids=a,b,c (none: every speaker with a portrait_source) and out=<folder> (absolute,
## or res:// / user://, globalized). {ids, all, out, error}; anything else, an empty value, a relative out=, an
## argument given twice or an id named twice is an error.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var ids := PackedStringArray()
	var named := false
	var out := ""
	var has_out := false
	for a in args:
		if a.begins_with("ids="):
			if named:
				return _arg_error("ids= is given twice")
			named = true
			for id in a.trim_prefix("ids=").split(",", false):
				var clean := id.strip_edges()
				if clean == "":
					continue
				if ids.has(clean):
					return _arg_error("'%s' is named twice in ids=" % clean)
				ids.append(clean)
			if ids.is_empty():
				return _arg_error("ids= names no speaker (leave it out to render every speaker with a portrait_source)")
		elif a.begins_with("out="):
			if has_out:
				return _arg_error("out= is given twice")
			has_out = true
			out = a.trim_prefix("out=").strip_edges()
			if out == "":
				return _arg_error("out= names no folder (leave it out to write the portraits themselves)")
			if not out.is_absolute_path():
				return _arg_error("out=%s is a relative folder: give an absolute one (or res://)" % out)
			if out.begins_with("res://") or out.begins_with("user://"):
				out = ProjectSettings.globalize_path(out)
		else:
			return _arg_error("unknown argument '%s' (ids=a,b,c and out=<folder>)" % a)
	return {"ids": ids, "all": not named, "out": out, "error": ""}


static func _arg_error(why: String) -> Dictionary:
	return {"ids": PackedStringArray(), "all": false, "out": "", "error": why}


## The whole request, checked before anything is written: {jobs: [{id, source, body, look, file, shown}], error}.
## Any problem anywhere (an argument, an unknown id or one without a portrait_source, a bad source, a body without
## the clip, time or bone, a bad or shared portrait path) gives an error and no jobs. `speakers` is speakers.json's
## "speakers"; file is the absolute path written, shown the path the wrote line prints.
static func plan(args: PackedStringArray, speakers: Dictionary, staff: Dictionary) -> Dictionary:
	var a := parse_args(args)
	if str(a.error) != "":
		return _refused(str(a.error))
	var ids: PackedStringArray = a.ids
	if a.all:
		for id in speakers:
			if speakers[id] is Dictionary and speakers[id].get("portrait_source") is Dictionary:
				ids.append(id)
		if ids.is_empty():
			return _refused("nothing to render: no speaker has a portrait_source")
	var jobs := []
	var files := {}
	for id in ids:
		var entry = speakers.get(id)
		if not entry is Dictionary:
			return _refused("no speaker '%s' in %s" % [id, SPEAKERS_PATH])
		if not entry.get("portrait_source") is Dictionary:
			return _refused("speaker '%s' has no portrait_source in %s" % [id, SPEAKERS_PATH])
		var src: Dictionary = entry.portrait_source
		var why := source_error(src)
		if why != "":
			return _refused("%s's portrait_source: %s" % [id, why])
		var where := resolve_source(src, staff)
		if str(where.error) != "":
			return _refused("%s: %s" % [id, where.error])
		if not str(where.look) in LOOKS:
			return _refused("%s: unknown look '%s'" % [id, where.look])
		if str(where.look) in ["anime", "realistic"] and not ResourceLoader.exists(ANIME_LOOK):
			return _refused("%s: the anime look %s is missing" % [id, ANIME_LOOK])
		why = body_error(str(where.path), str(src.clip), float(src.get("time", 0.0)), str(src.get("bone", "head")))
		if why != "":
			return _refused("%s: %s" % [id, why])
		var path := str(entry.get("portrait", ""))
		if not path.begins_with("res://") or path.get_extension() != "png" or path.contains(".."):
			return _refused("%s: its portrait path '%s' is not a res:// .png" % [id, path])
		var file := ProjectSettings.globalize_path(path) if str(a.out) == "" else str(a.out).path_join(path.get_file())
		if files.has(file):
			return _refused("%s and %s would both write %s" % [files[file], id, file])
		files[file] = id
		jobs.append({"id": id, "source": src, "body": str(where.path), "look": str(where.look), "file": file,
			"shown": path if str(a.out) == "" else file})
	return {"jobs": jobs, "error": ""}


static func _refused(why: String) -> Dictionary:
	return {"jobs": [], "error": why}


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


## What is wrong with a portrait_source's keys, types and numbers ("" when nothing is). A look goes with a model
## only: a staff variant brings its own (staff.json), so a look next to staff_variant is refused, not overridden.
static func source_error(src: Dictionary) -> String:
	var is_number := func(v): return v is float or v is int
	var unknown := src.keys().filter(func(k): return not k in SOURCE_KEYS)
	if not unknown.is_empty():
		return "unknown keys %s" % [unknown]
	if src.has("model") == src.has("staff_variant"):
		return "needs exactly one of model / staff_variant"
	var body = src.get("model", src.get("staff_variant"))
	if not body is String or (body as String).strip_edges() == "":
		return "model / staff_variant is not a scene path / \"<role>/<variant>\" (%s)" % [body]
	if src.has("staff_variant") and src.has("look"):
		return "a staff variant brings its own look (staff.json): drop look here"
	if src.has("look") and not src.look is String:
		return "look is not a string (%s)" % [src.look]
	if not src.get("clip") is String or str(src.clip) == "":
		return "needs a clip (a name)"
	var time = src.get("time", 0.0)
	if not is_number.call(time) or float(time) < 0.0:
		return "time is not a number ≥ 0 (%s)" % [time]
	if src.has("bone") and (not src.bone is String or str(src.bone) == ""):
		return "bone is not a bone name (%s)" % [src.bone]
	var cam = src.get("camera")
	if not cam is Dictionary:
		return "needs a camera"
	var odd := (cam as Dictionary).keys().filter(func(k): return not k in CAMERA_KEYS)
	if not odd.is_empty():
		return "camera has unknown keys %s" % [odd]
	var missing := CAMERA_KEYS.filter(func(k): return not cam.has(k))
	if not missing.is_empty():
		return "camera lacks %s" % [missing]
	var eye = cam.eye_offset
	if not eye is Array or eye.size() != 3 or not eye.all(is_number):
		return "camera.eye_offset is not [x, y, z]"
	for k in ["head_height", "yaw_deg", "pitch_deg", "fov"]:
		if not is_number.call(cam[k]):
			return "camera.%s is not a number (%s)" % [k, cam[k]]
	if float(cam.head_height) <= 0.05 or float(cam.head_height) > 2.0:
		return "camera.head_height %s out of (0.05, 2] m" % cam.head_height
	if absf(float(cam.yaw_deg)) > 90.0 or absf(float(cam.pitch_deg)) > 45.0 or float(cam.fov) < 5.0 or float(cam.fov) > 60.0:
		return "camera angles out of range (yaw ≤ 90, pitch ≤ 45, fov 5 … 60)"
	return ""


## What is wrong with a body for a portrait ("" when nothing is): a scene that instantiates a Node3D, with an
## AnimationPlayer that has the clip (the time within it) and a Skeleton3D that has the bone.
static func body_error(path: String, clip: String, time: float, bone: String) -> String:
	var scene = load(path) if ResourceLoader.exists(path) else null
	if not scene is PackedScene:
		return "'%s' is not a scene" % path
	var model = (scene as PackedScene).instantiate()
	if not model is Node3D:
		if model is Node:
			(model as Node).free()
		return "'%s' doesn't instantiate a Node3D" % path
	var why := ""
	var players := (model as Node).find_children("*", "AnimationPlayer", true, false)
	var skels := (model as Node).find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or not (players[0] as AnimationPlayer).has_animation(clip):
		why = "no clip '%s' in %s" % [clip, path]
	elif time > (players[0] as AnimationPlayer).get_animation(clip).length:
		why = "time %.2f s is past the end of %s (%.2f s)" % [time, clip, (players[0] as AnimationPlayer).get_animation(clip).length]
	elif skels.is_empty() or (skels[0] as Skeleton3D).find_bone(bone) < 0:
		why = "no bone '%s' in %s" % [bone, path]
	(model as Node).free()
	return why


## SaveSystem's autosave interval as its Timer gets it: game_config's autosave_interval_seconds (300 when it has
## none); a value that isn't a positive number leaves the Timer at its default 1 s.
static func autosave_seconds(config: Dictionary) -> float:
	if not config.has("autosave_interval_seconds"):
		return AUTOSAVE_DEFAULT_SECONDS
	var v = config.autosave_interval_seconds
	var s := float(v) if v is float or v is int or (v is String and (v as String).is_valid_float()) else 0.0
	return s if s > 0.0 else TIMER_DEFAULT_SECONDS


## The save guard's two moments, in seconds after start: x the studio asks to quit, y the watchdog's hard stop.
## The budget is GUARD_BASE_SECONDS plus GUARD_PER_SPEAKER_SECONDS a speaker; the hard stop never comes later than
## GUARD_SHARE of the autosave interval, whatever the config says.
static func guard_seconds(speakers: int, autosave_s: float) -> Vector2:
	var hard := minf(GUARD_BASE_SECONDS + GUARD_PER_SPEAKER_SECONDS * maxi(speakers, 1) + HARD_STOP_GRACE_SECONDS, autosave_s * GUARD_SHARE)
	return Vector2(maxf(hard - HARD_STOP_GRACE_SECONDS, hard * 0.5), hard)


## How many speakers the command line asks for (no ids: every speaker with a portrait_source; at least 1).
static func _speaker_count(args: PackedStringArray, speakers: Dictionary) -> int:
	var a := parse_args(args)
	if str(a.error) == "" and not a.all:
		return (a.ids as PackedStringArray).size()
	return maxi(speakers.values().filter(func(e): return e is Dictionary and e.get("portrait_source") is Dictionary).size(), 1)


## One planned speaker: pose the body, frame it, capture, write the PNG (unless the save guard has fired).
func _render(job: Dictionary) -> bool:
	var id := str(job.id)
	var src: Dictionary = job.source
	for old in _subject_root.get_children():   # the previous speaker's body
		old.free()
	var scene = load(str(job.body))
	if not scene is PackedScene:
		_fail("%s: '%s' is not a scene" % [id, job.body])
		return false
	var model: Node3D = (scene as PackedScene).instantiate() as Node3D
	if model == null:
		_fail("%s: '%s' doesn't instantiate a Node3D" % [id, job.body])
		return false
	_subject_root.add_child(model)
	if str(job.look) in ["anime", "realistic"]:
		var look = load(ANIME_LOOK)
		if not look is Script:
			_fail("%s: the anime look %s doesn't load" % [id, ANIME_LOOK])
			return false
		look.apply(model)

	# The pose: one still frame of the clip (plan() checked the clip, the time and the bone).
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var clip := str(src.clip)
	if players.is_empty() or not (players[0] as AnimationPlayer).has_animation(clip):
		_fail("%s: no clip '%s' in %s" % [id, clip, job.body])
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
		_fail("%s: no bone '%s' in %s" % [id, bone_name, job.body])
		return false
	var skel := skels[0] as Skeleton3D
	var cam: Dictionary = src.camera
	var off: Array = cam.eye_offset
	var eye := (skel.global_transform * skel.get_bone_global_pose(bone)).origin \
		+ model.global_basis * Vector3(float(off[0]), float(off[1]), float(off[2]))
	_frame(eye, float(cam.head_height), float(cam.yaw_deg), float(cam.pitch_deg), float(cam.fov))
	_info.text = "%s | %s | %s %.2f s" % [id, str(job.body).get_file(), clip, float(src.get("time", 0.0))]

	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if _quitting:   # the save guard fired during this render: nothing more is written
		return false
	var img := _view.get_texture().get_image()
	if img == null or img.is_empty():
		_fail("%s: the viewport gave no image" % id)
		return false
	img.convert(Image.FORMAT_RGB8)   # opaque (DP-3: the box's frame is a plain panel)
	if img.get_size() != Vector2i(OUT_SIZE, OUT_SIZE):
		img.resize(OUT_SIZE, OUT_SIZE, Image.INTERPOLATE_LANCZOS)
	var err := img.save_png(str(job.file))
	if err != OK:
		_fail("%s: can't write %s (error %d)" % [id, job.file, err])
		return false
	print("[PortraitStudio] wrote %s (%dx%d)" % [job.shown, img.get_width(), img.get_height()])
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
## of seconds into a run (pipelines still compiling); the watchdog's hard stop stays the backstop.
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
