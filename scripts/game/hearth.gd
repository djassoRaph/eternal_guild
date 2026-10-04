# hearth.gd
# The Hearth (Story 25.5, catalogue B1 + H3 + V2): the stone hearth, its fire and the firewood.
# fireplace_zone.gd owns the fire's state machine and pushes the fuel here (set_fire_level); this
# script owns the look. fire_look() is the single source of that look and uses the zone's bands
# (> 50 high, > 20 low, > 0 dying, 0 out), so zero Comfort (fuel 0) reads dark (Story 3.2).
# The wood store under the seat shows the firewood stock; Den Fa sits at SitPoint (Story 25.10);
# Onibi will live at the model's onibi_point (Epic 16).
extends Node3D

const MAX_LOGS := 5
const MAX_STORE := 10
const HIGH_FLOOR := 50.0   # = fireplace_zone.gd FUEL_HIGH_FLOOR (failsafe Test 11 checks they agree)
const LOW_FLOOR := 20.0    # = fireplace_zone.gd FUEL_LOW_FLOOR

## Show the faint teal Prior runes on the apron stones.
@export var show_prior_runes := true
## -1 = driven by the fireplace zone; 0..100 = a fixed fuel level (LookDev).
@export var preview_fuel := -1.0
## -1 = follow GameManager's firewood stock; 0..10 = a fixed stock (LookDev).
@export var preview_stock := -1
## Multiplies the fire's light (the hall's mood and day phase, Story 25.23: TavernLighting sets it). The bands,
## the colour, the flames and the ember glow are untouched; a fire that is out stays dark at any scale.
## Assigning it applies it at once; a value set before _ready is kept.
@export var light_scale: float = 1.0: set = set_light_scale

var fuel := 0.0
var placed_logs := 0
var stock := 0

var _look: Dictionary = {}
var _light_base := 0.0
var _flash := 0.0
var _t := 0.0
var _scale_base: Dictionary = {}   # particles -> [scale_min, scale_max]
var _glow: Array = []              # [local ember material, imported emission energy, imported albedo]
var _early_fuel := false           # the zone pushed a fuel level before _ready (node order): keep it

@onready var _light: OmniLight3D = $FireLight
@onready var _flames: GPUParticles3D = $FireParticles
@onready var _sparks: GPUParticles3D = $Embers
@onready var _smoke: GPUParticles3D = $Smoke
@onready var _pile: Node3D = $LogPile
@onready var _store: Node3D = $WoodStore


static func band_for(fuel_percent: float) -> String:
	if fuel_percent <= 0.0:
		return "out"
	if fuel_percent > HIGH_FLOOR:
		return "high"
	if fuel_percent > LOW_FLOOR:
		return "low"
	return "dying"


## The whole look of the fire at a fuel level (0..100). Ratios are 0..1 (particle amount_ratio,
## ember glow); flame_size scales the flame particles; logs = logs burning on the andirons.
static func fire_look(fuel_percent: float) -> Dictionary:
	var f := clampf(fuel_percent, 0.0, 100.0)
	var look := {"band": band_for(f), "color": Color(1.0, 0.3 + 0.5 * f / 100.0, 0.1)}
	match look.band:
		"high":
			var t := (f - HIGH_FLOOR) / (100.0 - HIGH_FLOOR)
			look.merge({"light": lerpf(1.5, 2.4, t), "flames": 1.0, "flame_size": lerpf(0.85, 1.0, t),
				"sparks": lerpf(0.6, 1.0, t), "ember_glow": 1.0, "smoke": 0.25, "logs": 3 + int(round(2.0 * t))})
		"low":
			var t := (f - LOW_FLOOR) / (HIGH_FLOOR - LOW_FLOOR)
			look.merge({"light": lerpf(0.8, 1.4, t), "flames": lerpf(0.4, 0.6, t), "flame_size": lerpf(0.55, 0.75, t),
				"sparks": 0.3, "ember_glow": 0.8, "smoke": 0.4, "logs": 2 + (1 if t >= 0.5 else 0)})
		"dying":
			var t := f / LOW_FLOOR
			look.merge({"light": lerpf(0.35, 0.7, t), "flames": lerpf(0.15, 0.3, t), "flame_size": lerpf(0.3, 0.45, t),
				"sparks": 0.0, "ember_glow": 0.6, "smoke": 0.8, "logs": 1})
		_:
			look.merge({"light": 0.0, "flames": 0.0, "flame_size": 0.0, "sparks": 0.0, "ember_glow": 0.0,
				"smoke": 0.0, "logs": 0})
	return look


## Logs on the andirons: the burning ones plus the logs placed in the open minigame, capped.
static func logs_shown(fuel_percent: float, placed: int) -> int:
	return mini(int(fire_look(fuel_percent).logs) + maxi(placed, 0), MAX_LOGS)


## Logs in the wood store: one per unit of firewood stock.
static func store_shown(stock_units: int) -> int:
	return clampi(stock_units, 0, MAX_STORE)


func _ready() -> void:
	add_to_group("hearth")
	for p in [_flames, _sparks, _smoke]:
		# Local copies: the look changes the process material per instance.
		p.process_material = (p.process_material as ParticleProcessMaterial).duplicate()
		var pm := p.process_material as ParticleProcessMaterial
		_scale_base[p] = [pm.scale_min, pm.scale_max]
	_make_glow_local()
	var runes := find_child("hearth_runes", true, false) as Node3D
	if runes:
		runes.visible = show_prior_runes
	var gm := get_node_or_null("/root/GameManager")
	if preview_stock >= 0:
		set_stock(preview_stock)
	elif gm:
		gm.firewood_changed.connect(set_stock)
		set_stock(int(gm.get_firewood_stock()))
	else:
		set_stock(0)
	if preview_fuel >= 0.0:
		set_fire_level(preview_fuel)
	elif _early_fuel:
		set_fire_level(fuel)
	else:
		set_fire_level(float(gm.get_fireplace_fuel()) if gm else 0.0)


func _process(delta: float) -> void:
	# The flash fades even while the light is hidden, so it can't fire late when the fire relights.
	_flash = maxf(_flash - delta * 1.4, 0.0)
	if not _light.visible:
		return
	_t += delta
	var flicker := 1.0 + 0.07 * sin(_t * 11.0) + 0.04 * sin(_t * 23.7 + 1.3)
	_light.light_energy = _light_base * flicker * (1.0 + 0.8 * _flash) * light_scale


## Called by fireplace_zone.gd on every fuel change (0..100).
func set_fire_level(fuel_percent: float) -> void:
	fuel = clampf(fuel_percent, 0.0, 100.0)
	if not is_node_ready():   # the zone can be ready first if node order changes: _ready applies it
		_early_fuel = true
		return
	_look = fire_look(fuel)
	_light_base = _look.light
	_light.visible = _look.light > 0.0
	_light.light_color = _look.color
	_light.light_energy = _light_base * light_scale
	_drive(_flames, _look.flames, _look.flame_size)
	_drive(_sparks, _look.sparks, 1.0)
	_drive(_smoke, _look.smoke, 1.0)
	for g in _glow:
		# A cold bed goes ash-dark, not just unlit: the imported albedo alone still reads orange.
		(g[0] as StandardMaterial3D).emission_energy_multiplier = float(g[1]) * float(_look.ember_glow)
		(g[0] as StandardMaterial3D).albedo_color = (g[2] as Color).darkened(0.65 * (1.0 - float(_look.ember_glow)))
	_show_logs()


## The fire light's multiplier (Story 25.23): clamps at 0, NaN/inf -> 1. Before _ready it is only stored
## (_ready's set_fire_level applies it); after, the light changes at once.
func set_light_scale(value: float) -> void:
	light_scale = maxf(value, 0.0) if is_finite(value) else 1.0
	if is_node_ready() and _light.visible:
		_light.light_energy = _light_base * light_scale


## Logs placed so far in the open minigame (0 when it closes).
func set_placed_logs(count: int) -> void:
	placed_logs = clampi(count, 0, MAX_LOGS)
	if is_node_ready():
		_show_logs()


func set_stock(units: int) -> void:
	stock = units
	if not is_node_ready():
		return
	var n := store_shown(units)
	for i in _store.get_child_count():
		(_store.get_child(i) as Node3D).visible = i < n


## A successful light: a flash of light and a fresh burst of flame.
func play_ignition() -> void:
	_flash = 1.0
	if is_node_ready() and _flames.emitting:
		_flames.restart()


func _drive(p: GPUParticles3D, ratio: float, size: float) -> void:
	p.emitting = ratio > 0.0
	p.amount_ratio = clampf(ratio, 0.0, 1.0)   # never touch `amount`: it restarts the emitter
	var pm := p.process_material as ParticleProcessMaterial
	pm.scale_min = _scale_base[p][0] * size
	pm.scale_max = _scale_base[p][1] * size


func _show_logs() -> void:
	var n := logs_shown(fuel, placed_logs)
	for i in _pile.get_child_count():
		(_pile.get_child(i) as Node3D).visible = i < n


## Imported materials are shared resources: give this instance its own ember material.
func _make_glow_local() -> void:
	var bed := find_child("ember_bed", true, false) as MeshInstance3D
	if bed == null or bed.mesh == null:
		push_warning("[Hearth] ember_bed missing")
		return
	for s in bed.mesh.get_surface_count():
		var mat := bed.mesh.surface_get_material(s) as StandardMaterial3D
		if mat and mat.emission_enabled:
			var local := mat.duplicate() as StandardMaterial3D
			bed.set_surface_override_material(s, local)
			_glow.append([local, mat.emission_energy_multiplier, mat.albedo_color])
