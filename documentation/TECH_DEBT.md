# Eternal Guild — Tech Debt & Deferred Items
Captured during the world-map dispatch work (Steps A–C2). Updated 2026-07-08 (Epic 4.1).

## ~~Confirmed dead / orphaned code~~ — RESOLVED 2026-06-21
All items in this section have been fixed and verified via live scene tree inspection:
- ✅ `GameManager.gd` lowercase `"on_mission"` match arms — fixed to `"On Mission"` (correct capitalization)
- ✅ `GameManager.gd` orphaned `assign_adventurer_to_mission()` — removed (zero callers confirmed via grep)
- ✅ Duplicate `PlayerManager` in `systems/` — deleted (autoload uses `scripts/autoload/` copy; player confirmed spawning correctly via runtime scene tree)
- ✅ Orphaned `scenes/ui/WorldMapBoard.tscn` — deleted (zero references confirmed via grep)
- ✅ `AdventurerRosterPanel.gd` duplicate `"on_mission"`/`"On Mission"` arms — consolidated to `"On Mission"`

## ~~Pause menu: dead script + stale connections (FR-34)~~ — RESOLVED 2026-07-05
`pause_menu.gd` (the full Save / Load / Save&Exit script) was assigned to the WRONG node — **PauseBackground (a Control)** — while it `extends CanvasLayer`, so Godot silently refused to attach it and its `_ready` never ran. The buttons were half-wired: Main Menu / Quit fired duplicate handlers in `main_tavern.gd` (via `.tscn` signal connections); Save / Load / Save & Exit were connected to nothing (dead). This was the FR-34 "stale `.tscn` connections bypass the handlers" debt.
- ✅ Moved `pause_menu.gd` onto the **PauseMenu CanvasLayer** (matching type) — its `_ready` now wires all five buttons + adds the Settings button, and the Save & Exit fix is live.
- ✅ Disconnected the two stale `.tscn` `pressed` signals (MainMenuButton / QuitButton → `main_tavern`).
- ✅ Removed the orphaned `_on_main_menu_button_pressed()` / `_on_quit_button_pressed()` from `main_tavern.gd`.
- Verified headless: MainTavern loads, `PauseMenu.script == pause_menu.gd`, scripts parse.

## Status / availability: three sources of truth for one fact
Availability is currently gated by THREE overlapping signals on the adventurer dict: the `status` string (`"Ready"`/`"On Mission"`/`"Injured"`/`"Resting"`), an `on_mission` boolean, and a `ready` boolean. Two reader functions check different subsets:
- `get_ready_adventurers()` (line ~157) checks all three.
- `is_adventurer_available()` (line ~165) checks only `status`.
They happen to agree today, but this is fragile. Now that `assign_adventurer_to_mission` (the only setter of the `on_mission` boolean) is removed, the boolean is never written by live code — making `get_ready_adventurers()`'s check of it redundant. Next step: simplify `get_ready_adventurers()` to match `is_adventurer_available()` (status-only), then remove the `on_mission` and `ready` booleans from adventurer dicts entirely.
**Mitigation already in place:** all new dispatch UI (C2 drag) reads availability ONLY via `get_ready_adventurers()`, so it inherits the correct logic and adds no fourth check.
**Update 2026-07-05:** the `AdventurerStatus` enum (`scripts/resources/adventurer_status.gd`) now exists and is adopted — the "next step" simplification should migrate availability to it and drop the `on_mission` / `ready` booleans.

## ~~Single-authority resource drains (Epic 3 / FR-3, FR-1)~~ — RESOLVED 2026-07-05
- ✅ **Firewood.** `GameManager.consume_firewood()` is the sole drain. Dead `stoke_fireplace()` (zero callers) removed. Verified: exactly one `firewood_stock -=` in the codebase. (Story 3.3.)
- ✅ **Beer.** Added `GameManager.consume_drink(drink_type, amount)` as the single authority; `consume_beer()` / `consume_beer_pints()` are now thin wrappers that delegate to it. Verified: exactly one `beer_stock -=` in the codebase. (Story 3.4 — authority done; the coin-burst payment animation + `SfxManager` are now built too, 2026-07-08.)

## Epic 4 (Adventurer Roster) — flags raised during Story 4.1
- **Duplicate recruit generator in `DataManager`.** The *active* hire-pool path is `GameManager.generate_daily_recruits()` → `generate_fallback_recruits()` (enriched in 4.1 with Tarot card / experience tier / wage / drink). `DataManager` carries a *second, parallel* generator — `generate_complete_character()`, `generate_daily_applicants()`, `generateSingleAdventurer()`, reading `data/characters/classes.json` — that the day loop does **not** call. Two sources of truth for "a recruit." Consolidate onto one authority (recommend: keep the GameManager path, or move generation into DataManager and have GameManager delegate) during **Story 4.3**. The `number in generateSingleAdventurer` unused-param warning lives in this dead path.
- **Class list: code vs GDD.** `game_config.json` ships **5** classes (Fighter/Rogue/Mage/**Ranger/Cleric**); the GDD MVP specifies **4** (Fighter/Rogue/Mage/**Healer**). Kept the working 5 for now — reconcile deliberately (rename Cleric→Healer + drop Ranger, or amend the GDD) before locking class-tied content (drink affinity in Epic 15, evolution art in Epic 17).
- **Portraits moving to Tarot cards.** Recruits now carry a `portrait` path from their assigned Tarot card (placeholder art until commissioned). This supersedes the class-based portrait lookup — roster/reveal UIs should read `adventurer.portrait` (MOD-3) rather than class. Wire in **Story 4.3**; makes the "Portrait not found for Ranger/Cleric" cosmetic item below moot.

## To verify when building C3 (dispatch commit)
- **Mission-board open gate.** Opening the board currently refuses with "You need to hire adventurers first" when the roster is empty. CHECK whether this gate keys off roster *size* (have any adventurers) or *available* count (have Ready ones). If it keys off availability, dispatching all adventurers could lock the player out of opening the board to see in-flight missions or next-day offerings — a soft-lock-adjacent edge that only becomes reachable once C3 makes "all adventurers busy" a real state.

## Untested branches from C2 (wrote-it, couldn't-exercise-it)
Both will get real testing in C3 when dispatch makes adventurers non-Ready and multi-adventurer missions can be staged:
- **Grey-out of non-Ready roster cards** — code runs, but never observed doing its job (all adventurers were Ready during C2 testing).
- **No-double-assign across slots** — never exercised (all C2-era missions were `required_adventurers: 1`, so only one slot existed).

## Cosmetic / deferred
- `⚠️ Portrait not found for class: Ranger` / `Cleric` — roster cards fall back to no portrait for some classes. Missing portrait assets, not a logic bug. *(Superseded once UIs read `adventurer.portrait` from the Tarot card — see the Epic 4 section above.)*

## GDScript warnings (pre-existing, non-blocking)
Captured from startup output — all are warnings, not runtime errors:
- Unused parameters: `mod_name` in `register_mod_data()`, `number` in `generateSingleAdventurer()`, `completed_missions` in `get_next_chain_mission()`, `failure_type` in `trigger_game_over()`, `adventurer` in `check_adventurer_level_up()`, `mission` in `handle_adventurer_injury()`, `reason` in `_on_game_over()` — prefix with `_` to silence
- Unused locals: `chain_missions`, `beer_adequate` — prefix with `_`
- Unused signals: ~~`recruitment_pool_changed`~~ (now emitted on pool generation + bridged to `AdventurerBus`, Epic 4.1), `missions_resolved` — connect or remove
- Shadowed names: local `ready` shadows `Node.ready` signal; `for name in` shadows `Node.name` — rename iterators
- Integer division truncation (2 instances) — cast to float if decimal needed
- Ternary type mismatch (2 instances) — ensure both arms return same type
- Enum/int mismatch (2 instances) — explicit cast
- ~~Runtime error: `Node not found: "%LogContainer"` in DataManager~~ — the dead `@onready var log_container = %LogContainer` binding was removed from DataManager in Epic 1 (verified 2026-06-24); should be resolved.
