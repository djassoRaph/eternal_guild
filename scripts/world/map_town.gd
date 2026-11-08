# map_town.gd — a settlement or a watchtower on the world map (2026-11-08, Raphael: "work on 3D models of world map
# monuments and towns"): a scene of KayKit pieces on one hex (assets/environment/custom/map_towns/*.tscn, built by
# tools/world/build_map_towns.gd). HexMapGenerator calls dress_for(record) on any topper that has it: here the
# buildings' team colour (KayKit's blue swatch) takes the record's culture's colour from a copy of the atlas
# (tools/world/make_town_atlases.py): the heartland red, the southreach ochre; the northmark keeps KayKit's blue.
# Only materials drawn from the KayKit atlas are swapped (a glowing Prior pillar in a square keeps its glow), and the
# tinted copies are shared by every town of a culture.
extends Node3D

const TINTS := {
	"heartland": "res://assets/environment/custom/map_towns/hexagons_medieval_heartland.png",
	"southreach": "res://assets/environment/custom/map_towns/hexagons_medieval_southreach.png",
}
const ATLAS_FILE := "hexagons_medieval.png"

static var _tinted := {}   # "<culture>|<source material's instance id>" -> its tinted copy

var culture := ""   # the culture it was dressed for ("" = KayKit's own colours)


func dress_for(rec: Dictionary) -> void:
	var c := str(rec.get("culture", ""))
	var path: String = TINTS.get(c, "")
	if path == "" or not ResourceLoader.exists(path):
		return
	var tex := load(path) as Texture2D
	if tex == null:
		return
	culture = c
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as BaseMaterial3D
			if src == null or src.albedo_texture == null or not src.albedo_texture.resource_path.ends_with(ATLAS_FILE):
				continue
			var key := "%s|%d" % [c, src.get_instance_id()]
			var m: BaseMaterial3D = _tinted.get(key)
			if m == null:
				m = src.duplicate() as BaseMaterial3D
				m.albedo_texture = tex
				_tinted[key] = m
			mi.set_surface_override_material(i, m)
