# HarvestMinigame — placeholder proving MinigameInterface pattern
class_name HarvestMinigame
extends MinigameInterface

func start_minigame() -> void:
	is_active = true
	is_paused = false
	print("[HarvestMinigame] Started")
	minigame_started.emit()

func end_minigame(success: bool) -> void:
	is_active = false
	is_paused = false
	print("[HarvestMinigame] Ended, success=", success)
	minigame_ended.emit(success)

func pause_minigame() -> void:
	if not is_active:
		return
	is_paused = true
	print("[HarvestMinigame] Paused")
	minigame_paused.emit()

func resume_minigame() -> void:
	if not is_active or not is_paused:
		return
	is_paused = false
	print("[HarvestMinigame] Resumed")
	minigame_resumed.emit()
