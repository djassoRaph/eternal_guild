# notice_board.gd
# The guild's mission board in the hall (Story 25.7, catalogue B4). One parchment notice is pinned for
# each open contract: today's pool (GameManager.available_missions) minus the ones a party has
# already taken (GameManager.active_missions), up to 8. The board fills up when a new day brings
# contracts and thins as parties are dispatched. The world-map screen is opened by the MissionBoard
# interaction zone (zone_interactions.gd), not by this node.
# This node stays out of the UI screens' group (see the story's name-clash note): that group means
# "a mission screen is open" and blocks every zone's input while any member is visible.
extends Node3D

const MAX_NOTICES := 8

## -1 = follow GameManager's contracts; 0..8 = a fixed count (LookDev).
@export var preview_count := -1

var _notices: Array = []
var _refresh_queued := false


## Notices pinned for a number of open contracts.
static func notices_shown(count: int) -> int:
	return clampi(count, 0, MAX_NOTICES)


## Contracts still open: those in today's pool that no active mission has taken. Each active mission
## claims at most one contract: the same dictionary first, then an equal one (a loaded save holds
## copies), then one with the same id or name (a copy edited since), so twin contracts and edited
## copies count once.
static func open_contracts(available: Array, active: Array) -> int:
	var taken := {}   # index into available -> true
	var left := []
	for entry in active:
		var m = entry.get("mission") if entry is Dictionary else null
		if m is Dictionary:
			left.append(m)
	for pass_i in 3:
		var still := []
		for m in left:
			var hit := -1
			for i in available.size():
				if taken.has(i) or not available[i] is Dictionary:
					continue
				var c: Dictionary = available[i]
				if (pass_i == 0 and is_same(c, m)) or (pass_i == 1 and c == m) \
						or (pass_i == 2 and _contract_key(c) != "" and _contract_key(c) == _contract_key(m)):
					hit = i
					break
			if hit >= 0:
				taken[hit] = true
			else:
				still.append(m)
		left = still
	return available.size() - taken.size()


static func _contract_key(m: Dictionary) -> String:
	return str(m.get("id", m.get("name", "")))


func _ready() -> void:
	add_to_group("notice_board")
	for i in MAX_NOTICES:
		var n := find_child("notice_%02d" % (i + 1), true, false) as Node3D
		if n:
			_notices.append(n)
		else:
			push_warning("[NoticeBoard] notice missing: notice_%02d" % (i + 1))
	if preview_count >= 0:
		set_notice_count(preview_count)
		return
	# Recount whenever the open contracts can change (buses, NFR-9): a refresh or a dispatch, a
	# resolution (also on a day with no new contracts), the morning briefing, and day_changed, which
	# advance_day, a loaded save and a reset all emit.
	AdventurerBus.missions_changed.connect(_queue_refresh)
	AdventurerBus.mission_dispatched.connect(_queue_refresh)
	AdventurerBus.missions_resolved.connect(_queue_refresh)
	GameBus.morning_briefing_ready.connect(_queue_refresh)
	GameBus.day_changed.connect(_queue_refresh)
	_refresh()


## Deferred, so a recount asked for mid advance_day (day_changed comes before the returns resolve)
## reads the lists once the whole day step is done.
func _queue_refresh(_a = null, _b = null, _c = null) -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	set_notice_count(open_contracts(GameManager.available_missions, GameManager.active_missions))


func set_notice_count(count: int) -> void:
	var shown := notices_shown(count)
	for i in _notices.size():
		(_notices[i] as Node3D).visible = i < shown
