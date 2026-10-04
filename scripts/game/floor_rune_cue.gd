# floor_rune_cue.gd — a glowing rune ring on the floor where an E interaction is (Story 25.23, catalogue V5, LM-9).
# It shows (with a short fade and a slow breath) only while its zone owns E (ZonePromptUI.owns_e: the nearest zone
# the player stands in, nothing else taking the key), and hides when the player leaves or another zone (the cat,
# Den Fa) takes E. It never changes who takes E: it only reads owns_e. The ring is unshaded, warm gold, roughness 0
# (the edge pass leaves it un-inked), transparent at render_priority 1 (drawn after the EdgeQuad, which would
# otherwise repaint over it), depth-tested (bodies hide it), no shadow. MainTavern puts one at the hearth's
# interact_point for the fire; other zones get one only if Raphael asks (Open question 2).
extends Node3D

const ZONE_PROMPT_UI := preload("res://scripts/game/ZonePromptUI.gd")

## The Area3D whose E ownership shows the cue.
@export var zone_path: NodePath
## A node holding the marker the cue stands on (the Hearth: its model's interact_point). Empty = stay where placed.
@export var hearth_path: NodePath
@export var anchor_name := "interact_point"
@export var fade_seconds := 0.25
@export var max_alpha := 1.0

var zone: Area3D = null
## The prompt UI to ask (tests give a stand-in); null = ZonePromptUI.find(get_tree()).
var prompt_ui = null
var shown := false

var _alpha := 0.0
var _t := 0.0
var _mat: StandardMaterial3D
@onready var _ring: MeshInstance3D = $Ring


func _ready() -> void:
	if zone == null and not zone_path.is_empty():
		zone = get_node_or_null(zone_path) as Area3D
	var m: Material = _ring.get_surface_override_material(0)
	if m == null and _ring.mesh:
		m = _ring.mesh.surface_get_material(0)
	_mat = (m as StandardMaterial3D).duplicate() if m is StandardMaterial3D else StandardMaterial3D.new()
	_ring.set_surface_override_material(0, _mat)
	_ring.visible = false
	_place.call_deferred()


func _place() -> void:
	if hearth_path.is_empty():
		return
	var h := get_node_or_null(hearth_path)
	var p := h.find_child(anchor_name, true, false) as Node3D if h else null
	if p:
		global_position = p.global_position + Vector3(0, 0.012, 0)
	else:
		push_warning("[FloorRuneCue] no %s under %s: the cue stays where it was placed" % [anchor_name, hearth_path])


func _process(delta: float) -> void:
	var ui = prompt_ui if prompt_ui != null else ZONE_PROMPT_UI.find(get_tree())
	shown = ui != null and zone != null and ui.owns_e(zone)
	_alpha = move_toward(_alpha, 1.0 if shown else 0.0, delta / maxf(fade_seconds, 0.01))
	_t += delta
	_ring.visible = _alpha > 0.0
	if _ring.visible:
		_mat.albedo_color.a = max_alpha * _alpha * (0.85 + 0.15 * sin(_t * 2.4))
