# Eternal Guild

A challenging 3D isometric tavern management game with hardcore adventurer simulation, inspired by Dwarf Fortress, Rimworld, and classic roguelikes.

## Overview

Manage your guild tavern while sending adventurers on dangerous missions in a world where every decision matters and death is permanent. Built with Godot 4.3+ and designed around the philosophy that meaningful challenge creates the best stories.

## Current Status: Alpha Development

**Core Systems Operational:**
- Complete patron service cycle (spawn, serve, payment)
- Mission assignment and resolution system
- Recruitment system with daily applicants
- Economic management (beer, gold, daily costs)
- Day/night progression cycle

**Known Critical Issues:**
- Economic imbalance (missions too profitable vs operating costs)
- Missing adventurer wage system
- No save/load functionality
- Performance lag during NPC spawning

## Key Features

### Tavern Management
- Serve patrons to generate income and reputation
- Manage beer inventory and daily operating costs
- Build relationships with customers for recruitment opportunities

### Adventurer System
- Hire from daily applicants with varying skills and costs
- Send adventurers on missions ranging from simple escorts to deadly investigations
- Permanent death system - lose an adventurer, they're gone forever
- Character progression through surviving dangerous encounters

### Economic Pressure
- Progressive tax system requiring careful resource management
- Daily wages and beer consumption for adventurers
- Reputation-gated access to higher-paying missions
- Multiple failure states leading to bankruptcy or closure

### Hardcore Difficulty Philosophy
- Level 1 adventurers: 30-40% death rate on basic missions
- Beer shortages cause immediate morale and performance penalties
- Economic decisions have lasting consequences
- Inspired by "dying is fun" roguelike design principles

## Technical Architecture

**Engine:** Godot 4.3+
**Architecture:** Singleton-based state management with data-driven content
**Art Style:** 3D isometric with pixel-perfect rendering and Studio Ghibli-inspired atmosphere
**Target Platform:** Desktop (Windows, Mac, Linux)

### Core Systems
- **GameManager:** Centralized state management and game logic
- **DataManager:** JSON-based content loading for easy modding
- **Signal-based UI:** Reactive interface responding to game state changes
- **Modular Design:** Built for future procedural world expansion

## Development Roadmap

### Immediate Priorities (Week 1)
1. Fix critical bugs preventing normal gameplay
2. Implement adventurer daily wages system
3. Rebalance mission rewards vs operating costs
4. Add harsh consequences for resource mismanagement

### Short-term Goals (1 Month)
- Complete economic rebalancing for meaningful resource pressure
- Implement save/load system
- Add adventurer roster management UI
- Enhanced mission departure and return narratives
- Performance optimization for smooth NPC interactions

### Long-term Vision (6+ Months)
- **Procedural World Choice System:** Select from 20-30 unique settlements, each offering completely different gameplay experiences
- **Community Modding Support:** Data-driven architecture enabling easy content creation
- **Multiple Victory Paths:** Economic dominance, military conquest, political influence, exploration mastery

## Installation & Setup

**Requirements:**
- Godot 4.3 or later
- Windows 10+, macOS 10.15+, or modern Linux distribution
- 2GB RAM minimum, 4GB recommended
- OpenGL 3.3 compatible graphics card

**Getting Started:**
1. Clone the repository
2. Open project in Godot 4.3+
3. Run the main scene (`scenes/MainTavern.tscn`)
4. Start with the tutorial or jump into sandbox mode
5. Some files are missing, just ask me for them.

## Controls

- **WASD:** Move player character
- **E:** Interact with patrons, furniture, and interfaces
- **ESC:** Pause menu
- **F11:** Debug spawn patron (development only)

## Game Design Philosophy

Eternal Guild embraces the philosophy that meaningful challenge creates the most engaging stories. Drawing inspiration from Dwarf Fortress ("losing is fun"), Caves of Qud, and Rimworld, every setback becomes a narrative opportunity.

**Core Principles:**
- Economic pressure forces strategic thinking
- Adventurer permadeath creates emotional investment
- Resource scarcity drives meaningful choices
- Failure states provide learning opportunities, not dead ends

## Contributing

Currently in early alpha with focus on core mechanics. Future plans include:
- Community content creation tools
- Modding API and documentation
- Settlement and mission editor
- Open-source release after core stability

## Architecture Notes

Built with future procedural world expansion in mind:
- All content defined in easily modifiable JSON files
- Clean separation between game logic and presentation
- Signal-based communication for loose coupling
- Modular scene structure supporting custom content

## License

[License TBD - Currently private development]

## Credits

**Development:** Raphael RECK.
**Art Assets:** KayKit Adventurers, KayKit Skeletons
**Engine:** Godot Engine
**Inspiration:** Dwarf Fortress, Rimworld, Caves of Qud, Stardew Valley

---

*"Every adventurer's death tells a story. Every tavern serves a purpose. Every choice echoes through the guild's legacy."*