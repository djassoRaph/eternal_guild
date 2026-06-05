# Eternal Guild — Session Changelog: World Map / Hex Generator

> **Purpose.** Bridge document recording what was decided and built this session,
> and what's still open. Next session: fold the relevant parts into the GDD
> proper (`00_GDD_Master.md`, `05_Technical_Architecture.md`, `07_World_Design.md`),
> then this file can be archived. Until then, THIS is the accurate record — where it
> disagrees with the GDD `.md` files, this wins.
>
> Engine: Godot 4.4. Session date: 2026-06-01.

---

## 1. The headline change: the unified map is REAL and partly built

The GDD still treats "settlement choice at game start" as future scope
(`07 §3`, `00 §7.3`). **That is now out of date.** This session built a working,
data-driven hex map that generates, shuffles biomes, and renders. The two-system
split the GDD describes (near-term "dispatch screen" vs. future "Great Settlement
Decision") is abandoned — it is now **one map, generated once at new-game, used
both for settlement choice and later for mission dispatch.**

Confirmed startup flow (target):
**Main Menu → New Game → HexMapTest (map reveals) → player confirms tile → MainTavern.**

---

## 2. What was actually built this session

* **`res://scripts/world/HexGrid.gd`** — static helper converting grid coords to
  world positions. Honeycomb layout (pointy-top, odd rows offset by half a step).
  Spacing standardized to **2.0** (`COL_STEP`/`ROW_STEP`), measured from the
  hand-placed reference scene as ~2.13 X / ~1.96 Z, rounded to 2.0 by choice.
  Entry points: `offset_to_world(col, row)` (primary) and `axial_to_world(q, r)`.
* **`res://scripts/world/HexMapGenerator.gd`** — generates ~19 fixed hex positions,
  SHUFFLES biomes onto them each run (center reserved as `tavern_site`, never
  randomized), maps each biome to a KayKit gltf, instances tiles, prints the
  layout. Shuffle works and is verified.
* **`res://scenes/world/HexMapTest.tscn`** — throwaway test scene hosting the
  generator. NOT the final WorldMap scene; will be promoted/replaced later.
* **Reveal animation (in progress / prompt written):** all 19 hexes spawn as plain
  grass, raised ~3 units, tumbling on the **local X axis** (face-over-edge flip,
  NOT Y), hold ~5s as a "loading" beat, then all flip at once to their assigned
  biome (model swap hidden mid-tumble) and settle down to Y=0. Fixed observer
  camera, no movement. Built with `Tween`.

---

## 3. Design decisions locked this session

* **Reveal style:** lift → X-axis tumble → flip-to-biome → settle. ~5s loading.
  This replaces the old "casino-shuffle / gacha flip" wording in the notes — the
  word "gacha" was imprecise; it's a reveal/assembly animation.
* **Tile selection:** **forced-center for v1** (player clicks the center hex to
  confirm and enter the tavern). "Pick any tile" is DEFERRED to a later pass.
* **Map generation model:** fixed positions every game, biomes shuffled per game
  with controlled composition (~3 forest, 3 mountain, 1 mine, rivers, sea on an
  edge, remainder grass). Procedural generation remains future; this is the
  "smallest version that earns the word shuffle."
* **Persistence rule (unchanged, reaffirmed):** the map is generated ONCE at
  new-game and must be persisted before the tavern loads; never regenerated mid-
  save. Save wiring NOT yet built — see open items.

---

## 4. Cleanup done / decided this session

* **`GlobalControl` autoload** (`res://control.gd`, project.godot line 24) — a stray
  one-off test mistakenly registered as a global singleton; source of
  `ERROR: Card node not found!`. Decision: remove the autoload line; file stays on
  disk. (Approved.)
* **Foreign `_Color1.fbx` nature pack** — 16 FBX files from a non-KayKit pack in
  `assets/environment/hexagons/nature/`, source of the `forest_texture.png` import
  errors. The fake `forest_texture.png` (a renamed copy of `hexagons_medieval.png`)
  was a hack. Decision: swap the one used tree (`Tree_2_C_Color1` → a KayKit
  `tree_single_B` / `trees_A_medium`), then delete all 16 FBX + the fake texture,
  through Godot's FileSystem dock. (Approved; swap-before-delete order.)
* **`camera_3d.gd` on HexMapTest's camera** — that script is MainTavern-specific
  (player-follow, hardcoded size=12, emoji spam). Decision: remove it; the map
  scene uses a plain static `Camera3D` with just a transform. (Approved.)

---

## 5. Open items / known bugs (NOT fixed yet)

* **PlayerManager spawn-bleed.** PlayerManager (autoload) injects/carries the player
  into EVERY scene, including the map scene. Chosen fix: gate player placement on
  the scene having a spawn point — BUT `MainTavern.tscn` currently has NO
  spawn-point node (only `ExteriorWorld.tscn` does, a `PlayerSpawnPoint` Marker3D).
  So the clean fix requires first adding a `PlayerSpawnPoint` to MainTavern, then
  applying the gate. DECISION PENDING (option 1: add tavern spawn point + gate;
  option 2: a `"player_scene"` group opt-in instead). Not a blocker for the reveal.
* **Broken load-game.** Save appears to work but Load (from menu) does not restore
  player position / does not behave like a normal load. This blocks the map's
  save/load gate (a generated world must survive quit/reload identically). Must be
  investigated before save-wiring the map.
* **Map visual tuning (later).** Some grass missing on generated tiles; lake / border
  / mine placement imperfect vs. the planned layout. Cosmetic, deferred.
* **`ExteriorWorld.tscn` dangling references.** References 4 `_Color1.fbx` trees at
  `assets/environment/nature/` (wrong path, files never existed) — broken since
  before this session. Separate cleanup, not urgent.

---

## 6. Next steps (in order)

1. Finish the reveal animation (prompt written).
2. Menu wiring: a main-menu button → `HexMapTest.tscn`; remove the old
   "Choose Starting Location (ASCII Map)" button (archive ASCII generator to
   `documentation/old/`).
3. Forced-center tile selection: make the center hex clickable → confirm → load
   `MainTavern` via `PlayerManager.transition_to_scene()`. On confirm, hand the
   generated map to `WorldManager` (held in memory for the session at minimum).
4. Resolve the PlayerManager spawn-bleed (decision pending, §5).
5. Save/load wiring for the map — gated on fixing the broken load-game first.
6. Missions on hexes (add `location_id` to the dispatch path/signal).
7. GDD rewrite: fold this changelog into `00`, `05`, `07`; then archive this file.

---

## 7. GDD sections that are now STALE (rewrite targets)

* `00_GDD_Master.md §7.3` — "settlement choice future scope" — no longer true.
* `07_World_Design.md §3` onward — the two-map split; "Great Settlement Decision"
  as future — now unified into the single built map.
* `05_Technical_Architecture.md §4` — file tree missing `HexGrid.gd`,
  `HexMapGenerator.gd`, `HexMapTest.tscn`; build order predates the reveal anim.
* Anywhere referencing "casino-shuffle / gacha flip" — reword to the lift/X-tumble/
  flip/settle reveal.
