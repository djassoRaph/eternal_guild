# hex_look.gd — the world map's hexes reskinned toward the exterior's Octopath look (Raphael 2026-11-03: "Octopath
# reskin", "Just make 3 for now: Grass. Water... Forest."). The KayKit pieces keep their shapes; the grass tile, the
# water tile and the forest toppers take hex_reskin.gdshader (their own atlas, each cell redrawn in world space). A
# mesh is dressed only when the piece it belongs to (its nearest instanced ancestor) is one of PIECES, so a mountain
# or a building standing on a grass tile keeps its KayKit look. HexMapGenerator calls dress() on each tile it makes
# (game_config "hex_look", true when absent) and dev key 5 on the map toggles it. Loaded by path: no class_name.
extends RefCounted

const SHADER := preload("res://assets/shaders/hex_reskin.gdshader")
const SAVED_META := &"hex_look_saved"
## The pieces this pass reskins: HexMapGenerator's GRASS_SCENE, WATER_SCENE and FOREST_TOPPERS (Test 25 checks they
## match the generator's).
const PIECES := [
	"res://assets/environment/hexagons/base/hex_grass.gltf",
	"res://assets/environment/hexagons/base/hex_water.gltf",
	"res://assets/environment/hexagons/nature/trees_A_large.gltf",
	"res://assets/environment/hexagons/nature/trees_A_medium.gltf",
	"res://assets/environment/hexagons/nature/trees_B_large.gltf",
	"res://assets/environment/hexagons/nature/trees_B_medium.gltf",
	"res://assets/environment/hexagons/nature/hills_A_trees.gltf",
	"res://assets/environment/hexagons/nature/hills_B_trees.gltf",
	"res://assets/environment/hexagons/nature/hills_C_trees.gltf",
]

static var _mats := {}   # atlas texture -> its hex_reskin material


## The coast tiles: not in this pass (Raphael: grass, water, forest), but they hold the same grass and water cells, so a
## caller (the comparison renders) may pass them in `extra`.
const COAST := [
	"res://assets/environment/hexagons/coast/hex_coast_A.gltf", "res://assets/environment/hexagons/coast/hex_coast_B.gltf",
	"res://assets/environment/hexagons/coast/hex_coast_C.gltf", "res://assets/environment/hexagons/coast/hex_coast_D.gltf",
	"res://assets/environment/hexagons/coast/hex_coast_E.gltf",
]


## Dress (or undress) every mesh under `node` whose piece is one of PIECES (or `extra`); returns how many meshes are
## dressed (on) or were undressed (off).
static func dress(node: Node, on := true, extra: Array = []) -> int:
	if node == null:
		return 0
	var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.push_front(node)
	var n := 0
	for m in meshes:
		var mi := m as MeshInstance3D
		var piece := _piece_of(mi, node)
		if not (piece in PIECES or piece in extra):
			continue
		if on:
			if mi.has_meta(SAVED_META):
				n += 1          # already dressed
				continue
			var mat := _material(mi.get_active_material(0))
			if mat == null:
				continue
			if not mi.has_meta(SAVED_META):
				mi.set_meta(SAVED_META, [mi.material_override])
			mi.material_override = mat
			n += 1
		elif mi.has_meta(SAVED_META):
			mi.material_override = (mi.get_meta(SAVED_META) as Array)[0]
			mi.remove_meta(SAVED_META)
			n += 1
	return n


## The scene file of the piece a mesh belongs to: its nearest ancestor (itself included, up to `stop`) that is an
## instanced scene.
static func _piece_of(mi: Node, stop: Node) -> String:
	var cur := mi
	while cur != null:
		if cur.scene_file_path != "":
			return cur.scene_file_path
		if cur == stop:
			break
		cur = cur.get_parent()
	return ""


## One hex_reskin material per atlas texture (the piece's own), or null for a mesh without a textured material.
static func _material(src: Material) -> ShaderMaterial:
	var base := src as BaseMaterial3D
	if base == null or base.albedo_texture == null:
		return null
	if not _mats.has(base.albedo_texture):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("atlas", base.albedo_texture)
		_mats[base.albedo_texture] = m
	return _mats[base.albedo_texture]
