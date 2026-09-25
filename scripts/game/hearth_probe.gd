# hearth_probe.gd — the hearth corner's ReflectionProbe (Story 25.10, decision J3): Den Fa's mirror mask
# reflects the real hall. The probe captures once (update mode Once), and again whenever the fire's look
# band changes (out / dying / low / high, the fireplace's fuel bands), so the mask shows the fire lit or
# dark. Its ambient mode is Disabled in the scene: it adds reflections only, never relights the corner.
extends ReflectionProbe

var _band := -1


func _ready() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("fireplace_fuel_changed"):
		gm.fireplace_fuel_changed.connect(_on_fuel)


## The fireplace's bands: 0 out, 1 dying (<= 20), 2 low (<= 50), 3 high.
static func band_of(fuel: float) -> int:
	if fuel <= 0.0:
		return 0
	if fuel <= 20.0:
		return 1
	if fuel <= 50.0:
		return 2
	return 3


func _on_fuel(fuel: float) -> void:
	var band := band_of(fuel)
	if band == _band:
		return
	_band = band
	recapture()


## A Once probe renders again when its update mode is set: flip it for a frame.
func recapture() -> void:
	update_mode = ReflectionProbe.UPDATE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree():
		update_mode = ReflectionProbe.UPDATE_ONCE
