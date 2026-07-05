extends CanvasLayer
class_name SettingsMenu
## Code-built settings overlay: audio volumes, fullscreen, and control rebinding.
## Instantiated by the main menu and pause menu; saves on close.

const ACTION_LABELS := {
	"move_forward": "Move Forward",
	"move_backward": "Move Backward",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"jump": "Jump",
	"interact": "Interact",
}

var _listening_action := ""
var _key_buttons := {}


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
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	# --- Audio ---
	vbox.add_child(_section_label("Audio"))
	for bus_name in ["Master", "Music", "SFX"]:
		vbox.add_child(_make_volume_row(bus_name))

	# --- Display ---
	var fs_row := HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 12)
	var fs_label := Label.new()
	fs_label.text = "Fullscreen"
	fs_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_row.add_child(fs_label)
	var fs_check := CheckButton.new()
	fs_check.button_pressed = SettingsManager.is_fullscreen()
	fs_check.toggled.connect(func(on: bool): SettingsManager.set_fullscreen(on))
	fs_row.add_child(fs_check)
	vbox.add_child(fs_row)

	# --- Controls ---
	vbox.add_child(_section_label("Controls"))
	for action in SettingsManager.get_rebindable_actions():
		vbox.add_child(_make_keybind_row(action))

	var reset := Button.new()
	reset.text = "Reset Controls to Default"
	reset.pressed.connect(_on_reset_controls)
	vbox.add_child(reset)

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


func _make_volume_row(bus_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = bus_name
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = SettingsManager.get_bus_volume(bus_name)  # set before connecting
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(200, 0)
	slider.value_changed.connect(func(v: float): SettingsManager.set_bus_volume(bus_name, v))
	row.add_child(slider)
	return row


func _make_keybind_row(action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = ACTION_LABELS.get(action, action)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 0)
	btn.text = SettingsManager.get_action_key_label(action)
	btn.pressed.connect(func(): _start_listening(action))
	_key_buttons[action] = btn
	row.add_child(btn)
	return row


func _start_listening(action: String) -> void:
	if _listening_action != "":
		_refresh_key_button(_listening_action)  # cancel any prior listen
	_listening_action = action
	_key_buttons[action].text = "Press a key…"


func _refresh_key_button(action: String) -> void:
	if _key_buttons.has(action):
		_key_buttons[action].text = SettingsManager.get_action_key_label(action)


func _on_reset_controls() -> void:
	SettingsManager.reset_keybinds()
	for a in _key_buttons:
		_refresh_key_button(a)


func _on_back_pressed() -> void:
	SettingsManager.save_settings()
	queue_free()


func _input(event: InputEvent) -> void:
	# Rebind capture takes priority while listening
	if _listening_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode != KEY_ESCAPE:  # Esc cancels the rebind
				SettingsManager.rebind_action(_listening_action, event)
			_refresh_key_button(_listening_action)
			_listening_action = ""
			get_viewport().set_input_as_handled()
		return
	# Otherwise Esc closes the overlay
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
