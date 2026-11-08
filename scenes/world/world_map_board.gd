extends Control

signal board_closed

const HEX_MAP_SCENE := preload("res://scenes/HexMapTest.tscn")
const MISSION_SLOT_SCRIPT := preload("res://scenes/world/mission_slot.gd")
const MAP_PLACES := preload("res://scripts/world/map_places.gd")

## 2026-11-08 (Raphael: "little clickable scrolls that zoom out/pan out and display more information"): each contract
## is a small rolled scroll drawn in 2D (its ribbon and seal in the danger's colour; a deployed one grey and still).
## Hovering one unrolls a short preview above it; a click grows the full scroll out of it, and closing rolls it back.
const MARKER_PAPER := Color(0.91, 0.83, 0.63, 1.0)
const MARKER_PAPER_SHADE := Color(0.74, 0.63, 0.44, 1.0)
const MARKER_WOOD := Color(0.38, 0.23, 0.12, 1.0)
const MARKER_LINE := Color(0.12, 0.08, 0.05, 0.95)
const MARKER_HALO := Color(1.0, 0.86, 0.40, 0.22)
const MARKER_DIM := Color(0.62, 0.64, 0.70, 1.0)     # a deployed contract's scroll, multiplied over its colours
const MARKER_HOT_SCALE := 1.25                         # the hovered scroll
const PREVIEW_SECONDS := 0.14                          # the hover preview unrolls
const ZOOM_SECONDS := 0.22                             # the full scroll flies out of its marker, then unrolls (UNFURL_SECONDS)
const CLOSE_SECONDS := 0.16                            # and rolls back into it

## Story 6.5: a click this close to a marker's drawn centre opens its hex (the nearest marker wins).
const MARKER_HIT_RADIUS := 36.0
## Story 6.5 (DD-6): the Good fit bar when game_config.json's dispatch_strong_fit_min_chance is missing or bad.
const STRONG_FIT_DEFAULT := 70
const FOUR_STATS := ["strength", "dexterity", "intelligence", "endurance"]   # the stats the success formula reads
# The scroll (Story 6.5, DD-9): placeholder_scroll, a flat parchment panel, until the U11 / Story 25.20 UI skin.
const SCROLL_PAPER := Color(0.87, 0.80, 0.63, 0.98)
const SCROLL_EDGE := Color(0.45, 0.32, 0.18, 1.0)
const SCROLL_SLOT := Color(0.78, 0.70, 0.52, 1.0)
const INK := Color(0.20, 0.13, 0.07, 1.0)
const INK_SOFT := Color(0.40, 0.31, 0.20, 1.0)
const INK_RED := Color(0.62, 0.13, 0.10, 1.0)
const INK_GREEN := Color(0.13, 0.42, 0.15, 1.0)
const INK_GOLD := Color(0.52, 0.38, 0.03, 1.0)
const UNFURL_SECONDS := 0.18
## Story 6.5 review P14: the board draws on its own CanvasLayer above the hall's GameUI (ZonePromptUI.gd sets it to 100
## at runtime: the top bar, the event log, the roster strip, popups, the E prompt), the morning briefing (100) and the
## lighting dev overlay (101), so the map is a clean full screen while it is open; the dialogue box (110) and the Codex
## (128) still draw above it. attach_to() makes the layer.
const CANVAS_LAYER := 105
## board_view(): the camera's place from what it looks at (the board's fixed view before 2026-11-08), the distance
## from the tavern that view keeps (13 steps reach at most 29.1 units on HexGrid's 2 x 2 spacing, so the old island's
## contracts never move it), and how far it may pull back.
const BOARD_CAM_OFFSET := Vector3(20.0, 50.0, 23.0)
const BOARD_REACH := 30.0
const BOARD_MAX_PULL := 3.0

var _sv: SubViewport
var _svc: SubViewportContainer
var _cam: Camera3D

var _bubble: PanelContainer
var _bubble_biome: Label
var _bubble_mission: Label
var _bubble_danger: Label

var _marker_layer: Control
var _marker_tweens: Array = []
var _markers: Array = []          # [{hex_id, pos}]: where each marker is drawn (Story 6.5: a click on one opens its hex)
var _marker_nodes: Dictionary = {}   # hex_id -> its scroll marker (the hovered one grows)
var _preview: PanelContainer = null  # the hover preview over a scroll marker (freed when it goes)
var _preview_hex := ""
var _badges: Dictionary = {}      # hex_id -> the party size shown on its marker
var _chips: Dictionary = {}       # hex_id -> the deployed chip's text

var _detail_panel: Control = null
var _closed_frame := -10          # the process frame a scroll last closed in (review P4: no click through a closing scroll)
var _header: Label = null         # the board's own top line: day, gold, who is ready (review P14)

# Scroll state — valid only while _detail_panel != null
var _panel_mission: Dictionary = {}
var _panel_rec: Dictionary = {}   # same dict object as WorldManager.world_map entry
var _panel_n: int = 0
var _panel_read_only := false     # a deployed hex: who is out, no places, no Send
var _assigned_ids: Array = []
var _slots: Array = []            # the place nodes (mission_slot.gd), in order
var _token_order: Array = []      # adventurer ids, in the order their tokens are shown
var _tokens: Dictionary = {}      # adventurer id -> {name, sub, tag: Label}
var _good_fit: Array = []
var _chance_label: Label = null
var _accept_btn: Button = null
var _party_label: Label = null
var _uses_label: Label = null
var _trait_label: Label = null
var _need_label: Label = null
var _reason_label: Label = null
var _readonly_label: Label = null


func _ready() -> void:
	add_to_group("mission_board")
	add_to_group("blocks_player")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_svc = SubViewportContainer.new()
	_svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_svc.stretch = true
	_svc.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_svc)

	_sv = SubViewport.new()
	_sv.size = Vector2i(1920, 1080)
	_sv.handle_input_locally = false
	_sv.own_world_3d = true
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_svc.add_child(_sv)

	var hex_map := HEX_MAP_SCENE.instantiate()
	hex_map.display_mode = true
	var controls := hex_map.get_node_or_null("CanvasLayer")
	if controls:
		controls.visible = false
	_sv.add_child(hex_map)

	_cam = hex_map.get_node_or_null("Camera3D") as Camera3D
	if _cam:
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_cam.fov = 50.0
		_frame_camera()

	# Marker layer sits above the SubViewport but below the hover bubble.
	_marker_layer = Control.new()
	_marker_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marker_layer)

	_build_bubble()
	_build_news_panel()
	_build_header()

	var hint := Label.new()
	hint.text = "Press ESC to close"
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	hint.add_theme_font_size_override("font_size", 14)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -220.0
	hint.offset_top = -36.0
	hint.offset_right = -12.0
	hint.offset_bottom = -12.0
	add_child(hint)


## Where the board's camera looks from and at (2026-11-08, World Gen v2 on New Game): at the tavern wherever it stands,
## from BOARD_CAM_OFFSET, pulled back (up to BOARD_MAX_PULL times) until the farthest contract or taken hex fits. The
## old island (the tavern at (0, 0), contracts within 13 steps) keeps exactly the view it always had. Static so the
## headless suite can check it.
static func board_view(records: Array) -> Dictionary:
	var target := Vector3.ZERO
	for rec in records:
		if rec is Dictionary and rec.get("is_center", false):
			target = _hex_world(rec.get("coord"))
			break
	var reach := 0.0
	for rec in records:
		if rec is Dictionary and (rec.get("active_mission") is Dictionary or rec.get("locked", false)):
			var w := _hex_world(rec.get("coord"))
			reach = maxf(reach, Vector2(w.x - target.x, w.z - target.z).length())
	var pull := clampf(reach / BOARD_REACH, 1.0, BOARD_MAX_PULL)
	return {"target": target, "position": target + BOARD_CAM_OFFSET * pull}


## Aims the camera with board_view() at the contracts as they are now: when the board is made, when it opens (the hall
## may place the day's contracts only then) and when they change.
func _frame_camera() -> void:
	if _cam == null:
		return
	var view := board_view(WorldManager.world_map)
	_cam.position = view.position
	_cam.look_at(view.target, Vector3.UP)


## A record's coord (Vector2i in memory, [x, y] in a save) as the hex's world position; (0, 0) for anything else.
static func _hex_world(c) -> Vector3:
	if c is Vector2i or c is Vector2:
		return HexGrid.offset_to_world(int(c.x), int(c.y))
	if c is Array and c.size() == 2:
		return HexGrid.offset_to_world(int(c[0]), int(c[1]))
	return Vector3.ZERO


func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.custom_minimum_size = Vector2(200.0, 0.0)
	_bubble.visible = false
	add_child(_bubble)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	_bubble.add_child(vbox)

	_bubble_biome = Label.new()
	_bubble_biome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_biome.add_theme_font_size_override("font_size", 13)
	_bubble_biome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_bubble_biome)

	_bubble_mission = Label.new()
	_bubble_mission.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_mission.add_theme_font_size_override("font_size", 12)
	_bubble_mission.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_mission.visible = false
	vbox.add_child(_bubble_mission)

	_bubble_danger = Label.new()
	_bubble_danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_danger.add_theme_font_size_override("font_size", 12)
	_bubble_danger.visible = false
	vbox.add_child(_bubble_danger)


## Review P14: hosts the board on its own CanvasLayer under `parent` (zone_interactions passes the root). The layer is
## freed when the board leaves the tree. Returns the layer.
func attach_to(parent: Node) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "WorldMapLayer"
	layer.layer = CANVAS_LAYER
	layer.add_child(self)
	parent.add_child(layer)
	tree_exited.connect(layer.queue_free)
	return layer


## The board's own top line (the hall's top bar is under the map): top centre, clear of Latest News (top left).
func _build_header() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 16.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.07, 0.90)
	style.border_color = Color(0.80, 0.60, 0.20, 0.70)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_header = Label.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_theme_font_size_override("font_size", 15)
	_header.add_theme_color_override("font_color", Color(0.95, 0.88, 0.62, 1.0))
	panel.add_child(_header)
	_refresh_header()


func _refresh_header() -> void:
	if _header == null:
		return
	var ready := 0
	for adv in GameManager.adventurers:
		if adv is Dictionary and GameManager.not_ready_reason(adv) == "":
			ready += 1
	_header.text = header_text(GameManager.current_day, GameManager.gold, ready, GameManager.adventurers.size())


static func header_text(day: int, gold: int, ready: int, roster: int) -> String:
	return "Day %d  ·  %d gold  ·  %d of %d ready" % [day, gold, ready, roster]


# ── Latest News (Epic 6 / FR-19b) — drains WorldManager.overheard_rumours ──────

const _NEWS_MAX_LINES := 5

func _build_news_panel() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(260.0, 0.0)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(16.0, 16.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.07, 0.90)
	style.border_color = Color(0.80, 0.60, 0.20, 0.70)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "Latest News"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.90, 0.80, 0.30, 1.0))
	vbox.add_child(header)
	vbox.add_child(HSeparator.new())

	var rumours: Array = WorldManager.overheard_rumours
	if rumours.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No word from the road yet. Loiter near drinking patrons back at the tavern to overhear rumours."
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder.add_theme_font_size_override("font_size", 12)
		placeholder.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1.0))
		placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(placeholder)
		return

	# Most recent first, capped so the panel can't grow unbounded over a long run.
	var recent := rumours.slice(maxi(0, rumours.size() - _NEWS_MAX_LINES), rumours.size())
	recent.reverse()
	for line in recent:
		var entry := Label.new()
		entry.text = "• " + str(line)
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_theme_font_size_override("font_size", 12)
		entry.add_theme_color_override("font_color", Color(0.82, 0.80, 0.75, 1.0))
		entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(entry)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseMotion:
		_handle_hover(event.position)

	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		# Review P4: a double-click, or a press in the frame a scroll closed or the next, doesn't open another one.
		if event.double_click or Engine.get_process_frames() - _closed_frame <= 1:
			if _detail_panel == null:
				get_viewport().set_input_as_handled()
			return
		# While the scroll is open let its own buttons handle clicks.
		if _detail_panel == null:
			# Story 6.5: a click on a marker opens its hex; anywhere else, the hex under the cursor (raycast).
			var rec := _record_by_id(marker_hit(_markers, event.position, MARKER_HIT_RADIUS))
			if rec.is_empty():
				rec = _record_at_screen(event.position)
			if not rec.is_empty() and rec.get("active_mission", null) != null:
				_open_detail_panel(rec)
				get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_cancel"):
		# ESC priority: close the scroll first; only close the board when no scroll is open.
		if _detail_panel != null:
			_close_detail_panel()
		else:
			_close()
		get_viewport().set_input_as_handled()


# ── Shared raycast helper — ONE implementation, called by hover AND click ──────

func _record_at_screen(mouse_pos: Vector2) -> Dictionary:
	"""Cast a ray from a screen pixel through the SubViewport camera.
	Returns the matching WorldManager hex record, or {} on a miss."""
	if _sv == null or _cam == null:
		return {}
	var svc_rect := _svc.get_global_rect()
	if not svc_rect.has_point(mouse_pos):
		return {}
	# Screen pixel → SubViewport pixel (sv is 1920×1080 stretched to svc_rect)
	var local := mouse_pos - svc_rect.position
	var sv_pos := Vector2(
		local.x / svc_rect.size.x * float(_sv.size.x),
		local.y / svc_rect.size.y * float(_sv.size.y)
	)
	var origin    := _cam.project_ray_origin(sv_pos)
	var direction := _cam.project_ray_normal(sv_pos)
	var space_state := _cam.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 2000.0)   # far enough for board_view's pull
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return {}
	var area: Object = result["collider"]
	if not area.has_meta("hex_id"):
		return {}
	return _record_by_id(str(area.get_meta("hex_id")))


func _record_by_id(hex_id: String) -> Dictionary:
	if hex_id == "":
		return {}
	for rec in WorldManager.world_map:
		if rec["id"] == hex_id:
			return rec
	return {}


## Story 6.5: the hex whose marker is drawn nearest `pos`, within `radius` px; "" = none. markers: [{hex_id, pos}].
static func marker_hit(markers: Array, pos: Vector2, radius: float) -> String:
	var best := ""
	var best_d := radius
	for m in markers:
		if not (m is Dictionary) or not (m.get("pos") is Vector2):
			continue
		var d: float = (m.pos as Vector2).distance_to(pos)
		if d <= best_d:
			best_d = d
			best = str(m.get("hex_id", ""))
	return best


func _handle_hover(mouse_pos: Vector2) -> void:
	# No hover bubble or preview while the scroll is showing.
	if _detail_panel != null:
		_hide_bubble()
		_hide_preview()
		return
	# Over a contract's scroll marker: its preview unrolls (instead of the bubble).
	var hid := marker_hit(_markers, mouse_pos, MARKER_HIT_RADIUS)
	if hid != "":
		if hid != _preview_hex:
			var mrec := _record_by_id(hid)
			if not mrec.is_empty():
				_show_preview(mrec)
		if _preview != null:
			_hide_bubble()
			return
	_hide_preview()
	var rec := _record_at_screen(mouse_pos)
	if rec.is_empty():
		_hide_bubble()
		return
	_show_bubble(rec, mouse_pos)


func _show_bubble(rec: Dictionary, mouse_pos: Vector2) -> void:
	var place := MAP_PLACES.short_line(rec)   # 2026-11-08: a settlement with its size, or a monument's name
	_bubble_biome.text = place if place != "" else _biome_line(rec.get("biome", ""))

	var mission = rec.get("active_mission", null)
	if rec.get("is_ruin", false) and not rec.get("ruin_discovered", false):
		# Story 6.3: the undiscovered ruin next to the tavern shows no further detail.
		_bubble_biome.text = "Unknown Ruins"
		_bubble_mission.visible = false
		_bubble_danger.visible = false
	elif mission != null:
		if GameManager.is_hex_taken(rec):
			# Story 6.5 (DD-8): who is out here, and when they're back.
			var info: Dictionary = GameManager.deployment_info(str(rec.get("id", "")))
			_bubble_mission.text = out_text(info.get("names", []), int(info.get("return_day", -1)))
		else:
			var line := "Work available: " + str(mission.get("name", "Unknown"))
			var n: int = GameManager.required_party_size(mission)
			if n > 1:
				line += "\n" + party_text(n)
			_bubble_mission.text = line
		_bubble_mission.visible = true
		var danger: int = int(mission.get("danger", 1))
		_bubble_danger.text = _danger_text(danger)
		_bubble_danger.add_theme_color_override("font_color", _danger_color(danger))
		_bubble_danger.visible = true
	else:
		_bubble_mission.visible = false
		_bubble_danger.visible = false

	# Position near cursor, clamped so bubble stays on screen
	var bubble_min := _bubble.get_combined_minimum_size()
	var vp_size    := get_viewport().get_visible_rect().size
	var bx := clampf(mouse_pos.x + 16.0, 0.0, vp_size.x - bubble_min.x)
	var by := clampf(mouse_pos.y + 16.0, 0.0, vp_size.y - bubble_min.y)
	_bubble.position = Vector2(bx, by)
	_bubble.visible = true


func _hide_bubble() -> void:
	if _bubble != null:
		_bubble.visible = false


## The lines a scroll marker's preview shows: the contract's name, its danger, days and reward, then the party it needs
## or, out on a deployment, who is out and when they're back. DRAFT words.
func preview_lines(rec: Dictionary) -> Array:
	var mission = rec.get("active_mission")
	if not mission is Dictionary:
		return []
	var lines := [str(mission.get("name", "Unknown Mission")), _danger_text(int(mission.get("danger", 1)))]
	var days: int = int(mission.get("duration_days", 1))
	var line := "%d %s" % [days, "day" if days == 1 else "days"]
	var reward = mission.get("reward_range", [])
	if reward is Array and reward.size() >= 2:
		line += " · %d–%d gold" % [int(reward[0]), int(reward[1])]
	lines.append(line)
	if GameManager.is_hex_taken(rec):
		var info: Dictionary = GameManager.deployment_info(str(rec.get("id", "")))
		lines.append(out_text(info.get("names", []), int(info.get("return_day", -1))))
	else:
		var n: int = GameManager.required_party_size(mission)
		if n > 1:
			lines.append(party_text(n))
		lines.append("Click to unroll")
	return lines


## The hovered scroll grows and a small parchment preview unrolls upward from it (2D, never over the open scroll).
func _show_preview(rec: Dictionary) -> void:
	_hide_preview()
	var lines := preview_lines(rec)
	var hex_id := str(rec.get("id", ""))
	var at: Vector2 = Vector2.ZERO
	var found := false
	for m in _markers:
		if m is Dictionary and str(m.get("hex_id", "")) == hex_id:
			at = m.pos
			found = true
			break
	if lines.is_empty() or not found:
		return
	var mission: Dictionary = rec.active_mission
	var card := PanelContainer.new()
	card.name = "ScrollPreview"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = SCROLL_PAPER
	style.border_color = SCROLL_EDGE
	style.set_border_width_all(2)
	style.border_width_top = 6       # the rolled ends, as on the full scroll
	style.border_width_bottom = 6
	style.set_corner_radius_all(3)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	for i in lines.size():
		var color := INK if i == 0 else (_danger_ink(int(mission.get("danger", 1))) if i == 1 else INK_SOFT)
		var label := _ink_label(str(lines[i]), 16 if i == 0 else 13, color)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == lines.size() - 1 and lines[i] == "Click to unroll":
			label.add_theme_color_override("font_color", Color(INK_SOFT, 0.7))
		box.add_child(label)
	add_child(card)
	var card_size := card.get_combined_minimum_size()
	card.size = card_size
	var vp := get_viewport().get_visible_rect().size
	card.position = Vector2(clampf(at.x - card_size.x * 0.5, 4.0, vp.x - card_size.x - 4.0), clampf(at.y - card_size.y - 30.0, 4.0, vp.y - card_size.y - 4.0))
	card.pivot_offset = Vector2(card_size.x * 0.5, card_size.y)   # unrolls upward from the marker
	card.scale = Vector2(1.0, 0.1)
	card.modulate.a = 0.0
	var tw := card.create_tween().set_parallel(true)
	tw.tween_property(card, "scale:y", 1.0, PREVIEW_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(card, "modulate:a", 1.0, PREVIEW_SECONDS * 0.6)
	_preview = card
	_preview_hex = hex_id
	var marker = _marker_nodes.get(hex_id)
	if marker is Control and is_instance_valid(marker):
		(marker as Control).scale = Vector2.ONE * MARKER_HOT_SCALE


func _hide_preview() -> void:
	if _preview != null and is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null
	var marker = _marker_nodes.get(_preview_hex)
	if marker is Control and is_instance_valid(marker):
		(marker as Control).scale = Vector2.ONE
	_preview_hex = ""


func _biome_line(biome: String) -> String:
	match biome:
		"grass":       return "Open grassland. Quiet, for now."
		"forest":      return "Dense woods. Beasts roam the deep paths."
		"mountain":    return "Jagged peaks. Old stone, old dangers."
		"hills":       return "Rolling hills. Sheep, standing stones, places to hide."   # DRAFT (World Gen v2)
		"coast":       return "Water's edge. Trade winds and restless tides."
		"river":       return "Water's edge. Trade winds and restless tides."
		"sea":         return "Open waters. The deep hides unknown things."
		"tavern_site": return "Your guild's home."
		_:             return biome.capitalize()


# Same values as single_mission_card.gd get_danger_text() / get_danger_color()
func _danger_text(danger: int) -> String:
	match danger:
		1: return "Safe"
		2: return "Low Risk"
		3: return "Moderate"
		4: return "Dangerous"
		5: return "Extreme"
		_: return "Unknown"


func _danger_color(danger: int) -> Color:
	match danger:
		1: return Color.GREEN
		2: return Color.YELLOW
		3: return Color.ORANGE
		4: return Color.RED
		5: return Color.PURPLE
		_: return Color.WHITE


## The danger colours as ink on the parchment scroll (the bright ones don't read on paper).
func _danger_ink(danger: int) -> Color:
	match danger:
		1: return INK_GREEN
		2: return INK_GOLD
		3: return Color(0.70, 0.35, 0.04, 1.0)
		4: return INK_RED
		5: return Color(0.40, 0.12, 0.50, 1.0)
		_: return INK


func _close() -> void:
	_close_detail_panel()
	_clear_markers()
	if GameManager.missions_changed.is_connected(_on_missions_changed):
		GameManager.missions_changed.disconnect(_on_missions_changed)
	board_closed.emit()
	queue_free()


func open_mission_board() -> void:
	visible = true
	_frame_camera()
	GameManager.missions_changed.connect(_on_missions_changed)
	call_deferred("_build_markers")


# ── Hex mission markers ───────────────────────────────────────────────────────

func _on_missions_changed() -> void:
	if visible:
		_frame_camera()
		_build_markers()


func _clear_markers() -> void:
	for tw in _marker_tweens:
		if is_instance_valid(tw):
			tw.kill()
	_marker_tweens.clear()
	for child in _marker_layer.get_children():
		child.free()
	_markers.clear()
	_marker_nodes.clear()
	_hide_preview()
	_badges.clear()
	_chips.clear()


func _build_markers() -> void:
	_clear_markers()

	if _cam == null or _sv == null or _svc == null:
		return

	var svc_rect := _svc.get_global_rect()
	if svc_rect.size.x < 1.0:
		return  # layout not yet settled; open_mission_board defers so this rarely fires

	var tags: Array = []   # [center, text]: spawned after every rune so a neighbour's marker never covers them
	for rec in WorldManager.world_map:
		if rec.get("active_mission", null) == null:
			continue

		# Forward projection: world pos → SubViewport pixel → screen pixel.
		# Exact inverse of _record_at_screen's screen→sv_pos transform.
		var world_pos := HexGrid.offset_to_world(rec.coord.x, rec.coord.y)
		var sv_pixel  := _cam.unproject_position(world_pos)
		var screen_pos := Vector2(
			sv_pixel.x / float(_sv.size.x) * svc_rect.size.x + svc_rect.position.x,
			sv_pixel.y / float(_sv.size.y) * svc_rect.size.y + svc_rect.position.y
		)

		var hex_id := str(rec.get("id", ""))
		var locked: bool = GameManager.is_hex_taken(rec)   # review P6: a stale lock (nobody out) is an open contract
		_markers.append({"hex_id": hex_id, "pos": screen_pos})
		_marker_nodes[hex_id] = _spawn_marker(screen_pos, locked, int(rec.active_mission.get("danger", 1)))
		if locked:
			# Story 6.5 (DD-8): the deployed token chip, under the dimmed rune.
			var info: Dictionary = GameManager.deployment_info(hex_id)
			_chips[hex_id] = chip_text(info.get("names", []), int(info.get("return_day", -1)))
			tags.append([screen_pos + Vector2(0.0, 40.0), _chips[hex_id]])
		else:
			var n: int = GameManager.required_party_size(rec.active_mission)
			if n > 1:
				# Story 6.5: a party mission shows how many it needs, beside its rune.
				_badges[hex_id] = n
				tags.append([screen_pos + Vector2(34.0, 12.0), "×%d" % n])
	for tag in tags:
		_spawn_tag(tag[0], tag[1])
	_refresh_header()


## A contract's marker: a small rolled scroll drawn at `screen_pos` (its ribbon and seal in the danger's colour). An open
## contract floats gently over a soft halo; a deployed one is grey and still.
func _spawn_marker(screen_pos: Vector2, is_locked: bool = false, danger: int = 1) -> Control:
	var marker := Control.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.position = screen_pos
	marker.draw.connect(_draw_scroll_marker.bind(marker, danger, is_locked))
	_marker_layer.add_child(marker)
	if not is_locked:
		var base_y := marker.position.y
		var bob := create_tween()
		bob.set_loops()
		bob.tween_property(marker, "position:y", base_y - 4.0, 1.1).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		bob.tween_property(marker, "position:y", base_y, 1.1).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_marker_tweens.append(bob)
	return marker


## The rolled scroll, centred on the marker's origin: a shadow, (open) a halo, the paper roll with its shaded underside,
## two wooden ends, the ribbon and the wax seal; dark outlines so it reads on grass, sand and water alike.
func _draw_scroll_marker(marker: Control, danger: int, is_locked: bool) -> void:
	var tint := MARKER_DIM if is_locked else Color.WHITE
	var paper := MARKER_PAPER * tint
	var shade := MARKER_PAPER_SHADE * tint
	var wood := MARKER_WOOD * tint
	var seal := (_danger_ink(danger) if not is_locked else Color(0.40, 0.42, 0.48, 1.0))
	var ribbon := (_danger_color(danger).darkened(0.15) if not is_locked else Color(0.55, 0.57, 0.63, 1.0))
	marker.draw_set_transform(Vector2(0.0, 15.0), 0.0, Vector2(1.0, 0.28))
	marker.draw_circle(Vector2.ZERO, 20.0, Color(0.0, 0.0, 0.0, 0.35))
	marker.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not is_locked:
		marker.draw_circle(Vector2.ZERO, 27.0, MARKER_HALO)
	var body := Rect2(-17.0, -8.0, 34.0, 16.0)
	marker.draw_rect(body, paper)
	marker.draw_rect(Rect2(body.position.x, 3.0, body.size.x, 5.0), shade)
	marker.draw_line(Vector2(-15.0, -5.5), Vector2(15.0, -5.5), paper.lightened(0.35), 1.5)
	marker.draw_rect(body, MARKER_LINE, false, 1.5)
	for side in [-1.0, 1.0]:
		var knob := Rect2(Vector2(side * 19.5 - 2.5, -10.0), Vector2(5.0, 20.0))
		marker.draw_rect(knob, wood)
		marker.draw_rect(knob, MARKER_LINE, false, 1.5)
	marker.draw_rect(Rect2(-3.0, -8.0, 6.0, 16.0), ribbon)
	marker.draw_circle(Vector2(0.0, 0.5), 5.5, MARKER_LINE)
	marker.draw_circle(Vector2(0.0, 0.5), 4.5, seal)


## Story 6.5: a small dark tag centred on `center` (a party size, or a deployed chip). Not part of the pulsing marker.
func _spawn_tag(center: Vector2, text: String) -> void:
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.05, 0.90)
	style.border_color = Color(0.85, 0.68, 0.25, 0.90)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
	tag.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.60, 1.0))
	tag.add_child(label)
	_marker_layer.add_child(tag)
	tag.position = center - tag.get_combined_minimum_size() * 0.5


# ── Story 6.5: the dispatch scroll's text (static, DRAFT lines) ───────────────

static func party_text(n: int) -> String:
	return "Party of %d" % n


static func chance_text(chance: int, chosen: int, need: int) -> String:
	if chosen <= 0 or chance < 0:
		return "Chance of success: — (pick an adventurer)"
	if chosen < need:
		return "Chance of success: %d%% (%d of %d chosen)" % [chance, chosen, need]
	return "Chance of success: %d%%" % chance


static func need_text(need: int, ready: int) -> String:
	if ready >= need:
		return ""
	return "Needs %d ready adventurer%s. You have %d." % [need, "" if need == 1 else "s", ready]


static func token_status_text(status: int, recovery: int, return_day: int) -> String:
	match status:
		AdventurerStatus.Status.ON_MISSION:
			return "Out, back day %d" % return_day if return_day >= 0 else "Out on a contract"
		AdventurerStatus.Status.RESTING:
			return "Resting, %d day%s" % [recovery, "" if recovery == 1 else "s"]
		AdventurerStatus.Status.WOUNDED:
			return "Wounded, %d day%s" % [recovery, "" if recovery == 1 else "s"]
		AdventurerStatus.Status.DEAD:
			return "Fallen"
	return ""


static func chip_text(names: Array, return_day: int) -> String:
	var who := "Out"
	if names.size() == 1:
		who = str(names[0])
	elif names.size() > 1:
		who = "%s +%d" % [names[0], names.size() - 1]
	return who if return_day < 0 else "%s · back day %d" % [who, return_day]


static func out_text(names: Array, return_day: int) -> String:
	if names.is_empty():
		return "Someone is out on this contract."
	var who := ", ".join(names)
	return "Out: %s" % who if return_day < 0 else "Out: %s (back day %d)" % [who, return_day]


static func deployed_text(names: Array, chance: int, return_day: int) -> String:
	if names.is_empty():
		return "Someone is out on this contract."
	var lines: Array = ["Out on this contract: %s." % ", ".join(names)]
	if chance >= 0:
		lines.append("They left with a %d%% chance." % chance)
	if return_day >= 0:
		lines.append("Back on day %d." % return_day)
	return "\n".join(lines)


## The stats the success formula reads that this mission uses (its other success_factors add nothing yet).
static func stat_names(mission: Dictionary) -> Array:
	var out: Array = []
	var factors = mission.get("success_factors", ["strength"])
	if factors is Array:
		for f in factors:
			var shown := str(f).capitalize()
			if FOUR_STATS.has(str(f)) and not out.has(shown):
				out.append(shown)
	return out


## DD-6: the READY ids whose chance is among the best `n` and at least `min_chance` (ties at the cut included).
static func strong_fits(estimates: Dictionary, n: int, min_chance: int) -> Array:
	if estimates.is_empty() or n <= 0:
		return []
	var values: Array = estimates.values().map(func(v): return int(v))
	values.sort()
	values.reverse()
	var cut := maxi(int(values[mini(n, values.size()) - 1]), min_chance)
	var ids: Array = estimates.keys().filter(func(k): return int(estimates[k]) >= cut)
	ids.sort_custom(func(a, b): return int(estimates[a]) > int(estimates[b]))
	return ids


static func strong_fit_min(value) -> int:
	if (value is int or value is float) and value >= 0 and value <= 100:
		return int(value)
	return STRONG_FIT_DEFAULT


## Tokens: READY first, best chance first (ties keep roster order), then the others in roster order.
## rows: [{id, ready, chance, ...}].
static func sort_tokens(rows: Array) -> Array:
	var ready: Array = []
	var others: Array = []
	for i in rows.size():
		if rows[i].get("ready", false):
			ready.append([rows[i], i])
		else:
			others.append(rows[i])
	ready.sort_custom(func(a, b): return int(a[0].chance) > int(b[0].chance) or (int(a[0].chance) == int(b[0].chance) and a[1] < b[1]))
	return ready.map(func(p): return p[0]) + others


static func _same_id(a, b) -> bool:
	return typeof(a) == typeof(b) and a == b


# ── The dispatch scroll (Story 6.5) ───────────────────────────────────────────

func _open_detail_panel(rec: Dictionary) -> void:
	_close_detail_panel()  # ensure only one scroll at a time
	_hide_preview()

	var mission = rec.get("active_mission", null)
	if not (mission is Dictionary):
		return
	_panel_mission = mission
	_panel_rec = rec  # the World Map record (its id is the dispatch's hex)
	if GameManager.is_hex_taken(rec):
		_open_deployed_scroll(rec)
		return

	_panel_n = GameManager.required_party_size(mission)
	_assigned_ids = []
	for _i in _panel_n:
		_assigned_ids.append(null)

	var vbox := _make_scroll(mission)

	_party_label = _ink_label(party_text(_panel_n), 15, INK)
	_party_label.visible = _panel_n > 1
	vbox.add_child(_party_label)

	var stats := stat_names(mission)
	_uses_label = _ink_label("Uses: " + ", ".join(stats), 13, INK_SOFT)
	_uses_label.visible = not stats.is_empty()
	vbox.add_child(_uses_label)

	_chance_label = _ink_label(chance_text(-1, 0, _panel_n), 16, INK_SOFT)
	vbox.add_child(_chance_label)

	_trait_label = _ink_label("", 13, Color(0.32, 0.18, 0.42, 1.0))
	_trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trait_label.visible = false
	vbox.add_child(_trait_label)

	vbox.add_child(HSeparator.new())

	# N places — mission_slot.gd: a token click or a roster drag fills one, a click empties it.
	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 8)
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(slots_row)
	for i in _panel_n:
		var slot := PanelContainer.new()
		slot.set_script(MISSION_SLOT_SCRIPT)
		slot.custom_minimum_size = Vector2(110.0, 44.0)
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = SCROLL_SLOT
		slot_style.border_color = SCROLL_EDGE
		slot_style.set_border_width_all(2)
		slot_style.set_corner_radius_all(4)
		slot.add_theme_stylebox_override("panel", slot_style)
		# Label created here and named so mission_slot._ready() can find it.
		var slot_lbl := Label.new()
		slot_lbl.name = "SlotLabel"
		slot_lbl.text = "Empty"
		slot_lbl.add_theme_font_size_override("font_size", 13)
		slot_lbl.add_theme_color_override("font_color", INK_SOFT)
		slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(slot_lbl)
		# Wire the slot to board state BEFORE add_child so the ref is live on _ready().
		slot.slot_index = i
		slot.assigned_ids = _assigned_ids
		slot.on_slot_changed = _on_slot_changed
		slots_row.add_child(slot)  # triggers slot._ready()
		_slots.append(slot)

	_need_label = _ink_label("", 13, INK_RED)
	vbox.add_child(_need_label)
	var ready_count := 0
	for adv in GameManager.adventurers:
		if adv is Dictionary and GameManager.not_ready_reason(adv) == "":
			ready_count += 1
	_need_label.text = need_text(_panel_n, ready_count)
	_need_label.visible = _need_label.text != ""

	vbox.add_child(_ink_label("Your adventurers", 13, INK_SOFT))
	_build_tokens(vbox)

	_reason_label = _ink_label("", 13, INK_RED)
	_reason_label.visible = false
	vbox.add_child(_reason_label)

	vbox.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	_accept_btn = Button.new()
	_accept_btn.text = "Send"
	_accept_btn.disabled = true  # enabled once all N places hold ready adventurers
	_accept_btn.pressed.connect(_on_accept_pressed)
	btn_row.add_child(_accept_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_close_detail_panel)
	btn_row.add_child(close_btn)

	_update_chance_and_accept()


## Where `hex_id`'s marker is drawn (its resting place), or (-1, -1) when it has none.
func _marker_pos(hex_id: String) -> Vector2:
	for m in _markers:
		if m is Dictionary and str(m.get("hex_id", "")) == hex_id and m.get("pos") is Vector2:
			return m.pos
	return Vector2(-1.0, -1.0)


## The full scroll flies out of its marker: it is scaled about a pivot that travels from the marker's point to its own
## middle while it grows to full width (ZOOM_SECONDS), so a tiny scroll leaves the marker and lands in the centre;
## then it unrolls from its middle (UNFURL_SECONDS). Runs the frame after it was made, when the container has placed it.
func _grow_from_marker(panel: Control, from: Vector2) -> void:
	if not is_instance_valid(panel) or panel.is_queued_for_deletion() or panel.has_meta("closing"):
		return
	var origin := (panel.get_parent() as Control).global_position + panel.position
	var middle := panel.size * 0.5
	panel.pivot_offset = from - origin
	panel.scale = Vector2(0.06, 0.06)   # again: placing it (Container.fit_child_in_rect) put its scale back to 1
	var tw := panel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "scale", Vector2(1.0, 0.12), ZOOM_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(panel, "pivot_offset", middle, ZOOM_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(panel, "modulate:a", 1.0, ZOOM_SECONDS * 0.4)
	tw.chain().tween_property(panel, "scale:y", 1.0, UNFURL_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	panel.set_meta("open_tween", tw)


## Closing: the scroll rolls up to its middle, then flies back into its marker and fades (CLOSE_SECONDS); nothing in it
## takes a click or a key meanwhile, and it is freed at the end. With no marker, or never shown, it goes at once.
func _roll_back(wrapper: Control, to: Vector2) -> void:
	var panel := wrapper.get_node_or_null("Scroll") as Control
	if panel == null or to.x < 0.0 or not is_inside_tree() or panel.modulate.a <= 0.01:
		wrapper.queue_free()
		return
	panel.set_meta("closing", true)
	var open_tw = panel.get_meta("open_tween", null)
	if open_tw is Tween and (open_tw as Tween).is_valid():
		(open_tw as Tween).kill()
	if panel.scale.is_equal_approx(Vector2.ONE):
		panel.pivot_offset = panel.size * 0.5   # its size may have changed while open; at full scale this moves nothing
	for c in wrapper.find_children("*", "Control", true, false):
		var ctl := c as Control
		ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctl.focus_mode = Control.FOCUS_NONE
		if ctl is BaseButton:
			(ctl as BaseButton).disabled = true
	var origin := wrapper.global_position + panel.position
	var tw := wrapper.create_tween()
	tw.tween_property(panel, "scale:y", 0.12, CLOSE_SECONDS * 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(true)
	tw.chain().tween_property(panel, "scale", Vector2(0.06, 0.06), CLOSE_SECONDS * 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(panel, "pivot_offset", to - origin, CLOSE_SECONDS * 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(panel, "modulate:a", 0.0, CLOSE_SECONDS * 0.55)
	tw.chain().tween_callback(wrapper.queue_free)


## The parchment scroll (placeholder_scroll, DD-9): name, danger, duration, reward. Since 2026-11-08 it grows out of its
## contract's marker (_grow_from_marker) and rolls back into it on close (_roll_back); with no marker it unfurls in place.
func _make_scroll(mission: Dictionary) -> VBoxContainer:
	var wrapper := CenterContainer.new()
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrapper)
	_detail_panel = wrapper

	var panel := PanelContainer.new()
	panel.name = "Scroll"
	panel.custom_minimum_size = Vector2(620.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = SCROLL_PAPER
	style.border_color = SCROLL_EDGE
	style.set_border_width_all(3)
	style.border_width_top = 12      # the rolled ends
	style.border_width_bottom = 12
	style.set_corner_radius_all(4)
	style.set_content_margin_all(20.0)
	panel.add_theme_stylebox_override("panel", style)
	wrapper.add_child(panel)
	var from := _marker_pos(str(_panel_rec.get("id", "")))
	if from.x < 0.0 or not is_inside_tree():
		panel.scale = Vector2(1.0, 0.05)
		var unfurl := panel.create_tween()   # bound to the panel: freed with it if the scroll closes mid-roll
		unfurl.tween_property(panel, "scale:y", 1.0, UNFURL_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		# The CenterContainer places the panel at the end of this frame: from the next one, it grows out of the marker.
		panel.scale = Vector2(0.06, 0.06)
		panel.modulate.a = 0.0
		get_tree().process_frame.connect(_grow_from_marker.bind(panel, from), CONNECT_ONE_SHOT)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var name_lbl := _ink_label(str(mission.get("name", "Unknown Mission")), 22, INK)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)
	vbox.add_child(HSeparator.new())

	var danger: int = int(mission.get("danger", 1))
	vbox.add_child(_ink_label("Danger:  " + _danger_text(danger), 15, _danger_ink(danger)))
	var duration: int = int(mission.get("duration_days", 1))
	vbox.add_child(_ink_label("Duration:  %d %s" % [duration, "day" if duration == 1 else "days"], 14, INK_SOFT))
	var reward = mission.get("reward_range", [0, 0])
	if reward is Array and reward.size() >= 2:
		vbox.add_child(_ink_label("Reward:  %d–%d gold" % [int(reward[0]), int(reward[1])], 14, INK_GOLD))
	return vbox


func _ink_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _build_tokens(parent: Container) -> void:
	var rows: Array = []
	var estimates := {}
	for adv in GameManager.adventurers:
		if not (adv is Dictionary):
			continue
		var id = adv.get("id", adv.get("name"))
		var ready: bool = GameManager.not_ready_reason(adv) == ""
		var chance: int = GameManager.estimate_success([adv], _panel_mission)
		rows.append({"id": id, "ready": ready, "chance": chance, "adv": adv})
		if ready:
			estimates[id] = chance
	rows = sort_tokens(rows)
	_good_fit = strong_fits(estimates, _panel_n, strong_fit_min(DataManager.get_config("dispatch_strong_fit_min_chance", STRONG_FIT_DEFAULT)))

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	parent.add_child(flow)
	for row in rows:
		_token_order.append(row.id)
		flow.add_child(_make_token(row))


func _make_token(row: Dictionary) -> Button:
	var adv: Dictionary = row.adv
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(186.0, 62.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_token_pressed.bind(row.id))

	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 4.0
	box.offset_right = -4.0
	box.add_theme_constant_override("separation", 6)
	btn.add_child(box)

	var pic := TextureRect.new()
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.texture = PortraitSocket.resolve_texture(adv)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(40.0, 54.0)
	box.add_child(pic)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # the status line wraps inside the token, not past it
	box.add_child(col)

	var light := Color(0.95, 0.90, 0.80, 1.0)
	var name_lbl := _ink_label(str(adv.get("name", "?")), 14, light)
	var sub := ""
	if row.ready:
		sub = "%s · %d%%" % [str(adv.get("class", "")), int(row.chance)]
	else:
		var status: int = GameManager.status_of(adv)
		# Review P10: every token names the class; a token that can't go shows why instead of a chance.
		sub = "%s · %s" % [str(adv.get("class", "")), token_status_text(status, int(adv.get("recovery", 0)),
			GameManager.return_day_for(adv) if status == AdventurerStatus.Status.ON_MISSION else -1)]
		btn.modulate = Color(1.0, 1.0, 1.0, 0.55)
	var sub_lbl := _ink_label(sub, 12, Color(0.80, 0.76, 0.66, 1.0))
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tag_lbl := _ink_label("", 12, Color(0.55, 0.90, 0.50, 1.0))
	tag_lbl.visible = false   # shown with "Good fit" / "Assigned" (_refresh_tokens)
	for l in [name_lbl, sub_lbl, tag_lbl]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l)
	_tokens[row.id] = {"name": name_lbl, "sub": sub_lbl, "tag": tag_lbl}
	return btn


## A token's labels as one line (name | class and chance, or status | tag); for tests and logs.
func _token_text(adventurer_id) -> String:
	var t: Dictionary = _tokens.get(adventurer_id, {})
	if t.is_empty():
		return ""
	return "%s | %s | %s" % [t.name.text, t.sub.text, t.tag.text]


func _refresh_tokens() -> void:
	for id in _tokens:
		var tag: Label = _tokens[id].tag
		if _slot_index_of(id) >= 0:
			tag.text = "Assigned"
		elif _good_fit.has(id):
			tag.text = "Good fit"
		else:
			tag.text = ""
		tag.visible = tag.text != ""


func _slot_index_of(adventurer_id) -> int:
	for i in _assigned_ids.size():
		if _assigned_ids[i] != null and _same_id(_assigned_ids[i], adventurer_id):
			return i
	return -1


func _show_reason(text: String) -> void:
	if is_instance_valid(_reason_label):
		_reason_label.text = text
		_reason_label.visible = text != ""


## A click on a token: a READY adventurer takes the first empty place; anyone else is refused with the reason, and the
## places stay as they were (AC 6). A click on someone already placed does nothing (review P5: a double-click mustn't
## undo the pick); a click on the place empties it.
func _on_token_pressed(adventurer_id) -> void:
	if _panel_read_only or _detail_panel == null:
		return
	var adv: Dictionary = GameManager.find_adventurer(adventurer_id)
	var why: String = GameManager.not_ready_reason(adv) if not adv.is_empty() else "That adventurer isn't in the guild."
	if why != "":
		_show_reason(why)
		return
	if _slot_index_of(adventurer_id) >= 0:
		return
	for slot in _slots:
		if slot.is_empty():
			if slot.fill(adventurer_id):
				_show_reason("")
			return
	_show_reason("Every place is taken. Click a place to empty it.")


func _open_deployed_scroll(rec: Dictionary) -> void:
	_panel_read_only = true
	var vbox := _make_scroll(_panel_mission)
	var info: Dictionary = GameManager.deployment_info(str(rec.get("id", "")))
	_readonly_label = _ink_label(deployed_text(info.get("names", []), int(info.get("chance", -1)), int(info.get("return_day", -1))), 15, INK)
	_readonly_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_readonly_label)
	vbox.add_child(HSeparator.new())
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_close_detail_panel)
	btn_row.add_child(close_btn)


func _close_detail_panel() -> void:
	if _detail_panel != null and is_instance_valid(_detail_panel):
		_roll_back(_detail_panel, _marker_pos(str(_panel_rec.get("id", ""))))   # rolls back into its marker, then goes
		_closed_frame = Engine.get_process_frames()
	_detail_panel = null
	_panel_mission = {}
	_panel_rec = {}
	_panel_n = 0
	_panel_read_only = false
	_assigned_ids = []
	_slots = []
	_token_order = []
	_tokens = {}
	_good_fit = []
	_chance_label = null
	_accept_btn = null
	_party_label = null
	_uses_label = null
	_trait_label = null
	_need_label = null
	_reason_label = null
	_readonly_label = null


# ── Slot callbacks ────────────────────────────────────────────────────────────

func _on_slot_changed() -> void:
	_update_chance_and_accept()


func _update_chance_and_accept() -> void:
	if _panel_read_only or not is_instance_valid(_chance_label) or not is_instance_valid(_accept_btn):
		return

	var party: Array = []
	for id in _assigned_ids:
		if id != null:
			var adv: Dictionary = GameManager.find_adventurer(id)
			if not adv.is_empty():
				party.append(adv)
	var all_ready := party.all(func(a): return GameManager.not_ready_reason(a) == "")
	_accept_btn.disabled = not (party.size() == _panel_n and all_ready)

	# The one estimate (DD-2): what is shown here is what dispatch stores and the resolver rolls.
	var chance: int = GameManager.estimate_success(party, _panel_mission) if not party.is_empty() else -1
	_chance_label.text = chance_text(chance, party.size(), _panel_n)
	var c := INK_SOFT
	if chance >= 70:
		c = INK_GREEN
	elif chance >= 50:
		c = INK_GOLD
	elif chance >= 0:
		c = INK_RED
	_chance_label.add_theme_color_override("font_color", c)

	var traits: Array = []
	for a in party:
		var t: Dictionary = GameManager.trait_info(a)
		if not t.is_empty():
			traits.append("%s — %s: %s" % [str(a.get("name", "?")), t.name, t.description])
	_trait_label.text = "\n".join(traits)
	_trait_label.visible = not traits.is_empty()
	_refresh_tokens()


func _on_accept_pressed() -> void:
	if _panel_read_only or _detail_panel == null:
		return
	var ids: Array = _assigned_ids.filter(func(x): return x != null)
	var why: String = GameManager.dispatch_adventurers(ids, _panel_mission, str(_panel_rec.get("id", "")))
	if why != "":
		_show_reason(why)
		_update_chance_and_accept()
		return
	# GameManager locked the hex and stored the record; redraw so the marker shows who went.
	_close_detail_panel()
	_build_markers()
