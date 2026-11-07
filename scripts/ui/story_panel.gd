# story_panel.gd — one illustrated story panel, full screen (Story 10.1, AC 2-5).
#
# The hall's director (scripts/narrative/story_panels.gd) makes one, sets `panel`, `look`, `panel_id`, `trigger_type`,
# `min_seconds` and `grace_seconds`, then adds it to the current scene, so it dies with the scene and reads keys before
# the scene root's _input. Built in code in the morning briefing's house style (the look comes from panels.json).
# - Layer 118: over the dialogue box, the pause menu and the fall screen (110), under 17.3's card reveal (120), 10.7's
#   end card (126) and the Codex (128). Process ALWAYS: its timers and tweens run while the tree is paused (10.7's stop).
# - While open it is in "story_panel_open" and "blocks_player" (the player and the E zones stand down:
#   ZonePromptUI.modal_open), and leaves both when it closes.
# - The world (PS-4): the current scene's set_world_frozen(true) when it has the two DC-11 methods and isn't frozen yet
#   (the hall's root runs ALWAYS, so a tree pause alone stops nothing there); else, with no such methods and the tree
#   running, a tree pause. On close it undoes only what it did.
# - Keys (PS-7): every key event is marked handled while open (no pause menu, no roster, no F9/F10, no zone). Dismiss,
#   or the next page, is the button, E (interact), Enter / Space (ui_accept) or Esc (ui_cancel: on a skippable panel it
#   skips the pages left). Never an echo, never a key in the first grace_seconds of a page; the mouse works on the
#   button at once. A hard gate (panel.skippable false) hides the button and ignores every dismiss for min_seconds on
#   each page, then fades the button in (7.3's death pause pattern).
# - pages (2026-11-07, the opening's three pictures): [{illustration, text}] shown in turn under the one title; a panel
#   without pages is one page of its own illustration and text.
# - `finished` is emitted exactly once: dismissed, close(reason), the fall (GameBus.game_over_triggered), or freed
#   while open (a scene change): an awaiting caller never hangs. Then it frees itself.
# No class_name and no autoload names (loaded by path; the fall's signal is found through the tree).
extends CanvasLayer

signal finished

const LAYER := 118
const OPEN_GROUPS := ["story_panel_open", "blocks_player"]
## The house style (the morning briefing's colours); panels.json's look overrides it key by key.
const DEFAULT_LOOK := {
	"backdrop": Color(0.0, 0.0, 0.0, 0.85), "panel_bg": Color(0.12, 0.11, 0.1, 1.0), "border": Color(0.8, 0.65, 0.3, 0.6),
	"title": Color(0.9, 0.75, 0.4), "ink": Color(0.85, 0.85, 0.8), "illustration_size": Vector2(960, 540),
}
const MAX_ILLUSTRATION_HEIGHT := 0.6   # of the window's height (AC 2)
const MAX_PANEL_WIDTH := 0.86          # of the window's width
const PLATE_SIZE := Vector2i(320, 180)
const PAGE_FADE_SECONDS := 0.25
const BUTTON_FADE_SECONDS := 0.4

## Set by the caller before it adds the panel.
var panel: Dictionary = {}
var look: Dictionary = {}
var panel_id := ""
var trigger_type := ""
var min_seconds := 3.0
var grace_seconds := 0.3

var backdrop: ColorRect
var frame: PanelContainer
var illustration: TextureRect
var title_label: Label
var text_label: Label
var counter_label: Label
var button: Button

## The page shown (0-based) and the pages ([{illustration, text}]).
var page := 0
var pages: Array = []
## A hard gate is holding the button back on this page.
var gated := false

var _closed := false
var _froze_scene: Node = null
var _paused_tree := false
var _page_opened_ms := 0
var _page_token := 0

## One "drawing a plate" warning per panel and picture per session (NFR-11).
static var warned_plates: Dictionary = {}
static var _plate: ImageTexture = null


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	for g in OPEN_GROUPS:
		add_to_group(g)
	pages = page_list(panel)
	_build()
	_freeze()
	var bus := get_tree().root.get_node_or_null("GameBus")
	if bus != null and bus.has_signal("game_over_triggered"):
		bus.connect("game_over_triggered", _on_game_over)
	get_viewport().size_changed.connect(_fit)
	print("[StoryPanels] open: %s (%s)" % [panel_id, trigger_type])
	_show_page(0)


## The pages to show: the panel's valid `pages` entries (a text each), else one page of its own illustration and text.
static func page_list(p: Dictionary) -> Array:
	var out: Array = []
	if p.get("pages") is Array:
		for pg in p.pages:
			if pg is Dictionary and pg.get("text") is String and str(pg.text) != "":
				out.append({"illustration": str(pg.get("illustration", "")), "text": str(pg.text)})
	if out.is_empty():
		out.append({"illustration": str(p.get("illustration", "")), "text": str(p.get("text", ""))})
	return out


## Whether a key may dismiss or turn the page now: not inside a hard gate, not in the page's first grace_seconds.
func can_dismiss_by_key() -> bool:
	return not _closed and not gated and Time.get_ticks_msec() - _page_opened_ms >= int(grace_seconds * 1000.0)


## Close now, also inside a hard gate (10.7's timeout): leave both groups, undo the freeze, emit `finished` once, free.
## A second call does nothing.
func close(reason := "dismiss") -> void:
	_close(reason, true)


func is_closed() -> bool:
	return _closed


func _input(event: InputEvent) -> void:
	if _closed:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventAction):
		return   # the mouse goes the GUI's way (the backdrop stops it; the button takes its clicks)
	get_viewport().set_input_as_handled()
	if event.is_echo() or not event.is_pressed() or not can_dismiss_by_key():
		return
	if event.is_action_pressed("ui_cancel"):
		if bool(panel.get("skippable", true)):
			close("skip")
		else:
			_advance()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_advance()


## Freed with its world (a scene change) while open: callers still hear `finished`.
func _exit_tree() -> void:
	if not _closed:
		_close("freed", false)


func _on_button() -> void:
	if _closed or gated:
		return
	_advance()


func _on_game_over(_reason: String = "") -> void:
	close("game over")


func _advance() -> void:
	if page + 1 < pages.size():
		_show_page(page + 1)
	else:
		close("dismiss")


func _show_page(i: int) -> void:
	page = clampi(i, 0, pages.size() - 1)
	_page_token += 1
	var pg: Dictionary = pages[page]
	illustration.texture = texture_for(panel_id, str(pg.get("illustration", "")))
	text_label.text = str(pg.get("text", ""))
	counter_label.text = "%d / %d" % [page + 1, pages.size()]
	counter_label.visible = pages.size() > 1
	_page_opened_ms = Time.get_ticks_msec()
	_set_gate(not bool(panel.get("skippable", true)), _page_token)
	frame.modulate.a = 0.0
	create_tween().tween_property(frame, "modulate:a", 1.0, PAGE_FADE_SECONDS)


func _set_gate(on: bool, token: int) -> void:
	gated = on
	button.visible = not on
	button.modulate.a = 0.0 if on else 1.0
	if on:
		get_tree().create_timer(maxf(min_seconds, 0.0), true).timeout.connect(_end_gate.bind(token))


func _end_gate(token: int) -> void:
	if _closed or token != _page_token:
		return
	gated = false
	button.visible = true
	create_tween().tween_property(button, "modulate:a", 1.0, BUTTON_FADE_SECONDS)


func _close(reason: String, free_it: bool) -> void:
	if _closed:
		return
	_closed = true
	_page_token += 1
	for g in OPEN_GROUPS:
		if is_in_group(g):
			remove_from_group(g)
	_thaw()
	visible = false
	print("[StoryPanels] close: %s (%s)" % [panel_id, reason])
	finished.emit()
	if free_it and is_inside_tree():
		queue_free()


func _freeze() -> void:
	var tree := get_tree()
	var scene := tree.current_scene
	if scene != null and scene.has_method("set_world_frozen") and scene.has_method("is_world_frozen"):
		if not scene.is_world_frozen():
			scene.set_world_frozen(true)
			_froze_scene = scene
	elif not tree.paused:
		tree.paused = true
		_paused_tree = true


func _thaw() -> void:
	if _froze_scene != null and is_instance_valid(_froze_scene):
		_froze_scene.set_world_frozen(false)
	_froze_scene = null
	if _paused_tree and is_inside_tree():
		get_tree().paused = false
	_paused_tree = false


func _look(key: String):
	var v = look.get(key)
	var d = DEFAULT_LOOK[key]
	return v if typeof(v) == typeof(d) else d


func _build() -> void:
	backdrop = ColorRect.new()
	backdrop.color = _look("backdrop")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	frame = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = _look("panel_bg")
	style.border_color = _look("border")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	frame.add_theme_stylebox_override("panel", style)
	center.add_child(frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	frame.add_child(vbox)

	illustration = TextureRect.new()
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	illustration.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(illustration)

	title_label = Label.new()
	title_label.text = str(panel.get("title", ""))
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", _look("title"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	text_label = Label.new()
	text_label.add_theme_font_size_override("font_size", 18)
	text_label.add_theme_color_override("font_color", _look("ink"))
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(text_label)

	counter_label = Label.new()
	counter_label.add_theme_font_size_override("font_size", 12)
	counter_label.add_theme_color_override("font_color", (_look("ink") as Color).darkened(0.4))
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(counter_label)

	button = Button.new()
	button.text = str(panel.get("button", "Continue"))
	button.custom_minimum_size = Vector2(200, 40)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE   # the keys are read in _input; a focused button would take Space twice
	button.pressed.connect(_on_button)
	vbox.add_child(button)
	_fit()


## The picture at its look size, scaled down to fit the window (at most 60 % of its height); the text wraps to its width.
func _fit() -> void:
	if illustration == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var want: Vector2 = _look("illustration_size")
	if want.x <= 0.0 or want.y <= 0.0:
		want = DEFAULT_LOOK.illustration_size
	var s := minf(1.0, minf(vp.y * MAX_ILLUSTRATION_HEIGHT / want.y, vp.x * MAX_PANEL_WIDTH / want.x))
	illustration.custom_minimum_size = (want * s).floor()
	text_label.custom_minimum_size.x = illustration.custom_minimum_size.x
	# pages: room for the tallest page's words, so the panel doesn't jump as the pages turn
	var font := text_label.get_theme_font("font")
	var font_size := text_label.get_theme_font_size("font_size")
	var tallest := 0.0
	if pages.size() > 1 and font != null:
		for pg in pages:
			tallest = maxf(tallest, font.get_multiline_string_size(str(pg.get("text", "")), HORIZONTAL_ALIGNMENT_CENTER,
				text_label.custom_minimum_size.x, font_size).y)
	text_label.custom_minimum_size.y = ceilf(tallest)


## The page's picture when it loads as a Texture2D; else a drawn plate and one warning per panel and path a session.
static func texture_for(id: String, path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	var key := "%s|%s" % [id, path]
	if not warned_plates.has(key):
		warned_plates[key] = true
		push_warning("[StoryPanels] illustration: %s missing: drawing a plate" % (path if path != "" else "(no path for %s)" % id))
	return plate()


## A plain dark plate with a lighter rim (the dialogue box's drawn-plate pattern), drawn once.
static func plate() -> ImageTexture:
	if _plate != null:
		return _plate
	var img := Image.create(PLATE_SIZE.x, PLATE_SIZE.y, false, Image.FORMAT_RGBA8)
	var fill := Color(0.16, 0.14, 0.13)
	img.fill(fill)
	var rim := fill.lightened(0.25)
	for x in PLATE_SIZE.x:
		for r in 3:
			img.set_pixel(x, r, rim)
			img.set_pixel(x, PLATE_SIZE.y - 1 - r, rim)
	for y in PLATE_SIZE.y:
		for r in 3:
			img.set_pixel(r, y, rim)
			img.set_pixel(PLATE_SIZE.x - 1 - r, y, rim)
	_plate = ImageTexture.create_from_image(img)
	return _plate
