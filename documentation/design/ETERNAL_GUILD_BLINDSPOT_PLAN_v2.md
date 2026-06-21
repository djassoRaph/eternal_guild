# Eternal Guild — Blind Spot Resolution Plan v2

**Original:** May 31, 2026
**Updated:** June 1, 2026
**Purpose:** Living task list tracking design gaps, bugs, and depth layers.
**Status:** T0–T2 complete. T3 remaining. Ready for play-test before continuing.

---

## How to Use This Document

Each task is self-contained. Before starting ANY task:

1. **Ask Raphael for the current version of every file you'll modify.** Do not generate from memory.
2. **Read the file in full before writing code.** The project uses signal-based singletons — breaking a signal chain cascades.
3. **Do not refactor unrelated code.** Touch only what the task describes.
4. **Test criteria are listed per task.** Confirm with Raphael before moving on.

Architecture rules to respect everywhere:
- GameManager is the single source of truth for game state.
- UI reacts to signals, never writes state directly.
- All content data lives in JSON files under `res://data/`.
- CanvasLayer for UI, not scene root.
- `queue_free()` for popups, not `hide()`.
- Engine is Godot 4.4. GDScript.

---

## TIER 0 — DATA-LOSS BUGS ✅ COMPLETE

### T0-1: Save System Missing Progression Data ✅
`get_save_data()` and `load_save_data()` now persist:
- `total_missions_completed`
- `tavern_reputation`
- `taxes_paid_count`
- `mission_tier_unlocked`
- `active_missions`
- `next_adventurer_id` (added with T0-3)
- `tax_grace_days` (added with T2-2)

### T0-2: GameManager / DataManager Progression Desync ✅
Duplicate progression variables removed from `DataManager.gd`:
- `total_missions_completed`, `tavern_reputation`, `taxes_paid_count`, `mission_tier_unlocked`, `tier_requirements`

All references now point to GameManager. DataManager owns only JSON loading and character generation.

### T0-3: Adventurer ID Collision Risk ✅
Replaced `randi() % 10000 + 1000` with a persistent counter:
- `var next_adventurer_id: int = 1` in GameManager
- `generate_unique_id()` increments and returns the counter
- `next_adventurer_id` saved and loaded correctly
- `generate_recruit_id()` now delegates to `generate_unique_id()`

Note: `DataManager.generate_unique_id()` still returns a String (`"CHAR_..."`) for patron conversion characters — separate system, left alone intentionally.

---

## TIER 1 — CORE DECISIONS MADE MEANINGFUL ✅ COMPLETE

### T1-1: Mission Duration ✅
Already implemented before this audit. `duration_days` from JSON is respected.
- `send_on_mission()` sets `adventurer.status = "On Mission"` and creates an `active_missions` entry with `days_remaining`
- `process_mission_returns()` ticks down daily, resolves at 0, stores results in `pending_reports`
- Morning briefing shows results next day

### T1-2: Stats Affect Mission Outcomes ✅
Already implemented before this audit. `calculate_mission_success_chance()` in GameManager:
- Base 50%
- Stat matching via `success_factors` array (+3% per point for STR/DEX/INT, +2% for END)
- Experience bonus (+2% per mission completed)
- Danger penalty (-8% per danger level)
- Clamped 10–95%

### T1-3: Adventurer Dismissal System ✅
`dismiss_adventurer()` added to GameManager:
- Blocked if adventurer status is "On Mission"
- Costs 5g flat severance (logs warning if broke)
- Deducts 1 reputation
- Emits `adventurer_roster_changed`

`recruitment_popup.gd` redesigned as a full guild management screen:
- Section 1: Current roster with stats, status, and Dismiss button (disabled for on-mission adventurers)
- Section 2: Available applicants with Hire button
- Both in a single ScrollContainer

---

## TIER 2 — PLAYER EXPERIENCE GAPS ✅ COMPLETE

### T2-1: Pre-Dispatch Information Display ✅
Dispatch confirm panel added to `mission_board.gd`:
- Shows mission name, duration, danger (skull icons), reward range
- Success chance with color coding (green ≥70%, yellow 50–69%, red <50%)
- Lists `success_factors` with adventurer's stat values
- Personality trait displayed with readable effect description
- Send / Cancel buttons
- Implemented as a CanvasLayer (layer 10) with CenterContainer — renders centered on screen above all other UI
- Party version shows average success chance, all member names, relevant stats

### T2-2: Tax Grace Period ✅
`handle_tax_payment()` and `check_tax_deadline()` rewritten:
- Warnings at 7, 3, and 1 days before tax due (shows actual gold amount needed)
- On missed payment: 3-day grace period with daily countdown messages
- Game over only fires on day 3 of grace period
- Successful payment resets `tax_grace_days = 0`
- `tax_grace_days` saved and loaded

### T2-3: Soft-Lock Safety Net ✅
Added to end of `advance_day()`:
- Triggers graceful game over if: `adventurers.size() == 0 AND gold < 8 AND daily_recruits.size() == 0`
- Runs after `generate_daily_recruits()` so fresh recruits prevent false trigger
- Threshold of 8g = below cheapest possible hiring cost

### T2-4: Trait System Integration ✅
`get_trait_data(personality)` helper added to GameManager — looks up from `DataManager.character_traits`.

Traits wired into:
- **Success chance** (`calculate_mission_success_chance`): `mission_bonus` applied as flat %, `danger_resistance` bonus on danger ≥3 missions
- **Injury** (`_resolve_solo_mission`): `injury_chance` increases probability of injured flag on failure
- **Reward** (`complete_mission`): `reward_bonus` multiplies gold earned on success, logs "🍀 luck paid off"
- **Wages** (`process_daily_operations`): `cost_multiplier` increases daily wage for greedy adventurers
- **Dispatch panel** (`mission_board.gd`): trait name and effect shown before sending

---

## TIER 3 — ARCHITECTURE PREP (Remaining)

### T3-1: Event System Foundation

**Status:** Not started.

**Problem:** The GDD describes daily procedural events (bard rumors, patron stories, settlement events). No event system exists. This will touch the day loop, UI, save system, and narrative — much harder to retrofit than to scaffold now.

**Files to create:** `data/events/daily_events.json`, new function in GameManager

**What to do:**
- Define a minimal event data structure in JSON:
  ```json
  {
    "events": [
      {
        "id": "bard_rumor",
        "type": "flavor",
        "chance": 0.2,
        "text": "A traveling bard shares tales of treasure in the northern ruins.",
        "day_min": 1,
        "day_max": 999
      }
    ]
  }
  ```
- Add a `roll_daily_event()` function to `advance_day()`:
  ```gdscript
  func roll_daily_event():
      var events = DataManager.get_events_for_day(current_day)
      for event in events:
          if randf() < event.get("chance", 0.0):
              log_message("📜 " + event.text)
              break  # One event per day max
  ```
- Add `get_events_for_day(day)` to DataManager — filters by `day_min`/`day_max`.
- Start with 10–15 flavor events. No mechanical effects yet.
- **Scaffold an "effects" field in the JSON for future use** (faction modifiers, mission bonuses, etc). Don't implement effects now.

**Test:** Play 10 days. Verify events fire occasionally. Verify no event fires every single day.

**Dependencies:** T0-1 must be done (already is) if events are ever saved.

---

### T3-2: Reputation Effects

**Status:** Not started.

**Problem:** `tavern_reputation` increments on mission success and decrements on dismissal without severance, but only gates Tier 3 unlock. The GDD describes it affecting patron quality, mission availability, recruit quality.

**Files to modify:** `scripts/GameManager.gd`

**What to do:**
- Define reputation thresholds as a data structure:
  ```gdscript
  var reputation_effects = {
      0:   {"patron_tip_bonus": 0.0, "recruit_quality_bonus": 0},
      25:  {"patron_tip_bonus": 0.1, "recruit_quality_bonus": 1},
      50:  {"patron_tip_bonus": 0.2, "recruit_quality_bonus": 2},
      100: {"patron_tip_bonus": 0.3, "recruit_quality_bonus": 3}
  }
  ```
- Add `get_reputation_tier()` that returns the current threshold dict.
- Wire `patron_tip_bonus` into patron payment calculation (wherever tips are calculated).
- Wire `recruit_quality_bonus` as a flat bonus added to stat rolls in `generate_fallback_recruits()`.
- **Reputation should decrease** on: mission failures, dismissal without severance (already -1 on any dismiss), beer shortages. Currently only goes up on success.
- Add reputation decrease in `complete_mission()` failure branch: `tavern_reputation = max(0, tavern_reputation - 1)`.

**Test:** Play until reputation 25+. Verify tips are slightly higher. Verify recruits have slightly better stats on average.

**Dependencies:** None.

---

### T3-3: Party Synergy

**Status:** Not started.

**Problem:** Class composition has no mechanical effect. A 3-Fighter party and a Fighter/Mage/Healer party perform identically on party missions.

**Files to modify:** `scripts/GameManager.gd` — extend `_resolve_party_mission()`

**What to do:**
- Add synergy calculation in `_resolve_party_mission()`, after `avg_chance` is computed:
  ```gdscript
  func calculate_party_synergy(party: Array) -> float:
      var classes_present = {}
      for member in party:
          classes_present[member.get("class", "")] = true
      var unique_classes = classes_present.size()
      return (unique_classes - 1) * 0.05  # +5% per unique class beyond first
  ```
- Add Healer effect: if party contains a Healer class, reduce death chance by 15% for all members in `handle_party_failure_consequences()`.
- Apply synergy to `final_chance` before clamp.
- Display party synergy in the dispatch confirm panel ("+X% synergy bonus" line).

**Test:** Form a 3-Fighter party and a Fighter+Mage+Healer party for the same mission. The mixed party should have a higher success rate. The Healer party should have a lower death rate on failure.

**Dependencies:** T1-2 (already done).

---

## TIER 4 — GDD UPDATES NEEDED

These are documentation tasks, not code. Do alongside or after T3 work.

### T4-1: Update `02_Gameplay_Mechanics.md`
- Add Section 3.6: Adventurer Dismissal / Release from Service
- Document severance cost (currently flat 5g), conditions (can't dismiss on-mission), reputation effects
- Note the `is_core` boolean placeholder for future Arcana system

### T4-2: Update `00_GDD_Master.md`
- Add "Release" step to Core Loop: Recruit → Dispatch → Manage → Resolve → Consequences → **Release**
- Document mission duration as a core mechanic, not just a JSON field
- Document stat-to-mission matching and trait system as core mechanics

### T4-3: Clarify Day Pacing
- Define how long a "day" is in real-time
- Define patron spawn rate and limits within a day
- Define what triggers day end (player choice? timer? patron limit?)
- This affects economic balance — income per day determines whether tax amounts are achievable

### T4-4: Define Economic Curve
- Document expected income per day at each phase (early/mid/late)
- Document expected costs: daily ops (5g) + wages (1g/adventurer) + beer costs
- Current tax: 1000g + (roster_size × 5). With roster of 5, that's 1025g every 30 days ≈ 34g/day for taxes alone. Is that achievable? Verify with a real playthrough.
- **Recommended: do a full play-test run before editing this doc.**

### T4-5: Define Failure Philosophy
- Document that failure is a narrative branch, not always an ending
- Define the spectrum: minor setback → major consequence → recovery → true game over
- The grace period system (T2-2) and soft-lock safety (T2-3) are already implemented — document them as intentional design

---

## Recommended Next Steps

```
PLAY-TEST a full run (Day 1 → Day 30 tax)   ← Do this first
  ↓
T3-2 (Reputation effects)     ← Most visible impact, 1 file
  ↓
T3-3 (Party synergy)          ← Small change, big feel
  ↓
T3-1 (Event scaffold)         ← More files, but sets up future content
  ↓
T4-1 to T4-5                  ← Documentation, do when stable
  ↓
MAP / DRAG-DROP DISPATCH BOARD ← The big creative feature, now earned
```

---

## Architecture Reference

**Signals to know:**
- `GameManager.adventurer_roster_changed` — emitted after any hire, dismiss, status change
- `GameManager.missions_changed` — emitted after mission pool refresh
- `GameManager.morning_briefing_ready(reports)` — emitted when missions resolve overnight
- `GameManager.day_changed(new_day)` — emitted at start of each new day
- `GameManager.game_over_triggered(reason)` — emitted on any failure condition

**Key functions:**
- `GameManager.calculate_mission_success_chance(adventurer, mission) -> int` — returns 10–95
- `GameManager.get_trait_data(personality) -> Dictionary` — returns trait modifiers from JSON
- `GameManager.dismiss_adventurer(adventurer) -> bool` — safe dismissal with checks
- `GameManager.generate_unique_id() -> int` — collision-safe adventurer IDs
- `DataManager.generate_daily_missions_with_tiers(count, tier) -> Array` — tier-filtered mission pool

**File locations:**
- `scripts/GameManager.gd` — all game state
- `systems/DataManager.gd` — JSON loading only
- `scripts/SaveSystem.gd` — file I/O, delegates to GameManager
- `scenes/ui/script/mission_board.gd` — mission board + dispatch confirm panel
- `scenes/ui/script/morning_briefing.gd` — post-sleep mission results
- `scenes/ui/script/bedroom_popup.gd` — end-of-day / sleep sequence
- `scenes/ui/script/recruitment_popup.gd` — roster management + hiring
- `scenes/ui/AdventurerRosterPanel.gd` — Tab-slide quick roster panel
- `data/characters/traits.json` — trait definitions (already correct, do not restructure)
- `data/missions/mission_types.json` — all mission templates
