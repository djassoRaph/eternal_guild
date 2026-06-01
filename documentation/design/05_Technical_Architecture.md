# GDD Section 5: Technical Architecture

### **Version: 1.1**
### **Project: Chronicles of the Eternal Guild**

> **Version 1.1 note:** Adds the World Map dispatch screen architecture, the `map_locations` data structure, the save-data contract, and a forward-compatibility contract for deployment state. Engine line corrected to the in-use version. The folder tree is updated to reflect the actual project layout.

---
## 1. Engine & Core Specifications

* **Engine**: Godot 4.4 (3D with isometric projection). *(The project has moved from the 4.3+ baseline; new code targets 4.4.)*
* **Rendering**: The 2.5D aesthetic is achieved through a custom pixel-art / edge-detection shader with pixel-perfect rendering and nearest-neighbor filtering enabled globally.
* **Performance Target**: The game must maintain a stable 60 FPS with full atmospheric effects enabled.
* **Memory Management**: Systems are designed for efficient NPC spawning and de-spawning cycles to manage memory usage, particularly as the number of patrons and adventurers grows.

---
## 2. Architectural Strategy

### 2.1 Multiple Singleton Managers
The game uses a system of multiple, focused singleton managers (`GameManager`, `DataManager`, `PlayerManager`, `SaveSystem`, `WorldManager`) to ensure the codebase is organized, maintainable, and scalable. This achieves **Separation of Concerns**, preventing a single monolithic manager from becoming bloated and difficult to debug.

### 2.2 Signal-Based Communication
To ensure systems are loosely coupled, the architecture heavily relies on Godot's built-in signal system. Game logic managers emit signals when state changes (e.g., `gold_updated`), and UI systems connect to these signals to update their presentation. This prevents UI code from directly controlling game logic.

### 2.3 The Dispatch Event as a Shared Contract (Important)
Dispatching an adventurer to a mission is treated as a **single authoritative event** emitted by `GameManager`, not as logic owned by any one screen. The mission board, the new World Map, the morning briefing, and any future visual feature all listen to the same event. This is the rule that lets the front-end change (list → hex map) without touching dispatch logic, and lets future cosmetic features (see Section 6) attach without a rewrite.

---
## 3. Data-Driven Design & Modding Support

### 3.1 JSON-Based Content
All game content — missions, adventurer classes, items, dialogue, and settlement data — is driven by external data files, primarily JSON.

### 3.2 Dual Purpose
1.  **Internal Development**: Rapid iteration on complex systems (like "Journey Through the Arcana") without code changes.
2.  **Future Modding**: The foundational requirement for community-created content, a lesson drawn from *Fort of Chains*.

---
## 4. The World Map Dispatch Screen — Architecture (NEAR-TERM)

### 4.1 New Files
```
scenes/world/WorldMap.tscn              # full-screen CanvasLayer war room
scenes/world/script/WorldMap.gd         # (new subfolder, mirrors scenes/ui/script/)
scenes/ui/MissionPostit.tscn            # 2D card pinned to a hex
scenes/ui/script/mission_postit.gd
scenes/ui/AdventurerToken.tscn          # draggable roster token
scenes/ui/script/adventurer_token.gd
```
`WorldMap.tscn` contains a `SubViewport` rendering the 3D hex grid (orthographic top-down camera for readability) and a 2D overlay layer of `Control` nodes for the mission postits and adventurer tokens. ESC closes it, matching the current mission board behaviour.

### 4.2 Modified Files (verify current versions before editing — non-breaking changes only)
```
scripts/GameManager.gd          # add map_locations[]; generate_map_locations();
                                #   modify refresh_available_missions() to assign per-location
systems/SaveSystem.gd           # map_locations in get_save_data()/load_save_data() FROM DAY ONE
scripts/game/zone_interactions.gd  # swap open_mission_board() -> open_world_map()
data/settlements/locations.json    # source pool for hex locations
data/settlements/capitals.json     # source pool
```

### 4.3 Must Remain Untouched
`send_on_mission()`, `send_party_on_mission()`, the dispatch confirm panel, all downstream mission-resolution logic, the morning briefing. These already work; the map only changes how dispatch is *triggered*.

### 4.4 The `map_locations` Data Structure
Generated once at new-game, persisted in the save, never regenerated mid-save:
```gdscript
{
    "id": "ironhold_pass",
    "name": "Ironhold Pass",
    "biome": "mountain",
    "faction": "dwarf",
    "danger_level": 2,
    "hex_position": Vector2i(3, 1),     # fixed per save, picked from a hand-authored valid-position set
    "mission_categories": ["combat", "gathering"],
    "active_missions": []                # repopulated daily by refresh_available_missions()
}
```
Hex positions are assigned from a fixed list of valid positions (a ring pattern, tavern at centre), not fully procedurally — the map feels different each run by shuffling which location lands on which hex, without the cost of true procedural generation.

### 4.5 Build Order (never leaves the build broken)
1. **Data layer only, no visuals.** `map_locations`, `generate_map_locations()`, save/load wiring, per-location mission assignment. Verify via the F12 debug panel and confirm old saves still load.
2. **Placeholder map scene.** Flat colored hexes, simple icons, ESC to close, wire `open_world_map()`. Old board kept as fallback.
3. **Mission postits, click-to-dispatch.** Cards pinned to hex screen positions; click triggers the existing confirm panel. *Shippable interim.*
4. **Adventurer tokens + drag-and-drop** via Godot's `_get_drag_data()` / `_can_drop_data()` / `_drop_data()`.
5. **KayKit 3D hex tiles** replace flat colors. *(Confirm the medieval hex tile pack is actually imported before reaching this step — it is not yet visible in the asset tree.)*

---
## 5. Save-Data Contract (Critical)
`map_locations` **must** be written by `get_save_data()` and read by `load_save_data()` from the first commit of the data layer. The single biggest risk in this feature is breaking save compatibility. Step 1 of the build order is verified complete only when a save created before the change still loads without error.

---
## 6. Forward-Compatibility Contract: Deployment State
To keep future cosmetic features cheap, the deployment data model must always answer four questions for every dispatched adventurer, without inference:
* **Who** is deployed (adventurer id)
* **From where** (origin — the tavern, or later a specific hex)
* **To where** (destination location id)
* **When** they return (return day / hour)

As long as this is true and the dispatch event (Section 2.3) carries it, the deferred living-adventurer visuals become listeners rather than changes to any system.

### 6.1 The Avatar Ladder — Technical Staging
The "living adventurers" feature (see `04_Art_and_Interaction.md` §3.3) is staged so each layer is independently shippable and none blocks core work.

* **Shared:** avatars reuse KayKit models mapped by class; only physically-present adventurers render; on-screen count is capped (~8–12) independent of roster size. An adventurer's `status` (Ready / Resting / Wounded / On-Mission) is the single source of truth for whether and where an avatar spawns.
* **Layer A (build first):** an avatar spawner in `MainTavern.tscn` reads the present roster and instantiates idle avatars at status-determined anchor points. Reuses `PatronSpawner` patterns. No movement.
* **Layer B:** a listener on the dispatch signal animates the relevant Layer-A avatar walking to the door, then despawns it. Single-scene; uses existing `NavigationAgent3D`.
* **Layer C:** status→anchor-point mapping for Wounded/Resting placement. Content on top of A.
* **Layer D (far future):** cross-scene continuity.

### 6.2 The Cross-Scene Reconstruction Mechanism (Layer D — capture-and-defer)
The hard part of Layer D is that `MainTavern.tscn` and `ExteriorWorld.tscn` do not share memory — an adventurer who "left" the tavern does not exist in the exterior scene. The solution is **not** a continuous off-screen simulation. It is reconstruction on scene load:

> When `ExteriorWorld.tscn` loads, its setup reads the list of currently in-transit adventurers and spawns an avatar for each at a position **interpolated from departure time and travel duration** (e.g., 30% of the way along the tavern→bridge path if 30% of travel time has elapsed). On return trips, interpolate in the opposite direction.

This means the data layer only needs to store, per in-transit adventurer: departure day/time, expected travel duration, and direction (outbound/returning). Position is *derived*, never stored or simulated tick-by-tick. This single mechanism is the entire bridge from the data layer to Layer D, and is recorded here so it never has to be rediscovered. It remains deferred until the core loop is proven.

---
## 7. Asset & Project Organization Standards (actual layout)
```
res://
├── assets/
│   ├── audio/
│   ├── characters/        # animations, kaykit models, portraits, textures
│   ├── environment/       # decorations, furniture, lighting, nature
│   ├── portraits/
│   ├── shaders/           # edge_detection.gdshader
│   └── ui/
├── data/
│   ├── characters/        # classes.json, names.json, traits.json
│   ├── dialogue/          # patron_lines.json
│   ├── economy/           # items.json
│   ├── missions/          # mission_types.json, rewards.json
│   └── settlements/       # capitals.json, locations.json
├── documentation/
│   ├── design/            # 00–07 GDD sections (+ html/)
│   └── old/               # archived notes
├── scenes/
│   ├── npcs/              # patron scenes
│   ├── player/
│   ├── ui/                # MissionBoard, cards, debug_panel, script/
│   └── world/             # ASCII generator, ExteriorWorld, (new) WorldMap
├── scripts/
│   ├── GameManager.gd
│   ├── autoload/          # PlayerManager
│   ├── camera/
│   ├── game/              # zone_interactions, main_tavern, bar_area, patron_interactions, ZonePromptUI
│   ├── menus/
│   ├── npcs/              # PatronSpawner, RealisticPatron
│   ├── player/
│   ├── ui/                # tavern_management, recruitment_popup, fade_to_black
│   └── world/             # entrance/exit zones, exteriorworld
└── systems/
    ├── DataManager.gd
    ├── PlayerManager.gd
    ├── SaveSystem.gd
    └── WorldManager.gd
```
*(Note: GameManager.gd currently lives at `scripts/GameManager.gd`, while DataManager/SaveSystem/PlayerManager/WorldManager live in `systems/`. PlayerManager appears in both `scripts/autoload/` and `systems/` — worth consolidating to one autoload source to avoid confusion.)*
