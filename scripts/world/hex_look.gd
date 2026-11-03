# hex_look.gd — the world map's hexes reskinned toward the exterior's Octopath look (Raphael 2026-11-03: "Octopath
# reskin", "Just make 3 for now: Grass. Water... Forest.", then "make all the other land masses ... with new water /
# beach shore lines"). The KayKit pieces keep their shapes; every land and sea piece of the map (the base tiles, the
# coast tiles and the nature toppers: trees, hills, mountains, rocks, water plants; never the buildings, the guild's
# pieces or the clouds) takes hex_reskin.gdshader: its own atlas, each cell redrawn in world space. A mesh is dressed
# only when the piece it belongs to (its nearest instanced ancestor) is a land/sea piece, so a building on a grass tile
# keeps its look.
# The shoreline: set_map() gives the shader a mask, one texel per hex (land white, sea black), and every land tile
# paints its beach and every water tile its shallows and foam along the edges they share. With the look on, the
# generator builds a coast hex as a grass tile (the beach comes from the mask) and keeps KayKit's coast tile hidden
# under it (COAST_SWAP_CHILD), so dress(off) can show KayKit again. HexMapGenerator calls set_map() and dress()
# (game_config "hex_look", true when absent); dev key 5 on the map toggles it. Loaded by path: no class_name.
extends RefCounted

const SHADER := preload("res://assets/shaders/hex_reskin.gdshader")
const SAVED_META := &"hex_look_saved"
const SWAP_META := &"hex_coast_swap"      # on a coast hex built as a grass tile
const COAST_SWAP_CHILD := "KayKitCoast"   # the hidden KayKit coast tile under it
const HEX_DIR := "res://assets/environment/hexagons/"
## The folders of the map's land and sea pieces (the generator's base, coast and nature pieces), and the pieces in
## them that aren't land (the fog clouds).
const LAND_DIRS := ["base", "coast", "nature"]
const NOT_LAND := ["cloud_big.gltf", "cloud_small.gltf"]
const GRASS := "res://assets/environment/hexagons/base/hex_grass.gltf"
const WATER := "res://assets/environment/hexagons/base/hex_water.gltf"
const COAST := [
	"res://assets/environment/hexagons/coast/hex_coast_A.gltf", "res://assets/environment/hexagons/coast/hex_coast_B.gltf",
	"res://assets/environment/hexagons/coast/hex_coast_C.gltf", "res://assets/environment/hexagons/coast/hex_coast_D.gltf",
	"res://assets/environment/hexagons/coast/hex_coast_E.gltf",
]

static var _mats := {}   # atlas texture -> its hex_reskin material
static var _map := {}    # the shader's shoreline uniforms (set_map)


## True for a land or sea piece of the map (the reskin's pieces).
static func is_piece(path: String) -> bool:
	if not path.begins_with(HEX_DIR) or path.get_file() in NOT_LAND:
		return false
	return path.trim_prefix(HEX_DIR).get_slice("/", 0) in LAND_DIRS


## True for a record that is sea (its biome, or a water base tile in an older record).
static func is_sea(rec: Dictionary) -> bool:
	return str(rec.get("biome", "")) == "sea" or str(rec.get("base_path", "")) == WATER


## Give the shader the map's land and sea (one texel per hex, from the records' offset coords) and where the map sits.
static func set_map(records: Array, origin: Vector3) -> void:
	if records.is_empty():
		_map = {}
		return
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for rec in records:
		var c: Vector2i = rec.coord
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var size := hi - lo + Vector2i.ONE
	var img := Image.create(size.x, size.y, false, Image.FORMAT_L8)
	img.fill(Color.BLACK)
	for rec in records:
		if not is_sea(rec):
			var c: Vector2i = rec.coord
			img.set_pixel(c.x - lo.x, c.y - lo.y, Color.WHITE)
	_map = {"hex_mask": ImageTexture.create_from_image(img), "mask_origin": Vector2(lo), "mask_size": Vector2(size),
		"map_origin": origin, "shore_on": 1.0, "col_step": HexGrid.COL_STEP, "row_step": HexGrid.ROW_STEP,
		"row_offset": HexGrid.ROW_OFFSET}
	for m in _mats.values():
		_apply_map(m)


## Dress (or undress) every mesh under `node` whose piece is a land or sea piece; returns how many meshes are dressed
## (on) or were undressed (off). A coast hex built as a grass tile shows its grass on, its hidden KayKit tile off.
static func dress(node: Node, on := true) -> int:
	if node == null:
		return 0
	for swap in _swapped(node):
		var kk := swap.get_node_or_null(COAST_SWAP_CHILD) as Node3D
		if kk:
			kk.visible = not on
		for c in swap.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).visible = on
	var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.push_front(node)
	var n := 0
	for m in meshes:
		var mi := m as MeshInstance3D
		if not is_piece(_piece_of(mi, node)):
			continue
		if on:
			if mi.has_meta(SAVED_META):
				n += 1          # already dressed
				continue
			var mat := _material(mi.get_active_material(0))
			if mat == null:
				continue
			mi.set_meta(SAVED_META, [mi.material_override])
			mi.material_override = mat
			n += 1
		elif mi.has_meta(SAVED_META):
			mi.material_override = (mi.get_meta(SAVED_META) as Array)[0]
			mi.remove_meta(SAVED_META)
			n += 1
	return n


static func _swapped(node: Node) -> Array:
	var out: Array = node.find_children("*", "Node3D", true, false).filter(func(x): return x.has_meta(SWAP_META))
	if node.has_meta(SWAP_META):
		out.push_front(node)
	return out


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
		_apply_map(m)
		_mats[base.albedo_texture] = m
	return _mats[base.albedo_texture]


static func _apply_map(m: ShaderMaterial) -> void:
	if _map.is_empty():
		m.set_shader_parameter("shore_on", 0.0)
		return
	for k in _map:
		m.set_shader_parameter(k, _map[k])
