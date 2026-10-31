# AdventurerRosterPanel.gd
extends Control

@onready var roster_list = $RosterScrollContainer/RosterList

# Preload the card template
var adventurer_card_scene = preload("res://scenes/ui/AdventurerCard.tscn")

# Track spawned cards
var adventurer_cards: Dictionary = {}

# CRITICAL FIX: Prevent overlapping refresh calls
var is_refreshing: bool = false

# Slide-in/out panel geometry. Panel is 350px wide (see AdventurerRosterPanel's offset_right
# in MainTavern.tscn). SHOWN_X used to be 1570 — exactly 1920-350, i.e. the panel's right edge
# landed flush on the screen's right edge with zero margin, clipping the portrait's right side
# (nothing wrong with the panel's own width; it just had nowhere to breathe). 24px margin fixes it.
const HIDDEN_X := 1920.0
const SHOWN_X := 1546.0

# Story 4.3: each entry shows its adventurer's Tarot card (compact) in CardContent/ArtSlot.
const TAROT_CARD_SCENE := "res://scenes/ui/TarotCard.tscn"
const ART_SIZE := Vector2(64, 106)                 # the card's aspect (tarot_card.json, 0.6)
const DEPLOYED_ART := Color(0.45, 0.45, 0.5, 1.0)  # a deployed adventurer's card art, greyed under the badge
const NOT_READY := Color(0.55, 0.55, 0.55, 0.80)   # the whole card, as before, for anyone not Ready

# Explicit open/closed state. Do NOT derive this from the animating position.x —
# rapid Tab presses or roster changes during the 0.3s slide would race against each
# other and leave the panel stuck (the "adventurers not displaying" bug).
var is_open: bool = false
var _slide_tween: Tween

func _ready():
	print("Adventurer Roster Panel initialized")
	
	# Connect to GameManager signals
	if GameManager:
		GameManager.adventurer_roster_changed.connect(_on_roster_changed)
		GameManager.day_changed.connect(_on_day_changed)
	
	# Initial population
	refresh_roster()
	
	# Start hidden (parked off-screen right). `is_open` — not position.x — is the source of truth.
	is_open = false
	position.x = HIDDEN_X
	visible = true

func _input(event):
	"""Tab toggles the roster panel."""
	if event.is_action_pressed("ui_focus_next"):  # Tab key
		toggle_panel()
		get_viewport().set_input_as_handled()  # don't also shift UI focus on Tab


func toggle_panel():
	"""Toggle visibility. Keys off explicit `is_open`, never the animating position."""
	if is_open:
		hide_panel()
	else:
		show_panel()

func _slide_to(target_x: float) -> void:
	# Reuse a single tween so competing show/hide calls can't fight over position.x.
	if _slide_tween and _slide_tween.is_running():
		_slide_tween.kill()
	_slide_tween = create_tween()
	_slide_tween.set_ease(Tween.EASE_OUT)
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.tween_property(self, "position:x", target_x, 0.3)

func show_panel():
	"""Slide the panel in from the right."""
	if is_open:
		return
	is_open = true
	_slide_to(SHOWN_X)
	print("Opening roster panel")

func hide_panel():
	"""Slide the panel out to the right."""
	if not is_open:
		return
	is_open = false
	_slide_to(HIDDEN_X)
	print("Closing roster panel")



func refresh_roster():
	"""Rebuild entire roster from GameManager"""
	# CRITICAL FIX: Prevent overlapping refreshes
	if is_refreshing:
		print("Refresh already in progress, skipping...")
		return
	
	is_refreshing = true
	print("Refreshing adventurer roster...")
	
	# Clear ALL children from roster_list
	for child in roster_list.get_children():
		child.queue_free()
	
	# Clear the tracking dictionary
	adventurer_cards.clear()
	
	# Wait for nodes to actually be freed
	await get_tree().process_frame
	
	# Get adventurers from GameManager
	var adventurers = GameManager.adventurers
	print("Found ", adventurers.size(), " adventurers to display")
	
	if adventurers.size() == 0:
		_show_empty_roster_message()
	else:
		# Create card for each adventurer
		for adventurer in adventurers:
			create_adventurer_card(adventurer)
	
	# CRITICAL FIX: Release the lock after refresh completes
	is_refreshing = false
	print("Roster refresh complete")

func _show_empty_roster_message():
	"""Display message when no adventurers hired"""
	var empty_label = Label.new()
	empty_label.text = "No adventurers in guild\nVisit recruitment desk to hire"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 12)
	empty_label.add_theme_color_override("font_color", Color.GRAY)
	roster_list.add_child(empty_label)  # FIXED: Use roster_list

func _get_adventurer_level(adventurer: Dictionary) -> int:
	"""Calculate level based on completed missions"""
	var missions = adventurer.get("missions_completed", 0)
	if missions < 3:
		return 1
	elif missions < 8:
		return 2
	elif missions < 15:
		return 3
	elif missions < 25:
		return 4
	elif missions < 40:
		return 5
	else:
		return 6

func create_adventurer_card(adventurer: Dictionary):
	"""Spawn and populate a single adventurer card (Story 4.3: their Tarot card's art, name, class, trait, status
	with the days left, the card's name, wage and drink, all read from the record)."""
	# id computed first so the drag script receives it before _ready() fires
	var adventurer_id = adventurer.get("id", adventurer.get("name"))

	var card = adventurer_card_scene.instantiate()
	card.set_script(preload("res://scenes/ui/script/adventurer_card.gd"))
	card.adventurer_id = adventurer_id
	roster_list.add_child(card)
	fill_card(card, adventurer, entry_view(adventurer, {
		"level": _get_adventurer_level(adventurer),
		"return_day": GameManager.return_day_for(adventurer),
		"today": GameManager.current_day,
		"card": GameManager.tarot_card_of(adventurer),
		"trait": GameManager.trait_info(adventurer),
		"wage": GameManager.wage_of(adventurer),
		"drink": GameManager.drink_text(adventurer),
	}))

	# Store card reference
	adventurer_cards[adventurer_id] = card

	print("Created card for: ", adventurer.get("name"))


## Put an entry_view() onto an AdventurerCard.tscn instance: the labels, the compact Tarot card (the shared card art,
## PortraitSocket.resolve_card_art), the Deployed badge and the greys. Non-Ready cards are dimmed as before; a deployed
## adventurer's art is greyed further.
static func fill_card(card: Control, adventurer: Dictionary, view: Dictionary) -> void:
	var info := card.get_node("CardContent/InfoContainer")
	(info.get_node("NameLabel") as Label).text = view.name
	(info.get_node("ClassLabel") as Label).text = view.class_line
	var status_label := info.get_node("StatusLabel") as Label
	status_label.text = view.status_line
	status_label.add_theme_color_override("font_color", view.status_color)
	var card_label := info.get_node("CardLabel") as Label
	card_label.text = view.card_name
	card_label.visible = view.card_name != ""
	(info.get_node("WageLabel") as Label).text = view.wage_line

	var slot := card.get_node("CardContent/ArtSlot") as Control
	var thumb = slot.get_node_or_null("Card")
	if thumb == null:
		thumb = (load(TAROT_CARD_SCENE) as PackedScene).instantiate()   # tarot_card.gd (by path, no class_name)
		thumb.name = "Card"
		thumb.compact = true
		thumb.custom_minimum_size = ART_SIZE
		slot.add_child(thumb)
		thumb.size = ART_SIZE       # after add_child: a size set before entering the tree gives way to the scene's offsets
		slot.move_child(thumb, 0)   # under the Deployed badge
	thumb.set_card(GameManager.tarot_card_of(adventurer), PortraitSocket.resolve_card_art(adventurer))
	thumb.modulate = DEPLOYED_ART if view.deployed else Color.WHITE
	(slot.get_node("DeployedBadge") as Label).visible = view.deployed
	card.modulate = NOT_READY if view.greyed else Color.WHITE


## One roster entry's lines (Story 4.3, pure): {name, class_line, status_line, status_color, deployed, greyed,
## card_name, wage_line}. `ctx`: level, return_day (GameManager.return_day_for: the day a deployed adventurer is back,
## the same day the World Map shows; -1 unknown), today, card (their deck card, GameManager.tarot_card_of), trait
## (GameManager.trait_info), wage (GameManager.wage_of: the wage the morning deducts) and drink (the drink line).
## Status lines are a DRAFT.
static func entry_view(adv: Dictionary, ctx: Dictionary) -> Dictionary:
	var S = AdventurerStatus.Status
	var status: int = GameManager.status_of(adv)
	var trait_name := str((ctx.trait as Dictionary).get("name", "")) if ctx.get("trait") is Dictionary else ""
	var class_line := "%s · Level %d" % [str(adv.get("class", "Adventurer")), int(ctx.get("level", 1))]
	if trait_name != "":
		class_line += " · " + trait_name
	var line := "Unknown"
	var color := Color.GRAY
	match status:
		S.READY:
			line = "Ready"
			color = Color.GREEN
		S.ON_MISSION:
			var back := int(ctx.get("return_day", -1))
			var left := back - int(ctx.get("today", 0)) if back >= 0 else -1
			line = ("Deployed · returns in %d day%s" % [left, "" if left == 1 else "s"]) if left >= 1 else "Deployed"
			color = Color.CYAN
		S.RESTING, S.WOUNDED:
			var base := "Resting" if status == S.RESTING else "Wounded"
			var rec = adv.get("recovery", 0)
			var days := int(rec) if (rec is int or rec is float) else 0
			line = ("%s · available in %d day%s" % [base, days, "" if days == 1 else "s"]) if days >= 1 else base
			color = Color.YELLOW if status == S.RESTING else Color.RED
		S.DEAD:
			line = "Fallen"
	var card = ctx.get("card", {})
	var drink := str(ctx.get("drink", ""))
	var wage_line := "%d gold a day" % int(ctx.get("wage", 1))
	if drink != "":
		wage_line += " · " + drink
	return {"name": str(adv.get("name", "Unknown")), "class_line": class_line, "status_line": line, "status_color": color,
		"deployed": status == S.ON_MISSION, "greyed": not AdventurerStatus.is_available(status),
		"card_name": str(card.get("name", "")) if card is Dictionary else "", "wage_line": wage_line}

func _on_roster_changed():
	"""Roster data changed — rebuild the cards. Visibility stays under the player's control
	(Tab); we no longer force the panel open on every change, which previously made Tab
	unpredictable and flew the panel in during mission dispatch."""
	print("Roster changed signal received!")
	refresh_roster()

func _on_day_changed(new_day: int):
	"""Called when day advances - refresh to update recovery timers"""
	refresh_roster()
