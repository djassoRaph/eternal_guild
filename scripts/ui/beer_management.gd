extends PopupPanel
# beer_management.gd - UPDATED FOR GAMEMANAGER

@onready var main_container = $MainContainer

func _ready():
	print("Beer Management Popup ready")

func open_beer_management():
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
	send_log_message("\"Welcome, Guildmaster! What can I get for you?\"")
	
	# Purchase section title
	var purchase_title = Label.new()
	purchase_title.text = "Beer Purchase Options"
	purchase_title.add_theme_font_size_override("font_size", 16)
	purchase_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(purchase_title)
	
	# Current status display
	create_status_display()
	
	# Purchase buttons
	create_purchase_buttons()

func create_status_display():
	"""Show current gold and beer status"""
	var status_container = VBoxContainer.new()
	main_container.add_child(status_container)
	
	var gold_status = Label.new()
	gold_status.text = "Current Gold: " + str(GameManager.get_gold())
	gold_status.add_theme_font_size_override("font_size", 14)
	gold_status.add_theme_color_override("font_color", Color.YELLOW)
	gold_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_container.add_child(gold_status)
	
	var beer_status = Label.new()
	beer_status.text = "Current Beer Stock: " + str(GameManager.get_beer())
	beer_status.add_theme_font_size_override("font_size", 14)
	beer_status.add_theme_color_override("font_color", Color.CYAN)
	beer_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_container.add_child(beer_status)

func create_purchase_buttons():
	var button_container = VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 5)
	main_container.add_child(button_container)
	
	# Buy 1 keg button
	var buy_1_button = Button.new()
	buy_1_button.text = "Buy 1 Keg of Beer (5 gold)"
	buy_1_button.custom_minimum_size = Vector2(300, 35)
	buy_1_button.pressed.connect(func(): buy_beer(1, 5))
	button_container.add_child(buy_1_button)
	
	# Buy 5 kegs button (discount)
	var buy_5_button = Button.new()
	buy_5_button.text = "Buy 5 Kegs of Beer (20 gold) - Save 5g!"
	buy_5_button.custom_minimum_size = Vector2(300, 35)
	buy_5_button.pressed.connect(func(): buy_beer(5, 20))
	button_container.add_child(buy_5_button)
	
	# Buy 10 kegs button (bigger discount)
	var buy_10_button = Button.new()
	buy_10_button.text = "Buy 10 Kegs of Beer (35 gold) - Save 15g!"
	buy_10_button.custom_minimum_size = Vector2(300, 35)
	buy_10_button.pressed.connect(func(): buy_beer(10, 35))
	button_container.add_child(buy_10_button)
	
	# Enable/disable buttons based on current gold
	var current_gold = GameManager.get_gold()
	buy_1_button.disabled = current_gold < 5
	buy_5_button.disabled = current_gold < 20
	buy_10_button.disabled = current_gold < 35

func buy_beer(kegs: int, cost: int):
	"""Purchase beer using GameManager - SIMPLIFIED"""
	
	# Attempt purchase through GameManager
	if GameManager.spend_gold(cost):
		# Purchase successful
		GameManager.add_beer(kegs)
		
		# Send success messages
		send_log_message("Purchased " + str(kegs) + " keg(s) from the tavern keeper for " + str(cost) + " gold!")
		
		var responses = [
			"\"Excellent choice, Guildmaster!\"",
			"\"That should keep your adventurers happy!\"",
			"\"Fresh from the brewery!\"",
			"\"Your guild's reputation grows with good ale!\""
		]
		send_log_message(responses[randi() % responses.size()])
		
		# Close and reopen popup to refresh display
		hide()
		await get_tree().create_timer(0.1).timeout
		open_beer_management()
		
	else:
		# Purchase failed - insufficient funds
		send_log_message("\"Sorry, you need " + str(cost) + " gold for that purchase.\"")
		send_log_message("\"Come back when you have more coin, friend.\"")

func send_log_message(message: String):
	"""Send message to GameManager logging system"""
	GameManager.log_message(message)
