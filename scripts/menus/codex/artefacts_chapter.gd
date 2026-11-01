# artefacts_chapter.gd — the Codex's Prior Artefacts chapter. Interim (Story 18.1): the old overlay's list moved into
# the book as it was; Story 18.3 makes it the chapter (the finder, oldest first, the link to The Fallen).
extends RefCounted

const UI := preload("res://scripts/menus/codex/codex_ui.gd")


func build(left: VBoxContainer, _right: VBoxContainer, ctx: Dictionary) -> void:
	var cfg: Dictionary = ctx.cfg
	var raw = ctx.codex.get("artifacts_found", []) if ctx.codex is Dictionary else []
	var list := VBoxContainer.new()
	list.name = "ArtefactList"
	left.add_child(list)
	if not (raw is Array) or (raw as Array).is_empty():
		list.add_child(UI.label(cfg, UI.text(cfg, "artefacts_empty"), "body", true, true))
		return
	for e in raw:
		if e is Dictionary:
			list.add_child(UI.label(cfg, "%s  —  Day %s" % [str(e.get("name", "?")), UI.num(e.get("found_day"))], "body"))
			list.add_child(UI.label(cfg, str(e.get("description", "")), "small", true, true))
