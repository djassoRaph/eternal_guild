extends Node
class_name LogBusClass

signal message(text: String)

var history: Array[String] = []

func post(text: String) -> void:
	history.append(text)
	emit_signal("message", text)
