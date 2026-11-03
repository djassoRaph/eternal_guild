# exterior_look.gd — the exterior's look (brainstorm 2026-11-03, BMAD _bmad-output/brainstorming-session-2026-11-03.md,
# idea #29: Raphael's Octopath shot is the OUTSIDE's reference: blue dusk, haze, warm windows, textured cobbles,
# braziers). A node ExteriorWorld adds at _ready (game_config "exterior_look", true when absent):
# - the ground in world space: ext_grass on the terrain, ext_cobble on the road and the square, ext_water on the stream;
#   the KayKit village buildings on ext_building (their own atlas, the window cell glowing by phase);
# - the light and the air per day phase (LOOKS: sun, ambient, background, depth haze, mist in the stream's valley,
#   glow, exposure, saturation, the lamps and the windows), blended over BLEND_SECONDS when the day clock
#   (GameBus.day_phase_changed) moves on; it starts at the clock's phase (GameManager.day_clock_phase()) like the hall;
# - code-made placeholder props, on the ground by raycast: braziers along the road, lamp posts round the square, a warm
#   glow at each house and at the guild tavern's door and windows, and falling leaves.
# Off (dev key 5) puts the scene's own environment, sun and materials back and frees the props. Dev key 2 steps the
# phase. Nothing is written into ExteriorWorld.tscn. Loaded by path: no class_name.
extends Node

const GRASS_SHADER := preload("res://assets/shaders/ext_grass.gdshader")
const COBBLE_SHADER := preload("res://assets/shaders/ext_cobble.gdshader")
const WATER_SHADER := preload("res://assets/shaders/ext_water.gdshader")
const BUILDING_SHADER := preload("res://assets/shaders/ext_building.gdshader")
const PHASES := ["morning", "day", "dusk", "evening", "late_night", "dawn"]
const PHASE_ALIASES := {"reveal": "late_night"}
const DEFAULT_PHASE := "day"
const BLEND_SECONDS := 4.0
const SAVED_META := &"exterior_look_saved"
const PROPS_NAME := "ExteriorLookProps"
## The terrain's meshes (a6_exterior_terrain.gltf) and the look each takes.
const TERRAIN_PATH := "Terrain/TerrainMesh"
const GROUND := {"terrain": "grass", "terrain_paths": "cobble", "terrain_water": "water"}
const VILLAGE_PATH := "Village"
const VILLAGE_SKIP := ["Street"]
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
const LAMP_POSTS := [Vector2(12.0, 2.5), Vector2(23.5, 2.5), Vector2(23.8, 13.8), Vector2(12.2, 14.0)]
const SQUARE_CENTER := Vector2(17.5, 8.0)
const TAVERN_GLOWS := [Vector3(3.9, 1.6, -1.6), Vector3(2.7, 1.8, 2.2), Vector3(-1.1, 1.8, 3.4)]
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
var _building_mat: ShaderMaterial
var _lamps: Array = []             # [light, base_energy, flicker]
var _from := {}
var _to := {}
var _blend_t := 1.0
var _clock := 0.0


func _ready() -> void:
	_world = get_parent() as Node3D
	var gb := get_node_or_null("/root/GameBus")
	if gb and gb.has_signal("day_phase_changed"):
		gb.day_phase_changed.connect(set_phase)
	phase = _start_phase()
	set_on(true)
	print("[ExteriorLook] phase %s" % phase)


func _process(delta: float) -> void:
	_clock += delta
	if is_on() and _blend_t < 1.0:
		_blend_t = minf(_blend_t + delta / BLEND_SECONDS, 1.0)
		applied = blend(_from, _to, _blend_t)
		_apply(applied)
	for l in _lamps:
		var light := l[0] as OmniLight3D
		if is_instance_valid(light) and light.visible and l[2]:
			var t := _clock * 9.0 + float(l[1]) * 7.0
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


## Every number and colour from a to b at t (0..1).
static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k in b:
		out[k] = a[k].lerp(b[k], t) if b[k] is Color and a.get(k) is Color else lerpf(float(a.get(k, b[k])), float(b[k]), t)
	return out


## The material a ground mesh takes (by the terrain mesh's name), or null.
static func ground_material(mesh_name: String) -> ShaderMaterial:
	var kind: String = GROUND.get(mesh_name, "")
	if kind == "":
		return null
	var m := ShaderMaterial.new()
	m.shader = {"grass": GRASS_SHADER, "cobble": COBBLE_SHADER, "water": WATER_SHADER}[kind]
	return m


## Put the ground and building materials on (or back off) the exterior under `world`; returns {ground, buildings}.
## The buildings share one material (`building_mat`, made from the first building's atlas when null).
static func apply_materials(world: Node, on: bool, building_mat: ShaderMaterial = null) -> Dictionary:
	var out := {"ground": 0, "buildings": 0, "building_mat": building_mat}
	var terrain := world.get_node_or_null(TERRAIN_PATH)
	if terrain:
		for mi in terrain.find_children("*", "MeshInstance3D", true, false):
			var m: ShaderMaterial = ground_material(mi.name) if on else null
			if on and m == null:
				continue
			if _set_material(mi, m, on):
				out.ground += 1
	var village := world.get_node_or_null(VILLAGE_PATH)
	if village:
		for b in village.get_children():
			if b.name in VILLAGE_SKIP:
				continue
			var meshes: Array = b.find_children("*", "MeshInstance3D", true, false)
			if b is MeshInstance3D:
				meshes.append(b)
			for mi in meshes:
				if on and out.building_mat == null:
					var src := (mi as MeshInstance3D).get_active_material(0) as BaseMaterial3D
					if src == null or src.albedo_texture == null:
						continue
					out.building_mat = ShaderMaterial.new()
					out.building_mat.shader = BUILDING_SHADER
					out.building_mat.set_shader_parameter("atlas", src.albedo_texture)
				if _set_material(mi, out.building_mat if on else null, on):
					out.buildings += 1
	return out


## On: keep the mesh's own override (once) and put `mat` on. Off: put the kept one back. True when it changed.
static func _set_material(mi: MeshInstance3D, mat: Material, on: bool) -> bool:
	if on:
		if not mi.has_meta(SAVED_META):
			mi.set_meta(SAVED_META, mi.material_override)
		mi.material_override = mat
		return true
	if mi.has_meta(SAVED_META):
		mi.material_override = mi.get_meta(SAVED_META)
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
	var mats := apply_materials(_world, on, _building_mat)
	_building_mat = mats.building_mat if on else _building_mat
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
		_build_props()
		_blend_t = 1.0
		applied = look_values(phase)
		_apply(applied)
	else:
		if _we and _orig_env:
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
	if seconds == 0.0:
		_blend_t = 1.0
		applied = _to
		_apply(applied)
	else:
		_blend_t = 0.0


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
	if _building_mat:
		_building_mat.set_shader_parameter("window_glow", float(v.windows))
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

## The props go on after a physics frame (the terrain's collider answers the ground rays from then on), then the
## current light is applied to their lamps.
func _build_props() -> void:
	if is_inside_tree():
		await get_tree().physics_frame
	if not is_on() or _world.get_node_or_null(PROPS_NAME):
		return
	var props := Node3D.new()
	props.name = PROPS_NAME
	_world.add_child(props)
	_lamps.clear()
	for i in BRAZIERS.size():
		props.add_child(_brazier(i, _ground(BRAZIERS[i])))
	for i in LAMP_POSTS.size():
		props.add_child(_lamp_post(i, _ground(LAMP_POSTS[i])))
	var tavern := _world.get_node_or_null("GuildTavern") as Node3D
	if tavern:
		for off in TAVERN_GLOWS:
			props.add_child(_glow(tavern.global_position + off, 1.2, 5.0, false))
	var village := _world.get_node_or_null(VILLAGE_PATH)
	if village:
		for b in village.get_children():
			if b.name in VILLAGE_SKIP or b.name == "Well" or not b is Node3D:
				continue
			var at := (b as Node3D).global_position
			var to_square := (SQUARE_CENTER - Vector2(at.x, at.z)).normalized() * 1.8
			props.add_child(_glow(at + Vector3(to_square.x, 1.3, to_square.y), HOUSE_ENERGY, 4.5, false))
	props.add_child(_leaves())
	_apply(applied)


## The ground's height under (x, z) by a ray down (the terrain's collider), else 0.
func _ground(at: Vector2) -> Vector3:
	var space := _world.get_world_3d().direct_space_state if _world.is_inside_tree() else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 30.0, at.y), Vector3(at.x, -30.0, at.y))
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			return hit.position
	return Vector3(at.x, 0.0, at.y)


func _light(at: Vector3, energy: float, light_range: float, color: Color, flicker: bool) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = color
	l.omni_range = light_range
	l.light_energy = 0.0
	l.shadow_enabled = false
	l.visible = false
	_lamps.append([l, energy, flicker])
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
	b.add_child(_part(_cyl(0.3, 0.3, 0.03), _mat(Color(0.9, 0.3, 0.08), 0.0, 2.0), Vector3(0, 1.07, 0)))
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
	d.lifetime = 12.0
	d.preprocess = 12.0
	d.visibility_aabb = AABB(Vector3(-32.0, -12.0, -18.0), Vector3(64.0, 16.0, 36.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28.0, 3.0, 14.0)
	pm.direction = Vector3(1, -0.4, 0.2)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0.1, -0.35, 0.05)
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
