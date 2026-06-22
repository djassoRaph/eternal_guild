# MinigameInterface — base class for all minigames
# Day-end sequence can pause any active minigame via this interface
# without knowing the concrete type.
class_name MinigameInterface
extends Node

signal minigame_started()
signal minigame_ended(success: bool)
signal minigame_paused()
signal minigame_resumed()

var is_active: bool = false
var is_paused: bool = false

func start_minigame() -> void:
	push_error("MinigameInterface: subclass must implement start_minigame()")

func end_minigame(success: bool) -> void:
	push_error("MinigameInterface: subclass must implement end_minigame()")

func pause_minigame() -> void:
	push_error("MinigameInterface: subclass must implement pause_minigame()")

func resume_minigame() -> void:
	push_error("MinigameInterface: subclass must implement resume_minigame()")
