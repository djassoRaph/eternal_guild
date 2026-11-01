# codex_menu.gd — the Codex: the Dragon Eye Book (Stories 18.1-18.5, Epic 18; FR-70).
#
# One overlay, opened from the main menu, the pause menu (in the hall and outside) and the book in the hall
# (scripts/game/codex_lectern.gd, Story 18.5): a two-page spread with a tab per chapter. data/config/codex_book.json
# holds the chapters (order, tab labels, titles), every word and the look; the chapters: Tarot Cards (18.2), Fallen
# Heroes (18.1; Story 19.4 replaces it), Prior Artefacts (18.3), Guild History (18.4). A tab rebuilds both pages in place;
# Esc or Close shuts the book.
#
# The look is a placeholder drawn in code (the Placeholder* nodes: a leather cover, two parchment pages, a gutter, a teal
# eye clasp, ribbon tabs) until Story 25.19/25.20's art: codex_book.json `spread` names a texture that replaces it (drawn
# as a nine-patch), from one path. The book reads codex.dat only (SaveSystem.codex_data, in memory: the fallen, the
# artefacts, the run history, the Tarot unlocks) plus the deck's data, and never writes anything (DC-13).
#
# While open it is in "blocks_player" (the player stands, no conversation opens, ZonePromptUI.modal_open() closes E and
# the hall hides its log) and in "codex_open" (Story 3.7's day clock stops while it is open), and it is modal: every key is
# the book's (Esc closes it; the left and right arrows turn a chapter's pages). `pause_world` (the book in the hall,
# DC-11): the world is frozen while it is open through the scene's set_world_frozen() (the hall: its root runs ALWAYS, so a
# tree pause wouldn't stop it), else by a tree pause; only what the book did is undone on close.
#
# Chapters are scripts in scripts/menus/codex/ (no class name, no autoload names): new(), then build(left, right, ctx) with
# ctx = {codex, deck, cfg, book, focus}. A chapter calls book.show_chapter(id, focus) for a link and book.note_read(chapter,
# id) for each page it shows: entry_read is what a playtest counts ("read a Codex entry", kickstarter-plan §2.3).
# No class name (the old CodexMenu name was unused): callers load the book by path.
extends CanvasLayer

signal closed
signal entry_read(chapter: String, entry_id: String)

const UI := preload("res://scripts/menus/codex/codex_ui.gd")
const OPEN_GROUP := "codex_open"
const CHAPTER_SCRIPTS := {
	"tarot": "res://scripts/menus/codex/tarot_chapter.gd",
	"fallen": "res://scripts/menus/codex/fallen_chapter.gd",
	"artefacts": "res://scripts/menus/codex/artefacts_chapter.gd",
	"history": "res://scripts/menus/codex/history_chapter.gd",
}

## The codex to read (a caller may set it before the book enters the tree; tests pass fixtures). null: SaveSystem's.
var codex = null
## The Tarot deck (tarot_deck.json's cards). null: DataManager's.
var deck = null
## The book in the hall sets this: the world is frozen while the book is open (DC-11).
var pause_world := false
## The chapter shown.
var current_chapter := ""

var _cfg: Dictionary = {}
var _spread: Control
var _placeholder: Control
var _texture: NinePatchRect
var _left: VBoxContainer
var _right: VBoxContainer
var _tabs: Dictionary = {}       # chapter id -> its tab Button
var _tab_group := ButtonGroup.new()
var _chapter = null              # the shown chapter's object (kept alive for its buttons)
var _last_read := ""
var _closing := false
var _frozen_scene: WeakRef = null
var _paused_tree := false


func _ready() -> void:
	layer = 128   # above other UI (the pause menu, the HUD at 100, the dialogue box at 110)
	process_mode = Node.PROCESS_MODE_ALWAYS   # works over a paused game
	add_to_group("blocks_player")
	add_to_group(OPEN_GROUP)
	_cfg = UI.config()
	if not (codex is Dictionary):
		var ss := get_node_or_null("/root/SaveSystem")
		codex = ss.codex_data if ss != null and ss.get("codex_data") is Dictionary else {}
	if not (deck is Array):
		var dm := get_node_or_null("/root/DataManager")
		deck = dm.get_tarot_deck() if dm != null and dm.has_method("get_tarot_deck") else []
	_build()
	_freeze(true)
	var chapters: Array = _cfg.chapters
	show_chapter(str(chapters[0].get("id", "")) if not chapters.is_empty() else "")
	get_viewport().size_changed.connect(_fit)
	_fit()


## Show chapter `id`: both pages rebuilt in place (the same book), its tab marked; `focus` picks what the chapter shows
## first (a hero's id, an artefact's index, a run, a card id). An id with no builder: a stub page and one warning.
func show_chapter(id: String, focus = null) -> void:
	if _left == null:
		return
	_clear(_left)
	_clear(_right)
	_chapter = null
	_last_read = ""
	current_chapter = id
	for tid in _tabs:
		(_tabs[tid] as Button).set_pressed_no_signal(tid == id)
	var title := id
	for c in _cfg.chapters:
		if str(c.get("id", "")) == id:
			title = str(c.get("title", c.get("tab", id)))
	var heading := UI.label(_cfg, title, "title")
	heading.name = "ChapterTitle"
	_left.add_child(heading)
	var path := str(CHAPTER_SCRIPTS.get(id, ""))
	var script = load(path) if path != "" and ResourceLoader.exists(path) else null
	if not (script is GDScript):
		UI.warn_once("chapter_" + id, "[Codex] fallback: no chapter '%s'; a stub page instead" % id)
		var stub := UI.label(_cfg, UI.text(_cfg, "stub"), "body", true, true)
		stub.name = "Stub"
		_left.add_child(stub)
		return
	_chapter = (script as GDScript).new()
	_chapter.build(_left, _right, {"codex": codex, "deck": deck, "cfg": _cfg, "book": self, "focus": focus})


## A chapter shows a page (`entry_id` in `chapter`): entry_read once (the same page again in a row: no), and the log line
## a playtest counts.
func note_read(chapter: String, entry_id: String) -> void:
	var key := chapter + "/" + entry_id
	if key == _last_read:
		return
	_last_read = key
	print(read_line(chapter, entry_id))
	entry_read.emit(chapter, entry_id)


static func read_line(chapter: String, entry_id: String) -> String:
	return "[Codex] read: %s %s" % [chapter, entry_id]


## Close the book: the world as it was, `closed`, gone.
func close() -> void:
	if _closing:
		return
	_closing = true
	_freeze(false)
	remove_from_group("blocks_player")
	remove_from_group(OPEN_GROUP)
	visible = false
	closed.emit()
	queue_free()


func is_closing() -> bool:
	return _closing


func _exit_tree() -> void:
	_freeze(false)   # freed without close() (a scene change): never leave the world frozen


## The book is modal: every key is its own. Esc closes it; the arrows turn the chapter's pages.
func _input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
		if event.is_pressed() and not event.is_echo() and _chapter != null and _chapter.has_method("turn"):
			if event.is_action_pressed("ui_left"):
				_chapter.turn(-1)
			elif event.is_action_pressed("ui_right"):
				_chapter.turn(1)


func _freeze(on: bool) -> void:
	if on:
		if not pause_world or not is_inside_tree() or _frozen_scene != null or _paused_tree:
			return
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("set_world_frozen") and scene.has_method("is_world_frozen"):
			if not scene.is_world_frozen():
				scene.set_world_frozen(true)
				_frozen_scene = weakref(scene)
		elif not get_tree().paused:
			get_tree().paused = true
			_paused_tree = true
		return
	if _frozen_scene != null:
		var scene = _frozen_scene.get_ref()
		_frozen_scene = null
		if scene != null and is_instance_valid(scene) and scene.has_method("set_world_frozen"):
			scene.set_world_frozen(false)
	if _paused_tree:
		_paused_tree = false
		if is_inside_tree():
			get_tree().paused = false


# --- the spread ---

func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Backdrop"
	dim.color = Color(0, 0, 0, 0.68)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_spread = Control.new()
	_spread.name = "Spread"
	_spread.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_spread)
	_placeholder = _build_placeholder()
	_spread.add_child(_placeholder)
	_texture = NinePatchRect.new()
	_texture.name = "SpreadTexture"
	_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture.visible = false
	_spread.add_child(_texture)
	_apply_spread_texture()
	_left = _page("LeftPage", _cfg.pages.left)
	_right = _page("RightPage", _cfg.pages.right)
	_build_tabs()
	var close_button := _tab_button(UI.text(_cfg, "close"))
	close_button.name = "CloseButton"
	close_button.toggle_mode = false
	close_button.button_group = null
	_anchor(close_button, [0.86, 0.935, 0.11, 0.05])
	close_button.pressed.connect(close)
	_spread.add_child(close_button)


## The placeholder spread (DC-2): the cover, the two pages where the content goes, the gutter, the eye clasp.
func _build_placeholder() -> Control:
	var root := Control.new()
	root.name = "PlaceholderSpread"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cover := Panel.new()
	cover.name = "PlaceholderCover"
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_theme_stylebox_override("panel", UI.box(UI.color(_cfg, "cover"), UI.color(_cfg, "cover_edge"), 6, 16))
	root.add_child(cover)
	var pages: Dictionary = _cfg.pages
	for side in [["PlaceholderLeftPage", pages.left], ["PlaceholderRightPage", pages.right]]:
		var r: Array = side[1]
		var page := Panel.new()
		page.name = side[0]
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_theme_stylebox_override("panel", UI.box(UI.color(_cfg, "page"), UI.color(_cfg, "page_edge"), 2, 6))
		_anchor(page, [float(r[0]) - 0.02, float(r[1]) - 0.035, float(r[2]) + 0.04, float(r[3]) + 0.07])
		root.add_child(page)
	var gutter := ColorRect.new()
	gutter.name = "PlaceholderGutter"
	gutter.color = UI.color(_cfg, "gutter")
	gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gx := (float(pages.left[0]) + float(pages.left[2]) + float(pages.right[0])) * 0.5
	_anchor(gutter, [gx - 0.006, float(pages.left[1]) - 0.035, 0.012, float(pages.left[3]) + 0.07])
	root.add_child(gutter)
	var eye := Panel.new()
	eye.name = "PlaceholderEye"
	eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eye.add_theme_stylebox_override("panel", UI.box(UI.color(_cfg, "eye"), UI.color(_cfg, "cover_edge"), 3, 40))
	_anchor(eye, [gx - 0.022, 0.006, 0.044, 0.042])
	var pupil := Panel.new()
	pupil.name = "Pupil"
	pupil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pupil.add_theme_stylebox_override("panel", UI.box(UI.color(_cfg, "cover_edge"), Color(0, 0, 0, 0), 0, 6))
	_anchor(pupil, [0.44, 0.12, 0.12, 0.76])
	eye.add_child(pupil)
	root.add_child(eye)
	return root


## codex_book.json `spread`: "" draws the placeholder; a texture replaces it (a nine-patch); a path that doesn't load
## draws the placeholder and warns once.
func _apply_spread_texture() -> void:
	var path := str(_cfg.get("spread", ""))
	var tex = load(path) if path != "" and ResourceLoader.exists(path) else null
	if tex is Texture2D:
		var m: Array = _cfg.spread_margins
		_texture.texture = tex
		_texture.patch_margin_left = int(m[0])
		_texture.patch_margin_top = int(m[1])
		_texture.patch_margin_right = int(m[2])
		_texture.patch_margin_bottom = int(m[3])
		_texture.visible = true
		_placeholder.visible = false
		return
	_texture.visible = false
	_placeholder.visible = true
	if path != "":
		UI.warn_once("spread", "[Codex] fallback: the book's spread '%s' doesn't load; the placeholder is drawn" % path)


## A page's content area: a VBox inside the page rect.
func _page(page_name: String, r: Array) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = page_name
	v.add_theme_constant_override("separation", 8)
	_anchor(v, r)
	_spread.add_child(v)
	return v


## The tabs: ribbons along the top edge, the first half over the left page and the rest over the right.
func _build_tabs() -> void:
	var chapters: Array = _cfg.chapters
	var half := int(ceil(chapters.size() / 2.0))
	var rows := []
	var pages: Dictionary = _cfg.pages
	for i in 2:
		var row := HBoxContainer.new()
		row.name = "Tabs%d" % i
		row.add_theme_constant_override("separation", 6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var r: Array = pages.left if i == 0 else pages.right
		_anchor(row, [float(r[0]), 0.004, float(r[2]), maxf(0.02, float(r[1]) - 0.042)])
		_spread.add_child(row)
		rows.append(row)
	for i in chapters.size():
		var c: Dictionary = chapters[i]
		var id := str(c.get("id", ""))
		var b := _tab_button(str(c.get("tab", id)))
		b.name = "Tab_" + id
		b.pressed.connect(show_chapter.bind(id))
		(rows[0] if i < half else rows[1]).add_child(b)
		_tabs[id] = b


func _tab_button(s: String) -> Button:
	var b := Button.new()
	b.text = s
	b.toggle_mode = true
	b.button_group = _tab_group
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 0)
	b.add_theme_font_size_override("font_size", UI.font_size(_cfg, "body"))
	var tab := UI.color(_cfg, "tab")
	var active := UI.color(_cfg, "tab_active")
	b.add_theme_stylebox_override("normal", UI.box(tab, UI.color(_cfg, "cover_edge"), 1, 6))
	b.add_theme_stylebox_override("hover", UI.box(tab.lightened(0.15), UI.color(_cfg, "eye"), 1, 6))
	b.add_theme_stylebox_override("pressed", UI.box(active, UI.color(_cfg, "eye"), 2, 6))
	b.add_theme_stylebox_override("hover_pressed", UI.box(active, UI.color(_cfg, "eye"), 2, 6))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, UI.color(_cfg, "tab_text"))
	return b


## A control placed by a rect [x, y, w, h] as fractions of its parent.
static func _anchor(c: Control, r: Array) -> void:
	c.anchor_left = float(r[0])
	c.anchor_top = float(r[1])
	c.anchor_right = float(r[0]) + float(r[2])
	c.anchor_bottom = float(r[1]) + float(r[3])
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0


## The spread's size: codex_book.json `size`, scaled down (never up) to fit max_screen_fraction of the window.
func _fit() -> void:
	if _spread == null or not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	var want := Vector2(float(_cfg.size[0]), float(_cfg.size[1]))
	var f := float(_cfg.max_screen_fraction)
	var s := minf(1.0, minf(vp.x * f / want.x, vp.y * f / want.y))
	_spread.custom_minimum_size = want * s


static func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
