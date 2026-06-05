# ASCIIWorldGenerator.gd - Lightweight ASCII world map generator
extends Control
class_name ASCIIWorldGenerator

# Map dimensions
@export var map_width: int = 80
@export var map_height: int = 40
@export var world_seed: int = 0

# ASCII tile representations
const TILES = {
	"water": "~",
	"shallow_water": ".",
	"grass": ",",
	"forest": "T",
	"dense_forest": "F",
	"mountain": "^",
	"high_mountain": "A",
	"desert": "s",
	"settlement_small": "o",
	"settlement_medium": "O",
	"settlement_large": "@",
	"road": "-",
	"bridge": "=",
	"player": "X",
	"unknown": "?"
}

# Color codes for tiles (using RichTextLabel colors)
const TILE_COLORS = {
	"~": "blue",
	".": "cyan",
	",": "green",
	"T": "dark_green",
	"F": "dark_green",
	"^": "gray",
	"A": "white",
	"s": "yellow",
	"o": "orange",
	"O": "orange",
	"@": "gold",
	"-": "brown",
	"=": "brown",
	"X": "red"
}

# Map data
var ascii_map: Array = []
var height_map: Array = []
var settlements: Array = []
var roads: Array = []

# Display elements
@onready var map_display = $MapDisplay  # RichTextLabel
@onready var info_panel = $InfoPanel    # Label
@onready var minimap = $Minimap        # TextureRect (optional)

# Interaction state
var cursor_x: int = 40
var cursor_y: int = 20
var selected_settlement: Dictionary = {}

signal settlement_selected(settlement: Dictionary)
signal map_generated()

func _ready():
	print("=== ASCII WORLD GENERATOR INITIALIZED ===")
	print("Map size: ", map_width, "x", map_height)
	
	setup_display()
	generate_world()
	display_map()

func setup_display():
	"""Setup the text display for ASCII map"""
	if not map_display:
		map_display = RichTextLabel.new()
		map_display.name = "MapDisplay"
		##map_display.add_theme_font_override("mono_font", preload("res://fonts/monospace.ttf") if FileAccess.file_exists("res://fonts/monospace.ttf") else ThemeDB.fallback_font)
		map_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		map_display.bbcode_enabled = true
		add_child(map_display)
	
	# Set monospace font for proper ASCII alignment
	map_display.add_theme_font_size_override("mono_font_size", 12)

func generate_world():
	"""Generate the ASCII world map"""
	print("Generating world with seed: ", world_seed if world_seed != 0 else "random")
	
	if world_seed == 0:
		world_seed = randi()
	
	seed(world_seed)
	
	# Initialize arrays
	ascii_map = []
	height_map = []
	
	# Step 1: Generate height map using simple noise
	generate_height_map()
	
	# Step 2: Convert heights to terrain types
	generate_terrain()
	
	# Step 3: Place settlements
	place_settlements()
	
	# Step 4: Generate roads between settlements
	generate_roads()
	
	map_generated.emit()
	print("World generation complete!")

func generate_height_map():
	"""Generate simple height map using diamond-square or simple noise"""
	for y in range(map_height):
		var height_row = []
		for x in range(map_width):
			# Simple noise function
			var height = generate_simple_noise(x, y)
			height_row.append(height)
		height_map.append(height_row)

func generate_simple_noise(x: int, y: int) -> float:
	"""Simple noise generation without external dependencies"""
	# Multiple octaves for more interesting terrain
	var value = 0.0
	var amplitude = 1.0
	var frequency = 0.05
	
	for octave in range(3):
		value += sin(x * frequency + world_seed) * cos(y * frequency + world_seed * 0.5) * amplitude
		amplitude *= 0.5
		frequency *= 2.0
	
	# Normalize to 0-1
	return (value + 1.0) / 2.0

func generate_terrain():
	"""Convert height map to ASCII terrain"""
	for y in range(map_height):
		var map_row = []
		for x in range(map_width):
			var height = height_map[y][x]
			var tile = height_to_terrain(height)
			map_row.append(tile)
		ascii_map.append(map_row)

func height_to_terrain(height: float) -> String:
	"""Convert height value to terrain type"""
	if height < 0.2:
		return TILES["water"]
	elif height < 0.3:
		return TILES["shallow_water"]
	elif height < 0.4:
		return TILES["grass"]
	elif height < 0.6:
		return TILES["forest"]
	elif height < 0.7:
		return TILES["dense_forest"]
	elif height < 0.85:
		return TILES["mountain"]
	else:
		return TILES["high_mountain"]

func place_settlements():
	"""Place settlements on suitable terrain"""
	settlements.clear()
	
	var num_settlements = randi_range(8, 15)
	var placed = 0
	var attempts = 0
	var max_attempts = num_settlements * 20
	
	while placed < num_settlements and attempts < max_attempts:
		attempts += 1
		
		var x = randi() % map_width
		var y = randi() % map_height
		
		# Check if location is suitable
		if not is_valid_settlement_location(x, y):
			continue
		
		# Check distance from other settlements
		if is_too_close_to_settlements(x, y, 8):
			continue
		
		# Place settlement
		var settlement_type = choose_settlement_type()
		var settlement = {
			"x": x,
			"y": y,
			"name": generate_settlement_name(placed),
			"type": settlement_type,
			"size": randi_range(50, 500),
			"danger": randi_range(1, 5),
			"wealth": randi_range(100, 1000),
			"description": generate_settlement_description(settlement_type)
		}
		
		settlements.append(settlement)
		
		# Mark on map
		if settlement.size < 150:
			ascii_map[y][x] = TILES["settlement_small"]
		elif settlement.size < 350:
			ascii_map[y][x] = TILES["settlement_medium"]
		else:
			ascii_map[y][x] = TILES["settlement_large"]
		
		placed += 1
		print("Placed settlement: ", settlement.name, " at (", x, ",", y, ")")

func is_valid_settlement_location(x: int, y: int) -> bool:
	"""Check if location is valid for settlement"""
	var terrain = ascii_map[y][x]
	return terrain in [TILES["grass"], TILES["forest"], TILES["desert"]]

func is_too_close_to_settlements(x: int, y: int, min_distance: int) -> bool:
	"""Check if position is too close to existing settlements"""
	for settlement in settlements:
		var dx = abs(settlement.x - x)
		var dy = abs(settlement.y - y)
		var distance = sqrt(dx * dx + dy * dy)
		if distance < min_distance:
			return true
	return false

func generate_roads():
	"""Generate simple roads between nearby settlements"""
	roads.clear()
	
	# Connect each settlement to 2-3 nearest neighbors
	for settlement in settlements:
		var nearest = find_nearest_settlements(settlement, 3)
		for target in nearest:
			if not is_road_exists(settlement, target):
				create_road(settlement, target)

func find_nearest_settlements(from_settlement: Dictionary, count: int) -> Array:
	"""Find nearest settlements"""
	var distances = []
	
	for settlement in settlements:
		if settlement == from_settlement:
			continue
		
		var dx = settlement.x - from_settlement.x
		var dy = settlement.y - from_settlement.y
		var distance = sqrt(dx * dx + dy * dy)
		distances.append({"settlement": settlement, "distance": distance})
	
	distances.sort_custom(func(a, b): return a.distance < b.distance)
	
	var result = []
	for i in min(count, distances.size()):
		result.append(distances[i].settlement)
	
	return result

func is_road_exists(from: Dictionary, to: Dictionary) -> bool:
	"""Check if road already exists between settlements"""
	for road in roads:
		if (road.from == from and road.to == to) or (road.from == to and road.to == from):
			return true
	return false

func create_road(from: Dictionary, to: Dictionary):
	"""Create road between two settlements"""
	roads.append({"from": from, "to": to})
	
	# Draw road on map (simple line)
	var x1 = from.x
	var y1 = from.y
	var x2 = to.x
	var y2 = to.y
	
	# Bresenham's line algorithm (simplified)
	var dx = abs(x2 - x1)
	var dy = abs(y2 - y1)
	var sx = 1 if x1 < x2 else -1
	var sy = 1 if y1 < y2 else -1
	var err = dx - dy
	
	while true:
		# Don't overwrite settlements
		if ascii_map[y1][x1] not in ["o", "O", "@"]:
			if ascii_map[y1][x1] == TILES["water"]:
				ascii_map[y1][x1] = TILES["bridge"]
			else:
				ascii_map[y1][x1] = TILES["road"]
		
		if x1 == x2 and y1 == y2:
			break
		
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x1 += sx
		if e2 < dx:
			err += dx
			y1 += sy

func display_map():
	"""Display the ASCII map in the RichTextLabel"""
	if not map_display:
		return
	
	map_display.clear()
	map_display.push_mono()  # Monospace font
	
	for y in range(map_height):
		for x in range(map_width):
			var tile = ascii_map[y][x]
			
			# Highlight cursor position
			if x == cursor_x and y == cursor_y:
				map_display.push_bgcolor(Color.WHITE)
				map_display.push_color(Color.BLACK)
			else:
				# Color based on tile type
				var color_name = TILE_COLORS.get(tile, "white")
				map_display.push_color(get_color_from_name(color_name))
			
			map_display.add_text(tile)
			
			if x == cursor_x and y == cursor_y:
				map_display.pop()  # bgcolor
				map_display.pop()  # color
			else:
				map_display.pop()  # color
		
		map_display.add_text("\n")
	
	map_display.pop()  # mono

func get_color_from_name(color_name: String) -> Color:
	"""Convert color name to Color"""
	match color_name:
		"blue": return Color.BLUE
		"cyan": return Color.CYAN
		"green": return Color.GREEN
		"dark_green": return Color(0, 0.5, 0)
		"gray": return Color.GRAY
		"white": return Color.WHITE
		"yellow": return Color.YELLOW
		"orange": return Color.ORANGE
		"gold": return Color.GOLD
		"brown": return Color(0.5, 0.25, 0)
		"red": return Color.RED
		_: return Color.WHITE

func _input(event):
	"""Handle input for map navigation"""
	if event is InputEventKey and event.pressed:
		var moved = false
		
		# Arrow key navigation
		if event.keycode == KEY_UP and cursor_y > 0:
			cursor_y -= 1
			moved = true
		elif event.keycode == KEY_DOWN and cursor_y < map_height - 1:
			cursor_y += 1
			moved = true
		elif event.keycode == KEY_LEFT and cursor_x > 0:
			cursor_x -= 1
			moved = true
		elif event.keycode == KEY_RIGHT and cursor_x < map_width - 1:
			cursor_x += 1
			moved = true
		
		if moved:
			display_map()
			update_info_panel()
		
		# Select settlement with Enter
		if event.keycode == KEY_ENTER:
			select_current_tile()
		
		# Regenerate with R
		if event.keycode == KEY_R:
			world_seed = 0  # Random seed
			generate_world()
			display_map()

func update_info_panel():
	"""Update information panel with current tile info"""
	if not info_panel:
		info_panel = Label.new()
		info_panel.name = "InfoPanel"
		add_child(info_panel)
	
	var tile = ascii_map[cursor_y][cursor_x]
	var terrain_name = get_terrain_name(tile)
	
	var info_text = "Position: (" + str(cursor_x) + ", " + str(cursor_y) + ")\n"
	info_text += "Terrain: " + terrain_name + "\n"
	info_text += "Height: " + str(snapped(height_map[cursor_y][cursor_x], 0.01)) + "\n"
	
	# Check if settlement
	var settlement = get_settlement_at(cursor_x, cursor_y)
	if settlement:
		info_text += "\n=== SETTLEMENT ===\n"
		info_text += "Name: " + settlement.name + "\n"
		info_text += "Type: " + settlement.type + "\n"
		info_text += "Population: " + str(settlement.size) + "\n"
		info_text += "Wealth: " + str(settlement.wealth) + " gold\n"
		info_text += "Danger Level: " + str(settlement.danger) + "/5\n"
		info_text += "\n" + settlement.description + "\n"
		info_text += "\nPress ENTER to select this settlement"
	
	info_panel.text = info_text

func get_terrain_name(tile: String) -> String:
	"""Get readable name for terrain tile"""
	for terrain_name in TILES:
		if TILES[terrain_name] == tile:
			return terrain_name.replace("_", " ").capitalize()
	return "Unknown"

func get_settlement_at(x: int, y: int) -> Dictionary:
	"""Get settlement at position"""
	for settlement in settlements:
		if settlement.x == x and settlement.y == y:
			return settlement
	return {}

func select_current_tile():
	"""Select the current tile (usually a settlement)"""
	var settlement = get_settlement_at(cursor_x, cursor_y)
	if settlement:
		selected_settlement = settlement
		settlement_selected.emit(settlement)
		print("Selected settlement: ", settlement.name)

func generate_settlement_name(index: int) -> String:
	"""Generate settlement names"""
	var prefixes = ["North", "South", "East", "West", "New", "Old", "Fort", "Port", "Mount"]
	var suffixes = ["haven", "burg", "ford", "gate", "holm", "ridge", "vale", "marsh", "creek"]
	
	return prefixes[index % prefixes.size()] + suffixes[index % suffixes.size()]

func choose_settlement_type() -> String:
	"""Choose settlement type based on terrain"""
	var types = ["Farming Village", "Trading Post", "Military Fort", "Mining Town", 
				 "Fishing Village", "Crossroads Inn", "Border Keep", "Merchant Hub"]
	return types[randi() % types.size()]

func generate_settlement_description(settlement_type: String) -> String:
	"""Generate description for settlement"""
	var descriptions = {
		"Farming Village": "Peaceful fields surround this agricultural community.",
		"Trading Post": "Merchants gather here to exchange goods from distant lands.",
		"Military Fort": "Stone walls protect this strategic defensive position.",
		"Mining Town": "Deep shafts extract precious minerals from the earth.",
		"Fishing Village": "Nets and boats line the shores of this coastal settlement.",
		"Crossroads Inn": "Travelers rest here at the junction of major trade routes.",
		"Border Keep": "Guards watch the frontier from this fortified outpost.",
		"Merchant Hub": "Wealth flows through this center of commerce."
	}
	return descriptions.get(settlement_type, "A modest settlement.")

# Public API
func get_map_as_string() -> String:
	"""Export map as string for saving/sharing"""
	var map_string = ""
	for row in ascii_map:
		for tile in row:
			map_string += tile
		map_string += "\n"
	return map_string

func load_map_from_string(map_string: String):
	"""Load map from string"""
	ascii_map.clear()
	var lines = map_string.split("\n")
	for line in lines:
		if line.length() > 0:
			var row = []
			for char in line:
				row.append(char)
			ascii_map.append(row)
	display_map()

func export_to_full_3d():
	"""Export data for 3D visualization"""
	return {
		"ascii_map": ascii_map,
		"height_map": height_map,
		"settlements": settlements,
		"roads": roads,
		"width": map_width,
		"height": map_height,
		"seed": world_seed
	}
