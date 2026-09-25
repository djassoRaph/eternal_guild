# Eternal Guild — State of the Build

**This table wins over every prose mention of "done / in progress / future" in
any other document.** Update it when a feature ships, not before.
*Last updated: 2026-06-14. Engine: Godot 4.4.*

---

## Shipped (verified in build)

| Feature | Owner | Notes |
|---|---|---|
| Tavern core loop (patrons, beer, gold, taxes) | GameManager | MVP running |
| Firewood / comfort system | GameManager + fireplace_zone | ⚠ two competing drain authorities — see TECH_DEBT |
| Recruitment + roster (5 cap) | GameManager | Roster panel with portraits (old anime set) |
| Dispatch (`send_on_mission` / `send_party_on_mission`) | GameManager :191/:215 | Works; `location_id` now carried (done) |
| Party mission UI | — | done |
| F12 debug menu | — | done |
| Morning briefing + deferred missions | — | done |
| New Game spine: MainMenu → HexMapTest reveal → settle confirm → MainTavern | WorldManager + PlayerManager | done 2026-06-02 |
| Unified world map: hex grid + biomes + landmarks, rendered under pixel shader | WorldManager + HexMapGenerator | done — verified in-game 2026-06-14 |
| PlayerManager spawn-bleed fix (`player_scene` group) | PlayerManager | done |
| WorldMapBoard (mission board = world map) | WorldMapBoard.tscn / world_map_board.gd | SubViewport re-render, no reveal anim |
| Hover-to-inspect hexes (Area3D raycast + 2D bubble) | world_map_board.gd | done 2026-06-07 |
| `required_adventurers` on all 19 mission templates | mission_types.json | capped at 3 |
| Daily missions pinned to hexes | WorldManager.assign_missions_to_hexes() ← GameManager.refresh_available_missions() | done |
| Dispatch from the map (click adventurer → hex mission) | WorldMapBoard + GameManager | done — verified in-game 2026-06-14 |
| MainMenu "Continue" → real SaveSystem.load_game() | main_menu.gd | done 2026-06-14 — orphan `savegame.dat` stub removed |
| Prior Ruins (D1) on a reserved hex next to the tavern; hover shows "Unknown Ruins"; missions skip it | HexMapGenerator (`_reserve_ruin`) + WorldManager (`is_mission_eligible`) + world_map_board.gd | done 2026-09-24 (Story 25.2). First asset through the inked pipeline |
| Tavern hall is a real room: B9 plank floor, timber-and-stone far walls with windows, knee-height near walls (cutaway), and a B10 front door that swings open for patrons and the player | `MainTavern.tscn` › `Architecture/Shell` + `scripts/game/front_door.gd`; failsafe Test 7 | done 2026-09-24 (Story 25.3). Grey boxes hidden, colliders unchanged; navmesh re-baked with the new colliders (verified: patrons in → table → out, player out through the door to the exterior) |
| The Guild Tavern outside (A1) replaces the KayKit tavern: solid, door at the camera side, "Press E" at the door, arrival in front of it; the exterior draws ink outlines; the map's tavern hex shows the A2 miniature + C9 home banner (old saves too) | `ExteriorWorld.tscn` (`GuildTavern`, `TavernEntranceZone`, `Camera3D/EdgeQuad`), `HexMapGenerator.gd` (`TAVERN_TOPPER`, `HOME_MARKER`, `home_toppers_for`); failsafe Test 8 | done 2026-09-25 (Story 25.8) |
| The outside is a place: terrain as the real ground (nothing floats, shadows attach), the tavern on a hill with a path down to a bridge over a stream, the village round a square, forest all around, boundary walls | `ExteriorWorld.tscn` (`Terrain`, `Village`, `Yard`, `Forest`, `Bounds`), `custom/a6_exterior_terrain.gltf`, `custom/a6_bridge.gltf`; failsafe Test 9 + `test/fixtures/exterior_heightfield.json` | done 2026-09-25 (Story 25.29) |
| The Hourglass Pillar rises through the round bar: rune bands and a glowing teal hourglass under a broken crown; reveal stages 0–4 (demo = full, from data); solid | `scenes/game/HourglassPillar.tscn`, `scripts/game/hourglass_pillar.gd`, `game_config.json` › `pillar_reveal_stage`; failsafe Test 10 | done 2026-09-25 (Story 25.4) |
| Asset-pipeline dev tooling: LookDev scene, export folders, failsafe Test 5 (asset-path integrity) | `scenes/dev/LookDev.tscn` + `scripts/dev/look_dev.gd`; `test/failsafe_test.gd` | done 2026-09-24 (Story 25.1, not player-facing). Renderer verified: **Forward+** |

## In flight (current work, in order)

| # | Feature | State |
|---|---|---|
| 1 | **Save / Load — make a full session round-trip** | Continue fix SHIPPED. **Active bug:** pause-menu QuitButton/MainMenuButton have stale `.tscn` `[connection]` blocks wiring them to `main_tavern.gd` (quit-without-save), pre-empting `pause_menu.gd`'s save-first handlers → on-disk file stays at the last autosave (pre-hire state). Fix = strip those two connection blocks. Then verify hire → Save & Exit → Continue restores roster + gold. |
| 2 | **World-map persistence** | After save round-trip works: serialize `WorldManager.world_map` + `chosen_center` into the save dict; on load, repopulate WorldManager and use HexMapGenerator's existing static-display mode (no regen). `capitals`/`landmarks` are currently dead/unused — decide if they matter. |
| 3 | Player spawn position on load | Player spawns at (0,0,0) instead of the found PlayerSpawnPoint (7,1,2); no position is serialized. Decide: restore exact position, or always spawn at a defined "morning" point. Small, after #1–2. |

## Parked (deliberately not now)

| Feature | Why parked |
|---|---|
| **End-of-day reveal rework** | Diagnosed ("payout screen" problem); plan in 05_REVEAL_REWORK_PLAN.md. Was next, but save/load jumped the queue. Resume after save round-trip is solid. |
| Hourglass time-display pillar (Blender asset) | Design spec complete. Moved up 2026-09-24: Batch 1 of the asset pipeline, modelled right after the D1 gate asset (08_ASSET_PROMPT_PACK §3, card B6). Stands mid-hall inside the round bar; style locked to inked |
| Exterior world NPC flow | Bigger stage for a play that doesn't land yet — after reveal |
| Fireplace drain-authority unification | TECH_DEBT; not mid-feature. (LimboAI evaluated as overkill — a single-owner FSM is enough.) |
| Drag-and-drop dispatch | Design explored; after board UX |
| Adventurer dismissal/retirement | Design explored, not finalized |
| Cross-scene adventurer presence (Layer D) | Spec exists (ADVENTURER_PRESENCE_SYSTEM.md) |
| Priors Deep dungeon | Late-game pillar |
| Kickstarter | Blocked on strong visuals (reveal + tarot art + pillar ARE the visuals) |

## Known lies in old docs (do not trust)

- Any mention of Godot 4.3 → engine is **4.4**.
- "20–30 settlements" → cap is **10**.
- "World map in-memory only / disk save blocked on broken load" → load is FIXED; persistence is active work (in-flight #2), not a blocker.
- "Reveal rework in flight / recon ready" → reveal is PARKED; save/load is current.
- WorldGenerateMenu ASCII map, MainTown.tscn, Day-30 door unlock → dead design.
- "Phase 1 90%" / phase numbering → dead.
- itch.io 90-day Demon Lord spine → removed; the Godot game is the only current direction.
- Anything in `documentation/old/` → archived, stale, ignore.

## Doc map (what's canonical)

| File | Status |
|---|---|
| 01_VISION.md | canonical, evergreen |
| 02_STATE_OF_THE_BUILD.md | canonical, living (this file) |
| 03_STORY_BIBLE.md | DRAFT — needs Raphael's pass |
| 04_PROCESS.md | canonical |
| 05_REVEAL_REWORK_PLAN.md | parked work plan (resume after save/load) |
| TECH_DEBT.md | keeper |
| INTEGRATION_CONTRACT_DISPATCH.md | keeper |
| ADVENTURER_PRESENCE_SYSTEM.md | keeper |
| 06_Character_Design.md | keeper (Arcana system + Gareth case study) |
| 08_ASSET_PROMPT_PACK.md | working doc: 3D art pipeline + prompts (tavern, map, hex landmarks); automation in `tools/n8n/` |
| 09_ASSET_INVENTORY.md | master checklist of every visual asset (used today + planned) for the full inked remake, with status per asset and wave order |
| 00_GDD_Master.md + any SESSION_* files | → move to `documentation/old/` |
| DATA_SOURCE_OF_TRUTH.md | does not exist yet — produced by Recon B (see reveal plan) |
