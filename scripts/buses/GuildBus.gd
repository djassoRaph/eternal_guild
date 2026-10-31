extends Node

# The guild's own events: its reputation (Epic 14), Den Fa's state (Story 10.3) and the staff (Epic 16).
# GameManager owns every value behind them and is the only emitter; scenes and UI listen.

signal reputation_changed(new_value: int)

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
