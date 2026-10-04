# tavern_lighting.gd — the hall's light: its mood and its day phase (Story 25.23; R-4, catalogue V10, V11).
#
# Two axes, picked by eye, never locked in code (LM-1). A MOOD is the hall's base lighting: "today" (the scene as
# saved, snapshotted at _ready: LM-2), or a game_config.json › tavern_light_moods preset (moody_a, moody_b, ...). A
# PHASE (morning, day, dusk, evening, late_night, dawn: tavern_light_phases) is a set of multipliers and a window
# colour on top of the mood; "day" is the identity, so the mood Raphael picks is what he sees in play. Moods switch
# at once (a dev/pick action, LM-4); phases blend every number over tavern_light_blend_seconds.
#
# The ink light (LM-3): the edge pass (edge_detection.gdshader light()) multiplies the screen by every
# DirectionalLight reaching the EdgeQuad. So the hall keeps exactly one ("Outdoors Light") and this script NEVER
# writes its transform, colour or energy: a mood only chooses whether it ALSO lights the hall (sun_lights_hall:
# true = its saved cull mask, false = the EdgeQuad's layer 20 alone, a pure ink light).
#
# Shadows are data (LM-5): a mood lists the lights that cast (shadow_lights: hearth, bar, desk, fill); candles and
# window lights never do. Hard edges (shadow_blur 0, light_size 0). The hearth's light is scaled through hearth.gd's
# light_scale: hearth.gd owns the fire's energy and colour (the bands, the flicker), this script never writes them.
# Warm pools (LM-6): OmniLights at flames the hall already shows, group "tavern_candle", saved hidden with their
# authored energy as metadata base_energy (energy = base_energy x candle_scale). Window light (LM-7): unshadowed
# SpotLight3Ds outside the window walls, group "tavern_window" (energy = base_energy x window_energy), and additive
# light cards through the openings, group "tavern_window_card" (the fog-shaft spike failed: an orthographic view
# renders volumetric fog as a flat haze). The round bar shows no flame: BarPool is a warm light over it with no lamp
# of its own (bar_pool_energy, today 0), the moody presets' answer to faces at the bar (AC 5).
#
# Phase triggers (LM-8): GameBus.day_phase_changed(phase), sent where the loop already turns (the bedroom: evening;
# sleep: late_night; the new day: morning; the briefing's end: day). "reveal" (Story 24.2's word) is late_night.
# A morning with no briefing pending turns to day after tavern_light_morning_hold_seconds.
#
# The logic is static and node-free (tests call it); the node only applies the result. Loaded by path: no class_name.
# Dev selector (debug builds): 1 the mood, 2 the phase, 3 the cast's shading preset (anime_look.gd), 4 the edge pass on/off.
extends Node

const GAME_CONFIG_PATH := "res://data/config/game_config.json"
const ANIME_LOOK := preload("res://scripts/game/anime_look.gd")
const TODAY := "today"
const INK_LAYER_MASK := 524288      # render layer 20: the EdgeQuad's alone
const PHASES := ["morning", "day", "dusk", "evening", "late_night", "dawn"]
const PHASE_ALIASES := {"reveal": "late_night"}
const SHADOW_NAMES := ["hearth", "bar", "desk", "fill"]
const OMNI_MODES := {"dual_paraboloid": OmniLight3D.SHADOW_DUAL_PARABOLOID, "cube": OmniLight3D.SHADOW_CUBE}
const DEFAULT_BLEND_SECONDS := 4.0
const DEFAULT_MORNING_HOLD := 20.0
const DEFAULT_PHASE := "day"
## "today": MainTavern's light as saved on 2026-10-04 (the story's table), in this script's terms. The node snapshots
## the real scene at _ready (and Test 25 pins the scene to these numbers). The ambient: no source is set, so the
## Background source renders, i.e. the project's clear colour (0.3 grey) x 1 (T1 measured it; the Environment's own
## ambient colour (0.4, 0.5, 0.7) x 0.3 is NOT what renders).
const TODAY_VALUES := {
	"ambient_background": true,
	"ambient_color": Color(0.3, 0.3, 0.3),
	"ambient_energy": 1.0,
	"sun_lights_hall": true,
	"fill_energy": 2.0,
	"bar_energy": 1.5,
	"desk_energy": 1.5,
	"bar_pool_energy": 0.0,
	"hearth_scale": 1.0,
	"candle_scale": 0.0,
	"window_color": Color(1.0, 0.95, 0.85),
	"window_energy": 0.0,
	"shadow_lights": [],
	"omni_shadow_mode": "cube",
	"pillar_glow": 1.0,
	"exposure": 1.0,
}
## A mood's keys: [kind, min, max]. A missing or bad value takes "today"'s, with a warning.
const MOOD_KEYS := {
	"ambient_color": ["color", 0.0, 1.0],
	"ambient_energy": ["number", 0.0, 4.0],
	"sun_lights_hall": ["bool"],
	"fill_energy": ["number", 0.0, 8.0],
	"bar_energy": ["number", 0.0, 8.0],
	"desk_energy": ["number", 0.0, 8.0],
	"bar_pool_energy": ["number", 0.0, 8.0],
	"hearth_scale": ["number", 0.05, 4.0],
	"candle_scale": ["number", 0.0, 4.0],
	"window_color": ["color", 0.0, 1.0],
	"window_energy": ["number", 0.0, 8.0],
	"shadow_lights": ["shadows"],
	"omni_shadow_mode": ["mode"],
	"pillar_glow": ["number", 0.6, 2.0],
	"exposure": ["number", 0.25, 4.0],
}
## A phase's multipliers [min, max]; window_color (optional: absent = the mood's) replaces the mood's colour.
const PHASE_SCALES := {
	"ambient_scale": [0.0, 4.0],
	"candle_scale": [0.0, 4.0],
	"hearth_scale": [0.1, 4.0],
	"fill_scale": [0.0, 4.0],
	"pillar_glow_scale": [0.3, 3.0],
	"window_energy": [0.0, 4.0],
}

static var last_warning := ""
static var _moods := {}            # config mood name -> entry
static var _phases := {}           # phase name -> entry
static var _cfg := {}
static var _loaded := false

## Bodies' shading preset cycling (key 3) and the hall's lights. Paths are relative to this node
## (TavernNavigation/Environment/TavernLighting in MainTavern).
@export var env_path := NodePath("../WorldEnvironment")
@export var sun_path := NodePath("../Outdoors Light")
@export var fill_path := NodePath("../TavernLight")
@export var bar_path := NodePath("../BarLight")
@export var desk_path := NodePath("../../Furniture/GuildDesk/DeskLight")
## The round bar's warm pool (a light with no lamp of its own: the bar shows no flame; optional, today off).
@export var bar_pool_path := NodePath("../BarPool")
@export var hearth_path := NodePath("../../Furniture/Hearth")
@export var pillar_path := NodePath("../../Architecture/HourglassPillar")
@export var hearth_probe_path := NodePath("../../../HearthProbe")
@export var bar_probe_path := NodePath("../../../BarProbe")
## The subtree whose tavern_candle / tavern_window lights this node drives (the hall's SubViewport).
@export var scope_path := NodePath("../../..")
## Keys 1 / 2 / 3 / 4 in debug builds.
@export var dev_keys := true

var mood := TODAY
var phase := DEFAULT_PHASE
var today := {}                    # the scene's saved light, in TODAY_VALUES's terms
var applied := {}                  # the values applied last
var applied_count := 0             # nodes touched by the last apply (a half-initialised controller shows here)

var _env: WorldEnvironment
var _sun: DirectionalLight3D
var _fill: Light3D
var _bar: Light3D
var _desk: Light3D
var _bar_pool: Light3D
var _hearth: Node3D
var _fire: OmniLight3D
var _pillar: Node3D
var _probes: Array = []
var _scope: Node
var _saved := {}                   # node -> {property: saved value} (restored when a mood doesn't use them)
var _env_saved := {}
var _sun_mask := 4294967295
var _from := {}
var _to := {}
var _blend_t := 1.0
var _blend_len := 0.0
var _hold_left := -1.0
var _pending_phase := ""
var _pending_mood := ""
var _label: Label = null
var _label_left := 0.0


# ---------------------------------------------------------------- static: data ----------------------------------

## Re-read game_config.json (after tuning numbers). Returns the configured mood (resolved).
static func reload_config() -> String:
	var cfg = null
	if FileAccess.file_exists(GAME_CONFIG_PATH):
		cfg = JSON.parse_string(FileAccess.get_file_as_string(GAME_CONFIG_PATH))   # Godot's parser: lenient, like DataManager's
	load_config(cfg if cfg is Dictionary else {})
	return configured_mood()


## Take the lighting keys from a config dictionary (game_config.json's, or a test's fixture).
static func load_config(cfg: Dictionary) -> void:
	_loaded = true
	_cfg = cfg
	_moods.clear()
	_phases.clear()
	var moods = cfg.get("tavern_light_moods", {})
	if not moods is Dictionary:
		_warn("[TavernLighting] tavern_light_moods is not an object; only today")
		moods = {}
	for key in moods:
		var k := str(key)
		if k.begins_with("_"):
			continue
		if k == TODAY or not moods[key] is Dictionary:
			_warn("[TavernLighting] tavern_light_moods.%s ignored (%s)" % [k, "today is the scene as saved" if k == TODAY else "not an object"])
			continue
		_moods[k] = moods[key]
	var phases = cfg.get("tavern_light_phases", {})
	if phases is Dictionary:
		for key in phases:
			if not str(key).begins_with("_") and phases[key] is Dictionary:
				_phases[str(key)] = phases[key]


static func _ensure() -> void:
	if not _loaded:
		reload_config()


## Every mood: "today", then the config's.
static func mood_names() -> Array:
	_ensure()
	return [TODAY] + _moods.keys()


## A mood name if known, else "today" with a warning.
static func resolve_mood(mood_name: String) -> String:
	_ensure()
	if mood_name == TODAY or _moods.has(mood_name):
		return mood_name
	_warn("[TavernLighting] unknown mood '%s' (known: %s); using today" % [mood_name, mood_names()])
	return TODAY


## game_config.json › tavern_light_mood, resolved.
static func configured_mood() -> String:
	_ensure()
	var want = _cfg.get("tavern_light_mood", TODAY)
	return resolve_mood(str(want) if want is String else TODAY)


static func phase_default() -> String:
	_ensure()
	var p := resolve_phase(str(_cfg.get("tavern_light_phase_default", DEFAULT_PHASE)))
	return p if p != "" else DEFAULT_PHASE


static func blend_seconds() -> float:
	_ensure()
	return _positive(_cfg.get("tavern_light_blend_seconds", DEFAULT_BLEND_SECONDS), DEFAULT_BLEND_SECONDS, "tavern_light_blend_seconds")


static func morning_hold_seconds() -> float:
	_ensure()
	return _positive(_cfg.get("tavern_light_morning_hold_seconds", DEFAULT_MORNING_HOLD), DEFAULT_MORNING_HOLD, "tavern_light_morning_hold_seconds")


## A phase name ("reveal" is late_night), or "" (with a warning) when unknown.
static func resolve_phase(phase_name: String) -> String:
	var p: String = PHASE_ALIASES.get(phase_name, phase_name)
	if p in PHASES:
		return p
	_warn("[TavernLighting] unknown phase '%s' (known: %s)" % [phase_name, PHASES])
	return ""


## A mood's full values: today's (`today_values`, the scene's snapshot) for "today"; for a config mood, each key
## checked (a missing or bad value: today's, with a warning). Config moods always use an explicit ambient colour.
static func mood_params(mood_name: String, today_values: Dictionary = TODAY_VALUES) -> Dictionary:
	_ensure()
	var out := today_values.duplicate(true)
	if mood_name == TODAY or not _moods.has(mood_name):
		if mood_name != TODAY:
			resolve_mood(mood_name)        # the warning
		return out
	var entry: Dictionary = _moods[mood_name]
	out.ambient_background = false
	for key in MOOD_KEYS:
		if not entry.has(key):
			_warn("[TavernLighting] mood '%s' has no %s; using today's (%s)" % [mood_name, key, today_values.get(key)])
			continue
		var spec: Array = MOOD_KEYS[key]
		var got = _check(entry[key], spec)
		if got == null:
			_warn("[TavernLighting] mood '%s' %s = %s is not valid; using today's (%s)" % [mood_name, key, entry[key], today_values.get(key)])
			continue
		if key == "shadow_lights":
			var keep := []
			for n in got:
				if str(n) in SHADOW_NAMES:
					keep.append(str(n))
				else:
					_warn("[TavernLighting] mood '%s' shadow_lights: '%s' can't cast (only %s; candles and windows never do)" % [mood_name, n, SHADOW_NAMES])
			got = keep
		out[key] = got
	return out


## A phase's multipliers and window colour ("day" is always the identity; an unknown phase: the identity too).
static func phase_params(phase_name: String) -> Dictionary:
	_ensure()
	var out := {"window_color": null}
	for key in PHASE_SCALES:
		out[key] = 1.0
	var p := resolve_phase(phase_name)
	if p == "" or p == "day":
		if p == "day" and _phases.has("day"):
			var d: Dictionary = _phases.day
			var ident := d.keys().all(func(k): return str(k).begins_with("_") or (PHASE_SCALES.has(k) and _num(d[k]) and is_equal_approx(float(d[k]), 1.0)))
			if not ident:
				_warn("[TavernLighting] tavern_light_phases.day must be the identity (every scale 1, no window colour); using the identity")
		return out
	var entry: Dictionary = _phases.get(p, {})
	if entry.is_empty():
		_warn("[TavernLighting] tavern_light_phases has no %s; using the identity" % p)
	for key in PHASE_SCALES:
		if entry.has(key):
			var lim: Array = PHASE_SCALES[key]
			if _num(entry[key]) and float(entry[key]) >= lim[0] and float(entry[key]) <= lim[1]:
				out[key] = float(entry[key])
			else:
				_warn("[TavernLighting] phase '%s' %s = %s is not in %s..%s; using 1" % [p, key, entry[key], lim[0], lim[1]])
	if entry.has("window_color"):
		var c = _check(entry.window_color, ["color", 0.0, 1.0])
		if c == null:
			_warn("[TavernLighting] phase '%s' window_color = %s is not 3 numbers 0..1; using the mood's" % [p, entry.window_color])
		else:
			out.window_color = c
	return out


## A mood's values with a phase on top: the scales multiply, the window colour replaces (when the phase has one).
static func combine(mood_values: Dictionary, phase_values: Dictionary) -> Dictionary:
	var out := mood_values.duplicate(true)
	var amb := float(phase_values.get("ambient_scale", 1.0))
	out.ambient_energy = float(mood_values.ambient_energy) * amb
	if amb != 1.0:
		out.ambient_background = false
	out.candle_scale = float(mood_values.candle_scale) * float(phase_values.get("candle_scale", 1.0))
	out.bar_pool_energy = float(mood_values.get("bar_pool_energy", 0.0)) * float(phase_values.get("candle_scale", 1.0))
	out.hearth_scale = float(mood_values.hearth_scale) * float(phase_values.get("hearth_scale", 1.0))
	out.fill_energy = float(mood_values.fill_energy) * float(phase_values.get("fill_scale", 1.0))
	out.pillar_glow = float(mood_values.pillar_glow) * float(phase_values.get("pillar_glow_scale", 1.0))
	out.window_energy = float(mood_values.window_energy) * float(phase_values.get("window_energy", 1.0))
	if phase_values.get("window_color") is Color:
		out.window_color = phase_values.window_color
	return out


## a -> b at t (0..1): numbers and colours lerp; switches (bools, lists, names) hold a's until t reaches 1.
static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	if t <= 0.0:
		return a.duplicate(true)
	if t >= 1.0:
		return b.duplicate(true)
	var out := a.duplicate(true)
	for k in b:
		if not a.has(k):
			out[k] = b[k]
		elif _num(a[k]) and _num(b[k]):
			out[k] = lerpf(float(a[k]), float(b[k]), t)
		elif a[k] is Color and b[k] is Color:
			out[k] = (a[k] as Color).lerp(b[k], t)
	return out


## The sun's cull mask for these values: its saved mask (with layer 20 kept) when it lights the hall, else layer 20.
static func sun_mask(values: Dictionary, saved_mask: int) -> int:
	return (saved_mask | INK_LAYER_MASK) if values.get("sun_lights_hall", true) else INK_LAYER_MASK


static func _check(v, spec: Array):
	match spec[0]:
		"number":
			return float(v) if _num(v) and float(v) >= spec[1] and float(v) <= spec[2] else null
		"bool":
			return v if v is bool else null
		"color":
			if v is Array and v.size() == 3 and v.all(func(x): return _num(x) and float(x) >= spec[1] and float(x) <= spec[2]):
				return Color(float(v[0]), float(v[1]), float(v[2]))
			return null
		"shadows":
			return v.duplicate() if v is Array and v.all(func(x): return x is String) else null
		"mode":
			return str(v) if v is String and OMNI_MODES.has(str(v)) else null
	return null


static func _num(v) -> bool:
	return (v is float or v is int) and is_finite(float(v))


static func _positive(v, fallback: float, key: String) -> float:
	if _num(v) and float(v) > 0.0:
		return float(v)
	_warn("[TavernLighting] %s = %s is not a positive number; using %s" % [key, v, fallback])
	return fallback


static func _warn(msg: String) -> void:
	last_warning = msg
	push_warning(msg)


# ---------------------------------------------------------------- the node ---------------------------------------

func _ready() -> void:
	_env = get_node_or_null(env_path) as WorldEnvironment
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	_fill = get_node_or_null(fill_path) as Light3D
	_bar = get_node_or_null(bar_path) as Light3D
	_desk = get_node_or_null(desk_path) as Light3D
	_bar_pool = get_node_or_null(bar_pool_path) as Light3D
	_hearth = get_node_or_null(hearth_path) as Node3D
	_fire = _hearth.get_node_or_null("FireLight") as OmniLight3D if _hearth else null
	_pillar = get_node_or_null(pillar_path) as Node3D
	_scope = get_node_or_null(scope_path)
	for p in [hearth_probe_path, bar_probe_path]:
		var probe := get_node_or_null(p) as ReflectionProbe
		if probe:
			_probes.append(probe)
	for n in ["env", "sun", "fill", "bar", "desk", "hearth", "pillar"]:
		if get("_" + n) == null:
			push_warning("[TavernLighting] %s not found: its light is left as saved" % n)
	# MainTavern's Environment and the window cards' material are sub-resources every instance of the cached scene
	# shares: this hall writes only its own copies, so a reload (Pause -> Load Game -> reload_current_scene) during a
	# dimmed phase still snapshots the scene's saved light as today (LM-2), and each card keeps its own alpha
	if _env and _env.environment:
		_env.environment = _env.environment.duplicate()
	for card in _cards():
		var mi := card as MeshInstance3D
		var m: Material = mi.get_surface_override_material(0)
		if m:
			var own: Material = m.duplicate()
			# no ink on a light card: the editor can drop an unshaded material's saved roughness 0 on a re-save
			if own is BaseMaterial3D:
				(own as BaseMaterial3D).roughness = 0.0
			mi.set_surface_override_material(0, own)
	reload_config()
	for l in _group("tavern_candle") + _group("tavern_window"):
		_base_energy(l)                # the authored energy, once, before any scale is applied
	today = _snapshot()
	var gb := get_node_or_null("/root/GameBus")
	if gb and gb.has_signal("day_phase_changed"):
		gb.day_phase_changed.connect(_on_day_phase)
	mood = _pending_mood if _pending_mood != "" else configured_mood()
	_pending_mood = ""
	var start := _pending_phase if _pending_phase != "" else phase_default()
	_pending_phase = ""
	phase = start
	applied = combine(mood_params(mood, today), phase_params(phase))
	_apply(applied)
	print("[TavernLighting] mood %s, phase %s" % [mood, phase])


func _process(delta: float) -> void:
	if _label_left > 0.0:
		_label_left -= delta
		if _label_left <= 0.0 and is_instance_valid(_label):
			_label.visible = false
	if _hold_left >= 0.0:
		_hold_left -= delta
		if _hold_left < 0.0:
			set_phase("day")
	if _blend_t < 1.0:
		_blend_t = minf(_blend_t + (delta / _blend_len if _blend_len > 0.0 else 1.0), 1.0)
		applied = blend(_from, _to, _blend_t)
		_apply(applied)
		if _blend_t >= 1.0:
			_recapture_probes()


## Switch the mood at once (the phase stays; a running blend ends at its target). Returns the mood now active.
## Before _ready the mood is kept and applied at _ready (instead of the configured one).
func set_mood(mood_name: String) -> String:
	mood = resolve_mood(mood_name)
	if not is_node_ready():
		_pending_mood = mood
		return mood
	_blend_t = 1.0
	applied = combine(mood_params(mood, today), phase_params(phase))
	_apply(applied)
	_recapture_probes()
	return mood


## Blend to a phase over `seconds` (-1: tavern_light_blend_seconds; 0: at once). An unknown phase: no change, a
## warning; "reveal" is late_night. A new phase mid-blend starts from the blended values (no jump).
func set_phase(phase_name: String, seconds := -1.0) -> String:
	var p := resolve_phase(phase_name)
	if p == "":
		return phase
	_hold_left = -1.0
	if not is_node_ready():
		_pending_phase = p
		phase = p
		return phase
	phase = p
	_from = applied.duplicate(true)
	_to = combine(mood_params(mood, today), phase_params(phase))
	_blend_len = blend_seconds() if seconds < 0.0 else seconds
	if _blend_len <= 0.0:
		_blend_t = 1.0
		applied = _to
		_apply(applied)
		_recapture_probes()
	else:
		_blend_t = 0.0
	return phase


## Re-read the config and re-apply the current mood (or the newly configured one when `to_configured`).
func reapply_config(to_configured := false) -> void:
	reload_config()
	set_mood(configured_mood() if to_configured else mood)


## {mood, phase, preset}: what the hall shows now.
func current() -> Dictionary:
	return {"mood": mood, "phase": phase, "preset": ANIME_LOOK.preset(), "blending": _blend_t < 1.0}


func _on_day_phase(phase_name: String) -> void:
	var p := set_phase(phase_name)
	if p == "morning" and PHASE_ALIASES.get(phase_name, phase_name) == "morning":
		var gm := get_node_or_null("/root/GameManager")
		var pending: bool = gm != null and bool(gm.get("has_pending_briefing"))
		if not pending:
			_hold_left = morning_hold_seconds()


## The scene's light as saved, in TODAY_VALUES's terms, plus every property a mood may change (restored later).
func _snapshot() -> Dictionary:
	var t := TODAY_VALUES.duplicate(true)
	if _env and _env.environment:
		var e := _env.environment
		_env_saved = {"ambient_light_source": e.ambient_light_source, "ambient_light_color": e.ambient_light_color,
			"ambient_light_energy": e.ambient_light_energy, "tonemap_exposure": e.tonemap_exposure}
		t.ambient_background = e.ambient_light_source == Environment.AMBIENT_SOURCE_BG and e.background_mode == Environment.BG_CLEAR_COLOR
		if t.ambient_background:
			# the Background source with a clear colour renders the project's clear colour x the bg energy
			var clear: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color", Color(0.3, 0.3, 0.3))
			clear.a = 1.0
			t.ambient_color = clear
			t.ambient_energy = e.background_energy_multiplier
		else:
			t.ambient_color = e.ambient_light_color
			t.ambient_energy = e.ambient_light_energy
		t.exposure = e.tonemap_exposure
	if _sun:
		_sun_mask = _sun.light_cull_mask
		t.sun_lights_hall = _sun_mask & 1 != 0
	for pair in [[_fill, "fill_energy"], [_bar, "bar_energy"], [_desk, "desk_energy"]]:
		if pair[0]:
			t[pair[1]] = (pair[0] as Light3D).light_energy
	var shadowed := []
	for pair in [[_fire, "hearth"], [_fill, "fill"], [_bar, "bar"], [_desk, "desk"]]:
		var l := pair[0] as Light3D
		if l == null:
			continue
		_saved[l] = {"shadow_enabled": l.shadow_enabled, "shadow_blur": l.shadow_blur, "light_size": l.light_size,
			"light_energy": l.light_energy}
		if l is OmniLight3D:
			_saved[l].omni_shadow_mode = (l as OmniLight3D).omni_shadow_mode
		if l.shadow_enabled:
			shadowed.append(pair[1])
	t.shadow_lights = shadowed
	if _fire:
		t.omni_shadow_mode = "cube" if _fire.omni_shadow_mode == OmniLight3D.SHADOW_CUBE else "dual_paraboloid"
	if _hearth and "light_scale" in _hearth:
		t.hearth_scale = float(_hearth.light_scale)
	if _pillar and "glow_energy" in _pillar:
		t.pillar_glow = float(_pillar.glow_energy)
	if _bar_pool:
		t.bar_pool_energy = _bar_pool.light_energy if _bar_pool.visible else 0.0
	var lit := _group("tavern_candle").filter(func(c): return c.visible)
	t.candle_scale = 1.0 if not lit.is_empty() else 0.0
	var wins := _group("tavern_window")
	if not wins.is_empty():
		t.window_color = (wins[0] as Light3D).light_color
		t.window_energy = 1.0 if wins.any(func(w): return w.visible) else 0.0
	return t


func _group(g: String) -> Array:
	if not is_inside_tree():
		return []
	return get_tree().get_nodes_in_group(g).filter(func(n): return n is Light3D and (_scope == null or _scope.is_ancestor_of(n)))


## The light cards through the window openings (group tavern_window_card) in this hall.
func _cards() -> Array:
	if not is_inside_tree():
		return []
	return get_tree().get_nodes_in_group("tavern_window_card").filter(func(n): return n is MeshInstance3D and (_scope == null or _scope.is_ancestor_of(n)))


## A candle's or window light's base energy: its base_energy metadata; a light saved without one gets its energy at
## first sight (_ready, before any scale) stored as that metadata. Never the current energy at apply time: a scale of
## 0 ("today") would zero it for good.
static func _base_energy(l: Light3D) -> float:
	if not l.has_meta("base_energy"):
		l.set_meta("base_energy", l.light_energy)
	return float(l.get_meta("base_energy"))


## Apply values to the hall's nodes. Never writes the sun's transform, colour or energy (LM-3), nor the fire's
## energy or colour (hearth.gd owns them: light_scale only).
func _apply(v: Dictionary) -> void:
	var n := 0
	if _env and _env.environment:
		var e := _env.environment
		if v.ambient_background and today.get("ambient_background", false) \
				and (v.ambient_color as Color).is_equal_approx(today.ambient_color) and is_equal_approx(float(v.ambient_energy), float(today.ambient_energy)):
			e.ambient_light_source = _env_saved.ambient_light_source
			e.ambient_light_color = _env_saved.ambient_light_color
			e.ambient_light_energy = _env_saved.ambient_light_energy
		else:
			e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			e.ambient_light_color = v.ambient_color
			e.ambient_light_energy = float(v.ambient_energy)
		e.tonemap_exposure = float(v.exposure)
		n += 1
	if _sun:
		_sun.light_cull_mask = sun_mask(v, _sun_mask)
		n += 1
	for pair in [[_fill, "fill_energy", "fill"], [_bar, "bar_energy", "bar"], [_desk, "desk_energy", "desk"]]:
		var l := pair[0] as Light3D
		if l:
			l.light_energy = float(v[pair[1]])
			_shadow(l, pair[2] in v.shadow_lights, v)
			n += 1
	if _bar_pool:
		_bar_pool.light_energy = float(v.bar_pool_energy)
		_bar_pool.visible = _bar_pool.light_energy > 0.0005
		_bar_pool.shadow_enabled = false
		n += 1
	if _hearth and "light_scale" in _hearth:
		_hearth.light_scale = float(v.hearth_scale)
		if _fire:
			_shadow(_fire, "hearth" in v.shadow_lights, v)
		n += 1
	if _pillar and "glow_energy" in _pillar:
		_pillar.glow_energy = float(v.pillar_glow)
		n += 1
	for c in _group("tavern_candle"):
		var e := _base_energy(c) * float(v.candle_scale)
		c.light_energy = e
		c.visible = e > 0.0005
		c.shadow_enabled = false
		n += 1
	for w in _group("tavern_window"):
		var e := _base_energy(w) * float(v.window_energy)
		w.light_energy = e
		w.light_color = v.window_color
		w.visible = e > 0.0005
		w.shadow_enabled = false
		n += 1
	# the light cards through the window openings (V11's fake god rays: additive, unshaded quads): the window
	# colour, their alpha x window_energy (their saved alpha is metadata base_alpha; each card's own material copy)
	for card in _cards():
		var mi := card as MeshInstance3D
		var m := mi.get_surface_override_material(0) as StandardMaterial3D
		if m == null:
			continue
		var c: Color = v.window_color
		c.a = clampf(float(mi.get_meta("base_alpha", 0.5)) * float(v.window_energy), 0.0, 1.0)
		m.albedo_color = c
		mi.visible = c.a > 0.002
		n += 1
	applied_count = n


## A light casts (hard edges) when listed, else its saved shadow settings come back.
func _shadow(l: Light3D, on: bool, v: Dictionary) -> void:
	var s: Dictionary = _saved.get(l, {})
	if on:
		l.shadow_enabled = true
		l.shadow_blur = 0.0
		l.light_size = 0.0
		if l is OmniLight3D:
			(l as OmniLight3D).omni_shadow_mode = OMNI_MODES.get(str(v.get("omni_shadow_mode", "dual_paraboloid")), OmniLight3D.SHADOW_DUAL_PARABOLOID)
	elif not s.is_empty():
		l.shadow_enabled = s.shadow_enabled
		l.shadow_blur = s.shadow_blur
		l.light_size = s.light_size
		if l is OmniLight3D and s.has("omni_shadow_mode"):
			(l as OmniLight3D).omni_shadow_mode = s.omni_shadow_mode


## The hearth corner's probes see the new light (Den Fa's mask): HearthProbe has recapture(); a probe without the
## script gets the same Once -> Always for two frames -> Once flip.
func _recapture_probes() -> void:
	for p in _probes:
		if not is_instance_valid(p):
			continue
		if p.has_method("recapture"):
			p.recapture()
		else:
			_flip(p)


static func _flip(p: ReflectionProbe) -> void:
	if not p.is_inside_tree():
		return
	var tree := p.get_tree()
	p.update_mode = ReflectionProbe.UPDATE_ALWAYS
	for i in 2:
		await tree.process_frame
		if not is_instance_valid(p) or not p.is_inside_tree():
			return
	p.update_mode = ReflectionProbe.UPDATE_ONCE


# ---------------------------------------------------------------- the dev selector -------------------------------

func _input(event: InputEvent) -> void:
	if not dev_keys or not OS.is_debug_build():
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return
	# the number row, not F6/F7/F8: Godot 4.4's editor takes those (run scene / pause / stop) when the game is embedded
	# in its Game tab; and never while a text field has the focus
	var focus := get_tree().root.gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	match k.keycode:
		KEY_1:
			var names := mood_names()
			set_mood(names[(names.find(mood) + 1) % names.size()])
		KEY_2:
			set_phase(PHASES[(PHASES.find(phase) + 1) % PHASES.size()])
		KEY_3:
			var presets: Array = ANIME_LOOK.preset_names()
			ANIME_LOOK.set_preset(presets[(presets.find(ANIME_LOOK.preset()) + 1) % presets.size()])
			retone_cast()
		KEY_4:
			toggle_edge_pass()
		_:
			return
	_show_label()


## Dev: show/hide the screen's edge pass (edge_detection.gdshader on the camera's quad, render layer 20) to see the
## hall without the ink. Returns the new visibility (true when there is no quad).
func toggle_edge_pass() -> bool:
	var q := edge_pass()
	if q == null:
		push_warning("[TavernLighting] no edge pass quad under the camera")
		return true
	q.visible = not q.visible
	return q.visible


## The camera's edge pass quad (its MeshInstance3D on the ink layer), or null.
func edge_pass() -> MeshInstance3D:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return null
	for c in cam.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).layers == INK_LAYER_MASK:
			return c
	return null


## Re-tone every body in the hall with the active shading preset (each toned body's mesh parents).
func retone_cast() -> int:
	if _scope == null:
		return 0
	var parents := {}
	for node in _scope.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var toned := ANIME_LOOK.is_toon(mi.material_override)
		for s in (mi.mesh.get_surface_count() if mi.mesh else 0):
			toned = toned or ANIME_LOOK.is_toon(mi.get_surface_override_material(s))
		if toned and mi.get_parent():
			parents[mi.get_parent()] = true
	var n := 0
	for p in parents:
		n += ANIME_LOOK.apply(p)
	return n


func _show_label() -> void:
	if _label == null or not is_instance_valid(_label):
		# on the scene root (the window), not under this node: inside the hall's SubViewport it would draw into the
		# 3D view's own image
		var layer := CanvasLayer.new()
		layer.layer = 101
		var host: Node = get_tree().current_scene if get_tree().current_scene else self
		host.add_child(layer)
		tree_exiting.connect(layer.queue_free)
		_label = Label.new()
		_label.position = Vector2(16, 48)
		_label.add_theme_font_size_override("font_size", 18)
		_label.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
		_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_label.add_theme_constant_override("outline_size", 4)
		layer.add_child(_label)
	var c := current()
	var q := edge_pass()
	_label.text = "[1] mood %s  [2] phase %s  [3] preset %s  [4] edges %s" % [c.mood, c.phase, c.preset, "off" if q and not q.visible else "on"]
	_label.visible = true
	_label_left = 3.0
