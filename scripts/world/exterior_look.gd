# exterior_look.gd — the exterior's look (brainstorm 2026-11-03, BMAD _bmad-output/brainstorming-session-2026-11-03.md,
# idea #29: Raphael's Octopath shot is the OUTSIDE's reference: blue dusk, haze, warm windows, textured cobbles,
# braziers). A node ExteriorWorld adds at _ready (game_config "exterior_look", true when absent):
# - the ground in world space: ext_grass on the terrain, ext_cobble on the road and the square, ext_water on the stream;
#   the KayKit village buildings on ext_building (their own atlas, the window cell glowing by phase);
# - the light and the air per day phase (LOOKS: sun, ambient, background, depth haze, mist in the stream's valley,
#   glow, exposure, saturation, the lamps and the windows), blended over BLEND_SECONDS when the day clock
#   (GameBus.day_phase_changed) moves on; it starts at the clock's phase (GameManager.day_clock_phase()) like the hall;
# - code-made placeholder props, on the ground by raycast: braziers along the road, lamp posts round the square, a warm
#   glow at each house and at the guild tavern's door and windows, and falling leaves;
# - (Story 25.35) the kit town: buildings in group village_kit and forest pieces in group nature_kit keep their own
#   textured kit materials (Quaternius, CC0), tinted toward the hall's palette and toon-shaded, each building's roof in
#   its own colour (metadata roof_tint), the kit windows glowing by phase (apply_kit).
# Off (dev key 5) puts the scene's own environment, sun and materials back and frees the props. Dev key 2 steps the
# phase. Nothing is written into ExteriorWorld.tscn. Loaded by path: no class_name.
extends Node

const GRASS_SHADER := preload("res://assets/shaders/ext_grass.gdshader")
const COBBLE_SHADER := preload("res://assets/shaders/ext_cobble.gdshader")
const WATER_SHADER := preload("res://assets/shaders/ext_water.gdshader")
const BUILDING_SHADER := preload("res://assets/shaders/ext_building.gdshader")
const KIT_ROOF_SHADER := preload("res://assets/shaders/kit_roof.gdshader")
const EDGE_PASS := preload("res://scripts/game/edge_pass.gd")
const PHASES := ["morning", "day", "dusk", "evening", "late_night", "dawn"]
const PHASE_ALIASES := {"reveal": "late_night"}
const DEFAULT_PHASE := "day"
const BLEND_SECONDS := 4.0
const SAVED_META := &"exterior_look_saved"
const PROPS_NAME := "ExteriorLookProps"
## The terrain's meshes (a6_exterior_terrain.gltf) and the look each takes.
const TERRAIN_PATH := "Terrain/TerrainMesh"
## Story 25.35: the town's street ribbons (a6_town_streets.gltf, mesh terrain_paths) take the same ground pass.
const STREETS_PATH := "Terrain/Streets"
const GROUND :={"terrain": "grass", "terrain_paths": "cobble", "terrain_water": "water"}
const VILLAGE_PATH := "Village"
const VILLAGE_SKIP := ["Street", "Well", "Fountain"]   # not buildings with windows: no atlas look, no glow
## Story 25.35: the kit town. Kit buildings (group KIT_GROUP) skip the KayKit atlas pass; they and the kit forest
## (group NATURE_GROUP) take apply_kit instead: each kit material (named MI_* / P_* / the nature kit's, a Blender
## ".00N" suffix ignored) multiplied by its KIT_TINT, toon-shaded; a building's roof tiles by its "roof_tint" metadata;
## the kit window glass swapped for one shared pane that glows by phase (KIT_WINDOW_ENERGY x the look's windows).
const KIT_GROUP := &"village_kit"
const NATURE_GROUP := &"nature_kit"
const KIT_SAVED_META := &"exterior_look_kit_saved"
const KIT_ROOF := "MI_RoundTiles"
const KIT_WINDOW := "MI_WindowGlass"
const KIT_WINDOW_ENERGY := 2.2
const KIT_TINT := {
	"MI_RoundTiles": Color(0.50, 0.36, 0.40), "MI_WoodTrim": Color(0.52, 0.42, 0.38), "MI_WoodTrim_Wear": Color(0.48, 0.40, 0.36),
	"MI_Plaster": Color(0.80, 0.80, 0.80), "MI_UnevenBrick": Color(0.72, 0.72, 0.76), "MI_RedBrick": Color(0.46, 0.38, 0.38),
	"MI_Brick": Color(0.70, 0.66, 0.66), "MI_RockTrim": Color(0.72, 0.72, 0.76), "P_Terracotta": Color(0.70, 0.56, 0.52),
	"Leaves_Pine": Color(0.78, 0.85, 0.72), "Leaves_NormalTree": Color(0.78, 0.85, 0.72), "Leaves_TwistedTree": Color(0.85, 0.80, 0.78),
	"Leaves": Color(0.78, 0.85, 0.72), "Grass": Color(0.80, 0.86, 0.74), "Bark_NormalTree": Color(0.75, 0.70, 0.68),
	"Bark_DeadTree": Color(0.70, 0.68, 0.70), "Bark_TwistedTree": Color(0.72, 0.68, 0.66), "Rocks": Color(0.78, 0.78, 0.82),
}
## The guild tavern (a1_guild_tavern.gltf) and its own emissive window material, which follows the phase's windows
## (never below TAVERN_WINDOW_FLOOR: the guild's light is always a little on).
const TAVERN_PATH := "GuildTavern"
const TAVERN_WINDOW_MAT := "emissive_window_mat"
const TAVERN_WINDOW_FLOOR := 0.15
## The ground rays only take hits under this node (the terrain's collider), never a tent, a cart or the player.
const GROUND_ROOT := "Terrain"
## The light and the air per phase. Colours are [r, g, b]; lamps and windows are 0..1 scales.
const LOOKS := {
	"morning": {"sun_color": [1.0, 0.85, 0.7], "sun_energy": 0.6, "ambient_color": [0.5, 0.56, 0.68], "ambient_energy": 0.65,
		"bg_color": [0.62, 0.68, 0.78], "fog_color": [0.72, 0.76, 0.84], "fog": 0.4, "mist": 0.06, "glow": 0.4,
		"lamps": 0.25, "windows": 0.3, "saturation": 0.82, "exposure": 1.0},
	"day": {"sun_color": [1.0, 0.95, 0.85], "sun_energy": 0.95, "ambient_color": [0.6, 0.64, 0.7], "ambient_energy": 0.6,
		"bg_color": [0.55, 0.68, 0.8], "fog_color": [0.72, 0.8, 0.9], "fog": 0.16, "mist": 0.0, "glow": 0.3,
		"lamps": 0.0, "windows": 0.0, "saturation": 0.88, "exposure": 1.0},
	"dusk": {"sun_color": [1.0, 0.55, 0.35], "sun_energy": 0.65, "ambient_color": [0.42, 0.38, 0.52], "ambient_energy": 0.6,
		"bg_color": [0.35, 0.3, 0.42], "fog_color": [0.55, 0.45, 0.55], "fog": 0.34, "mist": 0.04, "glow": 0.7,
		"lamps": 0.7, "windows": 0.8, "saturation": 0.85, "exposure": 1.0},
	"evening": {"sun_color": [0.55, 0.65, 0.95], "sun_energy": 0.32, "ambient_color": [0.2, 0.28, 0.48], "ambient_energy": 0.58,
		"bg_color": [0.08, 0.12, 0.22], "fog_color": [0.22, 0.3, 0.46], "fog": 0.42, "mist": 0.05, "glow": 1.0,
		"lamps": 1.0, "windows": 1.0, "saturation": 0.92, "exposure": 1.15},
	"late_night": {"sun_color": [0.45, 0.55, 0.9], "sun_energy": 0.22, "ambient_color": [0.14, 0.2, 0.38], "ambient_energy": 0.52,
		"bg_color": [0.05, 0.07, 0.14], "fog_color": [0.16, 0.22, 0.36], "fog": 0.48, "mist": 0.06, "glow": 1.0,
		"lamps": 1.0, "windows": 0.8, "saturation": 0.88, "exposure": 1.2},
	"dawn": {"sun_color": [0.9, 0.7, 0.65], "sun_energy": 0.45, "ambient_color": [0.4, 0.42, 0.58], "ambient_energy": 0.6,
		"bg_color": [0.4, 0.42, 0.55], "fog_color": [0.6, 0.6, 0.7], "fog": 0.42, "mist": 0.07, "glow": 0.5,
		"lamps": 0.4, "windows": 0.4, "saturation": 0.8, "exposure": 1.0},
}
const LOOK_KEYS := ["sun_color", "sun_energy", "ambient_color", "ambient_energy", "bg_color", "fog_color", "fog", "mist",
	"glow", "lamps", "windows", "saturation", "exposure"]
## The haze: depth fog from FOG_BEGIN to FOG_END metres from the camera (it sits about 29 m from the ground it frames),
## and mist below MIST_HEIGHT (the stream's valley floor is at y -3.25).
const FOG_BEGIN := 34.0
const FOG_END := 95.0
const MIST_HEIGHT := -2.0
## Props (x, z), put on the ground by raycast: braziers beside the road (tavern -> bridge), lamp posts round the square,
## the guild tavern's door and window glows (offsets from it, with heights), and each house's glow toward the square.
const BRAZIERS := [Vector2(-16.5, 12.4), Vector2(-11.0, 7.6), Vector2(-4.0, 12.8), Vector2(3.2, 12.5), Vector2(9.8, 7.4)]
const LAMP_POSTS := [Vector2(12.0, 2.5), Vector2(23.5, 2.5), Vector2(24.6, 12.2), Vector2(10.6, 12.0)]   # ~0.7 m clear of the stall tents
const SQUARE_CENTER := Vector2(17.5, 8.0)
const TAVERN_GLOWS := [Vector3(4.9, 1.6, -1.0), Vector3(4.6, 1.8, 2.8), Vector3(1.0, 1.8, 8.6)]   # 25.36: door, front window, brewhouse
const BRAZIER_ENERGY := 3.0
const LAMP_ENERGY := 2.0
const HOUSE_ENERGY := 1.2
const FIRE_COLOR := Color(1.0, 0.55, 0.25)
const LAMP_COLOR := Color(1.0, 0.68, 0.38)

var phase := DEFAULT_PHASE
var applied := {}

var _world: Node3D
var _we: WorldEnvironment
var _orig_env: Environment
var _env: Environment
var _sun: DirectionalLight3D
var _sun_saved := {}
var _building_mats := {}           # atlas texture -> its ext_building material (apply_materials' cache)
var _tavern_windows: Array = []    # [mesh, surface, the look's copy, its base emission energy]
var _kit := {}                     # apply_kit's cache: kit material copies and the shared "window" pane
var _lamps: Array = []             # [light, base_energy, flicker, flicker phase]
var _from := {}
var _to := {}
var _blend_t := 1.0
var _blend_len := BLEND_SECONDS
var _clock := 0.0


func _ready() -> void:
	_world = get_parent() as Node3D
	var gb := get_node_or_null("/root/GameBus")
	if gb and gb.has_signal("day_phase_changed"):
		gb.day_phase_changed.connect(set_phase)
	phase = _start_phase()
	# the node is always there (dev key 5 can turn the look on), the config only decides the start
	var dm := get_node_or_null("/root/DataManager")
	set_on(config_flag(dm.get_config("exterior_look", true) if dm else true, "exterior_look"))
	print("[ExteriorLook] look %s, phase %s" % ["on" if is_on() else "off", phase])


## A config switch: a bool, or true (with a warning) for anything else, so a typo can't break the scene.
static func config_flag(v, key: String) -> bool:
	if v is bool:
		return v
	push_warning("[ExteriorLook] game_config %s = %s is not true/false; using true" % [key, v])
	return true


func _process(delta: float) -> void:
	_clock += delta
	if is_on() and _blend_t < 1.0:
		_blend_t = minf(_blend_t + (delta / _blend_len if _blend_len > 0.0 else 1.0), 1.0)
		applied = blend(_from, _to, _blend_t)
		_apply(applied)
	for l in _lamps:
		var light := l[0] as OmniLight3D
		if is_instance_valid(light) and light.visible and l[2]:
			var t: float = _clock * 9.0 + float(l[3])
			light.light_energy = float(light.get_meta("lit", 0.0)) * (0.88 + 0.08 * sin(t) + 0.04 * sin(t * 2.7))


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	match k.keycode:
		KEY_2:
			set_phase(PHASES[(PHASES.find(phase) + 1) % PHASES.size()], 0.0)
		KEY_4:
			for q in EDGE_PASS.quads(_world.get_node_or_null("Camera3D") if _world else null):
				(q as MeshInstance3D).visible = not (q as MeshInstance3D).visible
		KEY_5:
			set_on(not is_on())
		_:
			return
	print("[ExteriorLook] look %s, phase %s" % ["on" if is_on() else "off", phase])


# ---------------------------------------------------------------- static: data ----------------------------------

## A phase name ("reveal" is late_night), or "" when unknown.
static func resolve_phase(phase_name: String) -> String:
	var p: String = PHASE_ALIASES.get(phase_name, phase_name)
	return p if p in PHASES else ""


## A phase's look: colours as Color, numbers as float (an unknown phase: the day's).
static func look_values(phase_name: String) -> Dictionary:
	var src: Dictionary = LOOKS.get(resolve_phase(phase_name), LOOKS[DEFAULT_PHASE])
	var out := {}
	for k in LOOK_KEYS:
		var v = src[k]
		out[k] = Color(v[0], v[1], v[2]) if v is Array else float(v)
	return out


## Every number and colour from a to b at t (0..1); a key missing from a (or of another type) takes b's.
static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k in b:
		var av = a.get(k)
		if b[k] is Color:
			out[k] = (av as Color).lerp(b[k], t) if av is Color else b[k]
		else:
			out[k] = lerpf(float(av), float(b[k]), t) if (av is float or av is int) else float(b[k])
	return out


## The material a ground mesh takes (by the terrain mesh's name), or null.
static func ground_material(mesh_name: String) -> ShaderMaterial:
	var kind: String = GROUND.get(mesh_name, "")
	if kind == "":
		return null
	var m := ShaderMaterial.new()
	m.shader = {"grass": GRASS_SHADER, "cobble": COBBLE_SHADER, "water": WATER_SHADER}[kind]
	return m


## Put the ground and building materials on (or back off) the exterior under `world`; returns {ground, buildings,
## building_mats, building_mat}. A building mesh takes the look only when its own material is a BaseMaterial3D with an
## albedo texture: one ext_building material per texture (`building_mats`, texture -> material, reused when given);
## `building_mat` is the first of them.
static func apply_materials(world: Node, on: bool, building_mats: Dictionary = {}) -> Dictionary:
	var out := {"ground": 0, "buildings": 0, "building_mats": building_mats, "building_mat": null}
	for ground_path in [TERRAIN_PATH, STREETS_PATH]:
		var terrain := world.get_node_or_null(ground_path)
		if terrain == null:
			continue
		for mi in terrain.find_children("*", "MeshInstance3D", true, false):
			var m: ShaderMaterial = ground_material(mi.name) if on else null
			if on and m == null:
				continue
			if _set_material(mi, m, on):
				out.ground += 1
	var village := world.get_node_or_null(VILLAGE_PATH)
	if village:
		for b in village.get_children():
			if b.name in VILLAGE_SKIP or b.is_in_group(KIT_GROUP):
				continue
			var meshes: Array = b.find_children("*", "MeshInstance3D", true, false)
			if b is MeshInstance3D:
				meshes.append(b)
			for mi in meshes:
				var m: ShaderMaterial = null
				if on:
					m = _building_material((mi as MeshInstance3D).get_active_material(0), building_mats)
					if m == null:
						continue
				if _set_material(mi, m, on):
					out.buildings += 1
	if not building_mats.is_empty():
		out.building_mat = building_mats.values()[0]
	return out


## The ext_building material for a building mesh's own material (one per atlas texture), or null when it has no
## textured BaseMaterial3D (it keeps its own).
static func _building_material(src: Material, cache: Dictionary) -> ShaderMaterial:
	var base := src as BaseMaterial3D
	if base == null or base.albedo_texture == null:
		return null
	if not cache.has(base.albedo_texture):
		var m := ShaderMaterial.new()
		m.shader = BUILDING_SHADER
		m.set_shader_parameter("atlas", base.albedo_texture)
		cache[base.albedo_texture] = m
	return cache[base.albedo_texture]


## Story 25.35: put the kit look on (or back off) every kit building (KIT_GROUP) under Village and every kit piece
## (NATURE_GROUP) under Forest. `cache` holds the material copies (source material [+ roof colour] -> copy) and the
## shared window pane, so a re-apply reuses them. Returns {meshes, window}.
static func apply_kit(world: Node, on: bool, cache: Dictionary) -> Dictionary:
	var out := {"meshes": 0, "window": null}
	var kit_nodes := []
	for parent_path in [VILLAGE_PATH, "Forest"]:
		var parent := world.get_node_or_null(parent_path)
		if parent:
			kit_nodes.append_array(parent.get_children())
	var tavern := world.get_node_or_null(TAVERN_PATH)   # Story 25.36: the kit tavern (its glass stays the tavern's own)
	if tavern:
		kit_nodes.append(tavern)
	for b in kit_nodes:
		if not (b.is_in_group(KIT_GROUP) or b.is_in_group(NATURE_GROUP)):   # the Fountain too: the kit look, no glow
			continue
		var roof: Color = b.get_meta("roof_tint", KIT_TINT[KIT_ROOF])
		for mi in b.find_children("*", "MeshInstance3D", true, false):
			if _set_kit(mi, on, roof, cache):
				out.meshes += 1
	out.window = cache.get("window")
	return out


## "MI_Plaster.004" -> "MI_Plaster" (Blender's duplicate suffix); anything else unchanged.
static func kit_base_name(material_name: String) -> String:
	var i := material_name.rfind(".")
	if i > 0 and material_name.substr(i + 1).is_valid_int():
		return material_name.substr(0, i)
	return material_name


static func _set_kit(mi: MeshInstance3D, on: bool, roof: Color, cache: Dictionary) -> bool:
	if mi.mesh == null:
		return false
	var n := mi.mesh.get_surface_count()
	if on:
		if not mi.has_meta(KIT_SAVED_META):
			var saved := []
			for s in n:
				saved.append(mi.get_surface_override_material(s))
			mi.set_meta(KIT_SAVED_META, saved)
		for s in n:
			if _is_tavern_window(mi.mesh.surface_get_material(s)):
				continue   # _set_tavern_windows owns that surface
			mi.set_surface_override_material(s, _kit_material(mi.mesh.surface_get_material(s), roof, cache))
		return true
	if mi.has_meta(KIT_SAVED_META):
		var saved: Array = mi.get_meta(KIT_SAVED_META)
		for s in mini(saved.size(), n):
			if _is_tavern_window(mi.mesh.surface_get_material(s)):
				continue
			mi.set_surface_override_material(s, saved[s])
		mi.remove_meta(KIT_SAVED_META)
		return true
	return false


static func _is_tavern_window(m: Material) -> bool:
	return m != null and m.resource_name == TAVERN_WINDOW_MAT


## The look's copy of a kit material (null keeps the mesh's own: not a BaseMaterial3D).
static func _kit_material(src: Material, roof: Color, cache: Dictionary) -> Material:
	var base := src as BaseMaterial3D
	if base == null:
		return null
	var kind := kit_base_name(base.resource_name)
	if kind == KIT_WINDOW:
		if not cache.has("window"):
			var w := StandardMaterial3D.new()
			w.albedo_color = Color(0.10, 0.09, 0.11)
			w.roughness = 1.0
			w.emission_enabled = true
			w.emission = Color(1.0, 0.62, 0.30)
			w.emission_energy_multiplier = 0.0
			cache["window"] = w
		return cache["window"]
	var key := "%d" % base.get_instance_id()
	if kind == KIT_ROOF:
		key += ":" + roof.to_html()
		if not cache.has(key):
			var r := ShaderMaterial.new()
			r.shader = KIT_ROOF_SHADER
			r.set_shader_parameter("albedo_tex", base.albedo_texture)
			r.set_shader_parameter("use_normal", base.normal_enabled and base.normal_texture != null)
			r.set_shader_parameter("normal_tex", base.normal_texture)
			r.set_shader_parameter("roof_color", roof)
			r.set_shader_parameter("uv1_scale", base.uv1_scale)
			r.set_shader_parameter("uv1_offset", base.uv1_offset)
			cache[key] = r
		return cache[key]
	if not cache.has(key):
		var m := base.duplicate() as BaseMaterial3D
		var tint: Color = roof if kind == KIT_ROOF else KIT_TINT.get(kind, Color.WHITE)
		m.albedo_color = base.albedo_color * tint
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		m.roughness = 1.0
		cache[key] = m
	return cache[key]


## On: keep the mesh's own override (once, wrapped in an array so even a null override is kept) and put `mat` on.
## Off: put the kept one back. True when it changed.
static func _set_material(mi: MeshInstance3D, mat: Material, on: bool) -> bool:
	if on:
		if not mi.has_meta(SAVED_META):
			mi.set_meta(SAVED_META, [mi.material_override])
		mi.material_override = mat
		return true
	if mi.has_meta(SAVED_META):
		mi.material_override = (mi.get_meta(SAVED_META) as Array)[0]
		mi.remove_meta(SAVED_META)
		return true
	return false


# ---------------------------------------------------------------- the node ----------------------------------------

func is_on() -> bool:
	return _env != null


## Put the look on (the materials, the environment copy, the sun, the props) or take it all off.
func set_on(on: bool) -> void:
	if _world == null:
		return
	if on == is_on():
		return
	apply_materials(_world, on, _building_mats)
	apply_kit(_world, on, _kit)
	_set_tavern_windows(on)
	_we = _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_sun = _world.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if on:
		if _we:
			_orig_env = _we.environment
			_env = _orig_env.duplicate() if _orig_env else Environment.new()
			_setup_env(_env)
			_we.environment = _env
		else:
			_env = Environment.new()
		if _sun:
			_sun_saved = {"light_color": _sun.light_color, "light_energy": _sun.light_energy}
		# the props go on after a physics frame (the terrain's collider answers the ground rays from then on); a
		# one-shot connection to this node's method, so a scene change before that frame drops it with the node
		if is_inside_tree():
			if not get_tree().physics_frame.is_connected(_build_props):
				get_tree().physics_frame.connect(_build_props, CONNECT_ONE_SHOT)
		else:
			_build_props()
		_blend_t = 1.0
		applied = look_values(phase)
		_apply(applied)
	else:
		if _we:
			_we.environment = _orig_env
		_env = null
		if _sun:
			for k in _sun_saved:
				_sun.set(k, _sun_saved[k])
		var props := _world.get_node_or_null(PROPS_NAME)
		if props:
			_world.remove_child(props)
			props.free()
		_lamps.clear()


## Blend to a phase over `seconds` (-1: BLEND_SECONDS; 0: at once). An unknown phase: no change.
func set_phase(phase_name: String, seconds := -1.0) -> void:
	var p := resolve_phase(phase_name)
	if p == "":
		push_warning("[ExteriorLook] unknown phase '%s'" % phase_name)
		return
	phase = p
	if not is_on():
		return
	_from = applied.duplicate()
	_to = look_values(p)
	_blend_len = BLEND_SECONDS if seconds < 0.0 else seconds
	if _blend_len <= 0.0:
		_blend_t = 1.0
		applied = _to
		_apply(applied)
	else:
		_blend_t = 0.0


## The guild tavern's own window material follows the phase: on, each window surface gets a copy (its own surface
## override kept, wrapped, in metadata); off puts the kept override back.
func _set_tavern_windows(on: bool) -> void:
	if not on:
		for w in _tavern_windows:
			var mi := w[0] as MeshInstance3D
			if is_instance_valid(mi) and mi.has_meta(SAVED_META):
				mi.set_surface_override_material(int(w[1]), (mi.get_meta(SAVED_META) as Array)[0])
				mi.remove_meta(SAVED_META)
		_tavern_windows.clear()
		return
	var tavern := _world.get_node_or_null(TAVERN_PATH)
	if tavern == null:
		return
	for node in tavern.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in (mi.mesh.get_surface_count() if mi.mesh else 0):
			var src := mi.get_active_material(s) as BaseMaterial3D
			if src == null or src.resource_name != TAVERN_WINDOW_MAT or mi.has_meta(SAVED_META):
				continue
			mi.set_meta(SAVED_META, [mi.get_surface_override_material(s)])
			var copy := src.duplicate() as BaseMaterial3D
			mi.set_surface_override_material(s, copy)
			_tavern_windows.append([mi, s, copy, src.emission_energy_multiplier])


func _start_phase() -> String:
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("day_clock_phase"):
		var p := resolve_phase(str(gm.day_clock_phase()))
		if p != "":
			return p
	return DEFAULT_PHASE


## The environment's fixed settings (the per-phase numbers come in _apply).
func _setup_env(e: Environment) -> void:
	e.background_mode = Environment.BG_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_depth_begin = FOG_BEGIN
	e.fog_depth_end = FOG_END
	e.fog_depth_curve = 1.4
	e.fog_height = MIST_HEIGHT
	e.fog_sun_scatter = 0.0
	e.glow_enabled = true
	e.glow_bloom = 0.06
	e.glow_hdr_threshold = 0.85
	e.glow_strength = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06


func _apply(v: Dictionary) -> void:
	if _env:
		_env.background_color = v.bg_color
		_env.ambient_light_color = v.ambient_color
		_env.ambient_light_energy = float(v.ambient_energy)
		_env.fog_light_color = v.fog_color
		_env.fog_density = float(v.fog)
		_env.fog_height_density = float(v.mist)
		_env.glow_intensity = float(v.glow)
		_env.adjustment_saturation = float(v.saturation)
		_env.tonemap_exposure = float(v.exposure)
	if _sun:
		_sun.light_color = v.sun_color
		_sun.light_energy = float(v.sun_energy)
	for m in _building_mats.values():
		(m as ShaderMaterial).set_shader_parameter("window_glow", float(v.windows))
	for w in _tavern_windows:
		(w[2] as BaseMaterial3D).emission_energy_multiplier = float(w[3]) * maxf(float(v.windows), TAVERN_WINDOW_FLOOR)
	if _kit.has("window"):
		(_kit["window"] as BaseMaterial3D).emission_energy_multiplier = KIT_WINDOW_ENERGY * float(v.windows)
	for l in _lamps:
		var light := l[0] as OmniLight3D
		if not is_instance_valid(light):
			continue
		var e := float(l[1]) * float(v.lamps)
		light.set_meta("lit", e)
		light.light_energy = e
		light.visible = e > 0.0005
	var flames: Array = get_tree().get_nodes_in_group("exterior_look_flame") if is_inside_tree() else []
	for f in flames:
		(f as Node3D).visible = float(v.lamps) > 0.05


# ---------------------------------------------------------------- the props ---------------------------------------

## The props (set_on connects this to the next physics frame, once): each stands on the terrain where its ground ray
## lands (a prop whose ray finds no terrain is skipped), then the current light is applied to their lamps.
func _build_props() -> void:
	if not is_on() or _world.get_node_or_null(PROPS_NAME):
		return
	var props := Node3D.new()
	props.name = PROPS_NAME
	_world.add_child(props)
	_lamps.clear()
	for i in BRAZIERS.size():
		var at = _ground(BRAZIERS[i])
		if at != null:
			props.add_child(_brazier(i, at))
	for i in LAMP_POSTS.size():
		var at = _ground(LAMP_POSTS[i])
		if at != null:
			props.add_child(_lamp_post(i, at))
	var tavern := _world.get_node_or_null(TAVERN_PATH) as Node3D
	if tavern:
		for off in TAVERN_GLOWS:
			props.add_child(_glow(tavern.to_global(off), 1.2, 5.0, false))
	var village := _world.get_node_or_null(VILLAGE_PATH)
	if village:
		for b in village.get_children():
			if b.name in VILLAGE_SKIP or not b is Node3D:
				continue
			var at := (b as Node3D).global_position
			if b.has_meta("glow"):   # a kit building: its door (local point, from the layout generator)
				props.add_child(_glow((b as Node3D).to_global(b.get_meta("glow")), HOUSE_ENERGY, 4.5, false))
				continue
			var to_square := (SQUARE_CENTER - Vector2(at.x, at.z)).normalized() * 1.8
			props.add_child(_glow(at + Vector3(to_square.x, 1.3, to_square.y), HOUSE_ENERGY, 4.5, false))
	props.add_child(_leaves())
	_apply(applied)


## The terrain's surface under (x, z), by a ray down that takes only hits under GROUND_ROOT (anything else above it,
## a tent, a cart, a villager or the player, is excluded and the ray cast again), or null when there is none.
func _ground(at: Vector2) -> Variant:
	var space := _world.get_world_3d().direct_space_state if _world.is_inside_tree() else null
	var terrain := _world.get_node_or_null(GROUND_ROOT)
	if space == null or terrain == null:
		return null
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 30.0, at.y), Vector3(at.x, -30.0, at.y))
	var skip: Array[RID] = []
	for i in 8:
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		if hit.collider is Node and terrain.is_ancestor_of(hit.collider):
			return hit.position
		skip.append(hit.rid)
	push_warning("[ExteriorLook] no terrain under (%.1f, %.1f): the prop there is skipped" % [at.x, at.y])
	return null


func _light(at: Vector3, energy: float, light_range: float, color: Color, flicker: bool) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = color
	l.omni_range = light_range
	l.light_energy = 0.0
	l.shadow_enabled = false
	l.visible = false
	_lamps.append([l, energy, flicker, _lamps.size() * 2.39])   # each lamp its own flicker phase
	return l


static func _mat(color: Color, roughness := 0.85, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
		m.roughness = 0.0
	return m


static func _part(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	return mi


static func _cyl(top: float, bottom: float, height: float, sides := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = sides
	return c


## A placeholder brazier: a stone pedestal, an iron bowl of coals, three flames, a flickering light.
func _brazier(i: int, at: Vector3) -> Node3D:
	var b := Node3D.new()
	b.name = "Brazier%d" % (i + 1)
	b.position = at
	b.add_child(_part(_cyl(0.1, 0.14, 0.85), _mat(Color(0.32, 0.31, 0.3)), Vector3(0, 0.425, 0)))
	b.add_child(_part(_cyl(0.34, 0.16, 0.22), _mat(Color(0.1, 0.09, 0.085), 0.7), Vector3(0, 0.96, 0)))
	var coals := _part(_cyl(0.3, 0.3, 0.03), _mat(Color(0.9, 0.3, 0.08), 0.0, 2.0), Vector3(0, 1.07, 0))
	coals.add_to_group("exterior_look_flame")   # cold by day, like the flames
	b.add_child(coals)
	var flame_mat := _mat(Color(1.0, 0.6, 0.22), 0.0, 3.5)
	for k in 3:
		var a := TAU * k / 3.0 + i
		var f := _part(_cyl(0.0, 0.1, 0.38 - k * 0.06, 6), flame_mat, Vector3(cos(a) * 0.08, 1.27 - k * 0.03, sin(a) * 0.08))
		f.add_to_group("exterior_look_flame")
		b.add_child(f)
	b.add_child(_light(Vector3(0, 1.6, 0), BRAZIER_ENERGY, 8.5, FIRE_COLOR, true))
	return b


## A placeholder lamp post: a dark post, an arm, a lantern hanging from it, its light.
func _lamp_post(i: int, at: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = "LampPost%d" % (i + 1)
	p.position = at
	var wood := _mat(Color(0.14, 0.1, 0.07), 0.9)
	var iron := _mat(Color(0.08, 0.075, 0.07), 0.7)
	var post := BoxMesh.new()
	post.size = Vector3(0.12, 2.7, 0.12)
	p.add_child(_part(post, wood, Vector3(0, 1.35, 0)))
	var arm := BoxMesh.new()
	arm.size = Vector3(0.6, 0.06, 0.06)
	p.add_child(_part(arm, iron, Vector3(0.27, 2.62, 0)))
	var glass := BoxMesh.new()
	glass.size = Vector3(0.17, 0.24, 0.17)
	var lantern_glass := _part(glass, _mat(Color(1.0, 0.7, 0.4), 0.0, 2.4), Vector3(0.5, 2.33, 0))
	lantern_glass.add_to_group("exterior_look_flame")
	p.add_child(lantern_glass)
	p.add_child(_part(_cyl(0.03, 0.14, 0.08, 8), iron, Vector3(0.5, 2.49, 0)))
	p.add_child(_part(_cyl(0.11, 0.09, 0.04, 8), iron, Vector3(0.5, 2.19, 0)))
	p.add_child(_light(Vector3(0.5, 2.3, 0), LAMP_ENERGY, 6.0, LAMP_COLOR, false))
	return p


## A warm glow at a door or a window (a light only: the windows themselves glow in ext_building / the tavern's own).
func _glow(at: Vector3, energy: float, light_range: float, flicker: bool) -> OmniLight3D:
	var l := _light(at, energy, light_range, LAMP_COLOR, flicker)
	l.name = "Glow"
	return l


## Falling leaves over the road, the bridge and the square.
static func _leaves() -> GPUParticles3D:
	var d := GPUParticles3D.new()
	d.name = "Leaves"
	d.position = Vector3(0.0, 6.0, 8.0)
	d.amount = 140
	d.lifetime = 10.0
	d.preprocess = 10.0
	d.visibility_aabb = AABB(Vector3(-32.0, -12.0, -18.0), Vector3(64.0, 16.0, 36.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28.0, 3.0, 14.0)
	pm.direction = Vector3(1, -0.1, 0.2)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0.1, -0.06, 0.05)   # a slow drift: about 3.5 m of fall in a leaf's life, so it stays above the ground
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.78, 0.42, 0.14))
	ramp.set_color(1, Color(0.55, 0.16, 0.1))
	ramp.add_point(0.5, Color(0.72, 0.58, 0.2))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_initial_ramp = tex
	d.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.09)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	quad.material = m
	d.draw_pass_1 = quad
	return d
