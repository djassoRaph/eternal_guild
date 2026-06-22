# Eternal Guild — Epic Progress Tracker
Updated: 2026-06-21 — Verified by reading actual source code.

Cross-references `epics.md` against working code in `shiningsun/`.

---

## Legend
- [x] Done — verified working in code
- [~] Partial — code exists but incomplete vs epic requirements
- [ ] Not started — no corresponding implementation

---

## Epic 1: Foundation Architecture & Modding Groundwork
**Status: ~25% — Critical infrastructure still missing**

### Story 1.1: Tech Debt Resolution
- [x] Duplicate `systems/PlayerManager.gd` deleted
- [x] `assign_adventurer_to_mission()` orphan removed from GameManager.gd
- [x] `"on_mission"` match arms fixed to `"On Mission"` (correct capitalization)
- [ ] **AdventurerStatus enum** (`scripts/resources/adventurer_status.gd`) — NOT CREATED. Still using string-based status (`"Ready"`, `"On Mission"`, `"Injured"`, `"Resting"`, `"Dead"`)
- [ ] `@onready var log_container = %LogContainer` still on line 2 of `systems/DataManager.gd` — NOT DELETED

### Story 1.2: Domain-Split EventBus
- [ ] `scripts/buses/` directory does not exist — **zero bus autoloads created**
- [ ] GameManager still holds all signals directly (gold_changed, beer_changed, day_changed, adventurer_roster_changed, missions_changed, recruitment_pool_changed, game_over_triggered, firewood_changed, fireplace_fuel_changed, mission_dispatched, missions_resolved, morning_briefing_ready)

### Story 1.3: Configuration Spine
- [x] `data/config/` directory created
- [x] `game_config.json` created — starting values, max_adventurers, firewood, tax, autosave
- [x] `features.json` created — feature flags for gating incomplete systems
- [x] `DataManager.get_config()` and `DataManager.get_feature()` methods added
- [x] `GameManager._apply_config()` reads from config; `reset_game_state()` reuses it

### Story 1.4: Project Structure Migrations
- [x] `Player.tscn` correctly at `scenes/player/Player.tscn`
- [x] `PlayerManager.gd:PLAYER_SCENE_PATH` points to `"res://scenes/player/Player.tscn"`
- [ ] ZonePromptUI **still registered as autoload** in project.godot line 24
- [ ] `get_node_or_null("/root/ZonePromptUI")` still in PlayerManager.gd line 100
- [ ] `clear_all_zones()` call still present in PlayerManager.gd

### Story 1.5: Dual-File Save Architecture Skeleton
- [~] SaveSystem.gd exists — single file `user://eternal_guild_save.json` with 3-backup rotation
- [~] Backup restore method works (`restore_from_backup()`)
- [~] Save validation exists (checks required fields)
- [ ] **No `schema_version` field** in save data
- [ ] **No `codex.dat`** (eternal cross-run persistence file)
- [ ] Not truly atomic (writes directly, relies on backups for corruption recovery)

### Story 1.6: MinigameInterface Base Class
- [ ] `scripts/minigames/` directory does not exist — no base class

### Story 1.7: Plugin Installation Suite
- [x] **LimboAI** — files present in `addons/limboai/` (GDExtension) — **but NOT in editor_plugins enabled list** (needs manual enable)
- [x] **Debug Menu (Calinou)** — installed, enabled, registered as autoload
- [ ] **GdUnit4** — NOT installed anywhere in project
- [ ] **QuestSystem 2** evaluation — NOT documented
- [x] **dialogue_manager** — installed and active
- [x] **asset_placer** — installed and active (dev tool)

### Story 1.8: Modding Foundation Stubs
- [ ] No MOD-8 hook methods on GameManager (on_patron_spawned, on_mission_resolved, etc.)
- [ ] No `data/config/factions.json`
- [~] Some data-driven content exists (JSON files in data/) but hardcoded class names remain in GDScript (MOD-2 violations: `"Fighter"`, `"Rogue"`, etc. used as literals)

### Story 1.9: Failsafe Test Suite
- [ ] GdUnit4 not installed — no automated tests exist

---

## Epic 2: Main Menu, Pause Menu & Game Settings
**Status: ~40% — Basic menu scaffolding, needs polish**

### Story 2.1: Main Menu Scene — PARTIAL
- [x] `MainMenu.tscn` + `main_menu.gd` — Start, Continue, Quit buttons exist
- [x] Continue button disabled when no save file exists (`has_save_game()` check)
- [~] New Game → transitions to HexMapTest scene — **NOTE (Raphael): not at expected quality**
- [~] Continue → loads save then transitions to MainTavern — load has known issues
- [x] Quit → `get_tree().quit()`
- [ ] No "overwrite existing save" confirmation on New Game when save exists
- [ ] No Settings button wired

### Story 2.2: Settings Screen — NOT DONE
- [ ] No settings scene exists
- [ ] No volume sliders
- [ ] No `user://settings.cfg` handling

### Story 2.3: Keybinding Remapper — NOT DONE
- [ ] Not implemented

### Story 2.4: Pause Menu & Save Handler — DONE
- [x] Full pause menu: Save, Load, Save & Exit, Main Menu, Quit
- [x] Confirmation dialogs on destructive actions (Main Menu, Load, Quit)
- [x] Save & Exit: saves then returns to main menu
- [x] Load: validates save exists, loads, reloads scene
- [x] Toggle pause with `get_tree().paused`
- [x] `process_mode = PROCESS_MODE_ALWAYS` (works while paused)

---

## Epic 3: The Living Tavern — Core Day Loop
**Status: ~75% — Core loop fully functional**

- [x] **Day cycle** — `advance_day()` processes all daily events in sequence
- [x] **Patron spawn** — PatronSpawner with timer-based spawn, up to 3 concurrent (configurable)
- [x] **Beer economy** — buy pints (1g each), sell to patrons (6g + comfort tip)
- [x] **Fireplace/Comfort** — fuel affects patron tips via `calculate_patron_tip()`. Comfort tiers: Cozy/Warm/Chilly/Freezing
- [x] **Firewood system** — purchase bundles, stoke fire (+25% fuel per bundle), max storage cap
- [x] **Single firewood drain authority** — `set_fireplace_fuel()` on GameManager is the single write point; `fireplace_zone.gd` manages burn state machine (DORMANT→BURNING_HIGH→BURNING_LOW→DYING)
- [x] **Morning briefing** — `MorningBriefing.tscn` shows sequential mission reports
- [x] **Daily processing chain**: recovery → availability status → beer consumption → mission returns → operations → tax check → recruit refresh → mission refresh
- [x] **Beer shortage consequences** — escalating: Day 1 = -25% mission penalty, Day 2 = 50% departure chance, Day 3+ = guaranteed departures
- [x] **Soft-lock detection** (FR-6) — triggers game over when 0 adventurers + <8g + no recruits
- [x] **GameOverScreen.tscn** exists for game over display
- [ ] **HUD notifications** for non-blocking warnings — log_message goes to console + scene log, but no floating HUD notifications

---

## Epic 4: The Adventurer Roster
**Status: ~70% — Functional roster, missing Tarot/portrait**

- [x] **Hire adventurer** — from daily recruit pool, deducts hiring cost (stat-based pricing), adds to roster
- [x] **Daily wages** — 1g per adventurer per day (with trait cost_multiplier)
- [x] **Dismiss adventurer** (FR-10) — 5g fee, -1 reputation, cannot dismiss if on mission
- [x] **Roster panel display** — AdventurerRosterPanel.gd + AdventurerCard.tscn (class, status, stats)
- [x] **Recruit generation** — 5 classes (Fighter/Rogue/Mage/Ranger/Cleric) with stat bonuses, personality traits, backgrounds
- [x] **Recruit availability window** — recruits expire after 3-7 days
- [x] **Max adventurer cap** — 5 (hardcoded, should be in config)
- [x] **Roster cap enforcement** — hire blocked + refund when full
- [x] **Recruitment refresh** — every 2 days, 2-4 new recruits generated
- [x] **Patron recruitment pool** — separate path for patron-to-adventurer conversion
- [ ] **Tarot card identifier** not stored in adventurer records (FR-27)
- [ ] **Portrait socket** not implemented (FR-30)
- [ ] No unique persistent ID system beyond incremental int

---

## Epic 5: Tutorial & Onboarding
**Status: 0% — Not started**
- [ ] No tutorial system, no hard-gate beats, no guild naming

---

## Epic 6: World Map, World Generation & Mission Dispatch
**Status: ~50% — Generation works, dispatch needs rework**

- [x] **Hex map generation** — seeded RNG, simplex noise + radial falloff, biomes (sea/grass/forest/mountain)
- [x] **Settlement placement** — configurable count, minimum spacing enforcement
- [x] **World persisted** — `WorldManager.set_generated_world()` stores records; `display_mode` re-renders without regenerating
- [x] **Tavern hex selection** — player picks center (signal `tavern_hex_selected`)
- [x] **Missions assigned to hexes** — `WorldManager.assign_missions_to_hexes()` distributes missions to eligible tiles
- [x] **Mission dispatch** — `send_on_mission()` / `send_party_on_mission()` with duration tracking
- [x] **Active mission timers** — tick down daily in `process_mission_returns()`
- [x] **Hex lock** — dispatched hex marked `locked`, freed on resolution
- [x] **Mission success formula** (FR-18) — `50% ± 3%/stat ± 2%/exp − 8%/danger`, clamped 10-95% ✅ EXACT MATCH
- [x] **Party missions** — average chance + party_size bonus (5% per extra member)
- [x] **Mission board UI** — SingleMissionCard + PartyMissionCard scenes
- [x] **World map assets** — coast variants, forest/mountain toppers, decorative props, tavern building
- [x] **Data-driven missions** — `data/missions/mission_types.json` + fallback generation
- [~] **Pre-dispatch panel** (FR-19) — mission board shows info, but unclear if full "estimated success %" is shown before confirm
- [ ] **Latest News feed** (FR-19b) — not implemented
- [ ] **Hex Strategy Map plugin evaluation** — not documented
- [~] **World NOT yet saved to disk** per WorldManager comment: "Saving to disk is a later step (gated on the load-game fix)"
- **NOTE (Raphael):** Map currently only displays 3 missions, randomly placed. Needs rework — not the system desired. Post-30-day group missions not displayed either.

---

## Epic 7: The End-of-Day Reveal
**Status: ~30% — Basic mission reports exist, not the "sacred ritual"**

- [x] **Morning briefing sequence** — panels shown one at a time, "Report N of M" counter
- [x] **Report contains**: mission name, adventurer name/class, success/fail, alive/injured/dead status
- [x] **Solo + party report types** with different data shapes
- [x] **Mission resolution consequences** — success: +gold, +1 day rest. Failure: injury (2-5 days), possible death
- [x] **Personality trait effects on resolution** — Reckless = extra injury chance, Lucky = bonus reward
- [ ] **Three visual variants** (RETURNED warm / WOUNDED muted / DEAD forced pause) — NOT implemented, all reports use same panel style
- [ ] **Forced death pause** (2s Timer block, fade-in advance button) — NOT implemented
- [ ] **Portrait emotional states** — no portrait system at all
- [ ] **Flavor lines** from class+outcome dictionary (3+ variants per combo) — NOT implemented
- [ ] **Group panel** with Connection flag — reports are sequential, no side-by-side layout
- [ ] **"Begin the Day"** closing ceremony — advance button exists but no ceremony
- [ ] **Reveal-before-display pattern** — deaths are processed during resolution (not saved to codex.dat first, since codex.dat doesn't exist)

---

## Epic 8: PatronNPC Systems & Ambient Life
**Status: ~40% — MVP placeholder, not production-ready**

- [~] **PatronNPC FSM** — `WALKING_TO_TABLE → SITTING_WAITING → DRINKING → LEAVING` (4 states, not 6 as architecture specifies WALKING→SEATED→WAITING→SERVED→DRINKING→LEAVING). **MVP-quality only — animations are placeholder, not real character animations.**
- [x] **NavigationAgent3D movement** — patrons walk to table, walk to exit
- [x] **Random model swap** — picks from 5 KayKit adventurer GLBs per patron
- [x] **Animations** — Idle and Running_A via AnimationPlayer (from GLB models)
- [x] **Service system** — player must be within 3.0 distance, patron shows yellow sphere indicator
- [x] **Timer-based behavior** — sit 2-5s, drink 8-15s
- [x] **Table management** — 5 positions, occupied tracking, availability check
- [x] **Up to 3 concurrent** (max_patrons configurable @export)
- [x] **Payment with comfort-based tip** — base 6-12g random + fire comfort multiplier
- [x] **No-beer check** — won't spawn if beer is 0, won't serve if no stock
- [x] **Patron flavor** — random name (first + surname), random origin ("the bridge crossroads", "the guard post", etc.)
- [x] **Spawn replacement** — 70% chance to spawn new patron after one leaves (5-15s delay)
- [x] **Despawn all** — `despawn_all_patrons()` for night/day-end
- [ ] **Eavesdropping proximity trigger** (FR-50) — not implemented
- [ ] **Dialogue Manager integration** — no ambient patron lines from dialogue system
- [ ] **Up to 5 patrons** per FR-1 — currently max 3

---

## Epic 9: The Bard NPC
**Status: 0% — Not started**
- [ ] No Bard NPC, visitor event, allow/refuse, narration, rumours

---

## Epic 10: Narrative Systems & Story Beats
**Status: ~5%**
- [x] Dialogue Manager plugin installed and active
- [ ] No narrative panel system, no Den Fa, no Hidden Threshold, no Kingdom Chronicle

---

## Epic 11: Campaign Save & Load
**Status: ~45% — Basic save works, load has issues, not architecture-compliant**

- [x] **Single-file JSON save** — `user://eternal_guild_save.json`
- [x] **3-backup rotation** — `create_save_backup()` rotates backup1→2→3
- [x] **Comprehensive state saved**: gold, beer, day, tax_due_day, adventurers (full array), max_adventurers, firewood, fuel, recruits, missions, active_missions, patron_pool, reputation, tier, morale
- [x] **Save metadata**: timestamp, date string, game version, playtime, save type
- [x] **Autosave** — every 5 minutes + on day change (after day 1)
- [x] **Load with validation** — checks required fields (current_day, gold, beer_stock, adventurers)
- [x] **Restore from backup** method exists
- [x] **Signal re-emission on load** — all UI signals fired to refresh displays
- [x] **Game over save** — saves state even on game over
- [ ] **No `schema_version`** — save not versioned
- [ ] **No `codex.dat`** — no eternal cross-run persistence
- [ ] **Not atomic** — direct FileAccess write (but backup rotation mitigates)
- [ ] **FR-36 player spawn at morning point** — PlayerManager uses SpawnPoint nodes but unclear if save/load respects this
- **NOTE (Raphael):** Load isn't working as expected — needs debugging/rework

---

## Epic 12: Loot & Adventurer Equipment
**Status: ~10% — Data exists, no loot system**

- [x] `data/economy/items.json` — item definitions exist
- [x] `data/missions/rewards.json` — reward data exists
- [x] Mission resolution returns gold rewards (range-based random)
- [ ] No 3-tier loot roll (gold/equipment/artifact distribution)
- [ ] No equipment slot system
- [ ] No Prior Artifact persistence
- [ ] No loot display in reveal panel

---

## Epic 13: Tax Cycle & Economic Pressure
**Status: ~85% — NEARLY COMPLETE**

- [x] **30-day tax cycle** — `tax_due_day` starts at 30, advances by 30 on payment
- [x] **Warnings at 7, 3, 1 day** before due (`check_tax_deadline()`)
- [x] **3-day grace period** — `tax_grace_days` increments daily if unpaid
- [x] **Game over on 3 days unpaid** — `trigger_game_over("bankruptcy", ...)`
- [x] **Tax amount** — 1000 + adventurers * 5 (scales with roster)
- [x] **Tier unlock tied to tax payment** — tier 2 unlocks after first tax paid
- [x] **Soft-lock game over** (FR-6) — detected when 0 adventurers + no gold + no recruits
- [ ] EventBus wiring (buses don't exist yet)
- [ ] Party mode economic expansion design (deferred)

---

## Epic 14: Reputation & Tavern Disturbances
**Status: ~15% — Reputation tracked but no effects/display**

- [x] `tavern_reputation` integer tracked in GameManager
- [x] +2 reputation on successful mission
- [x] -1 reputation on adventurer dismiss
- [x] Tier system partially uses reputation (tier 3 requires reputation >= 50)
- [ ] **No 5-tier label** (Unknown → Known → Trusted → Respected → Honored)
- [ ] **No reputation effects** on patron tips or recruit quality
- [ ] **No disturbance system** (pickpocket, drunk, rare visitor)
- [ ] **No reputation decay**
- [ ] **No reputation display** in HUD

---

## Epics 15–24: Not Started

| Epic | Status | Notes |
|------|--------|-------|
| 15: Farmland & Drinks | 0% | No farmland, no drink types beyond beer |
| 16: Staff & Automation | 0% | LimboAI installed but not enabled; no staff NPCs |
| 17: Tarot Evolution | 0% | No Tarot system at all |
| 18: Codex | 0% | No codex.dat, no Dragon Eye Book scene |
| 19: Memorial & Cemetery | 0% | No memorial wall, no cemetery scene |
| 20: Guild Fame | 0% | No fame system |
| 21: The Reading | 0% | No run-end ceremony |
| 22: Legacy Transition | 0% | No LegacyTransition class |
| 23: City Hub Buildings | 0% | No church, apothecary, alley |
| 24: Audio & Ambient | 0% | No audio system beyond Godot defaults |

---

## Installed Plugins

| Plugin | Required By | Status |
|--------|-------------|--------|
| dialogue_manager (nathanhoad) | Epic 8, 9, 10 | ✅ Installed & enabled |
| asset_placer | Dev tool | ✅ Installed & enabled |
| LimboAI (limbonaut) | Epic 16 (Onibi/Staff FSM) | ⚠️ GDExtension present, **NOT enabled** in editor_plugins |
| debug_menu (Calinou) | Epic 1 | ✅ Installed, enabled, autoload registered |
| godot_mcp_editor | Dev tool (MCP) | ✅ Installed & enabled |
| godot_mcp_runtime | Dev tool (MCP) | ✅ Installed & enabled |
| GdUnit4 | Epic 1 (test suite) | ❌ **Not installed** |
| QuestSystem 2 | Epic 9, 23 | ❌ Not installed, **evaluation not done** |
| Hex Strategy Map | Epic 6 (evaluate) | ❌ Not evaluated |

---

## Data Files Present

| Path | Content | Used By |
|------|---------|---------|
| `data/characters/classes.json` | Character class definitions | DataManager |
| `data/characters/names.json` | Adventurer name pools | DataManager |
| `data/characters/traits.json` | Positive/negative trait modifiers | GameManager (mission bonus, injury, cost) |
| `data/missions/mission_types.json` | Mission templates | DataManager → GameManager |
| `data/missions/rewards.json` | Reward definitions | (exists, usage unclear) |
| `data/settlements/locations.json` | World map location data | WorldManager |
| `data/settlements/capitals.json` | Faction capital definitions | WorldManager |
| `data/economy/items.json` | Item definitions | (exists, not yet wired to loot system) |
| `data/dialogue/patron_lines.json` | Patron ambient lines | (exists, unclear if active) |

**Missing data files (required by architecture):**
- `data/config/game_config.json` — all balance values
- `data/config/features.json` — feature flags
- `data/config/factions.json` — rival guild names, biome definitions
- `data/config/drink_affinity.json` — drink → adventurer class mappings

---

## What's Actually Playable Today

A player can:
1. Launch from Main Menu → generate a hex world → pick a tavern location
2. Enter the tavern with a 3D controllable character (Rogue model)
3. Buy beer from tavern management popup (1g/pint)
4. Stoke the fireplace for comfort (affects patron tips)
5. Watch patrons walk in, sit, wait for service, get served, drink, pay, leave
6. Serve patrons manually (proximity + interact) for gold + tip
7. Open recruitment popup, hire adventurers with stats/classes/personalities
8. Open mission board, dispatch solo/party adventurers on timed missions
9. Advance the day → morning briefing shows mission results (success/fail/injury/death)
10. Manage beer shortage consequences (escalating morale damage)
11. Pay taxes every 30 days or face bankruptcy game over
12. Save/Load/Continue from main menu
13. Pause → Save & Exit → Continue later
14. Walk between tavern interior and exterior world (player only — NPCs don't cross scenes yet)

---

## Blocking Gaps for Next Development

**Must complete before building new features (Epic 1 remainder):**

1. **Delete DataManager.gd line 2** (`@onready var log_container = %LogContainer`)
2. **Create AdventurerStatus enum** — replace all string status comparisons
3. **Create 6 EventBus autoloads** — decouple GameManager's 12+ signals
4. **Create `data/config/game_config.json`** — externalize `max_adventurers` and all balance values
5. **Create `data/config/features.json`** — feature flags
6. **Remove ZonePromptUI from autoloads** — convert to per-scene child node
7. **Add `schema_version` to save data** — future-proofing
8. **Create `codex.dat` skeleton** — needed before Memorial, Codex, or Legacy features
9. **Enable LimboAI in editor_plugins** — needed for Epic 16
10. **Install GdUnit4** — needed for test suite
11. **Create MinigameInterface base class**

**After Epic 1, highest-value next work for Kickstarter demo:**
- Epic 7 (Reveal) — upgrade morning briefing to the emotional "sacred ritual" panels
- Epic 6 completion — save world to disk, Latest News feed
- Epic 11 hardening — schema_version, codex.dat
- Epic 8 — bump patrons to 5, add eavesdropping, Dialogue Manager lines
