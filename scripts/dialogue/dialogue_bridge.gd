# dialogue_bridge.gd — what a .dialogue file may read of the game (Story 10.2, AC 4).
#
# Dialogue Manager resolves a name in a condition, mutation or {{…}} through its game states; the
# DialogueBox passes this object as `bridge` ({"bridge": DialogueBridge}), so files say
# `if bridge.deaths_this_run > 0` or `do bridge.mark_seen("den_fa_first_contact")`, never `GameManager.x`
# (Test 20 lints every .dialogue under data/dialogue/ against this script's names).
# Every value is read live from GameManager / DataManager by their autoload names (NFR-9) and is
# read-only; the conversation flags are the one thing a conversation writes (saved per run).
# No class_name (S8): preloaded by path (dialogue_runner.gd).
extends RefCounted

## The guild's reputation points (GameManager.tavern_reputation).
var reputation: int:
	get:
		return GameManager.tavern_reputation
	set(_v):
		_read_only("reputation")

## The current reputation tier's label ("Unknown", "Known", "Trusted", "Respected", "Honored").
var reputation_tier: String:
	get:
		return str(GameManager.get_reputation_tier().get("label", "Unknown"))
	set(_v):
		_read_only("reputation_tier")

## The current tier's index (0 = Unknown … 4 = Honored): GameManager's, from the same sorted list as the label.
var reputation_tier_index: int:
	get:
		return GameManager.get_reputation_tier_index()
	set(_v):
		_read_only("reputation_tier_index")

var day: int:
	get:
		return GameManager.current_day
	set(_v):
		_read_only("day")

## Adventurers on the roster now.
var roster_size: int:
	get:
		return GameManager.adventurers.size()
	set(_v):
		_read_only("roster_size")

## Adventurers hired this run (every successful hire, including those since dead or dismissed).
var adventurers_hired: int:
	get:
		return GameManager.adventurers_hired_this_run
	set(_v):
		_read_only("adventurers_hired")

var deaths_this_run: int:
	get:
		return GameManager.deaths_this_run
	set(_v):
		_read_only("deaths_this_run")

var gold: int:
	get:
		return GameManager.gold
	set(_v):
		_read_only("gold")

## Den Fa's state: "early", "mid" or "late" (Story 10.3; GameManager.den_fa_state, forward only).
var den_fa_state: String:
	get:
		return GameManager.den_fa_state
	set(_v):
		_read_only("den_fa_state")

## The demo build's profile (game_config.json "profile").
var is_demo: bool:
	get:
		return str(DataManager.get_config("profile", "full")) == "demo"
	set(_v):
		_read_only("is_demo")


## Whether a conversation flag is set this run (e.g. "den_fa_first_contact").
func seen(id: String) -> bool:
	return GameManager.dialogue_flags.get(id, false) == true


## Set a conversation flag for the rest of the run (saved with the run).
func mark_seen(id: String) -> void:
	GameManager.dialogue_flags[id] = true


func _read_only(what: String) -> void:
	push_warning("[Dialogue] ignore: bridge.%s is read-only (a .dialogue file tried to set it)" % what)
