extends Node
## NotificationManager (autoload) — non-blocking low-resource banners (Story 3.5).
## Listens to EconomyBus; pops a fading banner when gold / beer / comfort crosses a low threshold.
## Owns its own CanvasLayer, so no scene editing is required.

const MAX_VISIBLE := 2

var _warn_gold := 20
var _warn_beer := 2
var _warn_comfort := 25.0
var _duration := 4.0
var _cooldown := 15.0

var _container: VBoxContainer
var _active := {}      # type -> currently-below (edge detection / re-arm)
var _cooldowns := {}   # type -> seconds remaining


func _ready() -> void:
	if DataManager:
		_warn_gold = int(DataManager.get_config("warn_gold_below", _warn_gold))
		_warn_beer = int(DataManager.get_config("warn_beer_below", _warn_beer))
		_warn_comfort = float(DataManager.get_config("warn_comfort_below", _warn_comfort))
		_duration = float(DataManager.get_config("notification_duration_seconds", _duration))
		_cooldown = float(DataManager.get_config("notification_cooldown_seconds", _cooldown))

	# Own banner layer, anchored top-center. Banners stack downward.
	var layer := CanvasLayer.new()
	layer.layer = 64
	add_child(layer)
	_container = VBoxContainer.new()
	_container.anchor_left = 0.5
	_container.anchor_right = 0.5
	_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_container.grow_vertical = Control.GROW_DIRECTION_END
	_container.offset_top = 24.0
	_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_container.add_theme_constant_override("separation", 8)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_container)

	if EconomyBus:
		EconomyBus.gold_changed.connect(_on_gold_changed)
		EconomyBus.beer_changed.connect(_on_beer_changed)
		EconomyBus.fireplace_fuel_changed.connect(_on_comfort_changed)
		# Story 13.1 (DT-6): the tax cycle's events, one banner each (no cooldown: each is its own event).
		EconomyBus.tax_warning.connect(func(days_left: int, amount: int): show_banner(tax_warning_text(days_left, amount), true))
		EconomyBus.tax_paid.connect(func(amount: int): show_banner(tax_paid_text(amount), true))
		EconomyBus.tax_overdue.connect(func(days_remaining: int): show_banner(tax_overdue_text(days_remaining), true))
		EconomyBus.staff_wage_unpaid.connect(_on_staff_wage_unpaid)   # Story 16.5: an event each, no cooldown
	if GuildBus:
		GuildBus.staff_strike_changed.connect(_on_staff_strike_changed)
		GuildBus.reputation_tier_reached.connect(_on_reputation_tier_reached)   # Story 14.6 (DP-6; review P9)
	if GameBus:
		GameBus.game_over_triggered.connect(func(_cause: String): clear_banners())   # Story 13.4 review P8


## Story 14.6 (DP-6): a tier reached shows a banner, once a run (review P9: GuildBus.reputation_tier_reached, sent only for
## a tier above the run's highest so far, so reputation hovering at a threshold shows one); a drop shows nothing (14.3's
## subdued drop is deferred). An event banner (review, 2026-11-01): it waits its turn, never pushed out by a warning.
func _on_reputation_tier_reached(tier: String) -> void:
	show_banner(tier_rise_text(tier), true)

## Story 14.6: the tier rise banner. DRAFT (Raphael rewrites).
static func tier_rise_text(tier: String) -> String:
	return "The guild is now %s." % tier


## Story 16.5: a staff wage unpaid this morning, worded from the record GameManager has already updated.
func _on_staff_wage_unpaid(staff_id: String) -> void:
	var rec: Dictionary = GameManager.staff_record_by_id(staff_id)
	if not rec.is_empty():
		show_banner(staff_unpaid_text(str(rec.get("name", "?")), int(rec.get("missed_days", 1)), GameManager.staff_missed_days_to_leave()), true)

## Story 16.5: a strike ended for a member still hired (the back wage paid). A dismissal or a leaving ends one too, with
## the record already not hired: no banner (the leaving had its own).
func _on_staff_strike_changed(staff_id: String, on_strike: bool) -> void:
	var rec: Dictionary = GameManager.staff_record_by_id(staff_id)
	if not on_strike and rec.get("hired") == true:
		show_banner("%s is back to work." % _cap(str(rec.get("name", "?"))), true)

## Story 16.5: the unpaid-wage banner: GameManager's sentence (the event log has the same one, review P5).
static func staff_unpaid_text(staff_name: String, missed: int, leave_after: int) -> String:
	return GameManager.staff_unpaid_text(staff_name, missed, leave_after)

static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


## Frees every banner and drops the waiting ones (Story 13.4 review P8: the fall's pause froze them, and they played out
## over the main menu).
func clear_banners() -> void:
	for c in _container.get_children():
		c.queue_free()
	drop_queued()


## Epic 16 review P5: event banners (tax, staff) wait here when two events are already on screen.
var _queue: Array = []
var _newest := ""

## The newest banner text shown or queued ("" after clear_banners / drop_queued).
func newest_text() -> String:
	return _newest

## The event banners waiting their turn, oldest first.
func queued_texts() -> Array:
	return _queue.duplicate()

## Drops the waiting banners (and forgets the newest text).
func drop_queued() -> void:
	_queue.clear()
	_newest = ""


## Story 13.1 (DT-6): the tax banners' text. DRAFT (Raphael rewrites).
static func tax_warning_text(days_left: int, amount: int) -> String:
	if days_left == 1:
		return "Tax due tomorrow: %d gold." % amount
	return "Tax due in %d days: %d gold." % [days_left, amount]

static func tax_paid_text(amount: int) -> String:
	return "Tax paid: %d gold." % amount

static func tax_overdue_text(days_remaining: int) -> String:
	return "Tax overdue. %d day%s before the guild is seized." % [days_remaining, "" if days_remaining == 1 else "s"]


func _process(delta: float) -> void:
	for k in _cooldowns:
		if _cooldowns[k] > 0.0:
			_cooldowns[k] -= delta


func _on_gold_changed(v: int) -> void:
	_check("gold", float(v), float(_warn_gold), "Coins low")

func _on_beer_changed(v: int) -> void:
	_check("beer", float(v), float(_warn_beer), "Beer running low")

func _on_comfort_changed(v: float) -> void:
	# Only warn for a DYING fire (lit but low). A fully-out fire (0) is a normal resting state.
	if v > 0.0:
		_check("comfort", v, _warn_comfort, "Fireplace dying")
	else:
		_active["comfort"] = false


func _check(type: String, value: float, threshold: float, msg: String) -> void:
	if value < threshold:
		if not _active.get(type, false) and _cooldowns.get(type, 0.0) <= 0.0:
			_active[type] = true
			_cooldowns[type] = _cooldown
			show_banner(msg)
	else:
		_active[type] = false  # recovered — re-arm for next time


## A banner (at most MAX_VISIBLE on screen). `event` (Epic 16 review P5): a tax or staff event, never pushed out by a
## low-resource warning. Full: the oldest low-resource banner makes room; with only events on screen an event waits its
## turn (shown when a banner goes) and a low-resource warning is dropped.
func show_banner(msg: String, event := false) -> void:
	var live := _live_banners()
	if live.size() >= MAX_VISIBLE:
		var low := live.filter(func(b): return not b.get_meta("event", false))
		if not low.is_empty():
			_container.remove_child(low[0])
			low[0].queue_free()
		elif event:
			_queue.append(msg)
			_newest = msg
			return
		else:
			return
	_newest = msg
	_add_banner(msg, event)


## The banners on screen (not on their way out), oldest first.
func _live_banners() -> Array:
	return _container.get_children().filter(func(c): return not c.is_queued_for_deletion())


## A banner's time is up: it goes, and the next waiting event shows.
func _banner_done(panel: Node) -> void:
	if is_instance_valid(panel):
		if panel.get_parent() == _container:
			_container.remove_child(panel)
		panel.queue_free()
	if not _queue.is_empty() and _live_banners().size() < MAX_VISIBLE:
		_add_banner(str(_queue.pop_front()), true)


func _add_banner(msg: String, event: bool) -> void:
	var panel := PanelContainer.new()
	panel.set_meta("event", event)
	panel.modulate = Color(1, 1, 1, 0)  # fade in
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	var label := Label.new()
	label.text = msg
	label.add_theme_color_override("font_color", Color(1, 0.88, 0.66))
	margin.add_child(label)
	panel.add_child(margin)
	_container.add_child(panel)

	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)
	tw.tween_interval(_duration)
	tw.tween_property(panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_banner_done.bind(panel))
