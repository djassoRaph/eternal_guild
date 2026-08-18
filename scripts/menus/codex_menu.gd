extends CanvasLayer
class_name CodexMenu
## Code-built Codex overlay (Epic 18/19) — the guild's eternal record.
## Reads SaveSystem's codex.dat (cross-run persistent, independent of the active save game).
## Two parts: guild-wide stats, and the Fallen Heroes memorial list written by
## SaveSystem.record_fallen_hero() at the moment of death (Story 7.1).
## Instantiated by the main menu and pause menu, same pattern as SettingsMenu.


func _ready() -> void:
	layer = 128  # above other UI (pause menu is layer 1)
	process_mode = Node.PROCESS_MODE_ALWAYS  # works while the game is paused

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 480)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Codex"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	# --- Guild record ---
	vbox.add_child(_section_label("Guild Record"))
	vbox.add_child(_stats_row())

	# --- Fallen heroes ---
	vbox.add_child(_section_label("The Fallen"))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var fallen: Array = SaveSystem.get_codex("fallen_heroes", [])
	if fallen.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No heroes have fallen yet."
		empty_label.modulate = Color(1, 1, 1, 0.6)
		list.add_child(empty_label)
	else:
		var sorted_fallen := fallen.duplicate()
		sorted_fallen.sort_custom(func(a, b): return a.get("death_day", 0) > b.get("death_day", 0))
		for entry in sorted_fallen:
			list.add_child(_hero_row(entry))

	# --- Back ---
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(_on_back_pressed)
	vbox.add_child(back)


func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	return l


func _stats_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var stats := [
		["Runs", SaveSystem.get_codex("total_runs", 0)],
		["Best Day", SaveSystem.get_codex("best_day_reached", 0)],
		["Gold Earned", SaveSystem.get_codex("total_gold_earned", 0)],
		["Missions", SaveSystem.get_codex("total_missions_completed", 0)],
	]
	for stat in stats:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := Label.new()
		# Godot's JSON.parse floatifies saved ints (codex.dat is JSON) — coerce back to int for display.
		value.text = str(int(stat[1]))
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 20)
		col.add_child(value)
		var label := Label.new()
		label.text = stat[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color(1, 1, 1, 0.65)
		label.add_theme_font_size_override("font_size", 12)
		col.add_child(label)
		row.add_child(col)
	return row


func _hero_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var tarot_card := DataManager.get_tarot_card(entry.get("tarot_card", ""))
	var portrait := PortraitSocket.new()
	portrait.custom_minimum_size = Vector2(48, 48)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.set_adventurer({
		"portrait": tarot_card.get("portrait", ""),
		"class": entry.get("class", ""),
	})
	row.add_child(portrait)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_line := Label.new()
	var card_name: String = tarot_card.get("name", "")
	name_line.text = entry.get("name", "Unknown") + "  —  " + str(entry.get("class", "Unknown"))
	if card_name != "":
		name_line.text += "  (" + card_name + ")"
	info.add_child(name_line)

	var detail_line := Label.new()
	# Same JSON int-floatification as the stats row — coerce before display.
	detail_line.text = "Hired Day %s · Fell Day %s · %s missions completed" % [
		str(int(entry.get("hire_day", -1))) if entry.get("hire_day") != null else "?",
		str(int(entry.get("death_day", -1))) if entry.get("death_day") != null else "?",
		str(int(entry.get("missions_completed", 0))),
	]
	detail_line.modulate = Color(1, 1, 1, 0.65)
	detail_line.add_theme_font_size_override("font_size", 12)
	info.add_child(detail_line)

	row.add_child(info)
	return row


func _on_back_pressed() -> void:
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
