# tarot_chapter.gd — the Codex's Tarot Cards chapter. Interim (Story 18.1): a stub page; Story 18.2 builds the chapter.
extends RefCounted

const UI := preload("res://scripts/menus/codex/codex_ui.gd")


func build(left: VBoxContainer, _right: VBoxContainer, ctx: Dictionary) -> void:
	var stub := UI.label(ctx.cfg, UI.text(ctx.cfg, "stub"), "body", true, true)
	stub.name = "Stub"
	left.add_child(stub)
