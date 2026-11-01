# codex_lectern.gd — the Codex in the hall (Story 18.5, DC-10, DC-12): the Dragon Eye Book lying open on the old trunk by
# the hearth. Stand beside it, "Press E - Read the Codex", and the book (scripts/menus/codex_menu.gd) opens with the hall
# frozen while it is open (DC-11: pause_world). The first time in a run, Den Fa says a line about it first
# (data/dialogue/den_fa.dialogue, ~ codex_first_open) and the book opens when his box closes; GameManager.codex_first_opened
# (saved with the run) is set once his line is on screen, so he says it once a run. A box that can't open: the book opens
# at once and the flag stays false (he says it next time).
# The body is a placeholder (PlaceholderBody: an open book of simple meshes, its teal eye pulsing slowly: the glow that
# draws the eye, Story 25.19's AC) until Story 25.19's art: data/config/codex_book.json `lectern_body` names a scene that
# replaces it (the placeholder is hidden).
# One E never does two things (J6): it claims ReadZone with the scene's ZonePromptUI (the nearest zone the player stands in
# owns E; the hearth's fire is a few steps away) and acts on E only while owns_e(ReadZone); its own live checks stay a
# second guard. Where there's no ZonePromptUI, a Label3D over the book is its prompt.
# No autoload, no physics body; loaded by path (no class name).
extends Node3D

signal book_opened

const UI := preload("res://scripts/menus/codex/codex_ui.gd")
const Runner := preload("res://scripts/dialogue/dialogue_runner.gd")
const ZONE_PROMPT_UI := preload("res://scripts/game/ZonePromptUI.gd")
const BOOK_SCRIPT := "res://scripts/menus/codex_menu.gd"
const FIRST_OPEN_TITLE := "codex_first_open"
const COOLDOWN := 0.5            # seconds after the book or the line closes before E reads it again
const PROMPT_HEIGHT := 0.55      # the fallback Label3D prompt above the book

## Den Fa's line (the test seam, as den_fa.gd's): a file without codex_first_open opens the book at once.
@export_file("*.dialogue") var dialogue_path := "res://data/dialogue/den_fa.dialogue"

@onready var _zone: Area3D = $ReadZone
@onready var _anchor: Node3D = $Anchor
@onready var _body: Node3D = $PlaceholderBody
@onready var _eye: MeshInstance3D = $PlaceholderBody/Eye

var glow := {"min": 0.6, "max": 1.6, "period": 3.0}
var prompt := "Press E - Read the Codex"
var _player: Node3D = null
var _prompt_ui: Node = null
var _prompt_label: Label3D = null
var _prompt_shown := false
var _cooldown := 0.0
var _book: Node = null
var _box: Node = null
var _eye_mat: StandardMaterial3D = null
var _t := 0.0


## The eye's emission energy at time `t` (pure): a slow sine between glow.min and glow.max over glow.period seconds.
static func glow_energy(t: float, g: Dictionary) -> float:
	var lo := float(g.get("min", 0.6))
	var hi := float(g.get("max", 1.6))
	var period := maxf(0.1, float(g.get("period", 3.0)))
	return lerpf(lo, hi, 0.5 + 0.5 * sin(TAU * t / period))


func _ready() -> void:
	var cfg := UI.config()
	prompt = str(cfg.get("lectern_prompt", prompt))
	var g = cfg.get("lectern_glow", {})
	if g is Dictionary:
		for k in ["min", "max", "period"]:
			if g.get(k) is int or g.get(k) is float:
				glow[k] = float(g[k])
	_apply_body(str(cfg.get("lectern_body", "")))
	if _eye and _eye.material_override is StandardMaterial3D:
		_eye_mat = (_eye.material_override as StandardMaterial3D).duplicate()
		_eye.material_override = _eye_mat
	_zone.body_entered.connect(_on_body_entered)
	_zone.body_exited.connect(_on_body_exited)
	# The hall adds its ZonePromptUI in its own _ready (two frames after load), so look for a while (the cat's pattern).
	for i in 30:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		_prompt_ui = ZONE_PROMPT_UI.find(get_tree())
		if _prompt_ui:
			_prompt_ui.claim(_zone, prompt, _anchor)
			return
	_prompt_label = Label3D.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.text = prompt
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.no_depth_test = true
	_prompt_label.render_priority = 2           # above the ink pass (godot-dev-gotchas)
	_prompt_label.outline_render_priority = 1
	_prompt_label.pixel_size = 0.005
	_prompt_label.font_size = 40
	_prompt_label.outline_size = 10
	_prompt_label.modulate = Color(1, 1, 0)
	_prompt_label.position = Vector3(0, PROMPT_HEIGHT, 0)
	_prompt_label.visible = false
	add_child(_prompt_label)


## codex_book.json `lectern_body`: "" keeps the placeholder book; a scene replaces it; a path that doesn't load keeps the
## placeholder with one warning.
func _apply_body(path: String) -> void:
	if path == "":
		return
	var scene = load(path) if ResourceLoader.exists(path) else null
	if scene is PackedScene:
		var inst := (scene as PackedScene).instantiate()
		inst.name = "Body"
		add_child(inst)
		_body.visible = false
		return
	UI.warn_once("lectern_body", "[CodexLectern] fallback: the book's body '%s' doesn't load; the placeholder book stays" % path)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_t += delta
	if _eye_mat:
		_eye_mat.emission_energy_multiplier = glow_energy(_t, glow)
	_show_prompt(can_read())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo() and can_read():
		get_viewport().set_input_as_handled()
		interact()


## The player is beside the book, E is its (the prompt UI's owner), and nothing else holds the player.
func can_read() -> bool:
	if _player == null or not is_instance_valid(_player) or not is_inside_tree() or get_tree().paused:
		return false
	if _cooldown > 0.0 or is_book_open() or (_box != null and is_instance_valid(_box)):
		return false
	if not get_tree().get_nodes_in_group("dialogue_open").is_empty():
		return false
	if _prompt_ui != null and is_instance_valid(_prompt_ui) and not _prompt_ui.owns_e(_zone):
		return false
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.get("game_over_active"):
		return false
	if ZONE_PROMPT_UI.modal_open(get_tree()):
		return false
	for p in get_tree().get_nodes_in_group("patrons"):   # a waiting patron takes E first (zone_interactions)
		if p.has_method("can_be_served_by") and p.can_be_served_by(_player.global_position):
			return false
	return true


## Read the book: Den Fa's line first, once a run (DC-12); then (or at once) the book.
func interact() -> void:
	if is_book_open() or (_box != null and is_instance_valid(_box)):
		return
	_cooldown = COOLDOWN
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and not bool(gm.get("codex_first_opened")):
		var box = Runner.start(self, dialogue_path, FIRST_OPEN_TITLE)
		if box != null:
			_box = box
			box.first_line.connect(_on_line_shown, CONNECT_ONE_SHOT)
			box.closed.connect(_on_line_closed, CONNECT_ONE_SHOT)
			return
	open_book()


## Open the book over the scene, the world frozen while it is open. Returns it (or the one already open).
func open_book() -> Node:
	if is_book_open():
		return _book
	if not is_inside_tree():
		return null
	var book = load(BOOK_SCRIPT).new()
	book.pause_world = true
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	host.add_child(book)
	_book = book
	book.closed.connect(_on_book_closed, CONNECT_ONE_SHOT)
	print("[CodexLectern] open: the Codex")
	book_opened.emit()
	return book


func is_book_open() -> bool:
	return _book != null and is_instance_valid(_book) and not _book.is_queued_for_deletion() and not _book.is_closing()


func _on_line_shown() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		gm.set("codex_first_opened", true)


func _on_line_closed() -> void:
	_box = null
	_cooldown = COOLDOWN
	open_book.call_deferred()   # the next frame: the key that closed the box never reaches the book


func _on_book_closed() -> void:
	_book = null
	_cooldown = COOLDOWN


## The Label3D prompt, only in scenes without a ZonePromptUI (with one, the UI shows the claimed prompt).
func _show_prompt(want: bool) -> void:
	if want == _prompt_shown:
		return
	_prompt_shown = want
	if _prompt_label:
		_prompt_label.visible = want


func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		_player = body


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player = null
