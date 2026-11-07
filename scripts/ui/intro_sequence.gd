# intro_sequence.gd — the New Game intro (Raphael 2026-11-07: a "power point" introduction to the lore, played "during
# the loading of the world map"). Every new run passes through it: GameManager.NEW_RUN_SCENE is this scene (the main
# menu's New Game and the fall screen's New Run both go there), and it hands over to GameManager.WORLD_MAP_SCENE, which
# loads on a thread while the slides play.
#
# The slides are data/narrative/intro.json (art path + one line each; every word DRAFT). Each fades up from black, its
# art pushing in slowly (a Ken Burns move) while its line writes itself out; it holds, then fades to black. Click,
# Space, Enter or Right goes on (a press while the line is still writing finishes the line first); holding Esc, or the
# Skip button, leaves at once. The words are Labels over the art, never baked into it (Story 10.1's rule), so the art
# and the words are swapped apart. Built in code on its own CanvasLayer at 118 (Story 10.1's story-panel layer).
# Nothing here blocks a new run: a missing or broken JSON means straight to the map, a slide without art shows on the
# dark ground. No autoload state is touched, and SaveSystem never saves here (this root isn't a player_scene).
extends Node

const DATA_PATH := "res://data/narrative/intro.json"
const LAYER := 118
const PUSH := 0.06                    # the Ken Burns push: how much the art grows over one slide
const TEXT_COLOR := Color(0.96, 0.92, 0.84)
const INK := Color(0.05, 0.035, 0.025)
const SKIP_BAR_W := 150.0
const ADVANCE_KEYS := [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_RIGHT]

var _next := "res://scenes/HexMapTest.tscn"
var _slides: Array = []
var _cps := 38.0                      # letters a second as a line writes itself out
var _fade := 0.6
var _hold := 3.5
var _skip_hold := 0.8
var _grace := 0.3

var _layer: CanvasLayer
var _art: TextureRect
var _line: Label
var _dots: Label
var _black: ColorRect
var _skip_fill: ColorRect
var _wait_label: Label

var _advance := false
var _accept_after := 0                # ms ticks: input before this is ignored (each slide's grace)
var _esc_time := 0.0
var _leaving := false
var _type_tween: Tween = null
var _push_tween: Tween = null


func _ready() -> void:
	_next = GameManager.WORLD_MAP_SCENE
	if ResourceLoader.load_threaded_request(_next) != OK:
		push_warning("[Intro] could not start loading %s; it loads when the intro ends" % _next)
	_load_data()
	_build_ui()
	print("[Intro] %d slides, then %s" % [_slides.size(), _next])
	if _slides.is_empty():
		_leave()
		return
	_run()


func _run() -> void:
	for i in _slides.size():
		if _leaving:
			return
		await _show(i)
	_leave()


## One slide: up from black, the line writing out under the pushing art, a hold (or a press), down to black.
func _show(i: int) -> void:
	var s: Dictionary = _slides[i]
	var path := str(s.get("illustration", ""))
	_art.texture = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	if _art.texture == null and path != "":
		push_warning("[Intro] slide '%s': no art at %s" % [s.get("id", i), path])
	_art.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	_art.scale = Vector2.ONE
	_line.text = str(s.get("text", ""))
	_line.visible_ratio = 0.0
	_dots.text = _dots_for(i)
	_advance = false
	_accept_after = Time.get_ticks_msec() + int(_grace * 1000.0)
	var type_s := maxf(_line.text.length() / _cps, 0.3)
	_kill(_push_tween)
	_push_tween = create_tween()
	_push_tween.tween_property(_art, "scale", Vector2.ONE * (1.0 + PUSH), type_s + _hold + _fade * 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _fade_to(0.0)
	if _leaving:
		return
	_kill(_type_tween)
	_type_tween = create_tween()
	_type_tween.tween_property(_line, "visible_ratio", 1.0, type_s)
	var done_at := -1
	while not _leaving:
		await get_tree().process_frame
		if _advance:
			_advance = false
			if _line.visible_ratio < 1.0:
				_kill(_type_tween)
				_line.visible_ratio = 1.0
				continue
			break
		if _line.visible_ratio >= 1.0:
			if done_at < 0:
				done_at = Time.get_ticks_msec()
			elif Time.get_ticks_msec() - done_at >= int(_hold * 1000.0):
				break
	if not _leaving:
		await _fade_to(1.0)


func _fade_to(alpha: float) -> void:
	var tw := create_tween()
	tw.tween_property(_black, "color:a", alpha, _fade)
	await tw.finished


## To black, then the world map (already loaded on its thread, or waited for under "Inking the map…").
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	_kill(_type_tween)
	if _black.color.a < 1.0:
		var tw := create_tween()
		tw.tween_property(_black, "color:a", 1.0, _fade * 0.6)
		await tw.finished
	if ResourceLoader.load_threaded_get_status(_next) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_wait_label.visible = true
		while ResourceLoader.load_threaded_get_status(_next) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
	var packed = null
	if ResourceLoader.load_threaded_get_status(_next) == ResourceLoader.THREAD_LOAD_LOADED:
		packed = ResourceLoader.load_threaded_get(_next)
	print("[Intro] leaving for %s" % _next)
	if packed is PackedScene:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(_next)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or Time.get_ticks_msec() < _accept_after:
		return
	var go := false
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		go = true
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode in ADVANCE_KEYS:
		go = true
	if go:
		_advance = true
		get_viewport().set_input_as_handled()


## Holding Esc fills the skip bar; full, the intro ends.
func _process(delta: float) -> void:
	if _leaving:
		return
	_esc_time = _esc_time + delta if Input.is_physical_key_pressed(KEY_ESCAPE) else 0.0
	_skip_fill.size.x = SKIP_BAR_W * clampf(_esc_time / maxf(_skip_hold, 0.05), 0.0, 1.0)
	if _esc_time >= _skip_hold:
		_leave()


# ── Data and build ────────────────────────────────────────────────────────────

func _load_data() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("[Intro] %s not found: straight to the map" % DATA_PATH)
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not d is Dictionary:
		push_warning("[Intro] %s could not be read: straight to the map" % DATA_PATH)
		return
	_cps = _num(d, "chars_per_second", _cps)
	_fade = _num(d, "fade_seconds", _fade)
	_hold = _num(d, "hold_seconds", _hold)
	_skip_hold = _num(d, "skip_hold_seconds", _skip_hold)
	_grace = _num(d, "input_grace_seconds", _grace)
	var slides = d.get("slides", [])
	if slides is Array:
		for s in slides:
			if s is Dictionary and str(s.get("text", "")).strip_edges() != "":
				_slides.append(s)
			else:
				push_warning("[Intro] a slide without text was left out")


## A positive number from the JSON, or the default (with a warning) when it is missing or not one.
func _num(d: Dictionary, key: String, fallback: float) -> float:
	var v = d.get(key, fallback)
	if (v is float or v is int) and float(v) > 0.0:
		return float(v)
	push_warning("[Intro] %s = %s is not a positive number; using %s" % [key, v, fallback])
	return fallback


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)

	var ground := ColorRect.new()
	ground.color = Color(0.03, 0.02, 0.015)
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(ground)

	_art = TextureRect.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_art)

	# a dark band under the words, so they read on any art
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	g.set_color(1, Color(0.0, 0.0, 0.0, 0.85))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.0, 0.0)
	gt.fill_to = Vector2(0.0, 1.0)
	gt.width = 4
	gt.height = 256
	var band := TextureRect.new()
	band.texture = gt
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	band.offset_top = -320.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(band)

	_line = Label.new()
	_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_line.offset_left = 180.0
	_line.offset_right = -180.0
	_line.offset_top = -230.0
	_line.offset_bottom = -64.0
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_line.add_theme_font_size_override("font_size", 30)
	_line.add_theme_color_override("font_color", TEXT_COLOR)
	_line.add_theme_color_override("font_outline_color", INK)
	_line.add_theme_constant_override("outline_size", 7)
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_line)

	_dots = Label.new()
	_dots.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dots.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_dots.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dots.offset_right = -28.0
	_dots.offset_bottom = -22.0
	_dots.add_theme_font_size_override("font_size", 16)
	_dots.add_theme_color_override("font_color", Color(TEXT_COLOR, 0.55))
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_dots)

	_black = ColorRect.new()
	_black.color = Color(0.0, 0.0, 0.0, 1.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_black)

	# skipping: a button for the mouse, Esc held for the keyboard (the bar fills while it is held)
	var skip := Button.new()
	skip.text = "Skip intro ›"   # DRAFT
	skip.flat = true
	skip.focus_mode = Control.FOCUS_NONE   # Space / Enter go on to the next slide, never press this
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip.offset_right = -24.0
	skip.offset_top = 18.0
	skip.add_theme_color_override("font_color", Color(TEXT_COLOR, 0.7))
	skip.add_theme_font_size_override("font_size", 16)
	skip.pressed.connect(_leave)
	_layer.add_child(skip)
	var hint := Label.new()
	hint.text = "hold Esc to skip"   # DRAFT
	hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.offset_right = -30.0
	hint.offset_top = 52.0
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(TEXT_COLOR, 0.45))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(hint)
	_skip_fill = ColorRect.new()
	_skip_fill.color = Color(0.95, 0.80, 0.45, 0.8)
	_skip_fill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip_fill.offset_left = -30.0 - SKIP_BAR_W
	_skip_fill.offset_right = -30.0
	_skip_fill.offset_top = 74.0
	_skip_fill.offset_bottom = 77.0
	_skip_fill.size.x = 0.0
	_skip_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_skip_fill)

	_wait_label = Label.new()
	_wait_label.text = "Inking the map…"   # DRAFT
	_wait_label.set_anchors_preset(Control.PRESET_CENTER)
	_wait_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_wait_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_wait_label.add_theme_font_size_override("font_size", 22)
	_wait_label.add_theme_color_override("font_color", Color(TEXT_COLOR, 0.8))
	_wait_label.visible = false
	_layer.add_child(_wait_label)


func _dots_for(i: int) -> String:
	var parts := []
	for k in _slides.size():
		parts.append("●" if k == i else "○")
	return " ".join(parts)


func _kill(tw: Tween) -> void:
	if tw != null and tw.is_valid():
		tw.kill()
