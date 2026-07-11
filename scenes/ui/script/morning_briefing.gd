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
var portrait_socket: TextureRect
var flavor_label: Label
var panel_style: StyleBoxFlat
var _death_pause_active: bool = false

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

	panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.11, 0.1, 1.0)
	panel_style.border_color = Color(0.8, 0.65, 0.3, 0.6)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	title_label = Label.new()
	title_label.text = "MORNING BRIEFING"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	vbox.add_child(HSeparator.new())

	portrait_socket = TextureRect.new()
	portrait_socket.custom_minimum_size = Vector2(96, 96)
	portrait_socket.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_socket.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_socket.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(portrait_socket)

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

	flavor_label = Label.new()
	flavor_label.add_theme_font_size_override("font_size", 13)
	flavor_label.add_theme_color_override("font_color", Color(0.6, 0.58, 0.5))
	flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(flavor_label)

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

	title_label.text = "MORNING BRIEFING — Day " + str(GameManager.get_day())
	_show_next_report()


func _show_next_report():
	"""Advance to the next report"""
	current_report_index += 1

	if current_report_index >= reports.size():
		GameManager.log_message("Morning briefing complete. Time to manage the guild.")
		queue_free()
		return

	var report = reports[current_report_index]
	_display_report(report)


func _display_report(report: Dictionary):
	"""Show a single mission report"""
	mission_name_label.text = "" + report.get("mission_name", "Unknown Mission")

	# Portrait + fate-based tone (Story 7.2) — solo only; party is the group panel (7.4)
	var fate := "returned"
	if report.get("type", "solo") == "solo":
		var alive: bool = report.get("alive", true)
		var injured: bool = report.get("injured", false)
		fate = "dead" if not alive else ("wounded" if injured else "returned")
		_apply_fate(report, fate)
	else:
		portrait_socket.texture = null
		panel_style.border_color = Color(0.8, 0.65, 0.3, 0.6)
		panel_style.bg_color = Color(0.12, 0.11, 0.1, 1.0)
		flavor_label.text = ""

	if report.type == "solo":
		adventurer_label.text = report.get("adventurer_name", "?") + " (" + report.get("adventurer_class", "?") + ")"
	else:
		var members = report.get("party_members", [])
		adventurer_label.text = "Party of " + str(report.get("party_size", 0)) + ": " + ", ".join(members)

	if report.success:
		result_label.text = "MISSION SUCCESSFUL"
		result_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.4))

		var reward_range = report.get("reward", [0, 0])
		details_label.text = "Reward earned: " + str(reward_range[0]) + "-" + str(reward_range[1]) + " gold"
		details_label.text += "\nRoll: " + str(report.roll) + " vs " + str(report.success_chance) + "% chance"
	else:
		result_label.text = "MISSION FAILED"
		result_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))

		details_label.text = "Roll: " + str(report.roll) + " vs " + str(report.success_chance) + "% chance"

		if report.type == "party":
			var casualties = report.get("casualties", [])
			var injured_list = report.get("injured", [])
			if casualties.size() > 0:
				details_label.text += "\nLost: " + ", ".join(casualties)
			if injured_list.size() > 0:
				details_label.text += "\nInjured: " + ", ".join(injured_list)
		else:
			if not report.get("alive", true):
				details_label.text += "\n" + report.get("adventurer_name", "They") + " did not return."
			elif report.get("injured", false):
				details_label.text += "\n" + report.get("adventurer_name", "They") + " returned injured."

	report_counter.text = "Report " + str(current_report_index + 1) + " of " + str(reports.size())

	if current_report_index < reports.size() - 1:
		continue_button.text = "Next Report →"
	else:
		continue_button.text = "Begin the Day"

	# Death beat — forced pause before the advance button appears (Story 7.3)
	if fate == "dead":
		_begin_death_pause()
	else:
		_death_pause_active = false
		continue_button.visible = true
		continue_button.modulate.a = 1.0


func _apply_fate(report: Dictionary, fate: String) -> void:
	"""Story 7.2 — portrait (emotional state), panel tone (warm/muted/still), and a flavor line."""
	var cls: String = report.get("adventurer_class", "")
	var state := "" if fate == "returned" else fate
	portrait_socket.texture = PortraitSocket.resolve_texture({
		"portrait": report.get("portrait", ""),
		"class": cls,
		"id": report.get("adventurer_id", "")
	}, state)
	match fate:
		"dead":
			panel_style.border_color = Color(0.35, 0.33, 0.33, 0.85)
			panel_style.bg_color = Color(0.08, 0.08, 0.09, 1.0)
			portrait_socket.modulate = Color(0.55, 0.55, 0.6, 1.0)  # still, desaturated
		"wounded":
			panel_style.border_color = Color(0.72, 0.45, 0.3, 0.75)
			panel_style.bg_color = Color(0.13, 0.11, 0.10, 1.0)
			portrait_socket.modulate = Color(0.9, 0.85, 0.82, 1.0)
		_:
			panel_style.border_color = Color(0.85, 0.68, 0.35, 0.7)  # warm
			panel_style.bg_color = Color(0.14, 0.12, 0.10, 1.0)
			portrait_socket.modulate = Color(1, 1, 1, 1)
	flavor_label.text = _flavor_line(cls, fate)

func _flavor_line(_cls: String, fate: String) -> String:
	"""Placeholder flavor — Story 7.6 replaces this with a data-driven (class, outcome) JSON dict."""
	var pool: Array
	match fate:
		"dead":
			pool = ["They didn't come back.", "The chair sits empty tonight.", "One less name at the table."]
		"wounded":
			pool = ["Bloodied, but breathing.", "They'll mend — given time.", "Home, and hurting."]
		_:
			pool = ["Back with stories to tell.", "Safe, and richer for it.", "The road was kind today."]
	return pool[randi() % pool.size()]

func _begin_death_pause() -> void:
	"""Story 7.3 — hide the advance button, hold for reveal_death_pause_seconds, then fade it in.
	Runs independently per death panel. Input is ignored while _death_pause_active."""
	_death_pause_active = true
	continue_button.visible = false
	continue_button.modulate.a = 0.0
	var dur := float(DataManager.get_config("reveal_death_pause_seconds", 2.0))
	await get_tree().create_timer(dur).timeout
	if not is_instance_valid(continue_button):
		return
	_death_pause_active = false
	continue_button.visible = true
	var t := create_tween()
	t.tween_property(continue_button, "modulate:a", 1.0, 0.4)

func _on_continue_pressed():
	"""Player acknowledges this report"""
	if _death_pause_active:
		return  # forced pause — input silently ignored (Story 7.3)
	_show_next_report()


func _input(event):
	"""Allow spacebar/enter to advance"""
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E]:
			_on_continue_pressed()
			get_viewport().set_input_as_handled()
