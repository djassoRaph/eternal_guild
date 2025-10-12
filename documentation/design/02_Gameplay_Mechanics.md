# GDD Section 2: Gameplay Mechanics

### **Version: 1.0**
### **Project: Chronicles of the Eternal Guild**

---
## 1. The Core Loop
The gameplay is structured around a repeating and evolving cycle of management and adventure.

1.  **Recruit & Interact**: Meet unique adventurers.
2.  **Prepare & Dispatch**: Assign adventurers to missions.
3.  **Tavern Management**: Serve patrons, manage resources, and maintain the tavern's comfort.
4.  **Mission Resolution**: Missions are auto-resolved, with outcomes influencing adventurer growth.
5.  **Return & Consequences**: Adventurers return changed, and their success can unlock lore and story quests, including those related to "The Priors."

---
## 2. Tavern Management
The tavern is the player's primary interface for economic and resource management.

### 2.1 Patron Service Cycle
* The tavern currently supports up to 5 simultaneous patrons, with plans for future expansion.
* The player must physically move to patrons to serve them, earning gold and managing the flow of customers in real-time.

### 2.2 Economy & Resources
* **Gold**: The primary currency for all transactions.
* **Beer**: The core consumable for tavern income.
* **Taxes**: An escalating tax is due every 30 days, serving as the primary economic pressure and a key progression gate. The basic system for this is implemented.

### 2.3 Firewood & Comfort System
* **Status**: ✅ **Fully Implemented**.
* **Mechanic**: The player manages firewood to keep the tavern fireplace lit. A burning fire generates a "Comfort" level, which acts as a multiplier for tips earned from patrons.
* **Planned Feature**: A mini-game is planned for when the fire needs to be relit from 0% fuel.

---
## 3. Adventurer Management
Adventurers are the player's key assets for progressing the story and generating significant income.

### 3.1 Recruitment and Roster
* Players hire adventurers from a daily pool of randomly generated applicants.
* Each adventurer has a class, stats, and a hiring cost.

### 3.2 Consequences and Costs
* **Status**: ✅ **Implemented**.
* **Daily Costs**: Adventurers have daily wages and consume resources (beer), creating a constant economic drain.
* **Mission Risks**: Missions carry a real risk of injury, which requires a recovery period where the adventurer cannot go on missions, or permanent death.

### 3.3 Character Progression: "Journey Through the Arcana"
* This is the core system for ensuring deep character investment.
* **Mechanic**: Core adventurers are represented by evolving Tarot portraits. A character begins with a Minor Arcana card representing their novice state (e.g., "Seven of Swords").
* **Evolution**: By completing key personal story quests, they evolve into a Major Arcana, representing their growth into a master or legend (e.g., "The Emperor"). Their portrait, stats, and traits change to reflect this transformation.
* **Corruption**: Failure or dark choices can lead a character down a path of corruption, represented by a **Reversed** tarot portrait with negative traits.