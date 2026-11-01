# day_clock.gd — the day clock (Story 3.7; decision log K-14…K-19). One persistent node: GameManager adds it to itself as
# "DayClock" (group day_clock), so it lives across scene changes and is the ONE sender of GameBus.day_phase_changed.
#
# Where it runs (CL-2, K-19): in every "day scene", a current scene whose root is in group day_clock_scene (MainTavern and
# ExteriorWorld join it in _enter_tree). Anywhere else (the menus, HexMapTest's new-run map, dev scenes, the test suite,
# the frames of a scene change) it is off: no tick, no phase sent. Entering a day scene takes up the current phase
# silently (a load, a Continue, the front door), so readers take the phase from GameManager / the lighting at _ready.
#
# Each frame in a day scene: sync the phase (send every phase crossed, in order; a new day sends "morning"), then, unless
# held (hold_reason: the fall, the end, a paused tree, a frozen world, a modal screen, a conversation, the briefing, the
# Codex, a card reveal, a node in day_clock_hold) or a night is under way, advance GameManager.day_clock_minutes by real
# time (day_clock_seconds_per_hour per in-game hour, × speed), then sync again. At the day's end (2:00) the guildmaster
# nods off (K-16): in the hall, the bedroom's own sleep sequence ("nod_off"); outside (no bedroom), this node blacks the
# screen (its own overlay, so it stays black across the scene change), sets GameManager.pending_night and takes the
# player to the hall at day_clock.wake_spot, where the bedroom's sequence runs the same night (CL-16). The 1:00 warning
# is a banner anywhere. Rules: day_clock_rules.gd. No class_name: loaded by path.
extends Node

const Rules := preload("res://scripts/game/day_clock_rules.gd")
const ZPUI_PATH := "res://scripts/game/ZonePromptUI.gd"
const HALL_SCENE := "res://scenes/MainTavern.tscn"
const SCENE_GROUP := "day_clock_scene"
const HOLD_GROUP := "day_clock_hold"
const OVERLAY_LAYER := 125
const FADE_SECONDS := 0.5
const NOD_OFF := "nod_off"
const PENDING_RETRY_SECONDS := 2.0

## Debug speed (F12: x1 / x10 / x60). Session only, never saved.
static var speed := 1.0

## Tests switch the persistent clock off while their fixture clocks run.
var enabled := true
## How the nod-off outside changes scene (tests record it); unset: PlayerManager.transition_to_scene(path, spot).
var scene_changer: Callable

var _phase := ""          # the last phase sent ("" = take up the current one silently)
var _minute := -1         # the last whole minute sent on day_clock_changed
var _ending := ""         # "" | "bed" | "nod_off": a night under way (no tick until begin_day)
var _was_off := true
var _tired_day := -1      # the day the 1:00 warning showed
var _overlay: CanvasLayer = null
var _pending_left := 0.0  # outside with a pending night: time until the hall is asked for again


func _ready() -> void:
	add_to_group("day_clock")
	process_mode = Node.PROCESS_MODE_ALWAYS   # GameManager goes DISABLED on a fall; the hall's root runs ALWAYS
	var gb := get_node_or_null("/root/GameBus")
	if gb and gb.has_signal("game_over_triggered"):
		gb.game_over_triggered.connect(func(_r): _lift_overlay(true))


func _process(delta: float) -> void:
	manual_tick(delta)


## The frame's work (tests call it with their own delta).
func manual_tick(delta: float) -> void:
	if not enabled:
		return
	var tree := get_tree()
	if tree == null or not is_day_scene(tree):
		_was_off = true
		return
	var gm := _gm()
	if gm == null:
		return
	if _was_off:
		_was_off = false
		adopt()
	if str(gm.get("pending_night")) != "":
		_serve_pending_night(gm, delta)
	if _quiet(gm):
		return
	_sync()
	if _ending != "" or hold_reason(tree) != "":
		return
	var cfg: Dictionary = gm.day_clock_config()
	var before: float = gm.day_clock_minutes
	gm.day_clock_minutes = minf(before + delta * Rules.minutes_per_second(cfg, speed), float(cfg.end))
	_sync()
	_check_tired(before, gm.day_clock_minutes, cfg)
	if gm.day_clock_minutes >= float(cfg.end):
		_nod_off()


## The current scene is a day scene (CL-2).
static func is_day_scene(tree: SceneTree) -> bool:
	var s := tree.current_scene
	return s != null and is_instance_valid(s) and s.is_in_group(SCENE_GROUP)


## What holds the clock in a day scene ("" when nothing): the one scene-agnostic rule (K-15, CL-4, CL-19).
static func hold_reason(tree: SceneTree) -> String:
	var gm = tree.root.get_node_or_null("GameManager")
	if gm == null or gm.get("game_over_active") == true:
		return "the fall"
	var de = gm.get("demo_ending")
	if de is Dictionary and str(de.get("state", "")) == "ended":
		return "the end"
	if tree.paused:
		return "paused"
	var scene := tree.current_scene
	if scene != null:
		if scene.has_method("is_world_frozen"):
			if scene.is_world_frozen():
				return "frozen"
		else:
			var svc = scene.get_node_or_null("SubViewportContainer")
			if svc is Node and (svc as Node).process_mode == Node.PROCESS_MODE_DISABLED:
				return "frozen"
	if load(ZPUI_PATH).modal_open(tree):
		return "a screen"
	if not _live(tree, "dialogue_open").is_empty():
		return "a conversation"
	for n in _live(tree, "morning_briefing"):
		if n.get("visible") != false:
			return "the briefing"
	if not _live(tree, "codex_open").is_empty():
		return "the Codex"
	if not _live(tree, "card_reveal").is_empty():
		return "a card reveal"
	for n in _live(tree, HOLD_GROUP):
		return "held by %s" % n.name
	return ""


static func _live(tree: SceneTree, group: String) -> Array:
	return tree.get_nodes_in_group(group).filter(func(n): return not n.is_queued_for_deletion())


## Why the clock isn't moving now ("" when it runs): off outside a day scene, a night under way, or the hold.
func held_reason() -> String:
	if not enabled:
		return "off: disabled"
	var tree := get_tree()
	if tree == null or not is_day_scene(tree):
		return "off: %s" % (tree.current_scene.name if tree and tree.current_scene else "no scene")
	if _ending != "":
		return "the night"
	return hold_reason(tree)


func is_running() -> bool:
	return held_reason() == ""


## F12's speed (x1 / x10 / x60), through the node (the static is the clock's, session only).
func set_speed(v: float) -> void:
	speed = clampf(v, 0.0, 100.0)
	print("[DayClock] speed x%s" % speed)


func get_speed() -> float:
	return speed


## Take up the current phase and minute silently (entering a day scene, a load, New Game).
func adopt() -> void:
	var gm := _gm()
	if gm == null:
		return
	var cfg: Dictionary = gm.day_clock_config()
	_phase = Rules.phase_for(gm.day_clock_minutes, cfg)
	_minute = int(floor(gm.day_clock_minutes))


## Forget the session: a new run or a load (GameManager calls it). The phase is taken up again silently.
func reset_session() -> void:
	_ending = ""
	_phase = ""
	_minute = -1
	_tired_day = -1
	_pending_left = 0.0
	_lift_overlay(true)
	adopt()


## Send what changed: every phase crossed (in order), and the whole minute.
func _sync() -> void:
	var gm := _gm()
	if gm == null:
		return
	var cfg: Dictionary = gm.day_clock_config()
	var m: float = gm.day_clock_minutes
	var now := Rules.phase_for(m, cfg)
	if _phase == "":
		_phase = now
		_minute = int(floor(m))
		return
	if now != _phase:
		var steps := Rules.phases_between(_phase, now, cfg)
		_phase = now
		for p in steps:
			print("[DayClock] phase: %s (%s, day %d)" % [p, Rules.format_time(m), int(gm.current_day)])
			GameBus.day_phase_changed.emit(p)
	var whole := int(floor(m))
	if whole != _minute:
		_minute = whole
		GameBus.day_clock_changed.emit(whole)


func _quiet(gm: Node) -> bool:
	var de = gm.get("demo_ending")
	return gm.get("game_over_active") == true or (de is Dictionary and str(de.get("state", "")) == "ended")


func _check_tired(before: float, after: float, cfg: Dictionary) -> void:
	var t := float(cfg.get("tired", -1.0))
	var gm := _gm()
	if t < 0.0 or gm == null or before >= t or after < t or _tired_day == int(gm.current_day):
		return
	_tired_day = int(gm.current_day)
	NotificationManager.show_banner(str(Rules.text("tired")), true)
	print("[DayClock] tired: %s, day %d" % [Rules.format_time(after), int(gm.current_day)])


## A night begins (the bedroom's Sleep, or the nod-off): the clock jumps to the day's end, late_night is sent if it
## wasn't, and nothing ticks until begin_day(). False when a night is already under way.
func end_day(reason: String) -> bool:
	if _ending != "":
		return false
	var gm := _gm()
	if gm == null:
		return false
	_ending = reason
	var cfg: Dictionary = gm.day_clock_config()
	if gm.day_clock_minutes < float(cfg.end):
		gm.day_clock_minutes = float(cfg.end)
	_sync()
	print("[DayClock] night: %s, day %d" % [reason, int(gm.current_day)])
	return true


## The morning (after advance_day reset the minutes): "morning" sent, the clock runs again, the overlay lifts.
func begin_day() -> void:
	_ending = ""
	_tired_day = -1
	var gm := _gm()
	if gm != null and not _quiet(gm):
		_sync()
	_lift_overlay(false)


## F12: the clock forward to `target` minutes, sending the crossed phases in order. Earlier than now, past the end, or
## during a night: refused (false) with a log line.
func jump_to(target: float) -> bool:
	var gm := _gm()
	if gm == null:
		return false
	var cfg: Dictionary = gm.day_clock_config()
	var m: float = gm.day_clock_minutes
	if _ending != "" or target < m or target > float(cfg.end):
		print("[DayClock] refuse: jump to %s (now %s%s)" % [Rules.format_time(target), Rules.format_time(m), ", a night" if _ending != "" else ""])
		return false
	gm.day_clock_minutes = target
	_sync()
	_check_tired(m, target, cfg)
	print("[DayClock] jump: %s -> %s" % [Rules.format_time(m), Rules.format_time(target)])
	return true


## 2:00 (K-16): the hall's bedroom sleeps "nod_off"; outside (no bedroom here), the night is taken to the hall (CL-16).
func _nod_off() -> void:
	if _ending != "":
		return
	var tree := get_tree()
	var bed := _bedroom(tree)
	if bed != null:
		print("[DayClock] nod-off in the hall, day %d" % int(_gm().current_day))
		bed.start_sleep_sequence(NOD_OFF)
		if _ending == "":
			end_day(NOD_OFF)   # a bedroom that didn't start the night: still stop here
		return
	var gm := _gm()
	end_day(NOD_OFF)
	_show_overlay(str(Rules.text("nod_off")))
	gm.pending_night = NOD_OFF
	_pending_left = FADE_SECONDS + PENDING_RETRY_SECONDS   # the first ask goes after the fade; a retry only after that
	print("[DayClock] nod-off outside (%s), day %d: to the hall" % [tree.current_scene.name if tree.current_scene else "?", int(gm.current_day)])
	await tree.create_timer(FADE_SECONDS, true).timeout
	_go_to_hall()


func _go_to_hall() -> void:
	var gm := _gm()
	if gm == null:
		return
	var spot: Vector3 = gm.day_clock_config().wake_spot
	if scene_changer.is_valid():
		scene_changer.call(HALL_SCENE, spot)
		return
	var pm = get_node_or_null("/root/PlayerManager")
	if pm and pm.has_method("transition_to_scene"):
		pm.transition_to_scene(HALL_SCENE, spot)
	else:
		get_tree().change_scene_to_file(HALL_SCENE)


## A pending night (the nod-off outside): once the hall is ready (main_tavern.gd's group "main_tavern" and a bedroom), its
## sleep sequence runs the night. Still outside: ask for the hall again every few seconds (a door transition can swallow
## the first request).
func _serve_pending_night(gm: Node, delta: float) -> void:
	var tree := get_tree()
	var scene := tree.current_scene
	var bed := _bedroom(tree)
	if scene != null and scene.is_in_group("main_tavern") and bed != null:
		var reason := str(gm.pending_night)
		gm.pending_night = ""
		_ending = ""   # the bedroom's sequence starts its own night (end_day) and the morning (begin_day)
		print("[DayClock] the hall: the pending night (%s) runs in the bedroom" % reason)
		bed.start_sleep_sequence(reason)
		return
	if scene != null and scene.is_in_group("main_tavern"):
		return   # the hall is still getting ready
	_pending_left -= delta
	if _pending_left <= 0.0:
		_pending_left = PENDING_RETRY_SECONDS
		var pm = get_node_or_null("/root/PlayerManager")
		if not (pm and pm.get("is_transitioning") == true):
			_go_to_hall()


static func _bedroom(tree: SceneTree) -> Node:
	for n in tree.get_nodes_in_group("bedroom"):
		if is_instance_valid(n) and not n.is_queued_for_deletion() and n.has_method("start_sleep_sequence"):
			return n
	return null


func _show_overlay(line: String) -> void:
	_lift_overlay(true)
	_overlay = CanvasLayer.new()
	_overlay.name = "NodOffOverlay"
	_overlay.layer = OVERLAY_LAYER
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	var black := ColorRect.new()
	black.name = "Black"
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	black.modulate.a = 0.0
	var label := Label.new()
	label.name = "Line"
	label.text = line
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.add_child(label)
	_overlay.add_child(black)
	add_child(_overlay)
	black.create_tween().tween_property(black, "modulate:a", 1.0, FADE_SECONDS)


## The overlay goes (`now`: at once; else a short fade). Nothing when none is up.
func _lift_overlay(now: bool) -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		_overlay = null
		return
	var o := _overlay
	_overlay = null
	if now or not o.is_inside_tree():
		o.queue_free()
		return
	var black := o.get_node_or_null("Black") as CanvasItem
	if black == null:
		o.queue_free()
		return
	var tw := black.create_tween()
	tw.tween_property(black, "modulate:a", 0.0, FADE_SECONDS)
	tw.tween_callback(o.queue_free)


func overlay_up() -> bool:
	return _overlay != null and is_instance_valid(_overlay)


func _gm() -> Node:
	return get_node_or_null("/root/GameManager")
