# map_places.gd — what the world map says about its settlements and monuments (2026-11-08): the hover's one line and
# the click panel's extra lines, shared by the map table (New Game, scripts/world/map_table.gd) and the hall's World
# Map (scenes/world/world_map_board.gd). World Gen v2 sets the record keys (town_tier, town_variant, city_of,
# monument, monument_name, landmark, landmark_name). DRAFT words throughout. Loaded by path, no class_name.
extends RefCounted

const TIERS := {"hamlet": "a hamlet", "town": "a town", "city": "a city", "city_quarter": "a city"}
const MONUMENT_LINES := {
	"prior_pillar": "An old Prior pillar. Its hourglass still glows; nobody remembers who set it here.",
	"standing_stones": "Standing stones, older than any town. One carving on the altar still glows.",
	"watchtower": "A watchtower over the coast and the roads. Someone still keeps its fire.",
	"hermit_tower": "A lone tower far from any town. A lantern burns at the top every night.",
}
const LANDMARK_LINES := {
	"demon_crypt": "A ruined crypt. A red glow rises from the stairs below.",
	"dragon_lair": "A cave in the crag, scorched black. Bones lie at its mouth.",
	"bandit_hideout": "A bandit camp behind sharpened logs.",
	"goblin_warren": "A mound burrowed full of goblin holes.",
	"slime_bog": "A murky bog. Something glistens in the shallows.",
	"herb_glade": "A quiet glade where healers' herbs grow.",
}
const TOWN_LINES := {
	"city": ["The seat of its land: a keep, with quarters round it."],
	"town": ["A market town.", "A church town round an old Prior pillar."],
	"hamlet": ["A few houses round a well.", "A few houses and a windmill."],
}


## The hover's line for a settlement ("Barst, a city") or a monument ("The Ellowmere Ring"), or "" for any other hex.
## A settlement from before 2026-11-08 has no size: just its name.
static func short_line(rec: Dictionary) -> String:
	if rec.has("monument"):
		return str(rec.get("monument_name", "A monument"))
	if rec.has("landmark"):
		return str(rec.get("landmark_name", "A landmark"))
	if rec.get("is_zone", false) and str(rec.get("location_name", "")) != "":
		var tier := str(rec.get("town_tier", ""))
		return "%s, %s" % [rec.location_name, TIERS[tier]] if TIERS.has(tier) else str(rec.location_name)
	return ""


## The click panel's lines about the place itself (none for an ordinary hex).
static func detail_lines(rec: Dictionary) -> Array:
	if rec.has("monument"):
		var m: String = MONUMENT_LINES.get(str(rec.monument), "")
		return [m] if m != "" else []
	if rec.has("landmark"):
		var l: String = LANDMARK_LINES.get(str(rec.landmark), "")
		return [l] if l != "" else []
	if not rec.get("is_zone", false):
		return []
	var tier := str(rec.get("town_tier", ""))
	if tier == "city_quarter":
		return ["A quarter of %s." % str(rec.get("location_name", "the city"))]
	var lines: Array = TOWN_LINES.get(tier, [])
	if lines.is_empty():
		return []
	return [lines[clampi(int(rec.get("town_variant", 0)), 0, lines.size() - 1)]]
