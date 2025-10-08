# PatronSpawner.gd - SIMPLE SPAWNING SYSTEM
extends Node3D
class_name PatronSpawner

@export var max_patrons: int = 1
@export var spawn_interval: float = 20.0

# Patron scene to spawn
const PATRON_SCENE = preload("res://scenes/npcs/RealisticPatron.tscn")

var entrance_position = Vector3(8.7, 0.0, 3.3)

# State tracking
var active_patrons: Array = []
var spawn_timer: Timer

func _ready():
	print("🚀 PatronSpawner initializing...")
	
	# Set up spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.one_shot = false
	add_child(spawn_timer)
	
	await get_tree().create_timer(2.0).timeout
	
	print("✅ Spawning system ready")
	spawn_timer.start()
	
	if can_spawn_patron():
		spawn_patron()

func _on_spawn_timer_timeout():
	"""Try to spawn a patron on timer"""
	if can_spawn_patron():
		spawn_patron()

func can_spawn_patron() -> bool:
	"""Check if we can spawn a new patron"""
	if active_patrons.size() >= max_patrons:
		print("⚠️ Max patrons reached (", active_patrons.size(), "/", max_patrons, ")")
		return false
		
	return true

func spawn_patron():
	# Create patron instance
	var patron = PATRON_SCENE.instantiate()
	add_child(patron)
	
	# Place the patron at the entrance
	patron.global_position = entrance_position
	
	# Directly tell the patron to wait for service (skip movement)
	patron.set_up_for_static_spawn()
	
	# Connect cleanup signal
	patron.patron_finished.connect(_on_patron_finished)
	
	# Track patron
	active_patrons.append(patron)
	
	print("🆕 Spawned patron '", patron.patron_name, "' at entrance")
	print("🍺 Active patrons: ", active_patrons.size(), "/", max_patrons)

func _on_patron_finished(patron: RealisticPatron):
	"""Clean up when patron leaves"""
	if patron in active_patrons:
		active_patrons.erase(patron)
	
	patron.queue_free()
	
	print("👋 Patron left. Active: ", active_patrons.size(), "/", max_patrons)
	
	if can_spawn_patron() and randf() < 0.7:
		await get_tree().create_timer(randf_range(5.0, 15.0)).timeout
		if can_spawn_patron():
			spawn_patron()
