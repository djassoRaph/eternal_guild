# history_chapter.gd — the Codex's Guild History chapter (Story 18.4, DC-9).
#
# The left page: the all-time totals (runs, best day, gold earned, missions) and one row per run's end from the codex's
# `guild_history` (Story 13.4 writes one at a fall; Epics 21/22 will add The Reading's), newest first. The right page: the
# selected run (the newest when the chapter opens): the guild's name (Story 5.1 names guilds; until then "The guild of run
# 2"), the date and the cause, days survived, adventurers lost, gold at its peak, Fame (only when the entry has it: Epic
# 20), and the heir ("Carried forward: Nina, Healer"; none: "Guild Wiped" when no one survived, else "No heir carried
# forward"). Read only: the run's end writes the entry, never the book. Each page shown is a read; the arrows turn pages.
# Loaded by path; no class name, no autoload names (the book passes the codex).
extends RefCounted

const UI := preload("res://scripts/menus/codex/codex_ui.gd")
const TOTALS := [["runs", "total_runs"], ["best_day", "best_day_reached"], ["gold", "total_gold_earned"], ["missions", "total_missions_completed"]]

var entries: Array = []      # history_entries() (tests read it)
var row_nodes: Array = []
var selected := -1
var _ctx: Dictionary = {}
var _right: VBoxContainer


## The run entries, newest first (the list is only ever appended to, so the reverse of its order; an entry updated in place
## keeps its place); junk skipped; a missing or non-list key: []. Pure.
static func history_entries(codex: Dictionary) -> Array:
	var raw = codex.get("guild_history", [])
	if not (raw is Array):
		return []
	var out: Array = (raw as Array).filter(func(e): return e is Dictionary)
	out.reverse()
	return out


## An entry's lines (pure): {guild, date, cause, days, lost, gold_peak, fame, heir, outcome, missions, hired, row}.
## A missing number reads "?", never "null"; Fame is "" unless the entry has it.
static func history_view(entry: Dictionary, cfg: Dictionary) -> Dictionary:
	var run = entry.get("run")
	var guild := str(entry.get("guild_name")) if entry.get("guild_name") is String else ""
	if guild == "":
		guild = UI.text(cfg, "history_guild_fallback", {"run": UI.num(run)}) if (run is int or run is float) else UI.text(cfg, "history_guild_unknown")
	var heir := ""
	var outcome := ""
	var h = entry.get("legacy_adventurer")
	if h is Dictionary and str(h.get("name", "")) != "":
		var cls := str(h.get("class", ""))
		heir = UI.text(cfg, "history_carried", {"name": str(h.name), "class": cls}) if cls != "" else UI.text(cfg, "history_carried_name", {"name": str(h.name)})
		outcome = str(h.name)
	elif h is String and h != "":
		heir = UI.text(cfg, "history_carried_name", {"name": h})
		outcome = h
	else:
		var s = entry.get("survivors")
		if (s is int or s is float) and int(s) > 0:
			heir = UI.text(cfg, "history_no_heir")
			outcome = UI.text(cfg, "history_outcome_no_heir")
		else:
			heir = UI.text(cfg, "history_wiped")
			outcome = UI.text(cfg, "history_outcome_wiped")
	var cause := ""
	if str(entry.get("ending", "")) == "reading":
		cause = UI.text(cfg, "history_reading")
	else:
		var causes = cfg.get("text", {}).get("history_causes", {}) if cfg.get("text") is Dictionary else {}
		if not (causes is Dictionary):
			causes = UI.DEFAULTS.text.history_causes
		var key := str(entry.get("cause", ""))
		cause = str(causes.get(key, causes.get("fallback", UI.DEFAULTS.text.history_causes.fallback)))
	var ts = entry.get("timestamp")
	var fame = entry.get("fame")
	var days := UI.num(entry.get("days_survived"))
	return {"guild": guild, "date": Time.get_date_string_from_unix_time(int(ts)) if (ts is int or ts is float) else "",
		"cause": cause, "days": UI.text(cfg, "history_days", {"n": days}),
		"lost": UI.text(cfg, "history_lost", {"n": UI.num(entry.get("adventurers_lost"))}),
		"gold_peak": UI.text(cfg, "history_gold_peak", {"n": UI.num(entry.get("gold_peak"))}),
		"fame": UI.text(cfg, "history_fame", {"n": UI.num(fame)}) if (fame is int or fame is float) else "",
		"heir": heir, "outcome": outcome,
		"missions": UI.text(cfg, "history_missions", {"n": UI.num(entry.get("missions_completed"))}),
		"hired": UI.text(cfg, "history_hired", {"n": UI.num(entry.get("adventurers_hired"))}),
		"row": UI.text(cfg, "history_row", {"days": days, "outcome": outcome})}


func build(left: VBoxContainer, right: VBoxContainer, ctx: Dictionary) -> void:
	_ctx = ctx
	_right = right
	var cfg: Dictionary = ctx.cfg
	var codex: Dictionary = ctx.codex if ctx.codex is Dictionary else {}
	var labels = cfg.get("text", {}).get("history_totals", {}) if cfg.get("text") is Dictionary else {}
	if not (labels is Dictionary):
		labels = UI.DEFAULTS.text.history_totals
	var row := HBoxContainer.new()
	row.name = "Totals"
	left.add_child(row)
	for pair in TOTALS:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		var v := UI.label(cfg, UI.num(codex.get(pair[1], 0)), "heading")
		v.name = "Total_" + pair[0]
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(v)
		var l := UI.label(cfg, str(labels.get(pair[0], UI.DEFAULTS.text.history_totals[pair[0]])), "small", true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		row.add_child(col)
	entries = history_entries(codex)
	var sc := UI.scroll("HistoryScroll")
	left.add_child(sc)
	var list := VBoxContainer.new()
	list.name = "HistoryList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	sc.add_child(list)
	if entries.is_empty():
		var empty := UI.label(cfg, UI.text(cfg, "history_empty"), "body", true, true)
		empty.name = "Empty"
		list.add_child(empty)
		return
	var group := ButtonGroup.new()
	for i in entries.size():
		var view := history_view(entries[i], cfg)
		var r := UI.list_row(cfg, view.guild, view.row, group)
		r.name = "Row%d" % i
		r.pressed.connect(show_run.bind(i))
		list.add_child(r)
		row_nodes.append(r)
	var first := 0
	var f = ctx.get("focus")
	if f is int or f is float:
		for i in entries.size():
			var run = entries[i].get("run")
			if (run is int or run is float) and int(run) == int(f):
				first = i
	show_run(first)


## Show run entry `i` on the right page and count it as read.
func show_run(i: int) -> void:
	if i < 0 or i >= entries.size() or _right == null:
		return
	selected = i
	for k in row_nodes.size():
		(row_nodes[k] as Button).set_pressed_no_signal(k == i)
	for c in _right.get_children():
		_right.remove_child(c)
		c.queue_free()
	var cfg: Dictionary = _ctx.cfg
	var e: Dictionary = entries[i]
	var view := history_view(e, cfg)
	var lines := [["PageGuild", view.guild, "title", false], ["PageDate", view.date, "small", true], ["PageCause", view.cause, "body", true],
		["PageDays", view.days, "body", false], ["PageLost", view.lost, "body", false], ["PageGoldPeak", view.gold_peak, "body", false],
		["PageFame", view.fame, "body", false], ["PageHeir", view.heir, "heading", false], ["PageMissions", view.missions, "small", true],
		["PageHired", view.hired, "small", true]]
	for ln in lines:
		if str(ln[1]) == "":
			continue
		var l := UI.label(cfg, str(ln[1]), ln[2], ln[3], true)
		l.name = ln[0]
		_right.add_child(l)
	var book = _ctx.get("book")
	if book != null and is_instance_valid(book) and book.has_method("note_read"):
		var run = e.get("run")
		book.note_read("history", "run_%s" % (UI.num(run) if (run is int or run is float) else str(i)))


## Turn to the next (1) or previous (-1) run, wrapping.
func turn(dir: int) -> void:
	if entries.size() <= 1:
		return
	show_run(posmod(selected + dir, entries.size()))
