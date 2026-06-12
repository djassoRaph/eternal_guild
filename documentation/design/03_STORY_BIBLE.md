# Eternal Guild — Story Bible (DRAFT)

**Status: DRAFT.** Written by Claude from session memory, 2026-06-09. This is
the first time the narrative foundations exist on paper instead of in Raphael's
head. **Every section needs his pass.** Items marked ⚑ are Claude filling gaps
with proposals, not recorded decisions.

---

## 1. The Priors

A lost civilization whose ruins surround every settlement. Their mark is
**teal** — luminous runes carved in stone that still glow faintly. Nobody
living can read them fluently. Their artifacts concern *time*: hourglasses,
generational cycles, the patience of stone.

⚑ Proposed framing: the Priors did not fall to war or plague. They *completed
something* and left. What they completed, and whether the hourglass loop is
their machine still running, is the campaign-length mystery. The player never
gets a lore-dump; understanding accretes across runs.

The tavern's own cellar holds Prior stonework — the hourglass pillar (Phase-1
asset) is excavated gradually as the tavern upgrades, the building literally
revealing its foundations as the player invests in it.

## 2. Den Fa

A Prior-remnant advisor figure. Publicly: a quiet, weathered counselor —
secretly one of the King's advisors. In the tarot system he is **The Hermit
(IX)**: the lantern-bearer who shows the path but does not walk it for you.

He owns the **magical hourglass** — the in-fiction mechanism of the legacy
loop. When a run ends, Den Fa turns the glass, and one adventurer steps forward
to carry the guild's name to a new settlement.

Missions carry a `mission_source` flag: **King-sanctioned** (official, safer,
political) versus **Hidden** (Den Fa's own errands — Prior sites, things the
crown must not know). The player slowly realizes the Hidden missions are
assembling toward something.

⚑ Open design decision (standing, overridable): Den Fa's card placement as
The Hermit IX.

## 3. The hourglass legacy loop

One adventurer from the ending roster becomes the next run's protagonist,
opening a new tavern in a different settlement. **Max 10 settlements.** Each
settlement is a chapter; the full campaign is the guild's name spreading across
the map, generation by generation. Replayability comes from legacy, not
proceduralism — the world map is generated once per run and never regenerated.

## 4. Tarot as roster

- **22 Major Arcana** — named story adventurers with full Journey Through the
  Arcana arcs (see 06_Character_Design.md for the system and the Gareth case
  study).
- **56 Minor Arcana** — supporting cast, procedurally flavored, no deep arcs.
- **The World (XXI)** is the player's card — the old soldier in the Prior-rune
  circle. (Standing decision, overridable.)
- **Suit tinting** (standing mechanical hook, overridable): Swords → sacrificial,
  Cups → bonded, Wands → blaze-of-glory, Pentacles → survivor. Suit colors an
  adventurer's behavior at the moment it matters most.
- Full 78-card portrait prompt set exists (eternal_guild_tarot_portrait_prompts.md).
  Test batch validated 2026-06-09 — style holds across the set.

## 5. The player's journey — a run, dreamed out

*(⚑ This whole section is the proposed arc of one settlement-run, written
2026-06-09 at Raphael's request. The brewing ladder and the farmland grant are
NEW design — flagged as such. Validate before any of it touches code.)*

**Days 1–10 — Embers.** The tavern is one room and a cold fireplace. Two or
three patrons a night. The player learns the rhythm: wood, fire, beer, gold.
The first adventurer hired is barely affordable — a Page, a nobody with a
Minor Arcana card and a flaw. The first missions are errands: deliver a
message, gather herbs at the water's edge. The first reveal is small and
almost always kind. The game is teaching the ritual before it earns the right
to break it.

**Days 10–30 — The first tax.** Pressure arrives. Wages plus the looming
1000-gold tax force the first real choices: hire a third adventurer or stock
beer? Take the Hidden mission Den Fa quietly slides across the bar — better
pay, worse odds? Somewhere in here, the first wounded return happens, and the
player learns the reveal can hurt. The tax payment is the act break.

**Days 30–60 — A name.** The guild is known now. The King's notice arrives as
`mission_source: king` contracts — escorts, patrols, formal work with seals on
it. The roster grows toward its economic ceiling. A Major Arcana adventurer
walks in for the first time — someone with a *story*, whose card will evolve.
Tavern upgrade tier 1: the cellar is opened, and the first Prior stones show
in the excavation. Den Fa starts visiting more often.

**Days 60–90 — Heavy lifting.** High-tier missions: three-adventurer parties,
real danger ratings. This is where the death beat earns its design — the
player has had these people for sixty days. The reveal is now the night's
weather: some evenings golden, some evenings you count the silhouettes twice.

**The farmland grant (⚑ NEW).** Recognition made material: the local town
delegates a parcel of farmland to the guild. Not a farming minigame — a
*production choice*. The player assigns the land: **hops** (cheaper beer,
better margins), **orchard** (cider — new patron tier, better tips), and
eventually **vines** (wine — slow, expensive, the prestige drink that draws
the kind of patron who carries rumors and story hooks). The brewing ladder
beer → cider → wine is the tavern's visible status arc, the same way the
excavated pillar is its visible mystery arc. The land is worked by off-roster
hands; it costs gold and time, not new gameplay verbs. **Scope note: this is
one production-choice screen and three resource lines, not a farm sim. If it
grows past that, cut it.**

**Endgame of a run.** The Hidden missions converge on a Prior site. Den Fa
turns the hourglass. One adventurer — the player chooses, or the story does —
steps forward. The next settlement unlocks. The tavern empties; the fire goes
out for the last time; the legacy begins again somewhere new.

## 6. Tone reference

Grimgar melancholy, Spiritfarer's cosy-about-death, Ghibli warmth indoors,
Mignola shadow outdoors. The reveal is the game's heartbeat; everything in
this bible exists to make the person walking through that door matter.
