# hall_dressing.gd — the hall look, pass 2: set dressing (brainstorm 2026-11-03, BMAD
# _bmad-output/brainstorming-session-2026-11-03.md). Code-made placeholders, built by hall_look.gd under its props
# node (so key 5 and "hall_look": false take them away too), swappable for real models later:
# the memorial wall (#21: helmets on a shelf with brass name plates, a shield with a crossed sword and axe, a memorial
# candle), a horned beast skull over the hearth (#24), a ring of hanging tankards over the back bar (#27), a living bar
# top (#33: candles, plants, the brass service bell), old notices round the guild board (#23), past guildmasters'
# portraits with the last frame left empty (#26), roots wrapping the hourglass pillar with runes glowing in them (#30,
# #11), and a little dust in the light (#10). Candle lights join tavern_candle hidden with a base_energy, like the
# lanterns, so the mood lights them. Positions are MainTavern's, measured 2026-11-03. Loaded by path: no class_name.
extends RefCounted

const PAPER_SHADER := preload("res://assets/shaders/hall_paper.gdshader")
const PORTRAIT_SHADER := preload("res://assets/shaders/hall_portrait.gdshader")
const ROOT_SHADER := preload("res://assets/shaders/hall_root.gdshader")
const TANKARD := preload("res://assets/environment/custom/h1_tankard_empty.gltf")

const BAR_CENTER := Vector3(7.74015, 0.0, -8.21504)
const COUNTER_TOP := 1.215          # the round bar's counter, between radius 2.2 and 3.0
const PARTITION_Z := -14.483        # the partition's hall face
const WEST_WALL_X := -4.82          # the west wall's inside face
const CHIMNEY_X := -4.21            # the chimney breast's face above 3 m
const HEARTH_Z := -8.96
## The memorial: a shelf centred here on the partition, between the two banners.
const MEMORIAL_X := 11.0
## The bar top (angle in degrees round the bar centre, atan2(z, x); the staff opening is at -90): candles, plants, bell.
const BAR_CANDLES := [-30.0, 160.0, -150.0]
const BAR_PLANTS := [15.0, -125.0]
const BAR_BELL := 55.0
const TANKARD_RING_R := 1.83
const TANKARD_RING_Y := 2.5
const TANKARD_COUNT := 12
## Old notices round the board (x, y, tilt in degrees, width, height) on the wall behind its edges.
const NOTICES := [
	[2.42, 2.95, 8.0, 0.3, 0.38], [2.38, 1.85, -6.0, 0.28, 0.34], [6.18, 2.7, -9.0, 0.3, 0.38],
	[6.22, 1.7, 5.0, 0.26, 0.32], [3.15, 3.5, 4.0, 0.32, 0.26], [5.3, 3.48, -5.0, 0.3, 0.28],
]
## Portraits on the west wall (z of each frame centre); the last frame is empty.
const PORTRAITS := [-3.45, -2.75, -2.05, -1.35]
const PORTRAIT_Y := 2.75
const PORTRAIT_SIZE := Vector2(0.52, 0.64)
const PORTRAIT_LOOKS := [
	{"coat": Color(0.22, 0.17, 0.14), "hair": Color(0.55, 0.52, 0.48), "skin": Color(0.72, 0.56, 0.43)},
	{"coat": Color(0.16, 0.2, 0.17), "hair": Color(0.18, 0.12, 0.08), "skin": Color(0.62, 0.46, 0.34)},
	{"coat": Color(0.3, 0.14, 0.12), "hair": Color(0.42, 0.24, 0.12), "skin": Color(0.74, 0.6, 0.48)},
]
## Where each root starts round the pillar (degrees, atan2(z, x)): two down its left side, two down its right.
const ROOT_ANGLES := [115.0, 145.0, 265.0, 290.0]
const CANDLE_ENERGY := 0.45
const FLAME_GROUP := "tavern_candle_flame"   # hall_look.gd's: the lit flames TavernLighting shows with the candles
const CANDLE_COLOR := Color(1.0, 0.7, 0.4)

static var _mats := {}


## Build the dressing under `props`; returns how many of each it made.
static func build(props: Node3D) -> Dictionary:
	props.add_child(_memorial())
	props.add_child(_trophy())
	var ring := _tankard_ring()
	props.add_child(ring)
	var top := _bar_top()
	props.add_child(top)
	for i in NOTICES.size():
		props.add_child(_notice(i, NOTICES[i]))
	for i in PORTRAITS.size():
		props.add_child(_portrait(i, PORTRAITS[i], i < PORTRAITS.size() - 1))
	for k in ROOT_ANGLES.size():
		props.add_child(_root(k))
	props.add_child(_dust())
	# counted from what was built, not from the loops' bounds
	var count := func(parent: Node, pattern: String) -> int: return parent.find_children(pattern, "", false, false).size()
	return {"memorial": count.call(props, "MemorialWall"), "trophy": count.call(props, "BeastTrophy"),
		"tankards": count.call(ring, "Tankard*"), "bar_top": top.get_child_count(), "notices": count.call(props, "OldNotice*"),
		"portraits": count.call(props, "Portrait*"), "roots": count.call(props, "Root*"), "dust": count.call(props, "Dust")}


# ---------------------------------------------------------------- materials and parts ----------------------------

static func _mat(key: String, color: Color, metallic := 0.0, roughness := 0.85, cull_off := false) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = metallic
		m.roughness = roughness
		if cull_off:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


static func _wood() -> StandardMaterial3D:
	return _mat("wood", Color(0.16, 0.11, 0.075), 0.0, 0.9)


static func _iron() -> StandardMaterial3D:
	return _mat("iron", Color(0.09, 0.085, 0.08), 0.6, 0.7)


static func _steel() -> StandardMaterial3D:
	return _mat("steel", Color(0.56, 0.56, 0.54), 0.75, 0.45)


static func _brass() -> StandardMaterial3D:
	return _mat("brass", Color(0.72, 0.55, 0.27), 0.8, 0.35)


static func _bone() -> StandardMaterial3D:
	return _mat("bone", Color(0.76, 0.7, 0.58), 0.0, 0.8)


static func _part(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	return mi


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _cyl(top: float, bottom: float, height: float, sides := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = sides
	return c


static func _sphere(r: float, segments := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segments
	s.rings = segments / 2
	return s


## A candle with its flame and its light (hidden, tavern_candle, base_energy).
static func _candle(pos: Vector3, energy := CANDLE_ENERGY, light_range := 2.0) -> Node3D:
	var c := Node3D.new()
	c.name = "Candle"
	c.position = pos
	c.add_child(_part(_cyl(0.045, 0.05, 0.014), _brass(), Vector3(0, 0.007, 0)))
	c.add_child(_part(_cyl(0.026, 0.028, 0.13, 8), _mat("wax", Color(0.86, 0.8, 0.66), 0.0, 0.7), Vector3(0, 0.08, 0)))
	var flame := _mat("flame", Color(1.0, 0.8, 0.5))
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.62, 0.28)
	flame.emission_energy_multiplier = 3.0
	flame.roughness = 0.0        # no ink on the flame
	var flame_mesh := _part(_sphere(0.016, 8), flame, Vector3(0, 0.165, 0), Vector3.ZERO, Vector3(1, 1.8, 1))
	flame_mesh.add_to_group(FLAME_GROUP)   # shown only while the mood lights the candles (TavernLighting)
	c.add_child(flame_mesh)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0, 0.2, 0)
	light.light_color = CANDLE_COLOR
	light.omni_range = light_range
	light.light_energy = energy
	light.set_meta("base_energy", energy)
	light.shadow_enabled = false
	light.visible = false
	light.add_to_group("tavern_candle")
	c.add_child(light)
	return c


## A tapered tube along a smooth path (Catmull-Rom through `points`), radius r0 -> r1; UV.x runs along it.
static func _tube(points: Array, r0: float, r1: float, sides := 8, steps_per_seg := 6) -> ArrayMesh:
	var path: Array = []
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var pre: Vector3 = points[maxi(i - 1, 0)]
		var post: Vector3 = points[mini(i + 2, points.size() - 1)]
		for s in steps_per_seg:
			path.append(a.cubic_interpolate(b, pre, post, float(s) / steps_per_seg))
	path.append(points[-1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := path.size()
	for i in n:
		var p: Vector3 = path[i]
		var t: Vector3 = (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var side := t.cross(Vector3.UP)
		if side.length() < 0.01:
			side = t.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(t).normalized()
		var r := lerpf(r0, r1, float(i) / (n - 1))
		for k in sides + 1:
			var a := TAU * k / sides
			var d := side * cos(a) + up * sin(a)
			st.set_normal(d)
			st.set_uv(Vector2(float(i) / (n - 1), float(k) / sides))
			st.add_vertex(p + d * r)
	for i in n - 1:
		for k in sides:
			var a := i * (sides + 1) + k
			var b := a + sides + 1
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(b + 1)
			st.add_index(b)
	return st.commit()


static func _path_length(points: Array) -> float:
	var l := 0.0
	for i in points.size() - 1:
		l += (points[i + 1] as Vector3).distance_to(points[i])
	return l


static func _round(deg: float, r: float, y: float) -> Vector3:
	var a := deg_to_rad(deg)
	return BAR_CENTER + Vector3(cos(a) * r, y, sin(a) * r)


# ---------------------------------------------------------------- the pieces --------------------------------------

## The memorial wall on the partition: a shelf of fallen adventurers' helmets with brass name plates, a shield with a
## crossed sword and axe above, and a memorial candle.
static func _memorial() -> Node3D:
	var m := Node3D.new()
	m.name = "MemorialWall"
	var z := PARTITION_Z
	var shelf_y := 1.95
	m.add_child(_part(_box(Vector3(2.0, 0.05, 0.22)), _wood(), Vector3(MEMORIAL_X, shelf_y, z + 0.11)))
	for dx in [-0.8, 0.8]:
		m.add_child(_part(_box(Vector3(0.04, 0.16, 0.18)), _iron(), Vector3(MEMORIAL_X + dx, shelf_y - 0.1, z + 0.09)))
	var top := shelf_y + 0.025
	for i in 3:
		var x: float = MEMORIAL_X - 0.6 + i * 0.6
		var h := Node3D.new()
		h.name = "Helmet%d" % (i + 1)
		h.position = Vector3(x, top, z + 0.11)
		match i:
			0:   # a conical helm with a nose guard
				h.add_child(_part(_cyl(0.03, 0.13, 0.17), _steel(), Vector3(0, 0.1, 0)))
				h.add_child(_part(_cyl(0.135, 0.135, 0.025), _iron(), Vector3(0, 0.0125, 0)))
				h.add_child(_part(_box(Vector3(0.03, 0.11, 0.015)), _iron(), Vector3(0, 0.0, 0.13)))
			1:   # a round helm, dented
				h.add_child(_part(_sphere(0.13), _steel(), Vector3(0, 0.06, 0), Vector3(0.15, 0, 0.1), Vector3(1, 0.85, 1)))
				h.add_child(_part(_cyl(0.135, 0.135, 0.05), _iron(), Vector3(0, 0.025, 0)))
			2:   # a horned helm
				h.add_child(_part(_sphere(0.12), _steel(), Vector3(0, 0.06, 0), Vector3.ZERO, Vector3(1, 0.85, 1)))
				h.add_child(_part(_cyl(0.125, 0.125, 0.05), _iron(), Vector3(0, 0.025, 0)))
				for s in [-1.0, 1.0]:
					h.add_child(_part(_cyl(0.0, 0.028, 0.15, 8), _bone(), Vector3(s * 0.13, 0.15, 0), Vector3(0, 0, -s * 0.7)))
		m.add_child(h)
		m.add_child(_part(_box(Vector3(0.2, 0.045, 0.008)), _brass(), Vector3(x, shelf_y - 0.005, z + 0.224)))
	# the shield, and a crossed sword and axe over it
	var shield_c := Vector3(MEMORIAL_X, 2.78, z + 0.03)
	m.add_child(_part(_cyl(0.34, 0.34, 0.035, 20), _mat("shield", Color(0.3, 0.17, 0.15), 0.0, 0.85), shield_c, Vector3(PI * 0.5, 0, 0)))
	m.add_child(_part(_cyl(0.345, 0.345, 0.02, 20), _iron(), shield_c + Vector3(0, 0, -0.01), Vector3(PI * 0.5, 0, 0)))
	m.add_child(_part(_sphere(0.07), _iron(), shield_c + Vector3(0, 0, 0.03), Vector3.ZERO, Vector3(1, 1, 0.6)))
	var sword := Node3D.new()
	sword.name = "Sword"
	sword.position = shield_c + Vector3(0, 0, 0.07)
	sword.rotation = Vector3(0, 0, deg_to_rad(38))
	sword.add_child(_part(_box(Vector3(0.05, 0.84, 0.012)), _steel(), Vector3(0, 0.1, 0)))
	sword.add_child(_part(_box(Vector3(0.22, 0.03, 0.035)), _iron(), Vector3(0, -0.33, 0)))
	sword.add_child(_part(_cyl(0.018, 0.018, 0.16, 6), _wood(), Vector3(0, -0.43, 0)))
	sword.add_child(_part(_sphere(0.03, 8), _brass(), Vector3(0, -0.52, 0)))
	m.add_child(sword)
	var axe := Node3D.new()
	axe.name = "Axe"
	axe.position = shield_c + Vector3(0, 0, 0.09)
	axe.rotation = Vector3(0, 0, deg_to_rad(-38))
	axe.add_child(_part(_cyl(0.02, 0.02, 0.82, 6), _wood(), Vector3.ZERO))
	axe.add_child(_part(_box(Vector3(0.2, 0.15, 0.02)), _steel(), Vector3(0.09, 0.3, 0)))
	m.add_child(axe)
	m.add_child(_candle(Vector3(MEMORIAL_X + 0.92, top, z + 0.12), 0.8, 2.6))
	return m


## A horned beast skull on a board over the hearth (on the chimney breast, facing the hall).
static func _trophy() -> Node3D:
	var t := Node3D.new()
	t.name = "BeastTrophy"
	var s := Vector3(CHIMNEY_X + 0.16, 3.38, HEARTH_Z)
	t.add_child(_part(_box(Vector3(0.04, 0.46, 0.36)), _wood(), Vector3(CHIMNEY_X + 0.02, 3.35, HEARTH_Z)))
	t.add_child(_part(_sphere(0.13), _bone(), s, Vector3.ZERO, Vector3(1.2, 0.9, 1.0)))
	t.add_child(_part(_box(Vector3(0.26, 0.1, 0.12)), _bone(), s + Vector3(0.18, -0.07, 0)))
	var socket := _mat("socket", Color(0.05, 0.04, 0.03), 0.0, 0.9)
	for side in [-1.0, 1.0]:
		t.add_child(_part(_sphere(0.028, 8), socket, s + Vector3(0.09, 0.05, side * 0.065)))
		var horn := [s + Vector3(0.0, 0.08, side * 0.1), s + Vector3(0.02, 0.2, side * 0.28), s + Vector3(0.1, 0.32, side * 0.42),
			s + Vector3(0.22, 0.34, side * 0.5), s + Vector3(0.32, 0.28, side * 0.52)]
		var hm := MeshInstance3D.new()
		hm.mesh = _tube(horn, 0.05, 0.007, 8, 5)
		hm.material_override = _mat("horn", Color(0.42, 0.36, 0.28), 0.0, 0.7, true)
		t.add_child(hm)
	return t


## A ring of hanging tankards over the back bar, on chains from the dark above.
static func _tankard_ring() -> Node3D:
	var r := Node3D.new()
	r.name = "TankardRing"
	r.position = Vector3(BAR_CENTER.x, TANKARD_RING_Y, BAR_CENTER.z)
	var torus := TorusMesh.new()
	torus.inner_radius = TANKARD_RING_R - 0.025
	torus.outer_radius = TANKARD_RING_R + 0.025
	torus.rings = 48
	torus.ring_segments = 6
	r.add_child(_part(torus, _iron(), Vector3.ZERO))
	for deg in [30.0, 150.0, 270.0]:
		var a := deg_to_rad(deg)
		var chain_h := 4.0 - TANKARD_RING_Y
		r.add_child(_part(_cyl(0.01, 0.01, chain_h, 6), _iron(), Vector3(cos(a) * TANKARD_RING_R, chain_h * 0.5, sin(a) * TANKARD_RING_R)))
	for i in TANKARD_COUNT:
		var a := TAU * i / TANKARD_COUNT
		var at := Vector3(cos(a) * TANKARD_RING_R, 0.0, sin(a) * TANKARD_RING_R)
		r.add_child(_part(_cyl(0.006, 0.006, 0.08, 4), _iron(), at + Vector3(0, -0.04, 0)))
		var mug: Node3D = TANKARD.instantiate()
		mug.name = "Tankard%d" % (i + 1)
		mug.scale = Vector3.ONE * 1.5
		mug.position = at + Vector3(0, -0.08 - 0.077 * 1.5, 0)
		mug.rotation = Vector3(0, -a, 0)
		r.add_child(mug)
	return r


## The counter's dressing: candles (lit by the mood), potted plants and the brass service bell.
static func _bar_top() -> Node3D:
	var top := Node3D.new()
	top.name = "BarTop"
	for deg in BAR_CANDLES:
		top.add_child(_candle(_round(deg, 2.75, COUNTER_TOP)))
	for i in BAR_PLANTS.size():
		var p := Node3D.new()
		p.name = "Plant%d" % (i + 1)
		p.position = _round(BAR_PLANTS[i], 2.8, COUNTER_TOP)
		p.add_child(_part(_cyl(0.07, 0.05, 0.1), _mat("pot", Color(0.5, 0.28, 0.18), 0.0, 0.9), Vector3(0, 0.05, 0)))
		var leaf := _mat("leaf", Color(0.24, 0.36, 0.17), 0.0, 0.8)
		for k in 5:
			var a := TAU * k / 5 + i
			p.add_child(_part(_sphere(0.055, 8), leaf, Vector3(cos(a) * 0.05, 0.14 + (k % 2) * 0.04, sin(a) * 0.05), Vector3.ZERO, Vector3(1, 0.6, 1)))
		top.add_child(p)
	var bell := Node3D.new()
	bell.name = "ServiceBell"
	bell.position = _round(BAR_BELL, 2.85, COUNTER_TOP)
	bell.add_child(_part(_cyl(0.06, 0.065, 0.012), _wood(), Vector3(0, 0.006, 0)))
	bell.add_child(_part(_cyl(0.015, 0.05, 0.06), _brass(), Vector3(0, 0.042, 0)))
	bell.add_child(_part(_sphere(0.012, 8), _brass(), Vector3(0, 0.08, 0)))
	top.add_child(bell)
	return top


## An old notice pinned to the wall behind the guild board's edge.
static func _notice(i: int, spec: Array) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(spec[3], spec[4])
	var mat := ShaderMaterial.new()
	mat.shader = PAPER_SHADER
	mat.set_shader_parameter("seed", float(i) * 1.37 + 0.5)
	mat.set_shader_parameter("age", 0.5 + 0.08 * i)
	var mi := _part(quad, mat, Vector3(spec[0], spec[1], PARTITION_Z + 0.012), Vector3(0, 0, deg_to_rad(spec[2])))
	mi.name = "OldNotice%d" % (i + 1)
	return mi


## A gilt frame on the west wall, with a past guildmaster's portrait in it (or empty: the place left for you).
static func _portrait(i: int, z: float, filled: bool) -> Node3D:
	var p := Node3D.new()
	p.name = "Portrait%d" % (i + 1) if filled else "PortraitEmpty"
	p.position = Vector3(WEST_WALL_X + 0.02, PORTRAIT_Y, z)
	var gilt := _mat("gilt", Color(0.42, 0.32, 0.14), 0.5, 0.45)
	var w := PORTRAIT_SIZE.x
	var h := PORTRAIT_SIZE.y
	for s in [-1.0, 1.0]:
		p.add_child(_part(_box(Vector3(0.035, 0.06, w)), gilt, Vector3(0.0, s * (h - 0.06) * 0.5, 0)))
		p.add_child(_part(_box(Vector3(0.035, h, 0.06)), gilt, Vector3(0.0, 0, s * (w - 0.06) * 0.5)))
	p.add_child(_part(_box(Vector3(0.008, 0.04, 0.18)), _brass(), Vector3(0.0, -h * 0.5 - 0.06, 0)))
	if filled:
		var look: Dictionary = PORTRAIT_LOOKS[i % PORTRAIT_LOOKS.size()]
		var quad := QuadMesh.new()
		quad.size = Vector2(w - 0.1, h - 0.1)
		var mat := ShaderMaterial.new()
		mat.shader = PORTRAIT_SHADER
		mat.set_shader_parameter("coat", look.coat)
		mat.set_shader_parameter("hair", look.hair)
		mat.set_shader_parameter("skin", look.skin)
		mat.set_shader_parameter("seed", float(i) + 0.3)
		p.add_child(_part(quad, mat, Vector3(0.005, 0, 0), Vector3(0, PI * 0.5, 0)))
	return p


## A root that comes out from under the pillar's crown and creeps down the pillar into the back bar. The roots keep to
## the pillar's sides and back (ROOT_ANGLES): the camera looks from about +45 degrees, and a root crossing the glass's
## front hides the hall's centrepiece.
static func _root(k: int) -> MeshInstance3D:
	var a0: float = ROOT_ANGLES[k]
	var spec := [[a0, 1.0, 4.2], [a0 + 5.0, 0.98, 3.75], [a0 + 10.0, 0.8, 3.2], [a0 + 14.0, 0.8, 2.6],
		[a0 + 18.0, 0.8, 2.05], [a0 + 22.0, 0.76, 1.6], [a0 + 25.0, 0.74, 1.3]]
	var pts := spec.map(func(s): return _round(s[0], s[1], s[2]))
	var mi := MeshInstance3D.new()
	mi.name = "Root%d" % (k + 1)
	mi.mesh = _tube(pts, 0.1, 0.045, 9, 6)
	var mat := ShaderMaterial.new()
	mat.shader = ROOT_SHADER
	mat.set_shader_parameter("root_length", _path_length(pts))
	mat.set_shader_parameter("seed", float(k) * 3.1 + 1.0)
	mi.material_override = mat
	return mi


## A little dust in the air: tiny lit motes that only show where the light is (Raphael: "not too much").
static func _dust() -> GPUParticles3D:
	var d := GPUParticles3D.new()
	d.name = "Dust"
	d.position = Vector3(5.0, 2.0, -5.0)
	d.amount = 220
	d.lifetime = 14.0
	d.preprocess = 14.0
	d.visibility_aabb = AABB(Vector3(-10.5, -2.0, -10.5), Vector3(21.0, 4.0, 21.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9.5, 1.6, 9.5)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.01
	pm.initial_velocity_max = 0.05
	pm.gravity = Vector3(0, 0.002, 0)
	d.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.022, 0.022)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.92, 0.8, 0.5)
	m.render_priority = 1        # drawn after the edge pass quad, which repaints the opaque image
	quad.material = m
	d.draw_pass_1 = quad
	return d
