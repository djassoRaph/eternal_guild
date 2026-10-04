# Eternal Guild — 3D Asset Prompt Pack

*Tavern (outside + inside) · World map · Hex landmarks — v1, 2026-09-24*

> **How to use this doc.** Stage A prompts go into an image generator (any of them).
> Stage B–C prompts go into Claude Code **on your PC**, with Blender open and a
> Blender MCP connected. Every size and budget here was measured from files in this
> repo. If a number and your eye disagree, trust a KayKit model imported next to
> the new asset. Characters are the exception: they follow the realistic character
> spec in §1 (route RL; rewritten by Story 25.31).

---

## 0. Start here: is this worth your time right now?

An honest check against your own docs:

- **In progress** (`02_STATE_OF_THE_BUILD.md`): the save/load round-trip. **Parked:** the
  reveal rework, which is the heart of the game.
- **Kickstarter is blocked on visuals.** Your doc names which ones: *reveal + tarot
  art + pillar*. Tavern and map art help screenshots and a trailer, but they aren't
  on that list.
- So art works as a **side track** alongside other work: it uses a different part of your brain, it keeps you motivated, and it
  looks good in screenshots. It doesn't replace finishing save/load.

**Rules that keep this finishable:**

1. **Lock the style first.** Make 3 key-art images (§4). It's cheap, one sitting, and they become the
   reference for every model.
2. **Push one gate asset all the way through.** The Prior Ruins landmark (§5-D1) goes all the way into Godot
   under the pixel shader **before you make anything else**.
3. **Batch 1 has a hard cap of 6 assets** (§3). Everything else goes in the backlog.
4. **Know when to stop.** If the gate asset still looks wrong next to KayKit after 2 tries,
   stop. KayKit stays, and you've lost an evening instead of a month.
5. **Reuse before you generate.** Most mission locations already have a KayKit model
   (table in §5-D). Only make what KayKit can't give you.

---

## 1. The style rule: environment and characters

> **Since 2026-10-04 (sprint-change-proposal-2026-10-04.md, R-1):** the cast is REALISTIC, not anime.
> Route RL (`tools/blender/realistic/`, rigs REAL-1 for men and REAL-2 for women) replaced route AN;
> Story 25.31 built the human cast on it and rewrote this section (2026-10-04). The AN spec is kept at
> the end of the character spec as an appendix: it still governs the anime Quest Dealer, her fallback body.

The style rule has two halves (A-1, 2026-09-26; the characters' half realistic since R-1, 2026-10-04):

- **Environment** (buildings, rooms, furniture, props, landmarks, tiles): the KayKit box, below.
  Unchanged.
- **Characters** (the people of the cast: the staff, patrons, adventurers, the player, townsfolk):
  realistic, route RL. The look is summed up under "Characters" below; the rules are the
  **character spec (route RL)** after the build contract. Den Fa and the Cat are Story 25.32's
  (restyled realistic on their own rigs, R-3).

The build contract below holds for both.

### Environment (unchanged)

Every new asset must look like it came in the same box as KayKit:

- low-poly, chunky, slightly toy-like proportions, lightly bevelled edges. No surface
  detail modelled in: no individual bricks or planks unless they're big chunks.
- flat faces coloured from the **shared KayKit atlas**
  `assets/environment/hexagons/base/hexagons_medieval.png` (1024², 8 × 4 vertical-gradient
  swatches). No photo textures, no painted-on dirt, **no baked lighting**.
- The Godot pixel-art and edge-detection shader adds the final look on top.

**The biggest risk:** AI image-to-3D tools output a dense, lumpy mesh with a painted texture and baked
shadows. Under your shader, next to KayKit, that reads as "asset flip". The pipeline
below avoids it. Claude either **rebuilds** the asset in low-poly or **remaps** it onto the atlas.

**Mood** (from `01_VISION.md` / `03_STORY_BIBLE.md`):

| Where | Feel |
|---|---|
| Interior | Ghibli warmth, amber firelight, soft pools of light |
| Exterior | Mignola/Hellboy stark shadow shapes, cool dusk |
| The Priors | weathered pale stone, **teal glowing runes**, hourglass motifs |
| Tone ceiling | melancholy and weathered. Never glamorous, never gory |

**Target look (locked 2026-09-24): inked.** The style reference is the commissioned tavern
artwork, saved as `<art>/refs/commission_tavern_pillar.webp`: confident black outlines, flat
colours with two or three tones per material, hard Mignola-style shadow shapes. In game, most of
this look comes from the edge-detection outlines, the flat atlas colours and hard lighting, not
from the models, so the modelling rules above don't change. Picked key art: K1 inked v1, K2 =
style test S2 v1 (it came out inked despite its "pixel" prompt), K3 inked v1.

### Characters: realistic (route RL) — rewritten by Story 25.31

Decided 2026-10-04 (GDD decision log R-1…R-9, reversing A-1's anime for humans; first proved by the
realistic Bartender spike, `5ae8dc0`). The environment above keeps its models and inked look (A-5;
25.23 changed only the hall's lights):

- **Realistic adult proportions:** about 7–7.5 heads; men on REAL-1 (1.86 m), women on REAL-2
  (1.70 m); tops 1.50–2.25 m with headwear (the front door's 2.30 m lintel).
- **Gritty cel shading with ink outlines,** applied in Godot when the body loads (`anime_look.gd`,
  the same runtime as the anime dealer's): two toon tones, the ink hull, a muted, desaturated, earthy
  palette (R-7), worn and patched clothes, weathered faces. Not modelled or painted in.
- **Faces projected from the picked concept sheet** (no painted anime face presets): each character's
  turnaround is painted with n8n (AH-2), Raphael picks one, and the head texture is cut from it and
  baked seamless. At ortho 12 a head is about 11 px tall: faces proper are read in the dialogue
  portraits (A-2), silhouettes, headwear, beards and coats at game zoom.
- **Two textures per body:** the projected head and a painted body atlas, ≤ 1024², mipmaps on. Still
  **no baked lighting**.
- **Hair as opaque shells and falls,** never alpha cards.
- **Under the hood:** the KayKit skeleton (all 41 joints) with its rest pose re-proportioned, so the
  76 KayKit clips keep working (retargeted, the sits re-fitted, one arm pass).
- **Hands empty (R-9):** carried items (weapons, staves, the quill, the cane) are separate props on
  their slots, hidden by default and shown by the game only when it makes sense; worn gear shows.
- **References:** each character's pick, `<art>/picked/C_<id>.png` (the concept jobs: "Character
  concepts" below); the spike, `<art>/realistic_test/`.
- **A demo cast:** Claude built the Kickstarter demo's cast; after funding, paid 3D artists may redo
  it to the character spec below, and the bodies swap by data path (A-6). Colours are demo-grade
  and never block anything.

### Build contract (Godot-side rules) — added by Story 25.1

These sit on top of the style rules above. Every new asset card (Epic 25 / Epic 26 stories)
assumes them. **They stay in force for characters:** metres, +Y up, origin at bottom-centre on
0,0,0 (for a character, that is the armature root, between the feet), and a snake_case asset id
(`g12_bartender_real`). The character spec after this list adds the character rules.

- **Units and origin:** metres; +Y up in Godot (Z-up in Blender, exported with +Y Up ON); origin
  at bottom-centre on 0,0,0; all transforms applied.
- **Roughness is the outline switch.** `edge_detection.gdshader` only draws ink outlines where
  screen roughness is above 0 (`ceil(roughness)`).
  - Every normal surface: roughness above 0 (KayKit-like, about 0.5–1.0).
  - Surfaces that should read as *light, not ink* (pillar runes, Onibi, magic glow, VFX meshes):
    set roughness to **exactly 0**.
  - Seen in LookDev: roughness 0 removes the lines drawn *on* that surface. Surfaces behind it can
    still draw a thin contact line at its silhouette. Roughness 0 also makes the surface glossy,
    so pair it with emission.
  - This needs the **Forward+** renderer (verified 2026-09-24; see `game-architecture.md` › Renderer).
- **Marker empties** (Blender empties, exported as `Node3D`). Scenes collect them by name or
  group instead of hard-coded coordinates. Add `_01`, `_02`… when there are several:
  - `seat_point` (group `patron_seat`)
  - `serve_point`, `work_point`, `perform_point`, `sit_point`, `interact_point`, `spawn_point`
  - `grave_text`
- **Collision via Godot import hints** (node-name suffixes) on low-poly proxy meshes:
  - `<name>-colonly`: static trimesh, invisible.
  - `<name>-convcolonly`: convex, invisible.
  - Don't put `-col` on the visible mesh; it doubles the geometry cost.
  - Walkable interiors keep their baked NavigationRegion3D, so don't use `-navmesh`.
- **Triangle budgets** (calibrated 2026-09-24 against KayKit, counted from the files):

  | Tier | Budget | KayKit reference (measured) |
  |---|---|---|
  | Small hand prop | ≤ 300 | `barrel_small.obj` 207 · `props/barrel.gltf` 240 |
  | Furniture | ≤ 1,000 | `table_small.obj` 192 · `stool.obj` 172 |
  | Hex topper / landmark | ≤ 3,000 | `building_tavern_blue` 2,992 (only a capital earns more: castle 5,659) |
  | Hero interior piece (pillar, hearth, bar) | ≤ 5,000 | — |
  | Walkable exterior building | ≤ 8,000 | — |
  | Character (route RL, measured 2026-10-04) | ≤ 10,000 per body (`RL_TRI_BUDGET`: the whole GLB, props included; 14,000 only with re-measured hall and town budgets), ≤ 3 surfaces on `<Role>_Body`, ≤ 2 textures at ≤ 1024²; the 15 RL bodies measured 6,522–9,530 (character spec, Budgets) | `Knight.glb` 6,952 in total (≈ 4.6k body + ≈ 2.3k gear across 15 meshes) |
  | Character (route AN, the fallback anime dealer) | ≤ 10,000 (`AN_TRI_BUDGET`), ≤ 3 surfaces; she measured 9,459 with her quill | — |

- **Export folders:**
  - Props, buildings, landmarks: `res://assets/environment/custom/<asset_id>.gltf` (glTF Separate, §6.4).
  - Characters: `res://assets/characters/custom/<asset_id>.glb` (glTF Binary, armature + animations).
  - Never write into KayKit folders. Never overwrite a file.
- **Data hookup:** content is referenced by path from JSON (MOD-3) with a fallback (MOD-6). The
  failsafe suite (Test 5) checks that every referenced path exists. Known gaps live in
  `test/asset_path_allowlist.json`.
- **Quick check:** `scenes/dev/LookDev.tscn` (tavern or map preset) before the in-scene Stage D
  pass (§6.5).

### Character spec (route RL) — rewritten by Story 25.31

This is the contract every realistic body meets, whoever builds it: Claude through the Blender MCP
for the demo, or a paid 3D artist after the Kickstarter (A-6). The scripts in
`tools/blender/realistic/` (their `README.md` lists the chain and every character's steps) are how
the demo cast was built; they run route AN's generic chain (`tools/blender/anime/`) from their own
chain configs. An artist may model and paint by hand instead, as long as the body starts from its
base and passes every rule and check below. Every number here was measured in Story 25.31
(2026-10-04) on the 15 RL bodies. Where this spec says nothing, the AN appendix below applies
(weights, normals, export, the import keys): the two routes share the pipeline code and the runtime.

**Where things live:**

| What | Where |
|---|---|
| The pipeline scripts (versioned) | `<project>/tools/blender/realistic/` (+ route AN's generic modules in `tools/blender/anime/`) and their `README.md`s |
| The KayKit source (never modified) | `<art>/blender/g19_g24_townsfolk_kit.blend`: the KayKit rig and its 76 clips |
| The bases | `<art>/blender/realistic_base.blend` (REAL-1) and `realistic_base_w.blend` (REAL-2), each with its `_kaykit_feet/_sit/_rest.json`, `_foot_report.json` and `_arm_src.json` |
| A character's file | `<art>/blender/<id>.blend`, a save-as of its base (`open_base_as`; e.g. `g12_bartender_real.blend`) |
| Its textures | `<art>/textures/realistic/<id>_head.png` (the projection), `<id>_headpaint.png` (the baked head, shipped), `<id>_body.png` (the body atlas) |
| Its concept pick | `<art>/picked/C_<job id>.png` (e.g. `C_G12_bartender.png`) |
| The game file | `res://assets/characters/custom/<id>.glb` (the RL bodies end in `_real`) |
| The look at runtime | `res://scripts/game/anime_look.gd` (it serves both routes), `res://assets/characters/materials/anime_outline.tres`, `anime_toon.gdshader` (the shader presets) |

#### The bodies (the demo cast, 2026-10-04)

| Catalogue | Character | Base | GLB (`custom/`) | Tris (props) | Surfaces | Clips | Top (m) | Fallback body |
|---|---|---|---|---|---|---|---|---|
| G1 | the player | REAL-1 | `g1_player_real.glb` | 9,180 (sword 184) | 2 | 76 | 1.86 | KayKit `Rogue.glb` |
| G12 | the Bartender | REAL-1 | `g12_bartender_real.glb` | 9,082 (cloths 120 + 272) | 2 | 81 | 1.86 | `g12_bartender.glb` (25.13) |
| G13 | the Quest Dealer | REAL-2 | `g13_quest_dealer_real.glb` | 9,156 (quill 32) | 2 | 79 | 1.72 | `g13_quest_dealer_anime_v2.glb` (route AN, the face-seam fix) |
| G2 | Fighter | REAL-1 | `g2_fighter_real.glb` | 7,672 (sword, shield) | 2 | 76 | 1.84 | KayKit `Knight.glb` |
| G3 | Rogue | REAL-2 | `g3_rogue_real.glb` | 7,600 (worn daggers) | 2 | 76 | 1.72 | KayKit `Rogue.glb` |
| G4 | Mage | REAL-1 | `g4_mage_real.glb` | 8,298 (staff) | 2 | 76 | 1.93 | KayKit `Mage.glb` |
| G5 | Healer | REAL-2 | `g5_healer_real.glb` | 9,056 (crystal staff) | 2 | 76 | 1.80 | `healer.glb` (25.9) |
| G6 | Barbarian | REAL-1 | `g6_barbarian_real.glb` | 8,792 (axe) | 2 | 76 | 1.85 | KayKit `Barbarian.glb` |
| G7 | Ranger | REAL-2 | `g7_ranger_real.glb` | 8,084 (bow, worn quiver) | 2 | 76 | 1.72 | `ranger.glb` (25.9) |
| G19 | farmer | REAL-1 | `g19_farmer_real.glb` | 6,622 | 2 | 76 | 1.93 | `townsfolk_farmer.glb` (25.14) |
| G19 | local | REAL-1 | `g19_local_real.glb` | 6,522 | 2 | 76 | 1.90 | `townsfolk_local.glb` |
| G19 | traveller | REAL-1 | `g19_traveller_real.glb` | 8,000 | 2 | 76 | 1.85 | `townsfolk_traveller.glb` |
| G19 | guard | REAL-1 | `g19_guard_real.glb` | 7,120 | 2 | 76 | 1.94 | `townsfolk_guard.glb` |
| G19 | merchant | REAL-1 | `g19_merchant_real.glb` | 9,530 (worn purse 148) | 2 | 76 | 1.93 | `townsfolk_merchant.glb` |
| G24 | old woman | REAL-2 | `g19_old_woman_real.glb` | 7,568 (cane 68) | 2 | 76 | 1.73 | `townsfolk_old_woman.glb` |

Den Fa (G9) and the Cat (G11) are Story 25.32's, on their own rigs. The KayKit Knight stays in LookDev as the
scale reference.

**Custom rigs on route RL (Story 25.32).** A character whose canon is outside KayKit's 41-joint contract keeps
its own rig: Den Fa (2.91 m, bat ears, the mask, Point) and the Cat (a quadruped). Route RL's generic geometry,
UV and paint helpers build the body (`real_body.loft` / `tube` / `grid_slab` / `param_uvs`, `real_paint`'s
painters over `real_layout.REG`); the weights are the character's own (its bone names), the checks are its own
(code in `tools/blender/realistic/<name>/`, each proved on a bad pose), the budgets are RL's (≤ 10,000 tris,
≤ 3 surfaces, ≤ 2 textures at ≤ 1024²; the Cat's are smaller). The runtime look is the cast's (`look:
"realistic"` on the scene, `anime_look.apply`); a material that must keep its imported shading is named in
`anime_look.gd` › `KEEP_AS_IMPORTED` (Den Fa's mirror mask only). The old body stays on disk; the scene's
re-point is the rollback.

| Id | Who | Rig | GLB | Tris | Surfaces | Clips | Top (m) | Old body |
|---|---|---|---|---|---|---|---|---|
| G9 | Den Fa (no wings, R-8) | his own, 30 `d_` bones | `g9_den_fa_real_v6.glb` | 6,076 | 2 (atlas + `den_fa_mask`) | 6 | 2.91 | `g9_den_fa.glb` |
| G11 | the Cat | her own (planned) | `g11_the_cat_real.glb` (planned: her concept pick first) | ≤ 3,000 | ≤ 2 | 4 | 0.40–0.50 sitting | `g11_the_cat.glb` |

#### Proportions: the two bases

- **REAL-1 (men): 1.86 m, about 7.35 heads,** from the spike's concept sheet. **REAL-2 (women):
  1.70 m,** REAL-1's heights scaled about KayKit's ankle (0.9067), shoulders 0.170 off the midline,
  hips 0.095, hands × 0.92. Both keep KayKit's bone directions and rolls; only heads and lengths
  change (`real_chain.REAL_1` / `REAL_2` tables; armature space, metres):

  | Bone | REAL-1 head (x, y, z), length | REAL-2 head (x, y, z), length |
  |---|---|---|
  | `hips` | (0, 0, 0.900), 0.170 | (0, 0, 0.8296), 0.1541 |
  | `spine` | (0, 0, 1.070), 0.250 | (0, 0, 0.9837), 0.2267 |
  | `chest` | (0, −0.010, 1.320), 0.240 | (0, −0.0091, 1.2104), 0.2176 |
  | `head` | (0, −0.050, 1.580), 0.240 | (0, −0.0453, 1.4461), 0.2176 |
  | `upperarm.l` | (0.195, 0, 1.480), 0.300 | (0.170, 0, 1.3555), 0.2720 |
  | `lowerarm.l` | the upper arm's tail, 0.270 | (0.4416, 0.0156, 1.3555), 0.2448 |
  | `wrist.l`, `hand.l` | 0.074, 0.112 (KayKit's) | 0.0679, 0.1030 |
  | `handslot.l` | the palm: 0.080 along the forearm from the wrist, 0.026 palm-side | (0.7595, −0.0014, 1.3315) |
  | `upperleg.l` | (0.100, 0, 0.950), 0.440 | (0.095, 0, 0.8749), 0.3992 |
  | `lowerleg.l` | the knee, 0.510 down to KayKit's ankle (0.145) | (0.095, −0.0139, 0.4759), 0.3360 |
  | `foot.l`, `toes.l` | KayKit's | KayKit's |

- **Leg ratios:** REAL-1 **2.1537**, REAL-2 **1.9527** (thigh + shin over KayKit's 0.3765).
- **`Base_Body`** on each base is a neutral, clothing-less mannequin (`real_body.build_neutral`,
  `real_chain.MAN` / `WOMAN`): REAL-1 an average man (flat stomach), REAL-2 a woman (waist, hips, a
  round bust, slimmer limbs, a smaller head, hands and boots). It is never exported; the sit re-fit,
  the foot report and the arm pass are measured on it. Girth and a belly are a character's own params
  (the Bartender's belly, the Barbarian's `burly_ring`), never a base's.
- **Tops 1.50–2.25 m with headwear** (Test 19's `RL_TOP`; the lintel 2.30 − 0.05). REAL-1's 1.86
  leaves ~0.39 m for headwear (the Mage's floppy hat tops out at 1.93).
- **Seated room at the guild desk:** the realistic dealer's seated shoulders are 1.034 m above the
  root, under 25.30's desk top + 0.20 (1.05); her `hip_back` is 0.45 (her arms reach the ledger
  from there). Raise the desk stool or lower the desk is Raphael's call (Story 25.31 S1); Test 19
  holds the measured 1.03 (`RL_SEATED_SHOULDER_MIN_W`) until then.

#### The rig and clip contract

- **The 41 joints, all kept, with KayKit's names** (Godot shows 42: it adds a root), as in the AN
  appendix.
- **The retarget** (once per base): the hips and root location keys × the base's leg ratio in all
  76 clips, each action stamped; never run twice, never scale a character file's clips in place.
- **The sit re-fit** (`anime_retarget.refit_sit(..., seat_y=0.45)`), iterated (seat solve → foot IK →
  re-measure) until the error is < 0.002: the hips 0.397 behind the root, the feet planted, the
  seated hips at **`SIT_HIPS_Y` 0.5124 (REAL-1)** and **0.5164 (REAL-2**, Test 19
  `RL_SIT_HIPS_Y_W`). Every chair and table spot is 0.45; the **bar stools** are 0.72 with a foot
  ring and footrest at 0.27 = seat − 0.45 (R-5, `b2_bar_stool_tall.gltf`): `RealisticPatron` lifts
  the sitter by `SIT_LIFT` 0.27 there (eased in with Sit_Chair_Down), so the planted feet land on the
  footrest. A body whose seat thickness differs from its base's by more than 0.03 m runs
  `refit_sit("<Role>_Body")` in its own file; none of the 15 did (every seat within 0.02 of its base's).
- **The arm pass** (`real_arms.py`, once per base, on Idle, Walking_A, Running_A, the three
  Sit_Chair clips, Cheer and Interact): KayKit holds the arms 35–60° out from a chibi body; each key's
  upper arm turns toward the body, 0.03 m clear of `Base_Body`, ≤ 45°. A character wider than its
  base turns its arms out again with `real_player.arms_out` (≤ 6°; the Barbarian 10°).
- **The foot report** (73 clips, every contact frame within 0.03 m of the floor) is stamped on each
  base; squats lock the feet (`squat_planted`).
- **Clips per role** (N9: one armature per `.blend`, the file holds exactly these actions):

  | Role | Clips in the GLB | Its own clips | Loops | Playback rate |
  |---|---|---|---|---|
  | G12 the Bartender (`bartender`) | **81** | Walk_Bar, Wipe, Pour, Serve, Restock (re-posed on his reach; Walk_Bar elbows tucked) | Idle, Walking_A, Walk_Bar, Sit_Chair_Idle, Wipe, Restock | body block speeds (`hall_speed` 1.03, `bar_speed` 0.86) |
  | G13 the Quest Dealer (`desk_manager`) | **79** | Walk_Bar, Write, Brief | Idle, Walking_A, Walk_Bar, Sit_Chair_Idle, Write, Brief | body block (`hall_speed` 1.17, `bar_speed` 0.80) |
  | G1 the player | **76** | none (Idle re-posed, Running_A kept: his run plays at 5.0 / 6.996 = **0.715**) | Idle, Running_A | `player.json` `run_ground_speed` |
  | Patrons, townsfolk, class bodies | **76** | none (Idle re-posed by the clothes, Walking_A at its own stride, Running_A re-posed as a **jog**) | Idle, Walking_A, Running_A, Sit_Chair_Idle (one-shots: Sit_Chair_Down, Sit_Chair_StandUp, Cheer, Interact) | V9: the gameplay speed ÷ the measured ground speed (`walk_ground_speed` 1.03–1.21, `run_ground_speed` 2.00–2.80 m/s) |

  The gameplay speeds never change for a body (player 5.0, patrons `SPEED` 2.5, villagers
  `walk_speed` 1.2); only the clip's playback rate does, so nothing skates.
- **Hand slots and props** (R-9 refined): a carried item is its own mesh parented to its slot bone
  (BONE parent, built with the rig in rest, aimed from Idle's first frame), named with the role's
  prefix (`Fighter_Sword`, `OldWoman_Cane`). Godot imports it as BoneAttachment3D `<Prop>` on an item
  bone `<Prop>` under the slot, holding MeshInstance3D `<Prop>`: look the mesh up by class.
  `RealisticPatron.dress_body` hides every prop on `handslot.l/.r` (or their item bones); worn props
  (the player's sword and the Rogue's daggers on `hips`, the merchant's purse on `hips`, the Ranger's
  quiver on `chest`) stay visible. The Bartender's cloths and the dealer's quill show only during
  their actions.

#### The body and its textures

- **One joined, skinned `<Role>_Body`** with exactly one Armature modifier, ≤ 3 surfaces (every RL
  body has 2: the head and the body atlas), weights ≤ 4 influences, unsplit smooth normals, scale 1,
  one `UVMap`: the AN appendix's rules ("The body") hold unchanged; `anime_merge.check` prints them.
- **The head texture is projected from the pick:** `real_layout` measures the concept sheet (per
  view the centre column and the crown / eye and sole rows; `sheet_by_eyes` when a hat hides the
  crown); `real_body.projection_uvs` gives each head face the view its normal faces most;
  `real_paint.head_texture` cuts the crops; `real_bake.bake_head` blends the three views by the
  normal and bakes them seamless (Cycles EMIT) into the head's own unwrap: `<id>_headpaint.png`, the
  shipped head. A bake writes into every material's active image node: give the other slots a
  throwaway node during it.
- **The body atlas** (`real_paint.body_texture`): the clothes, skin and hair painted per region
  (`real_layout.REG`), with worn, patched detail and no baked lighting; the palette muted and earthy
  (R-7); distinctness: no green except the Ranger and the Rogue's small scarf, no cream except the
  Healer, nothing near Den Fa's #26587e.
- **Textures: ≤ 2 per body at ≤ 1024²** (Test 19's `RL_TEXTURES`, `RL_TEX_SIZE`), RGB, imported
  Lossless with mipmaps and Detect 3D off (the game filters at half resolution, so painted grime
  shimmers without mips). Each RL body ships two 1024² PNGs.
- **Hair** as opaque shells (projected or painted) and falls, never cards; the arms must clear it.
- **Long robes and skirts** (the Mage, the Healer, the old woman, the aprons and coats): the front
  follows the thighs and, below the knee, the shins (`robe_w`), so check (b) (no thigh poking out,
  `anime_clearcheck`) reads 0 pokes in Running_A and every sit clip; a seated back hem may hang
  behind the chair (cloth, not the seat).

#### Materials, glow and ink

- **In Blender:** Principled BSDF, Alpha unlinked at 1.0, backface culling off, Metallic 0,
  roughness above 0, no emission on any body material or any material the body shares (as the AN
  appendix).
- **Props may glow (AH-3, V5):** a prop's OWN material may emit, at roughness exactly 0 (the
  Healer's crystal: `RT_Healer_Crystal`, base (0.05, 0.30, 0.10), emission (0.20, 1.0, 0.35) × 1.6).
  `anime_merge.check` (`emission_ok`) fails emission on a body material, on one the body shares, and
  an emissive material above roughness 0. At load `anime_look.gd` gives an emissive source a glow
  copy in every preset: it keeps its emission, roughness 0 and **no outline** (light, not ink).
- **The look at load** (`anime_look.apply`, called by `staff_npc.gd`, `player.gd`,
  `RealisticPatron.dress_body` and `villager.gd` when the entry's `look` is `"realistic"` or
  `"anime"`, on the entry's own body only, never on a fallback): every opaque surface gets a toon
  copy (TOON diffuse, specular off, metallic 0) with the shared ink hull as its `next_pass`; one copy
  per imported material, shared by every instance.
- **The preset and the ink width** live in `data/config/game_config.json` ›
  `anime_look_preset` / `anime_look_presets` (`approved`: `TOON_BAND` 0.12 and `anime_outline.tres`,
  grow 0.011 m, ink (0.17, 0.09, 0.12); `darker_a`: grow 0.013; `darker_b`: grow 0.015). Today's
  setting is `approved`. Raphael picks the cast's preset and its thicker ink (R-1) on Story 25.23's
  D2 sheet in the picked mood; the pick only changes the config. The tests follow the active preset:
  Test 23 reads the pick from the config, and Test 19's look check (`_staff_look_wrong`) takes the
  preset's toon (a shader preset's ShaderMaterial with its own outline copy) and V5's prop glow in
  every preset; Test 19 runs it once under a darker preset, switched in the test (25.31 review P4).
- **The dark side** is albedo × the hall's ambient (the mood's, Story 25.23). The characters get no
  light of their own (A-5).

#### Budgets

- **Per body (AH-15):** **≤ 10,000 tris** with props (`RL_TRI_BUDGET`; up to 14,000 only once the
  hall and town budgets below are re-measured with it and still pass), **≤ 3 surfaces** on
  `<Role>_Body` (≤ 6 render elements with the hull; a shown prop adds its surfaces × 2), **≤ 2
  textures at ≤ 1024²**, mipmaps on. The 15 bodies: 6,522–9,530 tris, 2 surfaces, 2 textures each.
- **Texture memory, the whole cast (measured 2026-10-04):** 30 unique textures (two per body), each
  1024² RGB8 with mipmaps as uploaded = 4,194,303 bytes, **120 MiB** for the 15 bodies (read back
  from the GPU in MainTavern); the hall's whole texture memory read 526 MiB at 24 bodies. Lossless
  keeps the painted faces clean; VRAM compression (S3TC / BPTC, a third or less of that) is judged
  by eye if memory ever matters.
- **The hall (re-measured 2026-10-04 with the full realistic cast; Story 25.31 T-end):** the crowd
  check (§6.5) in MainTavern, clones of all 15 RL GLBs (raw instances through `anime_look.apply`,
  their props shown, looping Idle / Walking_A from staggered starts, 6 within the hearth light's
  6 m), on top of the hall's own 6 (the Bartender, the Quest Dealer, the player, Den Fa, the Cat and
  one spawned realistic patron); RTX 3080, V-Sync off, 2,900 frames per sample, render times summed
  over the SubViewport and the root viewport:

  | Bodies | Mood (run) | VISIBLE | SHADOW | GPU (ms) | CPU (ms) | fps |
  |---|---|---|---|---|---|---|
  | 6 (the hall's own) | today (1) | 99 | 0 | 0.290 | 0.243 | 1010 |
  | 22 | today (1) | 187 | 0 | 0.341 | 0.308 | 807 |
  | 24 | today (1) | 196 | 0 | 0.348 | 0.317 | 807 |
  | 6 | moody_a (1: the patron seated in the hearth's range) | 101 | 73 | 0.421 | 0.319 | 1007 |
  | 22 | moody_a (1) | 189 | 101 | 0.481 | 0.401 | 673 |
  | 24 | moody_a (1) | 197 | 101 | 0.486 | 0.402 | 673 |
  | 24 | moody_a (1), the hearth's shadow off | 197 | 0 | 0.367 | 0.322 | 806 |
  | 24 | moody_b (1) | 197 | 101 | 0.490 | 0.404 | 673 |
  | 6 | moody_a (2: three re-spawns, the patron 8.9–15.1 m away) | 100–101 | 65 | 0.423–0.427 | 0.313–0.317 | 1004–1008 |
  | 24 | moody_a (2, the same three) | 197 | 93 | 0.489–0.493 | 0.401–0.407 | 672–674 |

  - **VISIBLE ≤ 200 at 24 bodies: passes (196–197).** A realistic body is 2 surfaces + 2 hulls (4
    VISIBLE); with props shown, the clones here are the worst case. The margin is small: a hall that
    adds draws (a new prop, a third body surface, a KayKit fallback body with 7–15 surfaces) must be
    re-measured.
  - **SHADOW (Story 25.23's budget: 100 at 24 bodies, the hearth's dual paraboloid): 93 on the
    protocol (6 clones in the hearth's range); 101 when the spawned patron also sat in it.** Each body
    inside the hearth light's 6 m range adds 8 (4 elements × 2 views). Run 1's 101 is one over the
    line, at 0.49 ms; the line is a draw-count guard (25.23's 97 rounded up), the pass is the time.
  - **It passes the time line:** at 24 bodies the larger of the GPU and CPU times is 0.49 ms against
    **8.3 ms**. No mitigation was needed.
  - 25.23's S1-cast numbers (VISIBLE 179, SHADOW 97) were taken with the KayKit patrons and three RL
    bodies; the full RL cast raises VISIBLE (more clones carry visible props) and lowers SHADOW.
- **The town (measured 2026-10-04, Story 25.31 T-end; the first town budget):** ExteriorWorld (the
  root viewport, the camera at size 25), the sun shadowed in its default 4-split PSSM (max distance
  100 m), the six realistic villagers, the player (parked in the square), the Cat, then clones of the
  RL bodies (all 15 kinds, props shown) standing and walking in the square in view, as a crowd of
  patrons would; 21 of the 22 people on screen at 24 bodies; RTX 3080, V-Sync off, 2,900 frames per
  sample:

  | Bodies | Sun shadow | VISIBLE | SHADOW | GPU (ms) | CPU (ms) | fps |
  |---|---|---|---|---|---|---|
  | 8 (the town's own) | 4 splits | 91 | 274–278 | 0.676–0.689 | 0.293–0.296 | 808–811 |
  | 16 | 4 splits | 133 | 360 | 0.718 | 0.359 | 808 |
  | 24 | 4 splits | 185 | 494 | 0.779 | 0.449 | 674 |
  | 24 | 2 splits | 183 | 272 | 0.718 | 0.366 | 676 |
  | 24 | orthogonal | 184 | 212 | 0.698 | 0.337 | 807 |
  | 24 | off (its share) | 186 | 0 | 0.548 | 0.235 | 813 |

  - **Town budget: VISIBLE 200 and SHADOW 500 at 24 bodies** under the 4-split sun (185 and 494,
    rounded up to the next 50, the hall's rule). Each body in view adds about 6 VISIBLE and 13–14
    SHADOW (its elements in the splits that reach it).
  - **It passes:** 0.78 ms at 24 bodies against **8.3 ms** (the reference machine: RTX 3080). The
    sun's 4 splits cost 0.23 ms of GPU at 24 bodies; 2 splits halve the SHADOW draws if the town ever
    needs headroom.
  - Full numbers: Story 25.31's Debug Log (T-end).
- **Measure again** when a body exceeds 10,000 tris, a body gains a surface, a hall or town light
  starts casting, or the cast's count rises past 24 in one view.

#### Export and import

- As the AN appendix's "Export", with the RL file names: the `.blend` at `<art>/blender/<id>.blend`,
  the GLB at `res://assets/characters/custom/<id>.glb` (`<id>` ending `_real`), a NEW name for every
  rebuild (N5); the extracted images `<id>_<id>_body.png` and `<id>_<id>_headpaint.png`, each
  `.png.import` Lossless, mipmaps on, Detect 3D off; the `.glb.import` LODs off and `_subresources`
  looping exactly the role's loops (the table above). Re-export after every clip change; reimport
  headless (`--import`, exit 139 is harmless).

#### Data: bodies swap by data path (final, Story 25.31)

Every body the game shows comes from data, with a fallback that exists (MOD-3, MOD-6). `look`:
`"realistic"` (or `"anime"`, the same code path) tones the entry's own body; a fallback body is
never toned. Before removing a fallback file, repoint the field in the same commit.

| File | Entry | Fields | Read by |
|---|---|---|---|
| `data/characters/player.json` | the player (one man, AH-1) | `model_path`, `fallback_model_path`, `look`, `run_ground_speed` | `player.gd` at `_ready` (FileAccess; then `LAST_RESORT_BODY`, the KayKit Rogue) |
| `data/characters/staff.json` | `roles.<role>.variants.<variant>` | `model_path`, `fallback_model_path`, `look`, `body` {…} | `staff_npc.gd` (`_load_model`, `_body()`; then `LAST_RESORT_BODY`) |
| `data/characters/townsfolk.json` | `variants[]` (6 townsfolk + 6 adventurers) | `id`, `display_name`, `role`, `model_path`, `fallback_model_path`, `look`, `origin_type`, `weight`, `names`, `walk_ground_speed`, `run_ground_speed`, `head_top`, `sit_head_top`, `tankard_scale` | `RealisticPatron` (patrons: `_swap_to_model(path, variant)`, `dress_body`, `clip_rate`; `FALLBACK_MODELS` when the file is missing) and `villager.gd` (by `variant_id`) |
| `data/characters/classes.json` | `<Class>` | `model_path`, `fallback_model_path`, `look` | DataManager (no 3D consumer yet; the adventurer patrons use the same files) |

- **Body blocks** (staff only; every key a number > 0, `seated_front` may be ≤ 0; measured on the
  skinned body):
  - the Bartender: `hall_speed` 1.03, `bar_speed` 0.86, `serve_r` 1.92, `restock_r` 1.98, `ring_r`
    1.80, `keg_r` 1.90, `gap_r` 1.98, `walk_bar_half_low` 0.318, `walk_bar_half_shelf` 0.318,
    `walk_bar_half_mid` 0.341, `tankard_scale` 1.1 (`real_bar.py`);
  - the Quest Dealer: `hip_back` 0.45, `stool_pull` 0.47, `seated_front` −0.23,
    `walk_half_at_desk` 0.295, `idle_front` 0.127, `bubble_seated` 1.51, `hall_speed` 1.17,
    `bar_speed` 0.80 (`anime_clearcheck` with her config). The keys' meanings: the AN appendix's table.
- **Patrons and villagers** get no body block: `RealisticPatron`'s seat constants (`SIT_HIP_BACK`
  0.397, `SIT_CLIP_SEAT` 0.45, `BAR_STOOL_SEAT` 0.72, `SIT_LIFT` 0.27) hold for every RL body; the
  entry's speeds set the clip rates (V9), its head tops place the bubbles (+ 0.30 / 0.38 seated,
  + 0.45 for villagers), `tankard_scale` 1.1 sizes the held tankard (KayKit bodies 1.8), and
  `PatronSpawner.SEAT_ELBOW_ROOM` is 1.17: the widest seated half-width over the whole pool (townsfolk
  and classes; Sit_Chair_Idle, every frame, the shown props included) is the Mage's 0.449 (the
  townsfolk's 0.436), so two of the widest neighbours keep 0.27 m (townsfolk 0.30) and the round
  bar's adjacent stools (1.23 m) stay usable (re-measured in the 25.31 code review, P3).
- **Old saves (AH-7):** a patron saves its entry's `model_path`; a saved path that is not in the pool
  any more (a KayKit body) re-picks a body by `origin_type`.
- The adventurer pool: six entries on the class files (`adventurer_fighter` … `adventurer_ranger`);
  the hooded Rogue retired (AH-6); townsfolk weight share 0.846 (Test 16: ≤ 0.85).

#### Validation

- **In Blender:** `anime_merge.check` every row OK (with `emission_ok`); the top within 1.50–2.25;
  the base's foot report and arm pass stamped (`open_base_as` refuses otherwise); for a role at
  furniture, its clearance report (`real_bar.report` for the Bartender, `anime_clearcheck` for the
  dealer's desk); check (b) for skirts, robes and aprons (0 pokes in Running_A and the sits); every
  check shown to report a hit on a deliberately bad pose before its zero is trusted.
- **In Godot (the failsafe suite, 905 checks on 2026-10-04):** Test 19's GLB checker on the RL rules
  (`RL_*`: ≥ 41 bones, 76 + the role's own clips, loops and one-shots, the `<Role>_` meshes and
  listed props, ≤ 3 surfaces, ≤ 2 textures at ≤ 1024² with the import keys, no LODs, ≤ 10,000 tris,
  glow only on the listed props and at roughness 0, roughness > 0 elsewhere, no metal, top
  1.50–2.25) for the Bartender and the dealer (and their fallbacks on their own rules); Test 24 (the
  player: data, fallbacks, the run rate); Test 16 (the six townsfolk: GLBs, speeds, hands, names, as
  patrons and villagers, the fallback case, AH-7); Test 15 (the six classes: classes.json, GLBs,
  props on their slots, the glow, as patrons); Test 12 (the stools, the tankard); Test 22 (the
  portraits' resolves).
- **Stage D:** §6.5's character variant (six criteria and the crowd check), per slice; the RL sheets:
  `<art>/shots/staff/real/25-31_s1_sheet.png`, `_s2_sheet.png`, `_s3_sheet.png`.

### Appendix: the character spec (route AN) — the anime Quest Dealer's fallback (Story 25.30)

Kept as written by Story 25.30, with pointers where route RL took over (2026-10-04). It still
governs `g13_quest_dealer_anime.glb` and its v2 re-export (the realistic dealer's fallback body),
and its body, export and validation rules are the ones the RL spec above refers to.

This is the contract every anime body meets, whoever builds it: Claude through the Blender MCP for
the demo, or a paid 3D artist after the Kickstarter (A-6). The scripts in `tools/blender/anime/`
(their `README.md` lists the chain) are how the demo cast is built. An artist may model and paint
by hand instead, as long as the body starts from the shared base and passes every rule and check
below. Every number here was measured in Story 25.30 on the first AN body, G13 the Quest Dealer.

**Where things live:**

| What | Where |
|---|---|
| The pipeline scripts (versioned) | `<project>/tools/blender/anime/` and its `README.md` |
| The KayKit source (never modified) | `<art>/blender/g19_g24_townsfolk_kit.blend`: the KayKit rig and its 76 clips |
| The shared base | `<art>/blender/anime_base.blend`, with `anime_base_kaykit_feet.json`, `anime_base_kaykit_sit.json` and `anime_base_foot_report.json` beside it |
| A character's file | `<art>/blender/<id>.blend`, a save-as of the base (the dealer: `g13_quest_dealer_anime.blend`) |
| Its palette and face | `<art>/textures/anime/` (the dealer: `g13_quest_dealer_palette.png`, `g13_quest_dealer_face.png`) |
| The game file | `res://assets/characters/custom/<id>.glb` (the dealer: `g13_quest_dealer_anime.glb`) |
| The look at runtime | `res://scripts/game/anime_look.gd` and `res://assets/characters/materials/anime_outline.tres` |
| The approved look | `<art>/anime_test/anime_test_report.jpg` (its `<art>/blender/anime_test_dealer.blend` is never modified) |

Frames: Blender armature space is front −Y, left +X, up +Z. Godot (x, y, z) = Blender (x, z, −y).

#### Proportions: the base

- **About 3.5 heads, slim.** The top is ≤ 2.25 m (the front door's lintel, 2.30, minus 0.05; Test 19
  checks it); aim for about 2.10–2.20. The head is about 0.58–0.61 m, chin to crown. The Quest
  Dealer stands 2.138 m (the KayKit Knight 2.315, the 25.13 KayKit dealer 2.187).
- **The rest pose is KayKit's, stretched.** Every bone keeps KayKit's direction and roll; only heads
  and lengths change (`anime_rig.py`). The table is candidate B of Raphael's T0 sheet (2026-09-27):
  the approved test's rig with 0.08 m shorter legs and a 0.10 m longer torso, so a seated character
  has room above the guild desk. Armature space, metres; each `.r` bone mirrors its `.l` in x.

  | Bone | Head (x, y, z) | Length |
  |---|---|---|
  | `hips` | (0, 0, 0.742) | 0.198 |
  | `spine` | (0, 0, 0.940) | 0.280 |
  | `chest` | (0, 0, 1.220) | 0.250 |
  | `head` | (0, 0, 1.487) | 0.251 |
  | `upperarm.l` | (0.16, 0, 1.38) | 0.30 |
  | `lowerarm.l` | the upper arm's tail | 0.28 |
  | `wrist.l`, `hand.l` | their parent's tail | KayKit's |
  | `handslot.l` | the palm's centre: `hand.l`'s head + 0.01 along the hand, − 0.004 in z | KayKit's |
  | `upperleg.l` | (0.105, 0, 0.843) | 0.377 (the knee at z 0.466) |
  | `lowerleg.l` | the knee | 0.326 (down to KayKit's own ankle height, 0.1452) |
  | `foot.l`, `toes.l` | their parent's tail | KayKit's |

- **The leg ratio is 1.8675:** the anime thigh + shin, 0.7031 m, over KayKit's 0.3765 (0.2271 +
  0.1494). KayKit's lengths are stored on the rig as `rig["kaykit_thigh"]` and `rig["kaykit_shin"]`
  before any edit, and read from there, never typed in.
- **Arm adduction: 0°.** The one allowed exception to "directions kept" is an optional rigid
  rotation of the whole arm chain about the `upperarm` head, toward the body, of up to 15°
  (`anime_rig.ADDUCT_DEG`, applied as an absolute angle to KayKit's rest directions, never on top of
  an earlier run). The base uses none: KayKit's Idle holds the arms about 35° off the body, as in
  the approved test, and the T2 renders kept that.
- **`Base_Body`** is the neutral, unclothed reference body on the stretched rig
  (`anime_kit.build_base_body`): 4,872 tris, rest top 2.110. The foot report, the sit re-fit and the
  seated-room report are measured on it. It is **never exported**: a character file deletes it by
  name in its build step (`anime_dealer.build()` → `_drop_base_body`), the call after its save-as. **Its seat thickness is 0.0112 m** (the hips bone's height minus the
  lowest seat vertex, seated); the dealer's is 0.0098.
- **Seated room:** in Sit_Chair_Idle, both `upperarm` heads are ≥ 1.05 m above the root
  (`AN_SEATED_SHOULDER_MIN`: the desk top, 0.85, + 0.20), so a seated character reads above the
  desk. `anime_retarget.seated_room()` prints it. The base: 1.085 / 1.091. The dealer: Write
  1.059–1.069, Brief 1.081–1.091.

#### The rig and clip contract

- **The 41 joints, all kept, with KayKit's names** (Godot's import shows 42 bones: it adds a root):
  - the trunk: `root`, `hips`, `spine`, `chest`, `head`
  - each arm (`.l`, `.r`): `upperarm`, `lowerarm`, `wrist`, `hand`, `handslot`
  - each leg (`.l`, `.r`): `upperleg`, `lowerleg`, `foot`, `toes`
  - the inert IK and control bones, each side (nothing drives them, but they stay): `kneeIK`,
    `elbowIK`, `handIK`, `heelIK`, `IK-foot`, `IK-toe`, `control-toe-roll`, `control-heel-roll`,
    `control-foot-roll`
- **Bone lengths come from the base.** A character file never edits its bones. To change a length,
  or the adduction:
  1. Edit `anime_rig.py`'s `TABLE` (or `ADDUCT_DEG`).
  2. Rebuild the base from the untouched kit with the whole chain: `anime_base_build.open_kit()`, then (in its own call) `anime_base_build.finish()` →
     `anime_rig.run()` → `anime_kit.build_base_body()` → `anime_retarget.ratio_step()` →
     `anime_retarget.refit_sit("Base_Body")` → `anime_retarget.foot_report()`. The ratio step refuses
     a file whose actions already carry the stamp, so it can't run twice on one base.
  3. Rebuild each character file from the new base (`anime_dealer.py` for G13) and re-run the role's
     own IK clips there (`anime_anims.py`).

  **Never scale a character file's clips in place.**
- **The retarget** (in the base, once per chain build): the location keys of `hips` and `root` are
  scaled by the leg ratio in all 76 clips (KayKit keys `root`'s translation in Running_A and the four
  Dodge clips), and each action is stamped `anime_leg_ratio`. Every other deform bone's location offsets
  stay unscaled (the largest: `handslot` 0.53 m in the Death clips, `upperarm` 0.16, `upperleg`
  0.155). Action names stay exactly KayKit's, with no `.00x` suffixes.
- **The sit re-fit,** `anime_retarget.refit_sit(body_name, seat_y=0.44)`, rewrites the three
  Sit_Chair_* clips absolutely (it never scales) from KayKit's recorded sit data
  (`anime_base_kaykit_sit.json`):
  - KayKit's own back offset, unscaled: the hips go 0 → 0.397 m back through Sit_Chair_Down, hold
    0.397 in Sit_Chair_Idle and come back through Sit_Chair_StandUp. RealisticPatron's
    `SIT_HIP_BACK` 0.40 stays valid.
  - The seated height is solved so the body's lowest seat vertex rests on the 0.44 m seat. It prints
    **`SIT_HIPS_Y` 0.450**: the seated hips height, Godot frame, model-local (Test 19's
    `AN_SIT_HIPS_Y`).
  - The feet are planted flat at their rest spot through all three clips (KayKit's own seated feet
    dangle 0.23 m above the floor).
  - Down's last frame and StandUp's first meet Sit_Chair_Idle's first within 0.01 m.

  It covers every seat in the game: the bar stools (`seat_point` 0.44 ± 0.05), the desk stool
  (`WorkPoint` y 0.44), and Den Fa's bench (0.45). It is repeatable and the stamp doesn't block it.
  **The rule:** a character whose seat thickness differs from `Base_Body`'s 0.0112 m by more than
  0.03 m runs `anime_retarget.refit_sit("<Role>_Body")` in its own file, and Test 19's
  `AN_SIT_HIPS_Y` takes the `SIT_HIPS_Y` it prints. (The dealer, at 0.0098, didn't need it.)
  **`Sit_Chair_Pose` is neither re-fitted nor checked** (the foot report finds no contact frame in it:
  KayKit's seated feet dangle), so it plays at the ×1.8675 hips height; it isn't a game clip, and any
  role that needs it must re-fit it first.
- **The handslots** (`handslot.l`, `handslot.r`) sit at the palms' centres and keep KayKit's axes:
  in Idle, Walking_A and Sit_Chair_Idle, `handslot.r`'s local −X and `handslot.l`'s local +X point
  up. (KayKit's own weapons use local Z and lie across the hips in those clips.) Build the hand
  round the slot. A hand prop is its own mesh parented to the slot bone (Blender parent type BONE);
  Godot imports it under a BoneAttachment3D. The dealer's quill rises up and back out of her fist
  (`anime_dealer.QUILL_DIR`, in the rest frame).
- **Clips: "the 76 KayKit clips + the role's own".** One armature per `.blend`, and the file holds
  exactly these actions: no leftovers and no KayKit copies, because the exporter would pick them up
  and break the clip count. Every body carries the clips the game plays (Test 19's `CAST_CLIPS`):
  Idle, Walking_A, Running_A, Sit_Chair_Down, Sit_Chair_Idle, Sit_Chair_StandUp, Cheer and Interact.

  | Role (catalogue) | Clips in the GLB | Its own clips | Loops |
  |---|---|---|---|
  | G13 Quest Dealer (`desk_manager`) | **79** | Walk_Bar, Write, Brief (re-posed for her proportions with the 25.13 IK method); never the Bartender's Wipe, Pour, Serve, Restock | Idle, Walking_A, Walk_Bar, Sit_Chair_Idle, Write, Brief |
  | G12 Bartender (`bartender`) | no AN body: Story 25.31 built him on route RL (81 clips: the RL spec's role table); his 25.13 KayKit fallback has 83 (it also carries Write and Brief) | Walk_Bar, Wipe, Pour, Serve, Restock | the RL spec |
  | Patrons, townsfolk, class bodies, the player | no AN bodies: route RL since 2026-10-04 (76 clips; the RL spec's role table) | none | the RL spec |

- **Loop rules.** In Blender, key each looping clip's last frame with its t = 0 pose. In Godot, the
  `.glb.import`'s `_subresources` sets `"settings/loop_mode": 1` for exactly the role's loops;
  every other clip plays once (the dealer's one-shots Sit_Chair_Down, Sit_Chair_StandUp and Interact
  are checked). At runtime `staff_npc.gd`'s AnimationTree sets the staff's loops again, but Test 19
  still checks the file's own.
- **The foot report** (`anime_retarget.foot_report()`, over the 73 clips other than
  Sit_Chair_Down/Idle/StandUp, whose feet `refit_sit` plants; saved to
  `<art>/blender/anime_base_foot_report.json`):
  - The rule: on every contact frame (KayKit's own lowest foot ≤ 0.01 m above the floor; airborne
    frames aren't checked), the reference body's lowest foot vertex is within 0.03 m of the floor.
  - A clip over the limit gets a hips-height contact correction with smoothed keys.
  - The base's result for the clips the game plays, before → after the correction: Idle 0.020 →
    0.020, Walking_A 0.089 → 0.011, Running_A 0.133 → 0.000, Cheer 0.021 → 0.021, Interact 0.015 →
    0.015. **No clip is over 0.03 after the correction,** so none is listed as a limitation.
  - **Outliers to judge by eye before first use:** the worst before the correction were Lie_* (0.38),
    Jump_* (0.22), Death_B (0.17) and Running_B (0.17). The Lie_*, Death_* and Jump_* clips were
    corrected by the feet-only rule, so look at them in a render before a story first uses one.

#### The body

- **One joined, skinned mesh object, `<Role>_Body`** (the dealer: `Dealer_Body`), parented to `Rig`,
  with exactly one modifier: an Armature pointing at `Rig`.
- **≤ 3 surfaces** (material slots), one per material family: the palette atlas, the face, and
  optionally the hair. The cap counts that node only. The dealer has 2: the face and the palette
  (her hair is on the palette).
- **Props on item bones:** separate mesh nodes named with the role's prefix (the dealer:
  `Dealer_Quill` on `handslot.r`), parent type BONE, no vertex groups, no modifiers, at least one
  material. They count toward the triangles, not the surface cap. Anything that never moves apart
  from the body (the ears, a circlet) is merged into it. Every mesh node in the file starts with
  the prefix (`Dealer_`).
- **Weights:** every vertex is in at least one deform bone's group, has at most **4** influences,
  normalised, and no weight on a non-deform bone.
- **Unsplit, smooth normals:** `mesh.normals_domain == 'POINT'`, no `sharp_edge` or `sharp_face`
  attribute holding True, no custom normals, every face smooth. The outline's `grow` moves each
  exported vertex along its own normal, and glTF splits a vertex wherever its corner normals differ,
  so any split (a hard edge, a flat face, custom normals, Edge Split) opens a crack in the ink.
- **Scale 1:** `Rig` and `<Role>_Body` at object scale 1.0 (the outline's `grow_amount` is in local
  metres), the rig's origin at 0,0,0 between the feet.
- **One UV layer, named `UVMap`,** on every part: the atlas cell UVs or the face projection.
- **Before the join,** apply every non-Armature modifier on each part (`join()` keeps only the
  active object's modifiers) and give each part its single `UVMap` (`join()` merges UV layers by
  name). Make a skinned part the active object.
- **The check:** `anime_merge.check(body, props)` prints STRUCTURE / UV / WEIGHTS / NORMALS /
  MATERIALS / TRIS / SURFACES (and one PROP row per prop) as OK or OVER. Every row must be OK. The
  dealer: 9,427 tris + the quill's 32 = 9,459, 2 surfaces, all OK.

#### The atlas

- **One palette atlas per body,** `<art>/textures/anime/<name>_palette.png` (the dealer's:
  `g13_quest_dealer_palette.png`, named without `_anime`), with cells ≥ 4 px on a
  4-px grid. The dealer's is **32 × 32 px: a 4 × 4 grid of 8-px cells** (`anime_atlas.CELL` 8,
  `GRID` 4), 10 of them used.
- **Flat-colour parts collapse every UV onto one cell's centre** (the KayKit cell method), so each
  part samples exactly one colour, with no mip blur. The image texture's interpolation is Closest.
- **Recolours are atlas edits:** a variant is the same mesh with a different PNG (25.31).
- **No baked lighting** in the atlas or the face: no AO, no painted shading. Godot adds the toon
  tones and the ink.
- **Not the KayKit atlas:** characters never use `hexagons_medieval.png` (§6.3).

#### The face

- **1024 × 1024 px, RGB with no alpha channel.** Paint in RGBA if you like, then save it as RGB
  (`img.convert("RGB")`).
- **Front-projected onto the head:** u = 0.5 + x / 0.5 (x in head-relative metres, −0.25 … 0.25) and
  v = (z − chin) / (crown − chin), with the chin at −0.29 and the crown at +0.29 from the head's
  centre. The back of the head samples one skin texel. `anime_face.py` paints it (system Python with
  Pillow) and `anime_kit.build_head` projects it.
- **What must read at game zoom is the eye mass:** a dark-rimmed iris at least as big and dark as the
  approved test's (140 × 188 texels), with the lash line on its top. At zoom 8 one SubViewport pixel
  covers about 30 face texels (mip about 5); at zoom 12 about 45 face-on, and about 64 in a
  three-quarter view (mip 5.5–6). Brows and highlights are for the portraits (A-2): keep them light,
  in the approved test's style.
- **The mip-5 eye rule:** at mip 5, the darkest texel in each eye's area (a 220 × 240-texel box round
  the eye) is at least 40% darker than the skin, in luminance. **How to check it:**
  1. Build the mip chain the way Godot does, by repeated 2 × 2 averages: five `reduce(2)` steps for
     mip 5, one more for mip 6.
  2. Save `<id>_face_mip5.png` and `<id>_face_mip6.png` beside the face and look at them.
  3. Print, per eye, the darkest mip-5 texel against the skin.

  `python anime_face.py <out.png>` does all three and prints `mip-5 gate (>= 40%): OK`. The dealer:
  75% and 76% darker at mip 5, 60% at mip 6.
- **The import keys,** in each extracted image's `.png.import` `[params]` (the face and the palette
  alike): `compress/mode=0` (Lossless), `mipmaps/generate=true` and `detect_3d/compress_to=0`
  (Detect 3D off). Then reimport. With Detect 3D on, the first editor preview of the GLB switches the
  texture to VRAM Compressed, which breaks the mip-5 read, and S3TC corrupts palette cells. Test 19
  checks all three keys.
- Keep the 1024 source for the dialogue portraits (25.17).
- **Known (Stage D, 2026-09-27):** under some light angles (LookDev's light) the face falls in the
  toon's dark band. The eyes still read, and in the tavern the desk light lights her face.
  Face-normal shading is noted for 25.17 and 25.31.

#### Hair

- **Opaque clumps only:** tapered tubes following the head (the fringe, the face-framing locks, the
  back hair; `anime_hair.py`), on the palette atlas or the optional hair surface. No hair cards and no
  alpha cut-outs (see "No transparency" below). Lashes, iris rims and highlights are painted into the
  face texture instead.
- **They must clear the arms** in every clip the role plays: no hair vertex inside the upper-arm,
  forearm or hand capsules (the sleeve radius + 0.01 m). What worked for the dealer: the back hair
  as a central sheet of 7 clumps within ±31° of straight back (clumps at the sides hung where the
  lowered arms go, and Walking_A swings the arms 0.21 m behind the shoulders), and face-framing
  locks that end at the collarbone (longer tips sat where the arms reach forward).

#### Materials and ink

- **In Blender** (what the GLB carries), every material is a Principled BSDF with:
  - **the Alpha input unlinked, at 1.0,** and no image alpha or colour-attribute alpha linked
    anywhere. The Blender 4.5 glTF exporter takes `alphaMode` from that socket, not from a blend
    mode, so the GLB stays OPAQUE and Godot imports `transparency` DISABLED.
  - **backface culling off,** so glTF writes `doubleSided: true` and Godot imports `CULL_DISABLED`.
  - Metallic 0, Emission Strength 0, and roughness above 0 (the dealer's is 0.85; the runtime
    replaces it).

  `anime_merge.check` asserts all of it except roughness (its MATERIALS row: a Principled BSDF,
  Alpha unlinked at 1.0, backface culling off, Metallic 0, Emission Strength 0). Roughness > 0 is
  checked on the imported GLB by Test 19 (`_mesh_stats`).
- **No transparency anywhere on a character:** `transparency` DISABLED, no alpha blend, no alpha
  scissor. The edge-shader quad paints over transparent passes, and the shared outline hull has no
  texture or alpha test, so it would ink a cut-out card's whole shape.
- **In Godot the look is applied at load, not authored.** `scripts/game/anime_look.gd`'s
  `apply(model)` gives every imported StandardMaterial3D surface (props included) a toon copy as a
  surface override:
  - `diffuse_mode` TOON, with the band width set by roughness: **`TOON_BAND` 0.12** (the approved
    test's value; kept above 0 for Test 19's roughness rule. The edge shader inks skinned bodies
    whatever their roughness, because the renderer writes roughness as 1 − r·127/255 for dynamic
    instances)
  - `specular_mode` DISABLED, `metallic` 0, `metallic_specular` 0 (emission is left as imported:
    the Blender side keeps Emission Strength 0, and Test 19 fails an emissive toon surface)
  - `next_pass` = the shared outline

  There is one copy per imported material, shared by every instance, and the imported materials are
  never edited. A surface that isn't a StandardMaterial3D is left as imported, and one that isn't
  opaque gets no outline, each with a warning (Test 19 fails both), so deliver plain opaque
  materials. `staff_npc.gd` calls it for a variant whose `look` is `"anime"` (or `"realistic"`, the
  same path since 25.31), and never on a fallback body. Since 25.31 (V5) an emissive PROP material
  gets a glow copy instead (the RL spec's "Materials, glow and ink").
- **The ink outline** is `res://assets/characters/materials/anime_outline.tres`: one
  StandardMaterial3D for the whole cast, never duplicated. It is unshaded, `cull_mode` FRONT, `grow`
  on, **`grow_amount` 0.011** m (the approved test's; the `approved` preset's width; the cast's
  thicker ink is picked with the preset in Story 25.23's light, see the RL spec),
  **ink colour (0.17, 0.09, 0.12)**, metallic 0, roughness above 0 (the default 1), no emission,
  opaque. At zoom 12, 0.011 m is about 0.5 px on the half-resolution SubViewport (45 px/m), so in
  the hall the edge shader does most of the inking and the hull shows up close. Raphael was shown
  0.011 against 0.018 at zoom 8 at Stage D. Portrait-width outlines are 25.17's.
- **Shadow tone:** the dark side is albedo × the hall's ambient. Correction (Story 25.23, T1
  measured): "today" the ambient was never cool: MainTavern's Environment sets no ambient source, so
  the Background source renders the project's clear colour, a neutral 0.3 grey (its own ambient
  colour (0.4, 0.5, 0.7) × 0.3 is ignored). Since R-4 (2026-10-04) the environment's lights DO
  change: the picked mood (`game_config.json` › `tavern_light_mood`, scripts/game/tavern_lighting.gd)
  sets an explicit ambient colour and the day phase scales it, so the cast's dark side is albedo ×
  the picked mood's ambient. Characters still get no light of their own (A-5).
- **The ink light (25.23, LM-3):** the edge pass multiplies the screen by every DirectionalLight that
  reaches its EdgeQuad, so the hall keeps exactly one, and its transform, colour (1, 0.8, 0.5) and
  energy 1.5 never change in any mood or phase. A mood only moves its cull mask: all layers (it also
  lights the hall: "today") or render layer 20, the EdgeQuad's alone (a pure ink light: the moody
  moods). The EdgeQuad is on layer 20 with no shadow; `camera_3d.gd` adds layer 20 to its cull mask.

#### Budgets

- **Triangles: `AN_TRI_BUDGET` = 10,000 per body,** counted over the whole GLB with its props (as
  Test 19's `_mesh_stats` counts): min(10,000, ceil(9,459 × 1.15 / 500) × 500) = 10,000, from the
  dealer's measured 9,459 (`Dealer_Body` 9,427 + `Dealer_Quill` 32). The hard cap, `AN_TRI_CAP`, is
  also 10,000. The same number is in Test 19 (`AN_TRI_BUDGET`) and `anime_merge.py` (`TRI_BUDGET`):
  change all three together. (The approved test was 13,574 tris in 29 objects.)
- **Surfaces: ≤ 3 on `<Role>_Body`** (`AN_BODY_SURFACES` in Test 19, `SURFACE_CAP` in
  `anime_merge.py`). The outline draws each surface again, so a body is ≤ 6 render elements, and each
  prop adds its surfaces × 2 (the dealer seated with her quill may have ≤ 8). The dealer: 2 body
  surfaces + the quill's 1 = 6 elements.
- **The hall: 200 VISIBLE draw calls at 24 bodies.** 24 is the GDD's full hall at the avatar cap
  (5 patrons + 12 avatars + 4 staff), plus the player, Den Fa and the Cat. Measured in MainTavern on
  2026-09-27 with the crowd check (§6.5), on an **RTX 3080 with V-Sync off**, with render times
  summed over both viewports and averaged over ≥ 2,900 frames per sample:

  | Bodies | VISIBLE draw calls | GPU (ms) | CPU (ms) | fps |
  |---|---|---|---|---|
  | 6 (the baseline: the hall's own, clones freed) | 115 | 0.331 | 0.271 | 957 |
  | 22 | 181 | 0.343 | 0.352 | 842 |
  | 24 (the counter read 25: a patron walked in) | 193 | 0.350 | 0.368 | 849 |

  - The budget is the 24-body count, 193, rounded up to the next 50.
  - Each added body cost about 4 VISIBLE draws, 0.0008 ms of GPU and 0.005 ms of CPU (6 → 22
    bodies: +66 draws, +0.012 ms, +0.081 ms).
  - The clones' outline hulls are 38 of the 24-body draws (193 → 155 with them off).
  - **It passes:** at 24 bodies the larger of the GPU and CPU render times, 0.368 ms, is ≤ 8.3 ms
    (half a 60 fps frame, kept as headroom for the GDD's mid-range target).
  - The VISIBLE counter counts each opaque element once, but Forward+ draws opaque geometry again in
    the depth prepass, so the GPU's real draws are about twice the counter. Compare only against a
    baseline from the same run.
- **Shadows:** the 2026-09-27 hall budget above was measured with no shadow-casting light. The outline
  is an opaque `next_pass`, so under a shadowed light each body surface and its hull are drawn again
  in every shadow view: up to 4 PSSM splits for ExteriorWorld's sun, 2 views for a dual-paraboloid
  omni, 6 for a cube one. The town's own budget was measured in 25.31 with the realistic villagers
  and the player under the sun: the RL spec's "Budgets".
- **The hall under 25.23's lights (re-measured 2026-10-04):** the crowd check with the realistic S1
  bodies (the Bartender's, the player's and the Quest Dealer's GLBs as clones, 6 within the hearth
  light's range), RTX 3080, V-Sync off, 2,900 frames per sample, render times summed over both
  viewports. The moody moods shadow the hearth only (dual paraboloid, hard edges):

  | Bodies | Mood | VISIBLE | SHADOW | GPU (ms) | CPU (ms) | fps |
  |---|---|---|---|---|---|---|
  | 6 (the hall's own) | today | 103 | 0 | 0.296 | 0.249 | 1008 |
  | 24 | today | 178 | 0 | 0.353 | 0.315 | 808 |
  | 6 | moody_a | 105 | 65 | 0.428 | 0.326 | 1012 |
  | 22 | moody_a | 171 | 97 | 0.486 | 0.389 | 671 |
  | 24 | moody_a | 179 | 97 | 0.493 | 0.394 | 672 |
  | 24 | moody_a, the hearth's shadow in cube mode | 179 | 204 | 0.477 | 0.476 | 672 |
  | 24 | moody_a, the hearth's shadow off (its share) | 179 | 0 | 0.372 | 0.318 | 808 |
  | 24 | moody_b | 179 | 97 | 0.493 | 0.400 | 672 |

  - **Budgets: VISIBLE 200** at 24 bodies (unchanged: lights add no visible draws) and **SHADOW 100**
    at 24 bodies with the hearth's dual-paraboloid shadow (97 rounded up to the next 50; 250 if cube
    is picked). It passes: 0.49 ms at 24 bodies against 8.3 ms; no mitigation step was needed.
    Full table: `<art>/shots/25-23/25-23_budget.md`.
  - Re-measured with the full realistic cast in Story 25.31 (T-end): the RL spec's "Budgets" holds
    the current hall and town numbers.

#### Export

- **In Blender,** in its own MCP call (never open a file and export in the same call), with only
  `Rig`, `<Role>_Body` and its props selected:
  `bpy.ops.export_scene.gltf(use_selection=True, export_apply=False, export_skins=True, export_animations=True, export_yup=True)`.
  That is glTF Binary (`.glb`), +Y up, the skin and every action, modifiers not applied (the body's
  only modifier is its Armature; the rest were applied before the join; §6.4). Re-export after every
  clip change and compare the GLB's timestamp.
- **File naming:** a snake_case id that starts with the catalogue id (`g13_quest_dealer_anime`): the
  `.blend` at `<art>/blender/<id>.blend`, the GLB at `res://assets/characters/custom/<id>.glb`.
  Godot extracts each image beside the GLB as `<GLB name>_<image file name>.png`: the Blender 4.5
  exporter names each glTF image after its PNG file, not after the Blender image datablock (the
  dealer's datablocks are `dealer_face` and `dealer_palette`, but her files `g13_quest_dealer_face.png`
  and `g13_quest_dealer_palette.png` give `g13_quest_dealer_anime_g13_quest_dealer_face.png` and
  `…_palette.png`), each with its own `.png.import`.
- **Never overwrite a file:** a rebuilt body gets a new name. The anime dealer is
  `g13_quest_dealer_anime.glb` because the 25.13 KayKit `g13_quest_dealer.glb` exists; that file
  stays on disk, with its PNGs, as her fallback for as long as `staff.json` names it. If a name
  exists, stop and ask.
- **No `-col`, `-colonly`, `-convcolonly` or `-navmesh` style suffix on any Blender object name.**
  The import keeps `nodes/use_node_type_suffixes=true`, so such a node would become collision or a
  navmesh. Characters carry no collision.
- **The Godot import:**
  - Import headless (`--headless --path . --import`; exit code 139 is harmless) and check by loading
    the resource.
  - Each extracted image's `.png.import`: the three keys under "The face".
  - The `.glb.import`: `meshes/generate_lods=false`, and a minimal `_subresources` =
    `{"animations": {"<clip>": {"settings/loop_mode": 1}, …}}` for exactly the role's loops. Godot
    expands it on reimport; commit the expanded file.
  - Materials aren't extracted: the runtime look replaces them by override.

#### Data: bodies swap by data path

- **(a) Implemented and tested (Story 25.30): the staff,** in `data/characters/staff.json` ›
  `roles.<role>.variants.<variant>`:
  - `model_path`: the AN body's GLB.
  - `fallback_model_path`: a file that exists, loaded when `model_path` doesn't load (the dealer's:
    the 25.13 KayKit `g13_quest_dealer.glb`). Tests 5 and 19 check that both files exist; before
    removing a fallback file, repoint the field in the same commit.
  - `look`: `"anime"` makes `staff_npc.gd` call `anime_look.apply` on the variant's own body, never
    on the fallback.
  - `body`: the body-measured numbers, used only when the variant's own body loaded; a fallback body
    uses the script constants. Every key is a number > 0 (`seated_front` may be ≤ 0). A missing key
    would silently fall back to the KayKit constant, so Test 19 checks them all. Re-measure them on
    the skinned body for every new body (`anime_clearcheck.measure()`). The controllers read
    `hip_back`, `stool_pull`, `bubble_seated` and the speeds; `seated_front`, `walk_half_at_desk`
    and `idle_front` feed Test 19's desk geometry.

    | Key | What it is | The dealer (AN) | Her fallback (the KayKit g13 constant) |
    |---|---|---|---|
    | `hip_back` | how far in front of the WorkPoint her seated root sits (the sit clips put her hips 0.397 behind the root, so 0.397 puts them right over the WorkPoint). Rules: 0.18 ≤ `hip_back` ≤ 0.57, and the desk clearance `seated.z + seated_front <= DESK_SLAB_BACK - 0.02` | 0.397 | `DEALER_HIP_BACK` 0.32 |
    | `stool_pull` | how far the stool slides back while she sits down; **≥ 0.45** (Test 19's floor) | 0.45 | `STOOL_PULL` 0.52 |
    | `seated_front` | Sit_Chair_Idle's front at desk-top height, from her root | −0.276 | `SEATED_FRONT` −0.039 |
    | `walk_half_at_desk` | Walk_Bar's half-width at desk-top height | 0.289 | `WALK_HALF_AT_DESK` 0.40 |
    | `idle_front` | Idle's front at desk-top height, from her root | 0.159 | Test 19's `DEALER_IDLE_FRONT` 0.363 |
    | `bubble_seated` | the bark bubble's height while seated (the seated top + 0.10) | 1.94 | `BUBBLE_SEATED` 1.95 |
    | `hall_speed` | Walking_A's ground speed: stance length ÷ stance time, both feet, so the feet don't skate (m/s) | 1.51 | `HALL_SPEED` 0.82 |
    | `bar_speed` | Walk_Bar's ground speed, measured the same way (m/s) | 0.75 | `BAR_SPEED` 0.48 |

  - The approach point is not a body number: it stays `APPROACH_LOCAL` (desk geometry) for every
    body.
- **(b), (c): final since Story 25.31.** classes.json, townsfolk.json and the new player.json carry
  `model_path`, `fallback_model_path` and `look` (+ the measured speeds and head tops); the dealer's
  `silver_elf` points at her realistic body, with this AN body's v2 re-export as the fallback. The
  field names and their readers: the RL spec's "Data: bodies swap by data path (final)".

#### Validation

- **In Blender:**
  - `anime_merge.check`: every row OK; the top ≤ 2.25 m.
  - The foot report (no clip the game plays over 0.03 m on a contact frame) and the seated-room
    report (≥ 1.05).
  - For a role that works at furniture, `anime_clearcheck.py`: the 25.13 method on densified point
    clouds (edges sampled at 1/3 and 2/3), each check first shown to report a hit on a deliberately
    bad pose:
    - 0 hits on the desk's slab, front and side panels, in every clip and at every station;
    - the stool: overlap allowed only below the seat top and behind the root, seated depth
      ≤ 0.048 m (the dealer: 0.039);
    - the self-clips, 0 each: hair against the arm capsules; thighs outside the skirt above the hem
      (seated poke-through ≤ 0.01 m); each wrist ring inside its cuff.

    The dealer: all zero (her hands keep their rest gap of 0.0105 m inside the cuffs in every frame).
- **In Godot, Test 19** (in the failsafe suite: 502/0 after Story 25.30, Test 19 118 checks in about
  5.4–6.9 s) runs on every variant `staff.json` names:
  - **The GLB:** the KayKit rig (≥ 41 bones, the handslots, `hips`, `head`); exactly 76 + the role's
    own clips, the cast's clips present, no `.00x`, none of the excluded ones; the loops loop and the
    one-shots play once; only `<Role>_` meshes and the listed props; one `<Role>_Body` with ≤ 3
    surfaces; its textures Lossless with mipmaps and Detect 3D off; no LODs; tris ≤ `AN_TRI_BUDGET`,
    nothing glows, roughness > 0, no metal; the top above 1.8 and ≤ 2.25 m.
  - **The data:** `look` "anime", the fallback path, every `body` number; the desk geometry checked
    twice, once on the KayKit constants and once on the variant's `body`.
  - **The loaded body** (`_staff_look_wrong`): every surface overridden by a toon StandardMaterial3D
    (TOON, specular off, metallic 0, roughness > 0, no emission, opaque) with the shared outline as
    `next_pass`; the outline unshaded, CULL_FRONT, grow on; two instances sharing their overrides;
    the imported materials untouched; a fallback body not toned.
  - **The fallback case:** a missing `model_path` loads the fallback with the script constants and
    no toon.
  - **The sit re-fit on the loaded body:** Sit_Chair_Idle's hips within 0.03 of `AN_SIT_HIPS_Y` and
    0.40 (± 0.02) behind the root, the feet within 0.03 m of their rest height, Down and StandUp
    meeting it within 0.01 m, the `upperarm` heads ≥ 1.05.
  - **The staff behaviour with the body's numbers:** the first frame, the stool choreography, the
    autopilot, `set_work_state`, fire and re-hire.
- **Stage D:** the character variant in §6.5 (six pass criteria and the crowd check).

### Character concepts (Story 25.31, n8n `stage: "character"`)

Concepts first (AH-2): Raphael paints a turnaround sheet per character with `tools/n8n/`, picks one per character
in the gallery (`picked/<job id>.png`), and the Blender build follows the pick (a look guide, not a blueprint).
The 14 jobs mirror this section. Each job: `stage: "character"`, 16:9, 3 variants; refs (relative to the art
folder) `refs/anime_dealer_turnaround.png` (the shipped Quest Dealer, front/side/back, Idle pose) and
`anime_test/anime_test_report.jpg` (the approved anime test), plus the character's own reference from Raphael's
`documentation/artwork/use to inspire/` copied to `refs/` with a name. They sit first in the job list, in slice
order (S1, then S2 the townsfolk, then S3 the classes); runs are capped at 15 images (`4467833`), taken in file
order. The picks (2026-10-04) are in `<art>/picked/`; every RL body was built from its pick.

Each prompt is the shared opening, then the character's line, then the palette rules:

> Character turnaround sheet of ONE character shown three times side by side: front view, right side view, back view. Full body, standing upright, arms relaxed about 35 degrees away from the body, orthographic, plain mid-grey background, no text, no labels, no frames. Use the first two attached images only for the proportions, the rendering style and the three-view layout, NOT for their design or colours: REALISTIC adult human proportions (about 7 to 7.5 heads tall, a normal-sized head, normal-sized eyes): NOT anime, NOT chibi, NOT cute, NO big eyes. Grounded, gritty low-fantasy people drawn exactly in the style of the two attached style references: a hand-drawn cel-shaded look with two-tone shading, DEEP hard-edged shadows and thick dark ink outlines, a muted desaturated earthy palette, worn, patched and dirtied clothes, weathered serious faces. A hard world where adventurers die; these people have seen it. [then the per-character text in the table below] (2026-10-03: REALISTIC proportions, Raphael; style refs refs/style_realistic_local_d2.png and refs/style_realistic_traveller_d3.png)

> Palette rules for the whole cast: no green anywhere[, except …]; no cream or off-white clothing[, except …]; no teal-blue (that is another character's colour). Hands empty unless a prop is named.

| Job | Extra ref | The character's line | Palette exceptions |
|---|---|---|---|
| `C_G1_player` | `refs/raphael_lodoss_parn_cloak.png` | The player: ONE man, a weathered retired adventurer given a second chance, an old soldier in his forties: tired kind eyes, a short scruffy beard and short dark hair touched with grey, a few scars. A long travel coat or a cape in weathered brown or dusty slate grey-blue (never green), a plain linen shirt, a leather jerkin and belt, dark trousers, practical worn boots. No weapon drawn; a sword may hang at the hip. Humble, practical, lived-in. | none |
| `C_G12_bartender` | `refs/raphael_pixel_tavern_barkeep.jpg` | The tavern's Bartender: a burly, broad-shouldered barkeep with a belly, bare-headed (bald or very short cropped hair) and a full grey beard, thick forearms. A wine-red shirt with the sleeves rolled up to the elbows (no cuffs), a knee-length dark brown leather apron, dark trousers, sturdy boots, a small off-white bar cloth tucked in his belt. Dry wit, never stops moving. Chunky readable shapes, no weapons. | except his small bar cloth |
| `C_G19_farmer` | none | A farmer (townsfolk): a middle-aged man with a full brown beard, a wide straw hat whose brim still lets the face show from above, a loose undyed linen shirt, brown trousers held by a rope belt, straw-coloured and earthy brown tones, worn boots. Hands free. | none |
| `C_G19_local` | none | A local (townsfolk): a town man in his thirties, clean-shaven or stubble, a soft cloth cap with a short peak, a blue-grey tunic over a brown shirt, brown trousers, a belt, simple shoes. Ordinary and friendly. Hands free. | none |
| `C_G19_traveller` | none | A traveller (townsfolk): a road-worn wanderer (a man or a woman) in a dusty brown and grey hooded travel cloak with the hood up, a bedroll strapped across the top of a small backpack, a scarf, worn boots, a water skin at the belt. Dusty brown and grey only (NOT green). Hands free. | none |
| `C_G19_guard` | none | A town guard (townsfolk): a sturdy man in grey mail with a steel morion helmet (a crested comb on top and a brim that sweeps up at the front and back, his face fully visible: NOT a wide flat brim), a deep crimson livery tabard with a gold hem over the mail, a belt, steel-capped boots. Alert, proud. Hands free (no spear). | none |
| `C_G19_merchant` | none | A merchant (townsfolk): a well-fed man with a trimmed beard, a floppy beret worn at a slant with a small feather, a deep violet-purple coat with gold trim (a cooler purple than plum), a fat coin purse at his belt, rings, good boots. Shrewd and cheerful. Hands free. | none |
| `C_G19_old_woman` | none | An old woman (townsfolk): a small elderly woman with grey hair in a bun, a headscarf, a draped shawl in muted lavender (NOT cream), a long brown dress, a wooden cane in her right hand. Kind, a little hunched. | none |
| `C_G2_fighter` | `refs/raphael_anime_adventurer_party.jpg` | The Fighter adventurer: a young man, disciplined but questioning, in practical plate-and-mail armour with a brick-red surcoat and trims, a longsword at the hip and a round shield on the back, no helmet (or one with the face fully open), short hair. | none |
| `C_G3_rogue` | `refs/raphael_anime_adventurer_party.jpg` | The Rogue adventurer: a young woman, talented but reckless, a red ponytail, light dark-brown leathers with a short hooded cowl down on her shoulders, two daggers at her belt, a small green scarf as her only touch of green, soft boots. Quick and cocky. | except the Rogue's small green scarf |
| `C_G4_mage` | `refs/raphael_lodoss_cloaked_mage.jpg` | The Mage adventurer: a young man, book-smart, in long mid-blue robes with darker blue trim, a LOW floppy wide hat that does not stand tall (or a hood), a leather book satchel, a wooden staff in his right hand, cloth shoes. Studious, a little nervous. | none |
| `C_G5_healer` | `refs/raphael_anime_adventurer_party.jpg` | The Healer adventurer: a young woman in cream-white robes with a soft healer's hood, a tabard with a green cross, a satchel at her hip, warm gold trims, a wooden staff in her right hand topped with a GLOWING green crystal. Calm and kind. | except the Healer's green cross and glowing green crystal; except the Healer's robes |
| `C_G6_barbarian` | `refs/raphael_anime_adventurer_party.jpg` | The Barbarian adventurer: a burly, broad man with bare muscular arms, a wild beard and long hair, fur on the shoulders, burnt-orange cloth and dark leather, a big axe on his back, heavy boots. All fury, no control. | none |
| `C_G7_ranger` | `refs/raphael_lodoss_elf_archer_card.jpg` | The Ranger adventurer: a young woman (human, round ears) in forest green and brown leather, a hooded cape, a longbow in her LEFT hand, a quiver of red-fletched arrows on her back, bracers, soft boots. Watchful and calm. | except the Ranger's forest green |

---

## 2. The pipeline

```
Stage A  Concept image    any image generator            → reference only, never shipped
Stage B  Model            Route 1: Claude builds it in Blender (default)
                          Route 2: image-to-3D, then Claude cleans it (organic shapes only)
                          Route RL: realistic characters on the re-proportioned KayKit rig (§1 character spec)
                          Route AN: the anime dealer (her fallback body; §1 appendix)
Stage C  Atlas + export   Claude in Blender               → assets/environment/custom/<id>.gltf
                          characters: head + body atlas   → assets/characters/custom/<id>.glb
Stage D  Check in Godot   under the real shader + camera  → keep / redo / kill
```

**Stage A is automated.** `tools/n8n/` holds an n8n workflow that sends these prompts to Nano Banana
(Gemini) in three layers: key art → object concepts → front/side/top reference views. You pick
the best image at each layer. See `tools/n8n/README.md`. You can still paste prompts by hand into
any generator. **Views layer (tried 2026-09-24):** Nano Banana mostly redraws the concept's own
three-quarter angle instead of turning to front, side or top, so the views jobs are switched off.
Model from the picked concept plus the card's sizes, comparing screenshots taken at the same
30°/45° camera angle.

**Route 1: Claude builds it (the default).** Use it for buildings, furniture, ruins, and
anything hard-edged. Claude writes Blender Python through the MCP, builds from primitives,
screenshots the viewport, compares with your concept, and refines. This matches KayKit best,
because KayKit models are primitives plus bevels.

**Route 2: image-to-3D.** Use it only for organic shapes: a dragon skull, a gnarled tree,
a lumpy mound, a statue. Make a clean "model sheet" image (sheet suffix below), feed it to
Hyper3D Rodin or Hunyuan3D (both are built into the community Blender MCP), or to Meshy or Tripo by hand.
Then Claude decimates it hard and remaps it onto the atlas (§6.3). Expect to throw away
about 1 in 2.

**Route RL: realistic characters (since 2026-10-04, Story 25.31).** Use it for every human
character: the staff, patrons, adventurers, the player and townsfolk. It is route AN's chain (below)
run on a re-proportioned adult rig (REAL-1 for men, REAL-2 for women) from its own chain configs,
with the head projected from the character's picked concept sheet and a painted body atlas. The
scripts are in `tools/blender/realistic/` (its `README.md` lists the bases, the chain and each
character's steps); the rules are the character spec (route RL) in §1. The whole demo cast (15
bodies) was built on it in Story 25.31.

**Route AN: anime characters (2026-09-26 to 2026-10-04, Story 25.30; now the anime Quest Dealer's
fallback body only).** It was the route for every character: the
staff, patrons, adventurers, the player and townsfolk. Claude builds the body in Blender through the
MCP with Route 1's method (scripted, from primitives), on the KayKit skeleton with its rest pose
stretched to SD proportions, so the 76 KayKit clips keep working. The scripts are versioned in the
game repo at `tools/blender/anime/` (its `README.md` lists the chain), and every character starts
from the shared base `<art>/blender/anime_base.blend`. The rules are the character spec at the end
of §1. The toon look and the ink outline are applied in Godot at load, and bodies swap by data
path. First built: G13, the Quest Dealer. After the Kickstarter, paid 3D artists
redo the cast to the same spec. The RS route of the §8 log (an inked mesh on the unchanged KayKit
rig: G5, G7, G12, G13, the townsfolk kit) is retired for new characters.

**Which Blender MCP to use:**

- **Community `mcp-for-blender`** ([github.com/ahujasid/blender-mcp](https://github.com/ahujasid/blender-mcp)).
  It can run code, take viewport screenshots, and export GLB/FBX. It also connects to Poly Haven, Sketchfab,
  **Poly Pizza** (a CC0 low-poly library: search it before generating anything),
  Hyper3D Rodin, and Hunyuan3D.
  - Claude Code: `claude mcp add blender uvx mcp-for-blender`
  - Add-on: `uvx mcp-for-blender install-addon`. Then in Blender go to Preferences → Add-ons →
    enable "Interface: MCP for Blender", and in the 3D view press N → MCP tab → **Start MCP Server**.
- **Official Blender connector** (Anthropic, launched 2026-04-28). It analyses scenes and
  runs scripts through Blender's Python API. *I couldn't verify its install steps or whether it
  includes image-to-3D. Check Claude's connector directory.* Route 1 works with either
  one. Route 2's built-in generators are in the community one.
- **Safety:** the MCP runs any Python it's given inside Blender. The prompts in §6 tell Claude to
  save the `.blend` before each major step.
- **MCP status (2026-09-24, Story 25.1):**
  - Blender 4.5.2 LTS.
  - Add-on updated on disk with `uvx mcp-for-blender install-addon`. On Windows, run it with
    `PYTHONIOENCODING=utf-8`, because its final message crashes the cp1252 console after the
    install has already succeeded.
  - It writes `…\Blender\4.5\scripts\addons\blender_mcp.py` (and refreshes the older `addon.py`).
  - **Blender still reports protocol 5 until it is restarted** (or the add-on is re-enabled and
    the MCP server started again). The expected protocol is 9.
  - Integrations (Hyper3D Rodin, Hunyuan3D, Poly Haven, Poly Pizza, Sketchfab): all **off**.
  - Add-on telemetry consent: **ON**. That's Raphael's choice; toggle it in the MCP panel.

**Sheet suffix.** Append this to any concept prompt when you want an image for Route 2, or a
clean single-object reference for Route 1:

> Single object only, centred, whole object in frame, three-quarter view from 30 degrees
> above, plain flat light-grey background, even soft lighting, no cast shadows, no ground
> plane, no text, no other objects. Low-poly stylized game asset, flat-shaded faces,
> simple solid colours.

**Optional pixel preview.** Add *"rendered as crisp high-resolution pixel art with dithered
shading"* to any key-art prompt to preview roughly how it'll look under the in-game shader.
Use the non-pixel version as the modelling reference. **Caveat (seen 2026-09-24):** when a
reference image is attached, Nano Banana copies the reference's style and ignores this. For a
faithful preview, pixelate the image locally instead: the tavern renders at half resolution
(`stretch_shrink = 2` in `MainTavern.tscn`), so downscale ×2 and upscale ×2 with nearest-neighbour.

---

## 3. Priority: Batch 1 (hard cap: 6)

| # | Asset | Why it's in Batch 1 | Route |
|---|---|---|---|
| 0 | **K1–K3 key art** (tavern exterior, interior, world map) | Locks the look for everything. Also useful as Kickstarter art | Stage A only |
| 1 | **D1 Prior Ruins** (the **gate** asset) | Small, and unique to your world (KayKit has nothing like it). Tests every pipeline step, including the teal glow | 1 |
| 2 | **B6 The Hourglass Pillar** | The hall's centrepiece and a named Kickstarter visual. Built right after D1 proves the pipeline (moved up from Batch 2 on 2026-09-24) | 1 |
| 3 | **A1 + A2 The Guild Tavern** (walkable exterior + hex-centre miniature) | The first thing the player sees on both screens. Today it's KayKit's blue-team RTS tavern | 1 |
| 4 | **B1 The Hearth** | Core interaction (the fire minigame). Today it's 3 grey boxes | 1 |
| 5 | **B2 The Bar** (now the round bar around the pillar) | Second core interaction, and it sets the interior's tone | 1 |
| 6 | **D2 Demon Cult Crypt** (redesigned from the open-pit shrine) | Gives the map a visible threat, and it's the entrance to the cult's dungeon. No KayKit equivalent | 1 |

**Batch 2** (only after Batch 1 is in the game): D3 Dragon's Lair (moved out of Batch 1 on
2026-09-24 to keep the cap at 6), B3 Recruitment Desk, B4 Mission Board, B5 Wall of the Fallen,
D4–D7.
**Backlog:** everything else marked *backlog* below.

---

## 4. Stage A: Key art (style lock)

Style locked on 2026-09-24 (§1): **inked**. Every prompt below is sent together with the
commission as a reference image (`<art>/refs/commission_tavern_pillar.webp`). These prompts
mirror `tools/n8n/asset_prompts.json`. The first-round "cozy render" prompts are superseded, but
their images stay in the gallery.

### K1: Tavern exterior at night

> Use the attached reference illustration for the art style, the colour palette and this exact
> building's design (the same half-timbered guild tavern), but show the whole building from
> outside, not a cutaway. Isometric view from 30 degrees above, orthographic camera. The two-
> storey guild tavern at night: a pale stone ground floor, white plaster and dark timber-
> framed upper storey, steep dark red shingle roofs with a slightly curved ridge, two stone
> chimneys with thin smoke, warm amber light glowing from small arched windows, a heavy arched
> wooden door with a hanging lantern, a hanging wooden sign with an hourglass-inside-a-flame
> emblem, barrels by the door, a cobblestone path leading to the door, one small cloaked
> traveller approaching. Around it: gnarled leafless trees, big rounded boulders, rough grass,
> a dirt road. Style: hand-inked comic illustration like the reference: confident variable-
> weight black outlines, light hatching, flat colours with two or three tones per material,
> hard graphic shadow shapes (Mike Mignola inspired). Cold blue-violet night against warm
> amber windows. Melancholy and inviting. The building keeps chunky, simple, readable shapes,
> like a stylised game building. No text.

### K2: Tavern interior with the Hourglass Pillar

The picked interior came from the style test (job `S2_interior_pillar_pixel`, v1): the prompt
asked for pixel art, but the reference image won and it came out inked. The inked version of
the same prompt (job `S1_interior_pillar_inked`):

> Use the attached reference illustration for the room layout, the central pillar with its
> round bar, and the mood. Isometric cutaway view from 30 degrees above, orthographic camera,
> two walls and part of the roof removed so we see inside a timber-and-stone adventurers'
> guild tavern hall at night. In the exact centre of the hall an ancient pale-stone pillar
> rises up through a round opening in the wooden floor from the cellar below: its shaft is
> carved with bands of glowing teal runes, and set into its middle is a large hourglass of
> dark bronze and glass filled with glowing teal sand. A round wooden bar counter encircles
> the base of the pillar, its front panels carved with more teal runes, with simple bar stools
> around it. Around the room: a big stone hearth with a warm fire, tall back shelves of
> bottles and a large barrel on its side, a notice board with pinned papers, a recruitment
> desk with an open ledger and a candle, a few round tables, a wooden staircase. The warm
> amber firelight fights the cold teal glow of the pillar. Melancholy, mysterious and
> inviting. Plain dark background around the cutaway, no people, no text. Also match the
> reference's drawing style: bold dark ink outlines on every silhouette and major edge, flat
> colours with only two or three tones per material, hard graphic shadow shapes (Mike Mignola
> inspired). But it must still read as a low-poly 3D game model: chunky toy-like proportions,
> simple blocky shapes, flat-shaded faces, no fine texture detail, no painterly brush marks.
> Palette: honey and dark timber, pale grey stone, amber firelight, deep blue-violet shadow,
> teal glow.

### K3: World map

> Use the attached reference illustration only for the art style and colour palette, not for
> its content. Isometric view from 50 degrees above, orthographic: a hex-tile world map of a
> small island, like a board-game diorama. Hexagonal tiles: grassland, pine forests, rocky
> mountains with a dark cave, a winding river with a stone bridge, a coastline with shallow
> turquoise water. A small guild tavern with a dark red roof on the centre tile. Scattered
> landmark tiles: crumbling pale-stone ancient ruins with glowing teal runes, a jagged black
> shrine with a magenta-red glow, a bandit camp with a log palisade and campfire, a small
> mining village in the mountains, a watchtower near the coast. Style: hand-inked comic
> illustration like the reference: confident variable-weight black outlines, light hatching,
> flat colours with two or three tones per material, hard graphic shadow shapes (Mike Mignola
> inspired). Late-afternoon light, one side of the island darker and more foreboding. Clean,
> readable hex edges and silhouettes. Palette: muted greens, sand, pale stone, blue-teal sea,
> small accents of teal glow and magenta-red. No text, no labels.

---

## 5. Asset cards

Each card lists where the asset goes in the game, its size, its route, and its prompt. **⚑ marks a
proposal from me, not a recorded design decision.** Change or drop those freely.

### A. Tavern exterior

#### A1: The Guild Tavern (walkable exterior) · Batch 1 · Route 1
- **In game:** `scenes/world/ExteriorWorld.tscn`. It replaces `building_tavern_blue2`, which is the KayKit
  tavern scaled ×3 and rotated 90°. The door must face `TavernEntranceZone`.
- **Size:** relative to the scene rather than absolute. Import `building_blacksmith_blue.gltf` ×3
  and `Knight.glb` as references. The tavern should be the biggest building in the scene
  (~1.5× the blacksmith), and its door should be clearly taller than the Knight. The interior is
  **not** modelled: the door is only a trigger.
- **Budget:** ≤ 6,000 tris. Separate objects: `tavern_body`, `tavern_sign`, `chimney_smoke_anchor`
  (an empty object where Godot will attach smoke particles).
- **Concept prompt:** K1 + the sheet suffix. Swap the first sentence for *"A single building:"*.
- **Palette slots:** `stone_light` ground floor, `sand_plaster` upper walls, `wood_dark` frame,
  `roof_red` roof, `stone_dark` chimney, `emissive_window` windows.
- ⚑ **Sign emblem:** an hourglass inside a flame, joining the Priors (time) and the hearth (fire).

#### A2: The Guild Tavern (hex miniature) · Batch 1 · derived from A1
- **In game:** `TAVERN_TOPPER` in `scripts/world/HexMapGenerator.gd` (the centre hex).
- **Size:** fits a hex like KayKit's tavern. Footprint ≤ 1.3 × 1.4 m, height ≈ 1.4 m.
- **Budget:** ≤ 3,000 tris.
- **How:** don't design it again. Tell Claude: *"Make a hex-scale version of A1: same silhouette,
  roof colour and chimney. Drop the sign, barrels and small trim."* Deriving it from A1 keeps the two views
  visibly the same building.

#### A3: Tavern yard dressing · backlog
Firewood stack, lantern post, hitching rail, and the farmland plots (hops / orchard / vines, from Story
Bible §5). Try KayKit props and Poly Pizza first.

### B. Tavern interior (`scenes/MainTavern.tscn`)

**Room facts:** the floor is 20 × 24 m and the walls are 4 m high. The camera is **orthographic, 30° down,
45° yawed** (size 12). Everything is seen from above at an angle, so tops matter more than fronts,
and nothing is ever seen from below.

#### B1: The Hearth · Batch 1 · Route 1
- **In game:** replaces the `Fireplace` boxes (`FireplaceBase` / `FireplaceBack` / `Mantel`) where
  they sit now. **Keep** `FireLight` and `FireParticles`. The fire itself stays particles and light,
  so only model the stone.
- **Size:** ~2.5 m wide × 1.5 m deep. The firebox opening is ~1.2 m wide × 1.0 m high, with its floor at
  ~0.25 m. Mantel at ~1.9 m. The chimney breast runs up to 4 m (wall height).
- **Budget:** ≤ 5,000 tris. Separate objects: `hearth_stone`, `log_pile` (so code can hide it
  when the fire is out), `andirons`. Add an `emissive_embers` slot for the ember bed, so Godot can
  drive its brightness from the fire state (roaring → low → dying → out).
- ⚑ **Prior tie:** a few foundation stones at the base carry faint teal runes, as if the building's
  secret is starting to show (Story Bible §1). Make them separate `emissive_prior_teal` faces so
  they can be switched off.
- **Concept prompt:**
  > Stylized low-poly 3D game asset: a large stone tavern hearth. Big rough-cut pale grey stone
  > blocks, a wide arched firebox with iron andirons and a neat stack of split logs, a thick dark
  > timber mantel beam holding two candles, a tankard and a small hourglass, the chimney breast
  > rising to the ceiling. A few foundation stones near the floor carry faint glowing teal
  > carved runes. Warm and heavy, the heart of the room. Chunky toy-like proportions, flat-shaded
  > faces, soft colour gradients, bevelled edges, no fine texture detail. Isometric view from 30
  > degrees above, plain light-grey background.

#### B2: The Bar (round, around the pillar) · Batch 1 · Route 1
- **Decided 2026-09-24:** the bar is a full ring around the Hourglass Pillar (B6) from day one,
  as in the commissioned artwork. Early on only a stub of the pillar shows inside it.
- **In game:** the `BarArea` interaction. It replaces `BarCounter` and the local-only
  `TavernCounterCircular.glb`, and sits centred on the pillar.
- **Size:** counter 1.1 m high × 0.7 m deep, ring ~4.5 m across (⚑ check against the hall: the floor
  is 20 × 24 m). Leave a round floor opening in the centre for the pillar.
- **Budget:** ≤ 6,000 tris total. Separate objects: `bar_ring`, `bar_flap` (the hinged way in),
  and rune panels on `emissive_prior_teal` faces. The old back shelf and keg rack become wall
  props (backlog).
- **Stools are their own asset**, `bar_stool` (≤ 150 tris, exported as its own `.gltf`), so any
  number can be placed around the ring. Each carries an empty `seat_point` at seat height, facing
  the bar, for NPCs to sit on (see §7). Compare with the existing
  `assets/environment/decorations/stool.obj` first and reuse it if it fits the inked look. The
  concept draws stools in, but the B2 reference views leave them out on purpose.
- **Concept prompt:** mirrors job `B2_bar` (concept) in `tools/n8n/asset_prompts.json`:
  > Stylized low-poly 3D game asset: the round tavern bar from the reference image, shown on its
  > own. A full ring of bar counter about 4.5 metres across with one hinged flap to get inside, a
  > thick honey-coloured plank top on a dark timber base, the outer face divided into panels
  > carved with glowing teal runes, a brass foot rail, a few tankards and a cloth on the counter,
  > a ring of simple wooden bar stools around it. In the empty centre of the ring, a round
  > opening in the wooden floor where a pillar will stand: show the opening only, no pillar.
  > Warm and well-used. Chunky toy-like proportions, flat-shaded faces, soft colour gradients,
  > bevelled edges, no fine texture detail. Isometric view from 30 degrees above, plain
  > light-grey background.

#### B3: Recruitment Desk · Batch 2 · Route 1
- **In game:** the `RecruitmentDesk` area. The current `MissionDesk` box is 2 × 1.2 m, with its top at 0.9 m.
- **Budget:** ≤ 2,500 tris.
- **Concept prompt:**
  > Stylized low-poly 3D game asset: a heavy wooden guild recruitment desk. An open ledger with a
  > quill in an ink pot, a lit candle, a small brass hand bell, a stack of rolled hiring
  > contracts tied with red string, a worn stool behind it. Chunky toy-like proportions,
  > flat-shaded faces, soft colour gradients, bevelled edges, no fine texture detail. Isometric
  > view from 30 degrees above, plain light-grey background.

#### B4: Mission Board · Batch 2 · Route 1
- **In game:** the `MissionBoard` interaction, which opens `WorldMapBoard`. The current board is 3 × 2 m on a wall.
- **Budget:** ≤ 2,500 tris. Make the pinned notices separate objects so code could show or hide them
  per available mission.
- **Concept prompt:**
  > Stylized low-poly 3D game asset: a wall-mounted wooden guild notice board, 3 metres wide.
  > A thick timber frame, a painted hex map of an island in the centre, parchment notices pinned
  > around it, some marked with small skull symbols, red string linking a few of them, one
  > candle sconce on each side. Chunky toy-like proportions, flat-shaded faces, soft colour
  > gradients, bevelled edges, no fine texture detail. Front view tilted 30 degrees from above,
  > plain light-grey background.

#### B5: Wall of the Fallen · Batch 2 · Route 1
- **In game:** the "memorial wall" set-piece from Epic 19 (today the Codex is a plain list).
- **Budget:** wall piece ≤ 3,000 tris, and **one plaque ≤ 100 tris** as its own asset, so code can spawn
  one plaque per fallen hero.
- **Concept prompt:**
  > Stylized low-poly 3D game asset: a quiet memorial corner in a tavern. A stretch of timber
  > wall with rows of small wooden plaques and little framed tarot-card-sized portraits, a narrow
  > shelf of half-burnt candles beneath, and one empty chair pushed in at a small table with a
  > single full tankard left untouched. Melancholy, tender, not grim. Chunky toy-like
  > proportions, flat-shaded faces, soft colour gradients, bevelled edges, no fine texture
  > detail. Isometric view from 30 degrees above, plain light-grey background.
- *Backlog sibling:* the **Dragon Eye Book** (Epic 18 Codex set-piece): a huge tome on a lectern
  with a dragon-eye clasp that glows.

#### B6: The Hourglass Pillar · Batch 1 (right after D1) · Route 1
- **Decided 2026-09-24** (Story Bible §1): rooted in the cellar, it rises through the middle of
  the main hall inside the round bar (B2). Early on only a worn stub shows above the floor; each
  tavern upgrade reveals more of it. Fully revealed, it matches the commissioned artwork.
- **Your older design spec for this lives outside this repo.** Where it disagrees with the decision
  above, flag it rather than picking silently.
- Build it as **stacked segments**, each its own object, so upgrade tiers can reveal them in code:
  `pillar_foundation` (cellar part) → `pillar_base` → `pillar_shaft` (rune bands on
  `emissive_prior_teal` faces) → `pillar_hourglass` (bronze frame + glass, sand on
  `emissive_prior_teal`) → `pillar_capital` (broken crown).
- **Size:** ⚑ roughly 1.2 m wide, reaching ~3.5 m above the hall floor at full reveal (walls are 4 m).
- **Concept prompt:** mirrors job `B6_hourglass_pillar` (concept) in `tools/n8n/asset_prompts.json`:
  > Stylized low-poly 3D game asset: the ancient pale-stone hourglass pillar from the centre of
  > the reference image, shown on its own and fully excavated. Built as clearly stacked segments
  > from bottom to top: a wide rough foundation block (the part buried in the cellar), a thick
  > base drum, a shaft carved with bands of glowing teal runes, a large hourglass of dark bronze
  > and glass set into the middle of the shaft with glowing teal sand, and a broken crown-like
  > stone capital at the top. Mysterious, patient, very old, weathered. No floor and no bar
  > around it. Chunky toy-like proportions, flat-shaded faces, soft colour gradients, bevelled
  > edges, no fine texture detail. Isometric view from 30 degrees above, plain light-grey
  > background.

#### B7–B8 · backlog
Stairs to the quarters and a bed (`NextDayArea`). An infirmary cot for wounded adventurers (Adventurer
Presence Layer C).

### C. The world map

- **C1: Base tiles: don't replace them.** The map is built by `HexMapGenerator.gd` from KayKit
  tiles (grass, water, coast, rivers, roads, forest, mountain). There are dozens of good variants.
  Replacing them multiplies the work for little gain. The new map art is the **landmarks (D)** and
  the **tavern hex (A2)**.
- **C2: Map board frame** · backlog · 2D image, not 3D. A parchment-and-wood border for the
  `WorldMapBoard` UI.

### D. Hex landmarks

**Which missions need new art** (templates from `data/missions/mission_types.json`):

| Mission template(s) | Landmark | Source |
|---|---|---|
| `ancient_artifact` (+ Den Fa's Hidden missions) | Prior Ruins | **NEW: D1** |
| `demon_cult_investigation` | Demon Cult Shrine | **NEW: D2** |
| `dragon_reconnaissance` | Dragon's Lair | **NEW: D3** |
| `bandit_camp` | Bandit Hideout | **NEW: D4** (or assemble from KayKit props) |
| `goblin_patrol` | Goblin Warren | **NEW: D5** |
| `slime_extermination` | Slime Bog | **NEW: D6** |
| `herb_collection` | Herb Glade | **NEW: D7** |
| `rare_ore_mining` (Ironhold Pass) | Mine | KayKit `building_mine_blue` |
| `watchtower_construction` | Watchtower | KayKit `building_tower_A_blue` / `building_tower_base_blue` |
| `fortress_reinforcement`, `noble_caravan`, `diplomatic_package` | Castle / capital | KayKit `building_castle_blue` |
| `bridge_repair` | River crossing | KayKit `hex_river_crossing_A` / `_B` |
| `spy_network`, `merchant_escort_short` | Market town | KayKit `building_market_blue` |
| `refugee_escort`, `supply_run`, `urgent_message` | Village | KayKit `building_home_A/B_blue`, `building_well_blue` |
| `missing_caravan` | Road | KayKit `hex_road_*` + a broken-wagon prop (backlog) |

- The repo only contains KayKit's **blue** building set. Your full KayKit download may include
  other colour variants or extra pieces you haven't imported. Check it before making anything in
  a "KayKit" row.
- **Heads-up:** today `HexMapGenerator.gd` picks settlement buildings at random from
  `ZONE_BUILDINGS` and names them "Settlement N". Missions aren't tied to landmark type yet. New
  landmarks will *look* right but won't *mean* anything until the generator places them by
  mission type. That's a separate code task (§7).

**Size spec for all D cards:**
- A topper sitting on a KayKit hex, with its origin at bottom-centre on 0,0,0. The hex is 2.0 m across flats and 2.31 m
  point-to-point.
- Footprint ≤ 1.9 × 2.2 m, **preferably ≤ 1.6 × 1.8 m** so the tile's grass edge shows.
- Height 0.8–2.0 m. The KayKit tavern is 1.4 m, and the castle's 4.0 m is the ceiling.
- **≤ 3,000 tris.** The castle is 5,659, and only a capital earns that.

#### D1: Prior Ruins · Batch 1 · **GATE ASSET** · Route 1
- **Budget:** ≤ 2,000 tris. Stone uses `stone_beige` / `stone_taupe`, moss uses `moss`, the hourglass carving
  is **raised geometry** (not a texture), and broken tops are angled cuts, not noise.
- Runes are separate faces with an `emissive_prior_teal` slot.
- **Concept prompt:**
  > Stylized low-poly 3D hex tile game asset, isometric view from 30 degrees above. On a single
  > grassy hexagonal tile: the ruins of an ancient pale-stone temple. Three broken columns of
  > different heights, a collapsed archway, a round stone dais in the centre carved with an
  > hourglass symbol, and thin glowing teal runes cut into the stones. Moss creeping over fallen
  > blocks, one small tree growing through the rubble. Weathered, quiet, mysterious, not evil.
  > Chunky toy-like proportions, flat-shaded faces, soft colour gradients, bevelled edges, no
  > fine texture detail, low-poly board-game diorama style. Plain light-grey background.
  > Palette: pale beige and grey stone, fresh green grass and moss, teal glow.

#### D2: Demon Cult Crypt · Batch 1 · Route 1
- **Redesigned 2026-09-24:** a ruined gothic crypt, not an open pit. It's the surface entrance to
  the cult's underground temple: "town on top, dungeon below", in the spirit of Diablo 1's
  cathedral. Picked concept: job `D2_demon_crypt`, v2 (copied to `picked/D2_demon_shrine.png`, so
  the D2 views job and the card id stay `D2_demon_shrine`). The stairway-in-the-ground version
  (job `D2_demon_shrine` concept) lost.
- **Budget:** ≤ 2,500 tris. Swatches: `charcoal`, `iron`, `cloth_red`, `bone_white`, `stone_dark`.
  The glow from the doorway and the stairs uses `emissive_demon`. The spire is the tallest point
  (keep it ≤ 2.0 m).
- Only model the crypt, fence, gravestones and candles. The tile underneath is KayKit's own hex.
- **Concept prompt** (mirrors job `D2_demon_crypt`):
  > Match the art style, colour palette, lighting and level of detail of the attached
  > reference image, but show only the subject described next. Stylized low-poly 3D hex tile
  > game asset, isometric view from 30 degrees above. On a single six-sided hexagonal tile (a
  > hexagon, not a square) of scorched dark earth: a small ruined gothic crypt of black stone:
  > a squat mausoleum with a steep broken roof, a pointed-arch doorway, cracked buttresses and
  > one jagged spire. Its heavy iron door hangs open onto a stone stairway descending into
  > darkness, a faint magenta-red glow rising from far below. Tattered dark red banners on the
  > walls, bone-white candles by the door, a few leaning gravestones, a rusted iron fence,
  > dead grey grass at the tile's edges. Ominous but not gory: no bodies, no blood. Chunky
  > toy-like proportions, flat-shaded faces, soft colour gradients, bevelled edges, no fine
  > texture detail, low-poly board-game diorama style. Plain light-grey background. Palette:
  > charcoal and iron-grey stone, dark red cloth, a faint magenta-red glow, bone white.

#### D3: Dragon's Lair · Batch 2 (moved 2026-09-24) · Route 1 (+ Route 2 for the skull)
- A topper that brings its own rocky crag, similar in size to KayKit `mountain_A_grass`
  (1.8 × 1.9 m, 1.5 m tall). Height ≤ 1.8 m.
- **Budget:** ≤ 3,000 tris. Rock is faceted boulders (Route 1). The skull may be Route 2, decimated to ≤ 600 tris.
  Coin glints are tiny `emissive_gold` faces.
- **Concept prompt:**
  > Stylized low-poly 3D hex tile game asset, isometric view from 30 degrees above. On a single
  > hexagonal tile: a steep faceted rocky crag with a huge dark cave mouth, deep claw scars in the
  > rock, black scorch streaks around the entrance, a scatter of bones and a giant horned skull
  > half-buried at the cave's lip, a faint glint of gold coins in the darkness inside, a thin
  > wisp of smoke from a crack at the top. Chunky toy-like proportions, flat-shaded faces, soft
  > colour gradients, bevelled edges, no fine texture detail, low-poly board-game diorama style.
  > Plain light-grey background. Palette: warm grey and brown stone, charcoal scorch, bone
  > white, a spark of gold.
- **Skull sheet prompt (Route 2):**
  > A giant horned dragon skull, low-poly stylized game asset. Single object only, centred,
  > whole object in frame, three-quarter view from 30 degrees above, plain flat light-grey
  > background, even soft lighting, no cast shadows, no ground plane, no text, no other
  > objects. Flat-shaded faces, simple solid colours.

#### D4: Bandit Hideout · Batch 2 · Route 1 (assembly first)
- **Try assembly first:** have Claude import KayKit `tent`, `crate_*`, `barrel`, `weaponrack`, `flag_red`
  and model only the palisade and the campfire.
- **Budget:** ≤ 2,500 tris.
- **Concept prompt:**
  > Stylized low-poly 3D hex tile game asset, isometric view from 30 degrees above. On a single
  > grassy hexagonal tile: a small bandit camp. A ring of sharpened-log palisade with a gap for a
  > gate, two patched canvas tents, a campfire with a cooking pot, a crude lookout platform on
  > stilts, stolen crates and barrels, a torn red flag. Chunky toy-like proportions, flat-shaded
  > faces, soft colour gradients, bevelled edges, no fine texture detail, low-poly board-game
  > diorama style. Plain light-grey background.

#### D5: Goblin Warren · Batch 2 · Route 1
- **Budget:** ≤ 2,500 tris.
- **Concept prompt:**
  > Stylized low-poly 3D hex tile game asset, isometric view from 30 degrees above. On a single
  > hexagonal tile: a grassy mound burrowed full of round dark holes, crude huts of sticks and
  > stitched hide on top, a totem pole with a painted grinning face, a rickety rope bridge between
  > two huts, little piles of junk. Mischievous, not horror. Chunky toy-like proportions,
  > flat-shaded faces, soft colour gradients, bevelled edges, no fine texture detail, low-poly
  > board-game diorama style. Plain light-grey background.

#### D6: Slime Bog · Batch 2 · Route 1
- **Budget:** ≤ 2,000 tris. The slime blobs are separate objects so Godot can bounce them.
  Water uses the `water_light` swatch, and the slimes get a faint `emissive_slime`.
- **Concept prompt:**
  > Stylized low-poly 3D hex tile game asset, isometric view from 30 degrees above. On a single
  > hexagonal tile: a murky swamp. Dark green-brown water pools, clumps of reeds, two dead
  > leafless trees, three glossy translucent green slime blobs of different sizes sitting in
  > the shallows, a few bubbles on the water. Chunky toy-like proportions, flat-shaded faces,
  > soft colour gradients, bevelled edges, no fine texture detail, low-poly board-game diorama
  > style. Plain light-grey background.

#### D7: Herb Glade · Batch 2 · Route 1
- **Budget:** ≤ 1,200 tris. It's cheap: KayKit `tree_single_*` plus custom flower clusters.
- **Concept prompt:**
  > Stylized low-poly 3D hex tile game asset, isometric view from 30 degrees above. On a single
  > grassy hexagonal tile: a peaceful meadow with clusters of pale blue and white flowers, a single
  > mossy standing stone, a small stream crossing one corner. Gentle and safe. Chunky toy-like
  > proportions, flat-shaded faces, soft colour gradients, bevelled edges, no fine texture
  > detail, low-poly board-game diorama style. Plain light-grey background.

#### Landmark backlog
- ⚑ **Den Fa's Hermit Tower:** a narrow tower topped with a lantern, the hub for Hidden missions (he's The
  Hermit IX).
- **Demon Lord's Fortress:** on the map edge, for the endgame.
- **Refugee camp**, **broken caravan**.

---

## 6. Blender MCP prompts

Paste these into Claude Code on your PC with Blender open and the MCP connected.
**`<project>`** means your Godot project folder (`MCP_SETUP.md`: `F:/GAME I AM MAKING/shiningsun`).
**`<art>`** means a working folder **outside** the Godot project for `.blend` files, for example
`F:/GAME I AM MAKING/eternal_guild_art`. Keep it outside, because Godot tries to import any `.blend` it
finds inside the project.

**Characters (route RL; route AN for the fallback dealer)** have their own chain:
`tools/blender/realistic/README.md` (and `tools/blender/anime/README.md`) and the character spec in
§1. Of this section, only 6.4's note on rigged characters and 6.5's character variant apply to them.

### 6.0 Session setup (once per Blender session)

```
You're working in Blender through the MCP for my Godot game "Eternal Guild".
Before anything else: save the current file as <art>/blender/<asset_id>.blend (create the
folders if missing). Save again after every major step.

1. Scene: metric units, unit scale 1.0 (1 Blender unit = 1 m = 1 Godot unit). Z is up.
2. Create a collection "REF" and import these as scale/style references. Import only,
   never edit or re-export them:
   - <project>/assets/environment/hexagons/base/hex_grass.gltf
     (hex tile: 2.0 m across flats, 2.31 m point-to-point, top face at height 0)
   - <project>/assets/environment/hexagons/blue/building_tavern_blue.gltf
     (typical hex topper: ~1.2 x 1.3 m footprint, 1.4 m tall, ~3,000 tris)
   - <project>/assets/characters/models/kaykit_adventurers/Knight.glb (human scale)
3. Load <project>/assets/environment/hexagons/base/hexagons_medieval.png as an image
   datablock named "kaykit_atlas". It's a 1024x1024 atlas: 8 columns x 4 rows of vertical
   colour-gradient swatches, each 128 px wide x 256 px tall, lighter at the top.
4. Report back: the dimensions of each REF object after import, and which direction the
   front (door side) of building_tavern_blue faces. New assets must face the same way.
Don't build anything yet.
```

### 6.1 Build from concept (Route 1)

```
Build <ASSET NAME> for Eternal Guild, following card <id> in
documentation/design/08_ASSET_PROMPT_PACK.md. Look at the reference images first:
the picked concept <art>/picked/<id>.png and its front / side / top-down views in
<art>/generated/views/<id>/ (made by the n8n pipeline). Treat the views as a blueprint
for proportions and the concept as the target look.

Style: KayKit-like low-poly. Build from primitives (cubes, cylinders with 6-12 sides,
simple extrusions), bevel hard edges slightly (0.02-0.04 m, 1 segment), chunky
proportions, no modelled surface noise. Big shapes, not small detail.
Size: <paste the size line from the card>. Origin at bottom-centre, sitting on height 0.
Front faces the same way as REF/building_tavern_blue.
Triangle budget: <n> (hard max).

While building, put every face in a material slot named after what it is, using ONLY
names from the swatch table in section 6.3 (wood_light, stone_beige, roof_red, ...) or
emissive_<name> for anything that glows.
When the card lists separate objects, keep them separate, all parented to one empty
named <asset_id>.

Work in passes and save the .blend after each:
 (1) blockout of the big shapes -> viewport screenshot, orthographic, 30 deg down /
     45 deg around, next to REF -> tell me how it differs from the concept;
 (2) refine;
 (3) screenshot again.
Stop after pass 3 and show me. Don't keep iterating on your own.
Report: dimensions, triangle count, objects, material slots.
```

### 6.2 Clean up an AI-generated mesh (Route 2)

```
<Generate <asset> with the Hyper3D Rodin / Hunyuan3D tool from the views in
  <art>/generated/views/<id>/ (pass all of them if the tool accepts several images,
  otherwise the front view)>
  OR <I generated <asset> with Meshy/Tripo; it's imported as <object name>>.

Make it fit the KayKit style:
1. Save the .blend. Duplicate the original into a hidden collection "RAW" so we can go back.
2. Apply all transforms. Scale to <size from card>. Origin at bottom-centre on height 0.
   Front matches REF/building_tavern_blue.
3. Delete loose/internal geometry, merge by distance, then reduce to <= <n> triangles
   (try Decimate > Planar first, then Collapse if still over budget). Shade flat.
4. Delete all of its original textures and materials. No baked lighting may survive.
5. Split it into material slots by region (e.g. bone / horn / rock) using connected parts,
   normals or position, and name the slots from the swatch table in section 6.3.
6. Screenshot next to REF (orthographic, 30 deg down / 45 deg around).
   Report: triangle count, and whether the silhouette still reads.
```

### 6.3 Atlas remap: the step that makes it look like KayKit

**Characters don't use this atlas.** Each RL body has its own painted body atlas and head texture,
`<art>/textures/realistic/<id>_body.png` and `<id>_headpaint.png` (the character spec in §1), and
the AN dealer her small palette atlas; never `hexagons_medieval.png`. This section is for the
environment.

```
Remap <asset_id> onto the KayKit atlas:
1. For each material slot except emissive_*, find its swatch in the table below.
2. UV every face in that slot into its swatch:
   - U = the swatch's centre column (col + 0.5) / 8, +/- 0.02
   - V spread over the middle 60% of the swatch height, driven by each vertex's height
     within the whole asset: higher = nearer the top of the swatch (lighter).
     Image top is V = 1, so swatch row r spans V from 1 - (r+1)/4 to 1 - r/4.
3. Replace all non-emissive slots with ONE material "kaykit_atlas_mat": Principled BSDF,
   Base Color = kaykit_atlas image (interpolation: Closest), Metallic 0, Roughness 1.0.
   Roughness must stay above 0: the game's edge-detection shader skips outlines on
   roughness-0 surfaces.
4. emissive_* slots stay as their own materials: Base Color and Emission = the colour
   given for that slot, Emission Strength 2. Roughness 0 if it should have NO outline
   (glows usually shouldn't), otherwise 1.
5. Screenshot in Material Preview. Report the slot -> swatch mapping you used.
```

**Swatch table** (row, col, counted from 0 at the top-left of `hexagons_medieval.png`; colours
sampled from the file). The names are mine. Duplicate swatches in the atlas are left out.

| Slot name | Row, col | Top → bottom | Use for |
|---|---|---|---|
| `charcoal` | 0, 0 | `#263236` → `#000000` | soot, deep holes, cave mouths |
| `bone_white` | 0, 1 | `#FCFCFC` → `#AEBBC1` | bones, candles, skulls |
| `stone_light` | 0, 2 | `#AAB8BE` → `#596064` | grey stone, columns |
| `stone_dark` | 0, 3 | `#596064` → `#3C4246` | dark stone, chimney tops |
| `iron` | 0, 4 | `#4D4D4D` → `#1A1A1A` | metal fittings, andirons, pots |
| `wood_light` | 0, 5 | `#C8855F` → `#9B5A45` | planks, tables, beams |
| `wood_dark` | 0, 6 | `#B27052` → `#7D3D2C` | frames, barrels, posts |
| `ember` | 0, 7 | `#F07B36` → `#823323` | cold coals, rust |
| `water_light` | 1, 0 | `#87D1EA` → `#3E70B6` | shallow water, glass |
| `water_deep` | 1, 1 | `#29AAE2` → `#1C1F6D` | deep water, KayKit blue roofs |
| `gold_straw` | 1, 3 | `#FAD264` → `#A75D27` | straw, thatch, gold, beer |
| `grass` | 1, 4 | `#A9CC61` → `#4F8A30` | grass, leaves |
| `sand_plaster` | 1, 5 | `#E9C89A` → `#CB9460` | plaster walls, sand, bread |
| `stone_warm` | 1, 6 | `#A8A29D` → `#6D605C` | warm-grey stone, cobbles |
| `stone_brown` | 1, 7 | `#837265` → `#534741` | old stone, earth |
| `moss` | 2, 0 | `#DCE24C` → `#7A7E03` | moss, bog, dull slime |
| `prior_teal` | 2, 1 | `#00AC5D` → `#005D4B` | Prior accents, pine, non-glowing teal |
| `parchment` | 2, 5 | `#FDFBF9` → `#D2A06F` | paper, notices, linen |
| `demon_red` | 2, 6 | `#F15A24` → `#A40759` | demon stone accents |
| `brick_red` | 2, 7 | `#F07765` → `#C84649` | brick |
| `roof_red` / `cloth_red` | 3, 1 | `#EF6568` → `#A71C36` | tavern roof, banners, cushions |
| `candle_amber` | 3, 2 | `#FED365` → `#F48138` | honey, unlit windows |
| `fire` | 3, 4 | `#FDD264` → `#F25F27` | orange cloth, painted flames |
| `stone_beige` | 3, 5 | `#E2D3C0` → `#A88E6E` | Prior stone, pale walls |
| `stone_taupe` | 3, 6 | `#C0B09F` → `#6E5C4B` | weathered stone, rubble |
| `wood_old` | 3, 7 | `#9E8C7E` → `#493C33` | grey old wood, dead trees, palisades |

**Emissive colours** (⚑ proposals, tune in Godot):

| Slot | Colour |
|---|---|
| `emissive_prior_teal` | `#3FE0C8` |
| `emissive_demon` | `#E0306A` |
| `emissive_embers` | `#FF8A2B` |
| `emissive_window` | `#FFC266` |
| `emissive_gold` | `#FFD65C` |
| `emissive_slime` | `#9BE84A` |

### 6.4 Export to Godot

```
Export <asset_id> for Godot:
1. Save the .blend.
2. Apply all transforms on every object of the asset. Check: origin bottom-centre at
   0,0,0; no negative scale; normals facing out (recalculate outside if needed).
3. Export glTF 2.0, format "glTF Separate (.gltf + .bin + textures)", selected objects
   only, +Y Up ON, Apply Modifiers ON, materials exported, images Automatic, no cameras,
   no lights, no animation.
4. Save to <project>/assets/environment/custom/<asset_id>.gltf.
   Characters instead: format "glTF Binary (.glb)" with the armature and animations included
   (Animation ON) and Apply Modifiers OFF (see the note below), saved to
   <project>/assets/characters/custom/<asset_id>.glb.
   Never write into the KayKit folders (hexagons/, furniture/, characters/models/).
   Never overwrite an existing file. If the name exists, stop and ask. (The one exception
   is the atlas copy hexagons_medieval.png written next to it, which is identical every time.)
5. Report the files written and their sizes.
```

**Rigged characters: `export_apply=False`.** A skinned body exports with Apply Modifiers off. Its
non-Armature modifiers are applied in Blender before the join (the character spec in §1, "The
body"), so its only modifier left is the Armature, which the exporter writes as the skin. The
settings used for the route RL and AN bodies, with only `Rig`, `<Role>_Body` and its props selected, in an
MCP call of its own (never open a file and export in the same call):

```python
bpy.ops.export_scene.gltf(filepath="<project>/assets/characters/custom/<id>.glb",
                          use_selection=True, export_apply=False, export_skins=True,
                          export_animations=True, export_yup=True)
```

For a character, step 2's "apply all transforms" means `Rig` and `<Role>_Body` at scale 1.0 with
the rig's root at 0,0,0. Then set the import keys in the character spec ("Export"), and reimport.

### 6.5 Stage D: check it in Godot

- **Where to test:**
  - **Quick check first: `scenes/dev/LookDev.tscn`.**
    - Set `subject_scene` to the exported file and pick a preset (`tavern`, or `map` with `map_ortho_size` about 8 for a single hex).
    - Run it with `"E:/Godot installer/Godot_v4.4.1-stable_win64.exe" -d --path "F:/GAME I AM MAKING/shiningsun" res://scenes/dev/LookDev.tscn`.
    - It uses the same half-res SubViewport, camera basis, edge shader and lights as the tavern, with KayKit scale references and two proof objects beside the subject.
    - It quits itself after 240 s so SaveSystem's autosave can't overwrite your save.
    - The in-scene checks below are still mandatory for the final pass.
  - Landmarks: temporarily add the path to `ZONE_BUILDINGS` in `HexMapGenerator.gd` and run
    `HexMapTest.tscn`.
  - The tavern: place it next to `building_tavern_blue2` in `ExteriorWorld.tscn`.
  - Interior pieces: place them next to the box they replace in `MainTavern.tscn`.
- **Judge it under the real shader and camera**, not in the editor viewport.
- **It passes if all five hold:**
  1. Its scale looks right next to KayKit.
  2. Its colours sit inside the KayKit palette.
  3. Outlines draw the same way as on KayKit models.
  4. The silhouette reads at game zoom.
  5. Its triangle count is within budget.
- **Characters (routes RL and AN): the character variant** (Story 25.30's Stage D, used for every
  RL body in 25.31). For a character, the six criteria below replace the five above, whose criteria
  2 and 3 compare with KayKit. For an RL body read "top 1.50–2.25 m", "headwear, beards and coats"
  for criterion 3, and "the face reads in the portrait framing" for criterion 4 (a realistic head is
  about 11 px at zoom 12); the concept pick goes on the sheet beside the 3D turnaround.
  - **Where to test:**
    - **LookDev:** instance the character's own scene so the shipped load path applies the look (the
      dealer: `res://scenes/game/QuestDealer.tscn` with `hired_at_start_override = 1` and autopilot
      off). Show it beside the KayKit Knight and the body it replaces, in its clips; seated clips on
      a 0.44 m proxy stool behind a 0.85 m proxy desk. LookDev's "tavern" preset follows the hall's
      configured mood (`tavern_light_mood`; Story 25.23): its ambient, the sun as an ink-only light
      when the mood takes it off the hall, the fills. "today" changes nothing.
    - **MainTavern at zoom 12 and zoom 8,** set through the camera's `target_zoom`: the character at
      its job, next to the player, Den Fa and the patrons, in the picked mood (and the fire out, the
      worst case). The dev keys F6 / F7 / F8 cycle the mood, the phase and the shading preset
      (debug builds), or `TavernLighting.set_mood()` / `set_phase()` by eval.
    - **A portrait framing:** the driver's own ortho Camera3D, about 1 m, on the head, under the
      tavern lights. It is judged, not shipped: the portraits are 25.17's.
    - **The crowd check** (for a new kind of body, or a budget change):
      - Clones are raw instances of the GLB, each passed through `anime_look.apply`, each looping
        Idle or Walking_A from a staggered start time (static bodies skip skinning), on free hall
        floor. Never duplicate a staff node: a copy binds to the same desk, stool and GuildBus.
        On one clone, confirm that the VISIBLE draw calls rise by 2 per surface.
      - Fill the hall to 24 bodies, counting the ones already there; record 22 as well.
      - In its own eval, turn on `RenderingServer.viewport_set_measure_render_time` for the
        SubViewport and the root viewport, and turn V-Sync off (a capped GPU downclocks).
      - In later evals (the counters read 0 for the first 2 frames), average over ≥ 120 frames: the
        SubViewport's VISIBLE and SHADOW draw calls, the GPU and CPU render times summed over both
        viewports (plus the frame setup CPU time), and the uncapped fps. Measure in "today" and in
        the picked mood; SHADOW counts every shadowed light's views (take one sample with each
        shadowed light off: its own share). Start the accumulation in one short eval and poll it
        (the TCP server keeps one client, and a long eval's reply can be lost; 25.23).
      - Take the baseline in the same run with the clones freed. Free the clones and restore V-Sync
        in their own eval.
      - It passes if, at 24 bodies, the larger of the GPU and CPU render times is ≤ 8.3 ms. The
        budgets (hall and town) and the measurements are in the RL character spec's "Budgets".
    - Keep each run under 4 minutes (the autosave), and grep the run log after every driven E.
  - **It passes if all six hold:**
    1. Scale and height read right beside the Knight and the body it replaces (top ≤ 2.25 m).
    2. The silhouette reads at zoom 12.
    3. Hair clumps, ears, headwear (the dealer's circlet) and the costume's trims still read at half
       resolution at zoom 12.
    4. The eyes show at zoom 8. Faces proper are judged in the portrait framing.
    5. Two toon tones plus the ink outline: no alpha artefacts, no z-fighting or gaps from the
       outline hull, and it works with the edge shader.
    6. Tris and surfaces are within budget, and the crowd check passes.
  - Colours are demo-grade: note the palette, but it isn't a gate. Mark each shot keep or redo.
    Raphael's verdict on the result shots closes Stage D.
- **If it fails twice, stop** (§0 rule 4).
- Keep a screenshot for your records using the TCP method in `MCP_SETUP.md`.

---

## 7. Not covered here (separate, scoped tasks, per `04_PROCESS.md`)

- **Landmarks tied to missions:** make `HexMapGenerator.gd` place a landmark by the mission types
  that hex offers, instead of picking one from `ZONE_BUILDINGS` at random.
- **Swapping scene nodes:** one scoped prompt per asset for `MainTavern.tscn` / `ExteriorWorld.tscn`,
  after the asset passes Stage D.
- **Seats from the scene:** today patrons sit at 4 hard-coded `table_positions` in
  `scripts/npcs/PatronSpawner.gd`. Once stools with a `seat_point` are in the tavern, have the
  spawner collect seats from the scene (for example a `patron_seat` group) and keep the hard-coded
  list as a fallback. That's game code, so recon first per `04_PROCESS.md`.
- **Licences and disclosure:**
  - Check each generator's commercial terms before anything ships.
  - Assets from Poly Pizza or Sketchfab: note the licence (CC-BY needs a credit in the README).
  - Steam asks you to disclose AI-generated content, so keep the log below up to date.

---

## 8. Asset log (keep this filled in)

The n8n pipeline logs every generated image automatically in `<art>/generated/catalog.csv`.
This table tracks each finished asset.

| Asset | Route | Generator / source | Date | Status |
|---|---|---|---|---|
| K1 Tavern exterior key art | A | Nano Banana (gemini-2.5-flash-image) via n8n, commission as ref | 2026-09-24 | picked: inked v1 |
| K2 Interior key art | A | Nano Banana via n8n, commission as ref | 2026-09-24 | picked: S2 v1 (inked) |
| K3 World map key art | A | Nano Banana via n8n, commission as ref | 2026-09-24 | picked: inked v1 |
| D1 Prior Ruins (gate) | 1 | Claude via Blender MCP (scripted build, §6.3 atlas remap, §6.4 export) | 2026-09-24 | **in game**: Stage D passed (LookDev + HexMapTest); 1,956 tris; runes emissive at roughness 0 |
| B9 Tavern room shell (10-piece kit with B10) | — | Claude via Blender MCP (scripted kit on a 2 m module, §6.3 atlas remap with one kit-wide 4 m height scale, §6.4 export) | 2026-09-24 | **in game** (MainTavern): Stage D passed (LookDev corner + in-scene); 28–376 tris a piece |
| B10 Front door (frame + leaf) | — | same kit as B9 | 2026-09-24 | **in game**: leaves swing out on a trigger (`front_door.gd`); frame 144, leaf 84 tris |
| A1 + A2 Guild Tavern | 1 | Claude via Blender MCP (one parametric script; A2 = its mini LOD), §6.3 remap, §6.4 export | 2026-09-25 | **in game**: Stage D passed (LookDev + ExteriorWorld + HexMapTest); A1 4,568 tris, A2 996; windows emissive at roughness 0 (dark base + amber, not white) |
| C9 Home marker | — | same script as A1/A2 | 2026-09-25 | **in game**: guild banner with the hourglass emblem on the tavern hex; 116 tris |
| B6 Hourglass Pillar | 1 | Claude via Blender MCP (parametric stacked segments, octagonal lofts, emissive rune glyphs), §6.3 remap | 2026-09-25 | **in game**: Stage D passed (LookDev stages 0–4 + MainTavern); 2,480 tris; runes/sand/glass emissive teal at roughness 0 with a dark base; placed ×1.4 (the card's 3.5 m read too slender in the round bar) |
| A6 Exterior terrain (hill, path, stream) + bridge | — | Claude via Blender MCP (height-function mesh, atlas faces, creased ramp for ink outlines) + a scripted scene layout | 2026-09-25 | **in game** (ExteriorWorld): terrain 16,232 tris, trimesh collision; bridge 840 tris, walkable deck. Village and forest laid out from KayKit |
| B1 Hearth + H3 firewood | 1 | Claude via Blender MCP (parametric stone courses clipped round the arched firebox, stepped chimney breast, markers + convex collision proxies), §6.3 remap | 2026-09-25 | **in game**: Stage D passed (LookDev four fire states + MainTavern TCP run); B1 2,660 tris, H3 log 24 / bundle 172; stone on `stone_warm` (`stone_light` read slate blue); ember bed, candle flames and Prior runes emissive at roughness 0; the fire itself is particles + light driven by `hearth.gd` |
| B2 Round bar + stools, B12 back-bar island, H1 tankard | 1 | Claude via Blender MCP (parametric ring wedges via convex hulls, rune glyphs on the panels, trimesh collision proxies), §6.3 remap | 2026-09-25 | **in game**: Stage D passed (MainTavern TCP run: patrons sit on the stools facing the bar, the player serves, full then empty tankard in hand); B2 3,540 tris, stool 124, B12 2,558, tankard 112/118; ring 6.2 m across (the card's 4.5 m left no walkway round the ×1.4 pillar); base panels on atlas (1, 7) because `wood_dark` barely differs from `wood_light`; the held tankard is drawn 1.8× so it reads |
| B3 Guild desk + B4 Mission board | 2 | Claude via Blender MCP (parametric desk with dressing and a U-shaped trimesh collider; board with separate notice objects), §6.3 remap | 2026-09-25 | **in game**: Stage D passed (LookDev boards at 0 / 3 / 8 notices + MainTavern TCP run: both prompts, E opens the hire pool and the world map, a dispatch takes a notice down); B3 458 tris, B4 1,180; candle flames emissive at roughness 0; the board shows one notice per open contract |
| G5 Healer + G7 Ranger | RS | Claude via Blender MCP: outfit variants on KayKit bodies (Mage atlas recoloured cream-white with a hood, tabard, satchel and crystal staff; Rogue_Hooded atlas recoloured forest green with a longbow and a quiver), props on item bones, GLB with `export_apply=False` | 2026-09-25 | **in game**: Stage D passed (LookDev six-class lineup walking and sitting; MainTavern: a Healer and a Ranger patron seated and served, the roster shows the portraits); healer 6,285 tris, ranger 4,369; all 76 KayKit clips; the crystal is emissive at roughness 0 |
| G19 + G24 Townsfolk kit (farmer, local, traveller, guard, merchant, old woman) | RS | Claude via Blender MCP: one kit file and one rig (the Rogue, Mage, Knight, Barbarian and Rogue_Hooded parts re-bound after an exact rest-pose check), per-variant recoloured atlases, new lathe-built hats and small pieces, one GLB per variant | 2026-09-25 | **in game**: Stage D passed (LookDev six walking and sitting; MainTavern: a guard, a merchant and the old woman seated and served, chatter matching their origin; ExteriorWorld: six villagers at posts and on loops, barks overheard); 4,169–6,221 tris, all 76 KayKit clips, hands free except the old woman's cane |
| G11 The Cat + B20 her basket | R1 | Claude via Blender MCP: a scripted build from primitives (charcoal fur, white socks, chest and muzzle, pale green eyes) on her own 22-bone rig, four keyframed clips (Sleep, Idle, Walk, and Pet, a one-shot); the basket from the tavern atlas (wicker bands, a red cushion) | 2026-09-25 | **in game**: Stage D passed (MainTavern: asleep in the basket by the hearth, the prompt beside her, E plays Pet with "prrr…" or an "mrrp.", then back to sleep; ExteriorWorld: her stroll by the stall and the barrel, which a pet pauses and resumes); 1,310 tris (basket 298) |
| G9 Den Fa, the Architect | R1 + custom rig | Claude via Blender MCP: a scripted build from primitives on his own 42-bone rig (d_-prefixed; ears, mask and three bones per wing for Story 26.11), six keyframed clips (Idle, Sit, Walk loop; Point, StandUp, SitDown once); the Sit pose solved against the hearth's bench, wall and chimney | 2026-09-25 | **in game**: Stage D passed (LookDev beside the Knight in Idle, Walk, Point and Sit; MainTavern: seated by the lit fire, the mirror mask reflecting the hall through the new HearthProbe, "Press E - Talk to Den Fa" with a placeholder line, E going to the nearest of him, the cat and the fire, the walk to the bar, the point at the pillar, the walk back; the other tavern zones and the town unchanged); 2,546 tris, 2.91 m to the ear tips |
| G9 Den Fa, realistic (no wings, R-8) | RL + custom rig | Claude via Blender MCP: `tools/blender/realistic/den_fa/` (Story 25.32): his 25.10 rig minus the 12 wing bones (30 `d_` bones; rest and clips proved identical to the recorded 25.10 file), a body on route RL's helpers from his pick `C_G9_den_fa.png` (the worn #26587e coat with lapped skirt halves and a back vent, gloves, knee-high boots, the dark skull, the bat ears, the mirror mask shell), one painted atlas; checks: world clearance, the 10-log sightline, self-clips (a)–(c), each proved on a bad pose | 2026-10-04 | **in game, Stage D verdict pending** (v6 2026-10-04 after Raphael's v5 verdict "The shoulders are not broad enough. The legs are too slim.": broader shoulders (span 0.74 m, v5 0.67; capped by the chimney face when he sits) and chunkier legs, the same rig and clips: `g9_den_fa_real_v6.glb`, sheet `<art>/shots/den_fa/25-32_denfa_sheet_v6.png`; v5's sheet `<art>/shots/den_fa/25-32_denfa_sheet.png`: LookDev beside the Knight, REAL-1, REAL-2 and his old body; MainTavern seated with 10 logs, E at the fire / the cat / him, the dialogue box with his new portrait, the walk, the point, the return); v6 6,076 tris (v5 6,020), 2 surfaces, 1 texture, 2.91 m; 3 draw calls in the hall (the old body 9) |
| G12 The Bartender | RS | Claude via Blender MCP: the Barbarian body as a burly barkeep (bald, a grey beard, rolled sleeves, a knee-length apron, a belt cloth), recoloured by atlas cell, in `g12_g13_staff.blend` (a save-as of the townsfolk kit); five IK-posed clips (Walk_Bar, Wipe, Serve, Pour, Restock) checked for clearance against the counter, the shelf and the kegs | 2026-09-26 | **in game**: Stage D passed (LookDev beside the Knight in every state; MainTavern: wiping at a serve point with patrons seated, serve_toward = pour at the taps then serve at the nearest station with drink_handed, restock at beer 0, fired and re-hired through GuildBus with the front door held open as he passes); 4,473 tris, 83 clips |
| G13 The Quest Dealer | RS | Claude via Blender MCP: the Mage body with the Rogue head as a silver-haired elf woman after Raphael's reference (ears, long hair, a gold circlet with a red gem, a high collar with gold trim, a plum coat, a quill on `handslot.r`), in the same file; Write and Brief clips (IK) at the guild desk B3 | 2026-09-26 | **in game**: Stage D passed (LookDev on a proxy stool and desk; MainTavern: writing at the desk at load, the stool pulled out and the shuffle in on arrival, AVAILABLE with the player at the desk front, BRIEFING with a bark while E's RecruitmentPopup is open); 4,815 tris, 83 clips; since 2026-09-27 the fallback body of the anime G13 below (`silver_elf.fallback_model_path`) |
| G13 The Quest Dealer (anime) | AN | Claude via Blender MCP, route AN (`tools/blender/anime/`): the shared base `anime_base.blend` (the KayKit rig stretched to the §1 bone table, its 76 clips retargeted with the sits re-fitted to the 0.44 m seats), then her body after Raphael's silver-haired elf and the approved anime test (long platinum hair, elf ears, a gold circlet with a red gem, painted teal eyes, a high-collared plum coat with gold trim); one `Dealer_Body` (face + palette) and `Dealer_Quill` on `handslot.r`; Walk_Bar, Write and Brief re-posed by IK; desk, stool and self-clip clearance checked; `g13_quest_dealer_anime.glb`, a new file | 2026-09-27 | **in game** (`staff.json` `silver_elf`, `look: "anime"`): Stage D shots all kept against the six character criteria (§6.5: LookDev beside the Knight and the 25.13 dealer; MainTavern at zoom 12 and 8: writing at load, fire and re-hire, AVAILABLE, BRIEFING with a bark; the portrait framing; the zones walk; the crowd check at 24 bodies, 193 draws, 0.368 ms); 9,459 tris with the quill, 2 surfaces, 79 clips, 2.138 m; outline 0.011 (the approved test's); since 2026-10-04 (R-2, Q3) her re-export with the face-seam fix, `g13_quest_dealer_anime_v2.glb`, is the realistic dealer's fallback body |
| P9 Dialogue portraits: Den Fa, the Quest Dealer, the Bartender | — | Claude: in-engine renders by the portrait studio (`scenes/dev/PortraitStudio.tscn`, Story 25.17) from each body's `portrait_source` in `speakers.json`: the game's look (tavern ambient, edge-pass ink at `linePixels` 4, anime_look on the dealer), an omni key in front of the face, an ink light from behind, a warm backdrop, a mirror sky for Den Fa's mask; one bust rule (2.6 head heights, eyes 43% down, yaw −30°) | 2026-10-03 | **in game** (the dialogue box): 512 × 512 PNGs, lossless with mipmaps; the box draws them at 160 with mipmaps; Stage D sheet `<art>/shots/portraits/25-17_sheet.png` (Raphael's verdict 2026-10-03: "Good as they are", the faces turned toward the text). A new PNG's import: `mipmaps/generate=true`, `detect_3d/compress_to=0`. Re-rendered 2026-10-04 (25.31 S1): the Bartender and the Quest Dealer from their realistic bodies (cameras re-tuned in `speakers.json`); still to come: Den Fa after 25.32, the Elder and the Bard in 25.11 / 25.12 |
| G12 The Bartender (realistic) | RL | Claude via Blender MCP, route RL (`tools/blender/realistic/real_bartender.py`, `real_bar.py`) on REAL-1, from the spike (`5ae8dc0`) and his pick: burly, bald, grey beard, wine-red shirt with rolled sleeves, a knee-length leather apron with folds, the belt cloth and the hand cloth (props); production hands; the head projected from his pick and baked seamless; his five bar clips re-posed on his reach; the bar clearances re-measured (serve stand r 1.76 → 1.92) | 2026-10-04 | **in game** (`staff.json` `barkeep`, `look: "realistic"`, fallback the 25.13 g12): `g12_bartender_real.glb`, 9,082 tris, 2 surfaces, 81 clips, 1.86 m; Stage D sheet `<art>/shots/staff/real/25-31_s1_sheet.png` (Raphael's verdict pending) |
| G1 The player | RL | Claude via Blender MCP (`real_player.py`) on REAL-1, from his pick: one man (AH-1), a weathered retired adventurer: hair shell, short beard, a long open coat with a back vent, vest, belt, patched trousers, cuffed boots; the sword sheathed at his hip (a worn prop) | 2026-10-04 | **in game** (`data/characters/player.json`, `player.gd` from data, fallback the KayKit Rogue): `g1_player_real.glb`, 9,180 tris, 2 surfaces, 76 clips; Running_A at 0.715 (V9); same sheet |
| G13 The Quest Dealer (realistic) | RL | Claude via Blender MCP (`real_dealer.py`) on REAL-2, from her pick (R-2): the silver-haired elf, long ears, the slim circlet, the plum coat with gold trim over dark trousers; the quill a prop shown only while she writes; Walk_Bar, Write and Brief re-posed; the desk report re-measured (hip_back 0.45) | 2026-10-04 | **in game** (`silver_elf`, `look: "realistic"`, fallback the anime v2): `g13_quest_dealer_real.glb`, 9,156 tris, 2 surfaces, 79 clips, 1.72 m; seated shoulders 1.034 (desk height: Raphael's call); same sheet |
| B2 Tall bar stool | — | Claude, pure Python (`tools/props/make_tall_stool.py`) from the 25.6 stool's design and atlas cells | 2026-10-04 | **in game** (`BarStool.tscn`): `b2_bar_stool_tall.gltf`, seat 0.72, a foot ring and a footrest at 0.27 (R-5); 124 tris; the 25.6 stool untouched |
| G19 + G24 Townsfolk (realistic: farmer, local, traveller, guard, merchant, old woman) | RL | Claude via Blender MCP (`real_townsfolk.py`, `real_townsfolk_paint.py`), one `.blend` and one GLB each, from their picks; five men on REAL-1, the old woman on REAL-2; hats built round the shaped heads (straw, cap, beret, the guard's morion: AH-9); Idle, Walking_A, a jog for Running_A | 2026-10-04 | **in game** (townsfolk.json, `look: "realistic"`, fallbacks the 25.14 GLBs): patrons in the hall and villagers in the town; 6,522–9,530 tris, 2 surfaces, 76 clips each; hands empty (the old woman's cane a hidden prop); Stage D sheet `<art>/shots/staff/real/25-31_s2_sheet.png` (verdict pending) |
| G2–G7 Class bodies (realistic: Fighter, Rogue, Mage, Healer, Barbarian, Ranger) | RL | Claude via Blender MCP (`real_classes.py`, `real_classes_paint.py`), one `.blend` and one GLB each, from their picks; Fighter, Mage, Barbarian on REAL-1, Rogue, Healer, Ranger on REAL-2; carried items as hidden hand props (R-9), worn gear visible; the Healer's crystal glows as a prop (AH-3); the robes clear of the thighs (check (b)) | 2026-10-04 | **in game** as the adventurer patrons (townsfolk.json) and in classes.json (`look: "realistic"`, fallbacks the KayKit / 25.9 bodies): 7,600–9,056 tris, 2 surfaces, 76 clips each; Stage D sheet `<art>/shots/staff/real/25-31_s3_sheet.png` (verdict pending). The 25.28 inked reskins were folded into this |
| D2 Demon Cult Crypt | 1 | | | concept picked (crypt v2) |
| D3 Dragon's Lair | 1 (+2) | | | Batch 2 |
