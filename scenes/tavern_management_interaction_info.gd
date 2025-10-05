# InteractionGlow.gd
# Attach this to each InteractionInfo node
extends Node3D

# Reference to the glow mesh
@onready var glow_indicator: MeshInstance3D = $GlowPlane

func _ready():
	# Initial setup
	if glow_indicator == null:
		push_error("ERROR: GlowPlane MeshInstance3D not found! Check scene structure.")
		return
	
	# Hide glow by default
	glow_indicator.visible = false
	
	# Connect to parent Area3D signals
	var parent_area = get_parent()
	if parent_area is Area3D:
		parent_area.body_entered.connect(_on_body_entered)
		parent_area.body_exited.connect(_on_body_exited)
		print("✅ Glow system connected for: ", name)
	else:
		push_error("ERROR: Parent must be Area3D, got: ", parent_area.get_class())

func _on_body_entered(body: Node3D):
	"""Show glow when player enters interaction zone"""
	# Verify it's the player
	if body.name == "Player" or body.is_in_group("player"):
		print("👀 Player entered interaction zone: ", name)
		glow_indicator.visible = true

func _on_body_exited(body: Node3D):
	"""Hide glow when player leaves"""
	if body.name == "Player" or body.is_in_group("player"):
		print("🚶 Player left interaction zone: ", name)
		glow_indicator.visible = false
