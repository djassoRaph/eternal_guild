# GDD Section 7: World Design

### **Version: 1.1**
### **Project: Chronicles of the Eternal Guild**

> **Version 1.1 note:** This section now distinguishes between two different "world map" concepts that were previously conflated. The **World Map dispatch screen** (Section 2) is near-term, in-development work. The **Great Settlement Decision** (Section 3 onward) remains the long-term aspirational vision and is explicitly future scope. The old ASCII world-generation menu is a placeholder only and does not yet let the player choose a spawn location.

---
## 1. Design Philosophy: The World as the Core Mechanic
The world of Aethel is not merely a backdrop for the tavern; it is intended to become the central mechanic driving the game's replayability. In the long-term vision, the player's single most important strategic choice happens before they ever serve a drink: deciding where to build their guild. This choice fundamentally alters every subsequent aspect of the game, from the economy to the narrative.

Until that vision is built, the world serves a narrower but immediately valuable role: it is the surface on which missions appear and to which adventurers are dispatched. That near-term role is described first, because it is what is actually being implemented.

---
## 2. The World Map (Dispatch Screen) — NEAR-TERM, IN DEVELOPMENT
This replaces the current mission-board popup. Instead of a flat list of contracts, the player opens a full-screen view of the surrounding world: a 3D hex map with mission cards pinned to locations, and the guild's adventurer roster shown as draggable tokens along one edge.

### 2.1 What the Map Is
* **A persistent world layer.** 6–10 locations are fixed per save, generated once at new-game from existing settlement data (`locations.json`, `capitals.json`). Each location has a biome, faction, danger level, and a mission "flavor" that determines which kinds of missions can appear there.
* **A daily mission layer on top.** Each new day, locations roll for missions from their category pool. Routine locations (farms, roads) always offer at least one low-tier mission; dangerous locations may be empty one day and spike with a high-reward rare mission the next. **The location determines the mission pool, not the reverse.** This is the only procedural element at this stage — the map shape is stable, only the pinned missions change.
* **An adventurer roster layer.** The hired roster is shown as cards along one edge. Ready adventurers are bright and grabbable; adventurers already on a mission are greyed out with a return-day counter.

### 2.2 The Dispatch Flow
The player drags a Ready adventurer token onto a mission card. This triggers the **existing dispatch confirm panel** and dispatches exactly as the current system does. The map is a new front-end for dispatch; the dispatch logic underneath is unchanged.

### 2.3 The "Open the Board Each Morning" Feel
Because missions refresh overnight per location, opening the map each morning carries the same anticipation as checking a guild board: the player wonders what came in. This anticipation is the near-term emotional payoff and feeds directly into the end-of-day reveal that follows mission resolution.

### 2.4 Forward-Compatibility Note (Important)
The map is being built data-first. The data model knows, at all times, **which adventurer is deployed, from which location, to which mission, and on what day they return.** This matters because it makes later cosmetic features cheap to add rather than requiring a rewrite. Specifically, the long-term goal of **watching an adventurer physically walk out of the tavern toward their mission** becomes a purely visual listener bolted onto the existing dispatch event — not new core logic. See Section 6 and `05_Technical_Architecture.md` for the data contract that preserves this option.

---
## 3. The Long-Term Vision: "The Great Settlement Decision" — FUTURE SCOPE
> The remainder of this document describes the aspirational world system. **None of it is current work.** It is preserved here as the north star the near-term map is designed not to contradict.

At the start of each new game, the long-term vision presents the player with a world map showing 20–30 possible settlement locations. Each location is defined by a combination of factors, offering a unique set of strategic advantages, challenges, and stories. The player chooses one, and that choice shapes the entire playthrough.

*(Current status: the player cannot yet choose a spawn location. The ASCII generator is a generic placeholder.)*

---
## 4. Strategic Location Factors (Future Scope)
Each settlement's identity is a blend of the following attributes:

### 4.1 Proximity to the Demon Lord's Castle
This factor determines the game's core risk-versus-reward profile.
* **Close (High Risk/High Reward)**: Constant high-tier missions, frequent demon raids on the tavern, and a fast track to the endgame. Visually represented by dark, foreboding landscapes.
* **Far (Safe Growth)**: A peaceful early game, gradual progression, and more time to build a stable foundation before facing major threats.

### 4.2 Faction Territories
The dominant political or cultural power in a region dictates the social and mission landscape.
* **Assassin's Guild Territory**: Unlocks stealth, espionage, and assassination contracts with high payouts but constant danger.
* **Noble/Merchant Territory**: Focuses on political intrigue, diplomatic escorts, and a high-tax, high-luxury economy. Visually represented by grand, epic cities.
* **Succubus/Vice Territory**: Makes corruption mechanics a central part of gameplay, with temptations, moral consequences, and the potential to recruit fallen adventurers.

### 4.3 Environmental Biomes
The physical environment dictates available resources, mission types, and unique hazards.
* **Coastal Locations**: Center on naval missions, pirate hunting, and a fish-based economy, with seasonal storms as a recurring hazard. Visually inspired by high-fantasy coastal towns.
* **Mountain Locations**: Focus on mining, forging, dwarven connections, and high-stakes dragon lairs.
* **Forest Locations**: Involve alliances with druids, beast hunting contracts, and navigating mystical fae encounters.

### 4.4 Proximity to Ancient Ruins
Settlements built near the ruins of "The Priors" have unique opportunities related to lore and magic.
* Unlocks archaeological missions, providing lore discoveries and rare crafting materials.
* May feature awakened guardians who are both a threat and a potential source of great power.

---
## 5. Replayability & Example Playstyles (Future Scope)
The combination of these factors creates radically different gameplay experiences with each new start.

* **Example 1: The Coastal Merchant Run**: A playthrough focused on trade, naval adventures, and political alliances with merchant guilds in a Coastal, Noble-controlled settlement far from the Demon Lord.
* **Example 2: The Demon Border Survivor**: An intense, combat-heavy playthrough in a Mountain settlement close to the Demon Lord's castle, focused on rapid progression, high-risk missions, and managing adventurer corruption.
* **Example 3: The Forest Druid Haven**: A mystical playthrough in a deep Forest, dealing with seasonal cycles, beast companions, and fae politics, with a focus on harmony-based reputation.

---
## 6. Implementation Roadmap
The system is rolled out in phases to manage development complexity. Phases are ordered so the near-term map never blocks the long-term vision.

* **Phase 0 (Current — In Development): The World Map Dispatch Screen.** Replace the mission-board popup with the hex map described in Section 2. 6–10 fixed locations per save, daily mission spawning, drag-to-dispatch. Data-first build so deployment state is always known.
* **Phase 1 (MVP Foundation)**: A simple 3-location *choice at game start* (e.g., Safe, Balanced, Dangerous) with different mission pools, layered on top of the Phase 0 data model.
* **Phase 2 (Environmental Expansion)**: Introduce the 5 major biome types with unique missions and environmental events.
* **Phase 3 (Faction Integration)**: Implement the full faction territory system with unique mechanics and political consequences.
* **Phase 4 (Full Procedural System)**: Expand to 20+ locations with multi-layered effects (e.g., a Coastal settlement in Assassin territory near Ancient Ruins).
* **Phase 5+ (Cosmetic, deferred): Embodied dispatch.** Adventurers physically walk out of the tavern toward their mission and return into the scene. This is a visual listener on the existing dispatch event, intentionally deferred because it is atmosphere, not core. It must never block earlier phases.

---
## 7. Technical Considerations
The world data is structured to be easily expandable and moddable. The near-term map location structure is documented in `05_Technical_Architecture.md`. The long-term settlement structure remains:

```gdscript
# Example Data Structure for a long-term World Location (future scope)
class WorldLocation:
    var location_name: String
    var biome_type: String      # Forest, Mountain, Coast, etc.
    var demon_proximity: int    # 1-5 scale
    var dungeon_density: int    # 1-5 scale
    var dominant_faction: String # Assassins, Nobles, Neutral, etc.
    var special_features: Array  # Ancient Ruins, Dragon Lair, etc.
```
