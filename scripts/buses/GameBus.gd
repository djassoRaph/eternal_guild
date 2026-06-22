extends Node

signal day_changed(new_day: int)
signal game_over_triggered(reason: String)
signal morning_briefing_ready(reports: Array)
signal critical_error(reason: String)
signal game_error_triggered
