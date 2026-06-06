extends Control

signal board_closed

const HEX_MAP_SCENE := preload("res://scenes/HexMapTest.tscn")

var _sv: SubViewport
var _svc: SubViewportContainer
var _cam: Camera3D

var _bubble: PanelContainer
var _bubble_biome: Label
var _bubble_mission: Label
var _bubble_danger: Label


func _ready() -> void:
	add_to_group("mission_board")
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
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _handle_hover(mouse_pos: Vector2) -> void:
	if _sv == null or _cam == null:
		return

	var svc_rect := _svc.get_global_rect()
	if not svc_rect.has_point(mouse_pos):
		_hide_bubble()
		return

	# Map screen pixel → SubViewport pixel space (sv is 1920×1080 stretched to svc_rect)
	var local := mouse_pos - svc_rect.position
	var sv_pos := Vector2(
		local.x / svc_rect.size.x * float(_sv.size.x),
		local.y / svc_rect.size.y * float(_sv.size.y)
	)

	var origin    := _cam.project_ray_origin(sv_pos)
	var direction := _cam.project_ray_normal(sv_pos)

	# _cam is in the SubViewport (own_world_3d=true), so get_world_3d() returns that isolated world
	var space_state := _cam.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 200.0)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := space_state.intersect_ray(query)

	if result.is_empty():
		_hide_bubble()
		return

	var area: Object = result["collider"]
	if not area.has_meta("hex_id"):
		_hide_bubble()
		return

	var hex_id: String = area.get_meta("hex_id")
	for rec in WorldManager.world_map:
		if rec["id"] == hex_id:
			# Stage 1 confirmation print — left in intentionally until bubble is verified
			print("[hover] ", rec["id"], " biome=", rec["biome"], " mission=", rec.get("active_mission", null))
			_show_bubble(rec, mouse_pos)
			return

	_hide_bubble()


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
	board_closed.emit()
	queue_free()


func open_mission_board() -> void:
	visible = true
