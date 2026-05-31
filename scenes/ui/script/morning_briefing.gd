# morning_briefing.gd — Morning mission report screen
# Shows mission results one at a time with Darkest Dungeon-style reveal
extends CanvasLayer

var reports: Array = []
var current_report_index: int = -1
var is_animating: bool = false

var panel: PanelContainer
var title_label: Label
var mission_name_label: Label
var adventurer_label: Label
var result_label: Label
var details_label: Label
var continue_button: Button
var report_counter: Label

func _ready():
	layer = 100
	_build_ui()

func _build_ui():
	"""Build the morning briefing UI programmatically"""
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 400)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.1, 1.0)
	style.border_color = Color(0.8, 0.65, 0.3, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	title_label = Label.new()
	title_label.text = "☀️ MORNING BRIEFING"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	vbox.add_child(HSeparator.new())

	mission_name_label = Label.new()
	mission_name_label.text = ""
	mission_name_label.add_theme_font_size_override("font_size", 18)
	mission_name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	mission_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(mission_name_label)

	adventurer_label = Label.new()
	adventurer_label.text = ""
	adventurer_label.add_theme_font_size_override("font_size", 14)
	adventurer_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	adventurer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(adventurer_label)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)

	result_label = Label.new()
	result_label.text = ""
	result_label.add_theme_font_size_override("font_size", 28)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(result_label)

	details_label = Label.new()
	details_label.text = ""
	details_label.add_theme_font_size_override("font_size", 14)
	details_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.7))
	details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(details_label)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer2)

	report_counter = Label.new()
	report_counter.text = ""
	report_counter.add_theme_font_size_override("font_size", 12)
	report_counter.add_theme_color_override("font_color", Color(0.5, 0.5, 0.45))
	report_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(report_counter)

	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(200, 40)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.pressed.connect(_on_continue_pressed)
	vbox.add_child(continue_button)


func show_reports(mission_reports: Array):
	"""Called by bedroom_popup to start the briefing sequence"""
	reports = mission_reports
	current_report_index = -1

	if reports.size() == 0:
		queue_free()
		return

	title_label.text = "☀️ MORNING BRIEFING — Day " + str(GameManager.get_day())
	_show_next_report()


func _show_next_report():
	"""Advance to the next report"""
	current_report_index += 1

	if current_report_index >= reports.size():
		GameManager.log_message("📋 Morning briefing complete. Time to manage the guild.")
		queue_free()
		return

	var report = reports[current_report_index]
	_display_report(report)


func _display_report(report: Dictionary):
	"""Show a single mission report"""
	mission_name_label.text = "📜 " + report.get("mission_name", "Unknown Mission")

	if report.type == "solo":
		adventurer_label.text = report.get("adventurer_name", "?") + " (" + report.get("adventurer_class", "?") + ")"
	else:
		var members = report.get("party_members", [])
		adventurer_label.text = "Party of " + str(report.get("party_size", 0)) + ": " + ", ".join(members)

	if report.success:
		result_label.text = "✅ MISSION SUCCESSFUL"
		result_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.4))

		var reward_range = report.get("reward", [0, 0])
		details_label.text = "Reward earned: " + str(reward_range[0]) + "-" + str(reward_range[1]) + " gold"
		details_label.text += "\nRoll: " + str(report.roll) + " vs " + str(report.success_chance) + "% chance"
	else:
		result_label.text = "💀 MISSION FAILED"
		result_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))

		details_label.text = "Roll: " + str(report.roll) + " vs " + str(report.success_chance) + "% chance"

		if report.type == "party":
			var casualties = report.get("casualties", [])
			var injured_list = report.get("injured", [])
			if casualties.size() > 0:
				details_label.text += "\n☠️ Lost: " + ", ".join(casualties)
			if injured_list.size() > 0:
				details_label.text += "\n🩹 Injured: " + ", ".join(injured_list)
		else:
			if not report.get("alive", true):
				details_label.text += "\n☠️ " + report.get("adventurer_name", "They") + " did not return."
			elif report.get("injured", false):
				details_label.text += "\n🩹 " + report.get("adventurer_name", "They") + " returned injured."

	report_counter.text = "Report " + str(current_report_index + 1) + " of " + str(reports.size())

	if current_report_index < reports.size() - 1:
		continue_button.text = "Next Report →"
	else:
		continue_button.text = "Begin the Day"


func _on_continue_pressed():
	"""Player acknowledges this report"""
	_show_next_report()


func _input(event):
	"""Allow spacebar/enter to advance"""
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E]:
			_on_continue_pressed()
			get_viewport().set_input_as_handled()
