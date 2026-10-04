extends Node

signal day_changed(new_day: int)
signal game_over_triggered(reason: String)
signal morning_briefing_ready(reports: Array)
signal critical_error(reason: String)
signal game_error_triggered
signal patron_spawned(patron_data: Dictionary)
signal mission_resolved(mission_result: Dictionary)
signal day_advanced(day_number: int)
## The hall's time of day changed (Story 25.23): "morning", "day", "dusk", "evening", "late_night" (alias "reveal"),
## "dawn". Sent where the loop turns (the bedroom, sleep, the new day, the briefing's end); TavernLighting listens.
signal day_phase_changed(phase: String)
