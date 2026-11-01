# tarot_chapter.gd — the Codex's Tarot Cards chapter (Story 18.2; FR-71, FR-73; completes Story 17.4's navigation stub).
#
# The left page: "{n} / {total} Revealed" and every card's slot: the Major Arcana by number, then the Minor Arcana by suit
# (tarot_card.json's suit order), each by number. An unlocked card shows its face (Story 4.2's TarotCard: the painting at
# its portrait path, else its class silhouette) and its name, and opens its page; a locked one shows only the card back
# (tarot_card.json `back`: a placeholder drawn in code until Story 25.22), no name, no tooltip, no hover.
# The right page: the card's page: the card, its name, "Major Arcana · VII", its archetype, its personality note, its secret
# meaning, how it was revealed; Previous / Next (and the arrow keys, through the book) turn through the unlocked cards.
# The chapter opens on the first unlocked card (DC-6), so a reader sees an entry at once; each page shown is a read
# (the book's note_read: the playtest's "read a Codex entry").
# Unlocked (DC-4) = the deck's `unlock_trigger: "start"` cards (the four Major Arcana of the first run, FR-73) plus the
# codex's `tarot_unlocked` (Epic 17 writes it; Story 17.1 moves this rule into scripts/tarot/tarot_unlocks.gd). Epic 17's
# evolved and reversed cards add their fields in tarot_slots() / page_view(), the only models this chapter draws.
# Loaded by path; no class_name, no autoload names (the book passes the codex and the deck).
extends RefCounted

const UI := preload("res://scripts/menus/codex/codex_ui.gd")
const CARD_SCENE := "res://scenes/ui/TarotCard.tscn"
const CARD_SCRIPT := preload("res://scripts/ui/tarot_card.gd")
const SUIT_ORDER := ["wands", "cups", "swords", "pentacles"]
const SLOT_WIDTH := 76.0
const PAGE_CARD_WIDTH := 190.0
const COLUMNS := 7

var slots: Array = []            # tarot_slots(): [{card, unlocked}] in grid order (tests read it)
var slot_nodes: Array = []       # the slots' controls, in the same order
var unlocked_order: Array = []   # the unlocked slots' indices, in grid order
var selected := -1               # the slot whose page the right page shows
var _ctx: Dictionary = {}
var _right: VBoxContainer


## The ids of the unlocked cards (DC-4): the deck's "start" cards, then the codex's `tarot_unlocked` ids the deck knows
## (strings only, each once). A `tarot_unlocked` that isn't a list counts as none, with one warning. Pure but its warning.
static func unlocked_ids(deck: Array, codex: Dictionary) -> Array:
	var known := {}
	var out: Array = []
	for c in deck:
		if c is Dictionary:
			var id := str(c.get("id", ""))
			known[id] = true
			if str(c.get("unlock_trigger", "")) == "start" and not out.has(id):
				out.append(id)
	var extra = codex.get("tarot_unlocked", [])
	if not (extra is Array):
		UI.warn_once("tarot_unlocked", "[Codex] fallback: codex.dat tarot_unlocked is not a list; only the starting cards are revealed")
		extra = []
	for id in extra:
		if id is String and known.has(id) and not out.has(id):
			out.append(id)
	return out


## tarot_card.json's suit order (its `suits` keys), else wands, cups, swords, pentacles.
static func suit_order() -> Array:
	var s = PortraitSocket.card_config().get("suits", {})
	return (s as Dictionary).keys() if s is Dictionary and not (s as Dictionary).is_empty() else SUIT_ORDER.duplicate()


## The grid (pure): [{card, unlocked}] — the Major Arcana by number, then the Minor Arcana by suit in `suits` order, each
## by number; a card of an unknown suit last; non-Dictionary entries skipped.
static func tarot_slots(deck: Array, unlocked: Array, suits: Array = []) -> Array:
	var order := suits if not suits.is_empty() else suit_order()
	var tagged: Array = []
	for i in deck.size():
		var c = deck[i]
		if c is Dictionary:
			tagged.append([_rank(c, order), i, c])
	tagged.sort_custom(_by_rank)
	var out: Array = []
	for t in tagged:
		out.append({"card": t[2], "unlocked": unlocked.has(str(t[2].get("id", "")))})
	return out


static func _rank(c: Dictionary, order: Array) -> Array:
	var n = c.get("number")
	var num := float(n) if (n is int or n is float) else 999.0
	if str(c.get("arcana", "")) == "major":
		return [0, num]
	var g := order.find(str(c.get("suit", "")))
	return [1 + g if g >= 0 else 1 + order.size(), num]


static func _by_rank(a: Array, b: Array) -> bool:
	if a[0][0] != b[0][0]:
		return a[0][0] < b[0][0]
	if a[0][1] != b[0][1]:
		return a[0][1] < b[0][1]
	return a[1] < b[1]


## A slot's group heading id: "major", the suit, or "other".
static func slot_group(card: Dictionary, order: Array) -> String:
	if str(card.get("arcana", "")) == "major":
		return "major"
	var s := str(card.get("suit", ""))
	return s if order.has(s) else "other"


## A suit's label from tarot_card.json (else the id, capitalised).
static func suit_label(suit) -> String:
	var s = PortraitSocket.card_config().get("suits", {})
	var e = s.get(str(suit)) if s is Dictionary else null
	return str(e.get("label", str(suit).capitalize())) if e is Dictionary else str(suit).capitalize()


## A card's art in the book: its painting, else the silhouette of its `silhouette_class` (DC-4), else the plate.
static func art_for(card: Dictionary) -> Dictionary:
	return PortraitSocket.resolve_card_art({"portrait": card.get("portrait", ""), "class": str(card.get("silhouette_class", ""))})


## A card's page (pure): {id, name, arcana_line, archetype, lore, secret, unlock_line}. Never blank: a card without its
## story says so. The unlock line: a starting card's; else what Story 17.4 will write at the reveal
## (codex.tarot_unlock_context[id] = {adventurer, event}); else none.
static func page_view(card: Dictionary, codex: Dictionary, cfg: Dictionary) -> Dictionary:
	var id := str(card.get("id", ""))
	var arcana := ""
	if str(card.get("arcana", "")) == "major":
		var n = card.get("number")
		arcana = UI.text(cfg, "tarot_arcana_major", {"numeral": CARD_SCRIPT.roman(int(n)) if (n is int or n is float) else "?"})
	else:
		arcana = UI.text(cfg, "tarot_arcana_minor", {"suit": suit_label(card.get("suit"))})
	var lore := str(card.get("codex_lore", ""))
	var secret := str(card.get("codex_secret", ""))
	var unlock := ""
	if str(card.get("unlock_trigger", "")) == "start":
		unlock = UI.text(cfg, "tarot_start_line")
	else:
		var all = codex.get("tarot_unlock_context", {})
		var u = all.get(id) if all is Dictionary else null
		if u is Dictionary and str(u.get("adventurer", "")) != "" and str(u.get("event", "")) != "":
			unlock = UI.text(cfg, "tarot_revealed_line", {"adventurer": str(u.adventurer), "event": str(u.event)})
	return {"id": id, "name": str(card.get("name", "")), "arcana_line": arcana, "archetype": str(card.get("archetype", "")),
		"lore": lore if lore != "" else UI.text(cfg, "tarot_no_lore"),
		"secret": (UI.text(cfg, "tarot_secret_label") + secret) if secret != "" else "", "unlock_line": unlock}


func build(left: VBoxContainer, right: VBoxContainer, ctx: Dictionary) -> void:
	_ctx = ctx
	_right = right
	var cfg: Dictionary = ctx.cfg
	var deck: Array = ctx.deck if ctx.deck is Array else []
	var codex: Dictionary = ctx.codex if ctx.codex is Dictionary else {}
	var order := suit_order()
	slots = tarot_slots(deck, unlocked_ids(deck, codex), order)
	unlocked_order = []
	for i in slots.size():
		if slots[i].unlocked:
			unlocked_order.append(i)
	var counter := UI.label(cfg, UI.text(cfg, "tarot_counter", {"n": unlocked_order.size(), "total": slots.size()}), "heading", true)
	counter.name = "Counter"
	left.add_child(counter)
	var sc := UI.scroll("TarotScroll")
	left.add_child(sc)
	var list := VBoxContainer.new()
	list.name = "TarotGrid"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	sc.add_child(list)
	var group := "?"
	var grid: GridContainer = null
	var bg := ButtonGroup.new()
	for i in slots.size():
		var g := slot_group(slots[i].card, order)
		if g != group:
			group = g
			var heading := UI.label(cfg, UI.text(cfg, "tarot_major") if g == "major" else suit_label(g), "body", true)
			heading.name = "Heading_" + g
			list.add_child(heading)
			grid = GridContainer.new()
			grid.name = "Grid_" + g
			grid.columns = COLUMNS
			grid.add_theme_constant_override("h_separation", 4)
			grid.add_theme_constant_override("v_separation", 4)
			list.add_child(grid)
		var node := _slot(i, cfg, bg)
		grid.add_child(node)
		slot_nodes.append(node)
	if unlocked_order.is_empty():
		var none := UI.label(cfg, UI.text(cfg, "tarot_none"), "body", true, true)
		none.name = "None"
		right.add_child(none)
		return
	var first: int = unlocked_order[0]
	if ctx.get("focus") is String:
		for i in unlocked_order:
			if str(slots[i].card.get("id", "")) == ctx.focus:
				first = i
	show_card(first)


## Show slot `i`'s page on the right page (an unlocked card only) and count it as read.
func show_card(i: int) -> void:
	if i < 0 or i >= slots.size() or not slots[i].unlocked or _right == null:
		return
	selected = i
	for k in slot_nodes.size():
		if slot_nodes[k] is Button:
			(slot_nodes[k] as Button).set_pressed_no_signal(k == i)
	for c in _right.get_children():
		_right.remove_child(c)
		c.queue_free()
	var cfg: Dictionary = _ctx.cfg
	var card: Dictionary = slots[i].card
	var view := page_view(card, _ctx.codex if _ctx.codex is Dictionary else {}, cfg)
	var top := HBoxContainer.new()
	top.name = "PageTop"
	top.add_theme_constant_override("separation", 16)
	_right.add_child(top)
	var face = load(CARD_SCENE).instantiate()
	face.name = "PageCard"
	face.custom_minimum_size = Vector2(PAGE_CARD_WIDTH, PortraitSocket.card_height(PAGE_CARD_WIDTH))
	face.set_card(card, art_for(card))
	top.add_child(face)
	var head := VBoxContainer.new()
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_theme_constant_override("separation", 6)
	top.add_child(head)
	var title := UI.label(cfg, view.name, "title", false, true)
	title.name = "PageName"
	head.add_child(title)
	var arc := UI.label(cfg, view.arcana_line, "body", true)
	arc.name = "PageArcana"
	head.add_child(arc)
	if view.archetype != "":
		var at := UI.label(cfg, view.archetype, "heading", false, true)
		at.name = "PageArchetype"
		head.add_child(at)
	if view.unlock_line != "":
		var ul := UI.label(cfg, view.unlock_line, "small", true, true)
		ul.name = "PageUnlock"
		head.add_child(ul)
	var lore := UI.label(cfg, view.lore, "body", false, true)
	lore.name = "PageLore"
	_right.add_child(lore)
	if view.secret != "":
		var sec := UI.label(cfg, view.secret, "body", true, true)
		sec.name = "PageSecret"
		_right.add_child(sec)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right.add_child(fill)
	var nav := HBoxContainer.new()
	nav.name = "PageNav"
	_right.add_child(nav)
	var prev := UI.book_button(cfg, UI.text(cfg, "tarot_prev"))
	prev.name = "Prev"
	prev.disabled = unlocked_order.size() <= 1
	prev.pressed.connect(turn.bind(-1))
	nav.add_child(prev)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(gap)
	var next := UI.book_button(cfg, UI.text(cfg, "tarot_next"))
	next.name = "Next"
	next.disabled = unlocked_order.size() <= 1
	next.pressed.connect(turn.bind(1))
	nav.add_child(next)
	var book = _ctx.get("book")
	if book != null and is_instance_valid(book) and book.has_method("note_read"):
		book.note_read("tarot", view.id)


## Turn to the next (1) or previous (-1) unlocked card, wrapping. One unlocked card or none: nothing.
func turn(dir: int) -> void:
	var n := unlocked_order.size()
	if n <= 1:
		return
	var k := unlocked_order.find(selected)
	show_card(unlocked_order[posmod(k + dir, n)])


func _slot(i: int, cfg: Dictionary, group: ButtonGroup) -> Control:
	var s: Dictionary = slots[i]
	var card: Dictionary = s.card
	var card_h := PortraitSocket.card_height(SLOT_WIDTH)
	var box: Control
	if s.unlocked:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = str(card.get("name", ""))
		var hi := UI.color(cfg, "highlight")
		b.add_theme_stylebox_override("normal", UI.box(Color(0, 0, 0, 0)))
		b.add_theme_stylebox_override("hover", UI.box(Color(hi.r, hi.g, hi.b, 0.7)))
		b.add_theme_stylebox_override("pressed", UI.box(hi, UI.color(cfg, "accent"), 3))
		b.add_theme_stylebox_override("hover_pressed", UI.box(hi, UI.color(cfg, "accent"), 3))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(show_card.bind(i))
		box = b
	else:
		box = Control.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.name = "Slot_%s" % str(card.get("id", i))
	box.custom_minimum_size = Vector2(SLOT_WIDTH + 8, card_h + 24)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 4
	v.offset_right = -4
	v.offset_top = 3
	v.add_theme_constant_override("separation", 2)
	box.add_child(v)
	var face = load(CARD_SCENE).instantiate()
	face.name = "Card"
	face.custom_minimum_size = Vector2(SLOT_WIDTH, card_h)
	face.compact = true
	if s.unlocked:
		face.set_card(card, art_for(card))
	else:
		face.set_back()
	v.add_child(face)
	var name_label := UI.label(cfg, str(card.get("name", "")) if s.unlocked else "", "small")
	name_label.name = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	name_label.custom_minimum_size = Vector2(SLOT_WIDTH, 0)
	name_label.add_theme_font_size_override("font_size", maxi(10, UI.font_size(cfg, "small") - 2))
	v.add_child(name_label)
	return box
