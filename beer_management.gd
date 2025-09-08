extends PopupPanel

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
	# Tavern keeper greeting
	var greeting = Label.new()
	greeting.text = "\"Welcome, Guildmaster! What can I get for you?\""
	greeting.add_theme_font_size_override("font_size", 14)
	greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(greeting)
	
	# Purchase section title
	var purchase_title = Label.new()
	purchase_title.text = "Beer Purchase Options"
	purchase_title.add_theme_font_size_override("font_size", 16)
	purchase_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(purchase_title)
	
	# Purchase buttons
	create_purchase_buttons()

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

func buy_beer(kegs: int, cost: int):
	var current_gold = get_current_gold()
	
	if current_gold >= cost:
		# Update the TopStatsBar labels
		update_topstats_labels(-cost, kegs)
		
		# Send log messages
		send_log_message("Purchased " + str(kegs) + " keg(s) from the tavern keeper for " + str(cost) + " gold!")
		
		var responses = [
			"\"Excellent choice, Guildmaster!\"",
			"\"That should keep your adventurers happy!\"",
			"\"Fresh from the brewery!\"",
			"\"Your guild's reputation grows with good ale!\""
		]
		send_log_message(responses[randi() % responses.size()])
		
	else:
		send_log_message("\"Sorry, you need " + str(cost) + " gold for that purchase.\"")
		send_log_message("\"Come back when you have more coin, friend.\"")

func update_topstats_labels(gold_change: int, beer_change: int):
	var gold_label = get_node("/root/Node3D/GameUI/TopStatsBar/GoldLabel")
	var beer_label = get_node("/root/Node3D/GameUI/TopStatsBar/BeerLabel")
	
	# Extract current values from the labels
	var current_gold = int(gold_label.text.split(" ")[1])  # "Gold: 30" -> 30
	var current_beer = int(beer_label.text.split(" ")[1])  # "Beer: 5" -> 5
	
	# Calculate new values
	var new_gold = current_gold + gold_change
	var new_beer = current_beer + beer_change
	
	# Update the labels
	gold_label.text = "Gold: " + str(new_gold)
	beer_label.text = "Beer: " + str(new_beer)

func get_current_gold() -> int:
	var gold_label = get_node("/root/Node3D/GameUI/TopStatsBar/GoldLabel")
	var parts = gold_label.text.split(" ")
	return int(parts[1])

func send_log_message(message: String):
	var main_script = get_tree().current_scene
	if main_script and main_script.has_method("log_message"):
		await get_tree().process_frame
		main_script.log_message(message)
	else:
		print("LOG: " + message)
