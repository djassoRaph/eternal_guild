# look_dev.gd
# Stage D quick check for new assets (Epic 25 / Story 25.1).
# Reproduces the tavern render path (half-res SubViewport, orthographic isometric camera,
# edge-detection quad, tavern lights) around a Subject slot. Standalone: no autoload
# lookups, and the root is NOT in the "player_scene" group, so PlayerManager stands down.
extends Node3D

## Scene to inspect (e.g. an exported res://assets/environment/custom/<id>.gltf).
@export var subject_scene: PackedScene
## "tavern" = MainTavern camera + lights; "map" = HexMapTest camera + sun.
@export_enum("tavern", "map") var camera_preset: String = "tavern"
## Orthographic size for the map preset (HexMapTest uses 40; ~8 frames a single hex).
@export var map_ortho_size: float = 40.0
## Degrees per second; 0 = static.
@export var subject_rotation_speed: float = 0.0

# Basis shared by MainTavern's and HexMapTest's Camera3D. The in-game camera
# (camera_3d.gd) keeps this basis and only moves, so it is copied exactly.
const CAMERA_BASIS := Basis(
	Vector3(0.707107, 0.0, -0.707107),
	Vector3(-0.353553, 0.866026, -0.353553),
	Vector3(0.612373, 0.5, 0.612373))
const TAVERN_ORTHO_SIZE := 12.0
const CAMERA_DISTANCE := 14.0  # along the view axis; orthographic, so only clipping cares
# Save guard: SaveSystem's autosave timer runs in every scene (game_config.json
# "autosave_interval_seconds" = 300) and would overwrite the real save file with this
# scene's blank GameManager state. LookDev quits itself before that can happen.
const AUTO_QUIT_SECONDS := 240.0
# Map toppers sit on a real KayKit hex (top face at y = 0) in the map preset.
const HEX_BASE := "res://assets/environment/hexagons/base/hex_grass.gltf"
const TAVERN_LIGHTING := preload("res://scripts/game/tavern_lighting.gd")

@onready var _camera: Camera3D = %Camera3D
@onready var _subject_root: Node3D = %Subject
@onready var _floor: MeshInstance3D = %Floor
@onready var _tavern_lights: Array[Node3D] = [%OutdoorsLight, %WarmFill, %CoolFill]
@onready var _map_sun: DirectionalLight3D = %MapSun
@onready var _info: Label = %Info


func _ready() -> void:
	_apply_preset()
	var subject_name := "(none)"
	if camera_preset == "map":
		_subject_root.add_child(load(HEX_BASE).instantiate())
	if subject_scene:
		_subject_root.add_child(subject_scene.instantiate())
		subject_name = subject_scene.resource_path.get_file()
	var renderer := RenderingServer.get_current_rendering_method()
	print("[LookDev] renderer: %s" % renderer)
	print("[LookDev] preset: %s | subject: %s" % [camera_preset, subject_name])
	_info.text = "renderer: %s | preset: %s (ortho %.0f) | subject: %s | auto-quits in %d s (save guard)" % [
		renderer, camera_preset, _camera.size, subject_name, int(AUTO_QUIT_SECONDS)]
	get_tree().create_timer(AUTO_QUIT_SECONDS).timeout.connect(_on_save_guard_timeout)


func _process(delta: float) -> void:
	if subject_rotation_speed != 0.0:
		_subject_root.rotate_y(deg_to_rad(subject_rotation_speed) * delta)


func _on_save_guard_timeout() -> void:
	print("[LookDev] quit: save guard (%d s, before SaveSystem autosave)" % int(AUTO_QUIT_SECONDS))
	get_tree().quit()


func _apply_preset() -> void:
	var is_map := camera_preset == "map"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = map_ortho_size if is_map else TAVERN_ORTHO_SIZE
	var target := _subject_root.global_position
	_camera.global_transform = Transform3D(CAMERA_BASIS, target + CAMERA_BASIS.z * CAMERA_DISTANCE)
	for light in _tavern_lights:
		light.visible = not is_map
	_map_sun.visible = is_map
	_floor.visible = not is_map  # the hex top sits at y = 0, same as the floor plane
	if not is_map:
		_follow_hall_mood()


## LM-12 (Story 25.23): the "tavern" preset follows the hall's configured mood (game_config.json › tavern_light_mood)
## through TavernLighting's static helpers, so a quick check doesn't lie about the hall: the ambient, whether the sun
## lights the scene (else it only inks: the EdgeQuad moves to layer 20 with it, as in MainTavern), the cool fill, and
## the warm fill standing in for the hearth (x the mood's hearth_scale). "today" (the default) changes nothing.
func _follow_hall_mood(mood := "") -> void:
	if mood == "":
		mood = TAVERN_LIGHTING.reload_config()
	if mood == TAVERN_LIGHTING.TODAY:
		return
	var v: Dictionary = TAVERN_LIGHTING.mood_params(mood)
	var env := ($SubViewportContainer/SubViewport/WorldEnvironment as WorldEnvironment).environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = v.ambient_color
	env.ambient_light_energy = float(v.ambient_energy)
	env.tonemap_exposure = float(v.exposure)
	if not v.sun_lights_hall:
		(_camera.get_node("EdgeQuad") as VisualInstance3D).layers = TAVERN_LIGHTING.INK_LAYER_MASK
		(%OutdoorsLight as DirectionalLight3D).light_cull_mask = TAVERN_LIGHTING.INK_LAYER_MASK
	(%CoolFill as OmniLight3D).light_energy = float(v.fill_energy)
	(%WarmFill as OmniLight3D).light_energy = 1.5 * float(v.hearth_scale)
	print("[LookDev] the tavern light follows the hall's mood: %s" % mood)
