shader_type spatial;
// The map table's window (scenes/dev/MapTable.tscn, scripts/dev/map_table.gd; Raphael's sketch 2026-11-07).
// The world map renders in its own SubViewport from a camera that copies the table camera's pose (offset by the
// pan); this quad, lying on the scroll, shows that render at SCREEN_UV. So the map keeps the table's perspective but
// only shows through the window: it slides under the paper instead of hanging off the table.
// ALPHA puts the quad in the transparent pass; with render_priority 1 it draws after the camera's ink quad
// (edge_detection.gdshader, priority 0), so the map, already inked in its own view, isn't inked and lit twice.
// The quad still depth-tests against the table's opaque pieces (rollers, frame).
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D map_view : source_color, filter_linear;

void fragment() {
	ALBEDO = texture(map_view, SCREEN_UV).rgb;
	ALPHA = 1.0;
}
