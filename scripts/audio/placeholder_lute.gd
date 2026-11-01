# placeholder_lute.gd — a PLACEHOLDER lute phrase made in code (Story 9.2; Raphael chose code-made placeholder audio).
# A short plucked-string phrase on a D-dorian pattern, synthesised by Karplus-Strong (a delay line of seeded noise,
# each sample the decayed average of the two oldest: a plucked string), mixed, normalised and packed as a looping
# 16-bit mono AudioStreamWAV at 22050 Hz. No file, no import. The Bard plays it while he performs unless
# data/narrative/bard.json names a real track (music_path; Story 24.5's Bard music replaces it there).
# Deterministic (seeded): the same bytes every time; phrase() caches it for the session. No class_name: loaded by path.
extends RefCounted

const RATE := 22050
const STEP := 0.42          # seconds between notes
const RING := 1.6           # seconds a note rings (then a short fade)
const DECAY := 0.996        # Karplus-Strong's loss per pass
const PEAK := 0.8           # the mix is normalised to this (of full scale)
const TAIL := 0.9           # seconds of quiet ringing at the end, faded out, so the loop seam is soft
## D-dorian, Hz.
const A3 := 220.0
const C4 := 261.63
const D4 := 293.66
const E4 := 329.63
const F4 := 349.23
const G4 := 392.0
const A4 := 440.0
const C5 := 523.25
const D5 := 587.33
## The phrase: [step, frequencies] (a chord is a strum: its notes 25 ms apart).
const PATTERN := [[0, [A3, D4]], [1, [F4]], [2, [A4]], [3, [D5]], [4, [C5]], [5, [A4]], [6, [G4]], [7, [A4]],
	[8, [C4, F4]], [9, [E4]], [10, [D4]], [11, [A3]], [12, [A3, D4, F4]]]

static var _cache: Dictionary = {}


## The phrase for `seed`, built once a session.
static func phrase(seed := 9) -> AudioStreamWAV:
	if not _cache.has(seed):
		_cache[seed] = build(seed)
	return _cache[seed]


## A fresh build (tests compare two for determinism).
static func build(seed := 9) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var last_step := 0
	for p in PATTERN:
		last_step = maxi(last_step, int(p[0]))
	var frames := int((float(last_step) * STEP + RING + TAIL) * RATE)
	var mix := PackedFloat32Array()
	mix.resize(frames)
	for p in PATTERN:
		var t0 := float(p[0]) * STEP
		var notes: Array = p[1]
		for i in notes.size():
			_pluck(mix, int((t0 + 0.025 * i) * RATE), float(notes[i]), 0.5 if notes.size() > 1 else 0.6, rng)
	var peak := 0.0
	for v in mix:
		peak = maxf(peak, absf(v))
	var gain := PEAK / peak if peak > 0.0 else 1.0
	var data := PackedByteArray()
	data.resize(frames * 2)
	var fade_from := frames - int(TAIL * 0.6 * RATE)
	for n in frames:
		var v := mix[n] * gain
		if n >= fade_from:
			v *= 1.0 - float(n - fade_from) / float(frames - fade_from)
		data.encode_s16(n * 2, clampi(int(round(v * 32767.0)), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = frames
	return w


## One plucked note added into `mix` from frame `at`: Karplus-Strong for RING seconds, the last 0.15 s faded.
static func _pluck(mix: PackedFloat32Array, at: int, freq: float, amp: float, rng: RandomNumberGenerator) -> void:
	var period := maxi(2, int(round(float(RATE) / freq)))
	var buf := PackedFloat32Array()
	buf.resize(period)
	for i in period:
		buf[i] = rng.randf_range(-1.0, 1.0)
	var length := int(RING * RATE)
	var fade := int(0.15 * RATE)
	var idx := 0
	for n in length:
		var out := at + n
		if out >= mix.size():
			break
		var nxt := (idx + 1) % period
		var s := buf[idx]
		buf[idx] = (buf[idx] + buf[nxt]) * 0.5 * DECAY
		idx = nxt
		var env := 1.0 if n < length - fade else float(length - n) / float(fade)
		mix[out] += s * amp * env
