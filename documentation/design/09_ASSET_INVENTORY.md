# Eternal Guild — Asset Inventory (master list)

*v1, 2026-09-24. Every visual asset the game uses today, plus what the design docs plan.*

**Goal (Raphael, 2026-09-24):** remake **all** of the game's assets in the locked inked style
(`08_ASSET_PROMPT_PACK.md` §1), replacing the stock KayKit models. Since 2026-09-26 the characters are
anime instead (route AN). Since 2026-10-04 the characters are realistic (route RL;
sprint-change-proposal-2026-10-04.md): §0 item 4, §5 and the character spec in `08` §1, all
rewritten by Story 25.31, which built the human cast. This file is the checklist.
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
| …actually used by the game | **106** (89 before Story 25.29) |
| …on disk but unused (don't remake these unless the game starts using them) | 81 (98 before Story 25.29) |
| 2D portraits in use | 11 images (+ 3 P9 dialogue portraits rendered in engine, Story 25.17) |
| Planned assets from the design docs | see §7 |

*(Corrected 2026-09-24, Story 25.1: `Chair 3.obj` ×3 and `Chair 5.obj` ×2 are placed in MainTavern
but were first counted as unused, so used is 89, not 87, and unused is 98, not 100.)*

*(Story 25.29, 2026-09-25: the exterior village and forest put 17 more KayKit files into use: `building_home_B_blue`; `rock_single_D`, `rock_single_E`, `tree_single_A_cut`, `tree_single_B_cut`; and the props `bucket_empty`, `crate_B_small`, `crate_long_A`, `crate_open`, `ladder`, `pallet`, `resource_lumber`, `resource_stone`, `sack`, `target`, `weaponrack`, `wheelbarrow`. Counted by script from the ExteriorWorld diff. The per-section "used" counts in §1–§3 are pre-25.29.)*

At roughly one evening per 3D asset, 89 models is many months. Four things make it survivable:

1. **Kits, not singles.** Remake the hex tiles as one kit and the tavern furniture as one kit:
   shared proportions, bevels and atlas swatches. The second piece of a kit is much faster than the
   first.
2. **One base shape, several variants.** For example `trees_A_small / medium / large` are one tree
   scaled three ways, and `mountain_B`, `mountain_B_grass`, `mountain_B_grass_trees` are one mountain
   with toppings. §3 groups them, and that cuts the real count a lot.
3. **2D comes from the image pipeline.** Portraits, tarot cards, icons and UI art don't need Blender
   at all. The n8n pipeline makes them directly, so they're the cheapest part.
4. **Characters: route RL, realistic bodies on the KayKit skeleton.** Since the realistic correct
   course (2026-10-04, R-1; it reversed the 2026-09-26 anime route AN) the human cast is realistic:
   adult bodies of about 7–7.5 heads, gritty cel shading with ink outlines applied at load, a muted
   earthy palette, faces projected from each character's picked concept sheet, every visible part
   built in Blender. Each body starts from one of two bases, `<art>/blender/realistic_base.blend`
   (REAL-1, men, 1.86 m) or `realistic_base_w.blend` (REAL-2, women, 1.70 m): KayKit's own skeleton
   (all 41 joints) with its rest pose re-proportioned and the 76 KayKit clips retargeted, so nothing
   is rigged or animated from scratch. **Done 2026-10-04 (Story 25.31): all 15 human bodies** (the
   player, the Bartender, the Quest Dealer, the six townsfolk, the six class bodies). The scripts are
   versioned in `tools/blender/realistic/` (on route AN's chain in `tools/blender/anime/`); the
   character spec is in `08`; the route note is in §5. Den Fa and the Cat keep their own rigs and are
   restyled in Story 25.32.

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
| B6 Hourglass Pillar (stacked segments) | nothing (new centrepiece) | `in game` (2026-09-25, Story 25.4: `custom/b6_hourglass_pillar.gltf` 2,480 tris, placed ×1.4 at the round bar's centre; reveal stages 0–4, demo = 4 from `game_config.json`; solid, navmesh re-baked) |
| B2 Round bar (`bar_ring`, `bar_flap`) | `TavernCounterCircular`, `BarCounter` box (both removed) | `in game` (2026-09-25, Story 25.6: `custom/b2_round_bar.gltf` 3,540 tris in `scenes/game/RoundBar.tscn`, 6.2 m across round the pillar; solid counter, flap at the back, 5 `serve_point`s for the Bartender) |
| `bar_stool` (with `seat_point`) | `stool` | `in game` (Story 25.6: `custom/b2_bar_stool.gltf` 124 tris, a low stool at the KayKit chair height; 12 round the bar, seat markers in group `patron_seat`; `stool.obj` kept elsewhere) |
| B1 Hearth (`hearth_stone`, `log_pile`, `andirons`) | `FireplaceBase` / `FireplaceBack` / `Mantel` boxes (removed) | `in game` (2026-09-25, Story 25.5: `custom/b1_hearth.gltf` 2,660 tris in `scenes/game/Hearth.tscn`; the fire's look follows the fireplace state (V2) and is dark at zero Comfort; Den Fa's `sit_point` on the stone seat; wood store under the seat shows the stock; `West_5` window panel swapped for a full wall behind the chimney) |
| B3 Recruitment Desk | `MissionDesk` box (removed) | `in game` (2026-09-25, Story 25.7: `custom/b3_guild_desk.gltf` 458 tris in `scenes/game/GuildDesk.tscn`, facing the room; the Quest Dealer's `work_point` stool behind it, a `chronicle_point` for H5) |
| B4 Mission Board | current 3 × 2 m board (removed) | `in game` (2026-09-25, Story 25.7: `custom/b4_mission_board.gltf` 1,180 tris in `scenes/game/GuildNoticeBoard.tscn`; one pinned notice per open contract, up to 8. The notices stand in for H8's contract scrolls until v1) |
| B5 Wall of the Fallen + plaque | Codex list (Epic 18/19) | `planned` (Batch 2) |
| Back shelf + keg rack (B12) + tinted kegs (H2) | old B2 parts, `Keg` | `in game` (Story 25.6: `custom/b12_back_bar.gltf` 2,558 tris, a round island round the pillar's base inside the bar, bottles on two tiers, beer and mead kegs with taps) |
| B7 Stairs to the quarters + bed | `stairs_wood_decorated` | `planned` (backlog) |
| B8 Infirmary cot | nothing | `planned` (backlog) |
| Dragon Eye Book (Codex set-piece) | nothing | `planned` (backlog) |

Stock models in use today:

| Asset (stock file) | Folder | Notes | Status |
|---|---|---|---|
| `TavernCounterCircular` | furniture | local-only file; replaced by B2 (Story 25.6), no longer used by MainTavern | `replaced` |
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
| A3 Yard dressing: firewood, lantern post, hitching rail, farm plots | — | backlog in `08` | `planned` (KayKit placeholders placed in Story 25.29: firewood, wheelbarrow, sacks, bucket by the plots) |
| A6 The hill, path and town bridge | — | terrain + path + stream + bridge | `in game` (2026-09-25, Story 25.29: `custom/a6_exterior_terrain.gltf` 16,232 tris with a trimesh collider; `custom/a6_bridge.gltf` 840 tris) |
| Village + forest layout (E11/E12 with KayKit) | — | 8 buildings round a square with the well, 22 props, 422 trees/rocks | `in game` (2026-09-25, Story 25.29; KayKit stays until the R1 remakes) |
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

## 5. Characters — patrons, villagers, player, the cat, Den Fa and the staff (17 used)

| Asset (stock file) | Used in | Status |
|---|---|---|
| The player (G1) | the player, everywhere | `in game` (2026-10-04, Story 25.31, route RL: `assets/characters/custom/g1_player_real.glb` from `data/characters/player.json` (`player.gd` reads it; no body in `Player.tscn`): one man (AH-1), a weathered retired adventurer, a long coat, the sword worn at his hip; REAL-1, 9,180 tris, 2 surfaces, 76 clips, Running_A at 0.715). **Fallback:** the KayKit `Rogue` |
| Class bodies (G2–G7): Fighter, Rogue, Mage, Healer, Barbarian, Ranger | the adventurer patrons (~15%, `townsfolk.json` `adventurer_*`), `classes.json` | `in game` (2026-10-04, Story 25.31 S3, route RL: `assets/characters/custom/g2_fighter_real.glb` … `g7_ranger_real.glb`; the men on REAL-1, the women on REAL-2; 7,600–9,056 tris, 2 surfaces, 76 clips; carried weapons and staves are hidden hand props (R-9), the Healer's crystal glows as a prop). The 25.28 inked reskins were folded into this. **Fallbacks:** the stock `Knight`, `Rogue`, `Mage`, `Barbarian` and 25.9's `healer.glb` / `ranger.glb` |
| `Knight` | the Fighter's fallback body; LookDev's scale reference | `stock` (fallback only; no longer visible in the demo) |
| `Barbarian` | the Barbarian's fallback body | `stock` (fallback only) |
| `Mage` | the Mage's fallback, `RealisticPatron.tscn`'s built-in last resort, the staff's `LAST_RESORT_BODY` | `stock` (fallback only) |
| `Rogue` | the Rogue's and the player's fallback, the player's `LAST_RESORT_BODY` | `stock` (fallback only) |
| `Rogue_Hooded` | `RealisticPatron.FALLBACK_MODELS` only (the hooded adventurer retired, AH-6) | `stock` (fallback only) |
| Healer (G5, KayKit-rig) | the realistic Healer's fallback | `fallback` (2026-09-25, Story 25.9: `assets/characters/custom/healer.glb`, the Mage body recoloured cream-white with a hood, tabard, satchel and crystal staff; 6,285 tris, 76 clips). Replaced the missing `Cleric.glb` |
| Ranger (G7, KayKit-rig) | the realistic Ranger's fallback | `fallback` (2026-09-25, Story 25.9: `assets/characters/custom/ranger.glb`, Rogue_Hooded recoloured forest green and brown with a longbow and a quiver; 4,369 tris, 76 clips) |
| Townsfolk (G19, G24): farmer, local, traveller, guard, merchant, old woman | patrons (~85%), villagers in ExteriorWorld | `in game` (2026-10-04, Story 25.31 S2, route RL: `assets/characters/custom/g19_<id>_real.glb`, one GLB each from its pick; five men on REAL-1, the old woman on REAL-2; 6,522–9,530 tris, 2 surfaces, 76 clips; the guard's morion (AH-9); hands empty, the old woman's cane a hidden prop). **Fallbacks:** the Story 25.14 KayKit-kit bodies, `townsfolk_*.glb` (4,169–6,221 tris), listed with origin types and weights in `data/characters/townsfolk.json` |
| The Cat (G11) + her basket (B20) | MainTavern (asleep in the basket by the hearth), ExteriorWorld (a short stroll) | `in game` (2026-09-25, Story 25.15: `assets/characters/custom/g11_the_cat.glb`, her own 22-bone rig, 1,310 tris, clips Sleep/Idle/Walk + Pet; `assets/environment/custom/b20_cat_basket.gltf`, 298 tris; `scenes/game/TheCat.tscn` + `scripts/game/the_cat.gd`: pettable, decision F0). Her realistic redesign (Story 25.32: `g11_the_cat_real.glb`, `b20_cat_basket_real.gltf`) waits for her concept pick (n8n `C_G11_the_cat`) |
| Den Fa, the Architect (G9) | MainTavern (seated on the hearth's bench, the demo's first contact) | `in game` (2026-10-04, Story 25.32, route RL on his own rig: `assets/characters/custom/g9_den_fa_real.glb` from his pick without the wings (R-8): 30 `d_` bones (25.10's minus the 12 wing bones, rest and clips unchanged), one `DenFa_Body`, 6,020 tris, 2 surfaces (the body atlas + `den_fa_mask`), 1 texture 1024², 2.91 m; `DenFa.tscn` look "realistic", the mask kept as imported by `anime_look.gd`; Stage D verdict pending. Before it, 2026-09-25, Story 25.10: `g9_den_fa.glb` (on disk, unused: the one-line rollback), his own 42-bone rig, 2,546 tris, 2.91 m, clips Idle/Sit/Walk + Point/StandUp/SitDown; `scenes/game/DenFa.tscn` + `scripts/game/den_fa.gd`; the mirror mask reflects the hall through `HearthProbe`) |
| The Bartender (G12) | MainTavern (inside the round bar: wipes at the serve points, pours at the taps, restocks at the kegs) | `in game` (2026-10-04, Story 25.31 S1, route RL: `assets/characters/custom/g12_bartender_real.glb`, the burly barkeep from the realistic spike and his pick, on REAL-1; 9,082 tris with his two cloths, 2 surfaces, 81 clips = the 76 + his five bar clips re-posed on his reach; his body block in `staff.json` `barkeep.body`, `look: "realistic"`). **Fallback** (`barkeep.fallback_model_path`), from 2026-09-26, Story 25.13, the art and the seam; the logic is Epic 16's: `assets/characters/custom/g12_bartender.glb`, the Barbarian body as a burly barkeep (apron, belt cloth, rolled sleeves); 4,473 tris, 83 clips = 76 KayKit + the seven staff clips (his Walk_Bar/Wipe/Serve/Pour/Restock and the dealer's Write/Brief: actions are file-global in the shared g12_g13_staff.blend); `scenes/game/Bartender.tscn` + `scripts/game/bartender.gd`) |
| The Quest Dealer (G13) | MainTavern (seated at the guild desk B3: writes, briefs while the RecruitmentPopup is open) | `in game` (2026-10-04, Story 25.31 S1, route RL (R-2): `assets/characters/custom/g13_quest_dealer_real.glb`, the silver-haired elf remade realistic on REAL-2 from her pick; 9,156 tris with the quill (shown only while she writes), 2 surfaces, 79 clips; her body block re-measured (`hip_back` 0.45); `look: "realistic"`. **Her fallback** is the anime body's re-export with the face-seam fix, `g13_quest_dealer_anime_v2.glb` (Q3); the anime GLB and the KayKit g13 stay on disk.) Before it, 2026-09-27, Story 25.30, route AN: `assets/characters/custom/g13_quest_dealer_anime.glb`, the silver-haired elf after Raphael's reference rebuilt as an anime body on the shared base (long platinum hair, elf ears, the gold circlet with a red gem, painted teal eyes, the high-collared plum coat with gold trim, a quill); one skinned `Dealer_Body` with 2 surfaces (face + palette; cap 3) and the `Dealer_Quill` prop on `handslot.r`; 9,459 tris with the quill (budget 10,000); top 2.138 m; 79 clips = the 76 KayKit clips retargeted + her own Walk_Bar/Write/Brief (none of the Bartender's); the toon look and ink outline applied at load (`"look": "anime"`, `scripts/game/anime_look.gd`); her body numbers in `staff.json` `silver_elf.body`; `scenes/game/QuestDealer.tscn` + `scripts/game/quest_dealer.gd`). **The old fallback:** the 25.13 KayKit body, `g13_quest_dealer.glb` (the Mage body with the Rogue head; 4,815 tris, 83 clips), was the anime dealer's `fallback_model_path` until Story 25.31 (silver_elf's is now the anime v2 above). It stays on disk with its `.import` and its extracted PNGs (`g13_quest_dealer_dealer_mage.png`, `g13_quest_dealer_dealer_rogue.png`), and `<art>/blender/g12_g13_staff.blend` stays its source. More looks are planned as `staff.json` variants (Epic 16.2) |
| KayKit skeletons (4 files) | on disk, unused | `stock` (unused) |

Since Story 25.14 patrons are mostly townsfolk whose body matches their origin; the class bodies above still visit as travelling adventurers (~15% since the hooded Rogue retired, decision E1, AH-6).

**No stock KayKit human body is visible in the demo (Story 25.31, 2026-10-04):** the player, the Bartender, the Quest Dealer, every patron (townsfolk and adventurers) and every villager load a route RL body from data; the KayKit and Story 25.9/25.13/25.14 bodies remain only as fallbacks (shown on a broken install) and LookDev's Knight. Den Fa and the Cat (their own rigs) are restyled in Story 25.32. The unused legacy scenes `scenes/npcs/Patron{Farmer,Knight,Mage,Rogue}.tscn` (no scene or script instances them) still reference KayKit textures.

**Route RL (decided 2026-10-04, R-1; the whole human cast built in Story 25.31):** an RL character is
a realistic body built from its base, REAL-1 (`<art>/blender/realistic_base.blend`, men, 1.86 m) or
REAL-2 (`realistic_base_w.blend`, women, 1.70 m): KayKit's skeleton (all 41 joints) with its rest pose
re-proportioned to an adult and all 76 KayKit clips retargeted (the hips and root keys × the leg
ratio, the sits re-fitted to the 0.45 m chairs, one arm pass). A character is a save-as of its base:
its parts, a head texture projected from its picked concept sheet and a painted body atlas merged
into one skinned `<Role>_Body` (≤ 3 surfaces; props separate on their slots, carried ones hidden by
the game), plus the role's own clips, exported to a new `.glb`. The toon look and the ink outline are
applied at load when the data says `"look": "realistic"`, and each body is named by a data path with
a fallback, so paid artists' bodies swap in after the Kickstarter by changing `model_path`. Scripts:
`tools/blender/realistic/README.md`; the spec: `08` §1. The hall and town budgets with the whole cast:
`08` §1 "Budgets".

**Route AN (decided 2026-09-26; built: the Quest Dealer, Story 25.30; since 2026-10-04 only her fallback body):** an AN character is an
anime body built from the shared base `<art>/blender/anime_base.blend`. The base keeps KayKit's
skeleton (all 41 joints) with its rest pose stretched to about 3.5 heads (shorter legs and a longer
torso, so a seated body has room above the desk) and all 76 KayKit clips retargeted: the hips and
root keys scaled by the leg ratio, the three Sit_Chair_* clips re-fitted to the game's 0.44 m seats.
A character is a save-as of the base: its parts, a palette atlas and a painted face merged into one
skinned `<Role>_Body` (≤ 3 surfaces; props stay separate on item bones), plus the role's own clips,
exported to a new `.glb`. The toon look and the shared ink outline are applied at load when the data
says `"look": "anime"`, and each body is named by a data path with a fallback, so paid artists'
bodies swap in after the Kickstarter by changing `model_path`. Scripts and the chain:
`tools/blender/anime/README.md`; the spec: `08` §1's appendix. The rest of the cast went realistic
instead (route RL, above).
This replaces the earlier proposal (new inked meshes on the unchanged KayKit rig, tested first on
the player's `Rogue`).

**Proven 2026-09-25 (spike + Story 25.9), the earlier KayKit route:** outfit variants on KayKit bodies (a recoloured atlas plus bone-attached or skinned pieces) keep all 76 animations; the Healer and the Ranger are built that way. Recipe: `eternal_guild_art/spike/README.md`.

---

## 6. 2D art

| Asset | Where | Notes | Status |
|---|---|---|---|
| Class portraits | `assets/portraits/` (13 images: barbarian ×2, drow-girl, fighter-girl, fighter, healer ×2, mage ×2, ranger, rogue ×2, unnamed; every demo class has a PNG since Story 25.9) | loaded by class name in `scripts/ui/portrait_socket.gd` (`res://assets/portraits/<class>.png`) | `stock` |
| UI images | `assets/ui/` (3 images) | | `stock` |
| P9 dialogue portraits: Den Fa, the Quest Dealer, the Bartender | `assets/characters/portraits/npc/{den_fa,quest_dealer,bartender}.png` (512 × 512) | in-engine renders by the portrait studio (Story 25.17), shown by the dialogue box via `data/dialogue/speakers.json`; the Bartender and the Quest Dealer re-rendered from their realistic bodies (2026-10-04, Story 25.31 S1); Den Fa after 25.32 | `in game` |
| P9 dialogue portraits: the Elder, the Bard | `assets/characters/portraits/npc/{elder,bard}.png` (allowlisted per path) | no body yet: the box draws their plates; Story 25.11 (the Elder) and Story 25.12 (the Bard) render them with the studio | `planned` |
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
| **Healer model**: `data/classes.json` mapped Healer to `Cleric.glb`, which wasn't on disk | 1 | `in game` (2026-09-25, Story 25.9: `custom/healer.glb`) | classes.json:52 |
| Den Fa, "the Architect": 6'4", sylphlike, **bat ears**, **four wings of bare bone (no membrane)** *(2026-10-04, R-8, Raphael: "Den fa without the bone wings": dropped; the rest stands)*, a **featureless mirror mask**, "assembled rather than born" (Hermit IX, lantern, magic hourglass) | 1 hero character | `in game` (2026-09-25, Story 25.10: `custom/g9_den_fa.glb`, `scenes/game/DenFa.tscn`; seated by the hearth, talkable with placeholder lines until Story 10.3; realistic without wings since 2026-10-04, Story 25.32: `custom/g9_den_fa_real.glb`). Lantern + hourglass (H10) stay v1 | 03_STORY_BIBLE:30-38; art brief:29 |
| **Onibi**, the hearth fire-spirit (a shooting-star being living in the fire; LimboAI FSM planned) | 1 | `planned` | art brief:26,30; BMAD game-architecture.md:294,387 |
| Bard (visiting NPC, Epic 9) | 1 | `planned` | EPIC_PROGRESS:258-260 |
| Disturbance NPCs: pickpocket, drunk, rare visitor | 3 | `planned` | EPIC_PROGRESS:332 |
| Villagers + guards (G24): town ambient, overheard barks (the Villager's Voice) | 6 in the demo | `in game` (2026-09-25, Story 25.14: `scenes/npcs/Villager.tscn` placed in ExteriorWorld, three at posts and three on loops; lines in `data/dialogue/villager_barks.json`) | narrative-design.md §Ambient World Population |
| Staff NPCs (Epic 16): the Bartender (G12) and the Quest Dealer (G13) | 2 in the demo | `in game` (2026-09-26, Story 25.13: bodies, seven staff clips, `staff_npc.gd` controllers with a cosmetic autopilot, the `GuildBus.staff_hired` / `staff_fired` seam; in the demo profile both are there from day 1). Hiring, wages and the full work logic stay Epic 16; other staff roles stay `planned` | EPIC_PROGRESS:343,361; narrative-design.md Dialogue Framework 562/564 |
| Farm hands (off-roster workers) | open | ⚑ proposal | 03_STORY_BIBLE:109-110 |
| Recruits and applicants | reuse class models | `planned` | ADVENTURER_PRESENCE_SYSTEM:13,130 |
| The Cat (FR-112): the same cat in every scene, never explained | 1 | `in game` in the tavern and the town (2026-09-25, Story 25.15); the cemetery, church and alley get her when those scenes exist | epics FR-112, AR D11 |
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
| Drinks: beer, mead; later cider and wine (mugs, bottles, barrels) | beer/mead in data; cider/wine ⚑. H1: the beer tankard (full/empty) is in game (Story 25.6, held while drinking); mead/cider/wine vessels wait for those drinks to be served | game_config.json:34, 03_STORY_BIBLE:105-108 |
| Firewood bundles, gold coins | firewood: H3 `custom/h3_firewood_log.gltf` in game (logs on the andirons and in the hearth's wood store, Story 25.5); `h3_firewood_bundle.gltf` built, not yet placed (carrying comes later). Gold coins: stock or VFX | EPIC_PROGRESS:131,139 |
| Equipment (10) and Prior artifacts (6) | built on `shiningsun` as text; the spec says **no icon assets** | LOOT_AND_EQUIPMENT_SYSTEM:112-165,253 |

### 7.6 UI

Codex → "Dragon Eye Book" theming; mission cards (skull danger icons); roster cards/tokens; reveal
panel (warm/muted/dark tones, "no skull iconography spam"); HUD with 5 reputation tiers;
interaction feedback ("floating icons and/or glowing runes on the floor"; the fireplace's is built
since Story 25.23 (V5): `scenes/game/FloorRuneCue.tscn`, a warm-gold rune ring at the hearth's
interact_point while the fire owns E; the other zones' old InteractionInfo planes still don't show);
speech bubbles; narrative panels (Den Fa, Hidden Threshold, Kingdom Chronicle, not
started). Sources: 04_Art_and_Interaction:42-66, EPIC_PROGRESS:9,206-252,329-346,
05_REVEAL_REWORK_PLAN:99.

### 7.7 VFX

Fire burn states (dormant, high, low, dying) and the last fire going out at the end of a run; teal
rune and hourglass glow; glowing floor runes for interaction (the fireplace's built, 25.23); the hall's
light (25.23, V10 and V11: moods today / moody_a / moody_b and six day phases as data in
`game_config.json`, `scripts/game/tavern_lighting.gd`; warm pools from the hearth, torches, candles,
the board's sconces and a bar pool; window spot lights and additive light cards, the fake god rays,
since volumetric fog shafts don't render under the orthographic camera; the picks are Raphael's); coin burst; minigame target glow;
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

## 8. On disk but unused (81 files)

Don't remake these unless the game starts using them. If a wave needs one (for example roads for
`missing_caravan`), move its row into the right section first.

| Folder | Unused files |
|---|---|
| `hexagons/roads` | 15 (all) |
| `hexagons/rivers` | 12 |
| `hexagons/rivers/waterless` | 15 (all) |
| `hexagons/coast/waterless` | 5 (all) |
| `hexagons/props` | 10 (22 before Story 25.29) |
| `hexagons/nature` | 8 (12 before Story 25.29) |
| `hexagons/blue` | 5 (6 before Story 25.29) |
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
