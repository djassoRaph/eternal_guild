extends PopupPanel

@onready var main_container = get_node_or_null("PaddingContainer/MainContainer")



func _ready():
	print("=== BEER MANAGEMENT DEBUG ===")
	print("PopupPanel: ", self)
	print("Looking for PaddingContainer: ", get_node_or_null("PaddingContainer"))
	print("Looking for MainContainer: ", get_node_or_null("PaddingContainer/MainContainer"))
	print("main_container: ", main_container)
	print("Children of PopupPanel: ")
	for child in get_children():
		print("  - ", child.name, " (", child.get_class(), ")")
		if child.name == "PaddingContainer":
			print("    PaddingContainer children:")
			for grandchild in child.get_children():
				print("      - ", grandchild.name, " (", grandchild.get_class(), ")")

func open_beer_management():
	if not main_container:
		print("ERROR: main_container not found! Creating basic structure...")
		create_basic_structure()
	populate_popup_content()
	popup_centered()

func populate_popup_content():
	"""Fill the popup with current beer/gold data"""
	# Clear existing content
	for child in main_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Get current game state from main scene
	var main_scene = get_tree().current_scene
	var current_gold = main_scene.gold if main_scene.has_method("get") else 30
	var current_beer = main_scene.beer_stock if main_scene.has_method("get") else 5
	
	# Create content (using your existing pattern)
	create_beer_ui(current_gold, current_beer)

func create_beer_ui(gold: int, beer_stock: int):
	"""Create the beer management interface"""
	# Tavern keeper greeting
	var greeting = Label.new()
	greeting.text = "\"Welcome, Guildmaster! What can I get for you?\""
	greeting.add_theme_font_size_override("font_size", 14)
	greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(greeting)
	
	# Current stock display
	var stock_info = Label.new()
	stock_info.text = "Current Beer Stock: " + str(beer_stock) + " kegs"
	stock_info.add_theme_font_size_override("font_size", 16)
	stock_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(stock_info)
	
	# Gold display
	var gold_info = Label.new()
	gold_info.text = "Available Gold: " + str(gold)
	gold_info.add_theme_font_size_override("font_size", 14)
	gold_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(gold_info)
	
	# Purchase buttons
	create_purchase_buttons(stock_info, gold_info)

func create_purchase_buttons(stock_label: Label, gold_label: Label):
	"""Create the purchase option buttons"""
	var button_container = VBoxContainer.new()
	main_container.add_child(button_container)
	
	# Buy 1 keg button
	var buy_1_button = Button.new()
	buy_1_button.text = "Buy 1 Keg of Beer (5 gold)"
	buy_1_button.pressed.connect(func(): buy_beer(1, 5, stock_label, gold_label))
	button_container.add_child(buy_1_button)

func buy_beer(kegs: int, cost: int, stock_label: Label, gold_label: Label):
	"""Handle beer purchase"""
	var main_scene = get_tree().current_scene
	
	if main_scene.gold >= cost:
		main_scene.gold -= cost
		main_scene.beer_stock += kegs
		
		# Update displays
		stock_label.text = "Current Beer Stock: " + str(main_scene.beer_stock) + " kegs"
		gold_label.text = "Available Gold: " + str(main_scene.gold)
		
		# Update main UI
		main_scene.update_ui()
		
		# Send log message
		send_log_message("Purchased " + str(kegs) + " beer for " + str(cost) + " gold!")

func send_log_message(message: String):
	var main_script = get_tree().current_scene
	if main_script and main_script.has_method("log_message"):
		await get_tree().process_frame
		main_script.log_message(message)
		
func create_basic_structure():
	# Create the container structure if it doesn't exist
	var padding = MarginContainer.new()
	padding.name = "PaddingContainer"
	add_child(padding)
	print("created basic structure does this mean failure?")
	var vbox = VBoxContainer.new()
	vbox.name = "MainContainer"
	padding.add_child(vbox)
	
	main_container = vbox
