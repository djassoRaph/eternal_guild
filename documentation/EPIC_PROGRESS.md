# Eternal Guild — Epic Progress Tracker
Updated: 2026-08-18 (Codex/Memorial viewer + Latest News feed + reputation effects shipped). Earlier epics last verified 2026-06-21 — re-verify against source before relying on them.

Cross-references `epics.md` against working code in `shiningsun/`.

## Snapshot (2026-08-18)
**Shipped:** Epic 1 (100%) · Epic 2 (~92%) · Epic 3 (~100%) · Epic 7 (~95%, all 6 stories) · Epic 13 (~85%).
**In progress:** Epic 4 (~85%) · Epic 6 (~60%) · Epic 8 (~75%, Stories 8.4 + 8.5 done) · Epic 11 (~58%) · Epic 14 (~40%) · Epic 18 (~30%) · Epic 19 (~30%).
**Eternal layer:** deaths write to `codex.dat` cemetery (Story 7.1) and are now viewable in-game via the Codex overlay (2026-08-18) — still a plain list, not the "Dragon Eye Book" set-piece.
**Recent (2026-08-18):** Codex overlay (Epics 18/19) — guild stats + fallen-heroes list, reachable from Main Menu and Pause Menu, portraits via `PortraitSocket`. Latest News feed (Epic 6 / FR-19b) — drains Story 8.5's eavesdropped rumours into the World Map board. Reputation effects + 5-tier HUD display (Epic 14 / T3-2) — patron tip bonus, recruit stat bonus, moves on mission failure too now.
**Recent (2026-07-15):** serve beer-emote · Story 8.5 eavesdropping · player+patron position restore · Story 8.4 ambient chat.
**Not started:** Epics 5, 9, 10, 12, 15, 16, 17, 20, 21, 22, 23; Epic 24 Audio ~15% (SfxManager + coin SFX).

---

## Legend
- [x] Done — verified working in code
- [~] Partial — code exists but incomplete vs epic requirements
- [ ] Not started — no corresponding implementation

---

## Epic 1: Foundation Architecture & Modding Groundwork
**Status: ✅ 100% DONE — all 9 stories implemented; failsafe suite run & GREEN (27/27). Verified 2026-06-24.**

### Story 1.1: Tech Debt Resolution
- [x] Duplicate `systems/PlayerManager.gd` deleted
- [x] `assign_adventurer_to_mission()` orphan removed from GameManager.gd
- [x] `"on_mission"` match arms fixed to `"On Mission"` (correct capitalization)
- [x] **AdventurerStatus enum** (`scripts/resources/adventurer_status.gd`) — CREATED + adopted (verified used in GameManager, DataManager, AdventurerRosterPanel, recruitment_popup, debug_panel, failsafe_test) — 2026-06-24
- [x] Dead `@onready var log_container` removed from `systems/DataManager.gd` — verified 2026-06-24

### Story 1.2: Domain-Split EventBus — DONE (verified 2026-06-24)
- [x] `scripts/buses/` exists with all 6 buses: GameBus, AdventurerBus, EconomyBus, WorldBus, GuildBus, LegacyBus
- [x] GameManager routes signals through the domain buses (e.g. `firewood_changed → EconomyBus.firewood_changed`). [Spot-check recommended: confirm all *consumers* subscribe via buses, not just GameManager forwarding]

### Story 1.3: Configuration Spine
- [x] `data/config/` directory created
- [x] `game_config.json` created — starting values, max_adventurers, firewood, tax, autosave
- [x] `features.json` created — feature flags for gating incomplete systems
- [x] `DataManager.get_config()` and `DataManager.get_feature()` methods added
- [x] `GameManager._apply_config()` reads from config; `reset_game_state()` reuses it

### Story 1.4: Project Structure Migrations
- [x] `Player.tscn` correctly at `scenes/player/Player.tscn`
- [x] `PlayerManager.gd:PLAYER_SCENE_PATH` points to `"res://scenes/player/Player.tscn"`
- [x] ZonePromptUI removed from autoloads — now per-scene CanvasLayer
- [x] All callers use `ZonePromptUI.find(get_tree())` group lookup instead of `/root/ZonePromptUI`
- [x] main_tavern.gd and exteriorworld.gd instantiate ZonePromptUI locally

### Story 1.5: Dual-File Save Architecture Skeleton
- [x] SaveSystem.gd — dual-file architecture (`savegame.json` + `codex.dat`)
- [x] Backup restore method works (`restore_from_backup()`)
- [x] Save validation exists (checks required fields)
- [x] `schema_version` field in save data + `_migrate_save_data()` for future upgrades
- [x] `codex.dat` — eternal cross-run persistence (fallen heroes, guild achievements, run stats)
- [x] Atomic writes (write `.tmp` then rename)
- [x] `AUTOSAVE_INTERVAL` and `MAX_BACKUP_FILES` read from DataManager config

### Story 1.6: MinigameInterface Base Class
- [x] `scripts/minigames/minigame_interface.gd` — `class_name MinigameInterface` with 4 virtual methods + signals + state tracking
- [x] `scripts/minigames/harvest_minigame.gd` — placeholder subclass proving polymorphism pattern
- [x] Day-end sequence can call `pause_minigame()` on any `MinigameInterface` subclass without knowing concrete type

### Story 1.7: Plugin Installation Suite
- [x] **LimboAI** — GDExtension in `addons/limboai/`, auto-loads via `.gdextension` (no plugin.cfg needed)
- [x] **Debug Menu (Calinou)** — installed, enabled, registered as autoload
- [~] **GdUnit4** — NOT actually installed (no `addons/gdUnit4/`, not in editor_plugins). The failsafe suite (Story 1.9) is a **standalone headless script** instead, so this never blocked Epic 1. Install only if editor-integrated tests are wanted later.
- [x] **QuestSystem 2** evaluation — documented in `game-architecture.md` D8 Plugin Decisions Log (QS2 default, yggdrasil backup)
- [x] **dialogue_manager** — installed and active
- [x] **asset_placer** — installed and active (dev tool)

### Story 1.8: Modding Foundation Stubs
- [x] 5 MOD-8 hook methods on GameManager: `on_patron_spawned`, `on_mission_resolved`, `on_day_advanced`, `on_adventurer_hired`, `on_adventurer_died` — each emits to domain bus
- [x] Hooks wired into existing code paths (advance_day, hire_adventurer, handle_adventurer_death, _resolve_mission)
- [x] `data/config/factions.json` — rival guilds + 5 biome definitions with schema_version
- [x] `WorldManager.load_faction_data()` reads factions.json at startup
- [x] 3 hardcoded class/name lists replaced with `DataManager.get_config()` lookups (GameManager fallback recruits, recruitment_popup classes + names)
- [x] `adventurer_classes` and `adventurer_names` added to game_config.json

### Story 1.9: Failsafe Test Suite
- [~] GdUnit4 NOT installed — the suite is a standalone headless script (no plugin dependency), so this is fine
- [x] `test/failsafe_test.gd` — 4 tests: save/load round-trip, loot RNG distribution, mission success formula, AdventurerStatus transitions
- [x] `GameManager.roll_loot()` static method created for loot distribution (gold 75% / equipment 20% / artifact 5%)
- [x] Failsafe suite RUN & GREEN — **27/27 pass** (save round-trip, loot bands, mission formula, status transitions), verified 2026-06-24. NOTE: these are NOT GdUnit4/editor tests — `test/failsafe_test.gd` is a standalone headless script. Re-run anytime: `"<godot>" --headless --script res://test/failsafe_test.gd --path "F:\GAME I AM MAKING\shiningsun"`

---

## Epic 2: Main Menu, Pause Menu & Game Settings
**Status: ~92% — 2.1 / 2.2 / 2.3 / 2.4 DONE; New Game state-reset bug fixed 2026-07-12. Remaining: New Game→tavern flow polish (2.1) overlaps Epic 6 rework.**

### Story 2.1: Main Menu Scene — PARTIAL
- [x] `MainMenu.tscn` + `main_menu.gd` — Start, Continue, Quit buttons exist
- [x] Continue button disabled when no save file exists (`has_save_game()` check)
- [x] New Game → **resets all game state** (`reset_game_state()`) then transitions to HexMapTest — fixed 2026-07-12 (was inheriting the prior session's Day/gold/roster in-memory; see Epic 11)
- [~] Continue → loads save then transitions to MainTavern — load has known issues
- [x] Quit → `get_tree().quit()`
- [x] "Overwrite existing save" confirmation on New Game when a save exists (2026-07-05)
- [x] Settings button wired — opens the settings overlay from Main Menu + Pause Menu (2026-07-05)

### Story 2.2: Settings Screen — DONE (2026-07-05, verified headless)
- [x] `SettingsManager` autoload — loads / applies / saves settings; `default_bus_layout.tres` adds Master/Music/SFX buses
- [x] Volume sliders (Master/Music/SFX) drive the audio buses; Fullscreen toggle
- [x] `user://settings.cfg` save/load round-trip (verified 0.5 → save → load → 0.5)
- [x] Code-built settings overlay (`scripts/menus/settings_menu.gd`), reachable from Main Menu + Pause Menu
- NOTE: Master affects all audio immediately; Music/SFX buses are wired but only affect players explicitly assigned to those buses (audio categorization is future work)

### Story 2.3: Keybinding Remapper — DONE (2026-07-05, verified headless)
- [x] Rebind Move Forward/Back/Left/Right, Jump, Interact via the Settings overlay "Controls" section
- [x] Click-to-listen: click a key button → press a new key → rebinds (Esc cancels); uses physical keycodes (keyboard-layout independent)
- [x] Persisted to `user://settings.cfg` `[input]` and re-applied on startup (SettingsManager)
- [x] "Reset Controls to Default" restores project defaults (verified E→K→reset→E headless)

### Story 2.4: Pause Menu & Save Handler — DONE
- [x] Full pause menu: Save, Load, Save & Exit, Main Menu, Quit
- [x] Confirmation dialogs on destructive actions (Main Menu, Load, Quit)
- [x] Save & Exit: saves then returns to main menu
- [x] Load: validates save exists, loads, reloads scene
- [x] Toggle pause with `get_tree().paused`
- [x] `process_mode = PROCESS_MODE_ALWAYS` (works while paused)

---

## Epic 3: The Living Tavern — Core Day Loop
**Status: ✅ ~100% — firewood/beer authority + HUD notifications DONE 2026-07-05; 3.4 coin-payment animation + SFX DONE 2026-07-11. Fireplace re-spec'd to continuous decay + additive stoking; minigame polished (target marker, hearth theme, exit-orphan fix).**

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
- [x] **HUD notifications** — `NotificationManager` autoload (2026-07-05): non-blocking top-center banners for low gold/beer/comfort, edge-triggered + cooldown + max-2, config thresholds in `game_config.json`. Verified headless.
- [x] **Coin-payment reward** (Story 3.4 juice, 2026-07-11) — `scripts/fx/coin_reward.gd` procedural 3-coin burst on patron payment + `SfxManager` autoload (pooled SFX on the SFX bus, `coins.mp3` / `cointinkle.wav`)
- [x] **Fireplace continuous decay + additive stoking** (2026-07-11) — re-spec'd from stepped to continuous drain; stoking adds onto current fuel (no reset); config-driven rates. Minigame polished: glowing target marker at the optimal spot, warm hearth theme, debug strip; exit-to-menu orphan bug fixed

---

## Epic 4: The Adventurer Roster
**Status: ~85% — 4.1 / 4.4 / 4.5 DONE (2026-07-08). 4.3 portrait socket now BUILT (Story 7.5) — renders class silhouettes today, Guilo's Tarot art swaps in via data with zero code change. Only 4.2 hire-UI polish + minor 4.3 deltas remain.**

### Story 4.1: Daily Hire Pool Generation — ✅ DONE
- [x] 3–5 recruits/day from config (`hire_pool_min/max`)
- [x] **78-card Tarot deck** (`data/config/tarot_deck.json`) + `DataManager.get_tarot_deck / get_tarot_card / get_all_tarot_ids`
- [x] Enriched record: **unique Tarot card**, experience tier, daily wage, drink preference — all data-driven (MOD-2)
- [x] Unique-card rule: no dupe in pool, none on roster, none re-offered after hire (`hired_tarot_cards`)
- [x] `AdventurerBus.recruitment_pool_changed` emitted; verified (78 = 22 major/56 minor, pool 3–5, 0 dupes)

### Story 4.2: Hire an Adventurer — ⏸️ PARKED (Tarot portraits)
- [x] `hire_adventurer()` — gold gate, roster-cap + refund, unique ID, adds READY, removes from pool; Tarot card carried onto the roster record
- [ ] Hire/recruit UI + portrait display — deferred until Tarot portraits land

### Story 4.3: Roster Panel Display — 🔨 MOSTLY DONE (portrait socket built; awaiting Guilo art for the final swap)
- [x] Panel renders name, class+level, color-coded status, wage; greys non-Ready; refreshes on roster/day change (audit done)
- [x] **Tab-toggle display bug fixed** (2026-07-12) — panel derived open/closed from the animating `position.x` and force-showed on every roster change, so Tab raced the slide and often hid instead of showing ("adventurers not displaying"). Now uses an explicit `is_open` flag + single reused tween; Tab is the sole authority
- [x] **Portrait socket wired** (Story 7.5) — roster panel + recruitment popup render `PortraitSocket.resolve_texture(adventurer)`: Tarot portrait when present, else class portrait, else class-colored silhouette (never blank). Guilo's Tarot art drops in via `adventurer.portrait` with **zero code change**
- [ ] Remaining delta: show Tarot card name + drink pref, un-hardcode wage display, "Returns in N days" countdown

### Story 4.4: Daily Wage Deduction — ✅ DONE (verified unit + integration)
- [x] `apply_daily_wages()` — per-adventurer `daily_wage`, all statuses except DEAD, runs before the morning briefing
- [x] Gold floors at 0 + warning log; empty roster = no-op; emits `gold_changed` once → EconomyBus; fires exactly once in `advance_day` (old flat-wage path stripped — no double-charge)

### Story 4.5: Dismiss an Adventurer — ✅ DONE
- [x] Confirm prompt "Dismiss [Name]? Costs 5 gold and −1 Reputation" (cancel = nothing)
- [x] Blocked if ON_MISSION or gold < 5 (adventurer remains — fixed the old remove-before-check bug); on confirm: −5g, −1 rep, removed, `adventurer_roster_changed` + `gold_changed` emitted

### Cross-cutting fix (2026-07-08) — save/load status "Unknown"
- [x] Godot's `JSON.parse` floatifies saved ints and GDScript `match` won't coerce float→int, so hiring a save-carried recruit showed "Status: Unknown". Fixed via `_normalize_adventurer_ints()` on hire + on load (roster + recruits) + defensive coercion in the roster panel (also cleans "5.0 days" → "5 days"). Existing saves self-heal on next Continue.

### Still pending
- [x] **Portrait socket** — BUILT (Story 7.5): `scripts/ui/portrait_socket.gd` `PortraitSocket.resolve_texture()` (Tarot → class portrait → class-colored silhouette), wired into roster panel + recruitment popup. Guilo's art swaps in via data only
- [ ] Class list 5-vs-4 (code: Fighter/Rogue/Mage/Ranger/Cleric · GDD MVP: Fighter/Rogue/Mage/Healer) — reconcile before class-tied content (see TECH_DEBT)
- [ ] Duplicate recruit generator in `DataManager` (parallel to the active GameManager path) — consolidate in 4.3 (see TECH_DEBT)

---

## Epic 5: Tutorial & Onboarding
**Status: 0% — Not started. ⚠️ BLOCKED-by-design: build AFTER Epic 6 settles (Epic 7 now DONE, so the Reveal gate is unblocked).**
Epic 5 is a thin *guiding layer* over other systems (it narrates them, it doesn't build mechanics), so its gates depend on those systems being final — building it now = throwaway work:
- **5.3** (narrate the first Reveal) — ✅ dependency cleared: **Epic 7 is complete** (Stories 7.1–7.6). Buildable whenever the tutorial pass begins.
- **5.5** (send a quest) needs **Epic 6** World Map dispatch — flagged by Raphael for rework.
- **5.1** (guild naming) needs `codex.dat` `run_count` + `guild_name` in the save (Epic 11 hardening).

- [ ] 5.1 Guild Naming + Tavern Discovery · 5.2 Serve-Beer gate · 5.3 Reveal gate · 5.4 Recruit gate · 5.5 Send-Quest gate — all Run-1-only hard gates

---

## Epic 6: World Map, World Generation & Mission Dispatch
**Status: ~60% — Generation + distance-aware placement work; Latest News feed shipped (2026-08-18); mission count / group-mission display still need rework**

- [x] **Hex map generation** — seeded RNG, simplex noise + radial falloff, biomes (sea/grass/forest/mountain)
- [x] **Settlement placement** — configurable count, minimum spacing enforcement
- [x] **World persisted** — `WorldManager.set_generated_world()` stores records; `display_mode` re-renders without regenerating
- [x] **Tavern hex selection** — player picks center (signal `tavern_hex_selected`)
- [x] **Missions assigned to hexes** — `WorldManager.assign_missions_to_hexes()` is now **distance-aware** (2026-07-12): a quest's distance from the tavern scales with `duration_days` (+ a touch of danger), so 1-day errands land near and long/dangerous ones sit far. Tunable via `mission_hexes_per_day` / `mission_distance_spread`
- [x] **Mission dispatch** — `send_on_mission()` / `send_party_on_mission()` with duration tracking
- [x] **Active mission timers** — tick down daily in `process_mission_returns()`
- [x] **Hex lock** — dispatched hex marked `locked`, freed on resolution
- [x] **Mission success formula** (FR-18) — `50% ± 3%/stat ± 2%/exp − 8%/danger`, clamped 10-95% ✅ EXACT MATCH
- [x] **Party missions** — average chance + party_size bonus (5% per extra member)
- [x] **Mission board UI** — SingleMissionCard + PartyMissionCard scenes
- [x] **World map assets** — coast variants, forest/mountain toppers, decorative props, tavern building
- [x] **Data-driven missions** — `data/missions/mission_types.json` + fallback generation
- [~] **Pre-dispatch panel** (FR-19) — mission board shows info, but unclear if full "estimated success %" is shown before confirm
- [x] **Latest News feed** (FR-19b, 2026-08-18) — top-left panel on the World Map board drains `WorldManager.overheard_rumours` (Story 8.5), 5 most recent, newest first; placeholder message when empty. `scenes/world/world_map_board.gd`
- [ ] **Hex Strategy Map plugin evaluation** — not documented
- [~] **World NOT yet saved to disk** per WorldManager comment: "Saving to disk is a later step (gated on the load-game fix)"
- **NOTE (Raphael):** ~~randomly placed~~ **fixed 2026-07-12** (now distance-aware — 1-day quests no longer spawn across the map). Still to rework: only ~3-4 missions shown at once, and post-30-day group missions aren't displayed.

---

## Epic 7: The End-of-Day Reveal
**Status: ~95% — Stories 7.1–7.6 shipped (the "sacred ritual" reveal + crash-safe persistence). Only the optional "Begin the Day" closing flourish remains.**

- [x] **Morning briefing sequence** — panels shown one at a time, "Report N of M" counter
- [x] **Report contains**: mission name, adventurer name/class, success/fail, alive/injured/dead status
- [x] **Solo + party report types** with different data shapes
- [x] **Mission resolution consequences** — success: +gold, +1 day rest. Failure: injury (2-5 days), possible death
- [x] **Personality trait effects on resolution** — Reckless = extra injury chance, Lucky = bonus reward
- [x] **Three visual variants** (RETURNED warm / WOUNDED muted / DEAD dark) — **Story 7.2**, single reveal panel recolors by fate via stored `panel_style`
- [x] **Forced death pause** — **Story 7.3**, continue button hidden, `reveal_death_pause_seconds` (2.0) timer, then fade back in; input blocked during the pause
- [x] **Portrait emotional states** — **Story 7.5**, `PortraitSocket.resolve_texture(adv, emotional_state)` with 4-tier fallback (emotional variant → Tarot portrait → class portrait → class-colored silhouette); never null (MOD-6)
- [x] **Flavor lines** from class+outcome dictionary — **Story 7.6**, data-driven `data/reveal/flavor_lines.json` (6 classes × 3 outcomes × 3 lines + fallback), no-repeat-in-a-row (MOD-2)
- [x] **Group panel** with Connection flag — **Story 7.4**, side-by-side member tiles, party-wide tone, "✦ A bond was forged" when ≥2 Major Arcana survive (codex patch point for Epic 18)
- [ ] **"Begin the Day"** closing ceremony — advance button exists; dedicated ceremony flourish still optional (not scoped as a 7.x story)
- [x] **Reveal-before-display pattern** — **Story 7.1**, mission outcomes + deaths committed to `codex.dat` (cemetery record: id/name/class/tarot_card/hire_day/death_day/missions) and to savegame **before** the reveal plays; `LegacyBus.adventurer_died` fired at the death; reveal is now purely cosmetic + crash-safe

---

## Epic 8: PatronNPC Systems & Ambient Life
**Status: ~75% — core loop solid (5 patrons, serve, coin reward); Stories 8.4 ambient chat + 8.5 eavesdropping done; serve beer-emote polish. Remaining: FSM state-granularity (8.1).**

- [~] **PatronNPC FSM** — `WALKING_TO_TABLE → SITTING_WAITING → DRINKING → LEAVING` (4 states, not 6 as architecture specifies WALKING→SEATED→WAITING→SERVED→DRINKING→LEAVING). **MVP-quality only — animations are placeholder, not real character animations.**
- [x] **NavigationAgent3D movement** — patrons walk to table, walk to exit
- [x] **Random model swap** — picks from 5 KayKit adventurer GLBs per patron
- [x] **Animations** — Idle and Running_A via AnimationPlayer (from GLB models)
- [x] **Service system** — player within 3.0m; patron shows a **beer-mug emote** above the head (2026-07-15, replaced the old yellow sphere)
- [x] **Timer-based behavior** — sit 2-5s, drink 8-15s
- [x] **Table management** — 5 positions, occupied tracking, availability check
- [x] **Up to 5 concurrent** (max_patrons configurable @export) — playtest-confirmed `5/5`
- [x] **Payment with comfort-based tip** — base 6-12g random + fire comfort multiplier
- [x] **No-beer check** — won't spawn if beer is 0, won't serve if no stock
- [x] **Patron flavor** — random name (first + surname), random origin ("the bridge crossroads", "the guard post", etc.)
- [x] **Spawn replacement** — 70% chance to spawn new patron after one leaves (5-15s delay)
- [x] **Despawn all** — `despawn_all_patrons()` for night/day-end
- [x] **Story 8.4 — Ambient patron dialogue** (2026-07-12) — billboarded `Label3D` speech bubbles above drinking patrons; origin-keyed lines from `patron_lines.json` `ambient` (MOD-2), staggered pop-in/fade. `PatronSpeechBubble` (`scripts/fx/`) is the swap point for a richer panel (8.4-B/C) later. (Lightweight Label3D per the AC — not the full Dialogue Manager.)
- [x] **Up to 5 patrons** per FR-1 — now 5/5 (was mis-tracked as "max 3")
- [x] **8.5 Eavesdropping proximity trigger** (FR-50, 2026-07-15) — loitering near 2+ drinking patrons overhears a rumour: `NotificationManager` banner + `WorldBus.settlement_event(payload)` + queued to `WorldManager.overheard_rumours`; once per group per day; rumour text fills {place}/{faction} from world data (MOD-7). Latest News feed sink is the Epic 6 patch-point (pool ready to drain).

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
**Status: ~58% — save + player/patron position restore work; New Game reset + fire-fuel load fixed 2026-07-12. Remaining: disk-save overwrite window; full architecture-compliance.**

- [x] **Single-file JSON save** — `user://eternal_guild_save.json`
- [x] **3-backup rotation** — `create_save_backup()` rotates backup1→2→3
- [x] **Comprehensive state saved**: gold, beer, day, tax_due_day, adventurers (full array), max_adventurers, firewood, fuel, recruits, missions, active_missions, patron_pool, reputation, tier, morale
- [x] **Save metadata**: timestamp, date string, game version, playtime, save type
- [x] **Autosave** — every 5 minutes + on day change (after day 1)
- [x] **Load with validation** — checks required fields (current_day, gold, beer_stock, adventurers)
- [x] **Restore from backup** method exists
- [x] **Signal re-emission on load** — all UI signals fired to refresh displays
- [x] **Game over save** — saves state even on game over
- [x] **`schema_version`** — save versioned with migration support
- [x] **`codex.dat`** — eternal cross-run persistence (fallen heroes, achievements, run stats)
- [x] **Atomic writes** — write to `.tmp` then rename
- [x] **Player position + scene saved/restored** (2026-07-12, **confirmed in-game**) — `player_position` / `player_scene` in the save; `PlayerManager` pending-spawn puts the player back where they saved, and Continue routes to the saved scene
- [x] **Patron exact-restore** (2026-07-12, **confirmed in-game**) — each patron's position/state/model/identity serialized (`RealisticPatron.to_save`) and rebuilt by `PatronSpawner.restore_patrons()` on load (day-boundary autosaves have none, since night despawn runs first)
- [x] **New Game state-reset fixed** (2026-07-12) — `reset_game_state()` now also clears `active_missions`, `pending_reports`, `has_pending_briefing`, `tavern_reputation`, `taxes_paid_count`, `tax_grace_days`, `mission_tier_unlocked`; `_start_new_game()` calls it so a New Game no longer inherits the prior session's state.
- **NOTE (Raphael):** Load pass — (a) ~~fireplace fuel loads as 0%~~ **fixed 2026-07-12**; (b) old disk save isn't overwritten until the new game's Day-2 autosave (New Game→quit-before-Day-2 → Continue loads the old game) — **still open**; (c) ~~player + patron positions~~ **DONE 2026-07-12** (player scene+position; patrons rebuilt at exact position/state/model).

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
**Status: ~40% — Tiers, HUD display, and effects shipped (2026-08-18, T3-2). Disturbance system still not started.**

- [x] `tavern_reputation` integer tracked in GameManager, mutated only via `adjust_reputation()` (single authority)
- [x] +2 reputation on successful mission
- [x] -1 reputation on mission failure (2026-08-18) — previously only moved on success/dismiss
- [x] -1 reputation on adventurer dismiss
- [x] Tier system partially uses reputation (tier 3 requires reputation >= 50)
- [x] **5-tier label** (2026-08-18) — Unknown → Known → Trusted → Respected → Honored, data-driven via `data/config/game_config.json` `reputation_tiers`, `GameManager.get_reputation_tier()`
- [x] **Reputation effects** (2026-08-18) — tier's `tip_bonus` applied in `calculate_patron_tip()`; `recruit_stat_bonus` applied to rolled stats in `generate_fallback_recruits()`
- [x] **HUD display** (2026-08-18) — "Reputation: N (Tier)" in the tavern top stats bar, code-built, updates live via the new `reputation_changed` signal (bridged to `GuildBus`, previously an empty stub)
- [ ] **No disturbance system** (pickpocket, drunk, rare visitor)
- [ ] **No reputation decay over time** (only moves on success/failure/dismiss — no passive drift)
- [ ] **No reputation display** in HUD

---

## Epics 15–24: Not Started

| Epic | Status | Notes |
|------|--------|-------|
| 15: Farmland & Drinks | 0% | No farmland, no drink types beyond beer |
| 16: Staff & Automation | 0% | LimboAI installed but not enabled; no staff NPCs |
| 17: Tarot Evolution | ~5% | 78-card deck data + `DataManager` Tarot API exist and recruits carry a unique card (Epic 4.1); no evolution/leveling mechanic yet |
| 18: Codex | ~30% | **Basic viewer shipped (2026-08-18)** — `scripts/menus/codex_menu.gd`, a code-built overlay (same pattern as `settings_menu.gd`) reachable from Main Menu + Pause Menu, shows guild-wide stats (runs/best day/gold/missions). Not yet the full "Dragon Eye Book" presentation — plain list UI, no dedicated art/theming pass |
| 19: Memorial & Cemetery | ~30% | **Basic viewer shipped (2026-08-18)** — same `codex_menu.gd` renders `codex.dat.fallen_heroes` (name/class/Tarot card/hire+death day/missions completed) with `PortraitSocket` portraits, verified live against real save data. Not yet a dedicated memorial wall / cemetery scene — this is a list, not the eventual set-piece |
| 20: Guild Fame | 0% | No fame system |
| 21: The Reading | 0% | No run-end ceremony |
| 22: Legacy Transition | 0% | No LegacyTransition class |
| 23: City Hub Buildings | 0% | No church, apothecary, alley |
| 24: Audio & Ambient | ~15% | `SfxManager` autoload (pooled SFX on the SFX bus) + coin-payment SFX live; Master/Music/SFX bus layout from Epic 2.2. No music beds / ambient loops yet |

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
| auto_reload | Dev tool (hot-reload) | ✅ Installed & enabled |
| GdUnit4 | Epic 1 (test suite) | ❌ Not installed — failsafe suite is a standalone headless script instead (no dependency) |
| QuestSystem 2 | Epic 9, 23 | ⚠️ Not installed; **evaluation done** — QS2 chosen, yggdrasil backup (game-architecture.md D8) |
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
| `data/config/game_config.json` | All balance values (hire pool, wages, drink prefs, fire, reveal pause…) | DataManager / GameManager |
| `data/config/features.json` | Feature flags for gating incomplete systems | DataManager |
| `data/config/factions.json` | Rival guilds + 5 biome definitions | WorldManager |
| `data/config/tarot_deck.json` | 78-card Tarot deck (archetype layer) — id/name/arcana/suit/portrait/art_brief | DataManager (`get_tarot_deck/get_tarot_card`) |
| `data/config/class_colors.json` | Per-class silhouette colors + default | PortraitSocket |
| `data/reveal/flavor_lines.json` | Reveal flavor lines keyed by class × outcome (+ fallback) | morning_briefing (Story 7.6) |

**Missing data files (still absent):**
- `data/config/drink_affinity.json` — drink → adventurer class mappings (drink *preferences* currently live in `game_config.json`; a dedicated affinity map is the architecture target)

_(Correction 2026-07-11: `game_config.json`, `features.json`, and `factions.json` were previously listed here as "missing" — they have existed since Stories 1.3 / 1.8. Fixed.)_

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
9. Advance the day → the End-of-Day Reveal plays: per-adventurer portraits, fate-toned panels (returned/wounded/dead), authored flavor lines, a forced pause on death, and group panels with party bonds — deaths are written to the `codex.dat` cemetery
10. Manage beer shortage consequences (escalating morale damage)
11. Pay taxes every 30 days or face bankruptcy game over
12. Save/Load/Continue from main menu
13. Pause → Save & Exit → Continue later
14. Walk between tavern interior and exterior world (player only — NPCs don't cross scenes yet)

---

## Blocking Gaps & Next Development

**Epic 1 groundwork is 100% complete** — the old pre-flight checklist that lived here (AdventurerStatus enum, 6 EventBuses, config spine, `schema_version`, `codex.dat` skeleton, MinigameInterface, ZonePromptUI de-autoload) is all done and verified (27/27 failsafe GREEN). The one item never actually done — **install GdUnit4** — turned out to be unnecessary; the failsafe suite is a standalone headless script.

**Current blockers / rework (2026-07-11):**
1. **Load / Continue rework** (Epic 11) — Raphael reports load isn't behaving; needs a debugging pass. Blocks world-to-disk save (Epic 6) and Continue polish (Epic 2.1).
2. **World Map dispatch rework** (Epic 6) — only 3 random missions shown; not the desired system; post-30-day group missions not surfaced.
3. **Guilo Tarot portraits** — unblocks the final art swap in Epic 4.3 / recruitment / the Reveal (the socket already renders silhouettes, zero code change to swap the art in).
4. **Class list 5-vs-4 reconciliation** (code Fighter/Rogue/Mage/Ranger/Cleric vs GDD MVP Fighter/Rogue/Mage/Healer) — before class-tied content.
5. **Duplicate recruit generator** in `DataManager` — consolidate with the active GameManager path.

**Highest-value next work for the Kickstarter demo:**
- **Codex / Memorial viewer** (Epics 18/19) — cemetery data now writes to `codex.dat` (Story 7.1) but has no in-game viewer; the Dragon Eye Book / memorial wall makes those deaths visible & meaningful.
- **Epic 6 completion** — the map rework, save world to disk, Latest News feed.
- **Epic 8** — bump patrons to 5, add the eavesdropping trigger, wire Dialogue Manager ambient lines.
- **Epic 5 (Tutorial)** — the Reveal gate (5.3) is now unblocked (Epic 7 done); still waits on Epic 6 for the send-quest gate (5.5).
