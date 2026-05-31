# bedroom_popup.gd - SIMPLIFIED VERSION (Uses editor-built UI)
# Attach to: GameUI/PopupManager/BedroomPopup (PopupPanel)
extends PopupPanel

# === UI ELEMENT REFERENCES ===
# Day Summary Section
@onready var summary_title = $MarginContainer/MainVBox/DaySummaryContainer/TitleLabel
@onready var gold_label = $MarginContainer/MainVBox/DaySummaryContainer/GoldLabel
@onready var beer_label = $MarginContainer/MainVBox/DaySummaryContainer/BeerLabel
@onready var adventurers_label = $MarginContainer/MainVBox/DaySummaryContainer/AdventurersLabel

# Firewood Section
@onready var stock_label = $MarginContainer/MainVBox/FirewoodContainer/StockLabel
@onready var buy_3_button = $MarginContainer/MainVBox/FirewoodContainer/ButtonsContainer/Buy3Button
@onready var buy_5_button = $MarginContainer/MainVBox/FirewoodContainer/ButtonsContainer/Buy5Button
@onready var buy_10_button = $MarginContainer/MainVBox/FirewoodContainer/ButtonsContainer/Buy10Button

# Sleep Button
@onready var sleep_button = $MarginContainer/MainVBox/SleepButton

func _ready():
	print("🌙 Bedroom Popup ready (Editor UI version)")
	
	# Connect button signals
	buy_3_button.pressed.connect(func(): purchase_firewood(3, 15))
	buy_5_button.pressed.connect(func(): purchase_firewood(5, 25))
	buy_10_button.pressed.connect(func(): purchase_firewood(10, 45))
	sleep_button.pressed.connect(start_sleep_sequence)

func open_bedroom():
	"""Open the bedroom/quarters interface with updated info"""
	update_all_displays()
	popup_centered()
	GameManager.log_message("Reviewing the day before resting...")

func update_all_displays():
	"""Update all UI elements with current GameManager data"""
	
	# === UPDATE DAY SUMMARY ===
	var current_day = GameManager.get_day()
	summary_title.text = "📊 DAY " + str(current_day) + " SUMMARY"
	
	gold_label.text = "💰 Gold: " + str(GameManager.get_gold())
	beer_label.text = "🍺 Beer: " + str(GameManager.get_beer()) + " pints"
	adventurers_label.text = "⚔️ Adventurers: " + str(GameManager.get_adventurer_count())
	
	# === UPDATE FIREWOOD STOCK ===
	var current_stock = GameManager.get_firewood_stock()
	var max_stock = GameManager.get_max_firewood_storage()
	stock_label.text = "Current stock: " + str(current_stock) + "/" + str(max_stock) + " bundles"
	
	# === UPDATE BUTTON STATES ===
	update_button_availability()

func update_button_availability():
	"""Enable/disable purchase buttons based on gold and storage"""
	var current_gold = GameManager.get_gold()
	var current_stock = GameManager.get_firewood_stock()
	var max_stock = GameManager.get_max_firewood_storage()
	
	# Buy 3 bundles (15g)
	if current_gold < 15:
		buy_3_button.disabled = true
		buy_3_button.text = "Buy 3 bundles - 15 gold (Need " + str(15 - current_gold) + "g more)"
	elif current_stock + 3 > max_stock:
		buy_3_button.disabled = true
		buy_3_button.text = "Buy 3 bundles - 15 gold (Not enough storage)"
	else:
		buy_3_button.disabled = false
		buy_3_button.text = "Buy 3 bundles - 15 gold"
	
	# Buy 5 bundles (25g)
	if current_gold < 25:
		buy_5_button.disabled = true
		buy_5_button.text = "Buy 5 bundles - 25 gold (Need " + str(25 - current_gold) + "g more)"
	elif current_stock + 5 > max_stock:
		buy_5_button.disabled = true
		buy_5_button.text = "Buy 5 bundles - 25 gold (Not enough storage)"
	else:
		buy_5_button.disabled = false
		buy_5_button.text = "Buy 5 bundles - 25 gold"
	
	# Buy 10 bundles (45g)
	if current_gold < 45:
		buy_10_button.disabled = true
		buy_10_button.text = "Buy 10 bundles (Max) - 45 gold (Need " + str(45 - current_gold) + "g more)"
	elif current_stock + 10 > max_stock:
		buy_10_button.disabled = true
		buy_10_button.text = "Buy 10 bundles (Max) - 45 gold (Storage full!)"
	else:
		buy_10_button.disabled = false
		buy_10_button.text = "Buy 10 bundles (Max) - 45 gold"

func purchase_firewood(bundles: int, cost: int):
	"""Attempt to purchase firewood"""
	if GameManager.purchase_firewood(bundles, cost):
		# Success - refresh the display
		update_all_displays()
		GameManager.log_message("✅ Purchase successful! Ready for tomorrow.")
	else:
		# Failure - error message already logged by GameManager
		GameManager.log_message("❌ Purchase failed. Check your gold and storage capacity.")

func start_sleep_sequence():
	"""Begin the sleep/day advancement sequence"""
	GameManager.log_message("💤 Heading to bed for the night...")
	
	# Close this popup
	hide()
	
	# Small delay for better UX
	await get_tree().create_timer(0.3).timeout
	
	# Get fade system
	var fade_system = get_node_or_null("/root/Node3D/UIOverlay/FadeToBlack")
	
	if fade_system:
		# Despawn all patrons BEFORE fade starts
		GameManager.despawn_all_patrons()
		
		# Connect to fade completion (disconnect first to avoid duplicates)
		if fade_system.fade_complete.is_connected(_on_fade_complete):
			fade_system.fade_complete.disconnect(_on_fade_complete)
		fade_system.fade_complete.connect(_on_fade_complete)
		
		# Start fade animation
		fade_system.start_sleep_fade()
	else:
		# Fallback if fade system not found
		print("⚠️ Fade system not found! Advancing day immediately.")
		GameManager.despawn_all_patrons()
		_on_fade_complete()

func _on_fade_complete():
	"""Called when fade animation completes - advance the day, then show morning briefing"""
	# Advance day in GameManager (includes mission resolution, recovery, etc.)
	GameManager.advance_day()

	print("✅ New day started through bedroom sequence")
	GameManager.log_message("🌅 A new day dawns at the Eternal Guild!")

	if GameManager.has_pending_briefing:
		_show_morning_briefing()


func _show_morning_briefing():
	"""Create and display the morning briefing UI"""
	var briefing_scene = load("res://scenes/ui/MorningBriefing.tscn")
	if briefing_scene:
		var briefing = briefing_scene.instantiate()
		get_tree().root.add_child(briefing)
		briefing.show_reports(GameManager.get_and_clear_pending_reports())
	else:
		var reports = GameManager.get_and_clear_pending_reports()
		for report in reports:
			if report.success:
				GameManager.log_message("📜 REPORT: " + report.mission_name + " — SUCCESS")
			else:
				GameManager.log_message("📜 REPORT: " + report.mission_name + " — FAILED")
