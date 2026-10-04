# anime_look.gd — the anime cast's look at runtime (Story 25.30, route AN; A-1: toon shading and dark ink outlines).
#
# One entry point, apply(model): every imported StandardMaterial3D surface of a loaded body gets a toon copy of its
# material as a surface override. One copy per source material and look preset, shared by every instance (a static
# cache); the imported material itself is never edited: imported materials are shared resources (hearth.gd,
# hourglass_pillar.gd). A second call on the same model with the same preset changes nothing. A surface that is
# not opaque gets no outline: the hull has no texture or alpha test and would ink a cut-out card's whole shape.
# staff_npc.gd calls it for variants whose look is "anime" (not on a fallback body); 25.31 calls it for the player,
# the class bodies and the townsfolk. Loaded by path: no class_name.
#
# Look presets (2026-10-03, Raphael: "a tad darker ... in the world it's darker"): game_config.json ›
# anime_look_preset names the preset; "approved" (the default, and what an unknown name falls back to, with a
# warning) is the approved anime test's look, set here in code and never by the config:
#   - a StandardMaterial3D copy: toon diffuse (the band width is TOON_BAND, carried by roughness), no specular,
#     no metal, culling as imported (glTF doubleSided gives CULL_DISABLED), emission as imported;
#   - the shared ink outline (anime_outline.tres: grow 0.011, ink (0.17, 0.09, 0.12)) as next_pass.
# Every other preset is a game_config.json › anime_look_presets entry: a ShaderMaterial on anime_toon.gdshader
# (the source's albedo, texture and filter, UV1, vertex colour and emission; the preset's band, lit gain and
# shadow numbers, SHADER_DEFAULTS for any it leaves out) with its own copy of the outline (outline_grow,
# outline_ink) as next_pass. A source the shader can't draw (not opaque, or culling its front faces) gets the
# approved StandardMaterial3D toon instead, no outline when it isn't opaque. set_preset() switches at runtime:
# apply() then re-tones a body toned with another preset (from each toon's source material).
# An EMISSIVE source (AH-3 / V5, Story 25.31 S3: only a prop's own material may emit, the Healer's crystal) gets, in
# every preset, a StandardMaterial3D copy that keeps its emission at roughness 0 with no outline: light, not ink.
extends RefCounted

const OUTLINE := preload("res://assets/characters/materials/anime_outline.tres")
const TOON_SHADER := preload("res://assets/characters/materials/anime_toon.gdshader")
const TOON_BAND := 0.12            # the approved anime test's value (> 0: the edge shader and Test 19's roughness rule)
const GAME_CONFIG_PATH := "res://data/config/game_config.json"
const APPROVED := "approved"       # the default preset: the approved look, defined here (the config can't change it)
## A shader preset's numbers when its game_config entry leaves one out (or gives a bad value): the approved look's.
const SHADER_DEFAULTS := {
	"band_threshold": 0.0,         # N·L at the middle of the light band's edge (DIFFUSE_TOON: 0)
	"band_softness": TOON_BAND,    # half the edge's width (DIFFUSE_TOON: the roughness), 0..1
	"lit_gain": 1.0,               # × every light on the lit side
	"shadow_level": 1.0,           # × the ambient (the unlit side), 0..1
	"shadow_fill": 0.0,            # 0..1: × every light on the unlit side (a toon shadow colour; 0: ambient only)
	"shadow_tint": [1.0, 1.0, 1.0],    # the unlit side's colour cast (each channel 0.05..1)
	"shadow_desaturate": 0.0,      # 0..1: the unlit side's albedo towards grey
	"outline_grow": 0.011,         # the ink hull's grow_amount (m), 0..0.1
	"outline_ink": [0.17, 0.09, 0.12], # the ink hull's colour
}

static var _toon := {}             # preset name -> {source material -> its toon copy}
static var _outlines := {}         # shader preset name -> its outline copy
static var _preset := ""           # the active preset ("" = not read from the config yet)
static var _presets := {}          # shader preset name -> its game_config entry
static var _config_read := false
static var last_warning := ""      # the last warning pushed (tests read it)
const TOON_META := &"anime_toon"   # set on every toon copy (its preset's name): how apply() knows a material is toned
const SOURCE_META := &"anime_toon_source"   # the material a toon copy was made from (re-toning on a preset switch)


## Tone every surface of `model` (its MeshInstance3Ds, props included) with the active preset (or `preset_name`).
## Returns the number of materials toned. What a surface draws is toned: a material_override (it covers every
## surface), else the surface override, else the imported material. Only our own toon copies count as toned
## (review 2026-10-03: any override used to); one of another preset is re-toned from its source.
static func apply(model: Node, preset_name := "") -> int:
	if model == null:
		return 0
	var look := preset() if preset_name == "" else _resolve(preset_name)
	var toned := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		var whole := mi.material_override
		if whole != null:
			if _toned_with(whole, look):
				continue
			var wsrc := _source_of(whole)
			if wsrc is StandardMaterial3D:
				mi.material_override = _toon_of(wsrc as StandardMaterial3D, look, str(mi.name))
				toned += 1
			else:
				_warn("[Staff] anime look: %s's material_override is not a StandardMaterial3D; left as is" % mi.name)
			continue
		for s in mesh.get_surface_count():
			var cur := mi.get_surface_override_material(s)
			if _toned_with(cur, look):
				continue                   # toned already
			var src := _source_of(cur) if cur != null else mesh.surface_get_material(s)
			if not src is StandardMaterial3D:
				_warn("[Staff] anime look: %s surface %d is not a StandardMaterial3D; left as imported" % [mi.name, s])
				continue
			mi.set_surface_override_material(s, _toon_of(src as StandardMaterial3D, look, str(mi.name)))
			toned += 1
	return toned


## A toon copy made by apply() (any preset).
static func is_toon(m: Material) -> bool:
	return m != null and m.has_meta(TOON_META)


## The active preset: game_config.json › anime_look_preset (read once), or what set_preset() chose.
static func preset() -> String:
	if _preset == "":
		_read_config()
		_preset = _resolve(_preset_from_config())
	return _preset


## Switch the active preset at runtime (a later apply() re-tones). An unknown name falls back to "approved" with a
## warning. Returns the preset now active.
static func set_preset(preset_name: String) -> String:
	_read_config()
	_preset = _resolve(preset_name)
	return _preset


## Read game_config.json again (after tuning a preset's numbers): the shader presets' copies and outlines are made
## anew; the approved copies stay (the config can't change them).
static func reload() -> String:
	_config_read = false
	_preset = ""
	_outlines.clear()
	for k in _toon.keys():
		if k != APPROVED:
			_toon.erase(k)
	return preset()


## Every preset name: "approved", then the config's.
static func preset_names() -> Array:
	_read_config()
	return [APPROVED] + _presets.keys()


## A shader preset's numbers, its config entry over SHADER_DEFAULTS, each checked (a bad value: the default, warned).
static func params(preset_name: String) -> Dictionary:
	_read_config()
	var entry: Dictionary = _presets.get(preset_name, {})
	var out := {}
	for key in SHADER_DEFAULTS:
		var want = SHADER_DEFAULTS[key]
		var got = entry.get(key, want)
		if want is Array:
			var ok: bool = got is Array and got.size() == 3 and got.all(func(v): return (v is float or v is int) and is_finite(float(v)) and float(v) >= 0.0 and float(v) <= 1.0)
			if ok and key == "shadow_tint":
				ok = got.all(func(v): return float(v) >= 0.05)   # the lit band divides the tint back out
			if not ok:
				_warn("[Staff] anime look: preset '%s' %s = %s is not 3 numbers in range; using %s" % [preset_name, key, got, want])
				got = want
			out[key] = Color(float(got[0]), float(got[1]), float(got[2]))
		else:
			var ok: bool = (got is float or got is int) and is_finite(float(got))
			if ok:
				match key:
					"band_softness":
						ok = float(got) > 0.0 and float(got) <= 1.0
					"outline_grow":
						ok = float(got) > 0.0 and float(got) <= 0.1
					"lit_gain":
						ok = float(got) >= 0.0 and float(got) <= 4.0
					"shadow_level", "shadow_fill", "shadow_desaturate":
						ok = float(got) >= 0.0 and float(got) <= 1.0
					"band_threshold":
						ok = float(got) >= -1.0 and float(got) <= 1.0
			if not ok:
				_warn("[Staff] anime look: preset '%s' %s = %s is out of range; using %s" % [preset_name, key, got, want])
				got = want
			out[key] = float(got)
	return out


static func _toned_with(m: Material, look: String) -> bool:
	return is_toon(m) and str(m.get_meta(TOON_META)) == look


## What a toon copy was made from (itself when it isn't one of ours).
static func _source_of(m: Material) -> Material:
	if is_toon(m) and m.get_meta(SOURCE_META, null) is Material:
		return m.get_meta(SOURCE_META)
	return m


static func _resolve(preset_name: String) -> String:
	_read_config()
	if preset_name == APPROVED or _presets.has(preset_name):
		return preset_name
	_warn("[Staff] anime look: unknown preset '%s' (known: %s); using %s" % [preset_name, [APPROVED] + _presets.keys(), APPROVED])
	return APPROVED


static func _preset_from_config() -> String:
	var cfg = _config()
	var want = cfg.get("anime_look_preset", APPROVED) if cfg is Dictionary else APPROVED
	return str(want) if want is String and str(want) != "" else APPROVED


static func _config() -> Variant:
	if not FileAccess.file_exists(GAME_CONFIG_PATH):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(GAME_CONFIG_PATH))   # Godot's parser: lenient, like DataManager's


static func _read_config() -> void:
	if _config_read:
		return
	_config_read = true
	_presets.clear()
	var cfg = _config()
	var all = cfg.get("anime_look_presets", {}) if cfg is Dictionary else {}
	if not all is Dictionary:
		_warn("[Staff] anime look: game_config anime_look_presets is not an object; only %s" % APPROVED)
		return
	for key in all:
		var k := str(key)
		if k.begins_with("_"):
			continue                       # _comment
		if k == APPROVED or not all[key] is Dictionary:
			_warn("[Staff] anime look: game_config anime_look_presets.%s ignored (%s)" % [k, "the approved look is set in code" if k == APPROVED else "not an object"])
			continue
		_presets[k] = all[key]


static func _warn(msg: String) -> void:
	last_warning = msg
	push_warning(msg)


static func _toon_of(src: StandardMaterial3D, look: String, owner_name: String) -> Material:
	var cache: Dictionary = _toon.get(look, {})
	_toon[look] = cache
	var toon: Material = cache.get(src)
	if toon:
		return toon
	if src.emission_enabled:
		toon = _glow_toon(src)             # AH-3 / V5 (25.31): a prop's light, whatever the preset
	elif look == APPROVED:
		toon = _standard_toon(src, OUTLINE, owner_name)
	elif src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or src.cull_mode == BaseMaterial3D.CULL_FRONT:
		_warn("[Staff] anime look: %s's material %s can't take the %s shader (not opaque, or culling its front); the approved toon instead" % [owner_name, src.resource_name, look])
		toon = _standard_toon(src, _outline_of(look), owner_name)
	else:
		toon = _shader_toon(src, look)
	toon.set_meta(TOON_META, look)
	toon.set_meta(SOURCE_META, src)
	cache[src] = toon
	return toon


## AH-3 / V5 (Story 25.31 S3): an emissive source is light, not ink: its toon copy KEEPS the emission, stays at
## roughness 0 (the edge shader leaves roughness 0 un-inked) and gets no outline next_pass; toon diffuse, no specular,
## no metal.
static func _glow_toon(src: StandardMaterial3D) -> StandardMaterial3D:
	var toon := src.duplicate() as StandardMaterial3D
	toon.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	toon.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	toon.metallic = 0.0
	toon.metallic_specular = 0.0
	toon.metallic_texture = null
	toon.roughness = 0.0
	toon.roughness_texture = null
	toon.next_pass = null
	return toon


## The approved look's toon copy (unchanged since Story 25.30).
static func _standard_toon(src: StandardMaterial3D, outline: Material, owner_name: String) -> StandardMaterial3D:
	var toon := src.duplicate() as StandardMaterial3D       # shallow: it keeps the albedo texture
	toon.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	toon.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	toon.metallic = 0.0
	toon.metallic_specular = 0.0
	toon.metallic_texture = null       # the maps would bring the metal and the band back per texel
	toon.roughness = TOON_BAND
	toon.roughness_texture = null
	if toon.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		toon.next_pass = outline
	else:
		_warn("[Staff] anime look: %s's material %s is not opaque; no outline" % [owner_name, src.resource_name])
	return toon


## A shader preset's toon: anime_toon.gdshader with the source's surface and the preset's numbers.
static func _shader_toon(src: StandardMaterial3D, look: String) -> ShaderMaterial:
	var p := params(look)
	var m := ShaderMaterial.new()
	m.resource_name = "%s_%s" % [src.resource_name, look]
	m.shader = TOON_SHADER
	m.set_shader_parameter("albedo_color", src.albedo_color)
	var tex := src.albedo_texture
	var linear := src.texture_filter in [BaseMaterial3D.TEXTURE_FILTER_LINEAR, BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC]
	if tex:
		m.set_shader_parameter("albedo_linear" if linear else "albedo_nearest", tex)
	m.set_shader_parameter("albedo_use_linear", linear)
	m.set_shader_parameter("use_vertex_color", src.vertex_color_use_as_albedo)
	m.set_shader_parameter("uv1_scale", src.uv1_scale)
	m.set_shader_parameter("uv1_offset", src.uv1_offset)
	if src.emission_enabled:
		m.set_shader_parameter("emission_color", src.emission)
		m.set_shader_parameter("emission_energy", src.emission_energy_multiplier)
		m.set_shader_parameter("emission_add", src.emission_operator == BaseMaterial3D.EMISSION_OP_ADD)
		if src.emission_texture:
			m.set_shader_parameter("emission_texture", src.emission_texture)
	for key in ["band_threshold", "band_softness", "lit_gain", "shadow_level", "shadow_fill", "shadow_desaturate"]:
		m.set_shader_parameter(key, p[key])
	var tint: Color = p.shadow_tint
	m.set_shader_parameter("shadow_tint", Vector3(tint.r, tint.g, tint.b))
	m.set_shader_parameter("ink_roughness", TOON_BAND)
	m.next_pass = _outline_of(look)
	return m


## A shader preset's ink hull: a copy of the shared outline with the preset's width and colour (one per preset).
static func _outline_of(look: String) -> Material:
	if look == APPROVED:
		return OUTLINE
	var o: StandardMaterial3D = _outlines.get(look)
	if o:
		return o
	var p := params(look)
	o = OUTLINE.duplicate() as StandardMaterial3D
	o.resource_name = "anime_outline_%s" % look
	o.grow_amount = p.outline_grow
	var ink: Color = p.outline_ink
	o.albedo_color = Color(ink.r, ink.g, ink.b, 1.0)
	_outlines[look] = o
	return o
