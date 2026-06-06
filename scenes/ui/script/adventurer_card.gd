# adventurer_card.gd
# Drag-source script attached at runtime by AdventurerRosterPanel.
# Base type must match AdventurerCard.tscn root (PanelContainer).
extends PanelContainer

# Set by AdventurerRosterPanel immediately after set_script(), before add_child().
var adventurer_id  # int (or String fallback when no numeric id exists)


func _get_drag_data(_at_position: Vector2) -> Variant:
	# Availability is sourced exclusively from GameManager.get_ready_adventurers().
	# No status-string check — we inherit whatever logic that function encodes.
	for adv in GameManager.get_ready_adventurers():
		if adv.get("id", adv.get("name")) == adventurer_id:
			var preview := Label.new()
			var name_lbl := get_node_or_null("CardContent/InfoContainer/NameLabel")
			preview.text = name_lbl.text if name_lbl else "Adventurer"
			preview.add_theme_font_size_override("font_size", 15)
			preview.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50, 1.0))
			set_drag_preview(preview)
			return {"type": "adventurer", "id": adventurer_id}
	return null  # not in ready list — drag blocked
