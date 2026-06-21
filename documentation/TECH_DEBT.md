# Eternal Guild — Tech Debt & Deferred Items
Captured during the world-map dispatch work (Steps A–C2). Updated 2026-06-21.

## ~~Confirmed dead / orphaned code~~ — RESOLVED 2026-06-21
All items in this section have been fixed and verified via live scene tree inspection:
- ✅ `GameManager.gd` lowercase `"on_mission"` match arms — fixed to `"On Mission"` (correct capitalization)
- ✅ `GameManager.gd` orphaned `assign_adventurer_to_mission()` — removed (zero callers confirmed via grep)
- ✅ Duplicate `PlayerManager` in `systems/` — deleted (autoload uses `scripts/autoload/` copy; player confirmed spawning correctly via runtime scene tree)
- ✅ Orphaned `scenes/ui/WorldMapBoard.tscn` — deleted (zero references confirmed via grep)
- ✅ `AdventurerRosterPanel.gd` duplicate `"on_mission"`/`"On Mission"` arms — consolidated to `"On Mission"`

## Status / availability: three sources of truth for one fact
Availability is currently gated by THREE overlapping signals on the adventurer dict: the `status` string (`"Ready"`/`"On Mission"`/`"Injured"`/`"Resting"`), an `on_mission` boolean, and a `ready` boolean. Two reader functions check different subsets:
- `get_ready_adventurers()` (line ~157) checks all three.
- `is_adventurer_available()` (line ~165) checks only `status`.
They happen to agree today, but this is fragile. Now that `assign_adventurer_to_mission` (the only setter of the `on_mission` boolean) is removed, the boolean is never written by live code — making `get_ready_adventurers()`'s check of it redundant. Next step: simplify `get_ready_adventurers()` to match `is_adventurer_available()` (status-only), then remove the `on_mission` and `ready` booleans from adventurer dicts entirely.
**Mitigation already in place:** all new dispatch UI (C2 drag) reads availability ONLY via `get_ready_adventurers()`, so it inherits the correct logic and adds no fourth check.

## To verify when building C3 (dispatch commit)
- **Mission-board open gate.** Opening the board currently refuses with "You need to hire adventurers first" when the roster is empty. CHECK whether this gate keys off roster *size* (have any adventurers) or *available* count (have Ready ones). If it keys off availability, dispatching all adventurers could lock the player out of opening the board to see in-flight missions or next-day offerings — a soft-lock-adjacent edge that only becomes reachable once C3 makes "all adventurers busy" a real state.

## Untested branches from C2 (wrote-it, couldn't-exercise-it)
Both will get real testing in C3 when dispatch makes adventurers non-Ready and multi-adventurer missions can be staged:
- **Grey-out of non-Ready roster cards** — code runs, but never observed doing its job (all adventurers were Ready during C2 testing).
- **No-double-assign across slots** — never exercised (all C2-era missions were `required_adventurers: 1`, so only one slot existed).

## Cosmetic / deferred
- `⚠️ Portrait not found for class: Ranger` / `Cleric` — roster cards fall back to no portrait for some classes. Missing portrait assets, not a logic bug.

## GDScript warnings (pre-existing, non-blocking)
Captured from startup output — all are warnings, not runtime errors:
- Unused parameters: `mod_name` in `register_mod_data()`, `number` in `generateSingleAdventurer()`, `completed_missions` in `get_next_chain_mission()`, `failure_type` in `trigger_game_over()`, `adventurer` in `check_adventurer_level_up()`, `mission` in `handle_adventurer_injury()`, `reason` in `_on_game_over()` — prefix with `_` to silence
- Unused locals: `chain_missions`, `beer_adequate` — prefix with `_`
- Unused signals: `recruitment_pool_changed`, `missions_resolved` — either connect or remove
- Shadowed names: local `ready` shadows `Node.ready` signal; `for name in` shadows `Node.name` — rename iterators
- Integer division truncation (2 instances) — cast to float if decimal needed
- Ternary type mismatch (2 instances) — ensure both arms return same type
- Enum/int mismatch (2 instances) — explicit cast
- Runtime error: `Node not found: "%LogContainer"` in DataManager — likely a missing unique name binding
