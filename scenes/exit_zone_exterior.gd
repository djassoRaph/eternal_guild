extends Area3D

# This zone is placed at the tavern door in the exterior
# When player presses E, transitions back to interior scene

@onready var interaction_prompt = $InteractionPrompt
var player_in_zone = false
var player_ref = null

func _ready():
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Hide prompt initially
	if interaction_prompt:
		interaction_prompt.visible = false

func _process(_delta):
	if player_in_zone and Input.is_action_just_pressed("interact"):
		enter_tavern()

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_zone = true
		player_ref = body
		if interaction_prompt:
			interaction_prompt.visible = true
		print("Player at tavern entrance - Press E to enter")

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_zone = false
		player_ref = null
		if interaction_prompt:
			interaction_prompt.visible = false

func enter_tavern():
	print("Entering tavern...")
	
	# Instant scene change back to interior
	get_tree().change_scene_to_file("res://scenes/MainTavern.tscn")
