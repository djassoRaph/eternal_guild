# mission_slot.gd
# Drop-target for one adventurer slot in the mission detail panel.
# Attached via set_script() by world_map_board._open_detail_panel().
extends PanelContainer

var slot_index: int = 0
var assigned_ids: Array = []    # shared reference to panel's _assigned_ids array
var on_slot_changed: Callable   # bound to world_map_board._on_slot_changed()

var _filled_id = null           # null = empty; adventurer id when filled
var _label: Label = null


func _ready() -> void:
	_label = get_node_or_null("SlotLabel")
	mouse_filter = Control.MOUSE_FILTER_STOP


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.get("type") == "adventurer"):
		return false
	if _filled_id != null:
		return false  # slot already occupied
	var incoming_id = data.get("id")
	for used_id in assigned_ids:
		if used_id != null and used_id == incoming_id:
			return false  # same adventurer already placed in another slot
	return true


func _drop_data(_pos: Vector2, data: Variant) -> void:
	var incoming_id = data.get("id")
	_filled_id = incoming_id
	assigned_ids[slot_index] = incoming_id
	_refresh_display()
	if on_slot_changed.is_valid():
		on_slot_changed.call()


func _gui_input(event: InputEvent) -> void:
	# Click a filled slot to clear it
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and _filled_id != null:
		assigned_ids[slot_index] = null
		_filled_id = null
		_refresh_display()
		if on_slot_changed.is_valid():
			on_slot_changed.call()


func _refresh_display() -> void:
	if _label == null:
		return
	if _filled_id == null:
		_label.text = "Empty"
		_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45, 1.0))
		return
	var adv_name := ""
	for adv in GameManager.adventurers:
		if adv.get("id", adv.get("name")) == _filled_id:
			adv_name = adv.get("name", "")
			break
	_label.text = adv_name if adv_name != "" else str(_filled_id)
	_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50, 1.0))
