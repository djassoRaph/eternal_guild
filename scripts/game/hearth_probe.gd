# hearth_probe.gd — the hearth corner's ReflectionProbe (Story 25.10, decision J3): Den Fa's mirror mask
# reflects the real hall. The probe captures once (update mode Once), again shortly after the scene
# starts (once the fire's saved state is back), and whenever the fire's look band changes (out, dying,
# low, high: hearth.gd band_for, the single source), so the mask shows the fire lit or dark. Its
# ambient mode is Disabled in the scene: it adds reflections only, never relights the corner.
extends ReflectionProbe

const HEARTH_SCRIPT := preload("res://scripts/game/hearth.gd")

var _band := ""
var _capturing := false
var _again := false


func _ready() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("fireplace_fuel_changed"):
		gm.fireplace_fuel_changed.connect(_on_fuel)
	get_tree().create_timer(0.5).timeout.connect(recapture)   # after the fire's state is restored


func _on_fuel(fuel: float) -> void:
	var band: String = HEARTH_SCRIPT.band_for(fuel)
	if band == _band:
		return
	_band = band
	recapture()


## A Once probe renders again when its update mode is set: flip it to Always for two frames.
func recapture() -> void:
	if not is_inside_tree():
		return
	if _capturing:                 # a band change mid-capture: capture once more afterwards
		_again = true
		return
	_capturing = true
	update_mode = ReflectionProbe.UPDATE_ALWAYS
	for i in 2:
		if not is_inside_tree():
			_capturing = false
			return
		await get_tree().process_frame
	_capturing = false
	if is_inside_tree():
		update_mode = ReflectionProbe.UPDATE_ONCE
		if _again:
			_again = false
			recapture()
