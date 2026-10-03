extends Node

# Fill when guild reputation and staff systems ship (Epic 14, Epic 16)

signal reputation_changed(new_value: int)

# Den Fa's state (Story 10.3): "early" -> "mid" -> "late", forward only. GameManager owns it
# (den_fa_state, moved by adjust_reputation() at game_config.json's den_fa_state_tiers) and emits this when
# a move is earned in play, once per step (a jump across both tiers: early -> mid, then mid -> late).
# Loading a save and New Game set the state silently. Den Fa reads the state when talked to.
signal den_fa_state_changed(old_state: String, new_state: String)

# Staff (Story 16.1's contract, declared by Story 25.13 so the Bartender and the Quest Dealer can react).
# Story 16.2's hire and 16.5's leaving emit them; role is "bartender" or "desk_manager".
signal staff_hired(staff_id: String, role: String)
signal staff_fired(staff_id: String, role: String)
