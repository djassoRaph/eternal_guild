# story_panels.gd — the hall's story-panel director (Story 10.1, AC 1, 5, 6).
#
# A per-scene Node in group "story_panels" (architecture decisions 3 and 12: UI nodes are not singletons): main_tavern.gd
# adds it at the end of its _ready and, on a NEW run's first hall load (its pending_new_game_save branch), calls
# open_run_start_window(). Content: data/narrative/panels.json (every word DRAFT); timings: game_config.json
# story_panel_hard_gate_seconds and story_panel_input_grace_seconds. Each panel is shown by scripts/ui/story_panel.gd.
# - Triggers (PS-2): run_start (open_run_start_window), day_end (one frame after GameManager.day_changed, once the
#   briefing is gone and none is pending; and once when the hall loads), proximity (the player within trigger.radius m,
#   flat, of trigger.target), event (play(id) now, for a flow that owns the moment: 10.7's court panel; request(id)
#   when the screen is free).
# - One at a time, only while the screen is free (PS-8, screen_free); due panels in file order; the next opens only
#   after the last one's `finished`. play() skips the free check but never opens over another panel.
# - Once per run (PS-5): opening a panel sets dialogue_flags["panel_<id>"] through dialogue_bridge.gd (the one writer of
#   that store: saved with the run, cleared by New Game). A repeatable panel skips the check; a repeatable proximity
#   panel re-arms once the player is radius + 0.5 m away.
# - Pure statics for the data and the rules (parse_panels, conditions_hold, due_ids, screen_free) so tests feed fixtures.
# No class_name: loaded by path.
extends Node

const PANELS_PATH := "res://data/narrative/panels.json"
const BRIDGE_SCRIPT := "res://scripts/dialogue/dialogue_bridge.gd"
const OVERLAY := preload("res://scripts/ui/story_panel.gd")
const ZONE_PROMPT_UI := preload("res://scripts/game/ZonePromptUI.gd")
const KINDS := ["run_start", "day_end", "proximity", "event"]
## A node in one of these is a full-screen moment of its own: no panel opens over it (PS-8).
const BLOCK_GROUPS := ["dialogue_open", "morning_briefing", "card_reveal", "codex_open", "story_panel_open"]
const CONDITION_KEYS := ["min_day", "max_day", "min_deaths", "min_reputation", "profile", "flag", "not_flag"]
const LOOK_COLOURS := ["backdrop", "panel_bg", "border", "title", "ink"]
const ID_PATTERN := "^[a-z0-9_]+$"
const FLAG_PREFIX := "panel_"
const REARM_MARGIN := 0.5
const DEFAULT_HARD_GATE_SECONDS := 3.0
const DEFAULT_GRACE_SECONDS := 0.3

## id -> the parsed panel (parse_panels), in file order.
var panels: Dictionary = {}
## The house style (Colors, illustration_size a Vector2).
var look: Dictionary = {}
var hard_gate_seconds := DEFAULT_HARD_GATE_SECONDS
var grace_seconds := DEFAULT_GRACE_SECONDS
## The panel open now (an overlay), or null.
var current: Node = null
## Ids waiting for a free screen, in order.
var queue: Array = []
## A day_end check is waiting (a day changed, or the hall loaded).
var day_window := false

var _day_window_frame := 0
var _armed: Dictionary = {}     # proximity id -> false while the player hasn't left since it showed
var _warned: Dictionary = {}    # one warning per thing per director
var _bridge = null
var _data_set := false

## The "no panels file" warning, once a session.
static var _file_warned := false


func _ready() -> void:
	add_to_group("story_panels")
	if not _data_set:
		use_data(load_json(PANELS_PATH))
	hard_gate_seconds = _config_seconds("story_panel_hard_gate_seconds", DEFAULT_HARD_GATE_SECONDS)
	grace_seconds = _config_seconds("story_panel_input_grace_seconds", DEFAULT_GRACE_SECONDS)
	GameManager.day_changed.connect(_on_day_changed)
	_open_day_window()   # the load-time check: a quit can't lose an earned day-end panel


## Test seam and loader: parse `data` (panels.json's object, or null) and use it; its warnings are pushed.
func use_data(data) -> void:
	var parsed := parse_panels(data)
	panels = parsed.panels
	look = parsed.look
	_data_set = true
	for w in parsed.warnings:
		if str(w).begins_with("fallback:"):
			if _file_warned:
				continue
			_file_warned = true
		push_warning("[StoryPanels] %s" % w)


func _process(_delta: float) -> void:
	if current != null and not is_instance_valid(current):
		current = null
	if current != null or not screen_free(get_tree()):
		return
	if day_window and Engine.get_process_frames() >= _day_window_frame \
			and get_tree().get_nodes_in_group("morning_briefing").is_empty() and not GameManager.has_pending_briefing:
		day_window = false
		for id in due_ids(panels, "day_end", context(), _seen):
			_enqueue(id)
	if queue.is_empty():
		_check_proximity()
	while not queue.is_empty():
		var id := str(queue.pop_front())
		if why_not(id) == "":
			_open(id)
			return


# === The windows and the calls ===

## A new run's first hall load (main_tavern.gd's pending_new_game_save branch, its only caller): the run_start panels
## not yet seen this run, shown once the screen is free.
func open_run_start_window() -> void:
	for id in due_ids(panels, "run_start", context(), _seen):
		_enqueue(id)


## Show the panel `id` now (no free-screen check: the caller owns the moment, e.g. 10.7's stopped hall). The overlay (its
## `finished` is emitted exactly once), or null: an empty id (a silent off switch), an unknown, disabled or (not
## repeatable) already seen id, conditions that don't hold, or another panel open (one warning each).
func play(id: String) -> Node:
	if id == "":
		return null
	var why := why_not(id)
	if why != "":
		push_warning("[StoryPanels] play: '%s' refused (%s)" % [id, why])
		return null
	return _open(id)


## Queue the panel `id` until the screen is free (an unknown id is warned about and dropped).
func request(id: String) -> void:
	if not panels.has(id):
		push_warning("[StoryPanels] request: '%s' is not a panel: dropped" % id)
		return
	_enqueue(id)


## Why `id` can't open now ("" = it can).
func why_not(id: String) -> String:
	if not panels.has(id):
		return "unknown id"
	var p: Dictionary = panels[id]
	if not bool(p.enabled):
		return "disabled"
	if not bool(p.repeatable) and _seen(id):
		return "seen this run"
	var c := conditions_hold(p.conditions, context())
	if not (c.unknown as Array).is_empty():
		_warn_once("cond:" + id, "condition: %s has unknown keys %s: it never shows" % [id, c.unknown])
		return "unknown condition keys %s" % [c.unknown]
	if not c.ok:
		return "its conditions don't hold"
	if (current != null and is_instance_valid(current)) or not get_tree().get_nodes_in_group("story_panel_open").is_empty():
		return "another panel is open"
	return ""


## The live context the conditions read.
func context() -> Dictionary:
	return {"day": GameManager.current_day, "deaths": GameManager.deaths_this_run, "reputation": GameManager.tavern_reputation,
		"profile": DataManager.get_profile(), "flags": GameManager.dialogue_flags}


func _on_day_changed(_day: int) -> void:
	_open_day_window()


func _open_day_window() -> void:
	day_window = true
	_day_window_frame = Engine.get_process_frames() + 1   # bedroom_popup adds the briefing right after day_changed


func _enqueue(id: String) -> void:
	if not queue.has(id):
		queue.append(id)


func _open(id: String) -> Node:
	var p: Dictionary = panels[id]
	_bridge_obj().mark_seen(FLAG_PREFIX + id)
	if str(p.trigger.type) == "proximity":
		_armed[id] = false
	var o = OVERLAY.new()
	o.panel = p
	var l := look.duplicate()
	l.merge(p.get("look", {}), true)
	o.look = l
	o.panel_id = id
	o.trigger_type = str(p.trigger.type)
	o.min_seconds = float(p.min_seconds) if float(p.min_seconds) >= 0.0 else hard_gate_seconds
	o.grace_seconds = grace_seconds
	o.finished.connect(_on_panel_finished.bind(o))
	var tree := get_tree()
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root
	host.add_child(o)
	current = o
	return o


func _on_panel_finished(o: Node) -> void:
	if current == o:
		current = null


func _check_proximity() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not (player is Node3D):
		return
	var ctx := context()
	for id in panels:
		var p: Dictionary = panels[id]
		if not bool(p.enabled) or str(p.trigger.type) != "proximity":
			continue
		var target := _target(id, str(p.trigger.target))
		if target == null:
			continue
		var d := flat_distance((player as Node3D).global_position, target.global_position)
		var r := float(p.trigger.radius)
		if not bool(_armed.get(id, true)):
			if d > r + REARM_MARGIN:
				_armed[id] = true
			continue
		if d > r or (not bool(p.repeatable) and _seen(id)) or not bool(conditions_hold(p.conditions, ctx).ok):
			continue
		_armed[id] = false
		_enqueue(id)


func _target(id: String, path: String) -> Node3D:
	var scene := get_tree().current_scene
	var n = scene.get_node_or_null(NodePath(path)) if scene != null and path != "" else null
	if n is Node3D:
		return n
	_warn_once("target:" + id, "proximity: %s's target '%s' is not a 3D node in the scene: skipped" % [id, path])
	return null


func _seen(id: String) -> bool:
	return _bridge_obj().seen(FLAG_PREFIX + id)


func _bridge_obj():
	if _bridge == null:
		_bridge = load(BRIDGE_SCRIPT).new()
	return _bridge


func _warn_once(key: String, msg: String) -> void:
	if not _warned.has(key):
		_warned[key] = true
		push_warning("[StoryPanels] %s" % msg)


func _config_seconds(key: String, fallback: float) -> float:
	var v = DataManager.get_config(key, fallback)
	if (v is float or v is int) and float(v) >= 0.0:
		return float(v)
	push_warning("[StoryPanels] fallback: game_config %s '%s' is not a number >= 0: %s" % [key, str(v), fallback])
	return fallback


# === Pure rules (tests feed fixtures) ===

## panels.json read with Godot's parser: the object, or null when the file is missing or unparsable.
static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		return null
	return j.data


## {panels: id -> panel (every key filled, defaults taken), look: the house style, warnings: [String]}. Not an object:
## no panels (a "fallback:" warning). A panel with a bad id, no title or text, or an unknown trigger type (a proximity
## one without a target or a radius > 0) is skipped with a warning; a bad optional value takes its default with one.
## Never fails.
static func parse_panels(data) -> Dictionary:
	var warnings: Array = []
	var out := {"panels": {}, "look": OVERLAY.DEFAULT_LOOK.duplicate(), "warnings": warnings}
	if not (data is Dictionary):
		warnings.append("fallback: %s is missing or unreadable: no story panels" % PANELS_PATH)
		return out
	out.look = parse_look(data.get("look"), OVERLAY.DEFAULT_LOOK, warnings, "look")
	var raw = data.get("panels")
	if not (raw is Dictionary):
		warnings.append("fallback: %s has no panels object: no story panels" % PANELS_PATH)
		return out
	var re := RegEx.create_from_string(ID_PATTERN)
	for key in raw:
		var id := str(key)
		var p = raw[key]
		if re.search(id) == null:
			warnings.append("skip: '%s' is not a panel id (a-z, 0-9, _)" % id)
			continue
		if not (p is Dictionary):
			warnings.append("skip: %s is not an object" % id)
			continue
		var title := str(p.title) if p.get("title") is String else ""
		var text := str(p.text) if p.get("text") is String else ""
		if title == "" or text == "":
			warnings.append("skip: %s has no title or no text" % id)
			continue
		var trig = p.get("trigger")
		var kind := str(trig.get("type", "")) if trig is Dictionary else ""
		if not KINDS.has(kind):
			warnings.append("skip: %s has an unknown trigger type '%s'" % [id, kind])
			continue
		var trigger := {"type": kind}
		if kind == "proximity":
			var target = trig.get("target")
			var radius = trig.get("radius")
			if not (target is String) or str(target) == "" or not (radius is float or radius is int) or float(radius) <= 0.0:
				warnings.append("skip: %s (proximity) needs a target path and a radius > 0" % id)
				continue
			trigger.target = str(target)
			trigger.radius = float(radius)
		var min_s = p.get("min_seconds", -1.0)
		if not (min_s is float or min_s is int) or (p.has("min_seconds") and float(min_s) < 0.0):
			warnings.append("default: %s.min_seconds '%s' is not a number >= 0: the config's" % [id, str(min_s)])
			min_s = -1.0
		var conditions = p.get("conditions", {})
		if not (conditions is Dictionary):
			warnings.append("default: %s.conditions is not an object: none" % id)
			conditions = {}
		out.panels[id] = {
			"title": title, "text": text, "illustration": str(p.get("illustration", "")),
			"pages": _parse_pages(p.get("pages"), id, warnings),
			"skippable": _flag(p, "skippable", true, id, warnings),
			"repeatable": _flag(p, "repeatable", false, id, warnings),
			"enabled": _flag(p, "enabled", true, id, warnings),
			"button": str(p.button) if p.get("button") is String and str(p.button) != "" else "Continue",
			"min_seconds": float(min_s), "trigger": trigger, "conditions": conditions,
			"look": parse_look(p.get("look"), {}, warnings, id + ".look"),
		}
	return out


## The look keys of `raw` over `base`: colours as #RRGGBB(AA), illustration_size [w, h] > 0. A bad value keeps base's
## (a warning); keys starting with _ are comments.
static func parse_look(raw, base: Dictionary, warnings: Array, where: String) -> Dictionary:
	var out := base.duplicate()
	if raw == null:
		return out
	if not (raw is Dictionary):
		warnings.append("look: %s is not an object: the house style" % where)
		return out
	for key in raw:
		var k := str(key)
		var v = raw[key]
		if LOOK_COLOURS.has(k):
			if v is String and Color.html_is_valid(v):
				out[k] = Color.html(v)
			else:
				warnings.append("look: %s.%s '%s' is not a colour: the house style's" % [where, k, str(v)])
		elif k == "illustration_size":
			if v is Array and v.size() == 2 and (v[0] is float or v[0] is int) and (v[1] is float or v[1] is int) \
					and float(v[0]) > 0.0 and float(v[1]) > 0.0:
				out[k] = Vector2(float(v[0]), float(v[1]))
			else:
				warnings.append("look: %s.illustration_size '%s' is not [w, h] > 0: the house style's" % [where, str(v)])
		elif not k.begins_with("_"):
			warnings.append("look: %s.%s is not a look key: ignored" % [where, k])
	return out


## {ok, unknown}: every key of `cond` holds in `ctx` ({day, deaths, reputation, profile, flags}). An unknown key, or a
## number key that isn't a number, makes it not ok and is named in `unknown` (fail closed: a typo never fires a beat).
static func conditions_hold(cond: Dictionary, ctx: Dictionary) -> Dictionary:
	var ok := true
	var unknown: Array = []
	var flags = ctx.get("flags", {})
	if not (flags is Dictionary):
		flags = {}
	for key in cond:
		var k := str(key)
		if k.begins_with("_"):
			continue
		var v = cond[key]
		var is_num: bool = v is float or v is int
		match k:
			"min_day", "max_day", "min_deaths", "min_reputation":
				if not is_num:
					unknown.append(k)
					continue
				var have := float(ctx.get({"min_day": "day", "max_day": "day", "min_deaths": "deaths", "min_reputation": "reputation"}[k], 0))
				ok = ok and (have <= float(v) if k == "max_day" else have >= float(v))
			"profile":
				ok = ok and str(ctx.get("profile", "")) == str(v)
			"flag":
				ok = ok and (flags as Dictionary).get(str(v), false) == true
			"not_flag":
				ok = ok and (flags as Dictionary).get(str(v), false) != true
			_:
				unknown.append(k)
	return {"ok": ok and unknown.is_empty(), "unknown": unknown}


## The enabled panels of trigger `kind` that may show now: not seen (seen.call(id), unless repeatable) and their
## conditions holding; in file order.
static func due_ids(all: Dictionary, kind: String, ctx: Dictionary, seen: Callable) -> Array:
	var out: Array = []
	for id in all:
		var p: Dictionary = all[id]
		if not bool(p.get("enabled", true)) or str((p.get("trigger", {}) as Dictionary).get("type", "")) != kind:
			continue
		if not bool(p.get("repeatable", false)) and bool(seen.call(id)):
			continue
		if not bool(conditions_hold(p.get("conditions", {}), ctx).ok):
			continue
		out.append(id)
	return out


## Whether nothing owns the screen (PS-8): the tree running, not the fall, no conversation / briefing / card reveal /
## Codex / panel, no visible modal (ZonePromptUI.modal_open: a blocks_player or mission_board), the scene's world not
## frozen, no card reveal pending (17.3, when it exists), and a player in group "player".
static func screen_free(tree: SceneTree) -> bool:
	if tree == null or tree.paused:
		return false
	var gm := tree.root.get_node_or_null("GameManager")
	if gm != null and gm.get("game_over_active") == true:
		return false
	for g in BLOCK_GROUPS:
		if not tree.get_nodes_in_group(g).is_empty():
			return false
	if ZONE_PROMPT_UI.modal_open(tree):
		return false
	var scene := tree.current_scene
	if scene != null and scene.has_method("is_world_frozen") and scene.is_world_frozen():
		return false
	var nm := tree.root.get_node_or_null("NotificationManager")
	if nm != null and nm.has_method("card_reveal_pending") and nm.card_reveal_pending():
		return false
	return tree.get_first_node_in_group("player") != null


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _flag(p: Dictionary, key: String, fallback: bool, id: String, warnings: Array) -> bool:
	if not p.has(key):
		return fallback
	if p[key] is bool:
		return p[key]
	warnings.append("default: %s.%s '%s' is not true/false: %s" % [id, key, str(p[key]), fallback])
	return fallback


static func _parse_pages(raw, id: String, warnings: Array) -> Array:
	var out: Array = []
	if raw == null:
		return out
	if not (raw is Array):
		warnings.append("default: %s.pages is not a list: one page" % id)
		return out
	for i in (raw as Array).size():
		var pg = raw[i]
		if pg is Dictionary and pg.get("text") is String and str(pg.text) != "":
			out.append({"illustration": str(pg.get("illustration", "")), "text": str(pg.text)})
		else:
			warnings.append("skip: %s.pages[%d] has no text" % [id, i])
	return out
