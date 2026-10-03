# hourglass_pillar.gd
# The Hourglass Pillar (Story 25.4, catalogue B6): the Prior pillar at the heart of the hall, rooted
# in the cellar and rising through the round bar. Tavern upgrades reveal more of it over a run
# (Story Bible §1); the demo stage comes from game_config.json › pillar_reveal_stage.
# The glow is scaled per instance (glow_energy) so the day-phase lighting (Story 25.23) can tune it;
# the hum (Story 25.24) plays at HumAnchor and can follow reveal_stage_changed.
extends Node3D

signal reveal_stage_changed(stage: int)

const MAX_STAGE := 4
const SEGMENTS := ["pillar_foundation", "pillar_base", "pillar_stub", "pillar_band_low",
	"pillar_hourglass", "pillar_band_high", "pillar_capital"]

## -1 = read game_config.json (pillar_reveal_stage); 0..4 = fixed (LookDev, tests).
@export var reveal_stage_override: int = -1
## Multiplies the pillar's emission (rune bands, hourglass). Assigning it applies it at once.
@export var glow_energy: float = 1.0: set = set_glow_energy

var reveal_stage: int = MAX_STAGE
var _segments: Dictionary = {}     # segment name -> Node3D
var _glow: Array = []              # [local material, imported emission energy]


## The segments visible at a reveal stage: 0 is the worn stub; each stage uncovers the next part,
## up to the full centrepiece at MAX_STAGE. Out-of-range stages clamp.
static func segments_for_stage(stage: int) -> PackedStringArray:
	var s := clampi(stage, 0, MAX_STAGE)
	var out := PackedStringArray(["pillar_foundation", "pillar_base"])
	if s == 0:
		out.append("pillar_stub")
		return out
	out.append("pillar_band_low")
	if s >= 2:
		out.append("pillar_hourglass")
	if s >= 3:
		out.append("pillar_band_high")
	if s >= 4:
		out.append("pillar_capital")
	return out


func _ready() -> void:
	for seg_name in SEGMENTS:
		var node := find_child(seg_name, true, false) as Node3D
		if node:
			_segments[seg_name] = node
		else:
			push_warning("[HourglassPillar] segment missing: %s" % seg_name)
	_make_glow_local()
	var stage := reveal_stage_override
	if stage < 0:
		stage = stage_from_config(DataManager.get_config("pillar_reveal_stage", MAX_STAGE))
	set_reveal_stage(stage)
	set_glow_energy(glow_energy)


## game_config.json › pillar_reveal_stage as a stage: a number clamps to 0..MAX_STAGE; anything else
## (missing, text, a bool) warns and shows the full pillar rather than silently dropping to stage 0.
static func stage_from_config(value) -> int:
	if (value is int or value is float) and is_finite(float(value)):
		return clampi(int(value), 0, MAX_STAGE)
	push_warning("[HourglassPillar] pillar_reveal_stage is %s, not a number — showing stage %d." % [value, MAX_STAGE])
	return MAX_STAGE


func set_reveal_stage(stage: int) -> void:
	reveal_stage = clampi(stage, 0, MAX_STAGE)
	var shown := segments_for_stage(reveal_stage)
	for seg_name in _segments:
		_segments[seg_name].visible = seg_name in shown
	print("[HourglassPillar] reveal stage %d" % reveal_stage)
	reveal_stage_changed.emit(reveal_stage)


func set_glow_energy(energy: float) -> void:
	glow_energy = maxf(energy, 0.0) if is_finite(energy) else 1.0
	for pair in _glow:
		(pair[0] as StandardMaterial3D).emission_energy_multiplier = float(pair[1]) * glow_energy


## Imported materials are shared resources: give this instance its own copies before changing them.
func _make_glow_local() -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as StandardMaterial3D
			if mat and mat.emission_enabled:
				var local := mat.duplicate() as StandardMaterial3D
				(mi as MeshInstance3D).set_surface_override_material(s, local)
				_glow.append([local, mat.emission_energy_multiplier])
