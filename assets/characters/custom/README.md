# assets/characters/custom/

Inked-pipeline **characters** (Epic 25 demo cast, Epic 26 full cast): one rigged
`<asset_id>.glb` per character, exported as **glTF Binary** with its armature and animations.

- **Routes:**
  - **AN** (anime; the demo cast's route since 2026-09-26, first built: the Quest Dealer,
    `g13_quest_dealer_anime.glb`, Story 25.30): an SD anime body built from the shared base
    `<art>/blender/anime_base.blend`, which keeps KayKit's skeleton (all 41 joints) with its rest
    pose stretched and the 76 KayKit clips retargeted, so they keep working. One skinned
    `<Role>_Body` (≤ 3 surfaces), props as separate nodes on item bones, plus the role's own clips.
    The pipeline is the versioned scripts in `tools/blender/anime/` (its `README.md` lists the
    chain); the character spec is 08's.
  - **RS**: a new inked mesh bound to the existing KayKit rig, so every KayKit animation keeps
    working (adventurer classes, patrons, villagers, staff, the Bard, the Elder). *(Retired
    2026-09-26 for new characters. The Quest Dealer was rebuilt as AN in Story 25.30; the other
    KayKit-based bodies here follow in Story 25.31.)*
  - **Custom armature**: only where KayKit proportions don't fit (Den Fa, the Cat).
- **Rules:** the build contract in `documentation/design/08_ASSET_PROMPT_PACK.md` §1 applies
  (units, origin, roughness, budgets). Reference the file from JSON (e.g. `model_path` in
  `data/characters/classes.json`), never with `preload()`; keep a fallback (MOD-3 / MOD-6).
  The failsafe suite checks that every path referenced from `data/` exists.
- **The anime look is applied at load, not imported.** A variant with `"look": "anime"` in its data
  gets `scripts/game/anime_look.gd` `apply(model)`: each imported material gets one shared toon copy
  (toon diffuse, specular off, metallic 0, roughness `TOON_BAND` 0.12) set as a surface override,
  with the shared outline `assets/characters/materials/anime_outline.tres` as its `next_pass`. The
  outline is unshaded and front-face culled, in the ink colour (0.17, 0.09, 0.12), with a grow of
  0.011 (the approved test's; recommended at Stage D, pending Raphael's OK). Imported materials are
  never edited, and a fallback body keeps its imported look. In Blender the Principled BSDF's Alpha
  stays unlinked at 1.0 and backface culling is off, so the GLB is opaque and double-sided. Import
  keys for an AN file: each extracted `.png.import` takes `compress/mode=0`,
  `mipmaps/generate=true` and `detect_3d/compress_to=0`; the `.glb.import` takes
  `meshes/generate_lods=false` and the role's loops.
- **Bodies swap by data path, with a fallback.** A variant names its body with `model_path` and
  keeps a `fallback_model_path`; its `body` numbers apply only when its own body loads (a fallback
  uses the script constants). Example: `data/characters/staff.json`
  `desk_manager.variants.silver_elf` has `model_path` → `g13_quest_dealer_anime.glb` and
  `fallback_model_path` → the 25.13 KayKit `g13_quest_dealer.glb`, which stays here (with its
  `.import` and PNGs) for as long as staff.json names it. After the Kickstarter a paid artist's body
  goes in by changing `model_path` to its new file: never overwrite an existing GLB, export to a
  new name (08 §6.4).
- **Before it counts as done:** LookDev quick check (`scenes/dev/LookDev.tscn`), the in-scene
  check, then `09_ASSET_INVENTORY.md` → `in game` and an 08 §8 log row.
- Props, buildings and landmarks go in `assets/environment/custom/` instead.
