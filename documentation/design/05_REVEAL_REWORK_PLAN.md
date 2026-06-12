# Eternal Guild — End-of-Day Reveal Rework Plan

**The centerpiece. Highest-leverage work in the project.**
*Plan written 2026-06-09. Prompts below are ready to paste into Claude Code,
in order. Do not skip the recon.*

---

## Diagnosis (locked, from 2026-06-07 session)

The current modal is a **payout screen**, not a reveal:
1. Subject is the mission outcome, not the returning adventurer.
2. Dice are exposed ("Roll: 74 vs 66%") — immersion-breaking.
3. Success / wounded / death share one layout → numbing repetition.
4. Human consequence is the smallest text on the panel.

The bones are right: centered modal, dimmed tavern, tap-to-advance,
"Report N of M" counter. We rework the contents, not the skeleton.

## Design decisions (locked)

- **Subject of every panel = the adventurer.** Name as headline, state line
  under it, mission result as a dim footnote. Gold is a footnote, never a headline.
- **Dice never shown.** Delete from the player's view entirely.
- **Three structural panel variants:** returned-whole / returned-wounded /
  not-returned. Not just recolors — different structure.
- **Death beat (lead-designer call, overridable):** the death panel breaks the
  rhythm. No "FAILED" text, no footnote, no dice. The name sits alone with the
  portrait; the advance button is withheld for ~2 seconds; one quiet line
  ("She didn't come back."). Tap rhythm interrupted = death felt in the hands,
  not just the eyes.
- **Portrait holder:** large portrait in the panel, reusing the roster's
  portrait pipeline. Sized as the socket the evolving tarot art plugs into
  later. New tarot art replaces the anime set when imported — same socket.
- **Mystery stays.** No mission logs, no battle reports, ever. One flavor line,
  templated by class+outcome (inline dictionary first; JSON migration later).

---

## Recon A — find the panel (PASTE TO CLAUDE CODE FIRST)

```
READ-ONLY RECON. Do not edit anything.

Find the end-of-day mission report modal. Search all .gd and .tscn files for
the strings: "Next Report", "Begin the Day", "MISSION FAILED", "Report",
"Roll:". Then report:

1. The .tscn file(s) and .gd script(s) that build and populate the report
   modal, with paths.
2. The node tree of the modal (names + types), and whether it lives on a
   CanvasLayer.
3. The function(s) that populate a single report: full source, with the exact
   fields they read from the mission record and adventurer dict.
4. Where the "Roll: X vs Y%" text is composed.
5. How the queue advances (button signal → which function) and how the modal
   closes ("Begin the Day").
6. How roster cards load portraits (the keying — by class? by name?), full
   source of that loader, and the portrait asset folder layout.
7. Where mission resolution writes the outcome (which function in GameManager
   sets success/failure, injury, death) and the exact field names + possible
   values for adventurer status after resolution.

Report file paths + line numbers. NO EDITS.
```

## Recon B — data source of truth (can run same session)

```
READ-ONLY RECON. Do not edit anything.

Produce DATA_SOURCE_OF_TRUTH.md content: the ACTUAL committed shapes of
(1) the adventurer dict — every field name, type, and the values it actually
takes in code, (2) the mission record/template — every field incl.
required_adventurers and mission_source if present, (3) the hex record in
WorldManager.world_map. Copy from real source with file+line references.
Do not include aspirational fields from docs. NO EDITS.
```

---

## Build steps (each gets its own scoped prompt AFTER Recon A reports)

**R1 — Text hierarchy.** Rewrite panel population: adventurer name headline
(large), state line (medium), mission name + gold as dim footnote, dice text
deleted. Flavor line from an inline `const REVEAL_LINES` dictionary keyed by
class+outcome (3 variants each, pick random). One script, complete functions.
*Test gate: run 3 missions, all three outcomes readable in new hierarchy; no
dice visible anywhere.*

**R2 — Panel variants.** Three structural layouts: whole (warm tone, gold on
the bar line), wounded (muted tone, recovery-days line), not-returned
(see R3). Selection driven by the resolution fields Recon A reported.
*Test gate: force one of each via F12 debug; three panels are visibly
different at a glance.*

**R3 — Death beat.** Death panel: portrait + name alone, one quiet line, no
footnote, advance button hidden for ~2.0s (Timer node, then fade in). No
skull iconography spam; restraint is the design.
*Test gate: force a death; feel the pause; confirm tap rhythm breaks.*

**R4 — Portrait holder.** Large portrait in all three variants via the
existing roster portrait loader; graceful fallback for missing classes
(Ranger/Cleric per TECH_DEBT). Socket dimensions chosen to fit the tarot art
aspect (the NanoBanana set is landscape 16:9-ish and one portrait 9:16 —
decide crop once Recon A reports current portrait dimensions).
*Test gate: portraits render in all variants; missing-portrait case doesn't
break layout.*

**Out of scope (do not let in):** bespoke mission illustrations, mission logs,
animation systems, sound, reordering deaths to the end of the queue (possible
later polish, not now).

## Order of operations

Recon A → R1 → test → R2 → test → R3 → test → R4 → test → commit each step.
Recon B anytime; its output becomes DATA_SOURCE_OF_TRUTH.md in the docs folder.
