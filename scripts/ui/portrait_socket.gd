class_name PortraitSocket
extends TextureRect
## Shared portrait component (Story 7.5). One implementation, used by the Roster panel (Epic 4)
## and the End-of-Day Reveal (Epic 7). Always renders SOMETHING valid — never a broken image.
##
## Resolution priority: emotional-state variant → neutral portrait (Tarot card) → legacy class
## portrait → class-colored silhouette fallback. Class colours are data-driven (class_colors.json).

const CLASS_COLORS_PATH := "res://data/config/class_colors.json"
static var _class_colors: Dictionary = {}
static var _silhouette_cache: Dictionary = {}

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
