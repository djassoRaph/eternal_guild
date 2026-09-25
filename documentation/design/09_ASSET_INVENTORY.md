# Eternal Guild — Asset Inventory (master list)

*v1, 2026-09-24. Every visual asset the game uses today, plus what the design docs plan.*

**Goal (Raphael, 2026-09-24):** remake **all** of the game's assets in the locked inked style
(`08_ASSET_PROMPT_PACK.md` §1), replacing the stock KayKit models. This file is the checklist.
The *how* (image pipeline, Blender prompts, atlas remap, export, Godot check) lives in `08`.

**How to use it:** one row per asset. When an asset moves, update its **Status** here in the same
commit. Status values:

| Status | Meaning |
|---|---|
| `stock` | still the original KayKit (or other stock) file |
| `concept` | concept image picked in `<art>/picked/` |
| `modelled` | built in Blender (`<art>/blender/<id>.blend`), not exported yet |
| `exported` | `.gltf` written to `assets/environment/custom/` |
| `in game` | swapped into the scene/script and passed the Stage D check (08 §6.5) |
| `planned` | the docs want it, nothing exists yet |
| `replaced` | a stock file no longer used where this row says; its replacement is `in game` (the file stays on disk) |

`<art>` = `F:/GAME I AM MAKING/eternal_guild_art`. "Used in" short names: **tavern** =
`scenes/MainTavern.tscn`, **exterior** = `scenes/world/ExteriorWorld.tscn`, **hexworld** =
`scenes/world/HexagoneWorld.tscn`, **map-gen** = `scripts/world/HexMapGenerator.gd`, **patrons** =
`scripts/npcs/RealisticPatron.gd` + `scenes/npcs/RealisticPatron.tscn`, **player** =
`scenes/player/Player.tscn`. Counts come from a scan of every `.tscn`, `.gd` and `.tres` on
2026-09-24.

---

## 0. The size of the job (read this first)

| | Count |
|---|---|
| Model files in `assets/` | 187 |
| …actually used by the game | **89** |
| …on disk but unused (don't remake these unless the game starts using them) | 98 |
| 2D portraits in use | 11 images |
| Planned assets from the design docs | see §7 |

*(Corrected 2026-09-24, Story 25.1: `Chair 3.obj` ×3 and `Chair 5.obj` ×2 are placed in MainTavern
but were first counted as unused, so used is 89, not 87, and unused is 98, not 100.)*

At roughly one evening per 3D asset, 89 models is many months. Four things make it survivable:

1. **Kits, not singles.** Remake the hex tiles as one kit and the tavern furniture as one kit:
   shared proportions, bevels and atlas swatches. The second piece of a kit is much faster than the
   first.
2. **One base shape, several variants.** For example `trees_A_small / medium / large` are one tree
   scaled three ways, and `mountain_B`, `mountain_B_grass`, `mountain_B_grass_trees` are one mountain
   with toppings. §3 groups them, and that cuts the real count a lot.
3. **2D comes from the image pipeline.** Portraits, tarot cards, icons and UI art don't need Blender
   at all. The n8n pipeline makes them directly, so they're the cheapest part.
4. **Characters: re-skin on the KayKit skeleton.** The 5 characters are rigged and animated. Building
   new meshes bound to KayKit's *existing* rig keeps every animation working, instead of rigging and
   animating from scratch (§5).

**Order (waves).** Each wave finishes before the next starts, so the game always looks consistent
in at least one place:

| Wave | What | Why this order |
|---|---|---|
| 1 | Batch 1 from `08` §3: D1, B6, A1+A2, B1, B2 + stools, D2 | Proves the pipeline; includes the pillar |
| 2 | The tavern interior (§1) | The main screen the player stares at |
| 3 | The world-map kit (§3) + landmarks (§4) | Second screen; biggest set, most variants |
| 4 | The exterior world (§2) | Smaller; reuses map-kit pieces (rocks, trees, buildings) |
| 5 | Characters (§5) | Hardest; do it once the style is proven everywhere else |
| 2D | Portraits, tarot, icons, UI (§6) | In parallel with any wave, through n8n |

---

## 1. Tavern interior — `scenes/MainTavern.tscn` (27 used + new pieces)

New pieces from `08` (Batch 1 and 2):

| Asset | Replaces | Status |
|---|---|---|
| B9 Tavern room shell (plank floor, full/window/doorway walls, 1.0 m knee wall, posts, beam) | the `Floor`, `FloorEntrance`, `WallNorth`/`East`/`South`/`West`, `IndoorNorthwall` grey boxes (hidden; their colliders stay) | `in game` (2026-09-24, Story 25.3: `custom/b9_*.gltf`, 28–376 tris a piece; far walls full height, near walls cut to knee height) |
| B10 Front door (timber frame + two swinging leaves) | the open gap in the south wall | `in game` (2026-09-24, Story 25.3: `custom/b10_*.gltf` + `scripts/game/front_door.gd`) |
| B6 Hourglass Pillar (stacked segments) | nothing (new centrepiece) | `concept` |
| B2 Round bar (`bar_ring`, `bar_flap`) | `TavernCounterCircular`, `BarCounter` box | `concept` |
| `bar_stool` (with `seat_point`) | `stool` | `planned` (compare with `stool.obj` first) |
| B1 Hearth (`hearth_stone`, `log_pile`, `andirons`) | `FireplaceBase` / `FireplaceBack` / `Mantel` boxes | `concept` |
| B3 Recruitment Desk | `MissionDesk` box | `planned` (Batch 2) |
| B4 Mission Board | current 3 × 2 m board | `planned` (Batch 2) |
| B5 Wall of the Fallen + plaque | Codex list (Epic 18/19) | `planned` (Batch 2) |
| Back shelf + keg rack (wall props) | old B2 parts | `planned` |
| B7 Stairs to the quarters + bed | `stairs_wood_decorated` | `planned` (backlog) |
| B8 Infirmary cot | nothing | `planned` (backlog) |
| Dragon Eye Book (Codex set-piece) | nothing | `planned` (backlog) |

Stock models in use today:

| Asset (stock file) | Folder | Notes | Status |
|---|---|---|---|
| `TavernCounterCircular` | furniture | local-only file; replaced by B2 | `stock` |
| `table` | furniture | | `stock` |
| `bench` | furniture | | `stock` |
| `Chair 3` | furniture | ×3 under `Furniture/Chairs`; source unknown (§9) | `stock` |
| `Chair 5` | furniture | ×2 under `Furniture/Chairs`; source unknown (§9) | `stock` |
| `barrel` | furniture | also used in exterior | `stock` |
| `table_long_tablecloth_decorated_A` | decorations | | `stock` |
| `table_medium_tablecloth` | decorations | | `stock` |
| `table_small` | decorations | | `stock` |
| `table_small_decorated_A` | decorations | | `stock` |
| `stool` | decorations | becomes `bar_stool` | `stock` |
| `stairs_wood_decorated` | decorations | see B7 | `stock` |
| `wall_doorway_door` | decorations | | `stock` |
| `pillar_decorated` | decorations | a structural column, not the Hourglass Pillar | `stock` |
| `barrier` | decorations | | `stock` |
| `barrier_colum_half` | decorations | | `stock` |
| `torch_mounted` | decorations | | `stock` |
| `candle_thin_lit` | decorations | | `stock` |
| `banner_shield_red` | decorations | | `stock` |
| `keg` | decorations | kit with `keg_decorated`, `barrel_small` | `stock` |
| `keg_decorated` | decorations | | `stock` |
| `barrel_small` | decorations | | `stock` |
| `trunk_large_A` | decorations | | `stock` |
| `bottle_B_green` | decorations | small prop kit: bottle, plate, coins, key | `stock` |
| `plate` | decorations | | `stock` |
| `coin_stack_medium` | decorations | | `stock` |
| `key` | decorations | | `stock` |

Interior kits to build: **tables & seating** (4 tables, bench, stool), **barrels & kegs** (4),
**small props** (bottle, plate, coins, key, candle), **wall pieces** (doorway, torch, banner,
barrier ×2, column).

---

## 2. Exterior world — `scenes/world/ExteriorWorld.tscn` (14 used)

| Asset (stock file) | Folder | Notes | Status |
|---|---|---|---|
| A1 The Guild Tavern (walkable) | — | replaces `building_tavern_blue` ×3 | `in game` (2026-09-25, Story 25.8: `custom/a1_guild_tavern.gltf`, 4,568 tris, solid, door faces the camera side) |
| A3 Yard dressing: firewood, lantern post, hitching rail, farm plots | — | backlog in `08` | `planned` |
| `building_tavern_blue` | hexagons/blue | replaced by A1 | `replaced` (2026-09-25; file kept on disk) |
| `building_blacksmith_blue` | hexagons/blue | also map | `stock` |
| `building_home_A_blue` | hexagons/blue | also map + hexworld | `stock` |
| `building_market_blue` | hexagons/blue | also map | `stock` |
| `building_watermill_blue` | hexagons/blue | also map | `stock` |
| `building_well_blue` | hexagons/blue | exterior only | `stock` |
| `rock_single_A`, `rock_single_B` | hexagons/nature | shared with map kit | `stock` |
| `tree_single_A`, `tree_single_B` | hexagons/nature | shared with map kit | `stock` |
| `barrel` | hexagons/props | | `stock` |
| `crate_A_big` | hexagons/props | | `stock` |
| `tent` | hexagons/props | | `stock` |
| `barrel` | furniture | also tavern | `stock` |

Note: the exterior uses the **map-scale** KayKit buildings scaled up ×3. Once the map kit is
remade (wave 3), decide whether the exterior gets its own full-size buildings or keeps scaled
map pieces.

---

## 3. World-map kit — `HexMapGenerator.gd` + `HexagoneWorld.tscn` (53 used)

(27 tavern + 14 exterior + 53 map + 5 characters = 99; 10 files are shared between the map and the
exterior or the tavern, which leaves the 89 unique files.)

**Base, coast and river tiles** (the ground itself):

| Asset | Variants in use | Notes | Status |
|---|---|---|---|
| Hex base | `hex_grass`, `hex_water` | 2.0 m across flats, top at 0 | `stock` |
| Coast | `hex_coast_A` … `E` (5) | one coast kit | `stock` |
| River | `hex_river_A_curvy`, `hex_river_B`, `hex_river_F` (3) | 12 more river shapes on disk, unused | `stock` |
| Roads | none used yet | 15 on disk; `08` §5-D wants roads for `missing_caravan` | `stock` (unused) |

**Nature** (30 files, about 12 base shapes):

| Base shape | Files in use | Status |
|---|---|---|
| Tree A | `trees_A_small`, `trees_A_medium`, `trees_A_large` | `stock` |
| Tree B | `trees_B_small`, `trees_B_medium`, `trees_B_large` | `stock` |
| Single trees | `tree_single_A`, `tree_single_B` (also exterior) | `stock` |
| Hills | `hill_single_A`, `hill_single_B`, `hills_A_trees`, `hills_B_trees`, `hills_C_trees` | `stock` |
| Mountain A | `mountain_A_grass`, `mountain_A_grass_trees` | `stock` |
| Mountain B | `mountain_B`, `mountain_B_grass`, `mountain_B_grass_trees` | `stock` |
| Mountain C | `mountain_C_grass`, `mountain_C_grass_trees` | `stock` |
| Rocks | `rock_single_A`, `rock_single_B`, `rock_single_C` (A, B also exterior) | `stock` |
| Water plants | `waterlily_A`, `waterlily_B`, `waterplant_A`, `waterplant_B`, `waterplant_C` | `stock` |
| Clouds | `cloud_big`, `cloud_small` (hexworld) | `stock` |

**Buildings** (map-scale toppers, 12 used):

| Asset | Used in | Notes | Status |
|---|---|---|---|
| A2 Guild Tavern (hex miniature) | map-gen `TAVERN_TOPPER` | derived from A1 | `in game` (2026-09-25, Story 25.8: `custom/a2_guild_tavern_mini.gltf`, 996 tris) |
| C9 Home marker (guild banner) | map-gen `HOME_MARKER`, tavern hex | shares the sign's hourglass emblem | `in game` (2026-09-25, Story 25.8: `custom/c9_home_marker.gltf`, 116 tris) |
| `building_tavern_blue` | map-gen, exterior | replaced by A2 | `replaced` (2026-09-25; file kept on disk) |
| `building_castle_blue` | map-gen | capital / fortress missions | `stock` |
| `building_barracks_blue` | map-gen | | `stock` |
| `building_blacksmith_blue` | map-gen, exterior | | `stock` |
| `building_church_blue` | map-gen | | `stock` |
| `building_home_A_blue` | map-gen, exterior, hexworld | village missions | `stock` |
| `building_lumbermill_blue` | map-gen | | `stock` |
| `building_market_blue` | map-gen, exterior | market-town missions | `stock` |
| `building_mine_blue` | map-gen, hexworld | `rare_ore_mining` | `stock` |
| `building_watermill_blue` | map-gen, exterior | | `stock` |
| `building_windmill_blue` | map-gen | | `stock` |

**Map props and UI:**

| Asset | Used in | Status |
|---|---|---|
| `bucket_water` | hexworld | `stock` |
| `flag` (ui) | hexworld | `stock` |

---

## 4. Hex landmarks (mission sites) — from `08` §5-D

| Asset | Mission templates | Status |
|---|---|---|
| D1 Prior Ruins (gate asset) | `ancient_artifact`, Hidden missions | `in game` (2026-09-24, Story 25.2: `custom/d1_prior_ruins.gltf`, 1,956 tris; the reserved ruin hex next to the tavern) |
| D2 Demon Cult Crypt | `demon_cult_investigation` | `concept` (crypt v2) |
| D3 Dragon's Lair (+ skull) | `dragon_reconnaissance` | `planned` (Batch 2) |
| D4 Bandit Hideout | `bandit_camp` | `planned` (Batch 2) |
| D5 Goblin Warren | `goblin_patrol` | `planned` (Batch 2) |
| D6 Slime Bog | `slime_extermination` | `planned` (Batch 2) |
| D7 Herb Glade | `herb_collection` | `planned` (Batch 2) |
| Den Fa's Hermit Tower | Hidden missions hub | `planned` (backlog) |
| Demon Lord's Fortress | endgame | `planned` (backlog) |
| Refugee camp | `refugee_escort` | `planned` (backlog) |
| Broken caravan | `missing_caravan` | `planned` (backlog) |

The other mission templates use map buildings from §3 (mine, tower, castle, market, village,
river crossing).

---

## 5. Characters — patrons and player (5 used)

| Asset (stock file) | Used in | Status |
|---|---|---|
| `Knight` | patrons | `stock` |
| `Barbarian` | patrons | `stock` |
| `Mage` | patrons | `stock` |
| `Rogue` | patrons, player | `stock` |
| `Rogue_Hooded` | patrons | `stock` |
| `Cleric` (Healer class) | `data/classes.json`:52 | **missing**: the file isn't on disk |
| KayKit skeletons (4 files) | on disk, unused | `stock` (unused) |

**Route (proposal ⚑):** keep KayKit's rig and animations, and build new inked-style meshes bound to
that same skeleton, one class at a time. This avoids rigging and animating from scratch. Test it on
one character (the player's `Rogue`) before committing the other four.

---

## 6. 2D art

| Asset | Where | Notes | Status |
|---|---|---|---|
| Class portraits | `assets/portraits/` (11 images: barbarian, drow-girl, fighter-girl, fighter, healer ×2, mage ×2, rogue ×2, unnamed) | loaded by class name in `scripts/ui/portrait_socket.gd` (`res://assets/portraits/<class>.png`) | `stock` |
| UI images | `assets/ui/` (3 images) | | `stock` |
| K1–K3 key art | `<art>/picked/` | inked, picked 2026-09-24 | `concept` (done as key art) |

---

## 7. Planned assets from the design docs

From a full read of `documentation/design/` (not `old/`), `EPIC_PROGRESS.md`, `TECH_DEBT.md` and
the content JSON in `data/`, done 2026-09-24. Sources are file:line. The loot entries come from the
`shiningsun` branch, where Epic 12 is built.

**Also read:** the July 2026 art-direction brief written for the artist Guilo, which lives outside
this repo in the BMAD workspace: `F:\bmad - shiningsun desktop\_bmad-output\planning-artifacts\art-direction-brief.md`
("art brief" below). The commissioned tavern artwork that set the inked style (08 §1) matches its
recommended first piece, "The Threshold". The brief's written target was "painterly pixel"; the
delivered piece is inked, and the style lock follows the delivered piece. The brief also calls the
pillar "stone-and-roots": the B6 concept has no roots yet.

### 7.1 Tarot cards: the biggest 2D set

| Asset | Count | Status | Source |
|---|---|---|---|
| Tarot portraits: 22 Major + 56 Minor, each with an `art_brief` in `data/tarot_deck.json` | 78 | `planned`. Placeholder paths; `assets/characters/portraits/tarot/` doesn't exist yet | `tarot_deck.json`, 01_VISION:29-30, 03_STORY_BIBLE:58-61 |
| Emotional variants `_wounded` / `_dead` (socket already built) | up to 156 | `planned` | `scripts/ui/portrait_socket.gd`:21-25 |
| Reversed (corrupted) cards | open | `planned` | 06_Character_Design:40-41 |
| Evolution stages (e.g. Gareth: Seven of Swords → Chariot → Justice → Emperor) | open | `planned` (Epic 17 ~5%) | 06_Character_Design:36,47-65 |
| Reserved cards: Den Fa = Hermit IX, player = World XXI | 2 of the 78 | standing decision | 03_STORY_BIBLE:33,62 |

### 7.2 Characters and NPCs

| Asset | Count | Status | Source |
|---|---|---|---|
| **Healer model**: `data/classes.json` maps Healer to `Cleric.glb`, which isn't on disk | 1 | missing today | classes.json:52 |
| Den Fa, "the Architect": 6'4", sylphlike, **bat ears**, **four wings of bare bone (no membrane)**, a **featureless mirror mask**, "assembled rather than born" (Hermit IX, lantern, magic hourglass) | 1 hero character | `planned`. Design marked **decided** in the art brief | 03_STORY_BIBLE:30-38; art brief:29 |
| **Onibi**, the hearth fire-spirit (a shooting-star being living in the fire; LimboAI FSM planned) | 1 | `planned` | art brief:26,30; BMAD game-architecture.md:294,387 |
| Bard (visiting NPC, Epic 9) | 1 | `planned` | EPIC_PROGRESS:258-260 |
| Disturbance NPCs: pickpocket, drunk, rare visitor | 3 | `planned` | EPIC_PROGRESS:332 |
| Staff NPCs (Epic 16) | open | `planned` | EPIC_PROGRESS:343,361 |
| Farm hands (off-roster workers) | open | ⚑ proposal | 03_STORY_BIBLE:109-110 |
| Recruits and applicants | reuse class models | `planned` | ADVENTURER_PRESENCE_SYSTEM:13,130 |
| Beast-kin race (foxes, badgers, wolves, cats) | open | design only | 06_Character_Design:22-24 |
| Character animations: idle, walk, wave, sit/cheer/stand (patrons) | per model | partly built | ADVENTURER_PRESENCE_SYSTEM:42-43,91 |

**Enemies need no art.** The player never sees a mission (01_VISION:34-35), and bespoke mission
illustrations are ruled out (05_REVEAL_REWORK_PLAN:110).

### 7.3 Tavern and exterior (beyond §1–§2)

| Asset | Status | Source |
|---|---|---|
| Cellar (opened at upgrade tier 1; the pillar's roots) | ⚑ proposal | 03_STORY_BIBLE:94-95 |
| Tavern upgrade tiers (count not given) | `planned`, feature flag off | 03_STORY_BIBLE:25 |
| "Great Hall" final interior | aspirational | 04_Art_and_Interaction:27 |
| Avatar spots: door, lobby, fire, medical corner, rest | markers, not art | ADVENTURER_PRESENCE_SYSTEM:113-117 |
| Farmland: hops, orchard, vines (= A3 in §2) | ⚑ proposal, Epic 15 at 0% | 03_STORY_BIBLE:102-112 |
| Town bridge at the end of the tavern path | reference | 04_Art_and_Interaction:61 |
| City hub: church, apothecary, alley (Epic 23) | `planned`, 0% | EPIC_PROGRESS:350 |
| 4 exterior trees with broken `_Color1.fbx` references | broken today, "not urgent" | session.md:98-100 |

### 7.4 World map (beyond §3–§4)

| Asset | Status | Source |
|---|---|---|
| 5 capitals + their landmarks (Orrery of the Silent Sky, Weeping Monoliths, Sunken Archives, Mirror of Heat, Rift of Whispers) | data only, "currently dead/unused" | capitals.json:3-66, 02_STATE:35 |
| Biomes with no tiles: high mountain, desert, volcanic, deadland | data only | capitals.json:7,46,59 |
| Priors Deep dungeon | parked, late game | 02_STATE:49 |
| Dungeon tower (map landmark) | `planned` | art brief:27 |
| The chasm at the world's edge | `planned` | art brief:27 |
| Faction territories (assassin, noble/merchant, vice) | future scope | 07_World_Design:52-54 |

### 7.5 Items and props

| Asset | Status | Source |
|---|---|---|
| Drinks: beer, mead; later cider and wine (mugs, bottles, barrels) | beer/mead in data; cider/wine ⚑ | game_config.json:34, 03_STORY_BIBLE:105-108 |
| Firewood bundles, gold coins | built as gameplay; art is stock or VFX | EPIC_PROGRESS:131,139 |
| Equipment (10) and Prior artifacts (6) | built on `shiningsun` as text; the spec says **no icon assets** | LOOT_AND_EQUIPMENT_SYSTEM:112-165,253 |

### 7.6 UI

Codex → "Dragon Eye Book" theming; mission cards (skull danger icons); roster cards/tokens; reveal
panel (warm/muted/dark tones, "no skull iconography spam"); HUD with 5 reputation tiers;
interaction feedback ("floating icons and/or glowing runes on the floor", still missing for the
fireplace); speech bubbles; narrative panels (Den Fa, Hidden Threshold, Kingdom Chronicle, not
started). Sources: 04_Art_and_Interaction:42-66, EPIC_PROGRESS:9,206-252,329-346,
05_REVEAL_REWORK_PLAN:99.

### 7.7 VFX

Fire burn states (dormant, high, low, dying) and the last fire going out at the end of a run; teal
rune and hourglass glow; glowing floor runes for interaction; coin burst; minigame target glow;
speech-bubble pop and fade; hex reveal animation (lift, tumble, flip, settle), which the
WorldMapBoard doesn't have yet. Sources: EPIC_PROGRESS:132-140,252, 03_STORY_BIBLE:116,
session.md:40-51, 02_STATE:23.

### 7.8 Key art and marketing

Kickstarter visuals = **reveal + tarot art + pillar** (02_STATE:50). K1–K3 inked key art exists
(§6).

### 7.9 Open decisions that change the counts

1. **Who makes the tarot art:** a commissioned artist ("Guilo", EPIC_PROGRESS:426) or the
   Nano Banana prompt set (03_STORY_BIBLE:67-68)? That's 78+ images either way. The July art brief
   says each card gets "a permanent commissioned portrait" (art brief:28).
7. **End-of-Day Reveal panels:** focused 2D portrait panels, "a returning adventurer, alone,
   named, no numbers". They're campaign-blocking per the art brief (:23,31). Are they the tarot
   portraits reused, or their own paintings?
2. **Tarot variants:** how many reversed and evolution cards, and are `_wounded` / `_dead` separate
   paintings or overlays? This decides whether the set is 78 or 200+.
3. **Classes:** 4 (`shiningsun`, commit `ba86178`), 5 (`classes.json` here) or 6
   (`game_config.json`:27)? Each class needs a character model and portraits.
4. **Portrait style:** painterly Ghibli (04_Art_and_Interaction:17-20) vs pixel + Berserk shadow
   (01_VISION:50-52). The locked inked look (08 §1) may settle it.
5. **Beast-kin:** are they visual (their own models and portraits) or text only?
6. **Settlements:** max 10 (01_VISION:37) vs 20–30 (07_World_Design:37). This decides how many
   capital and landmark pieces the map needs.

---

## 8. On disk but unused (98 files)

Don't remake these unless the game starts using them. If a wave needs one (for example roads for
`missing_caravan`), move its row into the right section first.

| Folder | Unused files |
|---|---|
| `hexagons/roads` | 15 (all) |
| `hexagons/rivers` | 12 |
| `hexagons/rivers/waterless` | 15 (all) |
| `hexagons/coast/waterless` | 5 (all) |
| `hexagons/props` | 22 |
| `hexagons/nature` | 12 |
| `hexagons/blue` | 6 |
| `furniture` | 3 (`candle.obj`, `crate.glb`, `stairs_wide.obj`) |
| `characters/kaykit_skeletons` | 4 (all) |
| `hexagons/base` | 3 |
| `characters/kaykit_adventurers` | 1 |

---

## 9. Sources unknown (ART-6)

*Added 2026-09-24 (Story 25.1).* Every third-party pack folder now has a `LICENSE-SOURCE.md`. KayKit
(Adventurers, Skeletons, Dungeon Remastered 1.1, Medieval Hexagon 1.0) and Kenney are **CC0**, and
`TavernCounterCircular.glb` is project-owned. The files below have **no known source or licence**.
**Replace them, or find their source, before anything ships** (Steam/Kickstarter credits, and Steam's
AI-content disclosure).

| File(s) | Folder | In use? | Note |
|---|---|---|---|
| `barrel.glb`, `bench.glb`, `crate.glb`, `table.glb` + `*_albedo.png` | `environment/furniture` | yes (not crate) | PBR albedo textures; not KayKit |
| `Chair 3.obj`, `Chair 5.obj` | `environment/furniture` | yes | from a `chair.blend`; `.mtl` missing |
| `stonefireplace.jpg` | `environment/furniture` | no | |
| `barbarian.jpg`, `drow-girl.jpg`, `fighter-girl.jpg`, `healer.jpg`, `mage portrait.jpg`, `rogue.jpg`, `unnamed.jpg`, `fighter.png`, `healer.png`, `mage.png`, `rogue.png` | `portraits` | the PNGs, via `portrait_socket.gd` | JPGs carry Picasa metadata |
| `fighter.png`, `knight.png`, `mage.png`, `rogue.png` | `characters/portraits` | no | |
| `coins.mp3`, `cointinkle.wav` | `audio/sfx` | yes (`sfx_manager.gd`) | |
| `tavernbackgroundimage.png` | `ui` | yes (MainMenu) | replaced by Story 25.25 |
| `fire/log.png` | `ui` | yes (fire minigame) | |
