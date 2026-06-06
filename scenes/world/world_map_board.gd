extends Control

signal board_closed

const HEX_MAP_SCENE := preload("res://scenes/HexMapTest.tscn")

# If ۩ (U+06E9) renders as a tofu box, change this one constant to "✦" or any glyph you prefer.
const RUNE := "۩"

var _sv: SubViewport
var _svc: SubViewportContainer
var _cam: Camera3D

var _bubble: PanelContainer
var _bubble_biome: Label
var _bubble_mission: Label
var _bubble_danger: Label

var _marker_layer: Control
var _marker_tweens: Array = []

var _detail_panel: Control = null


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
		_cam.fov = 30.0
		_cam.position = Vector3(28.0, 22.0, 28.0)
		_cam.look_at(Vector3.ZERO, Vector3.UP)

	# Marker layer sits above the SubViewport but below the hover bubble.
	_marker_layer = Control.new()
	_marker_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marker_layer)

	_build_bubble()

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


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseMotion:
		_handle_hover(event.position)

	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		# While the detail panel is open let the panel's own buttons handle clicks.
		if _detail_panel == null:
			var rec := _record_at_screen(event.position)
			if not rec.is_empty() and rec.get("active_mission", null) != null:
				_open_detail_panel(rec)
				get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_cancel"):
		# ESC priority: close panel first; only close the board when no panel is open.
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
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 200.0)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return {}
	var area: Object = result["collider"]
	if not area.has_meta("hex_id"):
		return {}
	var hex_id: String = area.get_meta("hex_id")
	for rec in WorldManager.world_map:
		if rec["id"] == hex_id:
			return rec
	return {}


func _handle_hover(mouse_pos: Vector2) -> void:
	# No hover bubble while the detail panel is showing.
	if _detail_panel != null:
		_hide_bubble()
		return
	var rec := _record_at_screen(mouse_pos)
	if rec.is_empty():
		_hide_bubble()
		return
	# Stage 1 confirmation print — left in intentionally until bubble is verified
	print("[hover] ", rec["id"], " biome=", rec["biome"], " mission=", rec.get("active_mission", null))
	_show_bubble(rec, mouse_pos)


func _show_bubble(rec: Dictionary, mouse_pos: Vector2) -> void:
	_bubble_biome.text = _biome_line(rec.get("biome", ""))

	var mission = rec.get("active_mission", null)
	if mission != null:
		_bubble_mission.text = "Work available: " + mission.get("name", "Unknown")
		_bubble_mission.visible = true
		var danger: int = mission.get("danger", 1)
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


func _biome_line(biome: String) -> String:
	match biome:
		"grass":       return "Open grassland. Quiet, for now."
		"forest":      return "Dense woods. Beasts roam the deep paths."
		"mountain":    return "Jagged peaks. Old stone, old dangers."
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


func _close() -> void:
	_close_detail_panel()
	_clear_markers()
	if GameManager.missions_changed.is_connected(_on_missions_changed):
		GameManager.missions_changed.disconnect(_on_missions_changed)
	board_closed.emit()
	queue_free()


func open_mission_board() -> void:
	visible = true
	GameManager.missions_changed.connect(_on_missions_changed)
	call_deferred("_build_markers")


# ── Hex mission markers ───────────────────────────────────────────────────────

func _on_missions_changed() -> void:
	if visible:
		_build_markers()


func _clear_markers() -> void:
	for tw in _marker_tweens:
		if is_instance_valid(tw):
			tw.kill()
	_marker_tweens.clear()
	for child in _marker_layer.get_children():
		child.free()


func _build_markers() -> void:
	_clear_markers()

	if _cam == null or _sv == null or _svc == null:
		return

	var svc_rect := _svc.get_global_rect()
	if svc_rect.size.x < 1.0:
		return  # layout not yet settled; open_mission_board defers so this rarely fires

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

		_spawn_marker(screen_pos)


func _spawn_marker(screen_pos: Vector2) -> void:
	var marker := Control.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.position = screen_pos
	_marker_layer.add_child(marker)

	# Glow ring: warm, dim — centered behind rune. (Part 0: 48 pt, offset -24)
	var glow := Label.new()
	glow.text = RUNE
	glow.add_theme_font_size_override("font_size", 48)
	glow.add_theme_color_override("font_color", Color(1.0, 0.65, 0.15, 0.55))
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.position = Vector2(-24.0, -24.0)
	marker.add_child(glow)

	# Stroke layer: four 1-px offset copies in dark amber — fakes a bold outline.
	for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		var stroke := Label.new()
		stroke.text = RUNE
		stroke.add_theme_font_size_override("font_size", 32)
		stroke.add_theme_color_override("font_color", Color(0.55, 0.30, 0.0, 0.90))
		stroke.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stroke.position = Vector2(-16.0, -16.0) + off
		marker.add_child(stroke)

	# Rune: bright gold on top. (Part 0: Color green channel 0.9 → 0.92)
	var rune := Label.new()
	rune.text = RUNE
	rune.add_theme_font_size_override("font_size", 32)
	rune.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5, 1.0))
	rune.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rune.position = Vector2(-16.0, -16.0)
	marker.add_child(rune)

	# Pulse: breathe between 40% and 100% opacity on a sine curve, loop forever.
	marker.modulate.a = 0.65
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(marker, "modulate:a", 1.0, 1.4) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(marker, "modulate:a", 0.4, 1.4) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_marker_tweens.append(tw)


# ── Mission detail panel (C1: read-only display, no drag, no commit) ──────────

func _open_detail_panel(rec: Dictionary) -> void:
	_close_detail_panel()  # ensure only one panel at a time

	var mission: Dictionary = rec["active_mission"]

	# CenterContainer: full-rect transparent wrapper — auto-centers the panel.
	var wrapper := CenterContainer.new()
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrapper)
	_detail_panel = wrapper

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.07, 0.97)
	style.border_color = Color(0.80, 0.60, 0.20, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	wrapper.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Mission name
	var name_lbl := Label.new()
	name_lbl.text = mission.get("name", "Unknown Mission")
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.50, 1.0))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	vbox.add_child(HSeparator.new())

	# Danger
	var danger: int = mission.get("danger", 1)
	var danger_lbl := Label.new()
	danger_lbl.text = "Danger:  " + _danger_text(danger)
	danger_lbl.add_theme_font_size_override("font_size", 15)
	danger_lbl.add_theme_color_override("font_color", _danger_color(danger))
	vbox.add_child(danger_lbl)

	# Duration
	var duration: int = mission.get("duration_days", 1)
	var dur_lbl := Label.new()
	dur_lbl.text = "Duration:  " + str(duration) + (" day" if duration == 1 else " days")
	dur_lbl.add_theme_font_size_override("font_size", 14)
	dur_lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80, 1.0))
	vbox.add_child(dur_lbl)

	# Reward
	var lo: int = mission.get("reward_range", [0, 0])[0]
	var hi: int = mission.get("reward_range", [0, 0])[1]
	var reward_lbl := Label.new()
	reward_lbl.text = "Reward:  " + str(lo) + "–" + str(hi) + " gold"
	reward_lbl.add_theme_font_size_override("font_size", 14)
	reward_lbl.add_theme_color_override("font_color", Color(0.90, 0.80, 0.30, 1.0))
	vbox.add_child(reward_lbl)

	# Success chance — placeholder; real value arrives in C2 once adventurers are assigned
	var chance_lbl := Label.new()
	chance_lbl.text = "Success:  — (assign adventurers)"
	chance_lbl.add_theme_font_size_override("font_size", 14)
	chance_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1.0))
	vbox.add_child(chance_lbl)

	vbox.add_child(HSeparator.new())

	# Slot count — derive from party_required (bool or int)
	var party_raw = mission.get("party_required", false)
	var n: int
	if party_raw is bool:
		n = 2 if party_raw else 1
	else:
		n = maxi(1, int(party_raw))

	var slots_hdr := Label.new()
	slots_hdr.text = "Adventurers required:  " + str(n)
	slots_hdr.add_theme_font_size_override("font_size", 14)
	slots_hdr.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1.0))
	vbox.add_child(slots_hdr)

	# N empty bordered boxes — visual placeholders; become drop-targets in C2
	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 8)
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(slots_row)

	for _i in n:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(80.0, 100.0)
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.14, 0.11, 0.09, 1.0)
		slot_style.border_color = Color(0.45, 0.40, 0.28, 0.85)
		slot_style.set_border_width_all(2)
		slot_style.set_corner_radius_all(4)
		slot.add_theme_stylebox_override("panel", slot_style)
		var slot_lbl := Label.new()
		slot_lbl.text = "Empty"
		slot_lbl.add_theme_font_size_override("font_size", 12)
		slot_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45, 1.0))
		slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.add_child(slot_lbl)
		slots_row.add_child(slot)

	vbox.add_child(HSeparator.new())

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.add_theme_color_override("font_color", Color(0.85, 0.35, 0.30, 1.0))
	close_btn.pressed.connect(_close_detail_panel)
	vbox.add_child(close_btn)


func _close_detail_panel() -> void:
	if _detail_panel != null and is_instance_valid(_detail_panel):
		_detail_panel.queue_free()
	_detail_panel = null
