# debug_panel.gd
# ============================================================
# Eternal Guild — Debug Panel
# F12 to toggle. Root node must be CanvasLayer.
# Add DebugPanel.tscn as a child of MainTavern scene.
# All UI is built in code — no editor setup needed.
# ============================================================

extends CanvasLayer

# === STATE ===
var _visible: bool = false
var _current_tab: int = 0
var _tab_names: Array = ["📊 State", "💰 Economy", "⚔️ Missions", "👥 NPCs", "💀 Failures"]
var _content_stack: Array = []
var _state_labels: Dictionary = {}

# === MAIN PANEL REF ===
var _panel: PanelContainer

# ============================================================
# INIT
# ============================================================

func _ready() -> void:
	layer = 100
	_build_ui()
	_panel.visible = false
	print("🛠️ DebugPanel ready — press F12 to toggle")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			_visible = !_visible
			_panel.visible = _visible
			if _visible and _current_tab == 0:
				_refresh_state_tab()

# ============================================================
# UI CONSTRUCTION
# ============================================================

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left   = 15
	_panel.offset_top    = 15
	_panel.offset_right  = -15
	_panel.offset_bottom = -15
	add_child(_panel)

	var root_vbox := VBoxContainer.new()
	_panel.add_child(root_vbox)

	# --- Header ---
	var header := Label.new()
	header.text = "🛠️  ETERNAL GUILD — DEBUG PANEL       [F12 closes]"
	header.add_theme_font_size_override("font_size", 14)
	root_vbox.add_child(header)
	root_vbox.add_child(HSeparator.new())

	# --- Tab bar ---
	var tab_row := HBoxContainer.new()
	root_vbox.add_child(tab_row)
	for i in range(_tab_names.size()):
		var btn := Button.new()
		btn.text = _tab_names[i]
		btn.pressed.connect(_switch_tab.bind(i))
		tab_row.add_child(btn)
	root_vbox.add_child(HSeparator.new())

	# --- Scrollable content area ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_vbox)

	# One VBoxContainer per tab — only the active one is visible
	_content_stack.clear()
	for i in range(_tab_names.size()):
		var tab := VBoxContainer.new()
		tab.visible = (i == 0)
		content_vbox.add_child(tab)
		_content_stack.append(tab)

	_build_tab_state    (_content_stack[0])
	_build_tab_economy  (_content_stack[1])
	_build_tab_missions (_content_stack[2])
	_build_tab_npcs     (_content_stack[3])
	_build_tab_failures (_content_stack[4])

func _switch_tab(index: int) -> void:
	_current_tab = index
	for i in range(_content_stack.size()):
		_content_stack[i].visible = (i == index)
	if index == 0:
		_refresh_state_tab()

# ============================================================
# TAB 0 — STATE INSPECTOR
# ============================================================

func _build_tab_state(parent: VBoxContainer) -> void:
	_h(parent, "LIVE GAME STATE")

	var keys := [
		"gold", "beer", "firewood", "fuel",
		"day", "tax_due_day",
		"adventurers_count", "active_missions_count",
		"tier_unlocked", "reputation",
		"beer_shortage_days", "total_missions_completed"
	]
	for key in keys:
		var lbl := Label.new()
		lbl.text = key + ": ..."
		lbl.add_theme_font_size_override("font_size", 12)
		parent.add_child(lbl)
		_state_labels[key] = lbl

	parent.add_child(HSeparator.new())
	_h(parent, "Roster Detail")
	var roster_lbl := Label.new()
	roster_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roster_lbl.text = "(empty)"
	parent.add_child(roster_lbl)
	_state_labels["roster_detail"] = roster_lbl

	_h(parent, "Active Missions Detail")
	var mission_lbl := Label.new()
	mission_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_lbl.text = "(none)"
	parent.add_child(mission_lbl)
	_state_labels["mission_detail"] = mission_lbl

	parent.add_child(HSeparator.new())
	_btn_full(parent, "🔄  Refresh Now", _refresh_state_tab)

func _refresh_state_tab() -> void:
	if not is_instance_valid(GameManager):
		return
	var gm := GameManager

	_sl("gold",                    str(gm.gold) + " gp")
	_sl("beer",                    str(gm.beer_stock) + " kegs")
	_sl("firewood",                str(gm.firewood_stock) + " logs")
	_sl("fuel",                    str(snappedf(gm.fireplace_fuel * 100.0, 0.1)) + "%")
	_sl("day",                     "Day " + str(gm.current_day))
	_sl("tax_due_day",             "Day " + str(gm.tax_due_day))
	_sl("adventurers_count",       str(gm.adventurers.size()) + " / " + str(gm.max_adventurers))
	_sl("active_missions_count",   str(gm.active_missions.size()) + " active")
	_sl("tier_unlocked",           "Tier " + str(gm.mission_tier_unlocked))
	_sl("reputation",              str(gm.tavern_reputation))
	_sl("beer_shortage_days",      str(gm.beer_shortage_days) + " consecutive days")
	_sl("total_missions_completed",str(gm.total_missions_completed))

	# Roster
	if gm.adventurers.is_empty():
		_state_labels["roster_detail"].text = "(no adventurers hired)"
	else:
		var lines: Array = []
		for adv in gm.adventurers:
			lines.append("• %s  [%s]  — %s" % [
				adv.get("name", "?"),
				adv.get("class", "?"),
				adv.get("status", "idle")
			])
		_state_labels["roster_detail"].text = "\n".join(lines)

	# Active missions
	if gm.active_missions.is_empty():
		_state_labels["mission_detail"].text = "(no active missions)"
	else:
		var lines: Array = []
		for entry in gm.active_missions:
			var mission_name: String = entry.mission.get("name", "Unknown")
			var days_left: int = entry.days_remaining
			if entry.get("is_party_mission", false):
				var names = ", ".join(entry.party.map(func(a): return a.get("name", "?")))
				lines.append("• [PARTY] %s — %dd remaining (%s)" % [mission_name, days_left, names])
			else:
				var adv_name: String = entry.adventurer.get("name", "?")
				lines.append("• %s → %s — %dd remaining" % [adv_name, mission_name, days_left])
		_state_labels["mission_detail"].text = "\n".join(lines)

func _sl(key: String, value: String) -> void:
	if _state_labels.has(key):
		_state_labels[key].text = key.replace("_", " ") + ":  " + value

# ============================================================
# TAB 1 — ECONOMY INJECTOR
# ============================================================

func _build_tab_economy(parent: VBoxContainer) -> void:
	_h(parent, "GOLD")
	var gold_row := HBoxContainer.new()
	parent.add_child(gold_row)
	_btn(gold_row, "+100",    func(): GameManager.add_gold(100))
	_btn(gold_row, "+500",    func(): GameManager.add_gold(500))
	_btn(gold_row, "+1000",   func(): GameManager.add_gold(1000))
	_btn(gold_row, "Bankrupt",func(): _force_gold(0))
	_btn(gold_row, "Set 50g", func(): _force_gold(50))

	_h(parent, "BEER")
	var beer_row := HBoxContainer.new()
	parent.add_child(beer_row)
	_btn(beer_row, "+5 kegs",   func(): GameManager.add_beer(5))
	_btn(beer_row, "+20 kegs",  func(): GameManager.add_beer(20))
	_btn(beer_row, "Empty",     func(): _force_beer(0))
	_btn(beer_row, "Fill (50)", func(): GameManager.add_beer(50))

	_h(parent, "FIREWOOD & FUEL")
	var fire_row := HBoxContainer.new()
	parent.add_child(fire_row)
	_btn(fire_row, "+5 logs",  func(): GameManager.add_firewood(5))
	_btn(fire_row, "Max logs", func(): GameManager.add_firewood(GameManager.max_firewood_storage))
	_btn(fire_row, "No logs",  func(): _force_firewood(0))
	_btn(fire_row, "Full fuel",func(): _force_fuel(1.0))
	_btn(fire_row, "No fuel",  func(): _force_fuel(0.0))

	parent.add_child(HSeparator.new())
	_h(parent, "EVENTS")
	_btn_full(parent, "🏛️  Trigger Tax Event NOW",     _debug_trigger_tax)
	_btn_full(parent, "🍺  Force Beer Shortage (3d)",   _debug_force_beer_shortage)
	_btn_full(parent, "♻️  Reset Economy to Start",     _debug_reset_economy)

	parent.add_child(HSeparator.new())
	_h(parent, "JUMP TO DAY")
	var day_row := HBoxContainer.new()
	parent.add_child(day_row)
	for target_day in [15, 29, 30, 31, 60]:
		var btn := Button.new()
		btn.text = "Day " + str(target_day)
		btn.pressed.connect(func():
			GameManager.current_day = target_day
			GameManager.day_changed.emit(target_day)
			print("🛠️ Debug: jumped to Day ", target_day)
		)
		day_row.add_child(btn)

	parent.add_child(HSeparator.new())
	_h(parent, "TIER UNLOCK (sets all prerequisites)")
	var tier_row := HBoxContainer.new()
	parent.add_child(tier_row)

	var t2_btn := Button.new()
	t2_btn.text = "⬆️ Unlock Tier 2"
	t2_btn.pressed.connect(func():
		GameManager.mission_tier_unlocked = 2
		GameManager.taxes_paid_count = 1
		GameManager.refresh_available_missions()
		print("🛠️ Debug: Tier 2 unlocked (taxes_paid_count=1)")
	)
	tier_row.add_child(t2_btn)

	var t3_btn := Button.new()
	t3_btn.text = "⬆️ Unlock Tier 3"
	t3_btn.pressed.connect(func():
		GameManager.mission_tier_unlocked = 3
		GameManager.taxes_paid_count = 2
		GameManager.tavern_reputation = 50
		GameManager.total_missions_completed = 10
		GameManager.refresh_available_missions()
		print("🛠️ Debug: Tier 3 unlocked (all prerequisites set)")
	)
	tier_row.add_child(t3_btn)

func _force_gold(v: int) -> void:
	GameManager.gold = v
	GameManager.gold_changed.emit(v)

func _force_beer(v: int) -> void:
	GameManager.beer_stock = v
	GameManager.beer_changed.emit(v)

func _force_firewood(v: int) -> void:
	GameManager.firewood_stock = v
	GameManager.firewood_changed.emit(v)

func _force_fuel(v: float) -> void:
	GameManager.fireplace_fuel = v
	GameManager.fireplace_fuel_changed.emit(v)

func _debug_trigger_tax() -> void:
	if GameManager.has_method("process_tax_day"):
		GameManager.process_tax_day()
		print("🛠️ Tax event triggered")
	else:
		print("⚠️  GameManager.process_tax_day() not yet implemented")

func _debug_force_beer_shortage() -> void:
	_force_beer(0)
	GameManager.beer_shortage_days = 3
	print("🛠️ Beer shortage forced — shortage_days = 3")

func _debug_reset_economy() -> void:
	_force_gold(1000)
	_force_beer(10)
	_force_firewood(5)
	_force_fuel(0.5)
	GameManager.beer_shortage_days = 0
	GameManager.daily_operating_cost = 5
	print("🛠️ Economy reset to Day 1 starting values")

# ============================================================
# TAB 2 — MISSION CONTROL
# ============================================================

func _build_tab_missions(parent: VBoxContainer) -> void:
	_h(parent, "MISSION CONTROL")
	_btn_full(parent, "🎲  Force Generate New Missions",        _debug_gen_missions)
	_btn_full(parent, "✅  Complete All Active — SUCCESS",       func(): _debug_complete_all("success"))
	_btn_full(parent, "💀  Complete All Active — FAILURE",       func(): _debug_complete_all("failure"))
	_btn_full(parent, "🎰  Complete All Active — RANDOM",        _debug_complete_random)
	_btn_full(parent, "⏩  Simulate Day End (no sleep anim)",    _debug_simulate_day_end)

	parent.add_child(HSeparator.new())
	_h(parent, "TIER UNLOCK")
	var tier_row := HBoxContainer.new()
	parent.add_child(tier_row)
	_btn(tier_row, "Tier 1", func(): _debug_set_tier(1))
	_btn(tier_row, "Tier 2", func(): _debug_set_tier(2))
	_btn(tier_row, "Tier 3", func(): _debug_set_tier(3))

	parent.add_child(HSeparator.new())
	_h(parent, "Available Missions (after Generate):")
	var avail_lbl := Label.new()
	avail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	avail_lbl.text = "(press Generate above)"
	parent.add_child(avail_lbl)
	_state_labels["avail_missions"] = avail_lbl

func _debug_gen_missions() -> void:
	GameManager.refresh_missions()
	var missions: Array = GameManager.available_missions
	if missions.is_empty():
		_state_labels["avail_missions"].text = "(none generated — check DataManager)"
	else:
		var lines: Array = []
		for m in missions:
			lines.append("• " + m.get("name", m.get("title", "Unknown")))
		_state_labels["avail_missions"].text = "\n".join(lines)
	print("🛠️ Missions regenerated: ", missions.size())

func _debug_complete_all(result: String) -> void:
	if GameManager.active_missions.is_empty():
		print("⚠️  No active missions to resolve")
		return
	for m in GameManager.active_missions.duplicate():
		if GameManager.has_method("resolve_mission"):
			GameManager.resolve_mission(m, result)
		else:
			print("⚠️  GameManager.resolve_mission() not yet implemented — wire it up when mission system is ready")
			break
	print("🛠️ All missions forced → ", result.to_upper())

func _debug_complete_random() -> void:
	for m in GameManager.active_missions.duplicate():
		var result := "success" if randf() > 0.5 else "failure"
		if GameManager.has_method("resolve_mission"):
			GameManager.resolve_mission(m, result)
	print("🛠️ All missions resolved randomly")

func _debug_set_tier(tier: int) -> void:
	GameManager.mission_tier_unlocked = tier
	print("🛠️ Mission tier set to ", tier)

func _debug_simulate_day_end() -> void:
	if GameManager.has_method("advance_day"):
		GameManager.advance_day()
		print("🛠️ Day end simulated — now Day ", GameManager.current_day)
	else:
		print("⚠️  GameManager.advance_day() not found")

# ============================================================
# TAB 3 — NPC SANDBOX
# ============================================================

func _build_tab_npcs(parent: VBoxContainer) -> void:
	_h(parent, "PATRON SPAWNING")
	var spawn_row := HBoxContainer.new()
	parent.add_child(spawn_row)
	_btn(spawn_row, "Spawn 1",    func(): _debug_spawn_patrons(1))
	_btn(spawn_row, "Spawn 5",    func(): _debug_spawn_patrons(5))
	_btn(spawn_row, "Spawn 10",   func(): _debug_spawn_patrons(10))
	_btn_full(parent, "🚫  Despawn All Patrons", _debug_despawn_all)

	parent.add_child(HSeparator.new())
	_h(parent, "ADVENTURER ROSTER")
	_btn_full(parent, "➕  Add Random Adventurer",  _debug_add_adventurer)
	_btn_full(parent, "➕  Fill Roster to Max",       _debug_fill_roster)
	_btn_full(parent, "🗑️   Clear Entire Roster",     _debug_clear_roster)

	parent.add_child(HSeparator.new())
	_h(parent, "RECRUITMENT")
	_btn_full(parent, "🔄  Refresh Daily Recruits", _debug_refresh_recruits)

func _debug_spawn_patrons(count: int) -> void:
	var tavern := _find_main_tavern()
	if tavern and tavern.has_method("spawn_patron"):
		for i in range(count):
			tavern.spawn_patron()
		print("🛠️ Spawned ", count, " patron(s) via MainTavern")
	elif GameManager.has_method("spawn_patron"):
		for i in range(count):
			GameManager.spawn_patron()
	else:
		print("⚠️  No spawn_patron() found on MainTavern or GameManager — add the group 'main_tavern' to your scene root")

func _debug_despawn_all() -> void:
	if GameManager.has_method("despawn_all_patrons"):
		GameManager.despawn_all_patrons()
		print("🛠️ All patrons despawned")
	else:
		print("⚠️  GameManager.despawn_all_patrons() not found")

func _debug_add_adventurer() -> void:
	var dummy := {
		"name": "Debug Hero " + str(GameManager.adventurers.size() + 1),
		"class": ["Warrior","Ranger","Mage","Cleric","Rogue"][randi() % 5],
		"level": 1,
		"status": "idle",
		"id": "dbg_" + str(Time.get_ticks_msec())
	}
	# Try DataManager first for a proper generated adventurer
	if DataManager.has_method("generate_adventurer"):
		dummy = DataManager.generate_adventurer()
	GameManager.adventurers.append(dummy)
	GameManager.adventurer_roster_changed.emit()
	print("🛠️ Added adventurer: ", dummy.get("name", "?"))

func _debug_fill_roster() -> void:
	var slots := GameManager.max_adventurers - GameManager.adventurers.size()
	for i in range(slots):
		_debug_add_adventurer()
	print("🛠️ Roster filled to max (", GameManager.max_adventurers, ")")

func _debug_clear_roster() -> void:
	GameManager.adventurers.clear()
	GameManager.adventurer_roster_changed.emit()
	print("🛠️ Roster cleared")

func _debug_refresh_recruits() -> void:
	if GameManager.has_method("refresh_recruitment"):
		GameManager.refresh_recruitment()
		print("🛠️ Recruitment pool refreshed via GameManager")
	elif DataManager.has_method("generate_daily_recruits"):
		DataManager.generate_daily_recruits()
		print("🛠️ Recruitment pool refreshed via DataManager")
	else:
		print("⚠️  No refresh_recruitment() found")

# ============================================================
# TAB 4 — FAILURE STATE TESTING
# ============================================================

func _build_tab_failures(parent: VBoxContainer) -> void:
	_h(parent, "FAILURE STATE TESTING")

	var warn := Label.new()
	warn.text = "⚠️  These intentionally break the game. Save first."
	warn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
	parent.add_child(warn)
	parent.add_child(HSeparator.new())

	_btn_full(parent, "💸  Game Over: Bankruptcy",              _go_bankruptcy)
	_btn_full(parent, "🍺  Game Over: Beer Shortage (3 days)",  _go_beer_shortage)
	_btn_full(parent, "💀  Game Over: All Adventurers Dead",    _go_all_dead)
	_btn_full(parent, "🏴  Game Over: Direct Generic Trigger",  _go_direct)

	parent.add_child(HSeparator.new())
	_h(parent, "RECOVERY")
	_btn_full(parent, "♻️  Full Reset → Day 1 Starting State",  _full_reset)

func _go_bankruptcy() -> void:
	_force_gold(0)
	GameManager.daily_operating_cost = 9999
	if GameManager.has_method("advance_day"):
		GameManager.advance_day()
	print("🛠️ Bankruptcy scenario triggered")

func _go_beer_shortage() -> void:
	_force_beer(0)
	GameManager.beer_shortage_days = 3
	if GameManager.has_method("check_game_over_conditions"):
		GameManager.check_game_over_conditions()
	elif GameManager.has_method("trigger_game_over"):
		GameManager.trigger_game_over("beer_shortage", "The tavern ran dry for three days. Patrons went elsewhere.")
	print("🛠️ Beer shortage game over triggered")

func _go_all_dead() -> void:
	GameManager.adventurers.clear()
	GameManager.adventurer_roster_changed.emit()
	if GameManager.has_method("trigger_game_over"):
		GameManager.trigger_game_over("no_adventurers", "Every adventurer under your banner has perished.")
	print("🛠️ All adventurers killed, game over triggered")

func _go_direct() -> void:
	if GameManager.has_method("trigger_game_over"):
		GameManager.trigger_game_over("test_game_over", "DEBUG: Manual game over trigger.")
	else:
		print("⚠️  GameManager.trigger_game_over() not found")

func _full_reset() -> void:
	_force_gold(1000)
	_force_beer(10)
	_force_firewood(5)
	_force_fuel(0.5)
	GameManager.beer_shortage_days    = 0
	GameManager.current_day           = 1
	GameManager.daily_operating_cost  = 5
	GameManager.mission_tier_unlocked = 1
	GameManager.tavern_reputation     = 0
	GameManager.total_missions_completed = 0
	GameManager.adventurers.clear()
	GameManager.active_missions.clear()
	GameManager.day_changed.emit(1)
	GameManager.adventurer_roster_changed.emit()
	print("🛠️ Full reset — Day 1 starting state restored")

# ============================================================
# SHARED HELPERS
# ============================================================

func _find_main_tavern() -> Node:
	## Find main tavern via group. Add to_group("main_tavern") in your tavern scene.
	return get_tree().get_first_node_in_group("main_tavern")

func _h(parent: Node, text: String) -> void:
	var lbl := Label.new()
	lbl.text = "— " + text + " —"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	parent.add_child(lbl)

func _btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _btn_full(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
