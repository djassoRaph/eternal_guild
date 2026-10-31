# mission_slot.gd
# One adventurer place on the World Map scroll. Filled by a click on an adventurer token (Story 6.5:
# world_map_board._on_token_pressed -> fill) or a drag from the Tab roster panel; a click on a filled place empties it.
# Only a READY roster adventurer may take a place: GameManager decides (not_ready_reason), not the drag source.
# Attached via set_script() by world_map_board._open_detail_panel().
extends PanelContainer

var slot_index: int = 0
var assigned_ids: Array = []    # shared reference to the board's _assigned_ids array
var on_slot_changed: Callable   # bound to world_map_board._on_slot_changed()

var _filled_id = null           # null = empty; adventurer id when filled
var _label: Label = null

const INK := Color(0.20, 0.13, 0.07, 1.0)
const INK_EMPTY := Color(0.45, 0.38, 0.28, 1.0)


func _ready() -> void:
	_label = get_node_or_null("SlotLabel")
	mouse_filter = Control.MOUSE_FILTER_STOP


func is_empty() -> bool:
	return _filled_id == null


func filled_id():
	return _filled_id


## Whether this adventurer may take a place: on the roster, READY, and not already in another place.
func can_take(adventurer_id) -> bool:
	if adventurer_id == null:
		return false
	for used_id in assigned_ids:
		if used_id != null and typeof(used_id) == typeof(adventurer_id) and used_id == adventurer_id:
			return false   # same adventurer already placed
	var adv: Dictionary = GameManager.find_adventurer(adventurer_id)
	return not adv.is_empty() and GameManager.not_ready_reason(adv) == ""


## Puts an adventurer in this place; false (nothing changed) when it's taken or they can't go.
func fill(adventurer_id) -> bool:
	if _filled_id != null or not can_take(adventurer_id):
		return false
	_filled_id = adventurer_id
	assigned_ids[slot_index] = adventurer_id
	_refresh_display()
	if on_slot_changed.is_valid():
		on_slot_changed.call()
	return true


func clear_slot() -> void:
	if _filled_id == null:
		return
	assigned_ids[slot_index] = null
	_filled_id = null
	_refresh_display()
	if on_slot_changed.is_valid():
		on_slot_changed.call()


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.get("type") == "adventurer"):
		return false
	return _filled_id == null and can_take(data.get("id"))


func _drop_data(_pos: Vector2, data: Variant) -> void:
	fill(data.get("id"))


func _gui_input(event: InputEvent) -> void:
	# Click a filled place to empty it
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and _filled_id != null:
		clear_slot()


func _refresh_display() -> void:
	if _label == null:
		return
	if _filled_id == null:
		_label.text = "Empty"
		_label.add_theme_color_override("font_color", INK_EMPTY)
		return
	var adv: Dictionary = GameManager.find_adventurer(_filled_id)
	_label.text = str(adv.get("name", _filled_id)) if not adv.is_empty() else str(_filled_id)
	_label.add_theme_color_override("font_color", INK)
