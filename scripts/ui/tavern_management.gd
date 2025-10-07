extends PopupPanel
# tavern_management.gd - PINT-BASED SYSTEM UPDATE

@onready var main_container = $MainContainer

func _ready():
	print("Tavern Management Popup ready")

func open_tavern_management():
	populate_popup_content()
	popup_centered()

func populate_popup_content():
	# Clear existing content
	for child in main_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Create the beer management interface
	create_beer_ui()

func create_beer_ui():	
	send_log_message("\"Welcome, Guildmaster! Fresh pints available!\"")
	
	# Purchase section title
	var purchase_title = Label.new()
	purchase_title.text = "Tavern Management Options"
	purchase_title.add_theme_font_size_override("font_size", 16)
	purchase_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(purchase_title)
	
	# Current status display
	create_status_display()
	
	# Purchase buttons
	create_purchase_buttons()

func create_status_display():
	"""Show current gold and beer status in pints"""
	var status_container = VBoxContainer.new()
	main_container.add_child(status_container)
	
	var gold_status = Label.new()
	gold_status.text = "Current Gold: " + str(GameManager.get_gold())
	gold_status.add_theme_font_size_override("font_size", 14)
	gold_status.add_theme_color_override("font_color", Color.YELLOW)
	gold_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_container.add_child(gold_status)
	
	var beer_status = Label.new()
	beer_status.text = "Current Beer Stock: " + str(GameManager.get_beer()) + " pints"
	beer_status.add_theme_font_size_override("font_size", 14)
	beer_status.add_theme_color_override("font_color", Color.CYAN)
	beer_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_container.add_child(beer_status)
	
	# Economic explanation
	var profit_info = Label.new()
	profit_info.text = "Customers pay 6 gold per pint (5 gold profit each)"
	profit_info.add_theme_font_size_override("font_size", 12)
	profit_info.add_theme_color_override("font_color", Color.GREEN)
	profit_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_container.add_child(profit_info)

func create_purchase_buttons():
	var button_container = VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 5)
	main_container.add_child(button_container)
	
	# Buy 1 pint button
	var buy_1_button = Button.new()
	buy_1_button.text = "Buy 1 Pint of Beer (1 gold)"
	buy_1_button.custom_minimum_size = Vector2(300, 35)
	buy_1_button.pressed.connect(func(): buy_beer_pints(1, 1))
	button_container.add_child(buy_1_button)
	
	# Buy 5 pints button (no discount for clarity)
	var buy_5_button = Button.new()
	buy_5_button.text = "Buy 5 Pints of Beer (5 gold)"
	buy_5_button.custom_minimum_size = Vector2(300, 35)
	buy_5_button.pressed.connect(func(): buy_beer_pints(5, 5))
	button_container.add_child(buy_5_button)
	
	# Buy 10 pints button (small bulk discount)
	var buy_10_button = Button.new()
	buy_10_button.text = "Buy 10 Pints of Beer (9 gold) - Save 1g!"
	buy_10_button.custom_minimum_size = Vector2(300, 35)
	buy_10_button.pressed.connect(func(): buy_beer_pints(10, 9))
	button_container.add_child(buy_10_button)
	
	# Buy 20 pints button (better bulk discount)
	var buy_20_button = Button.new()
	buy_20_button.text = "Buy 20 Pints of Beer (17 gold) - Save 3g!"
	buy_20_button.custom_minimum_size = Vector2(300, 35)
	buy_20_button.pressed.connect(func(): buy_beer_pints(20, 17))
	button_container.add_child(buy_20_button)
	
	# Enable/disable buttons based on current gold
	var current_gold = GameManager.get_gold()
	buy_1_button.disabled = current_gold < 1
	buy_5_button.disabled = current_gold < 5
	buy_10_button.disabled = current_gold < 9
	buy_20_button.disabled = current_gold < 17

func buy_beer_pints(pints: int, cost: int):
	"""Purchase beer using GameManager - PINT-BASED SYSTEM"""
	
	# Attempt purchase through GameManager
	if GameManager.spend_gold(cost):
		# Purchase successful
		GameManager.add_beer(pints)
		
		# Send success messages with clear economics
		send_log_message("Purchased " + str(pints) + " pint(s) for " + str(cost) + " gold!")
		
		# Calculate profit potential
		var potential_profit = pints * 5  # 5 gold profit per pint
		send_log_message("Potential profit: " + str(potential_profit) + " gold (6g sale - 1g cost per pint)")
		
		var responses = [
			"\"Fresh from the barrel, perfect for thirsty adventurers!\"",
			"\"Each pint will keep your customers happy!\"",
			"\"Quality ale that sells itself!\"",
			"\"Your guild's reputation grows with good drink!\""
		]
		send_log_message(responses[randi() % responses.size()])
		
		# Close and reopen popup to refresh display
		hide()
		await get_tree().create_timer(0.1).timeout
		open_tavern_management()
		
	else:
		# Purchase failed - insufficient funds
		send_log_message("\"Sorry, you need " + str(cost) + " gold for that purchase.\"")
		send_log_message("\"Come back when you have more coin, friend.\"")

func send_log_message(message: String):
	"""Send message to GameManager logging system"""
	GameManager.log_message(message)
