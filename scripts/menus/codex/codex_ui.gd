# codex_ui.gd — the Codex's words and look (Stories 18.1-18.5), shared by the book (scripts/menus/codex_menu.gd), its
# chapters (scripts/menus/codex/*_chapter.gd) and the book in the hall (scripts/game/codex_lectern.gd).
#
# Everything comes from data/config/codex_book.json, read once a session and merged over DEFAULTS (the shipped values):
# a missing or broken file, or a missing or bad key, uses the default and warns once a session (never a broken book).
# The look is a placeholder drawn in code until Story 25.19/25.20's art (the colours under `placeholder`).
# Static helpers only; no class_name, no autoload names (loaded by path).
extends RefCounted

const CONFIG_PATH := "res://data/config/codex_book.json"

## The shipped codex_book.json (keep the two in step): what a missing or bad key falls back to.
const DEFAULTS := {
	"chapters": [
		{"id": "tarot", "tab": "Tarot Cards", "title": "The Arcana"},
		{"id": "fallen", "tab": "Fallen Heroes", "title": "The Fallen"},
		{"id": "artefacts", "tab": "Prior Artefacts", "title": "Prior Artefacts"},
		{"id": "history", "tab": "Guild History", "title": "Guild History"},
	],
	"size": [1600, 900],
	"max_screen_fraction": 0.92,
	"spread": "",
	"spread_margins": [48, 48, 48, 48],
	"pages": {"left": [0.055, 0.075, 0.405, 0.85], "right": [0.54, 0.075, 0.405, 0.85]},
	"placeholder": {
		"cover": "#3a2418", "cover_edge": "#1e120b", "page": "#e8dcc0", "page_edge": "#cbb68e", "gutter": "#a8916a",
		"ink": "#2b1d14", "muted_ink": "#6b5440", "accent": "#2f9c8e", "eye": "#3fb7a6", "tab": "#5a2e22",
		"tab_active": "#8a4a2e", "tab_text": "#ecdcbc", "highlight": "#d8c49a",
	},
	"font_sizes": {"title": 30, "heading": 21, "body": 17, "small": 14},
	"lectern_body": "",
	"lectern_prompt": "Press E - Read the Codex",
	"lectern_glow": {"min": 0.6, "max": 1.6, "period": 3.0},
	"text": {
		"close": "Close",
		"stub": "This chapter is not written yet.",
		"fallen_empty": "No heroes have fallen yet.",
		"fallen_count": "{n} fallen",
		"fallen_epigraph": "They went out through that door. The book keeps them now.",
		"fallen_detail": "Hired Day {hired} · Fell Day {fell} · {missions} missions completed",
		"tarot_counter": "{n} / {total} Revealed",
		"tarot_major": "Major Arcana",
		"tarot_arcana_major": "Major Arcana · {numeral}",
		"tarot_arcana_minor": "Minor Arcana · {suit}",
		"tarot_start_line": "Known to the guild from its first day.",
		"tarot_revealed_line": "First revealed when {adventurer} {event}.",
		"tarot_no_lore": "Its story has not been written yet.",
		"tarot_secret_label": "Secret meaning: ",
		"tarot_none": "No card has been revealed yet.",
		"tarot_prev": "‹ Previous",
		"tarot_next": "Next ›",
		"artefacts_empty": "No artefacts recovered yet",
		"artefact_run_day": "Run {run} · Day {day}",
		"artefact_day": "Day {day}",
		"artefact_found_by": "Found by {name}, {class}",
		"artefact_found_by_name": "Found by {name}",
		"artefact_finder_unknown": "Finder unknown",
		"artefact_finder_fell": "{name} fell on Day {day}.",
		"artefact_see_fallen": "See The Fallen",
		"history_totals": {"runs": "Runs", "best_day": "Best Day", "gold": "Gold Earned", "missions": "Missions"},
		"history_empty": "Your guild's history has yet to be written",
		"history_guild_fallback": "The guild of run {run}",
		"history_guild_unknown": "A guild",
		"history_days": "Days survived: {n}",
		"history_lost": "Adventurers lost: {n}",
		"history_gold_peak": "Gold at its peak: {n}",
		"history_fame": "Fame: {n}",
		"history_carried": "Carried forward: {name}, {class}",
		"history_carried_name": "Carried forward: {name}",
		"history_wiped": "Guild Wiped",
		"history_no_heir": "No heir carried forward",
		"history_outcome_wiped": "Wiped",
		"history_outcome_no_heir": "No heir",
		"history_row": "{days} days · {outcome}",
		"history_missions": "Missions completed: {n}",
		"history_hired": "Adventurers hired: {n}",
		"history_causes": {"bankruptcy": "Fell to the tax collector.", "soft_lock": "No hands left, and no coin to hire more.",
			"no_survivors": "No one came back.", "fallback": "The guild fell."},
		"history_reading": "The cards were read. The guild passed on.",
	},
}

static var _config: Dictionary = {}
static var _config_loaded := false
static var _warned: Dictionary = {}
## How many fallback warnings the Codex gave this session (each kind once); tests read and reset it.
static var warnings := 0


## codex_book.json merged over DEFAULTS, read once a session.
static func config() -> Dictionary:
	if not _config_loaded:
		_config_loaded = true
		var raw = null
		if FileAccess.file_exists(CONFIG_PATH):
			raw = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		_config = merged_config(raw)
	return _config


## Tests: use `cfg` (merged over DEFAULTS, so it may hold only the keys under test); null: read the file again next time.
static func set_config(cfg) -> void:
	_config_loaded = cfg is Dictionary
	_config = merged_config(cfg) if cfg is Dictionary else {}


## `raw` over DEFAULTS (pure but for its warnings): a missing or wrongly typed key (at any depth) takes its default; one
## warning names them all. Not a Dictionary: the defaults, one warning. Keys DEFAULTS doesn't know are kept.
static func merged_config(raw) -> Dictionary:
	if not (raw is Dictionary):
		warn_once("config", "[Codex] fallback: %s is missing or not a JSON object; the book uses its built-in words and look" % CONFIG_PATH)
		return DEFAULTS.duplicate(true)
	var bad: Array = []
	var out: Dictionary = _merge(DEFAULTS, raw, "", bad)
	if not bad.is_empty():
		warn_once("config_keys", "[Codex] fallback: %s has no usable %s; their defaults are used" % [CONFIG_PATH, bad])
	return out


static func _merge(defaults: Dictionary, raw: Dictionary, prefix: String, bad: Array) -> Dictionary:
	var out: Dictionary = {}
	for k in defaults:
		var d = defaults[k]
		if not raw.has(k):
			out[k] = d.duplicate(true) if (d is Dictionary or d is Array) else d
			if not (prefix == "text." or prefix.begins_with("text.")):   # a missing line is fine: its default is the text
				bad.append(prefix + str(k))
			continue
		var v = raw[k]
		if d is Dictionary and v is Dictionary:
			out[k] = _merge(d, v, prefix + str(k) + ".", bad)
		elif _usable(str(k), d, v):
			out[k] = v.duplicate(true) if (v is Dictionary or v is Array) else v
		else:
			out[k] = d.duplicate(true) if (d is Dictionary or d is Array) else d
			bad.append(prefix + str(k))
	for k in raw:
		if not out.has(k):
			out[k] = raw[k]
	return out


static func _usable(key: String, d, v) -> bool:
	var num := func(x): return x is int or x is float
	match key:
		"chapters":
			return v is Array and not (v as Array).is_empty() and (v as Array).all(func(c): return c is Dictionary and str(c.get("id", "")) != "")
		"size":
			return v is Array and (v as Array).size() == 2 and (v as Array).all(func(x): return (x is int or x is float) and float(x) > 0.0)
		"spread_margins":
			return v is Array and (v as Array).size() == 4 and (v as Array).all(num)
		"left", "right":
			return v is Array and (v as Array).size() == 4 and (v as Array).all(num)
		"max_screen_fraction":
			return num.call(v) and float(v) > 0.2 and float(v) <= 1.0
	if num.call(d):
		return num.call(v)
	return typeof(v) == typeof(d)


## Warn once a session per `key`.
static func warn_once(key: String, msg: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	warnings += 1
	push_warning(msg)


static func reset_warnings() -> void:
	_warned = {}
	warnings = 0


## A line of the book's text with its {x} filled in.
static func text(cfg: Dictionary, key: String, values := {}) -> String:
	var t = cfg.get("text", {}).get(key) if cfg.get("text") is Dictionary else null
	if t == null:
		t = DEFAULTS.text.get(key, key)
	var s := str(t)
	return s.format(values) if not values.is_empty() else s


## A placeholder colour.
static func color(cfg: Dictionary, key: String) -> Color:
	var p = cfg.get("placeholder", {})
	var hex = p.get(key, DEFAULTS.placeholder.get(key, "#ff00ff")) if p is Dictionary else DEFAULTS.placeholder.get(key, "#ff00ff")
	return Color.from_string(str(hex), Color.from_string(str(DEFAULTS.placeholder.get(key, "#ff00ff")), Color.MAGENTA))


static func font_size(cfg: Dictionary, key: String) -> int:
	var f = cfg.get("font_sizes", {})
	var v = f.get(key) if f is Dictionary else null
	return int(v) if (v is int or v is float) and float(v) > 4.0 else int(DEFAULTS.font_sizes.get(key, 17))


## A number from codex.dat as text: JSON floats as ints; anything else "?".
static func num(v) -> String:
	return str(int(v)) if (v is int or v is float) else "?"


## A label in the book's ink: size "title" / "heading" / "body" / "small"; muted (the second ink); wrapped.
static func label(cfg: Dictionary, s: String, size := "body", muted := false, wrap := false) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", font_size(cfg, size))
	l.add_theme_color_override("font_color", color(cfg, "muted_ink" if muted else "ink"))
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 120
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A flat StyleBox: `bg` filled (alpha 0 = none), a `border` colour of `width` px (0 = none), rounded `radius`.
static func box(bg: Color, border := Color(0, 0, 0, 0), width := 0, radius := 4) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.draw_center = bg.a > 0.0
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	b.content_margin_left = 8
	b.content_margin_right = 8
	b.content_margin_top = 4
	b.content_margin_bottom = 4
	return b


## A list row a reader clicks (artefacts, history): a toggle Button holding a title line and a muted line, in `group`.
## Its `pressed` is the caller's; the selected row shows the highlight.
static func list_row(cfg: Dictionary, title: String, sub: String, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = group
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 50)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hi := color(cfg, "highlight")
	b.add_theme_stylebox_override("normal", box(Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", box(Color(hi.r, hi.g, hi.b, 0.5)))
	b.add_theme_stylebox_override("pressed", box(hi, color(cfg, "accent"), 2))
	b.add_theme_stylebox_override("hover_pressed", box(hi, color(cfg, "accent"), 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_top = 3
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := label(cfg, title, "body")
	t.name = "Title"
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	v.add_child(t)
	var s := label(cfg, sub, "small", true)
	s.name = "Sub"
	v.add_child(s)
	b.add_child(v)
	return b


## A plain book button (Previous / Next, a link), in the book's colours.
static func book_button(cfg: Dictionary, s: String) -> Button:
	var b := Button.new()
	b.text = s
	b.focus_mode = Control.FOCUS_NONE
	var edge := color(cfg, "page_edge")
	b.add_theme_stylebox_override("normal", box(Color(edge.r, edge.g, edge.b, 0.55), color(cfg, "muted_ink"), 1))
	b.add_theme_stylebox_override("hover", box(color(cfg, "highlight"), color(cfg, "accent"), 1))
	b.add_theme_stylebox_override("pressed", box(color(cfg, "highlight"), color(cfg, "accent"), 2))
	b.add_theme_stylebox_override("disabled", box(Color(edge.r, edge.g, edge.b, 0.25), Color(0, 0, 0, 0), 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, color(cfg, "ink"))
	b.add_theme_color_override("font_disabled_color", color(cfg, "muted_ink"))
	b.add_theme_font_size_override("font_size", font_size(cfg, "body"))
	return b


## A vertical scroll area that fills the page below what's above it.
static func scroll(name := "Scroll") -> ScrollContainer:
	var s := ScrollContainer.new()
	s.name = name
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return s
