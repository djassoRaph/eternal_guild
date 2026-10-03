# dialogue_runner.gd — opens a conversation in the DialogueBox (Story 10.2). Static helpers, no autoload
# (architecture: no new UI singletons; Test 18 asserts Den Fa adds none). No class_name (S8): talkers
# preload it by path.
#
#   var box = Runner.start(self, "res://data/dialogue/den_fa.dialogue", "first_contact")
#   if box: box.closed.connect(...)
#
# start() loads the .dialogue (the imported resource; a file not imported yet is compiled from its text
# with a warning, so a fresh checkout still talks), checks the title, refuses while a box or another
# player-blocking screen is open, instances scenes/ui/DialogueBox.tscn into the current scene (after
# the SubViewportContainer, so the box reads keys before the 3D world) and starts it with the game-state
# bridge as {"bridge": DialogueBridge}. Any failure returns null with one [Dialogue] warning or error and
# leaves nothing open. We don't use DialogueManager.show_dialogue_balloon: it adds the balloon deferred
# to get_current_scene(), which in a --script test is the last /root child.
extends RefCounted

const BOX_SCENE := "res://scenes/ui/DialogueBox.tscn"
const BRIDGE_SCRIPT := "res://scripts/dialogue/dialogue_bridge.gd"

## Stamped by the box when it closes: the key press that closed it must not also act this frame (the
## player's polled jump reads Space, which is ui_accept too).
static var closed_physics_frame := -1
static var closed_process_frame := -1

static var _box: Node = null              # the open box, if any
static var _compiled: Dictionary = {}     # path -> DialogueResource compiled from text (not imported yet)


## Open `title` of the .dialogue at `path`, said by `speaker`. Returns the box, or null (nothing opened).
static func start(speaker: Node, path: String, title: String) -> Node:
	var resource := load_dialogue(path)
	if resource == null:
		return null
	return open(speaker, resource, title)


## Open `title` of an already loaded DialogueResource (Test 20 opens its inline fixtures this way).
static func open(speaker: Node, resource: Resource, title: String) -> Node:
	if speaker == null or not speaker.is_inside_tree():
		push_warning("[Dialogue] refuse: no speaker in the tree for ~ %s" % title)
		return null
	var tree := speaker.get_tree()
	if is_open() or not tree.get_nodes_in_group("dialogue_open").is_empty():
		push_warning("[Dialogue] refuse: a conversation is already open (%s ~ %s)" % [speaker.name, title])
		return null
	for n in tree.get_nodes_in_group("blocks_player"):
		if n.get("visible"):
			push_warning("[Dialogue] refuse: %s is open (%s ~ %s)" % [n.name, speaker.name, title])
			return null
	var titles = resource.get("titles") if resource != null else null
	if not titles is Dictionary or not (titles as Dictionary).has(title):
		push_warning("[Dialogue] refuse: no title '%s' in %s" % [title, _name_of(resource)])
		return null
	var scene = load(BOX_SCENE)
	if not scene is PackedScene:
		push_error("[Dialogue] open: %s does not load" % BOX_SCENE)
		return null
	var box: Node = (scene as PackedScene).instantiate()
	box.set("speaker_node", speaker)
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root
	host.add_child(box)
	_box = box
	print("[Dialogue] open: %s ~ %s (%s)" % [_name_of(resource), title, speaker.name])
	box.start(resource, title, [{"bridge": new_bridge()}])
	return box


## Whether a box is open (alive, in the tree, not closing).
static func is_open() -> bool:
	return _box != null and is_instance_valid(_box) and _box.is_inside_tree() and not _box.is_queued_for_deletion()


## A fresh game-state bridge (dialogue_bridge.gd), the `bridge` a .dialogue file reads.
static func new_bridge() -> RefCounted:
	return (load(BRIDGE_SCRIPT) as GDScript).new()


## Called by the box as it closes.
static func mark_closed() -> void:
	closed_physics_frame = Engine.get_physics_frames()
	closed_process_frame = Engine.get_process_frames()


## True on the frame a box closed and the physics frame after: polled input (jump) skips it.
static func just_closed() -> bool:
	return closed_physics_frame >= 0 and Engine.get_physics_frames() - closed_physics_frame <= 1


## The DialogueResource at `path`: the imported one, else compiled from the file's text (cached), else
## null with one error (missing file, compile errors).
static func load_dialogue(path: String) -> Resource:
	if not FileAccess.file_exists(path):
		push_error("[Dialogue] load: %s does not exist" % path)
		return null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is DialogueResource:
			return res
	if _compiled.has(path):
		return _compiled[path]
	var compiled := compile_text(FileAccess.get_file_as_string(path), path)
	if compiled == null:
		return null
	push_warning("[Dialogue] load: %s isn't imported yet: compiled from its text (open the editor or run --import once)" % path)
	_compiled[path] = compiled
	return compiled


## Compile .dialogue text to a DialogueResource without asserting (DialogueManager.create_resource_from_text
## asserts on errors): null with one error naming the first bad line.
static func compile_text(text: String, path := "") -> Resource:
	var result = DMCompiler.compile_string(text, path)
	if not result.errors.is_empty():
		var first: Dictionary = result.errors[0]
		push_error("[Dialogue] compile: %s has %d error(s), the first on line %d: %s" % [path if path != "" else "text",
			result.errors.size(), int(first.get("line_number", 0)) + 1, DMConstants.get_error_message(int(first.get("error", 0)))])
		return null
	var res := DialogueResource.new()
	res.using_states = result.using_states
	res.titles = result.titles
	res.first_title = result.first_title
	res.character_names = result.character_names
	res.lines = result.lines
	res.raw_text = text
	res.set_meta("source_path", path)
	return res


## How many numbered titles `<prefix>1`, `<prefix>2`, … a resource has in a row (early_1 … early_3: 3).
static func count_numbered(resource: Resource, prefix: String) -> int:
	var titles = resource.get("titles") if resource != null else null
	var n := 0
	while titles is Dictionary and (titles as Dictionary).has("%s%d" % [prefix, n + 1]):
		n += 1
	return n


static func _name_of(resource: Resource) -> String:
	if resource == null:
		return "nothing"
	if resource.resource_path != "":
		return resource.resource_path.get_file()
	return str(resource.get_meta("source_path", "inline text")).get_file()
