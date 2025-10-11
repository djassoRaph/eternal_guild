# 🏰 Eternal Guild

**Pre-Alpha 0.1.0 - "First Blood" Release**

> A hardcore isometric tavern management game where you run a guild hall, hire adventurers, send them on deadly missions, and try not to go bankrupt or get everyone killed. Inspired by Dwarf Fortress, Rimworld, and the "dying is fun" philosophy of classic roguelikes.

![Tavern Management](https://img.shields.io/badge/Status-Pre--Alpha-orange) ![Godot](https://img.shields.io/badge/Godot-4.3+-blue) ![Genre](https://img.shields.io/badge/Genre-Tavern%20Management-purple)

---

## ⚠️ Pre-Alpha Warning

**THIS IS A PRE-ALPHA BUILD!** What does that mean?

-  **Core systems work** - You can hire, assign missions, serve beer
-  **No tutorial** - Figure it out yourself, adventurer!
-  **Game Over untested** - I literally forgot to test this... let me know if it works! 😅
-  **Bugs expected** - Please report them!
-  **No save system yet** - Play in one sitting or start over
-  **Balance is rough** - Economy might be too easy or impossibly hard

**Translation:** This is playable but raw. You're an early tester, not a player. Expect jank. Report weirdness. Have fun breaking things!

---

## 🎮 What Can You Do Right Now?

### Tavern Management
- **Run a guild tavern** in a cozy isometric 3D pixel art world
- **Serve beer to patrons** (when they spawn... sometimes they do!)
- **Manage your beer inventory** - Buy stock, don't run out
- **Track your gold** - Income from patrons, expenses from everything

### Adventurer System
- **Hire adventurers** from daily applicants (different classes, skills, costs)
- **Assign missions** - Solo or party-based jobs
- **Send them to probable death** - Missions are dangerous!
- **Watch them come back** - Or not. Death is permanent.
- **Complete missions** - Earn rewards (if they survive)

### Economic Survival
- **Pay daily costs** - Adventurer wages, operating expenses
- **Balance income vs expenses** - Go bankrupt and... well, presumably you lose?
- **Progress through days** - Each day brings new challenges and opportunities

---

## 🎯 How to Play (There's No Tutorial!)

### Starting Out
1. **Day 1:** You start with some gold and 0 beers
2. **Hire adventurers** - Click the recruitment desk
3. **Buy more beer** - Click the bar/beer barrels
4. **Assign missions** - Click the mission board
5. **Advance the day** - Click "Next Day" button
6. **Don't go broke** - That's... probably important?

### Controls
- **WASD / Arrow Keys** - Move camera/player (depending on the scene)
- **Mouse Click** - Interact with zones (desk, board, bar, etc.)
- **E Key** - Interact with NPCs (when they're nearby)
- **UI Popups** - Click buttons, manage your guild

### Strategic Tips
- **Start with 1-2 adventurers** - Don't hire everyone on day 1
- **Check mission requirements** - Solo vs party missions(unlocked after 30 days.)
- **Watch your beer stock** - Patrons need drinks
- **Mission rewards vary** - Higher risk = higher reward
- **Adventurers can DIE** - Don't get too attached

---

## 🛠️ Current Features (Pre-Alpha 0.1.0)

### ✅ Implemented & Working
- [x] Core tavern management loop
- [x] Patron spawning and basic AI
- [x] Recruitment system with daily applicants
- [x] Mission assignment and completion
- [x] Beer inventory management
- [x] Gold/economy tracking
- [x] Day/night progression (mechanical, not visual yet)
- [x] Multiple character classes (Warrior, Rogue, Mage, Cleric, Ranger)
- [x] Isometric 3D pixel art rendering
- [x] Atmospheric lighting and Studio Ghibli-inspired aesthetic

### 🚧 Partially Working (Known Issues)
- [x] **Patron service cycle** - Patrons spawn but don't always order/pay
- [ ] **Economic balance** - Might be too easy or too hard
- [ ] **Mission difficulty** - Death rates not properly tuned
- [ ] **Performance** - Can lag with multiple NPCs
- [x] **Game Over screen** - Untested! Literally forgot to test this 😬
- [x] **Save/load system** - Basic loading is working. Ingame save and loading isn't. Exit game and continue from main menu is. 

### ❌ Not Yet Implemented
- [ ] Patron conversations and quest-giving
- [ ] Advanced adventurer progression
- [ ] Multiple tavern locations (procedural world system)
- [ ] Tax system and economic pressure
- [ ] Reputation tracking
- [ ] Tutorial or onboarding
- [ ] Sound effects and music
- [ ] Controller support

---

## Known Bugs & Issues

### Critical (Might Break Your Game)
- **Game Over state untested** - If you hit 0 gold or lose all adventurers... try it out.
- **No save system** - If you close the game, you lose everything
- **Occasional NPC spawn failures** - Patrons might not appear some days

### Annoying (But Playable)
- **Performance hiccups** during NPC spawning
- **Economic balance** needs serious tuning
- **Mission success rates** feel random (they are, but need better feedback)
- **UI can overlap** if you open multiple popups

### Cosmetic (Ignore These)
- Some visual glitches with pixel shader -> will get serious when I start getting my own assets. 
- Lighting sometimes pops when changing days weird.
- Fade to Black is not working properly. 

**Found a bug not listed here?** Please report it! (See Contributing section)

---

## System Requirements

### Minimum
- **OS:** Windows 10
- **Processor:** Dual-core 2.5 GHz
- **Memory:** 4 GB RAM
- **Graphics:** OpenGL 3.3 compatible
- **Storage:** 160 MB available space

---

## Installation

### Download Release Build
1. Ask Raphael for the zip/exe.
2. Download the latest pre-alpha build for your platform
3. Extract the archive
4. Run `EternalGuild.exe` (Windows)
5. Start playing (and breaking things)!

---

## Art & Design Philosophy

**Visual Style:**
- Isometric 3D with pixel art post-processing
- Warm orange tavern lighting (fireplace atmosphere)
- Cyan/blue magical accents inside wood.
- Studio Ghibli-inspired warmth and coziness

**Gameplay Philosophy:**
- **Meaningful challenge** - Difficulty creates better stories
- **Permanent consequences** - Death is permanent, choices matter
- **Economic pressure** - Resource management is core
- **"Dying is fun"** - Inspired by Dwarf Fortress and roguelikes
- **Strategic depth** - Multiple paths to success (or failure)

---

## Roadmap & Future Vision

### Short-Term (Pre-Alpha → Alpha)
- [ ] Fix game over state and test it properly
- [ ] Implement save/load system
- [ ] Balance economy and mission difficulty
- [ ] Add patron conversation system
- [ ] Create basic tutorial/onboarding
- [ ] Performance optimization
- [ ] Sound effects and ambient audio

### Mid-Term (Alpha → Beta)
- [ ] Adventurer progression and leveling
- [ ] Reputation and faction systems
- [ ] Tax escalation and economic pressure
- [ ] Multiple patron types (merchants, nobles, quest-givers)
- [ ] Injury system (not just death)
- [ ] Tavern upgrades and renovations

### Long-Term (Beta → 1.0)
- [ ] **Procedural world system** - Choose from 20-30 unique settlements
- [ ] Settlement-specific content (missions, NPCs, economies)
- [ ] Multiple victory conditions (economic, military, political)
- [ ] Faction warfare and guild politics
- [ ] Community modding support

### Vision (Post-1.0)
- **Content platform** - User-generated settlements and campaigns
- **Mod workshop** - Easy content creation tools
- **Procedural generation** - Infinite settlement variety
- **Multiplayer guilds** - Cooperative management (maybe?)

---

## Contributing & Feedback

### How to Help Right Now
1. **Play the pre-alpha** - Break things, find bugs
2. **Report issues** - Use GitHub Issues or [contact method]
3. **Share feedback** - What's fun? What's frustrating?
4. **Suggest features** - What would make this better?

### Reporting Bugs
**Good bug report:**
- What you were doing
- What you expected to happen
- What actually happened
- Steps to reproduce (if possible)
- Screenshots/videos if relevant

**Example:**
> "I hired 3 adventurers, assigned them to 'Escort Merchant' mission, advanced the day, and the game froze. Expected: Mission resolves and adventurers return. Actual: Stuck on loading screen."

### Feature Requests
Want to see something in the game? Open an issue with:
- Clear description of the feature
- Why it would be fun/useful
- How it fits with the game's philosophy

---

## License & Credits

### License
This project is licensed under [LICENSE TYPE] - see LICENSE.md for details

### Credits
- **Engine:** [Godot Engine 4.3+](https://godotengine.org/)
- **3D Models:** [KayKit Adventurers Pack](https://kaylousberg.com/)
- **Inspiration:** Dwarf Fortress, Rimworld, Graveyard Keeper, Dave the Diver
- **Developer:** [Your Name/Studio]

### Special Thanks
- Godot community for engine support
- Early testers who survived the pre-alpha
- Coffee, for making this possible

---

## Contact & Community

- **GitHub:** [github.com/djassoRaph/eternal_guild/tree/shiningsun](https://github.com/djassoRaph/eternal_guild/tree/shiningsun)
- **Discord:** [To Do Discord Server]
- **Twitter/X:** [@Raphiosi]
- **Email:** contact@raphaelreck.com

---

## Final Words from the Dev



**— Raphael**

---

*Last Updated: 12/10/25*  
*Version: Pre-Alpha 0.1.0 "First Blood"*  
*Built with Godot 4.3 and questionable decision-making*