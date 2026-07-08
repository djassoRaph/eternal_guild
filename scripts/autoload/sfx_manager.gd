extends Node
## SfxManager — pooled one-shot sound playback, routed to the "SFX" audio bus (Epic 2),
## so every SFX automatically respects the player's SFX volume slider.
##
## Loads streams at runtime and NO-OPS if a file is missing, so the game never crashes
## on a missing/unimported sound. Reuse this for beer-pour, fire-feed, door, etc. —
## do not bolt one-off AudioStreamPlayers onto individual scenes.
##
## Usage:  SfxManager.play("coins")

const BUS_NAME := "SFX"
const POOL_SIZE := 8

# name -> resource path. Add new SFX here.
const SFX_PATHS := {
	"coins": "res://assets/audio/sfx/coins.mp3",
	"cointinkle": "res://assets/audio/sfx/cointinkle.wav",
}

var _players: Array[AudioStreamPlayer] = []
var _streams := {}
var _next: int = 0

func _ready() -> void:
	var bus := BUS_NAME if AudioServer.get_bus_index(BUS_NAME) != -1 else "Master"
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_players.append(p)

	# Preload whatever exists; warn (don't crash) on anything missing/unimported.
	for key in SFX_PATHS:
		var path: String = SFX_PATHS[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
		else:
			push_warning("SfxManager: sfx '%s' not found/imported at %s" % [key, path])

	print("SfxManager ready — bus '%s', %d sound(s) loaded" % [bus, _streams.size()])

## Play a one-shot SFX by name. pitch_variation adds a small random pitch so repeats
## don't sound robotic. Silent no-op if the sound isn't loaded.
func play(sfx_name: String, pitch_variation: float = 0.08) -> void:
	if not _streams.has(sfx_name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sfx_name]
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.play()
