# Eternal Guild — 3D Asset Prompt Pack

*Tavern (outside + inside) · World map · Hex landmarks — v1, 2026-09-24*

> **How to use this doc.** Stage A prompts go into an image generator (any of them).
> Stage B–C prompts go into Claude Code **on your PC**, with Blender open and a
> Blender MCP connected. Every size and budget here was measured from files in this
> repo. If a number and your eye disagree, trust a KayKit model imported next to
> the new asset.

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

## 1. The one style rule

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

### Build contract (Godot-side rules) — added by Story 25.1

These sit on top of the style rules above. Every new asset card (Epic 25 / Epic 26 stories)
assumes them.

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
  | Character | ≈ KayKit density | `Knight.glb` 6,952 in total (≈ 4.6k body + ≈ 2.3k gear across 15 meshes) |

- **Export folders:**
  - Props, buildings, landmarks: `res://assets/environment/custom/<asset_id>.gltf` (glTF Separate, §6.4).
  - Characters: `res://assets/characters/custom/<asset_id>.glb` (glTF Binary, armature + animations).
  - Never write into KayKit folders. Never overwrite a file.
- **Data hookup:** content is referenced by path from JSON (MOD-3) with a fallback (MOD-6). The
  failsafe suite (Test 5) checks that every referenced path exists. Known gaps live in
  `test/asset_path_allowlist.json`.
- **Quick check:** `scenes/dev/LookDev.tscn` (tavern or map preset) before the in-scene Stage D
  pass (§6.5).

---

## 2. The pipeline

```
Stage A  Concept image    any image generator            → reference only, never shipped
Stage B  Model            Route 1: Claude builds it in Blender (default)
                          Route 2: image-to-3D, then Claude cleans it (organic shapes only)
Stage C  Atlas + export   Claude in Blender               → assets/environment/custom/<id>.gltf
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
   (Animation ON), saved to <project>/assets/characters/custom/<asset_id>.glb.
   Never write into the KayKit folders (hexagons/, furniture/, characters/models/).
   Never overwrite an existing file. If the name exists, stop and ask. (The one exception
   is the atlas copy hexagons_medieval.png written next to it, which is identical every time.)
5. Report the files written and their sizes.
```

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
| B6 Hourglass Pillar | 1 | | | concepts generating |
| A1 + A2 Guild Tavern | 1 | Claude via Blender MCP (one parametric script; A2 = its mini LOD), §6.3 remap, §6.4 export | 2026-09-25 | **in game**: Stage D passed (LookDev + ExteriorWorld + HexMapTest); A1 4,568 tris, A2 996; windows emissive at roughness 0 (dark base + amber, not white) |
| C9 Home marker | — | same script as A1/A2 | 2026-09-25 | **in game**: guild banner with the hourglass emblem on the tavern hex; 116 tris |
| B6 Hourglass Pillar | 1 | Claude via Blender MCP (parametric stacked segments, octagonal lofts, emissive rune glyphs), §6.3 remap | 2026-09-25 | **in game**: Stage D passed (LookDev stages 0–4 + MainTavern); 2,480 tris; runes/sand/glass emissive teal at roughness 0 with a dark base; placed ×1.4 (the card's 3.5 m read too slender in the round bar) |
| A6 Exterior terrain (hill, path, stream) + bridge | — | Claude via Blender MCP (height-function mesh, atlas faces, creased ramp for ink outlines) + a scripted scene layout | 2026-09-25 | **in game** (ExteriorWorld): terrain 16,232 tris, trimesh collision; bridge 840 tris, walkable deck. Village and forest laid out from KayKit |
| B1 Hearth + H3 firewood | 1 | Claude via Blender MCP (parametric stone courses clipped round the arched firebox, stepped chimney breast, markers + convex collision proxies), §6.3 remap | 2026-09-25 | **in game**: Stage D passed (LookDev four fire states + MainTavern TCP run); B1 2,660 tris, H3 log 24 / bundle 172; stone on `stone_warm` (`stone_light` read slate blue); ember bed, candle flames and Prior runes emissive at roughness 0; the fire itself is particles + light driven by `hearth.gd` |
| B2 Round bar + stools, B12 back-bar island, H1 tankard | 1 | Claude via Blender MCP (parametric ring wedges via convex hulls, rune glyphs on the panels, trimesh collision proxies), §6.3 remap | 2026-09-25 | **in game**: Stage D passed (MainTavern TCP run: patrons sit on the stools facing the bar, the player serves, full then empty tankard in hand); B2 3,540 tris, stool 124, B12 2,558, tankard 112/118; ring 6.2 m across (the card's 4.5 m left no walkway round the ×1.4 pillar); base panels on atlas (1, 7) because `wood_dark` barely differs from `wood_light`; the held tankard is drawn 1.8× so it reads |
| B1 Hearth | 1 | | | concepts generating |
| B2 Bar (round) | 1 | | | concepts generating |
| D2 Demon Cult Crypt | 1 | | | concept picked (crypt v2) |
| D3 Dragon's Lair | 1 (+2) | | | Batch 2 |
