# GDD Section 4: Art & Interaction

### **Version: 1.0**
### **Project: Chronicles of the Eternal Guild**

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

---
## 3. Interaction & User Feedback

### 3.1 Core Interaction Mechanic
The player controls an avatar in a 3D space. Interaction with key objects (mission board, bar, patrons, fireplace) is handled via proximity detection and a single key press ("E").

### 3.1.1 Mission Board UI Layer
Activating the mission board opens a compound UI with two panels visible simultaneously:
* **Left panel — Active Deployments**: Lists all groups currently on missions sorted by soonest expected return. Each row shows the lead adventurer portrait, mission name, and a return countdown with a status pip (🟢 On Track / 🟡 Delayed / 🔴 Overdue).
* **Right panel — Available Missions**: The standard list of postable contracts.
* The Guild Book (roster card grid, organized by suit/class with status filters) is accessible from a tab or button within this same screen, keeping all dispatch-related information in one place.

### 3.2 Organic Tutorial System
To avoid a traditional, text-heavy tutorial, the game will use a system of clear visual cues to guide the player.
* **Visual Feedback**: Interactive zones will be highlighted with floating icons and/or glowing runes on the floor when the player is near.
* **Status**: This system is functional for most zones but **needs to be implemented for the Fireplace**.

### 3.3 Narrative Interaction
Key story moments, character dialogue, and critical choices are presented through **2D/Text-based event scenes**. These paused moments use character portraits and narrative text to deliver story beats in a focused and impactful manner.