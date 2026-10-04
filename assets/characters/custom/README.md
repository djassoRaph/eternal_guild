# assets/characters/custom/

The pipeline's **characters** (Epic 25 demo cast, Epic 26 full cast): one rigged
`<asset_id>.glb` per character, exported as **glTF Binary** with its armature and animations.

- **Routes:**
  - **RL** (realistic; the demo cast's route since 2026-10-04, R-1; Story 25.31 built the whole
    human cast on it: `g1_player_real.glb`, `g12_bartender_real.glb`, `g13_quest_dealer_real.glb`,
    `g19_{farmer,local,traveller,guard,merchant,old_woman}_real.glb`,
    `g{2..7}_{fighter,rogue,mage,healer,barbarian,ranger}_real.glb`): an adult body built from one of
    two bases, REAL-1 (men, `<art>/blender/realistic_base.blend`) or REAL-2 (women,
    `realistic_base_w.blend`), which keep KayKit's skeleton (all 41 joints) with the rest pose
    re-proportioned and the 76 KayKit clips retargeted. One skinned `<Role>_Body` (≤ 3 surfaces: a
    head projected from the picked concept sheet and a painted body atlas, ≤ 2 textures at ≤ 1024²),
    props as separate nodes on their slots (carried ones hidden by the game, R-9), plus the role's
    own clips; ≤ 10,000 tris with props. The pipeline is `tools/blender/realistic/` (its `README.md`
    lists the chain and each character's steps); the character spec is 08 §1.
  - **AN** (anime; 2026-09-26 to 2026-10-04, Story 25.30): an SD anime body from the shared base
    `<art>/blender/anime_base.blend` (`tools/blender/anime/`, whose generic chain route RL runs).
    Only the Quest Dealer was built on it: `g13_quest_dealer_anime.glb` and its face-seam
    re-export `g13_quest_dealer_anime_v2.glb`, now her realistic body's fallback.
  - **RS**: a new inked mesh bound to the existing KayKit rig (25.9's `healer.glb` / `ranger.glb`,
    25.13's `g12_bartender.glb` / `g13_quest_dealer.glb`, 25.14's `townsfolk_*.glb`). *(Retired
    2026-09-26; since Story 25.31 these files are fallback bodies only.)*
  - **Custom armature**: only where KayKit proportions don't fit (Den Fa, the Cat; restyled in
    Story 25.32).
- **Rules:** the build contract in `documentation/design/08_ASSET_PROMPT_PACK.md` §1 applies
  (units, origin, roughness, budgets). Reference the file from JSON (e.g. `model_path` in
  `data/characters/classes.json`), never with `preload()`; keep a fallback (MOD-3 / MOD-6).
  The failsafe suite checks that every path referenced from `data/` exists.
- **The look is applied at load, not imported.** An entry with `"look": "realistic"` (or
  `"anime"`, the same path) in its data gets `scripts/game/anime_look.gd` `apply(model)` on its own
  body: each imported material gets one shared toon copy (the preset in `game_config.json` ›
  `anime_look_preset`; `approved`: toon diffuse, specular off, metallic 0, `TOON_BAND` 0.12) set as
  a surface override, with the shared outline `assets/characters/materials/anime_outline.tres` as
  its `next_pass` (unshaded, front-face culled, ink (0.17, 0.09, 0.12), grow 0.011 in `approved`;
  the cast's thicker ink is picked with the preset in Story 25.23's light). An emissive PROP
  material (the Healer's crystal) keeps its glow at roughness 0 with no outline; a body material
  never emits. Imported materials are never edited, and a fallback body keeps its imported look. In
  Blender the Principled BSDF's Alpha stays unlinked at 1.0 and backface culling is off, so the GLB
  is opaque and double-sided. Import keys: each extracted `.png.import` takes `compress/mode=0`,
  `mipmaps/generate=true` and `detect_3d/compress_to=0`; the `.glb.import` takes
  `meshes/generate_lods=false` and the role's loops.
- **Bodies swap by data path, with a fallback.** Every entry names its body with `model_path` and
  keeps a `fallback_model_path` (`data/characters/player.json`, `staff.json`, `townsfolk.json`,
  `classes.json`; 08 §1 "Data" lists the fields); staff `body` numbers apply only when the entry's
  own body loads (a fallback uses the script constants). Example: `staff.json`
  `desk_manager.variants.silver_elf` has `model_path` → `g13_quest_dealer_real.glb` and
  `fallback_model_path` → `g13_quest_dealer_anime_v2.glb`; the anime and the 25.13 KayKit
  `g13_quest_dealer.glb` stay here (with their `.import` and PNGs). Repoint a fallback before ever
  removing its file. After the Kickstarter a paid artist's body goes in by changing `model_path` to
  its new file: never overwrite an existing GLB, export to a new name (08 §6.4).
- **Before it counts as done:** LookDev quick check (`scenes/dev/LookDev.tscn`), the in-scene
  check, then `09_ASSET_INVENTORY.md` → `in game` and an 08 §8 log row.
- Props, buildings and landmarks go in `assets/environment/custom/` instead.
