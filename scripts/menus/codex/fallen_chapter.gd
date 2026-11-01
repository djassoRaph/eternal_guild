# fallen_chapter.gd — the Codex's Fallen Heroes chapter (Story 18.1, DC-3). Story 19.4 replaces it (the run filter, the
# death record panel, codex-game-run.dat); until then it is the live list the old Codex overlay showed (2026-08-18):
# every codex.dat `fallen_heroes` entry, newest death first, with the class portrait (PortraitSocket.resolve_texture),
# name, class, card, hire and fall days, missions. The right page: how many fell, and an epigraph.
# A click on a hero selects their row (highlighted) and counts as reading their entry (the book's note_read, review P1).
# `focus` (a hero's id, or {id, name, hire_day}: Story 18.3's "See The Fallen" link) selects that row and scrolls to it.
# Loaded by path; no class name, no autoload names (the book passes the codex and the deck).
extends RefCounted

const UI := preload("res://scripts/menus/codex/codex_ui.gd")

var rows: Array = []         # [{entry, node}] in display order (tests read it)
var focused: Control = null  # the selected (highlighted) row, if any
var selected := -1
var _ctx: Dictionary = {}
var _scroll: ScrollContainer


## codex.fallen_heroes, newest death first: the timestamp (real time, so it holds across runs, review P6), then the
## in-run death day, then the later in the file; junk skipped. Pure.
static func fallen_entries(codex: Dictionary) -> Array:
	var raw = codex.get("fallen_heroes", [])
	if not (raw is Array):
		return []
	var tagged: Array = []
	for i in (raw as Array).size():
		if raw[i] is Dictionary:
			tagged.append([raw[i], i])
	tagged.sort_custom(_newer)
	return tagged.map(func(t): return t[0])


static func _newer(a: Array, b: Array) -> bool:
	var ta := _n(a[0].get("timestamp"))
	var tb := _n(b[0].get("timestamp"))
	if ta != tb:
		return ta > tb
	var da := _n(a[0].get("death_day"))
	var db := _n(b[0].get("death_day"))
	if da != db:
		return da > db
	return int(a[1]) > int(b[1])


static func _n(v) -> float:
	return float(v) if (v is int or v is float) else -INF


## A deck card by id ({} when the deck doesn't know it: an old codex has "the_tower").
static func card_of(deck: Array, card_id) -> Dictionary:
	for c in deck:
		if c is Dictionary and str(c.get("id", "")) == str(card_id):
			return c
	return {}


## A hero's two lines: "Name — Class (Card)" and the hire / fall / missions line. Pure.
static func hero_lines(entry: Dictionary, deck: Array, cfg: Dictionary) -> Array:
	var card := card_of(deck, entry.get("tarot_card", ""))
	var top := "%s  —  %s" % [str(entry.get("name", "Unknown")), str(entry.get("class", "Unknown"))]
	if str(card.get("name", "")) != "":
		top += "  (%s)" % str(card.name)
	var detail := UI.text(cfg, "fallen_detail", {"hired": UI.num(entry.get("hire_day")),
		"fell": UI.num(entry.get("death_day", entry.get("day_fallen"))), "missions": UI.num(entry.get("missions_completed", 0))})
	return [top, detail]


## Is `entry` the hero `focus` names? An id (numbers as numbers), or {id, name, hire_day}: the id and, when given, the
## name and the hire day must match too (ids restarted every session before Story 4.2). Pure.
static func is_focus(entry: Dictionary, focus) -> bool:
	if focus is Dictionary:
		if not _same_id(entry.get("id"), focus.get("id")):
			return false
		if str(focus.get("name", "")) != "" and str(entry.get("name", "")) != str(focus.name):
			return false
		var fh = focus.get("hire_day")
		var eh = entry.get("hire_day")
		if (fh is int or fh is float) and (eh is int or eh is float) and int(fh) != int(eh):
			return false
		return true
	return focus != null and _same_id(entry.get("id"), focus)


func build(left: VBoxContainer, right: VBoxContainer, ctx: Dictionary) -> void:
	_ctx = ctx
	var cfg: Dictionary = ctx.cfg
	var deck: Array = ctx.deck if ctx.deck is Array else []
	var entries := fallen_entries(ctx.codex if ctx.codex is Dictionary else {})
	_scroll = UI.scroll("FallenScroll")
	left.add_child(_scroll)
	var list := VBoxContainer.new()
	list.name = "FallenList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	_scroll.add_child(list)
	if entries.is_empty():
		var empty := UI.label(cfg, UI.text(cfg, "fallen_empty"), "body", true, true)
		empty.name = "Empty"
		list.add_child(empty)
	var want := -1
	for i in entries.size():
		var e: Dictionary = entries[i]
		var row := _row(e, deck, cfg)
		row.gui_input.connect(_on_row_input.bind(i))
		list.add_child(row)
		rows.append({"entry": e, "node": row})
		if want < 0 and ctx.get("focus") != null and is_focus(e, ctx.focus):
			want = i
	var count := UI.label(cfg, UI.text(cfg, "fallen_count", {"n": entries.size()}), "heading")
	count.name = "Count"
	right.add_child(count)
	var epi := UI.label(cfg, UI.text(cfg, "fallen_epigraph"), "body", true, true)
	epi.name = "Epigraph"
	right.add_child(epi)
	if want >= 0:
		select(want)


## Select hero `i`: their row highlighted (the others not), scrolled into view, and their entry read (the book's note_read).
func select(i: int) -> void:
	if i < 0 or i >= rows.size():
		return
	var cfg: Dictionary = _ctx.cfg
	selected = i
	for k in rows.size():
		var box := UI.box(UI.color(cfg, "highlight"), UI.color(cfg, "accent"), 2) if k == i else UI.box(Color(0, 0, 0, 0))
		(rows[k].node as PanelContainer).add_theme_stylebox_override("panel", box)
	focused = rows[i].node
	if _scroll != null:
		_scroll.ensure_control_visible.call_deferred(focused)
	var book = _ctx.get("book")
	if book != null and is_instance_valid(book) and book.has_method("note_read"):
		var hid = rows[i].entry.get("id", i)
		book.note_read("fallen", UI.num(hid) if (hid is int or hid is float) else str(hid))


## Turn to the next (1) or previous (-1) hero (the book's arrow keys), wrapping; from nothing selected, the first.
func turn(dir: int) -> void:
	if rows.is_empty():
		return
	select(0 if selected < 0 else posmod(selected + dir, rows.size()))


func _on_row_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select(i)


func _row(e: Dictionary, deck: Array, cfg: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0)))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var card := card_of(deck, e.get("tarot_card", ""))
	var portrait := PortraitSocket.new()
	portrait.custom_minimum_size = Vector2(48, 48)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.set_adventurer({"portrait": card.get("portrait", ""), "class": e.get("class", ""), "id": e.get("id", "?")})
	row.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines := hero_lines(e, deck, cfg)
	var top := UI.label(cfg, lines[0], "body")
	top.name = "Name"
	info.add_child(top)
	var detail := UI.label(cfg, lines[1], "small", true)
	detail.name = "Detail"
	info.add_child(detail)
	row.add_child(info)
	return panel


static func _same_id(a, b) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return int(a) == int(b)
	return a != null and str(a) == str(b)
