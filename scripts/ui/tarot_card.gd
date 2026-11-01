# tarot_card.gd — one adventurer's Tarot card, drawn (Story 4.2, decision D-1).
#
# The hire panel shows each applicant as one of these, and the roster panel (Story 4.3) shows a compact one per
# adventurer. Everything about the look comes from data/config/tarot_card.json through PortraitSocket.card_config():
# the frame texture (a placeholder until Story 25.22's frame set: swap the path there), the card's aspect, and the
# header band (a Major card's numeral, a Minor card's suit), the art window and the name band as fractions of the card.
# The art is PortraitSocket.resolve_card_art(): the card's own painting when one exists at its portrait path, else the
# class silhouette tinted, else the class-coloured plate. A frame that doesn't load draws a plain border instead (one
# warning a session). Purely visual: every node ignores the mouse, so a parent's clicks and drags work through it.
#
# The children are made in _init, so set_card() works before the card enters the tree (tests). Loaded by path: no
# class_name, and no autoload is named here (the caller passes the deck card).
extends Control

const ROMAN := [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
const DEFAULT_RECTS := {"header": [0.06, 0.025, 0.88, 0.075], "window": [0.07, 0.115, 0.86, 0.735], "footer": [0.06, 0.865, 0.88, 0.105]}

static var frame_warnings := 0   # how many times the plain-border fallback warned (once a session; tests read it)
static var back_warnings := 0    # the card back's fallback warned (Story 18.2; once a session; tests read it)

## true: no header and no name (the roster's thumbnail).
var compact := false:
	set(v):
		compact = v
		_apply_labels()

var _field: ColorRect
var _art: TextureRect
var _frame: TextureRect
var _border: Panel
var _header: Label
var _icon: TextureRect
var _name: Label
var _cfg: Dictionary = {}
var _head: Dictionary = {"text": "", "color": Color.WHITE, "icon": null}
var _card_name := ""
var _back: TextureRect           # Story 18.2: the card back (tarot_card.json `back`) over the whole card
var _back_placeholder: Panel     # ... or, with no back art, the placeholder back drawn in code
var _back_eye: Panel
var _showing_back := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_field = ColorRect.new()
	_field.name = "Field"
	_art = TextureRect.new()
	_art.name = "Art"
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_frame = TextureRect.new()
	_frame.name = "Frame"
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_border = Panel.new()
	_border.name = "FallbackBorder"
	_border.visible = false
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.set_border_width_all(3)
	box.border_color = Color(0.69, 0.55, 0.34)
	box.set_corner_radius_all(6)
	_border.add_theme_stylebox_override("panel", box)
	_header = Label.new()
	_header.name = "Header"
	_icon = TextureRect.new()
	_icon.name = "SuitIcon"
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.visible = false
	_name = Label.new()
	_name.name = "CardName"
	for l in [_header, _name]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
	_back = TextureRect.new()
	_back.name = "Back"
	_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_back.stretch_mode = TextureRect.STRETCH_SCALE
	_back.visible = false
	_back_placeholder = Panel.new()
	_back_placeholder.name = "PlaceholderCardBack"
	_back_placeholder.visible = false
	_back_eye = Panel.new()
	_back_eye.name = "Eye"
	_back_eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back_placeholder.add_child(_back_eye)
	for n in [_field, _art, _frame, _border, _header, _icon, _name, _back, _back_placeholder]:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(n)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


## Draw `card` (a tarot_deck.json entry: id, name, arcana, number, suit; {} for none) with `art` (from
## PortraitSocket.resolve_card_art: {texture, tint, painting}).
func set_card(card: Dictionary, art: Dictionary) -> void:
	_cfg = PortraitSocket.card_config()
	_showing_back = false
	_back.visible = false
	_back_placeholder.visible = false
	_field.visible = true
	_art.visible = true
	_field.color = Color.from_string(str(_cfg.get("field_color", "#231c18")), Color(0.14, 0.11, 0.09))
	_apply_frame()
	var tex = art.get("texture")
	_art.texture = tex if tex is Texture2D else null
	_art.self_modulate = art.get("tint") if art.get("tint") is Color else Color.WHITE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if art.get("painting", false) else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_head = header_for(card, _cfg)
	_card_name = str(card.get("name", "")) if card is Dictionary else ""
	_apply_labels()
	_layout()


## Show only the card's back (Story 18.2: a locked Codex slot; later the flip reveal): tarot_card.json `back` drawn over the
## whole card when it loads; "" the placeholder back drawn in code (the field colour, a gold rule, a teal eye); a path
## that doesn't load: the placeholder and ONE warning a session. set_card() turns it face up again.
func set_back() -> void:
	_cfg = PortraitSocket.card_config()
	_showing_back = true
	var path := str(_cfg.get("back", ""))
	var tex = load(path) if path != "" and ResourceLoader.exists(path) else null
	_back.texture = tex if tex is Texture2D else null
	_back.visible = tex is Texture2D
	_back_placeholder.visible = not (tex is Texture2D)
	if not (tex is Texture2D):
		var rule := Color(0.69, 0.55, 0.34)
		var b := StyleBoxFlat.new()
		b.bg_color = Color.from_string(str(_cfg.get("field_color", "#231c18")), Color(0.14, 0.11, 0.09))
		b.border_color = rule
		b.set_border_width_all(3)
		b.set_corner_radius_all(6)
		_back_placeholder.add_theme_stylebox_override("panel", b)
		var e := StyleBoxFlat.new()
		e.bg_color = Color(0.25, 0.72, 0.65)
		e.border_color = rule
		e.set_border_width_all(2)
		e.set_corner_radius_all(999)
		_back_eye.add_theme_stylebox_override("panel", e)
		if path != "" and back_warnings == 0:
			back_warnings += 1
			push_warning("[TarotCard] fallback: the card back '%s' doesn't load; drawing the placeholder back" % path)
	for n in [_field, _art, _frame, _border, _header, _icon, _name]:
		n.visible = false
	_layout()


## What this card shows, for tests and callers: {header, header_color, icon, name, art, tint, frame_fallback, back}.
func shown() -> Dictionary:
	return {"header": _header.text if _header.visible else "", "header_color": _header.get_theme_color("font_color"),
		"icon": _icon.texture if _icon.visible else null, "name": _name.text if _name.visible else "", "art": _art.texture,
		"tint": _art.self_modulate, "frame": _frame.texture if _frame.visible else null, "frame_fallback": _border.visible,
		"back": _showing_back}


## A card's header band (pure): a Major card's numeral; a Minor card's suit label in its colour (its icon instead
## when the config names a texture that loads); {} card or an unknown suit: an empty text.
static func header_for(card: Dictionary, cfg: Dictionary) -> Dictionary:
	var out := {"text": "", "color": Color.from_string(str(cfg.get("numeral_color", "#e8d8b0")), Color.WHITE), "icon": null}
	if card.is_empty():
		return out
	if str(card.get("arcana", "")) == "major":
		var n = card.get("number")
		out.text = roman(int(n)) if (n is int or n is float) else ""
		return out
	var suit = card.get("suit")
	var suits = cfg.get("suits", {})
	var s = suits.get(str(suit), {}) if (suits is Dictionary and suit is String) else {}
	if not (s is Dictionary) or s.is_empty():
		return out
	out.text = str(s.get("label", ""))
	out.color = Color.from_string(str(s.get("color", "")), out.color)
	var icon_path := str(s.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon = load(icon_path)
		if icon is Texture2D:
			out.icon = icon
	return out


## Tests: the plain-border fallback's warnings so far, and a reset (it warns once a session).
static func frame_warning_count() -> int:
	return frame_warnings


static func reset_frame_warnings() -> void:
	frame_warnings = 0


## Tests: the card back's fallback warnings so far, and a reset (Story 18.2).
static func back_warning_count() -> int:
	return back_warnings


static func reset_back_warnings() -> void:
	back_warnings = 0


## A Major Arcana numeral: 0 is "0", then I … XXI (and on). Pure.
static func roman(n: int) -> String:
	if n <= 0:
		return "0"
	var out := ""
	var left := n
	for pair in ROMAN:
		while left >= int(pair[0]):
			out += str(pair[1])
			left -= int(pair[0])
	return out


func _apply_frame() -> void:
	var path := str(_cfg.get("frame", ""))
	var tex = load(path) if path != "" and ResourceLoader.exists(path) else null
	if tex is Texture2D:
		_frame.texture = tex
		_frame.visible = true
		_border.visible = false
		return
	_frame.texture = null
	_frame.visible = false
	_border.visible = true
	if frame_warnings == 0:
		frame_warnings += 1
		push_warning("[TarotCard] fallback: the card frame '%s' doesn't load; drawing a plain border" % path)


func _apply_labels() -> void:
	if _header == null:
		return
	if _showing_back:   # Story 18.2: a card shown face down has no labels
		for n in [_header, _icon, _name]:
			n.visible = false
		return
	var icon = _head.get("icon")
	_icon.texture = icon if icon is Texture2D else null
	_icon.visible = not compact and icon is Texture2D
	_header.text = str(_head.get("text", ""))
	_header.add_theme_color_override("font_color", _head.get("color", Color.WHITE))
	_header.visible = not compact and not (icon is Texture2D)
	_name.text = _card_name
	_name.add_theme_color_override("font_color", Color.from_string(str(_cfg.get("name_color", "#e8d8b0")), Color.WHITE))
	_name.visible = not compact


func _layout() -> void:
	if _field == null:
		return
	var s := size
	_frame.position = Vector2.ZERO
	_frame.size = s
	_border.position = Vector2.ZERO
	_border.size = s
	var window := _rect("window", s)
	_field.position = window.position
	_field.size = window.size
	_art.position = window.position
	_art.size = window.size
	var head := _rect("header", s)
	_header.position = head.position
	_header.size = head.size
	_icon.position = head.position
	_icon.size = head.size
	var foot := _rect("footer", s)
	_name.position = foot.position
	_name.size = foot.size
	_header.add_theme_font_size_override("font_size", maxi(8, int(head.size.y * 0.72)))
	_name.add_theme_font_size_override("font_size", maxi(8, int(foot.size.y * 0.5)))
	_back.position = Vector2.ZERO
	_back.size = s
	_back_placeholder.position = Vector2.ZERO
	_back_placeholder.size = s
	var eye := Vector2(s.x * 0.36, s.x * 0.24)
	_back_eye.position = (s - eye) * 0.5
	_back_eye.size = eye


func _rect(key: String, s: Vector2) -> Rect2:
	var r = _cfg.get(key, DEFAULT_RECTS[key])
	if not (r is Array and r.size() == 4 and r.all(func(v): return v is int or v is float)):
		r = DEFAULT_RECTS[key]
	return Rect2(float(r[0]) * s.x, float(r[1]) * s.y, float(r[2]) * s.x, float(r[3]) * s.y)
