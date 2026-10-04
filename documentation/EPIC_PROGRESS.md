# Eternal Guild — Epic Progress Tracker
Updated: 2026-10-03 (Story 10.3 built, in review: Den Fa's Early/Mid/Late states; Story 10.2 done after its code review: the dialogue box, Den Fa first; progress snapshot refreshed; BMAD `sprint-status.yaml` created and seeded from this file; demo roadmap written; Epic 25 through Story 25.30) · 2026-09-24 (Epics 25–26 added — Demo Art Pipeline & Full Cast; Epic 16 demo-Partial; Story 4.2 unparked; 6-class list decided) · 2026-08-20 (mission-count display cap fixed + animation-hang regression fixed + duplicate recruit names fixed + roster portrait clipping partially fixed, on top of 2026-08-18's Codex/Memorial viewer + Latest News feed + reputation effects + rumour-driven missions + save-overwrite fix + class-list reconciliation + patron FSM granularity + real patron animations + loot & equipment). Earlier epics last verified 2026-06-21 — re-verify against source before relying on them.

Cross-references `epics.md` against working code in `shiningsun/`.

## Snapshot (2026-10-03)
**Story totals (BMAD `sprint-status.yaml`):** 171 stories in 26 epics — 52 done, 10 in review, 14 in progress, 95 backlog.
**Done:** Epic 1 · Epic 3 · Epic 7 · Epic 8.
**In progress:** Epic 2 (3/4) · Epic 4 (3/5) · Epic 6 (4/6) · Epic 11 (2/4) · Epic 12 (4/5) · Epic 13 (2/4) · Epic 14 (3/6) · Epic 16 (art + seam from 25.13; FSMs not started) · Epic 17 (deck data) · Epic 18 (basic Codex overlay) · Epic 19 (fallen-hero data + list) · **Epic 25 (4/32 done, 10 in review, 25.1 in progress)**.
**Started 2026-10-03:** Epic 10 (Story 10.2, the dialogue box, done; Story 10.3, Den Fa's Early/Mid/Late states, in review).
**Not started:** Epics 5, 9, 15, 20, 21, 22, 23, 24 (SfxManager only), 26.
**Recent (2026-10-04):** Story 25.32 (in progress): Den Fa realistic without wings (verdict pending), the Cat's concept job queued. Story 25.31, the realistic human cast (in review): all 15 human bodies on route RL (the player, the Bartender, the Quest Dealer, six townsfolk, six classes), data-driven with fallbacks, the bar stools raised, the hall and town budgets measured with the full cast; Story 25.23, light and mood (in review). Details under "Epic 25 progress" below.
**Recent (2026-10-03/04):** darker concept prompts (122063b), realistic concepts (31213c0), the anime look presets (8453b5f, Test 23), the realistic Bartender spike (5ae8dc0); correct course → the realistic cast (sprint-change-proposal-2026-10-04.md in the BMAD workspace).
**Recent (2026-09-24 → 09-27):** the whole Epic 25 track so far — the tavern hall (shell, door, Hourglass Pillar, hearth, round bar, desk and board), the exterior (tavern, hill, path, bridge, village, forest), the six-class roster, the villager/patron kit, the Cat, Den Fa, the Bartender and the Quest Dealer; then the anime correct course (2026-09-26) and Story 25.30, the anime pipeline with the Quest Dealer as its first body (failsafe suite 502/502). Details under "Epic 25 progress" below.
**Next (see `_bmad-output/planning-artifacts/demo-roadmap-2026-10-03.md` in the BMAD workspace):** close the review queue (25.30 first), Story 10.2 (the dialogue box: walk up, press E, portrait, text and choices — Den Fa first; done 2026-10-03), 10.3 (Den Fa's Early/Mid/Late states; built 2026-10-03, in review), then a scope correct-course (Farmland, City Hub and the legacy transition: the Kickstarter plan and the epics disagree), then 25.31 (the realistic human cast, re-planned 2026-10-04) and the demo systems critical path.
**Tracking:** story statuses now live in the BMAD workspace's `_bmad-output/implementation-artifacts/sprint-status.yaml` (what the BMAD workflows read); this file stays the detailed per-feature log. Update both when a story changes status.

## Earlier snapshot (2026-08-20)
**Shipped:** Epic 1 (100%) · Epic 2 (~92%) · Epic 3 (~100%) · Epic 7 (~95%, all 6 stories) · Epic 13 (~85%).
**In progress:** Epic 4 (~88%) · Epic 6 (~70%, mission-count cap fixed) · Epic 8 (~80%, Stories 8.4 + 8.5 done, FSM granularity + real sit/cheer/stand animations, animation-hang regression fixed) · Epic 11 (~65%) · Epic 12 (~75%, built same-day as its own spec) · Epic 14 (~40%) · Epic 18 (~30%) · Epic 19 (~30%).
**Eternal layer:** deaths write to `codex.dat` cemetery (Story 7.1) and are now viewable in-game via the Codex overlay (2026-08-18) — still a plain list, not the "Dragon Eye Book" set-piece. Artifact-tier loot (Epic 12) now feeds the same eternal file.
**Recent (2026-08-20):** Mission-count display cap fixed (Epic 6) — `DataManager.generate_daily_missions_with_tiers()` used to `min(count, available_templates.size())`, so Tier 1 (the whole first ~30 days) only ever showed its 4 available templates regardless of the requested count; now cycles the shuffled pool with wrap-around so the requested count (6) always generates, with `add_mission_variety()` still giving each repeat its own name/location/client. This was the "only 3-4 missions shown at once" item tracked in this doc since 2026-07-11. Along the way, fixed the debug panel's "Force Generate New Missions" button, which was calling a different legacy code path (`GameManager.refresh_missions()`) than the one the World Map board actually uses (`GameManager.refresh_available_missions()`), making it misreport the fix during verification. Patron animation-hang regression fixed (Epic 8) — the real sit/cheer/stand-up animations shipped 2026-08-18 used `await animation_player.animation_finished`, which hung indefinitely in real gameplay (never caught by headless tests, which called the functions directly rather than through the real navigation-signal-triggered async flow) and permanently stranded patrons — no service indicator, E did nothing. Fixed by switching to `SceneTree.create_timer()` waits instead of the AnimationPlayer signal. Duplicate recruit names fixed (Epic 4) — `generate_fallback_recruits()` had no uniqueness check against the existing roster; now filters already-used names before picking, with a graceful repeat-name fallback if the pool is exhausted. Roster panel portrait clipping partially fixed (Epic 4) — the slide-in panel's shown position landed with zero margin from the screen's right edge, clipping the portrait; added a 24px margin. Explicitly deprioritized further precision here — the roster UI needs a fuller rework for the eventual 78-card scale.
**Recent (2026-08-18):** Codex overlay (Epics 18/19) — guild stats + fallen-heroes list, reachable from Main Menu and Pause Menu, portraits via `PortraitSocket`. Latest News feed (Epic 6 / FR-19b) — drains Story 8.5's eavesdropped rumours into the World Map board. Reputation effects + 5-tier HUD display (Epic 14 / T3-2) — patron tip bonus, recruit stat bonus, moves on mission failure too now. Rumour-driven missions (Epic 6) — eavesdropped rumours now have a chance to spawn a real, dispatchable mission on the map. Save-overwrite window fixed (Epic 11) — New Game force-saves the moment the tavern loads. Class list reconciled (Epic 4) — dropped Ranger, renamed Cleric→Healer to match the GDD's 4-class set, which every other file already used. Patron FSM granularity (Epic 8) — split SITTING_WAITING into SEATED/WAITING_SERVICE; corrected an unsourced "6-state" claim in this doc along the way. Real patron sit/cheer/stand-up animations (Epic 8) — the KayKit models had them all along; replaced the old scale-squash placeholder. Loot & equipment (Epic 12) — spec'd and built same day; `roll_loot()` was dead code until now, plus fixed a pre-existing bug where mission reports showed the reward range instead of the actual amount paid out.
**Recent (2026-07-15):** serve beer-emote · Story 8.5 eavesdropping · player+patron position restore · Story 8.4 ambient chat.
**Not started:** Epics 5, 9, 10, 15, 16, 17, 20, 21, 22, 23; Epic 24 Audio ~15% (SfxManager + coin SFX).

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
**Status: ~88% — 4.1 / 4.4 / 4.5 DONE (2026-07-08). 4.3 portrait socket now BUILT (Story 7.5) — renders class silhouettes today, Guilo's Tarot art swaps in via data with zero code change. Class list reconciled 2026-08-18. Duplicate recruit names + roster portrait clipping fixed 2026-08-20. Only 4.2 hire-UI polish + the duplicate-generator consolidation remain.**

### Story 4.1: Daily Hire Pool Generation — ✅ DONE
- [x] 3–5 recruits/day from config (`hire_pool_min/max`)
- [x] **78-card Tarot deck** (`data/config/tarot_deck.json`) + `DataManager.get_tarot_deck / get_tarot_card / get_all_tarot_ids`
- [x] Enriched record: **unique Tarot card**, experience tier, daily wage, drink preference — all data-driven (MOD-2)
- [x] Unique-card rule: no dupe in pool, none on roster, none re-offered after hire (`hired_tarot_cards`)
- [x] `AdventurerBus.recruitment_pool_changed` emitted; verified (78 = 22 major/56 minor, pool 3–5, 0 dupes)

### Story 4.2: Hire an Adventurer — 🔨 IN PROGRESS (unparked 2026-09-24: demo Tarot art = class silhouettes in the card frame)
- [x] `hire_adventurer()` — gold gate, roster-cap + refund, unique ID, adds READY, removes from pool; Tarot card carried onto the roster record
- [ ] Hire/recruit UI + portrait display — silhouette inside the Tarot card frame (Story 25.22); Tarot art swaps in later via the `portrait` path

### Story 4.3: Roster Panel Display — 🔨 MOSTLY DONE (portrait socket built; awaiting Guilo art for the final swap)
- [x] Panel renders name, class+level, color-coded status, wage; greys non-Ready; refreshes on roster/day change (audit done)
- [x] **Tab-toggle display bug fixed** (2026-07-12) — panel derived open/closed from the animating `position.x` and force-showed on every roster change, so Tab raced the slide and often hid instead of showing ("adventurers not displaying"). Now uses an explicit `is_open` flag + single reused tween; Tab is the sole authority
- [x] **Portrait socket wired** (Story 7.5) — roster panel + recruitment popup render `PortraitSocket.resolve_texture(adventurer)`: Tarot portrait when present, else class portrait, else class-colored silhouette (never blank). Guilo's Tarot art drops in via `adventurer.portrait` with **zero code change**
- [~] **Portrait clipping partially fixed** (2026-08-20) — the panel's slide-in `SHOWN_X` landed exactly `1920 - panel_width`, i.e. flush with the screen's right edge with zero margin, clipping the portrait's right side. Added a 24px margin (`SHOWN_X` 1570→1546). Raphael explicitly deprioritized further precision here — this card layout needs a fuller rework once the roster scales to a full 78-card deck
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
- [x] **Class list reconciled** (2026-08-18) — was 5 (Fighter/Rogue/Mage/Ranger/Cleric) vs. the GDD MVP's 4 (Fighter/Rogue/Mage/Healer). `class_colors.json`, `data/characters/classes.json`, and `recruitment_popup.gd` already used the GDD's 4; the active path (`game_config.json` + `GameManager.generate_fallback_recruits()`) was the one that had drifted — reconciled to match. See TECH_DEBT.
- [x] **Duplicate recruit names fixed** (2026-08-20) — `generate_fallback_recruits()` picked a random name with no uniqueness check against the existing roster, so two adventurers could end up sharing a name (e.g. two "Nina"s, caught live via a roster screenshot). Now filters out names already on the roster before picking, falling back to a repeat only if the whole pool is exhausted.
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
**Status: ~70% — Generation + distance-aware placement work; Latest News feed + rumour-driven missions shipped (2026-08-18); mission-count display cap fixed (2026-08-20); post-30-day group-mission display still needs rework**

- [x] **Hex map generation** — seeded RNG, simplex noise + radial falloff, biomes (sea/grass/forest/mountain)
- [x] **Settlement placement** — configurable count, minimum spacing enforcement
- [x] **World persisted** — `WorldManager.set_generated_world()` stores records; `display_mode` re-renders without regenerating
- [x] **Ruin hex reserved next to the tavern** (Story 6.2 AC) and the **"Unknown Ruins" hover** (Story 6.3 AC). Done 2026-09-24 via Story 25.2: `HexMapGenerator._reserve_ruin()` (seeded, no RNG drift), records gain `is_ruin` / `ruin_discovered`, the D1 Prior Ruins topper is used, and `WorldManager.is_mission_eligible()` keeps missions off it
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
- [x] **Rumour-driven missions** (2026-08-18) — eavesdropped rumours are no longer pure flavor: each has a `rumour_mission_chance` (default 20%, `game_config.json`) to also spawn a real, dispatch-ready mission via `PatronSpawner._maybe_spawn_rumour_mission()` + `WorldManager.assign_one_mission()` (reuses the same tiered generator and distance-band placement as the daily refresh). Latest News shows a follow-up line when it happens.
- [x] **Mission-count display cap fixed** (2026-08-20) — `DataManager.generate_daily_missions_with_tiers()` used `for i in range(min(count, available_templates.size()))`, so whenever a tier's template pool was smaller than the requested count, the board silently showed fewer missions. Tier 1 (the whole first ~30 days, before the first tax unlocks Tier 2) only has 4 templates total, so the board was hard-capped at 4 regardless of the requested 6. Fixed by cycling the shuffled template pool with wrap-around (`available_templates[i % available_templates.size()]`) so the requested count always generates; `add_mission_variety()` still randomizes each repeat's name/location/client so duplicates don't read as identical. Tier 2/3 (12/19 templates) were already unaffected. Verified headless (Tier 1: 4→6 missions generated and placed on hexes) and live in-game via the World Map board.
- [ ] **Hex Strategy Map plugin evaluation** — not documented
- [~] **World NOT yet saved to disk** per WorldManager comment: "Saving to disk is a later step (gated on the load-game fix)"
- **NOTE (Raphael):** ~~randomly placed~~ **fixed 2026-07-12** (now distance-aware — 1-day quests no longer spawn across the map). ~~only ~3-4 missions shown at once~~ **fixed 2026-08-20**. Still to rework: post-30-day group missions aren't displayed.

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
**Status: ~80% — core loop solid (5 patrons, serve, coin reward); Stories 8.4 ambient chat + 8.5 eavesdropping done; FSM granularity + real sit/cheer/stand animations landed 2026-08-18; animation-hang regression fixed 2026-08-20.**

- [x] **PatronNPC FSM** (5 states, 2026-08-18) — `WALKING_TO_TABLE → SEATED → WAITING_SERVICE → DRINKING → LEAVING`. Was 4 states (`SITTING_WAITING` collapsed "just sat" and "wants service, indicator showing" into one). **Correction:** the previously-noted "architecture specifies 6 states (WALKING→SEATED→WAITING→SERVED→DRINKING→LEAVING)" wasn't sourced from any design doc — checked all of them; it existed only as this bullet's own claim. Split `SITTING_WAITING` into `SEATED`/`WAITING_SERVICE` (a real, observable behavioral gap). `RealisticPatron.gd`.
- [x] **NavigationAgent3D movement** — patrons walk to table, walk to exit
- [x] **Random model swap** — picks from 5 KayKit adventurer GLBs per patron
- [x] **Real sit/cheer/stand-up animations** (2026-08-18) — all 5 patron GLBs turned out to already carry `Sit_Chair_Down/Idle/StandUp` and `Cheer` (missed on the first FSM-granularity pass, which wrongly claimed no fitting animation existed). Arriving plays Sit_Chair_Down → Sit_Chair_Idle; being served plays Cheer → back to Sit_Chair_Idle; the drinking timer firing plays Sit_Chair_StandUp before the patron actually gets up and walks out. Replaces the old `scale.y = 0.8/1.0` squash-hack. Locomotion (`Idle`/`Running_A`) unchanged.
- [x] **Animation-hang regression fixed** (2026-08-20) — the 2026-08-18 animation work used `await animation_player.animation_finished` in `_arrive_at_table()` and `on_drinking_timer_timeout()`, which hung indefinitely under real gameplay and permanently stranded patrons (no service indicator, pressing E did nothing — a real, caught-live regression). Never reproduced by headless tests because they called the functions directly, skipping the real navigation-signal-triggered async flow that actually exposed the hang. Fixed by switching to `SceneTree.create_timer()` waits (`_SIT_DOWN_SECONDS` / `_CHEER_SECONDS`) instead of the AnimationPlayer signal.
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
**Status: ~20% — Story 10.2 (the dialogue box, Den Fa first) done 2026-10-03; Story 10.3 (Den Fa's Early/Mid/Late states) built 2026-10-03, in review.**
- [x] Dialogue Manager plugin installed and active
- [x] Den Fa has a body and a seat by the hearth (Story 25.10)
- [x] **Story 10.2 — the dialogue box (done 2026-10-03, after its code review).** Walk up to Den Fa, press E: a box at the bottom of the screen shows his portrait (a drawn plate with his mirror mask until 25.17 paints the real one), his name, the line typing out and your replies (keyboard or mouse). The world keeps running; the player stands still; E, Enter, Space and Esc belong to the box until it closes (Esc ends a conversation, never the pause menu).
  - His conversation is `data/dialogue/den_fa.dialogue` (a DRAFT for Raphael to rewrite): first contact once a run, then one of three early openings, never the same twice in a row. Lines notice deaths this run, the reputation tier and the day.
  - `.dialogue` files read the game through `scripts/dialogue/dialogue_bridge.gd` only (reputation, tier, day, roster, hires and deaths this run, gold, demo, and saved conversation flags). GameManager now counts hires and deaths per run (saved).
  - `data/dialogue/speakers.json` names each speaker and their portrait path (Den Fa, the Quest Dealer, the Bartender, the Elder, the Bard).
  - Replaces 25.10's placeholder bubble (`den_fa_lines.json` retired). Failsafe Test 20 added, Test 18 updated.
  - Code review patches (2026-10-03): exported builds load the imported conversation; a line whose replies are all hidden plays as an ordinary line; a stalled conversation closes itself (a 10 s progress watchdog); a screen over the box (a popup, a mission board, pause) gets the keys; Tab and the debug keys stand down while a box is open; Den Fa standing up or walking off closes his conversation.
- [x] **Story 10.3 — Den Fa's states (built 2026-10-03, in review).** As the guild's reputation grows he moves from Early to Mid (at the Known tier) and Late (Trusted), never back; the tiers are `den_fa_state_tiers` in `game_config.json`. Each state has an entry conversation he plays once (`mid_enter`, `late_enter`) and its own openings, never the same twice in a row. Mid acknowledges and notices hires, deaths and the guild's name; Late states things and never asks. His Mid and Late lines are a DRAFT for Raphael to rewrite.
  - `GameManager.den_fa_state` (saved with the run, re-checked on load, reset by New Game), moved in `adjust_reputation()`; `GuildBus.den_fa_state_changed(old, new)`; `bridge.den_fa_state` for `.dialogue` files. Failsafe Test 21 added.
- [ ] The other key conversations arrive with their speakers: the Pillar Invitation, Final Missive and Beat 7 (10.1 panels / 10.4), the Bartender's Read and the Quest Dealer's Setup (Epic 16), the Elder (25.11), the Bard (9.1–9.5), the Legendary Wanderer (10.6), the Recruitment Offer (Epic 4's hire UI, 4.2); the Ambient Patron and the Villager's Voice stay bubbles (8.4, 25.14); the Discord has no words (26.11)
- [ ] No narrative panel system, no Hidden Threshold, no Kingdom Chronicle

---

## Epic 11: Campaign Save & Load
**Status: ~65% — save + player/patron position restore work; New Game reset + fire-fuel load fixed 2026-07-12; disk-save overwrite window fixed 2026-08-18. Remaining: full architecture-compliance.**

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
- [x] **Disk-save overwrite window fixed** (2026-08-18) — New Game now force-saves (`save_type: "new_game_start"`) the moment the tavern loads, via `GameManager.pending_new_game_save` set in `main_menu.gd` and consumed in `main_tavern.gd`'s `_ready()`. Fixes New Game → quit before Day 2 → Continue loading the previous run. Verified with a headless regression script (planted a stale save, ran the real code path, confirmed disk flipped to fresh state).
- **NOTE (Raphael):** Load pass — (a) ~~fireplace fuel loads as 0%~~ **fixed 2026-07-12**; (b) ~~old disk save isn't overwritten until the new game's Day-2 autosave~~ **fixed 2026-08-18**; (c) ~~player + patron positions~~ **DONE 2026-07-12** (player scene+position; patrons rebuilt at exact position/state/model).

---

## Epic 12: Loot & Adventurer Equipment
**Status: ~75% — built 2026-08-18 per the spec written the same day. Remaining: no UI polish beyond the one reveal-panel line (deliberately — see spec's non-goals).**

- [x] `GameManager.roll_loot()` (`scripts/GameManager.gd:1642`) — was dead code (unit-tested, never called). Now wired into `_resolve_solo_mission()` / `_resolve_party_mission()`, one roll per successful mission.
- [x] **Reward-amount bug fixed** — mission reports used to carry the config reward *range*; `complete_mission()`/`complete_party_mission()` now return the real rolled+paid amount and the report/reveal panel show that instead.
- [x] `data/economy/equipment.json` (11 items) + `data/economy/artifacts.json` (7 relics) — new files. Deliberately unglamorous tone per `01_VISION.md` (no magic-shop language; artifacts carry zero mechanical effect).
- [x] **Equipment tier** (20%) — single `adventurer.equipped_item` slot, flat +1/+2 stat bonus applied once at equip time, silently replaces whatever was equipped before. No inventory system (by design).
- [x] **Artifact tier** (5%) — `SaveSystem.record_artifact_found()`, persists to `codex.dat`'s new `artifacts_found` array, same append-only pattern as `record_fallen_hero()`.
- [x] **Codex "Artifacts Recovered" section** — third section in `codex_menu.gd`, alongside Guild Record and The Fallen.
- [x] **Reveal panel** — one terse `"· found: <name>"` line for equipment/artifact loot only; gold-tier loot stays invisible on purpose (folds into the reward number).
- [ ] Failure-path loot loss (the `equipment_damage`/`equipment_loss` tags already sitting unused in `mission_types.json`) — explicitly deferred, flagged as an open decision for Raphael in the spec.
- **Full spec:** `documentation/design/LOOT_AND_EQUIPMENT_SYSTEM.md` — still the reference for design intent, data schemas, and the open decisions not yet made.

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

## Epics 15–26

| Epic | Status | Notes |
|------|--------|-------|
| 15: Farmland & Drinks | 0% | No farmland, no drink types beyond beer |
| 16: Staff & Automation | ~10% (art + seam only) | **Demo-Partial since 2026-09-24:** Stories 16.1–16.5 (Bartender + Desk Manager) are in the demo's scope: in the demo profile both are there from day 1 (K9, Story 25.13); in the full game they unlock by reputation (Story 14.6) and are hired through Epic 16. LimboAI 1.6.0 loads as a GDExtension (`.godot/extension_list.cfg`; no editor-plugin switch needed) for 16.3/16.4 (plain GDScript FSM is the fallback). **Art and seam ready (Story 25.13, 2026-09-26):** the Bartender and the Quest Dealer bodies with seven staff clips; `scripts/game/staff_npc.gd` + `bartender.gd` / `quest_dealer.gd` with a cosmetic autopilot and the API 16.3/16.4 drive (`serve_toward`, `restock`, `enter_idle`, `set_work_state`, `drink_handed`); `GuildBus.staff_hired` / `staff_fired`; `GameManager.is_staff_hired(role)` (a stub for 16.1); the demo profile (`game_config.json` `profile: "demo"`, `demo_start_staff`) has both there from day 1 |
| 17: Tarot Evolution | ~5% | 78-card deck data + `DataManager` Tarot API exist and recruits carry a unique card (Epic 4.1); no evolution/leveling mechanic yet |
| 18: Codex | ~30% | **Basic viewer shipped (2026-08-18)** — `scripts/menus/codex_menu.gd`, a code-built overlay (same pattern as `settings_menu.gd`) reachable from Main Menu + Pause Menu, shows guild-wide stats (runs/best day/gold/missions). Not yet the full "Dragon Eye Book" presentation — plain list UI, no dedicated art/theming pass |
| 19: Memorial & Cemetery | ~30% | **Basic viewer shipped (2026-08-18)** — same `codex_menu.gd` renders `codex.dat.fallen_heroes` (name/class/Tarot card/hire+death day/missions completed) with `PortraitSocket` portraits, verified live against real save data. Not yet a dedicated memorial wall / cemetery scene — this is a list, not the eventual set-piece |
| 20: Guild Fame | 0% | No fame system |
| 21: The Reading | 0% | No run-end ceremony |
| 22: Legacy Transition | 0% | No LegacyTransition class |
| 23: City Hub Buildings | 0% | No church, apothecary, alley |
| 24: Audio & Ambient | ~15% | `SfxManager` autoload (pooled SFX on the SFX bus) + coin-payment SFX live; Master/Music/SFX bus layout from Epic 2.2. No music beds / ambient loops yet |
| 25: Demo Art Pipeline & Demo Cast | 18 of 32 built (15 done, 2 in review, 25.1 in progress; 2026-10-04) | Done after review: 25.2–25.10 (the gate asset, the tavern hall, the exterior, the class roster, Den Fa), 25.13 (the Bartender and the Quest Dealer), 25.14 (villager and patron body kit), 25.15 (the Cat), 25.17 (the cast's dialogue portraits), 25.29 (exterior ground, forest and village) and 25.30 (the anime character pipeline and the Quest Dealer); in review on branch `epic-25-pipeline`: 25.23 (light and mood) and 25.31 (the realistic human cast: all 15 human bodies on route RL, Raphael's Stage D verdicts pending); 25.1 (pipeline readiness) and 25.32 (Den Fa realistic, no wings; the Cat waits for her concept pick) in progress; see "Epic 25 progress" below. **Added 2026-09-24** (BMAD `sprint-change-proposal-2026-09-24.md`); **the anime cast added 2026-09-26** (`sprint-change-proposal-2026-09-26.md`). 32 stories — Tier 1 (25.1–25.25 + 25.30–25.32) is demo-critical: pipeline + gate asset, the tavern hall (shell, pillar, hearth, bar, desk/board, exterior), the demo cast (Healer/Ranger + one class list, Den Fa, the Elder, the Bard, Bartender + Quest Dealer, villager/patron body kit, the Cat, animations, dialogue portraits), memorial + cemetery, Codex lectern, UI skin, icons, card frames, lighting, soundscape, menu art, and the anime cast (25.30 the anime character pipeline + the Quest Dealer, 25.31 the human cast, 25.32 Den Fa and the Cat; sprint-change-proposal-2026-09-26). Tier 2 (25.26–25.27) is polish; stock art ships if it isn't done. 25.28 (the inked class reskins) is folded into 25.31. Already `in game`: D1 Prior Ruins, B1, B2, B6 and A1 (see `09_ASSET_INVENTORY.md`) | |
| 26: Full Cast | 0% | **Added 2026-09-24.** Post-demo: Onibi, Garden Manager, the King (portrait/seal/panels) + emissaries, rival musician, Legendary Wanderer, rival guilds, disturbance cast, guards/merchants/clergy, the peoples of the world, mountain elders, character states, Demon King panel art, commissioned NPC portraits |

### Epic 25 progress

**Story 25.1: pipeline readiness (in progress since 2026-09-24: built, waiting on the Blender add-on switch).**
- **Renderer verified: Forward+ (Vulkan).** Runtime `forward_plus`; the LookDev proof shot shows normal edges and the roughness mask working.
- `scenes/dev/LookDev.tscn` added for Stage D quick checks. It auto-quits at 240 s so it can't autosave over your save.
- Export folders `assets/{environment,characters}/custom/` created.
- Build contract and measured triangle budgets merged into 08 §1.
- `LICENSE-SOURCE.md` added in every asset folder; the unknown sources are listed in 09 §9.
- Failsafe Test 5 (asset-path integrity) added.
- Still open: restart Blender so the updated MCP add-on reports protocol 9.

**Story 25.2: D1 Prior Ruins in game (in review, 2026-09-24). The first asset through the whole pipeline.**
- Atlas-remapped in Blender and exported to `assets/environment/custom/d1_prior_ruins.gltf` (1,956 tris). The runes are emissive teal at roughness 0, so they have no outline.
- Imported headless; the PNG import settings match KayKit's atlas.
- Stage D passed in LookDev (map and tavern presets) and in-scene on `HexMapTest`.
- `HexMapGenerator._reserve_ruin()` reserves one land hex next to the tavern (Story 6.2). The pick is seeded, with no extra RNG draw, and a fixture-based drift guard proves every other hex is unchanged.
- `WorldManager.is_mission_eligible()` keeps missions off the ruin.
- The board hover shows "Unknown Ruins" (Story 6.3).
- Failsafe Test 6 added; the suite is at 57/57.

**Story 25.3: tavern room shell and front door (in review, 2026-09-25).**
- A 10-piece B9/B10 kit (2 m module, KayKit atlas) built in Blender and exported to `assets/environment/custom/`. Every piece is within budget (28–376 tris).
- `MainTavern.tscn` › `Architecture/Shell`: plank floor and porch, full-height far walls with windows and beams, the partition, knee-height near walls (the cutaway), and corner posts.
- The seven grey boxes are hidden. Their colliders are unchanged, which failsafe Test 7 checks against a fixture.
- New colliders close the south-wall gap either side of the door and the two back corner holes.
- The front door (`front_door.gd`) swings both leaves out when a patron or the player walks through, and emits `door_opened` / `door_closed` for the creak SFX (Story 25.24).
- Stage D passed in LookDev and in-scene. Patrons still walk entrance → table.
- Navmesh re-baked with the new colliders; the old bake had also gone stale on the porch. Verified in-game: patrons walk in → table → out, and the player walks out through the door to the exterior.

**Story 25.8: the Guild Tavern outside and on the map (in review, 2026-09-25). Pulled ahead at Raphael's request.**
- A1 Guild Tavern (4,568 tris), A2 hex miniature (996) and C9 home banner (116), built from one parametric Blender script (A2 is A1's "mini" level of detail) and exported to `assets/environment/custom/`.
- `ExteriorWorld.tscn`: A1 replaces the scaled KayKit tavern; the door faces the camera side. It's solid (collision proxies from the glTF), the "Press E" zone and label sit at the door, and the player arriving from the tavern lands in front of it.
- The exterior now has the ink-outline pass, like the map and the tavern.
- Map: the tavern hex shows A2 + the C9 banner, on new worlds and on old saves (display-time override; no RNG change, the drift guard still passes).
- Stage D passed in LookDev and in-scene (exterior round trip through the door; map tavern hex). Failsafe Test 8 added; the suite is at 98/98.

**Story 25.29: exterior ground, forest and village (in review, 2026-09-25). Added at Raphael's request after 25.8.**
- The exterior's ground is now one terrain mesh (drawn = walked): the old ground box was drawn at y −0.11 but walked at +0.25, and the KayKit props floated at 0.6 with detached shadows.
- The tavern stands on a hill (plateau at y 0, a creased 3 m ramp so the ink shader outlines it). A dirt path runs from the door down to a wooden bridge over a stream (walkable deck) and into the village square.
- Village: 8 KayKit buildings (solid) round the square with the well, the watermill on the stream, the windmill beyond, 22 street and yard props. The farm plots stay by the tavern.
- Forest: 422 seeded trees and rocks fill everything beyond the play area, with groves inside it and a clearing kept for the cemetery (25.18). Boundary walls keep the player in.
- Failsafe Test 9 added (every placed node sits on the terrain; no tree on the path, stream or a building); the suite is at 110/110.

**Story 25.4: the Hourglass Pillar (in review, 2026-09-25).**
- B6 built as stacked segments (foundation, base, worn stub, rune bands, the teal hourglass, the broken crown), 2,480 tris; runes and sand glow teal without an ink outline.
- `scenes/game/HourglassPillar.tscn` + `hourglass_pillar.gd`: reveal stages 0 (worn stub) to 4 (full); the demo shows 4 via `game_config.json` › `pillar_reveal_stage`; `glow_energy` for the day phases (25.23); `HumAnchor` + `reveal_stage_changed` for the hum (25.24).
- Placed at the centre of the round bar (×1.4, crown above the walls as in K2); solid, navmesh re-baked (control bake matched first). Patrons still reach their tables.
- Failsafe Test 10 added; the suite is at 131/131.

**Story 25.5: the Hearth and firewood (in review, 2026-09-25).**
- B1 built in stone (arched firebox, stepped chimney, timber mantel with candles, tankard and hourglass, andirons, faint Prior runes on the apron) with Den Fa's stone seat and a log niche; 2,660 tris. H3 firewood log and bundle.
- `scenes/game/Hearth.tscn` + `hearth.gd`: the fire's look (light, flames, sparks, smoke, ember glow, burning logs) follows the fireplace state (high / low / dying / out); out is dark (zero Comfort). Logs placed in the minigame appear on the andirons; the wood store shows the stock.
- Fixed on the way: `fireplace_zone.gd` looked its light and particles up by a path that resolved to nothing, so the fire never changed look; it now finds the hearth by group.
- In the hall: grey boxes removed, window panel behind the chimney made a full wall, trunk and a banner moved clear, the Tend Fire zone reshaped in front of the apron, navmesh re-baked (control bake matched first). Verified in-game: prompt, E opens the minigame, placed logs show, win → high → low → dying → out; 60 fps.
- Failsafe Test 11 added; the suite is at 174/174.

**Story 25.6: the round bar and drinks service (in review, 2026-09-25).**
- B2: a 6.2 m ring counter round the pillar (honey top, dark rune panels, brass foot rail, a flap at the back) with 12 low stools; B12: a round back-bar island hugging the pillar's base (bottles, beer and mead kegs); H1: the beer tankard, full and empty.
- Patrons now take seats from the scene: the stools' `patron_seat` markers first, the old table spots as the fallback; they slide onto the stool, face the bar, and hold a tankard while drinking (full, then empty). The drink clip itself is Story 25.16.
- The hall: the gitignored `TavernCounterCircular.glb`, the floating counter slab, the keg, old stools, plate and three barrels are gone (two barrels stand against the partition as stock); the counter is solid; navmesh re-baked (control bake matched first; every stool reachable). The walkway inside (1.15 m) is for the Bartender's scripted path (Story 25.13).
- Failsafe Test 12 added; the suite is at 203/203.

**Story 25.7: the guild desk and mission board (in review, 2026-09-25).**
- B3: a panelled timber desk (brass hourglass plaque, ledger, quill, candle, bell, contract rolls) facing the room, with the Quest Dealer's stool and `work_point` behind it and a spot for the Kingdom Chronicle; B4: a framed cork board with a painted island map and 8 pinned notices.
- The board shows one notice per open contract (today's pool minus the ones already taken) and updates on new days and dispatches. It stays out of the UI screens' `mission_board` group, which would block every zone's input.
- The hall: the old desk box (with its legs, chair and light) and the board box are gone; both prompt zones reshaped in front of their pieces and verified in-game (E opens the hire pool and the world map); navmesh re-baked (control bake matched).
- Failsafe Test 13 added; the suite is at 221/221.

**Story 25.9: the class roster (in review, 2026-09-25).**
- One class list everywhere (Fighter, Rogue, Mage, Healer, Barbarian, Ranger): `classes.json` gains the Ranger, the hire pool offers Barbarians and Rangers, the stray Cleric is gone, and the Barbarian has reveal lines. `GameManager.recruit_class_bonus` holds the per-class stat bonus (the first four unchanged).
- Healer (G5): the Mage body recoloured cream-white, with a hood trimmed in blue, a white tabard with a green cross, a satchel and a staff with a glowing green crystal. Ranger (G7): Rogue_Hooded recoloured forest green and brown leather, with a longbow and a quiver of red-fletched arrows. Both keep all 76 KayKit clips; the props sit on item bones, so the tankard hook works (the Healer's staff hides while drinking; the Ranger keeps the bow in the other hand).
- Portraits resolve for all six classes; Healers and Rangers now turn up as patrons.
- Failsafe Test 15 added; the suite is at 251/251.

**Story 25.14: the villager and patron body kit (done, 2026-09-25; pulled forward at Raphael's request).**
- Six townsfolk from one kit rig: a farmer (straw hat), a local (flat cap), a traveller (hood and bedroll), a town guard (kettle helmet, livery tabard and cape), a merchant (beret and purse) and an old woman (headscarf, shawl, cane). All keep the 76 KayKit clips; hands stay free for the tankard.
- Patrons pick a body by weight from `data/characters/townsfolk.json` (~80% townsfolk, the class bodies as travelling adventurers), then an origin of the same type and a fitting name, so their chatter matches their look.
- ExteriorWorld has six villagers: three at posts (the guard at the bridge, the merchant at a stall, the old woman by the well) and three walking loops; the player overhears the Villager's Voice (three registers, gentle dial) in speech bubbles.
- Failsafe Test 16 added; the suite is at 305/305.

**Story 25.15: the Cat (done, 2026-09-25; Raphael: "Cat ! <3", "Petting cat is important").**
- The Cat (G11): charcoal grey with white socks, chest and muzzle and pale green eyes, on her own small rig with four clips (asleep curled up, sitting, walking, and being petted).
- MainTavern: asleep in a wicker basket with a red cushion (B20) beside the hearth, 2.4 m from where the fire is tended.
- ExteriorWorld: a short baked stroll by the stall tent and the barrel, sitting a while at each stop.
- Pettable (decision F0, amending FR-112): beside her the prompt reads "Press E - Pet the cat"; usually she pushes her head into your hand and purrs ("prrr…"), sometimes she only says "mrrp."; then she sits a moment and goes back to sleep, or back to her stroll. Still no name, no autoload, no story entry.
- One E never does two things: beside the hearth the player can stand in both her zone and the fire's, so she yields E and her prompt to any other prompt zone, a waiting patron in range, an open mission screen, a pause or Game Over (found in code review).
- Failsafe Test 17 added (with a physics check that she yields); the suite is at 343/343.

**Story 25.10: Den Fa, the Architect (done, 2026-09-25).**
- Den Fa (G9) on his own rig: taller than the whole chibi cast (2.91 m to the ear tips; Raphael: "make him taller than all the chibi cast"), sylphlike, bat ears, four ivory bone wings folded like a cloak, a deep teal-blue Mages-Guild coat and a featureless mirror mask. Ear, mask and wing bones are ready for Story 26.11.
- At the demo start he sits on the hearth's bench and stays there; his head turns to the room so the mask catches the camera. MainTavern's first reflection probes make the mask reflect the hall and the fire.
- "Press E - Talk to Den Fa": a placeholder line in a speech bubble (`den_fa_lines.json`), replaced on 2026-10-03 by Story 10.2's dialogue box and `data/dialogue/den_fa.dialogue`; since Story 10.3 his conversation follows his state (Early, Mid at Known, Late at Trusted reputation). Walk to the bar, point at the pillar and return to the seat are ready for Epic 10's beats (they close an open conversation first).
- One E owner: beside the hearth the fire, the cat and Den Fa sit within 2.5 m, so the prompt UI now gives E and the prompt to the nearest zone (and to a waiting patron first); the tavern keeps one prompt manager.
- Failsafe Test 18 added; the suite is at 377/377.

**Story 25.13: the Bartender and the Quest Dealer (done, 2026-09-26; Raphael: the burly barkeep, and the Quest Dealer a woman after his silver-haired elf reference; "Available right away in the demo. But then have to unlock in the real game").**
- The Bartender (G12): the Barbarian body as a burly bald barkeep with a grey beard, an apron and a belt cloth. He works inside the round bar: wipes at the serve points the camera sees, pours at the taps, sets a tankard on the counter at the serve point nearest a patron, restocks at the kegs when the beer runs out, and shuffles (Walk_Bar) inside the ring. Barks (placeholders) when a patron sits in front of him.
- The Quest Dealer (G13): a silver-haired elf woman in a plum coat with a quill, seated at the guild desk. She writes; she turns to the player at the desk front; she briefs, with a bark, while the Recruitment screen is open. Several Quest Dealer looks are planned (16.2); this is the demo's.
- Both walk in through the front door when hired and out when fired (`GuildBus.staff_hired` / `staff_fired`; fired on the way in they turn back, hired on the way out they return): the door now takes a hold from walkers without a body (`hold_open` / `release_hold`), and she pulls the desk stool out to sit and puts it back when she leaves.
- In the demo profile both are there from day 1; in the full game they stay away until hired (Epic 16). The player's E is unchanged: the staff are cosmetic until 16.3/16.4, and no beer or gold moves.
- Failsafe Test 19 added; the suite is at 446/446.

**Story 25.30: the anime character pipeline and the Quest Dealer (in review, 2026-09-27; the first of the anime cast, `sprint-change-proposal-2026-09-26.md`; Raphael on the approved anime test: "It looks way better than the kaykit style !").**
- The pipeline (route AN): versioned Blender scripts in `tools/blender/anime/` (its README lists the chain) build one shared base, `<art>/blender/anime_base.blend`, from the untouched KayKit kit. The KayKit skeleton keeps all 41 joints; only its rest pose is stretched, to about 3.5 heads. The legs are 0.08 m shorter and the torso 0.10 m longer than in the approved test (the rebalance Raphael saw at T0), so a seated body has room above the desk: the base's seated shoulders are 1.085–1.091 m above the root (the target is ≥ 1.05, the desk top + 0.20). A neutral `Base_Body` (4,872 tris, never exported) is the reference body for the foot report, the sit re-fit and the seated-room report.
- All 76 KayKit clips come along: the hips and root keys are scaled by the leg ratio 1.8675; the three Sit_Chair clips are re-fitted to the game's 0.44 m seats (seated hips at 0.450, feet planted flat; KayKit's own seated feet dangle 0.23 m); the foot report over the 73 non-sit clips corrects foot contact (Walking_A 0.089 → 0.011 m, Running_A 0.133 → 0.000), and no clip is over 0.03 m afterwards.
- The Quest Dealer (G13) rebuilt on the base as the anime silver-haired elf: long platinum hair, elf ears, the gold circlet with its red gem, big teal eyes painted on the face, the plum coat with gold trim, the quill. One skinned `Dealer_Body` (2 surfaces: face and palette) plus the quill on her right hand: 9,459 tris (budget 10,000), top 2.138 m, 79 clips (the 76 + Walk_Bar, Write and Brief). A new file, `g13_quest_dealer_anime.glb`; the 25.13 KayKit `g13_quest_dealer.glb` stays on disk as her fallback body.
- The look is set at load: `scripts/game/anime_look.gd` gives her the two-tone toon shading (one shared copy per material; the imported materials are never edited) and the shared `anime_outline.tres` draws the ink. Outline weight 0.011 (the approved test's; recommended at Stage D, pending Raphael's OK). The Bartender stays KayKit, with his imported materials, until 25.31.
- Her numbers come from data: `staff.json` › `silver_elf` names the anime body, the g13 fallback, `look: "anime"` and a `body` block (hip_back 0.397, stool_pull 0.45, bubble_seated 1.94, hall_speed 1.51 and bar_speed 0.75 m/s, and the rest), used only when her own body loads; the fallback keeps the script constants. The approach point at the desk is unchanged. She clears the desk in every clip (0 hits), and her hair, skirt and cuffs don't clip through her.
- Stage D shots all kept against the six character criteria (Raphael's verdict on the Stage D sheet, and the outline weight, pending; his verdict closes Stage D): MainTavern at zoom 12 and 8 (seated and writing, fire and re-hire through the door, AVAILABLE, BRIEFING with its bark), a portrait framing, and the zones walk. The crowd check at 24 bodies: 193 draw calls, 0.350 ms GPU and 0.368 ms CPU on an RTX 3080 (the pass is ≤ 8.3 ms); the hall budget is 200 draw calls.
- Noted for later: the tavern's old `CoinStackMedium` prop sits on the desk where she writes (deferred); under some light angles faces fall in the toon's dark band (for 25.17/25.31).
- Failsafe Test 19 extended (106 → 118 checks: per-role GLB rules, the anime look on the live body, import settings, the sit re-fit, the g13 fallback case); the suite is at 502/502.
- Commits on `epic-25-pipeline` (not pushed): `33be8b3` (the pipeline scripts), `1793434` (the GLB, imports, outline and staff.json), `ae9b4b5` (the look helper, `_body()`, Test 19), `7029a76` (the slimmer quill, Stage D), `82fc2a5` (the docs: 08 character spec, 09, 04, 02).
- Open for Raphael: the torso/leg balance (N2-B used by default) and the outline weight (0.011 kept; 0.018 shown). Next: its code review.

**Story 25.17: the cast's dialogue portraits (done 2026-10-03, after its code review; P9, demo subset).**
- Talk to Den Fa and the box now shows his face: his portrait, rendered in the engine, replaces the drawn plate. The Quest Dealer and the Bartender have theirs too; the Elder and the Bard keep their plates until their bodies exist (25.11, 25.12).
- A portrait studio makes them, so a re-made body gets a new portrait with one command: `Godot --path . res://scenes/dev/PortraitStudio.tscn -- ids=den_fa,quest_dealer,bartender` (a windowed run; it writes `assets/characters/portraits/npc/<id>.png` and quits by itself). What to render lives in `data/dialogue/speakers.json` › `portrait_source` (the body or the staff variant, the pose, the camera); the Quest Dealer follows staff.json's `silver_elf`.
- The look is the game's: the tavern's ambient, the ink-outline edge pass, the anime toon look on her. One framing rule for all (a bust, the eyes 43% from the top, a 3/4 view turned toward the box's text), a warm backdrop, the key light in front of the face so her face sits in the toon's light band. Den Fa's mask is a dark mirror with a warm sweep and a glint, featureless; his ear tips are cropped at the top so his mask is as big as the others' faces.
- Two portrait-scale changes: the edge shader can draw wider lines (`linePixels`, 1 in the game, 4 in the studio) so the ink reads at the box's 160 px, and the box's portrait slot now draws with mipmaps (the project default, nearest, would sparkle).
- Failsafe Test 22 added (the portraits, their imports and data, the box resolving the PNGs, the studio a dev scene); Test 20's plate checks moved to a speaker still missing its portrait; the suite is at 668/668.
- Stage D: `<art>/shots/portraits/25-17_sheet.png` (the three at 512 and at 160) and the box in MainTavern with Den Fa's and the Quest Dealer's portraits. Raphael's verdict on the sheet (2026-10-03): "Good as they are", the faces turned toward the text (the viewer's right); Stage D closed. Re-render the Bartender after 25.31 and Den Fa after 25.32.
- Code review patches (2026-10-03): the studio checks the whole request before it writes anything (unknown or repeated ids, an empty or relative `out=`, a bad source, clip, bone or portrait path); `portrait_source` types are checked and a `look` next to a `staff_variant` is refused; the Bartender's source is his staff variant `bartender/barkeep` (the same body: his portrait re-renders byte-identical); the save guard follows `autosave_interval_seconds` with a budget per speaker, and a watchdog thread kills a run that hangs. Test 20's plate checks use stand-in speakers; Test 22 grew (the request checks, the guard, the shader's users scanned); the suite is at 687/687.


**Story 25.23: light and mood, day phases (in review, 2026-10-04; pulled forward by R-4, between 25.31 S1 and S2).**
- The hall's light is data now: a mood (today, moody_a, moody_b) and a day phase (morning, day, dusk, evening, late night, dawn) in `game_config.json`, applied by `scripts/game/tavern_lighting.gd`. "today" is the scene as it was (a shot of it matches the old hall pixel for pixel); the game ships on "today" until Raphael picks.
- The moody moods take the sun off the hall (it still draws the ink, unchanged) and light it with warm pools: the hearth (now with a hard shadow), the torches, the thin candle, the board's sconces, the bar and the desk. A warm pool over the round bar keeps faces readable there.
- Phases follow the loop: evening when you open the bedroom, late night as you sleep, morning on the new day, day after the briefing (`GameBus.day_phase_changed`). Windows carry the phase's colour (light cards; volumetric fog didn't work under the orthographic camera).
- The fireplace finally has its glowing floor rune (V5), shown while the fire owns E.
- Dev keys in debug builds: F6 mood, F7 phase, F8 the cast's shading preset. LookDev follows the configured mood.
- The hall budget re-measured under the new lights: 0.49 ms at 24 bodies; new budgets VISIBLE 200 and SHADOW 100 (08 §1).
- Failsafe Test 25 added; Tests 10, 11, 22, 23 extended (766 pass, the known POT check aside). Stage D sheets D1 (mood), D2 (shading, ink width, face normals) and D3 (phases, fire, glows, rune, windows, portraits, budget) in `<art>/shots/25-23/`, waiting for Raphael's picks.

**Story 25.31: the realistic human cast (in review, 2026-10-04; re-planned realistic by `sprint-change-proposal-2026-10-04.md`, R-1…R-9; 25.28's class reskins folded in).**
- Every human the demo shows is now a realistic body: the player, the Bartender, the Quest Dealer, the six townsfolk (farmer, local, traveller, guard, merchant, old woman; patrons in the hall and villagers in the town) and the six class bodies (Fighter, Rogue, Mage, Healer, Barbarian, Ranger; the adventurer patrons and `classes.json`). No stock KayKit body is visible any more; the KayKit and earlier custom bodies stay on disk as fallbacks (and LookDev's Knight). Den Fa and the Cat are 25.32's.
- Route RL (`tools/blender/realistic/`, on route AN's generic chain): two bases on the KayKit skeleton, REAL-1 (men, 1.86 m) and REAL-2 (women, 1.70 m), the 76 KayKit clips retargeted, the sits re-fitted to 0.45 m chairs, one arm pass. Each body: ≤ 10,000 tris (6,522–9,530), 2 surfaces, a head projected from Raphael's picked concept sheet and baked seamless, a painted body atlas; empty-handed (R-9: carried items are hidden props, worn gear shows; the Healer's crystal glows as a prop).
- The game reads every body from data with a fallback and `look: "realistic"`: `data/characters/player.json` (new; `player.gd` no longer hard-wires the Rogue), `staff.json`, `townsfolk.json`, `classes.json`. Clip playback rates come from measured ground speeds, so the gameplay speeds stayed and no feet skate. The Bartender's bar numbers and the dealer's desk numbers are body blocks; old saves re-pick a realistic body (AH-7); the hooded Rogue retired (AH-6).
- The bar stools went up to bar height (seat 0.72) with a foot ring and a footrest (R-5); patrons are lifted onto them.
- Budgets with the full cast (08 §1): the hall 196 VISIBLE draws at 24 bodies (≤ 200), 0.49 ms; the first town budget, VISIBLE 200 / SHADOW 500 at 24 bodies under the 4-split sun, 0.78 ms (≤ 8.3 ms); the cast's textures 120 MiB.
- Failsafe Tests 12, 15, 16, 19, 22 updated, Test 24 added (the player); the suite is at 905 pass (the known POT check aside, Raphael's uncommitted project.godot).
- Stage D sheets in `<art>/shots/staff/real/`: `25-31_s1_sheet.png` (the player, the Bartender, the Quest Dealer), `_s2_sheet.png` (the stools and the townsfolk), `_s3_sheet.png` (the classes), waiting for Raphael's verdicts (and his calls: the dealer's desk height, the stool's footrest, the props). Docs rewritten for route RL: 08 §1 (the character spec; AN kept as an appendix for the fallback dealer), 09 §0/§5, 04, 02, the READMEs.

**Story 25.32: Den Fa and the Cat, redesigned (in progress, 2026-10-04; R-3 realistic, R-8 no wings).**
- Den Fa (slice D, Stage D verdict pending): `assets/characters/custom/g9_den_fa_real.glb` from his pick without the bone wings: his own 25.10 rig minus the 12 wing bones (30 `d_` bones; rest and six clips proved identical), a realistic body on route RL's helpers (a worn #26587e Mages-Guild coat, gloves, knee-high boots, the dark skull, the bat ears to 2.91 m, the mirror mask shell), 6,020 tris, 2 surfaces, 1 texture. `DenFa.tscn` look "realistic"; `anime_look.gd` keeps his mask as imported (`KEEP_AS_IMPORTED`). Seat, wood store, self-clip and world checks in `tools/blender/realistic/den_fa/` (each proved on a bad pose). His portrait re-rendered. 3 draw calls in the hall (the old body 9). The old GLB stays on disk (one-line rollback).
- The Cat (slice C): her concept job `C_G11_the_cat` is in `tools/n8n/asset_prompts.json` for Raphael to run; her build waits for the pick.
- Failsafe Test 18 rewritten for the new body (30 bones, no wings; RL rules; KEEP_AS_IMPORTED; one seat source; the door rule); the suite is at 913 pass (the known POT check aside). Sheet: `<art>/shots/den_fa/25-32_denfa_sheet.png`.
---

## Installed Plugins

| Plugin | Required By | Status |
|--------|-------------|--------|
| dialogue_manager (nathanhoad) | Epic 8, 9, 10 | ✅ Installed & enabled |
| asset_placer | Dev tool | ✅ Installed & enabled |
| LimboAI (limbonaut) | Epic 16 (Onibi/Staff FSM) | ✅ 1.6.0 GDExtension, loads via `.godot/extension_list.cfg` (a GDExtension needs no `editor_plugins` entry); no game code uses it yet (checked in Story 25.13) |
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
15. Walk a dressed tavern hall (Epic 25): the Hourglass Pillar, the hearth (its fire follows the fireplace state), the round bar where patrons sit on stools, the guild desk and the mission board (one notice per open contract)
16. Pet the Cat in her basket by the hearth (or on her stroll outside); talk to Den Fa by the fire (his first contact in the dialogue box, Story 10.2; as the guild's reputation grows, his Mid and Late conversations, Story 10.3; a DRAFT script)
17. Watch the Bartender work the round bar and the anime Quest Dealer write and brief at the desk (cosmetic until Epic 16; both present from day 1 in the demo profile)
18. Walk out to the tavern's hill, down the path and over the bridge into the village, with six villagers and their barks; patrons and villagers wear the townsfolk kit
19. Hire from six classes (Fighter, Rogue, Mage, Healer, Barbarian, Ranger)

---

## Blocking Gaps & Next Development

**Epic 1 groundwork is 100% complete** — the old pre-flight checklist that lived here (AdventurerStatus enum, 6 EventBuses, config spine, `schema_version`, `codex.dat` skeleton, MinigameInterface, ZonePromptUI de-autoload) is all done and verified (27/27 failsafe GREEN). The one item never actually done — **install GdUnit4** — turned out to be unnecessary; the failsafe suite is a standalone headless script.

**Current blockers / rework (2026-07-11):**
1. **Load / Continue rework** (Epic 11) — Raphael reports load isn't behaving; needs a debugging pass. Blocks world-to-disk save (Epic 6) and Continue polish (Epic 2.1).
2. **World Map dispatch rework** (Epic 6) — only 3 random missions shown; not the desired system; post-30-day group missions not surfaced.
3. ~~**Guilo Tarot portraits**~~ — **no longer a demo blocker (2026-09-24):** the demo ships class silhouettes inside the Tarot card frame (Story 25.22); commissioned art swaps in later via data, zero code change. Story 4.2 is unparked.
4. **Class list — DECIDED 2026-09-24 (supersedes the 2026-08-18 reconcile to the GDD's 4):** demo ships 6 classes — Fighter, Rogue, Mage, Healer, Barbarian, Ranger. Story 25.9 writes that list into `classes.json`, `game_config.json`, `class_colors.json`, `flavor_lines.json` and builds the missing Healer (`Cleric.glb`) + Ranger models.
5. **Duplicate recruit generator** in `DataManager` — consolidate with the active GameManager path.

**Current plan (2026-10-03):** `_bmad-output/planning-artifacts/demo-roadmap-2026-10-03.md` (BMAD workspace) supersedes the list below: Phase A closes the review queue, Phase B is the dialogue box (10.2, 10.3), then a scope correct-course, the realistic cast (25.31, 25.32; 25.23 between S1 and S2) and the demo systems critical path (save/load, dispatch, hire UI, staff, the Bard, Codex, memorial, legacy, audio, tutorial). Of the 2026-07-11 blockers above, the load rework got its fixes on 2026-07-12 and 2026-08-18 (11.2 still open: the world isn't saved to disk), and the dispatch rework is Story 6.5.

**Highest-value next work for the Kickstarter demo (2026-07-11 list, kept for history; Epic 8 items and the basic Codex viewer are done):**
- **Codex / Memorial viewer** (Epics 18/19) — cemetery data now writes to `codex.dat` (Story 7.1) but has no in-game viewer; the Dragon Eye Book / memorial wall makes those deaths visible & meaningful.
- **Epic 6 completion** — the map rework, save world to disk, Latest News feed.
- **Epic 8** — bump patrons to 5, add the eavesdropping trigger, wire Dialogue Manager ambient lines.
- **Epic 5 (Tutorial)** — the Reveal gate (5.3) is now unblocked (Epic 7 done); still waits on Epic 6 for the send-quest gate (5.5).
