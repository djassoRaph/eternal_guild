extends RefCounted
## The screen's edge pass (assets/shaders/edge_detection.gdshader on a quad under the camera): on or off from
## game_config.json "edge_pass" (true when absent). MainTavern (TavernLighting) and ExteriorWorld apply it at load;
## TavernLighting's dev key 4 toggles it live. The scenes keep their quads as saved: only the runtime hides them.

const GAME_CONFIG_PATH := "res://data/config/game_config.json"
const EDGE_SHADER_PATH := "res://assets/shaders/edge_detection.gdshader"
## Every file that draws the edge pass: Raphael's copy at the project root has been MainTavern's quad since
## 2026-10-08, so a quad on either one is the edge pass (else "edge_pass": false and dev key 4 miss the hall's).
const EDGE_SHADER_PATHS := [EDGE_SHADER_PATH, "res://edge_detection-old.gdshader"]


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
		if is_edge_material(m):
			out.append(mi)
	return out


## True when a material draws the edge pass (a ShaderMaterial on one of EDGE_SHADER_PATHS).
static func is_edge_material(m: Material) -> bool:
	return m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.resource_path in EDGE_SHADER_PATHS


## Show or hide a camera's edge pass by the config; returns how many quads it set.
static func apply(cam: Node, on: Variant = null) -> int:
	var show: bool = enabled() if on == null else bool(on)
	var qs := quads(cam)
	for q in qs:
		(q as MeshInstance3D).visible = show
	return qs.size()
