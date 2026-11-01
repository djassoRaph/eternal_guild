extends Node

# The guild's own events: its reputation (Epic 14), Den Fa's state (Story 10.3) and the staff (Epic 16).
# GameManager owns every value behind them and is the only emitter; scenes and UI listen.

signal reputation_changed(new_value: int)
# Story 14.6 (DP-5): adjust_reputation(delta, reason), the one authority, also says what moved it: the change it applied
# (the clamp at 0 can shrink it; none is sent when nothing changed), the new value and the reason ("mission_success",
# "mission_failure", "party_mission_success", "party_mission_failure", "dismiss", "patron_satisfied"; Story 14.4 adds
# "disturbance_resolved" / "disturbance_ignored"; "" from the debug panel). Then, when the tier changed, the old and new tier
# labels (reputation_tiers of the active profile; a jump across two tiers is one change). Then reputation_changed as before.
# Loading a save and New Game set the value silently: these mean "earned in play".
signal reputation_adjusted(delta: int, new_value: int, reason: String)
signal reputation_tier_changed(old_tier: String, new_tier: String)
# Story 14.6 review P9: a tier this run reaches for the first time (GameManager.reputation_peak_tier; saved, New Game 0),
# after reputation_tier_changed. A drop and a climb back to a tier already reached send none. The tier banner's signal.
signal reputation_tier_reached(tier: String)
# Story 14.4: a tavern disturbance was settled: by the player's choice in its conversation (choice: the outcome id, e.g.
# "eject"), or by the morning after it was left alone ("ignored"). rep_delta and gold_delta: what was applied (the
# reputation also went through reputation_adjusted, reason "disturbance_resolved" / "disturbance_ignored").
signal disturbance_resolved(type: String, choice: String, rep_delta: int, gold_delta: int)
# Story 10.7: the demo's ending, the King's messenger (demo profile only). GameManager.demo_ending moved in play: "due"
# (reputation and taxes both reached; `day` is the morning he comes), "coming" (that morning: the hall shows him in the
# day phase), "waiting" (he walked into the hall), "ended" (the player heard him: the end card follows). Loading a save
# and New Game set the state silently.
signal demo_ending_changed(state: String, day: int)
# Epic 9: the Bard's visit moved in play (GameManager.bard_visit): "coming" (queued this morning: the hall shows him at his
# minute in its open hours), "waiting" (at the door), "performing" (let in: Story 9.2), "refused" (turned away, or tired
# of waiting). `day` is the visit's day. Loading a save and New Game set the visit silently.
signal bard_visit_changed(state: String, day: int)

# Den Fa's state (Story 10.3): "early" -> "mid" -> "late", forward only. GameManager owns it
# (den_fa_state, moved by adjust_reputation() at game_config.json's den_fa_state_tiers) and emits this when
# a move is earned in play, once per step (a jump across both tiers: early -> mid, then mid -> late).
# Loading a save and New Game set the state silently. Den Fa reads the state when talked to.
signal den_fa_state_changed(old_state: String, new_state: String)

# Staff (Story 16.1; declared by Story 25.13 so the Bartender and the Quest Dealer could react first).
# staff_id is "<role>/<variant>" (e.g. "bartender/barkeep"), role "bartender" or "desk_manager".
# GameManager emits them when its staff records change in play: hire_staff() -> staff_hired (the body walks in),
# dismiss_staff() and Story 16.5's leaving after unpaid wages -> staff_fired (the body walks out). Loading a save and
# New Game set the records silently: the hall's staff read GameManager.is_staff_hired() when it loads.
# GameManager never listens to these (tests emit them directly to drive the bodies).
signal staff_hired(staff_id: String, role: String)
signal staff_fired(staff_id: String, role: String)
# A hired staff member's strike started (Story 16.5: a wage they weren't paid) or ended (the back wage paid, or they
# were dismissed or left; the record is updated before the signal). Stories 16.3/16.4's automation stops on a strike.
signal staff_strike_changed(staff_id: String, on_strike: bool)
