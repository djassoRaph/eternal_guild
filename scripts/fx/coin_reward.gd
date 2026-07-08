extends Node3D
## CoinReward — a small procedural 3-coin burst spawned when a patron pays.
## Pure code, no art asset: three thin gold cylinders that pop, fan out, spin, arc,
## and vanish. Add it to the 3D world (inside the SubViewport), set global_position,
## then call burst().

const COIN_COUNT := 3
const LIFETIME := 0.75  # seconds; self-frees shortly after

func burst() -> void:
	SfxManager.play("coins")
	for i in COIN_COUNT:
		_spawn_coin(i)
	# Clean ourselves up once the last coin has finished its flight.
	get_tree().create_timer(LIFETIME + 0.25).timeout.connect(queue_free)

func _spawn_coin(index: int) -> void:
	var coin := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.06
	mesh.bottom_radius = 0.06
	mesh.height = 0.015
	mesh.radial_segments = 14
	coin.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.28)   # warm gold
	mat.metallic = 0.85
	mat.roughness = 0.35
	mat.emission_enabled = true                  # soft glow so it reads in the dim tavern
	mat.emission = Color(1.0, 0.70, 0.20)
	mat.emission_energy_multiplier = 0.4
	coin.material_override = mat
	add_child(coin)

	# Fan the three coins out horizontally at -35 / 0 / +35 degrees.
	var angle := deg_to_rad(-35.0 + 35.0 * float(index))
	var dir := Vector3(sin(angle), 0.0, cos(angle))
	var spread := randf_range(0.16, 0.28)
	var peak := Vector3(dir.x * spread, randf_range(0.35, 0.52), dir.z * spread)
	var land := Vector3(dir.x * spread * 1.7, -0.2, dir.z * spread * 1.7)
	var spin := Vector3(randf_range(-TAU, TAU), randf_range(-TAU, TAU), randf_range(-TAU, TAU))

	coin.position = Vector3.ZERO
	coin.scale = Vector3.ZERO

	var t := create_tween()
	t.set_parallel(true)
	# Pop in
	t.tween_property(coin, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Spin across the whole flight
	t.tween_property(coin, "rotation", spin, LIFETIME)
	# Arc up...
	t.tween_property(coin, "position", peak, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# ...then fall
	t.tween_property(coin, "position", land, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.30)
	# Shrink away at the end
	t.tween_property(coin, "scale", Vector3.ZERO, 0.18).set_ease(Tween.EASE_IN).set_delay(LIFETIME - 0.18)
