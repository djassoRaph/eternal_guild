# hall_look.gd — the guild hall's look, pass 1 (brainstorm 2026-11-03, BMAD _bmad-output/brainstorming-session-2026-11-03.md:
# "this place has history"). The b9 shell kit gets world-space materials (hall_floor.gdshader: dark worn planks, the
# tiled ring and the compass rose round the bar; hall_wall.gdshader: ruin stone to waist height, plaster in a timber
# frame, soot toward the top), its beams and posts go soot-dark, and code-made placeholder props join the hall:
# lanterns on chains (each an OmniLight3D in group tavern_candle, saved hidden with base_energy, so TavernLighting's
# mood lights them like the hall's other candles) and two faded banners on the partition. Pass 2's set dressing
# (hall_dressing.gd: the memorial wall, the trophy, the tankard ring, the bar top, old notices, portraits, the roots
# round the pillar, dust) goes under the same props node.
#
# TavernLighting applies it at _ready, before its light snapshot (game_config.json "hall_look", true when absent), and
# dev key 5 toggles it. Nothing is written into MainTavern.tscn: off puts every piece's own material back and frees
# the props. Loaded by path: no class_name.
extends RefCounted

const FLOOR_SHADER := preload("res://assets/shaders/hall_floor.gdshader")
const WALL_SHADER := preload("res://assets/shaders/hall_wall.gdshader")
const BANNER_SHADER := preload("res://assets/shaders/hall_banner.gdshader")
const HALL_DRESSING := preload("res://scripts/game/hall_dressing.gd")   # pass 2: the set dressing
const SHELL_PATH := "Architecture/Shell"
const KIT_DIR := "res://assets/environment/custom/"
## Which look each shell kit piece takes (by its glTF's file name).
const KIT := {
	"b9_floor": "floor", "b9_wall_full": "wall", "b9_wall_window": "wall", "b9_wall_low": "low_wall",
	"b9_beam": "timber", "b9_post_full": "timber", "b9_post_low": "timber",
}
const SAVED_META := &"hall_look_saved"    # a piece's own material_override, put back when the look goes off
const PROPS_NAME := "HallLookProps"
## The lit glass and flames of the look's lanterns and candles: TavernLighting shows them only while its mood lights
## the candles (candle_scale > 0), so a dark lantern doesn't glow.
const FLAME_GROUP := "tavern_candle_flame"
## The hall's numbers (MainTavern, measured 2026-11-03): the round bar's centre, the room's inside (min x, min z,
## max x, max z), and the worn lanes (ax, az, bx, bz): door -> bar front, door -> desk, door -> the west tables,
## bar -> hearth, bar -> notice board.
const BAR_CENTER := Vector2(7.74, -8.215)
const ROSE_CENTER := Vector2(7.74, -4.3)
const ROOM := Vector4(-5.0, -19.3, 15.2, 4.66)
const LANES := [
	Vector4(9.6, 4.4, 8.6, -1.0), Vector4(8.6, -1.0, 7.74, -4.0), Vector4(8.6, -1.0, 11.4, -2.9),
	Vector4(8.6, -1.0, 1.2, -2.6), Vector4(1.2, -2.6, -2.4, -3.4), Vector4(3.6, -8.4, -2.7, -9.2),
	Vector4(4.4, -11.4, 4.3, -13.1),
]
## Lanterns (x, z): over the west tables, beside the door lane (off it: a lamp on the lane hangs over walkers' heads
## on screen), the hall's middle, the bar's east side, the notice board, the lectern corner, the keg corner, behind
## the bar. They hang from CHAIN_TOP down to LANTERN_Y.
const LANTERNS := [
	Vector2(-2.6, -3.2), Vector2(10.8, 0.4), Vector2(3.6, -0.2), Vector2(13.4, -8.6), Vector2(4.3, -12.8),
	Vector2(-2.2, -12.4), Vector2(-1.2, 1.6), Vector2(7.7, -13.0),
]
const LANTERN_Y := 2.55
const CHAIN_TOP := 4.0
const LANTERN_ENERGY := 1.3
const LANTERN_RANGE := 4.6
const LANTERN_COLOR := Color(1.0, 0.66, 0.36)
## Faded banners on the partition's hall side (top centre of the cloth; QuadMesh faces +z).
const BANNERS := [
	{"pos": Vector3(9.4, 3.55, -14.44), "cloth": Color(0.24, 0.33, 0.34), "seed": 1.0},
	{"pos": Vector3(12.6, 3.55, -14.44), "cloth": Color(0.40, 0.17, 0.16), "seed": 2.0},
]
const BANNER_SIZE := Vector2(0.85, 1.7)

static var _floor_mat: ShaderMaterial
static var _wall_mat: ShaderMaterial
static var _low_wall_mat: ShaderMaterial
static var _timber_mat: StandardMaterial3D
static var _iron_mat: StandardMaterial3D
static var _glass_mat: StandardMaterial3D


## Put the look on (or take it off) the hall under `nav` (MainTavern's TavernNavigation); the props go under `host`.
## Returns how many pieces of each kind it set: {floor, wall, low_wall, timber, lanterns, banners}.
static func apply(nav: Node, host: Node, on: bool) -> Dictionary:
	var out := {"floor": 0, "wall": 0, "low_wall": 0, "timber": 0, "lanterns": 0, "banners": 0}
	var shell := nav.get_node_or_null(SHELL_PATH) if nav else null
	if shell == null:
		push_warning("[HallLook] no %s under %s: the hall keeps its look" % [SHELL_PATH, nav])
		return out
	for piece in shell.find_children("*", "Node3D", true, false):
		var kind: String = KIT.get(_kit_name(piece), "")
		if kind == "":
			continue
		for mi in _meshes(piece):
			_set_material(mi, _material(kind) if on else null, on)
			out[kind] += 1
	var old := host.get_node_or_null(PROPS_NAME) if host else null
	if old:
		for l in old.find_children("*", "OmniLight3D", true, false):
			l.remove_from_group("tavern_candle")
		host.remove_child(old)
		old.free()
	if on and host:
		var props := Node3D.new()
		props.name = PROPS_NAME
		host.add_child(props)
		for i in LANTERNS.size():
			props.add_child(_lantern(i, LANTERNS[i]))
		for b in BANNERS:
			props.add_child(_banner(b))
		out.lanterns = props.find_children("Lantern*", "", false, false).size()
		out.banners = props.find_children("Banner*", "", false, false).size()
		out.merge(HALL_DRESSING.build(props))
	return out


## True when the look is on under `host` (its props are there).
static func is_on(host: Node) -> bool:
	return host != null and host.get_node_or_null(PROPS_NAME) != null


## The floor's material (the hall's lanes, bar and room set once).
static func floor_material() -> ShaderMaterial:
	if _floor_mat == null:
		_floor_mat = ShaderMaterial.new()
		_floor_mat.shader = FLOOR_SHADER
		_floor_mat.set_shader_parameter("bar_center", BAR_CENTER)
		_floor_mat.set_shader_parameter("rose_center", ROSE_CENTER)
		_floor_mat.set_shader_parameter("room", ROOM)
		_floor_mat.set_shader_parameter("lanes", PackedVector4Array(LANES))
		_floor_mat.set_shader_parameter("lane_count", LANES.size())
	return _floor_mat


## The walls' material; `low` (the near walls, 1 m) is all ruin stone.
static func wall_material(low := false) -> ShaderMaterial:
	if low:
		if _low_wall_mat == null:
			_low_wall_mat = ShaderMaterial.new()
			_low_wall_mat.shader = WALL_SHADER
			_low_wall_mat.set_shader_parameter("stone_top", 3.0)
		return _low_wall_mat
	if _wall_mat == null:
		_wall_mat = ShaderMaterial.new()
		_wall_mat.shader = WALL_SHADER
	return _wall_mat


## Soot-dark timber for the beams and posts.
static func timber_material() -> StandardMaterial3D:
	if _timber_mat == null:
		_timber_mat = StandardMaterial3D.new()
		_timber_mat.albedo_color = Color(0.13, 0.09, 0.065)
		_timber_mat.roughness = 0.92
	return _timber_mat


static func _material(kind: String) -> Material:
	match kind:
		"floor":
			return floor_material()
		"wall":
			return wall_material()
		"low_wall":
			return wall_material(true)
	return timber_material()


static func _kit_name(n: Node) -> String:
	var path := n.scene_file_path
	if not path.begins_with(KIT_DIR):
		return ""
	return path.get_file().get_basename()


static func _meshes(piece: Node) -> Array:
	var out: Array = piece.find_children("*", "MeshInstance3D", true, false)
	if piece is MeshInstance3D:
		out.push_front(piece)
	return out


## On: keep the piece's own override (once, wrapped in an array so even a null override is kept) and put the look's
## on. Off: put the kept one back.
static func _set_material(mi: MeshInstance3D, mat: Material, on: bool) -> void:
	if on:
		if not mi.has_meta(SAVED_META):
			mi.set_meta(SAVED_META, [mi.material_override])
		mi.material_override = mat
	elif mi.has_meta(SAVED_META):
		mi.material_override = (mi.get_meta(SAVED_META) as Array)[0]
		mi.remove_meta(SAVED_META)


static func _iron() -> StandardMaterial3D:
	if _iron_mat == null:
		_iron_mat = StandardMaterial3D.new()
		_iron_mat.albedo_color = Color(0.09, 0.085, 0.08)
		_iron_mat.metallic = 0.6
		_iron_mat.roughness = 0.7
	return _iron_mat


static func _glass() -> StandardMaterial3D:
	if _glass_mat == null:
		_glass_mat = StandardMaterial3D.new()
		_glass_mat.albedo_color = Color(1.0, 0.75, 0.45)
		_glass_mat.emission_enabled = true
		_glass_mat.emission = Color(1.0, 0.62, 0.3)
		_glass_mat.emission_energy_multiplier = 2.2
		_glass_mat.roughness = 0.0       # no ink on the flame glass (the edge pass skips roughness 0)
	return _glass_mat


static func _part(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A placeholder lantern on a chain: an iron cap and base, four corner bars, warm glass, and its light (hidden,
## group tavern_candle, base_energy: TavernLighting's candle_scale lights it).
static func _lantern(i: int, at: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "Lantern%d" % (i + 1)
	root.position = Vector3(at.x, LANTERN_Y, at.y)
	var chain := CylinderMesh.new()
	chain.top_radius = 0.012
	chain.bottom_radius = 0.012
	chain.height = CHAIN_TOP - LANTERN_Y - 0.36
	chain.radial_segments = 6
	root.add_child(_part(chain, _iron(), Vector3(0, 0.36 + chain.height * 0.5, 0)))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.025
	cap.bottom_radius = 0.15
	cap.height = 0.09
	cap.radial_segments = 8
	root.add_child(_part(cap, _iron(), Vector3(0, 0.315, 0)))
	var base := CylinderMesh.new()
	base.top_radius = 0.12
	base.bottom_radius = 0.1
	base.height = 0.04
	base.radial_segments = 8
	root.add_child(_part(base, _iron(), Vector3(0, 0.02, 0)))
	var glass := BoxMesh.new()
	glass.size = Vector3(0.17, 0.23, 0.17)
	var lit_glass := _part(glass, _glass(), Vector3(0, 0.155, 0))
	lit_glass.add_to_group(FLAME_GROUP)   # shown only while the mood lights the candles (TavernLighting)
	root.add_child(lit_glass)
	var bar := BoxMesh.new()
	bar.size = Vector3(0.026, 0.27, 0.026)
	for c in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		root.add_child(_part(bar, _iron(), Vector3(c.x * 0.095, 0.155, c.y * 0.095)))
	var light := OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0, 0.155, 0)
	light.light_color = LANTERN_COLOR
	light.omni_range = LANTERN_RANGE
	light.light_energy = LANTERN_ENERGY
	light.set_meta("base_energy", LANTERN_ENERGY)
	light.shadow_enabled = false
	light.visible = false
	light.add_to_group("tavern_candle")
	root.add_child(light)
	return root


## A faded banner on a rod.
static func _banner(spec: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Banner%d" % int(spec.seed)
	root.position = spec.pos
	var rod := CylinderMesh.new()
	rod.top_radius = 0.02
	rod.bottom_radius = 0.02
	rod.height = BANNER_SIZE.x + 0.2
	rod.radial_segments = 6
	root.add_child(_part(rod, _iron(), Vector3(0, 0.03, 0.02), Vector3(0, 0, PI * 0.5)))
	var quad := QuadMesh.new()
	quad.size = BANNER_SIZE
	var mat := ShaderMaterial.new()
	mat.shader = BANNER_SHADER
	mat.set_shader_parameter("cloth", spec.cloth)
	mat.set_shader_parameter("seed", float(spec.seed))
	root.add_child(_part(quad, mat, Vector3(0, -BANNER_SIZE.y * 0.5, 0.0)))
	return root
