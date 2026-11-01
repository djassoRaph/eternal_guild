extends Node

signal day_changed(new_day: int)
signal game_over_triggered(reason: String)
signal morning_briefing_ready(reports: Array)
signal critical_error(reason: String)
signal game_error_triggered
signal patron_spawned(patron_data: Dictionary)
signal mission_resolved(mission_result: Dictionary)
signal day_advanced(day_number: int)
## The time of day changed phase (Stories 25.23, 3.7): "morning", "day", "dusk", "evening", "late_night" (alias "reveal"),
## "dawn". Sent only by the day clock (scripts/game/day_clock.gd, GameManager's DayClock): each phase once a day, in
## order, a jump sending every phase it crosses; never on load or on entering a scene (read GameManager.day_clock_phase()).
## TavernLighting, the disturbance director, the King's messenger and the patron spawner listen.
signal day_phase_changed(phase: String)
## The day clock's whole minute changed (Story 3.7): minutes since midnight of the day's start (6:00 = 360, 2:00 = 1560).
## Sent by the day clock as it runs, jumps and starts a new day; never on load or on entering a scene.
signal day_clock_changed(minutes: int)
