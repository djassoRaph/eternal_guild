# staff_panel.gd — the Staff section of Tavern Management (E at the Bar). Story 16.2's PLACEHOLDER hire UX: the epic
# replaces this one file (and its one call in tavern_management.gd) after the [P] staff-hire-UX session; the records,
# the rules and the bus wiring stay in GameManager (Story 16.1). Hiring, dismissing and paying a striker's back wage go
# only through GameManager.hire_staff / dismiss_staff / pay_staff_back_wage; the reasons a button is off come from
# GameManager.staff_hire_block_for, so the panel has no rule of its own.
# One row per staff.json role: hired (Working, or On strike with "Pay N gold"; Dismiss asks once first), a candidate
# ("Hire (N gold)": the first day's wage plus any debt the role left with, K-12; disabled with its reason) or locked
# ("Joins at <tier>", or the demo's "Joins at 150 gold", K-7; no button). Loaded by path (no class_name).
# Player-facing text is DRAFT.
extends VBoxContainer

## An action ran through GameManager (`why` "" = done, else its reason); Tavern Management refreshes on it.
signal acted(role: String, action: String, why: String)

const GAME_MANAGER_SCRIPT := "res://scripts/GameManager.gd"

var _armed := ""          # the role whose Dismiss was pressed once ("Sure? Dismiss")
var _said := {}           # role -> the last refusal shown in its row


## One view per role in `roles` (staff.json order: sorted by role id), from the records and the context GameManager's
## staff_ctx() gives (profile, start_staff, tier_index, tiers, gold). Pure. A view: {role, name, wage, state ("working",
## "on_strike", "candidate", "locked"), line, owed, actions: [{id ("pay", "dismiss", "hire"), text, enabled, reason}]}.
static func staff_rows(records: Array, roles: Dictionary, ctx: Dictionary, armed := "") -> Array:
	var gm_script = load(GAME_MANAGER_SCRIPT)
	var ids: Array = roles.keys().filter(func(k): return k is String and roles[k] is Dictionary)
	ids.sort()
	var out: Array = []
	for role in ids:
		var rec: Dictionary = {}
		for r in records:
			if r is Dictionary and r.get("role") == role:
				rec = r
				break
		if rec.is_empty():
			continue
		var wage := int(rec.get("daily_wage", 1))
		var who := str(rec.get("name", role))
		var view := {"role": role, "name": who.substr(0, 1).to_upper() + who.substr(1), "wage": wage, "owed": 0, "actions": []}
		var dismiss := {"id": "dismiss", "text": "Sure? Dismiss" if armed == role else "Dismiss", "enabled": true, "reason": ""}
		if rec.get("hired") == true:
			if rec.get("on_strike") == true:
				var owed := maxi(0, int(rec.get("owed", 0)))
				var short := int(ctx.get("gold", 0)) < owed
				view.state = "on_strike"
				view.owed = owed
				view.line = "On strike, owed %d gold" % owed
				view.actions = [{"id": "pay", "text": "Pay %d gold" % owed, "enabled": not short, "reason": "Not enough gold" if short else ""}, dismiss]
			else:
				view.state = "working"
				view.line = "Working"
				view.actions = [dismiss]
		else:
			var why: String = gm_script.staff_hire_block_for(rec, roles[role], ctx)
			if why.begins_with("Joins at "):
				view.state = "locked"
				view.line = why.trim_suffix(".")
			else:
				var debt := maxi(0, int(rec.get("owed", 0)))   # K-12: what the role left owed, paid back on hiring
				view.state = "candidate"
				view.owed = debt
				view.line = "Not hired, owed %d gold" % debt if debt > 0 else "Not hired"
				view.actions = [{"id": "hire", "text": "Hire (%d gold)" % gm_script.staff_hire_cost(rec), "enabled": why == "",
					"reason": why.trim_suffix(".")}]
		out.append(view)
	return out


## Rebuild the rows from GameManager's records (after an action, the popup opening, a test).
func refresh() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	add_theme_constant_override("separation", 6)
	add_child(HSeparator.new())
	var title := Label.new()
	title.text = "Staff"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	for v in staff_rows(GameManager.staff, GameManager.staff_roles(), GameManager.staff_ctx(), _armed):
		add_child(_row(v))


func _row(v: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.name = "%s_row" % v.role
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	box.add_child(line)
	var who := Label.new()
	who.name = "%s_name" % v.role
	who.text = "%s · %d gold a day" % [v.name, v.wage]
	who.custom_minimum_size = Vector2(230, 0)
	line.add_child(who)
	var state := Label.new()
	state.name = "%s_state" % v.role
	state.text = v.line
	state.custom_minimum_size = Vector2(170, 0)
	state.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45) if v.state == "on_strike" else Color(0.85, 0.85, 0.8))
	line.add_child(state)
	var reason := ""
	for a in v.actions:
		var b := Button.new()
		b.name = "%s_%s" % [v.role, a.id]
		b.text = a.text
		b.disabled = not a.enabled
		b.custom_minimum_size = Vector2(120, 30)
		b.pressed.connect(_act.bind(v.role, a.id))
		line.add_child(b)
		if a.reason != "" and reason == "":
			reason = a.reason
	if _said.get(v.role, "") != "":
		reason = str(_said[v.role]).trim_suffix(".")
	if reason != "":
		var r := Label.new()
		r.name = "%s_reason" % v.role
		r.text = reason
		r.add_theme_font_size_override("font_size", 12)
		r.add_theme_color_override("font_color", Color(1.0, 0.7, 0.5))
		box.add_child(r)
	return box


func _act(role: String, action: String) -> void:
	var why := ""
	match action:
		"dismiss":
			if _armed != role:
				_armed = role          # the first press only asks
				refresh.call_deferred()
				return
			_armed = ""
			why = GameManager.dismiss_staff(role)
		"hire":
			_armed = ""
			why = GameManager.hire_staff(role)
		"pay":
			_armed = ""
			why = GameManager.pay_staff_back_wage(role)
	_said[role] = why
	refresh.call_deferred()
	acted.emit(role, action, why)
