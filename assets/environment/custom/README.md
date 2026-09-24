# assets/environment/custom/

Inked-pipeline **props, buildings and hex landmarks** (Epic 25 / Epic 26), built in Blender
through the MCP and exported for Godot.

- **What goes here:** one `<asset_id>.gltf` (+ its `.bin` and the shared atlas copy
  `hexagons_medieval.png`) per asset, exported as **glTF Separate** per
  `documentation/design/08_ASSET_PROMPT_PACK.md` §6.4.
- **Rules:** follow the build contract in 08 §1 (KayKit atlas colours, no baked lighting,
  roughness > 0 unless the surface should read as light, marker empties, `-colonly` /
  `-convcolonly` collision proxies, triangle budgets). Never overwrite an existing file; never
  write into the KayKit folders.
- **Before it counts as done:** LookDev quick check (`scenes/dev/LookDev.tscn`), then the
  in-scene Stage D pass (08 §6.5), then set the asset's status to `in game` in
  `documentation/design/09_ASSET_INVENTORY.md` and log it in 08 §8.
- Characters do **not** go here: see `assets/characters/custom/`.
