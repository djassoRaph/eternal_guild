extends Control
class_name TavernScreen

@onready var base: TextureRect         = $TextureRect_tavernbase
@onready var hover_tavern: TextureRect = $TextureRect_tavern_highlight
@onready var hover_desk: TextureRect   = $TextureRect_desk_highlight
@onready var zone_tavern: Control      = $Control_ZoneTavern
@onready var zone_desk: Control        = $Control_ZoneDesk

func _ready() -> void:
	for c in get_children():
		print("Child:", c.name)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_textures()
	_wire_zone(zone_tavern, hover_tavern, "tavern")
	_wire_zone(zone_desk, hover_desk, "desk")

func _setup_textures() -> void:
	var nodes: Array[TextureRect] = [base, hover_tavern, hover_desk]
	for n in nodes:
		n.set_anchors_preset(Control.PRESET_FULL_RECT)
		n.set_offsets_preset(Control.PRESET_FULL_RECT)
		n.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # fill + center
		n.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE  # don't eat mouse input

	hover_tavern.visible = false
	hover_desk.visible = false

	hover_tavern.visible = false
	hover_desk.visible = false

func _wire_zone(zone: Control, hover: TextureRect, zone_name: String) -> void:
	zone.mouse_entered.connect(func() -> void:
		hover.visible = true
		LogBus.post("Hover: " + zone_name)
	)
	zone.mouse_exited.connect(func() -> void:
		hover.visible = false
		LogBus.post("Exit: " + zone_name)
	)
	zone.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				LogBus.post("Clicked " + zone_name)
	)
