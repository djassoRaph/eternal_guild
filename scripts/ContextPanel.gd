extends Control
class_name ContextPanel

@onready var log_text: TextEdit      = $PanelContainer_LogDock/TextEdit_LogText
@onready var next_day_button: Button = $Button_NextDay

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_instance_valid(next_day_button):
		next_day_button.pressed.connect(_on_next_day_pressed)
	LogBus.message.connect(_on_log_message)
	LogBus.post("UI online.")   # visible immediately

func _on_log_message(text: String) -> void:
	if is_instance_valid(log_text):
		if log_text.editable: log_text.editable = false
		log_text.append_text(text + "\n")
		log_text.scroll_vertical = log_text.get_line_count()

func _on_next_day_pressed() -> void:
	LogBus.post("Next Day pressed.")
