# 03_Story_and_Progression.md - Eternal Guild Narrative and Progression Design

## 🎭 **Overview**
This document outlines the narrative arc and progression system for *Eternal Guild*, guiding players through a procedural "adventure story" of tavern and guild management. The game features a 3-act structure, evolving from a confined tutorial phase to an open-world exploration loop, with replayability enhanced by biome-specific challenges and the "Achievements/Hommage" system. Progression is designed to introduce complexity gradually, avoiding overwhelm, while supporting multiple victory paths (economic, political, exploration) and future modding.

---

## 📖 **Three-Act Narrative Structure**

### **Act I: The Tavern Awakening (Days 1-30)**
**Setting the Stage**: Players begin in **MainTavern.tscn**, managing a newly inherited tavern in a chosen settlement from the **WorldGenerateMenu.tscn** ASCII map. This 30-day tutorial phase establishes core mechanics: serving patrons, recruiting adventurers, assigning missions, and handling economics (beer sales, taxes).

- **Narrative Hook**: A mysterious letter from "The Warden" hints at the tavern’s ancient ties to the "Priors" ruins, setting a lore foundation. Daily procedural "chances" (e.g., 20% chance of a bard rumor or patron story) introduce light narrative beats, keeping management engaging without grind.
- **Progression Goals**: 
  - Build initial gold reserves through beer sales and tips (influenced by Fireplace comfort levels).
  - Recruit a small adventurer roster (2-3 characters) with unique traits from JSON data.
  - Survive the first tax payment (1000 gold) by Day 30, unlocking the outdoor world.
- **Procedural Elements**: Random seed-generated settlement data (e.g., biome: plains/river) subtly affects initial conditions (e.g., river towns start with a trade bonus).
- **Player Experience**: A gentle learning curve with intuitive UI (e.g., E-key interactions, mission board popups), ensuring discoverability without external guides.
- **Transition**: On Day 30, a tax success event triggers a door unlock in MainTavern.tscn, fading to **MainTown.tscn** for Act II.

### **Act II: The Town Unfolds (Post-Day 30)**
**Expanding Horizons**: Players exit the tavern to explore **MainTown.tscn**, a procedural outdoor map reflecting their chosen settlement’s biome and features (e.g., river with bridge, central plaza/fountain, fields). This act introduces a fluid indoor-outdoor loop, deepening the guild’s story through town interactions.

- **Narrative Development**: The "Warden’s Commission" questline begins—players discover clues to the "Priors" ruins (e.g., herb gathering near rivers reveals lore fragments). Procedural town events (e.g., 30% chance of a plaza festival) tie to settlement factors, creating unique stories per playthrough.
- **Progression Goals**: 
  - Explore the town, interact with NPCs to unlock adventurer quests (e.g., "Defend the bridge" or "Gather herbs for brewing").
  - Forage resources (hops/herbs in fields/rivers, 5-10 nodes respawning daily) to craft custom beer, wine, or cider (post-MVP upgrades via tavern renovations).
  - Build town relations (e.g., trade with merchants in plazas) to unlock faction-specific missions (Nobles, Assassins).
- **Procedural Elements**: MapGen generates unique layouts (noise-based rivers, Voronoi plazas), with biome-specific challenges (e.g., flood events in river towns). Character arcs evolve via shared experiences (e.g., herb quests trigger "Journey Through the Arcana" updates).
- **Player Experience**: Seamless phasing between MainTavern.tscn and MainTown.tscn (via WorldManager singleton) avoids reload lag, maintaining 60 FPS. Varied routines (exploration vs. management) prevent Stardew-like repetition.
- **Transition**: Completing initial town quests (e.g., Warden’s first clue) unlocks Act III, with deeper world events.

### **Act III: The Eternal Legacy (Post-Initial Quests)**
**Endgame Evolution**: Players ascend to guild masters, shaping their legacy through procedural world expansion and community-driven content. This act supports long-term engagement and multiple victory paths.

- **Narrative Climax**: The "Priors" ruins storyline culminates in a settlement-specific finale (e.g., river towns reveal a flooded temple, plains uncover an ancient market). Procedural world events (e.g., demon incursions near ruins) challenge all playstyles.
- **Progression Goals**: 
  - Achieve victory via economic dominance (brewery empire), political influence (faction alliances), or exploration mastery (ruin discoveries).
  - Unlock "Achievements/Hommage" submenu in MainMenu.tscn, replaying maps with bonuses (e.g., "River Trader Legacy" starts with brewing upgrades).
- **Procedural Elements**: Full isometric world/town gen (Phase 4) creates infinite replay loops, with moddable biomes and features (e.g., custom rivers/plazas via JSON).
- **Player Experience**: Dynamic challenges (e.g., escalating taxes in Noble territories) keep optimization rewarding. Community mods add variety, avoiding Fort of Chains’ end-game gap.
- **Transition**: Legacy completion loops back to MainMenu.tscn, encouraging new seeds or "hommage" replays.

---

## 🔄 **Procedural Replay Loop**
- **MainMenu.tscn**: "Achievements/Hommage" button tracks completed settlements, allowing replays with saved seeds and biome-specific bonuses (e.g., forest maps boost herb yields). This fosters replayability across 20-30 procedural towns.
- **WorldGenerateMenu.tscn**: Seed input generates unique ASCII maps, with town selection locking in narrative/aesthetic variations (e.g., river biomes for trade, ruin-heavy for lore).
- **Loop Closure**: Each playthrough ends with a legacy summary, feeding into the "hommage" system for iterative storytelling.

---

## 🎮 **Gameplay Integration**
- **Character Depth**: Adventurers gain personalities through town interactions (e.g., a rogue thrives on espionage quests), avoiding stat-only designs.
- **Resource System**: Post-MVP, gathered herbs/hops unlock brewing upgrades (e.g., cider in orchard biomes), tying economics to exploration.
- **Difficulty Scaling**: Taxes and events scale with progress, with recovery mechanics (e.g., loan options) to avoid punishing failures.

---

## 🛠 **Modding Support**
- **Act I**: Modders can add daily event pools in JSON (e.g., `events.json`).
- **Act II**: Custom town features (rivers, plazas) via `locations.json`.
- **Act III**: Full world gen mods with API hooks for new biomes/quests.

---

## 💡 **Key Takeaways**
- Progression balances tutorial depth with open-ended exploration.
- Procedural "chances" (events, maps) ensure varied, meaningful play.
- Replayability via "hommage" supports all victory paths, preventing late-game stagnation.

---

**Conclusion**: This 3-act structure evolves from a cozy tavern start to a dynamic world, leveraging procedural generation for a rich, replayable narrative. Future phases will expand modding and isometric visuals, aligning with Eternal Guild’s community-driven vision.