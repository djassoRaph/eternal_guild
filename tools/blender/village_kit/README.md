# village_kit — the kit town's Blender scripts (Story 25.35)

The exterior's village and forest are built from two **CC0** Quaternius kits (Standard tier, downloaded from
OpenGameArt on 2026-11-04 with Raphael's OK; licences ship beside the assets):

- *Medieval Village MegaKit* — 176 modular pieces on a **2 m grid, 3 m storeys, real metres** (door 2.13 m).
- *Stylized Nature MegaKit* — 68 pieces (pines, broadleaf, dead and twisted trees, bushes, ferns, rocks).

Raw kits live outside the repo in `eternal_guild_art/downloads/quaternius/`. The working Blender file is
`eternal_guild_art/blender/quaternius_kit_test.blend`.

## The chain (exec'd into the running Blender, in this order)

| Script | What it does |
|---|---|
| `qkit.py` | `load(name, kit)` imports a kit piece once into the hidden `KIT` collection; `place(...)` adds a linked duplicate. Blender frame: glTF `(x, y, z)` → Blender `(x, -z, y)`. |
| `qhouse.py` | `house(place, ox, oy, w, d, floors, seed, ...)`: stone / plaster / timber storeys, random windows (with shutters), the door on the south (−y) side, gables, a roof chimney on the back slope near the ridge, sometimes a balcony. Kit rules are in its docstring. |
| `qprops.py` | Hand-built props with box-projected UVs so kit textures tile on them: anvil, forge (hearth, embers, hood, flue, bellows), barrels, weapon rack, grindstone, pots, shelves, potter's wheel, bottle kiln. |
| `qshops.py` | `smithy(into)`, `pottery(into)` — kit buildings + props. |
| `qmill.py` | `mill_house(into)`, `wheel_object()` (the water wheel, its own object, axle on x), `fountain(into)`. |
| `qrough.py` | **The rough pass** (Raphael: "too polished … more rounded, more curved"): join into one mesh, densify edges > 0.6 m, deform every vertex by one continuous function of position — ridge sag, gable kick, wall bow, upper-storey lean, a small tilt, low-frequency noise — then smooth-by-angle normals. `bake(...)` for a house, `bake_with(builder, ...)` for anything else. |
| `qexport.py` | Merge duplicate images, cap textures at 1024 px, export each building (`village_kit/*.gltf`) and nature piece (`nature_kit/*.gltf`) as glTF-separate sharing ONE texture folder (`assets/environment/kit_textures/`). |
| `gltf_inventory.py` | Bounds / tris / materials of every piece in a glTF folder (pure Python). |

The bake that shipped: houses `H01`–`H12` with `look = dict(sag=1.0, kick=0.75, bow=0.16, lean=0.22, tilt=0.03,
wob=0.10, wob_f=0.3)`; the shops and the watermill with `sag=0.8, kick=0.6, bow=0.10, lean=0.12, tilt=0.02, wob=0.08`;
the fountain with only `tilt=0.01, wob=0.04`.

## In the game

- `tools/exterior/gen_town.py` lays the town out and rewrites `scenes/world/ExteriorWorld.tscn` (see its docstring).
- `scripts/world/exterior_look.gd` `apply_kit()` tints and toon-shades the kit materials at runtime, colours each
  roof (`assets/shaders/kit_roof.gdshader`, the building's `roof_tint`) and lights the kit windows by phase.
- `scripts/world/water_wheel.gd` turns the watermill's wheel.

Everything here is demo art: after the Kickstarter the funded artists replace it (swap the glTFs by path).
