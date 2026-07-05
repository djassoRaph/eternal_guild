extends Node
## SettingsManager (autoload) — loads/saves user settings and applies them.
## Persists to user://settings.cfg: audio bus volumes, fullscreen, and key rebindings.

const SETTINGS_PATH := "user://settings.cfg"

const DEFAULT_VOLUMES := {"Master": 1.0, "Music": 1.0, "SFX": 1.0}  # linear 0.0–1.0
const DEFAULT_FULLSCREEN := false

## Player-rebindable actions (engine ui_* actions are intentionally excluded)
const REBINDABLE_ACTIONS := ["move_forward", "move_backward", "move_left", "move_right", "jump", "interact"]

var _volumes := {"Master": 1.0, "Music": 1.0, "SFX": 1.0}
var _fullscreen := false
var _keybinds := {}          # action -> physical_keycode (loaded from settings.cfg)
var _default_events := {}    # action -> Array[InputEvent] (snapshot of project defaults)


func _ready() -> void:
	_capture_default_events()  # snapshot defaults BEFORE any override
	load_settings()
	_apply_all()


# ---------- Audio ----------
func get_bus_volume(bus_name: String) -> float:
	return _volumes.get(bus_name, 1.0)

func set_bus_volume(bus_name: String, linear: float) -> void:
	_volumes[bus_name] = clampf(linear, 0.0, 1.0)
	_apply_bus_volume(bus_name)


# ---------- Display ----------
func is_fullscreen() -> bool:
	return _fullscreen

func set_fullscreen(enabled: bool) -> void:
	_fullscreen = enabled
	_apply_fullscreen()


# ---------- Keybinds ----------
func get_rebindable_actions() -> Array:
	return REBINDABLE_ACTIONS

func get_action_key_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "—"
	var fallback := ""
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var pk: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
			var kc: int = DisplayServer.keyboard_get_keycode_from_physical(pk) if e.physical_keycode != 0 else pk
			var label: String = OS.get_keycode_string(kc if kc != 0 else pk)
			if fallback == "":
				fallback = label
			# Prefer a letter key over arrows, so WASD/ZQSD shows instead of Up/Down/Left/Right
			if pk != KEY_UP and pk != KEY_DOWN and pk != KEY_LEFT and pk != KEY_RIGHT:
				return label
	return fallback if fallback != "" else "—"

func rebind_action(action: String, event: InputEventKey) -> void:
	if not InputMap.has_action(action):
		return
	var ev := InputEventKey.new()
	ev.physical_keycode = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, ev)
	_keybinds[action] = ev.physical_keycode  # record ONLY explicit rebinds

func reset_keybinds() -> void:
	for action in _default_events:
		InputMap.action_erase_events(action)
		for e in _default_events[action]:
			InputMap.action_add_event(action, e)
	_keybinds.clear()


# ---------- Persistence ----------
func save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus_name in _volumes:
		cfg.set_value("audio", bus_name, _volumes[bus_name])
	cfg.set_value("display", "fullscreen", _fullscreen)
	# Persist ONLY keys the player explicitly rebound. Never snapshot the whole InputMap —
	# multi-key actions (WASD + arrows) would collapse to one key and break movement.
	for action in _keybinds:
		cfg.set_value("input", action, _keybinds[action])
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("SettingsManager: failed to save settings (err %d)" % err)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		_volumes = DEFAULT_VOLUMES.duplicate()
		_fullscreen = DEFAULT_FULLSCREEN
		_keybinds = {}
		return
	for bus_name in DEFAULT_VOLUMES:
		_volumes[bus_name] = float(cfg.get_value("audio", bus_name, DEFAULT_VOLUMES[bus_name]))
	_fullscreen = bool(cfg.get_value("display", "fullscreen", DEFAULT_FULLSCREEN))
	_keybinds = {}
	for action in REBINDABLE_ACTIONS:
		var pk = cfg.get_value("input", action, null)
		if pk != null:
			_keybinds[action] = int(pk)


# ---------- Apply ----------
func _apply_all() -> void:
	for bus_name in _volumes:
		_apply_bus_volume(bus_name)
	_apply_fullscreen()
	_apply_keybinds()

func _apply_bus_volume(bus_name: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return  # bus not present in the layout — skip gracefully
	var linear: float = _volumes.get(bus_name, 1.0)
	var db := linear_to_db(linear) if linear > 0.0 else -80.0
	AudioServer.set_bus_volume_db(idx, db)

func _apply_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _apply_keybinds() -> void:
	for action in _keybinds:
		if not InputMap.has_action(action):
			continue
		var ev := InputEventKey.new()
		ev.physical_keycode = _keybinds[action]
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, ev)

func _capture_default_events() -> void:
	for action in REBINDABLE_ACTIONS:
		if InputMap.has_action(action):
			_default_events[action] = InputMap.action_get_events(action).duplicate()
