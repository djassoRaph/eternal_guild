extends Control

signal fade_complete

var fade_overlay: ColorRect
var sleep_text: Label

func _ready():
	# Create the black overlay
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade_overlay)
	
	# Create sleep message
	sleep_text = Label.new()
	sleep_text.text = "🌙 Resting at the Eternal Guild..."
	sleep_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sleep_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sleep_text.add_theme_font_size_override("font_size", 24)
	sleep_text.add_theme_color_override("font_color", Color.WHITE)
	sleep_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sleep_text)
	
	# Start invisible
	modulate.a = 0.0
	visible = false

func start_sleep_fade():
	"""Begin the sleep transition"""
	visible = true
	
	var tween = create_tween()
	
	# Fade to black (2 seconds)
	tween.tween_property(self, "modulate:a", 1.0, 2.0)
	
	# Hold black screen (1 second)
	tween.tween_interval(1.0)
	
	# Fade back to game (2 seconds)
	tween.tween_property(self, "modulate:a", 0.0, 2.0)
	
	# Complete
	tween.tween_callback(complete_fade)

func complete_fade():
	visible = false
	fade_complete.emit()
