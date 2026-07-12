# patron_speech_bubble.gd — ambient patron speech (Story 8.4).
#
# A tiny, self-contained billboarded bubble a patron spawns above its head while
# drinking. The MVP renders a Label3D — 2D text living in the 3D world, always
# facing the camera. The say()/presentation split is the intended swap point: later
# the Label3D internals can be replaced with a SubViewport-rendered panel (rounded
# bubble + tail + mood icon for 8.4-B/C) without changing how patrons call it.
class_name PatronSpeechBubble
extends Node3D

const HEAD_HEIGHT := 2.45  # metres above the patron origin (the service sphere sits at 2.2)
const WRAP_CHARS := 24     # soft word-wrap width so a line doesn't stretch across the room

var _label: Label3D

func say(text: String, hold_seconds: float = 3.5) -> void:
	if text == "" or text == "...":
		queue_free()
		return
	_ensure_label()
	_label.text = _wrap(text)
	_label.modulate.a = 1.0
	_label.scale = Vector3.ONE * 0.5

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_label, "scale", Vector3.ONE, 0.18)   # pop-in
	tw.tween_interval(hold_seconds)                          # hold
	tw.set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(_label, "modulate:a", 0.0, 0.5)        # fade out
	tw.tween_callback(queue_free)

func _ensure_label() -> void:
	if _label:
		return
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED       # always face the camera
	_label.no_depth_test = true                              # stay readable over the scene
	_label.render_priority = 2
	_label.pixel_size = 0.0075
	_label.font_size = 48
	_label.outline_size = 14
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.modulate = Color(0.98, 0.94, 0.86)                # warm parchment text
	_label.outline_modulate = Color(0.10, 0.06, 0.02, 0.92)  # dark warm outline for contrast
	_label.position = Vector3(0.0, HEAD_HEIGHT, 0.0)
	add_child(_label)

func _wrap(text: String) -> String:
	# Naive greedy word-wrap so long lines break across ~WRAP_CHARS instead of one wide row.
	var out := ""
	var line_len := 0
	for word in text.split(" "):
		if line_len > 0 and line_len + word.length() + 1 > WRAP_CHARS:
			out += "\n" + word
			line_len = word.length()
		else:
			out += (" " + word) if line_len > 0 else word
			line_len += word.length() + (1 if line_len > 0 else 0)
	return out
