# PlayerManager.gd
# AUTOLOAD SINGLETON - Add to Project Settings > Autoload as "PlayerManager"
# Manages persistent player across scene transitions
extends Node


# =============================================================================
# CONFIG
# =============================================================================
const PLAYER_SCENE_PATH := "res://scenes/player/Player.tscn"


# =============================================================================
# STATE
# =============================================================================
var player: CharacterBody3D = null
var player_scene: PackedScene = null
var is_transitioning := false
var pending_spawn_position := Vector3.ZERO
var has_pending_spawn := false
var _last_scene_name := ""


# =============================================================================
# SIGNALS
# =============================================================================
signal player_spawned(p: CharacterBody3D)
signal scene_transition_completed(scene_name: String)


# =============================================================================
# READY
# =============================================================================
func _ready() -> void:
	print("========================================")
	print("🎮 PlayerManager: INITIALIZING...")
	print("========================================")
	
	# Preload player scene if it exists
	if ResourceLoader.exists(PLAYER_SCENE_PATH):
		player_scene = load(PLAYER_SCENE_PATH)
		print("✅ Player scene loaded: ", PLAYER_SCENE_PATH)
	else:
		print("⚠️ No Player.tscn at: ", PLAYER_SCENE_PATH)
	
	# Connect to tree signals - multiple methods for reliability
	get_tree().node_added.connect(_on_node_added)
	get_tree().tree_changed.connect(_on_tree_changed)
	
	# Track current scene
	if get_tree().current_scene:
		_last_scene_name = get_tree().current_scene.name
		print("📍 Initial scene: ", _last_scene_name)
	
	print("✅ PlayerManager READY")
	print("========================================")


# =============================================================================
# PUBLIC: TRANSITION TO SCENE
# =============================================================================
func transition_to_scene(scene_path: String, spawn_pos: Vector3 = Vector3.ZERO) -> void:
	print("")
	print("========================================")
	print("🚀 TRANSITION REQUESTED")
	print("   To: ", scene_path)
	print("   Spawn: ", spawn_pos)
	print("========================================")
	
	if is_transitioning:
		print("❌ Already transitioning! Ignoring.")
		return
	
	# Check scene exists
	if not ResourceLoader.exists(scene_path):
		print("❌ ERROR: Scene does not exist: ", scene_path)
		return
	print("✅ Scene file exists")
	
	is_transitioning = true
	
	# Store spawn position
	if spawn_pos != Vector3.ZERO:
		pending_spawn_position = spawn_pos
		has_pending_spawn = true
		print("📍 Spawn position saved")
	
	# Remove player from current parent
	if player and is_instance_valid(player):
		var parent = player.get_parent()
		if parent:
			print("📤 Removing player from: ", parent.name)
			parent.remove_child(player)
		else:
			print("⚠️ Player has no parent")
	else:
		print("⚠️ No valid player reference")
	
	# Clear zones
	var zui = get_node_or_null("/root/ZonePromptUI")
	if zui:
		zui.clear_all_zones()
		print("🧹 Zones cleared")
	
	# DO THE SCENE CHANGE
	print("🔄 Calling change_scene_to_file()...")
	var result = get_tree().change_scene_to_file(scene_path)
	print("🔄 Result: ", result, " (0 = OK)")
	
	if result != OK:
		print("❌ Scene change FAILED!")
		is_transitioning = false
	else:
		print("✅ Scene change initiated!")
	
	print("========================================")


# =============================================================================
# SCENE DETECTION
# =============================================================================
func _on_node_added(node: Node) -> void:
	if node == get_tree().current_scene:
		print("🔍 Node added is current_scene: ", node.name)
		call_deferred("_handle_new_scene", node)


func _on_tree_changed() -> void:
	if not get_tree(): 
		return
	var current = get_tree().current_scene
	if current and current.name != _last_scene_name:
		print("🔍 Tree changed, new scene: ", current.name)
		_last_scene_name = current.name
		call_deferred("_handle_new_scene", current)


func _process(_delta: float) -> void:
	# Backup detection via polling
	if not is_transitioning:
		return
	
	var current = get_tree().current_scene
	if current and current.name != _last_scene_name:
		print("🔍 Scene change detected via _process: ", current.name)
		_last_scene_name = current.name
		call_deferred("_handle_new_scene", current)


# =============================================================================
# HANDLE NEW SCENE LOADED
# =============================================================================
func _handle_new_scene(scene_root: Node) -> void:
	print("")
	print("========================================")
	print("📍 NEW SCENE LOADED: ", scene_root.name)
	print("========================================")

	# Only manage the player in scenes that opt in. The menu and the hex
	# map have no floor or spawn point — injecting a player there makes it
	# fall through the void. Scenes that want a player join the
	# "player_scene" group (set in the editor on the scene root).
	if not scene_root.is_in_group("player_scene"):
		print("⏭️  Scene '", scene_root.name, "' is not a player_scene — PlayerManager standing down.")
		is_transitioning = false
		return

	# Find where to put player
	var parent_node = _find_player_parent(scene_root)
	print("📍 Player parent: ", parent_node.get_path() if parent_node else "NONE")
	
	# Determine spawn position
	var spawn_pos := Vector3.ZERO
	
	if has_pending_spawn:
		spawn_pos = pending_spawn_position
		has_pending_spawn = false
		print("📍 Using pending spawn: ", spawn_pos)
	else:
		var sp = _find_spawn_point(scene_root)
		if sp:
			spawn_pos = sp.global_position
			print("📍 Found spawn point: ", sp.name, " at ", spawn_pos)
	
	# Check for existing player in scene
	var existing = _find_player_in_scene(scene_root)
	
	if existing:
		print("👤 Found existing player in scene")
		if player and player != existing:
			print("🗑️ Removing duplicate, keeping ours")
			if spawn_pos == Vector3.ZERO:
				spawn_pos = existing.global_position
			existing.queue_free()
		else:
			# Adopt existing
			player = existing
			_setup_player(player)
			print("✅ Adopted existing player")
			is_transitioning = false
			emit_signal("scene_transition_completed", scene_root.name)
			return
	
	# Add our player to scene
	if player and is_instance_valid(player):
		print("📥 Adding player to scene...")
		if parent_node:
			parent_node.add_child(player)
		else:
			scene_root.add_child(player)
		
		if spawn_pos != Vector3.ZERO:
			player.global_position = spawn_pos
		
		print("✅ Player added at: ", player.global_position)
	else:
		print("⚠️ No player to add, creating new one...")
		player = _create_player(parent_node if parent_node else scene_root, spawn_pos)
	
	is_transitioning = false
	emit_signal("scene_transition_completed", scene_root.name)
	print("========================================")


# =============================================================================
# HELPERS
# =============================================================================
func _find_player_parent(root: Node) -> Node:
	# Check for SubViewport pattern (MainTavern)
	var sv = root.get_node_or_null("SubViewportContainer/SubViewport")
	if sv:
		print("   Found SubViewport structure")
		return sv
	return root


func _find_spawn_point(root: Node) -> Node3D:
	for name in ["PlayerSpawnPoint", "SpawnPoint", "PlayerSpawn"]:
		var sp = _find_node(root, name)
		if sp and sp is Node3D:
			return sp
	return null


func _find_player_in_scene(root: Node) -> CharacterBody3D:
	# Check group
	var group = get_tree().get_nodes_in_group("player")
	if group.size() > 0:
		return group[0]
	
	# Search by name
	var p = _find_node(root, "Player")
	if p and p is CharacterBody3D:
		return p
	
	return null


func _find_node(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root
	for child in root.get_children():
		var found = _find_node(child, target_name)
		if found:
			return found
	return null


func _setup_player(p: CharacterBody3D) -> void:
	if not p.is_in_group("player"):
		p.add_to_group("player")


func _create_player(parent: Node, pos: Vector3) -> CharacterBody3D:
	var p: CharacterBody3D
	
	if player_scene:
		p = player_scene.instantiate()
		print("✅ Instantiated from Player.tscn")
	else:
		p = CharacterBody3D.new()
		var col = CollisionShape3D.new()
		var shape = CapsuleShape3D.new()
		shape.radius = 0.4
		shape.height = 1.5
		col.shape = shape
		p.add_child(col)
		print("⚠️ Created basic player (no scene)")
	
	p.name = "Player"
	parent.add_child(p)
	p.global_position = pos
	_setup_player(p)
	
	emit_signal("player_spawned", p)
	return p
