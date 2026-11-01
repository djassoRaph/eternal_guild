# clock_label.gd — a small corner clock for a day scene without the hall's top bar (Story 3.7, CL-17; K-19: time passes
# outside too). The same words as the hall's PhaseLabel ("20:40 · Evening", day_clock_rules.hud_text), updated on the
# day clock's minute and phase and on a new day. ExteriorWorld adds it (exteriorworld.gd). Placeholder look: a plain
# label with a dark outline, top-left (25.20's UI skin restyles it). No class_name: loaded by path.
extends CanvasLayer

const Rules := preload("res://scripts/game/day_clock_rules.gd")

var label: Label


func _ready() -> void:
	layer = 5
	label = Label.new()
	label.name = "ClockLabel"
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.6))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	GameBus.day_clock_changed.connect(func(_m): refresh())
	GameBus.day_phase_changed.connect(func(_p): refresh())
	GameBus.day_changed.connect(func(_d): refresh())
	refresh()


func refresh() -> void:
	var t: String = Rules.hud_text(GameManager.day_clock_minutes, GameManager.day_clock_config())
	if label != null and label.text != t:
		label.text = t
