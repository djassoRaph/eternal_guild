# name_generator.gd — per-run place names for World Gen v2 (Raphael 2026-11-07: "we need the name generation too that
# azgaar has"). A syllable Markov chain in the spirit of Azgaar's Fantasy Map Generator (MIT): each culture's sample
# names (data/world/name_bases.json) are cut into short syllables; the chain maps the last letter written to the
# syllables that followed that letter in the samples, and a new name is walked from a start syllable until a sample
# could have ended there. Written from the idea; no code was taken from it.
# A name is turned down when it is too short or too long, has no vowel, piles up consonants or vowels, stutters (a
# letter pair said twice, "erer"), holds a blocked letter run (the JSON's "blocked": crude or unlucky words), copies a
# sample, or was already handed out this run; doubled letters survive only where the base allows them.
# Canon (narrative-design.md): proper nouns are generated per run, so a base holds sound samples, never canon names.
# Seeded by the caller's RandomNumberGenerator: one seed names one world the same way every time. Loaded by path.
extends RefCounted

const DATA_PATH := "res://data/world/name_bases.json"
const VOWELS := "aeiouy"
const MAX_TRIES := 60
## Used when the JSON is missing or broken: one plain base, no forms (a feature is then just its name).
const FALLBACK := {
	"bases": {"common": {"label": "Common", "min": 4, "max": 10, "double": "lst",
		"samples": ["Ashby", "Barrowdale", "Bellmere", "Brightwater", "Caldmoor", "Dunmere", "Elmstead", "Fernley",
			"Greywater", "Hartwell", "Larkhill", "Millbrook", "Oakhurst", "Redbank", "Stillwater", "Thornbury",
			"Willowmere", "Wrenfield"]}},
	"blocked": ["ass", "shit", "fuck", "cunt", "cock", "dick", "piss", "slut", "tit", "cum", "fag", "nig", "rape",
		"porn", "anal", "anus", "nazi", "sex", "butt"],
	"forms": {}}

var _rng: RandomNumberGenerator
var _bases := {}   # id -> {chain, samples, min, max, double, label}
var _forms := {}   # feature kind -> Array of "{name}" templates
var _blocked: Array = []   # lower-case letter runs no name may contain
var _used := {}    # every name handed out this run (lower case)


func _init(rng: RandomNumberGenerator, path: String = DATA_PATH) -> void:
	_rng = rng
	var data := _load(path)
	var bases = data.get("bases", {})
	if bases is Dictionary:
		for id in bases:
			var b = bases[id]
			if b is Dictionary and b.get("samples") is Array and not (b.samples as Array).is_empty():
				_bases[str(id)] = _build(b)
	if _bases.is_empty():
		for id in FALLBACK.bases:
			_bases[id] = _build(FALLBACK.bases[id])
	var forms = data.get("forms", {})
	_forms = forms if forms is Dictionary else {}
	var blocked = data.get("blocked", FALLBACK.blocked)
	for b in (blocked if blocked is Array else FALLBACK.blocked):
		_blocked.append(str(b).to_lower())


func base_ids() -> Array:
	return _bases.keys()


func has_base(id: String) -> bool:
	return _bases.has(id)


## A new name in culture `base_id` (the first base when that one doesn't exist).
func make(base_id: String) -> String:
	var b: Dictionary = _bases.get(base_id, _bases.values()[0])
	for t in MAX_TRIES:
		var w := _clean(_walk(b), b)
		if w.length() < b.min or w.length() > b.max or not _well_formed(w):
			continue
		if b.samples.has(w) or _used.has(w) or _blocked.any(func(x): return x in w):
			continue
		_used[w] = true
		return w.capitalize()
	# The chain ran dry (a tiny base): a sample with a letter from another, so it still differs from the sample.
	var keys: Array = b.samples.keys()
	var s: String = keys[_rng.randi_range(0, keys.size() - 1)]
	return (s + VOWELS[_rng.randi_range(0, 4)]).capitalize()


## A feature's full name: a new name in `base_id`, written with one of `kind`'s forms ("River {name}", "Lake {name}").
func place(kind: String, base_id: String) -> String:
	var n := make(base_id)
	var forms = _forms.get(kind, [])
	if not forms is Array or (forms as Array).is_empty():
		return n
	var s := str(forms[_rng.randi_range(0, forms.size() - 1)]).replace("{name}", n)
	return s.substr(0, 1).to_upper() + s.substr(1)


func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("[NameGenerator] %s not found; using the fallback base" % path)
		return FALLBACK
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("[NameGenerator] %s could not be read; using the fallback base" % path)
		return FALLBACK
	return parsed


func _build(b: Dictionary) -> Dictionary:
	var chain := {}
	var samples := {}
	for s in b.samples:
		var w := str(s).to_lower().strip_edges()
		if w.length() < 2:
			continue
		samples[w] = true
		var key := ""
		for syl in _syllables(w):
			if not chain.has(key):
				chain[key] = []
			chain[key].append(syl)
			key = syl.substr(syl.length() - 1)
		if not chain.has(key):
			chain[key] = []
		chain[key].append("")   # a sample ended after this letter: so may a new name
	return {"chain": chain, "samples": samples, "min": int(b.get("min", 4)), "max": int(b.get("max", 10)),
		"double": str(b.get("double", "")), "label": str(b.get("label", ""))}


## A word cut into syllables: the consonants before a vowel group, the vowel group, and one more consonant when two
## consonants meet ("brightwater" -> brig, htwa, ter); a last lone consonant joins the syllable before it.
func _syllables(w: String) -> Array:
	var out := []
	var n := w.length()
	var i := 0
	while i < n:
		var j := i
		while j < n and not _is_vowel(w[j]):
			j += 1
		while j < n and _is_vowel(w[j]):
			j += 1
		if j >= n - 1:
			j = n
		elif j + 1 < n and not _is_vowel(w[j + 1]):
			j += 1
		if j == i:
			j = i + 1
		out.append(w.substr(i, j - i))
		i = j
	return out


func _walk(b: Dictionary) -> String:
	var chain: Dictionary = b.chain
	var w := ""
	var key := ""
	for step in 14:
		var opts: Array = chain.get(key, [])
		if opts.is_empty():
			break
		var syl: String = opts[_rng.randi_range(0, opts.size() - 1)]
		if syl == "":
			if w.length() >= b.min:
				break
			continue
		if w.length() + syl.length() > b.max + 1:
			break
		w += syl
		key = syl.substr(syl.length() - 1)
	return w


func _clean(w: String, b: Dictionary) -> String:
	var out := ""
	for ch in w:
		var n := out.length()
		if n >= 2 and out[n - 1] == ch and out[n - 2] == ch:
			continue
		if n >= 1 and out[n - 1] == ch and not ch in b.double:
			continue
		out += ch
	return out


## At least one vowel, never more than three consonants or three vowels in a row, and no letter pair said twice
## running ("glenmerere").
func _well_formed(w: String) -> bool:
	for i in range(w.length() - 3):
		if w.substr(i, 2) == w.substr(i + 2, 2):
			return false
	var cons := 0
	var vows := 0
	var any_vowel := false
	for ch in w:
		if _is_vowel(ch):
			vows += 1
			cons = 0
			any_vowel = true
		else:
			cons += 1
			vows = 0
		if cons > 3 or vows > 3:
			return false
	return any_vowel and w.length() >= 2


func _is_vowel(ch: String) -> bool:
	return ch in VOWELS
