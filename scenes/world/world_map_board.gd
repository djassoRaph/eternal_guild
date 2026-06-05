# world_map_board.gd
# Overlay that renders the stored world map statically when the player presses
# E at the mission area. Closes on ESC.
extends Control

signal board_closed

const HEX_MAP_SCENE := preload("res://scenes/HexMapTest.tscn")


func _ready() -> void:
	add_to_group("mission_board")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var svc := SubViewportContainer.new()
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(svc)

	var sv := SubViewport.new()
	sv.size = Vector2i(1920, 1080)
	sv.handle_input_locally = false
	# Change A: own_world_3d=true gives the hex scene its own World3D so its Camera3D
	# auto-promotes to current instead of competing with the tavern's player camera.
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(sv)

	var hex_map := HEX_MAP_SCENE.instantiate()
	hex_map.display_mode = true
	# Hide MapControls (Back / Regenerate / dialog) — display mode is view-only.
	var controls := hex_map.get_node_or_null("CanvasLayer")
	if controls:
		controls.visible = false
	sv.add_child(hex_map)

	# Change B: override the camera for a long-lens diorama look.
	# HexMapTest.tscn is shared with the new-game reveal, so we override at runtime
	# rather than editing the .tscn, leaving the reveal camera untouched.
	# FOV 30° (long lens), 28° below horizontal, pulled back to ~45 units from map center.
	var cam := hex_map.get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 30.0
		# Transform: same 45° azimuth, position (28,22,28) → looks at origin at ~29° below horizontal.
		# Constructor order: (x.x, y.x, z.x, x.y, y.y, z.y, x.z, y.z, z.z, ox, oy, oz)
		cam.position = Vector3(28.0, 22.0, 28.0)
		cam.look_at(Vector3.ZERO, Vector3.UP)

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


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	board_closed.emit()
	queue_free()


func open_mission_board() -> void:
	visible = true
