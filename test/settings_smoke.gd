extends SceneTree
## Headless smoke test for the settings build + movement-integrity regression check.
## Cleans up settings.cfg so it never pollutes real user data.
var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	print("=== SETTINGS SMOKE ===")
	print("Bus Master=%s Music=%s SFX=%s" % [
		AudioServer.get_bus_index("Master") != -1,
		AudioServer.get_bus_index("Music") != -1,
		AudioServer.get_bus_index("SFX") != -1,
	])

	var sm = root.get_node_or_null("SettingsManager")
	print("SettingsManager autoload=%s" % (sm != null))

	# --- MOVEMENT INTEGRITY (regression): dual bindings survive when nothing is rebound ---
	print("move_forward events=%s (want 2)" % InputMap.action_get_events("move_forward").size())
	print("move_right events=%s (want 2)" % InputMap.action_get_events("move_right").size())
	if sm:
		print("move_forward label=%s (want a letter, NOT Up)" % sm.get_action_key_label("move_forward"))
		print("move_left label=%s (want a letter, NOT Left)" % sm.get_action_key_label("move_left"))

	var script = load("res://scripts/menus/settings_menu.gd")
	print("settings_menu.gd loaded=%s" % (script != null))

	if sm and script:
		# explicit rebind of ONE action must not disturb or persist others
		var ev = InputEventKey.new()
		ev.physical_keycode = KEY_K
		sm.rebind_action("interact", ev)
		sm.save_settings()
		var cfg = ConfigFile.new()
		cfg.load("user://settings.cfg")
		print("cfg wrote interact=%s move_forward=%s (want true/false)" % [
			cfg.has_section_key("input", "interact"),
			cfg.has_section_key("input", "move_forward"),
		])
		print("move_forward still 2 after rebind+save=%s" % (InputMap.action_get_events("move_forward").size() == 2))
		sm.reset_keybinds()
		print("interact after reset=%s (want E)" % sm.get_action_key_label("interact"))

		var menu = script.new()
		root.add_child(menu)
		print("SettingsMenu instantiated+ready=%s" % is_instance_valid(menu))
		menu.queue_free()

	# cleanup — never leave a settings.cfg artifact behind
	if FileAccess.file_exists("user://settings.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	print("=== SMOKE DONE ===")
	quit()
	return true
