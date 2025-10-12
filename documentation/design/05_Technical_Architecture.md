# GDD Section 5: Technical Architecture

### **Version: 1.0**
### **Project: Chronicles of the Eternal Guild**

---
## 1. Engine & Core Specifications

* **Engine**: Godot 4.3+ (3D with isometric projection).
* **Rendering**: The 2.5D aesthetic is achieved through a custom pixel-art shader with pixel-perfect rendering and nearest-neighbor filtering enabled globally.
* **Performance Target**: The game must maintain a stable 60 FPS with full atmospheric effects enabled.
* **Memory Management**: Systems are designed for efficient NPC spawning and de-spawning cycles to manage memory usage, particularly as the number of patrons and adventurers grows.

---
## 2. Architectural Strategy

### 2.1 Multiple Singleton Managers
The game uses a system of multiple, focused singleton managers (e.g., `TavernManager`, `MissionManager`, `DataManager`) to ensure the codebase is organized, maintainable, and scalable. This is a robust and proven design pattern for achieving **Separation of Concerns**, preventing a single monolithic manager from becoming bloated and difficult to debug.

### 2.2 Signal-Based Communication
To ensure systems are loosely coupled, the architecture heavily relies on Godot's built-in signal system. Game logic managers (like `GameManager`) will emit signals when the state changes (e.g., `gold_updated`), and UI systems will connect to these signals to update their presentation. This prevents UI code from directly controlling game logic, leading to a cleaner, more stable event flow.

---
## 3. Data-Driven Design & Modding Support

### 3.1 JSON-Based Content
All game content—including missions, adventurer classes, items, dialogue, and settlement data—is driven by external data files, primarily in JSON format.

### 3.2 Dual Purpose
This data-driven approach serves two critical functions:
1.  **Internal Development**: It allows for rapid iteration and management of complex, interconnected systems like the "Journey Through the Arcana" without requiring code changes for content adjustments.
2.  **Future Modding**: It is the foundational requirement for building a thriving modding community. By separating data from code, the architecture is inherently open to community-created content, a key lesson learned from the success of games like *Fort of Chains*.

---
## 4. Asset & Project Organization Standards
The project adheres to a clean and predictable folder structure to ensure maintainability.
```
res://
├── assets/
│   ├── audio/
│   ├── characters/
│   ├── environment/
│   ├── portraits/
│   └── ui/
├── data/
│   ├── characters/
│   ├── dialogue/
│   ├── economy/
│   ├── missions/
│   └── settlements/
├── documentation/
│   ├── # Eternal Guild - Development Bible & AI.md
│   └── # Game Design Document (GDD).md
├── scenes/
│   ├── player/
│   └── ui/
└── systems/
├── DataManager.gd
├── GameManager.gd
└── SaveSystem.gd
```
*(Note: This is a simplified representation of the full project structure outlined in another document.)*