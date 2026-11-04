# water_wheel.gd — Story 25.35: the watermill's wheel turns. Put on the watermill (village_kit/S_watermill.gltf): it
# finds the child "Wheel" (its origin on the axle, the axle along local X) and turns it at turns_per_minute, the top of
# the wheel moving downstream. Loaded by path: no class_name.
extends Node3D

@export var turns_per_minute := 5.0

var _wheel: Node3D


func _ready() -> void:
	_wheel = find_child("Wheel", true, false) as Node3D
	if _wheel == null:
		push_warning("[WaterWheel] no child named Wheel under %s" % name)


func _process(delta: float) -> void:
	if _wheel:
		_wheel.rotate_object_local(Vector3.RIGHT, -TAU * turns_per_minute / 60.0 * delta)
