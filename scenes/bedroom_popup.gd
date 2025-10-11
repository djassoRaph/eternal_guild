# bedroom_popup.gd
# Attach to: GameUI/PopupManager/BedroomPopup (PopupPanel)
extends PopupPanel

@onready var main_container = $MainContainer/PaddingContainer

func _ready():
	print("🌙 Bedroom Popup ready")

func open_bedroom():
	"""Open the bedroom/quarters interface"""
	populate_bedroom_content()
	popup_centered()

func populate_bedroom_content():
	"""Create the bedroom UI with firewood purchase and sleep option"""
	# Clear existing content
	for child in main_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Create the interface
	create_bedroom_ui()

func create_bedroom_ui():
	"""Build the complete bedroom interface"""
	
	# === TITLE ===
	var title = Label.new()
	title.text = "🌙 YOUR QUARTERS"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title)
	
	# === SEPARATOR ===
	#add_separator()
	
	# === DAY SUMMARY ===
	create_day_summary()
	
	# === SEPARATOR ===
	#add_separator()
	
	# === FIREWOOD SECTION ===
	#create_firewood_section()
	
	# === SEPARATOR ===
	#add_separator()
	
	# === SLEEP BUTTON ===
	#create_sleep_button()

func create_day_summary():
	"""Show summary of today's activities"""
	var summary_title = Label.new()
	summary_title.text = "📊 DAY " + str(GameManager.get_day()) + " SUMMARY"
	summary_title.add_theme_font_size_override("font_size", 14)
