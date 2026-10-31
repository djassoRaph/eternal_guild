extends Node

signal gold_changed(new_amount: int)
signal beer_changed(new_amount: int)
signal firewood_changed(new_amount: int)
signal fireplace_fuel_changed(new_percentage: float)
signal drink_requested

# The tax cycle (Story 13.1). GameManager emits them each morning from check_tax_deadline() / handle_tax_payment();
# the numbers come from game_config.json's tax_* keys. NotificationManager shows a banner for each.
## A configured day before the due day (tax_warning_days: 7, 3, 1): the tax due then, with today's roster.
signal tax_warning(days_left: int, amount: int)
## The first collection morning of a cycle (the due day, or the first check after it), before the payment is tried.
signal tax_demand_triggered(amount: int, due_day: int)
## The tax was taken through spend_gold (gold_changed has already gone out); the next due day is set.
signal tax_paid(amount: int)
## A morning the tax couldn't be paid, while the grace lasts: the mornings left before the guild falls (bankruptcy).
signal tax_overdue(days_remaining: int)
