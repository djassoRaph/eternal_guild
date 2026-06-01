class_name HexGrid

# Spacing constants — set to 2.0 (round number, ref: HexagoneWorld.tscn measured ~2.13 x / ~1.96 z).
# Odd rows are offset by half a column step (true honeycomb / offset-coordinate layout).
const COL_STEP  := 2.0   # world-space X distance between adjacent columns
const ROW_STEP  := 2.0   # world-space Z distance between adjacent rows
const ROW_OFFSET := 1.0  # X shift applied to odd rows (COL_STEP / 2)


# Convert offset grid coordinates to world-space position (Y = 0).
# col and row are integers; odd rows are shifted right by ROW_OFFSET.
static func offset_to_world(col: int, row: int) -> Vector3:
	var x := col * COL_STEP + (ROW_OFFSET if row % 2 != 0 else 0.0)
	var z := row * ROW_STEP
	return Vector3(x, 0.0, z)


# Axial-coordinate variant (q = column axis, r = row axis).
# Maps to the same honeycomb layout as offset_to_world.
static func axial_to_world(q: int, r: int) -> Vector3:
	var col := q + (r - (r & 1)) / 2
	var row := r
	return offset_to_world(col, row)
