extends Control
class_name TavernScreen

@onready var base: TextureRect = %"base"
@onready var hover_tavern: TextureRect = %"hover_tavern"
@onready var hover_desk: TextureRect = %"hover_desk"
@onready var zone_tavern: Control = %"ZoneTavern"
@onready var zone_desk: Control = %"ZoneDesk"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_textures()
	_wire_zone(zone_tavern, hover_tavern, "tavern")
	_wire_zone(zone_desk, hover_desk, "desk")

func _setup_textures() -> void:
	var nodes: Array[TextureRect] = [base, hover_tavern, hover_desk]
	for n in nodes:
		n.set_anchors_preset(Control.PRESET_FULL_RECT)
		n.set_offsets_preset(Control.PRESET_FULL_RECT)
		n.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		n.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hover_tavern.visible = false
	hover_desk.visible = false

func _wire_zone(zone: Control, hover: TextureRect, zone_name: String) -> void:
	zone.mouse_entered.connect(func() -> void:
		hover.visible = true
	)
	zone.mouse_exited.connect(func() -> void:
		hover.visible = false
	)
	zone.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				LogBus.post("Clicked " + zone_name)
	)
