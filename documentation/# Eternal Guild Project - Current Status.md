# Eternal Guild Project - Current Status & Implementation Guide

## Project Overview
**Game:** Chronicles of the Eternal Guild - Isometric 3D tavern management game  
**Engine:** Godot 4.3+  
**Art Style:** Studio Ghibli-inspired pixel art with 3D KayKit character models  
**Current Phase:** NPC patron system implementation  

## Current Working Systems

### Player Character System ✅
- **Character:** KayKit Rogue model with SpringBone physics (for now)
- **Movement:** Isometric WASD controls with smooth rotation
- **Physics:** Working gravity, collision, and floor detection
- **Script:** `player.gd` with complete movement and rotation system 
- **Scene Structure:**
  ```
  Player (CharacterBody3D) + player.gd
  ├── CollisionShape3D (CapsuleShape3D)
  └── Rogue (Node3D) - KayKit model with SpringBones
  ```

### Game Mechanics ✅
- **Gold System:** Working currency with UI display
- **Beer Management:** Purchase/stock system (5 gold per beer)
- **Day/Night Cycle:** Functional progression system
- **Mission System:** Adventurer recruitment and quest assignment
- **UI Systems:** Recruitment popup, mission board, beer management
- **Event Log:** In-game message system for player feedback

### Tavern Environment ✅
- **3D Tavern:** Complete interior with furniture and lighting
- **Tables:** Located at coordinates like (0, 0, 3.059)
- **Interaction Zones:** Bar, mission board, recruitment desk
- **Collision System:** Environment uses collision layer 2

## Assets Available

### KayKit Character Models
- **Player:** Rogue (currently implemented)
- **Available NPCs:** Knight, Barbarian, Archer, Mage
- **Skeleton Pack:** Additional character variants
- **Format:** .glb files
- **Location:** `res://assets/characters/models/kaykit_adventurers/`

## Current Implementation Target

### NPC Patron System Requirements
Based on user specifications:

1. **Spawning Pattern:**
   - One patron at a time only 
   - ~30-second intervals between spawns (Manually set for now F11)
   - No overlapping customers

2. **Movement Behavior:**
   - Spawn at tavern entrance
   - Walk to specific table coordinates (~aprox 0, 0, 3.059) 
   - Sit down (visual scale change to 0.7 height) (needs to be tested)

3. **Service Interaction:**
   - Show yellow sphere indicator above head (TODO ASAP)
   - Wait indefinitely for player service (no timeout) (need to fix)
   - Player presses E within 2-unit range to serve
   - Requires beer inventory to complete service (check this in the code please.)

4. **Economic Integration:**
   - Payment: 6 gold base + 1-3 gold tip = 7-9 gold total
   - Beer cost: 5 gold (1-4 gold profit margin)
   - Integrates with existing gold/beer systems

5. **Exit Behavior:**
   - After service: Drink for 8 seconds, pay, leave satisfied
   - If dismissed: Leave without payment
   - Walk to entrance and despawn

## Implementation Files

### Required Scripts
1. **RealisticPatron.gd** - Main NPC behavior class
2. **SinglePatronSpawner.gd** - Spawn management system  
3. **Player.gd updates** - Service interaction code

### Scene Structure
```
MainTavern.tscn
├── Player (existing)
├── Furniture (existing)
├── Interactive (existing)
└── PatronSpawner (new Node3D)
    └── [Spawned patrons appear here]
```

### Collision Layer Setup
- **Layer 1:** Player character
- **Layer 2:** Environment (floors, walls, furniture)
- **Layer 4:** NPC patrons
- **Masks:** Player collides with 2,4; NPCs collide with 2; Environment collides with nothing

## Technical Specifications

### Movement System
- **Speed:** 2.0 units/second for NPCs
- **Rotation:** Smooth interpolation to face movement direction
- **Physics:** CharacterBody3D with CapsuleShape3D collision
- **Pathfinding:** Direct movement to hardcoded coordinates

### Visual System
- **Model Loading:** KayKit .glb files with fallback to colored capsules
- **SpringBone Support:** Disable collision conflicts while preserving physics
- **Service Indicator:** Procedurally generated yellow sphere
- **Scaling:** Sitting simulation via Y-scale reduction

### Integration Points
- **Gold System:** `main_scene.update_gold(amount)`
- **Beer System:** `main_scene.get_current_beer()` and `main_scene.update_beer(-1)`
- **Logging:** `main_scene.log_message(text)`
- **Input:** Uses existing "interact" action (E key)

## Next Implementation Steps

### Phase 1: Basic Patron
1. Created `RealisticPatron.gd` script file
2. Created `SinglePatronSpawner.gd` script file
3. Add PatronSpawner Node3D to main scene
4. Update player.gd with service interaction code
5. Test single Knight patron workflow

### Phase 2: Multiple Character Types
1. Extend system to use different KayKit models
2. Add character-specific behaviors and payment amounts 
3. Implement variety in patron names and personalities
4. Implement story mode, characters walk in, give missions or consume beer, or are adventurers.

### Phase 3: Advanced Features
1. Multiple table support with seat management
2. Quest request system integration

## Current Blockers/Considerations

### Pending Decisions
- Service indicator implementation (code vs scene-based)
- Table/seat management for multiple patrons un clear collision... 
- Integration with existing mission/quest systems
- Visual feedback for service interactions

## File Locations
- **Player Script:** `player.gd` (attached to Player CharacterBody3D)
- **Main Scene:** `MainTavern.tscn`
- **Assets:** `res://characters/models/kaykit_adventurers/`
- **New Scripts:** To be created in `res://characters/npcs/`

The project is ready for NPC patron implementation with all prerequisite systems functional and tested.