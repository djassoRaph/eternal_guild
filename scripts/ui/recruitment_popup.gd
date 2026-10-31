# recruitment_popup.gd — the hire desk (Story 4.2; the guild list and its Dismiss from Story 4.5)
#
# E at the recruitment desk opens this PopupPanel (zone_interactions.gd; the Quest Dealer briefs while it is open).
# Story 4.2: the day's applicants stand as Tarot cards (scenes/ui/TarotCard.tscn: the card's painting when one exists,
# else the class silhouette in the card frame, decision D-1), each with name and class, tier, trait, drink, stats and
# costs. Hire picks one and a confirm bar asks before any gold moves; GameManager.hire_block_reason() says why someone
# can't be hired (the button and the bar show it) and GameManager.hire_adventurer() hires. The day's pool is made on
# open when the day never had one (GameManager.ensure_hire_pool: Day 1 of a New Game). Below, "Your guild" lists the
# roster with Dismiss (Story 4.5). build_hire_content(container) builds it all, also off the tree (failsafe Test 29).
# Player-facing text is a DRAFT.
extends PopupPanel

const TAROT_CARD_SCENE := "res://scenes/ui/TarotCard.tscn"
const PANEL_SIZE := Vector2i(1120, 800)     # five applicant columns fit at 1920 x 1080
const CARD_SIZE := Vector2(170, 283)        # tarot_card.json's aspect (0.6)
const COLUMN_WIDTH := 190
const GOLD := Color(0.95, 0.82, 0.45)
const TRAIT_COLOR := Color(0.85, 0.75, 1.0)
const COLUMN_BG := Color(0.12, 0.10, 0.09, 0.95)
const COLUMN_EDGE := Color(0.36, 0.28, 0.20, 1.0)

@onready var main_container = $MainContainer

var selected_id = null     # the applicant the confirm bar asks about (their id); null = none picked
var last_reason := ""      # why the last confirm was refused ("" = none); the bar itself always says the current reason
var _content: Control = null   # the container build_hire_content last filled

func _ready():
	add_to_group("blocks_player")
	var bg := StyleBoxFlat.new()   # opaque, so the cards read over the hall (the theme's panel is see-through)
	bg.bg_color = Color(0.09, 0.075, 0.065, 0.97)
	bg.set_border_width_all(2)
	bg.border_color = COLUMN_EDGE
	bg.set_content_margin_all(10)
	add_theme_stylebox_override("panel", bg)
	print("Recruitment Popup ready")

func open_recruitment_desk():
	"""Open the hire desk: today's applicants (made now if the day never had any) and the guild."""
	GameManager.ensure_hire_pool()
	selected_id = null
	last_reason = ""
	send_log_message("\"Welcome, Guildmaster! These brave souls seek to join your guild.\"")
	build_hire_content(main_container)
	popup_centered(PANEL_SIZE)


## Fill `container` (a VBoxContainer) with the desk: the top line, the applicants' columns, the confirm bar when one is
## picked, and the guild. Everything is rebuilt each time (after a pick, a hire, a refusal); nothing waits a frame.
func build_hire_content(container: Control) -> void:
	_content = container
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	var recruits: Array = GameManager.get_available_recruits()
	if selected_id != null and _recruit_by_id(recruits, selected_id).is_empty():
		selected_id = null   # hired or gone since it was picked
		last_reason = ""

	var top := HBoxContainer.new()
	top.name = "TopLine"
	top.add_theme_constant_override("separation", 30)
	container.add_child(top)
	top.add_child(_label("Title", "The hire desk", 18, GOLD))
	top.add_child(_label("StatusLine", "Gold %d · Roster %d/%d" % [GameManager.get_gold(), GameManager.get_adventurer_count(),
		GameManager.get_max_adventurers()], 14, Color.LIGHT_GRAY))

	container.add_child(_label("ApplicantsHeader", "Looking for work today", 16, Color(0.6, 0.85, 0.95)))
	if recruits.is_empty():
		container.add_child(_label("NoApplicants", "No one is looking for work today. Come back tomorrow.", 14, Color.GRAY))
	else:
		var scroll := ScrollContainer.new()
		scroll.name = "ApplicantsScroll"
		scroll.custom_minimum_size = Vector2(PANEL_SIZE.x - 40, 492)
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		container.add_child(scroll)
		var row := HBoxContainer.new()
		row.name = "Applicants"
		row.add_theme_constant_override("separation", 12)
		scroll.add_child(row)
		for recruit in recruits:
			row.add_child(_applicant_column(recruit))

	var picked: Dictionary = _recruit_by_id(recruits, selected_id) if selected_id != null else {}
	if not picked.is_empty():
		container.add_child(_confirm_bar(picked))

	container.add_child(HSeparator.new())
	var roster: Array = GameManager.adventurers
	container.add_child(_label("GuildHeader", "Your guild (%d/%d)" % [roster.size(), GameManager.get_max_adventurers()], 16, Color.ORANGE))
	var guild_scroll := ScrollContainer.new()
	guild_scroll.name = "GuildScroll"
	guild_scroll.custom_minimum_size = Vector2(PANEL_SIZE.x - 40, 150)
	container.add_child(guild_scroll)
	var guild := VBoxContainer.new()
	guild.name = "Guild"
	guild.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guild.add_theme_constant_override("separation", 8)
	guild_scroll.add_child(guild)
	if roster.is_empty():
		guild.add_child(_label("NoGuild", "No adventurers hired yet.", 13, Color.GRAY))
	else:
		for adventurer in roster:
			_create_adventurer_card(adventurer, guild)


## One applicant: the Tarot card over their lines and the Hire button.
func _applicant_column(recruit: Dictionary) -> Control:
	var rid = recruit.get("id")
	var column := PanelContainer.new()
	column.name = "Applicant_%s" % str(GameManager._id_key(rid))
	var style := StyleBoxFlat.new()
	style.bg_color = COLUMN_BG
	style.set_border_width_all(3 if _is_selected(rid) else 2)
	style.border_color = GOLD if _is_selected(rid) else COLUMN_EDGE
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	column.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	column.add_child(box)

	var card = (load(TAROT_CARD_SCENE) as PackedScene).instantiate()   # tarot_card.gd (loaded by path, no class_name)
	card.name = "Card"
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.set_card(GameManager.tarot_card_of(recruit), PortraitSocket.resolve_card_art(recruit))
	box.add_child(card)

	box.add_child(_label("NameLine", "%s the %s" % [str(recruit.get("name", "?")), str(recruit.get("class", "?"))], 15, Color.WHITE))
	var tier := str(recruit.get("experience_tier", ""))
	if tier != "":
		box.add_child(_label("TierLine", tier, 12, Color.LIGHT_GRAY))
	var t: Dictionary = GameManager.trait_info(recruit)
	if not t.is_empty():
		var trait_line := _label("TraitLine", "%s: %s" % [t.name, t.description], 12, TRAIT_COLOR)
		trait_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		trait_line.custom_minimum_size = Vector2(COLUMN_WIDTH - 16, 0)
		box.add_child(trait_line)
	var drink: String = GameManager.drink_text(recruit)
	if drink != "":
		box.add_child(_label("DrinkLine", drink, 12, Color(0.75, 0.85, 0.95)))
	box.add_child(_label("StatsLine", "STR %d · DEX %d · INT %d · END %d" % [int(recruit.get("strength", 0)), int(recruit.get("dexterity", 0)),
		int(recruit.get("intelligence", 0)), int(recruit.get("endurance", 0))], 12, Color.LIGHT_GRAY))
	box.add_child(_label("CostLine", "%d gold to hire · %d a day" % [int(recruit.get("hiring_cost", 10)), GameManager.wage_of(recruit)], 13, Color.YELLOW))

	var why: String = GameManager.hire_block_reason(recruit)
	var hire := Button.new()
	hire.name = "HireButton"
	hire.custom_minimum_size = Vector2(COLUMN_WIDTH - 16, 32)
	hire.text = "Hire" if why == "" else why
	hire.disabled = why != ""
	if why == "":
		hire.pressed.connect(_select.bind(rid))
	box.add_child(hire)
	return column


## The bar under the cards that asks before any gold moves (or says why it can't).
func _confirm_bar(recruit: Dictionary) -> Control:
	var bar := PanelContainer.new()
	bar.name = "ConfirmBar"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.14, 0.10, 0.95)
	style.set_border_width_all(2)
	style.border_color = GOLD
	style.set_content_margin_all(8)
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)
	var who := "%s the %s" % [str(recruit.get("name", "?")), str(recruit.get("class", "?"))]
	var why: String = GameManager.hire_block_reason(recruit)   # as things stand now (gold may have moved since the pick)
	var text := "Hire %s for %d gold? Wages: %d gold a day." % [who, int(recruit.get("hiring_cost", 10)), GameManager.wage_of(recruit)]
	if why != "":
		text = "Can't hire %s: %s." % [who, why]
	var line := _label("ConfirmText", text, 14, Color.WHITE)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(line)
	var yes := Button.new()
	yes.name = "ConfirmHire"
	yes.text = "Hire"
	yes.custom_minimum_size = Vector2(110, 32)
	yes.disabled = why != ""
	yes.pressed.connect(_confirm_hire)
	row.add_child(yes)
	var no := Button.new()
	no.name = "ConfirmCancel"
	no.text = "Not now"
	no.custom_minimum_size = Vector2(110, 32)
	no.pressed.connect(_cancel_pick)
	row.add_child(no)
	return bar


func _select(rid) -> void:
	selected_id = rid
	last_reason = ""
	build_hire_content(_content)


func _cancel_pick() -> void:
	selected_id = null
	last_reason = ""
	build_hire_content(_content)


## The confirm bar's Hire: GameManager checks again (gold may have moved since the pick) and hires, or the bar says why.
func _confirm_hire() -> void:
	var recruit := _recruit_by_id(GameManager.get_available_recruits(), selected_id)
	if recruit.is_empty():
		selected_id = null
		last_reason = ""
	else:
		var why: String = GameManager.hire_block_reason(recruit)
		if why != "":
			last_reason = why
		elif GameManager.hire_adventurer(recruit):
			selected_id = null
			last_reason = ""
	build_hire_content(_content)


func _is_selected(rid) -> bool:
	return selected_id != null and GameManager._same_id(GameManager._id_key(selected_id), GameManager._id_key(rid))


static func _recruit_by_id(recruits: Array, rid) -> Dictionary:
	if rid == null:
		return {}
	var key = GameManager._id_key(rid)
	for r in recruits:
		if r is Dictionary and GameManager._same_id(GameManager._id_key(r.get("id")), key):
			return r
	return {}


static func _label(node_name: String, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _get_adventurer_level(adventurer: Dictionary) -> int:
	var mc = adventurer.get("missions_completed", 0)
	if mc < 3: return 1
	elif mc < 8: return 2
	elif mc < 15: return 3
	elif mc < 25: return 4
	elif mc < 40: return 5
	else: return 6

func _create_adventurer_card(adventurer: Dictionary, parent: VBoxContainer):
	var card = PanelContainer.new()
	parent.add_child(card)

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.15, 0.2, 0.9)
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.5, 0.6, 0.9, 1.0)
	card.add_theme_stylebox_override("panel", card_style)

	var card_content = HBoxContainer.new()
	card.add_child(card_content)
	card_content.add_theme_constant_override("separation", 20)

	# Left: info
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_content.add_child(info)

	var level = _get_adventurer_level(adventurer)
	var name_label = Label.new()
	name_label.text = adventurer.get("name", "?") + " the " + adventurer.get("class", "?") + " (Lvl " + str(level) + ")"
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	info.add_child(name_label)

	var stats_label = Label.new()
	stats_label.text = "STR:" + str(adventurer.get("strength", 0)) + " | DEX:" + str(adventurer.get("dexterity", 0)) + " | INT:" + str(adventurer.get("intelligence", 0)) + " | END:" + str(adventurer.get("endurance", 0))
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	info.add_child(stats_label)

	var status = adventurer.get("status", AdventurerStatus.Status.READY)
	var status_label = Label.new()
	status_label.text = "Status: " + AdventurerStatus.to_string_label(status)
	status_label.add_theme_font_size_override("font_size", 12)
	var status_color: Color
	match status:
		AdventurerStatus.Status.READY:      status_color = Color.GREEN
		AdventurerStatus.Status.RESTING:    status_color = Color.YELLOW
		AdventurerStatus.Status.WOUNDED:    status_color = Color.RED
		AdventurerStatus.Status.ON_MISSION: status_color = Color.CYAN
		_:                                  status_color = Color.GRAY
	status_label.add_theme_color_override("font_color", status_color)
	info.add_child(status_label)

	# Right: dismiss button
	var dismiss_btn = Button.new()
	dismiss_btn.text = "Dismiss"
	dismiss_btn.custom_minimum_size = Vector2(100, 35)
	dismiss_btn.add_theme_color_override("font_color", Color(0.9, 0.35, 0.3))
	if status == AdventurerStatus.Status.ON_MISSION:
		dismiss_btn.disabled = true
		dismiss_btn.tooltip_text = "On mission"
	else:
		dismiss_btn.pressed.connect(func(): _on_dismiss_pressed(adventurer))
	card_content.add_child(dismiss_btn)

func _on_dismiss_pressed(adventurer: Dictionary):
	# Story 4.5: confirm before dismissing (5 gold + -1 reputation)
	var confirm = ConfirmationDialog.new()
	confirm.title = "Dismiss Adventurer"
	confirm.dialog_text = "Dismiss " + adventurer.get("name", "?") + "?\nCosts 5 gold and -1 Reputation."
	confirm.ok_button_text = "Dismiss"
	add_child(confirm)
	confirm.confirmed.connect(func(): _confirm_dismiss(adventurer))
	confirm.confirmed.connect(confirm.queue_free)
	confirm.canceled.connect(confirm.queue_free)
	confirm.popup_centered()

func _confirm_dismiss(adventurer: Dictionary):
	if GameManager.dismiss_adventurer(adventurer):
		hide()
		await get_tree().create_timer(0.1).timeout
		open_recruitment_desk()


# --- Unused recruit generator helpers (the desk never calls them; failsafe Test 15 reads create_adventurer()). The
# live generator is GameManager.generate_fallback_recruits(); consolidating the three generators is in TECH_DEBT. ---

func create_recruit_applicant() -> Dictionary:
	"""Create a potential recruit with stats and hiring cost"""
	var recruit = create_adventurer()  # Use existing function

	# Add recruitment-specific data
	recruit["hiring_cost"] = calculate_hiring_cost(recruit)
	recruit["personality"] = get_random_personality()
	recruit["background"] = get_random_background(recruit.class)
	recruit["availability"] = "Available"

	return recruit

func create_adventurer() -> Dictionary:
	"""Create an adventurer with random stats"""
	var adventurer_names = DataManager.get_config("adventurer_names", ["Brom", "Ezren", "Kael", "Lyra", "Nim", "Tarin", "Zara", "Garrick", "Mira", "Thorne", "Elira", "Doran", "Sylas", "Iris", "Raphio", "Aiden", "Cora", "Finn", "Runa", "Tobias"])
	var adventurer_classes = GameManager.valid_class_list(DataManager.get_config("adventurer_classes", GameManager.DEFAULT_ADVENTURER_CLASSES))

	var adv_name = adventurer_names[randi() % adventurer_names.size()]
	var adv_class = adventurer_classes[randi() % adventurer_classes.size()]

	var stats = {
		"strength": randi() % 6 + 1,
		"dexterity": randi() % 6 + 1,
		"intelligence": randi() % 6 + 1,
		"endurance": randi() % 6 + 1
	}

	# Class bonuses
	match adv_class:
		"Fighter":
			stats.strength += 2
			stats.endurance += 1
		"Rogue":
			stats.dexterity += 2
		"Mage":
			stats.intelligence += 2
		"Healer":
			stats.intelligence += 1
		"Barbarian":
			stats.strength += 3
			stats.endurance += 2
			stats.intelligence -= 1   # as classes.json and GameManager.recruit_class_bonus (Story 25.9 review)
		"Ranger":
			stats.dexterity += 2
			stats.endurance += 1

	var adventurer = {
		"id": randi() % 10000 + 1000,  # Temporary ID
		"name": adv_name,
		"class": adv_class,
		"status": AdventurerStatus.Status.READY,
		"recovery": 0,
		"strength": stats.strength,
		"dexterity": stats.dexterity,
		"intelligence": stats.intelligence,
		"endurance": stats.endurance,
		"missions_completed": 0,
		"missions_failed": 0,
		"gold_earned": 0,
		"injuries_sustained": 0
	}

	return adventurer

func calculate_hiring_cost(recruit: Dictionary) -> int:
	"""Calculate hiring cost based on stats and class"""
	var base_cost = 10
	var stat_total = recruit.strength + recruit.dexterity + recruit.intelligence + recruit.endurance
	var stat_bonus = (stat_total - 16) * 2  # Above average gets more expensive
	var class_bonus = 0

	match recruit.class:
		"Fighter": class_bonus = 0
		"Rogue": class_bonus = 2
		"Mage": class_bonus = 5
		"Healer": class_bonus = 8  # Most expensive
		"Barbarian": class_bonus = 3
		"Ranger": class_bonus = 4

	return max(5, base_cost + stat_bonus + class_bonus)

func get_random_personality() -> String:
	"""Get a random personality trait"""
	var personalities = [
		"Eager", "Cautious", "Brave", "Greedy", "Loyal", "Reckless",
		"Wise", "Ambitious", "Humble", "Proud", "Calm", "Fiery",
		"Cheerful", "Stoic", "Curious", "Determined"
	]
	return personalities[randi() % personalities.size()]

func get_random_background(character_class: String) -> String:
	"""Get a background story based on class"""
	var backgrounds = {
		"Fighter": [
			"Former city guard", "Retired soldier", "Village protector",
			"Tournament fighter", "Mercenary veteran", "Blacksmith's apprentice"
		],
		"Rogue": [
			"Reformed thief", "Scout from the borderlands", "Former spy",
			"Treasure hunter", "Street informant", "Circus performer"
		],
		"Mage": [
			"Academy dropout", "Wandering scholar", "Court wizard's apprentice",
			"Self-taught spellcaster", "Library researcher", "Ancient tome collector"
		],
		"Healer": [
			"Temple acolyte", "Traveling physician", "Herbalist from the forest",
			"Military medic", "Village wise woman", "Monastery refugee"
		],
		"Barbarian": [
			"Clan champion", "Pit fighter", "Exile from the northern holds",
			"Caravan guard", "Axe-for-hire", "Last of a burned village"
		],
		"Ranger": [
			"Forest warden", "Royal huntsman", "Border scout",
			"Trapper from the high valleys", "Poacher turned guide", "Beast tracker"
		]
	}
	var class_backgrounds = backgrounds.get(character_class, ["Unknown origin"])
	return class_backgrounds[randi() % class_backgrounds.size()]

func send_log_message(message: String):
	"""Send message to GameManager logging system"""
	if GameManager.has_method("log_message"):
		GameManager.log_message(message)
