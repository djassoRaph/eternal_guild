# ZonePromptUI.gd
# Attach to your GameUI CanvasLayer
# Shows 2D prompt at bottom of screen when player enters zones
extends CanvasLayer

var prompt_label: Label
var active: bool = false

func _ready():
	create_prompt_ui()
	
	# Wait for scene to fully load before connecting
	await get_tree().process_frame
	await get_tree().process_frame
	connect_to_zones()

func create_prompt_ui():
	"""Create the 2D prompt label"""
	prompt_label = Label.new()
	add_child(prompt_label)
	
	# Position at bottom center of screen
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_top = 1.0
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_bottom = 1.0
	prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_label.offset_left = -300
	prompt_label.offset_top = -100
	prompt_label.offset_right = 300
	prompt_label.offset_bottom = -50
	
	# Styling
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 28)
	prompt_label.add_theme_color_override("font_color", Color(1, 1, 0))
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prompt_label.add_theme_constant_override("outline_size", 10)
	
	# Hide by default
	prompt_label.visible = false
	
	print("Zone prompt UI created")

func connect_to_zones():
	"""Find and connect to all interaction zones"""
	var interactive_parent = get_node_or_null("/root/Node3D/SubViewportContainer/SubViewport/Interactive")
	
	if not interactive_parent:
		print("ERROR: Could not find Interactive parent node")
		return
	
	var zone_configs = {
		"BarArea": "Press E - Tavern Management",
		"RecruitmentDesk": "Press E - Recruit Adventurers",
		"MissionBoard": "Press E - View Missions",
		"NextDayArea": "Press E - Rest & Plan"
	}
	
	for zone_name in zone_configs.keys():
		var zone = interactive_parent.get_node_or_null(zone_name)
		if zone and zone is Area3D:
			var prompt_text = zone_configs[zone_name]
			zone.body_entered.connect(func(body): _on_zone_entered(body, prompt_text))
			zone.body_exited.connect(_on_zone_exited)
			print("Connected to zone: ", zone_name)
		else:
			print("WARNING: Could not find zone: ", zone_name)

func _on_zone_entered(body: Node3D, prompt_text: String):
	"""Show prompt when player enters zone"""
	if body.name == "Player" or body.is_in_group("player"):
		prompt_label.text = prompt_text
		prompt_label.visible = true
		active = true

func _on_zone_exited(body: Node3D):
	"""Hide prompt when player leaves zone"""
	if body.name == "Player" or body.is_in_group("player"):
		prompt_label.visible = false
		active = false
