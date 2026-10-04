extends RefCounted
## The screen's edge pass (assets/shaders/edge_detection.gdshader on a quad under the camera): on or off from
## game_config.json "edge_pass" (true when absent). MainTavern (TavernLighting) and ExteriorWorld apply it at load;
## TavernLighting's dev key 4 toggles it live. The scenes keep their quads as saved: only the runtime hides them.

const GAME_CONFIG_PATH := "res://data/config/game_config.json"
const EDGE_SHADER_PATH := "res://assets/shaders/edge_detection.gdshader"


## game_config.json's "edge_pass" (true when the file or the key is missing).
static func enabled() -> bool:
	if not FileAccess.file_exists(GAME_CONFIG_PATH):
		return true
	var cfg = JSON.parse_string(FileAccess.get_file_as_string(GAME_CONFIG_PATH))
	if cfg is Dictionary and cfg.has("edge_pass"):
		return bool(cfg["edge_pass"])
	return true


## The edge pass quads under a camera (MeshInstance3D children drawn with the edge shader).
static func quads(cam: Node) -> Array:
	var out := []
	if cam == null:
		return out
	for c in cam.get_children():
		if not c is MeshInstance3D:
			continue
		var mi := c as MeshInstance3D
		var m: Material = mi.material_override if mi.material_override else mi.get_surface_override_material(0)
		if m is ShaderMaterial and (m as ShaderMaterial).shader and (m as ShaderMaterial).shader.resource_path == EDGE_SHADER_PATH:
			out.append(mi)
	return out


## Show or hide a camera's edge pass by the config; returns how many quads it set.
static func apply(cam: Node, on: Variant = null) -> int:
	var show: bool = enabled() if on == null else bool(on)
	var qs := quads(cam)
	for q in qs:
		(q as MeshInstance3D).visible = show
	return qs.size()
