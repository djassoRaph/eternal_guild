# Eternal Guild — State of the Build

**This table wins over every prose mention of "done / in progress / future" in
any other document.** Update it when a feature ships, not before.
*Last updated: 2026-06-09. Engine: Godot 4.4.*

---

## Shipped (verified in build)

| Feature | Owner | Notes |
|---|---|---|
| Tavern core loop (patrons, beer, gold, taxes) | GameManager | MVP running |
| Firewood / comfort system | GameManager + fireplace_zone | ⚠ two competing drain authorities — see TECH_DEBT |
| Recruitment + roster (5 cap) | GameManager | Roster panel with portraits (old anime set) |
| Dispatch (`send_on_mission` / `send_party_on_mission`) | GameManager :191/:215 | Works; signal lacks `location_id` |
| Party mission UI | — | Phase-1 item, done |
| F12 debug menu | — | done |
| Morning briefing + deferred missions | — | done |
| New Game spine: MainMenu → HexMapTest reveal → settle confirm → MainTavern | WorldManager + PlayerManager | done 2026-06-02 |
| World map stored in memory | WorldManager (`world_map/capitals/landmarks`) | **In-memory only — not saved to disk yet** |
| PlayerManager spawn-bleed fix (`player_scene` group) | PlayerManager | done |
| WorldMapBoard (mission board = world map) | WorldMapBoard.tscn / world_map_board.gd | SubViewport re-render, no reveal anim |
| Hover-to-inspect hexes (Area3D raycast + 2D bubble) | world_map_board.gd | done 2026-06-07, visible in screenshots |
| `required_adventurers` on all 19 mission templates | mission_types.json | capped at 3 |
| Daily missions pinned to hexes | WorldManager.assign_missions_to_hexes() ← GameManager.refresh_available_missions() | done |
| End-of-day report modal (tap-to-advance, N of M) | scene TBD — recon pending | **works but flat — rework in flight** |

## In flight (current work, in order)

| # | Feature | State |
|---|---|---|
| 1 | **End-of-day reveal rework** | Diagnosed ("payout screen" problem). Plan: 05_REVEAL_REWORK_PLAN.md. Recon prompt ready. |
| 2 | Documentation v2 | This folder. Story bible draft awaiting Raphael's corrections. |
| 3 | `location_id` in dispatch signal | The one code gap tying map ↔ missions. After reveal ships. |

## Parked (deliberately not now)

| Feature | Why parked |
|---|---|
| Hourglass time-display pillar (Blender asset) | Design spec complete; model after reveal ships |
| Exterior world NPC flow | Bigger stage for a play that doesn't land yet — after reveal |
| Disk save of world map | Blocked on broken `load_game_state` / Continue bug |
| Fireplace drain-authority unification | TECH_DEBT; not mid-feature |
| Drag-and-drop dispatch | Design explored; after board UX |
| Adventurer dismissal/retirement | Design explored, not finalized |
| Cross-scene adventurer presence (Layer D) | Spec exists (ADVENTURER_PRESENCE_SYSTEM.md) |
| Priors Deep dungeon | Late-game pillar |
| Kickstarter | Blocked on strong visuals (reveal + tarot art + pillar ARE the visuals) |

## Known lies in old docs (do not trust)

- Any mention of Godot 4.3 → engine is **4.4**.
- "20–30 settlements" → cap is **10**.
- WorldGenerateMenu ASCII map, MainTown.tscn, Day-30 door unlock → dead design.
- "Phase 1 90%" / phase numbering → dead.
- itch.io 90-day Demon Lord spine → removed from documentation; the Godot game
  is the only current direction.

## Doc map (what's canonical)

| File | Status |
|---|---|
| 01_VISION.md | canonical, evergreen |
| 02_STATE_OF_THE_BUILD.md | canonical, living (this file) |
| 03_STORY_BIBLE.md | DRAFT — needs Raphael's pass |
| 04_PROCESS.md | canonical |
| 05_REVEAL_REWORK_PLAN.md | active work plan |
| TECH_DEBT.md | keeper, unchanged |
| INTEGRATION_CONTRACT_DISPATCH.md | keeper, unchanged |
| ADVENTURER_PRESENCE_SYSTEM.md | keeper, unchanged |
| 06_Character_Design.md | keeper (Arcana system + Gareth case study) |
| 00/01/02/03/04/05/07 GDD files, both SESSION_* files | → move to `documentation/old/` |
| DATA_SOURCE_OF_TRUTH.md | does not exist yet — produced by Recon B (see reveal plan) |
