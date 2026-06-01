# GDD Section 4: Art & Interaction

### **Version: 1.1**
### **Project: Chronicles of the Eternal Guild**

> **Version 1.1 note:** Section 3 now describes the World Map dispatch screen that replaces the mission-board popup, and flags the deferred "embodied dispatch" (walk-off) feature as future cosmetic scope.

---
## 1. Visual Style & Art Direction

### 1.1 Core Aesthetic
The game's aesthetic is a 2.5D cinematic style inspired by 80's anime, particularly the works of *Studio Ghibli* and *Record of Lodoss War*. It aims to blend a cozy, painterly atmosphere with the potential for epic fantasy and darker undertones.

### 1.2 Technical Execution
This look is achieved by rendering a 3D environment through a custom pixel-art shader in Godot. The target art style is a **high-resolution pixel art illustration with sharp volumetric shading, complex dithering, and a rich, detailed color palette**. The tavern decor will feature clean pixel edges with a concept-art rendering style.

### 1.3 Character Portraits
Character art is a key component of the game's emotional core and progression systems.
* **Human Adventurers**: Portraits will follow the Ghibli-inspired style, providing a canvas for the evolving expressions and appearances required by the "Journey Through the Arcana" system.
* **Beast-Kin Adventurers**: To add variety and world-depth, the roster will include anthropomorphic beast-kin characters, presented in a similar painterly portrait style.

---
## 2. Key Visual Inspirations
The project's visual identity is guided by a curated set of inspirational images.

* **Tavern Exterior**: A cozy, inviting isometric pixel art tavern at dusk, establishing the "home base" feel.
* **Tavern Interior**: A grand, multi-level concept art piece serves as the aspirational goal for the tavern's final "Great Hall" upgrade.
* **World Scale**: Epic pixel art cityscapes and dark fortresses establish the range of the world, from bustling capitals to the domains of the Demon Lords.
* **High Fantasy Environments**: Vibrant scenes, such as a coastal town with a flying ship, capture the magical, Ghibli-esque atmosphere of the world.
* **Art Language (current direction)**: A Hellsing × Hellboy ink-heavy treatment — stark shadow geometry for the exterior world, warm amber-lit interior — layered over the Ghibli/Lodoss base.

---
## 3. Interaction & User Feedback

### 3.1 Core Interaction Mechanic
The player controls an avatar in a 3D space. Interaction with key objects (bar, patrons, fireplace, and the world-map access point) is handled via proximity detection and a single key press ("E").

### 3.2 The World Map Dispatch Screen
Mission dispatch is handled through a full-screen **World Map**, not a list popup. This is the player's primary strategic interface for the adventure half of the game.

* **The map**: A 3D hex grid rendered in a SubViewport, showing the 6–10 locations surrounding the tavern (tavern at centre). Each location's hex reflects its biome.
* **Mission postits**: 2D cards pinned to each location, showing mission name, a danger indicator (skulls), and a reward range. Multiple missions at one location stack.
* **Adventurer tokens**: The hired roster runs along one edge as cards. Ready adventurers are bright and grabbable; on-mission adventurers are greyed out with a return-day counter.
* **Dispatch by drag**: The player drags a Ready token onto a mission card, which opens the existing dispatch confirm panel. Valid drop targets highlight during the drag.
* **Daily rhythm**: Missions refresh overnight per location, so opening the map each morning carries the anticipation of seeing what arrived — the same pull as checking a guild board.

### 3.3 Living Adventurers — The Avatar Ladder (Cosmetic, Staged)
The atmosphere goal is for adventurers to be **residents of the world, not menu entries** — visible in the tavern, leaving when dispatched, returning when done. This is cosmetic and built in four separately-shippable layers. Each layer is good on its own; development can stop at any rung and still leave a livelier game. None of it is built until the core dispatch-and-reveal loop is proven.

**Shared rules (apply to all layers):**
* Avatars **reuse existing KayKit adventurer models** (Knight, Mage, Rogue, Barbarian), mapped from the adventurer's class. No new art cost.
* **Only physically-present adventurers are rendered.** Adventurers out on missions are NOT in the tavern. Wounded, Resting, and Ready adventurers are.
* **On-screen avatar count is capped** (target ~8–12 visible) regardless of roster size. With a soft roster cap of 78, the tavern can never render everyone — a dozen visible bodies reads as "full and lively"; the data layer still tracks the full roster. This mirrors the existing 5-patron visible cap.

**Layer A — Adventurers exist in the tavern (build first).** Recruited, present adventurers spawn as idle avatars placed by status: Ready ones at tables / by the fire, Wounded ones near a medical corner, Resting ones in quiet spots. They do not walk anywhere yet — they simply inhabit the space. Cheapest layer, largest payoff to "liveliness." Reuses patron-spawning patterns.

**Layer B — Walk-to-door on dispatch (in-tavern only).** When the player dispatches an adventurer *while inside the tavern*, the existing avatar stands and walks to the door, then despawns. Handles one or several at once. A listener on the dispatch signal animating Layer A avatars. Stays entirely within one scene — no cross-scene problem.

**Layer C — Status-driven placement & behaviour.** Wounded adventurers loiter at the medical area; resting ones by the fire; etc. Mostly content on top of Layer A's "spawn at a status-determined spot." Cheap once A exists.

**Layer D — Cross-scene continuity (the cliff — far future).** If the player dispatches an adventurer and then walks outside themselves (e.g., to manage farms), they see that adventurer crossing `ExteriorWorld.tscn` toward the town bridge, as the Player transitions inside→outside. This is the expensive, fragile layer: it requires reconstructing off-screen adventurer positions when a scene loads. It only matters in the rare case of the player personally following a dispatched adventurer out. See `05_Technical_Architecture.md` §6 for the reconstruction mechanism that keeps it possible. **Must never block Layers A–C or any core work.**

### 3.4 Organic Tutorial System
To avoid a traditional, text-heavy tutorial, the game uses clear visual cues to guide the player.
* **Visual Feedback**: Interactive zones are highlighted with floating icons and/or glowing runes on the floor when the player is near.
* **Status**: Functional for most zones; **still needs implementation for the Fireplace.**

### 3.5 Narrative Interaction
Key story moments, character dialogue, and critical choices are presented through **2D/Text-based event scenes**. These paused moments use character portraits and narrative text to deliver story beats in a focused and impactful manner. The end-of-day mission report — the emotional centrepiece — uses this same focused, one-reveal-at-a-time presentation.
