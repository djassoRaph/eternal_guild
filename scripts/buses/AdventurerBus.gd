extends Node

signal adventurer_roster_changed
signal recruitment_pool_changed
signal mission_dispatched(adventurers: Array, mission: Dictionary, hex_id: String)
signal missions_resolved(reports: Array)
signal missions_changed
