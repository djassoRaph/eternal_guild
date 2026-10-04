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
`_arm_src.json` (the arm pass's source); REAL-1 also has `realistic_base_rig_rest.json` (its rest, REAL-2's source).

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
| 3 | `RC.base_body(ch)` | `Base_Body`, the neutral reference body (never exported): REAL-1 `real_body.build_base()`; REAL-2 the same parts built on REAL-1's recorded rest, carried onto REAL-2's (`transfer_rest`: each bone's length ratio along it, its girth across it), the trunk fitted to a woman's silhouette (`fit_profile`: hips, waist, shoulders, depth in front of / behind the spine line) and a bust (`add_bust`) |
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

## Budgets (AH-15)

`RL_TRI_BUDGET` 10,000 per body with props (14,000 only with re-measured hall and town budgets); <= 3 surfaces on
`<Role>_Body`; <= 2 textures at <= 1024², mipmaps on; top 1.50–2.25 with headwear (the 2.30 m lintel rule).

## Files

- `real_chain.py`: the REAL-1 / REAL-2 configs and the chain steps.
- `real_body.py`: the body parts (REAL-1's heights; the Bartender's shapes), the head projection, `rest_record`,
  `transfer_rest`, `fit_profile`, `add_bust`, `build_base`.
- `real_arms.py`: the arm pass and its clearance report.
- `real_layout.py`: concept sheets and the body atlas layout (pure Python).
- `real_paint.py`: the head and body textures (system Python: numpy + Pillow).
- `real_bartender.py`: the 2026-10-04 spike's Bartender (a test, `custom/tests/g12_bartender_realtest.glb`); S1
  promotes it onto the finished REAL-1 base.
