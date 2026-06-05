# Game Design Document: Chronicles of the Eternal Guild (Master Document)

### **Version: 1.1**
### **Last Updated: June 2026**

> **Version 1.1 note:** Repaired a corruption in Section 6 (the full text of Section 2 had been accidentally pasted into the architecture paragraph). Added World Map dispatch references and updated the roadmap. Encoding cleaned up.

---
## 1. Game Overview
* **Game Title**: Chronicles of the Eternal Guild
* **Pitch**: An 80's anime-inspired (*Studio Ghibli*, *Record of Lodoss War*) tavern management sim where you manage unique, evolving adventurers, uncover ancient mysteries, and build a legendary guild.
* **Genre**: Management Simulation, Adventure, Strategy, RPG
* **Platform**: PC (initial)
* **Target Audience**: Fans of strategy and management sims who crave deeper character stories and replayability (e.g., players of *Rimworld*, *Stardew Valley*, *Darkest Dungeon*, *Spiritfarer*).

---
## 2. Core Concepts & Vision

### 2.1 Design Pillars
* **Curiosity & Discovery**: Players are constantly driven to see what's next, from uncovering "Prior" ruins to encountering unique narrative events.
* **Meaningful Management**: The design philosophy is "**meaningful pressure creates engaging stories**." Economic hardship and dangerous quests force strategic decisions that lead to emergent narratives.
* **Deep Character Investment**: Players will care about their adventurers as individuals, not just statistics, through unique personalities and personal story arcs.
* **Complicity & Consequence**: The player is the enabler of heroes, not the hero. The emotional core is sending younger adventurers into danger and living with the results — surfaced most sharply in the end-of-day reveal.
* **Massive Replayability**: The long-term **Procedural World Choice System** is intended to make every playthrough fundamentally different.

### 2.2 Target Audience & Player Motivation (Bartle's Taxonomy)
* **Achiever**: Optimizing the tavern economy and progressing through increasingly dangerous missions provides a clear ladder of mastery.
* **Explorer**: The (future) Procedural World Choice System and the "Journey Through the Arcana" reward the desire to see everything.
* **Socializer**: The character-centric design lets players build a "found family" they care about.
* **Killer**: Dominating the game's systems, manipulating factions, and out-competing rival NPCs.

---
## 3. Gameplay Systems

### 3.1 The Core Loop
1.  **Recruit & Interact**: Meet unique adventurers.
2.  **Prepare & Dispatch**: Open the **World Map** and assign adventurers to missions at surrounding locations.
3.  **Tavern Management**: Serve patrons, manage resources, and maintain comfort.
4.  **Mission Resolution**: Missions auto-resolve, influencing adventurer growth.
5.  **Return & Consequences**: Adventurers return changed, revealed one by one in the end-of-day report; success can unlock lore and story quests.

### 3.2 Tavern Management
* **Patron Service Cycle**: Up to 5 simultaneous patrons, with planned expansion.
* **Economy & Resources**: Gold, Beer, and an escalating Tax system create the core economic challenge.
* **Firewood & Comfort System**: ✅ Implemented. Firewood keeps the fireplace lit, generating a "Comfort" level that multiplies tips. A relight mini-game is planned.

### 3.3 Adventurer Management & Dispatch
* **Recruitment, Consequences & Progression**: Hiring, daily costs, injury, and death are implemented.
* **World Map Dispatch**: Missions are dispatched through a full-screen hex World Map that replaces the old mission-board popup. Surrounding locations show daily-refreshing mission cards; the roster appears as draggable tokens; on-mission adventurers are greyed out with a return counter. (See Sections 2, 4, 5, 7 of the GDD.)
* **Character Progression: "Journey Through the Arcana"**: Core adventurers are represented by evolving Tarot portraits, from novice (Minor Arcana) to master (Major Arcana) — or corruption (Reversed). Designed to create deep character investment.

---
## 4. Story, Setting, & Progression

### 4.1 World & Narrative
An 80's anime-inspired fantasy world. Narrative is delivered through **2D/Text-based event scenes** with character dialogue and narration.

### 4.2 Progression: The First 30 Days
* **The Indoor Phase**: For the first 30 days, the player is confined to the tavern interior, forcing mastery of the core economic loop.
* **Unlocking the World**: Surviving the first 30-day tax cycle unlocks exterior exploration.

### 4.3 The "Priors" Lore System
Once outside is unlocked, major tavern renovations uncover the ruins of the precursor "Prior" civilization, kicking off the deeper archaeological mystery.

---
## 5. Art & Interaction

### 5.1 Visual Style
A 2.5D cinematic style inspired by Studio Ghibli and *Record of Lodoss War*, executed via a 3D environment with a custom pixel-art shader — high-resolution pixel art illustration with sharp volumetric shading, complex dithering, and a rich palette. Current direction layers a Hellsing × Hellboy ink treatment over this base.

### 5.2 Interaction System
The player controls an avatar in 3D space, interacting via proximity and "E". Visual feedback (floating icons, glowing runes) guides the player; **still needs implementation for the Fireplace.** Mission dispatch is handled through the World Map (§3.3).

### 5.3 Embodied Dispatch (Future, Deferred)
The atmosphere goal of seeing adventurers sit, rest by the fire, and physically walk out to their missions is deferred cosmetic scope, built as a visual listener on the dispatch event once the core loop is proven. The data model is being built now to keep this option open without a rewrite.

---
## 6. Technical Design & Architecture

### 6.1 Engine & Architecture
* **Engine**: Godot 4.4.
* **Architectural Strategy**: A system of multiple focused singleton managers (`GameManager`, `DataManager`, `PlayerManager`, `SaveSystem`, `WorldManager`) for Separation of Concerns, communicating through Godot signals. Dispatch is a single authoritative event that all front-ends (mission board, World Map, briefing, future visuals) listen to.

### 6.2 Data-Driven Design & Modding
All content is driven by external JSON files — crucial for systems like "Journey Through the Arcana" and the foundation for future modding. The World Map's `map_locations` is generated once per save and persisted from day one. (See `05_Technical_Architecture.md`.)

---
## 7. Project Status & Roadmap

### 7.1 Working Systems
* **Patron System**: Functional (up to 5 patrons).
* **Economic System**: Core mechanics operational.
* **Core Consequences**: Injury, death, daily costs implemented.
* **Tax System**: Basic escalating tax implemented.
* **Firewood System**: Working.
* **Party Mission UI / F12 Debug / Morning Briefing**: Implemented.
* **Save/Load System**: Functional, needs polish.

### 7.2 Immediate Priorities (Phase 0 / Phase 1)
1.  **World Map dispatch screen** — build data layer first (`map_locations`, save/load, per-location mission assignment), then placeholder map, then postits/drag, then KayKit hex tiles. Replaces the mission-board popup.
2.  **End-of-day mission report** — the emotional centrepiece; one-by-one reveal.
3.  **Fireplace** — visual interaction feedback + relight mini-game; clean up competing fireplace systems.
4.  **Exterior world** — NPC flow and "breathing life."

### 7.3 Future Scope (do not build yet)
Settlement choice at game start; full procedural world (20–30 settlements); faction systems; embodied dispatch (walk-off); modding platform. These remain the north star but must not block the core loop.
