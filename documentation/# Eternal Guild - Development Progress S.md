# Eternal Guild - Development Progress Summary

**Date:** Current Session  
**Status:** MVP Tavern Layout & Firewood System Planning

---

## Current State

### Working Systems
- ✅ Pixel art shader operational (3D-to-pixel pipeline)
- ✅ GameManager singleton with core state management
- ✅ DataManager with JSON content loading
- ✅ Patron service cycle (spawning, serving, payment)
- ✅ Beer management system
- ✅ Mission assignment system
- ✅ Recruitment system
- ✅ Day progression mechanics
- ✅ Fire place system
- ✅ KayKit character models rendering through pixel shader

### Visual Style Established
- Isometric 3D camera with pixel art post-processing
- Reference: "The Queen's Inn" layout (circular bar, functional zones)
- Warm orange lighting (fireplace/tavern atmosphere)
- Cyan/blue accent colors (magical/ancient elements)
- Pixel shader handles all art style conversion

---

## Current Work-in-Progress

### Circular Bar Counter
**Status:** MVP working. First level achived. Lore and Story needed. 


**Next Step:** 
- Make characters and story and lore around them
- Generate a list of easter eggs for the players to unlock.
- Work on the procedural world for replayability.

---

## Planned Systems (Not Yet Implemented)

### Story mode & Procedural map Systems
**Design Complete - Implementation Pending**

**Core Mechanics:**
- Resolution of missions with overlay and story mode.
- Before each new game, generate a map from a "seed" selection
- Allow the player to choose certain locations on the map for his tavern/guild to spawn at.
- 
**Procedural map:**
- Hide Fibonnacci or mandelbrots in the code to generate the maps, 
- Keep it simple MVP for now. (see rimworld alpha map)
- Once player acknowledge terrain, with "indivdual traits

**Interaction Points:**
- World Map, each location has description of it's influence etc. see GDD file.
- click on city, small description and type of influence is has on mission possibilities. => Accept go into tavern.

### World Map Management Interface


**Contents:**
- Beer stock purchasing (existing)
- Firewood purchasing (new)
- Purchase restriction: Once per morning flag

### Your Quarters Hub
**Multi-tab management interface**

**Tabs:**
- Rest: End day, advance time
- Finances: Daily income/expense review
- Upgrades: (Unlocks day 30) - Not implementing yet
- Renovations: (Unlocks later) - Future feature

---

## Layout Design Decisions

### Single-Floor Tavern (Current MVP)
```
Entrance → Main hall with circular bar (center-right)
         → Fireplace (left side)
         → Patron tables (center)
         → Desk + Mission Board (back wall alcoves)
         → Your Quarters door (back corner)
```

**Functional Zones:**
1. Beer barrels → Tavern Management popup
2. Fireplace → Stoke fire (immediate action)
3. Recruitment desk → Recruitment popup
4. Mission board → Missions popup
5. Your Quarters → Management hub
6. Patrons → Direct service

### Visual Clarity System (Planned)
**All zones get:**
- Floating 3D icon (beer mug, flame, scroll, sword, bed)
- Blue rune glow on floor when player approaches
- "E - [Action]" prompt on proximity
- Distinct lighting per zone

---

## Key Design Principles Established

### The Prior Door Narrative
- Ancient civilization called "The Priors"
- Tavern built on Prior foundations
- Discovery triggers: Excavation renovations (future)
- First discovery: Cellar with Prior door (200g unlock)
- Deeper mysteries: 500g, 1000g excavations
- Settlement-specific Prior ruins for replayability

### Progression Philosophy
**Early game:** Hands-on management (serve, maintain fire, recruit)  
**Mid game:** Strategic decisions (firewood quantity, budget allocation)  
**Late game:** (Not designed yet - automation deferred)

### Manager's Journey Vision
- Start: Solo tavern keeper doing everything
- Growth: Tavern expands, unlocks new management layers
- Shift: From active tasks to strategic oversight
- Foundation for settlement expansion system

---

## Technical Decisions Made

### Architecture
- Single-floor tavern for MVP (multi-level deferred)
- CSG for rapid prototyping, Blender for final assets
- Pixel shader handles all visual consistency
- JSON-driven content for modding support

### Interaction System
- Proximity-based zones with E key interaction
- Immediate actions (stoke fire, serve patron)
- Popup menus (tavern management, recruitment, missions, quarters)
- No tutorial - visual affordances teach organically

### Economic Balance Target
**Daily flow:**
- Income: 40-60g (beer + tips)
- Expenses: 15-25g (wages)
- Firewood: 5-25g (1-5 bundles, player choice)
- Net profit: 10-30g per day

---

## Immediate Next Steps

### Tomorrow (Blender Work)
- [ ] Model circular bar counter with proper entrance gap
- [ ] Create collision mesh (cylinder ring with opening)
- [ ] UV unwrap for pixel art textures
- [ ] Export as `.glb` with collision
- [ ] Import to Godot, replace CSG prototype

### This Week (Firewood Implementation)
- [ ] Add firewood variables to GameManager
- [ ] Implement fuel drain (0.5% + 0.1% per patron)
- [ ] Calculate comfort level from fuel percentage
- [ ] Wire comfort to tip multiplier
- [ ] Update Tavern Management popup (add firewood purchase)
- [ ] Create fireplace interaction zone
- [ ] Add visual states (fire intensity, particles, lighting)
- [ ] Add UI overlay (firewood stock, fuel %, comfort %)

### Testing Phase
- [ ] Playtest 10 full day cycles
- [ ] Validate: Is fire maintenance engaging or tedious?
- [ ] Balance: Firewood cost vs tip income math
- [ ] Identify: What friction points exist?
- [ ] Decide: Does layout need redesign or just polish?

---

## Deferred Features

### Automation Systems
- Staff hiring (barmaid, fire tender, cook)
- Automated patron serving
- Automated fire maintenance
**Reason:** Prove manual loop works first

### Multi-Level Expansion
- Upper floor (quarters, storage)
- Cellar (beer storage, Prior door)
- Kitchen wing
**Reason:** Single floor sufficient for MVP

### Outdoor Zones
- Town square, market, farm
- Settlement travel system
**Reason:** Unlock after Goal 3 (10 missions complete)

### Advanced Content
- Food service system
- Multiple settlements
- Procedural world choice
**Reason:** Core loop must be proven first

---

## Open Questions

### Design Decisions Needed
1. Firewood purchase timing: Morning prep or night planning?
   - **Current lean:** Morning via Tavern Management
2. Fireplace stoke animation: Instant or 2-second kneel?
   - **Current lean:** Short animation for tactile feel
3. Quarters tabs: All visible or progressive unlock?
   - **Current lean:** Progressive (Rest always, others unlock)

### Balance Tuning Required
- Fuel consumption rate (is 0.5% + 0.1%/patron right?)
- Firewood bundle cost (is 5g balanced?)
- Comfort impact curve (linear or exponential?)
- Patron count variation (predictable or random?)

---

## Success Metrics

### MVP Firewood System Works If:
- Player makes meaningful choice about firewood quantity
- Fire maintenance creates engagement (not ignored)
- Economic impact is noticeable (comfort affects income)
- Running out feels consequential but recoverable
- System doesn't become tedious after 5 days

### MVP Layout Works If:
- Player always knows where interactive zones are
- Navigation feels natural (no getting stuck)
- Camera angle makes all zones visible
- Circular bar creates clear focal point
- Space feels cozy, not cramped

### Overall MVP Success:
- Complete gameplay loop: Morning prep → Serve patrons → Maintain fire → Manage adventurers → End day → Repeat
- Player session lasts 10+ days without frustration
- Core systems proven before expanding complexity
- Foundation supports future settlement expansion

---

## Notes & Insights

### What's Working
- Pixel shader eliminates art style concerns
- CSG prototyping enables fast iteration
- GameManager architecture handles complexity well
- Reference images provide clear visual target

### What's Challenging
- Balancing active tasks vs strategic planning
- Collision for circular/complex shapes
- Knowing when to polish vs keep iterating
- Avoiding feature creep (automation, expansions, etc.)

### Key Learnings
- "Pretty enough" beats "perfect but never shipped"
- Test gameplay before committing to final art
- CSG → Blender workflow enables fast validation
- Circular bar is visual anchor that defines space
- Firewood system adds engagement between patron visits

---

## Current Blockers

**None - Clear path forward:**
1. Build Blender bar model (tomorrow)
2. Implement firewood system (this week)
3. Playtest for 10 days (end of week)
4. Iterate based on findings

---

## Repository Status

**Assets:**
- KayKit character models operational
- Pixel shader working
- CSG circular bar prototype (temporary)
- Basic tavern floor/walls

**Scripts:**
- GameManager.gd (core state)
- DataManager.gd (JSON loading)
- RealisticPatron.gd (NPC behavior)
- Beer/Recruitment/Mission popups functional

**To Add:**
- Fireplace fuel system
- Tavern Management rename/expansion
- Your Quarters multi-tab interface
- Visual zone indicators (icons, runes, glows)

---

## Long-Term Vision Reminder

**Core Innovation:** Procedural world choice system
- 20-30 unique settlements
- Each alters entire gameplay experience
- Different economies, politics, cultures, factions
- Settlement-specific Prior ruins
- Multiple victory paths per location

**This MVP proves:** Can one tavern location be engaging enough to warrant building 20-30 variants?

**If yes:** Scale to full vision  
**If no:** Redesign core loop before expanding