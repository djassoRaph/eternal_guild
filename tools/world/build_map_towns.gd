extends SceneTree
## Builds the world map's settlement scenes (2026-11-08) from KayKit pieces, scaled down to share one hex, and saves
## them as assets/environment/custom/map_towns/<id>.tscn with scripts/world/map_town.gd on the root (the culture's
## colour). Run after the pieces are imported:
##     "E:/Godot installer/Godot_v4.4.1-stable_win64_console.exe" --headless --path . --script res://tools/world/build_map_towns.gd
## A hex is 2.0 m across its flats (x) and 2.31 m point to point (z); its top is y = 0. Parts: [piece, x, z, yaw°, scale].
## The map cameras look from +x +z, so fronts lean that way. Tweak a layout here and run it again.

const OUT := "res://assets/environment/custom/map_towns/"
const SCRIPT := "res://scripts/world/map_town.gd"
const PIECES := {
	"home_A": "res://assets/environment/hexagons/blue/building_home_A_blue.gltf",
	"home_B": "res://assets/environment/hexagons/blue/building_home_B_blue.gltf",
	"well": "res://assets/environment/hexagons/blue/building_well_blue.gltf",
	"market": "res://assets/environment/hexagons/blue/building_market_blue.gltf",
	"church": "res://assets/environment/hexagons/blue/building_church_blue.gltf",
	"windmill": "res://assets/environment/hexagons/blue/building_windmill_blue.gltf",
	"blacksmith": "res://assets/environment/hexagons/blue/building_blacksmith_blue.gltf",
	"castle": "res://assets/environment/hexagons/blue/building_castle_blue.gltf",
	"tower_A": "res://assets/environment/hexagons/blue/building_tower_A_blue.gltf",
	"tower_base": "res://assets/environment/hexagons/blue/building_tower_base_blue.gltf",
	"pillar": "res://assets/environment/custom/d20_prior_pillar.gltf",
	"tree_A": "res://assets/environment/hexagons/nature/tree_single_A.gltf",
	"rock_A": "res://assets/environment/hexagons/nature/rock_single_A.gltf",
	"rock_B": "res://assets/environment/hexagons/nature/rock_single_B.gltf",
	"barrel": "res://assets/environment/hexagons/props/barrel.gltf",
}
const TOWNS := {
	"hamlet_a": [["home_A", -0.36, 0.10, 20, 0.62], ["home_B", 0.36, -0.24, -30, 0.56], ["well", 0.20, 0.44, 0, 0.5],
		["tree_A", -0.22, -0.54, 0, 0.55], ["barrel", 0.55, 0.20, 0, 0.6]],
	"hamlet_b": [["home_B", -0.34, -0.20, 10, 0.6], ["windmill", 0.42, 0.06, -25, 0.52], ["home_A", -0.06, 0.46, 55, 0.5],
		["rock_A", 0.50, -0.52, 0, 0.5]],
	"town_a": [["market", 0.02, 0.0, 0, 0.5], ["home_A", -0.58, -0.36, 30, 0.5], ["home_B", 0.58, -0.40, -25, 0.5],
		["home_A", 0.56, 0.50, -65, 0.48], ["well", -0.50, 0.48, 0, 0.45], ["tree_A", -0.05, -0.64, 0, 0.45]],
	"town_b": [["church", -0.42, -0.30, 15, 0.55], ["pillar", 0.14, 0.10, 0, 0.55], ["home_B", 0.56, -0.38, -30, 0.5],
		["home_A", 0.46, 0.54, -60, 0.48], ["home_A", -0.52, 0.50, 40, 0.48]],
	"city_keep": [["castle", 0.0, -0.04, 0, 0.78]],
	"city_quarter_a": [["tower_A", -0.52, -0.40, 0, 0.5], ["home_B", 0.30, -0.32, 20, 0.52], ["home_A", -0.10, 0.42, -40, 0.5],
		["blacksmith", 0.56, 0.42, -15, 0.45]],
	"city_quarter_b": [["tower_base", 0.50, -0.36, 0, 0.55], ["home_A", -0.46, -0.22, 30, 0.5], ["home_B", 0.0, 0.46, -20, 0.5],
		["well", -0.55, 0.42, 0, 0.42]],
	"watchtower": [["tower_A", 0.0, -0.05, 0, 0.85], ["rock_A", 0.48, 0.38, 0, 0.55], ["rock_B", -0.50, 0.30, 0, 0.45]],
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var bad := 0
	for id in TOWNS:
		bad += 0 if _save(id, TOWNS[id]) else 1
	print("[build_map_towns] %d scenes, %d failed" % [TOWNS.size() - bad, bad])
	quit(1 if bad > 0 else 0)


func _save(id: String, parts: Array) -> bool:
	var root := Node3D.new()
	root.name = id
	root.set_script(load(SCRIPT))
	for i in parts.size():
		var p: Array = parts[i]
		var packed := load(PIECES[p[0]]) as PackedScene
		if packed == null:
			push_error("[build_map_towns] %s: %s doesn't load" % [id, PIECES[p[0]]])
			root.free()
			return false
		var inst := packed.instantiate() as Node3D
		inst.name = "%s_%d" % [p[0], i]
		inst.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(p[3]))).scaled(Vector3.ONE * float(p[4])),
			Vector3(float(p[1]), 0.0, float(p[2])))
		root.add_child(inst)
		inst.owner = root
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, OUT + id + ".tscn")
	root.free()
	print("[build_map_towns] %s: %d parts -> %s (%s)" % [id, parts.size(), OUT + id + ".tscn", error_string(err)])
	return err == OK
