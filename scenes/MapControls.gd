# MapControls.gd
# A 2D overlay (CanvasLayer) for the hex map scene.
# Back -> main menu. Regenerate -> re-roll the map with a fresh reveal.
# Clicking the center tavern hex -> "Settle here?" confirm -> load the tavern.
#
# Setup in HexMapTest.tscn:
#   Add a CanvasLayer node as a child of the scene root.
#   Attach this script to it.
#   Set the exported generator_path to point at the HexMapGenerator node.
extends CanvasLayer

const MENU_SCENE := "res://scenes/MainMenu.tscn"
const TAVERN_SCENE := "res://scenes/MainTavern.tscn"

## Path to the HexMapGenerator node (the Node3D running HexMapGenerator.gd).
@export var generator_path: NodePath = NodePath("../HexMapGenerator")

var _generator: Node3D = null
var _back_button: Button
var _regenerate_button: Button
var _confirm_dialog: ConfirmationDialog
var _pending_center: Dictionary = {}  # the hex awaiting confirmation


func _ready() -> void:
	_generator = get_node_or_null(generator_path)
	if _generator == null:
		push_warning("[MapControls] No generator found at '%s'. Set generator_path in the inspector." % str(generator_path))
	else:
		print("[MapControls] Found generator: ", _generator.name)
		if _generator.has_signal("reveal_finished"):
			_generator.reveal_finished.connect(_on_reveal_finished)
		else:
			push_warning("[MapControls] Generator has no 'reveal_finished' signal — is the updated HexMapGenerator.gd applied?")
		if _generator.has_signal("tavern_hex_selected"):
			_generator.tavern_hex_selected.connect(_on_tavern_hex_selected)
		else:
			push_warning("[MapControls] Generator has no 'tavern_hex_selected' signal — is the updated HexMapGenerator.gd applied?")

	_build_buttons()
	_build_dialog()


func _build_buttons() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(24, 24)
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	_back_button = Button.new()
	_back_button.text = "← Back"
	_back_button.custom_minimum_size = Vector2(160, 40)
	_back_button.pressed.connect(_on_back_pressed)
	box.add_child(_back_button)

	_regenerate_button = Button.new()
	_regenerate_button.text = "⟳ Regenerate"
	_regenerate_button.custom_minimum_size = Vector2(160, 40)
	_regenerate_button.pressed.connect(_on_regenerate_pressed)
	box.add_child(_regenerate_button)


func _build_dialog() -> void:
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Settle Here?"
	_confirm_dialog.dialog_text = "Build your tavern on this spot?\nThis will be the centre of your world."
	_confirm_dialog.ok_button_text = "Settle"
	_confirm_dialog.cancel_button_text = "Not yet"
	_confirm_dialog.confirmed.connect(_on_settle_confirmed)
	add_child(_confirm_dialog)


# ── Button handlers ───────────────────────────────────────────────────────────

func _on_back_pressed() -> void:
	print("[MapControls] Back -> main menu")
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_regenerate_pressed() -> void:
	print("[MapControls] Regenerate pressed")
	if _generator == null or not _generator.has_method("generate_and_reveal"):
		push_warning("[MapControls] Generator missing or has no generate_and_reveal().")
		return
	_regenerate_button.disabled = true
	_generator.generate_and_reveal()


func _on_reveal_finished() -> void:
	print("[MapControls] Reveal finished — Regenerate re-enabled")
	if _regenerate_button:
		_regenerate_button.disabled = false


# ── Tavern selection flow ───────────────────────────────────────────────────

func _on_tavern_hex_selected(record: Dictionary) -> void:
	# Ignore clicks while the map is still revealing — settling tiles shouldn't
	# be confirmable.
	if _generator and _generator.get("_is_revealing"):
		return
	_pending_center = record
	_confirm_dialog.popup_centered()


func _on_settle_confirmed() -> void:
	print("[MapControls] Settle confirmed for: ", _pending_center.get("id", "?"))

	# Hand the generated world to WorldManager before leaving the scene, so the
	# chosen layout survives into the tavern (in-memory for now; disk save later).
	if _generator and _generator.has_method("get_records"):
		var records: Array = _generator.get_records()
		if WorldManager and WorldManager.has_method("set_generated_world"):
			WorldManager.set_generated_world(records, _pending_center)
		else:
			push_warning("[MapControls] WorldManager.set_generated_world() missing — map not stored.")

	print("[MapControls] Loading tavern...")
	get_tree().change_scene_to_file(TAVERN_SCENE)
