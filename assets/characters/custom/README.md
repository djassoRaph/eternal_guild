# assets/characters/custom/

Inked-pipeline **characters** (Epic 25 demo cast, Epic 26 full cast): one rigged
`<asset_id>.glb` per character, exported as **glTF Binary** with its armature and animations.

- **Routes:**
  - **RS**: a new inked mesh bound to the existing KayKit rig, so every KayKit animation keeps
    working (adventurer classes, patrons, villagers, staff, the Bard, the Elder).
  - **Custom armature**: only where KayKit proportions don't fit (Den Fa, the Cat).
- **Rules:** the build contract in `documentation/design/08_ASSET_PROMPT_PACK.md` §1 applies
  (units, origin, roughness, budgets). Reference the file from JSON (e.g. `model_path` in
  `data/characters/classes.json`), never with `preload()`; keep a fallback (MOD-3 / MOD-6).
  The failsafe suite checks that every path referenced from `data/` exists.
- **Before it counts as done:** LookDev quick check (`scenes/dev/LookDev.tscn`), the in-scene
  check, then `09_ASSET_INVENTORY.md` → `in game` and an 08 §8 log row.
- Props, buildings and landmarks go in `assets/environment/custom/` instead.
