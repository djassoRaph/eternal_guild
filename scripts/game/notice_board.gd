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


## Notices pinned for a number of open contracts.
static func notices_shown(count: int) -> int:
	return clampi(count, 0, MAX_NOTICES)


## Contracts still open: those in today's pool that no active mission has taken.
static func open_contracts(available: Array, active: Array) -> int:
	var n := 0
	for m in available:
		var taken := false
		for entry in active:
			if entry is Dictionary and entry.get("mission") == m:
				taken = true
				break
		if not taken:
			n += 1
	return n


func _ready() -> void:
	add_to_group("notice_board")
	for i in MAX_NOTICES:
		var n := find_child("notice_%02d" % (i + 1), true, false) as Node3D
		if n:
			_notices.append(n)
	var gm := get_node_or_null("/root/GameManager")
	if preview_count >= 0:
		set_notice_count(preview_count)
	elif gm:
		gm.missions_changed.connect(_refresh)
		gm.mission_dispatched.connect(func(_a, _m, _h): _refresh())
		_refresh()
	else:
		set_notice_count(MAX_NOTICES)


func _refresh() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		set_notice_count(open_contracts(gm.available_missions, gm.active_missions))


func set_notice_count(count: int) -> void:
	var shown := notices_shown(count)
	for i in _notices.size():
		(_notices[i] as Node3D).visible = i < shown
