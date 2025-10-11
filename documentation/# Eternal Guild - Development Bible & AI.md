# Eternal Guild - Development Bible & AI Context

## Purpose
This document serves as the authoritative reference for AI assistance on the Eternal Guild project, maintaining context across conversations and ensuring consistent, strategic development advice.

## Project Vision & Strategic Goals

### Core Innovation: Procedural World Choice System
- **20-30 unique settlements** at game start, each fundamentally altering gameplay
- **Settlement variety affects**: Economic systems, political situations, cultural backgrounds, faction relationships, story arcs, available missions, NPC types
- **Multiple victory paths**: Economic dominance, military conquest, political influence, exploration mastery
- **Long-term goal**: Evolution from single game to community content platform

### Architecture Principles
1. **Data-driven design** - All content in JSON files for modding support
2. **Singleton state management** - GameManager as single source of truth
3. **Signal-based UI updates** - Loose coupling between systems
4. **Modular scene structure** - Supporting future procedural world
5. **Performance scalability** - Designed for 20-30 settlements

## Current Implementation Status

### ✅ WORKING SYSTEMS
- **GameManager singleton** - Core state management with signal-based updates
- **DataManager singleton** - JSON content loading system
- **Basic recruitment** - Connected to DataManager's daily_recruits
- **Mission assignment** - Basic solo/party mission system
- **Basic tavern economics** - Gold and beer management
- **Day counter** - Mechanical progression (no visual day/night)
- **UI popups** - Beer management, recruitment, mission board
- **Single patron spawning** - Can spawn, walk, sit (but no service/conversation)

### ⏳ IN TESTING/BALANCING
- **Economic balance** - Currently playtesting mission rewards vs. costs
- **Mission difficulty** - Testing success rates and consequences

### ❌ PENDING CORE FEATURES
- **Patron interactions** - Service, payment, conversations, quest-giving
- **Save/Load system** - Complete state persistence
- **Adventurer mortality** - 30-40% death rate for level 1 on basic missions
- **Daily wages** - 1 gold + 1 beer per adventurer per day
- **Beer shortage consequences** - Morale penalties, adventurer desertion
- **Tax escalation** - Progressive increases (75g day 30, 150g day 60, 300g day 90)

### ❌ PENDING EXPANSION FEATURES
- **Settlement system** - 20-30 unique starting locations
- **World map generation** - Procedural or pre-designed settlement layouts
- **Outdoor areas** - Beyond the tavern walls
- **Multiple simultaneous patrons** - 2-3 customers at once
- **Conversation system** - Dynamic dialogue with patrons
- **Quest-giving patrons** - NPCs offering unique missions
- **Reputation tracking** - Affects available missions and patron types
- **Guild rank system** - Clay to Orichalcum progression
- **Visual day/night cycle** - Lighting and atmosphere changes
- **Equipment system** - Gear affecting mission success
- **Retirement mechanics** - Veteran adventurers leaving

## Technical Architecture

### File Organization
```
res://
├── scripts/
│   ├── GameManager.gd        # Autoload singleton - WORKING
│   ├── systems/
│   │   └── DataManager.gd    # Autoload singleton - WORKING
│   ├── game/
│   │   └── main_tavern.gd    # Scene coordinator
│   ├── npcs/
│   │   ├── RealisticPatron.gd # PARTIAL - movement works, no interaction
│   │   └── PatronSpawner.gd   # WORKING - single patron spawning
│   └── ui/                    # All popup systems WORKING
├── data/                      # JSON files for all content
└── assets/                    # KayKit models, textures, audio
```

### Current Technical Constraints
- **Engine**: Godot 4.3+
- **Art style**: 3D isometric with KayKit models
- **Performance**: Must maintain 60 FPS with atmospheric effects
- **Target**: Desktop first, future mobile consideration

## Design Philosophy

### Core Gameplay Loop Philosophy
**"Meaningful pressure creates engaging stories"**
- Economic pressure forces strategic decisions
- Adventurer permadeath creates emotional investment
- Resource scarcity drives player engagement
- Failure leads to narrative opportunities, not dead ends

### Progression Philosophy
1. **Tutorial Phase** (Days 1-30): Safe learning environment
2. **Consequence Phase** (Post-tax): Real risks and rewards
3. **Mastery Phase** (Days 60+): Complex strategic management
4. **End Game**: Demon Lord preparation requiring deep strategy

### Economic Balance Targets
- Players CANNOT survive without both tavern income AND missions
- Beer shortage should occur if poorly managed
- Tax payments should require planning, not luck
- Adventurer wages create constant pressure

## Development Priorities

### Immediate Priority: Core Loop Completion
1. **Complete patron interaction cycle** - Service, payment, conversations
2. **Implement save/load system** - Essential for testing
3. **Add adventurer daily costs** - Wages and beer consumption
4. **Implement death/injury system** - Make missions meaningful

### Phase 2: Economic Pressure Systems
1. **Tax escalation implementation**
2. **Beer shortage consequences**
3. **Reputation tracking**
4. **Mission tier gating**

### Phase 3: Content Expansion
1. **Multiple patron types** - Merchants, quest-givers, nobles
2. **Conversation system** - Dynamic dialogue
3. **Settlement data structure** - Prepare for procedural world
4. **Guild rank progression**

### Phase 4: Procedural World
1. **Settlement selection screen**
2. **Location-specific content**
3. **Faction systems**
4. **Multiple victory conditions**

## Known Issues & Decisions Needed

### Questions for Development
1. **Beer units**: Currently ambiguous - pints or kegs? (Leaning toward pints for clarity)
2. **Mission duration**: Real-time or day-based? (Currently day-based)
3. **Conversation depth**: Simple branches or complex state tracking?
4. **Save system**: JSON or Godot's native .tres format?
5. **Settlement generation**: Fully procedural or hand-crafted templates?

### Economic Questions
- What's the right mission reward range? (Currently testing)
- Should adventurers consume beer while on missions? (Prevents exploit)
- How harsh should failure consequences be? (Death vs. injury rates)

## AI Assistant Guidelines

### When Providing Solutions
1. **Always consider procedural world scalability** - Will this work with 30 settlements?
2. **Maintain data-driven architecture** - Content in JSON, logic in code
3. **Use GameManager for state** - Single source of truth
4. **Think about modding** - Can community extend this?
5. **Check existing systems** - Reuse before creating new

### Response Framework
1. **Acknowledge strategic vision** - Start with long-term impact
2. **Evaluate current state** - What's working vs. what's needed
3. **Provide phased implementation** - MVP → Full feature
4. **Consider performance** - 60 FPS with full effects
5. **Document for modders** - Clear, extensible patterns

### Testing Recommendations
- Test with 0 gold scenarios (should fail quickly)
- Test with 0 beer scenarios (adventurers should leave)
- Test 30-day survival (should require active management)
- Test with multiple simultaneous missions
- Test save/load at various game states

## Version History
- **Current Phase**: Core mechanics implementation
- **Last Major Update**: Recruitment system connected to DataManager
- **Active Development**: Economic balance playtesting
- **Next Milestone**: Complete patron interaction cycle

---

*This document is the single source of truth for the Eternal Guild project state and should be updated as systems are completed or requirements change.*