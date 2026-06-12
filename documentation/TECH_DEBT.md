# Eternal Guild — Tech Debt & Deferred Items
Captured during the world-map dispatch work (Steps A–C2). Nothing here is urgent; these are known issues to address deliberately, not mid-feature.

## Confirmed dead / orphaned code (verify with grep before removing)
- **`GameManager.gd` lines ~1391 and ~1412** — `match adventurer.status:` arms for `"on_mission"` (lowercase). The status field is only ever written as `"On Mission"` (capitalized), so these arms never fire. Dead but harmless. Decide later: delete the arms, or fix them to read the real value (ties into the status-signal mess below).
- **`GameManager.gd` ~line 1622, `assign_adventurer_to_mission()`** — appears to be an orphaned older dispatch path. Sets `adventurer["on_mission"] = true` (a boolean nothing else relies on). The live dispatch path is `send_on_mission` / `send_party_on_mission`. Before deleting: grep ALL `.gd` AND `.tscn` for `assign_adventurer_to_mission` to confirm zero callers. If something calls it, that caller is a bug to understand, not silently remove.
- **Duplicate `PlayerManager`** — exists in both `scripts/autoload/` and `systems/`. Project notes say consolidate to one source. DANGEROUS to get wrong (it's an autoload; scene transitions depend on it). The `systems/PlayerManager.gd` copy is flagged as the stale duplicate, safe to delete only after a full grep confirms no references to it.
- **`scenes/ui/WorldMapBoard.tscn`** — a `.tscn`-only embed of `HexMapTest` in a SubViewport, no script attached. The live mission board is `scenes/world/WorldMapBoard.tscn` (`world_map_board.gd`), instantiated from `zone_interactions.gd`. The `scenes/ui/` copy appears orphaned — grep for references to it before deleting.

## Status / availability: three sources of truth for one fact
Availability is currently gated by THREE overlapping signals on the adventurer dict: the `status` string (`"Ready"`/`"On Mission"`/`"Injured"`/`"Resting"`), an `on_mission` boolean, and a `ready` boolean. Two reader functions check different subsets:
- `get_ready_adventurers()` (line ~157) checks all three.
- `is_adventurer_available()` (line ~165) checks only `status`.
They happen to agree today, but this is fragile. Also note: `send_on_mission`/`send_party_on_mission` set `status = "On Mission"` but do NOT set the `on_mission` boolean — only the orphaned `assign_adventurer_to_mission` sets it. Someday: consolidate to ONE availability signal, fix the readers, remove the others. NOT during a feature — this touches many call sites.
**Mitigation already in place:** all new dispatch UI (C2 drag) reads availability ONLY via `get_ready_adventurers()`, so it inherits the correct logic and adds no fourth check.

## To verify when building C3 (dispatch commit)
- **Mission-board open gate.** Opening the board currently refuses with "You need to hire adventurers first" when the roster is empty. CHECK whether this gate keys off roster *size* (have any adventurers) or *available* count (have Ready ones). If it keys off availability, dispatching all adventurers could lock the player out of opening the board to see in-flight missions or next-day offerings — a soft-lock-adjacent edge that only becomes reachable once C3 makes "all adventurers busy" a real state.

## Untested branches from C2 (wrote-it, couldn't-exercise-it)
Both will get real testing in C3 when dispatch makes adventurers non-Ready and multi-adventurer missions can be staged:
- **Grey-out of non-Ready roster cards** — code runs, but never observed doing its job (all adventurers were Ready during C2 testing).
- **No-double-assign across slots** — never exercised (all C2-era missions were `required_adventurers: 1`, so only one slot existed).

## Cosmetic / deferred
- `⚠️ Portrait not found for class: Ranger` / `Cleric` — roster cards fall back to no portrait for some classes. Missing portrait assets, not a logic bug.
