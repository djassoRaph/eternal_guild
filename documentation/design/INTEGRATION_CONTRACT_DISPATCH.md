# Integration Contract — Dispatch & Adventurer Status (Planning Doc)

### **Status: PLANNING — the shared seam between WorldMap and Adventurer Presence.**
### **Project: Chronicles of the Eternal Guild**
### **Engine: Godot 4.4**

> This is the single source of truth for where the **WorldMap dispatch screen** and the **Adventurer Presence system** meet. Both read from GameManager; neither talks to the other directly. If this contract holds, the two systems can be built in any order, in parallel, without colliding. Read alongside `ADVENTURER_PRESENCE_SYSTEM.md` and `05_Technical_Architecture.md` §6.

---

## 1. The One Rule

**Both systems read GameManager. Neither writes to the other.**

* The WorldMap *triggers* a dispatch by calling GameManager.
* GameManager updates its data and emits a signal.
* The Presence system *reacts* to the signal.
* The WorldMap never animates an avatar. The Presence system never decides who is available. GameManager owns both facts.

If you ever find the WorldMap reaching into the tavern to move a body, or the Presence system computing "is this adventurer free" — stop. That logic belongs in GameManager.

---

## 2. The Shared Status Field (read by everyone, written only by GameManager)

Every adventurer has exactly **one** status at a time. This single field is the fact both systems consume.

```gdscript
enum AdventurerStatus {
    READY,      # in the tavern, available to dispatch
    RESTING,    # in the tavern, voluntarily idle / morale
    WOUNDED,    # in the tavern, recovering, cannot be dispatched
    DEPLOYED    # out on a mission, NOT in the tavern
}
```

How each system uses it — **read only, never recompute:**

| Question | WorldMap | Presence system |
|---|---|---|
| Show as grabbable token? | yes if `READY` | — |
| Show greyed-out with return counter? | yes if `DEPLOYED` | — |
| Render an avatar in the tavern? | — | yes if `READY`/`RESTING`/`WOUNDED` (up to cap) |
| Which anchor does the avatar stand at? | — | by status (fire / rest / medical) |
| Don't render at all? | — | if `DEPLOYED` |

"Available to dispatch" = `status == READY`. Computed **once**, in GameManager. Both systems ask GameManager; neither decides for itself. This is what stops the ghost-adventurer bug (a body by the fire who's also shown deployed on the map).

---

## 3. The Dispatch Event (the single intersection point)

When the player drags a token onto a mission and confirms, the WorldMap calls **one** GameManager method, which does the work and emits **one** signal.

### 3.1 The call (WorldMap → GameManager)
```gdscript
# Called by the WorldMap confirm panel. Existing dispatch logic
# (send_on_mission / send_party_on_mission) stays underneath unchanged.
GameManager.dispatch_adventurers(adventurer_ids: Array, mission_id, location_id)
```
Inside, GameManager: sets each adventurer's status to `DEPLOYED`, records the deployment record (§4), then emits:

### 3.2 The signal (GameManager → everyone listening)
```gdscript
signal adventurers_dispatched(adventurer_ids: Array, mission_id, location_id, return_day: int)
```

Who listens, and what they do — independently, neither aware of the other:
* **Presence system:** for each id, find that adventurer's resident avatar (if rendered) → send it `LEAVING` → walk to door → despawn. If no avatar exists (over cap), do nothing. Harmless.
* **WorldMap:** flips those tokens to greyed-out `DEPLOYED` with the return counter.
* **Morning briefing / log / anything future:** can listen too, with zero changes to the above.

### 3.3 The return event (the mirror)
```gdscript
signal adventurers_returned(adventurer_ids: Array, mission_id, success: bool)
```
GameManager flips status back (`DEPLOYED` → `READY`/`WOUNDED`, or removes the dead). The end-of-day reveal consumes this. The Presence system *may* later listen to spawn a walk-in animation — but that's a future polish, not part of this contract.

---

## 4. The Deployment Record (what makes Layer D possible later)

When GameManager sets an adventurer to `DEPLOYED`, it stores a small record. This costs nothing now and is the **entire** bridge to the deferred cross-scene chase (Layer D).

```gdscript
{
    "adventurer_id": "...",
    "mission_id": "...",
    "location_id": "...",     # which hex they went to
    "departure_day": 12,
    "departure_time": 0.0,    # if/when an intra-day clock exists
    "travel_duration": 2,     # days (or hours) out
    "direction": "outbound"   # outbound | returning
}
```

Nothing reads `location_id` / `travel_duration` / `direction` in the near-term build. They exist so that, much later, `ExteriorWorld.tscn` can reconstruct an adventurer's road position from departure time — without simulating anything. Store it now; ignore it until Layer D. (See `05_Technical_Architecture.md` §6.2.)

---

## 5. What Each System Owns (no overlap)

| Concern | Owner |
|---|---|
| Adventurer status (the enum) | **GameManager** |
| "Is this adventurer available?" | **GameManager** |
| Deployment record | **GameManager** |
| Roster data, hire/fire | **GameManager** |
| Hex locations, daily mission spawning | **WorldMap + GameManager data** |
| Dragging tokens, mission cards, map visuals | **WorldMap** |
| Triggering a dispatch | **WorldMap** (calls GameManager) |
| Tavern avatars, anchors, walking, render cap | **Presence system** |
| Reacting to dispatch/return | **Presence system** (listens to GameManager) |

If a concern isn't on this list, decide its owner *before* coding it, and add it here. The table is the contract.

---

## 6. Build Consequence (the one ordering rule)

**Firm up the dispatch event first** — before WorldMap Step 1, before Presence Step 5.

The moment `dispatch_adventurers()` + `adventurers_dispatched` + the status enum exist and are authoritative in GameManager, both systems become independent. They can then be built in any order, on any day, without re-coordinating. Until that exists, every other step is standing on sand.

Minimum first commit:
1. `AdventurerStatus` enum + a single status field per adventurer.
2. `dispatch_adventurers()` that sets status, stores the record, emits the signal.
3. `adventurers_dispatched` / `adventurers_returned` signals.
4. Verify with the F12 debug panel: dispatch a fake party → status flips to DEPLOYED → signal fires → returns flip it back. No map, no avatars needed to test it.

That commit is the seam. Everything else bolts onto it.

---

## 7. Drift Watch (how this contract dies if you're not careful)

* **Two places computing "available."** The instant the WorldMap decides availability on its own instead of asking GameManager, drift begins. One source.
* **WorldMap animating avatars.** If dispatch directly tells a body to walk, the systems are now fused and can't be built apart. It writes data; the avatar reacts.
* **Status as booleans instead of one enum.** `is_deployed`, `is_wounded`, `is_resting` as separate flags will eventually contradict each other (deployed AND resting?). One enum, one value, no contradictions.
* **Skipping the deployment record "for now."** It's nearly free and it's the only thing that keeps Layer D possible without a rewrite. Store it from the first dispatch.
