# 🏰 Chronicles of the Eternal Guild

**Pre-Alpha — a cozy tavern sim about the heroes you send to die.**

> You never pick up a sword. You pour the drinks, light the fire, and choose *who* walks out the door — then live with who comes back. A 3D guild-tavern management sim wrapped around a roguelite **legacy loop**, where every adventurer is a named soul with a Tarot card, and the gut-punch is the **End-of-Day Reveal** when they return… or don't.

![Status](https://img.shields.io/badge/Status-Pre--Alpha-orange) ![Godot](https://img.shields.io/badge/Godot-4.4.1-blue) ![Genre](https://img.shields.io/badge/Genre-Management%20Sim-purple)

*Working title / Godot project name: **ShiningSun** · Repo: [djassoRaph/eternal_guild](https://github.com/djassoRaph/eternal_guild)*

---

## 🎯 The Pitch (the soul, not just the systems)

You're a retired adventurer running a guild hall. By day the tavern lives — patrons drink, the fire crackles, gold trickles in scaled by how **cozy** you keep the place. But the real game is **dispatch**: send named adventurers to a dangerous world map, then wait. At day's end they come home **one at a time** — whole, wounded, or not at all. No dice shown, no battle log. Just their name, and whether they made it.

Do it long enough and your **fallen guilds return as rivals** in later runs. You choose an **heir**, and begin again. That's the Eternal Guild.

**Design pillars:** Complicity & Consequence · Deep Character Investment · Meaningful Management · Legacy & Mystery.

---

## ⚠️ Pre-Alpha Warning

Real talk: this is **playable but raw**. You're an early tester, not a player.

- ✅ **The core day-loop works** — walk the tavern, tend the fire, serve patrons, hire & dispatch adventurers, survive to the next day.
- ✅ **Menus, settings & saving exist now** — main menu, pause, volume + keybind settings, save-on-exit + Continue.
- 🚧 **Balance is rough** — the economy might be too kind or brutally unfair.
- 🚧 **The Reveal is a placeholder** — it still shows the dice math; the real "no numbers, just the person" version is coming.
- 🐛 **Bugs expected** — please report the weird stuff. Have fun breaking it.

> **Milestone:** Epics 1–3 complete (foundation · menus/audio · the living-tavern day-loop). **Epic 4** (adventurer roster + Tarot data foundation) is next.

---

## 🎮 What Works Right Now (Epics 1–3)

### The Living Tavern
- Walk your avatar around a **3D tavern** (WASD/ZQSD + jump; **E** to interact — all rebindable in Settings).
- **Patrons arrive and drink** — they pay gold scaled by your **Comfort** level, with a little **3-coin burst + clink** when they settle up.
- **Tend the fireplace** with a firewood minigame — a lit fire **decays continuously** (roaring → low → dying → out) and Comfort (and tips) fall with it. Re-light to **stoke** it back up.
- **Morning briefing** each day: who's returning, who's still deployed, pending warnings.
- **Non-blocking HUD notifications** when gold / beer / fire run low — no pausing the game.

### The Guild
- **Hire adventurers** from a daily applicant pool (classes, stats, costs).
- **Dispatch** them to missions on the world map (click an adventurer → pick a mission).
- **Missions auto-resolve** — you don't fight, you *decide*. Rewards if they live; a permanent empty chair if they don't.
- **Economy** with a **soft-lock guard** — gold in from patrons, out to wages and costs; run fully dry and the run ends.

### Systems & Polish
- Full **main menu / pause / settings** — audio buses with volume sliders, fullscreen toggle, **keybind remapper**.
- **Save & load** — save-on-exit and **Continue** from the main menu work; manual save from the pause menu is in *(full in-session round-trip still being hardened)*.
- **Autoload event-bus architecture** (GameBus / EconomyBus / AdventurerBus / WorldBus / GuildBus / LegacyBus) keeps systems decoupled.

---

## 🗺️ The Vision (not built yet — where this is heading)

- **The End-of-Day Reveal, done right** — adventurers return one at a time, *no dice, no numbers*; the death beat breaks rhythm and just says *"she didn't come back."*
- **78 Tarot adventurers** — every hire carries a unique Tarot card + a commissioned portrait; the 22 Major Arcana evolve across a story arc.
- **The roguelite legacy loop** — up to 10 settlements per run; at the end you pick an **heir** and begin again, and your **past guilds return as rivals**.
- **The hidden hand** — a metaphysical meta-arc read through **ambient villager gossip**, never a quest log.
- **Tax pressure, reputation, staff automation (the Onibi fire-spirit, Bartender, managers), farmland & brewing.**

---

## 🕹️ How to Play (no tutorial yet!)

1. **Name your guild.** You start with some gold and no beer.
2. **Buy beer & firewood** from your quarters, and **tend the fire** — keep Comfort up for better tips.
3. **Hire adventurers** at the recruitment desk.
4. **Dispatch** them to missions on the world map.
5. **Advance the day** by resting in your quarters — then watch who returns.
6. **Don't go broke, don't lose everyone.**

**Controls:** `WASD` / `ZQSD` move · `E` interact · mouse for UI · `Esc` pauses. All rebindable in **Settings**.

---

## 🛠️ Feature Status

### ✅ Working (Epics 1–3)
- [x] 3D tavern, avatar movement, proximity + E interaction
- [x] Main menu, pause menu, settings (audio / fullscreen / keybinds)
- [x] Save-on-exit + Continue from main menu
- [x] Patron spawning, beer service, gold × Comfort tips (+ coin-burst SFX)
- [x] Fireplace comfort minigame — continuous decay + re-light stoking
- [x] Single-authority firewood & beer economy
- [x] Morning briefing + non-blocking HUD warnings
- [x] Hire pool, mission dispatch, auto-resolve, soft-lock game-over guard
- [x] Event-bus architecture (6 domain buses)

### 🚧 Rough / Partial
- [ ] Economic & mission balance (needs real tuning)
- [ ] The End-of-Day Reveal (placeholder — still shows the dice)
- [ ] Full in-session save/load round-trip
- [ ] Music & ambient audio (the SFX layer just got started)

### ❌ Not Yet (see Vision / Roadmap)
- [ ] Tarot cards & portraits on adventurers *(Epic 4)*
- [ ] Tutorial / onboarding *(Epic 5)*
- [ ] Tax cycle & full game-over screen *(Epic 13)*
- [ ] Reputation, staff/Onibi automation, farmland & brewing
- [ ] Legacy loop — heir selection, rival guilds, multiple settlements

---

## 🐛 Known Issues
- **Balance** is untuned — expect wild swings.
- **The Reveal** exposes the dice roll (rework planned).
- **Save/load** mid-session can be flaky; **save-on-exit is the reliable path**.
- Occasional NPC spawn hiccups and minor lighting pops on day change.

**Found something else? Please report it** (see Contributing).

---

## 💻 Running It

### From a release build
Ask Raphael for the latest zip/exe, extract, run the executable (Windows), and break things.

### From source (Godot 4.4.1)
1. Clone: `git clone https://github.com/djassoRaph/eternal_guild`
2. Open the project in **Godot 4.4.1** — the LimboAI GDExtension is vendored in `addons/`, so no extra install needed.
3. Press **Play**. The main scene is the main menu.

**Minimum specs:** Windows 10 · dual-core 2.5 GHz · 4 GB RAM · OpenGL 3.3 · ~200 MB storage.

---

## 🎨 Art & Tone
- **3D worldspace with a painterly / pixel-art post-process** *(aspiration — the current build is clean low-poly KayKit + an edge shader on the way there).*
- **Warm hearth-lit interiors** (Ghibli / Spiritfarer coziness) against a **sparser, uneasier outside world**.
- **"Both true at once"** — cozy *and* complicit. You're the kind soul pouring the beer *and* the one sending people to die.

---

## 🗓️ Roadmap
- **Now:** Epic 4 — Adventurer Roster & the Tarot data foundation.
- **Next:** Epic 5 tutorial · Epic 13 tax cycle + full game-over · the Reveal rework.
- **Mid:** reputation, staff automation (Onibi fire-spirit), farmland & brewing, an injury system.
- **Long:** the legacy loop — heirs, rival guilds, up to 10 settlements, and the run-end **"Reading."**

*(Full design lives in the GDD, architecture, and epics docs — see `documentation/` and the planning workspace.)*

---

## 🤝 Contributing & Feedback

Play it, break it, report it.

**A good bug report:** what you were doing → what you expected → what actually happened → steps to reproduce → a screenshot/clip if handy.

> *Example: "I hired 3 adventurers, sent them on 'Escort Merchant,' advanced the day, and the game froze. Expected: mission resolves and they return. Actual: stuck on a loading screen."*

Feature idea? Open an issue: what it is, why it's fun, and how it fits the game's soul.

---

## 📜 License & Credits
- **License:** _TODO — pick one and add `LICENSE.md`._
- **Engine:** [Godot Engine 4.4.1](https://godotengine.org/)
- **Behaviour trees:** LimboAI · **Dialogue:** Dialogue Manager
- **3D models:** [KayKit Adventurers](https://kaylousberg.com/) (Kay Lousberg)
- **Design & code:** Raphael ([@djassoRaph](https://github.com/djassoRaph))
- **Tonal north stars:** Spiritfarer, Studio Ghibli, the "stories from systems" of Dwarf Fortress / RimWorld, and Disco Elysium's ambient voice.
- **Special thanks:** the Godot community, early testers, and coffee.

---

## 📫 Contact
- **GitHub:** [github.com/djassoRaph/eternal_guild](https://github.com/djassoRaph/eternal_guild)
- **Twitter/X:** [@Raphiosi](https://twitter.com/Raphiosi)
- **Email:** contact@raphaelreck.com

---

*Last updated: 2026-07-08 · Pre-Alpha (Epics 1–3 complete) · Built with Godot 4.4.1 and stubbornly good intentions.*
