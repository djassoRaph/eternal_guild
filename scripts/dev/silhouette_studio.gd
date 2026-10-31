# silhouette_studio.gd — the class silhouettes for the Tarot cards (Story 4.2, decision D-1, DH-6).
#
# Renders each requested class's silhouette from its realistic body (data/characters/classes.json model_path, else its
# fallback_model_path) and writes it where data/config/tarot_card.json's "silhouettes" says: a white figure on a
# transparent background, which the card tints (silhouette_tint). A windowed run (it needs the GPU), from the project:
#   Godot --path . res://scenes/dev/SilhouetteStudio.tscn -- classes=all
#   (or classes=Fighter,Mage; out=<absolute folder> writes previews there instead; sheet=<absolute .png> also writes
#   a contact sheet of the six, tinted, on the card's field colour). Then import new PNGs: Godot --headless --import.
# How: the pose is tarot_card.json's silhouette_render (clip, time; yaw_deg turns the body for a 3/4 view; per-class
# overrides), carried items as imported (shown: decision R-9 refined lists portraits and Tarot among the places the
# game shows them), every mesh drawn unshaded white over black in a 1024 x 1024 SubViewport with MSAA and an
# orthographic camera. The red channel becomes the alpha; the figure is cropped to its used rect and fitted into the
# configured size with the margin, centred, feet on the bottom margin. A figure that touches the render's edge is an
# error (it was cut off). The whole request is checked before the first render; any failure prints a
# [SilhouetteStudio] error line and quits with code 1.
# A dev scene: the root isn't in "player_scene", no autoload is named here, and it quits by itself. SaveSystem's
# autosave must never fire here: the save guard and the watchdog's hard stop come from portrait_studio.gd's statics
# (one rule), well before half the autosave interval. Loaded by path: no class_name.
extends Node3D

const CLASSES_PATH := "res://data/characters/classes.json"
const CARD_PATH := "res://data/config/tarot_card.json"
const CLASS_COLORS_PATH := "res://data/config/class_colors.json"
const GAME_CONFIG_PATH := "res://data/config/game_config.json"
const PORTRAIT_STUDIO := "res://scripts/dev/portrait_studio.gd"   # autosave_seconds() / guard_seconds(): one save-guard rule
const RENDER_SIZE := 1024
const ORTHO_SIZE := 3.0            # metres tall in view: a 1.86 m body with a raised staff fits with room
const VIEW_CENTER_Y := 1.25        # the camera looks at this height (the view spans about -0.25 .. 2.75 m)
const SETTLE_FRAMES := 6
const MIN_RUN_MS := 8000           # as the portrait studio: 4.4.1 can hang on a quit while pipelines still compile

@onready var _view: SubViewport = %Studio
@onready var _camera: Camera3D = %Camera3D
@onready var _subject_root: Node3D = %Subject
@onready var _info: Label = %Info

var _quitting := false
var _guard := Vector2.ZERO
var _watchdog: Thread = null
var _watch_stop := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var ps = load(PORTRAIT_STUDIO)
	var autosave: float = ps.autosave_seconds(_read_json(GAME_CONFIG_PATH))
	_guard = ps.guard_seconds(_class_count(args), autosave)
	_watchdog = Thread.new()
	_watchdog.start(_watch.bind(int(_guard.y * 1000.0)))
	get_tree().create_timer(maxf(_guard.x - Time.get_ticks_msec() / 1000.0, 0.0), true, false, true).timeout.connect(_on_save_guard_timeout)
	_view.size = Vector2i(RENDER_SIZE, RENDER_SIZE)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = ORTHO_SIZE
	_camera.position = Vector3(0.0, VIEW_CENTER_Y, 6.0)
	print("[SilhouetteStudio] save guard at %.0f s, hard stop at %.0f s (autosave every %.0f s)" % [_guard.x, _guard.y, autosave])
	_run.call_deferred(args)


func _exit_tree() -> void:
	_watch_stop = true
	if _watchdog != null and _watchdog.is_started():
		_watchdog.wait_to_finish()


func _on_save_guard_timeout() -> void:
	if _quitting:
		print("[SilhouetteStudio] error: save guard: still quitting at %.0f s; the hard stop follows" % (Time.get_ticks_msec() / 1000.0))
		return
	_fail("save guard: still running %.0f s after start: quitting" % (Time.get_ticks_msec() / 1000.0))


## The hard stop on its own thread (the main loop may be what hangs): kill the process at hard_ms after start.
func _watch(hard_ms: int) -> void:
	while not _watch_stop:
		if Time.get_ticks_msec() >= hard_ms:
			print("[SilhouetteStudio] error: hard stop: still running %.0f s after start, killing the process" % (hard_ms / 1000.0))
			OS.kill(OS.get_process_id())
			return
		OS.delay_msec(50)


func _run(args: PackedStringArray) -> void:
	var p := plan(args, _read_json(CLASSES_PATH), _read_json(CARD_PATH))
	if str(p.error) != "":
		_fail(str(p.error))
		return
	for job in p.jobs:
		if job.fallback:
			print("[SilhouetteStudio] warning: %s uses its fallback body %s (its model_path is missing)" % [job.cls, job.body])
		var why := clip_error(str(job.body), str(job.clip))   # review P12: every body and clip checked before any write
		if why != "":
			_fail("%s: %s" % [job.cls, why])
			return
		var dir := str(job.file).get_base_dir()
		var made := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir) if dir.begins_with("res://") else dir)
		if made != OK:
			_fail("%s: can't make the folder %s (error %d)" % [job.cls, dir, made])
			return
	var done: Array = []
	for job in p.jobs:
		if _quitting:
			return
		var img = await _render(job)
		if not (img is Image) or _quitting:
			return
		done.append({"cls": job.cls, "image": img})
	if p.sheet != "":
		var err := _contact_sheet(done, p.card).save_png(p.sheet)
		if err != OK:
			_fail("can't write the sheet %s (error %d)" % [p.sheet, err])
			return
		print("[SilhouetteStudio] wrote the sheet %s" % p.sheet)
	print("[SilhouetteStudio] done: %d silhouette(s) in %.1f s" % [done.size(), Time.get_ticks_msec() / 1000.0])
	_info.text = "done: %d silhouette(s) | quitting" % done.size()
	_quitting = true
	_quit(0)


## The whole request, checked before anything renders (pure): {error, jobs: [{cls, body, fallback, file, clip, time, yaw}],
## sheet, card}. classes=all (or a comma list) is required; out= and sheet= must be absolute.
static func plan(args: PackedStringArray, classes: Dictionary, card: Dictionary) -> Dictionary:
	var out := {"error": "", "jobs": [], "sheet": "", "card": card}
	var want := ""
	var out_dir := ""
	for a in args:
		if a.begins_with("classes="):
			want = a.substr(8)
		elif a.begins_with("out="):
			out_dir = a.substr(4)
		elif a.begins_with("sheet="):
			out.sheet = a.substr(6)
		else:
			out.error = "unknown argument '%s' (classes=all|A,B  out=<absolute folder>  sheet=<absolute .png>)" % a
			return out
	if want == "":
		out.error = "no classes= given (classes=all, or a comma list)"
		return out
	for p in [out_dir, out.sheet]:
		if p != "" and not (p.is_absolute_path() and not p.begins_with("res://") and not p.begins_with("user://")):
			out.error = "out= and sheet= must be absolute paths on disk: '%s'" % p
			return out
	var sil = card.get("silhouettes", {})
	var render = card.get("silhouette_render", {})
	if not (sil is Dictionary) or not (render is Dictionary):
		out.error = "%s needs silhouettes and silhouette_render objects" % CARD_PATH
		return out
	var size = render.get("size")
	if not (size is Array and size.size() == 2 and int(size[0]) > 8 and int(size[1]) > 8):
		out.error = "silhouette_render.size must be [w, h]"
		return out
	var names: Array = classes.keys() if want == "all" else Array(want.split(",", false))
	if names.is_empty():
		out.error = "no classes to render"
		return out
	for cls in names:
		var entry = classes.get(cls)
		if not (entry is Dictionary):
			out.error = "unknown class '%s' (not in %s)" % [cls, CLASSES_PATH]
			return out
		var body := ""
		var fallback := false   # review P12: the job says when it renders the fallback body
		for key in ["model_path", "fallback_model_path"]:
			var path := str(entry.get(key, ""))
			if path != "" and ResourceLoader.exists(path):
				body = path
				fallback = key == "fallback_model_path"
				break
		if body == "":
			out.error = "%s: neither its model_path nor its fallback_model_path exists" % cls
			return out
		var file := str(sil.get(cls, ""))
		if not (file.begins_with("res://") and file.ends_with(".png")) or file.contains(".."):
			out.error = "%s: tarot_card.json silhouettes has no res:// .png path for it ('%s')" % [cls, file]
			return out
		if out_dir != "":
			file = out_dir.path_join(file.get_file())
		var o = render.get("overrides", {}).get(cls, {}) if render.get("overrides") is Dictionary else {}
		o = o if o is Dictionary else {}
		out.jobs.append({"cls": cls, "body": body, "fallback": fallback, "file": file, "clip": str(o.get("clip", render.get("clip", "Idle"))),
			"time": float(o.get("time", render.get("time", 0.0))), "yaw": float(o.get("yaw_deg", render.get("yaw_deg", -25.0))),
			"size": Vector2i(int(size[0]), int(size[1])), "margin": clampf(float(render.get("margin", 0.06)), 0.0, 0.4)})
	return out


## Review P12: "" when `body` instances a Node3D with an AnimationPlayer holding `clip`, else why not (the studio checks
## every job with this before its first write, so a bad clip never leaves half the silhouettes rewritten).
static func clip_error(body: String, clip: String) -> String:
	var scene = load(body) if ResourceLoader.exists(body) else null
	if not scene is PackedScene:
		return "'%s' is not a scene" % body
	var model = (scene as PackedScene).instantiate()
	if not model is Node3D:
		if model:
			model.free()
		return "'%s' doesn't instantiate a Node3D" % body
	var players: Array = model.find_children("*", "AnimationPlayer", true, false)
	var ok: bool = not players.is_empty() and (players[0] as AnimationPlayer).has_animation(clip)
	model.free()
	return "" if ok else "no clip '%s' in %s" % [clip, body]


## One class: pose its body, render it white on black, turn that into the silhouette, write it. The Image, or null.
func _render(job: Dictionary):
	for old in _subject_root.get_children():
		old.free()
	var scene = load(str(job.body))
	if not scene is PackedScene:
		_fail("%s: '%s' is not a scene" % [job.cls, job.body])
		return null
	var model := (scene as PackedScene).instantiate() as Node3D
	if model == null:
		_fail("%s: '%s' doesn't instantiate a Node3D" % [job.cls, job.body])
		return null
	_subject_root.add_child(model)
	model.rotation_degrees = Vector3(0.0, float(job.yaw), 0.0)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty() or not (players[0] as AnimationPlayer).has_animation(str(job.clip)):
		_fail("%s: no clip '%s' in %s" % [job.cls, job.clip, job.body])
		return null
	var anim := players[0] as AnimationPlayer
	anim.play(str(job.clip))
	anim.seek(float(job.time), true)
	anim.pause()
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color.WHITE
	white.cull_mode = BaseMaterial3D.CULL_DISABLED
	for g in model.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).material_override = white
	_info.text = "%s | %s | %s %.2f s" % [job.cls, str(job.body).get_file(), job.clip, float(job.time)]
	for i in 2 + SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if _quitting:
		return null
	var shot := _view.get_texture().get_image()
	if shot == null or shot.is_empty():
		_fail("%s: the viewport gave no image" % job.cls)
		return null
	var mask := mask_from_render(shot)
	var used := mask.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		_fail("%s: nothing rendered (an empty silhouette)" % job.cls)
		return null
	if used.position.x <= 0 or used.position.y <= 0 or used.end.x >= mask.get_width() or used.end.y >= mask.get_height():
		_fail("%s: the figure touches the render's edge %s (cut off): widen ORTHO_SIZE or move VIEW_CENTER_Y" % [job.cls, used])
		return null
	var img := fit(mask.get_region(used), job.size, float(job.margin))
	var err := img.save_png(str(job.file))
	if err != OK:
		_fail("%s: can't write %s (error %d)" % [job.cls, job.file, err])
		return null
	print("[SilhouetteStudio] wrote %s (%dx%d) from %s, figure %dx%d px in the render" % [job.file, img.get_width(), img.get_height(),
		str(job.body).get_file(), used.size.x, used.size.y])
	return img


## A white-on-black render as a white figure on transparent: alpha = the red channel (unshaded white meshes; MSAA
## gives the soft edge). Pure.
static func mask_from_render(shot: Image) -> Image:
	var src := shot.duplicate() as Image
	src.convert(Image.FORMAT_L8)
	var lum := src.get_data()
	var la := PackedByteArray()
	la.resize(lum.size() * 2)
	for i in lum.size():
		la[i * 2] = 255
		la[i * 2 + 1] = lum[i]
	var out := Image.create_from_data(src.get_width(), src.get_height(), false, Image.FORMAT_LA8, la)
	out.convert(Image.FORMAT_RGBA8)
	return out


## The cropped figure fitted into `size` with `margin` (a fraction of each side), centred, its feet on the bottom
## margin. Pure.
static func fit(figure: Image, size: Vector2i, margin: float) -> Image:
	var avail := Vector2(size.x * (1.0 - 2.0 * margin), size.y * (1.0 - 2.0 * margin))
	var k := minf(avail.x / figure.get_width(), avail.y / figure.get_height())
	var w := maxi(1, int(round(figure.get_width() * k)))
	var h := maxi(1, int(round(figure.get_height() * k)))
	var scaled := figure.duplicate() as Image
	scaled.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var out := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(1, 1, 1, 0))
	var at := Vector2i(int((size.x - w) / 2.0), int(size.y - round(size.y * margin)) - h)
	out.blit_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), at)
	return out


## The six (or the requested) silhouettes side by side, each tinted with its class colour on the card's field colour.
func _contact_sheet(done: Array, card: Dictionary) -> Image:
	var colors := _read_json(CLASS_COLORS_PATH)
	var field := Color.from_string(str(card.get("field_color", "#231c18")), Color(0.14, 0.11, 0.09))
	var cell := Vector2i(320, 512)
	if not done.is_empty():
		cell = (done[0].image as Image).get_size()
	var gap := 16
	var sheet := Image.create(gap + done.size() * (cell.x + gap), cell.y + 2 * gap, false, Image.FORMAT_RGBA8)
	sheet.fill(field)
	for i in done.size():
		var hex := str(colors.get("classes", {}).get(done[i].cls, colors.get("default", "#7a7a7a")))
		var tint := Color.from_string(hex, Color.GRAY)
		var src: Image = done[i].image
		var tinted := Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
		for y in src.get_height():
			for x in src.get_width():
				var a := src.get_pixel(x, y).a
				if a > 0.0:
					tinted.set_pixel(x, y, Color(tint.r, tint.g, tint.b, a))
		sheet.blend_rect(tinted, Rect2i(Vector2i.ZERO, tinted.get_size()), Vector2i(gap + i * (cell.x + gap), gap))
	return sheet


func _class_count(args: PackedStringArray) -> int:
	for a in args:
		if a.begins_with("classes="):
			var want := a.substr(8)
			return _read_json(CLASSES_PATH).size() if want == "all" else maxi(want.split(",", false).size(), 1)
	return 1


func _fail(why: String) -> void:
	if _quitting:
		return
	_quitting = true
	push_error("[SilhouetteStudio] error: %s" % why)
	print("[SilhouetteStudio] error: %s" % why)
	_quit(1)


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
