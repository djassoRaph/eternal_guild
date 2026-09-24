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
any generator.

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

**Sheet suffix.** Append this to any concept prompt when you want an image for Route 2, or a
clean single-object reference for Route 1:

> Single object only, centred, whole object in frame, three-quarter view from 30 degrees
> above, plain flat light-grey background, even soft lighting, no cast shadows, no ground
> plane, no text, no other objects. Low-poly stylized game asset, flat-shaded faces,
> simple solid colours.

**Optional pixel preview.** Add *"rendered as crisp high-resolution pixel art with dithered
shading"* to any key-art prompt to preview roughly how it'll look under the in-game shader.
Use the non-pixel version as the modelling reference.

---

## 3. Priority: Batch 1 (hard cap: 6)

| # | Asset | Why it's in Batch 1 | Route |
|---|---|---|---|
| 0 | **K1–K3 key art** (tavern exterior, interior, world map) | Locks the look for everything. Also useful as Kickstarter art | Stage A only |
| 1 | **D1 Prior Ruins** (the **gate** asset) | Small, and unique to your world (KayKit has nothing like it). Tests every pipeline step, including the teal glow | 1 |
| 2 | **A1 + A2 The Guild Tavern** (walkable exterior + hex-centre miniature) | The first thing the player sees on both screens. Today it's KayKit's blue-team RTS tavern | 1 |
| 3 | **B1 The Hearth** | Core interaction (the fire minigame). Today it's 3 grey boxes | 1 |
| 4 | **B2 The Bar** | Second core interaction, and it sets the interior's tone | 1 |
| 5 | **D2 Demon Cult Shrine** | Gives the map a visible threat. No KayKit equivalent | 1 |
| 6 | **D3 Dragon's Lair** | Highest-tier mission site. No KayKit equivalent | 1 (+2 for the skull) |

**Batch 2** (only after Batch 1 is in the game): B6 Hourglass Pillar (your STATE doc parks it
until the reveal ships, so keep that decision), B3 Recruitment Desk, B4 Mission Board, B5 Wall of
the Fallen, D4–D7.
**Backlog:** everything else marked *backlog* below.

---

## 4. Stage A: Key art (style lock)

These work in any generator. For Midjourney, append `--ar 16:9 --style raw --no text, watermark`.

### K1: Tavern exterior at dusk

> Stylized low-poly 3D fantasy game scene, isometric view from 30 degrees above,
> orthographic camera. A cozy two-storey adventurers' guild tavern at dusk on a small grassy
> rise beside a dirt road: heavy timber frame over a pale stone ground floor, steep dark red
> shingle roof, a crooked stone chimney with a thin line of smoke, warm amber light glowing
> from small square windows, a hanging wooden sign with an hourglass-inside-a-flame emblem,
> barrels and stacked firewood by the door, a lantern on a post. Chunky toy-like
> proportions, flat-shaded faces with soft vertical colour gradients, bevelled edges, no fine
> texture detail, low-poly strategy-game diorama style. Strong graphic shadow shapes (Mike
> Mignola inspired lighting), cool blue-violet dusk sky against the warm windows. Melancholy
> and inviting. Muted palette: timber brown, pale stone grey, dark red roof, amber light, deep
> blue shadow.

### K2: Tavern interior at night

> Stylized low-poly 3D fantasy game interior, isometric cutaway view from 30 degrees above,
> orthographic camera, two walls removed so we see inside. A large timber-and-stone guild
> tavern hall at night: a big stone hearth with a roaring fire, a long wooden bar with kegs
> and bottles on back shelves, heavy round tables and benches, a recruitment desk with an
> open ledger and a candle, a notice board covered in pinned mission papers, a wooden
> staircase to an upper floor, a quiet corner with one empty chair and candles beneath small
> framed name plaques. Warm amber firelight pooling on the floor, deep soft shadows in the
> corners, Studio Ghibli warmth. Chunky toy-like proportions, flat-shaded faces with soft
> colour gradients, bevelled edges, no fine texture detail, low-poly game asset style.
> Palette: honey and dark timber, pale grey stone, amber and ember-orange light, a few deep
> red cloth accents.

### K3: World map

> Stylized low-poly 3D hex-tile world map of a small island, isometric view from 50 degrees
> above, orthographic. Hexagonal tiles: grassland, pine forests, rocky mountains with a dark
> cave, a winding river with a stone bridge, a coastline with shallow turquoise water. A cozy
> tavern with a red roof on the centre tile. Scattered landmark tiles: crumbling pale-stone
> ancient ruins with glowing teal runes, a jagged black shrine with a magenta-red glow, a
> bandit camp with a log palisade and campfire, a small mining village in the mountains, a
> watchtower near the coast. Chunky toy-like diorama proportions, flat-shaded faces, soft
> colour gradients, clean silhouettes, low-poly board-game look. Soft daylight, one side of
> the island darker and more foreboding. Palette: fresh greens, sand, pale stone, blue-teal
> sea, small accents of teal glow and magenta-red.

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

#### B2: The Bar · Batch 1 · Route 1
- **In game:** the `BarArea` interaction. It replaces `BarCounter` and the local-only
  `TavernCounterCircular.glb`.
- **Size:** counter 1.1 m high × 0.7 m deep, ~5 m long (match your current layout: straight or L).
  The back shelf is 2.5 m tall.
- **Budget:** ≤ 6,000 tris total, split into `bar_counter`, `back_shelf`, `keg_rack`.
- **Concept prompt:**
  > Stylized low-poly 3D game asset: a long wooden tavern bar. A thick honey-coloured plank top
  > on a dark timber base with simple panels, a brass foot rail, three tankards and a cloth on
  > the counter. Behind it, a tall back shelf with rows of bottles, a rack of three big wooden
  > kegs with taps, and a small chalkboard. Warm and well-used. Chunky toy-like proportions,
  > flat-shaded faces, soft colour gradients, bevelled edges, no fine texture detail. Isometric
  > view from 30 degrees above, plain light-grey background.

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

#### B6: The Hourglass Pillar · Batch 2 (parked until the reveal ships) · Route 1
- **Your design spec for this lives outside this repo. Reconcile with it before using this prompt.
  If they disagree, the spec wins.**
- Prior stonework in the cellar, excavated in stages as the tavern upgrades. Build it as **stacked
  segments** (buried → base → shaft → capital with hourglass) so upgrade tiers can reveal them in
  code.
- **Concept prompt:**
  > Stylized low-poly 3D game asset: an ancient pale-stone pillar half-excavated from a cellar
  > floor, its surface carved with bands of glowing teal runes, and at its top a large hourglass
  > of dark bronze and glass set into the stone, sand trickling. Rubble and a wooden excavation
  > scaffold around its base. Mysterious, patient, very old. Chunky toy-like proportions,
  > flat-shaded faces, soft colour gradients, bevelled edges, no fine texture detail. Isometric
  > view from 30 degrees above, plain light-grey background.

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

#### D2: Demon Cult Shrine · Batch 1 · Route 1
- **Budget:** ≤ 2,500 tris. Swatches: `charcoal`, `iron`, `cloth_red`, `bone_white`. Glow uses `emissive_demon`.
- **Concept prompt:**
  > Stylized low-poly 3D hex tile game asset, isometric view from 30 degrees above. On a single
  > hexagonal tile of scorched dark earth: a jagged black-stone altar ringed by five tall crooked
  > obelisks, tattered dark red banners on poles, a pit in the centre glowing magenta-red, a few
  > bone-white candles, dead grey grass at the edges. Ominous but not gory: no bodies, no
  > blood. Chunky toy-like proportions, flat-shaded faces, soft colour gradients, bevelled edges,
  > no fine texture detail, low-poly board-game diorama style. Plain light-grey background.
  > Palette: charcoal and iron-grey stone, dark red cloth, magenta-red glow, bone white.

#### D3: Dragon's Lair · Batch 1 · Route 1 (+ Route 2 for the skull)
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
   Never write into the KayKit folders (hexagons/, furniture/, characters/).
   Never overwrite an existing file. If the name exists, stop and ask. (The one exception
   is the atlas copy hexagons_medieval.png written next to it, which is identical every time.)
5. Report the files written and their sizes.
```

### 6.5 Stage D: check it in Godot

- **Where to test:**
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
| K1 Tavern exterior key art | A | | | todo |
| K2 Interior key art | A | | | todo |
| K3 World map key art | A | | | todo |
| D1 Prior Ruins (gate) | 1 | | | todo |
| A1 + A2 Guild Tavern | 1 | | | todo |
| B1 Hearth | 1 | | | todo |
| B2 Bar | 1 | | | todo |
| D2 Demon Cult Shrine | 1 | | | todo |
| D3 Dragon's Lair | 1 (+2) | | | todo |
