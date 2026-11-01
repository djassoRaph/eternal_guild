# artefacts_chapter.gd — the Codex's Prior Artefacts chapter (Story 18.3, DC-8).
#
# Every relic in the codex's `artifacts_found`, oldest first (the list is only ever appended to, so its order is the order
# of discovery), on the left page: its name and "Run 2 · Day 14". The right page: the one selected (the oldest when the
# chapter opens): its name, its description, who found it ("Finder unknown" for a find recorded before Story 18.3) and
# when. A finder who later fell (the same id, name and, when both have it, hire day in `fallen_heroes`: an id can come
# back in a later session, review P3) adds "Nina fell on Day 20." and a link to the Fallen Heroes chapter, that hero
# highlighted.
# Each page shown is a read (the book's note_read); the arrow keys turn the pages.
# Loaded by path; no class name, no autoload names (the book passes the codex).
extends RefCounted

const UI := preload("res://scripts/menus/codex/codex_ui.gd")

var entries: Array = []      # artefact_entries() (tests read it)
var row_nodes: Array = []    # the left page's rows, in the same order
var selected := -1
var _ctx: Dictionary = {}
var _right: VBoxContainer


## The relics in discovery order (file order); junk skipped; a missing or non-list key: []. Pure.
static func artefact_entries(codex: Dictionary) -> Array:
	var raw = codex.get("artifacts_found", [])
	if not (raw is Array):
		return []
	return (raw as Array).filter(func(e): return e is Dictionary)


## The finder's fate (pure): {id, name, hire_day, death_day} when the codex's fallen heroes hold the same id (numbers
## compared as numbers: a loaded codex has floats), the same name AND, when both record it, the same hire day
## (the save system's same-hero rule; review P3); else {}.
static func finder_fate(entry: Dictionary, codex: Dictionary) -> Dictionary:
	var fid = entry.get("found_by_id")
	var fname := str(entry.get("found_by", ""))
	if not (fid is int or fid is float) or fname == "":
		return {}
	var fallen = codex.get("fallen_heroes", [])
	if not (fallen is Array):
		return {}
	for h in fallen:
		if not (h is Dictionary):
			continue
		var hid = h.get("id")
		if not ((hid is int or hid is float) and int(hid) == int(fid) and str(h.get("name", "")) == fname):
			continue
		var eh = entry.get("found_by_hire_day")
		var fh = h.get("hire_day")
		if (eh is int or eh is float) and (fh is int or fh is float) and int(eh) != int(fh):
			continue
		return {"id": hid, "name": fname, "hire_day": fh, "death_day": h.get("death_day", h.get("day_fallen"))}
	return {}


## "Run 2 · Day 14" (an entry from before Story 18.3 has no run: "Day 14"). Pure.
static func when_line(entry: Dictionary, cfg: Dictionary) -> String:
	var run = entry.get("run")
	if run is int or run is float:
		return UI.text(cfg, "artefact_run_day", {"run": UI.num(run), "day": UI.num(entry.get("found_day"))})
	return UI.text(cfg, "artefact_day", {"day": UI.num(entry.get("found_day"))})


## "Found by Nina, Healer" (no class: "Found by Nina"); no finder recorded: "Finder unknown". Pure.
static func finder_line(entry: Dictionary, cfg: Dictionary) -> String:
	var who := str(entry.get("found_by", ""))
	if who == "":
		return UI.text(cfg, "artefact_finder_unknown")
	var cls := str(entry.get("found_by_class", ""))
	return UI.text(cfg, "artefact_found_by", {"name": who, "class": cls}) if cls != "" else UI.text(cfg, "artefact_found_by_name", {"name": who})


func build(left: VBoxContainer, right: VBoxContainer, ctx: Dictionary) -> void:
	_ctx = ctx
	_right = right
	var cfg: Dictionary = ctx.cfg
	entries = artefact_entries(ctx.codex if ctx.codex is Dictionary else {})
	var sc := UI.scroll("ArtefactScroll")
	left.add_child(sc)
	var list := VBoxContainer.new()
	list.name = "ArtefactList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	sc.add_child(list)
	if entries.is_empty():
		var empty := UI.label(cfg, UI.text(cfg, "artefacts_empty"), "body", true, true)
		empty.name = "Empty"
		list.add_child(empty)
		return
	var group := ButtonGroup.new()
	for i in entries.size():
		var e: Dictionary = entries[i]
		var row := UI.list_row(cfg, str(e.get("name", e.get("id", "?"))), when_line(e, cfg), group)
		row.name = "Row%d" % i
		row.pressed.connect(show_entry.bind(i))
		list.add_child(row)
		row_nodes.append(row)
	var first := 0
	var f = ctx.get("focus")
	if (f is int or f is float) and int(f) >= 0 and int(f) < entries.size():
		first = int(f)
	show_entry(first)


## Show artefact `i` on the right page and count it as read.
func show_entry(i: int) -> void:
	if i < 0 or i >= entries.size() or _right == null:
		return
	selected = i
	for k in row_nodes.size():
		(row_nodes[k] as Button).set_pressed_no_signal(k == i)
	for c in _right.get_children():
		_right.remove_child(c)
		c.queue_free()
	var cfg: Dictionary = _ctx.cfg
	var codex: Dictionary = _ctx.codex if _ctx.codex is Dictionary else {}
	var e: Dictionary = entries[i]
	var title := UI.label(cfg, str(e.get("name", e.get("id", "?"))), "title", false, true)
	title.name = "PageName"
	_right.add_child(title)
	var when := UI.label(cfg, when_line(e, cfg), "small", true)
	when.name = "PageWhen"
	_right.add_child(when)
	var desc := UI.label(cfg, str(e.get("description", "")), "body", false, true)
	desc.name = "PageDescription"
	_right.add_child(desc)
	var finder := UI.label(cfg, finder_line(e, cfg), "body", true, true)
	finder.name = "PageFinder"
	_right.add_child(finder)
	var book = _ctx.get("book")
	var fate := finder_fate(e, codex)
	if not fate.is_empty():
		var fell := UI.label(cfg, UI.text(cfg, "artefact_finder_fell", {"name": fate.name, "day": UI.num(fate.death_day)}), "body", false, true)
		fell.name = "PageFell"
		_right.add_child(fell)
		var link := UI.book_button(cfg, UI.text(cfg, "artefact_see_fallen"))
		link.name = "SeeFallen"
		link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if book != null and is_instance_valid(book) and book.has_method("show_chapter"):
			link.pressed.connect(book.show_chapter.bind("fallen", {"id": fate.id, "name": fate.name, "hire_day": fate.hire_day}))
		_right.add_child(link)
	if book != null and is_instance_valid(book) and book.has_method("note_read"):
		book.note_read("artefacts", "%s#%d" % [str(e.get("id", "?")), i])


## Turn to the next (1) or previous (-1) artefact, wrapping.
func turn(dir: int) -> void:
	if entries.size() <= 1:
		return
	show_entry(posmod(selected + dir, entries.size()))
