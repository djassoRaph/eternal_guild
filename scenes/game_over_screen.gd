# game_over_screen.gd — "The Guild Falls" (Story 13.4)
# The script of MainTavern's GameOverScreen CanvasLayer (MainTavern.tscn is not edited: the scene's old children are
# freed and the surface is built here). main_tavern.gd calls show_game_over(cause) on GameBus.game_over_triggered.
# By then the fall is already recorded (GameManager.trigger_game_over -> SaveSystem.end_run: the codex.dat entry, the
# save moved to fallen_runs/), so the buttons only route:
# - New Run: GameManager.begin_new_run(), the one new-run entry (Story 5.1's naming screen and Epics 21/22's Reading and
#   legacy transition hook in there or before it), then GameManager.NEW_RUN_SCENE;
# - Return to Main Menu: the run state reset, then the main menu (Continue is off: no save is left).
# Each asks once. Every word is in data/reveal/guild_falls.json (DRAFT). The look is a placeholder (UI skin: 25.20).
extends CanvasLayer

const TEXT_PATH := "res://data/reveal/guild_falls.json"
const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const LAYER := 110   # above the morning briefing and the F12 panel (both 100)
const STAT_KEYS := ["days_survived", "adventurers_lost", "gold_peak"]
## The built-in words when the data file or one of its keys is missing (one warning each).
const FALLBACK_TEXT := {
	"title": "The Guild Falls",
	"reasons": {"fallback": "The guild could not go on."},
	"stats": {"days_survived": "Days survived", "adventurers_lost": "Adventurers lost", "gold_peak": "Gold at its peak"},
	"buttons": {"new_run": "New Run", "main_menu": "Return to Main Menu"},
	"confirm": {"new_run": "Start a new guild? This one is gone.", "main_menu": "Leave for the main menu? This guild is gone."},
}

var cause := ""
var shown := false          # true once the surface is up (after any morning briefing closed)
var _text: Dictionary = {}
var _warned := {}
var _overlay: ColorRect
var _panel: PanelContainer
var _title: Label
var _reason: Label
var _stats := {}            # stat key -> its value Label
var _stat_names := {}       # stat key -> its name Label
var new_run_button: Button
var main_menu_button: Button
var _dialog: ConfirmationDialog


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS   # it runs while the tree is paused
	for c in get_children():
		c.queue_free()   # the scene's old ColorRect / MessageLabel / MainMenuButton
	_text = load_text(TEXT_PATH)
	_build()
	visible = false


## The screen's words from the data file; the built-in ones (and a warning) when it can't be read.
static func load_text(path: String) -> Dictionary:
	var data = null
	if FileAccess.file_exists(path):
		data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		push_warning("[GameOverScreen] fallback: %s is missing or unreadable; using the built-in text" % path)
		return FALLBACK_TEXT.duplicate(true)
	return data


## One line of the data file (section "" = a top-level key), else the built-in one with one warning.
func line(section: String, key: String) -> String:
	var src = _text.get(section) if section != "" else _text
	var v = src.get(key) if src is Dictionary else null
	if v is String and v != "":
		return v
	var fb = FALLBACK_TEXT.get(section) if section != "" else FALLBACK_TEXT
	var w := "%s.%s" % [section, key]
	if not _warned.has(w):
		_warned[w] = true
		push_warning("[GameOverScreen] fallback: %s has no %s; using the built-in text" % [TEXT_PATH, w])
	return str(fb.get(key, "")) if fb is Dictionary else ""


## The reason line for a cause (the key the guild fell with); a cause with no line takes the fallback line.
func reason_line(cause_key: String) -> String:
	var reasons = _text.get("reasons")
	if reasons is Dictionary and reasons.get(cause_key) is String:
		return reasons[cause_key]
	if not _warned.has("cause:" + cause_key):
		_warned["cause:" + cause_key] = true
		push_warning("[GameOverScreen] fallback: no reason line for '%s'" % cause_key)
	return line("reasons", "fallback")


func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "FallOverlay"
	_overlay.color = Color(0.0, 0.0, 0.0, 0.9)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var center := CenterContainer.new()
	center.name = "FallCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "FallPanel"
	_panel.custom_minimum_size = Vector2(720, 0)
	var style := StyleBoxFlat.new()   # placeholder_fall_panel (the UI skin is Story 25.20)
	style.bg_color = Color(0.09, 0.07, 0.06)
	style.border_color = Color(0.45, 0.35, 0.22)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(40)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	_panel.add_child(v)

	_title = Label.new()
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 48)
	_title.add_theme_color_override("font_color", Color(0.92, 0.82, 0.6))
	v.add_child(_title)

	_reason = Label.new()
	_reason.name = "Reason"
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason.custom_minimum_size = Vector2(640, 0)
	_reason.add_theme_font_size_override("font_size", 22)
	v.add_child(_reason)

	var grid := GridContainer.new()
	grid.name = "Stats"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(grid)
	for key in STAT_KEYS:
		var n := Label.new()
		n.add_theme_font_size_override("font_size", 20)
		n.add_theme_color_override("font_color", Color(0.75, 0.7, 0.62))
		grid.add_child(n)
		var val := Label.new()
		val.name = "Value_" + key
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.add_theme_font_size_override("font_size", 20)
		grid.add_child(val)
		_stat_names[key] = n
		_stats[key] = val

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	v.add_child(row)
	new_run_button = Button.new()
	new_run_button.name = "NewRun"
	new_run_button.custom_minimum_size = Vector2(220, 44)
	new_run_button.pressed.connect(_on_new_run_pressed)
	row.add_child(new_run_button)
	main_menu_button = Button.new()
	main_menu_button.name = "MainMenu"
	main_menu_button.custom_minimum_size = Vector2(220, 44)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	row.add_child(main_menu_button)


## Fills the surface from the data file and GameManager.last_run_summary (frozen at the fall).
func _fill() -> void:
	_title.text = line("", "title")
	_reason.text = reason_line(cause)
	var summary: Dictionary = GameManager.last_run_summary
	for key in STAT_KEYS:
		_stat_names[key].text = line("stats", key)
		var n = summary.get(key, 0)
		_stats[key].text = str(int(n)) if (n is int or n is float) else "—"
	new_run_button.text = line("buttons", "new_run")
	main_menu_button.text = line("buttons", "main_menu")


## Shows the fall for `reason` (a cause key). It waits a frame (the bedroom adds the morning briefing right after
## advance_day() returns) and then for any open morning briefing to close: the night's deaths land first.
func show_game_over(reason: String) -> void:
	cause = reason
	print("[GameOverScreen] fall: %s" % reason)
	await get_tree().process_frame
	while is_inside_tree():
		var open := get_tree().get_nodes_in_group("morning_briefing").filter(func(b): return is_instance_valid(b) and b.is_inside_tree())
		if open.is_empty():
			break
		await open[0].tree_exited
	if not is_inside_tree():
		return
	_fill()
	visible = true
	shown = true
	add_to_group("blocks_player")   # review P1, P9: the one modal rule: no walking, the E gate shut, the hall's log hidden
	_pause(true)
	_freeze_world(true)
	new_run_button.disabled = true   # review P10: no press lands before the screen is there
	main_menu_button.disabled = true
	_overlay.modulate.a = 0.0
	_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", 1.0, 0.6)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.5)
	tw.finished.connect(_on_faded_in)


func _on_faded_in() -> void:
	new_run_button.disabled = false
	main_menu_button.disabled = false
	new_run_button.grab_focus()


## Review P1: the hall's root runs while paused (main_tavern.gd), so a tree pause alone left the player walking (and the
## exit door working). The hall's world (its SubViewportContainer) is frozen as the pause menu does it.
func _freeze_world(on: bool) -> void:
	var cs := get_tree().current_scene if is_inside_tree() else null
	var svc = cs.get_node_or_null("SubViewportContainer") if cs else null
	if svc is Control:
		svc.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
		svc.mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP


func _on_new_run_pressed() -> void:
	_ask(line("confirm", "new_run"), line("buttons", "new_run"), _start_new_run)


func _on_main_menu_pressed() -> void:
	_ask(line("confirm", "main_menu"), line("buttons", "main_menu"), _return_to_main_menu)


## MainTavern.tscn's [connection] from the scene's old MainMenuButton names this method (the scene is not edited).
func _on_main_menu_button_pressed() -> void:
	_on_main_menu_pressed()


## One question before a button acts (Story 13.4: "when confirmed"); the dialog frees itself.
func _ask(text: String, ok_text: String, on_yes: Callable) -> void:
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	var d := ConfirmationDialog.new()
	d.title = line("", "title")
	d.dialog_text = text
	d.ok_button_text = ok_text
	d.process_mode = Node.PROCESS_MODE_ALWAYS
	d.confirmed.connect(func():
		d.queue_free()
		on_yes.call())
	d.canceled.connect(d.queue_free)
	_dialog = d
	add_child(d)
	d.popup_centered()
	d.get_cancel_button().grab_focus()   # review P10: a stray Enter cancels, it doesn't act


## New Run: a fresh run with nothing carried over, through the one new-run entry.
func _start_new_run() -> void:
	# Review P4: a save still in the slot (a fall with no live run: the editor, F12) is another run: New Game's own
	# question in the main menu decides whether to overwrite it.
	if SaveSystem.has_save_file():
		print("[GameOverScreen] the slot still holds a run: New Run goes by the main menu")
		_return_to_main_menu()
		return
	_leave()
	GameManager.begin_new_run()
	_go_to(GameManager.NEW_RUN_SCENE)


func _return_to_main_menu() -> void:
	_leave()
	GameManager.reset_game_state()
	_go_to(MAIN_MENU_SCENE)


func _leave() -> void:
	remove_from_group("blocks_player")
	_freeze_world(false)
	_pause(false)


## The scene change (Test 32's probe records it instead).
func _go_to(path: String) -> void:
	get_tree().change_scene_to_file(path)


## The pause while the fall is shown (Test 32's probe records it instead of pausing the suite).
func _pause(on: bool) -> void:
	get_tree().paused = on
