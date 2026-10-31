class_name PortraitSocket
extends TextureRect
## Shared portrait component (Story 7.5). One implementation, used by the Roster panel (Epic 4)
## and the End-of-Day Reveal (Epic 7). Always renders SOMETHING valid — never a broken image.
##
## Resolution priority: emotional-state variant → neutral portrait (Tarot card) → legacy class
## portrait → class-colored silhouette fallback. Class colours are data-driven (class_colors.json).

const CLASS_COLORS_PATH := "res://data/config/class_colors.json"
const CARD_CONFIG_PATH := "res://data/config/tarot_card.json"   # Story 4.2: the Tarot card's look
static var _class_colors: Dictionary = {}
static var _silhouette_cache: Dictionary = {}
static var _card_config: Dictionary = {}
static var _card_config_loaded := false
static var _plate_warned: Dictionary = {}   # class -> true: a card drawn on the plate is warned about once a session

## Apply the resolved portrait to THIS node (when the socket is used as an instanced TextureRect).
func set_adventurer(adv: Dictionary, emotional_state: String = "") -> void:
	texture = resolve_texture(adv, emotional_state)

## Shared resolver — returns a valid Texture2D for any adventurer/recruit dict. Never null.
static func resolve_texture(adv: Dictionary, emotional_state: String = "") -> Texture2D:
	var base: String = adv.get("portrait", "")

	# 1. Emotional-state variant, e.g. ".../major_00_the_fool_wounded.png"
	if emotional_state != "" and base != "":
		var variant := base.get_basename() + "_" + emotional_state + "." + base.get_extension()
		if ResourceLoader.exists(variant):
			return load(variant)

	# 2. Neutral portrait (the Tarot card path from Epic 4.1)
	if base != "" and ResourceLoader.exists(base):
		return load(base)

	# 3. Legacy class portrait (existing art for the base classes)
	var cls: String = str(adv.get("class", ""))
	if cls != "":
		var class_path := "res://assets/portraits/" + cls.to_lower() + ".png"
		if ResourceLoader.exists(class_path):
			return load(class_path)

	# 4. Class-colored silhouette fallback — never crashes
	push_warning("[PortraitSocket] portrait missing for adventurer %s, rendering fallback" % str(adv.get("id", "?")))
	return _silhouette_for(cls)

## The art on an adventurer's or applicant's Tarot card (Story 4.2, decision D-1: class silhouettes in the card frame
## until the paintings are funded): {texture, tint, painting}. The card's own painting at the record's `portrait` path
## when that file exists (commissioned art drops in there, no code change), else the class silhouette named in
## tarot_card.json, tinted by its silhouette_tint, else the class-coloured plate. The texture is never null. Unlike
## resolve_texture() it never falls back to the class portrait paintings (assets/portraits/, placeholders).
static func resolve_card_art(adv: Dictionary) -> Dictionary:
	var base := str(adv.get("portrait", ""))
	if base != "" and ResourceLoader.exists(base):
		var painting = load(base)
		if painting is Texture2D:
			return {"texture": painting, "tint": Color.WHITE, "painting": true}
	var cls := str(adv.get("class", ""))
	var cfg := card_config()
	var sil = cfg.get("silhouettes", {})
	var path := str(sil.get(cls, "")) if sil is Dictionary else ""
	if path != "" and ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return {"texture": tex, "tint": silhouette_tint(cls, cfg), "painting": false}
	if not _plate_warned.has(cls):
		_plate_warned[cls] = true
		push_warning("[PortraitSocket] fallback: no card silhouette for class '%s'; drawing the class plate" % cls)
	return {"texture": _silhouette_for(cls), "tint": Color.WHITE, "painting": false}

## The silhouettes' tint from a card config: "class" (class_colors.json, the default) or a colour string.
static func silhouette_tint(cls: String, cfg: Dictionary) -> Color:
	var t := str(cfg.get("silhouette_tint", "class"))
	if t == "class" or t == "":
		return class_color(cls)
	return Color.from_string(t, class_color(cls))

## A class's colour from class_colors.json (its default for an unknown class).
static func class_color(cls: String) -> Color:
	if _class_colors.is_empty():
		_load_class_colors()
	var classes = _class_colors.get("classes", {})
	var hex = classes.get(cls, _class_colors.get("default", "#7a7a7a")) if classes is Dictionary else _class_colors.get("default", "#7a7a7a")
	return Color.from_string(str(hex), Color(0.48, 0.48, 0.48))

## The Tarot card's look, data/config/tarot_card.json, read once a session (FileAccess: this class names no autoload).
## {} when the file is missing or isn't an object.
static func card_config() -> Dictionary:
	if not _card_config_loaded:
		_card_config_loaded = true
		_card_config = {}
		if FileAccess.file_exists(CARD_CONFIG_PATH):
			var data = JSON.parse_string(FileAccess.get_file_as_string(CARD_CONFIG_PATH))
			if data is Dictionary:
				_card_config = data
	return _card_config

## Tests: use `cfg` as the card config (null: read the file again next time) and forget the once-a-session warnings.
static func set_card_config(cfg) -> void:
	_card_config_loaded = cfg is Dictionary
	_card_config = cfg if cfg is Dictionary else {}
	_plate_warned = {}

static func _silhouette_for(cls: String) -> Texture2D:
	if _silhouette_cache.has(cls):
		return _silhouette_cache[cls]
	if _class_colors.is_empty():
		_load_class_colors()
	var hex: String = _class_colors.get("classes", {}).get(cls, _class_colors.get("default", "#7a7a7a"))
	var col := Color.from_string(hex, Color(0.48, 0.48, 0.48))
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(col)
	# Simple dark border so silhouettes read as a framed placeholder
	for x in range(64):
		for y in range(64):
			if x < 2 or x > 61 or y < 2 or y > 61:
				img.set_pixel(x, y, Color(0, 0, 0, 0.6))
	var tex := ImageTexture.create_from_image(img)
	_silhouette_cache[cls] = tex
	return tex

static func _load_class_colors() -> void:
	if not FileAccess.file_exists(CLASS_COLORS_PATH):
		_class_colors = {"classes": {}, "default": "#7a7a7a"}
		return
	var f := FileAccess.open(CLASS_COLORS_PATH, FileAccess.READ)
	if f == null:
		_class_colors = {"classes": {}, "default": "#7a7a7a"}
		return
	var data = JSON.parse_string(f.get_as_text())
	_class_colors = data if data is Dictionary else {"classes": {}, "default": "#7a7a7a"}
