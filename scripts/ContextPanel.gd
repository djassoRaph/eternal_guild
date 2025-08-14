extends Control
class_name ContextPanel

@export var log_text_path: NodePath
@export var next_day_button_path: NodePath

var log_text: TextEdit
var next_day_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if log_text_path != NodePath():
		log_text = get_node(log_text_path) as TextEdit
	if next_day_button_path != NodePath():
		next_day_button = get_node(next_day_button_path) as Button
		next_day_button.pressed.connect(_on_next_day_pressed)
	LogBus.message.connect(_on_log_message)
	LogBus.post("UI online.")  # so you see somethinge something immediately:
	LogBus.post("UI online.")


func _on_log_message(text: String) -> void:
	if log_text:
		if log_text.editable:
			log_text.editable = false
		log_text.append_text(text + "\n")
		log_text.scroll_vertical = log_text.get_line_count()

func _on_next_day_pressed() -> void:
	LogBus.post("Next Day pressed.")
