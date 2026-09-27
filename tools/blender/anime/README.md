# Route AN — the anime character pipeline (Story 25.30)

The scripts that build every anime (AN) character of the demo cast in Blender 4.5, and the ones paid artists re-run
after the Kickstarter. The art-side files live in `F:/GAME I AM MAKING/eternal_guild_art/` (`<art>`; not under git);
these scripts are the versioned source of truth. The character spec (proportions, rig and clip contract, budgets,
materials and ink, export, data) is `documentation/design/08_ASSET_PROMPT_PACK.md`.

## Running them

Through the Blender MCP server (`mcp__blender__execute_blender_code`), one step per call; the exec namespace does not
persist, so every call starts with:

```python
import sys, importlib
T = r"F:\GAME I AM MAKING\shiningsun\tools\blender\anime"
if T not in sys.path:
    sys.path.insert(0, T)
import anime_common as C, anime_base_build as B          # ... the modules the step uses
for m in (C, B):
    importlib.reload(m)
```

A file load (`open_mainfile`) leaves a stale context: the step after it goes in its own call. Never open a file and
export in the same call.

## The chain

| Step | Call | What it does |
|---|---|---|
| 1 | `anime_base_build.run()` | the untouched KayKit kit (`<art>/blender/g19_g24_townsfolk_kit.blend`) saved as `<art>/blender/anime_base.blend`; KayKit's leg lengths stored on the rig; its feet on every frame of the 76 clips (`anime_base_kaykit_feet.json`) and its sit clips (`anime_base_kaykit_sit.json`) recorded; stripped to `Rig` + the 76 actions |
| 2 | `anime_rig.run()` | the rest pose stretched to SD proportions (the N2-B table: shorter legs, a longer torso so she sits with room above the desk), the handslots re-seated in the palms; directions and rolls kept. Runs once per chain build |
| 3 | `anime_kit.build_base_body()` | `Base_Body`: the neutral reference body (never exported) |
| 4 | `anime_retarget.ratio_step()` | hips + root location keys scaled by the leg ratio, stamped; refuses a stamped file |
| 5 | `anime_retarget.refit_sit("Base_Body")` | the three Sit_Chair_* clips rewritten for the 0.44 m seats (KayKit's back offset kept, the height solved, the feet planted); repeatable; prints `SIT_HIPS_Y` (Test 19's `AN_SIT_HIPS_Y`) |
| 6 | `anime_retarget.foot_report()` | the 76-clip foot report and the hips-height contact correction (`anime_base_foot_report.json`) |
| 7 | `anime_dealer.open_base_as_dealer()` | the base saved as the character's file (`<art>/blender/g13_quest_dealer_anime.blend`) |
| 8 | `anime_dealer.build()` | her parts, the palette atlas, one `Dealer_Body`, the `Dealer_Quill` prop, the merge report |
| 9 | `anime_anims.build_clips()` | her own clips (Walk_Bar, Write, Brief), the 25.13 IK method |
| 10 | `anime_clearcheck.measure()`, `proof()`, `desk_report()`, `self_clips()` | her body numbers (into `staff.json`), desk and stool clearance, the self-clip checks |
| 11 | export | `export_scene.gltf(use_selection=True, export_apply=False, export_skins=True, export_animations=True, export_yup=True)` with only Rig, the body and its props selected, to a NEW file name |

`anime_face.py` runs in system Python (Pillow): `python anime_face.py <out.png>` paints the face and checks it at mip 5.

**Changing a bone length or the arm adduction** means editing `anime_rig.py`'s table and rebuilding the whole chain
from the untouched kit (steps 1–6), then the character file (7–10). Never re-run the ratio step on a retargeted base
and never scale a character file's clips in place. A character whose seat thickness differs from `Base_Body`'s by
more than 0.03 m runs `anime_retarget.refit_sit("<Role>_Body")` in its own file.

## After the export (Godot)

1. Import headless (`--headless --path . --import`; exit 139 is harmless) and check by loading the resource.
2. Each extracted image's `.png.import`: `compress/mode=0`, `mipmaps/generate=true`, `detect_3d/compress_to=0`.
3. The `.glb.import`: `meshes/generate_lods=false` and a minimal `_subresources` animations dict looping the role's
   loops. Reimport; commit the expanded files.
4. `data/characters/staff.json`: the variant's `model_path`, `fallback_model_path`, `"look": "anime"` and its `body`.
5. `scripts/game/anime_look.gd` tones the body at load; Test 19 checks the file, the data and the loaded body.
