# Loot & Equipment System — Epic 12 Spec

**Status: spec only, nothing in this doc is built yet.**
**Written: 2026-08-18, for a future implementation session (dev Claude or Raphael).**

---

## How to use this doc

Read "Ground truth" before anything else — it corrects real overstatements in
`EPIC_PROGRESS.md`'s Epic 12 section. Then "Design intent" before writing any
code: this system has real guardrails from `01_VISION.md` that are easy to
violate by defaulting to generic RPG-loot instincts. The rest is a concrete,
sequenced build plan with exact anchors in the current code.

Recon this doc's claims against the actual files before trusting them — this
was accurate as of 2026-08-18 on branch `shiningsun`; things may have moved.

---

## Ground truth (what actually exists today — corrects EPIC_PROGRESS.md)

`EPIC_PROGRESS.md`'s Epic 12 section currently reads "~10% — Data exists, no
loot system" and checks off three bullets as done. Checked all three directly:

| Claim | Reality |
|---|---|
| `data/economy/items.json` — item definitions exist | **True but misleading.** One item: `beer` (tavern stock, `category: "consumable"`). Nothing loot- or equipment-related. |
| `data/missions/rewards.json` — reward data exists | **File is empty** — literally `{}`. |
| Mission resolution returns gold rewards (range-based random) | True, but see the bug below — the *report* the reveal panel reads never carries the actual rolled amount, only the config range. |

**`GameManager.roll_loot()`** (`scripts/GameManager.gd:1642`) exists and is
unit-tested (`test/failsafe_test.gd`'s `test_loot_rng_distribution`), but:
- It's a bare category roller — `static func roll_loot() -> String`, returns
  `"gold"` (75%) / `"equipment"` (20%) / `"artifact"` (5%). No item, no value,
  no side effect.
- **It is never called anywhere in the live game.** Confirmed via `grep`.

**`failure_consequences`** tags on mission templates (`data/missions/mission_types.json`,
e.g. `"equipment_damage"`, `"equipment_loss"`) are similarly aspirational —
grep confirms nothing in `GameManager.gd` ever reads that array. Failure
outcomes are computed purely from `calculate_death_chance()`, independent of
these tags.

**Nothing in any design doc defines what "equipment" or "artifact" should
actually *do*.** Checked every file under `documentation/design/` for
`loot|artifact|equipment|inventory` — zero hits outside EPIC_PROGRESS.md's own
checklist. This spec is the first place that decision gets made; treat the
"Design intent" section below as the actual design work, not just wiring.

**A real bug worth fixing while you're in this code anyway:**
`_resolve_solo_mission()` / `_resolve_party_mission()`
(`scripts/GameManager.gd`, ~line 442 / ~476) return a report dict with
`"reward": mission.get("reward_range", [0, 0])` — the config *range*, not the
amount `complete_mission()` actually rolled and paid out. The reveal panel
(`scenes/ui/script/morning_briefing.gd:186-187`) displays it as
`"Reward earned: X-Y gold"` — a range, when the player should see the exact
number they got. This has nothing to do with loot per se, but you can't
report a gold-tier loot bonus correctly without first knowing the *actual*
rolled reward, so fixing this is a natural side-effect of this work, not
scope creep.

---

## Design intent — read `01_VISION.md` pillars first

Two pillar lines constrain this system hard, and it's easy to build something
that violates them by defaulting to genre convention:

> "Not a battle-report reader. Mission calculations stays off-screen."
> "The player never sees what happened on a mission, only who came back and
> how they look."

This rules out: a loot-drop screen, an inventory UI, item tooltips, "you
found a Sword +2" battle-report language, multiple equipment slots, item
rarity color-coding — the whole default RPG loot toolkit. Whatever surfaces
in the reveal panel must stay as terse as the existing "who came back, and
how they look" framing.

Two other pillars actively suggest what loot *should* mean here:

> Pillar 4, **Curiosity & Discovery**: "The Priors, their teal-rune ruins,
> Den Fa's secrets... Mystery is an asset."
> Pillar 5, **Legacy**: "One adventurer becomes the next run's protagonist...
> The hourglass loop, not infinite proceduralism, is the replayability story."

The **artifact** tier (5% of `roll_loot()`) is the natural fit for Prior
relics — mysterious, narratively loaded, *not* about mechanical power. The
**equipment** tier (20%) is small, permanent, unglamorous — matches "Meaningful
Management" (pillar 3), not a power fantasy. The **gold** tier (75%, the
common case) should stay boring on purpose — it's already the norm.

**Governing design rule for this whole system: loot should almost never be
mechanically interesting. It should occasionally be narratively interesting
(artifacts) and rarely be a small permanent nudge (equipment). If a decision
point below tempts you toward "more interesting," that's the wrong direction
for this game.**

---

## The three tiers, specified

### Gold tier (75% of rolls) — no new system, just fix the existing report bug

No new data, no new fields. On a successful mission where `roll_loot() ==
"gold"`, add a small bonus on top of the already-rolled reward — e.g. `+10%
to +25%` of the base roll, your call on the exact range. Fold it into the
same `reward` number the player already sees; do not give it a separate
line. This is the "boring on purpose" branch — most successes should look
exactly like they do today.

### Equipment tier (20% of rolls) — one slot, one flat stat bump, no rarity

- One optional field on the adventurer dict: `equipped_item: Dictionary` (or
  absent/`{}` if none). **Single slot, not multiple** — this is not a gear
  RPG. Equipping a new item silently replaces the old one; there is no
  inventory to manage, no "sell your old gear" prompt. That's deliberate —
  the vision pillar treats inventory management as exactly the kind of
  battle-report bookkeeping this game avoids.
- New data file `data/economy/equipment.json` — flat list, ~8-12 entries,
  each: `id`, `display_name`, `description` (Grimgar-tone: weathered,
  practical, never "+2 Flaming Sword" fantasy-shop language — think "a
  dented shield that's stopped one blade too many"), `stat` (one of
  strength/dexterity/intelligence/endurance), `bonus` (int, keep it small —
  +1 or +2, matching the scale of the class stat bonuses already in
  `generate_fallback_recruits()`).
- Apply the bonus **once, at the moment of equipping**, directly to the
  adventurer's stat field (same pattern the class bonuses already use in
  `generate_fallback_recruits()`). Do not build a "derived stats" system that
  recomputes bonuses from equipped items each time they're read — that's a
  bigger architecture change than this system needs. If the item is later
  replaced, the old bonus is *not* subtracted back out (matches "no
  inventory to manage" — the adventurer keeps trending stronger over a long
  career, which is a fine, quiet form of the "evolving individual" pillar).
- **Known pitfall, hit twice already this session**: Godot's `JSON.parse`
  floatifies saved ints. If `bonus` round-trips through a save, cast with
  `int()` wherever it's read back, the same way `_normalize_adventurer_ints()`
  already handles this for other adventurer fields (Epic 4 cross-cutting
  fix, `scripts/GameManager.gd`).

### Artifact tier (5% of rolls) — Prior relics, eternal, not equipped

- **Not attached to an adventurer** — adventurers die or age out; the guild's
  collection of relics shouldn't. Persist to `codex.dat` (the eternal
  cross-run store — `systems/SaveSystem.gd`), exactly mirroring how
  `record_fallen_hero()` already appends to `fallen_heroes`:
  - Add `"artifacts_found": []` to `_default_codex()`.
  - Add a `record_artifact_found(artifact_id: String)` function next to
    `record_fallen_hero()`, same shape: build an entry dict (`id`, `name`,
    `description`, `found_day`, `timestamp`), append, `_save_codex()`.
- New data file `data/economy/artifacts.json` — small list, ~5-8 entries.
  **No mechanical stat bonus at all.** These are Curiosity & Discovery
  payoff, not power — "Mystery is an asset," per the pillar. Flavor text
  should hint at the Priors / teal-rune ruins lore (check
  `documentation/design/session.md` and `00_GDD_Master.md` for existing
  Prior lore fragments to stay consistent, if any exist by the time this is
  built).
- **Natural tie-in already built tonight**: the Codex overlay
  (`scripts/menus/codex_menu.gd`, shipped 2026-08-18) already renders a
  "Guild Record" stats section and "The Fallen" list from `codex.dat`. A
  third section — "Artifacts Recovered" — is a near-zero-cost extension once
  `artifacts_found` exists: same file, same pattern as the existing
  `_stats_row()` / `_hero_row()` helpers. Worth doing in the same PR as the
  data model, since the payoff (a player can actually see what they found)
  is what makes the artifact tier feel like anything at all.

---

## Integration point — where the roll actually happens

Both `_resolve_solo_mission()` and `_resolve_party_mission()`
(`scripts/GameManager.gd`, ~lines 442 and 476) call `complete_mission()` /
`complete_party_mission()` and then build a report dict. The natural hook:

1. Only roll loot **on success** (`if success:` — failure already has its own
   consequences via `handle_party_failure_consequences()`; don't stack loot
   loss on top for v1 — that's a real design decision, but a separate one,
   flag it to Raphael rather than assuming it).
2. Call `GameManager.roll_loot()` once per resolved mission (not per party
   member — one roll per mission, matching how `reward` already works).
3. Branch on the tier:
   - `"gold"`: bump the reward before it's paid out (see gold tier above).
   - `"equipment"`: pick a random entry from `equipment.json`, set on the
     surviving adventurer (solo) or a random surviving party member (party
     mission — decide "random" vs. "class that most benefits from the
     stat," random is simpler and matches the "boring on purpose" ethos).
   - `"artifact"`: `SaveSystem.record_artifact_found(id)`.
4. Add one new report field, e.g. `"loot": {"tier": ..., "name": ...}` or
   `null` for the gold tier (which shouldn't get a separate mention — see
   above). This is what the reveal panel reads.
5. While you're touching the report dict, fix the reward-range-vs-actual-
   amount bug noted above — thread the real rolled `reward` int through
   instead of `mission.get("reward_range", [0,0])`.

## Reveal panel surfacing

`scenes/ui/script/morning_briefing.gd` (~line 186) is the only place that
currently reads the report's `reward` field. Add loot display here, but keep
it to the same one-line, terse register as the existing "who came back"
framing — something like appending `" · found: <name>"` only when
`report.loot != null`. No new panel, no new UI component, no icon system.
This is a text addition to an existing label, not a feature.

---

## Suggested build order

1. Fix the reward-range-vs-actual-amount bug first, in isolation — it's
   independent of loot and easy to verify on its own (headless: resolve a
   mission, check the report's `reward` is an int matching what
   `GameManager.gold` actually increased by, not the config array).
2. Author `data/economy/equipment.json` and `data/economy/artifacts.json` —
   pure data, no code, easy to review against the tone guidance above before
   any logic depends on it.
3. Wire the gold tier (no new fields, lowest risk) — verify headless: force
   many mission resolutions, confirm loot-tier gold successes pay out more
   than the base range's max.
4. Wire equipment — add `equipped_item`, apply the stat bump, verify headless
   (equip, check the stat actually increased by the right amount, check it
   survives a save/load round-trip with `int()` casting intact).
5. Wire artifacts — `record_artifact_found()`, verify headless (roll enough
   missions to hit the 5% tier a few times, check `codex.dat` gets the
   entries, check no duplicate-guard issue if the same artifact rolls
   twice — decide and document whether duplicates are allowed, they
   probably should be for v1 simplicity).
6. Add the Codex "Artifacts Recovered" section.
7. Add the one-line reveal-panel surfacing.

Each step should get its own commit, following the pattern used for every
Epic shipped in this session's history (`git log --oneline` on `shiningsun`
around 2026-08-18): recon, implement, verify headless (no GUI needed for any
of this — it's all `GameManager`/`SaveSystem` logic), commit, update
`EPIC_PROGRESS.md` in the same or a following commit.

---

## Open decisions for Raphael (don't assume — ask or flag in the PR)

- Does mission **failure** ever cost equipment (the `equipment_loss` /
  `equipment_damage` tags already sitting unused in `mission_types.json`
  hint someone wanted this)? Left out of this spec's v1 — recommend shipping
  the success-path loot first, then deciding whether failure consequences
  are worth building against those existing (currently decorative) tags.
- Can the same artifact be found twice? V1 recommendation: yes, simplest,
  revisit if it feels wrong in play.
- Should equipment be class-gated (a Mage never rolls a strength item)? V1
  recommendation: no, keep the pool universal — smaller data file, and
  "boring on purpose" cuts against adding a filtering layer for a system
  that's supposed to stay minor.

## Explicit non-goals (don't build these — said once here so it isn't re-litigated per commit)

- No inventory UI, no item tooltips, no icon assets.
- No equipment shop / buying gear with gold.
- No multiple equipment slots.
- No item rarity tiers beyond the existing three-way gold/equipment/artifact
  split.
- No stat recalculation system — bonuses apply once, at the moment of
  equipping, permanently.
