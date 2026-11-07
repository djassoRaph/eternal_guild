# map_table.gd
# Prototype (Raphael 2026-11-07, his sketch): the world map on a scroll on a table. The scroll unrolls on the existing
# table (assets/environment/furniture/table.glb), the real HexMapTest reveal (spin, flip, settle) plays in a window
# cut into the scroll, then the map slides UNDER the scroll: drag it (left or middle button), or WASD / arrows; the
# mouse wheel leans the camera in and out. Hover names the hex (a 2D label and a 2D hex outline: UI feedback stays
# 2D, never a 3D glow); a click opens a small 2D panel with more about it. R rolls a new world. With World Gen v2 on
# (scripts/world/world_gen_v2.gd, the default here) the world has a type, ranges, rivers and invented names: its
# name is shown over the table, hover and click name rivers, lakes, forests, ranges and lands, T cycles world types.
#
# How the window works: the map lives in its own World3D inside a SubViewport, drawn by a camera that copies the table
# camera's pose, offset by the pan. A quad on the scroll (assets/shaders/map_window.gdshader) shows that render at
# SCREEN_UV, so the map has the table's perspective but only shows through the window, framed by the paper. Picking
# is hex math on the window plane (no Area3D per hex), the way a 100,000-hex map would have to do it.
#
# Standalone dev scene (run it with F6): it writes nothing to WorldManager or any save, and the map is never handed
# on. SaveSystem's autosave can't fire here: can_autosave() needs a live run and a scene root in the player_scene
# group, and this root is in neither (so PlayerManager stands down too). Placeholder art: the scroll and frame are
# plain shapes; the root is assumed to sit at the origin.
extends Node3D

## World Gen v2 (scripts/world/world_gen_v2.gd: world types, ranges, climate, rivers, names); off = the game's
## HexMapGenerator island.
@export var use_world_gen_v2: bool = true
## v2: the world's size in hexes (100 x 64 = 6,400) and its type ("random" rolls one; T cycles them).
@export var world_width: int = 100
@export var world_height: int = 64
@export_enum("random", "continent", "archipelago", "twin", "inland_sea") var world_type: String = "random"
## The old generator's size: HexMapGenerator's map_radius (40 = 4,921 hexes; the game uses 20).
@export var map_radius: int = 40
## 0 = a new world every run; any other number = that seed.
@export var map_seed: int = 0
## World units a second the map slides with the keys at full view (half that leaning all the way in).
@export var key_pan_speed: float = 70.0

const TABLE_SCENE := "res://assets/environment/furniture/table.glb"
const HEX_MAP_SCENE := "res://scenes/HexMapTest.tscn"
const EDGE_SHADER := "res://assets/shaders/edge_detection.gdshader"
const WINDOW_SHADER := "res://assets/shaders/map_window.gdshader"
const WORLD_MANAGER := "res://systems/WorldManager.gd"   # is_mission_eligible(), static
const WORLD_GEN_V2 := "res://scripts/world/world_gen_v2.gd"
const WORLD_KINDS := ["continent", "archipelago", "twin", "inland_sea"]
const KIND_NAMES := {"continent": "a continent", "archipelago": "an archipelago", "twin": "twin continents",
	"inland_sea": "lands round an inland sea"}

const TABLE_SCALE := 70.0            # table.glb is 1 x 0.657 x 2 m; a hex is 2 units across
const TABLE_HEIGHT := 0.656775       # table.glb's top, measured
const PAPER_THICK := 0.3
const SCROLL_W := 124.0
const SCROLL_D := 64.0
const ROLL_R := 2.4
const MARGIN := 2.5                  # parchment between the window and the rollers / the paper's edge
const FRAME_W := 0.9
const FRAME_H := 0.35
const WIN_W := SCROLL_W - 2.0 * (ROLL_R + MARGIN)
const WIN_D := SCROLL_D - 2.0 * MARGIN

const PAPER := Color(0.87, 0.80, 0.63)
const WOOD_DARK := Color(0.30, 0.19, 0.11)
const FRAME_INK := Color(0.24, 0.16, 0.10)
const BACKGROUND := Color(0.07, 0.055, 0.045)
const FLOOR := Color(0.16, 0.11, 0.08)
const SEA := Color(0.15, 0.29, 0.34)          # near the hex water's average, as rendered
const SEA_SLACK := 4.0                         # open sea the window may show past the map's edge
const OUTLINE := Color(1.0, 0.85, 0.45, 0.95)
const GOLD := Color(0.95, 0.88, 0.62)

const CAM_FOV := 38.0
const CAM_DIR := Vector3(-0.42, 1.05, 1.0)   # from the table toward the camera: front-left, above
const CAM_DIST := 205.0
const CAM_TARGET_Z := 4.0
const LEAN_MIN := 0.42                       # the wheel leans the camera between these (fractions of CAM_DIST)
const LEAN_MAX := 1.0
const LEAN_STEP := 0.07

const HEX_R := 1.1547      # a hex's corner radius (pointy-top, 2 units across the flats)
const CLICK_SLOP := 6.0    # pixels a press may move and still count as a click
const BIOME_NAMES := {"sea": "Sea", "coast": "Coast", "grass": "Grassland", "forest": "Forest", "hills": "Hills",
	"mountain": "Mountains", "tavern_site": "Your tavern"}
const HINT := "Drag or WASD / arrows: slide the map   ·   Wheel: lean in / out   ·   Click a hex: details   ·   R: new world   ·   T: next world type"

var _paper_y := 0.0        # the window plane (the paper's top); the map's tile tops (its y = 0) sit on it
var _cam: Camera3D
var _sv: SubViewport
var _map_cam: Camera3D
var _map: Node3D = null
var _by_coord := {}        # Vector2i -> the map's record
var _home := Vector2i.ZERO
var _lo := Vector2.ZERO    # the map's extent (hex centres, x / z)
var _hi := Vector2.ZERO
var _pan := Vector2.ZERO   # where the map sits under the window (x / z); the point under the window's centre is -_pan
var _lean := LEAN_MAX
var _lean_target := LEAN_MAX
var _live := false         # the reveal is done: input on

var _paper_pivot: Node3D
var _right_roll: Node3D
var _window: MeshInstance3D
var _frame: Node3D

var _ui: CanvasLayer
var _outline: Control
var _hover_panel: PanelContainer
var _hover_label: Label
var _hint: Label
var _title: Label
var _subtitle: Label
var _detail: Control = null
var _hover_rec: Dictionary = {}

var _mouse := Vector2(-1.0, -1.0)   # the last mouse position any mouse event carried
var _dragging := false
var _drag_moved := 0.0
var _drag_last := Vector3.ZERO
var _wm_script = null


func _ready() -> void:
	_wm_script = load(WORLD_MANAGER)
	_paper_y = TABLE_HEIGHT * TABLE_SCALE + PAPER_THICK
	_build_map_view()
	_build_table()
	_build_ui()
	_update_cameras()
	get_viewport().size_changed.connect(_fit_map_view)
	_hint.text = "Unrolling the map…"
	await get_tree().create_timer(0.6).timeout
	await _unroll(2.0)
	_window.visible = true
	_frame.visible = true
	_spawn_map()


func _process(delta: float) -> void:
	_lean = lerpf(_lean, _lean_target, 1.0 - exp(-delta * 10.0))
	if _live:
		_key_pan(delta)
	_update_cameras()
	_update_hover()


# ── The map ───────────────────────────────────────────────────────────────────

## The real HexMapTest, inside the map view: its own camera, light and buttons are dropped (the table's camera and the
## map camera take over); _ready() then runs generate_and_reveal(). R calls this again for a new world.
func _spawn_map() -> void:
	_live = false
	_close_detail()
	_hover_rec = {}
	if _map != null:
		_map.queue_free()
		_map = null
	var map = (load(HEX_MAP_SCENE) as PackedScene).instantiate()   # HexMapGenerator.gd: its fields are set by name
	for child_name in ["CanvasLayer", "Camera3D", "DirectionalLight3D"]:
		var n: Node = map.get_node_or_null(child_name)
		if n:
			map.remove_child(n)
			n.free()
	if use_world_gen_v2:
		map.set_script(load(WORLD_GEN_V2))   # extends HexMapGenerator: same reveal and tiles, a new world
		map.set("world_width", world_width)
		map.set("world_height", world_height)
		map.set("world_type", world_type)
	else:
		map.set("map_radius", map_radius)
	map.set("randomize_seed_on_generate", map_seed == 0)
	if map_seed != 0:
		map.set("map_seed", map_seed)
	map.connect("reveal_finished", _on_reveal_finished)
	_sv.add_child(map)   # _ready(): the world is generated here, then revealed
	_map = map
	_index(map.call("get_records"))
	var home := HexGrid.offset_to_world(_home.x, _home.y)
	_set_pan(Vector2(-home.x, -home.z))   # the tavern under the window's centre
	_show_title()
	_hint.text = "Inking the map…"


## The world's name over the table (v2 names it; the old generator doesn't).
func _show_title() -> void:
	var wn := str(_map.get("world_name")) if use_world_gen_v2 and _map.get("world_name") != null else ""
	_title.text = wn
	_title.visible = wn != ""
	var kind := str(_map.get("world_kind")) if use_world_gen_v2 and _map.get("world_kind") != null else ""
	_subtitle.text = "%s · seed %d" % [KIND_NAMES.get(kind, "an island"), int(_map.get("map_seed"))]


func _on_reveal_finished() -> void:
	_live = true
	_hint.text = HINT


func _index(records: Array) -> void:
	_by_coord.clear()
	_lo = Vector2(INF, INF)
	_hi = Vector2(-INF, -INF)
	for rec in records:
		var c: Vector2i = rec.coord
		_by_coord[c] = rec
		if rec.get("is_center", false):
			_home = c
		var w := HexGrid.offset_to_world(c.x, c.y)
		_lo = Vector2(minf(_lo.x, w.x), minf(_lo.y, w.z))
		_hi = Vector2(maxf(_hi.x, w.x), maxf(_hi.y, w.z))


## Keeps the window over the map: at most SEA_SLACK of open sea shows past the map's edge.
func _set_pan(p: Vector2) -> void:
	if _by_coord.is_empty():
		_pan = p
		return
	_pan = Vector2(-_clamp_centre(-p.x, _lo.x - 1.0, _hi.x + 1.0, WIN_W * 0.5),
		-_clamp_centre(-p.y, _lo.y - HEX_R, _hi.y + HEX_R, WIN_D * 0.5))


## Where the window's centre may sit along one axis, given the map's extent [lo, hi] and the window's half size; a map
## narrower than the window stays centred.
func _clamp_centre(c: float, lo: float, hi: float, half: float) -> float:
	var a := lo - SEA_SLACK + half
	var b := hi + SEA_SLACK - half
	if a > b:
		return (lo + hi) * 0.5
	return clampf(c, a, b)


func _key_pan(delta: float) -> void:
	var f := 0.0
	var r := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		f += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		f -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		r += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		r -= 1.0
	if f == 0.0 and r == 0.0:
		return
	var fwd := -_cam.global_transform.basis.z
	fwd.y = 0.0
	var right := _cam.global_transform.basis.x
	right.y = 0.0
	var speed := key_pan_speed * lerpf(0.5, 1.0, inverse_lerp(LEAN_MIN, LEAN_MAX, _lean))
	var move := (fwd.normalized() * f + right.normalized() * r).normalized() * speed * delta
	# Looking further away means the map slides toward the camera.
	_set_pan(_pan - Vector2(move.x, move.z))


# ── Cameras ───────────────────────────────────────────────────────────────────

## The table camera leans along one line; the map camera copies its pose, shifted by the pan and the paper's height,
## so the map's tile tops land on the window plane in the table's own perspective.
func _update_cameras() -> void:
	var target := Vector3(0.0, _paper_y, CAM_TARGET_Z)
	_cam.position = target + CAM_DIR.normalized() * CAM_DIST * _lean
	_cam.look_at(target, Vector3.UP)
	var t := _cam.global_transform
	t.origin -= Vector3(_pan.x, _paper_y, _pan.y)
	_map_cam.transform = t


func _fit_map_view() -> void:
	_sv.size = Vector2i(get_viewport().get_visible_rect().size)


# ── Input ─────────────────────────────────────────────────────────────────────

## Sees every mouse event first (the panel's button included) only to remember where the mouse is; consumes nothing.
func _input(event: InputEvent) -> void:
	var m := event as InputEventMouse
	if m:
		_mouse = m.position


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_lean_target = clampf(_lean_target - LEAN_STEP, LEAN_MIN, LEAN_MAX)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_lean_target = clampf(_lean_target + LEAN_STEP, LEAN_MIN, LEAN_MAX)
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				var hit = _plane_hit(mb.position)
				if _live and hit != null and _in_window(hit):
					_dragging = true
					_drag_moved = 0.0
					_drag_last = hit
			elif _dragging:
				_dragging = false
				if mb.button_index == MOUSE_BUTTON_LEFT and _drag_moved < CLICK_SLOP:
					_open_detail(_hex_at(mb.position))
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_close_detail()
		return
	var mm := event as InputEventMouseMotion
	if mm and _dragging:
		_drag_moved += mm.relative.length()
		var hit = _plane_hit(mm.position)
		if hit != null:
			var d: Vector3 = hit - _drag_last
			_set_pan(_pan + Vector2(d.x, d.z))
			_drag_last = hit
		return
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		if k.keycode == KEY_ESCAPE:
			_close_detail()
		elif k.keycode == KEY_R and _live:
			_spawn_map()
		elif k.keycode == KEY_T and _live and use_world_gen_v2:
			var at := WORLD_KINDS.find(world_type)
			world_type = WORLD_KINDS[(at + 1) % WORLD_KINDS.size()]
			_spawn_map()


## Where the mouse ray meets the window plane (the paper's top), or null.
func _plane_hit(screen_pos: Vector2):
	var origin := _cam.project_ray_origin(screen_pos)
	var dir := _cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return null
	var t := (_paper_y - origin.y) / dir.y
	if t < 0.0:
		return null
	return origin + dir * t


func _in_window(p: Vector3) -> bool:
	return absf(p.x) <= WIN_W * 0.5 and absf(p.z) <= WIN_D * 0.5


## The record under the mouse, or {}: the nearest hex centre to the plane point, in the map's own coordinates.
func _hex_at(screen_pos: Vector2) -> Dictionary:
	var hit = _plane_hit(screen_pos)
	if hit == null or not _in_window(hit) or _by_coord.is_empty():
		return {}
	var m := Vector2(hit.x - _pan.x, hit.z - _pan.y)
	var row0 := roundi(m.y / HexGrid.ROW_STEP)
	var best := Vector2i.ZERO
	var best_d := INF
	for r in range(row0 - 1, row0 + 2):
		var off := HexGrid.ROW_OFFSET if r % 2 != 0 else 0.0
		var c0 := roundi((m.x - off) / HexGrid.COL_STEP)
		for c in range(c0 - 1, c0 + 2):
			var w := HexGrid.offset_to_world(c, r)
			var d := Vector2(w.x, w.z).distance_squared_to(m)
			if d < best_d:
				best_d = d
				best = Vector2i(c, r)
	if best_d > HEX_R * HEX_R:
		return {}
	return _by_coord.get(best, {})


# ── Hover and details (2D only) ───────────────────────────────────────────────

func _update_hover() -> void:
	var rec: Dictionary = {}
	if _live and _mouse.x >= 0.0 and not (_dragging and _drag_moved >= CLICK_SLOP):
		rec = _hex_at(_mouse)
	_hover_rec = rec
	if rec.is_empty():
		_hover_panel.visible = false
	else:
		_hover_label.text = _short_name(rec)
		_hover_panel.visible = true
		_hover_panel.reset_size()
		_hover_panel.position = _mouse + Vector2(18.0, 20.0)
	_outline.queue_redraw()


func _draw_outline() -> void:
	if _hover_rec.is_empty():
		return
	var c: Vector2i = _hover_rec.coord
	var w := HexGrid.offset_to_world(c.x, c.y)
	var corners := [Vector2(0.0, -HEX_R), Vector2(1.0, -HEX_R * 0.5), Vector2(1.0, HEX_R * 0.5),
		Vector2(0.0, HEX_R), Vector2(-1.0, HEX_R * 0.5), Vector2(-1.0, -HEX_R * 0.5)]
	var pts := PackedVector2Array()
	for k in corners:
		var o := Vector3(w.x + k.x + _pan.x, _paper_y + 0.05, w.z + k.y + _pan.y)
		if _cam.is_position_behind(o):
			return
		pts.append(_cam.unproject_position(o))
	pts.append(pts[0])
	_outline.draw_polyline(pts, OUTLINE, 2.5, true)


## The hover's one line: the most particular name the hex has (settlement, river, lake, forest, range), else its terrain.
func _short_name(rec: Dictionary) -> String:
	if rec.get("is_ruin", false) and not rec.get("ruin_discovered", false):
		return "Unknown Ruins"
	if rec.get("is_center", false):
		return "Your tavern"
	if rec.get("is_zone", false):
		return str(rec.get("location_name", "Settlement"))
	if int(rec.get("river_mask", 0)) != 0 and str(rec.get("river", "")) != "":
		return str(rec.river)
	if str(rec.get("feature", "")) != "":
		return str(rec.feature)
	return _terrain(rec)


func _terrain(rec: Dictionary) -> String:
	if rec.get("is_lake", false):
		return "Lake"
	var biome := str(rec.get("biome", ""))
	var t: String = BIOME_NAMES.get(biome, biome.capitalize())
	if int(rec.get("river_mask", 0)) != 0:
		t += " by a river" if not rec.get("is_center", false) else ""
	return t


## The click panel (a popup: freed on close, never hidden). DRAFT text throughout.
func _open_detail(rec: Dictionary) -> void:
	_close_detail()
	if rec.is_empty():
		return
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320.0, 0.0)
	panel.add_theme_stylebox_override("panel", _panel_style(0.94))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := Label.new()
	title.text = _short_name(rec)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", GOLD)
	box.add_child(title)
	var c: Vector2i = rec.coord
	var lines: Array = ["Terrain: %s" % _terrain(rec)]
	if str(rec.get("region", "")) != "":
		lines.append("Land: %s" % rec.region)
	if str(rec.get("river", "")) != "" and title.text != str(rec.river):
		lines.append("River: %s" % rec.river)
	if str(rec.get("feature", "")) != "" and title.text != str(rec.feature):
		lines.append(str(rec.feature))
	lines.append("Hex %d, %d" % [c.x, c.y])
	if not rec.get("is_center", false) and _map != null:
		var d: int = _map.call("_hex_distance", _home, c)   # HexMapGenerator's (offset coords, static)
		var per_day: float = 3.0
		var dm := get_node_or_null("/root/DataManager")
		if dm:
			per_day = float(dm.get_config("mission_hexes_per_day", 3.0))
		lines.append("From the tavern: %d hexes, about %d days out" % [d, maxi(1, ceili(d / maxf(per_day, 0.1)))])
	lines.append(_contract_line(rec))
	lines.append("Mission types: shown here once missions use the big map")
	for line in lines:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 15)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(296.0, 0.0)   # a wrap width up front, so the panel sizes to its text
		box.add_child(l)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(_close_detail)
	box.add_child(close)
	_ui.add_child(panel)
	panel.reset_size()
	var vp := get_viewport().get_visible_rect().size
	panel.position = Vector2(vp.x - panel.size.x - 24.0, 90.0)
	_detail = panel


func _contract_line(rec: Dictionary) -> String:
	if rec.get("is_center", false):
		return "Your guild's home"
	if rec.get("is_zone", false):
		return "A settlement: it posts its own contracts"
	if rec.get("is_ruin", false):
		return "Nobody has been inside"
	if str(rec.get("biome", "")) == "sea":
		return "No contracts at sea"
	if _wm_script != null and _wm_script.is_mission_eligible(rec):
		return "Contracts can be posted here"
	return "No contracts here"


func _close_detail() -> void:
	if _detail != null and is_instance_valid(_detail):
		_detail.queue_free()
	_detail = null


# ── Building ──────────────────────────────────────────────────────────────────

func _build_map_view() -> void:
	_sv = SubViewport.new()
	_sv.name = "MapView"
	_sv.own_world_3d = true
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.msaa_3d = get_viewport().msaa_3d
	_sv.screen_space_aa = get_viewport().screen_space_aa
	add_child(_sv)
	_fit_map_view()

	var we := WorldEnvironment.new()
	we.environment = _environment(SEA)
	_sv.add_child(we)
	_sv.add_child(_sun())

	# the sea past the world's edge: the map slides over open water, never over nothing
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000.0, 4000.0)
	sea.mesh = plane
	sea.position.y = -0.25   # just under the water tiles' tops (-0.2)
	sea.material_override = _mat(SEA)
	_sv.add_child(sea)

	_map_cam = Camera3D.new()
	_map_cam.fov = CAM_FOV
	_map_cam.far = 3000.0
	_sv.add_child(_map_cam)
	_map_cam.current = true
	_add_ink(_map_cam)


func _build_table() -> void:
	var we := WorldEnvironment.new()
	we.environment = _environment(BACKGROUND)
	add_child(we)
	add_child(_sun())

	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1200.0, 1200.0)
	floor_mi.mesh = plane
	floor_mi.material_override = _mat(FLOOR)
	add_child(floor_mi)

	var table: Node3D = (load(TABLE_SCENE) as PackedScene).instantiate()
	table.scale = Vector3.ONE * TABLE_SCALE
	table.rotation_degrees.y = 90.0   # its long side along x
	add_child(table)

	# the scroll: a sheet that grows from the left roller while the right roller rolls across
	var table_top := TABLE_HEIGHT * TABLE_SCALE
	_paper_pivot = Node3D.new()
	_paper_pivot.position = Vector3(-SCROLL_W * 0.5, table_top, 0.0)
	_paper_pivot.scale = Vector3(0.02, 1.0, 1.0)
	add_child(_paper_pivot)
	var paper := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(SCROLL_W, PAPER_THICK, SCROLL_D)
	paper.mesh = box
	paper.position = Vector3(SCROLL_W * 0.5, PAPER_THICK * 0.5, 0.0)
	paper.material_override = _paper_mat()
	_paper_pivot.add_child(paper)
	add_child(_roller(Vector3(-SCROLL_W * 0.5, table_top + ROLL_R, 0.0)))
	_right_roll = _roller(Vector3(-SCROLL_W * 0.5 + 2.0 * ROLL_R, table_top + ROLL_R, 0.0))
	add_child(_right_roll)

	# the frame round the window (the sketch's border), shown once the scroll is open
	_frame = Node3D.new()
	_frame.visible = false
	add_child(_frame)
	var y := _paper_y + FRAME_H * 0.5
	for side in [-1.0, 1.0]:
		_frame.add_child(_bar(Vector3(WIN_W + 2.0 * FRAME_W, FRAME_H, FRAME_W),
			Vector3(0.0, y, side * (WIN_D + FRAME_W) * 0.5)))
		_frame.add_child(_bar(Vector3(FRAME_W, FRAME_H, WIN_D), Vector3(side * (WIN_W + FRAME_W) * 0.5, y, 0.0)))

	# the window: the map view, shown through the paper
	_window = MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(WIN_W, WIN_D)
	_window.mesh = quad
	_window.position.y = _paper_y + 0.02
	var wm := ShaderMaterial.new()
	wm.shader = load(WINDOW_SHADER)
	wm.render_priority = 1
	wm.set_shader_parameter("map_view", _sv.get_texture())
	_window.material_override = wm
	_window.visible = false
	add_child(_window)

	_cam = Camera3D.new()
	_cam.fov = CAM_FOV
	_cam.far = 3000.0
	add_child(_cam)
	_cam.current = true
	_add_ink(_cam)


func _unroll(seconds: float) -> void:
	var start_x := _right_roll.position.x
	var end_x := SCROLL_W * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_paper_pivot, "scale:x", 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_right_roll, "position:x", end_x, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_right_roll, "rotation:z", -(end_x - start_x) / ROLL_R, seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)

	_outline = Control.new()
	_outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline.draw.connect(_draw_outline)
	_ui.add_child(_outline)

	_hover_panel = PanelContainer.new()
	_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_panel.add_theme_stylebox_override("panel", _panel_style(0.88))
	_hover_panel.visible = false
	_hover_label = Label.new()
	_hover_label.add_theme_font_size_override("font_size", 15)
	_hover_label.add_theme_color_override("font_color", GOLD)
	_hover_panel.add_child(_hover_label)
	_ui.add_child(_hover_panel)

	var hint_panel := PanelContainer.new()
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.add_theme_stylebox_override("panel", _panel_style(0.80))
	hint_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_panel.offset_left = 16.0
	hint_panel.offset_bottom = -12.0
	hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70, 0.95))
	hint_panel.add_child(_hint)
	_ui.add_child(hint_panel)

	# the world's name over the table (2D, like every other cue here)
	var head := VBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.set_anchors_preset(Control.PRESET_CENTER_TOP)
	head.grow_horizontal = Control.GROW_DIRECTION_BOTH
	head.offset_top = 14.0
	head.add_theme_constant_override("separation", 0)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_color_override("font_color", GOLD)
	_title.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
	_title.add_theme_constant_override("outline_size", 8)
	_title.visible = false
	head.add_child(_title)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 15)
	_subtitle.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70, 0.9))
	_subtitle.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
	_subtitle.add_theme_constant_override("outline_size", 5)
	head.add_child(_subtitle)
	_ui.add_child(head)


# ── Pieces ────────────────────────────────────────────────────────────────────

func _environment(background: Color) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.47, 0.40)
	env.ambient_light_energy = 0.55
	return env


## The same sun in both worlds, so the map and the table are lit alike.
func _sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.93, 0.80)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 600.0
	sun.rotation_degrees = Vector3(-58.0, -35.0, 0.0)
	return sun


func _roller(pos: Vector3) -> Node3D:
	var r := Node3D.new()
	r.position = pos
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = ROLL_R
	cyl.bottom_radius = ROLL_R
	cyl.height = SCROLL_D + 1.0
	body.mesh = cyl
	body.rotation_degrees.x = 90.0
	body.material_override = _mat(PAPER.darkened(0.12))
	r.add_child(body)
	for side in [-1.0, 1.0]:
		var knob := MeshInstance3D.new()
		var k := CylinderMesh.new()
		k.top_radius = ROLL_R * 0.55
		k.bottom_radius = ROLL_R * 0.55
		k.height = 4.0
		knob.mesh = k
		knob.rotation_degrees.x = 90.0
		knob.position = Vector3(0.0, 0.0, side * (SCROLL_D * 0.5 + 2.5))
		knob.material_override = _mat(WOOD_DARK)
		r.add_child(knob)
	return r


func _bar(size: Vector3, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = _mat(FRAME_INK)
	return mi


## The game's ink pass (edge_detection.gdshader), set up the way HexMapTest's camera has it.
func _add_ink(cam: Camera3D) -> void:
	var quad := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.flip_faces = true
	q.size = Vector2(2.0, 2.0)
	quad.mesh = q
	quad.extra_cull_margin = 16384.0
	var m := ShaderMaterial.new()
	m.shader = load(EDGE_SHADER)
	m.set_shader_parameter("lightIntensity", 1.25)
	m.set_shader_parameter("lineAlpha", 0.7)
	m.set_shader_parameter("useLighting", true)
	m.set_shader_parameter("lineHighlight", 0.2)
	m.set_shader_parameter("lineShadow", 0.55)
	quad.material_override = m
	cam.add_child(quad)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func _paper_mat() -> StandardMaterial3D:
	var m := _mat(Color.WHITE)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.noise = noise
	var g := Gradient.new()
	g.set_color(0, PAPER.darkened(0.10))
	g.set_color(1, PAPER.lightened(0.06))
	tex.color_ramp = g
	m.albedo_texture = tex
	return m


func _panel_style(alpha: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.08, 0.07, alpha)
	s.border_color = Color(0.80, 0.60, 0.20, 0.70)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 12.0
	s.content_margin_right = 12.0
	s.content_margin_top = 6.0
	s.content_margin_bottom = 6.0
	return s
