# demo_end_card.gd — the demo's "to be continued" card (Story 10.7, KM-7). Opened by the hall's royal_messenger.gd once
# the player has heard the King's messenger: the hall is already stopped (its world frozen, the tree paused; opened on its
# own, as tests do, the card stops it the same way). A CanvasLayer at 126, over the dialogue box (110), Story 10.1's
# panels (118) and Story 17.3's card reveal (120), running while paused; in "blocks_player" (the one modal rule) and
# "demo_end_card". It fades to black over fade_seconds and shows the title, the lines and the Kickstarter line (when it is
# not ""), all DRAFT text from data/narrative/demo_ending.json, in the morning briefing's panel style (25.20's skin later).
# Its one button (or Enter) is live after min_seconds: the tree unpaused, then the main menu (scene_changer, a test seam;
# default change_scene_to_file). The save on disk is the final day's: Continue replays it. Every key is eaten while it is
# open (Esc does nothing: no pause menu over the end). Built in code; no class_name: loaded by path.
extends CanvasLayer

const LAYER := 126
const MAIN_MENU := "res://scenes/MainMenu.tscn"
const MESSENGER_SCRIPT := "res://scripts/game/royal_messenger.gd"

## The card's text: {title, lines, kickstarter_line, button, min_seconds, fade_seconds} (demo_ending.json's end_card).
var text: Dictionary = {}
## How the button leaves (tests record the path); unset: get_tree().change_scene_to_file.
var scene_changer: Callable
var button: Button
var shade: ColorRect
var labels: Array = []
var left := false
var _live := false


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("demo_end_card")
	add_to_group("blocks_player")
	if not get_tree().paused:
		load(MESSENGER_SCRIPT).stop_hall(get_tree())   # opened on its own: the hall stops as it does after the messenger
	_build()
	var fade := maxf(0.0, num(text.get("fade_seconds"), 1.0))
	var tw := create_tween()
	tw.tween_property(shade, "modulate:a", 1.0, fade).from(0.0)
	var wait := maxf(0.0, num(text.get("min_seconds"), 3.0))
	if wait <= 0.0:
		_go_live()
	else:
		get_tree().create_timer(wait, true).timeout.connect(_go_live)   # process_always: it counts while paused


## A number from the text (review P9: a null or a non-number is the default, never an error).
static func num(v, d: float) -> float:
	return float(v) if (v is int or v is float) and is_finite(float(v)) else d


## A string from the text (review P9: anything else is the default).
static func word(v, d: String) -> String:
	return v if v is String else d


func _build() -> void:
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 1)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP   # nothing under the card takes a click
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()   # the morning briefing's panel style (morning_briefing.gd)
	style.bg_color = Color(0.12, 0.11, 0.1, 1.0)
	style.border_color = Color(0.8, 0.65, 0.3, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := _label(word(text.get("title"), "To be continued"), 32, Color(0.9, 0.75, 0.4))
	box.add_child(title)
	var lines = text.get("lines", [])
	for l in (lines if lines is Array else []):
		box.add_child(_label(str(l), 18, Color(0.85, 0.85, 0.8)))
	var ks := word(text.get("kickstarter_line"), "")
	if ks != "":
		box.add_child(_label(ks, 18, Color(0.9, 0.75, 0.4)))
	button = Button.new()
	button.text = word(text.get("button"), "Return to the main menu")
	button.disabled = true
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = Vector2(260, 44)
	button.pressed.connect(leave)
	box.add_child(button)


func _label(s: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	labels.append(l)
	return l


func _go_live() -> void:
	if not is_instance_valid(button):
		return
	_live = true
	button.disabled = false
	button.grab_focus()


## Every key is the card's: Enter (ui_accept) leaves once it is live; Esc and anything else do nothing.
func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
		if _live and event.is_action_pressed("ui_accept") and not event.is_echo():
			leave()


## To the main menu: the tree unpaused first (the menu must run), then the scene change. Once.
func leave() -> void:
	if left or not _live:
		return
	left = true
	get_tree().paused = false
	print("[DemoEnding] to the main menu (the save is the final day's: Continue replays it)")
	if scene_changer.is_valid():
		scene_changer.call(MAIN_MENU)
	else:
		get_tree().change_scene_to_file(MAIN_MENU)
