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


func show_banner(msg: String) -> void:
	# Enforce max visible — drop the oldest
	while _container.get_child_count() >= MAX_VISIBLE:
		var oldest := _container.get_child(0)
		_container.remove_child(oldest)
		oldest.queue_free()

	var panel := PanelContainer.new()
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
	tw.tween_callback(panel.queue_free)
