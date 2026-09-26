extends Node

# Fill when guild reputation and staff systems ship (Epic 14, Epic 16)

signal reputation_changed(new_value: int)

# Staff (Story 16.1's contract, declared by Story 25.13 so the Bartender and the Quest Dealer can react).
# Story 16.2's hire and 16.5's leaving emit them; role is "bartender" or "desk_manager".
signal staff_hired(staff_id: String, role: String)
signal staff_fired(staff_id: String, role: String)
