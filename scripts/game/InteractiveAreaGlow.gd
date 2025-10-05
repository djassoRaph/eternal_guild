# InteractiveAreaGlow.gd
# Attach this directly to Area3D nodes (BarArea, RecruitmentDesk, etc.)
# Creates glow plane automatically on ready
extends Area3D

var glow_plane: MeshInstance3D

func _ready():
	# Auto-configure collision
	collision_layer = 1
	collision_mask = 1
	monitoring = true
	monitorable = true
	
	# Create glow plane programmatically
	create_glow_plane()
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	print("✅ Interactive Area Glow ready: ", name)

func create_glow_plane():
	"""Create the glowing floor indicator"""
	glow_plane = MeshInstance3D.new()
	add_child(glow_plane)
	
	# Create plane mesh
	var plane = PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)  # 2x2 meter glow
	glow_plane.mesh = plane
	
	# Position slightly above floor
	glow_plane.position = Vector3(0, 1.05, 0)
	glow_plane.rotation_degrees = Vector3(0, 0, 0)  # Flat on ground
	
	# Create emissive material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0.8, 1, 0.5)  # Cyan with transparency
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0, 1, 1)  # Bright cyan
	mat.emission_energy = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # Always bright
	glow_plane.material_override = mat
	
	# Hide by default
	glow_plane.visible = false

func _on_body_entered(body: Node3D):
	"""Show glow when player enters"""
	print("Body entered ", name, ": ", body.name)
	
	if body.name == "Player" or body.is_in_group("player"):
		print("👀 Showing glow for: ", name)
		if glow_plane:
			glow_plane.visible = true

func _on_body_exited(body: Node3D):
	"""Hide glow when player leaves"""
	if body.name == "Player" or body.is_in_group("player"):
		print("🚶 Hiding glow for: ", name)
		if glow_plane:
			glow_plane.visible = false
