# Eternal Guild — Epic Progress Tracker
Updated: 2026-11-07 (Epic 10: Story 10.1 built, in review: the illustrated story panels; a new run's hall opens on "The Inheritance", three pictures; the King's court panel plays in the demo's ending) · 2026-11-04 (Epic 25: Story 25.35 the kit town, slice 1: CC0 Quaternius kits, rough-baked houses, smithy, pottery, watermill, fountain, a street grid and a kit forest) · 2026-11-03 (Epic 25: Story 25.33 built, in review: the look, the hall ("this place has history") and the exterior (Octopath); sprint-change-proposal-2026-11-03) · 2026-11-01 (Epic 3: Story 3.7 built, in review: the day clock, 6:00-2:00 in real time (6 minutes a demo day), the phases, the patrons by the hour, sleep from 20:00 and the 2:00 nod-off, inside and outside) · 2026-11-01 (Epic 18: Stories 18.1-18.5 done after their code review: an open is not a read (the opening page counts after 3 s), the book scales to a 1366 x 768 window, an artefact's fallen finder matched by hire day, a run counted at its first save, the tome on a taller stand) · 2026-11-01 (Epic 10: Story 10.7 done after its code review: he also comes in the evening, seeks the player once, a day jump still ends; the hall's E zones (bar, board, desk, bed) now obey the one E owner) · 2026-11-01 (Epic 18: Stories 18.1-18.5 built, in review: the Codex as the Dragon Eye Book, four adventurers readable, the book on the trunk in the hall) · 2026-11-01 (Epic 10: Story 10.7 built, in review: the demo's ending, the King's messenger) · 2026-11-01 (Epic 16: Stories 16.1-16.5 done after their code review: K-7's 150-gold staff unlock, K-10 the morning reveal always on waking, K-12 the debt stays with the role, Space serves once) · 2026-10-31 (Epic 16: Stories 16.1-16.5 built, in review: the staff records and wages, the Staff section at the Bar, the Bartender serving and the Quest Dealer's morning round on LimboAI) · 2026-10-03 (Story 10.3 built, in review: Den Fa's Early/Mid/Late states; Story 10.2 done after its code review: the dialogue box, Den Fa first; progress snapshot refreshed; BMAD `sprint-status.yaml` created and seeded from this file; demo roadmap written; Epic 25 through Story 25.30) · 2026-09-24 (Epics 25–26 added — Demo Art Pipeline & Full Cast; Epic 16 demo-Partial; Story 4.2 unparked; 6-class list decided) · 2026-08-20 (mission-count display cap fixed + animation-hang regression fixed + duplicate recruit names fixed + roster portrait clipping partially fixed, on top of 2026-08-18's Codex/Memorial viewer + Latest News feed + reputation effects + rumour-driven missions + save-overwrite fix + class-list reconciliation + patron FSM granularity + real patron animations + loot & equipment). Earlier epics last verified 2026-06-21 — re-verify against source before relying on them.

Cross-references `epics.md` against working code in `shiningsun/`.

## Snapshot (2026-10-03)
**Story totals (BMAD `sprint-status.yaml`):** 171 stories in 26 epics — 52 done, 10 in review, 14 in progress, 95 backlog.
**Done:** Epic 1 · Epic 3 · Epic 7 · Epic 8 · Epic 18 (2026-11-01, the Codex as the Dragon Eye Book).
**In progress:** Epic 2 (3/4) · Epic 4 (3/5) · Epic 6 (4/6) · Epic 11 (2/4) · Epic 12 (4/5) · Epic 13 (4/4 marked done; 13.2/13.3's ACs unmet) · Epic 14 (5/6) · Epic 16 (16.1-16.5 done 2026-11-01; Garden Manager and Onibi post-demo) · Epic 17 (deck data) · Epic 19 (fallen-hero data + list) · **Epic 25 (4/32 done, 10 in review, 25.1 in progress)**.
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
**Eternal layer:** deaths write to `codex.dat` cemetery (Story 7.1) and are viewable in-game: since 2026-11-01 in the Codex, the Dragon Eye Book (Epic 18), as its Fallen Heroes chapter (the 2026-08-18 list inside the book until Story 19.4's memorial). Artifact-tier loot (Epic 12) now feeds the same eternal file.
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
- [x] Continue → loads the save and resumes in the saved scene at the saved spot (Story 11.2, 2026-10-31: `SaveSystem.resume_scene()`; a broken save falls back to a backup, else a message)
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
- [x] Save & Exit: saves, and only after a confirmed write returns to the main menu; a failed save keeps you in the game with a message (Story 11.3, 2026-10-31)
- [x] Load: validates save exists, loads, and goes to the saved scene (Story 11.2, 2026-10-31; it used to reload the current scene)
- [x] The pause menu outside too (Esc in ExteriorWorld; Story 11.3)
- [x] Pausing: in the hall the menu freezes the hall's SubViewport (main_tavern.gd `toggle_pause_menu()`, the tree keeps running); outside it pauses the tree (`get_tree().paused`)
- [x] `process_mode = PROCESS_MODE_ALWAYS` (works while paused)

---

## Epic 3: The Living Tavern — Core Day Loop
**Status: reopened 2026-11-01 — Story 3.7 (the day clock, Raphael's K-14…K-19) built, in review; Stories 3.1-3.6 done (earlier: ✅ ~100% — firewood/beer authority + HUD notifications DONE 2026-07-05; 3.4 coin-payment animation + SFX DONE 2026-07-11. Fireplace re-spec'd to continuous decay + additive stoking; minigame polished (target marker, hearth theme, exit-orphan fix).).**

- [x] **Day cycle** — `advance_day()` processes all daily events in sequence
- [x] **Patron spawn** — PatronSpawner with timer-based spawn, up to 3 concurrent (configurable)
- [x] **Beer economy** — buy pints (1g each), sell to patrons (6g + comfort tip)
- [x] **Fireplace/Comfort** — fuel affects patron tips via `calculate_patron_tip()`. Comfort tiers: Cozy/Warm/Chilly/Freezing
- [x] **Firewood system** — purchase bundles, stoke fire (+25% fuel per bundle), max storage cap
- [x] **Single firewood drain authority** — `set_fireplace_fuel()` on GameManager is the single write point; `fireplace_zone.gd` manages burn state machine (DORMANT→BURNING_HIGH→BURNING_LOW→DYING)
- [x] **Morning briefing** — `MorningBriefing.tscn` shows sequential mission reports
- [x] **Daily processing chain**: recovery → availability status → beer consumption → mission returns → operations → tax check → recruit refresh → mission refresh
- [x] **Beer shortage consequences** — escalating: Day 1 = -25% mission penalty, Day 2 = 50% departure chance, Day 3+ = guaranteed departures
- [x] **Soft-lock detection** (FR-6) — the guild falls only with no way back: no one alive, no applicant the gold can hire (`hire_block_reason`) and no way to earn at the bar (no beer, less gold than `beer_pint_price`), or the whole deck dealt; under `soft_lock_gold_below` (8) it warns (Story 13.4 + review P2)
- [x] **"The Guild Falls"** — the game-over screen (Story 13.4; the old GameOverScreen never showed its text)
- [x] **HUD notifications** — `NotificationManager` autoload (2026-07-05): non-blocking top-center banners for low gold/beer/comfort, edge-triggered + cooldown + max-2, config thresholds in `game_config.json`. Verified headless.
- [x] **Coin-payment reward** (Story 3.4 juice, 2026-07-11) — `scripts/fx/coin_reward.gd` procedural 3-coin burst on patron payment + `SfxManager` autoload (pooled SFX on the SFX bus, `coins.mp3` / `cointinkle.wav`)
- [x] **Fireplace continuous decay + additive stoking** (2026-07-11) — re-spec'd from stepped to continuous drain; stoking adds onto current fuel (no reset); config-driven rates. Minigame polished: glowing target marker at the optimal spot, warm hearth theme, debug strip; exit-to-menu orphan bug fixed
- [x] **Story 3.7 — the day clock (built 2026-11-01, in review).** Raphael's K-14…K-19 (2026-11-01): a real-time day from 6:00 to 2:00 that drives the day phases. One demo day is 6 real minutes of running clock (18 s an in-game hour); the full game's is 10 (30 s).
  - The clock stops under every screen (the hire desk, the World Map, the bar's stock, the bedroom, a conversation, the morning briefing, the pause menu, the fire minigame, the Codex, a card reveal, the fall, the end card, F12), and no patron walks in while it is stopped. Time passes outside too: the clock runs in the hall and in ExteriorWorld (a small corner clock there); it is off in the menus and the new-run map.
  - The phases come from the clock alone: morning 6:00, day 9:00, dusk 17:00 (reached in play for the first time), evening 19:00, late night 23:00. The hall's light follows (a Continue at 18:40 opens on dusk); the old senders (the bedroom opening, the briefing's end, the lighting's 20-second morning hold) are gone.
  - Patrons follow the hours (`patron_phase_rates`): at most 2 in the morning, today's spawner by day (20 s, 5), more at dusk, the busiest evening (10 s, 7), last call at 23:00 (a banner), and at 0:00 the guests not yet served go home unpaid (a banner). Prices are unchanged (K-17).
  - The bedroom's Sleep works from 20:00 ("It's too early to sleep. (from 20:00)" before, DRAFT; firewood can still be bought). At 1:00 a warning banner; at 2:00 the guildmaster nods off where they stand and the bedroom's own night runs (the autosave, the morning). Outside, the screen goes black and they wake in the hall by the bedroom door.
  - The time of day is saved: a Continue resumes at the saved hour; the night's autosave says 6:00; an older save starts at 6:00. The HUD's top bar reads "20:40 · Evening".
  - The tavern's visitors and the King's messenger now walk in during the hall's open hours (day, dusk, evening), so a player back from a walk still meets them; at 23:00 they leave as they did at sleep.
  - F12: the clock's line, jumps forward (9:00 … 1:58), x1 / x10 / x60; the open panel holds the clock.
  - Files: `scripts/game/day_clock.gd` (GameManager's persistent `DayClock`), `scripts/game/day_clock_rules.gd` (pure), `scripts/ui/clock_label.gd`, `data/narrative/day_clock.json` (DRAFT words), `game_config.json` `day_clock` / `day_clock_seconds_per_hour` / `patron_phase_rates`; GameManager (`day_clock_minutes`, saved), GameBus (`day_clock_changed`), the bedroom popup, PatronSpawner, RealisticPatron (`leave_unserved`), TavernLighting, the briefing, the director, the messenger, F12. Failsafe Test 70 (Tests 25, 26, 37, 38 re-pinned).

---

## Epic 4: The Adventurer Roster
**Status: DONE. 4.1 / 4.4 / 4.5 (2026-07-08); 4.2 done 2026-10-31 after its code review (the hire desk: applicants as Tarot cards, class silhouettes in a placeholder frame, pick and confirm; traits real; ids never reused; the pool on Day 1). 4.3 done 2026-10-31 after its code review (each roster entry: the adventurer's Tarot card, card name, trait, wage and drink from the record, a Deployed badge with "returns in N days", "available in N days"). Class list reconciled 2026-08-18. The duplicate-generator consolidation is still open (TECH_DEBT).**

### Story 4.1: Daily Hire Pool Generation — ✅ DONE
- [x] 3–5 recruits/day from config (`hire_pool_min/max`)
- [x] **78-card Tarot deck** (`data/config/tarot_deck.json`) + `DataManager.get_tarot_deck / get_tarot_card / get_all_tarot_ids`
- [x] Enriched record: **unique Tarot card**, experience tier, daily wage, drink preference — all data-driven (MOD-2)
- [x] Unique-card rule: no dupe in pool, none on roster, none re-offered after hire (`hired_tarot_cards`)
- [x] `AdventurerBus.recruitment_pool_changed` emitted; verified (78 = 22 major/56 minor, pool 3–5, 0 dupes)

### Story 4.2: Hire an Adventurer — ✅ DONE (2026-10-31, demo roadmap D3, after its code review; decision D-1: class silhouettes in the card frame)
- [x] `hire_adventurer()` — gold gate, unique ID, adds READY, removes from pool; Tarot card carried onto the roster record
- [x] **One hire authority** — `GameManager.hire_block_reason()` ("No longer available" / "Roster full" / "Not enough gold", in that order) is checked before anything moves: a refused hire changes nothing and emits nothing (a full roster used to spend, then refund); the same applicant can't be hired twice; status forced READY at hire
- [x] **The pool on Day 1** — `GameManager.ensure_hire_pool()` on opening the desk: a day that never had a pool gets one (every New Game's Day 1 used to offer nobody: the pool was only made by `advance_day`)
- [x] **The hire desk** (`scripts/ui/recruitment_popup.gd`, same RecruitmentPopup node) — one column per applicant: a Tarot card (`scenes/ui/TarotCard.tscn`: Major numeral or Minor suit, the card's name, the art in the frame's window), name and class, tier, trait, drink, stats, "N gold to hire · W a day"; Hire picks, a confirm bar asks ("Hire Nina the Ranger for 24 gold? Wages: 2 gold a day." [Hire] [Not now]); the desk rebuilds in place; "Your guild" with Dismiss below (4.5). Opaque panel. Player text DRAFT
- [x] **The card's look in one data file** — `data/config/tarot_card.json`: frame path (the generated `assets/ui/tarot/placeholder_tarot_frame.png` until Story 25.22; `tools/ui/make_placeholder_tarot_frame.py`), band/window fractions, colours, suits (label, colour, icon path), class silhouettes, silhouette tint (`class` or a colour). A missing frame draws a plain border
- [x] **Card art** — `PortraitSocket.resolve_card_art()`: the Tarot painting at the card's `portrait` path when it exists (commissioned art drops in, no code change), else the class silhouette tinted the class colour, else the class plate. `resolve_texture()` (Reveal, Codex, map tokens) unchanged
- [x] **Class silhouettes** rendered from the six realistic class bodies by `scenes/dev/SilhouetteStudio.tscn` (one command, quits itself in ~4 s; carried weapons shown, R-9 refined): `assets/ui/tarot/silhouettes/<class>.png`
- [x] **Traits are real** — applicants draw one trait from `data/characters/traits.json` (was 8 hard-coded words, only 2 matching); hiring keeps it (`personality` used to be erased); `get_trait_data` ignores case; Experienced's +1 to every stat and Greedy's x1.5 wage act when the applicant is made; `trait_info()` shows it. The mission formula is unchanged; `estimate_success` now sees traits (Brave +10, +25 at danger 3; Experienced +5; Reckless -5)
- [x] **IDs never reused** — `generate_unique_id()` jumps past every id in use or remembered, the codex's fallen heroes included (a fresh session restarted at 1, and `record_fallen_hero` skips an id already in the codex, so a new run's adventurer could die unrecorded)
- [x] Failsafe Test 29 (66 checks); Stage D shots in `eternal_guild_art/shots/demo/4-2/`
- [x] **Code review patches (2026-10-31, 28db8b1..c7847a0)**: a hired-out carried-over pool doesn't refill the same day; traits do what the desk says (Reckless hurt on a success, the party bonus, the trait-named bonus line, Lucky's unused crit_chance dropped); the card's size from tarot_card.json's aspect; the event log and the E prompt step aside while a panel is open (one rule, `ZonePromptUI.modal_open`); the bar's row kept so the desk never grows; the desk follows gold while open; the dealt deck said and in the soft-lock rule; old saves' applicants healed and re-keyed; the codex dedupes a hero by id + name + hire day; six columns on screen. Review shots in `eternal_guild_art/shots/demo/d3-review/`

### Story 4.3: Roster Panel Display — ✅ DONE (2026-10-31, demo roadmap D3, after its code review: the status line never dims, lines clip so the closed panel never peeks, the thumbnail at the data's aspect)
- [x] Panel renders name, class+level, color-coded status, wage; greys non-Ready; refreshes on roster/day change (audit done)
- [x] **Tab-toggle display bug fixed** (2026-07-12) — panel derived open/closed from the animating `position.x` and force-showed on every roster change, so Tab raced the slide and often hid instead of showing ("adventurers not displaying"). Now uses an explicit `is_open` flag + single reused tween; Tab is the sole authority
- [x] **Portrait socket wired** (Story 7.5) — `PortraitSocket.resolve_texture(adventurer)`: Tarot portrait when present, else class portrait, else class-colored silhouette (never blank). *(Since Stories 4.2/4.3 the roster and the hire desk show the card art instead, `resolve_card_art`: never the class paintings, D-1; the Reveal and the Codex keep `resolve_texture`.)*
- [~] **Portrait clipping partially fixed** (2026-08-20) — the panel's slide-in `SHOWN_X` landed exactly `1920 - panel_width`, i.e. flush with the screen's right edge with zero margin, clipping the portrait's right side. Added a 24px margin (`SHOWN_X` 1570→1546). Raphael explicitly deprioritized further precision here — this card layout needs a fuller rework once the roster scales to a full 78-card deck
- [x] **The entry, Story 4.3** — `AdventurerRosterPanel.entry_view()` (pure) + `fill_card()`: the adventurer's Tarot card as a compact thumbnail (`TarotCard.tscn`, the same `PortraitSocket.resolve_card_art` as the hire desk: the class silhouette until a painting exists), name, "Ranger · Level 1 · Brave" (the trait kept since 4.2), the status line, the card's name ("The Chariot"), "2 gold a day · Drinks mead"
- [x] **Deployed**: a badge on the greyed art and "Deployed · returns in N days", N = `GameManager.return_day_for()` − today (the back day the World Map shows; saves from before 6.5 count today + days left). **Resting / Wounded**: "… · available in N days" from `recovery`. Status text DRAFT
- [x] **Wage and drink from the record**: `GameManager.wage_of()` (also what `apply_daily_wages` deducts now: one read); drinks through game_config `drink_labels`. The hard-coded "Daily Cost: 1 gold" is gone
- [x] Failsafe Test 30 (17 checks); Stage D shots in `eternal_guild_art/shots/demo/4-3/`. Not changed: Tab, the slide, the dim of non-Ready cards, the drag source

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
**Status: ~85% — Generation + distance-aware placement work; Latest News feed + rumour-driven missions shipped (2026-08-18); mission-count display cap fixed (2026-08-20); click-to-assign dispatch with the estimated success % and group missions in the demo (Story 6.5, 2026-10-31, done after its code review). Left: Story 6.1 (plugin evaluation) and the deferred items in Story 6.5's file**

- [x] **Hex map generation** — seeded RNG, simplex noise + radial falloff, biomes (sea/grass/forest/mountain)
- [x] **Settlement placement** — configurable count, minimum spacing enforcement
- [x] **World persisted** — `WorldManager.set_generated_world()` stores records; `display_mode` re-renders without regenerating
- [x] **Ruin hex reserved next to the tavern** (Story 6.2 AC) and the **"Unknown Ruins" hover** (Story 6.3 AC). Done 2026-09-24 via Story 25.2: `HexMapGenerator._reserve_ruin()` (seeded, no RNG drift), records gain `is_ruin` / `ruin_discovered`, the D1 Prior Ruins topper is used, and `WorldManager.is_mission_eligible()` keeps missions off it
- [x] **Tavern hex selection** — player picks center (signal `tavern_hex_selected`)
- [x] **Missions assigned to hexes** — `WorldManager.assign_missions_to_hexes()` is now **distance-aware** (2026-07-12): a quest's distance from the tavern scales with `duration_days` (+ a touch of danger), so 1-day errands land near and long/dangerous ones sit far. Tunable via `mission_hexes_per_day` / `mission_distance_spread`
- [x] **Mission dispatch** — `send_on_mission()` / `send_party_on_mission()` with duration tracking; since Story 6.5 the World Map goes through `GameManager.dispatch_adventurers()` (below)
- [x] **Active mission timers** — tick down daily in `process_mission_returns()`
- [x] **Hex lock** — dispatched hex marked `locked` (by GameManager since Story 6.5, not the board), freed on resolution, when the contract also leaves the hex and the day's pool (6.5 review)
- [x] **Mission success formula** (FR-18) — `50% ± 3%/stat ± 2%/exp − 8%/danger`, clamped 10-95% ✅ EXACT MATCH
- [x] **Party missions** — average chance + party_size bonus (5% per extra member); party size = `required_adventurers` since Story 6.5 (Tier 3 needs 3)
- [x] **Mission board UI** — SingleMissionCard + PartyMissionCard scenes
- [x] **World map assets** — coast variants, forest/mountain toppers, decorative props, tavern building
- [x] **Data-driven missions** — `data/missions/mission_types.json` + fallback generation
- [x] **Pre-dispatch panel** (FR-19) — the World Map's dispatch scroll (Story 6.5): name, danger, duration, reward, party size, the stats used, the estimated success %, traits, places, and a token per adventurer; see the Story 6.5 bullets below
- [x] **Latest News feed** (FR-19b, 2026-08-18) — top-left panel on the World Map board drains `WorldManager.overheard_rumours` (Story 8.5), 5 most recent, newest first; placeholder message when empty. `scenes/world/world_map_board.gd`
- [x] **Rumour-driven missions** (2026-08-18) — eavesdropped rumours are no longer pure flavor: each has a `rumour_mission_chance` (default 20%, `game_config.json`) to also spawn a real, dispatch-ready mission via `PatronSpawner._maybe_spawn_rumour_mission()` + `WorldManager.assign_one_mission()` (reuses the same tiered generator and distance-band placement as the daily refresh). Latest News shows a follow-up line when it happens.
- [x] **Mission-count display cap fixed** (2026-08-20) — `DataManager.generate_daily_missions_with_tiers()` used `for i in range(min(count, available_templates.size()))`, so whenever a tier's template pool was smaller than the requested count, the board silently showed fewer missions. Tier 1 (the whole first ~30 days, before the first tax unlocks Tier 2) only has 4 templates total, so the board was hard-capped at 4 regardless of the requested 6. Fixed by cycling the shuffled template pool with wrap-around (`available_templates[i % available_templates.size()]`) so the requested count always generates; `add_mission_variety()` still randomizes each repeat's name/location/client so duplicates don't read as identical. Tier 2/3 (12/19 templates) were already unaffected. Verified headless (Tier 1: 4→6 missions generated and placed on hexes) and live in-game via the World Map board.
- [ ] **Hex Strategy Map plugin evaluation** — not documented
- [ ] **Prototypes, dev only (2026-11-07; not wired into New Game)** — `scenes/dev/MapTable.tscn` (the map on a scroll on the furniture table: it slides under a window, drag / WASD / wheel, 2D hover outline and click panel) and World Gen v2 (`scripts/world/world_gen_v2.gd`, `scripts/world/name_generator.gd`, `data/world/name_bases.json`: world types, ridge ranges, climate, priority-flood rivers on the KayKit river tiles, lakes, invented names in four tongues). Found on the way: `WorldManager._hex_distance` reads the records' offset coords as axial, so most hexes get the wrong mission distance (932 of 1,261 on the current map, off by up to 10).
- [x] **World saved to disk** — since commit f604ec8 (`WorldManager.get_save_data()` / `load_save_data()`, saved as `world_data`: every hex record + the tavern hex; the map redraws the stored records). The Latest News rumours are saved with it since Story 11.2 (2026-10-31). The old "not yet saved" note here was stale.
- **NOTE (Raphael):** ~~randomly placed~~ **fixed 2026-07-12** (now distance-aware — 1-day quests no longer spawn across the map). ~~only ~3-4 missions shown at once~~ **fixed 2026-08-20**. ~~post-30-day group missions aren't displayed~~ **2026-10-31 (Story 6.5)**: group missions only exist from Tier 2, which the first tax (Day 30) unlocks, so a demo never met one; the demo profile now brings one from day 2 (below).

### Story 6.5: Click-to-Assign Dispatch — done (2026-10-31, demo roadmap D2; code review the same day)
- [x] **The dispatch scroll** — a click on a mission marker (or its hex) unfurls a parchment scroll (placeholder art): the mission's name, danger, duration, reward, "Party of N", the stats it uses, the chance line, traits, N places, Send/Close. `scenes/world/world_map_board.gd`
- [x] **Click-to-assign** — a token per adventurer (portrait, name, class, their chance): READY first by chance with "Good fit" marks (`dispatch_strong_fit_min_chance`, 70), the others greyed with their status ("Out, back day 40", "Wounded, 2 days"). A click on a READY token fills a place (again: takes it out); anyone else is refused with the reason. The Tab roster drag still works through the same check (`mission_slot.gd`)
- [x] **The estimated success %** — `GameManager.estimate_success()` is the one formula: the scroll shows it, dispatch stores it, the resolver rolls it (a party's chance was recomputed at resolution and the old panel showed only the first member's)
- [x] **Checked dispatch** — `GameManager.dispatch_adventurers(ids, mission, hex_id)`: only READY roster adventurers, each once, as many as the mission needs, onto a hex that still holds it and isn't taken; a refusal changes nothing and the scroll shows why. A dispatched hex could be dispatched to again before; not any more
- [x] **Deployment Record** — on each `active_missions` entry: `adventurer_ids` (party order; Story 11.2's load relink reads them), `mission_id`, `location_id`, `dispatch_day`, `return_day`, `travel_duration`, `direction`; a `[GameManager] dispatch:` log line
- [x] **Deployed markers** — a taken hex shows a chip ("Gareth +1 · back day 40"), its hover says who is out, its click opens the scroll read-only (also for missions sent before 6.5)
- [x] **Group missions in the demo** — `game_config.json` `demo_party_missions` (`from_day` 2, `per_refresh` 1, `max_tier` 2; 0 = off): in the demo profile each refresh from day 2 carries a party mission. The full profile is unchanged. Party markers carry "×2"; the hover says "Party of 2". `missions_changed` now fires after the missions are placed
- [x] **The map is a clean screen** (review P14) — the board draws on its own CanvasLayer (105) above the hall's GameUI (100: the top bar, the event log, the roster strip), with its own top line ("Day 37 · 782 gold · 3 of 6 ready")
- [x] **Code review (14 patches)** — a resolved contract leaves its hex and the pool (it could be run twice); a stale lock isn't "taken"; no click through a closing scroll and no double-click undoing a pick; tokens name the class; the dispatch line and whole days in the log; the no-template warning; the legacy board's party chance
- [x] **Tests** — failsafe Test 28 (88 checks); suite 1108/0. Stage D on copies of Raphael's save and codex: `eternal_guild_art/shots/demo/6-5/` (6-5_1…6-5_12; the pre-review shots in `before_review/`)
- [ ] Deferred (in Story 6.5's file and deferred-work.md): beer/morale never touch missions; traits never reach the roster (Story 4.2); WorldManager's hex distance; the legacy hidden MissionBoard; stale locks pruned on reset/load; the notice board's template-id match

---

## Epic 7: The End-of-Day Reveal
**Status: ~95% — Stories 7.1–7.6 shipped (the "sacred ritual" reveal + crash-safe persistence). Only the optional "Begin the Day" closing flourish remains.**

- [x] **Morning briefing sequence** — panels shown one at a time, "Report N of M" counter
- [x] **Report contains**: mission name, adventurer name/class, success/fail, alive/injured/dead status
- [x] **Solo + party report types** with different data shapes
- [x] **Mission resolution consequences** — success: +gold, +1 day rest. Failure: injury (2-5 days), possible death
- [x] **A death reads as a death (fixed 2026-10-31, 110e8c3, the D3 review's P0)** — `handle_adventurer_death` never set the status to DEAD, so every report showed the dead as returned and Story 7.3's death pause never ran. It is set first now; Test 29 checks a solo and a party death through the real resolver; Stage D shot `eternal_guild_art/shots/demo/d3-review/p0_1_death_panel_paused.png`
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
**Status: ~40% — Story 10.1 (illustrated story panels) built 2026-11-07, in review; Story 10.2 (the dialogue box, Den Fa first) done 2026-10-03; Story 10.3 (Den Fa's Early/Mid/Late states) built 2026-10-03; Story 10.7 (the demo's ending, the King's messenger) done 2026-11-01 after its code review.**
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
- [x] **Story 10.7 — the demo's ending: the King's messenger (done 2026-11-01, after its code review).** Demo profile only (sprint change 2026-10-31, K-2/K-3). When the guild's reputation reaches 32 after 2 taxes are paid (`profiles.demo.demo_ending`), the next morning a messenger of the King walks in through the front door (an event banner), walks to the guild master and stops beside them (or waits by the door), and E opens his conversation: the King asks for the guild's help. Once he is heard the hall stops, a "to be continued" card shows, then the main menu; the save stays the final day's, so Continue replays it and he comes again.
  - `GameManager.demo_ending` (due -> coming -> waiting -> ended; saved, "ended" written as "waiting"; New Game resets it), `GuildBus.demo_ending_changed`, pure rules in `scripts/game/demo_ending_rules.gd`. His day has no tavern disturbance. Heard: no automatic save after it.
  - The hall: `scripts/game/royal_messenger.gd` (added by `main_tavern.gd`; waits for the briefing, a conversation, a visitor, a pending card reveal or the pause menu), `scripts/npcs/royal_messenger_npc.gd` (a visitor body: the townsfolk guard, a placeholder by one key), `scripts/ui/demo_end_card.gd`. Content: `data/narrative/demo_ending.json`, `data/dialogue/royal_messenger.dialogue` (DRAFT). Story 10.1's court panel has a seam before the card (a no-op until 10.1). F12: the demo ending line, "Demo ending now". Failsafe Test 53 added.
  - Code review patches (2026-11-01): he also walks in during the evening (opening the bedroom turns the hall to evening); he seeks the player once and never into another E zone (he waits by the door then); a day jump while he waits still lets hearing him end the demo; the end clears the banners; "he's back" only after he was in the hall; a court panel that never finishes can't hold the card (60 s); `demo_ending.json` values that don't fit keep their default; a 3 s talk cooldown; new patrons don't wear his body while he's in. The hall's legacy E zones (`zone_interactions.gd`: the bar, the board, the hire desk, the bed) now act only while they own E (`ZonePromptUI.owns_e`), so the nearest zone gets the key.
- [x] **The New Game intro (2026-11-07, placeholder art).** Every new run (the main menu's New Game, the fall screen's New Run) opens on six illustrated slides before the world map: the Priors, the Forgetting, you, the letter, the road, the map that came with it. `GameManager.NEW_RUN_SCENE` is now `scenes/ui/IntroSequence.tscn` (`scripts/ui/intro_sequence.gd`, built in code on a CanvasLayer at 118, 10.1's panel layer); it hands over to the new `GameManager.WORLD_MAP_SCENE` (HexMapTest), loaded on a thread while the slides play.
  - Each slide fades up from black, its art pushes in slowly, its line writes itself out, it holds, then fades. Click / Space / Enter / Right goes on (a press while writing finishes the line); hold Esc or the Skip button leaves at once. A missing or broken JSON goes straight to the map.
  - Content: `data/narrative/intro.json` (every word DRAFT; canon kept: nothing named or explained, no face). Art: placeholders `assets/ui/panels/placeholder_intro_<id>.png` from `tools/ui/make_placeholder_intro.py` (Pillow; the inked art replaces them at the same paths).
  - The hall's arrival (the tavern, the pillar, the stranger) is Story 10.1's opening panel, below. Not yet: sound, a failsafe test of the intro itself.
- [x] **Story 10.1 — illustrated story panels (built 2026-11-07, in review; placeholder art, DRAFT words).** Full-screen illustrated panels for story beats, in the morning briefing's house style: a picture, a title, the words beside it (never baked in) and a Continue button. The hall's world stands still while one is up (DC-11's freeze), every key goes to it, and each panel shows once a run.
  - The demo's beats: a new run's hall opens on "The Inheritance", three pages (the marked tavern, the pillar, the stranger by the fire; skippable, E / Enter / Space / the button turns the page, Esc skips the rest). 10.7's ending now plays "The King Hears of You" between the hall's stop and the end card (a 3 s hard gate, then the button). "The First Death" (after the first briefing that reports a death) ships switched off (`enabled: false`).
  - How: `scripts/narrative/story_panels.gd` (a per-scene director in group `story_panels`, added by `main_tavern.gd`; triggers run_start, day_end, proximity, event; one at a time, only while nothing else owns the screen) and `scripts/ui/story_panel.gd` (the overlay, layer 118). Content: `data/narrative/panels.json` (DRAFT; `pages` added for the opening's three pictures); timings: `game_config.json` `story_panel_hard_gate_seconds` 3.0, `story_panel_input_grace_seconds` 0.3. Once per run through the run's dialogue flags (`panel_<id>`: saved, reset by New Game).
  - Art: placeholders `assets/ui/panels/placeholder_panel_<name>.png` from `tools/ui/make_placeholder_panels.py`; the inked art replaces them at the same paths. 10.7's seam now closes a court panel that never finished (T7b) and no longer errors on a panel that closed itself. Failsafe Test 57 added (48 checks), Test 53's seam checks extended. Not yet: 17.3's card reveal pump line (17.3 isn't built), sound, Story 5.1's discovery panels (proximity content).
- [ ] The other key conversations arrive with their speakers: the Pillar Invitation, Final Missive and Beat 7 (10.1 panels / 10.4), the Bartender's Read and the Quest Dealer's Setup (Epic 16), the Elder (25.11), the Bard (9.1–9.5), the Legendary Wanderer (10.6), the Recruitment Offer (Epic 4's hire UI, 4.2); the Ambient Patron and the Villager's Voice stay bubbles (8.4, 25.14); the Discord has no words (26.11)
- [ ] No Hidden Threshold, no Kingdom Chronicle (the panel system they will use is 10.1's)

---

## Epic 11: Campaign Save & Load
**Status: 100% — 11.1, 11.2, 11.3, 11.4 done (11.2 and 11.3 on 2026-10-31, after their code review). The world map has been saved to disk since commit f604ec8 (`world_data`: every hex record + the tavern hex).**

- [x] **Single-file JSON save** — `user://eternal_guild_save.json` (Story 11.2 decision: the real name stays; the epic's `savegame.dat` is the early name)
- [x] **3-backup rotation** — `create_save_backup()` rotates backup1→2→3 (it only ever kept two until Story 11.3 fixed the loop)
- [x] **Comprehensive state saved**: gold, beer, day, tax_due_day, adventurers (full array), max_adventurers, firewood, fuel, recruits, missions, active_missions, patron_pool, reputation, tier, morale
- [x] **Save metadata**: timestamp, date string, game version, playtime, save type
- [x] **Autosave** — every 5 minutes + at the end of each day's night (since the Story 11.2 review: only in a live run, i.e. after a load or New Game's first save, and after the whole night, not at day_changed)
- [x] **Load with validation** — checks required fields (current_day, gold, beer_stock, adventurers)
- [x] **Restore from backup** method exists
- [x] **Signal re-emission on load** — all UI signals fired to refresh displays
- [x] **Game over save** — the fallen state is saved one last time, then the save and its backups move to `fallen_runs/<stamp>/` (Story 13.4): Continue never resumes a fallen run
- [x] **`schema_version`** — save versioned with migration support
- [x] **`codex.dat`** — eternal cross-run persistence (fallen heroes, achievements, run stats)
- [x] **Atomic writes** — write to `.tmp` then rename
- [x] **Player position + scene saved/restored** (2026-07-12, **confirmed in-game**) — `player_position` / `player_scene` in the save; `PlayerManager` pending-spawn puts the player back where they saved, and Continue routes to the saved scene
- [x] **Patron exact-restore** (2026-07-12, **confirmed in-game**) — each patron's position/state/model/identity serialized (`RealisticPatron.to_save`) and rebuilt by `PatronSpawner.restore_patrons()` on load (day-boundary autosaves have none, since night despawn runs first)
- [x] **New Game state-reset fixed** (2026-07-12) — `reset_game_state()` now also clears `active_missions`, `pending_reports`, `has_pending_briefing`, `tavern_reputation`, `taxes_paid_count`, `tax_grace_days`, `mission_tier_unlocked`; `_start_new_game()` calls it so a New Game no longer inherits the prior session's state.
- [x] **Disk-save overwrite window fixed** (2026-08-18) — New Game now force-saves (`save_type: "new_game_start"`) the moment the tavern loads, via `GameManager.pending_new_game_save` set in `main_menu.gd` and consumed in `main_tavern.gd`'s `_ready()`. Fixes New Game → quit before Day 2 → Continue loading the previous run. Verified with a headless regression script (planted a stale save, ran the real code path, confirmed disk flipped to fresh state).
- **NOTE (Raphael):** Load pass — (a) ~~fireplace fuel loads as 0%~~ **fixed 2026-07-12**; (b) ~~old disk save isn't overwritten until the new game's Day-2 autosave~~ **fixed 2026-08-18**; (c) ~~player + patron positions~~ **DONE 2026-07-12** (player scene+position; patrons rebuilt at exact position/state/model).

### Story 11.2: Full State Load & Resume — DONE (2026-10-31, after its code review)
- [x] **The menu autosave no longer overwrites the run.** The 300 s autosave ran in every scene: in the main menu it saved the menu as the resume scene (Continue reopened the menu), and on a fresh launch it wrote a Day-1 default over the run. It now runs only in a player scene (`SaveSystem.can_autosave()`: the hall, outside).
- [x] **One resume path** — `SaveSystem.resume_scene()` for Continue and the pause menu's Load (Load used to reload the current scene). A missing scene, or one that isn't a player scene (menu, hex map), goes to the tavern's PlayerSpawnPoint with `[SaveSystem] warn: saved scene not found, falling back to default spawn`, and the saved spot is dropped.
- [x] **`load_game()` returns the state it applied** (`{}` on failure); `read_save()` falls back to the newest readable backup; `player_spot(data)` gives `{scene, x, y, z}`; a failed load shows "Couldn't load the save." (DRAFT) instead of doing nothing.
- [x] **Deployed adventurers re-linked on load** — after a load a mission held copies, so its resolution left the roster adventurer On Mission for good (found by the Story 6.5 agent).
- [x] **Morale survives a load** — JSON brought its keys back as Strings, so every adventurer read as neutral after a load.
- [x] **Also saved now:** the tarot cards hired this run (`hired_tarot_cards`, Epic 4.1's never-again rule) and the Latest News rumours (in `world_data`; New Game clears them).
- [x] **Best-effort load** — null or junk values load as defaults instead of aborting the load half-way; a newer schema loads its known fields.
- [x] **Not saved, by decision:** the map seed (the hex records are the world), the morning reports (the reveal is cosmetic), the hall's day phase, scripted NPC positions. `bard_performed_today` waits for Story 9.2.
- [x] **`SaveSystem.save_path`** — the save a session reads and writes; the suite and Stage D runs point it at a copy.
- Failsafe Test 26 (suite 966 / 0); Stage D 25/25 on a copy of the real save (Continue into the hall at the saved spot, out to the village square, save, menu, Continue outside at the same spot with the same values, the missing-scene fallback, the pause menu's Load); shots in `eternal_guild_art/shots/demo/11-2/`.
- Code review patches (2026-10-31): the automatic saves (timer, end of day, game over, the reveal's pre-save) need a live run, so a scene launched straight from the editor can't write its Day 1 over the run; the day's autosave runs after the whole night; a Load in the hall keeps the saved fire; codex.dat follows the redirect (`codex_path`); New Game forgets the last run's pending patrons, scene and spot; re-linking prefers each member's own id and mission days are ints again; a backup fallback is shown as a banner; a save without a world clears the old map. Suite 1088 / 0.

### Story 11.3: Pause Menu Save-First Handler Fix — DONE (2026-10-31, after its code review)
- [x] **Save & Exit saves first** — it returns to the main menu only when the save is written and confirmed; a failed save keeps the menu open, the game paused and the file on disk untouched, with "Save failed — please check disk space". The handler carries the fix comment. The stale `.tscn` `[connection]` blocks were already stripped on 2026-07-05 (f366c76); Test 27 now fails if a scene wires a PauseMenu button again.
- [x] **Confirmed writes** — `_write_file_atomic` checks the tmp file (every byte on disk) before it replaces the save; the backups rotate only after that, and the rotation now keeps three.
- [x] **A pause menu outside** — Esc in ExteriorWorld opens the same menu (built in code, no scene edit) and pauses the game: villagers and the cat stop and start again, the E prompt comes back, Settings/Codex keep Esc first, an open dialogue box keeps Esc.
- [x] **Save no longer freezes the hall** — Save closed the menu with its own toggle and left the hall's world frozen until Esc twice; it now closes through main_tavern's toggle and shows a "Game saved" banner.
- Failsafe Test 27 (suite 988 / 0); Stage D 24/24 + 7/7 on a copy of the real save (Save in the hall, outside pause with villagers / cat / prompt / dialogue box, a failed Save & Exit, Save & Exit + Continue back to the spot); shots in `eternal_guild_art/shots/demo/11-3/`.
- Code review patches (2026-10-31): the swap is undoable (the old save steps aside as `.prev`, the new one moves in or the old one comes back, and only then does it become `.backup1`), so a locked save file no longer loses a backup or leaves a `.tmp`; a NaN in the run fails the save instead of writing an unreadable file (verified in 4.4.1: JSON writes it as bare `nan`); after a crash mid-swap the save is recovered from `.tmp` / `.prev`.

---

## Epic 12: Loot & Adventurer Equipment
**Status: ~75% — built 2026-08-18 per the spec written the same day. Remaining: no UI polish beyond the one reveal-panel line (deliberately — see spec's non-goals).**

- [x] `GameManager.roll_loot()` (`scripts/GameManager.gd:1642`) — was dead code (unit-tested, never called). Now wired into `_resolve_solo_mission()` / `_resolve_party_mission()`, one roll per successful mission.
- [x] **Reward-amount bug fixed** — mission reports used to carry the config reward *range*; `complete_mission()`/`complete_party_mission()` now return the real rolled+paid amount and the report/reveal panel show that instead.
- [x] `data/economy/equipment.json` (11 items) + `data/economy/artifacts.json` (7 relics) — new files. Deliberately unglamorous tone per `01_VISION.md` (no magic-shop language; artifacts carry zero mechanical effect).
- [x] **Equipment tier** (20%) — single `adventurer.equipped_item` slot, flat +1/+2 stat bonus applied once at equip time, silently replaces whatever was equipped before. No inventory system (by design).
- [x] **Artifact tier** (5%) — `SaveSystem.record_artifact_found()`, persists to `codex.dat`'s new `artifacts_found` array, same append-only pattern as `record_fallen_hero()`.
- [x] **Codex "Artifacts Recovered" section** — since Story 18.3 (2026-11-01) the Codex book's Prior Artefacts chapter (`scripts/menus/codex/artefacts_chapter.gd`: who found each relic, a link to a fallen finder); it began as a third section in `codex_menu.gd`.
- [x] **Reveal panel** — one terse `"· found: <name>"` line for equipment/artifact loot only; gold-tier loot stays invisible on purpose (folds into the reward number).
- [ ] Failure-path loot loss (the `equipment_damage`/`equipment_loss` tags already sitting unused in `mission_types.json`) — explicitly deferred, flagged as an open decision for Raphael in the spec.
- **Full spec:** `documentation/design/LOOT_AND_EQUIPMENT_SYSTEM.md` — still the reference for design intent, data schemas, and the open decisions not yet made.

---

## Epic 13: Tax Cycle & Economic Pressure
**Status: ~95% — 13.1 and 13.4 done after their code review (2026-10-31: the tax cycle on EconomyBus, every number in game_config; "The Guild Falls" and New Run). 13.2/13.3: done (pre-BMAD); ACs unmet, see deferred-work › Story 13.1; Raphael to reopen or accept.**

- [x] **30-day tax cycle** — `tax_due_day` starts at 30, advances by `tax_interval_days` (30) on payment
- [x] **Warnings at 7, 3, 1 day** before due (`check_tax_deadline()`; the days are `tax_warning_days`)
- [x] **3-day grace period** — `tax_grace_days` increments daily if unpaid (`tax_grace_period_days`; the due morning counts as the first)
- [x] **Game over when the grace runs out** — `trigger_game_over("bankruptcy", ...)` (the due day + 2 with grace 3)
- [x] **Tax amount** — `tax_base_amount` 1000 + `tax_per_adventurer` 5 × the roster
- [x] **Tier unlock tied to tax payment** — tier 2 unlocks after first tax paid
- [x] **Soft-lock game over** (FR-6) — no way back: no one alive, no applicant the gold can hire (`hire_block_reason`) and no way to earn at the bar (no beer, less gold than `beer_pint_price`), or the whole deck dealt; under `soft_lock_gold_below` (8) it warns (Story 13.4 + review P2)
- [x] **"The Guild Falls"** (Story 13.4) — the reason line by cause, the run's stats, New Run / Return to Main Menu; the fall recorded in codex.dat's `guild_history`
- [x] **EventBus wiring** (Story 13.1) — `EconomyBus.tax_warning`, `tax_demand_triggered`, `tax_paid`, `tax_overdue`
- [ ] Party mode economic expansion design (deferred)

### Story 13.1: Tax Cycle EventBus Verification — DONE (2026-10-31, after its code review)
- [x] **The tax cycle on the bus.** EconomyBus gains `tax_warning(days_left, amount)`, `tax_demand_triggered(amount, due_day)`, `tax_paid(amount)` and `tax_overdue(days_remaining)`; GameManager emits them from `check_tax_deadline()` / `handle_tax_payment()`. The demand goes out once a cycle (the first collection morning), before the payment; `tax_paid` after `spend_gold`'s `gold_changed`; `tax_overdue` on each grace morning; then the bankruptcy fall. Payment stays automatic.
- [x] **Every tax number in game_config.json** (today's values): `tax_due_day` (the first due day), `tax_interval_days`, `tax_base_amount`, `tax_per_adventurer`, `tax_grace_period_days`, `tax_warning_days`, with `_tax_comment`. `GameManager.tax_config_from()` falls back per key with a `[GameManager] fallback:` warning, once a run; no tax literal is left in the two functions. Story 14.6's demo profile can override them.
- [x] **Banners** — NotificationManager shows one per tax event (DRAFT text: "Tax due in 3 days: 1000 gold.", "Tax due tomorrow: …", "Tax paid: …", "Tax overdue. 2 days before the guild is seized.").
- [x] **F12** — the State tab's tax line (due day, days left, amount, grace, paid); "Trigger Tax Event NOW" runs the real morning check (it called a `process_tax_day()` that never existed).
- [x] **Code review (2026-10-31)** — F12's Trigger Tax Event no longer moves an unpayable tax (it said "use Failures › Bankruptcy" and asks before collecting); `current_tax_amount()` read by the F12 line; the warning's wording in `tax_warning_log_line()`.
- Failsafe Test 31 (suite 1211 / 0; 1287 / 0 after the review); Stage D in the hall (warnings, the readout, the paid morning, an overdue morning; re-shot with one adventurer on the roster); shots in `eternal_guild_art/shots/demo/13-1/`.

### Story 13.4: Full Game-Over Surface — DONE (2026-10-31, after its code review)
- [x] **The fall by its cause.** `game_over_triggered(reason)` (GameManager and GameBus) carries the cause key (`bankruptcy`, `soft_lock`; Story 21.3 adds `no_survivors`), not "Tax Bankruptcy: " + a sentence; the sentence stays in the log.
- [x] **Recorded before it shows.** `trigger_game_over` freezes `last_run_summary` (`run_summary()`: days survived, adventurers lost, gold at its peak, survivors, ...) and calls `SaveSystem.end_run()` before it emits: codex.dat's new `guild_history` gets the entry (`record_run_end(entry)`, the totals too), the fallen state is saved one last time, then the save, `.prev`, `.tmp` and every backup move to `<save folder>/fallen_runs/<stamp>/`. Continue never resumes a fallen run; while fallen nothing saves it again (the pause menu, the timer). Only in a live run: a hall launched straight from the editor records nothing.
- [x] **"The Guild Falls"** — `scenes/game_over_screen.gd` builds it on MainTavern's GameOverScreen (scene unchanged): the title, the reason line for the cause, the three stats, New Run and Return to Main Menu (each asks once). It waits for an open morning briefing (the night's deaths land first), then pauses. Every word in `data/reveal/guild_falls.json` (DRAFT). The hall ignores its keys while fallen (no pause menu over the fall); the B test key is gone.
- [x] **Gold at its peak** — `GameManager.gold_peak` (raised by `add_gold`, saved).
- [x] **The soft-lock rule** (review P2, a decision) — `_check_soft_lock()`: no one alive, no applicant the gold can hire (`hire_block_reason`) and no way to earn at the bar (no beer, less gold than `beer_pint_price`), or the whole deck dealt; under `soft_lock_gold_below` (8) it warns; Story 3.6's `[GameManager] warn: soft-lock condition detected on day N`. A tax paid that leaves a few coins and beer no longer ends the run.
- [x] **One way into a new run** — `GameManager.begin_new_run()` + `NEW_RUN_SCENE` (today the world map), used by New Run and the main menu's New Game. Story 5.1's naming screen and Epics 21/22 (The Reading, `LegacyTransition`) hook in there.
- [x] **F12** — "Game Over: Bankruptcy" runs the real tax path (it set an operating cost nothing reads).
- [x] **Code review (2026-10-31)** — the fall holds the hall (the screen joins `blocks_player`, the hall's world is frozen, the exit door and the keys stand down, the log and the top bar hide); a failed archive leaves a `.fallen` tombstone (never resumed; a rename falls back to copy); New Run with a save still in the slot goes by the main menu; the night ends at the fall (no contracts, applicants or "new day"); the fall clears the banners; the buttons wake after the fade, the questions start on Cancel; a loaded `gold_peak` never below the starting gold.
- Failsafe Test 32 (suite 1237 / 0; 1287 / 0 after the review); Stage D: the bankruptcy fall after the morning briefing (re-shot: the screen alone; E at the door and W do nothing), New Run to the world map; the soft-lock fall, Return to Main Menu (Continue off), the Codex; shots in `eternal_guild_art/shots/demo/13-4/`.

---

## Epic 14: Reputation & Tavern Disturbances
**Status: ~80% — Tiers, HUD display and effects (2026-08-18); the demo pacing profile (14.6) and the tavern disturbances (14.4) built 2026-11-01, done after their code review the same day. Left: 14.5 (reputation-gated content), 14.3's animated label, passive decay.**

- [x] `tavern_reputation` integer tracked in GameManager, mutated only via `adjust_reputation(delta, reason)` (single authority; Story 14.6 added the reason)
- [x] The gains are config keys (Story 14.6): `rep_mission_success` 2, `rep_mission_failure` -1, `rep_party_mission_success` 0, `rep_party_mission_failure` -1, `rep_dismiss` -1, `rep_patron_satisfied` 0 in the full game (today's numbers); the demo profile's are faster
- [x] A patron who finishes and pays is a source (`GameManager.patron_satisfied()`, 0 in the full game; +1 in the demo)
- [x] Tier system partially uses reputation (tier 3 requires reputation >= 50)
- [x] **5-tier label** (2026-08-18) — Unknown → Known → Trusted → Respected → Honored, data-driven via `data/config/game_config.json` `reputation_tiers`, `GameManager.get_reputation_tier()`
- [x] **Reputation effects** (2026-08-18) — tier's `tip_bonus` applied in `calculate_patron_tip()`; `recruit_stat_bonus` applied to rolled stats in `generate_fallback_recruits()`
- [x] **HUD display** (2026-08-18) — "Reputation: N (Tier)" in the tavern top stats bar, code-built, updates live via the new `reputation_changed` signal (bridged to `GuildBus`, previously an empty stub)
- [x] **Reputation events on GuildBus** (Story 14.6): `reputation_adjusted(delta, new_value, reason)`, `reputation_tier_changed(old_tier, new_tier)` and `reputation_tier_reached(tier)` (the first time the run reaches a tier: the run's peak, saved); a banner on that ("The guild is now Known.", DRAFT), once a run
- [x] **Tavern disturbances** (Story 14.4): the thief (guilty or innocent), the rowdy drunk, the grieving family, the rival guild's man
- [ ] **No reputation decay over time** (only moves on its sources — no passive drift)
- [ ] 14.3's animated tier label (a plain label and the rise banner today)

### Epic 14 progress

**Story 14.6: the demo pacing profile (built 2026-11-01, done after the code review the same day; demo roadmap D6).**
- **Profiles.** `DataManager.get_config(key)` returns `game_config.json` `profiles.<profile>.<key>` when the active profile's block has it, else the top-level value: the top level is the full game. A block replaces a value whole; `profile`, `profiles` and the keys tools read straight from the file can't be overridden. `DataManager.get_profile()` / `is_demo()`.
- **The demo's values** (`profiles.demo`, DRAFT): tiers 0/10/24/40/70 (Known, Trusted, Respected, Honored), a mission success +3, a group success +3, a satisfied patron +1; 40 gold and 20 beer to start (K-1); a 20-gold tax every 3 days from Day 3, warned 2 days and 1 day before (DP-12); `demo_ending` on at reputation 32 after 2 taxes (Story 10.7's keys, K-9); nobody on the staff at start and the staff hireable once the guild has held 150 gold (`staff_unlock`, K-7, amended from 300 on 2026-11-01; `staff_hire_block_for` locks by it since Epic 16's review: "Joins at 150 gold."); deaths twice as likely (`death_chance_multiplier` 2, K-8).
- **The welcome text** in the hall's event log states the active tax (it said "every 30 days, 1000 gold").
- Test 37; Tests 19, 20, 26, 31, 32, 33, 35, 36 pin the full profile or K9's staff seed where they check the full game's numbers. Suite 1422 / 0 (from 1379). Stage D in the hall: the profile live, a real served patron's +1, the tier banners, Den Fa's mid_enter and late_enter at the demo tiers, and an 8-day driven demo session (two taxes paid on Days 3 and 6, Respected on Day 4, deaths on Day 5); shots in `eternal_guild_art/shots/demo/14-6/`.
- **Code review (2026-11-01, P5 P6 P9-P12 P14-P16).** **The profile is per run** (K-13, provisional): the save records it; Continue / Load keep the run's (an older save without one is the full game), New Game takes the file's (`DataManager.run_profile`). The tier banner shows once a run (`reputation_tier_reached`, an event banner). The run's first tax is warned on Day 1 (`check_tax_warning`, run by the hall's first load after New Game). On a grace day the welcome text says "overdue since Day N". The dismissal's log line reads `rep_dismiss`. Tests: Den Fa on the demo tiers, the profile warning once a session, load and New Game silent. Suite 1523 / 0. Stage D: a copy of Raphael's day-37 save through the menu's Continue stays the full game under the shipped demo (1020 gold due Day 60, no demo schedule); New Game is the demo with "Tax due in 2 days: 20 gold." on Day 1 (`14-6_r1_old_save_stays_full.png`, `14-6_r2_day1_tax_warning.png`).

**Story 14.4: tavern disturbances (built 2026-11-01, done after the code review the same day; demo roadmap D6).**
- **The roll** (GameManager, each morning after the tax): yesterday's event settled (shown and left alone: its `ignored` outcome; never shown: dropped), then today's: a `disturbance_schedule` entry first (the demo's guilty thief on Day 2), else below `disturbance_reputation_below`, out of `disturbance_cooldown_days`, on a `disturbance_daily_chance` roll; a type and a truth by weight. Saved (`pending_disturbance`, `last_disturbance_day`).
- **The hall** (`scripts/game/disturbance_director.gd`): in the day phase the visitor (`scripts/npcs/disturbance_npc.gd`, a placeholder townsfolk body) stands at his type's spot with a banner; E opens his conversation (`data/dialogue/disturbances.dialogue`, DRAFT); the reply's `bridge.choose(id)` decides it: `GameManager.resolve_disturbance()` applies the outcome from `data/disturbances/disturbances.json`, a banner says what happened, he walks out. Walking away leaves him; sleep sends him off and the morning applies "ignored". `GuildBus.disturbance_resolved`.
- **The dialogue runner** takes an optional bridge; the bridge gains `choose(id)` / `choice` and the disturbance's type and subject.
- F12: the State tab's `disturbance` line and Economy › "Queue a thief now". Test 38; suite 1460 / 0. Stage D: the Day-2 thief through real E presses (thrown out, +2), an innocent thrown out (-2), a drunk walked away from and ignored into the next morning, the mourner and the rival's man at their spots; shots in `eternal_guild_art/shots/demo/14-4/`.
- **Code review (2026-11-01, P1-P4, P7, P8, P13, P14, P16).** HIGH: on a morning with no reports the visitor never came (the lighting turned to day without telling the bus): the hold's end is on GameBus now and the director reads the lighting's phase live. The spots re-picked from the hall: 2.3 m from every E zone (Den Fa's walk too) and 4.55 m from every patron seat (the thief by the front wall, the drunk in the back-west corner by the hearth, the mourner just inside the door, the rival's man near the stairs west of the notice board). The ignored outcome is logged that morning with its cost and shown as a banner once the day begins. The mourner names this run's fallen (`fallen_this_run`); the schedule and F12 honour `min_deaths`. A visitor whose event is gone (a debug path, another day) walks out. The paid replies show only when the guild can pay (`bridge.can_afford`). The talk zone is 1.2 m; a visitor not out in time fades over 1 s. The banners are event banners. Suite 1523 / 0. Stage D: a real New Game, patrons in the hall, two real sleeps: the quiet morning's hold ended and the Day-2 thief appeared at his new spot (19.9 s after waking), a real E talked to him with a patron waiting (nobody served), the next morning logged "He slipped out. A patron's purse went with him. (-10 gold)" and showed it after the hold; the other three at their spots, the mourner naming this run's dead (`14-4_r1`…`14-4_r7`).

---

## Epics 15–26

| Epic | Status | Notes |
|------|--------|-------|
| 15: Farmland & Drinks | 0% | No farmland, no drink types beyond beer |
| 16: Staff & Automation | ~70% (the demo's 16.1-16.5 done 2026-11-01) | The Bartender serves stool patrons and restocks; the Quest Dealer briefs and sends a Minor Arcana each morning; saved staff records, wages, strikes and leaving; a placeholder Staff section at the Bar. Garden Manager and Onibi are post-demo (Epic 26). Details below. |
| 17: Tarot Evolution | ~5% | 78-card deck data + `DataManager` Tarot API exist and recruits carry a unique card (Epic 4.1); no evolution/leveling mechanic yet · Story 18.2 (2026-11-01) marked the four starting Major Arcana (`unlock_trigger: "start"`) and gave them their Codex page text (DRAFT) |
| 18: Codex | 5 of 5 done (2026-11-01, after the code review; demo roadmap D8) | The Dragon Eye Book: a two-page book (placeholder art, swap from `codex_book.json`) with Tarot Cards (78 slots, four readable Major Arcana), Fallen Heroes, Prior Artefacts (who found them) and Guild History (each run's end); the book on the trunk by the hearth, Den Fa's line once a run. See "Epic 18 progress" below |
| 19: Memorial & Cemetery | ~30% | **Basic viewer shipped (2026-08-18)** — same `codex_menu.gd` renders `codex.dat.fallen_heroes` (name/class/Tarot card/hire+death day/missions completed) with `PortraitSocket` portraits, verified live against real save data. Not yet a dedicated memorial wall / cemetery scene — this is a list, not the eventual set-piece · since 2026-11-01 the list is the Codex book's Fallen Heroes chapter (Story 18.1; Story 19.4 replaces it) |
| 20: Guild Fame | 0% | No fame system |
| 21: The Reading | 0% | No run-end ceremony |
| 22: Legacy Transition | 0% | No LegacyTransition class |
| 23: City Hub Buildings | 0% | No church, apothecary, alley |
| 24: Audio & Ambient | ~15% | `SfxManager` autoload (pooled SFX on the SFX bus) + coin-payment SFX live; Master/Music/SFX bus layout from Epic 2.2. No music beds / ambient loops yet |
| 25: Demo Art Pipeline & Demo Cast | 19 of 34 built (15 done, 3 in review, 25.1 in progress; 2026-11-03: + 25.33 the look, in review; 25.34 the hourglass clock, backlog; 2026-11-04: + 25.35 the kit town, in progress) | Done after review: 25.2–25.10 (the gate asset, the tavern hall, the exterior, the class roster, Den Fa), 25.13 (the Bartender and the Quest Dealer), 25.14 (villager and patron body kit), 25.15 (the Cat), 25.17 (the cast's dialogue portraits), 25.29 (exterior ground, forest and village) and 25.30 (the anime character pipeline and the Quest Dealer); in review on branch `epic-25-pipeline`: 25.23 (light and mood) and 25.31 (the realistic human cast: all 15 human bodies on route RL, Raphael's Stage D verdicts pending); 25.1 (pipeline readiness) and 25.32 (Den Fa realistic, no wings; the Cat waits for her concept pick) in progress; see "Epic 25 progress" below. **Added 2026-09-24** (BMAD `sprint-change-proposal-2026-09-24.md`); **the anime cast added 2026-09-26** (`sprint-change-proposal-2026-09-26.md`). 32 stories — Tier 1 (25.1–25.25 + 25.30–25.32) is demo-critical: pipeline + gate asset, the tavern hall (shell, pillar, hearth, bar, desk/board, exterior), the demo cast (Healer/Ranger + one class list, Den Fa, the Elder, the Bard, Bartender + Quest Dealer, villager/patron body kit, the Cat, animations, dialogue portraits), memorial + cemetery, Codex lectern, UI skin, icons, card frames, lighting, soundscape, menu art, and the anime cast (25.30 the anime character pipeline + the Quest Dealer, 25.31 the human cast, 25.32 Den Fa and the Cat; sprint-change-proposal-2026-09-26). Tier 2 (25.26–25.27) is polish; stock art ships if it isn't done. 25.28 (the inked class reskins) is folded into 25.31. Already `in game`: D1 Prior Ruins, B1, B2, B6 and A1 (see `09_ASSET_INVENTORY.md`); 25.19 (the Codex lectern) has a placeholder in game since Story 18.5 (2026-11-01: a tome on a book stand on the trunk by the hearth, materials `placeholder_codex_*`, swap at `codex_book.json` `lectern_body`) | |
| 26: Full Cast | 0% | **Added 2026-09-24.** Post-demo: Onibi, Garden Manager, the King (portrait/seal/panels) + emissaries, rival musician, Legendary Wanderer, rival guilds, disturbance cast, guards/merchants/clergy, the peoples of the world, mountain elders, character states, Demon King panel art, commissioned NPC portraits |

### Epic 16 progress

**Stories 16.1-16.5: the Bartender and the Quest Dealer actually work (built 2026-10-31; done 2026-11-01 after the code review; demo roadmap D5).**
- **16.1 Staff records.** GameManager keeps one saved record per staff role (`staff`: staff_id `role/variant`, name, daily wage, hired, on strike, owed, missed days), seeded from the profile (the demo's starting staff: K9 had both; since K-7, 2026-11-01, the demo starts with none and hires them once the guild has held 150 gold, Story 14.6; an unpaid debt stays with the role and re-hiring pays it, K-12). `hire_staff` / `dismiss_staff` are the one way in and out and emit `GuildBus.staff_hired` / `staff_fired` (the bodies walk in and out); new `GuildBus.staff_strike_changed`. `is_staff_hired` reads the record; `is_staff_working` = hired and not on strike. F12: a staff readout and Hire / Dismiss / Pay / Strike buttons. Test 33 part A.
- **16.5 Wages.** Each morning, right after the adventurers' wages (before the tax), each hired member is paid in full or goes on strike owing the wage (`EconomyBus.staff_wage_paid` / `staff_wage_unpaid`, a banner); a striker isn't paid automatically; after 3 unpaid mornings in a row they leave (a warning banner the day before). The back wage is paid from the Staff section or F12. Wages (3 and 4 gold, placeholders) and the 3 days live in `game_config.json` `staff_wages`, so Story 14.6's demo profile can override them. Test 33 part B.
- **16.2 Staff section (placeholder hire UX).** E at the Bar: Tavern Management lists the staff: Working (Dismiss asks first), On strike with "Pay N gold", a candidate with "Hire (N gold)" (the first day's wage; disabled with "Not enough gold"), or locked ("Joins at Trusted" / "Respected" in the full profile). `scripts/ui/staff_panel.gd`; every rule is GameManager's. Test 34.
- **16.3 The Bartender serves.** His brain (`scripts/game/bartender_ai.gd` on `staff_ai.gd`, a LimboAI `LimboHSM` built in code, MANUAL, updated by his own tick): IDLE (wiping) -> SERVING (a patron on a bar stool who has waited 3 s: the pour at the taps, the hand-over at the counter through the patron's own `serve_patron()`, the player's `consume_drink` path) -> RESTOCKING (at the kegs while the beer is out; then the same patron). No orders on strike or after a fall; table patrons stay the player's. A serve takes about 13 s. The hall turns automation on (`main_tavern.gd`); tests and LookDev keep 25.13's cosmetic body. Test 35 (with a LimboAI probe).
- **16.4 The Quest Dealer at work.** Her brain (`quest_dealer_ai.gd`): BRIEFING while a screen is up (the hire desk, the World Map, the morning reports) or her round runs, AVAILABLE with the player at the desk, else writing. Her morning round (FR-65): once a day, a few seconds after the reports, she sends the READY Minor Arcana with the best odds (at least 70%, the World Map's Good fit) on an open solo tier-1 contract through `dispatch_adventurers`, and says so; Major Arcana and party contracts stay the player's. The morning reports always open on waking, whatever the staff (K-10, 2026-11-01); she briefs while they show; a strike cancels that morning's round. Test 36.
- Suite 1379 / 0 (from 1287). Stage D in the hall for each story; shots in `eternal_guild_art/shots/demo/16-2/`, `16-3/`, `16-4/`, `16-5/`.
- **Code review (2026-11-01, three reviewers; 9c180ce..3e62265; suite 1485 / 0):** Space beside a waiting patron serves once like E (it also sold a second pint for instant gold); K-7 at 150 gold wired into the hire rule (the Staff rows read "Joins at 150 gold" until then); K-12 the debt stays with the role; K-10 the desk path removed (the reveal always opens on waking; a Load drops unshown reports; a held key no longer skips one); an old save no longer gets a round on load; a strike cancels the round; K-11 her bar stays 70%; tax and staff banners are never pushed out by a low-resource warning, and the log carries the same sentence; no staff brain without LimboAI (a fresh clone); a double-click can't skip Dismiss's question; Tests 31-37 extended. Stage D re-shot: `16-2_6_locked_150_gold`, `16-2_7_unlocked_at_150`, `16-3_2_serve`, `16-4_1_round_brief`, `16-4_3_reports_briefing`, `16-4_4_reveal_no_staff`.
- Open for Raphael: the staff economy against the demo's 40 starting gold (Story 14.6); the strike / leave chain; the hire panel not opening by itself at the desk (the E rule kept); her bubble's readability over the bar (the UI pass); every line DRAFT. See deferred-work.md › Epic 16.

### Epic 18 progress

**Stories 18.1-18.5: the Codex as the Dragon Eye Book (built 2026-11-01, done after its code review the same day; demo roadmap D8; art parked: Story 25.19).**
- **18.1 The book.** `scripts/menus/codex_menu.gd` (the same path the main and pause menus open) is a two-page book: a placeholder spread drawn in code (leather cover, parchment pages, gutter, teal eye clasp; `data/config/codex_book.json` `spread` swaps in 25.19/25.20's art), four ribbon tabs from the same file (Tarot Cards, Fallen Heroes, Prior Artefacts, Guild History) that rebuild both pages in place, Close and Esc. It is modal (every key is the book's; the arrows turn pages), in groups `blocks_player` and `codex_open` (for Story 3.7's day clock), reads only codex.dat and the deck, and writes nothing. `pause_world` freezes the world while it is open (the hall's new `set_world_frozen`, split out of the pause menu's toggle; elsewhere a tree pause). Chapters live in `scripts/menus/codex/` (`codex_ui.gd`: the config, words and look). The Fallen Heroes chapter keeps the live list (Story 19.4 replaces it).
- **18.2 The Tarot chapter.** All 78 cards: the Major Arcana, then the four suits. Unlocked cards show their face (Story 4.2's card; the class silhouette until a painting exists) and name; locked ones only the card back (a placeholder drawn in code; `tarot_card.json` `back`). The right page: the card, its name, "Major Arcana · VII", archetype, a personality note, the secret meaning, how it was revealed; Previous / Next. **Four adventurers readable from the first run:** The Magician, The Chariot, Strength and The Star (not The Hermit: Den Fa's card, 03_STORY_BIBLE) (`tarot_deck.json` `unlock_trigger: "start"` + their DRAFT page text). Unlocked = those + codex `tarot_unlocked` (Epic 17 writes it). It opens on the first unlocked card. Opening the book logs `[Codex] open: <from>`; a page the reader chose (a click, a page turn, a tab, a link), or the opening page once it has stayed 3 s (`read_dwell_seconds`), logs `[Codex] read: <chapter> <id>` (the playtests' "read a Codex entry"; since the code review).
- **18.3 Prior Artefacts.** A find now records who found it and the run (`record_artifact_found(id, finder)`; the loot roll passes its recipient). The chapter lists every relic oldest first; a page says "Found by Nina, Healer" ("Finder unknown" for older finds) and, when that finder later fell, "See The Fallen" opens them in the Fallen Heroes chapter.
- **18.4 Guild History.** The all-time totals and one entry per run's end (Story 13.4's `guild_history`), newest first: the guild ("The guild of run 2" until Story 5.1), date and cause, days survived, adventurers lost, gold at its peak, Fame when there is any, the heir or "Guild Wiped".
- **18.5 The book in the hall.** `scenes/game/CodexLectern.tscn`: a placeholder open book on the trunk by the hearth with a slowly pulsing teal eye; "Press E - Read the Codex" (one E owner). The first read in a run plays Den Fa's line (`den_fa.dialogue` `codex_first_open`, DRAFT), then the book opens; after that it opens at once. `GameManager.codex_first_opened` is saved with the run.
- Tests 44-48; suite 1644 / 0 (from 1566). Stage D on copies of the save and codex: the main menu's book (the four Major Arcana pages by real clicks, the locked backs, Prior Artefacts with a fallen finder and the link to The Fallen, Guild History, Esc), then the hall (the book on the trunk, E: Den Fa's line, then the book with the hall frozen, Esc, E: the book at once, one E owner beside the fire, the pause menu's book); shots in `eternal_guild_art/shots/demo/18-1/` … `18-5/`.
- Open for Raphael: the four starting cards and every line are DRAFT; the book's placeholder look and the trunk spot wait for Story 25.19 / 25.20. See deferred-work.md › Epic 18.
- **After the code review (2026-11-01; three reviewers, P1-P13 applied, d297efd..72cfb99 + docs; all five done):** an open is not a read (`[Codex] open: <from>`; the opening page counts after 3 s; a clicked fallen hero counts); the spread keeps its 1600 x 900 layout scaled to fit the window (at 1366 x 768 and 1280 x 720 nothing crosses the gutter; the Tarot grid wraps to its page); an artefact's fallen finder must match the hire day too, and a finder's id is never handed out again; codex `runs_started` counts a run at its first save (a find's run number); Fallen Heroes newest by real time across runs; the pause menu's book is modal for Tab / F12; no book over a fall or a paused tree; the tome on a 0.32 m stand (above a reader's head from the hall camera), pages tilted 6°, its rest on the lid in the world frame. Suite 1665 / 0. Stage D (`stageD_rv2`, 15 / 15): `18-1/18-1_6_book_1366x768.png`, `18-1_7_book_1280x720.png`, the reading-spot shot `18-5/18-5_1_book_in_hall.png`; a real E where the book's and the fire's zones overlap acts once: at z -10.6 the book opens and the fire does nothing, at z -10.3 the fire opens its minigame and the book stays shut.

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
- Dev keys in debug builds: 1 mood, 2 phase, 3 the cast's shading preset, 4 the edge pass on/off (F6–F8 clashed with the editor's run/pause/stop). LookDev follows the configured mood.
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
- Den Fa (slice D, Stage D verdict pending): `assets/characters/custom/g9_den_fa_real_v6.glb` (v6 2026-10-04 after Raphael's v5 verdict "The shoulders are not broad enough. The legs are too slim.": broader shoulders (span 0.74 m, v5 0.67; capped by the chimney face when he sits) and chunkier legs, the same rig and clips; v5 stays on disk) from his pick without the bone wings: his own 25.10 rig minus the 12 wing bones (30 `d_` bones; rest and six clips proved identical), a realistic body on route RL's helpers (a worn #26587e Mages-Guild coat, gloves, knee-high boots, the dark skull, the bat ears to 2.91 m, the mirror mask shell), 6,076 tris, 2 surfaces, 1 texture. `DenFa.tscn` look "realistic"; `anime_look.gd` keeps his mask as imported (`KEEP_AS_IMPORTED`). Seat, wood store, self-clip and world checks in `tools/blender/realistic/den_fa/` (each proved on a bad pose). His portrait re-rendered. 3 draw calls in the hall (the old body 9). The old GLB stays on disk (one-line rollback).
- The Cat (slice C): her concept job `C_G11_the_cat` is in `tools/n8n/asset_prompts.json` for Raphael to run; her build waits for the pick.
- Failsafe Test 18 rewritten for the new body (30 bones, no wings; RL rules; KEEP_AS_IMPORTED; one seat source; the door rule); the suite is at 913 pass (the known POT check aside). Sheet: `<art>/shots/den_fa/25-32_denfa_sheet.png`.

**Story 25.33: the look, the hall and the exterior (in review, 2026-11-03; sprint-change-proposal-2026-11-03.md, H-1…H-8).**
- The hall's ink pass can be switched off again: `edge_pass.gd` knows both edge shader files (the hall's quad draws Raphael's `edge_detection-old.gdshader`); Test 25 checks both scenes.
- Hall look, pass 1 (`scripts/game/hall_look.gd`; `hall_floor`, `hall_wall`, `hall_banner` shaders): dark worn planks with worn lanes, a tiled ring and compass rose at the bar, ruin stone under plaster and timber with soot, soot-dark beams, 8 placeholder lanterns, 2 faded banners, the `history` mood. Raphael: "oh that was sexy".
- Pass 2 (`scripts/game/hall_dressing.gd`; `hall_paper`, `hall_portrait`, `hall_root` shaders): the memorial placeholder, a beast skull over the hearth, the tankard ring, candles, plants and the bell on the counter, old notices round the board, four portraits with the last frame empty, roots with glowing runes on the pillar, dust.
- The exterior (`scripts/world/exterior_look.gd`; `ext_grass`, `ext_cobble`, `ext_water`, `ext_building` shaders): cobbles, muted grass, dark water, the village windows lit by phase, haze and a little valley mist, braziers, lamp posts, leaves, following the day clock.
- Switches: game_config `hall_look`, `exterior_look` (true when absent); dev key 5 in both scenes, key 2 outside (the next phase). The scenes are untouched: everything goes on at load.
- The world map (H-9): KayKit's hex shapes reskinned toward the same look (`scripts/world/hex_look.gd`, `hex_reskin.gdshader`; config `hex_look`, key 5 on the map), every land and sea piece, with beaches, shallows and foam drawn from each map's land and sea (a coast hex built as a grass tile over its hidden KayKit coast tile); follows every re-roll. The mountains stand 1.5× taller with craggy rock and snow on their high ledges.
- Code review done 2026-11-03 (28 patches applied; the look off = mood today). Open: Raphael's verdicts on pass 2 and the exterior, the `history` mood's readability, the beast skull's light. Suite 1770 pass / 0 fail on the committed tests. Sheets in `<art>/shots/look/`.

**Story 25.35: the kit town, slice 1 (in progress, 2026-11-04; decisions T-1…T-9 in the GDD decision log).**
- Two CC0 Quaternius kits (village + nature) replace KayKit outside: `assets/environment/village_kit/` (12 house variants, smithy, pottery, watermill, fountain), `nature_kit/` (22 trees, bushes, rocks), one shared `kit_textures/`; licences beside them.
- Every building is rough-baked in Blender (`tools/blender/village_kit/`, README): sagging ridges, bowed walls, roof chimneys; the watermill's wheel is its own node, turned by `scripts/world/water_wheel.gd`.
- `tools/exterior/gen_town.py` (+ `exterior_terrain.py`, Story 25.29's terrain, now versioned) lays out the town: a street grid off the plaza, houses facing the streets, the smithy, pottery, watermill and fountain, a kit forest; writes ExteriorWorld.tscn and the street ribbons (`custom/a6_town_streets.gltf`). The windmill and the KayKit village are gone; the farmer walks the east street.
- `exterior_look.gd` `apply_kit`: the kit's own materials tinted and toon-shaded, roofs coloured per building (`kit_roof.gdshader`), kit windows glowing by phase; key 5 shows the raw kit.
- Tests 9/16/17 check kit buildings by their footprints; Test 72 covers the town. Next slices: the airship port, the town gate, market tents; walled farmland, a town hall.
---

## Installed Plugins

| Plugin | Required By | Status |
|--------|-------------|--------|
| dialogue_manager (nathanhoad) | Epic 8, 9, 10 | ✅ Installed & enabled |
| asset_placer | Dev tool | ✅ Installed & enabled |
| LimboAI (limbonaut) | Epic 16 (Onibi/Staff FSM) | ✅ 1.6.0 GDExtension, loads via `.godot/extension_list.cfg` (no `editor_plugins` entry needed); used by the staff brains since Stories 16.3/16.4, only through `scripts/game/staff_ai.gd` (Test 35 probes the API) |
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
11. Pay taxes (the full game: every 30 days; the demo: 20 gold every 3 days from Day 3, Story 14.6), with warnings and a grace period, or the guild falls: "The Guild Falls" shows how long it lasted, then New Run or the main menu
11b. Deal with a tavern disturbance (Story 14.4): a stranger in the hall (a thief, or not), a drunk, a mourner at the door, a rival guild's man; talk to them and choose
11c. Reach the demo's end (Story 10.7, demo profile): once the guild's reputation reaches 32 after 2 taxes are paid, the next morning the King's messenger walks in and asks for the guild's help; then "to be continued" and the main menu (Continue replays the final day)
12. Save/Load/Continue from main menu
13. Pause → Save & Exit → Continue later
14. Walk between tavern interior and exterior world (player only — NPCs don't cross scenes yet)
15. Walk a dressed tavern hall (Epic 25): the Hourglass Pillar, the hearth (its fire follows the fireplace state), the round bar where patrons sit on stools, the guild desk and the mission board (one notice per open contract)
16. Pet the Cat in her basket by the hearth (or on her stroll outside); talk to Den Fa by the fire (his first contact in the dialogue box, Story 10.2; as the guild's reputation grows, his Mid and Late conversations, Story 10.3; a DRAFT script)
17. Watch the Bartender serve the bar's stool patrons by himself (and restock when the beer runs out) and the Quest Dealer send a Minor Arcana on a contract each morning; hire, dismiss and pay them back from the Staff section at the Bar; unpaid, they strike, then leave (in the demo profile hireable once the guild has held 150 gold, K-7: "Joins at 150 gold." until then)
18. Walk out to the tavern's hill, down the path and over the bridge into the village, with six villagers and their barks; patrons and villagers wear the townsfolk kit
19. Hire from six classes (Fighter, Rogue, Mage, Healer, Barbarian, Ranger)

---

## Blocking Gaps & Next Development

**Epic 1 groundwork is 100% complete** — the old pre-flight checklist that lived here (AdventurerStatus enum, 6 EventBuses, config spine, `schema_version`, `codex.dat` skeleton, MinigameInterface, ZonePromptUI de-autoload) is all done and verified (27/27 failsafe GREEN). The one item never actually done — **install GdUnit4** — turned out to be unnecessary; the failsafe suite is a standalone headless script.

**Current blockers / rework (2026-07-11):**
1. ~~**Load / Continue rework** (Epic 11)~~ — **done:** fixes 2026-07-12 and 2026-08-18, the world on disk since f604ec8, and Story 11.2 (2026-10-31: one resume path, deployed adventurers and morale restored, no menu autosave).
2. **World Map dispatch rework** (Epic 6) — only 3 random missions shown; not the desired system; post-30-day group missions not surfaced.
3. ~~**Guilo Tarot portraits**~~ — **no longer a demo blocker (2026-09-24):** the demo ships class silhouettes inside the Tarot card frame (Story 25.22); commissioned art swaps in later via data, zero code change. Story 4.2 is unparked.
4. **Class list — DECIDED 2026-09-24 (supersedes the 2026-08-18 reconcile to the GDD's 4):** demo ships 6 classes — Fighter, Rogue, Mage, Healer, Barbarian, Ranger. Story 25.9 writes that list into `classes.json`, `game_config.json`, `class_colors.json`, `flavor_lines.json` and builds the missing Healer (`Cleric.glb`) + Ranger models.
5. **Duplicate recruit generator** in `DataManager` — consolidate with the active GameManager path.

**Current plan (2026-10-03):** `_bmad-output/planning-artifacts/demo-roadmap-2026-10-03.md` (BMAD workspace) supersedes the list below: Phase A closes the review queue, Phase B is the dialogue box (10.2, 10.3), then a scope correct-course, the realistic cast (25.31, 25.32; 25.23 between S1 and S2) and the demo systems critical path (save/load, dispatch, hire UI, staff, the Bard, Codex, memorial, legacy, audio, tutorial). Of the 2026-07-11 blockers above, the load rework got its fixes on 2026-07-12 and 2026-08-18 (the world was already on disk; Story 11.2 closed the rest on 2026-10-31), and the dispatch rework is Story 6.5.

**Highest-value next work for the Kickstarter demo (2026-07-11 list, kept for history; Epic 8 items and the basic Codex viewer are done):**
- **Codex / Memorial viewer** (Epics 18/19) — cemetery data now writes to `codex.dat` (Story 7.1) but has no in-game viewer; the Dragon Eye Book / memorial wall makes those deaths visible & meaningful.
- **Epic 6 completion** — the map rework, save world to disk, Latest News feed.
- **Epic 8** — bump patrons to 5, add the eavesdropping trigger, wire Dialogue Manager ambient lines.
- **Epic 5 (Tutorial)** — the Reveal gate (5.3) is now unblocked (Epic 7 done); still waits on Epic 6 for the send-quest gate (5.5).
