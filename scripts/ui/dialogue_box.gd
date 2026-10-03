# dialogue_box.gd — the dialogue box (Story 10.2): one reusable box for every talker (DL-3).
#
# A copy of Dialogue Manager 3.10.4's example balloon (addons/dialogue_manager/example_balloon/, left
# untouched), extended:
# - a portrait slot left of the text: the speaker's portrait from data/dialogue/speakers.json, or a
#   plate drawn once per speaker while it is missing (their colour and initials; Den Fa's mirror mask);
# - keys are read FIRST, in _input: E (interact), Enter/Space (ui_accept) and Esc (ui_cancel), and jump,
#   are handled here and marked handled, so none of them reaches the 3D world in the SubViewport (Den Fa,
#   the cat, the fire, the bar, ExitArea), the pause menu or the debug keys while the box is open.
#   ui_up/ui_down stay unhandled: Godot's focus moves between the replies;
# - interact / ui_accept finish the typing, then go on (or pick the focused reply); Esc finishes the
#   typing, then ends the conversation, except on a line tagged [#required] that offers replies (a real
#   choice must be made);
# - while open it is in groups "dialogue_open" (ZonePromptUI's gate, the E zones) and "blocks_player"
#   (the player doesn't move or jump). The world keeps running (DL-2): process_mode ALWAYS, no pause;
# - it closes itself (end of conversation, Esc, Game Over, no first line), emits `closed` (the contract
#   talkers use: an Esc-ended conversation never emits DialogueManager.dialogue_ended) and frees itself.
# The look is the house panel style of the morning briefing, all in the scene's one Theme (25.20 swaps
# it). No class_name (S8): dialogue_runner.gd instances scenes/ui/DialogueBox.tscn.
extends CanvasLayer

## Emitted once, when the box closes for any reason.
signal closed

const Runner := preload("res://scripts/dialogue/dialogue_runner.gd")
const SPEAKERS_PATH := "res://data/dialogue/speakers.json"
const PLATE_SIZE := 160
const PLATE_RIM := 4                                  # px of lighter rim round a drawn plate
const NEUTRAL_COLOUR := Color(0.30, 0.29, 0.27)       # an unknown speaker's plate
const MASK_COLOUR := Color(0.88, 0.90, 0.92)          # Den Fa's mirror mask: pale, featureless
const MASK_RADII := Vector2(44, 60)                   # the mask's oval on the plate (px)
const START_TIMEOUT_MS := 2000                        # no first line by then: close, release the player
const OPEN_GROUPS := ["dialogue_open", "blocks_player"]
const BOX_ACTIONS := ["interact", "ui_accept", "ui_cancel", "jump"]

static var _speakers: Dictionary = {}                 # speaker id -> {name, portrait, colour, plate?}
static var _speakers_loaded := false
static var _plates: Dictionary = {}                   # speaker id -> the drawn plate (one per run)
## Missing-portrait warnings given per speaker id (one a run, NFR-11).
static var warned_portraits: Dictionary = {}


## The dialogue resource
@export var dialogue_resource: DialogueResource

## The title the conversation starts from.
@export var start_from_title: String = ""

## The action to use for advancing the dialogue (the replies' accept action too).
@export var next_action: StringName = &"ui_accept"

## The action to use to skip typing the dialogue
@export var skip_action: StringName = &"ui_cancel"

## A sound player for voice lines (if they exist): plays only for a line tagged [#voice=res://…] (NFR-5).
@onready var audio_stream_player: AudioStreamPlayer = %AudioStreamPlayer

## Who started the conversation (dialogue_runner.gd sets it; for logs).
var speaker_node: Node = null

## Temporary game states
var temporary_game_states: Array = []

## See if we are waiting for the player
var is_waiting_for_input: bool = false

## See if we are running a long mutation and should hide the balloon
var will_hide_balloon: bool = false

## A dictionary to store any ephemeral variables
var locals: Dictionary = {}

var _locale: String = TranslationServer.get_locale()
var _closed := false
var _started_ms := -1

## The current line
var dialogue_line: DialogueLine:
	set(value):
		if _closed:
			return
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			# The dialogue has finished so close the box
			close("end")
	get:
		return dialogue_line

## A cooldown timer for delaying the balloon hide when encountering a mutation.
var mutation_cooldown: Timer = Timer.new()

## The base balloon anchor
@onready var balloon: Control = %Balloon

## The speaker's portrait (or drawn plate) and the initials drawn over a plate
@onready var portrait_frame: Control = %PortraitFrame
@onready var portrait: TextureRect = %Portrait
@onready var initials_label: Label = %Initials

## The label showing the name of the currently speaking character
@onready var character_label: RichTextLabel = %CharacterLabel

## The label showing the currently spoken dialogue
@onready var dialogue_label: DialogueLabel = %DialogueLabel

## The menu of responses
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu

## Indicator to show that player can progress dialogue.
@onready var progress: Polygon2D = %Progress


func _ready() -> void:
	balloon.hide()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)

	responses_menu.hide_failed_responses = true
	# If the responses menu doesn't have a next action set, use this one
	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)

	GameBus.game_over_triggered.connect(_on_game_over)


func _process(_delta: float) -> void:
	if _closed:
		return
	if is_instance_valid(dialogue_line):
		progress.visible = not dialogue_label.is_typing and dialogue_line.responses.size() == 0 and not dialogue_line.has_tag("voice")
	elif _started_ms >= 0 and Time.get_ticks_msec() - _started_ms > START_TIMEOUT_MS:
		push_error("[Dialogue] close: no first line from %s ~ %s within %d ms" % [_file_name(), start_from_title, START_TIMEOUT_MS])
		close("error")


## Keys first: nothing behind the box (the world, the pause menu, the zones) sees E, Enter, Space, Esc
## or jump while it is open. Mouse input goes the addon's way (the balloon's and the replies' gui_input).
func _input(event: InputEvent) -> void:
	if _closed or not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()
	else:
		for action in BOX_ACTIONS:   # their releases and echoes, and a jump key of its own
			if event.is_action(action):
				get_viewport().set_input_as_handled()
				return


func _notification(what: int) -> void:
	## Detect a change of locale and update the current dialogue line to show the new language
	if what == NOTIFICATION_TRANSLATION_CHANGED and _locale != TranslationServer.get_locale() and is_instance_valid(dialogue_label) and is_instance_valid(dialogue_line):
		_locale = TranslationServer.get_locale()
		var visible_ratio: float = dialogue_label.visible_ratio
		dialogue_line = await dialogue_resource.get_next_dialogue_line(dialogue_line.id, temporary_game_states)
		if visible_ratio < 1:
			dialogue_label.skip_typing()


## Start some dialogue
func start(with_dialogue_resource: DialogueResource = null, title: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not title.is_empty():
		start_from_title = title
	for g in OPEN_GROUPS:
		add_to_group(g)
	_started_ms = Time.get_ticks_msec()
	show()
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_title, temporary_game_states)


## Apply any changes to the balloon given a new [DialogueLine].
func apply_dialogue_line() -> void:
	mutation_cooldown.stop()

	progress.hide()
	is_waiting_for_input = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	_show_speaker(dialogue_line)

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses

	# Show our balloon
	balloon.show()
	will_hide_balloon = false

	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing
	if _closed:
		return

	# Wait for next line
	var voice = null
	if dialogue_line.has_tag("voice"):
		var voice_path := dialogue_line.get_tag_value("voice")
		voice = load(voice_path) if ResourceLoader.exists(voice_path) else null
		if not voice is AudioStream:
			push_warning("[Dialogue] voice: %s doesn't load: the line stays text only" % voice_path)
	if voice is AudioStream:
		audio_stream_player.stream = voice
		audio_stream_player.play()
		await audio_stream_player.finished
		if not _closed:
			next(dialogue_line.next_id)
	elif dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE
		responses_menu.show()
	elif dialogue_line.time != "":
		var time: float = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		if not _closed:
			next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()


## Go to the next line
func next(next_id: String) -> void:
	is_waiting_for_input = false
	responses_menu.hide()
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


## End the conversation now: hide, release the player and the E zones on this frame, say so, free.
func close(reason := "end") -> void:
	if _closed:
		return
	_closed = true
	mutation_cooldown.stop()
	audio_stream_player.stop()
	hide()
	for g in OPEN_GROUPS:
		remove_from_group(g)
	Runner.mark_closed()
	print("[Dialogue] close: %s ~ %s (%s)" % [_file_name(), start_from_title, reason])
	closed.emit()
	queue_free()


## Whether it has closed (it frees itself at the end of that frame).
func is_closed() -> bool:
	return _closed


# interact / ui_accept: finish typing, else pick the focused reply, else go on.
func _advance() -> void:
	if not is_instance_valid(dialogue_line):
		return
	if dialogue_label.is_typing:
		dialogue_label.skip_typing()
		return
	if responses_menu.visible:
		var items: Array = responses_menu.get_menu_items()
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and focused in items:
			responses_menu.response_selected.emit(focused.get_meta("response"))
		elif not items.is_empty():
			(items[0] as Control).grab_focus()
		return
	if is_waiting_for_input:
		next(dialogue_line.next_id)


# ui_cancel: finish typing, else end the conversation, unless a [#required] choice is on screen.
func _cancel() -> void:
	if is_instance_valid(dialogue_line):
		if dialogue_label.is_typing:
			dialogue_label.skip_typing()
			return
		if dialogue_line.has_tag("required") and dialogue_line.responses.size() > 0:
			return
	close("cancel")


func _show_speaker(line: DialogueLine) -> void:
	var id := speaker_id(line.character, line.tags)
	var shown := display_name(id, tr(line.character, "dialogue"))
	character_label.visible = not line.character.is_empty()
	character_label.text = shown
	portrait_frame.visible = not line.character.is_empty()
	if line.character.is_empty():
		return
	var tex := portrait_texture(id)
	portrait.texture = tex
	var entry = speakers().get(id)
	var plate: bool = _plates.get(id) == tex
	initials_label.visible = plate and not (entry is Dictionary and str(entry.get("plate", "")) == "mask")
	initials_label.text = initials(shown)


func _file_name() -> String:
	if dialogue_resource == null:
		return "nothing"
	if dialogue_resource.resource_path != "":
		return dialogue_resource.resource_path.get_file()
	return str(dialogue_resource.get_meta("source_path", "inline text")).get_file()


# ------------------------------------------------------------------ speakers and portraits (AC 6)

## speakers.json's speakers (id -> {name, portrait, colour, plate?}), read once a run.
static func speakers() -> Dictionary:
	if not _speakers_loaded:
		_speakers_loaded = true
		var data = JSON.parse_string(FileAccess.get_file_as_string(SPEAKERS_PATH)) if FileAccess.file_exists(SPEAKERS_PATH) else null
		if data is Dictionary and data.get("speakers") is Dictionary:
			_speakers = data.speakers
		else:
			push_warning("[Dialogue] load: %s is missing or unreadable: every speaker gets a neutral plate" % SPEAKERS_PATH)
	return _speakers


## A line's speaker id: its [#speaker=id] tag, else its character name lower-cased, spaces to _ ("Den Fa" -> den_fa).
static func speaker_id(character: String, tags: PackedStringArray) -> String:
	for t in tags:
		if t.begins_with("speaker="):
			return t.trim_prefix("speaker=").strip_edges()
	return character.strip_edges().to_lower().replace(" ", "_")


## The name the box shows: speakers.json's, else the line's own character name.
static func display_name(id: String, character: String) -> String:
	var entry = speakers().get(id)
	if entry is Dictionary and str(entry.get("name", "")) != "":
		return str(entry.name)
	return character


## Up to two initials, skipping articles ("The Quest Dealer" -> QD).
static func initials(shown: String) -> String:
	var out := ""
	for w in shown.split(" ", false):
		if not w.to_lower() in ["the", "a", "an", "of"]:
			out += w.left(1).to_upper()
	return out.left(2) if out != "" else "?"


## The speaker's portrait; while it is missing a plate drawn once (their colour, or Den Fa's mask), one
## warning per speaker per run (NFR-11). Never null.
static func portrait_texture(id: String) -> Texture2D:
	var entry = speakers().get(id)
	var path := str(entry.get("portrait", "")) if entry is Dictionary else ""
	if path != "" and ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	if _plates.has(id):
		return _plates[id]
	warned_portraits[id] = int(warned_portraits.get(id, 0)) + 1
	if entry is Dictionary:
		push_warning("[Dialogue] portrait: %s is missing: drawing %s's plate" % [path if path != "" else "(no path)", id])
	else:
		push_warning("[Dialogue] speaker: '%s' has no entry in %s: raw name and a neutral plate" % [id, SPEAKERS_PATH])
	var colour := NEUTRAL_COLOUR
	if entry is Dictionary and Color.html_is_valid(str(entry.get("colour", ""))):
		colour = Color.html(str(entry.colour))
	var plate := _draw_plate(colour, entry is Dictionary and str(entry.get("plate", "")) == "mask")
	_plates[id] = plate
	return plate


static func _draw_plate(colour: Color, mask: bool) -> ImageTexture:
	var img := Image.create(PLATE_SIZE, PLATE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(colour)
	var rim := colour.lightened(0.3)
	for i in PLATE_SIZE:
		for r in PLATE_RIM:
			img.set_pixel(i, r, rim)
			img.set_pixel(i, PLATE_SIZE - 1 - r, rim)
			img.set_pixel(r, i, rim)
			img.set_pixel(PLATE_SIZE - 1 - r, i, rim)
	if mask:   # the mirror mask: one pale oval, no features (never a face)
		var c := Vector2(PLATE_SIZE, PLATE_SIZE) / 2.0
		for y in PLATE_SIZE:
			for x in PLATE_SIZE:
				var d := (Vector2(x, y) + Vector2(0.5, 0.5) - c) / MASK_RADII
				if d.length_squared() <= 1.0:
					img.set_pixel(x, y, MASK_COLOUR)
	return ImageTexture.create_from_image(img)


#region Signals


func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		balloon.hide()


func _on_mutated(mutation: Dictionary) -> void:
	if _closed:
		return
	if not mutation.is_inline:
		is_waiting_for_input = false
		will_hide_balloon = true
		mutation_cooldown.start(0.1)


func _on_balloon_gui_input(event: InputEvent) -> void:
	# Mouse only: keys never get here (_input takes them first)
	if _closed or not is_instance_valid(dialogue_line):
		return
	var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
	if not mouse_was_clicked:
		return
	get_viewport().set_input_as_handled()
	if dialogue_label.is_typing:
		dialogue_label.skip_typing()
	elif is_waiting_for_input and dialogue_line.responses.size() == 0:
		next(dialogue_line.next_id)


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	if _closed:
		return
	next(response.next_id)


func _on_game_over(_reason: String) -> void:
	close("game over")


#endregion
