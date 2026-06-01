# Adventurer Presence System — Build Spec (Planning Doc)

### **Status: PLANNING — not yet implemented. Code at a later date.**
### **Project: Chronicles of the Eternal Guild**
### **Engine: Godot 4.4**

> This document specifies the "living adventurers" feature: recruits who walk into the tavern, wait to be hired, linger as residents if hired, leave at day's end if not, and walk to the door when dispatched. It is written to **extend the existing patron system**, not replace or parallel it. Read alongside `04_Art_and_Interaction.md` §3.3 (the A–D ladder) and `05_Technical_Architecture.md` §6.

---

## 0. The Scene We're Building (so the intent is never lost)

> Morning. The door swings and a rogue ducks in, throws a half-wave toward the bar, and finds a spot near the door to wait — she doesn't know yet if she'll be hired. Two more drift in over the next while. By evening, if the player hasn't taken her on, she pulls her hood up and walks back out into the dark. The ones who were hired are still there when the fire burns low, standing near it, waiting for the next job. When the player sends a party off, they stand and walk to the door together and are gone.

Every beat in that paragraph is a state in the machine below. Nothing here is decoration for its own sake — the unhired applicant leaving at dusk is the *complicity & consequence* pillar pushed one step earlier into the loop.

---

## 1. What Already Exists (the foundation we extend)

The patron system is a complete, working template for everything here:

* **`RealisticPatron.gd`** — a `CharacterBody3D` with a `PatronState` enum state machine, a `NavigationAgent3D`, KayKit model swapping (`_swap_to_random_model()`), animation playback (`_patron_play_animation()`), and signal emission on lifecycle events (`patron_finished`, `wants_to_be_served`). It already walks entrance → table → exit.
* **`PatronSpawner.gd`** — owns `active_patrons`, anchor positions (`table_positions`), occupancy tracking (`occupied_tables`), spawn gating (`can_spawn_patron()`), and bulk cleanup (`despawn_all_patrons()`).
* **`GameManager`** — the data authority. Already exposes `hire_adventurer()`, `get_ready_adventurers()`, `get_adventurer_count()`, `cleanup_expired_recruitment_candidates()`, and emits `adventurer_roster_changed` and `day_changed`.

**Design rule for this whole feature:** the adventurer avatar is a *view* of `GameManager` data. It never owns truth. If the avatar and the data disagree, the data wins and the avatar is corrected or despawned. This is the same separation the patron system already respects (patrons are ephemeral; gold/beer live in GameManager).

---

## 2. Scope of THIS Build (Layer A + heart of Layer B)

In scope:
* Recruits arrive as walking avatars and wait in a "lobby" area near the door.
* Hired adventurers relocate to resident anchor points (by the fire, etc.).
* Unhired recruits leave at end of day.
* Dispatched adventurers (while player is inside) stand and walk to the door, then despawn.
* Wounded/Resting adventurers stand at status-appropriate anchors.

**Explicitly OUT of scope for this build (do not build yet):**
* Cross-scene continuity (Layer D — seeing them in `ExteriorWorld.tscn`). Deferred. See §9.
* Adventurers walking *back in* on mission return as a visual. (Data return already works; the walk-in animation is a later, easy add once Layer A is stable.)
* Conversations, idle barks, table-sitting animations beyond what KayKit models already have.

The discipline line: **build only what happens inside the room the player is looking at, and only for adventurers who are physically present.** Everything else is data.

---

## 3. The Core Constraint: Render Cap

`GameManager` may hold a large roster (GDD soft cap: 78). The tavern **must never try to render all of them.**

* Define `MAX_VISIBLE_ADVENTURERS` (start at ~10–12).
* The spawner renders avatars for *present* adventurers up to the cap. Present = status in {Ready, Resting, Wounded} AND not currently deployed.
* If more are present than the cap allows, render the cap's worth; the rest are understood to be "around" without a body. Nobody counts; a dozen bodies reads as "full."
* This mirrors the existing 5-patron visible cap. It is the single most important rule — getting it wrong (rendering all 78) collapses the feature at 60 FPS under the pixel shader.

---

## 4. New Files

```
scenes/npcs/AdventurerNPC.tscn              # mirrors RealisticPatron.tscn structure
scripts/npcs/AdventurerNPC.gd               # the state-machine body (see §5)
scripts/npcs/AdventurerPresenceManager.gd   # the spawner/coordinator (see §6)
```

`AdventurerNPC.tscn` is structurally a clone of `RealisticPatron.tscn`: a `CharacterBody3D` root with a `CollisionShape3D` and a `NavigationAgent3D`, model loaded at runtime. Same collision layers (Layer 2, Mask 1, no NPC-to-NPC collision) so adventurers and patrons coexist without shoving each other.

---

## 5. `AdventurerNPC.gd` — The State Machine

Modeled directly on `RealisticPatron.gd`. Reuse its model-swap, animation, and navigation code wholesale (`_swap_to_random_model`, `_find_animation_player`, `_patron_play_animation`, `_navigate_with_agent`). Only the states and lifecycle differ.

### 5.1 States
```gdscript
enum AdventurerState {
    ARRIVING,        # walking from door to a lobby/waiting spot
    WAITING_HIRE,    # standing in lobby, available to recruit (the "wave and wait")
    RESIDENT_IDLE,   # hired, standing at a resident anchor (by the fire, etc.)
    WALKING_TO_SPOT, # relocating between anchors (e.g. lobby -> fire on hire)
    LEAVING          # walking to door, then despawn (unhired at dusk, or dispatched)
}
```

### 5.2 Identity binding (critical)
Each avatar holds the **id of the GameManager adventurer it represents** (`adventurer_id: String` or the dict reference per your data shape — confirm against `GameManager`'s adventurer structure before coding). The avatar's class determines its KayKit model (Knight/Mage/Rogue/Barbarian), so it is **not** random like patrons — a Mage recruit shows the Mage model. This is the one real change to the model-swap logic: pick by class, not `randi()`.

### 5.3 Lifecycle / transitions
* Spawned at the door anchor in `ARRIVING`, target = an open lobby spot → on `navigation_finished` → `WAITING_HIRE`, play Idle, optionally a one-shot wave animation if the model has one.
* On hire (signal from manager): → `WALKING_TO_SPOT`, target = an open resident anchor → arrive → `RESIDENT_IDLE`.
* On end-of-day-unhired (manager call): → `LEAVING`, target = door → arrive → emit `adventurer_left` → `queue_free()`.
* On dispatch (manager call, player inside): → `LEAVING`, target = door → arrive → emit `adventurer_departed_for_mission` → `queue_free()`.
* Wounded/Resting: spawned or relocated to a status anchor in `RESIDENT_IDLE` (placement differs, behavior identical).

### 5.4 Signals
```gdscript
signal arrived_at_lobby(npc)
signal adventurer_left(npc)                  # unhired, gone for good
signal adventurer_departed_for_mission(npc)  # dispatched
signal reached_resident_spot(npc)
```

---

## 6. `AdventurerPresenceManager.gd` — The Coordinator

Modeled on `PatronSpawner.gd`. Owns the avatars, the anchor sets, and the sync to GameManager.

### 6.1 Anchor sets (hand-placed Vector3 lists, like `table_positions`)
```gdscript
var door_anchor: Vector3                 # shared entrance, reuse patron entrance_position
var lobby_anchors: Array[Vector3]        # waiting-to-be-hired spots near the door
var fire_anchors: Array[Vector3]         # resident idle spots by the fireplace
var medical_anchors: Array[Vector3]      # wounded loiter here
var rest_anchors: Array[Vector3]         # resting adventurers
```
Anchors are authored by hand in the tavern scene, exactly as `table_positions` are today. Occupancy tracked per-anchor (dictionary), same as `occupied_tables`.

### 6.2 The sync model (the heart of correctness)
The manager does **not** drive state from gameplay events directly. It **reconciles the visible avatars against GameManager's data** whenever the data changes:

* Listen to `GameManager.adventurer_roster_changed` and the recruitment-candidate signals.
* On change, compute: who *should* be visible (present, not deployed, up to cap) vs. who *is* currently spawned.
* Spawn avatars for newly-present adventurers; transition-to-LEAVING avatars for ones no longer present (dispatched, left, died).
* This reconcile-on-signal pattern means the avatars can never permanently desync from the data — a missed event self-heals on the next reconcile. It is more robust than trying to perfectly mirror every event.

### 6.3 Daily lifecycle hooks
* **Recruits arriving:** when GameManager generates the day's recruitment candidates, the manager spawns `WAITING_HIRE` avatars for them in the lobby (capped). These represent *candidates*, not yet roster members.
* **On hire:** the hired candidate's avatar transitions lobby → resident anchor. (Recruitment currently flows through `GameManager.hire_adventurer()` via `main_tavern.hire_recruit()` / the recruitment popup — the manager listens for the resulting roster change rather than hooking the popup directly.)
* **End of day:** unhired candidate avatars go `LEAVING`. This pairs with the existing `cleanup_expired_recruitment_candidates()` — the data cleanup already exists; this adds the *visible* departure. Hook alongside the existing `despawn_all_patrons()` call in the day-advance flow (`main_tavern.advance_day` / `zone_interactions.open_bedroom_popup`).

### 6.4 Dispatch hook
When an adventurer is dispatched (the future WorldMap, or current mission board), GameManager emits the dispatch event. The manager finds that adventurer's resident avatar and sends it `LEAVING`. If no avatar exists (over cap / not rendered), nothing visible happens — correct and harmless.

---

## 7. Integration Points (where this touches existing code)

Minimal and additive. Nothing existing is rewritten.

* **`MainTavern.tscn`** — add one `AdventurerPresenceManager` node (sibling of the patron spawner) and author the anchor positions.
* **`GameManager`** — confirm/lean on existing signals (`adventurer_roster_changed`, `day_changed`) and the dispatch event. If a clean "adventurer dispatched" signal carrying the adventurer id doesn't yet exist, **add one** — this is the same forward-compatible dispatch event the WorldMap spec needs, so it serves double duty.
* **Day-advance flow** — alongside `despawn_all_patrons()`, call the manager's "send unhired recruits home" + "despawn-all for night" so the tavern empties at night like the patrons do.
* **Recruitment** — no change to recruitment logic; the manager observes roster changes rather than intercepting the hire.

---

## 8. Build Order (each step leaves a working game)

1. **Static residents.** `AdventurerNPC` + manager; spawn idle avatars at fire/rest/medical anchors for the *already-hired* roster (capped). No arriving, no leaving. Verify: hire someone via existing flow → a body appears by the fire. This alone makes the tavern feel alive.
2. **Class-correct models.** Model picked by adventurer class, not random.
3. **Recruit arrival.** Day's candidates spawn at the door and walk to lobby, `WAITING_HIRE`. Hire → walk to fire. Verify against the recruitment popup.
4. **Unhired departure.** End-of-day unhired candidates walk to door and despawn, paired with existing candidate cleanup.
5. **Dispatch walk-out.** On dispatch, resident avatar walks to door and despawns. (Pairs naturally with the WorldMap dispatch work.)
6. **Status placement polish.** Wounded → medical anchors, Resting → rest anchors.

Ship after any step. Step 1 is already a visible win for the "strong visuals before Kickstarter" goal.

---

## 9. Deferred: Cross-Scene Continuity (Layer D) — DO NOT BUILD YET

Recorded so it stays possible without a rewrite, then set down:

When the player walks out to `ExteriorWorld.tscn`, dispatched adventurers do **not** carry over as live nodes (the scenes don't share memory). The future solution is **reconstruction on scene load**: `ExteriorWorld` reads the list of in-transit adventurers from GameManager and spawns avatars at positions *interpolated from departure time and travel duration* — not a continuous simulation. The only data requirement is that each in-transit adventurer stores departure day/time, travel duration, and direction (outbound/returning). Position is derived, never stored tick-by-tick.

This is the entire bridge from this build to Layer D. It is deferred until the core dispatch-and-reveal loop is proven, and must never block Steps 1–6 above.

---

## 10. Risks & Watch-Items

* **The render cap is non-negotiable.** Build Step 1 *with* the cap in place, not as an afterthought.
* **Reconcile, don't mirror.** Driving avatars by reconciling against data (§6.2) avoids the whole class of "avatar stuck because an event was missed" bugs.
* **Candidates vs. roster.** Waiting-to-hire avatars represent recruitment *candidates*; resident avatars represent *roster members*. Keep these distinct in the manager — they have different cleanup rules (candidates expire at dusk; roster members persist).
* **Collision layers.** Use the patron layers (Layer 2 / Mask 1) so adventurers don't collide with patrons or each other; only with the floor/walls.
* **`PlayerManager` duplication** (noted in the architecture doc) is unrelated but lives nearby — don't let it confuse autoload references while wiring this in.
