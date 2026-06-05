# ASCIIWorldSelection.gd - Simple ASCII map selector
extends Control

# The ONLY scene we go to after selection
const TAVERN_SCENE = "res://scenes/MainTavern.tscn"

# Simple map display
@onready var map_label = $VBoxContainer/MapLabel
@onready var info_label = $VBoxContainer/InfoLabel
@onready var select_button = $VBoxContainer/SelectButton
@onready var back_button = $VBoxContainer/BackButton

# Simple ASCII map (small for testing)
var ascii_map = [
	"~~~~~~....,,,,,,TTT^^^",
	"~~~~.....,,,,,TTTT^^^A",
	"~~......,,o,,TFFF^^AAA",
	"~......,,,,,,,FFF^^^AA",
	"......,,,@,,,,,T^^^^AA",
	".....,,,,-,,,,,,^^^AAA",
	"....,,,o---o,,,,^^^^AA",
	"....,,,,,,,,,,,,T^^^AA",
]

# Settlement data (simple)
var settlements = [
	{"x": 10, "y": 2, "name": "Mountain Village", "symbol": "o"},
	{"x": 9, "y": 4, "name": "Central Keep", "symbol": "@"},
	{"x": 7, "y": 6, "name": "River Cross", "symbol": "o"},
	{"x": 11, "y": 6, "name": "Forest Camp", "symbol": "o"},
]

var cursor_x = 9
var cursor_y = 4
var selected_settlement = null

func _ready():
	setup_ui()
	display_map()
	update_info()

func setup_ui():
	"""Create simple UI if it doesn't exist"""
	if not has_node("VBoxContainer"):
		var vbox = VBoxContainer.new()
		vbox.name = "VBoxContainer"
		add_child(vbox)
		
		# Title
		var title = Label.new()
		title.text = "CHOOSE YOUR STARTING LOCATION"
		title.add_theme_font_size_override("font_size", 24)
		vbox.add_child(title)
		
		# Map display
		var map_lbl = RichTextLabel.new()
		map_lbl.name = "MapLabel"
		map_lbl.custom_minimum_size = Vector2(600, 300)
		map_lbl.bbcode_enabled = true
		vbox.add_child(map_lbl)
		
		# Info display
		var info_lbl = Label.new()
		info_lbl.name = "InfoLabel"
		info_lbl.text = "Use ARROW KEYS to move cursor"
		vbox.add_child(info_lbl)
		
		# Buttons
		var select_btn = Button.new()
		select_btn.name = "SelectButton"
		select_btn.text = "Select This Location"
		select_btn.pressed.connect(_on_select_pressed)
		vbox.add_child(select_btn)
		
		var back_btn = Button.new()
		back_btn.name = "BackButton"
		back_btn.text = "Back to Menu"
		back_btn.pressed.connect(_on_back_pressed)
		vbox.add_child(back_btn)
		
		# Update references
		map_label = map_lbl
		info_label = info_lbl
		select_button = select_btn
		back_button = back_btn

func display_map():
	"""Show the ASCII map with cursor"""
	if not map_label:
		return
		
	map_label.clear()
	map_label.push_mono()  # Use monospace font
	
	for y in range(ascii_map.size()):
		var line = ascii_map[y]
		for x in range(line.length()):
			var char = line[x]
			
			# Highlight cursor position
			if x == cursor_x and y == cursor_y:
				map_label.push_bgcolor(Color.YELLOW)
				map_label.push_color(Color.BLACK)
				map_label.add_text(char)
				map_label.pop()
				map_label.pop()
			else:
				# Color the character
				map_label.push_color(get_char_color(char))
				map_label.add_text(char)
				map_label.pop()
		
		map_label.add_text("\n")
	
	map_label.pop()  # pop mono

func get_char_color(char: String) -> Color:
	"""Simple coloring"""
	match char:
		"~": return Color.BLUE
		".": return Color.CYAN
		",": return Color.GREEN
		"T", "F": return Color.DARK_GREEN
		"^", "A": return Color.GRAY
		"o", "@": return Color.GOLD
		"-": return Color.BROWN
		_: return Color.WHITE

func update_info():
	"""Update info text"""
	if not info_label:
		return
		
	# Check if cursor is on a settlement
	selected_settlement = get_settlement_at(cursor_x, cursor_y)
	
	if selected_settlement:
		info_label.text = "Settlement: " + selected_settlement.name + "\nPress ENTER or click SELECT to choose"
		select_button.disabled = false
	else:
		var terrain = get_terrain_at(cursor_x, cursor_y)
		info_label.text = "Terrain: " + terrain + "\nMove to a settlement (o or @) to select"
		select_button.disabled = true

func get_settlement_at(x: int, y: int):
	"""Check if there's a settlement at position"""
	for settlement in settlements:
		if settlement.x == x and settlement.y == y:
			return settlement
	return null

func get_terrain_at(x: int, y: int) -> String:
	"""Get terrain name at position"""
	if y >= 0 and y < ascii_map.size():
		var line = ascii_map[y]
		if x >= 0 and x < line.length():
			match line[x]:
				"~": return "Deep Water"
				".": return "Shallow Water"
				",": return "Grassland"
				"T": return "Forest"
				"F": return "Dense Forest"
				"^": return "Mountains"
				"A": return "High Peaks"
				"-": return "Road"
				_: return "Unknown"
	return "Out of bounds"

func _input(event):
	"""Handle keyboard input"""
	if event is InputEventKey and event.pressed:
		var moved = false
		
		# Arrow key movement
		if event.keycode == KEY_UP and cursor_y > 0:
			cursor_y -= 1
			moved = true
		elif event.keycode == KEY_DOWN and cursor_y < ascii_map.size() - 1:
			cursor_y += 1
			moved = true
		elif event.keycode == KEY_LEFT and cursor_x > 0:
			cursor_x -= 1
			moved = true
		elif event.keycode == KEY_RIGHT and cursor_x < 21:  # map width - 1
			cursor_x += 1
			moved = true
		
		if moved:
			display_map()
			update_info()
		
		# Selection
		if event.keycode == KEY_ENTER and selected_settlement:
			_on_select_pressed()
		
		# Back
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()

func _on_select_pressed():
	"""Player selected a settlement - go to tavern"""
	if selected_settlement:
		print("Selected: ", selected_settlement.name)
		
		# Store selection in GameManager if it exists
		if GameManager:
			GameManager.set("selected_settlement_name", selected_settlement.name)
			
			# You could add starting bonuses based on location
			match selected_settlement.name:
				"Mountain Village":
					GameManager.add_gold(20)  # Mining bonus
				"Central Keep":
					GameManager.add_gold(50)  # Trade hub bonus
				"River Cross":
					GameManager.add_beer(3)  # Trade route
				"Forest Camp":
					pass  # Standard start
		
		# ALWAYS go to the tavern scene
		get_tree().change_scene_to_file(TAVERN_SCENE)

func _on_back_pressed():
	"""Go back to main menu"""
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
