# GDD Section 7: World Design

### **Version: 1.0**
### **Project: Chronicles of the Eternal Guild**

---
## 1. Design Philosophy: The World as the Core Mechanic
The world of Aethel is not merely a backdrop for the tavern; it is the central mechanic that drives the game's immense replayability. The player's single most important strategic choice happens before they ever serve a drink: deciding where to build their guild. This choice fundamentally alters every subsequent aspect of the game, from the economy to the narrative.

---
## 2. The Core Mechanic: "The Great Settlement Decision"
At the start of each new game, the player is presented with a world map showing 20-30 possible settlement locations. Each location is defined by a combination of factors, offering a unique set of strategic advantages, challenges, and stories.

---
## 3. Strategic Location Factors
Each settlement's identity is a blend of the following attributes:

### 3.1 Proximity to the Demon Lord's Castle
This factor determines the game's core risk-versus-reward profile.
* **Close (High Risk/High Reward)**: Constant high-tier missions, frequent demon raids on the tavern, and a fast track to the endgame. Visually represented by dark, foreboding landscapes.
* **Far (Safe Growth)**: A peaceful early game, gradual progression, and more time to build a stable foundation before facing major threats.

### 3.2 Faction Territories
The dominant political or cultural power in a region dictates the social and mission landscape.
* **Assassin's Guild Territory**: Unlocks stealth, espionage, and assassination contracts with high payouts but constant danger.
* **Noble/Merchant Territory**: Focuses on political intrigue, diplomatic escorts, and a high-tax, high-luxury economy. Visually represented by grand, epic cities.
* **Succubus/Vice Territory**: Makes corruption mechanics a central part of gameplay, with temptations, moral consequences, and the potential to recruit fallen adventurers.

### 3.3 Environmental Biomes
The physical environment dictates available resources, mission types, and unique hazards.
* **Coastal Locations**: Center on naval missions, pirate hunting, and a fish-based economy, with seasonal storms as a recurring hazard. Visually inspired by high-fantasy coastal towns.
* **Mountain Locations**: Focus on mining, forging, dwarven connections, and high-stakes dragon lairs.
* **Forest Locations**: Involve alliances with druids, beast hunting contracts, and navigating mystical fae encounters.

### 3.4 Proximity to Ancient Ruins
Settlements built near the ruins of "The Priors" have unique opportunities related to lore and magic.
* Unlocks archaeological missions, providing lore discoveries and rare crafting materials.
* May feature awakened guardians who are both a threat and a potential source of great power.

---
## 4. Replayability & Example Playstyles
The combination of these factors creates radically different gameplay experiences with each new start.

* **Example 1: The Coastal Merchant Run**: A playthrough focused on trade, naval adventures, and political alliances with merchant guilds in a Coastal, Noble-controlled settlement far from the Demon Lord.
* **Example 2: The Demon Border Survivor**: An intense, combat-heavy playthrough in a Mountain settlement close to the Demon Lord's castle, focused on rapid progression, high-risk missions, and managing adventurer corruption.
* **Example 3: The Forest Druid Haven**: A mystical playthrough in a deep Forest, dealing with seasonal cycles, beast companions, and fae politics, with a focus on harmony-based reputation.

---
## 5. Implementation Roadmap
The system will be rolled out in phases to manage development complexity.

* **Phase 1 (MVP Foundation)**: A simple 3-location choice (e.g., Safe, Balanced, Dangerous) with different mission pools.
* **Phase 2 (Environmental Expansion)**: Introduce the 5 major biome types with unique missions and environmental events.
* **Phase 3 (Faction Integration)**: Implement the full faction territory system with unique mechanics and political consequences.
* **Phase 4 (Full Procedural System)**: Expand to 20+ locations with multi-layered effects (e.g., a Coastal settlement in Assassin territory near Ancient Ruins).

---
## 6. Technical Considerations
The world data will be structured to be easily expandable and moddable.

```
gdscript
# Example Data Structure for a World Location
class WorldLocation:
    var location_name: String
    var biome_type: String # Forest, Mountain, Coast, etc.
    var demon_proximity: int # 1-5 scale
    var dungeon_density: int # 1-5 scale
    var dominant_faction: String # Assassins, Nobles, Neutral, etc.
    var special_features: Array # Ancient Ruins, Dragon Lair, etc.
```