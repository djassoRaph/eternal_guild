# history_chapter.gd — the Codex's Guild History chapter. Interim (Story 18.1): the old overlay's Guild Record row (the
# all-time totals) moved into the book; Story 18.4 adds the run entries (codex.dat guild_history, Story 13.4).
extends RefCounted

const UI := preload("res://scripts/menus/codex/codex_ui.gd")


func build(left: VBoxContainer, _right: VBoxContainer, ctx: Dictionary) -> void:
	var cfg: Dictionary = ctx.cfg
	var codex: Dictionary = ctx.codex if ctx.codex is Dictionary else {}
	var row := HBoxContainer.new()
	row.name = "Totals"
	left.add_child(row)
	for pair in [["Runs", "total_runs"], ["Best Day", "best_day_reached"], ["Gold Earned", "total_gold_earned"], ["Missions", "total_missions_completed"]]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UI.label(cfg, UI.num(codex.get(pair[1], 0)), "heading"))
		col.add_child(UI.label(cfg, pair[0], "small", true))
		row.add_child(col)
