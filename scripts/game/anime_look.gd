# anime_look.gd — the anime cast's look at runtime (Story 25.30, route AN; A-1: toon shading and dark ink outlines).
#
# One entry point, apply(model): every imported StandardMaterial3D surface of a loaded body gets a toon copy of its
# material as a surface override: toon diffuse (the band width is TOON_BAND, carried by roughness), no specular, no
# metal, and the shared ink outline as next_pass. One copy per source material, shared by every instance (a static
# cache); the imported material itself is never edited: imported materials are shared resources (hearth.gd,
# hourglass_pillar.gd). A second call on the same model changes nothing. Culling stays as imported (glTF doubleSided
# gives CULL_DISABLED). A surface that is not opaque gets no outline: the hull has no texture or alpha test and would
# ink a cut-out card's whole shape. staff_npc.gd calls it for variants whose look is "anime" (not on a fallback body);
# 25.31 calls it for the player, the class bodies and the townsfolk. Loaded by path: no class_name.
extends RefCounted

const OUTLINE := preload("res://assets/characters/materials/anime_outline.tres")
const TOON_BAND := 0.12            # the approved anime test's value (> 0: the edge shader and Test 19's roughness rule)

static var _toon := {}             # source material -> its toon copy


## Tone every surface of `model` (its MeshInstance3Ds, props included). Returns the number of surfaces toned.
static func apply(model: Node) -> int:
	if model == null:
		return 0
	var toned := 0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			if (mi as MeshInstance3D).get_surface_override_material(s) != null:
				continue                   # toned already
			var src := mesh.surface_get_material(s)
			if not src is StandardMaterial3D:
				push_warning("[Staff] anime look: %s surface %d is not a StandardMaterial3D; left as imported" % [mi.name, s])
				continue
			(mi as MeshInstance3D).set_surface_override_material(s, _toon_of(src as StandardMaterial3D, str(mi.name)))
			toned += 1
	return toned


static func _toon_of(src: StandardMaterial3D, owner_name: String) -> StandardMaterial3D:
	var toon: StandardMaterial3D = _toon.get(src)
	if toon:
		return toon
	toon = src.duplicate() as StandardMaterial3D       # shallow: it keeps the albedo texture
	toon.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	toon.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	toon.metallic = 0.0
	toon.metallic_specular = 0.0
	toon.roughness = TOON_BAND
	if toon.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		toon.next_pass = OUTLINE
	else:
		push_warning("[Staff] anime look: %s's material %s is not opaque; no outline" % [owner_name, src.resource_name])
	_toon[src] = toon
	return toon
