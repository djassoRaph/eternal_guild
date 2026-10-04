# Route AN — the anime character pipeline (Stories 25.30, 25.31)

The scripts that build every anime (AN) character of the demo cast in Blender 4.5, and the ones paid artists re-run
after the Kickstarter. The art-side files live in `F:/GAME I AM MAKING/eternal_guild_art/` (`<art>`; not under git);
these scripts are the versioned source of truth. The character spec (proportions, rig and clip contract, budgets,
materials and ink, export, data) is `documentation/design/08_ASSET_PROMPT_PACK.md`.

## Running them

Through the Blender MCP server (`mcp__blender__execute_blender_code`), one step per call; the exec namespace does not
persist, so every call starts with:

```python
import sys
T = r"F:\GAME I AM MAKING\shiningsun\tools\blender\anime"
if T not in sys.path:
    sys.path.insert(0, T)
for n in [n for n in sys.modules if n.startswith("anime_")]:
    del sys.modules[n]                                    # fresh imports: a reload order bug kept a stale anime_common
import anime_common as C, anime_dealer as D              # ... the modules the step uses
```

A file load (`open_mainfile`) leaves a stale context: the step after it goes in its own call. Never open a file and
export in the same call.

## The chain

| Step | Call | What it does |
|---|---|---|
| 1a | `anime_base_build.open_kit()` | the untouched KayKit kit (`<art>/blender/g19_g24_townsfolk_kit.blend`) saved as `<art>/blender/anime_base.blend` (a file load: the next step in its own call) |
| 1b | `anime_base_build.finish()` | KayKit's leg lengths stored on the rig; its feet on every frame of the 76 clips (`anime_base_kaykit_feet.json`) and its sit clips (`anime_base_kaykit_sit.json`) recorded; stripped to `Rig` + the 76 actions (the kit's objects deleted by the explicit `KIT_OBJECTS` list; an unexpected object refuses); saved |
| 2 | `anime_rig.run()` | the rest pose stretched to SD proportions (the N2-B table: shorter legs, a longer torso so she sits with room above the desk), the handslots re-seated in the palms; directions and rolls kept. Runs once per chain build |
| 3 | `anime_kit.build_base_body()` | `Base_Body`: the neutral reference body (never exported) |
| 4 | `anime_retarget.ratio_step()` | hips + root location keys scaled by the leg ratio, stamped; refuses a stamped file and a rig step 2 hasn't stretched; prints every deform bone's unscaled location offset |
| 5 | `anime_retarget.refit_sit("Base_Body")` | the three Sit_Chair_* clips rewritten for the 0.44 m seats (KayKit's back offset kept, the height solved, the feet planted), stamped; repeatable; prints `SIT_HIPS_Y` (Test 19's `AN_SIT_HIPS_Y`) and the seat re-measured on the stored clip. In a file that already has Write / Brief it refuses unless `rebuild_ok=True`, and then step 9 runs again |
| 6 | `anime_retarget.foot_report()` | the 76-clip foot report and the hips-height contact correction (`anime_base_foot_report.json`); stamps the rig (`anime_foot_report`) |
| 7 | `C.open_base_as(path)` (the dealer: `anime_dealer.open_base_as_dealer(cfg)`) | the base saved as the character's file; refuses a base missing a stamp of steps 2, 4, 5 or 6, the base's own path, and an existing file unless `overwrite_ok=True` |
| 8 | the role's `build(cfg)` (`anime_dealer.build(D.DEALER)`) | `Base_Body` deleted; its parts (`anime_kit` body parts + `anime_garments` + `anime_hair`), the palette atlas, one `<Role>_Body`, its props, the merge report (asserts `Rig` at the origin) |
| 9 | the role's `build_clips(cfg)` (`anime_dealer.build_clips`) | its own clips through `anime_anims.build_clips(clips)` (the dealer's Walk_Bar, Write, Brief), the 25.13 IK method; drops `anime_clearcheck`'s cached clouds |
| 10 | `anime_clearcheck.measure(cfg=)`, `proof(nums, cfg)`, `desk_report(nums, cfg)`, `proof_self_clips(cfg)`, `self_clips(cfg)` | the body numbers (into `staff.json`), desk and stool clearance, the self-clip checks, each check first shown to report on a deliberately bad pose; each leaves the rig in rest with no active action |
| 11 | export | `export_scene.gltf(use_selection=True, export_apply=False, export_skins=True, export_animations=True, export_yup=True)` with only Rig, the body and its props selected, to a NEW file name |

**Chains (25.31 S1.0).** Steps 1–7 take a chain config: `anime_common.AN` (this route's base, the default of every
call above) or route RL's `real_chain.REAL_1` / `REAL_2` (`tools/blender/realistic/README.md`). A chain holds the
base's files, the rest-pose table (`anime_rig.run(chain=)`), the stamps and the seat (`refit_sit`'s default: AN 0.44,
RL 0.45); a step not given one finds it by the rig's stamp (`anime_common.chain_of`). `open_kit` refuses an existing
base; `foot_report` writes the chain's JSON only in that chain's base (else `out=`). `anime_common.scratch_chain(AN,
folder, prefix)` rebuilds a whole base into scratch files: 25.31 S1.0 rebuilt the AN base that way and got
`anime_base.blend`'s rest, stamps, all 76 actions and the four JSONs back identical.

`anime_face.py` runs in system Python (Pillow): `python anime_face.py <out.png> [preset] [--overwrite]` paints a face
preset (`dealer`, `young_f`, `adult_f`, `aged_f`, `young_m`, `adult_m`, `aged_m`; colours are overrides of `run()`)
and checks its eyes at mip 5 (>= 40 % darker than the skin). It refuses an existing file without `--overwrite`.

## A role's config (25.31)

Each character is one config dict (`anime_dealer.config()` is the model): its files (`blend`, `face_png`,
`palette_png`), `palette_mat` and `palette` (key -> hex, in atlas cell order), `body` and `props` names, and the
`check` block that drives `anime_clearcheck`: which palette keys are hair / legs / skirt / skin / cuff, the Z bands
(test heights: `skirt_below`, `thigh_band`, `thigh_pad`), the cuff ring (`r`, `tube`, `offset`; omit it for a body
without cuffs and check (c) is skipped), `seat_keys` (refit_sit's seat: skin, leggings, pelvis; never a robe's hem),
the clip lists per check, and the station geometry. `anime_dealer.DEALER` is the shipped files; `anime_dealer.SCRATCH`
writes `<art>/blender/scratch_2531_dealer.blend` and `<art>/textures/anime/scratch/`, never a shipped file (the
regression rebuild).

## The generic kit (25.31)

- `anime_kit.build_base_body(params=None, join=True)`: no arguments = the chain's joined `Base_Body` (identical:
  4,872 tris); `build_base_body(params, join=False, prefix=, material=, face=)` returns a character's skin parts
  `{head, neck, torso, pelvis, arm_l/r, hand_l/r, leg_l/r, foot_l/r}`. Params (`anime_kit.BODY`): `skin`,
  `torso_girth`, `belly`, `bust`, `arm_girth`, `leg_girth`, `hand_scale`, `pelvis_girth`, segment counts, `boot_top`.
  Burly bodies (AH-5) are girth, not a new rig.
- `anime_garments`: elf / human ears, circlet, collar, trims, belt, skirt / robe (profile, back fullness and lift,
  front ease, a front `slit`), trousers, mantles, cuffs, apron, tabard, cape, shawl, hood / headscarf, hats
  (`build_hat(kind)`: straw, cap, morion, beret; each prints its top against the 2.25 cap), pack, purse, beards. Each
  builds one skinned smooth part in the caller's material; the caller paints (`anime_atlas.paint_part`) and joins.
  Check every hat from the game camera's height (a wide brim hides the face).
- `anime_hair.build_preset(name, prefix, material, lod)`: `long` (the dealer's), `short`, `cropped`, `bald` (no
  parts; a beard is a garment), `ponytail`, `bun` (grey = the palette cell).
- `anime_anims`: `base_pose`, `arm_to`, `leg_to`, `squat`, `lean`, `turn_head`, `in_frame_of`, `make_clip`,
  `walk_bar(hand, pole, stride)` (the dealer's elbows out; the Bartender's tucked: hand (0.15, -0.36, 0.70),
  pole (0.30, 0.35, 0.80)), `build_clips(clips)`.
- `anime_retarget.refit_sit(body_name, seat_verts=)` iterates the seat solve -> foot IK -> re-measure on the stored
  clip until |error| < 0.002 (refuses beyond 0.01) and takes SIT_HIPS_Y from the post-IK clip; a clothed body passes
  `anime_clearcheck.seat_verts(cfg)`. A role's own clips (actions `ratio_step` never stamped) block it unless
  `rebuild_ok=True`.
- Self-clip checks (`anime_clearcheck`): (a) hair vs the arm capsules; (b) for every thigh vertex the skirt covers at
  rest, the ray from the upper leg's axis through it must hit the skirt at or beyond it (pokes, open misses, and
  misses that leave downward under the hem, reported apart); (c) the hand's skin inside the cuff ring's axial span
  stays within its inner radius, the Sit_Chair clips included. `proof_self_clips(cfg)` shows each one reporting.
- Faces: `anime_kit.build_head` decides the face UVs per face (front faces projected, the others one skin texel at
  their side's edge), so no face mixes projected and fallback corners (the dealer's shipped head smears eye, blush and
  lip texels across her left cheek; 25.31 S0).

**Changing a bone length or the arm adduction** means editing `anime_rig.py`'s table and rebuilding the whole chain
from the untouched kit (steps 1a–6), then the character file (7–10). Never re-run the ratio step on a retargeted base
and never scale a character file's clips in place. A character whose seat thickness differs from `Base_Body`'s by
more than 0.03 m runs `anime_retarget.refit_sit("<Role>_Body")` in its own file.

## After the export (Godot)

1. Import headless (`--headless --path . --import`; exit 139 is harmless) and check by loading the resource.
2. Each extracted image's `.png.import`: `compress/mode=0`, `mipmaps/generate=true`, `detect_3d/compress_to=0`.
3. The `.glb.import`: `meshes/generate_lods=false` and a minimal `_subresources` animations dict looping the role's
   loops. Reimport; commit the expanded files.
4. `data/characters/staff.json`: the variant's `model_path`, `fallback_model_path`, `"look": "anime"` and its `body`.
5. `scripts/game/anime_look.gd` tones the body at load; Test 19 checks the file, the data and the loaded body.
