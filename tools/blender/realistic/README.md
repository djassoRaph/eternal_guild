# Route RL — the realistic character pipeline (Story 25.31)

The cast's route since the 2026-10-04 correct course (sprint-change-proposal-2026-10-04.md, R-1): realistic adult
bodies on the KayKit skeleton (all 41 joints, the 76 clips kept), built in Blender 4.5 through the Blender MCP server.
Route RL runs route AN's generic chain (`tools/blender/anime/`, read its README first) from its own chain configs;
route AN stays for the anime Quest Dealer, her fallback body. Art-side files live in
`F:/GAME I AM MAKING/eternal_guild_art/` (`<art>`; not under git); these scripts are the versioned source of truth.

## The two bases

| Base | File | Who | Rig |
|---|---|---|---|
| REAL-1 | `<art>/blender/realistic_base.blend` | the men (the player, the Bartender, the Fighter, the Mage, the Barbarian, most townsfolk) | 1.86 m, ~7.35 heads, leg ratio 2.154 (from the spike's concept sheet) |
| REAL-2 | `<art>/blender/realistic_base_w.blend` | the women (the Quest Dealer, the Rogue, the Healer, the Ranger, the old woman) | 1.70 m, REAL-1's heights scaled about KayKit's ankle (K2 = 0.9067), shoulders 0.170 off the midline, hips 0.095, hands x 0.92; leg ratio 1.953 |

Both: the sit clips re-fitted for the 0.45 m table chairs (R-5: the bar stools get a foot ring at seat - 0.45), the
76-clip foot report stamped, one arm pass on the game clips. A base's files sit beside it: `<stem>_kaykit_feet.json`,
`_kaykit_sit.json`, `_kaykit_rest.json` (KayKit's own data, recorded in step 1b), `_foot_report.json`,
`_arm_src.json` (the arm pass's source); REAL-1 also has `realistic_base_rig_rest.json` (its rest; REAL-2's v1 body was
built on it).

**The neutral bodies (v2, 2026-10-04).** Each base's `Base_Body` is a clothing-less mannequin built straight on its rig
from the chain's `body` params (`real_chain.MAN` / `WOMAN`, every height in that rig's metres): REAL-1 an average man
(flat stomach; hips 0.181, waist 0.160, chest 0.186 half-widths; the spike's boots, so its foot report holds); REAL-2 a
woman (v3: hips 0.165 (0.170 at the thighs), waist 0.120, ribs 0.153 half-widths, a full, round bust (two domes,
`real_body.bust_dome`), a high-cut hip line, slimmer arms and legs, hands x 0.86, the head
x 0.93 with a narrower jaw and softer brow, a slender neck, smaller ankle boots). The v1 bodies were the spike
Bartender's (shirt and beer belly; REAL-2 that body reshaped) and read as men. Girth and a belly are a character's own
params (`belly`, `trunk_scale`), never a base's.

## Running

One step per MCP call; the exec namespace does not persist, so every call starts with:

```python
import sys
for T in (r"F:\GAME I AM MAKING\shiningsun\tools\blender\anime", r"F:\GAME I AM MAKING\shiningsun\tools\blender\realistic"):
    if T not in sys.path:
        sys.path.insert(0, T)
for n in [n for n in sys.modules if n.startswith(("anime_", "real_"))]:
    del sys.modules[n]
import anime_common as C, real_chain as RC                # ... and the modules the step uses
```

A file load (`open_mainfile`, `open_kit`, `open_base_as`) leaves a stale context: the step after it goes in its own
call. Never open a file and export in the same call. Save after each step that changes the base
(`bpy.ops.wm.save_mainfile()`); `finish` saves itself.

## Chain configs (no patching)

`real_chain.REAL_1` and `real_chain.REAL_2` are chain dicts like `anime_common.AN`: the base's files, the rest-pose
`table` (+ `knee_z`, `palm`, `hand_scale`), the rig stamps, `seat_y` 0.45, the `arm_pass` parameters, and for REAL-2
the `base_body` recipe (built on REAL-1's recorded rest, carried over). Every generic step takes the chain
(`anime_base_build.open_kit/finish(chain)`, `anime_rig.run(chain=)`, `anime_retarget.refit_sit/foot_report(chain=)`,
`anime_common.open_base_as(path, chain=)`) or finds it by the rig's stamp (`anime_common.chain_of`: importing
`real_chain` registers REAL-1 and REAL-2). A step writes only its chain's files; `foot_report` writes the chain's JSON
only when the open file is that chain's base. `anime_common.scratch_chain(chain, folder, prefix)` points a whole base
rebuild at scratch files (the regression rebuild of the AN base, 25.31 S1.0).

## The chain

| Step | Call | What it does |
|---|---|---|
| 1a | `RC.open_kit(ch)` | the untouched KayKit kit saved as the base (refuses an existing base) |
| 1b | `RC.finish(ch)` | KayKit's leg lengths, its feet on every frame of the 76 clips and its sit clips recorded; stripped to `Rig` + the 76 actions; saved |
| 2 | `RC.rig(ch)` | the rest pose to the chain's table (directions and rolls kept; the handslot at the palm); stamped `anime_rig` = `real_rig` = REAL-1 / REAL-2 |
| — | `RC.record_rest(RC.REAL_1)` | REAL-1 only, once: its rest -> `realistic_base_rig_rest.json` (refuses a different record) |
| 3 | `RC.base_body(ch)` | `Base_Body`, the neutral mannequin (never exported): `real_body.build_neutral(ch["body"])` on the open rig (a pchip-lofted trunk with the bust / belly, a neck, the analytic head scaled onto the head bone, one tube per arm and leg, the hands, `build_boot(boot=)`); repeatable. After it, re-run 5 and 7 (and 6 when the boots changed) |
| 4 | `RC.ratio(ch)` | hips + root location keys x the leg ratio; never run twice |
| 5 | `RC.sit(ch)` | `refit_sit("Base_Body")` for the 0.45 m seat (iterated to < 0.002), prints `SIT_HIPS_Y`; repeatable |
| 6 | `RC.feet(ch)` | the 76-clip foot report + contact correction, stamped `anime_foot_report` |
| 7 | `RC.arms(ch)` | `real_arms.run`: the arm pass (below), stamped `real_arm_pass` per clip; repeatable |
| 8 | `RC.open_base_as(path, ch)` | the base saved as a character's file; refuses a base missing any stamp (rig, ratio, the sit at 0.45, the foot report, the arm pass), the base's own path, and an existing file unless `overwrite_ok=True` |

Then the character (S1 on): its parts from `real_body` (and the AN kit's garments, hats with `head_radius_at`, hair
presets), its two textures from `real_paint`, `anime_merge.join/check`, its own clips through `anime_anims` (the 25.13
method), `anime_clearcheck`, and a manual glTF export to a NEW file name (N5). A character whose seat thickness differs
from its base's by more than 0.03 m runs `anime_retarget.refit_sit("<Role>_Body")` in its own file.

**Changing a table** means rebuilding that base from the untouched kit (steps 1a–7). Never re-run the ratio step on a
retargeted base, and never scale a character file's clips in place.

## The arm pass (`real_arms.py`)

KayKit's clips hold the arms 35–60° out from a chibi body. Once per base, for Idle, Walking_A, Running_A, the three
Sit_Chair clips, Cheer and Interact, every key frame's upper arm turns toward the body about the chest's front-back
axis through the shoulder, so the forward/back swing, the height and the elbow bend stay KayKit's. It stops `gap`
(0.03 m) outside the base's `Base_Body` beside the forearm, hand and elbow (posed in that frame), never more than
45° per frame, never past 0.06 m off the midline in front of the belly, and leaves raised hands alone (Cheer). Only
the `upperarm.l/.r` rotation channels are rewritten; the source arms are recorded once (`<stem>_arm_src.json`), so a
re-run starts from them. `real_arms.report(ch)` re-measures the clearance per clip. A body much wider than its base
(the Bartender's belly) checks its own arms in its file. The other KayKit clips (Lie, Death, Jump, Dodge) are judged
on screen before use.

## Faces and textures (`real_layout.py`, `real_paint.py`)

- A concept **sheet** (`real_layout.make_sheet(concept_png, height, views, head_crops)`; `save_sheet` / `load_sheet`
  as JSON): per view (front, side, back) the centre column and the crown and sole rows (each view's own m/px), and
  the head texture's crop boxes (one quadrant per view). Measure it off the picked concept (`<art>/picked/C_<id>.png`).
  `real_layout.BARTENDER` is the spike's.
- The head material: `real_body.projection_uvs(bm, sheet=)` gives each face the view its normal faces most and projects
  its corners onto that view's pixels; `build_head/beard/ears/neck(..., sheet=)` pass it through.
  `real_paint.head_texture(out, sheet)` (or `python real_paint.py head <out.png> --sheet <sheet.json>`) cuts the crops,
  floods the sheet's grey away with its silhouette ink, bleeds the drawing outward and upscales each into its quadrant.
- The body atlas: `real_paint.body_texture(out, painters=, palette=)` paints each `(region, wrap_u, wrap_v, painter)`
  over `real_layout.REG` (a wrapping ring is painted periodic); `BARTENDER_PAINTERS` is the spike's; `palette`
  overrides `real_layout.PALETTE`'s colours. Two textures per body at <= 1024², mipmaps on (AH-15).
- The spike's PNGs (`<art>/textures/realistic/g12_bartender_realtest_*.png`) repaint pixel-identical through these
  functions (25.31 S1.0).
- **Sheet options (25.31 S1):** `side_flip` (the side view shows his RIGHT side, front image-right: the player's and
  the dealer's picks); `crown_rows` (never sample above the drawn crown: the bleed is streaked there); `top_from_back`
  (faces looking up, above `z_min`, take the back view's hair laid flat: no view sees a crown); `face_y` (how far back
  the front view keeps the cheeks). A sheet's side view may be drawn at another scale than its front: register it by
  its crown row so the eye lines meet (the player's: 22.3).
- **The painted head pass (`real_bake.bake_head`, 25.31 S1):** the projection gives each face ONE view, so the front
  and side drawings meet in a step (a jagged beard, a second brow). After `build()` (its own call), `paint_head()`
  bakes the head material into the head faces' own unwrap with the views blended by the normal (`w = max(0, n.v)^4`,
  the front weighted up on the face), Cycles EMIT, 1024²; the result (`<id>_headpaint.png`) is the shipped head
  texture. A bake writes into the active image node of EVERY material on the object: the other slots get a throwaway
  node during the bake (else the body atlas's pixels in memory are overwritten and exported). Re-run it after every
  `build()` with `paint_head(overwrite_ok=True)` (it refuses an existing PNG otherwise). It is re-runnable: the
  projection reads the concept crops recorded on the head material at the first bake (`real_bake_src`), never the
  material's current image (the bake itself after one run); a head baked before that record refuses until `build()`
  re-points it. The mesh is stamped `real_head_bake`; the helper UV layers and Cycles' settings are undone in a
  `finally`.
- **Export (25.31 review P1):** every role's `export(..., overwrite_ok=False)` goes through `real_chain.export_glb`:
  it refuses an existing GLB unless `overwrite_ok=True` (N5: the shipped GLBs are live paths), saves, drops the
  `SRC_*` clip sources, exports, and reverts the file in a `finally`.

## The S1 characters (25.31)

| Character | Module | Base | File / GLB | Notes |
|---|---|---|---|---|
| G12 the Bartender | `real_bartender.py` (+ `real_bar.py`) | REAL-1 | `g12_bartender_real.blend` / `custom/g12_bartender_real.glb` | the spike's body with `build_hand_real`, apron folds (`APRON_FOLDS`, `skirt_w` 0.75 / 0.35), his five bar clips; `real_bar.report` checks every clip at its stations against the 25.13 bar geometry with his body block's radii, `halves` gives the Walk_Bar half-widths |
| G1 the player | `real_player.py` | REAL-1 | `g1_player_real.blend` / `custom/g1_player_real.glb` | the Bartender's head x 0.88 / -0.02 m under a hair shell; the coat, vest, collar, lapels, skirt halves (a back vent); the sword a prop on hips; Idle re-posed; `arms_out` keeps Running_A's arms outside the coat; `rate()` measures Running_A's ground speed (player.json) |
| G13 the Quest Dealer | `real_dealer.py` | REAL-2 | `g13_quest_dealer_real.blend` / `custom/g13_quest_dealer_real.glb` | REAL-2's head (width 0.90, jaw 0.14), a hair cap and a long fall, elf ears, the circlet band; the buttoned coat over the bust (`bust_dome`); the quill a prop on handslot.r; her desk clips; `measure()` = anime_clearcheck's desk report with her config |

## The townsfolk (25.31 S2)

`real_townsfolk.py` (+ `real_townsfolk_paint.py` for the textures, system Python: `python real_townsfolk_paint.py
<id>|all [--overwrite]`) builds the six townsfolk from `<art>/picked/C_G19_<id>.png`: the farmer, the local, the
traveller, the guard and the merchant on REAL-1, the old woman on REAL-2. One module, one `.blend` and one GLB per
variant (V13: actions are file-global): `<art>/blender/g19_<id>_real.blend` -> `custom/g19_<id>_real.glb`. Steps (one
MCP call each): `open_base_as(id)`, `build(id)`, `paint_head(id)`, `build_clips(id)`, `measure(id)`, `export(id)`.

- Sheets: `real_layout.sheet_by_eyes` registers a pick on its EYE line (their crowns are under hats): per view the face
  midline / nose tip px, the eye row and the sole row (`real_layout.TOWNSFOLK_SHEETS`).
- Heads: the player's (x `HEAD_X` per face, -0.02 m); the old woman's REAL-2 head (`OLD_HEAD`). Hats are built round
  the shaped head (`build_hat`: straw, cap, beret, helmet) on the body atlas; her headscarf and bun are head-material
  shells (projected).
- Clips: Idle (hands by the clothes), Walking_A (`WALK_STRIDE`), Running_A as a jog (`JOG_STRIDE`, the sprint's lean
  halved: patrons run at 2.5 m/s), then `real_player.arms_out` (<= 6 deg) on Running_A, the sit clips, Cheer and
  Interact. Every rewritten clip starts from a recorded `SRC_*` copy (removed for the export): `build_clips` is repeatable.
- `measure` gives what townsfolk.json carries: Walking_A / Running_A ground speeds (the villagers' and patrons' playback
  rates, V9), the standing / seated head tops (bubbles), and the seat (V13: every body within 0.012 m of its base's, so
  no sit re-fit).
- R-9: hands empty; worn things on the body or a visible prop on hips (the merchant's purse); the old woman's cane is a
  prop on handslot.r that `RealisticPatron.dress_body` hides.

## The class bodies (25.31 S3)

`real_classes.py` (+ `real_classes_paint.py`, system Python: `python real_classes_paint.py <class>|all [--overwrite]
[--body-only]`) builds the six class bodies from `<art>/picked/C_G<n>_<class>.png`: the Fighter (G2), the Mage (G4) and
the Barbarian (G6) on REAL-1, the Rogue (G3), the Healer (G5) and the Ranger (G7) on REAL-2; one `.blend` and one GLB
each: `<art>/blender/g<n>_<class>_real.blend` -> `custom/g<n>_<class>_real.glb`. Steps (one MCP call each):
`open_base_as(V)`, `build(V)`, `build_clips(V)`, `build(V, props_only=True)` (the hand props aimed from the re-posed
Idle), `paint_head(V)`, `measure(V)` (+ `robe_check(V)` for the Mage and the Healer), `export(V)`. A later `build(V)`
keeps the clips; re-run `paint_head(V, overwrite_ok=True)` after it (and `export(V, overwrite_ok=True)` to replace a
shipped GLB).

- Sheets: `real_layout.CLASS_SHEETS` (eye-line registered); `_crops` widens the head windows for the Rogue's ponytail,
  the Healer's hood and the Barbarian's long beard (300 px). The Healer's hood is a head-material shell projected from
  her pick (its gold edge and folds are the drawing's); the Barbarian's hair fall and long beard too (his pick's axe is
  mirrored out of the back view: `real_classes_paint._barbarian_head`). The Ranger's hair and braid are body-atlas
  strands (her pick draws them under a hood in two views).
- R-9 (refined): EMPTY-HANDED bodies. Carried items are props on a hand slot, which the game hides (`RealisticPatron.
  dress_body`): the Fighter's sword (r) and shield (l), the Mage's staff, the Healer's crystal staff, the Barbarian's
  axe (r), the Ranger's bow (l). Worn gear is visible: the Rogue's sheathed daggers (a prop on hips), the Ranger's
  quiver (a prop on chest), satchels and straps on the body. Hand props are aimed from Idle's first frame
  (`slot_frame`: built in rest so the bone carries them).
- AH-3 / V5: the Healer's crystal is the staff's second material `RT_Healer_Crystal` (emissive green on a dark base,
  roughness 0); `anime_merge.check` (`emission_ok`) fails emission on a body material or one the body shares, and an
  emissive material above roughness 0. `anime_look.gd` keeps it emissive at roughness 0 without an outline.
- Long robes (Mage, Healer): skirt halves split at the front (`split_skirt`), the front following the thighs fully and
  high up (`legs` 1.0, h^0.22) with front ease, and below the knee handed over to the shins (`robe_w`, `shin` 1.0) so a
  seated robe hangs along the shins instead of standing out like a board. `robe_check` runs anime_clearcheck's check (b)
  with the RL regions (legs = "trousers", skirt = "apron"; proved on a bad pose first).
- Burly (AH-5): the Barbarian's jerkin is lofted on `burly_ring` (the neutral man x 1.13 / 1.10 + a belly), bare arms
  x 1.32 / 1.22 (`bare_arm`), `arms_out` up to 10 deg.

The bar stools (25.31 S2.0, R-5) are not a Blender build: `tools/props/make_tall_stool.py` writes
`b2_bar_stool_tall.gltf` (seat 0.72, the foot ring and footrest 0.45 m under it) from the 25.6 stool's design.

Their clips reuse `real_bartender`'s pose helpers (`stand_tall`, `reach`, `short_walk`; `_SOLES` set to the character's
own body before a build), each from the base's retargeted clips kept as `SRC_*` copies (removed for the export).

## Custom rigs: Den Fa and the Cat (25.32)

A character outside KayKit's 41-joint contract keeps its own rig and runs route RL's generic helpers with its own
weights and checks. Add `tools/blender/realistic/den_fa` (or `cat`) to the runner's `sys.path`; the module names start
with `real_`, so the fresh-import loop reloads them.

**Den Fa** (`den_fa/`, `<art>/blender/g9_den_fa_real.blend` -> `custom/g9_den_fa_real.glb`; R-8: no wings):

| Step | Call | What it does |
|---|---|---|
| 0 | `DA.record_shipped(DF.RECORD)` with the shipped `g9_den_fa.blend` OPEN (never saved) | 25.10's rest and actions -> `<art>/blender/g9_den_fa_25_10_record.json` |
| 1 | `DF.new_file()` | an empty file saved as `g9_den_fa_real.blend` (refuses an existing file) |
| 2 | `DF.build_rig()` | `DenFa_Rig`, the 30 `d_` bones (25.10's minus the 12 wing bones) |
| 3 | `DF.build_clips()` | the six clips from `real_den_fa_anims` (25.10's pose functions, the wing tuck dropped), stashed on muted NLA tracks; `compare()` proves the rest and every F-curve on the kept bones against the record (0.0 on 2026-10-04) |
| 4 | `python den_fa/real_den_fa_paint.py [--overwrite]` (system Python) | the body atlas over `real_layout.REG` (his garments in the boxes; the coat base #26587e under slate grime) |
| 5 | `DF.build()` | `DenFa_Body` (the parts joined; the rig in rest first) and `DF.check()`: RL budgets, metal only on `den_fa_mask` |
| 6 | `CK.proofs()` then `CK.clearance()`, `CK.log_hits("Sit", t)`, `CK.self_clips()`, `CK.numbers()` | each check reports on a bad pose first (asserted), then the clips: world clearance at `seat_root`, the 10-log sightline, self-clips (a)-(c); `numbers()` gives `MASK_SEATED` / `MASK_STANDING` / `BUBBLE_SEATED` for `den_fa.gd` |
| 7 | `DF.export(overwrite_ok=...)` | `DenFa_Rig` + `DenFa_Body` to the NEW GLB (refuses an existing one unless asked), save first, revert in a finally |

Then `--headless --import`, the `.glb.import` loops (`_subresources` animations) and `generate_lods=false`, and the
extracted PNG's `detect_3d/compress_to=0`. The coat's skirt is two halves lapping at the front (the right over the
left, the side placket) and at the back vent (the left over the right); below the hips both follow the thighs and,
below the knee, the shins: seated, only 0.17 m separate his thigh axis from the bench top, so the back stays within
0.15 m of the thighs. `CK.walk_route_clearance()` samples his walk off the seat (a finding: his walk to the bar
brushes the chimney corner with the 25.10 body too; logged in deferred-work). The mask is his own material
`den_fa_mask` (metallic 1.0, roughness 0.10, #d8dde3): `anime_look.gd` › `KEEP_AS_IMPORTED` leaves it as imported.

**The Cat** (`cat/`): planned in 25.32 from her concept pick (`C_G11_the_cat`); not built yet.

## Budgets (AH-15)

`RL_TRI_BUDGET` 10,000 per body with props (14,000 only with re-measured hall and town budgets); <= 3 surfaces on
`<Role>_Body`; <= 2 textures at <= 1024², mipmaps on; top 1.50–2.25 with headwear (the 2.30 m lintel rule). The 15
bodies: 6,522–9,530 tris, 2 surfaces, 2 textures each (120 MiB of textures for the cast). The hall (VISIBLE 196 at 24
bodies, 0.49 ms) and the first town budget (VISIBLE 200 / SHADOW 500 at 24 bodies under the 4-split sun, 0.78 ms) were
measured with the full cast at 25.31 T-end: 08 §1, "Budgets".

## Files

- `real_chain.py`: the REAL-1 / REAL-2 configs and the chain steps.
- `real_body.py`: the body parts (REAL-1's heights; the Bartender's shapes), the head projection, `rest_record`,
  `transfer_rest`, `build_neutral` (the bases' bodies) and `build_base` (the spike's body, superseded).
- `real_arms.py`: the arm pass and its clearance report.
- `real_layout.py`: concept sheets and the body atlas layout (pure Python).
- `real_paint.py`: the head and body textures (system Python: numpy + Pillow).
- `real_bartender.py`: the production Bartender (25.31 S1; the spike's test GLB and blend stay, commit 5ae8dc0) and
  the pose helpers the other characters reuse.
- `real_bar.py`: the Bartender's bar clearance and body numbers.
- `real_player.py`, `real_dealer.py`: the player and the Quest Dealer (25.31 S1).
- `real_townsfolk.py`, `real_townsfolk_paint.py`: the six townsfolk and their textures (25.31 S2).
- `real_classes.py`, `real_classes_paint.py`: the six class bodies and their textures (25.31 S3).
- `real_bake.py`: the painted head pass.
- `den_fa/real_den_fa.py`, `real_den_fa_anims.py`, `real_den_fa_check.py`, `real_den_fa_paint.py`: Den Fa on his own
  rig (25.32).
