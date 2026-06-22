class_name AdventurerStatus
extends RefCounted

enum Status {
	READY,
	ON_MISSION,
	RESTING,
	WOUNDED,
	DEAD,
}

static func to_string_label(s: Status) -> String:
	match s:
		Status.READY: return "Ready"
		Status.ON_MISSION: return "On Mission"
		Status.RESTING: return "Resting"
		Status.WOUNDED: return "Wounded"
		Status.DEAD: return "Dead"
		_: return "Unknown"

static func from_string(s: String) -> Status:
	match s:
		"Ready": return Status.READY
		"On Mission": return Status.ON_MISSION
		"on_mission": return Status.ON_MISSION
		"Resting": return Status.RESTING
		"Injured": return Status.WOUNDED
		"Wounded": return Status.WOUNDED
		"Dead": return Status.DEAD
		_:
			push_warning("[AdventurerStatus] Unknown status string: " + s)
			return Status.READY

static func is_available(s: Status) -> bool:
	return s == Status.READY

static func is_terminal(s: Status) -> bool:
	return s == Status.DEAD

static func can_transition(from: Status, to: Status) -> bool:
	match from:
		Status.READY:
			return to == Status.ON_MISSION or to == Status.DEAD
		Status.ON_MISSION:
			return to in [Status.RESTING, Status.WOUNDED, Status.DEAD]
		Status.RESTING:
			return to == Status.READY or to == Status.DEAD
		Status.WOUNDED:
			return to == Status.RESTING or to == Status.DEAD
		Status.DEAD:
			push_error("[AdventurerStatus] Cannot transition from DEAD")
			return false
		_:
			return false

static func for_save(s: Status) -> String:
	return to_string_label(s)

static func from_save(s: String) -> Status:
	return from_string(s)
